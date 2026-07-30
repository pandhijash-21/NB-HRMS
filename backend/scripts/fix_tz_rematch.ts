import dotenv from 'dotenv';
dotenv.config({ override: true });
import { PrismaClient } from '@prisma/client';

async function main() {
  const { attendanceSyncService } = await import(
    '../src/modules/attendance/attendanceSync.service'
  );
  const { paytimeWallClockToUtc } = await import(
    '../src/modules/attendance/esslMssql.client'
  );

  // sanity: wall 09:56 → UTC 04:26 → IST display 09:56
  const wall = new Date(Date.UTC(2026, 6, 30, 9, 56, 0));
  const utc = paytimeWallClockToUtc(wall);
  console.log('WALL_AS_UTC_COMPONENTS', wall.toISOString());
  console.log('REAL_UTC', utc.toISOString());
  const ist = new Date(utc.getTime() + 330 * 60 * 1000);
  console.log(
    'IST_DISPLAY',
    `${ist.getUTCHours().toString().padStart(2, '0')}:${ist.getUTCMinutes().toString().padStart(2, '0')}`,
  );

  const prisma = new PrismaClient();
  const info = await prisma.employeeGeneralInfo.findFirst({
    where: { employeeId: 1 },
    select: { punchId: true },
  });
  const punchId = info?.punchId?.trim() || '1';
  console.log('REMATCHING', punchId);
  const r = await attendanceSyncService.rematchEmployeePunchId({
    employeeId: 1,
    punchId,
  });
  console.log('REMATCH', r);

  const dayStart = new Date('2026-07-29T18:30:00.000Z'); // July 30 IST start
  const dayEnd = new Date('2026-07-30T18:30:00.000Z');
  const july30 = await prisma.attendancePunch.findMany({
    where: {
      employeeId: 1,
      source: 'ESSL',
      punchAt: { gte: dayStart, lt: dayEnd },
    },
    orderBy: { punchAt: 'asc' },
    take: 10,
  });
  console.log(
    'JULY30_PUNCHES',
    july30.map((p) => ({
      at: p.punchAt.toISOString(),
      ist: new Date(p.punchAt.getTime() + 330 * 60000).toISOString().slice(11, 16),
      key: p.externalKey,
    })),
  );

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
