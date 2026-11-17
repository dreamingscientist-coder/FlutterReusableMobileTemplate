import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/ad_free_service.dart';

/// Banner-only footer. Keep the ad above the system home/gesture area.
class AppSupportFooter extends StatelessWidget {
  const AppSupportFooter({super.key, this.banner = const SizedBox.shrink()});
  final Widget banner;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: AdFreeService.instance,
      builder: (context, _) {
        if (AdFreeService.instance.active) return const SizedBox.shrink();
        return ColoredBox(
            key: const ValueKey('blue-bottom-section'),
            color: AppConfig.seedColor,
            child: SafeArea(top: false, child: banner));
      });
}
