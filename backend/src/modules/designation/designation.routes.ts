import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { designationService } from './designation.service';

export const designationRouter = Router();

designationRouter.get(
  '/designations',
  requireAuth,
  requirePermission('PERSONAL_INFO', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const isAlias = req.query.isAlias !== undefined ? req.query.isAlias === 'true' : undefined;
      const activeOnly = req.query.includeInactive !== 'true';
      const data = await designationService.list({ isAlias, activeOnly });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.post(
  '/designations',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await designationService.create(req.body);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.patch(
  '/designations/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await designationService.update(String(req.params.id), req.body);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.get(
  '/position-slots',
  requireAuth,
  requirePermission('USER_MGMT', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await designationService.listPositionSlots();
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.post(
  '/position-slots',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await designationService.createPositionSlot({
        ...req.body,
        createdBy: req.user!.id,
      });
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.post(
  '/position-slots/:id/assign',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await designationService.assignPositionHolder(String(req.params.id), {
        ...req.body,
        assignedBy: req.user!.id,
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
