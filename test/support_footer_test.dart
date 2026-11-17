import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_reusable_mobile_template/widgets/app_support_footer.dart';

void main() {
  testWidgets('banner footer has no action row at large text size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          size: Size(320, 640), textScaler: TextScaler.linear(2.4)),
      child: Scaffold(
          bottomNavigationBar: AppSupportFooter(
        banner: SizedBox(key: ValueKey('test-banner'), height: 50),
      )),
    )));
    expect(find.byType(Wrap), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    final section = find.byKey(const ValueKey('blue-bottom-section'));
    expect(tester.getSize(section).height, 50);
    expect(
        find.descendant(
            of: section, matching: find.byKey(const ValueKey('test-banner'))),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('secondary screen footer contains only the banner on blue',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            bottomNavigationBar: AppSupportFooter(
                banner: SizedBox(key: ValueKey('test-banner'), height: 50)))));
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const ValueKey('blue-bottom-section')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
