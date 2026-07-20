import { ApprovalAction, ApproverRole, ReimbursementStatus, SalaryRecordStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { salaryService } from '../salary/salary.service';

/** True when user role or employee designation is Admin (final authority in this project). */
async function isAdminAuthority(userId: string): Promise<boolean> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      role: { select: { name: true } },
      employee: { select: { generalInfo: { select: { designation: true } } } },
    },
  });
  if (!user) return false;
  const role = String(user.role?.name ?? '').toUpperCase();
  if (role === 'ADMIN') return true;
  const designation = String(user.employee?.generalInfo?.designation ?? '')
    .trim()
    .toUpperCase();
  return designation === 'ADMIN';
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
    if (selfUserId && userId === selfUserId) return null;
    return userId;
  };

  // Only 1st → 2nd → 3rd. Last non-null is final.
  // If a layer is Admin (role/designation), that layer is final — do not add later layers.
  const raw = [
    normalize(gi.firstApproverUserId ?? legacyUserId(gi.firstReportingId)),
    normalize(gi.secondApproverUserId ?? legacyUserId(gi.secondReportingId)),
    normalize(gi.thirdApproverUserId ?? legacyUserId(gi.thirdReportingId)),
  ];

  const firstApproverUserId = raw[0];
  let secondApproverUserId = raw[1];
  let thirdApproverUserId = raw[2];

  if (firstApproverUserId && (await isAdminAuthority(firstApproverUserId))) {
    secondApproverUserId = null;
    thirdApproverUserId = null;
  } else if (secondApproverUserId && (await isAdminAuthority(secondApproverUserId))) {
    thirdApproverUserId = null;
  }

  return { firstApproverUserId, secondApproverUserId, thirdApproverUserId };
}

function isPendingStep(s: { action: unknown; isSuperseded: boolean }) {
  return !s.isSuperseded && (s.action === null || typeof s.action === 'undefined');
}

async function nextClaimNo(): Promise<string> {
  const year = new Date().getFullYear();
  const prefix = `REIM-${year}-`;
  const latest = await prisma.reimbursementClaim.findFirst({
    where: { claimNo: { startsWith: prefix } },
    orderBy: { claimNo: 'desc' },
    select: { claimNo: true },
  });
  const seq = latest ? Number(latest.claimNo.slice(prefix.length)) + 1 : 1;
  return `${prefix}${String(seq).padStart(4, '0')}`;
}

const claimInclude = {
  employee: {
    include: {
      generalInfo: {
        select: {
          fullName: true,
          employeeCode: true,
          designation: true,
          department: true,
        },
      },
    },
  },
  approvalSteps: { orderBy: { stepNumber: 'asc' as const } },
};

/** Post approved amount onto current calendar month DRAFT salary (other_allowance / reimbursement). */
async function postAmountToCurrentMonthSalary(params: {
  employeeId: number;
  amount: number;
  actorId: string;
}) {
  const now = new Date();
  const salaryMonth = now.getMonth() + 1;
  const salaryYear = now.getFullYear();

  let record = await prisma.employeeSalaryRecord.findUnique({
    where: {
      employeeId_salaryMonth_salaryYear: {
        employeeId: params.employeeId,
        salaryMonth,
        salaryYear,
      },
    },
    include: { columnValues: true },
  });

  if (!record) {
    const created = await salaryService.createSalaryRecord(
      params.employeeId,
      salaryMonth,
      salaryYear,
      params.actorId,
    );
    record = await prisma.employeeSalaryRecord.findUnique({
      where: { id: created!.id },
      include: { columnValues: true },
    });
  }

  if (!record) throw new Error('Failed to create/load salary record');
  if (record.status === SalaryRecordStatus.FINALIZED) {
    throw new Error(
      'Salary for this month is already finalized. Reopen the draft salary record before posting reimbursement.',
    );
  }

  const overrides: Record<string, number> = {};
  for (const cv of record.columnValues) {
    if (cv.overrideValue != null) {
      overrides[cv.columnIdentifier] = Number(cv.overrideValue);
    }
  }

  const hasReimbursementCol = record.columnValues.some(
    (c) => c.columnIdentifier === 'reimbursement' && String(c.category) === 'EARNING',
  );
  const colId = hasReimbursementCol ? 'reimbursement' : 'other_allowance';
  const prev = overrides[colId] ?? 0;
  overrides[colId] = Number(prev) + Number(params.amount);

  await salaryService.updateSalaryRecord(record.id, overrides);

  return { salaryRecordId: record.id, salaryMonth, salaryYear };
}

