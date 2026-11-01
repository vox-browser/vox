"""Audit frozen Stack Overflow startup/capture instructions on macOS.

Use run_memory_bounded.py. References are mandatory and never regenerated.
Page JavaScript is disabled in both engines; separate positive-control JSC
probes precede the uninstrumented seven-pair process-tree cohort. Counts are
observed lower bounds, not complete task accounting or engine timings.
"""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import statistics
import subprocess
import sys
import threading
import time
import traceback
from types import SimpleNamespace
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import measure_browser_instructions as measurement
from measure_sealed_github_instructions import native_dependencies, fingerprint
from process_instruction_counts import MacCounters
from stackoverflow_browser_instructions import fixture_metadata, validate_document, classify_replay
from page_archive import Replay
from check_pixel_equality import compare
URL = 'https://stackoverflow.com/questions'
READINESS = '''JSON.stringify({title:document.title,url:location.href,
    ready:document.readyState,textLength:document.body?.textContent.length||0,
    captureReady:location.href==='https://stackoverflow.com/questions'
        && document.title==='Newest Questions - Stack Overflow'
        && innerWidth===1024 && innerHeight===768 && devicePixelRatio===1
        && document.fonts.status==='loaded'
        && [...document.images].every(i=>{const r=i.getBoundingClientRect();
            return r.width<=0||r.height<=0||r.x>=1024||r.y>=768||r.right<=0||r.bottom<=0
                || (i.complete&&i.naturalWidth>0&&i.naturalHeight>0)})})'''

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def write(path, value):
    temporary = path.with_name(path.name + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

@contextmanager
def environment(values):
    previous = dict(os.environ)
    try:
        os.environ.clear()
        os.environ.update(
            {key: previous[key] for key in ['PATH', 'HOME', 'USER', 'LOGNAME', 'TMPDIR', 'LANG', 'LC_ALL'] if key in previous},
        )
        os.environ.update(values)
        yield
    finally:
        os.environ.clear()
        os.environ.update(previous)

class AuditCDP(measurement.CDP):

    def call(self, method, params=None):
        if method == 'Runtime.evaluate' and params and ('resources:performance.getEntriesByType' in params.get('expression', '')):
            params = dict(params)
            params['expression'] = """JSON.stringify(Object.assign(JSON.parse((EXPR)), {
                questionIds:[...document.querySelectorAll('[id^="question-summary-"]')].map(e=>e.id),
                bodyText:document.body.textContent,fontsStatus:document.fonts.status,
                viewport:[innerWidth,innerHeight],scale:devicePixelRatio,
                allElements:document.querySelectorAll('*').length,
                imageRects:[...document.images].map(i=>({src:i.currentSrc||i.src,
                    complete:i.complete,naturalWidth:i.naturalWidth,naturalHeight:i.naturalHeight,
                    rect:(()=>{const r=i.getBoundingClientRect();return {
                        x:r.x,y:r.y,width:r.width,height:r.height}})()}))
            }))""".replace('EXPR', params['expression'])
        return super().call(method, params)

def chrome_content(report, fixture):
    audit = report['document_audit']
    require(
        audit['url'] == URL and audit['title'] == fixture['title'] and (audit['ready'] == 'complete'),
        "audit['url'] == URL and audit['title'] == fixture['title'] and (audit['ready'] == 'complete')",
    )
    require(
        audit['viewport'] == [1024, 768] and audit['scale'] == 1,
        "audit['viewport'] == [1024, 768] and audit['scale'] == 1",
    )
    require(
        audit['questionIds'] == fixture['question_ids'] and len(audit['bodyText']) > 1000,
        "audit['questionIds'] == fixture['question_ids'] and len(audit['bodyText']) > 1000",
    )
    require(
        audit['fontsStatus'] == 'loaded' and audit['allElements'] > 0,
        "audit['fontsStatus'] == 'loaded' and audit['allElements'] > 0",
    )
    required = []
    for image in audit['imageRects']:
        r = image['rect']
        if r['width'] > 0 and r['height'] > 0 and (r['x'] < 1024) and (r['y'] < 768) and (r['x'] + r['width'] > 0) and (r['y'] + r['height'] > 0):
            require(image['complete'] and image['naturalWidth'] > 0 and (image['naturalHeight'] > 0), image)
            if image['src'].startswith(('http:', 'https:')):
                required.append(image['src'])
    return dict(question_ids=audit['questionIds'], body_sha256=digest_bytes(audit['bodyText'].encode()), body_utf8_bytes=len(audit['bodyText'].encode()), required_images=sorted(set(required)), fonts_status=audit['fontsStatus'])

def digest_bytes(value):
    return hashlib.sha256(value).hexdigest()


def root_probe(log, pid, positive=False):
    rows = re.findall(r'JSC_PROBE pid=(\d+) contexts=(\d+) groups=(\d+) evaluations=(\d+)', log)
    roots = [dict(zip(('pid', 'contexts', 'groups', 'evaluations'), map(int, row)))
             for row in rows if int(row[0]) == pid]
    require(len(roots) == 1, 'Probe must report the actual browser root PID once')
    root = roots[0]
    if positive:
        require(root['contexts'] > 0 and root['evaluations'] > 0,
                'JSC positive control did not initialize and execute code')
    else:
        require(
            root['contexts'] == root['groups'] == root['evaluations'] == 0,
            'Disabled author scripting unexpectedly initialized JSC',
        )
    return root


def validate_counter_report(report, engine):
    require(report.get('exit') == 0 and not report.get('shutdown_forced', False),
            'Browser did not exit normally')
    require(not report['unreadable_pids'] and report['root_instructions'] > 0,
            'Missing or unreadable root hardware counters')
    require(report['aggregate_is_lower_bound'] is True,
            'Process sampler must disclose its lower-bound coverage')
    tasks = report['processes']
    require(len({(task['pid'], task['start_ticks']) for task in tasks}) == len(tasks),
            'Duplicate task identity')
    require(
        report['instructions'] == sum((task['instructions'] for task in tasks)),
        'Aggregate differs from retained per-task counts',
    )
    if engine == 'vox':
        require(report['root_final_exit_sample'] is True, 'Missing Vox zombie endpoint')
        require(report['native_instruction_markers'] is False, 'Instrumented native capture')


def summarize(observations, repeat):
    require(repeat >= 7 and len(observations) == 2 * repeat, 'Need seven complete pairs')
    for pair in range(1, repeat + 1):
        rows = observations[(pair - 1) * 2:pair * 2]
        require([row['pair'] for row in rows] == [pair, pair], 'Pair identity mismatch')
        order = ['vox', 'brave'] if pair % 2 else ['brave', 'vox']
        require([row['engine'] for row in rows] == order, 'Pair order is not alternating')
    require(
        all((row['valid'] and row['pixel_validation']['exact'] for row in observations)),
        'Invalid content, counters or pixels in cohort',
    )
    require(
        all((type(row['instructions']) is int and row['instructions'] > 0 for row in observations)),
        'Instruction counters must be positive integers',
    )
    require(len({row['content']['body_sha256'] for row in observations}) == 1,
            'Body text differs across observations')
    results = {}
    for engine in ('vox', 'brave'):
        counts = [row['instructions'] for row in observations if row['engine'] == engine]
        results[engine] = dict(counts=counts, median=statistics.median(counts),
                               minimum=min(counts), maximum=max(counts))
    vox, brave = results['vox'], results['brave']
    return dict(results=results, median_vox_over_brave=vox['median'] / brave['median'],
                conservative_observed_vox_over_brave=vox['maximum'] / brave['minimum'],
                observed_ten_percent_gate=dict(
                    expression='10 * max(Vox observed) <= 9 * min(Brave observed)',
                    left=10 * vox['maximum'], right=9 * brave['minimum'],
                    passed=10 * vox['maximum'] <= 9 * brave['minimum']))


def probe_runtime(args, ready, audit_config, fixture):
    """Run debug timing and interposition outside the measured cohort."""
    folder = args.output / 'runtime-diagnostic'
    folder.mkdir()
    env = dict(
        VOX_TEST_WINDOW='1',
        VOX_COOKIE_FILE='',
        DYLD_INSERT_LIBRARIES=str(args.jsc_probe),
        LADYBIRD_DEBUG_TIMING='1',
        LADYBIRD_SCREENSHOT_SCALE='1',
        LADYBIRD_ENABLE_SNAPSHOT_CACHE='0',
        VOX_SCREENSHOT_NATIVE_LAYOUT='0',
        LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds),
        VOX_PROXY=ready['proxy'],
        SSL_CERT_FILE=ready['ca'],
        NO_PROXY='',
        no_proxy='',
    )
    results = {}
    for mode in ('positive-control', 'page'):
        target = folder / mode
        target.mkdir()
        profile = target / 'profile'
        profile.mkdir()
        env.update(
            VOX_PROFILE_DIR=str(profile),
            LADYBIRD_CACHE_DIR=str(target / 'cache'),
            VOX_CAPTURE_AUDIT_CONFIG=str(audit_config),
            VOX_CAPTURE_AUDIT_PATH=str(target / 'audit.json'),
        )
        if mode == 'positive-control':
            command = [str(args.vox), '--headless-smoke', '--js-engine=javascriptcore']
        else:
            config = SimpleNamespace(
                width=1024,
                height=768,
                url=URL,
                vox_arg=[
                    '--disable-javascript',
                    '--js-engine=javascriptcore',
                    '--screenshot-viewport-height',
                    '768',
                ],
            )
            command = measurement.vox_launch_command(config, args.vox, target / 'capture.window.png')
        with environment(env), (target / 'browser.log').open('w') as log:
            process = subprocess.Popen(command, cwd=ROOT, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=180)
            finally:
                measurement.stop_process(process)
        require(code == 0, 'Runtime diagnostic browser failed')
        log = (target / 'browser.log').read_text()
        result = dict(
            command=command,
            root_pid=process.pid,
            exit=code,
            probe=root_probe(log, process.pid, mode == 'positive-control'),
        )
        if mode == 'page':
            markers = re.findall(
                'Ladybird V scripting: enabled=(\\w+) runtime=(\\w+) sources=(\\d+) source_bytes=(\\d+) preloaded_scripts=(\\d+)',
                log,
            )
            require(
                markers and all((row == ('false', 'false', '0', '0', '0') for row in markers)),
                'Page scripting diagnostics do not confirm disabled, uninitialized runtime',
            )
            result['scripting_markers'] = markers
            result['content'] = validate_document(json.loads((target / 'audit.json').read_text()), fixture)
            measurement.crop_document_viewport(target / 'capture.window.png', target / 'capture.png', 1024, 768)
            result['pixels'] = measurement.validate_screenshot(target / 'capture.png', args.expected_vox, 1024, 768)
        results[mode] = result
        write(folder / 'results.json', results)
    return results

