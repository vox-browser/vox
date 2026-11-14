#!/usr/bin/env python3
"""Measure per-keystroke latency in the live ChatGPT composer.

Launches a fresh Vox process with a private profile, waits for the composer,
then types TEXT with native key events at a fixed interval through the
injected driver (tools/js_engine_driver_darwin.m). For every key it records
the synchronous keyDown handling time and the delay until the page view's
layer next publishes new contents. Publication is the native frame boundary,
not physical scanout. Instruction and CPU counts cover the browser process
only (no script workers or adblock helper).

Run it inside the memory guard, for example:

    python3 tools/run_memory_bounded.py --limit-gib 3 --lock Build/typing.lock \\
        --report Build/typing-guard.json -- \\
      python3 tools/measure_chatgpt_typing.py --output Build/typing-1 --socks 127.0.0.1:1337

Extra environment variables for the browser (A/B switches such as
VOX_DISABLE_MEDIA_EVALUATION_MEMO=1) can be given with --env NAME=VALUE.
"""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from measure_chatgpt_engines import Driver, ORIGIN, URL  # noqa: E402

DEFAULT_TEXT = 'the quick brown fox jumps over the lazy dog'


def percentile(values, fraction):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(len(ordered) * fraction))]


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--app', type=Path, default=ROOT / 'Build/v/Vox.app')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--text', default=DEFAULT_TEXT)
    parser.add_argument('--interval-ms', type=float, default=120)
    parser.add_argument('--settle', type=float, default=6, help='seconds after the composer is ready')
    parser.add_argument('--load-timeout', type=float, default=90)
    parser.add_argument('--socks', help='HOST:PORT SOCKS proxy for chatgpt.com, stored in the private profile')
    parser.add_argument('--env', action='append', default=[], help='NAME=VALUE for the browser process')
    parser.add_argument('--sample', type=float, default=0,
                        help='also run /usr/bin/sample on the browser for this many seconds while typing')
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=False)
    control = args.output / 'control'
    control.mkdir()
    profile = args.output / 'profile'
    profile.mkdir()
    if args.socks:
        host, _, port = args.socks.rpartition(':')
        (profile / 'settings.json').write_text(json.dumps(
            {'enabled': True, 'host': host, 'port': port, 'sites': 'chatgpt.com'}))
    driver_library = args.output / 'js-engine-driver.dylib'
    subprocess.run(['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-dynamiclib', '-fobjc-arc',
                    str(ROOT / 'tools/js_engine_driver_darwin.m'), '-framework', 'Cocoa',
                    '-Wl,-undefined,dynamic_lookup', '-o', str(driver_library)], check=True)
    environment = {k: v for k, v in os.environ.items()
                   if k.lower() not in {'all_proxy', 'http_proxy', 'https_proxy'}}
    environment.update(VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(profile))
    for item in args.env:
        name, _, value = item.partition('=')
        environment[name] = value
    # /usr/bin/env applies DYLD_INSERT_LIBRARIES to the Vox exec itself.
    command = ['/usr/bin/env', 'DYLD_INSERT_LIBRARIES=' + str(driver_library.resolve()),
               'VOX_JS_DRIVER_DIR=' + str(control.resolve()), 'VOX_JS_DRIVER_ORIGIN=' + ORIGIN,
               str((args.app / 'Contents/MacOS/Vox').resolve()), '--window-width=1024',
               '--window-height=880', URL]
    log = (args.output / 'browser.log').open('wb')
    process = subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
    driver = Driver(control)
    result = dict(command=command, env=args.env, interval_ms=args.interval_ms, text=args.text,
                  load_before=os.getloadavg(), failure=None)
    try:
        driver.wait('window', 60)
        deadline = time.monotonic() + args.load_timeout
        ready = False
        while time.monotonic() < deadline and not ready:
            _, state, _ = driver.state()
            ready = bool(state and state['ready'] == 'complete' and state['editor'] and state['marker'] == '1')
            time.sleep(0.2)
        if not ready:
            raise RuntimeError('ChatGPT composer did not become ready')
        time.sleep(args.settle)
        driver.request('eval', "(() => { const e = document.querySelector('#prompt-textarea') ||"
                       " document.querySelector('textarea, [contenteditable=true]'); e && e.focus(); return 'ok' })()")
        sampler = None
        if args.sample > 0:
            pid = driver.request('pid')['result']['pid']
            sampler = subprocess.Popen(['/usr/bin/sample', str(pid), '%g' % args.sample, '1', '-file',
                                        str(args.output / 'sample.txt')],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        before = driver.request('usage')['result']
        response = driver.request('typelat', '%g\n%s' % (args.interval_ms, args.text), timeout=600)['result']
        after = driver.request('usage')['result']
        if sampler:
            sampler.wait()
        if 'rows' not in response:
            raise RuntimeError('driver: %s' % response)
        rows = response['rows']
        _, state, _ = driver.state()
        composer = (state or {}).get('composer', '').strip()
        if composer != args.text:
            raise RuntimeError('Composer text differs from the typed text: %r' % composer)
        handled = [row['handled'] * 1e3 for row in rows]
        present = [row['present'] * 1e3 for row in rows if 'present' in row]
        result.update(
            keys=len(rows), rows=rows,
            handled_ms=dict(median=statistics.median(handled), p90=percentile(handled, .9), max=max(handled)),
            present_ms=dict(median=statistics.median(present), p90=percentile(present, .9), max=max(present)),
            missing_publications=len(rows) - len(present),
            instructions_per_key=(after['instructions'] - before['instructions']) / len(rows),
            cpu_ms_per_key=(after['user_seconds'] - before['user_seconds'] + after['system_seconds']
                            - before['system_seconds']) / len(rows) * 1e3)
    except Exception as error:  # Record and keep the attempt.
        result['failure'] = '%s: %s' % (type(error).__name__, error)
    finally:
        try:
            driver.request('quit', timeout=5)
        except Exception:
            pass
        try:
            process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        log.close()
        result['exit'] = process.returncode
        result['load_after'] = os.getloadavg()
        (args.output / 'result.json').write_text(json.dumps(result, indent=1))
    print(json.dumps({k: v for k, v in result.items() if k not in ('rows', 'command')}, indent=1))
    if result['failure']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
