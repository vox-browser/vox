#!/usr/bin/env python3
"""Measure frozen Pikabu captures with full-uBO Brave and native Vox.

This is an offline replay with author JavaScript enabled, not full browsing
parity. The same archived HTTPS bodies and response-header provenance feed both
engines. Missing responses fail closed; no request falls through to the network.
Vox's exit/capture total includes teardown. Brave's observed process-tree total
ends before its first screenshot response and is a polling lower bound.
"""
from __future__ import annotations

import argparse
import base64
from contextlib import contextmanager
import ctypes
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

from measure_browser_instructions import (
    CDP, run_vox, stop_process, wait_for_chrome_debugger,
)
from process_instruction_counts import MacCounters, ProcessTreeCounter, CounterSampler
from probe_frozen_github_chrome import ReplayCDP

REPO = Path(__file__).resolve().parents[1]
URL = 'https://pikabu.ru/'
DOC_STATE = r'''JSON.stringify({url:location.href,title:document.title,
 ready:document.readyState,width:innerWidth,height:innerHeight,scale:devicePixelRatio,
 text:document.body?.innerText||'',stories:document.querySelectorAll('article.story').length,
 firstTitle:document.querySelector('.story__title')?.textContent||'',
 images:[...document.querySelectorAll('article.story img')].map(i=>({
 src:i.currentSrc||i.src,complete:i.complete,naturalWidth:i.naturalWidth,
 naturalHeight:i.naturalHeight,rect:i.getBoundingClientRect().toJSON()})),
 fontsStatus:document.fonts.status})'''


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fingerprint_tree(root):
    rows = []
    for path in sorted(root.rglob('*')):
        if path.is_file() and not path.is_symlink():
            rows.append({'file': str(path.relative_to(root)), 'bytes': path.stat().st_size,
                         'sha256': digest(path)})
    return {'files': rows, 'sha256': hashlib.sha256(json.dumps(
        rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()}


def clone_file(source, target):
    """Use APFS clones to avoid duplicating large browser binaries/caches."""
    lib = ctypes.CDLL(None, use_errno=True)
    clone = lib.clonefile
    clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
    clone.restype = ctypes.c_int
    if clone(os.fsencode(source), os.fsencode(target), 0):
        shutil.copy2(source, target)
    return target


@contextmanager
def fresh_copy(template, parent, label):
    with tempfile.TemporaryDirectory(prefix='pikabu-' + label + '-', dir=parent) as temporary:
        copy = Path(temporary) / label
        shutil.copytree(template, copy, copy_function=clone_file, symlinks=True,
                        ignore=shutil.ignore_patterns('Singleton*', 'DevToolsActivePort'))
        yield copy


def evaluate(client, expression):
    result = client.call('Runtime.evaluate', {'expression': expression, 'awaitPromise': True,
                                               'returnByValue': True})
    if 'exceptionDetails' in result:
        raise RuntimeError(result['exceptionDetails'])
    return result.get('result', {}).get('value')


def list_inputs():
    manifest = json.loads((REPO / 'adblock/lists/manifest.json').read_text())
    rows = []
    for item in manifest['lists']:
        path = REPO / 'adblock' / item['file']
        if digest(path) != item['sha256']:
            raise RuntimeError('Pinned list hash mismatch: ' + item['name'])
        rows.append({'name': item['name'], 'content': path.read_text()})
    return manifest, rows


def frozen_response(cache, url, resource_type):
    key = hashlib.sha256(url.encode()).hexdigest()
    # The canonical main document is pinned to an archived response with
    # actual header provenance, also installed byte-for-byte in Vox's pages.
    resource = cache / 'resources' / key
    header_path = resource.with_name(key + '.headers.json')
    final_path = resource.with_name(key + '.url')
    if not resource.is_file() or not header_path.is_file() or not final_path.is_file():
        return None
    if final_path.read_text() != url:
        return None  # A final-body-only redirect cache cannot replay each hop.
    body = resource.read_bytes()
    if not body or len(body) > 16 * 1024 * 1024:
        return None
    headers = json.loads(header_path.read_text())
    # HTTP client's cache contains decoded bodies. Wire compression/framing
    # headers therefore cannot be replayed literally over CDP.
    headers = [h for h in headers if h['name'].lower() not in (
        'content-encoding', 'transfer-encoding', 'content-length')]
    headers.append({'name': 'content-length', 'value': str(len(body))})
    if resource_type == 'Document':
        page = cache / 'pages' / key
        if not page.is_file() or page.read_bytes() != body:
            raise RuntimeError('Canonical document differs between native cache and replay')
    return body, headers, resource


class PikabuReplayCDP(ReplayCDP):
    def __init__(self, url, cache):
        super().__init__(url, cache)
        self.replay_rows = {}

    def pump(self):
        response = self.receive()
        identifier = response.get('id')
        if identifier is not None:
            if identifier in self.pending_replay:
                self.pending_replay.remove(identifier)
                row = self.replay_rows.pop(identifier)
                if 'error' in response:
                    error = response['error']
                    # A paused request can disappear before Chrome handles
                    # its asynchronous reply (for example after cancellation).
                    # Record that rejection without retrying or allowing the
                    # request onto the network. All other protocol errors fail.
                    if (error.get('code') == -32602
                            and error.get('message') == 'Invalid InterceptionId.'):
                        row['requested_action'] = row['action']
                        row['action'] = 'canceled-interception'
                        row['replay_error'] = error
                        return
                    raise RuntimeError(response['error'])
                row['acknowledged'] = True
            else:
                self.responses[identifier] = response
            return
        method = response.get('method')
        params = response.get('params', {})
        if method != 'Fetch.requestPaused':
            self.events.append(response)
            return
        request = params['request']
        url = request['url']
        kind = params['resourceType']
        cached = frozen_response(self.cache, url, kind)
        row = {'url': url, 'resource_type': kind, 'method': request['method']}
        if cached is None or request['method'] != 'GET':
            row['action'] = 'failed-missing-or-non-get'
            command = self.issue('Fetch.failRequest', {'requestId': params['requestId'],
                                                       'errorReason': 'BlockedByClient'})
        else:
            body, headers, path = cached
            row.update(action='replayed', bytes=len(body), sha256=hashlib.sha256(body).hexdigest(),
                       headers_sha256=hashlib.sha256(json.dumps(headers, sort_keys=True).encode()).hexdigest(),
                       cache_path=str(path))
            command = self.issue('Fetch.fulfillRequest', {'requestId': params['requestId'],
                'responseCode': 200, 'responseHeaders': headers,
                'body': base64.b64encode(body).decode()})
        self.pending_replay.add(command)
        self.replay_rows[command] = row
        self.requests.append(row)


def content_ready(state, width, height):
    """Reject loading screens, empty stories, missing viewport images and fonts."""
    images = [i for i in state.get('images', []) if i['rect']['width'] > 100
              and i['rect']['height'] > 100 and i['rect']['top'] < height
              and i['rect']['bottom'] > 0]
    return (state.get('url') == URL and state.get('ready') == 'complete'
            and (state.get('width'), state.get('height'), state.get('scale')) == (width, height, 1)
            and state.get('stories', 0) > 0 and len(state.get('text', '')) > 1000
            and bool(state.get('firstTitle', '').strip()) and state.get('fontsStatus') == 'loaded'
            and bool(images) and all(i['complete'] and i['naturalWidth'] > 0 for i in images))


def native_content_state(audit):
    """Normalize the generic native observer without inventing DOM image data.

    Vox's compact paint bridge can retain decoded pixels separately from its
    HTMLImageElement model. Both original model and actual paint cache state
    remain in the raw audit; the readiness gate accepts either decoded source.
    """
    selections = {s['name']: s for s in audit['selections']}
    titles = selections.get('first_title', {}).get('elements', [])
    images = []
    for element in selections.get('story_images', {}).get('elements', []):
        image = element.get('image')
        if not image:
            continue
        rect = element['rect']
        model_ready = image['complete'] and image['natural_width'] > 0
        images.append(dict(
            src=image['current_src'] or element['attributes'].get('src', ''),
            complete=model_ready or image['paint_decoded'],
            naturalWidth=image['natural_width'] if model_ready else image['paint_width'],
            naturalHeight=image['natural_height'] if model_ready else image['paint_height'],
            rect=dict(width=rect['width'], height=rect['height'], top=rect['y'],
                      bottom=rect['y'] + rect['height'])))
    bodies = selections.get('body', {}).get('elements', [])
    return dict(url=audit['url'], title=audit['title'], ready=audit['ready'],
                width=audit['viewport_width'], height=audit['viewport_height'], scale=1,
                stories=selections.get('stories', {}).get('count', 0),
                firstTitle=titles[0]['text'] if titles else '',
                text=bodies[0]['text'] if bodies else '', images=images,
                fontsStatus=audit['fonts_status'])


def native_font_gate(audit):
    """Require the actual retained Roboto faces used by the Pikabu viewport."""
    verified = set()
    for face in audit.get('font_faces', []):
        family = face['family'].strip(' \"\'').lower()
        weight = {'normal': '400', 'bold': '700'}.get(face['weight'], face['weight'])
        if (family == 'roboto' and face['style'] == 'normal' and face['status'] == 'loaded'
                and face['parsed_font_present'] and face['source_path']):
            verified.add(weight)
    return {'400', '500', '700'} <= verified


def connect_brave(profile, process, counter, deadline, replay_cache=None):
    port, _ = wait_for_chrome_debugger(profile / 'DevToolsActivePort', counter, deadline, .02, profile)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    while True:
        with opener.open(f'http://127.0.0.1:{port}/json/list', timeout=15) as response:
            targets = json.load(response)
        target = next((t for t in targets if t['type'] == 'background_page'
                       and t['url'].endswith('/background.html')), None)
        if target:
            break
        if process.poll() is not None or time.monotonic() > deadline:
            raise RuntimeError('Full MV2 uBlock Origin background did not load')
        time.sleep(.02)
    background = CDP(target['webSocketDebuggerUrl'])
    try:
        while not evaluate(background, "typeof vAPI!=='undefined' && typeof vAPI.defer?.create==='function'"):
            if time.monotonic() > deadline:
                raise TimeoutError('uBO bootstrap')
            time.sleep(.02)
        while not evaluate(background, "(async()=> (await import('./js/background.js')).default.readyToFilter)()"):
            if time.monotonic() > deadline:
                raise TimeoutError('uBO filter readiness')
            time.sleep(.02)
        page_target = next(t for t in targets if t['type'] == 'page')
        page = (PikabuReplayCDP(page_target['webSocketDebuggerUrl'], replay_cache)
                if replay_cache else CDP(page_target['webSocketDebuggerUrl']))
        return background, page
    except BaseException:
        background.sock.close()
        raise


def brave_command(args, profile, offline):
    command = [str(args.binary), '--headless=new', '--no-first-run', '--no-default-browser-check',
               '--disable-sync', '--disable-background-networking', '--remote-debugging-port=0',
               '--remote-allow-origins=*', '--user-data-dir=' + str(profile),
               '--load-extension=' + str(args.extension)]
    if offline:
        command.append('--no-proxy-server')
        command.append('--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost')
    return command + ['about:blank']


def close_brave(process, background, page):
    if page:
        try:
            page.call('Browser.close')
        except (EOFError, OSError):
            pass
        page.sock.close()
    if background:
        background.sock.close()
    # Browser.close schedules profile/database flushes. Let that graceful exit
    # finish before the watchdog fallback; otherwise a prepared selfie can be
    # lost and every measured launch needlessly recompiles full filter lists.
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        pass
    stop_process(process)


def prepare_profile(args):
    if args.profile.exists():
        raise RuntimeError('Refusing to overwrite existing prepared profile')
    manifest, lists = list_inputs()
    extension_manifest = json.loads((args.extension / 'manifest.json').read_text())
    if (extension_manifest.get('manifest_version') != 2
            or extension_manifest.get('name') != 'uBlock Origin'
            or extension_manifest.get('version') != manifest['engine']['version']):
        raise RuntimeError('Pinned full MV2 uBlock Origin is required')
    (args.profile / 'Default').mkdir(parents=True)
    (args.profile / 'Default/Preferences').write_text(json.dumps({
        'profile': {'default_content_setting_values': {'braveShields': 2}}}))
    background = page = None
    command = brave_command(args, args.profile, False)
    with Path(str(args.output) + '.prepare.log').open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            counter = ProcessTreeCounter(MacCounters(), process.pid)
            background, page = connect_brave(args.profile, process, counter, time.monotonic() + args.timeout)
            selected = evaluate(background, """(async()=>{
                const u=(await import('./js/background.js')).default;
                const a=(await import('./js/assets.js')).default;
                u.userSettings.autoUpdate=false;await u.saveUserSettings();
                const lists=""" + json.dumps(lists) + """;
                await u.saveSelectedFilterLists(lists.map(x=>x.name));
                for(const list of lists)await a.put(list.name,list.content);
                await a.remove(/^compiled\\//);await u.loadFilterLists();
                await u.selfieManager.create();return u.selectedFilterLists;})()""")
            metadata = {'selected_lists': selected, 'extension': str(args.extension),
                        'extension_sha256': fingerprint_tree(args.extension)['sha256'],
                        'extension_version': extension_manifest['version'],
                        'list_manifest_sha256': digest(REPO / 'adblock/lists/manifest.json'),
                        'preparation_note': 'Unmeasured one-time exact list installation and compiled engine snapshot; no page visit.'}
        finally:
            close_brave(process, background, page)
    metadata['profile_sha256'] = fingerprint_tree(args.profile)['sha256']
    (args.profile.parent / (args.profile.name + '.json')).write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata), flush=True)


