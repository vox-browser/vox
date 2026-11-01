#!/usr/bin/env python3
"""Measure the archived BBC homepage from fresh launch through document PNG.

Run under the adoption-aware memory guard. Both engines use original HTTPS
origins, one non-forwarding replay, original author scripts, empty profiles and
caches, and the same native viewport/scale. Reference capture is a separate
diagnostic; acceptance requires seven alternating pairs and unchanged references.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import threading
from urllib.parse import urlsplit

import hacker_news_browser_instructions as browser
from measure_sealed_github_instructions import FixtureHTML, text_content
from page_archive import Replay, load_archive
from stackoverflow_browser_instructions import local_only_font_sources

REPO = Path(__file__).resolve().parents[1]
URL = 'https://www.bbc.com/'
SELECTORS = [dict(name='body', selector='body', limit=1, attributes=[]),
             dict(name='headlines', selector='[data-testid="card-headline"]', limit=1000,
                  attributes=['data-testid']),
             dict(name='images', selector='img', limit=1000, attributes=['src', 'srcset', 'alt']),
             dict(name='all', selector='*', limit=0, attributes=[])]
SCOPE = ('Exclusive resource-coalition creation through encoded document PNG availability; '
         'fresh process, empty private profile/cache, sealed HTTPS responses via one local '
         'SOCKS/TLS replay without forwarding, original author JavaScript enabled. '
         'Vox ends before PNG file write; Brave includes CDP PNG delivery and target/window setup. '
         'Readiness polling and two seconds of settlement are included; semantic audits and '
         'teardown follow the endpoint. Exited helpers and explicitly allowed coalition-owned '
         'services are included. GPU execution, observer/replay and outside services are excluded. '
         'The fixture records any shared JavaScript wall-clock override; monotonic timers remain real. '
         'OS filesystem/shader caches are retained. Per-engine references test stability; '
         'cross-browser pixel differences are reported separately.')


def fixture_expectations(archive):
    manifest = load_archive(archive)
    browser.require(manifest['url'] == URL, 'Expected the BBC homepage, not /news')
    entry = manifest['responses'][URL]
    browser.require(entry['status'] == 200, 'BBC document response must be successful')
    parser = FixtureHTML()
    parser.feed((archive / 'bodies' / entry['sha256']).read_text())
    title = next(text_content(node) for node in parser.nodes if node['tag'] == 'title')
    headlines = [text_content(node) for node in parser.nodes
                 if node['attrs'].get('data-testid') == 'card-headline']
    images = [node for node in parser.nodes if node['tag'] == 'img']
    styles = [text_content(node) for node in parser.nodes if node['tag'] == 'style']
    placeholders = sorted({node['attrs'].get('src', '') for node in images
                           if urlsplit(node['attrs'].get('src', '')).path.endswith('/grey-placeholder.png')})
    browser.require(title.startswith('BBC Home') and len(headlines) >= 20 and len(images) >= 10,
                    'BBC source lacks complete homepage content')
    return dict(url=URL, title=title, headlines=headlines, source_image_count=len(images),
                image_sources=sorted(node['attrs'].get('src', '') for node in images
                                     if node['attrs'].get('src', '') not in placeholders),
                placeholder_sources=placeholders,
                local_font_fallback_sources=local_only_font_sources(styles),
                document_sha256=entry['sha256'], document_bytes=entry['bytes'],
                responses=len(manifest['responses']),
                benchmark_clock=manifest.get('benchmark_clock'),
                workload=manifest.get('workload', 'Original archived responses and author scripts'),
                manifest_sha256=browser.sha(archive / 'manifest.json'))


def validate_document(audit, expected):
    browser.require(audit.get('url') == URL and audit.get('title') == expected['title']
                    and audit.get('ready') == 'complete'
                    and [audit.get('viewport_width'), audit.get('viewport_height')] == [1024, 768],
                    'BBC document identity/readiness/viewport failed')
    selections = {row['name']: row for row in audit.get('selections', [])}
    browser.require({'body', 'headlines', 'images', 'all'} <= selections.keys(),
                    'BBC semantic audit is missing a selection')
    headlines = selections['headlines']
    actual = [row['text'] for row in headlines['elements']]
    browser.require(headlines['count'] == len(actual) and actual == expected['headlines'],
                    'BBC source headline inventory changed, was truncated or reordered')
    bodies = selections['body']['elements']
    browser.require(selections['body']['count'] == 1 and len(bodies) == 1
                    and len(bodies[0]['text']) > 1000 and selections['all']['count'] > 500,
                    'BBC body or DOM is incomplete')
    images = selections['images']
    browser.require(images['count'] == len(images['elements']), 'BBC image audit was truncated')
    sources = sorted(row.get('attributes', {}).get('src', '') for row in images['elements']
                     if row.get('attributes', {}).get('src', '') not in expected['placeholder_sources'])
    # BBC removes grey loading placeholders after each real image decodes.
    # Every authored photograph must remain; only those explicit placeholders
    # may disappear during hydration, independently of any measured candidate.
    browser.require(sources == expected['image_sources'], 'BBC photograph source inventory changed')
    visible = []
    for row in images['elements']:
        rect = row['rect']
        if (rect['width'] <= 0 or rect['height'] <= 0 or rect['x'] >= 1024
                or rect['y'] >= 768 or rect['x'] + rect['width'] <= 0
                or rect['y'] + rect['height'] <= 0):
            continue
        image = row.get('image') or {}
        browser.require((image.get('complete') and image.get('natural_width', 0) > 0)
                        or (image.get('paint_decoded') and image.get('paint_width', 0) > 0),
                        'BBC visible image is not decoded: ' + str(row.get('attributes')))
        visible.append(row)
    browser.require(visible, 'BBC has no visible decoded images')
    browser.require(audit.get('fonts_status') == 'loaded', 'BBC fonts are unsettled')
    local_fallbacks = []
    for face in audit.get('font_faces', []):
        allowed = expected.get('local_font_fallback_sources', {}).get(face.get('family', '').casefold(), [])
        sources = face.get('declared_sources', [])
        local_missing = face['status'] == 'error' and bool(sources) and all(s in allowed for s in sources)
        browser.require(face['status'] not in ('loading', 'error') or local_missing,
                        'BBC requested font failed')
        if local_missing:
            local_fallbacks.append(dict(family=face['family'], sources=sources))
        browser.require(face['status'] != 'loaded' or face.get('parsed_font_present'),
                        'BBC loaded font has no parsed data')
    return dict(passed=True, headlines=len(actual), images=images['count'],
                visible_decoded_images=len(visible), dom_elements=selections['all']['count'],
                unavailable_local_fallbacks=local_fallbacks,
                body_text_sha256=hashlib.sha256(bodies[0]['text'].encode()).hexdigest())


def audit_expression():
    return '''({url:location.href,title:document.title,ready:document.readyState,
      viewport_width:innerWidth,viewport_height:innerHeight,fonts_status:document.fonts.status,
      font_faces:[...document.fonts].map(f=>({family:f.family,status:f.status,
        parsed_font_present:f.status==='loaded'})),selections:''' + json.dumps(SELECTORS) + '''.map(s=>{
        const nodes=[...document.querySelectorAll(s.selector)];
        return {name:s.name,count:nodes.length,elements:nodes.slice(0,s.limit).map(e=>{
          const r=e.getBoundingClientRect();return {text:e.textContent,
            attributes:Object.fromEntries(s.attributes.map(a=>[a,e.getAttribute(a)])),
            rect:{x:r.x,y:r.y,width:r.width,height:r.height},
            image:e.tagName==='IMG'?{complete:e.complete,natural_width:e.naturalWidth,
              natural_height:e.naturalHeight,current_src:e.currentSrc}:null}})}})})'''



def trial_order(index, control=False):
    order = ['control', 'vox', 'brave'] if control else ['vox', 'brave']
    return order if index % 2 == 0 else order[::-1]


def run_trial(engine, app, folder, args):
    environment = args.vox_environment
    try:
        if engine == 'control':
            args.vox_environment = dict(environment)
            if args.control_disable_grid_width_only:
                args.vox_environment['VOX_DISABLE_GRID_WIDTH_ONLY'] = '1'
            if getattr(args, 'control_disable_stationary_raster', False):
                args.vox_environment['VOX_DISABLE_STATIONARY_RASTER_REUSE'] = '1'
            if getattr(args, 'control_disable_client_geometry_index', False):
                args.vox_environment['VOX_DISABLE_VISUAL_CONTEXT_INDEX'] = '1'
            if getattr(args, 'control_disable_tracked_persistent_shortcut', False):
                args.vox_environment['VOX_DISABLE_TRACKED_PERSISTENT_SHORTCUT'] = '1'
        return browser.run_browser('vox' if engine == 'control' else engine, app, folder, args)
    finally:
        args.vox_environment = environment


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--vox-app', type=Path, default=REPO / 'Build/v/Vox.app')
    parser.add_argument('--control-vox-app', type=Path, help='Also run a pinned Vox control before each candidate/Brave pair')
    parser.add_argument('--control-disable-grid-width-only', action='store_true',
                        help='Disable only grid width-probe reuse in the pinned Vox control')
    parser.add_argument('--control-disable-stationary-raster', action='store_true',
                        help='Disable stationary document pixel reuse in the pinned Vox control')
    parser.add_argument('--control-disable-client-geometry-index', action='store_true',
                        help='Use recursive visual-context lookup in the pinned Vox control')
    parser.add_argument('--control-disable-tracked-persistent-shortcut', action='store_true',
                        help='Walk detached allocation blocks in the pinned Vox control')
    parser.add_argument('--brave-app', type=Path, default=Path('/Applications/Brave Browser.app'))
    parser.add_argument('--diff-tool', type=Path, default=REPO / 'Build/hn-home-instructions-20261031/pixel_diff')
    parser.add_argument('--expected-vox', type=Path)
    parser.add_argument('--expected-brave', type=Path)
    parser.add_argument('--capture-reference', action='store_true')
    parser.add_argument('--reference-engine', choices=['vox', 'brave', 'both'], default='both')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--scale', type=int, choices=[1, 2], default=2)
    parser.add_argument('--timeout', type=float, default=180)
    parser.add_argument('--settle-seconds', type=float, default=2)
    args = parser.parse_args(argv)
    if any((args.control_disable_grid_width_only, args.control_disable_stationary_raster,
            args.control_disable_client_geometry_index,
            args.control_disable_tracked_persistent_shortcut)) and not args.control_vox_app:
        parser.error('Disabling the control optimization needs --control-vox-app')
    if not args.capture_reference and (args.repeat < 7 or not args.expected_vox or not args.expected_brave):
        parser.error('Acceptance needs seven pairs and both existing pixel references')
    if not args.capture_reference and args.reference_engine != 'both':
        parser.error('Single-engine runs are only for reference diagnostics')
    if args.timeout <= 0 or not 0 <= args.settle_seconds < args.timeout:
        parser.error('Invalid timeout or settle duration')
    for key, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, key, value.resolve())
    return args


def main():
    args = parse_args()
    expected = fixture_expectations(args.archive)
    args.output.mkdir(parents=True, exist_ok=False)
    args.audit_config = args.output / 'audit-config.json'
    browser.write_json(args.audit_config, dict(selectors=SELECTORS))
    args.expected = None
    args.instruction_scope = 'launch'
    args.vox_arguments = ['--js-engine', 'javascriptcore']
    args.content_validator = lambda audit: validate_document(audit, expected)
    args.audit_expression = audit_expression()
    # Only viewport images are required: offscreen lazy images need not decode.
    args.readiness_expression = f'''location.href==={json.dumps(URL)} && document.readyState==='complete'
      && document.fonts.status==='loaded' && innerWidth===1024 && innerHeight===768
      && devicePixelRatio==={args.scale} && [...document.images].filter(i=>{{const r=i.getBoundingClientRect();
        return r.width>0&&r.height>0&&r.x<1024&&r.y<768&&r.right>0&&r.bottom>0}})
        .every(i=>i.complete&&i.naturalWidth>0)'''
    # `complete` establishes resource availability; decode() also waits for the
    # image decoder before the unchanged two-second raster settlement period.
    args.post_readiness_expression = '''Promise.all([...document.images].filter(i=>{
      const r=i.getBoundingClientRect();return r.width>0&&r.height>0&&r.x<1024&&r.y<768
        &&r.right>0&&r.bottom>0}).map(i=>i.decode())).then(()=>true)'''
    apps = {}
    sources = [('vox', args.vox_app), ('brave', args.brave_app)]
    if args.control_vox_app:
        sources.append(('control', args.control_vox_app))
    for engine, source in sources:
        target = args.output / engine / source.name
        target.parent.mkdir()
        shutil.copytree(source, target, symlinks=True, copy_function=browser.clone_file)
        apps[engine] = target
    paths = {path for app in apps.values() for path in app.rglob('*') if path.is_file()}
    paths.update(browser.native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    paths.update(path for path in args.archive.rglob('*') if path.is_file())
    paths.update(path for path in browser.COALITION_SERVICES if path.is_file())
    paths.update(REPO / 'tools' / name for name in ('bbc_browser_instructions.py',
        'hacker_news_browser_instructions.py', 'page_archive.py', 'coalition_instruction_counts.py',
        'measure_sealed_github_instructions.py', 'measure_browser_instructions.py',
        'capture_brave_reference.py', 'process_instruction_counts.py', 'run_memory_bounded.py',
        'check_pixel_equality.py', 'pikabu_browser_instructions.py'))
    paths.add(REPO / 'tools/stackoverflow_browser_instructions.py')
    paths.update(path for path in (args.expected_vox, args.expected_brave) if path)
    paths.update((args.diff_tool, args.audit_config))
    pinned = browser.fingerprint(paths)
    browser.write_json(args.output / 'inputs.json', dict(files=pinned, scope=SCOPE,
        fixture=expected, original_scripts_retained=True, author_javascript_enabled=True,
        viewport=[1024, 768], scale=args.scale, settle_seconds=args.settle_seconds,
        javascript_backends=dict(vox='javascriptcore', brave='v8'),
        control_disable_grid_width_only=args.control_disable_grid_width_only,
        control_disable_stationary_raster=args.control_disable_stationary_raster,
        control_disable_client_geometry_index=args.control_disable_client_geometry_index,
        control_disable_tracked_persistent_shortcut=args.control_disable_tracked_persistent_shortcut,
        brave_post_readiness_expression=args.post_readiness_expression,
        readiness_correction='Await visible image decode before the original settlement; no engine credit',
        system=subprocess.check_output(['sw_vers'], text=True)))
    replay = Replay(args.archive, args.output / 'replay')
    thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
    thread.start()
    pairs = []
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=public)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        args.url = URL
        args.vox_environment = dict(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
                                    VOX_BLOCK_COOKIE_BANNERS='0')
        args.brave_proxy_argument = '--proxy-server=' + replay.ready['proxy'].replace('socks5h:', 'socks5:')
        args.brave_arguments = ['--ignore-certificate-errors-spki-list=' + spki]
        for index in range(1 if args.capture_reference else args.repeat):
            pair = {}
            order = trial_order(index, bool(args.control_vox_app))
            if args.capture_reference and args.reference_engine != 'both':
                order = [args.reference_engine]
            for engine in order:
                row = run_trial(engine, apps[engine], args.output / f'pair-{index+1}-{engine}', args)
                row['scope'] = SCOPE
                browser.write_json(args.output / f'pair-{index+1}-{engine}/result.json', row)
                pair[engine] = row
                browser.require(browser.fingerprint(paths) == pinned, 'Pinned benchmark input changed')
                print(json.dumps(browser.progress_record(index+1, engine, row, 'launch')), flush=True)
            pairs.append(pair)
            browser.write_json(args.output / 'pairs.json', pairs)
        if args.capture_reference:
            summary = dict(reference_capture=True, passed=all(row['exit'] == 0 for row in pairs[0].values()),
                           acceptance=False)
        else:
            try:
                summary = browser.evaluate_pairs(pairs, .9, 'launch')
            except RuntimeError as error:
                summary = dict(passed=False, error=str(error), pairs=len(pairs))
            if args.control_vox_app:
                try:
                    summary['matched_control'] = browser.evaluate_pairs(
                        [dict(vox=pair['vox'], brave=pair['control']) for pair in pairs], .9, 'launch')
                except RuntimeError as error:
                    summary['matched_control'] = dict(passed=False, error=str(error))
                    summary['passed'] = False
            summary['cross_browser_pixels'] = browser.compare(args.expected_brave, args.expected_vox,
                args.output / 'cross-browser.diff.png', args.diff_tool)
        browser.write_json(args.output / 'summary.json', summary)
        print(json.dumps(summary, indent=2), flush=True)
        return 0 if summary['passed'] else 1
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        thread.join(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
