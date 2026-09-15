import { Router } from 'express';
import type { NextFunction, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { isSuperAdminRole } from '../auth/permissions-map';
import { fail, ok } from '../../utils/response';
import { storageService } from './storage.service';

export const storageRouter = Router();

function requireStorageAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user) return res.status(401).json(fail('Unauthenticated'));
  const role = req.user.roleName ?? req.user.role;
  if (isSuperAdminRole(role)) return next();
  const held = req.user.permissions?.USER_MGMT ?? [];
  if (held.includes('WRITE') || held.includes('DELETE')) return next();
  return res.status(403).json(fail('You do not have permission to manage storage'));
}

storageRouter.get('/', requireAuth, requireStorageAdmin, async (_req, res) => {
  try {
    const usage = await storageService.usage();
    return res.json(ok(usage));
  } catch (err) {
    console.error('Storage usage failed:', err);
    return res.status(500).json(fail('Unable to load storage usage'));
  }
});

storageRouter.post('/purge', requireAuth, requireStorageAdmin, async (req, res) => {
  const password = String((req.body as { password?: unknown } | undefined)?.password ?? '').trim();
  if (!password) {
    return res.status(400).json(fail('Admin password is required'));
  }
  try {
    const result = await storageService.purgeTextAndDocuments(req.user!.id, password);
    if (!result.ok) {
      return res.status(result.status).json(fail(result.error));
    }
    return res.json(ok(result.data));
  } catch (err) {
    console.error('Storage purge failed:', err);
    return res.status(500).json(fail('Unable to clear storage data'));
  }
});
