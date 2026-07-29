import { prisma } from '../../config/prisma';

/** Normalize punch IDs for comparison (trim; keep as-is for exact unique lookup). */
export function normalizePunchId(raw: string): string {
  return raw.trim();
}

/**
 * Map machine Empcode → HRMS employeeId via EmployeeGeneralInfo.punchId.
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

/** Bulk load punchId → employeeId map for a sync batch. */
export async function loadPunchIdMap(): Promise<Map<string, number>> {
  const rows = await prisma.employeeGeneralInfo.findMany({
    where: { punchId: { not: null } },
    select: { punchId: true, employeeId: true },
  });
  const map = new Map<string, number>();
  for (const r of rows) {
    if (!r.punchId) continue;
    const n = normalizePunchId(r.punchId);
    map.set(n, r.employeeId);
    const stripped = n.replace(/^0+/, '') || '0';
    if (!map.has(stripped)) map.set(stripped, r.employeeId);
  }
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
