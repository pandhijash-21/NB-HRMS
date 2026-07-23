import { Router, Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { requireAuth } from '../../middleware/auth';
import { ok, fail } from '../../utils/response';
import { uploadService } from '../personal-education/upload.service';
import { repositoryService } from './repository.service';

export const repositoryRouter = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

const MANAGE_ROLES = ['ADMIN', 'HR', 'HR_MANAGER', 'SUPER_ADMIN'];

function canManageRepository(req: Request) {
  const role = String(req.user?.roleName ?? req.user?.role ?? '').toUpperCase();
  return MANAGE_ROLES.includes(role);
}

function requireManageRepository(req: Request, res: Response, next: NextFunction) {
  if (!req.user) return res.status(401).json(fail('Unauthenticated'));
  if (!canManageRepository(req)) {
    return res.status(403).json(fail('Only Admin/HR can manage the repository'));
  }
  return next();
}

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

/** List company documents — any authenticated user. */
repositoryRouter.get('/', requireAuth, async (_req: Request, res: Response) => {
  try {
    const data = await repositoryService.listActive();
    return res.json(ok(data));
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Failed to list documents';
    return res.status(400).json(fail(msg));
  }
});

repositoryRouter.get('/:id', requireAuth, async (req: Request, res: Response) => {
  try {
    const data = await repositoryService.getById(p(req.params.id));
    return res.json(ok(data));
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : 'Document not found';
    return res.status(404).json(fail(msg));
  }
});

/** Upload + create — Admin/HR only. Multipart: file, title, optional description/category. */
repositoryRouter.post(
  '/',
  requireAuth,
  requireManageRepository,
  upload.single('file'),
  async (req: Request, res: Response) => {
    try {
      if (!req.file) return res.status(400).json(fail('File is required'));

      const title = String(req.body?.title ?? '').trim();
      if (!title) return res.status(400).json(fail('Title is required'));

      const description = req.body?.description != null ? String(req.body.description) : null;
      const category = req.body?.category != null ? String(req.body.category) : null;

      const fileUrl = await uploadService.uploadToCloudinary(req.file, 'repository/policies');
      const uploadedBy = req.user?.id ?? null;

      const data = await repositoryService.create({
        title,
        description,
        category,
        fileUrl,
        fileName: req.file.originalname || null,
        mimeType: req.file.mimetype || null,
        fileSize: req.file.size ?? null,
        uploadedBy,
      });

      return res.status(201).json(ok(data));
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Upload failed';
      return res.status(400).json(fail(msg));
    }
  },
);

/** Soft-delete — Admin/HR only. */
repositoryRouter.delete(
  '/:id',
  requireAuth,
  requireManageRepository,
  async (req: Request, res: Response) => {
    try {
      const data = await repositoryService.softDelete(p(req.params.id));
      return res.json(ok(data));
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Delete failed';
      return res.status(400).json(fail(msg));
    }
  },
);
