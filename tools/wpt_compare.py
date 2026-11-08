#!/usr/bin/env python3
"""Run Ladybird's imported WPT testharness suite in Vox and Brave and compare timings.

usage: wpt_compare.py --output Build/wpt-brave-UNIQUE [--include css/css-grid ...]
                      [--limit N] [--browsers vox,brave] [--chunk-size 250]

Run under run_memory_bounded.py. The test list is every expectation under
Ladybird's Tests/LibWeb/Text/expected/wpt-import (`name@query.txt` names the
`name.html?query` variant). A local static server stands in for wptserve: it
serves Tests/LibWeb/Text/input/wpt-import as the WPT root with `.headers` files,
a small `.sub.` substitution subset and `Cache-Control: no-store`; Python
handlers are absent, so tests needing them fail in both browsers alike.
testharness.js is served with Ladybird's CI modifications reverted (see
HARNESS_PATCHES) so neither browser takes its `internals` shortcuts.

Both browsers load the same bytes. The served testharnessreport.js disables the
result table (as wptrunner does), posts each top-level document's results to the
server and navigates to the next test, so one fresh-profile window runs a whole
chunk after an unrecorded warm-up page. Chunks alternate the browser that runs
first. A test whose document is never requested (NO_DOCUMENT), whose harness
does not announce execution (NO_HARNESS: no testharnessreport.js request
and no immediate, document-matched alive ping), that does not report by its harness
timeout plus a grace period (HARD_TIMEOUT), whose browser exits (CRASH) or
whose browser's process group exceeds --browser-memory-gib RSS (MEMORY_LIMIT,
sampled every 250 ms) is recorded as such and the browser is relaunched at the
next test. Per-test time
is measured by the server from the test document request to its result post.
The canonical Vox bundle is held under its shared publication lease.
"""
import argparse
import contextlib
import hashlib
import json
import math
import mimetypes
import os
from pathlib import Path
import re
import signal
import statistics
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, unquote, urlsplit

from browser_bundle_lease import canonical_bundle_lease
from wpt_fixtures import export_fixtures, verify_fixture_tree

REPO = Path(__file__).resolve().parents[1]
LADYBIRD = Path(os.environ.get('LADYBIRD_SOURCE_DIR', REPO.parent / '3rd' / 'ladybird'))
TEXT_TESTS = LADYBIRD / 'Tests' / 'LibWeb' / 'Text'
VOX = REPO / 'Build' / 'v' / 'Vox.app' / 'Contents' / 'MacOS' / 'Vox'
BRAVE = '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'
RUNNER_PREFIX = '/__vox_wpt__/'
DOCUMENT_EXTENSIONS = ('.html', '.htm', '.xhtml', '.xht', '.svg')
HARNESS_STATUSES = ('OK', 'ERROR', 'TIMEOUT', 'PRECONDITION_FAILED')
SUBTEST_STATUSES = ('PASS', 'FAIL', 'TIMEOUT', 'NOTRUN', 'PRECONDITION_FAILED')
MESSAGE_LIMIT = 300
SUITE_SCOPE = dict(
    name='ladybird-imported-testharness', full_upstream_wpt=False,
    selection='Ladybird Tests/LibWeb/Text/expected/wpt-import expectations',
    server='static HTTP; no Python handlers, HTTPS, or WPT multi-origin configuration',
    excluded_types=['reftest', 'print-reftest', 'crashtest', 'wdspec', 'test262',
                    'aamtest', 'manual', 'visual'],
    denominator='reported runtime subtests in selected imported files only')
CONTENT_TYPES = {
    '.html': 'text/html', '.htm': 'text/html', '.xhtml': 'application/xhtml+xml',
    '.xht': 'application/xhtml+xml', '.svg': 'image/svg+xml', '.js': 'text/javascript',
    '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json',
    '.xml': 'application/xml', '.txt': 'text/plain', '.wasm': 'application/wasm',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.otf': 'font/otf',
    '.webp': 'image/webp', '.avif': 'image/avif', '.vtt': 'text/vtt',
}
NAVIGATION_PROXY_VARIABLES = ('ALL_PROXY', 'HTTP_PROXY', 'HTTPS_PROXY', 'all_proxy',
                              'http_proxy', 'https_proxy', 'VOX_PROXY')

REPORT_SCRIPT = r"""(function () {
    // Only the top-level test document reports; workers, frames and popups
    // that load testharness.js belong to the test that created them.
    if (typeof window === "undefined" || window.top !== window || window.opener)
        return;
    setup({ output: false });
    // Vox reuses subresources across navigations despite no-store, so the
    // server cannot rely on seeing this script requested. Announce execution
    // before a synchronous test can occupy the main thread and delay timers.
    // Include document identity so a late request cannot start the next test.
    var alive = new XMLHttpRequest();
    alive.open("POST", "%(alive)s");
    alive.send(location.pathname + location.search);
    add_completion_callback(function (tests, harness_status) {
        var finished = performance.now();
        function text(value) {
            return value === null || value === undefined ? null : String(value).slice(0, %(limit)d);
        }
        var payload = JSON.stringify({
            url: location.pathname + location.search,
            finished_ms: finished,
            harness: { status: harness_status.status, message: text(harness_status.message) },
            tests: tests.map(function (test) {
                return { name: String(test.name), status: test.status, message: text(test.message) };
            })
        });
        setTimeout(function () {
            var request = new XMLHttpRequest();
            request.open("POST", "%(result)s");
            request.setRequestHeader("Content-Type", "application/json");
            request.onload = function () {
                var next = JSON.parse(request.responseText).next;
                // Vox implements neither location.replace() nor assign().
                if (next)
                    location.href = next;
            };
            request.send(payload);
        }, 0);
    });
})();
""" % dict(limit=MESSAGE_LIMIT, result=RUNNER_PREFIX + 'result', alive=RUNNER_PREFIX + 'alive')


