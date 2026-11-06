#!/usr/bin/env python3
"""Publish a packaged Vox DMG as the next release.

packaging/Info.plist holds the version. A release commits the version bump
alone on master, builds that commit in a dedicated release checkout, creates
the GitHub release tagged with the bare version (for example 0.1.1), then
points vox-browser.org/version, which the browser's update check reads, at it.

The release checkout is a clone next to the canonical one with its own Build/
caches and build queue. Building there compiles only committed sources, while
other sessions keep working, building and committing in the canonical checkout.
"""
import contextlib
import fcntl
import hashlib
import json
from pathlib import Path
import platform
import plistlib
import posixpath
import re
import shlex
import subprocess
import time
import urllib.request

from rebuild_browser import repository_state

REPOSITORY = 'vox-browser/vox'
WEBSITE_HOST = 'vpm'
# vox-website serves this file at /version (VOX_VERSION_FILE in its service).
WEBSITE_VERSION_FILE = '/var/www/vox-browser.org/version'
VERSION_URL = 'https://vox-browser.org/version'
INFO_PLIST = 'packaging/Info.plist'
VERSION = re.compile(r'\d{1,9}(\.\d{1,9}){0,2}')
SSH_OPTIONS = ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15']
VERSION_KEYS = ('CFBundleShortVersionString', 'CFBundleVersion')


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


def with_bundle_version(text, version):
    """Info.plist text at version, with the build number advanced once; formatting kept."""
    info = plistlib.loads(text.encode())
    if info['CFBundleShortVersionString'] == version:
        return text
    values = dict(CFBundleShortVersionString=version,
                  CFBundleVersion=str(int(info.get('CFBundleVersion', '0')) + 1))
    for key, value in values.items():
        match = re.search(r'<key>%s</key>\s*<string>([^<]*)</string>' % key, text)
        if match is None:
            raise RuntimeError('Info.plist has no %s string' % key)
        text = text[:match.start(1)] + value + text[match.end(1):]
    if {key: plistlib.loads(text.encode())[key] for key in values} != values:
        raise RuntimeError('Could not update the version in Info.plist')
    return text


def set_bundle_version(path, version):
    text = path.read_text()
    updated = with_bundle_version(text, version)
    path.write_text(updated)
    return updated != text


def without_version(text):
    for key in VERSION_KEYS:
        text = re.sub(r'(<key>%s</key>\s*<string>)[^<]*' % key, lambda match: match.group(1), text)
    return text


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
    """Commit the version bump alone on master and return the commit to release.

    Other sessions' uncommitted and staged work stays where it is. An earlier
    attempt's uncommitted bump is reused; other uncommitted Info.plist edits stop
    the release instead of being committed with it.
    """
    git = ['git', '-C', str(root)]
    committed = command([*git, 'show', 'HEAD:' + INFO_PLIST])
    if plistlib.loads(committed.encode())['CFBundleShortVersionString'] != version:
        path = root / INFO_PLIST
        if without_version(path.read_text()) != without_version(committed):
            raise RuntimeError('%s has uncommitted changes besides the version; commit or '
                               'revert them first' % INFO_PLIST)
        path.write_text(with_bundle_version(committed, version))
        for attempt in range(30):
            # Pathspec commits leave other staged files out of the release commit.
            result = subprocess.run([*git, 'commit', '--quiet', '-m', 'Release Vox ' + version,
                                     '--', INFO_PLIST], capture_output=True, text=True)
            if result.returncode == 0:
                break
            if 'index.lock' not in result.stderr or attempt == 29:
                raise RuntimeError('Could not commit the version bump: ' + result.stderr.strip())
            time.sleep(1)  # Another session is committing.
    return command([*git, 'rev-parse', 'HEAD']).strip()


def release_checkout(root):
    # A sibling keeps the checkout-relative ../3rd dependency paths valid.
    return root.parent / (root.name + '-release')


def prepare_checkout(root, checkout, commit):
    """Check out commit in the release clone; its ignored Build/ caches stay warm."""
    if not (checkout / '.git').is_dir():
        if checkout.exists():
            raise RuntimeError('%s exists but is not a release checkout' % checkout)
        print('Creating the release checkout %s (the first build fetches and builds its '
              'native dependencies)' % checkout, flush=True)
        command(['git', 'clone', '--quiet', '--no-checkout', str(root), str(checkout)])
    git = ['git', '-C', str(checkout)]
    # The canonical repository is shallow, so Git copies its objects instead of
    # sharing them; fetch the commits made since the last release.
    command([*git, 'fetch', '--quiet', str(root), 'master'])
    if subprocess.run([*git, 'cat-file', '-e', commit + '^{commit}']).returncode:
        raise RuntimeError('%s is not on master' % commit)
    # The build supervisor builds only master; this clone's own master names the commit.
    command([*git, 'checkout', '--quiet', '--force', '-B', 'master', commit])
    command([*git, 'clean', '--quiet', '-ffd'])
    if command([*git, 'status', '--porcelain']).strip():
        raise RuntimeError('The release checkout %s is not clean' % checkout)


@contextlib.contextmanager
def release_lock(root):
    path = root / 'Build/release.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another release is running') from None
        yield


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
            repository=REPOSITORY, host=WEBSITE_HOST, checkout=None):
    """Bump, build the committed sources, package and publish; return the DMG path."""
    checkout = checkout or release_checkout(root)
    with release_lock(root):
        released = released_version(repository)
        version = next_version(bundle_version(root / INFO_PLIST), released, requested)
        # Fail before committing or building when the release cannot be published.
        check_unreleased(repository, version)
        check_website(host)
        if package_only:
            # Repackage the release checkout's commit; its receipt is checked below.
            if not (checkout / '.git').is_dir() or bundle_version(checkout / INFO_PLIST) != version:
                raise RuntimeError('The release checkout holds no build of %s; run deploy.vsh '
                                   'without --package-only' % version)
            commit = command(['git', '-C', str(checkout), 'rev-parse', 'HEAD']).strip()
        else:
            commit = commit_version(root, version)
            prepare_checkout(root, checkout, commit)
        # The build receipt names the inputs the compiler consumed; they must be this commit.
        expected = repository_state(checkout)['build_inputs_sha256']
        print('Releasing Vox %s from %s (previous release: %s)' % (version, commit[:12], released),
              flush=True)
        if output is None:
            output = root / 'Build/deploy' / ('Vox-%s-%s.dmg' % (version, platform.machine()))
        dmg = deploy(checkout, output, package_only)
        manifest = json.loads(dmg.with_suffix('.dmg.json').read_text())
        if manifest['version'] != version:
            raise RuntimeError('The DMG contains Vox %s, not %s' % (manifest['version'], version))
        compiled = manifest.get('source_build', {}).get('verified_inputs', {})
        if compiled.get('head') != commit or compiled.get('build_inputs_sha256') != expected:
            raise RuntimeError('The build did not compile the release commit %s; run deploy.vsh '
                               'again' % commit)
        minimum = plistlib.loads((checkout / INFO_PLIST).read_bytes())['LSMinimumSystemVersion']
        publish_release(repository, version, dmg, minimum)
        publish_website_version(version, host)
    return dmg


def publish_website_only(root, repository=REPOSITORY, host=WEBSITE_HOST):
    """Point /version at the version in Info.plist once its DMG is on GitHub."""
    version = bundle_version(root / INFO_PLIST)
    if not any(name.endswith('.dmg') for name in release_assets(repository, version)):
        raise RuntimeError('The GitHub release %s has no DMG to download' % version)
    publish_website_version(version, host)
    return version
