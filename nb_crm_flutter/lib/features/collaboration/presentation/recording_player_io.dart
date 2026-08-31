import 'package:flutter/material.dart';

import '../../../core/utils/open_url.dart';

Widget meetingRecordingPlayer(String url) {
  return ColoredBox(
    color: const Color(0xFF0B0B0B),
    child: Center(
      child: FilledButton.icon(
        onPressed: () => openExternalUrl(url),
        icon: const Icon(Icons.play_circle_rounded),
        label: const Text('Open recording'),
      ),
    ),
  );
}
