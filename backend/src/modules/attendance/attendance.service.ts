import { prisma } from '../../config/prisma';
import { randomUUID } from 'crypto';

const IST_OFFSET_MIN = 330;
const IST_OFFSET_MS = IST_OFFSET_MIN * 60 * 1000;
const DEFAULT_POLICY = {
  id: 'default' as const,
  defaultPunchInTime: '09:00',
  defaultPunchOutTime: '15:30',
  punchInBufferMinutes: 10,
  punchOutBufferMinutes: 10,
};

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

async function getAttendancePolicy() {
  const row = await prisma.attendancePolicy.findUnique({ where: { id: 'default' } });
  if (!row) return DEFAULT_POLICY;
  return {
    id: row.id,
    defaultPunchInTime: row.defaultPunchInTime,
    defaultPunchOutTime: row.defaultPunchOutTime,
    punchInBufferMinutes: row.punchInBufferMinutes,
    punchOutBufferMinutes: row.punchOutBufferMinutes,
  };
}

type EffectivePolicy = {
  source: 'GLOBAL' | 'EMPLOYEE';
  punchInTime: string;
  punchOutTime: string;
  punchInBufferMinutes: number;
  punchOutBufferMinutes: number;
  globalPolicy: Awaited<ReturnType<typeof getAttendancePolicy>>;
  employeeSettings: {
    useGlobalPolicy: boolean;
    punchInTime: string | null;
    punchOutTime: string | null;
    punchInBufferMinutes: number | null;
    punchOutBufferMinutes: number | null;
  } | null;
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
    };
  }

  return {
    source: 'EMPLOYEE',
    punchInTime: settings.punchInTime ?? globalPolicy.defaultPunchInTime,
    punchOutTime: settings.punchOutTime ?? globalPolicy.defaultPunchOutTime,
    punchInBufferMinutes: settings.punchInBufferMinutes ?? globalPolicy.punchInBufferMinutes,
    punchOutBufferMinutes: settings.punchOutBufferMinutes ?? globalPolicy.punchOutBufferMinutes,
    globalPolicy,
    employeeSettings: {
      useGlobalPolicy: false,
      punchInTime: settings.punchInTime,
      punchOutTime: settings.punchOutTime,
      punchInBufferMinutes: settings.punchInBufferMinutes,
      punchOutBufferMinutes: settings.punchOutBufferMinutes,
    },
  };
}

function evaluateDayPunches(
  policy: Pick<EffectivePolicy, 'punchInTime' | 'punchOutTime' | 'punchInBufferMinutes' | 'punchOutBufferMinutes'>,
  firstIn: string | null,
  lastOut: string | null,
) {
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
  const isLate = punchInMin == null ? null : punchInMin > lateAfterMin;
  const isHalfDay = isLate;
  const meetsPunchOut = punchOutMin == null ? null : punchOutMin >= eligibleOutAfterMin;
  return { totalMinutes, isLate, isHalfDay, meetsPunchOut };
}

function monthRangeYmd(year: number, month: number) {
  if (!Number.isFinite(year) || year < 2000 || year > 2100) throw new Error('Invalid year');
  if (!Number.isFinite(month) || month < 1 || month > 12) throw new Error('Invalid month');
  const lastDay = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const from = `${year}-${String(month).padStart(2, '0')}-01`;
  const to = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
  return { from, to };
}

