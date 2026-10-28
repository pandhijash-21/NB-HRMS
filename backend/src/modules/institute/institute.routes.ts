import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireAnyPermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { instituteService } from './institute.service';

export const instituteRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

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
  requireAnyPermission(['USER_MGMT', 'PROJECTS'], 'READ'),
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
      const body = (req.body ?? {}) as Record<string, unknown>;
      const profile = instituteService.parseBody(body);
      const data = await instituteService.create({
        code: String(body.code ?? ''),
        name: String(body.name ?? ''),
        sortOrder: body.sortOrder !== undefined ? Number(body.sortOrder) : undefined,
        isChildCompany: body.isChildCompany !== undefined ? Boolean(body.isChildCompany) : false,
        parentOrganizationId:
          body.parentOrganizationId === undefined
            ? null
            : body.parentOrganizationId
              ? String(body.parentOrganizationId)
              : null,
        ...profile,
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
      const body = (req.body ?? {}) as Record<string, unknown>;
      const profile = instituteService.parseBody(body);
      const data = await instituteService.update(p(req.params.id), {
        ...(body.code !== undefined ? { code: String(body.code) } : {}),
        ...(body.name !== undefined ? { name: String(body.name) } : {}),
        ...(body.isActive !== undefined ? { isActive: Boolean(body.isActive) } : {}),
        ...(body.sortOrder !== undefined ? { sortOrder: Number(body.sortOrder) } : {}),
        ...(body.isChildCompany !== undefined
          ? { isChildCompany: Boolean(body.isChildCompany) }
          : {}),
        ...(body.parentOrganizationId !== undefined
          ? {
              parentOrganizationId: body.parentOrganizationId
                ? String(body.parentOrganizationId)
                : null,
            }
          : {}),
        ...profile,
      });
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
      const data = await instituteService.remove(p(req.params.id));
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
      const data = await instituteService.getMembers(p(req.params.id));
      if (!data) return res.status(404).json(fail('Institute not found'));
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
