/// Application configuration from compile-time `--dart-define` values.
class AppConfig {
  AppConfig._();

  /// Mirror of Next.js `NEXT_PUBLIC_API_URL` (includes `/api` suffix).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000/api',
  );
}
