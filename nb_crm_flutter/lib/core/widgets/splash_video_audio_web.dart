import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import '../services/branding_config.dart';

@JS('__nbStartSplash')
external void __nbStartSplash(String url);

@JS('__nbAbortSplash')
external void __nbAbortSplash();

@JS('__nbSplashUrl')
external String? get __nbSplashUrl;

void stopSplashPageAudio() {
  try {
    __nbAbortSplash();
  } catch (_) {}
}

void startSplashOverlay() {
  try {
    __nbStartSplash('mrnb.gif');
  } catch (_) {}
}
