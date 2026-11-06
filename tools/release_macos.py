#!/usr/bin/env python3
"""Publish a packaged Vox DMG as the next release.

packaging/Info.plist holds the version. A release bumps it, builds the DMG,
creates the GitHub release tagged with the bare version (for example 0.1.1),
commits the bump, then points vox-browser.org/version, which the browser's
update check reads, at the new version.
"""
import hashlib
import json
import platform
import plistlib
import posixpath
import re
import shlex
import subprocess
import urllib.request

REPOSITORY = 'vox-browser/vox'
WEBSITE_HOST = 'vpm'
# vox-website serves this file at /version (VOX_VERSION_FILE in its service).
WEBSITE_VERSION_FILE = '/var/www/vox-browser.org/version'
VERSION_URL = 'https://vox-browser.org/version'
INFO_PLIST = 'packaging/Info.plist'
VERSION = re.compile(r'\d{1,9}(\.\d{1,9}){0,2}')
SSH_OPTIONS = ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15']


def parse_version(text):
    if not VERSION.fullmatch(text or ''):
        raise ValueError('Invalid release version: %r' % text)
    parts = [int(part) for part in text.split('.')]
    return tuple(parts + [0] * (3 - len(parts)))


def format_version(parts):
    return '.'.join(map(str, parts))


def next_version(current, released, requested=None):
    """An explicit version, a newer one already in Info.plist, or the next patch release."""
    previous = parse_version(released)
    if requested:
        chosen = parse_version(requested)
    elif parse_version(current) > previous:
        chosen = parse_version(current)
    else:
        chosen = previous[:2] + (previous[2] + 1,)
    if chosen <= previous:
        raise ValueError('%s is not newer than the released %s' % (format_version(chosen), released))
    return format_version(chosen)


def bundle_version(path):
    return plistlib.loads(path.read_bytes())['CFBundleShortVersionString']


def set_bundle_version(path, version):
    """Write the version and advance the build number once; keep the file's formatting."""
    text = path.read_text()
    info = plistlib.loads(text.encode())
    if info['CFBundleShortVersionString'] == version:
        return False
    values = dict(CFBundleShortVersionString=version,
                  CFBundleVersion=str(int(info.get('CFBundleVersion', '0')) + 1))
    for key, value in values.items():
        match = re.search(r'<key>%s</key>\s*<string>([^<]*)</string>' % key, text)
        if match is None:
            raise RuntimeError('%s has no %s string' % (path, key))
        text = text[:match.start(1)] + value + text[match.end(1):]
    if {key: plistlib.loads(text.encode())[key] for key in values} != values:
        raise RuntimeError('Could not update the version in ' + str(path))
    path.write_text(text)
    return True


def command(arguments, **kwargs):
    result = subprocess.run(arguments, capture_output=True, text=True, **kwargs)
    if result.returncode != 0:
        raise RuntimeError('%s failed: %s' % (shlex.join(arguments[:3]),
                                              (result.stderr or result.stdout).strip()))
    return result.stdout


def absent(arguments):
    """Run a GitHub query that should report "not found"; other failures are errors."""
    result = subprocess.run(arguments, capture_output=True, text=True)
    if result.returncode == 0:
        return False
    message = (result.stderr + result.stdout).lower()
    if 'not found' in message or 'http 404' in message:
        return True
    raise RuntimeError('%s failed: %s' % (shlex.join(arguments[:3]), message.strip()))


def released_version(repository):
    return command(['gh', 'release', 'view', '-R', repository, '--json', 'tagName',
                    '--jq', '.tagName']).strip()


def check_unreleased(repository, version):
    # A failed upload can leave a draft release; never reuse or replace it silently.
    if not absent(['gh', 'release', 'view', version, '-R', repository, '--json', 'tagName']):
        raise RuntimeError('%s already has a release %s (delete a leftover draft, or choose '
                           'another version with --version)' % (repository, version))
    if not absent(['gh', 'api', 'repos/%s/git/ref/tags/%s' % (repository, version)]):
        raise RuntimeError('%s already has a tag %s' % (repository, version))