export const attendanceService = {
  async getAdminPolicy() {
    // Ensure row exists so admin UI always has something to edit
    const row = await prisma.attendancePolicy.upsert({
      where: { id: 'default' },
      update: {},
      create: { ...DEFAULT_POLICY, updatedBy: 'system' },
    });
    return {
      id: row.id,
      defaultPunchInTime: row.defaultPunchInTime,
      defaultPunchOutTime: row.defaultPunchOutTime,
      punchInBufferMinutes: row.punchInBufferMinutes,
      punchOutBufferMinutes: row.punchOutBufferMinutes,
      updatedAt: row.updatedAt.toISOString(),
      updatedBy: row.updatedBy ?? null,
    };
  },

  async updateAdminPolicy(params: {
    defaultPunchInTime: string;
    defaultPunchOutTime: string;
    punchInBufferMinutes: number;
    punchOutBufferMinutes: number;
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

    const row = await prisma.attendancePolicy.upsert({
      where: { id: 'default' },
      update: {
        defaultPunchInTime: params.defaultPunchInTime,
        defaultPunchOutTime: params.defaultPunchOutTime,
        punchInBufferMinutes: params.punchInBufferMinutes,
        punchOutBufferMinutes: params.punchOutBufferMinutes,
        updatedBy: params.updatedBy,
      },
      create: {
        id: 'default',
        defaultPunchInTime: params.defaultPunchInTime,
        defaultPunchOutTime: params.defaultPunchOutTime,
        punchInBufferMinutes: params.punchInBufferMinutes,
        punchOutBufferMinutes: params.punchOutBufferMinutes,
        updatedBy: params.updatedBy,
      },
    });

    return {
      id: row.id,
      defaultPunchInTime: row.defaultPunchInTime,
      defaultPunchOutTime: row.defaultPunchOutTime,
      punchInBufferMinutes: row.punchInBufferMinutes,
      punchOutBufferMinutes: row.punchOutBufferMinutes,
      updatedAt: row.updatedAt.toISOString(),
      updatedBy: row.updatedBy ?? null,
    };
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
      select: { punchAt: true },
    });

    // Group by YYYY-MM-DD (IST)
    const byDay: Record<string, { count: number; firstIn?: string; lastOut?: string }> = {};
    for (const p of punches) {
      const d = new Date(p.punchAt);
      const key = istKeyFromUtcDate(d);
      const iso = d.toISOString(); // stored/transported as UTC ISO; UI formats as IST
      if (!byDay[key]) byDay[key] = { count: 0, firstIn: iso, lastOut: iso };
      byDay[key].count += 1;
      byDay[key].firstIn = byDay[key].firstIn ? (byDay[key].firstIn < iso ? byDay[key].firstIn : iso) : iso;
      byDay[key].lastOut = byDay[key].lastOut ? (byDay[key].lastOut > iso ? byDay[key].lastOut : iso) : iso;
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
      select: { id: true, punchAt: true, terminalId: true, punchType: true, source: true },
    });

    const firstIn = punches[0]?.punchAt ? new Date(punches[0].punchAt).toISOString() : null;
    const lastOut = punches.length ? new Date(punches[punches.length - 1].punchAt).toISOString() : null;

    const policy = await resolveEffectivePolicy(params.employeeId);
    const { totalMinutes, isLate, isHalfDay, meetsPunchOut } = evaluateDayPunches(
      policy,
      firstIn,
      lastOut,
    );

    return {
      punches,
      summary: {
        firstIn,
        lastOut,
        totalMinutes,
        policy: {
          source: policy.source,
          punchInTime: policy.punchInTime,
          punchOutTime: policy.punchOutTime,
          punchInBufferMinutes: policy.punchInBufferMinutes,
          punchOutBufferMinutes: policy.punchOutBufferMinutes,
          globalPolicy: policy.globalPolicy,
          employeeSettings: policy.employeeSettings,
        },
        evaluation: {
          isLate,
          isHalfDay,
          meetsPunchOut,
          thresholds: {
            lateAfter: policy.punchInTime,
            lateBufferMinutes: policy.punchInBufferMinutes,
            punchOutEligibleAfter: policy.punchOutTime,
            punchOutBufferMinutes: policy.punchOutBufferMinutes,
          },
        },
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
      },
    });

    const employees = await prisma.employee.findMany({
      where: { status: 'ACTIVE' },
      include: { generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } } },
      orderBy: { id: 'asc' },
    });

    const byEmployee: Record<number, Array<{ id: string; punchAt: string; terminalId: string | null; punchType: string | null; source: string }>> = {};
    for (const p of punches) {
      const arr = byEmployee[p.employeeId] ?? (byEmployee[p.employeeId] = []);
      arr.push({
        id: p.id,
        punchAt: new Date(p.punchAt).toISOString(),
        terminalId: p.terminalId ?? null,
        punchType: p.punchType ?? null,
        source: String(p.source),
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
      select: { id: true, punchAt: true, terminalId: true, punchType: true, source: true },
    });

    const policy = await resolveEffectivePolicy(params.employeeId);

    type PunchRow = {
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
        source: String(p.source),
      });
    }

    // Iterate every IST day in [from, to] inclusive so empty days appear.
    const days: Array<{
      date: string;
      firstIn: string | null;
      lastOut: string | null;
      totalMinutes: number;
      punches: PunchRow[];
      isLate: boolean | null;
      isHalfDay: boolean | null;
      meetsPunchOut: boolean | null;
    }> = [];

    let cursor = istDayStartUtc(params.from);
    const end = istDayStartUtc(params.to);
    while (cursor.getTime() <= end.getTime()) {
      const date = istKeyFromUtcDate(cursor);
      const dayPunches = byDay[date] ?? [];
      const firstIn = dayPunches[0]?.punchAt ?? null;
      const lastOut = dayPunches.length ? dayPunches[dayPunches.length - 1].punchAt : null;
      const { totalMinutes, isLate, isHalfDay, meetsPunchOut } = evaluateDayPunches(
        policy,
        firstIn,
        lastOut,
      );

      days.push({
        date,
        firstIn,
        lastOut,
        totalMinutes,
        punches: dayPunches,
        isLate,
        isHalfDay,
        meetsPunchOut,
      });

      cursor = new Date(cursor.getTime() + 24 * 60 * 60 * 1000);
    }

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
        source: policy.source,
        punchInTime: policy.punchInTime,
        punchOutTime: policy.punchOutTime,
        punchInBufferMinutes: policy.punchInBufferMinutes,
        punchOutBufferMinutes: policy.punchOutBufferMinutes,
        globalPolicy: policy.globalPolicy,
        employeeSettings: policy.employeeSettings,
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
      include: { leaveType: { select: { code: true, name: true } } },
      orderBy: { fromDate: 'asc' },
    });

    const leaveDaysInMonth = leaveApps.reduce((sum, app) => sum + Number(app.totalDays), 0);

    let presentDays = 0;
    let lateDays = 0;
    let halfDays = 0;
    let totalWorkingMinutes = 0;
    for (const day of history.days) {
      if (day.firstIn) presentDays += 1;
      if (day.isLate === true) lateDays += 1;
      if (day.isHalfDay === true) halfDays += 1;
      totalWorkingMinutes += day.totalMinutes;
    }

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
        absentDays: Math.max(0, history.days.length - presentDays),
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
      select: { id: true, employeeId: true, punchAt: true, terminalId: true, punchType: true, source: true },
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
      select: { id: true, employeeId: true, punchAt: true, terminalId: true, punchType: true, source: true },
    });

    return {
      ...row,
      punchAt: row.punchAt.toISOString(),
      source: String(row.source),
    };
  },
};

