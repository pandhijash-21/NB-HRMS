import {
  Prisma,
  SalaryColumnCategory,
  SalaryRecordStatus,
} from '@prisma/client';
import { prisma } from '../../config/prisma';
import { assignmentService } from '../personal-education/assignment.service';
import { buildFormulaPreview, computeFullSalary, mergeEmployeeRules } from './salaryEngine.service';
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
          status: SalaryRecordStatus.DRAFT,
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
    if (record.status === SalaryRecordStatus.FINALIZED) {
      throw new Error('Cannot edit finalized salary record');
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

  async finalizeRecord(recordId: string, finalizedBy: string) {
    const record = await prisma.employeeSalaryRecord.findUnique({ where: { id: recordId } });
    if (!record) throw new Error('Salary record not found');
    if (record.status === SalaryRecordStatus.FINALIZED) {
      throw new Error('Record is already finalized');
    }

    return prisma.employeeSalaryRecord.update({
      where: { id: recordId },
      data: {
        status: SalaryRecordStatus.FINALIZED,
        finalizedAt: new Date(),
        finalizedBy,
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
      where: { employeeId, status: SalaryRecordStatus.FINALIZED },
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
};
