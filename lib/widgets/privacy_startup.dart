import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import '../services/ads_service.dart';

/// Shows the first-use basic analytics choice before independently starting ads.
class PrivacyStartup extends StatefulWidget {
  const PrivacyStartup({super.key, required this.child});
  final Widget child;
  @override
  State<PrivacyStartup> createState() => _PrivacyStartupState();
}

class _PrivacyStartupState extends State<PrivacyStartup> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final analytics = AnalyticsService.instance;
    if (AnalyticsService.enabled) await analytics.init();
    if (analytics.needsConsentChoice && mounted) {
      final allow = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: const Text('Help improve this app?'),
                content: const Text(
                    'Allow basic usage measurement of sessions, engagement, and screens? This choice is separate from advertising and App Tracking Transparency. You can change it in Settings.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Not now')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Allow analytics')),
                ],
              ));
      await analytics.setUsageConsent(allow ?? false);
    }
    if (mounted) await AdsService.instance.init();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
