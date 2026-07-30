import { prisma } from '../../config/prisma';

/** Normalize punch IDs for comparison (trim; keep as-is for exact unique lookup). */
export function normalizePunchId(raw: string): string {
  return raw.trim();
}

/**
 * Map machine CardNO / Empcode → HRMS employeeId via EmployeeGeneralInfo.punchId.
 * Profile field "Punch ID" MUST equal the machine CardNO (same digits as string).
 * Never matches by name or employeeCode.
 */
export async function resolveEmployeeIdByPunchId(
  empcode: string,
): Promise<number | null> {
  const code = normalizePunchId(empcode);
  if (!code) return null;

  const exact = await prisma.employeeGeneralInfo.findFirst({
    where: { punchId: code },
    select: { employeeId: true },
  });
  if (exact) return exact.employeeId;

  // Fallback: strip leading zeros on both sides (0001 ↔ 1)
  const stripped = code.replace(/^0+/, '') || '0';
  if (stripped !== code) {
    const byStripped = await prisma.employeeGeneralInfo.findFirst({
      where: {
        OR: [{ punchId: stripped }, { punchId: code.padStart(4, '0') }],
      },
      select: { employeeId: true },
    });
    if (byStripped) return byStripped.employeeId;
  }

  return null;
}

export type PunchIdEmployee = { employeeId: number; fullName: string | null };

/** Bulk load punchId → { employeeId, fullName } for sync / preview. */
export async function loadPunchIdEmployeeMap(): Promise<Map<string, PunchIdEmployee>> {
  const rows = await prisma.employeeGeneralInfo.findMany({
    where: { punchId: { not: null } },
    select: { punchId: true, employeeId: true, fullName: true },
  });
  const map = new Map<string, PunchIdEmployee>();
  for (const r of rows) {
    if (!r.punchId) continue;
    const entry: PunchIdEmployee = {
      employeeId: r.employeeId,
      fullName: r.fullName ?? null,
    };
    const n = normalizePunchId(r.punchId);
    map.set(n, entry);
    const stripped = n.replace(/^0+/, '') || '0';
    if (!map.has(stripped)) map.set(stripped, entry);
  }
  return map;
}

/** Bulk load punchId → employeeId map for a sync batch. */
export async function loadPunchIdMap(): Promise<Map<string, number>> {
  const full = await loadPunchIdEmployeeMap();
  const map = new Map<string, number>();
  for (const [k, v] of full) map.set(k, v.employeeId);
  return map;
}

export function lookupPunchIdMap(map: Map<string, number>, empcode: string): number | null {
  const code = normalizePunchId(empcode);
  if (!code) return null;
  if (map.has(code)) return map.get(code)!;
  const stripped = code.replace(/^0+/, '') || '0';
  if (map.has(stripped)) return map.get(stripped)!;
  return null;
}

export function lookupPunchIdEmployee(
  map: Map<string, PunchIdEmployee>,
  empcode: string,
): PunchIdEmployee | null {
  const code = normalizePunchId(empcode);
  if (!code) return null;
  if (map.has(code)) return map.get(code)!;
  const stripped = code.replace(/^0+/, '') || '0';
  if (map.has(stripped)) return map.get(stripped)!;
  return null;
}
