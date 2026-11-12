#!/usr/bin/env python3
"""Build Vox for Windows x86-64 with MinGW and installed native dependencies.

On macOS/Linux, run this command through tools/run_memory_bounded.py.
See docs/WINDOWS.md for the dependency setup and runtime limitations.
"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--javascriptcore-dll', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--deps-root', type=Path,
                        help='cross-compilation sysroot containing mingw64/')
    parser.add_argument('--console', action='store_true',
                        help='keep a console entry point for startup diagnostics')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    environment = dict(os.environ, V_MACOS_V3_NO_FALLBACK='1')
    prefix = '' if os.name == 'nt' else 'x86_64-w64-mingw32-'
    for variable, command in [('CC', 'gcc'), ('CXX', 'g++'), ('AR', 'ar'),
                              ('OBJDUMP', 'objdump'), ('DLLTOOL', 'dlltool')]:
        environment.setdefault(variable, prefix + command)
    if args.deps_root:
        root = args.deps_root.resolve()
        environment['PKG_CONFIG_LIBDIR'] = str(root / 'mingw64/lib/pkgconfig')
        environment['PKG_CONFIG_SYSROOT_DIR'] = str(root)
        environment.pop('PKG_CONFIG_PATH', None)
    compiler = environment.get('V_BIN') or shutil.which('v')
    if not compiler:
        raise SystemExit('Set V_BIN or put the current V compiler on PATH')
    compiler = str(Path(compiler).resolve())

    def run(command):
        subprocess.run([str(part) for part in command], cwd=repo,
                       env=environment, check=True)

    run([sys.executable, repo / 'tools/prepare_windows_jsc.py',
         args.javascriptcore_dll.resolve()])
    run([sys.executable, repo / 'tools/build_linux_native.py', '--os', 'windows'])
    modules = subprocess.check_output(
        [sys.executable, str(repo / 'tools/prepare_ui2.py'), compiler],
        cwd=repo, env=environment, text=True).strip()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Third-party object caches do not fingerprint every transitive header.
    # Keep target C runtime objects independent of host builds and old sysroots.
    with tempfile.TemporaryDirectory(prefix='vox-windows-compile-') as scratch:
        environment['VTMP'] = scratch
        # Production embedding is required when the executable leaves this
        # checkout. Keep the C optimization level unchanged for this build path.
        flags = ['-b', 'c', '-prod', '-no-prod-options']
        if args.console:
            flags += ['-subsystem', 'console']
        run([compiler, '-memory-limit', '10G', *flags, '-enable-globals', '-gc', 'none',
             '-os', 'windows', '-arch', 'amd64', '-cc', environment['CC'],
             '-d', 'ui2_custom_rendering', '-d', 'sokol_d3d11',
             '-path', f'{repo}|{modules}|@vmodules|@vlib', '-o', output, '.'])
    if output.read_bytes()[:2] != b'MZ':
        raise SystemExit('Compiler did not produce a Windows executable')
    print(f'Built Windows Vox: {output}')


if __name__ == '__main__':
    main()
