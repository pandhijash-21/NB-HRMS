import { prisma } from '../../config/prisma';
import { randomUUID } from 'crypto';
import { deriveDayInOut } from './dayPunch.rules';
import { evaluateWebAttendanceGate } from './webAttendanceGate';
import { notifyAdminsWebAttendance } from './webAttendanceNotify';

const IST_OFFSET_MIN = 330;
const IST_OFFSET_MS = IST_OFFSET_MIN * 60 * 1000;
const DEFAULT_POLICY = {
  id: 'default' as const,
  defaultPunchInTime: '10:00',
  defaultPunchOutTime: '19:00',
  punchInBufferMinutes: 10,
  punchOutBufferMinutes: 10,
  maxBufferDaysPerMonth: 2,
  halfDayWindows: [] as Array<{ punchIn: string; punchOut: string }>,
};

type HalfDayWindow = { punchIn: string; punchOut: string };

function normalizeHalfDayWindows(raw: unknown): HalfDayWindow[] {
  if (!Array.isArray(raw)) return [];
  const out: HalfDayWindow[] = [];
  for (const item of raw) {
    if (!item || typeof item !== 'object') continue;
    const punchIn = String((item as any).punchIn ?? (item as any).checkIn ?? '').trim();
    const punchOut = String((item as any).punchOut ?? (item as any).checkOut ?? '').trim();
    if (!/^\d{2}:\d{2}$/.test(punchIn) || !/^\d{2}:\d{2}$/.test(punchOut)) continue;
    const start = parseHmToMinutes(punchIn);
    const end = parseHmToMinutes(punchOut);
    if (end <= start) continue;
    out.push({ punchIn, punchOut });
  }
  return out;
}

function fitsHalfDayWindow(
  windows: HalfDayWindow[],
  firstIn: string | null,
  lastOut: string | null,
): boolean {
  if (!windows.length || !firstIn || !lastOut) return false;
  const inMin = minutesInIstDayFromUtcDate(new Date(firstIn));
  const outMin = minutesInIstDayFromUtcDate(new Date(lastOut));
  if (!(outMin > inMin)) return false;
  for (const w of windows) {
    const start = parseHmToMinutes(w.punchIn);
    const end = parseHmToMinutes(w.punchOut);
    if (inMin >= start && outMin <= end) return true;
  }
  return false;
}
const WEEKDAY_CODES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'] as const;
type DayStatus = 'PRESENT' | 'LEAVE' | 'ABSENT' | 'HOLIDAY';

function istDayStartUtc(ymd: string) {
  // "YYYY-MM-DDT00:00:00+05:30" parsed into a UTC Date instance
  const dt = new Date(`${ymd}T00:00:00+05:30`);
  if (!Number.isFinite(dt.getTime())) throw new Error('Invalid date format. Expected YYYY-MM-DD');
  return dt;
}

function istDayRangeUtc(ymd: string) {
  const from = istDayStartUtc(ymd);
  const toExclusive = new Date(from.getTime() + 24 * 60 * 60 * 1000);
  return { from, toExclusive };
}

function istKeyFromUtcDate(d: Date) {
  const shifted = new Date(d.getTime() + IST_OFFSET_MS);
  return `${shifted.getUTCFullYear()}-${String(shifted.getUTCMonth() + 1).padStart(2, '0')}-${String(shifted.getUTCDate()).padStart(2, '0')}`;
}

function parseYmd(ymd: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(ymd);
  if (!m) throw new Error('Invalid date format. Expected YYYY-MM-DD');
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const da = Number(m[3]);
  const dt = new Date(Date.UTC(y, mo - 1, da));
  if (!Number.isFinite(dt.getTime())) throw new Error('Invalid date');
  return dt;
}

function parseHmToMinutes(hm: string): number {
  const m = /^(\d{2}):(\d{2})$/.exec(hm);
  if (!m) throw new Error('Invalid time format. Expected HH:MM');
  const hh = Number(m[1]);
  const mm = Number(m[2]);
  if (!Number.isFinite(hh) || !Number.isFinite(mm) || hh < 0 || hh > 23 || mm < 0 || mm > 59) throw new Error('Invalid time value');
  return hh * 60 + mm;
}

function minutesInIstDayFromUtcDate(d: Date): number {
  // Convert instant to "local IST" clock time without relying on Intl timeZone math.
  const shifted = new Date(d.getTime() + IST_OFFSET_MS);
  return shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
}

function normalizeWeeklyOffDays(input: unknown): Set<string> {
  const raw = Array.isArray(input) ? input : [];
  const normalized = raw
    .map((d) => String(d).trim().toUpperCase())
    .filter((d): d is string => WEEKDAY_CODES.includes(d as (typeof WEEKDAY_CODES)[number]));
  return new Set(normalized.length ? normalized : ['SUN']);
}

function weekdayCodeFromYmd(dateYmd: string): string {
  // Date-only weekday from calendar YMD (avoid IST-midnight → UTC day shift).
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateYmd);
  if (!m) return 'SUN';
  const y = Number(m[1]);
  const mo = Number(m[2]);
  const da = Number(m[3]);
  return WEEKDAY_CODES[new Date(Date.UTC(y, mo - 1, da)).getUTCDay()] ?? 'SUN';
}

async function getAttendancePolicy() {
  const row = await prisma.attendancePolicy.findUnique({ where: { id: 'default' } });
  if (!row) return DEFAULT_POLICY;
  return {
    id: row.id,
    defaultPunchInTime: row.defaultPunchInTime,
    defaultPunchOutTime: row.defaultPunchOutTime,
    punchInBufferMinutes: row.punchInBufferMinutes,
    punchOutBufferMinutes: row.punchOutBufferMinutes,
    maxBufferDaysPerMonth: row.maxBufferDaysPerMonth ?? DEFAULT_POLICY.maxBufferDaysPerMonth,
    halfDayWindows: normalizeHalfDayWindows(row.halfDayWindows),
  };
}

type DayOverrideRow = {
  date: Date;
  defaultPunchInTime: string | null;
  defaultPunchOutTime: string | null;
  punchInBufferMinutes: number | null;
  punchOutBufferMinutes: number | null;
  note: string | null;
};

function serializeDayOverride(row: {
  id: string;
  date: Date;
  defaultPunchInTime: string | null;
  defaultPunchOutTime: string | null;
  punchInBufferMinutes: number | null;
  punchOutBufferMinutes: number | null;
  note: string | null;
  updatedAt: Date;
  updatedBy: string | null;
}) {
  return {
    id: row.id,
    date: istKeyFromUtcDate(row.date),
    defaultPunchInTime: row.defaultPunchInTime,
    defaultPunchOutTime: row.defaultPunchOutTime,
    punchInBufferMinutes: row.punchInBufferMinutes,
    punchOutBufferMinutes: row.punchOutBufferMinutes,
    note: row.note,
    updatedAt: row.updatedAt.toISOString(),
    updatedBy: row.updatedBy,
  };
}

async function fetchDayOverridesMap(fromYmd: string, toYmd: string): Promise<Map<string, DayOverrideRow>> {
  const rows = await prisma.attendancePolicyDayOverride.findMany({
    where: {
      date: {
        gte: parseYmd(fromYmd),
        lte: parseYmd(toYmd),
      },
    },
  });
  const map = new Map<string, DayOverrideRow>();
  for (const r of rows) {
    map.set(istKeyFromUtcDate(r.date), r);
  }
  return map;
}

type EffectivePolicy = {
  source: 'GLOBAL' | 'EMPLOYEE' | 'DAY_OVERRIDE';
  punchInTime: string;
  punchOutTime: string;
  punchInBufferMinutes: number;
  punchOutBufferMinutes: number;
  maxBufferDaysPerMonth: number;
  halfDayWindows: HalfDayWindow[];
  globalPolicy: Awaited<ReturnType<typeof getAttendancePolicy>>;
  employeeSettings: {
    useGlobalPolicy: boolean;
    punchInTime: string | null;
    punchOutTime: string | null;
    punchInBufferMinutes: number | null;
    punchOutBufferMinutes: number | null;
  } | null;
  dayOverride: ReturnType<typeof serializeDayOverride> | null;
};

