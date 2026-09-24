import { prisma } from '../../config/prisma';
import {
  buildPermissionsMap,
  invalidateOrgAdminPermissionCache,
  type RolePermissionRow,
} from '../auth/permissions-map';
import { sseService } from '../events/sse.service';
import { emitPermissionsUpdated } from '../collaboration/socket';
import { parseModules } from './platform.service';

const FULL = {
  canRead: true,
  canWrite: true,
  canApprove: true,
  canDelete: true,
  canExport: true,
} as const;

function inferCategory(
  key: string,
  explicitCategory?: string | null,
): 'HRMS' | 'CRM' | 'ERP' | 'COLLABORATION' {
  if (explicitCategory) {
    const up = explicitCategory.trim().toUpperCase();
    if (up === 'HRMS' || up === 'CRM' || up === 'ERP' || up === 'COLLABORATION') return up;
  }
  const k = key.trim().toUpperCase();
  if (
    k.startsWith('COLLAB_') ||
    ['CHAT', 'MEETINGS', 'TASKS', 'ORG_TREE', 'SUPPORT', 'COLLABORATION'].includes(k)
  ) {
    return 'COLLABORATION';
  }
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

export type OrgAdminPatchInput = {
  canRead?: boolean;
  canWrite?: boolean;
  canApprove?: boolean;
  canDelete?: boolean;
  canExport?: boolean;
  employeeViewScope?: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
};

function normalizePermissionFlags(flags: {
  canRead: boolean;
  canWrite: boolean;
  canApprove: boolean;
  canDelete: boolean;
  canExport: boolean;
}) {
  const hasElevated =
    flags.canWrite || flags.canApprove || flags.canDelete || flags.canExport;
  if (hasElevated) flags.canRead = true;
  if (!flags.canRead) {
    flags.canWrite = false;
    flags.canApprove = false;
    flags.canDelete = false;
    flags.canExport = false;
  }
  return flags;
}

function notifyOrgAdminPermissionsUpdated(organizationId: string, moduleKey?: string) {
  invalidateOrgAdminPermissionCache(organizationId);
  try {
    sseService.broadcast('permissions_updated', {
      organizationId,
      moduleKey: moduleKey ?? null,
      at: Date.now(),
    });
  } catch {
    // SSE broadcast skipped if error
  }
  try {
    emitPermissionsUpdated({ roleId: `org:${organizationId}`, moduleKey: moduleKey ?? null });
  } catch {
    // Socket broadcast skipped if error
  }
}

/** Whether a module category is allowed under the org's suite license (+ always COLLABORATION). */
export function isCategoryLicensed(
  category: string,
  enabledModules: string[],
): boolean {
  const cat = category.trim().toUpperCase();
  if (cat === 'COLLABORATION') return true;
  const suites = enabledModules.map((m) => m.trim().toUpperCase());
  return suites.includes(cat);
}

export async function resolveOrganizationIdBySubOrg(
  subOrganization?: string | null,
): Promise<string | null> {
  if (!subOrganization?.trim()) return null;
  const org = await prisma.organization.findFirst({
    where: {
      deletedAt: null,
      OR: [
        { name: { equals: subOrganization.trim(), mode: 'insensitive' } },
        { code: { equals: subOrganization.trim(), mode: 'insensitive' } },
      ],
    },
    select: { id: true },
  });
  return org?.id ?? null;
}

export const orgAdminPermissionService = {
  async getForOrganization(organizationId: string) {
    const org = await prisma.organization.findUnique({ where: { id: organizationId } });
    if (!org || org.deletedAt) return { error: 'Company not found', status: 404 } as const;

    const enabledModules = parseModules(org.tagLine);
    const modules = await prisma.systemModule.findMany({
      where: { isActive: true },
      orderBy: [{ category: 'asc' }, { sortOrder: 'asc' }, { name: 'asc' }],
    });
    const existing = await prisma.organizationAdminPermission.findMany({
      where: { organizationId },
    });
    const permMap = new Map(existing.map((p) => [p.moduleKey, p]));

    return modules
      .map((mod) => {
        const category = inferCategory(mod.key, mod.category);
        const p = permMap.get(mod.key);
        return {
          moduleKey: mod.key,
          moduleName: mod.name,
          description: mod.description,
          category,
          sortOrder: mod.sortOrder ?? 0,
          licensed: isCategoryLicensed(category, enabledModules),
          canRead: p?.canRead ?? false,
          canWrite: p?.canWrite ?? false,
          canApprove: p?.canApprove ?? false,
          canDelete: p?.canDelete ?? false,
          canExport: p?.canExport ?? false,
          employeeViewScope: p?.employeeViewScope ?? 'NONE',
        };
      })
      .filter((row) => row.licensed);
  },

  async patchModule(
    organizationId: string,
    moduleKey: string,
    input: OrgAdminPatchInput,
    updaterId: string,
  ) {
    const org = await prisma.organization.findUnique({ where: { id: organizationId } });
    if (!org || org.deletedAt) return { error: 'Company not found', status: 404 } as const;

    const mod = await prisma.systemModule.findUnique({ where: { key: moduleKey } });
    if (!mod || !mod.isActive) {
      return { error: `Module ${moduleKey} not found`, status: 404 } as const;
    }

    const category = inferCategory(mod.key, mod.category);
    const enabledModules = parseModules(org.tagLine);
    if (!isCategoryLicensed(category, enabledModules)) {
      return {
        error: `Module ${moduleKey} is not available under this company's licensed suites`,
        status: 400,
      } as const;
    }

    const existing = await prisma.organizationAdminPermission.findUnique({
      where: { organizationId_moduleKey: { organizationId, moduleKey } },
    });
    const merged = normalizePermissionFlags({
      canRead: input.canRead ?? existing?.canRead ?? false,
      canWrite: input.canWrite ?? existing?.canWrite ?? false,
      canApprove: input.canApprove ?? existing?.canApprove ?? false,
      canDelete: input.canDelete ?? existing?.canDelete ?? false,
      canExport: input.canExport ?? existing?.canExport ?? false,
    });

    const employeeViewScope =
      input.employeeViewScope ??
      existing?.employeeViewScope ??
      (moduleKey === 'PERSONAL_INFO' ? 'UNIVERSITY' : 'NONE');

    await prisma.organizationAdminPermission.upsert({
      where: { organizationId_moduleKey: { organizationId, moduleKey } },
      update: {
        ...merged,
        employeeViewScope,
        updatedBy: updaterId,
      },
      create: {
        organizationId,
        moduleKey,
        ...merged,
        employeeViewScope,
        updatedBy: updaterId,
      },
    });

    notifyOrgAdminPermissionsUpdated(organizationId, moduleKey);
    return orgAdminPermissionService.getForOrganization(organizationId);
  },

  async batchSetCategory(
    organizationId: string,
    categoryFilter: string,
    enable: boolean,
    updaterId: string,
  ) {
    const org = await prisma.organization.findUnique({ where: { id: organizationId } });
    if (!org || org.deletedAt) return { error: 'Company not found', status: 404 } as const;

    const enabledModules = parseModules(org.tagLine);
    const modules = await prisma.systemModule.findMany({ where: { isActive: true } });
    const filter = categoryFilter.trim().toUpperCase();
    const flags = enable ? { ...FULL } : {
      canRead: false,
      canWrite: false,
      canApprove: false,
      canDelete: false,
      canExport: false,
    };

    for (const mod of modules) {
      const category = inferCategory(mod.key, mod.category);
      if (!isCategoryLicensed(category, enabledModules)) continue;
      if (filter !== 'ALL' && category !== filter) continue;

      await prisma.organizationAdminPermission.upsert({
        where: { organizationId_moduleKey: { organizationId, moduleKey: mod.key } },
        update: {
          ...flags,
          ...(enable && mod.key === 'PERSONAL_INFO'
            ? { employeeViewScope: 'UNIVERSITY' as const }
            : {}),
          updatedBy: updaterId,
        },
        create: {
          organizationId,
          moduleKey: mod.key,
          ...flags,
          employeeViewScope: mod.key === 'PERSONAL_INFO' ? 'UNIVERSITY' : 'NONE',
          updatedBy: updaterId,
        },
      });
    }

    notifyOrgAdminPermissionsUpdated(organizationId);
    return orgAdminPermissionService.getForOrganization(organizationId);
  },

  /** Seed full admin access for licensed suites + COLLABORATION (onboard / backfill). */
  async seedForOrganization(
    organizationId: string,
    enabledModules: string[],
    creatorId?: string,
  ) {
    const modules = await prisma.systemModule.findMany({ where: { isActive: true } });
    for (const mod of modules) {
      const category = inferCategory(mod.key, mod.category);
      if (!isCategoryLicensed(category, enabledModules)) continue;

      await prisma.organizationAdminPermission.upsert({
        where: { organizationId_moduleKey: { organizationId, moduleKey: mod.key } },
        update: {},
        create: {
          organizationId,
          moduleKey: mod.key,
          ...FULL,
          employeeViewScope: mod.key === 'PERSONAL_INFO' ? 'UNIVERSITY' : 'NONE',
          updatedBy: creatorId ?? null,
        },
      });
    }
    notifyOrgAdminPermissionsUpdated(organizationId);
  },

  /** Revoke org-admin flags for modules outside current suite licenses. */
  async trimUnlicensed(organizationId: string, enabledModules: string[]) {
    const modules = await prisma.systemModule.findMany({ where: { isActive: true } });
    const unlicensedKeys = modules
      .filter((m) => !isCategoryLicensed(inferCategory(m.key, m.category), enabledModules))
      .map((m) => m.key);

    if (unlicensedKeys.length === 0) return;

    await prisma.organizationAdminPermission.deleteMany({
      where: {
        organizationId,
        moduleKey: { in: unlicensedKeys },
      },
    });
    notifyOrgAdminPermissionsUpdated(organizationId);
  },

  /** Raw rows for auth map building. */
  async listRows(organizationId: string): Promise<RolePermissionRow[]> {
    const rows = await prisma.organizationAdminPermission.findMany({
      where: { organizationId },
    });
    return rows.map((r) => ({
      moduleKey: r.moduleKey,
      canRead: r.canRead,
      canWrite: r.canWrite,
      canApprove: r.canApprove,
      canDelete: r.canDelete,
      canExport: r.canExport,
      employeeViewScope: r.employeeViewScope,
    }));
  },

  /**
   * Assert a granter may grant the given flags on moduleKey.
   * Returns null if allowed, or an error object.
   */
  assertGrantAllowed(
    granterMap: Record<string, string[]>,
    moduleKey: string,
    desired: {
      canRead?: boolean;
      canWrite?: boolean;
      canApprove?: boolean;
      canDelete?: boolean;
      canExport?: boolean;
    },
  ): { error: string; status: number } | null {
    const held = granterMap[moduleKey] ?? [];
    const checks: Array<[keyof typeof desired, string]> = [
      ['canRead', 'READ'],
      ['canWrite', 'WRITE'],
      ['canApprove', 'APPROVE'],
      ['canDelete', 'DELETE'],
      ['canExport', 'EXPORT'],
    ];
    for (const [flag, action] of checks) {
      if (desired[flag] === true && !held.includes(action)) {
        return {
          error: `You cannot grant ${action} on ${moduleKey} because your company admin access does not include it`,
          status: 403,
        };
      }
    }
    return null;
  },
};

export async function loadOrgAdminPermissionMap(
  organizationId: string,
): Promise<{
  permissions: Record<string, string[]>;
  employeeViewScope: RolePermissionRow['employeeViewScope'];
}> {
  const rows = await orgAdminPermissionService.listRows(organizationId);
  const permissions = buildPermissionsMap(rows);
  const personal = rows.find((p) => p.moduleKey === 'PERSONAL_INFO');
  let employeeViewScope = personal?.employeeViewScope ?? 'NONE';

  // Cascade: company admins who can manage users always get workforce directory access.
  // Fixes tenants where Admin Access granted USER_MGMT but not PERSONAL_INFO.
  const hasUserMgmt = (permissions.USER_MGMT ?? []).includes('READ');
  if (hasUserMgmt && !(permissions.PERSONAL_INFO ?? []).includes('READ')) {
    permissions.PERSONAL_INFO = [
      ...new Set([...(permissions.PERSONAL_INFO ?? []), 'READ', 'WRITE', 'DELETE']),
    ];
  }

  if (employeeViewScope === 'NONE' || employeeViewScope === 'SELF') {
    // Admins with PERSONAL_INFO read still get a sensible default for workforce directory
    if ((permissions.PERSONAL_INFO ?? []).includes('READ')) {
      employeeViewScope = 'UNIVERSITY';
    }
  }
  return { permissions, employeeViewScope };
}
