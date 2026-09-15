import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/earth_models.dart';
import 'earth_pin.dart';

class EarthGlobeView extends StatefulWidget {
  const EarthGlobeView({
    super.key,
    required this.properties,
    required this.selectedId,
    required this.autoSpin,
    required this.nightMode,
    required this.zoom,
    required this.onZoomChanged,
    required this.onTapGlobe,
    required this.onTapProperty,
  });

  static const minZoom = 0.65;
  static const maxZoom = 4.2;

  final List<EarthProperty> properties;
  final String? selectedId;
  final bool autoSpin;
  final bool nightMode;
  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final void Function(double lat, double lng) onTapGlobe;
  final void Function(EarthProperty property) onTapProperty;

  @override
  State<EarthGlobeView> createState() => _EarthGlobeViewState();
}

class _EarthGlobeViewState extends State<EarthGlobeView>
    with SingleTickerProviderStateMixin {
  static const _dayAsset = 'assets/images/earth/earth-day.jpg';
  static const _nightAsset = 'assets/images/earth/earth-night.jpg';
  static const _dayUrl =
      'https://raw.githubusercontent.com/Pana-g/flutter_earth_globe/master/example/assets/2k_earth-day.jpg';
  static const _nightUrl =
      'https://raw.githubusercontent.com/Pana-g/flutter_earth_globe/master/example/assets/2k_earth-night.jpg';

  late final AnimationController _spin;
  ui.Image? _day;
  ui.Image? _night;
  Uint8List? _dayPixels;
  Uint8List? _nightPixels;
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  bool _failed = false;
  double _yaw = 0.85;
  double _pitch = 0.22;
  Offset? _lastDrag;
  Offset? _pointerDown;
  bool _dragged = false;
  double _scaleStartZoom = 1;
  Timer? _tapTimer;

  ui.Image? get _texture => widget.nightMode ? (_night ?? _day) : _day;
  Uint8List? get _pixels => widget.nightMode ? (_nightPixels ?? _dayPixels) : _dayPixels;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..addListener(() {
        if (widget.autoSpin && _lastDrag == null) {
          setState(() => _yaw += 0.004);
        }
      });
    _spin.repeat();
    _load();
  }

  Future<void> _load() async {
    try {
      try {
        _program = await ui.FragmentProgram.fromAsset('shaders/earth_sphere.frag');
        _shader = _program!.fragmentShader();
      } catch (_) {}
      final day = await _decode(_dayAsset, _dayUrl);
      ui.Image? night;
      try {
        night = await _decode(_nightAsset, _nightUrl);
      } catch (_) {}
      final dayPx = await _rgba(day);
      Uint8List? nightPx;
      if (night != null) nightPx = await _rgba(night);
      if (!mounted) {
        day.dispose();
        night?.dispose();
        return;
      }
      setState(() {
        _day = day;
        _night = night;
        _dayPixels = dayPx;
        _nightPixels = nightPx;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<Uint8List?> _rgba(ui.Image image) async {
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data != null) return data.buffer.asUint8List();
    } catch (_) {}
    try {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImage(image, Offset.zero, Paint());
      final copy = await recorder.endRecording().toImage(image.width, image.height);
      final data = await copy.toByteData(format: ui.ImageByteFormat.rawRgba);
      copy.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<ui.Image> _decode(String asset, String fallbackUrl) async {
    try {
      final data = await rootBundle.load(asset);
      return await _codec(data.buffer.asUint8List());
    } catch (_) {
      final completer = Completer<ui.Image>();
      final stream = NetworkImage(fallbackUrl).resolve(const ImageConfiguration());
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          stream.removeListener(listener);
          completer.complete(info.image);
        },
        onError: (error, stack) {
          stream.removeListener(listener);
          completer.completeError(error);
        },
      );
      stream.addListener(listener);
      return completer.future;
    }
  }

  Future<ui.Image> _codec(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _spin.dispose();
    _shader?.dispose();
    _day?.dispose();
    _night?.dispose();
    super.dispose();
  }

  double _radius(Size size) {
    final zoom = widget.zoom.clamp(EarthGlobeView.minZoom, EarthGlobeView.maxZoom);
    return (size.shortestSide * 0.38 * zoom).clamp(90.0, size.longestSide * 1.6);
  }

  void _setZoom(double next) {
    final z = next.clamp(EarthGlobeView.minZoom, EarthGlobeView.maxZoom);
    if ((z - widget.zoom).abs() < 0.001) return;
    widget.onZoomChanged(z);
  }

  Offset _center(Size size) => Offset(size.width / 2, size.height / 2);

  Offset? _project(double latDeg, double lngDeg, Size size) {
    final p = _project3(latDeg * math.pi / 180, lngDeg * math.pi / 180);
    if (p.z <= 0.08) return null;
    final c = _center(size);
    final r = _radius(size);
    return Offset(c.dx + p.x * r, c.dy - p.y * r);
  }

  _Vec3 _project3(double lat, double lon) {
    final lonR = lon + _yaw;
    var x = math.cos(lat) * math.sin(lonR);
    var y = math.sin(lat);
    var z = math.cos(lat) * math.cos(lonR);
    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);
    final y2 = y * cp - z * sp;
    final z2 = y * sp + z * cp;
    return _Vec3(x, y2, z2);
  }

  void _onTapDown(TapDownDetails d, Size size) {
    final c = _center(size);
    final r = _radius(size);
    final dx = (d.localPosition.dx - c.dx) / r;
    final dy = (c.dy - d.localPosition.dy) / r;
    final d2 = dx * dx + dy * dy;
    if (d2 > 1) return;
    final z = math.sqrt(1 - d2);
    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);
    final y = dy * cp + z * sp;
    final z2 = -dy * sp + z * cp;
    final x = dx;
    final lat = math.asin(y.clamp(-1, 1));
    final lon = math.atan2(x, z2) - _yaw;
    var lng = lon * 180 / math.pi;
    while (lng > 180) {
      lng -= 360;
    }
    while (lng < -180) {
      lng += 360;
    }
    widget.onTapGlobe(lat * 180 / math.pi, lng);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF05070F)),
            CustomPaint(painter: _StarfieldPainter()),
            if (_texture != null)
              Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
                      final e = resolved as PointerScrollEvent;
                      final factor = e.scrollDelta.dy > 0 ? 0.90 : 1.11;
                      _setZoom(widget.zoom * factor);
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    _tapTimer?.cancel();
                    _dragged = true;
                    _setZoom(widget.zoom * 1.28);
                  },
                  onScaleStart: (d) {
                    _lastDrag = d.localFocalPoint;
                    _pointerDown = d.localFocalPoint;
                    _dragged = false;
                    _scaleStartZoom = widget.zoom;
                  },
                  onScaleUpdate: (d) {
                    final last = _lastDrag ?? d.localFocalPoint;
                    final delta = d.localFocalPoint - last;
                    _lastDrag = d.localFocalPoint;
                    if (delta.distanceSquared > 0.4 || (d.scale - 1).abs() > 0.015) {
                      _dragged = true;
                    }
                    setState(() {
                      _yaw += delta.dx * 0.01;
                      _pitch = (_pitch + delta.dy * 0.005).clamp(-0.7, 0.7);
                    });
                    if ((d.scale - 1).abs() > 0.01) {
                      _setZoom(_scaleStartZoom * d.scale);
                    }
                  },
                  onScaleEnd: (d) {
                    _lastDrag = null;
                    if (_dragged || _pointerDown == null) return;
                    final pos = _pointerDown!;
                    _tapTimer?.cancel();
                    _tapTimer = Timer(const Duration(milliseconds: 220), () {
                      if (!mounted) return;
                      _onTapDown(TapDownDetails(localPosition: pos), size);
                    });
                  },
                  child: CustomPaint(
                    painter: _EarthSpherePainter(
                      texture: _texture!,
                      pixels: _pixels,
                      shader: _shader,
                      yaw: _yaw,
                      pitch: _pitch,
                      radius: _radius(size),
                    ),
                    size: size,
                  ),
                ),
              )
            else
              Center(
                child: _failed
                    ? const Text(
                        'Could not load Earth texture',
                        style: TextStyle(color: Colors.white54),
                      )
                    : const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
              ),
            ..._pins(size),
          ],
        );
      },
    );
  }

  List<Widget> _pins(Size size) {
    final pins = <Widget>[];
    for (final p in widget.properties) {
      final pos = _project(p.latitude, p.longitude, size);
      if (pos == null) continue;
      final selected = p.id == widget.selectedId;
      pins.add(
        Positioned(
          left: pos.dx - 18,
          top: pos.dy - 18,
          child: GestureDetector(
            onTap: () => widget.onTapProperty(p),
            child: EarthPropertyPin(
              kind: p.kind,
              imageUrl: p.pinImage.isEmpty ? null : p.pinImage,
              size: selected ? 40 : 32,
              selected: selected,
              label: selected ? p.name : null,
            ),
          ),
        ),
      );
    }
    return pins;
  }
}

