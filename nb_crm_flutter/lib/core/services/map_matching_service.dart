import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../logging/app_logger.dart';

class MapMatchingService {
  // Public OSRM demo server for map matching
  // In production, this should point to a self-hosted instance to avoid rate limits
  static const String _osrmDemoUrl = 'https://router.project-osrm.org/match/v1/driving';

  /// Takes a list of raw LatLng points and returns a list of snapped LatLng points
  /// using OSRM map matching.
  static Future<List<LatLng>> matchPoints(List<LatLng> points) async {
    if (points.isEmpty) return [];
    if (points.length == 1) return points; // OSRM requires at least 2 points

    try {
      final coordinates = points.map((p) => '${p.longitude},${p.latitude}').join(';');
      final uri = Uri.parse('$_osrmDemoUrl/$coordinates?geometries=geojson&overview=full');
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['matchings'] != null && data['matchings'].isNotEmpty) {
          final matchedPoints = <LatLng>[];
          for (var matching in data['matchings']) {
            final geom = matching['geometry']['coordinates'] as List;
            for (var coord in geom) {
              matchedPoints.add(LatLng(coord[1] as double, coord[0] as double));
            }
          }
          return matchedPoints.isNotEmpty ? matchedPoints : points;
        }
      }
      return points; // Fallback to raw points on failure
    } catch (e) {
      AppLogger.tracking.w('OSRM match error: $e');
      return points; // Fallback to raw points on exception
    }
  }

  /// Batch processes a large number of points by chunking them to avoid URI length limits
  static Future<List<LatLng>> matchPointsInBatches(List<LatLng> points, {int batchSize = 50}) async {
    if (points.length <= batchSize) {
      return matchPoints(points);
    }

    final matchedPoints = <LatLng>[];
    for (int i = 0; i < points.length; i += batchSize) {
      final end = (i + batchSize < points.length) ? i + batchSize : points.length;
      final chunk = points.sublist(i, end);
      
      // To ensure continuity, if this is not the first chunk, include the last point of the previous chunk
      final chunkToMatch = i > 0 ? [points[i - 1], ...chunk] : chunk;
      
      final matchedChunk = await matchPoints(chunkToMatch);
      
      // If we added the overlapping point, remove it from the result to avoid duplicates
      if (i > 0 && matchedChunk.isNotEmpty) {
        matchedPoints.addAll(matchedChunk.sublist(1));
      } else {
        matchedPoints.addAll(matchedChunk);
      }
    }
    
    return matchedPoints;
  }
}
