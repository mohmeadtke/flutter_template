/// Per-project settings. Starting a new project means changing this file:
/// the endpoint paths in `EndPoints` stay the same, only these values differ.
class AppConfig {
  AppConfig._();

  /// Every endpoint is relative to this. Keep the trailing slash.
  static const String baseUrl = 'https://api.example.com/api/';

  /// Sent as `X-App-Type` on every request.
  static const String appType = 'customer';

  /// Mazajk-style request signing: when set, every request carries an
  /// `X-KEY` header (HMAC-SHA256 of `<30s window>|<method>|<path>`). Leave
  /// null for backends that don't check it.
  static const String? requestSigningKey = null;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Timeout for session upkeep (refresh, sign-out). Kept short: a slow
  /// server must never trap anyone on the sign-out screen.
  static const Duration sessionRequestTimeout = Duration(seconds: 15);

  /// Accept self-signed certificates (local / test servers). Only ever
  /// applied in debug builds — a release build always verifies them.
  static const bool allowSelfSignedCertificatesInDebug = false;
}
