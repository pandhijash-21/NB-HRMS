import { prisma } from '../../config/prisma';
import { getRedisClient, connectRedis } from '../../config/redis';
import { TrackingEventType } from '@prisma/client';
import { deriveDayInOut } from '../attendance/dayPunch.rules';
import {
  getRecentLocationAlerts,
  notifyAdminsLocationUnavailable,
} from './tracking.alerts';

export interface LiveLocation {
  employeeId: number;
  latitude: number;
  longitude: number;
  heading: number;
  updatedAt: string;
  fullName?: string;
  designation?: string;
  photoUrl?: string | null;
  isPunchedIn?: boolean;
  isOutsideGeofence?: boolean;
  tripId?: string | null;
  /** ISO time when the employee last started being stationary on the current trip */
  stoppedSince?: string | null;
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

type TripRow = {
  id: string;
  employeeId: number;
  startTime: Date;
  endTime: Date | null;
};

/** Close a trip: distance, optional OSRM geometry, hub stats. */
async function finalizeTrip(
  trip: TripRow,
  tip: {
    latitude: number;
    longitude: number;
    heading: number;
    endLocationId: string | null;
  },
) {
  const tripPoints = await prisma.locationHistory.findMany({
    where: { tripId: trip.id },
    orderBy: { timestamp: 'asc' },
  });

  const allPoints = [
    ...tripPoints,
    {
      id: 'temp',
      employeeId: trip.employeeId,
      latitude: tip.latitude,
      longitude: tip.longitude,
      heading: tip.heading,
      timestamp: new Date(),
      tripId: trip.id,
    },
  ];

  let totalDistanceKm = 0;
  let routeGeometry: string | null = null;
  let activeTime = 0;
  let idleTime = 0;

  let windowStartPoint = allPoints[0];
  if (windowStartPoint) {
    for (let i = 1; i < allPoints.length; i++) {
      const p = allPoints[i]!;
      const timeDiffSec =
        (new Date(p.timestamp).getTime() - new Date(windowStartPoint.timestamp).getTime()) /
        1000;
      const distKm = getDistanceFromLatLonInKm(
        windowStartPoint.latitude,
        windowStartPoint.longitude,
        p.latitude,
        p.longitude,
      );

      if (timeDiffSec >= 180) {
        if (distKm < 0.02) idleTime += timeDiffSec;
        else activeTime += timeDiffSec;
        windowStartPoint = p;
      }
    }
  }

  if (allPoints.length >= 2) {
    try {
      let samplePoints = allPoints;
      if (allPoints.length > 100) {
        const step = allPoints.length / 100;
        samplePoints = Array.from({ length: 100 }, (_, i) => allPoints[Math.floor(i * step)]!);
      }
      const coordinates = samplePoints.map((p) => `${p.longitude},${p.latitude}`).join(';');
      const osrmUrl = `https://router.project-osrm.org/match/v1/driving/${coordinates}?geometries=geojson&overview=full`;
      const res = await fetch(osrmUrl);
      const osrmData = await res.json();
      if (osrmData.code === 'Ok' && osrmData.matchings?.length > 0) {
        const bestMatch = osrmData.matchings[0];
        totalDistanceKm = bestMatch.distance / 1000.0;
        routeGeometry = JSON.stringify(bestMatch.geometry);
      }
    } catch (err) {
      console.error('OSRM match failed on backend', err);
    }
    if (totalDistanceKm <= 0) {
      for (let i = 1; i < allPoints.length; i++) {
        totalDistanceKm += getDistanceFromLatLonInKm(
          allPoints[i - 1]!.latitude,
          allPoints[i - 1]!.longitude,
          allPoints[i]!.latitude,
          allPoints[i]!.longitude,
        );
      }
    }
  }

  let gapCount = 0;
  let totalGapDuration = 0;
  try {
    const events = await prisma.trackingEvent.findMany({ where: { tripId: trip.id } });
    gapCount = events.filter((e) => e.eventType !== 'MANUAL_PAUSE').length;
    for (const ev of events) {
      if (ev.eventType !== 'MANUAL_PAUSE' && ev.endTime) {
        totalGapDuration += (ev.endTime.getTime() - ev.timestamp.getTime()) / 1000;
      }
    }
  } catch (err) {
    console.error('[tracking] gap calc skipped', err);
  }

  const tripDurationSec = (Date.now() - trip.startTime.getTime()) / 1000;
  const trackingUptimePercent =
    tripDurationSec > 0
      ? Math.max(0, 100 * (1 - totalGapDuration / tripDurationSec))
      : 100.0;

  await prisma.trip.update({
    where: { id: trip.id },
    data: {
      endTime: new Date(),
      distanceKm: totalDistanceKm,
      endLocationId: tip.endLocationId,
      routeGeometry,
      activeTime: Math.round(activeTime),
      idleTime: Math.round(idleTime),
      trackingUptimePercent,
      gapCount,
      totalGapDuration: Math.round(totalGapDuration),
    },
  });
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

    const prevLat = empInfo?.latitude;
    const prevLng = empInfo?.longitude;
    const prevStoppedSince = empInfo?.stoppedSince ?? null;
    
    if (!empInfo?.fullName) {
      const emp = await prisma.employee.findUnique({
        where: { id: params.employeeId },
        select: {
          photoUrl: true,
          generalInfo: { select: { fullName: true, designation: true } },
        },
      });
      if (emp) {
        empInfo = {
          employeeId: params.employeeId,
          latitude: params.latitude,
          longitude: params.longitude,
          heading: params.heading,
          updatedAt: new Date().toISOString(),
          fullName: emp.generalInfo?.fullName,
          designation: emp.generalInfo?.designation || '',
          photoUrl: emp.photoUrl ?? null,
        };
      } else {
        throw new Error('Employee not found');
      }
    } else {
      empInfo.latitude = params.latitude;
      empInfo.longitude = params.longitude;
      empInfo.heading = params.heading;
      empInfo.updatedAt = new Date().toISOString();
      if (empInfo.photoUrl === undefined) {
        try {
          const emp = await prisma.employee.findUnique({
            where: { id: params.employeeId },
            select: { photoUrl: true },
          });
          empInfo.photoUrl = emp?.photoUrl ?? null;
        } catch (_) {}
      }
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
      },
      orderBy: { punchAt: 'asc' },
      select: { punchAt: true, source: true },
    });

    // On-duty for tracking: prefer mobile punch pairs so a mid-day machine scan
    // does not clear "punched in" and block trip start/recording.
    const mobilePunches = punches.filter((p) => String(p.source) === 'MOBILE_APP');
    let isPunchedIn: boolean;
    if (mobilePunches.length > 0) {
      isPunchedIn = mobilePunches.length % 2 === 1;
    } else {
      const { firstIn, lastOut } = deriveDayInOut(punches);
      isPunchedIn = Boolean(firstIn) && !lastOut;
      if (!isPunchedIn && punches.length > 0) {
        isPunchedIn = punches.length % 2 === 1;
      }
    }
    let isOutsideGeofence = false;
    let currentTripId: string | null = null;

    // Always resolve any open trip (even if punched out) so we can close it.
    const activeTrip = await prisma.trip.findFirst({
      where: { employeeId: params.employeeId, endTime: null },
      orderBy: { startTime: 'desc' },
    });
    currentTripId = activeTrip?.id || null;

    // Punch-out while a trip is open â†’ end & save the trip (so it shows in Trips / Hub).
    if (!isPunchedIn && activeTrip) {
      try {
        await finalizeTrip(activeTrip, {
          latitude: params.latitude,
          longitude: params.longitude,
          heading: params.heading,
          endLocationId: null,
        });
      } catch (err) {
        console.error('[tracking] failed to finalize trip on punch-out', err);
        try {
          await prisma.trip.update({
            where: { id: activeTrip.id },
            data: { endTime: new Date() },
          });
        } catch (e2) {
          console.error('[tracking] failed hard-end trip', e2);
        }
      }
      currentTripId = null;
    }

    if (isPunchedIn) {
        const activeLocs = await prisma.attendanceLocation.findMany({
          where: { isActive: true }
        });
        
        if (activeLocs.length > 0) {
          let insideAny = false;
          let enteredGeofenceId: string | null = null;
          for (const loc of activeLocs) {
          if (loc) {
            const dist = getDistanceFromLatLonInKm(params.latitude, params.longitude, loc.latitude, loc.longitude);
            if (dist <= loc.radiusKm) {
              insideAny = true;
              enteredGeofenceId = loc.id;
              break;
            }
          }
        }
        isOutsideGeofence = !insideAny;

        // Start a trip whenever punched-in + outside + no open trip
        if (isOutsideGeofence && !currentTripId) {
          try {
            const newTrip = await prisma.trip.create({
              data: {
                employeeId: params.employeeId,
                // Outside → no current geofence id (do not use enteredGeofenceId).
                startLocationId: null,
              },
            });
            currentTripId = newTrip.id;
            console.log(`[tracking] trip started ${currentTripId} for employee ${params.employeeId}`);
          } catch (err) {
            console.error('[tracking] trip.create failed', err);
          }
        } else if (!isOutsideGeofence && currentTripId) {
          // Employee re-entered a geofence â†’ end & save trip
          const tripToEnd =
            activeTrip && activeTrip.id === currentTripId
              ? activeTrip
              : await prisma.trip.findUnique({ where: { id: currentTripId } });
          if (tripToEnd && !tripToEnd.endTime) {
            try {
              await finalizeTrip(tripToEnd, {
                latitude: params.latitude,
                longitude: params.longitude,
                heading: params.heading,
                endLocationId: enteredGeofenceId,
              });
              console.log(`[tracking] trip ended ${tripToEnd.id} for employee ${params.employeeId}`);
            } catch (err) {
              console.error('[tracking] failed to finalize trip on geofence enter', err);
              try {
                await prisma.trip.update({
                  where: { id: tripToEnd.id },
                  data: { endTime: new Date(), endLocationId: enteredGeofenceId },
                });
              } catch (e2) {
                console.error('[tracking] failed hard-end trip', e2);
              }
            }
          }
          currentTripId = null;
        }

        // Store history with tripId (only while trip is open)
        try {
          await prisma.locationHistory.create({
            data: {
              employeeId: params.employeeId,
              latitude: params.latitude,
              longitude: params.longitude,
              heading: params.heading,
              tripId: currentTripId
            }
          });
        } catch (err) {
          console.error('[tracking] locationHistory.create failed', err);
        }
      } else {
        // No geofences configured â€” still track trips while punched in (field mode)
        isOutsideGeofence = true;
        if (!currentTripId) {
          try {
            const newTrip = await prisma.trip.create({
              data: { employeeId: params.employeeId },
            });
            currentTripId = newTrip.id;
            console.log(`[tracking] field-mode trip started ${currentTripId}`);
          } catch (err) {
            console.error('[tracking] field-mode trip.create failed', err);
          }
        }
        try {
          await prisma.locationHistory.create({
            data: {
              employeeId: params.employeeId,
              latitude: params.latitude,
              longitude: params.longitude,
              heading: params.heading,
              tripId: currentTripId,
            },
          });
        } catch (err) {
          console.error('[tracking] locationHistory.create failed', err);
        }
      }
    }

    empInfo.isPunchedIn = isPunchedIn;
    empInfo.isOutsideGeofence = isOutsideGeofence;
    empInfo.tripId = currentTripId;

    // Stopped timer: while on a trip, if displacement < ~20m keep/start stoppedSince
    if (currentTripId && prevLat != null && prevLng != null) {
      const movedKm = getDistanceFromLatLonInKm(
        prevLat,
        prevLng,
        params.latitude,
        params.longitude,
      );
      if (movedKm < 0.02) {
        empInfo.stoppedSince = prevStoppedSince ?? new Date().toISOString();
      } else {
        empInfo.stoppedSince = null;
      }
    } else if (!currentTripId) {
      empInfo.stoppedSince = null;
    } else {
      // First ping of a trip â€” not stopped yet
      empInfo.stoppedSince = null;
    }
    
    // Store in Redis with TTL of 2 minutes (120 seconds)
    // If they don't ping within 2 minutes, they disappear from the live map
    await redis.setEx(key, 120, JSON.stringify(empInfo));

    if (isPunchedIn) {
      try {
        await redis.del(`alert:loc_off:${params.employeeId}`);
      } catch {
        /* ignore */
      }
    }
    
    return { success: true };
  },

  async processHeartbeat(params: { 
    employeeId: number; 
    batteryLevel: number | null; 
    networkStatus: string | null; 
    permissionStatus: string | null; 
    locationServiceEnabled: boolean; 
    lastKnownGapReason: string | null;
  }) {
    await connectRedis();
    const redis = getRedisClient();
    
    const activeTrip = await prisma.trip.findFirst({
      where: { employeeId: params.employeeId, endTime: null },
      orderBy: { startTime: 'desc' }
    });
    
    if (!activeTrip) return;

    if (params.lastKnownGapReason) {
      const lastInferredGap = await prisma.trackingEvent.findFirst({
        where: {
          tripId: activeTrip.id,
          source: 'INFERRED_FROM_HEARTBEAT_GAP',
        },
        orderBy: { timestamp: 'desc' }
      });
      
      if (lastInferredGap && lastInferredGap.confidence === 'LOW') {
        let mappedType: TrackingEventType = 'BACKGROUND_SERVICE_KILLED';
        if (params.lastKnownGapReason === 'NETWORK_UNAVAILABLE') mappedType = 'NETWORK_UNAVAILABLE';
        else if (params.lastKnownGapReason === 'DEVICE_RESTARTED') mappedType = 'DEVICE_RESTARTED';
        else if (params.lastKnownGapReason === 'APP_FORCE_CLOSED') mappedType = 'APP_FORCE_CLOSED';
        else if (params.lastKnownGapReason === 'BATTERY_DIED') mappedType = 'BATTERY_DIED';
        
        await prisma.trackingEvent.update({
          where: { id: lastInferredGap.id },
          data: {
            eventType: mappedType,
            gapReasonId: params.lastKnownGapReason,
            confidence: 'HIGH',
            endTime: new Date()
          }
        });
      }
    }
    
    if (params.permissionStatus && params.permissionStatus !== 'granted') {
      await prisma.trackingEvent.create({
        data: {
          employeeId: params.employeeId,
          tripId: activeTrip.id,
          eventType: 'LOCATION_PERMISSION_REVOKED',
          batteryLevel: params.batteryLevel,
          networkStatus: params.networkStatus,
          source: 'EXPLICIT_EVENT',
          confidence: 'HIGH'
        }
      });
    } else if (!params.locationServiceEnabled) {
      await prisma.trackingEvent.create({
        data: {
          employeeId: params.employeeId,
          tripId: activeTrip.id,
          eventType: 'LOCATION_SERVICE_DISABLED',
          batteryLevel: params.batteryLevel,
          networkStatus: params.networkStatus,
          source: 'EXPLICIT_EVENT',
          confidence: 'HIGH'
        }
      });
    }
    
    const key = `heartbeat:${params.employeeId}`;
    await redis.setEx(key, 90, new Date().toISOString());
  },

  async checkMissingHeartbeats() {
    await connectRedis();
    const redis = getRedisClient();
    
    const activeTrips = await prisma.trip.findMany({
      where: { endTime: null }
    });
    
    for (const trip of activeTrips) {
      const key = `heartbeat:${trip.employeeId}`;
      const exists = await redis.exists(key);
      if (!exists) {
        const lastEvent = await prisma.trackingEvent.findFirst({
          where: { tripId: trip.id },
          orderBy: { timestamp: 'desc' }
        });
        
        if (!lastEvent || (lastEvent.source !== 'INFERRED_FROM_HEARTBEAT_GAP' || lastEvent.endTime != null)) {
          await prisma.trackingEvent.create({
            data: {
              employeeId: trip.employeeId,
              tripId: trip.id,
              eventType: 'BACKGROUND_SERVICE_KILLED',
              source: 'INFERRED_FROM_HEARTBEAT_GAP',
              confidence: 'LOW'
            }
          });
        }
      }
    }

    await this.checkPunchWindowLocationGaps();
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
  },

  async getAllTrips(employeeId?: number) {
    return prisma.trip.findMany({
      where: employeeId ? { employeeId } : undefined,
      include: {
        employee: {
          select: {
            id: true,
            generalInfo: { select: { fullName: true, employeeCode: true, designation: true } }
          }
        }
      },
      orderBy: { startTime: 'desc' }
    });
  },

  async getTripRoute(tripId: string) {
    const trip = await prisma.trip.findUnique({
      where: { id: tripId },
      include: {
        employee: {
          select: {
            photoUrl: true,
            generalInfo: { select: { fullName: true } },
          },
        },
      }
    });
    if (!trip) throw new Error('Trip not found');

    const route = await prisma.locationHistory.findMany({
      where: { tripId },
      orderBy: { timestamp: 'asc' },
      select: { latitude: true, longitude: true, heading: true, timestamp: true }
    });

    return { trip, route };
  },

  async getHubKPIs(employeeId?: number) {
    const whereClause = employeeId ? { employeeId } : {};
    
    // Aggregate overall KPI stats from Trip records
    const trips = await prisma.trip.findMany({ where: whereClause });
    
    let totalDistanceKm = 0;
    let totalActiveTime = 0;
    let totalIdleTime = 0;
    let totalGaps = 0;
    let totalUptimePercent = 0;
    let uptimeSamples = 0;
    
    for (const t of trips) {
      totalDistanceKm += t.distanceKm;
      totalActiveTime += t.activeTime;
      totalIdleTime += t.idleTime;
      totalGaps += t.gapCount;
      if (t.endTime) {
        totalUptimePercent += t.trackingUptimePercent;
        uptimeSamples++;
      }
    }
    
    const averageUptimePercent = uptimeSamples > 0 ? (totalUptimePercent / uptimeSamples) : 100.0;
    
    return {
      totalDistanceKm,
      totalActiveTime,
      totalIdleTime,
      totalGaps,
      averageUptimePercent,
      tripCount: trips.length
    };
  },

  async getTripEvents(tripId: string) {
    const events = await prisma.trackingEvent.findMany({
      where: { tripId },
      orderBy: { timestamp: 'asc' }
    });
    return events;
  },

  /**
   * Employee-wise location availability between punch-in and punch-out for a day.
   * Uses location_history silence (>120s) + tracking_events for reasons.
   */
  async getHubDayAvailability(params: { date: string; employeeId?: number }) {
    const ymd = String(params.date || '').trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(ymd)) {
      throw new Error('Invalid date. Expected YYYY-MM-DD');
    }

    const fromUtc = new Date(`${ymd}T00:00:00+05:30`);
    const toExclusive = new Date(fromUtc.getTime() + 24 * 60 * 60 * 1000);
    const now = new Date();

    const punchWhere: {
      punchAt: { gte: Date; lt: Date };
      employeeId?: number;
    } = { punchAt: { gte: fromUtc, lt: toExclusive } };
    if (params.employeeId) punchWhere.employeeId = params.employeeId;

    const punches = await prisma.attendancePunch.findMany({
      where: punchWhere,
      orderBy: [{ employeeId: 'asc' }, { punchAt: 'asc' }],
      select: { employeeId: true, punchAt: true, source: true },
    });

    const byEmployee = new Map<number, Array<{ punchAt: Date; source: string }>>();
    for (const p of punches) {
      const arr = byEmployee.get(p.employeeId) ?? [];
      arr.push({ punchAt: p.punchAt, source: String(p.source) });
      byEmployee.set(p.employeeId, arr);
    }

    const employeeIds = [...byEmployee.keys()];
    if (employeeIds.length === 0) {
      return { date: ymd, employees: [] };
    }

    const employees = await prisma.employee.findMany({
      where: { id: { in: employeeIds } },
      include: {
        generalInfo: {
          select: { fullName: true, employeeCode: true, designation: true, department: true },
        },
      },
    });
    const empMap = new Map(employees.map((e) => [e.id, e]));

    const locationPoints = await prisma.locationHistory.findMany({
      where: {
        employeeId: { in: employeeIds },
        timestamp: { gte: fromUtc, lt: toExclusive },
      },
      orderBy: { timestamp: 'asc' },
      select: { employeeId: true, timestamp: true },
    });

    const events = await prisma.trackingEvent.findMany({
      where: {
        employeeId: { in: employeeIds },
        timestamp: { gte: fromUtc, lt: toExclusive },
        eventType: { not: 'MANUAL_PAUSE' },
      },
      orderBy: { timestamp: 'asc' },
      select: {
        employeeId: true,
        eventType: true,
        timestamp: true,
        endTime: true,
        confidence: true,
        source: true,
      },
    });

    const pointsByEmp = new Map<number, Date[]>();
    for (const p of locationPoints) {
      const arr = pointsByEmp.get(p.employeeId) ?? [];
      arr.push(p.timestamp);
      pointsByEmp.set(p.employeeId, arr);
    }

    const eventsByEmp = new Map<number, typeof events>();
    for (const ev of events) {
      const arr = eventsByEmp.get(ev.employeeId) ?? [];
      arr.push(ev);
      eventsByEmp.set(ev.employeeId, arr);
    }

    const rows = employeeIds
      .map((id) => {
        const emp = empMap.get(id);
        const dayPunches = byEmployee.get(id) ?? [];
        const { firstIn, lastOut } = deriveDayInOut(dayPunches);
        if (!firstIn) return null;

        const punchIn = new Date(firstIn);
        const punchOut = lastOut ? new Date(lastOut) : (now < toExclusive ? now : new Date(toExclusive.getTime() - 1));
        const windowEnd = punchOut.getTime() < punchIn.getTime() ? punchIn : punchOut;

        return buildEmployeeAvailability({
          employeeId: id,
          fullName: emp?.generalInfo?.fullName ?? `Employee #${id}`,
          employeeCode: emp?.generalInfo?.employeeCode ?? null,
          designation: emp?.generalInfo?.designation ?? null,
          department: emp?.generalInfo?.department ?? null,
          punchIn,
          punchOut: lastOut ? new Date(lastOut) : null,
          stillOnDuty: !lastOut,
          points: (pointsByEmp.get(id) ?? []).filter(
            (t) => t.getTime() >= punchIn.getTime() && t.getTime() <= windowEnd.getTime(),
          ),
          events: eventsByEmp.get(id) ?? [],
          windowEnd,
        });
      })
      .filter((r): r is NonNullable<typeof r> => r != null)
      .sort((a, b) => a.fullName.localeCompare(b.fullName));

    return { date: ymd, employees: rows };
  },

  async getEmployeeAvailability(params: { employeeId: number; date: string }) {
    const day = await this.getHubDayAvailability({
      date: params.date,
      employeeId: params.employeeId,
    });
    const row = day.employees.find((e) => e.employeeId === params.employeeId);
    if (!row) {
      return {
        date: params.date,
        employeeId: params.employeeId,
        punchIn: null,
        punchOut: null,
        stillOnDuty: false,
        availableSeconds: 0,
        unavailableSeconds: 0,
        dutySeconds: 0,
        availablePercent: 0,
        gapCount: 0,
        segments: [],
        fullName: `Employee #${params.employeeId}`,
        employeeCode: null,
        designation: null,
        department: null,
      };
    }
    return { date: params.date, ...row };
  },

  async getRecentAlerts() {
    return getRecentLocationAlerts();
  },

  async getLiveBoard() {
    const locations = await this.getAllLiveLocations();
    const ymd = todayIstYmd();
    const day = await this.getHubDayAvailability({ date: ymd });
    const alerts = await getRecentLocationAlerts();
    const liveIds = new Set(locations.map((l) => l.employeeId));

    const employees = day.employees.map((emp) => {
      const lastSeg = emp.segments[emp.segments.length - 1];
      const currentlyAvailable = lastSeg?.status === 'AVAILABLE';
      return {
        ...emp,
        isLive: liveIds.has(emp.employeeId),
        currentlyAvailable,
      };
    });

    return { date: ymd, locations, employees, alerts };
  },

  async exportTripRecording(tripId: string, format: 'gpx' | 'csv' | 'json') {
    const { trip, route } = await this.getTripRoute(tripId);
    const name = trip.employee?.generalInfo?.fullName ?? `employee-${trip.employeeId}`;
    const safe = name.replace(/[^a-zA-Z0-9._-]+/g, '_').slice(0, 40);
    const start = new Date(trip.startTime).toISOString().slice(0, 10);
    const base = `trip_${safe}_${start}_${tripId.slice(0, 8)}`;

    if (format === 'json') {
      return {
        filename: `${base}.json`,
        contentType: 'application/json; charset=utf-8',
        body: JSON.stringify({ trip, route }, null, 2),
      };
    }

    if (format === 'csv') {
      const lines = ['timestamp,latitude,longitude,heading'];
      for (const p of route) {
        lines.push(
          `${new Date(p.timestamp).toISOString()},${p.latitude},${p.longitude},${p.heading ?? ''}`,
        );
      }
      return {
        filename: `${base}.csv`,
        contentType: 'text/csv; charset=utf-8',
        body: lines.join('\n'),
      };
    }

    const trkpts = route
      .map((p) => {
        const iso = new Date(p.timestamp).toISOString();
        return `      <trkpt lat="${p.latitude}" lon="${p.longitude}"><time>${iso}</time></trkpt>`;
      })
      .join('\n');

    const gpx = `<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="NB-HRMS" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>${xmlEscape(name)} trip ${start}</name>
    <time>${new Date(trip.startTime).toISOString()}</time>
  </metadata>
  <trk>
    <name>${xmlEscape(name)}</name>
    <trkseg>
${trkpts}
    </trkseg>
  </trk>
</gpx>
`;
    return {
      filename: `${base}.gpx`,
      contentType: 'application/gpx+xml; charset=utf-8',
      body: gpx,
    };
  },

  async checkPunchWindowLocationGaps() {
    const ymd = todayIstYmd();
    const day = await this.getHubDayAvailability({ date: ymd });
    let redis: ReturnType<typeof getRedisClient> | null = null;
    try {
      redis = getRedisClient();
    } catch {
      redis = null;
    }

    for (const emp of day.employees) {
      if (!emp.stillOnDuty) {
        if (redis) {
          try {
            await redis.del(`alert:loc_off:${emp.employeeId}`);
          } catch {
            /* ignore */
          }
        }
        continue;
      }

      const lastSeg = emp.segments[emp.segments.length - 1];
      if (!lastSeg || lastSeg.status !== 'UNAVAILABLE') {
        if (redis) {
          try {
            await redis.del(`alert:loc_off:${emp.employeeId}`);
          } catch {
            /* ignore */
          }
        }
        continue;
      }

      const lockKey = `alert:loc_off:${emp.employeeId}`;
      const gapStart = lastSeg.start;
      if (redis) {
        try {
          const existing = await redis.get(lockKey);
          if (existing === gapStart) continue;
          await redis.set(lockKey, gapStart);
        } catch {
          /* still notify once this cycle */
        }
      }

      const lastPing = await prisma.locationHistory.findFirst({
        where: { employeeId: emp.employeeId },
        orderBy: { timestamp: 'desc' },
        select: { latitude: true, longitude: true, timestamp: true, tripId: true },
      });

      await notifyAdminsLocationUnavailable({
        id: `${emp.employeeId}-${gapStart}`,
        employeeId: emp.employeeId,
        fullName: emp.fullName,
        employeeCode: emp.employeeCode,
        designation: emp.designation,
        department: emp.department,
        punchIn: emp.punchIn,
        punchOut: emp.punchOut,
        unavailableSince: gapStart,
        durationSeconds: lastSeg.durationSeconds,
        reason: lastSeg.reason,
        confidence: lastSeg.confidence,
        lastKnownLatitude: lastPing?.latitude ?? null,
        lastKnownLongitude: lastPing?.longitude ?? null,
        lastKnownAt: lastPing?.timestamp ? lastPing.timestamp.toISOString() : null,
        tripId: lastPing?.tripId ?? null,
        notifiedAt: new Date().toISOString(),
      });
    }
  },
};

