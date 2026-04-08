import { prisma } from '../../config/prisma';
import {
  leaveAbsenceExpireQueue,
  leaveApproverReminderQueue,
  leaveApproverTimeoutQueue,
  leaveCreditQueue,
  leaveYearEndQueue,
} from './leave.queues';

function parseMonthDay(mmdd: string): { month: number; day: number } | null {
  const m = /^(\d{2})-(\d{2})$/.exec(mmdd);
  if (!m) return null;
  const month = Number(m[1]);
  const day = Number(m[2]);
  if (!Number.isFinite(month) || !Number.isFinite(day)) return null;
  return { month, day };
}

function cronForMonthDay(month: number, day: number) {
  // Run at 00:10 UTC on that day every year
  return `10 0 ${day} ${month} *`;
}

export async function ensureLeaveRepeatableJobs() {
  const [ny, my, ye] = await Promise.all([
    prisma.leaveSetting.findUnique({ where: { key: 'new_year_credit_date' } }),
    prisma.leaveSetting.findUnique({ where: { key: 'mid_year_credit_date' } }),
    prisma.leaveSetting.findUnique({ where: { key: 'yearend_processing_date' } }),
  ]);

  const newYear = ny ? parseMonthDay(ny.value) : null;
  const midYear = my ? parseMonthDay(my.value) : null;
  const yearEnd = ye ? parseMonthDay(ye.value) : null;

  if (newYear) {
    await leaveCreditQueue.add(
      'credit-new-year',
      {},
      { repeat: { pattern: cronForMonthDay(newYear.month, newYear.day), tz: 'UTC' } }
    );
  }
  if (midYear) {
    await leaveCreditQueue.add(
      'credit-mid-year',
      {},
      { repeat: { pattern: cronForMonthDay(midYear.month, midYear.day), tz: 'UTC' } }
    );
  }
  if (yearEnd) {
    await leaveYearEndQueue.add(
      'year-end',
      {},
      { repeat: { pattern: cronForMonthDay(yearEnd.month, yearEnd.day), tz: 'UTC' } }
    );
  }

  // Placeholder repeaters for reminder/timeout/absence-expiry scanning.
  await leaveApproverReminderQueue.add(
    'scan',
    {},
    { repeat: { pattern: '*/30 * * * *', tz: 'UTC' } }
  );
  await leaveApproverTimeoutQueue.add(
    'scan',
    {},
    { repeat: { pattern: '*/15 * * * *', tz: 'UTC' } }
  );
  await leaveAbsenceExpireQueue.add(
    'scan',
    {},
    { repeat: { pattern: '*/30 * * * *', tz: 'UTC' } }
  );
}

