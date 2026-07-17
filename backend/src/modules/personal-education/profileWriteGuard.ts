import type { Request } from 'express';

/** Roles that may write profile data immediately without a ChangeRequest. */
export const PROFILE_DIRECT_WRITE_ROLES = [
  'ADMIN',
  'SUPER_ADMIN',
  'HR',
  'HR_MANAGER',
  'HOI',
  'REGISTRAR',
  'VC',
] as const;

export function roleOf(req: Request): string {
  return String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '').toUpperCase();
}

export function isPrivilegedProfileEditor(req: Request): boolean {
  return (PROFILE_DIRECT_WRITE_ROLES as readonly string[]).includes(roleOf(req));
}

/**
 * Employees editing their own profile must use POST /approvals.
 * Privileged roles (and admins editing others) may write directly.
 */
export function assertMayDirectWriteProfile(req: Request, targetEmployeeId: number) {
  if (isPrivilegedProfileEditor(req)) return;
  const tokenEmployeeId = req.user?.employeeId != null ? Number(req.user.employeeId) : null;
  const isSelf = tokenEmployeeId != null && tokenEmployeeId === targetEmployeeId;
  if (isSelf) {
    const err: any = new Error(
      'Profile changes require HR approval. Submit a change request from the app instead of saving directly.',
    );
    err.status = 403;
    throw err;
  }
}
