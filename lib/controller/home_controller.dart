import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../api/api_error_messages.dart';
import '../api/api_response.dart';
import '../api/api_utils.dart';
import '../api/end_points.dart';
import '../model/device_model.dart';
import 'auth_controller.dart';

/// Example feature controller — copy this shape for every new screen:
/// Rx fields for what the view shows, one method per API call, and the view
/// only reads fields and calls methods.
class HomeController extends GetxController {
  final AuthController auth = Get.find();

  final devices = <DeviceModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadDevices();
  }

  Future<void> loadDevices() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final response = await ApiUtils().get(endpoint: EndPoints.devices);
      if (!response.isSuccess) {
        errorMessage.value = ApiErrorMessages.fromResponse(response);
        return;
      }
      devices.assignAll(DeviceModel.listFrom(response.body));
    } catch (e) {
      debugPrint('Loading devices failed: $e');
      errorMessage.value = ApiErrorMessages.fromError(e);
    } finally {
      isLoading.value = false;
    }
  }

  void signOut() => auth.signOut();
}
