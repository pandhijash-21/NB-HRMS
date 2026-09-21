import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Application configuration from compile-time `--dart-define` values.
class AppConfig {
  AppConfig._();

  static const _prefsKey = 'nb_crm_api_base_url';
  /// Always mirrored for the background tracking isolate (release + debug).
  static const bgApiPrefsKey = 'nb_crm_bg_api_base_url';

  static String? _runtimeOverride;

  static void setApiBaseUrl(String? url) {
    if (kReleaseMode) return;
    _runtimeOverride = url;
  }

  static Future<void> persistApiBaseUrl(String url) async {
    if (kReleaseMode) return;
    _runtimeOverride = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
    await prefs.setString(bgApiPrefsKey, url);
  }

  /// Persist the URL the FGS isolate should call (works in release too).
  static Future<void> mirrorApiBaseUrlForBackground([String? url]) async {
    final value = (url ?? apiBaseUrl).trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(bgApiPrefsKey, value);
  }

  /// Load the last debug backend choice before Dio / auth bootstrap.
  /// Debug defaults to the local API so Google Earth and other unreleased
  /// modules are reachable without silently landing on production.
  static Future<void> hydrate() async {
    if (kReleaseMode) {
      await mirrorApiBaseUrlForBackground(liveApiBaseUrl);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) {
      _runtimeOverride = saved;
      await prefs.setString(bgApiPrefsKey, saved);
      return;
    }
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    _runtimeOverride = fromEnv.isNotEmpty ? fromEnv : localApiBaseUrl;
    await prefs.setString(bgApiPrefsKey, _runtimeOverride!);
  }

  /// Resolve API base for background isolate (prefs → compile-time → live).
  static Future<String> resolveApiBaseUrlForBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(bgApiPrefsKey)?.trim();
      if (saved != null && saved.isNotEmpty) return saved;
    } catch (_) {}
    return apiBaseUrl;
  }

  static bool isLocalUrl(String url) {
    return url.contains('127.0.0.1') || url.contains('localhost');
  }

  static bool get isUsingLocalBackend {
    if (kReleaseMode) return false;
    return isLocalUrl(apiBaseUrl);
  }

  static const String localApiBaseUrl = 'http://localhost:4000/api';
  static const String liveApiBaseUrl = 'https://crm.nbdeveloper.co.in/api';

  /// API base URL (includes `/api` suffix).
  ///
  /// - In local debug mode, allows runtime switching between local dev and live database.
  /// - In release / production builds, strictly defaults to the live database.
  static String get apiBaseUrl {
    if (!kReleaseMode && _runtimeOverride != null && _runtimeOverride!.isNotEmpty) {
      return _runtimeOverride!;
    }
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kReleaseMode) return localApiBaseUrl;
    return liveApiBaseUrl;
  }

  /// Shared with backend `TRANSPORT_SECRET` for double AES-GCM JSON envelopes.
  ///
  /// This is a **client-visible transport protocol key**, not a server vault
  /// secret. On Flutter Web it is recoverable from the compiled JS bundle.
  /// Do not put JWT, DB, or SMTP secrets here. Real security relies on HTTPS,
  /// JWT/session auth, and backend RBAC.
  static const String transportSecret = String.fromEnvironment(
    'TRANSPORT_SECRET',
    defaultValue: 'nb-crm-double-enc-v2-local',
  );

  static String get socketOrigin {
    final base = apiBaseUrl;
    if (base.endsWith('/api')) return base.substring(0, base.length - 4);
    if (base.endsWith('/api/')) return base.substring(0, base.length - 5);
    return base;
  }
}
