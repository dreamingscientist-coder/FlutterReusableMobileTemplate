import '../l10n/app_language.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/development_settings.dart';

class DebugBannerSetting extends StatelessWidget {
  const DebugBannerSetting({super.key});
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final development = DevelopmentSettings.instance;
    return ListenableBuilder(
        listenable: development,
        builder: (context, _) => SwitchListTile(
              key: const ValueKey('debug-banner-toggle'),
              title: const AppText('Show test banner'),
              subtitle: const AppText(
                  'Debug only · Google test ads. A labelled preview appears while the ad loads. This choice is saved on this device.'),
              value: development.showTestBanner,
              onChanged: (value) async {
                try {
                  await development.setShowTestBanner(value);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: AppText(
                            'Could not save banner preview. Please try again.')));
                  }
                }
              },
            ));
  }
}
