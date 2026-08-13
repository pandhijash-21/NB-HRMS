import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../../../tracking_hub/presentation/providers.dart';
import '../../../tracking_hub/presentation/widgets/location_availability_widgets.dart';
import '../widgets/tracking_avatar_marker.dart';
import 'admin_live_tracking_shared.dart';

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

  final Map<int, LatLng> _lastPositions = {};
  final Map<int, DateTime> _stopStartTimes = {};
  /// Forces rebuild so stop timers tick every second.
  int _tick = 0;
  final Set<String> _seenAlertIds = {};
  final Set<int> _activeAlertEmployeeIds = {};
  final Map<int, String> _alertEmployeeNames = {};
  bool _alertsPrimed = false;

  static const _stopMoveMeters = 20.0;
  static const _stopBubbleAfter = Duration(seconds: 5);

  void _processLiveLocations(List<dynamic> locations) {
    for (final loc in locations) {
      if (loc is! Map) continue;
      final employeeId = asEmployeeId(loc['employeeId']);
      if (employeeId == null) continue;

      final lat = (loc['latitude'] as num).toDouble();
      final lng = (loc['longitude'] as num).toDouble();
      final newPoint = LatLng(lat, lng);
      final onTrip = hasOpenTrip(Map<String, dynamic>.from(loc));

      final stoppedSinceRaw = loc['stoppedSince']?.toString();
      if (onTrip &&
          stoppedSinceRaw != null &&
          stoppedSinceRaw.isNotEmpty &&
          stoppedSinceRaw != 'null') {
        final parsed = DateTime.tryParse(stoppedSinceRaw)?.toLocal();
        if (parsed != null) _stopStartTimes[employeeId] = parsed;
      } else if (!onTrip) {
        _stopStartTimes.remove(employeeId);
      }

      final lastPos = _lastPositions[employeeId];
      if (lastPos == null) {
        _lastPositions[employeeId] = newPoint;
        if (onTrip && !_stopStartTimes.containsKey(employeeId)) {
          _stopStartTimes[employeeId] = DateTime.now();
        }
        continue;
      }

      final dist = const Distance().as(LengthUnit.Meter, lastPos, newPoint);
      if (dist > _stopMoveMeters) {
        _lastPositions[employeeId] = newPoint;
        if (stoppedSinceRaw == null ||
            stoppedSinceRaw.isEmpty ||
            stoppedSinceRaw == 'null') {
          _stopStartTimes.remove(employeeId);
        }
      } else if (onTrip && !_stopStartTimes.containsKey(employeeId)) {
        _stopStartTimes[employeeId] = DateTime.now();
      }
    }
  }

  void _openEmployeeLive(int employeeId) {
    context.push('/admin/live-tracking/employee/$employeeId');
  }

  @override
  void initState() {
    super.initState();
    _fetchMyLocation();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      ref.invalidate(liveBoardProvider);
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

  void _notifyNewAlerts(List<dynamic> alerts) {
    final active = activeLocationAlerts(alerts);
    final currentIds = <int>{};
    for (final a in active) {
      final id = (a['employeeId'] as num?)?.toInt();
      if (id == null) continue;
      currentIds.add(id);
      final name = a['fullName']?.toString();
      if (name != null && name.isNotEmpty) _alertEmployeeNames[id] = name;
    }

    if (!_alertsPrimed) {
      for (final a in active) {
        final id = a['id']?.toString();
        if (id != null && id.isNotEmpty) _seenAlertIds.add(id);
      }
      _activeAlertEmployeeIds
        ..clear()
        ..addAll(currentIds);
      _alertsPrimed = true;
      return;
    }

    for (final empId in _activeAlertEmployeeIds.difference(currentIds)) {
      if (!mounted) continue;
      final name = _alertEmployeeNames[empId] ?? 'Employee #$empId';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1B5E20),
          duration: const Duration(seconds: 4),
          content: Text('$name location is available again'),
        ),
      );
    }

    for (final a in active) {
      final id = a['id']?.toString();
      if (id == null || id.isEmpty || _seenAlertIds.contains(id)) continue;
      _seenAlertIds.add(id);
      if (!mounted) continue;
      final name = a['fullName']?.toString() ?? 'Employee';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB71C1C),
          duration: const Duration(seconds: 6),
          content: Text(
            '$name GPS off since ${formatAvailabilityClock(a['unavailableSince']?.toString())}'
            ' (${reasonLabel(a['reason']?.toString())})',
          ),
        ),
      );
    }

    _activeAlertEmployeeIds
      ..clear()
      ..addAll(currentIds);
  }

  Widget _buildDutyAvailabilityPanel(List<dynamic> employees) {
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 188,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'On-duty location availability',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: employees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = Map<String, dynamic>.from(employees[index] as Map);
                  final id = asEmployeeId(row['employeeId']) ?? 0;
                  final name = row['fullName']?.toString() ?? 'Employee';
                  final on = isLocationCurrentlyOn(row);
                  return InkWell(
                    onTap: () => _openEmployeeLive(id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AvailabilityStatusPill(
                              available: on,
                              live: row['isLive'] == true,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              'On ${formatAvailabilityDuration((row['availableSeconds'] as num?)?.toInt() ?? 0)}'
                              ' · Off ${formatAvailabilityDuration((row['unavailableSeconds'] as num?)?.toInt() ?? 0)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AvailabilitySlotBar(
                          segments: (row['segments'] as List?) ?? const [],
                          height: 8,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
    final asyncBoard = ref.watch(liveBoardProvider);
    final asyncGeofences = ref.watch(geofenceLocationsProvider);

    ref.listen<AsyncValue<Map<String, dynamic>>>(liveBoardProvider,
        (previous, next) {
      if (next is AsyncData) {
        final locations = (next.value!['locations'] as List?) ?? const [];
        _processLiveLocations(locations);
        _notifyNewAlerts((next.value!['alerts'] as List?) ?? const []);
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
      body: asyncBoard.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (board) {
          final allLocations = (board['locations'] as List?) ?? const [];
          final dutyEmployees = (board['employees'] as List?) ?? const [];
          final boardAlerts = (board['alerts'] as List?) ?? const [];
          final dutyMap = dutyById(dutyEmployees);
          final byEmployee = <int, Map<String, dynamic>>{};
          for (final raw in allLocations) {
            if (raw is! Map) continue;
            final loc = Map<String, dynamic>.from(raw);
            final id = asEmployeeId(loc['employeeId']);
            if (id == null) continue;
            loc['employeeId'] = id;
            byEmployee[id] = loc;
          }
          final locations = byEmployee.values.toList();

          final markers = locations.map((loc) {
            final lat = (loc['latitude'] as num).toDouble();
            final lng = (loc['longitude'] as num).toDouble();
            final name = loc['fullName']?.toString() ?? 'Unknown';
            final employeeId = loc['employeeId'] as int;
            final pinColor = colorForUser(name);
            final onTrip = hasOpenTrip(loc);
            final duty = dutyMap[employeeId];
            final gpsOn = duty == null || isLocationCurrentlyOn(duty);

            Widget? stopBubble;
            final stopStartTime = _stopStartTimes[employeeId];
            if (onTrip && stopStartTime != null) {
              final stopDuration = DateTime.now().difference(stopStartTime);
              if (stopDuration >= _stopBubbleAfter) {
                stopBubble = StoppedBubble(duration: stopDuration);
              }
            }

            return AnimatedMarker(
              point: LatLng(lat, lng),
              width: 140,
              height: stopBubble != null ? 168 : 148,
              duration: const Duration(milliseconds: 2200),
              curve: Curves.linear,
              builder: (context, animation) => GestureDetector(
                onTap: () => _openEmployeeLive(employeeId),
                child: Column(
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
                      photoUrl: loc['photoUrl']?.toString(),
                      size: onTrip ? 46 : 36,
                      borderColor: pinColor,
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          final staticMarkers = geofenceLabelMarkers(filteredGeofences);
          final alreadyShowingMe =
              myEmployeeId != null && byEmployee.containsKey(myEmployeeId);
          if (_myLocation != null && !alreadyShowingMe) {
            staticMarkers.add(
              Marker(
                point: _myLocation!,
                width: 120,
                height: 70,
                child: youAreHereMarker(
                  isDark: isDark,
                  photoUrl: auth.user?.photoUrl,
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
                  CircleLayer(circles: geofenceCircles(filteredGeofences)),
                  AnimatedMarkerLayer(markers: markers.cast<AnimatedMarker>()),
                  if (staticMarkers.isNotEmpty)
                    MarkerLayer(markers: staticMarkers),
                ],
              ),
              if (activeLocationAlerts(boardAlerts).isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: ActiveLocationAlertsBanner(
                    alerts: boardAlerts,
                    dense: true,
                    onTapEmployee: _openEmployeeLive,
                  ),
                ),
              if (dutyEmployees.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildDutyAvailabilityPanel(dutyEmployees),
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
