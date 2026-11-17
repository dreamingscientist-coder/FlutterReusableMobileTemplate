# Analytics, language, and support popup

Each generated app owns its Firebase project. Never copy another app's Firebase
options, GoogleService-Info.plist, google-services.json, AdMob IDs or tester list.
Analytics is off by default; missing configuration cannot block app startup.

After `make setup`, install Firebase CLI and FlutterFire CLI, authenticate, then:

```sh
flutterfire configure --project=YOUR_PROJECT_ID --platforms=ios,android
flutter run --dart-define=FIREBASE_ANALYTICS_ENABLED=true
```

This template initializes the default native Firebase app. Confirm FlutterFire
bundles ios/Runner/GoogleService-Info.plist in Runner resources and configures
android/app/google-services.json plus the Google Services Gradle plugin. Keep the
same define on release builds. Generated Fastlane scripts also read
FIREBASE_ANALYTICS_ENABLED=true from .env. Native Auth reuses that default Firebase app.
If switching to generated Dart FirebaseOptions, use those options in the shared
initialization instead; do not initialize two default apps with different config.

Enable Google Analytics in Firebase. Verify app_open in DebugView. On iOS add
-FIRDebugEnabled to Xcode Run arguments; on Android use
`adb shell setprop debug.firebase.analytics.app YOUR_PACKAGE`.
Named routes are observed automatically. Add RouteSettings(name: 'settings') to
new routes, or use AnalyticsService.instance.logScreen with a stable screen name.
Never send personal information. SDK readiness does not prove server receipt.
Google Analytics is no-cost; this setup adds no paid Cloud service or export.
Firebase advertising storage, ad user data, and ad personalization are explicitly denied; generated iOS apps also disable IDFV collection. ATT controls IDFA access for advertising and does not decide whether UMP permits ads or whether the user has analytics consent. Review GA/AdMob links, audiences, Google signals, and data sharing in the console. Evaluate regional analytics consent separately and update privacy disclosures.
Official references: https://firebase.google.com/docs/flutter/setup and
https://firebase.google.com/docs/analytics/debugview and https://firebase.google.com/pricing

Settings persists English/Vietnamese with native Flutter localization delegates.
Use AppText/tr and maintain lib/l10n/vi.dart for each app's new copy. Names, units,
URLs and data keys stay unchanged. The starter catalog covers common shell copy;
complete translations when enabling optional account/purchase features.

The support popup appears after three home openings and repeats after three more
if dismissed. Successful store review launch stops it; this is not proof a review
was submitted. Rate/Share/More apps appear only when the corresponding public
store links are configured. Rewards are separate from rating/sharing. Configure
StoreLinksConfig or the documented store-link dart defines per app. Do not offer
rewards for reviews, shares or ad clicks.
