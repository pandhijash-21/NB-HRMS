import { prisma } from '../../config/prisma';
import type { EmployeeStatus } from '@prisma/client';
import { resolveInstituteRef } from '../institute/institute.util';
import { loadPositionMapByRoleId, resolveRoleIdForPosition } from '../designation/position.util';

function attachPosition<T extends { user?: { roleId: string } | null }>(
  employee: T,
  positionMap: Map<string, { id: string; name: string; linkedRoleId: string; linkedRoleName: string }>,
) {
  const roleId = employee.user?.roleId;
  const position = roleId ? positionMap.get(roleId) ?? null : null;
  return { ...employee, position };
}

export const employeeService = {
  async list(params: { search?: string; status?: string; limit?: number; offset?: number; subOrganization?: string | null }) {
    const { search, status, limit = 20, offset = 0 } = params;

    const where: any = {};
    if (status) where.status = status as EmployeeStatus;
    if (params.subOrganization === '__NO_INSTITUTE_SCOPE__') {
      where.id = -1;
    } else if (params.subOrganization) {
      const scope = params.subOrganization.trim();
      where.generalInfo = {
        ...(where.generalInfo ?? {}),
        OR: [
          { subOrganization: { equals: scope, mode: 'insensitive' } },
          { institute: { code: { equals: scope, mode: 'insensitive' } } },
          { institute: { name: { equals: scope, mode: 'insensitive' } } },
        ],
      };
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

    const [rawItems, total, positionMap] = await Promise.all([
      prisma.employee.findMany({
        where,
        include: {
          generalInfo: true,
          user: { select: { roleId: true, role: { select: { name: true } } } },
        },
        take: limit,
        skip: offset,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.employee.count({ where }),
      loadPositionMapByRoleId(),
    ]);

    const items = rawItems.map((emp) => attachPosition(emp, positionMap));

    return { items, total };
  },

  async getById(employeeId: number) {
    const [employee, positionMap] = await Promise.all([
      prisma.employee.findUnique({
        where: { id: employeeId },
        include: {
          generalInfo: { include: { institute: true } },
          personalInfo: true,
          addresses: true,
          otherInfo: true,
          bankInfo: true,
          familyMembers: true,
          academicQuals: true,
          user: { select: { id: true, roleId: true, role: { select: { id: true, name: true } } } },
        },
      }),
      loadPositionMapByRoleId(),
    ]);
    if (!employee) return null;
    return attachPosition(employee, positionMap);
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
    positionDesignationId?: string | null;
    firstApproverUserId?: string | null;
    secondApproverUserId?: string | null;
    thirdApproverUserId?: string | null;
    firstReportingId?: number | null;
    secondReportingId?: number | null;
    thirdReportingId?: number | null;
    instituteId?: string | null;
    subOrganization?: string | null;
    abbreviation?: string | null;
  }, creatorId: string) {
    const instituteRef = await resolveInstituteRef({
      instituteId: input.instituteId,
      subOrganization: input.subOrganization,
    });

    const assignedRoleId = await resolveRoleIdForPosition(input.positionDesignationId ?? null);

    return prisma.$transaction(async (tx) => {
      const tempUserId = `pending-${Math.random().toString(36).substring(2, 11)}`;
      const employee = await tx.employee.create({
        data: {
          status: 'ACTIVE',
          abbreviation: input.abbreviation ?? null,
          createdBy: creatorId,
          userId: tempUserId,
        },
      });

      const designationRef = await tx.designation.findFirst({
        where: { name: input.designation, isAlias: false },
      });

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
          instituteId: instituteRef.instituteId,
          subOrganization: instituteRef.subOrganization,
          employeeCode: input.employeeCode,
          firstApproverUserId:  input.firstApproverUserId  ?? null,
          secondApproverUserId: input.secondApproverUserId ?? null,
          thirdApproverUserId:  input.thirdApproverUserId  ?? null,
          firstReportingId:  input.firstReportingId  ?? null,
          secondReportingId: input.secondReportingId ?? null,
          thirdReportingId:  input.thirdReportingId  ?? null,
          updatedBy: creatorId,
        },
      });

      await tx.employeeAddress.create({
        data: {
          employeeId: employee.id,
          addressType: 'LOCAL',
          personalEmail: input.personalEmail,
          instituteEmail: input.institutionalEmail,
        },
      });

      await tx.employeePersonalInfo.create({
        data: {
          employeeId: employee.id,
          birthDate: new Date('1990-01-01'),
          gender: 'MALE',
          maritalStatus: 'SINGLE',
        },
      });

      const defaultPassword = '01011990';
      const passwordHash = await require('bcryptjs').hash(defaultPassword, 12);
      const { encryptPasswordForAdmin } = await import('../../utils/passwordCrypto');
      const user = await tx.user.create({
        data: {
          employeeId: employee.id,
          roleId: assignedRoleId,
          passwordHash,
          adminPasswordEnc: encryptPasswordForAdmin(defaultPassword),
          isFirstLogin: true,
          createdBy: creatorId,
        }
      });

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

  async assignPosition(employeeId: number, positionDesignationId: string | null, updaterId: string) {
    const employee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: { user: { select: { id: true, roleId: true } } },
    });
    if (!employee) throw new Error('Employee not found');
    if (!employee.user || employee.userId.startsWith('pending-')) {
      throw new Error('Employee has no active user account');
    }

    const roleId = await resolveRoleIdForPosition(positionDesignationId);

    const updatedUser = await prisma.user.update({
      where: { id: employee.user.id },
      data: { roleId, updatedBy: updaterId },
      include: { role: { select: { id: true, name: true } } },
    });

    const positionMap = await loadPositionMapByRoleId();
    return {
      user: updatedUser,
      position: positionMap.get(roleId) ?? null,
    };
  },

  async listNames(params?: { subOrganization?: string }) {
    const byUserId = new Map<
      string,
      {
        type: 'EMPLOYEE' | 'POSITION';
        id: number | string;
        userId: string;
        fullName: string;
        employeeCode: string | null;
        designationName: string | null;
      }
    >();

    const employeeWhere: Record<string, unknown> = { status: 'ACTIVE' };
    if (params?.subOrganization === '__NO_INSTITUTE_SCOPE__') {
      employeeWhere.id = -1;
    } else if (params?.subOrganization) {
      const scope = params.subOrganization.trim();
      employeeWhere.generalInfo = {
        OR: [
          { subOrganization: { equals: scope, mode: 'insensitive' } },
          { institute: { code: { equals: scope, mode: 'insensitive' } } },
          { institute: { name: { equals: scope, mode: 'insensitive' } } },
        ],
      };
    }

    const employees = await prisma.employee.findMany({
      where: employeeWhere,
      select: {
        id: true,
        userId: true,
        generalInfo: {
          select: {
            fullName: true,
            employeeCode: true,
            designation: true,
            designationRef: { select: { name: true, isAlias: true } },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    for (const e of employees) {
      if (!e.generalInfo?.fullName || !e.userId || e.userId.startsWith('pending-')) continue;
      byUserId.set(e.userId, {
        type: 'EMPLOYEE',
        id: e.id,
        userId: e.userId,
        fullName: e.generalInfo.fullName,
        employeeCode: e.generalInfo.employeeCode,
        designationName: e.generalInfo.designationRef?.name ?? e.generalInfo.designation ?? null,
      });
    }

    const positionSlots = await prisma.positionSlot.findMany({
      where: { isActive: true, userId: { not: null } },
      include: {
        designation: { select: { name: true, isAlias: true } },
        linkedRole: { select: { name: true } },
        user: { select: { id: true, username: true, isActive: true } },
      },
      orderBy: { name: 'asc' },
    });

    for (const slot of positionSlots) {
      if (!slot.userId || !slot.user?.isActive) continue;
      byUserId.set(slot.userId, {
        type: 'POSITION',
        id: slot.id,
        userId: slot.userId,
        fullName: slot.name || slot.designation.name,
        employeeCode: slot.code,
        designationName: slot.designation.name,
      });
    }

    const orphanPositionUsers = await prisma.user.findMany({
      where: {
        employeeId: null,
        isActive: true,
        username: { not: null },
        positionSlot: null,
      },
      select: {
        id: true,
        username: true,
        role: { select: { name: true } },
      },
      orderBy: { createdAt: 'asc' },
    });

    for (const u of orphanPositionUsers) {
      if (byUserId.has(u.id)) continue;
      byUserId.set(u.id, {
        type: 'POSITION',
        id: u.id,
        userId: u.id,
        fullName: u.username ?? 'Position Account',
        employeeCode: u.role.name,
        designationName: u.role.name,
      });
    }

    const items = [...byUserId.values()];
    items.sort((a, b) => {
      if (a.type !== b.type) return a.type === 'POSITION' ? -1 : 1;
      return a.fullName.localeCompare(b.fullName);
    });
    return items;
  },

  async softDelete(employeeId: number, requesterId: string) {
    return prisma.$transaction(async (tx) => {
      const employee = await tx.employee.findUnique({
        where: { id: employeeId },
      });
      if (!employee) return null;

      if (employee.userId && !employee.userId.startsWith('pending-')) {
        await tx.user.update({
          where: { id: employee.userId },
          data: { isActive: false, updatedBy: requesterId },
        });
      }

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
