import { prisma } from '../../config/prisma';
import {
  assertRequiredCompanyFields,
  companyProfileToPrismaData,
  parseCompanyProfileFromBody,
  type CompanyProfileInput,
} from './companyProfile';

function normalizeCode(code: string): string {
  return code.trim().toUpperCase().replace(/\s+/g, '_');
}

function mapOrg(row: {
  id: string;
  code: string;
  name: string;
  registrationNo: string | null;
  establishmentYear: number | null;
  contactPerson: string | null;
  mobileNo: string | null;
  contactNo: string | null;
  email: string | null;
  webAddress: string | null;
  panNo: string | null;
  gstNo: string | null;
  cinNo: string | null;
  country: string | null;
  state: string | null;
  city: string | null;
  address1: string | null;
  address2: string | null;
  pinCode: string | null;
  tagLine: string | null;
  hostingUrl: string | null;
  pageSize: string | null;
  dateFormat: string | null;
  timeZone: string | null;
  socialPostUrl: string | null;
  bankName: string | null;
  accountHolderName: string | null;
  bankAccountNo: string | null;
  ifscCode: string | null;
  bankBranch: string | null;
  isActive: boolean;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}) {
  return {
    ...row,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export type OrganizationCreateInput = CompanyProfileInput & {
  code: string;
  name: string;
  sortOrder?: number;
};

export type OrganizationUpdateInput = CompanyProfileInput & {
  code?: string;
  name?: string;
  isActive?: boolean;
  sortOrder?: number;
};

export const organizationService = {
  /** Copy ORGANIZATION lookups into the Organization table if missing.
   *  Employee add-form historically used SystemLookup; Config uses Organization. */
  async syncFromLookups() {
    const lookups = await prisma.systemLookup.findMany({
      where: { category: 'ORGANIZATION' },
    });
    for (const row of lookups) {
      await prisma.organization.upsert({
        where: { code: row.code },
        update: {},
        create: {
          code: row.code,
          name: row.label,
          sortOrder: row.sortOrder,
          isActive: row.isActive,
        },
      });
    }
  },

  async list(options?: { activeOnly?: boolean }) {
    await this.syncFromLookups();
    const rows = await prisma.organization.findMany({
      where: options?.activeOnly ? { isActive: true } : undefined,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
    return rows.map(mapOrg);
  },

  async getById(id: string) {
    const row = await prisma.organization.findUnique({ where: { id } });
    if (!row) throw new Error('Organization not found');
    return mapOrg(row);
  },

  async create(data: OrganizationCreateInput) {
    const code = normalizeCode(data.code);
    const name = data.name.trim();
    if (!code || !name) throw new Error('Code and name are required');
    if (!/^[A-Z0-9_]+$/.test(code)) {
      throw new Error('Organization code must be uppercase letters, numbers, and underscores');
    }

    assertRequiredCompanyFields(data, { requireAll: true });

    const clash = await prisma.organization.findFirst({
      where: { OR: [{ code }, { name }] },
    });
    if (clash) throw new Error('Organization code or name already exists');

    const profile = companyProfileToPrismaData(data);
    const row = await prisma.organization.create({
      data: {
        code,
        name,
        sortOrder: data.sortOrder ?? 0,
        ...profile,
      } as Parameters<typeof prisma.organization.create>[0]['data'],
    });

    // Keep ORGANIZATION lookup in sync for employee dropdowns.
    await prisma.systemLookup.upsert({
      where: { category_code: { category: 'ORGANIZATION', code } },
      update: { label: name, isActive: true },
      create: { category: 'ORGANIZATION', code, label: name, sortOrder: data.sortOrder ?? 0 },
    });

    return mapOrg(row);
  },

  async update(id: string, data: OrganizationUpdateInput) {
    const current = await prisma.organization.findUnique({ where: { id } });
    if (!current) throw new Error('Organization not found');

    const code = data.code !== undefined ? normalizeCode(data.code) : undefined;
    const name = data.name !== undefined ? data.name.trim() : undefined;

    if (code && !/^[A-Z0-9_]+$/.test(code)) {
      throw new Error('Organization code must be uppercase letters, numbers, and underscores');
    }
    if (name !== undefined && !name) throw new Error('Name is required');

    if (code || name) {
      const clash = await prisma.organization.findFirst({
        where: {
          id: { not: id },
          OR: [...(code ? [{ code }] : []), ...(name ? [{ name }] : [])],
        },
      });
      if (clash) throw new Error('Organization code or name already exists');
    }

    const profile = companyProfileToPrismaData(data);
    const row = await prisma.organization.update({
      where: { id },
      data: {
        ...(code !== undefined ? { code } : {}),
        ...(name !== undefined ? { name } : {}),
        ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
        ...(data.sortOrder !== undefined ? { sortOrder: data.sortOrder } : {}),
        ...profile,
      } as Parameters<typeof prisma.organization.update>[0]['data'],
    });

    if (code || name || data.isActive !== undefined) {
      const lookupCode = code ?? current.code;
      await prisma.systemLookup.upsert({
        where: { category_code: { category: 'ORGANIZATION', code: lookupCode } },
        update: {
          ...(name !== undefined ? { label: name } : {}),
          ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
        },
        create: {
          category: 'ORGANIZATION',
          code: lookupCode,
          label: name ?? current.name,
          sortOrder: data.sortOrder ?? current.sortOrder,
          isActive: data.isActive ?? current.isActive,
        },
      });
      if (code && code !== current.code) {
        await prisma.systemLookup.deleteMany({
          where: { category: 'ORGANIZATION', code: current.code },
        });
      }
    }

    return mapOrg(row);
  },

  async remove(id: string) {
    const current = await prisma.organization.findUnique({
      where: { id },
      include: { _count: { select: { childInstitutes: true } } },
    });
    if (!current) throw new Error('Organization not found');

    if (current._count.childInstitutes > 0) {
      return mapOrg(
        await prisma.organization.update({
          where: { id },
          data: { isActive: false },
        }),
      );
    }

    await prisma.organization.delete({ where: { id } });
    await prisma.systemLookup.deleteMany({
      where: { category: 'ORGANIZATION', code: current.code },
    });
    return { deleted: true, id, hard: true };
  },

  parseBody(body: Record<string, unknown>) {
    return parseCompanyProfileFromBody(body);
  },
};
