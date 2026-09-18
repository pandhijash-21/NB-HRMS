import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'mr_nb_tts.dart';

enum MrNbExpression {
  wave('assets/clips/processed/mr_nb_wave.gif'),
  idle('assets/clips/processed/mr_nb_idle.gif'),
  welcome('assets/clips/processed/mr_nb_welcome.gif'),
  pointing('assets/clips/processed/mr_nb_pointing.gif'),
  sideWave('assets/clips/processed/mr_nb_side_wave.gif'),
  thumbsUp('assets/clips/processed/mr_nb_thumbs_up.gif'),
  thinking('assets/clips/processed/mr_nb_thinking.gif');

  final String assetPath;
  const MrNbExpression(this.assetPath);
}

class MrNbNarrationStep {
  final String title;
  final String speechText;
  final MrNbExpression expression;
  final String? audioAsset;

  const MrNbNarrationStep({
    required this.title,
    required this.speechText,
    required this.expression,
    this.audioAsset,
  });
}

/// Service managing Mr. NB's voiceover narration and tour state.
class MrNbTourService {
  MrNbTourService._() {
    _tts = createNbTts(() => _speakGeneration);
  }
  static final MrNbTourService instance = MrNbTourService._();

  final AudioPlayer _audioPlayer = AudioPlayer();
  late final NbTts _tts;

  bool _isInitialized = false;
  bool _isMuted = false;
  int _speakGeneration = 0;

  bool get isMuted => _isMuted;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      await _tts.init();
    } catch (e) {
      debugPrint('MrNbTourService TTS init error: $e');
    }
  }

  /// Call from a pointer/click so browsers allow later speechSynthesis.
  Future<void> unlock() async {
    try {
      await _tts.unlock();
    } catch (_) {}
    unawaited(init());
  }

  void unmute() {
    _isMuted = false;
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      stop();
    }
  }

  /// Start voice immediately (must run from a click, before awaits).
  void beginNarration(MrNbNarrationStep step) {
    if (!_isInitialized) {
      unawaited(init());
    }
    if (_isMuted) return;
    final generation = ++_speakGeneration;
    unawaited(_audioPlayer.stop());
    if (step.audioAsset != null && step.audioAsset!.isNotEmpty) {
      unawaited(_playAsset(step.audioAsset!, generation, step));
      return;
    }
    final spoken = _spokenText(step);
    if (spoken.isEmpty) return;
    _tts.beginSpeak(_splitForSpeech(spoken), generation: generation);
  }

  Future<void> _playAsset(String asset, int generation, MrNbNarrationStep step) async {
    try {
      await _audioPlayer.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Audio asset playback failed, falling back to TTS: $e');
      if (generation != _speakGeneration) return;
      final spoken = _spokenText(step);
      if (spoken.isEmpty) return;
      _tts.beginSpeak(_splitForSpeech(spoken), generation: generation);
    }
  }

  /// Narrates a tour step. Speaks title and every sentence of the card body.
  Future<void> narrateStep(MrNbNarrationStep step) async {
    unawaited(unlock());
    beginNarration(step);
  }

  /// One spoken sentence at a time so Chrome cannot truncate the card.
  List<String> _splitForSpeech(String text) {
    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return [text];
    final chunks = <String>[];
    for (final sentence in sentences) {
      if (sentence.length <= 180) {
        chunks.add(sentence);
        continue;
      }
      final parts = sentence.split(RegExp(r'(?<=[,;:])\s+'));
      final buf = StringBuffer();
      for (final part in parts) {
        if (buf.isNotEmpty && buf.length + part.length > 160) {
          chunks.add(buf.toString().trim());
          buf.clear();
        }
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(part);
      }
      if (buf.isNotEmpty) chunks.add(buf.toString().trim());
    }
    return chunks;
  }

  String _spokenText(MrNbNarrationStep step) {
    final title = _forSpeech(step.title.trim());
    var body = _forSpeech(step.speechText.trim());
    if (body.isEmpty) return title;
    if (title.isEmpty) return body;
    if (body.toLowerCase().startsWith(title.toLowerCase())) return body;
    return '$title. $body';
  }

  /// Expansions so Chrome does not spell abbreviations.
  String _forSpeech(String text) {
    var out = text.replaceAll('—', ', ').replaceAll('–', ', ');
    out = out.replaceAllMapped(
      RegExp(r'\bMr\.?\s+(?=NB\b)', caseSensitive: false),
      (_) => 'Mister ',
    );
    out = out.replaceAllMapped(
      RegExp(r'\bMr\.(?=\s|$)', caseSensitive: false),
      (_) => 'Mister',
    );
    return out;
  }

  Future<void> stop() async {
    _speakGeneration++;
    await _haltPlayback();
  }

  Future<void> _haltPlayback() async {
    try {
      await _audioPlayer.stop();
      await _tts.stop();
    } catch (_) {}
  }

  void dispose() {
    _audioPlayer.dispose();
    _tts.stop();
  }
}
