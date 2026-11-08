#!/usr/bin/env python3
"""Check Dawn idle raster release without main-thread device retirement."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    output = parser.parse_args().output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    skia = ROOT / 'Build/deps/skia-brave-dawn/source'
    dawn = ROOT / 'Build/deps/skia-brave-dawn/dawn-build'
    source = ROOT / 'tools/native_dawn_idle_retention_test.mm'
    paths = [source, Path(__file__).resolve(), ROOT / 'native_graphite_dawn_darwin.mm',
             *ROOT.glob('native*.h'), skia / 'out/Release/libskia.a',
             skia / 'out/Release/libskcms.a', dawn / 'src/dawn/native/libwebgpu_dawn.a']

    def hashes():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

    before = hashes()
    records = []

    def run(name, command, limit):
        guarded = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                   '--lock', str(output / (name + '.lock')),
                   '--report', str(output / (name + '-guard.json')),
                   '--limit-gib', str(limit), '--', *command]
        with (output / (name + '.log')).open('w') as log:
            result = subprocess.run(guarded, stdout=log, stderr=subprocess.STDOUT,
                                    env=dict(os.environ, ASAN_OPTIONS='detect_leaks=0',
                                             UBSAN_OPTIONS='halt_on_error=1',
                                             VOX_GRAPHICS_CONTEXT_DIAGNOSTICS='1'))
        records.append(dict(name=name, command=guarded, exit=result.returncode))
        (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
        result.check_returncode()

    for mode in ['optimized', 'sanitized']:
        binary = output / mode
        flags = ['-O2'] if mode == 'optimized' else ['-O1', '-g', '-fsanitize=address,undefined']
        command = ['clang++', '-std=c++20', *flags, '-DSK_RELEASE', '-UNDEBUG', '-fno-rtti',
                   '-DSK_GRAPHITE', '-DSK_DAWN', '-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER',
                   '-I' + str(ROOT), '-I' + str(skia),
                   '-I' + str(skia / 'third_party/externals/dawn/include'),
                   '-I' + str(dawn / 'gen/include'), str(source),
                   '-L' + str(skia / 'out/Release'), '-L' + str(dawn / 'src/dawn/native'),
                   '-Wl,-hidden-lskia', '-Wl,-hidden-lskcms', '-Wl,-hidden-lwebgpu_dawn']
        for framework in ['CoreText', 'Metal', 'CoreGraphics', 'Foundation', 'ImageIO',
                          'IOSurface', 'IOKit', 'QuartzCore', 'Cocoa']:
            command += ['-framework', framework]
        run(mode + '-compile', [*command, '-o', str(binary)], 12)
        if before != hashes():
            raise RuntimeError('Dawn inputs changed during compilation')
        run(mode + '-runtime', [str(binary)], 3)
        assert 'VOX_DAWN_IDLE_RASTER_RELEASE retained_device=1 purgeable_bytes=0' in (
            output / (mode + '-runtime.log')).read_text()
        print((output / (mode + '-runtime.log')).read_text().splitlines()[0], flush=True)
    if before != hashes():
        raise RuntimeError('Dawn inputs changed during checks')
    (output / 'receipt.json').write_text(json.dumps(dict(passed=True, sources=before,
                                                       commands=records), indent=2) + '\n')


if __name__ == '__main__':
    main()
