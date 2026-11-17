import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// SDK console hashes, not IDFA/advertising IDs from the AdMob web console.
class AdTestDevices {
  static const _ids = String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');
  static const _enabled = bool.fromEnvironment('ADMOB_ENABLE_TEST_DEVICES');

  static List<String> parse(String value) {
    final ids = value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    for (final id in ids) {
      if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(id)) {
        throw const FormatException(
            'Use the 32-character test-device hash printed by the Mobile Ads SDK, not an IDFA.');
      }
    }
    return ids.toList(growable: false);
  }

  /// Release/TestFlight builds require explicit opt-in. Configure before loading ads.
  static Future<void> configure() async {
    if (!kDebugMode && !_enabled) return;
    final ids = parse(_ids);
    if (ids.isNotEmpty) {
      await MobileAds.instance
          .updateRequestConfiguration(RequestConfiguration(testDeviceIds: ids));
    }
  }
}
