import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import { sendAccountCreatedEmail } from '../../utils/mailer';
import type { CreateUserInput, UpdateUserInput } from './types';
import { buildCredentialView } from './credentials.util';
import { encryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { clearLoginLock, loadLocksByUserIds, lockSummary } from '../auth/loginLock.service';

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
  async list(filters: { roleId?: string; isActive?: boolean; search?: string }) {
    const rows = await prisma.user.findMany({
      where: {
        ...(filters.roleId   ? { roleId: filters.roleId }     : {}),
        ...(filters.isActive !== undefined ? { isActive: filters.isActive } : {}),
        ...(filters.search
          ? {
              employee: {
                generalInfo: {
                  fullName: { contains: filters.search, mode: 'insensitive' },
                },
              },
            }
          : {}),
      },
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

  async getCredentials(id: string) {
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
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

    // ─── Employee-linked user ────────────────────────────────────────────────
    if (input.employeeId !== undefined) {
      // Check employee exists
      const employee = await prisma.employee.findUnique({
        where: { id: input.employeeId },
        include: { personalInfo: true },
      });
      if (!employee) return { error: 'Employee not found', status: 404 } as const;

      // Check user doesn't already exist
      const existing = await prisma.user.findUnique({ where: { employeeId: input.employeeId } });
      if (existing) return { error: 'User account already exists for this employee', status: 409 } as const;

      // Default password: DOB as DDMMYYYY, fallback to 01011990
      let defaultPassword = '01011990';
      const dob = employee.personalInfo?.birthDate;
      if (dob) {
        const d = String(dob.getDate()).padStart(2, '0');
        const m = String(dob.getMonth() + 1).padStart(2, '0');
        const y = dob.getFullYear();
        defaultPassword = `${d}${m}${y}`;
      }

      const passwordHash = await bcrypt.hash(defaultPassword, 12);

      const user = await prisma.user.create({
        data: {
          employeeId:   input.employeeId,
          roleId:       input.roleId,
          passwordHash,
          adminPasswordEnc: encryptPasswordForAdmin(defaultPassword),
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
        where: { id: input.employeeId },
        data:  { userId: user.id },
      });

      // Fire-and-forget email notification (non-blocking)
      const toEmail: string =
        (employee as any).generalInfo?.instituteEmail ?? '';
      if (toEmail) {
        sendAccountCreatedEmail(toEmail, input.employeeId, defaultPassword).catch(console.error);
      }

      return { user, defaultPasswordUsed: !dob };
    }

    if (input.username) {
      return {
        error:
          'Alias accounts must be created via Designations → Alias accounts (pick a position).',
        status: 400,
      } as const;
    }

    return { error: 'employeeId is required', status: 400 } as const;
  },

  async update(id: string, input: UpdateUserInput, requesterId: string) {
    // Prevent admin from changing their own role
    if (input.roleId && id === requesterId) {
      return { error: 'You cannot change your own role', status: 400 } as const;
    }

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) return { error: 'User not found', status: 404 } as const;

    if (input.roleId) {
      const role = await prisma.role.findUnique({ where: { id: input.roleId } });
      if (!role) return { error: 'Role not found', status: 404 } as const;
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

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) return { error: 'User not found', status: 404 } as const;

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
      include: { employee: { select: { generalInfo: { select: { employeeCode: true } } } } },
    });
    if (!user) return { error: 'User not found', status: 404 } as const;

    await clearLoginLock({
      userId: id,
      aliases: [
        user.username ?? '',
        user.employee?.generalInfo?.employeeCode ?? '',
        user.employeeId != null ? String(user.employeeId) : '',
      ].filter(Boolean),
    });
    await invalidateSession(id, user.roleId);

    return {
      message: 'Login unblocked. The user can sign in again.',
      updatedBy: requesterId,
    };
  },
};
