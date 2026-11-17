import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reads/requests iOS ATT. ATT governs IDFA tracking; it is not the ad gate.
///
/// The system alert can only appear while the application is active. It is a
/// one-time prompt, so denied, restricted, and authorized states are returned
/// without attempting to present it again.
class TrackingConsentService {
  TrackingConsentService._();

  static Future<TrackingStatus?> requestIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;

    try {
      await _waitUntilResumed();

      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return status;

      // The first frame is already scheduled by main.dart. A short delay gives
      // UIKit time to finish making the Flutter view controller presentable.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return status;
    } on MissingPluginException catch (error) {
      debugPrint('ATT plugin is unavailable: $error');
      return null;
    } on PlatformException catch (error) {
      debugPrint('ATT request failed: ${error.code} ${error.message}');
      return null;
    }
  }

  /// Reads ATT again after returning from Settings. Ads remain governed by UMP.
  static Future<TrackingStatus?> currentStatus() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } on MissingPluginException catch (error) {
      debugPrint('ATT plugin is unavailable: $error');
      return null;
    } on PlatformException catch (error) {
      debugPrint('ATT status read failed: ${error.code} ${error.message}');
      return null;
    }
  }

  static Future<void> _waitUntilResumed() async {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == AppLifecycleState.resumed) return;

    final completer = Completer<void>();
    late final _ResumeObserver observer;
    observer = _ResumeObserver(() {
      binding.removeObserver(observer);
      if (!completer.isCompleted) completer.complete();
    });
    binding.addObserver(observer);

    // Close the small race between the initial check and observer install.
    if (binding.lifecycleState == AppLifecycleState.resumed) {
      binding.removeObserver(observer);
      completer.complete();
    }
    await completer.future;
  }
}

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResumed);

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}
