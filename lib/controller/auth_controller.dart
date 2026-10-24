import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:jwt_decoder/jwt_decoder.dart';
import '../api/api_error_messages.dart';
import '../api/api_response.dart';
import '../api/api_utils.dart';
import '../api/app_config.dart';
import '../api/end_points.dart';
import '../model/auth_model.dart';
import '../routes/app_routes.dart';
import '../services/nid_service.dart';
import '../services/preferences_service.dart';
import '../services/session_storage.dart';

/// How a sign-in route's answer was read.
enum SignInOutcome {
  /// A real session: both tokens stored.
  session,

  /// A registration token, stored without a refresh token: the account is
  /// created by `CreateWithContact`.
  registration,

  /// A two-factor challenge. Nothing was stored.
  twoFactorRequired,
}

/// Owns the session: stores it, refreshes it, ends it, registers the NID and
/// decides where a launch or a fresh sign-in lands. Registered permanently in
/// `MainBindings`.
class AuthController extends GetxController {
  final authModel = Rxn<AuthModel>();

  Future<bool>? _refreshRequest;
  bool _endingSession = false;
  bool _signingOut = false;
  StreamSubscription<String>? _nidSubscription;

  /// Seconds before the real expiry at which the token counts as expired,
  /// so it can't expire while the request is on its way.
  static const Duration _expirySkew = Duration(seconds: 30);

  /// True only for a real session — not for a registration token.
  bool get isSignedIn => authModel.value?.isSession ?? false;

  bool get isRegistrationPending =>
      authModel.value?.isRegistrationToken ?? false;

  /// The bearer token for the next request (a session's or a registration's).
  String? get accessToken => authModel.value?.accessToken;

  @override
  void onInit() {
    super.onInit();
    _nidSubscription = NidService.onNidRefresh.listen((_) => updateNID());
  }

  @override
  void onClose() {
    _nidSubscription?.cancel();
    super.onClose();
  }

  /// Loads what the last run left behind. Awaited in main() before the first
  /// request, so nothing goes out without the stored token.
  Future<void> restoreSession() async {
    // The iOS Keychain outlives deleting the app; preferences don't. A fresh
    // install must not sign in with the session a deleted install left.
    if (PreferencesService.isFirstLaunch) {
      await SessionStorage.clear();
      await PreferencesService.markInstalled();
    }
    authModel.value = await SessionStorage.read();
  }

  // ── Launch and sign-in ────────────────────────────────────────────────────

  /// Decides the first screen from what is stored.
  Future<void> openApp() async {
    final stored = authModel.value;
    if (stored != null && stored.isSession) {
      await routeSignedIn();
      return;
    }
    // A registration token outlives neither a relaunch nor its expiry here:
    // the template has no profile step to resume. Projects that do can route
    // to it while `isRegistrationPending && !isTokenExpired()`.
    if (stored != null) await _clearSession();
    unawaited(Get.offAllNamed(AppRoutes.login));
  }

  /// Reads the 200 of any sign-in route and stores what it grants.
  ///
  /// Throws [ApiFailure] (`registration_failed`) when the answer carries no
  /// token at all.
  Future<SignInOutcome> acceptSignIn(dynamic data) async {
    final result = data is Map
        ? AuthModel.fromJson(Map<String, dynamic>.from(data))
        : null;

    if (result?.requiresTwoFactor ?? false) {
      return SignInOutcome.twoFactorRequired;
    }
    if (result == null || !result.hasAccessToken) {
      throw const ApiFailure('registration_failed');
    }

    await _storeSession(result);
    return result.isRegistrationToken
        ? SignInOutcome.registration
        : SignInOutcome.session;
  }

