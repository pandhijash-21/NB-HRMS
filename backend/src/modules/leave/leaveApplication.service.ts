import { prisma } from '../../config/prisma';
import { calculateLeaveDays } from './leaveDayCalculator.service';
import { leaveBalanceService } from './leaveBalance.service';
import { leaveApprovalWorkflowService } from './leaveApprovalWorkflow.service';
import { leaveNotificationService } from './leaveNotification.service';
import { employmentChangeService } from '../personal-education/employmentChange.service';
import { enrichApplicationsWithApproverNames } from './leaveApprovalStep.util';

function toUtcDateOnly(d: Date | string) {
  const src = new Date(d);
  return new Date(Date.UTC(src.getUTCFullYear(), src.getUTCMonth(), src.getUTCDate()));
}

function generateApplicationNo(): string {
  const now = new Date();
  const y = now.getUTCFullYear();
  const m = String(now.getUTCMonth() + 1).padStart(2, '0');
  const d = String(now.getUTCDate()).padStart(2, '0');
  const rnd = Math.floor(Math.random() * 100000).toString().padStart(5, '0');
  return `LV${y}${m}${d}${rnd}`;
}

export type ApplyLeaveInput = {
  employeeId: number;
  leaveTypeId: string;
  fromDate: Date | string;
  toDate: Date | string;
  isHalfDay?: boolean;
  halfDaySession?: 'MORNING' | 'AFTERNOON' | null;
  reason: string;
  documentUrl?: string | null;
  appliedBy: string;
  isAppliedByAdmin?: boolean;
};

