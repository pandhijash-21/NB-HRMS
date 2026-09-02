import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { boqService } from './boq.service';

export const boqRouter = Router();
const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

boqRouter.get('/', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await boqService.list({ projectId })));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

boqRouter.get('/:id', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    return res.json(ok(await boqService.getById(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

boqRouter.post('/', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await boqService.create(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

boqRouter.patch('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await boqService.update(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

boqRouter.delete('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await boqService.remove(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});
