#!/usr/bin/env python3
"""Release Vox: commit the version bump, build that commit with literal -prod / single C
unit in the ../vox2-release checkout, package a stripped macOS DMG, upload it to a new
GitHub release and update vox-browser.org/version. Uncommitted work is never released."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import shlex
import subprocess
import sys
import tempfile
import uuid

from browser_bundle_lease import publication_lease
from bundle_macos_libraries import bundle_libraries, macho_files, verify_self_contained
from rebuild_browser import production_environment
import release_macos

ROOT = Path(__file__).resolve().parents[1]
README = 'README HOW TO RUN VOX.txt'


def run(command, root, **kwargs):
    command = [str(part) for part in command]
    print('+ ' + shlex.join(command), flush=True)
    subprocess.run(command, cwd=root, check=True, **kwargs)


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def bundle_identity(bundle):
    """Include resources, native libraries, modes and symlink targets in the pin."""
    digest = hashlib.sha256()
    for path in sorted(bundle.rglob('*')):
        digest.update(os.fsencode(path.relative_to(bundle)) + b'\0')
        digest.update(str(path.lstat().st_mode & 0o7777).encode() + b'\0')
        if path.is_symlink():
            digest.update(b'link\0' + os.fsencode(os.readlink(path)) + b'\0')
        elif path.is_file():
            digest.update(b'file\0' + sha256(path).encode() + b'\0')
        else:
            digest.update(b'dir\0')
    return digest.hexdigest()


def verified_build(root, bundle):
    receipt = json.loads((root / 'Build/production-build/latest.json').read_text())
    mode = receipt.get('c_compile', {})
    if (receipt.get('exit') != 0 or mode.get('mode') != 'single'
            or mode.get('requested') != 'single' or mode.get('v_prod') is not True):
        raise RuntimeError('The completed production build must use --prod --no-parallel-cc')
    if sha256(bundle / 'Contents/MacOS/Vox') != receipt.get('executable_sha256'):
        raise RuntimeError('The canonical Vox executable does not match its build receipt')
    return receipt


def minimum_macos(binary):
    """Return the Mach-O minimum macOS version, or None for non-Mach-O files."""
    result = subprocess.run(['/usr/bin/vtool', '-show-build', str(binary)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] == 'minos':
            return tuple(int(x) for x in parts[1].split('.'))
    return None


def macos_version(parts):
    """Pad so 26 and 26.0 compare equal."""
    return (tuple(parts) + (0, 0, 0))[:3]


def verify_deployment_target(app, declared):
    """Reject a bundle whose Mach-O files require a newer macOS than Info.plist declares."""
    if not declared or not all(part.isdigit() for part in declared.split('.')):
        raise RuntimeError('Info.plist must declare a numeric LSMinimumSystemVersion')
    supported = macos_version(int(x) for x in declared.split('.'))
    for path in sorted((app / 'Contents').rglob('*')):
        if path.is_symlink() or not path.is_file() or path.suffix in ('.plist', '.json', '.txt'):
            continue
        minimum = minimum_macos(path)
        if minimum is not None and macos_version(minimum) > supported:
            raise RuntimeError('%s requires macOS %s; the release declares macOS %s'
                               % (path.relative_to(app), '.'.join(map(str, minimum)), declared))


def guarded(command, root, reports, name, limit_gib=12, **kwargs):
    run([sys.executable, root / 'tools/run_memory_bounded.py',
         '--lock', reports / (name + '.lock'), '--report', reports / (name + '.json'),
         '--limit-gib', str(limit_gib), '--', *command], root, **kwargs)


def deploy(root=ROOT, output=None, package_only=False):
    if not package_only:
        # The canonical supervisor supplies the memory guard and build receipts.
        # Drop inherited supervision/profiling overrides before entering it. The
        # build targets Info.plist's LSMinimumSystemVersion itself.
        run(['sh', root / 'build-prod-browser.sh', '--prod', '--no-parallel-cc'],
            root, env=production_environment(os.environ))

    source = root / 'Build/v/Vox.app'
    with tempfile.TemporaryDirectory(prefix='vox-dmg-') as directory:
        work = Path(directory)
        payload = work / 'payload'
        payload.mkdir()
        app = payload / 'Vox.app'
        # Stage only this release payload, outside Build's shared browser and
        # benchmark directories. A publisher cannot exchange it during the copy.
        with publication_lease(root, shared=True):
            receipt = verified_build(root, source)
            source_identity = bundle_identity(source)
            run(['/usr/bin/ditto', source, app], root)
            if bundle_identity(source) != source_identity or bundle_identity(app) != source_identity:
                raise RuntimeError('The source bundle changed while staging the release')

        # The build links vcpkg and Homebrew libraries by absolute build-machine
        # paths. Carry them inside the release and drop those search paths.
        bundle_libraries(app)
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        verify_deployment_target(app, info.get('LSMinimumSystemVersion', ''))
        version = info['CFBundleShortVersionString']
        if not version or any(c not in '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-+' for c in version):
            raise RuntimeError('Invalid release version in Info.plist')
        if output is None:
            output = root / 'Build/deploy' / ('Vox-' + version + '-' + platform.machine() + '.dmg')
        output = Path(output).resolve()
        if output.suffix.lower() != '.dmg' or output.is_relative_to(source.resolve()):
            raise RuntimeError('Choose a .dmg output path outside the canonical app')
        output.parent.mkdir(parents=True, exist_ok=True)
        reports = output.parent / 'receipts' / uuid.uuid4().hex
        reports.mkdir(parents=True)

        entitlements = root / 'packaging/Vox.entitlements.plist'
        binaries = [app / 'Contents/MacOS' / name for name in ('Vox', 'VoxAdblockWorker')]
        sizes = {}
        for binary in binaries:
            before = binary.stat().st_size
            # Preserve externally visible symbols needed by native bridges.
            run(['/usr/bin/strip', '-x', binary], root)
            sizes[binary.name] = dict(before=before, stripped=binary.stat().st_size)

        # Stripping and bundling invalidate signatures. Retain ad-hoc runtime
        # signatures and the JIT entitlement, without claiming a Developer ID or
        # notarization. Nested libraries must be signed before the app.
        for library in macho_files(app):
            if library not in binaries:
                run(['/usr/bin/codesign', '--force', '--sign', '-', library], root)
        run(['/usr/bin/codesign', '--force', '--sign', '-', '--entitlements',
             entitlements, binaries[1]], root)
        run(['/usr/bin/codesign', '--force', '--sign', '-', '--entitlements',
             entitlements, app], root)
        run(['/usr/bin/codesign', '--verify', '--deep', '--strict', app], root)
        verify_self_contained(app)
        (payload / README).write_bytes((root / 'packaging' / README).read_bytes())
        (payload / 'Applications').symlink_to('/Applications', target_is_directory=True)

        # Execute the stripped/re-signed browser before publishing the image.
        environment = production_environment(os.environ)
        environment.update(VOX_PROFILE_DIR=str(work / 'smoke-profile'), VOX_TEST_WINDOW='1')
        guarded([binaries[0], '--headless-smoke'], root, reports, 'smoke', 3, env=environment)
        packaged_identity = bundle_identity(app)

        # Build and verify in a temporary location before replacing an existing DMG.
        with tempfile.TemporaryDirectory(prefix='.vox-dmg-', dir=output.parent) as image_directory:
            image = Path(image_directory) / 'Vox.dmg'
            guarded(['/usr/bin/hdiutil', 'create', '-volname', 'Vox', '-fs', 'HFS+',
                     '-format', 'UDZO', '-srcfolder', payload, image], root, reports, 'create')
            guarded(['/usr/bin/hdiutil', 'verify', image], root, reports, 'verify')
            manifest = dict(source_build=receipt, source_bundle_sha256=source_identity,
                            packaged_bundle_sha256=packaged_identity,
                            packaged_executable_sha256=sha256(binaries[0]),
                            dmg_sha256=sha256(image), version=version, architecture=platform.machine(),
                            sizes=sizes, memory_reports=str(reports),
                            bundled_libraries=sorted(path.name for path in (app / 'Contents/Frameworks').glob('*')),
                            signing='ad-hoc; no Developer ID certificate or Apple notarization')
            manifest_path = Path(image_directory) / 'manifest.json'
            manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
            os.replace(image, output)
            os.replace(manifest_path, output.with_suffix('.dmg.json'))
    print('Created ' + str(output), flush=True)
    return output


def main():
    parser = argparse.ArgumentParser(prog='deploy.vsh', description=__doc__)
    parser.add_argument('--output', type=Path, help='DMG path (default: Build/deploy/Vox-VERSION-ARCH.dmg)')
    parser.add_argument('--package-only', action='store_true',
                        help="reuse the release checkout's completed build (with --no-publish: "
                        "the canonical Build/v build)")
    parser.add_argument('--version', help='release this version (for example 0.2.0) instead of '
                        'the next patch version')
    parser.add_argument('--no-publish', action='store_true',
                        help='only build and package; leave the version, GitHub and the website alone')
    parser.add_argument('--website-only', action='store_true',
                        help='point vox-browser.org/version at the released version in Info.plist')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('DMG deployment requires macOS')
    if args.website_only and (args.no_publish or args.package_only or args.output or args.version):
        parser.error('--website-only takes no other options')
    if args.no_publish and args.version:
        parser.error('--version publishes a release; omit --no-publish')
    try:
        if args.website_only:
            release_macos.publish_website_only(ROOT)
        elif args.no_publish:
            deploy(output=args.output, package_only=args.package_only)
        else:
            release_macos.release(ROOT, deploy, args.output, args.package_only, args.version)
    except subprocess.CalledProcessError as error:
        if error.returncode == 75:
            print('Deploy: the shared production build is busy; run again after it finishes, '
                  'or use --package-only for an existing matching build.', file=sys.stderr)
        else:
            print('Deploy: command failed with exit ' + str(error.returncode), file=sys.stderr)
        return error.returncode
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print('Deploy: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
