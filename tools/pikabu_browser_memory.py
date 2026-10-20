#!/usr/bin/env python3
"""Compare foreground Vox/Brave process-tree memory on frozen Pikabu responses.

Both browsers execute author JavaScript. Primary memory is the simultaneous
sum of macOS physical footprints, including GPU and utility descendants. Brave
uses a fresh profile with its default Shields; no extensions are installed.
Vox runs without screenshot mode, which marks the translated document inactive.
"""
import argparse
import base64
import json
from pathlib import Path
import re
import select
import shutil
import statistics
import struct
import subprocess
import tempfile
import time
import urllib.request

from compare_browser_memory import ForegroundControl
from measure_browser_instructions import chrome_debugger_endpoint, stop_process
from pikabu_browser_instructions import (
    DOC_STATE, PikabuReplayCDP, clone_file, digest, fingerprint_tree, frozen_response,
)
from process_instruction_counts import CounterSampler
from wikipedia_browser_memory import PhysicalTree, clean_environment, placement, summarize

REPO = Path(__file__).resolve().parents[1]
URL = 'https://pikabu.ru/'


def runtime_identity(binary):
    files = [binary, *sorted(binary.parent.glob('*.dylib'))]
    snapshot = binary.parent.parent / 'Resources/adblock.snapshot.bin'
    if snapshot.is_file():
        files.append(snapshot)
    return {str(path): digest(path) for path in files}


def crop_native_document(window, target, document):
    header = window.read_bytes()[:24]
    if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
        raise RuntimeError('Invalid native endpoint image')
    width, height = struct.unpack('!II', header[16:24])
    logical_width, logical_height = document['viewport_width'], document['viewport_height']
    scale = width // logical_width
    if scale < 1 or width % logical_width or height != (logical_height + 84) * scale:
        raise RuntimeError('Native endpoint image does not contain the measured viewport')
    subprocess.run(['sips', '--cropToHeightWidth', str(logical_height * scale), str(width),
                    '--cropOffset', str(60 * scale), '0', str(window), '--out', str(target)],
                   check=True, stdout=subprocess.DEVNULL)


def memory_result(counter, endpoint):
    result = summarize(counter.samples, endpoint, window=2)
    idle = [row for row in counter.samples if endpoint / 2 <= row['seconds'] <= endpoint]
    times = [row['seconds'] for row in idle]
    values = [row['physical_footprint_bytes'] for row in idle]
    mean_time, mean_value = statistics.mean(times), statistics.mean(values)
    result['idle_slope_bytes_per_second'] = sum(
        (t - mean_time) * (v - mean_value) for t, v in zip(times, values)
    ) / sum((t - mean_time) ** 2 for t in times)
    return result


