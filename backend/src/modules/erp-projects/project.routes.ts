import { Router, Request, Response } from 'express';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { projectService } from './project.service';
import { towerService } from './tower.service';
import { paymentTermService } from './payment-term.service';
import { pricingComponentService } from './pricing-component.service';

export const projectRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

projectRouter.get(
  '/',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = String(req.query.includeInactive ?? '') === 'true';
      const data = await projectService.list({ includeInactive });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list projects'));
    }
  },
);

projectRouter.get(
  '/next-number',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      return res.json(ok(await projectService.nextNumber()));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

projectRouter.post(
  '/upload',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('File is required'));
      const folder = String(req.body?.folder ?? 'erp/projects');
      const url = await uploadService.uploadToCloudinary(req.file, folder);
      return res.json(
        ok({
          url,
          fileName: req.file.originalname || null,
          mimeType: req.file.mimetype || null,
          fileSize: req.file.size ?? null,
        }),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Upload failed'));
    }
  },
);

// --- Payment Plans ---
projectRouter.get(
  '/payment-plans',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = req.query.includeInactive === 'true';
      return res.json(ok(await paymentTermService.listPlans(includeInactive)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list payment plans'));
    }
  },
);

projectRouter.post(
  '/payment-plans',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await paymentTermService.createPlan(req.body ?? {});
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create payment plan'));
    }
  },
);

projectRouter.get(
  '/payment-plans/:planId',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await paymentTermService.getPlanById(p(req.params.planId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to get payment plan'));
    }
  },
);

projectRouter.patch(
  '/payment-plans/:planId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await paymentTermService.updatePlan(p(req.params.planId), req.body ?? {});
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update payment plan'));
    }
  },
);

projectRouter.delete(
  '/payment-plans/:planId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await paymentTermService.deletePlan(p(req.params.planId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to delete payment plan'));
    }
  },
);

projectRouter.post(
  '/payment-plans/:planId/duplicate',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.status(201).json(ok(await paymentTermService.duplicatePlan(p(req.params.planId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to duplicate payment plan'));
    }
  },
);

// --- Payment Terms (Milestones) ---
projectRouter.get(
  '/payment-terms',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const planId = req.query.planId ? String(req.query.planId) : undefined;
      return res.json(ok(await paymentTermService.list(planId)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list payment terms'));
    }
  },
);

projectRouter.post(
  '/payment-terms',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await paymentTermService.create(req.body ?? {});
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create payment term'));
    }
  },
);

projectRouter.patch(
  '/payment-terms/:termId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await paymentTermService.update(p(req.params.termId), req.body ?? {});
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update payment term'));
    }
  },
);

projectRouter.delete(
  '/payment-terms/:termId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await paymentTermService.delete(p(req.params.termId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to delete payment term'));
    }
  },
);

projectRouter.get(
  '/pricing-components',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = req.query.includeInactive === 'true';
      return res.json(ok(await pricingComponentService.list(includeInactive)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list pricing components'));
    }
  },
);

projectRouter.post(
  '/pricing-components',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await pricingComponentService.create(req.body ?? {});
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to create pricing component'));
    }
  },
);

projectRouter.patch(
  '/pricing-components/:componentId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await pricingComponentService.update(p(req.params.componentId), req.body ?? {});
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to update pricing component'));
    }
  },
);

projectRouter.delete(
  '/pricing-components/:componentId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await pricingComponentService.delete(p(req.params.componentId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to delete pricing component'));
    }
  },
);

projectRouter.post(
  '/pricing-components/reset',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (_req: Request, res: Response) => {
    try {
      return res.json(ok(await pricingComponentService.resetDefaults()));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to reset pricing components'));
    }
  },
);

projectRouter.get(
  '/:id',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await projectService.getById(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
    }
  },
);

projectRouter.post(
  '/',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await projectService.create(req.body ?? {}, req.user!.id);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Create failed'));
    }
  },
);

projectRouter.patch(
  '/:id',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await projectService.update(p(req.params.id), req.body ?? {}, req.user!.id);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update failed'));
    }
  },
);

projectRouter.delete(
  '/:id',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await projectService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Delete failed'));
    }
  },
);

projectRouter.get(
  '/:id/towers',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await towerService.list(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list towers'));
    }
  },
);

projectRouter.post(
  '/:id/towers',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await towerService.create(p(req.params.id), req.body ?? {});
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Create tower failed'));
    }
  },
);

projectRouter.get(
  '/:id/towers/:towerId',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await towerService.getById(p(req.params.id), p(req.params.towerId))));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Tower not found'));
    }
  },
);

projectRouter.patch(
  '/:id/towers/:towerId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(await towerService.update(p(req.params.id), p(req.params.towerId), req.body ?? {})),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update tower failed'));
    }
  },
);

projectRouter.delete(
  '/:id/towers/:towerId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await towerService.remove(p(req.params.id), p(req.params.towerId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Delete tower failed'));
    }
  },
);

projectRouter.post(
  '/:id/towers/:towerId/regenerate-units',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(await towerService.regenerateUnits(p(req.params.id), p(req.params.towerId))),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Regenerate failed'));
    }
  },
);

projectRouter.patch(
  '/:id/towers/:towerId/units/:unitId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(
          await towerService.updateUnit(
            p(req.params.id),
            p(req.params.towerId),
            p(req.params.unitId),
            req.body ?? {},
          ),
        ),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update unit failed'));
    }
  },
);

projectRouter.post(
  '/:id/towers/:towerId/units',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.status(201).json(
        ok(
          await towerService.createUnit(
            p(req.params.id),
            p(req.params.towerId),
            req.body ?? {},
          ),
        ),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Create unit failed'));
    }
  },
);

projectRouter.delete(
  '/:id/towers/:towerId/units/:unitId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(
          await towerService.deleteUnit(
            p(req.params.id),
            p(req.params.towerId),
            p(req.params.unitId),
          ),
        ),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Delete unit failed'));
    }
  },
);

projectRouter.post(
  '/:id/towers/:towerId/units/batch-apply',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(
          await towerService.batchApplyUnits(
            p(req.params.id),
            p(req.params.towerId),
            req.body ?? {},
          ),
        ),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Batch apply failed'));
    }
  },
);

