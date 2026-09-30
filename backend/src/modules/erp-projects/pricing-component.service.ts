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

function computeFormulaPreview(formulaType: string, rateUnit?: string | null, defaultRate?: Prisma.Decimal | null): string {
  switch (formulaType) {
    case 'AREA_BSV':
      return 'Super Built-Up Area × Base Rate (BSV)';
    case 'AREA_RATE':
      return `Super Built-Up Area × Component Rate (${rateUnit ?? '₹/sq.ft'})`;
    case 'PERCENTAGE':
      return defaultRate != null ? `${defaultRate}% of Total Unit Value` : '% of Total Unit Value';
    case 'FIXED':
      return 'Fixed Amount (₹)';
    case 'DOCS_MULTIPLIER':
      return 'Document Count × Fee per Document';
    default:
      return 'Configured Formula';
  }
}

const DEFAULT_PRICING_COMPONENTS = [
  // 1. Base Components
  {
    category: 'BASE_PRICE',
    code: 'BSV',
    name: 'Basic Sale Value (BSV)',
    formulaType: 'AREA_RATE',
    formulaPreview: 'Super Built-Up Area × Base Rate',
    referenceBase: 'SUPER_BUILT_UP',
    rateUnit: '₹/sq.ft',
    isRequired: true,
    isActive: true,
    sequence: 1,
    description: 'Core residential basic sale price per square foot',
  },
  {
    category: 'BASE_PRICE',
    code: 'FRC',
    name: 'Floor Rise Charge (FRC)',
    formulaType: 'AREA_RATE',
    formulaPreview: 'Super Built-Up Area × FRC Rate',
    referenceBase: 'SUPER_BUILT_UP',
    rateUnit: '₹/sq.ft',
    isRequired: false,
    isActive: true,
    sequence: 2,
    description: 'Floor level incremental charge per square foot',
  },
  {
    category: 'BASE_PRICE',
    code: 'DEV_CHARGE',
    name: 'Development Charge (GEB / AMC)',
    formulaType: 'AREA_RATE',
    formulaPreview: 'Super Built-Up Area × Dev Rate',
    referenceBase: 'SUPER_BUILT_UP',
    rateUnit: '₹/sq.ft',
    isRequired: false,
    isActive: true,
    sequence: 3,
    description: 'Electricity Board & Municipal infrastructure charge',
  },
  {
    category: 'BASE_PRICE',
    code: 'PLC',
    name: 'Preferential Location Charge (PLC)',
    formulaType: 'AREA_RATE',
    formulaPreview: 'Super Built-Up Area × PLC Rate',
    referenceBase: 'SUPER_BUILT_UP',
    rateUnit: '₹/sq.ft',
    isRequired: false,
    isActive: true,
    sequence: 4,
    description: 'Corner, garden facing, road facing or premium location charge',
  },

  // 2. Taxes
  {
    category: 'TAX',
    code: 'GST',
    name: 'GST',
    formulaType: 'PERCENTAGE',
    formulaPreview: '5.0% of Total Unit Value',
    referenceBase: 'TOTAL_UNIT_VALUE',
    defaultRate: new Prisma.Decimal(5.0),
    rateUnit: '%',
    isRequired: false,
    isActive: true,
    sequence: 11,
    description: 'Goods and Services Tax on residential units',
  },
  {
    category: 'TAX',
    code: 'STAMP_DUTY',
    name: 'Stamp Duty',
    formulaType: 'PERCENTAGE',
    formulaPreview: '4.9% of Total Unit Value',
    referenceBase: 'TOTAL_UNIT_VALUE',
    defaultRate: new Prisma.Decimal(4.9),
    rateUnit: '%',
    isRequired: false,
    isActive: true,
    sequence: 12,
    description: 'State government stamp duty fee',
  },
  {
    category: 'TAX',
    code: 'REGISTRATION',
    name: 'Registration Fee',
    formulaType: 'PERCENTAGE',
    formulaPreview: '1.0% of Total Unit Value',
    referenceBase: 'TOTAL_UNIT_VALUE',
    defaultRate: new Prisma.Decimal(1.0),
    rateUnit: '%',
    isRequired: false,
    isActive: true,
    sequence: 13,
    description: 'Sub-registrar property registration charges',
  },

  // 3. Maintenance
  {
    category: 'MAINTENANCE',
    code: 'RUNNING_MAINTENANCE',
    name: 'Running Maintenance',
    formulaType: 'AREA_RATE',
    formulaPreview: 'Super Built-Up Area × Maintenance Rate',
    referenceBase: 'SUPER_BUILT_UP',
    rateUnit: '₹/sq.ft',
    isRequired: false,
    isActive: true,
    sequence: 21,
    description: 'Periodic maintenance collection per sq.ft',
  },
  {
    category: 'MAINTENANCE',
    code: 'MAINTENANCE_DEPOSIT',
    name: 'Maintenance Deposit (Sinking Fund)',
    formulaType: 'AREA_RATE',
    formulaPreview: 'Super Built-Up Area × Deposit Rate',
    referenceBase: 'SUPER_BUILT_UP',
    rateUnit: '₹/sq.ft',
    isRequired: false,
    isActive: true,
    sequence: 22,
    description: 'One-time society maintenance corpus / sinking deposit',
  },

  // 4. Other Charges
  {
    category: 'OTHER_CHARGE',
    code: 'LEGAL_FEE',
    name: 'Legal & Advocate Fees',
    formulaType: 'DOCS_MULTIPLIER',
    formulaPreview: 'Document Count × Fee per Document',
    rateUnit: '₹/doc',
    isRequired: false,
    isActive: true,
    sequence: 31,
    description: 'Legal agreement drafting & document processing fee',
  },
  {
    category: 'OTHER_CHARGE',
    code: 'SOCIETY_FORMATION',
    name: 'Society Formation / Club Membership',
    formulaType: 'FIXED',
    formulaPreview: 'Fixed Amount',
    rateUnit: '₹',
    isRequired: false,
    isActive: true,
    sequence: 32,
    description: 'One-time society registration & club amenities fee',
  },
];

