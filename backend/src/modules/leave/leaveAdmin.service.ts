import { prisma } from '../../config/prisma';
import { leaveBalanceService } from './leaveBalance.service';
import { leaveApprovalWorkflowService } from './leaveApprovalWorkflow.service';
import { leaveNotificationService } from './leaveNotification.service';
import { parseCreditSchedule } from './leaveCreditSchedule.util';
import { ensureLeaveRepeatableJobs, parseMonthDay } from '../../jobs/leave/leaveSchedulers';

async function getSettingMonthDay(key: string, fallback: { month: number; day: number }) {
  const row = await prisma.leaveSetting.findUnique({ where: { key } });
  return (row ? parseMonthDay(row.value) : null) ?? fallback;
}

async function buildDefaultCreditSchedule(
  days: number,
  isCarryForward: boolean,
): Promise<{ credits: Array<{ month: number; day: number; days: number }> }> {
  const ny = await getSettingMonthDay('new_year_credit_date', { month: 1, day: 1 });
  const my = await getSettingMonthDay('mid_year_credit_date', { month: 7, day: 1 });
  if (isCarryForward) {
    const half = days / 2;
    return {
      credits: [
        { month: ny.month, day: ny.day, days: half },
        { month: my.month, day: my.day, days: half },
      ],
    };
  }
  return {
    credits: [{ month: ny.month, day: ny.day, days }],
  };
}

/** Keep leave-type credit month/day aligned with global credit-date settings. */
async function realignCreditSchedulesToSettings() {
  const ny = await getSettingMonthDay('new_year_credit_date', { month: 1, day: 1 });
  const my = await getSettingMonthDay('mid_year_credit_date', { month: 7, day: 1 });

  const types = await prisma.leaveType.findMany({
    where: { isActive: true },
    select: { id: true, creditSchedule: true },
  });

  for (const lt of types) {
    const credits = parseCreditSchedule(lt.creditSchedule);
    if (credits.length === 0) continue;
    const sorted = [...credits].sort((a, b) => a.month - b.month || a.day - b.day);
    if (sorted.length === 1) {
      sorted[0] = { ...sorted[0], month: ny.month, day: ny.day };
    } else {
      sorted[0] = { ...sorted[0], month: ny.month, day: ny.day };
      sorted[1] = { ...sorted[1], month: my.month, day: my.day };
    }
    await prisma.leaveType.update({
      where: { id: lt.id },
      data: { creditSchedule: { credits: sorted } as any },
    });
  }
}

