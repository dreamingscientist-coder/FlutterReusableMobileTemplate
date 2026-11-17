import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../config/app_strings.dart';
import '../screens/settings_screen.dart';
import 'banner_ad_widget.dart';
import 'app_support_footer.dart';

/// Use for every app screen: persistent header, Settings access and footer.
class AppScaffold extends StatelessWidget {
  final AppBar appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool showSettings;
  const AppScaffold(
      {super.key,
      required this.appBar,
      required this.body,
      this.bottomNavigationBar,
      this.showSettings = true});
  @override
  Widget build(BuildContext context) {
    final color = AppConfig.seedColor;
    return Scaffold(
      appBar: AppBar(
        title: appBar.title,
        automaticallyImplyLeading: appBar.automaticallyImplyLeading,
        leading: appBar.leading,
        foregroundColor: Colors.white,
        backgroundColor: color,
        actions: [
          ...?appBar.actions,
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: tr('Home'),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          if (showSettings)
            IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: tr(AppStrings.settings),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        settings: const RouteSettings(name: 'settings'),
                        builder: (_) => const SettingsScreen())))
        ],
      ),
      body: body,
      bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
        if (bottomNavigationBar != null) bottomNavigationBar!,
        const AppSupportFooter(banner: BannerAdWidget()),
      ]),
    );
  }
}
