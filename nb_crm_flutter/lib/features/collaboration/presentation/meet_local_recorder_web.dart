import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;
import 'package:livekit_client/livekit_client.dart';
import 'package:web/web.dart' as web;

class MeetLocalRecorder {
  web.MediaRecorder? _recorder;
  web.MediaStream? _displayStream;
  web.AudioContext? _audioCtx;
  web.MediaStreamAudioDestinationNode? _mixDest;
  final Set<String> _attachedTrackIds = {};
  Timer? _audioSyncTimer;
  Room? _room;
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

  void _syncAudioTracks(Room room) {
    final ctx = _audioCtx;
    final mixDest = _mixDest;
    if (ctx == null || mixDest == null) return;

    final tracksToAttach = <web.MediaStreamTrack>[];

    // 1. Host local microphone
    for (final pub in room.localParticipant?.audioTrackPublications ?? const <TrackPublication<AudioTrack>>[]) {
      final media = pub.track?.mediaStreamTrack;
      if (media != null) {
        final js = _asJsTrack(media);
        if (js != null) {
          final trackId = js.id;
          if (!_attachedTrackIds.contains(trackId)) {
            _attachedTrackIds.add(trackId);
            tracksToAttach.add(js);
          }
        }
      }
    }

    // 2. All remote attendees audio tracks
    for (final remote in room.remoteParticipants.values) {
      for (final pub in remote.audioTrackPublications) {
        final media = pub.track?.mediaStreamTrack;
        if (media != null) {
          final js = _asJsTrack(media);
          if (js != null) {
            final trackId = js.id;
            if (!_attachedTrackIds.contains(trackId)) {
              _attachedTrackIds.add(trackId);
              tracksToAttach.add(js);
            }
          }
        }
      }
    }

    // Connect tracks to Web Audio Graph
    for (final jsTrack in tracksToAttach) {
      try {
        final stream = web.MediaStream([jsTrack].toJS);
        final source = ctx.createMediaStreamSource(stream);
        source.connect(mixDest);
      } catch (_) {
        // Track might not be graph-compatible
      }
    }
  }

  web.MediaStreamTrack? _asJsTrack(MediaStreamTrack track) {
    try {
      final raw = (track as dynamic).jsTrack;
      if (raw == null) return null;
      return raw as web.MediaStreamTrack;
    } catch (_) {
      return null;
    }
  }

  Future<void> start({required Room room, required String code}) async {
    if (active) return;
    _chunks.clear();
    _attachedTrackIds.clear();
    _room = room;

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

    _displayStream = stream;

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

    // Setup Web Audio Context and Destination Node for complete mixing
    final ctx = web.AudioContext();
    if (ctx.state == 'suspended') {
      await ctx.resume().toDart;
    }
    final mixDest = ctx.createMediaStreamDestination();
    _audioCtx = ctx;
    _mixDest = mixDest;

    // 1. Tab / Screen audio (if captured by browser)
    final displayAudio = stream.getAudioTracks().toDart;
    if (displayAudio.isNotEmpty) {
      try {
        final firstAudio = displayAudio.first;
        _attachedTrackIds.add(firstAudio.id);
        final tabStream = web.MediaStream([firstAudio].toJS);
        final tabSource = ctx.createMediaStreamSource(tabStream);
        tabSource.connect(mixDest);
      } catch (_) {}
    }

    // 2. Initial sync of all attendees & host mic
    _syncAudioTracks(room);

    // 3. Continuously sync audio for participants joining or unmuting during the meeting
    _audioSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_room != null) _syncAudioTracks(_room!);
    });

    // Combine video from screen capture + complete mixed audio from all participants
    final vTracks = stream.getVideoTracks().toDart;
    final mixedAudioTracks = mixDest.stream.getAudioTracks().toDart;
    final combined = <web.MediaStreamTrack>[
      ...vTracks,
      ...mixedAudioTracks,
    ];
    final recordStream = web.MediaStream(combined.toJS);

    web.MediaRecorder recorder;
    if (_mimeType.isNotEmpty) {
      recorder = web.MediaRecorder(
        recordStream,
        web.MediaRecorderOptions(mimeType: _mimeType),
      );
    } else {
      recorder = web.MediaRecorder(recordStream);
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

    _cleanup();
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
    _cleanup();
    _recorder = null;
    _chunks.clear();
  }

  void _cleanup() {
    _audioSyncTimer?.cancel();
    _audioSyncTimer = null;
    _room = null;
    _attachedTrackIds.clear();

    try {
      _audioCtx?.close();
    } catch (_) {}
    _audioCtx = null;
    _mixDest = null;

    final stream = _displayStream;
    _displayStream = null;
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
