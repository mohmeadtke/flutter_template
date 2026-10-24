// Sets the bundle ID (Android applicationId + iOS PRODUCT_BUNDLE_IDENTIFIER)
// and, optionally, the app name shown under the icon.
//
//   dart run tool/rename.dart com.company.myapp "My App"
//
// Safe to run again later: the current ID is read from the Android build file.
import 'dart:io';

const _gradle = 'android/app/build.gradle.kts';
const _kotlinRoot = 'android/app/src/main/kotlin';
const _manifest = 'android/app/src/main/AndroidManifest.xml';
const _pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
const _infoPlist = 'ios/Runner/Info.plist';
const _mainDart = 'lib/main.dart';

void main(List<String> args) {
  if (args.isEmpty || args.length > 2) {
    _fail('Usage: dart run tool/rename.dart <bundle.id> ["App Name"]');
  }
  final newId = args[0];
  // No underscores or dashes: iOS rejects underscores, Android rejects dashes.
  if (!RegExp(
    r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$',
  ).hasMatch(newId)) {
    _fail('"$newId" is not a valid bundle ID (example: com.company.myapp).');
  }

  final gradle = File(_gradle).readAsStringSync();
  final match = RegExp(r'applicationId = "([^"]+)"').firstMatch(gradle);
  if (match == null) _fail('applicationId not found in $_gradle');
  final oldId = match.group(1)!;

  if (oldId != newId) {
    _replace(_gradle, '"$oldId"', '"$newId"');
    _replace(
      _pbxproj,
      'PRODUCT_BUNDLE_IDENTIFIER = $oldId;',
      'PRODUCT_BUNDLE_IDENTIFIER = $newId;',
    );
    _replace(
      _pbxproj,
      'PRODUCT_BUNDLE_IDENTIFIER = $oldId.RunnerTests;',
      'PRODUCT_BUNDLE_IDENTIFIER = $newId.RunnerTests;',
    );
    _moveMainActivity(oldId, newId);
    stdout.writeln('Bundle ID: $oldId -> $newId');
  }

  if (args.length == 2) {
    final name = args[1];
    final xmlName = _xmlEscape(name);
    _replaceRegExp(
      _manifest,
      RegExp(r'android:label="[^"]*"'),
      (_) => 'android:label="$xmlName"',
    );
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      _replaceRegExp(
        _infoPlist,
        RegExp('(<key>$key</key>\\s*<string>)[^<]*(</string>)'),
        (m) => '${m[1]}$xmlName${m[2]}',
      );
    }
    _replaceRegExp(
      _mainDart,
      RegExp(r"title: '[^']*'"),
      (_) => "title: '${name.replaceAll("'", r"\'")}'",
    );
    stdout.writeln('App name: $name');
  }

  stdout.writeln('Done. Run `flutter clean` before the next build.');
}

void _moveMainActivity(String oldId, String newId) {
  final oldDir = Directory('$_kotlinRoot/${oldId.replaceAll('.', '/')}');
  final oldFile = File('${oldDir.path}/MainActivity.kt');
  if (!oldFile.existsSync()) _fail('${oldFile.path} not found');

  final newDir = Directory('$_kotlinRoot/${newId.replaceAll('.', '/')}')
    ..createSync(recursive: true);
  final source = oldFile.readAsStringSync().replaceFirst(
    'package $oldId',
    'package $newId',
  );
  File('${newDir.path}/MainActivity.kt').writeAsStringSync(source);
  oldFile.deleteSync();

  // Remove the old package folders that are now empty.
  var dir = oldDir;
  while (dir.path != _kotlinRoot && dir.listSync().isEmpty) {
    dir.deleteSync();
    dir = dir.parent;
  }
}

void _replace(String path, String from, String to) {
  final file = File(path);
  final text = file.readAsStringSync();
  if (!text.contains(from)) _fail('"$from" not found in $path');
  file.writeAsStringSync(text.replaceAll(from, to));
}

void _replaceRegExp(String path, RegExp from, String Function(Match) to) {
  final file = File(path);
  final text = file.readAsStringSync();
  if (!from.hasMatch(text)) _fail('${from.pattern} not found in $path');
  file.writeAsStringSync(text.replaceAllMapped(from, to));
}

String _xmlEscape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
