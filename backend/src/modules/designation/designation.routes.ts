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
      const data = await designationService.create({
        ...req.body,
        createdBy: req.user!.id,
      });
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

designationRouter.delete(
  '/designations/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await designationService.remove(String(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.get(
  '/positions',
  requireAuth,
  requirePermission('PERSONAL_INFO', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const { listActivePositions } = await import('./position.util');
      const data = await listActivePositions();
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

designationRouter.post(
  '/positions',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const { displayName, roleName, description } = req.body ?? {};
      if (!displayName || !roleName) {
        return res.status(400).json(fail('displayName and roleName are required'));
      }
      const data = await designationService.createPosition({
        displayName: String(displayName),
        roleName: String(roleName),
        description: description ? String(description) : undefined,
        createdBy: req.user!.id,
      });
      return res.status(201).json(ok(data));
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

designationRouter.get(
  '/position-slots/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await designationService.getPositionSlotById(String(req.params.id));
      if (!data) return res.status(404).json(fail('Alias account not found'));
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
      const password = String(req.body?.password ?? '');
      const data = await designationService.createPositionSlot({
        ...req.body,
        createdBy: req.user!.id,
      });
      return res.status(201).json(
        ok({
          ...data,
          credentials: {
            loginId: data.code,
            password,
            readyToLogin: true,
            message: 'Alias account is active. Log in with the login code and password below.',
          },
        }),
      );
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
