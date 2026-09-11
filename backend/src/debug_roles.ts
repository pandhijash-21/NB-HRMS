import { prisma } from './config/prisma';

async function main() {
  const roles = await prisma.role.findMany({
    include: {
      permissions: true,
      _count: { select: { users: true } }
    }
  });
  console.log('ROLES IN DB:');
  for (const r of roles) {
    console.log(`\nROLE: ${r.name} (id: ${r.id}, isSystem: ${r.isSystem}, users: ${r._count.users})`);
    console.log('Permissions count:', r.permissions.length);
    for (const p of r.permissions) {
      console.log(`  - ${p.moduleKey}: read=${p.canRead} write=${p.canWrite} approve=${p.canApprove} delete=${p.canDelete} scope=${p.employeeViewScope}`);
    }
  }
}

main().catch(console.error).finally(() => prisma.$disconnect());
