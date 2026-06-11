import { prisma } from '../../config/prisma';
import type { EmployeeStatus } from '@prisma/client';

export const employeeService = {
  async list(params: { search?: string; status?: string; limit?: number; offset?: number; subOrganization?: string | null }) {
    const { search, status, limit = 20, offset = 0 } = params;

    const where: any = {};
    if (status) where.status = status as EmployeeStatus;
    if (params.subOrganization) {
      where.generalInfo = { ...(where.generalInfo ?? {}), subOrganization: params.subOrganization };
    }
    const s = search?.trim();
    if (s) {
      const isNumeric = /^\d+$/.test(s);
      const numericId = isNumeric ? Number(s) : null;

      where.OR = [
        { generalInfo: { fullName: { contains: s, mode: 'insensitive' } } },
        { generalInfo: { employeeCode: { contains: s, mode: 'insensitive' } } },
        ...(numericId !== null && Number.isFinite(numericId) ? [{ id: numericId }] : []),
      ];
    }

    const [items, total] = await Promise.all([
      prisma.employee.findMany({
        where,
        include: { generalInfo: true },
        take: limit,
        skip: offset,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.employee.count({ where }),
    ]);

    return { items, total };
  },

  getById(employeeId: number) {
    return prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        generalInfo: true,
        personalInfo: true, // NOTE: encrypted fields exist here; do NOT expose decrypted via this service
        addresses: true,
        otherInfo: true,
        bankInfo: true,
        familyMembers: true,
        academicQuals: true,
      },
    });
  },

  async createFull(input: {
    fullName: string;
    personalEmail: string;
    institutionalEmail?: string | null;
    designation: string;
    department: string;
    joiningDate: Date;
    employeeCategory: string;
    employeeCode: string;
    firstApproverUserId?: string | null;
    secondApproverUserId?: string | null;
    thirdApproverUserId?: string | null;
    // legacy
    firstReportingId?: number | null;
    secondReportingId?: number | null;
    thirdReportingId?: number | null;
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

      const designationRef = await tx.designation.findFirst({
        where: { name: input.designation, isAlias: false },
      });

      // 3. Create General Info
      await tx.employeeGeneralInfo.create({
        data: {
          employeeId: employee.id,
          fullName: input.fullName,
          designation: input.designation,
          designationId: designationRef?.id ?? null,
          department: input.department,
          joiningDate: input.joiningDate,
          originalJoiningDate: input.joiningDate,
          employeeCategory: input.employeeCategory as any,
          organization: 'GANDHINAGAR UNIVERSITY',
          employeeCode: input.employeeCode,
          // New (preferred)
          firstApproverUserId:  input.firstApproverUserId  ?? null,
          secondApproverUserId: input.secondApproverUserId ?? null,
          thirdApproverUserId:  input.thirdApproverUserId  ?? null,
          // Legacy (kept as null unless provided)
          firstReportingId:  input.firstReportingId  ?? null,
          secondReportingId: input.secondReportingId ?? null,
          thirdReportingId:  input.thirdReportingId  ?? null,
          updatedBy: creatorId,
        },
      });

      // 4. Create Address (Local) for both emails
      await tx.employeeAddress.create({
        data: {
          employeeId: employee.id,
          addressType: 'LOCAL',
          personalEmail: input.personalEmail,
          instituteEmail: input.institutionalEmail,
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

  async listNames() {
    const employees = await prisma.employee.findMany({
      where: { status: 'ACTIVE' },
      select: {
        id: true,
        userId: true,
        generalInfo: {
          select: { fullName: true, employeeCode: true },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
    const employeeItems = employees
      .filter((e) => e.generalInfo?.fullName)
      .map((e) => ({
        type: 'EMPLOYEE' as const,
        id: e.id,
        userId: e.userId,
        fullName: e.generalInfo!.fullName,
        employeeCode: e.generalInfo!.employeeCode,
      }));

    const positionUsers = await prisma.user.findMany({
      where: { employeeId: null, isActive: true, username: { not: null } },
      select: {
        id: true,
        username: true,
        role: { select: { name: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    const positionItems = positionUsers.map((u) => ({
      type: 'POSITION' as const,
      id: u.id,
      userId: u.id,
      fullName: u.username ?? 'Position Account',
      employeeCode: u.role.name,
    }));

    return [...employeeItems, ...positionItems];
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

