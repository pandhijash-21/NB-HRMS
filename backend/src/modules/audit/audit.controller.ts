import type { Request, Response } from 'express';
import { auditService } from './audit.service';
import { activityTracker } from './activity-tracker.service';
import { ok, fail } from '../../utils/response';

export const auditController = {
  /**
   * POST /api/admin/audit-logs/track
   * Ingest client-side click and page view events.
   */
  async trackClientActivity(req: Request, res: Response) {
    try {
      const user = req.user;
      if (!user?.id) return res.status(401).json(fail('Unauthenticated'));

      const rawEvents = Array.isArray(req.body?.events)
        ? req.body.events
        : req.body ? [req.body] : [];

      if (!rawEvents.length) {
        return res.json(ok({ tracked: 0 }));
      }

      const ip = req.ip;
      const userAgent = req.headers['user-agent'] ? String(req.headers['user-agent']) : null;
      const empId = typeof user.employeeId === 'number' ? user.employeeId : null;

      activityTracker.enqueueBatch(
        rawEvents.map((ev: any) => ({
          tableName: ev.type === 'PAGE_VIEW' ? 'PAGE_VIEW' : 'USER_CLICK',
          recordId: ev.screen ? String(ev.screen).slice(0, 255) : 'client',
          employeeId: empId,
          fieldName: ev.target ? String(ev.target).slice(0, 255) : 'User Click',
          oldValue: ev.screen ? `Screen: ${ev.screen}` : null,
          newValue: ev.metadata ? String(typeof ev.metadata === 'object' ? JSON.stringify(ev.metadata) : ev.metadata).slice(0, 500) : null,
          changedBy: user.id,
          changeReason: ev.reason ? String(ev.reason).slice(0, 500) : 'Client UI interaction',
          ipAddress: ip,
          userAgent,
        })),
      );

      return res.json(ok({ tracked: rawEvents.length }));
    } catch (err: unknown) {
      console.error('[auditController.trackClientActivity error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to track activity'));
    }
  },
  /**
   * GET /api/admin/audit-logs
   * Scoped to caller's tenant organization.
   */
  async getAdminLogs(req: Request, res: Response) {
    try {
      const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
      const actorId = typeof req.query.actorId === 'string' ? req.query.actorId : undefined;
      const tableName = typeof req.query.tableName === 'string' ? req.query.tableName : undefined;
      const category = typeof req.query.category === 'string' ? (req.query.category as any) : undefined;
      const search = typeof req.query.search === 'string' ? req.query.search : undefined;
      const startDate = typeof req.query.startDate === 'string' ? req.query.startDate : undefined;
      const endDate = typeof req.query.endDate === 'string' ? req.query.endDate : undefined;
      const page = req.query.page ? Number(req.query.page) : 1;
      const limit = req.query.limit ? Number(req.query.limit) : 50;

      const result = await auditService.listLogs(req.user ?? {}, {
        employeeId,
        actorId,
        tableName,
        category,
        search,
        startDate,
        endDate,
        page,
        limit,
      });

      return res.json(ok(result));
    } catch (err: unknown) {
      console.error('[auditController.getAdminLogs error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch audit logs'));
    }
  },

  /**
   * GET /api/admin/audit-logs/employees
   * Employee-wise summary for tenant admin dropdown / list.
   */
  async getAdminEmployees(req: Request, res: Response) {
    try {
      const search = typeof req.query.search === 'string' ? req.query.search : undefined;
      const employees = await auditService.listEmployeesWithLogs(req.user ?? {}, { search });
      return res.json(ok(employees));
    } catch (err: unknown) {
      console.error('[auditController.getAdminEmployees error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch employees with logs'));
    }
  },

  /**
   * GET /api/admin/audit-logs/stats
   * Tenant KPI metrics.
   */
  async getAdminStats(req: Request, res: Response) {
    try {
      const stats = await auditService.getAuditStats(req.user ?? {});
      return res.json(ok(stats));
    } catch (err: unknown) {
      console.error('[auditController.getAdminStats error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch audit stats'));
    }
  },

  /**
   * GET /api/platform/audit-logs/hierarchy
   * Superadmin Level 1: Organization & Admin list with aggregate log stats.
   */
  async getSuperadminHierarchy(_req: Request, res: Response) {
    try {
      const hierarchy = await auditService.listSuperadminHierarchy();
      return res.json(ok(hierarchy));
    } catch (err: unknown) {
      console.error('[auditController.getSuperadminHierarchy error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch superadmin hierarchy'));
    }
  },

  /**
   * GET /api/platform/audit-logs/organizations/:organizationId/employees
   * Superadmin Level 2: Employees of a selected tenant company.
   */
  async getSuperadminTenantEmployees(req: Request, res: Response) {
    try {
      const organizationId = Array.isArray(req.params.organizationId)
        ? req.params.organizationId[0]
        : req.params.organizationId;
      const search = typeof req.query.search === 'string' ? req.query.search : undefined;

      const employees = await auditService.listEmployeesWithLogs(req.user ?? {}, {
        organizationId,
        search,
      });

      return res.json(ok(employees));
    } catch (err: unknown) {
      console.error('[auditController.getSuperadminTenantEmployees error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch organization employees'));
    }
  },

  /**
   * GET /api/platform/audit-logs
   * Superadmin Level 3: Cross-tenant / tenant-drilled logs.
   */
  async getSuperadminLogs(req: Request, res: Response) {
    try {
      const organizationId = typeof req.query.organizationId === 'string' ? req.query.organizationId : undefined;
      const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
      const actorId = typeof req.query.actorId === 'string' ? req.query.actorId : undefined;
      const tableName = typeof req.query.tableName === 'string' ? req.query.tableName : undefined;
      const category = typeof req.query.category === 'string' ? (req.query.category as any) : undefined;
      const search = typeof req.query.search === 'string' ? req.query.search : undefined;
      const startDate = typeof req.query.startDate === 'string' ? req.query.startDate : undefined;
      const endDate = typeof req.query.endDate === 'string' ? req.query.endDate : undefined;
      const page = req.query.page ? Number(req.query.page) : 1;
      const limit = req.query.limit ? Number(req.query.limit) : 50;

      const result = await auditService.listLogs(req.user ?? {}, {
        organizationId,
        employeeId,
        actorId,
        tableName,
        category,
        search,
        startDate,
        endDate,
        page,
        limit,
      });

      return res.json(ok(result));
    } catch (err: unknown) {
      console.error('[auditController.getSuperadminLogs error]:', err);
      return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch superadmin audit logs'));
    }
  },
};
