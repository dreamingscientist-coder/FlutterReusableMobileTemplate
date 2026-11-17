import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reusable_mobile_template/services/store_links.dart';

void main() {
  test('review routes directly using the listing app ID', () {
    const links = StoreLinks(
        appleAppUrl: 'https://apps.apple.com/fr/app/my-app/id123?uo=4');
    expect(links.nativeRating(TargetPlatform.iOS).toString(),
        'itms-apps://apps.apple.com/app/id123?action=write-review');
    expect(links.rating(TargetPlatform.iOS).toString(),
        'https://apps.apple.com/app/id123?action=write-review');
  });

  test('template does not inherit another app listing', () {
    const links = StoreLinks();
    expect(links.listing(TargetPlatform.iOS), isNull);
    expect(links.rating(TargetPlatform.android), isNull);
    expect(links.developer(TargetPlatform.iOS), isNull);
  });
  test('configured review and share use the same app', () {
    const links = StoreLinks(
      appleAppUrl: 'https://apps.apple.com/app/id123',
      googleAppUrl: 'https://play.google.com/store/apps/details?id=example.app',
    );
    expect(links.rating(TargetPlatform.iOS)!.scheme, 'https');
    expect(links.rating(TargetPlatform.iOS)!.path, '/app/id123');
    expect(links.rating(TargetPlatform.iOS)!.queryParameters['action'],
        'write-review');
    expect(links.listing(TargetPlatform.iOS)!.queryParameters, isEmpty);
    expect(links.listing(TargetPlatform.android)!.queryParameters['id'],
        'example.app');
  });
}
