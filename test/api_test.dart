import 'dart:convert';
import 'package:app_template/api/api_error_messages.dart';
import 'package:app_template/api/api_utils.dart';
import 'package:app_template/api/end_points.dart';
import 'package:app_template/api/interceptors.dart';
import 'package:app_template/controller/auth_controller.dart';
import 'package:app_template/localization/messages.dart';
import 'package:app_template/model/auth_model.dart';
import 'package:app_template/routes/app_routes.dart';
import 'package:app_template/services/preferences_service.dart';
import 'package:app_template/services/session_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt(Duration expiresIn) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.sig';
}

/// Fake backend. Protected routes accept only [validToken]; the refresh route
/// rotates it unless [refuseRefresh] is set.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.validToken);

  String validToken;
  bool refuseRefresh = false;
  final requests = <RequestOptions>[];
  final bodies = <String>[];
  int refreshCalls = 0;

  int countOf(String path) => requests.where((r) => r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(
      requestStream == null
          ? ''
          : utf8.decode(
              (await requestStream.toList()).expand((c) => c).toList(),
              allowMalformed: true,
            ),
    );

    if (options.path == EndPoints.refreshToken) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refuseRefresh) return _json({'code': 'device_revoked'}, 401);
      validToken = _jwt(const Duration(hours: 1));
      return _json({
        'data': {'accessToken': validToken, 'refreshToken': 'r2'},
        'error': false,
      }, 200);
    }
    if (options.path == EndPoints.login) {
      return _json({'code': 'invalid_credentials'}, 401);
    }
    final ok = options.headers['Authorization'] == 'Bearer $validToken';
    return _json({'ok': ok}, ok ? 200 : 401);
  }

  ResponseBody _json(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackend backend;
  late AuthController auth;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'app',
      packageName: 'com.example.app',
      version: '1.2.3',
      buildNumber: '7',
      buildSignature: '',
    );
    ApiUtils().initializeDio();
    Get.addTranslations(Messages().keys);
    Get.locale = const Locale('en');
  });

  Future<void> signIn(String accessToken, {required String serverToken}) async {
    await Get.delete<AuthController>(force: true);
    auth = Get.put(AuthController(), permanent: true);
    auth.authModel.value = AuthModel(
      id: 'u1',
      displayName: 'Ali',
      accessToken: accessToken,
      refreshToken: 'r1',
    );
    await SessionStorage.write(auth.authModel.value!);
    backend = _FakeBackend(serverToken);
    ApiUtils().client.httpClientAdapter = backend;
    ApiUtils().sessionClient.httpClientAdapter = backend;
  }

  group('headers', () {
    test('every request carries the device and app headers', () async {
      final token = _jwt(const Duration(hours: 1));
      await signIn(token, serverToken: token);

      await ApiUtils().get(endpoint: 'Some/Thing');
      await ApiUtils().get(endpoint: 'Some/Thing');

      final first = backend.requests[0].headers;
      final second = backend.requests[1].headers;
      expect(first['Authorization'], 'Bearer $token');
      expect(first['X-Device-SN'], isNotEmpty);
      expect(first['X-Device-SN'], second['X-Device-SN']);
      expect(first['X-Device-OS'], isNotEmpty);
      expect(first['X-App-Version'], '1.2.3+7');
      expect(first['X-App-Type'], 'customer');
      expect(first['X-Timezone'], isNotEmpty);
      expect(first['Accept-Language'], 'en');
      expect(first['X-Request-ID'], isNot(second['X-Request-ID']));
      // No signing key configured.
      expect(first.containsKey('X-KEY'), isFalse);
    });

    test('X-KEY signature matches the backend formula', () {
      final now = DateTime.utc(2026, 1, 1, 12);
      final a = DeviceHeadersInterceptor.signRequest(
        key: 'k',
        method: 'GET',
        path: '/api/Auth/Devices',
        now: now,
      );
      final b = DeviceHeadersInterceptor.signRequest(
        key: 'k',
        method: 'get',
        path: '/api/auth/devices',
        now: now.add(const Duration(seconds: 5)),
      );
      expect(a, b);
      expect(a, matches(RegExp(r'^[0-9A-F]{64}$')));
    });
  });

  group('token refresh', () {
    test('expired token is refreshed before the request is sent', () async {
      await signIn(
        _jwt(const Duration(minutes: -5)),
        serverToken: 'server-only',
      );

      final res = await ApiUtils().get(endpoint: 'Some/Thing');

      expect(res.statusCode, 200);
      expect(backend.refreshCalls, 1);
      final refresh = backend.requests.first;
      expect(refresh.path, EndPoints.refreshToken);
      expect(refresh.method, 'PUT');
      expect(refresh.queryParameters['refreshToken'], 'r1');
      expect(refresh.headers['X-Device-SN'], isNotEmpty);
      final stored = await SessionStorage.read();
      expect(stored!.refreshToken, 'r2');
      // Fields the refresh answer leaves out are kept.
      expect(stored.displayName, 'Ali');
    });

    test('parallel requests share one refresh call', () async {
      await signIn(
        _jwt(const Duration(minutes: -5)),
        serverToken: 'server-only',
      );

      final results = await Future.wait(
        List.generate(5, (_) => ApiUtils().get(endpoint: 'Some/Thing')),
      );

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(backend.refreshCalls, 1);
    });

    test('a 401 refreshes once and replays the request', () async {
      await signIn(
        _jwt(const Duration(hours: 1)),
        serverToken: 'revoked-on-server',
      );

      final res = await ApiUtils().get(endpoint: 'Some/Thing');

      expect(res.statusCode, 200);
      expect(backend.refreshCalls, 1);
      expect(backend.countOf('Some/Thing'), 2);
    });

    test('a FormData body survives the replay', () async {
      await signIn(
        _jwt(const Duration(hours: 1)),
        serverToken: 'revoked-on-server',
      );

      final res = await ApiUtils().postFormData(
        endpoint: 'Some/Upload',
        formData: {'name': 'cover'},
      );

      expect(res.statusCode, 200);
      expect(backend.countOf('Some/Upload'), 2);
      expect(backend.bodies.last, contains('cover'));
    });

    test('a 401 from a sign-in route is not refreshed', () async {
      await signIn(
        _jwt(const Duration(hours: 1)),
        serverToken: 'revoked-on-server',
      );

      final res = await ApiUtils().post(
        endpoint: EndPoints.login,
        data: {'userName': 'a', 'password': 'b'},
      );

      expect(res.statusCode, 401);
      expect(backend.refreshCalls, 0);
      expect(
        ApiErrorMessages.fromResponse(res),
        'The phone number, e-mail or password is incorrect',
      );
    });

    testWidgets('a refused refresh ends the session', (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: AppRoutes.login,
          getPages: [
            GetPage(name: AppRoutes.login, page: () => const SizedBox()),
          ],
        ),
      );
      await tester.runAsync(() async {
        await signIn(
          _jwt(const Duration(hours: 1)),
          serverToken: 'revoked-on-server',
        );
        backend.refuseRefresh = true;

        final res = await ApiUtils().get(endpoint: 'Some/Thing');

        expect(res.statusCode, 401);
        expect(backend.refreshCalls, 1);
        expect(auth.isSignedIn, isFalse);
        expect(await SessionStorage.read(), isNull);
      });
      // Let the session-ended snackbar run out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('restore', () {
    test('a fresh install drops a session a deleted install left', () async {
      final session = AuthModel(
        accessToken: _jwt(const Duration(hours: 1)),
        refreshToken: 'r1',
      );
      // What the iOS Keychain keeps after the app is deleted; preferences
      // start empty.
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.init();
      await SessionStorage.write(session);
      await Get.delete<AuthController>(force: true);
      auth = Get.put(AuthController(), permanent: true);

      await auth.restoreSession();
      expect(auth.isSignedIn, isFalse);
      expect(await SessionStorage.read(), isNull);

      // Later launches keep the session.
      await SessionStorage.write(session);
      await auth.restoreSession();
      expect(auth.isSignedIn, isTrue);
    });
  });

  group('error messages', () {
    test('reads the code from every body shape the backend uses', () {
      Response r(dynamic data, [int status = 400]) => Response(
        requestOptions: RequestOptions(),
        data: data,
        statusCode: status,
      );

      expect(ApiErrorMessages.codeOf(r('otp_invalid')), 'otp_invalid');
      expect(
        ApiErrorMessages.codeOf(r({'code': 'otp_expired'})),
        'otp_expired',
      );
      expect(
        ApiErrorMessages.codeOf(
          r({'data': null, 'error': true, 'message': 'x'}),
        ),
        'x',
      );
      expect(
        ApiErrorMessages.codeOf(
          r([
            {'code': 'DuplicateEmail', 'description': '...'},
          ]),
        ),
        'DuplicateEmail',
      );
      expect(
        ApiErrorMessages.fromResponse(r({'code': 'unknown_code'}, 500)),
        'Server error, please try again later',
      );
    });
  });
}
