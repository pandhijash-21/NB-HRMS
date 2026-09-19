import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { ok, fail } from '../../utils/response';
import { notificationsService } from './notifications.service';

export const notificationsRouter = Router();

notificationsRouter.get('/', requireAuth, async (req: Request, res: Response) => {
  try {
    const limit = req.query.limit ? Number(req.query.limit) : 50;
    const data = await notificationsService.listForUser(req.user!.id, limit);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed to load notifications'));
  }
});

notificationsRouter.get('/unread-count', requireAuth, async (req: Request, res: Response) => {
  try {
    const count = await notificationsService.unreadCount(req.user!.id);
    return res.json(ok({ count }));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

notificationsRouter.post('/broadcast', requireAuth, async (req: Request, res: Response) => {
  try {
    const data = await notificationsService.broadcast(
      {
        id: req.user!.id,
        role: req.user!.role ?? req.user!.roleName,
        companyAdminGranted: req.user!.companyAdminGranted,
        subOrganization: req.user!.subOrganization,
      },
      {
        title: String(req.body?.title ?? ''),
        body: String(req.body?.body ?? ''),
        path: req.body?.path != null ? String(req.body.path) : '/notifications',
      },
    );
    return res.json(ok(data));
  } catch (e: unknown) {
    const status = (e as { status?: number })?.status === 403 ? 403 : 400;
    return res.status(status).json(fail(e instanceof Error ? e.message : 'Broadcast failed'));
  }
});

notificationsRouter.post('/read-all', requireAuth, async (req: Request, res: Response) => {
  try {
    const data = await notificationsService.markAllRead(req.user!.id);
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

notificationsRouter.post('/:id/read', requireAuth, async (req: Request, res: Response) => {
  try {
    const data = await notificationsService.markRead(req.user!.id, String(req.params.id));
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});
