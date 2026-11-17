import 'package:flutter_reusable_mobile_template/services/store_links.dart';
import 'package:flutter_reusable_mobile_template/l10n/app_language.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reusable_mobile_template/config/app_config.dart';
import 'package:flutter_reusable_mobile_template/widgets/support_prompt.dart';

const testLinks = StoreLinks(
    appleAppUrl: 'https://apps.apple.com/app/id123',
    googleAppUrl: 'https://play.google.com/store/apps/details?id=example.test',
    appleDeveloperUrl: 'https://apps.apple.com/developer/id456',
    googleDeveloperUrl: 'https://play.google.com/store/apps/dev?id=123');
void main() {
  test('support popup cadence respects dismissal and completion', () {
    expect(supportPromptDue(2, 0, false), isFalse);
    expect(supportPromptDue(3, 0, false), isTrue);
    expect(supportPromptDue(5, 3, false), isFalse);
    expect(supportPromptDue(6, 3, false), isTrue);
    expect(supportPromptDue(20, 3, true), isFalse);
  });

  testWidgets('rating popup omits rewards and dismissal postpones it',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'${AppConfig.bundleId}.support.opens': 2});
    await tester.pumpWidget(const MaterialApp(
        home: SupportPrompt(
            links: testLinks, child: Scaffold(body: Text('Home')))));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Reward'), findsNothing);
    await tester.tap(find.text(tr('Later')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('${AppConfig.bundleId}.support.postponed'), 3);
    expect(prefs.getBool('${AppConfig.bundleId}.support.completed'), isNull);
  });

  testWidgets('render support popup at narrow, landscape and enlarged sizes',
      (tester) async {
    await AppLanguage.instance
        .select(const bool.fromEnvironment('SUPPORT_QA_VI') ? 'vi' : 'en');
    addTearDown(() => AppLanguage.instance.select('en'));
    final fontPath = Platform.environment['QA_FONT_PATH']!;
    await tester.runAsync(() async {
      await (FontLoader('PreviewSans')
            ..addFont(Future.value(
                ByteData.sublistView(await File(fontPath).readAsBytes()))))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(844, 390)
    ]) {
      for (final scale in [1.0, 1.5]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        SharedPreferences.setMockInitialValues(
            {'${AppConfig.bundleId}.support.opens': 2});
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                theme: ThemeData(fontFamily: 'PreviewSans', useMaterial3: true),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: const SupportPrompt(
                    links: testLinks, child: Scaffold(body: Text('Home'))))));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '/tmp/${AppConfig.bundleId}-support-${size.width.toInt()}-$scale.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(tr('Later')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !const bool.fromEnvironment('RENDER_SUPPORT_QA'));
}
