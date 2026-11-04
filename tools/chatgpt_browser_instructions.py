#!/usr/bin/env python3
"""Compare a single SOCKS-captured ChatGPT homepage using disk-only replay.

Author scripts remain enabled and the archived document is unchanged. References
are required; this tool never regenerates them. Diagnostic runs may use fewer
than seven pairs, but cannot pass the 5% acceptance gate.
"""
import argparse
import base64
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from types import SimpleNamespace

import hacker_news_browser_instructions as measurement
from capture_chatgpt_archive import URL
from measure_sealed_github_instructions import clean_environment, fingerprint, native_dependencies, require
from measure_sealed_github_instructions import FixtureHTML, text_content
from measure_precise_scroll import runtime_input_paths
from page_archive import Replay, load_archive

ROOT = Path(__file__).resolve().parents[1]
SELECTORS = [dict(name='headings', selector='h1', limit=20, attributes=[]),
             dict(name='editors', selector='textarea,[contenteditable=true]', limit=20,
                  attributes=['id', 'placeholder', 'contenteditable']),
             dict(name='buttons', selector='button', limit=200, attributes=['aria-label']),
             dict(name='links', selector='a[href]', limit=200, attributes=['href']),
             dict(name='images', selector='img', limit=100, attributes=['src'])]


def normalized(text):
    return ' '.join(text.split())


def source_expectations(archive, manifest):
    parser = FixtureHTML()
    entry = manifest['responses'][URL]
    parser.feed((archive / 'bodies' / entry['sha256']).read_text())
    return dict(document_sha256=entry['sha256'],
        headings=[normalized(text_content(n)) for n in parser.nodes if n['tag'] == 'h1'],
        links=[(n['attrs']['href'], normalized(text_content(n))) for n in parser.nodes
               if n['tag'] == 'a' and 'href' in n['attrs']],
        buttons=sum(n['tag'] == 'button' for n in parser.nodes),
        editors=sum(n['tag'] == 'textarea' or n['attrs'].get('contenteditable') == 'true'
                    for n in parser.nodes))


def content_gate(audit, title, expected=None):
    require(audit.get('url') == URL and audit.get('title') == title, 'Wrong ChatGPT document')
    require(audit.get('ready') == 'complete', 'Incomplete ChatGPT document')
    require((audit.get('viewport_width'), audit.get('viewport_height')) == (1024, 768),
            'Wrong document viewport')
    groups = {row['name']: row for row in audit.get('selections', [])}
    for name in ['headings', 'editors', 'buttons', 'links']:
        group = groups.get(name, {})
        require(group.get('count', 0) > 0 and group['count'] == len(group.get('elements', [])),
                'Missing or truncated content: ' + name)
    require(any(e.get('rect', {}).get('width', 0) > 0
                and e.get('rect', {}).get('height', 0) > 0
                for e in groups['editors']['elements']), 'ChatGPT editor is not laid out')
    if expected is not None:
        require([normalized(e['text']) for e in groups['headings']['elements']] == expected['headings'],
                'Homepage headings differ from the original source')
        require([(e['attributes'].get('href', ''), normalized(e['text']))
                 for e in groups['links']['elements']] == expected['links'],
                'Full homepage link identity differs from the original source')
        require(groups['buttons']['count'] == expected['buttons']
                and groups['editors']['count'] == expected['editors'], 'Incomplete homepage controls')
    errors = audit.get('native_reported_errors', []) + audit.get('javascript_diagnostics', [])
    require(not errors, 'ChatGPT script/native errors: ' + repr(errors)[:1500])
    return dict(title=title, counts={name: row['count'] for name, row in groups.items()})


def audit_expression():
    return """(() => ({url:location.href,title:document.title,ready:document.readyState,
      viewport_width:innerWidth,viewport_height:innerHeight,
      selections:SELECTORS.map(s=>{const nodes=[...document.querySelectorAll(s.selector)];
        return {name:s.name,count:nodes.length,elements:nodes.slice(0,s.limit).map(e=>{
          const r=e.getBoundingClientRect();return {text:e.textContent,
          rect:{x:r.x,y:r.y,width:r.width,height:r.height},
          attributes:Object.fromEntries(s.attributes.map(a=>[a,e.getAttribute(a)]))}})}})}))()""".replace(
              'SELECTORS', json.dumps(SELECTORS))


def summarize(pairs):
    summary = measurement.evaluate_pairs(pairs, .95, 'launch')
    summary['minimum_pairs'] = 7
    summary['diagnostic_only'] = len(pairs) < 7
    summary['passed'] = summary['passed'] and len(pairs) >= 7
    return summary


@contextmanager
def clean_observer_environment():
    previous = dict(os.environ)
    cleaned = clean_environment()
    os.environ.clear()
    os.environ.update(cleaned)
    try:
        yield
    finally:
        os.environ.clear()
        os.environ.update(previous)

