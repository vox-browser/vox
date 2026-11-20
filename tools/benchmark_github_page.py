#!/usr/bin/env python3
"""Observe frozen GitHub launch, hydration, PNG, audit and normal process exit.

JSC and LibJS use the same Vox executable. The optional `v8` engine runs a
private `-d vox_v8` Vox build (JavaScriptCore's C API on V8) given by
--v8-vox. Brave supplies a whole-browser V8 comparison, including its distinct
DOM/renderer and CDP setup/audit/shutdown.
Counters cover observed process trees from creation, including startup; they
are lower bounds and exclude GPU/external-service execution. This is not an
isolated JavaScript benchmark or an optimization acceptance gate.
PNG availability and browser exit are separate wall-time endpoints. Brave
includes CDP delivery and the harness's PNG write. Vox's file completion is
observed during exit polling, with scheduler and polling delay.
Run through run_memory_bounded with the same private PID registry.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import statistics
import struct
import subprocess
import threading
import time
import urllib.request
from types import SimpleNamespace

from browser_bundle_lease import canonical_bundle_lease
from check_pixel_equality import compare
from github_hydrated_render import (AuditCDP, SELECTORS, URL, certificate_spki,
                                    content, ready_selector, validate)
from hacker_news_browser_instructions import test_display
from libjs_browser_diagnostic import native_reuse_errors
from libjs_capture_native_compiler import CAPTURE_DIR, CLANG, captured_source
from libjs_pack_native_cache import SHA256, libraries_from_trace, read_records
import measure_browser_instructions as measurement
from measure_precise_scroll import runtime_input_paths
from measure_sealed_github_instructions import native_dependencies
from page_archive import Replay, load_archive
from process_instruction_counts import MacCounters, ProcessTreeCounter, CounterSampler
from run_memory_bounded import publish_adopted_processes

ROOT = Path(__file__).resolve().parents[1]
CAPTURE_COMPILER = ROOT / 'tools/libjs_capture_native_compiler.py'
PNG_END_CHUNK = b'\x00\x00\x00\x00IEND\xaeB`\x82'
RASTER_OPTIONS = ('DOCUMENT_P3 PNG_RENDER_DENSITY PNG_GPU_MIPS ANALYTIC_RECT '
    'DOCUMENT_IMAGE_P3 IMAGE_GAMUT_BEFORE_FILTER PRECISE_TRANSFORM_ORIGIN '
    'SCALED_PNG_SHADOW_GROUP GPU_RECTANGLE_CLIP RECTANGLE_CLIP_DEDUP '
    'GLYPH_RECTANGLE_CLIP GPU_THIN_RECTANGLE_CLIP PAINT_LAYER SCALED_PNG '
    'EXTENDED_GLYPH_COLOR EXTENDED_SHAPE_COLOR ROOT_CAPTURE_WIDTH '
    'DISJOINT_ROUNDED_BATCH SHADOWED_PNG_TEXT').split()


def digest(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def png_write_complete(path):
    try:
        with path.open('rb') as handle:
            if handle.seek(0, os.SEEK_END) < len(PNG_END_CHUNK):
                return False
            handle.seek(-len(PNG_END_CHUNK), os.SEEK_END)
            return handle.read(len(PNG_END_CHUNK)) == PNG_END_CHUNK
    except FileNotFoundError:
        return False


def check_capture_stability(row, previous_attempts, diff_tool):
    if not row['valid']:
        return
    baseline = next((sample for sample in previous_attempts
                     if sample['engine'] == row['engine'] and sample['valid']), None)
    if baseline is None:
        return
    folder = Path(row['folder'])
    row['stability_pixels'] = compare(Path(baseline['folder']) / 'document.png',
        folder / 'document.png', folder / 'stability-diff.png', diff_tool)
    if not row['stability_pixels']['exact']:
        row.update(valid=False, error='Rendered pixels changed within the same engine')


def clean_environment():
    return {k: v for k, v in os.environ.items()
            if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_'))
            and 'proxy' not in k.lower()}


def verify_replayed_scripts(replay, expected):
    if not expected:
        return {}
    fetched = {}
    for line in (replay.output / 'requests.jsonl').read_text().splitlines():
        request = json.loads(line)
        url = request.get('url')
        if url in expected and request.get('method') == 'GET' and request.get('archived'):
            fetched.setdefault(url, set()).add(request['sha256'])
    missing = [url for url, digest in expected.items() if fetched.get(url) != {digest}]
    if missing:
        raise RuntimeError('Compatibility scripts were not served by the common replay: ' + ', '.join(missing))
    return expected


def cache_errors(capture, shutdown, *, preparing, diagnostics, resuming=False):
    errors = []
    if any(not isinstance(receipt, dict) for receipt in (capture, shutdown)):
        return ['missing capture or shutdown cache receipt']
    if diagnostics and not preparing:
        errors.extend(native_reuse_errors(capture, shutdown))
    abis = set()
    for phase, receipt in [('capture', capture), ('shutdown', shutdown)]:
        native = receipt.get('native') or {}
        abis.add(native.get('abi'))
        if (receipt.get('engine') != 'libjs' or receipt.get('native_context_initialized') is not False
                or native.get('identity_kind') != 'generated-code' or not native.get('abi')
                or native.get('last_error') != '' or native.get('invalid_entries') != 0):
            errors.append(f'{phase}: unverified generated-code cache identity or cache failure')
        if preparing and phase == 'shutdown':
            compiled = native.get('compiled_executables', 0) > 0 and native.get('compiler_invocations', 0) > 0
            reused = resuming and native.get('cache_hits', 0) > 0
            if native.get('pending_executables') != 0 or not (compiled or reused):
                errors.append('shutdown: cache preparation incomplete')
        if not preparing and not diagnostics:
            for key in ('cache_misses', 'pending_executables', 'compiled_executables', 'compiler_invocations'):
                if native.get(key) != 0:
                    errors.append(f'{phase}: {key} must be zero')
            if native.get('cache_hits', 0) <= 0:
                errors.append(f'{phase}: cache hits must be positive')
    if len(abis) != 1:
        errors.append('native ABI changed between capture and shutdown')
    return errors


def verify_compiler_captures(directory, cache, abi):
    if not SHA256.fullmatch(abi):
        raise ValueError('Invalid captured cache ABI')
    source = cache / abi
    records, libraries, _ = read_records(source, abi)
    if not libraries:
        raise ValueError('Prepared cache contains no native libraries')
    batches = {}
    for name, sha in libraries.items():
        if digest(source / name) != sha:
            raise ValueError(f'Prepared library digest mismatch: {name}')
        code, source_sha = captured_source(directory, sha)
        if digest(code) != source_sha:
            raise ValueError(f'Captured C digest mismatch: {name}')
        batches[name] = dict(library_sha256=sha, source_sha256=source_sha)
    return dict(directory=str(directory), abi=abi, records=len(records), batches=batches)


def verify_native_library_trace(trace, cache, abi, pid):
    if not SHA256.fullmatch(abi):
        raise ValueError('Invalid traced cache ABI')
    source = cache / abi
    names, receipt = libraries_from_trace(trace, source, pid)
    _, libraries, _ = read_records(source, abi)
    unknown = set(names) - libraries.keys()
    if unknown:
        raise ValueError(f'Traced libraries lack cache records: {sorted(unknown)}')
    return dict(receipt, abi=abi, libraries=names)


def observe(args, engine, folder, expected, replayed_scripts, api):
    folder.mkdir()
    profile, cache = folder / 'profile', folder / 'http-cache'
    profile.mkdir()
    cache.mkdir()
    config, audit_path, png = folder / 'audit-config.json', folder / 'audit.json', folder / 'document.png'
    save(config, dict(selectors=SELECTORS, describe_native_errors=True))
    replay = Replay(args.archive, folder / 'replay')
    threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    env = clean_environment()
    env.update(VOX_PROFILE_DIR=str(profile), LADYBIRD_CACHE_DIR=str(cache), VOX_COOKIE_FILE='',
        VOX_TEST_WINDOW='1', VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'],
        VOX_CAPTURE_DOCUMENT_ONLY='1', VOX_CAPTURE_DOCUMENT_ACTIVE='1',
        VOX_CAPTURE_RENDER_DEVICE_PIXEL_RATIO='2', LADYBIRD_SCREENSHOT_SCALE='1',
        VOX_CAPTURE_AUDIT_CONFIG=str(config), VOX_CAPTURE_AUDIT_PATH=str(audit_path),
        VOX_CAPTURE_READY_SELECTOR=ready_selector(expected),
        LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.settle_seconds), VOX_LIBJS_FRONTEND_CACHE='on',
        VOX_LIBJS_NATIVE_COMPILER='/usr/bin/false', VOX_LIBJS_NATIVE_CACHE='0')
    if args.raster_parity_options:
        env.update({'VOX_DIAGNOSTIC_' + name: '1' for name in RASTER_OPTIONS})
    if args.adblock_assets and engine != 'brave':
        env['VOX_ADBLOCK_ENGINE_ASSETS'] = str(args.adblock_assets)
    if engine == 'v8':
        # Prints the V8 version at startup; its counters are kept regardless.
        env['VOX_V8_DIAGNOSTICS'] = '1'
    final_cache = folder / 'native-cache-final.json'
    if engine == 'libjs-native':
        env.update(VOX_LIBJS_NATIVE_CACHE=str(args.native_cache),
            VOX_LIBJS_NATIVE_GENERATED_CODE_CACHE='1', VOX_LIBJS_NATIVE_CACHE_FINAL_AUDIT_PATH=str(final_cache))
        # Visits verify that pinned cache files are unchanged, so the learned
        # lookup index stays frozen. Seed it by passing any other
        # VOX_LIBJS_NATIVE_LOOKUP_INDEX value (for example `learn`).
        env.setdefault('VOX_LIBJS_NATIVE_LOOKUP_INDEX', 'readonly')
        if args.prepare_native_cache:
            env['VOX_LIBJS_NATIVE_COMPILER'] = str(args.native_compiler)
            if args.native_captures:
                env[CAPTURE_DIR] = str(args.native_captures)
        if args.native_diagnostics:
            env['VOX_LIBJS_NATIVE_DIAGNOSTICS'] = '1'
        if args.trace_native_libraries:
            env['DYLD_PRINT_LIBRARIES'] = '1'
    row = dict(engine=engine, host_before=dict(unix=time.time(), cpu_count=os.cpu_count(), load=os.getloadavg()),
        http_cache_initial_entries=len(list(cache.iterdir())), imported_cookies='disabled',
        scope=__doc__, folder=str(folder),
        browser_overrides={key: value for key, value in env.items()
                           if (key.startswith(('VOX_', 'LADYBIRD_')) and key != 'VOX_PROXY')
                           or key == 'DYLD_PRINT_LIBRARIES'})
    client = process = None
    try:
        if engine == 'brave':
            x, y = args.position
            options = SimpleNamespace(width=1024, height=768, chrome_windowed=True,
                chrome_extra_arg=[f'--window-position={x},{y}', '--window-size=1024,900',
                    '--proxy-server=' + replay.ready['proxy'].replace('socks5h://', 'socks5://'),
                    '--ignore-certificate-errors-spki-list=' + certificate_spki(replay.ready['ca'])])
            command = measurement.chrome_launch_command(options, args.brave, profile)
        else:
            backend = 'libjs' if engine.startswith('libjs') else 'javascriptcore'
            executable = args.v8_vox if engine == 'v8' else args.vox
            command = [str(executable), '--enable-javascript', '--js-engine=' + backend,
                '--window-width', '1024', '--window-height', '880', '--screenshot-viewport-height', '768',
                '--screenshot', str(png), URL]
        row['command'] = command
        save(folder / 'launch.json', row)
        with (folder / 'browser.log').open('w') as log:
            launched = time.monotonic()
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            row['pid'] = process.pid
            publish_adopted_processes(args.memory_guard_registry, [process.pid])
            counter = ProcessTreeCounter(api, process.pid)
            deadline = launched + args.timeout
            with CounterSampler(counter, .005):
                if engine == 'brave':
                    port, _ = measurement.wait_for_chrome_debugger(profile / 'DevToolsActivePort',
                        counter, deadline, .005, folder / 'browser.log')
                    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
                    target = measurement.wait_for_chrome_page_target(opener, port, counter, deadline,
                        .005, folder / 'browser.log')
                    client = AuditCDP(target)
                    row['version'] = measurement.prepare_chrome_target(client, options)
                    client.call('Page.navigate', {'url': URL})
                    selector = json.dumps(ready_selector(expected))
                    expression = 'document.readyState==="complete"&&!!document.querySelector(' + selector + ')'
                    while client.call('Runtime.evaluate', {'expression': expression,
                                                          'returnByValue': True})['result'].get('value') is not True:
                        if time.monotonic() > deadline:
                            raise TimeoutError('GitHub hydration readiness timeout')
                        time.sleep(.02)
                    client.call('Runtime.evaluate', {'expression': 'document.fonts.ready.then(()=>true)',
                                                    'awaitPromise': True, 'returnByValue': True})
                    time.sleep(args.settle_seconds)
                    result = client.call('Page.captureScreenshot', {'format': 'png', 'captureBeyondViewport': False})
                    png.write_bytes(base64.b64decode(result['data']))
                    row['png_available_ms'] = (time.monotonic() - launched) * 1000
                    from github_hydrated_render import audit_expression
                    result = client.call('Runtime.evaluate', {'expression': 'JSON.stringify(' + audit_expression() + ')',
                                                            'returnByValue': True})
                    audit = json.loads(result['result']['value'])
                    audit['javascript_diagnostics'] = list(client.errors)
                    save(audit_path, audit)
                    try:
                        client.call('Browser.close')
                    except (EOFError, OSError):
                        pass
                    client.sock.close(); client = None
                while True:
                    if 'png_available_ms' not in row and png_write_complete(png):
                        row['png_available_ms'] = (time.monotonic() - launched) * 1000
                    readings = counter.sample()
                    root = readings.get(counter.root_identity)
                    if root and root.exited:
                        row.update(counter.report(snapshot=counter.snapshot_before(time.monotonic())))
                        break
                    if time.monotonic() > deadline:
                        raise TimeoutError('Browser process exit timeout')
                    time.sleep(.005)
                row['exit'] = process.wait()
                row['launch_through_exit_ms'] = (time.monotonic() - launched) * 1000
        if row['exit'] != 0:
            raise RuntimeError('Abnormal browser exit: ' + str(row['exit']))
        if 'png_available_ms' not in row:
            # The browser can write the PNG and exit between the file check
            # and the counter sample. Exit is a conservative observed endpoint.
            if not png_write_complete(png):
                raise RuntimeError('Browser exited before completing the document PNG')
            row['png_available_ms'] = row['launch_through_exit_ms']
            row['png_first_observed_at_exit'] = True
        row['post_png_ms'] = row['launch_through_exit_ms'] - row['png_available_ms']
        audit = json.loads(audit_path.read_text())
        validate(audit, expected)
        row['content_validated'] = True
        row['counts'] = {g['name']: g['count'] for g in audit['selections']}
        header = png.read_bytes()[:24]
        if header[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('!II', header[16:24]) != (1024, 768):
            raise RuntimeError('Invalid document PNG or viewport dimensions')
        row['pixels'] = compare(args.reference_png, png, folder / 'brave-diff.png', args.diff_tool)
        row['png_file_sha256'] = digest(png)
        if engine != 'brave':
            row['configured_javascript_engine'] = audit.get('configured_javascript_engine')
            row['javascript_runtime'] = audit.get('javascript_runtime')
            row['native_cache'] = audit.get('compiled_javascript_cache')
            runtime = row['javascript_runtime'] or {}
            backend = 'libjs' if engine.startswith('libjs') else 'javascriptcore'
            if (row['configured_javascript_engine'] != backend or runtime.get('engine') != backend
                    or runtime.get('native_context_initialized') is not (engine in ['jsc', 'v8'])):
                raise RuntimeError('Requested JavaScript engine execution is unverified')
            if engine == 'v8' and 'Vox V8 backend: V8 ' not in (folder / 'browser.log').read_text(errors='replace'):
                raise RuntimeError('Missing V8 backend diagnostic')
            if backend == 'libjs' and (runtime.get('libjs_execution_generation', 0) <= 0
                    or not runtime.get('modules') or any(m.get('status') != 'evaluated'
                    or m.get('promise_state') != 'fulfilled' for m in runtime['modules'])):
                raise RuntimeError('LibJS module execution is incomplete')
        if engine == 'libjs-native':
            row['native_cache_final'] = json.loads(final_cache.read_text())
            row['cache_errors'] = cache_errors(row['native_cache'], row['native_cache_final'],
                preparing=args.prepare_native_cache, diagnostics=args.native_diagnostics,
                resuming=args.resume_native_abi is not None)
            if row['cache_errors']:
                raise RuntimeError('Native cache was incomplete: ' + repr(row['cache_errors']))
            abi = row['native_cache_final']['native']['abi']
            if args.resume_native_abi is not None and abi != args.resume_native_abi:
                raise ValueError('Resumed native cache ABI changed')
            if args.native_captures:
                row['compiler_captures'] = verify_compiler_captures(args.native_captures, args.native_cache, abi)
        row['replayed_scripts'] = verify_replayed_scripts(replay, replayed_scripts)
        if engine == 'libjs-native' and args.trace_native_libraries:
            trace = folder / 'native-library-trace.log'
            shutil.copyfile(folder / 'browser.log', trace)
            row['native_library_trace'] = verify_native_library_trace(
                trace, args.native_cache, row['native_cache_final']['native']['abi'], row['pid'])
        row['valid'] = True
    except Exception as error:
        row.update(valid=False, error=str(error), browser_exit_if_known=process.returncode if process else None)
    finally:
        if client:
            client.sock.close()
        if process:
            measurement.stop_process(process)
            row['exit'] = process.returncode
        replay.server.shutdown()
        replay.server.server_close()
        row['host_after'] = dict(unix=time.time(), load=os.getloadavg())
        save(folder / 'result.json', row)
        shutil.rmtree(profile)
        shutil.rmtree(cache)
    return row


def run(args, *, bundle_lease=None, resume_native_abi=None):
    args.output = args.output.resolve(); args.archive = args.archive.resolve()
    args.vox = args.vox.resolve(); args.brave = args.brave.resolve()
    args.v8_vox = getattr(args, 'v8_vox', None)
    if 'v8' in args.engines:
        if args.v8_vox is None:
            raise ValueError('The v8 engine requires --v8-vox')
        args.v8_vox = args.v8_vox.resolve()
    if args.native_cache: args.native_cache = args.native_cache.resolve()
    if args.adblock_assets: args.adblock_assets = args.adblock_assets.resolve()
    args.trace_native_libraries = getattr(args, 'trace_native_libraries', False)
    if args.trace_native_libraries:
        args.native_diagnostics = True
    args.resume_native_abi = resume_native_abi
    resume_native_seed = resume_native_abi is not None
    if 'libjs-native' in args.engines and args.native_cache is None:
        raise ValueError('Native measurements require a separately prepared cache')
    if args.prepare_native_cache and args.native_cache.exists() and not resume_native_seed:
        raise ValueError('Native cache preparation requires a new cache directory')
    args.native_captures = getattr(args, 'native_captures', None)
    if resume_native_seed and (not args.prepare_native_cache or args.native_captures is None):
        raise ValueError('Resuming a native seed requires compiler captures')
    if args.native_captures is not None:
        args.native_captures = args.native_captures.resolve()
        if not args.prepare_native_cache:
            raise ValueError('Compiler captures require native cache preparation')
        if (args.native_captures.is_relative_to(args.native_cache)
                or args.native_cache.is_relative_to(args.native_captures)):
            raise ValueError('Use separate directories for compiler captures and the native cache')
        if (args.native_captures.exists() and not resume_native_seed) or args.native_captures == args.output:
            raise ValueError('Compiler captures require a new directory')
    args.output.mkdir(parents=True, exist_ok=False)
    args.position = test_display()['position']
    expected = content(json.loads(args.reference_audit.read_text()))
    manifest = load_archive(args.archive)
    if manifest['url'] != URL:
        raise ValueError('Expected the frozen vlang/v repository page')
    replayed_scripts = {item['url']: item['after'] for item in manifest.get('benchmark_compatibility', [])}
    for url, expected_digest in replayed_scripts.items():
        if manifest['responses'].get(url, {}).get('sha256') != expected_digest:
            raise ValueError('Compatibility script does not match archive: ' + url)
    report = dict(scope=__doc__, engines=args.engines, attempts=[], acceptance=False,
        prepare_native_cache=args.prepare_native_cache, native_diagnostics=args.native_diagnostics,
        replayed_scripts=replayed_scripts,
        policy='Frozen original-origin replay; fresh HTTP caches and profiles; OS caches retained; 1024x768 document; shared settle period.')
    if args.trace_native_libraries:
        report['trace_native_libraries'] = True
    if resume_native_seed:
        report['resume_native_seed'] = True
    api = MacCounters()
    with (bundle_lease or canonical_bundle_lease)(ROOT / 'Build/v/Vox.app'):
        asset_env = {'VOX_ADBLOCK_ENGINE_ASSETS': str(args.adblock_assets)} if args.adblock_assets else {}
        paths = [*native_dependencies(args.vox, args.vox.parent.glob('*.dylib')),
            *sorted((ROOT / 'Build/v').glob('*.dylib')), *runtime_input_paths(args.vox, asset_env),
            args.reference_audit, Path(__file__), args.archive / 'manifest.json',
            ROOT / 'tools/github_hydrated_render.py', ROOT / 'tools/measure_browser_instructions.py',
            ROOT / 'tools/libjs_browser_diagnostic.py',
            ROOT / 'tools/process_instruction_counts.py', ROOT / 'tools/page_archive.py',
            ROOT / 'tools/check_pixel_equality.py', args.reference_png, args.diff_tool]
        if 'brave' in args.engines:
            paths.extend(native_dependencies(args.brave))
        if 'v8' in args.engines:
            paths.extend(native_dependencies(args.v8_vox, args.v8_vox.parent.glob('*.dylib')))
        if args.prepare_native_cache:
            paths.append(args.native_compiler)
        if args.native_captures:
            paths.append(Path(CLANG))
        if args.native_captures or args.trace_native_libraries:
            paths.append(ROOT / 'tools/libjs_pack_native_cache.py')
        native_files = set(p for p in args.native_cache.rglob('*') if p.is_file()) if args.native_cache else set()
        paths.extend(sorted(native_files))
        pins = {str(p): digest(p) for p in paths}
        report['inputs'] = pins
        report['production_receipt'] = json.loads((ROOT / 'Build/production-build/latest.json').read_text())
        if args.native_captures:
            args.native_captures.mkdir(mode=0o700, parents=True, exist_ok=resume_native_seed)
            report['native_captures'] = str(args.native_captures)
        save(args.output / 'results.json', report)
        for pair in range(args.repeat):
            order = args.engines if pair % 2 == 0 else args.engines[::-1]
            for engine in order:
                if any(digest(p) != h for p, h in pins.items()):
                    raise RuntimeError('Pinned runtime inputs changed')
                load_archive(args.archive)
                row = observe(args, engine, args.output / f'{pair}-{engine}', expected, replayed_scripts, api)
                load_archive(args.archive)
                row['pair'] = pair
                row['changed_inputs'] = [p for p, h in pins.items() if not Path(p).is_file() or digest(p) != h]
                if args.native_cache and not args.prepare_native_cache:
                    row['new_cache_files'] = sorted(str(p) for p in args.native_cache.rglob('*')
                                                    if p.is_file() and p not in native_files)
                if row['changed_inputs'] or row.get('new_cache_files'):
                    row.update(valid=False, error='Pinned runtime inputs or native cache changed')
                check_capture_stability(row, report['attempts'], args.diff_tool)
                report['attempts'].append(row)
                save(args.output / 'results.json', report)
                print(json.dumps({k: row.get(k) for k in ['pair', 'engine', 'valid', 'error',
                    'instructions', 'png_available_ms', 'launch_through_exit_ms', 'root_lifetime_max_phys_footprint']}), flush=True)
        report['complete'] = all(r['valid'] for r in report['attempts'])
        report['medians'] = {}
        for engine in [] if args.prepare_native_cache or args.native_diagnostics else args.engines:
            rows = [r for r in report['attempts'] if r['engine'] == engine]
            if all(r['valid'] for r in rows):
                report['medians'][engine] = {k: statistics.median(r[k] for r in rows)
                    for k in ['instructions', 'png_available_ms', 'launch_through_exit_ms']}
        save(args.output / 'results.json', report)
    return 0 if report['complete'] else 1


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--archive', type=Path, required=True)
    p.add_argument('--reference-audit', type=Path, required=True)
    p.add_argument('--reference-png', type=Path, required=True)
    p.add_argument('--diff-tool', type=Path, default=ROOT / 'Build/pixel-tools/pixel_diff')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--memory-guard-registry', type=Path, required=True)
    p.add_argument('--engines', nargs='+', choices=['libjs', 'jsc', 'libjs-native', 'v8', 'brave'], default=['libjs', 'jsc', 'brave'])
    p.add_argument('--native-cache', type=Path)
    p.add_argument('--adblock-assets', type=Path,
                   help='Private Vox filter bundle for a fixture that serves compatibility scripts directly')
    p.add_argument('--prepare-native-cache', action='store_true',
                   help='Compile a new cache for the same fixture in a separate untimed seed')
    compiler = p.add_mutually_exclusive_group()
    compiler.add_argument('--native-compiler', type=Path,
                          help='Compiler for the preparation run (default /usr/bin/clang)')
    compiler.add_argument('--native-captures', type=Path,
                          help='Retain generated C and library receipts in a new directory while seeding')
    p.add_argument('--native-diagnostics', action='store_true',
                   help='Verify actual native execution with instrumented counters in an untimed reopen')
    p.add_argument('--trace-native-libraries', action='store_true',
                   help='Save a loader trace and identify its cache libraries in an untimed reopen')
    p.add_argument('--vox', type=Path, default=ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox')
    p.add_argument('--v8-vox', type=Path, help='Private -d vox_v8 Vox executable for the v8 engine')
    p.add_argument('--brave', type=Path, default=Path('/Applications/Brave Browser.app/Contents/MacOS/Brave Browser'))
    p.add_argument('--repeat', type=int, default=7)
    p.add_argument('--settle-seconds', type=float, default=1)
    p.add_argument('--timeout', type=float, default=180)
    p.add_argument('--raster-parity-options', action='store_true')
    args = p.parse_args()
    if args.repeat < 1 or not 0 <= args.settle_seconds < args.timeout:
        p.error('Require a positive repeat count and settle period below the timeout')
    if len(set(args.engines)) != len(args.engines):
        p.error('Each engine may appear only once')
    if ('v8' in args.engines) != (args.v8_vox is not None):
        p.error('The v8 engine and --v8-vox require each other')
    if args.trace_native_libraries and (args.prepare_native_cache or 'libjs-native' not in args.engines
                                        or args.native_cache is None):
        p.error('--trace-native-libraries requires a libjs-native reopen with --native-cache')
    if args.prepare_native_cache and (args.engines != ['libjs-native'] or args.repeat != 1
                                      or args.native_diagnostics or not args.native_cache):
        p.error('Preparation requires one libjs-native run, a new cache and native diagnostics disabled')
    if args.native_compiler and not args.prepare_native_cache:
        p.error('The compiler can only be selected during preparation')
    if args.native_captures and not args.prepare_native_cache:
        p.error('--native-captures requires --prepare-native-cache')
    args.native_compiler = (CAPTURE_COMPILER if args.native_captures
                            else args.native_compiler or Path(CLANG)).resolve()
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())
