import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import type { UpdatePermissionsInput, PatchPermissionInput, CreateModuleInput, UpdateModuleInput } from './types';

import { invalidateRolePermissionCache } from '../auth/permissions-map';
import { sseService } from '../events/sse.service';
import { emitPermissionsUpdated } from '../collaboration/socket';

/** Invalidate all active sessions for every user assigned to a given role and clear permission caches. */
export async function invalidateRoleSessions(roleId: string, moduleKey?: string) {
  invalidateRolePermissionCache(roleId);
  try {
    sseService.broadcast('permissions_updated', {
      roleId,
      moduleKey: moduleKey ?? null,
      at: Date.now(),
    });
  } catch {
    // SSE broadcast skipped if error
  }
  try {
    emitPermissionsUpdated({ roleId, moduleKey: moduleKey ?? null });
  } catch {
    // Socket broadcast skipped if error
  }
  try {
    await connectRedis();
    const userIds = await redis.sMembers(`role_users:${roleId}`);
    if (userIds.length > 0) {
      await Promise.all(userIds.map((uid) => redis.del(`session:${uid}`)));
      await redis.del(`role_users:${roleId}`);
    }
  } catch {
    // Redis unavailable — sessions will expire naturally
  }
}

export function inferCategory(
  key: string,
  explicitCategory?: string | null,
): 'HRMS' | 'CRM' | 'ERP' {
  if (explicitCategory) {
    const up = explicitCategory.trim().toUpperCase();
    if (up === 'HRMS' || up === 'CRM' || up === 'ERP') return up;
  }
  const k = key.trim().toUpperCase();
  if (
    k.startsWith('ERP_') ||
    [
      'PROJECTS',
      'WORK_ORDERS',
      'BOQ',
      'STORE',
      'DPR',
      'TENDERS',
      'TENDER_APPLICATIONS',
      'CONTRACTORS',
      'ERP_CONFIGURATIONS',
    ].includes(k)
  ) {
    return 'ERP';
  }
  if (
    k.startsWith('CRM_') ||
    [
      'CRM',
      'CRM_PRE_SALES',
      'CRM_POST_SALES',
      'CRM_HEADERS',
      'CRM_BIN',
      'CRM_SETTINGS',
      'CRM_DASHBOARD',
    ].includes(k)
  ) {
    return 'CRM';
  }
  return 'HRMS';
}

