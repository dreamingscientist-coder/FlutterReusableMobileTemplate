#!/usr/bin/env python3
# =====================================================================
# setup/setup_project.py — turns this template into YOUR new app.
#
# You normally run it through:   make setup   (→ setup/new_app.sh)
#
# What it does, in order:
#   1. Loads YOUR saved developer profile (contact, Apple/Google keys)
#      from Mobile-Release/developer_profile.env — asks only the first
#      time — then asks about this app (name, bundle ID, ads...) → ask()
#   2. Renames the Dart package in pubspec.yaml + tests      → rename_package()
#   3. Runs `flutter create` to make fresh ios/ + android/   → flutter_create()
#   4. Patches Android + iOS files (AdMob ID, name, signing)  → patch_*()
#   5. Writes lib/config/app_config.dart                     → write_app_config()
#   6. Writes fastlane files, app.env, .env, key.properties  → write_release_files()
#   7. Writes the legal web pages into legal/                → write_legal_pages()
#      and the store texts into store/<language>/            → write_store_texts()
#   8. Runs `flutter pub get` and marks the project as done
#
# It only uses Python's standard library (no pip install needed).
# Options (for testing):
#   --answers FILE.json   use answers from a file instead of questions
#   --skip-flutter        do not run flutter commands
# =====================================================================
import argparse
import datetime
import getpass
import glob
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES = os.path.join(ROOT, "setup", "templates")
DONE_MARKER = os.path.join(ROOT, "setup", ".setup_done")
TEMPLATE_PACKAGE = "flutter_reusable_mobile_template"

DEFAULT_MOBILE_RELEASE = "/Users/khacmuoivu/Developer/Tool/Mobile-Release"

# Google's public TEST AdMob app IDs (used until you enter real ones).
TEST_ADMOB_APP_IOS = "ca-app-pub-3940256099942544~1458002511"
TEST_ADMOB_APP_ANDROID = "ca-app-pub-3940256099942544~3347511713"

DART_RESERVED = {
    "abstract", "as", "assert", "async", "await", "break", "case", "catch",
    "class", "const", "continue", "default", "deferred", "do", "dynamic",
    "else", "enum", "export", "extends", "extension", "external", "factory",
    "false", "final", "finally", "for", "function", "get", "if", "implements",
    "import", "in", "interface", "is", "late", "library", "mixin", "new",
    "null", "on", "operator", "part", "required", "rethrow", "return", "set",
    "static", "super", "switch", "sync", "this", "throw", "true", "try",
    "typedef", "var", "void", "while", "with", "yield", "flutter", "test",
}


# ---------------------------------------------------------------------
# Small printing helpers
# ---------------------------------------------------------------------
def title(text):
    print("\n\033[1;34m== " + text + " ==\033[0m")


def ok(text):
    print("  \033[32m✔\033[0m " + text)


def warn(text):
    print("  \033[33m!\033[0m " + text)


def fail(text):
    print("\n\033[31m✘ " + text + "\033[0m")
    sys.exit(1)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


def render(text, values):
    """Replace {{KEY}} with values[KEY]."""
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", str(value))
    left = re.findall(r"{{[A-Z_]+}}", text)
    if left:
        fail("Template placeholder(s) without value: " + ", ".join(sorted(set(left))))
    return text


def keep_blocks(text, name, keep):
    """Keep or remove <!--IF_NAME--> ... <!--END_IF_NAME--> blocks."""
    pattern = re.compile(r"<!--IF_%s-->(.*?)<!--END_IF_%s-->" % (name, name), re.S)
    return pattern.sub(lambda m: m.group(1) if keep else "", text)


# ---------------------------------------------------------------------
# 1. Questions
# ---------------------------------------------------------------------
def question(label, default="", check=None, error="Invalid value.", allow_empty=False):
    while True:
        hint = " [%s]" % default if default else ""
        answer = input("  %s%s: " % (label, hint)).strip() or default
        if not answer and allow_empty:
            return ""
        if not answer:
            print("    → Please enter a value.")
            continue
        if check and not check(answer):
            print("    → " + error)
            continue
        return answer


def yes_no(label, default=True):
    hint = "Y/n" if default else "y/N"
    while True:
        answer = input("  %s [%s]: " % (label, hint)).strip().lower()
        if not answer:
            return default
        if answer in ("y", "yes", "o", "oui"):
            return True
        if answer in ("n", "no", "non"):
            return False


def choose_one(label, options, default=1):
    """Display a numbered menu and return the selected option value."""
    print("    " + label + ":")
    for index, (name, value) in enumerate(options, 1):
        print("      %d) %-24s %s" % (index, name, value))
    selected = question(
        "Choice", str(default),
        lambda v: v.isdigit() and 1 <= int(v) <= len(options),
        "Choose a number from 1 to %d." % len(options),
    )
    return options[int(selected) - 1][1]


def choose_many(label, options, default="1"):
    """Display a numbered menu and return comma-separated selected values."""
    print("    " + label + " (choose one or more, comma separated):")
    for index, (name, value) in enumerate(options, 1):
        print("      %d) %-24s %s" % (index, name, value))

    def valid(value):
        picks = [part.strip() for part in value.split(",")]
        return bool(picks) and all(
            pick.isdigit() and 1 <= int(pick) <= len(options) for pick in picks
        )

    selected = question("Choice", default, valid, "Use numbers such as 1 or 1,2.")
    indexes = []
    for part in selected.split(","):
        index = int(part.strip()) - 1
        if index not in indexes:
            indexes.append(index)
    return ",".join(options[index][1] for index in indexes)


def is_bundle_id(v):
    if not re.fullmatch(r"[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+", v):
        return False
    return v.split(".")[-1] not in DART_RESERVED


def is_email(v):
    return re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", v) is not None


def is_https(v):
    return re.fullmatch(r"https://[^\s]+", v) is not None


def slugify_app_name(v):
    slug = re.sub(r"[^a-z0-9]+", "", v.lower())
    return slug if slug and slug not in DART_RESERVED else "myapp"


