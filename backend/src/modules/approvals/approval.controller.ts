import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { approvalService } from './approval.service';
import { sseService } from '../events/sse.service';
import { prisma } from '../../config/prisma';

const REVIEWER_ROLES = ['ADMIN', 'HR', 'HR_MANAGER', 'SUPER_ADMIN'];

function assertReviewer(req: Request): boolean {
  const role = String((req.user as any)?.roleName ?? (req.user as any)?.role ?? '').toUpperCase();
  return REVIEWER_ROLES.includes(role);
}

function moduleLabel(module: string): string {
  switch (module) {
    case 'PERSONAL':
      return 'Personal Info';
    case 'ADDRESS_LOCAL':
      return 'Local Address';
    case 'ADDRESS_PERMANENT':
      return 'Permanent Address';
    case 'ADDRESS':
      return 'Address';
    case 'OTHER':
      return 'Other Info';
    case 'BANK':
      return 'Bank Info';
    default:
      return module;
  }
}

export const approvalController = {
  /** GET /api/approvals?status=PENDING */
  async list(req: Request, res: Response) {
    try {
      if (!assertReviewer(req)) {
        return res.status(403).json(fail('Only Admin/HR can review profile change requests'));
      }
      const status = req.query.status as 'PENDING' | 'APPROVED' | 'REJECTED' | undefined;
      const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
      const data = await approvalService.list({ status, employeeId });
      return res.json(ok(data));
    } catch (err) {
      console.error('[approvals:list]', err);
      return res.status(500).json(fail('Failed to list requests'));
    }
  },

  /** POST /api/approvals — Employee submits a change request */
  async create(req: Request, res: Response) {
    try {
      const schema = z.object({
        module: z.string().min(1),
        newData: z.record(z.string(), z.unknown()),
      });
      const body = schema.safeParse(req.body);
      if (!body.success) return res.status(400).json(fail(body.error.message));

      const employeeId = req.user?.employeeId ? Number(req.user.employeeId) : null;
      if (!employeeId) {
        console.warn('[approvals:create] No employeeId in JWT for user:', req.user?.id);
        return res.status(403).json(fail('No employee linked to this account. Please log out and log back in.'));
      }

      const result = await approvalService.requestChange(
        employeeId,
        body.data.module,
        body.data.newData,
        req.user!.id,
      );

      const gi = await prisma.employeeGeneralInfo.findUnique({
        where: { employeeId },
        select: { fullName: true, employeeCode: true },
      });
      const changedFields = approvalService.describeChanges(result.oldData, result.newData);
      const who = gi?.fullName ?? `Employee #${employeeId}`;
      const code = gi?.employeeCode ? ` (${gi.employeeCode})` : '';
      const fieldHint =
        changedFields.length > 0
          ? ` Changing: ${changedFields.slice(0, 8).join(', ')}${changedFields.length > 8 ? '…' : ''}`
          : '';

      sseService.toAdmins('change_request_created', {
        id: result.id,
        employeeId,
        employeeName: gi?.fullName ?? null,
        employeeCode: gi?.employeeCode ?? null,
        module: body.data.module,
        changedFields,
        requestedAt: result.requestedAt,
        message: `${who}${code} requested a change to ${moduleLabel(body.data.module)}.${fieldHint}`,
      });

      return res.status(201).json(ok(result));
    } catch (err) {
      console.error('[approvals:create]', err);
      return res.status(500).json(fail('Failed to submit change request'));
    }
  },

  /** POST /api/approvals/:id/approve */
  async approve(req: Request, res: Response) {
    try {
      if (!assertReviewer(req)) {
        return res.status(403).json(fail('Only Admin/HR can approve profile change requests'));
      }
      const id = String(req.params.id);
      const result = await approvalService.approve(id, req.user!.id);
      if (!result) return res.status(404).json(fail('Request not found or already reviewed'));

      sseService.toEmployee(result.employeeId, 'change_request_approved', {
        id: result.id,
        module: result.module,
        message: `Your ${moduleLabel(result.module)} update was approved by HR.`,
      });

      return res.json(ok(result));
    } catch (err: any) {
      console.error('[approvals:approve]', err);
      return res.status(500).json(fail(err?.message ?? 'Failed to approve request'));
    }
  },

  /** POST /api/approvals/:id/reject */
  async reject(req: Request, res: Response) {
    try {
      if (!assertReviewer(req)) {
        return res.status(403).json(fail('Only Admin/HR can reject profile change requests'));
      }
      const id = String(req.params.id);
      const result = await approvalService.reject(id, req.user!.id);
      if (!result) return res.status(404).json(fail('Request not found or already reviewed'));

      sseService.toEmployee(result.employeeId, 'change_request_rejected', {
        id: result.id,
        module: result.module,
        message: `Your ${moduleLabel(result.module)} update was rejected by HR.`,
      });

      return res.json(ok(result));
    } catch (err) {
      console.error('[approvals:reject]', err);
      return res.status(500).json(fail('Failed to reject request'));
    }
  },

  /** GET /api/approvals/pending?module=PERSONAL */
  async getPending(req: Request, res: Response) {
    try {
      const module = String(req.query.module ?? '');
      const employeeId = req.user?.employeeId ? Number(req.user.employeeId) : null;
      if (!employeeId || !module) {
        return res.status(400).json(fail('Missing module or employee ID'));
      }
      const result = await approvalService.getPending(employeeId, module);
      return res.json(ok(result));
    } catch (err) {
      console.error('[approvals:getPending]', err);
      return res.status(500).json(fail('Failed to get pending request'));
    }
  },
};
