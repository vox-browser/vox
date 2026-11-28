#!/usr/bin/env python3
"""Time a replayed page load in Vox and in Brave, from launch to a capture.

Every round launches each browser once, alternating which goes first, with an
empty profile and cache against the same offline archive
(tools/page_archive.py) at its original URL. Both open a normal window of the
same document viewport and device scale and receive the URL on their command
line, so startup, window creation, fetching, scripts, layout, raster and PNG
encoding are inside both intervals.

Endpoints:
  Vox    process launch to the completed document PNG that --screenshot
         writes once the page's resources are ready (and --ready-selector
         matches).
  Brave  process launch to the PNG that Page.captureScreenshot returns after
         the load event, document.fonts.ready and the same selector, written
         by this harness. It includes the DevTools attachment, one in-page
         readiness promise polled every 10 ms, and the CDP delivery of the
         PNG. The harness adds no wait of its own.

Brave's window height is calibrated once so that its document viewport has
the requested size without emulation, and every trial checks the viewport and
the capture size. --test-type hides the warning bar of the certificate flag
that trusts the replay, which would otherwise take 56 px of the viewport.

The readiness conditions are each engine's own and are not proven identical:
compare the two captures before trusting a timing. CPU is the rusage total of
the Vox process and the sum over Brave's process tree at capture; processes
that exited earlier and GPU or system services are not counted, so both are
lower bounds. The two browsers apply their own content blocking, so their
replayed request counts differ. Run it through run_memory_bounded.
"""
import argparse
import base64
import ctypes
import json
import os
from pathlib import Path
import statistics
import struct
import subprocess
import threading
import time
import urllib.request
from urllib.parse import urlsplit

from github_hydrated_render import certificate_spki
from hacker_news_browser_instructions import test_display
from measure_browser_instructions import CDP, chrome_debugger_endpoint, stop_process
from measure_load_parallelism import ThreadCounters, clean_environment, digest, run_trial
from page_archive import Replay, load_archive

ROOT = Path(__file__).resolve().parents[1]
BRAVE = Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser')
# Window height for the calibration launch; the toolbar height is measured.
CALIBRATION_OUTER_HEIGHT = 900
# Marks Brave's analytics notice as seen, so that a new profile has no
# first-run notice to open while a page loads. The profile is otherwise empty,
# and check_viewport() rejects a trial whose document viewport changed.
BRAVE_LOCAL_STATE = {'brave': {'p3a': {'notice_acknowledged': True}}}


def readiness_expression(url, selector):
    """A promise for the loaded page's identity, resolved by the page itself."""
    parts = urlsplit(url)
    origin = f'{parts.scheme}://{parts.netloc}/' if parts.netloc else url
    return '''new Promise(resolve => {
  const origin = %s, selector = %s;
  const check = () => {
    if (location.href.startsWith(origin) && document.readyState === 'complete'
        && (!selector || document.querySelector(selector))) {
      document.fonts.ready.then(() => resolve(JSON.stringify({
        url: location.href, title: document.title, width: innerWidth, height: innerHeight,
        scale: devicePixelRatio, images: document.images.length,
        incomplete_images: [...document.images].filter(image => !image.complete).length,
        document_height: document.documentElement.scrollHeight,
        page_ms: performance.now()})));
    } else {
      setTimeout(check, 10);
    }
  };
  check();
})''' % (json.dumps(origin), json.dumps(selector))


def png_size(data):
    if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise ValueError('Not a PNG')
    return struct.unpack('>II', data[16:24])


def check_viewport(page, png, width, height, scale):
    actual = page['width'], page['height'], page['scale']
    if actual != (width, height, scale):
        raise RuntimeError(f'Brave viewport is {actual}; expected {(width, height, scale)}')
    if png != (width * scale, height * scale):
        raise RuntimeError(f'Brave capture is {png}; expected {(width * scale, height * scale)}')


class ProcessTree:
    """Sum of rusage CPU over a process and its live descendants."""
    def __init__(self, counters):
        self.counters = counters
        self.lib = counters.lib
        self.lib.proc_listchildpids.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
        self.lib.proc_listchildpids.restype = ctypes.c_int
        self.buffer = (ctypes.c_int * 4096)()

    def pids(self, root):
        found, queue = [root], [root]
        while queue:
            count = self.lib.proc_listchildpids(queue.pop(), self.buffer, ctypes.sizeof(self.buffer))
            # Older systems return bytes instead of a count.
            if count > len(self.buffer):
                count //= ctypes.sizeof(ctypes.c_int)
            children = [self.buffer[index] for index in range(max(count, 0))]
            children = [pid for pid in children if pid > 0 and pid not in found]
            found += children
            queue += children
        return found

    def cpu_ns(self, root):
        pids = self.pids(root)
        return sum(self.counters.process_cpu_ns(pid) or 0 for pid in pids), len(pids)


