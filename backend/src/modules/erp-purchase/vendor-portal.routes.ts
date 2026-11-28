import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { vendorPortalService } from './vendor-portal.service';

export const vendorPortalPublicRouter = Router();
export const vendorPortalAdminRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function statusOf(e: unknown) {
  if (e && typeof e === 'object' && 'status' in e && typeof (e as { status: unknown }).status === 'number') {
    return (e as { status: number }).status;
  }
  return 400;
}

// ── Public (no auth) ─────────────────────────────────────────────────────────

vendorPortalPublicRouter.get('/:token', async (req: Request, res: Response) => {
  try {
    return res.json(ok(await vendorPortalService.getPublicSummary(p(req.params.token))));
  } catch (e: unknown) {
    return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

vendorPortalPublicRouter.post('/:token/otp/send', async (req: Request, res: Response) => {
  try {
    const email = String((req.body ?? {}).email ?? '');
    return res.json(ok(await vendorPortalService.sendOtp(p(req.params.token), email)));
  } catch (e: unknown) {
    return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

vendorPortalPublicRouter.post('/:token/otp/verify', async (req: Request, res: Response) => {
  try {
    const body = (req.body ?? {}) as Record<string, unknown>;
    return res.json(
      ok(
        await vendorPortalService.verifyOtp(
          p(req.params.token),
          String(body.email ?? ''),
          String(body.otp ?? ''),
        ),
      ),
    );
  } catch (e: unknown) {
    return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

vendorPortalPublicRouter.post('/:token/submit', async (req: Request, res: Response) => {
  try {
    const sessionToken =
      (req.headers['x-vendor-session'] as string | undefined) ||
      String((req.body ?? {}).sessionToken ?? '');
    return res.status(201).json(
      ok(await vendorPortalService.submitQuotation(p(req.params.token), sessionToken, req.body ?? {})),
    );
  } catch (e: unknown) {
    return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// ── Admin (auth) — mounted under /api/erp/purchase ────────────────────────────

vendorPortalAdminRouter.get(
  '/requests/:id/vendor-portal',
  requireAuth,
  requirePermission('PURCHASE', 'READ'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await vendorPortalService.ensureInvite(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

vendorPortalAdminRouter.post(
  '/requests/:id/vendor-portal/ensure',
  requireAuth,
  requirePermission('PURCHASE', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await vendorPortalService.ensureInvite(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

vendorPortalAdminRouter.post(
  '/requests/:id/vendor-portal/rotate',
  requireAuth,
  requirePermission('PURCHASE', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      return res.json(ok(await vendorPortalService.rotateInvite(p(req.params.id))));
    } catch (e: unknown) {
      return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);

vendorPortalAdminRouter.post(
  '/requests/:id/vendor-portal/email',
  requireAuth,
  requirePermission('PURCHASE', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const emailsRaw = (req.body ?? {}).emails;
      const emails = Array.isArray(emailsRaw)
        ? emailsRaw.map((e) => String(e))
        : String((req.body ?? {}).email ?? '')
            .split(/[,;\s]+/)
            .filter(Boolean);
      return res.json(ok(await vendorPortalService.emailInvite(p(req.params.id), emails)));
    } catch (e: unknown) {
      return res.status(statusOf(e)).json(fail(e instanceof Error ? e.message : 'Failed'));
    }
  },
);
