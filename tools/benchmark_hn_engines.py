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
import signal
from pathlib import Path
import statistics
import sys
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


def build_receipts(binary):
    """Pin sealed build provenance; runtime trials do not consume live V sources."""
    binary = Path(binary).resolve()
    directory = binary.with_name(binary.name + '.build')
    if not directory.is_dir():
        return [], None
    files = [directory / name for name in ['configuration.json', 'source-manifest.json', 'frozen-compile.json']]
    configuration, sources, frozen = [json.loads(path.read_text()) for path in files]
    command = frozen.get('compiler_command', [])
    if (frozen.get('complete') is not True or frozen.get('compiler_exit') != 0
            or '-o' not in command or command[command.index('-o') + 1:command.index('-o') + 2] != [str(binary)]
            or not sources):
        raise ValueError('Missing or inconsistent sealed build: ' + str(binary))
    return files, dict(configuration=configuration, source_inputs=frozen['source_inputs'])


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


def validate(visits, engine, cycles, diagnostic, pins, callback_cpu=False):
    expected = {'v8': ['v8'], 'jsc': ['jsc'], 'libjs': ['libjs-cold', 'libjs-process-warm'],
                'libjs-warm': ['libjs-warm']}[engine]
    if [v['mode'] for v in visits] != expected:
        raise ValueError('Missing or unexpected visit receipts')
    for visit in visits:
        # A diagnostic builtin profile must never enter a timing cohort.
        if not diagnostic and visit.get('builtin_profile'):
            raise ValueError('Builtin profiling enabled in timed visit')
        if (visit['rows'] != 101 or not visit['collapse_verified']
                or not visit['classes_restored'] or visit['cycles'] != cycles
                or visit['native_context'] != (engine in ['v8', 'jsc'])
                or visit['script_sha256'] != pins[str(SCRIPT)]
                or visit['page_sha256'] != pins[str(PAGE)]):
            raise ValueError('Engine, fixture, cancellation or DOM audit failed')
        if any(not math.isfinite(visit[key]) or visit[key] < 0 for key in METRICS):
            raise ValueError('Invalid timing')
        cpu_ns = visit.get('callback_thread_cpu_ns', 0)
        if (type(cpu_ns) is not int or cpu_ns < 0
                or (callback_cpu and (cpu_ns <= 0 or cpu_ns > round(visit['callback_ms'] * 1e6) + 10000000))
                or (not callback_cpu and cpu_ns != 0)):
            raise ValueError('Invalid or unexpectedly enabled callback thread CPU clock')
        if visit['cache']['last_error'] or visit['cache']['invalid_entries']:
            raise ValueError('Native cache failed')
        if not diagnostic and any(visit.get(k, 0) for k in ['borrowed_arguments', 'short_string_hits', 'direct_property_reads', 'fresh_arrays_initialized', 'class_collection_hits', 'direct_collection_walks']):
            raise ValueError('Argument storage counters enabled during timing')
        if not diagnostic and any(visit['activity'].values()):
            raise ValueError('Diagnostic counters enabled in timed visit')
        for counter in ['property_key_activity', 'fragment_text_activity', 'lookup_activity', 'argument_activity', 'builtin_key_activity', 'context_activity',
                        'primitive_activity', 'validation_activity', 'empty_scope_activity', 'index_key_activity', 'context_reuse_activity']:
            if not diagnostic and any(visit.get(counter, {}).values()):
                raise ValueError('Diagnostic counters enabled in timed visit: ' + counter)
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


def measure_child(report_path, command):
    """Wait for one directly launched benchmark; no polling in timed regions."""
    report_path = Path(report_path)
    process = subprocess.Popen(command, cwd=ROOT, start_new_session=True)
    report = dict(pid=process.pid, command=command, new_session=True,
                  metric='wait4 peak including the largest reaped descendant; not aggregate tree RSS; cold/same-process warm share one process')
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    _, status, usage = os.wait4(process.pid, 0)
    process.returncode = os.waitstatus_to_exitcode(status)
    report.update(exit=process.returncode,
                  peak_rss_bytes=int(usage.ru_maxrss) * (1 if sys.platform == 'darwin' else 1024),
                  process_cpu_ns=round((usage.ru_utime + usage.ru_stime) * 1e9),
                  cpu_scope='wait4 user+system time, including reaped descendant accounting')
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    return process.returncode if process.returncode >= 0 else 128 - process.returncode


def validate_memory(report, command):
    if (report.get('command') != command or report.get('exit') != 0
            or type(report.get('pid')) is not int or report['pid'] <= 0
            or type(report.get('peak_rss_bytes')) is not int or report['peak_rss_bytes'] <= 0
            or type(report.get('process_cpu_ns')) is not int or report['process_cpu_ns'] <= 0):
        raise ValueError('Missing or invalid per-process memory receipt')


def validate_visit_memory(visits, process, required):
    values = [v.get('self_peak_rss_bytes', 0) for v in visits]
    if not required:
        if any(values):
            raise ValueError('Memory probe enabled in timing cohort')
        return
    if (any(type(v) is not int or v <= 0 or v > process['peak_rss_bytes'] for v in values)
            or any(b < a for a, b in zip(values, values[1:]))):
        raise ValueError('Missing or inconsistent root-process memory checkpoint')


