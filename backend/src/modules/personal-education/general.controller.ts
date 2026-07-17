import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { generalService } from './general.service';

const GeneralInfoSchema = z.object({
  fullName:             z.string().min(1),
  originalJoiningDate:  z.string().min(1),
  joiningDate:          z.string().min(1),
  incrementMonth:       z.string().optional().nullable(),
  organization:         z.string().min(1),
  subOrganization:      z.string().optional().nullable(),
  department:           z.string().min(1),
  functionalDepartment: z.string().optional().nullable(),
  firstReportingId:     z.number().int().optional().nullable(),
  secondReportingId:    z.number().int().optional().nullable(),
  thirdReportingId:     z.number().int().optional().nullable(),
  firstApproverUserId:  z.string().uuid().optional().nullable(),
  secondApproverUserId: z.string().uuid().optional().nullable(),
  thirdApproverUserId:  z.string().uuid().optional().nullable(),
  employeeCategory:     z.string().min(1),
  designation:          z.string().min(1),
  shift:                z.string().optional().nullable(),
  appointmentType:      z.string().optional().nullable(),
  employeeCode:         z.string().min(1).optional().nullable(),
  instituteId:          z.string().uuid().optional().nullable(),
});

const GeneralInfoPatchSchema = GeneralInfoSchema.partial();

function parseInput(data: z.infer<typeof GeneralInfoSchema>) {
  return {
    ...data,
    originalJoiningDate: data.originalJoiningDate ? new Date(data.originalJoiningDate) : undefined,
    joiningDate:         data.joiningDate         ? new Date(data.joiningDate)         : undefined,
  };
}

export const generalController = {
  async get(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    const data = await generalService.get(employeeId);
    return res.json(ok(data));
  },

  async create(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const body = GeneralInfoSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    try {
      const created = await generalService.create(employeeId, parseInput(body.data), req.user!.id);
      return res.status(201).json(ok(created));
    } catch (err: any) {
      if (err.code === 'P2002') return res.status(409).json(fail('General info already exists. Use PATCH to update.'));
      throw err;
    }
  },

  async update(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const body = GeneralInfoPatchSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    try {
      const updated = await generalService.update(employeeId, parseInput(body.data as any), req.user!.id, req);
      return res.json(ok(updated));
    } catch (err: any) {
      return res.status(err.status ?? 500).json(fail(err.message ?? 'Internal server error'));
    }
  },
};
