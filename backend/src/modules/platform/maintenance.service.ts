import { prisma } from '../../config/prisma';
import { redis, connectRedis } from '../../config/redis';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import bcrypt from 'bcryptjs';
import { env } from '../../config/env';
import { sendOtpEmail } from '../../utils/mailer';

export const MAINTENANCE_POLICY_KEY = 'maintenance_policy';
const REDIS_CACHE_KEY = 'platform:maintenance_policy';
const CACHE_TTL_SECONDS = 30;

const BYPASS_EMAIL = 'it.nbdeveloper@gmail.com';
const BYPASS_OTP_REDIS_KEY = 'platform:maintenance_bypass_otp';
const BYPASS_SESSION_PREFIX = 'platform:maintenance_bypass_session:';
const OTP_TTL_SECONDS = 600; // 10 minutes
const BYPASS_DURATION_MS = 24 * 60 * 60 * 1000; // 24 hours

export type MaintenancePlatform = 'both' | 'web' | 'app';

export interface ModuleMaintenanceConfig {
  enabled: boolean;
  title: string;
  message: string;
  platform?: MaintenancePlatform;
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

export interface BypassVerifyResult {
  token: string;
  expiresAt: string;
}

export const DEFAULT_MAINTENANCE_POLICY: MaintenancePolicy = {
  global: {
    enabled: false,
    title: 'Platform Under Scheduled Maintenance',
    message: 'The entire platform is currently undergoing scheduled maintenance. We will be back shortly.',
    platform: 'both',
  },
  modules: {
    CRM: {
      enabled: false,
      title: 'NB CRM Under Maintenance',
      message: 'CRM and Lead services are currently undergoing scheduled upgrades.',
      platform: 'both',
    },
    HRMS: {
      enabled: false,
      title: 'NB HRMS Under Maintenance',
      message: 'HRMS, Attendance, and Leave services are currently undergoing maintenance.',
      platform: 'both',
    },
    ERP: {
      enabled: false,
      title: 'NB ERP Under Maintenance',
      message: 'ERP, Projects, and Vendor services are currently undergoing maintenance.',
      platform: 'both',
    },
    COLLAB: {
      enabled: false,
      title: 'Collaboration Services Under Maintenance',
      message: 'Chat, Video Meetings, and Tracking services are currently undergoing maintenance.',
      platform: 'both',
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
          platform: 'both',
          ...(parsed.global ?? {}),
        },
        modules: {
          CRM: { ...DEFAULT_MAINTENANCE_POLICY.modules.CRM, platform: 'both', ...(parsed.modules?.CRM ?? {}) },
          HRMS: { ...DEFAULT_MAINTENANCE_POLICY.modules.HRMS, platform: 'both', ...(parsed.modules?.HRMS ?? {}) },
          ERP: { ...DEFAULT_MAINTENANCE_POLICY.modules.ERP, platform: 'both', ...(parsed.modules?.ERP ?? {}) },
          COLLAB: { ...DEFAULT_MAINTENANCE_POLICY.modules.COLLAB, platform: 'both', ...(parsed.modules?.COLLAB ?? {}) },
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

  async requestBypassOtp(superadminPassword: string): Promise<{ success: boolean; message: string; cooldownRemaining?: number }> {
    const trimmedPass = (superadminPassword || '').trim();
    if (!trimmedPass) {
      return {
        success: false,
        message: 'Superadmin password is required.',
      };
    }

    // Verify Superadmin Password before generating or sending any OTP
    const superadminUser = await prisma.user.findUnique({
      where: { username: 'superadmin' },
      select: { id: true, passwordHash: true, isActive: true },
    });

    if (!superadminUser || !superadminUser.passwordHash) {
      return {
        success: false,
        message: 'Superadmin account not configured.',
      };
    }

    const passwordMatch = await bcrypt.compare(trimmedPass, superadminUser.passwordHash);
    if (!passwordMatch) {
      return {
        success: false,
        message: 'Invalid Superadmin password.',
      };
    }

    await connectRedis().catch(() => {});

    // Check 60-second cooldown
    try {
      const existing = await redis.get(`${BYPASS_OTP_REDIS_KEY}:cooldown`);
      if (existing) {
        const ttl = await redis.ttl(`${BYPASS_OTP_REDIS_KEY}:cooldown`);
        return {
          success: false,
          message: `Please wait ${ttl > 0 ? ttl : 60} seconds before requesting a new code.`,
          cooldownRemaining: ttl > 0 ? ttl : 60,
        };
      }
    } catch {}

    // Generate cryptographically secure 6-digit numeric OTP
    const otp = String(crypto.randomInt(100000, 999999));

    try {
      await redis.set(BYPASS_OTP_REDIS_KEY, otp, { EX: OTP_TTL_SECONDS });
      await redis.set(`${BYPASS_OTP_REDIS_KEY}:cooldown`, '1', { EX: 60 });
    } catch (err) {
      console.warn('Redis unavailable for maintenance OTP:', err);
    }

    // Send email to it.nbdeveloper@gmail.com
    await sendOtpEmail(
      BYPASS_EMAIL,
      otp,
      {
        subject: 'NB Platform — Maintenance Bypass Session OTP',
        heading: 'NB INFRA PROJECTS LTD.',
        purpose: '24-Hour Maintenance Session Access Authorization',
      }
    );

    return {
      success: true,
      message: `A 6-digit verification code has been sent to ${BYPASS_EMAIL}.`,
    };
  },

  async verifyBypassOtp(inputOtp: string): Promise<BypassVerifyResult> {
    const trimmed = (inputOtp || '').trim();
    if (!trimmed || trimmed.length !== 6) {
      throw new Error('Please enter a valid 6-digit verification code.');
    }

    await connectRedis().catch(() => {});
    let valid = false;

    try {
      const stored = await redis.get(BYPASS_OTP_REDIS_KEY);
      if (stored && stored === trimmed) {
        valid = true;
        await redis.del(BYPASS_OTP_REDIS_KEY);
        await redis.del(`${BYPASS_OTP_REDIS_KEY}:cooldown`);
      }
    } catch {}

    if (!valid) {
      throw new Error('Invalid or expired verification code.');
    }

    const expiresAtDate = new Date(Date.now() + BYPASS_DURATION_MS);
    const expiresAt = expiresAtDate.toISOString();

    const token = jwt.sign(
      {
        sub: BYPASS_EMAIL,
        purpose: 'MAINTENANCE_BYPASS',
        iat: Math.floor(Date.now() / 1000),
      },
      env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    try {
      const sessionKey = `${BYPASS_SESSION_PREFIX}${token.slice(-16)}`;
      await redis.set(sessionKey, JSON.stringify({ email: BYPASS_EMAIL, expiresAt }), {
        EX: 24 * 3600,
      });
    } catch {}

    return { token, expiresAt };
  },

  verifyBypassToken(token: string): boolean {
    if (!token || typeof token !== 'string') return false;
    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as jwt.JwtPayload;
      if (decoded && decoded.purpose === 'MAINTENANCE_BYPASS') {
        return true;
      }
    } catch {}
    return false;
  },
};
