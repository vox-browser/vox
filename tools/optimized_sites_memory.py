#!/usr/bin/env python3
"""Measure per-browser RAM for the six frozen optimized-site workloads.

RAM is the median observed simultaneous peak physical footprint of fresh
browser process trees. These are separate memory runs on the declared bundle;
they do not replace or extend historical instruction acceptance cohorts.
"""
import argparse
import base64
from contextlib import contextmanager
import functools
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import statistics
import subprocess
import threading
from types import SimpleNamespace

import hacker_news_browser_instructions as browser
import cnn_home_browser_instructions as full_ubo
import lobsters_browser_instructions as lobsters
from browser_memory_observer import BrowserMemoryObserver
from measure_sealed_github_instructions import FixtureHTML, text_content
from page_archive import Replay, load_archive

REPO = Path(__file__).resolve().parents[1]
SITES = ('lobsters', 'reddit', 'hacker-news', 'cnn', 'wikipedia', 'vlang')
SELECTORS = [dict(name='body', selector='body', limit=1, attributes=[]),
             dict(name='images', selector='img', limit=1000, attributes=['src', 'srcset'])]


def text_hash(value):
    return hashlib.sha256(' '.join(value.split()).encode()).hexdigest()


def generic_expectations(document):
    parser = FixtureHTML()
    parser.feed(document.read_text())
    body = next(n for n in parser.nodes if n['tag'] == 'body')
    return dict(title=next(text_content(n) for n in parser.nodes if n['tag'] == 'title'),
                body_text_sha256=text_hash(text_content(body)),
                images=sorted((n['attrs'].get('src', ''), n['attrs'].get('srcset', ''))
                              for n in parser.nodes if n['tag'] == 'img'))


def validate_generic(audit, expected, url):
    browser.require(audit.get('url') == url and audit.get('title') == expected['title']
                    and audit.get('ready') == 'complete'
                    and [audit.get('viewport_width'), audit.get('viewport_height')] == [1024, 768],
                    'Memory run loaded a different document or viewport')
    selections = {r['name']: r for r in audit.get('selections', [])}
    body, images = (selections[n] for n in ('body', 'images'))
    browser.require(body['count'] == len(body['elements']) == 1
                    and images['count'] == len(images['elements']), 'Memory audit truncated')
    actual_hash = text_hash(body['elements'][0]['text'])
    browser.require(actual_hash == expected['body_text_sha256'], 'Memory run body content changed')
    browser.require(sorted((r['attributes'].get('src', ''), r['attributes'].get('srcset', ''))
                           for r in images['elements']) == expected['images'], 'Memory run images changed')
    return dict(passed=True, body_text_sha256=actual_hash, images=len(images['elements']))


@contextmanager
def local_fixture(folder):
    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *args):
            pass
    server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(folder)))
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    try:
        yield f'http://127.0.0.1:{server.server_port}/index.html'
    finally:
        server.shutdown()
        server.server_close()
        worker.join(timeout=5)


def site_config(site):
    if site in ('lobsters', 'cnn'):
        archive = REPO / 'Tests/Browser/Brave/sites' / site
        source = (REPO / ('Build/lobsters-home-instructions-20261102-102016/acceptance-owned'
                         if site == 'lobsters' else 'Build/cnn-final-launch-20261101-2100/seven'))
        inputs = json.loads((source / 'inputs.json').read_text())
        profile = (REPO / 'Build/lobsters-home-instructions-20261102-102016/brave-template-final'
                   if site == 'lobsters' else Path(inputs['brave_profile_template']))
        return dict(archive=archive, full_ubo=True, scale=1, settle_seconds=5,
                    brave_profile_template=profile, vox_cache_template=Path(inputs['vox_cache_template']),
                    expected_vox=archive / 'live.png', expected_brave=archive / 'live.png')
    if site == 'hacker-news':
        reference = REPO / 'Tests/Browser/Brave/expected/hacker-news-home-instructions.png'
        return dict(archive=REPO / 'Tests/Browser/Brave/hn-home-instructions',
                    scale=2, settle_seconds=2, expected_vox=reference, expected_brave=reference)
    if site == 'reddit':
        reference = REPO / 'Build/old-reddit-instructions-20261101/diagnostic/brave.png'
        return dict(archive=REPO / 'Build/old-reddit-instructions-20261101/archive',
                    scale=1, settle_seconds=2, expected_vox=reference, expected_brave=reference,
                    vox_cache_template=REPO / 'Build/old-reddit-instructions-20261101/frozen-cache')
    if site == 'wikipedia':
        base = REPO / 'Build/wikipedia-instructions-20261101'
        return dict(archive=base / 'archive-v2', scale=1, settle_seconds=2,
                    expected_vox=base / 'diagnostic-v2-vox.png', expected_brave=base / 'diagnostic-v2-brave.png',
                    vox_scripting=False, brave_disable_javascript=True)
    base = REPO / 'Build/optimized-sites-audit-20261101/vlang'
    return dict(fixture=REPO / 'Build/vlang-instructions-20261030-1540/fixture',
                scale=1, settle_seconds=2,
                expected_vox=base / '1.candidate.png', expected_brave=base / '1.brave.png')


