# Flutter workspace disk usage

Keep generated projects compact. Treat source, signing files, release artifacts
that still need to be delivered, and regenerable build output separately.

- Before a large build or when a checkout grows unexpectedly, measure the project
  and its immediate subdirectories with `du -sh .` and `du -hd 1 .`.
  Check `build/`, `.dart_tool/`, `android/.gradle/`, and `ios/Pods/` where present.
- Reuse the machine's Flutter SDK, Android SDK, Pub cache, and Gradle user home
  across projects. Avoid project-local copies and custom per-project cache paths
  unless the project has a specific isolation requirement.
- Build and test only the platform and variants needed for the task. Keep
  deliverables that are still needed before running `flutter clean`. Run
  `flutter pub get` when dependencies need to be restored.
- Copy the template without generated caches or prior build output. Keep lockfiles
  and source files. Keep build outputs, local caches, and downloaded dependencies
  out of version control.
- Before removing project-local Gradle caches, Pods, or Xcode DerivedData, verify
  their location, confirm no active build uses them, and check that they can be
  regenerated. Preserve lockfiles. Leave shared caches, SDKs, simulator data,
  signing material, and release archives alone unless cleanup is specifically
  requested.
- Use `make vclean` when starting an app that does not need optional SDK features.
  This changes dependencies and app behavior, so use the preview first and only
  remove features the app owner has chosen to omit.
- When disk size is part of the task, report before and after sizes and identify
  any large directories left in place.

# AdMob build policy

Use `grelease` for builds that need production AdMob app and ad unit IDs.
Use Google sample IDs for local builds, `gbeta`, and direct Make or Fastlane
builds, including direct store release lanes. Keep production IDs in the app's
release configuration. Preserve the sample IDs in the Android manifest and
iOS plist so direct Flutter builds use Google's test configuration. Leave the
production build flag scoped to `grelease`.