def evaluate_memory_target(summary, percent):
    """Compare both compiled warm peaks with the lowest V8 process peak."""
    if type(percent) is not int or not 1 <= percent <= 100:
        raise ValueError('Use a whole percentage between 1 and 100')
    warm = max(summary[mode]['max'] for mode in ['libjs-warm', 'libjs-process-warm'])
    v8 = summary['v8']['min']
    if any(type(value) is not int or value <= 0 for value in [warm, v8]):
        raise ValueError('Invalid peak resident byte counts')
    return dict(target_percent=percent, warm_max_bytes=warm, v8_min_bytes=v8,
                passed=100 * warm <= percent * v8,
                scope='highest root-process peak of both compiled warm modes / lowest V8 root-process peak')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--memory', action='store_true', help='Separate memory cohort: record root RUSAGE_SELF high-water RSS at each visit checkpoint')
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--target-v8-speedup', type=int, default=3)
    parser.add_argument('--target-v8-memory-percent', type=int,
                        help='Require both compiled warm peaks at or below this integer percentage of V8; --memory only')
    parser.add_argument('--v8-binary', type=Path, help='Optional pinned V8 control executable with matching C mode')
    parser.add_argument('--jsc-binary', type=Path, help='Matching C-mode build linked to system JavaScriptCore')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('--cycles', type=int, default=100)
    parser.add_argument('--timeout', type=float, default=120)
    args = parser.parse_args()
    if args.pairs < 7 or args.cycles < 1 or args.timeout <= 0 or args.target_v8_speedup < 1:
        parser.error('Use at least seven pairs, positive cycles and timeout')
    if args.target_v8_memory_percent is not None and (not args.memory or not 1 <= args.target_v8_memory_percent <= 100):
        parser.error('--target-v8-memory-percent requires --memory and a percentage from 1 to 100')
    output, binary = args.output.resolve(), args.binary.resolve()
    output.mkdir(parents=True, exist_ok=False)
    jsc_binary = args.jsc_binary.resolve() if args.jsc_binary else None
    v8_binary = args.v8_binary.resolve() if args.v8_binary else binary
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
                   VOX_HN_ENGINE_MEMORY=str(int(args.memory)),
                   VOX_LIBJS_NATIVE_CACHE=str(output / ((cache_label or label) + '-cache')),
                   LADYBIRD_CACHE_DIR=str(output / (label + '-http-cache')),
                   VOX_PROFILE_DIR=str(output / (label + '-profile')),
                   VOX_TEST_WINDOW='1')
        if diagnostic and engine == 'v8':
            env['VOX_V8_DIAGNOSTICS'] = '1'
        attempt = dict(label=label, engine=engine, diagnostic=diagnostic,
                       command=[str(jsc_binary if engine == 'jsc' else v8_binary if engine == 'v8' else binary)], environment={k: v for k, v in env.items()
                                                        if k.startswith(('VOX_', 'LADYBIRD_')) or k == 'SSL_CERT_FILE'}, host_before=host())
        report['attempts'].append(attempt)
        save()
        began = time.monotonic_ns()
        try:
            memory_report = output / (label + '-process.json')
            attempt['measurement_command'] = [sys.executable, str(Path(__file__).resolve()), '--measure-child', str(memory_report), *attempt['command']]
            process = subprocess.Popen(attempt['measurement_command'], cwd=ROOT, env=env, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            attempt['measurement_pid'] = process.pid
            save()
            try:
                stdout, stderr = process.communicate(timeout=args.timeout)
            except subprocess.TimeoutExpired:
                # Kill the measured task and compiler descendants together; keep
                # the waiter alive so it can retain the actual task exit/rusage.
                child = json.loads(memory_report.read_text()) if memory_report.exists() else None
                if child:
                    try:
                        os.killpg(child['pid'], signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                else:
                    process.terminate()
                try:
                    stdout, stderr = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    if child:
                        try:
                            os.killpg(child['pid'], signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    process.kill()
                    stdout, stderr = process.communicate()
                attempt.update(timeout=True, exit=process.returncode, stdout=stdout, stderr=stderr)
                if memory_report.exists():
                    attempt['process'] = json.loads(memory_report.read_text())
                raise
            attempt.update(exit=process.returncode, stdout=stdout, stderr=stderr)
            if process.returncode:
                raise RuntimeError(f'{label} exited {process.returncode}')
            attempt['process'] = json.loads(memory_report.read_text())
            validate_memory(attempt['process'], attempt['command'])
            attempt['pid'] = attempt['process']['pid']
            visits = [json.loads(line) for line in stdout.splitlines() if line.startswith('{')]
            attempt['visits'] = visits
            validate(visits, engine, args.cycles, diagnostic, report['inputs'])
            validate_visit_memory(visits, attempt['process'], args.memory)
            if diagnostic and engine == 'v8' and 'Vox V8 backend: V8 ' not in stderr:
                raise ValueError('Missing V8 backend diagnostic')
            cache = Path(env['VOX_LIBJS_NATIVE_CACHE'])
            attempt['native_libraries'] = {str(p): digest(p) for p in cache.rglob('*.dylib')}
            if engine not in ['v8', 'jsc'] and not attempt['native_libraries']:
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
            report['frozen_builds'] = {}
            for built_image in dict.fromkeys([binary, v8_binary] + ([jsc_binary] if jsc_binary else [])):
                receipts, metadata = build_receipts(built_image)
                paths.extend(receipts)
                if metadata is not None:
                    report['frozen_builds'][str(built_image)] = metadata
            if v8_binary != binary:
                paths.append(v8_binary)
                control_imports = subprocess.check_output(['nm', '-m', '-u', str(v8_binary)], text=True)
                for symbol in ['_JSGlobalContextCreate', '_JSEvaluateScript']:
                    if not any(symbol + ' ' in line and '(from libVoxJSCOnV8)' in line for line in control_imports.splitlines()):
                        raise ValueError('Control executable must bind V8: ' + symbol)
                report['v8_control_imports'] = control_imports
            report['v8_executable'] = str(v8_binary)
            if jsc_binary:
                paths.append(jsc_binary)
                imports_jsc = subprocess.check_output(['nm', '-m', '-u', str(jsc_binary)], text=True)
                for symbol in ['_JSGlobalContextCreate', '_JSEvaluateScript']:
                    if not any(symbol + ' ' in line and '(from JavaScriptCore)' in line for line in imports_jsc.splitlines()):
                        raise ValueError('JSC executable must bind JavaScriptCore: ' + symbol)
                report['jsc_imports'] = imports_jsc
                report['macos_version'] = subprocess.check_output(['sw_vers'], text=True)
            for image in [binary, binary.parent / 'libVoxJSCOnV8.dylib'] + ([jsc_binary] if jsc_binary else []) + ([v8_binary] if v8_binary != binary else []):
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
            if jsc_binary:
                run('jsc', 'diagnostic-jsc', True)
            run('v8', 'diagnostic-v8', True)
            run('libjs', 'diagnostic-libjs', True)
            run('libjs-warm', 'diagnostic-libjs-warm', True, 'diagnostic-libjs')
            for index in range(args.pairs):
                order = ['v8', 'libjs'] if index % 2 == 0 else ['libjs', 'v8']
                if jsc_binary:
                    order.insert(0 if index % 2 else len(order), 'jsc')
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
                for mode in ['v8', 'libjs-cold', 'libjs-warm', 'libjs-process-warm'] + (['jsc'] if jsc_binary else [])}
            warm_ns = max(round(v['callback_ms'] * 1e6) for v in visits if v['mode'] == 'libjs-warm')
            v8_ns = min(round(v['callback_ms'] * 1e6) for v in visits if v['mode'] == 'v8')
            report['wait4_peak_summary'] = {mode: dict(
                median=statistics.median(a['process']['peak_rss_bytes'] for a in report['attempts']
                    if not a['diagnostic'] and any(v['mode'] == mode for v in a['visits'])),
                min=min(a['process']['peak_rss_bytes'] for a in report['attempts']
                    if not a['diagnostic'] and any(v['mode'] == mode for v in a['visits'])),
                max=max(a['process']['peak_rss_bytes'] for a in report['attempts']
                    if not a['diagnostic'] and any(v['mode'] == mode for v in a['visits'])))
                for mode in report['summary']}
            report['wait4_peak_scope'] = ('Kernel wait4 peak RSS (bytes), including largest reaped descendant, through exit; '
                'cold and same-process warm share one peak for their two-visit process; '
                'may include compiler peak; excludes replay/measurement wrapper; not aggregate tree RAM')
            report['memory_instrumented'] = args.memory
            if args.memory:
                report['memory_summary'] = {mode: dict(median=statistics.median(v['self_peak_rss_bytes'] for v in visits if v['mode'] == mode), min=min(v['self_peak_rss_bytes'] for v in visits if v['mode'] == mode), max=max(v['self_peak_rss_bytes'] for v in visits if v['mode'] == mode)) for mode in report['summary']}
                report['memory_scope'] = 'RUSAGE_SELF peak resident bytes, process startup through each visit checkpoint after cache finish and before final audits; compiler/replay/wrapper excluded; same-process warm retains cold history'
                if args.target_v8_memory_percent is not None:
                    report['memory_target'] = evaluate_memory_target(report['memory_summary'], args.target_v8_memory_percent)
            report['target_v8_speedup'] = args.target_v8_speedup
            report['target_v8_passed'] = not args.memory and args.target_v8_speedup * warm_ns <= v8_ns
            report['verified'] = True
            load_archive(ARCHIVE)
            print(json.dumps(report['summary'], indent=2))
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        report['host_after'] = host()
        save()


if __name__ == '__main__':
    if len(sys.argv) > 3 and sys.argv[1] == '--measure-child':
        raise SystemExit(measure_child(sys.argv[2], sys.argv[3:]))
    main()
