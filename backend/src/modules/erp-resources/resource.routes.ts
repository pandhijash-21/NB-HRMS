import { Router, Request, Response } from 'express';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { resourceService } from './resource.service';
import { storeInwardService } from './store-inward.service';

export const resourceRouter = Router();
const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

// Materials
resourceRouter.get('/materials', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
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

resourceRouter.get('/materials/stock-summary', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await resourceService.materialStockSummary(projectId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/materials', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await resourceService.createMaterial(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/materials/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.updateMaterial(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/materials/:id/stock', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.addMaterialStock(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/materials/:id/outward', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.dispatchMaterialOutward(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/materials/:id/logs', requireAuth, requirePermission('STORE', 'READ'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.getMaterialLogs(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/materials/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.removeMaterial(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// Machines
resourceRouter.get('/machines', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
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

resourceRouter.get('/machines/stock-summary', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
  try {
    const projectId = String(req.query.projectId ?? '') || undefined;
    return res.json(ok(await resourceService.machineStockSummary(projectId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/machines/issues/active', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
  try {
    const contractorId = String(req.query.contractorId ?? '') || undefined;
    const machineId = String(req.query.machineId ?? '') || undefined;
    return res.json(ok(await resourceService.listActiveMachineIssues({ contractorId, machineId })));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/machines/issues/:issueId/return', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.returnMachine(p(req.params.issueId), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/machines', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await resourceService.createMachine(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/machines/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.updateMachine(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/machines/:id/stock', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.addMachineStock(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/machines/:id/issue', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.issueMachine(p(req.params.id), req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/machines/:id/logs', requireAuth, requirePermission('STORE', 'READ'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.getMachineLogs(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/machines/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.removeMachine(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// Labour
resourceRouter.get('/labour', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'READ'), async (_req, res) => {
  try {
    return res.json(ok(await resourceService.listLabour()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/labour', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await resourceService.createLabour(req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/labour/:id', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.updateLabour(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/labour/:id', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await resourceService.removeLabour(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// ── Store masters (ERP Configurations) ─────────────────────────────────────
resourceRouter.get('/stores', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
  try {
    const includeInactive = String(req.query.includeInactive ?? '') === 'true';
    return res.json(ok(await storeInwardService.listStores(includeInactive)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/stores', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await storeInwardService.createStore(req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/stores/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await storeInwardService.updateStore(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/stores/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await storeInwardService.removeStore(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// Also allow ERP_CONFIGURATIONS to manage store masters from Configurations hub
resourceRouter.get('/stores-config', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'READ'), async (req, res) => {
  try {
    const includeInactive = String(req.query.includeInactive ?? '') === 'true';
    return res.json(ok(await storeInwardService.listStores(includeInactive)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/stores-config', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.status(201).json(ok(await storeInwardService.createStore(req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.patch('/stores-config/:id', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await storeInwardService.updateStore(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.delete('/stores-config/:id', requireAuth, requirePermission('ERP_CONFIGURATIONS', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await storeInwardService.removeStore(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// ── Purchase orders (stub — full Purchase menu later) ──────────────────────
resourceRouter.get('/purchase-orders', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
  try {
    return res.json(
      ok(
        await storeInwardService.listPurchaseOrders({
          status: String(req.query.status ?? '') || undefined,
          openOnly: String(req.query.openOnly ?? '') === 'true',
        }),
      ),
    );
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/purchase-orders/:id', requireAuth, requirePermission('STORE', 'READ'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await storeInwardService.getPurchaseOrder(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/purchase-orders', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res
      .status(201)
      .json(ok(await storeInwardService.createPurchaseOrder(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// ── Goods inward (PO receipt + QC) ─────────────────────────────────────────
resourceRouter.get('/inwards', requireAuth, requirePermission('STORE', 'READ'), async (req, res) => {
  try {
    return res.json(
      ok(
        await storeInwardService.listInwards({
          purchaseOrderId: String(req.query.purchaseOrderId ?? '') || undefined,
          storeId: String(req.query.storeId ?? '') || undefined,
        }),
      ),
    );
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.get('/inwards/:id', requireAuth, requirePermission('STORE', 'READ'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await storeInwardService.getInward(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post('/inwards', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res
      .status(201)
      .json(ok(await storeInwardService.createInward(req.body ?? {}, req.user?.id)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

resourceRouter.post(
  '/upload',
  requireAuth,
  requirePermission('STORE', 'WRITE'),
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('File is required'));
      const folder = String(req.body?.folder ?? 'erp/store');
      const url = await uploadService.uploadToCloudinary(req.file, folder);
      return res.json(
        ok({
          url,
          fileName: req.file.originalname || null,
          mimeType: req.file.mimetype || null,
          fileSize: req.file.size ?? null,
        }),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Upload failed'));
    }
  },
);