def is_admob_app_id(v):
    return re.fullmatch(r"ca-app-pub-\d{16}~\d{10}", v) is not None


def is_admob_unit_id(v):
    return re.fullmatch(r"ca-app-pub-\d{16}/\d{10}", v) is not None


# ---------------------------------------------------------------------
# Developer profile = your FIXED details, shared by ALL apps.
# Saved once in <Mobile-Release>/developer_profile.env (never in git).
# ---------------------------------------------------------------------
PROFILE_NAME = "developer_profile.env"
SHARED_KEYSTORE_PROPS = os.path.join("Android", "keystore.properties")
IOS_CATEGORIES = [
    "BOOKS", "BUSINESS", "EDUCATION", "ENTERTAINMENT", "FINANCE", "FOOD_AND_DRINK",
    "GAMES", "GRAPHICS_AND_DESIGN", "HEALTH_AND_FITNESS", "LIFESTYLE", "MEDICAL",
    "MUSIC", "NAVIGATION", "NEWS", "PHOTO_AND_VIDEO", "PRODUCTIVITY", "REFERENCE",
    "SHOPPING", "SOCIAL_NETWORKING", "SPORTS", "TRAVEL", "UTILITIES", "WEATHER",
]

STORE_LANGUAGES = [
    ("English (United States)", "en-US"),
    ("French (France)", "fr-FR"),
    ("Vietnamese (Vietnam)", "vi-VN"),
    ("English (United Kingdom)", "en-GB"),
    ("German (Germany)", "de-DE"),
    ("Spanish (Spain)", "es-ES"),
    ("Italian (Italy)", "it-IT"),
    ("Portuguese (Brazil)", "pt-BR"),
]


def next_sku_number(apps_dir):
    """Return one more than the highest VKM SKU in existing app.env files."""
    highest = 0
    for path in glob.glob(os.path.join(apps_dir, "*", "app.env")):
        values = read_env_file(path)
        value = values.get("SKU_NUMBER", "")
        if not value:
            match = re.fullmatch(r"VKM(\d+)", values.get("SKU", ""), re.IGNORECASE)
            value = match.group(1) if match else ""
        if value.isdigit():
            highest = max(highest, int(value))
    return str(highest + 1)


def read_env_file(path):
    """KEY=VALUE file → dict (empty dict if the file is missing)."""
    values = {}
    if not os.path.isfile(path):
        return values
    for raw in read(path).splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def is_phone(v):
    return re.fullmatch(r"\+[0-9][0-9 ]{7,19}", v) is not None


def ask_profile(mr, old):
    """Questions about YOU (asked once, then reused for every app)."""
    p = dict(old)

    def q(key, label, default="", check=None, error="Invalid value.", allow_empty=False):
        p[key] = question(label, p.get(key) or default, check, error, allow_empty)

    print("    These details are the same for all your apps.")
    q("DEVELOPER_NAME", "Developer / company name (legal pages, copyright)", "Vu Khac")
    print("    App Review contact (private, only Apple sees it):")
    q("CONTACT_FIRST_NAME", "  First name")
    q("CONTACT_LAST_NAME", "  Last name")
    q("CONTACT_PHONE", "  Phone with country code (e.g. +33 6 12 34 56 78)", "", is_phone,
      "Start with + and the country code, digits and spaces only.")
    q("CONTACT_EMAIL", "  Email", "", is_email, "Not a valid email.")
    print("    Public contact (shown to users in the app and on the stores):")
    q("SUPPORT_EMAIL", "  Support email", p.get("CONTACT_EMAIL", ""), is_email, "Not a valid email.")
    q("PUBLIC_PHONE", "  Public phone for Google Play (empty = none)", "", is_phone,
      "Start with + and the country code.", True)
    q("DEVELOPER_WEBSITE", "  Your website (empty = each app's info page)", "", is_https,
      "Must start with https://", True)
    print("    Legal pages: one public site, e.g. GitHub Pages repo 'app-legal'.")
    q("LEGAL_BASE_URL", "  Legal pages base URL", "https://YOUR-GITHUB-NAME.github.io/app-legal",
      is_https, "Must start with https://")
    p["LEGAL_BASE_URL"] = p["LEGAL_BASE_URL"].rstrip("/")
    q("GOVERNING_LAW", "  Country whose law applies to the Terms", "France")

    print("    Apple (developer.apple.com → Account → Membership):")
    q("APPLE_TEAM_ID", "  Apple Team ID (10 characters)", "",
      lambda v: re.fullmatch(r"[A-Z0-9]{10}", v) is not None, "10 capital letters/digits.", True)
    q("APPLE_ID", "  Apple ID email (used by make ios-create / ios-privacy)", "", is_email,
      "Not a valid email.", True)
    keys = sorted(glob.glob(os.path.join(mr, "appstoreconnect", "private_keys", "AuthKey_*.p8")))
    if keys:
        print("    App Store Connect API keys found:")
        for i, k in enumerate(keys, 1):
            print("      %d) %s" % (i, os.path.basename(k)))
        current = str(keys.index(p["ASC_KEY_PATH"]) + 1) if p.get("ASC_KEY_PATH") in keys else "1"
        pick = question("  Which key? (number)", current,
                        lambda v: v.isdigit() and 1 <= int(v) <= len(keys), "Choose a number from the list.")
        p["ASC_KEY_PATH"] = keys[int(pick) - 1]
    else:
        warn("No AuthKey_*.p8 in appstoreconnect/private_keys — add ASC_KEY_PATH to the profile later.")
        p.setdefault("ASC_KEY_PATH", "")
    m = re.search(r"AuthKey_([A-Z0-9]+)\.p8$", p["ASC_KEY_PATH"])
    p["ASC_KEY_ID"] = m.group(1) if m else p.get("ASC_KEY_ID", "")
    print("    Issuer ID: App Store Connect → Users and Access → Integrations → App Store Connect API.")
    q("ASC_ISSUER_ID", "  Issuer ID", "", lambda v: re.fullmatch(r"[0-9a-fA-F-]{36}", v) is not None,
      "Looks like 69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx", True)

    p["PLAY_JSON_KEY"] = p.get("PLAY_JSON_KEY") or os.path.join(
        mr, "Android", "keys", "google-play-service-account.json")
    if not os.path.isfile(p["PLAY_JSON_KEY"]):
        warn("Google Play key not found: " + p["PLAY_JSON_KEY"])
    return p


