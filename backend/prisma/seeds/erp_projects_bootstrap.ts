import { PrismaClient } from '@prisma/client';
import { seedSystemLookups } from './lookups.seed';

const prisma = new PrismaClient();

async function main() {
  await prisma.systemModule.upsert({
    where: { key: 'PROJECTS' },
    update: { name: 'ERP Projects' },
    create: { key: 'PROJECTS', name: 'ERP Projects' },
  });

  await prisma.systemModule.upsert({
    where: { key: 'WORK_ORDERS' },
    update: { name: 'ERP Work Orders' },
    create: { key: 'WORK_ORDERS', name: 'ERP Work Orders' },
  });

  const admin = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
  const emp = await prisma.role.findUnique({ where: { name: 'EMPLOYEE' } });
  const extra = await prisma.role.findMany({
    where: { name: { in: ['HR', 'HR_MANAGER', 'SUPER_ADMIN'] } },
  });

  const full = {
    canRead: true,
    canWrite: true,
    canApprove: true,
    canDelete: true,
    canExport: true,
  };

  for (const role of [admin, ...extra].filter(Boolean)) {
    for (const moduleKey of ['PROJECTS', 'WORK_ORDERS']) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: role!.id, moduleKey } },
        update: full,
        create: { roleId: role!.id, moduleKey, ...full },
      });
    }
  }

  if (emp) {
    for (const moduleKey of ['PROJECTS', 'WORK_ORDERS']) {
      await prisma.rolePermission.upsert({
        where: { roleId_moduleKey: { roleId: emp.id, moduleKey } },
        update: {
          canRead: true,
          canWrite: false,
          canApprove: false,
          canDelete: false,
          canExport: false,
        },
        create: {
          roleId: emp.id,
          moduleKey,
          canRead: true,
          canWrite: false,
          canApprove: false,
          canDelete: false,
          canExport: false,
        },
      });
    }
  }

  await seedSystemLookups(prisma);
  console.log('ERP Projects module + lookups bootstrapped');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
