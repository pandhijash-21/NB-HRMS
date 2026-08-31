import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { contractorService } from './contractor.service';

export const contractorRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

contractorRouter.get(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = String(req.query.includeInactive ?? '') === 'true';
      return res.json(ok(await contractorService.list({ includeInactive })));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.post(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.status(201).json(ok(await contractorService.create(req.body ?? {})));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.patch(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.update(p(req.params.id), req.body ?? {})));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.post(
  '/:id/toggle',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.toggleActive(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.delete(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