def run_brave(args, api):
    metadata = json.loads((args.profile.parent / (args.profile.name + '.json')).read_text())
    profile_before = fingerprint_tree(args.profile)
    if metadata.get('profile_sha256', profile_before['sha256']) != profile_before['sha256']:
        raise RuntimeError('Prepared profile bytes changed')
    if metadata['extension_sha256'] != fingerprint_tree(args.extension)['sha256']:
        raise RuntimeError('Prepared extension bytes changed')
    if metadata['list_manifest_sha256'] != digest(REPO / 'adblock/lists/manifest.json'):
        raise RuntimeError('Prepared list manifest changed')
    with fresh_copy(args.profile, args.scratch_dir, 'profile') as profile:
        background = page = None
        command = brave_command(args, profile, True)
        log_path = Path(str(args.output) + '.log')
        with log_path.open('w') as log:
            launched = time.monotonic()
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            counter = ProcessTreeCounter(api, process.pid)
            try:
                with CounterSampler(counter, args.sample_interval):
                    deadline = time.monotonic() + args.timeout
                    background, page = connect_brave(profile, process, counter, deadline, args.cache)
                    settings = evaluate(background, """(async()=>{const u=(await import('./js/background.js')).default;
                        return {selected:u.selectedFilterLists,autoUpdate:u.userSettings.autoUpdate,
                                ready:u.readyToFilter};})()""")
                    if (settings['selected'] != metadata['selected_lists'] or settings['autoUpdate']
                            or not settings['ready']):
                        raise RuntimeError('Prepared full uBO settings did not survive restart')
                    for method in ['Page.enable', 'Runtime.enable', 'Network.enable']:
                        page.call(method)
                    page.call('Network.setBypassServiceWorker', {'bypass': True})
                    page.call('Network.setCacheDisabled', {'cacheDisabled': True})
                    page.call('Emulation.setDeviceMetricsOverride', dict(width=args.width, height=args.height,
                                                                         deviceScaleFactor=1, mobile=False))
                    page.call('Fetch.enable', {'patterns': [{'urlPattern': '*', 'requestStage': 'Request'}]})
                    baseline = counter.sample()
                    navigation = time.monotonic()
                    page.call('Page.navigate', {'url': URL})
                    while True:
                        value = evaluate(page, DOC_STATE)
                        state = json.loads(value) if value else {}
                        if content_ready(state, args.width, args.height):
                            break
                        if time.monotonic() > deadline:
                            raise RuntimeError('Pikabu content gate failed: ' + json.dumps(state, ensure_ascii=False))
                        time.sleep(.02)
                    image = page.call('Page.captureScreenshot', {'format': 'png', 'captureBeyondViewport': False})
                    endpoint = time.monotonic()
                    snapshot = counter.snapshot_before(endpoint)
                    result = counter.report(snapshot=snapshot)
                    result.update(navigation_to_capture=counter.report(baseline, snapshot=snapshot),
                        process_launch_to_capture_ms=(endpoint - launched) * 1000,
                        navigation_to_capture_ms=(endpoint - navigation) * 1000,
                        final_sample_precedes_capture_ms=(endpoint - snapshot.sampled_at) * 1000,
                        endpoint='completed frozen Pikabu stories, visible image and fonts ready; first CDP screenshot response',
                        content_gate_passed=True, document=state, command=command, ubo=settings,
                        profile_metadata=metadata, version=page.call('Browser.getVersion'))
                    Path(str(args.output) + '.png').write_bytes(base64.b64decode(image['data']))
                    # The audit starts strictly after the instruction boundary.
                    result['requests'] = page.requests
                    result['events'] = [e for e in page.events if e['method'] in (
                        'Runtime.exceptionThrown', 'Runtime.consoleAPICalled', 'Network.loadingFailed')]
                    result['resources'] = evaluate(page, "JSON.stringify(performance.getEntriesByType('resource').map(x=>x.toJSON()))")
                    result['font_audit'] = evaluate(page, """JSON.stringify({
                        faces:[...document.fonts].map(f=>({family:f.family,style:f.style,
                            weight:f.weight,status:f.status})),
                        firstStoryFamily:getComputedStyle(document.querySelector('.story__title')).fontFamily,
                        robotoRegular:document.fonts.check('16px Roboto'),
                        robotoMedium:document.fonts.check('500 16px Roboto'),
                        robotoBold:document.fonts.check('700 16px Roboto')})""")
                    font_audit = json.loads(result['font_audit'])
                    result['font_gate_passed'] = all(font_audit[key] for key in (
                        'robotoRegular', 'robotoMedium', 'robotoBold'))
                    result['content_gate_passed'] &= result['font_gate_passed']
                    result['brave_version'] = subprocess.check_output(
                        ['/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleShortVersionString',
                         str(args.binary.parents[1] / 'Info.plist')], text=True).strip()
            finally:
                close_brave(process, background, page)
    if profile_before != fingerprint_tree(args.profile):
        raise RuntimeError('Prepared profile template changed during measurement')
    result['profile_template_sha256'] = profile_before['sha256']
    return result


