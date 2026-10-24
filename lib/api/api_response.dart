import 'package:dio/dio.dart';

/// Reads the platform's `{ data, error, message }` envelope, and bare bodies
/// from endpoints that don't use it.
extension ApiResponse on Response {
  /// 2xx, and not the envelope's soft refusal (`error: true` with a 200).
  bool get isSuccess {
    final status = statusCode ?? 0;
    final body = data;
    return status >= 200 &&
        status < 300 &&
        !(body is Map && body['error'] == true);
  }

  /// The envelope's `data`, or the whole body when there is no envelope.
  dynamic get body {
    final raw = data;
    return raw is Map && raw.containsKey('data') ? raw['data'] : raw;
  }
}