/** Gap threshold aligned with live Redis TTL (120s) + heartbeat (90s). */
const AVAILABILITY_GAP_MS = 120_000;

function todayIstYmd() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function xmlEscape(value: string) {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

type AvailabilitySegment = {
  start: string;
  end: string;
  status: 'AVAILABLE' | 'UNAVAILABLE';
  durationSeconds: number;
  reason: string | null;
  confidence: string | null;
};

function buildEmployeeAvailability(input: {
  employeeId: number;
  fullName: string;
  employeeCode: string | null;
  designation: string | null;
  department: string | null;
  punchIn: Date;
  punchOut: Date | null;
  stillOnDuty: boolean;
  points: Date[];
  events: Array<{
    eventType: string;
    timestamp: Date;
    endTime: Date | null;
    confidence: string;
    source: string;
  }>;
  windowEnd: Date;
}) {
  const segments = buildAvailabilitySegments(
    input.punchIn,
    input.windowEnd,
    input.points,
    input.events,
  );

  let availableSeconds = 0;
  let unavailableSeconds = 0;
  let gapCount = 0;
  for (const s of segments) {
    if (s.status === 'AVAILABLE') availableSeconds += s.durationSeconds;
    else {
      unavailableSeconds += s.durationSeconds;
      gapCount += 1;
    }
  }
  const dutySeconds = availableSeconds + unavailableSeconds;
  const availablePercent =
    dutySeconds > 0 ? Math.round((availableSeconds / dutySeconds) * 1000) / 10 : 0;

  return {
    employeeId: input.employeeId,
    fullName: input.fullName,
    employeeCode: input.employeeCode,
    designation: input.designation,
    department: input.department,
    punchIn: input.punchIn.toISOString(),
    punchOut: input.punchOut ? input.punchOut.toISOString() : null,
    stillOnDuty: input.stillOnDuty,
    availableSeconds,
    unavailableSeconds,
    dutySeconds,
    availablePercent,
    gapCount,
    pingCount: input.points.length,
    segments,
  };
}

function buildAvailabilitySegments(
  punchIn: Date,
  windowEnd: Date,
  points: Date[],
  events: Array<{
    eventType: string;
    timestamp: Date;
    endTime: Date | null;
    confidence: string;
    source: string;
  }>,
): AvailabilitySegment[] {
  const startMs = punchIn.getTime();
  const endMs = windowEnd.getTime();
  if (endMs <= startMs) return [];

  const sorted = [...points]
    .map((d) => d.getTime())
    .filter((t) => t >= startMs && t <= endMs)
    .sort((a, b) => a - b);

  const raw: Array<{ start: number; end: number; status: 'AVAILABLE' | 'UNAVAILABLE' }> = [];

  const pushSeg = (a: number, b: number, status: 'AVAILABLE' | 'UNAVAILABLE') => {
    const s = Math.max(a, startMs);
    const e = Math.min(b, endMs);
    if (e <= s) return;
    const last = raw[raw.length - 1];
    if (last && last.status === status && last.end === s) {
      last.end = e;
      return;
    }
    raw.push({ start: s, end: e, status });
  };

  if (sorted.length === 0) {
    pushSeg(startMs, endMs, 'UNAVAILABLE');
  } else {
    const first = sorted[0]!;
    if (first - startMs > AVAILABILITY_GAP_MS) {
      pushSeg(startMs, first, 'UNAVAILABLE');
    } else {
      pushSeg(startMs, first, 'AVAILABLE');
    }

    for (let i = 0; i < sorted.length - 1; i++) {
      const cur = sorted[i]!;
      const next = sorted[i + 1]!;
      const gap = next - cur;
      if (gap > AVAILABILITY_GAP_MS) {
        pushSeg(cur, next, 'UNAVAILABLE');
      } else {
        pushSeg(cur, next, 'AVAILABLE');
      }
    }

    const last = sorted[sorted.length - 1]!;
    if (endMs - last > AVAILABILITY_GAP_MS) {
      pushSeg(last, endMs, 'UNAVAILABLE');
    } else {
      pushSeg(last, endMs, 'AVAILABLE');
    }
  }

  return raw.map((seg) => {
    const durationSeconds = Math.max(0, Math.round((seg.end - seg.start) / 1000));
    let reason: string | null = null;
    let confidence: string | null = null;

    if (seg.status === 'UNAVAILABLE') {
      const mid = (seg.start + seg.end) / 2;
      const match = events.find((ev) => {
        const evStart = ev.timestamp.getTime();
        const evEnd = (ev.endTime ?? windowEnd).getTime();
        return evStart <= mid && evEnd >= mid;
      }) ?? events.find((ev) => {
        const evStart = ev.timestamp.getTime();
        return evStart >= seg.start && evStart <= seg.end;
      });

      if (match) {
        reason = String(match.eventType);
        confidence = String(match.confidence);
      } else {
        reason = 'NO_LOCATION_PING';
        confidence = 'MEDIUM';
      }
    }

    return {
      start: new Date(seg.start).toISOString(),
      end: new Date(seg.end).toISOString(),
      status: seg.status,
      durationSeconds,
      reason,
      confidence,
    };
  });
}

