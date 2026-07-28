import { prisma } from '../../config/prisma';
import { instituteMemberFilters, resolveInstituteRef } from './institute.util';
import {
  assertRequiredCompanyFields,
  companyProfileToPrismaData,
  parseCompanyProfileFromBody,
  type CompanyProfileInput,
} from '../organization/companyProfile';

function normalizeCode(code: string): string {
  return code.trim().toUpperCase().replace(/\s+/g, '_');
}

function mapInstitute(row: {
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
  isChildCompany: boolean;
  parentOrganizationId: string | null;
  isActive: boolean;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
  parentOrganization?: { id: string; code: string; name: string } | null;
}) {
  const { parentOrganization, ...rest } = row;
  return {
    ...rest,
    createdAt: rest.createdAt.toISOString(),
    updatedAt: rest.updatedAt.toISOString(),
    parentOrganization: parentOrganization
      ? {
          id: parentOrganization.id,
          code: parentOrganization.code,
          name: parentOrganization.name,
        }
      : null,
  };
}

const parentInclude = {
  parentOrganization: { select: { id: true, code: true, name: true } },
} as const;

export type InstituteCreateInput = CompanyProfileInput & {
  code: string;
  name: string;
  sortOrder?: number;
  isChildCompany?: boolean;
  parentOrganizationId?: string | null;
};

export type InstituteUpdateInput = CompanyProfileInput & {
  code?: string;
  name?: string;
  isActive?: boolean;
  sortOrder?: number;
  isChildCompany?: boolean;
  parentOrganizationId?: string | null;
};

async function resolveChildCompany(
  isChildCompany: boolean | undefined,
  parentOrganizationId: string | null | undefined,
  current?: { isChildCompany: boolean; parentOrganizationId: string | null },
) {
  const child =
    isChildCompany !== undefined ? Boolean(isChildCompany) : (current?.isChildCompany ?? false);
  let parentId =
    parentOrganizationId !== undefined
      ? parentOrganizationId
      : (current?.parentOrganizationId ?? null);

  if (!child) {
    parentId = null;
  } else if (!parentId) {
    throw new Error('Parent organization is required when institute is a child company');
  } else {
    const parent = await prisma.organization.findFirst({
      where: { id: parentId, isActive: true },
      select: { id: true },
    });
    if (!parent) throw new Error('Parent organization not found or inactive');
  }

  return { isChildCompany: child, parentOrganizationId: parentId };
}

