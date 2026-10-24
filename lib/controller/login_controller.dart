import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../api/api_error_messages.dart';
import '../api/api_response.dart';
import '../api/api_utils.dart';
import '../api/end_points.dart';
import 'auth_controller.dart';

class LoginController extends GetxController {
  final AuthController _auth = Get.find();

  final userName = TextEditingController();
  final password = TextEditingController();
  final isLoading = false.obs;

  Future<void> login() async {
    if (isLoading.value) return;
    final name = userName.text.trim();
    if (name.isEmpty || password.text.isEmpty) {
      Get.snackbar('error'.tr, 'fill_all_fields'.tr);
      return;
    }

    isLoading.value = true;
    try {
      final response = await ApiUtils().post(
        endpoint: EndPoints.login,
        data: {'userName': name, 'password': password.text},
      );
      if (!response.isSuccess) {
        Get.snackbar(
          'error'.tr,
          ApiErrorMessages.fromResponse(
            response,
            // A wrong name or password, by design indistinguishable.
            bareUnauthorizedCode: 'invalid_credentials',
          ),
        );
        return;
      }

      switch (await _auth.acceptSignIn(response.data)) {
        case SignInOutcome.twoFactorRequired:
          Get.snackbar(
            'alert'.tr,
            ApiErrorMessages.message('two_factor_required'),
          );
        case SignInOutcome.registration:
          // Login never answers a registration token for a real account.
          await _auth.discardSession();
          Get.snackbar(
            'error'.tr,
            ApiErrorMessages.message('registration_failed'),
          );
        case SignInOutcome.session:
          await _auth.routeSignedIn();
      }
    } catch (e) {
      debugPrint('Login failed: $e');
      Get.snackbar('error'.tr, ApiErrorMessages.fromError(e));
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    userName.dispose();
    password.dispose();
    super.onClose();
  }
}
