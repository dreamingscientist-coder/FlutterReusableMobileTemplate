import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_reusable_mobile_template/l10n/app_language.dart';
import 'package:flutter_reusable_mobile_template/screens/settings_screen.dart';

void main() {
  testWidgets('render persisted language selector with app font',
      (tester) async {
    final font = File(Platform.environment['QA_FONT_PATH']!);
    await tester.runAsync(() async {
      await (FontLoader('Roboto')
            ..addFont(
                Future.value(ByteData.sublistView(await font.readAsBytes()))))
          .load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    SharedPreferences.setMockInitialValues({});
    final out = Directory('/tmp/template-language-qa');
    await tester.runAsync(() => out.create(recursive: true));
    for (final lang in ['en', 'vi']) {
      await AppLanguage.instance.select(lang);
      for (final size in [
        const Size(320, 640),
        const Size(390, 844),
        const Size(844, 390)
      ]) {
        for (final scale in [1.0, 1.5]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
              key: key,
              child: MaterialApp(
                  key: UniqueKey(),
                  locale: AppLanguage.instance.locale,
                  supportedLocales: const [Locale('en'), Locale('vi')],
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: const SettingsScreen())));
          await tester.pumpAndSettle();
          expect(find.text(tr('Language')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final img = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File('${out.path}/$lang-${size.width.toInt()}-$scale.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
    await AppLanguage.instance.select('en');
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: !const bool.fromEnvironment('RENDER_LANGUAGE_QA'));
}
