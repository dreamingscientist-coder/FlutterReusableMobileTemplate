#!/usr/bin/env python3
"""Discover public store links for this Flutter app; confirm nonempty replacements."""
import argparse
import json
import re
import sys
from pathlib import Path
from urllib.parse import urlencode, urlsplit, urlunsplit
from urllib.request import urlopen

FIELDS = ('appleAppUrl', 'googleAppUrl', 'appleDeveloperUrl', 'googleDeveloperUrl')
DEFINE_KEYS = dict(zip(FIELDS, ('APPLE_APP_STORE_URL', 'GOOGLE_PLAY_APP_URL',
                               'APPLE_DEVELOPER_URL', 'GOOGLE_PLAY_DEVELOPER_URL')))


def public_json(url):
    with urlopen(url, timeout=20) as response:
        return json.load(response)


def apple_links(bundle, app_id='', country='fr', fetch=public_json):
    query = {'country': country}
    query['id' if app_id else 'bundleId'] = app_id or bundle
    records = fetch('https://itunes.apple.com/lookup?' + urlencode(query)).get('results', [])
    matches = [item for item in records if item.get('bundleId') == bundle
               and (not app_id or str(item.get('trackId')) == app_id)]
    if len(matches) != 1:
        raise ValueError('No unique published Apple listing matches this project bundle ID; keeping existing links.')
    item = matches[0]
    result = {}
    for field, key in [('appleAppUrl', 'trackViewUrl'), ('appleDeveloperUrl', 'artistViewUrl')]:
        uri = urlsplit(item.get(key, ''))
        if uri.scheme != 'https' or uri.hostname != 'apps.apple.com':
            raise ValueError('Apple lookup returned an unexpected store URL')
        # Retain Apple’s storefront and slug. Remove affiliate/tracking queries.
        result[field] = urlunsplit((uri.scheme, uri.netloc, uri.path, '', ''))
    return result


