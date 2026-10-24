import 'package:shared_preferences/shared_preferences.dart';
import 'device_identity_service.dart';

/// Non-secret app settings in SharedPreferences. Call [init] once in main().
/// Tokens never go here — see `SessionStorage`.
class PreferencesService {
  PreferencesService._();

  static late SharedPreferences prefs;

  static const String _languageKey = 'language';
  static const String _installedKey = 'installed';

  /// Keys that describe this device and its reader, not the account, so a
  /// sign-out keeps them.
  static const List<String> _deviceKeys = [
    _languageKey,
    _installedKey,
    ...DeviceIdentityService.preservedPreferenceKeys,
  ];

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  /// True until [markInstalled]. Preferences are deleted with the app, so this
  /// is the first launch of a fresh install (or after the app data was cleared).
  static bool get isFirstLaunch => !prefs.containsKey(_installedKey);

  static Future<void> markInstalled() => prefs.setString(_installedKey, '1');

  static String get language => prefs.getString(_languageKey) ?? 'ar';

  static Future<void> saveLanguage(String code) =>
      prefs.setString(_languageKey, code);

  /// Wipes everything the signed-out account left behind, keeping the
  /// device keys.
  static Future<void> clearAccountPreferences() async {
    final kept = <String, String>{
      for (final key in _deviceKeys)
        if (prefs.getString(key) != null) key: prefs.getString(key)!,
    };
    await prefs.clear();
    for (final entry in kept.entries) {
      await prefs.setString(entry.key, entry.value);
    }
  }
}
