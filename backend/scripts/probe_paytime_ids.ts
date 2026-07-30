import dotenv from 'dotenv';
dotenv.config({ path: '.env', override: true });
import sql from 'mssql';

async function main() {
  const pool = await sql.connect({
    server: process.env.MSSQL_HOST!,
    port: Number(process.env.MSSQL_PORT),
    database: process.env.MSSQL_DB!,
    user: process.env.MSSQL_USER!,
    password: process.env.MSSQL_PASSWORD!,
    options: { encrypt: false, trustServerCertificate: true },
  });

  const recent = await pool.request().query(`
    SELECT TOP 10 CardNO, EmpCode, EmpID, In_Out_Time, Mode, DeviceCode
    FROM dbo.tmpDmpTerminalData
    WHERE CardNO IS NOT NULL AND LTRIM(RTRIM(CardNO)) <> ''
    ORDER BY In_Out_Time DESC
  `);
  console.log('RECENT:', JSON.stringify(recent.recordset, null, 2));

  const stats = await pool.request().query(`
    SELECT
      SUM(CASE WHEN EmpCode <> 0 THEN 1 ELSE 0 END) AS nonZeroEmpCode,
      SUM(CASE WHEN CardNO IS NOT NULL AND LTRIM(RTRIM(CardNO)) <> '' AND CardNO <> '0' THEN 1 ELSE 0 END) AS usefulCardNo,
      COUNT(*) AS total
    FROM dbo.tmpDmpTerminalData
  `);
  console.log('STATS:', stats.recordset[0]);
  await pool.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
