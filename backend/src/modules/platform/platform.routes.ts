import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requireSuperAdmin } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { platformService } from './platform.service';

export const platformRouter = Router();

// Apply Superadmin authentication guard to ALL platform routes
platformRouter.use(requireAuth, requireSuperAdmin());

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

/**
 * SaaS Platform Overview & Health Metrics
 */
platformRouter.get('/stats', async (_req: Request, res: Response) => {
  try {
    const stats = await platformService.getStats();
    return res.json(ok(stats));
  } catch (err: unknown) {
    return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch platform metrics'));
  }
});

/**
 * List all client companies (Tenants)
 */
platformRouter.get('/companies', async (_req: Request, res: Response) => {
  try {
    const companies = await platformService.listCompanies();
    return res.json(ok(companies));
  } catch (err: unknown) {
    return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to list companies'));
  }
});

/**
 * Onboard a new client company & provision their initial System Admin account
 */
platformRouter.post('/companies', async (req: Request, res: Response) => {
  try {
    const result = await platformService.onboardCompany(req.body);
    return res.status(201).json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to onboard company'));
  }
});

/**
 * Update client company profile, status (Active/Suspended), or module entitlements
 */
platformRouter.patch('/companies/:id', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const updated = await platformService.updateCompany(id, req.body);
    return res.json(ok(updated));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to update company'));
  }
});

/**
 * List all client company System Admins
 */
platformRouter.get('/admins', async (_req: Request, res: Response) => {
  try {
    const admins = await platformService.listSystemAdmins();
    return res.json(ok(admins));
  } catch (err: unknown) {
    return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to list admins'));
  }
});

/**
 * Reset a client company System Admin's password
 */
platformRouter.post('/admins/:id/reset-password', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const newPassword = String(req.body.newPassword ?? '');
    const result = await platformService.resetAdminPassword(id, newPassword);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to reset password'));
  }
});

/**
 * Unlock a locked client company System Admin account
 */
platformRouter.post('/admins/:id/unlock', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const result = await platformService.unlockAdminAccount(id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to unlock account'));
  }
});

/**
 * Move a client company to Trash (30-day soft delete)
 */
platformRouter.delete('/companies/:id', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const superadminPassword = req.body?.superadminPassword || req.headers['x-superadmin-password'] || req.query.superadminPassword;
    const result = await platformService.trashCompany(id, superadminPassword ? String(superadminPassword) : undefined, req.user?.id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to move company to trash'));
  }
});

/**
 * Restore a client company from Trash
 */
platformRouter.post('/companies/:id/restore', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const result = await platformService.restoreCompany(id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to restore company'));
  }
});

/**
 * Permanently purge a client company
 */
platformRouter.delete('/companies/:id/permanent', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const superadminPassword = req.body?.superadminPassword || req.headers['x-superadmin-password'] || req.query.superadminPassword;
    const result = await platformService.purgeCompany(id, superadminPassword ? String(superadminPassword) : undefined, req.user?.id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to permanently delete company'));
  }
});

/**
 * Move a System Admin to Trash (30-day soft delete)
 */
platformRouter.delete('/admins/:id', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const superadminPassword = req.body?.superadminPassword || req.headers['x-superadmin-password'] || req.query.superadminPassword;
    const result = await platformService.trashAdmin(id, superadminPassword ? String(superadminPassword) : undefined, req.user?.id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to move admin to trash'));
  }
});

/**
 * Restore a System Admin from Trash
 */
platformRouter.post('/admins/:id/restore', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const result = await platformService.restoreAdmin(id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to restore admin'));
  }
});

/**
 * Permanently purge a System Admin
 */
platformRouter.delete('/admins/:id/permanent', async (req: Request, res: Response) => {
  try {
    const id = p(req.params.id);
    const superadminPassword = req.body?.superadminPassword || req.headers['x-superadmin-password'] || req.query.superadminPassword;
    const result = await platformService.purgeAdmin(id, superadminPassword ? String(superadminPassword) : undefined, req.user?.id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to permanently delete admin'));
  }
});

/**
 * Retrieve all items in Trash with 30-day countdown
 */
platformRouter.get('/trash', async (_req: Request, res: Response) => {
  try {
    const trash = await platformService.getTrash();
    return res.json(ok(trash));
  } catch (err: unknown) {
    return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to fetch trash items'));
  }
});

/**
 * Empty all Trash immediately
 */
platformRouter.delete('/trash/empty', async (req: Request, res: Response) => {
  try {
    const superadminPassword = req.body?.superadminPassword || req.headers['x-superadmin-password'] || req.query.superadminPassword;
    const result = await platformService.emptyTrash(superadminPassword ? String(superadminPassword) : undefined, req.user?.id);
    return res.json(ok(result));
  } catch (err: unknown) {
    return res.status(500).json(fail(err instanceof Error ? err.message : 'Failed to empty trash'));
  }
});
