#!/usr/bin/env python3
"""Require frozen HN navigation/capture CPU work to be 10% less than Brave.

Run under tools/run_memory_bounded.py on macOS. Exclusive resource coalitions
include live and exited browser helpers and coalition-owned Metal compiler
services. GPU execution and services outside the coalition are excluded.
Both captures must match the original Brave pixels exactly.
"""
from __future__ import annotations

import argparse
import base64
import ctypes
from contextlib import contextmanager
from dataclasses import asdict
import gzip
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
import os
from pathlib import Path
import select
import shutil
import statistics
import subprocess
import time
import threading
import traceback
from urllib.parse import quote, unquote, urlsplit

from check_pixel_equality import compare
from capture_brave_reference import resize_native_viewport
from coalition_instruction_counts import MacCoalitionCounters, CoalitionCounter, instruction_delta
from measure_browser_instructions import CDP, chrome_debugger_endpoint
# These helpers have no GitHub-specific policy or browser side effects.
from measure_sealed_github_instructions import (
    boundary_bracket, clean_environment, fingerprint, native_dependencies,
    parse_native_coalitions, processes, require, sha,
)
from pikabu_browser_instructions import clone_file
from process_instruction_counts import CounterSampler, MacCounters

REPO = Path(__file__).resolve().parents[1]
NAME = 'hacker-news-item-50231722-complete'
ASSETS = 'hacker-news-item-50231722'
FIXTURES = REPO / 'Tests/Browser/Brave'
DOCUMENT = FIXTURES / 'input' / (NAME + '.html')
EXPECTED = FIXTURES / 'expected' / (NAME + '.png')
WIDTH, HEIGHT = 1024, 768
TARGET = .90
METAL_COMPILER = Path('/System/Library/Frameworks/Metal.framework/Versions/A/'
                      'XPCServices/MTLCompilerService.xpc/Contents/MacOS/MTLCompilerService')
