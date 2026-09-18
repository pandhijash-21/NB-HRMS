import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'mascot_clip_registry.dart';

class MascotPresenter extends StatefulWidget {
  const MascotPresenter({
    super.key,
    required this.clip,
    this.size = 168,
    this.muted = true,
  });

  final MascotClip clip;
  final double size;
  final bool muted;

  @override
  State<MascotPresenter> createState() => _MascotPresenterState();
}

class _MascotPresenterState extends State<MascotPresenter> {
  VideoPlayerController? _controller;
  bool _useGif = kIsWeb;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant MascotPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id) {
      _disposeController();
      _useGif = kIsWeb;
      if (!kIsWeb) _initVideo();
    } else if (oldWidget.muted != widget.muted) {
      _controller?.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(widget.clip.mp4);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0 : 1);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      _disposeController();
      if (mounted) setState(() => _useGif = true);
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    Widget media;
    final ctrl = _controller;
    if (!_useGif && ctrl != null && ctrl.value.isInitialized) {
      media = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      );
    } else {
      media = Image.asset(
        widget.clip.gif,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Color(0xFFC5A36A), size: 56),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: media,
        ),
      ),
    );
  }
}
