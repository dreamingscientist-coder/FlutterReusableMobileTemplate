import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reusable_mobile_template/services/ad_test_devices.dart';

void main() {
  test('accepts SDK hashes, trims and deduplicates', () {
    expect(
        AdTestDevices.parse(
            ' abcdef0123456789abcdef0123456789,abcdef0123456789abcdef0123456789 ,'),
        ['abcdef0123456789abcdef0123456789']);
    expect(AdTestDevices.parse(''), isEmpty);
  });
  test('rejects web-console IDFA instead of pretending it registers a device',
      () {
    expect(() => AdTestDevices.parse('969233AB-2404-4CBD-92FC-C1C1E32B2D80'),
        throwsFormatException);
    expect(() => AdTestDevices.parse('bad'), throwsFormatException);
  });
}
