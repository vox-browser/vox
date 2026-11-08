#!/usr/bin/env python3
"""Check exact GG shape/packed-view reuse against the pinned native GPU backend."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from browser_bundle_lease import publication_lease
ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--backend', type=Path, default=ROOT / 'Build/v/Vox.app/Contents/MacOS/libVoxGraphite.dylib')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = ROOT / 'tools/native_gg_shape_cache_test.cpp'
    paths = [source, Path(__file__).resolve(), args.backend.resolve(), *sorted((ROOT / 'native/include').glob('*.h'))]
    def hashes():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    records = []
    with publication_lease(ROOT, shared=True):
        before = hashes()
        for mode in ['optimized', 'sanitized']:
            binary = output / mode
            flags = ['-O2'] if mode == 'optimized' else ['-O1', '-g', '-fsanitize=address,undefined']
            commands = [('compile', ['clang++', '-std=c++20', *flags, str(source), '-o', str(binary)], 12),
                        ('runtime', [str(binary), str(args.backend.resolve())], 3)]
            for phase, command, limit in commands:
                name = mode + '-' + phase
                guarded = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'), '--lock', str(output / (name + '.lock')), '--report', str(output / (name + '-guard.json')), '--limit-gib', str(limit), '--', *command]
                assert before == hashes(), 'Inputs changed before check'
                with (output / (name + '.log')).open('w') as log:
                    result = subprocess.run(guarded, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0', UBSAN_OPTIONS='halt_on_error=1'))
                records.append(dict(name=name, command=guarded, exit=result.returncode))
                (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
                result.check_returncode()
                assert before == hashes(), 'Inputs changed during check'
        (output / 'receipt.json').write_text(json.dumps(dict(passed=True, inputs=before, commands=records), indent=2) + '\n')
    print('Exact GG shape-cache checks passed in optimized and ASan/UBSan modes')

if __name__ == '__main__':
    main()
