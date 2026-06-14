import type { ReactNode } from 'react';

export type PermissionMap = Record<string, string[]>;

export function hasPermission(
  perms: PermissionMap | undefined | null,
  module: string,
  action: string,
): boolean {
  return perms?.[module]?.includes(action) ?? false;
}

export function canViewOwnWorkforce(
  perms: PermissionMap | undefined | null,
  employeeViewScope?: string | null,
): boolean {
  return employeeViewScope === 'SELF' && hasPermission(perms, 'PERSONAL_INFO', 'READ');
}

export function canViewWorkforce(
  perms: PermissionMap | undefined | null,
  employeeViewScope?: string | null,
): boolean {
  if (employeeViewScope === 'INSTITUTE' || employeeViewScope === 'UNIVERSITY') return true;
  return false;
}

export function canEditOwnWorkforce(
  perms: PermissionMap | undefined | null,
  employeeViewScope?: string | null,
): boolean {
  return canViewOwnWorkforce(perms, employeeViewScope) && hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
}

export function canEditWorkforce(
  perms: PermissionMap | undefined | null,
  employeeViewScope?: string | null,
): boolean {
  return canViewWorkforce(perms, employeeViewScope) && hasPermission(perms, 'PERSONAL_INFO', 'WRITE');
}

/** Can open the admin portal (management modules — not employee self-service). */
export function canAccessAdminPortal(
  perms: PermissionMap | undefined | null,
  employeeViewScope?: string | null,
): boolean {
  if (canViewWorkforce(perms, employeeViewScope)) return true;
  if (!perms || Object.keys(perms).length === 0) return false;

  const hasManagementModule =
    hasPermission(perms, 'USER_MGMT', 'READ') ||
    hasPermission(perms, 'ROLE_MGMT', 'READ') ||
    hasPermission(perms, 'SALARY', 'READ') ||
    hasPermission(perms, 'PAYROLL', 'READ') ||
    hasPermission(perms, 'REPORTS', 'READ') ||
    hasPermission(perms, 'FIELD_MGMT', 'READ') ||
    hasPermission(perms, 'LEAVE', 'APPROVE');

  if (hasManagementModule) return true;

  // Self-service employees (Staff): personal/leave/attendance access uses the employee portal.
  if (employeeViewScope === 'SELF' || employeeViewScope === 'NONE') {
    return false;
  }

  return (
    hasPermission(perms, 'ATTENDANCE', 'READ') ||
    hasPermission(perms, 'LEAVE', 'WRITE') ||
    hasPermission(perms, 'PERSONAL_INFO', 'WRITE')
  );
}

export function canApproveLeave(perms: PermissionMap | undefined | null): boolean {
  return hasPermission(perms, 'LEAVE', 'APPROVE');
}

export function resolvePostLoginPath(
  perms: PermissionMap | undefined | null,
  role: string,
  employeeViewScope?: string | null,
): string {
  if (canAccessAdminPortal(perms, employeeViewScope)) return '/admin/dashboard';
  if (canApproveLeave(perms)) return '/approvals';
  if (canViewOwnWorkforce(perms, employeeViewScope)) return '/profile';
  if (['HOD', 'HOI', 'REGISTRAR', 'VC', 'HR', 'HR_MANAGER'].includes(role)) {
    return '/approvals';
  }
  return '/dashboard';
}

export type NavItemDef = {
  label: string;
  href: string;
  icon: ReactNode;
  module?: string;
  action?: string;
};

export type NavGroupDef = {
  heading?: string;
  items: NavItemDef[];
};

/** Filter admin sidebar items by the user's role permissions. */
export function filterAdminNav(
  groups: NavGroupDef[],
  perms: PermissionMap | undefined | null,
  employeeViewScope?: string | null,
): NavGroupDef[] {
  return groups
    .map((g) => ({
      ...g,
      items: g.items.filter((item) => {
        if (item.href === '/admin/employees') {
          return canViewWorkforce(perms, employeeViewScope);
        }
        if (!item.module || !item.action) return true;
        return hasPermission(perms, item.module, item.action);
      }),
    }))
    .filter((g) => g.items.length > 0);
}
