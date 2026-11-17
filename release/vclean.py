#!/usr/bin/env python3
"""Remove optional SDKs from apps made with FlutterReusableMobileTemplate."""
import argparse
import datetime
import re
import shutil
import subprocess
from pathlib import Path

FEATURES = {'1': 'AdMob and tracking', '2': 'Apple/Google sign-in and Firebase', '3': 'RevenueCat / Pro purchases'}
PACKAGES = {'1': ['google_mobile_ads', 'app_tracking_transparency'], '2': ['firebase_core', 'firebase_auth', 'google_sign_in', 'sign_in_with_apple'], '3': ['purchases_flutter']}
FLAGS = {'1': ['adsEnabled', 'rewardedAdsEnabled'], '2': ['signInEnabled', 'appleSignInEnabled', 'googleSignInEnabled', 'accountLinkingAfterPro'], '3': ['proEnabled', 'revenueCatEnabled', 'accountLinkingAfterPro']}
ENV_FLAGS = {'1': ['ADS_ENABLED', 'REWARDED_ADS_ENABLED'], '2': ['SIGN_IN_ENABLED', 'APPLE_SIGN_IN_ENABLED', 'GOOGLE_SIGN_IN_ENABLED', 'ACCOUNT_LINKING_AFTER_PRO'], '3': ['PRO_ENABLED', 'REVENUECAT_ENABLED', 'IAP_ENABLED', 'ACCOUNT_LINKING_AFTER_PRO']}
STUBS = {
'purchase_service.dart': '''import 'package:flutter/foundation.dart';
class LocalProduct { String get priceString => ''; }
class LocalPackage { LocalProduct get storeProduct => LocalProduct(); }
class PurchaseService extends ChangeNotifier {
  PurchaseService._();
  static final instance = PurchaseService._();
  bool get isPro => false;
  bool get isPremium => false;
  bool get busy => false;
  String? get message => null;
  LocalPackage? get proPackage => null;
  Future<void> init() async {}
  Future<void> buyPro() async {}
  Future<void> restorePurchases() async {}
  Future<void> logInRevenueCat(String id) async {}
}
''',
'auth_service.dart': '''import 'package:flutter/foundation.dart';
class LocalAccount {
  String? get email => null;
  String get uid => '';
}
class AuthService extends ChangeNotifier {
  AuthService._();
  static final instance = AuthService._();
  bool get busy => false;
  bool get isSignedIn => false;
  String? get message => null;
  LocalAccount? get user => null;
  Future<void> init() async {}
  Future<void> signInWithGoogle() async {}
  Future<void> signInWithApple() async {}
  Future<void> signOut() async {}
}
''',
'ads_service.dart': '''import 'package:flutter/foundation.dart';
class AdsService extends ChangeNotifier {
  AdsService._();
  static final instance = AdsService._();
  bool get canShowAds => false;
  bool get privacyOptionsRequired => false;
  Future<void> init() async {}
  void showPrivacyOptions() {}
}
''',
'rewarded_ad_service.dart': '''import 'package:flutter/foundation.dart';
class RewardedAdService {
  RewardedAdService._();
  static final instance = RewardedAdService._();
  void preload() {}
  Future<bool> show({required VoidCallback onReward}) async => false;
}
''',
'interstitial_ad_service.dart': '''class InterstitialAdService {
  InterstitialAdService._();
  static final instance = InterstitialAdService._();
  void preload() {}
  Future<void> show() async {}
}
''',
}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--remove', help='Comma-separated numbers: 1 ads, 2 sign-in, 3 purchases, 4 all')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--release-preflight', action='store_true', help='Noninteractive cleanup of disabled purchases and release configuration')
    parser.add_argument('--skip-checks', action='store_true', help='Skip Flutter checks and CocoaPods refresh')
    args = parser.parse_args()
    root = args.project.resolve()
    while not (root / 'pubspec.yaml').is_file() and root.parent != root:
        root = root.parent
    if not (root / 'pubspec.yaml').is_file():
        parser.error('Run inside a Flutter project or pass --project.')
    if args.release_preflight:
        config_path = root / 'lib/config/app_config.dart'
        config = config_path.read_text() if config_path.is_file() else ''
        # Never remove an enabled purchase integration automatically.
        enabled = re.search(r'static const bool (?:proEnabled|revenueCatEnabled)\s*=\s*true', config)
        if enabled:
            print('Purchase integration enabled; leaving SDK installed.')
            return
        args.remove = '3'
    if not args.remove:
        print('Remove optional features:')
        for number, label in FEATURES.items(): print(f'  {number}. {label}')
        print('  4. All of the above\n  0. Cancel')
    selected = set(re.split(r'[,\s]+', args.remove or input('Choose numbers (for example 2,3): ').strip()))
    if selected == {'0'}: return
    if not selected or not selected <= {'1', '2', '3', '4'}: parser.error('Choose 1, 2, 3, or 4.')
    if '4' in selected: selected = {'1', '2', '3'}
    changes = {}
    def edit(path, transform):
        file = root / path
        if file.is_file():
            old = file.read_text()
            new = transform(changes.get(path, old))
            if old != new: changes[path] = new
    if args.release_preflight:
        rewarded = bool(re.search(r'static const bool rewardedAdsEnabled\s*=\s*true', config))
        if not rewarded:
            for file in ['app.env', '.env']:
                edit(file, lambda text: re.sub(r'^REWARDED_ADS_ENABLED=.*$', 'REWARDED_ADS_ENABLED=false', text, flags=re.M))
        def fix_android_lane(text):
            # Only rewrite the template's map call; other lanes use the project_root method.
            if ('def admob_dart_defines(platform)' in text
                    and 'File.join(project_root, "tool/sync_admob.py")' in text
                    and 'admob_dart_defines(:android).map' in text):
                text = text.replace('def admob_dart_defines(platform)', 'def admob_dart_defines(platform, project_root)')
                text = text.replace('admob_dart_defines(:android).map', 'admob_dart_defines(:android, project_root).map')
            text = text.replace('%w[banner_unit_id interstitial_unit_id rewarded_unit_id].each do |key|', 'required_units = %w[banner_unit_id interstitial_unit_id]\n  required_units << "rewarded_unit_id" if ENV["REWARDED_ADS_ENABLED"] == "true"\n  required_units.each do |key|')
            return text
        edit('android/fastlane/Fastfile', fix_android_lane)
    packages = [p for n in selected for p in PACKAGES[n]]
    edit('pubspec.yaml', lambda s: re.sub(r'^  (?:' + '|'.join(packages) + r'):.*\n', '', s, flags=re.M))
    flags = [f for n in selected for f in FLAGS[n]]
    edit('lib/config/app_config.dart', lambda s: re.sub(r'(static const bool (?:' + '|'.join(flags) + r')\s*=\s*)(true|false)', r'\g<1>false', s))
    env_flags = [f for n in selected for f in ENV_FLAGS[n]]
    for file in ['app.env', '.env']:
        edit(file, lambda s: re.sub(r'^((?:' + '|'.join(env_flags) + r')=).*$', r'\g<1>false', s, flags=re.M))
    services = []
    if '1' in selected: services += ['ads_service.dart', 'rewarded_ad_service.dart', 'interstitial_ad_service.dart']
    if '2' in selected: services += ['auth_service.dart']
    if '3' in selected: services += ['purchase_service.dart']
    for service in services:
        edit('lib/services/' + service, lambda s, name=service: '// Optional SDK removed by vclean.\n' + STUBS[name])
    if '1' in selected:
        edit('lib/widgets/banner_ad_widget.dart', lambda s: '''import 'package:flutter/widgets.dart';
class BannerAdWidget extends StatelessWidget {
  const BannerAdWidget({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
''')
        edit('lib/services/tracking_consent_service.dart', lambda s: '''class TrackingConsentService {
  static Future<void> requestIfNeeded() async {}
}
''')
        edit('android/app/src/main/AndroidManifest.xml', lambda s: re.sub(r'\s*<meta-data\s+android:name="com.google.android.gms.ads.APPLICATION_ID"[^>]*?/?>', '', s))
        edit('ios/Runner/Info.plist', lambda s: re.sub(r'\s*<key>GADApplicationIdentifier</key>\s*<string>[^<]*</string>', '', s))
    # Refuse custom direct SDK integrations instead of leaving a broken app.
    unsupported = []
    for file in (root / 'lib').rglob('*.dart'):
        relative = str(file.relative_to(root))
        source = changes.get(relative, file.read_text())
        if any('package:' + package + '/' in source for package in packages): unsupported.append(relative)
    if unsupported: parser.error('Custom SDK imports need adapting first: ' + ', '.join(unsupported))
    print('Removing: ' + ', '.join(FEATURES[n] for n in sorted(selected)))
    for path in sorted(changes): print('  ' + path)
    if args.dry_run: return
    if not changes and not args.release_preflight:
        print('Already cleaned.'); return
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup = root / '.vclean-backups' / stamp
    # Lockfiles are included because package managers update them after edits.
    backup.mkdir(parents=True, exist_ok=True, mode=0o700)
    backup.chmod(0o700)
    for path in set(changes) | {'pubspec.lock', 'ios/Podfile.lock'}:
        original = root / path
        if original.is_file():
            dest = backup / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(original, dest)
    for path, source in changes.items(): (root / path).write_text(source)
    ignore = root / '.gitignore'
    if ignore.is_file() and '.vclean-backups/' not in ignore.read_text():
        with ignore.open('a') as f: f.write('\n# Local feature cleanup backups (may include private .env)\n.vclean-backups/\n')
    print(f'Backup: {backup}')
    if not args.skip_checks:
        import os
        env = dict(os.environ)
        env.pop('GEM_HOME', None); env.pop('GEM_PATH', None)
        for command in [['flutter', 'pub', 'get'], ['flutter', 'analyze'], ['flutter', 'test']]:
            subprocess.run(command, cwd=root, env=env, check=True)
        if (root / 'ios/Podfile').is_file() and shutil.which('pod'):
            subprocess.run(['pod', 'install'], cwd=root / 'ios', env=env, check=True)
    print('Done. SDK cleanup and checks completed. No uploads.')
    if args.release_preflight:
        print('iOS export requires a valid Xcode account session and Apple Distribution certificate/private key; cleanup cannot renew your login.')

if __name__ == '__main__': main()
