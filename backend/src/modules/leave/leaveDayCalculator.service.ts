import { prisma } from '../../config/prisma';

function toUtcDateOnly(d: Date): Date {
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function addDaysUtc(dateOnly: Date, days: number): Date {
  const d = new Date(dateOnly);
  d.setUTCDate(d.getUTCDate() + days);
  return d;
}

type LeaveTypeConfig = {
  skipPublicHolidays: boolean;
  skipWeekends: boolean;
  allowHalfDay: boolean;
};

async function getLeaveTypeConfig(leaveTypeId: string): Promise<LeaveTypeConfig> {
  const lt = await prisma.leaveType.findUnique({
    where: { id: leaveTypeId },
    select: { skipPublicHolidays: true, skipWeekends: true, allowHalfDay: true },
  });
  if (!lt) throw new Error('Leave type not found');
  return lt;
}

async function getHolidaySet(year: number): Promise<Set<string>> {
  const rows = await prisma.publicHoliday.findMany({
    where: { year },
    select: { date: true },
  });
  const set = new Set<string>();
  for (const r of rows) {
    const d = toUtcDateOnly(r.date);
    set.add(d.toISOString().slice(0, 10));
  }
  return set;
}

function isSundayUtc(dateOnly: Date): boolean {
  return dateOnly.getUTCDay() === 0;
}

function isWeekendUtc(dateOnly: Date): boolean {
  const day = dateOnly.getUTCDay();
  return day === 0 || day === 6;
}

/**
 * Calculates leave days inclusive between two dates (UTC date-only),
 * skipping Sundays always, and optionally skipping weekends/holidays based on LeaveType flags.
 *
 * Rules:
 * - Always skip Sundays.
 * - If isHalfDay=true => fromDate and toDate must be same calendar day, returns 0.5.
 */
export async function calculateLeaveDays(params: {
  fromDate: Date;
  toDate: Date;
  isHalfDay: boolean;
  leaveTypeId: string;
}): Promise<number> {
  const { fromDate, toDate, isHalfDay, leaveTypeId } = params;

  const cfg = await getLeaveTypeConfig(leaveTypeId);

  const from = toUtcDateOnly(fromDate);
  const to = toUtcDateOnly(toDate);
  if (to.getTime() < from.getTime()) throw new Error('toDate must be on/after fromDate');

  if (isHalfDay) {
    if (!cfg.allowHalfDay) throw new Error('Half-day is not allowed for this leave type');
    if (from.getTime() !== to.getTime()) throw new Error('Half-day leave must be a single day');
    // Still respect Sunday rule: half-day on Sunday counts as 0
    if (isSundayUtc(from)) return 0;
    if (cfg.skipWeekends && isWeekendUtc(from)) return 0;
    if (cfg.skipPublicHolidays) {
      const hs = await getHolidaySet(from.getUTCFullYear());
      if (hs.has(from.toISOString().slice(0, 10))) return 0;
    }
    return 0.5;
  }

  const years = new Set<number>();
  for (let d = new Date(from); d.getTime() <= to.getTime(); d = addDaysUtc(d, 1)) {
    years.add(d.getUTCFullYear());
  }
  const holidaySets: Record<number, Set<string>> = {};
  if (cfg.skipPublicHolidays) {
    for (const y of years) holidaySets[y] = await getHolidaySet(y);
  }

  let total = 0;
  for (let d = new Date(from); d.getTime() <= to.getTime(); d = addDaysUtc(d, 1)) {
    if (isSundayUtc(d)) continue;
    if (cfg.skipWeekends && isWeekendUtc(d)) continue;
    if (cfg.skipPublicHolidays) {
      const key = d.toISOString().slice(0, 10);
      if (holidaySets[d.getUTCFullYear()]?.has(key)) continue;
    }
    total += 1;
  }
  return total;
}

