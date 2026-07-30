import { PrismaClient } from '@prisma/client';

const p = new PrismaClient();

async function main() {
  const pol = await p.attendancePolicy.findUnique({ where: { id: 'default' } });
  const settings = await p.employeeAttendanceSettings.findMany({ take: 10 });
  const gens = await p.employeeGeneralInfo.findMany({
    select: { employeeId: true, fullName: true, punchId: true, weeklyOffDays: true },
    take: 20,
  });
  console.log(JSON.stringify({ pol, settings, gens }, null, 2));
}

main()
  .finally(() => p.$disconnect());
