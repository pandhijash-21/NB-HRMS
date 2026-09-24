import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, type PermissionAction } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { supportService } from './support.service';

export const supportRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function normalizeRole(raw: unknown): string {
  return String(raw ?? '')
    .toUpperCase()
    .replace(/[\s_-]+/g, '');
}

/** Admin / System Admin can configure who receives Support tickets. */
export function canManageSupportHandlers(req: Request): boolean {
  if ((req.user as any)?.companyAdminGranted === true) return true;
  const role = normalizeRole((req.user as any)?.roleName ?? (req.user as any)?.role);
  return [
    'ADMIN',
    'SYSTEMADMIN',
    'SYSTEMADMINISTRATOR',
    'SUPERADMIN',
  ].includes(role);
}

/** Role-based IT (used when no assignees configured, and as admin override). */
function isRolePrivilegedSupportIt(req: Request): boolean {
  const role = normalizeRole((req.user as any)?.roleName ?? (req.user as any)?.role);
  if (
    [
      'ADMIN',
      'HR',
      'HRMANAGER',
      'SYSTEMADMIN',
      'SYSTEMADMINISTRATOR',
      'SUPERADMIN',
    ].includes(role)
  ) {
    return true;
  }
  if ((req.user as any)?.companyAdminGranted === true) return true;
  const perms = (req.user as any)?.permissions as Record<string, string[]> | undefined;
  const actions = perms?.SUPPORT ?? perms?.support ?? [];
  return actions.map((a) => String(a).toUpperCase()).includes('APPROVE');
}

/** IT queue: assigned handlers, or role fallback / Admin when managing. */
export async function isSupportIt(req: Request): Promise<boolean> {
  const caps = await supportService.capabilities({
    employeeId:
      req.user?.employeeId != null && Number.isFinite(Number(req.user.employeeId))
        ? Number(req.user.employeeId)
        : null,
    rolePrivileged: isRolePrivilegedSupportIt(req),
    canManageHandlers: canManageSupportHandlers(req),
  });
  return caps.isIt;
}

supportRouter.use(requireAuth);
supportRouter.use((req, res, next) => {
  const action: PermissionAction = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method)
    ? 'WRITE'
    : 'READ';
  if (
    req.path === '/queue' ||
    req.path === '/handlers' ||
    req.path === '/capabilities' ||
    req.path.endsWith('/review') ||
    req.path.endsWith('/resolve') ||
    req.path.endsWith('/force-close')
  ) {
    return requirePermission('SUPPORT', 'READ')(req, res, next);
  }
  return requirePermission('SUPPORT', action)(req, res, next);
});

supportRouter.get('/capabilities', async (req: Request, res: Response) => {
  try {
    const employeeId =
      req.user!.employeeId != null && Number.isFinite(Number(req.user!.employeeId))
        ? Number(req.user!.employeeId)
        : null;
    const data = await supportService.capabilities({
      employeeId,
      rolePrivileged: isRolePrivilegedSupportIt(req),
      canManageHandlers: canManageSupportHandlers(req),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/handlers', async (req: Request, res: Response) => {
  try {
    // Anyone who can act as IT (or manage) may see who is assigned.
    if (!(await isSupportIt(req)) && !canManageSupportHandlers(req)) {
      return res.status(403).json(fail('Not allowed to view Support handlers'));
    }
    const data = await supportService.listHandlers();
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.put('/handlers', async (req: Request, res: Response) => {
  try {
    if (!canManageSupportHandlers(req)) {
      return res.status(403).json(fail('Only Admin can assign Support handlers'));
    }
    const raw = req.body?.employeeIds ?? req.body?.employeeId ?? [];
    const employeeIds = Array.isArray(raw)
      ? raw.map((v: unknown) => Number(v))
      : [Number(raw)];
    const data = await supportService.setHandlers({
      employeeIds,
      actorId: String(req.user!.id),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.post('/', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.status(400).json(fail('Employee profile is required to raise a ticket'));
    }
    const ticket = await supportService.create({
      employeeId,
      createdBy: String(req.user!.id),
      title: String(req.body?.title ?? ''),
      description: String(req.body?.description ?? ''),
      photoUrl: req.body?.photoUrl != null ? String(req.body.photoUrl) : null,
    });
    return res.status(201).json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/my', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.json(ok([]));
    }
    const data = await supportService.listMine(employeeId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/queue', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support can view the queue'));
    }
    const includeClosed =
      req.query.includeClosed === 'true' || req.query.includeClosed === '1';
    const data = await supportService.listQueue({ includeClosed });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const employeeId = req.user!.employeeId != null ? Number(req.user!.employeeId) : null;
    const ticket = await supportService.assertCanView(p(req.params.id), {
      userId: String(req.user!.id),
      employeeId: employeeId && Number.isFinite(employeeId) ? employeeId : null,
      isIt: await isSupportIt(req),
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    const msg = e.message ?? 'Failed';
    return res.status(msg === 'Ticket not found' ? 404 : 403).json(fail(msg));
  }
});

supportRouter.patch('/:id/review', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support can update review / ETA'));
    }
    const ticket = await supportService.setInReview({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      etaAt: req.body?.etaAt ?? req.body?.eta,
      note: req.body?.note != null ? String(req.body.note) : null,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/resolve', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support can mark resolved'));
    }
    const ticket = await supportService.markResolved({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      remarks: String(req.body?.remarks ?? req.body?.resolveRemarks ?? ''),
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/confirm', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.status(400).json(fail('Employee profile required'));
    }
    const ticket = await supportService.confirm({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      employeeId,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/deny', async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId || !Number.isFinite(employeeId)) {
      return res.status(400).json(fail('Employee profile required'));
    }
    const ticket = await supportService.deny({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      employeeId,
      note: req.body?.note != null ? String(req.body.note) : null,
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

supportRouter.patch('/:id/force-close', async (req: Request, res: Response) => {
  try {
    if (!(await isSupportIt(req))) {
      return res.status(403).json(fail('Only IT Support can force-close tickets'));
    }
    const ticket = await supportService.forceClose({
      ticketId: p(req.params.id),
      actorId: String(req.user!.id),
      remarks: String(req.body?.remarks ?? ''),
    });
    return res.json(ok(ticket));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});
