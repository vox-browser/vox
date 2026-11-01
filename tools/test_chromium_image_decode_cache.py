#!/usr/bin/env python3
"""Check resource identity, retained-picture reuse and decode-cache bounds."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = args.output or Path(tempfile.mkdtemp(prefix='image-decode-cache-', dir=repo / 'Build'))
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources = ['native_chromium_image_decode_cache.h', 'native_graphite_bridge.h',
               'tools/native_chromium_image_decode_cache_test.cpp']
    before = {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in sources}
    binary = output / 'decode-cache-test'
    commands = [
        ('build', ['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=address,undefined',
                   '-fno-omit-frame-pointer', str(repo / sources[-1]), '-o', str(binary)], 12),
        ('run', [str(binary)], 3),
    ]
    steps = []
    for name, command, limit in commands:
        guarded = ['python3', str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                   '--lock', str(output / (name + '.lock')),
                   '--report', str(output / (name + '.json')), '--', *command]
        with (output / (name + '.log')).open('x') as log:
            code = subprocess.run(guarded, cwd=repo, stdout=log, stderr=subprocess.STDOUT).returncode
        steps.append(dict(name=name, exit_code=code))
        print((output / (name + '.log')).read_text(), end='')
        if code:
            break
    after = {name: hashlib.sha256((repo / name).read_bytes()).hexdigest() for name in sources}
    stable = before == after
    with (output / 'status.json').open('x') as status:
        json.dump(dict(steps=steps, sources=before, sources_unchanged=stable), status, indent=2)
    print('Artifacts:', output)
    return steps[-1]['exit_code'] or (0 if stable else 1)


if __name__ == '__main__':
    raise SystemExit(main())
