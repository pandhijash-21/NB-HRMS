import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { lookupService } from './lookup.service';

export const lookupRouter = Router();

/** Active options for forms (any authenticated user). */
lookupRouter.get('/lookups', requireAuth, async (req: Request, res: Response) => {
  try {
    const category = req.query.category ? String(req.query.category) : undefined;
    const activeOnly = req.query.includeInactive !== 'true';
    const data = category
      ? await lookupService.list(category, { activeOnly })
      : await lookupService.listGrouped({ activeOnly });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

lookupRouter.get(
  '/admin/lookups/categories',
  requireAuth,
  requirePermission('FIELD_MGMT', 'READ'),
  async (_req: Request, res: Response) => {
    return res.json(ok(lookupService.listCategories()));
  },
);

lookupRouter.get(
  '/admin/lookups',
  requireAuth,
  requirePermission('FIELD_MGMT', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const category = req.query.category ? String(req.query.category) : undefined;
      const data = category
        ? await lookupService.list(category, { activeOnly: false })
        : await lookupService.listGrouped({ activeOnly: false });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

lookupRouter.post(
  '/admin/lookups',
  requireAuth,
  requirePermission('FIELD_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await lookupService.create(req.body ?? {});
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

lookupRouter.patch(
  '/admin/lookups/:id',
  requireAuth,
  requirePermission('FIELD_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await lookupService.update(String(req.params.id), req.body ?? {});
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

lookupRouter.delete(
  '/admin/lookups/:id',
  requireAuth,
  requirePermission('FIELD_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await lookupService.remove(String(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