def project_identity(root, platform):
    if platform == 'ios':
        path = root / 'ios/Runner.xcodeproj/project.pbxproj'
        if path.exists():
            ids = set(re.findall(r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*"?([\w.-]+)', path.read_text()))
            ids = {item for item in ids if not item.endswith('.RunnerTests')}
            if len(ids) == 1:
                return ids.pop()
    else:
        for name in ('build.gradle.kts', 'build.gradle'):
            path = root / 'android/app' / name
            if path.exists():
                match = re.search(r'applicationId\s*(?:=\s*)?[\'"]([\w.-]+)', path.read_text())
                if match:
                    return match[1]
    raise ValueError('Cannot determine a unique project identity; pass --identity explicitly.')


def read_defaults(root):
    paths = [root / 'lib/features/settings/store_links.dart', root / 'lib/services/store_links.dart']
    service = next((p for p in paths if p.exists()), None)
    if service is None:
        raise ValueError('This project needs the reusable StoreLinks service before configuring links.')
    config = service.with_name('store_links_config.dart')
    values = dict.fromkeys(FIELDS, '')
    if config.exists():
        values.update(dict(re.findall(r"static const (\w+)\s*=\s*'([^']*)';", config.read_text())))
    else:
        text = service.read_text()
        for field in FIELDS:
            match = re.search(r'this\.' + field + r'\s*=\s*const String.fromEnvironment\((.*?)\)', text, re.S)
            if match:
                default = re.search(r"defaultValue:\s*'([^']*)'", match[1])
                if default:
                    values[field] = default[1]
    return service, config, values


def merge_links(existing, discovered, confirm):
    result = existing.copy()
    for key, value in discovered.items():
        if value == result.get(key):
            continue
        if not result.get(key) or confirm(key, result[key], value):
            result[key] = value
    return result


def atomic_write(path, text):
    tmp = path.with_name(path.name + '.tmp')
    tmp.write_text(text)
    tmp.replace(path)


def synchronize(root, discovered, confirm, dry_run=False):
    service, config, existing = read_defaults(root)
    updated = merge_links(existing, discovered, confirm)
    if dry_run:
        print(json.dumps(updated, indent=2))
        return updated
    # Validated public URLs only; never embed credentials or arbitrary Dart code.
    for field, value in updated.items():
        if value and (urlsplit(value).scheme != 'https' or urlsplit(value).hostname !=
                      ('apps.apple.com' if field.startswith('apple') else 'play.google.com')
                      or re.search(r"['\n\r\\$]", value)):
            raise ValueError('Invalid store URL for ' + field)
    text = service.read_text()
    if "import 'store_links_config.dart';" not in text:
        text = "import 'store_links_config.dart';\n" + text
    for field in FIELDS:
        pattern = r'(this\.' + field + r'\s*=\s*const String.fromEnvironment\()(.*?)(\))'
        def replace(match, field=field):
            return match[1] + '\n      ' + repr(DEFINE_KEYS[field]) + ',\n      defaultValue: StoreLinksConfig.' + field + ',\n    ' + match[3]
        text, count = re.subn(pattern, replace, text, count=1, flags=re.S)
        if count != 1:
            raise ValueError('Unsupported StoreLinks constructor: ' + field)
    content = '// Public store defaults maintained by tool/sync_store_links.py.\nclass StoreLinksConfig {\n'
    content += ''.join(f"  static const {key} = '{updated[key]}';\n" for key in FIELDS) + '}\n'
    if config.exists() and config.read_text() != content:
        config.with_suffix('.dart.bak').write_text(config.read_text())
    atomic_write(config, content)
    if text != service.read_text():
        atomic_write(service, text)
    # Existing explicit build overrides must follow the same confirmation rule.
    for path in root.glob('admob_*_defines.json'):
        data = json.loads(path.read_text())
        changed = False
        for field, value in discovered.items():
            key = DEFINE_KEYS[field]
            if key in data and data[key] != value:
                if not data[key] or confirm(key + ' in ' + path.name, data[key], value):
                    data[key] = value
                    changed = True
        if changed:
            path.with_suffix('.json.bak').write_text(path.read_text())
            atomic_write(path, json.dumps(data, indent=2) + '\n')
    # Keep update-store destinations in sync without activating any policy.
    for policy_path in [root / 'app-update.json', *sorted((root / 'legal').glob('*/app-update.json'))]:
        if not policy_path.exists():
            continue
        policy = json.loads(policy_path.read_text())
        for platform, field in [('ios', 'appleAppUrl'), ('android', 'googleAppUrl')]:
            if updated.get(field) and isinstance(policy.get(platform), dict):
                policy[platform]['storeUrl'] = updated[field]
        atomic_write(policy_path, json.dumps(policy, indent=2) + '\n')
    print('Public store defaults saved. Rebuild the app to use them.')
    return updated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=Path.cwd())
    parser.add_argument('--platform', choices=['ios', 'android'], required=True)
    parser.add_argument('--store-id', default='')
    parser.add_argument('--identity', default='')
    parser.add_argument('--country', default='fr')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    root = args.project.resolve()
    identity = args.identity or project_identity(root, args.platform)
    if args.platform == 'ios':
        if args.store_id and not args.store_id.isdigit():
            raise ValueError('Apple store ID must be numeric (not an AdMob app ID).')
        discovered = apple_links(identity, args.store_id, args.country)
    else:
        if not args.store_id:
            print('No linked Google Play listing yet; keeping existing Android links.')
            return
        if args.store_id != identity:
            raise ValueError('Linked Google Play package does not match the project; keeping existing links.')
        discovered = {'googleAppUrl': 'https://play.google.com/store/apps/details?' + urlencode({'id': identity})}
    print('Verified public links for ' + identity + ':')
    for key, value in discovered.items():
        print('  ' + key + ': ' + value)
    def confirm(key, old, new):
        print(f'Replace {key}?\n  Current: {old}\n  Found:   {new}')
        if args.dry_run or not sys.stdin.isatty():
            print('Keeping existing value (no interactive confirmation).')
            return False
        return input('Replace? [y/N]: ').strip().lower() == 'y'
    synchronize(root, discovered, confirm, args.dry_run)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        sys.exit('Store links: ' + str(error))
