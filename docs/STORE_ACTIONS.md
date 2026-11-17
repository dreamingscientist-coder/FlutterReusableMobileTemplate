# Store actions in Settings

Rate this app, Share app, and More apps from this developer are reusable Settings rows.
Configure each new published app through Flutter build/run dart defines:

```
--dart-define=APPLE_APP_STORE_URL=https://apps.apple.com/app/idYOUR_APP_ID
--dart-define=APPLE_DEVELOPER_URL=https://apps.apple.com/developer/idYOUR_DEVELOPER_ID
--dart-define=GOOGLE_PLAY_APP_URL=https://play.google.com/store/apps/details?id=YOUR_PACKAGE
--dart-define=GOOGLE_PLAY_DEVELOPER_URL=https://play.google.com/store/apps/dev?id=YOUR_DEVELOPER_ID
```

Use HTTPS public store URLs. No developer login, credentials, or runtime account lookup is required.
Unconfigured actions are disabled. Android can be configured when its listing is published.
Apple rating opens its documented HTTPS listing URL with action=write-review.
Share uses the public listing without a review query and anchors its popover to the row on iPad.
The template deliberately contains no Archegenos app ID. `make setup` preserves this service;
pass the appropriate defines on subsequent builds. Labels are in AppStrings for app localization.

Verify review on a physical device with the App Store available; a simulator may not provide it.
Verify share-sheet positioning on iPad. No automatic rating prompts are shown.

## Discover links with ggad

After choosing the AdMob app in ggad, linked store IDs are used to discover
public store URLs. iOS lookup validates the bundle ID against the project.
Missing values are filled; nonempty replacements show current/found values and
require a yes answer. Noninteractive runs retain nonempty values. Defaults are
saved in lib/services/store_links_config.dart and survive make setup. Rebuild
the app afterwards. No developer credentials are bundled into your app.

You can also run `python3 tool/sync_store_links.py --platform ios --store-id YOUR_APP_ID`.
Use `--dry-run` to preview. If iOS project files do not yet exist, pass
`--identity YOUR_BUNDLE_ID`. Android requires `--platform android --store-id YOUR_PACKAGE`;
it must match the project. Google developer links need manual configuration.
Unpublished/unlinked apps keep their existing links.

The review button extracts the numeric app ID from the saved listing, opens `itms-apps://apps.apple.com/app/idAPP_ID?action=write-review`, then falls back to the global HTTPS review link if native launch fails. Share retains the public storefront URL. This targets the App Store Write a Review screen; opening the store does not confirm that its review screen rendered.

Review launch tries the native App Store route, then an HTTPS universal link with externalNonBrowserApplication. If both fail it opens the saved public listing without a review query. Safari never receives the generated write-review URL. Store launch success does not confirm that the review UI appeared; verify on a physical device.
