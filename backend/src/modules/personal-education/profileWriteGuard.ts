import type { Request } from 'express';
import { prisma } from '../../config/prisma';

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

export type ProfileWriteModule =
  | 'PERSONAL'
  | 'ADDRESS_LOCAL'
  | 'ADDRESS_PERMANENT'
  | 'OTHER'
  | 'BANK';

export function roleOf(req: Request): string {
  return String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '').toUpperCase();
}

export function isPrivilegedProfileEditor(req: Request): boolean {
  return (PROFILE_DIRECT_WRITE_ROLES as readonly string[]).includes(roleOf(req));
}

function hasText(v: unknown): boolean {
  return typeof v === 'string' && v.trim().length > 0;
}

/**
 * First-time / incomplete sections may be filled directly by the employee.
 * Once the section already has real data, further edits must go through Admin/HR approval.
 */
export async function isProfileModuleBootstrapIncomplete(
  employeeId: number,
  module: ProfileWriteModule,
): Promise<boolean> {
  if (module === 'PERSONAL') {
    const p = await prisma.employeePersonalInfo.findUnique({ where: { employeeId } });
    if (!p) return true;
    return !(
      hasText(p.aadhaarNo) ||
      hasText(p.panNo) ||
      hasText(p.aadhaarCardUrl) ||
      hasText(p.panCardUrl) ||
      hasText(p.birthPlace) ||
      hasText(p.homeTown)
    );
  }

  if (module === 'ADDRESS_LOCAL' || module === 'ADDRESS_PERMANENT') {
    const addressType = module === 'ADDRESS_LOCAL' ? 'LOCAL' : 'PERMANENT';
    const a = await prisma.employeeAddress.findUnique({
      where: { employeeId_addressType: { employeeId, addressType } },
    });
    if (!a) return true;
    return !(
      hasText(a.city) ||
      hasText(a.mobileNo) ||
      hasText(a.area) ||
      hasText(a.flatBlockNo) ||
      hasText(a.zipPostalCode)
    );
  }

  if (module === 'OTHER') {
    const o = await prisma.employeeOtherInfo.findUnique({ where: { employeeId } });
    if (!o) return true;
    return !(
      hasText(o.skillSet) ||
      hasText(o.hobbies) ||
      hasText(o.strength) ||
      hasText(o.weakness) ||
      hasText(o.passportUrl) ||
      o.heightInFeet != null ||
      o.weightInKg != null
    );
  }

  if (module === 'BANK') {
    const b = await prisma.employeeBankInfo.findUnique({ where: { employeeId } });
    if (!b) return true;
    return !(
      hasText(b.bankAccountNo) ||
      hasText(b.ifscCode) ||
      hasText(b.bankName) ||
      hasText(b.cancelledChequeUrl) ||
      hasText(b.passbookUrl)
    );
  }

  return false;
}

/**
 * Employees editing their own profile:
 * - first fill of an incomplete section → direct write OK
 * - later changes → must use POST /approvals
 * Privileged roles may always write directly.
 */
export async function assertMayDirectWriteProfile(
  req: Request,
  targetEmployeeId: number,
  module?: ProfileWriteModule,
) {
  if (isPrivilegedProfileEditor(req)) return;

  const tokenEmployeeId = req.user?.employeeId != null ? Number(req.user.employeeId) : null;
  const isSelf = tokenEmployeeId != null && tokenEmployeeId === targetEmployeeId;
  if (!isSelf) {
    const err: any = new Error('You can only edit your own profile, or use Admin/HR access.');
    err.status = 403;
    throw err;
  }

  if (module && (await isProfileModuleBootstrapIncomplete(targetEmployeeId, module))) {
    return;
  }

  const err: any = new Error(
    'This profile section is already filled. Further changes require Admin/HR approval — submit a change request from the app.',
  );
  err.status = 403;
  throw err;
}

/** Whether an employee upload should persist immediately (first fill) or only return a URL. */
export async function mayPersistEmployeeUpload(
  req: Request,
  employeeId: number,
  alreadyHasUrl: boolean,
): Promise<boolean> {
  if (isPrivilegedProfileEditor(req)) return true;
  const tokenEmployeeId = req.user?.employeeId != null ? Number(req.user.employeeId) : null;
  if (tokenEmployeeId == null || tokenEmployeeId !== employeeId) return false;
  // First upload of an empty slot is OK; replacing an existing file needs approval.
  return !alreadyHasUrl;
}