@contextmanager
def replay_site(config, output):
    if 'fixture' in config:
        with local_fixture(config['fixture']) as url:
            yield url, config['fixture'] / 'index.html', {}
        return
    archive = config['archive']
    manifest = load_archive(archive)
    document = archive / 'bodies' / manifest['responses'][manifest['url']]['sha256']
    if config.get('scale') == 2:
        with browser.fixture_server(document, output, archive) as url:
            yield url, document, {}
        return
    replay = Replay(archive, output / 'replay')
    worker = threading.Thread(target=replay.server.serve_forever, daemon=True)
    worker.start()
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=public)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        yield manifest['url'], document, dict(vox_environment=dict(VOX_PROXY=replay.ready['proxy'],
              SSL_CERT_FILE=replay.ready['ca']),
              brave_proxy_argument='--proxy-server=' + replay.ready['proxy'].replace('socks5h:', 'socks5:'),
              brave_arguments=['--ignore-certificate-errors-spki-list=' + spki])
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        worker.join(timeout=5)


def summarize_rows(rows, repeat):
    result = {}
    for site in sorted({r['site'] for r in rows}):
        result[site] = {}
        for engine in ('vox', 'brave'):
            cohort = [r for r in rows if r['site'] == site and r['engine'] == engine]
            browser.require(len(cohort) == repeat and all(r.get('content_exact') and
                r.get('kernel_exit_status') == 0 and r.get('memory', {}).get('observed_peak_bytes', 0) > 0
                and not r.get('memory_error') for r in cohort), 'Incomplete memory cohort: ' + site + '/' + engine)
            values = [r['memory']['observed_peak_bytes'] for r in cohort]
            result[site][engine] = dict(median_observed_peak_bytes=statistics.median(values),
                runs_bytes=values, trials=len(values), all_reference_pixels_exact=all(r.get('pixels_exact') for r in cohort))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--site', choices=SITES, action='append')
    parser.add_argument('--repeat', type=int, default=2)
    args = parser.parse_args()
    browser.require(args.repeat >= 2, 'Use at least two alternating memory pairs')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    environment = browser.clean_environment()
    os.environ.clear()
    os.environ.update(environment)
    apps = dict(vox=REPO / 'Build/v/Vox.app', brave=Path('/Applications/Brave Browser.app'))
    configs = {site: site_config(site) for site in (args.site or SITES)}
    paths = {p for app in apps.values() for p in app.rglob('*') if p.is_file()}
    paths.update(browser.native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    paths.update(REPO / 'tools' / name for name in (
        'optimized_sites_memory.py', 'browser_memory_observer.py', 'wikipedia_browser_memory.py',
        'compare_browser_memory.py', 'hacker_news_browser_instructions.py', 'cnn_home_browser_instructions.py',
        'lobsters_browser_instructions.py', 'cnn_browser_instructions.py', 'forum_news_pixels.py',
        'coalition_instruction_counts.py', 'measure_browser_instructions.py', 'process_instruction_counts.py',
        'measure_sealed_github_instructions.py', 'page_archive.py', 'run_memory_bounded.py',
        'capture_brave_reference.py', 'check_pixel_equality.py', 'pikabu_browser_instructions.py'))
    if any(config.get('full_ubo') for config in configs.values()):
        paths.update(p for p in (REPO / 'Build/forum-news-parity-20261030/extension/uBlock0.chromium').rglob('*') if p.is_file())
        paths.add(REPO / 'adblock/lists/manifest.json')
    for config in configs.values():
        for key, value in config.items():
            if isinstance(value, Path):
                browser.require(value.exists(), 'Missing workload input: ' + str(value))
                paths.update((p for p in value.rglob('*') if p.is_file()) if value.is_dir() else [value])
    pinned = browser.fingerprint(paths)
    browser.write_json(args.output / 'inputs.json', dict(files=pinned,
        production_receipt=json.loads((REPO / 'Build/production-build/latest.json').read_text()),
        configurations={k:{n:str(v) if isinstance(v, Path) else v for n,v in c.items()} for k,c in configs.items()},
        memory_statistic='Median of observed simultaneous process-tree peak physical footprints',
        note='Separate current-bundle memory observations; no instruction acceptance or optimization credit'))
    rows = []
    for site, config in configs.items():
        output = args.output / site
        output.mkdir()
        with replay_site(config, output) as (url, document, replay):
            settings = SimpleNamespace(timeout=180, instruction_scope='launch', audit_vox_capture_ownership=True,
                browser_memory_observer=BrowserMemoryObserver, memory_guard_registry=args.memory_guard_registry,
                audit_config=output / 'audit-config.json', vox_arguments=['--js-engine', 'javascriptcore',
                    '--screenshot-viewport-height', '768'], vox_environment={},
                expected=None, diff_tool=REPO / 'Build/hn-home-instructions-20261031/pixel_diff',
                url=url, **{k:v for k,v in config.items() if k not in ('archive', 'fixture', 'full_ubo')})
            for key, value in replay.items():
                setattr(settings, key, value)
            # Scale-1 catalog captures use CDP emulation on Retina displays,
            # matching the original process-counter capture tools.
            if settings.scale == 1:
                settings.brave_emulated_viewport = True
                if not config.get('full_ubo'):
                    settings.brave_initial_page = True
                    settings.brave_arguments = getattr(settings, 'brave_arguments', []) + ['--headless=new']
            if config.get('full_ubo'):
                workload = lobsters if site == 'lobsters' else full_ubo
                expected = workload.fixture_expectations(config['archive'])
                selectors = workload.SELECTORS
                settings.content_validator = lambda audit: workload.validate_document(audit, expected)
                settings.audit_expression = workload.audit_expression()
                settings.brave_setup = full_ubo.full_ubo_ready
                settings.brave_emulated_viewport = settings.brave_initial_page = True
                settings.brave_arguments += ['--load-extension=' + str(REPO / 'Build/forum-news-parity-20261030/extension/uBlock0.chromium'), '--headless=new']
                settings.vox_environment.update(VOX_BLOCK_COOKIE_BANNERS='0')
            else:
                expected = generic_expectations(document)
                selectors = SELECTORS
                settings.content_validator = lambda audit: validate_generic(audit, expected, url)
                settings.audit_expression = full_ubo.audit_expression(SELECTORS)
            browser.write_json(settings.audit_config, dict(selectors=selectors))
            # Only visible images must be decoded; offscreen lazy images remain in the full inventory audit.
            settings.readiness_expression = f'''location.href==={json.dumps(url)} && document.readyState==='complete'
              && document.fonts.status==='loaded' && innerWidth===1024 && innerHeight===768
              && devicePixelRatio==={settings.scale} && [...document.images].every(i=>{{const r=i.getBoundingClientRect();
              return r.width<=0||r.height<=0||r.x>=1024||r.y>=768||r.right<=0||r.bottom<=0||(i.complete&&i.naturalWidth>0)}})'''
            for index in range(args.repeat):
                for engine in (('vox', 'brave') if index % 2 == 0 else ('brave', 'vox')):
                    row = browser.run_browser(engine, apps[engine], output / f'pair-{index+1}-{engine}', settings)
                    row.update(site=site, pair=index+1)
                    rows.append(row)
                    browser.write_json(args.output / 'rows.json', rows)
                    print(json.dumps(dict(site=site, engine=engine, pair=index+1, exit=row['exit'],
                          content_exact=row.get('content_exact'), pixels_exact=row.get('pixels_exact'),
                          peak_bytes=row.get('memory', {}).get('observed_peak_bytes'), error=row.get('error'))), flush=True)
                    browser.require(browser.fingerprint(paths) == pinned, 'Pinned memory input changed')
    summary = summarize_rows(rows, args.repeat)
    browser.write_json(args.output / 'summary.json', summary)
    print(json.dumps(summary, indent=2), flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
