import { Worker } from 'bullmq';
import { getBullmqConnection } from '../../config/bullmq';
import { prisma } from '../../config/prisma';
import { leaveBalanceService } from '../../modules/leave/leaveBalance.service';
import {
  creditAuditContext,
  isMidYearCredit,
  parseCreditSchedule,
} from '../../modules/leave/leaveCreditSchedule.util';
import { LEAVE_QUEUE_NAMES } from './leave.queues';

function todayMonthDayUtc() {
  const now = new Date();
  return { month: now.getUTCMonth() + 1, day: now.getUTCDate(), year: now.getUTCFullYear() };
}

function matchesCredit(credit: { month: number; day: number; days: number }, month: number, day: number) {
  return credit.month === month && credit.day === day && credit.days > 0;
}

export function startLeaveCreditWorker() {
  const connection = getBullmqConnection();

  return new Worker(
    LEAVE_QUEUE_NAMES.CREDIT,
    async () => {
      const { month, day, year } = todayMonthDayUtc();

      const leaveTypes = await prisma.leaveType.findMany({
        where: { isActive: true },
        select: {
          id: true,
          code: true,
          applicableTo: true,
          creditSchedule: true,
          isCarryForward: true,
        },
      });

      const employees = await prisma.employeeGeneralInfo.findMany({
        select: { employeeId: true, employeeCategory: true },
      });

      for (const lt of leaveTypes) {
        const credits = parseCreditSchedule(lt.creditSchedule);
        const credit = credits.find((c) => matchesCredit(c, month, day));
        if (!credit) continue;

        const ctx = creditAuditContext(lt.code, year, month, day);

        for (const e of employees) {
          const cat = e.employeeCategory === 'TEACHING' ? 'TEACHING' : 'NON_TEACHING';
          if (lt.applicableTo !== 'BOTH' && lt.applicableTo !== cat) continue;

          const already = await prisma.leaveAuditLog.findFirst({
            where: { employeeId: e.employeeId, context: ctx },
          });
          if (already) continue;

          if (isMidYearCredit(lt.creditSchedule, credit)) {
            await leaveBalanceService.ensureMidYearTransition({
              employeeId: e.employeeId,
              leaveTypeId: lt.id,
              year,
              leaveCode: lt.code,
              isCarryForward: lt.isCarryForward,
              actorId: 'system',
            });
          }

          await leaveBalanceService.credit({
            employeeId: e.employeeId,
            leaveTypeId: lt.id,
            year,
            days: credit.days,
            actorId: 'system',
            action: 'CREDIT',
            context: ctx,
          });
        }
      }

      return { ok: true };
    },
    { connection },
  );
}
