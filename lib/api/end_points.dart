/// Endpoint paths, relative to `AppConfig.baseUrl`. The same for every
/// project on this backend.
class EndPoints {
  EndPoints._();

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// `POST { userName, password }` — answers a `LoginResultDto`.
  static const String login = 'Auth/Login';

  /// Prefix shared by every external-provider sign-in (`Auth/External/Google`).
  static const String externalLogin = 'Auth/External/';
  static const String googleLogin = 'Auth/External/Google';
  static const String authExists = 'Auth/Exists';
  static const String generateOtp = 'Auth/GenerateOTP';
  static const String validateOtp = 'Auth/ValidateOTP';

  /// Creates the account for a registration token.
  static const String createWithContact = 'Auth/CreateWithContact';

  /// `POST { email }` — sends a six-digit code.
  static const String emailSendCode = 'Auth/Email/SendCode';

  /// `POST { email, code }` — answers a `LoginResultDto`.
  static const String emailVerifyCode = 'Auth/Email/VerifyCode';

  /// `PUT ?refreshToken=` — the token binds from the query string.
  static const String refreshToken = 'Auth/Refresh-Token';

  /// Form-encoded `refreshToken=` — revokes it and frees this device's slot.
  static const String logout = 'Auth/Logout';

  /// `POST { password, confirmPassword }` with a code-proven session.
  static const String resetPassword = 'Auth/ResetPassword';

  /// `POST { currentPassword, newPassword, confirmPassword }`.
  static const String changePassword = 'Auth/ChangePassword';

  /// `GET` lists the account's devices; `DELETE {id}` frees one.
  static const String devices = 'Auth/Devices';

  // ── Notifications (NID = Firebase push token) ─────────────────────────────

  static const String updateNID = 'Notification/UpdateNID';
  static const String removeNID = 'Notification/RemoveNID';

  // ── Storage ───────────────────────────────────────────────────────────────

  /// `GET` — `{ provider, baseUrl }`, the CDN relative file paths resolve
  /// against.
  static const String storageBaseUrl = 'storage/Files/BaseUrl';

  /// Multipart `POST` (`file`) with `?purpose=&folder=&name=&replace=`.
  static const String uploadFile = 'storage/Files/Upload';

  /// Routes that create or end a session. A 401 from one of them is the
  /// credential being refused — it must never trigger a token refresh.
  static const List<String> sessionRoutes = [
    login,
    externalLogin,
    authExists,
    generateOtp,
    validateOtp,
    createWithContact,
    emailSendCode,
    emailVerifyCode,
    refreshToken,
    logout,
  ];

  static bool isSessionRoute(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return sessionRoutes.any(normalized.startsWith);
  }
}