def brave_command(args, profile, replay, outer_height, url):
    x, y = args.position
    # --test-type hides the warning bar for the certificate flag below.
    return [str(args.brave), '--no-first-run', '--no-default-browser-check', '--test-type',
            '--disable-background-networking', '--remote-debugging-port=0',
            f'--user-data-dir={profile}', f'--window-position={x},{y}',
            f'--window-size={args.width},{outer_height}',
            f'--force-device-scale-factor={args.screenshot_scale}',
            '--proxy-server=' + replay.ready['proxy'].replace('socks5h://', 'socks5://'),
            '--ignore-certificate-errors-spki-list=' + certificate_spki(replay.ready['ca']), url]


def page_target(opener, port, deadline, process):
    while True:
        try:
            with opener.open(f'http://127.0.0.1:{port}/json/list', timeout=5) as response:
                for target in json.load(response):
                    if target.get('type') == 'page' and target.get('webSocketDebuggerUrl'):
                        return target['webSocketDebuggerUrl']
        except OSError:
            pass
        if process.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('Brave page target did not start')
        time.sleep(.002)


def evaluate_when_ready(client, expression, deadline):
    """A navigation destroys the context a promise waits in; ask again."""
    while True:
        try:
            result = client.call('Runtime.evaluate', dict(expression=expression, awaitPromise=True,
                                                          returnByValue=True))
            if 'exceptionDetails' not in result and 'value' in result.get('result', {}):
                return json.loads(result['result']['value'])
        except RuntimeError:
            pass
        if time.monotonic() > deadline:
            raise TimeoutError('Brave page readiness timed out')
        time.sleep(.002)


