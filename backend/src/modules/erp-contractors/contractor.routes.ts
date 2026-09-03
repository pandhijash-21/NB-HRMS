import { Router, Request, Response } from 'express';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { contractorService } from './contractor.service';

export const contractorRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

contractorRouter.get(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = String(req.query.includeInactive ?? '') === 'true';
      return res.json(ok(await contractorService.list({ includeInactive })));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.post(
  '/upload',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('File is required'));
      const folder = String(req.body?.folder ?? 'erp/contractors');
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

contractorRouter.get(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.getById(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
    }
  },
);

contractorRouter.post(
  '/',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.status(201).json(ok(await contractorService.create(req.body ?? {})));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.patch(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.update(p(req.params.id), req.body ?? {})));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.post(
  '/:id/toggle',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.toggleActive(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

contractorRouter.delete(
  '/:id',
  requireAuth,
  requirePermission('WORK_ORDERS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await contractorService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
