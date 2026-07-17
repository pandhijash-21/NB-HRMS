import { prisma } from '../../config/prisma';
import { leaveBalanceService } from './leaveBalance.service';

async function getLeaveSettingInt(key: string): Promise<number | null> {
  const row = await prisma.leaveSetting.findUnique({ where: { key } });
  if (!row) return null;
  const raw = String(row.value ?? '').trim();
  if (!raw || raw.toLowerCase() === 'null') return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

function addHours(d: Date, hours: number): Date {
  const out = new Date(d);
  out.setHours(out.getHours() + hours);
  return out;
}

/** Map step role → leave setting key for that layer's approval window. */
function windowSettingKeyForRole(approverRole: string): string {
  switch (approverRole) {
    case 'FIRST_REPORTING':
    case 'HOD':
      return 'hod_window_hours';
    case 'SECOND_REPORTING':
    case 'HOI':
      return 'hoi_window_hours';
    case 'THIRD_REPORTING':
    case 'VC':
    case 'REGISTRAR':
      return 'global_window_hours';
    default:
      return 'approver_window_hours';
  }
}

async function resolveApprovers(employeeId: number) {
  const gi = await prisma.employeeGeneralInfo.findUnique({
    where: { employeeId },
    select: {
      firstApproverUserId: true,
      secondApproverUserId: true,
      thirdApproverUserId: true,
      firstReportingId: true,
      secondReportingId: true,
      thirdReportingId: true,
    },
  });
  if (!gi) throw new Error('Employee general info not found');

  const employee = await prisma.employee.findUnique({
    where: { id: employeeId },
    select: { userId: true },
  });
  const selfUserId =
    employee?.userId && !employee.userId.startsWith('pending-') ? employee.userId : null;

  const legacyIds = [gi.firstReportingId, gi.secondReportingId, gi.thirdReportingId].filter(
    (x): x is number => typeof x === 'number' && Number.isFinite(x),
  );

  const legacyEmployees = legacyIds.length
    ? await prisma.employee.findMany({
        where: { id: { in: legacyIds } },
        select: { id: true, userId: true },
      })
    : [];

  const legacyUserId = (empId: number | null) => {
    if (empId == null) return null;
    const userId = legacyEmployees.find((e) => e.id === empId)?.userId ?? null;
    if (!userId || userId.startsWith('pending-')) return null;
    return userId;
  };

  const normalize = (userId: string | null | undefined): string | null => {
    if (!userId) return null;
    // Self cannot approve own leave — treat as NULL (bypass)
    if (selfUserId && userId === selfUserId) return null;
    return userId;
  };

  // Per layer: explicit approver user id, else legacy employee → user id. NULL = bypass.
  return {
    firstApproverUserId: normalize(gi.firstApproverUserId ?? legacyUserId(gi.firstReportingId)),
    secondApproverUserId: normalize(gi.secondApproverUserId ?? legacyUserId(gi.secondReportingId)),
    thirdApproverUserId: normalize(gi.thirdApproverUserId ?? legacyUserId(gi.thirdReportingId)),
  };
}

function isPendingStep(s: { action: unknown; isSuperseded: boolean }) {
  return !s.isSuperseded && (s.action === null || typeof s.action === 'undefined');
}

export const leaveApprovalWorkflowService = {
  /**
   * Creates sequential approval steps from profile reporting managers:
   * 1st → 2nd → 3rd (final). NULL layers are omitted (bypassed).
   * Only the first active tier gets a timeout window; later tiers start when they become current.
   */
  async createStepsForApplication(applicationId: string) {
    const app = await prisma.leaveApplication.findUnique({
      where: { id: applicationId },
      select: { id: true, employeeId: true },
    });
    if (!app) throw new Error('Application not found');

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
      steps.push({
        stepNumber,
        approverRole: 'FIRST_REPORTING',
        approverUserId: firstApproverUserId,
        windowExpiresAt: windowFor(firstHours),
      });
      stepNumber += 1;
    }
    if (secondApproverUserId) {
      // Window starts only when this tier becomes current (after prior approve / escalate)
      steps.push({
        stepNumber,
        approverRole: 'SECOND_REPORTING',
        approverUserId: secondApproverUserId,
      });
      stepNumber += 1;
    }
    if (thirdApproverUserId) {
      steps.push({
        stepNumber,
        approverRole: 'THIRD_REPORTING',
        approverUserId: thirdApproverUserId,
      });
      stepNumber += 1;
    }

    // If only 2nd/3rd exist, first created step needs its window now
    if (steps.length > 0 && !steps[0].windowExpiresAt) {
      const role = steps[0].approverRole as string;
      const hours =
        role === 'SECOND_REPORTING'
          ? secondHours
          : role === 'THIRD_REPORTING'
            ? thirdHours
            : firstHours;
      steps[0].windowExpiresAt = windowFor(hours);
    }

    if (steps.length === 0) {
      throw new Error(
        'No reporting manager configured for this employee. Please set at least one reporting layer before applying for leave.',
      );
    }

    await prisma.leaveApprovalStep.createMany({
      data: steps.map((s) => ({
        applicationId: app.id,
        stepNumber: s.stepNumber,
        approverRole: s.approverRole,
        approverUserId: s.approverUserId,
        windowExpiresAt: s.windowExpiresAt,
      })),
    });

    return { created: steps.length };
  },

  /**
   * Starts the approval timeout window for the current pending tier
   * (used when a prior tier is approved / auto-escalated).
   */
  async startWindowForCurrentTier(applicationId: string) {
    const steps = await prisma.leaveApprovalStep.findMany({
      where: { applicationId, isSuperseded: false, action: null },
      orderBy: { stepNumber: 'asc' },
    });
    if (steps.length === 0) return;

    const minTier = Math.min(...steps.map((s) => s.stepNumber));
    const current = steps.filter((s) => s.stepNumber === minTier);
    if (current.every((s) => s.windowExpiresAt != null)) return;

    const role = String(current[0]?.approverRole ?? '');
    const [roleHours, fallbackHours] = await Promise.all([
      getLeaveSettingInt(windowSettingKeyForRole(role)),
      getLeaveSettingInt('approver_window_hours'),
    ]);
    const hours = roleHours ?? fallbackHours;
    if (!hours) return;

    const expiresAt = addHours(new Date(), hours);
    await prisma.leaveApprovalStep.updateMany({
      where: {
        applicationId,
        stepNumber: minTier,
        action: null,
        isSuperseded: false,
        windowExpiresAt: null,
      },
      data: { windowExpiresAt: expiresAt },
    });
  },

  async approveOrReject(params: {
    applicationId: string;
    approverUserId: string;
    action: 'APPROVE' | 'REJECT';
    remarks?: string;
    actorId: string;
    /** ADMIN/HR may act on any current-tier step even if not the assigned approver. */
    allowAdminOverride?: boolean;
  }) {
    const { applicationId, approverUserId, action, remarks, actorId, allowAdminOverride } = params;

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

      const myStep =
        tierPending.find((s) => s.approverUserId === approverUserId) ??
        (allowAdminOverride ? tierPending[0] : undefined);
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
        // Rejection is final — do not escalate to further reporting layers
        await tx.leaveApprovalStep.updateMany({
          where: { applicationId, id: { not: myStep.id }, action: null, isSuperseded: false },
          data: { isSuperseded: true },
        });

        await tx.leaveApplication.update({
          where: { id: applicationId },
          data: { status: 'REJECTED' },
        });

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

      // Intermediate approve → stay PENDING; next reporting layer becomes current
      if (minTier < finalTier) {
        return { status: 'PENDING' as const };
      }

      // Final tier approve → leave APPROVED
      await tx.leaveApprovalStep.updateMany({
        where: {
          applicationId,
          id: { not: myStep.id },
          stepNumber: finalTier,
          action: null,
          isSuperseded: false,
        },
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
