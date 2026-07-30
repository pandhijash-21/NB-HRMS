/**
 * Day punch-in / punch-out derivation.
 *
 * - Punch-IN = earliest punch of any source (never "overwritten").
 * - Punch-OUT:
 *   - If employee used phone (MOBILE_APP) twice → 2nd mobile punch locks OUT.
 *   - Else machine (ESSL / ETIMEOFFICE) → last machine punch is OUT
 *     (later machine scans can move OUT later; stored rows are never updated).
 * - Geofenced mobile punch creation is unchanged; this only affects summary fields.
 */

export type DayPunchLike = {
  punchAt: Date | string;
  source: string;
};

function iso(p: DayPunchLike): string {
  return new Date(p.punchAt).toISOString();
}

function isMobile(source: string): boolean {
  return String(source) === 'MOBILE_APP';
}

function isMachine(source: string): boolean {
  const s = String(source);
  return s === 'ESSL' || s === 'ETIMEOFFICE';
}

export function deriveDayInOut(punchesAsc: DayPunchLike[]): {
  firstIn: string | null;
  lastOut: string | null;
} {
  if (!punchesAsc.length) return { firstIn: null, lastOut: null };

  const ordered = [...punchesAsc].sort(
    (a, b) => new Date(a.punchAt).getTime() - new Date(b.punchAt).getTime(),
  );
  const firstIn = iso(ordered[0]!);

  const mobile = ordered.filter((p) => isMobile(p.source));
  if (mobile.length >= 2) {
    // Phone's 2nd punch locks punch-out (done).
    return { firstIn, lastOut: iso(mobile[1]!) };
  }

  const machine = ordered.filter((p) => isMachine(p.source));
  if (machine.length >= 2) {
    // Last machine punch is punch-out (can advance as more scans sync in).
    return { firstIn, lastOut: iso(machine[machine.length - 1]!) };
  }

  // Mixed / single-side leftovers after firstIn
  const afterIn = ordered.filter((p) => iso(p) !== firstIn);
  if (!afterIn.length) return { firstIn, lastOut: null };

  // Prefer last machine after IN; else a single phone punch after machine IN.
  const machineAfter = afterIn.filter((p) => isMachine(p.source));
  if (machineAfter.length) {
    return { firstIn, lastOut: iso(machineAfter[machineAfter.length - 1]!) };
  }

  const mobileAfter = afterIn.filter((p) => isMobile(p.source));
  if (mobileAfter.length) {
    return { firstIn, lastOut: iso(mobileAfter[mobileAfter.length - 1]!) };
  }

  // Admin / other sources after IN
  return { firstIn, lastOut: iso(afterIn[afterIn.length - 1]!) };
}