PROFILE_ORDER = [
    ("# --- You ---", None), ("DEVELOPER_NAME", None),
    ("# --- App Review contact (private) ---", None),
    ("CONTACT_FIRST_NAME", None), ("CONTACT_LAST_NAME", None), ("CONTACT_PHONE", None), ("CONTACT_EMAIL", None),
    ("# --- Public contact ---", None),
    ("SUPPORT_EMAIL", None), ("PUBLIC_PHONE", None), ("DEVELOPER_WEBSITE", None),
    ("LEGAL_BASE_URL", None), ("GOVERNING_LAW", None),
    ("# --- Apple ---", None),
    ("APPLE_TEAM_ID", None), ("APPLE_ID", None), ("ASC_KEY_ID", None), ("ASC_ISSUER_ID", None), ("ASC_KEY_PATH", None),
    ("# --- Google Play ---", None), ("PLAY_JSON_KEY", None),
]


def save_profile(path, p):
    lines = ["# developer_profile.env — YOUR fixed details, shared by ALL apps.",
             "# Written by `make setup`. Edit by hand any time; every app reads it at release time.",
             "# Keep this file on your Mac only (it is outside every git repo)."]
    for key, _ in PROFILE_ORDER:
        if key.startswith("#"):
            lines.append("\n" + key)
        else:
            lines.append(env_line(key, p.get(key, "")).rstrip("\n"))
    write(path, "\n".join(lines) + "\n")
    ok("Profile saved: " + path)


def show_profile(p):
    for key, _ in PROFILE_ORDER:
        if not key.startswith("#"):
            print("    %-19s %s" % (key, p.get(key) or "(empty)"))


def ask():
    a = {}
    title("1/4  Your Mobile-Release folder")
    default_dir = os.environ.get("MOBILE_RELEASE_DIR", DEFAULT_MOBILE_RELEASE)
    if os.path.isdir(default_dir):
        mr = default_dir
        ok("Using shared folder: " + mr)
    else:
        mr = question("Mobile-Release folder", default_dir, os.path.isdir, "Folder not found.")
    a["mobile_release_dir"] = mr

    profile_path = os.path.join(mr, PROFILE_NAME)
    profile = read_env_file(profile_path)
    if profile:
        ok("Reusing saved developer profile: " + profile_path)
    else:
        title("First time: your developer profile (asked only once)")
        profile = ask_profile(mr, {})
        save_profile(profile_path, profile)
    a["profile"] = profile

    title("2/4  This app")
    supplied_name = os.environ.get("VFLUT_APP_NAME", "").strip()
    if supplied_name:
        a["app_name"] = supplied_name
        ok("App name: " + supplied_name)
    else:
        a["app_name"] = question("App name (shown under the icon)", "My App",
                                 lambda v: len(v) <= 30, "Max 30 characters (store limit).")
    print("    Bundle ID = the same unique ID on iOS and Android.")
    a["bundle_id"] = "com.khacmuoivu.%s" % slugify_app_name(a["app_name"])
    ok("Bundle ID: " + a["bundle_id"])
    apps_dir = os.environ.get("VFLUT_APPS_DIR", "/Users/khacmuoivu/Developer/Apps")
    a["sku_number"] = next_sku_number(apps_dir)
    ok("SKU: VKM" + a["sku_number"])
    a["seed_color"] = question("Main color, hex without # (e.g. 3F51B5)", "3F51B5",
                               lambda v: re.fullmatch(r"[0-9A-Fa-f]{6}", v) is not None,
                               "Use 6 hex characters like 3F51B5.").upper()
    a["store_languages"] = choose_many("Store languages", STORE_LANGUAGES)
    category_options = [(value.replace("_", " ").title(), value) for value in IOS_CATEGORIES]
    a["ios_category"] = choose_one(
        "App Store category", category_options, IOS_CATEGORIES.index("UTILITIES") + 1
    )

    title("3/4  Money, ads, sign-in")
    a["ads_enabled"] = yes_no("Enable AdMob banner + rewarded ads?", True)
    a["rewarded_ads_enabled"] = a["ads_enabled"]
    a["admob_app_ios"] = a["admob_app_android"] = ""
    a["banner_ios"] = a["banner_android"] = ""
    a["rewarded_ios"] = a["rewarded_android"] = ""
    a["interstitial_ios"] = a["interstitial_android"] = ""
    a["rewarded_interstitial_ios"] = a["rewarded_interstitial_android"] = ""
    a["native_ios"] = a["native_android"] = ""
    a["app_open_ios"] = a["app_open_android"] = ""
    if a["ads_enabled"]:
        print("    Google test IDs selected. Run ggad later to add live AdMob IDs.")
    a["pro_enabled"] = yes_no("Enable Free + Pro with RevenueCat validation?", True)
    a["revenuecat_enabled"] = a["pro_enabled"]
    a["sign_in_enabled"] = yes_no("Enable sign-in and account linking?", a["pro_enabled"])
    a["account_linking_after_pro"] = a["pro_enabled"] and a["sign_in_enabled"]
    a["apple_sign_in_enabled"] = a["sign_in_enabled"]
    a["google_sign_in_enabled"] = a["sign_in_enabled"]
    if a["sign_in_enabled"]:
        print("    Apple + Google/Firebase sign-in and account linking selected.")
    a["iap_enabled"] = a["pro_enabled"]

    title("4/4  Android signing")
    a["keystore_path"] = os.path.join(mr, "Android", "upload-keystore.jks")
    shared_props = os.path.join(mr, SHARED_KEYSTORE_PROPS)
    a["keystore_alias"] = a["keystore_password"] = a["key_password"] = ""
    a["save_keystore_props"] = False
    saved = read_env_file(shared_props)
    if saved.get("storePassword"):
        ok("Reusing saved signing settings: " + shared_props)
        a["keystore_path"] = saved.get("storeFile", a["keystore_path"])
        a["keystore_alias"] = saved.get("keyAlias", "upload")
        a["keystore_password"] = saved["storePassword"]
        a["key_password"] = saved.get("keyPassword", saved["storePassword"])
    elif os.path.isfile(a["keystore_path"]):
        print("    Upload keystore found. Leave the alias empty to set signing up later.")
        a["keystore_alias"] = question("Keystore key alias", "upload", allow_empty=True)
        if a["keystore_alias"]:
            a["keystore_password"] = getpass.getpass("  Keystore password (hidden): ").strip()
            a["key_password"] = (getpass.getpass("  Key password (hidden, empty = same): ").strip()
                                 or a["keystore_password"])
            print("    Save these so future apps don't ask again? They are stored in")
            print("    " + shared_props + " (on this Mac only, next to the keystore).")
            a["save_keystore_props"] = yes_no("Save for future apps?", True)
    else:
        warn("Upload keystore not found: " + a["keystore_path"])
    return a


