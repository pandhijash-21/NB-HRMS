import type { Request, Response } from 'express';
import { z } from 'zod';
import { fail, ok } from '../../utils/response';
import { experienceService } from './experience.service';

const fields = z.object({
  type: z.string().trim().min(1),
  designation: z.string().trim().min(1),
  organizationName: z.string().trim().min(1),
  fromDate: z.coerce.date(),
  toDate: z.coerce.date(),
  jobDescription: z.string().trim().nullable().optional(),
  lastSalary: z.coerce.number().nonnegative().nullable().optional(),
  experienceLetterUrl: z.string().url().nullable().optional(),
  lastPaycheckUrl: z.string().url().nullable().optional(),
  recommendationLetters: z.array(z.string().url()).optional(),
});

const schema = fields.refine((v) => v.toDate >= v.fromDate, {
  message: 'To date cannot be before from date',
  path: ['toDate'],
});

function employeeId(req: Request): number | null {
  const id = Number(req.params.id);
  return Number.isInteger(id) && id > 0 ? id : null;
}

export const experienceController = {
  async list(req: Request, res: Response) {
    const id = employeeId(req);
    if (id == null) return res.status(400).json(fail('Invalid employee id'));
    return res.json(ok(await experienceService.list(id)));
  },

  async create(req: Request, res: Response) {
    const id = employeeId(req);
    if (id == null) return res.status(400).json(fail('Invalid employee id'));
    const body = schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Invalid experience'));
    return res.status(201).json(ok(await experienceService.create(id, body.data)));
  },

  async update(req: Request, res: Response) {
    const id = employeeId(req);
    if (id == null) return res.status(400).json(fail('Invalid employee id'));
    const body = fields.partial().safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Invalid experience'));
    const updated = await experienceService.update(id, String(req.params.experienceId), body.data);
    if (!updated) return res.status(404).json(fail('Experience not found'));
    return res.json(ok(updated));
  },

  async remove(req: Request, res: Response) {
    const id = employeeId(req);
    if (id == null) return res.status(400).json(fail('Invalid employee id'));
    const removed = await experienceService.remove(id, String(req.params.experienceId));
    if (!removed) return res.status(404).json(fail('Experience not found'));
    return res.json(ok(removed));
  },
};
