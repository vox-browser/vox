#!/usr/bin/env python3
"""Check scroll pipeline preparation, idle reuse and pixels under bounded RSS."""
import argparse
import hashlib
import json
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    skia = ROOT / 'Build/deps/skia-brave/source'
    source = ROOT / 'tools/native_scroll_pipeline_warmup_test.mm'
    paths = [source, ROOT / 'native_graphite_darwin.mm', *ROOT.glob('native/include/native*.h'),
             skia / 'out/Release/libskia.a', skia / 'out/Release/libskcms.a']
    def hashes():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    before = hashes()
    records = []
    def run(name, command, limit):
        guarded = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
            '--lock', str(output / (name + '.lock')), '--report', str(output / (name + '-guard.json')),
            '--limit-gib', str(limit), '--', *command]
        with (output / (name + '.log')).open('w') as log:
            result = subprocess.run(guarded, stdout=log, stderr=subprocess.STDOUT,
                env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0', UBSAN_OPTIONS='halt_on_error=1'))
        records.append(dict(name=name, command=guarded, exit=result.returncode))
        (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
        result.check_returncode()
    for mode in ['optimized', 'sanitized']:
        binary = output / mode
        flags = ['-O2'] if mode == 'optimized' else ['-O1', '-g', '-fsanitize=address,undefined']
        command = ['clang++', '-std=c++20', *flags, '-DSK_GRAPHITE',
            '-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER', '-I' + str(skia), str(source),
            '-L' + str(skia / 'out/Release'), '-lskia', '-lskcms']
        for framework in ['Foundation', 'Metal', 'CoreGraphics', 'ImageIO', 'IOSurface']:
            command += ['-framework', framework]
        run(mode + '-compile', [*command, '-o', str(binary)], 12)
        if before != hashes():
            raise RuntimeError('Native input changed during compilation')
        run(mode + '-runtime', [str(binary)], 3)
        print((output / (mode + '-runtime.log')).read_text().splitlines()[0], flush=True)
    if before != hashes():
        raise RuntimeError('Native input changed during checks')
    (output / 'receipt.json').write_text(json.dumps(dict(passed=True, sources=before,
                                                       commands=records), indent=2) + '\n')


if __name__ == '__main__':
    main()
