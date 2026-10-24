import 'package:get/get.dart';
import '../bindings/bindings.dart';
import '../view/screens/home_screen.dart';
import '../view/screens/login_screen.dart';
import '../view/screens/splash_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';

  static final List<GetPage> pages = [
    GetPage(
      name: splash,
      page: () => const SplashScreen(),
      binding: SplashBindings(),
    ),
    GetPage(
      name: login,
      page: () => const LoginScreen(),
      binding: LoginBindings(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: home,
      page: () => const HomeScreen(),
      binding: HomeBindings(),
      transition: Transition.fadeIn,
    ),
  ];
}
