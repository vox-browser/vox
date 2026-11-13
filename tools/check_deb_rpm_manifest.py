#!/usr/bin/env python3
"""Check the DEB/RPM scaffolding for consistency.

Verifies the nFPM manifest, wrapper, desktop entry, icon, and release
workflow that consume them. Run from the repository root:

    python3 tools/check_deb_rpm_manifest.py
"""
import re
import sys
from pathlib import Path

APP_ID = 'org.vox_browser.vox'
NFPM_YAML = Path('packaging/deb-rpm/nfpm.yaml')
WRAPPER = Path('packaging/deb-rpm/vox-wrapper.sh')
DESKTOP = Path(f'packaging/deb-rpm/{APP_ID}.desktop')
ICON_SRC = Path('packaging/Vox.png')
WORKFLOW = Path('.github/workflows/release-deb-rpm.yml')


def fail(message):
    print(f'error: {message}')
    return 1


def main():
    repo = Path(__file__).resolve().parent.parent
    failures = 0

    try:
        text = (repo / NFPM_YAML).read_text(encoding='utf-8')
    except OSError as err:
        return fail(f'cannot read {NFPM_YAML}: {err}')

    for needle in ('name: vox', 'arch: amd64', 'platform: linux',
                   'version: ${VOX_VERSION}', 'license: GPL-2.0-or-later',
                   'homepage: https://vox-browser.org',
                   'src: release-staging/deb-rpm-prime', 'type: tree',
                   'depends:'):
        if needle not in text:
            print(f'error: nfpm.yaml is missing {needle!r}')
            failures += 1
    if 'overrides:' not in text or 'rpm:' not in text:
        print('error: nfpm.yaml must carry per-packager rpm overrides')
        failures += 1
    if 'libicu74' not in text:
        print('error: nfpm.yaml DEB depends must keep libicu74 (Ubuntu 24.04 ABI)')
        failures += 1
    rpm_section = text.split('rpm:', 1)[1] if 'rpm:' in text else ''
    if '\n      - icu\n' in rpm_section or '\n      - icu\r\n' in rpm_section:
        print('error: nfpm.yaml rpm depends must not use system icu; the RPM vendors ICU 74 under /usr/lib/vox')
        failures += 1

    try:
        wrapper = (repo / WRAPPER).read_text(encoding='utf-8')
    except OSError as err:
        return fail(f'cannot read {WRAPPER}: {err}')
    for needle in ('../lib/vox', 'readlink -f', 'LD_LIBRARY_PATH="$libdir',
                     'exec "$libdir/vox" "$@"'):
        if needle not in wrapper:
            print(f'error: wrapper must contain {needle!r}')
            failures += 1
    for absolute in ('LD_LIBRARY_PATH="/usr/lib/vox', 'exec /usr/lib/vox/vox'):
        if absolute in wrapper:
            print(f'error: wrapper must not hard-code host path {absolute!r}; resolve relative to $0')
            failures += 1

    try:
        desktop = (repo / DESKTOP).read_text(encoding='utf-8')
    except OSError as err:
        return fail(f'cannot read {DESKTOP}: {err}')
    if 'Exec=vox %u' not in desktop:
        print('error: desktop entry must use single-URL Exec=vox %u (the parser rejects a second source)')
        failures += 1
    if 'Exec=vox %U' in desktop:
        print('error: desktop entry must not use %U; parse_launch_options supports only one source')
        failures += 1
    if f'Icon={APP_ID}' not in desktop:
        print('error: desktop entry must carry the app-id icon')
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
    for needle in ('packaging/deb-rpm/nfpm.yaml', 'nfpm package',
                   '--packager deb', '--packager rpm',
                   'usr/lib/vox', 'usr/bin/vox',
                   f'{APP_ID}.png',
                   'dpkg-deb', 'rpm2cpio',
                   '--headless-smoke', 'SHA256SUMS', 'gh release create',
                   '--latest=false', 'libicuuc.so.74'):
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
    print(f'DEB/RPM scaffolding is consistent for {APP_ID}.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
