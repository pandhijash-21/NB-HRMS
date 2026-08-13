import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../../core/utils/heading_utils.dart';

class TripVideoFrameInput {
  const TripVideoFrameInput({
    required this.points,
    required this.timestamps,
    required this.employeeName,
    required this.distanceKm,
  });

  final List<LatLng> points;
  final List<DateTime?> timestamps;
  final String employeeName;
  final double distanceKm;
}

class TripVideoExporter {
  TripVideoExporter._();

  static const _channel = MethodChannel('nb_crm/trip_video');
  static const width = 1280;
  static const height = 720;
  static const fps = 12;
  static const maxFrames = 216;

  static Future<String> exportMp4({
    required TripVideoFrameInput input,
    required void Function(double progress) onProgress,
  }) async {
    if (input.points.length < 2) {
      throw Exception('Not enough GPS points to build a trip video.');
    }

    final frames = _sampleFrames(input);
    await _channel.invokeMethod<String>('start', {
      'width': width,
      'height': height,
      'fps': fps,
    });

    try {
      for (var i = 0; i < frames.length; i++) {
        final png = await _renderFrame(
          input: input,
          frameIndex: i,
          totalFrames: frames.length,
          cursor: frames[i],
        );
        await _channel.invokeMethod('addFrame', {'bytes': png});
        onProgress((i + 1) / (frames.length + 1));
        await Future<void>.delayed(Duration.zero);
      }
      final path = await _channel.invokeMethod<String>('finish');
      onProgress(1);
      if (path == null || path.isEmpty) {
        throw Exception('Video encoder did not return a file.');
      }
      return path;
    } catch (e) {
      try {
        await _channel.invokeMethod('cancel');
      } catch (_) {}
      rethrow;
    }
  }

  static List<double> _sampleFrames(TripVideoFrameInput input) {
    final n = input.points.length;
    final count = math.max(48, math.min(maxFrames, n * 2));
    return List<double>.generate(count, (i) {
      if (count == 1) return 0;
      return i * (n - 1) / (count - 1);
    });
  }

  static Future<Uint8List> _renderFrame({
    required TripVideoFrameInput input,
    required int frameIndex,
    required int totalFrames,
    required double cursor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    _TripVideoPainter(
      points: input.points,
      timestamps: input.timestamps,
      employeeName: input.employeeName,
      distanceKm: input.distanceKm,
      cursor: cursor,
      frameIndex: frameIndex,
      totalFrames: totalFrames,
    ).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (bytes == null) {
      throw Exception('Failed to render video frame.');
    }
    return bytes.buffer.asUint8List();
  }
}

class _TripVideoPainter extends CustomPainter {
  _TripVideoPainter({
    required this.points,
    required this.timestamps,
    required this.employeeName,
    required this.distanceKm,
    required this.cursor,
    required this.frameIndex,
    required this.totalFrames,
  });

  final List<LatLng> points;
  final List<DateTime?> timestamps;
  final String employeeName;
  final double distanceKm;
  final double cursor;
  final int frameIndex;
  final int totalFrames;

  static const _gold = Color(0xFFC5A059);
  static const _bg = Color(0xFF12100E);
  static const _panel = Color(0xE61A1816);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
    _drawGrid(canvas, size);

    final projected = points.map((p) => _project(p, size)).toList();
    final idx = cursor.floor().clamp(0, points.length - 1);
    final next = math.min(idx + 1, points.length - 1);
    final t = cursor - idx;
    final traveled = <Offset>[];
    for (var i = 0; i <= idx; i++) {
      traveled.add(projected[i]);
    }
    if (next != idx) {
      traveled.add(Offset.lerp(projected[idx], projected[next], t)!);
    }
    final marker = traveled.last;

    final restPaint = Paint()
      ..color = const Color(0xFF4A4036)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = _gold.withValues(alpha: 0.28)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final goldPaint = Paint()
      ..color = _gold
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fullPath = Path()..moveTo(projected.first.dx, projected.first.dy);
    for (final p in projected.skip(1)) {
      fullPath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(fullPath, restPaint);

    if (traveled.length >= 2) {
      final gone = Path()..moveTo(traveled.first.dx, traveled.first.dy);
      for (final p in traveled.skip(1)) {
        gone.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(gone, glow);
      canvas.drawPath(gone, goldPaint);
    }

    _drawPin(canvas, projected.first, const Color(0xFF2E7D32), 'IN');
    _drawPin(canvas, projected.last, const Color(0xFFC62828), 'OUT');

    final heading = next == idx
        ? 0.0
        : bearingBetween(points[idx], points[next]);
    _drawMarker(canvas, marker, heading);

    _drawHud(
      canvas: canvas,
      size: size,
      currentTime: timestamps[idx],
      progress: (frameIndex + 1) / totalFrames,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14C5A059)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  Offset _project(LatLng p, Size size) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final q in points) {
      minLat = math.min(minLat, q.latitude);
      maxLat = math.max(maxLat, q.latitude);
      minLng = math.min(minLng, q.longitude);
      maxLng = math.max(maxLng, q.longitude);
    }
    const pad = 72.0;
    final latSpan = math.max(maxLat - minLat, 0.0004);
    final lngSpan = math.max(maxLng - minLng, 0.0004);
    final x = pad + (p.longitude - minLng) / lngSpan * (size.width - pad * 2);
    final y = pad + (maxLat - p.latitude) / latSpan * (size.height - pad * 2 - 56);
    return Offset(x, y);
  }

  void _drawPin(Canvas canvas, Offset c, Color color, String label) {
    canvas.drawCircle(c, 8, Paint()..color = color);
    canvas.drawCircle(c, 8, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, -22));
  }

  void _drawMarker(Canvas canvas, Offset c, double headingDeg) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(headingDeg * math.pi / 180);
    final path = Path()
      ..moveTo(0, -16)
      ..lineTo(11, 12)
      ..lineTo(0, 6)
      ..lineTo(-11, 12)
      ..close();
    canvas.drawPath(path, Paint()..color = _gold);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  void _drawHud({
    required Canvas canvas,
    required Size size,
    required DateTime? currentTime,
    required double progress,
  }) {
    final top = RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 18, 1232, 64),
      const Radius.circular(14),
    );
    canvas.drawRRect(top, Paint()..color = _panel);
    final title = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: 'TRIP RECORDING  ·  ',
            style: TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          TextSpan(
            text: employeeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 900);
    title.paint(canvas, const Offset(44, 36));

    final timeLabel = currentTime == null
        ? ''
        : currentTime.toLocal().toString().split('.').first;
    final meta = TextPainter(
      text: TextSpan(
        text: '${distanceKm.toStringAsFixed(2)} km   $timeLabel',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    meta.paint(canvas, Offset(size.width - meta.width - 44, 38));

    final bar = Rect.fromLTWH(24, size.height - 28, size.width - 48, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(8)),
      Paint()..color = const Color(0x33FFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, size.height - 28, (size.width - 48) * progress, 8),
        const Radius.circular(8),
      ),
      Paint()..color = _gold,
    );
  }

  @override
  bool shouldRepaint(covariant _TripVideoPainter oldDelegate) => true;
}
