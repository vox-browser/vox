#!/usr/bin/env python3
"""Compare current physical footprints of isolated browser process trees."""

import argparse
import base64
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile
import threading
import time
import urllib.request

from measure_browser_instructions import (
    VOX_CHROME_HEIGHT,
    CDP, chrome_debugger_endpoint, crop_document_viewport, fresh_vox_cache, stop_process,
)
from process_instruction_counts import CounterSampler, MacCounters, RusageInfoV4

REPO = Path(__file__).resolve().parents[1]


def activate_browser(pid):
    # Address the isolated process, preserving other browser profiles.
    script = f'''ObjC.import("AppKit");
        const app=$.NSRunningApplication.runningApplicationWithProcessIdentifier({pid});
        const found=Number(app.processIdentifier)===Number({pid});
        const before=found&&Boolean(app.active);
        if(found&&!before) {{ app.activateWithOptions(2); delay(0.2); }}
        JSON.stringify({{pid:Number(app.processIdentifier),was_active:before,
            active:found&&Boolean(app.active)}});'''
    return json.loads(subprocess.check_output(['osascript', '-l', 'JavaScript', '-e', script], text=True))


class ForegroundControl:
    def __init__(self, pid, enabled, start_at=0, inspect=None):
        self.pid, self.enabled = pid, enabled
        self.next_check = start_at
        self.inspect = inspect or activate_browser
        self.checks = []

    def poll(self, elapsed, force=False):
        if not self.enabled or (not force and elapsed < self.next_check):
            return
        self.checks.append(dict(self.inspect(self.pid), seconds=elapsed))
        self.next_check = elapsed + 1

    def verify_steady(self, endpoint, window=2):
        if not self.enabled:
            return None
        start = endpoint - window
        before = [row for row in self.checks if row['seconds'] <= start]
        recent = [row for row in self.checks if start < row['seconds'] <= endpoint]
        if not before or not recent or endpoint - recent[-1]['seconds'] > 1.5:
            raise RuntimeError('Insufficient foreground checks around the settled memory window')
        if any(not row['active'] or not row['was_active'] for row in [before[-1], *recent]):
            raise RuntimeError('Browser lost foreground focus around the settled memory window')
        return [start, endpoint]

    def activation_at(self, endpoint):
        return next((row for row in reversed(self.checks)
                     if row['seconds'] <= endpoint and row['active']), None)


def summarize_samples(samples, endpoint, window=1):
    live = [s for s in samples if s['processes'] and s['seconds'] <= endpoint]
    steady = [s for s in live if endpoint - window <= s['seconds'] <= endpoint]
    if len(steady) < 5:
        raise RuntimeError('Insufficient settled memory samples')
    return {
        'steady_bytes': statistics.median(s['bytes'] for s in steady),
        'steady_range_bytes': [min(s['bytes'] for s in steady), max(s['bytes'] for s in steady)],
        'peak_simultaneous_bytes': max(s['bytes'] for s in live),
        'steady_window_seconds': [endpoint - window, endpoint],
        'steady_samples': len(steady),
        'processes_at_endpoint': steady[-1]['processes'],
    }


class TreeMemory:
    def __init__(self, root, started):
        self.api = MacCounters()
        self.root = root
        self.started = started
        self.samples = []
        self.lock = threading.Lock()

    def sample(self):
        with self.lock:
            pending, seen, processes, missing = [self.root], set(), [], []
            while pending:
                pid = pending.pop()
                if pid in seen:
                    continue
                seen.add(pid)
                usage = RusageInfoV4()
                if self.api.lib.proc_pid_rusage(pid, 4, ctypes.byref(usage)):
                    code = ctypes.get_errno()
                    if code not in (errno.ESRCH, errno.ENOENT):
                        raise OSError(code, os.strerror(code), str(pid))
                    missing.append(pid)
                    continue
                if usage.ri_proc_exit_abstime:
                    continue
                processes.append({'pid': pid, 'start_ticks': usage.ri_proc_start_abstime,
                                  'bytes': usage.ri_phys_footprint, 'rss': usage.ri_resident_size,
                                  'path': self.api.path(pid)})
                pending.extend(self.api.children(pid))
            self.samples.append({'seconds': time.monotonic() - self.started,
                                 'bytes': sum(p['bytes'] for p in processes),
                                 'processes': processes, 'vanished_during_sample': missing})


