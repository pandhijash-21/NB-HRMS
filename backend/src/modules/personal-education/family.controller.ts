import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { familyService } from './family.service';

const memberSchema = z.object({
  id: z.string().uuid().optional(),
  relation: z.string().min(1),
  name: z.string().min(1),
  city: z.string().min(1).nullable().optional(),
  mobileNo: z.string().min(1).nullable().optional(),
  phoneNo: z.string().min(1).nullable().optional(),
  personalEmail: z.string().email().nullable().optional(),
  dateOfBirth: z.string().datetime().nullable().optional(),
  aadhaarNo: z.string().min(4).nullable().optional(), // sensitive
  aadhaarUrl: z.string().url().nullable().optional(),
  isNominee: z.boolean().optional(),
  isDependent: z.boolean().optional(),
  isEmployed: z.boolean().optional(),
  employerName: z.string().min(1).nullable().optional(),
  updatedBy: z.string().min(1).nullable().optional(),
});

function parseDate(input: string) {
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) throw new Error('Invalid date');
  return d;
}

export const familyController = {
  async list(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    const rows = await familyService.list(employeeId);
    return res.json(ok(rows));
  },

  async create(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    const body = memberSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const { phoneNo, ...rest } = body.data;
    const mobileNo = body.data.mobileNo ?? phoneNo ?? null;

    const created = await familyService.create(employeeId, {
      ...rest,
      mobileNo,
      dateOfBirth: body.data.dateOfBirth ? parseDate(body.data.dateOfBirth) : null,
    }, req);

    return res.status(201).json(ok(created));
  },

  async update(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    const memberId = String(req.params.memberId);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (!memberId) return res.status(400).json(fail('Invalid member id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    const body = memberSchema.partial().safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const { phoneNo, id: _id, ...rest } = body.data;
    const mobileNo =
      body.data.mobileNo !== undefined || body.data.phoneNo !== undefined
        ? body.data.mobileNo ?? body.data.phoneNo ?? null
        : undefined;

    const updated = await familyService.update(employeeId, memberId, {
      ...rest,
      ...(mobileNo !== undefined ? { mobileNo } : {}),
      dateOfBirth: body.data.dateOfBirth ? parseDate(body.data.dateOfBirth) : undefined,
    }, req);

    if (!updated) return res.status(404).json(fail('Family member not found'));
    return res.json(ok(updated));
  },

  async softDelete(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    const memberId = String(req.params.memberId);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (!memberId) return res.status(400).json(fail('Invalid member id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    const deleted = await familyService.softDelete(employeeId, memberId, req);
    if (!deleted) return res.status(404).json(fail('Family member not found'));
    return res.json(ok(deleted));
  },
};

