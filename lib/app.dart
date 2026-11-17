// =====================================================================
// app.dart — app-wide look (colors, light/dark theme) and first screen.
// Change colors in lib/config/app_config.dart (seedColor), not here.
// =====================================================================
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_language.dart';
import 'widgets/app_update_gate.dart';
import 'services/analytics_service.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'widgets/support_prompt.dart';
import 'widgets/privacy_startup.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: AppLanguage.instance,
        builder: (context, _) => MaterialApp(
              locale: AppLanguage.instance.locale,
              supportedLocales: const [Locale('en'), Locale('vi')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              navigatorObservers: [
                if (AnalyticsService.instance.observer case final observer?)
                  observer
              ],
              builder: (context, child) => AppUpdateGate(child: child!),
              title: AppConfig.appName,
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorSchemeSeed: AppConfig.seedColor,
                brightness: Brightness.light,
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorSchemeSeed: AppConfig.seedColor,
                brightness: Brightness.dark,
                useMaterial3: true,
              ),
              themeMode: ThemeMode.system, // follows the phone setting
              home: const PrivacyStartup(child: SupportPrompt(child: HomeScreen())),
            ));
  }
}
