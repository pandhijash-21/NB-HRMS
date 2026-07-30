import {
  Prisma,
  SalaryColumnCategory,
  SalaryRecordStatus,
} from '@prisma/client';
import { prisma } from '../../config/prisma';
import { assignmentService } from '../personal-education/assignment.service';
import { buildFormulaPreview, computeFullSalary, mergeEmployeeRules, applyAttendanceProration } from './salaryEngine.service';
import { getPayCommissionByCode } from './payCommission.service';
import { columnKey, type ColumnRuleInput } from './salary.types';
import { columnRuleSchema, validateConditionalConditions } from './salary.validation';

async function loadTemplateContext(templateId: string) {
  const template = await prisma.salaryStructureTemplate.findUnique({
    where: { id: templateId },
    include: {
      designation: true,
      payCommission: true,
      columnRules: { include: { conditions: { orderBy: { sortOrder: 'asc' } } } },
    },
  });
  if (!template) throw new Error('Salary structure template not found');

  const columnDefinitions = await prisma.salaryColumnDefinition.findMany({
    where: { payCommissionId: template.payCommissionId },
    orderBy: { evaluationOrder: 'asc' },
  });

  return { template, columnDefinitions };
}

export const salaryService = {
  async listTemplates(filters?: { designationId?: string; payCommissionCode?: string }) {
    const where: Prisma.SalaryStructureTemplateWhereInput = { isActive: true };
    if (filters?.designationId) where.designationId = filters.designationId;
    if (filters?.payCommissionCode) {
      const pc = await getPayCommissionByCode(filters.payCommissionCode);
      where.payCommissionId = pc.id;
    }

    return prisma.salaryStructureTemplate.findMany({
      where,
      include: {
        designation: { select: { id: true, name: true, isAlias: true } },
        payCommission: true,
        _count: { select: { columnRules: true } },
      },
    });
  },

  async getTemplateByDesignationAndCommission(designationId: string, payCommissionCode: string) {
    const designation = await prisma.designation.findUnique({ where: { id: designationId } });
    if (!designation) throw new Error('Designation not found');
    if (designation.isAlias) throw new Error('Alias designations cannot have salary templates');

    const payCommissionId = (await getPayCommissionByCode(payCommissionCode)).id;

    const template = await prisma.salaryStructureTemplate.findUnique({
      where: { designationId_payCommissionId: { designationId, payCommissionId } },
      include: {
        columnRules: { include: { conditions: { orderBy: { sortOrder: 'asc' } } } },
        payCommission: true,
        designation: true,
      },
    });

    const columnDefinitions = await prisma.salaryColumnDefinition.findMany({
      where: { payCommissionId },
      orderBy: { evaluationOrder: 'asc' },
    });

    const payCommission = await prisma.payCommission.findUnique({ where: { id: payCommissionId } });

    return {
      template,
      columnDefinitions,
      configured: !!template,
      designation,
      payCommission,
    };
  },

  async createTemplate(designationId: string, payCommissionCode: string, createdBy?: string) {
    const designation = await prisma.designation.findUnique({ where: { id: designationId } });
    if (!designation) throw new Error('Designation not found');
    if (designation.isAlias) throw new Error('Alias designations cannot have salary templates');

    const payCommissionId = (await getPayCommissionByCode(payCommissionCode)).id;

    const existing = await prisma.salaryStructureTemplate.findUnique({
      where: { designationId_payCommissionId: { designationId, payCommissionId } },
    });
    if (existing) return existing;

    return prisma.salaryStructureTemplate.create({
      data: { designationId, payCommissionId, createdBy },
      include: { designation: true, payCommission: true },
    });
  },

  async updateTemplateColumnVisibility(
    templateId: string,
    columnVisibility: Record<string, boolean>,
  ) {
    const template = await prisma.salaryStructureTemplate.findUnique({ where: { id: templateId } });
    if (!template) throw new Error('Salary structure template not found');

    return prisma.salaryStructureTemplate.update({
      where: { id: templateId },
      data: { columnVisibility },
    });
  },

  async deleteTemplate(templateId: string) {
    const records = await prisma.employeeSalaryRecord.count({ where: { templateId } });
    if (records > 0) throw new Error('Cannot delete template with existing salary records');

    await prisma.salaryStructureTemplate.delete({ where: { id: templateId } });
    return { deleted: true };
  },

  async getTemplateRules(templateId: string) {
    return prisma.salaryColumnRule.findMany({
      where: { templateId },
      include: { conditions: { orderBy: { sortOrder: 'asc' } } },
      orderBy: [{ category: 'asc' }, { columnIdentifier: 'asc' }],
    });
  },

  async getColumnDefinitions(payCommissionCode: string) {
    const payCommissionId = (await getPayCommissionByCode(payCommissionCode)).id;
    return prisma.salaryColumnDefinition.findMany({
      where: { payCommissionId },
      orderBy: { evaluationOrder: 'asc' },
    });
  },

  async upsertColumnRule(
    templateId: string,
    columnIdentifier: string,
    category: SalaryColumnCategory,
    input: ColumnRuleInput,
  ) {
    const parsed = columnRuleSchema.parse(input);
    if (parsed.rule_type === 'CONDITIONAL') {
      validateConditionalConditions(parsed.conditions);
    }

    const { template, columnDefinitions } = await loadTemplateContext(templateId);
    const def = columnDefinitions.find(
      (d) => d.columnIdentifier === columnIdentifier && d.category === category,
    );
    if (!def) throw new Error('Unknown column for this pay commission');
    if (!def.isRuleConfigurable) throw new Error('This column is computed and cannot be configured');

    const formulaPreview = buildFormulaPreview(parsed as ColumnRuleInput, columnDefinitions);

    const ruleData = {
      ruleType: parsed.rule_type,
      formulaPreview,
      fixedDefaultValue: parsed.rule_type === 'FIXED' ? parsed.default_value : null,
      percentageValue: parsed.rule_type === 'PERCENTAGE' ? parsed.percentage_value : null,
      percentageReferenceColumns:
        parsed.rule_type === 'PERCENTAGE'
          ? (parsed.percentage_reference_columns ??
            (parsed.reference_column_identifier
              ? [{ column_identifier: parsed.reference_column_identifier, weight: 1 }]
              : []))
          : Prisma.JsonNull,
    };

    const rule = await prisma.$transaction(async (tx) => {
      const upserted = await tx.salaryColumnRule.upsert({
        where: {
          templateId_columnIdentifier_category: { templateId, columnIdentifier, category },
        },
        create: {
          templateId,
          columnIdentifier,
          category,
          ...ruleData,
        },
        update: ruleData,
      });

      if (parsed.rule_type === 'CONDITIONAL') {
        await tx.conditionalRuleCondition.deleteMany({ where: { columnRuleId: upserted.id } });
        await tx.conditionalRuleCondition.createMany({
          data: parsed.conditions.map((c) => ({
            columnRuleId: upserted.id,
            comparator: c.comparator,
            referenceColumnIdentifier: c.reference_column_identifier,
            thresholdValue: c.threshold_value,
            resultType: c.result_type,
            resultValue: c.result_value,
            resultReferenceColumnIdentifier: c.result_reference_column_identifier ?? null,
            resultReferenceColumns:
              c.result_type === 'PERCENTAGE_OF_COLUMN' && c.result_reference_columns?.length
                ? c.result_reference_columns
                : undefined,
            sortOrder: c.sort_order,
            isElseFallback: c.is_else_fallback,
          })),
        });
      } else {
        await tx.conditionalRuleCondition.deleteMany({ where: { columnRuleId: upserted.id } });
      }

      return tx.salaryColumnRule.findUnique({
        where: { id: upserted.id },
        include: { conditions: { orderBy: { sortOrder: 'asc' } } },
      });
    });

    return { rule, template: template.designation.name };
  },

  async computePreview(
    templateId: string,
    overrides?: Record<string, number>,
    options?: {
      employeeId?: number;
      employeeRules?: Record<string, ColumnRuleInput> | null;
    },
  ) {
    const { columnDefinitions } = await loadTemplateContext(templateId);
    const rules = await prisma.salaryColumnRule.findMany({
      where: { templateId },
      include: { conditions: { orderBy: { sortOrder: 'asc' } } },
    });

    let employeeRules = options?.employeeRules;
    if (employeeRules === undefined && options?.employeeId) {
      const profile = await prisma.employeeSalaryInfo.findUnique({
        where: { employeeId: options.employeeId },
      });
      employeeRules = (profile?.columnRules as Record<string, ColumnRuleInput> | null) ?? null;
    }

    const merged = mergeEmployeeRules(rules, employeeRules, columnDefinitions);
    return computeFullSalary(columnDefinitions, merged, overrides);
  },

  async createSalaryRecord(
    employeeId: number,
    salaryMonth: number,
    salaryYear: number,
    createdBy?: string,
  ) {
    const existing = await prisma.employeeSalaryRecord.findUnique({
      where: { employeeId_salaryMonth_salaryYear: { employeeId, salaryMonth, salaryYear } },
    });
    if (existing) throw new Error('Salary record already exists for this month');

    const lastDay = new Date(Date.UTC(salaryYear, salaryMonth, 0));
    const assignment = await assignmentService.resolveForDate(employeeId, lastDay);

    const salaryInfo = await prisma.employeeSalaryInfo.findUnique({ where: { employeeId } });
    if (!salaryInfo?.payCommissionId) {
      throw new Error('Employee pay commission not configured in salary profile');
    }

    const designationId =
      assignment?.designationId ??
      (await prisma.employeeGeneralInfo.findUnique({ where: { employeeId } }))?.designationId;
    if (!designationId) throw new Error('Employee designation not found');

    const designation = await prisma.designation.findUnique({ where: { id: designationId } });
    if (designation?.isAlias) throw new Error('Cannot create salary for alias designation');

    const payCommission = await prisma.payCommission.findUnique({
      where: { id: salaryInfo.payCommissionId },
    });
    if (!payCommission) throw new Error('Employee pay commission not found');

    const { template } = await this.getTemplateByDesignationAndCommission(
      designationId,
      payCommission.code,
    );
    if (!template) {
      throw new Error('No salary structure template configured for this designation and pay commission');
    }

    const profileOverrides = (salaryInfo.columnOverrides as Record<string, number> | null) ?? undefined;
    const computed = await this.computePreview(template.id, profileOverrides, { employeeId });

    return prisma.$transaction(async (tx) => {
      const record = await tx.employeeSalaryRecord.create({
        data: {
          employeeId,
          assignmentId: assignment?.id ?? null,
          templateId: template.id,
          payCommissionCode: payCommission.code,
          salaryMonth,
          salaryYear,
          status: SalaryRecordStatus.UNPAID,
          grossPay: computed.gross_pay,
          totalDeductions: computed.total_deductions,
          netPay: computed.net_pay,
          createdBy,
        },
      });

      await tx.employeeSalaryColumnValue.createMany({
        data: computed.columns.map((c) => ({
          salaryRecordId: record.id,
          columnIdentifier: c.column_identifier,
          category: c.category,
          ruleComputedValue: c.rule_computed_value,
          overrideValue: null,
          effectiveValue: c.effective_value,
          formulaPreview: c.formula_preview,
        })),
      });

      return tx.employeeSalaryRecord.findUnique({
        where: { id: record.id },
        include: {
          columnValues: { orderBy: [{ category: 'asc' }, { columnIdentifier: 'asc' }] },
          employee: { include: { generalInfo: true } },
          template: { include: { designation: true, payCommission: true } },
        },
      });
    });
  },

  async updateSalaryRecord(recordId: string, overrides?: Record<string, number>) {
    const record = await prisma.employeeSalaryRecord.findUnique({
      where: { id: recordId },
      include: { columnValues: true, template: true },
    });
    if (!record) throw new Error('Salary record not found');
    if (record.status === SalaryRecordStatus.PAID) {
      throw new Error('Cannot edit paid salary record');
    }

    const mergedOverrides = overrides ?? (await prisma.employeeSalaryInfo.findUnique({
      where: { employeeId: record.employeeId },
    }))?.columnOverrides as Record<string, number> | undefined;

    const computed = await this.computePreview(record.templateId, mergedOverrides, {
      employeeId: record.employeeId,
    });

    return prisma.$transaction(async (tx) => {
      for (const col of computed.columns) {
        const key = columnKey(col.column_identifier, col.category);
        const overrideVal = overrides?.[key] ?? overrides?.[col.column_identifier];
        await tx.employeeSalaryColumnValue.upsert({
          where: {
            salaryRecordId_columnIdentifier_category: {
              salaryRecordId: recordId,
              columnIdentifier: col.column_identifier,
              category: col.category,
            },
          },
          create: {
            salaryRecordId: recordId,
            columnIdentifier: col.column_identifier,
            category: col.category,
            ruleComputedValue: col.rule_computed_value,
            overrideValue: overrideVal ?? null,
            effectiveValue: col.effective_value,
            formulaPreview: col.formula_preview,
          },
          update: {
            ruleComputedValue: col.rule_computed_value,
            overrideValue: overrideVal ?? null,
            effectiveValue: col.effective_value,
            formulaPreview: col.formula_preview,
          },
        });
      }

      return tx.employeeSalaryRecord.update({
        where: { id: recordId },
        data: {
          grossPay: computed.gross_pay,
          totalDeductions: computed.total_deductions,
          netPay: computed.net_pay,
        },
        include: {
          columnValues: true,
          employee: { include: { generalInfo: true } },
          template: { include: { designation: true, payCommission: true } },
        },
      });
    });
  },

  async markRecordPaid(recordId: string, paidBy: string) {
    const record = await prisma.employeeSalaryRecord.findUnique({ where: { id: recordId } });
    if (!record) throw new Error('Salary record not found');
    if (record.status === SalaryRecordStatus.PAID) {
      throw new Error('Record is already marked paid');
    }

    return prisma.employeeSalaryRecord.update({
      where: { id: recordId },
      data: {
        status: SalaryRecordStatus.PAID,
        finalizedAt: new Date(),
        finalizedBy: paidBy,
      },
      include: {
        columnValues: true,
        employee: { include: { generalInfo: true } },
        template: { include: { designation: true, payCommission: true } },
      },
    });
  },

  /** @deprecated use markRecordPaid */
  async finalizeRecord(recordId: string, finalizedBy: string) {
    return this.markRecordPaid(recordId, finalizedBy);
  },

  async markRecordUnpaid(recordId: string) {
    const record = await prisma.employeeSalaryRecord.findUnique({ where: { id: recordId } });
    if (!record) throw new Error('Salary record not found');
    if (record.status === SalaryRecordStatus.UNPAID) {
      throw new Error('Record is already unpaid');
    }

    return prisma.employeeSalaryRecord.update({
      where: { id: recordId },
      data: {
        status: SalaryRecordStatus.UNPAID,
        finalizedAt: null,
        finalizedBy: null,
      },
      include: {
        columnValues: true,
        employee: { include: { generalInfo: true } },
        template: { include: { designation: true, payCommission: true } },
      },
    });
  },

  async getRecord(recordId: string) {
    const record = await prisma.employeeSalaryRecord.findUnique({
      where: { id: recordId },
      include: {
        columnValues: true,
        employee: { include: { generalInfo: true } },
        template: { include: { designation: true, payCommission: true } },
        assignment: true,
      },
    });
    if (!record) throw new Error('Salary record not found');
    return record;
  },

  async listRecords(filters: {
    employeeId?: number;
    designationId?: string;
    payCommissionCode?: string;
    salaryMonth?: number;
    salaryYear?: number;
    status?: SalaryRecordStatus;
  }) {
    const where: Prisma.EmployeeSalaryRecordWhereInput = {};
    if (filters.employeeId) where.employeeId = filters.employeeId;
    if (filters.payCommissionCode) where.payCommissionCode = filters.payCommissionCode.toUpperCase();
    if (filters.salaryMonth) where.salaryMonth = filters.salaryMonth;
    if (filters.salaryYear) where.salaryYear = filters.salaryYear;
    if (filters.status) where.status = filters.status;
    if (filters.designationId) {
      where.template = { designationId: filters.designationId };
    }

    return prisma.employeeSalaryRecord.findMany({
      where,
      include: {
        columnValues: { orderBy: [{ category: 'asc' }, { columnIdentifier: 'asc' }] },
        employee: { include: { generalInfo: { select: { fullName: true, department: true } } } },
        template: { include: { designation: true, payCommission: true } },
      },
      orderBy: [{ salaryYear: 'desc' }, { salaryMonth: 'desc' }],
    });
  },

  async getStructureStatus() {
    const [designations, commissions, templates] = await Promise.all([
      prisma.designation.findMany({
        where: { isAlias: false, isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      }),
      prisma.payCommission.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      }),
      prisma.salaryStructureTemplate.findMany({
        where: { isActive: true },
        include: { payCommission: true, _count: { select: { columnRules: true } } },
      }),
    ]);

    return designations.map((d) => ({
      designation: d,
      commissions: commissions.map((pc) => {
        const tpl = templates.find(
          (t) => t.designationId === d.id && t.payCommissionId === pc.id,
        );
        return {
          payCommission: {
            id: pc.id,
            code: pc.code,
            name: pc.name,
            ruleEditorEnabled: pc.ruleEditorEnabled,
          },
          configured: !!tpl && tpl._count.columnRules > 0,
          templateId: tpl?.id ?? null,
        };
      }),
    }));
  },

  async updateEmployeePayProfile(
    employeeId: number,
    data: {
      payCommissionCode?: string;
      columnOverrides?: Record<string, number> | null;
      columnRules?: Record<string, ColumnRuleInput> | null;
    },
    updatedBy?: string,
  ) {
    const generalInfo = await prisma.employeeGeneralInfo.findUnique({ where: { employeeId } });
    if (!generalInfo?.designationId) {
      throw new Error('Employee designation must be set before configuring pay commission');
    }

    const existing = await prisma.employeeSalaryInfo.findUnique({ where: { employeeId } });
    let payCommissionId = existing?.payCommissionId ?? null;
    let payCommissionLabel = existing?.payCommission ?? null;

    if (data.payCommissionCode) {
      const pc = await getPayCommissionByCode(data.payCommissionCode);
      payCommissionId = pc.id;
      payCommissionLabel = pc.name;
    } else if (!payCommissionId) {
      const defaultPc = await getPayCommissionByCode('FIFTH');
      payCommissionId = defaultPc.id;
      payCommissionLabel = defaultPc.name;
    }

    return prisma.employeeSalaryInfo.upsert({
      where: { employeeId },
      create: {
        employeeId,
        payCommissionId,
        payCommission: payCommissionLabel,
        designationId: generalInfo.designationId,
        columnOverrides: data.columnOverrides ?? undefined,
        columnRules: data.columnRules ?? undefined,
        updatedBy,
      },
      update: {
        ...(data.payCommissionCode
          ? { payCommissionId, payCommission: payCommissionLabel }
          : {}),
        designationId: generalInfo.designationId,
        ...(data.columnOverrides !== undefined
          ? { columnOverrides: data.columnOverrides ?? Prisma.JsonNull }
          : {}),
        ...(data.columnRules !== undefined
          ? { columnRules: data.columnRules ?? Prisma.JsonNull }
          : {}),
        updatedBy,
      },
    });
  },

  async getEmployeePayProfile(employeeId: number) {
    return prisma.employeeSalaryInfo.findUnique({
      where: { employeeId },
      include: { designationRef: true, payCommissionRef: true },
    });
  },

  async getEmployeeSalaryPreview(employeeId: number) {
    const generalInfo = await prisma.employeeGeneralInfo.findUnique({
      where: { employeeId },
      include: { designationRef: true },
    });
    const profile = await this.getEmployeePayProfile(employeeId);
    const designationId = profile?.designationId ?? generalInfo?.designationId ?? null;
    const payCommissionCode = profile?.payCommissionRef?.code ?? null;
    const payCommissionId = profile?.payCommissionId ?? null;

    if (!designationId || !payCommissionId) {
      return {
        configured: false,
        reason: !designationId ? 'NO_DESIGNATION' : 'NO_COMMISSION',
        designation: generalInfo?.designationRef ?? null,
        payCommissionCode,
        payCommission: profile?.payCommissionRef ?? null,
        columnOverrides: {},
        computed: null,
        templateId: null,
      };
    }

    const template = await prisma.salaryStructureTemplate.findFirst({
      where: {
        designationId,
        isActive: true,
        payCommissionId,
      },
      include: {
        designation: true,
        payCommission: true,
        _count: { select: { columnRules: true } },
      },
    });

    if (!template) {
      return {
        configured: false,
        reason: 'NO_TEMPLATE',
        designation: generalInfo?.designationRef ?? null,
        payCommissionCode,
        payCommission: profile?.payCommissionRef ?? null,
        columnOverrides: (profile?.columnOverrides as Record<string, number>) ?? {},
        computed: null,
        templateId: null,
      };
    }

    const overrides = (profile?.columnOverrides as Record<string, number> | null) ?? {};
    const employeeColumnRules =
      (profile?.columnRules as Record<string, ColumnRuleInput> | null) ?? {};
    const templateRules = await prisma.salaryColumnRule.findMany({
      where: { templateId: template.id },
      include: { conditions: { orderBy: { sortOrder: 'asc' } } },
    });
    const computed = await this.computePreview(template.id, overrides, {
      employeeId,
      employeeRules: employeeColumnRules,
    });
    const columnDefinitions = await prisma.salaryColumnDefinition.findMany({
      where: { payCommissionId: template.payCommissionId },
      orderBy: { evaluationOrder: 'asc' },
    });
    const displayNameByKey = new Map(
      columnDefinitions.map((d) => [`${d.category}::${d.columnIdentifier}`, d.displayName]),
    );

    return {
      configured: template._count.columnRules > 0,
      reason: template._count.columnRules > 0 ? null : 'NO_RULES',
      designation: generalInfo?.designationRef ?? template.designation,
      payCommissionCode,
      payCommission: profile?.payCommissionRef ?? template.payCommission,
      ruleEditorEnabled: profile?.payCommissionRef?.ruleEditorEnabled ?? true,
      columnVisibility:
        (template.columnVisibility as Record<string, boolean> | null) ?? {},
      templateId: template.id,
      columnOverrides: overrides,
      employeeColumnRules,
      templateRules,
      columnDefinitions,
      computed: {
        ...computed,
        columns: computed.columns.map((c) => ({
          ...c,
          display_name: displayNameByKey.get(columnKey(c.column_identifier, c.category as SalaryColumnCategory)) ?? c.column_identifier,
        })),
      },
    };
  },

  async getLatestFinalizedRecord(employeeId: number) {
    return prisma.employeeSalaryRecord.findFirst({
      where: { employeeId, status: SalaryRecordStatus.PAID },
      orderBy: [{ salaryYear: 'desc' }, { salaryMonth: 'desc' }],
      include: { template: { include: { designation: true } } },
    });
  },

  async getSlipData(recordId: string) {
    const record = await this.getRecord(recordId);
    const earnings = record.columnValues.filter((c) => c.category === 'EARNING' && c.columnIdentifier !== 'gross_pay');
    const deductions = record.columnValues.filter(
      (c) =>
        c.category === 'DEDUCTION' &&
        c.columnIdentifier !== 'net_pay' &&
        c.columnIdentifier !== 'total_deductions',
    );

    return {
      record,
      institutionName: record.employee.generalInfo?.organization ?? 'Institution',
      monthYear: `${record.salaryMonth}/${record.salaryYear}`,
      employee: {
        id: record.employeeId,
        name: record.employee.generalInfo?.fullName ?? '',
        designation: record.template.designation.name,
        department: record.employee.generalInfo?.department ?? '',
      },
      earnings,
      deductions,
      grossPay: Number(record.grossPay),
      totalDeductions: Number(record.totalDeductions),
      netPay: Number(record.netPay),
    };
  },

  async listEmployeeRecords(employeeId: number, filters?: { salaryYear?: number; salaryMonth?: number }) {
    return this.listRecords({
      employeeId,
      salaryYear: filters?.salaryYear,
      salaryMonth: filters?.salaryMonth,
    });
  },

  async getEmployeeMonthlyOverview(employeeId: number, year: number, month: number) {
    const { attendanceService } = await import('../attendance/attendance.service');
    const attendance = await attendanceService.getEmployeeMonthlySummary({ employeeId, year, month });

    const [record, balances] = await Promise.all([
      prisma.employeeSalaryRecord.findFirst({
        where: { employeeId, salaryYear: year, salaryMonth: month },
        include: {
          template: { include: { designation: true, payCommission: true } },
          columnValues: true,
        },
      }),
      prisma.leaveBalance.findMany({
        where: { employeeId, year },
        include: { leaveType: { select: { code: true, name: true } } },
      }),
    ]);

    return {
      year,
      month,
      attendance: attendance.stats,
      attendancePolicy: attendance.policy,
      days: attendance.days,
      leaveApplications: attendance.leaveApplications,
      leaveBalances: balances.map((b) => ({
        leaveType: b.leaveType,
        totalCredited: Number(b.totalCredited),
        carryForward: Number(b.carryForward),
        used: Number(b.used),
        available: Number(b.available),
      })),
      salaryRecord: record
        ? {
            id: record.id,
            status: record.status,
            salaryMonth: record.salaryMonth,
            salaryYear: record.salaryYear,
            grossPay: Number(record.grossPay),
            totalDeductions: Number(record.totalDeductions),
            netPay: Number(record.netPay),
            payCommissionCode: record.payCommissionCode,
            designation: record.template.designation.name,
            canDownloadSlip: record.status === 'PAID',
            columns: record.columnValues.map((c) => ({
              columnIdentifier: c.columnIdentifier,
              category: c.category,
              ruleComputedValue: Number(c.ruleComputedValue),
              overrideValue: c.overrideValue != null ? Number(c.overrideValue) : null,
              effectiveValue: Number(c.effectiveValue),
              formulaPreview: c.formulaPreview,
            })),
          }
        : null,
    };
  },

  /**
   * Calculate (and optionally persist) monthly salary using employee profile amounts,
   * attendance proration (cut-on-leave / cut-on-absent), and any existing reimbursement overrides.
   */
  async calculateMonthlySalary(params: {
    employeeId: number;
    year: number;
    month: number;
    persist: boolean;
    createdBy?: string;
  }) {
    const { employeeId, year, month, persist, createdBy } = params;
    if (!Number.isFinite(year) || !Number.isFinite(month) || month < 1 || month > 12) {
      throw new Error('Invalid year/month');
    }

    const { attendanceService } = await import('../attendance/attendance.service');
    const attendance = await attendanceService.getEmployeeMonthlySummary({ employeeId, year, month });
    const stats = attendance.stats as {
      absentDays: number;
      unpaidLeaveDays: number;
      salaryAbsentDays: number;
      daysInMonth: number;
      holidayDays: number;
      leaveDays: number;
    };

    const existing = await prisma.employeeSalaryRecord.findUnique({
      where: {
        employeeId_salaryMonth_salaryYear: {
          employeeId,
          salaryMonth: month,
          salaryYear: year,
        },
      },
      include: { columnValues: true },
    });
    if (existing?.status === SalaryRecordStatus.PAID) {
      throw new Error('Salary for this month is paid and cannot be recalculated');
    }

    const salaryInfo = await prisma.employeeSalaryInfo.findUnique({ where: { employeeId } });
    if (!salaryInfo?.payCommissionId) {
      throw new Error('Employee pay commission not configured in salary profile');
    }

    const lastDay = new Date(Date.UTC(year, month, 0));
    const assignment = await assignmentService.resolveForDate(employeeId, lastDay);
    const designationId =
      assignment?.designationId ??
      (await prisma.employeeGeneralInfo.findUnique({ where: { employeeId } }))?.designationId;
    if (!designationId) throw new Error('Employee designation not found');

    const payCommission = await prisma.payCommission.findUnique({
      where: { id: salaryInfo.payCommissionId },
    });
    if (!payCommission) throw new Error('Employee pay commission not found');

    const { template } = await this.getTemplateByDesignationAndCommission(
      designationId,
      payCommission.code,
    );
    if (!template) {
      throw new Error('No salary structure template configured for this designation and pay commission');
    }

    const profileOverrides = (salaryInfo.columnOverrides as Record<string, number> | null) ?? {};
    const mergedOverrides: Record<string, number> = { ...profileOverrides };

    // Preserve non-reimbursement monthly overrides already on the record.
    if (existing?.columnValues?.length) {
      for (const cv of existing.columnValues) {
        if (cv.overrideValue == null) continue;
        const id = cv.columnIdentifier;
        if (id === 'reimbursement' || id === 'other_allowance') continue;
        mergedOverrides[columnKey(id, cv.category)] = Number(cv.overrideValue);
        mergedOverrides[id] = Number(cv.overrideValue);
      }
    }

    const { columnDefinitions } = await loadTemplateContext(template.id);

    // Fold all approved reimbursements for this month into salary.
    const monthStart = new Date(Date.UTC(year, month - 1, 1));
    const monthEndExclusive = new Date(Date.UTC(year, month, 1));
    const approvedClaims = await prisma.reimbursementClaim.findMany({
      where: {
        employeeId,
        status: 'APPROVED',
        OR: [
          { salaryMonth: month, salaryYear: year },
          {
            salaryMonth: null,
            appliedAt: { gte: monthStart, lt: monthEndExclusive },
          },
        ],
      },
      select: { id: true, amount: true },
    });
    const reimbursementTotal = approvedClaims.reduce((sum, c) => sum + Number(c.amount), 0);
    const hasReimbursementCol = columnDefinitions.some(
      (d) => d.columnIdentifier === 'reimbursement' && d.category === 'EARNING',
    );
    const reimbColId = hasReimbursementCol ? 'reimbursement' : 'other_allowance';
    if (reimbursementTotal > 0 || hasReimbursementCol) {
      if (hasReimbursementCol) {
        mergedOverrides[columnKey(reimbColId, 'EARNING')] = reimbursementTotal;
        mergedOverrides[reimbColId] = reimbursementTotal;
      } else if (reimbursementTotal > 0) {
        const profileBase = Number(
          profileOverrides[columnKey(reimbColId, 'EARNING')] ?? profileOverrides[reimbColId] ?? 0,
        );
        mergedOverrides[columnKey(reimbColId, 'EARNING')] = profileBase + reimbursementTotal;
        mergedOverrides[reimbColId] = profileBase + reimbursementTotal;
      }
    }

    let computed = await this.computePreview(template.id, mergedOverrides, { employeeId });
    computed = applyAttendanceProration(computed, columnDefinitions, {
      daysInMonth: stats.daysInMonth,
      absentDays: stats.absentDays,
      unpaidLeaveDays: stats.unpaidLeaveDays,
    });

    const breakdown = {
      daysInMonth: stats.daysInMonth,
      trueAbsentDays: stats.absentDays,
      unpaidLeaveDays: stats.unpaidLeaveDays,
      salaryAbsentDays: stats.salaryAbsentDays,
      holidayDays: stats.holidayDays,
      leaveDays: stats.leaveDays,
      reimbursementTotal,
      reimbursementClaims: approvedClaims.length,
    };

    if (!persist) {
      return {
        persisted: false,
        breakdown,
        computed: {
          grossPay: computed.gross_pay,
          totalDeductions: computed.total_deductions,
          netPay: computed.net_pay,
          columns: computed.columns,
        },
        salaryRecord: existing
          ? { id: existing.id, status: existing.status, salaryMonth: month, salaryYear: year }
          : null,
      };
    }

    const saved = await prisma.$transaction(async (tx) => {
      let recordId = existing?.id;
      if (!recordId) {
        const created = await tx.employeeSalaryRecord.create({
          data: {
            employeeId,
            assignmentId: assignment?.id ?? null,
            templateId: template.id,
            payCommissionCode: payCommission.code,
            salaryMonth: month,
            salaryYear: year,
            status: SalaryRecordStatus.UNPAID,
            grossPay: computed.gross_pay,
            totalDeductions: computed.total_deductions,
            netPay: computed.net_pay,
            createdBy,
          },
        });
        recordId = created.id;
      } else {
        await tx.employeeSalaryRecord.update({
          where: { id: recordId },
          data: {
            grossPay: computed.gross_pay,
            totalDeductions: computed.total_deductions,
            netPay: computed.net_pay,
          },
        });
      }

      for (const col of computed.columns) {
        const key = columnKey(col.column_identifier, col.category);
        const overrideVal = mergedOverrides[key] ?? mergedOverrides[col.column_identifier];
        await tx.employeeSalaryColumnValue.upsert({
          where: {
            salaryRecordId_columnIdentifier_category: {
              salaryRecordId: recordId,
              columnIdentifier: col.column_identifier,
              category: col.category,
            },
          },
          create: {
            salaryRecordId: recordId,
            columnIdentifier: col.column_identifier,
            category: col.category,
            ruleComputedValue: col.rule_computed_value,
            overrideValue: overrideVal ?? null,
            effectiveValue: col.effective_value,
            formulaPreview: col.formula_preview,
          },
          update: {
            ruleComputedValue: col.rule_computed_value,
            overrideValue: overrideVal ?? null,
            effectiveValue: col.effective_value,
            formulaPreview: col.formula_preview,
          },
        });
      }

      if (approvedClaims.length) {
        await tx.reimbursementClaim.updateMany({
          where: { id: { in: approvedClaims.map((c) => c.id) } },
          data: {
            salaryMonth: month,
            salaryYear: year,
            salaryRecordId: recordId,
          },
        });
      }

      return tx.employeeSalaryRecord.findUnique({
        where: { id: recordId },
        include: {
          columnValues: { orderBy: [{ category: 'asc' }, { columnIdentifier: 'asc' }] },
          template: { include: { designation: true, payCommission: true } },
        },
      });
    });

    return {
      persisted: true,
      breakdown,
      computed: {
        grossPay: computed.gross_pay,
        totalDeductions: computed.total_deductions,
        netPay: computed.net_pay,
        columns: computed.columns,
      },
      salaryRecord: saved
        ? {
            id: saved.id,
            status: saved.status,
            salaryMonth: saved.salaryMonth,
            salaryYear: saved.salaryYear,
            grossPay: Number(saved.grossPay),
            totalDeductions: Number(saved.totalDeductions),
            netPay: Number(saved.netPay),
            designation: saved.template.designation.name,
            payCommissionCode: saved.payCommissionCode,
            columns: saved.columnValues.map((c) => ({
              columnIdentifier: c.columnIdentifier,
              category: c.category,
              ruleComputedValue: Number(c.ruleComputedValue),
              overrideValue: c.overrideValue != null ? Number(c.overrideValue) : null,
              effectiveValue: Number(c.effectiveValue),
              formulaPreview: c.formulaPreview,
            })),
          }
        : null,
    };
  },

  async getMonthPayrollOverview(year: number, month: number) {
    if (!Number.isFinite(year) || !Number.isFinite(month) || month < 1 || month > 12) {
      throw new Error('Invalid year/month');
    }

    const [employees, records] = await Promise.all([
      prisma.employee.findMany({
        where: { status: 'ACTIVE' },
        select: {
          id: true,
          generalInfo: {
            select: {
              fullName: true,
              employeeCode: true,
              department: true,
              designation: true,
            },
          },
          salaryInfo: { select: { payCommissionId: true } },
        },
        orderBy: { id: 'asc' },
      }),
      prisma.employeeSalaryRecord.findMany({
        where: { salaryYear: year, salaryMonth: month },
        select: {
          id: true,
          employeeId: true,
          status: true,
          grossPay: true,
          totalDeductions: true,
          netPay: true,
          payCommissionCode: true,
        },
      }),
    ]);

    const byEmployee = new Map(records.map((r) => [r.employeeId, r]));
    const rows = employees.map((e) => {
      const rec = byEmployee.get(e.id);
      const status = !rec
        ? 'NOT_CALCULATED'
        : rec.status === SalaryRecordStatus.PAID
          ? 'PAID'
          : 'UNPAID';
      return {
        employeeId: e.id,
        fullName: e.generalInfo?.fullName ?? `Employee #${e.id}`,
        employeeCode: e.generalInfo?.employeeCode ?? null,
        department: e.generalInfo?.department ?? null,
        designation: e.generalInfo?.designation ?? null,
        hasPayCommission: Boolean(e.salaryInfo?.payCommissionId),
        status,
        recordId: rec?.id ?? null,
        grossPay: rec ? Number(rec.grossPay) : null,
        totalDeductions: rec ? Number(rec.totalDeductions) : null,
        netPay: rec ? Number(rec.netPay) : null,
        payCommissionCode: rec?.payCommissionCode ?? null,
      };
    });

    let paidAmount = 0;
    let unpaidAmount = 0;
    let paidCount = 0;
    let unpaidCount = 0;
    let notCalculatedCount = 0;
    for (const row of rows) {
      if (row.status === 'PAID') {
        paidCount += 1;
        paidAmount += row.netPay ?? 0;
      } else if (row.status === 'UNPAID') {
        unpaidCount += 1;
        unpaidAmount += row.netPay ?? 0;
      } else {
        notCalculatedCount += 1;
      }
    }

    return {
      year,
      month,
      kpis: {
        totalEmployees: rows.length,
        calculatedCount: paidCount + unpaidCount,
        notCalculatedCount,
        unpaidCount,
        paidCount,
        totalNetPay: paidAmount + unpaidAmount,
        paidAmount,
        remainingAmount: unpaidAmount,
      },
      employees: rows,
    };
  },
};