def normalise(a):
    """Fill values that are derived from the answers + the developer profile."""
    p = a.get("profile", {})
    a["developer_name"] = p.get("DEVELOPER_NAME", "")
    a["support_email"] = p.get("SUPPORT_EMAIL", "")
    a["legal_base_url"] = p.get("LEGAL_BASE_URL", "").rstrip("/")
    a["governing_law"] = p.get("GOVERNING_LAW", "France")
    a["apple_team_id"] = p.get("APPLE_TEAM_ID", "")
    a["asc_key_path"] = p.get("ASC_KEY_PATH", "")
    a["play_json_key"] = p.get("PLAY_JSON_KEY", "")
    for key in ("developer_name", "support_email", "legal_base_url"):
        if not a[key]:
            fail("Developer profile is missing %s. Edit %s and run setup again."
                 % (key.upper(), os.path.join(a["mobile_release_dir"], PROFILE_NAME)))

    parts = a["bundle_id"].split(".")
    a["slug"] = parts[-1]              # e.g. scanpro  (Dart package + project name)
    a["org"] = ".".join(parts[:-1])    # e.g. com.khacvu
    a["legal_url"] = "%s/%s" % (a["legal_base_url"], a["slug"])
    a["store_languages"] = ",".join(x.strip() for x in a.get("store_languages", "en-US").split(","))
    a.setdefault("ios_category", "UTILITIES")
    a.setdefault("admob_app_ios", "")
    a.setdefault("admob_app_android", "")
    for key, default in {
        "rewarded_ads_enabled": False, "sign_in_enabled": False, "apple_sign_in_enabled": False,
        "google_sign_in_enabled": False, "revenuecat_enabled": a.get("iap_enabled", False),
        "pro_enabled": a.get("iap_enabled", False), "account_linking_after_pro": True,
        "sku_number": "1", "rewarded_ios": "", "rewarded_android": "",
        "interstitial_ios": "", "interstitial_android": "",
        "rewarded_interstitial_ios": "", "rewarded_interstitial_android": "",
        "native_ios": "", "native_android": "",
        "app_open_ios": "", "app_open_android": "",
        "revenuecat_apple_api_key": "", "revenuecat_google_api_key": "",
    }.items():
        a.setdefault(key, default)
    return a


# ---------------------------------------------------------------------
# 2. Rename Dart package
# ---------------------------------------------------------------------
def rename_package(a):
    title("Renaming Dart package → " + a["slug"])
    pubspec = os.path.join(ROOT, "pubspec.yaml")
    text = read(pubspec)
    text = re.sub(r"^name:\s*\S+", "name: " + a["slug"], text, count=1, flags=re.M)
    text = re.sub(r'^description:.*$', 'description: "%s"' % a["app_name"].replace('"', "'"),
                  text, count=1, flags=re.M)
    write(pubspec, text)
    for path in glob.glob(os.path.join(ROOT, "test", "**", "*.dart"), recursive=True) + \
            glob.glob(os.path.join(ROOT, "lib", "**", "*.dart"), recursive=True):
        t = read(path)
        if "package:%s/" % TEMPLATE_PACKAGE in t:
            write(path, t.replace("package:%s/" % TEMPLATE_PACKAGE, "package:%s/" % a["slug"]))
    ok("pubspec.yaml and imports updated")


# ---------------------------------------------------------------------
# 3. flutter create (makes ios/ and android/ for YOUR Flutter version)
# ---------------------------------------------------------------------
PROTECTED = ["lib", "test", "pubspec.yaml", "analysis_options.yaml", "README.md", ".gitignore"]


def flutter_create(a):
    title("Creating iOS + Android projects (flutter create)")
    if os.path.exists(os.path.join(ROOT, "ios")) or os.path.exists(os.path.join(ROOT, "android")):
        fail("ios/ or android/ already exists. Setup must run on a fresh copy of the template.")
    # Several template plugins still use CocoaPods. Keep Flutter's iOS SPM
    # integration off until google_mobile_ads/purchases/sign_in_with_apple all
    # support it, otherwise new apps can fail during pod install.
    config_cmd = ["flutter", "config", "--no-enable-swift-package-manager"]
    print("  $ " + " ".join(config_cmd))
    if subprocess.run(config_cmd, cwd=ROOT).returncode != 0:
        warn("Could not disable Flutter Swift Package Manager; iOS pod install may fail.")
    # Safety copy: flutter create never overwrites, but we double-check.
    backup = tempfile.mkdtemp(prefix="template_backup_")
    for name in PROTECTED:
        src = os.path.join(ROOT, name)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(backup, name))
        elif os.path.isfile(src):
            shutil.copy2(src, os.path.join(backup, name))
    cmd = ["flutter", "create", "--org", a["org"], "--project-name", a["slug"],
           "--platforms", "ios,android", "--description", a["app_name"], "."]
    print("  $ " + " ".join(cmd))
    result = subprocess.run(cmd, cwd=ROOT)
    # Put our files back exactly as they were.
    for name in PROTECTED:
        src = os.path.join(backup, name)
        dst = os.path.join(ROOT, name)
        if os.path.isdir(src):
            shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(src, dst)
        elif os.path.isfile(src):
            shutil.copy2(src, dst)
    shutil.rmtree(backup, ignore_errors=True)
    # flutter create adds a default test that does not match our app.
    default_test = os.path.join(ROOT, "test", "widget_test.dart")
    if os.path.exists(default_test):
        os.remove(default_test)
    if result.returncode != 0:
        fail("flutter create failed (see messages above).")
    ok("ios/ and android/ created")


