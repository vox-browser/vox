#!/usr/bin/env python3
"""Exercise the production repaint-wake functions and retained pixels under ARC/MRC."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    args.output.mkdir(parents=True, exist_ok=False)
    source = root / 'native_capture_darwin.m'
    declarations = ['static void native_mark_browser_redraw(',
                    'static void native_request_browser_redraw(',
                    'void native_wake_browser(',
                    'void native_wake_browser_during_preparation(']
    text = source.read_text()
    functions = []
    for declaration in declarations:
        start = text.index(declaration)
        functions.append(text[start:text.index('\n}\n', start) + 2])
    (args.output / 'native_prepared_wakes.inc').write_text('\n\n'.join(functions) + '\n')
    inputs = [source, root / 'native_layer_presentation_darwin.h',
              root / 'native_layer_presentation_test_darwin.h',
              root / 'tools/native_prepared_wakes_test.m', Path(__file__).resolve()]
    fingerprint = lambda: {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = fingerprint()
    jobs = []
    for mode, flag in [('mrc', '-fno-objc-arc'), ('arc', '-fobjc-arc')]:
        binary = args.output / mode
        command = [shutil.which('clang'), '-O2', '-fblocks', flag,
                   '-framework', 'Cocoa', '-framework', 'QuartzCore', '-framework', 'CoreGraphics',
                   '-I', str(root), '-I', str(args.output.resolve()),
                   str(root / 'tools/native_prepared_wakes_test.m'), '-o', str(binary)]
        with (args.output / (mode + '.log')).open('w') as log:
            compiled = subprocess.call(command, stdout=log, stderr=subprocess.STDOUT)
            tested = subprocess.call([str(binary.resolve())], stdout=log, stderr=subprocess.STDOUT) if compiled == 0 else None
        jobs.append(dict(mode=mode, command=command, compile_exit=compiled, test_exit=tested))
        print(json.dumps(jobs[-1]), flush=True)
    passed = before == fingerprint() and all(j['test_exit'] == 0 for j in jobs)
    (args.output / 'result.json').write_text(json.dumps(dict(passed=passed, sources=before, jobs=jobs), indent=2) + '\n')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
