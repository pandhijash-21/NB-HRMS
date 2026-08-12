import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { redis, connectRedis } from '../config/redis';
import { fail } from '../utils/response';

/** One active JWT per user id — newer login overwrites Redis and kicks older devices. */
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
        return res.status(401).json(
          fail('Session expired or logged in from another device. Please log in again.'),
        );
      }
    } catch (err) {
      // Fail closed: exclusive sessions require Redis. Do not accept bare JWTs.
      console.error('Redis session validation failed:', err);
      return res.status(503).json(
        fail('Session service temporarily unavailable. Please try again shortly.'),
      );
    }

    req.user = {
      id: userId,
      employeeId: decoded.employeeId as number | null | undefined,
      roleId: decoded.roleId as string,
      roleName: decoded.roleName as string,
      role: decoded.roleName as string,
      subOrganization: (decoded.subOrganization as string | null | undefined) ?? null,
      employeeViewScope:
        (decoded.employeeViewScope as
          | 'NONE'
          | 'SELF'
          | 'INSTITUTE'
          | 'UNIVERSITY'
          | undefined) ?? 'NONE',
      permissions: (decoded.permissions as Record<string, string[]>) ?? {},
    };

    return next();
  } catch {
    return res.status(401).json(fail('Invalid or expired token'));
  }
}
