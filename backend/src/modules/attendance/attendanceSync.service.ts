import { prisma } from '../../config/prisma';
import { AttendanceSource } from '@prisma/client';
import {
  fetchEsslPunchRows,
  fetchPaytimePunchesInRange,
  isPaytimeMssqlConfigured,
  type EsslPunchRow,
} from './esslMssql.client';
import {
  buildExternalKey,
  fetchLastPunchData,
  fetchPunchDataMcid,
  isEtimeofficeConfigured,
  parseEtimePunchDate,
  type EtimePunchRow,
} from './etimeoffice.client';
import { loadPunchIdMap, lookupPunchIdMap } from './punchId.mapper';

const BATCH_INSERT = 500;

async function insertMappedEtimePunches(
  punches: EtimePunchRow[],
  punchMap: Map<string, number>,
): Promise<{ inserted: number; skippedUnmatched: number; unmatchedCodes: string[] }> {
  const unmatched = new Set<string>();
  const rows: Array<{
    employeeId: number;
    punchAt: Date;
    source: AttendanceSource;
    externalKey: string;
    terminalId: string | null;
    punchType: string | null;
  }> = [];

  for (const p of punches) {
    const code = String(p.Empcode ?? '').trim();
    if (!code || !p.PunchDate) continue;
    const employeeId = lookupPunchIdMap(punchMap, code);
    if (employeeId == null) {
      unmatched.add(code);
      continue;
    }
    let punchAt: Date;
    try {
      punchAt = parseEtimePunchDate(String(p.PunchDate));
    } catch {
      continue;
    }
    rows.push({
      employeeId,
      punchAt,
      source: AttendanceSource.ETIMEOFFICE,
      externalKey: buildExternalKey(p),
      terminalId: p.mcid != null ? String(p.mcid) : null,
      punchType: p.M_Flag != null ? String(p.M_Flag) : null,
    });
  }

  let inserted = 0;
  for (let i = 0; i < rows.length; i += BATCH_INSERT) {
    const chunk = rows.slice(i, i + BATCH_INSERT);
    const res = await prisma.attendancePunch.createMany({
      data: chunk,
      skipDuplicates: true,
    });
    inserted += res.count;
  }

  return {
    inserted,
    skippedUnmatched: unmatched.size,
    unmatchedCodes: [...unmatched].sort(),
  };
}

async function insertMappedPaytimeRows(
  punches: EsslPunchRow[],
  punchMap: Map<string, number>,
  opts?: { forceEmployeeId?: number; forcePunchId?: string },
): Promise<{ inserted: number; skippedUnmatched: number; unmatchedCodes: string[] }> {
  const unmatched = new Set<string>();
  const rows: Array<{
    employeeId: number;
    punchAt: Date;
    source: AttendanceSource;
    externalKey: string;
    terminalId: string | null;
    punchType: string | null;
  }> = [];

  const forcePid = opts?.forcePunchId?.trim();
  const forceEmp = opts?.forceEmployeeId;

  for (const p of punches) {
    let employeeId = lookupPunchIdMap(punchMap, p.punchId);
    // Testing: map this card onto a specific employee even if profile map is stale mid-request
    if (
      forceEmp != null &&
      forcePid &&
      (p.punchId === forcePid || p.punchId.replace(/^0+/, '') === forcePid.replace(/^0+/, ''))
    ) {
      employeeId = forceEmp;
    }
    if (employeeId == null) {
      unmatched.add(p.punchId);
      continue;
    }
    rows.push({
      employeeId,
      punchAt: p.punchAt,
      source: AttendanceSource.ESSL,
      externalKey: p.externalKey,
      terminalId: p.terminalId ?? null,
      punchType: p.punchType ?? null,
    });
  }

  let inserted = 0;
  for (let i = 0; i < rows.length; i += BATCH_INSERT) {
    const chunk = rows.slice(i, i + BATCH_INSERT);
    const res = await prisma.attendancePunch.createMany({
      data: chunk,
      skipDuplicates: true,
    });
    inserted += res.count;
  }

  return {
    inserted,
    skippedUnmatched: unmatched.size,
    unmatchedCodes: [...unmatched].sort(),
  };
}

