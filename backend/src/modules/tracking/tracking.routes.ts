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

// Admin/HR: Get all live locations
trackingRouter.get('/live', requireAuth, async (req: Request, res: Response) => {
  try {
    const role = String((req.user as any)?.role ?? '').toUpperCase();
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEM_ADMIN', 'SYSTEM ADMIN', 'HR'].includes(role)) {
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
    const role = String((req.user as any)?.role ?? '').toUpperCase();
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEM_ADMIN', 'SYSTEM ADMIN', 'HR'].includes(role)) {
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
    const role = String((req.user as any)?.role ?? '').toUpperCase();
    if (!['SUPERADMIN', 'ADMIN', 'SYSTEM_ADMIN', 'SYSTEM ADMIN', 'HR'].includes(role)) {
      return res.status(403).json(fail('Forbidden: Only System Admin, Admin, and HR can view trip routes.'));
    }
    const tripId = String(req.params.id);
    const data = await trackingService.getTripRoute(tripId);
    return res.json(ok(data));
  } catch (e: any) {
    return res.status(400).json(fail(e.message));
  }
});
