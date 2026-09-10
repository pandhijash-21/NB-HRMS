import 'package:flutter/foundation.dart';

/// Application configuration from compile-time `--dart-define` values.
class AppConfig {
  AppConfig._();

  static String? _runtimeOverride;

  static void setApiBaseUrl(String? url) {
    if (kReleaseMode) return;
    _runtimeOverride = url;
  }

  static bool get isUsingLocalBackend {
    if (kReleaseMode) return false;
    return apiBaseUrl.contains('127.0.0.1') || apiBaseUrl.contains('localhost');
  }

  static const String localApiBaseUrl = 'http://127.0.0.1:4000/api';
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
