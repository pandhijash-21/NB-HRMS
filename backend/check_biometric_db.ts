import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();

async function main() {
  const rows = await prisma.employeeAttendanceSettings.findMany();
  console.log('--- employee_attendance_settings ---');
  console.log(JSON.stringify(rows, null, 2));
}

main().finally(() => prisma.$disconnect());
