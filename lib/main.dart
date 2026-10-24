import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'api/api_utils.dart';
import 'controller/auth_controller.dart';
import 'localization/messages.dart';
import 'routes/app_routes.dart';
import 'services/device_identity_service.dart';
import 'services/nid_service.dart';
import 'services/preferences_service.dart';
import 'style/themes.dart';

Future<void> main() async {
  // debugPrint also logs in release builds, and errors can carry request URLs
  // (the refresh token and NID travel in the query string).
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();

  await PreferencesService.init();
  // Started now so the first request doesn't wait for the device lookups.
  DeviceIdentityService.identity.ignore();
  // Add `options: DefaultFirebaseOptions.currentPlatform` after
  // `flutterfire configure`.
  await NidService.init();

  ApiUtils().initializeDio();
  // Before runApp: nothing may go out without the stored token.
  await Get.put(AuthController(), permanent: true).restoreSession();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'App Template',
      debugShowCheckedModeBanner: false,
      translations: Messages(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      locale: Locale(PreferencesService.language),
      fallbackLocale: const Locale('en'),
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      getPages: AppRoutes.pages,
      builder: EasyLoading.init(),
    );
  }
}
