import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reusable_mobile_template/services/ad_free_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reward grants 15 minutes and survives restart', () async {
    SharedPreferences.setMockInitialValues({});
    final service = AdFreeService();
    await service.init();
    expect(service.active, isFalse);
    await service.grant();
    expect(service.until!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(898, 900));
    final restored = AdFreeService();
    await restored.init();
    expect(restored.until!.millisecondsSinceEpoch,
        service.until!.millisecondsSinceEpoch);
    service.dispose();
    restored.dispose();
  });
  test('expired reward does not suppress ads', () async {
    SharedPreferences.setMockInitialValues({
      'ad_free_until': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .millisecondsSinceEpoch
    });
    final service = AdFreeService();
    await service.init();
    expect(service.active, isFalse);
    expect(service.until, isNull);
    service.dispose();
  });
}