SCOPE = ('Navigation request to encoded document PNG availability, fresh process/profile/cache, '
         '1024x768 CSS pixels, recorded device scale, frozen script-free fixture replayed over loopback HTTP. Vox native markers '
         'exclude PNG file write; Brave CDP response includes base64/IPC delivery and readiness '
         'polling. Both browsers use inactive native windows on the display away from the pointer. Exclusive resource coalitions '
         'include exited helpers and coalition-owned Metal compiler services; GPU execution '
         'and services outside the coalition are excluded. '
         'Full comment-row identity is checked after the measured PNG endpoint. '
         'This is a capture workflow comparison, not identical internal rendering endpoints.')


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def test_display():
    """Use native display coordinates, placing Brave away from the pointer."""
    class Point(ctypes.Structure):
        _fields_ = [('x', ctypes.c_double), ('y', ctypes.c_double)]
    class Size(ctypes.Structure):
        _fields_ = [('width', ctypes.c_double), ('height', ctypes.c_double)]
    class Rect(ctypes.Structure):
        _fields_ = [('origin', Point), ('size', Size)]
    cg = ctypes.CDLL('/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics')
    cg.CGDisplayBounds.argtypes = [ctypes.c_uint32]
    cg.CGDisplayBounds.restype = Rect
    cg.CGEventCreate.argtypes = [ctypes.c_void_p]
    cg.CGEventCreate.restype = ctypes.c_void_p
    cg.CGEventGetLocation.argtypes = [ctypes.c_void_p]
    cg.CGEventGetLocation.restype = Point
    event = cg.CGEventCreate(None)
    require(event, 'Cannot locate pointer for test window placement')
    pointer = cg.CGEventGetLocation(event)
    cf = ctypes.CDLL('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    cf.CFRelease.argtypes = [ctypes.c_void_p]
    cf.CFRelease(event)
    displays = (ctypes.c_uint32 * 16)()
    count = ctypes.c_uint32()
    require(cg.CGGetActiveDisplayList(16, displays, ctypes.byref(count)) == 0 and count.value,
            'Cannot enumerate test displays')
    bounds = [cg.CGDisplayBounds(displays[index]) for index in range(count.value)]
    away = [b for b in bounds if not (b.origin.x <= pointer.x < b.origin.x + b.size.width
                                    and b.origin.y <= pointer.y < b.origin.y + b.size.height)]
    screen = max(away or bounds, key=lambda b: b.size.width * b.size.height)
    return dict(pointer=[pointer.x, pointer.y],
                bounds=[screen.origin.x, screen.origin.y, screen.size.width, screen.size.height],
                position=[int(screen.origin.x + max(screen.size.width - WIDTH - 80, 0)),
                          int(screen.origin.y + 30)])


def document_comments(document):
    class Comments(HTMLParser):
        def handle_starttag(self, tag, attributes):
            attributes = dict(attributes)
            if tag == 'tr' and 'comtr' in attributes.get('class', '').split():
                ids.append(attributes.get('id'))

    ids = []
    Comments().feed(document.read_text(encoding='utf-8'))
    require(0 < len(ids) <= 1000 and all(ids) and len(set(ids)) == len(ids),
            'Fixture must have unique, nonempty comment-row IDs')
    return ids


def check_content(audit, url, expected_comments):
    require(audit.get('url') == url and audit.get('ready') == 'complete'
            and [audit.get('viewport_width'), audit.get('viewport_height')] == [WIDTH, HEIGHT],
            'Captured document identity, readiness, or viewport differs')
    selection = next((row for row in audit.get('selections', [])
                      if row.get('name') == 'comments'), {})
    ids = [row.get('attributes', {}).get('id') for row in selection.get('elements', [])]
    require(selection.get('count') == len(expected_comments) and ids == expected_comments,
            'Captured document omitted or changed comment rows')


@contextmanager
def fixture_server(document, folder):
    """Use the real navigation path in both browsers, with only pinned files."""
    files = {document, *(path for path in (document.parent / ASSETS).rglob('*') if path.is_file())}
    routes = {'/' + path.relative_to(document.parent).as_posix(): path for path in files}
    with (folder / 'replay-requests.jsonl').open('w') as log:
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                path = routes.get(unquote(urlsplit(self.path).path))
                if path is None:
                    self.send_error(404)
                    return
                data = path.read_bytes()
                self.send_response(200)
                self.send_header('Content-Type', mimetypes.guess_type(path.name)[0] or 'application/octet-stream')
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Cache-Control', 'no-store')
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, message, *arguments):
                log.write(json.dumps(dict(at=time.time(), message=message % arguments)) + '\n')
                log.flush()

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            yield f'http://127.0.0.1:{server.server_port}/' + quote(document.name)
        finally:
            server.shutdown()
            server.server_close()
            worker.join()


def evaluate_pairs(pairs):
    """Require every observation and use the least favorable cross-run ratio."""
    require(len(pairs) >= 2, 'At least two complete alternating pairs are required')
    for pair in pairs:
        require(set(pair) == {'vox', 'brave'}, 'Incomplete measured pair')
        for row in pair.values():
            require(type(row.get('exit')) is int and row['exit'] == 0
                    and row.get('pixels_exact') is True and row.get('content_exact') is True,
                    'Every observation must exit successfully and match pixels and full comment identity')
            lo, hi = row['instruction_interval']['lower'], row['instruction_interval']['upper']
            require(type(lo) is int and type(hi) is int and 0 < lo <= hi,
                    'Invalid or unavailable instruction interval')
    vox = [pair['vox']['instruction_interval']['upper'] for pair in pairs]
    brave = [pair['brave']['instruction_interval']['lower'] for pair in pairs]
    ratio = max(vox) / min(brave)
    return dict(target_vox_fraction=TARGET, worst_vox_over_best_brave=ratio,
                vox_median_instructions=statistics.median(vox),
                brave_median_lower_bound_instructions=statistics.median(brave),
                passed=max(vox) * 10 <= min(brave) * 9, pairs=len(pairs))


def wait_until(predicate, deadline, description):
    while True:
        value = predicate()
        if value:
            return value
        require(time.monotonic() < deadline, description + ' watchdog expired')
        time.sleep(.01)


