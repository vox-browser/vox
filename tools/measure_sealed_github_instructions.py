#!/usr/bin/env python3
"""Frozen GitHub navigation to document-PNG-availability diagnostic.

Native markers measure its exclusive coalition at the actual native hooks.
Chrome's exclusive coalition includes exited browser tasks, with external
sampling bounds and CDP delivery overhead. These are logical workflow boundaries.
Every attempted observation is retained; there are no retries or exclusions.
The supplied successful build receipt must identify this exact Vox executable.
This diagnostic does not grant feature credit or establish browser parity.
"""
from __future__ import annotations

import argparse
import base64
from dataclasses import asdict
import gzip
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import select
import shutil
import statistics
import struct
import subprocess
import sys
import time
import traceback
from urllib.parse import urljoin
import urllib.request

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / 'tools'))
from coalition_instruction_counts import MacCoalitionCounters, CoalitionCounter, instruction_delta
from measure_browser_instructions import CDP, chrome_debugger_endpoint, parse_native_counters
from probe_frozen_github_chrome import ReplayCDP
from process_instruction_counts import MacCounters, CounterSampler
from seal_github_instruction_fixture import SealedFixture

URL = 'https://github.com/vlang/v'
WIDTH, HEIGHT = 1024, 768
SELECTORS = [
    dict(name='rows', selector='tr.react-directory-row', limit=1, attributes=[]),
    dict(name='fileLinks', selector='tr.react-directory-row a[href*="/vlang/v/tree/"], tr.react-directory-row a[href*="/vlang/v/blob/"]', limit=100, attributes=['href']),
    dict(name='about', selector='div[class*="HideWhenNarrow__"] p[class*="description__"]', limit=2, attributes=[]),
    dict(name='images', selector='img', limit=100, attributes=['src', 'alt']),
]
NOTE = ('Logical navigation request to document PNG availability. Native encoder-return '
        'marker precedes file write; Chrome CDP response includes PNG base64/IPC delivery. '
        'Chrome has externally sampled boundary intervals. Both exclusive resource '
        'coalitions include helper and exited tasks. Native screenshot window is inactive, unlike headless '
        'Chrome. Author JavaScript is enabled but full JavaScript/visibility parity is '
        'unproven. Both mandatory semantic content audits run after the PNG endpoint and '
        'are excluded from instruction measurements; Chrome readiness polling and capture '
        'settling remain included. No identical internal endpoint or general Chrome parity claim.')
AUDIT_POLICY = dict(semantic_audits_required=True, semantic_audits_inside_measurement=False,
                   vox='After encoded-PNG counter markers and successful output save, before termination.',
                   chrome='After PNG response, final counter sample, sampler stop, and output save.',
                   chrome_readiness='Scalar document/viewport/font state and the two independently known decoded images; no semantic selectors, text collection, or geometry queries.')


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def data_sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def application(binary):
    return next((parent for parent in binary.parents if parent.suffix == '.app'), None)


def fingerprint(paths):
    return {str(path): dict(sha256=sha(path), bytes=path.stat().st_size)
            for path in sorted(set(Path(path).absolute() for path in paths))}


def native_dependencies(binary):
    """Resolve transitive non-system load commands under a clean dyld environment."""
    main = binary.resolve()
    seen = set()
    main_rpaths = []

    def expand(value, loader):
        return (value.replace('@loader_path', str(loader.parent))
                .replace('@executable_path', str(main.parent)))

    def visit(loader, inherited):
        loader = loader.resolve()
        if loader in seen:
            return
        seen.add(loader)
        commands = subprocess.check_output(['otool', '-l', str(loader)], text=True)
        rpaths = [expand(path, loader) for path in re.findall(
            r'cmd LC_RPATH\s+cmdsize \d+\s+path (.*?) \(offset \d+\)', commands)]
        rpaths += inherited
        if loader == main:
            main_rpaths[:] = rpaths
        dependencies = subprocess.check_output(['otool', '-L', str(loader)], text=True)
        for line in dependencies.splitlines()[1:]:
            name = line.strip().split(' (', 1)[0]
            if name.startswith(('/System/Library/', '/usr/lib/')):
                continue
            candidates = ([Path(path) / name[len('@rpath/'):]
                           for path in rpaths + main_rpaths]
                          if name.startswith('@rpath/') else [Path(expand(name, loader))])
            resolved = next((path.resolve() for path in candidates if path.is_file()), None)
            require(resolved is not None, 'Unresolved non-system runtime: ' + name)
            visit(resolved, rpaths)
    visit(main, [])
    return seen


class FixtureHTML(HTMLParser):
    """Independent source expectations; deliberately no browser-derived baseline."""
    VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = dict(tag='', attrs={}, children=[])
        self.stack = [self.root]
        self.nodes = []

    def handle_starttag(self, tag, attrs):
        node = dict(tag=tag, attrs=dict(attrs), children=[], parent=self.stack[-1])
        self.stack[-1]['children'].append(node)
        self.nodes.append(node)
        if tag not in self.VOID:
            self.stack.append(node)

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, 0, -1):
            if self.stack[index]['tag'] == tag:
                del self.stack[index:]
                break

    def handle_data(self, text):
        self.stack[-1]['children'].append(text)


def text_content(node):
    return ''.join(child if isinstance(child, str) else text_content(child)
                   for child in node['children'])


def ancestor(node, predicate):
    while 'parent' in node:
        node = node['parent']
        if predicate(node):
            return True
    return False


