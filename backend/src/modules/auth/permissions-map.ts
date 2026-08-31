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

export function isAdminRole(role?: string | null) {
  const r = String(role ?? '')
    .toUpperCase()
    .replace(/\s+/g, '');
  return ['ADMIN', 'SUPERADMIN', 'SYSTEMADMIN'].includes(r);
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
