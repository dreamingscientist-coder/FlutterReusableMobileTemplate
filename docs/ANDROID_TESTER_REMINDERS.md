# Daily reminders for Android testers

Generate a calendar file and share it with the Android testers who want daily
prompts. Choose a start date, a local time, and the number of testing days.
For example, from the project root:

```sh
python3 tool/android_tester_reminder.py --app "My App" --start 2026-11-16 \
  --time 19:00 --days 14 --output /tmp/my-app-android-test.ics
```

Ask testers to import the file into a calendar that syncs to their Android
device and verify that the imported event has a notification at its start time.
Calendar apps can apply their own notification settings. Testers can change the
series time or delete the series when they finish. Import the file once to avoid
duplicate events.

The calendar entry asks testers to open the Android test build and try a feature.
It does not install the build or track whether testers opened it. Share the Play
testing link alongside the calendar file when onboarding testers.
