import 'package:get/get.dart';
import 'auth_controller.dart';

class SplashController extends GetxController {
  final AuthController _auth = Get.find();

  @override
  void onReady() {
    super.onReady();
    _auth.openApp();
  }
}
