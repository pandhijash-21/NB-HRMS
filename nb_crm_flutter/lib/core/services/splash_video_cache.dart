import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps a local copy of the Cloudinary splash for instant replays.
class SplashVideoCache {
  SplashVideoCache._();

  static const _prefsUrlKey = 'nb_crm_splash_cached_url';
  static const _prefsPathKey = 'nb_crm_splash_cached_path';

  /// Returns a local file path if already cached for [remoteUrl], else null.
  static Future<String?> cachedFilePath(String remoteUrl) async {
    if (kIsWeb) return null;
    final source = remoteUrl.trim();
    if (!source.startsWith('http')) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString(_prefsUrlKey);
      final cachedPath = prefs.getString(_prefsPathKey);
      if (cachedUrl == source &&
          cachedPath != null &&
          cachedPath.isNotEmpty &&
          File(cachedPath).existsSync() &&
          File(cachedPath).lengthSync() > 50_000) {
        return cachedPath;
      }
    } catch (_) {}
    return null;
  }

  /// Download in background so the *next* cold start is instant.
  static Future<void> prefetch(String? remoteUrl) async {
    final url = remoteUrl?.trim();
    if (url == null || !url.startsWith('http') || kIsWeb) return;
    try {
      if (await cachedFilePath(url) != null) return;
      final dir = Directory('${Directory.systemTemp.path}/nb_crm_splash');
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/splash_mr_nb.mp4');
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 45));
      if (res.statusCode < 200 || res.statusCode >= 300 || res.bodyBytes.isEmpty) {
        return;
      }
      await file.writeAsBytes(res.bodyBytes, flush: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsUrlKey, url);
      await prefs.setString(_prefsPathKey, file.path);
    } catch (_) {}
  }
}
