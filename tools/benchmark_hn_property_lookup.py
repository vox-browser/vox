#!/usr/bin/env python3
"""Same-executable alternating HN runtime controls, candidates and V8.

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
    parser.add_argument('--control-binary', type=Path, help='Matched older C build for the layout comparison')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--pairs', type=int, default=7)
    parser.add_argument('--cycles', type=int, default=500)
    parser.add_argument('--target-v8-speedup', type=int, default=2)
    parser.add_argument('--callback-thread-cpu', action='store_true',
                        help='Separate calling-thread CPU diagnostic; wall-time gate is unchanged')
    parser.add_argument('--optimization', choices=['property', 'arguments', 'combined', 'registers', 'keys', 'capacity', 'storage', 'dispatch', 'indices', 'frames', 'calls', 'reads', 'arrays', 'collections', 'walk', 'helpers', 'references', 'bindings', 'accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys', 'layout', 'frame-access', 'values', 'key-records'], default='property')
    args = parser.parse_args()
    if args.pairs < 7 or args.cycles < 1 or args.target_v8_speedup < 1:
        parser.error('Use at least seven pairs and positive cycle counts')
    if args.optimization in ['layout', 'frame-access', 'values', 'key-records', 'instruction-borrowing'] and not args.control_binary:
        parser.error('Cross-binary comparisons require --control-binary')
    separate_cache = bool(args.control_binary) or args.optimization in ['native-property', 'native-length', 'native-index', 'native-numeric-keys', 'native-primitives', 'registers', 'dispatch', 'layout', 'frame-access', 'values', 'key-records']
    binary, output = args.binary.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    replay = Replay(hn.ARCHIVE, output / 'replay')
    aliases = hn.add_image_aliases(replay)
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    shared_cache = output / 'native-cache'
    report_native_counts = {}
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'DYLD_', 'JSC_', 'GC_'))
                   and 'proxy' not in k.lower()}
    environment.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
    report = dict(scope='matching C-mode optimized test executables; HN native DOM, cached script initialization '
                       'and synchronous collapse/expand; excludes process startup, external network, '
                       'window, layout, paint and teardown; V8 includes local image host setup',
                  control='test-only switch disables successful property-position hints',
                  candidate='bounded live-key-validated successful property-position hints',
                  optimization=args.optimization,
                  attempts=[], inputs={}, replay=replay.ready, image_aliases=aliases,
                  host_before=hn.host())
    report['callback_thread_cpu'] = dict(enabled=args.callback_thread_cpu,
        scope='Calling thread during the existing callback span; excludes other threads and scheduling waits; wall-time target unchanged')
    report['control'] = {'property': 'linear property lookup; arguments elision disabled',
                         'arguments': 'property hints enabled; arguments elision disabled',
                         'combined': 'linear property lookup; arguments elision disabled',
                         'registers': 'property hints and arguments elision enabled; environment bindings',
                         'keys': 'property hints, arguments elision and register bindings; rebuild length keys',
                         'capacity': 'all prior runtime optimizations; rounded frame capacity',
                         'storage': 'property hints, arguments elision and register bindings; legacy keys/capacity',
                         'dispatch': 'all prior optimizations; primitive wrappers, full validation and empty block environments',
                         'indices': 'all prior optimizations; decimal/UTF16 array index keys',
                         'bindings': 'compact references; ordinary environment resolution',
                         'accessors': 'all prior optimizations; full ordinary accessor/data-write descriptors',
                         'forward': 'ordinary accessor dispatch; owning Function.prototype.call forwarding',
                         'search': 'forwarded call slices; separate array HasProperty and Get',
                         'forward-search': 'ordinary accessors; owning call forwarding and separate array reads',
                         'envs': 'forwarded calls and own array reads; new function environments',
                         'instruction-borrowing': 'all prior optimizations; copied dispatch instruction records',
                         'generated-strings': 'all prior optimizations; cloned split/join results',
                         'fragment-text': 'all LibJS optimizations; full HTML text fragment parser',
                         'call-workspaces': 'all prior optimizations and native callback reuse; heap argument buffers',
                         'global-bindings': 'all prior optimizations; reconstruct and hash global binding keys',
                         'native-primitives': 'all prior optimizations; VM string truthiness, typeof and nonnumeric equality',
                         'property-keys': 'all prior optimizations; generic ToPrimitive and ToString for property keys',
                         'native-numeric-keys': 'compiled indexed reads; generic numeric ToPropertyKey conversion',
                         'native-index': 'compiled property plans; VM numeric property reads',
                         'native-length': 'compiled property plans; VM length reads',
                         'native-property': 'all prior optimizations; generic operand decoding for property reads',
                         'entry-cache': 'all prior optimizations; repeated map lookups for native entry preparation and dispatch',
                         'references': 'shared dynamic handlers; materialized Reference records',
                         'helpers': 'shared dynamic handlers disabled',
                         'key-records': '16-byte values; wide property keys and owning name headers',
                         'values': 'all prior optimizations; 24-byte separate number/cell values',
                         'frame-access': 'shared native handlers; generic frame arrays and out-of-line slot checks',
                         'layout': 'all runtime optimizations; prior UTF16 record layout',
                         'walk': 'all prior optimizations; capturing collection traversal adapter',
                         'collections': 'all prior optimizations; new native class collection on every query',
                         'arrays': 'all prior optimizations; generic fresh array element definitions',
                         'reads': 'all prior optimizations; full descriptors and UTF16 conversion',
                         'calls': 'all prior optimizations; owning call argument arrays',
                         'frames': 'all prior optimizations; fresh synchronous frames'}[args.optimization]
    report['candidate'] = {'global-bindings': 'bounded content-and-live-key-validated own global data hints',
                           'native-primitives': 'native UTF16 truthiness, primitive typeof and equality; coercive fallback',
                           'property-keys': 'direct string/symbol property keys with generic coercion fallback',
                           'native-numeric-keys': 'direct canonical numeric keys with unchanged object dispatch',
                           'native-index': 'guarded native reads of live own indexed data cells',
                           'native-length': 'guarded native string and ordinary array length reads',
                           'native-property': 'compiled property operand plans with live runtime semantics',
                           'entry-cache': 'bounded tier-owned exact-executable native entry table',
                           'property': 'validated property hints; arguments elision disabled',
                           'arguments': 'property hints enabled; unobserved arguments elided',
                           'combined': 'validated property hints and unobserved arguments elided',
                           'registers': 'property hints and arguments elision enabled; scope-proven register bindings',
                           'keys': 'property hints, arguments elision and register bindings; reuse length keys',
                           'capacity': 'all prior runtime optimizations; exact frame capacity',
                           'storage': 'property hints, arguments elision and register bindings; cached keys/exact capacity',
                           'dispatch': 'all prior optimizations; direct primitive reads, validation reuse and empty block no-ops',
                           'indices': 'all prior optimizations; canonical numeric array index keys',
                           'bindings': 'compact references; skip empty concrete environments and read live own global data',
                           'accessors': 'live ordinary accessor dispatch and own data writes',
                           'forward': 'copying callees borrow Function.prototype.call frame tails',
                           'search': 'forwarded calls and combined live own array data reads',
                           'forward-search': 'borrowed call forwarding and combined live own array data reads',
                           'envs': 'reuse empty function environments with dynamic escape guards',
                           'instruction-borrowing': 'all prior optimizations; borrowed executable instruction records',
                           'generated-strings': 'bounded code-unit result reuse and exact join storage',
                           'fragment-text': 'all LibJS optimizations; validated plain HTML text fragments',
                           'call-workspaces': 'bounded synchronous call argument buffer reuse',
                           'references': 'shared dynamic handlers; direct object/environment reads',
                           'helpers': 'shared dynamic handlers enabled',
                           'key-records': '16-byte values; compact tagged keys and bounded binding-name reuse',
                           'values': 'all prior optimizations; 16-byte shared number/cell payload',
                           'frame-access': 'shared native handlers; checked typed frame access and inline slot validation',
                           'layout': 'all runtime optimizations; compact optional ASCII payload',
                           'walk': 'all prior optimizations; direct collection traversal',
                           'collections': 'all prior optimizations; bounded native live class collection reuse',
                           'arrays': 'all prior optimizations; direct fresh dense array storage',
                           'reads': 'all prior optimizations; direct data reads and cached short strings',
                           'calls': 'all prior optimizations; borrowed small concrete call arguments',
                           'frames': 'all prior optimizations; bounded reuse of unexposed synchronous frames'}[args.optimization]

    if args.control_binary and args.optimization == 'call-workspaces':
        report['control'] = 'previous sealed build; heap call arguments and native invocation records'
        report['candidate'] = 'bounded call arguments and synchronous native invocation record reuse'

    def save():
        (output / 'results.json').write_text(json.dumps(report, indent=2) + '\n')

    def verify():
        for path, sha in report['inputs'].items():
            if not Path(path).is_file() or hn.digest(path) != sha:
                raise RuntimeError('Pinned input changed: ' + path)

    def run(config, label, diagnostic=False, seed=False):
        verify()
        cache_key = config if separate_cache else 'shared'
        cache = output / ('native-cache-' + config) if separate_cache else shared_cache
        engine = 'libjs' if seed else 'v8' if config == 'v8' else 'libjs-warm'
        env = dict(environment, VOX_HN_ENGINE_BENCHMARK=engine,
                   VOX_HN_ENGINE_CYCLES=str(args.cycles), VOX_LIBJS_NATIVE_CACHE=str(cache),
                   VOX_LIBJS_LOOKUP_HINTS='0' if config == 'control' else '1',
                   VOX_HN_ENGINE_DIAGNOSTIC=str(int(diagnostic)),
                   VOX_LIBJS_REGISTER_BINDINGS='0', VOX_LIBJS_BUILTIN_KEYS='0',
                   VOX_LIBJS_EXACT_CONTEXT='0', VOX_LIBJS_PRIMITIVE_READS='0',
                   VOX_LIBJS_VALIDATION_CACHE='0', VOX_LIBJS_EMPTY_SCOPES='0', VOX_LIBJS_NUMERIC_KEYS='0', VOX_LIBJS_CONTEXT_REUSE='0',
                   VOX_PROFILE_DIR=str(output / (label + '-profile')),
                   LADYBIRD_CACHE_DIR=str(output / (label + '-http-cache')), VOX_TEST_WINDOW='1')
        env['VOX_LIBJS_NATIVE_NUMERIC_KEYS'] = '0' if args.optimization == 'native-numeric-keys' and config == 'control' else '1'
        env['VOX_LIBJS_NATIVE_INDICES'] = '0' if args.optimization == 'native-index' and config == 'control' else '1'
        env['VOX_LIBJS_NATIVE_LENGTHS'] = '0' if args.optimization == 'native-length' and config == 'control' else '1'
        env['VOX_HN_CALLBACK_CPU'] = '1' if args.callback_thread_cpu else '0'
        env['VOX_LIBJS_ARGUMENT_WORKSPACES'] = '0' if args.optimization == 'call-workspaces' and config == 'control' else '1'
        env['VOX_LIBJS_GLOBAL_BINDING_HINTS'] = '0' if args.optimization == 'global-bindings' and config == 'control' else '1'
        env['VOX_LIBJS_NATIVE_PRIMITIVES'] = '0' if args.optimization == 'native-primitives' and config == 'control' else '1'
        env['VOX_LIBJS_PRIMITIVE_PROPERTY_KEYS'] = '0' if args.optimization == 'property-keys' and config == 'control' else '1'
        env['VOX_LIBJS_NATIVE_PROPERTY_READS'] = '0' if args.optimization == 'native-property' and config == 'control' else '1'
        env['VOX_LIBJS_NATIVE_ENTRY_CACHE'] = '0' if args.optimization == 'entry-cache' and config == 'control' else '1'
        env['VOX_HTML_FRAGMENT_TEXT'] = '0' if args.optimization == 'fragment-text' and config == 'control' else '1'
        env['VOX_LIBJS_GENERATED_STRINGS'] = '0' if args.optimization == 'generated-strings' and config == 'control' else '1'
        env['VOX_LIBJS_FAST_BINDINGS'] = '1' if args.optimization in ['accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys'] or (args.optimization == 'bindings' and config != 'control') else '0'
        env['VOX_LIBJS_DIRECT_ACCESSORS'] = '1' if args.optimization in ['forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys'] or (args.optimization == 'accessors' and config != 'control') else '0'
        env['VOX_LIBJS_FORWARD_CALL_ARGUMENTS'] = '1' if args.optimization in ['search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys'] or (args.optimization in ['forward', 'forward-search'] and config != 'control') else '0'
        env['VOX_LIBJS_ARRAY_SEARCH_READS'] = '1' if args.optimization in ['envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys'] or (args.optimization in ['search', 'forward-search'] and config != 'control') else '0'
        env['VOX_LIBJS_REUSE_FUNCTION_ENVIRONMENTS'] = '1' if args.optimization in ['instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys'] or (args.optimization == 'envs' and config != 'control') else '0'
        env['VOX_LIBJS_COMPACT_REFERENCES'] = '0' if config == 'control' and args.optimization == 'references' else '1'
        env['VOX_LIBJS_NATIVE_DYNAMIC'] = '0' if config == 'control' and args.optimization == 'helpers' else '1'
        env['VOX_LIBJS_DIRECT_COLLECTION_WALK'] = '0'
        env['VOX_LIBJS_CLASS_QUERY_CACHE'] = '0'
        env['VOX_LIBJS_FRESH_ARRAYS'] = '0'
        env['VOX_LIBJS_SHORT_STRINGS'] = '0'
        env['VOX_LIBJS_DIRECT_READS'] = '0'
        env['VOX_LIBJS_BORROW_ARGUMENTS'] = '0'
        if args.optimization in ['frames', 'calls', 'reads', 'arrays', 'collections', 'walk', 'helpers', 'references', 'bindings', 'accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys', 'layout', 'frame-access', 'values', 'key-records']:
            for setting in ['LOOKUP_HINTS', 'ARGUMENT_ELISION', 'REGISTER_BINDINGS', 'BUILTIN_KEYS',
                            'EXACT_CONTEXT', 'PRIMITIVE_READS', 'VALIDATION_CACHE', 'EMPTY_SCOPES', 'NUMERIC_KEYS']:
                env['VOX_LIBJS_' + setting] = '1'
            env['VOX_LIBJS_CONTEXT_REUSE'] = '0' if config == 'control' and args.optimization == 'frames' else '1'
            env['VOX_LIBJS_SHORT_STRINGS'] = '0'
            env['VOX_LIBJS_DIRECT_READS'] = '0'
            if args.optimization in ['reads', 'arrays', 'collections', 'walk', 'helpers', 'references', 'bindings', 'accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys', 'layout', 'frame-access', 'values', 'key-records']:
                env['VOX_LIBJS_BORROW_ARGUMENTS'] = '1'
                env['VOX_LIBJS_SHORT_STRINGS'] = '0' if config == 'control' and args.optimization == 'reads' else '1'
                env['VOX_LIBJS_DIRECT_READS'] = '0' if config == 'control' and args.optimization == 'reads' else '1'
                if args.optimization in ['arrays', 'collections', 'walk', 'helpers', 'references', 'bindings', 'accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys', 'layout', 'frame-access', 'values', 'key-records']:
                    env['VOX_LIBJS_FRESH_ARRAYS'] = '0' if config == 'control' and args.optimization == 'arrays' else '1'
                if args.optimization in ['collections', 'walk', 'helpers', 'references', 'bindings', 'accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys', 'layout', 'frame-access', 'values', 'key-records']:
                    env['VOX_LIBJS_CLASS_QUERY_CACHE'] = '0' if config == 'control' and args.optimization == 'collections' else '1'
                if args.optimization in ['walk', 'helpers', 'references', 'bindings', 'accessors', 'forward', 'search', 'forward-search', 'envs', 'instruction-borrowing', 'generated-strings', 'fragment-text', 'call-workspaces', 'global-bindings', 'native-primitives', 'property-keys', 'entry-cache', 'native-property', 'native-length', 'native-index', 'native-numeric-keys', 'layout', 'frame-access', 'values', 'key-records']:
                    env['VOX_LIBJS_DIRECT_COLLECTION_WALK'] = '0' if config == 'control' and args.optimization == 'walk' else '1'
            if args.optimization == 'calls':
                env['VOX_LIBJS_BORROW_ARGUMENTS'] = '0' if config == 'control' else '1'
        elif args.optimization == 'indices':
            for setting in ['LOOKUP_HINTS', 'ARGUMENT_ELISION', 'REGISTER_BINDINGS', 'BUILTIN_KEYS',
                            'EXACT_CONTEXT', 'PRIMITIVE_READS', 'VALIDATION_CACHE', 'EMPTY_SCOPES']:
                env['VOX_LIBJS_' + setting] = '1'
            env['VOX_LIBJS_NUMERIC_KEYS'] = '0' if config == 'control' else '1'
        elif args.optimization == 'dispatch':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '1'
            env['VOX_LIBJS_REGISTER_BINDINGS'] = '1'
            env['VOX_LIBJS_BUILTIN_KEYS'] = '1'
            env['VOX_LIBJS_EXACT_CONTEXT'] = '1'
            env['VOX_LIBJS_PRIMITIVE_READS'] = '0' if config == 'control' else '1'
            env['VOX_LIBJS_VALIDATION_CACHE'] = '0' if config == 'control' else '1'
            env['VOX_LIBJS_EMPTY_SCOPES'] = '0' if config == 'control' else '1'
        elif args.optimization == 'storage':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '1'
            env['VOX_LIBJS_REGISTER_BINDINGS'] = '1'
            env['VOX_LIBJS_BUILTIN_KEYS'] = '0' if config == 'control' else '1'
            env['VOX_LIBJS_EXACT_CONTEXT'] = '0' if config == 'control' else '1'
        elif args.optimization == 'capacity':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '1'
            env['VOX_LIBJS_REGISTER_BINDINGS'] = '1'
            env['VOX_LIBJS_BUILTIN_KEYS'] = '1'
            env['VOX_LIBJS_EXACT_CONTEXT'] = '0' if config == 'control' else '1'
        elif args.optimization == 'keys':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '1'
            env['VOX_LIBJS_REGISTER_BINDINGS'] = '1'
            env['VOX_LIBJS_BUILTIN_KEYS'] = '0' if config == 'control' else '1'
        elif args.optimization == 'registers':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '1'
            env['VOX_LIBJS_REGISTER_BINDINGS'] = '0' if config == 'control' else '1'
        elif args.optimization == 'property':
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '0'
        elif args.optimization == 'arguments':
            env['VOX_LIBJS_LOOKUP_HINTS'] = '1'
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '0' if config == 'control' else '1'
        else:
            env['VOX_LIBJS_ARGUMENT_ELISION'] = '0' if config == 'control' else '1'
        attempt_policy = dict(property_hints=env['VOX_LIBJS_LOOKUP_HINTS'],
                              argument_elision=env['VOX_LIBJS_ARGUMENT_ELISION'],
                              register_bindings=env['VOX_LIBJS_REGISTER_BINDINGS'],
                              builtin_keys=env['VOX_LIBJS_BUILTIN_KEYS'],
                              exact_context=env['VOX_LIBJS_EXACT_CONTEXT'],
                              primitive_reads=env['VOX_LIBJS_PRIMITIVE_READS'],
                              validation_cache=env['VOX_LIBJS_VALIDATION_CACHE'],
                              empty_scopes=env['VOX_LIBJS_EMPTY_SCOPES'],
                              numeric_keys=env['VOX_LIBJS_NUMERIC_KEYS'],
                              context_reuse=env['VOX_LIBJS_CONTEXT_REUSE'])
        if diagnostic and config == 'v8':
            env['VOX_V8_DIAGNOSTICS'] = '1'
        attempt = dict(configuration=config, label=label, diagnostic=diagnostic, seed=seed,
                       policy=attempt_policy,
                       command=[str(args.control_binary.resolve() if config == 'control' and args.control_binary else binary)], environment={k: v for k, v in env.items()
                           if k.startswith(('VOX_', 'LADYBIRD_')) or k == 'SSL_CERT_FILE'},
                       host_before=hn.host())
        report['attempts'].append(attempt)
        save()
        started = time.monotonic_ns()
        try:
            process = subprocess.Popen(attempt['command'], cwd=hn.ROOT, env=env, text=True,
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
            hn.validate(visits, engine, args.cycles, diagnostic, report['inputs'], callback_cpu=args.callback_thread_cpu)
            for visit in visits:
                visit['callback_thread_cpu_ms'] = visit.get('callback_thread_cpu_ns', 0) / 1e6
            for visit in visits:
                activity = visit['lookup_activity']
                if not diagnostic and any(activity.values()):
                    raise ValueError('Lookup diagnostics enabled in timed trial')
                if diagnostic and config == 'candidate' and activity['hits'] <= 0:
                    raise ValueError('Candidate did not exercise property hints')
                if diagnostic and args.optimization == 'dispatch':
                    primitive, validation = visit['primitive_activity'], visit['validation_activity']
                    if config == 'candidate' and (primitive['direct'] <= 0 or primitive['boxed'] != 0
                                                  or validation['hits'] <= 0
                                                  or visit['empty_scope_activity']['elided'] <= 0):
                        raise ValueError('HN candidate did not exercise primitive reads and validation reuse')
                    if config == 'control' and (primitive['boxed'] <= 0 or primitive['direct'] != 0
                                                or validation['hits'] != 0
                                                or visit['empty_scope_activity']['elided'] != 0):
                        raise ValueError('HN dispatch control did not execute legacy paths')
                if diagnostic and args.optimization == 'indices':
                    index_activity = visit['index_key_activity']
                    if config == 'candidate' and (index_activity['numeric'] <= 0 or index_activity['strings'] != 0):
                        raise ValueError('HN did not exercise numeric keys without string fallback')
                    if config == 'control' and (index_activity['strings'] <= 0 or index_activity['numeric'] != 0):
                        raise ValueError('HN control did not construct decimal/UTF16 index keys')
                if diagnostic and config != 'v8' and args.optimization == 'instruction-borrowing':
                    if visit['activity'].get('function_environments_reused', 0) <= 0:
                        raise ValueError('Both instruction controls must retain environment reuse')
                if diagnostic and config != 'v8' and args.optimization == 'native-numeric-keys':
                    if (visit['activity'].get('native_numeric_key_reads', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Native numeric key conversion eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'native-index':
                    if (visit['activity'].get('native_index_steps', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Native own-index lowering eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'native-length':
                    if (visit['activity'].get('native_length_steps', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Native length lowering eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'native-property':
                    if (visit['activity'].get('specialized_property_steps', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Compiled property plan eligibility differs from requested mode')
                if diagnostic and config != 'v8' and args.optimization == 'entry-cache':
                    if (visit['activity'].get('entry_cache_hits', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Native entry cache eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'property-keys':
                    if (sum(visit.get('property_key_activity', {}).values()) > 0) != (config == 'candidate'):
                        raise ValueError('Primitive property key eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'global-bindings':
                    if (visit['activity'].get('global_binding_hint_hits', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Global binding hint eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'call-workspaces':
                    if (visit['activity'].get('argument_workspace_calls', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Call argument workspace eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'fragment-text':
                    if (visit.get('fragment_text_activity', {}).get('fast', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Plain fragment eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'generated-strings':
                    if (visit['activity'].get('generated_string_hits', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Generated string result cache eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'envs':
                    if (visit['activity'].get('function_environments_reused', 0) > 0) != (config == 'candidate'):
                        raise ValueError('Function environment reuse eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization in ['forward', 'search', 'forward-search']:
                    activity = visit['activity']
                    if args.optimization in ['forward', 'forward-search'] and ((activity.get('forwarded_call_slices', 0) > 0) != (config == 'candidate')):
                        raise ValueError('Forwarded call eligibility mismatch')
                    if args.optimization in ['search', 'forward-search'] and ((activity.get('direct_array_search_reads', 0) > 0) != (config == 'candidate')):
                        raise ValueError('Array search read eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'accessors':
                    used = visit['activity'].get('direct_accessor_gets', 0) > 0 and visit['activity'].get('direct_accessor_sets', 0) > 0
                    if used != (config == 'candidate'):
                        raise ValueError('Direct accessor eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'bindings':
                    used = visit['activity']['own_global_binding_reads'] > 0 and visit['activity']['empty_binding_environments_skipped'] > 0
                    if used != (config == 'candidate'):
                        raise ValueError('Fast binding read eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'references':
                    if (visit['activity']['compact_reference_reads'] > 0) != (config == 'candidate'):
                        raise ValueError('Compact reference read eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'helpers':
                    if (visit['activity']['direct_slow_steps'] > 0) != (config == 'candidate'):
                        raise ValueError('Native dynamic handler eligibility mismatch')
                if diagnostic and config != 'v8' and args.optimization == 'walk':
                    if (visit['direct_collection_walks'] > 0) != (config == 'candidate'):
                        raise ValueError('Direct collection traversal mismatch')
                if diagnostic and args.optimization == 'collections':
                    if (visit['class_collection_hits'] > 0) != (config == 'candidate'):
                        raise ValueError('Native live class collection reuse mismatch')
                if diagnostic and args.optimization == 'arrays':
                    if (visit['fresh_arrays_initialized'] > 0) != (config == 'candidate'):
                        raise ValueError('Fresh-array eligibility mismatch')
                if diagnostic and args.optimization == 'reads':
                    if (visit['short_string_hits'] > 0 and visit['direct_property_reads'] > 0) != (config == 'candidate'):
                        raise ValueError('Direct-read/string-cache eligibility mismatch')
                if diagnostic and args.optimization == 'calls':
                    if (visit['borrowed_arguments'] > 0) != (config == 'candidate'):
                        raise ValueError('Borrowed-argument path eligibility mismatch')
                if diagnostic and args.optimization == 'frames':
                    reuse = visit['context_reuse_activity']
                    if config == 'candidate' and reuse['reused'] <= 0:
                        raise ValueError('HN candidate did not reuse synchronous frames')
                    if config == 'control' and any(reuse.values()):
                        raise ValueError('HN control unexpectedly exercised context reuse')
                context_activity = visit['context_activity']
                if not diagnostic and any(context_activity.values()):
                    raise ValueError('Context allocation diagnostics enabled during timing')
                if diagnostic and config == 'candidate' and args.optimization in ['capacity', 'storage']:
                    if context_activity['frames'] <= 0 or context_activity['slots'] != context_activity['capacity']:
                        raise ValueError('HN callbacks did not exercise exact frame allocation')
                if diagnostic and config == 'control' and args.optimization in ['capacity', 'storage']:
                    if context_activity['capacity'] <= context_activity['slots']:
                        raise ValueError('HN control did not use rounded frame capacity')
                key_activity = visit['builtin_key_activity']
                if not diagnostic and any(key_activity.values()):
                    raise ValueError('Builtin-key diagnostics enabled during timing')
                if diagnostic and config == 'candidate' and args.optimization in ['keys', 'storage']:
                    if (key_activity['cached'] <= 0 or key_activity['ascii_compares'] <= 0
                            or key_activity['legacy'] != 0):
                        raise ValueError('HN callbacks did not exercise cached keys and ASCII comparisons')
                if diagnostic and config == 'control' and args.optimization in ['keys', 'storage']:
                    if (key_activity['legacy'] <= 0 or key_activity['cached'] != 0
                            or key_activity['ascii_compares'] != 0):
                        raise ValueError('Key-cache control did not execute legacy key construction')
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
                report_native_counts[cache_key] = visits[0]['cache']['compiled_executables']
                report['native_executables'] = report_native_counts.copy()
            elif config != 'v8' and visits[0]['cache']['cache_hits'] != report_native_counts[cache_key]:
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
                     hn.ROOT / 'sites/hacker_news_engine_benchmark_test.v',
                     hn.ROOT / 'sites/engine_callback_cpu.h',
                     hn.ROOT / 'tools/page_archive.py',
                     *sorted((hn.ROOT / 'Build/v').glob('*.dylib'))]
            report['frozen_builds'] = {}
            receipt_images = [binary] + ([args.control_binary.resolve()] if args.control_binary else [])
            for built_image in receipt_images:
                receipts, metadata = hn.build_receipts(built_image)
                if metadata is None:
                    raise ValueError('Use build_hn_engine_benchmark.py for sealed source provenance')
                paths.extend(receipts)
                report['frozen_builds'][str(built_image)] = metadata
            report['linked_libraries'] = {}
            if args.control_binary:
                paths.append(args.control_binary.resolve())
            for image in [binary, binary.parent / 'libVoxJSCOnV8.dylib'] + ([args.control_binary.resolve()] if args.control_binary else []):
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
            run('control', 'seed-control', seed=True)
            if separate_cache:
                run('candidate', 'seed-candidate', seed=True)
            for config in ['control', 'candidate', 'v8']:
                run(config, 'diagnostic-' + config, True)
            if args.optimization in ['registers', 'dispatch', 'native-primitives', 'native-property', 'native-length', 'native-index']:
                diagnostics = {a['configuration']: a['visits'][0]['activity']
                               for a in report['attempts'] if a['diagnostic']}
                control, candidate = diagnostics['control'], diagnostics['candidate']
                if (candidate['entries'] != control['entries']
                        or candidate['fast_steps'] <= control['fast_steps']
                        or candidate['slow_steps'] >= control['slow_steps']):
                    raise ValueError('Lowering did not replace helper steps with native steps')
                if args.optimization == 'native-index':
                    delta = candidate['fast_steps'] - control['fast_steps']
                    if (candidate['fast_steps'] + candidate['slow_steps'] != control['fast_steps'] + control['slow_steps']
                            or delta != candidate['native_index_steps']):
                        raise ValueError('Native index lowering changed total work or miscounted replaced steps')
                report['lowering_diagnostic'] = diagnostics
            if args.optimization in ['entry-cache', 'native-numeric-keys']:
                diagnostics = {a['configuration']: a['visits'][0]['activity']
                               for a in report['attempts'] if a['diagnostic']}
                if any(diagnostics['control'][key] != diagnostics['candidate'][key]
                       for key in ['entries', 'fast_steps', 'slow_steps', 'direct_slow_steps']):
                    raise ValueError('Native specialization changed executed instruction counts')
                report['entry_cache_diagnostic' if args.optimization == 'entry-cache' else 'native_numeric_key_diagnostic'] = diagnostics
            for index in range(args.pairs):
                order = ['control', 'candidate', 'v8'] if index % 2 == 0 else ['v8', 'candidate', 'control']
                for config in order:
                    run(config, f'pair-{index + 1}-{config}')
            trials = [a for a in report['attempts'] if not a['diagnostic'] and not a['seed']]
            report['summary'] = {config: {metric: dict(
                median=statistics.median(a['visits'][0][metric] for a in trials if a['configuration'] == config),
                min=min(a['visits'][0][metric] for a in trials if a['configuration'] == config),
                max=max(a['visits'][0][metric] for a in trials if a['configuration'] == config))
                for metric in hn.METRICS + (['callback_thread_cpu_ms'] if args.callback_thread_cpu else [])} for config in ['control', 'candidate', 'v8']}
            candidate_ns = int(round(report['summary']['candidate']['callback_ms']['max'] * 1e6))
            v8_ns = int(round(report['summary']['v8']['callback_ms']['min'] * 1e6))
            report['twice_v8_conservative'] = 2 * candidate_ns <= v8_ns
            report['target_v8_speedup'] = args.target_v8_speedup
            report['target_v8_passed'] = args.target_v8_speedup * candidate_ns <= v8_ns
            report['verified'] = True
            print(json.dumps(report['summary'], indent=2))
    finally:
        replay.server.shutdown()
        replay.server.server_close()
        report['host_after'] = hn.host()
        save()


if __name__ == '__main__':
    main()
