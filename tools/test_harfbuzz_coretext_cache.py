#!/usr/bin/env python3
"""Check face-owned CoreText hyphen results, including cached negative results."""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=False)
    inputs = [root / 'platform/harfbuzz_coretext_macos.h',
              root / 'tools/harfbuzz_coretext_cache_test.c', Path(__file__).resolve()]
    fingerprint = lambda: {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = fingerprint()
    flags = shlex.split(subprocess.check_output(
        ['pkg-config', '--cflags', '--libs', 'harfbuzz'], text=True))
    binary = (args.output / 'test').resolve()
    command = ['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-I', str(root),
               str(inputs[1]), '-framework', 'CoreText', '-framework', 'CoreFoundation',
               *flags, '-o', str(binary)]
    with (args.output / 'test.log').open('w') as log:
        compiled = subprocess.call(command, stdout=log, stderr=subprocess.STDOUT)
        tested = subprocess.call([str(binary)], stdout=log, stderr=subprocess.STDOUT) if compiled == 0 else None
    passed = before == fingerprint() and tested == 0
    result = dict(passed=passed, sources=before, command=command,
                  compile_exit=compiled, test_exit=tested)
    (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(dict(passed=passed, compile_exit=compiled, test_exit=tested)), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