def links_digest(rows):
    values = sorted((urljoin(URL, row['attributes'].get('href', '')), row['text'].strip())
                    for row in rows)
    return data_sha(json.dumps(values, separators=(',', ':'), ensure_ascii=False).encode())


def source_expectations(fixture):
    body = fixture.lookup_response(URL, 'Document')[0]
    parser = FixtureHTML()
    parser.feed(body.decode('utf-8'))
    is_row = lambda node: node['tag'] == 'tr' and 'react-directory-row' in node['attrs'].get('class', '').split()
    rows = [node for node in parser.nodes if is_row(node)]
    links = [dict(text=text_content(node), attributes=node['attrs']) for node in parser.nodes
             if node['tag'] == 'a' and re.search(r'/vlang/v/(?:tree|blob)/', node['attrs'].get('href', ''))
             and ancestor(node, is_row)]
    about = [node for node in parser.nodes if node['tag'] == 'p'
             and 'description__' in node['attrs'].get('class', '')
             and ancestor(node, lambda parent: 'HideWhenNarrow__' in parent['attrs'].get('class', ''))]
    images = [node for node in parser.nodes if node['tag'] == 'img']
    require(len(rows) == 32 and len(links) == 64 and len(about) == 1 and len(images) == 13,
            'Unexpected fixture source structure; do not silently change content gate')
    return dict(document_sha256=data_sha(body), document_bytes=len(body), rows=len(rows),
                file_links=len(links), file_links_sha256=links_digest(links),
                first_link=next(row for row in links if row['text'].strip()),
                about_text_sha256=data_sha(text_content(about[0]).encode()),
                images=sorted(urljoin(URL, node['attrs']['src']) for node in images),
                decoded_images={
                    'https://avatars.githubusercontent.com/u/46413578?s=60&v=4': [60, 60],
                    'https://raw.githubusercontent.com/vlang/v-logo/master/dist/v-logo.svg?sanitize=true': [500, 500]},
                image_policy='All 13 exact source URLs retained. Require both archived known images decoded; missing unarchived images may remain zero natural size.')


def visible(element):
    rect = element.get('rect', {})
    x, y = rect.get('x', 0), rect.get('y', 0)
    width, height = rect.get('width', 0), rect.get('height', 0)
    return width > 0 and height > 0 and x < WIDTH and y < HEIGHT and x + width > 0 and y + height > 0


def content_gate(audit, expected):
    failures = []
    if audit.get('url') != URL or audit.get('ready') != 'complete':
        failures.append('wrong URL or readiness')
    if [audit.get('viewport_width'), audit.get('viewport_height')] != [WIDTH, HEIGHT]:
        failures.append('wrong document viewport')
    selections = {row['name']: row for row in audit.get('selections', [])}
    rows, links, about, images = [selections.get(name, dict(count=0, elements=[]))
                                for name in ['rows', 'fileLinks', 'about', 'images']]
    if rows['count'] != expected['rows'] or not rows['elements'] or not visible(rows['elements'][0]):
        failures.append('repository first row missing or outside viewport')
    if (links['count'] != expected['file_links'] or len(links['elements']) != expected['file_links']
            or links_digest(links['elements']) != expected['file_links_sha256']):
        failures.append('repository filename/href digest differs')
    first = expected['first_link']
    if not any(row['text'].strip() == first['text'].strip()
               and urljoin(URL, row['attributes'].get('href', '')) == urljoin(URL, first['attributes']['href'])
               and visible(row) for row in links['elements']):
        failures.append('first repository filename is not visible')
    if (about['count'] != 1 or len(about['elements']) != 1 or not visible(about['elements'][0])
            or data_sha(about['elements'][0]['text'].encode()) != expected['about_text_sha256']):
        failures.append('wide visible About text differs or is outside viewport')
    actual_images = sorted(urljoin(URL, row['attributes'].get('src', '')) for row in images['elements'])
    if images['count'] != len(expected['images']) or actual_images != expected['images']:
        failures.append('image source inventory differs')
    for url, size in expected['decoded_images'].items():
        matches = [row for row in images['elements'] if urljoin(URL, row['attributes'].get('src', '')) == url]
        if len(matches) != 1:
            failures.append('known decoded image missing: ' + url)
            continue
        image = matches[0].get('image') or {}
        if not (image.get('complete') and [image.get('natural_width'), image.get('natural_height')] == size):
            failures.append('known image not decoded to expected dimensions: ' + url)
    return dict(passed=not failures, failures=failures)


def png_info(path):
    header = Path(path).read_bytes()[:24]
    require(header[:8] == b'\x89PNG\r\n\x1a\n' and len(header) == 24, 'Invalid document PNG')
    dimensions = list(struct.unpack('>II', header[16:24]))
    require(dimensions == [WIDTH, HEIGHT], 'Wrong encoded document PNG dimensions: ' + str(dimensions))
    return dict(path=str(path), dimensions=dimensions, sha256=sha(path), bytes=Path(path).stat().st_size)


def processes():
    rows = []
    for line in subprocess.check_output(['ps', '-axo', 'pid=,ppid=,uid=,command='], text=True).splitlines():
        words = line.strip().split(None, 3)
        if len(words) == 4:
            rows.append(dict(pid=int(words[0]), parent=int(words[1]), uid=int(words[2]), command=words[3]))
    return rows


