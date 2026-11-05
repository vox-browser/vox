#!/usr/bin/env python3
"""Captures every fixture twice with one Vox bundle, alternating a control and a
candidate environment, and reports which captures differ.

The candidate differs only by extra environment variables (for example
VOX_GG_TEXT=1). Captures are whole windows, so they are compared as decoded
RGBA pixels outside --ignore rectangles; by default that is the status bar's
live "RAM: …" readout, which changes between any two launches. Fixtures whose
captures differ are captured once more with the control environment to
separate rendering differences from nondeterminism. Each fixture is one of:

  equal            control and candidate pixels match
  equal_to_repeat  the control was the outlier: the candidate matches the repeat
  different        the control is stable but the candidate differs
  unstable         all three captures differ
  failed           a capture exited abnormally or wrote no PNG

Writes OUTPUT/summary.json and keeps every PNG and log. --recompare rebuilds
the summary from an existing OUTPUT without launching the browser.
"""
import argparse
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from browser_bundle_lease import canonical_bundle_lease

OUTCOMES = ('equal', 'equal_to_repeat', 'different', 'unstable', 'failed')


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def input_identity(bundle, inputs):
    """Pin the executable, native libraries, fixtures and shared fixture resources."""
    paths = [bundle / 'Contents/MacOS/Vox', *bundle.glob('Contents/MacOS/*.dylib')]
    for directory in (inputs, inputs.parent / 'assets', inputs.parent / 'resources'):
        if directory.is_dir():
            paths.extend(p for p in directory.rglob('*') if p.is_file())
    return {str(p): sha256(p) for p in sorted(set(paths))}


def enabled_renderers(environment):
    return [name for name in ('text', 'shapes', 'paths')
            if environment.get('VOX_GG_' + name.upper()) == '1']


def registration_present(log, renderers):
    marker = next((line for line in log.read_text(errors='replace').splitlines()
                   if line.startswith('VOX_GG enabled ')), '')
    return all(f'{name}=true' in marker.split() for name in renderers)


def capture(browser, html, png, log, extra_env, width, height, delay, timeout):
    env = {k: v for k, v in os.environ.items() if not k.startswith(('VOX_GG_', 'VOX_DISABLE_'))}
    env.update(extra_env)
    env['VOX_TEST_WINDOW'] = '1'
    env['LADYBIRD_SCREENSHOT_DELAY_SECONDS'] = str(delay)
    with tempfile.TemporaryDirectory(prefix='vox-ab-profile-') as profile:
        env['VOX_PROFILE_DIR'] = profile
        with log.open('wb') as out:
            try:
                result = subprocess.run([str(browser), '--window-width', str(width), '--window-height',
                                         str(height), '--screenshot', str(png), str(html)],
                                        env=env, stdout=out, stderr=subprocess.STDOUT, timeout=timeout)
                return result.returncode
            except subprocess.TimeoutExpired:
                return 'timeout'


def compare(first, second, ignore):
    """Compares decoded RGBA pixels outside the ignored (x, y, w, h) rectangles."""
    if not first.exists() or not second.exists():
        return None
    with Image.open(first) as a, Image.open(second) as b:
        a, b = a.convert('RGBA'), b.convert('RGBA')
    if a.size != b.size:
        return {'equal': False, 'sizes': [list(a.size), list(b.size)]}
    for x, y, w, h in ignore:
        a.paste((0, 0, 0, 0), (x, y, x + w, y + h))
        b.paste((0, 0, 0, 0), (x, y, x + w, y + h))
    difference = ImageChops.difference(a, b)
    box = difference.getbbox(alpha_only=False)
    if box is None:
        return {'equal': True}
    pixels = sum(1 for p in difference.crop(box).getdata() if p != (0, 0, 0, 0))
    return {'equal': False, 'pixels': pixels, 'bbox': list(box)}


