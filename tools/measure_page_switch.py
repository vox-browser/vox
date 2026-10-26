#!/usr/bin/env python3
"""Measure one native address navigation, with fast page switching on or off.

Run alternating matched trials under tools/run_memory_bounded.py. The endpoint
is a changed Cocoa layer publication after updateLayer with the target title,
not physical display scanout. Captures retain the first and settled frames for
pixel validation. Use --diagnostic separately from timed acceptance trials.
"""
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
from urllib.parse import urlsplit

REPO = Path(__file__).resolve().parents[1]
ENDPOINT = 'native address submission to changed Cocoa layer contents after updateLayer with target title; not physical scanout'


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--from-url', required=True)
    parser.add_argument('--to-url', required=True)
    parser.add_argument('--from-title', required=True)
    parser.add_argument('--to-title', required=True)
    parser.add_argument('--mode', choices=['off', 'on'], required=True)
    parser.add_argument('--diagnostic', action='store_true')
    parser.add_argument('--cache-template', type=Path)
    parser.add_argument('--network-policy', required=True)
    parser.add_argument('--proxy', help='SOCKS5 replay or live route; uses a private settings profile')
    parser.add_argument('--ca', type=Path, help='Process-local replay certificate')
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=768, help='Document viewport height without chrome')
    parser.add_argument('--settle-seconds', type=float, default=4)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Requires macOS')
    if args.width <= 0 or args.height <= 0 or not 0 <= args.settle_seconds <= 60:
        parser.error('Invalid viewport or settle period')
    binary, output = args.binary.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source = REPO/'tools/measure_page_switch_darwin.m'
    probe = output/'page-switch.dylib'
    compile_command = ['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-dynamiclib',
                       '-fobjc-arc', str(source), '-framework', 'Cocoa',
                       '-framework', 'QuartzCore', '-o', str(probe)]
    with (output/'compile.log').open('w') as log:
        subprocess.run(compile_command, stdout=log, stderr=subprocess.STDOUT, check=True)
    cache, profile = output/'cache', output/'profile'
    if args.cache_template:
        shutil.copytree(args.cache_template, cache)
    else:
        cache.mkdir()
    shutil.rmtree(cache/'snapshots', ignore_errors=True)
    cache_digest = hashlib.sha256()
    for path in sorted(cache.rglob('*')):
        if path.is_file():
            cache_digest.update(str(path.relative_to(cache)).encode()+b'\0'+path.read_bytes())
    profile.mkdir()
    settings = dict(experimental_fast_page_switch=args.mode == 'on', enabled=False)
    if args.proxy:
        proxy = urlsplit(args.proxy)
        if proxy.scheme not in {'socks5', 'socks5h'} or not proxy.hostname or not proxy.port or proxy.username:
            parser.error('--proxy requires a SOCKS5 hostname and port')
        settings.update(enabled=True, host=proxy.hostname, port=str(proxy.port), sites='')
    (profile/'settings.json').write_text(json.dumps(settings)+'\n')
    env = dict(os.environ)
    for name in list(env):
        if name.startswith(('VOX_', 'LADYBIRD_', 'DYLD_')) or name.lower() in {
                'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy', 'ssl_cert_file'}:
            env.pop(name)
    env.update(VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache),
               DYLD_LIBRARY_PATH=str(binary.parent), DYLD_INSERT_LIBRARIES=str(probe),
               VOX_SWITCH_FROM=args.from_url, VOX_SWITCH_TO=args.to_url,
               VOX_SWITCH_FROM_TITLE=args.from_title, VOX_SWITCH_TO_TITLE=args.to_title,
               VOX_SWITCH_OUTPUT=str(output), VOX_SWITCH_SETTLE=str(args.settle_seconds))
    if args.ca:
        env['SSL_CERT_FILE'] = str(args.ca.resolve())
    if args.diagnostic:
        env['VOX_PAGE_SWITCH_DIAGNOSTICS'] = '1'
    pinned = [binary, *sorted(binary.parent.glob('*.dylib')), source, probe, Path(__file__).resolve()]
    if args.ca:
        pinned.append(args.ca.resolve())
    hashes = {str(path): sha256(path) for path in pinned}
    command = [str(binary), '--enable-javascript', '--window-width', str(args.width),
               '--window-height', str(args.height+84), args.from_url]
    evidence = dict(endpoint=ENDPOINT, mode=args.mode, diagnostic=args.diagnostic,
                    command=command, compile_command=compile_command, source_and_binary_sha256=hashes,
                    cache_sha256=cache_digest.hexdigest(), initial_settings=settings,
                    profile_policy='fresh private profile per trial', viewport=[args.width,args.height],
                    network_policy=args.network_policy, settle_seconds=args.settle_seconds,
                    settle_basis='matching source document title', started_unix=time.time(),
                    host=dict(cpu_count=os.cpu_count(), load_average_before=list(os.getloadavg())))
    try:
        with (output/'browser.log').open('w') as log:
            child = subprocess.Popen(command, cwd=REPO, env=env, stdout=log, stderr=subprocess.STDOUT)
            evidence['pid'] = child.pid
            try:
                code = child.wait(timeout=100)
            except subprocess.TimeoutExpired:
                child.kill()
                evidence['browser_exit_code'] = child.wait()
                raise RuntimeError('Browser timeout')
        evidence['browser_exit_code'] = code
        text = (output/'browser.log').read_text(errors='replace')
        if code or 'PAGE_SWITCH_ERROR' in text or text.count('PAGE_SWITCH_DONE') != 1:
            raise RuntimeError(f'Invalid browser completion, exit {code}; inspect browser.log')
        starts = [line for line in text.splitlines() if line.startswith('PAGE_SWITCH_START ')]
        results = [line for line in text.splitlines() if line.startswith('PAGE_SWITCH_RESULT ')]
        if len(starts) != 1 or len(results) != 1 or args.from_title not in starts[0] or args.to_title not in results[0]:
            raise RuntimeError('Missing matching source/target publication')
        numbers = dict(re.findall(r'(navigation_ms|callback_ms|scale|width|height|submitted_s|published_s)=([\d.]+)', results[0]))
        evidence.update({key: float(value) for key,value in numbers.items()})
        if len(numbers) != 7:
            raise RuntimeError('Incomplete native timing record')
        if evidence['width'] != args.width or evidence['height'] != args.height+84:
            raise RuntimeError('Native viewport differs from requested geometry')
        evidence['captures_sha256'] = {name:sha256(output/name) for name in ['hot.png','first-new.png','settled-new.png']}
        if hashes != {str(path):sha256(path) for path in pinned}:
            raise RuntimeError('Build or probe identity changed during trial')
        evidence.update(valid=True, start=starts[0], publication=results[0])
        print(json.dumps({key:evidence[key] for key in ['mode','diagnostic','navigation_ms','callback_ms','scale','valid']}), flush=True)
    except Exception as error:
        evidence.update(valid=False, error=str(error))
        raise
    finally:
        evidence['finished_unix'] = time.time()
        evidence['host']['load_average_after'] = list(os.getloadavg())
        (output/'run.json').write_text(json.dumps(evidence, indent=2)+'\n')


if __name__ == '__main__':
    main()
