import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { otherService } from './other.service';
import { assertMayDirectWriteProfile } from './profileWriteGuard';

const OtherInfoSchema = z.object({
  skillSet:        z.string().optional().nullable(),
  hobbies:         z.string().optional().nullable(),
  strength:        z.string().optional().nullable(),
  weakness:        z.string().optional().nullable(),
  isHandicapped:   z.boolean().optional(),
  handicapDetails: z.string().optional().nullable(),
  heightInFeet:    z.number().positive().optional().nullable(),
  weightInKg:      z.number().positive().optional().nullable(),
});

function assertSelfAccess(req: Request, employeeId: number) {
  if (req.user?.roleName === 'EMPLOYEE' && req.user.employeeId !== employeeId) {
    throw { status: 403, message: 'Forbidden' };
  }
}

export const otherController = {
  async get(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    assertSelfAccess(req, employeeId);
    const data = await otherService.get(employeeId);
    return res.json(ok(data));
  },

  async create(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    assertSelfAccess(req, employeeId);
    try {
      await assertMayDirectWriteProfile(req, employeeId, 'OTHER');
    } catch (err: any) {
      return res.status(err.status ?? 403).json(fail(err.message));
    }

    const body = OtherInfoSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    try {
      const created = await otherService.create(employeeId, body.data, req.user!.id);
      return res.status(201).json(ok(created));
    } catch (err: any) {
      if (err.code === 'P2002') return res.status(409).json(fail('Other info already exists. Use PATCH to update.'));
      throw err;
    }
  },

  async update(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    assertSelfAccess(req, employeeId);
    try {
      await assertMayDirectWriteProfile(req, employeeId, 'OTHER');
    } catch (err: any) {
      return res.status(err.status ?? 403).json(fail(err.message));
    }

    const body = OtherInfoSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    try {
      const updated = await otherService.update(employeeId, body.data, req.user!.id, req);
      return res.json(ok(updated));
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Internal server error'));
    }
  },
};
