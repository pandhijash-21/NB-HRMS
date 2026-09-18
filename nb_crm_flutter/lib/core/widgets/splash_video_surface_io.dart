import 'dart:async';

import 'splash_video_audio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildSplashVideoSurface({
  required String asset,
  required VoidCallback onEnded,
  required VoidCallback onPlaying,
  required ValueChanged<int> onProgress,
}) {
  return _IoSplashVideo(
    asset: asset,
    onEnded: onEnded,
    onPlaying: onPlaying,
    onProgress: onProgress,
  );
}

class _IoSplashVideo extends StatefulWidget {
  const _IoSplashVideo({
    required this.asset,
    required this.onEnded,
    required this.onPlaying,
    required this.onProgress,
  });

  final String asset;
  final VoidCallback onEnded;
  final VoidCallback onPlaying;
  final ValueChanged<int> onProgress;

  @override
  State<_IoSplashVideo> createState() => _IoSplashVideoState();
}

class _IoSplashVideoState extends State<_IoSplashVideo> {
  VideoPlayerController? _controller;
  bool _ended = false;
  bool _playingSignaled = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    widget.onProgress(1);
    var fake = 1;
    final tick = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (fake >= 88) return;
      fake += 2;
      widget.onProgress(fake);
    });
    try {
      final controller = VideoPlayerController.asset(
        widget.asset,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = controller;
      await controller.initialize();
      tick.cancel();
      if (!mounted) return;
      widget.onProgress(100);
      await controller.setLooping(false);
      await controller.setVolume(0);
      SplashVideoAudio.applyMute = (muted) {
        unawaited(controller.setVolume(muted ? 0 : 1));
      };
      controller.addListener(_onTick);
      await controller.play();
      if (!mounted) return;
      setState(() => _visible = true);
      if (!_playingSignaled) {
        _playingSignaled = true;
        widget.onPlaying();
      }
    } catch (e) {
      tick.cancel();
      debugPrint('Splash video failed: $e');
      widget.onProgress(100);
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized || _ended) return;
    final duration = value.duration;
    if (duration < const Duration(milliseconds: 500)) return;
    if (value.position < const Duration(milliseconds: 300)) return;
    final ended = value.isCompleted ||
        value.position >= duration - const Duration(milliseconds: 120);
    if (ended && !value.isPlaying) {
      _ended = true;
      widget.onEnded();
    }
  }

  @override
  void dispose() {
    SplashVideoAudio.applyMute = null;
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = _visible &&
        controller != null &&
        controller.value.isInitialized &&
        controller.value.size.width > 0;
    if (!ready) return const SizedBox.expand();
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