def measure(args, browser, output):
    output.mkdir()
    client = None
    screen = placement()
    binary = args.vox if browser == 'vox' else args.brave
    identity = {'binary': str(binary), 'sha256': digest(binary)}
    if browser == 'vox':
        identity['runtime'] = runtime_identity(binary)
    with tempfile.TemporaryDirectory(prefix='profile-', dir=output) as temporary:
        profile = Path(temporary).resolve()
        env = clean_environment()
        if browser == 'vox':
            cache = profile / 'cache'
            shutil.copytree(args.cache, cache, copy_function=clone_file)
            shutil.rmtree(cache / 'snapshots', ignore_errors=True)
            env.update(LADYBIRD_CACHE_DIR=str(cache), VOX_TEST_WINDOW='1',
                       LADYBIRD_DEBUG_TIMING='1',
                       DYLD_LIBRARY_PATH=str(binary.parent),
                       DYLD_INSERT_LIBRARIES=str(args.network_deny),
                       NO_PROXY='localhost,127.0.0.1',
                       LADYBIRD_SCREENSHOT_SCALE=str(screen['scale']),
                       VOX_NATIVE_OBSERVATION_DELAY_MS=str(int(args.seconds * 1000) + 500),
                       VOX_NATIVE_OBSERVATION_SCREENSHOT=str(output / 'window.png'),
                       VOX_CAPTURE_AUDIT_PATH=str(output / 'document.json'),
                       VOX_CAPTURE_AUDIT_CONFIG=str(output / 'audit-config.json'))
            (output / 'audit-config.json').write_text(json.dumps({'selectors': [
                {'name': 'stories', 'selector': '.story', 'limit': 20},
                {'name': 'images', 'selector': '.story img', 'limit': 20, 'attributes': ['src']},
            ]}))
            command = [str(binary), '--enable-javascript', '--window-width', '1024',
                       '--window-height', '880', URL]
        else:
            command = [str(binary), '--no-first-run', '--no-default-browser-check',
                       '--disable-background-networking', '--remote-debugging-port=0',
                       '--no-proxy-server',
                       '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost',
                       '--user-data-dir=' + str(profile), '--window-size=1024,939',
                       f"--window-position={screen['left']},{screen['top']}", 'about:blank']
        with (output / 'browser.log').open('w') as log:
            started = time.monotonic()
            process = subprocess.Popen(command, cwd=REPO, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            counter = PhysicalTree(process.pid, started)
            foreground = ForegroundControl(process.pid, True, start_at=1)
            try:
                with CounterSampler(counter, .05):
                    if browser == 'brave':
                        while not (endpoint := chrome_debugger_endpoint(profile / 'DevToolsActivePort')):
                            if process.poll() is not None or time.monotonic() - started > 30:
                                raise RuntimeError('Brave debugger did not start')
                            time.sleep(.02)
                        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                        with opener.open(f'http://127.0.0.1:{endpoint[0]}/json/list') as response:
                            targets = json.load(response)
                        client = PikabuReplayCDP(next(t['webSocketDebuggerUrl'] for t in targets
                                                     if t['type'] == 'page'), args.cache)
                        identity['version'] = client.call('Browser.getVersion')
                        for method in ['Page.enable', 'Network.enable']:
                            client.call(method)
                        client.call('Network.setBypassServiceWorker', {'bypass': True})
                        client.call('Network.setCacheDisabled', {'cacheDisabled': True})
                        client.call('Emulation.setDeviceMetricsOverride', dict(width=1024,
                            height=796, deviceScaleFactor=screen['scale'], mobile=False))
                        client.call('Fetch.enable', {'patterns': [dict(urlPattern='http*', requestStage='Request')]})
                        client.call('Page.bringToFront')
                        client.call('Page.navigate', {'url': URL})
                    while time.monotonic() - started < args.seconds:
                        if process.poll() is not None:
                            raise RuntimeError(f'{browser} exited before the memory endpoint')
                        foreground.poll(time.monotonic() - started)
                        if client and select.select([client.sock], [], [], .02)[0]:
                            client.pump()
                        elif not client:
                            time.sleep(.02)
                    endpoint = time.monotonic() - started
                    counter.sample()
                    memory = memory_result(counter, endpoint)
                    foreground.verify_steady(endpoint)
                    result = dict(browser=browser, command=command, identity=identity,
                        screen=screen, seconds=endpoint, memory=memory,
                        samples=counter.samples, foreground_checks=foreground.checks)
                    if client:
                        state = client.call('Runtime.evaluate', dict(expression=DOC_STATE, returnByValue=True))
                        document = json.loads(state['result']['value'])
                        if document['url'] != URL or document['ready'] != 'complete' or document['stories'] <= 0:
                            raise RuntimeError('Brave did not load the frozen document')
                        result.update(document=document, requests=client.requests)
                        pixels = client.call('Page.captureScreenshot', dict(format='png', captureBeyondViewport=False))
                        (output / 'document.png').write_bytes(base64.b64decode(pixels['data']))
                    else:
                        result['readiness'] = native_readiness((output / 'browser.log').read_text())
                        deadline = time.monotonic() + 15
                        while not (output / 'document.json').is_file() or not (output / 'window.png').is_file():
                            if process.poll() is not None or time.monotonic() > deadline:
                                raise RuntimeError('Vox did not produce its normal-window endpoint observation')
                            time.sleep(.02)
                        document = json.loads((output / 'document.json').read_text())
                        validate_native_document(document)
                        result['document'] = document
                        crop_native_document(output / 'window.png', output / 'document.png', document)
                        if runtime_identity(binary) != identity['runtime']:
                            raise RuntimeError('Vox executable or runtime changed during measurement')
                    # Capture/debugger observations follow the primary endpoint.
                    (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
                    return result
            finally:
                if client:
                    client.sock.close()
                stop_process(process)


def native_readiness(log):
    installs = len(re.findall(r'Ladybird V timing: install_total ', log))
    commands = [int(n) for n in re.findall(r'first_paint_replay \((\d+) commands\)', log)]
    if installs < 1 or not commands or commands[-1] < 100:
        raise RuntimeError('Vox did not install and paint the frozen page')
    return dict(completed_installs=installs, first_paint_command_counts=commands,
                note='Initial completion/paint checks; endpoint DOM and window capture validated separately.')


def validate_native_document(document):
    stories = next((s['count'] for s in document.get('selections', []) if s['name'] == 'stories'), 0)
    if (document.get('url') != URL or document.get('ready') != 'complete'
            or not document.get('title') or document.get('paint_commands', 0) < 100 or stories <= 0):
        raise RuntimeError('Vox did not retain the frozen document at the memory endpoint')


def comparison(vox, brave):
    v = [r['memory']['settled_physical_footprint_bytes'] for r in vox]
    b = [r['memory']['settled_physical_footprint_bytes'] for r in brave]
    return dict(vox_median_bytes=statistics.median(v), brave_median_bytes=statistics.median(b),
                vox_range_bytes=[min(v), max(v)], brave_range_bytes=[min(b), max(b)],
                target_met=max(v) < min(b),
                criterion='Every Vox trial below every Brave trial, full process-tree physical footprint')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path, default=REPO / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--network-deny', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--seconds', type=float, default=60)
    parser.add_argument('--trials', type=int, default=3)
    parser.add_argument('--browser', choices=['both', 'vox', 'brave'], default='both')
    args = parser.parse_args()
    if args.seconds < 10 or args.trials < 1:
        parser.error('Use at least ten seconds and one trial')
    for key in ('vox', 'brave', 'cache', 'network_deny', 'output'):
        setattr(args, key, getattr(args, key).resolve())
    if frozen_response(args.cache, URL, 'Document') is None:
        parser.error('Cache is missing the canonical frozen document and response headers')
    args.output.mkdir(parents=True, exist_ok=False)
    fixture = fingerprint_tree(args.cache)
    rows = {'vox': [], 'brave': []}
    for trial in range(args.trials):
        order = ['vox', 'brave'] if trial % 2 == 0 else ['brave', 'vox']
        for browser in order:
            if args.browser not in ('both', browser):
                continue
            row = measure(args, browser, args.output / f'{trial + 1}-{browser}')
            rows[browser].append(row)
            print(browser, trial + 1, json.dumps(row['memory']), flush=True)
    if fingerprint_tree(args.cache) != fixture:
        raise RuntimeError('Frozen response template changed during measurement')
    result = dict(fixture=fixture, trials=rows)
    if all(rows.values()):
        result['comparison'] = comparison(**rows)
        print(json.dumps(result['comparison']), flush=True)
    (args.output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
