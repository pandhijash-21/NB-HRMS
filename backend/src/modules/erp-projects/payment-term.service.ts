import { prisma } from '../../config/prisma';
import { Prisma } from '@prisma/client';

function num(v: unknown): number | null {
  if (v == null || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function dec(v: unknown): Prisma.Decimal | null {
  const n = num(v);
  return n == null ? null : new Prisma.Decimal(n);
}

const DEFAULT_REGULAR_TERMS = [
  { name: 'On Booking', percentPayment: new Prisma.Decimal(10), lastDayMonths: new Prisma.Decimal(0.5), sequence: 0 },
  { name: 'On Plinth Level', percentPayment: new Prisma.Decimal(20), lastDayMonths: new Prisma.Decimal(2), sequence: 1 },
  { name: 'On Structure Completion', percentPayment: new Prisma.Decimal(40), lastDayMonths: new Prisma.Decimal(6), sequence: 2 },
  { name: 'On Finishing / Flooring', percentPayment: new Prisma.Decimal(20), lastDayMonths: new Prisma.Decimal(10), sequence: 3 },
  { name: 'On Possession', percentPayment: new Prisma.Decimal(10), lastDayMonths: new Prisma.Decimal(12), sequence: 4 },
];

const DEFAULT_20_80_TERMS = [
  { name: 'On Booking', percentPayment: new Prisma.Decimal(20), lastDayMonths: new Prisma.Decimal(0), sequence: 0 },
  { name: 'Within 3 Months', percentPayment: new Prisma.Decimal(80), lastDayMonths: new Prisma.Decimal(3), sequence: 1 },
];

export const paymentTermService = {
  async ensureSeeded() {
    const count = await prisma.erpPaymentPlan.count();
    if (count > 0) return;

    // 1. Regular Construction Plan (Default)
    const regularPlan = await prisma.erpPaymentPlan.create({
      data: {
        name: 'Regular Construction Plan',
        code: 'REGULAR_PLAN',
        description: 'Standard construction milestone-linked payment schedule',
        isDefault: true,
        isActive: true,
        sequence: 0,
        terms: {
          create: DEFAULT_REGULAR_TERMS,
        },
      },
    });

    // 2. 20:80 Subvention / Booking Plan
    await prisma.erpPaymentPlan.create({
      data: {
        name: '20:80 Booking Plan',
        code: 'PLAN_20_80',
        description: '20% on booking and 80% within 3 months',
        isDefault: false,
        isActive: true,
        sequence: 1,
        terms: {
          create: DEFAULT_20_80_TERMS,
        },
      },
    });

    // Link any orphan terms without plan_id to regularPlan
    await prisma.erpPaymentTerm.updateMany({
      where: { planId: null },
      data: { planId: regularPlan.id },
    });
  },

  async listPlans(includeInactive = false) {
    await this.ensureSeeded();

    const where: Prisma.ErpPaymentPlanWhereInput = {};
    if (!includeInactive) {
      where.isActive = true;
    }

    return prisma.erpPaymentPlan.findMany({
      where,
      include: {
        terms: {
          where: includeInactive ? undefined : { isActive: true },
          orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
        },
      },
      orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async getPlanById(id: string) {
    const plan = await prisma.erpPaymentPlan.findUnique({
      where: { id },
      include: {
        terms: {
          orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
        },
      },
    });
    if (!plan) throw new Error('Payment plan not found');
    return plan;
  },

  async createPlan(body: Record<string, unknown>) {
    const name = String(body.name ?? '').trim();
    if (!name) throw new Error('Plan name is required');
    const rawCode = String(body.code ?? name).trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_');
    const code = rawCode.length > 0 ? rawCode : `PLAN_${Date.now()}`;
    const description = body.description ? String(body.description).trim() : null;
    const isDefault = Boolean(body.isDefault);
    const sequence = num(body.sequence) != null ? Math.trunc(Number(body.sequence)) : 0;

    if (isDefault) {
      await prisma.erpPaymentPlan.updateMany({
        where: { isDefault: true },
        data: { isDefault: false },
      });
    }

    // Optional initial terms
    let initialTerms: Prisma.ErpPaymentTermCreateWithoutPlanInput[] | undefined;
    if (Array.isArray(body.terms) && body.terms.length > 0) {
      initialTerms = body.terms.map((t: any, idx: number) => {
        const tName = String(t.name ?? `Milestone ${idx + 1}`).trim();
        const tPercent = dec(t.percentPayment) ?? new Prisma.Decimal(0);
        const tMonths = dec(t.lastDayMonths) ?? new Prisma.Decimal(0);
        const tSeq = num(t.sequence) != null ? Math.trunc(Number(t.sequence)) : idx;
        return {
          name: tName,
          percentPayment: tPercent,
          lastDayMonths: tMonths,
          sequence: tSeq,
          isActive: true,
        };
      });
    }

    return prisma.erpPaymentPlan.create({
      data: {
        name,
        code,
        description,
        isDefault,
        isActive: true,
        sequence,
        terms: initialTerms ? { create: initialTerms } : undefined,
      },
      include: {
        terms: {
          orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
        },
      },
    });
  },

  async updatePlan(id: string, body: Record<string, unknown>) {
    const data: Prisma.ErpPaymentPlanUpdateInput = {};
    if (body.name != null) data.name = String(body.name).trim();
    if (body.description !== undefined) {
      data.description = body.description ? String(body.description).trim() : null;
    }
    if (body.sequence != null) {
      const s = num(body.sequence);
      if (s != null) data.sequence = Math.trunc(s);
    }
    if (body.isActive != null) {
      data.isActive = Boolean(body.isActive);
    }
    if (body.isDefault === true) {
      await prisma.erpPaymentPlan.updateMany({
        where: { id: { not: id }, isDefault: true },
        data: { isDefault: false },
      });
      data.isDefault = true;
    } else if (body.isDefault === false) {
      data.isDefault = false;
    }

    return prisma.erpPaymentPlan.update({
      where: { id },
      data,
      include: {
        terms: {
          orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
        },
      },
    });
  },

  async deletePlan(id: string) {
    const plan = await prisma.erpPaymentPlan.findUnique({ where: { id } });
    if (!plan) throw new Error('Payment plan not found');

    const totalPlans = await prisma.erpPaymentPlan.count();
    if (totalPlans <= 1) {
      throw new Error('Cannot delete the only remaining payment plan');
    }

    await prisma.erpPaymentPlan.delete({ where: { id } });

    // If deleted plan was default, set another active plan as default
    if (plan.isDefault) {
      const next = await prisma.erpPaymentPlan.findFirst({
        where: { isActive: true },
        orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
      });
      if (next) {
        await prisma.erpPaymentPlan.update({
          where: { id: next.id },
          data: { isDefault: true },
        });
      }
    }
    return { success: true };
  },

  async duplicatePlan(id: string) {
    const source = await this.getPlanById(id);
    const newName = `${source.name} (Copy)`;
    const newCode = `${source.code}_COPY_${Date.now().toString().slice(-4)}`;

    return prisma.erpPaymentPlan.create({
      data: {
        name: newName,
        code: newCode,
        description: source.description,
        isDefault: false,
        isActive: true,
        sequence: source.sequence + 1,
        terms: {
          create: source.terms.map((t, idx) => ({
            name: t.name,
            percentPayment: t.percentPayment,
            lastDayMonths: t.lastDayMonths,
            sequence: idx,
            isActive: t.isActive,
          })),
        },
      },
      include: {
        terms: {
          orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
        },
      },
    });
  },

  // --- Terms under a Plan ---
  async list(planId?: string) {
    await this.ensureSeeded();

    let resolvedPlanId = planId;
    if (!resolvedPlanId) {
      const defaultPlan = await prisma.erpPaymentPlan.findFirst({
        where: { isDefault: true, isActive: true },
      });
      resolvedPlanId = defaultPlan?.id;
    }

    const where: Prisma.ErpPaymentTermWhereInput = { isActive: true };
    if (resolvedPlanId) {
      where.planId = resolvedPlanId;
    }

    return prisma.erpPaymentTerm.findMany({
      where,
      orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async create(body: Record<string, unknown>) {
    await this.ensureSeeded();

    const name = String(body.name ?? '').trim();
    if (!name) throw new Error('Term name is required');
    const percent = dec(body.percentPayment);
    if (percent == null) throw new Error('Percent payment is required');
    const months = dec(body.lastDayMonths);
    if (months == null) throw new Error('Last day of payment in months is required');
    const sequence = num(body.sequence) != null ? Math.trunc(Number(body.sequence)) : 0;

    let planId = body.planId ? String(body.planId).trim() : null;
    if (!planId) {
      const defaultPlan = await prisma.erpPaymentPlan.findFirst({
        where: { isDefault: true, isActive: true },
      });
      planId = defaultPlan?.id ?? null;
    }

    return prisma.erpPaymentTerm.create({
      data: {
        planId,
        name,
        percentPayment: percent,
        lastDayMonths: months,
        sequence,
        isActive: true,
      },
    });
  },

  async update(id: string, body: Record<string, unknown>) {
    const data: Prisma.ErpPaymentTermUpdateInput = {};
    if (body.name != null) data.name = String(body.name).trim();
    if (body.percentPayment != null) {
      const p = dec(body.percentPayment);
      if (p != null) data.percentPayment = p;
    }
    if (body.lastDayMonths != null) {
      const m = dec(body.lastDayMonths);
      if (m != null) data.lastDayMonths = m;
    }
    if (body.sequence != null) {
      const s = num(body.sequence);
      if (s != null) data.sequence = Math.trunc(s);
    }
    if (body.isActive != null) {
      data.isActive = Boolean(body.isActive);
    }
    if (body.planId != null) {
      data.plan = { connect: { id: String(body.planId) } };
    }

    return prisma.erpPaymentTerm.update({
      where: { id },
      data,
    });
  },

  async delete(id: string) {
    return prisma.erpPaymentTerm.delete({
      where: { id },
    });
  },
};
