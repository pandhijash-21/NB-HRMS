import { prisma } from '../../config/prisma';
import { leaveBalanceService } from './leaveBalance.service';
import { leaveNotificationService } from './leaveNotification.service';
import { leaveAbsenceExpireQueue } from '../../jobs/leave/leave.queues';

async function getLWPTypeId() {
  const lt = await prisma.leaveType.findUnique({ where: { code: 'LWP' }, select: { id: true } });
  if (!lt) throw new Error('LWP leave type not configured in database');
  return lt.id;
}

async function getAbsenceWindowHours(): Promise<number> {
  const s = await prisma.leaveSetting.findUnique({ where: { key: 'absence_window_hours' } });
  return s ? Number(s.value) : 48;
}

export const absenceLwpService = {
  /**
   * Mark one employee absent for a given date.
   * Creates AbsenceRecord + schedules expiry job.
   */
  async markAbsent(params: {
    employeeId: number;
    date: Date;
    actorId: string;
  }) {
    const { employeeId, date, actorId } = params;

    const windowHours = await getAbsenceWindowHours();
    const markedAt = new Date();
    const windowExpiresAt = new Date(markedAt.getTime() + windowHours * 60 * 60 * 1000);

    const dateOnly = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));

    const existing = await prisma.absenceRecord.findFirst({
      where: { employeeId, date: dateOnly },
    });
    if (existing) return existing;

    const record = await prisma.absenceRecord.create({
      data: { employeeId, date: dateOnly, markedAt, windowExpiresAt, convertedToLwp: false },
    });

    // Schedule expiry job in BullMQ (delayed until windowExpiresAt)
    const delay = windowExpiresAt.getTime() - Date.now();
    const job = await leaveAbsenceExpireQueue.add(
      'expire',
      { absenceRecordId: record.id, employeeId, date: dateOnly.toISOString() },
      { delay: Math.max(delay, 0), jobId: `absence:${record.id}` },
    );

    await prisma.absenceRecord.update({
      where: { id: record.id },
      data: { bullmqJobId: job.id ?? null },
    });

    // Notify employee
    leaveNotificationService.notifyAbsenceWindowExpiring(employeeId, dateOnly, windowHours).catch(() => {});

    return record;
  },

  /**
   * Called by BullMQ when absence window expires.
   * Converts to LWP if no leave was applied.
   */
  async convertToLwpOnExpiry(absenceRecordId: string) {
    const record = await prisma.absenceRecord.findUnique({ where: { id: absenceRecordId } });
    if (!record || record.convertedToLwp || record.leaveApplicationId) return null;

    const lwpTypeId = await getLWPTypeId();
    const year = record.date.getUTCFullYear();
    const month = record.date.getUTCMonth() + 1;

    return prisma.$transaction(async (tx) => {
      // 1. Mark the absence as converted
      await tx.absenceRecord.update({
        where: { id: record.id },
        data: { convertedToLwp: true },
      });

      // 2. Upsert monthly LWP record
      const existing = await tx.monthlyLWPRecord.findUnique({
        where: { employeeId_year_month: { employeeId: record.employeeId, year, month } },
      });
      if (existing) {
        await tx.monthlyLWPRecord.update({
          where: { id: existing.id },
          data: { days: { increment: 1 } },
        });
      } else {
        await tx.monthlyLWPRecord.create({
          data: { employeeId: record.employeeId, year, month, days: 1 },
        });
      }

      // 3. Deduct from LWP balance (credit then mark as used)
      await leaveBalanceService.credit({
        employeeId: record.employeeId,
        leaveTypeId: lwpTypeId,
        year,
        days: 1,
        actorId: 'system',
        action: 'CREDIT',
        context: `AutoLWP:Absence:${record.id}`,
      });

      await leaveBalanceService.approve({
        employeeId: record.employeeId,
        leaveTypeId: lwpTypeId,
        year,
        days: 1,
        actorId: 'system',
        context: `AutoLWP:Absence:${record.id}`,
      });

      return record;
    }).then((r) => {
      leaveNotificationService.notifyLwpConverted(record.employeeId, record.date).catch(() => {});
      return r;
    });
  },

  async listAbsences(params: {
    employeeId?: number;
    year?: number;
    month?: number;
    convertedToLwp?: boolean;
  }) {
    const where: any = {};
    if (params.employeeId) where.employeeId = params.employeeId;
    if (typeof params.convertedToLwp === 'boolean') where.convertedToLwp = params.convertedToLwp;
    if (params.year || params.month) {
      const y = params.year ?? new Date().getUTCFullYear();
      const m = params.month;
      if (m) {
        const start = new Date(Date.UTC(y, m - 1, 1));
        const end   = new Date(Date.UTC(y, m, 1));
        where.date = { gte: start, lt: end };
      } else {
        const start = new Date(Date.UTC(y, 0, 1));
        const end   = new Date(Date.UTC(y + 1, 0, 1));
        where.date = { gte: start, lt: end };
      }
    }
    return prisma.absenceRecord.findMany({
      where,
      orderBy: { date: 'desc' },
      include: {
        employee: {
          include: { generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } } },
        },
      },
    });
  },
};
