#!/usr/bin/env python3
"""Compare retired instructions for frozen Wikipedia captures.

Both engines render https://www.wikipedia.org/ from the same frozen cache
without page JavaScript: Vox through its HTML+CSS-only site policy, Brave with
author JavaScript disabled over CDP. Counts cover process launch through
capture. Vox additionally includes teardown; Brave's observed process tree is a
polling lower bound. Neither includes GPU instructions or external services.
Missing responses fail offline. --archive replays sealed original responses
through one loopback proxy with fresh private caches/profiles for both engines.
By default every capture must match the same reference. --expected-vox permits
separate, exact per-engine baselines and reports their cross-browser difference;
that mode verifies rendering stability, not cross-browser pixel parity.
"""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
from types import SimpleNamespace

import measure_browser_instructions as measurement
from process_instruction_counts import MacCounters
from check_pixel_equality import compare
from reddit_browser_instructions import (FrozenAssetsCDP, digest, evaluate_pairs,
    fingerprint_tree, native_environment)
from page_archive import Replay, load_archive
from measure_sealed_github_instructions import native_dependencies

REPO = Path(__file__).resolve().parents[1]
URL = 'https://www.wikipedia.org/'


def engine_config(args, engine):
    replay = getattr(args, 'replay', None)
    extra = (['--proxy-server=' + replay['proxy'].replace('socks5h:', 'socks5:'),
              '--ignore-certificate-errors-spki-list=' + replay['spki'],
              '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE 127.0.0.1']
             if replay else ['--no-proxy-server',
              '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost'])
    return SimpleNamespace(binary=args.vox if engine == 'vox' else args.brave,
        url=args.url, width=1024, height=768, timeout=90, scratch_dir=args.output,
        sample_interval=.005, vox_arg=['--disable-javascript'] if replay else [],
        expect_title='Wikipedia' if args.url == URL else None, chrome_launch_mode='blank',
        chrome_disable_javascript=True,
        chrome_extra_arg=extra)


@contextmanager
def archive_replay(args):
    if not args.archive:
        yield
        return
    replay = Replay(args.archive, args.output / 'replay')
    thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
    thread.start()
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=public)
        args.replay = dict(replay.ready, spki=base64.b64encode(hashlib.sha256(der).digest()).decode())
        yield
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        thread.join(timeout=5)


