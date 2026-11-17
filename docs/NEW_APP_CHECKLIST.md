# New app checklist

Work through the boxes in order. ☐ = to do.

## A. Local project
- ☐ Fresh copy of the template (GitHub "Use this template", or copy the folder)
- ☐ `make setup` → answer the questions (first time only: your developer profile too)
- ☐ Write the store texts in `store/<language>/` (remove every `TODO`)
- ☐ `make check` → no errors
- ☐ `flutter run` on an iPhone simulator **and** an Android emulator
- ☐ On a physical iPhone, enable **Settings → Privacy & Security → Tracking → Allow Apps to Request to Track**, delete the app, reinstall it, and confirm ATT appears before UMP or any ad
- ☐ Record the fresh-install ATT flow and attach it to **App Review Information → Notes** before submitting an ad-supported app
- ☐ App icon: put a 1024×1024 PNG at `assets/icon.png`, then run `dart run flutter_launcher_icons` (add the package first), or set the icons in Xcode / Android Studio
- ☐ `git add . && git commit -m "Setup"`, then `git status` must NOT list `.env`, `key.properties`, `.jks` or `.p8` files

## B. Legal pages (both stores require them)
- ☐ Copy `legal/<app>/` into your public `app-legal` repo and push
- ☐ Open the 4 links in a browser: `privacy.html`, `terms.html`, `support.html`, `delete-data.html`
- ☐ Read them once and adapt anything that is not true for this app

## C. Apple — App Store Connect
1. ☐ `make ios-create` → creates the App ID and the app (asks for your Apple ID password + 2FA code once)
   - If the name is taken, change `APP_NAME` in `app.env` and try again.
2. ☐ `make ios-info` → **automatic**: name, subtitle, description, keywords, support / marketing / privacy URLs, copyright, category, App Review contact (name, phone, email)
3. ☐ `make ios-privacy` → **automatic** App Privacy answers. The first time only, fastlane asks the questions (with ads: *Identifiers → Device ID*, *Usage Data → Advertising Data*, *Diagnostics*, used for **Third-Party Advertising**, tracking = **Yes**). Your answers are then reused by every app
4. ☐ In App Store Connect → your app, by hand:
   - ☐ **App Information**: content rights, age rating
   - ☐ **Pricing and Availability**
   - ☐ **In-App Purchases** (if Premium is on): type **Non-Consumable**, Product ID = `<bundle id>.premium`, add price + localisation + review screenshot
   - ☐ Paid Apps agreement signed (Business → Agreements), needed for in-app purchases
5. ☐ `make ios-beta` → install from TestFlight → test purchase with a Sandbox account
6. ☐ Version page: screenshots. Attach the in-app purchase to the version
7. ☐ `make ios-release` → press **Add for Review**

## D. Google — Play Console
1. ☐ **Create app** by hand (Google does not allow this through its API): name, default language, app/game, free/paid
2. ☐ First upload **by hand** (Google requires it):
   ```bash
   flutter build appbundle --release
   # upload build/app/outputs/bundle/release/app-release.aab
   # in Play Console → Test and release → Internal testing → Create release
   ```
3. ☐ **App content** section: privacy policy URL, ads = **Yes**, app access, content rating, target audience, data safety (with ads: *Device or other IDs*, shared with Google for advertising), **data deletion URL** = `delete-data.html`
4. ☐ **Monetise → Products → In-app products** (if Premium is on): Product ID = `<bundle id>.premium`, then activate it
5. ☐ From now on: `make android-internal` (add `DRAFT=true` while the app is still a draft)
6. ☐ Add testers, then `make android-closed`. New personal accounts need **12 testers for 14 days** before production access
7. ☐ `make android-info` → **automatic**: title, short + full description, contact email / phone / website
8. ☐ Store listing, by hand: icon 512×512, feature graphic 1024×500, screenshots
9. ☐ `make android-production`

## E. AdMob (if ads are on)
1. ☐ admob.google.com → **Apps → Add app** (once for iOS, once for Android). Link each to its store listing when it is live
2. ☐ Create a **Banner** ad unit in each app
3. ☐ Put the IDs in:
   - `lib/config/app_config.dart` → `_iosBannerId`, `_androidBannerId`
   - `ios/Runner/Info.plist` → `GADApplicationIdentifier`
   - `android/app/src/main/AndroidManifest.xml` → `com.google.android.gms.ads.APPLICATION_ID`
4. ☐ **Privacy & messaging** → create and publish a **GDPR** message (and an **IDFA explainer** for iOS). Without this, no consent form appears in the EU
5. ☐ Publish an **app-ads.txt** file on your developer website (the one listed in the stores)

## Troubleshooting
| Problem | Fix |
|---|---|
| App crashes at launch (ads SDK) | The AdMob App ID is missing from Info.plist / AndroidManifest.xml |
| "Product not found" in Settings | Product ID mismatch, product not active yet, or (Android) app not yet uploaded to a testing track |
| iOS signing error in `make ios-beta` | Check `APPLE_TEAM_ID` and the `ASC_*` values in `Mobile-Release/developer_profile.env`. The API key needs the **Admin** or **App Manager** role |
| `[CP] Check Pods Manifest.lock` fails | Run `cd ios && pod install`. Setup and Fastlane do this automatically when a Podfile exists. |
| ATT does not appear on a fresh install | Confirm tracking requests are enabled in iOS Settings, `NSUserTrackingUsageDescription` exists, and test on a physical device before UMP or another permission prompt. |
| Android: "Only releases with status draft may be created on draft app" | Use `make android-internal DRAFT=true` |
| Android: "APK/AAB signed in debug mode" | `android/key.properties` is missing or wrong |
| "Please fix the store texts first" | Remove every `TODO` in `store/<language>/` and respect the max lengths (see `store/README.md`) |
| `make ios-info` fails on "What's New" | Leave `release_notes.txt` for later: it is only sent for versions after 1.0.0 |
| Wrong phone / email on the stores | Edit `Mobile-Release/developer_profile.env`, then run `make store-info` again |
| Version code already used | Raise the number after `+` in `pubspec.yaml` and try again |

## Preserve the shared screen shell
Use `AppScaffold` for every main screen; keep the top header, persistent footer and
Settings action. Keep the Settings screen and its legal/contact/store entries when
replacing the template Home. Run `gprivacy --sync-only` after changing saved URLs,
and verify links in a normal simulator build as well as the release build.
Never use a generic `ROOT` constant in Fastlane Ruby lanes: Fastlane also defines
ROOT for its installation directory. Use `project_root` or `APP_RELEASE_ROOT`.

## Update policy (included by setup)
- Publish `legal/<app>/app-update.json` with your existing legal pages.
- Discover/configure the actual App Store listing; do not guess the iOS store URL.
- Use normal `gbeta`: Optional / Required / No change prepares a pending draft.
- Activate the hosted policy only after the release is publicly downloadable.
- See [Update policy](APP_UPDATES.md) for required mode, expiry and offline behavior.
