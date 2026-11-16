#!/usr/bin/env python3
"""Build a pinned Linux release in a native Debian CI container, then test its DEB."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

V_REVISION = 'c4dee97041851a8b71c0024aa90163a2b6f2134b'
VC_REVISION = '0adf6994fb702bb84c6de192317c375efa4b449d'
UI2_REVISION = 'f18e784d96a27991974ef8cfdd25b33830a9f067'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(arguments, **kwargs):
    print('+', ' '.join(map(str, arguments)), flush=True)
    return subprocess.run(list(map(str, arguments)), check=True, **kwargs)


def checkout(repository, revision, target):
    target.mkdir(parents=True)
    run(['git', 'init', '-q', target])
    run(['git', '-C', target, 'fetch', '--depth=1', repository, revision])
    run(['git', '-C', target, 'checkout', '--detach', 'FETCH_HEAD'])


def portable_clip(source):
    signature = 'pub fn document_image_clip_requires_msaa('
    if source.count(signature) != 1:
        raise RuntimeError('Expected exactly one document clip helper')
    start = source.index(signature)
    end = source.index('\n}', start) + 2
    return 'module canvas\n\n' + source[start:end] + '\n'


def verify_package_manifest(manifest, expected_commit, architecture):
    mode = manifest['source_build'].get('c_compile', {})
    if (manifest['source_build'].get('exit') != 0
            or mode != dict(backend='c', mode='single', requested='single', v_prod=True)
            or manifest.get('architecture') != architecture):
        raise RuntimeError('Release must contain a native, single-unit C -prod build')
    for key in ('inputs', 'verified_inputs'):
        state = manifest['source_build'].get(key, {})
        if state.get('head') != expected_commit or state.get('dirty') is not False:
            raise RuntimeError('Release build does not match the clean requested commit')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--toolchain', type=Path, required=True)
    parser.add_argument('--expected-commit', required=True)
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.expected_commit):
        parser.error('--expected-commit must be a full Git commit ID')
    source, toolchain = args.source.resolve(), args.toolchain.resolve()
    if subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip() != 'amd64':
        raise RuntimeError('This release job requires a native AMD64 Debian environment')
    run(['git', 'config', '--global', '--add', 'safe.directory', source])
    head = subprocess.check_output(['git', '-C', source, 'rev-parse', 'HEAD'], text=True).strip()
    if head != args.expected_commit:
        raise RuntimeError('Checkout does not match the requested release commit')
    run(['git', '-C', source, 'checkout', '-B', 'master'])
    if subprocess.check_output(['git', '-C', source, 'status', '--porcelain']).strip():
        raise RuntimeError('The release checkout is not clean')
    output = source / 'Build/deploy'
    output.mkdir(parents=True, exist_ok=True)
    reports = output / 'validation'
    reports.mkdir()

    def guarded(command, name, limit=12, environment=None):
        run([sys.executable, source / 'tools/run_memory_bounded.py',
             '--lock', reports / (name + '.lock'), '--report', reports / (name + '.json'),
             '--limit-gib', limit, '--timeout', '2700', '--', *command],
            cwd=source, env=environment)

    compiler = toolchain / 'v'
    checkout('https://github.com/vlang/v.git', V_REVISION, compiler)
    checkout('https://github.com/vlang/vc.git', VC_REVISION, compiler / 'vc')
    checkout('https://github.com/vlang/ui2.git', UI2_REVISION, toolchain / 'ui2')
    environment = dict(os.environ, VFLAGS='', V_MACOS_V3_NO_FALLBACK='1',
                       UI2_SOURCE_DIR=str(toolchain / 'ui2'))
    # Bootstrap the current frontend directly; make's legacy fallback currently
    # fails while compiling the newer compiler's typed AST array operations.
    guarded(['cc', '-std=gnu11', '-w', '-o', compiler / 'v-seed', compiler / 'vc/v.c',
             '-lm', '-lpthread'], 'compiler-seed', environment=environment)
    environment.update(VOX_MATCH_SCOPE_CC='clang',
                       VOX_MATCH_SCOPE_RECEIPT=str(compiler / 'patched.txt'))
    scope_adapter = Path(__file__).with_name('v_match_scope_cc.py')
    command = [compiler / 'v-seed', '-b', 'c', '-memory-limit', '10G', '-nocache',
               '-d', 'dynamic_boehm', '-cc', scope_adapter,
               '-prod', '-o', compiler / 'v']
    for backend in ('fastc', 'x64', 'amd64', 'arm64', 'ssa', 'eval', 'wasm'):
        command += ['-d', 'skip_' + backend]
    guarded([*command, compiler / 'cmd/v'], 'compiler', environment=environment)
    if not (compiler / 'patched.txt').is_file():
        raise RuntimeError('The checked late-match scope adapter was not applied')
    wrapper = compiler / 'v-linux'
    wrapper.write_text('#!/bin/sh\nexec "' + str(compiler / 'v') + '" -d dynamic_boehm "$@"\n')
    wrapper.chmod(0o755)
    (compiler / 'manifest.json').write_text(json.dumps(dict(
        sha256=digest(wrapper), scoped_compiler_sha256=digest(compiler / 'v'),
        bootstrap=str(compiler / 'v-seed'), vlib=str(compiler / 'vlib'))) + '\n')
    # Old release tags stage the Linux GG compatibility files after UI2, which
    # removes its portable clip helper. Materialize only that exact release
    # function in the dependency overlay, without the Metal upload methods.
    clip_source = source / 'tools/ui2/gg_document_clip.v'
    clip = (clip_source.read_text() if clip_source.exists() else portable_clip(
        (source / 'tools/ui2/gg_document_image.v').read_text()))
    (compiler / 'vlib/gg/canvas/vox_document_clip.v').write_text(clip)
    environment.update(V_BIN=str(wrapper))
    for key in ('VOX_MATCH_SCOPE_CC', 'VOX_MATCH_SCOPE_RECEIPT'):
        environment.pop(key, None)
    run([sys.executable, source / 'tools/deploy_macos.py', '--no-publish'], cwd=source, env=environment)
    version = plistlib.loads((source / 'packaging/Info.plist').read_bytes())['CFBundleShortVersionString']
    package = output / ('Vox-%s-amd64.deb' % version)
    manifest = json.loads(package.with_suffix('.deb.json').read_text())
    verify_package_manifest(manifest, args.expected_commit, 'amd64')
    if digest(package) != manifest['deb_sha256']:
        raise RuntimeError('Package does not match its recorded checksum')
    extracted = reports / 'package'
    guarded(['dpkg-deb', '--extract', package, extracted], 'extract')
    guarded([sys.executable, source / 'tools/test_linux_browser.py', extracted / 'usr/bin/vox',
             '--output', reports / 'browser'], 'browser', 3, environment)
    if digest(package) != manifest['deb_sha256']:
        raise RuntimeError('Package changed during validation')
    (output / 'amd64-toolchain.json').write_text(json.dumps(dict(
        source_commit=args.expected_commit, v_revision=V_REVISION, vc_revision=VC_REVISION,
        ui2_revision=UI2_REVISION, compiler_sha256=digest(compiler / 'v'),
        match_scope_adapter_sha256=digest(scope_adapter),
        portable_clip_sha256=hashlib.sha256(clip.encode()).hexdigest()), indent=2) + '\n')
    print('VERIFIED AMD64 DEBIAN PACKAGE:', package, flush=True)


if __name__ == '__main__':
    main()
