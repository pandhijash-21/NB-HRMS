/// Application configuration from compile-time `--dart-define` values.
class AppConfig {
  AppConfig._();

  /// Mirror of Next.js `NEXT_PUBLIC_API_URL` (includes `/api` suffix).
  /// Local default talks to `npm run dev` on this machine.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4000/api',
  );

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
}
