import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { requirePermission, requireSelfEmployeeOrPermission } from '../../middleware/rbac';
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

attendanceRouter.get('/admin/employee/:employeeId/history', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '');
    if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
      return res.status(403).json(fail('Forbidden'));
    }
    const employeeId = Number(req.params.employeeId);
    if (!Number.isFinite(employeeId) || employeeId <= 0) {
      return res.status(400).json(fail('Invalid employeeId'));
    }

    // Default range = current month in IST (UTC+05:30)
    const istNow = new Date(Date.now() + 330 * 60 * 1000);
    const y = istNow.getUTCFullYear();
    const m = istNow.getUTCMonth() + 1;
    const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
    const defaultFrom = `${y}-${String(m).padStart(2, '0')}-01`;
    const defaultTo = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;

    const from = String(req.query.from ?? defaultFrom);
    const to = String(req.query.to ?? defaultTo);
    const data = await attendanceService.getAdminEmployeeHistory({ employeeId, from, to });
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

attendanceRouter.patch('/admin/policy', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
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

// Employee-specific punch windows (self read; admin/HR write)
attendanceRouter.get(
  '/employee/:employeeId/settings',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'ATTENDANCE', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const data = await attendanceService.getEmployeeAttendanceSettings(employeeId);
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

attendanceRouter.patch(
  '/employee/:employeeId/settings',
  requireAuth,
  (req, res, next) => {
    const role = String((req.user as { role?: string })?.role ?? '').toUpperCase();
    if (['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) return next();
    return requirePermission('ATTENDANCE', 'WRITE')(req, res, next);
  },
  async (req: Request, res: Response) => {
    try {
      const role = String((req.user as any)?.role ?? '');
      if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
        return res.status(403).json(fail('Forbidden'));
      }
      const employeeId = Number(req.params.employeeId);
      const updatedBy = String((req.user as any)?.id ?? 'unknown');
      const data = await attendanceService.updateEmployeeAttendanceSettings(employeeId, {
        useGlobalPolicy: req.body?.useGlobalPolicy,
        punchInTime: req.body?.punchInTime,
        punchOutTime: req.body?.punchOutTime,
        punchInBufferMinutes: req.body?.punchInBufferMinutes,
        punchOutBufferMinutes: req.body?.punchOutBufferMinutes,
        updatedBy,
      });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// Monthly attendance + leave summary (self or admin)
attendanceRouter.get(
  '/employee/:employeeId/monthly-summary',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'ATTENDANCE', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const year = Number(req.query.year ?? new Date().getFullYear());
      const month = Number(req.query.month ?? new Date().getMonth() + 1);
      const data = await attendanceService.getEmployeeMonthlySummary({ employeeId, year, month });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

// Employee history with evaluation (self or admin)
attendanceRouter.get(
  '/employee/:employeeId/history',
  requireAuth,
  requireSelfEmployeeOrPermission('employeeId', 'ATTENDANCE', 'READ'),
  async (req: Request, res: Response) => {
    try {
      const employeeId = Number(req.params.employeeId);
      const istNow = new Date(Date.now() + 330 * 60 * 1000);
      const y = istNow.getUTCFullYear();
      const m = istNow.getUTCMonth() + 1;
      const lastDay = new Date(Date.UTC(y, m, 0)).getUTCDate();
      const defaultFrom = `${y}-${String(m).padStart(2, '0')}-01`;
      const defaultTo = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
      const from = String(req.query.from ?? defaultFrom);
      const to = String(req.query.to ?? defaultTo);
      const data = await attendanceService.getAdminEmployeeHistory({ employeeId, from, to });
      return res.json(ok(data));
    } catch (e: any) {
      return res.status(400).json(fail(e.message));
    }
  },
);

function requireAttendanceAdmin(req: Request, res: Response): boolean {
  const role = String((req.user as { role?: string } | undefined)?.role ?? '');
  if (!['ADMIN', 'HR', 'HR_MANAGER'].includes(role)) {
    res.status(403).json(fail('Forbidden'));
    return false;
  }
  return true;
}

// Admin: add manual punch
attendanceRouter.post('/admin/punch', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { employeeId, punchAt, punchType, terminalId } = req.body;
    if (!employeeId || !punchAt) {
      return res.status(400).json(fail('employeeId and punchAt are required'));
    }
    const data = await attendanceService.createAdminPunch({
      employeeId: Number(employeeId),
      punchAt: String(punchAt),
      punchType: punchType ? String(punchType) : null,
      terminalId: terminalId ? String(terminalId) : null,
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin: edit existing punch
attendanceRouter.patch('/admin/punch/:punchId', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { punchAt, punchType, terminalId } = req.body;
    if (!punchAt) {
      return res.status(400).json(fail('punchAt is required'));
    }
    const data = await attendanceService.updateAdminPunch({
      punchId: req.params.punchId,
      punchAt: String(punchAt),
      punchType: punchType ? String(punchType) : null,
      terminalId: terminalId ? String(terminalId) : null,
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

/** Device / biometric sync status (PayTime MSSQL + optional eTimeOffice). */
attendanceRouter.get('/admin/device/status', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { attendanceSyncService } = await import('./attendanceSync.service');
    return res.json(ok(await attendanceSyncService.getDeviceStatus()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

attendanceRouter.get('/admin/device/meta', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { fetchPaytimeMeta } = await import('./esslMssql.client');
    return res.json(ok(await fetchPaytimeMeta()));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

attendanceRouter.post('/admin/device/sync', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { attendanceSyncService } = await import('./attendanceSync.service');
    const data = await attendanceSyncService.syncDeviceNow();
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

attendanceRouter.get('/admin/device/preview', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const from = String(req.query.from ?? '');
    const to = String(req.query.to ?? '');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
      return res.status(400).json(fail('from and to must be YYYY-MM-DD'));
    }
    const empcode = req.query.empcode ? String(req.query.empcode) : undefined;
    const source = String(req.query.source ?? 'paytime'); // paytime | etimeoffice
    const { loadPunchIdEmployeeMap, lookupPunchIdEmployee } = await import('./punchId.mapper');

    if (source === 'etimeoffice') {
      const mode = String(req.query.mode ?? 'raw');
      const { fetchPunchDataMcid, fetchInOutPunchData } = await import('./etimeoffice.client');
      const punchMap = await loadPunchIdEmployeeMap();
      if (mode === 'inout') {
        const rows = await fetchInOutPunchData({ empcode, fromYmd: from, toYmd: to });
        return res.json(
          ok(
            rows.map((r) => {
              const m = lookupPunchIdEmployee(punchMap, r.Empcode);
              return {
                ...r,
                name: m?.fullName ?? null,
                matchedEmployeeId: m?.employeeId ?? null,
              };
            }),
          ),
        );
      }
      const rows = await fetchPunchDataMcid({ empcode, fromYmd: from, toYmd: to });
      return res.json(
        ok(
          rows.map((r) => {
            const m = lookupPunchIdEmployee(punchMap, r.Empcode);
            return {
              name: m?.fullName ?? null,
              empcode: r.Empcode,
              punchDate: r.PunchDate,
              mcid: r.mcid ?? null,
              mFlag: r.M_Flag ?? null,
              matchedEmployeeId: m?.employeeId ?? null,
            };
          }),
        ),
      );
    }

    const { fetchPaytimePunchesInRange, isPaytimeMssqlConfigured } = await import('./esslMssql.client');
    if (!isPaytimeMssqlConfigured()) {
      return res.status(400).json(fail('PayTime MSSQL is not configured'));
    }
    const punchMap = await loadPunchIdEmployeeMap();
    const rows = await fetchPaytimePunchesInRange({
      fromYmd: from,
      toYmd: to,
      punchId: empcode,
    });
    return res.json(
      ok(
        rows.map((r) => {
          const m = lookupPunchIdEmployee(punchMap, r.punchId);
          return {
            name: m?.fullName ?? null,
            empcode: r.punchId,
            punchDate: r.punchAt.toISOString(),
            mcid: r.terminalId ?? null,
            mFlag: r.punchType ?? null,
            matchedEmployeeId: m?.employeeId ?? null,
          };
        }),
      ),
    );
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

attendanceRouter.post('/admin/device/backfill', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const from = String(req.body?.from ?? '');
    const to = String(req.body?.to ?? '');
    const empcode = req.body?.empcode ? String(req.body.empcode) : undefined;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to)) {
      return res.status(400).json(fail('from and to must be YYYY-MM-DD'));
    }
    const { attendanceSyncService } = await import('./attendanceSync.service');
    // Prefer PayTime when configured
    const { isPaytimeMssqlConfigured } = await import('./esslMssql.client');
    const data = isPaytimeMssqlConfigured()
      ? await attendanceSyncService.backfillPaytime({ fromYmd: from, toYmd: to, punchId: empcode })
      : await attendanceSyncService.backfillEtimeoffice({ fromYmd: from, toYmd: to, empcode });
    return res.json(ok(data));
  } catch (e: unknown) {
    return res.status(400).json(fail(e instanceof Error ? e.message : 'Failed'));
  }
});

// --- Attendance Location Management ---

attendanceRouter.get('/admin/locations', requireAuth, requirePermission('ATTENDANCE', 'READ'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const data = await attendanceService.getLocations();
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.post('/admin/locations', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { name, latitude, longitude, radiusKm, isUnique, isActive } = req.body;
    const data = await attendanceService.createLocation({
      name: String(name),
      latitude: Number(latitude),
      longitude: Number(longitude),
      radiusKm: Number(radiusKm),
      isUnique: isUnique !== undefined ? Boolean(isUnique) : false,
      isActive: Boolean(isActive ?? true),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.patch('/admin/locations/:id', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const { name, latitude, longitude, radiusKm, isUnique, isActive } = req.body;
    const data = await attendanceService.updateLocation(req.params.id as string, {
      name: name !== undefined ? String(name) : undefined,
      latitude: latitude !== undefined ? Number(latitude) : undefined,
      longitude: longitude !== undefined ? Number(longitude) : undefined,
      radiusKm: radiusKm !== undefined ? Number(radiusKm) : undefined,
      isUnique: isUnique !== undefined ? Boolean(isUnique) : undefined,
      isActive: isActive !== undefined ? Boolean(isActive) : undefined,
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.delete('/admin/locations/:id', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req, res) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    await attendanceService.deleteLocation(req.params.id as string);
    return res.json(ok({ deleted: true }));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// --- Geofenced App Punch ---

attendanceRouter.post('/my/verify-location', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req, res) => {
  try {
    const { latitude, longitude } = req.body;
    if (latitude == null || longitude == null) {
      return res.status(400).json(fail('Latitude and longitude are required.'));
    }
    const data = await attendanceService.verifyLocation(Number(latitude), Number(longitude));
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.post('/my/punch', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    
    const { latitude, longitude, deviceInfo, biometricVerified, biometricToken, reason } = req.body;
    
    if (latitude == null || longitude == null) {
      return res.status(400).json(fail('Latitude and longitude are required.'));
    }

    const data = await attendanceService.createGeofencedPunch({
      employeeId,
      latitude: Number(latitude),
      longitude: Number(longitude),
      deviceInfo: deviceInfo ?? null,
      biometricVerified: Boolean(biometricVerified),
      biometricToken: biometricToken ? String(biometricToken) : null,
      reason: reason ? String(reason) : undefined,
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.post('/my/register-biometrics', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    const { biometricToken } = req.body;
    if (!biometricToken) return res.status(400).json(fail('biometricToken is required'));
    const updatedBy = String(req.user!.id ?? (req.user as any)?.userId ?? 'unknown');
    const data = await attendanceService.registerBiometricToken(employeeId, String(biometricToken), updatedBy);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

attendanceRouter.post('/admin/reset-biometrics/:employeeId', requireAuth, requirePermission('ATTENDANCE', 'WRITE'), async (req: Request, res: Response) => {
  try {
    if (!requireAttendanceAdmin(req, res)) return;
    const employeeId = Number(req.params.employeeId);
    if (!employeeId) return res.status(400).json(fail('Invalid employeeId'));
    const updatedBy = String(req.user!.id ?? (req.user as any)?.userId ?? 'unknown');
    const data = await attendanceService.resetBiometricToken(employeeId, updatedBy);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});




