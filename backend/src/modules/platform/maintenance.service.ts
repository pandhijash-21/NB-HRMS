import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';

export const MAINTENANCE_POLICY_KEY = 'maintenance_policy';
const REDIS_CACHE_KEY = 'platform:maintenance_policy';
const CACHE_TTL_SECONDS = 30;

export interface ModuleMaintenanceConfig {
  enabled: boolean;
  title: string;
  message: string;
}

export interface MaintenancePolicy {
  global: ModuleMaintenanceConfig;
  modules: {
    CRM: ModuleMaintenanceConfig;
    HRMS: ModuleMaintenanceConfig;
    ERP: ModuleMaintenanceConfig;
    COLLAB: ModuleMaintenanceConfig;
  };
  estimatedEndTime?: string | null;
  allowedRoles: string[];
}

export const DEFAULT_MAINTENANCE_POLICY: MaintenancePolicy = {
  global: {
    enabled: false,
    title: 'Platform Under Scheduled Maintenance',
    message: 'The entire platform is currently undergoing scheduled maintenance. We will be back shortly.',
  },
  modules: {
    CRM: {
      enabled: false,
      title: 'NB CRM Under Maintenance',
      message: 'CRM and Lead services are currently undergoing scheduled upgrades.',
    },
    HRMS: {
      enabled: false,
      title: 'NB HRMS Under Maintenance',
      message: 'HRMS, Attendance, and Leave services are currently undergoing maintenance.',
    },
    ERP: {
      enabled: false,
      title: 'NB ERP Under Maintenance',
      message: 'ERP, Projects, and Vendor services are currently undergoing maintenance.',
    },
    COLLAB: {
      enabled: false,
      title: 'Collaboration Services Under Maintenance',
      message: 'Chat, Video Meetings, and Tracking services are currently undergoing maintenance.',
    },
  },
  estimatedEndTime: null,
  allowedRoles: ['SUPERADMIN'],
};

export const maintenanceService = {
  async getPolicy(): Promise<MaintenancePolicy> {
    try {
      await connectRedis();
      const cached = await redis.get(REDIS_CACHE_KEY);
      if (cached) {
        return JSON.parse(cached) as MaintenancePolicy;
      }
    } catch {
      // Redis unavailable; fall through to database
    }

    const row = await prisma.platformBranding.findUnique({
      where: { key: MAINTENANCE_POLICY_KEY },
      select: { meta: true },
    });

    if (!row?.meta) {
      return DEFAULT_MAINTENANCE_POLICY;
    }

    try {
      const parsed = JSON.parse(row.meta) as MaintenancePolicy;
      const merged: MaintenancePolicy = {
        global: {
          ...DEFAULT_MAINTENANCE_POLICY.global,
          ...(parsed.global ?? {}),
        },
        modules: {
          CRM: { ...DEFAULT_MAINTENANCE_POLICY.modules.CRM, ...(parsed.modules?.CRM ?? {}) },
          HRMS: { ...DEFAULT_MAINTENANCE_POLICY.modules.HRMS, ...(parsed.modules?.HRMS ?? {}) },
          ERP: { ...DEFAULT_MAINTENANCE_POLICY.modules.ERP, ...(parsed.modules?.ERP ?? {}) },
          COLLAB: { ...DEFAULT_MAINTENANCE_POLICY.modules.COLLAB, ...(parsed.modules?.COLLAB ?? {}) },
        },
        estimatedEndTime: parsed.estimatedEndTime ?? null,
        allowedRoles: parsed.allowedRoles ?? ['SUPERADMIN'],
      };

      try {
        await connectRedis();
        await redis.set(REDIS_CACHE_KEY, JSON.stringify(merged), { EX: CACHE_TTL_SECONDS });
      } catch {}

      return merged;
    } catch {
      return DEFAULT_MAINTENANCE_POLICY;
    }
  },

  async setPolicy(input: Partial<MaintenancePolicy>, updatedBy?: string | null): Promise<MaintenancePolicy> {
    const current = await this.getPolicy();
    const updated: MaintenancePolicy = {
      global: {
        ...current.global,
        ...(input.global ?? {}),
      },
      modules: {
        CRM: { ...current.modules.CRM, ...(input.modules?.CRM ?? {}) },
        HRMS: { ...current.modules.HRMS, ...(input.modules?.HRMS ?? {}) },
        ERP: { ...current.modules.ERP, ...(input.modules?.ERP ?? {}) },
        COLLAB: { ...current.modules.COLLAB, ...(input.modules?.COLLAB ?? {}) },
      },
      estimatedEndTime: input.estimatedEndTime !== undefined ? input.estimatedEndTime : current.estimatedEndTime,
      allowedRoles: input.allowedRoles ?? current.allowedRoles,
    };

    await prisma.platformBranding.upsert({
      where: { key: MAINTENANCE_POLICY_KEY },
      create: {
        key: MAINTENANCE_POLICY_KEY,
        url: 'maintenance_policy',
        meta: JSON.stringify(updated),
        updatedBy: updatedBy ?? null,
      },
      update: {
        meta: JSON.stringify(updated),
        updatedBy: updatedBy ?? null,
      },
    });

    try {
      await connectRedis();
      await redis.set(REDIS_CACHE_KEY, JSON.stringify(updated), { EX: CACHE_TTL_SECONDS });
    } catch {}

    return updated;
  },
};
