import sql from 'mssql';
import { env } from '../../config/env';

export type ConnectionPool = sql.ConnectionPool;

/** Raw row from PayTime dump table before punchId → employee mapping. */
export type PaytimeRawPunch = {
  punchId: string;
  punchAt: Date;
  terminalId?: string | null;
  punchType?: string | null;
  externalKey: string;
};

export type EsslPunchRow = {
  externalKey: string;
  /** Machine punch id (Empcode) — mapped later via EmployeeGeneralInfo.punchId */
  punchId: string;
  punchAt: Date;
  terminalId?: string | null;
  punchType?: string | null;
};

const PUNCH_ID_ALIASES = [
  'cardno',
  'card_no',
  'punchid',
  'punch_id',
  'punchno',
  'punch_no',
  'empcode',
  'emp_code',
  'empid',
  'emp_id',
  'userid',
  'user_id',
  'nuserid',
  'suserid',
  'enrollnumber',
  'enroll_no',
];

const PUNCH_AT_ALIASES = [
  'in_out_time',
  'inouttime',
  'punchdatetime',
  'punch_date_time',
  'punchdate',
  'punch_date',
  'punchtime',
  'punch_time',
  'txndatetime',
  'txn_date_time',
  'logdate',
  'log_date',
  'attntime',
  'dtpunchtime',
  'attn_dt',
  'datetime',
  'createdat',
  'created_at',
  'createddate',
];

const TERMINAL_ALIASES = [
  'devicecode',
  'deviceid',
  'device_id',
  'dvcid',
  'terminalid',
  'terminal_id',
  'machinid',
  'machineid',
  'machine_id',
  'mcid',
  'ndeviceid',
  'ipaddress',
];

const MODE_ALIASES = ['mode', 'inout', 'inoutflag', 'in_out', 'punchtype', 'punch_type', 'm_flag'];

const ID_ALIASES = ['id', 'txnid', 'txn_id', 'srno', 'sr_no', 'recid', 'recordid', 'nlogid'];

let poolPromise: Promise<sql.ConnectionPool> | null = null;
let columnMapCache: {
  punchId: string;
  punchAt: string;
  terminal?: string;
  mode?: string;
  rowId?: string;
} | null = null;

export function isPaytimeMssqlConfigured(): boolean {
  return Boolean(env.MSSQL_HOST && env.MSSQL_DB && env.MSSQL_USER && env.MSSQL_PASSWORD && env.MSSQL_TABLE);
}

function buildConfig(): sql.config {
  if (!env.MSSQL_HOST || !env.MSSQL_DB || !env.MSSQL_USER || !env.MSSQL_PASSWORD) {
    throw new Error('PayTime MSSQL is not configured');
  }
  const host = env.MSSQL_HOST.replace(/^\.\\/, 'localhost\\').replace(/^\./, 'localhost');
  // Support "localhost\Instance" or separate MSSQL_INSTANCE
  let server = host;
  let instanceName = env.MSSQL_INSTANCE || undefined;
  if (host.includes('\\')) {
    const [srv, inst] = host.split('\\');
    server = srv || 'localhost';
    instanceName = inst || instanceName;
  }

  return {
    server,
    port: instanceName ? undefined : env.MSSQL_PORT,
    database: env.MSSQL_DB,
    user: env.MSSQL_USER,
    password: env.MSSQL_PASSWORD,
    options: {
      encrypt: env.MSSQL_ENCRYPT,
      trustServerCertificate: env.MSSQL_TRUST_SERVER_CERT,
      ...(instanceName ? { instanceName } : {}),
    },
    connectionTimeout: 15000,
    requestTimeout: 60000,
    pool: { max: 5, min: 0, idleTimeoutMillis: 30000 },
  };
}

function quoteIdent(name: string): string {
  return `[${name.replace(/]/g, ']]')}]`;
}

function pickColumn(cols: string[], aliases: string[], override?: string): string | undefined {
  if (override && cols.some((c) => c.toLowerCase() === override.toLowerCase())) {
    return cols.find((c) => c.toLowerCase() === override.toLowerCase())!;
  }
  const lower = new Map(cols.map((c) => [c.toLowerCase(), c]));
  for (const a of aliases) {
    const hit = lower.get(a);
    if (hit) return hit;
  }
  return undefined;
}

