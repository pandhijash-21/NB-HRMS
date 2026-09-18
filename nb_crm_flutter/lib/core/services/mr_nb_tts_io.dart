import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'mr_nb_tts.dart';

NbTts createNbTtsImpl(int Function() generation) => _IoNbTts(generation);

class _IoNbTts implements NbTts {
  _IoNbTts(this._generation);

  final int Function() _generation;
  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  @override
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.08);
      await _tts.setVolume(1);
    } catch (_) {}
  }

  @override
  Future<void> unlock() async {
    await init();
  }

  @override
  void beginSpeak(List<String> chunks, {required int generation}) {
    unawaited(speakAll(chunks, generation: generation));
  }

  @override
  Future<void> speakAll(List<String> chunks, {required int generation}) async {
    await init();
    try {
      await _tts.stop();
    } catch (_) {}
    await _tts.setVolume(1);
    for (final chunk in chunks) {
      if (generation != _generation() || chunk.trim().isEmpty) return;
      try {
        await _tts.speak(chunk);
      } catch (_) {
        return;
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
