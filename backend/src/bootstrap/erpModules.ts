import { prisma } from '../config/prisma';

const ERP_MODULE_KEYS = ['PROJECTS', 'WORK_ORDERS'] as const;

const FULL = {
  canRead: true,
  canWrite: true,
  canApprove: true,
  canDelete: true,
  canExport: true,
};

const EMPLOYEE_RO = {
  canRead: true,
  canWrite: false,
  canApprove: false,
  canDelete: false,
  canExport: false,
};

/** Idempotent: ensure ERP modules + admin write perms exist (prod never runs full seed). */
export async function ensureErpModulePermissions(): Promise<void> {
  for (const key of ERP_MODULE_KEYS) {
    const name = key === 'PROJECTS' ? 'ERP Projects' : 'ERP Work Orders';
    await prisma.systemModule.upsert({
      where: { key },
      update: { name },
      create: { key, name },
    });
  }

  const admin = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
  const emp = await prisma.role.findUnique({ where: { name: 'EMPLOYEE' } });
  const elevated = await prisma.role.findMany({
    where: { name: { in: ['HR', 'HR_MANAGER', 'SUPER_ADMIN'] } },
  });

  for (const role of [admin, ...elevated].filter(Boolean)) {
    for (const moduleKey of ERP_MODULE_KEYS) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: role!.id, moduleKey } },
        update: FULL,
        create: { roleId: role!.id, moduleKey, ...FULL },
      });
    }
  }

  if (emp) {
    for (const moduleKey of ERP_MODULE_KEYS) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: emp.id, moduleKey } },
        update: EMPLOYEE_RO,
        create: { roleId: emp.id, moduleKey, ...EMPLOYEE_RO },
      });
    }
  }
}
