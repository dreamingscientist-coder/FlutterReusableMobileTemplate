// =====================================================================
// app_config.dart — THE ONE FILE TO EDIT PER APP
//
// `make setup` replaces this file for a new app. These defaults are safe
// for a template repo and can be edited after setup.
// =====================================================================
import 'dart:io' show Platform;
import '../services/development_settings.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' show Color;

class AppConfig {
  AppConfig._();

  static const String appName = 'My App';
  static const String bundleId = 'com.khacmuoivu.myapp';
  static const String developerName = 'Vu Khac';
  static const Color seedColor = Color(0xFF3F51B5);

  /// Internal stock/SKU prefix for your app family. Increment per new repo.
  static const String skuPrefix = 'VKM';
  static const int skuNumber = 1;
  static const String sku = '$skuPrefix$skuNumber';

  static const String supportEmail = 'support@example.com';
  static const String accountLinkingSupportEmail = supportEmail;
  static const String legalPagesUrl =
      'https://example.github.io/app-legal/myapp';

  static const String privacyPolicyUrl = '$legalPagesUrl/privacy.html';
  static const String termsOfUseUrl = '$legalPagesUrl/terms.html';
  static const String supportPageUrl = '$legalPagesUrl/support.html';
  static const String dataDeletionUrl = '$legalPagesUrl/delete-data.html';

  static String get purchaseHelpUrl => Platform.isIOS
      ? 'https://reportaproblem.apple.com'
      : 'https://play.google.com/store/account/orderhistory';

  static const bool adsEnabled = true;
  static bool get bannerAdsEnabled =>
      adsEnabled &&
      (!kDebugMode || DevelopmentSettings.instance.showTestBanner);
  static const bool rewardedAdsEnabled = true;
  static const bool signInEnabled = false;
  static const bool appleSignInEnabled = false;
  static const bool googleSignInEnabled = false;
  static const bool revenueCatEnabled = true;
  static const bool proEnabled = true;
  static const bool accountLinkingAfterPro = true;

  /// Bottom banner: fixed normal banner height, delayed after app open.
  static const int bannerHeight = 50;
  static const Duration bannerInitialDelay =
      Duration(seconds: kDebugMode ? 3 : 30);

  static const String _iosBannerId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );
  static const String _androidBannerId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const String _iosRewardedId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
  );
  static const String _androidRewardedId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
  );
  static const String _iosInterstitialId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_ID',
  );
  static const String _androidInterstitialId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
  );
  static const String _iosRewardedInterstitialId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_INTERSTITIAL_ID',
  );
  static const String _androidRewardedInterstitialId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_INTERSTITIAL_ID',
  );
  static const String _iosNativeId = String.fromEnvironment(
    'ADMOB_IOS_NATIVE_ID',
  );
  static const String _androidNativeId = String.fromEnvironment(
    'ADMOB_ANDROID_NATIVE_ID',
  );
  static const String _iosAppOpenId = String.fromEnvironment(
    'ADMOB_IOS_APP_OPEN_ID',
  );
  static const String _androidAppOpenId = String.fromEnvironment(
    'ADMOB_ANDROID_APP_OPEN_ID',
  );

  static const String _testIosBannerId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testAndroidBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testIosRewardedId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _testAndroidRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testAndroidInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testIosRewardedInterstitialId =
      'ca-app-pub-3940256099942544/6978759866';
  static const String _testAndroidRewardedInterstitialId =
      'ca-app-pub-3940256099942544/5354046379';
  static const String _testIosNativeId =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _testAndroidNativeId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testIosAppOpenId =
      'ca-app-pub-3940256099942544/5575463023';
  static const String _testAndroidAppOpenId =
      'ca-app-pub-3940256099942544/9257395921';

  static const bool _useLiveAds = bool.fromEnvironment('ADMOB_USE_LIVE');

  static String get bannerAdUnitId {
    final real = Platform.isIOS ? _iosBannerId : _androidBannerId;
    final test = Platform.isIOS ? _testIosBannerId : _testAndroidBannerId;
    if (kDebugMode || !_useLiveAds || real.isEmpty) return test;
    return real;
  }

  static String get rewardedAdUnitId {
    final real = Platform.isIOS ? _iosRewardedId : _androidRewardedId;
    final test = Platform.isIOS ? _testIosRewardedId : _testAndroidRewardedId;
    if (kDebugMode || !_useLiveAds || real.isEmpty) return test;
    return real;
  }

  static String get interstitialAdUnitId => _unitId(
        _iosInterstitialId,
        _androidInterstitialId,
        _testIosInterstitialId,
        _testAndroidInterstitialId,
      );
  static String get rewardedInterstitialAdUnitId => _unitId(
        _iosRewardedInterstitialId,
        _androidRewardedInterstitialId,
        _testIosRewardedInterstitialId,
        _testAndroidRewardedInterstitialId,
      );
  static String get nativeAdUnitId => _unitId(
        _iosNativeId,
        _androidNativeId,
        _testIosNativeId,
        _testAndroidNativeId,
      );
  static String get appOpenAdUnitId => _unitId(
        _iosAppOpenId,
        _androidAppOpenId,
        _testIosAppOpenId,
        _testAndroidAppOpenId,
      );

  static String _unitId(
    String ios,
    String android,
    String testIos,
    String testAndroid,
  ) {
    final real = Platform.isIOS ? ios : android;
    if (kDebugMode || !_useLiveAds || real.isEmpty) {
      return Platform.isIOS ? testIos : testAndroid;
    }
    return real;
  }

  static const String revenueCatAppleApiKey = '';
  static const String revenueCatGoogleApiKey = '';
  static const String revenueCatEntitlementId = 'pro';
  static const String proProductId = '$bundleId.pro';
}
