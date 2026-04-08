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
    select: { department: true, subOrganization: true, organization: true },
  });
  if (!gi) throw new Error('Employee general info not found');

  const dept = gi.department;
  const institute = gi.subOrganization ?? gi.organization;

  const [deptRow, instRow, globalRow] = await Promise.all([
    prisma.departmentApprover.findFirst({
      where: { department: dept, isActive: true },
      select: { hodEmployeeId: true },
    }),
    prisma.instituteApprover.findFirst({
      where: { institute, isActive: true },
      select: { hoiEmployeeId: true },
    }),
    prisma.globalApprover.findFirst({
      where: { isActive: true },
      select: { vcEmployeeId: true, registrarEmployeeId: true },
    }),
  ]);

  return {
    hodEmployeeId: deptRow?.hodEmployeeId ?? null,
    hoiEmployeeId: instRow?.hoiEmployeeId ?? null,
    vcEmployeeId: globalRow?.vcEmployeeId ?? null,
    registrarEmployeeId: globalRow?.registrarEmployeeId ?? null,
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
    const [hodHours, hoiHours, globalHours, fallbackHours] = await Promise.all([
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

    const { hodEmployeeId, hoiEmployeeId, vcEmployeeId, registrarEmployeeId } =
      await resolveApprovers(app.employeeId);

    type StepRow = {
      stepNumber: number;
      approverRole: any;
      approverId: number | null;
      windowExpiresAt?: Date;
    };
    const steps: StepRow[] = [];

    if (hodEmployeeId && hodEmployeeId !== app.employeeId) {
      steps.push({ stepNumber: 1, approverRole: 'HOD', approverId: hodEmployeeId, windowExpiresAt: windowFor(hodHours) });
    }
    if (hoiEmployeeId && hoiEmployeeId !== app.employeeId) {
      steps.push({ stepNumber: 2, approverRole: 'HOI', approverId: hoiEmployeeId, windowExpiresAt: windowFor(hoiHours) });
    }

    const finalApprovers: Array<{ role: any; id: number }> = [];
    if (vcEmployeeId) finalApprovers.push({ role: 'VC', id: vcEmployeeId });
    if (registrarEmployeeId) finalApprovers.push({ role: 'REGISTRAR', id: registrarEmployeeId });

    if (finalApprovers.length === 0) {
      throw new Error('No final approver configured (VC/REGISTRAR)');
    }

    for (const fa of finalApprovers) {
      steps.push({ stepNumber: 3, approverRole: fa.role, approverId: fa.id, windowExpiresAt: windowFor(globalHours) });
    }

    await prisma.leaveApprovalStep.createMany({
      data: steps.map((s) => ({
        applicationId: app.id,
        stepNumber:    s.stepNumber,
        approverRole:  s.approverRole,
        approverId:    s.approverId,
        windowExpiresAt: s.windowExpiresAt,
      })),
    });

    return { created: steps.length };
  },

  async approveOrReject(params: {
    applicationId: string;
    approverEmployeeId: number;
    action: 'APPROVE' | 'REJECT';
    remarks?: string;
    actorId: string;
  }) {
    const { applicationId, approverEmployeeId, action, remarks, actorId } = params;

    return prisma.$transaction(async (tx) => {
      const app = await tx.leaveApplication.findUnique({
        where: { id: applicationId },
        include: { approvalSteps: true },
      });
      if (!app) throw new Error('Application not found');
      if (app.status !== 'PENDING') throw new Error('Application is not pending');

      const steps = app.approvalSteps;
      const pendingSteps = steps.filter((s) => isPendingStep(s));
      if (pendingSteps.length === 0) throw new Error('No pending approval steps');

      const minTier = Math.min(...pendingSteps.map((s) => s.stepNumber));
      const tierPending = pendingSteps.filter((s) => s.stepNumber === minTier);

      const myStep = tierPending.find((s) => s.approverId === approverEmployeeId);
      if (!myStep) {
        throw new Error('Not authorized for current approval tier');
      }

      const prismaAction =
        action === 'REJECT'
          ? 'REJECTED'
          : minTier < 3
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
      if (minTier < 3) {
        return { status: 'PENDING' as const };
      }

      // Final tier: first approval finalizes; supersede the other final approver (if any)
      await tx.leaveApprovalStep.updateMany({
        where: { applicationId, id: { not: myStep.id }, stepNumber: 3, action: null, isSuperseded: false },
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

