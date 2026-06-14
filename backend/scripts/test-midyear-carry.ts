import { prisma } from '../src/config/prisma';
import { leaveBalanceService } from '../src/modules/leave/leaveBalance.service';

async function main() {
  const sl = await prisma.leaveType.findFirst({ where: { code: 'SL' } });
  const emp = await prisma.employee.findFirst({ where: { status: 'ACTIVE' } });
  if (!sl || !emp) throw new Error('no data');
  const year = 2026;

  const reset = async () => {
    await prisma.leaveBalance.upsert({
      where: { employeeId_leaveTypeId_year: { employeeId: emp.id, leaveTypeId: sl.id, year } },
      update: { totalCredited: 5, carryForward: 0, used: 2, pending: 0, available: 3 },
      create: {
        employeeId: emp.id,
        leaveTypeId: sl.id,
        year,
        totalCredited: 5,
        carryForward: 0,
        used: 2,
        pending: 0,
        available: 3,
      },
    });
    await prisma.leaveAuditLog.deleteMany({
      where: { employeeId: emp.id, OR: [{ context: { contains: 'SL:2026' } }] },
    });
  };

  await reset();
  await leaveBalanceService.ensureMidYearTransition({
    employeeId: emp.id,
    leaveTypeId: sl.id,
    year,
    leaveCode: 'SL',
    isCarryForward: true,
    actorId: 'test',
  });
  await leaveBalanceService.credit({
    employeeId: emp.id,
    leaveTypeId: sl.id,
    year,
    days: 5,
    actorId: 'test',
    action: 'CREDIT',
    context: 'AutoCredit:SL:2026:7-1',
  });
  const withCf = await prisma.leaveBalance.findUnique({
    where: { employeeId_leaveTypeId_year: { employeeId: emp.id, leaveTypeId: sl.id, year } },
  });
  console.log('Carry forward ON — expect avail 8, cf 3:', {
    credited: withCf?.totalCredited,
    cf: withCf?.carryForward,
    used: withCf?.used,
    available: withCf?.available,
  });

  await reset();
  await leaveBalanceService.ensureMidYearTransition({
    employeeId: emp.id,
    leaveTypeId: sl.id,
    year,
    leaveCode: 'SL',
    isCarryForward: false,
    actorId: 'test',
  });
  await leaveBalanceService.credit({
    employeeId: emp.id,
    leaveTypeId: sl.id,
    year,
    days: 5,
    actorId: 'test',
    action: 'CREDIT',
    context: 'AutoCredit:SL:2026:7-1',
  });
  const noCf = await prisma.leaveBalance.findUnique({
    where: { employeeId_leaveTypeId_year: { employeeId: emp.id, leaveTypeId: sl.id, year } },
  });
  console.log('Carry forward OFF — expect avail 5, cf 0:', {
    credited: noCf?.totalCredited,
    cf: noCf?.carryForward,
    used: noCf?.used,
    available: noCf?.available,
  });
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
