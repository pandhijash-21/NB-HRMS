import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStreamTrack;
import 'package:livekit_client/livekit_client.dart';
import 'package:web/web.dart' as web;

class LivekitWebSttTap {
  static const supported = true;

  web.AudioContext? _ctx;
  web.MediaStreamAudioSourceNode? _source;
  web.ScriptProcessorNode? _processor;
  web.GainNode? _mute;
  final _pending = <Float32List>[];
  int _pendingSamples = 0;
  double _nativeRate = 48000;
  String? _boundId;
  DateTime? _chunkStarted;
  bool _micOn = true;

  DateTime? get chunkStarted => _chunkStarted;

  bool get attached => _processor != null;

  void attach(Room room, {required bool micOn}) {
    _micOn = micOn;
    if (!micOn) return;
    final pub = room.localParticipant?.getTrackPublicationBySource(TrackSource.microphone);
    final track = pub?.track;
    final media = track?.mediaStreamTrack;
    if (media == null || pub!.muted) return;
    final id = media.id;
    if (id != null && id == _boundId && _processor != null) return;
    _bind(media);
  }

  void setMicEnabled(bool on) {
    _micOn = on;
  }

  void stop() {
    _teardown();
    _pending.clear();
    _pendingSamples = 0;
    _chunkStarted = null;
  }

  ({Uint8List bytes, DateTime started, DateTime ended})? takeChunk() {
    if (_pendingSamples < _nativeRate * 0.6 || _chunkStarted == null) {
      return null;
    }
    final chunks = List<Float32List>.from(_pending);
    final started = _chunkStarted!;
    _pending.clear();
    _pendingSamples = 0;
    _chunkStarted = null;
    var total = 0;
    for (final c in chunks) {
      total += c.length;
    }
    final merged = Float32List(total);
    var offset = 0;
    for (final c in chunks) {
      merged.setAll(offset, c);
      offset += c.length;
    }
    final pcm = _downsample(merged, _nativeRate, 16000);
    if (_rms(pcm) < 0.01) return null;
    return (bytes: _encodeWav(pcm, 16000), started: started, ended: DateTime.now());
  }

  void _bind(MediaStreamTrack track) {
    _teardown();
    final jsTrack = _asJsTrack(track);
    if (jsTrack == null) return;
    final ctx = web.AudioContext();
    _ctx = ctx;
    _nativeRate = ctx.sampleRate;
    final stream = web.MediaStream([jsTrack].toJS);
    final source = ctx.createMediaStreamSource(stream);
    final processor = ctx.createScriptProcessor(4096, 1, 1);
    processor.onaudioprocess = ((web.Event event) {
      if (!_micOn) return;
      final e = event as web.AudioProcessingEvent;
      final src = e.inputBuffer.getChannelData(0).toDart;
      _pending.add(Float32List.fromList(src));
      _pendingSamples += src.length;
      _chunkStarted ??= DateTime.now();
    }).toJS;
    final mute = ctx.createGain();
    mute.gain.value = 0;
    source.connect(processor);
    processor.connect(mute);
    mute.connect(ctx.destination);
    _source = source;
    _processor = processor;
    _mute = mute;
    _boundId = track.id;
    if (ctx.state == 'suspended') {
      ctx.resume();
    }
  }

  void _teardown() {
    try {
      _processor?.disconnect();
      _source?.disconnect();
      _mute?.disconnect();
    } catch (_) {}
    _processor = null;
    _source = null;
    _mute = null;
    _boundId = null;
    final ctx = _ctx;
    _ctx = null;
    if (ctx != null && ctx.state != 'closed') {
      ctx.close();
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
}

Float32List _downsample(Float32List input, double fromRate, int toRate) {
  if (fromRate == toRate) return input;
  final ratio = fromRate / toRate;
  final out = Float32List((input.length / ratio).floor().clamp(1, input.length));
  for (var i = 0; i < out.length; i++) {
    final src = (i * ratio).floor().clamp(0, input.length - 1);
    out[i] = input[src];
  }
  return out;
}

double _rms(Float32List samples) {
  if (samples.isEmpty) return 0;
  var sum = 0.0;
  for (final s in samples) {
    sum += s * s;
  }
  return math.sqrt(sum / samples.length);
}

Uint8List _encodeWav(Float32List samples, int sampleRate) {
  final bytes = ByteData(44 + samples.length * 2);
  void writeStr(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      bytes.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  writeStr(0, 'RIFF');
  bytes.setUint32(4, 36 + samples.length * 2, Endian.little);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeStr(36, 'data');
  bytes.setUint32(40, samples.length * 2, Endian.little);
  var offset = 44;
  for (var i = 0; i < samples.length; i++, offset += 2) {
    final s = samples[i].clamp(-1.0, 1.0);
    bytes.setInt16(offset, s < 0 ? (s * 0x8000).round() : (s * 0x7fff).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}
