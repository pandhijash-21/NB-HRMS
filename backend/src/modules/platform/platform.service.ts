import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import { encryptPasswordForAdmin, decryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { clearLoginLock, loadLocksByUserIds } from '../auth/loginLock.service';
import { isSuperAdminRole } from '../auth/permissions-map';

export type OnboardCompanyInput = {
  name: string;
  code: string;
  contactPerson?: string;
  email?: string;
  mobileNo?: string;
  address?: string;
  enabledModules?: string[];
  adminUsername: string;
  adminPassword: string;
};

export type UpdateCompanyInput = {
  name?: string;
  code?: string;
  contactPerson?: string;
  email?: string;
  mobileNo?: string;
  address?: string;
  enabledModules?: string[];
  isActive?: boolean;
};

export function parseModules(raw?: string | null): string[] {
  if (raw === null || raw === undefined || raw === '') return ['HRMS', 'CRM', 'ERP'];
  try {
    const parsed = JSON.parse(raw);
    if (Array.isArray(parsed)) return parsed.map((s) => String(s).trim().toUpperCase()).filter(Boolean);
  } catch {
    // Comma-separated fallback
    const parts = (raw ?? '').split(',').map((s) => s.trim().toUpperCase()).filter(Boolean);
    return parts;
  }
  return [];
}

export const platformService = {
  /** Aggregated SaaS platform overview metrics */
  async getStats() {
    let dbStatus = 'HEALTHY';
    try {
      await prisma.$queryRaw`SELECT 1`;
    } catch {
      dbStatus = 'DOWN';
    }

    let redisStatus = 'CONNECTED';
    try {
      await connectRedis();
      await redis.ping();
    } catch {
      redisStatus = 'DEGRADED';
    }

    const [totalCompanies, activeCompanies, totalSystemAdmins, totalUsers, trashedCompanies, trashedAdmins] = await Promise.all([
      prisma.organization.count({ where: { deletedAt: null } }),
      prisma.organization.count({ where: { isActive: true, deletedAt: null } }),
      prisma.user.count({
        where: {
          role: { name: { in: ['SYSTEM_ADMIN', 'SYSTEM_ADMINISTRATOR', 'ADMIN'] } },
          isActive: true,
          deletedAt: null,
        },
      }),
      prisma.user.count({ where: { isActive: true, deletedAt: null } }),
      prisma.organization.count({ where: { deletedAt: { not: null } } }),
      prisma.user.count({ where: { deletedAt: { not: null } } }),
    ]);

    return {
      totalCompanies,
      activeCompanies,
      totalSystemAdmins,
      totalUsers,
      totalTrash: trashedCompanies + trashedAdmins,
      uptimeSeconds: Math.floor(process.uptime()),
      dbStatus,
      redisStatus,
      platformVersion: '2.5.0-enterprise',
    };
  },

  /** List all client companies (Tenants) */
  async listCompanies() {
    const orgs = await prisma.organization.findMany({
      where: { deletedAt: null },
      orderBy: [{ createdAt: 'desc' }],
    });

    const results = await Promise.all(
      orgs.map(async (org) => {
        const [userCount, adminUser] = await Promise.all([
          prisma.user.count({
            where: { subOrganization: org.name, deletedAt: null },
          }),
          prisma.user.findFirst({
            where: {
              subOrganization: org.name,
              role: { name: { in: ['SYSTEM_ADMIN', 'SYSTEM_ADMINISTRATOR', 'ADMIN'] } },
              deletedAt: null,
            },
            select: {
              id: true,
              username: true,
              isActive: true,
              lastLoginAt: true,
            },
            orderBy: { createdAt: 'asc' },
          }),
        ]);

        return {
          id: org.id,
          name: org.name,
          code: org.code,
          contactPerson: org.contactPerson,
          email: org.email,
          mobileNo: org.mobileNo,
          address: [org.address1, org.city, org.state].filter(Boolean).join(', ') || null,
          isActive: org.isActive,
          enabledModules: parseModules(org.tagLine),
          userCount,
          primaryAdmin: adminUser,
          createdAt: org.createdAt.toISOString(),
          updatedAt: org.updatedAt.toISOString(),
        };
      }),
    );

    return results;
  },

  /** Onboard a brand new client company and provision their root System Admin account */
  async onboardCompany(input: OnboardCompanyInput) {
    const trimmedName = input.name.trim();
    const cleanCode = input.code.trim().toUpperCase().replace(/\s+/g, '_');
    const cleanUsername = input.adminUsername.trim().toLowerCase();

    if (!trimmedName) throw new Error('Company name is required');
    if (!cleanCode) throw new Error('Company code is required');
    if (!cleanUsername) throw new Error('Admin username is required');
    if (!input.adminPassword || input.adminPassword.length < 6) {
      throw new Error('Admin password must be at least 6 characters');
    }

    // Check uniqueness
    const existingOrg = await prisma.organization.findFirst({
      where: {
        OR: [{ name: { equals: trimmedName, mode: 'insensitive' } }, { code: cleanCode }],
      },
    });
    if (existingOrg) {
      throw new Error(`A company with name "${trimmedName}" or code "${cleanCode}" already exists.`);
    }

    const existingUser = await prisma.user.findUnique({
      where: { username: cleanUsername },
    });
    if (existingUser) {
      throw new Error(`Username "${cleanUsername}" is already in use.`);
    }

    // Find System Admin role
    const sysAdminRole = await prisma.role.findFirst({
      where: { name: { in: ['SYSTEM_ADMIN', 'SYSTEM_ADMINISTRATOR', 'ADMIN'] } },
      orderBy: { name: 'asc' },
    });
    if (!sysAdminRole) {
      throw new Error('System Admin role not found. Please contact support.');
    }

    const modules = input.enabledModules && input.enabledModules.length > 0
      ? input.enabledModules
      : ['HRMS', 'CRM', 'ERP'];

    const org = await prisma.organization.create({
      data: {
        name: trimmedName,
        code: cleanCode,
        contactPerson: input.contactPerson?.trim() || null,
        email: input.email?.trim() || null,
        mobileNo: input.mobileNo?.trim() || null,
        address1: input.address?.trim() || null,
        tagLine: JSON.stringify(modules),
        isActive: true,
      },
    });

    const passwordHash = await bcrypt.hash(input.adminPassword, 12);
    const adminPasswordEnc = encryptPasswordForAdmin(input.adminPassword);

    const user = await prisma.user.create({
      data: {
        username: cleanUsername,
        roleId: sysAdminRole.id,
        subOrganization: org.name,
        passwordHash,
        adminPasswordEnc,
        isActive: true,
        isFirstLogin: false,
      },
      select: {
        id: true,
        username: true,
        subOrganization: true,
        role: { select: { id: true, name: true } },
        createdAt: true,
      },
    });

    return {
      company: {
        id: org.id,
        name: org.name,
        code: org.code,
        contactPerson: org.contactPerson,
        email: org.email,
        mobileNo: org.mobileNo,
        enabledModules: modules,
        isActive: org.isActive,
      },
      admin: {
        id: user.id,
        username: user.username,
        role: user.role.name,
      },
    };
  },

  /** Update company details, status (suspend/activate), or module entitlements */
  async updateCompany(id: string, input: UpdateCompanyInput) {
    const existing = await prisma.organization.findUnique({ where: { id } });
    if (!existing) throw new Error('Company not found');

    const updateData: Record<string, unknown> = {};
    if (input.name !== undefined) updateData.name = input.name.trim();
    if (input.code !== undefined) {
      updateData.code = input.code.trim().toUpperCase().replace(/\s+/g, '_');
    }
    if (input.contactPerson !== undefined) updateData.contactPerson = input.contactPerson.trim() || null;
    if (input.email !== undefined) updateData.email = input.email.trim() || null;
    if (input.mobileNo !== undefined) updateData.mobileNo = input.mobileNo.trim() || null;
    if (input.address !== undefined) updateData.address1 = input.address.trim() || null;
    if (input.isActive !== undefined) updateData.isActive = Boolean(input.isActive);
    if (input.enabledModules !== undefined) {
      updateData.tagLine = JSON.stringify(input.enabledModules);
    }

    const updated = await prisma.organization.update({
      where: { id },
      data: updateData,
    });

    try {
      const { invalidateLicenseCache } = require('../../middleware/tenantLicense');
      invalidateLicenseCache(existing.name);
      if (input.name) invalidateLicenseCache(input.name);
    } catch {}

    // If company name was updated, synchronize users' subOrganization
    if (input.name && input.name.trim() !== existing.name) {
      await prisma.user.updateMany({
        where: { subOrganization: existing.name },
        data: { subOrganization: input.name.trim() },
      });
    }

    return {
      id: updated.id,
      name: updated.name,
      code: updated.code,
      contactPerson: updated.contactPerson,
      email: updated.email,
      mobileNo: updated.mobileNo,
      isActive: updated.isActive,
      enabledModules: parseModules(updated.tagLine),
      updatedAt: updated.updatedAt.toISOString(),
    };
  },

  /** List all client company System Admins across tenants */
  async listSystemAdmins() {
    const admins = await prisma.user.findMany({
      where: {
        role: { name: { in: ['SYSTEM_ADMIN', 'SYSTEM_ADMINISTRATOR', 'ADMIN'] } },
        deletedAt: null,
      },
      select: {
        id: true,
        username: true,
        subOrganization: true,
        isActive: true,
        isFirstLogin: true,
        lastLoginAt: true,
        createdAt: true,
        adminPasswordEnc: true,
        role: { select: { id: true, name: true } },
      },
      orderBy: [{ createdAt: 'desc' }],
    });

    const userIds = admins.map((a) => a.id);
    const lockMap = await loadLocksByUserIds(userIds);

    return admins.map((admin) => {
      const locks = lockMap[admin.id];
      const plainPassword = decryptPasswordForAdmin(admin.adminPasswordEnc);

      return {
        id: admin.id,
        username: admin.username,
        companyName: admin.subOrganization || 'Unassigned',
        role: admin.role.name,
        isActive: admin.isActive,
        isFirstLogin: admin.isFirstLogin,
        lastLoginAt: admin.lastLoginAt?.toISOString() ?? null,
        createdAt: admin.createdAt.toISOString(),
        plainPassword,
        loginBlocked: locks?.loginBlocked ?? false,
        loginTemporarilyLocked: locks?.loginTemporarilyLocked ?? false,
        loginLockedUntil: locks?.loginLockedUntil ?? null,
        loginFailCount: locks?.loginFailCount ?? 0,
      };
    });
  },

  /** Reset a client company system admin's password */
  async resetAdminPassword(userId: string, newPassword: string) {
    if (!newPassword || newPassword.length < 6) {
      throw new Error('Password must be at least 6 characters');
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { role: true },
    });
    if (!user) throw new Error('User not found');

    if (isSuperAdminRole(user.role.name)) {
      throw new Error('Cannot reset Superadmin platform password via tenant console.');
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const adminPasswordEnc = encryptPasswordForAdmin(newPassword);

    await prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash,
        adminPasswordEnc,
        isFirstLogin: false,
      },
    });

    await clearLoginLock({ userId, aliases: [user.username ?? ''] });

    return { success: true, message: `Password for "${user.username}" reset successfully.` };
  },

  /** Unlock a locked client company system admin account */
  async unlockAdminAccount(userId: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new Error('User not found');

    await clearLoginLock({ userId, aliases: [user.username ?? ''] });

    return { success: true, message: `Account "${user.username}" unlocked successfully.` };
  },

  /** Move a client company to Trash (30-day soft delete) */
  async trashCompany(id: string, superadminPassword?: string, superadminUserId?: string) {
    await verifySuperAdminPassword(superadminUserId, superadminPassword);

    const org = await prisma.organization.findUnique({ where: { id } });
    if (!org) throw new Error('Company not found');
    if (org.deletedAt) throw new Error('Company is already in Trash');

    await prisma.organization.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        isActive: false,
      },
    });

    // Also mark associated company users as deleted/inactive
    await prisma.user.updateMany({
      where: {
        subOrganization: org.name,
        role: { name: { not: 'SUPERADMIN' } },
      },
      data: {
        deletedAt: new Date(),
        isActive: false,
      },
    });

    return { success: true, message: `Company "${org.name}" moved to Trash for 30 days.` };
  },

  /** Restore a client company from Trash */
  async restoreCompany(id: string) {
    const org = await prisma.organization.findUnique({ where: { id } });
    if (!org) throw new Error('Company not found');
    if (!org.deletedAt) throw new Error('Company is not in Trash');

    await prisma.organization.update({
      where: { id },
      data: {
        deletedAt: null,
        isActive: true,
      },
    });

    // Also restore associated users
    await prisma.user.updateMany({
      where: { subOrganization: org.name, deletedAt: { not: null } },
      data: {
        deletedAt: null,
        isActive: true,
      },
    });

    return { success: true, message: `Company "${org.name}" restored successfully.` };
  },

  /** Permanently purge a client company and its records */
  async purgeCompany(id: string, superadminPassword?: string, superadminUserId?: string) {
    await verifySuperAdminPassword(superadminUserId, superadminPassword);

    const org = await prisma.organization.findUnique({ where: { id } });
    if (!org) throw new Error('Company not found');

    await safelyDeleteOrg(org.id, org.name);

    return { success: true, message: `Company "${org.name}" permanently deleted.` };
  },

  /** Move a System Admin to Trash (30-day soft delete) */
  async trashAdmin(id: string, superadminPassword?: string, superadminUserId?: string) {
    await verifySuperAdminPassword(superadminUserId, superadminPassword);

    const user = await prisma.user.findUnique({
      where: { id },
      include: { role: true },
    });
    if (!user) throw new Error('User not found');
    if (isSuperAdminRole(user.role.name)) {
      throw new Error('Cannot delete or trash root Superadmin account.');
    }
    if (user.deletedAt) throw new Error('User is already in Trash');

    await prisma.user.update({
      where: { id },
      data: {
        deletedAt: new Date(),
        isActive: false,
      },
    });

    // Invalidate sessions in Redis
    try {
      await connectRedis();
      await redis.del(`session:${id}`);
    } catch {
      // Redis unavailable
    }

    return { success: true, message: `System admin "${user.username}" moved to Trash for 30 days.` };
  },

  /** Restore a System Admin from Trash */
  async restoreAdmin(id: string) {
    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) throw new Error('User not found');
    if (!user.deletedAt) throw new Error('User is not in Trash');

    await prisma.user.update({
      where: { id },
      data: {
        deletedAt: null,
        isActive: true,
      },
    });

    return { success: true, message: `System admin "${user.username}" restored successfully.` };
  },

  /** Permanently purge a System Admin */
  async purgeAdmin(id: string, superadminPassword?: string, superadminUserId?: string) {
    await verifySuperAdminPassword(superadminUserId, superadminPassword);

    const user = await prisma.user.findUnique({
      where: { id },
      include: { role: true },
    });
    if (!user) throw new Error('User not found');
    if (isSuperAdminRole(user.role.name)) {
      throw new Error('Cannot purge root Superadmin account.');
    }

    await safelyDeleteUserIds([id]);

    return { success: true, message: `System admin "${user.username}" permanently deleted.` };
  },

  /** Automatically purge items in Trash older than 30 days */
  async autoPurgeExpiredTrash() {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    // 1. Expired users
    const expiredUsers = await prisma.user.findMany({
      where: {
        deletedAt: { lte: thirtyDaysAgo },
        role: { name: { not: 'SUPERADMIN' } },
      },
      select: { id: true },
    });
    if (expiredUsers.length > 0) {
      await safelyDeleteUserIds(expiredUsers.map((u) => u.id));
    }

    // 2. Expired organizations
    const expiredOrgs = await prisma.organization.findMany({
      where: { deletedAt: { lte: thirtyDaysAgo } },
      select: { id: true, name: true },
    });
    for (const org of expiredOrgs) {
      await safelyDeleteOrg(org.id, org.name);
    }
  },

  /** Retrieve all items currently in Trash with countdown calculation */
  async getTrash() {
    await this.autoPurgeExpiredTrash();

    const [trashedOrgs, trashedUsers] = await Promise.all([
      prisma.organization.findMany({
        where: { deletedAt: { not: null } },
        orderBy: [{ deletedAt: 'desc' }],
      }),
      prisma.user.findMany({
        where: {
          deletedAt: { not: null },
          role: { name: { not: 'SUPERADMIN' } },
        },
        include: { role: true },
        orderBy: [{ deletedAt: 'desc' }],
      }),
    ]);

    const calculateDays = (deletedAt: Date) => {
      const expiresAt = new Date(deletedAt.getTime() + 30 * 24 * 60 * 60 * 1000);
      const remainingMs = expiresAt.getTime() - Date.now();
      const daysRemaining = Math.max(0, Math.ceil(remainingMs / (24 * 60 * 60 * 1000)));
      return { expiresAt: expiresAt.toISOString(), daysRemaining };
    };

    const companies = trashedOrgs.map((org) => {
      const { expiresAt, daysRemaining } = calculateDays(org.deletedAt!);
      return {
        id: org.id,
        name: org.name,
        code: org.code,
        contactPerson: org.contactPerson,
        email: org.email,
        type: 'COMPANY' as const,
        deletedAt: org.deletedAt!.toISOString(),
        expiresAt,
        daysRemaining,
      };
    });

    const admins = trashedUsers.map((user) => {
      const { expiresAt, daysRemaining } = calculateDays(user.deletedAt!);
      return {
        id: user.id,
        username: user.username,
        companyName: user.subOrganization || 'Unassigned',
        role: user.role.name,
        type: 'ADMIN' as const,
        deletedAt: user.deletedAt!.toISOString(),
        expiresAt,
        daysRemaining,
      };
    });

    return {
      companies,
      admins,
      totalCount: companies.length + admins.length,
    };
  },

  /** Empty all trash immediately */
  async emptyTrash(superadminPassword?: string, superadminUserId?: string) {
    await verifySuperAdminPassword(superadminUserId, superadminPassword);

    const trashedOrgs = await prisma.organization.findMany({
      where: { deletedAt: { not: null } },
      select: { id: true, name: true },
    });
    for (const org of trashedOrgs) {
      await safelyDeleteOrg(org.id, org.name);
    }

    const trashedUsers = await prisma.user.findMany({
      where: {
        deletedAt: { not: null },
        role: { name: { not: 'SUPERADMIN' } },
      },
      select: { id: true },
    });
    if (trashedUsers.length > 0) {
      await safelyDeleteUserIds(trashedUsers.map((u) => u.id));
    }

    return { success: true, message: 'Trash bin emptied successfully.' };
  },

  /** Permanently purge ALL non-superadmin client and tenant data (Fresh Clean Database Reset) */
  async purgeAllData(superadminPassword?: string, superadminUserId?: string) {
    await verifySuperAdminPassword(superadminUserId, superadminPassword);

    // 1. Find all non-superadmin users
    const nonSuperadminUsers = await prisma.user.findMany({
      where: {
        role: { name: { not: 'SUPERADMIN' } },
        username: { not: 'superadmin' },
      },
      select: { id: true },
    });
    if (nonSuperadminUsers.length > 0) {
      await safelyDeleteUserIds(nonSuperadminUsers.map((u) => u.id));
    }

    // 2. Find all organizations
    const allOrgs = await prisma.organization.findMany({
      select: { id: true, name: true },
    });
    for (const org of allOrgs) {
      await safelyDeleteOrg(org.id, org.name);
    }

    // 3. Clear any remaining non-superadmin employee records
    const remainingEmployees = await prisma.employee.findMany({
      where: {
        id: { not: 1 },
      },
      select: { id: true },
    });
    if (remainingEmployees.length) {
      const empIds = remainingEmployees.map((e) => e.id);
      await prisma.employeeGeneralInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeePersonalInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeAddress.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeOtherInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.familyMember.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.academicQualification.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeExperience.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeSalaryInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeBankInfo.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeAttendanceSettings.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeAssignment.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeSalaryRecord.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.positionAssignment.deleteMany({ where: { holderEmployeeId: { in: empIds } } });
      await prisma.locationHistory.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.trip.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.trackingEvent.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.leaveBalance.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.leaveAuditLog.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.leaveApplication.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.monthlyLWPRecord.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.absenceRecord.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.attendancePunch.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.reimbursementClaim.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employeeLetterDocument.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.changeRequest.deleteMany({ where: { employeeId: { in: empIds } } });
      await prisma.employee.deleteMany({ where: { id: { in: empIds } } });
    }

    return { success: true, message: 'All tenant and client data purged successfully. Fresh clean database active.' };
  },
};

