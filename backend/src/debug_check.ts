import { prisma } from './config/prisma';

async function main() {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      username: true,
      subOrganization: true,
      role: { select: { id: true, name: true } },
      employeeId: true,
    },
  });
  console.log('USERS IN DB:', users.length);
  for (const u of users) {
    console.log(`- ${u.username} (${u.role.name}) org=${u.subOrganization} empId=${u.employeeId}`);
  }

  const orgs = await prisma.organization.findMany();
  console.log('ORGANIZATIONS IN DB:', orgs.length, JSON.stringify(orgs, null, 2));
}

main().catch(console.error).finally(() => prisma.$disconnect());
