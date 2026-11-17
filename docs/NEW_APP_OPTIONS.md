# New App Options

## Identity

Default bundle ID is `com.khacmuoivu.[newname]`. The final segment also becomes the Dart package/project slug. Keep it lowercase, short, and unique.

Increase the VKM SKU number for every new repo. The app exposes it as `AppConfig.sku`, writes it to `app.env`, and shows it in Settings.

## Privacy And Legal

Settings includes Privacy Policy, Terms, Help, Contact Support, Delete My Data, and Privacy Choices. Privacy Choices appears only when AdMob says consent options are required.

iOS `ITSAppUsesNonExemptEncryption` is set to `false`, meaning no special encryption.

## Ads

Banner ads use a fixed 50px bottom slot and appear only after 30 seconds from initial app open. Debug builds use Google test IDs. Production Fastlane lanes should not ship test IDs.

Rewarded ads are available through `RewardedAdService.instance`. Call `preload()` early and `show(onReward: ...)` when the user chooses to watch an ad.

## Pro / RevenueCat

Pro is validated through RevenueCat. Default entitlement ID is `pro`; default product ID is `${bundleId}.pro`. Configure those in RevenueCat, App Store Connect, and Google Play.

When Pro is active, banner ads hide automatically. Settings can show account linking after Pro purchase.

## Account Linking

Sign-in is optional per repo. Enable Apple, Google, or both during setup. Google sign-in requires Firebase. Apple sign-in requires Apple developer capability and Firebase Apple provider setup.

Account-linking support uses the configured support email by default. Change `AppConfig.accountLinkingSupportEmail` for a dedicated mailbox.

## Fastlane

Fastlane uses shared information from `Tool/Mobile-Release` and per-app `app.env`. Store secrets stay out of the repo.
