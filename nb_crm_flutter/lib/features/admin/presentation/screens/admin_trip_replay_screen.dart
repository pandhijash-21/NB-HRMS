import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../widgets/route_pass_legend.dart';
import '../widgets/tracking_avatar_marker.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/router/app_back_button.dart';
import '../../../../core/services/map_matching_service.dart';
import '../../../../core/utils/heading_utils.dart';
import '../../../../core/utils/route_pass_analyzer.dart';

final adminTripRouteProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, tripId) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('tracking/trips/$tripId/route');
  final data = res.data['data'] as Map<String, dynamic>;
  final rawRoute = data['route'] as List;
  
  if (rawRoute.isNotEmpty) {
    try {
      final List<Map<String, dynamic>> computedStops = [];
      LatLng? lastPos;
      Map<String, dynamic>? currentStopStart;
      
      for (int i = 0; i < rawRoute.length; i++) {
        final p = rawRoute[i];
        final pos = LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble());
        final time = DateTime.tryParse(p['timestamp'] ?? '');
        
        if (time == null) continue;

        if (lastPos == null) {
          lastPos = pos;
          currentStopStart = p;
          continue;
        }
        
        final dist = const Distance().as(LengthUnit.Meter, lastPos, pos);
        if (dist > 5) {
          final startTime = DateTime.tryParse(currentStopStart!['timestamp'] ?? '');
          if (startTime != null) {
             final duration = time.difference(startTime).inSeconds;
             if (duration >= 10) {
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
      
      // Check if the trip ended on a stop
      if (lastPos != null && currentStopStart != null) {
         final p = rawRoute.last;
         final time = DateTime.tryParse(p['timestamp'] ?? '');
         final startTime = DateTime.tryParse(currentStopStart['timestamp'] ?? '');
         if (time != null && startTime != null) {
            final duration = time.difference(startTime).inSeconds;
            if (duration >= 10) {
               computedStops.add({
                 'latitude': currentStopStart['latitude'],
                 'longitude': currentStopStart['longitude'],
                 'duration': duration,
               });
            }
         }
      }
      // Combine stops that are within 30 meters of each other
      final List<Map<String, dynamic>> clusteredStops = [];
      for (final stop in computedStops) {
        bool merged = false;
        final p1 = LatLng((stop['latitude'] as num).toDouble(), (stop['longitude'] as num).toDouble());
        
        for (final cluster in clusteredStops) {
           final p2 = LatLng((cluster['latitude'] as num).toDouble(), (cluster['longitude'] as num).toDouble());
           if (const Distance().as(LengthUnit.Meter, p1, p2) <= 30) {
              cluster['duration'] = (cluster['duration'] as num).toInt() + (stop['duration'] as num).toInt();
              merged = true;
              break;
           }
        }
        
        if (!merged) {
           clusteredStops.add(Map<String, dynamic>.from(stop));
        }
      }
      
      data['stops'] = clusteredStops;

      final points = rawRoute.map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())).toList();
      final snappedPoints = await MapMatchingService.matchPointsInBatches(points, batchSize: 50);
      
      // Replace route with snapped points and recalculate headings
      final List<Map<String, dynamic>> snappedRoute = [];
      for (int i = 0; i < snappedPoints.length; i++) {
        double heading = 0.0;
        if (i < snappedPoints.length - 1) {
          heading = const Distance().bearing(snappedPoints[i], snappedPoints[i+1]);
        } else if (i > 0) {
          heading = const Distance().bearing(snappedPoints[i-1], snappedPoints[i]);
        }
        
        snappedRoute.add({
          'latitude': snappedPoints[i].latitude,
          'longitude': snappedPoints[i].longitude,
          'heading': heading,
        });
      }
      data['route'] = snappedRoute;
    } catch (e) {
      AppLogger.tracking.e('Error snapping historical route: $e');
    }
  }
  return data;
});

class AdminTripReplayScreen extends ConsumerStatefulWidget {
  final String tripId;
  const AdminTripReplayScreen({super.key, required this.tripId});

  @override
  ConsumerState<AdminTripReplayScreen> createState() => _AdminTripReplayScreenState();
}