class _Vec3 {
  const _Vec3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}

class _EarthSpherePainter extends CustomPainter {
  _EarthSpherePainter({
    required this.texture,
    required this.pixels,
    required this.shader,
    required this.yaw,
    required this.pitch,
    required this.radius,
  });

  final ui.Image texture;
  final Uint8List? pixels;
  final ui.FragmentShader? shader;
  final double yaw;
  final double pitch;
  final double radius;

  static const _stacks = 56;
  static const _slices = 96;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = radius;

    canvas.drawCircle(
      c,
      r * 1.16,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.2,
          const [Color(0x334078C8), Color(0x114078C8), Color(0x00000000)],
          const [0.74, 0.88, 1.0],
        ),
    );

    var painted = false;
    if (shader != null) {
      try {
        _paintShader(canvas, size, c, r);
        painted = true;
      } catch (_) {
        painted = false;
      }
    }
    if (!painted && pixels != null && pixels!.length >= texture.width * texture.height * 4) {
      _paintMesh(canvas, c, r);
      painted = true;
    }
    if (!painted) {
      _paintFlat(canvas, c, r);
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = const Color(0x66B7D7FF),
    );
  }

  void _paintShader(Canvas canvas, Size size, Offset c, double r) {
    final s = shader!;
    var i = 0;
    s.setFloat(i++, c.dx);
    s.setFloat(i++, c.dy);
    s.setFloat(i++, r);
    s.setFloat(i++, yaw);
    s.setFloat(i++, pitch);
    s.setImageSampler(0, texture);
    canvas.drawRect(Offset.zero & size, Paint()..shader = s);
  }

  void _paintMesh(Canvas canvas, Offset c, double r) {
    final tw = texture.width;
    final th = texture.height;
    final px = pixels!;
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final positions = <Offset>[];
    final colors = <Color>[];
    final indices = <int>[];

    Color sample(double u, double v) {
      var uu = u % 1.0;
      if (uu < 0) uu += 1;
      final vv = v.clamp(0.0, 1.0);
      final x = (uu * (tw - 1)).round().clamp(0, tw - 1);
      final y = (vv * (th - 1)).round().clamp(0, th - 1);
      final o = (y * tw + x) * 4;
      return Color.fromARGB(255, px[o], px[o + 1], px[o + 2]);
    }

    _Vec3 rotate(double lat, double lon) {
      final lonR = lon + yaw;
      final x = math.cos(lat) * math.sin(lonR);
      final y = math.sin(lat);
      final z = math.cos(lat) * math.cos(lonR);
      return _Vec3(x, y * cp - z * sp, y * sp + z * cp);
    }

    final grid = List<_Vec3>.filled((_stacks + 1) * (_slices + 1), const _Vec3(0, 0, 0));
    final uv = List<Color>.filled((_stacks + 1) * (_slices + 1), Colors.black);
    for (var i = 0; i <= _stacks; i++) {
      final lat = math.pi / 2 - i * math.pi / _stacks;
      for (var j = 0; j <= _slices; j++) {
        final lon = -math.pi + j * 2 * math.pi / _slices;
        final idx = i * (_slices + 1) + j;
        grid[idx] = rotate(lat, lon);
        uv[idx] = sample(j / _slices, i / _stacks);
      }
    }

    void tri(int a, int b, int d) {
      final va = grid[a];
      final vb = grid[b];
      final vd = grid[d];
      if (va.z < 0.04 || vb.z < 0.04 || vd.z < 0.04) return;
      final base = positions.length;
      for (final pair in [(va, uv[a]), (vb, uv[b]), (vd, uv[d])]) {
        final v = pair.$1;
        final light = (0.38 + 0.62 * v.z.clamp(0.0, 1.0)).clamp(0.22, 1.0);
        positions.add(Offset(c.dx + v.x * r, c.dy - v.y * r));
        colors.add(Color.fromARGB(
          255,
          (pair.$2.red * light).round(),
          (pair.$2.green * light).round(),
          (pair.$2.blue * light).round(),
        ));
      }
      indices.addAll([base, base + 1, base + 2]);
    }

    for (var i = 0; i < _stacks; i++) {
      for (var j = 0; j < _slices; j++) {
        final a = i * (_slices + 1) + j;
        final b = a + 1;
        final d = (i + 1) * (_slices + 1) + j;
        final e = d + 1;
        tri(a, d, b);
        tri(b, d, e);
      }
    }

    if (positions.isEmpty) return;
    canvas.drawVertices(
      ui.Vertices(
        VertexMode.triangles,
        positions,
        colors: colors,
        indices: indices,
      ),
      BlendMode.srcOver,
      Paint()..isAntiAlias = true,
    );
  }

  void _paintFlat(Canvas canvas, Offset c, double r) {
    final sphere = Rect.fromCircle(center: c, radius: r);
    canvas.save();
    canvas.clipPath(Path()..addOval(sphere));
    final tw = texture.width.toDouble();
    final th = texture.height.toDouble();
    final destH = r * 2;
    final destW = destH * (tw / th);
    var x = c.dx - destW / 2 + ((yaw / (2 * math.pi)) * destW);
    x %= destW;
    final y = c.dy - r + pitch * r * 0.85;
    final src = Rect.fromLTWH(0, 0, tw, th);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (final shift in <double>[-destW, 0, destW]) {
      canvas.drawImageRect(texture, src, Rect.fromLTWH(x + shift, y, destW, destH), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EarthSpherePainter old) =>
      old.texture != texture ||
      old.pixels != pixels ||
      old.shader != shader ||
      old.yaw != yaw ||
      old.pitch != pitch ||
      old.radius != radius;
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 120; i++) {
      paint.color = Colors.white.withValues(alpha: 0.15 + rnd.nextDouble() * 0.7);
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * 1.4 + 0.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

