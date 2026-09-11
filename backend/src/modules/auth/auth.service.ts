import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import { env } from '../../config/env';
import { sendPasswordResetEmail } from '../../utils/mailer';
import { encryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { passwordFromBirthDate } from '../../utils/dobPassword';
import type { LoginInput, ChangePasswordInput } from './auth.types';
import { passwordMeetsPolicy, passwordPolicyIssue } from '../../utils/passwordPolicy';
import {
  assertNotLocked,
  clearLoginLock,
  recordLoginFailure,
  isExemptIdentifier,
} from './loginLock.service';
import { otpService } from './otp.service';
import { buildPermissionsMap, isSuperAdminRole, isSystemAdminRole } from './permissions-map';

const SESSION_TTL = 8 * 60 * 60; // 8 hours in seconds

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function storeSession(userId: string, roleId: string, token: string) {
  await connectRedis();
  // Overwrite any previous session — only one active login per user (all roles).
  await redis.set(`session:${userId}`, token, { EX: SESSION_TTL });
  await redis.sAdd(`role_users:${roleId}`, userId);
  await redis.expire(`role_users:${roleId}`, SESSION_TTL);
}

async function deleteSession(userId: string, roleId?: string) {
  try {
    await connectRedis();
    await redis.del(`session:${userId}`);
    if (roleId) await redis.sRem(`role_users:${roleId}`, userId);
  } catch (err) {
    console.warn('Redis session delete skipped:', err);
  }
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

export const authService = {
  async login(input: LoginInput) {
    const identifier = String(input.identifier).trim();
    const isNumericEmployeeId = /^\d+$/.test(identifier);

    const userInclude = {
      role: {
        include: { permissions: true },
      },
      employee: {
        include: { generalInfo: true },
      },
    } as const;

    // 1. Resolve user:
    //    - Priority 1: employeeGeneralInfo.employeeCode (matches '007', 'IT5', etc. even if numeric or has leading zeroes)
    //    - Priority 2: User.username (position/alias accounts)
    //    - Priority 3: Employee.id numeric primary key (if numeric)
    //    - Priority 4: Institutional or personal email
    let user = null;

    // Check by employeeCode (case-insensitive)
    const byCode = await prisma.employeeGeneralInfo.findFirst({
      where: { employeeCode: { equals: identifier, mode: 'insensitive' } },
      select: { employeeId: true },
    });
    if (byCode?.employeeId != null) {
      user = await prisma.user.findUnique({
        where: { employeeId: byCode.employeeId },
        include: userInclude,
      });
    }

    // Check by username (position accounts)
    if (!user) {
      user = await prisma.user.findFirst({
        where: { username: { equals: identifier, mode: 'insensitive' } },
        include: userInclude,
      });
    }

    // Direct fallback for root administrator identifiers ('admin', 'superadmin')
    if (!user && (identifier.toLowerCase() === 'admin' || identifier.toLowerCase() === 'superadmin')) {
      user = await prisma.user.findFirst({
        where: {
          OR: [
            { employeeId: 1 },
            { role: { name: { in: ['SUPERADMIN', 'SYSTEM_ADMIN', 'ADMIN', 'SYSTEM_ADMINISTRATOR'] } } },
          ],
        },
        include: userInclude,
      });
    }

    // If numeric, check by Employee.id (internal DB PK)
    if (!user && isNumericEmployeeId) {
      user = await prisma.user.findUnique({
        where: { employeeId: Number(identifier) },
        include: userInclude,
      });
    }

    // Check by institutional or personal email
    if (!user && identifier.includes('@')) {
      const byEmail = await prisma.employeeAddress.findFirst({
        where: {
          OR: [
            { instituteEmail: { equals: identifier, mode: 'insensitive' } },
            { personalEmail: { equals: identifier, mode: 'insensitive' } },
          ],
        },
        select: { employeeId: true },
      });
      if (byEmail?.employeeId != null) {
        user = await prisma.user.findUnique({
          where: { employeeId: byEmail.employeeId },
          include: userInclude,
        });
      }
    }

    const isExempt =
      isExemptIdentifier(identifier) ||
      (user != null &&
        (isSuperAdminRole(user.role?.name) ||
          isSystemAdminRole(user.role?.name) ||
          isExemptIdentifier(user.username)));

    if (!user) {
      if (isExempt) {
        return {
          error:
            'Account does not exist. Check your employee ID or username, or contact Admin/HR.',
          status: 404,
        } as const;
      }
      // Keep rate-limit for unknown IDs, but tell the client clearly when no account exists.
      const fail = await recordLoginFailure({ identifier });
      if (fail.status === 401) {
        return {
          error:
            'Account does not exist. Check your employee ID or username, or contact Admin/HR.',
          status: 404,
        } as const;
      }
      return { error: fail.error, status: fail.status } as const;
    }

    const aliases = [
      identifier,
      user.username ?? '',
      user.employee?.generalInfo?.employeeCode ?? '',
      user.employeeId != null ? String(user.employeeId) : '',
    ].filter(Boolean);

    if (!isExempt) {
      const locked = await assertNotLocked({
        userId: user.id,
        identifier,
        roleName: user.role?.name,
        username: user.username,
      });
      if (locked) return { error: locked.error, status: locked.status } as const;
    } else {
      // Proactively clear any stale lock if previously locked
      await clearLoginLock({ userId: user.id, aliases });
    }

    if (!user.isActive) return { error: 'Account disabled', status: 403 } as const;

    // 2. Verify password
    const valid = user.passwordHash
      ? await bcrypt.compare(input.password, user.passwordHash)
      : false;
    if (!valid) {
      if (isExempt) {
        return { error: 'Invalid username or password', status: 401 } as const;
      }
      const fail = await recordLoginFailure({
        userId: user.id,
        identifier,
        aliases,
        roleName: user.role?.name,
        username: user.username,
      });
      return { error: fail.error, status: fail.status } as const;
    }

    await clearLoginLock({ userId: user.id, aliases });

    // 3. Build permissions map
    const rolePermissions = user.role?.permissions ?? [];
    const permissions = buildPermissionsMap(rolePermissions);
    const personalPerm = rolePermissions.find((p) => p.moduleKey === 'PERSONAL_INFO');
    let employeeViewScope = personalPerm?.employeeViewScope ?? 'NONE';
    const effectiveRoleName = user.role?.name ?? (isSuperAdminRole(user.username) ? 'SUPERADMIN' : 'STAFF');
    if (isAdminRole(effectiveRoleName) || isSystemAdminRole(effectiveRoleName)) {
      if (employeeViewScope === 'NONE' || employeeViewScope === 'SELF') {
        employeeViewScope = 'UNIVERSITY';
      }
    }
    const userSubOrg = (user as { subOrganization?: string | null }).subOrganization;
    const scopeSubOrg =
      userSubOrg ??
      (employeeViewScope === 'INSTITUTE'
        ? user.employee?.generalInfo?.subOrganization ?? null
        : null);

    // 4. Sign JWT
    const token = jwt.sign(
      {
        sub:         user.id,
        employeeId:  user.employeeId ?? null,
        roleId:      user.roleId ?? user.role?.id ?? '',
        roleName:    effectiveRoleName,
        subOrganization: scopeSubOrg,
        employeeViewScope,
        permissions,
      },
      env.JWT_SECRET,
      { expiresIn: '8h' }
    );

    // 5. Record exclusive session in Redis (replaces any previous device).
    try {
      await storeSession(user.id, user.roleId, token);
    } catch (err) {
      console.error('Failed to store login session in Redis:', err);
      return {
        error: 'Unable to create a secure session. Please try again shortly.',
        status: 503,
      } as const;
    }

    // 6. Update lastLoginAt
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    // First login OR a password that no longer meets policy → force a change
    // before email OTP. Clients already gate on `isFirstLogin`.
    const mustChangePassword =
      user.isFirstLogin || !passwordMeetsPolicy(input.password);

    const emailStatus = mustChangePassword
      ? { needsEmailVerification: false, emails: [] as Awaited<ReturnType<typeof otpService.getEmailVerificationStatus>>['emails'] }
      : await otpService.getEmailVerificationStatus(user.id, user.employeeId ?? null);

    return {
      token,
      isFirstLogin: mustChangePassword,
      needsEmailVerification: emailStatus.needsEmailVerification,
      pendingEmails: emailStatus.emails.filter((e) => !e.verified),
      permissions,
      exclusiveSession: true,
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

    const valid = await bcrypt.compare(input.currentPassword, user.passwordHash);
    if (!valid) return { error: 'Current password is incorrect', status: 400 } as const;

    const currentMeetsPolicy = passwordMeetsPolicy(input.currentPassword);
    if (!user.isFirstLogin && currentMeetsPolicy) {
      return {
        error: 'Password can only be changed on first login or when it no longer meets security rules. Contact an administrator to reset your password.',
        status: 403,
      } as const;
    }

    if (input.newPassword === input.currentPassword) {
      return { error: 'New password must be different from your current password', status: 400 } as const;
    }

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
    await clearLoginLock({
      userId: targetUserId,
      aliases: [user.username ?? '', user.employeeId != null ? String(user.employeeId) : ''].filter(Boolean),
    });

    // Fire-and-forget email notification
    const toEmail: string =
      (user.employee as any)?.generalInfo?.instituteEmail ??
      (user.employee as any)?.addresses?.[0]?.personalEmail ??
      '';
    if (toEmail && user.employeeId) {
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
    const policyError = passwordPolicyIssue(newPassword);
    if (policyError) {
      return { error: policyError, status: 400 } as const;
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
    await clearLoginLock({
      userId: targetUserId,
      aliases: [user.username ?? '', user.employee?.generalInfo?.employeeCode ?? '', user.employeeId != null ? String(user.employeeId) : ''].filter(Boolean),
    });

    return {
      loginId: user.username ?? user.employee?.generalInfo?.employeeCode ?? null,
      password: newPassword,
      message: 'Password updated',
    };
  },

  async getMe(user: NonNullable<Express.Request['user']>) {
    const emailStatus = await otpService.getEmailVerificationStatus(
      user.id,
      user.employeeId ?? null,
    );
    const dbUser = await prisma.user.findUnique({
      where: { id: user.id },
      include: { role: { include: { permissions: true } } },
    });
    const permissions = dbUser?.role
      ? buildPermissionsMap(dbUser.role.permissions)
      : user.permissions;
    const personalPerm = dbUser?.role?.permissions.find((p) => p.moduleKey === 'PERSONAL_INFO');
    return {
      employeeId: user.employeeId,
      roleId: dbUser?.roleId ?? user.roleId,
      roleName: dbUser?.role?.name ?? user.roleName,
      permissions,
      employeeViewScope: personalPerm?.employeeViewScope ?? user.employeeViewScope ?? 'NONE',
      subOrganization: user.subOrganization ?? null,
      needsEmailVerification: emailStatus.needsEmailVerification,
      pendingEmails: emailStatus.emails.filter((e) => !e.verified),
    };
  },
};
