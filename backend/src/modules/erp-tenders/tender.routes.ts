import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { tenderService } from './tender.service';

export const tenderRouter = Router();
const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

tenderRouter.get('/helpers/boq-activities', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const boqId = String(req.query.boqId ?? '');
    if (!boqId) return res.status(400).json(fail('boqId is required'));
    return res.json(ok(await tenderService.activitiesFromBoq(boqId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderRouter.get('/helpers/preview-lines', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const boqId = String(req.query.boqId ?? '') || undefined;
    const activityId = String(req.query.activityId ?? '') || undefined;
    if (boqId) {
      return res.json(ok(await tenderService.linesFromBoq(boqId, activityId)));
    }
    if (!activityId) return res.status(400).json(fail('activityId is required when BOQ is not selected'));
    return res.json(ok(await tenderService.linesFromActivity(activityId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderRouter.get('/', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await tenderService.list({ projectId })));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderRouter.get('/:id', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    return res.json(ok(await tenderService.getById(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderRouter.post('/', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await tenderService.create(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderRouter.patch('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await tenderService.update(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderRouter.delete('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await tenderService.remove(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// Applications nested under /api/tenders/applications via separate mount — see index
export const tenderApplicationRouter = Router();

tenderApplicationRouter.get('/', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const tenderId = String(req.query.tenderId ?? '') || undefined;
    return res.json(ok(await tenderService.listApplications({ tenderId })));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderApplicationRouter.get('/:id', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    return res.json(ok(await tenderService.getApplication(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderApplicationRouter.post('/', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await tenderService.createApplication(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderApplicationRouter.patch('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await tenderService.updateApplication(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

tenderApplicationRouter.delete('/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await tenderService.removeApplication(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});
