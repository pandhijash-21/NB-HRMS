import bcrypt from 'bcryptjs';
import type { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { resolveInstituteRef } from '../institute/institute.util';
import { encryptPasswordForAdmin } from '../../utils/passwordCrypto';
import { grantFullUniversityAccess } from '../user-management/universityAccess.util';

function slugify(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

function roleCodeFromName(name: string): string {
  return slugify(name).toUpperCase();
}

async function copyRolePermissionsFromTemplate(
  tx: Prisma.TransactionClient,
  templateRoleName: string,
  targetRoleId: string,
  updatedBy?: string,
) {
  const template = await tx.role.findUnique({ where: { name: templateRoleName } });
  if (!template) return;

  const perms = await tx.rolePermission.findMany({ where: { roleId: template.id } });
  if (!perms.length) return;

  await tx.rolePermission.createMany({
    data: perms.map((p) => ({
      roleId: targetRoleId,
      moduleKey: p.moduleKey,
      canRead: p.canRead,
      canWrite: p.canWrite,
      canApprove: p.canApprove,
      canDelete: p.canDelete,
      canExport: p.canExport,
      employeeViewScope: p.employeeViewScope,
      updatedBy,
    })),
    skipDuplicates: true,
  });
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
    createdBy?: string;
  }) {
    const slug = slugify(data.name);
    const existing = await prisma.designation.findFirst({
      where: { OR: [{ name: data.name }, { slug }] },
    });
    if (existing) throw new Error('Designation with this name already exists');

    const isAlias = data.isAlias ?? false;
    if (isAlias) {
      throw new Error('Positions are created from Workforce → Create Position, not here.');
    }

    return prisma.$transaction(async (tx) => {
      const roleName = roleCodeFromName(data.name);
      if (!/^[A-Z][A-Z0-9_]*$/.test(roleName)) {
        throw new Error('Could not derive a valid role code from this designation name');
      }

      let role = await tx.role.findUnique({ where: { name: roleName } });
      if (!role) {
        role = await tx.role.create({
          data: {
            name: roleName,
            description: `Permissions for ${data.name}`,
            isSystem: false,
            createdBy: data.createdBy ?? null,
          },
        });
        await copyRolePermissionsFromTemplate(tx, 'EMPLOYEE', role.id, data.createdBy);
      }

      return tx.designation.create({
        data: {
          name: data.name,
          slug,
          isAlias,
          linkedRoleId: role.id,
          sortOrder: data.sortOrder ?? 0,
        },
        include: { linkedRole: { select: { id: true, name: true } } },
      });
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

    if (current.isAlias && data.linkedRoleId === null) {
      throw new Error('Position types cannot remove their linked role');
    }

    const updateData: Record<string, unknown> = { ...data };
    if (data.name) updateData.slug = slugify(data.name);

    const roleChanged =
      current.isAlias &&
      data.linkedRoleId !== undefined &&
      data.linkedRoleId !== current.linkedRoleId &&
      data.linkedRoleId !== null;

    return prisma.$transaction(async (tx) => {
      const updated = await tx.designation.update({
        where: { id },
        data: updateData,
        include: { linkedRole: { select: { id: true, name: true } } },
      });

      if (roleChanged && data.linkedRoleId) {
        const slots = await tx.positionSlot.findMany({
          where: { designationId: id },
          select: { id: true, userId: true },
        });
        await tx.positionSlot.updateMany({
          where: { designationId: id },
          data: { linkedRoleId: data.linkedRoleId },
        });
        const userIds = slots.map((s) => s.userId).filter((uid): uid is string => !!uid);
        if (userIds.length) {
          await tx.user.updateMany({
            where: { id: { in: userIds } },
            data: { roleId: data.linkedRoleId },
          });
        }
      }

      return updated;
    });
  },

  async remove(id: string) {
    const current = await prisma.designation.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            generalInfoRecords: true,
            assignments: true,
            salaryInfoRecords: true,
            positionSlots: true,
            salaryStructureTemplates: true,
          },
        },
      },
    });
    if (!current) throw new Error('Designation not found');
    if (current.isAlias) {
      throw new Error('Position types cannot be deleted here. Deactivate them instead.');
    }

    const inUse =
      current._count.generalInfoRecords +
      current._count.assignments +
      current._count.salaryInfoRecords +
      current._count.positionSlots +
      current._count.salaryStructureTemplates;

    if (inUse > 0) {
      return prisma.designation.update({
        where: { id },
        data: { isActive: false },
        include: { linkedRole: { select: { id: true, name: true } } },
      });
    }

    await prisma.designation.delete({ where: { id } });
    return { deleted: true, id, hard: true };
  },

  /** Creates a position: system role (permissions) + alias designation (for alias account linking). */
  async createPosition(data: {
    displayName: string;
    roleName: string;
    description?: string;
    createdBy: string;
  }) {
    const roleName = data.roleName.trim().toUpperCase().replace(/\s+/g, '_');
    if (!/^[A-Z][A-Z0-9_]*$/.test(roleName)) {
      throw new Error('Role code must be uppercase letters, numbers, and underscores (e.g. HOI)');
    }

    const displayName = data.displayName.trim();
    if (!displayName) throw new Error('Position name is required');

    const slug = slugify(displayName);
    const existingDes = await prisma.designation.findFirst({
      where: { OR: [{ name: displayName }, { slug }] },
    });
    if (existingDes) {
      throw new Error(
        existingDes.isAlias
          ? `Position "${existingDes.name}" already exists`
          : `"${displayName}" is a job designation, not a position. Use a different position name (e.g. Staff, HR Manager).`,
      );
    }

    const existingRole = await prisma.role.findUnique({ where: { name: roleName } });

    if (existingRole) {
      const linkedPosition = await prisma.designation.findFirst({
        where: { isAlias: true, linkedRoleId: existingRole.id },
      });
      if (linkedPosition) {
        throw new Error(
          `Role "${roleName}" is already registered as position "${linkedPosition.name}". Edit it under Roles & Permissions.`,
        );
      }

      return prisma.$transaction(async (tx) => {
        if (data.description?.trim()) {
          await tx.role.update({
            where: { id: existingRole.id },
            data: { description: data.description.trim(), updatedBy: data.createdBy },
          });
        }

        const designation = await tx.designation.create({
          data: {
            name: displayName,
            slug,
            isAlias: true,
            linkedRoleId: existingRole.id,
          },
          include: { linkedRole: { select: { id: true, name: true } } },
        });

        return { role: existingRole, designation, linkedExistingRole: true };
      });
    }

    return prisma.$transaction(async (tx) => {
      const role = await tx.role.create({
        data: {
          name: roleName,
          description: data.description?.trim() || `${displayName} position`,
          createdBy: data.createdBy,
        },
      });

      const designation = await tx.designation.create({
        data: {
          name: displayName,
          slug,
          isAlias: true,
          linkedRoleId: role.id,
        },
        include: { linkedRole: { select: { id: true, name: true } } },
      });

      return { role, designation, linkedExistingRole: false };
    });
  },

  async getPositionSlotById(id: string) {
    return prisma.positionSlot.findUnique({
      where: { id },
      include: {
        designation: true,
        linkedRole: { select: { id: true, name: true } },
        institute: { select: { id: true, code: true, name: true } },
        user: {
          select: {
            id: true,
            username: true,
            isActive: true,
            isFirstLogin: true,
            lastLoginAt: true,
            subOrganization: true,
            createdAt: true,
          },
        },
        assignments: {
          where: { effectiveTo: null },
          include: {
            holderEmployee: {
              include: { generalInfo: { select: { fullName: true, employeeCode: true } } },
            },
          },
          take: 1,
        },
      },
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
    linkedRoleId?: string;
    instituteId?: string | null;
    subOrganization?: string | null;
    password: string;
    createdBy: string;
    grantUniversityAccess?: boolean;
  }) {
    const designation = await prisma.designation.findUnique({
      where: { id: data.designationId },
      include: { linkedRole: { select: { id: true, name: true } } },
    });
    if (!designation?.isAlias) throw new Error('Alias account must be linked to a position type');
    if (!designation.linkedRoleId) {
      throw new Error(
        `Position "${designation.name}" has no linked role. Set permissions on the position type first.`,
      );
    }

    const linkedRoleId = designation.linkedRoleId;
    if (data.linkedRoleId && data.linkedRoleId !== linkedRoleId) {
      throw new Error('Role is inherited from the position type and cannot be overridden');
    }

    const existingCode = await prisma.positionSlot.findUnique({ where: { code: data.code } });
    if (existingCode) throw new Error('Position slot code already exists');

    const existingUser = await prisma.user.findUnique({ where: { username: data.code } });
    if (existingUser) throw new Error('Username already in use');

    const passwordHash = await bcrypt.hash(data.password, 10);
    const instituteRef = await resolveInstituteRef({
      instituteId: data.instituteId,
      subOrganization: data.subOrganization,
    });

    const isUniversityWide = !data.instituteId && !data.subOrganization;

    if (data.grantUniversityAccess) {
      await grantFullUniversityAccess(linkedRoleId, data.createdBy);
    }

    return prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          username: data.code,
          roleId: linkedRoleId,
          subOrganization: isUniversityWide ? null : instituteRef.subOrganization,
          passwordHash,
          adminPasswordEnc: encryptPasswordForAdmin(data.password),
          createdBy: data.createdBy,
        },
      });

      return tx.positionSlot.create({
        data: {
          code: data.code,
          name: data.name,
          designationId: data.designationId,
          linkedRoleId,
          instituteId: isUniversityWide ? null : instituteRef.instituteId,
          subOrganization: isUniversityWide ? null : instituteRef.subOrganization,
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
