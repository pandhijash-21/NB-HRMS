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
      /** Prevent double-flush when both finish hook and flushAudit middleware run. */
      auditFlushed?: boolean;
    }
  }
}

async function writeAuditEntries(req: Request): Promise<void> {
  if (req.auditFlushed) return;
  const entries = req.auditEntries ?? [];
  if (!entries.length) {
    req.auditFlushed = true;
    return;
  }

  const changedBy = req.user?.id;
  if (!changedBy) return;

  req.auditFlushed = true;
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
}

/**
 * Controllers typically `return res.json(...)` without calling `next()`, so a
 * post-handler `flushAudit` middleware never runs. Hook response finish here.
 */
export function startAuditContext(req: Request, res: Response, next: NextFunction) {
  req.auditEntries = [];
  req.auditFlushed = false;

  const flush = () => {
    void writeAuditEntries(req).catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[audit] flush failed', err);
    });
  };

  res.on('finish', flush);
  res.on('close', flush);
  next();
}

export async function flushAudit(req: Request, res: Response, next: NextFunction) {
  try {
    const entries = req.auditEntries ?? [];
    if (!entries.length) return next();

    const changedBy = req.user?.id;
    if (!changedBy) return res.status(401).json(fail('Unauthenticated'));

    await writeAuditEntries(req);
    return next();
  } catch (err) {
    return next(err);
  }
}
