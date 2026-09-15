import { prisma } from '../../config/prisma';
import { resolveInstituteRef } from '../institute/institute.util';
import { isSuperAdminRole, isSystemAdminRole } from '../auth/permissions-map';

export type EmployeeViewScope = 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';

type AuthUser = {
  id?: string;
  employeeId?: number | null;
  subOrganization?: string | null;
  employeeViewScope?: EmployeeViewScope;
  permissions?: Record<string, string[]>;
  role?: string;
  roleName?: string;
};

export function isAdministrativeRole(roleName?: string): boolean {
  const r = String(roleName ?? '').toUpperCase().replace(/[\s_-]/g, '');
  // SUPERADMIN + HR tiers — tenant ADMIN uses org matrix (see canViewEmployeeDirectory).
  return ['SUPERADMIN', 'HR', 'HRMANAGER', 'DEVELOPER'].includes(r);
}

export function getEmployeeViewScope(user: AuthUser | undefined): EmployeeViewScope {
  if (isSuperAdminRole(user?.role || user?.roleName)) return 'UNIVERSITY';
  if (isAdministrativeRole(user?.role || user?.roleName)) return 'UNIVERSITY';
  if (isSystemAdminRole(user?.role || user?.roleName)) {
    const scope = user?.employeeViewScope ?? 'NONE';
    if (scope === 'INSTITUTE' || scope === 'UNIVERSITY') return scope;
    const perms = user?.permissions ?? {};
    if ((perms.PERSONAL_INFO ?? []).includes('READ') || (perms.USER_MGMT ?? []).includes('READ')) {
      return 'UNIVERSITY';
    }
  }
  return user?.employeeViewScope ?? 'NONE';
}

export function canViewEmployeeDirectory(user: AuthUser | undefined): boolean {
  if (isSuperAdminRole(user?.role || user?.roleName)) return true;
  if (isAdministrativeRole(user?.role || user?.roleName)) return true;

  const perms = user?.permissions ?? {};
  const hasPersonalRead = (perms.PERSONAL_INFO ?? []).includes('READ');
  const hasUserMgmt = (perms.USER_MGMT ?? []).includes('READ');

  if (isSystemAdminRole(user?.role || user?.roleName)) {
    // Company System Admin: matrix PERSONAL_INFO, or USER_MGMT cascade for workforce.
    if (hasPersonalRead || hasUserMgmt) return true;
  }

  if (!hasPersonalRead) return false;
  const scope = getEmployeeViewScope(user);
  return scope === 'INSTITUTE' || scope === 'UNIVERSITY';
}

export function canViewOwnEmployeeRecord(user: AuthUser | undefined): boolean {
  const scope = getEmployeeViewScope(user);
  return scope === 'SELF' && user?.employeeId != null;
}

export function canWriteEmployeeDirectory(user: AuthUser | undefined): boolean {
  if (isSuperAdminRole(user?.role || user?.roleName)) return true;
  if (isAdministrativeRole(user?.role || user?.roleName)) return true;
  if (!canViewEmployeeDirectory(user)) return false;
  const perms = user?.permissions ?? {};
  if ((perms.PERSONAL_INFO ?? []).includes('WRITE')) return true;
  // Cascade: user managers can maintain directory when PERSONAL_INFO write wasn't seeded.
  if (isSystemAdminRole(user?.role || user?.roleName) && (perms.USER_MGMT ?? []).includes('WRITE')) {
    return true;
  }
  return false;
}

export function canWriteOwnEmployeeRecord(user: AuthUser | undefined): boolean {
  if (!canViewOwnEmployeeRecord(user)) return false;
  return user?.permissions?.PERSONAL_INFO?.includes('WRITE') ?? false;
}

/** Institute code/name filter for list queries when scope is INSTITUTE or tenant scoped. */
export async function resolveDirectoryInstituteFilter(
  user: AuthUser | undefined,
): Promise<string | undefined> {
  // Full-directory roles / company System Admin with university-level effective scope
  if (isAdministrativeRole(user?.role || user?.roleName)) {
    return undefined;
  }
  if (isSystemAdminRole(user?.role || user?.roleName)) {
    const scope = getEmployeeViewScope(user);
    if (scope === 'UNIVERSITY' || scope === 'NONE') {
      // NONE here already failed canView; UNIVERSITY = whole company
      if (scope === 'UNIVERSITY') return undefined;
    }
  }

  if (getEmployeeViewScope(user) !== 'INSTITUTE') return undefined;

  const direct = user?.subOrganization?.trim();
  if (direct) return direct;

  if (!user?.id) return '__NO_INSTITUTE_SCOPE__';

  const slot = await prisma.positionSlot.findFirst({
    where: { userId: user.id },
    include: { institute: { select: { code: true, name: true } } },
  });
  if (slot?.institute?.code) return slot.institute.code;
  if (slot?.subOrganization) return slot.subOrganization;

  return '__NO_INSTITUTE_SCOPE__';
}

export async function employeeMatchesDirectoryScope(
  employeeId: number,
  user: AuthUser | undefined,
): Promise<boolean> {
  if (isAdministrativeRole(user?.role || user?.roleName)) return true;
  if (isSuperAdminRole(user?.role || user?.roleName)) return true;
  const scope = getEmployeeViewScope(user);
  if (scope === 'NONE') return false;
  if (scope === 'SELF') {
    return user?.employeeId != null && user.employeeId === employeeId;
  }
  if (scope === 'UNIVERSITY') return true;

  const instituteFilter = await resolveDirectoryInstituteFilter(user);
  if (!instituteFilter || instituteFilter === '__NO_INSTITUTE_SCOPE__') return false;

  const employee = await prisma.employee.findUnique({
    where: { id: employeeId },
    include: {
      generalInfo: {
        include: { institute: { select: { id: true, code: true, name: true } } },
      },
    },
  });
  if (!employee?.generalInfo) return false;

  const gi = employee.generalInfo;
  const ref = await resolveInstituteRef({
    instituteId: gi.instituteId,
    subOrganization: gi.subOrganization,
  });

  const empCode = ref.institute?.code ?? gi.subOrganization ?? '';
  const filter = instituteFilter.toLowerCase();
  return (
    empCode.toLowerCase() === filter ||
    (ref.institute?.name?.toLowerCase() === filter) ||
    (gi.subOrganization?.toLowerCase() === filter)
  );
}
