import type { Request, Response, NextFunction } from 'express';
import { maintenanceService, type ModuleMaintenanceConfig } from '../modules/platform/maintenance.service';
import { isSuperAdminRole } from '../modules/auth/permissions-map';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';

/**
 * Paths that are NEVER blocked by maintenance mode.
 */
const ALWAYS_EXEMPT_PATHS = [
  '/health',
  '/api/auth/branding',
  '/privacypolicy',
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
      estimatedEndTime: estimatedEndTime ?? null,
    },
  });
}

/**
 * Global and Modular maintenance middleware.
 * - Global maintenance blocks all non-exempt API routes.
 * - Modular maintenance blocks only the specific module under maintenance.
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

  try {
    const policy = await maintenanceService.getPolicy();

    // 1. Global / Platform-wide Maintenance
    if (policy.global.enabled) {
      // Allow login endpoint so Superadmin can authenticate
      if (path === '/api/auth/login' || path === '/api/auth/token') {
        return next();
      }
      return sendMaintenanceBlock(res, 'GLOBAL', policy.global, policy.estimatedEndTime);
    }

    // 2. Modular Maintenance
    const moduleKey = matchModule(path);
    if (moduleKey && policy.modules[moduleKey]?.enabled) {
      return sendMaintenanceBlock(res, moduleKey, policy.modules[moduleKey], policy.estimatedEndTime);
    }
  } catch (err) {
    // If maintenance check fails, fail open to avoid accidental system outage
    console.warn('Maintenance middleware check error:', err);
  }

  return next();
}
