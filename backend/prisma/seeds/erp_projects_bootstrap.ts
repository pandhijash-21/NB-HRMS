import { PrismaClient } from '@prisma/client';
import { seedSystemLookups } from './lookups.seed';

const prisma = new PrismaClient();

async function main() {
  await prisma.systemModule.upsert({
    where: { key: 'PROJECTS' },
    update: { name: 'ERP Projects' },
    create: { key: 'PROJECTS', name: 'ERP Projects' },
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
    await prisma.rolePermission.upsert({
      where: { roleId_moduleKey: { roleId: role!.id, moduleKey: 'PROJECTS' } },
      update: full,
      create: { roleId: role!.id, moduleKey: 'PROJECTS', ...full },
    });
  }

  if (emp) {
    await prisma.rolePermission.upsert({
      where: { roleId_moduleKey: { roleId: emp.id, moduleKey: 'PROJECTS' } },
      update: {
        canRead: true,
        canWrite: false,
        canApprove: false,
        canDelete: false,
        canExport: false,
      },
      create: {
        roleId: emp.id,
        moduleKey: 'PROJECTS',
        canRead: true,
        canWrite: false,
        canApprove: false,
        canDelete: false,
        canExport: false,
      },
    });
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
