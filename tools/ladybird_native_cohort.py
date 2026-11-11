#!/usr/bin/env python3
"""Run a pinned Ladybird catalog through Vox's native document test entry point.

Compile compact/upstream_testharness_test.v separately, then run this command
inside run_memory_bounded.py. A page must report every original expected name,
a clean harness, passing assertions and a successful guarded process exit.
This exercises navigation/DOM/CSS/layout/JSC; it does not validate GUI painting.
"""
import argparse
from collections import Counter
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from browser_bundle_lease import canonical_bundle_lease
from wpt_compare import clean_environment, discover_tests, upstream_testharness
from wpt_fixtures import export_fixtures, verify_fixture_tree
from wpt_upstream_server import UpstreamWPTServer
from wpt_expectation_errata import load_expectation_errata

REPO = Path(__file__).resolve().parents[1]
REPORT = b'''if(typeof document!=="undefined"&&self===top){
globalThis.nativeWptResult=null;setup({output:false});
add_completion_callback((tests,status)=>{globalThis.nativeWptResult={
harness:status.status,harness_message:status.message,
tests:tests.map(t=>({name:t.name,status:t.status,message:t.message}))}});}'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def catalog_ids(text):
    ids = [line.strip() for line in text.splitlines()
           if line.strip() and not line.lstrip().startswith('#')]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError('Catalog must contain distinct test IDs')
    return ids


def expectation_names(text):
    """Names can span lines; only a status-tab prefix starts a new name."""
    names, current = [], None
    for line in text.splitlines():
        match = re.match(r'^(?:Pass|Fail|Timeout|NotRun|Not run|PreconditionFailed)\t(.*)$', line)
        if match:
            if current is not None:
                names.append('\n'.join(current))
            current = [match.group(1)]
        elif current is not None:
            current.append(line)
    if current is not None:
        names.append('\n'.join(current))
    found = re.search(r'^Found (\d+) tests?$', text, re.M)
    if not names or (found and int(found.group(1)) != len(names)):
        raise ValueError('Expected-name count does not match the Ladybird expectation')
    return names


def assess(payload, expected, process_exit):
    tests = payload.get('tests', []) if payload else []
    missing = list((Counter(expected) - Counter(t['name'] for t in tests)).elements())
    passed = (process_exit == 0 and payload is not None and payload.get('harness') == 0
              and not missing and len(tests) >= len(expected)
              and all(t['status'] == 0 for t in tests))
    return dict(all_pass=passed, expected_subtests=len(expected), missing_names=missing,
                reported=len(tests), passing=sum(t['status'] == 0 for t in tests))


class Requests:
    def __init__(self, file):
        self.file = file

    def note_request(self, target):
        pass

    def note_harness(self, target):
        pass

    def accept(self, payload):
        raise AssertionError('Native collector does not accept a result POST')

    def log_request(self, *args):
        self.file.write(json.dumps(args) + '\n')
        self.file.flush()


def run(args):
    fixture, manifest = export_fixtures(args.ladybird, args.ladybird_ref, args.fixture_cache)
    text_root = fixture / 'Tests/LibWeb/Text'
    catalog = args.catalog.read_text()
    revision = re.search(r'^# Ladybird ([0-9a-f]{40})$', catalog, re.M)
    if revision and revision.group(1) != manifest['revision']:
        raise ValueError('Catalog revision differs from the selected fixture revision')
    ids = catalog_ids(catalog)
    discovered = {t['id']: t for t in discover_tests(text_root)}
    if any(name not in discovered for name in ids):
        raise ValueError('Catalog contains IDs absent from the pinned fixture revision')
    cases = [discovered[name] for name in ids
             if not args.include or any(name == p or name.startswith(p.rstrip('/') + '/')
                                        for p in args.include)]
    if not cases:
        raise ValueError('No selected cases')
    expected = {t['id']: expectation_names((text_root / 'expected/wpt-import' /
                (t['id'].replace('?', '@', 1) + '.txt')).read_text()) for t in cases}
    args.output.mkdir(parents=True, exist_ok=False)
    write(args.output / 'tests.json', cases)
    write(args.output / 'expected-names.json', expected)
    paths = [args.native, args.catalog, Path(__file__), REPO / 'compact/upstream_testharness_test.v',
             *[REPO / 'tools' / n for n in ['wpt_compare.py', 'wpt_upstream_server.py',
               'wpt_fixtures.py', 'browser_bundle_lease.py', 'run_memory_bounded.py',
               'wpt_expectation_errata.py']]]
    errata_overrides, errata = {}, []
    errata_sha = None
    if args.expectation_errata:
        paths.append(args.expectation_errata)
        errata_sha = sha(args.expectation_errata)
        errata_overrides, errata = load_expectation_errata(args.expectation_errata,
            text_root / 'input/wpt-import', manifest['revision'], cases)
    variant = 'proposed-expectation-errata' if errata else 'unmodified-upstream'
    bundle = REPO / 'Build/v/Vox.app'
    if bundle.exists():
        paths += [p for p in (bundle / 'Contents/MacOS').iterdir() if p.is_file()]
    pins = {str(p.resolve()): sha(p) for p in paths}
    if args.expectation_errata and pins[str(args.expectation_errata.resolve())] != errata_sha:
        raise RuntimeError('Expectation errata changed while loading')
    identity = dict(pins=pins, fixture_revision=manifest['revision'], changed_inputs=[],
                    fixture_variant=variant, expectation_errata=errata,
                    scope='native document navigation, DOM, CSS, layout, JSC; no GUI or painting',
                    host=dict(cpu_count=os.cpu_count(), load=os.getloadavg()), command=sys.argv)
    write(args.output / 'identity.json', identity)

    def verify():
        identity['changed_inputs'] = [p for p, h in pins.items()
                                      if not Path(p).is_file() or sha(p) != h]
        write(args.output / 'identity.json', identity)
        if identity['changed_inputs']:
            raise RuntimeError('Native cohort inputs changed')

    root = text_root / 'input/wpt-import'
    overrides = {'/resources/testharness.js':
                 (upstream_testharness((root / 'resources/testharness.js').read_text()).encode(),
                  'text/javascript'), '/resources/testharnessreport.js': (REPORT, 'text/javascript')}
    overrides.update(errata_overrides)
    rows, started = [], time.monotonic()
    lease = canonical_bundle_lease(bundle) if bundle.exists() else contextlib.nullcontext()
    with lease, (args.output / 'requests.jsonl').open('w') as requests:
        server = UpstreamWPTServer(args.wpt_root, root, Requests(requests), overrides,
                                   '/__alive', '/__result', args.output / 'certificates')
        try:
            write(args.output / 'server.json', server.identity)
            for i, test in enumerate(cases):
                verify()
                if server.changed_inputs():
                    raise RuntimeError('WPT server inputs changed')
                profile = args.output / f'profile-{i:03}'
                profile.mkdir()
                (profile / 'settings.json').write_text('{"allow_any_site":true}\n')
                result = args.output / f'{i:03}.result.json'
                env = clean_environment()
                env.update(VOX_UPSTREAM_WPT_URL=server.base_url + test['url'],
                           VOX_UPSTREAM_WPT_RESULT=str(result), VOX_PROFILE_DIR=str(profile))
                command = [sys.executable, str(REPO / 'tools/run_memory_bounded.py'),
                           '--limit-gib', '2', '--timeout', '80',
                           '--lock', str(args.output / f'{i:03}.lock'),
                           '--report', str(args.output / f'{i:03}.guard.json'), '--', str(args.native)]
                tick = time.monotonic()
                with (args.output / f'{i:03}.log').open('w') as log:
                    process = subprocess.run(command, cwd=REPO, env=env, stdin=subprocess.DEVNULL,
                                             stdout=log, stderr=subprocess.STDOUT)
                payload = json.loads(result.read_text()) if result.exists() else None
                row = dict(id=test['id'], url=test['url'], exit=process.returncode,
                           seconds=time.monotonic() - tick, result=payload,
                           **assess(payload, expected[test['id']], process.returncode))
                rows.append(row)
                write(args.output / 'cases.json', rows)
                print(test['id'], f"{row['passing']}/{row['reported']}",
                      f"missing={len(row['missing_names'])}", f'exit={process.returncode}', flush=True)
        finally:
            server.shutdown()
        if server.changed_inputs():
            raise RuntimeError('WPT server inputs changed')
        verify()
        verify_fixture_tree(fixture, manifest)
    summary = dict(cases=len(rows), passing_cases=sum(r['all_pass'] for r in rows),
                   subtests=sum(r['reported'] for r in rows),
                   passing_subtests=sum(r['passing'] for r in rows),
                   expected_subtests=sum(r['expected_subtests'] for r in rows),
                   missing_subtests=sum(len(r['missing_names']) for r in rows),
                   all_pass=len(rows) == len(cases) and all(r['all_pass'] for r in rows),
                   wall_seconds=time.monotonic() - started, inputs_unchanged=True,
                   fixture_variant=variant, corrected_expectations=len(errata),
                   executable_sha256=sha(args.native))
    # Passing a corrected variant cannot establish that the original tests pass.
    summary['unmodified_upstream_all_pass'] = None if errata else summary['all_pass']
    write(args.output / 'summary.json', summary)
    print(json.dumps(summary), flush=True)
    return int(not summary['all_pass'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--ladybird-ref', required=True)
    parser.add_argument('--native', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--ladybird', type=Path, default=REPO.parent / '3rd/ladybird')
    parser.add_argument('--wpt-root', type=Path, default=REPO.parent / '3rd/web-platform-tests')
    parser.add_argument('--fixture-cache', type=Path, default=Path.home() / '.cache/vox/wpt')
    parser.add_argument('--include', action='append', default=[])
    parser.add_argument('--expectation-errata', type=Path,
                        help='Explicit expectation-only corrections; labels results as modified fixtures')
    args = parser.parse_args()
    args.native, args.catalog, args.output = (p.resolve() for p in
                                             [args.native, args.catalog, args.output])
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
