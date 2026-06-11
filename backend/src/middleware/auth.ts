import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { redis, connectRedis } from '../config/redis';
import { fail } from '../utils/response';

export async function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined;
  if (!token) return res.status(401).json(fail('Missing bearer token'));

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
    const userId = String(decoded.sub ?? '');

    // Validate session still exists in Redis (honours logout / permission revocation)
    try {
      await connectRedis();
      const sessionExists = await redis.get(`session:${userId}`);
      if (!sessionExists) {
        return res.status(401).json(fail('Session expired. Please log in again.'));
      }
    } catch {
      // Redis unavailable — fall through and accept the JWT as-is
      // (fail-open to avoid locking everyone out on Redis downtime)
    }

    req.user = {
      id:          userId,
      employeeId:  decoded.employeeId,
      roleId:      decoded.roleId,
      roleName:    decoded.roleName,
      role:        decoded.roleName,  // backward compat for existing requireRole checks
      subOrganization: (decoded as any).subOrganization ?? null,
      permissions: decoded.permissions ?? {},
    };

    return next();
  } catch {
    return res.status(401).json(fail('Invalid or expired token'));
  }
}
