import { Router, Request, Response } from 'express';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { earthService } from './earth.service';

export const earthRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
});

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

earthRouter.get(
  '/dashboard',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      return res.json(ok(await earthService.dashboard()));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to load dashboard'));
    }
  },
);

earthRouter.get(
  '/geocode',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const q = String(req.query.q ?? '').trim();
      return res.json(ok(await earthService.geocode(q)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Geocode failed'));
    }
  },
);

earthRouter.get(
  '/reverse',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const lat = Number(req.query.lat);
      const lng = Number(req.query.lng);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
        return res.status(400).json(fail('lat and lng are required'));
      }
      return res.json(ok(await earthService.reverse(lat, lng)));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Reverse geocode failed'));
    }
  },
);

earthRouter.post(
  '/upload',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'WRITE'),
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('File is required'));
      const url = await uploadService.uploadToCloudinary(req.file, 'earth/properties');
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

earthRouter.get(
  '/properties',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const data = await earthService.list({
        includeInactive: String(req.query.includeInactive ?? '') === 'true',
        kind: req.query.kind ? String(req.query.kind) : undefined,
        status: req.query.status ? String(req.query.status) : undefined,
        q: req.query.q ? String(req.query.q) : undefined,
      });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list properties'));
    }
  },
);

earthRouter.get(
  '/properties/:id',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await earthService.getById(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
    }
  },
);

earthRouter.post(
  '/properties',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await earthService.create(req.body ?? {}, req.user!.id);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Create failed'));
    }
  },
);

earthRouter.patch(
  '/properties/:id',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await earthService.update(p(req.params.id), req.body ?? {}, req.user!.id);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update failed'));
    }
  },
);

earthRouter.delete(
  '/properties/:id',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await earthService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Delete failed'));
    }
  },
);

earthRouter.get(
  '/properties/:id/prices',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await earthService.listPrices(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list prices'));
    }
  },
);

earthRouter.post(
  '/properties/:id/prices',
  requireAuth,
  requirePermission('GOOGLE_EARTH', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await earthService.addPrice(p(req.params.id), req.body ?? {}, req.user!.id);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to add price'));
    }
  },
);
