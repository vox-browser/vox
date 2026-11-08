#!/usr/bin/env python3
"""Check real filter input pixels, ownership and repeated-frame RSS.

Run inside run_memory_bounded.py with --limit-gib 3. This compiles the canonical
native filter entry points; the fixture does not load a browser or network.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from test_native_document_canvas import entry_points


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = [root / 'native_capture_darwin.m', root / 'tools/native_css_filter_source_test.m',
              root / 'tools/test_native_document_canvas.py', Path(__file__).resolve()]
    inputs += list(root.glob('native/include/native*darwin.h'))
    pins = {str(path): digest(path) for path in inputs}
    fragment = output / 'native_document_canvas_entry_points.inc'
    fragment.write_text(entry_points(inputs[0].read_text()))
    binary = output / 'test'
    command = ['clang', '-O2', '-fobjc-arc', '-fblocks', '-Wno-deprecated-declarations',
               '-I', str(root), '-I', str(output), str(inputs[1]),
               '-framework', 'Cocoa', '-framework', 'CoreGraphics', '-framework', 'CoreImage',
               '-framework', 'QuartzCore', '-framework', 'IOSurface', '-o', str(binary)]
    result = {'pins': pins, 'command': command, 'fragment_sha256': digest(fragment)}
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
