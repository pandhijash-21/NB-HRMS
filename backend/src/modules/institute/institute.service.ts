import { prisma } from '../../config/prisma';
import { instituteMemberFilters, resolveInstituteRef } from './institute.util';

function normalizeCode(code: string): string {
  return code.trim().toUpperCase().replace(/\s+/g, '_');
}

export const instituteService = {
  async list(options?: { activeOnly?: boolean }) {
    return prisma.institute.findMany({
      where: options?.activeOnly ? { isActive: true } : undefined,
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  },

  async getById(id: string) {
    return prisma.institute.findUnique({ where: { id } });
  },

  async getByCode(code: string) {
    return prisma.institute.findUnique({ where: { code: normalizeCode(code) } });
  },

  async create(data: { code: string; name: string; sortOrder?: number }) {
    const code = normalizeCode(data.code);
    const name = data.name.trim();
    if (!code || !name) throw new Error('Code and name are required');
    if (!/^[A-Z0-9_]+$/.test(code)) {
      throw new Error('Institute code must be uppercase letters, numbers, and underscores');
    }

    const clash = await prisma.institute.findFirst({
      where: { OR: [{ code }, { name }] },
    });
    if (clash) throw new Error('Institute code or name already exists');

    return prisma.institute.create({
      data: { code, name, sortOrder: data.sortOrder ?? 0 },
    });
  },

  async update(id: string, data: { code?: string; name?: string; isActive?: boolean; sortOrder?: number }) {
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
          OR: [
            ...(code ? [{ code }] : []),
            ...(name ? [{ name }] : []),
          ],
        },
      });
      if (clash) throw new Error('Institute code or name already exists');
    }

    return prisma.$transaction(async (tx) => {
      const updated = await tx.institute.update({
        where: { id },
        data: {
          ...(code !== undefined ? { code } : {}),
          ...(name !== undefined ? { name } : {}),
          ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
          ...(data.sortOrder !== undefined ? { sortOrder: data.sortOrder } : {}),
        },
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

      return updated;
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
      // Soft-delete when referenced
      return prisma.institute.update({
        where: { id },
        data: { isActive: false },
      });
    }

    await prisma.institute.delete({ where: { id } });
    return { deleted: true, id, hard: true };
  },

  async getMembers(instituteId: string) {
    const institute = await prisma.institute.findUnique({ where: { id: instituteId } });
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

    return { institute, employees, aliases };
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

  resolveInstituteRef,
};
