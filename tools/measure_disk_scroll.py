#!/usr/bin/env python3
"""Benchmark a sealed page archive with precise native input and no live access.

Run inside tools/run_memory_bounded.py. The browser uses a fresh private cache
and profile each time; all responses come from the disk-only loopback replay.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

from page_archive import Replay, load_archive

REPO = Path(__file__).resolve().parents[1]


def offline_environment(proxy, certificate):
    env = {key: value for key, value in os.environ.items()
           if 'proxy' not in key.lower() and key not in {
               'DYLD_INSERT_LIBRARIES', 'CURL_CA_BUNDLE', 'REQUESTS_CA_BUNDLE', 'SSL_CERT_DIR'}}
    env.update(VOX_PROXY=proxy, SSL_CERT_FILE=certificate, NO_PROXY='')
    return env


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--binary', type=Path, default=REPO / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--require-title', required=True)
    parser.add_argument('--trials', type=int, default=2)
    parser.add_argument('--compare-env', help='Alternate control NAME=1 and candidate NAME= each round')
    parser.add_argument('--env', action='append', default=[])
    parser.add_argument('--inputs', type=int, default=360)
    parser.add_argument('--settle-seconds', type=float, default=20)
    parser.add_argument('--input-marker-env', help='Diagnostic only: touch the path after SCROLL_START')
    args = parser.parse_args()
    if args.trials < 2 or any('=' not in item for item in args.env):
        parser.error('At least two trials and NAME=VALUE environment entries are required')
    archive, output = args.archive.resolve(), args.output.resolve()
    manifest = load_archive(archive)
    output.mkdir(parents=True, exist_ok=False)
    records = []
    sources = [Path(__file__).resolve(), REPO / 'tools/page_archive.py',
               REPO / 'tools/measure_precise_scroll.py',
               REPO / 'tools/measure_precise_scroll_darwin.m',
               REPO / 'tools/pikabu_instruction_network_deny.c',
               REPO / 'tools/pikabu_instruction_network_deny_test.c']
    hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
    (output / 'tool-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
    binary = args.binary.resolve()
    pinned = [binary, *sorted(binary.parent.glob('*.dylib'))]
    build_hashes = {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in pinned}
    (output / 'build-sha256.json').write_text(json.dumps(build_hashes, indent=2) + '\n')

    def check_build():
        if build_hashes != {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in pinned}:
            raise RuntimeError('Browser build changed between trials')

    def run(command, name, env=None):
        with (output / (name + '.log')).open('w') as log:
            result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT)
        records.append(dict(name=name, command=command, exit_code=result.returncode))
        (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
        result.check_returncode()

    guard = output / 'network-deny.dylib'
    run(['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-dynamiclib',
         str(REPO / 'tools/pikabu_instruction_network_deny.c'), '-o', str(guard)], 'compile-network-guard')
    guard_test = output / 'network-deny-test'
    run(['clang', '-O2', '-Wall', '-Wextra', '-Werror',
         str(REPO / 'tools/pikabu_instruction_network_deny_test.c'), '-o', str(guard_test)], 'compile-network-test')
    run([str(guard_test)], 'network-guard-test', dict(os.environ, DYLD_INSERT_LIBRARIES=str(guard)))
    replay = Replay(archive, output / 'replay')
    server = threading.Thread(target=replay.server.serve_forever, daemon=True)
    server.start()
    rows = []
    try:
        env = offline_environment(replay.ready['proxy'], replay.ready['ca'])
        for repeat in range(1, args.trials + 1):
            for build in (['control', 'candidate'] if args.compare_env else ['browser']):
                check_build()
                name = f'{build}-{repeat}'
                start = time.time()
                command = [sys.executable, str(REPO / 'tools/measure_precise_scroll.py'),
                           '--binary', str(args.binary.resolve()), '--url', manifest['url'],
                           '--output', str(output / name), '--width', '1024', '--height', '764',
                           '--inputs', str(args.inputs), '--delta', '12', '--reverse-every', '120',
                           '--require-title', args.require_title, '--settle-seconds', str(args.settle_seconds),
                           '--timeout', '150', '--insert-library', str(guard), '--network-policy',
                           'Disk-only sealed archive at original HTTPS origins; loopback replay has no '
                           'forwarding; external DNS/connect/connectx denied by tested interposer; '
                           'no SOCKS; initially empty private cache/profile; manifest SHA256 ' +
                           replay.ready['manifest_sha256']]
                for item in args.env:
                    command += ['--env', item]
                if args.compare_env:
                    command += ['--env', args.compare_env + '=' + ('1' if build == 'control' else '')]
                if args.input_marker_env:
                    command += ['--env', args.input_marker_env + '=' + str(output / name / 'input.marker')]
                (output / (name + '-ambient.txt')).write_text(subprocess.check_output(
                    ['ps', '-axo', 'pid=,ppid=,%cpu=,rss=,etime=,comm='], text=True))
                with (output / (name + '.log')).open('w') as log:
                    child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
                    try:
                        if args.input_marker_env:
                            while child.poll() is None:
                                browser_log = output / name / 'browser.log'
                                if browser_log.exists() and 'SCROLL_START ' in browser_log.read_text(errors='replace'):
                                    (output / name / 'input.marker').touch()
                                    break
                                time.sleep(.05)
                        code = child.wait(timeout=180)
                    except BaseException:
                        child.kill()
                        child.wait()
                        raise
                records.append(dict(name=name, command=command, exit_code=code))
                (output / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
                request_log = output / 'replay/requests.jsonl'
                requests = [r for r in map(json.loads, request_log.read_text().splitlines() if request_log.exists() else [])
                            if r['t_unix'] >= start]
                (output / name / 'disk-requests.json').write_text(json.dumps(requests, indent=2) + '\n')
                if code:
                    raise RuntimeError(f'{name}: measurement exited {code}; inspect browser.log and disk-requests.json')
                check_build()
                missing = [r for r in requests if r.get('archived') is False or 'error' in r]
                if missing:
                    raise RuntimeError(f'{name}: unarchived requests; inspect disk-requests.json')
                if not any(r.get('url') == manifest['url'] and r['status'] == 200 for r in requests):
                    raise RuntimeError('Main document was not read from the archive')
                summary = json.loads((output / name / 'summary.json').read_text())
                row = dict(trial=name, **{k: v for k, v in summary.items() if k not in {'inputs', 'publications'}})
                rows.append(row)
                (output / 'summary.json').write_text(json.dumps(dict(archive=replay.ready,
                    diagnostic_only=bool(args.input_marker_env), trials=rows), indent=2) + '\n')
                print(name, 'scroll publications/s', round(summary['mean_scroll_fps'], 2),
                      'over budget', round(100 * summary['fraction_over_budget'], 2), '%', flush=True)
        # Verify bytes and metadata again, rather than trusting pathnames across trials.
        load_archive(archive)
        if hashlib.sha256((archive / 'manifest.json').read_bytes()).hexdigest() != replay.ready['manifest_sha256']:
            raise RuntimeError('Archive manifest changed during trials')
        if hashes != {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}:
            raise RuntimeError('Benchmark tools changed during trials')
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        server.join(timeout=5)


if __name__ == '__main__':
    main()
