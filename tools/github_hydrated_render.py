#!/usr/bin/env python3
"""Compare GitHub's complete React repository text, from fresh launch to PNG.

Both browsers execute scripts against the same original-origin disk replay.
The retained native audit supplies every directory row's identity and text,
the latest commit, and the complete README. SSR filenames alone cannot pass.
The original per-engine PNG references are mandatory and never regenerated.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
import threading
import time
from types import SimpleNamespace

import measure_browser_instructions as measurement
from browser_bundle_lease import canonical_bundle_lease
from hacker_news_browser_instructions import test_display
from page_archive import Replay, load_archive
from process_instruction_counts import MacCounters
from measure_precise_scroll import runtime_input_paths
from measure_sealed_github_instructions import native_dependencies

ROOT = Path(__file__).resolve().parents[1]
URL = 'https://github.com/vlang/v'
SELECTORS = [dict(name=name, selector=selector, limit=200, attributes=['id', 'href'])
             for name, selector in [('rows', 'tr.react-directory-row'),
                                    ('latest', '[data-testid=latest-commit]'),
                                    ('readme', 'article.markdown-body'),
                                    ('commits', 'a[href*="/commit/"]')]]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def content(audit):
    groups = {group['name']: group for group in audit['selections']}
    result = {}
    for name in ['rows', 'latest', 'readme', 'commits']:
        group = groups[name]
        elements = group['elements']
        if not elements or group['count'] != len(elements):
            raise ValueError('Missing or truncated GitHub content: ' + name)
        result[name] = [dict(id=e['attributes'].get('id', ''), text=e['text']) for e in elements]
        if name == 'commits':
            for result_element, element in zip(result[name], elements):
                result_element['href'] = element['attributes']['href']
    ids = [e['id'] for e in result['rows']]
    if len(set(ids)) != len(ids) or any(not row['text'].strip() for row in result['rows']):
        raise ValueError('Invalid directory row identities or text')
    if len(result['commits']) < len(ids):
        raise ValueError('Reference omits React commit text')
    if any(not name or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_' for c in name)
           for name in ids):
        raise ValueError('Directory row IDs cannot be used as capture selectors')
    return result


def ready_selector(expected):
    # :has() cannot be nested in Chromium. One independent condition per row
    # also prevents an omitted row from making an every-present-row check pass.
    return 'body' + ''.join(':has(#' + row['id'] + ' a[href*="/commit/"])'
                           for row in expected['rows']) + \
        ':has([data-testid=sponsor-button]:not([aria-disabled="true"]))'


def audit_expression():
    return '''({url:location.href,title:document.title,ready:document.readyState,
      viewport_width:innerWidth,viewport_height:innerHeight,
      selections:SELECTORS.map(s=>{const nodes=[...document.querySelectorAll(s.selector)];
        return {name:s.name,count:nodes.length,elements:nodes.slice(0,s.limit).map(e=>({
          text:e.textContent,attributes:{id:e.id,href:e.getAttribute('href')||''}}))}})})'''.replace('SELECTORS', json.dumps(SELECTORS))


class AuditCDP(measurement.CDP):
    def __init__(self, url):
        super().__init__(url)
        self.errors = []

    def receive(self):
        response = super().receive()
        if response.get('method') == 'Runtime.exceptionThrown':
            self.errors.append(response['params']['exceptionDetails'])
        return response

    def call(self, method, params=None):
        # The existing driver collects this audit after its PNG endpoint.
        if method == 'Runtime.evaluate' and 'bodyClass:document.body' in (params or {}).get('expression', ''):
            params = dict(params, expression='JSON.stringify(' + audit_expression() + ')')
        result = super().call(method, params)
        if method == 'Runtime.evaluate' and (params or {}).get('expression') == 'JSON.stringify(' + audit_expression() + ')':
            value = json.loads(result['result']['value'])
            value['javascript_diagnostics'] = list(self.errors)
            result['result']['value'] = json.dumps(value)
        return result


def validate(audit, expected):
    if (audit.get('url') != URL or audit.get('ready') != 'complete'
            or (audit.get('viewport_width'), audit.get('viewport_height')) != (1024, 768)):
        raise ValueError('Wrong document, readiness or viewport')
    if audit.get('javascript_diagnostics') or audit.get('native_reported_errors'):
        raise ValueError('GitHub script/native errors')
    if content(audit) != expected:
        raise ValueError('React rows, latest commit or README differ from the retained text')


def certificate_spki(ca):
    public = subprocess.run(['openssl', 'x509', '-in', ca, '-pubkey', '-noout'],
                            check=True, capture_output=True).stdout
    der = subprocess.run(['openssl', 'pkey', '-pubin', '-outform', 'DER'], input=public,
                         check=True, capture_output=True).stdout
    return base64.b64encode(hashlib.sha256(der).digest()).decode()


def run(args):
    args.archive, args.output = args.archive.resolve(), args.output.resolve()
    manifest = load_archive(args.archive)
    if manifest['url'] != URL or not manifest.get('author_scripts', '').lower().startswith('original'):
        raise ValueError('Expected an original scripted GitHub archive')
    expected = content(json.loads(args.reference_audit.read_text()))
    if args.repeat < 1:
        raise ValueError('At least one complete pair is required')
    selector = ready_selector(expected)
    args.output.mkdir(parents=True, exist_ok=False)
    config = args.output / 'audit-config.json'
    config.write_text(json.dumps(dict(selectors=SELECTORS, describe_native_errors=True)))
    reference_paths = [args.reference_audit, args.expected_vox, args.expected_brave]
    binary = ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox'
    brave = Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser')
    paths = [*native_dependencies(binary, binary.parent.glob('*.dylib')),
             *native_dependencies(brave), *runtime_input_paths(binary, {}),
             *reference_paths, args.archive / 'manifest.json', Path(__file__), Path(measurement.__file__)]
    pins = {str(p.resolve()): digest(p) for p in paths}
    records = []
    original_environment = dict(os.environ)
    replay = Replay(args.archive, args.output / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    try:
        with canonical_bundle_lease(binary.parents[2]):
            for pair in range(args.repeat):
                for engine in (['vox', 'brave'] if pair % 2 == 0 else ['brave', 'vox']):
                    if any(digest(Path(p)) != value for p, value in pins.items()):
                        raise ValueError('Pinned browser or input changed')
                    environment = {k: v for k, v in original_environment.items()
                                   if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_'))
                                   and 'proxy' not in k.lower()}
                    prefix = args.output / f'{pair}-{engine}'
                    with tempfile.TemporaryDirectory(dir=args.output) as profile:
                        environment.update(VOX_PROFILE_DIR=profile, VOX_TEST_WINDOW='1',
                            VOX_CAPTURE_DOCUMENT_ONLY='1', LADYBIRD_SCREENSHOT_SCALE='1',
                            VOX_CAPTURE_READY_SELECTOR=selector, VOX_CAPTURE_AUDIT_CONFIG=str(config),
                            VOX_CAPTURE_AUDIT_PATH=str(prefix) + '.audit.json',
                            VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
                        if args.metadata_control:
                            environment['VOX_DISABLE_METADATA_ATTRIBUTE_STYLE_REUSE'] = '1'
                        os.environ.clear()
                        os.environ.update(environment)
                        common = dict(url=URL, width=1024, height=768, timeout=args.timeout,
                                      settle_seconds=args.settle_seconds, sample_interval=.005)
                        host = dict(cpu_count=os.cpu_count(), load=os.getloadavg(), unix=time.time())
                        if engine == 'vox':
                            options = SimpleNamespace(**common, binary=binary, native_instruction_markers=False,
                                vox_chrome_height=112, native_document_only=True,
                                vox_arg=['--enable-javascript', '--js-engine=javascriptcore',
                                         '--screenshot-viewport-height', '768'])
                            row = measurement.run_vox(options, prefix, MacCounters(), Path(profile) / 'cache')
                            audit = json.loads(Path(str(prefix) + '.audit.json').read_text())
                        else:
                            x, y = test_display()['position']
                            expression = 'JSON.stringify({ready:document.readyState,textLength:document.body?.innerText.length||0,fileLinks:document.querySelectorAll("tr.react-directory-row a").length,captureReady:!!document.querySelector(' + json.dumps(selector) + ')})'
                            options = SimpleNamespace(**common, binary=brave, scratch_dir=args.output,
                                chrome_windowed=True, chrome_readiness_expression=expression,
                                chrome_extra_arg=[f'--window-position={x},{y}', '--window-size=1024,900',
                                    '--proxy-server=' + replay.ready['proxy'].replace('socks5h://', 'socks5://'),
                                    '--ignore-certificate-errors-spki-list=' + certificate_spki(replay.ready['ca'])])
                            row = measurement.run_chrome(options, prefix, MacCounters(), AuditCDP)
                            audit = row['document_audit']
                        row.update(pair=pair, engine=engine, host_before=host,
                                   host_after=dict(load=os.getloadavg(), unix=time.time()))
                        records.append(row)
                        (args.output / 'records.json').write_text(json.dumps(records, indent=2))
                        reference = args.expected_vox if engine == 'vox' else args.expected_brave
                        try:
                            validate(audit, expected)
                            row['content_validated'] = True
                            row['pixels'] = measurement.validate_screenshot(Path(row['screenshot']), reference, 1024, 768)
                        except (ValueError, RuntimeError) as error:
                            row['validation_error'] = str(error)
                        (args.output / 'records.json').write_text(json.dumps(records, indent=2))
                        print(json.dumps(dict(pair=pair, engine=engine, instructions=row['instructions'],
                            milliseconds=row['process_launch_to_capture_observed_ms'],
                            validation_error=row.get('validation_error'))), flush=True)
            if any(digest(Path(p)) != value for p, value in pins.items()):
                raise ValueError('Pinned browser or input changed')
            load_archive(args.archive)
        times = {engine: [r['process_launch_to_capture_observed_ms'] for r in records if r['engine'] == engine]
                 for engine in ['vox', 'brave']}
        valid = all(r.get('content_validated') and r.get('pixels', {}).get('exact') for r in records)
        summary = dict(records=records, pins=pins, author_scripts=manifest['author_scripts'],
            selected_js_engines=dict(vox='javascriptcore', brave='v8'),
            replay_clock=manifest.get('replay_clock'), median_ms={k: statistics.median(v) for k, v in times.items()},
            conservative_time_ratio=max(times['vox']) / min(times['brave']),
            all_content_and_pixels_valid=valid,
            passed=valid and args.repeat >= 7 and max(times['vox']) <= min(times['brave']),
            scope=__doc__, policy='Fresh private profiles and HTTP caches; OS caches retained; author scripts enabled; exact retained text and per-engine PNGs. Vox endpoint includes audit/teardown; Brave endpoint is CDP PNG delivery, before audit/teardown. Process-tree instruction counts are lower bounds and exclude GPU/external services.')
        (args.output / 'summary.json').write_text(json.dumps(summary, indent=2))
        return 0 if summary['passed'] else 1
    except Exception as error:
        (args.output / 'failure.json').write_text(json.dumps(dict(error=str(error), records=records,
                                                               pins=pins), indent=2))
        raise
    finally:
        os.environ.clear()
        os.environ.update(original_environment)
        replay.server.shutdown()
        replay.server.server_close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['archive', 'reference-audit', 'expected-vox', 'expected-brave', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--settle-seconds', type=float, default=1)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--metadata-control', action='store_true')
    raise SystemExit(run(parser.parse_args()))
