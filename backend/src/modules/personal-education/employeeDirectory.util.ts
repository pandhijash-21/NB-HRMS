import { prisma } from '../../config/prisma';
import { resolveInstituteRef } from '../institute/institute.util';

export type EmployeeViewScope = 'NONE' | 'SELF' | 'INSTITUTE' | 'UNIVERSITY';

type AuthUser = {
  id?: string;
  employeeId?: number | null;
  subOrganization?: string | null;
  employeeViewScope?: EmployeeViewScope;
  permissions?: Record<string, string[]>;
};

export function getEmployeeViewScope(user: AuthUser | undefined): EmployeeViewScope {
  return user?.employeeViewScope ?? 'NONE';
}

export function canViewEmployeeDirectory(user: AuthUser | undefined): boolean {
  const scope = getEmployeeViewScope(user);
  return scope === 'INSTITUTE' || scope === 'UNIVERSITY';
}

export function canViewOwnEmployeeRecord(user: AuthUser | undefined): boolean {
  const scope = getEmployeeViewScope(user);
  return scope === 'SELF' && user?.employeeId != null;
}

export function canWriteEmployeeDirectory(user: AuthUser | undefined): boolean {
  if (!canViewEmployeeDirectory(user)) return false;
  return user?.permissions?.PERSONAL_INFO?.includes('WRITE') ?? false;
}

export function canWriteOwnEmployeeRecord(user: AuthUser | undefined): boolean {
  if (!canViewOwnEmployeeRecord(user)) return false;
  return user?.permissions?.PERSONAL_INFO?.includes('WRITE') ?? false;
}

/** Institute code/name filter for list queries when scope is INSTITUTE. */
export async function resolveDirectoryInstituteFilter(
  user: AuthUser | undefined,
): Promise<string | undefined> {
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
