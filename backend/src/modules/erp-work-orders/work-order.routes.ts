import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { workOrderService } from './work-order.service';

export const workOrderRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

workOrderRouter.get(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      return res.json(ok(await workOrderService.list()));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

workOrderRouter.get(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await workOrderService.getById(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

workOrderRouter.post(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const userId = req.user?.id;
      return res.status(201).json(ok(await workOrderService.create(req.body ?? {}, userId)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

workOrderRouter.patch(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const userId = req.user?.id;
      return res.json(ok(await workOrderService.update(p(req.params.id), req.body ?? {}, userId)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

workOrderRouter.patch(
  '/:id/status',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const userId = req.user?.id;
      const status = String(req.body?.status ?? '');
      return res.json(ok(await workOrderService.updateStatus(p(req.params.id), status, userId)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

workOrderRouter.patch(
  '/:id/approval',
  requireAuth,
  requirePermission('WORK_ORDERS', 'APPROVE'),
  async (req: Request, res: Response) => {
    try {
      const userId = req.user?.id;
      const approvalStatus = String(req.body?.approvalStatus ?? '');
      return res.json(ok(await workOrderService.updateApproval(p(req.params.id), approvalStatus, userId)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

workOrderRouter.delete(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await workOrderService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