@contextmanager
def archive_environment(args, engine, profile, prefix):
    saved = dict(os.environ)
    # Ambient profiles, script flags, proxy settings and heap overrides must
    # not change the workload. Trust applies only to these child processes.
    env = {key: value for key, value in saved.items()
           if 'proxy' not in key.lower()
           and not key.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_', 'JSC_'))
           and key not in ('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'REQUESTS_CA_BUNDLE')}
    env.update(VOX_PROXY=args.replay['proxy'], SSL_CERT_FILE=args.replay['ca'], NO_PROXY='',
               VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(profile / 'cache'),
               LADYBIRD_SCREENSHOT_SCALE='1', VOX_TEST_WINDOW='1', VOX_COOKIE_FILE='',
               VOX_CAPTURE_AUDIT_PATH=str(prefix) + '.audit.json')
    if engine == 'vox':
        env['DYLD_INSERT_LIBRARIES'] = str(args.network_deny)
    try:
        os.environ.clear()
        os.environ.update(env)
        yield
    finally:
        os.environ.clear()
        os.environ.update(saved)


def run_engine(args, engine, prefix, api):
    config = engine_config(args, engine)
    if getattr(args, 'replay', None):
        started = time.time()
        host = dict(cpu_count=os.cpu_count(), load_average=os.getloadavg())
        with tempfile.TemporaryDirectory(prefix=engine + '-profile-', dir=args.output) as temporary:
            with archive_environment(args, engine, Path(temporary), prefix):
                report = (measurement.run_vox(config, prefix, api) if engine == 'vox'
                          else measurement.run_chrome(config, prefix, api))
        if engine == 'vox':
            report['document_audit'] = json.loads(Path(str(prefix) + '.audit.json').read_text())
        report.update(started_unix=started, host=host,
                      cache_policy='fresh empty private cache; sealed loopback replay; no forwarding',
                      profile_policy='fresh private profile per observation',
                      screenshot_scale=1, author_javascript_enabled=False)
        return report
    if engine == 'vox':
        with native_environment(args.network_deny), measurement.fresh_vox_cache(args.cache, args.output) as (cache, _):
            return measurement.run_vox(config, prefix, api, cache)
    return measurement.run_chrome(config, prefix, api,
        client_factory=lambda url: FrozenAssetsCDP(url, args.cache))


def validate_report(report, args, engine):
    if report['unreadable_pids'] or report['instructions'] <= 0:
        raise RuntimeError('Unreadable or nonpositive browser process counters')
    if args.archive:
        audit = report['document_audit']
        if engine == 'vox':
            measurement.validate_capture_audit(audit, engine_config(args, engine))
            if not report['root_final_exit_sample']:
                raise RuntimeError('Vox final root counter is missing')
        elif audit.get('url') != args.url or audit.get('ready') != 'complete' or not audit.get('textLength'):
            raise RuntimeError('Brave captured an incomplete or incorrect document')
        if args.url == URL and audit.get('title') != 'Wikipedia':
            raise RuntimeError('Browser did not capture Wikipedia')


def pinned_inputs(args):
    paths = {args.vox, args.brave, args.network_deny, args.diff_tool,
             *native_dependencies(args.vox), *sorted(args.vox.parent.glob('*.dylib'))}
    for path in (args.expected, args.expected_vox, args.vox.with_name('VoxAdblockWorker'),
                 args.vox.parent.parent / 'Resources/adblock.snapshot.bin'):
        if path and path.is_file():
            paths.add(path)
    # The Brave launcher dlopens its framework, so its load commands alone
    # cannot pin the executable code used by its browser and helper tasks.
    frameworks = args.brave.parent.parent / 'Frameworks/Brave Browser Framework.framework/Versions'
    paths.update(path.resolve() for path in frameworks.glob('*/Brave Browser Framework'))
    for name in ('wikipedia_browser_instructions.py', 'measure_browser_instructions.py',
                 'process_instruction_counts.py', 'page_archive.py', 'check_pixel_equality.py',
                 'reddit_browser_instructions.py', 'probe_frozen_github_chrome.py',
                 'measure_sealed_github_instructions.py'):
        paths.add(REPO / 'tools' / name)
    return {str(path.resolve()): digest(path) for path in sorted(paths)}


def measure_pairs(args, api):
    pairs = []
    for index in range(args.repeat):
        pair = {}
        for engine in (['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox']):
            prefix = args.output / f'pair-{index+1}.{engine}'
            report = run_engine(args, engine, prefix, api)
            # Retain the raw counts before content or pixel validation can fail.
            path = Path(str(prefix) + '.json')
            path.write_text(json.dumps(report, indent=2) + '\n')
            validate_report(report, args, engine)
            expected = args.expected_vox if engine == 'vox' and args.expected_vox else args.expected
            verdict = compare(expected, Path(report['screenshot']),
                              Path(str(prefix) + '.diff.png'), args.diff_tool)
            report.update(pixels_exact=verdict['exact'], pixel_comparison=verdict)
            path.write_text(json.dumps(report, indent=2) + '\n')
            pair[engine] = report
            print(json.dumps(dict(pair=index+1, engine=engine, instructions=report['instructions'],
                                  pixels_exact=verdict['exact'])), flush=True)
            if not verdict['exact']:
                raise RuntimeError('Rendered viewport differs from its reference; sample rejected')
        pairs.append(pair)
    return pairs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    fixture = parser.add_mutually_exclusive_group(required=True)
    fixture.add_argument('--cache', type=Path)
    fixture.add_argument('--archive', type=Path, help='Sealed page_archive.py capture; both engines start with empty caches')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected', type=Path,
        help='Brave no-JavaScript reference; required unless --capture-reference')
    parser.add_argument('--expected-vox', type=Path,
        help='Separate exact Vox baseline; reports existing cross-browser differences without claiming pixel parity')
    parser.add_argument('--diff-tool', type=Path, default=REPO/'Build/pixel-equality/pixel_diff')
    references = parser.add_mutually_exclusive_group()
    references.add_argument('--capture-reference', action='store_true',
        help='Capture one Brave no-JavaScript reference into the output directory')
    references.add_argument('--capture-vox-reference', action='store_true',
        help='Capture a separate Vox baseline, without claiming cross-browser pixel equality')
    parser.add_argument('--url', default=URL)
    parser.add_argument('--vox', type=Path, default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--network-deny', type=Path, default=REPO/'Build/pikabu-instructions-network-deny.dylib')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--required-reduction', type=float, default=.20)
    args = parser.parse_args()
    if args.repeat < 1 or not 0 <= args.required_reduction < 1:
        parser.error('Invalid repeat count or required reduction')
    capturing = args.capture_reference or args.capture_vox_reference
    if not capturing and args.expected is None:
        parser.error('--expected is required unless --capture-reference is given')
    for name in ['cache', 'archive', 'output', 'vox', 'brave', 'network_deny',
                 'expected', 'expected_vox', 'diff_tool']:
        value = getattr(args, name)
        if value is not None:
            setattr(args, name, value.resolve())
    if args.archive and load_archive(args.archive)['url'] != args.url:
        parser.error('Archive URL differs from requested document')
    if not args.network_deny.is_file():
        parser.error('Build the process-local network deny dylib first')
    args.output.mkdir(parents=True, exist_ok=False, mode=0o700)
    api = MacCounters()
    with archive_replay(args):
        if capturing:
            engine = 'vox' if args.capture_vox_reference else 'brave'
            prefix = args.output / (engine + '-reference')
            report = run_engine(args, engine, prefix, api)
            Path(str(prefix) + '.json').write_text(json.dumps(report, indent=2) + '\n')
            validate_report(report, args, engine)
            print(json.dumps(dict(reference=report['screenshot'], instructions=report['instructions'])))
            return 0
        pinned = pinned_inputs(args)
        fixture_hash = fingerprint_tree(args.archive or args.cache)
        (args.output / 'input-sha256.json').write_text(json.dumps(pinned, indent=2) + '\n')
        reference_comparison = compare(args.expected, args.expected_vox or args.expected,
                                       args.output / 'references.diff.png', args.diff_tool)
        pairs = measure_pairs(args, api)
    if pinned != {name: digest(Path(name)) for name in pinned} or fixture_hash != fingerprint_tree(args.archive or args.cache):
        raise RuntimeError('Pinned executable, runtime or benchmark input changed')
    summary = evaluate_pairs(pairs, args.required_reduction)
    summary.update(pairs=pairs, pinned_sha256=pinned, fixture_sha256=fixture_hash,
                   cross_browser_pixels_exact=reference_comparison['exact'],
                   cross_browser_pixel_comparison=reference_comparison,
                   collector_environment={} if args.archive else {key: os.environ[key] for key in
                       ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR', 'GC_MARKERS']
                       if key in os.environ},
                   pass_scope=('instruction target and exact per-engine rendering stability'
                               if args.expected_vox else 'instruction target and cross-browser pixel parity'),
                   counter='proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions',
                   scope=__doc__, viewport=[1024, 768], url=args.url, page_javascript=False)
    (args.output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k not in ['pairs', 'pinned_sha256', 'scope']}), flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
