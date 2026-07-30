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

  const range = await pool.request().query(`
    SELECT COUNT(*) AS c, MAX(In_Out_Time) AS mx, MAX(CreatedDate) AS mxCreated
    FROM dbo.tmpDmpTerminalData
  `);
  console.log('TOTAL_AND_MAX', range.recordset[0]);

  const recent = await pool.request().query(`
    SELECT TOP 15 CardNO, EmpCode, EmpID, In_Out_Time, Mode, CreatedDate, DeviceCode
    FROM dbo.tmpDmpTerminalData
    ORDER BY In_Out_Time DESC, CreatedDate DESC
  `);
  console.log('RECENT_BY_PUNCH_TIME', JSON.stringify(recent.recordset, null, 2));

  const recentCreated = await pool.request().query(`
    SELECT TOP 15 CardNO, EmpCode, EmpID, In_Out_Time, Mode, CreatedDate, DeviceCode
    FROM dbo.tmpDmpTerminalData
    ORDER BY CreatedDate DESC
  `);
  console.log('RECENT_BY_CREATED', JSON.stringify(recentCreated.recordset, null, 2));

  const mapped = await prisma.employeeGeneralInfo.findMany({
    where: { punchId: { not: null } },
    select: { employeeId: true, fullName: true, punchId: true, employeeCode: true },
  });
  console.log('PROFILE_PUNCH_IDS', mapped);

  await pool.close();
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