async function resolveEffectivePolicy(employeeId: number): Promise<EffectivePolicy> {
  const globalPolicy = await getAttendancePolicy();
  const settings = await prisma.employeeAttendanceSettings.findUnique({
    where: { employeeId },
  });

  if (!settings || settings.useGlobalPolicy) {
    return {
      source: 'GLOBAL',
      punchInTime: globalPolicy.defaultPunchInTime,
      punchOutTime: globalPolicy.defaultPunchOutTime,
      punchInBufferMinutes: globalPolicy.punchInBufferMinutes,
      punchOutBufferMinutes: globalPolicy.punchOutBufferMinutes,
      maxBufferDaysPerMonth: globalPolicy.maxBufferDaysPerMonth,
      halfDayWindows: globalPolicy.halfDayWindows,
      globalPolicy,
      employeeSettings: settings
        ? {
            useGlobalPolicy: true,
            punchInTime: settings.punchInTime,
            punchOutTime: settings.punchOutTime,
            punchInBufferMinutes: settings.punchInBufferMinutes,
            punchOutBufferMinutes: settings.punchOutBufferMinutes,
          }
        : null,
      dayOverride: null,
    };
  }

  return {
    source: 'EMPLOYEE',
    punchInTime: settings.punchInTime ?? globalPolicy.defaultPunchInTime,
    punchOutTime: settings.punchOutTime ?? globalPolicy.defaultPunchOutTime,
    punchInBufferMinutes: settings.punchInBufferMinutes ?? globalPolicy.punchInBufferMinutes,
    punchOutBufferMinutes: settings.punchOutBufferMinutes ?? globalPolicy.punchOutBufferMinutes,
    maxBufferDaysPerMonth: globalPolicy.maxBufferDaysPerMonth,
    halfDayWindows: globalPolicy.halfDayWindows,
    globalPolicy,
    employeeSettings: {
      useGlobalPolicy: false,
      punchInTime: settings.punchInTime,
      punchOutTime: settings.punchOutTime,
      punchInBufferMinutes: settings.punchInBufferMinutes,
      punchOutBufferMinutes: settings.punchOutBufferMinutes,
    },
    dayOverride: null,
  };
}

function applyDayOverrideToPolicy(
  base: EffectivePolicy,
  override: DayOverrideRow | null | undefined,
): EffectivePolicy {
  if (!override) return base;
  return {
    ...base,
    source: 'DAY_OVERRIDE',
    punchInTime: override.defaultPunchInTime ?? base.punchInTime,
    punchOutTime: override.defaultPunchOutTime ?? base.punchOutTime,
    punchInBufferMinutes: override.punchInBufferMinutes ?? base.punchInBufferMinutes,
    punchOutBufferMinutes: override.punchOutBufferMinutes ?? base.punchOutBufferMinutes,
    dayOverride: serializeDayOverride({
      id: 'override',
      date: override.date,
      defaultPunchInTime: override.defaultPunchInTime,
      defaultPunchOutTime: override.defaultPunchOutTime,
      punchInBufferMinutes: override.punchInBufferMinutes,
      punchOutBufferMinutes: override.punchOutBufferMinutes,
      note: override.note,
      updatedAt: new Date(),
      updatedBy: null,
    }),
  };
}

type DayPunchEval = {
  totalMinutes: number;
  isAfterExactIn: boolean | null;
  isOutsideBuffer: boolean | null;
  /** Provisional: outside buffer always half; in-buffer grace until quota applied. */
  isLate: boolean | null;
  isHalfDay: boolean | null;
  usedBufferGrace: boolean;
  meetsPunchOut: boolean | null;
};

function evaluateDayPunches(
  policy: Pick<
    EffectivePolicy,
    | 'punchInTime'
    | 'punchOutTime'
    | 'punchInBufferMinutes'
    | 'punchOutBufferMinutes'
    | 'halfDayWindows'
  >,
  firstIn: string | null,
  lastOut: string | null,
): DayPunchEval {
  const totalMinutes =
    firstIn && lastOut
      ? Math.max(0, Math.floor((new Date(lastOut).getTime() - new Date(firstIn).getTime()) / 60000))
      : 0;
  const punchInMin = firstIn ? minutesInIstDayFromUtcDate(new Date(firstIn)) : null;
  const punchOutMin = lastOut ? minutesInIstDayFromUtcDate(new Date(lastOut)) : null;
  const defaultInMin = parseHmToMinutes(policy.punchInTime);
  const defaultOutMin = parseHmToMinutes(policy.punchOutTime);
  const lateAfterMin = defaultInMin + policy.punchInBufferMinutes;
  const eligibleOutAfterMin = defaultOutMin - policy.punchOutBufferMinutes;
  const meetsPunchOut = punchOutMin == null ? null : punchOutMin >= eligibleOutAfterMin;
  const inHalfWindow = fitsHalfDayWindow(policy.halfDayWindows ?? [], firstIn, lastOut);

  if (punchInMin == null) {
    return {
      totalMinutes,
      isAfterExactIn: null,
      isOutsideBuffer: null,
      isLate: null,
      isHalfDay: null,
      usedBufferGrace: false,
      meetsPunchOut,
    };
  }

  const isAfterExactIn = punchInMin > defaultInMin;
  const isOutsideBuffer = punchInMin > lateAfterMin;
  // Outside buffer → always late + half-day. In-buffer late → provisional until monthly quota applied.
  // Also half-day if punches fall entirely inside a configured half-day window.
  const isLate = isOutsideBuffer ? true : isAfterExactIn;
  const isHalfDay = isOutsideBuffer || inHalfWindow;
  const usedBufferGrace = isAfterExactIn && !isOutsideBuffer && !inHalfWindow;

  return {
    totalMinutes,
    isAfterExactIn,
    isOutsideBuffer,
    isLate,
    isHalfDay,
    usedBufferGrace,
    meetsPunchOut,
  };
}

/**
 * Apply monthly buffer-day quota chronologically.
 * First `maxBufferDays` in-buffer late days are forgiven (not half-day).
 * Further in-buffer late days become half-day. Outside-buffer days always half-day.
 */
function applyMonthlyBufferQuota<T extends { date: string; eval: DayPunchEval }>(
  days: T[],
  maxBufferDaysPerMonth: number,
): Array<T & { isLate: boolean | null; isHalfDay: boolean | null; bufferGraceUsed: boolean }> {
  const max = Math.max(0, Math.floor(maxBufferDaysPerMonth));
  const sorted = [...days].sort((a, b) => a.date.localeCompare(b.date));
  const byDate = new Map<string, { isLate: boolean | null; isHalfDay: boolean | null; bufferGraceUsed: boolean }>();
  let used = 0;
  let currentMonth = '';

  for (const day of sorted) {
    const monthKey = day.date.slice(0, 7); // YYYY-MM
    if (monthKey !== currentMonth) {
      currentMonth = monthKey;
      used = 0;
    }
    const e = day.eval;
    if (e.isOutsideBuffer === true) {
      byDate.set(day.date, { isLate: true, isHalfDay: true, bufferGraceUsed: false });
      continue;
    }
    if (e.usedBufferGrace) {
      if (used < max) {
        used += 1;
        byDate.set(day.date, { isLate: false, isHalfDay: false, bufferGraceUsed: true });
      } else {
        byDate.set(day.date, { isLate: true, isHalfDay: true, bufferGraceUsed: false });
      }
      continue;
    }
    byDate.set(day.date, {
      isLate: e.isLate,
      isHalfDay: e.isHalfDay,
      bufferGraceUsed: false,
    });
  }

  return days.map((d) => {
    const applied = byDate.get(d.date) ?? {
      isLate: d.eval.isLate,
      isHalfDay: d.eval.isHalfDay,
      bufferGraceUsed: false,
    };
    return { ...d, ...applied };
  });
}

