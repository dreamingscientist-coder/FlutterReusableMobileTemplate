import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reusable_mobile_template/config/app_config.dart';
import 'package:flutter_reusable_mobile_template/services/development_settings.dart';
import 'package:flutter_reusable_mobile_template/screens/settings_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevelopmentSettings.instance.init();
  });
  test('debug preference persists and cannot affect release builds', () async {
    final settings = DevelopmentSettings();
    await settings.init();
    expect(settings.showTestBanner, isFalse);
    await settings.setShowTestBanner(true);
    final restored = DevelopmentSettings();
    await restored.init();
    expect(restored.showTestBanner, isTrue);
    final release = DevelopmentSettings(isDebugBuild: false);
    await release.init();
    await release.setShowTestBanner(false);
    expect(release.showTestBanner, isFalse);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('developer_show_test_banner'),
        isTrue);
    settings.dispose();
    restored.dispose();
    release.dispose();
  });
  testWidgets('Settings switch shows and removes the banner immediately',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('debug-banner-toggle'));
    expect(toggle, findsOneWidget);
    expect(find.byKey(const ValueKey('banner-slot')), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('banner-slot')), findsOneWidget);
    expect(find.text('Test banner preview · waiting for ad'), findsOneWidget);
    expect(
        AppConfig.bannerAdUnitId, startsWith('ca-app-pub-3940256099942544/'));
    expect(
        (await SharedPreferences.getInstance())
            .getBool('developer_show_test_banner'),
        isTrue);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('banner-slot')), findsNothing);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('developer_show_test_banner'),
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('render debug Settings and test-banner preview', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader('Roboto')
            ..addFont(Future.value(ByteData.sublistView(
                await File(Platform.environment['QA_FONT_PATH']!)
                    .readAsBytes()))))
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
        await DevelopmentSettings.instance.setShowTestBanner(false);
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              theme: ThemeData(useMaterial3: true, fontFamily: 'Roboto'),
              home: const SettingsScreen(),
            )));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('debug-banner-toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('banner-slot')), findsOneWidget);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
                  '/tmp/${AppConfig.bundleId}-banner-settings-${size.width.toInt()}-$scale.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !const bool.fromEnvironment('RENDER_BANNER_QA'));
}