def run(args):
    output = args.output
    archive = args.archive
    diff_tool = args.diff_tool
    binaries = dict(vox=args.vox, brave=args.brave)
    output.mkdir(parents=True, exist_ok=False, mode=0o700)
    fixture = fixture_metadata(archive)
    config = output / 'audit-config.json'
    write(
        config,
        dict(
            selectors=[
                dict(name='body', selector='body', limit=1),
                dict(
                    name='questions',
                    selector='[id^="question-summary-"]',
                    limit=1000,
                    attributes=['id'],
                ),
                dict(name='images', selector='img', limit=1000, attributes=['src', 'srcset']),
                dict(name='all', selector='*', limit=0),
            ],
        ),
    )
    sources = [Path(__file__), diff_tool, config, args.expected_vox, args.expected_brave, *[ROOT / 'tools' / name for name in ['measure_browser_instructions.py', 'process_instruction_counts.py', 'stackoverflow_browser_instructions.py', 'page_archive.py', 'check_pixel_equality.py', 'measure_sealed_github_instructions.py']], args.jsc_probe]
    pins = {label: fingerprint(native_dependencies(binary) | set(binary.parent.glob('*.dylib'))) for (label, binary) in binaries.items()}
    extra = [binaries['vox'].with_name('VoxAdblockWorker'), binaries['vox'].parent.parent / 'Resources/adblock.snapshot.bin']
    versions = binaries['brave'].parent.parent / 'Frameworks/Brave Browser Framework.framework/Versions'
    extra.extend((path.resolve() for path in versions.glob('*/Brave Browser Framework')))
    extra.extend((path.resolve() for path in versions.glob('*/Helpers/*.app/Contents/MacOS/*') if path.is_file()))
    extras = fingerprint(extra)
    observers = {str(path): digest(path) for path in sources}
    summary = dict(
        status='running',
        fixture=fixture,
        binary_pins=pins,
        extra_runtime_pins=extras,
        observer_sha256=observers,
        host=dict(
            platform=platform.platform(),
            architecture=platform.machine(),
            cpu_count=os.cpu_count(),
            load_average=os.getloadavg(),
            started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        ),
        scope='Hardware-retired CPU instructions via macOS libproc, observed process-tree lower bounds. Startup included for both. Vox ends after native PNG capture, audit and normal process exit; Brave ends at last complete polling pass before first PNG CDP response, excluding subsequent audit and shutdown. GPU and outside services excluded. Observer/replay excluded.',
        policy=dict(
            viewport=[1024, 768],
            capture_scale=1,
            sample_interval_seconds=0.005,
            cache='Fresh private browser profiles and caches per trial; OS filesystem/shader caches retained',
            network='Same sealed original-origin replay; missing requests never forward',
            author_javascript='Disabled in both engines; fixture also has no script elements',
            vox_selected_javascript_backend='javascriptcore',
            brave_javascript_backend='V8 for CDP observer expressions; no author scripts',
            native_instruction_markers=False,
            filtering=dict(
                vox='Default enabled adblock, pinned snapshot and helper, empty private profile',
                brave='Fresh-profile Brave filtering defaults; no overrides; headless Shields activity unverified; auxiliary requests fail closed at replay',
            ),
            settle_seconds=args.settle_seconds,
            settle='Same fixed settlement after document/font/image readiness, plus native/CDP scheduling; content audits required.',
            launch='Direct Popen; both browser roots remain guard descendants; no LaunchServices',
        ),
        observations=[],
        references=dict(vox=str(args.expected_vox), brave=str(args.expected_brave)),
        optimization_credit=False,
        prior_evidence=args.prior_evidence,
    )
    write(output / 'summary.json', summary)
    replay = None
    try:
        with (output / 'startup.log').open('w') as log:
            startup = subprocess.run(
                [str(binaries['vox']), '--headless-smoke', '--js-engine=javascriptcore'],
                stdout=log,
                stderr=subprocess.STDOUT,
                timeout=90,
            )
        summary['startup_exit'] = startup.returncode
        require(startup.returncode == 0, 'startup.returncode == 0')
        replay = Replay(archive, output / 'replay')
        thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
        thread.start()
        ready = replay.ready
        require(
            ready['manifest_sha256'] == fixture['manifest_sha256'] and ready['forwarding'] is False,
            "ready['manifest_sha256'] == fixture['manifest_sha256'] and ready['forwarding'] is False",
        )
        pem = subprocess.check_output(['openssl', 'x509', '-in', ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=pem)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        summary['replay'] = dict(ready, spki=spki)
        summary['runtime_diagnostic'] = probe_runtime(args, ready, config, fixture)
        write(output / 'summary.json', summary)
        api = MacCounters()
        for trial in range(1, args.repeat + 1):
            order = ['vox', 'brave'] if trial % 2 == 1 else ['brave', 'vox']
            for label in order:
                folder = output / f'pair-{trial}' / label
                folder.mkdir(parents=True)
                for (path, pin) in {**pins[label], **extras}.items():
                    require(digest(path) == pin['sha256'], 'Runtime changed: ' + path)
                require(fixture_metadata(archive) == fixture, 'fixture_metadata(archive) == fixture')
                request_path = output / 'replay/requests.jsonl'
                before = len(request_path.read_text().splitlines()) if request_path.exists() else 0
                profile = folder / 'profile'
                profile.mkdir()
                cache = folder / 'cache'
                cache.mkdir()
                env = dict(
                    VOX_TEST_WINDOW='1',
                    VOX_PROFILE_DIR=str(profile),
                    VOX_COOKIE_FILE='',
                    LADYBIRD_CACHE_DIR=str(cache),
                    LADYBIRD_ENABLE_SNAPSHOT_CACHE='0',
                    VOX_PROXY=ready['proxy'],
                    SSL_CERT_FILE=ready['ca'],
                    NO_PROXY='',
                    no_proxy='',
                    LADYBIRD_SCREENSHOT_SCALE='1',
                    VOX_SCREENSHOT_NATIVE_LAYOUT='0',
                    VOX_CAPTURE_AUDIT_CONFIG=str(config),
                    VOX_CAPTURE_AUDIT_PATH=str(folder / 'audit.json'),
                )
                config_args = SimpleNamespace(
                    binary=binaries[label],
                    url=URL,
                    width=1024,
                    height=768,
                    timeout=180,
                    sample_interval=0.005,
                    scratch_dir=folder,
                    counter_backend='macos',
                    native_instruction_markers=False,
                    settle_seconds=args.settle_seconds,
                    vox_arg=[
                        '--disable-javascript',
                        '--js-engine=javascriptcore',
                        '--screenshot-viewport-height',
                        '768',
                    ],
                    chrome_launch_mode='blank',
                    chrome_disable_javascript=True,
                    chrome_readiness_expression=READINESS,
                    chrome_extra_arg=[
                        '--proxy-server=' + ready['proxy'].replace('socks5h://', 'socks5://'),
                        '--proxy-bypass-list=<-loopback>',
                        '--ignore-certificate-errors-spki-list=' + spki,
                        '--force-color-profile=srgb',
                        '--lang=en-US',
                        '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost, EXCLUDE 127.0.0.1',
                    ],
                )
                row = dict(
                    pair=trial,
                    engine=label,
                    valid=False,
                    started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                    host_load=os.getloadavg(),
                    environment=env,
                )
                summary['observations'].append(row)
                write(output / 'summary.json', summary)
                with environment(env):
                    report = measurement.run_chrome(config_args, folder / 'capture', api, client_factory=AuditCDP) if label == 'brave' else measurement.run_vox(config_args, folder / 'capture', api, cache)
                write(folder / 'capture.json', report)
                validate_counter_report(report, label)
                if label == 'vox':
                    require(
                        'Vox instructions ' not in (folder / 'capture.log').read_text(),
                        'Native instrumentation leaked into cohort',
                    )
                require(
                    report['exit'] == 0 and (not report.get('shutdown_forced', False)),
                    "report['exit'] == 0 and (not report.get('shutdown_forced', False))",
                )
                require(
                    not report['unreadable_pids'] and report['instructions'] > 0,
                    "not report['unreadable_pids'] and report['instructions'] > 0",
                )
                content = chrome_content(report, fixture) if label == 'brave' else validate_document(json.loads((folder / 'audit.json').read_text()), fixture)
                requests = [json.loads(line) for line in request_path.read_text().splitlines()[before:]]
                write(folder / 'requests.json', requests)
                validation = classify_replay(requests, fixture, content)
                require(not validation['transport_errors'], "not validation['transport_errors']")
                write(folder / 'replay-validation.json', validation)
                png = Path(report['screenshot'])
                pixels = measurement.validate_screenshot(png, summary['references'].get(label), 1024, 768)
                require(pixels['exact'], 'Fixed reference mismatch')
                row.update(
                    valid=True,
                    instructions=report['instructions'],
                    content=content,
                    pixel_validation=pixels,
                    report=str(folder / 'capture.json'),
                    png=str(png),
                    root_final_exit_sample=report['root_final_exit_sample'],
                    aggregate_is_lower_bound=report['aggregate_is_lower_bound'],
                    missing_final_sample_count=report['missing_final_sample_count'],
                    final_sample_precedes_capture_ms=report.get('final_sample_precedes_capture_ms'),
                )
                for (path, pin) in {**pins[label], **extras}.items():
                    require(digest(path) == pin['sha256'], "digest(path) == pin['sha256']")
                write(output / 'summary.json', summary)
                print(
                    json.dumps(
                        dict(pair=trial, engine=label, instructions=report['instructions'], valid=True),
                    ),
                    flush=True,
                )
        require(
            len(summary['observations']) == 2 * args.repeat and all((row['valid'] for row in summary['observations'])),
            "len(summary['observations']) == 2 * args.repeat and all((row['valid'] for row in summary['observations']))",
        )
        require(
            len({row['content']['body_sha256'] for row in summary['observations']}) == 1,
            "len({row['content']['body_sha256'] for row in summary['observations']}) == 1",
        )
        require(
            all((digest(path) == value for (path, value) in observers.items())),
            'all((digest(path) == value for (path, value) in observers.items()))',
        )
        require(fixture_metadata(archive) == fixture, 'fixture_metadata(archive) == fixture')
        summary['cross_browser_pixels'] = compare(
                                              args.expected_brave,
                                              args.expected_vox,
                                              output / 'cross-browser.diff.png',
                                              diff_tool,
                                          )
        summary.update(summarize(summary['observations'], args.repeat))
        summary['status'] = 'completed'
    except Exception as error:
        summary.update(status='failed', error=str(error), traceback=traceback.format_exc())
        raise
    finally:
        if replay:
            replay.server.shutdown()
            replay.server.server_close()
            thread.join(timeout=5)
        summary['finished_utc'] = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
        write(output / 'summary.json', summary)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--archive', type=Path, default=ROOT / 'Tests/Browser/Brave/sites/stackoverflow')
    parser.add_argument('--vox', type=Path, default=ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--expected-vox', type=Path, required=True)
    parser.add_argument('--expected-brave', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, required=True)
    parser.add_argument(
        '--jsc-probe',
        type=Path,
        required=True,
        help='Diagnostic-only JSC interposer, validated by a positive control',
    )
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--settle-seconds', type=float, default=2)
    parser.add_argument('--prior-evidence', help='Earlier cohort retained when correcting this protocol')
    args = parser.parse_args()
    if args.repeat < 7 or not 0 <= args.settle_seconds < 180:
        parser.error('Need at least seven pairs and a finite nonnegative settle below 180 seconds')
    for name in ['output', 'archive', 'vox', 'brave', 'expected_vox', 'expected_brave', 'diff_tool', 'jsc_probe']:
        setattr(args, name, getattr(args, name).resolve())
    run(args)
if __name__ == '__main__':
    main()
