import type { Express } from 'express';
import { cloudinary, getCloudinaryCredentials } from '../../config/cloudinary';
import { prisma } from '../../config/prisma';

function ensureCloudinaryConfigured() {
  if (!getCloudinaryCredentials()) {
    throw new Error(
      'Cloudinary is not configured. Set CLOUDINARY_URL or CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET in backend/.env'
    );
  }
}

export type ParsedCloudinaryUrl = {
  cloudName: string;
  resourceType: 'image' | 'raw' | 'video' | 'auto';
  deliveryType: string;
  publicId: string;
  format?: string;
  version?: string;
};

/** Parse a res.cloudinary.com delivery URL into upload components. */
export function parseCloudinaryDeliveryUrl(rawUrl: string): ParsedCloudinaryUrl | null {
  try {
    const u = new URL(rawUrl.trim());
    if (!u.hostname.includes('res.cloudinary.com')) return null;
    const parts = u.pathname.split('/').filter(Boolean);
    if (parts.length < 4) return null;
    const cloudName = parts[0];
    const resourceType = parts[1] as ParsedCloudinaryUrl['resourceType'];
    const deliveryType = parts[2];
    let i = 3;
    // Skip transforms (c_scale,w_..) and signed-URL tokens (s--xxxx--)
    while (
      i < parts.length &&
      !/^v\d+$/.test(parts[i]) &&
      (parts[i].includes(',') || /^s--.+--$/.test(parts[i]) || parts[i].startsWith('t_'))
    ) {
      i += 1;
    }
    let version: string | undefined;
    if (i < parts.length && /^v\d+$/.test(parts[i])) {
      version = parts[i];
      i += 1;
    }
    if (i >= parts.length) return null;
    const rest = parts.slice(i).join('/');
    const dot = rest.lastIndexOf('.');
    const format = dot > 0 ? rest.slice(dot + 1) : undefined;
    const publicId = format ? rest.slice(0, dot) : rest;
    return { cloudName, resourceType, deliveryType, publicId, format, version };
  } catch {
    return null;
  }
}

