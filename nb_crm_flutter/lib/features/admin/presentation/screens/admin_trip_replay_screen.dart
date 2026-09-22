import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../auth/presentation/auth_providers.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/utils/heading_utils.dart';
import '../../../tracking_hub/presentation/trip_recording_download.dart';

/// Hard cap for web map memory — dense polylines + tile thrash cause OOM.
const int _kMaxReplayPoints = 120;
const int _kMaxStopMarkers = 12;

List<LatLng> _downsampleLatLng(List<LatLng> points, int maxPoints) {
  if (points.length <= maxPoints) return points;
  if (maxPoints < 2) return points.take(maxPoints).toList();
  final last = points.length - 1;
  return List<LatLng>.generate(maxPoints, (i) {
    final idx = ((i * last) / (maxPoints - 1)).round();
    return points[idx];
  });
}

final adminTripRouteProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tripId) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('tracking/trips/$tripId/route');
  final data = Map<String, dynamic>.from(res.data['data'] as Map);
  final rawRoute = data['route'] as List? ?? const [];

  if (rawRoute.isEmpty) return data;

  try {
    final points = <LatLng>[];
    for (final raw in rawRoute) {
      final p = Map<String, dynamic>.from(raw as Map);
      points.add(
        LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        ),
      );
    }
    final displayPoints = _downsampleLatLng(points, _kMaxReplayPoints);
    data['displayPoints'] = displayPoints
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();

    // Stops from raw timestamps (before display downsample), then keep longest only.
    final computedStops = <Map<String, dynamic>>[];
    LatLng? lastPos;
    Map<String, dynamic>? currentStopStart;

    for (final raw in rawRoute) {
      final p = Map<String, dynamic>.from(raw as Map);
      final pos = LatLng(
        (p['latitude'] as num).toDouble(),
        (p['longitude'] as num).toDouble(),
      );
      final time = DateTime.tryParse(p['timestamp']?.toString() ?? '');
      if (time == null) continue;

      if (lastPos == null) {
        lastPos = pos;
        currentStopStart = p;
        continue;
      }

      final dist = const Distance().as(LengthUnit.Meter, lastPos, pos);
      if (dist > 15) {
        final startTime =
            DateTime.tryParse(currentStopStart!['timestamp']?.toString() ?? '');
        if (startTime != null) {
          final duration = time.difference(startTime).inSeconds;
          if (duration >= 30) {
            computedStops.add({
              'latitude': currentStopStart['latitude'],
              'longitude': currentStopStart['longitude'],
              'duration': duration,
            });
          }
        }
        lastPos = pos;
        currentStopStart = p;
      }
    }

    if (lastPos != null && currentStopStart != null && rawRoute.isNotEmpty) {
      final p = Map<String, dynamic>.from(rawRoute.last as Map);
      final time = DateTime.tryParse(p['timestamp']?.toString() ?? '');
      final startTime =
          DateTime.tryParse(currentStopStart['timestamp']?.toString() ?? '');
      if (time != null && startTime != null) {
        final duration = time.difference(startTime).inSeconds;
        if (duration >= 30) {
          computedStops.add({
            'latitude': currentStopStart['latitude'],
            'longitude': currentStopStart['longitude'],
            'duration': duration,
          });
        }
      }
    }

    final clusteredStops = <Map<String, dynamic>>[];
    for (final stop in computedStops) {
      var merged = false;
      final p1 = LatLng(
        (stop['latitude'] as num).toDouble(),
        (stop['longitude'] as num).toDouble(),
      );
      for (final cluster in clusteredStops) {
        final p2 = LatLng(
          (cluster['latitude'] as num).toDouble(),
          (cluster['longitude'] as num).toDouble(),
        );
        if (const Distance().as(LengthUnit.Meter, p1, p2) <= 40) {
          cluster['duration'] =
              (cluster['duration'] as num).toInt() + (stop['duration'] as num).toInt();
          merged = true;
          break;
        }
      }
      if (!merged) clusteredStops.add(Map<String, dynamic>.from(stop));
    }

    clusteredStops.sort(
      (a, b) => (b['duration'] as num).compareTo(a['duration'] as num),
    );
    data['stops'] = clusteredStops.take(_kMaxStopMarkers).toList();
  } catch (e) {
    AppLogger.tracking.e('Error preparing trip replay: $e');
  }

  return data;
});

class AdminTripReplayScreen extends ConsumerStatefulWidget {
  final String tripId;
  const AdminTripReplayScreen({super.key, required this.tripId});

