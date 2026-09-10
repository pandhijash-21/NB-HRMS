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

export function canCreateAdmins(role?: string | null): boolean {
  return isSuperAdminRole(role);
}

const rolePermCache = new Map<
  string,
  { at: number; perms: Record<string, string[]>; employeeViewScope: RolePermissionRow['employeeViewScope'] }
>();
const ROLE_PERM_TTL_MS = 15_000;

export function invalidateRolePermissionCache(roleId?: string) {
  if (roleId) rolePermCache.delete(roleId);
  else rolePermCache.clear();
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
  const employeeViewScope = personal?.employeeViewScope ?? 'NONE';
  rolePermCache.set(roleId, { at: Date.now(), perms, employeeViewScope });
  return { permissions: perms, employeeViewScope };
}

const userRoleCache = new Map<string, { roleId: string; roleName: string; at: number }>();
const USER_ROLE_TTL_MS = 15_000;

export function invalidateUserRoleCache(userId?: string) {
  if (userId) userRoleCache.delete(userId);
  else userRoleCache.clear();
}

/** Resolves live user role so designation/role switches apply immediately. */
export async function getLiveUserRole(userId: string): Promise<{ roleId: string; roleName: string } | null> {
  const hit = userRoleCache.get(userId);
  if (hit && Date.now() - hit.at < USER_ROLE_TTL_MS) {
    return { roleId: hit.roleId, roleName: hit.roleName };
  }
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { roleId: true, role: { select: { name: true } } },
  });
  if (!user) return null;
  const res = { roleId: user.roleId, roleName: user.role?.name ?? 'EMPLOYEE' };
  userRoleCache.set(userId, { ...res, at: Date.now() });
  return res;
}
