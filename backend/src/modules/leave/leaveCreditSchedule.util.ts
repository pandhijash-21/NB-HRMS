export type CreditEntry = { month: number; day: number; days: number };

export function parseCreditSchedule(schedule: unknown): CreditEntry[] {
  if (!schedule || typeof schedule !== 'object') return [];
  const credits = (schedule as { credits?: unknown }).credits;
  if (!Array.isArray(credits)) return [];
  return credits
    .map((c) => ({
      month: Number((c as CreditEntry).month),
      day: Number((c as CreditEntry).day),
      days: Number((c as CreditEntry).days),
    }))
    .filter((c) => c.month >= 1 && c.month <= 12 && c.day >= 1 && c.day <= 31 && c.days > 0);
}

function creditDate(year: number, month: number, day: number): Date {
  return new Date(Date.UTC(year, month - 1, day));
}

/** Scheduled credit events that should have run on or before `asOf` (UTC). */
export function creditsDueByDate(schedule: unknown, year: number, asOf: Date = new Date()): CreditEntry[] {
  const entries = parseCreditSchedule(schedule);
  const asOfUtc = Date.UTC(asOf.getUTCFullYear(), asOf.getUTCMonth(), asOf.getUTCDate());
  return entries.filter((c) => creditDate(year, c.month, c.day).getTime() <= asOfUtc);
}

export function expectedTotalCredited(schedule: unknown, year: number, asOf: Date = new Date()): number {
  return creditsDueByDate(schedule, year, asOf).reduce((sum, c) => sum + c.days, 0);
}

export function creditAuditContext(leaveCode: string, year: number, month: number, day: number): string {
  return `AutoCredit:${leaveCode}:${year}:${month}-${day}`;
}

export function midYearTransitionContext(leaveCode: string, year: number): string {
  return `MidYearTransition:${leaveCode}:${year}`;
}

/** True when this credit is not the first event in a multi-tranche schedule (e.g. Jul after Jan). */
export function isMidYearCredit(schedule: unknown, credit: CreditEntry): boolean {
  const sorted = parseCreditSchedule(schedule).sort(
    (a, b) => a.month - b.month || a.day - b.day,
  );
  if (sorted.length < 2) return false;
  const first = sorted[0];
  return credit.month !== first.month || credit.day !== first.day;
}