def launch(app, arguments, folder, environment):
    """LaunchServices gives this fresh app its own resource coalition."""
    require(not any(row['command'].startswith(str(app) + '/Contents/') for row in processes()),
            'Private measured app already has a live process')
    command = ['/usr/bin/open', '-n', '-g', '-a', str(app),
               '--stdout', str(folder / 'stdout.log'), '--stderr', str(folder / 'browser.log')]
    for key, value in sorted(environment.items()):
        command += ['--env', key + '=' + value]
    command += ['--args', *arguments]
    opened = subprocess.run(command, env=clean_environment(), capture_output=True, text=True)
    write_json(folder / 'launch.json', dict(command=command, exit=opened.returncode,
                                           stdout=opened.stdout, stderr=opened.stderr))
    require(opened.returncode == 0, 'LaunchServices launch failed')
    return command


def root_for(binary, identifier):
    roots = [row for row in processes() if row['command'].startswith(str(binary) + ' ')
             and identifier in row['command']]
    require(len(roots) <= 1, 'Measured process identity is not unique')
    return roots[0] if roots else None


def exit_watch(pid):
    queue = select.kqueue()
    queue.control([select.kevent(pid, filter=select.KQ_FILTER_PROC,
                  flags=select.KQ_EV_ADD | select.KQ_EV_ENABLE | select.KQ_EV_ONESHOT,
                  fflags=select.KQ_NOTE_EXIT | 0x04000000)], 0, 0)
    return queue


def await_exit(queue, deadline):
    while True:
        events = queue.control(None, 1, .05)
        if events:
            event = events[0]
            require(event.fflags & select.KQ_NOTE_EXIT and event.fflags & 0x04000000,
                    'Kernel did not supply exit status')
            return event.data
        require(time.monotonic() < deadline, 'Browser exit watchdog expired')


def accepted_coalition_executable(path, app):
    path = Path(path).resolve()
    return path.is_relative_to((app / 'Contents').resolve()) or path == METAL_COMPILER.resolve()


def exact_coalition_membership(api, process_api, cid, app, pid, deadline, attempts):
    """Identify every live task; never subtract Metal's CPU work from the counter."""
    while True:
        before = api.read(cid)
        members, vanished = [], []
        for row in processes():
            if row['uid'] != os.getuid():
                continue
            try:
                if api.resource_coalition(row['pid']) != cid:
                    continue
                executable = process_api.path(row['pid'])
                members.append(dict(row, executable=executable,
                                    accepted=accepted_coalition_executable(executable, app)))
            except OSError as error:
                if error.errno not in (2, 3):
                    raise
                vanished.append(row['pid'])
        after = api.read(cid)
        scan = dict(before_snapshot=asdict(before), after_snapshot=asdict(after), members=members,
                    stable=(before.tasks_started, before.tasks_exited) == (after.tasks_started, after.tasks_exited),
                    all_owned=bool(members) and all(row['accepted'] for row in members),
                    exact_live_count=after.tasks_started - after.tasks_exited == len(members),
                    root_present=pid in {row['pid'] for row in members}, vanished_during_scan=vanished)
        attempts.append(scan)
        if all(scan[key] for key in ('stable', 'all_owned', 'exact_live_count', 'root_present')):
            return scan
        require(time.monotonic() < deadline, 'No stable exact exclusive coalition membership')
        time.sleep(.01)


def membership(api, cid, app, pid, deadline, attempts, browser=None):
    scan = exact_coalition_membership(api, MacCounters(), cid, app, pid,
                                     min(deadline, time.monotonic() + 20), attempts)
    owned = {row['pid'] for row in processes()
             if row['command'].startswith(str(app) + '/Contents/')}
    require(owned <= {row['pid'] for row in scan['members']},
            'A private browser helper is outside its resource coalition')
    if browser:
        infos = browser.call('SystemInfo.getProcessInfo')['processInfo']
        require({int(row['id']) for row in infos} <= {row['pid'] for row in scan['members']},
                'A Brave browser task is outside its exclusive resource coalition')
        scan['cdp_processes'] = infos
    return scan


