#!/usr/bin/env python3
"""Build the pinned macOS OpenType/CoreText shaper without Graphite2."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

VERSION = '15.1.0'
SHA256 = '5c057929413b8664592fea67edea5c2c47b4ffb0bf5f4accb5164bc6acc69d94'
URL = f'https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/refs/tags/{VERSION}'
ROOT = Path(__file__).resolve().parents[1]
OPTIONS = ['-DBUILD_SHARED_LIBS=OFF', '-DCMAKE_BUILD_TYPE=Release',
           '-DCMAKE_POSITION_INDEPENDENT_CODE=ON', '-DHB_HAVE_CORETEXT=ON',
           *['-DHB_HAVE_' + name + '=OFF' for name in
             ['GRAPHITE2', 'FREETYPE', 'GLIB', 'ICU', 'CAIRO', 'GOBJECT', 'INTROSPECTION']],
           *['-DHB_BUILD_' + name + '=OFF' for name in
             ['UTILS', 'SUBSET', 'RASTER', 'VECTOR', 'GPU', 'GPU_DEMO']]]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract_sources(archive, destination):
    with tarfile.open(archive) as bundle:
        for member in bundle:
            path = Path(member.name)
            if path.is_absolute() or '..' in path.parts or path.parts[0] != f'harfbuzz-{VERSION}':
                raise RuntimeError('Invalid HarfBuzz archive path')
            # Only build inputs; omit upstream's agent-instructions symlink.
            if member.isdir():
                continue
            if member.issym() and member.name == f'harfbuzz-{VERSION}/CLAUDE.md':
                continue
            if not member.isfile():
                raise RuntimeError('Unsupported HarfBuzz archive entry')
            target = destination / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(bundle.extractfile(member).read())


def cached(root, identity):
    receipt = root / 'build.json'
    if not receipt.is_file():
        return False
    data = json.loads(receipt.read_text())
    outputs = data.get('outputs', {})
    return (data.get('inputs') == identity and 'lib/libharfbuzz.a' in outputs
            and 'include/harfbuzz/hb.h' in outputs
            and all((root / name).is_file() and digest(root / name) == sha
                    for name, sha in outputs.items()))


def check_executable(executable):
    libraries = subprocess.check_output(['otool', '-L', str(executable)], text=True)
    symbols = subprocess.check_output(['nm', '-u', str(executable)], text=True)
    if 'graphite2' in libraries.lower() or re.search(r'\b_?gr_\w+', symbols):
        raise RuntimeError('Browser still depends on Graphite2')


def build():
    if sys.platform != 'darwin':
        raise RuntimeError('This isolated HarfBuzz build is for macOS')
    root = ROOT / f'Build/deps/harfbuzz-{VERSION}'
    root.mkdir(parents=True, exist_ok=True)
    with (root / 'build.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        cmake = shutil.which('cmake')
        compiler = shutil.which('clang++')
        if not cmake or not compiler:
            raise RuntimeError('HarfBuzz preparation requires CMake and Clang')
        identity = dict(version=VERSION, url=URL, sha256=SHA256, options=OPTIONS,
                        builder=digest(Path(__file__)), architecture=platform.machine(),
                        deployment_target=os.environ.get('MACOSX_DEPLOYMENT_TARGET', '15.0'),
                        compiler=subprocess.check_output([compiler, '--version'], text=True),
                        cmake=subprocess.check_output([cmake, '--version'], text=True))
        if cached(root, identity):
            return root
        archive = root / 'source.tar.gz'
        if not archive.is_file():
            temporary = root / 'source.download'
            urllib.request.urlretrieve(URL, temporary)
            if digest(temporary) != SHA256:
                raise RuntimeError('HarfBuzz archive checksum mismatch')
            temporary.replace(archive)
        if digest(archive) != SHA256:
            raise RuntimeError('HarfBuzz archive checksum mismatch')
        with tempfile.TemporaryDirectory(prefix='compile-', dir=root) as temporary:
            work = Path(temporary)
            extract_sources(archive, work)
            output = work / 'build'
            command = [cmake, '-S', str(work / f'harfbuzz-{VERSION}'), '-B', str(output),
                       f'-DCMAKE_CXX_COMPILER={compiler}',
                       '-DCMAKE_OSX_DEPLOYMENT_TARGET=' + identity['deployment_target'],
                       '-DCMAKE_INSTALL_PREFIX=' + str(root), *OPTIONS]
            for args in [command, [cmake, '--build', str(output), '--parallel', '2'],
                         [cmake, '--install', str(output)]]:
                subprocess.run(args, check=True, stdout=sys.stderr, stderr=sys.stderr)
            shutil.copyfile(work / f'harfbuzz-{VERSION}/COPYING', root / 'LICENSE')
        outputs = [root / 'lib/libharfbuzz.a', root / 'LICENSE',
                   *sorted((root / 'include/harfbuzz').glob('*.h'))]
        receipt = dict(inputs=identity, configure_command=command,
                       outputs={str(p.relative_to(root)): digest(p) for p in outputs})
        (root / 'build.json').write_text(json.dumps(receipt, indent=2) + '\n')
        return root


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-executable', type=Path)
    args = parser.parse_args()
    if args.check_executable:
        check_executable(args.check_executable)
        print('No Graphite2 library or symbol dependency')
    else:
        print(build())
