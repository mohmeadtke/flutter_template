import 'package:get/get.dart';
import '../controller/home_controller.dart';
import '../controller/login_controller.dart';
import '../controller/splash_controller.dart';

// `AuthController` is not bound here: main() registers it permanently before
// runApp, because the session must be restored before the first request.

class SplashBindings implements Bindings {
  @override
  void dependencies() {
    // Not lazy: the splash view never reads it, but its onReady must run.
    Get.put(SplashController());
  }
}

class LoginBindings implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => LoginController());
  }
}

class HomeBindings implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HomeController());
  }
}
