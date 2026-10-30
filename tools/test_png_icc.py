#!/usr/bin/env python3
"""Check native PNG ICC metadata bounds and buffer tagging on macOS."""

import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import time
import zlib

REPO = Path(__file__).resolve().parents[1]
RESOURCES = REPO / 'Tests/Browser/Brave/resources'


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def run_cases(executable, output):
    tagged = RESOURCES / 'icc-matrix-p3.png'
    plain = RESOURCES / 'icc-matrix-untagged.png'
    environment = dict(os.environ, ASAN_OPTIONS='detect_leaks=0')
    subprocess.run([str(executable), str(tagged), str(plain)], env=environment, check=True)
    data = tagged.read_bytes()
    offset = 8
    profile = None
    while offset + 12 <= len(data):
        size = struct.unpack_from('>I', data, offset)[0]
        if data[offset + 4:offset + 8] == b'iCCP':
            payload = data[offset + 8:offset + 8 + size]
            profile = zlib.decompress(payload.split(b'\0', 1)[1][1:])
            break
        offset += size + 12
    assert profile is not None

    def png(*chunks):
        return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', b'\0' * 13) + b''.join(chunks) + chunk(b'IDAT', b'')

    def icc(value=profile, name=b'test', method=0):
        return chunk(b'iCCP', name + b'\0' + bytes([method]) + zlib.compress(value))

    cases = [
        ('valid', png(icc()), profile), ('untagged', png(), None),
        ('bad-method', png(icc(method=1)), None), ('empty-name', png(icc(name=b'')), None),
        ('long-name', png(icc(name=b'x' * 80)), None), ('max-name', png(icc(name=b'x' * 79)), profile),
        ('cicp', png(icc(), chunk(b'cICP', b'\1\1\0\1')), None),
        ('srgb', png(chunk(b'sRGB', b'\0'), icc()), profile),
        ('late', png(chunk(b'IDAT', b''), icc()), None),
        ('invalid-icc', png(icc(b'x' * 520)), None),
    ]
    complete = png(icc())
    for size in range(0, 33 + len(icc()), 7):
        cases.append((f'prefix-{size}', complete[:size], None))
    compressed = zlib.compress(profile)
    for size in range(0, len(compressed), 5):
        cases.append((f'deflate-{size}', png(chunk(b'iCCP', b'test\0\0' + compressed[:size])), None))
    oversized = bytearray(17 * 1024 * 1024)
    oversized[:4] = struct.pack('>I', len(oversized))
    oversized[36:40] = b'acsp'
    cases.append(('bounded', png(icc(bytes(oversized))), None))
    results = []
    for name, source, expected in cases:
        source_path, target = output / (name + '.png'), output / (name + '.icc')
        source_path.write_bytes(source)
        result = subprocess.run([str(executable), '--extract', str(source_path), str(target)],
                                env=environment, capture_output=True, text=True)
        passed = result.returncode == (1 if expected is None else 0)
        passed = passed and (expected is None or target.read_bytes() == expected)
        results.append(dict(name=name, passed=passed, exit=result.returncode,
                            log=result.stdout + result.stderr))
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(f'ICC extraction: {sum(row["passed"] for row in results)}/{len(results)} passed')
    return 0 if all(row['passed'] for row in results) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--execute', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('This native test requires macOS')
    output = (args.output_dir or REPO / 'Build/native-png-icc' / str(time.time_ns())).resolve()
    if args.execute:
        return run_cases(args.execute, output)
    output.mkdir(parents=True, exist_ok=False)
    executable = output / 'native_png_icc_test'
    compile_command = ['clang', '-fobjc-arc', '-O1', '-g', '-fsanitize=address',
                       '-fno-omit-frame-pointer', '-I' + str(REPO), '-framework', 'Foundation',
                       '-lz', str(REPO / 'tools/native_png_icc_test.m'), '-o', str(executable)]
    for name, command, limit in [
        ('compile', compile_command, '12'),
        ('runtime', [sys.executable, str(Path(__file__).resolve()), '--execute', str(executable),
                     '--output-dir', str(output)], '3'),
    ]:
        with (output / (name + '.log')).open('x') as log:
            result = subprocess.run([sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                                     '--lock', str(output / (name + '.lock')), '--report',
                                     str(output / (name + '-guard.json')), '--limit-gib', limit,
                                     '--'] + command, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            print(f'{name} failed; evidence: {output}')
            return result.returncode
    print(f'ICC metadata checks passed; evidence: {output}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
