import { Prisma, SalaryColumnCategory } from '@prisma/client';
import { prisma } from '../../config/prisma';

export function normalizePayCommissionCode(input: string): string {
  return input
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

export async function getPayCommissionByCode(code: string) {
  const normalized = normalizePayCommissionCode(code);
  const pc = await prisma.payCommission.findUnique({ where: { code: normalized } });
  if (!pc) throw new Error(`Pay commission "${code}" not found`);
  return pc;
}

type CreatePayCommissionInput = {
  code: string;
  name: string;
  description?: string | null;
  ruleEditorEnabled?: boolean;
  sortOrder?: number;
  cloneFromCommissionId?: string | null;
};

type UpdatePayCommissionInput = {
  name?: string;
  description?: string | null;
  isActive?: boolean;
  ruleEditorEnabled?: boolean;
  sortOrder?: number;
};

type ColumnInput = {
  columnIdentifier: string;
  displayName: string;
  category: SalaryColumnCategory;
  evaluationOrder: number;
  isRuleConfigurable?: boolean;
  cutOnLeave?: boolean;
  cutOnAbsent?: boolean;
};

export const payCommissionService = {
  async list() {
    return prisma.payCommission.findMany({
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      include: {
        _count: {
          select: {
            columnDefinitions: true,
            salaryStructureTemplates: true,
            employeeSalaryInfos: true,
          },
        },
      },
    });
  },

  async getById(id: string) {
    const pc = await prisma.payCommission.findUnique({
      where: { id },
      include: {
        columnDefinitions: { orderBy: { evaluationOrder: 'asc' } },
        _count: {
          select: {
            salaryStructureTemplates: true,
            employeeSalaryInfos: true,
          },
        },
      },
    });
    if (!pc) throw new Error('Pay commission not found');
    return pc;
  },

  async create(input: CreatePayCommissionInput) {
    const code = normalizePayCommissionCode(input.code);
    if (!code) throw new Error('Commission code is required');

    const existing = await prisma.payCommission.findUnique({ where: { code } });
    if (existing) throw new Error(`Pay commission code "${code}" already exists`);

    return prisma.$transaction(async (tx) => {
      const maxSort = await tx.payCommission.aggregate({ _max: { sortOrder: true } });
      const created = await tx.payCommission.create({
        data: {
          code,
          name: input.name.trim(),
          description: input.description ?? null,
          ruleEditorEnabled: input.ruleEditorEnabled ?? true,
          sortOrder: input.sortOrder ?? (maxSort._max.sortOrder ?? 0) + 10,
        },
      });

      if (input.cloneFromCommissionId) {
        const sourceCols = await tx.salaryColumnDefinition.findMany({
          where: { payCommissionId: input.cloneFromCommissionId },
          orderBy: { evaluationOrder: 'asc' },
        });
        if (sourceCols.length) {
          await tx.salaryColumnDefinition.createMany({
            data: sourceCols.map((c) => ({
              payCommissionId: created.id,
              columnIdentifier: c.columnIdentifier,
              displayName: c.displayName,
              category: c.category,
              evaluationOrder: c.evaluationOrder,
              isRuleConfigurable: c.isRuleConfigurable,
              cutOnLeave: c.cutOnLeave,
              cutOnAbsent: c.cutOnAbsent,
            })),
          });
        }
      }

      return tx.payCommission.findUnique({
        where: { id: created.id },
        include: {
          columnDefinitions: { orderBy: { evaluationOrder: 'asc' } },
          _count: { select: { columnDefinitions: true, salaryStructureTemplates: true } },
        },
      });
    });
  },

  async update(id: string, input: UpdatePayCommissionInput) {
    await this.getById(id);
    return prisma.payCommission.update({
      where: { id },
      data: {
        ...(input.name !== undefined ? { name: input.name.trim() } : {}),
        ...(input.description !== undefined ? { description: input.description } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
        ...(input.ruleEditorEnabled !== undefined ? { ruleEditorEnabled: input.ruleEditorEnabled } : {}),
        ...(input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
      },
      include: {
        columnDefinitions: { orderBy: { evaluationOrder: 'asc' } },
        _count: { select: { columnDefinitions: true, salaryStructureTemplates: true } },
      },
    });
  },

  async remove(id: string) {
    const pc = await this.getById(id);
    const recordCount = await prisma.employeeSalaryRecord.count({
      where: { template: { payCommissionId: id } },
    });
    if (recordCount > 0) {
      throw new Error('Cannot delete a pay commission that has salary records');
    }
    if (pc._count.employeeSalaryInfos > 0) {
      throw new Error('Cannot delete a pay commission assigned to employees. Deactivate it instead.');
    }
    if (pc._count.salaryStructureTemplates > 0) {
      throw new Error('Cannot delete a pay commission with structure templates. Deactivate it instead.');
    }
    await prisma.payCommission.delete({ where: { id } });
    return { deleted: true };
  },

  async listColumns(payCommissionId: string) {
    await this.getById(payCommissionId);
    return prisma.salaryColumnDefinition.findMany({
      where: { payCommissionId },
      orderBy: { evaluationOrder: 'asc' },
    });
  },

  async createColumn(payCommissionId: string, input: ColumnInput) {
    const identifier = input.columnIdentifier.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
    if (!identifier) throw new Error('Column identifier is required');

    return prisma.salaryColumnDefinition.create({
      data: {
        payCommissionId,
        columnIdentifier: identifier,
        displayName: input.displayName.trim(),
        category: input.category,
        evaluationOrder: input.evaluationOrder,
        isRuleConfigurable: input.isRuleConfigurable ?? true,
        cutOnLeave: input.cutOnLeave ?? false,
        cutOnAbsent: input.cutOnAbsent ?? false,
      },
    });
  },

  async updateColumn(columnId: string, input: Partial<ColumnInput>) {
    const col = await prisma.salaryColumnDefinition.findUnique({ where: { id: columnId } });
    if (!col) throw new Error('Column not found');

    return prisma.salaryColumnDefinition.update({
      where: { id: columnId },
      data: {
        ...(input.displayName !== undefined ? { displayName: input.displayName.trim() } : {}),
        ...(input.evaluationOrder !== undefined ? { evaluationOrder: input.evaluationOrder } : {}),
        ...(input.isRuleConfigurable !== undefined ? { isRuleConfigurable: input.isRuleConfigurable } : {}),
        ...(input.cutOnLeave !== undefined ? { cutOnLeave: input.cutOnLeave } : {}),
        ...(input.cutOnAbsent !== undefined ? { cutOnAbsent: input.cutOnAbsent } : {}),
      },
    });
  },

  async deleteColumn(columnId: string) {
    const col = await prisma.salaryColumnDefinition.findUnique({
      where: { id: columnId },
      include: { payCommission: { include: { salaryStructureTemplates: true } } },
    });
    if (!col) throw new Error('Column not found');

    const templateIds = col.payCommission.salaryStructureTemplates.map((t) => t.id);

    await prisma.$transaction(async (tx) => {
      if (templateIds.length) {
        await tx.salaryColumnRule.deleteMany({
          where: {
            templateId: { in: templateIds },
            columnIdentifier: col.columnIdentifier,
            category: col.category,
          },
        });
      }
      await tx.salaryColumnDefinition.delete({ where: { id: columnId } });
    });

    return { deleted: true };
  },
};
