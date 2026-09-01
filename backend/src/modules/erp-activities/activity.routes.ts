import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { activityService } from './activity.service';

export const activityRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

activityRouter.get(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = String(req.query.includeInactive ?? '') === 'true';
      const data = await activityService.list({ includeInactive });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

activityRouter.get(
  '/admin',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (_req: Request, res: Response) => {
    try {
      return res.json(ok(await activityService.adminList()));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

activityRouter.get(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await activityService.getById(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

activityRouter.post(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.status(201).json(ok(await activityService.create(req.body ?? {})));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

activityRouter.patch(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await activityService.update(p(req.params.id), req.body ?? {})));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

activityRouter.post(
  '/:id/toggle',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await activityService.toggleActive(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

activityRouter.delete(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await activityService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
