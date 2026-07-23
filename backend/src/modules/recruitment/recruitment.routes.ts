import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { recruitmentService } from './recruitment.service';

export const recruitmentRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function isPrivilegedAdmin(req: Request) {
  const role = String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '').toUpperCase();
  return ['ADMIN', 'HR', 'HR_MANAGER', 'SUPER_ADMIN'].includes(role);
}

// ─── Vacancies (all enrolled users) ──────────────────────────────────────────

recruitmentRouter.get(
  '/vacancies',
  requireAuth,
  requirePermission('RECRUITMENT', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await recruitmentService.listActiveRequirements();
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.get(
  '/vacancies/:id',
  requireAuth,
  requirePermission('RECRUITMENT', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const row = await recruitmentService.getRequirement(p(req.params.id));
      if (!row.isActive && !isPrivilegedAdmin(req)) {
        return res.status(404).json(fail('Vacancy not found'));
      }
      // Strip candidate PII for non-admin vacancy viewers
      if (!isPrivilegedAdmin(req)) {
        const { candidates: _c, ...publicView } = row as any;
        return res.json(ok(publicView));
      }
      return res.json(ok(row));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Admin requirements ──────────────────────────────────────────────────────

recruitmentRouter.get(
  '/requirements',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const activeOnly = String(req.query.activeOnly ?? '') === 'true';
      const data = await recruitmentService.listAllRequirements({ activeOnly });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.post(
  '/requirements',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.createRequirement(req.body ?? {}, req.user!.id);
      return res.status(201).json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.get(
  '/requirements/:id',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.getRequirement(p(req.params.id));
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.patch(
  '/requirements/:id',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.updateRequirement(
        p(req.params.id),
        req.body ?? {},
        req.user!.id,
      );
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.patch(
  '/requirements/:id/active',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const isActive = Boolean(req.body?.isActive);
      const data = await recruitmentService.setRequirementActive(
        p(req.params.id),
        isActive,
        req.user!.id,
      );
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Candidates (admin) ──────────────────────────────────────────────────────

recruitmentRouter.get(
  '/candidates',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const requirementId = req.query.requirementId
        ? String(req.query.requirementId)
        : undefined;
      const data = await recruitmentService.listCandidates({ requirementId });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.post(
  '/candidates',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.createCandidate(req.body ?? {}, req.user!.id);
      return res.status(201).json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.get(
  '/candidates/:id',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.getCandidate(p(req.params.id));
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.patch(
  '/candidates/:id',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.updateCandidate(
        p(req.params.id),
        req.body ?? {},
        req.user!.id,
      );
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.post(
  '/candidates/:id/rounds',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.scheduleNextRound(
        p(req.params.id),
        req.body ?? {},
        req.user!.id,
      );
      return res.status(201).json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

recruitmentRouter.post(
  '/candidates/:id/hire',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.hireCandidate(
        p(req.params.id),
        req.body ?? {},
        req.user!.id,
      );
      return res.status(201).json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Interviewer queue ───────────────────────────────────────────────────────

recruitmentRouter.get('/my-interviews', requireAuth, async (req: Request, res: Response) => {
  try {
    const data = await recruitmentService.listMyPendingInterviews(req.user!.id);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

recruitmentRouter.patch(
  '/rounds/:id/status',
  requireAuth,
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.updateRoundStatus(
        p(req.params.id),
        {
          statusCode: String(req.body?.statusCode ?? ''),
          remarks: req.body?.remarks != null ? String(req.body.remarks) : null,
        },
        req.user!.id,
        { privilegedAdmin: isPrivilegedAdmin(req) },
      );
      return res.json(ok(data));
    } catch (e: any) {
      const msg = String(e.message ?? '');
      const status =
        msg.includes('Only the assigned') || msg.includes('view-only') ? 403 : 400;
      return res.status(status).json(fail(msg));
    }
  },
);

recruitmentRouter.post(
  '/rounds/:id/confirm',
  requireAuth,
  requirePermission('RECRUITMENT', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const data = await recruitmentService.confirmRoundStatus(p(req.params.id), req.user!.id);
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);
