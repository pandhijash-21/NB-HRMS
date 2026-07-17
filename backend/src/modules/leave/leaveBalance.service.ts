import { prisma } from '../../config/prisma';
import {
  creditAuditContext,
  creditsDueByDate,
  isMidYearCredit,
  midYearTransitionContext,
  parseCreditSchedule,
} from './leaveCreditSchedule.util';

function computeAvailable(
  totalCredited: number,
  carryForward: number,
  used: number,
  pending: number,
) {
  return totalCredited + carryForward - used - pending;
}

export type BalanceAdjustAction =
  | 'CREDIT'
  | 'CARRY_FORWARD'
  | 'APPLY_PENDING'
  | 'APPROVE'
  | 'REJECT_REVERT'
  | 'CANCEL_REVERT'
  | 'MANUAL_ADJUST';

export const leaveBalanceService = {
  async ensureBalanceRow(employeeId: number, leaveTypeId: string, year: number) {
    return prisma.leaveBalance.upsert({
      where: { employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year } },
      update: {},
      create: {
        employeeId,
        leaveTypeId,
        year,
        totalCredited: 0,
        carryForward: 0,
        used: 0,
        pending: 0,
        available: 0,
      },
    });
  },

  /**
   * Credits leave (or carry-forward) into totalCredited.
   * Always writes LeaveAuditLog in the same transaction.
   */
  async credit(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    days: number;
    actorId: string;
    action: BalanceAdjustAction;
    context?: string;
  }) {
    const { employeeId, leaveTypeId, year, days, actorId, action, context } = params;
    if (!Number.isFinite(days) || days <= 0) throw new Error('days must be > 0');

    return prisma.$transaction(async (tx) => {
      const row = await tx.leaveBalance.upsert({
        where: { employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year } },
        update: {},
        create: {
          employeeId,
          leaveTypeId,
          year,
          totalCredited: 0,
          carryForward: 0,
          used: 0,
          pending: 0,
          available: 0,
        },
      });

      const oldValue = { ...row };
      const totalCredited = row.totalCredited + days;
      const available = computeAvailable(totalCredited, row.carryForward, row.used, row.pending);

      const updated = await tx.leaveBalance.update({
        where: { id: row.id },
        data: {
          totalCredited,
          available,
          lastCreditedAt: new Date(),
        },
      });

      await tx.leaveAuditLog.create({
        data: {
          employeeId,
          actorId,
          action,
          context,
          oldValue: oldValue as any,
          newValue: updated as any,
        },
      });

      return updated;
    });
  },

  /**
   * Year-end: move unused available days into next year's `carryForward` field
   * (only for leave types with isCarryForward enabled — caller filters).
   */
  async applyYearEndCarryForward(params: {
    employeeId: number;
    leaveTypeId: string;
    fromYear: number;
    toYear: number;
    days: number;
    actorId: string;
  }) {
    const { employeeId, leaveTypeId, fromYear, toYear, days, actorId } = params;
    if (!Number.isFinite(days) || days <= 0) return null;

    return prisma.$transaction(async (tx) => {
      const row = await tx.leaveBalance.upsert({
        where: {
          employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year: toYear },
        },
        update: {},
        create: {
          employeeId,
          leaveTypeId,
          year: toYear,
          totalCredited: 0,
          carryForward: 0,
          used: 0,
          pending: 0,
          available: 0,
        },
      });

      const oldValue = { ...row };
      const carryForward = row.carryForward + days;
      const available = computeAvailable(row.totalCredited, carryForward, row.used, row.pending);

      const updated = await tx.leaveBalance.update({
        where: { id: row.id },
        data: { carryForward, available },
      });

      await tx.leaveAuditLog.create({
        data: {
          employeeId,
          actorId,
          action: 'CARRY_FORWARD',
          context: `YearEnd:${fromYear}->${toYear}:${leaveTypeId}`,
          oldValue: oldValue as any,
          newValue: updated as any,
        },
      });

      return updated;
    });
  },

  async applyPending(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    days: number;
    actorId: string;
    context?: string;
  }) {
    const { employeeId, leaveTypeId, year, days, actorId, context } = params;
    if (!Number.isFinite(days) || days <= 0) throw new Error('days must be > 0');

    return prisma.$transaction(async (tx) => {
      const row = await tx.leaveBalance.upsert({
        where: { employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year } },
        update: {},
        create: {
          employeeId,
          leaveTypeId,
          year,
          totalCredited: 0,
          carryForward: 0,
          used: 0,
          pending: 0,
          available: 0,
        },
      });

      const currentAvailable = computeAvailable(
        row.totalCredited,
        row.carryForward,
        row.used,
        row.pending,
      );
      if (currentAvailable < days) {
        throw new Error('Insufficient leave balance');
      }

      const oldValue = { ...row };
      const pending = row.pending + days;
      const available = computeAvailable(row.totalCredited, row.carryForward, row.used, pending);

      const updated = await tx.leaveBalance.update({
        where: { id: row.id },
        data: { pending, available },
      });

      await tx.leaveAuditLog.create({
        data: {
          employeeId,
          actorId,
          action: 'APPLY_PENDING',
          context,
          oldValue: oldValue as any,
          newValue: updated as any,
        },
      });

      return updated;
    });
  },

  async approve(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    days: number;
    actorId: string;
    context?: string;
  }) {
    const { employeeId, leaveTypeId, year, days, actorId, context } = params;
    if (!Number.isFinite(days) || days <= 0) throw new Error('days must be > 0');

    return prisma.$transaction(async (tx) => {
      const row = await tx.leaveBalance.findUnique({
        where: { employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year } },
      });
      if (!row) throw new Error('Leave balance row not found');
      if (row.pending < days) throw new Error('Pending balance is less than approval days');

      const oldValue = { ...row };
      const used = row.used + days;
      const pending = row.pending - days;
      const available = computeAvailable(row.totalCredited, row.carryForward, used, pending);

      const updated = await tx.leaveBalance.update({
        where: { id: row.id },
        data: { used, pending, available },
      });

      await tx.leaveAuditLog.create({
        data: {
          employeeId,
          actorId,
          action: 'APPROVE',
          context,
          oldValue: oldValue as any,
          newValue: updated as any,
        },
      });

      return updated;
    });
  },

  async revertPending(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    days: number;
    actorId: string;
    revertAction: 'REJECT_REVERT' | 'CANCEL_REVERT';
    context?: string;
  }) {
    const { employeeId, leaveTypeId, year, days, actorId, revertAction, context } = params;
    if (!Number.isFinite(days) || days <= 0) throw new Error('days must be > 0');

    return prisma.$transaction(async (tx) => {
      const row = await tx.leaveBalance.findUnique({
        where: { employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year } },
      });
      if (!row) throw new Error('Leave balance row not found');
      if (row.pending < days) throw new Error('Pending balance is less than revert days');

      const oldValue = { ...row };
      const pending = row.pending - days;
      const available = computeAvailable(row.totalCredited, row.carryForward, row.used, pending);

      const updated = await tx.leaveBalance.update({
        where: { id: row.id },
        data: { pending, available },
      });

      await tx.leaveAuditLog.create({
        data: {
          employeeId,
          actorId,
          action: revertAction,
          context,
          oldValue: oldValue as any,
          newValue: updated as any,
        },
      });

      return updated;
    });
  },

  async manualAdjust(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    totalCredited?: number;
    carryForward?: number;
    used?: number;
    pending?: number;
    actorId: string;
    context: string;
  }) {
    const { employeeId, leaveTypeId, year, actorId, context } = params;

    return prisma.$transaction(async (tx) => {
      const row = await tx.leaveBalance.upsert({
        where: { employeeId_leaveTypeId_year: { employeeId, leaveTypeId, year } },
        update: {},
        create: {
          employeeId,
          leaveTypeId,
          year,
          totalCredited: 0,
          carryForward: 0,
          used: 0,
          pending: 0,
          available: 0,
        },
      });

      const nextTotalCredited = params.totalCredited ?? row.totalCredited;
      const nextUsed = params.used ?? row.used;
      const nextPending = params.pending ?? row.pending;
      const nextCarryForward = params.carryForward ?? row.carryForward;

      const available = computeAvailable(
        nextTotalCredited,
        nextCarryForward,
        nextUsed,
        nextPending,
      );

      const oldValue = { ...row };
      const updated = await tx.leaveBalance.update({
        where: { id: row.id },
        data: {
          totalCredited: nextTotalCredited,
          carryForward: nextCarryForward,
          used: nextUsed,
          pending: nextPending,
          available,
        },
      });

      await tx.leaveAuditLog.create({
        data: {
          employeeId,
          actorId,
          action: 'MANUAL_ADJUST',
          context,
          oldValue: oldValue as any,
          newValue: updated as any,
        },
      });

      return updated;
    });
  },

  /**
   * At the second credit tranche (e.g. Jul 1): move unused Jan–Jun balance into carryForward
   * when enabled; otherwise forfeit unused first-half days. Then Jul credit is applied separately.
   */
  async ensureMidYearTransition(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    leaveCode: string;
    isCarryForward: boolean;
    actorId: string;
  }) {
    const midCtx = midYearTransitionContext(params.leaveCode, params.year);
    const done = await prisma.leaveAuditLog.findFirst({
      where: { employeeId: params.employeeId, context: midCtx },
    });
    if (done) return;

    const row = await this.ensureBalanceRow(params.employeeId, params.leaveTypeId, params.year);
    const h1Unused = Math.max(
      0,
      computeAvailable(row.totalCredited, row.carryForward, row.used, row.pending),
    );

    const nextCarryForward =
      params.isCarryForward && h1Unused > 0 ? row.carryForward + h1Unused : row.carryForward;
    const nextTotalCredited = row.used + row.pending;

    if (
      nextCarryForward !== row.carryForward ||
      nextTotalCredited !== row.totalCredited
    ) {
      await this.manualAdjust({
        employeeId: params.employeeId,
        leaveTypeId: params.leaveTypeId,
        year: params.year,
        totalCredited: nextTotalCredited,
        carryForward: nextCarryForward,
        used: row.used,
        pending: row.pending,
        actorId: params.actorId,
        context: midCtx,
      });
    } else {
      await this.markCreditApplied({
        employeeId: params.employeeId,
        leaveTypeId: params.leaveTypeId,
        year: params.year,
        context: midCtx,
        actorId: params.actorId,
      });
    }
  },

  /** Record that a scheduled credit was satisfied (e.g. legacy seed already included the days). */
  async markCreditApplied(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    context: string;
    actorId: string;
  }) {
    const row = await this.ensureBalanceRow(params.employeeId, params.leaveTypeId, params.year);
    await prisma.leaveAuditLog.create({
      data: {
        employeeId: params.employeeId,
        actorId: params.actorId,
        action: 'CREDIT',
        context: params.context,
        oldValue: row as any,
        newValue: row as any,
      },
    });
  },

  /**
   * Apply scheduled credits (Jan 1 / Jul 1, etc.) idempotently and fix over-credits from legacy seed.
   */
  async syncScheduledCredits(employeeId: number, year?: number, actorId = 'system') {
    const y = year ?? new Date().getUTCFullYear();
    const asOf = new Date();
    if (asOf.getUTCFullYear() !== y) return;

    const general = await prisma.employeeGeneralInfo.findUnique({
      where: { employeeId },
      select: { employeeCategory: true },
    });
    if (!general) return;

    const cat = general.employeeCategory === 'TEACHING' ? 'TEACHING' : 'NON_TEACHING';

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

    for (const lt of leaveTypes) {
      if (lt.applicableTo !== 'BOTH' && lt.applicableTo !== cat) continue;

      const schedule = parseCreditSchedule(lt.creditSchedule);
      if (schedule.length === 0) continue;

      const dueCredits = creditsDueByDate(lt.creditSchedule, y, asOf).sort(
        (a, b) => a.month - b.month || a.day - b.day,
      );

      let runningExpected = 0;
      for (const credit of dueCredits) {
        runningExpected += credit.days;
        const ctx = creditAuditContext(lt.code, y, credit.month, credit.day);
        const already = await prisma.leaveAuditLog.findFirst({
          where: { employeeId, context: ctx },
        });
        if (already) continue;

        if (isMidYearCredit(lt.creditSchedule, credit)) {
          await this.ensureMidYearTransition({
            employeeId,
            leaveTypeId: lt.id,
            year: y,
            leaveCode: lt.code,
            isCarryForward: lt.isCarryForward,
            actorId,
          });
        }

        let row = await this.ensureBalanceRow(employeeId, lt.id, y);

        if (row.totalCredited > runningExpected) {
          await this.manualAdjust({
            employeeId,
            leaveTypeId: lt.id,
            year: y,
            totalCredited: runningExpected,
            carryForward: row.carryForward,
            used: row.used,
            pending: row.pending,
            actorId,
            context: `ReconcileSchedule:${lt.code}:${y}:${credit.month}-${credit.day}`,
          });
          row = await this.ensureBalanceRow(employeeId, lt.id, y);
        }

        if (row.totalCredited >= runningExpected) {
          await this.markCreditApplied({
            employeeId,
            leaveTypeId: lt.id,
            year: y,
            context: ctx,
            actorId,
          });
          continue;
        }

        const toAdd = runningExpected - row.totalCredited;
        await this.credit({
          employeeId,
          leaveTypeId: lt.id,
          year: y,
          days: toAdd,
          actorId,
          action: 'CREDIT',
          context: ctx,
        });
      }
    }
  },
};

