#!/usr/bin/env python3
"""Exercise Core Image shadow coloring across every byte alpha value.

Run through run_memory_bounded with --limit-gib 3. The test uses the canonical
native color matrix and real Core Image rendering, without launching a browser.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = root / 'tools/native_css_drop_shadow_test.m'
    inputs = [source, root / 'native/include/native_css_drop_shadow_darwin.h', Path(__file__).resolve()]
    pins = {str(path): digest(path) for path in inputs}
    binary = output / 'test'
    command = ['clang', '-O2', '-fobjc-arc', '-fblocks', '-I', str(root), str(source),
               '-framework', 'Cocoa', '-framework', 'CoreImage', '-o', str(binary)]
    result = dict(pins=pins, command=command)
    with (output / 'compile.log').open('w') as log:
        result['compile_exit'] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
    if result['compile_exit'] == 0:
        with (output / 'run.log').open('w') as log:
            result['run_exit'] = subprocess.run([str(binary)], stdout=log, stderr=subprocess.STDOUT).returncode
        result['binary_sha256'] = digest(binary)
    result['changed_inputs'] = [name for name, sha in pins.items() if digest(Path(name)) != sha]
    result['exit'] = int(result['compile_exit'] != 0 or result.get('run_exit') != 0 or bool(result['changed_inputs']))
    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result[key] for key in ('compile_exit', 'run_exit', 'changed_inputs', 'exit') if key in result}))
    return result['exit']


if __name__ == '__main__':
    raise SystemExit(main())
