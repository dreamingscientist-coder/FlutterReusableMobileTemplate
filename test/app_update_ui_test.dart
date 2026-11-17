import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reusable_mobile_template/l10n/app_language.dart';
import 'package:flutter_reusable_mobile_template/services/app_update_service.dart';
import 'package:flutter_reusable_mobile_template/widgets/app_update_gate.dart';

AppUpdateNotice notice(bool required) => AppUpdateNotice(
    latest: '1.10.0',
    required: required,
    releasesBehind: 3,
    storeUrl: Uri.parse('https://apps.apple.com/app/id123456789'));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'required notice blocks underlying interaction; optional can dismiss',
      (tester) async {
    var taps = 0;
    final service = AppUpdateService(platform: 'unsupported');
    service.notice = notice(true);
    await tester.pumpWidget(MaterialApp(
        home: AppUpdateGate(
            service: service,
            child: Scaffold(
                body: TextButton(
                    onPressed: () => taps++, child: const Text('Weather'))))));
    await tester.pump();
    expect(find.text('Later'), findsNothing);
    expect(find.text('Check again'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 0);
    service.notice = notice(false);
    service.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(service.notice, null);
    await tester.tap(find.text('Weather'));
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
  testWidgets('visual update cards in three languages and required sizes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await (FontLoader('Roboto')
            ..addFont(Future.value(ByteData.sublistView(
                await File(Platform.environment['QA_FONT_PATH']!)
                    .readAsBytes()))))
          .load();
    });
    final out = Directory('/tmp/template-update-qa');
    await tester.runAsync(() => out.create(recursive: true));
    for (final lang in ['en', 'vi']) {
      await AppLanguage.instance.select(lang);
      for (final size in [
        const Size(320, 640),
        const Size(390, 844),
        const Size(844, 390)
      ]) {
        for (final scale in [1.0, 1.5]) {
          for (final required in [false, true]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            final boundary = GlobalKey();
            await tester.pumpWidget(RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    locale: AppLanguage.instance.locale,
                    supportedLocales: const [Locale('en'), Locale('vi')],
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    theme: ThemeData(
                        useMaterial3: true,
                        fontFamily: 'Roboto',
                        colorSchemeSeed: const Color(0xff153c50)),
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: Scaffold(
                        body: SafeArea(
                            child: SingleChildScrollView(
                                child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: AppUpdateCard(
                                        notice: notice(required),
                                        onLater: required ? null : () {},
                                        onRetry: () {}))))))));
            await tester.pumpAndSettle();
            expect(tester.takeException(), null);
            await tester.runAsync(() async {
              final img = await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
              final bytes =
                  await img.toByteData(format: ui.ImageByteFormat.png);
              await File(
                      '${out.path}/$lang-${size.width.toInt()}-$scale-$required.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              img.dispose();
            });
            await tester.pumpWidget(const SizedBox.shrink());
          }
        }
      }
    }
    await AppLanguage.instance.select('en');
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !const bool.fromEnvironment('RENDER_UPDATE_QA'));
}
