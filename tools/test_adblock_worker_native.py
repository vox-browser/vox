#!/usr/bin/env python3
"""Exercise the macOS filter-helper transport without creating a browser window."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New directory for all binaries, logs and receipts')
    parser.add_argument('--helper', type=Path, help='Existing explicitly worker-capable executable')
    parser.add_argument('--gc', choices=['boehm', 'none'], default='boehm')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('The subprocess backend is macOS-only; other platforms retain the direct engine')
    output = args.output.resolve()
    output.mkdir()
    source_names = ['fake', 'transport', 'parent_death', 'publication']
    sources = [ROOT / 'tools' / ('adblock_worker_' + name + '_test.c') for name in source_names]
    inputs = sources + [Path(__file__), ROOT / 'main.v']
    inputs += [path for path in (ROOT / 'adblock').iterdir() if path.is_file() and path.suffix in ['.v', '.h', '.c', '.bin', '.gz']]
    pins = {str(path): sha(path) for path in inputs}
    (output / 'pins.json').write_text(json.dumps(pins, indent=2))
    env = {key: value for key, value in os.environ.items() if not key.startswith(('GC_', 'VOX_', 'LADYBIRD_', 'DYLD_'))}
    for name in ['tmp', 'cache']:
        (output / name).mkdir()
    env.update(VTMP=str(output / 'tmp'), TMPDIR=str(output / 'tmp'), VCACHE=str(output / 'cache'), GC_MARKERS='1')
    result = {'console_only_no_browser_ram_credit': True, 'rows': []}
    def run(command, label):
        started = time.monotonic()
        with (output / (label + '.log')).open('w') as log:
            code = subprocess.run(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=300).returncode
        result['rows'].append({'command': command, 'actual_exit': code, 'elapsed': time.monotonic() - started})
        if code:
            raise RuntimeError(label + ' failed; raw log retained')
    try:
        main_source = (ROOT / 'main.v').read_text().split('fn main() {', 1)[1]
        first = re.sub(r'^\s*(?://[^\n]*\n\s*)*', '', main_source)
        assert first.startswith('if status := adblock.run_default_worker_role(os.args)'), 'Worker dispatch must precede browser heap/font/GUI initialization'
        helper = args.helper.resolve() if args.helper else output / 'helper'
        if not args.helper:
            compiler = os.environ.get('V_BIN') or shutil.which('v') or str(Path.home() / 'code/v/v')
            run([compiler, '-old-compiler', '-bug-report-url', 'http://127.0.0.1:9', '-enable-globals', '-exclude', '@vlib/time/zoneinfo.native.v', '-gc', args.gc, '-path', str(ROOT) + '|@vlib', '-keepc', '-o', str(helper), str(ROOT / 'tools/adblock-worker-mini/main.v')], 'helper-compile')
        result['helper_sha256'] = sha(helper)
        for name, source in zip(source_names, sources):
            run(['cc', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror', '-Wno-unused-function', str(source), '-o', str(output / name)], name + '-compile')
        run([str(output / 'transport'), str(output / 'fake'), str(output / 'requests.log')], 'transport-run')
        run([str(output / 'publication'), str(output / 'fake')], 'publication-run')
        invalid = subprocess.run([str(helper), '--vox-adblock-worker-v1', 'unexpected-argument'], env=env, capture_output=True)
        result['invalid_worker_role_exit'] = invalid.returncode
        assert invalid.returncode == 64 and not invalid.stdout and not invalid.stderr
        with (output / 'parent-death.log').open('w') as log:
            parent = subprocess.Popen([str(output / 'parent_death'), str(helper)], env=env, stdout=subprocess.PIPE, stderr=log, text=True)
            child = int(parent.stdout.readline().strip())
            parent.kill()
            result['actual_killed_parent_exit'] = parent.wait(timeout=5)
            started = time.monotonic()
            while True:
                status = subprocess.run(['/bin/ps', '-o', 'stat=', '-p', str(child)], capture_output=True, text=True)
                if status.returncode:
                    break
                if time.monotonic() - started > 5:
                    raise RuntimeError('Owned helper survived its parent; PID ' + str(child))
                time.sleep(.05)
            result['helper_gone_after_parent_death_seconds'] = time.monotonic() - started
        result['status'] = 'passed'
    except BaseException:
        result.update(status='failed', exception=traceback.format_exc())
    result['changed_pins'] = [name for name, digest in pins.items() if not Path(name).exists() or sha(name) != digest]
    if result['changed_pins']:
        result['status'] = 'failed'
    result['native_objects'] = {str(path): sha(path) for path in (output / 'cache').rglob('*') if path.is_file() and ('adblock' in path.name)}
    result['actual_outer_exit'] = int(result['status'] != 'passed')
    (output / 'result.json').write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return result['actual_outer_exit']

if __name__ == '__main__':
    sys.exit(main())
