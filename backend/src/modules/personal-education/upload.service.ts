import type { Express } from 'express';
import { cloudinary } from '../../config/cloudinary';
import { env } from '../../config/env';
import { prisma } from '../../config/prisma';

function ensureCloudinaryConfigured() {
  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    throw new Error('Cloudinary is not configured');
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
    });

    return result.secure_url;
  },

  setEmployeePhoto(employeeId: number, photoUrl: string, actorId?: string) {
    return prisma.employee.update({
      where: { id: employeeId },
      data: { photoUrl, createdBy: actorId ?? undefined },
    });
  },

  setEmployeeSignature(employeeId: number, signatureUrl: string, actorId?: string) {
    return prisma.employee.update({
      where: { id: employeeId },
      data: { signatureUrl, createdBy: actorId ?? undefined },
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
};