export const leaveApplicationService = {
  async apply(input: ApplyLeaveInput) {
    const from = toUtcDateOnly(input.fromDate);
    const to   = toUtcDateOnly(input.toDate);

    // Validate leave type
    const lt = await prisma.leaveType.findUnique({ where: { id: input.leaveTypeId } });
    if (!lt || !lt.isActive) throw new Error('Invalid or inactive leave type');

    if (!input.isAppliedByAdmin && !lt.employeeCanApply) {
      throw new Error('Employees cannot apply for this leave type. Contact HR/Admin.');
    }

    if (lt.requiresDocument && !(input.documentUrl && String(input.documentUrl).trim())) {
      throw new Error('Supporting document is required for this leave type');
    }

    // Check employee category eligibility
    const gi = await prisma.employeeGeneralInfo.findUnique({
      where: { employeeId: input.employeeId },
      select: { employeeCategory: true },
    });
    if (!gi) throw new Error('Employee not found');
    const cat = gi.employeeCategory === 'TEACHING' ? 'TEACHING' : 'NON_TEACHING';
    if (lt.applicableTo !== 'BOTH' && lt.applicableTo !== cat) {
      throw new Error(`This leave type is not applicable to ${cat} employees`);
    }

    if (input.isHalfDay && !lt.allowHalfDay) {
      throw new Error('Half-day leave is not allowed for this leave type');
    }

    // Calculate days
    const totalDays = await calculateLeaveDays({
      fromDate: from,
      toDate: to,
      isHalfDay: input.isHalfDay ?? false,
      leaveTypeId: input.leaveTypeId,
    });
    if (totalDays <= 0) throw new Error('No working days in selected date range');

    const year = from.getUTCFullYear();

    // Check balance (skip for LWP/DL/AL/OT — unlimited or balance irrelevant)
    const skipBalanceCheck = ['LWP', 'DL', 'AL', 'OT'].includes(lt.code);
    if (!skipBalanceCheck) {
      const balance = await prisma.leaveBalance.findUnique({
        where: { employeeId_leaveTypeId_year: { employeeId: input.employeeId, leaveTypeId: lt.id, year } },
      });
      if (!balance || balance.available < totalDays) {
        throw new Error(`Insufficient ${lt.name} balance. Available: ${balance?.available ?? 0} days`);
      }
    }

    // Detect overlapping approved/pending applications
    const overlap = await prisma.leaveApplication.findFirst({
      where: {
        employeeId: input.employeeId,
        status: { in: ['PENDING', 'APPROVED'] },
        fromDate: { lte: to },
        toDate: { gte: from },
      },
    });
    if (overlap) throw new Error('Overlapping leave application already exists for this period');

    // Create application
    const assignmentId = await employmentChangeService.resolveAssignmentIdForLeave({ employeeId: input.employeeId, fromDate: from });
    const app = await prisma.leaveApplication.create({
      data: {
        applicationNo: generateApplicationNo(),
        employeeId: input.employeeId,
        assignmentId,
        leaveTypeId: input.leaveTypeId,
        fromDate: from,
        toDate: to,
        isHalfDay: input.isHalfDay ?? false,
        halfDaySession: input.halfDaySession ?? null,
        totalDays,
        reason: input.reason,
        documentUrl: input.documentUrl ?? null,
        status: 'PENDING',
        appliedBy: input.appliedBy,
        isAppliedByAdmin: input.isAppliedByAdmin ?? false,
      },
    });

    // Reserve balance
    if (!skipBalanceCheck) {
      await leaveBalanceService.applyPending({
        employeeId: input.employeeId,
        leaveTypeId: lt.id,
        year,
        days: totalDays,
        actorId: input.appliedBy,
        context: `LeaveApplication:${app.id}`,
      });
    }

    // Create approval workflow steps
    await leaveApprovalWorkflowService.createStepsForApplication(app.id);

    // Notify applicant + first approver
    leaveNotificationService.notifyApplied(app.id).catch(() => {});

    // Notify first approver (tier 1 if exists, else tier 3)
    const firstStep = await prisma.leaveApprovalStep.findFirst({
      where: { applicationId: app.id, isSuperseded: false },
      orderBy: { stepNumber: 'asc' },
    });
    if (firstStep) {
      leaveNotificationService.notifyApproverPendingStep(firstStep.id).catch(() => {});
    }

    return app;
  },

  async cancel(applicationId: string, actorId: string, actorEmployeeId: number) {
    const app = await prisma.leaveApplication.findUnique({ where: { id: applicationId } });
    if (!app) throw new Error('Application not found');
    if (app.status !== 'PENDING') throw new Error('Only pending applications can be cancelled');
    if (!app.isAppliedByAdmin && app.employeeId !== actorEmployeeId) {
      throw new Error('Not authorized to cancel this application');
    }

    const lt = await prisma.leaveType.findUnique({ where: { id: app.leaveTypeId }, select: { code: true } });
    const skipBalanceCheck = ['LWP', 'DL', 'AL', 'OT'].includes(lt?.code ?? '');

    await prisma.$transaction(async (tx) => {
      await tx.leaveApplication.update({
        where: { id: applicationId },
        data: { status: 'CANCELLED' },
      });
      await tx.leaveApprovalStep.updateMany({
        where: { applicationId, action: null, isSuperseded: false },
        data: { isSuperseded: true },
      });
    });

    if (!skipBalanceCheck) {
      const year = app.fromDate.getUTCFullYear();
      await leaveBalanceService.revertPending({
        employeeId: app.employeeId,
        leaveTypeId: app.leaveTypeId,
        year,
        days: app.totalDays,
        actorId,
        revertAction: 'CANCEL_REVERT',
        context: `LeaveApplication:${applicationId}`,
      });
    }

    return true;
  },

  async list(params: {
    employeeId?: number;
    status?: string;
    year?: number;
    page?: number;
    limit?: number;
  }) {
    const { page = 0, limit = 20, employeeId, status, year } = params;
    const where: any = {};
    if (employeeId) where.employeeId = employeeId;
    if (status) where.status = status;
    if (year) {
      where.fromDate = { gte: new Date(Date.UTC(year, 0, 1)), lt: new Date(Date.UTC(year + 1, 0, 1)) };
    }

    const [items, total] = await prisma.$transaction([
      prisma.leaveApplication.findMany({
        where,
        skip: page * limit,
        take: limit,
        orderBy: { appliedAt: 'desc' },
        include: {
          leaveType: { select: { name: true, code: true } },
          approvalSteps: { where: { isSuperseded: false }, orderBy: { stepNumber: 'asc' } },
          assignment: { select: { subOrganization: true, designation: true, department: true, effectiveFrom: true, effectiveTo: true } },
          employee: {
            include: {
              generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } },
            },
          },
        },
      }),
      prisma.leaveApplication.count({ where }),
    ]);

    return { items, total };
  },

  async getById(applicationId: string) {
    return prisma.leaveApplication.findUnique({
      where: { id: applicationId },
      include: {
        leaveType: true,
        approvalSteps: { orderBy: { stepNumber: 'asc' } },
        assignment: { select: { subOrganization: true, designation: true, department: true, effectiveFrom: true, effectiveTo: true } },
        employee: {
          include: {
            generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } },
          },
        },
      },
    });
  },

  async getBalances(employeeId: number, year?: number) {
    const y = year ?? new Date().getUTCFullYear();
    await leaveBalanceService.syncScheduledCredits(employeeId, y);
    return prisma.leaveBalance.findMany({
      where: { employeeId, year: y },
      include: {
        leaveType: {
          select: {
            name: true,
            code: true,
            allowHalfDay: true,
            employeeCanApply: true,
            isActive: true,
          },
        },
      },
      orderBy: { leaveType: { code: 'asc' } },
    });
  },

  /** Pending applications for approver (by user id — works for position accounts too).
   *  Privileged admins (ADMIN/HR) see all PENDING apps so they can act from Leave Approvals. */
  async getPendingForApprover(approverUserId: string, opts?: { privilegedAdmin?: boolean }) {
    if (opts?.privilegedAdmin) {
      const rows = await prisma.leaveApplication.findMany({
        where: { status: 'PENDING' },
        include: {
          leaveType: { select: { name: true, code: true } },
          approvalSteps: { where: { isSuperseded: false }, orderBy: { stepNumber: 'asc' } },
          assignment: { select: { subOrganization: true, designation: true, department: true, effectiveFrom: true, effectiveTo: true } },
          employee: {
            include: {
              generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } },
            },
          },
        },
        orderBy: { appliedAt: 'asc' },
      });
      return enrichApplicationsWithApproverNames(rows);
    }

    const apps = await prisma.leaveApplication.findMany({
      where: {
        status: 'PENDING',
        approvalSteps: {
          some: {
            approverUserId,
            action: null,
            isSuperseded: false,
          },
        },
      },
      include: {
        leaveType: { select: { name: true, code: true } },
        approvalSteps: { where: { isSuperseded: false }, orderBy: { stepNumber: 'asc' } },
        assignment: { select: { subOrganization: true, designation: true, department: true, effectiveFrom: true, effectiveTo: true } },
        employee: {
          include: {
            generalInfo: { select: { fullName: true, employeeCode: true, designation: true, department: true } },
          },
        },
      },
      orderBy: { appliedAt: 'asc' },
    });

    // Only return apps where this user is on the *current* (lowest pending) tier
    const filtered = apps.filter((app) => {
      const pending = app.approvalSteps.filter((s) => s.action == null && !s.isSuperseded);
      if (pending.length === 0) return false;
      const minTier = Math.min(...pending.map((s) => s.stepNumber));
      return pending.some((s) => s.stepNumber === minTier && s.approverUserId === approverUserId);
    });
    return enrichApplicationsWithApproverNames(filtered);
  },
};