export const reimbursementsService = {
  async apply(params: {
    employeeId: number;
    title: string;
    description: string;
    amount: number;
    openingKm?: number | null;
    closingKm?: number | null;
    proofUrl?: string | null;
    appliedBy: string;
  }) {
    const title = params.title.trim();
    const description = params.description.trim();
    if (!title) throw new Error('Title is required');
    if (!description) throw new Error('Description is required');
    if (!Number.isFinite(params.amount) || params.amount <= 0) {
      throw new Error('Amount must be greater than 0');
    }
    if (
      params.openingKm != null &&
      params.closingKm != null &&
      params.closingKm < params.openingKm
    ) {
      throw new Error('Closing km cannot be less than opening km');
    }

    const { firstApproverUserId, secondApproverUserId, thirdApproverUserId } =
      await resolveApprovers(params.employeeId);

    type StepRow = { stepNumber: number; approverRole: ApproverRole; approverUserId: string };
    const steps: StepRow[] = [];
    let stepNumber = 1;
    if (firstApproverUserId) {
      steps.push({
        stepNumber,
        approverRole: ApproverRole.FIRST_REPORTING,
        approverUserId: firstApproverUserId,
      });
      stepNumber += 1;
    }
    if (secondApproverUserId) {
      steps.push({
        stepNumber,
        approverRole: ApproverRole.SECOND_REPORTING,
        approverUserId: secondApproverUserId,
      });
      stepNumber += 1;
    }
    if (thirdApproverUserId) {
      steps.push({
        stepNumber,
        approverRole: ApproverRole.THIRD_REPORTING,
        approverUserId: thirdApproverUserId,
      });
    }

    if (steps.length === 0) {
      throw new Error(
        'No reporting manager configured. Set at least one reporting layer before applying for reimbursement.',
      );
    }

    const claimNo = await nextClaimNo();

    return prisma.$transaction(async (tx) => {
      const claim = await tx.reimbursementClaim.create({
        data: {
          claimNo,
          employeeId: params.employeeId,
          title,
          description,
          amount: params.amount,
          openingKm: params.openingKm ?? null,
          closingKm: params.closingKm ?? null,
          proofUrl: params.proofUrl ?? null,
          status: ReimbursementStatus.PENDING,
          appliedBy: params.appliedBy,
          approvalSteps: {
            create: steps.map((s) => ({
              stepNumber: s.stepNumber,
              approverRole: s.approverRole,
              approverUserId: s.approverUserId,
            })),
          },
        },
        include: claimInclude,
      });
      return claim;
    });
  },

  async listMine(employeeId: number) {
    return prisma.reimbursementClaim.findMany({
      where: { employeeId },
      include: claimInclude,
      orderBy: { appliedAt: 'desc' },
    });
  },

  async listAll(opts?: { status?: ReimbursementStatus }) {
    return prisma.reimbursementClaim.findMany({
      where: opts?.status ? { status: opts.status } : undefined,
      include: claimInclude,
      orderBy: { appliedAt: 'desc' },
    });
  },

  async getById(id: string) {
    return prisma.reimbursementClaim.findUnique({
      where: { id },
      include: claimInclude,
    });
  },

  async getPendingForApprover(
    approverUserId: string,
    opts?: { privilegedAdmin?: boolean },
  ) {
    if (opts?.privilegedAdmin) {
      return prisma.reimbursementClaim.findMany({
        where: { status: ReimbursementStatus.PENDING },
        include: claimInclude,
        orderBy: { appliedAt: 'asc' },
      });
    }

    const pendingSteps = await prisma.reimbursementApprovalStep.findMany({
      where: {
        approverUserId,
        action: null,
        isSuperseded: false,
        claim: { status: ReimbursementStatus.PENDING },
      },
      select: { claimId: true, stepNumber: true },
    });

    if (!pendingSteps.length) return [];

    const claimIds = [...new Set(pendingSteps.map((s) => s.claimId))];
    const claims = await prisma.reimbursementClaim.findMany({
      where: { id: { in: claimIds }, status: ReimbursementStatus.PENDING },
      include: claimInclude,
      orderBy: { appliedAt: 'asc' },
    });

    // Only return claims where this user is on the *current* (min pending) tier
    return claims.filter((c) => {
      const pending = c.approvalSteps.filter((s) => isPendingStep(s));
      if (!pending.length) return false;
      const minTier = Math.min(...pending.map((s) => s.stepNumber));
      return pending.some(
        (s) => s.stepNumber === minTier && s.approverUserId === approverUserId,
      );
    });
  },

  async approveOrReject(params: {
    claimId: string;
    approverUserId: string;
    action: 'APPROVE' | 'REJECT';
    remarks?: string;
    allowAdminOverride?: boolean;
  }) {
    const { claimId, approverUserId, action, remarks, allowAdminOverride } = params;
    const actorIsAdminFinal = await isAdminAuthority(approverUserId);

    const result = await prisma.$transaction(async (tx) => {
      const claim = await tx.reimbursementClaim.findUnique({
        where: { id: claimId },
        include: { approvalSteps: true },
      });
      if (!claim) throw new Error('Claim not found');
      if (claim.status !== ReimbursementStatus.PENDING) {
        throw new Error('Claim is not pending');
      }
      if (claim.salaryRecordId) {
        throw new Error('Claim already posted to salary');
      }

      const steps = claim.approvalSteps;
      const finalTier = steps.length ? Math.max(...steps.map((s) => s.stepNumber)) : 0;
      const pendingSteps = steps.filter((s) => isPendingStep(s));
      if (!pendingSteps.length) throw new Error('No pending approval steps');

      const minTier = Math.min(...pendingSteps.map((s) => s.stepNumber));
      const tierPending = pendingSteps.filter((s) => s.stepNumber === minTier);

      const myStep =
        tierPending.find((s) => s.approverUserId === approverUserId) ??
        (allowAdminOverride ? tierPending[0] : undefined);
      if (!myStep) throw new Error('Not authorized for current approval tier');

      // Last reporting layer is final. Admin role/designation is also final authority.
      const treatAsFinal = minTier >= finalTier || actorIsAdminFinal;

      const prismaAction =
        action === 'REJECT'
          ? ApprovalAction.REJECTED
          : treatAsFinal
            ? ApprovalAction.APPROVED
            : ApprovalAction.RECOMMENDED;

      await tx.reimbursementApprovalStep.update({
        where: { id: myStep.id },
        data: { action: prismaAction, remarks: remarks ?? null, actionAt: new Date() },
      });

      if (action === 'REJECT') {
        await tx.reimbursementApprovalStep.updateMany({
          where: { claimId, id: { not: myStep.id }, action: null, isSuperseded: false },
          data: { isSuperseded: true },
        });
        await tx.reimbursementClaim.update({
          where: { id: claimId },
          data: { status: ReimbursementStatus.REJECTED },
        });
        return { status: 'REJECTED' as const, finalized: false };
      }

      if (!treatAsFinal) {
        return { status: 'PENDING' as const, finalized: false };
      }

      await tx.reimbursementApprovalStep.updateMany({
        where: {
          claimId,
          id: { not: myStep.id },
          action: null,
          isSuperseded: false,
        },
        data: { isSuperseded: true },
      });

      await tx.reimbursementClaim.update({
        where: { id: claimId },
        data: { status: ReimbursementStatus.APPROVED },
      });

      return {
        status: 'APPROVED' as const,
        finalized: true,
        employeeId: claim.employeeId,
        amount: Number(claim.amount),
      };
    });

    if (result.finalized && result.status === 'APPROVED') {
      try {
        const posted = await postAmountToCurrentMonthSalary({
          employeeId: result.employeeId!,
          amount: result.amount!,
          actorId: approverUserId,
        });
        await prisma.reimbursementClaim.update({
          where: { id: claimId },
          data: {
            salaryMonth: posted.salaryMonth,
            salaryYear: posted.salaryYear,
            salaryRecordId: posted.salaryRecordId,
          },
        });
      } catch (e: any) {
        // Leave claim APPROVED but surface salary error to caller
        throw new Error(
          `Claim approved, but salary post failed: ${e?.message ?? 'unknown error'}`,
        );
      }
    }

    return this.getById(claimId);
  },

  async cancel(claimId: string, employeeId: number) {
    const claim = await prisma.reimbursementClaim.findUnique({ where: { id: claimId } });
    if (!claim) throw new Error('Claim not found');
    if (claim.employeeId !== employeeId) throw new Error('Not your claim');
    if (claim.status !== ReimbursementStatus.PENDING) {
      throw new Error('Only pending claims can be cancelled');
    }
    await prisma.reimbursementApprovalStep.updateMany({
      where: { claimId, action: null, isSuperseded: false },
      data: { isSuperseded: true },
    });
    return prisma.reimbursementClaim.update({
      where: { id: claimId },
      data: { status: ReimbursementStatus.CANCELLED },
      include: claimInclude,
    });
  },
};
