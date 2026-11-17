import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../services/ads_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  Timer? _delay;
  bool _loaded = false;
  bool _delayFinished = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    AdsService.instance.addListener(_onAdsStateChanged);
    _delay = Timer(AppConfig.bannerInitialDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _delayFinished = true);
      _loadIfNeeded();
    });
  }

  void _onAdsStateChanged() {
    if (!mounted) {
      return;
    }
    if (AdsService.instance.canShowAds) {
      _loadIfNeeded();
    } else {
      _removeAd();
    }
  }

  void _loadIfNeeded() {
    if (!_delayFinished || !AdsService.instance.canShowAds || _ad != null) {
      return;
    }
    final generation = _generation;
    final ad = BannerAd(
      adUnitId: AppConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || generation != _generation || !identical(ad, _ad)) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed: ${error.code} ${error.message}');
          ad.dispose();
          if (generation == _generation && identical(ad, _ad) && mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  void _removeAd() {
    _generation++;
    final old = _ad;
    _ad = null;
    _loaded = false;
    old?.dispose();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    AdsService.instance.removeListener(_onAdsStateChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded || !AdsService.instance.canShowAds) {
      if (!AdsService.instance.showBannerPreview) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        key: const ValueKey('banner-slot'),
        height: AppConfig.bannerHeight.toDouble(),
        child: const Center(
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Test banner preview · waiting for ad',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 12)))),
      );
    }
    return SizedBox(
      key: const ValueKey('banner-slot'),
      height: AppConfig.bannerHeight.toDouble(),
      width: double.infinity,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: AppConfig.bannerHeight.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
