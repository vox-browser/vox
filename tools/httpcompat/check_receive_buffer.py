#!/usr/bin/env python3
"""Run response-buffer ownership, retention and upstream framing checks."""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--gc', choices=['both', 'boehm', 'none'], default='both')
    parser.add_argument('--asan', action='store_true')
    args = parser.parse_args()
    if args.asan and args.gc != 'none':
        parser.error('--asan requires --gc none')
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    out.mkdir()
    compiler = os.environ.get('V_BIN', shutil.which('v') or str(Path.home() / 'code/v/v'))
    modules = Path(subprocess.check_output(
        [sys.executable, str(repo / 'tools/prepare_http_compat.py'), compiler],
        cwd=repo, text=True).strip())
    target = modules / 'net/http/vox_receive_buffer_test.v'
    template = repo / 'tools/httpcompat/receive_buffer_test.v.inc'
    temporary = target.with_suffix(f'.{os.getpid()}.tmp')
    temporary.write_bytes(template.read_bytes())
    temporary.replace(target)
    pinned = [Path(__file__).resolve(), template, repo / 'tools/http_receive_buffer.py',
              repo / 'tools/httpcompat/receive_buffer.h', repo / 'tools/prepare_http_compat.py',
              target, modules / 'net/http/request.v', modules / 'net/http/request_receive_test.v',
              modules / 'net/http/vox_receive_buffer.v']
    def identity():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in pinned}
    before = identity()
    expected_names = [name for p in [target, modules / 'net/http/request_receive_test.v']
                      for name in re.findall(r'^fn (test_\w+)', p.read_text(), re.M)]
    compiler_tmp = out / 'compiler-tmp'
    compiler_tmp.mkdir()
    rows = []
    for mode in ['none', 'boehm'] if args.gc == 'both' else [args.gc]:
        binary = out / f'receive_{mode}'
        command = [compiler, '-memory-limit', '10G', '-enable-globals', '-cc', 'clang',
                   '-keepc',
                   '-path', f'{modules}|{repo}|@vmodules|@vlib', '-gc', mode]
        if mode == 'none':
            command += ['-prealloc']
        if args.asan:
            command += ['-cflags', '-fsanitize=address -fno-omit-frame-pointer',
                        '-ldflags', '-fsanitize=address']
        command += ['-file-list', str(modules / 'net/http/request_receive_test.v'),
                    '-o', str(binary), str(target)]
        env = os.environ.copy()
        env.update(VOX_ARENA_POISON='1', VOX_ARENA_POISON_FULL='1')
        env['VTMP'] = str(compiler_tmp)
        if args.asan:
            env['ASAN_OPTIONS'] = 'detect_leaks=0'
        for stage, actual in [('build', command), ('runtime', [str(binary)])]:
            guarded = [sys.executable, str(repo / 'tools/run_memory_bounded.py'),
                       '--lock', str(out / f'{mode}-{stage}.lock'),
                       '--report', str(out / f'{mode}-{stage}-guard.json')]
            if stage == 'runtime':
                guarded += ['--limit-gib', '3']
            guarded += ['--', *actual]
            with (out / f'{mode}-{stage}.log').open('w') as log:
                code = subprocess.run(guarded, cwd=repo, env=env, stdout=log,
                                      stderr=subprocess.STDOUT).returncode
            rows.append(dict(mode=mode, stage=stage, command=guarded, exit=code))
            if stage == 'build' and code == 0:
                sources = list(compiler_tmp.rglob(f'{binary.name}.*.tmp.c'))
                if len(sources) != 1:
                    raise RuntimeError('Cannot identify retained test C source')
                source = sources[0].read_text()
                harness = re.search(r'^int main\([^\n]*\)\s*\{.*?^\}', source, re.M | re.S)
                if not harness:
                    raise RuntimeError('Test harness not found')
                registered = [name for name in expected_names
                              if re.search(r'\b\w*' + re.escape(name) + r'\(\);', harness[0])]
                rows[-1].update(c_source=str(sources[0]),
                                c_source_sha256=hashlib.sha256(source.encode()).hexdigest(),
                                expected_cases=expected_names, registered_cases=registered)
                if registered != expected_names:
                    code = 1
                    rows[-1]['case_count_error'] = True
            if stage == 'runtime' and code == 0:
                rows[-1]['passed_cases'] = len(expected_names)
            changed = identity() != before
            (out / 'result.json').write_text(json.dumps(dict(
                inputs=before, inputs_changed=changed, asan=args.asan,
                environment={k: env[k] for k in ['VTMP', 'VOX_ARENA_POISON',
                             'VOX_ARENA_POISON_FULL', 'ASAN_OPTIONS'] if k in env},
                results=rows), indent=2) + '\n')
            print(mode, stage, code, flush=True)
            if code or changed:
                raise SystemExit(code or 1)


if __name__ == '__main__':
    main()
