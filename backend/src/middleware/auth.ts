import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { redis, connectRedis } from '../config/redis';
import { prisma } from '../config/prisma';
import { fail } from '../utils/response';
import {
  permissionsForRole,
  getLiveUserRole,
  isSystemAdminRole,
  isSuperAdminRole,
  resolveSystemAdminPermissions,
} from '../modules/auth/permissions-map';

const SESSION_TTL = 8 * 60 * 60;

/** One active JWT per user id — newer login overwrites Redis and kicks older devices immediately. */
export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  const bearer = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
  const queryToken = typeof req.query.token === 'string' ? req.query.token : undefined;
  const token = bearer || queryToken;
  if (!token) return res.status(401).json(fail('Missing bearer token'));

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
    const userId = String(decoded.sub ?? '');
    if (!userId) {
      return res.status(401).json(fail('Invalid or expired token'));
    }

    try {
      await connectRedis();
      const sessionToken = await redis.get(`session:${userId}`);
      if (!sessionToken || sessionToken !== token) {
        const isDisplaced = Boolean(sessionToken && sessionToken !== token);
        return res.status(401).json(
          fail(
            isDisplaced
              ? 'Session displaced by another sign-in. Please log in again.'
              : 'Session expired. Please log in again.',
          ),
        );
      } else {
        // Sliding expiration window: extend active session TTL (30 days for Remember Me, 8h default)
        const isRememberMe = Boolean(decoded.rememberMe);
        const sessionTtl = isRememberMe ? 30 * 24 * 60 * 60 : SESSION_TTL;
        await redis.expire(`session:${userId}`, sessionTtl);
      }
    } catch (err) {
      // Fail closed: exclusive sessions require Redis. Do not accept bare JWTs.
      console.error('Redis session validation failed:', err);
      return res.status(503).json(
        fail('Session service temporarily unavailable. Please try again shortly.'),
      );
    }

    let activeRoleId = String(decoded.roleId ?? '');
    let activeRoleName = String(decoded.roleName ?? '');
    let companyAdminGranted = decoded.companyAdminGranted === true;
    try {
      const liveUserRole = await getLiveUserRole(userId);
      if (liveUserRole) {
        activeRoleId = liveUserRole.roleId;
        activeRoleName = liveUserRole.roleName;
        companyAdminGranted = liveUserRole.companyAdminGranted;
      }
    } catch {}

    const jwtPermissions = (decoded.permissions as Record<string, string[]>) ?? {};
    let permissions = jwtPermissions;
    let employeeViewScope =
      (decoded.employeeViewScope as
        | 'NONE'
        | 'SELF'
        | 'INSTITUTE'
        | 'UNIVERSITY'
        | undefined) ?? 'NONE';
    let organizationId =
      (decoded.organizationId as string | null | undefined) ?? null;
    const subOrganization =
      (decoded.subOrganization as string | null | undefined) ?? null;

    try {
      if (isSystemAdminRole(activeRoleName) && !isSuperAdminRole(activeRoleName)) {
        const orgLive = await resolveSystemAdminPermissions(subOrganization);
        if (orgLive) {
          permissions = orgLive.permissions;
          employeeViewScope = orgLive.employeeViewScope;
          organizationId = orgLive.organizationId;
        }
      } else {
        const live = await permissionsForRole(activeRoleId);
        if (live) {
          permissions = live.permissions;
          employeeViewScope = live.employeeViewScope;
        }
      }
    } catch (err) {
      console.warn('Live role permissions lookup failed; using JWT permissions:', err);
    }

    req.user = {
      id: userId,
      employeeId: decoded.employeeId as number | null | undefined,
      roleId: activeRoleId,
      roleName: activeRoleName,
      role: activeRoleName,
      subOrganization,
      organizationId,
      employeeViewScope,
      companyAdminGranted,
      permissions,
      rememberMe: Boolean(decoded.rememberMe),
      token,
    };

    return next();
  } catch {
    return res.status(401).json(fail('Invalid or expired token'));
  }
}
