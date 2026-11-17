#!/usr/bin/env python3
"""Compare original Reddit handlers through Vox's LibJS, V8 and JSC DOM bridges.

Use matching source-built sites/reddit_engine_benchmark_test.v executables.
Run through run_memory_bounded --limit-gib 3. No window or rendering is involved.
"""
import argparse
import json
import math
import os
from pathlib import Path
import signal
import statistics
import subprocess
import sys
import threading
import time

from benchmark_hn_engines import build_receipts, digest, host, measure_child
from browser_bundle_lease import canonical_bundle_lease
from measure_precise_scroll import runtime_input_paths
from page_archive import Replay

ROOT = Path(__file__).resolve().parents[1]
METRICS = ['initialization_ms', 'first_cycle_ms', 'callback_ms', 'compile_finish_ms', 'total_ms']


def validate(visit, mode, cycles, manifest_sha, diagnostic=False, memory=False):
    if (visit['mode'] != mode or visit['cycles'] != cycles
            or visit['manifest_sha256'] != manifest_sha
            or not all(visit[k] for k in ['collapse_verified', 'classes_restored', 'probe_verified'])
            or visit['native_context'] != (mode in ['v8', 'jsc'])):
        raise ValueError('Wrong workload, failed DOM audit, or unexpected engine fallback')
    if any(not math.isfinite(visit[k]) or visit[k] < 0 for k in METRICS):
        raise ValueError('Invalid measured interval')
    if abs(visit['total_ms'] - sum(visit[k] for k in METRICS[:-1])) > 0.001:
        raise ValueError('Inconsistent interval sum')
    if not 0 < visit['callback_thread_cpu_ns'] <= visit['callback_ms'] * 1e6 + 10000000:
        raise ValueError('Invalid callback thread CPU clock')
    if bool(visit['self_peak_rss_bytes']) != memory:
        raise ValueError('Unexpected root-process memory probe')
    cache = visit['cache']
    if cache['last_error'] or cache['invalid_entries'] or cache['pending_executables']:
        raise ValueError('Native cache failed or was not completely flushed')
    if mode == 'libjs-warm' and (cache['cache_hits'] <= 0 or cache['cache_misses'] or cache['compiler_invocations']):
        raise ValueError('Warm run did not completely reuse compiled code')
    if mode == 'libjs-cold' and (cache['cache_hits'] or cache['compiled_executables'] <= 0 or cache['compiler_invocations'] <= 0):
        raise ValueError('Cold seed did not fill an empty native cache')
    if not diagnostic and any(visit['activity'].values()):
        raise ValueError('Native instrumentation was enabled in a timed run')
    if diagnostic and mode == 'libjs-warm' and visit['activity']['entries'] <= 0:
        raise ValueError('Cached native code did not execute')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--v8-binary', required=True, type=Path)
    parser.add_argument('--jsc-binary', required=True, type=Path)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--native-cache', required=True, type=Path)
    parser.add_argument('--skip-seed', action='store_true', help='Use a previously filled, pinned native cache')
    parser.add_argument('--memory', action='store_true', help='Separate root-process high-water RSS cohort')
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('--cycles', type=int, default=100)
    parser.add_argument('--timeout', type=float, default=180)
    args = parser.parse_args()
    if args.pairs < 7 or args.cycles < 1 or args.timeout <= 0:
        parser.error('Use at least seven groups and positive cycles/timeout')
    output, archive, cache = args.output.resolve(), args.archive.resolve(), args.native_cache.resolve()
    output.mkdir(parents=True, exist_ok=False)
    if not args.skip_seed and cache.exists():
        parser.error('Cold seed requires a new native-cache directory')
    binaries = {'v8': args.v8_binary.resolve(), 'jsc': args.jsc_binary.resolve(),
                'libjs-warm': args.jsc_binary.resolve(), 'libjs-cold': args.jsc_binary.resolve()}
    report = dict(scope='Recovered original Reddit listing scripts plus representative two-comment/menu probe; '
                  'HTML/runtime/script initialization, first measured cycle, repeated native click dispatch and DOM synchronization, '
                  'explicit cache finish. Sum of intervals excludes process startup, file hashing, audits, teardown, external network, '
                  'window, layout and paint. Fixture self-probe calls the handlers once during initialization.',
                  policy='Fresh process/profile/HTTP cache each trial; retained OS caches; warm LibJS retains native libraries only '
                  'and uses compiler /usr/bin/false. Native engines retain their existing compact DOM bridge; LibJS uses native bindings.',
                  memory=args.memory, cycles=args.cycles, pairs=args.pairs, host_before=host(), attempts=[], inputs={}, builds={})
    env_base = {k: v for k, v in os.environ.items()
                if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_', 'VFLAGS')) and 'proxy' not in k.lower()}
    replay = Replay(archive, output / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    env_base.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
    report['replay'] = replay.ready

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    def verify():
        changed = [p for p, sha in report['inputs'].items() if not Path(p).is_file() or digest(p) != sha]
        if changed:
            raise RuntimeError('Pinned inputs changed: ' + str(changed))

    def run(mode, label, diagnostic=False, cycles=None):
        verify()
        count = cycles or args.cycles
        env = dict(env_base, VOX_REDDIT_ENGINE_BENCHMARK=mode, VOX_REDDIT_ENGINE_CYCLES=str(count),
                   VOX_REDDIT_ENGINE_ARCHIVE=str(archive), VOX_REDDIT_ENGINE_DIAGNOSTIC=str(int(diagnostic)),
                   VOX_REDDIT_ENGINE_MEMORY=str(int(args.memory)), VOX_LIBJS_NATIVE_CACHE=str(cache),
                   VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(output / (label + '-profile')),
                   LADYBIRD_CACHE_DIR=str(output / (label + '-http-cache')))
        if mode == 'libjs-warm':
            env['VOX_LIBJS_NATIVE_COMPILER'] = '/usr/bin/false'
        if mode == 'v8' and diagnostic:
            env['VOX_V8_DIAGNOSTICS'] = '1'
        measurement = output / (label + '-process.json')
        command = [sys.executable, str(Path(__file__).resolve()), '--measure-child', str(measurement), str(binaries[mode])]
        attempt = dict(mode=mode, label=label, diagnostic=diagnostic, command=command, host_before=host(),
                       environment={k:v for k,v in env.items() if k.startswith(('VOX_', 'LADYBIRD_')) or k=='SSL_CERT_FILE'})
        report['attempts'].append(attempt)
        save()
        try:
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                stdout, stderr = process.communicate(timeout=900 if mode=='libjs-cold' else args.timeout)
            except subprocess.TimeoutExpired:
                if measurement.exists():
                    child = json.loads(measurement.read_text())
                    os.killpg(child['pid'], signal.SIGKILL)
                stdout, stderr = process.communicate(timeout=10)
                attempt['timeout'] = True
            attempt.update(exit=process.returncode, stdout=stdout, stderr=stderr)
            attempt['process'] = json.loads(measurement.read_text())
            if process.returncode or attempt.get('timeout') or attempt['process']['exit']:
                raise RuntimeError('Benchmark process failed')
            visits = [json.loads(line) for line in stdout.splitlines() if line.startswith('{')]
            if len(visits) != 1:
                raise ValueError('Expected exactly one visit')
            visit = visits[0]
            attempt['visit'] = visit
            validate(visit, mode, count, report['inputs'][str(archive / 'manifest.json')], diagnostic, args.memory)
            if diagnostic and mode=='v8' and 'Vox V8 backend: V8 ' not in stderr:
                raise ValueError('Missing actual V8 backend diagnostic')
            verify()
            print(label + ': ' + ', '.join(f'{key}={visit[key]:.3f}' for key in ['initialization_ms','callback_ms','compile_finish_ms']), flush=True)
            return visit
        except Exception as error:
            attempt['error'] = str(error)
            print(label + ': FAILED ' + str(error), flush=True)
            return None
        finally:
            attempt['host_after'] = host()
            save()

    try:
        with canonical_bundle_lease(ROOT / 'Build/v/Vox.app'):
            paths = [Path(__file__).resolve(), ROOT/'sites/reddit_engine_benchmark_test.v', ROOT/'tools/page_archive.py',
                     ROOT/'tools/benchmark_hn_engines.py', archive/'manifest.json', *sorted((archive/'bodies').iterdir()),
                     Path(replay.ready['ca'])]
            configurations = []
            for engine in ['v8','jsc']:
                binary = binaries[engine]
                receipts, build = build_receipts(binary)
                if not build:
                    raise ValueError('Missing sealed benchmark build')
                parsed = json.loads(next(p for p in receipts if p.name=='source-manifest.json').read_text())
                benchmark_source = ROOT/'sites/reddit_engine_benchmark_test.v'
                if parsed.get(str(benchmark_source)) != digest(benchmark_source):
                    raise ValueError('Executable does not contain the current benchmark source')
                report['builds'][engine] = build
                configuration = build['configuration']
                configurations.append({k:configuration[k] for k in ['allocator','optimization','inline_threshold','c_mode']})
                paths.extend([binary,*receipts,*runtime_input_paths(binary,env_base)])
                imports = subprocess.check_output(['nm','-m','-u',str(binary)],text=True)
                origin = 'libVoxJSCOnV8' if engine=='v8' else 'JavaScriptCore'
                for symbol in ['_JSGlobalContextCreate','_JSEvaluateScript']:
                    if not any(symbol+' ' in line and '(from '+origin+')' in line for line in imports.splitlines()):
                        raise ValueError('Wrong native engine linkage')
            if configurations[0] != configurations[1]:
                raise ValueError('Mismatched allocator/C compilation configurations')
            report['macos_version'] = subprocess.check_output(['sw_vers'], text=True)
            # Include the actual adapter and its libnode dependency, plus the
            # shared native helpers loaded by the browser host. System images
            # residing only in dyld's cache are identified by the OS receipt.
            images = [binaries['jsc'], binaries['v8'], binaries['v8'].parent/'libVoxJSCOnV8.dylib',
                      *sorted((ROOT/'Build/v').glob('*.dylib'))]
            report['linked_libraries'] = {}
            while images:
                image = images.pop().resolve()
                if str(image) in report['linked_libraries']:
                    continue
                paths.append(image)
                linked = subprocess.check_output(['otool','-L',str(image)],text=True)
                report['linked_libraries'][str(image)] = linked
                for line in linked.splitlines()[1:]:
                    dependency = Path(line.strip().split(' (',1)[0])
                    if dependency.is_absolute() and dependency.is_file():
                        images.append(dependency)
            report['inputs'] = {str(p):digest(p) for p in dict.fromkeys(paths)}
            save()
            if not args.skip_seed and not run('libjs-cold','cold-seed'):
                raise ValueError('Cold seed failed; no timing cohort collected')
            libraries = sorted(cache.rglob('*.dylib'))
            if not libraries:
                raise ValueError('Missing seeded native libraries')
            report['inputs'].update({str(p):digest(p) for p in cache.rglob('*') if p.is_file()})
            save()
            for engine in ['v8','jsc','libjs-warm']:
                if not run(engine,engine+'-diagnostic',diagnostic=True,cycles=3):
                    raise ValueError('Engine eligibility/correctness diagnostic failed')
            for group in range(args.pairs):
                order = ['v8','jsc','libjs-warm']
                if group % 2:
                    order.reverse()
                for engine in order:
                    run(engine,f'group-{group+1}-{engine}')
            timed = [a for a in report['attempts'] if a['label'].startswith('group-')]
            report['complete'] = len(timed)==3*args.pairs and all('visit' in a and 'error' not in a for a in timed)
            if report['complete']:
                report['summary'] = {}
                for engine in ['v8','jsc','libjs-warm']:
                    visits = [a['visit'] for a in timed if a['mode']==engine]
                    report['summary'][engine] = {key:dict(median=statistics.median(v[key] for v in visits),
                        minimum=min(v[key] for v in visits),maximum=max(v[key] for v in visits))
                        for key in [*METRICS,'callback_thread_cpu_ns','self_peak_rss_bytes']}
            verify()
    except Exception as error:
        report.update(error=str(error),complete=False)
    finally:
        report['host_after'] = host()
        save()
        replay.server.shutdown()
        replay.server.server_close()
    return 0 if report.get('complete') else 1


if __name__ == '__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--measure-child':
        raise SystemExit(measure_child(sys.argv[2],sys.argv[3:]))
    raise SystemExit(main())
