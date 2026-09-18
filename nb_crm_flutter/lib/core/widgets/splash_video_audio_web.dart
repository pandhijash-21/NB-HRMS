import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

@JS('__nbStartSplash')
external void __nbStartSplash(String url);

@JS('__nbAbortSplash')
external void __nbAbortSplash();

void stopSplashPageAudio() {
  try {
    __nbAbortSplash();
  } catch (_) {}
}

void startSplashOverlay() {
  var url = 'assets/assets/clips/processed/splash_mr_nb.mp4';
  try {
    url = ui_web.assetManager.getAssetUrl(
      'assets/clips/processed/splash_mr_nb.mp4',
    );
  } catch (_) {}
  try {
    __nbStartSplash(url);
  } catch (_) {}
}
