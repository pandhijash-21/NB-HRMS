import { prisma } from '../../config/prisma';
import { getRedisClient, connectRedis } from '../../config/redis';

export interface LiveLocation {
  employeeId: number;
  latitude: number;
  longitude: number;
  heading: number;
  updatedAt: string;
  fullName?: string;
  designation?: string;
  isPunchedIn?: boolean;
  isOutsideGeofence?: boolean;
}

function getDistanceFromLatLonInKm(lat1: number, lon1: number, lat2: number, lon2: number) {
  var R = 6371;
  var dLat = deg2rad(lat2-lat1);
  var dLon = deg2rad(lon2-lon1); 
  var a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * 
    Math.sin(dLon/2) * Math.sin(dLon/2)
    ; 
  var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
  return R * c;
}

function deg2rad(deg: number) {
  return deg * (Math.PI/180)
}

export const trackingService = {
  async updateLocation(params: { employeeId: number; latitude: number; longitude: number; heading: number }) {
    await connectRedis();
    const redis = getRedisClient();
    const key = `live_location:${params.employeeId}`;
    
    let empInfo: LiveLocation | null = null;
    const existing = await redis.get(key);
    
    if (existing) {
      try {
        empInfo = JSON.parse(existing);
      } catch (e) {}
    }
    
    if (!empInfo?.fullName) {
      const emp = await prisma.employee.findUnique({
        where: { id: params.employeeId },
        include: { generalInfo: { select: { fullName: true, designation: true } } }
      });
      if (emp) {
        empInfo = {
          employeeId: params.employeeId,
          latitude: params.latitude,
          longitude: params.longitude,
          heading: params.heading,
          updatedAt: new Date().toISOString(),
          fullName: emp.generalInfo?.fullName,
          designation: emp.generalInfo?.designation || ''
        };
      } else {
        throw new Error('Employee not found');
      }
    } else {
      empInfo.latitude = params.latitude;
      empInfo.longitude = params.longitude;
      empInfo.heading = params.heading;
      empInfo.updatedAt = new Date().toISOString();
    }

    // Determine isPunchedIn and isOutsideGeofence
    const istNow = new Date(Date.now() + 330 * 60 * 1000);
    const y = istNow.getUTCFullYear();
    const m = istNow.getUTCMonth();
    const d = istNow.getUTCDate();
    const startOfDay = new Date(Date.UTC(y, m, d, -5, -30, 0, 0)); // IST 00:00:00 -> UTC -5:30
    const endOfDay = new Date(Date.UTC(y, m, d, 18, 29, 59, 999)); // IST 23:59:59 -> UTC 18:29:59

    const punches = await prisma.attendancePunch.findMany({
      where: {
        employeeId: params.employeeId,
        punchAt: { gte: startOfDay, lte: endOfDay }
      }
    });

    const isPunchedIn = punches.length === 1;
    let isOutsideGeofence = false;

    if (isPunchedIn) {
      // Store history
      await prisma.locationHistory.create({
        data: {
          employeeId: params.employeeId,
          latitude: params.latitude,
          longitude: params.longitude,
          heading: params.heading
        }
      });

      // Check geofences
      const activeLocs = await prisma.attendanceLocation.findMany({
        where: { isActive: true }
      });
      
      if (activeLocs.length > 0) {
        let insideAny = false;
        for (const loc of activeLocs) {
          if (loc) {
            const dist = getDistanceFromLatLonInKm(params.latitude, params.longitude, loc.latitude, loc.longitude);
            if (dist <= loc.radiusKm) {
              insideAny = true;
              break;
            }
          }
        }
        isOutsideGeofence = !insideAny;
      }
    }

    empInfo.isPunchedIn = isPunchedIn;
    empInfo.isOutsideGeofence = isOutsideGeofence;
    
    // Store in Redis with TTL of 2 minutes (120 seconds)
    // If they don't ping within 2 minutes, they disappear from the live map
    await redis.setEx(key, 120, JSON.stringify(empInfo));
    
    return { success: true };
  },

  async getAllLiveLocations(): Promise<LiveLocation[]> {
    await connectRedis();
    const redis = getRedisClient();
    const keys = await redis.keys('live_location:*');
    
    if (keys.length === 0) return [];
    
    const data = await redis.mGet(keys);
    const locations: LiveLocation[] = [];
    
    for (const item of data) {
      if (item) {
        try {
          locations.push(JSON.parse(item));
        } catch (e) {}
      }
    }
    
    return locations;
  }
};