def run(args):
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    archive = args.archive.resolve()
    manifest = load_archive(archive)
    require(manifest['url'] == URL, 'Archive is not the ChatGPT homepage')
    require(manifest['responses'][URL]['status'] == 200, 'Unsuccessful homepage response')
    expected_content = source_expectations(archive, manifest)
    measurement.write_json(out / 'source-expectations.json', expected_content)
    apps = measurement.reference_browser_apps(out, [
        ('vox', ROOT / 'Build/v/Vox.app'), ('brave', Path('/Applications/Brave Browser.app'))])
    reference = args.expected.resolve(strict=True)
    audit_config = out / 'audit-config.json'
    measurement.write_json(audit_config, dict(selectors=SELECTORS, describe_native_errors=True))
    settings = SimpleNamespace(url=URL, scale=2, instruction_scope='launch', timeout=args.timeout,
        settle_seconds=args.settle_seconds, audit_config=audit_config,
        memory_guard_registry=args.memory_guard_registry.resolve(),
        vox_arguments=['--screenshot-viewport-height', '768', '--js-engine=javascriptcore'],
        expected=reference, diff_tool=args.diff_tool.resolve(),
        audit_vox_capture_ownership=True,
        content_validator=lambda audit: content_gate(audit, args.title, expected_content),
        audit_expression=audit_expression(), brave_emulated_viewport=True)
    settings.readiness_expression = """location.href===URL && document.title===TITLE
        && document.readyState==='complete' && document.fonts.status==='loaded'
        && innerWidth===1024 && innerHeight===768 && devicePixelRatio===2
        && [...document.querySelectorAll('textarea,[contenteditable=true]')].some(e=>{
            const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&!e.disabled})""".replace(
            'URL', json.dumps(URL)).replace('TITLE', json.dumps(args.title))
    paths = {reference, audit_config, settings.diff_tool, out / 'source-expectations.json'}
    paths.update(p for p in archive.rglob('*') if p.is_file())
    paths.update(Path(__file__).parent / name for name in [
        'chatgpt_browser_instructions.py', 'capture_chatgpt_archive.py',
        'hacker_news_browser_instructions.py', 'coalition_instruction_counts.py',
        'process_instruction_counts.py', 'measure_browser_instructions.py',
        'measure_sealed_github_instructions.py', 'run_memory_bounded.py',
        'page_archive.py', 'check_pixel_equality.py', 'capture_brave_reference.py'])
    paths.update(runtime_input_paths(apps['vox'] / 'Contents/MacOS/Vox', {}))
    paths.update(native_dependencies(apps['vox'] / 'Contents/MacOS/Vox'))
    # Pin both application bundles, including renderer/utility executables.
    for app in apps.values():
        paths.update(p for p in app.rglob('*') if p.is_file())
    pins = fingerprint(paths)
    measurement.write_json(out / 'inputs.json', dict(files=pins, scope=measurement.LAUNCH_SCOPE,
        policy=dict(url=URL, viewport=[1024, 768], scale=2,
            author_scripts='Original bytes, enabled in both browsers; no frozen DOM substitution',
            network='Original-origin sealed replay, no forwarding or downloads during trials',
            caches='Empty private profiles/caches each trial; OS filesystem/shader caches retained',
            reference=str(reference), title=args.title, settle_seconds=args.settle_seconds,
            gate='100 * max(Vox upper) <= 95 * min(Brave lower), at least seven pairs')))
    replay = Replay(archive, out / 'replay')
    worker = threading.Thread(target=replay.server.serve_forever, daemon=True)
    worker.start()
    pairs = []
    try:
        public = subprocess.check_output(['openssl', 'x509', '-in', replay.ready['ca'], '-pubkey', '-noout'])
        der = subprocess.check_output(['openssl', 'pkey', '-pubin', '-outform', 'der'], input=public)
        spki = base64.b64encode(hashlib.sha256(der).digest()).decode()
        settings.vox_environment = dict(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
            VOX_BLOCK_COOKIE_BANNERS='0', VOX_CAPTURE_DOCUMENT_ACTIVE='1',
            LADYBIRD_ENABLE_SNAPSHOT_CACHE='0')
        settings.brave_proxy_argument = '--proxy-server=' + replay.ready['proxy'].replace('socks5h:', 'socks5:')
        settings.brave_arguments = ['--ignore-certificate-errors-spki-list=' + spki,
                                   '--force-device-scale-factor=2', '--disable-backgrounding-occluded-windows']
        measurement.write_json(out / 'replay.json', replay.ready)
        with clean_observer_environment():
            for index in range(args.repeat):
                pair = {}
                for engine in (['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox']):
                    require(fingerprint(paths) == pins, 'Inputs changed before trial')
                    row = measurement.run_browser(engine, apps[engine], out / f'pair-{index+1}-{engine}', settings)
                    pair[engine] = row
                    measurement.write_json(out / 'pairs.json', pairs + [pair])
                    print(json.dumps(measurement.progress_record(index+1, engine, row, 'launch')), flush=True)
                    require(fingerprint(paths) == pins, 'Inputs changed during trial')
                pairs.append(pair)
                if any(row['exit'] for row in pair.values()):
                    break
        summary = summarize(pairs)
    except Exception as error:
        summary = dict(passed=False, error=str(error), pairs=len(pairs),
            observation_errors=[dict(engine=engine, error=row.get('error'),
                                      kernel_exit_status=row.get('kernel_exit_status'))
                                for pair in pairs for engine, row in pair.items() if row.get('exit')])
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        worker.join()
    summary.update(optimization_credit=False, author_scripts='original, enabled',
                   scope=measurement.LAUNCH_SCOPE)
    measurement.write_json(out / 'summary.json', summary)
    print(json.dumps(summary), flush=True)
    return 0 if summary['passed'] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--expected', type=Path, required=True)
    parser.add_argument('--title', required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, required=True)
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--settle-seconds', type=float, default=5)
    args = parser.parse_args()
    if args.repeat < 2 or not 0 <= args.settle_seconds < args.timeout:
        parser.error('Need at least two pairs and settlement below the timeout')
    return run(args)


if __name__ == '__main__':
    sys.exit(main())
