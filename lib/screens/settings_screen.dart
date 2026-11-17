import '../l10n/app_language.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/debug_banner_setting.dart';
import 'package:flutter/material.dart';
import '../services/analytics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import '../services/store_links.dart';
import '../services/store_review_launcher.dart';

import '../config/app_config.dart';
import '../config/app_strings.dart';
import '../services/ads_service.dart';
import '../services/auth_service.dart';
import '../services/link_service.dart';
import '../services/purchase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText(AppStrings.couldNotOpen)));
  }

  Future<void> _openWeb(BuildContext context, String url) async {
    final ok = await LinkService.openWeb(url);
    if (!ok && context.mounted) _showError(context);
  }

  Future<void> _emailSupport(
    BuildContext context, {
    bool accountLinking = false,
  }) async {
    final details = await LinkService.deviceInfoForSupport();
    final ok = await LinkService.sendEmail(
      to: accountLinking
          ? AppConfig.accountLinkingSupportEmail
          : AppConfig.supportEmail,
      subject:
          '${AppConfig.appName} - ${accountLinking ? AppStrings.accountLinkEmailSubject : AppStrings.supportEmailSubject}',
      body: '${AppStrings.supportEmailBody}$details',
    );
    if (!ok && context.mounted) {
      await _openWeb(context, AppConfig.supportPageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        PurchaseService.instance,
        AdsService.instance,
        AuthService.instance,
        AppLanguage.instance,
      ]),
      builder: (context, _) => AppScaffold(
        showSettings: false,
        appBar: AppBar(title: const AppText(AppStrings.settings)),
        body: ListView(
          children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppText('Language'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'en', label: Text('English')),
                            ButtonSegment(
                                value: 'vi', label: Text('Tiếng Việt')),
                          ],
                          selected: {
                            AppLanguage.instance.code
                          },
                          onSelectionChanged: (value) =>
                              AppLanguage.instance.select(value.first)),
                    ])),
            if (kDebugMode) ...[
              const _SectionTitle('Developer preview'),
              const DebugBannerSetting(),
            ],
            if (AppConfig.proEnabled) ..._proSection(context),
            if (_shouldShowAccountSection) ..._accountSection(context),
            ..._storeSection(context),
            ..._helpSection(context),
            ..._legalSection(context),
            ..._aboutSection(),
          ],
        ),
      ),
    );
  }

  bool get _shouldShowAccountSection =>
      AppConfig.signInEnabled &&
      (!AppConfig.accountLinkingAfterPro || PurchaseService.instance.isPro);

  List<Widget> _proSection(BuildContext context) {
    final purchases = PurchaseService.instance;
    final package = purchases.proPackage;
    return [
      const _SectionTitle(AppStrings.sectionPremium),
      if (purchases.isPro)
        const ListTile(
          leading: Icon(Icons.verified_outlined),
          title: AppText(AppStrings.premiumActive),
        )
      else
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const AppText(AppStrings.buyPremium),
          subtitle: const AppText(AppStrings.buyPremiumSubtitle),
          trailing: purchases.busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (package == null
                  ? null
                  : AppText(package.storeProduct.priceString)),
          enabled: !purchases.busy,
          onTap: purchases.buyPro,
        ),
      ListTile(
        leading: const Icon(Icons.restore),
        title: const AppText(AppStrings.restorePurchases),
        subtitle: const AppText(AppStrings.restoreSubtitle),
        enabled: !purchases.busy,
        onTap: purchases.restorePurchases,
      ),
      if (purchases.message != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: AppText(
            purchases.message!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  List<Widget> _accountSection(BuildContext context) {
    final auth = AuthService.instance;
    final user = auth.user;
    return [
      const _SectionTitle(AppStrings.sectionAccount),
      if (user != null)
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: const AppText(AppStrings.signedIn),
          subtitle: AppText(user.email ?? user.uid),
          trailing: TextButton(
            onPressed: auth.signOut,
            child: const AppText(AppStrings.signOut),
          ),
        )
      else ...[
        if (AppConfig.appleSignInEnabled)
          ListTile(
            leading: const Icon(Icons.apple),
            title: const AppText(AppStrings.linkWithApple),
            enabled: !auth.busy,
            onTap: auth.signInWithApple,
          ),
        if (AppConfig.googleSignInEnabled)
          ListTile(
            leading: const Icon(Icons.g_mobiledata),
            title: const AppText(AppStrings.linkWithGoogle),
            enabled: !auth.busy,
            onTap: auth.signInWithGoogle,
          ),
      ],
      ListTile(
        leading: const Icon(Icons.support_agent_outlined),
        title: const AppText(AppStrings.accountLinkingSupport),
        onTap: () => _emailSupport(context, accountLinking: true),
      ),
      if (auth.message != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: AppText(
            auth.message!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ];
  }

  Future<void> _rate(BuildContext context, StoreLinks links) async {
    final opened = await openStoreReview(links, defaultTargetPlatform);
    if (!opened && context.mounted) _showError(context);
  }

  Future<void> _share(BuildContext context, Uri listing) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(ShareParams(
        text: '${AppConfig.appName} — $listing',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  List<Widget> _storeSection(BuildContext context) {
    const links = StoreLinks();
    final review = kIsWeb ? null : links.rating(defaultTargetPlatform);
    final listing = kIsWeb ? null : links.listing(defaultTargetPlatform);
    final developer = kIsWeb ? null : links.developer(defaultTargetPlatform);
    return [
      const _SectionTitle(AppStrings.sectionAbout),
      ListTile(
        leading: const Icon(Icons.star_outline),
        title: const AppText(AppStrings.rateThisApp),
        subtitle: review == null
            ? const AppText(AppStrings.storeLinkUnavailable)
            : null,
        enabled: review != null,
        onTap: review == null ? null : () => _rate(context, links),
      ),
      Builder(
          builder: (shareContext) => ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const AppText(AppStrings.shareApp),
                subtitle: listing == null
                    ? const AppText(AppStrings.storeLinkUnavailable)
                    : null,
                enabled: listing != null,
                onTap: listing == null
                    ? null
                    : () => _share(shareContext, listing),
              )),
      ListTile(
        leading: const Icon(Icons.apps_outlined),
        title: const AppText(AppStrings.moreDeveloperApps),
        subtitle: developer == null
            ? const AppText(AppStrings.storeLinkUnavailable)
            : null,
        enabled: developer != null,
        onTap: developer == null
            ? null
            : () => _openWeb(context, developer.toString()),
      ),
    ];
  }

  List<Widget> _helpSection(BuildContext context) => [
        const _SectionTitle(AppStrings.sectionHelp),
        ListTile(
          leading: const Icon(Icons.mail_outline),
          title: const AppText(AppStrings.contactSupport),
          subtitle: const AppText(AppStrings.contactSupportSubtitle),
          onTap: () => _emailSupport(context),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline),
          title: const AppText(AppStrings.supportPage),
          onTap: () => _openWeb(context, AppConfig.supportPageUrl),
        ),
        if (AppConfig.proEnabled)
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const AppText(AppStrings.purchaseProblem),
            subtitle: const AppText(AppStrings.purchaseProblemSubtitle),
            onTap: () => _openWeb(context, AppConfig.purchaseHelpUrl),
          ),
      ];

  List<Widget> _legalSection(BuildContext context) {
    final ads = AdsService.instance;
    return [
      if (AnalyticsService.enabled)
        ListenableBuilder(
          listenable: AnalyticsService.instance,
          builder: (context, child) => SwitchListTile(
            title: const Text('Usage analytics'),
            subtitle: const Text(
              'Share basic usage measurement, separately from ads.',
            ),
            value: AnalyticsService.instance.enabledForUsage,
            onChanged: AnalyticsService.instance.setUsageConsent,
          ),
        ),
      const _SectionTitle(AppStrings.sectionLegal),
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const AppText(AppStrings.privacyPolicy),
        onTap: () => _openWeb(context, AppConfig.privacyPolicyUrl),
      ),
      ListTile(
        leading: const Icon(Icons.description_outlined),
        title: const AppText(AppStrings.termsOfUse),
        onTap: () => _openWeb(context, AppConfig.termsOfUseUrl),
      ),
      if (AppConfig.adsEnabled && ads.privacyOptionsRequired)
        ListTile(
          leading: const Icon(Icons.tune),
          title: const AppText(AppStrings.privacyChoices),
          onTap: ads.showPrivacyOptions,
        ),
      ListTile(
        leading: const Icon(Icons.delete_outline),
        title: const AppText(AppStrings.deleteMyData),
        subtitle: const AppText(AppStrings.deleteMyDataSubtitle),
        onTap: () => _openWeb(context, AppConfig.dataDeletionUrl),
      ),
    ];
  }

  List<Widget> _aboutSection() => [
        const _SectionTitle(AppStrings.sectionAbout),
        FutureBuilder<String>(
          future: LinkService.appVersionLabel(),
          builder: (context, snapshot) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: const AppText(AppStrings.version),
            trailing: AppText(snapshot.data ?? ''),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.confirmation_number_outlined),
          title: AppText(AppStrings.sku),
          trailing: AppText(AppConfig.sku),
        ),
        const ListTile(
          leading: Icon(Icons.lock_open_outlined),
          title: AppText(AppStrings.noEncryption),
          dense: true,
        ),
        const ListTile(
            title: AppText('© ${AppConfig.developerName}'), dense: true),
      ];
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: AppText(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
