#!/usr/bin/env python3
"""Prepare native bridges and print a shell environment for subsequent `v .` builds."""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def shell_environment(values, shell):
    if shell == 'powershell':
        return '\n'.join("$env:" + key + " = '" + value.replace("'", "''") + "'"
                         for key, value in values.items())
    return '\n'.join('export ' + key + '=' + shlex.quote(value) for key, value in values.items())


def compiler_shell_environment(values, shell):
    # V_BIN may name a different compiler from `v` on PATH. Keep adapter
    # preparation and the subsequent plain command on that same executable.
    command = ('function global:v { & $env:V_BIN @args }' if shell == 'powershell'
               else 'v() { "$V_BIN" "$@"; }')
    return shell_environment(values, shell) + '\n' + command


def build_flags(root, modules, platform):
    # Use the checked C backend: FastC can compile the browser but still
    # miscompiles live DOM queries. v.mod's development default is opt-in here.
    flags = ['-b', 'c', '-enable-globals', '-memory-limit', '10G',
             '-no-parallel', '-cc', 'gcc' if platform == 'win32' else 'clang',
             '-path', '|'.join([str(root), *map(str, modules), '@vmodules', '@vlib'])]
    if platform.startswith('linux'):
        flags += ['-d', 'dynamic_boehm', '-d', 'use_openssl',
                  '-exclude', '@vlib/time/zoneinfo.native.v', '-cflags', '-D_GNU_SOURCE=1',
                  '-o', str(root / 'Build/linux/vox')]
    elif platform == 'win32':
        flags += ['-gc', 'none', '-d', 'ui2_custom_rendering', '-d', 'sokol_d3d11',
                  '-prod', '-no-prod-options']
    return shlex.join(flags)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', default=os.environ.get('V_BIN') or shutil.which('v'))
    parser.add_argument('--javascriptcore-dll', type=Path)
    parser.add_argument('--shell', choices=['sh', 'powershell'],
                        default='powershell' if os.name == 'nt' else 'sh')
    args = parser.parse_args()
    if not args.compiler:
        parser.error('Install current V and put v on PATH, or set V_BIN')
    compiler = Path(shutil.which(args.compiler) or args.compiler).resolve()
    if not compiler.is_file():
        parser.error('V compiler does not exist: ' + str(compiler))
    environment = dict(os.environ)
    environment.pop('VFLAGS', None)

    def prepare(name, *arguments):
        command = [sys.executable, str(ROOT / 'tools' / name), *map(str, arguments)]
        result = subprocess.run(command, cwd=ROOT, env=environment, check=True,
                                stdout=subprocess.PIPE, text=True)
        lines = result.stdout.strip().splitlines()
        for line in lines[:-1]:
            print(line, file=sys.stderr)
        return lines[-1] if lines else ''

    if sys.platform.startswith('linux'):
        compiler = Path(prepare('prepare_v_match_scope.py', compiler))
    if sys.platform == 'darwin':
        prepare('build_harfbuzz.py')
    if sys.platform.startswith('linux') or os.name == 'nt':
        prepare('build_linux_native.py', '--os', 'windows' if os.name == 'nt' else 'linux')
    if os.name == 'nt':
        if args.javascriptcore_dll is None:
            parser.error('Windows setup requires --javascriptcore-dll PATH')
        prepare('prepare_windows_jsc.py', args.javascriptcore_dll.resolve())
    modules = [prepare('prepare_ui2.py', compiler), prepare('prepare_http_compat.py', compiler)]
    if sys.platform.startswith('linux'):
        # UI2 and the platform adapters intentionally share a module tree.
        modules.insert(0, prepare('prepare_linux_modules.py', compiler))
    print(compiler_shell_environment({'V_BIN': str(compiler),
                             'VFLAGS': build_flags(ROOT, modules, sys.platform)}, args.shell))


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        # An empty failed command substitution makes `eval` succeed. Emit a
        # failing shell statement so a setup failure cannot select old flags.
        shell = 'powershell' if os.name == 'nt' else 'sh'
        if '--shell' in sys.argv:
            shell = sys.argv[sys.argv.index('--shell') + 1]
        print("throw 'Vox build setup failed'" if shell == 'powershell' else 'false')
        raise SystemExit(1)

