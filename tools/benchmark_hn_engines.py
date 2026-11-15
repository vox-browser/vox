#!/usr/bin/env python3
"""Compare V8 with first/reopened LibJS HN script and native DOM work.

Use the source-built sites/hacker_news_engine_benchmark_test.v executable and
run this driver through run_memory_bounded --limit-gib 3. No window is created.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import threading
import time

from browser_bundle_lease import canonical_bundle_lease
from page_archive import Replay, load_archive

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0'
PAGE = ROOT / 'Tests/Browser/Brave/input/hacker-news-item-50231722-complete.html'
ARCHIVE = ROOT / 'Tests/Browser/Brave/hn-home-instructions'
ASSETS = ROOT / 'Tests/Browser/Brave/input/hacker-news-item-50231722'
METRICS = ['initialization_ms', 'first_cycle_ms', 'callback_ms', 'compile_finish_ms', 'total_ms']


def digest(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def host():
    return dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg())


def add_image_aliases(replay, assets=ASSETS):
    # The retained discussion has a local-assets <base>. Preserve its bytes
    # and resolve those two image URLs to the exact same archived asset bytes.
    aliases = {}
    for name in ['s.gif', 'y18.svg']:
        original = 'https://news.ycombinator.com/' + name
        alias = 'https://news.ycombinator.com/hacker-news-item-50231722/' + name
        entry = replay.manifest['responses'][original]
        if digest(assets / name) != entry['sha256']:
            raise ValueError('Discussion image differs from archived response: ' + name)
        replay.manifest['responses'][alias] = dict(entry)
        aliases[alias] = dict(original=original, sha256=entry['sha256'])
    return aliases


def validate(visits, engine, cycles, diagnostic, pins):
    expected = {'v8': ['v8'], 'libjs': ['libjs-cold', 'libjs-process-warm'],
                'libjs-warm': ['libjs-warm']}[engine]
    if [v['mode'] for v in visits] != expected:
        raise ValueError('Missing or unexpected visit receipts')
    for visit in visits:
        if (visit['rows'] != 101 or not visit['collapse_verified']
                or not visit['classes_restored'] or visit['cycles'] != cycles
                or visit['native_context'] != (engine == 'v8')
                or visit['script_sha256'] != pins[str(SCRIPT)]
                or visit['page_sha256'] != pins[str(PAGE)]):
            raise ValueError('Engine, fixture, cancellation or DOM audit failed')
        if any(not math.isfinite(visit[key]) or visit[key] < 0 for key in METRICS):
            raise ValueError('Invalid timing')
        if visit['cache']['last_error'] or visit['cache']['invalid_entries']:
            raise ValueError('Native cache failed')
        if not diagnostic and any(visit['activity'].values()):
            raise ValueError('Diagnostic counters enabled in timed visit')
    if engine == 'libjs':
        cold, warm = visits
        if (cold['cache']['compiler_invocations'] < 1
                or cold['cache']['cache_hits'] != 0
                or cold['frontend']['misses'] < 1
                or warm['cache']['compiler_invocations'] != 0
                or warm['cache']['cache_misses'] != 0
                or warm['cache']['pending_executables'] != 0
                or warm['cache']['cache_hits'] != cold['cache']['compiled_executables']
                or warm['frontend']['misses'] != 0
                or warm['frontend']['hits'] != cold['frontend']['misses']):
            raise ValueError('Cold compilation or compiler-free complete warm reuse failed')
        if diagnostic and warm['activity']['entries'] <= 0:
            raise ValueError('Warm native code did not execute')
    elif engine == 'libjs-warm':
        warm = visits[0]
        if (warm['cache']['compiler_invocations'] != 0 or warm['cache']['cache_hits'] < 1
                or warm['cache']['cache_misses'] != 0 or warm['cache']['pending_executables'] != 0
                or warm['frontend']['hits'] != 0 or warm['frontend']['misses'] < 1):
            raise ValueError('Restart did not reuse native code with a cold process-local frontend')
        if diagnostic and warm['activity']['entries'] <= 0:
            raise ValueError('Restart did not execute cached native code')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('--cycles', type=int, default=100)
    parser.add_argument('--timeout', type=float, default=120)
    args = parser.parse_args()
    if args.pairs < 7 or args.cycles < 1 or args.timeout <= 0:
        parser.error('Use at least seven pairs, positive cycles and timeout')
    output, binary = args.output.resolve(), args.binary.resolve()
    output.mkdir(parents=True, exist_ok=False)
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_', 'VFLAGS'))
                   and 'proxy' not in k.lower()}
    report = dict(scope='HN HTML parse, browser engine/DOM initialization, first collapse/expand, '
                       'repeated callbacks including DOM synchronization, explicit cache finish; '
                       'includes original-origin loopback image replay during V8 host setup; '
                       'excludes process startup, external network, window, layout, paint, PNG, audits and teardown',
                  warm_policy='libjs-warm: fresh process/document/VM and retained native cache, cold parser; '
                              'libjs-process-warm: same-process parsed-source and native reuse; '
                              'both use compiler /usr/bin/false',
                  filesystem_cache='retained; no OS cache purge',
                  adblock='disabled for every mode; author-script/DOM comparison excludes filter-list startup',
                  host_before=host(), attempts=[], linked_libraries={}, inputs={})
    replay = Replay(ARCHIVE, output / 'replay')
    report['image_aliases'] = add_image_aliases(replay)
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    environment.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
    report['replay'] = replay.ready

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    def verify():
        if any(not Path(path).is_file() or digest(path) != sha
               for path, sha in report['inputs'].items()):
            raise RuntimeError('Pinned executable, fixture, driver or native library changed')

    def run(engine, label, diagnostic=False, cache_label=None):
        verify()
        env = dict(environment, VOX_HN_ENGINE_BENCHMARK=engine,
                   VOX_HN_ENGINE_CYCLES=str(args.cycles),
                   VOX_HN_ENGINE_DIAGNOSTIC=str(int(diagnostic)),
                   VOX_LIBJS_NATIVE_CACHE=str(output / ((cache_label or label) + '-cache')),
                   LADYBIRD_CACHE_DIR=str(output / (label + '-http-cache')),
                   VOX_PROFILE_DIR=str(output / (label + '-profile')),
                   VOX_TEST_WINDOW='1')
        if diagnostic and engine == 'v8':
            env['VOX_V8_DIAGNOSTICS'] = '1'
        attempt = dict(label=label, engine=engine, diagnostic=diagnostic,
                       command=[str(binary)], environment={k: v for k, v in env.items()
                                                        if k.startswith(('VOX_', 'LADYBIRD_')) or k == 'SSL_CERT_FILE'}, host_before=host())
        report['attempts'].append(attempt)
        save()
        began = time.monotonic_ns()
        try:
            process = subprocess.Popen([str(binary)], cwd=ROOT, env=env, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            attempt['pid'] = process.pid
            save()
            try:
                stdout, stderr = process.communicate(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                process.kill()
                stdout, stderr = process.communicate()
                attempt.update(timeout=True, exit=process.returncode, stdout=stdout, stderr=stderr)
                raise
            attempt.update(exit=process.returncode, stdout=stdout, stderr=stderr)
            if process.returncode:
                raise RuntimeError(f'{label} exited {process.returncode}')
            visits = [json.loads(line) for line in stdout.splitlines() if line.startswith('{')]
            attempt['visits'] = visits
            validate(visits, engine, args.cycles, diagnostic, report['inputs'])
            if diagnostic and engine == 'v8' and 'Vox V8 backend: V8 ' not in stderr:
                raise ValueError('Missing V8 backend diagnostic')
            cache = Path(env['VOX_LIBJS_NATIVE_CACHE'])
            attempt['native_libraries'] = {str(p): digest(p) for p in cache.rglob('*.dylib')}
            if engine != 'v8' and not attempt['native_libraries']:
                raise ValueError('Missing compiled native libraries')
            if engine == 'libjs-warm':
                first = next(a for a in report['attempts'] if a['label'] == cache_label)
                if attempt['native_libraries'] != first['native_libraries']:
                    raise ValueError('Compiled native libraries changed on restart')
                if visits[0]['cache']['cache_hits'] != first['visits'][0]['cache']['compiled_executables']:
                    raise ValueError('Restart did not reuse the complete first-visit native cohort')
            verify()
            requests = output / 'replay/requests.jsonl'
            if requests.exists() and any(not json.loads(line).get('archived', False)
                                         for line in requests.read_text().splitlines()):
                raise ValueError('Replay received an unarchived or failed request')
            print(label + ': ' + ', '.join(f"{v['mode']} {v['total_ms']:.3f} ms"
                                          for v in visits), flush=True)
        except Exception as error:
            attempt['error'] = str(error)
            raise
        finally:
            attempt.update(wall_ns=time.monotonic_ns() - began, host_after=host())
            save()

    try:
        # Source-built tests also link the shared browser's native libraries.
        with canonical_bundle_lease(ROOT / 'Build/v/Vox.app'):
            paths = [binary, SCRIPT, PAGE, Path(__file__),
                     ROOT / 'sites/hacker_news_engine_benchmark_test.v',
                     ROOT / 'tools/page_archive.py', ARCHIVE / 'manifest.json',
                     *sorted((ARCHIVE / 'bodies').iterdir()), Path(replay.ready['ca']),
                     ASSETS / 's.gif', ASSETS / 'y18.svg',
                     binary.parent / 'libVoxJSCOnV8.dylib',
                     *sorted((ROOT / 'Build/v').glob('*.dylib'))]
            for image in [binary, binary.parent / 'libVoxJSCOnV8.dylib']:
                linked = subprocess.check_output(['otool', '-L', str(image)], text=True)
                report['linked_libraries'][str(image)] = linked
                for line in linked.splitlines()[1:]:
                    path = Path(line.strip().split(' (', 1)[0])
                    if path.is_absolute() and path.is_file():
                        paths.append(path.resolve())
            report['inputs'] = {str(path): digest(path) for path in paths}
            imports = subprocess.check_output(['nm', '-m', '-u', str(binary)], text=True)
            report['javascript_imports'] = '\n'.join(line for line in imports.splitlines()
                                                     if '_JS' in line)
            for symbol in ['_JSGlobalContextCreate', '_JSEvaluateScript']:
                if not any(symbol + ' ' in line and '(from libVoxJSCOnV8)' in line
                           for line in imports.splitlines()):
                    raise ValueError(f'{symbol} is not bound to the V8 backend')
            save()
            run('v8', 'diagnostic-v8', True)
            run('libjs', 'diagnostic-libjs', True)
            run('libjs-warm', 'diagnostic-libjs-warm', True, 'diagnostic-libjs')
            for index in range(args.pairs):
                order = ['v8', 'libjs'] if index % 2 == 0 else ['libjs', 'v8']
                for engine in order:
                    run(engine, f'pair-{index + 1}-{engine}')
                    if engine == 'libjs':
                        run('libjs-warm', f'pair-{index + 1}-libjs-warm',
                            cache_label=f'pair-{index + 1}-libjs')
            visits = [v for a in report['attempts'] if not a['diagnostic'] for v in a['visits']]
            report['summary'] = {mode: {metric: dict(
                median=statistics.median(v[metric] for v in visits if v['mode'] == mode),
                min=min(v[metric] for v in visits if v['mode'] == mode),
                max=max(v[metric] for v in visits if v['mode'] == mode)) for metric in METRICS}
                for mode in ['v8', 'libjs-cold', 'libjs-warm', 'libjs-process-warm']}
            report['verified'] = True
            load_archive(ARCHIVE)
            print(json.dumps(report['summary'], indent=2))
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        report['host_after'] = host()
        save()


if __name__ == '__main__':
    main()