# Each launch first runs this page so that no measured test pays for loading
# the harness into a cold process. Its result is not recorded.
WARMUP = dict(id='__warmup__', url=RUNNER_PREFIX + 'warmup.html', harness_timeout=10)
WARMUP_PAGE = b"""<!doctype html><title>warm-up</title>
<script src="/resources/testharness.js"></script>
<script src="/resources/testharnessreport.js"></script>
<script>test(function () { assert_true(true); }, "warm-up");</script>
"""

# Ladybird's vendored testharness.js raises the harness timeouts for its CI and
# takes shortcuts (no assertion messages or stacks, a runner timeout hook) when
# `internals` exists. Vox exposes an `internals` object to pages, so serve both
# browsers the upstream behaviour instead.
HARNESS_PATCHES = (
    ('"normal":150000', '"normal":10000'),
    ('"long":300000', '"long":60000'),
    ('globalThis.internals', 'globalThis.__wpt_compare_no_internals'),
)


def upstream_testharness(source):
    for old, new in HARNESS_PATCHES:
        if old not in source:
            raise ValueError(f'testharness.js no longer contains {old!r}')
        source = source.replace(old, new)
    return source


def test_url(relative_path, query=''):
    return '/' + quote(relative_path, safe='/') + ('?' + quote(query, safe='=&') if query else '')


def normalized_target(target):
    parts = urlsplit(target)
    return unquote(parts.path) + ('?' + unquote(parts.query) if parts.query else '')


def harness_timeout_seconds(source):
    if re.search(r'''<meta[^>]*name=["']?timeout["']?[^>]*content=["']?long''', source, re.I) \
            or re.search(r'''<meta[^>]*content=["']?long["']?[^>]*name=["']?timeout''', source, re.I) \
            or re.search(r'META:\s*timeout=long', source):
        return 60
    return 10


def discover_tests(text_root=TEXT_TESTS, includes=()):
    """Return the imported testharness tests named by Ladybird's expectations."""
    expected_root = text_root / 'expected' / 'wpt-import'
    input_root = text_root / 'input' / 'wpt-import'
    tests = []
    for expectation in sorted(expected_root.rglob('*.txt')):
        relative = expectation.relative_to(expected_root).with_suffix('').as_posix()
        directory, _, name = relative.rpartition('/')
        name, _, query = name.partition('@')
        base = f'{directory}/{name}' if directory else name
        document = next((input_root / (base + extension) for extension in DOCUMENT_EXTENSIONS
                         if (input_root / (base + extension)).is_file()), None)
        if document is None:
            continue
        test_id = relative.replace('@', '?', 1) if query else relative
        if includes and not any(test_id == prefix or test_id.startswith(prefix.rstrip('/') + '/')
                                for prefix in includes):
            continue
        source = document.read_text(errors='replace')
        path = document.relative_to(input_root).as_posix()
        tests.append(dict(id=test_id, url=test_url(path, query), path=path,
                          harness_timeout=harness_timeout_seconds(source)))
    return tests


def parse_headers_file(path):
    headers = []
    if path.is_file():
        for line in path.read_text(errors='replace').splitlines():
            name, separator, value = line.partition(':')
            if separator and name.strip():
                headers.append((name.strip(), value.strip()))
    return headers


def substitute(body, host, port):
    """Apply the wptserve `.sub.` templates these single-origin runs can honour."""
    def replace(match):
        expression = match.group(1).strip()
        if expression in ('host', 'domains[]', 'location[hostname]'):
            return host
        if expression.startswith('domains['):
            # A distinct loopback name keeps www-style domains cross-origin.
            return 'localhost'
        if re.fullmatch(r'ports\[http\]\[\d+\]', expression) or expression == 'location[port]':
            return str(port)
        if expression == 'location[scheme]':
            return 'http'
        if expression in ('location[host]', 'location[server]'):
            return f'{host}:{port}' if expression == 'location[host]' else f'http://{host}:{port}'
        return match.group(0)
    return re.sub(r'{{([^}]*)}}', replace, body.decode('latin-1')).encode('latin-1')


class Limits:
    def __init__(self, startup=30, navigation=10, harness_start=5, grace=10, memory_bytes=4 << 30):
        self.startup = startup
        self.navigation = navigation
        self.harness_start = harness_start
        self.grace = grace
        self.memory_bytes = memory_bytes


