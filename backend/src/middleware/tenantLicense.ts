import type { Request, Response, NextFunction } from 'express';
import { prisma } from '../config/prisma';
import { isSuperAdminRole } from '../modules/auth/permissions-map';
import { parseModules } from '../modules/platform/platform.service';
import { fail } from '../utils/response';

// In-memory cache for organization licensed modules (TTL: 30s)
const licenseCache = new Map<string, { modules: string[]; at: number }>();
const LICENSE_TTL_MS = 30_000;

export function invalidateLicenseCache(subOrg?: string) {
  if (subOrg) licenseCache.delete(subOrg.toLowerCase());
  else licenseCache.clear();
}

async function getCompanyModules(subOrganization: string): Promise<string[]> {
  const key = subOrganization.toLowerCase().trim();
  const cached = licenseCache.get(key);
  if (cached && Date.now() - cached.at < LICENSE_TTL_MS) {
    return cached.modules;
  }

  const org = await prisma.organization.findFirst({
    where: {
      OR: [
        { name: { equals: subOrganization, mode: 'insensitive' } },
        { code: { equals: subOrganization, mode: 'insensitive' } },
      ],
      deletedAt: null,
    },
    select: { tagLine: true, isActive: true },
  });

  if (!org || !org.isActive) {
    const mods = parseModules(org?.tagLine);
    licenseCache.set(key, { modules: mods, at: Date.now() });
    return mods;
  }

  const mods = parseModules(org.tagLine);
  licenseCache.set(key, { modules: mods, at: Date.now() });
  return mods;
}

export function requireModuleLicense(suite: 'HRMS' | 'CRM' | 'ERP') {
  return async (req: Request, res: Response, next: NextFunction) => {
    // If not authenticated or superadmin, bypass license check
    if (!req.user || isSuperAdminRole(req.user.roleName ?? req.user.role)) {
      return next();
    }

    const subOrg = req.user.subOrganization;
    if (!subOrg) {
      return next();
    }

    try {
      const enabledModules = await getCompanyModules(subOrg);
      if (!enabledModules.includes(suite)) {
        return res.status(403).json(
          fail(`The ${suite} suite is not enabled or licensed for your organization (${subOrg}). Please contact your administrator.`),
        );
      }
      return next();
    } catch (err) {
      console.warn(`License check failed for ${subOrg}:`, err);
      return next();
    }
  };
}
