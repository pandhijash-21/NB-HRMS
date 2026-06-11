import type { ConnectionPool } from 'mssql';

/**
 * Placeholder connector for eSSL eTimeTrackLite MSSQL.
 * We keep this stubbed until creds + table schema are provided.
 */
export type EsslPunchRow = {
  // Must include a stable key for idempotency.
  externalKey: string;
  // HRMS employee id mapping (default assumption until schema known)
  employeeId: number;
  punchAt: Date;
  terminalId?: string | null;
  punchType?: string | null;
};

export async function connectEsslMssql(): Promise<ConnectionPool | null> {
  // Intentionally not implemented until creds are provided.
  return null;
}

export async function fetchEsslPunchRows(_params: { cursor?: string | null; limit: number }): Promise<{ rows: EsslPunchRow[]; nextCursor: string | null }> {
  // Intentionally stubbed: once creds are provided we will query the real tables.
  return { rows: [], nextCursor: null };
}

