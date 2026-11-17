#!/usr/bin/env python3
"""Generate a calendar reminder for an Android testing campaign."""

import argparse
import re
from datetime import date, datetime, time, timezone
from pathlib import Path
from uuid import uuid4


def calendar_text(value):
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace(";", "\\;").replace(",", "\\,")


def fold_line(line):
    chunks = []
    chunk = ""
    size = 0
    for character in line:
        width = len(character.encode("utf-8"))
        if size + width > 75:
            chunks.append(chunk)
            chunk = " "
            size = 1
        chunk += character
        size += width
    return "\r\n".join([*chunks, chunk])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, help="App display name")
    parser.add_argument("--start", required=True, type=date.fromisoformat)
    parser.add_argument("--time", required=True, help="Tester-local time, HH:MM")
    parser.add_argument("--days", required=True, type=int, help="Number of daily reminders")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not args.app.strip() or any(ord(character) < 32 for character in args.app):
        parser.error("--app must be a nonempty single-line app name")
    if not re.fullmatch(r"(?:[01][0-9]|2[0-3]):[0-5][0-9]", args.time):
        parser.error("--time must be in 24-hour HH:MM format")
    if args.days < 1:
        parser.error("--days must be positive")

    start = datetime.combine(args.start, time.fromisoformat(args.time))
    summary = calendar_text(f"Open {args.app} on Android")
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Flutter Mobile Template//Android Tester Reminder//EN",
        "BEGIN:VEVENT",
        f"UID:{uuid4()}",
        f"DTSTAMP:{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}",
        f"DTSTART:{start:%Y%m%dT%H%M%S}",
        "DURATION:PT5M",
        f"RRULE:FREQ=DAILY;COUNT={args.days}",
        f"SUMMARY:{summary}",
        "DESCRIPTION:Open the Android test build and try a feature.",
        "BEGIN:VALARM",
        "ACTION:DISPLAY",
        f"DESCRIPTION:{summary}",
        "TRIGGER:PT0S",
        "END:VALARM",
        "END:VEVENT",
        "END:VCALENDAR",
    ]
    try:
        with args.output.open("x", encoding="utf-8", newline="") as output:
            output.write("\r\n".join(map(fold_line, lines)) + "\r\n")
    except OSError as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
