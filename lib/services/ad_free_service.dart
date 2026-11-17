import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdFreeService extends ChangeNotifier {
  AdFreeService();
  static final instance = AdFreeService();
  DateTime? _until;
  Timer? _expiry;
  DateTime? get until => active ? _until : null;
  bool get active => _until?.isAfter(DateTime.now()) == true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt('ad_free_until');
    _until = value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    _schedule();
    notifyListeners();
  }

  Future<void> grant() async {
    _until = DateTime.now().add(const Duration(minutes: 15));
    _schedule();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ad_free_until', _until!.millisecondsSinceEpoch);
  }

  void _schedule() {
    _expiry?.cancel();
    if (active) {
      _expiry = Timer(_until!.difference(DateTime.now()), notifyListeners);
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }
}