# ---------------------------------------------------------------------
# 4a. Android patches
# ---------------------------------------------------------------------
def xml_escape(v):
    return (v.replace("&", "&amp;").replace('"', "&quot;")
            .replace("<", "&lt;").replace(">", "&gt;").replace("'", "\\'"))


def patch_android(a):
    title("Patching Android files")
    manifest_path = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.isfile(manifest_path):
        fail("Not found: " + manifest_path)
    m = read(manifest_path)

    # App name under the icon
    m, n = re.subn(r'android:label="[^"]*"', 'android:label="%s"' % xml_escape(a["app_name"]), m, count=1)
    ok("App name set") if n else warn("android:label not found — set the app name by hand")

    # AdMob App ID (REQUIRED, the app crashes at launch without it)
    if "com.google.android.gms.ads.APPLICATION_ID" not in m:
        block = ('        <!-- AdMob App ID (required by google_mobile_ads, even when ads are off) -->\n'
                 '        <meta-data\n'
                 '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
                 '            android:value="%s"/>\n'
                 '    </application>') % TEST_ADMOB_APP_ANDROID
        if "    </application>" in m:
            m = m.replace("    </application>", block, 1)
            ok("AdMob App ID added")
        else:
            fail("</application> not found in AndroidManifest.xml")

    # Let url_launcher open web pages and the email app (Android 11+)
    intents = ('        <intent>\n'
               '            <action android:name="android.intent.action.VIEW"/>\n'
               '            <data android:scheme="https"/>\n'
               '        </intent>\n'
               '        <intent>\n'
               '            <action android:name="android.intent.action.SENDTO"/>\n'
               '            <data android:scheme="mailto"/>\n'
               '        </intent>\n')
    if 'android:scheme="mailto"' not in m:
        if "<queries>" in m:
            m = m.replace("<queries>", "<queries>\n" + intents.rstrip("\n"), 1)
        else:
            m = m.replace("</manifest>", "    <queries>\n%s    </queries>\n</manifest>" % intents, 1)
        ok("Link/email queries added")
    write(manifest_path, m)

    # Release signing + minimum Android version
    kts = os.path.join(ROOT, "android", "app", "build.gradle.kts")
    groovy = os.path.join(ROOT, "android", "app", "build.gradle")
    if not os.path.isfile(kts):
        if os.path.isfile(groovy):
            warn("Old build.gradle (Groovy) found — release signing NOT patched. "
                 "Please update Flutter (flutter upgrade) and run setup again.")
            return
        fail("Not found: " + kts)
    g = read(kts)
    marker = "// [template] release signing"
    if marker not in g:
        header = ("import java.io.FileInputStream\n"
                  "import java.util.Properties\n\n")
        loader = ("\n%s — reads android/key.properties (never committed)\n"
                  "val keystoreProperties = Properties()\n"
                  "val keystorePropertiesFile = rootProject.file(\"key.properties\")\n"
                  "if (keystorePropertiesFile.exists()) {\n"
                  "    keystoreProperties.load(FileInputStream(keystorePropertiesFile))\n"
                  "}\n") % marker
        signing = ("    signingConfigs {\n"
                   "        create(\"release\") {\n"
                   "            keyAlias = keystoreProperties[\"keyAlias\"] as String?\n"
                   "            keyPassword = keystoreProperties[\"keyPassword\"] as String?\n"
                   "            storeFile = (keystoreProperties[\"storeFile\"] as String?)?.let { file(it) }\n"
                   "            storePassword = keystoreProperties[\"storePassword\"] as String?\n"
                   "        }\n"
                   "    }\n\n"
                   "    buildTypes {")
        plugins_end = re.search(r"^plugins\s*\{.*?^\}\s*$", g, flags=re.S | re.M)
        if not plugins_end or "    buildTypes {" not in g:
            warn("build.gradle.kts has an unexpected layout — signing NOT patched. See docs/NEW_APP_CHECKLIST.md.")
        else:
            g = g[:plugins_end.end()] + "\n" + loader + g[plugins_end.end():]
            g = header + g
            g = g.replace("    buildTypes {", signing, 1)
            # Remove Flutter's default TODO comments above the debug signing line.
            g = re.sub(r'[ \t]*// TODO: Add your own signing config.*\n', '', g)
            g = re.sub(r'[ \t]*// Signing with the debug keys for now.*\n', '', g)
            g, n = re.subn(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
                           '// Uses your upload key when android/key.properties exists,\n'
                           '            // otherwise debug keys (so `flutter run --release` still works).\n'
                           '            signingConfig = if (keystorePropertiesFile.exists())\n'
                           '                signingConfigs.getByName("release")\n'
                           '            else\n'
                           '                signingConfigs.getByName("debug")', g, count=1)
            ok("Release signing added") if n else warn("Release signingConfig line not found — check build.gradle.kts")
    # google_mobile_ads needs Android 6.0+ (API 23)
    g, n = re.subn(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = maxOf(flutter.minSdkVersion, 23)", g, count=1)
    if n:
        ok("minSdk ≥ 23")
    write(kts, g)

    # Check the ID flutter create used
    if 'applicationId = "%s"' % a["bundle_id"] not in g:
        warn("applicationId in build.gradle.kts is not %s — please check." % a["bundle_id"])


# ---------------------------------------------------------------------
# 4b. iOS patches
# ---------------------------------------------------------------------
def patch_ios(a):
    title("Patching iOS files")
    podfile = os.path.join(ROOT, "ios", "Podfile")
    if os.path.isfile(podfile):
        pod = read(podfile)
        pod, n = re.subn(r"^#\s*platform :ios, '15\.0'", "platform :ios, '15.0'", pod, count=1, flags=re.M)
        if n:
            write(podfile, pod)
            ok("Podfile platform set to iOS 15")
        elif "platform :ios" not in pod:
            write(podfile, "platform :ios, '15.0'\n" + pod)
            ok("Podfile platform set to iOS 15")

    plist_path = os.path.join(ROOT, "ios", "Runner", "Info.plist")
    if not os.path.isfile(plist_path):
        fail("Not found: " + plist_path)
    with open(plist_path, "rb") as f:
        plist = plistlib.load(f)
    plist["CFBundleDisplayName"] = a["app_name"]
    plist["FIREBASE_ANALYTICS_COLLECTION_ENABLED"] = False
    plist["GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED"] = False
    plist["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE"] = False
    plist["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA"] = False
    plist["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS"] = False
    # AdMob App ID (REQUIRED, the app crashes at launch without it)
    plist["GADApplicationIdentifier"] = TEST_ADMOB_APP_IOS
    # Text of the iOS tracking permission popup (App Tracking Transparency)
    plist["NSUserTrackingUsageDescription"] = (
        "Allow tracking across other companies’ apps and websites so ad partners can measure and personalize advertising. "
        "Ads may still appear if you decline.")
    # Google's ad network ID for iOS attribution
    items = plist.get("SKAdNetworkItems", [])
    if not any(i.get("SKAdNetworkIdentifier") == "cstr6suwn9.skadnetwork" for i in items):
        items.append({"SKAdNetworkIdentifier": "cstr6suwn9.skadnetwork"})
    plist["SKAdNetworkItems"] = items
    # "No special encryption" → skips the export question on every upload
    plist["ITSAppUsesNonExemptEncryption"] = False
    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f, sort_keys=False)
    ok("Info.plist: name, AdMob ID, tracking text, encryption flag")

    pbx = os.path.join(ROOT, "ios", "Runner.xcodeproj", "project.pbxproj")
    if os.path.isfile(pbx) and ("PRODUCT_BUNDLE_IDENTIFIER = %s;" % a["bundle_id"]) not in read(pbx):
        warn("iOS bundle ID in project.pbxproj is not %s — please check in Xcode." % a["bundle_id"])


