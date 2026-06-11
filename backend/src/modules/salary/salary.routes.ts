import { Router, Request, Response } from 'express';
import { PayCommissionType, SalaryColumnCategory, SalaryRecordStatus } from '@prisma/client';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireSelfEmployeeOrPermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { salaryService } from './salary.service';
import { createRecordSchema, createTemplateSchema, updateRecordSchema } from './salary.validation';

export const salaryRouter = Router();

function p(value: string | string[]): string {
  return Array.isArray(value) ? value[0] : value;
}

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
      const payCommissionType = req.query.payCommissionType as PayCommissionType | undefined;
      const data = await salaryService.listTemplates({ designationId, payCommissionType });
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
      const commission = p(req.params.commission).toUpperCase() as PayCommissionType;
      if (!['FIFTH', 'SIXTH'].includes(commission)) {
        return res.status(400).json(fail('Invalid pay commission'));
      }
      const data = await salaryService.getTemplateByDesignationAndCommission(
        p(req.params.designationId),
        commission,
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
        body.payCommissionType,
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
      const commission = p(req.params.commission).toUpperCase() as PayCommissionType;
      const data = await salaryService.getColumnDefinitions(commission);
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
      const { payCommissionType, columnOverrides, columnRules } = req.body as {
        payCommissionType?: PayCommissionType;
        columnOverrides?: Record<string, number> | null;
        columnRules?: Record<string, import('./salary.types').ColumnRuleInput> | null;
      };
      if (payCommissionType && !['FIFTH', 'SIXTH'].includes(payCommissionType)) {
        return res.status(400).json(fail('payCommissionType must be FIFTH or SIXTH'));
      }
      if (!payCommissionType && columnOverrides === undefined && columnRules === undefined) {
        return res.status(400).json(fail('Nothing to update'));
      }
      const data = await salaryService.updateEmployeePayProfile(
        Number(req.params.employeeId),
        { payCommissionType, columnOverrides, columnRules },
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
        payCommissionType: req.query.payCommissionType as PayCommissionType | undefined,
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
      const data = await salaryService.finalizeRecord(p(req.params.id), req.user!.id);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
