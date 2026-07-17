import type { Request, Response } from 'express';
import { z } from 'zod';
import { ok, fail } from '../../utils/response';
import { employeeService } from './employee.service';
import { assignmentService } from './assignment.service';
import { employmentChangeService } from './employmentChange.service';
import {
  canViewEmployeeDirectory,
  canWriteEmployeeDirectory,
  employeeMatchesDirectoryScope,
  resolveDirectoryInstituteFilter,
} from './employeeDirectory.util';

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
  async list(req: Request, res: Response) {
    const limit = Number(req.query.limit) || 20;
    const offset = Number(req.query.offset) || 0;
    const search = req.query.search as string | undefined;
    const status = req.query.status as string | undefined;
    const subOrganization = await resolveDirectoryInstituteFilter(req.user);

    const data = await employeeService.list({ limit, offset, search, status, subOrganization });
    return res.json(ok({ ...data, viewScope: req.user?.employeeViewScope ?? 'NONE' }));
  },

  async getById(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json(fail('Invalid employee id'));

    const isSelf =
      req.user?.employeeId != null && Number(req.user.employeeId) === id;
    if (!isSelf) {
      if (!canViewEmployeeDirectory(req.user)) {
        return res.status(403).json(fail('You do not have permission to view this employee'));
      }
      const allowed = await employeeMatchesDirectoryScope(id, req.user);
      if (!allowed) return res.status(403).json(fail('Employee is outside your access scope'));
    }

    const data = await employeeService.getById(id);
    if (!data) return res.status(404).json(fail('Employee not found'));
    return res.json(ok(data));
  },

  async listAssignments(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json(fail('Invalid employee id'));
    const data = await assignmentService.list(id);
    return res.json(ok(data));
  },

  async backfillAssignments(req: Request, res: Response) {
    // Admin/HR only route (enforced at router)
    const out = await assignmentService.backfillAll(req.user!.id);
    return res.json(ok(out));
  },

  async instituteTransfer(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const Schema = z.object({
      instituteId: z.string().uuid().optional(),
      newSubOrganization: z.string().min(1).optional().nullable(),
      effectiveFrom: z.string().min(1),
      reason: z.string().optional().nullable(),
    }).refine((d) => d.instituteId || d.newSubOrganization, {
      message: 'instituteId or newSubOrganization is required',
    });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    const data = await employmentChangeService.instituteTransfer({
      employeeId,
      instituteId: body.data.instituteId ?? null,
      newSubOrganization: body.data.newSubOrganization ?? null,
      effectiveFrom: body.data.effectiveFrom,
      reason: body.data.reason ?? null,
      changedBy: req.user!.id,
    });
    return res.json(ok(data));
  },

  async designationUpgrade(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const Schema = z.object({
      newDesignation: z.string().min(1),
      effectiveFrom: z.string().min(1),
      reason: z.string().optional().nullable(),
    });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    const data = await employmentChangeService.designationUpgrade({
      employeeId,
      newDesignation: body.data.newDesignation,
      effectiveFrom: body.data.effectiveFrom,
      reason: body.data.reason ?? null,
      changedBy: req.user!.id,
    });
    return res.json(ok(data));
  },

  async update(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json(fail('Invalid employee id'));

    const body = updateSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    const isSelf =
      req.user?.employeeId != null && Number(req.user.employeeId) === id;
    if (!isSelf) {
      if (!canWriteEmployeeDirectory(req.user)) {
        return res.status(403).json(fail('You do not have permission to edit this employee'));
      }
      const allowed = await employeeMatchesDirectoryScope(id, req.user);
      if (!allowed) return res.status(403).json(fail('Employee is outside your access scope'));
    }

    const updated = await employeeService.update(id, body.data);
    if (!updated) return res.status(404).json(fail('Employee not found'));
    return res.json(ok(updated));
  },

  async assignPosition(req: Request, res: Response) {
    const employeeId = Number(req.params.id);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employee id'));

    const Schema = z.object({
      positionDesignationId: z.string().uuid().nullable(),
    });
    const body = Schema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.issues[0]?.message ?? 'Validation error'));

    if (!canWriteEmployeeDirectory(req.user)) {
      return res.status(403).json(fail('You do not have permission to assign positions'));
    }
    const allowed = await employeeMatchesDirectoryScope(employeeId, req.user);
    if (!allowed) return res.status(403).json(fail('Employee is outside your access scope'));

    try {
      const data = await employeeService.assignPosition(
        employeeId,
        body.data.positionDesignationId,
        req.user!.id,
      );
      return res.json(ok(data));
    } catch (err: unknown) {
      return res.status(400).json(fail(err instanceof Error ? err.message : 'Failed to assign position'));
    }
  },

  async createFull(req: Request, res: Response) {
    console.log('POST /api/employees/full hit with:', req.body);
    const FullCreateSchema = z.object({
      fullName: z.string().min(1),
      personalEmail: z.string().email(),
      institutionalEmail: z.string().email().optional().nullable(),
      designation: z.string().min(1),
      department: z.string().min(1),
      joiningDate: z.string().transform((str) => new Date(str)),
      employeeCategory: z.string().min(1),
      employeeCode: z.string().min(1),
      // New: approver user ids (employee user or position user). NULL bypasses layer.
      firstApproverUserId: z.string().optional().nullable(),
      secondApproverUserId: z.string().optional().nullable(),
      thirdApproverUserId: z.string().optional().nullable(),
      // Legacy (kept for backward compatibility with older clients)
      firstReportingId: z.number().int().optional().nullable(),
      secondReportingId: z.number().int().optional().nullable(),
      thirdReportingId: z.number().int().optional().nullable(),
      instituteId: z.string().uuid().optional(),
      subOrganization: z.string().optional().nullable(),
      positionDesignationId: z.string().uuid().optional().nullable(),
      abbreviation: z.string().min(1).max(10).optional().nullable(),
    });

    const body = FullCreateSchema.safeParse(req.body);
    if (!body.success) return res.status(400).json(fail(body.error.message));

    try {
      const created = await employeeService.createFull(body.data, req.user!.id);
      return res.status(201).json(ok(created));
    } catch (err: any) {
      let message = err.message || "An error occurred";
      
      // Map common Prisma errors
      if (err.code === 'P2002') {
        const target = err.meta?.target || [];
        if (target.includes('employee_code')) {
          message = "Employee Code already exists. Please use a unique code.";
        } else if (target.includes('institute_email')) {
          message = "Institutional Email already exists. Please use a unique email.";
        } else {
          message = "A record with this unique information already exists.";
        }
      }
      
      return res.status(400).json(fail(message));
    }
  },

  async listNames(req: Request, res: Response) {
    const subOrganization = await resolveDirectoryInstituteFilter(req.user);
    const employees = await employeeService.listNames({ subOrganization });
    return res.json(ok(employees));
  },

  async delete(req: Request, res: Response) {
    const id = Number(req.params.id);
    if (!Number.isFinite(id)) return res.status(400).json(fail('Invalid employee id'));

    const deleted = await employeeService.softDelete(id, req.user!.id);
    if (!deleted) return res.status(404).json(fail('Employee not found'));
    return res.json(ok({ message: 'Employee deactivated successfully' }));
  },
};