export const attendanceSyncService = {
  /**
   * PayTime MSSQL fetch → map punchId → insert (skipDuplicates).
   * Never updates existing punch rows (punch-in time stays the earliest row).
   */
  async syncEsslPunches() {
    if (!isPaytimeMssqlConfigured()) {
      return {
        source: AttendanceSource.ESSL,
        inserted: 0,
        skippedUnmatched: 0,
        unmatchedCodes: [] as string[],
        cursor: null as string | null,
        fetched: 0,
        skipped: true,
        reason: 'PayTime MSSQL credentials not configured',
      };
    }

    const state = await prisma.attendanceSyncState.upsert({
      where: { source: AttendanceSource.ESSL },
      update: {},
      create: { source: AttendanceSource.ESSL, cursor: null, lastSyncedAt: null },
    });

    const punchMap = await loadPunchIdMap();
    let cursor: string | null = state.cursor ?? null;
    let totalInserted = 0;
    let totalFetched = 0;
    const unmatched = new Set<string>();
    let guard = 0;

    for (;;) {
      guard += 1;
      if (guard > 50) break;

      const { rows, nextCursor, rawCount } = await fetchEsslPunchRows({ cursor, limit: 2000 });
      totalFetched += rawCount;
      if (!rows.length) break;

      const result = await insertMappedPaytimeRows(rows, punchMap);
      totalInserted += result.inserted;
      for (const c of result.unmatchedCodes) unmatched.add(c);

      cursor = nextCursor;
      if (!cursor || rows.length < 2000) break;
    }

    await prisma.attendanceSyncState.update({
      where: { source: AttendanceSource.ESSL },
      data: { cursor, lastSyncedAt: new Date() },
    });

    return {
      source: AttendanceSource.ESSL,
      inserted: totalInserted,
      skippedUnmatched: unmatched.size,
      unmatchedCodes: [...unmatched].sort().slice(0, 50),
      cursor,
      fetched: totalFetched,
      skipped: false,
    };
  },

  /**
   * Date-range backfill from PayTime.
   * - No punchId → import ALL cards in range that match any employee's Punch ID.
   * - With punchId → only that CardNO (single range query — fast).
   */
  async backfillPaytime(params: { fromYmd: string; toYmd: string; punchId?: string }) {
    if (!isPaytimeMssqlConfigured()) {
      throw new Error('PayTime MSSQL credentials not configured');
    }
    const punchMap = await loadPunchIdMap();
    const punchId = params.punchId?.trim() || undefined;

    // Filtered by Punch ID: one query for the whole range.
    if (punchId) {
      const rows = await fetchPaytimePunchesInRange({
        fromYmd: params.fromYmd,
        toYmd: params.toYmd,
        punchId,
        limit: 20000,
      });
      const result = await insertMappedPaytimeRows(rows, punchMap, {
        // If this Punch ID is on a profile, map wins; force not needed here
      });
      return {
        source: AttendanceSource.ESSL,
        fetched: rows.length,
        inserted: result.inserted,
        skippedUnmatched: result.skippedUnmatched,
        unmatchedCodes: result.unmatchedCodes.slice(0, 50),
      };
    }

    // All cards: walk week-by-week to avoid TOP truncation on busy ranges.
    let totalFetched = 0;
    let totalInserted = 0;
    const unmatched = new Set<string>();
    const cursor = new Date(`${params.fromYmd}T00:00:00Z`);
    const end = new Date(`${params.toYmd}T00:00:00Z`);
    while (cursor.getTime() <= end.getTime()) {
      const fromYmd = cursor.toISOString().slice(0, 10);
      const weekEnd = new Date(cursor.getTime());
      weekEnd.setUTCDate(weekEnd.getUTCDate() + 6);
      if (weekEnd.getTime() > end.getTime()) weekEnd.setTime(end.getTime());
      const toYmd = weekEnd.toISOString().slice(0, 10);

      const rows = await fetchPaytimePunchesInRange({
        fromYmd,
        toYmd,
        limit: 20000,
      });
      totalFetched += rows.length;
      const result = await insertMappedPaytimeRows(rows, punchMap);
      totalInserted += result.inserted;
      for (const c of result.unmatchedCodes) unmatched.add(c);

      cursor.setUTCDate(cursor.getUTCDate() + 7);
    }

    return {
      source: AttendanceSource.ESSL,
      fetched: totalFetched,
      inserted: totalInserted,
      skippedUnmatched: unmatched.size,
      unmatchedCodes: [...unmatched].sort().slice(0, 50),
    };
  },

  /**
   * After profile Punch ID change: pull that CardNO into this employee (testing rematch).
   * Uses last ~18 months ending at latest PayTime punch (fast enough for profile save).
   */
  async rematchEmployeePunchId(params: {
    employeeId: number;
    punchId: string;
    fromYmd?: string;
    toYmd?: string;
  }) {
    if (!isPaytimeMssqlConfigured()) {
      return { skipped: true, reason: 'PayTime not configured', inserted: 0, fetched: 0 };
    }
    const punchId = params.punchId.trim();
    if (!punchId) return { skipped: true, reason: 'Empty punchId', inserted: 0, fetched: 0 };

    const { fetchPaytimeMeta } = await import('./esslMssql.client');
    const meta = await fetchPaytimeMeta();
    const toYmd =
      params.toYmd ??
      (meta.maxPunchAt ? meta.maxPunchAt.slice(0, 10) : new Date().toISOString().slice(0, 10));
    let fromYmd = params.fromYmd;
    if (!fromYmd) {
      const to = new Date(`${toYmd}T00:00:00Z`);
      to.setUTCMonth(to.getUTCMonth() - 18);
      fromYmd = to.toISOString().slice(0, 10);
      if (meta.minPunchAt && meta.minPunchAt.slice(0, 10) > fromYmd) {
        fromYmd = meta.minPunchAt.slice(0, 10);
      }
    }

    const punchMap = await loadPunchIdMap();
    punchMap.set(punchId, params.employeeId);
    punchMap.set(punchId.replace(/^0+/, '') || '0', params.employeeId);

    // Drop previously imported PayTime rows for this card (wrong TZ keys from older imports).
    await prisma.attendancePunch.deleteMany({
      where: {
        employeeId: params.employeeId,
        source: AttendanceSource.ESSL,
        externalKey: { startsWith: `PAYTIME|${punchId}|` },
      },
    });

    const rows = await fetchPaytimePunchesInRange({
      fromYmd,
      toYmd,
      punchId,
      limit: 20000,
    });
    const result = await insertMappedPaytimeRows(rows, punchMap, {
      forceEmployeeId: params.employeeId,
      forcePunchId: punchId,
    });

    return {
      skipped: false,
      fetched: rows.length,
      inserted: result.inserted,
      fromYmd,
      toYmd,
      punchId,
      employeeId: params.employeeId,
    };
  },

  /** Incremental sync from eTimeOffice (optional other sites). */
  async syncEtimeofficePunches() {
    if (!isEtimeofficeConfigured()) {
      return {
        source: AttendanceSource.ETIMEOFFICE,
        inserted: 0,
        skippedUnmatched: 0,
        unmatchedCodes: [] as string[],
        cursor: null as string | null,
        skipped: true,
        reason: 'eTimeOffice credentials not configured',
      };
    }

    const state = await prisma.attendanceSyncState.upsert({
      where: { source: AttendanceSource.ETIMEOFFICE },
      update: {},
      create: { source: AttendanceSource.ETIMEOFFICE, cursor: null, lastSyncedAt: null },
    });

    const punchMap = await loadPunchIdMap();
    const { punches, nextCursor } = await fetchLastPunchData(state.cursor);
    const result = await insertMappedEtimePunches(punches, punchMap);

    const cursor = nextCursor ?? state.cursor;
    await prisma.attendanceSyncState.update({
      where: { source: AttendanceSource.ETIMEOFFICE },
      data: {
        cursor,
        lastSyncedAt: new Date(),
      },
    });

    return {
      source: AttendanceSource.ETIMEOFFICE,
      inserted: result.inserted,
      skippedUnmatched: result.skippedUnmatched,
      unmatchedCodes: result.unmatchedCodes,
      cursor,
      fetched: punches.length,
      skipped: false,
    };
  },

  /** Date-range backfill via PunchDataMCID (eTimeOffice). */
  async backfillEtimeoffice(params: { fromYmd: string; toYmd: string; empcode?: string }) {
    if (!isEtimeofficeConfigured()) {
      throw new Error('eTimeOffice credentials not configured');
    }
    const punchMap = await loadPunchIdMap();
    const punches = await fetchPunchDataMcid({
      empcode: params.empcode,
      fromYmd: params.fromYmd,
      toYmd: params.toYmd,
    });
    const result = await insertMappedEtimePunches(punches, punchMap);
    return {
      source: AttendanceSource.ETIMEOFFICE,
      fetched: punches.length,
      ...result,
    };
  },

  /** Primary device sync: PayTime MSSQL first, then optional eTimeOffice. */
  async syncDeviceNow() {
    const paytime = await this.syncEsslPunches();
    const etime = await this.syncEtimeofficePunches();
    return { paytime, etime };
  },

  async getDeviceStatus() {
    const [etime, essl] = await Promise.all([
      prisma.attendanceSyncState.findUnique({ where: { source: AttendanceSource.ETIMEOFFICE } }),
      prisma.attendanceSyncState.findUnique({ where: { source: AttendanceSource.ESSL } }),
    ]);
    const punchIds = await prisma.employeeGeneralInfo.count({
      where: { punchId: { not: null } },
    });
    return {
      etimeoffice: {
        configured: isEtimeofficeConfigured(),
        lastSyncedAt: etime?.lastSyncedAt?.toISOString() ?? null,
        cursor: etime?.cursor ?? null,
      },
      esslMssql: {
        configured: isPaytimeMssqlConfigured(),
        lastSyncedAt: essl?.lastSyncedAt?.toISOString() ?? null,
        cursor: essl?.cursor ?? null,
        note: isPaytimeMssqlConfigured()
          ? 'PayTime MSSQL (tmpDmpTerminalData) — map via Punch ID'
          : 'PayTime MSSQL not configured',
      },
      employeesWithPunchId: punchIds,
      rules: {
        punchIn: 'Earliest punch of the day (machine or phone) — never overwritten',
        punchOut:
          'Phone 2nd punch locks OUT; otherwise last machine punch is OUT (later scans can advance OUT)',
      },
    };
  },
};
