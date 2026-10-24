import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../model/auth_model.dart';

/// Keeps the session (both tokens and the user fields) in the Keychain /
/// Android Keystore-backed storage rather than in plain SharedPreferences.
class SessionStorage {
  SessionStorage._();

  static const String _sessionKey = 'auth_session';

  // Readable after the first unlock: a background refresh while the phone is
  // locked must still be able to store the rotated token.
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<AuthModel?> read() async {
    try {
      final stored = await _storage.read(key: _sessionKey);
      if (stored != null) return AuthModel.fromJson(jsonDecode(stored));
    } catch (e) {
      debugPrint('Discarding unreadable stored session: $e');
      await clear();
    }
    return null;
  }

  static Future<void> write(AuthModel session) =>
      _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _sessionKey);
    } catch (e) {
      debugPrint('Failed to delete stored session: $e');
    }
  }
}
