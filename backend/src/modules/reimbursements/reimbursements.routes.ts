import { Router, Request, Response } from 'express';
import {
  ReimbursementAmountMode,
  ReimbursementFieldKind,
  ReimbursementStatus,
} from '@prisma/client';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireRole } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { reimbursementsService } from './reimbursements.service';

export const reimbursementsRouter = Router();

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);

function isPrivilegedAdmin(req: Request) {
  const role = String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '').toUpperCase();
  return ['ADMIN', 'HR', 'HR_MANAGER', 'SUPERADMIN', 'SYSTEM_ADMIN'].includes(role);
}

const adminRoles = ['ADMIN', 'HR', 'HR_MANAGER'] as const;

function parseFieldKind(raw: unknown): ReimbursementFieldKind | null {
  const s = String(raw ?? '').toUpperCase();
  return (Object.values(ReimbursementFieldKind) as string[]).includes(s)
    ? (s as ReimbursementFieldKind)
    : null;
}

function parseAmountMode(raw: unknown): ReimbursementAmountMode | null {
  const s = String(raw ?? '').toUpperCase();
  return (Object.values(ReimbursementAmountMode) as string[]).includes(s)
    ? (s as ReimbursementAmountMode)
    : null;
}

function parseValues(body: any) {
  const raw = body?.values;
  if (!Array.isArray(raw)) return [];
  return raw.map((v: any) => ({
    fieldKey: String(v?.fieldKey ?? v?.key ?? ''),
    value: v?.value ?? null,
    proofUrl: v?.proofUrl != null ? String(v.proofUrl) : null,
  }));
}

// ─── Types (active for apply forms) ──────────────────────────────────────────

