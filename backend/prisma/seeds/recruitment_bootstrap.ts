import { PrismaClient } from '@prisma/client';
import { seedSystemLookups } from './lookups.seed';

const prisma = new PrismaClient();

async function main() {
  await prisma.systemModule.upsert({
    where: { key: 'RECRUITMENT' },
    update: {},
    create: { key: 'RECRUITMENT', name: 'Recruitment' },
  });

  const admin = await prisma.role.findUnique({ where: { name: 'ADMIN' } });
  const emp = await prisma.role.findUnique({ where: { name: 'EMPLOYEE' } });
  const hrRoles = await prisma.role.findMany({
    where: { name: { in: ['HR', 'HR_MANAGER', 'SUPER_ADMIN'] } },
  });

  const full = {
    canRead: true,
    canWrite: true,
    canApprove: true,
    canDelete: true,
    canExport: true,
  };

  for (const role of [admin, ...hrRoles].filter(Boolean)) {
    await prisma.rolePermission.upsert({
      where: { roleId_moduleKey: { roleId: role!.id, moduleKey: 'RECRUITMENT' } },
      update: full,
      create: { roleId: role!.id, moduleKey: 'RECRUITMENT', ...full },
    });
  }

  if (emp) {
    await prisma.rolePermission.upsert({
      where: { roleId_moduleKey: { roleId: emp.id, moduleKey: 'RECRUITMENT' } },
      update: {
        canRead: true,
        canWrite: false,
        canApprove: false,
        canDelete: false,
        canExport: false,
      },
      create: {
        roleId: emp.id,
        moduleKey: 'RECRUITMENT',
        canRead: true,
        canWrite: false,
        canApprove: false,
        canDelete: false,
        canExport: false,
      },
    });
  }

  await seedSystemLookups(prisma);
  await prisma.systemLookup.deleteMany({ where: { category: 'EMPLOYMENT_TYPE' } });
  const c = await prisma.systemLookup.count({
    where: {
      category: {
        in: ['INTERVIEW_TYPE', 'INTERVIEW_STATUS', 'CANDIDATE_SOURCE'],
      },
    },
  });
  console.log(`Recruitment seeded. Lookup options: ${c}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