export const permissionService = {
  async getForRole(roleId: string) {
    const role = await prisma.role.findUnique({ where: { id: roleId } });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    // Return all modules with current flags (defaults to all false if no row exists)
    const modules = await prisma.systemModule.findMany({
      where:   { isActive: true },
      orderBy: { key: 'asc' },
    });

    const existing = await prisma.rolePermission.findMany({ where: { roleId } });
    const permMap = new Map(existing.map((p) => [p.moduleKey, p]));

    return modules.map((mod: any) => {
      const p = permMap.get(mod.key);
      return {
        moduleKey:  mod.key,
        moduleName: mod.name,
        category:   inferCategory(mod.key, mod.category),
        sortOrder:  mod.sortOrder ?? 0,
        canRead:    p?.canRead    ?? false,
        canWrite:   p?.canWrite   ?? false,
        canApprove: p?.canApprove ?? false,
        canDelete:  p?.canDelete  ?? false,
        canExport:  p?.canExport  ?? false,
        employeeViewScope: p?.employeeViewScope ?? 'NONE',
      };
    });
  },

  async replaceForRole(roleId: string, input: UpdatePermissionsInput, updaterId: string) {
    const role = await prisma.role.findUnique({ where: { id: roleId } });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    // Validate all module keys exist
    const validKeys = new Set(
      (await prisma.systemModule.findMany({ select: { key: true } })).map((m) => m.key)
    );
    for (const { moduleKey } of input.permissions) {
      if (!validKeys.has(moduleKey)) {
        return { error: `Unknown module key: ${moduleKey}`, status: 400 } as const;
      }
    }

    await prisma.$transaction([
      prisma.rolePermission.deleteMany({ where: { roleId } }),
      prisma.rolePermission.createMany({
        data: input.permissions.map((p) => ({
          roleId,
          moduleKey:  p.moduleKey,
          canRead:    p.canRead,
          canWrite:   p.canWrite,
          canApprove: p.canApprove,
          canDelete:  p.canDelete,
          canExport:  p.canExport,
          employeeViewScope: p.employeeViewScope ?? 'NONE',
          updatedBy:  updaterId,
        })),
      }),
    ]);

    await invalidateRoleSessions(roleId);

    return permissionService.getForRole(roleId);
  },

  async patchModulePermission(
    roleId: string,
    moduleKey: string,
    input: PatchPermissionInput,
    updaterId: string
  ) {
    const role = await prisma.role.findUnique({ where: { id: roleId } });
    if (!role) return { error: 'Role not found', status: 404 } as const;

    const mod = await prisma.systemModule.findUnique({ where: { key: moduleKey } });
    if (!mod) return { error: `Module ${moduleKey} not found`, status: 404 } as const;

    await prisma.rolePermission.upsert({
      where:  { roleId_moduleKey: { roleId, moduleKey } },
      update: { ...input, updatedBy: updaterId },
      create: {
        roleId,
        moduleKey,
        canRead:    input.canRead    ?? false,
        canWrite:   input.canWrite   ?? false,
        canApprove: input.canApprove ?? false,
        canDelete:  input.canDelete  ?? false,
        canExport:  input.canExport  ?? false,
        employeeViewScope: input.employeeViewScope ?? 'NONE',
        updatedBy:  updaterId,
      },
    });

    await invalidateRoleSessions(roleId, moduleKey);

    return permissionService.getForRole(roleId);
  },

  async listModules() {
    try {
      const rows = await prisma.$queryRawUnsafe<
        Array<{
          key: string;
          name: string;
          description: string | null;
          category: string;
          sort_order: number;
          is_active: boolean;
        }>
      >(`
        SELECT key, name, description, category, sort_order, is_active
        FROM system_modules
        WHERE is_active = true
        ORDER BY category ASC, sort_order ASC, name ASC
      `);

      return rows.map((r) => ({
        key: r.key,
        name: r.name,
        description: r.description,
        category: inferCategory(r.key, r.category),
        sortOrder: r.sort_order ?? 0,
        isActive: r.is_active,
      }));
    } catch {
      const modules = await prisma.systemModule.findMany({
        where:   { isActive: true },
        select:  { key: true, name: true, description: true, isActive: true },
        orderBy: { key: 'asc' },
      });
      return modules.map((m: any) => ({
        key: m.key,
        name: m.name,
        description: m.description,
        category: inferCategory(m.key, m.category),
        sortOrder: m.sortOrder ?? 0,
        isActive: m.isActive,
      }));
    }
  },

  async createModule(input: CreateModuleInput, creatorId: string) {
    const key = input.key.trim().toUpperCase().replace(/\s+/g, '_');
    const existing = await prisma.systemModule.findUnique({ where: { key } });
    if (existing) {
      return { error: `Module with key ${key} already exists`, status: 409 } as const;
    }

    const mod = await prisma.systemModule.create({
      data: {
        key,
        name: input.name.trim(),
        description: input.description?.trim() || null,
        category: input.category ?? 'HRMS',
        sortOrder: input.sortOrder ?? 0,
        isActive: true,
      },
    });

    // Automatically grant full permissions on new module to SUPERADMIN, SYSTEM_ADMIN, and ADMIN
    const adminRoles = await prisma.role.findMany({
      where: { name: { in: ['SUPERADMIN', 'SYSTEM_ADMIN', 'ADMIN'] } },
    });
    for (const r of adminRoles) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: r.id, moduleKey: key } },
        update: { canRead: true, canWrite: true, canApprove: true, canDelete: true, canExport: true, updatedBy: creatorId },
        create: {
          roleId: r.id,
          moduleKey: key,
          canRead: true,
          canWrite: true,
          canApprove: true,
          canDelete: true,
          canExport: true,
          updatedBy: creatorId,
        },
      });
      await invalidateRoleSessions(r.id, key);
    }

    return mod;
  },

  async updateModule(key: string, input: UpdateModuleInput, _updaterId: string) {
    const mod = await prisma.systemModule.findUnique({ where: { key } });
    if (!mod) return { error: `Module ${key} not found`, status: 404 } as const;

    const updated = await prisma.systemModule.update({
      where: { key },
      data: {
        ...(input.name ? { name: input.name.trim() } : {}),
        ...(input.description !== undefined ? { description: input.description?.trim() || null } : {}),
        ...(input.category ? { category: input.category } : {}),
        ...(input.sortOrder !== undefined ? { sortOrder: input.sortOrder } : {}),
        ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
      },
    });

    return updated;
  },

  async deleteModule(key: string, _requesterId: string) {
    const mod = await prisma.systemModule.findUnique({ where: { key } });
    if (!mod) return { error: `Module ${key} not found`, status: 404 } as const;

    await prisma.systemModule.update({
      where: { key },
      data: { isActive: false },
    });

    return { message: `Module ${key} deactivated` };
  },
};
