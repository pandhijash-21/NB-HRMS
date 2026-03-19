import type { Request } from 'express';
import { mask } from '../../utils/crypto';

export function pushAudit(
  req: Request,
  entry: {
    tableName: string;
    recordId: string;
    employeeId?: number | null;
    fieldName: string;
    oldValue?: string | null;
    newValue?: string | null;
    changeReason?: string | null;
    sensitive?: boolean;
  }
) {
  if (!req.auditEntries) req.auditEntries = [];
  req.auditEntries.push({
    tableName: entry.tableName,
    recordId: entry.recordId,
    employeeId: entry.employeeId ?? null,
    fieldName: entry.fieldName,
    oldValue: entry.sensitive && entry.oldValue ? mask(entry.oldValue) : entry.oldValue ?? null,
    newValue: entry.sensitive && entry.newValue ? mask(entry.newValue) : entry.newValue ?? null,
    changeReason: entry.changeReason ?? null,
  });
}

export function diffAndAudit(
  req: Request,
  args: {
    tableName: string;
    recordId: string;
    employeeId?: number | null;
    before: Record<string, unknown>;
    after: Record<string, unknown>;
    sensitiveFields?: Set<string>;
  }
) {
  const sensitive = args.sensitiveFields ?? new Set<string>();
  for (const [key, newVal] of Object.entries(args.after)) {
    if (newVal === undefined) continue;
    const oldVal = args.before[key];
    const oldStr = oldVal == null ? null : String(oldVal);
    const newStr = newVal == null ? null : String(newVal);
    if (oldStr === newStr) continue;
    pushAudit(req, {
      tableName: args.tableName,
      recordId: args.recordId,
      employeeId: args.employeeId ?? null,
      fieldName: key,
      oldValue: oldStr,
      newValue: newStr,
      sensitive: sensitive.has(key),
    });
  }
}

