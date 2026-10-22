import 'dart:async';

import 'package:flutter/material.dart';

import '../app_version.dart';
import '../services/location_access_gate.dart';

/// Full-screen branded splash displaying the Mr NB GIF animation.
class SplashVideoHost extends StatefulWidget {
  const SplashVideoHost({
    super.key,
    this.isReady = false,
    this.onDismissed,
  });

  static const gifAsset = 'assets/images/mrnb.gif';

  /// If true, signals that the underlying page is ready and triggers smooth fadeout.
  /// If false, the loader animation keeps looping continuously.
  final bool isReady;
  final VoidCallback? onDismissed;

  @override
  State<SplashVideoHost> createState() => _SplashVideoHostState();
}

class _SplashVideoHostState extends State<SplashVideoHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
    );

    // Warm location permissions gate quietly in background
    unawaited(LocationAccessGate.requestPermissionPrompt());

    if (widget.isReady) {
      _finish();
    }
  }

  @override
  void didUpdateWidget(SplashVideoHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isReady && !oldWidget.isReady) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (_done || !mounted) return;
    _done = true;
    await _fade.reverse();
    if (mounted) {
      setState(() {});
      widget.onDismissed?.call();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done && _fade.isDismissed) {
      return const SizedBox.shrink();
    }

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.black,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Subtle luxury background gradient
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: [
                      Color(0xFF1A140E),
                      Color(0xFF090705),
                      Colors.black,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // Centered Mr NB GIF
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: 360,
                        maxHeight: 360,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        SplashVideoHost.gifAsset,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Welcome to NB Group',
                      style: TextStyle(
                        color: Color(0xFFE8C98A),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontFamily: 'serif',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real Estate & Financial Services',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              // Version watermark (bottom-left)
              Positioned(
                left: 20,
                bottom: 24 + bottomPadding,
                child: Text(
                  'v$kAppVersion',
                  style: const TextStyle(
                    color: Color(0x8AFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // Skip button (bottom-right)
              Positioned(
                right: 20,
                bottom: 20 + bottomPadding,
                child: TextButton.icon(
                  onPressed: _finish,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Skip'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