def sync_ios_dependencies():
    """Keep legacy CocoaPods projects in sync before Xcode can archive them."""
    podfile = os.path.join(ROOT, "ios", "Podfile")
    if not os.path.isfile(podfile):
        return
    if shutil.which("pod") is None:
        warn("ios/Podfile exists but CocoaPods is unavailable — install CocoaPods, then run `cd ios && pod install`.")
        return

    title("Synchronizing iOS CocoaPods dependencies")
    if subprocess.run(["pod", "install"], cwd=os.path.join(ROOT, "ios")).returncode != 0:
        warn("pod install failed — run `cd ios && pod install` before building an IPA.")
    else:
        ok("Podfile.lock and Pods/Manifest.lock synchronized")


# ---------------------------------------------------------------------
# 5. lib/config/app_config.dart
# ---------------------------------------------------------------------
def dart_str(v):
    return v.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def write_app_config(a):
    title("Writing lib/config/app_config.dart")
    text = render(read(os.path.join(TEMPLATES, "app_config.dart.tmpl")), {
        "APP_NAME_DART": dart_str(a["app_name"]),
        "BUNDLE_ID": a["bundle_id"],
        "DEVELOPER_NAME_DART": dart_str(a["developer_name"]),
        "SEED_COLOR": a["seed_color"],
        "SUPPORT_EMAIL": a["support_email"],
        "LEGAL_URL": a["legal_url"],
        "SKU_NUMBER": a.get("sku_number", "1"),
        "ADS_ENABLED": "true" if a["ads_enabled"] else "false",
        "REWARDED_ADS_ENABLED": "true" if a.get("rewarded_ads_enabled") else "false",
        "SIGN_IN_ENABLED": "true" if a.get("sign_in_enabled") else "false",
        "APPLE_SIGN_IN_ENABLED": "true" if a.get("apple_sign_in_enabled") else "false",
        "GOOGLE_SIGN_IN_ENABLED": "true" if a.get("google_sign_in_enabled") else "false",
        "REVENUECAT_ENABLED": "true" if a.get("revenuecat_enabled") else "false",
        "PRO_ENABLED": "true" if a.get("pro_enabled") else "false",
        "ACCOUNT_LINKING_AFTER_PRO": "true" if a.get("account_linking_after_pro") else "false",
        "IOS_BANNER_ID": a["banner_ios"],
        "ANDROID_BANNER_ID": a["banner_android"],
        "IOS_REWARDED_ID": a.get("rewarded_ios", ""),
        "ANDROID_REWARDED_ID": a.get("rewarded_android", ""),
        "IOS_INTERSTITIAL_ID": a.get("interstitial_ios", ""),
        "ANDROID_INTERSTITIAL_ID": a.get("interstitial_android", ""),
        "IOS_REWARDED_INTERSTITIAL_ID": a.get("rewarded_interstitial_ios", ""),
        "ANDROID_REWARDED_INTERSTITIAL_ID": a.get("rewarded_interstitial_android", ""),
        "IOS_NATIVE_ID": a.get("native_ios", ""),
        "ANDROID_NATIVE_ID": a.get("native_android", ""),
        "IOS_APP_OPEN_ID": a.get("app_open_ios", ""),
        "ANDROID_APP_OPEN_ID": a.get("app_open_android", ""),
        "REVENUECAT_APPLE_API_KEY": a.get("revenuecat_apple_api_key", ""),
        "REVENUECAT_GOOGLE_API_KEY": a.get("revenuecat_google_api_key", ""),
    })
    write(os.path.join(ROOT, "lib", "config", "app_config.dart"), text)
    ok("done")


