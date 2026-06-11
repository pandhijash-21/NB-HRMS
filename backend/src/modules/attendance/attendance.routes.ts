import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission } from '../../middleware/rbac';
import { ok, fail } from '../../utils/response';
import { attendanceService } from './attendance.service';

export const attendanceRouter = Router();

// Employee: calendar view
attendanceRouter.get('/my/calendar', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    const from = String(req.query.from ?? '');
    const to = String(req.query.to ?? '');
    const data = await attendanceService.getMyCalendarPunches({ employeeId, from, to });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.get('/my/day', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    const date = String(req.query.date ?? '');
    const data = await attendanceService.getMyDayPunches({ employeeId, date });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: view all employees punches for a date
attendanceRouter.get('/admin/day', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '');
    if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }
    const date = String(req.query.date ?? '');
    const data = await attendanceService.getAdminDayPunches({ date });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.post('/admin/punch', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '');
    if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }
    const employeeId = Number(req.body?.employeeId);
    const punchAt = String(req.body?.punchAt ?? '');
    const punchType = req.body?.punchType != null ? String(req.body.punchType) : null;
    const terminalId = req.body?.terminalId != null ? String(req.body.terminalId) : null;
    const data = await attendanceService.createAdminPunch({ employeeId, punchAt, punchType, terminalId });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.patch('/admin/punch/:id', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '');
    if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }
    const punchId = String(req.params.id ?? '');
    const punchAt = String(req.body?.punchAt ?? '');
    const punchType = req.body?.punchType != null ? String(req.body.punchType) : null;
    const terminalId = req.body?.terminalId != null ? String(req.body.terminalId) : null;
    const data = await attendanceService.updateAdminPunch({ punchId, punchAt, punchType, terminalId });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: attendance policy (default punch in/out + buffers)
attendanceRouter.get('/admin/policy', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '');
    if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }
    const data = await attendanceService.getAdminPolicy();
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.patch('/admin/policy', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '');
    if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }

    const defaultPunchInTime = String(req.body?.defaultPunchInTime ?? '');
    const defaultPunchOutTime = String(req.body?.defaultPunchOutTime ?? '');
    const punchInBufferMinutes = Number(req.body?.punchInBufferMinutes);
    const punchOutBufferMinutes = Number(req.body?.punchOutBufferMinutes);
    const updatedBy = String((req.user as any)?.id ?? (req.user as any)?.userId ?? 'unknown');

    const data = await attendanceService.updateAdminPolicy({
      defaultPunchInTime,
      defaultPunchOutTime,
      punchInBufferMinutes,
      punchOutBufferMinutes,
      updatedBy,
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