def classify(row, directory, ignore):
    """Fills the row's comparisons and outcome from the PNGs in directory."""
    control, candidate, repeat = (directory / f'{m}.png' for m in ('control', 'candidate', 'control-repeat'))
    for stale in ('equal', 'control_stable'):
        row.pop(stale, None)
    exits = [row.get('control_exit'), row.get('candidate_exit')]
    row['candidate_vs_control'] = compare(control, candidate, ignore)
    if 'control_repeat_exit' in row or repeat.exists():
        exits.append(row.get('control_repeat_exit'))
        row['repeat_vs_control'] = compare(control, repeat, ignore)
        row['candidate_vs_repeat'] = compare(repeat, candidate, ignore)
    first = row['candidate_vs_control']
    if row.get('error') or any(code != 0 for code in exits) or first is None:
        row['outcome'] = 'failed'
    elif first['equal']:
        row['outcome'] = 'equal'
    elif row.get('repeat_vs_control') is None or row.get('candidate_vs_repeat') is None:
        row['outcome'] = 'failed'
    elif row['candidate_vs_repeat']['equal']:
        row['outcome'] = 'equal_to_repeat'
    elif row['repeat_vs_control']['equal']:
        row['outcome'] = 'different'
    else:
        row['outcome'] = 'unstable'
    return row