def clean_environment():
    env = dict(os.environ)
    for key in list(env):
        if key.startswith(('DYLD_', 'VOX_', 'LADYBIRD_', 'SCREENSHOT_', 'GC_')) or key.lower() in (
                'http_proxy', 'https_proxy', 'all_proxy', 'no_proxy') or key == 'DEBUG_TIMING':
            env.pop(key, None)
    return env


def native_environment(args, folder):
    # LaunchServices can inherit the desktop session's environment. Explicitly
    # clear observed controls as well as cleaning the launcher's environment.
    # Some collector options test presence rather than a nonempty value, so
    # --env NAME= cannot reliably clear them. Refuse those ambient options.
    extra_gc = sorted(key for key in os.environ if key.startswith('GC_') and key != 'GC_MARKERS')
    require(not extra_gc, 'Remove ambient collector controls before measuring: ' + ', '.join(extra_gc))
    env = dict(DYLD_INSERT_LIBRARIES=str(args.network_deny), VOX_TEST_WINDOW='1', VOX_COOKIE_FILE='',
               VOX_PROFILE_INSTRUCTIONS='1', VOX_CAPTURE_DOCUMENT_ONLY='1',
               VOX_CAPTURE_AUDIT_CONFIG=str(args.work_dir / 'audit-config.json'),
               VOX_CAPTURE_AUDIT_PATH=str(folder / 'audit.json'), LADYBIRD_CACHE_DIR=str(folder / 'cache'),
               LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds), LADYBIRD_SCREENSHOT_SCALE='1',
               GC_MARKERS=str(args.gc_markers))
    for key in os.environ.keys() - clean_environment().keys():
        env.setdefault(key, '')
    return env


def build_provenance(path, executable):
    receipt = json.loads(path.read_bytes())
    require((type(receipt.get('exit')) is int and receipt['exit'] == 0) or (receipt.get('passed') is True
            and receipt.get('build_complete') is True), 'Vox build receipt is not successful')
    require(receipt.get('executable_sha256', receipt.get('binary_sha256')) == sha(executable),
            'Vox build receipt does not identify this executable')
    return dict(path=str(path), sha256=sha(path), bytes=path.stat().st_size,
                configuration_note='Compiler/GC/preallocation/native options remain those of this pinned build receipt; setting GC_MARKERS cannot enable GC in a GC-none binary.')


def parse_native_coalitions(text, coalition_id):
    rows = [json.loads(line[len('Vox coalition instructions: '):]) for line in text.splitlines()
            if line.startswith('Vox coalition instructions: ')]
    selected = []
    for label in ['navigation_started', 'capture_document_encoded']:
        matching = [row for row in rows if row.get('label') == label]
        require(len(matching) == 1, 'Require exactly one native coalition marker: ' + label)
        row = matching[0]
        require(all(type(row.get(key)) is int and row[key] >= 0 for key in
                    ['coalition_id', 'instructions', 'tasks_started', 'tasks_exited']),
                'Malformed native coalition marker')
        require(row['coalition_id'] == coalition_id and row['instructions'] > 0,
                'Native marker coalition mismatch or unavailable instructions')
        require(row['tasks_exited'] <= row['tasks_started'], 'Invalid native coalition task totals')
        selected.append(row)
    before, after = selected
    require(rows.index(before) < rows.index(after), 'Native coalition markers reversed')
    delta = {key: after[key] - before[key] for key in ['instructions', 'tasks_started', 'tasks_exited']}
    require(delta['instructions'] > 0 and min(delta.values()) >= 0, 'Native coalition counters decreased')
    return dict(markers=selected, delta=delta, coalition_id=coalition_id)


def native_membership(api, cid, app, pid, deadline, attempts):
    while True:
        before = api.read(cid)
        members, vanished = [], []
        for row in processes():
            if row['uid'] != os.getuid():
                continue
            try:
                group = api.resource_coalition(row['pid'])
            except OSError as exc:
                if exc.errno in (2, 3):
                    vanished.append(row['pid'])
                    continue
                raise
            if group == cid:
                members.append(row)
        after = api.read(cid)
        stable = (before.tasks_started, before.tasks_exited) == (after.tasks_started, after.tasks_exited)
        owned = bool(members) and all(row['command'].startswith(str(app) + '/Contents/') for row in members)
        exact = after.tasks_started - after.tasks_exited == len(members)
        root_present = pid in {row['pid'] for row in members}
        scan = dict(before_snapshot=asdict(before), after_snapshot=asdict(after), members=members,
                    stable=stable, all_owned=owned, exact_live_count=exact,
                    root_present=root_present, vanished_during_scan=vanished)
        attempts.append(scan)
        if stable and owned and exact and root_present:
            return scan
        require(time.monotonic() < deadline, 'No stable exact native coalition membership before capture')
        time.sleep(.01)


def native_browser_arguments(args, png):
    # Older Vox builds run page scripts by default and reject the newer
    # --enable-javascript switch. Select this contract explicitly; never infer
    # it by retrying a failed browser launch inside a declared cohort.
    mode = args.vox_javascript_mode
    require(mode in ('explicit', 'default-enabled'), 'Unknown native JavaScript launch contract')
    javascript = ['--enable-javascript'] if mode == 'explicit' else ['--js-engine=javascriptcore']
    return javascript + ['--window-width', str(WIDTH), '--window-height', str(HEIGHT + 84),
                         '--screenshot', str(png), URL]


