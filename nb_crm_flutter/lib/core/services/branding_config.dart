import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';

/// Public branding assets (splash video URL from Cloudinary / DB).
class BrandingConfig {
  BrandingConfig._();

  static String? splashVideoUrl;
  static String minVersion = '';
  static String maxVersion = '';
  static String updateUrlWeb = '';
  static String updateUrlAndroid = '';
  static String updateUrlIos = '';
  static const _prefsKey = 'nb_crm_splash_video_url';
  static const _minKey = 'nb_crm_min_version';
  static const _maxKey = 'nb_crm_max_version';
  static const _webKey = 'nb_crm_update_url_web';
  static const _androidKey = 'nb_crm_update_url_android';
  static const _iosKey = 'nb_crm_update_url_ios';

  static Future<void> hydrateFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null && cached.trim().isNotEmpty) {
      splashVideoUrl = cached.trim();
    }
    minVersion = prefs.getString(_minKey)?.trim() ?? '';
    maxVersion = prefs.getString(_maxKey)?.trim() ?? '';
    updateUrlWeb = prefs.getString(_webKey)?.trim() ?? '';
    updateUrlAndroid = prefs.getString(_androidKey)?.trim() ?? '';
    updateUrlIos = prefs.getString(_iosKey)?.trim() ?? '';
  }

  static Future<void> fetch(DioClient dio) async {
    try {
      final data = await dio.getEnvelope<Map<String, dynamic>>(
        'auth/branding',
        parse: (raw) {
          if (raw is Map) return Map<String, dynamic>.from(raw);
          return <String, dynamic>{};
        },
      );
      final url = data['splashVideoUrl']?.toString().trim();
      minVersion = data['minVersion']?.toString().trim() ?? '';
      maxVersion = data['maxVersion']?.toString().trim() ?? '';
      updateUrlWeb = data['updateUrlWeb']?.toString().trim() ?? '';
      updateUrlAndroid = data['updateUrlAndroid']?.toString().trim() ?? '';
      updateUrlIos = data['updateUrlIos']?.toString().trim() ?? '';
      final prefs = await SharedPreferences.getInstance();
      if (url != null && url.isNotEmpty) {
        splashVideoUrl = url;
        await prefs.setString(_prefsKey, url);
      }
      await prefs.setString(_minKey, minVersion);
      await prefs.setString(_maxKey, maxVersion);
      await prefs.setString(_webKey, updateUrlWeb);
      await prefs.setString(_androidKey, updateUrlAndroid);
      await prefs.setString(_iosKey, updateUrlIos);
    } catch (_) {
      // Keep cached / asset fallback.
    }
  }

  /// Link for the app that is running: web, Android, or iOS.
  static String updateLinkForThisDevice() {
    if (kIsWeb) return updateUrlWeb.trim();
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return updateUrlIos.trim();
      case TargetPlatform.android:
        return updateUrlAndroid.trim();
      default:
        return updateUrlWeb.trim();
    }
  }

  /// Prefer remote Cloudinary URL; fall back to bundled asset path.
  static String resolveSplashSource() {
    final remote = splashVideoUrl?.trim();
    if (remote != null && remote.startsWith('http')) {
      return leanCloudinaryUrl(remote);
    }
    return 'assets/clips/processed/splash_mr_nb.mp4';
  }

  /// Prefer a smaller/faster Cloudinary delivery for cold start.
  static String leanCloudinaryUrl(String url) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) {
      return url;
    }
    // Replace any existing transformation segment after /upload/.
    return url.replaceFirst(
      RegExp(r'/upload/[^/]*(?=/v\d+/|/[^/]+/)'),
      '/upload/w_960,c_limit,q_auto:eco,f_mp4,vc_auto',
    );
  }

  static bool get hasRemoteSplash {
    final remote = splashVideoUrl?.trim();
    return remote != null && remote.startsWith('http');
  }
}
