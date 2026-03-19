import type { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { fail } from '../utils/response';

export type AuthRole = 'EMPLOYEE' | 'HR' | 'ADMIN';

export type AuthUser = {
  id: string;
  role: AuthRole;
  employeeId?: number;
};

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : undefined;
  if (!token) return res.status(401).json(fail('Missing bearer token'));

  try {
    const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
    const id = String(decoded.sub ?? decoded.userId ?? decoded.id ?? '');
    const role = String(decoded.role ?? '').toUpperCase() as AuthRole;
    const employeeId = decoded.employeeId != null ? Number(decoded.employeeId) : undefined;

    if (!id || !role || !['EMPLOYEE', 'HR', 'ADMIN'].includes(role)) {
      return res.status(401).json(fail('Invalid token'));
    }

    req.user = { id, role, employeeId };
    return next();
  } catch {
    return res.status(401).json(fail('Invalid token'));
  }
}

