import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { redis, connectRedis } from '../config/redis';
import { fail } from '../utils/response';

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  const bearer = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
  const queryToken = typeof req.query.token === 'string' ? req.query.token : undefined;
  const token = bearer || queryToken;
  if (!token) return res.status(401).json(fail('Missing bearer token'));

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
    const userId = String(decoded.sub ?? '');

    // Validate session still exists in Redis (honours logout / permission revocation)
    try {
      await connectRedis();
      const sessionToken = await redis.get(`session:${userId}`);
      if (!sessionToken || sessionToken !== token) {
        return res.status(401).json(fail('Session expired or logged in from another device. Please log in again.'));
      }
    } catch {
      // Redis unavailable — fall through and accept the JWT as-is
      // (fail-open to avoid locking everyone out on Redis downtime)
    }

    req.user = {
      id:          userId,
      employeeId:  decoded.employeeId as number | null | undefined,
      roleId:      decoded.roleId as string,
      roleName:    decoded.roleName as string,
      role:        decoded.roleName as string,
      subOrganization: (decoded.subOrganization as string | null | undefined) ?? null,
      employeeViewScope: (decoded.employeeViewScope as 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY' | undefined) ?? 'NONE',
      permissions: (decoded.permissions as Record<string, string[]>) ?? {},
    };

    return next();
  } catch {
    return res.status(401).json(fail('Invalid or expired token'));
  }
}
