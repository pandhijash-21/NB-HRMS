import { prisma } from '../src/config/prisma';
import { leaveBalanceService } from '../src/modules/leave/leaveBalance.service';

async function main() {
  const year = new Date().getUTCFullYear();
  const employees = await prisma.employee.findMany({ select: { id: true } });
  for (const e of employees) {
    await leaveBalanceService.syncScheduledCredits(e.id, year);
  }
  const sl = await prisma.leaveType.findFirst({ where: { code: 'SL' } });
  if (sl) {
    const bals = await prisma.leaveBalance.findMany({
      where: { leaveTypeId: sl.id, year },
      take: 5,
    });
    console.log(
      'SL sample after sync:',
      bals.map((b) => ({ emp: b.employeeId, credited: b.totalCredited, available: b.available })),
    );
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
