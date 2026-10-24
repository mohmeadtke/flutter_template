import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controller/home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(controller.auth.authModel.value?.displayName ?? 'home'.tr),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'sign_out'.tr,
            onPressed: controller.signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadDevices,
        child: Obx(() {
          if (controller.isLoading.value && controller.devices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = controller.errorMessage.value;
          if (error != null) {
            return _Message(text: error, onRetry: controller.loadDevices);
          }
          if (controller.devices.isEmpty) {
            return _Message(text: 'no_devices'.tr);
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: controller.devices.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final device = controller.devices[index];
              return ListTile(
                leading: const Icon(Icons.smartphone),
                title: Text(device.displayName),
                subtitle: device.current ? Text('this_device'.tr) : null,
              );
            },
          );
        }),
      ),
    );
  }
}

/// Empty and error states. Scrollable so pull-to-refresh still works.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: onRetry, child: Text('retry'.tr)),
          ),
        ],
      ],
    );
  }
}
