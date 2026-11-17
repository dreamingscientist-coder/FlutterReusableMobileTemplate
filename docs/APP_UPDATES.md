# Automatic update-policy setup

Copy the template, then run your normal `make setup`. No separate update-feature
installation command is needed. Setup generates `legal/APP/app-update.json`,
with your bundle ID, current version, a 90-day expiry, and disabled platform
policies. The app checks LEGAL_URL/app-update.json on launch/resume (six-hour
throttle). APP_UPDATE_POLICY_URL can override the endpoint at build time.

Publish legal/APP alongside your existing legal pages using the usual legal-site
workflow. No paid backend or new account is needed for existing public GitHub
Pages hosting. The template does not publish a website or create a store listing
on your behalf. Keep the policy disabled until the app version is publicly
available. Store-link discovery also fills the policy store URLs without enabling
it. iOS URL starts empty because an App Store ID cannot be guessed during setup.

The shared grelease detects the generated policy and asks Optional / Required /
No change before uploading. Its project-local tool/gbeta_update_policy.py
prepares app-update.pending.json and records successful per-platform upload
versions before the Git push. gbeta skips policy preparation. Store uploads
and the Git push leave the live policy inactive until you publish it.
Run source ~/.zsh_functions in existing terminal sessions to reload the commands.

After public store availability: copy the pending mode/version/minimum into the
corresponding hosted platform policy, append the version to publishedReleases,
renew expiresAt, and set enabled/storeAvailable=true. Required blocks versions
below latest; minimumSupportedVersion independently blocks unsupported versions.
More than two published releases behind gives a stronger dismissible reminder.
Do not count beta builds. Do not block users whose OS/storefront cannot obtain
the new version. storeAvailable is an operator assertion, not an automated check.

Policy schema: schemaVersion=1; appId=your bundle/package ID; ios/android objects
with enabled, storeAvailable, latestVersion, minimumSupportedVersion, mode,
publishedReleases (ordered unique numeric major.minor.patch versions), expiresAt,
storeUrl, and optional messages keyed by en/vi (or your app's supported locales).
This template shares one bundle/package ID on both platforms. Apps using distinct
identities must adapt appId validation before enabling the feature.

Offline, expired, malformed, wrong-app or unavailable policy: fail open. Required
policy is not persisted offline. Optional notices dismiss per version/session.
Store destination is constrained to platform-store HTTPS URLs and checked against
configured StoreLinks when available. Native store-open failures show a retry.
User version is evaluated locally, not sent to the policy host. Requests expose
normal HTTP metadata to the hosting service. Publication/cache delays apply.

GitHub Pages supports public repositories on GitHub Free; limits include 1 GB
site size, soft 100 GB/month bandwidth and soft 10 builds/hour for branch builds.
Official terms checked 2026-10-22:
https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits

Run make check. Optional visual QA uses test/app_update_ui_test.dart with
RENDER_UPDATE_QA=true and QA_FONT_PATH pointing to the app's UI font. No Firebase,
mBlue IDs, reward system, or private credentials are required for update checks.
