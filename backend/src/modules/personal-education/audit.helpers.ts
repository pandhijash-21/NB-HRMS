import type { Request } from 'express';

const AUDIT_IGNORE_FIELDS = new Set([
  'id',
  'employeeId',
  'updatedBy',
  'createdAt',
  'updatedAt',
  'deletedAt',
  'isActive',
]);

function normalizeAuditValue(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  if (typeof value === 'string') {
    const t = value.trim();
    return t === '' ? null : t;
  }
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return null;
    // Compare calendar date in UTC to avoid time-noise in logs.
    return value.toISOString().slice(0, 10);
  }
  if (typeof value === 'boolean' || typeof value === 'number') {
    return String(value);
  }
  return String(value);
}

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
  },
) {
  if (AUDIT_IGNORE_FIELDS.has(entry.fieldName)) return;
  if (!req.auditEntries) req.auditEntries = [];
  req.auditEntries.push({
    tableName: entry.tableName,
    recordId: entry.recordId,
    employeeId: entry.employeeId ?? null,
    fieldName: entry.fieldName,
    oldValue: entry.oldValue ?? null,
    newValue: entry.newValue ?? null,
    changeReason: entry.changeReason ?? null,
  });
}

/**
 * Audit only fields that actually changed.
 * Prefer passing `changedKeys` (= keys present on the request body) so a full
 * form POST that re-sends unchanged values does not spam the log.
 */
export function diffAndAudit(
  req: Request,
  args: {
    tableName: string;
    recordId: string;
    employeeId?: number | null;
    before: Record<string, unknown>;
    after: Record<string, unknown>;
    /** If set, only these keys are considered (request body keys). */
    changedKeys?: Iterable<string>;
  },
) {
  const keys = args.changedKeys
    ? [...args.changedKeys]
    : Object.keys(args.after);

  for (const key of keys) {
    if (AUDIT_IGNORE_FIELDS.has(key)) continue;
    if (!(key in args.after) && args.changedKeys) {
      // key listed but not on after — skip
    }
    const newVal = args.after[key];
    if (newVal === undefined && args.changedKeys == null) continue;

    const oldStr = normalizeAuditValue(args.before[key]);
    const newStr = normalizeAuditValue(newVal);
    if (oldStr === newStr) continue;

    pushAudit(req, {
      tableName: args.tableName,
      recordId: args.recordId,
      employeeId: args.employeeId ?? null,
      fieldName: key,
      oldValue: oldStr,
      newValue: newStr,
    });
  }
}
