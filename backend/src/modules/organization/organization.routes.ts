import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { organizationService } from './organization.service';

export const organizationRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

/** Active organizations for pickers (any authenticated user). */
organizationRouter.get('/organizations', requireAuth, async (req: Request, res: Response) => {
  try {
    const activeOnly = req.query.includeInactive !== 'true';
    const data = await organizationService.list({ activeOnly });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

organizationRouter.get(
  '/admin/organizations',
  requireAuth,
  requirePermission('USER_MGMT', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await organizationService.list({ activeOnly: false });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

organizationRouter.get(
  '/admin/organizations/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await organizationService.getById(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
    }
  },
);

organizationRouter.post(
  '/admin/organizations',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = (req.body ?? {}) as Record<string, unknown>;
      const profile = organizationService.parseBody(body);
      const data = await organizationService.create({
        code: String(body.code ?? ''),
        name: String(body.name ?? ''),
        sortOrder: body.sortOrder !== undefined ? Number(body.sortOrder) : undefined,
        ...profile,
      });
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

organizationRouter.patch(
  '/admin/organizations/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const body = (req.body ?? {}) as Record<string, unknown>;
      const profile = organizationService.parseBody(body);
      const data = await organizationService.update(p(req.params.id), {
        ...(body.code !== undefined ? { code: String(body.code) } : {}),
        ...(body.name !== undefined ? { name: String(body.name) } : {}),
        ...(body.isActive !== undefined ? { isActive: Boolean(body.isActive) } : {}),
        ...(body.sortOrder !== undefined ? { sortOrder: Number(body.sortOrder) } : {}),
        ...profile,
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

organizationRouter.delete(
  '/admin/organizations/:id',
  requireAuth,
  requirePermission('USER_MGMT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await organizationService.remove(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
