#!/usr/bin/env python3
"""Compare installed Vox Skia/GG adapters on frozen Hacker News bytes.

Run through run_memory_bounded.py with the same --memory-guard-registry. Keep
the canonical bundle under a publication lease for the entire comparison.
Counters cover startup through encoded PNG, not isolated rendering. Scrolling
uses the existing native precise-input/publication probe, without profiling.
"""
import argparse
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import time
import traceback

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import hacker_news_browser_instructions as hn
from browser_bundle_lease import canonical_bundle_lease
from measure_precise_scroll import runtime_input_paths
from measure_sealed_github_instructions import clean_environment, fingerprint, native_dependencies
from page_archive import load_archive
from gg_migration.capture_ab import compare as compare_window
from PIL import Image
from check_pixel_equality import compare as compare_document
from process_instruction_counts import MacCounters

ROOT = TOOLS.parent
GG = dict(VOX_GG_TEXT='1', VOX_GG_SHAPES='1', VOX_GG_PATHS='1')
LOAD_SCOPE = ('Main browser process, all threads, process creation through the native encoded '
              'document PNG checkpoint; startup/window setup, page scripting/layout/paint and PNG '
              'encoding included. Filter helpers, GPU work and external services excluded. '
              'Not a total-browser coalition measurement or isolated raster cost.')


def coverage(log):
    before, during = {}, {}
    target = before
    for line in log.splitlines():
        if line.startswith('SCROLL_DONE '):
            break  # The optional final PNG is outside the measured pipeline.
        if line.startswith('SCROLL_START '):
            target = during
        match = re.fullmatch(r'VOX_GG (text|shape|path|svg) (.*?) drawn=([01])', line)
        if match:
            key = match[1] + ' ' + match[2]
            row = target.setdefault(key, dict(drawn=0, declined=0))
            row['drawn' if match[3] == '1' else 'declined'] += 1
    return dict(startup=before, input_and_final_publication=during)


def stats(values):
    return dict(samples=len(values), median=statistics.median(values),
                minimum=min(values), maximum=max(values), values=values)


