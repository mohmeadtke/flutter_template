import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'app_config.dart';
import 'interceptors.dart';

/// The app's HTTP clients.
///
/// [get] / [post] / ... go through the main client: device headers, bearer
/// token, refresh-before-expiry and refresh-and-replay on 401.
/// [sessionClient] has the device headers only — for the refresh and
/// sign-out calls themselves, so they can never recurse into a refresh.
///
/// 4xx responses are returned, not thrown, so screens can read the backend's
/// error code (`ApiErrorMessages.fromResponse`). Only 5xx and network
/// failures throw a [DioException] (`ApiErrorMessages.fromError`).
class ApiUtils {
  static final ApiUtils _apiUtils = ApiUtils._internal();

  ApiUtils._internal();

  factory ApiUtils() => _apiUtils;

  static late Dio _dio;
  static late Dio _sessionDio;
  static CancelToken _token = CancelToken();

  /// Shared by every request made without its own token; see [cancelAll].
  static CancelToken get token => _token;

  /// Cancels every in-flight request (sign-out, leaving a flow).
  static void cancelAll([String reason = 'cancelled']) {
    if (!_token.isCancelled) _token.cancel(reason);
    _token = CancelToken();
  }

  /// The main client, for tests and the rare call [get] / [post] don't cover.
  Dio get client => _dio;

  /// Device headers only; no auth interceptor. See the class doc.
  Dio get sessionClient => _sessionDio;

  void initializeDio([String urlPrefix = '']) {
    _dio = _createClient(urlPrefix, AppConfig.receiveTimeout);
    _dio.interceptors.addAll([
      AuthInterceptor(_dio),
      DeviceHeadersInterceptor(),
    ]);

    _sessionDio = _createClient(urlPrefix, AppConfig.sessionRequestTimeout);
    _sessionDio.interceptors.add(DeviceHeadersInterceptor());
  }

  static Dio _createClient(String urlPrefix, Duration receiveTimeout) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl + urlPrefix,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: receiveTimeout,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (!kIsWeb && kDebugMode && AppConfig.allowSelfSignedCertificatesInDebug) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()
          ..badCertificateCallback =
              (X509Certificate cert, String host, int port) => true,
      );
    }
    return dio;
  }

  Future<Response> get({
    required String endpoint,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.get(
      endpoint,
      queryParameters: queryParameters,
      cancelToken: cancelToken ?? token,
    );
  }

  Future<Response> post({
    required String endpoint,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      endpoint,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken ?? token,
    );
  }

  Future<Response> put({
    required String endpoint,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.put(
      endpoint,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken ?? token,
    );
  }

  Future<Response> patch({
    required String endpoint,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.patch(
      endpoint,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken ?? token,
    );
  }

  Future<Response> delete({
    required String endpoint,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) {
    return _dio.delete(
      endpoint,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken ?? token,
    );
  }

  /// Multipart upload. Dio sets the `multipart/form-data` content type with
  /// its boundary — never set that header by hand.
  Future<Response> postFormData({
    required String endpoint,
    required Map<String, dynamic> formData,
    Map<String, dynamic>? queryParameters,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      endpoint,
      data: FormData.fromMap(formData),
      queryParameters: queryParameters,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken ?? token,
    );
  }
}
