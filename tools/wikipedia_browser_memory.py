#!/usr/bin/env python3
"""Windowed, offline Wikipedia memory comparison with explicit Chrome scripting.

Primary memory is the simultaneous sum of macOS task physical footprints,
never summed RSS. Each fresh browser is measured from launch until a settled
pre-screenshot endpoint. GPU and utility descendants remain enabled and count.
The observed simultaneous peak is a polling lower bound; separate task lifetime
maxima are an auxiliary envelope and are never called a simultaneous peak.
"""
import argparse
import base64
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import platform as host_platform
import shutil
import select
import statistics
import struct
import subprocess
import tempfile
import threading
import time
import urllib.request

from compare_browser_memory import ForegroundControl, activate_browser
from measure_browser_instructions import (
    VOX_CHROME_HEIGHT, VOX_TOOLBAR_HEIGHT, chrome_debugger_endpoint,
    crop_document_viewport, fresh_vox_cache, stop_process,
)
from measure_browser_render import scripting_summary
from probe_frozen_github_chrome import ReplayCDP
from process_instruction_counts import CounterSampler, MacCounters, RusageInfoV4

REPO = Path(__file__).resolve().parents[1]
URL = 'https://www.wikipedia.org/'
PORTAL_SCRIPTS = {
    URL + 'portal/wikipedia.org/assets/js/index-43aa8c7b47.js':
        'c406c48ae80988a75fbfa2993f8b6faa18853e175cd602c8cbf474cf68c4dfc7',
    URL + 'portal/wikipedia.org/assets/js/gt-ie9-507b16b6be.js':
        'b6095c067391ecb2841c3bdb11534507ed219c958bba2a20720ae876b6f2cb31',
}


def chrome_scripting_enabled(policy):
    if policy not in ('disabled', 'enabled'):
        raise ValueError('Chrome script policy must be disabled or enabled')
    return policy == 'enabled'


class ObservedReplayCDP(ReplayCDP):
    """Retain actual command order and host receipt times for lifecycle events."""
    def __init__(self, url, cache):
        self.commands = []
        super().__init__(url, cache)

    def issue(self, method, params=None):
        observed = time.monotonic()
        identifier = super().issue(method, params)
        self.commands.append(dict(id=identifier, method=method, issued_monotonic=observed))
        return identifier

    def pump(self):
        before = len(self.events)
        super().pump()
        if len(self.events) > before:
            self.events[-1]['observer_received_monotonic'] = time.monotonic()


def begin_chrome_navigation(client, screen, activity, activate, started, script_policy='disabled'):
    scripting = chrome_scripting_enabled(script_policy)
    version = client.call('Browser.getVersion')
    for method in ['Page.enable', 'Network.enable']:
        client.call(method)
    client.call('Page.setLifecycleEventsEnabled', {'enabled': True})
    client.call('Network.setCacheDisabled', {'cacheDisabled': True})
    client.call('Network.setBypassServiceWorker', {'bypass': True})
    client.call('Emulation.setDeviceMetricsOverride', dict(width=1024, height=768,
        deviceScaleFactor=screen['scale'], mobile=False))
    client.call('Emulation.setScriptExecutionDisabled', {'value': not scripting})
    client.call('Fetch.enable', {'patterns': [{'urlPattern': 'http*', 'requestStage': 'Request'}]})
    if activate:
        client.call('Page.bringToFront')
    activity.poll(time.monotonic() - started, force=True)
    return version, client.call('Page.navigate', {'url': URL})


def lifecycle_readiness(events, navigation):
    frame, loader = navigation.get('frameId'), navigation.get('loaderId')
    if not frame or not loader:
        raise RuntimeError('Chrome navigation did not identify its frame and loader')
    committed, milestones = None, {}
    for event in events:
        params = event.get('params', {})
        if event.get('method') == 'Page.frameNavigated':
            actual = params.get('frame', {})
            if actual.get('id') == frame and actual.get('loaderId') == loader:
                if actual.get('url') != URL:
                    raise RuntimeError('Chrome committed an unexpected document URL')
                committed = event
        if (event.get('method') == 'Page.lifecycleEvent' and params.get('frameId') == frame
                and params.get('loaderId') == loader):
            milestones.setdefault(params.get('name'), event)
    paint = milestones.get('firstContentfulPaint', milestones.get('firstPaint'))
    if committed is None or paint is None or 'load' not in milestones or 'networkIdle' not in milestones:
        return None
    required = [committed, paint, milestones['load'], milestones['networkIdle']]
    return dict(frame_id=frame, loader_id=loader, url=URL,
        ready_monotonic=max(e['observer_received_monotonic'] for e in required),
        frame_commit=committed, load=milestones['load'], network_idle=milestones['networkIdle'], paint=paint,
        note='Matching frame/loader commit, paint, load and networkIdle; host receipt of last required event. No Runtime observer commands before memory endpoint. Frozen fixture contains no font-face rules or external fonts.')


def verify_runtime_after_endpoint(commands, endpoint_monotonic):
    if any(c['method'].startswith('Runtime.') and c['issued_monotonic'] < endpoint_monotonic
            for c in commands):
        raise RuntimeError('A Runtime observer command preceded the primary memory endpoint')


