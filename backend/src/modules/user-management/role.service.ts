import { prisma } from '../../config/prisma';
import type { CreateRoleInput, UpdateRoleInput } from './types';

export const roleService = {
  async list() {
    const roles = await prisma.role.findMany({
      include: {
        _count: { select: { users: { where: { isActive: true } } } },
        permissions: { select: { moduleKey: true, canRead: true, canWrite: true, canApprove: true } },
      },
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
      permissionSummary: r.permissions.map((p) => p.moduleKey),
    }));
  },

  async getById(id: string) {
    const role = await prisma.role.findUnique({
      where: { id },
      include: {
        permissions: true,
        _count: { select: { users: { where: { isActive: true } } } },
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
      permissions: permissionsMap,
    };
  },

  async create(input: CreateRoleInput, creatorId: string) {
    const existing = await prisma.role.findUnique({ where: { name: input.name } });
    if (existing) return { error: 'Role name already exists', status: 409 } as const;

    return prisma.role.create({
      data: {
        name:        input.name,
        description: input.description,
        createdBy:   creatorId,
      },
    });
  },

  async update(id: string, input: UpdateRoleInput, updaterId: string) {
    const role = await prisma.role.findUnique({ where: { id } });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    if (input.name && input.name !== role.name) {
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
    const role = await prisma.role.findUnique({ where: { id } });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    if (role.isSystem) return { error: 'Cannot delete a system role', status: 400 } as const;

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
