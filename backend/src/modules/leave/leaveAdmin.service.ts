import { prisma } from '../../config/prisma';
import { leaveBalanceService } from './leaveBalance.service';
import { leaveApprovalWorkflowService } from './leaveApprovalWorkflow.service';
import { leaveNotificationService } from './leaveNotification.service';

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
    const common = {
      name:               data.name,
      applicableTo:       data.applicableTo,
      defaultDaysPerYear: data.defaultDaysPerYear ?? null,
      isCarryForward:     data.isCarryForward ?? false,
      allowHalfDay:       data.allowHalfDay ?? true,
      skipPublicHolidays: data.skipPublicHolidays ?? true,
      skipWeekends:       data.skipWeekends ?? true,
      requiresDocument:   data.requiresDocument ?? false,
      requiresReason:     data.requiresReason ?? true,
      creditSchedule:     (data.creditSchedule as any) ?? null,
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
    return prisma.leaveSetting.upsert({
      where: { key },
      update: { value, updatedBy: actorId },
      create: { key, value, description: '', updatedBy: actorId },
    });
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
    return prisma.leaveBalance.findMany({
      where: { employeeId, year: y },
      include: { leaveType: { select: { code: true, name: true } } },
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
  async approveStep(applicationId: string, approverUserId: string, actorId: string, remarks?: string) {
    const result = await leaveApprovalWorkflowService.approveOrReject({
      applicationId,
      approverUserId,
      action: 'APPROVE',
      remarks,
      actorId,
    });

    if (result.status === 'APPROVED') {
      leaveNotificationService.notifyApplicantDecision(applicationId, true).catch(() => {});
    } else {
      // Move to next tier — notify next approver(s)
      const nextSteps = await prisma.leaveApprovalStep.findMany({
        where: { applicationId, action: null, isSuperseded: false },
        orderBy: { stepNumber: 'asc' },
      });
      for (const s of nextSteps.filter((s) => s.stepNumber === (nextSteps[0]?.stepNumber ?? 999))) {
        leaveNotificationService.notifyApproverPendingStep(s.id).catch(() => {});
      }
    }

    return result;
  },

  async rejectStep(applicationId: string, approverUserId: string, actorId: string, remarks?: string) {
    const result = await leaveApprovalWorkflowService.approveOrReject({
      applicationId,
      approverUserId,
      action: 'REJECT',
      remarks,
      actorId,
    });
    leaveNotificationService.notifyApplicantDecision(applicationId, false).catch(() => {});
    return result;
  },

  // ─── Year-end carry-forward processing ───────────────────────────────────────
  async runYearEnd(currentYear: number, actorId: string) {
    const leaveTypes = await prisma.leaveType.findMany({
      where: { isActive: true, isCarryForward: true },
      select: { id: true, code: true, defaultDaysPerYear: true },
    });
    const employees = await prisma.employeeGeneralInfo.findMany({
      select: { employeeId: true },
    });

    let processed = 0;
    const nextYear = currentYear + 1;

    for (const lt of leaveTypes) {
      for (const e of employees) {
        const currentBalance = await prisma.leaveBalance.findUnique({
          where: { employeeId_leaveTypeId_year: { employeeId: e.employeeId, leaveTypeId: lt.id, year: currentYear } },
        });
        if (!currentBalance) continue;

        const carryForwardDays = Math.max(0, currentBalance.available);

        if (carryForwardDays > 0) {
          await leaveBalanceService.credit({
            employeeId: e.employeeId,
            leaveTypeId: lt.id,
            year: nextYear,
            days: carryForwardDays,
            actorId,
            action: 'CARRY_FORWARD',
            context: `YearEnd:${currentYear}->${nextYear}`,
          });
        }
        processed++;
      }
    }

    return { processed, nextYear };
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