def run_vox(args, folder, expected, manifest_sha):
    result = dict(engine='vox', scope=NOTE, comparison_eligible=False, performance_credit=0,
                  membership_attempts=[])
    queue = None
    pid = root_start = cid = None
    proc = api = None
    try:
        cache = folder / 'cache'
        shutil.copytree(args.fixture, cache)
        sealed = SealedFixture(cache, manifest_sha)
        png, audit = folder / 'document.png', folder / 'audit.json'
        env = native_environment(args, folder)
        result['environment_controls'] = env
        app = application(args.vox)
        require(app is not None, 'Native exclusive coalition launch requires a private .app bundle')
        require(not any(row['command'].startswith(str(app) + '/Contents/') for row in processes()),
                'Native private app already has running processes; will not reuse or terminate them')
        command = ['/usr/bin/open', '-n', '-g', '-a', str(app),
                   '--stdout', str(folder / 'stdout.log'), '--stderr', str(folder / 'browser.log')]
        for key, value in sorted(env.items()):
            command += ['--env', key + '=' + value]
        command += ['--args'] + native_browser_arguments(args, png)
        launched = subprocess.run(command, capture_output=True, text=True, env=clean_environment())
        result.update(command=command, actual_open_exit=launched.returncode,
                      launch_stdout=launched.stdout, launch_stderr=launched.stderr)
        require(launched.returncode == 0, 'LaunchServices failed to launch native browser')
        api, proc = MacCoalitionCounters(), MacCounters()
        deadline = time.monotonic() + args.timeout
        while pid is None:
            roots = [row for row in processes() if row['command'].startswith(str(args.vox) + ' ')
                     and str(png) in row['command']]
            require(len(roots) <= 1, 'Native root identity is not unique')
            if roots:
                pid = roots[0]['pid']
                result['root'] = roots[0]
                break
            require(time.monotonic() < deadline, 'Native launched root was not observed before watchdog')
            time.sleep(.01)
        require(proc.path(pid) == str(args.vox), 'Native executable path mismatch')
        root_start = proc.read(pid).start
        cid, cli_cid = api.resource_coalition(pid), api.resource_coalition(os.getpid())
        require(cid != cli_cid, 'Native browser inherited observer coalition')
        result.update(resource_coalition=cid, observer_resource_coalition=cli_cid)
        queue = select.kqueue()
        queue.control([select.kevent(pid, filter=select.KQ_FILTER_PROC,
                      flags=select.KQ_EV_ADD | select.KQ_EV_ENABLE | select.KQ_EV_ONESHOT,
                      fflags=select.KQ_NOTE_EXIT | 0x04000000)], 0, 0)
        result['membership_before_capture'] = native_membership(api, cid, app, pid,
                min(deadline, time.monotonic() + 15), result['membership_attempts'])
        while True:
            events = queue.control(None, 1, .05)
            if events:
                require(events[0].ident == pid and events[0].fflags & select.KQ_NOTE_EXIT
                        and events[0].fflags & 0x04000000, 'Missing native kernel exit status')
                result['root_kernel_wait_status'] = events[0].data
                break
            require(time.monotonic() < deadline, 'Native capture watchdog expired')
        result['native_counters'] = parse_native_counters((folder / 'browser.log').read_text(errors='replace'))
        require(result['root_kernel_wait_status'] == 0, 'Native process failed: ' + str(result['root_kernel_wait_status']))
        require(not result['native_counters']['unavailable'], 'Native instruction counters unavailable')
        values = {}
        for label in ['navigation_started', 'capture_document_encoded']:
            matches = [phase['cumulative_instructions'] for phase in result['native_counters']['phases']
                       if phase['label'] == label]
            require(len(matches) == 1, 'Require exactly one native marker: ' + label)
            values[label] = matches[0]
        result['marker_values'] = values
        result['main_task_instructions'] = values['capture_document_encoded'] - values['navigation_started']
        require(result['main_task_instructions'] > 0, 'Native interval is empty or reversed')
        result['coalition_counters'] = parse_native_coalitions((folder / 'browser.log').read_text(errors='replace'), cid)
        result['coalition_instructions'] = result['coalition_counters']['delta']['instructions']
        result['png'] = png_info(png)
        state = json.loads(audit.read_text())
        result['content_gate'] = content_gate(state, expected)
        result['audit_sha256'] = sha(audit)
        result['document_activity'] = dict(visibility=state.get('visibility'), fully_active=state.get('fully_active'))
        sealed.validate()
        require(result['content_gate']['passed'], 'Native content gate failed: ' + repr(result['content_gate']['failures']))
        result.update(exit=0, comparison_eligible=True,
                      accounting_note='Exact in-process resource-coalition snapshots include live and exited helper work; main-task markers are separate diagnostics. Exclusive stable live membership verified after LaunchServices launch and before capture. No launch hold: membership may first be scanned after navigation; departed startup task paths cannot be reconstructed. Native private app had no live process before launch.')
    except Exception as exc:
        result.update(exit=1, error=str(exc), traceback=traceback.format_exc())
    finally:
        if pid is not None and 'root_kernel_wait_status' not in result:
            # Only terminate the exact PID/start identity created by this launch.
            try:
                if proc.read(pid).start == root_start and proc.path(pid) == str(args.vox):
                    os.kill(pid, 15)
            except ProcessLookupError:
                pass
            except Exception as exc:
                result['cleanup_terminate_error'] = repr(exc)
            if queue is not None:
                events = queue.control(None, 1, 5)
                result['cleanup_root_kernel_wait_status'] = events[0].data if events else None
        if queue is not None:
            queue.close()
        if (folder / 'browser.log').exists():
            try:
                result.setdefault('native_counters', parse_native_counters((folder / 'browser.log').read_text(errors='replace')))
            except Exception as exc:
                result['counter_parse_error'] = repr(exc)
                result['exit'] = 1
    return result


