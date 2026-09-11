import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import { sendAccountCreatedEmail } from '../../utils/mailer';
import type { CreateUserInput, UpdateUserInput } from './types';
import { buildCredentialView } from './credentials.util';
import { encryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { passwordFromBirthDate } from '../../utils/dobPassword';
import { clearLoginLock, loadLocksByUserIds, lockSummary } from '../auth/loginLock.service';
import { isAdminRole, isSuperAdminRole, isSystemAdminRole } from '../auth/permissions-map';

async function invalidateSession(userId: string, roleId?: string) {
  try {
    await connectRedis();
    await redis.del(`session:${userId}`);
    if (roleId) await redis.sRem(`role_users:${roleId}`, userId);
  } catch {
    // Redis unavailable — session will expire naturally
  }
}

export const userService = {
  async list(
    filters: { roleId?: string; isActive?: boolean; search?: string },
    requester?: { id?: string; roleName?: string; role?: string; subOrganization?: string | null },
  ) {
    const isSuperAdmin = isSuperAdminRole(requester?.roleName ?? requester?.role);

    const whereConditions: any[] = [];

    if (filters.roleId) {
      whereConditions.push({ roleId: filters.roleId });
    }
    if (filters.isActive !== undefined) {
      whereConditions.push({ isActive: filters.isActive });
    }

    if (!isSuperAdmin) {
      // Strictly exclude superadmin role & username
      whereConditions.push({
        role: {
          name: {
            notIn: ['SUPERADMIN', 'Superadmin', 'superadmin'],
          },
        },
      });
      whereConditions.push({
        OR: [
          { username: null },
          {
            username: {
              notIn: ['superadmin', 'SUPERADMIN', 'Superadmin'],
            },
          },
        ],
      });

      // If requester belongs to a company, scope users to their company
      if (requester?.subOrganization) {
        whereConditions.push({
          OR: [
            { subOrganization: requester.subOrganization },
            {
              employee: {
                generalInfo: {
                  subOrganization: requester.subOrganization,
                },
              },
            },
          ],
        });
      }
    }

    if (filters.search) {
      whereConditions.push({
        OR: [
          { username: { contains: filters.search, mode: 'insensitive' } },
          { subOrganization: { contains: filters.search, mode: 'insensitive' } },
          {
            employee: {
              generalInfo: {
                fullName: { contains: filters.search, mode: 'insensitive' },
              },
            },
          },
          {
            employee: {
              generalInfo: {
                employeeCode: { contains: filters.search, mode: 'insensitive' },
              },
            },
          },
        ],
      });
    }

    const rows = await prisma.user.findMany({
      where: whereConditions.length > 0 ? { AND: whereConditions } : {},
      select: {
        id:          true,
        employeeId:  true,
        username:      true,
        subOrganization: true,
        isActive:    true,
        isFirstLogin:true,
        lastLoginAt: true,
        createdAt:   true,
        role: {
          select: { id: true, name: true },
        },
        positionSlot: {
          select: {
            code: true,
            name: true,
            designation: { select: { name: true } },
          },
        },
        employee: {
          select: {
            id:         true,
            status:     true,
            photoUrl:   true,
            generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
    const locks = await loadLocksByUserIds(rows.map((u) => u.id));
    return rows.map((u) => ({ ...u, ...(locks[u.id] ?? lockSummary({ stage: 0, fails: 0, lockedUntil: null, blockedAt: null })) }));
  },

  async getCredentials(
    id: string,
    requester?: { id?: string; roleName?: string; role?: string },
  ) {
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        role: { select: { name: true } },
        employee: {
          include: {
            generalInfo: { select: { employeeCode: true, fullName: true } },
            personalInfo: { select: { birthDate: true } },
          },
        },
        positionSlot: { select: { code: true } },
      },
    });
    if (!user) return null;
    const isRequesterSuperAdmin = isSuperAdminRole(requester?.roleName ?? requester?.role);
    if (!isRequesterSuperAdmin && (isSuperAdminRole(user.role?.name) || user.username?.toLowerCase() === 'superadmin')) {
      return null;
    }
    return buildCredentialView(user);
  },

  async getById(id: string) {
    return prisma.user.findUnique({
      where: { id },
      select: {
        id:               true,
        employeeId:       true,
        isActive:         true,
        isFirstLogin:     true,
        lastLoginAt:      true,
        passwordChangedAt:true,
        createdAt:        true,
        updatedAt:        true,
        role: {
          include: { permissions: true },
        },
        employee: {
          select: {
            id:         true,
            status:     true,
            photoUrl:   true,
            generalInfo:{ select: { fullName: true, designation: true, department: true } },
          },
        },
      },
    });
  },

  async create(input: CreateUserInput, creatorId: string) {
    // Check role exists
    const role = await prisma.role.findUnique({ where: { id: input.roleId } });
    if (!role) return { error: 'Role not found', status: 404 } as const;
    if (!role.isActive) return { error: 'Role is inactive', status: 400 } as const;

    const creator = await prisma.user.findUnique({
      where: { id: creatorId },
      select: { role: { select: { name: true } } },
    });
    const isCreatorSuperAdmin = isSuperAdminRole(creator?.role?.name);

    // HIERARCHY ENFORCEMENT: Only Superadmin can create Admin accounts
    if (isAdminRole(role.name) && !isCreatorSuperAdmin) {
      return {
        error: 'Forbidden: Only Superadmin can create or assign Admin accounts',
        status: 403,
      } as const;
    }

    // ─── Employee-linked user ────────────────────────────────────────────────
    let targetEmployeeId = input.employeeId;

    if (targetEmployeeId === undefined && input.employeeCode) {
      const codeRecord = await prisma.employeeGeneralInfo.findFirst({
        where: { employeeCode: { equals: input.employeeCode.trim(), mode: 'insensitive' } },
        select: { employeeId: true },
      });
      if (codeRecord) {
        targetEmployeeId = codeRecord.employeeId;
      }
    }

    if (targetEmployeeId !== undefined) {
      // Check employee exists
      const employee = await prisma.employee.findUnique({
        where: { id: targetEmployeeId },
        include: { personalInfo: true, generalInfo: true },
      });
      if (!employee) return { error: 'Employee not found', status: 404 } as const;

      // Check user doesn't already exist
      const existing = await prisma.user.findUnique({ where: { employeeId: targetEmployeeId } });
      if (existing) return { error: 'User account already exists for this employee', status: 409 } as const;

      // Default password: DOB as DDMMYYYY (UTC), fallback to 01011990
      let defaultPassword = '01011990';
      const dob = employee.personalInfo?.birthDate;
      if (dob) {
        defaultPassword = passwordFromBirthDate(dob);
      }

      const passwordHash = await bcrypt.hash(defaultPassword, 12);

      const user = await prisma.user.create({
        data: {
          employeeId:   targetEmployeeId,
          roleId:       input.roleId,
          passwordHash,
          adminPasswordEnc: encryptPasswordForAdmin(defaultPassword),
          isActive:     true,
          isFirstLogin: true,
          createdBy:    creatorId,
        },
        select: {
          id: true, employeeId: true, username: true, isActive: true, isFirstLogin: true, createdAt: true,
          role: { select: { id: true, name: true } },
        },
      });

      // Backfill Employee.userId
      await prisma.employee.update({
        where: { id: targetEmployeeId },
        data:  { userId: user.id },
      });

      // Fire-and-forget email notification (non-blocking)
      const toEmail: string =
        (employee as any).generalInfo?.instituteEmail ?? '';
      if (toEmail) {
        sendAccountCreatedEmail(toEmail, targetEmployeeId, defaultPassword).catch(console.error);
      }

      return { user, defaultPasswordUsed: !dob };
    }

    if (input.username) {
      if (!isCreatorSuperAdmin) {
        return {
          error:
            'Alias accounts must be created via Designations → Alias accounts (pick a position).',
          status: 400,
        } as const;
      }

      const cleanUsername = input.username.trim();
      const existing = await prisma.user.findUnique({
        where: { username: cleanUsername },
      });
      if (existing) {
        return { error: 'Username is already in use by another account', status: 409 } as const;
      }

      const initialPassword = input.password?.trim() || '01011998';
      const passwordHash = await bcrypt.hash(initialPassword, 12);

      const user = await prisma.user.create({
        data: {
          username: cleanUsername,
          subOrganization: input.subOrganization?.trim() || null,
          roleId: input.roleId,
          passwordHash,
          adminPasswordEnc: encryptPasswordForAdmin(initialPassword),
          isActive: true,
          isFirstLogin: false,
          createdBy: creatorId,
        },
        select: {
          id: true,
          employeeId: true,
          username: true,
          subOrganization: true,
          roleId: true,
          isActive: true,
          isFirstLogin: true,
          createdAt: true,
        },
      });

      return { user, defaultPasswordUsed: !input.password };
    }

    return { error: 'employeeId or username is required', status: 400 } as const;
  },

  async update(id: string, input: UpdateUserInput, requesterId: string) {
    // Prevent user from changing their own role
    if (input.roleId && id === requesterId) {
      return { error: 'You cannot change your own role', status: 400 } as const;
    }

    const user = await prisma.user.findUnique({
      where: { id },
      include: { role: { select: { name: true } } },
    });
    if (!user) return { error: 'User not found', status: 404 } as const;

    const requester = await prisma.user.findUnique({
      where: { id: requesterId },
      include: { role: { select: { name: true } } },
    });
    const isRequesterSuperAdmin = isSuperAdminRole(requester?.role?.name);

    // HIERARCHY ENFORCEMENT:
    // 1. Non-superadmins cannot modify a Superadmin user at all
    if (isSuperAdminRole(user.role?.name) && !isRequesterSuperAdmin) {
      return { error: 'Forbidden: Cannot modify a Superadmin account', status: 403 } as const;
    }

    // 2. Non-superadmins cannot deactivate another System Admin
    if (input.isActive === false && isSystemAdminRole(user.role?.name) && !isRequesterSuperAdmin) {
      return { error: 'Forbidden: Only Superadmin can deactivate Admin accounts', status: 403 } as const;
    }

    // 3. Changing roles involving Admin tiers requires Superadmin
    if (input.roleId) {
      const targetRole = await prisma.role.findUnique({ where: { id: input.roleId } });
      if (!targetRole) return { error: 'Role not found', status: 404 } as const;

      const isTargetAdmin = isAdminRole(targetRole.name);
      const isCurrentAdmin = isAdminRole(user.role?.name);
      if ((isTargetAdmin || isCurrentAdmin) && !isRequesterSuperAdmin) {
        return {
          error: 'Forbidden: Only Superadmin can assign, elevate, or modify Admin roles',
          status: 403,
        } as const;
      }
    }

    const updated = await prisma.user.update({
      where: { id },
      data: {
        ...(input.roleId   ? { roleId: input.roleId }     : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
        updatedBy: requesterId,
      },
      select: { id: true, employeeId: true, isActive: true, role: { select: { id: true, name: true } } },
    });

    // Role changed → force re-login for new permissions
    if (input.roleId && input.roleId !== user.roleId) {
      await invalidateSession(id, user.roleId);
    }

    // Deactivated → kick session
    if (input.isActive === false) {
      await invalidateSession(id, user.roleId);
    }

    return updated;
  },

  async softDelete(id: string, requesterId: string) {
    if (id === requesterId) {
      return { error: 'Cannot deactivate your own account', status: 400 } as const;
    }

    const user = await prisma.user.findUnique({
      where: { id },
      include: { role: { select: { name: true } } },
    });
    if (!user) return { error: 'User not found', status: 404 } as const;

    const requester = await prisma.user.findUnique({
      where: { id: requesterId },
      include: { role: { select: { name: true } } },
    });
    const isRequesterSuperAdmin = isSuperAdminRole(requester?.role?.name);

    // HIERARCHY ENFORCEMENT:
    if (isSuperAdminRole(user.role?.name)) {
      return { error: 'Forbidden: Cannot deactivate a Superadmin account', status: 403 } as const;
    }
    if (isSystemAdminRole(user.role?.name) && !isRequesterSuperAdmin) {
      return { error: 'Forbidden: Only Superadmin can deactivate Admin accounts', status: 403 } as const;
    }

    await prisma.user.update({
      where: { id },
      data:  { isActive: false, updatedBy: requesterId },
    });

    await invalidateSession(id, user.roleId);

    return { message: 'User deactivated' };
  },

  async unblockLogin(id: string, requesterId: string) {
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        role: { select: { name: true } },
        employee: { select: { generalInfo: { select: { employeeCode: true } } } },
      },
    });
    if (!user) return { error: 'User not found', status: 404 } as const;

    const requester = await prisma.user.findUnique({
      where: { id: requesterId },
      include: { role: { select: { name: true } } },
    });
    const isRequesterSuperAdmin = isSuperAdminRole(requester?.role?.name);

    // HIERARCHY ENFORCEMENT:
    if (isSuperAdminRole(user.role?.name) && !isRequesterSuperAdmin) {
      return { error: 'Forbidden: Cannot modify a Superadmin account', status: 403 } as const;
    }
    if (isSystemAdminRole(user.role?.name) && !isRequesterSuperAdmin) {
      return { error: 'Forbidden: Only Superadmin can unblock Admin accounts', status: 403 } as const;
    }

    await clearLoginLock({
      userId: id,
      aliases: [
        user.username ?? '',
        user.employee?.generalInfo?.employeeCode ?? '',
        user.employeeId != null ? String(user.employeeId) : '',
      ].filter(Boolean),
    });
    // Reactivate account if inactive, and update audit
    await prisma.user.update({
      where: { id },
      data: { isActive: true, updatedBy: requesterId },
    });
    await invalidateSession(id, user.roleId);

    return {
      message: 'Login unblocked and account activated. The user can sign in now.',
      updatedBy: requesterId,
    };
  },
};