def run_browser(engine, app, folder, args):
    folder.mkdir()
    binary = app / 'Contents/MacOS' / ('Vox' if engine == 'vox' else 'Brave Browser')
    result = dict(engine=engine, exit=1, scope=SCOPE, membership_attempts=[],
                  viewport_css_pixels=[WIDTH, HEIGHT], device_scale=args.scale)
    browser = client = sampler = counter = queue = None
    root = None
    root_start = None
    try:
        deadline = time.monotonic() + args.timeout
        png = folder / 'document.png'
        profile, cache = folder / 'profile', folder / 'cache'
        profile.mkdir()
        cache.mkdir()
        api = MacCoalitionCounters()
        if engine == 'vox':
            environment = dict(VOX_PROFILE_INSTRUCTIONS='1', VOX_TEST_WINDOW='1',
                VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache), VOX_COOKIE_FILE='',
                LADYBIRD_SCREENSHOT_SCALE=str(args.scale),
                VOX_SCREENSHOT_NATIVE_LAYOUT='1' if args.scale == 2 else '0',
                VOX_CAPTURE_AUDIT_CONFIG=str(args.audit_config),
                VOX_CAPTURE_AUDIT_PATH=str(folder / 'audit.json'),
                VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds))
            # An empty value still enables native controls that test getenv().
            ambient = sorted(os.environ.keys() - clean_environment().keys() - environment.keys())
            require(not ambient, 'Remove ambient measurement controls: ' + ', '.join(ambient))
            result['environment'] = environment
            arguments = ['--enable-javascript', '--window-width', str(WIDTH), '--window-height',
                         str(HEIGHT + 84), '--screenshot', str(png), args.url]
            result['command'] = launch(app, arguments, folder, environment)
            root = wait_until(lambda: root_for(binary, str(png)), deadline, 'Vox launch')
        else:
            arguments = ['--no-startup-window', '--no-first-run', '--no-default-browser-check',
                '--enable-automation', '--disable-background-networking', '--disable-sync', '--no-proxy-server',
                '--hide-scrollbars', '--force-color-profile=srgb', '--lang=en-US',
                '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE 127.0.0.1',
                '--remote-debugging-port=0', '--user-data-dir=' + str(profile)]
            result['command'] = launch(app, arguments, folder, {})
            endpoint = wait_until(lambda: chrome_debugger_endpoint(profile / 'DevToolsActivePort'),
                                  deadline, 'Brave debugger')
            root = wait_until(lambda: root_for(binary, str(profile)), deadline, 'Brave launch')
            port, browser_path = endpoint
            browser = CDP(f'ws://127.0.0.1:{port}{browser_path}')
            result['version'] = browser.call('Browser.getVersion')
        result['root'] = root
        root_start = MacCounters().read(root['pid']).start
        result['root_start_ticks'] = root_start
        queue = exit_watch(root['pid'])
        cid = api.resource_coalition(root['pid'])
        require(cid != api.resource_coalition(os.getpid()), 'Browser inherited observer coalition')
        result['resource_coalition'] = cid
        result['membership_before'] = membership(api, cid, app, root['pid'], deadline,
                                                 result['membership_attempts'], browser)
        if engine == 'vox':
            result['kernel_exit_status'] = await_exit(queue, deadline)
            require(result['kernel_exit_status'] == 0, 'Vox exited unsuccessfully')
            markers = parse_native_coalitions((folder / 'browser.log').read_text(), cid)
            result['native_coalition_markers'] = markers
            value = markers['delta']['instructions']
            result['instruction_interval'] = dict(lower=value, upper=value)
            audit = json.loads((folder / 'audit.json').read_text())
        else:
            display = test_display()
            result['test_display'] = display
            target = browser.call('Target.createTarget', dict(url='about:blank', newWindow=True,
                background=True, left=display['position'][0], top=display['position'][1],
                width=WIDTH + 80, height=HEIGHT + 140))['targetId']
            client = CDP(f'ws://127.0.0.1:{port}/devtools/page/{target}')
            client.call('Page.enable')
            result['native_viewport'] = resize_native_viewport(browser, client, target,
                                                              WIDTH, HEIGHT, args.scale)
            client.call('Emulation.setFocusEmulationEnabled', dict(enabled=True))
            counter = CoalitionCounter(api, cid)
            sampler = CounterSampler(counter, .002)
            sampler.__enter__()
            navigation_at = time.monotonic()
            navigation = client.call('Page.navigate', dict(url=args.url))
            result['navigation'] = navigation
            require(not navigation.get('errorText'), 'Brave navigation failed: ' + str(navigation.get('errorText')))
            # Scalar readiness only; pixel validation follows the measured interval.
            expression = f'''location.href==={json.dumps(args.url)}
                && document.readyState==='complete' && document.fonts.status==='loaded'
                && innerWidth==={WIDTH} && innerHeight==={HEIGHT} && devicePixelRatio==={args.scale}
                && [...document.images].every(i=>i.complete && i.naturalWidth>0)'''
            wait_until(lambda: client.call('Runtime.evaluate', dict(expression=expression,
                       returnByValue=True))['result'].get('value') is True, deadline, 'Brave document')
            time.sleep(args.settle_seconds)
            image = client.call('Page.captureScreenshot', dict(format='png', captureBeyondViewport=False))
            endpoint_at = time.monotonic()
            counter.sample()
            sampler.__exit__(None, None, None)
            sampler = None
            history = list(counter.snapshots)
            start_before, start_after = boundary_bracket(history, navigation_at)
            end_before, end_after = boundary_bracket(history, endpoint_at)
            lower = instruction_delta(start_after, end_before)['instructions']
            upper = instruction_delta(start_before, end_after)['instructions']
            result['instruction_interval'] = dict(lower=lower, upper=upper)
            result['boundary_brackets'] = [asdict(row) for row in
                (start_before, start_after, end_before, end_after)]
            png.write_bytes(base64.b64decode(image['data'], validate=True))
            # This semantic collection is deliberately outside the measured interval.
            audit = client.call('Runtime.evaluate', dict(expression='''({url:location.href,
                ready:document.readyState,viewport_width:innerWidth,viewport_height:innerHeight,
                selections:[{name:'comments',count:document.querySelectorAll('tr.comtr').length,
                elements:[...document.querySelectorAll('tr.comtr')].map(e=>({attributes:{id:e.id}}))}]})''',
                returnByValue=True))['result']['value']
            write_json(folder / 'audit.json', audit)
            result['membership_after'] = membership(api, cid, app, root['pid'], deadline,
                                                    result['membership_attempts'], browser)
            browser.call('Browser.close')
            result['kernel_exit_status'] = await_exit(queue, deadline)
            require(result['kernel_exit_status'] == 0, 'Brave exited unsuccessfully')
        check_content(audit, args.url, args.expected_comments)
        result.update(content_exact=True, comment_rows=len(args.expected_comments))
        verdict = compare(args.expected, png, folder / 'document.diff.png', args.diff_tool)
        result.update(pixels_exact=verdict['exact'], pixel_comparison=verdict, png_sha256=sha(png))
        require(verdict['exact'], 'Captured document differs from the unchanged Brave reference')
        result['exit'] = 0
    except Exception as error:
        result.update(error=str(error), traceback=traceback.format_exc())
    finally:
        if sampler:
            sampler.__exit__(None, None, None)
        if counter:
            (folder / 'coalition-snapshots.json.gz').write_bytes(gzip.compress(
                json.dumps([asdict(row) for row in counter.snapshots]).encode(), mtime=0))
        if root and 'kernel_exit_status' not in result:
            # Signal only the still-live process with this private app/unique argv.
            try:
                if root_for(binary, str(folder)) == root and root_start is not None:
                    require(MacCounters().read(root['pid']).start == root_start,
                            'Measured PID identity changed during cleanup')
                    os.kill(root['pid'], 15)
                    if queue:
                        result['cleanup_kernel_exit_status'] = await_exit(queue, time.monotonic() + 5)
            except ProcessLookupError:
                pass
            except Exception as error:
                result['cleanup_error'] = str(error)
        if queue:
            queue.close()
        for connection in (client, browser):
            if connection:
                connection.sock.close()
        write_json(folder / 'result.json', result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory')
    parser.add_argument('--vox-app', type=Path, default=REPO / 'Build/v/Vox.app')
    parser.add_argument('--brave-app', type=Path, default=Path('/Applications/Brave Browser.app'))
    parser.add_argument('--diff-tool', type=Path, default=REPO / 'Build/hacker-news-pixels/pixel_diff')
    parser.add_argument('--document', type=Path, default=DOCUMENT)
    parser.add_argument('--expected', type=Path, default=EXPECTED)
    parser.add_argument('--scale', type=int, choices=[1, 2], default=2)
    parser.add_argument('--repeat', type=int, default=3)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--settle-seconds', type=float, default=2)
    args = parser.parse_args()
    if args.repeat < 2 or args.timeout <= 0 or not 0 <= args.settle_seconds < args.timeout:
        parser.error('Need at least two pairs, a positive watchdog, and a bounded nonnegative settle')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    args.diff_tool = args.diff_tool.resolve()
    args.document = args.document.resolve()
    args.expected = args.expected.resolve()
    args.expected_comments = document_comments(args.document)
    args.audit_config = args.output / 'audit-config.json'
    write_json(args.audit_config, dict(selectors=[dict(name='comments', selector='tr.comtr',
               limit=len(args.expected_comments), attributes=['id'], layout_depth=0)]))
    apps = {}
    for engine, source in [('vox', args.vox_app), ('brave', args.brave_app)]:
        app = args.output / engine / source.name
        app.parent.mkdir()
        shutil.copytree(source.resolve(), app, copy_function=clone_file, symlinks=True)
        apps[engine] = app
    paths = {args.document, args.expected, args.diff_tool, args.audit_config, METAL_COMPILER}
    paths.update(Path(__file__).resolve().parent / name for name in (
        'hacker_news_browser_instructions.py', 'check_pixel_equality.py',
        'coalition_instruction_counts.py', 'measure_browser_instructions.py',
        'capture_brave_reference.py',
        'measure_sealed_github_instructions.py', 'pikabu_browser_instructions.py',
        'process_instruction_counts.py'))
    paths.update(path for path in (args.document.parent / ASSETS).rglob('*') if path.is_file())
    for app in apps.values():
        paths.update(path for path in app.rglob('*') if path.is_file())
    paths.update(native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    pinned = fingerprint(paths)
    write_json(args.output / 'inputs.json', dict(files=pinned, scope=SCOPE,
               settle_seconds=args.settle_seconds, target_vox_fraction=TARGET,
               comment_ids=args.expected_comments,
               device_scale=args.scale, viewport_css_pixels=[WIDTH, HEIGHT],
               system=subprocess.check_output(['sw_vers'], text=True)))
    pairs = []
    with fixture_server(args.document, args.output) as args.url:
        write_json(args.output / 'replay.json', dict(url=args.url, document=str(args.document),
                   network_policy='Loopback replay only; fresh caches; Cache-Control: no-store'))
        for index in range(args.repeat):
            pair = {}
            for engine in (['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox']):
                row = run_browser(engine, apps[engine], args.output / f'pair-{index+1}-{engine}', args)
                pair[engine] = row
                require(fingerprint(paths) == pinned, 'Pinned input or browser runtime changed during measurement')
                print(json.dumps(dict(pair=index+1, engine=engine, exit=row['exit'],
                                 instructions=row.get('instruction_interval'), error=row.get('error'))), flush=True)
            pairs.append(pair)
            write_json(args.output / 'pairs.json', pairs)
    try:
        summary = evaluate_pairs(pairs)
    except RuntimeError as error:
        summary = dict(passed=False, error=str(error))
    write_json(args.output / 'summary.json', summary)
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