  @override
  ConsumerState<AdminTripReplayScreen> createState() =>
      _AdminTripReplayScreenState();
}

class _AdminTripReplayScreenState extends ConsumerState<AdminTripReplayScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _animController;

  List<LatLng> _routePoints = const [];
  List<double> _headings = const [];
  List<Map<String, dynamic>> _stops = const [];
  String _employeeName = '';
  bool _routeReady = false;

  /// Position updates must NOT call setState — that rebuilds TileLayer and OOMs web.
  final ValueNotifier<LatLng?> _position = ValueNotifier<LatLng?>(null);
  final ValueNotifier<double> _heading = ValueNotifier<double>(0);
  final ValueNotifier<bool> _isPlaying = ValueNotifier<bool>(false);

  double _playbackSpeed = 1.0;
  Duration _baseDuration = const Duration(seconds: 10);
  int _lastEmitMs = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    _animController.addListener(_onAnimTick);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isPlaying.value = false;
      }
    });
  }

  void _hydrateRoute(Map<String, dynamic> data) {
    if (_routeReady) return;

    final display = data['displayPoints'] as List? ?? data['route'] as List? ?? const [];
    if (display.isEmpty) return;

    final points = <LatLng>[];
    for (final raw in display) {
      final p = Map<String, dynamic>.from(raw as Map);
      points.add(
        LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        ),
      );
    }
    final capped = _downsampleLatLng(points, _kMaxReplayPoints);
    if (capped.isEmpty) return;

    final headings = <double>[];
    for (var i = 0; i < capped.length; i++) {
      if (i < capped.length - 1) {
        headings.add(bearingBetween(capped[i], capped[i + 1]));
      } else if (i > 0) {
        headings.add(bearingBetween(capped[i - 1], capped[i]));
      } else {
        headings.add(0);
      }
    }
    for (var i = 1; i < headings.length; i++) {
      headings[i] = lerpHeading(headings[i - 1], headings[i], 0.55);
    }

    final trip = data['trip'];
    _routePoints = capped;
    _headings = headings;
    _stops = List<Map<String, dynamic>>.from(
      (data['stops'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ??
          const [],
    );
    _employeeName =
        trip?['employee']?['generalInfo']?['fullName']?.toString() ?? 'Unknown';
    _position.value = capped.first;
    _heading.value = headings.first;
    _baseDuration = Duration(
      seconds: (capped.length / 5).clamp(5.0, 45.0).toInt(),
    );
    _animController.duration = Duration(
      milliseconds: (_baseDuration.inMilliseconds / _playbackSpeed).round(),
    );
    _routeReady = true;
  }

  void _onAnimTick() {
    if (_routePoints.isEmpty) return;

    final progress = _animController.value;
    // ~12 fps pin updates — enough for smooth replay without web OOM.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (progress < 1.0 &&
        _lastEmitMs != 0 &&
        nowMs - _lastEmitMs < 80) {
      return;
    }
    _lastEmitMs = nowMs;

    final totalSegments = _routePoints.length - 1;
    if (totalSegments <= 0) {
      _position.value = _routePoints.first;
      _heading.value = _headings.isNotEmpty ? _headings.first : 0;
      return;
    }

    if (progress >= 1.0) {
      _position.value = _routePoints.last;
      _heading.value = _headings.isNotEmpty ? _headings.last : 0;
      return;
    }

    final exactIndex = progress * totalSegments;
    final baseIndex = exactIndex.floor().clamp(0, totalSegments - 1);
    final remainder = (exactIndex - baseIndex).clamp(0.0, 1.0);
    final p1 = _routePoints[baseIndex];
    final p2 = _routePoints[baseIndex + 1];
    final h1 = baseIndex < _headings.length
        ? _headings[baseIndex]
        : bearingBetween(p1, p2);
    final h2 = (baseIndex + 1) < _headings.length ? _headings[baseIndex + 1] : h1;

    _position.value = LatLng(
      p1.latitude + (p2.latitude - p1.latitude) * remainder,
      p1.longitude + (p2.longitude - p1.longitude) * remainder,
    );
    _heading.value = lerpHeading(h1, h2, remainder);
  }

  void _togglePlayPause() {
    if (_isPlaying.value) {
      _animController.stop();
      _isPlaying.value = false;
    } else {
      if (_animController.isCompleted) {
        _animController.reset();
      }
      _animController.forward();
      _isPlaying.value = true;
    }
  }

  void _changeSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      final wasPlaying = _isPlaying.value;
      final currentProgress = _animController.value;
      _animController.duration = Duration(
        milliseconds: (_baseDuration.inMilliseconds / _playbackSpeed).round(),
      );
      _animController.value = currentProgress;
      if (wasPlaying) {
        _animController.forward(from: currentProgress);
      }
    });
  }

  @override
  void dispose() {
    _animController.removeListener(_onAnimTick);
    _animController.dispose();
    _position.dispose();
    _heading.dispose();
    _isPlaying.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(adminTripRouteProvider(widget.tripId));

    ref.listen(adminTripRouteProvider(widget.tripId), (prev, next) {
      next.whenData((data) {
        if (_routeReady || !mounted) return;
        _hydrateRoute(data);
        if (_routeReady) setState(() {});
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Replay'),
        leading: const AppBackButton(fallbackLocation: '/admin/trips'),
        actions: [
          IconButton(
            tooltip: 'Download trip video',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => showTripDownloadMenu(
              context: context,
              dioClient: ref.read(dioClientProvider),
              tripId: widget.tripId,
            ),
          ),
        ],
      ),
      body: routeAsync.when(
        data: (data) {
          if (!_routeReady) {
            // First frame after fetch — hydrate via listen; show spinner once.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _routeReady) return;
              _hydrateRoute(data);
              if (_routeReady) setState(() {});
            });
            return const Center(child: CircularProgressIndicator());
          }
          if (_routePoints.isEmpty) {
            return const Center(
              child: Text('No location data recorded for this trip.'),
            );
          }

          final bounds = LatLngBounds.fromPoints(_routePoints);
          final theme = Theme.of(context);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: bounds,
                    padding: const EdgeInsets.all(48),
                  ),
                  minZoom: 3,
                  maxZoom: 17,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nb.hrms',
                    maxNativeZoom: 17,
                    keepBuffer: 1,
                    panBuffer: 0,
                    retinaMode: false,
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: const Color(0xFFC5A059),
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  if (_stops.isNotEmpty)
                    MarkerLayer(
                      markers: [
                        for (final stop in _stops)
                          Marker(
                            point: LatLng(
                              (stop['latitude'] as num).toDouble(),
                              (stop['longitude'] as num).toDouble(),
                            ),
                            width: 72,
                            height: 36,
                            alignment: Alignment.topCenter,
                            child: _StopChip(
                              durationSecs: (stop['duration'] as num).toInt(),
                            ),
                          ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _routePoints.first,
                        width: 36,
                        height: 36,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 36,
                        ),
                      ),
                      if (_routePoints.length > 1)
                        Marker(
                          point: _routePoints.last,
                          width: 36,
                          height: 36,
                          alignment: Alignment.bottomRight,
                          child: const Icon(
                            Icons.flag,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                    ],
                  ),
                  ValueListenableBuilder<LatLng?>(
                    valueListenable: _position,
                    builder: (context, pos, _) {
                      if (pos == null) return const SizedBox.shrink();
                      return MarkerLayer(
                        markers: [
                          Marker(
                            point: pos,
                            width: 88,
                            height: 72,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue),
                                  ),
                                  child: Text(
                                    _employeeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.blue.shade700,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              Positioned(
                bottom: 24,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(28),
                  color: theme.cardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _isPlaying,
                          builder: (context, playing, _) {
                            return IconButton(
                              icon: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                              ),
                              onPressed: _togglePlayPause,
                              color: Colors.blue,
                              iconSize: 28,
                            );
                          },
                        ),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _animController,
                            builder: (context, _) {
                              return Slider(
                                value: _animController.value.clamp(0.0, 1.0),
                                onChanged: (val) {
                                  _lastEmitMs = 0;
                                  _animController.value = val;
                                  if (!_isPlaying.value) _onAnimTick();
                                },
                              );
                            },
                          ),
                        ),
                        PopupMenuButton<double>(
                          initialValue: _playbackSpeed,
                          onSelected: _changeSpeed,
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 0.5, child: Text('0.5x')),
                            PopupMenuItem(value: 1.0, child: Text('1.0x')),
                            PopupMenuItem(value: 1.5, child: Text('1.5x')),
                            PopupMenuItem(value: 2.0, child: Text('2.0x')),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (context, _) {
                            return SizedBox(
                              width: 40,
                              child: Text(
                                '${(_animController.value * 100).toInt()}%',
                                textAlign: TextAlign.end,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading trip route: $e')),
      ),
    );
  }
}

class _StopChip extends StatelessWidget {
  const _StopChip({required this.durationSecs});

  final int durationSecs;

  @override
  Widget build(BuildContext context) {
    final minutes = durationSecs ~/ 60;
    final seconds = durationSecs % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        timeStr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
