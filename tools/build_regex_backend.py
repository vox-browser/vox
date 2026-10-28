#!/usr/bin/env python3
"""Build the byte-exact pinned LibRegex Rust dependency owned by this repository."""
import argparse
import fcntl
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    source = repo / 'libregex/native'
    manifest = json.loads((source / 'manifest.json').read_text())
    digest = hashlib.sha256()
    for record in manifest['files']:
        data = (source / record['path']).read_bytes()
        actual = hashlib.sha256(data).hexdigest()
        if actual != record['sha256']:
            raise SystemExit(f"Pinned source differs: {record['path']}")
        digest.update(data)
    digest.update((source / 'unicode.rs').read_bytes())
    digest.update(Path(__file__).read_bytes())
    if args.verify_only:
        print(f"Verified {len(manifest['files'])} exact sources at {manifest['upstream_commit']}")
        return
    compiler = os.environ.get('RUSTC') or shutil.which('rustc')
    if compiler is None:
        installed = sorted((Path.home() / '.rustup/toolchains').glob('stable-*/bin/rustc'))
        if len(installed) != 1:
            raise SystemExit('Set RUSTC to a Rust compiler supporting edition 2024')
        compiler = str(installed[0])
    compiler_identity = subprocess.check_output([compiler, '--version', '--verbose'], text=True).strip()
    version = compiler_identity.splitlines()[0]
    # The same compiler release can produce incompatible Linux/macOS or
    # x86-64/ARM archives in a shared checkout. Include rustc's host triple.
    digest.update(compiler_identity.encode())
    fingerprint = digest.hexdigest()
    # A Linux VM can share this checkout with its macOS host. Keep their
    # archives separate for the entire compile/link lifetime, not just while
    # rebuilding the archive under the lock.
    output = repo / 'Build/libregex' / platform.system().lower()
    output.mkdir(parents=True, exist_ok=True)
    lock = (output / 'build.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX)
    archive = output / 'libregex_native.a'
    stamp = output / 'source.sha256'
    if archive.exists() and stamp.exists() and stamp.read_text().strip() == fingerprint:
        return
    unicode = output / 'libunicode_rust.rlib'
    common = [compiler, '--edition=2024', '-O']
    subprocess.run(common + ['--crate-name', 'libunicode_rust', '--crate-type', 'rlib',
                            str(source / 'unicode.rs'), '-o', str(unicode)], check=True)
    environment = dict(os.environ, CARGO_PKG_NAME='libregex_rust')
    temporary = output / 'libregex_native.a.tmp'
    subprocess.run(common + ['--crate-name', 'libregex_rust', '--crate-type', 'staticlib',
                            '--extern', f'libunicode_rust={unicode}',
                            str(source / 'Libraries/LibRegex/Rust/src/lib.rs'), '-o', str(temporary)],
                   env=environment, check=True)
    temporary.replace(archive)
    stamp.write_text(fingerprint + '\n')
    print(f'Built pinned LibRegex backend with {version}')


if __name__ == '__main__':
    main()
