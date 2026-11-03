#!/usr/bin/env python3
"""Compare cached Hacker News startup/capture CPU work with Brave.

Run under tools/run_memory_bounded.py on macOS. Exclusive resource coalitions
include live and exited browser helpers and the explicitly named coalition-owned
system services. GPU execution and services outside the coalition are excluded.
Both captures must match the original Brave pixels exactly. The default counts
startup in both browsers. The optional navigation interval has asymmetric window
setup boundaries and cannot establish comparable page-only instruction costs.
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
import math
import mimetypes
from fractions import Fraction
import os
from pathlib import Path
import plistlib
import select
import shlex
import shutil
import statistics
import subprocess
import tempfile
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
from page_archive import load_archive
from run_memory_bounded import publish_adopted_processes
from measure_precise_scroll import runtime_input_paths

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
SET_STORE_UPDATER = Path('/System/Library/PrivateFrameworks/CascadeSets.framework/Versions/A/'
                         'XPCServices/SetStoreUpdateService.xpc/Contents/MacOS/SetStoreUpdateService')
COALITION_SERVICES = (METAL_COMPILER, SET_STORE_UPDATER)
SCOPE = ('Navigation request to encoded document PNG availability, fresh process/profile/cache, '
         '1024x768 CSS pixels, recorded device scale, cached fixture replayed over loopback HTTP. Vox native markers '
         'exclude PNG file write; Brave CDP response includes base64/IPC delivery and readiness '
         'polling. Vox requests its initial navigation before presenting its first native window frame; '
         'Brave creates and resizes an about:blank window before the measured navigation request. '
         'Both browsers use inactive native windows on the display away from the pointer. Exclusive resource coalitions '
         'include exited helpers and coalition-owned Metal compiler and CascadeSets update services; GPU execution '
         'and services outside the coalition are excluded. '
         'Full story/comment-row identity is checked after the measured PNG endpoint. '
         'The asymmetric window setup makes this interval diagnostic only. '
         'This is a capture workflow comparison, not identical internal rendering endpoints.')
LAUNCH_SCOPE = ('Exclusive browser resource-coalition creation through encoded document PNG '
                'availability, including browser/window startup and the navigation/capture workflow '
                'described by navigation_scope. Brave includes CDP target/window setup. '
                'OS filesystem and shader caches are not cleared. This is a full startup/capture '
                'workflow, not isolated page navigation or rendering work.')


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def reference_browser_apps(output, sources):
    """Reference existing bundles; private profiles/caches remain per trial.

    Per-trial input fingerprints reject a rebuild or update during a cohort.
    Keeping links rather than copies also preserves the familiar result layout.
    """
    apps = {}
    for engine, source in sources:
        source = Path(source).resolve(strict=True)
        require(source.is_dir() and (source / 'Contents/MacOS').is_dir(),
                'Expected a browser application: ' + str(source))
        link = Path(output) / engine / source.name
        link.parent.mkdir()
        link.symlink_to(source, target_is_directory=True)
        apps[engine] = source
    write_json(Path(output) / 'browser-apps.json', dict(
        policy='Existing bundles; no per-cohort copies; changed hashes invalidate the run',
        apps={engine: str(app) for engine, app in apps.items()}))
    return apps


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


def document_comments(document, row_class='comtr'):
    class Comments(HTMLParser):
        def handle_starttag(self, tag, attributes):
            attributes = dict(attributes)
            if tag == 'tr' and row_class in attributes.get('class', '').split():
                ids.append(attributes.get('id'))

    ids = []
    Comments().feed(document.read_text(encoding='utf-8'))
    require(0 < len(ids) <= 1000 and all(ids) and len(set(ids)) == len(ids),
            'Fixture must have unique, nonempty row IDs')
    return ids


def check_content(audit, url, expected_comments, row_name='comments'):
    require(audit.get('url') == url and audit.get('ready') == 'complete'
            and [audit.get('viewport_width'), audit.get('viewport_height')] == [WIDTH, HEIGHT],
            'Captured document identity, readiness, or viewport differs')
    selection = next((row for row in audit.get('selections', [])
                      if row.get('name') == row_name), {})
    ids = [row.get('attributes', {}).get('id') for row in selection.get('elements', [])]
    row_kind = 'story' if row_name == 'stories' else 'comment'
    require(selection.get('count') == len(expected_comments) and ids == expected_comments,
            f'Captured document omitted or changed {row_kind} rows')


@contextmanager
def fixture_server(document, folder, archive=None):
    """Use the real navigation path in both browsers, with only pinned files."""
    files = {document, *(path for path in (document.parent / ASSETS).rglob('*') if path.is_file())}
    routes = {'/' + path.relative_to(document.parent).as_posix(): path for path in files}
    archived = {}
    if archive:
        manifest = load_archive(archive)
        origin = urlsplit(manifest['url']).netloc
        for url, entry in manifest['responses'].items():
            parsed = urlsplit(url)
            require(parsed.netloc == origin, 'Loopback replay requires a same-origin archive')
            route = parsed.path + ('?' + parsed.query if parsed.query else '')
            archived[route] = entry
    with (folder / 'replay-requests.jsonl').open('w') as log:
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                entry = archived.get(self.path) if archive else None
                path = archive / 'bodies' / entry['sha256'] if entry else routes.get(unquote(urlsplit(self.path).path))
                if path is None or (archive and entry is None):
                    self.send_error(404)
                    return
                data = path.read_bytes()
                self.send_response(entry['status'] if entry else 200)
                content_type = next((h['value'] for h in entry['headers']
                                     if h['name'].lower() == 'content-type'), 'application/octet-stream') if entry else mimetypes.guess_type(path.name)[0] or 'application/octet-stream'
                self.send_header('Content-Type', content_type)
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
            target = urlsplit(manifest['url']).path if archive else '/' + quote(document.name)
            yield f'http://127.0.0.1:{server.server_port}' + target
        finally:
            server.shutdown()
            server.server_close()
            worker.join()


def launch_instruction_interval(engine, result):
    """Use an actual cumulative coalition reading, including exited startup tasks.

    No subtraction of a post-launch observation: that would silently omit startup.
    Exclusivity is checked by run_browser, including ownership after Brave capture.
    """
    cid = result['resource_coalition']
    if engine == 'vox':
        end = result['native_coalition_markers']['markers'][-1]
        require(end.get('label') == 'capture_document_encoded', 'Missing native PNG endpoint')
        readings = [end, end]
    elif engine == 'brave':
        readings = result['boundary_brackets'][-2:]
        require(len(readings) == 2, 'Missing Brave PNG boundary brackets')
    else:
        raise RuntimeError('Unknown browser engine')
    require(all(reading.get('coalition_id') == cid for reading in readings),
            'Launch endpoint coalition identity differs')
    lower, upper = (reading.get('instructions') for reading in readings)
    require(type(lower) is int and type(upper) is int and 0 < lower <= upper,
            'Invalid launch instruction interval')
    return dict(lower=lower, upper=upper)


def evaluate_pairs(pairs, target=TARGET, instruction_scope='navigation'):
    """Require every observation and use the least favorable cross-run ratio."""
    require(instruction_scope in ('navigation', 'launch'), 'Unknown instruction scope')
    require(len(pairs) >= 2, 'At least two complete alternating pairs are required')
    for pair in pairs:
        require(set(pair) == {'vox', 'brave'}, 'Incomplete measured pair')
        for row in pair.values():
            require(type(row.get('exit')) is int and row['exit'] == 0
                    and row.get('pixels_exact') is True and row.get('content_exact') is True,
                    'Every observation must exit successfully and match pixels and full row identity')
            interval = (row['instruction_interval'] if instruction_scope == 'navigation'
                        else row['launch_instruction_interval'])
            lo, hi = interval['lower'], interval['upper']
            require(type(lo) is int and type(hi) is int and 0 < lo <= hi,
                    'Invalid or unavailable instruction interval')
    key = 'instruction_interval' if instruction_scope == 'navigation' else 'launch_instruction_interval'
    vox = [pair['vox'][key]['upper'] for pair in pairs]
    brave = [pair['brave'][key]['lower'] for pair in pairs]
    ratio = max(vox) / min(brave)
    fraction = Fraction(str(target))
    require(0 < fraction <= 1, 'Target fraction must be in (0, 1]')
    return dict(target_vox_fraction=float(fraction), worst_vox_over_best_brave=ratio,
                instruction_scope=instruction_scope,
                vox_median_instructions=statistics.median(vox),
                brave_median_lower_bound_instructions=statistics.median(brave),
                passed=max(vox) * fraction.denominator <= min(brave) * fraction.numerator, pairs=len(pairs))


def progress_record(pair, engine, row, instruction_scope):
    require(instruction_scope in ('navigation', 'launch'), 'Unknown instruction scope')
    key = 'launch_instruction_interval' if instruction_scope == 'launch' else 'instruction_interval'
    return dict(pair=pair, engine=engine, exit=row['exit'], instruction_scope=instruction_scope,
                instructions=row.get(key), navigation_instruction_interval=row.get('instruction_interval'),
                launch_instruction_interval=row.get('launch_instruction_interval'), error=row.get('error'))


def wait_until(predicate, deadline, description):
    while True:
        value = predicate()
        if value:
            return value
        require(time.monotonic() < deadline, description + ' watchdog expired')
        time.sleep(.01)


def finish_capture_readiness(client, args):
    expression = getattr(args, 'post_readiness_expression', None)
    if not expression:
        return
    result = client.call('Runtime.evaluate', dict(expression=expression,
                         awaitPromise=True, returnByValue=True))
    require(not result.get('exceptionDetails') and result.get('result', {}).get('value') is True,
            'Brave asynchronous capture readiness failed: ' + repr(result))


def prepare_browser_profile(engine, profile, cache, args):
    """Copy closed, pinned templates; never launch against the source profile."""
    for destination, source in ((profile, getattr(args, engine + '_profile_template', None)),
                                (cache, getattr(args, engine + '_cache_template', None))):
        if source is not None:
            shutil.copytree(source, destination, dirs_exist_ok=True, copy_function=clone_file,
                            symlinks=True,
                            ignore=shutil.ignore_patterns('Singleton*', 'DevToolsActivePort'))


def configure_brave_viewport(browser, client, target, args):
    if getattr(args, 'brave_emulated_viewport', False):
        client.call('Emulation.setDeviceMetricsOverride', dict(width=WIDTH, height=HEIGHT,
                    deviceScaleFactor=args.scale, mobile=False))
        return dict(width=WIDTH, height=HEIGHT, scale=args.scale, emulated=True)
    return resize_native_viewport(browser, client, target, WIDTH, HEIGHT, args.scale)


def existing_browser_processes(app):
    """Pin unrelated shared-bundle tasks before starting a measured root."""
    process_api, coalition_api = MacCounters(), MacCoalitionCounters()
    existing = []
    for row in processes():
        if not row['command'].startswith(str(app) + '/Contents/'):
            continue
        try:
            before = process_api.read(row['pid'])
            cid = coalition_api.resource_coalition(row['pid'])
            after = process_api.read(row['pid'])
        except OSError as error:
            if error.errno in (2, 3):
                continue
            raise
        require(before.start == after.start and not before.exited and not after.exited,
                'Preexisting browser process changed while pinning its identity')
        existing.append(dict(row, start_ticks=before.start, resource_coalition=cid))
    return existing


def verified_preexisting_app_pids(process_api, coalition_api, cid, rows, existing_processes):
    """A PID/command match alone cannot exempt a recycled or moved task."""
    previous = {(row['pid'], row['command']): row for row in existing_processes}
    excluded = set()
    for row in rows:
        old = previous.get((row['pid'], row['command']))
        if old is None:
            continue
        require(type(old.get('start_ticks')) is int and old['start_ticks'] > 0
                and type(old.get('resource_coalition')) is int and old['resource_coalition'] > 0,
                'Preexisting browser task has no pinned process identity')
        try:
            before = process_api.read(row['pid'])
            current_cid = coalition_api.resource_coalition(row['pid'])
            after = process_api.read(row['pid'])
        except OSError as error:
            if error.errno in (2, 3):
                continue
            raise
        if (before.exited or after.exited or before.start != old['start_ticks']
                or after.start != old['start_ticks'] or current_cid != old['resource_coalition']):
            continue
        require(current_cid != cid, 'Measured coalition contains a preexisting browser task')
        excluded.add(row['pid'])
    return excluded


def private_capture_marker(command, binary):
    """Recognize an explicit private instance, without guessing from its URL."""
    prefix = str(binary) + ' '
    if not command.startswith(prefix):
        return None
    try:
        arguments = shlex.split(command[len(prefix):])
    except ValueError:
        return None
    option = '--user-data-dir' if binary.name == 'Brave Browser' else '--screenshot'
    values = []
    for index, argument in enumerate(arguments):
        if argument == option and index + 1 < len(arguments):
            values.append(arguments[index + 1])
        elif argument.startswith(option + '='):
            values.append(argument[len(option) + 1:])
    if len(values) != 1 or not Path(values[0]).is_absolute():
        return None
    return option, str(Path(values[0]).resolve())


def verified_concurrent_capture_tasks(process_api, coalition_api, cid, app, pid, rows):
    """Separate independently launched captures of the shared installed app.

    A new unrelated capture can start after launch.json's preexisting snapshot.
    Authenticate its distinct private profile/output and live root, then pin
    each excluded task's executable, creation time and different coalition.
    An escaped descendant of our root, an ambiguous root or a CDP-owned process
    must still fail the ordinary ownership checks.
    """
    app = app.resolve()
    by_pid = {row['pid']: row for row in rows}
    ours = by_pid.get(pid)
    if ours is None:
        return [], []
    name = 'Brave Browser' if app.name == 'Brave Browser.app' else 'Vox'
    binary = (app / 'Contents/MacOS' / name).resolve()
    marker = private_capture_marker(ours['command'], binary)
    if marker is None:
        return [], []

    def descendant(child, ancestor):
        seen = set()
        while child in by_pid and child not in seen:
            if child == ancestor:
                return True
            seen.add(child)
            child = by_pid[child]['parent']
        return False

    def identity(row):
        try:
            before = process_api.read(row['pid'])
            path = Path(process_api.path(row['pid'])).resolve()
            current_cid = coalition_api.resource_coalition(row['pid'])
            after = process_api.read(row['pid'])
        except OSError as error:
            if error.errno in (2, 3):
                return None
            raise
        if (before.exited or after.exited or before.start != after.start
                or type(before.start) is not int or before.start <= 0
                or type(current_cid) is not int or current_cid <= 0
                or current_cid == cid or not path.is_relative_to(app / 'Contents')):
            return None
        base = {key: row[key] for key in ('pid', 'parent', 'uid', 'command')}
        return dict(base, start_ticks=before.start, resource_coalition=current_cid,
                    executable=str(path))

    roots = []
    for row in rows:
        other_marker = private_capture_marker(row['command'], binary)
        if (other_marker is None or other_marker == marker or row['pid'] == pid
                or descendant(row['pid'], pid) or descendant(pid, row['pid'])):
            continue
        root = identity(row)
        if root is not None and root['executable'] == str(binary):
            roots.append(dict(root, private_marker=list(other_marker)))
    tasks = []
    for row in rows:
        if descendant(row['pid'], pid):
            continue
        task = identity(row) if roots else None
        if task is None:
            continue
        anchors = [root for root in roots
                   if task['resource_coalition'] == root['resource_coalition']
                   and task['start_ticks'] >= root['start_ticks']]
        if anchors:
            tasks.append(dict(task, independent_root_pids=[root['pid'] for root in anchors]))
    # Re-read roots after their helpers: PID reuse or a coalition move cannot
    # authorize any exemption derived from an earlier observation.
    stable_roots = [root for root in roots if identity(root) ==
                    {key: value for key, value in root.items() if key != 'private_marker'}]
    observed = {row['pid']: row for row in processes()} if stable_roots else {}
    def same_command(row):
        return observed.get(row['pid']) == {
            key: row[key] for key in ('pid', 'parent', 'uid', 'command')}
    stable_roots = [root for root in stable_roots if same_command(root)]
    stable_pids = {root['pid'] for root in stable_roots}
    return stable_roots, [task for task in tasks
                         if same_command(task)
                         and stable_pids.intersection(task['independent_root_pids'])]


def launch(app, arguments, folder, environment):
    """LaunchServices gives this fresh app its own resource coalition."""
    # Shared installed bundles may already host the user's windows. -n and the
    # unique profile/capture argument identify our fresh root; membership() then
    # verifies its exclusive coalition without touching those existing tasks.
    existing = existing_browser_processes(app)
    command = ['/usr/bin/open', '-n', '-g', '-a', str(app),
               '--stdout', str(folder / 'stdout.log'), '--stderr', str(folder / 'browser.log')]
    for key, value in sorted(environment.items()):
        command += ['--env', key + '=' + value]
    command += ['--args', *arguments]
    opened = subprocess.run(command, env=clean_environment(), capture_output=True, text=True)
    write_json(folder / 'launch.json', dict(command=command, existing_processes=existing, exit=opened.returncode,
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


def await_exit(queue, deadline, while_running=None):
    while True:
        events = queue.control(None, 1, .05)
        if events:
            event = events[0]
            require(event.fflags & select.KQ_NOTE_EXIT and event.fflags & 0x04000000,
                    'Kernel did not supply exit status')
            return event.data
        require(time.monotonic() < deadline, 'Browser exit watchdog expired')
        if while_running:
            while_running()


def accepted_coalition_executable(path, app):
    path = Path(path).resolve()
    return path.is_relative_to((app / 'Contents').resolve()) or any(
        path == service.resolve() for service in COALITION_SERVICES)


def code_sign_clone_identity(path, app, command):
    """Authenticate macOS's temporary mapping of the private app's main binary."""
    app = Path(app)
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    name, identifier = info['CFBundleExecutable'], info['CFBundleIdentifier']
    original = app / 'Contents/MacOS' / name
    if not command.startswith(str(original) + ' '):
        return None
    path = Path(path).resolve()
    try:
        parts = path.relative_to((Path(tempfile.gettempdir()).parent / 'X').resolve()).parts
    except ValueError:
        return None
    if (len(parts) != 6 or parts[0] != identifier + '.code_sign_clone'
            or not parts[1].startswith('code_sign_clone.')
            or parts[2:] != (app.name + '.bundle', 'Contents', 'MacOS', name)):
        return None
    original_sha, mapped_sha = sha(original), sha(path)
    if original_sha != mapped_sha:
        return None
    return dict(original=str(original), mapped=str(path), sha256=mapped_sha,
                method='Exact macOS code_sign_clone path, private root argv, identical binary bytes')


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
                accepted = accepted_coalition_executable(executable, app)
                clone = None
                if not accepted and row['pid'] == pid:
                    clone = code_sign_clone_identity(executable, app, row['command'])
                    accepted = clone is not None
                members.append(dict(row, executable=executable, accepted=accepted,
                                    code_sign_clone_identity=clone))
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


def membership(api, cid, app, pid, deadline, attempts, browser=None, existing_processes=()):
    limit = min(deadline, time.monotonic() + 20)
    while True:
        process_api = MacCounters()
        scan = exact_coalition_membership(api, process_api, cid, app, pid, limit, attempts)
        app_processes = [row for row in processes()
                         if row['command'].startswith(str(app) + '/Contents/')]
        excluded = verified_preexisting_app_pids(process_api, api, cid, app_processes,
                                                existing_processes)
        concurrent_roots, concurrent_tasks = verified_concurrent_capture_tasks(
            process_api, api, cid, app, pid, app_processes)
        concurrent = {row['pid'] for row in concurrent_tasks}
        excluded |= concurrent
        owned = {row['pid'] for row in app_processes} - excluded
        scan['preexisting_app_pids'] = sorted(excluded - concurrent)
        scan['concurrent_capture_roots'] = concurrent_roots
        scan['concurrent_capture_tasks'] = concurrent_tasks
        scan['private_app_pids'] = sorted(owned)
        # Preserve argv and ancestry even when the ownership assertion below
        # fails. PIDs alone cannot distinguish an escaped helper from another
        # session launching this shared bundle during the trial.
        scan['observed_app_processes'] = app_processes
        infos = browser.call('SystemInfo.getProcessInfo')['processInfo'] if browser else []
        if browser:
            scan['cdp_processes'] = infos
        after = asdict(api.read(cid))
        scan['after_ownership_snapshot'] = after
        # Fetch workers and Metal services can start after the exact scan. Keep
        # the ownership queries inside its stable task-membership interval too.
        # Retrying the scan still includes every exited task in the counters.
        scan['ownership_stable'] = all(scan['after_snapshot'][key] == after[key]
                                       for key in ('tasks_started', 'tasks_exited'))
        if not scan['ownership_stable']:
            require(time.monotonic() < limit, 'No stable exclusive coalition ownership check')
            continue
        members = {row['pid'] for row in scan['members']}
        require(not (excluded & members), 'Measured coalition contains a preexisting browser task')
        require(owned <= members, 'A private browser helper is outside its resource coalition')
        require({int(row['id']) for row in infos} <= members,
                'A Brave browser task is outside its exclusive resource coalition')
        return scan


def capture_ownership_audit(scans, endpoint):
    """Prove the live task set at a native endpoint without moving its counter.

    Monotonic task-start/exit totals matching a stable scan exclude task churn
    between that scan and the endpoint. Aggregate counters retain exited work;
    this does not recover individual identities of already exited tasks.
    """
    require(endpoint.get('label') == 'capture_document_encoded'
            and type(endpoint.get('coalition_id')) is int and endpoint['coalition_id'] > 0
            and type(endpoint.get('tasks_started')) is int
            and type(endpoint.get('tasks_exited')) is int
            and 0 <= endpoint['tasks_exited'] < endpoint['tasks_started'],
            'Invalid native capture ownership endpoint')
    for scan in reversed(scans):
        if not all(scan.get(key) is True for key in
                   ('stable', 'all_owned', 'exact_live_count', 'root_present', 'ownership_stable')):
            continue
        readings = [scan.get(key, {}) for key in
                    ('before_snapshot', 'after_snapshot', 'after_ownership_snapshot')]
        if not all(all(reading.get(key) == endpoint.get(key) for key in
                       ('coalition_id', 'tasks_started', 'tasks_exited')) for reading in readings):
            continue
        return dict(passed=True, method='Stable live ownership with native endpoint task totals',
                    endpoint=dict(endpoint), scan=scan,
                    exited_task_identity_limit='Aggregate exited work is included; individual exited identities are not recovered')
    raise RuntimeError('No stable owned Vox task set matches the native PNG endpoint')


def run_browser(engine, app, folder, args):
    folder.mkdir()
    binary = app / 'Contents/MacOS' / ('Vox' if engine == 'vox' else 'Brave Browser')
    scope = getattr(args, 'instruction_scope', 'launch')
    result = dict(engine=engine, exit=1, instruction_scope=scope,
                  scope=LAUNCH_SCOPE if scope == 'launch' else SCOPE, membership_attempts=[],
                  viewport_css_pixels=[WIDTH, HEIGHT], device_scale=args.scale)
    browser = client = sampler = counter = queue = None
    memory_observer = None
    root = None
    root_start = None
    result['started_unix'] = time.time()
    result['host_before'] = dict(cpu_count=os.cpu_count(), load_average=os.getloadavg())
    try:
        deadline = time.monotonic() + args.timeout
        png = folder / 'document.png'
        profile, cache = folder / 'profile', folder / 'cache'
        profile.mkdir()
        cache.mkdir()
        prepare_browser_profile(engine, profile, cache, args)
        api = MacCoalitionCounters()
        if engine == 'vox':
            environment = dict(VOX_PROFILE_INSTRUCTIONS='1', VOX_TEST_WINDOW='1',
                VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache), VOX_COOKIE_FILE='',
                LADYBIRD_SCREENSHOT_SCALE=str(args.scale),
                VOX_SCREENSHOT_NATIVE_LAYOUT='1' if args.scale == 2 else '0',
                VOX_CAPTURE_AUDIT_CONFIG=str(args.audit_config),
                VOX_CAPTURE_AUDIT_PATH=str(folder / 'audit.json'),
                VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds))
            environment.update(getattr(args, 'vox_environment', {}))
            # An empty value still enables native controls that test getenv().
            ambient = sorted(os.environ.keys() - clean_environment().keys() - environment.keys())
            require(not ambient, 'Remove ambient measurement controls: ' + ', '.join(ambient))
            result['environment'] = environment
            arguments = ['--enable-javascript' if getattr(args, 'vox_scripting', True) else '--disable-javascript', '--window-width', str(WIDTH), '--window-height',
                         str(HEIGHT + 84), '--screenshot', str(png), args.url]
            arguments = list(getattr(args, 'vox_arguments', [])) + arguments
            result['command'] = launch(app, arguments, folder, environment)
            root = wait_until(lambda: root_for(binary, str(png)), deadline, 'Vox launch')
        else:
            arguments = ['--no-startup-window', '--no-first-run', '--no-default-browser-check',
                '--enable-automation', '--disable-background-networking', '--disable-sync',
                getattr(args, 'brave_proxy_argument', '--no-proxy-server'),
                '--hide-scrollbars', '--force-color-profile=srgb', '--lang=en-US',
                '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE 127.0.0.1',
                '--remote-debugging-port=0', '--user-data-dir=' + str(profile)]
            arguments += getattr(args, 'brave_arguments', [])
            if getattr(args, 'brave_initial_page', False):
                arguments.remove('--no-startup-window')
                arguments.append('about:blank')
            result['command'] = launch(app, arguments, folder, {})
            endpoint = wait_until(lambda: chrome_debugger_endpoint(profile / 'DevToolsActivePort'),
                                  deadline, 'Brave debugger')
            root = wait_until(lambda: root_for(binary, str(profile)), deadline, 'Brave launch')
            port, browser_path = endpoint
            browser = CDP(f'ws://127.0.0.1:{port}{browser_path}')
            result['version'] = browser.call('Browser.getVersion')
        result['root'] = root
        existing = json.loads((folder / 'launch.json').read_text()).get('existing_processes', [])
        require(root['pid'] not in {row['pid'] for row in existing},
                'Launch reused a preexisting browser process')
        root_start = MacCounters().read(root['pid']).start
        result['root_start_ticks'] = root_start
        observer_factory = getattr(args, 'browser_memory_observer', None)
        if observer_factory:
            memory_observer = observer_factory(root['pid'], root_start, folder)
        registry = getattr(args, 'memory_guard_registry', None)
        if registry:
            publish_adopted_processes(registry, [root['pid']])
        queue = exit_watch(root['pid'])
        cid = api.resource_coalition(root['pid'])
        require(cid != api.resource_coalition(os.getpid()), 'Browser inherited observer coalition')
        result['resource_coalition'] = cid
        result['membership_before'] = membership(api, cid, app, root['pid'], deadline,
                                                 result['membership_attempts'], browser, existing)
        if registry:
            publish_adopted_processes(registry,
                [row['pid'] for row in result['membership_before']['members']
                 if row['executable'].startswith(str(app) + '/Contents/')])
        if engine == 'brave' and getattr(args, 'brave_setup', None):
            result['brave_setup'] = args.brave_setup(browser, port, deadline)
        if engine == 'vox':
            audit_capture_ownership = getattr(args, 'audit_vox_capture_ownership', False)
            capture_scans = [result['membership_before']]
            def observe_owned_tasks():
                # A process may exit during a scan. Retain partial attempts;
                # acceptance still requires a complete endpoint-matching scan.
                try:
                    scan = membership(api, cid, app, root['pid'],
                                      min(deadline, time.monotonic() + .15),
                                      result['membership_attempts'], existing_processes=existing)
                    capture_scans.append(scan)
                    if registry:
                        publish_adopted_processes(registry,
                            [row['pid'] for row in scan['members']
                             if row['executable'].startswith(str(app) + '/Contents/')])
                except (OSError, RuntimeError) as error:
                    result.setdefault('capture_ownership_scan_errors', []).append(str(error))
            if audit_capture_ownership:
                result['kernel_exit_status'] = await_exit(queue, deadline, observe_owned_tasks)
                result['capture_ownership_scans'] = capture_scans
            else:
                result['kernel_exit_status'] = await_exit(queue, deadline)
            require(result['kernel_exit_status'] == 0, 'Vox exited unsuccessfully')
            markers = parse_native_coalitions((folder / 'browser.log').read_text(), cid)
            result['native_coalition_markers'] = markers
            if audit_capture_ownership:
                result['capture_ownership_audit'] = capture_ownership_audit(capture_scans,
                                                                         markers['markers'][-1])
            value = markers['delta']['instructions']
            result['instruction_interval'] = dict(lower=value, upper=value)
            audit = json.loads((folder / 'audit.json').read_text())
        else:
            display = test_display()
            result['test_display'] = display
            if getattr(args, 'brave_initial_page', False):
                target = wait_until(lambda: next((row['targetId'] for row in
                    browser.call('Target.getTargets')['targetInfos'] if row['type'] == 'page'), None),
                    deadline, 'Brave initial page')
            else:
                target = browser.call('Target.createTarget', dict(url='about:blank', newWindow=True,
                    background=True, left=display['position'][0], top=display['position'][1],
                    width=WIDTH + 80, height=HEIGHT + 140))['targetId']
            client = CDP(f'ws://127.0.0.1:{port}/devtools/page/{target}')
            client.call('Page.enable')
            if getattr(args, 'brave_disable_javascript', False):
                client.call('Emulation.setScriptExecutionDisabled', dict(value=True))
            result['native_viewport'] = configure_brave_viewport(browser, client, target, args)
            client.call('Emulation.setFocusEmulationEnabled', dict(enabled=True))
            counter = CoalitionCounter(api, cid)
            sampler = CounterSampler(counter, .002)
            sampler.__enter__()
            navigation_at = time.monotonic()
            navigation = client.call('Page.navigate', dict(url=args.url))
            result['navigation'] = navigation
            require(not navigation.get('errorText'), 'Brave navigation failed: ' + str(navigation.get('errorText')))
            # Scalar readiness only; pixel validation follows the measured interval.
            expression = getattr(args, 'readiness_expression', None) or f'''location.href==={json.dumps(args.url)}
                && document.readyState==='complete' && document.fonts.status==='loaded'
                && innerWidth==={WIDTH} && innerHeight==={HEIGHT} && devicePixelRatio==={args.scale}
                && [...document.images].every(i=>i.complete && i.naturalWidth>0)'''
            wait_until(lambda: client.call('Runtime.evaluate', dict(expression=expression,
                       returnByValue=True))['result'].get('value') is True, deadline, 'Brave document')
            finish_capture_readiness(client, args)
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
            row_name = getattr(args, 'row_name', 'comments')
            selector = getattr(args, 'row_selector', 'tr.comtr')
            expression = '''({url:location.href,
                ready:document.readyState,viewport_width:innerWidth,viewport_height:innerHeight,
                selections:[{name:ROW_NAME,count:document.querySelectorAll(ROW_SELECTOR).length,
                elements:[...document.querySelectorAll(ROW_SELECTOR)].map(e=>({attributes:{id:e.id}}))}]})'''
            expression = expression.replace('ROW_NAME', json.dumps(row_name)).replace('ROW_SELECTOR', json.dumps(selector))
            expression = getattr(args, 'audit_expression', None) or expression
            audit = client.call('Runtime.evaluate', dict(expression=expression,
                returnByValue=True))['result']['value']
            write_json(folder / 'audit.json', audit)
            result['membership_after'] = membership(api, cid, app, root['pid'], deadline,
                                                    result['membership_attempts'], browser, existing)
            if registry:
                publish_adopted_processes(registry,
                    [row['pid'] for row in result['membership_after']['members']
                     if row['executable'].startswith(str(app) + '/Contents/')])
            browser.call('Browser.close')
            result['kernel_exit_status'] = await_exit(queue, deadline)
            require(result['kernel_exit_status'] == 0, 'Brave exited unsuccessfully')
        result['launch_instruction_interval'] = launch_instruction_interval(engine, result)
        result['navigation_scope'] = SCOPE
        result['launch_scope'] = LAUNCH_SCOPE
        validator = getattr(args, 'content_validator', None)
        if validator:
            result['content_audit'] = validator(audit)
        else:
            check_content(audit, args.url, args.expected_comments, getattr(args, 'row_name', 'comments'))
            result['comment_rows'] = len(args.expected_comments)
        result['content_exact'] = True
        if getattr(args, 'capture_reference', False):
            result.update(reference_capture=True, png_sha256=sha(png), exit=0)
            return result
        expected = getattr(args, 'expected_' + engine, None) or args.expected
        verdict = compare(expected, png, folder / 'document.diff.png', args.diff_tool)
        result.update(pixels_exact=verdict['exact'], pixel_comparison=verdict, png_sha256=sha(png))
        require(verdict['exact'], 'Captured document differs from its unchanged pixel reference')
        result['exit'] = 0
    except Exception as error:
        result.update(error=str(error), traceback=traceback.format_exc())
    finally:
        result['finished_unix'] = time.time()
        result['host_after'] = dict(cpu_count=os.cpu_count(), load_average=os.getloadavg())
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
        if memory_observer:
            try:
                result['memory'] = memory_observer.finish()
            except Exception as error:
                result.update(exit=1, memory_error=str(error))
        write_json(folder / 'result.json', result)
    return result


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='New evidence directory')
    parser.add_argument('--memory-guard-registry', type=Path,
                        help='Same private file passed to run_memory_bounded --adopt-pids-from')
    parser.add_argument('--vox-app', type=Path, default=REPO / 'Build/v/Vox.app')
    parser.add_argument('--brave-app', type=Path, default=Path('/Applications/Brave Browser.app'))
    parser.add_argument('--diff-tool', type=Path, default=REPO / 'Build/hacker-news-pixels/pixel_diff')
    parser.add_argument('--document', type=Path, default=DOCUMENT)
    parser.add_argument('--expected', type=Path)
    parser.add_argument('--home-archive', type=Path,
                        help='Sealed original home-page resources; replayed locally without downloads')
    parser.add_argument('--target-vox-fraction', type=float, default=TARGET,
                        help='Maximum Vox/Brave instruction ratio (default: .9)')
    parser.add_argument('--instruction-scope', choices=['navigation', 'launch'], default='launch',
                        help='Gate full startup-to-PNG (default); navigation is an asymmetric '
                             'window-setup diagnostic. Both intervals are recorded')
    parser.add_argument('--scale', type=int, choices=[1, 2], default=2)
    parser.add_argument('--repeat', type=int, default=3)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--settle-seconds', type=float, default=2)
    args = parser.parse_args(argv)
    if args.expected is None:
        args.expected = FIXTURES / 'expected/hacker-news-home-instructions.png' if args.home_archive else EXPECTED
    if (args.repeat < 2 or not math.isfinite(args.timeout) or args.timeout <= 0
            or not 0 <= args.settle_seconds < args.timeout
            or not 0 < args.target_vox_fraction <= 1):
        parser.error('Need at least two pairs, a positive watchdog, and a bounded nonnegative settle')
    return args


def main():
    args = parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    args.diff_tool = args.diff_tool.resolve()
    args.document = args.document.resolve()
    args.expected = args.expected.resolve()
    args.row_name, args.row_selector = 'comments', 'tr.comtr'
    if args.home_archive:
        args.home_archive = args.home_archive.resolve()
        manifest = load_archive(args.home_archive)
        require(manifest['url'] == 'https://news.ycombinator.com/', 'Expected the Hacker News home page')
        args.document = args.home_archive / 'bodies' / manifest['responses'][manifest['url']]['sha256']
        args.row_name, args.row_selector = 'stories', 'tr.athing'
    args.expected_comments = document_comments(args.document, 'athing' if args.home_archive else 'comtr')
    if args.home_archive:
        require(len(args.expected_comments) == 30, 'Home-page fixture must contain all 30 stories')
    args.audit_config = args.output / 'audit-config.json'
    write_json(args.audit_config, dict(selectors=[dict(name=args.row_name, selector=args.row_selector,
               limit=len(args.expected_comments), attributes=['id'], layout_depth=0)]))
    apps = reference_browser_apps(args.output, [('vox', args.vox_app), ('brave', args.brave_app)])
    paths = {args.document, args.expected, args.diff_tool, args.audit_config,
             args.output / 'browser-apps.json'}
    paths.update(path for path in COALITION_SERVICES if path.is_file())
    paths.update(Path(__file__).resolve().parent / name for name in (
        'hacker_news_browser_instructions.py', 'check_pixel_equality.py',
        'coalition_instruction_counts.py', 'measure_browser_instructions.py',
        'capture_brave_reference.py',
        'measure_sealed_github_instructions.py', 'pikabu_browser_instructions.py',
        'process_instruction_counts.py', 'page_archive.py', 'run_memory_bounded.py'))
    paths.add(REPO / 'tools/measure_precise_scroll.py')
    paths.update(runtime_input_paths(apps['vox'] / 'Contents/MacOS/Vox', {}))
    paths.update(path for path in (args.document.parent / ASSETS).rglob('*') if path.is_file())
    if args.home_archive:
        paths.update(path for path in args.home_archive.rglob('*') if path.is_file())
    for app in apps.values():
        paths.update(path for path in app.rglob('*') if path.is_file())
    paths.update(native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    pinned = fingerprint(paths)
    write_json(args.output / 'inputs.json', dict(files=pinned,
               scope=LAUNCH_SCOPE if args.instruction_scope == 'launch' else SCOPE,
               navigation_scope=SCOPE,
               settle_seconds=args.settle_seconds, target_vox_fraction=args.target_vox_fraction,
               instruction_scope=args.instruction_scope, launch_scope=LAUNCH_SCOPE,
               comment_ids=args.expected_comments,
               row_selector=args.row_selector,
               host=dict(cpu_count=os.cpu_count(), load_average=os.getloadavg()),
               original_scripts_retained=bool(args.home_archive),
               device_scale=args.scale, viewport_css_pixels=[WIDTH, HEIGHT],
               system=subprocess.check_output(['sw_vers'], text=True)))
    pairs = []
    with fixture_server(args.document, args.output, args.home_archive) as args.url:
        write_json(args.output / 'replay.json', dict(url=args.url, document=str(args.document),
                   network_policy='Loopback replay only; fresh caches; Cache-Control: no-store'))
        for index in range(args.repeat):
            pair = {}
            for engine in (['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox']):
                row = run_browser(engine, apps[engine], args.output / f'pair-{index+1}-{engine}', args)
                pair[engine] = row
                require(fingerprint(paths) == pinned, 'Pinned input or browser runtime changed during measurement')
                print(json.dumps(progress_record(index+1, engine, row, args.instruction_scope)), flush=True)
            pairs.append(pair)
            write_json(args.output / 'pairs.json', pairs)
    try:
        summaries = {scope: evaluate_pairs(pairs, args.target_vox_fraction, scope)
                     for scope in ('navigation', 'launch')}
        summary = dict(summaries[args.instruction_scope], scopes=summaries)
    except RuntimeError as error:
        summary = dict(passed=False, error=str(error))
    write_json(args.output / 'summary.json', summary)
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if summary['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
