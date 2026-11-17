// =====================================================================
// ads_service.dart — starts AdMob the legal way (EU/GDPR ready).
//
// Consent order:
//   1. On iOS, request App Tracking Transparency while the app is active.
//      ATT controls IDFA tracking; denial does not prohibit ads.
//   2. Ask Google's consent tool (UMP) if this user must see a consent
//      form (EU/UK users). If yes, the form is shown automatically.
//   3. Only when consent allows it → start the Mobile Ads SDK.
//   4. Banners check `canShowAds` before loading.
//
// The consent form itself is designed in AdMob:
//   admob.google.com → Privacy & messaging → GDPR (and "IDFA explainer"
//   for iOS). Without that message published, no form appears.
// =====================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import 'purchase_service.dart';
import 'ad_free_service.dart';
import 'rewarded_ad_service.dart';
import 'tracking_consent_service.dart';
import 'development_settings.dart';
import 'ad_test_devices.dart';

class AdsService extends ChangeNotifier with WidgetsBindingObserver {
  AdsService._() {
    WidgetsBinding.instance.addObserver(this);
    // When the user buys Premium, banners must disappear right away.
    DevelopmentSettings.instance.addListener(notifyListeners);
    PurchaseService.instance.addListener(notifyListeners);
    AdFreeService.instance.addListener(notifyListeners);
  }

  static final AdsService instance = AdsService._();

  bool _started = false;
  Future<void>? _testConfiguration;
  Future<void>? _sdkStart; // prevents starting the SDK twice
  bool _sdkReady = false;
  bool _consentFlowComplete = false;
  bool _consentFlowInProgress = false;
  bool _hasCompletedInitialFlow = false;

  bool _privacyOptionsRequired = false;

  /// True when the law requires a "Privacy choices" button in Settings.
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// Banners use this to decide if they may load.
  bool get canRequestReward =>
      AppConfig.adsEnabled && _sdkReady && !PurchaseService.instance.isPro;
  bool get canShowAds =>
      AppConfig.bannerAdsEnabled &&
      canRequestReward &&
      !AdFreeService.instance.active;
  bool get showBannerPreview =>
      kDebugMode &&
      AppConfig.bannerAdsEnabled &&
      !PurchaseService.instance.isPro &&
      !AdFreeService.instance.active;

  /// Called once from main.dart. Never throws.
  Future<void> init() async {
    if (!AppConfig.adsEnabled || _started) return;
    _started = true;
    _consentFlowInProgress = true;

    // ATT is separate from regional ad consent. Request it before UMP so two
    // sheets never compete. UMP decides whether ads may be requested; Google
    // documents that it omits IDFA from ad requests after ATT denial.
    await TrackingConsentService.requestIfNeeded();

    // Update consent info, then show the form if required.
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            debugPrint(
              'Consent form error: ${error.errorCode} ${error.message}',
            );
          }
          _consentFlowComplete = true;
          _consentFlowInProgress = false;
          _startSdkIfAllowed();
        });
      },
      (FormError error) {
        // No network etc. → Google says: try with last known consent.
        debugPrint('Consent update error: ${error.errorCode} ${error.message}');
        _consentFlowComplete = true;
        _consentFlowInProgress = false;
        _startSdkIfAllowed();
      },
    );

    // UMP may report a prior valid choice immediately after update begins.
    await _startSdkIfAllowed();
  }

  Future<void> _startSdkIfAllowed() async {
    try {
      // Do not start ads until the current launch's UMP refresh/form finishes.
      if (!_consentFlowComplete) return;
      if (!await ConsentInformation.instance.canRequestAds()) {
        _sdkReady = false;
        RewardedAdService.instance.revoke();
        notifyListeners();
        return;
      }
      _testConfiguration ??= AdTestDevices.configure();
      await _testConfiguration;
      _sdkStart ??= MobileAds.instance.initialize().then((_) {
        _sdkReady = true;
      });
      await _sdkStart;
      _hasCompletedInitialFlow = true;
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
      RewardedAdService.instance.preload();
      notifyListeners();
    } catch (e) {
      debugPrint('Ads start failed: $e');
    }
  }

  /// Opens the consent form again (the "Privacy choices" button).
  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint(
          'Privacy options error: ${error.errorCode} ${error.message}',
        );
      }
      // The user may have changed their choice → re-check.
      _consentFlowComplete = true;
      _startSdkIfAllowed();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        _sdkReady = false;
        RewardedAdService.instance.revoke();
        notifyListeners();
      }
    } else if (state == AppLifecycleState.resumed && _started) {
      unawaited(_refreshAfterResume());
    }
  }

  Future<void> _refreshAfterResume() async {
    await TrackingConsentService.currentStatus();
    if (_consentFlowInProgress) return;
    if (!_hasCompletedInitialFlow) {
      _started = false;
      await init();
      return;
    }
    try {
      if (!await ConsentInformation.instance.canRequestAds()) {
        _sdkReady = false;
        RewardedAdService.instance.revoke();
        notifyListeners();
        return;
      }
      _sdkStart ??= MobileAds.instance.initialize();
      await _sdkStart;
      _sdkReady = true;
      RewardedAdService.instance.preload();
      notifyListeners();
    } catch (error) {
      debugPrint('Ads resume check failed: $error');
      _sdkReady = false;
      notifyListeners();
    }
  }
}
