import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vi.dart';

/// One persisted language preference shared by every route and UI label.
class AppLanguage extends ChangeNotifier {
  AppLanguage();
  static final instance = AppLanguage();
  String _code = 'en';
  String get code => _code;
  Locale get locale => Locale(_code);
  Future<void> init() async {
    final saved =
        (await SharedPreferences.getInstance()).getString('app_language');
    _code = saved == 'vi' ? 'vi' : 'en';
    notifyListeners();
  }

  Future<void> select(String code) async {
    if (code != 'en' && code != 'vi') throw ArgumentError.value(code, 'code');
    if (code == _code) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('app_language', code)) {
      throw StateError('Could not save language');
    }
    _code = code;
    notifyListeners();
  }
}

String tr(String source) =>
    AppLanguage.instance.code == 'vi' ? vietnamese[source] ?? source : source;

/// English strings remain stable translation keys; const call sites are supported.
/// Listening here also updates already-open routes immediately on selection.
class AppText extends StatelessWidget {
  const AppText(this.data,
      {super.key,
      this.style,
      this.maxLines,
      this.overflow,
      this.textAlign,
      this.softWrap,
      this.semanticsLabel,
      this.translate = true});
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final String? semanticsLabel;
  final bool translate;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: AppLanguage.instance,
        builder: (context, _) => Text(translate ? tr(data) : data,
            style: style,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
            semanticsLabel:
                semanticsLabel == null ? null : tr(semanticsLabel!)),
      );
}

/// Rebuild route controls such as field hints, tooltips and painted chart labels.
mixin AppLanguageUpdates<T extends StatefulWidget> on State<T> {
  void _languageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    AppLanguage.instance.addListener(_languageChanged);
  }

  @override
  void dispose() {
    AppLanguage.instance.removeListener(_languageChanged);
    super.dispose();
  }
}
