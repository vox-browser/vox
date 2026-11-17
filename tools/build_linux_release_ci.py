#!/usr/bin/env python3
"""Build a pinned Linux release in Debian or Arch, then test its native package."""
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


def verify_c_compiler(compiler):
    result = subprocess.run([compiler, '-Werror=implicit-function-declaration',
                            '-x', 'c', '-fsyntax-only', '-'],
        input='double vox_round_even(double x) { return __builtin_roundeven(x); }\n',
        text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError('The release C compiler must support __builtin_roundeven; '
                           'use Clang 19 with its matching LLD.\n' + result.stderr)


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


def validate_package(source, reports, package, manifest, distribution, guarded, environment,
                     installed_executable=Path('/usr/bin/vox')):
    package_digest = manifest['package_sha256' if distribution == 'arch' else 'deb_sha256']
    if digest(package) != package_digest:
        raise RuntimeError('Package does not match its recorded checksum')
    if distribution == 'arch':
        # Exercise dependency resolution and the actual installed layout in the
        # disposable build container; deployment itself needs no root privileges.
        guarded(['sudo', '-n', 'pacman', '-U', '--noconfirm', package], 'install')
        executable = installed_executable
    else:
        extracted = reports / 'package'
        guarded(['dpkg-deb', '--extract', package, extracted], 'extract')
        executable = extracted / 'usr/bin/vox'
    if digest(executable.resolve()) != manifest['packaged_executable_sha256']:
        raise RuntimeError('Installed executable does not match the package')
    guarded([sys.executable, source / 'tools/test_linux_browser.py', executable,
             '--output', reports / 'browser'], 'browser', 3, environment)
    if digest(package) != package_digest or digest(executable.resolve()) != manifest['packaged_executable_sha256']:
        raise RuntimeError('Package or installed executable changed during validation')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--toolchain', type=Path, required=True)
    parser.add_argument('--expected-commit', required=True)
    parser.add_argument('--distribution', choices=('debian', 'arch'), default='debian')
    parser.add_argument('--architecture', choices=('amd64', 'arm64'), default='amd64')
    parser.add_argument('--compiler-no-prod', action='store_true',
                        help='speed up the compiler bootstrap in an emulated VM; the browser still uses -prod')
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.expected_commit):
        parser.error('--expected-commit must be a full Git commit ID')
    source, toolchain = args.source.resolve(), args.toolchain.resolve()
    if args.distribution == 'arch' and args.architecture != 'amd64':
        parser.error('Arch releases currently require --architecture amd64')
    architecture = 'x86_64' if args.distribution == 'arch' else args.architecture
    host_architecture = subprocess.check_output(
        ['uname', '-m'] if args.distribution == 'arch' else ['dpkg', '--print-architecture'], text=True).strip()
    if host_architecture != architecture:
        raise RuntimeError('This release job requires a native %s Linux environment' % architecture)
    native_cc = os.environ.get('CC', 'clang')
    verify_c_compiler(native_cc)
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
                       CC=native_cc, UI2_SOURCE_DIR=str(toolchain / 'ui2'))
    # Bootstrap the current frontend directly; make's legacy fallback currently
    # fails while compiling the newer compiler's typed AST array operations.
    guarded([native_cc, '-std=gnu11', '-w', '-o', compiler / 'v-seed', compiler / 'vc/v.c',
             '-lm', '-lpthread'], 'compiler-seed', environment=environment)
    environment.update(VOX_MATCH_SCOPE_CC=native_cc,
                       VOX_MATCH_SCOPE_RECEIPT=str(compiler / 'patched.txt'))
    scope_adapter = Path(__file__).with_name('v_match_scope_cc.py')
    command = [compiler / 'v-seed', '-b', 'c', '-memory-limit', '10G', '-nocache',
               '-d', 'dynamic_boehm', '-cc', scope_adapter,
               '-o', compiler / 'v']
    if not args.compiler_no_prod:
        command.append('-prod')
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
    package_command = [sys.executable, source / 'tools/deploy_macos.py', '--no-publish']
    if args.distribution == 'arch':
        package_command += ['--format', 'arch']
    run(package_command, cwd=source, env=environment)
    version = plistlib.loads((source / 'packaging/Info.plist').read_bytes())['CFBundleShortVersionString']
    package = output / ('vox-%s-1-x86_64.pkg.tar.zst' % version if args.distribution == 'arch'
                        else 'Vox-%s-%s.deb' % (version, architecture))
    manifest = json.loads(package.with_name(package.name + '.json').read_text())
    verify_package_manifest(manifest, args.expected_commit, architecture)
    validate_package(source, reports, package, manifest, args.distribution, guarded, environment)
    (output / (architecture + '-toolchain.json')).write_text(json.dumps(dict(
        source_commit=args.expected_commit, v_revision=V_REVISION, vc_revision=VC_REVISION,
        ui2_revision=UI2_REVISION, compiler_sha256=digest(compiler / 'v'),
        match_scope_adapter_sha256=digest(scope_adapter),
        portable_clip_sha256=hashlib.sha256(clip.encode()).hexdigest()), indent=2) + '\n')
    print('VERIFIED %s PACKAGE:' % args.distribution.upper(), package, flush=True)


if __name__ == '__main__':
    main()
