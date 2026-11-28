#!/usr/bin/env python3
"""Build and package a stripped production Vox executable as a native Debian package."""
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

from browser_bundle_lease import publication_lease
from rebuild_browser import production_environment
from release_macos import packaging_version, sha256

ROOT = Path(__file__).resolve().parents[1]
MAINTAINER = 'Alexander Medvednikov <alexander@medvednikov.com>'


def run(command, root, **kwargs):
    command = [str(part) for part in command]
    print('+ ' + shlex.join(command), flush=True)
    return subprocess.run(command, cwd=root, check=True, **kwargs)


def capture(command, root):
    return run(command, root, capture_output=True, text=True).stdout.strip()


def verified_build(root, executable):
    receipt = json.loads((root / 'Build/linux/production-build/latest.json').read_text())
    mode = receipt.get('c_compile', {})
    if (receipt.get('exit') != 0 or mode.get('backend') != 'c'
            or mode.get('mode') != 'single' or mode.get('requested') != 'single'
            or mode.get('v_prod') is not True):
        raise RuntimeError('The completed Linux build must use --backend c --prod --no-parallel-cc')
    if sha256(executable) != receipt.get('executable_sha256'):
        raise RuntimeError('The Linux Vox executable does not match its build receipt')
    return receipt


def guarded(command, root, work, name, limit_gib=12, **kwargs):
    # Packaging an existing executable also works in a fresh native container
    # without a V compiler. Keep the same process-tree RSS guard and limits.
    run([sys.executable, root / 'tools/run_memory_bounded.py',
         '--lock', work / (name + '.lock'), '--report', work / (name + '.json'),
         '--limit-gib', str(limit_gib), '--', *command], root, **kwargs)
    return json.loads((work / (name + '.json')).read_text())


def dependencies(work, binaries):
    # dpkg-shlibdeps uses the build host's package database, including ABI version
    # requirements. Inspect optional dlopened helpers as well as the main binary.
    debian = work / 'debian'
    debian.mkdir()
    (debian / 'control').write_text(
        'Source: vox\nSection: web\nPriority: optional\nMaintainer: ' + MAINTAINER
        + '\n\nPackage: vox\nArchitecture: any\nDescription: Vox web browser\n')
    output = capture(['dpkg-shlibdeps', '-O', *['-e' + str(path) for path in binaries]], work)
    for line in output.splitlines():
        if line.startswith('shlibs:Depends=') and line.partition('=')[2].strip():
            linked = line.partition('=')[2].strip()
            plugins = (', gstreamer1.0-plugins-base, gstreamer1.0-plugins-good, gstreamer1.0-libav, glib-networking'
                       if 'libgstreamer1.0-0' in linked else '')
            return linked + ', ca-certificates, fonts-dejavu-core' + plugins
    raise RuntimeError('dpkg-shlibdeps did not produce runtime dependencies')


