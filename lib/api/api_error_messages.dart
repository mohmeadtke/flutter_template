import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

/// A failure the app raises itself, carrying a code from the same table the
/// backend's codes live in.
class ApiFailure implements Exception {
  final String code;

  const ApiFailure(this.code);

  @override
  String toString() => 'ApiFailure($code)';
}

/// Turns any backend or network failure into one translated sentence.
///
/// The backend's error code is the contract; its wire message is for logs
/// only. Each code has a translation key `api_<code>` in `messages.dart` — a
/// new backend code needs a row there, nothing here.
class ApiErrorMessages {
  ApiErrorMessages._();

  static String get unexpected => 'api_unexpected'.tr;

  /// The sentence for [code], or [fallback] when the code is unknown.
  static String message(String? code, {String? fallback}) {
    final normalized = code?.trim().toLowerCase() ?? '';
    if (normalized.isNotEmpty) {
      final key = 'api_$normalized';
      final translated = key.tr;
      // `.tr` hands the key back when there is no translation for it.
      if (translated != key) return translated;
    }
    return fallback ?? unexpected;
  }

  /// The backend's code in [response]: a plain-text body, a module's
  /// `{ code, message }`, the envelope's `message`, or Identity's
  /// `[{ code, description }]`.
  static String? codeOf(Response? response) => _extractCode(response?.data);

  /// The sentence for a refused [response]. A bare 401 on a sign-in route
  /// means the credentials were wrong; pass [bareUnauthorizedCode] there.
  static String fromResponse(
    Response? response, {
    String? fallback,
    String? bareUnauthorizedCode,
  }) {
    final code = codeOf(response);
    if (code == null &&
        response?.statusCode == 401 &&
        bareUnauthorizedCode != null) {
      return message(bareUnauthorizedCode, fallback: fallback);
    }
    return message(code, fallback: fallback ?? _statusMessage(response));
  }

  /// The sentence for a thrown [error].
  static String fromError(Object error, {String? fallback}) {
    if (error is ApiFailure) return message(error.code, fallback: fallback);
    if (error is DioException) {
      if (error.response != null) {
        return fromResponse(error.response, fallback: fallback);
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return message('timeout');
        case DioExceptionType.connectionError:
          return message('no_internet');
        case DioExceptionType.cancel:
          return message('canceled');
        case DioExceptionType.unknown:
          if (error.error is SocketException) return message('no_internet');
          break;
        default:
          break;
      }
    }
    if (error is SocketException) return message('no_internet');
    return fallback ?? unexpected;
  }

  static String? _statusMessage(Response? response) {
    switch (response?.statusCode) {
      case 401:
        return message('unauthorized');
      case 403:
        return message('forbidden');
      case 404:
        return message('not_found');
      case final int status when status >= 500:
        return message('server_error');
      default:
        return null;
    }
  }

  static String? _extractCode(dynamic data) {
    if (data is String) {
      final text = data.trim();
      // Codes are short; anything longer is an HTML error page from a proxy.
      if (text.isEmpty || text.length > 200) return null;
      // A JSON body the server labelled as plain text.
      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          return _extractCode(jsonDecode(text));
        } catch (_) {
          // Not JSON after all — read it as a plain code.
        }
      }
      return text.replaceAll('"', '');
    }
    if (data is Map) {
      for (final key in const ['code', 'message']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      final errors = data['errors'];
      if (errors is List) return _extractCode(errors);
      if (errors is Map && errors.isNotEmpty) {
        return _extractCode(errors.values.first);
      }
      return null;
    }
    if (data is List && data.isNotEmpty) return _extractCode(data.first);
    return null;
  }
}