export const pricingComponentService = {
  async list(includeInactive = false) {
    const count = await prisma.erpPricingComponent.count();
    if (count === 0) {
      await prisma.erpPricingComponent.createMany({
        data: DEFAULT_PRICING_COMPONENTS,
      });
    }

    return prisma.erpPricingComponent.findMany({
      where: includeInactive ? {} : { isActive: true },
      orderBy: [{ sequence: 'asc' }, { createdAt: 'asc' }],
    });
  },

  async getById(id: string) {
    const row = await prisma.erpPricingComponent.findUnique({ where: { id } });
    if (!row) throw new Error('Pricing component not found');
    return row;
  },

  async create(body: Record<string, unknown>) {
    const name = String(body.name ?? '').trim();
    if (!name) throw new Error('Component name is required');
    let code = String(body.code ?? '').trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_');
    if (!code) {
      code = name.toUpperCase().replace(/[^A-Z0-9_]/g, '_');
    }
    const category = String(body.category ?? 'BASE_PRICE').trim().toUpperCase();
    const formulaType = String(body.formulaType ?? 'AREA_RATE').trim().toUpperCase();
    const rateUnit = body.rateUnit != null ? String(body.rateUnit).trim() : '₹/sq.ft';
    const defaultRate = dec(body.defaultRate);
    const formulaPreview = body.formulaPreview
      ? String(body.formulaPreview).trim()
      : computeFormulaPreview(formulaType, rateUnit, defaultRate);
    const referenceBase = body.referenceBase ? String(body.referenceBase).trim() : null;
    const sequence = num(body.sequence) != null ? Math.trunc(Number(body.sequence)) : 50;
    const isRequired = Boolean(body.isRequired);
    const isActive = body.isActive !== false;
    const description = body.description != null ? String(body.description).trim() : null;

    return prisma.erpPricingComponent.create({
      data: {
        code,
        name,
        category,
        formulaType,
        formulaPreview,
        referenceBase,
        defaultRate,
        rateUnit,
        isRequired,
        isActive,
        sequence,
        description,
      },
    });
  },

  async update(id: string, body: Record<string, unknown>) {
    await this.getById(id);
    const data: Prisma.ErpPricingComponentUpdateInput = {};

    if (body.name != null) data.name = String(body.name).trim();
    if (body.code != null) {
      data.code = String(body.code).trim().toUpperCase().replace(/[^A-Z0-9_]/g, '_');
    }
    if (body.category != null) {
      data.category = String(body.category).trim().toUpperCase();
    }
    if (body.formulaType != null) {
      data.formulaType = String(body.formulaType).trim().toUpperCase();
    }
    if (body.rateUnit != null) {
      data.rateUnit = String(body.rateUnit).trim();
    }
    if (body.defaultRate !== undefined) {
      data.defaultRate = dec(body.defaultRate);
    }
    if (body.formulaPreview != null) {
      data.formulaPreview = String(body.formulaPreview).trim();
    } else if (body.formulaType != null) {
      data.formulaPreview = computeFormulaPreview(
        String(body.formulaType),
        body.rateUnit ? String(body.rateUnit) : undefined,
        dec(body.defaultRate),
      );
    }
    if (body.referenceBase !== undefined) {
      data.referenceBase = body.referenceBase ? String(body.referenceBase).trim() : null;
    }
    if (body.sequence != null) {
      const s = num(body.sequence);
      if (s != null) data.sequence = Math.trunc(s);
    }
    if (body.isRequired != null) {
      data.isRequired = Boolean(body.isRequired);
    }
    if (body.isActive != null) {
      data.isActive = Boolean(body.isActive);
    }
    if (body.description !== undefined) {
      data.description = body.description ? String(body.description).trim() : null;
    }

    return prisma.erpPricingComponent.update({
      where: { id },
      data,
    });
  },

  async delete(id: string) {
    const row = await this.getById(id);
    if (row.isRequired) {
      throw new Error(`Cannot delete required component: ${row.name}`);
    }
    return prisma.erpPricingComponent.delete({ where: { id } });
  },

  async resetDefaults() {
    await prisma.erpPricingComponent.deleteMany();
    await prisma.erpPricingComponent.createMany({
      data: DEFAULT_PRICING_COMPONENTS,
    });
    return this.list(true);
  },
};
