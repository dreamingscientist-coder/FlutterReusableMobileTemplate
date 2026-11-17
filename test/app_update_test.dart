import 'dart:convert';
import 'package:flutter_reusable_mobile_template/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_reusable_mobile_template/services/app_update_service.dart';

Map<String, dynamic> updatePolicy(
        {String mode = 'optional', String minimum = '1.0.0'}) =>
    {
      'schemaVersion': 1,
      'appId': 'com.example.sample',
      'ios': {
        'enabled': true,
        'storeAvailable': true,
        'expiresAt': '2027-01-01T00:00:00Z',
        'latestVersion': '1.10.0',
        'minimumSupportedVersion': minimum,
        'mode': mode,
        'publishedReleases': ['1.0.0', '1.1.0', '1.2.0', '1.10.0'],
        'storeUrl': 'https://apps.apple.com/app/id123456789',
        'messages': {
          'en': 'Improvements',
          'vi': 'Cải tiến',
          'fr': 'Améliorations'
        }
      }
    };
void main() {
  final now = DateTime.utc(2026, 10, 22);
  AppUpdateNotice? evaluate(Map<String, dynamic> p, String v) =>
      AppUpdateNotice.evaluate(p,
          platform: 'ios',
          installed: v,
          now: now,
          bundleId: 'com.example.sample');
  test('compares numeric version components', () {
    expect(compareAppVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareAppVersions('2.0.0', '1.99.99'), greaterThan(0));
    expect(() => compareAppVersions('bad', '1.0.0'), throwsFormatException);
  });
  test('optional, >2 published releases, minimum and required policy', () {
    final p = updatePolicy();
    expect(evaluate(p, '1.1.0')!.strongReminder, false);
    final strong = evaluate(p, '1.0.0')!;
    expect(strong.releasesBehind, 3);
    expect(strong.strongReminder, true);
    expect(strong.required, false);
    expect(evaluate(updatePolicy(minimum: '1.2.0'), '1.1.0')!.required, true);
    expect(evaluate(updatePolicy(mode: 'required'), '1.2.0')!.required, true);
    expect(evaluate(p, '1.10.0'), null);
    expect(evaluate(p, '2.0.0'), null);
    expect(
        evaluate(p, '0.9.0')!.releasesBehind, 0); // No invented release count.
  });
  test('disabled, unavailable, expired, inconsistent and wrong store ignored',
      () {
    for (final change in [
      {'enabled': false},
      {'storeAvailable': false},
      {'expiresAt': '2026-01-01T00:00:00Z'},
      {'minimumSupportedVersion': '2.0.0'},
      {'mode': 'unknown'},
      {
        'publishedReleases': ['1.0.0', '1.2.0', '1.1.0', '1.10.0']
      },
      {'storeUrl': 'https://example.com/app/id123456789'},
      {'storeUrl': 'https://apps.apple.com/developer/id999'}
    ]) {
      final p = updatePolicy();
      (p['ios'] as Map).addAll(change);
      expect(evaluate(p, '1.0.0'), null, reason: change.toString());
    }
  });
  test(
      'throttle, per-session dismissal, refreshed mandatory notice and fail open',
      () async {
    var time = now;
    var calls = 0;
    var failed = false;
    var mode = 'optional';
    final service = AppUpdateService(
        platform: 'ios',
        now: () => time,
        version: () async => '1.0.0',
        client: MockClient((_) async {
          calls++;
          return failed
              ? http.Response('bad', 503)
              : http.Response.bytes(
                  utf8.encode(jsonEncode({
                    ...updatePolicy(mode: mode),
                    'appId': AppConfig.bundleId
                  })),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await service.check();
    expect(service.notice, isNotNull);
    service.dismiss();
    expect(service.notice, null);
    await service.check();
    expect(calls, 1);
    time = time.add(const Duration(hours: 6));
    await service.check();
    expect(calls, 2);
    expect(service.notice, null);
    mode = 'required';
    await service.check(force: true);
    expect(service.notice!.required, true);
    service.dismiss();
    expect(service.notice, isNotNull);
    failed = true;
    await service.check(force: true);
    expect(service.notice, null);
    service.dispose();
  });
  test('malformed policy and package-info failure never block', () async {
    final service = AppUpdateService(
        platform: 'ios',
        version: () async => throw StateError('unavailable'),
        client: MockClient((_) async => http.Response('{}', 200)));
    await service.check();
    expect(service.notice, null);
    expect(service.busy, false);
    service.dispose();
  });
}
