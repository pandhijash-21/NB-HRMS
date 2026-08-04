import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'dart:math' show pi;
import '../../../auth/presentation/auth_providers.dart';

final adminTripRouteProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, tripId) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('/tracking/trips/$tripId/route');
  return res.data['data'] as Map<String, dynamic>;
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
  late Animation<double> _animation;
  
  List<LatLng> _routePoints = [];
  List<double> _headings = [];
  
  LatLng? _currentPosition;
  double _currentHeading = 0.0;
  bool _isPlaying = false;
  
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
    final exactIndex = progress * totalSegments;
    final baseIndex = exactIndex.floor();
    final remainder = exactIndex - baseIndex;
    
    if (baseIndex < totalSegments) {
      final p1 = _routePoints[baseIndex];
      final p2 = _routePoints[baseIndex + 1];
      
      final lat = p1.latitude + (p2.latitude - p1.latitude) * remainder;
      final lng = p1.longitude + (p2.longitude - p1.longitude) * remainder;
      
      setState(() {
        _currentPosition = LatLng(lat, lng);
        if (_headings.length > baseIndex) {
          _currentHeading = _headings[baseIndex];
        }
      });
    }
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
      ),
      body: routeAsync.when(
        data: (data) {
          final trip = data['trip'];
          final rawRoute = data['route'] as List;
          
          if (rawRoute.isEmpty) {
            return const Center(child: Text('No location data recorded for this trip.'));
          }

          if (_routePoints.isEmpty) {
            _routePoints = rawRoute.map((p) => LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble())).toList();
            _headings = rawRoute.map((p) => (p['heading'] as num?)?.toDouble() ?? 0.0).toList();
            _currentPosition = _routePoints.first;
            _currentHeading = _headings.first;
            
            // Adjust animation duration based on distance/points
            _animController.duration = Duration(seconds: (_routePoints.length / 5).clamp(5.0, 60.0).toInt());
          }

          final employeeId = trip['employeeId'] as int;
          final models = [
            'assets/3d/car.glb',
            'assets/3d/cyberpunk_car.glb',
            'assets/3d/dominus_-_rocket_league_car.glb',
          ];
          final modelPath = models[employeeId % models.length];
          final employeeName = trip['employee']?['generalInfo']?['fullName'] ?? 'Unknown';
          
          // Calculate map bounds
          final bounds = LatLngBounds.fromPoints(_routePoints);

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
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
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
                              Transform.rotate(
                                angle: _currentHeading * (pi / 180),
                                child: SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: IgnorePointer(
                                    child: Flutter3DViewer(
                                      src: modelPath,
                                      activeGestureInterceptor: false,
                                    ),
                                  ),
                                ),
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