def parse_rectangle(text):
    values = [int(v) for v in text.split(',')]
    if len(values) != 4 or values[2] <= 0 or values[3] <= 0:
        raise argparse.ArgumentTypeError('expected X,Y,W,H')
    return tuple(values)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--bundle', type=Path)
    parser.add_argument('--inputs', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--candidate-env', action='append', default=[], metavar='KEY=VALUE')
    parser.add_argument('--width', type=int, default=1024)
    parser.add_argument('--height', type=int, default=852)
    parser.add_argument('--delay', type=float, default=2)
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--only', action='append', default=[])
    parser.add_argument('--fixture-list', type=Path,
                        help='one fixture stem per line, preserving a historical cohort')
    parser.add_argument('--ignore', action='append', type=parse_rectangle, metavar='X,Y,W,H',
                        help='window rectangle excluded from comparison (default: the RAM readout)')
    parser.add_argument('--recompare', action='store_true',
                        help='rebuild OUTPUT/summary.json from existing captures')
    args = parser.parse_args()
    ignore = args.ignore or [(args.width - 224, args.height - 24, 224, 24)]
    if args.recompare:
        # Without a summary (an interrupted run), exit codes are unknown.
        path = args.output / 'summary.json'
        summary = json.loads(path.read_text()) if path.exists() else {}
        if not summary:
            summary = {'interim': True}
        if not args.ignore and summary.get('ignore'):
            ignore = summary['ignore']
        previous = summary.get('results') or [
            {'fixture': d.name} for d in sorted(args.output.iterdir())
            if (d / 'control.png').exists() and (d / 'candidate.png').exists()]
        rows = [classify(row, args.output / row['fixture'], ignore) for row in previous]
        renderers = enabled_renderers(summary.get('candidate_env', {}))
        if renderers:
            for row in rows:
                log = args.output / row['fixture'] / 'candidate.log'
                if not log.exists() or not registration_present(log, renderers):
                    row.update(outcome='failed', error='requested gg.canvas renderers were not registered')
    else:
        if not args.bundle or not args.inputs:
            parser.error('--bundle and --inputs are required unless --recompare is given')
        rows, summary = run_captures(args, ignore)
    summary.update(ignore=[list(r) for r in ignore], fixtures=len(rows), results=rows)
    summary.update({o: [r['fixture'] for r in rows if r['outcome'] == o] for o in OUTCOMES if o != 'equal'})
    summary['equal'] = sum(r['outcome'] == 'equal' for r in rows)
    for stale in ('different_stable_control', 'different_unstable_control'):
        summary.pop(stale, None)
    (args.output / 'summary.json').write_text(json.dumps(summary, indent=1))
    print(json.dumps({k: v for k, v in summary.items() if k != 'results'}, indent=1))
    return 0 if (summary.get('inputs_unchanged') and not summary.get('interim') and rows
                 and len(rows) == summary.get('requested_fixtures', len(rows))
                 and all(r['outcome'] in ('equal', 'equal_to_repeat') for r in rows)) else 1


def run_captures(args, ignore):
    # Compilation can continue while this holds a shared publication lease.
    # The publisher waits before replacing the app; all hash checks remain.
    with canonical_bundle_lease(args.bundle):
        return run_leased_captures(args, ignore)


def run_leased_captures(args, ignore):
    browser = args.bundle / 'Contents/MacOS/Vox'
    candidate = dict(item.split('=', 1) for item in args.candidate_env)
    # Diagnostics prove the requested adapters were registered in this binary.
    renderers = enabled_renderers(candidate)
    if renderers:
        candidate['VOX_GG_DIAGNOSTICS'] = '1'
    args.output.mkdir(parents=True, exist_ok=False)
    identity_before = sha256(browser)
    inputs_before = input_identity(args.bundle, args.inputs)
    fixtures = sorted(args.inputs.glob('*.html'))
    if args.fixture_list:
        names = args.fixture_list.read_text().splitlines()
        available = {f.stem for f in fixtures}
        missing = sorted(set(names) - available)
        if missing or len(names) != len(set(names)):
            raise ValueError(f'invalid fixture list: missing={missing}, duplicate names={len(names) != len(set(names))}')
        fixtures = [f for f in fixtures if f.stem in names]
    if args.only:
        fixtures = [f for f in fixtures if f.stem in args.only]
    rows = []
    inputs_unchanged = True
    for html in fixtures:
        directory = args.output / html.stem
        directory.mkdir(exist_ok=True)
        row = {'fixture': html.stem}
        for mode, env in (('control', {}), ('candidate', candidate)):
            if input_identity(args.bundle, args.inputs) != inputs_before:
                inputs_unchanged = False
                break
            png = directory / f'{mode}.png'
            row[f'{mode}_exit'] = capture(browser, html, png, directory / f'{mode}.log', env,
                                          args.width, args.height, args.delay, args.timeout)
            row[f'{mode}_sha256'] = sha256(png)
        if not inputs_unchanged:
            row['outcome'] = 'failed'
            row['error'] = 'inputs changed during capture'
            rows.append(row)
            break
        first = compare(directory / 'control.png', directory / 'candidate.png', ignore)
        if first is not None and not first['equal']:
            png = directory / 'control-repeat.png'
            row['control_repeat_exit'] = capture(browser, html, png, directory / 'control-repeat.log',
                                                 {}, args.width, args.height, args.delay, args.timeout)
            row['control_repeat_sha256'] = sha256(png)
        classify(row, directory, ignore)
        if renderers and not registration_present(directory / 'candidate.log', renderers):
            row.update(outcome='failed', error='requested gg.canvas renderers were not registered')
        rows.append(row)
        # Preserve actual exits and partial progress if the guard stops the run.
        (args.output / 'summary.json').write_text(json.dumps({
            'interim': True, 'results': rows, 'candidate_env': candidate,
            'bundle': str(args.bundle), 'input_identity': inputs_before,
            'executable_sha256_before': identity_before,
            'requested_fixtures': len(fixtures),
        }, indent=1))
        print(json.dumps(row), flush=True)
    summary = {
        'bundle': str(args.bundle), 'executable_sha256_before': identity_before,
        'executable_sha256_after': sha256(browser), 'candidate_env': candidate,
        'input_identity': inputs_before,
        'inputs_unchanged': inputs_unchanged and input_identity(args.bundle, args.inputs) == inputs_before,
        'requested_fixtures': len(fixtures),
    }
    return rows, summary


if __name__ == '__main__':
    sys.exit(main())
