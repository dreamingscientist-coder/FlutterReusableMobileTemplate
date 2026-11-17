import 'package:flutter_reusable_mobile_template/services/store_links.dart';
import 'package:flutter_reusable_mobile_template/services/store_review_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('failed native review never sends the review query to Safari', () async {
    const links =
        StoreLinks(appleAppUrl: 'https://apps.apple.com/fr/app/my-app/id123');
    final attempts = <(Uri, LaunchMode)>[];
    expect(
      await openStoreReview(
        links,
        TargetPlatform.iOS,
        launcher: (uri, mode) async {
          attempts.add((uri, mode));
          return attempts.length == 3;
        },
      ),
      isTrue,
    );
    expect(attempts[0].$1.scheme, 'itms-apps');
    expect(attempts[0].$1.host, 'apps.apple.com');
    expect(attempts[1].$2, LaunchMode.externalNonBrowserApplication);
    expect(attempts[2].$1, links.listing(TargetPlatform.iOS));
    expect(attempts[2].$1.queryParameters.containsKey('action'), isFalse);
  });
  test(
    'successful native launch stops; plugin failures use the listing fallback',
    () async {
      var calls = 0;
      expect(
        await openStoreReview(
          const StoreLinks(
              appleAppUrl: 'https://apps.apple.com/fr/app/my-app/id123'),
          TargetPlatform.iOS,
          launcher: (uri, mode) async {
            calls++;
            return true;
          },
        ),
        isTrue,
      );
      expect(calls, 1);
      calls = 0;
      expect(
        await openStoreReview(
          const StoreLinks(
              appleAppUrl: 'https://apps.apple.com/fr/app/my-app/id123'),
          TargetPlatform.iOS,
          launcher: (uri, mode) async {
            calls++;
            if (calls < 3) throw StateError('unavailable');
            return true;
          },
        ),
        isTrue,
      );
      expect(calls, 3);
    },
  );
}
