#!/usr/bin/env python3
"""Compile GG's real canvas path, then run its transfer checks with a 3 GiB guard.

Run this driver through run_memory_bounded.py with its default compile budget.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

from prepare_gg_metal import prepare_sokol_metal
from prepare_http_compat import compiler_vlib
from prepare_prealloc_runtime import prepare
from prepare_ui2 import prepare_gg_gradient


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--prod', action='store_true', help='Exercise literal V -prod, as automatic browser builds do')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    compiler = args.compiler.resolve()
    vlib = compiler_vlib(str(compiler), output)
    modules = output / 'modules'
    modules.mkdir(exist_ok=True)
    prepare_gg_gradient(modules, vlib)
    staged = prepare_sokol_metal(modules, vlib)
    runtime = prepare(compiler)
    paths = [compiler, runtime / 'compiler/v', Path(__file__),
             repo / 'tools/gg_migration/metal_transfer_check.v',
             repo / 'native/include/native_gg_metal_transfer.h',
             repo / 'tools/prepare_gg_metal.py', repo / 'tools/prepare_ui2.py',
             repo / 'tools/prepare_prealloc_runtime.py', repo / 'tools/prepare_http_compat.py',
             repo / 'tools/run_memory_bounded.py', staged / 'sokol_gfx.h',
             staged / 'manifest.json', runtime / 'manifest.json']
    for directory in [vlib / 'gg/canvas', vlib / 'sokol',
                      vlib.parent / 'thirdparty/sokol', runtime / 'builtin', modules]:
        paths.extend(p for p in directory.rglob('*') if p.is_file())
    def hashes():
        return {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    pins = hashes()
    (output / 'inputs.json').write_text(json.dumps(pins, indent=2) + '\n')
    records = []
    environment = dict(os.environ, V_MACOS_V3_NO_FALLBACK='1')
    environment.pop('VFLAGS', None)
    environment.pop('VEXE', None)
    try:
        for mode in ['none', 'prealloc']:
            selected = compiler if mode == 'none' else runtime / 'compiler/v'
            extra = [] if mode == 'none' else ['-prealloc']
            if args.prod:
                extra.append('-prod')
            binary = output / mode
            command = [str(selected), '-b', 'c', '-cc', 'clang', '-memory-limit', '10G',
                       '-enable-globals', '-gc', 'none', *extra,
                       '-path', f'{repo}|{modules}|{runtime}|@vlib|@vmodules',
                       '-o', str(binary), str(repo / 'tools/gg_migration/metal_transfer_check.v')]
            check = ['python3', str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', '3',
                     '--lock', str(output / (mode + '.lock')), '--report', str(output / (mode + '-guard.json')),
                     '--', str(binary)]
            for label, step in [('compile', command), ('run', check)]:
                assert hashes() == pins, 'changed input before ' + mode
                env = dict(environment)
                if label == 'run':
                    env['VOX_GG_READBACK_DIAGNOSTICS'] = '1'
                result = subprocess.run(step, cwd=repo, env=env, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                records.append({'command': step, 'exit': result.returncode, 'output': result.stdout})
                (output / (mode + '-' + label + '.log')).write_text(result.stdout)
                assert hashes() == pins, 'changed input during ' + mode
                if result.returncode:
                    print(result.stdout, flush=True)
                    raise SystemExit(result.returncode)
                if label == 'run':
                    assert result.stdout.count('VOX_GG_READBACK joined=1 ') == 64, 'joined path did not execute'
                    assert 'VOX_GG_READBACK joined=0 ' not in result.stdout
                print(mode, label, 'passed', flush=True)
    finally:
        (output / 'results.json').write_text(json.dumps(records, indent=2) + '\n')


if __name__ == '__main__':
    main()
