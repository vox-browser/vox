#!/usr/bin/env python3
"""Observe an active native page against an unchanged offline response archive.

This is a functional diagnostic, not a performance or pixel-conformance gate.
The native observation timer writes the audit, captures the whole window, and
quits normally. Run through the memory guard with the same private PID registry.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import threading
import time

from browser_bundle_lease import canonical_bundle_lease
from measure_precise_scroll import runtime_input_paths
from page_archive import Replay, load_archive
from run_memory_bounded import publish_adopted_processes

ROOT = Path(__file__).resolve().parents[1]
SELECTORS = [('rows', 'tr.react-directory-row'),
             ('latest', '[data-testid=latest-commit]'),
             ('readme', 'article.markdown-body'),
             ('commits', 'a[href*="/commit/"]')]


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def run(args):
    output, binary, archive = args.output.resolve(), args.binary.resolve(), args.archive.resolve()
    output.mkdir(exist_ok=False, parents=True)
    replay = Replay(archive, output / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    config = dict(describe_native_errors=True, selectors=[
        dict(name=name, selector=selector, limit=200, attributes=['id', 'href'])
        for name, selector in SELECTORS])
    (output / 'audit-config.json').write_text(json.dumps(config, indent=2) + '\n')
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_'))
                   and 'proxy' not in k.lower()}
    environment.update(VOX_PROFILE_DIR=str(output / 'profile'), VOX_TEST_WINDOW='1',
        VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
        VOX_NATIVE_OBSERVATION_DELAY_MS=str(args.observe_ms),
        VOX_NATIVE_OBSERVATION_SCREENSHOT=str(output / 'window.png'),
        VOX_CAPTURE_AUDIT_CONFIG=str(output / 'audit-config.json'),
        VOX_CAPTURE_AUDIT_PATH=str(output / 'audit.json'), LADYBIRD_SCREENSHOT_SCALE='1')
    command = [str(binary), '--enable-javascript', '--js-engine=' + args.engine,
               '--window-width', '1024', '--window-height', '880', replay.manifest['url']]
    result = dict(command=command, configuration=args.configuration,
        scope='active-window functional diagnosis; whole-window PNG; no pixel/performance gate',
        observer_sha256=digest(Path(__file__)), sample_after=args.sample_after,
        host_before=dict(cpu_count=os.cpu_count(), load=os.getloadavg(), unix=time.time()))
    process = None
    try:
        # The standalone diagnostic uses the shared native libraries too.
        with canonical_bundle_lease(ROOT / 'Build/v/Vox.app'):
            paths = [binary, *runtime_input_paths(binary, environment),
                     *sorted((ROOT / 'Build/v').glob('*.dylib')), archive / 'manifest.json']
            pins = {str(path): digest(path) for path in paths}
            result['inputs_before'] = pins
            with (output / 'browser.log').open('w') as log:
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                           cwd=ROOT, env=environment)
                result['pid'] = process.pid
                publish_adopted_processes(args.memory_guard_registry, [process.pid])
                (output / 'launch.json').write_text(json.dumps(result, indent=2) + '\n')
                sampler = None
                if args.sample_after is not None:
                    def sample_stack():
                        time.sleep(args.sample_after)
                        if process.poll() is None:
                            with (output / 'sample.log').open('w') as sample_log:
                                subprocess.run(['sample', str(process.pid), '1', '1', '-file',
                                                str(output / 'sample.txt')],
                                               stdout=sample_log, stderr=subprocess.STDOUT,
                                               timeout=10, check=False)
                    sampler = threading.Thread(target=sample_stack, daemon=True)
                    sampler.start()
                try:
                    result['browser_exit'] = process.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    result['timeout'] = True
                    process.terminate()
                    try:
                        result['browser_exit'] = process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        result['browser_exit'] = process.wait()
                if sampler is not None:
                    sampler.join(timeout=12)
            result['changed_inputs'] = [path for path, expected in pins.items()
                if not Path(path).is_file() or digest(Path(path)) != expected]
            load_archive(archive)
            if (output / 'audit.json').is_file():
                audit = json.loads((output / 'audit.json').read_text())
                result['document'] = {key: audit.get(key) for key in
                    ['url', 'title', 'ready', 'visibility', 'fully_active',
                     'viewport_width', 'viewport_height']}
                result['counts'] = {group['name']: group['count'] for group in audit['selections']}
                result['javascript_diagnostics'] = audit.get('javascript_diagnostics', [])
                result['native_errors'] = audit.get('native_reported_errors', [])
                result['native_error_count'] = audit.get('native_reported_error_count', 0)
                result['native_error_information'] = audit.get('native_reported_error_information', [])
            result['png_present'] = (output / 'window.png').is_file()
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            result['browser_exit'] = process.wait()
        replay.server.shutdown()
        replay.server.server_close()
        result['host_after'] = dict(load=os.getloadavg(), unix=time.time())
        (output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result.get(key) for key in
        ['pid', 'browser_exit', 'document', 'counts', 'png_present', 'changed_inputs',
         'javascript_diagnostics']}, ensure_ascii=False))
    return 0 if (result.get('browser_exit') == 0 and result.get('png_present')
                 and not result.get('changed_inputs')) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--engine', choices=['libjs', 'javascriptcore'], default='libjs')
    parser.add_argument('--observe-ms', type=int, default=15000)
    parser.add_argument('--timeout', type=float, default=150)
    parser.add_argument('--configuration', default='diagnostic browser; see its compile receipt')
    parser.add_argument('--sample-after', type=float,
                        help='Collect a separate one-second macOS stack diagnostic after this delay')
    args = parser.parse_args()
    if args.observe_ms <= 0 or args.timeout <= args.observe_ms / 1000:
        parser.error('Timeout must exceed the positive observation delay')
    if args.sample_after is not None and args.sample_after < 0:
        parser.error('Sample delay must be nonnegative')
    raise SystemExit(run(args))


if __name__ == '__main__':
    main()
