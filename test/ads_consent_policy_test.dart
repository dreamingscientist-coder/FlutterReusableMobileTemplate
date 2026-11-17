import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reusable_mobile_template/services/tracking_consent_service.dart';

void main() {
  test('ATT status is separate from UMP ad eligibility', () {
    expect(TrackingConsentService.currentStatus, isA<Function>());
    // AdsService separately checks UMP canRequestAds.
  });
}
