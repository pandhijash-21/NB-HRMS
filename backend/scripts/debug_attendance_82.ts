import dotenv from 'dotenv';
dotenv.config({ override: true });
import sql from 'mssql';
import { PrismaClient } from '@prisma/client';

async function main() {
  const prisma = new PrismaClient();
  const pool = await sql.connect({
    server: process.env.MSSQL_HOST!,
    port: Number(process.env.MSSQL_PORT),
    database: process.env.MSSQL_DB!,
    user: process.env.MSSQL_USER!,
    password: process.env.MSSQL_PASSWORD!,
    options: { encrypt: false, trustServerCertificate: true },
  });

  const range = await pool.request().query(
    `SELECT MIN(In_Out_Time) AS mn, MAX(In_Out_Time) AS mx, COUNT(*) AS c FROM dbo.tmpDmpTerminalData`,
  );
  console.log('PAYTIME_RANGE', range.recordset[0]);

  const july = await pool.request().query(`
    SELECT COUNT(*) AS c FROM dbo.tmpDmpTerminalData
    WHERE In_Out_Time >= '2026-07-01' AND In_Out_Time < '2026-08-01'
  `);
  console.log('JULY2026', july.recordset[0]);

  const lateJune = await pool.request().query(`
    SELECT COUNT(*) AS c FROM dbo.tmpDmpTerminalData
    WHERE In_Out_Time >= '2026-06-29' AND In_Out_Time < '2026-07-02'
  `);
  console.log('JUN29_JUL1', lateJune.recordset[0]);

  const c82 = await pool.request().query(`
    SELECT TOP 15 CardNO, In_Out_Time, Mode, DeviceCode
    FROM dbo.tmpDmpTerminalData
    WHERE LTRIM(RTRIM(CardNO)) = '82'
    ORDER BY In_Out_Time DESC
  `);
  console.log('CARD82_COUNT_SAMPLE', c82.recordset.length, JSON.stringify(c82.recordset, null, 2));

  const c82cnt = await pool.request().query(`
    SELECT COUNT(*) AS c FROM dbo.tmpDmpTerminalData WHERE LTRIM(RTRIM(CardNO)) = '82'
  `);
  console.log('CARD82_TOTAL', c82cnt.recordset[0]);

  const emps = await prisma.employeeGeneralInfo.findMany({
    where: {
      OR: [
        { punchId: '82' },
        { fullName: { contains: 'Admin', mode: 'insensitive' } },
        { fullName: { contains: 'System', mode: 'insensitive' } },
      ],
    },
    select: { employeeId: true, fullName: true, punchId: true, employeeCode: true },
  });
  console.log('EMPS', emps);

  const punches = await prisma.attendancePunch.count({ where: { source: 'ESSL' } });
  console.log('ESSL_PUNCHES_IN_PG', punches);

  const sync = await prisma.attendanceSyncState.findMany();
  console.log('SYNC', sync);

  await pool.close();
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
