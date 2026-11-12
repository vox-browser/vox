#!/usr/bin/env python3
"""Check the Flathub scaffolding for consistency.

Verifies the manifest parses, pins a runtime, carries the minimum sandbox
permissions for a browser, and installs the metainfo, desktop entry and
icon that agree with the app id. Run from the repository root:

    python3 tools/check_flatpak_manifest.py
"""
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

APP_ID = 'org.vox_browser.vox'


def fail(message):
    print(f'error: {message}')
    return 1


def main():
    repo = Path(__file__).resolve().parent.parent
    flatpak = repo / 'packaging/flatpak'
    manifest_path = flatpak / f'{APP_ID}.json'
    metainfo_path = flatpak / f'{APP_ID}.metainfo.xml'
    desktop_path = flatpak / f'{APP_ID}.desktop'
    failures = 0

    try:
        manifest = json.loads(manifest_path.read_text())
    except (OSError, json.JSONDecodeError) as err:
        return fail(f'cannot parse {manifest_path}: {err}')

    for key in ('app-id', 'runtime', 'runtime-version', 'sdk', 'command',
                'finish-args', 'modules'):
        if key not in manifest:
            print(f'error: manifest is missing {key!r}')
            failures += 1
    if manifest.get('app-id') != APP_ID:
        print(f"error: app-id is {manifest.get('app-id')!r}, want {APP_ID!r}")
        failures += 1

    # A browser needs network, IPC, display, audio and GPU access. Anything
    # beyond this list deserves a comment in the manifest.
    required_args = {'--share=ipc', '--share=network', '--socket=x11',
                     '--socket=wayland', '--socket=pulseaudio', '--device=dri'}
    missing = required_args - set(manifest.get('finish-args', []))
    if missing:
        print(f'error: finish-args is missing {sorted(missing)}')
        failures += 1

    modules = {module.get('name'): module
               for module in manifest.get('modules', [])}
    for name in ('v', 'ui2', 'vox'):
        if name not in modules:
            print(f'error: manifest has no {name!r} module')
            failures += 1
    vox = modules.get('vox', {})
    build_text = '\n'.join(vox.get('build-commands', []))
    for needle in ('metainfo', '.desktop', 'icons', '/app/bin/vox'):
        if needle not in build_text:
            print(f'error: vox module never installs {needle}')
            failures += 1

    try:
        meta = ET.parse(metainfo_path).getroot()
    except (OSError, ET.ParseError) as err:
        return fail(f'cannot parse {metainfo_path}: {err}')
    if meta.findtext('id') != APP_ID:
        print('error: metainfo id does not match the app id')
        failures += 1

    try:
        desktop = desktop_path.read_text()
    except OSError as err:
        return fail(f'cannot read {desktop_path}: {err}')
    if 'Exec=vox' not in desktop or f'Icon={APP_ID}' not in desktop:
        print('error: desktop entry must Exec vox with the app-id icon')
        failures += 1

    if failures:
        print(f'{failures} problem(s) found.')
        return 1
    print(f'Flathub scaffolding is consistent for {APP_ID}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
