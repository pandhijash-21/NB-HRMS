import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' show pi;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import '../../../auth/presentation/auth_providers.dart';

final _liveLocationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.dio.get('/tracking/live');
  return res.data['data'] ?? [];
});

final _geofenceLocationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final res = await dioClient.getEnvelope<List<dynamic>>('attendance/admin/locations', parse: (r) => r as List<dynamic>);
  return res;
});

class AdminLiveTrackingScreen extends ConsumerStatefulWidget {
  const AdminLiveTrackingScreen({super.key});

  @override
  ConsumerState<AdminLiveTrackingScreen> createState() => _AdminLiveTrackingScreenState();
}

class _AdminLiveTrackingScreenState extends ConsumerState<AdminLiveTrackingScreen> {
  Timer? _timer;
  LatLng? _myLocation;
  String? _selectedGeofenceId;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchMyLocation();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.invalidate(_liveLocationsProvider);
    });
  }

  Future<void> _fetchMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() {
          _myLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      // Ignore errors for now
    }
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
    final index = name.codeUnits.fold<int>(0, (prev, curr) => prev + curr) % colors.length;
    return colors[index];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final role = auth.user?.role.toUpperCase() ?? '';
    final canView = ['SUPERADMIN', 'ADMIN', 'HR'].contains(role);

    if (!canView) {
      return const Scaffold(
        body: Center(child: Text('Permission Denied. Only Admins and HR can view Live Tracking.')),
      );
    }

    final asyncLocations = ref.watch(_liveLocationsProvider);
    final asyncGeofences = ref.watch(_geofenceLocationsProvider);
    final geofences = asyncGeofences.value ?? [];
    
    // Apply filter
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
                  ...geofences.map((g) => DropdownMenuItem<String?>(
                        value: g['id']?.toString(),
                        child: Text(g['name'] ?? 'Unknown'),
                      )),
                ],
                onChanged: (val) {
                  setState(() => _selectedGeofenceId = val);
                  if (val != null) {
                    final target = geofences.firstWhere((g) => g['id'].toString() == val, orElse: () => null);
                    if (target != null) {
                      _mapController.move(LatLng(target['latitude'], target['longitude']), 15.0);
                    }
                  }
                },
              ),
            ),
        ],
      ),
      body: asyncLocations.when(
        data: (locations) {
          final markers = locations.map((loc) {
            final lat = (loc['latitude'] as num).toDouble();
            final lng = (loc['longitude'] as num).toDouble();
            final name = loc['fullName'] ?? 'Unknown';
            final employeeId = loc['employeeId'];
            final pinColor = _getColorForUser(name);
            final isPunchedIn = loc['isPunchedIn'] == true;
            final isOutsideGeofence = loc['isOutsideGeofence'] == true;
            final heading = (loc['heading'] as num?)?.toDouble() ?? 0.0;

            Widget markerChild;

            if (isPunchedIn && isOutsideGeofence && employeeId != null) {
              final models = [
                'assets/3d/car.glb',
                'assets/3d/cyberpunk_car.glb',
                'assets/3d/dominus_-_rocket_league_car.glb',
              ];
              final modelPath = models[(employeeId as int) % models.length];

              markerChild = GestureDetector(
                onTap: () => context.go('/admin/employees/$employeeId'),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: pinColor, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: heading),
                      duration: const Duration(seconds: 1),
                      builder: (context, angle, child) {
                        return Transform.rotate(
                          angle: angle * (pi / 180),
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
                        );
                      },
                    ),
                  ],
                ),
              );
            } else {
              markerChild = GestureDetector(
                onTap: () {
                  if (employeeId != null) {
                    context.go('/admin/employees/$employeeId');
                  }
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: pinColor, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.3),
                          radius: 0.8,
                          colors: [
                            pinColor.withOpacity(0.5),
                            pinColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: pinColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1.5,
                            offset: const Offset(0, 4),
                          ),
                          const BoxShadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              );
            }

            return Marker(
              point: LatLng(lat, lng),
              width: 120,
              height: 100, // Increased height for 3D model
              child: markerChild,
            );
          }).toList();

          // Add Geofence labels
          for (final loc in filteredGeofences) {
            markers.add(
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
                      color: (loc['isUnique'] == true) ? Colors.blue.shade900 : Colors.blue,
                      shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          if (_myLocation != null) {
            final myPinColor = Colors.blue.shade600;
            markers.add(
              Marker(
                point: _myLocation!,
                width: 120,
                height: 70,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: myPinColor, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Text(
                        'You',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.3, -0.3),
                          radius: 0.8,
                          colors: [
                            myPinColor.withOpacity(0.5),
                            myPinColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: myPinColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1.5,
                            offset: const Offset(0, 4),
                          ),
                          const BoxShadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            );
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation ?? const LatLng(0, 0),
              initialZoom: _myLocation != null ? 12 : 3,
              minZoom: 2,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.nb.hrms',
              ),
              CircleLayer(
                circles: filteredGeofences.map((loc) {
                  final isUnique = loc['isUnique'] == true;
                  final baseColor = isUnique ? Colors.blue.shade900 : Colors.blue;
                  return CircleMarker(
                    point: LatLng(loc['latitude'], loc['longitude']),
                    color: baseColor.withOpacity(0.2),
                    borderColor: baseColor.withOpacity(0.8),
                    borderStrokeWidth: isUnique ? 3 : 2,
                    useRadiusInMeter: true,
                    radius: (loc['radiusKm'] * 1000).toDouble(), // km to meters
                  );
                }).toList(),
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: markers,
                  builder: (context, clusterMarkers) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.blue.shade900,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                        ],
                      ),
                      child: Center(
                        child: Text(
                          clusterMarkers.length.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
        error: (e, st) => Center(child: Text('Error loading live tracking data')),
      ),
    );
  }
}