export const uploadService = {
  async uploadToCloudinary(file: Express.Multer.File, folder: string): Promise<string> {
    ensureCloudinaryConfigured();

    const base64 = file.buffer.toString('base64');
    const dataUri = `data:${file.mimetype};base64,${base64}`;
    const isPdf =
      file.mimetype === 'application/pdf' ||
      (file.originalname || '').toLowerCase().endsWith('.pdf');

    const result = await cloudinary.uploader.upload(dataUri, {
      folder: `hrms/${folder}`,
      resource_type: isPdf ? 'raw' : 'auto',
      type: 'upload',
      access_mode: 'public',
      use_filename: true,
      unique_filename: true,
    });

    return result.secure_url;
  },

  /**
   * Resolve a Cloudinary URL that the **server** can fetch.
   * Restricted media delivery often returns HTTP 401 for signed browser URLs —
   * prefer private_download_url for server-side proxying.
   */
  async getViewableUrl(rawUrl: string): Promise<string> {
    ensureCloudinaryConfigured();
    const parsed = parseCloudinaryDeliveryUrl(rawUrl);
    if (!parsed) return rawUrl;

    // Prefer the parsed resource type first, then the other common ones.
    const ordered: Array<'image' | 'raw' | 'video'> = [
      ...(parsed.resourceType === 'image' || parsed.resourceType === 'raw' || parsed.resourceType === 'video'
        ? [parsed.resourceType]
        : []),
      'image',
      'raw',
      'video',
    ].filter((v, i, a) => a.indexOf(v) === i) as Array<'image' | 'raw' | 'video'>;

    const format = parsed.format || (rawUrl.toLowerCase().includes('.pdf') ? 'pdf' : undefined);
    const expiresAt = Math.floor(Date.now() / 1000) + 60 * 60;
    const deliveryType =
      parsed.deliveryType === 'authenticated' ? 'authenticated' : 'upload';

    // 1) private_download_url — works with restricted media when server fetches it
    for (const resourceType of ordered) {
      try {
        const downloadUrl = cloudinary.utils.private_download_url(parsed.publicId, format ?? '', {
          resource_type: resourceType,
          type: deliveryType,
          expires_at: expiresAt,
          attachment: false,
        });
        if (downloadUrl) return downloadUrl;
      } catch {
        // try next
      }
    }

    // 2) Signed delivery fallback
    for (const resourceType of ordered) {
      try {
        const signed = cloudinary.url(parsed.publicId, {
          resource_type: resourceType,
          type: deliveryType,
          sign_url: true,
          secure: true,
          ...(parsed.version ? { version: parsed.version.replace(/^v/, '') } : {}),
          ...(format ? { format } : {}),
        });
        if (signed) return signed;
      } catch {
        // try next
      }
    }

    return rawUrl;
  },

  /** Fetch document bytes trying multiple Cloudinary access strategies. */
  async fetchDocumentBytes(rawUrl: string): Promise<{ buffer: Buffer; contentType: string | null }> {
    ensureCloudinaryConfigured();
    const parsed = parseCloudinaryDeliveryUrl(rawUrl);
    const candidates: string[] = [];

    if (parsed) {
      const format = parsed.format || (rawUrl.toLowerCase().includes('.pdf') ? 'pdf' : undefined);
      const expiresAt = Math.floor(Date.now() / 1000) + 60 * 60;
      const deliveryType =
        parsed.deliveryType === 'authenticated' ? 'authenticated' : 'upload';
      const ordered: Array<'image' | 'raw' | 'video'> = [
        ...(parsed.resourceType === 'image' || parsed.resourceType === 'raw' || parsed.resourceType === 'video'
          ? [parsed.resourceType]
          : []),
        'image',
        'raw',
        'video',
      ].filter((v, i, a) => a.indexOf(v) === i) as Array<'image' | 'raw' | 'video'>;

      for (const resourceType of ordered) {
        try {
          const downloadUrl = cloudinary.utils.private_download_url(parsed.publicId, format ?? '', {
            resource_type: resourceType,
            type: deliveryType,
            expires_at: expiresAt,
            attachment: false,
          });
          if (downloadUrl) candidates.push(downloadUrl);
        } catch {
          // continue
        }
        try {
          const signed = cloudinary.url(parsed.publicId, {
            resource_type: resourceType,
            type: deliveryType,
            sign_url: true,
            secure: true,
            ...(parsed.version ? { version: parsed.version.replace(/^v/, '') } : {}),
            ...(format ? { format } : {}),
          });
          if (signed) candidates.push(signed);
        } catch {
          // continue
        }
      }
    }

    candidates.push(rawUrl);

    let lastStatus = 0;
    for (const candidate of candidates) {
      try {
        const upstream = await fetch(candidate);
        lastStatus = upstream.status;
        if (!upstream.ok) continue;
        const buffer = Buffer.from(await upstream.arrayBuffer());
        if (buffer.length === 0) continue;
        return {
          buffer,
          contentType: upstream.headers.get('content-type'),
        };
      } catch {
        // try next candidate
      }
    }

    throw Object.assign(new Error(`Failed to fetch document (${lastStatus || 'unreachable'})`), {
      status: 502,
    });
  },

  guessMimeFromUrl(url: string): string | null {
    const u = url.toLowerCase().split('?')[0];
    if (u.endsWith('.pdf')) return 'application/pdf';
    if (u.endsWith('.png')) return 'image/png';
    if (u.endsWith('.jpg') || u.endsWith('.jpeg')) return 'image/jpeg';
    if (u.endsWith('.gif')) return 'image/gif';
    if (u.endsWith('.webp')) return 'image/webp';
    if (u.endsWith('.doc')) return 'application/msword';
    if (u.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return null;
  },

  setEmployeePhoto(employeeId: number, photoUrl: string, _actorId?: string) {
    return prisma.employee.update({
      where: { id: employeeId },
      data: { photoUrl },
    });
  },

  setEmployeeSignature(employeeId: number, signatureUrl: string, _actorId?: string) {
    return prisma.employee.update({
      where: { id: employeeId },
      data: { signatureUrl },
    });
  },

  setAadhaarCard(employeeId: number, aadhaarCardUrl: string, actorId?: string) {
    return prisma.employeePersonalInfo.upsert({
      where: { employeeId },
      update: { aadhaarCardUrl, updatedBy: actorId ?? undefined },
      create: {
        employeeId,
        birthDate: new Date('1970-01-01T00:00:00.000Z'),
        gender: 'OTHER',
        maritalStatus: 'SINGLE',
        nationality: 'INDIAN',
        aadhaarCardUrl,
        updatedBy: actorId ?? null,
      },
    });
  },

  setPanCard(employeeId: number, panCardUrl: string, actorId?: string) {
    return prisma.employeePersonalInfo.upsert({
      where: { employeeId },
      update: { panCardUrl, updatedBy: actorId ?? undefined },
      create: {
        employeeId,
        birthDate: new Date('1970-01-01T00:00:00.000Z'),
        gender: 'OTHER',
        maritalStatus: 'SINGLE',
        nationality: 'INDIAN',
        panCardUrl,
        updatedBy: actorId ?? null,
      },
    });
  },

  setOtherDocument(employeeId: number, otherDocumentUrl: string, actorId?: string) {
    return prisma.employeePersonalInfo.upsert({
      where: { employeeId },
      update: { otherDocumentUrl, updatedBy: actorId ?? undefined },
      create: {
        employeeId,
        birthDate: new Date('1970-01-01T00:00:00.000Z'),
        gender: 'OTHER',
        maritalStatus: 'SINGLE',
        nationality: 'INDIAN',
        otherDocumentUrl,
        updatedBy: actorId ?? null,
      },
    });
  },

  setPassport(employeeId: number, passportUrl: string, actorId?: string) {
    return prisma.employeeOtherInfo.upsert({
      where: { employeeId },
      update: { passportUrl, updatedBy: actorId ?? undefined },
      create: {
        employeeId,
        passportUrl,
        updatedBy: actorId ?? null,
      },
    });
  },

  async setSemMarksheet(employeeId: number, qualId: string, sem: number, url: string, actorId?: string) {
    const field = `sem${sem}MarksheetUrl` as const;
    const exists = await prisma.academicQualification.findFirst({
      where: { id: qualId, employeeId, isActive: true },
    });
    if (!exists) throw new Error('Qualification not found');

    return prisma.academicQualification.update({
      where: { id: qualId },
      data: { [field]: url, updatedBy: actorId ?? undefined } as any,
    });
  },

  async setCertificate(employeeId: number, qualId: string, url: string, actorId?: string) {
    const exists = await prisma.academicQualification.findFirst({
      where: { id: qualId, employeeId, isActive: true },
    });
    if (!exists) throw new Error('Qualification not found');

    return prisma.academicQualification.update({
      where: { id: qualId },
      data: { certificateUrl: url, updatedBy: actorId ?? undefined },
    });
  },

  async setFamilyMemberAadhaar(employeeId: number, memberId: string, url: string, actorId?: string) {
    const member = await prisma.familyMember.findFirst({
      where: { id: memberId, employeeId, isActive: true },
    });
    if (!member) return null;

    return prisma.familyMember.update({
      where: { id: memberId },
      data: { aadhaarUrl: url, updatedBy: actorId ?? undefined },
    });
  },

  setCancelledCheque(employeeId: number, cancelledChequeUrl: string, actorId?: string) {
    return prisma.employeeBankInfo.upsert({
      where: { employeeId },
      update: { cancelledChequeUrl, updatedBy: actorId ?? undefined },
      create: {
        employeeId,
        cancelledChequeUrl,
        updatedBy: actorId ?? null,
      },
    });
  },

  setPassbook(employeeId: number, passbookUrl: string, actorId?: string) {
    return prisma.employeeBankInfo.upsert({
      where: { employeeId },
      update: { passbookUrl, updatedBy: actorId ?? undefined },
      create: {
        employeeId,
        passbookUrl,
        updatedBy: actorId ?? null,
      },
    });
  },
};
