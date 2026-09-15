import { prisma } from '../../config/prisma';
import type { EmployeeStatus } from '@prisma/client';
import { resolveInstituteRef } from '../institute/institute.util';
import { loadPositionMapByRoleId, resolveRoleIdForPosition, resolveRoleIdDirect } from '../designation/position.util';
import { resolveOrCreateRoleForDesignation } from '../designation/designationRole.util';
import { encryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { passwordFromBirthDate, parseBirthDateInput } from '../../utils/dobPassword';
import bcrypt from 'bcryptjs';
import { safelyDeleteUserIds } from '../platform/platform.service';
import { isAdminRole } from '../auth/permissions-map';
import { redis, connectRedis } from '../../config/redis';

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
          { organization: { equals: scope, mode: 'insensitive' } },
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
    birthDate: Date;
    positionDesignationId?: string | null;
    roleId?: string | null;
    firstApproverUserId?: string | null;
    secondApproverUserId?: string | null;
    thirdApproverUserId?: string | null;
    firstReportingId?: number | null;
    secondReportingId?: number | null;
    thirdReportingId?: number | null;
    organization?: string | null;
    instituteId?: string | null;
    subOrganization?: string | null;
    abbreviation?: string | null;
  }, creatorId: string) {
    const instituteRef = await resolveInstituteRef({
      instituteId: input.instituteId,
      subOrganization: input.subOrganization,
    });

    return prisma.$transaction(async (tx) => {
      const { role: matchedRole, designation: designationRef } =
        await resolveOrCreateRoleForDesignation(tx, input.designation, creatorId);

      let assignedRoleId: string;
      if (input.roleId) {
        assignedRoleId = await resolveRoleIdDirect(input.roleId);
      } else if (input.positionDesignationId) {
        assignedRoleId = await resolveRoleIdForPosition(input.positionDesignationId);
      } else {
        assignedRoleId = matchedRole.id;
      }

      const tempUserId = `pending-${Math.random().toString(36).substring(2, 11)}`;
      const employee = await tx.employee.create({
        data: {
          status: 'ACTIVE',
          abbreviation: input.abbreviation ?? null,
          createdBy: creatorId,
          userId: tempUserId,
        },
      });

      const creatorUser = await tx.user.findUnique({
        where: { id: creatorId },
        select: { subOrganization: true },
      });
      const cleanSub = (s?: string | null) => (s && !/^\d{4}$/.test(s.trim()) ? s.trim() : null);
      const targetSubOrg =
        cleanSub(input.subOrganization) ||
        instituteRef.subOrganization ||
        cleanSub(creatorUser?.subOrganization) ||
        null;
      const targetOrg =
        (input.organization && input.organization.trim()) ||
        instituteRef.institute?.name ||
        targetSubOrg ||
        'NB DEVELOPER';

      await tx.employeeGeneralInfo.create({
        data: {
          employeeId: employee.id,
          fullName: input.fullName,
          designation: input.designation,
          designationId: designationRef.id,
          department: input.department,
          joiningDate: input.joiningDate,
          originalJoiningDate: input.joiningDate,
          employeeCategory: input.employeeCategory as any,
          organization: targetOrg,
          instituteId: instituteRef.instituteId,
          subOrganization: targetSubOrg,
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

      const birthDate = parseBirthDateInput(input.birthDate);
      const defaultPassword = passwordFromBirthDate(birthDate);

      await tx.employeePersonalInfo.create({
        data: {
          employeeId: employee.id,
          birthDate,
          gender: 'MALE',
          maritalStatus: 'SINGLE',
        },
      });

      const passwordHash = await bcrypt.hash(defaultPassword, 12);
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

      await tx.employeeAssignment.create({
        data: {
          employeeId: employee.id,
          effectiveFrom: input.joiningDate,
          effectiveTo: null,
          organization: targetOrg,
          instituteId: instituteRef.instituteId,
          subOrganization: targetSubOrg,
          department: input.department,
          designation: input.designation,
          designationId: designationRef.id,
          reason: 'Initial onboarding assignment',
          changeType: 'JOINING',
          changedBy: creatorId,
        },
      });

      const created = await tx.employee.update({
        where: { id: employee.id },
        data: { userId: user.id },
        include: {
          generalInfo: true,
          addresses: true,
        }
      });

      return {
        ...created,
        initialPassword: defaultPassword,
        loginHint: input.employeeCode,
      };
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

  /**
   * Permanently remove a TERMINATED employee and all related DB rows
   * (photos URLs, attendance, leave, salary, docs, login user, sessions).
   * Refuses to delete SUPERADMIN / ADMIN login accounts.
   */
  async hardDelete(employeeId: number, requesterId: string) {
    const employee = await prisma.employee.findUnique({
      where: { id: employeeId },
      include: {
        generalInfo: { select: { fullName: true, employeeCode: true } },
      },
    });
    if (!employee) return { ok: false as const, error: 'Employee not found', status: 404 as const };

    if (employee.status !== 'TERMINATED') {
      return {
        ok: false as const,
        error: 'Employee must be terminated first. Terminate once, then delete again to permanently remove all data.',
        status: 400 as const,
      };
    }

    const userId = employee.userId?.startsWith('pending-') ? null : employee.userId;
    const linkedUser = userId
      ? await prisma.user.findUnique({
          where: { id: userId },
          select: { id: true, role: { select: { name: true } } },
        })
      : await prisma.user.findFirst({
          where: { employeeId },
          select: { id: true, role: { select: { name: true } } },
        });

    if (isAdminRole(linkedUser?.role?.name)) {
      return {
        ok: false as const,
        error: 'Cannot permanently delete Superadmin or System Admin accounts from workforce.',
        status: 403 as const,
      };
    }

    const deleteUserId = linkedUser?.id ?? userId;

    if (deleteUserId) {
      await safelyDeleteUserIds([deleteUserId]);
      try {
        await connectRedis();
        await redis.del(`session:${deleteUserId}`);
      } catch {
        // Redis optional for wipe
      }
    } else {
      // Pending / orphan employee — purge person data without a real user row
      const empIds = [employeeId];
      const apps = await prisma.leaveApplication.findMany({
        where: { employeeId: { in: empIds } },
        select: { id: true },
      });
      if (apps.length) {
        await prisma.leaveApprovalStep.deleteMany({
          where: { applicationId: { in: apps.map((a) => a.id) } },
        });
      }
      await prisma.leaveApplication.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.leaveBalance.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.leaveAuditLog.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.monthlyLWPRecord.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.absenceRecord.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.attendancePunch.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeAttendanceSettings.deleteMany({ where: { employeeId: { in: empIds } } });
      const salaryRecords = await prisma.employeeSalaryRecord.findMany({
        where: { employeeId: { in: empIds } },
        select: { id: true },
      });
      if (salaryRecords.length) {
        await prisma.employeeSalaryColumnValue.deleteMany({
          where: { salaryRecordId: { in: salaryRecords.map((r) => r.id) } },
        });
      }
      await prisma.employeeSalaryRecord.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeSalaryInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeBankInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeLetterDocument.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.reimbursementClaim.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.changeRequest.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.auditLog.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.locationHistory.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.trip.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.trackingEvent.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.positionAssignment.deleteMany({ where: { holderEmployeeId: { in: empIds } } });
      await prisma.employeeAssignment.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.departmentApprover.deleteMany({ where: { hodEmployeeId: { in: empIds } } });
      await prisma.instituteApprover.deleteMany({ where: { hoiEmployeeId: { in: empIds } } });
      await prisma.globalApprover.updateMany({
        where: { vcEmployeeId: { in: empIds } },
        data: { vcEmployeeId: null },
      });
      await prisma.globalApprover.updateMany({
        where: { registrarEmployeeId: { in: empIds } },
        data: { registrarEmployeeId: null },
      });
      await prisma.orgTreeContact.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.crmFollowUp.updateMany({
        where: { assignedToId: { in: empIds } },
        data: { assignedToId: null },
      });
      await prisma.familyMember.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.academicQualification.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeExperience.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeAddress.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeePersonalInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeOtherInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeGeneralInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employee.deleteMany({ where: { id: { in: empIds } } });
    }

    // Ensure employee row is gone even if user cascade missed it
    const still = await prisma.employee.findUnique({ where: { id: employeeId } });
    if (still) {
      await prisma.user.updateMany({
        where: { employeeId },
        data: { employeeId: null, updatedBy: requesterId },
      });
      await prisma.employee.delete({ where: { id: employeeId } }).catch(() => null);
    }

    return {
      ok: true as const,
      message: 'Employee and all related data permanently deleted',
      employeeId,
      name: employee.generalInfo?.fullName ?? null,
      code: employee.generalInfo?.employeeCode ?? null,
    };
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
