#!/usr/bin/env python3
"""Prepare local update intentions. Never activates or publishes the live policy."""
import argparse
import datetime as dt
import json
from pathlib import Path
import re
import tempfile


def version(value):
    if not re.fullmatch(r'\d+\.\d+\.\d+', value):
        raise ValueError('Version must be major.minor.patch')
    return tuple(map(int, value.split('.')))


def read_build(root):
    match = re.search(r'^version:\s*[\"\']?(\d+\.\d+\.\d+)\+(\d+)[\"\']?\s*(?:#.*)?$', (root / 'pubspec.yaml').read_text(), re.M)
    if not match:
        raise ValueError('pubspec.yaml needs version: major.minor.patch+build')
    return match.group(1), match.group(2)


def policy_path(root):
    candidates = [p for p in [root / 'app-update.json', *sorted((root / 'legal').glob('*/app-update.json'))] if p.exists()]
    if len(candidates) != 1:
        raise ValueError('Expected one app-update.json in project root or legal/APP/. Configure the app update checker first.')
    return candidates[0]


def save(path, data):
    with tempfile.NamedTemporaryFile('w', dir=path.parent, delete=False, prefix='.update-policy-') as file:
        json.dump(data, file, indent=2, ensure_ascii=False)
        file.write('\n')
    Path(file.name).replace(path)


def prepare(root, mode, minimum=''):
    source = policy_path(root)
    policy = json.loads(source.read_text())
    if policy.get('schemaVersion') != 1:
        raise ValueError('Unsupported update policy schema')
    local_version, _ = read_build(root)
    if minimum:
        if version(minimum) > version(local_version):
            raise ValueError('Minimum cannot exceed the local version; change it after store-aware version planning if needed.')
    platforms = {}
    for platform in ('ios', 'android'):
        current = policy.get(platform)
        if not isinstance(current, dict):
            continue
        minimum_version = minimum or current.get('minimumSupportedVersion', local_version)
        version(minimum_version)
        platforms[platform] = {'minimumSupportedVersion': minimum_version, 'uploadSucceeded': False}
    if not platforms:
        raise ValueError('Policy has no iOS or Android settings')
    pending = {'schemaVersion': 1, 'status': 'pending_store_publication',
               'preparedAt': dt.datetime.now(dt.timezone.utc).isoformat(),
               'policyFile': str(source.relative_to(root)), 'mode': mode,
               'platforms': platforms}
    save(root / 'app-update.pending.json', pending)
    print(f'Pending update policy saved: {mode}. Live app-update.json unchanged.')


def record(root, platform):
    path = root / 'app-update.pending.json'
    pending = json.loads(path.read_text())
    current = pending['platforms'][platform]
    release, build = read_build(root)
    if version(current['minimumSupportedVersion']) > version(release):
        raise ValueError('Minimum version exceeds uploaded version; correct pending policy before publication.')
    current.update(version=release, build=build, uploadSucceeded=True)
    save(path, pending)
    print(f'Pending {platform} policy: {release}+{build}, {pending["mode"]}. Not activated.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare', 'record'])
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--mode', choices=['optional', 'required'])
    parser.add_argument('--minimum', default='')
    parser.add_argument('--platform', choices=['ios', 'android'])
    args = parser.parse_args()
    try:
        if args.action == 'prepare':
            if not args.mode:
                raise ValueError('--mode is required')
            prepare(args.root, args.mode, args.minimum)
        else:
            if not args.platform:
                raise ValueError('--platform is required')
            record(args.root, args.platform)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f'Update policy: {error}\n')


if __name__ == '__main__':
    main()