class SealedCDP(ReplayCDP):
    def __init__(self, endpoint, fixture, deadline):
        self.fixture, self.deadline = fixture, deadline
        super().__init__(endpoint, fixture.root)

    def lookup_response(self, url, resource_type):
        return self.fixture.lookup_response(url, resource_type)

    def replay_headers(self, body, mime, path):
        return self.fixture.replay_headers(body, mime, path)

    def pump(self):
        require(time.monotonic() < self.deadline, 'Chrome observation watchdog expired')
        return super().pump()


def chrome_audit_expression():
    return '''JSON.stringify((()=>({url:location.href,title:document.title,ready:document.readyState,
      visibility:document.visibilityState,fully_active:true,viewport_width:innerWidth,
      viewport_height:innerHeight,scale:devicePixelRatio,fonts_status:document.fonts.status,
      selections:''' + json.dumps(SELECTORS) + '''.map(q=>{const all=[...document.querySelectorAll(q.selector)];
       return {name:q.name,selector:q.selector,count:all.length,elements:all.slice(0,q.limit).map(e=>{
        const r=e.getBoundingClientRect(),i=e instanceof HTMLImageElement;
        return {tag:e.localName,text:e.textContent,rect:{x:r.x,y:r.y,width:r.width,height:r.height},
         attributes:Object.fromEntries(q.attributes.filter(a=>e.hasAttribute(a)).map(a=>[a,e.getAttribute(a)])),
         image:i?{complete:e.complete,current_src:e.currentSrc,natural_width:e.naturalWidth,
          natural_height:e.naturalHeight}:null};})};})}))())'''


def chrome_readiness_expression(expected):
    # Do not collect selector inventories, text, geometry, or hashes here: that
    # semantic audit is deliberately outside the measured interval. The sealed
    # fixture has unavailable images, so only its two archived images must decode.
    return '''JSON.stringify((()=>{const images=[...document.images];return {
      url:location.href,ready:document.readyState,viewport_width:innerWidth,
      viewport_height:innerHeight,scale:devicePixelRatio,fonts_status:document.fonts.status,
      known_images_ready:Object.entries(''' + json.dumps(expected['decoded_images']) + ''').every(([url,size])=>{
        const found=images.filter(i=>i.src===url);return found.length===1&&found[0].complete&&
          found[0].naturalWidth===size[0]&&found[0].naturalHeight===size[1];})};})())'''


def chrome_capture_endpoint(client, counter, sampler, expected, deadline, settle_seconds, checks=None):
    """Collect only readiness/capture work before freezing endpoint counters."""
    checks = [] if checks is None else checks
    while True:
        require(time.monotonic() < deadline, 'Chrome readiness watchdog expired')
        response = client.call('Runtime.evaluate', dict(
            expression=chrome_readiness_expression(expected), returnByValue=True))
        require('exceptionDetails' not in response, 'Chrome readiness JavaScript failed')
        state = json.loads(response['result']['value'])
        ready = (state.get('url') == URL and state.get('ready') == 'complete'
                 and [state.get('viewport_width'), state.get('viewport_height')] == [WIDTH, HEIGHT]
                 and state.get('scale') == 1 and state.get('fonts_status') == 'loaded'
                 and state.get('known_images_ready') is True)
        checks.append(dict(monotonic=time.monotonic(), passed=ready, state=state))
        if ready:
            break
        time.sleep(.02)
    # Match the native explicit post-readiness capture delay. This delay
    # and any resulting timer work remain inside each instruction interval.
    settle_until = time.monotonic() + settle_seconds
    while time.monotonic() < settle_until:
        require(time.monotonic() < deadline, 'Chrome settle watchdog expired')
        time.sleep(max(0, min(.02, settle_until - time.monotonic())))
    image = client.call('Page.captureScreenshot', dict(format='png', captureBeyondViewport=False))
    endpoint_at = time.monotonic()
    counter.sample()  # First post-endpoint read brackets the delivery boundary.
    sampler.__exit__(None, None, None)
    return image, endpoint_at, checks


def boundary_bracket(history, point):
    before = [row for row in history if row.sample_completed <= point]
    after = [row for row in history if row.sample_started >= point]
    require(before and after, 'Counter history does not bracket external boundary')
    return before[-1], after[0]


