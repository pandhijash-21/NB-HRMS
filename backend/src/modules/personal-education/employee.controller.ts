import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { employeeService } from './employee.service';

const createSchema = z.object({
  userId: z.string().min(1),
  abbreviation: z.string().min(1).max(10).optional(),
  status: z.enum(['ACTIVE', 'INACTIVE', 'ON_LEAVE', 'RESIGNED', 'RETIRED', 'TERMINATED']).optional(),
  createdBy: z.string().min(1).optional(),
});

const updateSchema = z.object({
  abbreviation: z.string().min(1).max(10).nullable().optional(),
  status: z.enum(['ACTIVE', 'INACTIVE', 'ON_LEAVE', 'RESIGNED', 'RETIRED', 'TERMINATED']).optional(),
  photoUrl: z.string().url().nullable().optional(),
  signatureUrl: z.string().url().nullable().optional(),
});

export const employeeController = {
  async getById(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json(fail('Invalid employee id'));

    // EMPLOYEE can only read self (if token includes employeeId)
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== id) {
      return res.status(403).json(fail('Forbidden'));
    }

    const data = await employeeService.getById(id);
    if (!data) return res.status(404).json(fail('Employee not found'));
    return res.json(ok(data));
  },

  async create(req: Request, res: Response) {
    const body = createSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));
    const created = await employeeService.create(body.data);
    return res.status(201).json(ok(created));
  },

  async update(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json(fail('Invalid employee id'));

    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== id) {
      return res.status(403).json(fail('Forbidden'));
    }

    const body = updateSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));
    const updated = await employeeService.update(id, body.data);
    if (!updated) return res.status(404).json(fail('Employee not found'));
    return res.json(ok(updated));
  },
};

