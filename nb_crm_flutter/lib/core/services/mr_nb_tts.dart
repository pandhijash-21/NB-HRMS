import 'mr_nb_tts_io.dart' if (dart.library.js_interop) 'mr_nb_tts_web.dart';

abstract class NbTts {
  Future<void> init();
  Future<void> unlock();
  /// Speak [chunks] starting immediately (first utterance must be sync for Chrome).
  void beginSpeak(List<String> chunks, {required int generation});
  Future<void> speakAll(List<String> chunks, {required int generation});
  Future<void> stop();
}

NbTts createNbTts(int Function() generation) => createNbTtsImpl(generation);
