#!/usr/bin/env python3
"""Check the Snap scaffolding for consistency.

Verifies the snapcraft manifest parses (when PyYAML is available),
carries the minimum metadata for a releasable Snap, and agrees with the
desktop entry, icon, and release workflow that consume it. Run from the
repository root:

    python3 tools/check_snap_manifest.py
"""
import re
import sys
from pathlib import Path

APP_ID = 'org.vox_browser.vox'
SNAP_YAML = Path('packaging/snap/snapcraft.yaml')
DESKTOP = Path(f'packaging/snap/{APP_ID}.desktop')
ICON_SRC = Path('packaging/Vox.png')
WORKFLOW = Path('.github/workflows/release-snap.yml')


def fail(message):
    print(f'error: {message}')
    return 1


def main():
    repo = Path(__file__).resolve().parent.parent
    failures = 0

    try:
        text = (repo / SNAP_YAML).read_text(encoding='utf-8')
    except OSError as err:
        return fail(f'cannot read {SNAP_YAML}: {err}')

    try:
        import yaml

        manifest = yaml.safe_load(text)
    except ImportError:
        manifest = None
        print('note: PyYAML is unavailable; running text-level checks only')
    except Exception as err:
        return fail(f'cannot parse {SNAP_YAML}: {err}')

    if manifest is not None:
        expected = {
            'name': 'vox',
            'base': 'core24',
            'confinement': 'classic',
        }
        for key, want in expected.items():
            if manifest.get(key) != want:
                print(f"error: snapcraft.yaml sets {key!r} to "
                      f"{manifest.get(key)!r}, want {want!r}")
                failures += 1
        apps = manifest.get('apps', {})
        if apps.get('vox', {}).get('command') != 'bin/vox':
            print('error: apps.vox.command must be bin/vox')
            failures += 1
        if apps.get('vox', {}).get('common-id') != APP_ID:
            print(f'error: apps.vox.common-id must be {APP_ID}')
            failures += 1
        parts = manifest.get('parts', {})
        if parts.get('vox', {}).get('plugin') != 'dump':
            print('error: parts.vox.plugin must be dump')
            failures += 1
        if parts.get('vox', {}).get('source') != 'release-staging/snap-prime':
            print('error: parts.vox.source must be release-staging/snap-prime')
            failures += 1
    else:
        for needle in ('name: vox', 'base: core24', 'confinement: classic',
                       'command: bin/vox', f'common-id: {APP_ID}',
                       'plugin: dump', 'source: release-staging/snap-prime',
                       'packaging/version.txt'):
            if needle not in text:
                print(f'error: snapcraft.yaml is missing {needle!r}')
                failures += 1

    try:
        desktop = (repo / DESKTOP).read_text(encoding='utf-8')
    except OSError as err:
        return fail(f'cannot read {DESKTOP}: {err}')
    if 'Exec=vox' not in desktop or f'Icon={APP_ID}' not in desktop:
        print('error: desktop entry must Exec vox with the app-id icon')
        failures += 1
    if 'MimeType=' not in desktop or 'x-scheme-handler/https' not in desktop:
        print('error: desktop entry must handle http/https links')
        failures += 1

    if not (repo / ICON_SRC).is_file():
        print(f'error: icon source {ICON_SRC} is missing')
        failures += 1

    try:
        workflow = (repo / WORKFLOW).read_text(encoding='utf-8')
    except OSError as err:
        return fail(f'cannot read {WORKFLOW}: {err}')
    for needle in ('packaging/snap/snapcraft.yaml', 'snap/gui/',
                   f'snap/gui/{APP_ID}.png', 'unsquashfs',
                   '--headless-smoke', 'SHA256SUMS', 'gh release create'):
        if needle not in workflow:
            print(f'error: {WORKFLOW} never mentions {needle!r}')
            failures += 1

    try:
        version = (repo / 'packaging/version.txt').read_text(
            encoding='utf-8-sig').strip()
    except OSError as err:
        return fail(f'cannot read packaging/version.txt: {err}')
    if not re.fullmatch(r'[0-9][0-9A-Za-z.\-]*', version):
        print(f'error: packaging/version.txt holds no usable version: {version!r}')
        failures += 1

    if failures:
        print(f'{failures} problem(s) found.')
        return 1
    print(f'Snap scaffolding is consistent for {APP_ID}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
