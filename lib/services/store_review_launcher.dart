import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store_links.dart';

/// A write-review URL must reach the store, not a Safari page.
Future<bool> openStoreReview(
  StoreLinks links,
  TargetPlatform platform, {
  Future<bool> Function(Uri, LaunchMode)? launcher,
}) async {
  Future<bool> attempt(Uri? uri, LaunchMode mode) async {
    if (uri == null) return false;
    try {
      return await (launcher?.call(uri, mode) ?? launchUrl(uri, mode: mode));
    } catch (_) {
      return false;
    }
  }

  final apple =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  if (apple) {
    if (await attempt(
      links.nativeRating(platform),
      LaunchMode.externalApplication,
    )) {
      return true;
    }
    // Universal-link attempt may open the App Store, but must not open Safari.
    if (await attempt(
      links.rating(platform),
      LaunchMode.externalNonBrowserApplication,
    )) {
      return true;
    }
    // If direct review routing is unavailable, the known public listing works
    // in either the store or browser; users can choose Write a Review there.
    return attempt(links.listing(platform), LaunchMode.externalApplication);
  }
  return attempt(links.rating(platform), LaunchMode.externalApplication);
}