def application_state(pid):
    script = f'''ObjC.import('AppKit');
    const app=$.NSRunningApplication.runningApplicationWithProcessIdentifier({pid});
    JSON.stringify({{pid:Number(app.processIdentifier),active:Number(app.processIdentifier)==={pid}&&Boolean(app.active)}});'''
    return json.loads(subprocess.check_output(['osascript', '-l', 'JavaScript', '-e', script], text=True))


class BackgroundControl:
    """Restore the original foreground app, then require browser inactivity."""
    def __init__(self, pid, anchor, inspect=None, restore=None):
        self.pid, self.anchor = pid, anchor
        self.inspect, self.restore = inspect or application_state, restore or activate_browser
        self.next_check, self.checks = 0, []

    def poll(self, elapsed, force=False):
        if not force and elapsed < self.next_check:
            return
        before = self.inspect(self.pid)
        restored = self.restore(self.anchor) if before['active'] else None
        after = self.inspect(self.pid) if restored else before
        self.checks.append(dict(seconds=elapsed, pid=self.pid,
            was_active=before['active'], active=after['active'], restored_anchor=restored))
        self.next_check = elapsed + 1

    def verify_steady(self, endpoint, window=2):
        start = endpoint - window
        before = [r for r in self.checks if r['seconds'] <= start]
        recent = [r for r in self.checks if start < r['seconds'] <= endpoint]
        if not before or not recent or endpoint - recent[-1]['seconds'] > 1.5:
            raise RuntimeError('Insufficient background application checks')
        if any(r['was_active'] or r['active'] for r in [before[-1], *recent]):
            raise RuntimeError('Browser became active around the settled memory window')
        return [start, endpoint]


def activity_control(args, pid, start_at=0):
    if args.background:
        return BackgroundControl(pid, args.background_anchor_pid)
    return ForegroundControl(pid, args.foreground, start_at=start_at)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint_tree(path):
    return {str(p.relative_to(path)): digest(p) for p in sorted(path.rglob('*')) if p.is_file()}


class PhysicalTree:
    """Keep discovered live children even when their parent exits/reparents.

    PID/start-time pairs prevent counting a reused PID as part of this browser.
    Every snapshot retains task roles and any disappearance during enumeration.
    """
    def __init__(self, root, started, api=None):
        self.api = api or MacCounters()
        self.root, self.started = root, started
        self.known, self.samples = {}, []
        self.lock = threading.Lock()

    def sample(self):
        with self.lock:
            pending = [self.root, *self.known]
            seen, live, vanished, reused = set(), [], [], []
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
                    vanished.append(pid)
                    continue
                start = usage.ri_proc_start_abstime
                if pid in self.known and self.known[pid] != start:
                    reused.append(pid)
                    continue
                self.known[pid] = start
                if usage.ri_proc_exit_abstime:
                    continue
                live.append(dict(pid=pid, start_ticks=start, path=self.api.path(pid),
                    physical_footprint_bytes=usage.ri_phys_footprint,
                    resident_size_bytes=usage.ri_resident_size,
                    task_lifetime_peak_bytes=max(usage.ri_lifetime_max_phys_footprint,
                                                 usage.ri_phys_footprint)))
                pending.extend(self.api.children(pid))
            self.samples.append(dict(seconds=time.monotonic() - self.started,
                physical_footprint_bytes=sum(p['physical_footprint_bytes'] for p in live),
                processes=live, vanished_during_sample=vanished, reused_pids_excluded=reused))


def summarize(samples, endpoint, window=1):
    live = [s for s in samples if s['seconds'] <= endpoint and s['processes']]
    steady = [s for s in live if endpoint - window <= s['seconds'] <= endpoint]
    if len(steady) < 5:
        raise RuntimeError('Insufficient settled process-tree memory observations')
    if endpoint - steady[-1]['seconds'] > .1:
        raise RuntimeError('Last memory observation is too far before endpoint')
    task_peaks = {}
    for row in live:
        for task in row['processes']:
            identity = task['pid'], task['start_ticks']
            task_peaks[identity] = max(task_peaks.get(identity, 0), task['task_lifetime_peak_bytes'])
    values = [s['physical_footprint_bytes'] for s in steady]
    peak = max(live, key=lambda s: s['physical_footprint_bytes'])
    return dict(settled_physical_footprint_bytes=statistics.median(values),
        settled_range_bytes=[min(values), max(values)], settled_sample_count=len(steady),
        settled_window_seconds=[endpoint - window, endpoint],
        observed_simultaneous_peak_bytes=peak['physical_footprint_bytes'],
        observed_peak_seconds=peak['seconds'], observed_peak_processes=peak['processes'],
        task_lifetime_peak_sum_envelope_bytes=sum(task_peaks.values()),
        peak_note='Launch to pre-capture endpoint. Observed simultaneous peak is a polling lower bound; sum of task lifetime maxima is a non-simultaneous auxiliary envelope.',
        endpoint_processes=steady[-1]['processes'],
        max_sample_gap_seconds=max((b['seconds'] - a['seconds'] for a, b in zip(live, live[1:])), default=0),
        final_sample_gap_seconds=endpoint - steady[-1]['seconds'])


