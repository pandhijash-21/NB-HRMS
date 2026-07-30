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

  const top = await pool.request().query(`
    SELECT TOP 25 LTRIM(RTRIM(CardNO)) AS card, COUNT(*) AS c
    FROM dbo.tmpDmpTerminalData
    GROUP BY LTRIM(RTRIM(CardNO))
    ORDER BY COUNT(*) DESC
  `);
  console.log('TOP_CARDS', JSON.stringify(top.recordset));

  const like82 = await pool.request().query(`
    SELECT DISTINCT CardNO FROM dbo.tmpDmpTerminalData WHERE CardNO LIKE '%82%'
  `);
  console.log('LIKE82', JSON.stringify(like82.recordset));

  const june30 = await pool.request().query(`
    SELECT TOP 30 CardNO, In_Out_Time, Mode
    FROM dbo.tmpDmpTerminalData
    WHERE In_Out_Time >= '2026-06-30' AND In_Out_Time < '2026-07-01'
    ORDER BY In_Out_Time DESC
  `);
  console.log('JUN30', JSON.stringify(june30.recordset, null, 2));

  const pg = await prisma.attendancePunch.findMany({
    where: { source: 'ESSL' },
    take: 10,
    orderBy: { punchAt: 'desc' },
    select: {
      employeeId: true,
      punchAt: true,
      externalKey: true,
      punchType: true,
    },
  });
  console.log('PG_ESSL', pg);

  const mapped = await prisma.employeeGeneralInfo.findMany({
    where: { punchId: { not: null } },
    select: { punchId: true, fullName: true, employeeId: true },
  });
  console.log('MAPPED', mapped);

  await pool.close();
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
