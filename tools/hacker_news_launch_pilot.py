#!/usr/bin/env python3
"""Vox-only launch-to-PNG pilots using the canonical Hacker News capture gates.

Usage: hacker_news_launch_pilot.py OUTPUT REPEAT NAME=APP[:KEY=VALUE,...] ...

Variants rotate each round. These observations are not Brave acceptance pairs.
Run through run_memory_bounded.py, passing the same PID registry to both tools.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import statistics
import sys

import hacker_news_browser_instructions as hn
from page_archive import load_archive

REPO = hn.REPO
CHECKPOINT = re.compile(r'Vox instructions cumulative: (\S+) (\d+)')


def parse_variant(value):
    name, separator, rest = value.partition('=')
    if not separator or not re.fullmatch(r'[A-Za-z0-9_-]+', name):
        raise argparse.ArgumentTypeError('Expected NAME=APP[:KEY=VALUE,...]; use a simple unique name')
    app, _, environment = rest.partition(':')
    variables = {}
    for item in environment.split(',') if environment else []:
        key, separator, value = item.partition('=')
        if not separator or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', key) or key in variables:
            raise argparse.ArgumentTypeError('Expected unique KEY=VALUE environment overrides')
        variables[key] = value
    path = Path(app).expanduser().absolute()
    if not app or not (path / 'Contents/MacOS/Vox').is_file():
        raise argparse.ArgumentTypeError('Expected an existing Vox.app: ' + app)
    return dict(name=name, app=str(path), environment=variables)


def rotated_variants(variants, trial):
    start = (trial - 1) % len(variants)
    return variants[start:] + variants[:start]


def prepare_capture(output, diff_tool, registry=None, timeout=120):
    archive = REPO / 'Tests/Browser/Brave/hn-home-instructions'
    args = hn.parse_args(['--output', str(output), '--home-archive', str(archive),
                          '--diff-tool', str(diff_tool), '--timeout', str(timeout),
                          '--instruction-scope', 'launch'])
    args.memory_guard_registry = registry
    args.output = args.output.absolute()
    args.output.mkdir(parents=True, exist_ok=False)
    args.diff_tool = args.diff_tool.absolute()
    manifest = load_archive(archive)
    hn.require(manifest['url'] == 'https://news.ycombinator.com/', 'Expected the Hacker News home page')
    args.document = archive / 'bodies' / manifest['responses'][manifest['url']]['sha256']
    args.row_name, args.row_selector = 'stories', 'tr.athing'
    args.expected_comments = hn.document_comments(args.document, 'athing')
    hn.require(len(args.expected_comments) == 30, 'Home-page fixture must contain all 30 stories')
    args.audit_config = args.output / 'audit-config.json'
    hn.write_json(args.audit_config, dict(selectors=[dict(name=args.row_name, selector=args.row_selector,
                  limit=len(args.expected_comments), attributes=['id'], layout_depth=0)]))
    return args


def input_paths(args, variants):
    paths = {args.expected, args.diff_tool, args.audit_config, Path(__file__).absolute()}
    paths.update(path for path in args.home_archive.rglob('*') if path.is_file())
    paths.update(path for path in hn.COALITION_SERVICES if path.is_file())
    paths.update(REPO / 'tools' / name for name in (
        'hacker_news_browser_instructions.py', 'check_pixel_equality.py',
        'coalition_instruction_counts.py', 'measure_browser_instructions.py',
        'capture_brave_reference.py', 'measure_sealed_github_instructions.py',
        'pikabu_browser_instructions.py', 'process_instruction_counts.py',
        'page_archive.py', 'run_memory_bounded.py', 'measure_precise_scroll.py'))
    for variant in variants:
        app = Path(variant['app'])
        binary = app / 'Contents/MacOS/Vox'
        paths.update(path for path in app.rglob('*') if path.is_file())
        paths.update(hn.native_dependencies(binary))
        environment = variant['environment']
        paths.update(hn.runtime_input_paths(binary, environment))
        if environment.get('DYLD_INSERT_LIBRARIES'):
            for image in environment['DYLD_INSERT_LIBRARIES'].split(':'):
                paths.update(hn.native_dependencies(Path(image)))
    # Keep lexical paths through Vox.app: resolving them would hide a replaced
    # symlink or publication. No bundles or repository tools are copied.
    return paths


def checked_trial(args, variant, trial, paths, pinned):
    folder = args.output / f"trial-{trial}-{variant['name']}"
    row = dict(trial=trial, variant=variant['name'], exit=1, instructions=None,
               pixels_exact=False, content_exact=False, error=None, checkpoints={})
    try:
        hn.require(hn.fingerprint(paths) == pinned, 'Pinned input changed before the trial')
        args.vox_environment = variant['environment']
        result = hn.run_browser('vox', Path(variant['app']), folder, args)
        interval = result.get('launch_instruction_interval') or {}
        log = folder / 'browser.log'
        for label, value in CHECKPOINT.findall(log.read_text(errors='replace') if log.exists() else ''):
            row['checkpoints'].setdefault(label, int(value))
        row.update(exit=result.get('exit'), instructions=interval.get('lower'),
                   instruction_interval=interval, pixels_exact=result.get('pixels_exact'),
                   content_exact=result.get('content_exact'), error=result.get('error'),
                   png_sha256=result.get('png_sha256'), kernel_exit_status=result.get('kernel_exit_status'),
                   host_before=result.get('host_before'), host_after=result.get('host_after'),
                   started_unix=result.get('started_unix'), finished_unix=result.get('finished_unix'))
        hn.require(hn.fingerprint(paths) == pinned, 'Pinned input changed during the trial')
        row['inputs_unchanged'] = True
        hn.require(row['exit'] == 0 and row['kernel_exit_status'] == 0
                   and row['pixels_exact'] is True and row['content_exact'] is True,
                   row['error'] or 'Capture gates failed')
        hn.require(type(interval.get('lower')) is int and interval['lower'] > 0
                   and interval.get('upper') == interval['lower'], 'Missing exact launch counter')
    except Exception as error:
        row.update(exit=1, error=str(error))
    return row


def summarize(rows, variants, repeat):
    summary = {}
    for variant in variants:
        selected = [row for row in rows if row['variant'] == variant['name']]
        valid = (len(selected) == repeat and {row['trial'] for row in selected} == set(range(1, repeat + 1))
                 and all(row['exit'] == 0 and row.get('inputs_unchanged') is True
                         and row.get('pixels_exact') is True and row.get('content_exact') is True
                         and type(row['instructions']) is int and row['instructions'] > 0
                         for row in selected))
        counts = [row['instructions'] for row in selected]
        summary[variant['name']] = dict(counts=counts, completed=len(selected), expected=repeat,
            median=statistics.median(counts) if valid else None,
            max=max(counts) if valid else None, all_gates=valid)
    if len(variants) > 1:
        base = variants[0]['name']
        for variant in variants[1:]:
            name = variant['name']
            valid = summary[base]['all_gates'] and summary[name]['all_gates']
            savings = []
            if valid:
                for trial in range(1, repeat + 1):
                    by_name = {row['variant']: row for row in rows if row['trial'] == trial}
                    savings.append(by_name[base]['instructions'] - by_name[name]['instructions'])
            summary[name]['paired_saving_vs_' + base] = dict(
                values=savings, median=statistics.median(savings) if valid else None)
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('repeat', type=int)
    parser.add_argument('variants', nargs='+', type=parse_variant)
    parser.add_argument('--diff-tool', type=Path, default=REPO / 'Build/pixel-tools/pixel_diff')
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    options = parser.parse_args(argv)
    if options.repeat < 1 or len({v['name'] for v in options.variants}) != len(options.variants):
        parser.error('Need a positive repeat count and unique variant names')
    args = prepare_capture(options.output, options.diff_tool, options.memory_guard_registry)
    variants = options.variants
    paths = input_paths(args, variants)
    pinned = hn.fingerprint(paths)
    hn.write_json(args.output / 'inputs.json', dict(variants=variants, files=pinned,
        scope=hn.LAUNCH_SCOPE, navigation_scope=hn.SCOPE, acceptance=False,
        policy='Vox-only pilot; every attempt retained; changed inputs invalidate the pilot',
        command=sys.argv if argv is None else argv,
        host=dict(cpu_count=os.cpu_count(), load_average=os.getloadavg()),
        viewport_css_pixels=[hn.WIDTH, hn.HEIGHT], device_scale=args.scale,
        settle_seconds=args.settle_seconds))
    rows = []
    with hn.fixture_server(args.document, args.output, args.home_archive) as args.url:
        hn.write_json(args.output / 'replay.json', dict(url=args.url, document=str(args.document),
            network_policy='Loopback replay only; fresh profiles/caches; Cache-Control: no-store',
            os_caches='Filesystem and shader caches retained'))
        for trial in range(1, options.repeat + 1):
            for variant in rotated_variants(variants, trial):
                row = checked_trial(args, variant, trial, paths, pinned)
                rows.append(row)
                hn.write_json(args.output / 'rows.json', rows)
                print(json.dumps(row), flush=True)
    summary = summarize(rows, variants, options.repeat)
    hn.write_json(args.output / 'summary.json', summary)
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if all(value['all_gates'] for value in summary.values()) else 1


if __name__ == '__main__':
    raise SystemExit(main())
