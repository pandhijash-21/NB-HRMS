import { prisma } from '../../config/prisma';
import { fetchEsslPunchRows } from './esslMssql.client';

const BATCH = 2000;

export const attendanceSyncService = {
  /**
   * Incremental sync from eSSL MSSQL into Postgres attendance_punches.
   * Safe to run without creds/schema: will do nothing (stub returns empty).
   */
  async syncEsslPunches() {
    const state = await prisma.attendanceSyncState.upsert({
      where: { source: 'ESSL' },
      update: {},
      create: { source: 'ESSL', cursor: null, lastSyncedAt: null },
    });

    let cursor: string | null = state.cursor ?? null;
    let totalInserted = 0;

    for (;;) {
      const { rows, nextCursor } = await fetchEsslPunchRows({ cursor, limit: BATCH });
      if (!rows.length) break;

      // Upsert via createMany + skipDuplicates using unique externalKey
      await prisma.attendancePunch.createMany({
        data: rows.map((r) => ({
          employeeId: r.employeeId,
          punchAt: r.punchAt,
          source: 'ESSL',
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
      where: { source: 'ESSL' },
      data: {
        cursor,
        lastSyncedAt: new Date(),
      },
    });

    return { inserted: totalInserted, cursor };
  },
};

