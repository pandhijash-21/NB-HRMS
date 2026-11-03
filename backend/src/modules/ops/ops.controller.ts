import type { Request, Response } from 'express';
import { ok, fail } from '../../utils/response';
import { isAdminRole } from '../auth/permissions-map';
import { opsService } from './ops.service';

function assertOpsAccess(req: Request) {
  const role = String((req as any).user?.role || '');
  const roleUpper = role.toUpperCase();
  const roleCompact = roleUpper.replace(/[\s_-]+/g, '');
  const allowed =
    isAdminRole(role) ||
    ['ADMIN', 'SUPERADMIN', 'SUPER_ADMIN', 'SYSTEMADMIN', 'SYSTEM_ADMIN', 'ITADMIN'].some(
      (r) => roleUpper === r || roleCompact === r.replace(/_/g, '') || roleUpper.includes(r),
    );
  if (!allowed) {
    const err = new Error('Ops Health is restricted to admins / ITADMIN');
    (err as any).status = 403;
    throw err;
  }
}

function scopeOf(req: Request) {
  return String(req.headers['x-crm-scope'] || req.query.scope || 'NB_DEVELOPER');
}

export const opsController = {
  async dashboard(req: Request, res: Response) {
    try {
      assertOpsAccess(req);
      const data = await opsService.getDashboard(scopeOf(req));
      return res.json(ok(data));
    } catch (err: any) {
      return res.status(err?.status || 500).json(fail(err?.message || 'Ops dashboard failed'));
    }
  },

  async backups(req: Request, res: Response) {
    try {
      assertOpsAccess(req);
      return res.json(ok(opsService.listBackups()));
    } catch (err: any) {
      return res.status(err?.status || 500).json(fail(err?.message || 'List backups failed'));
    }
  },

  async createBackup(req: Request, res: Response) {
    try {
      assertOpsAccess(req);
      const info = await opsService.createBackup();
      return res.json(ok(info));
    } catch (err: any) {
      return res.status(err?.status || 500).json(fail(err?.message || 'Backup failed'));
    }
  },

  async liveLogs(req: Request, res: Response) {
    try {
      assertOpsAccess(req);
      const limit = req.query.limit ? parseInt(String(req.query.limit), 10) : 100;
      return res.json(ok(opsService.liveLogs(limit)));
    } catch (err: any) {
      return res.status(err?.status || 500).json(fail(err?.message || 'Live logs failed'));
    }
  },
};
