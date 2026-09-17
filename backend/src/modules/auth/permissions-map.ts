import { prisma } from '../../config/prisma';

export type RolePermissionRow = {
  moduleKey: string;
  canRead: boolean;
  canWrite: boolean;
  canApprove: boolean;
  canDelete: boolean;
  canExport: boolean;
  employeeViewScope?: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
};

/** Build the { MODULE_KEY: ['READ','WRITE', ...] } permissions map from DB rows. */
export function buildPermissionsMap(
  permissions: RolePermissionRow[],
): Record<string, string[]> {
  const map: Record<string, string[]> = {};
  for (const p of permissions) {
    const actions: string[] = [];
    if (p.canRead) actions.push('READ');
    if (p.canWrite) actions.push('WRITE');
    if (p.canApprove) actions.push('APPROVE');
    if (p.canDelete) actions.push('DELETE');
    if (p.canExport) actions.push('EXPORT');
    map[p.moduleKey] = actions;
  }
  return map;
}

export function isSuperAdminRole(role?: string | null): boolean {
  const r = String(role ?? '')
    .toUpperCase()
    .replace(/[\s_-]+/g, '');
  return r === 'SUPERADMIN';
}

export function isSystemAdminRole(role?: string | null): boolean {
  const r = String(role ?? '')
    .toUpperCase()
    .replace(/[\s_-]+/g, '');
  return r === 'SYSTEMADMIN' || r === 'SYSTEMADMINISTRATOR' || r === 'ADMIN';
}

export function isAdminRole(role?: string | null): boolean {
  return isSuperAdminRole(role) || isSystemAdminRole(role);
}

/** Tenant System Admin privileges, including Super Admin grants that keep designation. */
export function hasCompanyAdminPrivileges(
  role?: string | null,
  companyAdminGranted?: boolean | null,
): boolean {
  if (isSuperAdminRole(role)) return false;
  return isSystemAdminRole(role) || companyAdminGranted === true;
}

/** Overlay ADMIN for privilege checks without changing the stored designation role. */
export function effectiveCompanyAdminRoleName(
  roleName?: string | null,
  companyAdminGranted?: boolean | null,
): string {
  const name = roleName ?? 'EMPLOYEE';
  if (hasCompanyAdminPrivileges(name, companyAdminGranted) && !isSystemAdminRole(name)) {
    return 'ADMIN';
  }
  return name;
}

export function canCreateAdmins(role?: string | null): boolean {
  return isSuperAdminRole(role);
}

const rolePermCache = new Map<
  string,
  { at: number; perms: Record<string, string[]>; employeeViewScope: RolePermissionRow['employeeViewScope'] }
>();
const orgAdminPermCache = new Map<
  string,
  { at: number; perms: Record<string, string[]>; employeeViewScope: RolePermissionRow['employeeViewScope'] }
>();
const ROLE_PERM_TTL_MS = 15_000;

export function invalidateRolePermissionCache(roleId?: string) {
  if (roleId) rolePermCache.delete(roleId);
  else rolePermCache.clear();
}

export function invalidateOrgAdminPermissionCache(organizationId?: string) {
  if (organizationId) orgAdminPermCache.delete(organizationId);
  else orgAdminPermCache.clear();
}

/** Live role permissions (seed/role edits apply without forcing a new login). */
export async function permissionsForRole(roleId: string): Promise<{
  permissions: Record<string, string[]>;
  employeeViewScope: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
} | null> {
  const hit = rolePermCache.get(roleId);
  if (hit && Date.now() - hit.at < ROLE_PERM_TTL_MS) {
    return { permissions: hit.perms, employeeViewScope: hit.employeeViewScope ?? 'NONE' };
  }
  const role = await prisma.role.findUnique({
    where: { id: roleId },
    include: { permissions: true },
  });
  if (!role) return null;
  const perms = buildPermissionsMap(role.permissions);
  const personal = role.permissions.find((p) => p.moduleKey === 'PERSONAL_INFO');
  let employeeViewScope = personal?.employeeViewScope ?? 'NONE';
  // Only Superadmin gets forced university scope; tenant ADMIN uses org matrix scope.
  if (isSuperAdminRole(role.name)) {
    if (employeeViewScope === 'NONE' || employeeViewScope === 'SELF') {
      employeeViewScope = 'UNIVERSITY';
    }
  }
  rolePermCache.set(roleId, { at: Date.now(), perms, employeeViewScope });
  return { permissions: perms, employeeViewScope };
}

