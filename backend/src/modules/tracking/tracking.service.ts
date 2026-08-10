import { prisma } from '../../config/prisma';
import { getRedisClient, connectRedis } from '../../config/redis';
import { TrackingEventType } from '@prisma/client';
import { deriveDayInOut } from '../attendance/dayPunch.rules';

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
  }
};

