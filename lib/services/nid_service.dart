import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// NID = the Firebase Cloud Messaging token the backend pushes to.
///
/// Firebase is optional while a project is being set up: if
/// google-services.json / GoogleService-Info.plist are missing, [init] fails
/// quietly and [getNid] returns null, so the app still runs.
class NidService {
  NidService._();

  static bool _available = false;

  static bool get isAvailable => _available;

  /// Pass `DefaultFirebaseOptions.currentPlatform` once `flutterfire
  /// configure` has generated `firebase_options.dart`.
  static Future<void> init({FirebaseOptions? options}) async {
    try {
      await Firebase.initializeApp(options: options);
      _available = true;
    } catch (e) {
      debugPrint('Firebase not configured, NID disabled: $e');
    }
  }

  static Future<String?> getNid() async {
    if (!_available) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await messaging.requestPermission();
      }
      if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
        // getToken throws on iOS until APNs has handed over its token.
        final apns = await messaging.getAPNSToken();
        if (apns == null) return null;
      }
      final token = await messaging.getToken();
      return token == null || token.isEmpty ? null : token;
    } catch (e) {
      debugPrint('getNid failed: $e');
      return null;
    }
  }

  /// Fires when Firebase rotates the token; it must be sent to the backend
  /// again or pushes stop arriving.
  static Stream<String> get onNidRefresh => _available
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();
}
