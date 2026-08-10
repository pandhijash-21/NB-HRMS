import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Bearing from [from] → [to] in degrees clockwise from north (0–360).
double bearingBetween(LatLng from, LatLng to) {
  final lat1 = from.latitude * math.pi / 180;
  final lat2 = to.latitude * math.pi / 180;
  final dLon = (to.longitude - from.longitude) * math.pi / 180;

  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final brng = math.atan2(y, x) * 180 / math.pi;
  return (brng + 360) % 360;
}

double normalizeHeading(double degrees) {
  var h = degrees % 360.0;
  if (h < 0) h += 360.0;
  return h;
}

/// True when device GPS heading is usable (not -1 / NaN / stationary noise).
bool isValidGpsHeading(double? heading, {double? speedMps}) {
  if (heading == null || heading.isNaN || heading < 0) return false;
  // Many devices report 0 when unknown — treat as invalid if nearly stopped.
  if (speedMps != null && speedMps < 0.4 && heading == 0) return false;
  return true;
}

/// Prefer movement bearing when the car clearly moved; otherwise GPS / fallback.
double resolveTravelHeading({
  required double? gpsHeading,
  double? speedMps,
  LatLng? previous,
  LatLng? current,
  double? fallback,
}) {
  if (previous != null && current != null) {
    final dist = const Distance().as(LengthUnit.Meter, previous, current);
    if (dist >= 3.5) {
      return bearingBetween(previous, current);
    }
  }
  if (isValidGpsHeading(gpsHeading, speedMps: speedMps)) {
    return normalizeHeading(gpsHeading!);
  }
  return normalizeHeading(fallback ?? gpsHeading ?? 0);
}

/// Shortest-path lerp between two headings (degrees).
double lerpHeading(double from, double to, double t) {
  from = normalizeHeading(from);
  to = normalizeHeading(to);
  var diff = to - from;
  if (diff > 180) diff -= 360;
  if (diff < -180) diff += 360;
  return normalizeHeading(from + diff * t.clamp(0.0, 1.0));
}
