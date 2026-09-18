import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'mr_nb_tts.dart';

NbTts createNbTtsImpl(int Function() generation) => _WebNbTts(generation);

class _WebNbTts implements NbTts {
  _WebNbTts(this._generation);

  final int Function() _generation;
  final _liveUtterances = <web.SpeechSynthesisUtterance>[];
  Timer? _resumeWatch;
  bool _inited = false;
  int _token = 0;

  web.SpeechSynthesis get _synth => web.window.speechSynthesis;

  @override
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    try {
      _synth.getVoices();
      web.window.speechSynthesis.addEventListener(
        'voiceschanged',
        (web.Event _) {
          try {
            _synth.getVoices();
          } catch (_) {}
        }.toJS,
      );
    } catch (_) {}
  }

  @override
  Future<void> unlock() async {
    // Resume only — never speak a dummy utterance here. A queued "." after
    // the real line either delays the tour voice or replaces it in Chrome.
    try {
      _synth.getVoices();
      _synth.resume();
    } catch (_) {}
    unawaited(init());
  }

  @override
  void beginSpeak(List<String> chunks, {required int generation}) {
    unawaited(init());
    _stopResumeWatch();
    _token++;
    final token = _token;
    try {
      _synth.resume();
    } catch (_) {}
    try {
      if (_synth.speaking || _synth.pending) {
        _synth.pause();
        _synth.cancel();
        _synth.resume();
      }
    } catch (_) {}
    if (chunks.isEmpty) return;
    _startResumeWatch();
    _speakChunk(chunks, 0, generation, token);
  }

  @override
  Future<void> speakAll(List<String> chunks, {required int generation}) async {
    beginSpeak(chunks, generation: generation);
    if (chunks.isEmpty) return;
    final words = chunks.join(' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final timeoutMs = (words * 520 + 1800).clamp(1800, 60000);
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (DateTime.now().isBefore(deadline) && generation == _generation()) {
      try {
        if (!_synth.speaking && !_synth.pending) break;
      } catch (_) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  void _speakChunk(List<String> chunks, int index, int generation, int token) {
    if (token != _token || generation != _generation()) return;
    if (index >= chunks.length) return;
    final text = chunks[index].trim();
    if (text.isEmpty) {
      _speakChunk(chunks, index + 1, generation, token);
      return;
    }
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = 'en-US'
      ..rate = 0.92
      ..pitch = 1.04
      ..volume = 1;
    _applyEnglishVoice(utterance);
    utterance.addEventListener(
      'end',
      (web.Event _) {
        if (token != _token || generation != _generation()) return;
        _speakChunk(chunks, index + 1, generation, token);
      }.toJS,
    );
    _liveUtterances.add(utterance);
    if (_liveUtterances.length > 12) {
      _liveUtterances.removeRange(0, _liveUtterances.length - 12);
    }
    try {
      _synth.resume();
      _synth.speak(utterance);
    } catch (_) {}
  }

  void _applyEnglishVoice(web.SpeechSynthesisUtterance utterance) {
    try {
      final voices = _synth.getVoices().toDart;
      web.SpeechSynthesisVoice? pick;
      for (final voice in voices) {
        final lang = voice.lang.toLowerCase();
        final name = voice.name.toLowerCase();
        if (lang.startsWith('en-us') && name.contains('female')) {
          pick = voice;
          break;
        }
        pick ??= lang.startsWith('en-us') ? voice : pick;
        pick ??= lang.startsWith('en') ? voice : pick;
      }
      if (pick != null) utterance.voice = pick;
    } catch (_) {}
  }

  void _startResumeWatch() {
    _resumeWatch?.cancel();
    _resumeWatch = Timer.periodic(const Duration(milliseconds: 280), (_) {
      try {
        if (_synth.paused) _synth.resume();
      } catch (_) {}
    });
  }

  void _stopResumeWatch() {
    _resumeWatch?.cancel();
    _resumeWatch = null;
  }

  @override
  Future<void> stop() async {
    _token++;
    _stopResumeWatch();
    try {
      _synth.cancel();
    } catch (_) {}
    _liveUtterances.clear();
  }
}
