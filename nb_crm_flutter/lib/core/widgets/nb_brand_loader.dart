import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded loader featuring the animated Mr NB GIF for page loading & boot states.
class NbBrandLoader extends StatefulWidget {
  const NbBrandLoader({
    super.key,
    this.statusLines = const <String>[],
    this.size = 140,
    this.isFullScreen = true,
  });

  /// Status lines or messages shown under the loader.
  final List<String> statusLines;

  /// Diameter of the central loader container.
  final double size;

  /// If true, renders a full-screen dark gradient backdrop; otherwise transparent.
  final bool isFullScreen;

  @override
  State<NbBrandLoader> createState() => _NbBrandLoaderState();
}

class _NbBrandLoaderState extends State<NbBrandLoader>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFC5A36A);
  static const _goldLite = Color(0xFFE8C98A);

  late final AnimationController _pulse;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.statusLines.where((s) => s.trim().isNotEmpty).toList();

    Widget loaderCore = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size + 40,
            height: widget.size + 40,
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulse, _spin]),
              builder: (context, _) {
                final pulseScale = 0.94 + (_pulse.value * 0.08);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulsing golden aura
                    Transform.scale(
                      scale: pulseScale,
                      child: Container(
                        width: widget.size + 30,
                        height: widget.size + 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _gold.withValues(alpha: 0.22),
                              _gold.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Rotating golden orbital arc
                    Transform.rotate(
                      angle: _spin.value * math.pi * 2,
                      child: Container(
                        width: widget.size + 14,
                        height: widget.size + 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border(
                            top: const BorderSide(color: _goldLite, width: 2),
                            right: BorderSide(
                              color: _gold.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            bottom: BorderSide(
                              color: _gold.withValues(alpha: 0.1),
                              width: 1,
                            ),
                            left: BorderSide(
                              color: _gold.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Inner circle holding Mr NB GIF
                    Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0F0C09),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.18),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/mrnb_splash.webp',
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                        cacheWidth: 280,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/mr_nb.jpg',
                          fit: BoxFit.contain,
                          cacheWidth: 280,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 18),
            ...lines.map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _goldLite.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.isFullScreen) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF16110C), Color(0xFF000000)],
            radius: 0.85,
          ),
        ),
        child: loaderCore,
      );
    }

    return loaderCore;
  }
}
