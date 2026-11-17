import 'store_links_config.dart';

import 'package:flutter/foundation.dart';

/// Supply the published listing links through --dart-define. Keep unconfigured
/// actions disabled instead of sending users to an unrelated store listing.
class StoreLinks {
  const StoreLinks({
    this.appleAppUrl = const String.fromEnvironment(
      'APPLE_APP_STORE_URL',
      defaultValue: StoreLinksConfig.appleAppUrl,
    ),
    this.googleAppUrl = const String.fromEnvironment(
      'GOOGLE_PLAY_APP_URL',
      defaultValue: StoreLinksConfig.googleAppUrl,
    ),
    this.appleDeveloperUrl = const String.fromEnvironment(
      'APPLE_DEVELOPER_URL',
      defaultValue: StoreLinksConfig.appleDeveloperUrl,
    ),
    this.googleDeveloperUrl = const String.fromEnvironment(
      'GOOGLE_PLAY_DEVELOPER_URL',
      defaultValue: StoreLinksConfig.googleDeveloperUrl,
    ),
  });
  final String appleAppUrl, googleAppUrl, appleDeveloperUrl, googleDeveloperUrl;

  Uri? _valid(String value, String host) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host == host
        ? uri
        : null;
  }

  Uri? rating(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      final app = _valid(appleAppUrl, 'apps.apple.com');
      if (app == null) return null;
      final id = RegExp(r'^id([0-9]+)$')
          .firstMatch(app.pathSegments.lastOrNull ?? '')
          ?.group(1);
      if (id == null) return null;
      // Review routing uses only the numeric app ID. Keep storefront URLs for sharing.
      return Uri.parse('https://apps.apple.com/app/id$id?action=write-review');
    }
    if (platform == TargetPlatform.android) {
      return _valid(googleAppUrl, 'play.google.com');
    }
    return null;
  }

  /// Direct App Store route to its Write a Review screen.
  Uri? nativeRating(TargetPlatform platform) {
    final review = rating(platform);
    if (review == null ||
        (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS)) {
      return null;
    }
    return review.replace(scheme: 'itms-apps', host: 'apps.apple.com');
  }

  /// Public listing URL, without the review query, for sharing.
  Uri? listing(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return _valid(appleAppUrl, 'apps.apple.com');
    }
    if (platform == TargetPlatform.android) {
      return _valid(googleAppUrl, 'play.google.com');
    }
    return null;
  }

  Uri? developer(TargetPlatform platform) {
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return _valid(appleDeveloperUrl, 'apps.apple.com');
    }
    if (platform == TargetPlatform.android) {
      return _valid(googleDeveloperUrl, 'play.google.com');
    }
    return null;
  }
}
