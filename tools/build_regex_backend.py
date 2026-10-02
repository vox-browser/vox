#!/usr/bin/env python3
"""Build the byte-exact pinned LibRegex Rust dependency owned by this repository."""
import argparse
import hashlib
import json
import os
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
    version = subprocess.check_output([compiler, '--version'], text=True).strip()
    digest.update(version.encode())
    fingerprint = digest.hexdigest()
    output = repo / 'Build/libregex'
    output.mkdir(parents=True, exist_ok=True)
    archive = output / 'libregex_native.a'
    stamp = output / 'source.sha256'
    if archive.exists() and stamp.exists() and stamp.read_text().strip() == fingerprint:
        return
    unicode = output / 'libunicode_rust.rlib'
    common = [compiler, '--edition=2024', '-O']
    subprocess.run(common + ['--crate-name', 'libunicode_rust', '--crate-type', 'rlib',
                            str(source / 'unicode.rs'), '-o', str(unicode)], check=True)
    environment = dict(os.environ, CARGO_PKG_NAME='libregex_rust')
    subprocess.run(common + ['--crate-name', 'libregex_rust', '--crate-type', 'staticlib',
                            '--extern', f'libunicode_rust={unicode}',
                            str(source / 'Libraries/LibRegex/Rust/src/lib.rs'), '-o', str(archive)],
                   env=environment, check=True)
    stamp.write_text(fingerprint + '\n')
    print(f'Built pinned LibRegex backend with {version}')


if __name__ == '__main__':
    main()
