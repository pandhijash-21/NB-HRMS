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

  async createFull(input: {
    fullName: string;
    email: string;
    designation: string;
    department: string;
    joiningDate: Date;
    employeeCategory: string;
    employeeCode: string;
  }, creatorId: string) {
    return prisma.$transaction(async (tx) => {
      // 1. Get Employee Role ID
      const employeeRole = await tx.role.findUnique({
        where: { name: 'EMPLOYEE' }
      });
      if (!employeeRole) throw new Error('EMPLOYEE role not found. Please seed the database.');

      // 2. Create Employee with a temporary unique userId
      const tempUserId = `pending-${Math.random().toString(36).substring(2, 11)}`;
      const employee = await tx.employee.create({
        data: {
          status: 'ACTIVE',
          createdBy: creatorId,
          userId: tempUserId,
        },
      });

      // 3. Create General Info
      await tx.employeeGeneralInfo.create({
        data: {
          employeeId: employee.id,
          fullName: input.fullName,
          designation: input.designation,
          department: input.department,
          joiningDate: input.joiningDate,
          originalJoiningDate: input.joiningDate,
          employeeCategory: input.employeeCategory as any,
          organization: 'GANDHINAGAR UNIVERSITY',
          updatedBy: creatorId,
        },
      });

      // 4. Create Address (Local) for email
      await tx.employeeAddress.create({
        data: {
          employeeId: employee.id,
          addressType: 'LOCAL',
          instituteEmail: input.email,
        },
      });

      // 5. Create Personal Info (Empty for now)
      await tx.employeePersonalInfo.create({
        data: {
          employeeId: employee.id,
          birthDate: new Date('1990-01-01'), // Placeholder
          gender: 'MALE', // Placeholder
          maritalStatus: 'SINGLE', // Placeholder
        },
      });

      // 6. Create User account
      // Default password: 01011990
      const passwordHash = await require('bcryptjs').hash('01011990', 12);
      const user = await tx.user.create({
        data: {
          employeeId: employee.id,
          roleId: employeeRole.id,
          passwordHash,
          isFirstLogin: true,
          createdBy: creatorId,
        }
      });

      // 7. Update Employee with real userId
      return tx.employee.update({
        where: { id: employee.id },
        data: { userId: user.id },
        include: {
          generalInfo: true,
          addresses: true,
        }
      });
    });
  },

  async softDelete(employeeId: number, requesterId: string) {
    return prisma.$transaction(async (tx) => {
      const employee = await tx.employee.findUnique({
        where: { id: employeeId },
      });
      if (!employee) return null;

      // 1. Deactivate User if exists
      if (employee.userId && !employee.userId.startsWith('pending-')) {
        await tx.user.update({
          where: { id: employee.userId },
          data: { isActive: false, updatedBy: requesterId },
        });
      }

      // 2. Update Employee Status
      return tx.employee.update({
        where: { id: employeeId },
        data: {
          status: 'TERMINATED',
        },
      });
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