/** Superadmin Password Verification Helper */
export async function verifySuperAdminPassword(superAdminUserId?: string, passwordAttempt?: string) {
  if (!passwordAttempt || !passwordAttempt.trim()) {
    throw new Error('Superadmin password confirmation is required for this action.');
  }
  let superadmin: { passwordHash: string } | null = null;
  if (superAdminUserId) {
    superadmin = await prisma.user.findUnique({
      where: { id: superAdminUserId },
      select: { passwordHash: true },
    });
  }
  if (!superadmin) {
    superadmin = await prisma.user.findFirst({
      where: {
        OR: [
          { username: 'superadmin' },
          { role: { name: 'SUPERADMIN' } },
        ],
      },
      select: { passwordHash: true },
    });
  }
  if (!superadmin || !superadmin.passwordHash) {
    throw new Error('Superadmin verification failed.');
  }
  const valid = await bcrypt.compare(passwordAttempt.trim(), superadmin.passwordHash);
  if (!valid) {
    throw new Error('Incorrect Superadmin password. Action rejected.');
  }
}

/** Safe Cascade Deletion Helper for Users */
export async function safelyDeleteUserIds(userIds: string[]) {
  if (!userIds.length) return;

  // 1. Delete associated employee records & unbind approvers
  const employees = await prisma.employee.findMany({
    where: { userId: { in: userIds } },
    select: { id: true },
  });

  if (employees.length) {
    const empIds = employees.map((e) => e.id);

    await prisma.employeeGeneralInfo.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeePersonalInfo.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeAddress.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeOtherInfo.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.familyMember.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.academicQualification.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeExperience.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeSalaryInfo.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeBankInfo.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeAttendanceSettings.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeAssignment.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeSalaryRecord.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.positionAssignment.deleteMany({ where: { holderEmployeeId: { in: empIds } } });
    await prisma.locationHistory.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.trip.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.trackingEvent.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.leaveBalance.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.leaveAuditLog.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.leaveApplication.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.monthlyLWPRecord.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.absenceRecord.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.attendancePunch.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.reimbursementClaim.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.employeeLetterDocument.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.changeRequest.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.departmentApprover.deleteMany({ where: { hodEmployeeId: { in: empIds } } });
    await prisma.instituteApprover.deleteMany({ where: { hoiEmployeeId: { in: empIds } } });
    await prisma.globalApprover.updateMany({ where: { vcEmployeeId: { in: empIds } }, data: { vcEmployeeId: null } });
    await prisma.globalApprover.updateMany({ where: { registrarEmployeeId: { in: empIds } }, data: { registrarEmployeeId: null } });
    await prisma.orgTreeContact.deleteMany({ where: { employeeId: { in: empIds } } });
    await prisma.crmFollowUp.updateMany({ where: { assignedToId: { in: empIds } }, data: { assignedToId: null } });

    await prisma.employee.deleteMany({ where: { id: { in: empIds } } });
  }

  await prisma.employeeGeneralInfo.updateMany({
    where: { firstApproverUserId: { in: userIds } },
    data: { firstApproverUserId: null },
  });
  await prisma.employeeGeneralInfo.updateMany({
    where: { secondApproverUserId: { in: userIds } },
    data: { secondApproverUserId: null },
  });
  await prisma.employeeGeneralInfo.updateMany({
    where: { thirdApproverUserId: { in: userIds } },
    data: { thirdApproverUserId: null },
  });

  // 2. OrgTrees & Contacts created by user
  const trees = await prisma.orgTree.findMany({
    where: { createdById: { in: userIds } },
    select: { id: true },
  });
  if (trees.length) {
    const treeIds = trees.map((t) => t.id);
    await prisma.orgTreeContact.deleteMany({ where: { treeId: { in: treeIds } } });
    await prisma.orgTree.deleteMany({ where: { id: { in: treeIds } } });
  }

  // 3. WorkTasks & TaskEvents
  await prisma.workTaskEvent.deleteMany({ where: { actorUserId: { in: userIds } } });
  const tasks = await prisma.workTask.findMany({
    where: {
      OR: [
        { assignerUserId: { in: userIds } },
        { assigneeUserId: { in: userIds } },
        { extraApproverUserId: { in: userIds } },
      ],
    },
    select: { id: true },
  });
  if (tasks.length) {
    const taskIds = tasks.map((t) => t.id);
    await prisma.workTaskSubtask.deleteMany({ where: { taskId: { in: taskIds } } });
    await prisma.workTaskEvent.deleteMany({ where: { taskId: { in: taskIds } } });
    await prisma.workTask.deleteMany({ where: { id: { in: taskIds } } });
  }

  // 4. Chat & Meetings
  await prisma.chatReaction.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.chatMessage.deleteMany({ where: { senderId: { in: userIds } } });
  await prisma.chatChannelMember.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.chatChannel.deleteMany({ where: { createdById: { in: userIds } } });
  await prisma.meetingParticipant.deleteMany({ where: { userId: { in: userIds } } });
  await prisma.meetingChatMessage.deleteMany({
    where: {
      OR: [
        { senderUserId: { in: userIds } },
        { recipientUserId: { in: userIds } },
      ],
    },
  });
  await prisma.meeting.deleteMany({ where: { hostUserId: { in: userIds } } });

  // 5. Audit logs
  await prisma.auditLog.deleteMany({ where: { changedBy: { in: userIds } } });

  // Finally delete users (excluding SUPERADMIN)
  await prisma.user.deleteMany({
    where: {
      id: { in: userIds },
      role: { name: { not: 'SUPERADMIN' } },
    },
  });
}

/** Safe Cascade Deletion Helper for Organizations */
export async function safelyDeleteOrg(orgId: string, orgName: string) {
  // Find users in this organization
  const users = await prisma.user.findMany({
    where: {
      subOrganization: orgName,
      role: { name: { not: 'SUPERADMIN' } },
    },
    select: { id: true },
  });
  if (users.length) {
    await safelyDeleteUserIds(users.map((u) => u.id));
  }
  // Unlink ERP projects and Institutes
  await prisma.erpProject.updateMany({
    where: { organizationId: orgId },
    data: { organizationId: null },
  });
  await prisma.institute.updateMany({
    where: { parentOrganizationId: orgId },
    data: { parentOrganizationId: null },
  });
  await prisma.organization.delete({ where: { id: orgId } });
}
