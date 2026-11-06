#!/usr/bin/env python3
"""Alternate sealed -prod variants in the canonical bundle and restore it.

No bundles or repository tools are copied. Only executable build outputs are
    installed while holding the exclusive publication lease. Each measured
browser is a fresh process with a private empty profile/cache.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading

from browser_bundle_lease import publication_lease, ROOT
from freeze_browser_compile import fingerprint, check_fingerprints, digest
from localize_bundle_rpaths import localize
from page_archive import Replay
from rebuild_browser import write_json


def replace_executable(source, binary, bundle):
    temporary = binary.with_name('.Vox-mode-comparison')
    shutil.copyfile(source, temporary)
    temporary.chmod(0o755)
    os.replace(temporary, binary)
    subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements',
                    str(ROOT / 'packaging/Vox.entitlements.plist'), str(bundle)], check=True)
    subprocess.run(['codesign', '--verify', str(bundle)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--builds', required=True, type=Path)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--counter-pairs', type=int, default=7)
    parser.add_argument('--timing-pairs', type=int, default=2)
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--prepare-builds', action='store_true',
                        help='Relink sealed variants against the latest common native libraries before measuring')
    args = parser.parse_args()
    output, builds = args.output.resolve(), args.builds.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if not args.prepare_builds and not json.loads((builds / 'built.json').read_text())['complete']:
        raise ValueError('Matched compilation did not complete')
    bundle = ROOT / 'Build/v/Vox.app'
    binary = bundle / 'Contents/MacOS/Vox'
    state = ROOT / 'Build/production-build'
    replay = None
    rows = []
    with publication_lease(ROOT) as lease_fd:
        os.environ['VOX_BUNDLE_LEASE_FD'] = str(lease_fd)
        with publication_lease(ROOT):
            original = output / 'original-Vox'
            shutil.copyfile(binary, original)
            original_hash = digest(binary)
            pinned = fingerprint([p for p in bundle.rglob('*') if p.is_file()
                                  and p != binary and '_CodeSignature' not in p.parts]
                                 + [ROOT / 'tools/measure_precise_scroll.py',
                                    ROOT / 'tools/measure_precise_scroll_darwin.m',
                                    state / 'latest.json'])
        try:
            if args.prepare_builds:
                from compare_prod_modes import refresh_native, finish
                refresh_native(builds)
                finish(builds)
            executables = {}
            for mode in ('single', 'parallel'):
                executable = builds / mode / 'Vox'
                localize(executable, ROOT / 'Build/v')
                subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements',
                                str(ROOT / 'packaging/Vox.entitlements.plist'), str(executable)], check=True)
                executables[mode] = executable
            if not args.live:
                replay = Replay(args.archive, output / 'replay')
                threading.Thread(target=replay.server.serve_forever, daemon=True).start()
            write_json(output / 'protocol.json', dict(
                scope='main-process scrolling, first native wheel dispatch through its final publication/dispatch completion',
                original_executable_sha256=original_hash, runtime_inputs=pinned,
                modes={mode: dict(path=str(path), sha256=digest(path)) for mode, path in executables.items()},
                replay=replay.ready if replay else None, gpu_canvas=True,
                counter_pairs=args.counter_pairs, timing_pairs=args.timing_pairs))
            cohorts = [('diagnostic', 1), ('timing', args.timing_pairs), ('counters', args.counter_pairs)]
            for cohort, pairs in cohorts:
                for pair in range(pairs):
                    for mode in ('single', 'parallel'):
                        name = f'{cohort}-{pair + 1}-{mode}'
                        print('Measuring ' + name, flush=True)
                        with publication_lease(ROOT):
                            check_fingerprints(pinned)
                            replace_executable(executables[mode], binary, bundle)
                            selected_hash = digest(binary)
                        command = [sys.executable, str(ROOT / 'tools/measure_precise_scroll.py'),
                                   '--output', str(output / name), '--url', 'https://vlang.io/',
                                   '--width', '1708', '--height', '953', '--chrome-height', '112',
                                   '--inputs', '600', '--input-hz', '120', '--delta', '8',
                                   '--reverse-every', '150', '--settle-seconds', '10',
                                   '--require-title', 'V — The V Programming Language',
                                   '--network-policy', 'direct live HTTPS; empty private caches' if args.live else
                                   'original-origin frozen responses only; empty private caches; no forwarding']
                        if cohort == 'counters':
                            command.append('--instructions')
                        if cohort == 'diagnostic':
                            command += ['--env', 'VOX_GPU_CANVAS_VERIFY=2', '--env', 'VOX_GPU_CANVAS_DIAGNOSTICS=1']
                        environment = {key: value for key, value in os.environ.items()
                                       if not key.startswith(('VOX_', 'LADYBIRD_', 'DYLD_'))
                                       and key.lower() not in ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy')}
                        environment['VOX_TEST_WINDOW'] = '1'
                        environment['VOX_BUNDLE_LEASE_FD'] = str(lease_fd)
                        if replay:
                            environment.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
                        with publication_lease(ROOT, shared=True):
                            check_fingerprints(pinned)
                            if digest(binary) != selected_hash:
                                raise RuntimeError('Executable replaced before trial')
                            with (output / (name + '.log')).open('w') as stream:
                                result = subprocess.run(command, cwd=ROOT, env=environment, pass_fds=(lease_fd,),
                                                        stdout=stream, stderr=subprocess.STDOUT)
                            row = dict(name=name, cohort=cohort, mode=mode, pair=pair + 1,
                                       command=command, exit=result.returncode, executable_sha256=selected_hash)
                            rows.append(row)
                            write_json(output / 'attempts.json', rows)
                            check_fingerprints(pinned)
                            if digest(binary) != selected_hash:
                                raise RuntimeError('Executable replaced during trial')
                        if result.returncode:
                            raise RuntimeError('Invalid trial retained: ' + name)
                        if cohort == 'diagnostic':
                            log = (output / name / 'browser.log').read_text()
                            window = log.split('SCROLL_INPUT 0 ', 1)[1].split('SCROLL_INPUT 599 ', 1)[0]
                            gpu = re.findall(r'^VOX_GPU_CANVAS .*?draws=(\d+).*?compared=(\d+).*?max_error=(\d+)',
                                             window, re.MULTILINE)
                            if not gpu or not sum(int(row[0]) for row in gpu) or not sum(int(row[1]) for row in gpu):
                                raise RuntimeError('GPU scroll/verification not observed during input')
                            maximum = max(int(row[2]) for row in gpu)
                            write_json(output / (name + '-gpu.json'), dict(frames=len(gpu),
                                       draws=sum(int(row[0]) for row in gpu), max_channel_error=maximum))
                            if maximum > 3:
                                raise RuntimeError('Existing GPU pixel bound exceeded')
        finally:
            if replay:
                replay.server.shutdown()
                replay.server.server_close()
            with publication_lease(ROOT):
                replace_executable(original, binary, bundle)
                restored = digest(binary)
                write_json(output / 'restoration.json', dict(expected=original_hash, actual=restored,
                                                           restored=restored == original_hash))
                if restored != original_hash:
                    raise RuntimeError('Restored signed executable differs from original')


if __name__ == '__main__':
    main()
