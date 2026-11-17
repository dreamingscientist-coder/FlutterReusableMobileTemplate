# Support popup

The home route offers reward, rating, sharing and developer apps after three opens. Dismissal, including tapping outside or Back, postpones the next offer for three more opens. A successful review-store launch stops future offers. Failed launches remain eligible after the cooldown.

Only configured platform store links are offered. Configure StoreLinksConfig or the existing store URL dart-defines for each app; unrelated listings are never used. The reward action is optional and grants an ad break only after the SDK reports an earned reward.

Preview in a debug build with `flutter run --dart-define=SHOW_SUPPORT_PROMPT=true`. The force flag has no effect in profile or release builds.

## Debug banner preview

In a debug build, open Settings → Developer preview → Show test banner. It defaults off and persists on this device. Turning it on reserves a labelled preview immediately; a Google test banner replaces it when consent, network and SDK loading allow. Turning it off disposes the banner and removes its slot. Profile/release builds do not offer the switch and keep their configured advertising behavior.