export const instituteService = {
  async list(options?: { activeOnly?: boolean }) {
    const rows = await prisma.institute.findMany({
      where: options?.activeOnly ? { isActive: true } : undefined,
      include: parentInclude,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
    return rows.map(mapInstitute);
  },

  async getById(id: string) {
    const row = await prisma.institute.findUnique({
      where: { id },
      include: parentInclude,
    });
    return row ? mapInstitute(row) : null;
  },

  async getByCode(code: string) {
    const row = await prisma.institute.findUnique({
      where: { code: normalizeCode(code) },
      include: parentInclude,
    });
    return row ? mapInstitute(row) : null;
  },

  async create(data: InstituteCreateInput) {
    const code = normalizeCode(data.code);
    const name = data.name.trim();
    if (!code || !name) throw new Error('Code and name are required');
    if (!/^[A-Z0-9_]+$/.test(code)) {
      throw new Error('Institute code must be uppercase letters, numbers, and underscores');
    }

    assertRequiredCompanyFields(data, { requireAll: true });
    const child = await resolveChildCompany(data.isChildCompany, data.parentOrganizationId);

    const clash = await prisma.institute.findFirst({
      where: { OR: [{ code }, { name }] },
    });
    if (clash) throw new Error('Institute code or name already exists');

    const profile = companyProfileToPrismaData(data);
    const row = await prisma.institute.create({
      data: {
        code,
        name,
        sortOrder: data.sortOrder ?? 0,
        isChildCompany: child.isChildCompany,
        parentOrganizationId: child.parentOrganizationId,
        ...profile,
      } as Parameters<typeof prisma.institute.create>[0]['data'],
      include: parentInclude,
    });
    return mapInstitute(row);
  },

  async update(id: string, data: InstituteUpdateInput) {
    const current = await prisma.institute.findUnique({ where: { id } });
    if (!current) throw new Error('Institute not found');

    const code = data.code !== undefined ? normalizeCode(data.code) : undefined;
    const name = data.name !== undefined ? data.name.trim() : undefined;

    if (code && !/^[A-Z0-9_]+$/.test(code)) {
      throw new Error('Institute code must be uppercase letters, numbers, and underscores');
    }

    if (code || name) {
      const clash = await prisma.institute.findFirst({
        where: {
          id: { not: id },
          OR: [...(code ? [{ code }] : []), ...(name ? [{ name }] : [])],
        },
      });
      if (clash) throw new Error('Institute code or name already exists');
    }

    const child =
      data.isChildCompany !== undefined || data.parentOrganizationId !== undefined
        ? await resolveChildCompany(data.isChildCompany, data.parentOrganizationId, current)
        : null;

    const profile = companyProfileToPrismaData(data);

    return prisma.$transaction(async (tx) => {
      const updated = await tx.institute.update({
        where: { id },
        data: {
          ...(code !== undefined ? { code } : {}),
          ...(name !== undefined ? { name } : {}),
          ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
          ...(data.sortOrder !== undefined ? { sortOrder: data.sortOrder } : {}),
          ...(child
            ? {
                isChildCompany: child.isChildCompany,
                parentOrganizationId: child.parentOrganizationId,
              }
            : {}),
          ...profile,
        } as Parameters<typeof tx.institute.update>[0]['data'],
        include: parentInclude,
      });

      if (code && code !== current.code) {
        await tx.employeeGeneralInfo.updateMany({
          where: { instituteId: id },
          data: { subOrganization: code },
        });
        await tx.positionSlot.updateMany({
          where: { instituteId: id },
          data: { subOrganization: code },
        });
        await tx.user.updateMany({
          where: { positionSlot: { instituteId: id } },
          data: { subOrganization: code },
        });
      }

      return mapInstitute(updated);
    });
  },

  async remove(id: string) {
    const current = await prisma.institute.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            generalInfoRecords: true,
            positionSlots: true,
            assignments: true,
          },
        },
      },
    });
    if (!current) throw new Error('Institute not found');

    const inUse =
      current._count.generalInfoRecords +
      current._count.positionSlots +
      current._count.assignments;
    if (inUse > 0) {
      return mapInstitute(
        await prisma.institute.update({
          where: { id },
          data: { isActive: false },
          include: parentInclude,
        }),
      );
    }

    await prisma.institute.delete({ where: { id } });
    return { deleted: true, id, hard: true };
  },

  async getMembers(instituteId: string) {
    const institute = await prisma.institute.findUnique({
      where: { id: instituteId },
      include: parentInclude,
    });
    if (!institute) return null;

    const { employeeWhere, aliasWhere } = instituteMemberFilters(institute);

    const [employees, aliases] = await Promise.all([
      prisma.employee.findMany({
        where: employeeWhere,
        include: {
          generalInfo: {
            select: {
              fullName: true,
              employeeCode: true,
              designation: true,
              department: true,
              subOrganization: true,
              instituteId: true,
            },
          },
        },
        orderBy: { id: 'asc' },
      }),
      prisma.positionSlot.findMany({
        where: aliasWhere,
        include: {
          designation: { select: { name: true } },
          linkedRole: { select: { name: true } },
          user: { select: { id: true, username: true, isActive: true } },
        },
        orderBy: { code: 'asc' },
      }),
    ]);

    return { institute: mapInstitute(institute), employees, aliases };
  },

  /** Link legacy sub_organization strings to institute_id after seed/migration. */
  async backfillInstituteLinks() {
    const institutes = await prisma.institute.findMany();
    let general = 0;
    let slots = 0;

    for (const inst of institutes) {
      const g = await prisma.employeeGeneralInfo.updateMany({
        where: {
          instituteId: null,
          subOrganization: { in: [inst.code, inst.name], mode: 'insensitive' },
        },
        data: { instituteId: inst.id, subOrganization: inst.code },
      });
      general += g.count;

      const s = await prisma.positionSlot.updateMany({
        where: {
          instituteId: null,
          OR: [
            { subOrganization: { in: [inst.code, inst.name], mode: 'insensitive' } },
            { code: { endsWith: `-${inst.code}`, mode: 'insensitive' } },
          ],
        },
        data: { instituteId: inst.id, subOrganization: inst.code },
      });
      slots += s.count;
    }

    return { generalInfoUpdated: general, positionSlotsUpdated: slots };
  },

  parseBody(body: Record<string, unknown>) {
    return parseCompanyProfileFromBody(body);
  },

  resolveInstituteRef,
};
