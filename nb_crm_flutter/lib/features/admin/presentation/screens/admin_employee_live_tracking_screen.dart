import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/services/map_matching_service.dart';
import '../../../../core/utils/heading_utils.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../../tracking_hub/presentation/providers.dart';
import '../../../tracking_hub/presentation/widgets/location_availability_widgets.dart';
import '../widgets/tracking_avatar_marker.dart';
import 'admin_live_tracking_shared.dart';

class AdminEmployeeLiveTrackingScreen extends ConsumerStatefulWidget {
  const AdminEmployeeLiveTrackingScreen({
    super.key,
    required this.employeeId,
  });

  final int employeeId;

  @override
  ConsumerState<AdminEmployeeLiveTrackingScreen> createState() =>
      _AdminEmployeeLiveTrackingScreenState();
}

class _AdminEmployeeLiveTrackingScreenState
    extends ConsumerState<AdminEmployeeLiveTrackingScreen> {
  Timer? _pollTimer;
  Timer? _uiTick;
  final MapController _mapController = MapController();
  bool _didFit = false;
  int _tick = 0;

  final List<LatLng> _rawTrail = [];
  final List<LatLng> _snappedTrail = [];
  bool _isSnapping = false;
  String? _trailTripId;
  bool _hydrating = false;
  LatLng? _lastPosition;
  DateTime? _stopStartTime;
  double? _smoothedHeading;

  static const _stopMoveMeters = 20.0;
  static const _stopBubbleAfter = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.invalidate(liveBoardProvider);
    });
    _uiTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _stopStartTime == null) return;
      setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _uiTick?.cancel();
    super.dispose();
  }

  Future<void> _hydrateTripTrail(String tripId) async {
    if (_hydrating) return;
    if (_trailTripId == tripId && _snappedTrail.length >= 2) return;
    _hydrating = true;
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
        _rawTrail
          ..clear()
          ..addAll(points);
        _snappedTrail
          ..clear()
          ..addAll(points);
        _trailTripId = tripId;
        if (points.isNotEmpty) _lastPosition = points.last;
      });
      _fitTrail();
    } catch (e) {
      AppLogger.tracking.w('[EmployeeLive] hydrate trip $tripId failed: $e');
    } finally {
      _hydrating = false;
    }
  }

  void _clearTrail() {
    _rawTrail.clear();
    _snappedTrail.clear();
    _trailTripId = null;
    _stopStartTime = null;
  }

  void _fitTrail() {
    if (_didFit) return;
    final points = _snappedTrail.isNotEmpty
        ? _snappedTrail
        : (_lastPosition != null ? [_lastPosition!] : const <LatLng>[]);
    if (points.isEmpty) return;
    _didFit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _mapController.move(points.first, 16);
        return;
      }
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    });
  }

  Future<void> _processLocation(Map<String, dynamic> loc) async {
    final lat = (loc['latitude'] as num).toDouble();
    final lng = (loc['longitude'] as num).toDouble();
    final newPoint = LatLng(lat, lng);
    final gpsHeading = (loc['heading'] as num?)?.toDouble();
    final tripId = loc['tripId']?.toString();
    final onTrip = tripId != null && tripId.isNotEmpty && tripId != 'null';

    if (!onTrip) {
      if (_trailTripId != null && mounted) {
        setState(_clearTrail);
      }
    } else if (_trailTripId != tripId || _snappedTrail.isEmpty) {
      await _hydrateTripTrail(tripId);
    }

    final stoppedSinceRaw = loc['stoppedSince']?.toString();
    if (onTrip &&
        stoppedSinceRaw != null &&
        stoppedSinceRaw.isNotEmpty &&
        stoppedSinceRaw != 'null') {
      final parsed = DateTime.tryParse(stoppedSinceRaw)?.toLocal();
      if (parsed != null) _stopStartTime = parsed;
    }

    final lastPos = _lastPosition;
    if (lastPos == null) {
      _lastPosition = newPoint;
      if (onTrip && _stopStartTime == null) {
        _stopStartTime = DateTime.now();
      }
    } else {
      final dist = const Distance().as(LengthUnit.Meter, lastPos, newPoint);
      if (dist > _stopMoveMeters) {
        _lastPosition = newPoint;
        if (stoppedSinceRaw == null ||
            stoppedSinceRaw.isEmpty ||
            stoppedSinceRaw == 'null') {
          _stopStartTime = null;
        }
      } else if (onTrip && _stopStartTime == null) {
        _stopStartTime = DateTime.now();
      }
    }

    final travelHeading = resolveTravelHeading(
      gpsHeading: gpsHeading,
      previous: lastPos,
      current: newPoint,
      fallback: _smoothedHeading,
    );
    _smoothedHeading = lerpHeading(
      _smoothedHeading ?? travelHeading,
      travelHeading,
      0.28,
    );

    if (!onTrip) return;

    final shouldAppend = _rawTrail.isEmpty ||
        _rawTrail.last.latitude != lat ||
        _rawTrail.last.longitude != lng;
    if (!shouldAppend) return;

    final prevPoint = _rawTrail.isNotEmpty ? _rawTrail.last : null;
    _rawTrail.add(newPoint);
    _trailTripId = tripId;

    if (prevPoint == null) {
      if (mounted) setState(() => _snappedTrail.add(newPoint));
      return;
    }
    if (_isSnapping) return;
    _isSnapping = true;
    final matched = await MapMatchingService.matchPoints([prevPoint, newPoint]);
    if (!mounted) {
      _isSnapping = false;
      return;
    }
    setState(() {
      if (matched.isNotEmpty) {
        if (_snappedTrail.isNotEmpty && matched.first == _snappedTrail.last) {
          _snappedTrail.addAll(matched.sublist(1));
        } else {
          _snappedTrail.addAll(matched);
        }
      } else {
        _snappedTrail.add(newPoint);
      }
    });
    _isSnapping = false;
  }

  @override
  Widget build(BuildContext context) {
    assert(_tick >= 0);
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role.toUpperCase() ?? '';
    final canView =
        ['SUPERADMIN', 'ADMIN', 'HR', 'SYSTEMADMIN'].contains(role);
    if (!canView) {
      return const Scaffold(
        body: Center(child: Text('Permission Denied.')),
      );
    }

    final asyncBoard = ref.watch(liveBoardProvider);
    final asyncGeofences = ref.watch(geofenceLocationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<AsyncValue<Map<String, dynamic>>>(liveBoardProvider,
        (previous, next) {
      if (next is! AsyncData) return;
      final locations = (next.value!['locations'] as List?) ?? const [];
      for (final raw in locations) {
        if (raw is! Map) continue;
        final loc = Map<String, dynamic>.from(raw);
        if (asEmployeeId(loc['employeeId']) != widget.employeeId) continue;
        unawaited(_processLocation(loc));
        break;
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackLocation: '/admin/live-tracking'),
        title: const Text('Live route'),
      ),
      body: asyncBoard.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (_, __) =>
            const Center(child: Text('Error loading live tracking data')),
        data: (board) {
          final allLocations = (board['locations'] as List?) ?? const [];
          final dutyEmployees = (board['employees'] as List?) ?? const [];
          final dutyMap = dutyById(dutyEmployees);
          final duty = dutyMap[widget.employeeId];

          Map<String, dynamic>? loc;
          for (final raw in allLocations) {
            if (raw is! Map) continue;
            final row = Map<String, dynamic>.from(raw);
            if (asEmployeeId(row['employeeId']) == widget.employeeId) {
              loc = row;
              break;
            }
          }

          final name = loc?['fullName']?.toString() ??
              duty?['fullName']?.toString() ??
              'Employee #${widget.employeeId}';
          final pinColor = colorForUser(name);
          final onTrip = loc != null && hasOpenTrip(loc);
          final gpsOn = duty == null || isLocationCurrentlyOn(duty);
          final livePoint = loc == null
              ? null
              : (_snappedTrail.isNotEmpty
                  ? _snappedTrail.last
                  : LatLng(
                      (loc['latitude'] as num).toDouble(),
                      (loc['longitude'] as num).toDouble(),
                    ));

          if (livePoint != null) _fitTrail();

          final geofences = asyncGeofences.value ?? [];

          Widget? stopBubble;
          if (onTrip && _stopStartTime != null) {
            final stopDuration = DateTime.now().difference(_stopStartTime!);
            if (stopDuration >= _stopBubbleAfter) {
              stopBubble = StoppedBubble(duration: stopDuration);
            }
          }

          final markers = <AnimatedMarker>[];
          if (livePoint != null) {
            markers.add(
              AnimatedMarker(
                point: livePoint,
                width: 150,
                height: stopBubble != null ? 168 : 148,
                duration: const Duration(milliseconds: 2200),
                curve: Curves.linear,
                builder: (context, animation) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stopBubble != null) stopBubble,
                    GpsStatusChip(
                      on: gpsOn,
                      availableSeconds:
                          (duty?['availableSeconds'] as num?)?.toInt() ?? 0,
                      unavailableSeconds:
                          (duty?['unavailableSeconds'] as num?)?.toInt() ?? 0,
                    ),
                    NameChip(name: name, borderColor: pinColor, isDark: isDark),
                    TrackingAvatarMarker(
                      photoUrl: loc?['photoUrl']?.toString(),
                      size: onTrip ? 46 : 36,
                      borderColor: pinColor,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            livePoint ?? const LatLng(23.2156, 72.6369),
                        initialZoom: livePoint != null ? 15 : 11,
                        minZoom: 3,
                        maxZoom: 18,
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
                        CircleLayer(circles: geofenceCircles(geofences)),
                        if (_snappedTrail.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _snappedTrail,
                                color: const Color(0xFFC5A059),
                                strokeWidth: 5,
                              ),
                            ],
                          ),
                        AnimatedMarkerLayer(markers: markers),
                        MarkerLayer(markers: geofenceLabelMarkers(geofences)),
                      ],
                    ),
                    if (loc == null)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: Material(
                          color: const Color(0xFFB71C1C),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'This employee is not currently live. Showing last known availability below.',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Material(
                elevation: 16,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            onTrip
                                ? 'Live route for this employee'
                                : 'Live location only — no open trip yet',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (duty != null)
                            AvailabilityDetailsView(row: duty)
                          else
                            const Text('No punch-window availability yet.'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => context.go(
                                  '/admin/employees/${widget.employeeId}',
                                ),
                                child: const Text('Profile'),
                              ),
                              TextButton(
                                onPressed: () => context.push(
                                  '/admin/tracking-hub/employee/${widget.employeeId}',
                                ),
                                child: const Text('Full timeline'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
