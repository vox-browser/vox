#!/usr/bin/env python3
"""Measure sealed CNN homepage startup through encoded document PNG availability.

Run under run_memory_bounded.py with the same adoption registry. Seven alternating
pairs, full-uBO filtering, complete content and an unchanged cross-browser pixel
reference are required for acceptance. A diagnostic pair never grants acceptance.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import threading
import time

import hacker_news_browser_instructions as browser
from cnn_browser_instructions import native_fonts_ready
from forum_news_pixels import check_filters, executable_identity
from measure_sealed_github_instructions import FixtureHTML, text_content
from page_archive import Replay, load_archive

REPO = Path(__file__).resolve().parents[1]
URL = 'https://edition.cnn.com/'
HEADLINE = 'container__headline-text'
SELECTORS = [dict(name='body', selector='body', limit=1, attributes=[]),
             dict(name='headlines', selector='.' + HEADLINE, limit=1000, attributes=[]),
             dict(name='images', selector='img', limit=1000, attributes=['src']),
             dict(name='all', selector='*', limit=0, attributes=[])]
SCOPE = ('Exclusive resource-coalition creation through encoded document PNG availability. '
         'Includes startup, window/target setup, full-uBO startup, readiness and settlement. '
         'Vox ends before PNG file write; Brave includes CDP PNG delivery. Semantic audits, '
         'filter verification and teardown follow the endpoint. Fresh browser processes and '
         'private copies of declared closed profiles/encoded response caches. Original-origin '
         'sealed HTTPS replay without forwarding; frozen DOM has author scripts removed, '
         'normal scripting policy and uBO scriptlets retained. GPU instructions, observer, '
         'replay and services outside the exclusive coalition are excluded; exited helpers '
         'and explicitly allowed owned services are included. Brave uses its headless target '
         'at scale 1; Vox uses an inactive window and native scale-1 capture. '
         'OS filesystem/shader caches retained.')


def fixture_expectations(archive):
    manifest = load_archive(archive)
    browser.require(manifest['url'] == URL, 'Expected CNN homepage archive')
    entry = manifest['responses'][URL]
    browser.require(entry['status'] == 200, 'CNN main response must succeed')
    parser = FixtureHTML()
    parser.feed((archive / 'bodies' / entry['sha256']).read_text())
    browser.require(not any(n['tag'] == 'script' for n in parser.nodes),
                    'This workload requires the script-free frozen DOM')
    headlines = [text_content(n) for n in parser.nodes
                 if HEADLINE in (n['attrs'].get('class') or '').split()]
    images = sorted(n['attrs'].get('src', '') for n in parser.nodes if n['tag'] == 'img')
    title = next(text_content(n) for n in parser.nodes if n['tag'] == 'title')
    browser.require('CNN' in title and len(headlines) >= 50 and len(images) >= 50,
                    'CNN source inventory is incomplete')
    capture = archive / 'capture.json'
    browser.require(browser.sha(capture) == manifest['capture_report_sha256'],
                    'CNN capture provenance changed')
    provenance = json.loads(capture.read_text())
    check_filters(provenance)
    lists = json.loads((REPO / 'adblock/lists/manifest.json').read_text())
    browser.require(provenance['engine'] == lists['engine'] and provenance['lists'] ==
                    [{k: row[k] for k in ('name', 'sha256')} for row in lists['lists']],
                    'CNN filter provenance differs from current lists')
    return dict(url=URL, title=title, headlines=headlines, image_sources=images,
                html_sha256=entry['sha256'], html_bytes=entry['bytes'],
                manifest_sha256=browser.sha(archive / 'manifest.json'),
                responses=len(manifest['responses']), workload=manifest.get('workload'))


def validate_document(audit, expected):
    browser.require(audit.get('url') == URL and audit.get('title') == expected['title']
                    and audit.get('ready') == 'complete'
                    and [audit.get('viewport_width'), audit.get('viewport_height')] == [1024, 768],
                    'CNN document identity, readiness or viewport failed')
    selections = {row['name']: row for row in audit.get('selections', [])}
    browser.require(set(selections) >= {'body', 'headlines', 'images', 'all'}, 'Missing CNN audit')
    for name in ('body', 'headlines', 'images'):
        browser.require(selections[name]['count'] == len(selections[name]['elements']),
                        'Truncated CNN ' + name + ' inventory')
    browser.require([row['text'] for row in selections['headlines']['elements']] == expected['headlines'],
                    'CNN headline inventory changed or was reordered')
    browser.require(sorted(row['attributes'].get('src', '') for row in selections['images']['elements'])
                    == expected['image_sources'], 'CNN image source inventory changed')
    body = selections['body']['elements']
    browser.require(len(body) == 1 and len(body[0]['text']) > 1000 and selections['all']['count'] > 1000,
                    'CNN body or DOM is incomplete')
    visible = 0
    for row in selections['images']['elements']:
        r = row['rect']
        if r['width'] <= 0 or r['height'] <= 0 or r['x'] >= 1024 or r['y'] >= 768 or r['x'] + r['width'] <= 0 or r['y'] + r['height'] <= 0:
            continue
        image = row.get('image') or {}
        browser.require((image.get('complete') and image.get('natural_width', 0) > 0)
                        or (image.get('paint_decoded') and image.get('paint_width', 0) > 0),
                        'CNN visible image is not decoded')
        visible += 1
    browser.require(visible > 0 and audit.get('fonts_status') == 'loaded' and native_fonts_ready(audit),
                    'CNN visible images or real display fonts are missing')
    return dict(passed=True, headlines=len(expected['headlines']), images=len(expected['image_sources']),
                visible_images=visible, dom_elements=selections['all']['count'],
                body_text_sha256=hashlib.sha256(body[0]['text'].encode()).hexdigest())


def audit_expression():
    return '''({url:location.href,title:document.title,ready:document.readyState,
      viewport_width:innerWidth,viewport_height:innerHeight,fonts_status:document.fonts.status,
      font_faces:[...document.fonts].map(f=>({family:f.family,weight:['400','normal'].includes(f.weight)?'auto':f.weight,
        status:f.status,parsed_font_present:f.status==='loaded',source_path:'browser-font-face'})),
      selections:''' + json.dumps(SELECTORS) + '''.map(s=>{const nodes=[...document.querySelectorAll(s.selector)];
        return {name:s.name,count:nodes.length,elements:nodes.slice(0,s.limit).map(e=>{
          const r=e.getBoundingClientRect();return {text:e.textContent,
            attributes:Object.fromEntries(s.attributes.map(a=>[a,e.getAttribute(a)||''])),
            rect:{x:r.x,y:r.y,width:r.width,height:r.height},
            image:e.tagName==='IMG'?{complete:e.complete,natural_width:e.naturalWidth}:null}})}})})'''


def full_ubo_ready(connection, port, deadline):
    target = browser.wait_until(lambda: next((row for row in connection.call('Target.getTargets')['targetInfos']
        if row['type'] == 'background_page' and row['url'].endswith('/background.html')), None),
        deadline, 'Full-uBO background')
    background = browser.CDP(f"ws://127.0.0.1:{port}/devtools/page/{target['targetId']}")
    def evaluate(expression):
        result = background.call('Runtime.evaluate', dict(expression=expression, awaitPromise=True, returnByValue=True))
        browser.require(not result.get('exceptionDetails'), 'Full-uBO bootstrap exception')
        return result['result'].get('value')
    try:
        browser.wait_until(lambda: evaluate("typeof vAPI!=='undefined' && typeof vAPI.defer?.create==='function'"),
                           deadline, 'Full-uBO bootstrap')
        browser.wait_until(lambda: evaluate("(async()=> (await import('./js/background.js')).default.readyToFilter)()"),
                           deadline, 'Full-uBO filters')
        settings = evaluate("""(async()=>{const u=(await import('./js/background.js')).default;
          return {selected:u.selectedFilterLists,autoUpdate:u.userSettings.autoUpdate,
                  userFilters:(await u.loadUserFilters()).content};})()""")
        selected = [row['name'] for row in json.loads((REPO / 'adblock/lists/manifest.json').read_text())['lists']]
        browser.require(set(settings['selected']) == set(selected) and not settings['autoUpdate']
                        and not settings['userFilters'].strip(), 'Full-uBO prepared settings changed')
        return settings
    finally:
        background.sock.close()


def summarize(pairs, diagnostic=False):
    if diagnostic:
        return dict(acceptance=False, passed=False, valid=all(row.get('exit') == 0
                    for pair in pairs for row in pair.values()), pairs=len(pairs),
                    reason='Diagnostic observations; seven complete pairs required')
    browser.require(len(pairs) >= 7, 'Seven complete alternating pairs required')
    browser.require(all(pair.get('vox', {}).get('filter_gate', {}).get('passed') is True
                        and pair.get('brave', {}).get('brave_setup') for pair in pairs),
                    'Every pair needs verified full-uBO filtering')
    result = browser.evaluate_pairs([dict(vox=pair['vox'], brave=pair['brave']) for pair in pairs], .9, 'launch')
    if any('control' in pair for pair in pairs):
        browser.require(all('control' in pair and pair['control'].get('filter_gate', {}).get('passed')
                            for pair in pairs), 'Every control needs verified content and filters')
        result['matched_control'] = browser.evaluate_pairs(
            [dict(vox=pair['vox'], brave=pair['control']) for pair in pairs], 1, 'launch')
    result['acceptance'] = result['passed']
    return result


def parse_args(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, default=REPO / 'Tests/Browser/Brave/sites/cnn')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--memory-guard-registry', type=Path, required=True)
    p.add_argument('--vox-app', type=Path, default=REPO / 'Build/v/Vox.app')
    p.add_argument('--brave-app', type=Path, default=Path('/Applications/Brave Browser.app'))
    p.add_argument('--brave-profile-template', type=Path, required=True)
    p.add_argument('--vox-cache-template', type=Path, required=True)
    p.add_argument('--extension', type=Path, required=True)
    p.add_argument('--checker', type=Path, required=True)
    p.add_argument('--expected', type=Path, required=True)
    p.add_argument('--diff-tool', type=Path, required=True)
    p.add_argument('--diagnostic', action='store_true')
    p.add_argument('--diagnostic-engine', choices=['vox', 'brave', 'both'], default='both')
    control = p.add_mutually_exclusive_group()
    control.add_argument('--control-static-media', action='store_true',
                   help='Alternate the same Vox binary with static-media raster reuse disabled')
    control.add_argument('--control-lazy-image-batches', action='store_true',
                   help='Alternate the same Vox binary with per-completion lazy-image geometry checks')
    control.add_argument('--control-lazy-images', action='store_true',
                   help='Alternate the same Vox binary with negative lazy-image probes uncached')
    control.add_argument('--control-font-completion', action='store_true',
                   help='Alternate the same Vox binary with family-wide font completion invalidation')
    control.add_argument('--control-hidden-animations', action='store_true',
                   help='Alternate the same Vox binary with hidden CSS animation redraws enabled')
    control.add_argument('--control-geometry-snapshot-keys', action='store_true',
                   help='Alternate the same Vox binary with coarse geometry snapshot buckets')
    control.add_argument('--control-live-font-geometry', action='store_true',
                   help='Alternate the same Vox binary with geometry bound to exact font generations')
    control.add_argument('--control-live-font-cascades', action='store_true',
                   help='Alternate the same Vox binary without reusing retained font inputs across generations')
    control.add_argument('--control-vox-app', type=Path,
                   help='Alternate a separately pinned Vox control application without environment overrides')
    p.add_argument('--repeat', type=int, default=7)
    p.add_argument('--settle-seconds', type=float, default=5)
    p.add_argument('--timeout', type=float, default=180)
    args = p.parse_args(argv)
    if args.repeat < 1 or (not args.diagnostic and args.repeat < 7):
        p.error('Acceptance needs seven pairs; --diagnostic explicitly disables acceptance')
    if not 0 <= args.settle_seconds < args.timeout:
        p.error('Invalid settle period or timeout')
    if args.diagnostic_engine != 'both' and not args.diagnostic:
        p.error('Single-engine observations require --diagnostic')
    for key, value in vars(args).items():
        if isinstance(value, Path):
            setattr(args, key, value.resolve())
    return args


def trial_order(index, control=False):
    order = ['control', 'vox', 'brave'] if control else ['vox', 'brave']
    return order if index % 2 == 0 else order[::-1]


def control_environment(args):
    if args.control_vox_app:
        return {}
    for option, variable in (
        ('control_live_font_geometry', 'VOX_DISABLE_LIVE_FONT_GEOMETRY_REUSE'),
        ('control_lazy_image_batches', 'VOX_DISABLE_LAZY_IMAGE_BATCHES'),
        ('control_geometry_snapshot_keys', 'VOX_DISABLE_GEOMETRY_SNAPSHOT_KEYS'),
        ('control_live_font_cascades', 'VOX_DISABLE_LIVE_FONT_CASCADE_REUSE'),
        ('control_hidden_animations', 'VOX_DISABLE_HIDDEN_ANIMATION_THROTTLING'),
        ('control_font_completion', 'VOX_DISABLE_FACE_SPECIFIC_FONT_COMPLETION'),
        ('control_lazy_images', 'VOX_DISABLE_LAZY_IMAGE_PROBE_CACHE'),
        ('control_static_media', 'VOX_DISABLE_STATIC_MEDIA_RASTER_REUSE'),
    ):
        if getattr(args, option):
            return {variable: '1'}
    return {}


def audit_native_filters(args, folder):
    report = folder / 'filter.json'
    command = ['node', str(REPO / 'tools/adblock/brave_parity.mjs'), '--url', URL,
        '--brave', str(args.brave_app / 'Contents/MacOS/Brave Browser'),
        '--extension', str(args.extension), '--profile-template', str(args.brave_profile_template),
        '--checker', str(args.checker), '--vox-log', str(folder / 'requests.jsonl'),
        '--output', str(report)]
    with (folder / 'filter.log').open('w') as log:
        completed = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout,
                                   env=browser.clean_environment())
    browser.write_json(folder / 'filter-command.json', dict(command=command, exit=completed.returncode))
    browser.require(completed.returncode == 0, 'CNN full-uBO traffic audit failed')
    result = json.loads(report.read_text())
    check_filters(result, document=False)
    return dict(passed=True, sha256=browser.sha(report), counts=result['counts'])


def main():
    args = parse_args()
    expected = fixture_expectations(args.archive)
    args.output.mkdir(parents=True, exist_ok=False)
    args.scale, args.instruction_scope = 1, 'launch'
    args.brave_emulated_viewport = True
    args.brave_initial_page = True
    args.audit_config = args.output / 'audit-config.json'
    browser.write_json(args.audit_config, dict(selectors=SELECTORS))
    args.content_validator = lambda audit: validate_document(audit, expected)
    args.audit_expression = audit_expression()
    args.brave_setup = full_ubo_ready
    preferences = json.loads((args.brave_profile_template / 'Default/Preferences').read_text())
    browser.require(preferences['profile']['default_content_setting_values']['braveShields'] == 2,
                    'Prepared Brave profile must disable Shields to match full-uBO filtering')
    args.vox_arguments = ['--js-engine', 'javascriptcore', '--screenshot-viewport-height', '768']
    args.readiness_expression = f'''location.href==={json.dumps(URL)} && document.readyState==='complete'
      && document.fonts.status==='loaded' && innerWidth===1024 && innerHeight===768 && devicePixelRatio===1
      && [...document.images].every(i=>{{const r=i.getBoundingClientRect();return r.width<=0||r.height<=0
        ||r.x>=1024||r.y>=768||r.right<=0||r.bottom<=0||(i.complete&&i.naturalWidth>0)}})'''
    # Match the established full-uBO reference. Calling decode() explicitly
    # changes Chromium's image decode sizing and is a different raster workload.
    args.post_readiness_expression = 'new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(()=>r(true))))'
    apps = {}
    sources = [('vox', args.vox_app), ('brave', args.brave_app)]
    has_control = bool(args.control_vox_app or control_environment(args))
    if has_control:
        sources.append(('control', args.control_vox_app or args.vox_app))
    for engine, source in sources:
        target = args.output / engine / source.name
        target.parent.mkdir()
        shutil.copytree(source, target, symlinks=True, copy_function=browser.clone_file)
        apps[engine] = target
    paths = {p for app in apps.values() for p in app.rglob('*') if p.is_file()}
    paths.update(browser.native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    for folder in (args.archive, args.extension, args.brave_profile_template, args.vox_cache_template):
        paths.update(p for p in folder.rglob('*') if p.is_file() and not p.name.startswith('Singleton'))
    paths.update(p for p in browser.COALITION_SERVICES if p.is_file())
    paths.update((args.expected, args.checker, args.diff_tool, args.audit_config))
    paths.update(REPO / 'tools' / name for name in (
        'cnn_home_browser_instructions.py', 'cnn_browser_instructions.py',
        'hacker_news_browser_instructions.py', 'forum_news_pixels.py',
        'coalition_instruction_counts.py', 'measure_browser_instructions.py',
        'process_instruction_counts.py', 'measure_sealed_github_instructions.py',
        'check_pixel_equality.py', 'capture_brave_reference.py', 'page_archive.py',
        'pikabu_browser_instructions.py', 'reddit_browser_instructions.py',
        'probe_frozen_github_chrome.py', 'run_memory_bounded.py'))
    paths.update(p for p in (REPO / 'tools/adblock').glob('*.mjs'))
    paths.add(REPO / 'adblock/lists/manifest.json')
    pinned = browser.fingerprint(paths)
    browser.write_json(args.output / 'inputs.json', dict(files=pinned, fixture=expected, scope=SCOPE,
        source_vox_identity=executable_identity(args.vox_app / 'Contents/MacOS/Vox'),
        source_control_identity=(executable_identity(args.control_vox_app / 'Contents/MacOS/Vox')
                                 if args.control_vox_app else None),
        author_scripts=False, normal_scripting_policy=True, javascript_backends=dict(vox='javascriptcore', brave='v8'),
        viewport=[1024, 768], scale=1, settle_seconds=args.settle_seconds,
        brave_profile_template=str(args.brave_profile_template), vox_cache_template=str(args.vox_cache_template)))
    replay = Replay(args.archive, args.output / 'replay')
    thread = threading.Thread(target=replay.server.serve_forever, daemon=True)
    thread.start()
    pairs = []
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=public)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        args.url = URL
        args.brave_proxy_argument = '--proxy-server=' + replay.ready['proxy'].replace('socks5h:', 'socks5:')
        args.brave_arguments = ['--ignore-certificate-errors-spki-list=' + spki,
                               '--load-extension=' + str(args.extension), '--headless=new']
        for index in range(args.repeat):
            pair = {}
            order = trial_order(index, has_control)
            if args.diagnostic_engine != 'both':
                order = [args.diagnostic_engine]
            for engine in order:
                folder = args.output / f'pair-{index+1}-{engine}'
                args.vox_environment = dict(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
                    VOX_BLOCK_COOKIE_BANNERS='0', VOX_ADBLOCK_LOG=str(folder / 'requests.jsonl'))
                if engine == 'control':
                    args.vox_environment.update(control_environment(args))
                row = browser.run_browser('vox' if engine == 'control' else engine, apps[engine], folder, args)
                row['scope'] = SCOPE
                if engine in ('vox', 'control') and row['exit'] == 0:
                    try:
                        row['filter_gate'] = audit_native_filters(args, folder)
                    except Exception as error:
                        row.update(exit=1, error=str(error))
                browser.write_json(folder / 'result.json', row)
                pair[engine] = row
                print(json.dumps(browser.progress_record(index+1, engine, row, 'launch')), flush=True)
                browser.require(browser.fingerprint(paths) == pinned, 'Pinned benchmark input changed')
            pairs.append(pair)
            browser.write_json(args.output / 'pairs.json', pairs)
        try:
            summary = summarize(pairs, args.diagnostic)
        except RuntimeError as error:
            summary = dict(acceptance=False, passed=False, pairs=len(pairs), error=str(error))
        browser.write_json(args.output / 'summary.json', summary)
        print(json.dumps(summary), flush=True)
        return 0 if summary.get('valid') or summary['passed'] else 1
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        thread.join(timeout=5)


if __name__ == '__main__':
    raise SystemExit(main())
