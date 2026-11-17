// =====================================================================
// app_config_test.dart — catches setup mistakes before you publish.
// Run with: make check   (or: flutter test)
// =====================================================================
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_reusable_mobile_template/config/app_config.dart';

void main() {
  test('Bundle ID looks valid (lowercase, dots, no spaces)', () {
    expect(
      RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$')
          .hasMatch(AppConfig.bundleId),
      isTrue,
    );
  });

  test('App name is set', () {
    expect(AppConfig.appName.trim(), isNotEmpty);
  });

  test('Support email looks valid', () {
    expect(
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(AppConfig.supportEmail),
      isTrue,
    );
  });

  test('Legal pages use https (required by both stores)', () {
    for (final url in [
      AppConfig.privacyPolicyUrl,
      AppConfig.termsOfUseUrl,
      AppConfig.supportPageUrl,
      AppConfig.dataDeletionUrl,
    ]) {
      expect(url.startsWith('https://'), isTrue, reason: url);
    }
  });

  test('Pro product ID starts with the bundle ID', () {
    expect(AppConfig.proProductId, startsWith(AppConfig.bundleId));
  });
}
