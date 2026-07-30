/**
 * Probe PayTime MSSQL using backend/.env
 * Run: npx tsx scripts/probe_paytime.ts
 */
import dotenv from 'dotenv';
dotenv.config({ path: '.env', override: true });

import sql from 'mssql';

const host = process.env.MSSQL_HOST || '';
const port = Number(process.env.MSSQL_PORT || 1433);
const instance = process.env.MSSQL_INSTANCE?.trim() || undefined;
const database = process.env.MSSQL_DB || '';
const user = process.env.MSSQL_USER || '';
const password = process.env.MSSQL_PASSWORD || '';
const table = process.env.MSSQL_TABLE || 'tmpDmpTerminalData';

const config: sql.config = {
  server: host,
  port: instance ? undefined : port,
  database,
  user,
  password,
  options: {
    encrypt: process.env.MSSQL_ENCRYPT === 'true',
    trustServerCertificate: process.env.MSSQL_TRUST_SERVER_CERT !== 'false',
    ...(instance ? { instanceName: instance } : {}),
  },
  connectionTimeout: 20000,
  requestTimeout: 30000,
};

async function main() {
  console.log(`Connecting to ${host}${instance ? '\\' + instance : ''}:${instance ? '(dynamic)' : port} / ${database} ...`);
  const pool = await sql.connect(config);
  console.log('CONNECTED OK');

  const cols = await pool.request().input('table', sql.NVarChar, table).query(`
    SELECT COLUMN_NAME, DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @table
    ORDER BY ORDINAL_POSITION
  `);
  console.log('COLUMNS:', JSON.stringify(cols.recordset, null, 2));

  const cnt = await pool.request().query(`SELECT COUNT(*) AS c FROM dbo.[${table.replace(/]/g, ']]')}]`);
  console.log('ROW_COUNT:', cnt.recordset[0]);

  const sample = await pool.request().query(`SELECT TOP 3 * FROM dbo.[${table.replace(/]/g, ']]')}]`);
  console.log('SAMPLE:', JSON.stringify(sample.recordset, null, 2));

  await pool.close();
  console.log('DONE');
}

main().catch((e) => {
  console.error('PROBE FAILED:', e?.message || e);
  process.exit(1);
});
