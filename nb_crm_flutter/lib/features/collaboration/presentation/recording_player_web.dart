import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget meetingRecordingPlayer(String url) => _WebRecordingPlayer(url: url);

class _WebRecordingPlayer extends StatefulWidget {
  const _WebRecordingPlayer({required this.url});
  final String url;

  @override
  State<_WebRecordingPlayer> createState() => _WebRecordingPlayerState();
}

class _WebRecordingPlayerState extends State<_WebRecordingPlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'meet-rec-${identityHashCode(this)}-${widget.url.hashCode}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = web.HTMLVideoElement()
        ..src = widget.url
        ..controls = true
        ..autoplay = false
        ..preload = 'metadata';
      video.setAttribute('playsinline', 'true');
      video.setAttribute('controlsList', 'nodownload');
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain'
        ..backgroundColor = '#0B0B0B'
        ..border = '0'
        ..display = 'block';
      return video;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B0B0B),
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
