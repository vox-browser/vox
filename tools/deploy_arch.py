#!/usr/bin/env python3
"""Build and smoke a native Arch Linux package from the production executable."""
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import tempfile

from browser_bundle_lease import publication_lease
from deploy_linux import ROOT, capture, guarded, run, verified_build
from rebuild_browser import production_environment
from release_macos import packaging_version, sha256


def dependencies(root, binaries):
    """Resolve direct ELF dependencies to packages in the build host's database."""
    packages = {'ca-certificates', 'ttf-dejavu'}
    bundled = {binary.name for binary in binaries}
    for binary in binaries:
        needed = re.findall(r'\(NEEDED\).*\[([^\]]+)\]',
                            capture(['readelf', '--dynamic', binary], root))
        linked = capture(['ldd', binary], root)
        for library in needed:
            if library in bundled:
                continue
            match = re.search(r'^\s*' + re.escape(library) + r'\s+=>\s+(/\S+)', linked, re.M)
            if not match:
                # ldd prints the ELF interpreter as an absolute path without =>.
                match = re.search(r'^\s*(/\S*/' + re.escape(library) + r')\s+\(', linked, re.M)
            if not match:
                raise RuntimeError('Unresolved runtime library: ' + library)
            owner = capture(['pacman', '-Qqo', Path(match[1]).resolve()], root)
            if not re.fullmatch(r'[a-zA-Z0-9@._+-]+', owner):
                raise RuntimeError('Invalid runtime package owner: ' + owner)
            packages.add(owner)
    if not any(package not in ('ca-certificates', 'ttf-dejavu') for package in packages):
        raise RuntimeError('No ELF runtime dependencies were found')
    return sorted(packages)


def pkgbuild(version, architecture, runtime_dependencies):
    return ("pkgname=vox\npkgver=%s\npkgrel=1\npkgdesc='Vox web browser'\n"
            "arch=(%s)\nurl='https://vox-browser.org'\nlicense=('GPL-3.0-or-later')\n"
            "depends=(%s)\noptions=('!strip' '!debug')\n"
            'package() {\n    cp -a "$startdir/payload/." "$pkgdir/"\n}\n'
            % (shlex.quote(version), shlex.quote(architecture),
               ' '.join(map(shlex.quote, runtime_dependencies))))


def deploy(root=ROOT, output=None, package_only=False, build_environment=None):
    version = packaging_version(root)
    if os.geteuid() == 0:
        raise RuntimeError('Run Arch deployment as a regular user; makepkg refuses root')
    for tool in ('makepkg', 'pacman', 'bsdtar', 'readelf', 'ldd', 'strip', 'zstd'):
        if not shutil.which(tool):
            raise RuntimeError('Missing %s; install base-devel, libarchive and zstd on Arch Linux' % tool)
    architecture = platform.machine()
    if architecture != 'x86_64':
        raise RuntimeError('Arch Linux releases currently require an x86_64 build host')
    source = root / 'Build/linux/vox'
    filename = 'vox-%s-1-%s.pkg.tar.zst' % (version, architecture)
    output = Path(output or root / 'Build/deploy' / filename).resolve()
    if (not output.name.endswith('.pkg.tar.zst')
            or output.is_relative_to((root / 'Build/linux').resolve())):
        raise RuntimeError('Choose a .pkg.tar.zst output path outside the canonical Linux build')
    environment = production_environment(os.environ if build_environment is None else build_environment)
    if not package_only:
        run(['sh', root / 'tools/run_v_tool.sh', 'rebuild_browser', '--build',
             '--backend', 'c', '--prod', '--no-parallel-cc'], root, env=environment)

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.vox-arch-', dir=output.parent) as directory:
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
        runtime_dependencies = dependencies(root, binaries)
        installed_dependencies = capture(['pacman', '-Q', *runtime_dependencies], root)
        (payload / 'usr/bin').mkdir(parents=True)
        (payload / 'usr/bin/vox').symlink_to('../lib/vox/vox')
        for relative, source_path in (
                ('usr/share/applications/vox.desktop', root / 'packaging/vox.desktop'),
                ('usr/share/icons/hicolor/1024x1024/apps/vox.png', root / 'packaging/Vox.png'),
                ('usr/share/licenses/vox/LICENSE', root / 'LICENSE'),
                ('usr/share/doc/vox/THIRD_PARTY_NOTICES.md', root / 'THIRD_PARTY_NOTICES.md')):
            path = payload / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source_path, path)
            path.chmod(0o644)
        (work / 'PKGBUILD').write_text(pkgbuild(version, architecture, runtime_dependencies))
        config = work / 'makepkg.conf'
        config.write_text("source /etc/makepkg.conf\nPKGEXT='.pkg.tar.zst'\n"
                          "COMPRESSZST=(zstd -c -T1 -)\n")
        environment.update(PKGDEST=str(work), BUILDDIR=str(work / 'build'),
                           SRCDEST=str(work), SRCPKGDEST=str(work), LOGDEST=str(work),
                           PKGEXT='.pkg.tar.zst', CARCH=architecture, LC_ALL='C')
        reports = {}
        reports['create'] = guarded(['makepkg', '--dir', work, '--noconfirm', '--nocolor', '--nosign',
                                     '--config', config], root, work, 'create', env=environment)
        image = work / filename
        identity = capture(['pacman', '-Qp', image], root)
        if identity != 'vox %s-1' % version:
            raise RuntimeError('The Arch package has the wrong name or version: ' + identity)
        extracted = work / 'extracted'
        extracted.mkdir()
        reports['extract'] = guarded(['bsdtar', '-xpf', image, '-C', extracted], root, work, 'extract')
        for binary in binaries:
            if sha256(extracted / 'usr/lib/vox' / binary.name) != sha256(binary):
                raise RuntimeError('The Arch payload does not match the stripped binaries')
        environment.update(VOX_PROFILE_DIR=str(work / 'smoke-profile'), VOX_TEST_WINDOW='1')
        reports['smoke'] = guarded([extracted / 'usr/bin/vox', '--headless-smoke'],
                                   root, work, 'smoke', 3, env=environment)
        manifest = dict(version=version, package_release=1, architecture=architecture,
                        source_build=receipt, source_binaries_sha256=identities, sizes=sizes,
                        packaged_executable_sha256=sha256(binaries[0]),
                        package_sha256=sha256(image), dependencies=runtime_dependencies,
                        installed_dependencies=installed_dependencies, memory_reports=reports)
        manifest_path = work / 'manifest.json'
        manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
        os.replace(image, output)
        os.replace(manifest_path, output.with_name(output.name + '.json'))
    print('Created ' + str(output), flush=True)
    return output
