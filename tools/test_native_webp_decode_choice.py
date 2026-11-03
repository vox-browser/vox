#!/usr/bin/env python3
"""Diagnose WebP RGB/YUV differences against retained full-uBO Brave pixels."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parent.parent
BODY = REPO / 'Tests/Browser/Brave/resources/engadget-webp-decode-choice.webp'
REFERENCE = BODY.with_suffix('.json')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=REPO / 'Build/native-webp-decode-choice' / str(time.time_ns()))
    parser.add_argument('--library', type=Path, default=REPO / 'Build/v/Vox.app/Contents/MacOS/libVoxGraphite.dylib')
    parser.add_argument('--sanitize', action='store_true')
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
               REPO / 'tools/native_webp_decode_choice_test.mm', REPO / 'native_graphite_bridge.h',
               REPO / 'native_image_color_profile.h']
    pins = lambda: {str(p): digest(p) for p in sources}
    before = pins()
    (output / 'identity.json').write_text(json.dumps(before, indent=2))
    binary = output / 'native_webp_decode_choice_test'
    flags = ['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer'] if args.sanitize else ['-O2']
    commands = [('compile', ['clang++', '-std=c++20', *flags, '-framework', 'Foundation',
                             str(sources[5]), '-o', str(binary)], 12),
                ('runtime', [str(binary), str(BODY), str(REFERENCE), str(library)], 3)]
    code = 0
    for name, command, limit in commands:
        guarded = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                   '--lock', str(output / (name + '.lock')), '--report',
                   str(output / (name + '.guard.json')), '--', *command]
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run(guarded, stdout=log, stderr=subprocess.STDOUT).returncode
        if code:
            break
    after = pins()
    (output / 'identity-after.json').write_text(json.dumps(after, indent=2))
    roi = expected['comparison_rect']
    summary = dict(status='pass' if code == 0 and before == after else 'failure',
                   child_exit=code, unchanged_inputs=before == after, sanitized=args.sanitize,
                   reference_pixels=roi[2] * roi[3], full_site_parity=False,
                   rgb_different_pixels=expected['rgb_different_pixels'] if code == 0 else None,
                   yuv_control_different_pixels=expected['yuv_control_different_pixels'] if code == 0 else None)
    (output / 'summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(dict(**summary, artifacts=str(output))))
    return 0 if summary['status'] == 'pass' else 1


if __name__ == '__main__':
    sys.exit(main())
