# Banner footer and support actions

The shared footer contains only the banner. It has no reward/rate/share/more-apps
row and no decorative vertical padding. The banner sits directly above the
system bottom safe area; do not overlap the home indicator or gesture region.
When no ad or debug preview is available, no banner height is reserved.
Each route owns its own banner widget. Keep Google test units in debug builds.

Rate/Share/More apps remain in Settings and the optional support popup, using
per-app store links. Reward offers are separate from reviews and shares.
The existing optional 15-minute ad break service can be invoked explicitly by
apps that need it; it is no longer shown in the footer or support popup.

## Test devices

Keep Google's sample ad units in debug builds. Devices registered under AdMob
Settings > Test devices receive AdMob Network test ads account-wide; no IDFA list
needs to be copied into each app. This does not apply to third-party mediation.

For SDK-side registration, copy the 32-character test-device hash from the native
Mobile Ads console log (not the hyphenated advertising ID/IDFA). Use:

```
flutter run --dart-define=ADMOB_TEST_DEVICE_IDS=YOUR_SDK_HASH
```

For an internal release/TestFlight build, also explicitly set
`--dart-define=ADMOB_ENABLE_TEST_DEVICES=true`. Generated Fastlane scripts read
both settings from .env. Remove that opt-in for public releases, following Google
 guidance. Configuration is awaited before SDK initialization/preload and ad
requests. Invalid IDs or configuration failures prevent SDK readiness and ad
requests rather than silently continuing. Verify the Test Ad badge on physical
devices; code configuration alone is not proof that an ad is a test ad.
Registration never grants app features or bypasses consent. Tester feature
unlocks are an app-specific decision, separate from safe ad testing.

Official guide: https://developers.google.com/admob/flutter/test-ads

## ATT and regional ad consent

On iOS, ATT authorization controls access to IDFA for tracking. If a user denies, restricts, or has not decided, Google Mobile Ads can still serve ads; Google documents that its SDK omits IDFA from ad requests after denial. ATT status does not replace Google's UMP `canRequestAds` result. Refresh UMP consent each launch, show any required form, and only then initialize/request ads. Keep regional purposes/vendor consent, privacy-options entry points, and publisher settings in place. Inspect actual SDK and mediation behavior; non-personalized labels alone do not establish that tracking is disabled.

When the app backgrounds, dispose cached ad handles and ignore late load callbacks; refresh UMP and ATT status on resume. Recheck the selected SDK version and mediation adapters against current guidance before each release.

Official references: [Google ATT/IDFA behavior](https://developers.google.com/admob/ios/privacy/idfa), [Google ad-serving modes](https://developers.google.com/admob/ios/privacy/ad-serving-modes), [Google UMP for Flutter](https://developers.google.com/admob/flutter/privacy), [Apple ATT](https://developer.apple.com/documentation/apptrackingtransparency).