class Session:
    """One browser launch running consecutive tests from a chunk."""

    def __init__(self, browser, tests, start, records, launch='', now=None, warmup=True):
        self.browser = browser
        self.tests = tests
        self.index = start
        self.records = records
        self.launch = launch
        self.warming = warmup
        self.launched_at = time.monotonic() if now is None else now
        self.active_since = self.launched_at
        self.document_requested_at = None
        self.harness_seen_at = None
        self.first_of_launch = True
        self.finished = start >= len(tests)
        self.aborted = False

    @property
    def current(self):
        if self.finished or self.aborted:
            return None
        return WARMUP if self.warming else self.tests[self.index]

    def advance(self, now):
        """Move to the next test and return its URL, or None at the chunk's end."""
        if self.warming:
            self.warming = False
        else:
            self.index += 1
            self.first_of_launch = False
        self.active_since = now
        self.document_requested_at = None
        self.harness_seen_at = None
        if self.index >= len(self.tests):
            self.finished = True
            return None
        return self.tests[self.index]['url']

    def deadline(self, limits):
        """Return when the current test stops waiting, and the outcome it then gets.

        Each phase is bounded separately: a browser that never requests the
        test document, a document whose harness never starts (Vox does not run
        scripts in standalone SVG documents), and a harness that does not report
        within its own timeout. The harness has started once the document
        requests testharnessreport.js or that script's alive ping arrives.
        """
        if self.document_requested_at is None:
            return self.active_since + (limits.startup if self.first_of_launch
                                        else limits.navigation), 'NO_DOCUMENT'
        if self.harness_seen_at is None:
            return self.document_requested_at + limits.harness_start, 'NO_HARNESS'
        return self.harness_seen_at + self.current['harness_timeout'] + limits.grace, \
            'HARD_TIMEOUT'


class Runner:
    def __init__(self, request_log=None):
        self.condition = threading.Condition()
        self.session = None
        self.unexpected_posts = 0
        self.request_log = request_log
        self.started = time.monotonic()

    def log_request(self, method, target, status):
        if self.request_log is None:
            return
        with self.condition:
            session = self.session
            test = session.current if session else None
            self.request_log.write(f"{time.monotonic() - self.started:.3f}\t{session.browser if session else '-'}"
                                   f"\t{test['id'] if test else '-'}\t{method}\t{status}\t{target}\n")

    def begin(self, session):
        with self.condition:
            self.session = session

    def note_request(self, target):
        with self.condition:
            session = self.session
            test = session.current if session else None
            if test is None:
                return
            if session.document_requested_at is None:
                if normalized_target(target) == normalized_target(test['url']):
                    session.document_requested_at = time.monotonic()
            elif urlsplit(target).path == '/resources/testharnessreport.js':
                self.note_harness()

    def note_harness(self, target=None):
        with self.condition:
            session = self.session
            if session and session.current and session.document_requested_at is not None \
                    and session.harness_seen_at is None:
                if target is not None and normalized_target(target) != normalized_target(session.current['url']):
                    return
                session.harness_seen_at = time.monotonic()
                self.condition.notify_all()

    def accept(self, payload):
        now = time.monotonic()
        with self.condition:
            session = self.session
            test = session.current if session else None
            if test is None:
                self.unexpected_posts += 1
                return None
            if session.warming:
                next_url = session.advance(time.monotonic())
                self.condition.notify_all()
                return next_url
            requested = session.document_requested_at
            session.records.append(dict(
                browser=session.browser, test=test['id'], outcome='COMPLETE',
                harness=HARNESS_STATUSES[payload['harness']['status']]
                if payload['harness']['status'] in range(len(HARNESS_STATUSES)) else 'UNKNOWN',
                harness_message=payload['harness'].get('message'),
                subtests=[dict(name=item['name'], status=SUBTEST_STATUSES[item['status']]
                               if item['status'] in range(len(SUBTEST_STATUSES)) else 'UNKNOWN',
                               message=item.get('message')) for item in payload['tests']],
                reported_url=payload.get('url'),
                url_matches=normalized_target(payload.get('url') or '') == normalized_target(test['url']),
                document_ms=None if requested is None else round((now - requested) * 1000, 3),
                cycle_ms=round((now - session.active_since) * 1000, 3),
                page_ms=payload.get('finished_ms'),
                launch=session.launch, first_of_launch=session.first_of_launch))
            next_url = session.advance(time.monotonic())
            self.condition.notify_all()
            return next_url

    def abandon(self, session, outcome):
        """Record the current test as failed to report and stop accepting its posts."""
        with self.condition:
            test = session.current
            if test is None:
                return None
            if session.warming:
                session.aborted = True
                self.condition.notify_all()
                raise RunAborted(f'{session.browser} launch {session.launch} could not run the '
                                   f'warm-up test ({outcome})')
            session.records.append(dict(
                browser=session.browser, test=test['id'], outcome=outcome, harness=None,
                subtests=[], document_ms=None,
                cycle_ms=round((time.monotonic() - session.active_since) * 1000, 3),
                launch=session.launch, first_of_launch=session.first_of_launch,
                document_requested=session.document_requested_at is not None,
                harness_seen=session.harness_seen_at is not None))
            session.aborted = True
            self.condition.notify_all()
            return session.index + 1


