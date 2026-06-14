import type { User, EmployeePersonalInfo, EmployeeGeneralInfo } from '@prisma/client';
import { decryptPasswordForAdmin } from '../../utils/passwordCrypto';

type UserWithRelations = User & {
  employee?: {
    generalInfo?: Pick<EmployeeGeneralInfo, 'employeeCode' | 'fullName'> | null;
    personalInfo?: Pick<EmployeePersonalInfo, 'birthDate'> | null;
  } | null;
  positionSlot?: { code: string } | null;
};

export function formatDobPassword(birthDate: Date): string {
  const d = String(birthDate.getUTCDate()).padStart(2, '0');
  const m = String(birthDate.getUTCMonth() + 1).padStart(2, '0');
  const y = birthDate.getUTCFullYear();
  return `${d}${m}${y}`;
}

export function resolveLoginId(user: UserWithRelations): string | null {
  return user.username ?? user.employee?.generalInfo?.employeeCode ?? null;
}

/** Password still on default (employee DOB / 01011990) when isFirstLogin is true. */
export function resolveDefaultPassword(user: UserWithRelations): string {
  const dob = user.employee?.personalInfo?.birthDate;
  if (dob) return formatDobPassword(dob);
  return '01011990';
}

export function buildCredentialView(user: UserWithRelations) {
  const loginId = resolveLoginId(user);
  const isAlias = !!user.username && !user.employeeId;
  const accountType = isAlias ? 'ALIAS' : user.employeeId ? 'EMPLOYEE' : 'SYSTEM';

  const stored = decryptPasswordForAdmin(user.adminPasswordEnc);
  let password: string | null = stored;
  let passwordNote: string;

  if (password) {
    passwordNote = 'Current saved password (updated on every set/change).';
  } else if (user.isFirstLogin) {
    if (isAlias) {
      passwordNote =
        'No saved password on file. Use Reset password to set one that admins can view.';
    } else {
      password = resolveDefaultPassword(user);
      passwordNote = user.employee?.personalInfo?.birthDate
        ? 'Default password: date of birth as DDMMYYYY.'
        : 'Default password: 01011990.';
    }
  } else {
    passwordNote =
      'Password was changed before admin storage was enabled. Reset password once to save it for viewing.';
  }

  return {
    userId: user.id,
    loginId,
    accountType,
    isFirstLogin: user.isFirstLogin,
    password,
    passwordNote,
    canLogin: user.isActive && !!loginId,
  };
}
