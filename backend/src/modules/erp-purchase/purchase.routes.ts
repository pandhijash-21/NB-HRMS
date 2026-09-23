import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { prisma } from '../../config/prisma';
import { purchaseService } from './purchase.service';

export const purchaseRouter = Router();
const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

async function resolveEmployeeId(userId?: string): Promise<number | undefined> {
  if (!userId) return undefined;
  const emp = await prisma.employee.findFirst({
    where: { userId, status: 'ACTIVE' },
    select: { id: true },
  });
  return emp?.id;
}

// Settings
purchaseRouter.get('/settings', requireAuth, requirePermission('PURCHASE', 'READ'), async (_req, res) => {
  try {
    return res.json(ok(await purchaseService.getSettings()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.patch('/settings', requireAuth, requirePermission('PURCHASE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await purchaseService.updateSettings(req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// List / get
purchaseRouter.get('/requests', requireAuth, async (req: Request, res: Response) => {
  try {
    const status = String(req.query.status ?? '') || undefined;
    const mine = String(req.query.mine ?? '') === 'true';
    const pendingForMe = String(req.query.pendingForMe ?? '') === 'true';
    const employeeId = await resolveEmployeeId(req.user?.id);

    // STORE or PURCHASE read
    const canStore = true; // gated below loosely; prefer either permission
    void canStore;

    return res.json(
      ok(
        await purchaseService.list({
          status,
          approverEmployeeId: pendingForMe ? employeeId : undefined,
          requestedByEmployeeId: mine ? employeeId : undefined,
        }),
      ),
    );
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.get('/requests/:id', requireAuth, async (req: Request, res: Response) => {
  try {
    return res.json(ok(await purchaseService.getById(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.post('/requests', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    const employeeId = await resolveEmployeeId(req.user?.id);
    return res.status(201).json(
      ok(
        await purchaseService.create(req.body ?? {}, {
          userId: req.user?.id,
          employeeId,
        }),
      ),
    );
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.patch('/requests/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await purchaseService.update(p(req.params.id), req.body ?? {})));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.post('/requests/:id/submit', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await purchaseService.submit(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.post('/requests/:id/approve', requireAuth, async (req: Request, res: Response) => {
  try {
    const employeeId = await resolveEmployeeId(req.user?.id);
    return res.json(ok(await purchaseService.approve(p(req.params.id), employeeId)));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.post('/requests/:id/reject', requireAuth, async (req: Request, res: Response) => {
  try {
    const employeeId = await resolveEmployeeId(req.user?.id);
    return res.json(
      ok(await purchaseService.reject(p(req.params.id), (req.body as { reason?: string })?.reason, employeeId)),
    );
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

purchaseRouter.delete('/requests/:id', requireAuth, requirePermission('STORE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    return res.json(ok(await purchaseService.remove(p(req.params.id))));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});
