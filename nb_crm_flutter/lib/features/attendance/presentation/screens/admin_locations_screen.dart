import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../attendance_providers.dart';

// ---------------------------------------------------------
// NOTE: This screen requires flutter_map and latlong2.
// Ensure those are imported and added to pubspec.yaml.
// ---------------------------------------------------------

class AdminLocationsScreen extends ConsumerStatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  ConsumerState<AdminLocationsScreen> createState() => _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends ConsumerState<AdminLocationsScreen> {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _locations = [];
  bool _isLoading = true;
  String? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _centerToCurrentLocation();
  }

  Future<void> _centerToCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
    } catch (e) {
      // Ignore errors for optional location centering
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final dio = ref.read(dioClientProvider);
      final res = await dio.getEnvelope<List<dynamic>>('attendance/admin/locations', parse: (r) => r as List<dynamic>);
      setState(() {
        _locations = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onLocationSelected(String id, double lat, double lng, int index) {
    setState(() {
      _selectedLocationId = id;
    });
    _mapController.move(LatLng(lat, lng), 15.0);
    
    // Auto-scroll the list to the selected item (approx 100px per ListTile)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        index * 100.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showAddLocationDialog([Map<String, dynamic>? existing]) {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final latCtrl = TextEditingController(text: existing?['latitude']?.toString() ?? '');
    final lngCtrl = TextEditingController(text: existing?['longitude']?.toString() ?? '');
    final radCtrl = TextEditingController(text: existing?['radiusKm']?.toString() ?? '0.1'); // Default 100m
    bool isUnique = existing?['isUnique'] ?? false;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Allowed Zone' : 'Edit Zone'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Location Name (e.g. Main Office)'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        decoration: const InputDecoration(labelText: 'Latitude'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        decoration: const InputDecoration(labelText: 'Longitude'),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: radCtrl,
                  decoration: const InputDecoration(labelText: 'Radius (in km, e.g. 0.1 for 100m)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Unique Location'),
                  subtitle: const Text('Highlights main offices or special branches'),
                  value: isUnique,
                  onChanged: (val) => setDialogState(() => isUnique = val),
                  contentPadding: EdgeInsets.zero,
                  activeColor: Colors.blue.shade900,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tip: You can use google maps to find latitude and longitude of your office.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text;
                final lat = double.tryParse(latCtrl.text) ?? 0.0;
                final lng = double.tryParse(lngCtrl.text) ?? 0.0;
                final rad = double.tryParse(radCtrl.text) ?? 0.1;
                
                if (name.isEmpty) return;

                final dio = ref.read(dioClientProvider);
                try {
                  if (existing == null || !existing.containsKey('id') || existing['id'] == null) {
                    await dio.postEnvelope('attendance/admin/locations', data: {
                      'name': name,
                      'latitude': lat,
                      'longitude': lng,
                      'radiusKm': rad,
                      'isUnique': isUnique,
                      'isActive': true,
                    }, parse: (r) => r);
                  } else {
                    await dio.patchEnvelope('attendance/admin/locations/${existing['id']}', data: {
                      'name': name,
                      'latitude': lat,
                      'longitude': lng,
                      'radiusKm': rad,
                      'isUnique': isUnique,
                    }, parse: (r) => r);
                  }
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
                _fetchLocations();
              },
              child: const Text('Save'),
            ),
          ],
        );
          },
        );
      },
    );
  }

  Future<void> _deleteLocation(String id) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.deleteEnvelope('attendance/admin/locations/$id', parse: (r) => r);
      _fetchLocations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Admin: Geofenced Zones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => _showAddLocationDialog(),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _locations.isNotEmpty
                          ? LatLng(_locations.first['latitude'], _locations.first['longitude'])
                          : const LatLng(23.0225, 72.5714), // Default Ahmedabad
                      initialZoom: 13.0,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onTap: (tapPosition, point) {
                        _showAddLocationDialog({
                          'latitude': point.latitude,
                          'longitude': point.longitude,
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nbdeveloper.hrms',
                      ),
                      CircleLayer(
                        circles: _locations.map((loc) {
                          final isSelected = loc['id'] == _selectedLocationId;
                          final isUnique = loc['isUnique'] == true;
                          final baseColor = isUnique ? Colors.blue.shade900 : Colors.blue;
                          return CircleMarker(
                            point: LatLng(loc['latitude'], loc['longitude']),
                            color: isSelected ? Colors.orange.withOpacity(0.3) : baseColor.withOpacity(0.3),
                            borderColor: isSelected ? Colors.orange : baseColor,
                            borderStrokeWidth: isSelected ? 3 : (isUnique ? 3 : 2),
                            useRadiusInMeter: true,
                            radius: (loc['radiusKm'] * 1000).toDouble(), // km to meters
                          );
                        }).toList(),
                      ),
                      MarkerLayer(
                        markers: _locations.asMap().entries.map((entry) {
                          final index = entry.key;
                          final loc = entry.value;
                          final isSelected = loc['id'] == _selectedLocationId;
                          final isUnique = loc['isUnique'] == true;
                          final baseColor = isUnique ? Colors.blue.shade900 : Colors.red;
                          return Marker(
                            point: LatLng(loc['latitude'], loc['longitude']),
                            width: 60,
                            height: 60,
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () => _onLocationSelected(loc['id'], loc['latitude'], loc['longitude'], index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.elasticOut,
                                transform: Matrix4.translationValues(0, isSelected ? -10 : 0, 0),
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: isSelected ? Colors.orange : baseColor,
                                      size: isSelected ? 50 : 40,
                                      shadows: const [
                                        Shadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 6)),
                                      ],
                                    ),
                                    if (isUnique)
                                      Positioned(
                                        top: isSelected ? 9 : 7,
                                        child: Icon(
                                          Icons.star_rounded,
                                          color: Colors.white,
                                          size: isSelected ? 22 : 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _locations.length,
                    itemBuilder: (context, index) {
                      final loc = _locations[index];
                      return ListTile(
                        leading: const Icon(Icons.location_city_rounded),
                        title: Text(loc['name']),
                        subtitle: Text('Radius: ${loc['radiusKm']} km\nLat: ${loc['latitude']}, Lng: ${loc['longitude']}'),
                        isThreeLine: true,
                        selected: loc['id'] == _selectedLocationId,
                        selectedTileColor: isDark ? Colors.white10 : Colors.blue.shade50,
                        onTap: () => _onLocationSelected(loc['id'], loc['latitude'], loc['longitude'], index),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                              onPressed: () => _showAddLocationDialog(loc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.red),
                              onPressed: () => _deleteLocation(loc['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
