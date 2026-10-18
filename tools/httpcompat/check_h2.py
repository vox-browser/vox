#!/usr/bin/env python3
"""Check HTTP/2 I/O admission and optionally its TLS integration fixtures."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gc', choices=('both', 'boehm', 'none'), default='both')
    parser.add_argument('--integration', action='store_true')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    compiler = os.environ.get('V_BIN', shutil.which('v') or str(Path.home() / 'code/v/v'))
    modules = Path(subprocess.check_output(
        [sys.executable, str(repo / 'tools/prepare_http_compat.py'), compiler], text=True).strip())
    target = modules / 'net/http/vox_h2_fairness_test.v'
    content = (repo / 'tools/httpcompat/h2_fairness_test.v.inc').read_text()
    if not target.exists() or target.read_text() != content:
        temporary = target.with_suffix(f'.{os.getpid()}.tmp')
        temporary.write_text(content)
        temporary.replace(target)
    tests = [str(target)]
    if args.integration:
        tests.append(str(repo / 'browsernet/http2_tls_test.v'))
    for mode in ('boehm', 'none') if args.gc == 'both' else (args.gc,):
        for index, test in enumerate(tests):
            binary = repo / f'Build/v/httpcompat/check_h2_{mode}_{index}'
            # Direct compilation avoids vtest's shell rejoining the pipe-separated
            # module search path without quoting. Always run the resulting test.
            command = [compiler, '-old-compiler', '-enable-globals', '-skip-running',
                       '-path', f'{modules}|{repo}|@vmodules|@vlib', '-gc', mode,
                       '-o', str(binary), test]
            print(f'Compile and run {Path(test).name} with {mode}', flush=True)
            subprocess.run(command, cwd=repo, check=True)
            subprocess.run([str(binary)], cwd=repo, check=True)


if __name__ == '__main__':
    main()
