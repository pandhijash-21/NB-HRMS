import { prisma } from '../../config/prisma';
import { leaveBalanceService } from './leaveBalance.service';

async function getLeaveSettingInt(key: string): Promise<number | null> {
  const row = await prisma.leaveSetting.findUnique({ where: { key } });
  if (!row) return null;
  const n = Number(row.value);
  return Number.isFinite(n) ? n : null;
}

function addHours(d: Date, hours: number): Date {
  const out = new Date(d);
  out.setHours(out.getHours() + hours);
  return out;
}

async function resolveApprovers(employeeId: number) {
  const gi = await prisma.employeeGeneralInfo.findUnique({
    where: { employeeId },
    select: {
      // New (preferred)
      firstApproverUserId: true,
      secondApproverUserId: true,
      thirdApproverUserId: true,
      // Legacy fallback (employee ids)
      firstReportingId: true,
      secondReportingId: true,
      thirdReportingId: true,
    },
  });
  if (!gi) throw new Error('Employee general info not found');

  const legacyIds = [gi.firstReportingId, gi.secondReportingId, gi.thirdReportingId].filter(
    (x): x is number => typeof x === 'number' && Number.isFinite(x),
  );

  const legacyEmployees = legacyIds.length
    ? await prisma.employee.findMany({
        where: { id: { in: legacyIds } },
        select: { id: true, userId: true },
      })
    : [];

  const legacyUserId = (employeeId: number | null) => {
    if (employeeId == null) return null;
    const userId = legacyEmployees.find((e) => e.id === employeeId)?.userId ?? null;
    if (!userId || userId.startsWith('pending-')) return null;
    return userId;
  };

  // Per layer: explicit approver user id (employee or position account), else legacy employee → user id
  return {
    firstApproverUserId: gi.firstApproverUserId ?? legacyUserId(gi.firstReportingId),
    secondApproverUserId: gi.secondApproverUserId ?? legacyUserId(gi.secondReportingId),
    thirdApproverUserId: gi.thirdApproverUserId ?? legacyUserId(gi.thirdReportingId),
  };
}

function isPendingStep(s: { action: unknown; isSuperseded: boolean }) {
  return !s.isSuperseded && (s.action === null || typeof s.action === 'undefined');
}

