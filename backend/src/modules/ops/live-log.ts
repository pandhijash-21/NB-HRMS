export type LiveLogEntry = {
  id: string;
  at: string;
  method: string;
  path: string;
  status: number;
  ms: number;
  userId?: string;
  userRole?: string;
  employeeId?: number;
  ip?: string;
  scope?: string;
  note?: string;
};

const MAX = 500;
const buffer: LiveLogEntry[] = [];

export function pushLiveLog(entry: Omit<LiveLogEntry, 'id' | 'at'> & { at?: string }) {
  const row: LiveLogEntry = {
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    at: entry.at || new Date().toISOString(),
    method: entry.method,
    path: entry.path,
    status: entry.status,
    ms: entry.ms,
    userId: entry.userId,
    userRole: entry.userRole,
    employeeId: entry.employeeId,
    ip: entry.ip,
    scope: entry.scope,
    note: entry.note,
  };
  buffer.unshift(row);
  if (buffer.length > MAX) buffer.length = MAX;
  return row;
}

export function listLiveLogs(limit = 100): LiveLogEntry[] {
  return buffer.slice(0, Math.max(1, Math.min(limit, MAX)));
}

export function clearLiveLogs() {
  buffer.length = 0;
}
