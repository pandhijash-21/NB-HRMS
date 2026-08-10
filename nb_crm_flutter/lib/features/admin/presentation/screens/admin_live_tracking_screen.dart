import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/services/map_matching_service.dart';
import '../../../../core/utils/heading_utils.dart';
import '../../../../core/utils/route_pass_analyzer.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../widgets/route_pass_legend.dart';
import '../widgets/tracking_avatar_marker.dart';

final _liveLocationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('tracking/live');
  return res.data['data'] ?? [];
});

final _geofenceLocationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.getEnvelope<List<dynamic>>(
    'attendance/admin/locations',
    parse: (r) => r as List<dynamic>,
  );
  return res;
});

class AdminLiveTrackingScreen extends ConsumerStatefulWidget {
  const AdminLiveTrackingScreen({super.key});

  @override
  ConsumerState<AdminLiveTrackingScreen> createState() =>
      _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState
    extends ConsumerState<AdminLiveTrackingScreen> {
  Timer? _pollTimer;
  Timer? _uiTick;
  LatLng? _myLocation;
  String? _selectedGeofenceId;
  final MapController _mapController = MapController();

  final Map<int, List<LatLng>> _rawTrails = {};
  final Map<int, List<LatLng>> _snappedTrails = {};
  final Map<int, bool> _isSnapping = {};
  final Map<int, LatLng> _lastPositions = {};
  final Map<int, DateTime> _stopStartTimes = {};
  final Map<int, double> _smoothedHeadings = {};
  /// Which tripId the current in-memory trail belongs to.
  final Map<int, String?> _trailTripIds = {};
  final Set<String> _hydratingTripIds = {};
  /// Forces rebuild so stop timers tick every second.
  int _tick = 0;

  static const _stopMoveMeters = 20.0;
  static const _stopBubbleAfter = Duration(seconds: 5);

  Future<void> _hydrateTripTrail(int employeeId, String tripId) async {
    if (_hydratingTripIds.contains(tripId)) return;
    if (_trailTripIds[employeeId] == tripId &&
        (_snappedTrails[employeeId]?.length ?? 0) >= 2) {
      return;
    }

    _hydratingTripIds.add(tripId);
    try {
      final dio = ref.read(dioClientProvider);
      final data = await dio.getEnvelope<Map<String, dynamic>>(
        'tracking/trips/$tripId/route',
        parse: (r) => Map<String, dynamic>.from(r as Map),
      );
      final route = (data['route'] as List?) ?? const [];
      final points = <LatLng>[];
      for (final p in route) {
        if (p is! Map) continue;
        final lat = (p['latitude'] as num?)?.toDouble();
        final lng = (p['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(LatLng(lat, lng));
      }
      if (!mounted) return;
      setState(() {
        _rawTrails[employeeId] = List<LatLng>.from(points);
        _snappedTrails[employeeId] = List<LatLng>.from(points);
        _trailTripIds[employeeId] = tripId;
        if (points.isNotEmpty) {
          _lastPositions[employeeId] = points.last;
        }
      });
    } catch (e) {
      AppLogger.tracking.w('[LiveTracking] hydrate trip $tripId failed: $e');
    } finally {
      _hydratingTripIds.remove(tripId);
    }
  }

  void _clearTrail(int employeeId) {
    _rawTrails.remove(employeeId);
    _snappedTrails.remove(employeeId);
    _trailTripIds.remove(employeeId);
    _stopStartTimes.remove(employeeId);
  }

  Future<void> _processLiveLocations(List<dynamic> locations) async {
    for (final loc in locations) {
      if (loc is! Map) continue;
      final employeeId = _asEmployeeId(loc['employeeId']);
      if (employeeId == null) continue;

      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();
      final newPoint = LatLng(lat, lng);
      final gpsHeading = (loc['heading'] as num?)?.toDouble();
      final tripId = loc['tripId']?.toString();
      final hasTrip = tripId != null && tripId.isNotEmpty && tripId != 'null';

      // Path persistence: load saved trip points when re-entering live map.
      // Clear path only when they re-enter geofence (trip ends).
      if (!hasTrip) {
        if (_trailTripIds.containsKey(employeeId)) {
          if (mounted) setState(() => _clearTrail(employeeId));
        }
      } else {
        final knownTrip = _trailTripIds[employeeId];
        if (knownTrip != tripId ||
            (_snappedTrails[employeeId]?.isEmpty ?? true)) {
          await _hydrateTripTrail(employeeId, tripId);
        }
      }

      // Stopped-since from backend (survives leaving the screen).
      final stoppedSinceRaw = loc['stoppedSince']?.toString();
      if (hasTrip &&
          stoppedSinceRaw != null &&
          stoppedSinceRaw.isNotEmpty &&
          stoppedSinceRaw != 'null') {
        final parsed = DateTime.tryParse(stoppedSinceRaw)?.toLocal();
        if (parsed != null) {
          _stopStartTimes[employeeId] = parsed;
        }
      }

      final lastPos = _lastPositions[employeeId];
      if (lastPos == null) {
        _lastPositions[employeeId] = newPoint;
        if (hasTrip && !_stopStartTimes.containsKey(employeeId)) {
          _stopStartTimes[employeeId] = DateTime.now();
        }
      } else {
        final dist =
            const Distance().as(LengthUnit.Meter, lastPos, newPoint);
        if (dist > _stopMoveMeters) {
          _lastPositions[employeeId] = newPoint;
          // Moving again — clear stop (backend will also clear stoppedSince)
          if (stoppedSinceRaw == null ||
              stoppedSinceRaw.isEmpty ||
              stoppedSinceRaw == 'null') {
            _stopStartTimes.remove(employeeId);
          }
        } else if (hasTrip && !_stopStartTimes.containsKey(employeeId)) {
          // Local fallback if backend hasn't stamped stoppedSince yet
          _stopStartTimes[employeeId] = DateTime.now();
        }
      }

      final travelHeading = resolveTravelHeading(
        gpsHeading: gpsHeading,
        previous: lastPos,
        current: newPoint,
        fallback: _smoothedHeadings[employeeId],
      );
      final prevSmooth = _smoothedHeadings[employeeId] ?? travelHeading;
      // Softer blend → less heading jitter while still tracking turns.
      _smoothedHeadings[employeeId] =
          lerpHeading(prevSmooth, travelHeading, 0.28);

      if (!hasTrip) continue;

      final rawTrail = _rawTrails.putIfAbsent(employeeId, () => []);
      final snappedTrail = _snappedTrails.putIfAbsent(employeeId, () => []);
      _trailTripIds[employeeId] = tripId;

      final shouldAppend = rawTrail.isEmpty ||
          rawTrail.last.latitude != lat ||
          rawTrail.last.longitude != lng;
      if (!shouldAppend) continue;

      final prevPoint = rawTrail.isNotEmpty ? rawTrail.last : null;
      rawTrail.add(newPoint);

      if (prevPoint == null) {
        if (mounted) setState(() => snappedTrail.add(newPoint));
      } else if (!(_isSnapping[employeeId] ?? false)) {
        _isSnapping[employeeId] = true;
        final matched =
            await MapMatchingService.matchPoints([prevPoint, newPoint]);
        if (mounted) {
          setState(() {
            if (matched.isNotEmpty) {
              if (snappedTrail.isNotEmpty &&
                  matched.first == snappedTrail.last) {
                snappedTrail.addAll(matched.sublist(1));
              } else {
                snappedTrail.addAll(matched);
              }
            } else {
              snappedTrail.add(newPoint);
            }
          });
        }
        _isSnapping[employeeId] = false;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMyLocation();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.invalidate(_liveLocationsProvider);
    });
    // Keep "Stopped MM:SS" counting even when GPS point is unchanged.
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_stopStartTimes.isEmpty) return;
      setState(() => _tick++);
    });
  }