def settled_reduction(vox, chrome):
    vox_values = [r['memory']['settled_physical_footprint_bytes'] for r in vox]
    chrome_values = [r['memory']['settled_physical_footprint_bytes'] for r in chrome]
    v, c = statistics.median(vox_values), statistics.median(chrome_values)
    if min(v, c) <= 0:
        raise ValueError('Physical footprint must be positive')
    median_met = v <= c * .30
    worst_met = max(vox_values) <= .30 * min(chrome_values)
    return dict(vox_settled_median_bytes=v, chrome_settled_median_bytes=c,
        vox_target_bytes=c * .30, strict_vox_target_bytes=min(chrome_values) * .30,
        settled_reduction=1 - v / c, median_target_met=median_met, target_met=median_met and worst_met,
        vox_settled_range_bytes=[min(vox_values), max(vox_values)],
        chrome_settled_range_bytes=[min(chrome_values), max(chrome_values)],
        worst_vox_over_best_chrome=max(vox_values) / min(chrome_values),
        every_vox_below_thirty_percent_of_every_chrome=worst_met,
        vox_observed_peak_median_bytes=statistics.median(r['memory']['observed_simultaneous_peak_bytes'] for r in vox),
        chrome_observed_peak_median_bytes=statistics.median(r['memory']['observed_simultaneous_peak_bytes'] for r in chrome))


def placement():
    # Cocoa coordinates run upward; Chrome bounds use the main display's top.
    script = '''ObjC.import('AppKit');
    const screens=$.NSScreen.screens, mouse=$.NSEvent.mouseLocation;
    let selected=screens.objectAtIndex(0), mainTop=Number(selected.frame.origin.y)+Number(selected.frame.size.height);
    for(let i=0;i<Number(screens.count);i++){let s=screens.objectAtIndex(i),f=s.frame;
      let inside=Number(mouse.x)>=Number(f.origin.x)&&Number(mouse.x)<Number(f.origin.x)+Number(f.size.width)&&Number(mouse.y)>=Number(f.origin.y)&&Number(mouse.y)<Number(f.origin.y)+Number(f.size.height);
      if(!inside){selected=s;break;}}
    const f=selected.visibleFrame;
    JSON.stringify({left:Math.round(Number(f.origin.x)+Number(f.size.width)-1024),top:Math.round(mainTop-Number(f.origin.y)-Number(f.size.height)),scale:Number(selected.backingScaleFactor)});'''
    return json.loads(subprocess.check_output(['osascript', '-l', 'JavaScript', '-e', script], text=True))


def clean_environment(inherited=None):
    env = dict(os.environ if inherited is None else inherited)
    for key in list(env):
        if key.startswith(('GC_', 'JSC_', 'VOX_', 'LADYBIRD_', 'DYLD_', 'MTL_', 'SKIA_', 'CHROME_', 'CHROMIUM_')) or key.lower() in ('http_proxy', 'https_proxy', 'all_proxy'):
            env.pop(key)
    env.update(VOX_TEST_WINDOW='1', VOX_COOKIE_FILE='')
    return env


def vox_environment(args, cache, screen, prefix):
    env = clean_environment()
    env.update(LADYBIRD_CACHE_DIR=str(cache), LADYBIRD_DEBUG_TIMING='1',
        LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle + 2),
        LADYBIRD_SCREENSHOT_SCALE=str(screen['scale']),
        DYLD_INSERT_LIBRARIES=str(args.network_deny), DYLD_LIBRARY_PATH=str(args.vox.parent),
        VOX_CAPTURE_AUDIT_PATH=str(prefix.with_suffix('.capture.json')),
        VOX_CAPTURE_AUDIT_CONFIG=str(prefix.with_suffix('.capture-config.json')))
    if args.diagnostic_gc_stats:
        env['GC_PRINT_STATS'] = '1'
    return env


def png_dimensions(path):
    header = path.read_bytes()[:24]
    if len(header) != 24 or header[:8] != b'\x89PNG\r\n\x1a\n':
        raise RuntimeError('Invalid PNG header')
    return struct.unpack('!II', header[16:24])


def require_png_scale(path, width, height, scale):
    dimensions = png_dimensions(path)
    expected = (round(width * scale), round(height * scale))
    if dimensions != expected:
        raise RuntimeError(f'PNG raster dimensions {dimensions}; require {expected}')
    return dimensions


def crop_native_viewport(window, raw, logical, scale):
    subprocess.run(['sips', '--cropToHeightWidth', str(round(768 * scale)), str(round(1024 * scale)),
        '--cropOffset', str(round(VOX_TOOLBAR_HEIGHT * scale)), '0', str(window), '--out', str(raw)],
        check=True, stdout=subprocess.DEVNULL)
    require_png_scale(raw, 1024, 768, scale)
    shutil.copyfile(raw, logical)
    if scale != 1:
        subprocess.run(['sips', '--resampleHeightWidth', '768', '1024', str(logical)],
            check=True, stdout=subprocess.DEVNULL)


