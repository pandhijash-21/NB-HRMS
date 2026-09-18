import 'package:flutter/material.dart';

/// Web splash is a page-level HTML overlay (`web/index.html`), not a
/// Flutter platform view. Platform views punch a hole through the canvas
/// and let the login route show through.
Widget buildSplashVideoSurface({
  required String asset,
  required VoidCallback onEnded,
  required VoidCallback onPlaying,
  required ValueChanged<int> onProgress,
}) {
  return const ColoredBox(color: Colors.black);
}
