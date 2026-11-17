import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt in per generated app only after installing its native Firebase config.
class AnalyticsService extends ChangeNotifier {
  AnalyticsService._();
  static final instance = AnalyticsService._();
  static const enabled = bool.fromEnvironment('FIREBASE_ANALYTICS_ENABLED');
  FirebaseAnalytics? _analytics;
  NavigatorObserver? _observer;
  static const _consentKey = 'analytics.basic_measurement_consent.v1';
  bool needsConsentChoice = true;
  bool _enabled = false;
  bool get enabledForUsage => _enabled;
  bool get isReady => _analytics != null;
  NavigatorObserver? get observer => _observer;

  Future<void> init() async {
    if (!enabled ||
        isReady ||
        kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android)) {
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      needsConsentChoice = !preferences.containsKey(_consentKey);
      _enabled = preferences.getBool(_consentKey) ?? false;
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(false);
      await _analytics!.setConsent(
        adStorageConsentGranted: false,
        adUserDataConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        analyticsStorageConsentGranted: _enabled,
      );
      await _analytics!.setAnalyticsCollectionEnabled(_enabled);
      if (_enabled) {
        await _analytics!.logAppOpen();
        _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      }
      notifyListeners();
    } catch (error) {
      _analytics = null;
      _observer = null;
      debugPrint('Firebase Analytics initialization failed: $error');
    }
  }

  Future<void> setUsageConsent(bool enabled) async {
    _enabled = enabled;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_consentKey, enabled);
    needsConsentChoice = false;
    final analytics = _analytics;
    if (analytics == null) return;
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setConsent(
      analyticsStorageConsentGranted: enabled,
      adStorageConsentGranted: false,
      adUserDataConsentGranted: false,
      adPersonalizationSignalsConsentGranted: false,
    );
    await analytics.setAnalyticsCollectionEnabled(enabled);
    _observer =
        enabled ? FirebaseAnalyticsObserver(analytics: analytics) : null;
    notifyListeners();
  }

  /// Use stable screen names only; exclude account IDs, searches and location.
  Future<void> logScreen(String name) async {
    if (!_enabled) return;
    try {
      await _analytics?.logScreenView(screenName: name);
    } catch (error) {
      debugPrint('Analytics screen event failed: $error');
    }
  }
}