def run_chrome(args, folder, expected, manifest_sha):
    result = dict(engine='chrome', scope=NOTE, comparison_eligible=False, performance_credit=0,
                  membership_attempts=[], author_javascript=True, tracing=False)
    browser = client = sampler = queue = counter = None
    closed = False
    pid = None
    try:
        fixture = SealedFixture(args.fixture, manifest_sha)
        api, proc = MacCoalitionCounters(), MacCounters()
        profile = folder / 'profile'
        profile.mkdir()
        require(not any(row['command'].startswith(str(args.chrome_app) + '/Contents/') for row in processes()),
                'Private Chrome app already has running processes; will not reuse or terminate them')
        flags = ['--headless=new', '--no-first-run', '--no-default-browser-check', '--enable-automation',
                 '--disable-background-networking', '--no-proxy-server',
                 '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost',
                 '--remote-debugging-port=0', '--user-data-dir=' + str(profile), 'about:blank']
        command = ['/usr/bin/open', '-n', '-g', '-a', str(args.chrome_app), '--args', *flags]
        launched = subprocess.run(command, capture_output=True, text=True, env=clean_environment())
        result.update(command=command, actual_open_exit=launched.returncode,
                      launch_stdout=launched.stdout, launch_stderr=launched.stderr)
        require(launched.returncode == 0, 'LaunchServices failed to launch Chrome')
        deadline = time.monotonic() + args.timeout
        endpoint = None
        while endpoint is None:
            require(time.monotonic() < deadline, 'Chrome debugger startup watchdog expired')
            endpoint = chrome_debugger_endpoint(profile / 'DevToolsActivePort')
            time.sleep(.02)
        roots = [row for row in processes() if row['command'].startswith(str(args.chrome) + ' ')
                 and '--user-data-dir=' + str(profile) in row['command']]
        require(len(roots) == 1, 'Chrome root identity is not unique')
        pid = roots[0]['pid']
        require(proc.path(pid) == str(args.chrome), 'Chrome executable path mismatch')
        cid, cli_cid = api.resource_coalition(pid), api.resource_coalition(os.getpid())
        require(cid != cli_cid, 'Chrome inherited the observer resource coalition')
        result.update(root=roots[0], resource_coalition=cid, observer_resource_coalition=cli_cid)
        queue = select.kqueue()
        queue.control([select.kevent(pid, filter=select.KQ_FILTER_PROC,
                      flags=select.KQ_EV_ADD | select.KQ_EV_ENABLE | select.KQ_EV_ONESHOT,
                      fflags=select.KQ_NOTE_EXIT | 0x04000000)], 0, 0)
        port, browser_path = endpoint
        browser = CDP(f'ws://127.0.0.1:{port}{browser_path}')
        result['version'] = browser.call('Browser.getVersion')
        result['actual_browser_arguments'] = browser.call('Browser.getBrowserCommandLine')

        def membership(label):
            # Rescanning an unstable inventory is not an observation retry.
            limit = min(deadline, time.monotonic() + 25)
            while True:
                before = api.read(cid)
                infos = browser.call('SystemInfo.getProcessInfo')['processInfo']
                rows, members, vanished = processes(), [], []
                for row in rows:
                    if row['uid'] != os.getuid():
                        continue
                    try:
                        group = api.resource_coalition(row['pid'])
                    except OSError as exc:
                        if exc.errno in (2, 3):
                            vanished.append(row['pid'])
                            continue
                        raise
                    if group == cid:
                        members.append(row)
                after = api.read(cid)
                required = {int(info['id']) for info in infos}
                required.update(row['pid'] for row in rows if str(profile) in row['command']
                                and row['command'].startswith(str(args.chrome_app)))
                stable = (before.tasks_started, before.tasks_exited) == (after.tasks_started, after.tasks_exited)
                present = required <= {row['pid'] for row in members}
                owned = bool(members) and all(row['command'].startswith(str(args.chrome_app) + '/Contents/') for row in members)
                exact = after.tasks_started - after.tasks_exited == len(members)
                scan = dict(label=label, cdp_processes=infos, members=members, vanished=vanished,
                            before_snapshot=asdict(before), after_snapshot=asdict(after), stable=stable,
                            required_present=present, all_owned=owned, exact_live_count=exact)
                result['membership_attempts'].append(scan)
                if stable and present and owned and exact:
                    return scan
                require(time.monotonic() < limit, 'Cannot establish exclusive stable Chrome coalition membership')
                time.sleep(.1)

        result['membership_before'] = membership('before')
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(f'http://127.0.0.1:{port}/json/list', timeout=15) as response:
            targets = json.load(response)
        page = next(target['webSocketDebuggerUrl'] for target in targets if target['type'] == 'page')
        client = SealedCDP(page, fixture, deadline)
        for method in ['Page.enable', 'Runtime.enable', 'Network.enable']:
            client.call(method)
        client.call('Network.setBypassServiceWorker', dict(bypass=True))
        client.call('Network.setCacheDisabled', dict(cacheDisabled=True))
        client.call('Emulation.setDeviceMetricsOverride', dict(width=WIDTH, height=HEIGHT, deviceScaleFactor=1, mobile=False))
        client.call('Fetch.enable', dict(patterns=[dict(urlPattern='*', requestStage='Request')]))
        counter = CoalitionCounter(api, cid)
        sampler = CounterSampler(counter, .002)
        sampler.__enter__()
        counter.sample()
        navigation_start = time.monotonic()
        client.call('Page.navigate', dict(url=URL))
        result['navigation_response_monotonic'] = time.monotonic()
        checks = []
        result['readiness_checks'] = checks
        image, endpoint_at, checks = chrome_capture_endpoint(
            client, counter, sampler, expected, deadline, args.settle_seconds, checks)
        sampler = None
        with counter.lock:
            history = list(counter.snapshots)
        start_before, start_after = boundary_bracket(history, navigation_start)
        end_before, end_after = boundary_bracket(history, endpoint_at)
        lower = instruction_delta(start_after, end_before)
        upper = instruction_delta(start_before, end_after)
        result.update(navigation_request_monotonic=navigation_start, png_available_monotonic=endpoint_at,
                      boundary_brackets=dict(navigation_before=asdict(start_before), navigation_after=asdict(start_after),
                                             capture_before=asdict(end_before), capture_after=asdict(end_after)),
                      instruction_interval=dict(lower=lower['instructions'], upper=upper['instructions']),
                      lower_delta=lower, upper_delta=upper,
                      bracket_note='Lower uses first sample entirely after navigation request and last entirely before CDP screenshot response; upper uses opposite sides. CDP base64/IPC tail is included in logical workflow.')
        png = folder / 'document.png'
        png.write_bytes(base64.b64decode(image['data'], validate=True))
        result['png'] = png_info(png)
        # Sampling is fully stopped and its upper boundary retained before the
        # expensive mandatory audit. It observes this same captured navigation.
        audit_started = time.monotonic()
        require(audit_started >= end_after.sample_completed, 'Semantic audit overlaps capture counter bracket')
        response = client.call('Runtime.evaluate', dict(expression=chrome_audit_expression(), returnByValue=True))
        require('exceptionDetails' not in response, 'Chrome audit JavaScript failed')
        audit = json.loads(response['result']['value'])
        gate = content_gate(audit, expected)
        result.update(content_gate=gate, semantic_audit_started_monotonic=audit_started,
                      semantic_audit_completed_monotonic=time.monotonic(),
                      semantic_audit_excluded_from_measurement=True)
        write_json(folder / 'audit.json', audit)
        result['audit_sha256'] = sha(folder / 'audit.json')
        result['document_activity'] = dict(visibility=audit.get('visibility'), fully_active=audit.get('fully_active'))
        require(gate['passed'], 'Chrome content gate failed: ' + repr(gate['failures']))
        require(audit.get('scale') == 1 and audit.get('fonts_status') == 'loaded',
                'Chrome post-capture scale or font readiness changed')
        result['membership_after'] = membership('after')
        fixture.validate()
        browser.call('Browser.close')
        closed = True
        events = queue.control(None, 1, 15)
        require(len(events) == 1 and events[0].ident == pid and events[0].fflags & select.KQ_NOTE_EXIT
                and events[0].fflags & 0x04000000, 'Missing Chrome kernel exit status')
        result['root_kernel_wait_status'] = events[0].data
        require(events[0].data == 0, 'Chrome root exited unsuccessfully')
        result.update(exit=0, comparison_eligible=True)
    except Exception as exc:
        result.update(exit=1, error=str(exc), traceback=traceback.format_exc())
    finally:
        if sampler is not None:
            try:
                sampler.__exit__(*sys.exc_info())
            except Exception as exc:
                result['sampler_error'] = repr(exc)
                result['exit'] = 1
        if counter is not None:
            with counter.lock:
                raw = json.dumps([asdict(row) for row in counter.snapshots], separators=(',', ':')).encode()
            archive = folder / 'coalition-snapshots.json.gz'
            archive.write_bytes(gzip.compress(raw, compresslevel=1, mtime=0))
            result['snapshot_archive'] = dict(path=str(archive), sha256=sha(archive), raw_sha256=data_sha(raw))
        if browser is not None and not closed:
            try:
                browser.call('Browser.close')
            except Exception as exc:
                result['cleanup_close_error'] = repr(exc)
        if queue is not None:
            if 'root_kernel_wait_status' not in result:
                events = queue.control(None, 1, 15)
                result['cleanup_root_kernel_wait_status'] = events[0].data if events else None
            queue.close()
        if client is not None:
            result.update(requests=client.requests, events=client.events)
            client.sock.close()
        if browser is not None:
            browser.sock.close()
        if 'audit' in locals():
            write_json(folder / 'audit.json', audit)
            result['audit_sha256'] = sha(folder / 'audit.json')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vox', type=Path, required=True)
    parser.add_argument('--vox-build-protocol', type=Path, required=True)
    parser.add_argument('--vox-javascript-mode', choices=['explicit', 'default-enabled'], default='explicit',
                        help='Use default-enabled only for a verified older build that runs author scripts by default; selects JavaScriptCore explicitly. No launch probing or retries.')
    parser.add_argument('--gc-markers', type=int, choices=[1, 2], default=1)
    parser.add_argument('--chrome-app', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, required=True)
    parser.add_argument('--network-deny', type=Path, required=True)
    parser.add_argument('--work-dir', type=Path, required=True)
    parser.add_argument('--runtime-library', type=Path, action='append', default=[])
    parser.add_argument('--samples', type=int, default=3)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--settle-seconds', type=float, default=.5)
    parser.add_argument('--vox-sha256')
    parser.add_argument('--chrome-sha256')
    parser.add_argument('--manifest-sha256')
    args = parser.parse_args()
    require(args.samples > 0 and args.timeout > 0 and args.settle_seconds >= 0,
            'Samples/watchdog must be positive and settle seconds nonnegative')
    for key in ['vox', 'vox_build_protocol', 'chrome_app', 'fixture', 'network_deny', 'work_dir']:
        setattr(args, key, getattr(args, key).resolve())
    import plistlib
    bundle = plistlib.loads((args.chrome_app / 'Contents/Info.plist').read_bytes())
    args.chrome = args.chrome_app / 'Contents/MacOS' / bundle['CFBundleExecutable']
    for path, wanted in [(args.vox, args.vox_sha256), (args.chrome, args.chrome_sha256)]:
        require(path.is_file(), 'Missing executable: ' + str(path))
        if wanted:
            require(sha(path) == wanted, 'Executable SHA256 mismatch: ' + str(path))
    require(args.network_deny.is_file(), 'Missing native offline guard')
    fixture = SealedFixture(args.fixture, args.manifest_sha256)
    expected = source_expectations(fixture)
    provenance = build_provenance(args.vox_build_protocol, args.vox)
    paths = {Path(__file__).resolve(), args.vox, args.chrome, args.network_deny, args.vox_build_protocol}
    paths.update(native_dependencies(args.vox))
    paths.update(path.resolve() for path in args.runtime_library)
    for app in [application(args.vox), args.chrome_app]:
        if app:
            paths.update(path.absolute() for path in app.rglob('*') if path.is_file())
    paths.update(REPO / 'tools' / name for name in ['coalition_instruction_counts.py',
                 'process_instruction_counts.py', 'measure_browser_instructions.py',
                 'probe_frozen_github_chrome.py', 'seal_github_instruction_fixture.py'])
    paths.update(path for path in (REPO / 'adblock/lists').rglob('*') if path.is_file())
    pinned = fingerprint(paths)
    args.work_dir.mkdir(parents=True, exist_ok=False, mode=0o700)
    write_json(args.work_dir / 'audit-config.json', dict(selectors=SELECTORS))
    # Reject unsupported collector environment controls before any observation.
    native_environment(args, args.work_dir / 'pair-01.vox')
    plan = dict(schema=2, samples=args.samples, retries=0, exclusions=0,
                order=[dict(pair=index + 1, engine=engine) for index in range(args.samples)
                       for engine in (['vox', 'chrome'] if index % 2 == 0 else ['chrome', 'vox'])],
                url=URL, viewport=[WIDTH, HEIGHT], device_scale_factor=1, author_javascript=True,
                vox_javascript_launch_mode=args.vox_javascript_mode,
                fixture=str(args.fixture), manifest_sha256=fixture.manifest_sha256,
                fixture_policy=fixture.manifest['metadata_policy'], source_expectations=expected,
                runtime_pins=pinned, endpoint_scope=NOTE, audit_policy=AUDIT_POLICY, performance_credit=0,
                chrome_parity_established=False, timeout=args.timeout, settle_seconds=args.settle_seconds,
                vox_build_provenance=provenance, gc_marker_threads=args.gc_markers,
                environment_policy='Clear inherited browser, dyld, timing and proxy controls; reject ambient GC controls other than GC_MARKERS and set its native value explicitly. Build mode is unchanged.',
                policy='All attempted samples retained, no retries; cached body metadata synthetic. Fail closed on missing/nonGET requests, use native DYLD network guard. Browser app files, linked native runtime, tools, filter lists and sealed fixture pinned before launches and after every sample. Counts exclude GPU execution and external services.')
    # This is written before the first measured launch, and never rewritten.
    write_json(args.work_dir / 'plan.json', plan)
    observations = []
    for item in plan['order']:
        folder = args.work_dir / ('pair-%02d.%s' % (item['pair'], item['engine']))
        folder.mkdir()
        report = dict(item)
        try:
            require(fingerprint(paths) == pinned, 'Pinned runtime changed before observation')
            fixture.validate()
            report.update((run_vox if item['engine'] == 'vox' else run_chrome)(args, folder, expected, fixture.manifest_sha256))
            require(fingerprint(paths) == pinned, 'Pinned runtime changed during observation')
            fixture.validate()
        except Exception as exc:
            report.update(exit=1, error=str(exc), traceback=traceback.format_exc(), comparison_eligible=False)
        write_json(folder / 'result.json', report)
        observations.append(report)
        print(json.dumps({key: report.get(key) for key in ['pair', 'engine', 'exit', 'error', 'main_task_instructions', 'instruction_interval', 'comparison_eligible']}), flush=True)
    successful = all(row.get('exit') == 0 for row in observations)
    eligible = successful and all(row.get('comparison_eligible') for row in observations)
    summary = dict(exit=0 if successful else 1, observations=observations, plan_sha256=sha(args.work_dir / 'plan.json'),
                   all_content_and_capture_checks_passed=successful, all_task_comparison_eligible=eligible,
                   chrome_parity_established=False, performance_credit=0, endpoint_scope=NOTE,
                   audit_policy=AUDIT_POLICY)
    if successful:
        vox = [row['main_task_instructions'] for row in observations if row['engine'] == 'vox']
        native_coalitions = [row['coalition_instructions'] for row in observations if row['engine'] == 'vox']
        chrome = [row['instruction_interval'] for row in observations if row['engine'] == 'chrome']
        summary['diagnostic_counts'] = dict(vox_main_task_median=statistics.median(vox),
            vox_coalition_median=statistics.median(native_coalitions),
            chrome_coalition_lower_median=statistics.median(row['lower'] for row in chrome),
            chrome_coalition_upper_median=statistics.median(row['upper'] for row in chrome),
            conservative_worst_vox_over_best_chrome_lower=max(native_coalitions) / min(row['lower'] for row in chrome),
            logical_workflow_worst_vox_below_best_chrome_lower=max(native_coalitions) <= min(row['lower'] for row in chrome),
            note='Both include all coalition tasks. External Chrome boundaries/CDP tail and document activity differences prohibit an unconditional internal browser parity claim.')
    write_json(args.work_dir / 'summary.json', summary)
    return summary['exit']


if __name__ == '__main__':
    raise SystemExit(main())
