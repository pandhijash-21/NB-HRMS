import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'heading_utils.dart';

/// One continuous travel pass within a single trip (e.g. outbound, return, 3rd lap).
class RoutePass {
  RoutePass({
    required this.passNumber,
    required this.points,
    required this.color,
    required this.distanceMeters,
  });

  final int passNumber;
  final List<LatLng> points;
  final Color color;
  final double distanceMeters;
}

/// Result of splitting a trip polyline into colored, stackable passes.
class RoutePassAnalysis {
  RoutePassAnalysis({
    required this.passes,
    required this.polylines,
  });

  final List<RoutePass> passes;
  final List<Polyline> polylines;

  int get passCount => passes.length;
  bool get hasMultiplePasses => passes.length > 1;
}

/// Palette: pass 1 = blue, pass 2 = red, then distinct follow-ons.
const List<Color> kRoutePassColors = [
  Color(0xFF1565C0), // blue — first pass
  Color(0xFFC62828), // red — return / 2nd
  Color(0xFFEF6C00), // orange
  Color(0xFF6A1B9A), // purple
  Color(0xFF00838F), // teal
  Color(0xFFAD1457), // pink
  Color(0xFF2E7D32), // green
  Color(0xFF4527A0), // deep purple
];

Color colorForPass(int passNumber) {
  final i = (passNumber - 1) % kRoutePassColors.length;
  return kRoutePassColors[i];
}

/// Splits [rawPoints] into passes when the traveler U-turns (or sharply reverses),
/// and builds slightly offset polylines so overlapping road traces stack in color.
RoutePassAnalysis analyzeRoutePasses(
  List<LatLng> rawPoints, {
  double minStepMeters = 4.0,
  double uTurnDegrees = 140.0,
  double minPassMetersBeforeUTurn = 40.0,
  double stackOffsetMeters = 5.5,
  double strokeWidth = 5.0,
}) {
  if (rawPoints.length < 2) {
    final color = colorForPass(1);
    final pts = List<LatLng>.from(rawPoints);
    return RoutePassAnalysis(
      passes: pts.isEmpty
          ? const []
          : [
              RoutePass(
                passNumber: 1,
                points: pts,
                color: color,
                distanceMeters: 0,
              ),
            ],
      polylines: pts.length >= 2
          ? [
              Polyline(
                points: pts,
                strokeWidth: strokeWidth,
                color: color.withValues(alpha: 0.9),
              ),
            ]
          : const [],
    );
  }

  const distance = Distance();
  final cleaned = <LatLng>[rawPoints.first];
  for (var i = 1; i < rawPoints.length; i++) {
    final prev = cleaned.last;
    final next = rawPoints[i];
    if (distance.as(LengthUnit.Meter, prev, next) >= minStepMeters) {
      cleaned.add(next);
    }
  }
  if (cleaned.length < 2) {
    return RoutePassAnalysis(
      passes: [
        RoutePass(
          passNumber: 1,
          points: List<LatLng>.from(rawPoints),
          color: colorForPass(1),
          distanceMeters: 0,
        ),
      ],
      polylines: [
        Polyline(
          points: List<LatLng>.from(rawPoints),
          strokeWidth: strokeWidth,
          color: colorForPass(1).withValues(alpha: 0.9),
        ),
      ],
    );
  }

  final passesPoints = <List<LatLng>>[];
  var current = <LatLng>[cleaned.first];
  var passDistance = 0.0;
  // Rolling bearing of the last ~25m of this pass (smoother U-turn detect).
  double? passBearing;

  void flushPass() {
    if (current.length >= 2) {
      passesPoints.add(List<LatLng>.from(current));
    }
    current = current.isNotEmpty ? <LatLng>[current.last] : <LatLng>[];
    passDistance = 0.0;
    passBearing = null;
  }

  for (var i = 1; i < cleaned.length; i++) {
    final a = cleaned[i - 1];
    final b = cleaned[i];
    final stepM = distance.as(LengthUnit.Meter, a, b);
    if (stepM < minStepMeters * 0.5) continue;

    final bearing = bearingBetween(a, b);

    if (passBearing != null && passDistance >= minPassMetersBeforeUTurn) {
      final delta = _headingDelta(passBearing!, bearing);
      if (delta >= uTurnDegrees) {
        flushPass();
        if (current.isEmpty) {
          current.add(a);
        } else if (current.last != a) {
          current.add(a);
        }
      }
    }

    current.add(b);
    passDistance += stepM;
    // Blend bearing so gradual curves don't look like U-turns.
    if (passBearing == null) {
      passBearing = bearing;
    } else {
      passBearing = lerpHeading(passBearing!, bearing, 0.35);
    }
  }
  flushPass();

  if (passesPoints.isEmpty) {
    passesPoints.add(cleaned);
  }

  final passes = <RoutePass>[];
  final polylines = <Polyline>[];

  for (var i = 0; i < passesPoints.length; i++) {
    final pts = passesPoints[i];
    final passNumber = i + 1;
    final color = colorForPass(passNumber);
    var dist = 0.0;
    for (var j = 1; j < pts.length; j++) {
      dist += distance.as(LengthUnit.Meter, pts[j - 1], pts[j]);
    }
    passes.add(
      RoutePass(
        passNumber: passNumber,
        points: pts,
        color: color,
        distanceMeters: dist,
      ),
    );

    final offsetPts = _offsetPolyline(
      pts,
      meters: stackOffsetMeters * i,
    );
    // Draw earlier passes under later ones: add in order (pass1 then pass2 on top).
    polylines.add(
      Polyline(
        points: offsetPts,
        strokeWidth: strokeWidth + (i * 0.35),
        color: color.withValues(alpha: 0.9),
      ),
    );
  }

  return RoutePassAnalysis(passes: passes, polylines: polylines);
}

double _headingDelta(double a, double b) {
  var d = (b - a).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

/// Shift polyline sideways so stacked passes on the same road stay readable.
List<LatLng> _offsetPolyline(List<LatLng> points, {required double meters}) {
  if (meters.abs() < 0.5 || points.length < 2) {
    return List<LatLng>.from(points);
  }
  const distance = Distance();
  final out = <LatLng>[];
  for (var i = 0; i < points.length; i++) {
    final LatLng a;
    final LatLng b;
    if (i == 0) {
      a = points[0];
      b = points[1];
    } else if (i == points.length - 1) {
      a = points[i - 1];
      b = points[i];
    } else {
      a = points[i - 1];
      b = points[i + 1];
    }
    final bearing = bearingBetween(a, b);
    final perp = normalizeHeading(bearing + 90);
    out.add(distance.offset(points[i], meters, perp));
  }
  return out;
}
