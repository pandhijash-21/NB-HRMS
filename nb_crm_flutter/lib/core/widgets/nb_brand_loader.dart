import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Branded full-screen loader used on splash and while the app boots.
class NbBrandLoader extends StatefulWidget {
  const NbBrandLoader({super.key});

  @override
  State<NbBrandLoader> createState() => _NbBrandLoaderState();
}

class _NbBrandLoaderState extends State<NbBrandLoader>
    with TickerProviderStateMixin {
  static const _gold = Color(0xFFC5A36A);
  static const _goldLite = Color(0xFFE8C98A);

  late final AnimationController _spin;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF16110C), Color(0xFF000000)],
          radius: 0.85,
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 168,
          height: 168,
          child: AnimatedBuilder(
            animation: Listenable.merge([_spin, _pulse]),
            builder: (context, _) {
              final pulse = 0.82 + (_pulse.value * 0.18);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _gold.withValues(alpha: 0.28),
                            _gold.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.55, 1],
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: _spin.value * math.pi * 2,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border(
                          top: const BorderSide(color: _goldLite, width: 1.6),
                          right: BorderSide(
                            color: _gold.withValues(alpha: 0.55),
                            width: 1.6,
                          ),
                          bottom: BorderSide(
                            color: _gold.withValues(alpha: 0.16),
                            width: 1.6,
                          ),
                          left: BorderSide(
                            color: _gold.withValues(alpha: 0.16),
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -_spin.value * math.pi * 1.14,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _gold.withValues(alpha: 0.28),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: _spin.value * math.pi * 2,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _goldLite,
                          boxShadow: [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.9),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 84,
                      height: 84,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2A2218), Color(0xFF0C0C0C)],
                        ),
                        border: Border.all(
                          color: _gold.withValues(alpha: 0.35),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.22),
                            blurRadius: 28,
                          ),
                        ],
                      ),
                      child: const Text(
                        'NB',
                        style: TextStyle(
                          color: _goldLite,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                          fontFamily: 'serif',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