def make_handler(runner, root, host, port_holder):
    root = root.resolve()
    testharness = upstream_testharness((root / 'resources' / 'testharness.js').read_text()).encode()

    class Handler(BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *args):
            pass

        def send_body(self, status, body, content_type, extra=()):
            runner.log_request(self.command, self.path, status)
            self.send_response(status)
            names = {name.lower() for name, _ in extra}
            if 'content-type' not in names:
                self.send_header('Content-Type', content_type)
            for name, value in extra:
                self.send_header(name, value)
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            if self.command != 'HEAD':
                self.wfile.write(body)

        def resolve(self):
            path = unquote(urlsplit(self.path).path)
            candidate = (root / path.lstrip('/')).resolve()
            if candidate != root and root not in candidate.parents:
                return None
            return candidate if candidate.is_file() else None

        def do_GET(self):
            runner.note_request(self.path)
            path = urlsplit(self.path).path
            if path == '/resources/testharnessreport.js':
                return self.send_body(200, REPORT_SCRIPT.encode(), 'text/javascript')
            if path == '/resources/testharness.js':
                return self.send_body(200, testharness, 'text/javascript')
            if path == WARMUP['url']:
                return self.send_body(200, WARMUP_PAGE, 'text/html')
            file = self.resolve()
            if file is None:
                return self.send_body(404, b'Not found', 'text/plain')
            body = file.read_bytes()
            if '.sub.' in file.name:
                body = substitute(body, host, port_holder[0])
            content_type = CONTENT_TYPES.get(file.suffix.lower()) \
                or mimetypes.guess_type(file.name)[0] or 'application/octet-stream'
            headers = parse_headers_file(file.parent / '__dir__.headers') \
                + parse_headers_file(file.with_name(file.name + '.headers'))
            self.send_body(200, body, content_type, headers)

        do_HEAD = do_GET

        def do_POST(self):
            length = int(self.headers.get('Content-Length') or 0)
            body = self.rfile.read(length) if length else b''
            path = urlsplit(self.path).path
            if path == RUNNER_PREFIX + 'alive':
                runner.note_harness(body.decode('utf-8', errors='replace'))
                return self.send_body(204, b'', 'text/plain')
            if path != RUNNER_PREFIX + 'result':
                return self.send_body(404, b'Not found', 'text/plain')
            try:
                payload = json.loads(body)
            except ValueError:
                return self.send_body(400, b'Invalid result', 'text/plain')
            next_url = runner.accept(payload)
            self.send_body(200, json.dumps(dict(next=next_url)).encode(), 'application/json')

    return Handler


