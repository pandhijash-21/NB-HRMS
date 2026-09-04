import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { dprService } from './dpr.service';

export const dprRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

dprRouter.get('/', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await dprService.list({ projectId })));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

dprRouter.get('/:id', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    return res.json(ok(await dprService.getById(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

dprRouter.post('/', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await dprService.create(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

dprRouter.delete('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await dprService.remove(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});
