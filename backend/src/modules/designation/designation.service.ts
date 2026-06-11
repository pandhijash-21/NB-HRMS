import bcrypt from 'bcryptjs';
import { prisma } from '../../config/prisma';

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

export const designationService = {
  async list(filters?: { isAlias?: boolean; activeOnly?: boolean }) {
    return prisma.designation.findMany({
      where: {
        ...(filters?.isAlias !== undefined ? { isAlias: filters.isAlias } : {}),
        ...(filters?.activeOnly ? { isActive: true } : {}),
      },
      include: { linkedRole: { select: { id: true, name: true } } },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  },

  async getById(id: string) {
    return prisma.designation.findUnique({
      where: { id },
      include: { linkedRole: { select: { id: true, name: true } } },
    });
  },

  async create(data: {
    name: string;
    isAlias?: boolean;
    linkedRoleId?: string | null;
    sortOrder?: number;
  }) {
    const slug = slugify(data.name);
    const existing = await prisma.designation.findFirst({
      where: { OR: [{ name: data.name }, { slug }] },
    });
    if (existing) throw new Error('Designation with this name already exists');

    return prisma.designation.create({
      data: {
        name: data.name,
        slug,
        isAlias: data.isAlias ?? false,
        linkedRoleId: data.isAlias ? data.linkedRoleId ?? null : null,
        sortOrder: data.sortOrder ?? 0,
      },
      include: { linkedRole: { select: { id: true, name: true } } },
    });
  },

  async update(
    id: string,
    data: {
      name?: string;
      isAlias?: boolean;
      linkedRoleId?: string | null;
      isActive?: boolean;
      sortOrder?: number;
    },
  ) {
    const current = await prisma.designation.findUnique({ where: { id } });
    if (!current) throw new Error('Designation not found');

    const updateData: Record<string, unknown> = { ...data };
    if (data.name) updateData.slug = slugify(data.name);

    return prisma.designation.update({
      where: { id },
      data: updateData,
      include: { linkedRole: { select: { id: true, name: true } } },
    });
  },

  async listPositionSlots() {
    return prisma.positionSlot.findMany({
      include: {
        designation: true,
        linkedRole: { select: { id: true, name: true } },
        user: { select: { id: true, username: true, isActive: true } },
        assignments: {
          where: { effectiveTo: null },
          include: {
            holderEmployee: {
              include: { generalInfo: { select: { fullName: true } } },
            },
          },
          take: 1,
        },
      },
      orderBy: { code: 'asc' },
    });
  },

  async createPositionSlot(data: {
    code: string;
    name: string;
    designationId: string;
    linkedRoleId: string;
    subOrganization?: string | null;
    password: string;
    createdBy: string;
  }) {
    const designation = await prisma.designation.findUnique({ where: { id: data.designationId } });
    if (!designation?.isAlias) throw new Error('Position slot must use an alias designation');

    const existingCode = await prisma.positionSlot.findUnique({ where: { code: data.code } });
    if (existingCode) throw new Error('Position slot code already exists');

    const existingUser = await prisma.user.findUnique({ where: { username: data.code } });
    if (existingUser) throw new Error('Username already in use');

    const passwordHash = await bcrypt.hash(data.password, 10);

    return prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          username: data.code,
          roleId: data.linkedRoleId,
          subOrganization: data.subOrganization ?? null,
          passwordHash,
          createdBy: data.createdBy,
        },
      });

      return tx.positionSlot.create({
        data: {
          code: data.code,
          name: data.name,
          designationId: data.designationId,
          linkedRoleId: data.linkedRoleId,
          subOrganization: data.subOrganization ?? null,
          userId: user.id,
        },
        include: {
          designation: true,
          linkedRole: { select: { id: true, name: true } },
          user: { select: { id: true, username: true } },
        },
      });
    });
  },

  async assignPositionHolder(
    positionSlotId: string,
    data: { holderEmployeeId: number; effectiveFrom: string; assignedBy: string },
  ) {
    const slot = await prisma.positionSlot.findUnique({ where: { id: positionSlotId } });
    if (!slot) throw new Error('Position slot not found');

    const effectiveFrom = new Date(data.effectiveFrom);

    return prisma.$transaction(async (tx) => {
      await tx.positionAssignment.updateMany({
        where: { positionSlotId, effectiveTo: null },
        data: { effectiveTo: effectiveFrom },
      });

      return tx.positionAssignment.create({
        data: {
          positionSlotId,
          holderEmployeeId: data.holderEmployeeId,
          effectiveFrom,
          assignedBy: data.assignedBy,
        },
        include: {
          holderEmployee: {
            include: { generalInfo: { select: { fullName: true } } },
          },
        },
      });
    });
  },
};