async function monthBufferUsageBeforeDate(
  employeeId: number,
  dateYmd: string,
  basePolicy: EffectivePolicy,
): Promise<{ used: number; max: number }> {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateYmd);
  if (!m) return { used: 0, max: basePolicy.maxBufferDaysPerMonth };
  const year = Number(m[1]);
  const month = Number(m[2]);
  const { from, to } = monthRangeYmd(year, month);
  // Only count days strictly before this date in the month.
  if (dateYmd <= from) return { used: 0, max: basePolicy.maxBufferDaysPerMonth };

  const dayBefore = (() => {
    const dt = parseYmd(dateYmd);
    const prev = new Date(dt.getTime() - 24 * 60 * 60 * 1000);
    return `${prev.getUTCFullYear()}-${String(prev.getUTCMonth() + 1).padStart(2, '0')}-${String(prev.getUTCDate()).padStart(2, '0')}`;
  })();

  const overrides = await fetchDayOverridesMap(from, dayBefore < from ? from : dayBefore);
  const { from: fromUtc } = istDayRangeUtc(from);
  const toExclusive = new Date(istDayStartUtc(dayBefore).getTime() + 24 * 60 * 60 * 1000);
  const punches = await prisma.attendancePunch.findMany({
    where: {
      employeeId,
      punchAt: { gte: fromUtc, lt: toExclusive },
    },
    orderBy: { punchAt: 'asc' },
    select: { punchAt: true, source: true },
  });

  const byDay: Record<string, Array<{ punchAt: Date; source: string }>> = {};
  for (const p of punches) {
    const key = istKeyFromUtcDate(p.punchAt);
    if (key >= dateYmd) continue;
    (byDay[key] ??= []).push({ punchAt: p.punchAt, source: String(p.source) });
  }

  const evalDays: Array<{ date: string; eval: DayPunchEval }> = [];
  for (const [date, dayPunches] of Object.entries(byDay)) {
    const { firstIn, lastOut } = deriveDayInOut(dayPunches);
    const policy = applyDayOverrideToPolicy(basePolicy, overrides.get(date));
    evalDays.push({ date, eval: evaluateDayPunches(policy, firstIn, lastOut) });
  }
  const applied = applyMonthlyBufferQuota(evalDays, basePolicy.maxBufferDaysPerMonth);
  const used = applied.filter((d) => d.bufferGraceUsed).length;
  return { used, max: basePolicy.maxBufferDaysPerMonth };
}

function monthRangeYmd(year: number, month: number) {
  if (!Number.isFinite(year) || year < 2000 || year > 2100) throw new Error('Invalid year');
  if (!Number.isFinite(month) || month < 1 || month > 12) throw new Error('Invalid month');
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const from = `${year}-${String(month).padStart(2, '0')}-01`;
  const to = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
  return { from, to };
}

/** Build a set of YYYY-MM-DD (IST) covered by APPROVED leave applications. */
function approvedLeaveDateSet(
  apps: Array<{ status: string; fromDate: Date; toDate: Date }>,
  rangeFromYmd: string,
  rangeToYmd: string,
): Set<string> {
  const out = new Set<string>();
  const rangeStart = istDayStartUtc(rangeFromYmd).getTime();
  const rangeEnd = istDayStartUtc(rangeToYmd).getTime();

  for (const app of apps) {
    if (app.status !== 'APPROVED') continue;
    let cursor = istDayStartUtc(istKeyFromUtcDate(app.fromDate));
    const end = istDayStartUtc(istKeyFromUtcDate(app.toDate));
    while (cursor.getTime() <= end.getTime()) {
      if (cursor.getTime() >= rangeStart && cursor.getTime() <= rangeEnd) {
        out.add(istKeyFromUtcDate(cursor));
      }
      cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
    }
  }
  return out;
}

function resolveDayStatus(
  hasPunch: boolean,
  dateYmd: string,
  approvedLeaveDates: Set<string>,
  holidayDates: Set<string>,
): DayStatus {
  if (hasPunch) return 'PRESENT';
  if (holidayDates.has(dateYmd)) return 'HOLIDAY';
  if (approvedLeaveDates.has(dateYmd)) return 'LEAVE';
  return 'ABSENT';
}

async function fetchApprovedLeaveDates(
  employeeId: number,
  fromYmd: string,
  toYmd: string,
): Promise<Set<string>> {
  const fromDate = parseYmd(fromYmd);
  const toDate = parseYmd(toYmd);
  const approvedLeaves = await prisma.leaveApplication.findMany({
    where: {
      employeeId,
      status: 'APPROVED',
      fromDate: { lte: toDate },
      toDate: { gte: fromDate },
    },
    select: { status: true, fromDate: true, toDate: true },
  });
  return approvedLeaveDateSet(approvedLeaves, fromYmd, toYmd);
}

async function fetchApprovedLeaveOnDate(employeeId: number, dateYmd: string) {
  const dayDate = parseYmd(dateYmd);
  return prisma.leaveApplication.findFirst({
    where: {
      employeeId,
      status: 'APPROVED',
      fromDate: { lte: dayDate },
      toDate: { gte: dayDate },
    },
    select: {
      id: true,
      applicationNo: true,
      fromDate: true,
      toDate: true,
      isHalfDay: true,
      leaveType: { select: { name: true, code: true } },
    },
  });
}

async function fetchHolidayDates(
  employeeId: number,
  fromYmd: string,
  toYmd: string,
): Promise<Set<string>> {
  const [generalInfo, publicHolidays] = await Promise.all([
    prisma.employeeGeneralInfo.findUnique({
      where: { employeeId },
      select: { weeklyOffDays: true },
    }),
    prisma.publicHoliday.findMany({
      where: {
        date: {
          gte: istDayStartUtc(fromYmd),
          lt: new Date(istDayStartUtc(toYmd).getTime() + 24 * 60 * 60 * 1000),
        },
      },
      select: { date: true },
    }),
  ]);

  const holidayDates = new Set<string>(
    publicHolidays.map((h) => istKeyFromUtcDate(h.date)),
  );
  const weeklyOffDays = normalizeWeeklyOffDays(generalInfo?.weeklyOffDays);
  let cursor = istDayStartUtc(fromYmd);
  const end = istDayStartUtc(toYmd);
  while (cursor.getTime() <= end.getTime()) {
    const key = istKeyFromUtcDate(cursor);
    if (weeklyOffDays.has(weekdayCodeFromYmd(key))) holidayDates.add(key);
    cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
  }
  return holidayDates;
}

function describeRegisteredDevice(
  deviceInfo: Record<string, unknown> | null,
  userAgent?: string | null,
): { label: string; platform: string } {
  const info = deviceInfo ?? {};
  const platform = String(info.platform ?? '').trim().toLowerCase() || 'unknown';
  const explicit = String(info.deviceLabel ?? '').trim();
  if (explicit && explicit.toLowerCase() !== 'native app') {
    return { label: explicit.slice(0, 120), platform };
  }
  if (platform === 'android') {
    const brand = String(info.manufacturer ?? info.brand ?? '').trim();
    const model = String(info.model ?? '').trim();
    const label = [brand, model].filter(Boolean).join(' ').replace(/\s+/g, ' ').trim();
    return { label: (label || 'Android device').slice(0, 120), platform };
  }
  if (platform === 'ios') {
    const name = String(info.name ?? info.model ?? 'iPhone').trim();
    return { label: name.slice(0, 120), platform };
  }
  if (platform === 'web') {
    const browser = String(info.browserLabel ?? '').trim();
    const label = [explicit, browser].filter(Boolean).join(' · ') || 'Web browser';
    return { label: label.slice(0, 120), platform };
  }
  const ua = String(userAgent ?? '').trim();
  return { label: (ua ? ua.slice(0, 80) : 'Unknown device'), platform };
}

