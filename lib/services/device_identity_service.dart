import 'dart:io';
import 'dart:math';
import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/app_config.dart';

/// What this install tells the backend about itself on every request.
class DeviceIdentity {
  /// Same string from the same phone every time, across reinstalls — a
  /// device limit counts phones, not installs.
  final String serial;

  /// `ios` / `android` / `web` / ...
  final String os;
  final String osVersion;

  /// The pubspec version without the build number (`1.0.0`).
  final String version;

  /// The full build label (`1.0.0+3`).
  final String buildLabel;

  /// Android package name / iOS bundle id.
  final String packageName;

  /// IANA zone, e.g. `Asia/Baghdad`.
  final String timezone;

  const DeviceIdentity({
    required this.serial,
    required this.os,
    required this.osVersion,
    required this.version,
    required this.buildLabel,
    required this.packageName,
    required this.timezone,
  });

  Map<String, String> get headers => {
    'X-Device-SN': serial,
    'X-Device-OS': os,
    'X-Device-OS-Version': osVersion,
    'X-App-Version': buildLabel,
    'X-App-Type': AppConfig.appType,
    'X-Timezone': timezone,
  };
}

/// Resolves [DeviceIdentity] once per process.
///
/// The future is cached rather than the value, so two early requests on a
/// fresh install cannot each mint their own serial.
class DeviceIdentityService {
  DeviceIdentityService._();

  static const String _serialKey = 'device_serial';

  /// Keychain item that survives delete-and-reinstall but is never restored
  /// onto another phone from a backup.
  static const FlutterSecureStorage _keychain = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static final Random _random = Random.secure();
  static Future<DeviceIdentity>? _identity;

  static Future<DeviceIdentity> get identity => _identity ??= _resolve();

  /// Preference keys this service owns, which a sign-out must not wipe.
  static const List<String> preservedPreferenceKeys = [_serialKey];

  /// Random UUID v4, used for the fallback serial and for `X-Request-ID`.
  static String newUuid() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<DeviceIdentity> _resolve() async {
    final results = await Future.wait([
      _resolveSerial(),
      _resolveOsVersion(),
      _resolveTimezone(),
    ]);
    final package = await _resolvePackageInfo();

    return DeviceIdentity(
      serial: results[0],
      os: _os,
      osVersion: results[1],
      version: package?.version ?? '',
      buildLabel: package == null
          ? ''
          : package.buildNumber.isEmpty
          ? package.version
          : '${package.version}+${package.buildNumber}',
      packageName: package?.packageName ?? '',
      timezone: results[2],
    );
  }

  static String get _os {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  static Future<String> _resolveSerial() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidId = await const AndroidId().getId();
        if (androidId != null && androidId.isNotEmpty) return androidId;
      } else if (!kIsWeb && Platform.isIOS) {
        final stored = await _keychain.read(key: _serialKey);
        if (stored != null && stored.isNotEmpty) return stored;
        final minted = newUuid();
        await _keychain.write(key: _serialKey, value: minted);
        return minted;
      }
    } catch (e) {
      debugPrint('Device serial lookup failed, using the stored one: $e');
    }
    return _preferencesSerial();
  }

  /// Last resort: survives app restarts only, not a reinstall.
  static Future<String> _preferencesSerial() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_serialKey);
    if (stored != null && stored.isNotEmpty) return stored;
    final minted = newUuid();
    await prefs.setString(_serialKey, minted);
    return minted;
  }

  static Future<String> _resolveOsVersion() async {
    if (kIsWeb) return '';
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) return (await plugin.androidInfo).version.release;
      if (Platform.isIOS) return (await plugin.iosInfo).systemVersion;
    } catch (e) {
      debugPrint('OS version lookup failed: $e');
    }
    return Platform.operatingSystemVersion;
  }

  static Future<String> _resolveTimezone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (e) {
      debugPrint('Timezone lookup failed: $e');
      return DateTime.now().timeZoneName;
    }
  }

  static Future<PackageInfo?> _resolvePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (e) {
      debugPrint('Package info lookup failed: $e');
      return null;
    }
  }
}
