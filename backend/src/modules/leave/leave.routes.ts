import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';

const p = (v: string | string[]) => (Array.isArray(v) ? v[0] : v);
import { requireRole, requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { leaveApplicationService } from './leaveApplication.service';
import { leaveAdminService } from './leaveAdmin.service';
import { absenceLwpService } from './absenceLwp.service';

export const leaveRouter = Router();

const adminOrHR = requireRole(['ADMIN', 'HR', 'HR_MANAGER']);
const approverRoles = requireRole(['ADMIN', 'HR', 'HR_MANAGER', 'HOD', 'HOI', 'VC', 'REGISTRAR']);

// ─── Employee: apply / cancel / view own leaves ─────────────────────────────

leaveRouter.post('/apply', requireAuth, requirePermission('LEAVE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    const app = await leaveApplicationService.apply({
      ...req.body,
      employeeId,
      appliedBy: req.user!.id,
      isAppliedByAdmin: false,
    });
    return res.status(201).json(ok(app));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

leaveRouter.post('/applications/:id/cancel', requireAuth, requirePermission('LEAVE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    await leaveApplicationService.cancel(p(req.params.id), req.user!.id, Number(req.user!.employeeId));
    return res.json(ok({ cancelled: true }));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

leaveRouter.get('/my/applications', requireAuth, requirePermission('LEAVE', 'READ'), async (req: Request, res: Response) => {
  const employeeId = Number(req.user!.employeeId);
  const q = req.query as Record<string, string>;
  const result = await leaveApplicationService.list({
    employeeId,
    status: q.status || undefined,
    year: q.year ? Number(q.year) : undefined,
    page: q.page ? Number(q.page) : 0,
    limit: q.limit ? Number(q.limit) : 20,
  });
  return res.json(ok(result));
});

leaveRouter.get('/my/balances', requireAuth, requirePermission('LEAVE', 'READ'), async (req: Request, res: Response) => {
  const employeeId = Number(req.user!.employeeId);
  const year = req.query.year ? Number(String(req.query.year)) : undefined;
  const balances = await leaveApplicationService.getBalances(employeeId, year);
  return res.json(ok(balances));
});

leaveRouter.get('/my/pending-approvals', requireAuth, approverRoles, async (req: Request, res: Response) => {
  const approverEmployeeId = Number(req.user!.employeeId);
  const apps = await leaveApplicationService.getPendingForApprover(approverEmployeeId);
  return res.json(ok(apps));
});

leaveRouter.get('/applications/:id', requireAuth, async (req: Request, res: Response) => {
  const app = await leaveApplicationService.getById(p(req.params.id));
  if (!app) return res.status(404).json(fail('Not found'));
  return res.json(ok(app));
});

// ─── Approver: approve / reject ─────────────────────────────────────────────

leaveRouter.post('/applications/:id/approve', requireAuth, approverRoles, async (req: Request, res: Response) => {
  try {
    const approverEmployeeId = Number(req.user!.employeeId);
    const result = await leaveAdminService.approveStep(
      p(req.params.id),
      approverEmployeeId,
      req.user!.id,
      String(req.body.remarks ?? ''),
    );
    return res.json(ok(result));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

leaveRouter.post('/applications/:id/reject', requireAuth, approverRoles, async (req: Request, res: Response) => {
  try {
    const approverEmployeeId = Number(req.user!.employeeId);
    const result = await leaveAdminService.rejectStep(
      p(req.params.id),
      approverEmployeeId,
      req.user!.id,
      String(req.body.remarks ?? ''),
    );
    return res.json(ok(result));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ─── Admin: applications list ────────────────────────────────────────────────

leaveRouter.get('/admin/applications', requireAuth, requirePermission('LEAVE', 'READ'), async (req: Request, res: Response) => {
  const q = req.query as Record<string, string>;
  const result = await leaveApplicationService.list({
    employeeId: q.employeeId ? Number(q.employeeId) : undefined,
    status: q.status || undefined,
    year: q.year ? Number(q.year) : undefined,
    page: q.page ? Number(q.page) : 0,
    limit: q.limit ? Number(q.limit) : 20,
  });
  return res.json(ok(result));
});

leaveRouter.post('/admin/apply', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const app = await leaveApplicationService.apply({
      ...req.body,
      appliedBy: req.user!.id,
      isAppliedByAdmin: true,
    });
    return res.status(201).json(ok(app));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ─── Admin: leave types ──────────────────────────────────────────────────────

leaveRouter.get('/admin/types', requireAuth, requirePermission('LEAVE', 'READ'), async (_req, res) => {
  const types = await leaveAdminService.listTypes();
  return res.json(ok(types));
});

leaveRouter.post('/admin/types', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const lt = await leaveAdminService.upsertType(req.body);
    return res.json(ok(lt));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

leaveRouter.delete('/admin/types/:code', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const lt = await leaveAdminService.deleteType(p(req.params.code));
    return res.json(ok(lt));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ─── Admin: settings ─────────────────────────────────────────────────────────

leaveRouter.get('/admin/settings', requireAuth, requirePermission('LEAVE', 'READ'), async (_req, res) => {
  const settings = await leaveAdminService.listSettings();
  return res.json(ok(settings));
});

leaveRouter.patch('/admin/settings/:key', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  const updated = await leaveAdminService.updateSetting(p(req.params.key), req.body.value, req.user!.id);
  return res.json(ok(updated));
});

// ─── Admin: public holidays ──────────────────────────────────────────────────

leaveRouter.get('/admin/holidays', requireAuth, requirePermission('LEAVE', 'READ'), async (req: Request, res: Response) => {
  const year = req.query.year ? Number(String(req.query.year)) : undefined;
  const holidays = await leaveAdminService.listHolidays(year);
  return res.json(ok(holidays));
});

leaveRouter.post('/admin/holidays', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const h = await leaveAdminService.addHoliday(req.body);
    return res.status(201).json(ok(h));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

leaveRouter.delete('/admin/holidays/:id', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  await leaveAdminService.deleteHoliday(p(req.params.id));
  return res.json(ok({ deleted: true }));
});

// ─── Admin: balance management ───────────────────────────────────────────────

leaveRouter.get('/admin/balances/:employeeId', requireAuth, requirePermission('LEAVE', 'READ'), async (req: Request, res: Response) => {
  const year = req.query.year ? Number(String(req.query.year)) : undefined;
  const balances = await leaveAdminService.getEmployeeBalances(Number(p(req.params.employeeId)), year);
  return res.json(ok(balances));
});

leaveRouter.post('/admin/balances/adjust', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const result = await leaveAdminService.adjustBalance({ ...req.body, actorId: req.user!.id });
    return res.json(ok(result));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ─── Admin: year-end ─────────────────────────────────────────────────────────

leaveRouter.post('/admin/year-end', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const year = req.body.year ?? new Date().getUTCFullYear();
    const result = await leaveAdminService.runYearEnd(year, req.user!.id);
    return res.json(ok(result));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ─── Admin: workflow config ──────────────────────────────────────────────────

leaveRouter.get('/admin/workflow-config', requireAuth, adminOrHR, async (_req, res) => {
  const config = await leaveAdminService.getWorkflowConfig();
  return res.json(ok(config));
});

leaveRouter.post('/admin/workflow-config/dept', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  const cfg = await leaveAdminService.setDeptApprover(req.body.department, req.body.hodEmployeeId, req.user!.id);
  return res.json(ok(cfg));
});

leaveRouter.post('/admin/workflow-config/institute', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  const cfg = await leaveAdminService.setInstituteApprover(req.body.institute, req.body.hoiEmployeeId, req.user!.id);
  return res.json(ok(cfg));
});

leaveRouter.post('/admin/workflow-config/global', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  const cfg = await leaveAdminService.setGlobalApprover(
    req.body.vcEmployeeId ?? null,
    req.body.registrarEmployeeId ?? null,
    req.user!.id,
  );
  return res.json(ok(cfg));
});

// ─── Admin: absences ─────────────────────────────────────────────────────────

leaveRouter.get('/admin/absences', requireAuth, requirePermission('LEAVE', 'READ'), async (req: Request, res: Response) => {
  const q = req.query as Record<string, string>;
  const absences = await absenceLwpService.listAbsences({
    employeeId: q.employeeId ? Number(q.employeeId) : undefined,
    year: q.year ? Number(q.year) : undefined,
    month: q.month ? Number(q.month) : undefined,
  });
  return res.json(ok(absences));
});

leaveRouter.post('/admin/absences/mark', requireAuth, adminOrHR, async (req: Request, res: Response) => {
  try {
    const record = await absenceLwpService.markAbsent({
      employeeId: Number(req.body.employeeId),
      date: new Date(req.body.date),
      actorId: req.user!.id,
    });
    return res.status(201).json(ok(record));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// ─── Leave types (public) ────────────────────────────────────────────────────

leaveRouter.get('/types', requireAuth, async (_req, res) => {
  const types = await prisma.leaveType.findMany({ where: { isActive: true }, orderBy: { code: 'asc' } });
  return res.json(ok(types));
});

import { prisma } from '../../config/prisma';