/** Live per-company System Admin capabilities. */
export async function permissionsForOrganizationAdmin(organizationId: string): Promise<{
  permissions: Record<string, string[]>;
  employeeViewScope: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
} | null> {
  const hit = orgAdminPermCache.get(organizationId);
  if (hit && Date.now() - hit.at < ROLE_PERM_TTL_MS) {
    return { permissions: hit.perms, employeeViewScope: hit.employeeViewScope ?? 'NONE' };
  }
  const rows = await prisma.organizationAdminPermission.findMany({
    where: { organizationId },
  });
  const perms = buildPermissionsMap(rows);

  // Cascade: USER_MGMT implies workforce directory (PERSONAL_INFO) for company admins.
  if ((perms.USER_MGMT ?? []).includes('READ') && !(perms.PERSONAL_INFO ?? []).includes('READ')) {
    perms.PERSONAL_INFO = [
      ...new Set([...(perms.PERSONAL_INFO ?? []), 'READ', 'WRITE', 'DELETE']),
    ];
  }

  const personal = rows.find((p) => p.moduleKey === 'PERSONAL_INFO');
  let employeeViewScope = personal?.employeeViewScope ?? 'NONE';
  if (
    (employeeViewScope === 'NONE' || employeeViewScope === 'SELF') &&
    (perms.PERSONAL_INFO ?? []).includes('READ')
  ) {
    employeeViewScope = 'UNIVERSITY';
  }
  orgAdminPermCache.set(organizationId, { at: Date.now(), perms, employeeViewScope });
  return { permissions: perms, employeeViewScope };
}

/** Resolve org + org-admin permissions for a System Admin user by subOrganization. */
export async function resolveSystemAdminPermissions(
  subOrganization?: string | null,
): Promise<{
  organizationId: string | null;
  permissions: Record<string, string[]>;
  employeeViewScope: 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';
} | null> {
  if (!subOrganization?.trim()) {
    return { organizationId: null, permissions: {}, employeeViewScope: 'NONE' };
  }
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
  if (!org) {
    return { organizationId: null, permissions: {}, employeeViewScope: 'NONE' };
  }
  const live = await permissionsForOrganizationAdmin(org.id);
  return {
    organizationId: org.id,
    permissions: live?.permissions ?? {},
    employeeViewScope: live?.employeeViewScope ?? 'NONE',
  };
}

const userRoleCache = new Map<string, {
  roleId: string;
  roleName: string;
  companyAdminGranted: boolean;
  at: number;
}>();
const USER_ROLE_TTL_MS = 15_000;

export function invalidateUserRoleCache(userId?: string) {
  if (userId) userRoleCache.delete(userId);
  else userRoleCache.clear();
}

/** Resolves live user role so designation/role switches apply immediately. */
export async function getLiveUserRole(userId: string): Promise<{
  roleId: string;
  roleName: string;
  companyAdminGranted: boolean;
} | null> {
  const hit = userRoleCache.get(userId);
  if (hit && Date.now() - hit.at < USER_ROLE_TTL_MS) {
    return {
      roleId: hit.roleId,
      roleName: hit.roleName,
      companyAdminGranted: hit.companyAdminGranted,
    };
  }
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { roleId: true, companyAdminGranted: true, role: { select: { name: true } } },
  });
  if (!user) return null;
  const dbRole = user.role?.name ?? 'EMPLOYEE';
  const companyAdminGranted = user.companyAdminGranted === true;
  const res = {
    roleId: user.roleId,
    roleName: effectiveCompanyAdminRoleName(dbRole, companyAdminGranted),
    companyAdminGranted,
  };
  userRoleCache.set(userId, { ...res, at: Date.now() });
  return res;
}
