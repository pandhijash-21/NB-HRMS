import { prisma } from '../../config/prisma';
import { AttendanceSource } from '@prisma/client';
import { fetchEsslPunchRows } from './esslMssql.client';
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

async function insertMappedPunches(
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

export const attendanceSyncService = {
  /**
   * Legacy MSSQL eSSL path — still stubbed until other-site creds exist.
   */
  async syncEsslPunches() {
    const state = await prisma.attendanceSyncState.upsert({
      where: { source: AttendanceSource.ESSL },
      update: {},
      create: { source: AttendanceSource.ESSL, cursor: null, lastSyncedAt: null },
    });

    let cursor: string | null = state.cursor ?? null;
    let totalInserted = 0;

    for (;;) {
      const { rows, nextCursor } = await fetchEsslPunchRows({ cursor, limit: 2000 });
      if (!rows.length) break;

      await prisma.attendancePunch.createMany({
        data: rows.map((r) => ({
          employeeId: r.employeeId,
          punchAt: r.punchAt,
          source: AttendanceSource.ESSL,
          externalKey: r.externalKey,
          terminalId: r.terminalId ?? null,
          punchType: r.punchType ?? null,
        })),
        skipDuplicates: true,
      });

      totalInserted += rows.length;
      cursor = nextCursor;
      if (!cursor) break;
    }

    await prisma.attendanceSyncState.update({
      where: { source: AttendanceSource.ESSL },
      data: { cursor, lastSyncedAt: new Date() },
    });

    return { source: AttendanceSource.ESSL, inserted: totalInserted, cursor };
  },

  /** Incremental sync from eTimeOffice DownloadLastPunchData. */
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
    const result = await insertMappedPunches(punches, punchMap);

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

  /** Date-range backfill via PunchDataMCID. */
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
    const result = await insertMappedPunches(punches, punchMap);
    return {
      source: AttendanceSource.ETIMEOFFICE,
      fetched: punches.length,
      ...result,
    };
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
        configured: false,
        lastSyncedAt: essl?.lastSyncedAt?.toISOString() ?? null,
        cursor: essl?.cursor ?? null,
        note: 'MSSQL connector stubbed for other sites/vendors',
      },
      employeesWithPunchId: punchIds,
    };
  },
};