class Server(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        # Killing a browser between tests resets its idle connections.
        if not isinstance(sys.exc_info()[1], (ConnectionResetError, BrokenPipeError)):
            super().handle_error(request, client_address)


def sha256(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as file:
        for block in iter(lambda: file.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def clean_environment():
    env = dict(os.environ)
    for name in list(env):
        if name in NAVIGATION_PROXY_VARIABLES or name.startswith(('DYLD_', 'VOX_PROFILE_')) \
                or name in ('LADYBIRD_ENABLE_SNAPSHOT_CACHE', 'LADYBIRD_SCREENSHOT_DELAY_SECONDS'):
            env.pop(name)
    return env


def vox_launch(executable, profile, url, width, height):
    profile.mkdir(parents=True)
    (profile / 'profile').mkdir()
    (profile / 'cache').mkdir()
    # Loopback fixtures are outside the optimized-site allowlist.
    (profile / 'profile' / 'settings.json').write_text('{"allow_any_site":true}\n')
    env = clean_environment()
    env.update(VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(profile / 'profile'),
               LADYBIRD_CACHE_DIR=str(profile / 'cache'))
    return [str(executable), '--enable-javascript', '--window-width', str(width),
            '--window-height', str(height), url], env


def brave_launch(executable, profile, url, width, height):
    profile.mkdir(parents=True)
    command = [str(executable), '--no-first-run', '--no-default-browser-check',
               '--disable-background-networking', '--disable-sync', '--disable-component-update',
               '--disable-background-timer-throttling', '--disable-renderer-backgrounding',
               '--disable-backgrounding-occluded-windows', '--force-color-profile=srgb',
               '--lang=en-US', f'--user-data-dir={profile}', f'--window-size={width},{height}',
               '--window-position=40,40', '--new-window', url]
    return command, clean_environment()


def group_rss(ps_output, group):
    """Sum the RSS bytes of one process group from `ps -axo pgid=,rss=` output."""
    total = 0
    for line in ps_output.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0] == str(group):
            total += int(fields[1]) * 1024
    return total


def browser_rss(process):
    output = subprocess.run(['ps', '-axo', 'pgid=,rss='], capture_output=True, text=True).stdout
    return group_rss(output, process.pid)


def signal_process_group(pid, number, killpg=os.killpg):
    """Signal a browser's process group that may already have exited.

    macOS reports EPERM rather than ESRCH when the group's only remaining
    member is the not-yet-reaped leader, so both mean there is nothing to stop.
    """
    try:
        killpg(pid, number)
    except (ProcessLookupError, PermissionError):
        pass


def stop_process_group(process, marker):
    if process.poll() is None:
        signal_process_group(process.pid, signal.SIGTERM)
        try:
            process.wait(5)
        except subprocess.TimeoutExpired:
            signal_process_group(process.pid, signal.SIGKILL)
            process.wait(5)
    # Helpers that left the group still name the private profile directory.
    subprocess.run(['pkill', '-KILL', '-f', marker], stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, check=False)


class RunAborted(RuntimeError):
    pass


def run_chunk(runner, browser, executable, digest, tests, records, base_url, output, chunk_index,
              width, height, limits):
    start = 0
    launch = 0
    started = time.monotonic()
    while start < len(tests):
        # The shared bundle can be rebuilt by other sessions; never mix builds.
        if sha256(executable) != digest:
            raise RunAborted(f'{executable} changed before chunk {chunk_index} launch {launch}')
        launch_id = f'{browser}-{chunk_index:03d}-{launch:03d}'
        profile = output / 'profiles' / launch_id
        url = base_url + WARMUP['url']
        command, env = (vox_launch if browser == 'vox' else brave_launch)(
            executable, profile, url, width, height)
        log = open(output / 'logs' / f'{launch_id}.log', 'wb')
        session = Session(browser, tests, start, records, launch_id)
        runner.begin(session)
        process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT,
                                   stdin=subprocess.DEVNULL, start_new_session=True)
        next_start = None
        next_sample = time.monotonic()
        try:
            while next_start is None:
                with runner.condition:
                    if session.finished:
                        break
                    deadline, outcome = session.deadline(limits)
                    remaining = deadline - time.monotonic()
                    if process.poll() is not None or remaining <= 0:
                        # The condition's lock is reentrant, so this records the
                        # outcome atomically with the decision.
                        next_start = runner.abandon(
                            session, 'CRASH' if process.poll() is not None else outcome)
                        break
                    runner.condition.wait(min(remaining, 0.25))
                # A runaway page must not reach the memory guard, which would
                # stop the whole run. Sample outside the lock so that requests
                # being timed never wait for ps.
                if limits.memory_bytes and time.monotonic() >= next_sample:
                    next_sample = time.monotonic() + 0.25
                    if browser_rss(process) > limits.memory_bytes:
                        next_start = runner.abandon(session, 'MEMORY_LIMIT')
            if next_start is None:
                next_start = len(tests)
        finally:
            stop_process_group(process, str(profile))
            log.close()
        start = next_start
        launch += 1
    return dict(browser=browser, chunk=chunk_index, tests=len(tests), launches=launch,
                seconds=round(time.monotonic() - started, 3))


def percentile(values, fraction):
    ordered = sorted(values)
    if not ordered:
        return None
    position = (len(ordered) - 1) * fraction
    lower = math.floor(position)
    upper = min(lower + 1, len(ordered) - 1)
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def browser_summary(records):
    harness = {}
    subtests = {}
    outcomes = {}
    for record in records:
        outcomes[record['outcome']] = outcomes.get(record['outcome'], 0) + 1
        if record['harness']:
            harness[record['harness']] = harness.get(record['harness'], 0) + 1
        for subtest in record['subtests']:
            subtests[subtest['status']] = subtests.get(subtest['status'], 0) + 1
    total = sum(subtests.values())
    return dict(tests=len(records), outcomes=outcomes, harness=harness, subtests=subtests,
                subtest_total=total,
                subtest_pass_rate=None if not total else round(subtests.get('PASS', 0) / total, 4),
                tests_all_pass=sum(1 for record in records if record['harness'] == 'OK'
                                   and record['subtests']
                                   and all(item['status'] == 'PASS' for item in record['subtests'])))


def completed_cleanly(record):
    return record is not None and record['outcome'] == 'COMPLETE' and record['harness'] == 'OK' \
        and record['document_ms'] is not None \
        and not any(item['status'] in ('TIMEOUT', 'NOTRUN') for item in record['subtests'])


def same_results(left, right):
    return sorted((item['name'], item['status']) for item in left['subtests']) \
        == sorted((item['name'], item['status']) for item in right['subtests'])


def timing_comparison(pairs):
    if not pairs:
        return dict(tests=0)
    vox = [pair[1]['document_ms'] for pair in pairs]
    brave = [pair[2]['document_ms'] for pair in pairs]
    # A 1 ms floor keeps sub-millisecond server timings from dominating ratios.
    ratios = [max(left, 1) / max(right, 1) for left, right in zip(vox, brave)]
    return dict(
        tests=len(pairs),
        vox_total_ms=round(sum(vox), 1), brave_total_ms=round(sum(brave), 1),
        total_ratio=round(sum(vox) / sum(brave), 3) if sum(brave) else None,
        vox_median_ms=round(statistics.median(vox), 2),
        brave_median_ms=round(statistics.median(brave), 2),
        ratio_geomean=round(math.exp(sum(math.log(value) for value in ratios) / len(ratios)), 3),
        ratio_median=round(statistics.median(ratios), 3),
        ratio_p10=round(percentile(ratios, .1), 3), ratio_p90=round(percentile(ratios, .9), 3),
        vox_faster=sum(1 for value in ratios if value < 1))


def summarize(tests, records, chunks):
    by_browser = {}
    for record in records:
        by_browser.setdefault(record['browser'], {})[record['test']] = record
    vox = by_browser.get('vox', {})
    brave = by_browser.get('brave', {})
    both = [(test['id'], vox.get(test['id']), brave.get(test['id'])) for test in tests]
    clean = [pair for pair in both if completed_cleanly(pair[1]) and completed_cleanly(pair[2])]
    identical = [pair for pair in clean if same_results(pair[1], pair[2])]
    directories = {}
    for pair in clean:
        directories.setdefault(pair[0].split('/')[0], []).append(pair)
    slowest = sorted(identical, key=lambda pair: max(pair[1]['document_ms'], 1)
                     / max(pair[2]['document_ms'], 1), reverse=True)[:25]
    largest = sorted(identical, key=lambda pair: pair[1]['document_ms'] - pair[2]['document_ms'],
                     reverse=True)[:25]
    return dict(
        suite_scope=SUITE_SCOPE,
        tests=len(tests),
        browsers={name: browser_summary(list(results.values())) for name, results in by_browser.items()},
        wall_seconds={name: round(sum(chunk['seconds'] for chunk in chunks if chunk['browser'] == name), 1)
                      for name in by_browser},
        launches={name: sum(chunk['launches'] for chunk in chunks if chunk['browser'] == name)
                  for name in by_browser},
        both_clean=timing_comparison(clean),
        identical_results=timing_comparison(identical),
        directories={name: timing_comparison(pairs) for name, pairs in sorted(directories.items())},
        slowest_ratio=[dict(test=pair[0], vox_ms=pair[1]['document_ms'], brave_ms=pair[2]['document_ms'])
                       for pair in slowest],
        largest_difference=[dict(test=pair[0], vox_ms=pair[1]['document_ms'],
                                 brave_ms=pair[2]['document_ms']) for pair in largest])


def format_report(summary, identity):
    vox_digest = next((digest for path, digest in identity['pinned'].items()
                       if path.endswith('/Contents/MacOS/Vox')), None)
    receipt = identity.get('vox_receipt') or {}
    lines = ['# Imported WPT subset: Vox vs Brave', '',
             '**Scope: Ladybird-imported testharness subset, not full upstream WPT.** '
             'The static HTTP server lacks Python handlers, HTTPS, and WPT multi-origin setup. '
             'Reported subtest percentages apply only to this selected cohort.', '',
             f"Started {identity['started']}, {summary['tests']} tests from Ladybird "
             f"`{identity['ladybird_head'][:12]}` wpt-import; host {identity['host_cpus']} CPUs, "
             f"load {identity['load_start']} → {identity['load_end']}.", '',
             f"Vox `{(vox_digest or 'not run')[:12]}` (C mode {receipt.get('c_compile', {}).get('mode')}, "
             f"head `{receipt.get('inputs', {}).get('head', '')[:12]}`); {identity.get('brave_version')}.", '']
    if identity.get('aborted') or identity.get('changed_inputs'):
        lines += [f"**Incomplete:** {identity.get('aborted') or 'inputs changed: ' + str(identity['changed_inputs'])}", '']
    lines += ['## Conformance', '',
              '| | Vox | Brave |', '|---|---:|---:|']
    vox = summary['browsers'].get('vox', {})
    brave = summary['browsers'].get('brave', {})

    def row(label, getter):
        lines.append(f'| {label} | {getter(vox)} | {getter(brave)} |')
    row('Tests run', lambda item: item.get('tests', 0))
    row('Harness OK', lambda item: item.get('harness', {}).get('OK', 0))
    row('Harness ERROR', lambda item: item.get('harness', {}).get('ERROR', 0))
    row('Harness TIMEOUT', lambda item: item.get('harness', {}).get('TIMEOUT', 0))
    row('Document never requested', lambda item: item.get('outcomes', {}).get('NO_DOCUMENT', 0))
    row('Harness never started', lambda item: item.get('outcomes', {}).get('NO_HARNESS', 0))
    row('No report after harness timeout', lambda item: item.get('outcomes', {}).get('HARD_TIMEOUT', 0))
    row('Browser exited', lambda item: item.get('outcomes', {}).get('CRASH', 0))
    row('Browser over memory limit', lambda item: item.get('outcomes', {}).get('MEMORY_LIMIT', 0))
    row('Tests with every subtest passing', lambda item: item.get('tests_all_pass', 0))
    row('Subtests passing', lambda item: f"{item.get('subtests', {}).get('PASS', 0)} / {item.get('subtest_total', 0)}")
    row('Subtest pass rate', lambda item: f"{100 * (item.get('subtest_pass_rate') or 0):.1f}%")
    lines.append(f"| Browser launches | {summary['launches'].get('vox', 0)} | {summary['launches'].get('brave', 0)} |")
    lines.append(f"| Suite wall clock (incl. launches, timeouts) | {summary['wall_seconds'].get('vox', 0)} s "
                 f"| {summary['wall_seconds'].get('brave', 0)} s |")
    lines += ['', '## Timing', '',
              'Per-test time is from the test document request to its result post, measured by the server.',
              'Ratios are Vox / Brave per test (1 ms floor); >1 means Vox is slower.', '',
              '| Set | Tests | Vox total | Brave total | Total ratio | Geomean ratio | Median ratio | p10–p90 | Vox faster |',
              '|---|---:|---:|---:|---:|---:|---:|---|---:|']
    for label, key in (('Both harness OK, no timeouts', 'both_clean'),
                       ('…and identical subtest results', 'identical_results')):
        item = summary[key]
        if item['tests']:
            lines.append(f"| {label} | {item['tests']} | {item['vox_total_ms'] / 1000:.1f} s | "
                         f"{item['brave_total_ms'] / 1000:.1f} s | {item['total_ratio']}× | "
                         f"{item['ratio_geomean']}× | {item['ratio_median']}× | "
                         f"{item['ratio_p10']}–{item['ratio_p90']} | {item['vox_faster']} |")
    lines += ['', '### By directory (both harness OK, no timeouts)', '',
              '| Directory | Tests | Vox total | Brave total | Total ratio | Geomean ratio |',
              '|---|---:|---:|---:|---:|---:|']
    for name, item in sorted(summary['directories'].items(), key=lambda entry: -entry[1]['tests']):
        lines.append(f"| {name} | {item['tests']} | {item['vox_total_ms'] / 1000:.2f} s | "
                     f"{item['brave_total_ms'] / 1000:.2f} s | {item['total_ratio']}× | {item['ratio_geomean']}× |")
    for title, key in (('Largest slowdowns (identical results, by ratio)', 'slowest_ratio'),
                       ('Largest absolute differences (identical results)', 'largest_difference')):
        lines += ['', f'### {title}', '', '| Test | Vox ms | Brave ms |', '|---|---:|---:|']
        lines += [f"| `{item['test']}` | {item['vox_ms']:.1f} | {item['brave_ms']:.1f} |"
                  for item in summary[key][:15]]
    return '\n'.join(lines) + '\n'


def chunks_of(tests, size):
    return [tests[index:index + size] for index in range(0, len(tests), size)]


def main():
    # Browsers run in their own sessions; unwinding stops them on SIGTERM.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--include', action='append', default=[],
                        help='Test id prefix such as dom/nodes (repeatable)')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--ladybird-ref', help='Read imported fixtures at this Git revision without changing the upstream checkout')
    parser.add_argument('--fixture-cache', type=Path, default=Path.home() / '.cache/vox/wpt')
    parser.add_argument('--require-all-pass', action='store_true',
                        help='Exit nonzero unless every selected case and subtest passes in every requested browser')
    parser.add_argument('--browsers', default='vox,brave')
    parser.add_argument('--chunk-size', type=int, default=250)
    parser.add_argument('--vox', type=Path, default=VOX)
    parser.add_argument('--brave', type=Path, default=Path(BRAVE))
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=768)
    parser.add_argument('--startup-seconds', type=float, default=30,
                        help='Wait for a fresh browser to request its first test')
    parser.add_argument('--navigation-seconds', type=float, default=10,
                        help='Wait for the next test document after a result')
    parser.add_argument('--harness-start-seconds', type=float, default=5,
                        help='Wait for the harness to start after the document')
    parser.add_argument('--grace-seconds', type=float, default=10,
                        help='Wait beyond the harness timeout for its report')
    parser.add_argument('--browser-memory-gib', type=float, default=4,
                        help='Stop a browser whose process group exceeds this RSS')
    args = parser.parse_args()
    browsers = [name.strip() for name in args.browsers.split(',') if name.strip()]
    if not browsers or any(name not in ('vox', 'brave') for name in browsers):
        parser.error('--browsers takes vox and/or brave')
    if args.output.exists():
        parser.error(f'{args.output} already exists')
    args.fixture_root = None
    args.fixture_manifest = None
    args.text_root = TEXT_TESTS
    if args.ladybird_ref:
        args.fixture_root, args.fixture_manifest = export_fixtures(
            LADYBIRD, args.ladybird_ref, args.fixture_cache)
        args.text_root = args.fixture_root / 'Tests/LibWeb/Text'
    tests = discover_tests(args.text_root, includes=args.include)
    if args.limit:
        tests = tests[:args.limit]
    if not tests:
        parser.error('no tests selected')
    executables = dict(vox=args.vox.resolve(), brave=args.brave)
    for name in browsers:
        if not Path(executables[name]).is_file():
            parser.error(f'{name} executable not found: {executables[name]}')
    # Hold the shared read lease on the canonical bundle so that it cannot be
    # republished between the launches of one run.
    lease = canonical_bundle_lease(executables['vox'].parents[2]) if 'vox' in browsers \
        else contextlib.nullcontext()
    with lease:
        return run(args, tests, browsers, executables)


