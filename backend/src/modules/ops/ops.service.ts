import { prisma } from '../../config/prisma';
import { connectRedis } from '../../config/redis';
import { env } from '../../config/env';
import { getCloudinaryCredentials, configureCloudinary } from '../../config/cloudinary';
import { v2 as cloudinary } from 'cloudinary';
import { listLiveLogs } from './live-log';
import { listLocalBackups, runLocalDbBackup } from './backup.service';

async function timed<T>(fn: () => Promise<T>): Promise<{ ok: boolean; ms: number; error?: string; data?: T }> {
  const t0 = Date.now();
  try {
    const data = await fn();
    return { ok: true, ms: Date.now() - t0, data };
  } catch (err) {
    return { ok: false, ms: Date.now() - t0, error: err instanceof Error ? err.message : String(err) };
  }
}

export const opsService = {
  async getDashboard(scope = 'NB_DEVELOPER') {
    const dbProbe = await timed(async () => {
      await prisma.$queryRaw`SELECT 1`;
      return true;
    });

    const redisProbe = await timed(async () => {
      await connectRedis();
      return true;
    });

    const cloudinaryConfigured = !!getCloudinaryCredentials();
    let cloudinaryProbe: { ok: boolean; ms: number; error?: string; detail?: string } = {
      ok: false,
      ms: 0,
      error: 'not configured',
    };
    if (cloudinaryConfigured) {
      configureCloudinary();
      const c = await timed(async () => {
        // Lightweight authenticated ping
        const res = await cloudinary.api.ping();
        return res?.status || 'ok';
      });
      cloudinaryProbe = {
        ok: c.ok,
        ms: c.ms,
        error: c.error,
        detail: c.ok ? String(c.data) : undefined,
      };
    }

    const apiSelf = await timed(async () => ({
      service: 'hrms-backend',
      env: env.NODE_ENV || 'development',
      port: env.PORT,
    }));

    const [totalLeads, excelLeads, manualLeads, metaLeads, googleLeads, webhookLeads, deletedLeads] =
      await Promise.all([
        prisma.crmLead.count({ where: { scope, isDeleted: false } }),
        prisma.crmLead.count({ where: { scope, isDeleted: false, leadSource: 'EXCEL' } }),
        prisma.crmLead.count({
          where: { scope, isDeleted: false, OR: [{ leadSource: 'MANUAL' }, { leadSource: null }] },
        }),
        prisma.crmLead.count({ where: { scope, isDeleted: false, leadSource: 'META' } }),
        prisma.crmLead.count({ where: { scope, isDeleted: false, leadSource: 'GOOGLE' } }),
        prisma.crmLead.count({ where: { scope, isDeleted: false, leadSource: 'WEBHOOK' } }),
        prisma.crmLead.count({ where: { scope, isDeleted: true } }),
      ]);

    const lastIngested = await prisma.crmLead.findMany({
      where: {
        scope,
        isDeleted: false,
        leadSource: { in: ['META', 'GOOGLE', 'WEBHOOK', 'EXCEL', 'MANUAL'] },
      },
      orderBy: { createdAt: 'desc' },
      take: 10,
      select: {
        id: true,
        name: true,
        phone: true,
        leadSource: true,
        status: true,
        createdAt: true,
        campaign: { select: { id: true, name: true, platform: true } as any },
      },
    });

    const auditLogs = await prisma.auditLog.findMany({
      orderBy: { changedAt: 'desc' },
      take: 40,
      select: {
        id: true,
        tableName: true,
        recordId: true,
        fieldName: true,
        oldValue: true,
        newValue: true,
        changedBy: true,
        changedAt: true,
        changeReason: true,
        ipAddress: true,
        employeeId: true,
      },
    });

    const backups = listLocalBackups().slice(0, 20);
    const liveLogs = listLiveLogs(80);

    const overallOk = dbProbe.ok && apiSelf.ok;

    return {
      generatedAt: new Date().toISOString(),
      overall: overallOk ? 'healthy' : 'degraded',
      system: {
        env: env.NODE_ENV || 'development',
        port: env.PORT,
        uptimeSec: Math.floor(process.uptime()),
        node: process.version,
        memoryMb: Math.round(process.memoryUsage().rss / (1024 * 1024)),
      },
      probes: {
        database: { ok: dbProbe.ok, latencyMs: dbProbe.ms, error: dbProbe.error },
        redis: { ok: redisProbe.ok, latencyMs: redisProbe.ms, error: redisProbe.error },
        api: { ok: apiSelf.ok, latencyMs: apiSelf.ms, error: apiSelf.error },
        cloudinary: cloudinaryProbe,
      },
      leads: {
        scope,
        total: totalLeads,
        excel: excelLeads,
        manual: manualLeads,
        meta: metaLeads,
        google: googleLeads,
        webhook: webhookLeads,
        ads: metaLeads + googleLeads + webhookLeads,
        inBin: deletedLeads,
      },
      lastIngested: lastIngested.map((l) => ({
        id: l.id,
        name: l.name,
        phone: l.phone,
        leadSource: l.leadSource,
        status: l.status,
        createdAt: l.createdAt,
        campaignName: l.campaign?.name || null,
        platform: (l.campaign as any)?.platform || null,
      })),
      backups: {
        dir: 'backups/db',
        count: backups.length,
        latest: backups[0] || null,
        items: backups,
      },
      liveLogs,
      auditLogs,
    };
  },

  listBackups() {
    return listLocalBackups();
  },

  async createBackup() {
    return runLocalDbBackup('manual');
  },

  liveLogs(limit = 100) {
    return listLiveLogs(limit);
  },
};
