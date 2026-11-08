#!/usr/bin/env python3
"""Check rounded image/background coverage against frozen Brave corner pixels."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parent.parent
BODY = REPO / 'Tests/Browser/Brave/sites/engadget/bodies/8285b5bb088a1bc8402bfb3ca2cd89ffed598d0930164febb13857ba2201783b'
REFERENCE = REPO / 'Tests/Browser/Brave/resources/engadget-rounded-image-corners.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPO / 'Build/native-rounded-image-pair' / str(time.time_ns()))
    parser.add_argument('--library', type=Path, default=REPO / 'Build/v/Vox.app/Contents/MacOS/libVoxGraphite.dylib')
    args = parser.parse_args()
    output, library = args.output.resolve(), args.library.resolve()
    output.mkdir(parents=True, exist_ok=False)
    expected = json.loads(REFERENCE.read_text())
    if digest(BODY) != expected['image_sha256']:
        raise SystemExit('Original publisher WebP bytes changed')
    codec = next((p for p in [Path('/opt/homebrew/lib/libwebpdecoder.dylib'),
                              Path('/usr/local/lib/libwebpdecoder.dylib')] if p.is_file()), None)
    if codec is None:
        raise SystemExit('libwebpdecoder is required')
    sources = [BODY, REFERENCE, library, codec.resolve(), Path(__file__).resolve(),
               REPO / 'tools/native_chromium_rounded_image_pair_test.mm',
               REPO / 'native/include/native_graphite_bridge.h', REPO / 'native/include/native_image_color_profile.h']
    pins = lambda: {str(p): digest(p) for p in sources}
    before = pins()
    (output / 'identity.json').write_text(json.dumps(before, indent=2))
    binary = output / 'native_rounded_image_pair_test'
    commands = [('compile', ['clang++', '-std=c++20', '-O2', '-framework', 'Foundation',
                             str(sources[5]), '-o', str(binary)], 12),
                ('runtime', [str(binary), str(BODY), str(REFERENCE), str(library)], 3)]
    code = 0
    for name, command, limit in commands:
        guarded = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                   '--lock', str(output / (name + '.lock')), '--report',
                   str(output / (name + '.guard.json')), '--'] + command
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run(guarded, stdout=log, stderr=subprocess.STDOUT).returncode
        if code:
            break
    after = pins()
    (output / 'identity-after.json').write_text(json.dumps(after, indent=2))
    summary = dict(status='pass' if code == 0 and before == after else 'failure',
                   child_exit=code, unchanged_inputs=before == after, reference_pixels=240,
                   separate_control_different_pixels=14 if code == 0 else None,
                   paired_different_pixels=0 if code == 0 else None)
    (output / 'summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(dict(**summary, artifacts=str(output))))
    return 0 if summary['status'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