def encoded_instructions(log):
    values = re.findall(r'^Vox instructions cumulative: capture_document_encoded (\d+)$',
                        log, re.MULTILINE)
    hn.require(len(values) == 1 and int(values[0]) > 0, 'Missing or duplicate PNG counter endpoint')
    return int(values[0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--app', type=Path, default=ROOT/'Build/v/Vox.app')
    parser.add_argument('--archive', type=Path, default=hn.FIXTURES/'hn-home-instructions')
    parser.add_argument('--diff-tool', type=Path, required=True)
    parser.add_argument('--load-pairs', type=int, default=7)
    parser.add_argument('--scroll-pairs', type=int, default=4)
    parser.add_argument('--inputs', type=int, default=600)
    parser.add_argument('--reverse-every', type=int, default=60,
                        help='Reverse before reaching the frozen page boundary (60 at delta 3)')
    parser.add_argument('--scroll-only', action='store_true',
                        help='Keep diagnostic loads/pixels but omit the seven timed load pairs')
    parser.add_argument('--chrome-height', type=int, default=112)
    parser.add_argument('--load-chrome-height', type=int, default=84,
                        help='Screenshot mode chrome; audited document must still be 1024x768')
    args = parser.parse_args()
    if args.load_pairs < 7 or args.scroll_pairs < 2 or args.inputs < 60 or args.reverse_every < 1:
        parser.error('Need seven load pairs, two scroll pairs and at least 60 inputs')
    # Reject ambient controls instead of inheriting a different workload.
    ambient = sorted(os.environ.keys() - clean_environment().keys())
    if ambient:
        parser.error('Remove ambient measurement controls: ' + ', '.join(ambient))
    output, app, archive = (p.resolve() for p in (args.output, args.app, args.archive))
    output.mkdir(parents=True, exist_ok=False)
    binary = app/'Contents/MacOS/Vox'
    manifest = load_archive(archive)
    document = archive/'bodies'/manifest['responses'][manifest['url']]['sha256']
    ids = hn.document_comments(document, 'athing')
    hn.require(manifest['url'] == 'https://news.ycombinator.com/' and len(ids) == 30,
               'Need the unchanged complete HN homepage archive')
    audit_config = output/'audit-config.json'
    hn.write_json(audit_config, dict(selectors=[dict(name='stories', selector='tr.athing',
                  limit=30, attributes=['id'], layout_depth=0)]))
    config = argparse.Namespace(instruction_scope='launch', scale=2, timeout=120,
        settle_seconds=2, audit_config=audit_config, row_name='stories', row_selector='tr.athing',
        expected_comments=ids, diff_tool=args.diff_tool.resolve(), vox_scripting=True,
        memory_guard_registry=args.memory_guard_registry.resolve(),
        audit_vox_capture_ownership=True, vox_chrome_height=args.load_chrome_height)
    rows, scrolling, diagnostics = [], [], []
    summary = dict(valid=False, workload='Archived Hacker News homepage, original scripts and '
        'resources, loopback no-store replay, fresh profiles/caches, retained OS caches, '
        '1024x768 document, native scale 2; same executable and C mode for both variants',
        comparison='Existing Skia versus opt-in GG text/shapes/paths; fallback and other Skia paths remain',
        load_scope=LOAD_SCOPE, scroll_scope='Changed Cocoa layer publications after updateLayer, '
        'over the full first-to-last precise-input period; not physical scanout',
        load=rows, scrolling=scrolling, diagnostics=diagnostics,
        scroll_reverse_every=args.reverse_every, timed_load_omitted=args.scroll_only)
    with canonical_bundle_lease(app):
        pinned_paths = {Path(__file__).resolve(), Path(hn.__file__), audit_config,
                        args.diff_tool.resolve(), *archive.rglob('*')}
        pinned_paths.update(p for p in app.rglob('*') if p.is_file())
        pinned_paths.update(runtime_input_paths(binary, {}))
        pinned_paths.update(native_dependencies(binary))
        pinned_paths.update(TOOLS/name for name in ['measure_precise_scroll.py',
            'measure_precise_scroll_darwin.m', 'precise_scroll_faults.h', 'page_archive.py',
            'coalition_instruction_counts.py', 'process_instruction_counts.py',
            'measure_sealed_github_instructions.py', 'browser_bundle_lease.py'])
        pinned_paths = {p for p in pinned_paths if p.is_file()}
        pinned = fingerprint(pinned_paths)
        hn.write_json(output/'inputs.json', dict(files=pinned, story_ids=ids,
                      production_receipt=json.loads((ROOT/'Build/production-build/latest.json').read_text())))

        def unchanged():
            hn.require(fingerprint(pinned_paths) == pinned, 'Pinned benchmark inputs changed')

        def load(label, folder, diagnostic=False, reference=False):
            unchanged()
            directory = output/folder
            directory.mkdir()
            profile, cache = directory/'profile', directory/'cache'
            profile.mkdir(); cache.mkdir()
            png, audit = directory/'document.png', directory/'audit.json'
            environment = clean_environment()
            environment.update(GG if label == 'gg' else {})
            environment.update(VOX_MEASURE_NATIVE_SUBMISSION='1', VOX_PROFILE_INSTRUCTIONS='1',
                VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache),
                MallocSpaceEfficient='1', VOX_COOKIE_FILE='', LADYBIRD_SCREENSHOT_SCALE='2',
                VOX_SCREENSHOT_NATIVE_LAYOUT='1', VOX_CAPTURE_DOCUMENT_ONLY='1',
                LADYBIRD_SCREENSHOT_DELAY_SECONDS='2', VOX_CAPTURE_AUDIT_CONFIG=str(audit_config),
                VOX_CAPTURE_AUDIT_PATH=str(audit))
            if diagnostic:
                environment.update(VOX_GG_DIAGNOSTICS='1', LADYBIRD_DEBUG_TIMING='1')
            command = [str(binary), '--enable-javascript', '--window-width', '1024',
                       '--window-height', str(768+args.load_chrome_height), '--screenshot',
                       str(png), config.url]
            row = dict(exit=1, variant=label, folder=folder, command=command,
                       environment={k:v for k,v in environment.items() if k.startswith(
                           ('VOX_','LADYBIRD_','Malloc'))}, started_unix=time.time(),
                       host_before=dict(cpu_count=os.cpu_count(), load_average=os.getloadavg()))
            child = None
            try:
                with (directory/'browser.log').open('w') as log:
                    child = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=log,
                                             stderr=subprocess.STDOUT)
                    usage = MacCounters().read(child.pid)
                    row.update(pid=child.pid, start_ticks=usage.start)
                    hn.publish_adopted_processes(config.memory_guard_registry, [child.pid])
                    try:
                        row['browser_exit'] = child.wait(timeout=config.timeout)
                    except subprocess.TimeoutExpired:
                        child.kill(); row['browser_exit'] = child.wait()
                        raise RuntimeError('Browser capture watchdog expired')
                hn.require(row['browser_exit'] == 0 and png.is_file(), 'Browser capture failed')
                text = (directory/'browser.log').read_text()
                count = encoded_instructions(text)
                row['launch_instruction_interval'] = dict(lower=count, upper=count)
                content = json.loads(audit.read_text())
                hn.check_content(content, config.url, ids, 'stories')
                hn.require(not content.get('native_reported_error_count') and
                           not content.get('javascript_diagnostics'), 'Document reported errors')
                row['content_exact'] = True
                if not reference:
                    verdict = compare_document(config.expected, png, directory/'diff.png', config.diff_tool)
                    row['pixel_comparison'] = verdict
                    hn.require(verdict['exact'], 'Captured pixels differ from fixed Skia reference')
                row['exit'] = 0
            except Exception as error:
                row.update(error=str(error), traceback=traceback.format_exc())
            finally:
                if child and child.poll() is None:
                    child.kill(); child.wait()
                row.update(finished_unix=time.time(), host_after=dict(
                    cpu_count=os.cpu_count(), load_average=os.getloadavg()))
            if (directory/'browser.log').exists():
                row['native_submission_ms'] = {
                    key:int(value) for key,value in re.findall(
                        r'^Ladybird V timing: ((?:navigation|document_install)_to_first_native_layer_submission) (\d+) ms$',
                        (directory/'browser.log').read_text(), re.MULTILINE)}
                if row['exit'] == 0 and not reference:
                    hn.require(len(row['native_submission_ms']) == 2,
                               'Missing native first-document submission times')
            hn.write_json(directory/'result.json', row)
            unchanged()
            print(json.dumps(dict(stage='load', folder=folder, variant=label, exit=row['exit'],
                instructions=row.get('launch_instruction_interval'), error=row.get('error'))), flush=True)
            return row

        def scroll(label, folder, diagnostic=False, counters=False):
            unchanged()
            command = [sys.executable, str(TOOLS/'measure_precise_scroll.py'), '--binary', str(binary),
                '--url', config.url, '--output', str(output/folder), '--allow-fixture-navigation',
                '--network-policy', 'Frozen HN archive, same loopback no-store server; no live access',
                '--width', '1024', '--height', '768', '--chrome-height', str(args.chrome_height),
                '--inputs', str(args.inputs), '--delta', '3', '--reverse-every', str(args.reverse_every),
                '--input-hz', '60', '--settle-seconds', '4', '--require-title', 'Hacker News',
                '--script-policy', 'enabled']
            env = dict(GG) if label == 'gg' else {}
            env['VOX_PRECISE_FINAL_CAPTURE'] = str(output/folder/'final.png')
            if diagnostic:
                env['VOX_GG_DIAGNOSTICS'] = '1'
            if counters:
                command.append('--instructions')
            for key, value in env.items():
                command.extend(['--env', key+'='+value])
            with (output/(folder+'.log')).open('w') as log:
                run = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
            row = dict(variant=label, folder=folder, command=command, exit=run.returncode,
                       diagnostic=diagnostic, counters=counters)
            if (output/folder/'summary.json').exists():
                row['summary'] = json.loads((output/folder/'summary.json').read_text())
            if run.returncode == 0:
                final = output/folder/'final.png'
                hn.require(final.is_file(), 'Missing final scroll pixels')
                with Image.open(final) as image:
                    w,h = image.size
                factor = w/1024
                hn.require(factor in (1,2) and h == (768+args.chrome_height)*factor,
                           'Final scroll capture has unexpected dimensions')
                row['final_pixel_size'] = [w,h]
                if (output/'scroll-reference.png').exists():
                    row['final_pixels'] = compare_window(output/'scroll-reference.png', final,
                        [(w-int(224*factor), h-int(24*factor), int(224*factor), int(24*factor))])
                    hn.require(row['final_pixels']['equal'], 'Final scroll pixels differ from fixed Skia reference')
                elif label == 'skia':
                    # The diagnostic Skia scroll establishes the reference;
                    # every later control and candidate must preserve it.
                    (output/'scroll-reference.png').write_bytes(final.read_bytes())
            if diagnostic and (output/folder/'browser.log').exists():
                row['coverage'] = coverage((output/folder/'browser.log').read_text())
            unchanged()
            print(json.dumps({k:v for k,v in row.items() if k not in ('command', 'summary')}
                | {'fps':row.get('summary', {}).get('mean_scroll_fps')}), flush=True)
            return row

        try:
            with hn.fixture_server(document, output, archive) as config.url:
                hn.write_json(output/'replay.json', dict(url=config.url, archive=str(archive)))
                reference = load('skia', 'diagnostic-reference', True, True)
                diagnostics.append(reference)
                hn.require(reference['exit'] == 0, 'Reference capture failed')
                config.expected = output/'diagnostic-reference/document.png'
                for label in ('skia', 'gg'):
                    row = load(label, 'diagnostic-'+label, True)
                    diagnostics.append(row)
                    hn.require(row['exit'] == 0, 'Diagnostic load/pixels failed')
                    if label == 'gg':
                        log = (output/'diagnostic-gg/browser.log').read_text()
                        hn.require('VOX_GG enabled text=true shapes=true paths=true' in log,
                                   'This bundle does not contain GG adapters')
                        summary['load_coverage'] = coverage(log)
                for label in ('skia','gg'):
                    row = scroll(label, 'diagnostic-scroll-'+label, True)
                    diagnostics.append(row)
                    hn.require(row['exit'] == 0, 'Diagnostic scrolling failed')
                    if label == 'gg': summary['scroll_coverage'] = row['coverage']
                for pair in range(0 if args.scroll_only else args.load_pairs):
                    for label in (('skia','gg') if pair % 2 == 0 else ('gg','skia')):
                        row = load(label, f'load-{pair+1}-{label}')
                        rows.append(row)
                        hn.write_json(output/'results.json', summary)
                        hn.require(row['exit'] == 0, 'Load comparison failed; attempt retained')
                for pair in range(args.scroll_pairs):
                    for label in (('skia','gg') if pair % 2 == 0 else ('gg','skia')):
                        row = scroll(label, f'scroll-{pair+1}-{label}')
                        scrolling.append(row)
                        hn.write_json(output/'results.json', summary)
                        hn.require(row['exit'] == 0, 'Scroll comparison failed; attempt retained')
                # Hardware-counter scrolling is a separate diagnostic cohort.
                for label in ('skia', 'gg'):
                    row = scroll(label, 'counter-scroll-'+label, counters=True)
                    diagnostics.append(row)
                    hn.require(row['exit'] == 0, 'Scrolling counter diagnostic failed')
            summary['statistics'] = {}
            for label in ('skia', 'gg'):
                loads = [r for r in rows if r['variant'] == label]
                scrolls = [r['summary'] for r in scrolling if r['variant'] == label]
                summary['statistics'][label] = dict(
                    scroll_fps=stats([r['mean_scroll_fps'] for r in scrolls]),
                    scroll_interval_median_ms=stats([r['scroll_interval_us']['median']/1000 for r in scrolls]),
                    scroll_interval_p95_ms=stats([r['scroll_interval_us']['p95']/1000 for r in scrolls]),
                    scroll_interval_max_ms=stats([r['scroll_interval_us']['max']/1000 for r in scrolls]),
                    over_budget_fraction=stats([r['fraction_over_budget'] for r in scrolls]),
                    update_layer_median_ms=stats([r['update_layer_us']['median']/1000 for r in scrolls]))
                if loads:
                    summary['statistics'][label].update(
                        navigation_to_native_submission_ms=stats([r['native_submission_ms'][
                            'navigation_to_first_native_layer_submission'] for r in loads]),
                        document_install_to_native_submission_ms=stats([r['native_submission_ms'][
                            'document_install_to_first_native_layer_submission'] for r in loads]),
                        launch_instructions=stats([r['launch_instruction_interval']['upper'] for r in loads]))
            unchanged()
            summary['valid'] = True
        finally:
            hn.write_json(output/'results.json', summary)
    print(json.dumps(summary.get('statistics', {}), indent=2), flush=True)


if __name__ == '__main__':
    main()