def run_native(args, api):
    library = args.network_deny.resolve()
    if not library.is_file():
        raise RuntimeError('Build the process-local network deny dylib first')
    config_path = Path(str(args.output) + '.audit-config.json')
    config_path.write_text(json.dumps({'selectors': [
        {'name': 'stories', 'selector': 'article.story', 'limit': 0},
        {'name': 'first_title', 'selector': '.story__title', 'limit': 1},
        {'name': 'story_images', 'selector': 'article.story img', 'limit': 100,
         'attributes': ['src', 'data-src']},
        {'name': 'body', 'selector': 'body', 'limit': 1},
    ]}))
    audit_path = Path(str(args.output) + '.document.json')
    audit_path.unlink(missing_ok=True)
    with fresh_copy(args.cache, args.scratch_dir, 'cache') as cache:
        for variable in ('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy',
                         'https_proxy', 'all_proxy'):
            os.environ.pop(variable, None)
        os.environ.update(VOX_TEST_WINDOW='1', DYLD_INSERT_LIBRARIES=str(library),
                          VOX_ADBLOCK_LOG=str(args.output) + '.requests.jsonl',
                          VOX_CAPTURE_AUDIT_PATH=str(audit_path),
                          VOX_CAPTURE_AUDIT_CONFIG=str(config_path))
        os.environ.pop('LADYBIRD_ENABLE_SNAPSHOT_CACHE', None)
        args.url = URL
        args.vox_arg = ['--enable-javascript']
        result = run_vox(args, args.output, api, cache)
        result['network_deny_sha256'] = digest(library)
        result['author_javascript_enabled'] = True
        result['network_policy'] = 'Process-local getaddrinfo/connect guard allows only loopback; same frozen cache, no live refresh.'
        if audit_path.exists():
            result['native_document_audit'] = json.loads(audit_path.read_text())
            result['document'] = native_content_state(result['native_document_audit'])
            result['font_gate_passed'] = native_font_gate(result['native_document_audit'])
            result['content_gate_passed'] = (content_ready(result['document'], args.width, args.height)
                                             and result['font_gate_passed'])
        else:
            result['content_gate_passed'] = False
            result['content_gate_note'] = 'Native binary lacks opt-in capture DOM audit; capture remains a diagnostic pending content validation.'
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', choices=['vox', 'brave', 'prepare-profile'], required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--extension', type=Path)
    parser.add_argument('--profile', type=Path)
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--network-deny', type=Path, default=REPO / 'Build/pikabu-instructions-network-deny.dylib')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=656)
    parser.add_argument('--sample-interval', type=float, default=.005)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--scratch-dir', type=Path)
    args = parser.parse_args()
    for field in ['binary', 'extension', 'profile', 'cache', 'output', 'network_deny', 'scratch_dir']:
        value = getattr(args, field)
        if value is not None:
            setattr(args, field, value.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.width <= 0 or args.height <= 0 or args.sample_interval <= 0 or args.timeout <= 0:
        parser.error('dimensions, interval and watchdog must be positive')
    if args.engine in ['brave', 'prepare-profile'] and (not args.extension or not args.profile):
        parser.error('Brave requires --extension and --profile')
    if args.engine == 'prepare-profile':
        prepare_profile(args)
        return
    if not args.cache or not args.cache.is_dir():
        parser.error('Frozen replay requires --cache')
    before = fingerprint_tree(args.cache)
    binary_before = digest(args.binary)
    result = run_native(args, MacCounters()) if args.engine == 'vox' else run_brave(args, MacCounters())
    if binary_before != digest(args.binary) or before != fingerprint_tree(args.cache):
        raise RuntimeError('Binary or frozen cache changed during measurement')
    result.update(engine=args.engine, binary=str(args.binary), binary_sha256=binary_before,
                  cache_sha256=before['sha256'], url=URL, viewport=[args.width, args.height],
                  workload='Frozen archived Pikabu HTTPS responses, fail-closed misses, author JavaScript enabled; not full browsing parity.',
                  response_policy='Legacy cache has body/header/final-URL provenance but no status field. Admitted same-URL responses are normalized to status200; wire compression/framing headers are removed for decoded bodies, length is recomputed; other recorded headers are preserved.',
                  measurement_driver_sha256=digest(__file__),
                  counter_module_sha256=digest(REPO / 'tools/process_instruction_counts.py'),
                  machine=platform.machine(), kernel=platform.release(),
                  sample_interval_seconds=args.sample_interval,
                  screenshot_sha256=digest(str(args.output) + '.png'))
    Path(str(args.output) + '.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({k: result.get(k) for k in ['engine', 'instructions', 'content_gate_passed',
          'process_launch_to_capture_ms', 'process_launch_to_capture_observed_ms', 'cache_sha256']}), flush=True)


if __name__ == '__main__':
    main()
