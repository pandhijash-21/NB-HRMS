import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { approvalService } from './approval.service';
import { sseService } from '../events/sse.service';

export const approvalController = {
  /** GET /api/approvals?status=PENDING */
  async list(req: Request, res: Response) {
    try {
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
        req.user!.id
      );

      // 🔔 Real-time: notify all admins immediately
      sseService.toAdmins('change_request_created', {
        id: result.id,
        employeeId,
        module: body.data.module,
        requestedAt: result.requestedAt,
        message: `Employee #${employeeId} requested a change to ${body.data.module}`,
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
      const id = String(req.params.id);
      const result = await approvalService.approve(id, req.user!.id);
      if (!result) return res.status(404).json(fail('Request not found or already reviewed'));

      // 🔔 Real-time: notify the employee their request was approved
      sseService.toEmployee(result.employeeId, 'change_request_approved', {
        id: result.id,
        module: result.module,
        message: `Your ${result.module} update was approved by HR.`,
      });

      return res.json(ok(result));
    } catch (err) {
      console.error('[approvals:approve]', err);
      return res.status(500).json(fail('Failed to approve request'));
    }
  },

  /** POST /api/approvals/:id/reject */
  async reject(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      const result = await approvalService.reject(id, req.user!.id);
      if (!result) return res.status(404).json(fail('Request not found or already reviewed'));

      // 🔔 Real-time: notify the employee their request was rejected
      sseService.toEmployee(result.employeeId, 'change_request_rejected', {
        id: result.id,
        module: result.module,
        message: `Your ${result.module} update was reviewed by HR.`,
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
