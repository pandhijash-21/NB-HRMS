import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

import '../../../../core/utils/heading_utils.dart';

/// Top-down car marker that faces the direction of travel.
///
/// Uses a GLB when available; falls back to a painted directional car so
/// heading always reads clearly (even if assets are missing).
class Car3DMarkerWidget extends StatefulWidget {
  final String modelPath;
  /// Degrees clockwise from north (map up).
  final double heading;
  final double size;
  /// Extra yaw so the GLB's "forward" aligns with map north (common GLBs need 90).
  final double modelForwardOffsetDegrees;

  const Car3DMarkerWidget({
    super.key,
    required this.modelPath,
    required this.heading,
    this.size = 56,
    this.modelForwardOffsetDegrees = 90,
  });

  @override
  State<Car3DMarkerWidget> createState() => _Car3DMarkerWidgetState();
}

class _Car3DMarkerWidgetState extends State<Car3DMarkerWidget>
    with SingleTickerProviderStateMixin {
  final Flutter3DController _controller = Flutter3DController();
  late AnimationController _turnController;
  late Animation<double> _turnAnimation;
  double _fromHeading = 0;
  double _toHeading = 0;
  bool _modelReady = false;
  bool _modelFailed = false;

  @override
  void initState() {
    super.initState();
    _fromHeading = normalizeHeading(widget.heading);
    _toHeading = _fromHeading;
    _turnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _turnAnimation = AlwaysStoppedAnimation(_fromHeading);
  }

  @override
  void didUpdateWidget(covariant Car3DMarkerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heading != widget.heading) {
      _animateTo(normalizeHeading(widget.heading));
    }
  }

  void _animateTo(double next) {
    _fromHeading = normalizeHeading(
      _turnAnimation.value.isNaN ? _toHeading : _turnAnimation.value,
    );
    _toHeading = next;
    _turnAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _turnController, curve: Curves.easeOutCubic),
    );
    _turnController.forward(from: 0);
  }

  double get _displayedHeading {
    final t = _turnController.isAnimating ? _turnAnimation.value : 1.0;
    return lerpHeading(_fromHeading, _toHeading, t);
  }

  @override
  void dispose() {
    _turnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final travelHeading = normalizeHeading(_displayedHeading);

    return AnimatedBuilder(
      animation: _turnController,
      builder: (context, _) {
        return Transform.rotate(
          // 0° = north (map up). Flutter rotates clockwise.
          angle: travelHeading * 3.141592653589793 / 180.0,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Painted car faces "up" = forward after parent rotation.
                if (!_modelReady || _modelFailed)
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _TopDownCarPainter(
                      color: Colors.blue.shade700,
                    ),
                  ),
                if (!_modelFailed)
                  IgnorePointer(
                    child: Opacity(
                      opacity: _modelReady ? 1 : 0,
                      child: Transform.rotate(
                        // Align GLB mesh forward axis with map-north before travel yaw.
                        angle: widget.modelForwardOffsetDegrees *
                            3.141592653589793 /
                            180.0,
                        child: Flutter3DViewer(
                          controller: _controller,
                          src: widget.modelPath,
                          activeGestureInterceptor: false,
                          onLoad: (_) {
                            if (!mounted) return;
                            setState(() {
                              _modelReady = true;
                              _modelFailed = false;
                            });
                            _controller.setCameraOrbit(0, 0, 110);
                          },
                          onError: (_) {
                            if (!mounted) return;
                            setState(() {
                              _modelFailed = true;
                              _modelReady = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Simple top-down car silhouette facing "up" (north) before rotation.
class _TopDownCarPainter extends CustomPainter {
  final Color color;

  _TopDownCarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final body = Paint()..color = color;
    final glass = Paint()..color = Colors.lightBlueAccent.withOpacity(0.85);
    final accent = Paint()..color = Colors.white.withOpacity(0.9);

    // Body (nose toward top)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + size.height * 0.02),
        width: size.width * 0.42,
        height: size.height * 0.72,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(bodyRect, body);

    // Cabin / windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - size.height * 0.02),
          width: size.width * 0.28,
          height: size.height * 0.22,
        ),
        Radius.circular(size.width * 0.04),
      ),
      glass,
    );

    // Nose arrow so facing direction is obvious
    final path = Path()
      ..moveTo(cx, cy - size.height * 0.38)
      ..lineTo(cx - size.width * 0.12, cy - size.height * 0.18)
      ..lineTo(cx + size.width * 0.12, cy - size.height * 0.18)
      ..close();
    canvas.drawPath(path, accent);

    // Wheels
    final wheel = Paint()..color = Colors.black87;
    final w = size.width * 0.1;
    final h = size.height * 0.12;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - size.width * 0.28, cy - size.height * 0.22, w, h),
        const Radius.circular(2),
      ),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + size.width * 0.18, cy - size.height * 0.22, w, h),
        const Radius.circular(2),
      ),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - size.width * 0.28, cy + size.height * 0.12, w, h),
        const Radius.circular(2),
      ),
      wheel,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx + size.width * 0.18, cy + size.height * 0.12, w, h),
        const Radius.circular(2),
      ),
      wheel,
    );
  }

  @override
  bool shouldRepaint(covariant _TopDownCarPainter oldDelegate) =>
      oldDelegate.color != color;
}