async function resolveColumns(pool: sql.ConnectionPool): Promise<NonNullable<typeof columnMapCache>> {
  if (columnMapCache) return columnMapCache;

  const table = env.MSSQL_TABLE;
  const metaReq = pool.request();
  metaReq.input('table', sql.NVarChar, table);
  const meta = await metaReq.query<{ COLUMN_NAME: string }>(`
    SELECT COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_NAME = @table
    ORDER BY ORDINAL_POSITION
  `);

  const cols = meta.recordset.map((r) => String(r.COLUMN_NAME));
  if (!cols.length) {
    throw new Error(`PayTime table not found or empty schema: ${table}`);
  }

  const punchId =
    pickColumn(cols, PUNCH_ID_ALIASES, env.MSSQL_PUNCH_ID_COLUMN) ??
    (() => {
      throw new Error(
        `Cannot find punch-id column in ${table}. Columns: ${cols.join(', ')}. Set MSSQL_PUNCH_ID_COLUMN.`,
      );
    })();
  const punchAt =
    pickColumn(cols, PUNCH_AT_ALIASES, env.MSSQL_PUNCH_AT_COLUMN) ??
    (() => {
      throw new Error(
        `Cannot find punch-time column in ${table}. Columns: ${cols.join(', ')}. Set MSSQL_PUNCH_AT_COLUMN.`,
      );
    })();

  columnMapCache = {
    punchId,
    punchAt,
    terminal: pickColumn(cols, TERMINAL_ALIASES, env.MSSQL_TERMINAL_COLUMN),
    mode: pickColumn(cols, MODE_ALIASES, env.MSSQL_MODE_COLUMN),
    rowId: pickColumn(cols, ID_ALIASES),
  };
  return columnMapCache;
}

export async function connectEsslMssql(): Promise<ConnectionPool | null> {
  if (!isPaytimeMssqlConfigured()) return null;
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(buildConfig())
      .connect()
      .catch((err) => {
        poolPromise = null;
        throw err;
      });
  }
  return poolPromise;
}

function toDate(value: unknown): Date | null {
  if (value == null) return null;
  if (value instanceof Date && Number.isFinite(value.getTime())) return value;
  const d = new Date(String(value));
  return Number.isFinite(d.getTime()) ? d : null;
}

/**
 * PayTime MSSQL stores naive IST wall-clock datetimes.
 * Tedious returns them as Date where getUTC* === the wall-clock digits.
 * Convert to a real UTC instant so Flutter `toLocal()` / IST day math is correct.
 * Example: wall 09:56 IST → 2026-07-30T09:56:00+05:30 → 04:26Z
 */
export function paytimeWallClockToUtc(wall: Date): Date {
  const y = wall.getUTCFullYear();
  const m = wall.getUTCMonth();
  const d = wall.getUTCDate();
  const hh = wall.getUTCHours();
  const mm = wall.getUTCMinutes();
  const ss = wall.getUTCSeconds();
  const pad = (n: number) => String(n).padStart(2, '0');
  return new Date(
    `${y}-${pad(m + 1)}-${pad(d)}T${pad(hh)}:${pad(mm)}:${pad(ss)}+05:30`,
  );
}

function buildExternalKey(parts: {
  rowId?: string | null;
  punchId: string;
  punchAt: Date;
  terminalId?: string | null;
}): string {
  if (parts.rowId) return `PAYTIME|${parts.rowId}`;
  const when = parts.punchAt.toISOString();
  const term = parts.terminalId ?? '0';
  return `PAYTIME|${parts.punchId}|${when}|${term}`;
}

function mapRawPaytimeRow(r: Record<string, unknown>): EsslPunchRow | null {
  const punchId = String(r.punchId ?? '').trim();
  const wall = toDate(r.punchAt);
  if (!punchId || !wall) return null;
  const punchAt = paytimeWallClockToUtc(wall);
  const terminalId = r.terminalId != null ? String(r.terminalId) : null;
  const punchType = r.punchType != null ? String(r.punchType) : null;
  const rowId = r.rowId != null ? String(r.rowId) : null;
  return {
    punchId,
    punchAt,
    terminalId,
    punchType,
    externalKey: buildExternalKey({ rowId, punchId, punchAt, terminalId }),
  };
}

/**
 * Fetch punches from PayTime MSSQL dump table (cursor = ISO punchAt exclusive lower bound).
 * Does not map to employeeId — caller uses punchId.mapper.
 */
export async function fetchEsslPunchRows(params: {
  cursor?: string | null;
  limit: number;
}): Promise<{ rows: EsslPunchRow[]; nextCursor: string | null; rawCount: number }> {
  const pool = await connectEsslMssql();
  if (!pool) return { rows: [], nextCursor: null, rawCount: 0 };

  const cols = await resolveColumns(pool);
  const table = quoteIdent(env.MSSQL_TABLE);
  const limit = Math.min(Math.max(params.limit || 2000, 1), 5000);

  const selectParts = [
    `${quoteIdent(cols.punchId)} AS punchId`,
    `${quoteIdent(cols.punchAt)} AS punchAt`,
  ];
  if (cols.terminal) selectParts.push(`${quoteIdent(cols.terminal)} AS terminalId`);
  if (cols.mode) selectParts.push(`${quoteIdent(cols.mode)} AS punchType`);
  if (cols.rowId) selectParts.push(`${quoteIdent(cols.rowId)} AS rowId`);

  const req = pool.request();
  req.input('limit', sql.Int, limit);

  let where = '1=1';
  if (params.cursor?.trim()) {
    const cursorDate = toDate(params.cursor);
    if (cursorDate) {
      req.input('cursorAt', sql.DateTime, cursorDate);
      where = `${quoteIdent(cols.punchAt)} > @cursorAt`;
    }
  }

  const q = `
    SELECT TOP (@limit) ${selectParts.join(', ')}
    FROM ${table}
    WHERE ${where}
    ORDER BY ${quoteIdent(cols.punchAt)} ASC
  `;

  const result = await req.query(q);
  const rows: EsslPunchRow[] = [];
  let maxWall: Date | null = null;

  for (const r of result.recordset as Array<Record<string, unknown>>) {
    const wall = toDate(r.punchAt);
    const mapped = mapRawPaytimeRow(r);
    if (!mapped) continue;
    rows.push(mapped);
    if (wall && (!maxWall || wall > maxWall)) maxWall = wall;
  }

  // Cursor must stay in PayTime wall-clock space (SQL column is naive IST).
  const nextCursor = rows.length ? (maxWall?.toISOString() ?? null) : null;
  return { rows, nextCursor, rawCount: rows.length };
}

