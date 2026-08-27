import { Router, Request, Response } from 'express';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { projectService } from './project.service';
import { towerService } from './tower.service';

export const projectRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

projectRouter.get(
  '/',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const includeInactive = String(req.query.includeInactive ?? '') === 'true';
      const data = await projectService.list({ includeInactive });
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list projects'));
    }
  },
);

projectRouter.get(
  '/next-number',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      return res.json(ok(await projectService.nextNumber()));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

projectRouter.post(
  '/upload',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('File is required'));
      const folder = String(req.body?.folder ?? 'erp/projects');
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

projectRouter.get(
  '/:id',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await projectService.getById(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Not found'));
    }
  },
);

projectRouter.post(
  '/',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await projectService.create(req.body ?? {}, req.user!.id);
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Create failed'));
    }
  },
);

projectRouter.patch(
  '/:id',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await projectService.update(p(req.params.id), req.body ?? {}, req.user!.id);
      return res.json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update failed'));
    }
  },
);

projectRouter.delete(
  '/:id',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await projectService.remove(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Delete failed'));
    }
  },
);

projectRouter.get(
  '/:id/towers',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await towerService.list(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to list towers'));
    }
  },
);

projectRouter.post(
  '/:id/towers',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await towerService.create(p(req.params.id), req.body ?? {});
      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Create tower failed'));
    }
  },
);

projectRouter.get(
  '/:id/towers/:towerId',
  requireAuth,
  requirePermission('PROJECTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await towerService.getById(p(req.params.id), p(req.params.towerId))));
    } catch (e: unknown) {
      return res.status(404).json(fail(e instanceof Error ? e.message : 'Tower not found'));
    }
  },
);

projectRouter.patch(
  '/:id/towers/:towerId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(await towerService.update(p(req.params.id), p(req.params.towerId), req.body ?? {})),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update tower failed'));
    }
  },
);

projectRouter.delete(
  '/:id/towers/:towerId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await towerService.remove(p(req.params.id), p(req.params.towerId))));
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Delete tower failed'));
    }
  },
);

projectRouter.post(
  '/:id/towers/:towerId/regenerate-units',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(await towerService.regenerateUnits(p(req.params.id), p(req.params.towerId))),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Regenerate failed'));
    }
  },
);

projectRouter.patch(
  '/:id/towers/:towerId/units/:unitId',
  requireAuth,
  requirePermission('PROJECTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(
        ok(
          await towerService.updateUnit(
            p(req.params.id),
            p(req.params.towerId),
            p(req.params.unitId),
            req.body ?? {},
          ),
        ),
      );
    } catch (e: unknown) {
      return res.status(400).json(fail(e instanceof Error ? e.message : 'Update unit failed'));
    }
  },
);
