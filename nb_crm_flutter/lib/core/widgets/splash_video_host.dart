import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../services/branding_config.dart';
import 'nb_brand_loader.dart';
import 'splash_video_audio.dart';
import 'splash_video_surface.dart';

/// Full-screen branded splash. Parent should mount this only when logged out.
class SplashVideoHost extends StatefulWidget {
  const SplashVideoHost({super.key});

  static const assetFallback = 'assets/clips/processed/splash_mr_nb.mp4';

  @override
  State<SplashVideoHost> createState() => _SplashVideoHostState();
}

class _SplashVideoHostState extends State<SplashVideoHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  bool _done = false;
  bool _playing = false;
  bool _showSkip = false;
  bool _muted = true;
  int _progress = 0;
  String _status = 'Preparing Mr NB…';
  Timer? _skipTimer;
  Timer? _failSafe;
  Timer? _statusTicker;
  int _statusIndex = 0;

  static const _statusCycle = [
    'Preparing Mr NB…',
    'Fetching splash media…',
    'Buffering video…',
    'Almost ready…',
  ];

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
    _skipTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && !_done) setState(() => _showSkip = true);
    });
    // Cached/local splash should fail fast; first remote download gets a bit more room.
    final failSeconds = BrandingConfig.hasRemoteSplash ? 18 : 12;
    _failSafe = Timer(Duration(seconds: failSeconds), _finish);
    _statusTicker = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted || _playing || _done) return;
      setState(() {
        _statusIndex = (_statusIndex + 1) % _statusCycle.length;
        _status = _statusCycle[_statusIndex];
      });
    });
  }

  void _afterFrame(VoidCallback fn) {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      if (mounted) fn();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fn();
    });
  }

  void _markPlaying() {
    _afterFrame(() {
      if (!mounted || _playing) return;
      setState(() {
        _playing = true;
        _status = 'Playing…';
        _progress = 100;
      });
    });
  }

  void _onProgress(int pct) {
    _afterFrame(() {
      if (!mounted || _playing || _done) return;
      setState(() {
        _progress = pct.clamp(0, 100);
        if (pct < 25) {
          _status = BrandingConfig.hasRemoteSplash
              ? 'Fetching splash from cloud…'
              : 'Loading splash media…';
        } else if (pct < 70) {
          _status = 'Buffering video…';
        } else {
          _status = 'Almost ready…';
        }
      });
    });
  }

  Future<void> _finish() async {
    if (_done || !mounted) return;
    _done = true;
    _skipTimer?.cancel();
    _failSafe?.cancel();
    _statusTicker?.cancel();
    SplashVideoAudio.stop();
    await _fade.reverse();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _failSafe?.cancel();
    _statusTicker?.cancel();
    SplashVideoAudio.stop();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done && _fade.isDismissed) {
      return const SizedBox.shrink();
    }

    final source = BrandingConfig.resolveSplashSource();

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.black,
        child: SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              SplashVideoSurface(
                key: ValueKey('splash-mr-nb-$source'),
                asset: source,
                onEnded: _finish,
                onPlaying: _markPlaying,
                onProgress: _onProgress,
              ),
              if (!_playing)
                NbBrandLoader(
                  statusLines: [
                    _status,
                    if (_progress > 0 && _progress < 100) '$_progress%',
                  ],
                ),
              if (_showSkip)
                Positioned(
                  right: 20,
                  bottom: 24 + MediaQuery.paddingOf(context).bottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Material(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: _muted ? 'Unmute' : 'Mute',
                          color: Colors.white,
                          onPressed: () {
                            setState(() => _muted = !_muted);
                            SplashVideoAudio.applyMute?.call(_muted);
                          },
                          icon: Icon(
                            _muted ? Icons.volume_off : Icons.volume_up,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black.withValues(alpha: 0.45),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