  /// Where a kept session goes. The NID is registered here rather than on
  /// sign-in, so a session a flow only borrows never subscribes this device.
  Future<void> routeSignedIn() async {
    unawaited(updateNID());
    unawaited(Get.offAllNamed(AppRoutes.home));
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  /// Parallel requests hit 401 together, so they share one refresh call
  /// instead of each firing its own (the backend rotates the refresh token —
  /// a second call with the old one would be refused).
  Future<bool> refreshToken() {
    return _refreshRequest ??= _performRefreshToken().whenComplete(() {
      _refreshRequest = null;
    });
  }

  Future<bool> _performRefreshToken() async {
    final current = authModel.value;
    final startedFrom = current?.refreshToken;
    if (current == null || startedFrom == null || startedFrom.isEmpty) {
      return false;
    }

    final Response response;
    try {
      response = await ApiUtils().sessionClient.put(
        EndPoints.refreshToken,
        // Binds from the query string — a JSON body binds to null.
        queryParameters: {'refreshToken': startedFrom},
        options: Options(
          headers: {
            if (current.hasAccessToken)
              'Authorization': 'Bearer ${current.accessToken}',
          },
        ),
      );
    } catch (e) {
      // No answer is not a refusal: keep the session for the next attempt.
      debugPrint('Token refresh did not reach the server: $e');
      return false;
    }

    // A sign-out or another sign-in landed while this was in flight — its
    // answer belongs to a session that no longer exists.
    if (authModel.value?.refreshToken != startedFrom) return false;

    final status = response.statusCode ?? 0;
    if (response.isSuccess && response.body is Map) {
      final refreshed = AuthModel.fromJson(
        Map<String, dynamic>.from(response.body),
      );
      if (!refreshed.hasAccessToken) return false;
      // An answer without a new refresh token keeps the stored one rather
      // than overwriting a working credential with nothing.
      if (!refreshed.hasRefreshToken) refreshed.refreshToken = startedFrom;
      refreshed
        ..id ??= current.id
        ..userName ??= current.userName
        ..displayName ??= current.displayName
        ..phoneNumber ??= current.phoneNumber
        ..email ??= current.email;
      if (refreshed.roles.isEmpty) refreshed.roles = current.roles;
      await _storeSession(refreshed);
      return true;
    }

    if (status == 400 || status == 401 || status == 404) {
      final code = ApiErrorMessages.codeOf(response);
      await endSession(
        reasonCode: code == 'device_revoked'
            ? 'device_revoked'
            : 'session_expired',
      );
    }
    return false;
  }

  bool isTokenExpired() {
    final token = accessToken;
    if (token == null || token.isEmpty) return false;
    try {
      return JwtDecoder.getExpirationDate(
        token,
      ).isBefore(DateTime.now().add(_expirySkew));
    } catch (_) {
      // Not a JWT: let the backend decide (its 401 triggers a refresh).
      return false;
    }
  }

  /// A claim of the stored access token. On a registration token these carry
  /// the verified facts `CreateWithContact` applies (`phone_number`, `email`).
  String? tokenClaim(String name) {
    final token = accessToken;
    if (token == null || token.isEmpty) return null;
    try {
      final value = JwtDecoder.decode(token)[name];
      if (value is String && value.isNotEmpty) return value;
      if (value is List && value.isNotEmpty) return value.first?.toString();
    } catch (e) {
      debugPrint('Failed to decode access token: $e');
    }
    return null;
  }

  // ── NID (push token) ──────────────────────────────────────────────────────

  /// Registers this device's FCM token with the backend. Runs on every open
  /// with a session, after sign-in, and whenever Firebase rotates the token
  /// (reinstall, restore, app-data clear).
  Future<void> updateNID() async {
    if (!isSignedIn) return;
    try {
      final nid = await NidService.getNid();
      if (nid == null) {
        debugPrint('Skipped UpdateNID: no FCM token available');
        return;
      }
      final response = await ApiUtils().post(
        endpoint: EndPoints.updateNID,
        queryParameters: {'nid': nid},
      );
      if (!response.isSuccess) {
        debugPrint('Failed to update NID: ${response.statusCode}');
      }
    } catch (e) {
      // Push is a nice-to-have — it must never break startup or a sign-in.
      debugPrint('Failed to update NID: $e');
    }
  }

  /// Clears this device's FCM token on the backend. Must run before the
  /// session is wiped: the request is authenticated with it.
  Future<void> removeNID() async {
    try {
      final response = await ApiUtils().get(endpoint: EndPoints.removeNID);
      if (!response.isSuccess) {
        debugPrint('Failed to remove NID: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to remove NID: $e');
    }
  }

  // ── Language ──────────────────────────────────────────────────────────────

  /// Saved locally; the backend reads it from `Accept-Language`.
  Future<void> changeLanguage(String code) async {
    await PreferencesService.saveLanguage(code);
    await Get.updateLocale(Locale(code));
  }

  // ── Ending the session ────────────────────────────────────────────────────

  /// Signs this device out. Every server step is best-effort with a short
  /// timeout — a failure here must never trap anyone in the app.
  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      final session = authModel.value;
      if (session?.isSession ?? false) {
        // Authenticated with the session about to be revoked, so it goes
        // first; this device stops getting the account's notifications.
        await removeNID().timeout(
          AppConfig.sessionRequestTimeout,
          onTimeout: () {},
        );
      }
      // Also frees this device's slot in the device limit.
      await _revokeOnServer(session);
      ApiUtils.cancelAll('signed out');
      await _clearSession();
      await PreferencesService.clearAccountPreferences();
      unawaited(Get.offAllNamed(AppRoutes.login));
    } finally {
      _signingOut = false;
    }
  }

  /// The server ended this session — its refresh was refused, or this device
  /// was removed from another phone. Forgets it and returns to sign-in with
  /// the reason.
  Future<void> endSession({String reasonCode = 'session_expired'}) async {
    // A sign-out already in progress clears everything itself.
    if (_endingSession || _signingOut) return;
    _endingSession = true;
    try {
      // In-flight requests are not cancelled: this usually runs inside one of
      // them (its refresh was refused), and it must end with its 401, not a
      // "cancelled" error on top of the session-ended notice.
      await _clearSession();
      unawaited(Get.offAllNamed(AppRoutes.login));
      Get.snackbar('alert'.tr, ApiErrorMessages.message(reasonCode));
    } finally {
      _endingSession = false;
    }
  }

  /// Drops a session that a flow received but must not keep (an existing
  /// account met on the register path, a finished password reset). Revoked
  /// on the server first, so the device slot is freed.
  Future<void> discardSession() async {
    await _revokeOnServer(authModel.value);
    await _clearSession();
  }

  Future<void> _revokeOnServer(AuthModel? session) async {
    final refreshToken = session?.refreshToken;
    if (session == null || refreshToken == null || refreshToken.isEmpty) {
      return;
    }
    try {
      await ApiUtils().sessionClient.post(
        EndPoints.logout,
        // The action binds [FromForm]; a JSON body binds to null and revokes
        // nothing.
        data: {'refreshToken': refreshToken},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            if (session.hasAccessToken)
              'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );
    } catch (e) {
      debugPrint('Server sign-out failed, clearing locally anyway: $e');
    }
  }

  Future<void> _storeSession(AuthModel session) async {
    authModel.value = session;
    try {
      await SessionStorage.write(session);
    } catch (e) {
      // The in-memory session still works for this run.
      debugPrint('Failed to persist the session: $e');
    }
  }

  Future<void> _clearSession() async {
    authModel.value = null;
    await SessionStorage.clear();
  }
}
