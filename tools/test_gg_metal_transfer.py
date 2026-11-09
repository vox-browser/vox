#!/usr/bin/env python3
"""Real Metal ordering/pixel checks. Run under run_memory_bounded.py (3 GiB)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess

from prepare_gg_metal import prepare_sokol_metal


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--v-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    vroot = args.v_root.resolve()
    staged = prepare_sokol_metal(output / 'modules', vroot / 'vlib')
    paths = [Path(__file__), root / 'tools/prepare_gg_metal.py', root / 'tools/prepare_ui2.py',
             root / 'native/include/native_gg_metal_transfer.h',
             root / 'tools/native_gg_metal_transfer_test.m',
             staged / 'sokol_gfx.h', staged / 'manifest.json',
             vroot / 'thirdparty/sokol/sokol_gfx.h']
    def hashes():
        return {str(p.resolve()): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    pins = hashes()
    (output / 'inputs.json').write_text(json.dumps(pins, indent=2) + '\n')
    records = []
    try:
        for mode, flags in [('optimized', ['-O2']),
                            ('sanitized', ['-O1', '-g', '-fsanitize=address,undefined'])]:
            binary = output / mode
            command = ['clang', '-std=c11', '-fobjc-arc', *flags,
                       '-DVOX_SOKOL_HEADER=' + json.dumps(str(staged / 'sokol_gfx.h')),
                       str(root / 'tools/native_gg_metal_transfer_test.m'),
                       '-framework', 'Metal', '-framework', 'Foundation', '-o', str(binary)]
            for step in [command, [str(binary)]]:
                assert hashes() == pins, 'inputs changed before ' + mode
                print(shlex.join(step), flush=True)
                result = subprocess.run(step, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                print(result.stdout, flush=True)
                records.append({'command': step, 'exit': result.returncode, 'output': result.stdout})
                assert hashes() == pins, 'inputs changed during ' + mode
                if result.returncode:
                    raise SystemExit(result.returncode)
        env = dict(os.environ, VOX_GG_READBACK_DIAGNOSTICS='1')
        step = [str(output / 'optimized')]
        result = subprocess.run(step, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        records.append({'command': step, 'env': {'VOX_GG_READBACK_DIAGNOSTICS': '1'},
                        'exit': result.returncode, 'output': result.stdout})
        assert result.returncode == 0 and hashes() == pins
        assert result.stdout.count('VOX_GG_READBACK ') == 128, 'diagnostics must be bounded'
        print('Bounded readback diagnostics: 128 markers', flush=True)
    finally:
        (output / 'results.json').write_text(json.dumps(records, indent=2) + '\n')


if __name__ == '__main__':
    main()
