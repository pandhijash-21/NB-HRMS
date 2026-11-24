import { Router, type Request, type Response, type NextFunction } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSuperAdmin } from '../../middleware/rbac';
import { isSuperAdminRole, isSystemAdminRole } from '../auth/permissions-map';
import { auditController } from './audit.controller';
import { fail } from '../../utils/response';

export function requireAuditPermission(req: Request, res: Response, next: NextFunction) {
  if (!req.user) return res.status(401).json(fail('Unauthenticated'));
  const role = req.user.roleName ?? req.user.role;
  if (isSuperAdminRole(role) || isSystemAdminRole(role)) return next();
  const perms = req.user.permissions ?? {};
  const hasAudit = (perms.AUDIT ?? []).includes('READ');
  const hasReports = (perms.REPORTS ?? []).includes('READ');
  if (hasAudit || hasReports) return next();
  return res.status(403).json(fail('Access denied: AUDIT or REPORTS READ permission required'));
}

export const adminAuditRouter = Router();

adminAuditRouter.use(requireAuth, requireAuditPermission);

// Tenant Admin employee-wise audit log endpoints
adminAuditRouter.get('/', auditController.getAdminLogs);
adminAuditRouter.get('/employees', auditController.getAdminEmployees);
adminAuditRouter.get('/stats', auditController.getAdminStats);

export const superadminAuditRouter = Router();

superadminAuditRouter.use(requireAuth, requireSuperAdmin());

// Superadmin Admin > Employee-wise hierarchical drill-down endpoints
superadminAuditRouter.get('/hierarchy', auditController.getSuperadminHierarchy);
superadminAuditRouter.get('/organizations/:organizationId/employees', auditController.getSuperadminTenantEmployees);
superadminAuditRouter.get('/', auditController.getSuperadminLogs);
