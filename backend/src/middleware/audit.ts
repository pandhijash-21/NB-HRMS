import type { NextFunction, Request, Response } from 'express';
import { prisma } from '../config/prisma';
import { fail } from '../utils/response';

export type AuditEntryInput = {
  tableName: string;
  recordId: string;
  employeeId?: number | null;
  fieldName: string;
  oldValue?: string | null;
  newValue?: string | null;
  changeReason?: string | null;
};

declare global {
  namespace Express {
    interface Request {
      auditEntries?: AuditEntryInput[];
    }
  }
}

export function startAuditContext(req: Request, _res: Response, next: NextFunction) {
  req.auditEntries = [];
  next();
}

export async function flushAudit(req: Request, res: Response, next: NextFunction) {
  try {
    const entries = req.auditEntries ?? [];
    if (!entries.length) return next();

    const changedBy = req.user?.id;
    if (!changedBy) return res.status(401).json(fail('Unauthenticated'));

    await prisma.auditLog.createMany({
      data: entries.map((e) => ({
        tableName: e.tableName,
        recordId: e.recordId,
        employeeId: e.employeeId ?? null,
        fieldName: e.fieldName,
        oldValue: e.oldValue ?? null,
        newValue: e.newValue ?? null,
        changedBy,
        changeReason: e.changeReason ?? null,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent'] ? String(req.headers['user-agent']) : null,
      })),
    });

    return next();
  } catch (err) {
    return next(err);
  }
}

