#!/usr/bin/env python3
"""Compare retired instructions for identical frozen github.com/vlang/v captures.

The input is a serialized, script-free GitHub repository page (its DOM after
hydration) with a <base href>. Counts cover process launch through capture.
Vox additionally includes teardown; both observed process trees are polling
lower bounds. Neither includes GPU instructions or external services. Archived
HTTP bodies feed both engines; missing responses fail offline. This does not
measure live JavaScript parity.
"""
import argparse
import json
import os
from pathlib import Path
from html.parser import HTMLParser
from types import SimpleNamespace
import sys
import time

import measure_browser_instructions as measurement
from process_instruction_counts import MacCounters
from check_pixel_equality import compare
from reddit_browser_instructions import (FrozenAssetsCDP, baseline_vox_counts, digest,
    engine_reference, evaluate_pairs, evaluate_vox_cohort, fingerprint_tree,
    private_measurement_environment, vox_control_environment, vox_launch_arguments)

REPO = Path(__file__).resolve().parents[1]
ROW_SELECTOR = 'tr.react-directory-row'


class GitHubAssetsCDP(FrozenAssetsCDP):
    def call(self, method, params=None):
        marker = "paint:performance.getEntriesByType('paint').map(r=>r.toJSON())"
        if method == 'Runtime.evaluate' and params and marker in params.get('expression', ''):
            params = dict(params)
            params['expression'] = params['expression'].replace(marker, marker +
                ',viewport_width:innerWidth,viewport_height:innerHeight,'
                f'rowIds:[...document.querySelectorAll({ROW_SELECTOR!r})].map(e=>e.id)')
        return super().call(method, params)


def document_identity(path):
    class Identity(HTMLParser):
        in_title = False
        def handle_starttag(self, tag, attrs):
            attrs = dict(attrs)
            if tag == 'title':
                self.in_title = True
            if tag == 'tr' and 'react-directory-row' in (attrs.get('class') or '').split():
                rows.append(attrs.get('id') or '')
        def handle_endtag(self, tag):
            if tag == 'title':
                self.in_title = False
        def handle_data(self, value):
            if self.in_title:
                title.append(value)
    title, rows = [], []
    Identity(convert_charrefs=True).feed(path.read_text())
    title = ''.join(title).strip()
    if not title or not rows or len(rows) != len(set(rows)) or '' in rows:
        raise ValueError('Frozen GitHub input must have a title and uniquely identified directory rows')
    return title, rows


def validate_document(report, url, title, rows, engine):
    audit = report['document_audit']
    if (audit.get('url') != url or audit.get('ready') != 'complete' or audit.get('title') != title
            or [audit.get('viewport_width'), audit.get('viewport_height')] != [1024, 768]):
        raise RuntimeError('GitHub document identity, readiness or viewport differs')
    if engine == 'vox':
        if not audit.get('fully_active') or audit.get('paint_commands', 0) <= 0:
            raise RuntimeError('GitHub document is inactive or unpainted')
        selection = next((s for s in audit.get('selections', []) if s.get('name') == 'rows'), {})
        actual = [row.get('attributes', {}).get('id') for row in selection.get('elements', [])]
        if selection.get('count') != len(rows):
            raise RuntimeError('GitHub document omitted directory rows')
    else:
        actual = audit.get('rowIds')
    if actual != rows:
        raise RuntimeError('GitHub document omitted or reordered directory rows')


