import { Router, Request, Response } from 'express';
import { SalaryColumnCategory, SalaryRecordStatus } from '@prisma/client';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { salaryService } from './salary.service';
import { payCommissionService } from './payCommission.service';
import {
  createColumnSchema,
  createPayCommissionSchema,
  updateColumnSchema,
  updatePayCommissionSchema,
} from './payCommission.validation';
import { createRecordSchema, createTemplateSchema, updateRecordSchema } from './salary.validation';

export const salaryRouter = Router();

function p(value: string | string[]): string {
  return Array.isArray(value) ? value[0] : value;
}

salaryRouter.get(
  '/pay-commissions',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await payCommissionService.list();
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/pay-commissions',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = createPayCommissionSchema.parse(req.body);
      const data = await payCommissionService.create(body);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/pay-commissions/:id',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await payCommissionService.getById(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.patch(
  '/pay-commissions/:id',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = updatePayCommissionSchema.parse(req.body);
      const data = await payCommissionService.update(p(req.params.id), body);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.delete(
  '/pay-commissions/:id',
  requireAuth,
  requirePermission('SALARY', 'DELETE'),
  async (req: Request, res: Response) => {
    try {
      const data = await payCommissionService.remove(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/pay-commissions/:id/columns',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = createColumnSchema.parse(req.body);
      const data = await payCommissionService.createColumn(p(req.params.id), body);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.patch(
  '/pay-commissions/columns/:columnId',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = updateColumnSchema.parse(req.body);
      const data = await payCommissionService.updateColumn(p(req.params.columnId), body);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.delete(
  '/pay-commissions/columns/:columnId',
  requireAuth,
  requirePermission('SALARY', 'DELETE'),
  async (req: Request, res: Response) => {
    try {
      const data = await payCommissionService.deleteColumn(p(req.params.columnId));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/structures/status',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await salaryService.getStructureStatus();
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/templates',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const designationId = req.query.designationId as string | undefined;
      const payCommissionCode = req.query.payCommissionCode as string | undefined;
      const data = await salaryService.listTemplates({ designationId, payCommissionCode });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/templates/by-designation/:designationId/:commission',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.getTemplateByDesignationAndCommission(
        p(req.params.designationId),
        p(req.params.commission),
      );
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/templates',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = createTemplateSchema.parse(req.body);
      const data = await salaryService.createTemplate(
        body.designationId,
        body.payCommissionCode,
        req.user!.id,
      );
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.delete(
  '/templates/:id',
  requireAuth,
  requirePermission('SALARY', 'DELETE'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.deleteTemplate(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.patch(
  '/templates/:templateId/column-visibility',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const { columnVisibility } = req.body as { columnVisibility: Record<string, boolean> };
      if (!columnVisibility || typeof columnVisibility !== 'object') {
        return res.status(400).json(fail('columnVisibility object is required'));
      }
      const data = await salaryService.updateTemplateColumnVisibility(
        p(req.params.templateId),
        columnVisibility,
      );
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/templates/:templateId/rules',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.getTemplateRules(p(req.params.templateId));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/column-definitions/:commission',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.getColumnDefinitions(p(req.params.commission));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.put(
  '/templates/:templateId/rules/:columnIdentifier',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const category = (req.query.category as SalaryColumnCategory) ?? 'EARNING';
      const data = await salaryService.upsertColumnRule(
        p(req.params.templateId),
        p(req.params.columnIdentifier),
        category,
        req.body,
      );
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/compute',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const { templateId, overrides, employeeId, employeeRules } = req.body as {
        templateId: string;
        overrides?: Record<string, number>;
        employeeId?: number;
        employeeRules?: Record<string, import('./salary.types').ColumnRuleInput> | null;
      };
      const data = await salaryService.computePreview(templateId, overrides, {
        employeeId,
        employeeRules,
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

/** Employee-only salary config — never writes to salary_structure_template or salary_column_rules */
salaryRouter.patch(
  '/employees/:employeeId/profile',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const { payCommissionCode, columnOverrides, columnRules } = req.body as {
        payCommissionCode?: string;
        columnOverrides?: Record<string, number> | null;
        columnRules?: Record<string, import('./salary.types').ColumnRuleInput> | null;
      };
      if (!payCommissionCode && columnOverrides === undefined && columnRules === undefined) {
        return res.status(400).json(fail('Nothing to update'));
      }
      const data = await salaryService.updateEmployeePayProfile(
        Number(req.params.employeeId),
        { payCommissionCode, columnOverrides, columnRules },
        req.user!.id,
      );
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/employees/:employeeId/profile',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const profile = await salaryService.getEmployeePayProfile(Number(req.params.employeeId));
      const latest = await salaryService.getLatestFinalizedRecord(Number(req.params.employeeId));
      return res.json(ok({ profile, latestFinalizedRecord: latest }));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/employees/:employeeId/salary-preview',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.getEmployeeSalaryPreview(Number(req.params.employeeId));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/records',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = createRecordSchema.parse(req.body);
      const data = await salaryService.createSalaryRecord(
        body.employeeId,
        body.salaryMonth,
        body.salaryYear,
        req.user!.id,
      );
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/records',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.listRecords({
        employeeId: req.query.employeeId ? Number(req.query.employeeId) : undefined,
        designationId: req.query.designationId as string | undefined,
        payCommissionCode: req.query.payCommissionCode as string | undefined,
        salaryMonth: req.query.salaryMonth ? Number(req.query.salaryMonth) : undefined,
        salaryYear: req.query.salaryYear ? Number(req.query.salaryYear) : undefined,
        status: req.query.status as SalaryRecordStatus | undefined,
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/records/:id',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.getRecord(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/employees/:employeeId/monthly-overview',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const year = Number(req.query.year ?? new Date().getFullYear());
      const month = Number(req.query.month ?? new Date().getMonth() + 1);
      const data = await salaryService.getEmployeeMonthlyOverview(employeeId, year, month);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/employees/:employeeId/monthly-calc',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const year = Number(req.body?.year ?? new Date().getFullYear());
      const month = Number(req.body?.month ?? new Date().getMonth() + 1);
      const data = await salaryService.calculateMonthlySalary({
        employeeId,
        year,
        month,
        persist: false,
        createdBy: String((req.user as any)?.id ?? 'unknown'),
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/employees/:employeeId/monthly-save',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const year = Number(req.body?.year ?? new Date().getFullYear());
      const month = Number(req.body?.month ?? new Date().getMonth() + 1);
      const data = await salaryService.calculateMonthlySalary({
        employeeId,
        year,
        month,
        persist: true,
        createdBy: String((req.user as any)?.id ?? 'unknown'),
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/employees/:employeeId/records',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const salaryYear = req.query.salaryYear ? Number(req.query.salaryYear) : undefined;
      const salaryMonth = req.query.salaryMonth ? Number(req.query.salaryMonth) : undefined;
      const data = await salaryService.listEmployeeRecords(employeeId, { salaryYear, salaryMonth });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/employees/:employeeId/slip/:recordId',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const recordId = p(req.params.recordId);
      const record = await salaryService.getRecord(recordId);
      if (record.employeeId !== employeeId) {
        return res.status(403).json(fail('Record does not belong to this employee'));
      }
      if (record.status !== 'PAID') {
        return res.status(400).json(fail('Salary slip is available only for paid records'));
      }
      const data = await salaryService.getSlipData(recordId);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/records/:id/slip',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.getSlipData(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.patch(
  '/records/:id',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = updateRecordSchema.parse(req.body);
      const data = await salaryService.updateSalaryRecord(p(req.params.id), body.overrides);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/records/:id/finalize',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.markRecordPaid(p(req.params.id), req.user!.id);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/records/:id/mark-paid',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.markRecordPaid(p(req.params.id), req.user!.id);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.post(
  '/records/:id/mark-unpaid',
  requireAuth,
  requirePermission('SALARY', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await salaryService.markRecordUnpaid(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

salaryRouter.get(
  '/payroll/month',
  requireAuth,
  requirePermission('SALARY', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const year = Number(req.query.year ?? new Date().getFullYear());
      const month = Number(req.query.month ?? new Date().getMonth() + 1);
      const data = await salaryService.getMonthPayrollOverview(year, month);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
