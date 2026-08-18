/// Application configuration from compile-time `--dart-define` values.
class AppConfig {
  AppConfig._();

  /// Mirror of Next.js `NEXT_PUBLIC_API_URL` (includes `/api` suffix).
  /// Local default talks to `npm run dev` on this machine.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:4000/api',
  );

  /// Must match backend `TRANSPORT_SECRET` (double AES-GCM on JSON payloads).
  static const String transportSecret = String.fromEnvironment(
    'TRANSPORT_SECRET',
    defaultValue: 'nb-crm-double-enc-v2-local',
  );
}