def measure_vox(args, prefix):
    window, screenshot = Path(str(prefix) + '.window.png'), Path(str(prefix) + '.png')
    log_path = Path(str(prefix) + '.log')
    runtime_paths = {'avif_library': args.binary.parent / 'libVoxAVIF.dylib',
                     'snapshot_payload': args.binary.parent.parent / 'Resources/adblock.snapshot.bin'}
    runtime_files = {key: {'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                     for key, path in runtime_paths.items() if path.is_file()}
    with fresh_vox_cache(args.cache_template, args.output) as (cache, digest):
        if cache:
            shutil.rmtree(cache / 'snapshots', ignore_errors=True)
        env = dict(os.environ, LADYBIRD_DEBUG_TIMING='1',
                   LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle + 1))
        if cache:
            env['LADYBIRD_CACHE_DIR'] = str(cache)
        for key in ('LADYBIRD_ENABLE_SNAPSHOT_CACHE', 'GC_PRINT_STATS'):
            env.pop(key, None)
        if args.diagnostic_library:
            env['DYLD_INSERT_LIBRARIES'] = str(args.diagnostic_library.resolve())
        command = [str(args.binary), *args.vox_arg, '--window-width', str(args.width),
                   '--window-height', str(args.height + VOX_CHROME_HEIGHT), '--screenshot', str(window), args.url]
        with log_path.open('w') as log:
            started = time.monotonic()
            process = subprocess.Popen(command, cwd=REPO, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            counter = TreeMemory(process.pid, started)
            saved_at = None
            foreground = ForegroundControl(process.pid, args.foreground, start_at=1)
            try:
                with CounterSampler(counter, args.interval):
                    while process.poll() is None:
                        elapsed = time.monotonic() - started
                        foreground.poll(elapsed)
                        if saved_at is None and 'Saved Ladybird V window screenshot:' in log_path.read_text():
                            saved_at = time.monotonic() - started
                        if time.monotonic() - started > args.timeout:
                            raise RuntimeError('Vox capture timed out')
                        time.sleep(.02)
                    if saved_at is None and window.is_file():
                        saved_at = time.monotonic() - started
            finally:
                stop_process(process)
        if process.returncode or saved_at is None or not window.is_file():
            raise RuntimeError(f'Vox capture failed; see {log_path}')
        # Leave one second between the settled window and PNG capture.
        endpoint = saved_at - 1
        foreground_window = foreground.verify_steady(endpoint)
        summary = summarize_samples(counter.samples, endpoint)
        for key, record in runtime_files.items():
            if hashlib.sha256(runtime_paths[key].read_bytes()).hexdigest() != record['sha256']:
                raise RuntimeError('Browser runtime input changed: ' + key)
        crop_document_viewport(window, screenshot, args.width, args.height)
        return {'command': command, 'cache_digest': digest, 'memory': summary,
                'activation': foreground.activation_at(endpoint),
                'foreground_checks': foreground.checks,
                'foreground_steady_verified': foreground_window is not None,
                'foreground_verified_window_seconds': foreground_window,
                'runtime_files': runtime_files,
                'collector_overrides': {k: v for k, v in env.items() if k.startswith('GC_')},
                'runtime_overrides': {k: v for k, v in env.items() if k.startswith('JSC_')},
                'samples': counter.samples, 'screenshot': str(screenshot)}


def measure_chrome(args, prefix):
    log_path, screenshot = Path(str(prefix) + '.log'), Path(str(prefix) + '.png')
    with tempfile.TemporaryDirectory(prefix='chrome-profile-', dir=args.output) as profile:
        # Use the actual GUI browser and retain the GPU and utility processes.
        command = [str(args.binary), '--no-first-run', '--no-default-browser-check',
                   '--disable-background-networking', '--remote-debugging-port=0',
                   f'--user-data-dir={profile}', f'--window-size={args.width},{args.height + 143}',
                   'about:blank']
        with log_path.open('w') as log:
            started = time.monotonic()
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            counter = TreeMemory(process.pid, started)
            foreground = ForegroundControl(process.pid, args.foreground)
            client = None
            try:
                with CounterSampler(counter, args.interval):
                    active = Path(profile) / 'DevToolsActivePort'
                    while not (endpoint := chrome_debugger_endpoint(active)):
                        if process.poll() is not None or time.monotonic() - started > args.timeout:
                            raise RuntimeError(f'Chrome debugger unavailable; see {log_path}')
                        time.sleep(.02)
                    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                    with http.open(f'http://127.0.0.1:{endpoint[0]}/json/list') as response:
                        targets = json.load(response)
                    client = CDP(next(t['webSocketDebuggerUrl'] for t in targets if t['type'] == 'page'))
                    version = client.call('Browser.getVersion')
                    client.call('Page.enable')
                    if args.foreground:
                        client.call('Page.bringToFront')
                        foreground.poll(time.monotonic() - started)
                        if not foreground.activation_at(time.monotonic() - started):
                            raise RuntimeError('Chrome did not become the foreground application')
                    client.call('Emulation.setDeviceMetricsOverride', {
                        'width': args.width, 'height': args.height, 'deviceScaleFactor': args.device_scale, 'mobile': False})
                    client.call('Page.navigate', {'url': args.url})
                    while True:
                        result = client.call('Runtime.evaluate', {'expression':
                            'JSON.stringify({ready:document.readyState,text:document.body?.innerText.length||0})',
                            'returnByValue': True})
                        document = json.loads(result.get('result', {}).get('value') or '{}')
                        if document.get('ready') == 'complete' and document.get('text', 0):
                            break
                        if time.monotonic() - started > args.timeout:
                            raise RuntimeError('Chrome document did not become ready')
                        time.sleep(.02)
                    client.call('Runtime.evaluate', {'expression': 'document.fonts.ready.then(()=>true)',
                                                     'awaitPromise': True, 'returnByValue': True})
                    settled_at = time.monotonic()
                    while time.monotonic() - settled_at < args.settle:
                        foreground.poll(time.monotonic() - started)
                        time.sleep(.02)
                    foreground.poll(time.monotonic() - started, force=True)
                    endpoint_at = time.monotonic() - started
                    foreground_window = foreground.verify_steady(endpoint_at)
                    summary = summarize_samples(counter.samples, endpoint_at)
                    audit = client.call('Runtime.evaluate', {'expression':
                        'JSON.stringify({title:document.title,url:location.href,width:innerWidth,height:innerHeight,'
                        'textLength:document.body.innerText.length,scale:devicePixelRatio,focused:document.hasFocus(),visibility:document.visibilityState,sprites:document.querySelectorAll(".sprite").length})',
                        'returnByValue': True})
                    targets_audit = client.call('Target.getTargets')
                    document = json.loads(audit['result']['value'])
                    if args.foreground and (not document['focused'] or document['visibility'] != 'visible'):
                        raise RuntimeError('Chrome document lost focus before capture')
                    pixels = client.call('Page.captureScreenshot', {'format': 'png', 'captureBeyondViewport': False})
                    screenshot.write_bytes(base64.b64decode(pixels['data']))
                    client.call('Browser.close')
            finally:
                if client:
                    client.sock.close()
                stop_process(process)
        return {'command': command, 'version': version, 'document': document,
                'activation': foreground.activation_at(endpoint_at),
                'foreground_checks': foreground.checks,
                'foreground_steady_verified': foreground_window is not None,
                'foreground_verified_window_seconds': foreground_window,
                'targets': targets_audit,
                'memory': summary, 'samples': counter.samples, 'screenshot': str(screenshot)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', choices=['vox', 'chrome'], required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--url', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--label', required=True)
    parser.add_argument('--cache-template', type=Path)
    parser.add_argument('--vox-arg', action='append', default=[])
    parser.add_argument('--repeat', type=int, default=1)
    parser.add_argument('--settle', type=float, default=15)
    parser.add_argument('--interval', type=float, default=.02)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=768)
    parser.add_argument('--device-scale', type=float, default=2,
                        help='Chrome raster scale; match the native Vox window backing scale')
    parser.add_argument('--diagnostic-library', type=Path,
                        help='Vox-only instrumentation; excluded from normal comparison runs')
    parser.add_argument('--foreground', action='store_true',
                        help='Activate the isolated browser before settling')
    args = parser.parse_args()
    if args.settle < 3 or args.interval <= 0 or args.repeat < 1:
        parser.error('settle must be at least three seconds; repeat and interval must be positive')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    args.binary = args.binary.resolve()
    native_scale = float(subprocess.check_output([
        'osascript', '-l', 'JavaScript', '-e',
        'ObjC.import("AppKit"); String($.NSScreen.mainScreen.backingScaleFactor)',
    ], text=True).strip())
    fingerprint = hashlib.sha256(args.binary.read_bytes()).hexdigest()
    for index in range(1, args.repeat + 1):
        prefix = args.output / f'{args.label}-{index}'
        path = Path(str(prefix) + '.json')
        if path.exists():
            raise RuntimeError(f'Preserve prior measurement: {path}')
        result = (measure_vox if args.engine == 'vox' else measure_chrome)(args, prefix)
        if hashlib.sha256(args.binary.read_bytes()).hexdigest() != fingerprint:
            raise RuntimeError('Browser executable changed during measurement')
        result.update(engine=args.engine, url=args.url, binary_sha256=fingerprint, viewport=[args.width, args.height],
                      foreground_controlled=args.foreground,
                      settle_seconds=args.settle, metric='sum of simultaneous process physical footprints',
                      native_display_backing_scale=native_scale,
                      chrome_device_scale=args.device_scale if args.engine == 'chrome' else None,
                      matched_native_raster_scale=args.engine == 'vox' or args.device_scale == native_scale)
        result['diagnostic_library'] = (str(args.diagnostic_library) if args.diagnostic_library
                                        else os.environ.get('DYLD_INSERT_LIBRARIES'))
        path.write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'label': args.label, 'sample': index, 'memory': result['memory']}), flush=True)


if __name__ == '__main__':
    main()
