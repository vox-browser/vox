#!/usr/bin/env python3
"""Check native PNG encoding against Cocoa for pixels, profiles and density."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import traceback
import zlib
from PIL import Image


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def chunks(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    result = []
    offset = 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        body = data[offset + 8:offset + 8 + length]
        assert len(body) == length
        crc = struct.unpack('>I', data[offset + 8 + length:offset + 12 + length])[0]
        assert zlib.crc32(kind + body) & 0xFFFFFFFF == crc
        if kind not in (b'IDAT', b'IEND'):
            result.append((kind.decode('ascii'), body.hex()))
        offset += length + 12
    assert offset == len(data)
    return result


def compare(reference, actual):
    with Image.open(reference) as expected, Image.open(actual) as observed:
        row = dict(pixels_exact=expected.size == observed.size and
                   expected.convert('RGBA').tobytes() == observed.convert('RGBA').tobytes(),
                   profile_exact=expected.info.get('icc_profile') == observed.info.get('icc_profile'),
                   density_exact=expected.info.get('dpi') == observed.info.get('dpi'),
                   metadata_exact=chunks(reference) == chunks(actual))
    # Inspect the scanlines independently to establish that the optimized path
    # executes, while the comparisons above cover pixels and PNG metadata.
    data = actual.read_bytes()
    offset, compressed = 8, bytearray()
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind, body = data[offset + 4:offset + 8], data[offset + 8:offset + 8 + length]
        if kind == b'IHDR':
            width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', body)
        if kind == b'IDAT':
            compressed.extend(body)
        offset += length + 12
    assert depth == 8 and color in (2, 6) and interlace == 0
    pitch = width * {2: 3, 6: 4}[color] + 1
    raw = zlib.decompress(compressed)
    row['unfiltered_rows'] = len(raw) == pitch * height and set(raw[::pitch]) == {0}
    row['passed'] = all(row.values())
    return row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve()
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix='vox-snapshot-png-'))
    output.mkdir(parents=True, exist_ok=True)
    assert not (output / 'result.json').exists(), output
    compiler = Path(shutil.which('clang')).resolve()
    files = (source / 'native_snapshot_png_darwin.h', source / 'native_snapshot_png_opaque_darwin.h', source / 'tools/native_snapshot_png_test.m',
             Path(__file__).resolve(), compiler)
    pins = {str(path): digest(path) for path in files}
    result = dict(passed=False, pins=pins, jobs={})
    try:
        for name, flag in [('nonarc', '-fno-objc-arc'), ('arc', '-fobjc-arc')]:
            directory = output / name
            directory.mkdir()
            artifacts = directory / 'artifacts'
            artifacts.mkdir()
            command = [str(compiler), flag, '-O2', '-Wall', '-Wextra', '-Werror',
                       '-framework', 'Cocoa', '-framework', 'ImageIO', '-lz', '-I', str(source),
                       str(source / 'tools/native_snapshot_png_test.m'), '-o', str(directory / 'tests')]
            row = dict(command=command, passed=False)
            result['jobs'][name] = row
            with (directory / 'compile.log').open('w') as log:
                row['compile_exit_code'] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
            if row['compile_exit_code'] != 0:
                continue
            row['binary_sha256'] = digest(directory / 'tests')
            with (directory / 'test.log').open('w') as log:
                row['test_exit_code'] = subprocess.run([str(directory / 'tests'), str(artifacts)],
                    stdout=log, stderr=subprocess.STDOUT).returncode
            records = [json.loads(line) for line in (directory / 'test.log').read_text().splitlines()
                       if line.startswith('{')]
            row['cases'] = [dict(case=case['case'], **compare(
                artifacts / ('case-%d-reference.png' % case['case']),
                artifacts / ('case-%d-actual.png' % case['case']))) for case in records]
            row['fallback_cases'] = [dict(case=case['case'], **compare(
                artifacts / ('case-%d-reference.png' % case['case']),
                artifacts / ('case-%d-fallback.png' % case['case']))) for case in records]
            row['passed'] = (row['test_exit_code'] == 0 and len(records) == 45 and
                {case['case'] for case in records} == set(range(45)) and
                all(case['passed'] for case in row['cases'] + row['fallback_cases']) and
                'PASS 45 snapshot PNG pixel/profile/density cases' in (directory / 'test.log').read_text())
        result['changed_inputs'] = [str(path) for path, sha in pins.items() if digest(Path(path)) != sha]
        result['passed'] = len(result['jobs']) == 2 and all(row['passed'] for row in result['jobs'].values()) and not result['changed_inputs']
    except BaseException:
        result['exception'] = traceback.format_exc()
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(passed=result['passed'], result=str(output / 'result.json'))))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
