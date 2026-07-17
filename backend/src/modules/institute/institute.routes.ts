import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { instituteService } from './institute.service';

export const instituteRouter = Router();

instituteRouter.get('/institutes', requireAuth, async (req: Request, res: Response) => {
  try {
    const activeOnly = req.query.includeInactive !== 'true';
    const data = await instituteService.list({ activeOnly });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

instituteRouter.get(
  '/admin/institutes',
  requireAuth,
  requirePermission('USER_MGMT', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await instituteService.list({ activeOnly: false });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

instituteRouter.post(
  '/admin/institutes',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const { code, name, sortOrder } = req.body ?? {};
      const data = await instituteService.create({
        code: String(code ?? ''),
        name: String(name ?? ''),
        sortOrder: sortOrder !== undefined ? Number(sortOrder) : undefined,
      });
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

instituteRouter.patch(
  '/admin/institutes/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await instituteService.update(String(req.params.id), req.body ?? {});
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

instituteRouter.delete(
  '/admin/institutes/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await instituteService.remove(String(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

instituteRouter.get(
  '/admin/institutes/:id/members',
  requireAuth,
  requirePermission('PERSONAL_INFO', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await instituteService.getMembers(String(req.params.id));
      if (!data) return res.status(404).json(fail('Institute not found'));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
