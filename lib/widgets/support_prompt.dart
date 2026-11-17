import '../l10n/app_language.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/store_links.dart';
import '../services/store_review_launcher.dart';
import '../services/rewarded_ad_service.dart';

/// Per-install cadence. Dismissal postpones; only a successful store launch completes.
bool supportPromptDue(int opens, int postponed, bool completed) =>
    !completed && opens >= 3 && opens - postponed >= 3;

Future<void> showAdBreakOffer(BuildContext context) async {
  final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: const AppText('15 minutes without ads'),
            content: const SingleChildScrollView(
                child: AppText(
                    'Watch one optional rewarded ad to hide banners and automatic ads for 15 minutes on this device.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const AppText('Not now')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const AppText('Watch ad')),
            ],
          ));
  if (accepted != true || !context.mounted) return;
  final earned = await RewardedAdService.instance.show(onReward: () {});
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: AppText(earned
          ? 'Enjoy 15 minutes without ads.'
          : 'Ad unavailable or reward not earned. Please try again later.')));
}

Future<void> maybeShowSupportPrompt(BuildContext context,
    {StoreLinks links = const StoreLinks()}) async {
  if (kIsWeb) return;
  final platform = defaultTargetPlatform;
  final listing = links.listing(platform);
  final rating = links.rating(platform);
  final developer = links.developer(platform);
  if (listing == null && rating == null && developer == null) return;
  final prefs = await SharedPreferences.getInstance();
  const prefix = '${AppConfig.bundleId}.support';
  final opens = (prefs.getInt('$prefix.opens') ?? 0) + 1;
  await prefs.setInt('$prefix.opens', opens);
  const force = bool.fromEnvironment('SHOW_SUPPORT_PROMPT') ||
      bool.fromEnvironment('TEMPLATE_SHOW_PROMPT');
  if (!(kDebugMode && force) &&
      !supportPromptDue(opens, prefs.getInt('$prefix.postponed') ?? 0,
          prefs.getBool('$prefix.completed') ?? false)) {
    return;
  }
  if (!context.mounted) return;
  final answer = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: const AppText('Enjoying this app?'),
            content: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  const AppText(
                      'Support this app by rating it, sharing it, or exploring more apps.'),
                  const SizedBox(height: 16),
                  Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (rating != null)
                          TextButton.icon(
                              onPressed: () => Navigator.pop(dialog, 'rate'),
                              icon: const Icon(Icons.star_outline),
                              label: const AppText('Rate')),
                        if (listing != null)
                          TextButton.icon(
                              onPressed: () => Navigator.pop(dialog, 'share'),
                              icon: const Icon(Icons.share_outlined),
                              label: const AppText('Share')),
                        if (developer != null)
                          TextButton.icon(
                              onPressed: () => Navigator.pop(dialog, 'more'),
                              icon: const Icon(Icons.apps_outlined),
                              label: const AppText('More apps')),
                      ]),
                ])),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const AppText('Later')),
            ],
          ));
  // Every dismissal/action starts another three-open cooldown.
  await prefs.setInt('$prefix.postponed', opens);
  if (!context.mounted) return;
  var succeeded = true;
  try {
    if (answer == 'rate') {
      succeeded = await openStoreReview(links, platform);
      if (succeeded) await prefs.setBool('$prefix.completed', true);
    } else if (answer == 'share' && listing != null) {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
          text: listing.toString(),
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    } else if (answer == 'more' && developer != null) {
      succeeded =
          await launchUrl(developer, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    succeeded = false;
  }
  if (!succeeded && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: AppText('Could not open. Please try again later.')));
  }
}

/// Put around the home route, below MaterialApp's navigator.
class SupportPrompt extends StatefulWidget {
  const SupportPrompt(
      {super.key, required this.child, this.links = const StoreLinks()});
  final StoreLinks links;
  final Widget child;
  @override
  State<SupportPrompt> createState() => _SupportPromptState();
}

class _SupportPromptState extends State<SupportPrompt> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await maybeShowSupportPrompt(context, links: widget.links);
      } catch (_) {
        // A preference failure must not prevent using the app.
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
