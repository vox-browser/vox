#!/usr/bin/env python3
"""Check the browser's Boehm marker default and its environment override."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--expected-default', type=int, default=1)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--library-dir', type=Path)
    args = parser.parse_args()
    if args.expected_default < 1:
        parser.error('--expected-default must be positive')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    configurations = [('default', None, args.expected_default), ('override', '2', 2)]
    for label, override, expected in configurations:
        env = dict(os.environ, GC_PRINT_STATS='1')
        env.pop('GC_MARKERS', None)
        if override is not None:
            env['GC_MARKERS'] = override
        if args.library_dir:
            env['DYLD_LIBRARY_PATH'] = str(args.library_dir.resolve())
        run = subprocess.run([str(args.binary.resolve()), '--headless-smoke'], env=env,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                             timeout=120)
        args.output.with_name(args.output.stem + '-' + label + '.log').write_text(run.stdout)
        run.check_returncode()
        collections = sorted({int(n) for n in re.findall(r'GC #(\d+)', run.stdout)})
        helpers = [int(n) for n in re.findall(r'Started (\d+) mark helper threads', run.stdout)]
        markers = 1 + (max(helpers) if helpers else 0)
        assert collections, 'Missing Boehm collection trace; collection must remain enabled'
        assert 'smoke check passed' in run.stdout, 'Missing engine/JavaScript smoke result'
        assert markers == expected, (label, markers, expected)
        rows.append(dict(mode=label, override=override, markers=markers,
                         collections=collections, exit=run.returncode))
    result = dict(exit=0, binary=str(args.binary.resolve()), rows=rows)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
