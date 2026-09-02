import 'dart:async';
import 'dart:js_interop';

import 'package:livekit_client/livekit_client.dart';
import 'package:web/web.dart' as web;

class MeetLocalRecorder {
  web.MediaRecorder? _recorder;
  web.MediaStream? _stream;
  final List<web.Blob> _chunks = [];
  String _fileName = 'meeting.webm';
  Completer<void>? _stopCompleter;
  String _mimeType = 'video/webm';

  bool get active => _recorder != null && _recorder!.state != 'inactive';

  String _pickMimeType() {
    const types = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm',
      'video/mp4',
    ];
    for (final t in types) {
      if (web.MediaRecorder.isTypeSupported(t)) {
        return t;
      }
    }
    return '';
  }

  Future<void> start({required Room room, required String code}) async {
    if (active) return;
    _chunks.clear();

    final safeCode = code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    _mimeType = _pickMimeType();
    final ext = _mimeType.contains('mp4') ? 'mp4' : 'webm';
    _fileName = 'meeting-$safeCode-$stamp.$ext';

    web.MediaStream stream;
    try {
      final mediaDevices = web.window.navigator.mediaDevices;
      final displayOptions = web.DisplayMediaStreamOptions(
        video: true.toJS,
        audio: true.toJS,
      );
      final jsPromise = mediaDevices.getDisplayMedia(displayOptions);
      stream = await jsPromise.toDart;
    } catch (e) {
      throw Exception('Screen recording permission was cancelled or not supported: $e');
    }

    _stream = stream;

    // Listen for user stopping screen share from browser banner
    final videoTracks = stream.getVideoTracks().toDart;
    if (videoTracks.isNotEmpty) {
      final firstVideo = videoTracks.first;
      firstVideo.onended = ((web.Event _) {
        if (active) {
          try {
            _recorder?.stop();
          } catch (_) {}
        }
      }).toJS;
    }

    web.MediaRecorder recorder;
    if (_mimeType.isNotEmpty) {
      recorder = web.MediaRecorder(
        stream,
        web.MediaRecorderOptions(mimeType: _mimeType),
      );
    } else {
      recorder = web.MediaRecorder(stream);
    }

    recorder.ondataavailable = ((web.BlobEvent event) {
      if (event.data.size > 0) {
        _chunks.add(event.data);
      }
    }).toJS;

    recorder.onstop = ((web.Event _) {
      _stopCompleter?.complete();
    }).toJS;

    recorder.start(1000);
    _recorder = recorder;
  }

  Future<String?> stopAndSave() async {
    final recorder = _recorder;
    if (recorder == null) return null;

    if (recorder.state != 'inactive') {
      _stopCompleter = Completer<void>();
      recorder.stop();
      await _stopCompleter?.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
    }

    _cleanupStream();
    _recorder = null;

    if (_chunks.isEmpty) {
      return null;
    }

    final jsArray = _chunks.toJS;
    final blob = web.Blob(
      jsArray,
      web.BlobPropertyBag(type: _mimeType.isNotEmpty ? _mimeType : 'video/webm'),
    );
    _chunks.clear();

    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = _fileName;
    anchor.click();

    // Revoke object URL after 30 seconds
    Timer(const Duration(seconds: 30), () {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    });

    return 'Saved $_fileName to Downloads';
  }

  Future<void> discard() async {
    final recorder = _recorder;
    if (recorder != null) {
      try {
        if (recorder.state != 'inactive') recorder.stop();
      } catch (_) {}
    }
    _cleanupStream();
    _recorder = null;
    _chunks.clear();
  }

  void _cleanupStream() {
    final stream = _stream;
    _stream = null;
    if (stream != null) {
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        try {
          track.stop();
        } catch (_) {}
      }
    }
  }
}
