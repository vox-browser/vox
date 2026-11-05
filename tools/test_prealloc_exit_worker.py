#!/usr/bin/env python3
"""Exercise a native worker reading V-owned state during normal process exit."""
import argparse
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--compiler', default=str(Path.home() / 'code/v/v'))
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    executable = out / 'exit-worker'

    def guarded(name, command, expected):
        report = out / (name + '-guard.json')
        call = ['python3', str(ROOT / 'tools/run_memory_bounded.py'),
                '--lock', str(out / (name + '.lock')), '--report', str(report),
                '--limit-gib', '3' if name != 'compile' else '12',
                '--timeout', '120', '--', *command]
        env = dict(os.environ, V_MACOS_V3_NO_FALLBACK='1')
        result = subprocess.run(call, cwd=ROOT, env=env, capture_output=True, text=True)
        (out / (name + '.log')).write_text(result.stdout + result.stderr)
        receipt = json.loads(report.read_text())
        assert receipt['child_exit_code'] == expected, (name, receipt, result.stdout, result.stderr)
        assert result.returncode == expected, (name, result.returncode)
        if name.startswith('browser'):
            assert 'EXIT_WORKER_OK' in result.stdout + result.stderr

    guarded('compile', [args.compiler, '-memory-limit', '10G', '-nocache', '-enable-globals',
                       '-prealloc', '-gc', 'none', '-o', str(executable),
                       str(ROOT / 'tools/prealloc_exit_worker_fixture.v')], 0)
    # Establish that the test exposes the original teardown order, then verify
    # the browser policy repeatedly with fresh processes and normal exit().
    guarded('unprotected', [str(executable)], 139)
    for i in range(5):
        guarded('browser-' + str(i), [str(executable), 'browser'], 0)
    print('Prealloc exit: original lifetime fault reproduced; five browser workers survive cleanup.')


if __name__ == '__main__':
    main()