def pinned_inputs(args):
    from measure_sealed_github_instructions import native_dependencies
    paths = {args.html, args.expected, args.vox, args.brave, args.network_deny, args.diff_tool,
             *native_dependencies(args.vox), *args.vox.parent.glob('*.dylib')}
    if args.expected_vox is not None:
        paths.add(args.expected_vox)
    for path in (args.vox.with_name('VoxAdblockWorker'),
                 args.vox.parent.parent / 'Resources/adblock.snapshot.bin'):
        if path.is_file():
            paths.add(path)
    frameworks = args.brave.parent.parent / 'Frameworks/Brave Browser Framework.framework/Versions'
    paths.update(path.resolve() for path in frameworks.glob('*/Brave Browser Framework'))
    paths.update(REPO / 'tools' / name for name in (
        'github_browser_instructions.py', 'reddit_browser_instructions.py',
        'measure_browser_instructions.py', 'process_instruction_counts.py',
        'probe_frozen_github_chrome.py', 'check_pixel_equality.py',
        'measure_sealed_github_instructions.py'))
    return {str(path.resolve()): digest(path) for path in paths}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--html', type=Path, required=True)
    parser.add_argument('--expected', type=Path, required=True,
                        help='Brave reference capture of --html at 1024x768')
    parser.add_argument('--expected-vox', type=Path,
                        help='Compare Vox captures with this fixed Vox reference instead of --expected. '
                             'Brave still uses --expected; the summary records the cross-browser difference.')
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vox', type=Path, default=REPO/'Build/v/Vox.app/Contents/MacOS/Vox')
    parser.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    parser.add_argument('--vox-js-engine', choices=['javascriptcore', 'libjs'], default='javascriptcore',
                        help='Explicit Vox backend selection; Brave uses V8. The script-free input may not create a runtime.')
    parser.add_argument('--network-deny', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, default=REPO/'Build/pixel-tools/pixel_diff')
    parser.add_argument('--repeat', type=int, default=7)
    parser.add_argument('--required-reduction', type=float, default=.10)
    parser.add_argument('--vox-only', action='store_true',
                        help='Measure only Vox against its fixed reference; Brave is not launched.')
    parser.add_argument('--brave-only', action='store_true',
                        help='Measure only Brave against its fixed reference; Vox is not launched.')
    parser.add_argument('--vox-env', action='append', default=[], metavar='VOX_DISABLE_NAME=VALUE',
                        help='Set a VOX_DISABLE_* control in every Vox observation (same-binary A/B).')
    parser.add_argument('--baseline-summary', type=Path,
                        help='With --vox-only, compare medians with an earlier Vox cohort on the same fixture.')
    args = parser.parse_args()
    if args.baseline_summary is not None and not args.vox_only:
        parser.error('--baseline-summary compares Vox-only cohorts')
    if args.vox_only and args.brave_only:
        parser.error('Choose at most one of --vox-only and --brave-only')
    try:
        vox_controls = vox_control_environment(args.vox_env)
    except ValueError as error:
        parser.error(str(error))
    if args.repeat < 1 or not 0 <= args.required_reduction < 1:
        parser.error('Invalid repeat count or required reduction')
    for name in ['html', 'expected', 'expected_vox', 'cache', 'output', 'vox', 'brave', 'network_deny', 'diff_tool']:
        if getattr(args, name) is not None:
            setattr(args, name, getattr(args, name).resolve())
    if not args.network_deny.is_file():
        parser.error('Build the process-local network deny dylib first')
    args.output.mkdir(parents=True, exist_ok=False, mode=0o700)
    cross_browser = None
    if args.expected_vox is not None and not (args.vox_only or args.brave_only):
        cross_browser = compare(args.expected, args.expected_vox,
                                args.output/'vox-reference-vs-brave-reference.diff.png', args.diff_tool)
    title, rows = document_identity(args.html)
    audit_config = args.output/'row-audit-config.json'
    audit_config.write_text(json.dumps(dict(selectors=[dict(name='rows', selector=ROW_SELECTOR,
        limit=len(rows), attributes=['id'], layout_depth=0)])))
    pinned = pinned_inputs(args)
    cache_hash = fingerprint_tree(args.cache)
    html_digest, reference_digest = digest(args.html), digest(engine_reference(args, 'vox'))
    baseline = None
    if args.baseline_summary is not None:
        baseline = baseline_vox_counts(args.baseline_summary, html_digest, reference_digest, cache_hash)
    api = MacCounters()
    pairs = []
    for index in range(args.repeat):
        pair = {}
        engines = (['vox'] if args.vox_only else ['brave'] if args.brave_only
                   else ['vox', 'brave'] if index % 2 == 0 else ['brave', 'vox'])
        for engine in engines:
            prefix = args.output / f'pair-{index+1}.{engine}'
            config = SimpleNamespace(binary=args.vox if engine == 'vox' else args.brave,
                url=args.html.as_uri(), width=1024, height=768, timeout=90,
                scratch_dir=args.output, sample_interval=.005,
                vox_arg=vox_launch_arguments(args.vox_js_engine), chrome_launch_mode='blank',
                chrome_disable_javascript=False,
                chrome_extra_arg=['--no-proxy-server', '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE localhost'])
            started = time.time()
            host_before = dict(cpu_count=os.cpu_count(), load_average=os.getloadavg())
            with private_measurement_environment(args.network_deny if engine == 'vox' else None, args.output):
                if engine == 'vox':
                    os.environ['VOX_CAPTURE_AUDIT_PATH'] = str(prefix)+'.audit.json'
                    os.environ['VOX_CAPTURE_AUDIT_CONFIG'] = str(audit_config)
                    os.environ.update(vox_controls)
                    with measurement.fresh_vox_cache(args.cache, args.output) as (cache, _):
                        report = measurement.run_vox(config, prefix, api, cache)
                    report['document_audit'] = json.loads(Path(str(prefix)+'.audit.json').read_text())
                else:
                    report = measurement.run_chrome(config, prefix, api,
                        client_factory=lambda url: GitHubAssetsCDP(url, args.cache))
            report.update(profile_policy='fresh empty private profile per observation', screenshot_scale=1,
                          selected_js_engine=args.vox_js_engine if engine == 'vox' else 'v8',
                          started_unix=started, finished_unix=time.time(), host_before=host_before,
                          host_after=dict(cpu_count=os.cpu_count(), load_average=os.getloadavg()))
            report_path = Path(str(prefix)+'.json')
            report_path.write_text(json.dumps(report, indent=2)+'\n')
            validate_document(report, config.url, title, rows, engine)
            report['content_exact'] = True
            verdict = compare(engine_reference(args, engine), Path(report['screenshot']),
                              Path(str(prefix)+'.diff.png'), args.diff_tool)
            report['pixels_exact'] = verdict['exact']
            report['pixel_comparison'] = verdict
            if report['unreadable_pids']:
                raise RuntimeError('Unreadable browser process counters')
            report_path.write_text(json.dumps(report, indent=2)+'\n')
            pair[engine] = report
            print(json.dumps(dict(pair=index+1, engine=engine, instructions=report['instructions'],
                                  pixels_exact=verdict['exact'])), flush=True)
            if not verdict['exact']:
                raise RuntimeError('Rendered viewport differs; this sample receives no performance credit')
            if pinned != pinned_inputs(args) or cache_hash != fingerprint_tree(args.cache):
                raise RuntimeError('Pinned runtime or benchmark input changed during measurement')
        pairs.append(pair)
    if pinned != pinned_inputs(args) or cache_hash != fingerprint_tree(args.cache):
        raise RuntimeError('Pinned executable, runtime or benchmark input changed')
    if args.vox_only:
        summary = evaluate_vox_cohort(pairs, baseline, args.required_reduction)
        summary.update(baseline_summary=str(args.baseline_summary) if baseline else None)
    elif args.brave_only:
        brave = [pair['brave']['instructions'] for pair in pairs]
        summary = dict(brave_observed_instructions=brave,
                       brave_median_observed_instructions=sorted(brave)[len(brave) // 2])
    else:
        summary = evaluate_pairs(pairs, args.required_reduction)
    summary.update(html_sha256=html_digest, vox_reference_sha256=reference_digest,
                   vox_control_environment=vox_controls,
                   reference_policy='Vox-only fixed Vox reference' if args.vox_only
                   else 'per-engine fixed references' if args.expected_vox is not None else 'shared Brave reference',
                   cross_browser_reference_pixels=cross_browser)
    summary.update(pairs=pairs, pinned_sha256=pinned, cache_sha256=cache_hash,
                   selected_js_engines=dict(vox=args.vox_js_engine, brave='v8'),
                   title=title, row_ids=rows, sample_interval_seconds=.005,
                   counter='proc_pid_rusage/RUSAGE_INFO_V4/ri_instructions',
                   scope=__doc__, viewport=[1024, 768], scripting_policy_enabled=True,
                   workload_note='Frozen input is the serialized hydrated DOM with script elements removed.')
    (args.output/'summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print(json.dumps({k: v for k, v in summary.items() if k not in ['pairs', 'pinned_sha256', 'scope']}), flush=True)
    return 0 if summary.get('passed', True) else 1


if __name__ == '__main__':
    sys.exit(main())