def audit_timing(started, started_wall_ns, mtime_ns, observed, settle):
    ready = (mtime_ns - started_wall_ns) / 1_000_000_000
    lag = observed - started - ready
    if ready < 0 or lag < -.05 or lag > .5:
        raise RuntimeError(f'Capture audit timestamp/observation lag is invalid: {lag:.3f}s')
    return dict(ready_seconds=ready, first_observed_seconds=observed - started,
        observation_lag_seconds=lag, endpoint_seconds=ready + settle,
        screenshot_earliest_seconds=ready + settle + 2)


def validate_vox_document(document):
    if (document['url'] != URL or document['ready'] != 'complete' or
            (document['viewport_width'], document['viewport_height']) != (1024, 768) or
            document['paint_commands'] <= 0 or document['javascript_diagnostics']):
        raise RuntimeError('Vox document readiness/viewport/paint audit failed')
    selections = {s['name']: s for s in document['selections']}
    if (selections['body']['count'] != 1 or len(selections['body']['elements']) != 1 or
            selections['body']['elements'][0]['text_utf8_bytes'] < 5000 or
            selections['root']['count'] != 1 or selections['sprites']['count'] != 21 or
            'no-js' not in selections['root']['elements'][0]['attributes'].get('class', '')):
        raise RuntimeError('Vox portal body/root/sprite audit failed')
    globe = selections['globe']
    image = globe['elements'][0].get('image') if globe['count'] == 1 and globe['elements'] else None
    expected_src = URL + 'portal/wikipedia.org/assets/img/Wikipedia-logo-v2@2x.png'
    if not image or not image['model_present'] or not image['complete'] or image['current_src'] != expected_src or (image['natural_width'], image['natural_height']) != (200, 183):
        raise RuntimeError('Vox Retina globe is not decoded at density 2')
    # paint_decoded reads the literal src cache rather than the model's selected
    # srcset bitmap, so current_src+natural dimensions are the density proof.
    if document['fonts_status'] not in ('loaded', 'unmaterialized') or any(
            face['status'] != 'loaded' for face in document['font_faces']):
        raise RuntimeError('Vox fonts are still pending')


def validate_chrome_targets(audit):
    pages = [t for t in audit['targetInfos'] if t['type'] == 'page']
    if len(pages) != 1 or pages[0]['url'] != URL:
        raise RuntimeError('Chrome must contain exactly one Wikipedia page target')


def validate_chrome_document(document, scale, script_policy='disabled'):
    scripting = chrome_scripting_enabled(script_policy)
    if (document['url'] != URL or document['ready'] != 'complete' or document['width'] != 1024
            or document['height'] != 768 or document['scale'] != scale):
        raise RuntimeError('Chrome viewport or document readiness audit failed')
    classes = document['rootClass'].split()
    if scripting:
        if ('js-enabled' not in classes or 'no-js' in classes
                or document.get('portalGlobals') != ['object', 'object', 'object', 'string']
                or document.get('portalDomain') != 'wikipedia.org'
                or not document.get('localizedVisible') or not document.get('languageLabelPresent')
                or 'jsl10n-visible' not in document.get('bodyClass', '').split()):
            raise RuntimeError('Chrome author JavaScript execution audit failed')
    elif 'no-js' not in classes or any(x != 'undefined' for x in document['authorGlobals']):
        raise RuntimeError('Chrome no-JavaScript policy audit failed')
    if document['fontsStatus'] != 'loaded':
        raise RuntimeError('Chrome fonts were pending after the primary endpoint')
    expected_src = URL + 'portal/wikipedia.org/assets/img/Wikipedia-logo-v2@2x.png'
    # Author JS collapses language lists in normal Chrome. Audit the complete
    # parsed body separately from its smaller, normally visible text.
    content_ready = (document['textLength'] >= 500 and document.get('textContentLength', 0) >= 5000
        if scripting else document['textLength'] >= 5000)
    if not content_ready or document['sprites'] != 21 or not any(
            image['src'] == expected_src and image['complete'] and image['width'] == 200
            and image['height'] == 183 for image in document['images']):
        raise RuntimeError('Chrome frozen portal content or Retina globe is incomplete')


def validate_chrome_requests(requests, script_policy='disabled'):
    scripting = chrome_scripting_enabled(script_policy)
    scripts = [r for r in requests if r['resource_type'] == 'Script']
    if not scripting:
        if scripts:
            raise RuntimeError('Chrome fetched an author script while disabled')
        return
    if {r['url'] for r in scripts} != set(PORTAL_SCRIPTS) or any(
            r.get('action') != 'replayed' or r.get('method') != 'GET'
            or r.get('sha256') != PORTAL_SCRIPTS[r['url']] for r in scripts):
        raise RuntimeError('Chrome author scripts did not replay the exact frozen assets')
    if any(r.get('action') != 'replayed' for r in requests if r['resource_type'] in
            ('XHR', 'Fetch', 'Stylesheet', 'Font')):
        raise RuntimeError('Chrome author JavaScript required an uncached rendering resource')


