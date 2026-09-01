import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart';

import 'meet_android_share.dart';

class MeetLocalRecorder {
  MediaRecorder? _recorder;
  LocalVideoTrack? _ownedCapture;
  String? _path;
  String _fileName = 'meeting.mp4';
  bool _preparedAndroid = false;

  bool get active => _recorder != null;

  Future<void> start({required Room room, required String code}) async {
    if (active) return;
    final safeCode = code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    _fileName = 'meeting-$safeCode-$stamp.mp4';

    MediaStreamTrack? videoTrack;
    final existingShare = room.localParticipant?.videoTrackPublications
        .where((p) => p.source == TrackSource.screenShareVideo)
        .map((p) => p.track)
        .whereType<LocalVideoTrack>()
        .firstOrNull;
    if (existingShare != null) {
      videoTrack = existingShare.mediaStreamTrack;
    } else {
      _preparedAndroid = await prepareAndroidScreenShare();
      try {
        final capture = await LocalVideoTrack.createScreenShareTrack(
          const ScreenShareCaptureOptions(maxFrameRate: 15, captureScreenAudio: true),
        );
        _ownedCapture = capture;
        videoTrack = capture.mediaStreamTrack;
      } catch (_) {
        final cam = room.localParticipant?.videoTrackPublications
            .where((p) => p.source == TrackSource.camera)
            .map((p) => p.track)
            .whereType<LocalVideoTrack>()
            .firstOrNull;
        videoTrack = cam?.mediaStreamTrack;
      }
    }
    if (videoTrack == null) {
      throw Exception(
        'Allow screen capture (choose this meeting window) or turn on your camera to record on this device.',
      );
    }

    final path = '${Directory.systemTemp.path}${Platform.pathSeparator}$_fileName';
    final recorder = MediaRecorder();
    try {
      await recorder.start(
        path,
        videoTrack: videoTrack,
        audioChannel: RecorderAudioChannel.OUTPUT,
      );
    } catch (_) {
      await recorder.start(
        path,
        videoTrack: videoTrack,
        audioChannel: RecorderAudioChannel.INPUT,
      );
    }
    _recorder = recorder;
    _path = path;
  }

  Future<String?> stopAndSave() async {
    final recorder = _recorder;
    final path = _path;
    _recorder = null;
    _path = null;
    if (recorder == null || path == null) return null;
    try {
      await recorder.stop();
    } catch (_) {}
    final owned = _ownedCapture;
    _ownedCapture = null;
    if (owned != null) {
      try {
        await owned.stop();
      } catch (_) {}
    }
    if (_preparedAndroid && owned != null) {
      await stopAndroidScreenShare();
    }
    _preparedAndroid = false;

    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Recording file was not created on this device.');
    }
    final bytes = await file.readAsBytes();
    try {
      await file.delete();
    } catch (_) {}
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save meeting recording',
      fileName: _fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'webm'],
    );
    return saved;
  }

  Future<void> discard() async {
    final recorder = _recorder;
    final path = _path;
    _recorder = null;
    _path = null;
    if (recorder != null) {
      try {
        await recorder.stop();
      } catch (_) {}
    }
    final owned = _ownedCapture;
    _ownedCapture = null;
    if (owned != null) {
      try {
        await owned.stop();
      } catch (_) {}
    }
    if (_preparedAndroid && owned != null) {
      await stopAndroidScreenShare();
    }
    _preparedAndroid = false;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}
