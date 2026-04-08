import { prisma } from '../../config/prisma';

function computeAvailable(totalCredited: number, used: number, pending: number) {
  return totalCredited - used - pending;
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
      const available = computeAvailable(totalCredited, row.used, row.pending);

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

      if (row.available < days) {
        throw new Error('Insufficient leave balance');
      }

      const oldValue = { ...row };
      const pending = row.pending + days;
      const available = computeAvailable(row.totalCredited, row.used, pending);

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
      const available = computeAvailable(row.totalCredited, used, pending);

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
      const available = computeAvailable(row.totalCredited, row.used, pending);

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

      const available = computeAvailable(nextTotalCredited, nextUsed, nextPending);

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
};

