import 'splash_video_audio_stub.dart'
    if (dart.library.js_interop) 'splash_video_audio_web.dart';

class SplashVideoAudio {
  static void Function(bool muted)? applyMute;

  static void stop() => stopSplashPageAudio();

  static void startLoggedOut() => startSplashOverlay();
}
