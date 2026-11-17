import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import 'ads_service.dart';
import 'ad_free_service.dart';

class RewardedAdService {
  RewardedAdService._();
  static final RewardedAdService instance = RewardedAdService._();

  RewardedAd? _ad;
  bool _loading = false;
  int _generation = 0;
  RewardedAd? _presentedAd;

  void preload() {
    if (!AppConfig.rewardedAdsEnabled ||
        !AdsService.instance.canRequestReward ||
        _ad != null ||
        _loading) {
      return;
    }
    _loading = true;
    final generation = _generation;
    RewardedAd.load(
      adUnitId: AppConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (generation != _generation) {
            ad.dispose();
            return;
          }
          _loading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          if (generation != _generation) return;
          debugPrint('Rewarded ad failed: ${error.code} ${error.message}');
          _loading = false;
        },
      ),
    );
  }

  void revoke() {
    _generation++;
    _ad?.dispose();
    _presentedAd?.dispose();
    _ad = null;
    _presentedAd = null;
    _loading = false;
  }

  Future<bool> show({required VoidCallback onReward}) async {
    if (!AppConfig.rewardedAdsEnabled ||
        !AdsService.instance.canRequestReward) {
      return false;
    }
    final ad = _ad;
    if (ad == null) {
      preload();
      return false;
    }
    _ad = null;
    _presentedAd = ad;
    final generation = _generation;
    var earned = false;
    final completed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (generation != _generation) return;
        _presentedAd = null;
        if (!completed.isCompleted) completed.complete(earned);
        preload();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded ad show failed: ${error.code} ${error.message}');
        ad.dispose();
        if (generation != _generation) return;
        _presentedAd = null;
        if (!completed.isCompleted) completed.complete(earned);
        preload();
      },
    );
    await ad.show(
      onUserEarnedReward: (_, __) {
        if (generation != _generation) return;
        earned = true;
        AdFreeService.instance.grant();
        onReward();
      },
    );
    return completed.future;
  }
}