class _AdminTripReplayScreenState extends ConsumerState<AdminTripReplayScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _animController;

  List<LatLng> _routePoints = [];
  List<double> _headings = [];
  
  LatLng? _currentPosition;
  double _currentHeading = 0.0;
  bool _isPlaying = false;
  
  double _playbackSpeed = 1.0;
  Duration _baseDuration = const Duration(seconds: 10);
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Default duration, will adjust based on points
    );
    _animController.addListener(_updatePosition);
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isPlaying = false);
      }
    });
  }

  void _updatePosition() {
    if (_routePoints.isEmpty) return;

    final progress = _animController.value;
    if (progress >= 1.0) {
      setState(() {
        _currentPosition = _routePoints.last;
        _currentHeading = _headings.isNotEmpty ? _headings.last : 0.0;
      });
      return;
    }

    final totalSegments = _routePoints.length - 1;
    if (totalSegments <= 0) {
      setState(() {
        _currentPosition = _routePoints.first;
        _currentHeading = _headings.isNotEmpty ? _headings.first : 0.0;
      });
      return;
    }

    final exactIndex = progress * totalSegments;
    final baseIndex = exactIndex.floor().clamp(0, totalSegments - 1);
    final remainder = (exactIndex - baseIndex).clamp(0.0, 1.0);

    final p1 = _routePoints[baseIndex];
    final p2 = _routePoints[baseIndex + 1];

    final lat = p1.latitude + (p2.latitude - p1.latitude) * remainder;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * remainder;

    final h1 = baseIndex < _headings.length
        ? _headings[baseIndex]
        : bearingBetween(p1, p2);
    final h2 = (baseIndex + 1) < _headings.length
        ? _headings[baseIndex + 1]
        : h1;

    setState(() {
      _currentPosition = LatLng(lat, lng);
      _currentHeading = lerpHeading(h1, h2, remainder);
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_animController.isCompleted) {
          _animController.reset();
        }
        _animController.forward();
      } else {
        _animController.stop();
      }
    });
  }

  void _changeSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
      final wasPlaying = _isPlaying;
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
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeAsync = ref.watch(adminTripRouteProvider(widget.tripId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Replay'),
        leading: const AppBackButton(fallbackLocation: '/admin/trips'),
      ),
      body: routeAsync.when(
        data: (data) {
          final trip = data['trip'];
          final rawRoute = data['route'] as List;
          
          if (rawRoute.isEmpty) {
            return const Center(child: Text('No location data recorded for this trip.'));
          }

          if (_routePoints.isEmpty) {
            _routePoints = rawRoute
                .map(
                  (p) => LatLng(
                    (p['latitude'] as num).toDouble(),
                    (p['longitude'] as num).toDouble(),
                  ),
                )
                .toList();
            _headings = <double>[];
            for (var i = 0; i < _routePoints.length; i++) {
              if (i < _routePoints.length - 1) {
                _headings.add(
                  bearingBetween(_routePoints[i], _routePoints[i + 1]),
                );
              } else if (i > 0) {
                _headings.add(
                  bearingBetween(_routePoints[i - 1], _routePoints[i]),
                );
              } else {
                _headings.add(
                  (rawRoute[i]['heading'] as num?)?.toDouble() ?? 0.0,
                );
              }
            }
            for (var i = 1; i < _headings.length; i++) {
              _headings[i] = lerpHeading(_headings[i - 1], _headings[i], 0.55);
            }
            _currentPosition = _routePoints.first;
            _currentHeading = _headings.first;

            _baseDuration = Duration(
              seconds: (_routePoints.length / 5).clamp(5.0, 60.0).toInt(),
            );
            _animController.duration = Duration(
              milliseconds:
                  (_baseDuration.inMilliseconds / _playbackSpeed).round(),
            );
          }

          final employeeName =
              trip['employee']?['generalInfo']?['fullName'] ?? 'Unknown';
          final photoUrl = trip['employee']?['photoUrl']?.toString();

          final bounds = LatLngBounds.fromPoints(_routePoints);
          final passAnalysis = analyzeRoutePasses(_routePoints);

          final computedStops = data['stops'] as List<dynamic>? ?? [];

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.nb.hrms',
                  ),
                  PolylineLayer(polylines: passAnalysis.polylines),
                  if (computedStops.isNotEmpty)
                    MarkerLayer(
                      markers: computedStops.map((stop) {
                        final lat = (stop['latitude'] as num).toDouble();
                        final lng = (stop['longitude'] as num).toDouble();
                        final durationSecs = (stop['duration'] as num).toInt();
                        final minutes = durationSecs ~/ 60;
                        final seconds = durationSecs % 60;
                        final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

                        return Marker(
                          point: LatLng(lat, lng),
                          width: 100,
                          height: 60,
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Stopped',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  timeStr,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (_currentPosition != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPosition!,
                          width: 100,
                          height: 100,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue),
                                ),
                                child: Text(employeeName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              TrackingAvatarMarker(
                                photoUrl: photoUrl,
                                size: 48,
                                borderColor: Colors.blue.shade700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  // Start and End markers
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _routePoints.first,
                        width: 40, height: 40,
                        child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                        alignment: Alignment.topCenter,
                      ),
                      if (_routePoints.length > 1)
                        Marker(
                          point: _routePoints.last,
                          width: 40, height: 40,
                          child: const Icon(Icons.flag, color: Colors.red, size: 40),
                          alignment: Alignment.bottomRight,
                        ),
                    ],
                  ),
                ],
              ),

              Positioned(
                top: 12,
                right: 12,
                child: RoutePassLegend(analysis: passAnalysis),
              ),
              
              // Floating control panel
              Positioned(
                bottom: 30,
                left: 30,
                right: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _togglePlayPause,
                        color: Colors.blue,
                        iconSize: 30,
                      ),
                      Expanded(
                        child: Slider(
                          value: _animController.value,
                          onChanged: (val) {
                            setState(() {
                              _animController.value = val;
                              if (!_isPlaying) _updatePosition();
                            });
                          },
                        ),
                      ),
                      PopupMenuButton<double>(
                        initialValue: _playbackSpeed,
                        onSelected: _changeSpeed,
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 0.5, child: Text('0.5x')),
                          const PopupMenuItem(value: 1.0, child: Text('1.0x')),
                          const PopupMenuItem(value: 1.5, child: Text('1.5x')),
                          const PopupMenuItem(value: 2.0, child: Text('2.0x')),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${_playbackSpeed}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${(_animController.value * 100).toInt()}%'),
                    ],
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