export const leaveApprovalWorkflowService = {
  /**
   * Creates 3-tier steps:
   * 1) HOD (if configured and not self)
   * 2) HOI (if configured and not self)
   * 3) VC + Registrar (parallel if both configured; either can finalize)
   */
  async createStepsForApplication(applicationId: string) {
    const app = await prisma.leaveApplication.findUnique({
      where: { id: applicationId },
      select: { id: true, employeeId: true },
    });
    if (!app) throw new Error('Application not found');

    // Fetch per-role windows in parallel; fall back to shared approver_window_hours
    // Keys reuse existing hod/hoi/global settings rows — only UI labels change
    const [firstHours, secondHours, thirdHours, fallbackHours] = await Promise.all([
      getLeaveSettingInt('hod_window_hours'),
      getLeaveSettingInt('hoi_window_hours'),
      getLeaveSettingInt('global_window_hours'),
      getLeaveSettingInt('approver_window_hours'),
    ]);

    const now = new Date();
    const windowFor = (hours: number | null): Date | undefined => {
      const h = hours ?? fallbackHours;
      return h ? addHours(now, h) : undefined;
    };

    const { firstApproverUserId, secondApproverUserId, thirdApproverUserId } =
      await resolveApprovers(app.employeeId);

    type StepRow = {
      stepNumber: number;
      approverRole: any;
      approverUserId: string | null;
      windowExpiresAt?: Date;
    };
    const steps: StepRow[] = [];

    let stepNumber = 1;
    if (firstApproverUserId) {
      steps.push({ stepNumber, approverRole: 'FIRST_REPORTING', approverUserId: firstApproverUserId, windowExpiresAt: windowFor(firstHours) });
      stepNumber += 1;
    }
    if (secondApproverUserId) {
      steps.push({ stepNumber, approverRole: 'SECOND_REPORTING', approverUserId: secondApproverUserId, windowExpiresAt: windowFor(secondHours) });
      stepNumber += 1;
    }

    if (thirdApproverUserId) {
      steps.push({ stepNumber, approverRole: 'THIRD_REPORTING', approverUserId: thirdApproverUserId, windowExpiresAt: windowFor(thirdHours) });
      stepNumber += 1;
    }

    if (steps.length === 0) {
      throw new Error('No reporting manager configured for this employee. Please set at least one reporting layer before applying for leave.');
    }

    await prisma.leaveApprovalStep.createMany({
      data: steps.map((s) => ({
        applicationId: app.id,
        stepNumber:    s.stepNumber,
        approverRole:  s.approverRole,
        approverUserId: s.approverUserId,
        windowExpiresAt: s.windowExpiresAt,
      })),
    });

    return { created: steps.length };
  },

  async approveOrReject(params: {
    applicationId: string;
    approverUserId: string;
    action: 'APPROVE' | 'REJECT';
    remarks?: string;
    actorId: string;
  }) {
    const { applicationId, approverUserId, action, remarks, actorId } = params;

    return prisma.$transaction(async (tx) => {
      const app = await tx.leaveApplication.findUnique({
        where: { id: applicationId },
        include: { approvalSteps: true },
      });
      if (!app) throw new Error('Application not found');
      if (app.status !== 'PENDING') throw new Error('Application is not pending');

      const steps = app.approvalSteps;
      const finalTier = steps.length ? Math.max(...steps.map((s) => s.stepNumber)) : 0;
      const pendingSteps = steps.filter((s) => isPendingStep(s));
      if (pendingSteps.length === 0) throw new Error('No pending approval steps');

      const minTier = Math.min(...pendingSteps.map((s) => s.stepNumber));
      const tierPending = pendingSteps.filter((s) => s.stepNumber === minTier);

      const myStep = tierPending.find((s) => s.approverUserId === approverUserId);
      if (!myStep) {
        throw new Error('Not authorized for current approval tier');
      }

      const prismaAction =
        action === 'REJECT'
          ? 'REJECTED'
          : minTier < finalTier
            ? 'RECOMMENDED'
            : 'APPROVED';

      await tx.leaveApprovalStep.update({
        where: { id: myStep.id },
        data: { action: prismaAction, remarks, actionAt: new Date() },
      });

      if (action === 'REJECT') {
        // Supersede any other pending steps
        await tx.leaveApprovalStep.updateMany({
          where: { applicationId, id: { not: myStep.id }, action: null, isSuperseded: false },
          data: { isSuperseded: true },
        });

        await tx.leaveApplication.update({
          where: { id: applicationId },
          data: { status: 'REJECTED' },
        });

        // Revert pending balance (days were reserved at apply time)
        const year = app.fromDate.getUTCFullYear();
        await leaveBalanceService.revertPending({
          employeeId: app.employeeId,
          leaveTypeId: app.leaveTypeId,
          year,
          days: app.totalDays,
          actorId,
          revertAction: 'REJECT_REVERT',
          context: `LeaveApplication:${applicationId}`,
        });

        return { status: 'REJECTED' as const };
      }

      // If this tier is not final, just continue
      if (minTier < finalTier) {
        return { status: 'PENDING' as const };
      }

      // Final tier: first approval finalizes; supersede the other final approver (if any)
      await tx.leaveApprovalStep.updateMany({
        where: { applicationId, id: { not: myStep.id }, stepNumber: finalTier, action: null, isSuperseded: false },
        data: { isSuperseded: true },
      });

      await tx.leaveApplication.update({
        where: { id: applicationId },
        data: { status: 'APPROVED' },
      });

      const year = app.fromDate.getUTCFullYear();
      await leaveBalanceService.approve({
        employeeId: app.employeeId,
        leaveTypeId: app.leaveTypeId,
        year,
        days: app.totalDays,
        actorId,
        context: `LeaveApplication:${applicationId}`,
      });

      return { status: 'APPROVED' as const };
    });
  },
};

