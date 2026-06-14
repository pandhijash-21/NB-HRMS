import { prisma } from '../../config/prisma';
import { invalidateRoleSessions } from './permission.service';

const FULL = {
  canRead: true,
  canWrite: true,
  canApprove: true,
  canDelete: true,
  canExport: true,
};

const MODULE_KEYS = [
  'PERSONAL_INFO',
  'EDUCATION',
  'LEAVE',
  'PAYROLL',
  'SALARY',
  'ATTENDANCE',
  'BANK_DETAILS',
  'DOCUMENTS',
  'REPORTS',
  'USER_MGMT',
  'ROLE_MGMT',
  'FIELD_MGMT',
] as const;

/** Grant full university-wide admin capabilities to a role (IT Admin, IT Engineer, etc.). */
export async function grantFullUniversityAccess(roleId: string, updatedBy: string) {
  const role = await prisma.role.findUnique({ where: { id: roleId } });
  if (!role) throw new Error('Role not found');

  await prisma.$transaction(
    MODULE_KEYS.map((moduleKey) =>
      prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId, moduleKey } },
        update: {
          ...FULL,
          ...(moduleKey === 'PERSONAL_INFO' ? { employeeViewScope: 'UNIVERSITY' as const } : {}),
          updatedBy,
        },
        create: {
          roleId,
          moduleKey,
          ...FULL,
          employeeViewScope: moduleKey === 'PERSONAL_INFO' ? 'UNIVERSITY' : 'NONE',
          updatedBy,
        },
      }),
    ),
  );

  await invalidateRoleSessions(roleId);
}