def check_website(host, path=WEBSITE_VERSION_FILE):
    command(['ssh', *SSH_OPTIONS, host, 'test -d %s -a -w %s' % (
        shlex.quote(posixpath.dirname(path)), shlex.quote(posixpath.dirname(path)))])


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def release_assets(repository, version):
    output = command(['gh', 'release', 'view', version, '-R', repository, '--json', 'assets'])
    return {asset['name']: asset.get('digest') for asset in json.loads(output)['assets']}


def publish_release(repository, version, dmg, minimum):
    digest = sha256(dmg)
    machine = 'Apple silicon' if platform.machine() == 'arm64' else platform.machine()
    notes = ('Vox %s for macOS %s or later on %s.\n\nSHA-256 of %s: `%s`\n'
             % (version, minimum, machine, dmg.name, digest))
    print('Creating the %s release on %s with %s' % (version, repository, dmg.name), flush=True)
    command(['gh', 'release', 'create', version, str(dmg), '-R', repository,
             '--title', version, '--notes', notes])
    if release_assets(repository, version).get(dmg.name) != 'sha256:' + digest:
        raise RuntimeError('The GitHub release %s does not carry %s with SHA-256 %s'
                           % (version, dmg.name, digest))


def commit_version(root, version):
    if subprocess.run(['git', '-C', str(root), 'diff', '--quiet', 'HEAD', '--', INFO_PLIST]).returncode == 0:
        return False
    # Commit only Info.plist, even when other changes are staged.
    command(['git', '-C', str(root), 'commit', '--quiet', '-m', 'Release Vox ' + version,
             '--', INFO_PLIST])
    return True


def live_version(url=VERSION_URL):
    request = urllib.request.Request(url, headers={'Cache-Control': 'no-cache',
                                                   'User-Agent': 'Vox-release'})
    with urllib.request.urlopen(request, timeout=15) as response:
        return response.read(128).decode().strip()


def publish_website_version(version, host=WEBSITE_HOST, path=WEBSITE_VERSION_FILE, url=VERSION_URL):
    print('Pointing %s at %s' % (url, version), flush=True)
    # Replace the file atomically so a concurrent update check never reads it half-written.
    script = ('set -eu; umask 022; temporary=$(mktemp %s); cat > "$temporary"; '
              'chmod 0644 "$temporary"; mv -f "$temporary" %s'
              % (shlex.quote(posixpath.join(posixpath.dirname(path), '.version.XXXXXX')),
                 shlex.quote(path)))
    command(['ssh', *SSH_OPTIONS, host, script], input=version + '\n')
    served = live_version(url)
    if served != version:
        raise RuntimeError('%s serves %r instead of %s. Deploy vox-website with VOX_VERSION_FILE '
                           'support, then run: v run deploy.vsh --website-only' % (url, served, version))


def release(root, deploy, output=None, package_only=False, requested=None,
            repository=REPOSITORY, host=WEBSITE_HOST):
    """Bump, build, package and publish; return the DMG path."""
    info = root / INFO_PLIST
    released = released_version(repository)
    version = next_version(bundle_version(info), released, requested)
    # Fail before the long build when the release cannot be published.
    check_unreleased(repository, version)
    check_website(host)
    if package_only:
        built = bundle_version(root / 'Build/v/Vox.app/Contents/Info.plist')
        if built != version:
            raise RuntimeError('Build/v/Vox.app is version %s; run deploy.vsh without '
                               '--package-only to build %s' % (built, version))
    else:
        set_bundle_version(info, version)
    print('Releasing Vox %s (previous release: %s)' % (version, released), flush=True)
    dmg = deploy(root, output, package_only)
    packaged = json.loads(dmg.with_suffix('.dmg.json').read_text())['version']
    if packaged != version:
        raise RuntimeError('The DMG contains Vox %s, not %s' % (packaged, version))
    minimum = plistlib.loads(info.read_bytes())['LSMinimumSystemVersion']
    publish_release(repository, version, dmg, minimum)
    commit_version(root, version)
    publish_website_version(version, host)
    return dmg


def publish_website_only(root, repository=REPOSITORY, host=WEBSITE_HOST):
    """Point /version at the version in Info.plist once its DMG is on GitHub."""
    version = bundle_version(root / INFO_PLIST)
    if not any(name.endswith('.dmg') for name in release_assets(repository, version)):
        raise RuntimeError('The GitHub release %s has no DMG to download' % version)
    publish_website_version(version, host)
    return version