reimbursementsRouter.get(
  '/types/active',
  requireAuth,
  requirePermission('REIMBURSEMENTS', 'READ'),
  async (_req: Request, res: Response) => {
    try {
      const data = await reimbursementsService.listTypes({ activeOnly: true });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Admin type/field config ─────────────────────────────────────────────────

reimbursementsRouter.get(
  '/types',
  requireAuth,
  requireRole([...adminRoles]),
  async (_req: Request, res: Response) => {
    try {
      const data = await reimbursementsService.listTypes();
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.post(
  '/types',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const amountMode = parseAmountMode(req.body?.amountMode) ?? undefined;
      const fieldsRaw = Array.isArray(req.body?.fields) ? req.body.fields : undefined;
      const created = await reimbursementsService.createType({
        code: String(req.body?.code ?? req.body?.name ?? ''),
        name: String(req.body?.name ?? ''),
        description: req.body?.description != null ? String(req.body.description) : null,
        amountMode,
        ratePerUnit:
          req.body?.ratePerUnit != null && req.body.ratePerUnit !== ''
            ? Number(req.body.ratePerUnit)
            : null,
        approverUserId:
          req.body?.approverUserId != null && String(req.body.approverUserId).trim()
            ? String(req.body.approverUserId).trim()
            : null,
        sortOrder: req.body?.sortOrder != null ? Number(req.body.sortOrder) : undefined,
        fields: fieldsRaw?.map((f: any, i: number) => ({
          key: f?.key != null ? String(f.key) : undefined,
          label: String(f?.label ?? ''),
          fieldKind: parseFieldKind(f?.fieldKind) ?? ReimbursementFieldKind.TEXT,
          requiresProof: Boolean(f?.requiresProof),
          isRequired: f?.isRequired !== false,
          sortOrder: f?.sortOrder != null ? Number(f.sortOrder) : i + 1,
        })),
      });
      return res.status(201).json(ok(created));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.patch(
  '/types/:id',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const amountMode = req.body?.amountMode != null ? parseAmountMode(req.body.amountMode) : undefined;
      if (req.body?.amountMode != null && !amountMode) {
        return res.status(400).json(fail('Invalid amountMode'));
      }
      const updated = await reimbursementsService.updateType(p(req.params.id), {
        name: req.body?.name != null ? String(req.body.name) : undefined,
        description:
          req.body?.description !== undefined
            ? req.body.description == null
              ? null
              : String(req.body.description)
            : undefined,
        amountMode: amountMode ?? undefined,
        ratePerUnit:
          req.body?.ratePerUnit !== undefined
            ? req.body.ratePerUnit == null || req.body.ratePerUnit === ''
              ? null
              : Number(req.body.ratePerUnit)
            : undefined,
        approverUserId:
          req.body?.approverUserId !== undefined
            ? req.body.approverUserId == null || String(req.body.approverUserId).trim() === ''
              ? null
              : String(req.body.approverUserId).trim()
            : undefined,
        isActive: req.body?.isActive != null ? Boolean(req.body.isActive) : undefined,
        sortOrder: req.body?.sortOrder != null ? Number(req.body.sortOrder) : undefined,
      });
      return res.json(ok(updated));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.delete(
  '/types/:id',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const data = await reimbursementsService.deleteType(p(req.params.id));
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.put(
  '/types/:id/fields',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const fieldsRaw = Array.isArray(req.body?.fields) ? req.body.fields : [];
      const data = await reimbursementsService.replaceFields(
        p(req.params.id),
        fieldsRaw.map((f: any, i: number) => ({
          key: f?.key != null ? String(f.key) : undefined,
          label: String(f?.label ?? ''),
          fieldKind: parseFieldKind(f?.fieldKind) ?? ReimbursementFieldKind.TEXT,
          requiresProof: Boolean(f?.requiresProof),
          isRequired: f?.isRequired !== false,
          sortOrder: f?.sortOrder != null ? Number(f.sortOrder) : i + 1,
        })),
      );
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.post(
  '/types/:id/fields',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const kind = parseFieldKind(req.body?.fieldKind);
      if (!kind) return res.status(400).json(fail('Invalid fieldKind'));
      const created = await reimbursementsService.addField(p(req.params.id), {
        key: req.body?.key != null ? String(req.body.key) : undefined,
        label: String(req.body?.label ?? ''),
        fieldKind: kind,
        requiresProof: Boolean(req.body?.requiresProof),
        isRequired: req.body?.isRequired !== false,
        sortOrder: req.body?.sortOrder != null ? Number(req.body.sortOrder) : undefined,
      });
      return res.status(201).json(ok(created));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.patch(
  '/fields/:fieldId',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const kind =
        req.body?.fieldKind != null ? parseFieldKind(req.body.fieldKind) : undefined;
      if (req.body?.fieldKind != null && !kind) {
        return res.status(400).json(fail('Invalid fieldKind'));
      }
      const updated = await reimbursementsService.updateField(p(req.params.fieldId), {
        label: req.body?.label != null ? String(req.body.label) : undefined,
        fieldKind: kind ?? undefined,
        requiresProof:
          req.body?.requiresProof != null ? Boolean(req.body.requiresProof) : undefined,
        isRequired: req.body?.isRequired != null ? Boolean(req.body.isRequired) : undefined,
        sortOrder: req.body?.sortOrder != null ? Number(req.body.sortOrder) : undefined,
      });
      return res.json(ok(updated));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

reimbursementsRouter.delete(
  '/fields/:fieldId',
  requireAuth,
  requireRole([...adminRoles]),
  async (req: Request, res: Response) => {
    try {
      const data = await reimbursementsService.deleteField(p(req.params.fieldId));
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// ─── Apply / my list ─────────────────────────────────────────────────────────

reimbursementsRouter.post(
  '/apply',
  requireAuth,
  requirePermission('REIMBURSEMENTS', 'WRITE'),
  async (req: Request, res: Response) => {
    try {
      const selfEmployeeId = Number(req.user!.employeeId);
      const bodyEmployeeId =
        req.body?.employeeId != null && req.body.employeeId !== ''
          ? Number(req.body.employeeId)
          : null;
      const explicitOnBehalf = req.body?.onBehalf === true || req.body?.onBehalf === 'true';
      const onBehalf =
        explicitOnBehalf ||
        (bodyEmployeeId != null &&
          Number.isFinite(bodyEmployeeId) &&
          bodyEmployeeId !== selfEmployeeId);

      if (onBehalf && !isPrivilegedAdmin(req)) {
        return res.status(403).json(fail('Only Admin/HR can apply on behalf of staff'));
      }

      const employeeId = onBehalf
        ? (bodyEmployeeId as number)
        : selfEmployeeId;
      if (!employeeId || !Number.isFinite(employeeId)) {
        return res.status(400).json(fail('Employee ID is required'));
      }

      const typeId = String(req.body?.typeId ?? '');
      if (!typeId) return res.status(400).json(fail('typeId is required'));

      const claim = await reimbursementsService.apply({
        employeeId,
        appliedBy: req.user!.id,
        typeId,
        claimDate: req.body?.claimDate ?? null,
        title: req.body?.title != null ? String(req.body.title) : null,
        description: req.body?.description != null ? String(req.body.description) : null,
        values: parseValues(req.body),
        amount:
          req.body?.amount != null && req.body.amount !== ''
            ? Number(req.body.amount)
            : null,
        onBehalf,
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
  requireRole([...adminRoles]),
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
