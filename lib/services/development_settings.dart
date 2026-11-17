import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug banner preview never changes production advertising or ad unit IDs.
class DevelopmentSettings extends ChangeNotifier {
  DevelopmentSettings({this.isDebugBuild = kDebugMode});
  static final instance = DevelopmentSettings();
  final bool isDebugBuild;
  bool _showTestBanner = false;
  bool get showTestBanner => isDebugBuild && _showTestBanner;

  Future<void> init() async {
    if (!isDebugBuild) return;
    _showTestBanner = (await SharedPreferences.getInstance())
            .getBool('developer_show_test_banner') ??
        false;
    notifyListeners();
  }

  Future<void> setShowTestBanner(bool value) async {
    if (!isDebugBuild || value == _showTestBanner) return;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool('developer_show_test_banner', value)) {
      throw StateError('Could not save banner preview');
    }
    _showTestBanner = value;
    notifyListeners();
  }
}
