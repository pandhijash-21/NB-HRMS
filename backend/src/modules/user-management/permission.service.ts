import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import type { UpdatePermissionsInput, PatchPermissionInput } from './types';

/** Invalidate all active sessions for every user assigned to a given role. */
export async function invalidateRoleSessions(roleId: string) {
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

    return modules.map((mod) => {
      const p = permMap.get(mod.key);
      return {
        moduleKey:  mod.key,
        moduleName: mod.name,
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

    await invalidateRoleSessions(roleId);

    return permissionService.getForRole(roleId);
  },

  async listModules() {
    return prisma.systemModule.findMany({
      where:   { isActive: true },
      select:  { key: true, name: true, description: true, isActive: true },
      orderBy: { key: 'asc' },
    });
  },
};