def deploy(root=ROOT, output=None, package_only=False, build_environment=None):
    version = packaging_version(root)
    # Check tools before starting an expensive production build.
    for tool in ('dpkg', 'dpkg-deb', 'dpkg-shlibdeps', 'strip'):
        if not shutil.which(tool):
            raise RuntimeError('Missing %s; install dpkg-dev and binutils' % tool)
    architecture = capture(['dpkg', '--print-architecture'], root)
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', architecture):
        raise RuntimeError('Invalid Debian architecture: ' + architecture)
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', version):
        raise RuntimeError('Invalid release version in Info.plist')
    source = root / 'Build/linux/vox'
    output = Path(output or root / 'Build/deploy' / ('Vox-%s-%s.deb' % (version, architecture))).resolve()
    if output.suffix.lower() != '.deb' or output.is_relative_to((root / 'Build/linux').resolve()):
        raise RuntimeError('Choose a .deb output path outside the canonical Linux build')
    environment = production_environment(os.environ if build_environment is None else build_environment)
    if not package_only:
        run(['sh', root / 'tools/run_v_tool.sh', 'rebuild_browser', '--build',
             '--backend', 'c', '--prod', '--no-parallel-cc'], root, env=environment)

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.vox-deb-', dir=output.parent) as directory:
        work = Path(directory)
        payload = work / 'payload'
        library = payload / 'usr/lib/vox'
        library.mkdir(parents=True)
        with publication_lease(root, shared=True):
            receipt = verified_build(root, source)
            sources = [source]
            helper = source.with_name('libVoxAVIF.so')
            if helper.is_file():
                sources.append(helper)
            identities = {path.name: sha256(path) for path in sources}
            for path in sources:
                shutil.copy2(path, library / path.name)
            for path in sources:
                if sha256(path) != identities[path.name] or sha256(library / path.name) != identities[path.name]:
                    raise RuntimeError('The Linux build changed while staging the release')

        binaries = [library / path.name for path in sources]
        sizes = {}
        for binary in binaries:
            before = binary.stat().st_size
            run(['strip', '--strip-unneeded', binary], root)
            binary.chmod(0o755)
            sizes[binary.name] = dict(before=before, stripped=binary.stat().st_size)
        runtime_dependencies = dependencies(work, binaries)
        (payload / 'usr/bin').mkdir(parents=True)
        (payload / 'usr/bin/vox').symlink_to('../lib/vox/vox')
        for relative, source_path in (
                ('usr/share/applications/vox.desktop', root / 'packaging/vox.desktop'),
                ('usr/share/icons/hicolor/1024x1024/apps/vox.png', root / 'packaging/Vox.png'),
                ('usr/share/doc/vox/copyright', root / 'LICENSE'),
                ('usr/share/doc/vox/THIRD_PARTY_NOTICES.md', root / 'THIRD_PARTY_NOTICES.md')):
            path = payload / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source_path, path)
            path.chmod(0o644)
        control = payload / 'DEBIAN'
        control.mkdir()
        installed_size = sum(path.stat().st_size for path in payload.rglob('*')
                             if path.is_file() and not path.is_symlink())
        (control / 'control').write_text(
            'Package: vox\nVersion: %s\nArchitecture: %s\nSection: web\nPriority: optional\n'
            'Maintainer: %s\nHomepage: https://vox-browser.org\nInstalled-Size: %s\n'
            'Depends: %s\nDescription: Vox web browser\n'
            % (version, architecture, MAINTAINER, (installed_size + 1023) // 1024, runtime_dependencies))

        image = work / 'Vox.deb'
        reports = {}
        reports['create'] = guarded(['dpkg-deb', '--root-owner-group', '--build', payload, image],
                                    root, work, 'create')
        run(['dpkg-deb', '--info', image], root)
        # Execute the final extracted package, through its installed command
        # symlink, so library placement and the packaged bytes are exercised.
        extracted = work / 'extracted'
        reports['extract'] = guarded(['dpkg-deb', '--extract', image, extracted], root, work, 'extract')
        for binary in binaries:
            if sha256(extracted / 'usr/lib/vox' / binary.name) != sha256(binary):
                raise RuntimeError('The DEB payload does not match the stripped binaries')
        environment.update(VOX_PROFILE_DIR=str(work / 'smoke-profile'), VOX_TEST_WINDOW='1')
        reports['smoke'] = guarded([extracted / 'usr/bin/vox', '--headless-smoke'],
                                   root, work, 'smoke', 3, env=environment)
        manifest = dict(version=version, architecture=architecture, source_build=receipt,
                        source_binaries_sha256=identities, sizes=sizes,
                        packaged_executable_sha256=sha256(binaries[0]),
                        deb_sha256=sha256(image), dependencies=runtime_dependencies,
                        memory_reports=reports)
        manifest_path = work / 'manifest.json'
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        os.replace(image, output)
        os.replace(manifest_path, output.with_suffix('.deb.json'))
    print('Created ' + str(output), flush=True)
    return output