export const attendanceService = {
  async getAdminPolicy() {
    // Ensure row exists so admin UI always has something to edit
    const row = await prisma.attendancePolicy.upsert({
      where: { id: 'default' },
      update: {},
      create: {
        id: 'default',
        defaultPunchInTime: DEFAULT_POLICY.defaultPunchInTime,
        defaultPunchOutTime: DEFAULT_POLICY.defaultPunchOutTime,
        punchInBufferMinutes: DEFAULT_POLICY.punchInBufferMinutes,
        punchOutBufferMinutes: DEFAULT_POLICY.punchOutBufferMinutes,
        maxBufferDaysPerMonth: DEFAULT_POLICY.maxBufferDaysPerMonth,
        halfDayWindows: DEFAULT_POLICY.halfDayWindows,
        updatedBy: 'system',
      },
    });
    return {
      id: row.id,
      defaultPunchInTime: row.defaultPunchInTime,
      defaultPunchOutTime: row.defaultPunchOutTime,
      punchInBufferMinutes: row.punchInBufferMinutes,
      punchOutBufferMinutes: row.punchOutBufferMinutes,
      maxBufferDaysPerMonth: row.maxBufferDaysPerMonth ?? DEFAULT_POLICY.maxBufferDaysPerMonth,
      halfDayWindows: normalizeHalfDayWindows(row.halfDayWindows),
      updatedAt: row.updatedAt.toISOString(),
      updatedBy: row.updatedBy ?? null,
    };
  },

  async updateAdminPolicy(params: {
    defaultPunchInTime: string;
    defaultPunchOutTime: string;
    punchInBufferMinutes: number;
    punchOutBufferMinutes: number;
    maxBufferDaysPerMonth: number;
    halfDayWindows?: unknown;
    updatedBy: string;
  }) {
    // Validate early (throws friendly errors)
    parseHmToMinutes(params.defaultPunchInTime);
    parseHmToMinutes(params.defaultPunchOutTime);
    if (!Number.isFinite(params.punchInBufferMinutes) || params.punchInBufferMinutes < 0 || params.punchInBufferMinutes > 240) {
      throw new Error('Invalid punchInBufferMinutes (expected 0-240)');
    }
    if (!Number.isFinite(params.punchOutBufferMinutes) || params.punchOutBufferMinutes < 0 || params.punchOutBufferMinutes > 240) {
      throw new Error('Invalid punchOutBufferMinutes (expected 0-240)');
    }
    if (!Number.isFinite(params.maxBufferDaysPerMonth) || params.maxBufferDaysPerMonth < 0 || params.maxBufferDaysPerMonth > 31) {
      throw new Error('Invalid maxBufferDaysPerMonth (expected 0-31)');
    }
    const halfDayWindows = normalizeHalfDayWindows(params.halfDayWindows ?? []);

    const row = await prisma.attendancePolicy.upsert({
      where: { id: 'default' },
      update: {
        defaultPunchInTime: params.defaultPunchInTime,
        defaultPunchOutTime: params.defaultPunchOutTime,
        punchInBufferMinutes: params.punchInBufferMinutes,
        punchOutBufferMinutes: params.punchOutBufferMinutes,
        maxBufferDaysPerMonth: params.maxBufferDaysPerMonth,
        halfDayWindows,
        updatedBy: params.updatedBy,
      },
      create: {
        id: 'default',
        defaultPunchInTime: params.defaultPunchInTime,
        defaultPunchOutTime: params.defaultPunchOutTime,
        punchInBufferMinutes: params.punchInBufferMinutes,
        punchOutBufferMinutes: params.punchOutBufferMinutes,
        maxBufferDaysPerMonth: params.maxBufferDaysPerMonth,
        halfDayWindows,
        updatedBy: params.updatedBy,
      },
    });

    return {
      id: row.id,
      defaultPunchInTime: row.defaultPunchInTime,
      defaultPunchOutTime: row.defaultPunchOutTime,
      punchInBufferMinutes: row.punchInBufferMinutes,
      punchOutBufferMinutes: row.punchOutBufferMinutes,
      maxBufferDaysPerMonth: row.maxBufferDaysPerMonth ?? DEFAULT_POLICY.maxBufferDaysPerMonth,
      halfDayWindows: normalizeHalfDayWindows(row.halfDayWindows),
      updatedAt: row.updatedAt.toISOString(),
      updatedBy: row.updatedBy ?? null,
    };
  },

  async getAdminPolicyDayOverride(dateYmd: string) {
    parseYmd(dateYmd);
    const row = await prisma.attendancePolicyDayOverride.findUnique({
      where: { date: parseYmd(dateYmd) },
    });
    return row ? serializeDayOverride(row) : null;
  },

  async upsertAdminPolicyDayOverride(params: {
    date: string;
    defaultPunchInTime?: string | null;
    defaultPunchOutTime?: string | null;
    punchInBufferMinutes?: number | null;
    punchOutBufferMinutes?: number | null;
    note?: string | null;
    updatedBy: string;
  }) {
    parseYmd(params.date);
    if (params.defaultPunchInTime) parseHmToMinutes(params.defaultPunchInTime);
    if (params.defaultPunchOutTime) parseHmToMinutes(params.defaultPunchOutTime);
    if (
      params.punchInBufferMinutes != null &&
      (!Number.isFinite(params.punchInBufferMinutes) ||
        params.punchInBufferMinutes < 0 ||
        params.punchInBufferMinutes > 240)
    ) {
      throw new Error('Invalid punchInBufferMinutes (expected 0-240)');
    }
    if (
      params.punchOutBufferMinutes != null &&
      (!Number.isFinite(params.punchOutBufferMinutes) ||
        params.punchOutBufferMinutes < 0 ||
        params.punchOutBufferMinutes > 240)
    ) {
      throw new Error('Invalid punchOutBufferMinutes (expected 0-240)');
    }

    const hasAny =
      params.defaultPunchInTime != null ||
      params.defaultPunchOutTime != null ||
      params.punchInBufferMinutes != null ||
      params.punchOutBufferMinutes != null;
    if (!hasAny) throw new Error('Provide at least one override field for this day');

    const row = await prisma.attendancePolicyDayOverride.upsert({
      where: { date: parseYmd(params.date) },
      create: {
        date: parseYmd(params.date),
        defaultPunchInTime: params.defaultPunchInTime ?? null,
        defaultPunchOutTime: params.defaultPunchOutTime ?? null,
        punchInBufferMinutes: params.punchInBufferMinutes ?? null,
        punchOutBufferMinutes: params.punchOutBufferMinutes ?? null,
        note: params.note ?? null,
        updatedBy: params.updatedBy,
      },
      update: {
        defaultPunchInTime: params.defaultPunchInTime ?? null,
        defaultPunchOutTime: params.defaultPunchOutTime ?? null,
        punchInBufferMinutes: params.punchInBufferMinutes ?? null,
        punchOutBufferMinutes: params.punchOutBufferMinutes ?? null,
        note: params.note ?? null,
        updatedBy: params.updatedBy,
      },
    });
    return serializeDayOverride(row);
  },

  async deleteAdminPolicyDayOverride(dateYmd: string) {
    parseYmd(dateYmd);
    await prisma.attendancePolicyDayOverride.deleteMany({ where: { date: parseYmd(dateYmd) } });
    return { ok: true };
  },

  async getMyCalendarPunches(params: { employeeId: number; from: string; to: string }) {
    const { from: fromUtc } = istDayRangeUtc(params.from);
    // inclusive end-of-day: add 1 day and use lt
    const toExclusive = new Date(istDayStartUtc(params.to).getTime() + 24 * 60 * 60 * 1000);

    const punches = await prisma.attendancePunch.findMany({
      where: {
        employeeId: params.employeeId,
        punchAt: { gte: fromUtc, lt: toExclusive },
      },
      orderBy: { punchAt: 'asc' },
      select: { punchAt: true, source: true },
    });

    const approvedLeaveDates = await fetchApprovedLeaveDates(
      params.employeeId,
      params.from,
      params.to,
    );
    const holidayDates = await fetchHolidayDates(
      params.employeeId,
      params.from,
      params.to,
    );

    // Group by YYYY-MM-DD (IST)
    const byDay: Record<
      string,
      { count: number; firstIn?: string; lastOut?: string; dayStatus: DayStatus }
    > = {};
    const punchesByDay: Record<string, Array<{ punchAt: Date; source: string }>> = {};
    for (const p of punches) {
      const d = new Date(p.punchAt);
      const key = istKeyFromUtcDate(d);
      (punchesByDay[key] ??= []).push({ punchAt: d, source: String(p.source) });
    }
    for (const [key, dayPunches] of Object.entries(punchesByDay)) {
      const { firstIn, lastOut } = deriveDayInOut(dayPunches);
      byDay[key] = {
        count: dayPunches.length,
        firstIn: firstIn ?? undefined,
        lastOut: lastOut ?? firstIn ?? undefined,
        dayStatus: 'PRESENT',
      };
    }

    for (const dateKey of approvedLeaveDates) {
      if (!byDay[dateKey]) {
        byDay[dateKey] = { count: 0, dayStatus: 'LEAVE' };
      } else {
        byDay[dateKey].dayStatus = resolveDayStatus(byDay[dateKey].count > 0, dateKey, approvedLeaveDates, holidayDates);
      }
    }

    for (const dateKey of holidayDates) {
      if (!byDay[dateKey]) {
        byDay[dateKey] = { count: 0, dayStatus: 'HOLIDAY' };
      } else {
        byDay[dateKey].dayStatus = resolveDayStatus(byDay[dateKey].count > 0, dateKey, approvedLeaveDates, holidayDates);
      }
    }

    // Fill every day in range so calendar can show Holiday / Leave / Absent.
    let cursor = istDayStartUtc(params.from);
    const end = istDayStartUtc(params.to);
    while (cursor.getTime() <= end.getTime()) {
      const dateKey = istKeyFromUtcDate(cursor);
      if (!byDay[dateKey]) {
        byDay[dateKey] = {
          count: 0,
          dayStatus: resolveDayStatus(false, dateKey, approvedLeaveDates, holidayDates),
        };
      } else {
        byDay[dateKey].dayStatus = resolveDayStatus(
          byDay[dateKey].count > 0,
          dateKey,
          approvedLeaveDates,
          holidayDates,
        );
      }
      cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
    }

    return byDay;
  },

  async getMyDayPunches(params: { employeeId: number; date: string }) {
    const { from: fromUtc, toExclusive } = istDayRangeUtc(params.date);

    const punches = await prisma.attendancePunch.findMany({
      where: {
        employeeId: params.employeeId,
        punchAt: { gte: fromUtc, lt: toExclusive },
      },
      orderBy: { punchAt: 'asc' },
      select: { id: true, punchAt: true, terminalId: true, punchType: true, source: true, latitude: true, longitude: true, locationId: true, location: true, deviceInfo: true },
    });

    const { firstIn, lastOut } = deriveDayInOut(
      punches.map((p) => ({ punchAt: p.punchAt, source: String(p.source) })),
    );

    const basePolicy = await resolveEffectivePolicy(params.employeeId);
    const dayOverrideRow = await prisma.attendancePolicyDayOverride.findUnique({
      where: { date: parseYmd(params.date) },
    });
    const policy = applyDayOverrideToPolicy(basePolicy, dayOverrideRow);
    const raw = evaluateDayPunches(policy, firstIn, lastOut);
    const { used, max } = await monthBufferUsageBeforeDate(params.employeeId, params.date, basePolicy);

    let isLate = raw.isLate;
    let isHalfDay = raw.isHalfDay;
    let bufferGraceUsed = false;
    if (raw.isOutsideBuffer === true) {
      isLate = true;
      isHalfDay = true;
    } else if (raw.usedBufferGrace) {
      if (used < max) {
        isLate = false;
        isHalfDay = false;
        bufferGraceUsed = true;
      } else {
        isLate = true;
        isHalfDay = true;
      }
    }

    const hasPunch = punches.length > 0;
    const [leaveApp, holidayDates] = await Promise.all([
      hasPunch ? Promise.resolve(null) : fetchApprovedLeaveOnDate(params.employeeId, params.date),
      fetchHolidayDates(params.employeeId, params.date, params.date),
    ]);
    const dayStatus = resolveDayStatus(
      hasPunch,
      params.date,
      leaveApp ? new Set([params.date]) : new Set<string>(),
      holidayDates,
    );

    return {
      punches,
      summary: {
        firstIn,
        lastOut,
        totalMinutes: raw.totalMinutes,
        dayStatus,
        leave: dayStatus === 'LEAVE' && leaveApp
          ? {
              applicationNo: leaveApp.applicationNo,
              leaveTypeName: leaveApp.leaveType.name,
              leaveTypeCode: leaveApp.leaveType.code,
              fromDate: leaveApp.fromDate.toISOString(),
              toDate: leaveApp.toDate.toISOString(),
              isHalfDay: leaveApp.isHalfDay,
            }
          : null,
        policy: {
          source: policy.source,
          punchInTime: policy.punchInTime,
          punchOutTime: policy.punchOutTime,
          punchInBufferMinutes: policy.punchInBufferMinutes,
          punchOutBufferMinutes: policy.punchOutBufferMinutes,
          maxBufferDaysPerMonth: policy.maxBufferDaysPerMonth,
          bufferDaysUsedThisMonth: used + (bufferGraceUsed ? 1 : 0),
          globalPolicy: policy.globalPolicy,
          employeeSettings: policy.employeeSettings,
          dayOverride: dayOverrideRow ? serializeDayOverride(dayOverrideRow) : null,
        },
        evaluation: hasPunch
          ? {
              isLate,
              isHalfDay,
              meetsPunchOut: raw.meetsPunchOut,
              isOutsideBuffer: raw.isOutsideBuffer,
              bufferGraceUsed,
              bufferDaysRemaining: Math.max(0, max - used - (bufferGraceUsed ? 1 : 0)),
              thresholds: {
                lateAfter: policy.punchInTime,
                lateBufferMinutes: policy.punchInBufferMinutes,
                punchOutEligibleAfter: policy.punchOutTime,
                punchOutBufferMinutes: policy.punchOutBufferMinutes,
              },
            }
          : null,
      },
    };
  },

  async getAdminDayPunches(params: { date: string }) {
    const { from: fromUtc, toExclusive } = istDayRangeUtc(params.date);

    const punches = await prisma.attendancePunch.findMany({
      where: { punchAt: { gte: fromUtc, lt: toExclusive } },
      orderBy: [{ employeeId: 'asc' }, { punchAt: 'asc' }],
      select: {
        id: true,
        employeeId: true,
        punchAt: true,
        terminalId: true,
        punchType: true,
        source: true,
        latitude: true,
        longitude: true,
        locationId: true,
        location: true,
        deviceInfo: true,
      },
    });

    const employees = await prisma.employee.findMany({
      where: { status: 'ACTIVE' },
      include: { generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } } },
      orderBy: { id: 'asc' },
    });

    const byEmployee: Record<number, Array<{ id: string; punchAt: string; terminalId: string | null; punchType: string | null; source: string; location?: any; deviceInfo?: any; latitude?: number | null; longitude?: number | null; locationId?: string | null; }>> = {};
    for (const p of punches) {
      const arr = byEmployee[p.employeeId] ?? (byEmployee[p.employeeId] = []);
      arr.push({
        id: p.id,
        punchAt: new Date(p.punchAt).toISOString(),
        terminalId: p.terminalId ?? null,
        punchType: p.punchType ?? null,
        source: String(p.source), location: p.location, deviceInfo: p.deviceInfo, latitude: p.latitude, longitude: p.longitude, locationId: p.locationId,
      });
    }

    return employees.map((e) => ({
      employeeId: e.id,
      fullName: e.generalInfo?.fullName ?? `Employee #${e.id}`,
      employeeCode: e.generalInfo?.employeeCode ?? null,
      designation: e.generalInfo?.designation ?? null,
      department: e.generalInfo?.department ?? null,
      punches: byEmployee[e.id] ?? [],
    }));
  },

  /**
   * Admin: multi-day punch history for one employee with policy evaluation per day.
   */
  async getAdminEmployeeHistory(params: {
    employeeId: number;
    from: string;
    to: string;
  }) {
    parseYmd(params.from);
    parseYmd(params.to);

    const employee = await prisma.employee.findUnique({
      where: { id: params.employeeId },
      include: {
        generalInfo: {
          select: { fullName: true, employeeCode: true, designation: true, department: true },
        },
      },
    });
    if (!employee) throw new Error('Employee not found');

    const { from: fromUtc } = istDayRangeUtc(params.from);
    const toExclusive = new Date(istDayStartUtc(params.to).getTime() + 24 * 60 * 60 * 1000);

    const punches = await prisma.attendancePunch.findMany({
      where: {
        employeeId: params.employeeId,
        punchAt: { gte: fromUtc, lt: toExclusive },
      },
      orderBy: { punchAt: 'asc' },
      select: { id: true, punchAt: true, terminalId: true, punchType: true, source: true, latitude: true, longitude: true, locationId: true, location: true, deviceInfo: true },
    });

    const basePolicy = await resolveEffectivePolicy(params.employeeId);
    const dayOverrides = await fetchDayOverridesMap(params.from, params.to);

    const approvedLeaveDates = await fetchApprovedLeaveDates(
      params.employeeId,
      params.from,
      params.to,
    );
    const holidayDates = await fetchHolidayDates(
      params.employeeId,
      params.from,
      params.to,
    );

    type PunchRow = { location?: any; deviceInfo?: any; latitude?: number | null; longitude?: number | null; locationId?: string | null;
      id: string;
      punchAt: string;
      terminalId: string | null;
      punchType: string | null;
      source: string;
    };
    const byDay: Record<string, PunchRow[]> = {};
    for (const p of punches) {
      const iso = new Date(p.punchAt).toISOString();
      const key = istKeyFromUtcDate(new Date(p.punchAt));
      const arr = byDay[key] ?? (byDay[key] = []);
      arr.push({
        id: p.id,
        punchAt: iso,
        terminalId: p.terminalId ?? null,
        punchType: p.punchType ?? null,
        source: String(p.source), location: p.location, deviceInfo: p.deviceInfo, latitude: p.latitude, longitude: p.longitude, locationId: p.locationId,
      });
    }

    // Iterate every IST day in [from, to] inclusive so empty days appear.
    type DraftDay = {
      date: string;
      firstIn: string | null;
      lastOut: string | null;
      punches: PunchRow[];
      dayStatus: DayStatus;
      eval: DayPunchEval;
    };
    const draftDays: DraftDay[] = [];

    let cursor = istDayStartUtc(params.from);
    const end = istDayStartUtc(params.to);
    while (cursor.getTime() <= end.getTime()) {
      const date = istKeyFromUtcDate(cursor);
      const dayPunches = byDay[date] ?? [];
      const { firstIn, lastOut } = deriveDayInOut(
        dayPunches.map((p) => ({ punchAt: p.punchAt, source: p.source })),
      );
      const dayPolicy = applyDayOverrideToPolicy(basePolicy, dayOverrides.get(date));
      const evaluation = evaluateDayPunches(dayPolicy, firstIn, lastOut);

      const hasPunch = Boolean(firstIn);
      const dayStatus = resolveDayStatus(hasPunch, date, approvedLeaveDates, holidayDates);

      draftDays.push({
        date,
        firstIn,
        lastOut,
        punches: dayPunches,
        dayStatus,
        eval: evaluation,
      });

      cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
    }

    const applied = applyMonthlyBufferQuota(draftDays, basePolicy.maxBufferDaysPerMonth);
    const days = applied.map((d) => ({
      date: d.date,
      firstIn: d.firstIn,
      lastOut: d.lastOut,
      totalMinutes: d.eval.totalMinutes,
      punches: d.punches,
      isLate: d.isLate,
      isHalfDay: d.isHalfDay,
      meetsPunchOut: d.eval.meetsPunchOut,
      bufferGraceUsed: d.bufferGraceUsed,
      dayStatus: d.dayStatus,
    }));

    return {
      employee: {
        employeeId: employee.id,
        fullName: employee.generalInfo?.fullName ?? `Employee #${employee.id}`,
        employeeCode: employee.generalInfo?.employeeCode ?? null,
        designation: employee.generalInfo?.designation ?? null,
        department: employee.generalInfo?.department ?? null,
      },
      from: params.from,
      to: params.to,
      policy: {
        source: basePolicy.source,
        punchInTime: basePolicy.punchInTime,
        punchOutTime: basePolicy.punchOutTime,
        punchInBufferMinutes: basePolicy.punchInBufferMinutes,
        punchOutBufferMinutes: basePolicy.punchOutBufferMinutes,
        maxBufferDaysPerMonth: basePolicy.maxBufferDaysPerMonth,
        bufferDaysUsed: days.filter((d) => d.bufferGraceUsed).length,
        globalPolicy: basePolicy.globalPolicy,
        employeeSettings: basePolicy.employeeSettings,
      },
      days,
    };
  },

  async getEmployeeAttendanceSettings(employeeId: number) {
    const employee = await prisma.employee.findUnique({ where: { id: employeeId }, select: { id: true } });
    if (!employee) throw new Error('Employee not found');
    const effective = await resolveEffectivePolicy(employeeId);
    const row = await prisma.employeeAttendanceSettings.findUnique({ where: { employeeId } });
    return {
      employeeId,
      useGlobalPolicy: row?.useGlobalPolicy ?? true,
      punchInTime: row?.punchInTime ?? null,
      punchOutTime: row?.punchOutTime ?? null,
      punchInBufferMinutes: row?.punchInBufferMinutes ?? null,
      punchOutBufferMinutes: row?.punchOutBufferMinutes ?? null,
      biometricToken: row?.biometricToken ?? null,
      biometricDeviceLabel: row?.biometricDeviceLabel ?? null,
      biometricDevicePlatform: row?.biometricDevicePlatform ?? null,
      effective: {
        source: effective.source,
        punchInTime: effective.punchInTime,
        punchOutTime: effective.punchOutTime,
        punchInBufferMinutes: effective.punchInBufferMinutes,
        punchOutBufferMinutes: effective.punchOutBufferMinutes,
      },
      globalPolicy: effective.globalPolicy,
    };
  },

  async updateEmployeeAttendanceSettings(
    employeeId: number,
    input: {
      useGlobalPolicy?: boolean;
      punchInTime?: string | null;
      punchOutTime?: string | null;
      punchInBufferMinutes?: number | null;
      punchOutBufferMinutes?: number | null;
      updatedBy: string;
    },
  ) {
    const employee = await prisma.employee.findUnique({ where: { id: employeeId }, select: { id: true } });
    if (!employee) throw new Error('Employee not found');

    if (input.punchInTime) parseHmToMinutes(input.punchInTime);
    if (input.punchOutTime) parseHmToMinutes(input.punchOutTime);
    if (input.punchInBufferMinutes != null && (input.punchInBufferMinutes < 0 || input.punchInBufferMinutes > 240)) {
      throw new Error('Invalid punchInBufferMinutes (expected 0-240)');
    }
    if (input.punchOutBufferMinutes != null && (input.punchOutBufferMinutes < 0 || input.punchOutBufferMinutes > 240)) {
      throw new Error('Invalid punchOutBufferMinutes (expected 0-240)');
    }

    await prisma.employeeAttendanceSettings.upsert({
      where: { employeeId },
      update: {
        useGlobalPolicy: input.useGlobalPolicy ?? undefined,
        punchInTime: input.punchInTime === undefined ? undefined : input.punchInTime,
        punchOutTime: input.punchOutTime === undefined ? undefined : input.punchOutTime,
        punchInBufferMinutes: input.punchInBufferMinutes === undefined ? undefined : input.punchInBufferMinutes,
        punchOutBufferMinutes: input.punchOutBufferMinutes === undefined ? undefined : input.punchOutBufferMinutes,
        updatedBy: input.updatedBy,
      },
      create: {
        employeeId,
        useGlobalPolicy: input.useGlobalPolicy ?? false,
        punchInTime: input.punchInTime ?? null,
        punchOutTime: input.punchOutTime ?? null,
        punchInBufferMinutes: input.punchInBufferMinutes ?? null,
        punchOutBufferMinutes: input.punchOutBufferMinutes ?? null,
        updatedBy: input.updatedBy,
      },
    });

    return this.getEmployeeAttendanceSettings(employeeId);
  },

  async getEmployeeMonthlySummary(params: { employeeId: number; year: number; month: number }) {
    const { from, to } = monthRangeYmd(params.year, params.month);
    const history = await this.getAdminEmployeeHistory({ employeeId: params.employeeId, from, to });

    const monthStart = istDayStartUtc(from);
    const monthEndExclusive = new Date(istDayStartUtc(to).getTime() + 24 * 60 * 60 * 1000);

    const leaveApps = await prisma.leaveApplication.findMany({
      where: {
        employeeId: params.employeeId,
        status: { in: ['APPROVED', 'PENDING', 'HOD_RECOMMENDED', 'HOI_RECOMMENDED'] },
        fromDate: { lt: monthEndExclusive },
        toDate: { gte: monthStart },
      },
      include: { leaveType: { select: { code: true, name: true, cutsSalary: true } } },
      orderBy: { fromDate: 'asc' },
    });

    const approvedOnly = leaveApps.filter((a) => a.status === 'APPROVED');
    const approvedLeaveDates = approvedLeaveDateSet(approvedOnly, from, to);
    const unpaidLeaveApps = approvedOnly.filter((a) => a.leaveType.cutsSalary);
    const unpaidLeaveDates = approvedLeaveDateSet(unpaidLeaveApps, from, to);
    // Unpaid leave days that are not holidays (holiday wins over leave for day status).
    const holidayDates = await fetchHolidayDates(params.employeeId, from, to);
    let unpaidLeaveDays = 0;
    for (const d of unpaidLeaveDates) {
      if (!holidayDates.has(d)) unpaidLeaveDays += 1;
    }

    const leaveDaysInMonth = approvedOnly.reduce((sum, app) => sum + Number(app.totalDays), 0);

    let presentDays = 0;
    let leaveDays = 0;
    let holidayDays = 0;
    let lateDays = 0;
    let halfDays = 0;
    let totalWorkingMinutes = 0;
    for (const day of history.days) {
      const status = (day as { dayStatus?: string }).dayStatus
        ?? resolveDayStatus(Boolean(day.firstIn), day.date, approvedLeaveDates, holidayDates);
      if (status === 'PRESENT') presentDays += 1;
      if (status === 'LEAVE') leaveDays += 1;
      if (status === 'HOLIDAY') holidayDays += 1;
      if (day.isLate === true) lateDays += 1;
      if (day.isHalfDay === true) halfDays += 1;
      totalWorkingMinutes += day.totalMinutes;
    }

    const absentDays = Math.max(
      0,
      history.days.filter((d) => (d as { dayStatus?: string }).dayStatus === 'ABSENT').length,
    );
    const absentDates = history.days
      .filter((d) => (d as { dayStatus?: string }).dayStatus === 'ABSENT')
      .map((d) => d.date);
    const daysInMonth = history.days.length;
    const salaryAbsentDays = absentDays + unpaidLeaveDays + halfDays * 0.5;

    return {
      year: params.year,
      month: params.month,
      from,
      to,
      policy: history.policy,
      stats: {
        presentDays,
        lateDays,
        halfDays,
        absentDays,
        absentDates,
        leaveDays,
        holidayDays,
        unpaidLeaveDays,
        salaryAbsentDays,
        daysInMonth,
        totalWorkingMinutes,
        totalWorkingHours: Math.round((totalWorkingMinutes / 60) * 100) / 100,
        leaveApplications: leaveApps.length,
        leaveDaysInMonth,
      },
      days: history.days,
      leaveApplications: leaveApps.map((a) => ({
        id: a.id,
        applicationNo: a.applicationNo,
        status: a.status,
        fromDate: a.fromDate.toISOString(),
        toDate: a.toDate.toISOString(),
        totalDays: Number(a.totalDays),
        isHalfDay: a.isHalfDay,
        leaveType: a.leaveType,
        reason: a.reason,
        cutsSalary: a.leaveType.cutsSalary,
      })),
    };
  },

  async createAdminPunch(params: { employeeId: number; punchAt: string; punchType?: string | null; terminalId?: string | null }) {
    const dt = new Date(params.punchAt);
    if (!Number.isFinite(dt.getTime())) throw new Error('Invalid punchAt datetime');

    const employee = await prisma.employee.findUnique({ where: { id: params.employeeId }, select: { id: true } });
    if (!employee) throw new Error('Employee not found');

    const row = await prisma.attendancePunch.create({
      data: {
        employeeId: params.employeeId,
        punchAt: dt,
        source: 'ESSL',
        terminalId: params.terminalId ?? 'MANUAL',
        punchType: params.punchType ?? 'MANUAL',
        externalKey: `MANUAL-${params.employeeId}-${dt.getTime()}-${randomUUID()}`,
      },
      select: { id: true, employeeId: true, punchAt: true, terminalId: true, punchType: true, source: true, latitude: true, longitude: true, locationId: true, location: true, deviceInfo: true },
    });

    return {
      ...row,
      punchAt: row.punchAt.toISOString(),
      source: String(row.source),
    };
  },

  async updateAdminPunch(params: { punchId: string; punchAt: string; punchType?: string | null; terminalId?: string | null }) {
    const dt = new Date(params.punchAt);
    if (!Number.isFinite(dt.getTime())) throw new Error('Invalid punchAt datetime');

    const row = await prisma.attendancePunch.update({
      where: { id: params.punchId },
      data: {
        punchAt: dt,
        punchType: params.punchType ?? undefined,
        terminalId: params.terminalId ?? undefined,
      },
      select: { id: true, employeeId: true, punchAt: true, terminalId: true, punchType: true, source: true, latitude: true, longitude: true, locationId: true, location: true, deviceInfo: true },
    });

    return {
      ...row,
      punchAt: row.punchAt.toISOString(),
      source: String(row.source),
    };
  },

  // --- Attendance Location Management ---

  async getLocations() {
    return prisma.attendanceLocation.findMany({ orderBy: { createdAt: 'desc' } });
  },

  async createLocation(params: { name: string; latitude: number; longitude: number; radiusKm: number; isUnique?: boolean; isActive: boolean }) {
    return prisma.attendanceLocation.create({ data: params });
  },

  async updateLocation(id: string, params: { name?: string; latitude?: number; longitude?: number; radiusKm?: number; isUnique?: boolean; isActive?: boolean }) {
    return prisma.attendanceLocation.update({ where: { id }, data: params });
  },

  async deleteLocation(id: string) {
    return prisma.attendanceLocation.delete({ where: { id } });
  },

  // --- Geofenced App Punch ---

  async verifyLocation(latitude: number, longitude: number) {
    const locations = await prisma.attendanceLocation.findMany({ where: { isActive: true } });
    if (locations.length === 0) {
      throw new Error('No attendance zones configured by Admin. Cannot punch in via app.');
    }

    const getDistanceFromLatLonInKm = (lat1: number, lon1: number, lat2: number, lon2: number) => {
      const R = 6371;
      const dLat = (lat2 - lat1) * (Math.PI / 180);
      const dLon = (lon2 - lon1) * (Math.PI / 180);
      const a = 
        Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) * 
        Math.sin(dLon/2) * Math.sin(dLon/2); 
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
      return R * c;
    };

    for (const loc of locations) {
      const dist = getDistanceFromLatLonInKm(latitude, longitude, loc.latitude, loc.longitude);
      if (dist <= loc.radiusKm) {
        return { success: true, locationId: loc.id };
      }
    }
    
    throw new Error('You are outside of the allowed attendance zones.');
  },

  async createGeofencedPunch(params: {
    employeeId: number;
    latitude: number;
    longitude: number;
    deviceInfo: any;
    biometricVerified: boolean;
    biometricToken?: string | null;
    reason?: string;
    userAgent?: string | null;
  }) {
    if (!params.biometricVerified && !params.deviceInfo) {
      throw new Error('Punch must be authenticated with biometrics or a trusted device fingerprint.');
    }

    const gate = evaluateWebAttendanceGate({
      userAgent: params.userAgent,
      deviceInfo: params.deviceInfo && typeof params.deviceInfo === 'object' ? params.deviceInfo : null,
    });
    if (!gate.allowed) {
      throw new Error(gate.message ?? 'Web attendance is not allowed on this browser/device.');
    }

    // Biometric/Fingerprint Pinning Check
    const settings = await prisma.employeeAttendanceSettings.findUnique({
      where: { employeeId: params.employeeId },
      select: { biometricToken: true, biometricDeviceLabel: true },
    });

    if (settings && settings.biometricToken) {
      if (!params.biometricToken || params.biometricToken !== settings.biometricToken) {
        const label = settings.biometricDeviceLabel?.trim();
        throw new Error(
          label
            ? `Punch in from your registered device: ${label}.`
            : 'Punch in from the device where you first registered your fingerprint.',
        );
      }
    } else {
      throw new Error('Fingerprint is not set. Please register your fingerprint in the app settings first.');
    }

    const locations = await prisma.attendanceLocation.findMany({ where: { isActive: true } });
    
    if (locations.length === 0) {
      throw new Error('No attendance zones configured by Admin. Cannot punch in via app.');
    }

    let matchedLocationId: string | null = null;
    
    // Haversine formula
    const getDistanceFromLatLonInKm = (lat1: number, lon1: number, lat2: number, lon2: number) => {
      const R = 6371;
      const dLat = (lat2 - lat1) * (Math.PI / 180);
      const dLon = (lon2 - lon1) * (Math.PI / 180);
      const a = 
        Math.sin(dLat/2) * Math.sin(dLat/2) +
        Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) * 
        Math.sin(dLon/2) * Math.sin(dLon/2); 
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
      return R * c;
    };

    for (const loc of locations) {
      const dist = getDistanceFromLatLonInKm(params.latitude, params.longitude, loc.latitude, loc.longitude);
      if (dist <= loc.radiusKm) {
        matchedLocationId = loc.id;
        break;
      }
    }
    
    if (!matchedLocationId) {
      throw new Error('You are outside of the allowed attendance zones.');
    }

    const dt = new Date();
    // Mobile punches are always "now" — never allow backdating via this endpoint.
    // Day window in IST so late-night punches land on the correct Indian calendar day.
    const istNow = new Date(dt.getTime() + 330 * 60 * 1000);
    const y = istNow.getUTCFullYear();
    const m = istNow.getUTCMonth();
    const d = istNow.getUTCDate();
    const startOfDay = new Date(Date.UTC(y, m, d, -5, -30, 0, 0));
    const endOfDay = new Date(Date.UTC(y, m, d, 18, 29, 59, 999));
    
    const todaysPunchesCount = await prisma.attendancePunch.count({
      where: {
        employeeId: params.employeeId,
        punchAt: { gte: startOfDay, lte: endOfDay }
      }
    });

    if (todaysPunchesCount >= 2) {
      if (!params.reason || params.reason.trim().length === 0) {
        throw new Error('REASON_REQUIRED');
      }
    }

    const enrichedDeviceInfo = {
      ...(params.deviceInfo && typeof params.deviceInfo === 'object' ? params.deviceInfo : {}),
      clientKind: gate.kind,
      deviceLabel: gate.deviceLabel,
      browserLabel: gate.browserLabel,
      userAgent: gate.userAgent || params.userAgent || null,
    };

    const row = await prisma.attendancePunch.create({
      data: {
        employeeId: params.employeeId,
        punchAt: dt,
        source: 'MOBILE_APP',
        terminalId: gate.kind === 'ios_safari' ? 'WEB_IOS_SAFARI' : 'APP',
        punchType: 'APP_PUNCH',
        externalKey: `APP-${params.employeeId}-${dt.getTime()}-${randomUUID()}`,
        latitude: params.latitude,
        longitude: params.longitude,
        locationId: matchedLocationId,
        deviceInfo: enrichedDeviceInfo,
        reason: params.reason ? params.reason.trim() : undefined,
      },
      select: { id: true, employeeId: true, punchAt: true, terminalId: true, punchType: true, source: true, latitude: true, longitude: true, locationId: true, location: true, reason: true },
    });

    if (gate.kind === 'ios_safari') {
      void notifyAdminsWebAttendance({
        type: 'web_punch',
        employeeId: params.employeeId,
        gate,
        punchAt: row.punchAt.toISOString(),
      });
    }

    return {
      ...row,
      punchAt: row.punchAt.toISOString(),
      source: String(row.source),
    };
  },

  async registerBiometricToken(
    employeeId: number,
    biometricToken: string,
    updatedBy: string,
    opts?: { userAgent?: string | null; deviceInfo?: Record<string, unknown> | null },
  ) {
    const employee = await prisma.employee.findUnique({ where: { id: employeeId }, select: { id: true } });
    if (!employee) throw new Error('Employee not found');

    const gate = evaluateWebAttendanceGate({
      userAgent: opts?.userAgent,
      deviceInfo: opts?.deviceInfo ?? null,
    });
    if (!gate.allowed) {
      throw new Error(gate.message ?? 'Web attendance is not allowed on this browser/device.');
    }

    const existing = await prisma.employeeAttendanceSettings.findUnique({
      where: { employeeId },
      select: { biometricToken: true, biometricDeviceLabel: true },
    });

    if (existing?.biometricToken) {
      const label = existing.biometricDeviceLabel?.trim();
      throw new Error(
        label
          ? `Fingerprint is already registered on ${label}. Punch in from that device, or ask Admin/HR to reset it.`
          : 'Fingerprint already registered. Punch in from that device, or ask Admin/HR to reset it.',
      );
    }

    const device = describeRegisteredDevice(opts?.deviceInfo ?? null, opts?.userAgent);

    await prisma.employeeAttendanceSettings.upsert({
      where: { employeeId },
      update: {
        biometricToken,
        biometricDeviceLabel: device.label,
        biometricDevicePlatform: device.platform,
        updatedBy,
      },
      create: {
        employeeId,
        useGlobalPolicy: true,
        biometricToken,
        biometricDeviceLabel: device.label,
        biometricDevicePlatform: device.platform,
        updatedBy,
      },
    });

    if (gate.kind === 'ios_safari') {
      void notifyAdminsWebAttendance({
        type: 'web_register',
        employeeId,
        gate,
      });
    }

    return { success: true };
  },

  async resetBiometricToken(employeeId: number, updatedBy: string) {
    const employee = await prisma.employee.findUnique({ where: { id: employeeId }, select: { id: true } });
    if (!employee) throw new Error('Employee not found');

    await prisma.employeeAttendanceSettings.upsert({
      where: { employeeId },
      update: {
        biometricToken: null,
        biometricDeviceLabel: null,
        biometricDevicePlatform: null,
        updatedBy,
      },
      create: {
        employeeId,
        useGlobalPolicy: true,
        biometricToken: null,
        biometricDeviceLabel: null,
        biometricDevicePlatform: null,
        updatedBy,
      },
    });

    return { success: true };
  }
};


