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

export const uploadService = {
  async uploadToCloudinary(file: Express.Multer.File, folder: string): Promise<string> {
    ensureCloudinaryConfigured();

    const base64 = file.buffer.toString('base64');
    const dataUri = `data:${file.mimetype};base64,${base64}`;

    const result = await cloudinary.uploader.upload(dataUri, {
      folder: `hrms/${folder}`,
      resource_type: 'auto',
      /** Without this, account/upload-preset may default to authenticated → browser gets HTTP 401 on res.cloudinary.com URLs. */
      access_mode: 'public',
    });

    return result.secure_url;
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
    const exists = await prisma.academicQualification.findFirst({ where: { id: qualId, employeeId, isActive: true } });
    if (!exists) throw new Error('Qualification not found');

    return prisma.academicQualification.update({
      where: { id: qualId },
      data: { [field]: url, updatedBy: actorId ?? undefined } as any,
    });
  },

  async setCertificate(employeeId: number, qualId: string, url: string, actorId?: string) {
    const exists = await prisma.academicQualification.findFirst({ where: { id: qualId, employeeId, isActive: true } });
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
};
