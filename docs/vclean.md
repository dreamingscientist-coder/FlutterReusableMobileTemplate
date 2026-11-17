# Optional feature cleanup

Run `vclean` inside a generated Flutter app (including its ios/android folder).
Menu: 1 = AdMob and tracking, 2 = sign-in/Firebase, 3 = RevenueCat/Pro, 4 = all, 0 = cancel.
Enter multiple numbers such as `2,3`.

Preview: `vclean --remove 2,3 --dry-run`.
Apply: `vclean --remove 2,3`.
Without the shell helper: `make vclean` or `python3 release/vclean.py`.

The command disables feature flags, removes SDK dependencies, and substitutes
small local interfaces so existing template screens keep compiling. It backs
up changed sources and dependency locks under `.vclean-backups/`, then runs
Flutter package resolution, analysis, tests, and CocoaPods when present.
Custom direct SDK imports stop cleanup before changes. Review custom flows
and store/privacy descriptions for your app after removing a feature.

Restore by copying backed-up files to their original paths, then running
`flutter pub get` and `cd ios && env -u GEM_HOME -u GEM_PATH pod install`.
Nothing is uploaded or committed. Run `source ~/.zsh_functions` in an existing
terminal to load the new command. SDK removal affects future builds, not
already installed or uploaded app versions.

Before builds, `gbeta` runs `gprivacy --sync-only` to refresh saved public contact and legal links in AppConfig. Run `gprivacy` to publish changed legal page content first. `--sync-only` never publishes or uploads and does not enable cleaned features.
