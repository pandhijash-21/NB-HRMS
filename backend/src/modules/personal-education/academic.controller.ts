import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { academicService } from './academic.service';

const createSchema = z.object({
  degreeType: z.enum(['SSC', 'HSC', 'DIPLOMA', 'BACHELOR', 'MASTER', 'PHD']),
  degreeName: z.string().min(1).nullable().optional(),
  medium: z.enum(['GUJARATI', 'HINDI', 'ENGLISH', 'MARATHI', 'OTHER']).nullable().optional(),
  boardUniversity: z.string().min(1),
  schoolCollege: z.string().min(1),
  passingYear: z.number().int(),
  percentage: z.number().nullable().optional(),
  grade: z.string().min(1).nullable().optional(),
  specialization: z.string().min(1).nullable().optional(),
  durationYears: z.number().int().nullable().optional(),
  totalSemesters: z.number().int().nullable().optional(),
  certificateUrl: z.string().url().nullable().optional(),
  sem1MarksheetUrl: z.string().url().nullable().optional(),
  sem2MarksheetUrl: z.string().url().nullable().optional(),
  sem3MarksheetUrl: z.string().url().nullable().optional(),
  sem4MarksheetUrl: z.string().url().nullable().optional(),
  sem5MarksheetUrl: z.string().url().nullable().optional(),
  sem6MarksheetUrl: z.string().url().nullable().optional(),
  sem7MarksheetUrl: z.string().url().nullable().optional(),
  sem8MarksheetUrl: z.string().url().nullable().optional(),
  displayOrder: z.number().int().optional(),
  updatedBy: z.string().min(1).nullable().optional(),
});

export const academicController = {
  async list(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }
    const rows = await academicService.list(employeeId);
    return res.json(ok(rows));
  },

  async create(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }
    const body = createSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));
    const created = await academicService.create(employeeId, body.data, req.user?.id);
    return res.status(201).json(ok(created));
  },

  async update(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    const qualId = String(req.params.qualId);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (!qualId) return res.status(400).json(fail('Invalid qualification id'));
    if (req.user?.role === 'EMPLOYEE' && req.user.employeeId && req.user.employeeId !== employeeId) {
      return res.status(403).json(fail('Forbidden'));
    }

    const body = createSchema.partial().safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));
    const updated = await academicService.update(employeeId, qualId, body.data, req.user?.id);
    if (!updated) return res.status(404).json(fail('Qualification not found'));
    return res.json(ok(updated));
  },
};