def drain_replay(client):
    # Service late favicon/resource Fetch pauses and acknowledgements without
    # evaluating author-observer JavaScript during the settled memory window.
    while client.pending or select.select([client.sock], [], [], 0)[0]:
        client.pump()


def launch_external_diagnostic(command, output, receipt, metadata):
    # The observer must keep polling activity while vmmap analyzes its target.
    # This child belongs to the observer, not the browser's measured task tree.
    with output.open('w') as log:
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
    return dict(process=process, output=output, receipt=receipt,
        record=dict(command=command, diagnostic_pid=process.pid,
                    launched_monotonic=time.monotonic(), **metadata))


def finish_external_diagnostics(jobs):
    records = []
    for job in jobs:
        row = job['record']
        if 'actual_exit_code' not in row:
            try:
                row['actual_exit_code'] = job['process'].wait(timeout=30)
                row['timed_out'] = False
            except subprocess.TimeoutExpired:
                job['process'].kill()
                row['actual_exit_code'] = job['process'].wait()
                row['timed_out'] = True
            row.update(completed_monotonic=time.monotonic(), output=str(job['output']),
                       output_sha256=digest(job['output']))
            job['receipt'].write_text(json.dumps(row, indent=2) + '\n')
        records.append(dict(row))
    return records


def chrome_sample(args, prefix, screen):
    log_path = prefix.with_suffix('.log')
    client = process = None
    with tempfile.TemporaryDirectory(prefix='chrome-profile-', dir=args.output) as profile:
        command = [str(args.chrome), '--no-first-run', '--no-default-browser-check',
            '--disable-background-networking', '--remote-debugging-port=0',
            '--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost',
            f'--user-data-dir={profile}', '--window-size=1024,911',
            f"--window-position={screen['left']},{screen['top']}", 'about:blank']
        with log_path.open('w') as log:
            started = time.monotonic()
            load_at_launch = os.getloadavg()
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True, env=clean_environment())
            counter = PhysicalTree(process.pid, started)
            foreground = activity_control(args, process.pid)
            try:
                with CounterSampler(counter, args.interval):
                    active = Path(profile) / 'DevToolsActivePort'
                    while not (debugger := chrome_debugger_endpoint(active)):
                        if process.poll() is not None or time.monotonic() - started > args.timeout:
                            raise RuntimeError('Chrome debugger unavailable')
                        time.sleep(.02)
                    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                    target = None
                    while target is None:
                        with http.open(f'http://127.0.0.1:{debugger[0]}/json/list', timeout=10) as response:
                            target = next((t for t in json.load(response) if t['type'] == 'page'), None)
                        if time.monotonic() - started > args.timeout:
                            raise RuntimeError('Chrome page target unavailable')
                        if target is None:
                            time.sleep(.02)
                    client = ObservedReplayCDP(target['webSocketDebuggerUrl'], args.cache)
                    version, navigation = begin_chrome_navigation(client, screen, foreground,
                        args.foreground, started, args.chrome_script_policy)
                    while True:
                        drain_replay(client)
                        readiness = lifecycle_readiness(client.events, navigation)
                        if readiness is not None:
                            break
                        if time.monotonic() - started > args.timeout:
                            raise RuntimeError('Chrome matching document lifecycle did not become ready')
                        foreground.poll(time.monotonic() - started)
                        time.sleep(.02)
                    ready_at = readiness['ready_monotonic']
                    while time.monotonic() - ready_at < args.settle:
                        drain_replay(client)
                        foreground.poll(time.monotonic() - started)
                        time.sleep(.05)
                    drain_replay(client)
                    endpoint = ready_at - started + args.settle
                    endpoint_observed = time.monotonic() - started
                    load_at_endpoint = os.getloadavg()
                    summary = summarize(counter.samples, endpoint)
                    audit = client.call('Runtime.evaluate', {'expression': '''JSON.stringify({url:location.href,title:document.title,ready:document.readyState,width:innerWidth,height:innerHeight,scale:devicePixelRatio,textLength:document.body.innerText.length,rootClass:document.documentElement.className,authorGlobals:[typeof window.Wikipedia,typeof window.wmf],portalGlobals:[typeof mw,typeof window.wmTest,typeof window.wmL10nVisible,typeof window.portalSearchDomain],portalDomain:window.portalSearchDomain,localizedVisible:!!(window.wmL10nVisible&&window.wmL10nVisible.ready),languageLabelPresent:!!document.getElementById('jsLangLabel'),bodyClass:document.body.className,textContentLength:document.body.textContent.length,navigatorLanguage:navigator.language,navigatorLanguages:navigator.languages,fontsStatus:document.fonts.status,images:[...document.images].map(i=>({src:i.currentSrc||i.src,width:i.naturalWidth,height:i.naturalHeight,complete:i.complete})),sprites:document.querySelectorAll('.sprite').length,visibility:document.visibilityState,focused:document.hasFocus()})''', 'returnByValue': True})
                    verify_runtime_after_endpoint(client.commands, started + endpoint)
                    document = json.loads(audit['result']['value'])
                    target_audit = client.call('Target.getTargets')
                    validate_chrome_targets(target_audit)
                    pids = ','.join(str(p['pid']) for p in summary['endpoint_processes'])
                    process_commands = subprocess.check_output(['ps', '-p', pids,
                        '-o', 'pid=,ppid=,command='], text=True)
                    validate_chrome_document(document, screen['scale'], args.chrome_script_policy)
                    validate_chrome_requests(client.requests, args.chrome_script_policy)
                    png = client.call('Page.captureScreenshot', dict(format='png', captureBeyondViewport=False))
                    screenshot = prefix.with_suffix('.png')
                    screenshot.write_bytes(base64.b64decode(png['data']))
                    raster_dimensions = require_png_scale(screenshot, 1024, 768, screen['scale'])
                    foreground_window = foreground.verify_steady(endpoint)
                    if args.foreground and (not document['focused'] or document['visibility'] != 'visible'):
                        raise RuntimeError('Chrome document focus/visibility changed before capture')
                    if args.background and (document['focused'] or document['visibility'] != 'visible'):
                        raise RuntimeError('Chrome document did not remain visible and unfocused in background')
                    client.call('Browser.close')
                    process.wait(timeout=15)
                    if process.returncode:
                        raise RuntimeError(f'Chrome exited {process.returncode}')
                return dict(engine='chrome', chrome_script_policy=args.chrome_script_policy, command=command, version=version, memory=summary,
                    samples=counter.samples, screenshot=str(screenshot), screenshot_sha256=digest(screenshot),
                    document=document, requests=client.requests, foreground_checks=foreground.checks,
                    targets=target_audit, endpoint_process_commands=process_commands,
                    raster_dimensions=raster_dimensions,
                    load_average_at_launch=load_at_launch, load_average_at_endpoint=load_at_endpoint,
                    ready_timing=dict(ready_seconds=ready_at - started, endpoint_seconds=endpoint,
                        first_observed_endpoint_seconds=endpoint_observed,
                        observation_lag_seconds=endpoint_observed - endpoint),
                    navigation=navigation, lifecycle_readiness=readiness, commands=client.commands,
                    runtime_commands_before_endpoint=0,
                    foreground_verified_window_seconds=foreground_window, process_exit=process.returncode)
            except Exception as error:
                prefix.with_suffix('.partial.json').write_text(json.dumps(dict(error=str(error),
                    command=command, samples=counter.samples, foreground_checks=foreground.checks,
                    requests=client.requests if client else [], memory=locals().get('summary'),
                    document=locals().get('document'), targets=locals().get('target_audit'),
                    endpoint_process_commands=locals().get('process_commands'),
                    commands=client.commands if client else [], events=client.events if client else [],
                    navigation=locals().get('navigation'), lifecycle_readiness=locals().get('readiness')), indent=2) + '\n')
                raise
            finally:
                if client:
                    client.sock.close()
                stop_process(process)


