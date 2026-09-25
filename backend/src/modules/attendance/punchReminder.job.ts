import { prisma } from '../../config/prisma';
import { sseService } from '../events/sse.service';
import { emitPushNotify } from '../collaboration/socket';

const IST_OFFSET_MS = 330 * 60 * 1000;
const WEEKDAY_CODES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'] as const;
const REMINDER_MINUTES = 5;
const PUNCH_IN_KIND = 'punch_in_reminder';
const PUNCH_OUT_KIND = 'punch_out_reminder';

let running = false;

type IstNow = {
  ymd: string;
  minutes: number;
  weekday: string;
  dayStart: Date;
  dayEnd: Date;
};

function istNow(now = new Date()): IstNow {
  const shifted = new Date(now.getTime() + IST_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth() + 1;
  const day = shifted.getUTCDate();
  const ymd = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
  const weekday = WEEKDAY_CODES[new Date(Date.UTC(year, month - 1, day)).getUTCDay()] ?? 'SUN';
  const dayStart = new Date(Date.UTC(year, month - 1, day) - IST_OFFSET_MS);
  return {
    ymd,
    minutes: shifted.getUTCHours() * 60 + shifted.getUTCMinutes(),
    weekday,
    dayStart,
    dayEnd: new Date(dayStart.getTime() + 24 * 60 * 60 * 1000),
  };
}

function ymdFromInstant(value: Date): string {
  const shifted = new Date(value.getTime() + IST_OFFSET_MS);
  const year = shifted.getUTCFullYear();
  const month = shifted.getUTCMonth() + 1;
  const day = shifted.getUTCDate();
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function parseHm(value: string | null | undefined): number | null {
  const match = /^(\d{2}):(\d{2})$/.exec(String(value ?? '').trim());
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

function formatHm(total: number): string {
  const hours = Math.floor(total / 60);
  const minutes = total % 60;
  return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
}

function weeklyOff(raw: unknown): Set<string> {
  const days = (Array.isArray(raw) ? raw : [])
    .map((day) => String(day).trim().toUpperCase())
    .filter((day) => (WEEKDAY_CODES as readonly string[]).includes(day));
  return new Set(days.length ? days : ['SUN']);
}

function due(nowMinutes: number, targetMinutes: number): boolean {
  const until = targetMinutes - nowMinutes;
  return until > 0 && until <= REMINDER_MINUTES;
}

async function notify(userId: string, kind: string, title: string, body: string) {
  await prisma.userNotification.create({
    data: {
      userId,
      title,
      body,
      kind,
      path: '/home',
    },
  });
  const payload = { kind, title, body, path: '/home' };
  emitPushNotify([userId], payload);
  sseService.toUser(userId, 'push_notify', payload);
}

/** One reminder, five minutes before each employee's own punch-in and punch-out, on working days. */
export async function runPunchReminders(now = new Date()) {
  if (running) return;
  running = true;
  try {
    const clock = istNow(now);
    const [policy, dayOverride, holidays, leaves, employees, punches, alreadySent] = await Promise.all([
      prisma.attendancePolicy.findUnique({ where: { id: 'default' } }),
      prisma.attendancePolicyDayOverride.findFirst({
        where: { date: { gte: clock.dayStart, lt: clock.dayEnd } },
      }),
      prisma.publicHoliday.findMany({
        where: { date: { gte: new Date(clock.dayStart.getTime() - 24 * 60 * 60 * 1000), lt: clock.dayEnd } },
        select: { date: true, isOptional: true },
      }),
      prisma.leaveApplication.findMany({
        where: {
          status: 'APPROVED',
          isHalfDay: false,
          fromDate: { lt: clock.dayEnd },
          toDate: { gte: clock.dayStart },
        },
        select: { employeeId: true, fromDate: true, toDate: true },
      }),
      prisma.employee.findMany({
        where: {
          status: 'ACTIVE',
          user: { isActive: true, deletedAt: null },
        },
        select: {
          id: true,
          user: { select: { id: true } },
          generalInfo: { select: { weeklyOffDays: true } },
          attendanceSettings: {
            select: { useGlobalPolicy: true, punchInTime: true, punchOutTime: true },
          },
        },
      }),
      prisma.attendancePunch.groupBy({
        by: ['employeeId'],
        where: { punchAt: { gte: clock.dayStart, lt: clock.dayEnd } },
        _count: { _all: true },
      }),
      prisma.userNotification.findMany({
        where: {
          kind: { in: [PUNCH_IN_KIND, PUNCH_OUT_KIND] },
          createdAt: { gte: clock.dayStart, lt: clock.dayEnd },
        },
        select: { userId: true, kind: true },
      }),
    ]);

    const holidayToday = holidays.some((row) => !row.isOptional && ymdFromInstant(row.date) === clock.ymd);
    if (holidayToday) return;

    const onLeave = new Set(
      leaves
        .filter((row) => ymdFromInstant(row.fromDate) <= clock.ymd && ymdFromInstant(row.toDate) >= clock.ymd)
        .map((row) => row.employeeId),
    );
    const punchCount = new Map(punches.map((row) => [row.employeeId, row._count._all]));
    const sent = new Set(alreadySent.map((row) => `${row.userId}:${row.kind}`));

    const globalIn = dayOverride?.defaultPunchInTime ?? policy?.defaultPunchInTime ?? '10:00';
    const globalOut = dayOverride?.defaultPunchOutTime ?? policy?.defaultPunchOutTime ?? '19:00';

    for (const employee of employees) {
      const userId = employee.user?.id;
      if (!userId) continue;
      if (weeklyOff(employee.generalInfo?.weeklyOffDays).has(clock.weekday)) continue;
      if (onLeave.has(employee.id)) continue;

      const settings = employee.attendanceSettings;
      const useOwn = settings != null && settings.useGlobalPolicy === false;
      const punchIn = parseHm(useOwn ? settings.punchInTime ?? globalIn : globalIn);
      const punchOut = parseHm(useOwn ? settings.punchOutTime ?? globalOut : globalOut);
      const count = punchCount.get(employee.id) ?? 0;

      if (punchIn != null && due(clock.minutes, punchIn) && count === 0 && !sent.has(`${userId}:${PUNCH_IN_KIND}`)) {
        const at = formatHm(punchIn);
        await notify(
          userId,
          PUNCH_IN_KIND,
          'Punch in soon',
          `Your punch-in time is ${at}. Punch in within 5 minutes.`,
        );
        sent.add(`${userId}:${PUNCH_IN_KIND}`);
      }

      if (punchOut != null && due(clock.minutes, punchOut) && count < 2 && !sent.has(`${userId}:${PUNCH_OUT_KIND}`)) {
        const at = formatHm(punchOut);
        await notify(
          userId,
          PUNCH_OUT_KIND,
          'Punch out soon',
          `Your punch-out time is ${at}. Punch out within 5 minutes.`,
        );
        sent.add(`${userId}:${PUNCH_OUT_KIND}`);
      }
    }
  } catch (err) {
    console.warn('[punch-reminder] failed', err);
  } finally {
    running = false;
  }
}