  Future<void> _fetchMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) {
        setState(() {
          _myLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (_) {}
  }

  Color _getColorForUser(String name) {
    final colors = [
      Colors.red.shade600,
      Colors.green.shade600,
      Colors.blue.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.pink.shade600,
      Colors.deepOrange.shade600,
      Colors.indigo.shade600,
      Colors.cyan.shade600,
    ];
    final index =
        name.codeUnits.fold<int>(0, (prev, curr) => prev + curr) % colors.length;
    return colors[index];
  }

  static int? _asEmployeeId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uiTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Touch tick so analyzer keeps the field (used to force stop-timer rebuilds).
    assert(_tick >= 0);

    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role.toUpperCase() ?? '';
    final canView =
        ['SUPERADMIN', 'ADMIN', 'HR', 'SYSTEMADMIN'].contains(role);

    if (!canView) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Permission Denied. Only Admins and HR can view Live Tracking.',
          ),
        ),
      );
    }

    final myEmployeeId = auth.user?.employeeId;
    final asyncLocations = ref.watch(_liveLocationsProvider);
    final asyncGeofences = ref.watch(_geofenceLocationsProvider);

    ref.listen<AsyncValue<List<dynamic>>>(_liveLocationsProvider,
        (previous, next) {
      if (next is AsyncData) {
        _processLiveLocations(next.value!);
      }
    });

    final geofences = asyncGeofences.value ?? [];
    final filteredGeofences = _selectedGeofenceId == null
        ? geofences
        : geofences.where((g) => g['id'] == _selectedGeofenceId).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Live Tracking'),
        actions: [
          if (geofences.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<String?>(
                value: _selectedGeofenceId,
                hint: const Text('Filter Zone'),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Zones')),
                  ...geofences.map(
                    (g) => DropdownMenuItem<String?>(
                      value: g['id']?.toString(),
                      child: Text(g['name'] ?? 'Unknown'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedGeofenceId = val);
                  if (val != null) {
                    final target = geofences.firstWhere(
                      (g) => g['id'].toString() == val,
                      orElse: () => null,
                    );
                    if (target != null) {
                      _mapController.move(
                        LatLng(target['latitude'], target['longitude']),
                        15.0,
                      );
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: asyncLocations.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (allLocations) {
          final byEmployee = <int, Map<String, dynamic>>{};
          for (final raw in allLocations) {
            if (raw is! Map) continue;
            final loc = Map<String, dynamic>.from(raw);
            final id = _asEmployeeId(loc['employeeId']);
            if (id == null) continue;
            loc['employeeId'] = id;
            byEmployee[id] = loc;
          }
          final locations = byEmployee.values.toList();

          final markers = locations.map((loc) {
            final lat = (loc['latitude'] as num).toDouble();
            final lng = (loc['longitude'] as num).toDouble();
            final name = loc['fullName'] ?? 'Unknown';
            final employeeId = loc['employeeId'] as int;
            final pinColor = _getColorForUser(name);
            final tripId = loc['tripId']?.toString();
            final hasTrip =
                tripId != null && tripId.isNotEmpty && tripId != 'null';

            Widget? stopBubble;
            final stopStartTime = _stopStartTimes[employeeId];
            if (hasTrip && stopStartTime != null) {
              final stopDuration = DateTime.now().difference(stopStartTime);
              if (stopDuration >= _stopBubbleAfter) {
                final minutes = stopDuration.inMinutes;
                final seconds = stopDuration.inSeconds % 60;
                final timeStr =
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                stopBubble = Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Stopped $timeStr',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }
            }

            final nameChip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.black87 : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: pinColor, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );

            late final Widget markerChild;
            final photoUrl = loc['photoUrl']?.toString();
            markerChild = GestureDetector(
              onTap: () => context.go('/admin/employees/$employeeId'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (stopBubble != null) stopBubble,
                  nameChip,
                  TrackingAvatarMarker(
                    photoUrl: photoUrl,
                    size: hasTrip ? 46 : 36,
                    borderColor: pinColor,
                  ),
                ],
              ),
            );

            final snappedPosition =
                (_snappedTrails[employeeId]?.isNotEmpty ?? false)
                    ? _snappedTrails[employeeId]!.last
                    : LatLng(lat, lng);

            // No key: AnimatedMarkerLayer/MarkerLayer world-copies reuse the
            // same key for each wrap → Duplicate GlobalKey / tree corruption.
            return AnimatedMarker(
              point: snappedPosition,
              width: 140,
              height: stopBubble != null ? 140 : 120,
              duration: const Duration(milliseconds: 2200),
              curve: Curves.linear,
              builder: (context, animation) => markerChild,
            );
          }).toList();

          // Only draw paths for employees currently on a trip (outside geofence).
          // Multi-pass: U-turn / reverse on same road → stacked colors + legend.
          final polylines = <Polyline>[];
          RoutePassAnalysis? legendAnalysis;
          for (final e in _snappedTrails.entries) {
            final tripId = _trailTripIds[e.key];
            if (tripId == null || e.value.length < 2) continue;
            final analysis = analyzeRoutePasses(e.value);
            polylines.addAll(analysis.polylines);
            if (legendAnalysis == null ||
                analysis.passCount > legendAnalysis.passCount) {
              legendAnalysis = analysis;
            }
          }

          final staticMarkers = <Marker>[];
          for (final loc in filteredGeofences) {
            staticMarkers.add(
              Marker(
                point: LatLng(loc['latitude'], loc['longitude']),
                width: 150,
                height: 40,
                child: Center(
                  child: Text(
                    loc['name'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (loc['isUnique'] == true)
                          ? Colors.blue.shade900
                          : Colors.blue,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 4),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          // Avoid duplicate pin when admin's own live location is already on the map.
          final alreadyShowingMe =
              myEmployeeId != null && byEmployee.containsKey(myEmployeeId);
          if (_myLocation != null && !alreadyShowingMe) {
            final myPinColor = Colors.blue.shade600;
            final myPhoto = auth.user?.photoUrl;
            staticMarkers.add(
              Marker(
                point: _myLocation!,
                width: 120,
                height: 70,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: myPinColor, width: 1.5),
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TrackingAvatarMarker(
                      photoUrl: myPhoto,
                      size: 32,
                      borderColor: myPinColor,
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _myLocation ?? const LatLng(23.2156, 72.6369),
                  initialZoom: _myLocation != null ? 12 : 11,
                  minZoom: 3,
                  maxZoom: 18,
                  // Keep a single world on screen so marker layers don't
                  // replicate Positioned widgets across wraps.
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-85.0, -180.0),
                      const LatLng(85.0, 180.0),
                    ),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nb.hrms',
                  ),
                  CircleLayer(
                    circles: filteredGeofences.map((loc) {
                      final isUnique = loc['isUnique'] == true;
                      final baseColor =
                          isUnique ? Colors.blue.shade900 : Colors.blue;
                      return CircleMarker(
                        point: LatLng(loc['latitude'], loc['longitude']),
                        color: baseColor.withValues(alpha: 0.2),
                        borderColor: baseColor.withValues(alpha: 0.8),
                        borderStrokeWidth: isUnique ? 3 : 2,
                        useRadiusInMeter: true,
                        radius: (loc['radiusKm'] * 1000).toDouble(),
                      );
                    }).toList(),
                  ),
                  PolylineLayer(polylines: polylines),
                  AnimatedMarkerLayer(markers: markers.cast<AnimatedMarker>()),
                  if (staticMarkers.isNotEmpty)
                    MarkerLayer(markers: staticMarkers),
                ],
              ),
              if (legendAnalysis != null && legendAnalysis.passes.isNotEmpty)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: RoutePassLegend(analysis: legendAnalysis),
                ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (e, st) =>
            const Center(child: Text('Error loading live tracking data')),
      ),
    );
  }
}
