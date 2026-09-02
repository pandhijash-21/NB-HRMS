import 'package:flutter/foundation.dart';

/// Application configuration from compile-time `--dart-define` values.
class AppConfig {
  AppConfig._();

  /// API base URL (includes `/api` suffix).
  ///
  /// - Debug builds default to `http://127.0.0.1:4000/api` (local backend).
  /// - Release builds default to production Hostinger.
  /// - Override anytime: `--dart-define=API_BASE_URL=...`
  static String get apiBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kDebugMode) return 'http://127.0.0.1:4000/api';
    return 'https://crm.nbdeveloper.co.in/api';
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