def run_brave(args, tree, folder, url, outer_height, capture=True):
    folder.mkdir()
    profile, png = folder / 'profile', folder / 'document.png'
    profile.mkdir()
    (profile / 'Local State').write_text(json.dumps(BRAVE_LOCAL_STATE))
    replay = Replay(args.archive, folder / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    command = brave_command(args, profile, replay, outer_height, url)
    row = dict(command=command, folder=str(folder),
               host_before=dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg()))
    process = client = None
    try:
        with (folder / 'browser.log').open('w') as log:
            launched = time.monotonic()
            process = subprocess.Popen(command, cwd=folder, env=clean_environment(), stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            deadline = launched + args.timeout
            while (endpoint := chrome_debugger_endpoint(profile / 'DevToolsActivePort')) is None:
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError(f'Brave debugger did not start; see {folder}')
                time.sleep(.002)
            row['debugger_ms'] = (time.monotonic() - launched) * 1000
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            client = CDP(page_target(opener, endpoint[0], deadline, process))
            client.sock.settimeout(args.timeout)
            row['attached_ms'] = (time.monotonic() - launched) * 1000
            page = evaluate_when_ready(client, readiness_expression(args.url if capture else url,
                                                                    args.ready_selector if capture else None),
                                       deadline)
            row['ready_ms'] = (time.monotonic() - launched) * 1000
            if args.settle_seconds and capture:
                time.sleep(args.settle_seconds)
            if capture:
                data = base64.b64decode(client.call('Page.captureScreenshot', dict(
                    format='png', captureBeyondViewport=False))['data'])
                png.write_bytes(data)
                row['png_ms'] = (time.monotonic() - launched) * 1000
                cpu, processes = tree.cpu_ns(process.pid)
                row.update(process_tree_cpu_ms=cpu / 1e6, processes=processes, png_size=png_size(data),
                           png_sha256=digest(png))
            row.update(page=page, version=client.call('Browser.getVersion').get('product'))
            try:
                client.call('Browser.close')
            except (EOFError, OSError, RuntimeError):
                pass
            try:
                row['exit'] = process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                row['exit'] = 'stopped'
    finally:
        if client is not None:
            client.sock.close()
        if process is not None:
            stop_process(process)
        replay.server.shutdown()
        replay.server.server_close()
    row['host_after'] = dict(unix=time.time(), load=os.getloadavg())
    requests = [json.loads(line) for line in (replay.output / 'requests.jsonl').read_text().splitlines()]
    row.update(replayed_requests=len(requests),
               unarchived_requests=len([request for request in requests if request.get('archived') is False]))
    (folder / 'result.json').write_text(json.dumps(row, indent=2) + '\n')
    return row


def calibrate(args, tree):
    """Measure Brave's toolbar height so its document viewport matches Vox's."""
    row = run_brave(args, tree, args.output / 'brave-calibration', 'about:blank',
                    CALIBRATION_OUTER_HEIGHT, capture=False)
    page = row['page']
    if page['width'] != args.width or page['scale'] != args.screenshot_scale:
        raise RuntimeError(f'Brave opened a {page["width"]} px viewport at scale {page["scale"]}')
    return CALIBRATION_OUTER_HEIGHT - page['height'] + args.height


def compare(vox, brave):
    """Vox and Brave launch-to-capture times of the same rounds, in ms."""
    return dict(
        rounds=len(vox), vox_ms=vox, brave_ms=brave,
        vox_median_ms=statistics.median(vox), brave_median_ms=statistics.median(brave),
        vox_to_brave=statistics.median(vox) / statistics.median(brave),
        rounds_vox_faster=sum(a < b for a, b in zip(vox, brave)),
        # The conservative reading: Vox's slowest launch against Brave's fastest.
        slowest_vox_ms=max(vox), fastest_brave_ms=min(brave),
        slowest_vox_beats_fastest_brave=max(vox) < min(brave))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path, default=ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=BRAVE)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--url', help='Defaults to the archived page URL.')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--js-engine', default='javascriptcore')
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=768)
    parser.add_argument('--screenshot-scale', type=int, default=2, choices=[1, 2])
    parser.add_argument('--settle-seconds', type=float, default=0)
    parser.add_argument('--sample-interval', type=float, default=.002)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--ready-selector', metavar='SELECTOR',
                        help='Both browsers capture only after this selector matches.')
    parser.add_argument('--env', action='append', default=[], metavar='NAME=VALUE',
                        help='Extra Vox environment for every trial.')
    args = parser.parse_args()
    args.vox, args.archive, args.output = args.vox.resolve(), args.archive.resolve(), args.output.resolve()
    args.url = args.url or load_archive(args.archive)['url']
    args.first_submission = False
    args.output.mkdir(parents=True, exist_ok=False)
    display = test_display()
    args.position = display['position']
    counters = ThreadCounters()
    tree = ProcessTree(counters)
    identity = dict(vox=str(args.vox), vox_sha256=digest(args.vox), brave=str(args.brave),
                    brave_sha256=digest(args.brave), archive=str(args.archive),
                    manifest_sha256=digest(args.archive / 'manifest.json'))
    outer_height = calibrate(args, tree)
    rows = []
    for index in range(1, args.repeat + 1):
        for browser in (['vox', 'brave'] if index % 2 else ['brave', 'vox']):
            if browser == 'vox':
                row = run_trial(args, counters, index, 'vox', args.env)
                row.update(browser='vox', cpu_ms=row['launch_to_png']['process_cpu_ms'])
            else:
                row = run_brave(args, tree, args.output / f'brave-{index}', args.url, outer_height)
                check_viewport(row['page'], tuple(row['png_size']), args.width, args.height,
                               args.screenshot_scale)
                row.update(browser='brave', trial=index, cpu_ms=row['process_tree_cpu_ms'])
            rows.append(row)
            if digest(args.vox) != identity['vox_sha256'] or digest(args.brave) != identity['brave_sha256']:
                raise RuntimeError('A measured executable changed during the cohort')
            print(json.dumps(dict(browser=browser, trial=index, png_ms=round(row['png_ms']),
                                  cpu_ms=round(row['cpu_ms']), requests=row['replayed_requests'])), flush=True)
    by = {browser: [row for row in rows if row['browser'] == browser] for browser in ['vox', 'brave']}
    summary = compare([row['png_ms'] for row in by['vox']], [row['png_ms'] for row in by['brave']])
    summary.update(
        vox_cpu_ms=statistics.median(row['cpu_ms'] for row in by['vox']),
        brave_process_tree_cpu_ms=statistics.median(row['cpu_ms'] for row in by['brave']),
        vox_replayed_requests=sorted({row['replayed_requests'] for row in by['vox']}),
        brave_replayed_requests=sorted({row['replayed_requests'] for row in by['brave']}),
        vox_png_sha256=sorted({row['png_sha256'] for row in by['vox']}),
        brave_png_sha256=sorted({row['png_sha256'] for row in by['brave']}),
        brave_version=by['brave'][0]['version'], brave_outer_window_height=outer_height,
        brave_ready_ms=[row['ready_ms'] for row in by['brave']],
        brave_attached_ms=[row['attached_ms'] for row in by['brave']])
    result = dict(scope=__doc__, url=args.url, viewport=[args.width, args.height],
                  screenshot_scale=args.screenshot_scale, ready_selector=args.ready_selector,
                  settle_seconds=args.settle_seconds, js_engine=args.js_engine, vox_environment=args.env,
                  display=display, **identity, summary=summary, trials=rows)
    (args.output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
