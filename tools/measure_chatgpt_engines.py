#!/usr/bin/env python3
"""Compare live ChatGPT load and prompt-response times between Vox JS engines.

Each trial launches a fresh browser process with an empty private profile,
waits for the composer, types the prompt with native key events, presses
Return and waits for the assistant's answer. Trials alternate between the
bundles so host load and service variation affect both engines alike.

Times come from the injected driver (tools/js_engine_driver_darwin.m) and are
seconds since the browser process started. Hardware counters cover the
browser process only (no worker or adblock helper processes).
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://chatgpt.com/'
ORIGIN = 'https://chatgpt.com'

STATE = r"""(() => {
  const editor = document.querySelector('#prompt-textarea') || document.querySelector('textarea, [contenteditable=true]');
  // Geometry forces layout; avoid it while the document is still loading.
  const rect = editor && document.readyState === 'complete' ? editor.getBoundingClientRect() : null;
  const messages = role => [...document.querySelectorAll('[data-message-role="' + role + '"], [data-message-author-role="' + role + '"]')];
  const text = role => messages(role).map(node => node.textContent).join('\n');
  const answers = messages('assistant');
  const navigation = (performance.getEntriesByType && performance.getEntriesByType('navigation')[0]) || null;
  return JSON.stringify({
    href: location.href, title: document.title, ready: document.readyState,
    editor: !!(rect && rect.width > 0 && rect.height > 0),
    composer: editor ? (editor.value !== undefined ? editor.value : editor.textContent) : '',
    marker: document.documentElement.dataset.octaneHomeBehaviorReady || null,
    user: text('user').slice(0, 300), assistant: text('assistant').slice(0, 600),
    // The answer is complete when its message carries data-message-complete.
    stop: answers.length > 0 && !answers[answers.length - 1].hasAttribute('data-message-complete')
        || !!document.querySelector('[data-testid="stop-button"]'),
    body: document.body ? String(document.body.textContent || '').slice(0, 300) : '',
    navigation: navigation ? {dcl: navigation.domContentLoadedEventEnd, load: navigation.loadEventEnd} : null,
  });
})()"""


def sha256(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


class Driver:
    def __init__(self, directory):
        self.directory = directory
        self.count = 0

    def wait(self, identifier, timeout):
        path = self.directory / ('res-' + identifier)
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if path.exists():
                return json.loads(path.read_text())
            time.sleep(0.005)
        raise TimeoutError('driver response ' + identifier)

    def request(self, command, payload='', timeout=20):
        self.count += 1
        identifier = '%06d' % self.count
        temporary = self.directory / ('req-%s.tmp' % identifier)
        temporary.write_text(command + '\n' + payload)
        temporary.rename(self.directory / ('req-' + identifier))
        return self.wait(identifier, timeout)

    def state(self):
        response = self.request('eval', STATE)
        result = response['result']
        if 'value' not in result:
            return response['t'], None, result
        return response['t'], json.loads(result['value']), None


def first(samples, predicate):
    return next((t for t, state in samples if state and predicate(state)), None)


def run_trial(args, engine, app, output):
    output.mkdir(parents=True)
    control = output / 'control'
    control.mkdir()
    profile = output / 'profile'
    profile.mkdir()
    executable = app / 'Contents/MacOS/Vox'
    environment = {k: v for k, v in os.environ.items() if k.lower() not in
                   {'all_proxy', 'http_proxy', 'https_proxy'}}
    environment.update(VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(profile))
    if args.proxy:
        environment['VOX_PROXY'] = args.proxy
    command = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
               '--lock', str(output / 'guard.lock'), '--report', str(output / 'guard.json'), '--',
               '/usr/bin/env', 'DYLD_INSERT_LIBRARIES=' + str(args.driver),
               'VOX_JS_DRIVER_DIR=' + str(control), 'VOX_JS_DRIVER_ORIGIN=' + ORIGIN,
               str(executable), '--window-width=1024', '--window-height=880', URL]
    load = os.getloadavg()
    row = dict(engine=engine, command=command, load_before=load, started=time.time(), failure=None)
    log = (output / 'browser.log').open('wb')
    process = subprocess.Popen(command, env=environment, stdout=log, stderr=subprocess.STDOUT)
    driver = Driver(control)
    samples = []
    try:
        row['window'] = driver.wait('window', 60)['t']
        deadline = time.monotonic() + args.load_timeout
        ready = None
        while time.monotonic() < deadline:
            t, state, error = driver.state()
            samples.append((t, state))
            if state and state['ready'] == 'complete' and state['editor'] and ready is None:
                ready = t
            if ready is not None and (state and state['marker'] == '1' or t - ready > args.marker_timeout):
                break
            time.sleep(args.poll)
        if ready is None:
            raise RuntimeError('ChatGPT composer did not become ready')
        row['times'] = dict(
            first_probe=samples[0][0],
            dom_complete=first(samples, lambda s: s['ready'] == 'complete'),
            editor=first(samples, lambda s: s['editor']),
            ready=ready,
            marker=first(samples, lambda s: s['marker'] == '1'))
        last = samples[-1][1] or {}
        row['navigation_timing'] = last.get('navigation')
        settle_until = time.monotonic() + args.settle
        while time.monotonic() < settle_until:
            time.sleep(args.poll)
        row['usage_ready'] = driver.request('usage')['result']
        # The composer can be re-rendered between focusing and typing. Retry
        # with a fresh focus; every attempt precedes the measured submission.
        row['typing_attempts'] = 0
        typed = False
        while not typed and row['typing_attempts'] < 3:
            row['typing_attempts'] += 1
            driver.request('eval', "(() => { const e = document.querySelector('#prompt-textarea') ||"
                           " document.querySelector('textarea, [contenteditable=true]'); e && e.focus(); return 'ok' })()")
            row['times']['type'] = driver.request('type', args.prompt, timeout=30)['t']
            typed_deadline = time.monotonic() + 3
            while time.monotonic() < typed_deadline:
                t, state, _ = driver.state()
                samples.append((t, state))
                composer = state['composer'].strip() if state else ''
                if composer == args.prompt:
                    typed = True
                    break
                if composer:
                    raise RuntimeError('Composer text differs from the prompt: %r' % composer)
                time.sleep(args.poll)
        if not typed:
            raise RuntimeError('Typed prompt did not reach the composer')
        row['usage_submit'] = driver.request('usage')['result']
        row['times']['submit'] = driver.request('type', '\r')['t']
        answer_deadline = time.monotonic() + args.answer_timeout
        while time.monotonic() < answer_deadline:
            t, state, _ = driver.state()
            samples.append((t, state))
            if state and 'Rome' in state['assistant'] and not state['stop']:
                break
            if state and ('unusual activity' in state['body'].lower() or 'something went wrong' in state['body'].lower()):
                raise RuntimeError('Service refused the query: ' + state['body'][:200])
            time.sleep(args.poll)
        after = [(t, s) for t, s in samples if t >= row['times']['submit']]
        row['times']['user_message'] = first(after, lambda s: args.prompt in s['user'])
        row['times']['assistant_text'] = first(after, lambda s: s['assistant'].strip() != '')
        row['times']['rome'] = first(after, lambda s: 'Rome' in s['assistant'])
        row['times']['answer_complete'] = first(after, lambda s: 'Rome' in s['assistant'] and not s['stop'])
        if row['times']['rome'] is None:
            raise RuntimeError('No answer containing Rome')
        row['answer'] = samples[-1][1]['assistant']
        row['conversation_url'] = samples[-1][1]['href']
        row['usage_end'] = driver.request('usage')['result']
        row['submit_to_rome'] = row['times']['rome'] - row['times']['submit']
        row['launch_to_ready'] = ready
    except Exception as error:  # Record and keep the attempt.
        row['failure'] = '%s: %s' % (type(error).__name__, error)
        if samples and samples[-1][1]:
            row['last_state'] = samples[-1][1]
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
        row['exit'] = process.returncode
        row['load_after'] = os.getloadavg()
        (output / 'samples.json').write_text(json.dumps(samples))
        (output / 'row.json').write_text(json.dumps(row, indent=1))
    return row


def summarize(rows):
    summary = {}
    for engine in sorted({row['engine'] for row in rows}):
        good = [row for row in rows if row['engine'] == engine and not row['failure']]
        entry = dict(trials=len([r for r in rows if r['engine'] == engine]), successful=len(good))
        for name, value in [('launch_to_ready', lambda r: r['launch_to_ready']),
                            ('launch_to_dom_complete', lambda r: r['times']['dom_complete']),
                            ('launch_to_bootstrap_marker', lambda r: r['times']['marker']),
                            ('submit_to_user_message', lambda r: r['times']['user_message'] and
                             r['times']['user_message'] - r['times']['submit']),
                            ('submit_to_first_assistant_text', lambda r: r['times']['assistant_text'] and
                             r['times']['assistant_text'] - r['times']['submit']),
                            ('submit_to_rome', lambda r: r['submit_to_rome']),
                            ('ready_instructions', lambda r: r['usage_ready']['instructions']),
                            ('query_instructions', lambda r: r['usage_end']['instructions'] - r['usage_submit']['instructions']),
                            ('ready_cpu_seconds', lambda r: r['usage_ready']['user_seconds'] + r['usage_ready']['system_seconds']),
                            ('peak_footprint_mib', lambda r: r['usage_end']['peak_footprint_bytes'] / 2**20)]:
            values = [v for v in (value(r) for r in good) if v is not None]
            if values:
                entry[name] = dict(median=statistics.median(values), min=min(values), max=max(values),
                                   values=values)
        summary[engine] = entry
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', action='append', required=True, metavar='NAME=PATH',
                        help='Engine label and Vox.app bundle; give two or more')
    parser.add_argument('--driver', type=Path,
                        help='Prebuilt tools/js_engine_driver_darwin.m dylib (default: compile it)')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=3)
    parser.add_argument('--prompt', default='capital of italy')
    parser.add_argument('--proxy', default='socks5h://127.0.0.1:1337')
    parser.add_argument('--poll', type=float, default=0.1)
    parser.add_argument('--settle', type=float, default=5)
    parser.add_argument('--marker-timeout', type=float, default=20,
                        help='Seconds after readiness to wait for the author bootstrap marker')
    parser.add_argument('--load-timeout', type=float, default=120)
    parser.add_argument('--answer-timeout', type=float, default=90)
    args = parser.parse_args()
    apps = []
    for item in args.app:
        name, _, path = item.partition('=')
        apps.append((name, Path(path).resolve()))
    args.output.mkdir(parents=True, exist_ok=False)
    if args.driver is None:
        # One driver serves both engines: it binds the JavaScript C API that
        # the browser process loaded (JavaScriptCore or libVoxJSCOnV8).
        args.driver = args.output / 'js-engine-driver.dylib'
        subprocess.run(['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-dynamiclib', '-fobjc-arc',
                        str(ROOT / 'tools/js_engine_driver_darwin.m'), '-framework', 'Cocoa',
                        '-Wl,-undefined,dynamic_lookup', '-o', str(args.driver)], check=True)
    args.driver = args.driver.resolve()
    pins = {str(p): sha256(p) for _, app in apps for p in sorted(app.rglob('*')) if p.is_file()}
    pins[str(args.driver)] = sha256(args.driver)
    (args.output / 'inputs.json').write_text(json.dumps(dict(files=pins, apps={n: str(a) for n, a in apps},
        prompt=args.prompt, url=URL, proxy=args.proxy, host_cpus=os.cpu_count()), indent=1))
    rows = []
    for index in range(args.pairs):
        order = apps if index % 2 == 0 else list(reversed(apps))
        for name, app in order:
            row = run_trial(args, name, app, args.output / ('pair-%d-%s' % (index + 1, name)))
            rows.append(row)
            print(json.dumps({k: row.get(k) for k in ['engine', 'failure', 'exit', 'launch_to_ready',
                              'submit_to_rome', 'times', 'load_before']}), flush=True)
            current = {str(p): sha256(p) for _, a in apps for p in sorted(a.rglob('*')) if p.is_file()}
            current[str(args.driver)] = sha256(args.driver)
            if current != pins:
                raise RuntimeError('Measured bundles changed during the cohort')
    summary = summarize(rows)
    (args.output / 'rows.json').write_text(json.dumps(rows, indent=1))
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=1))
    print(json.dumps(summary, indent=1))


if __name__ == '__main__':
    main()
