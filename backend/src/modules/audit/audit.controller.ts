import type { Request, Response } from 'express';
import { auditService } from './audit.service';
import { ok, fail } from '../../utils/response';

export const auditController = {
  /**
   * GET /api/admin/audit-logs
   * Scoped to caller's tenant organization.
   */
  async getAdminLogs(req: Request, res: Response) {
    try {
      const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
      const actorId = typeof req.query.actorId === 'string' ? req.query.actorId : undefined;
      const tableName = typeof req.query.tableName === 'string' ? req.query.tableName : undefined;
      const search = typeof req.query.search === 'string' ? req.query.search : undefined;
      const startDate = typeof req.query.startDate === 'string' ? req.query.startDate : undefined;
      const endDate = typeof req.query.endDate === 'string' ? req.query.endDate : undefined;
      const page = req.query.page ? Number(req.query.page) : 1;
      const limit = req.query.limit ? Number(req.query.limit) : 50;

      const result = await auditService.listLogs(req.user ?? {}, {
        employeeId,
        actorId,
        tableName,
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
