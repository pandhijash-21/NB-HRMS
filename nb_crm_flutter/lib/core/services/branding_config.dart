import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_client.dart';

/// Public branding assets (splash video URL from Cloudinary / DB).
class BrandingConfig {
  BrandingConfig._();

  static String? splashVideoUrl;
  static const _prefsKey = 'nb_crm_splash_video_url';

  static Future<void> hydrateFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null && cached.trim().isNotEmpty) {
      splashVideoUrl = cached.trim();
    }
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
      if (url != null && url.isNotEmpty) {
        splashVideoUrl = url;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, url);
      }
    } catch (_) {
      // Keep cached / asset fallback.
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