def run(args, tests, browsers, executables):
    (args.output / 'logs').mkdir(parents=True)
    (args.output / 'profiles').mkdir()
    (args.output / 'tests.json').write_text(json.dumps(tests, indent=1) + '\n')

    pinned = {}
    if 'vox' in browsers:
        for path in [executables['vox'], *sorted(executables['vox'].parent.glob('*'))]:
            if path.is_file():
                pinned[str(path)] = sha256(path)
    if 'brave' in browsers:
        pinned[str(executables['brave'])] = sha256(executables['brave'])
    report_root = args.text_root / 'input' / 'wpt-import'
    identity = dict(
        suite_scope=SUITE_SCOPE,
        started=time.strftime('%Y-%m-%dT%H:%M:%S%z'), argv=sys.argv,
        ladybird_head=args.fixture_manifest['revision'] if args.fixture_manifest else subprocess.run(
            ['git', '-C', str(LADYBIRD), 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip(),
        fixture_manifest=args.fixture_manifest,
        wpt_root=str(report_root), host_cpus=os.cpu_count(),
        load_start=[round(value, 2) for value in os.getloadavg()],
        brave_version=subprocess.run([str(executables['brave']), '--version'], capture_output=True,
                                     text=True).stdout.strip() if 'brave' in browsers else None,
        vox_receipt=json.loads((REPO / 'Build' / 'production-build' / 'latest.json').read_text())
        if 'vox' in browsers and (REPO / 'Build' / 'production-build' / 'latest.json').is_file() else None,
        pinned=pinned, width=args.width, height=args.height, chunk_size=args.chunk_size,
        limits=dict(startup=args.startup_seconds, navigation=args.navigation_seconds,
                    harness_start=args.harness_start_seconds, grace=args.grace_seconds,
                    browser_memory_gib=args.browser_memory_gib))
    limits = Limits(args.startup_seconds, args.navigation_seconds, args.harness_start_seconds,
                    args.grace_seconds, int(args.browser_memory_gib * (1 << 30)))

    request_log = open(args.output / 'requests.log', 'w', buffering=1)
    runner = Runner(request_log)
    host = '127.0.0.1'
    port_holder = [0]
    server = Server((host, 0), make_handler(runner, report_root, host, port_holder))
    port_holder[0] = server.server_address[1]
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base_url = f'http://{host}:{port_holder[0]}'
    identity['base_url'] = base_url

    records = []
    chunk_results = []
    results_file = open(args.output / 'results.jsonl', 'w')
    written = 0
    aborted = None
    try:
        for chunk_index, chunk in enumerate(chunks_of(tests, args.chunk_size)):
            if args.fixture_manifest:
                verify_fixture_tree(args.fixture_root, args.fixture_manifest)
            order = browsers if chunk_index % 2 == 0 else list(reversed(browsers))
            for browser in order:
                result = run_chunk(runner, browser, executables[browser],
                                   pinned[str(executables[browser])], chunk, records, base_url,
                                   args.output, chunk_index, args.width, args.height, limits)
                chunk_results.append(result)
                for record in records[written:]:
                    results_file.write(json.dumps(record) + '\n')
                written = len(records)
                results_file.flush()
                print(f"[{time.strftime('%H:%M:%S')}] chunk {chunk_index + 1}/{math.ceil(len(tests) / args.chunk_size)}"
                      f" {browser}: {result['tests']} tests in {result['seconds']} s,"
                      f" {result['launches']} launch(es)", flush=True)
    except (RunAborted, ValueError) as error:
        aborted = str(error)
        print(f'error: {aborted}; summarizing the completed chunks', file=sys.stderr)
    finally:
        for record in records[written:]:
            results_file.write(json.dumps(record) + '\n')
        results_file.close()
        server.shutdown()
        request_log.close()
    if args.fixture_manifest:
        try:
            verify_fixture_tree(args.fixture_root, args.fixture_manifest)
        except ValueError as error:
            aborted = str(error)
    changed = [path for path, digest in pinned.items() if not Path(path).is_file() or sha256(path) != digest]
    identity['load_end'] = [round(value, 2) for value in os.getloadavg()]
    identity['finished'] = time.strftime('%Y-%m-%dT%H:%M:%S%z')
    identity['changed_inputs'] = changed
    identity['unexpected_posts'] = runner.unexpected_posts
    identity['aborted'] = aborted
    summary = summarize(tests, records, chunk_results)
    (args.output / 'identity.json').write_text(json.dumps(identity, indent=1) + '\n')
    (args.output / 'chunks.json').write_text(json.dumps(chunk_results, indent=1) + '\n')
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=1) + '\n')
    report = format_report(summary, identity)
    (args.output / 'report.md').write_text(report)
    print(report)
    if changed:
        print(f'error: inputs changed during the run: {changed}', file=sys.stderr)
    all_pass = all(len([record for record in records if record['browser'] == browser
                       and record['outcome'] == 'COMPLETE' and record['harness'] == 'OK'
                       and all(test['status'] == 'PASS' for test in record['subtests'])]) == len(tests)
                   for browser in browsers)
    return 1 if changed or aborted or (args.require_all_pass and not all_pass) else 0


if __name__ == '__main__':
    sys.exit(main())
