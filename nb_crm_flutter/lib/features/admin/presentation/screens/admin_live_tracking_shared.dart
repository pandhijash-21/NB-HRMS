import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../auth/presentation/auth_providers.dart';
import '../widgets/tracking_avatar_marker.dart';

final geofenceLocationsProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  return dioClient.getEnvelope<List<dynamic>>(
    'attendance/admin/locations',
    parse: (r) => r as List<dynamic>,
  );
});

int? asEmployeeId(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

Map<int, Map<String, dynamic>> dutyById(List<dynamic> employees) {
  final map = <int, Map<String, dynamic>>{};
  for (final raw in employees) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    final id = asEmployeeId(row['employeeId']);
    if (id == null) continue;
    map[id] = row;
  }
  return map;
}

Color colorForUser(String name) {
  const colors = [
    Color(0xFFE53935),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFFF4511E),
    Color(0xFF3949AB),
    Color(0xFF00ACC1),
  ];
  final index =
      name.codeUnits.fold<int>(0, (prev, curr) => prev + curr) % colors.length;
  return colors[index];
}

String formatCompactDuration(int seconds) {
  if (seconds <= 0) return '0m';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

bool hasOpenTrip(Map<String, dynamic> loc) {
  final tripId = loc['tripId']?.toString();
  return tripId != null && tripId.isNotEmpty && tripId != 'null';
}

class GpsStatusChip extends StatelessWidget {
  const GpsStatusChip({
    super.key,
    required this.on,
    this.availableSeconds = 0,
    this.unavailableSeconds = 0,
  });

  final bool on;
  final int availableSeconds;
  final int unavailableSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: on ? const Color(0xFF2E7D32) : Colors.red.shade700,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        on
            ? 'GPS on ${formatCompactDuration(availableSeconds)}'
            : 'GPS off ${formatCompactDuration(unavailableSeconds)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class NameChip extends StatelessWidget {
  const NameChip({
    super.key,
    required this.name,
    required this.borderColor,
    required this.isDark,
  });

  final String name;
  final Color borderColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black87 : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class StoppedBubble extends StatelessWidget {
  const StoppedBubble({super.key, required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final timeStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
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

List<Marker> geofenceLabelMarkers(List<dynamic> geofences) {
  return geofences.map((loc) {
    return Marker(
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
    );
  }).toList();
}

List<CircleMarker> geofenceCircles(List<dynamic> geofences) {
  return geofences.map((loc) {
    final isUnique = loc['isUnique'] == true;
    final baseColor = isUnique ? Colors.blue.shade900 : Colors.blue;
    return CircleMarker(
      point: LatLng(loc['latitude'], loc['longitude']),
      color: baseColor.withValues(alpha: 0.2),
      borderColor: baseColor.withValues(alpha: 0.8),
      borderStrokeWidth: isUnique ? 3 : 2,
      useRadiusInMeter: true,
      radius: (loc['radiusKm'] * 1000).toDouble(),
    );
  }).toList();
}

Widget youAreHereMarker({
  required bool isDark,
  required String? photoUrl,
}) {
  final pinColor = Colors.blue.shade600;
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: pinColor, width: 1.5),
        ),
        child: const Text(
          'You',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
      TrackingAvatarMarker(photoUrl: photoUrl, size: 32, borderColor: pinColor),
    ],
  );
}
