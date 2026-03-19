import type { NextFunction, Request, Response } from 'express';
import type { AuthRole } from './auth';
import { fail } from '../utils/response';

export function requireRole(allowed: AuthRole[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const role = req.user?.role;
    if (!role) return res.status(401).json(fail('Unauthenticated'));
    if (!allowed.includes(role)) return res.status(403).json(fail('Forbidden'));
    return next();
  };
}

