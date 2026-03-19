import { prisma } from '../../config/prisma';
import type { EmployeeStatus } from '@prisma/client';

export const employeeService = {
  getById(employeeId: number) {
    return prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        generalInfo: true,
        personalInfo: true, // NOTE: encrypted fields exist here; do NOT expose decrypted via this service
        addresses: true,
        otherInfo: true,
        familyMembers: true,
        academicQuals: true,
      },
    });
  },

  create(input: { userId: string; abbreviation?: string; status?: EmployeeStatus; createdBy?: string }) {
    return prisma.employee.create({
      data: {
        userId: input.userId,
        abbreviation: input.abbreviation,
        status: input.status,
        createdBy: input.createdBy,
      },
    });
  },

  async update(
    employeeId: number,
    input: { abbreviation?: string | null; status?: EmployeeStatus; photoUrl?: string | null; signatureUrl?: string | null }
  ) {
    const exists = await prisma.employee.findUnique({ where: { id: employeeId } });
    if (!exists) return null;

    return prisma.employee.update({
      where: { id: employeeId },
      data: {
        abbreviation: input.abbreviation ?? undefined,
        status: input.status ?? undefined,
        photoUrl: input.photoUrl ?? undefined,
        signatureUrl: input.signatureUrl ?? undefined,
      },
    });
  },
};