# ---------------------------------------------------------------------
# 6. Release files
# ---------------------------------------------------------------------
def env_line(key, value):
    value = str(value)
    if re.search(r"[\s#\"']", value):
        value = '"%s"' % value.replace('"', "'")
    return "%s=%s\n" % (key, value)


def write_release_files(a):
    title("Writing release files")
    # app.env — public, committed to git
    languages = a["store_languages"].split(",")
    app_env = ("# app.env — app identity (safe to commit). Written by make setup.\n"
               + env_line("APP_NAME", a["app_name"])
               + env_line("APP_SLUG", a["slug"])
               + env_line("BUNDLE_ID", a["bundle_id"])
               + env_line("SKU", "VKM" + str(a.get("sku_number", "1")))
               + env_line("ADS_ENABLED", "true" if a["ads_enabled"] else "false")
               + env_line("REWARDED_ADS_ENABLED", "true" if a.get("rewarded_ads_enabled") else "false")
               + env_line("PRO_ENABLED", "true" if a.get("pro_enabled") else "false")
               + env_line("REVENUECAT_ENABLED", "true" if a.get("revenuecat_enabled") else "false")
               + env_line("SIGN_IN_ENABLED", "true" if a.get("sign_in_enabled") else "false")
               + env_line("APPLE_SIGN_IN_ENABLED", "true" if a.get("apple_sign_in_enabled") else "false")
               + env_line("GOOGLE_SIGN_IN_ENABLED", "true" if a.get("google_sign_in_enabled") else "false")
               + env_line("ACCOUNT_LINKING_AFTER_PRO", "true" if a.get("account_linking_after_pro") else "false")
               + env_line("IAP_ENABLED", "true" if a["iap_enabled"] else "false")
               + "\n# --- Store listing (texts are in store/<language>/) ---\n"
               + env_line("STORE_LANGUAGES", a["store_languages"])
               + env_line("APP_PRIMARY_LANGUAGE", languages[0])
               + env_line("IOS_PRIMARY_CATEGORY", a["ios_category"])
               + env_line("LEGAL_URL", a["legal_url"]))
    app_env += ("\n# --- AdMob IDs (blank fields are reserved for units not created yet) ---\n")
    for platform, suffix in (("IOS", "ios"), ("ANDROID", "android")):
        app_env += env_line("ADMOB_%s_APP_ID" % platform, a.get("admob_app_%s" % suffix, ""))
        for env_name, answer_name in (
            ("BANNER_ID", "banner"), ("INTERSTITIAL_ID", "interstitial"),
            ("REWARDED_ID", "rewarded"),
            ("REWARDED_INTERSTITIAL_ID", "rewarded_interstitial"),
            ("NATIVE_ID", "native"), ("APP_OPEN_ID", "app_open"),
        ):
            app_env += env_line(
                "ADMOB_%s_%s" % (platform, env_name),
                a.get("%s_%s" % (answer_name, suffix), ""),
            )
    write(os.path.join(ROOT, "app.env"), app_env)
    ok("app.env")

    # .env — private, NOT committed
    dot_env = ("# .env — PRIVATE machine settings (ignored by git). Written by make setup.\n"
               "# Your fixed details (contact, Apple/Google keys) are read from\n"
               "# $MOBILE_RELEASE_DIR/developer_profile.env — shared by all apps.\n"
               "# To use a different value for THIS app only, add the line here,\n"
               "# e.g. SUPPORT_EMAIL=scanpro@example.com\n"
               + env_line("MOBILE_RELEASE_DIR", a["mobile_release_dir"]))
    write(os.path.join(ROOT, ".env"), dot_env)
    ok(".env (private)")

    # fastlane
    for platform in ("ios", "android"):
        dst = os.path.join(ROOT, platform, "fastlane")
        os.makedirs(dst, exist_ok=True)
        shutil.copy2(os.path.join(TEMPLATES, "fastlane", platform, "Fastfile"), os.path.join(dst, "Fastfile"))
    team = a["apple_team_id"]
    write(os.path.join(ROOT, "ios", "fastlane", "Appfile"),
          '# iOS app identity for fastlane (written by make setup)\n'
          'app_identifier("%s")\n%s' % (a["bundle_id"],
                                         'team_id("%s")\n' % team if team else '# team_id("XXXXXXXXXX")  # add your Apple Team ID\n'))
    write(os.path.join(ROOT, "android", "fastlane", "Appfile"),
          '# Android app identity for fastlane (written by make setup)\n'
          'json_key_file("%s")\npackage_name("%s")\n' % (a["play_json_key"], a["bundle_id"]))
    ok("ios/fastlane and android/fastlane")

    # Android signing
    example = ("# Copy this file to key.properties and fill it. key.properties is ignored by git.\n"
               "storeFile=%s\nkeyAlias=upload\nstorePassword=CHANGE_ME\nkeyPassword=CHANGE_ME\n"
               % a["keystore_path"])
    write(os.path.join(ROOT, "android", "key.properties.example"), example)
    if a.get("keystore_alias") and a.get("keystore_password"):
        write(os.path.join(ROOT, "android", "key.properties"),
              "# PRIVATE — ignored by git. Written by make setup.\n"
              "storeFile=%s\nkeyAlias=%s\nstorePassword=%s\nkeyPassword=%s\n"
              % (a["keystore_path"], a["keystore_alias"], a["keystore_password"], a["key_password"]))
        ok("android/key.properties (private)")
        if a.get("save_keystore_props"):
            shared = os.path.join(a["mobile_release_dir"], SHARED_KEYSTORE_PROPS)
            write(shared,
                  "# Shared Android signing settings — reused by every new app (this Mac only).\n"
                  "storeFile=%s\nkeyAlias=%s\nstorePassword=%s\nkeyPassword=%s\n"
                  % (a["keystore_path"], a["keystore_alias"], a["keystore_password"], a["key_password"]))
            ok("Signing settings saved for future apps: " + shared)
    else:
        warn("android/key.properties not created — copy key.properties.example and fill it before release.")

    # Make sure git never sees the secrets, even if android/.gitignore changes.
    gi = os.path.join(ROOT, ".gitignore")
    text = read(gi) if os.path.exists(gi) else ""
    for line in (".env", "android/key.properties", "*.jks", "*.keystore", "*.p8"):
        if line not in text.splitlines():
            text += ("\n" if text and not text.endswith("\n") else "") + line + "\n"
    write(gi, text)