def vox_sample(args, prefix, screen):
    log_path, window, screenshot = prefix.with_suffix('.log'), prefix.with_suffix('.window.png'), prefix.with_suffix('.png')
    with fresh_vox_cache(args.cache, args.output) as (cache, cache_digest):
        shutil.rmtree(cache / 'snapshots', ignore_errors=True)
        audit_path = prefix.with_suffix('.capture.json')
        config_path = prefix.with_suffix('.capture-config.json')
        config_path.write_text(json.dumps(dict(selectors=[
            dict(name='body', selector='body', limit=1, attributes=[]),
            dict(name='root', selector='html', limit=1, attributes=['class']),
            dict(name='sprites', selector='.sprite', limit=0, attributes=[]),
            dict(name='globe', selector='img.central-featured-logo', limit=1, attributes=['src', 'srcset'])
        ]), indent=2) + '\n')
        env = vox_environment(args, cache, screen, prefix)
        command = [str(args.vox), '--window-width', '1024', '--window-height', str(768 + VOX_CHROME_HEIGHT),
            '--screenshot', str(window), URL]
        with log_path.open('w') as log:
            started = time.monotonic()
            started_wall_ns = time.time_ns()
            load_at_launch = os.getloadavg()
            process = subprocess.Popen(command, cwd=REPO, stdout=log, stderr=subprocess.STDOUT,
                env=env, start_new_session=True)
            counter = PhysicalTree(process.pid, started)
            foreground = activity_control(args, process.pid, start_at=1)
            saved_at = None
            timing = document = None
            load_at_endpoint = None
            external_jobs = []
            vmmap_pending = sorted(set([args.diagnostic_vmmap_after, args.settle])) if args.diagnostic_vmmap else []
            try:
                with CounterSampler(counter, args.interval):
                    while process.poll() is None:
                        elapsed = time.monotonic() - started
                        if timing is None and audit_path.exists():
                            try:
                                document = json.loads(audit_path.read_text())
                            except json.JSONDecodeError:
                                pass
                            else:
                                timing = audit_timing(started, started_wall_ns,
                                    audit_path.stat().st_mtime_ns, time.monotonic(), args.settle)
                                validate_vox_document(document)
                        if timing is not None and load_at_endpoint is None and elapsed >= timing['endpoint_seconds']:
                            load_at_endpoint = dict(values=os.getloadavg(), observed_seconds=elapsed,
                                observation_lag_seconds=elapsed - timing['endpoint_seconds'])
                        foreground.poll(elapsed)
                        if vmmap_pending and elapsed >= vmmap_pending[0]:
                            checkpoint = vmmap_pending.pop(0)
                            external_jobs.append(launch_external_diagnostic(
                                ['vmmap', '-summary', str(process.pid)],
                                prefix.with_suffix(f'.vmmap-{checkpoint:g}s.txt'),
                                prefix.with_suffix(f'.vmmap-{checkpoint:g}s.result.json'),
                                dict(checkpoint_seconds=checkpoint, observed_launch_seconds=elapsed)))
                        if saved_at is None and 'Saved Ladybird V window screenshot:' in log_path.read_text():
                            saved_at = time.monotonic() - started
                        if elapsed > args.timeout:
                            raise RuntimeError('Vox screenshot timeout')
                        time.sleep(.02)
                    if saved_at is None and window.is_file():
                        saved_at = time.monotonic() - started
                if process.returncode or saved_at is None or timing is None:
                    raise RuntimeError(f'Vox capture failed (exit {process.returncode})')
                endpoint = timing['endpoint_seconds']
                if saved_at < timing['screenshot_earliest_seconds'] - .05:
                    raise RuntimeError('Vox screenshot marker precedes the declared capture guard')
                summary = summarize(counter.samples, endpoint)
                foreground_window = foreground.verify_steady(endpoint)
                external_diagnostics = finish_external_diagnostics(external_jobs)
                if any(row['actual_exit_code'] != 0 or row['timed_out'] for row in external_diagnostics):
                    raise RuntimeError('External diagnostic failed; actual exits and outputs retained')
                scripting = scripting_summary(log_path.read_text())
                if scripting is None or any(scripting[key] for key in ('enabled', 'runtime', 'sources', 'source_bytes', 'preloaded_scripts')):
                    raise RuntimeError('Vox scripting disabled audit failed')
                raster_dimensions = require_png_scale(window, 1024, 768 + VOX_CHROME_HEIGHT, screen['scale'])
                raw_viewport = prefix.with_suffix('.viewport-2x.png')
                crop_native_viewport(window, raw_viewport, screenshot, screen['scale'])
                return dict(engine='vox', command=command, memory=summary, samples=counter.samples,
                    screenshot=str(screenshot), screenshot_sha256=digest(screenshot), scripting=scripting,
                    raw_viewport=str(raw_viewport), raw_viewport_sha256=digest(raw_viewport),
                    cache_digest=cache_digest, process_exit=process.returncode,
                    document=document, ready_timing=timing, raster_dimensions=raster_dimensions,
                    screenshot_scale_environment=env['LADYBIRD_SCREENSHOT_SCALE'],
                    external_diagnostics=external_diagnostics,
                    load_average_at_launch=load_at_launch, load_average_at_endpoint=load_at_endpoint,
                    foreground_checks=foreground.checks, foreground_verified_window_seconds=foreground_window,
                    endpoint_note='Ready audit mtime plus fixed settle interval; PNG is scheduled two seconds later. Settled window is the preceding second; capture allocations excluded.')
            except Exception as error:
                prefix.with_suffix('.partial.json').write_text(json.dumps(dict(error=str(error),
                    command=command, samples=counter.samples, foreground_checks=foreground.checks,
                    memory=locals().get('summary'), document=document, ready_timing=timing),
                    indent=2) + '\n')
                raise
            finally:
                stop_process(process)
                finish_external_diagnostics(external_jobs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', choices=['chrome', 'vox', 'paired'], required=True)
    parser.add_argument('--vox', type=Path)
    parser.add_argument('--chrome', type=Path, required=True)
    parser.add_argument('--chrome-script-policy', choices=['disabled', 'enabled'], default='disabled',
        help='Chrome author scripting; Vox remains disabled. Enabled is a separate normal-Chrome comparison.')
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--network-deny', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repeat', type=int, default=1)
    parser.add_argument('--settle', type=float, default=15)
    parser.add_argument('--interval', type=float, default=.005)
    parser.add_argument('--timeout', type=float, default=120)
    activity = parser.add_mutually_exclusive_group()
    activity.add_argument('--foreground', action='store_true')
    activity.add_argument('--background', action='store_true')
    parser.add_argument('--diagnostic-gc-stats', action='store_true')
    parser.add_argument('--diagnostic-vmmap', action='store_true')
    parser.add_argument('--diagnostic-vmmap-after', type=float, default=3)
    args = parser.parse_args()
    if args.repeat < 1 or args.settle < 5 or args.interval <= 0:
        parser.error('Require positive repeat/interval and settle >= 5')
    if args.engine in ('vox', 'paired') and (args.vox is None or args.network_deny is None):
        parser.error('Vox requires --vox and --network-deny')
    if (args.diagnostic_gc_stats or args.diagnostic_vmmap) and args.engine != 'vox':
        parser.error('Diagnostic instrumentation is allowed only for single-engine Vox diagnostics')
    for name in ('vox', 'chrome', 'cache', 'network_deny', 'output'):
        value = getattr(args, name)
        if value:
            setattr(args, name, value.resolve())
    args.output.mkdir(parents=True, exist_ok=False)
    args.background_anchor_pid = int(subprocess.check_output(['osascript', '-l', 'JavaScript', '-e',
        "ObjC.import('AppKit'); String(Number($.NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier))"], text=True)) if args.background else None
    screen = placement()
    machine = dict(os=host_platform.platform(), macos=subprocess.check_output(['sw_vers', '-productVersion'], text=True).strip(),
        hardware_model=subprocess.check_output(['sysctl', '-n', 'hw.model'], text=True).strip(),
        logical_cpus=int(subprocess.check_output(['sysctl', '-n', 'hw.ncpu'], text=True)),
        physical_memory_bytes=int(subprocess.check_output(['sysctl', '-n', 'hw.memsize'], text=True)),
        cpu=subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string'], text=True).strip())
    files = [Path(__file__), *(REPO / 'tools' / name for name in (
        'compare_browser_memory.py', 'measure_browser_instructions.py', 'measure_browser_render.py',
        'probe_frozen_github_chrome.py', 'process_instruction_counts.py'))]
    chrome_bundle = args.chrome.parents[2]
    files.extend(p for p in chrome_bundle.rglob('*') if p.is_file())
    if args.vox:
        files.extend([args.vox, args.network_deny])
        files.extend(p for p in args.vox.parents[2].rglob('*') if p.is_file())
    pins = {str(p): digest(p) for p in files}
    cache_pins = fingerprint_tree(args.cache)
    protocol = dict(windowed=True, author_javascript=dict(vox=False, chrome=chrome_scripting_enabled(args.chrome_script_policy)),
        chrome_script_policy=args.chrome_script_policy, url=URL, viewport=[1024, 768],
        machine=machine,
        chrome_readiness='Matching Page frame/loader commit, paint, load and networkIdle; no Runtime enable/evaluate until after fixed primary endpoint. Frozen fixture has no font-face or external font resources; fonts status audited afterward.',
        device_scale=screen['scale'], window_placement=screen, foreground_controlled=args.foreground,
        background_controlled=args.background, background_anchor_pid=args.background_anchor_pid,
        diagnostic_instrumentation=bool(args.diagnostic_gc_stats or args.diagnostic_vmmap),
        metric='Sum of simultaneous task physical footprints; RSS recorded per task only, never summed.',
        primary_gate='Median settled Vox bytes <= 0.30 * median settled Chrome bytes AND maximum settled Vox bytes <= 0.30 * minimum settled Chrome bytes.',
        settle_seconds=args.settle, interval_seconds=args.interval, repeats=args.repeat,
        peak_scope='Launch to pre-capture settled endpoint; observed simultaneous polling peak separate from task kernel lifetime-peak envelope.',
        process_scope='Browser and every discovered descendant including renderers, GPU, utilities, and discovered reparented helpers. WindowServer and system services excluded for both. Unsampled short-lived helpers can be missed.',
        replay='Same frozen bodies and explicitly synthetic HTTP metadata: inferred MIME/status200/no-store/CORS wildcard. Not recorded origin headers. Missing requests blocked. Vox process-local network deny. No live fallback.',
        files_sha256=pins, cache_files_sha256=cache_pins)
    (args.output / 'protocol.json').write_text(json.dumps(protocol, indent=2) + '\n')
    rows = []
    for index in range(1, args.repeat + 1):
        order = (['vox', 'chrome'] if index % 2 else ['chrome', 'vox']) if args.engine == 'paired' else [args.engine]
        for engine in order:
            prefix = args.output / f'pair-{index}-{engine}'
            try:
                row = (chrome_sample if engine == 'chrome' else vox_sample)(args, prefix, screen)
                row.update(pair=index, sampled_interval_seconds=args.interval)
                prefix.with_suffix('.json').write_text(json.dumps(row, indent=2) + '\n')
                rows.append(row)
                print(json.dumps(dict(pair=index, engine=engine,
                    settled_bytes=row['memory']['settled_physical_footprint_bytes'],
                    observed_peak_bytes=row['memory']['observed_simultaneous_peak_bytes'],
                    endpoint_processes=len(row['memory']['endpoint_processes']))), flush=True)
            except Exception as error:
                prefix.with_suffix('.failure.json').write_text(json.dumps(dict(error=str(error)), indent=2) + '\n')
                raise
    if pins != {name: digest(Path(name)) for name in pins} or cache_pins != fingerprint_tree(args.cache):
        raise RuntimeError('Pinned executable, runtime, observer or cache changed')
    summary = dict(results=rows, protocol=protocol)
    if args.engine == 'paired':
        summary.update(settled_reduction([r for r in rows if r['engine'] == 'vox'], [r for r in rows if r['engine'] == 'chrome']))
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    return 0 if args.engine != 'paired' or summary['target_met'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
