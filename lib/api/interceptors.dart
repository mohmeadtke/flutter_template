import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response, FormData;
import '../controller/auth_controller.dart';
import '../services/device_identity_service.dart';
import 'app_config.dart';
import 'end_points.dart';

/// Identifies this install on every request, signed in or not: device limits,
/// the devices list and the server logs all key off these headers.
class DeviceHeadersInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final identity = await DeviceIdentityService.identity;
      options.headers.addAll(identity.headers);
    } catch (e) {
      debugPrint('Sending request without device headers: $e');
    }
    options.headers['X-Request-ID'] = DeviceIdentityService.newUuid();
    options.headers['Accept-Language'] = _acceptLanguage();
    final signingKey = AppConfig.requestSigningKey;
    if (signingKey != null) {
      options.headers['X-KEY'] = signRequest(
        key: signingKey,
        method: options.method,
        path: options.uri.path,
      );
    }
    handler.next(options);
  }

  static String _acceptLanguage() {
    final code = Get.locale?.languageCode ?? 'ar';
    // Kurdish (Sorani) is written in Arabic script.
    if (code == 'ku' || code == 'kr') return 'ku-Arab';
    return code;
  }

  /// HMAC-SHA256 of `<30-second window>|<method>|<path>`, upper-case hex.
  /// Only sent when `AppConfig.requestSigningKey` is set.
  static String signRequest({
    required String key,
    required String method,
    required String path,
    DateTime? now,
  }) {
    final window =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000 ~/ 30;
    final payload = '$window|${method.toLowerCase()}|${path.toLowerCase()}';
    final digest = Hmac(sha256, utf8.encode(key)).convert(utf8.encode(payload));
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }
}

/// Adds the bearer token and keeps it fresh:
///  - a token that expires within the skew is refreshed before sending,
///  - a 401 refreshes once and replays the request,
///  - a refused refresh ends the session (in `AuthController`).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio);

  final Dio _dio;

  /// Marks a request that already had its one refresh, so a second 401 cannot
  /// start an endless refresh/replay loop.
  static const String _refreshedKey = 'refreshedForRequest';

  // Looked up per request: tests and sign-out may replace the instance.
  AuthController? get _auth =>
      Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final auth = _auth;
    if (auth != null &&
        auth.isSignedIn &&
        !EndPoints.isSessionRoute(options.path) &&
        options.extra[_refreshedKey] != true &&
        auth.isTokenExpired()) {
      // This counts as the request's one refresh: if it fails (offline) the
      // request still goes out and a 401 is returned as it is.
      options.extra[_refreshedKey] = true;
      await auth.refreshToken();
    }
    final token = auth?.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  // 4xx responses don't throw (validateStatus accepts < 500), so the 401 is
  // handled here, not in onError.
  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode != 401) {
      handler.next(response);
      return;
    }
    try {
      final replayed = await _refreshAndReplay(response.requestOptions);
      if (replayed != null) {
        handler.resolve(replayed);
        return;
      }
    } on DioException catch (e) {
      handler.reject(e);
      return;
    }
    handler.next(response);
  }

  // Covers requests sent with a validateStatus that turns 401 into an error.
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    try {
      final replayed = await _refreshAndReplay(err.requestOptions);
      if (replayed != null) {
        handler.resolve(replayed);
        return;
      }
    } on DioException catch (e) {
      handler.next(e);
      return;
    }
    handler.next(err);
  }

  /// Null when the request must not be replayed (session route, already
  /// refreshed, nothing to refresh with, or the refresh failed) — the
  /// original 401 is kept.
  Future<Response<dynamic>?> _refreshAndReplay(RequestOptions options) async {
    final auth = _auth;
    if (auth == null) return null;
    if (EndPoints.isSessionRoute(options.path)) return null;
    if (options.extra[_refreshedKey] == true) return null;
    // A registration token has nothing to refresh with; its 401 stays a 401
    // instead of ending a sign-up that is still in progress.
    if (!(auth.authModel.value?.hasRefreshToken ?? false)) return null;

    options.extra[_refreshedKey] = true;
    if (!await auth.refreshToken()) return null;

    // A FormData body can only be sent once, so the replay needs a copy.
    final data = options.data;
    if (data is FormData) options.data = data.clone();
    // Goes through the interceptors again: fresh token, request id and X-KEY.
    return _dio.fetch(options);
  }
}
