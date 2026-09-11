import { prisma } from '../../config/prisma';
import type { CreateRoleInput, UpdateRoleInput } from './types';
import { isSuperAdminRole } from '../auth/permissions-map';

function pickDesignationLabel(
  designations: Array<{ name: string; isAlias: boolean }>,
): string | null {
  const job = designations.find((d) => !d.isAlias);
  return job?.name ?? designations[0]?.name ?? null;
}

const roleInclude = {
  _count: { select: { users: { where: { isActive: true } } } },
  permissions: { select: { moduleKey: true, canRead: true, canWrite: true, canApprove: true } },
  designations: {
    where: { isActive: true },
    select: { id: true, name: true, isAlias: true },
    orderBy: [{ isAlias: 'asc' as const }, { name: 'asc' as const }],
  },
};

export const roleService = {
  async list(
    opts?: { positionsOnly?: boolean; designationsOnly?: boolean },
    requesterRole?: string | null,
  ) {
    const isSuperAdmin = isSuperAdminRole(requesterRole);
    const where: {
      isActive?: boolean;
      id?: { in: string[] };
      name?: { notIn?: string[] };
      OR?: Array<Record<string, unknown>>;
    } = { isActive: true };

    if (!isSuperAdmin) {
      where.name = {
        notIn: [
          'SUPERADMIN',
          'Superadmin',
          'superadmin',
          'SYSTEM_ADMIN',
          'SYSTEMADMIN',
          'SYSTEM_ADMINISTRATOR',
          'System Administrator',
          'System Admin',
        ],
      };
    }

    if (opts?.positionsOnly) {
      const positionRoles = await prisma.designation.findMany({
        where: { isAlias: true, isActive: true, linkedRoleId: { not: null } },
        select: { linkedRoleId: true },
      });
      const roleIds = [...new Set(positionRoles.map((p) => p.linkedRoleId!).filter(Boolean))];
      if (roleIds.length === 0) return [];
      where.id = { in: roleIds };
    } else if (opts?.designationsOnly === true) {
      // Roles explicitly tied to a designation, plus single core organization admin role
      const allowedSystemRoles = ['ADMIN', 'EMPLOYEE'];
      where.OR = [
        { designations: { some: { isActive: true } } },
        { name: { in: allowedSystemRoles } },
      ];
    }

    const roles = await prisma.role.findMany({
      where,
      include: roleInclude,
      orderBy: [{ isSystem: 'desc' }, { name: 'asc' }],
    });

    return roles.map((r) => ({
      id:          r.id,
      name:        r.name,
      description: r.description,
      isSystem:    r.isSystem,
      isActive:    r.isActive,
      createdAt:   r.createdAt,
      userCount:   r._count.users,
      positionName: pickDesignationLabel(r.designations),
      permissionSummary: r.permissions.map((p) => p.moduleKey),
    }));
  },

  async getById(id: string) {
    const role = await prisma.role.findUnique({
      where: { id },
      include: {
        permissions: true,
        _count: { select: { users: { where: { isActive: true } } } },
        designations: {
          where: { isActive: true },
          select: { id: true, name: true, isAlias: true },
          orderBy: [{ isAlias: 'asc' }, { name: 'asc' }],
        },
      },
    });
    if (!role) return null;

    const permissionsMap: Record<string, object> = {};
    for (const p of role.permissions) {
      permissionsMap[p.moduleKey] = {
        canRead:    p.canRead,
        canWrite:   p.canWrite,
        canApprove: p.canApprove,
        canDelete:  p.canDelete,
        canExport:  p.canExport,
        employeeViewScope: p.employeeViewScope,
      };
    }

    return {
      id:          role.id,
      name:        role.name,
      description: role.description,
      isSystem:    role.isSystem,
      isActive:    role.isActive,
      createdAt:   role.createdAt,
      userCount:   role._count.users,
      positionName: pickDesignationLabel(role.designations),
      permissions: permissionsMap,
    };
  },

  async create(input: CreateRoleInput, creatorId: string) {
    const name = input.name.trim().toUpperCase().replace(/\s+/g, '_');
    if (!/^[A-Z][A-Z0-9_]*$/.test(name)) {
      return {
        error: 'Role name must be uppercase letters, numbers, and underscores (e.g. HR_MANAGER)',
        status: 400,
      } as const;
    }

    if (['SUPERADMIN', 'SYSTEM_ADMIN', 'SYSTEMADMIN', 'ADMIN'].includes(name)) {
      return {
        error: 'Role name is reserved for core system administrators',
        status: 400,
      } as const;
    }

    const clash = await prisma.role.findUnique({ where: { name } });
    if (clash) return { error: 'Role name already exists', status: 409 } as const;

    const newRole = await prisma.role.create({
      data: {
        name,
        description: input.description?.trim() || null,
        isSystem: false,
        createdBy: creatorId,
      },
    });

    // Populate module permissions: either cloned or defaults for all system modules
    if (input.cloneRoleId) {
      const sourcePerms = await prisma.rolePermission.findMany({
        where: { roleId: input.cloneRoleId },
      });
      if (sourcePerms.length > 0) {
        await prisma.rolePermission.createMany({
          data: sourcePerms.map((p) => ({
            roleId: newRole.id,
            moduleKey: p.moduleKey,
            canRead: p.canRead,
            canWrite: p.canWrite,
            canApprove: p.canApprove,
            canDelete: p.canDelete,
            canExport: p.canExport,
            employeeViewScope: p.employeeViewScope,
            updatedBy: creatorId,
          })),
        });
      }
    } else {
      const modules = await prisma.systemModule.findMany({
        where: { isActive: true },
        select: { key: true },
      });
      if (modules.length > 0) {
        await prisma.rolePermission.createMany({
          data: modules.map((m) => ({
            roleId: newRole.id,
            moduleKey: m.key,
            canRead: true,
            canWrite: false,
            canApprove: false,
            canDelete: false,
            canExport: false,
            employeeViewScope: 'NONE',
            updatedBy: creatorId,
          })),
        });
      }
    }

    return newRole;
  },

  async update(id: string, input: UpdateRoleInput, updaterId: string) {
    const role = await prisma.role.findUnique({ where: { id } });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    if (input.name && input.name !== role.name) {
      if (role.isSystem || ['SUPERADMIN', 'SYSTEM_ADMIN', 'ADMIN', 'EMPLOYEE'].includes(role.name)) {
        return { error: 'Cannot rename a core system role', status: 400 } as const;
      }
      const userCount = await prisma.user.count({ where: { roleId: id, isActive: true } });
      if (userCount > 0) {
        return {
          error: `Cannot rename role: ${userCount} active user(s) assigned`,
          status: 409,
        } as const;
      }
      const clash = await prisma.role.findUnique({ where: { name: input.name } });
      if (clash) return { error: 'Role name already exists', status: 409 } as const;
    }

    return prisma.role.update({
      where: { id },
      data: {
        ...(input.name        ? { name: input.name }               : {}),
        ...(input.description !== undefined ? { description: input.description } : {}),
        updatedBy: updaterId,
      },
    });
  },

  async softDelete(id: string, requesterId: string) {
    const role = await prisma.role.findUnique({
      where: { id },
      include: { designations: { where: { isActive: true }, take: 1 } },
    });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    if (role.isSystem || ['SUPERADMIN', 'SYSTEM_ADMIN', 'ADMIN', 'EMPLOYEE'].includes(role.name)) {
      return { error: 'Cannot delete a core system role', status: 400 } as const;
    }

    if (role.designations.length > 0) {
      return {
        error: 'This role is linked to a designation. Remove or deactivate the designation instead.',
        status: 400,
      } as const;
    }

    const userCount = await prisma.user.count({ where: { roleId: id, isActive: true } });
    if (userCount > 0) {
      return {
        error: `Cannot delete role: ${userCount} active user(s) assigned`,
        status: 409,
      } as const;
    }

    await prisma.role.update({
      where: { id },
      data:  { isActive: false, updatedBy: requesterId },
    });

    return { message: 'Role deactivated' };
  },
};
