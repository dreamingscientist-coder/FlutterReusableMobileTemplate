import '../l10n/app_language.dart';
// =====================================================================
// home_screen.dart — first screen. Replace the body with your app.
// The banner at the bottom hides itself when ads are off / Premium.
// =====================================================================
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_strings.dart';
import '../widgets/app_scaffold.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      appBar: AppBar(
        title: const AppText(AppConfig.appName),
      ),
      // ---------- YOUR APP CONTENT GOES HERE ----------
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(AppStrings.homeTitle, style: textTheme.headlineMedium),
              const SizedBox(height: 12),
              const AppText(AppStrings.homeBody, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      // ------------------------------------------------
    );
  }
}
