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
  String? url = BrandingConfig.splashVideoUrl?.trim();
  if (url == null || !url.startsWith('http')) {
    try {
      final prefetched = __nbSplashUrl?.trim();
      if (prefetched != null && prefetched.startsWith('http')) {
        url = prefetched;
      }
    } catch (_) {}
  }

  late final String resolved;
  if (url != null && url.startsWith('http')) {
    resolved = BrandingConfig.leanCloudinaryUrl(url);
  } else {
    var assetUrl = 'assets/assets/clips/processed/splash_mr_nb.mp4';
    try {
      assetUrl = ui_web.assetManager.getAssetUrl(
        'assets/clips/processed/splash_mr_nb.mp4',
      );
    } catch (_) {}
    resolved = assetUrl;
  }

  try {
    __nbStartSplash(resolved);
  } catch (_) {}
}
