import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/login_controller.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('login'.tr)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                CustomTextField(
                  controller: controller.userName,
                  title: 'username'.tr,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: controller.password,
                  title: 'password'.tr,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => controller.login(),
                ),
                const SizedBox(height: 24),
                Obx(
                  () => CustomButton(
                    title: 'login'.tr,
                    loading: controller.isLoading.value,
                    onTap: controller.login,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
