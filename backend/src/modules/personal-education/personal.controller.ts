import type { Request, Response } from 'express';
import { z } from 'zod';
import { fail, ok } from '../../utils/response';
import { personalService } from './personal.service';
import {
  canViewEmployeeDirectory,
  employeeMatchesDirectoryScope,
} from './employeeDirectory.util';
import { assertMayDirectWriteProfile } from './profileWriteGuard';
async function assertCanAccessEmployeePersonal(
  req: Request,
  employeeId: number,
  res: Response,
): Promise<boolean> {
  const isSelf =
    req.user?.employeeId != null && Number(req.user.employeeId) === employeeId;
  if (isSelf) return true;

  if (!canViewEmployeeDirectory(req.user)) {
    res.status(403).json(fail('Forbidden'));
    return false;
  }

  const allowed = await employeeMatchesDirectoryScope(employeeId, req.user);
  if (!allowed) {
    res.status(403).json(fail('Forbidden'));
    return false;
  }
  return true;
}

const personalUpsertSchema = z.object({
  birthDate: z.string().datetime().or(z.string().min(4)),
  birthPlace: z.string().min(1).nullable().optional(),
  homeTown: z.string().min(1).nullable().optional(),
  gender: z.string().min(1),
  maritalStatus: z.string().min(1),
  nationality: z.string().min(1).optional(),
  motherTongue: z.string().min(1).nullable().optional(),
  bloodGroup: z.string().nullable().optional(),
  castCategory: z.string().min(1).nullable().optional(),
  subCaste: z.string().min(1).nullable().optional(),
  nomineeName: z.string().min(1).nullable().optional(),
  nomineeRelation: z.string().min(1).nullable().optional(),

  // sensitive (REST only)
  aadhaarNo: z.string().min(4).nullable().optional(),
  panNo: z.string().min(4).nullable().optional(),

  // urls
  aadhaarCardUrl: z.string().url().nullable().optional(),
  panCardUrl: z.string().url().nullable().optional(),
  otherDocumentUrl: z.string().url().nullable().optional(),

  passportNo: z.string().min(1).nullable().optional(),
  passportIssuePlace: z.string().min(1).nullable().optional(),
  passportIssueDate: z.string().datetime().nullable().optional(),
  passportExpiryDate: z.string().datetime().nullable().optional(),

  updatedBy: z.string().min(1).nullable().optional(),
});

function parseDate(input: string) {
  const d = new Date(input);
  if (Number.isNaN(d.getTime())) throw new Error('Invalid date');
  return d;
}

export const personalController = {
  async get(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    if (!(await assertCanAccessEmployeePersonal(req, employeeId, res))) return;

    const data = await personalService.get(employeeId);
    if (!data) return res.status(404).json(fail('Personal info not found'));
    return res.json(ok(data));
  },

  async create(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (!(await assertCanAccessEmployeePersonal(req, employeeId, res))) return;

    try {
      await assertMayDirectWriteProfile(req, employeeId, 'PERSONAL');
    } catch (err: any) {
      return res.status(err.status ?? 403).json(fail(err.message));
    }

    const body = personalUpsertSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const created = await personalService.create(employeeId, {
      ...body.data,
      birthDate: parseDate(body.data.birthDate),
      passportIssueDate: body.data.passportIssueDate ? parseDate(body.data.passportIssueDate) : null,
      passportExpiryDate: body.data.passportExpiryDate ? parseDate(body.data.passportExpiryDate) : null,
    }, req);

    return res.status(201).json(ok(created));
  },

  async update(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));
    if (!(await assertCanAccessEmployeePersonal(req, employeeId, res))) return;

    try {
      await assertMayDirectWriteProfile(req, employeeId, 'PERSONAL');
    } catch (err: any) {
      return res.status(err.status ?? 403).json(fail(err.message));
    }

    const body = personalUpsertSchema.partial().safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const updated = await personalService.update(employeeId, {
      ...body.data,
      birthDate: body.data.birthDate ? parseDate(body.data.birthDate) : undefined,
      passportIssueDate: body.data.passportIssueDate ? parseDate(body.data.passportIssueDate) : undefined,
      passportExpiryDate: body.data.passportExpiryDate ? parseDate(body.data.passportExpiryDate) : undefined,
    }, req);

    if (!updated) return res.status(404).json(fail('Personal info not found'));
    return res.json(ok(updated));
  },
};

