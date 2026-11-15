#!/usr/bin/env python3
"""Same-executable alternating HN lookup-cache controls, candidates and V8.

Use the HN source-built test executable and run_memory_bounded --limit-gib 3.
This is the script/DOM workload documented in HACKER_NEWS_JS_ENGINES.md.
"""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import threading
import time

import benchmark_hn_engines as hn
from browser_bundle_lease import canonical_bundle_lease
from page_archive import Replay


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('--cycles', type=int, default=500)
    parser.add_argument('--optimization', choices=['property', 'arguments', 'combined'], default='property')
    args = parser.parse_args()
    if args.pairs < 7 or args.cycles < 1:
        parser.error('Use at least seven pairs and positive cycle counts')
    binary, output = args.binary.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    replay = Replay(hn.ARCHIVE, output / 'replay')
    aliases = hn.add_image_aliases(replay)
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    cache = output / 'native-cache'
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'JSC_', 'GC_'))
                   and 'proxy' not in k.lower()}
    environment.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
    report = dict(scope='same optimized test executable; HN native DOM, cached script initialization '
                       'and synchronous collapse/expand; excludes process startup, external network, '
                       'window, layout, paint and teardown; V8 includes local image host setup',
                  control='test-only switch disables successful property-position hints',
                  candidate='bounded live-key-validated successful property-position hints',
                  optimization=args.optimization,
                  attempts=[], inputs={}, replay=replay.ready, image_aliases=aliases,
                  host_before=hn.host())
    report['control'] = {'property': 'linear property lookup; arguments elision disabled',
                         'arguments': 'property hints enabled; arguments elision disabled',
                         'combined': 'linear property lookup; arguments elision disabled'}[args.optimization]
    report['candidate'] = {'property': 'validated property hints; arguments elision disabled',
                           'arguments': 'property hints enabled; unobserved arguments elided',
                           'combined': 'validated property hints and unobserved arguments elided'}[args.optimization]

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    def verify():
        for path, sha in report['inputs'].items():
            if not Path(path).is_file() or hn.digest(path) != sha:
                raise RuntimeError('Pinned input changed: ' + path)

    def run(config, label, diagnostic=False, seed=False):
        verify()
        engine = 'libjs' if seed else 'v8' if config == 'v8' else 'libjs-warm'
        env = dict(environment, VOX_HN_ENGINE_BENCHMARK=engine,
                   VOX_HN_ENGINE_CYCLES=str(args.cycles), VOX_LIBJS_NATIVE_CACHE=str(cache),
                   VOX_LIBJS_LOOKUP_HINTS='0' if config == 'control' else '1',
                   VOX_HN_ENGINE_DIAGNOSTIC=str(int(diagnostic)),
                   VOX_PROFILE_DIR=str(output / (label + '-profile')),
                   LADYBIRD_CACHE_DIR=str(output / (label + '-http-cache')), VOX_TEST_WINDOW='1')
        if args.optimization == 'property':
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '0'
        elif args.optimization == 'arguments':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '0' if config == 'control' else '1'
        else:
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '0' if config == 'control' else '1'
        attempt_policy = dict(property_hints=env['VOX_LIBJS_LOOKUP_HINTS'],
                              argument_elision=env['VOX_LIBJS_ARGUMENT_ELISION'])
        if diagnostic and config == 'v8':
            env['VOX_V8_DIAGNOSTICS'] = '1'
        attempt = dict(configuration=config, label=label, diagnostic=diagnostic, seed=seed,
                       policy=attempt_policy,
                       command=[str(binary)], environment={k: v for k, v in env.items()
                           if k.startswith(('VOX_', 'LADYBIRD_')) or k == 'SSL_CERT_FILE'},
                       host_before=hn.host())
        report['attempts'].append(attempt)
        save()
        started = time.monotonic_ns()
        try:
            process = subprocess.Popen([str(binary)], cwd=hn.ROOT, env=env, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            attempt['pid'] = process.pid
            save()
            try:
                stdout, stderr = process.communicate(timeout=120)
            except subprocess.TimeoutExpired:
                process.kill()
                stdout, stderr = process.communicate()
                attempt.update(exit=process.returncode, stdout=stdout, stderr=stderr, timeout=True)
                raise
            attempt.update(exit=process.returncode, stdout=stdout, stderr=stderr)
            if process.returncode:
                raise RuntimeError(f'{label} exited {process.returncode}')
            visits = [json.loads(line) for line in stdout.splitlines() if line.startswith('{')]
            attempt['visits'] = visits
            hn.validate(visits, engine, args.cycles, diagnostic, report['inputs'])
            for visit in visits:
                activity = visit['lookup_activity']
                if not diagnostic and any(activity.values()):
                    raise ValueError('Lookup diagnostics enabled in timed trial')
                if diagnostic and config == 'candidate' and activity['hits'] <= 0:
                    raise ValueError('Candidate did not exercise property hints')
                argument_activity = visit['argument_activity']
                if not diagnostic and any(argument_activity.values()):
                    raise ValueError('Argument allocation counters enabled during timing')
                if diagnostic and config == 'candidate' and args.optimization != 'property':
                    if argument_activity['elided'] <= 0 or argument_activity['created'] != 0:
                        raise ValueError('HN candidate did not elide all unobserved arguments objects')
            if seed:
                libraries = sorted(cache.rglob('*.dylib'))
                if not libraries:
                    raise ValueError('Seed did not produce native code')
                report['inputs'].update({str(p): hn.digest(p) for p in libraries})
                report['native_executables'] = visits[0]['cache']['compiled_executables']
            elif config != 'v8' and visits[0]['cache']['cache_hits'] != report['native_executables']:
                raise ValueError('Incomplete native-code reuse')
            if diagnostic and config == 'v8' and 'Vox V8 backend: V8 ' not in stderr:
                raise ValueError('Missing V8 backend diagnostic')
            requests = output / 'replay/requests.jsonl'
            if requests.exists() and any(not json.loads(line).get('archived', False)
                                         or json.loads(line).get('status') != 200
                                         for line in requests.read_text().splitlines()):
                raise ValueError('Invalid replay request')
            verify()
            print(label + ': ' + ', '.join(f"{v['callback_ms']:.3f} ms callbacks" for v in visits), flush=True)
        except Exception as error:
            attempt['error'] = str(error)
            raise
        finally:
            attempt.update(host_after=hn.host(), wall_ns=time.monotonic_ns() - started)
            save()

    try:
        with canonical_bundle_lease(hn.ROOT / 'Build/v/Vox.app'):
            paths = [binary, binary.parent / 'libVoxJSCOnV8.dylib', hn.SCRIPT, hn.PAGE,
                     hn.ARCHIVE / 'manifest.json', *sorted((hn.ARCHIVE / 'bodies').iterdir()),
                     hn.ASSETS / 's.gif', hn.ASSETS / 'y18.svg', Path(__file__), Path(hn.__file__),
                     hn.ROOT / 'libjs/property_lookup.v', hn.ROOT / 'libjs/object.v',
                     hn.ROOT / 'sites/hacker_news_engine_benchmark_test.v',
                     hn.ROOT / 'tools/page_archive.py',
                     *sorted((hn.ROOT / 'Build/v').glob('*.dylib'))]
            report['linked_libraries'] = {}
            for image in [binary, binary.parent / 'libVoxJSCOnV8.dylib']:
                linked = subprocess.check_output(['otool', '-L', str(image)], text=True)
                report['linked_libraries'][str(image)] = linked
                for line in linked.splitlines()[1:]:
                    path = Path(line.strip().split(' (', 1)[0])
                    if path.is_absolute() and path.is_file():
                        paths.append(path.resolve())
            report['inputs'] = {str(p): hn.digest(p) for p in paths}
            imports = subprocess.check_output(['nm', '-m', '-u', str(binary)], text=True)
            report['javascript_imports'] = '\n'.join(line for line in imports.splitlines() if '_JS' in line)
            for symbol in ['_JSGlobalContextCreate', '_JSEvaluateScript']:
                if not any(symbol + ' ' in line and '(from libVoxJSCOnV8)' in line for line in imports.splitlines()):
                    raise ValueError('JavaScript entry does not bind to V8: ' + symbol)
            run('control', 'seed', seed=True)
            for config in ['control', 'candidate', 'v8']:
                run(config, 'diagnostic-' + config, True)
            for index in range(args.pairs):
                order = ['control', 'candidate', 'v8'] if index % 2 == 0 else ['v8', 'candidate', 'control']
                for config in order:
                    run(config, f'pair-{index + 1}-{config}')
            trials = [a for a in report['attempts'] if not a['diagnostic'] and not a['seed']]
            report['summary'] = {config: {metric: dict(
                median=statistics.median(a['visits'][0][metric] for a in trials if a['configuration'] == config),
                min=min(a['visits'][0][metric] for a in trials if a['configuration'] == config),
                max=max(a['visits'][0][metric] for a in trials if a['configuration'] == config))
                for metric in hn.METRICS} for config in ['control', 'candidate', 'v8']}
            report['verified'] = True
            print(json.dumps(report['summary'], indent=2))
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        report['host_after'] = hn.host()
        save()


if __name__ == '__main__':
    main()
