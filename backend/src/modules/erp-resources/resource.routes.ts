import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { resourceService } from './resource.service';

export const resourceRouter = Router();
const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

// Materials
resourceRouter.get('/materials', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const data = await resourceService.listMaterials({
      includeInactive: String(req.query.includeInactive ?? '') === 'true',
      projectId: String(req.query.projectId ?? '') || undefined,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/materials/stock-summary', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await resourceService.materialStockSummary(projectId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/materials', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await resourceService.createMaterial(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/materials/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.updateMaterial(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/materials/:id/stock', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.addMaterialStock(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/materials/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.removeMaterial(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// Machines
resourceRouter.get('/machines', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const data = await resourceService.listMachines({
      includeInactive: String(req.query.includeInactive ?? '') === 'true',
      projectId: String(req.query.projectId ?? '') || undefined,
    });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/machines/stock-summary', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await resourceService.machineStockSummary(projectId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/machines', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await resourceService.createMachine(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/machines/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.updateMachine(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/machines/:id/stock', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.addMachineStock(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/machines/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.removeMachine(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// Labour
resourceRouter.get('/labour', requireAuth, requirePermission('WORK_ORDERS', 'READ'), async (_req, res) => {
  try {
    return res.json(ok(await resourceService.listLabour()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/labour', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await resourceService.createLabour(req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/labour/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.updateLabour(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/labour/:id', requireAuth, requirePermission('WORK_ORDERS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.removeLabour(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});
