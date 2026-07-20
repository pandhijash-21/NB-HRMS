import { Router, Request, Response } from 'express';
import { ReimbursementStatus } from '@prisma/client';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireRole } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { reimbursementsService } from './reimbursements.service';

export const reimbursementsRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function isPrivilegedAdmin(req: Request) {
  const role = String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '').toUpperCase();
  return ['ADMIN', 'HR', 'HR_MANAGER'].includes(role);
}

// ─── Employee apply / my list ────────────────────────────────────────────────

reimbursementsRouter.post(
  '/apply',
  requireAuth,
  requirePermission('REIMBURSEMENTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.user!.employeeId);
      if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
      const amount = Number(req.body?.amount);
      const openingKm =
        req.body?.openingKm != null && req.body.openingKm !== ''
          ? Number(req.body.openingKm)
          : null;
      const closingKm =
        req.body?.closingKm != null && req.body.closingKm !== ''
          ? Number(req.body.closingKm)
          : null;

      const claim = await reimbursementsService.apply({
        employeeId,
        title: String(req.body?.title ?? ''),
        description: String(req.body?.description ?? ''),
        amount,
        openingKm: Number.isFinite(openingKm as number) ? (openingKm as number) : null,
        closingKm: Number.isFinite(closingKm as number) ? (closingKm as number) : null,
        proofUrl: req.body?.proofUrl != null ? String(req.body.proofUrl) : null,
        appliedBy: req.user!.id,
      });
      return res.status(201).json(ok(claim));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.get(
  '/my',
  requireAuth,
  requirePermission('REIMBURSEMENTS', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.user!.employeeId);
      if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
      const data = await reimbursementsService.listMine(employeeId);
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.get('/my/pending', requireAuth, async (req: Request, res: Response) => {
  try {
    const data = await reimbursementsService.getPendingForApprover(String(req.user!.id), {
      privilegedAdmin: isPrivilegedAdmin(req),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

reimbursementsRouter.get('/claims/:id', requireAuth, async (req: Request, res: Response) => {
  try {
    const claim = await reimbursementsService.getById(p(req.params.id));
    if (!claim) return res.status(404).json(fail('Not found'));
    return res.json(ok(claim));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

reimbursementsRouter.post('/claims/:id/approve', requireAuth, async (req: Request, res: Response) => {
  try {
    const claim = await reimbursementsService.approveOrReject({
      claimId: p(req.params.id),
      approverUserId: String(req.user!.id),
      action: 'APPROVE',
      remarks: req.body?.remarks != null ? String(req.body.remarks) : undefined,
      allowAdminOverride: isPrivilegedAdmin(req),
    });
    return res.json(ok(claim));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

reimbursementsRouter.post('/claims/:id/reject', requireAuth, async (req: Request, res: Response) => {
  try {
    const claim = await reimbursementsService.approveOrReject({
      claimId: p(req.params.id),
      approverUserId: String(req.user!.id),
      action: 'REJECT',
      remarks: req.body?.remarks != null ? String(req.body.remarks) : undefined,
      allowAdminOverride: isPrivilegedAdmin(req),
    });
    return res.json(ok(claim));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

reimbursementsRouter.post(
  '/claims/:id/cancel',
  requireAuth,
  requirePermission('REIMBURSEMENTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.user!.employeeId);
      const claim = await reimbursementsService.cancel(p(req.params.id), employeeId);
      return res.json(ok(claim));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Admin list ──────────────────────────────────────────────────────────────

reimbursementsRouter.get(
  '/admin',
  requireAuth,
  requireRole(['ADMIN', 'HR', 'HR_MANAGER']),
  async (req: Request, res: Response) => {
    try {
      const statusRaw = req.query.status ? String(req.query.status).toUpperCase() : '';
      const status =
        statusRaw && Object.values(ReimbursementStatus).includes(statusRaw as ReimbursementStatus)
          ? (statusRaw as ReimbursementStatus)
          : undefined;
      const data = await reimbursementsService.listAll({ status });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);
