import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reusable_mobile_template/l10n/app_language.dart';
import 'package:flutter_reusable_mobile_template/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('language persists and unsupported values are rejected', () async {
    SharedPreferences.setMockInitialValues({});
    final language = AppLanguage();
    await language.select('vi');
    final restored = AppLanguage();
    await restored.init();
    expect(restored.locale, const Locale('vi'));
    expect(() => restored.select('xx'), throwsArgumentError);
    language.dispose();
    restored.dispose();
  });
  test('analytics is disabled by default and screen calls are harmless',
      () async {
    expect(AnalyticsService.enabled, false);
    await AnalyticsService.instance.init();
    await AnalyticsService.instance.logScreen('home');
    expect(AnalyticsService.instance.isReady, false);
    expect(AnalyticsService.instance.observer, null);
  });
}