/** Date-range preview for admin Raw tab (naive local datetimes as stored in PayTime). */
export async function fetchPaytimePunchesInRange(params: {
  fromYmd: string;
  toYmd: string;
  punchId?: string;
  limit?: number;
}): Promise<EsslPunchRow[]> {
  const pool = await connectEsslMssql();
  if (!pool) return [];

  const cols = await resolveColumns(pool);
  const table = quoteIdent(env.MSSQL_TABLE);
  const limit = Math.min(params.limit ?? 10000, 20000);

  // PayTime stores wall-clock datetimes (no TZ). Compare as strings/local, not UTC-shifted JS Dates.
  const fromAt = `${params.fromYmd} 00:00:00`;
  const toExclusiveYmd = (() => {
    const [y, m, d] = params.toYmd.split('-').map(Number);
    const dt = new Date(Date.UTC(y!, m! - 1, d! + 1));
    return `${dt.getUTCFullYear()}-${String(dt.getUTCMonth() + 1).padStart(2, '0')}-${String(dt.getUTCDate()).padStart(2, '0')}`;
  })();
  const toAt = `${toExclusiveYmd} 00:00:00`;

  const selectParts = [
    `${quoteIdent(cols.punchId)} AS punchId`,
    `${quoteIdent(cols.punchAt)} AS punchAt`,
  ];
  if (cols.terminal) selectParts.push(`${quoteIdent(cols.terminal)} AS terminalId`);
  if (cols.mode) selectParts.push(`${quoteIdent(cols.mode)} AS punchType`);
  if (cols.rowId) selectParts.push(`${quoteIdent(cols.rowId)} AS rowId`);

  const req = pool.request();
  req.input('limit', sql.Int, limit);
  req.input('fromAt', sql.NVarChar, fromAt);
  req.input('toAt', sql.NVarChar, toAt);

  let where = `${quoteIdent(cols.punchAt)} >= CONVERT(datetime, @fromAt, 120) AND ${quoteIdent(cols.punchAt)} < CONVERT(datetime, @toAt, 120)`;
  if (params.punchId?.trim()) {
    const q = params.punchId.trim();
    req.input('pid', sql.NVarChar, q);
    where += ` AND LTRIM(RTRIM(CAST(${quoteIdent(cols.punchId)} AS NVARCHAR(100)))) = @pid`;
  }

  const q = `
    SELECT TOP (@limit) ${selectParts.join(', ')}
    FROM ${table}
    WHERE ${where}
    ORDER BY ${quoteIdent(cols.punchAt)} ASC
  `;

  const result = await req.query(q);
  const rows: EsslPunchRow[] = [];
  for (const r of result.recordset as Array<Record<string, unknown>>) {
    const mapped = mapRawPaytimeRow(r);
    if (mapped) rows.push(mapped);
  }
  return rows;
}

/** Min/max punch times + row count for UI defaults. */
export async function fetchPaytimeMeta(): Promise<{
  configured: boolean;
  minPunchAt: string | null;
  maxPunchAt: string | null;
  totalRows: number;
  table: string;
}> {
  if (!isPaytimeMssqlConfigured()) {
    return {
      configured: false,
      minPunchAt: null,
      maxPunchAt: null,
      totalRows: 0,
      table: env.MSSQL_TABLE,
    };
  }
  const pool = await connectEsslMssql();
  if (!pool) {
    return {
      configured: false,
      minPunchAt: null,
      maxPunchAt: null,
      totalRows: 0,
      table: env.MSSQL_TABLE,
    };
  }
  const cols = await resolveColumns(pool);
  const table = quoteIdent(env.MSSQL_TABLE);
  const result = await pool.request().query(`
    SELECT
      MIN(${quoteIdent(cols.punchAt)}) AS mn,
      MAX(${quoteIdent(cols.punchAt)}) AS mx,
      COUNT(*) AS c
    FROM ${table}
  `);
  const row = result.recordset[0] as { mn?: Date; mx?: Date; c?: number };
  return {
    configured: true,
    minPunchAt: row.mn ? new Date(row.mn).toISOString() : null,
    maxPunchAt: row.mx ? new Date(row.mx).toISOString() : null,
    totalRows: Number(row.c ?? 0),
    table: env.MSSQL_TABLE,
  };
}

export function resetPaytimeColumnCache(): void {
  columnMapCache = null;
}
