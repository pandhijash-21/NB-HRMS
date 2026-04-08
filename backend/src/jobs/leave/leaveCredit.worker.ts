import { Worker } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';
import { prisma } from '../../config/prisma';
import { leaveBalanceService } from '../../modules/leave/leaveBalance.service';
import { LEAVE_QUEUE_NAMES } from './leave.queues';

function todayMonthDayUtc() {
  const now = new Date();
  return { month: now.getUTCMonth() + 1, day: now.getUTCDate(), year: now.getUTCFullYear() };
}

function matchesCredit(credit: any, month: number, day: number) {
  return credit?.month === month && credit?.day === day && Number(credit?.days) > 0;
}

export function startLeaveCreditWorker() {
  const connection = getBullmqConnection();

  return new Worker(
    LEAVE_QUEUE_NAMES.CREDIT,
    async () => {
      const { month, day, year } = todayMonthDayUtc();

      const leaveTypes = await prisma.leaveType.findMany({
        where: { isActive: true },
        select: { id: true, code: true, applicableTo: true, creditSchedule: true },
      });

      const employees = await prisma.employeeGeneralInfo.findMany({
        select: { employeeId: true, employeeCategory: true },
      });

      for (const lt of leaveTypes) {
        const schedule = lt.creditSchedule as any;
        const credits: any[] = Array.isArray(schedule?.credits) ? schedule.credits : [];
        const credit = credits.find((c) => matchesCredit(c, month, day));
        if (!credit) continue;

        const daysToCredit = Number(credit.days);
        for (const e of employees) {
          const cat = e.employeeCategory === 'TEACHING' ? 'TEACHING' : 'NON_TEACHING';
          if (lt.applicableTo !== 'BOTH' && lt.applicableTo !== cat) continue;

          await leaveBalanceService.credit({
            employeeId: e.employeeId,
            leaveTypeId: lt.id,
            year,
            days: daysToCredit,
            actorId: 'system',
            action: 'CREDIT',
            context: `AutoCredit:${lt.code}:${month}-${day}`,
          });
        }
      }

      return { ok: true };
    },
    { connection }
  );
}