# ---------------------------------------------------------------------
# 7. Legal pages
# ---------------------------------------------------------------------
def write_legal_pages(a):
    title("Writing legal pages → legal/%s/" % a["slug"])
    today = datetime.date.today().strftime("%d %B %Y")
    values = {
        "APP_NAME": html_escape(a["app_name"]),
        "APP_NAME_URL": urllib.parse.quote(a["app_name"]),
        "DEVELOPER_NAME": html_escape(a["developer_name"]),
        "SUPPORT_EMAIL": html_escape(a["support_email"]),
        "BUNDLE_ID": a["bundle_id"],
        "GOVERNING_LAW": html_escape(a["governing_law"]),
        "LAST_UPDATED": today,
    }
    out_dir = os.path.join(ROOT, "legal", a["slug"])
    src_dir = os.path.join(TEMPLATES, "legal")
    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".html"):
            continue
        text = read(os.path.join(src_dir, name))
        text = keep_blocks(text, "ADS", a["ads_enabled"])
        text = keep_blocks(text, "IAP", a["iap_enabled"])
        write(os.path.join(out_dir, name), render(text, values))
        ok(name)


def write_update_policy(a):
    title("Writing disabled app update policy")
    version_text = read(os.path.join(ROOT, "pubspec.yaml"))
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)', version_text, re.M)
    current = match.group(1) if match else '1.0.0'
    expires = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=90)).isoformat()
    policy = {"schemaVersion": 1, "appId": a["bundle_id"]}
    for platform in ("ios", "android"):
        policy[platform] = {"enabled": False, "storeAvailable": False,
            "latestVersion": current, "minimumSupportedVersion": current,
            "mode": "optional", "publishedReleases": [current], "expiresAt": expires,
            "storeUrl": "" if platform == "ios" else
                "https://play.google.com/store/apps/details?id=" + a["bundle_id"],
            "messages": {"en": "", "vi": "", "fr": ""}}
    destination = os.path.join(ROOT, "legal", a["slug"], "app-update.json")
    if not os.path.exists(destination):
        write(destination, json.dumps(policy, indent=2) + "\n")
    ok("Update policy ready for gbeta; keep disabled until public release.")


# ---------------------------------------------------------------------
# 8. Store listing texts (one folder per language, used by fastlane)
# ---------------------------------------------------------------------
def write_store_texts(a):
    title("Writing store texts → store/")
    src_dir = os.path.join(TEMPLATES, "store")
    values = {"APP_NAME": a["app_name"], "DEVELOPER_NAME": a["developer_name"]}
    os.makedirs(os.path.join(ROOT, "store"), exist_ok=True)
    shutil.copy2(os.path.join(src_dir, "README.md"), os.path.join(ROOT, "store", "README.md"))
    for lang in a["store_languages"].split(","):
        for name in sorted(os.listdir(os.path.join(src_dir, "texts"))):
            dst = os.path.join(ROOT, "store", lang, name)
            if not os.path.exists(dst):
                write(dst, render(read(os.path.join(src_dir, "texts", name)), values))
        ok("store/%s/" % lang)


def html_escape(v):
    return v.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="Turn the template into a new app.")
    parser.add_argument("--answers", help="JSON file with answers (skips questions)")
    parser.add_argument("--skip-flutter", action="store_true", help="do not run flutter commands")
    args = parser.parse_args()

    if os.path.exists(DONE_MARKER):
        fail("Setup already ran for this project. Start again from a fresh copy of the template.")
    if not args.skip_flutter and (os.path.exists(os.path.join(ROOT, "ios"))
                                  or os.path.exists(os.path.join(ROOT, "android"))):
        fail("ios/ or android/ already exists. Setup must run on a fresh copy of the template.")

    print("\033[1mFlutter App Template — new app setup\033[0m")
    print("Press Enter to accept the [default] value.")

    if args.answers:
        with open(args.answers, encoding="utf-8") as f:
            answers = json.load(f)
    else:
        answers = ask()
    a = normalise(answers)

    title("Summary")
    for label, key in [("App name", "app_name"), ("Bundle ID", "bundle_id"),
                       ("Legal pages", "legal_url"), ("Ads", "ads_enabled"),
                       ("Premium purchase", "iap_enabled"), ("Store languages", "store_languages"),
                       ("iOS category", "ios_category"), ("Apple Team", "apple_team_id"),
                       ("ASC key", "asc_key_path")]:
        print("  %-17s %s" % (label + ":", a.get(key) if a.get(key) not in ("", None) else "(not set)"))
    if not args.answers and not yes_no("Create the app with these values?", True):
        fail("Stopped. Nothing was changed.")

    rename_package(a)
    if not args.skip_flutter:
        flutter_create(a)
    patch_android(a)
    patch_ios(a)
    write_app_config(a)
    write_release_files(a)
    write_legal_pages(a)
    write_update_policy(a)
    write_store_texts(a)

    if not args.skip_flutter:
        title("flutter pub get")
        if subprocess.run(["flutter", "pub", "get"], cwd=ROOT).returncode != 0:
            warn("flutter pub get failed — run it again when online.")
        else:
            sync_ios_dependencies()

    write(DONE_MARKER, "setup done %s for %s\n" % (datetime.datetime.now().isoformat(timespec="seconds"),
                                                   a["bundle_id"]))
    title("All done 🎉")
    print("  Next steps: open docs/NEW_APP_CHECKLIST.md")
    print("  Quick test: make check   then   flutter run")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nStopped.")
        sys.exit(1)
