import type { Request, Response, NextFunction } from 'express';
import { maintenanceService, type ModuleMaintenanceConfig } from '../modules/platform/maintenance.service';
import { isSuperAdminRole } from '../modules/auth/permissions-map';
import jwt from 'jsonwebtoken';

/**
 * Paths that are NEVER blocked by maintenance mode.
 */
const ALWAYS_EXEMPT_PATHS = [
  '/health',
  '/api/auth/branding',
  '/api/platform/maintenance-bypass',
  '/privacypolicy',
  '/termsofservice',
  '/terms',
  '/contactus',
  '/api/contactus',
  '/api/contact-us',
];

function isSuperAdminFromToken(req: Request): boolean {
  if (req.user && isSuperAdminRole(req.user.roleName ?? req.user.role)) {
    return true;
  }
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith('Bearer ')) {
    try {
      const decoded = jwt.decode(authHeader.slice(7)) as jwt.JwtPayload | null;
      const role = String(decoded?.roleName ?? decoded?.role ?? '');
      if (isSuperAdminRole(role)) return true;
    } catch {}
  }
  return false;
}

function matchesTargetPlatform(configPlatform?: string, req?: Request): boolean {
  if (!configPlatform || configPlatform === 'both') return true;
  const platformHeader = (req?.headers['x-client-platform'] as string)?.toLowerCase();
  const isApp = platformHeader === 'app' || !!req?.headers['x-app-version'];
  const isWeb = !isApp;

  if (configPlatform === 'web' && isApp) return false; // App users allowed through
  if (configPlatform === 'app' && isWeb) return false; // Web users allowed through
  return true;
}

function matchModule(path: string): 'CRM' | 'HRMS' | 'ERP' | 'COLLAB' | null {
  const p = path.toLowerCase();
  if (p.startsWith('/api/crm') || p.startsWith('/api/hub') || p.startsWith('/crm/api')) {
    return 'CRM';
  }
  if (
    p.startsWith('/api/leave') ||
    p.startsWith('/api/attendance') ||
    p.startsWith('/api/salary') ||
    p.startsWith('/api/approvals') ||
    p.startsWith('/api/letters') ||
    p.startsWith('/api/reimbursements') ||
    p.startsWith('/api/recruitment')
  ) {
    return 'HRMS';
  }
  if (
    p.startsWith('/api/projects') ||
    p.startsWith('/api/work-orders') ||
    p.startsWith('/api/erp') ||
    p.startsWith('/api/boq') ||
    p.startsWith('/api/tenders') ||
    p.startsWith('/api/tender-applications') ||
    p.startsWith('/api/dpr')
  ) {
    return 'ERP';
  }
  if (
    p.startsWith('/api/chat') ||
    p.startsWith('/api/meetings') ||
    p.startsWith('/api/tracking') ||
    p.startsWith('/api/tasks')
  ) {
    return 'COLLAB';
  }
  return null;
}

function sendMaintenanceBlock(res: Response, scope: string, config: ModuleMaintenanceConfig, estimatedEndTime?: string | null) {
  return res.status(503).json({
    success: false,
    code: 'MAINTENANCE_MODE',
    error: config.message || `${config.title || 'Module'} is currently undergoing maintenance.`,
    maintenance: {
      scope,
      title: config.title,
      message: config.message,
      platform: config.platform || 'both',
      estimatedEndTime: estimatedEndTime ?? null,
    },
  });
}

/**
 * Global and Modular maintenance middleware.
 * - Global maintenance blocks all non-exempt API routes.
 * - Modular maintenance blocks only the specific module under maintenance.
 * - Platform targeted: can selectively block web only, app only, or both.
 * - 24-hour bypass token (via OTP) exempts the authorized session device.
 * - Superadmin is always exempt across all routes and modules.
 */
export async function maintenanceMiddleware(req: Request, res: Response, next: NextFunction) {
  const path = req.path;

  // Always exempt health and public informational endpoints
  if (ALWAYS_EXEMPT_PATHS.some((exempt) => path === exempt || path.startsWith(exempt + '/'))) {
    return next();
  }

  // Superadmin platform administration routes are always accessible
  if (path.startsWith('/api/platform')) {
    return next();
  }

  // Fast bypass for Superadmin credentials
  if (isSuperAdminFromToken(req)) {
    return next();
  }

  // 24-Hour Emergency Maintenance Bypass Check
  const bypassToken = (req.headers['x-maintenance-bypass'] as string) || (req.query.maintenance_bypass as string);
  if (bypassToken && maintenanceService.verifyBypassToken(bypassToken)) {
    return next();
  }

  try {
    const policy = await maintenanceService.getPolicy();

    // 1. Global / Platform-wide Maintenance
    if (policy.global.enabled && matchesTargetPlatform(policy.global.platform, req)) {
      // Allow login endpoint so Superadmin can authenticate
      if (path === '/api/auth/login' || path === '/api/auth/token') {
        return next();
      }
      return sendMaintenanceBlock(res, 'GLOBAL', policy.global, policy.estimatedEndTime);
    }

    // 2. Modular Maintenance
    const moduleKey = matchModule(path);
    if (moduleKey && policy.modules[moduleKey]?.enabled && matchesTargetPlatform(policy.modules[moduleKey].platform, req)) {
      return sendMaintenanceBlock(res, moduleKey, policy.modules[moduleKey], policy.estimatedEndTime);
    }
  } catch (err) {
    // If maintenance check fails, fail open to avoid accidental system outage
    console.warn('Maintenance middleware check error:', err);
  }

  return next();
}
