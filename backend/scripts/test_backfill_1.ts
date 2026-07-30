import dotenv from 'dotenv';
dotenv.config({ override: true });

async function main() {
  const { attendanceSyncService } = await import(
    '../src/modules/attendance/attendanceSync.service'
  );
  console.time('backfill');
  const r = await attendanceSyncService.backfillPaytime({
    fromYmd: '2026-06-01',
    toYmd: '2026-07-30',
    punchId: '1',
  });
  console.timeEnd('backfill');
  console.log(JSON.stringify(r, null, 2));

  // Ensure SYSTEM ADMIN has punchId 1 for test, then rematch
  const { PrismaClient } = await import('@prisma/client');
  const prisma = new PrismaClient();
  const admin = await prisma.employeeGeneralInfo.findFirst({
    where: { employeeId: 1 },
    select: { punchId: true, fullName: true },
  });
  console.log('ADMIN', admin);
  if (admin) {
    const rematch = await attendanceSyncService.rematchEmployeePunchId({
      employeeId: 1,
      punchId: admin.punchId?.trim() || '1',
    });
    console.log('REMATCH', rematch);
    const count = await prisma.attendancePunch.count({
      where: { employeeId: 1, source: 'ESSL' },
    });
    console.log('ADMIN_ESSL_PUNCHES', count);
  }
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
