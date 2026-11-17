import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';

class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  bool _initialized = false;
  bool _isPro = false;
  bool _busy = false;
  String? _message;
  Offerings? _offerings;

  bool get isPro => _isPro;
  bool get isPremium => _isPro;
  bool get busy => _busy;
  String? get message => _message;
  Package? get proPackage {
    final packages = _offerings?.current?.availablePackages;
    if (packages == null || packages.isEmpty) return null;
    return packages.first;
  }

  Future<void> init() async {
    if (_initialized || !AppConfig.revenueCatEnabled || !AppConfig.proEnabled) {
      return;
    }
    _initialized = true;
    final key = Platform.isIOS
        ? AppConfig.revenueCatAppleApiKey
        : AppConfig.revenueCatGoogleApiKey;
    if (key.isEmpty) {
      _message = 'RevenueCat key missing.';
      notifyListeners();
      return;
    }
    try {
      await Purchases.configure(PurchasesConfiguration(key));
      Purchases.addCustomerInfoUpdateListener(_applyCustomerInfo);
      _applyCustomerInfo(await Purchases.getCustomerInfo());
      _offerings = await Purchases.getOfferings();
      notifyListeners();
    } catch (e) {
      debugPrint('RevenueCat init failed: $e');
      _message = 'Purchases are unavailable right now.';
      notifyListeners();
    }
  }

  Future<void> buyPro() async {
    if (_busy || _isPro) return;
    final package = proPackage;
    if (package == null) {
      _message = 'No Pro package found in RevenueCat.';
      notifyListeners();
      return;
    }
    _setBusy(true);
    try {
      final info = await Purchases.purchasePackage(package);
      _applyCustomerInfo(info);
      _setBusy(
        false,
        message: _isPro
            ? 'Pro unlocked.'
            : 'Purchase finished, but Pro is not active yet.',
      );
    } catch (e) {
      debugPrint('Purchase failed: $e');
      _setBusy(false, message: 'Purchase canceled or failed.');
    }
  }

  Future<void> restorePurchases() async {
    if (_busy) return;
    _setBusy(true);
    try {
      _applyCustomerInfo(await Purchases.restorePurchases());
      _setBusy(
        false,
        message: _isPro
            ? 'Purchase restored.'
            : 'No active Pro purchase found.',
      );
    } catch (e) {
      debugPrint('Restore failed: $e');
      _setBusy(false, message: 'Could not restore purchases.');
    }
  }

  Future<void> logInRevenueCat(String appUserId) async {
    if (!AppConfig.revenueCatEnabled || appUserId.isEmpty) return;
    final result = await Purchases.logIn(appUserId);
    _applyCustomerInfo(result.customerInfo);
  }

  void _applyCustomerInfo(CustomerInfo info) {
    _isPro = info.entitlements.active.containsKey(
      AppConfig.revenueCatEntitlementId,
    );
    notifyListeners();
  }

  void _setBusy(bool value, {String? message}) {
    _busy = value;
    _message = message;
    notifyListeners();
  }
}