export const leaveAdminService = {
  // ─── Leave Types ────────────────────────────────────────────────────────────
  async listTypes() {
    return prisma.leaveType.findMany({ orderBy: { code: 'asc' } });
  },

  async upsertType(data: {
    code: string;
    name: string;
    applicableTo: 'TEACHING' | 'NON_TEACHING' | 'BOTH';
    defaultDaysPerYear?: number | null;
    isCarryForward?: boolean;
    allowHalfDay?: boolean;
    skipPublicHolidays?: boolean;
    skipWeekends?: boolean;
    requiresDocument?: boolean;
    requiresReason?: boolean;
    creditSchedule?: unknown;
    isActive?: boolean;
    employeeCanApply?: boolean;
  }) {
    const isCarryForward = data.isCarryForward ?? false;
    let creditSchedule = data.creditSchedule;
    if (
      (creditSchedule == null || creditSchedule === undefined) &&
      data.defaultDaysPerYear != null &&
      Number(data.defaultDaysPerYear) > 0
    ) {
      creditSchedule = await buildDefaultCreditSchedule(
        Number(data.defaultDaysPerYear),
        isCarryForward,
      );
    }

    const common = {
      name:               data.name,
      applicableTo:       data.applicableTo,
      defaultDaysPerYear: data.defaultDaysPerYear ?? null,
      isCarryForward,
      allowHalfDay:       data.allowHalfDay ?? true,
      skipPublicHolidays: data.skipPublicHolidays ?? true,
      skipWeekends:       data.skipWeekends ?? true,
      requiresDocument:   data.requiresDocument ?? false,
      requiresReason:     data.requiresReason ?? true,
      creditSchedule:     (creditSchedule as any) ?? null,
      isActive:           data.isActive ?? true,
      employeeCanApply:   data.employeeCanApply ?? true,
    };
    return prisma.leaveType.upsert({
      where:  { code: data.code },
      update: common,
      create: { code: data.code, ...common },
    });
  },

  async deleteType(code: string) {
    return prisma.leaveType.update({
      where: { code },
      data:  { isActive: false },
    });
  },

  // ─── Settings ────────────────────────────────────────────────────────────────
  async listSettings() {
    return prisma.leaveSetting.findMany({ orderBy: { key: 'asc' } });
  },

  async updateSetting(key: string, value: string, actorId: string) {
    const scheduleKeys = new Set([
      'new_year_credit_date',
      'mid_year_credit_date',
      'yearend_processing_date',
    ]);

    if (scheduleKeys.has(key) && !parseMonthDay(value)) {
      throw new Error(`${key} must be MM-DD (e.g. 01-01)`);
    }
    if (key === 'approver_timeout_action') {
      const v = value.toLowerCase();
      if (v !== 'escalate' && v !== 'reject') {
        throw new Error('approver_timeout_action must be escalate or reject');
      }
      value = v;
    }
    if (key === 'lwp_auto_apply') {
      const v = value.toLowerCase();
      if (v !== 'true' && v !== 'false') {
        throw new Error('lwp_auto_apply must be true or false');
      }
      value = v;
    }
    if (key.endsWith('_hours')) {
      if (value.trim() === '' || value.toLowerCase() === 'null') {
        value = '';
      } else {
        const n = Number(value);
        if (!Number.isFinite(n) || n < 0) {
          throw new Error(`${key} must be a non-negative number (or empty for infinite)`);
        }
        value = String(n);
      }
    }

    const updated = await prisma.leaveSetting.upsert({
      where: { key },
      update: { value, updatedBy: actorId },
      create: { key, value, description: '', updatedBy: actorId },
    });

    if (key === 'new_year_credit_date' || key === 'mid_year_credit_date') {
      await realignCreditSchedulesToSettings();
    }
    if (scheduleKeys.has(key)) {
      try {
        await ensureLeaveRepeatableJobs();
      } catch (err) {
        console.warn('[leave.settings] failed to re-register schedulers:', err);
      }
    }

    return updated;
  },

  // ─── Public Holidays ─────────────────────────────────────────────────────────
  async listHolidays(year?: number) {
    return prisma.publicHoliday.findMany({
      where: year ? { year } : undefined,
      orderBy: { date: 'asc' },
    });
  },

  async addHoliday(data: { name: string; date: Date | string; year: number; isOptional?: boolean }) {
    return prisma.publicHoliday.create({
      data: {
        name: data.name,
        date: new Date(data.date),
        year: data.year,
        isOptional: data.isOptional ?? false,
      },
    });
  },

  async deleteHoliday(id: string) {
    return prisma.publicHoliday.delete({ where: { id } });
  },

  // ─── Balances management ─────────────────────────────────────────────────────
  async getEmployeeBalances(employeeId: number, year?: number) {
    const y = year ?? new Date().getUTCFullYear();
    await leaveBalanceService.syncScheduledCredits(employeeId, y);
    return prisma.leaveBalance.findMany({
      where: { employeeId, year: y },
      include: {
        leaveType: {
          select: { code: true, name: true, employeeCanApply: true, isActive: true },
        },
      },
    });
  },

  async adjustBalance(params: {
    employeeId: number;
    leaveTypeId: string;
    year: number;
    totalCredited?: number;
    carryForward?: number;
    used?: number;
    actorId: string;
    context: string;
  }) {
    return leaveBalanceService.manualAdjust(params);
  },

  // ─── Applications ─────────────────────────────────────────────────────────────
  async approveStep(
    applicationId: string,
    approverUserId: string,
    actorId: string,
    remarks?: string,
    opts?: { allowAdminOverride?: boolean },
  ) {
    const result = await leaveApprovalWorkflowService.approveOrReject({
      applicationId,
      approverUserId,
      action: 'APPROVE',
      remarks,
      actorId,
      allowAdminOverride: opts?.allowAdminOverride,
    });

    if (result.status === 'APPROVED') {
      leaveNotificationService.notifyApplicantDecision(applicationId, true).catch(() => {});
    } else if (result.status === 'PENDING') {
      // Next reporting layer is now current — start its timeout window + notify
      await leaveApprovalWorkflowService.startWindowForCurrentTier(applicationId);
      const nextSteps = await prisma.leaveApprovalStep.findMany({
        where: { applicationId, action: null, isSuperseded: false },
        orderBy: { stepNumber: 'asc' },
      });
      const nextTier = nextSteps[0]?.stepNumber;
      for (const s of nextSteps.filter((s) => s.stepNumber === nextTier)) {
        leaveNotificationService.notifyApproverPendingStep(s.id).catch(() => {});
      }
    }

    return result;
  },

  async rejectStep(
    applicationId: string,
    approverUserId: string,
    actorId: string,
    remarks?: string,
    opts?: { allowAdminOverride?: boolean },
  ) {
    const result = await leaveApprovalWorkflowService.approveOrReject({
      applicationId,
      approverUserId,
      action: 'REJECT',
      remarks,
      actorId,
      allowAdminOverride: opts?.allowAdminOverride,
    });
    leaveNotificationService.notifyApplicantDecision(applicationId, false).catch(() => {});
    return result;
  },

  // ─── Year-end carry-forward processing ───────────────────────────────────────
  async runYearEnd(currentYear: number, actorId: string) {
    const leaveTypes = await prisma.leaveType.findMany({
      where: { isActive: true, isCarryForward: true },
      select: { id: true, code: true },
    });
    const employees = await prisma.employeeGeneralInfo.findMany({
      select: { employeeId: true },
    });

    let processed = 0;
    let carried = 0;
    const nextYear = currentYear + 1;

    for (const lt of leaveTypes) {
      for (const e of employees) {
        const currentBalance = await prisma.leaveBalance.findUnique({
          where: {
            employeeId_leaveTypeId_year: {
              employeeId: e.employeeId,
              leaveTypeId: lt.id,
              year: currentYear,
            },
          },
        });
        if (!currentBalance) continue;

        // Prefer stored available; recompute if stale.
        const available = Math.max(
          0,
          currentBalance.available ??
            currentBalance.totalCredited +
              currentBalance.carryForward -
              currentBalance.used -
              currentBalance.pending,
        );

        if (available > 0) {
          // Idempotent: skip if already carried for this leave type + transition
          const already = await prisma.leaveAuditLog.findFirst({
            where: {
              employeeId: e.employeeId,
              action: 'CARRY_FORWARD',
              context: `YearEnd:${currentYear}->${nextYear}:${lt.id}`,
            },
          });
          if (!already) {
            await leaveBalanceService.applyYearEndCarryForward({
              employeeId: e.employeeId,
              leaveTypeId: lt.id,
              fromYear: currentYear,
              toYear: nextYear,
              days: available,
              actorId,
            });
            carried += 1;
          }
        }
        processed += 1;
      }
    }

    return { processed, carried, nextYear, fromYear: currentYear };
  },

  // ─── Workflow config ──────────────────────────────────────────────────────────
  async setDeptApprover(department: string, hodEmployeeId: number, actorId: string) {
    return prisma.departmentApprover.upsert({
      where: { department },
      update: { hodEmployeeId, isActive: true, updatedBy: actorId },
      create: { department, hodEmployeeId, isActive: true, updatedBy: actorId },
    });
  },

  async setInstituteApprover(institute: string, hoiEmployeeId: number, actorId: string) {
    return prisma.instituteApprover.upsert({
      where: { institute },
      update: { hoiEmployeeId, isActive: true, updatedBy: actorId },
      create: { institute, hoiEmployeeId, isActive: true, updatedBy: actorId },
    });
  },

  async setGlobalApprover(vcEmployeeId: number | null, registrarEmployeeId: number | null, actorId: string) {
    const existing = await prisma.globalApprover.findFirst({ where: { isActive: true } });
    if (existing) {
      return prisma.globalApprover.update({
        where: { id: existing.id },
        data: { vcEmployeeId, registrarEmployeeId, updatedBy: actorId },
      });
    }
    return prisma.globalApprover.create({
      data: { vcEmployeeId, registrarEmployeeId, isActive: true, updatedBy: actorId },
    });
  },

  async getWorkflowConfig() {
    const [depts, institutes, global] = await Promise.all([
      prisma.departmentApprover.findMany({
        where: { isActive: true },
        include: { hod: { include: { generalInfo: { select: { fullName: true } } } } },
      }),
      prisma.instituteApprover.findMany({
        where: { isActive: true },
        include: { hoi: { include: { generalInfo: { select: { fullName: true } } } } },
      }),
      prisma.globalApprover.findFirst({
        where: { isActive: true },
        include: {
          vc: { include: { generalInfo: { select: { fullName: true } } } },
          registrar: { include: { generalInfo: { select: { fullName: true } } } },
        },
      }),
    ]);
    return { depts, institutes, global };
  },
};
