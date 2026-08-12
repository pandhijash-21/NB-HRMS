import { Router, Request, Response } from 'express';
import { requireAuth } from '../../middleware/auth';
import { ok, fail } from '../../utils/response';
import { trackingService } from './tracking.service';

export const trackingRouter = Router();

// Employee: Update their own live location
trackingRouter.post('/live', requireAuth, async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    
    const { latitude, longitude, heading } = req.body;
    
    if (latitude == null || longitude == null) {
      return res.status(400).json(fail('Latitude and longitude are required.'));
    }

    const data = await trackingService.updateLocation({
      employeeId,
      latitude: Number(latitude),
      longitude: Number(longitude),
      heading: Number(heading ?? 0),
    });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Employee: Send device heartbeat for gap detection
trackingRouter.post('/heartbeat', requireAuth, async (req: Request, res: Response) => {
  try {
    const employeeId = Number(req.user!.employeeId);
    if (!employeeId) return res.status(400).json(fail('Employee ID not found in token'));
    
    const { batteryLevel, networkStatus, permissionStatus, locationServiceEnabled, lastKnownGapReason } = req.body;

    await trackingService.processHeartbeat({
      employeeId,
      batteryLevel: batteryLevel ? Number(batteryLevel) : null,
      networkStatus: networkStatus ? String(networkStatus) : null,
      permissionStatus: permissionStatus ? String(permissionStatus) : null,
      locationServiceEnabled: locationServiceEnabled === true || locationServiceEnabled === 'true',
      lastKnownGapReason: lastKnownGapReason ? String(lastKnownGapReason) : null,
    });
    
    return res.json(ok({ success: true }));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Get all live locations
trackingRouter.get('/live', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view live tracking.'));
    }
    
    const data = await trackingService.getAllLiveLocations();
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Get all trips (optionally filtered by employee)
trackingRouter.get('/trips', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view trips.'));
    }
    const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
    const data = await trackingService.getAllTrips(employeeId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Get specific trip route
trackingRouter.get('/trips/:id/route', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view trip routes.'));
    }
    const tripId = String(req.params.id);
    const data = await trackingService.getTripRoute(tripId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Get Tracking Hub KPIs
trackingRouter.get('/hub-kpis', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view KPIs.'));
    }
    const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
    const data = await trackingService.getHubKPIs(employeeId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Get tracking events for a trip (Timeline gaps)
trackingRouter.get('/trips/:id/events', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view events.'));
    }
    const tripId = String(req.params.id);
    const data = await trackingService.getTripEvents(tripId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Employee-wise location availability for a day (punch-in → punch-out)
trackingRouter.get('/hub-day', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view availability.'));
    }
    const date = String(req.query.date || '').trim();
    if (!date) return res.status(400).json(fail('date query (YYYY-MM-DD) is required'));
    const employeeId = req.query.employeeId ? Number(req.query.employeeId) : undefined;
    const data = await trackingService.getHubDayAvailability({ date, employeeId });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});

// Admin/HR: Single employee availability detail
trackingRouter.get('/availability/:employeeId', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase().replace(/[\s_]/g, '');
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEMADMIN', 'HR', 'DEVELOPER'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view availability.'));
    }
    const employeeId = Number(req.params.employeeId);
    if (!Number.isFinite(employeeId)) return res.status(400).json(fail('Invalid employeeId'));
    const date = String(req.query.date || '').trim();
    if (!date) return res.status(400).json(fail('date query (YYYY-MM-DD) is required'));
    const data = await trackingService.getEmployeeAvailability({ employeeId, date });
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});
