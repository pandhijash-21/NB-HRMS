import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import { env } from '../../config/env';
import { sendPasswordResetEmail } from '../../utils/mailer';
import { encryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { passwordFromBirthDate } from '../../utils/dobPassword';
import type { LoginInput, ChangePasswordInput } from './auth.types';

const SESSION_TTL = 8 * 60 * 60; // 8 hours in seconds

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Build the { MODULE_KEY: ['READ','WRITE', ...] } permissions map from DB row. */
function buildPermissionsMap(
  permissions: Array<{
    moduleKey: string;
    canRead: boolean;
    canWrite: boolean;
    canApprove: boolean;
    canDelete: boolean;
    canExport: boolean;
  }>
): Record<string, string[]> {
  const map: Record<string, string[]> = {};
  for (const p of permissions) {
    const actions: string[] = [];
    if (p.canRead)    actions.push('READ');
    if (p.canWrite)   actions.push('WRITE');
    if (p.canApprove) actions.push('APPROVE');
    if (p.canDelete)  actions.push('DELETE');
    if (p.canExport)  actions.push('EXPORT');
    map[p.moduleKey] = actions;
  }
  return map;
}

async function storeSession(userId: string, roleId: string) {
  await connectRedis();
  await redis.set(`session:${userId}`, '1', { EX: SESSION_TTL });
  // Track user→role membership for bulk invalidation on permission changes
  await redis.sAdd(`role_users:${roleId}`, userId);
  await redis.expire(`role_users:${roleId}`, SESSION_TTL);
}

async function deleteSession(userId: string, roleId?: string) {
  await connectRedis();
  await redis.del(`session:${userId}`);
  if (roleId) await redis.sRem(`role_users:${roleId}`, userId);
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

export const authService = {
  async login(input: LoginInput) {
    const identifier = String(input.identifier).trim();
    const isEmployeeId = /^\d+$/.test(identifier);

    // 1. Find user (either employeeId login or username login for position accounts)
    const user = await prisma.user.findUnique({
      where: isEmployeeId
        ? { employeeId: Number(identifier) }
        : { username: identifier },
      include: {
        role: {
          include: { permissions: true },
        },
        employee: {
          include: { generalInfo: true },
        },
      },
    });

    if (!user) return { error: 'Invalid credentials', status: 401 } as const;
    if (!user.isActive) return { error: 'Account disabled', status: 403 } as const;

    // 2. Verify password
    const valid = await bcrypt.compare(input.password, user.passwordHash);
    if (!valid) return { error: 'Invalid credentials', status: 401 } as const;

    // 3. Build permissions map
    const permissions = buildPermissionsMap(user.role.permissions);
    const personalPerm = user.role.permissions.find((p) => p.moduleKey === 'PERSONAL_INFO');
    const employeeViewScope = personalPerm?.employeeViewScope ?? 'NONE';
    const scopeSubOrg =
      employeeViewScope === 'INSTITUTE'
        ? ((user as { subOrganization?: string | null }).subOrganization ??
          user.employee?.generalInfo?.subOrganization ??
          null)
        : null;

    // 4. Sign JWT
    const token = jwt.sign(
      {
        sub:         user.id,
        employeeId:  user.employeeId ?? null,
        roleId:      user.roleId,
        roleName:    user.role.name,
        subOrganization: scopeSubOrg,
        employeeViewScope,
        permissions,
      },
      env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    // 5. Record session in Redis
    await storeSession(user.id, user.roleId);

    // 6. Update lastLoginAt
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return {
      token,
      isFirstLogin: user.isFirstLogin,
      permissions,
      user: {
        id:         user.id,
        employeeId: user.employeeId ?? null,
        name:
          user.employeeId
            ? (user.employee?.generalInfo?.fullName ?? `Employee #${user.employeeId}`)
            : (user.username ?? 'Position Account'),
        role:       user.role.name,
        photoUrl:   user.employee?.photoUrl ?? null,
        username:   user.username ?? null,
        subOrganization: scopeSubOrg,
        employeeViewScope,
        permissions,
      },
    };
  },

  async logout(userId: string, roleId: string) {
    await deleteSession(userId, roleId);
  },

  async changePassword(userId: string, input: ChangePasswordInput) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'User not found', status: 404 } as const;

    if (!user.isFirstLogin) {
      return {
        error: 'Password can only be changed on first login. Contact an administrator to reset your password.',
        status: 403,
      } as const;
    }

    const valid = await bcrypt.compare(input.currentPassword, user.passwordHash);
    if (!valid) return { error: 'Current password is incorrect', status: 400 } as const;

    const newHash = await bcrypt.hash(input.newPassword, 12);

    await prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash:      newHash,
        adminPasswordEnc:  encryptPasswordForAdmin(input.newPassword),
        isFirstLogin:      false,
        passwordChangedAt: new Date(),
      },
    });

    // Force re-login with new password
    await deleteSession(userId, user.roleId);

    return { message: 'Password changed. Please log in again.' };
  },

  async resetPassword(targetUserId: string, requesterId: string) {
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      include: {
        employee: { include: { personalInfo: true } },
      },
    });
    if (!user) return { error: 'User not found', status: 404 } as const;

    // Default password = DOB as DDMMYYYY, fallback to 01011990
    let defaultPassword = '01011990';
    const dob = user.employee?.personalInfo?.birthDate;
    if (dob) {
      defaultPassword = passwordFromBirthDate(dob);
    }

    const newHash = await bcrypt.hash(defaultPassword, 12);

    await prisma.user.update({
      where: { id: targetUserId },
      data: {
        passwordHash: newHash,
        adminPasswordEnc: encryptPasswordForAdmin(defaultPassword),
        isFirstLogin: true,
        updatedBy:    requesterId,
      },
    });

    // Invalidate any active session for this user
    await deleteSession(targetUserId, user.roleId);

    // Fire-and-forget email notification
    const toEmail: string =
      (user.employee as any)?.generalInfo?.instituteEmail ??
      (user.employee as any)?.addresses?.[0]?.personalEmail ??
      '';
    if (toEmail) {
      sendPasswordResetEmail(toEmail, user.employeeId, defaultPassword).catch(console.error);
    }

    const loginId = user.username ?? (user.employee as any)?.generalInfo?.employeeCode ?? null;

    return {
      message: `Password reset successfully`,
      loginId,
      password: defaultPassword,
      isDefaultPassword: !dob && !user.username,
    };
  },

  async adminSetPassword(
    targetUserId: string,
    requesterId: string,
    newPassword: string,
  ) {
    const user = await prisma.user.findUnique({
      where: { id: targetUserId },
      include: { employee: { include: { generalInfo: true } } },
    });
    if (!user) return { error: 'User not found', status: 404 } as const;
    if (newPassword.length < 8) {
      return { error: 'Password must be at least 8 characters', status: 400 } as const;
    }

    const newHash = await bcrypt.hash(newPassword, 12);
    await prisma.user.update({
      where: { id: targetUserId },
      data: {
        passwordHash: newHash,
        adminPasswordEnc: encryptPasswordForAdmin(newPassword),
        isFirstLogin: true,
        updatedBy: requesterId,
      },
    });
    await deleteSession(targetUserId, user.roleId);

    return {
      loginId: user.username ?? user.employee?.generalInfo?.employeeCode ?? null,
      password: newPassword,
      message: 'Password updated',
    };
  },

  getMe(user: NonNullable<Express.Request['user']>) {
    return {
      employeeId:  user.employeeId,
      roleId:      user.roleId,
      roleName:    user.roleName,
      permissions: user.permissions,
      employeeViewScope: user.employeeViewScope ?? 'NONE',
      subOrganization: user.subOrganization ?? null,
    };
  },
};
