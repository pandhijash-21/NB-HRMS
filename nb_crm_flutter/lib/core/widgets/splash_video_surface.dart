import 'splash_video_surface_io.dart'
    if (dart.library.js_interop) 'splash_video_surface_web.dart';

import 'package:flutter/material.dart';

/// Platform video for the splash clip (HTML &lt;video&gt; on web, video_player elsewhere).
class SplashVideoSurface extends StatelessWidget {
  const SplashVideoSurface({
    super.key,
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
  Widget build(BuildContext context) {
    return buildSplashVideoSurface(
      asset: asset,
      onEnded: onEnded,
      onPlaying: onPlaying,
      onProgress: onProgress,
    );
  }
}
