import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:livekit_client/livekit_client.dart';
import 'package:record/record.dart';

import '../data/meet_repository.dart';
import 'stt_chunk_io.dart' if (dart.library.js_interop) 'stt_chunk_web.dart';
import 'stt_livekit_tap.dart';

class MeetBhashiniStt {
  MeetBhashiniStt({required MeetRepository repo}) : _repo = repo;

  final MeetRepository _repo;
  final LivekitWebSttTap _webTap = LivekitWebSttTap();
  final AudioRecorder? _recorder = LivekitWebSttTap.supported ? null : AudioRecorder();
  Timer? _timer;
  Timer? _retry;
  DateTime? _chunkStarted;
  bool _micOn = true;
  bool _running = false;
  String _meetingId = '';
  String _language = 'en';
  String? _bearer;
  String? _path;
  Room? _room;

  Future<void> start({
    required String meetingId,
    String language = 'en',
    String? bearer,
    Room? room,
  }) async {
    await stop();
    _meetingId = meetingId;
    _language = language;
    _bearer = bearer;
    _room = room;
    _running = true;
    _micOn = true;
    if (LivekitWebSttTap.supported) {
      if (room != null) _webTap.attach(room, micOn: true);
      if (!_webTap.attached) _scheduleRetry();
      _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
        unawaited(_flushWeb());
      });
      return;
    }
    final recorder = _recorder;
    if (recorder == null) return;
    final allowed = await recorder.hasPermission();
    if (!allowed) return;
    await _beginChunk();
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      unawaited(_rotate());
    });
  }

  void attach(Room room) {
    _room = room;
    if (!_running || !_micOn) return;
    if (LivekitWebSttTap.supported) {
      _webTap.attach(room, micOn: true);
      return;
    }
    unawaited(_beginChunk());
  }

  void setLanguage(String language) => _language = language;

  void setMicEnabled(bool on) {
    _micOn = on;
    _webTap.setMicEnabled(on);
    if (!on) {
      if (LivekitWebSttTap.supported) {
        unawaited(_flushWeb());
      } else {
        unawaited(_rotate());
      }
      return;
    }
    if (_room != null) attach(_room!);
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _retry?.cancel();
    _retry = null;
    if (LivekitWebSttTap.supported) {
      await _flushWeb();
      _webTap.stop();
    } else {
      await _rotate();
    }
    _room = null;
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _recorder?.dispose();
    } catch (_) {}
  }

  RecordConfig get _config => const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
          audioManagerMode: AudioManagerMode.modeNormal,
          manageBluetooth: false,
          useLegacy: true,
        ),
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.mixWithOthers,
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
          ],
          manageAudioSession: false,
        ),
      );

  Future<void> _beginChunk() async {
    final recorder = _recorder;
    if (!_running || !_micOn || recorder == null) return;
    try {
      if (await recorder.isRecording()) return;
      final livekitHasMic = _room?.localParticipant?.audioTrackPublications.any(
            (p) => p.source == TrackSource.microphone && !p.muted && p.track != null,
          ) ??
          false;
      if (_room != null && !livekitHasMic) {
        _scheduleRetry();
        return;
      }
      _path = sttChunkPath();
      await recorder.start(_config, path: _path ?? 'meet-stt.wav');
      _chunkStarted = DateTime.now();
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (!_running || _retry?.isActive == true) return;
    _retry = Timer(const Duration(milliseconds: 900), () {
      if (_running && _micOn) {
        if (LivekitWebSttTap.supported && _room != null) {
          _webTap.attach(_room!, micOn: true);
        } else {
          unawaited(_beginChunk());
        }
      }
    });
  }

  Future<void> _flushWeb() async {
    if (_running && _micOn && _room != null) {
      _webTap.attach(_room!, micOn: true);
    }
    final chunk = _webTap.takeChunk();
    if (chunk == null) return;
    try {
      await _repo.ingestTranscriptChunk(
        _meetingId,
        audioBase64: base64Encode(chunk.bytes),
        language: _language,
        startedAt: chunk.started,
        endedAt: chunk.ended,
        bearer: _bearer,
      );
    } catch (_) {}
  }

  Future<void> _rotate() async {
    final recorder = _recorder;
    Uint8List? bytes;
    final started = _chunkStarted;
    try {
      if (recorder != null && await recorder.isRecording()) {
        final stopped = await recorder.stop();
        final location = stopped ?? _path;
        if (location != null) bytes = await readSttChunk(location);
      }
    } catch (_) {}
    _chunkStarted = null;
    _path = null;
    if (_running && _micOn) await _beginChunk();
    if (bytes == null || bytes.length < 128 || started == null) return;
    try {
      await _repo.ingestTranscriptChunk(
        _meetingId,
        audioBase64: base64Encode(bytes),
        language: _language,
        startedAt: started,
        endedAt: DateTime.now(),
        bearer: _bearer,
      );
    } catch (_) {}
  }
}
