#!/usr/bin/env python3
"""Observe an active native page from an offline archive or a direct HTTP(S) URL.

This is a functional diagnostic, not a performance or pixel-conformance gate.
The native observer captures the window, or the screenshot path captures only
the document, and quits normally. Use the memory guard with the same PID registry.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import threading
import time
from urllib.parse import urlsplit

from browser_bundle_lease import canonical_bundle_lease
from measure_precise_scroll import runtime_input_paths
from page_archive import Replay, load_archive
from run_memory_bounded import publish_adopted_processes

ROOT = Path(__file__).resolve().parents[1]
SELECTORS = [('rows', 'tr.react-directory-row'),
             ('latest', '[data-testid=latest-commit]'),
             ('readme', 'article.markdown-body'),
             ('commits', 'a[href*="/commit/"]')]


def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()


def live_http_url(value):
    try:
        parsed = urlsplit(value)
        if (parsed.scheme not in ('http', 'https') or not parsed.hostname
                or parsed.username is not None or parsed.password is not None
                or any(character.isspace() or ord(character) < 32 for character in value)):
            raise ValueError('Expected an HTTP(S) URL without credentials or whitespace')
        parsed.port
    except ValueError as error:
        raise argparse.ArgumentTypeError(str(error)) from error
    return value


def run(args):
    output, binary = args.output.resolve(), args.binary.resolve()
    archive = args.archive.resolve() if args.archive is not None else None
    capture_png = output / ('document.png' if args.document_capture else 'window.png')
    output.mkdir(exist_ok=False, parents=True)
    replay = Replay(archive, output / 'replay') if archive is not None else None
    if replay is not None:
        threading.Thread(target=replay.server.serve_forever, daemon=True).start()
    target_url = replay.manifest['url'] if replay is not None else args.url
    config = dict(describe_native_errors=True, describe_text_geometry=args.text_geometry, selectors=[
        dict(name=name, selector=selector, limit=200, attributes=['id', 'href'])
        for name, selector in SELECTORS])
    (output / 'audit-config.json').write_text(json.dumps(config, indent=2) + '\n')
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'LADYBIRD_', 'JSC_', 'GC_', 'DYLD_'))
                   and 'proxy' not in k.lower()}
    environment.update(VOX_PROFILE_DIR=str(output / 'profile'), VOX_TEST_WINDOW='1',
        VOX_NATIVE_OBSERVATION_DELAY_MS=str(args.observe_ms),
        VOX_NATIVE_OBSERVATION_SCREENSHOT=str(capture_png),
        VOX_CAPTURE_AUDIT_CONFIG=str(output / 'audit-config.json'),
        VOX_CAPTURE_AUDIT_PATH=str(output / 'audit.json'), LADYBIRD_SCREENSHOT_SCALE='1')
    if replay is not None:
        environment.update(VOX_PROXY=replay.ready['proxy'], SSL_CERT_FILE=replay.ready['ca'])
    else:
        # A direct navigation must not inherit an earlier replay's private CA.
        environment.pop('SSL_CERT_FILE', None)
        environment.pop('SSL_CERT_DIR', None)
    environment['VOX_LIBJS_NATIVE_CACHE_FINAL_AUDIT_PATH'] = str(output / 'native-cache-final.json')
    if args.native_cache is not None:
        environment['VOX_LIBJS_NATIVE_CACHE'] = str(args.native_cache.resolve())
    if args.disable_native_cache:
        environment['VOX_LIBJS_NATIVE_CACHE'] = '0'
    if args.frontend_cache is not None:
        environment['VOX_LIBJS_FRONTEND_CACHE'] = args.frontend_cache
    if args.native_compiler is not None:
        environment['VOX_LIBJS_NATIVE_COMPILER'] = str(args.native_compiler.resolve())
    if args.native_diagnostics:
        environment['VOX_LIBJS_NATIVE_DIAGNOSTICS'] = '1'
    if args.render_device_scale is not None:
        environment['VOX_CAPTURE_RENDER_DEVICE_PIXEL_RATIO'] = str(args.render_device_scale)
    if args.date_epoch_ms is not None:
        environment['VOX_LIBJS_DATE_EPOCH_MS'] = str(args.date_epoch_ms)
    if args.audit_interval_ms is not None:
        environment['VOX_NATIVE_OBSERVATION_INTERVAL_MS'] = str(args.audit_interval_ms)
    if args.document_capture:
        environment.pop('VOX_NATIVE_OBSERVATION_DELAY_MS')
        environment.pop('VOX_NATIVE_OBSERVATION_SCREENSHOT')
        environment.update(VOX_CAPTURE_DOCUMENT_ONLY='1', VOX_CAPTURE_DOCUMENT_ACTIVE='1',
            LADYBIRD_SCREENSHOT_DELAY_SECONDS=str(args.observe_ms / 1000))
        if args.ready_selector is not None:
            environment['VOX_CAPTURE_READY_SELECTOR'] = args.ready_selector
    command = [str(binary), '--enable-javascript', '--js-engine=' + args.engine,
               '--window-width', '1024', '--window-height',
               '852' if args.document_capture else '880']
    if args.document_capture:
        command.extend(['--screenshot', str(capture_png)])
    command.append(target_url)
    result = dict(command=command, configuration=args.configuration,
        source=dict(mode='archive' if replay is not None else 'live', url=target_url,
                    response_policy='frozen response archive' if replay is not None
                    else 'current direct HTTP(S) responses; page bytes may change'),
        native_cache=environment.get('VOX_LIBJS_NATIVE_CACHE', 'profile default'),
        native_compiler=environment.get('VOX_LIBJS_NATIVE_COMPILER', 'clang'),
        frontend_cache=environment.get('VOX_LIBJS_FRONTEND_CACHE', 'native-cache policy'),
        audit_interval_ms=args.audit_interval_ms,
        scope=('active document-only native capture; no pixel/performance gate'
               if args.document_capture else
               'active-window functional diagnosis; whole-window PNG; no pixel/performance gate'),
        document_capture=args.document_capture, ready_selector=args.ready_selector,
        text_geometry=args.text_geometry, native_diagnostics=args.native_diagnostics,
        render_device_scale=args.render_device_scale,
        date_epoch_ms=args.date_epoch_ms,
        observer_sha256=digest(Path(__file__)), sample_after=args.sample_after,
        host_before=dict(cpu_count=os.cpu_count(), load=os.getloadavg(), unix=time.time()))
    process = None
    try:
        # The standalone diagnostic uses the shared native libraries too.
        with canonical_bundle_lease(ROOT / 'Build/v/Vox.app'):
            paths = [binary, *runtime_input_paths(binary, environment),
                     *sorted((ROOT / 'Build/v').glob('*.dylib'))]
            if archive is not None:
                paths.append(archive / 'manifest.json')
            pins = {str(path): digest(path) for path in paths}
            result['inputs_before'] = pins
            with (output / 'browser.log').open('w') as log:
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                           cwd=ROOT, env=environment)
                result['pid'] = process.pid
                publish_adopted_processes(args.memory_guard_registry, [process.pid])
                (output / 'launch.json').write_text(json.dumps(result, indent=2) + '\n')
                sampler = None
                if args.sample_after is not None:
                    def sample_stack():
                        time.sleep(args.sample_after)
                        if process.poll() is None:
                            with (output / 'sample.log').open('w') as sample_log:
                                subprocess.run(['sample', str(process.pid), '1', '1', '-file',
                                                str(output / 'sample.txt')],
                                               stdout=sample_log, stderr=subprocess.STDOUT,
                                               timeout=10, check=False)
                    sampler = threading.Thread(target=sample_stack, daemon=True)
                    sampler.start()
                try:
                    result['browser_exit'] = process.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    result['timeout'] = True
                    process.terminate()
                    try:
                        result['browser_exit'] = process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        result['browser_exit'] = process.wait()
                if sampler is not None:
                    sampler.join(timeout=12)
            result['changed_inputs'] = [path for path, expected in pins.items()
                if not Path(path).is_file() or digest(Path(path)) != expected]
            if archive is not None:
                load_archive(archive)
            if (output / 'native-cache-final.json').is_file():
                result['compiled_javascript_cache_final'] = json.loads(
                    (output / 'native-cache-final.json').read_text())
            if (output / 'audit.json').is_file():
                audit = json.loads((output / 'audit.json').read_text())
                result['document'] = {key: audit.get(key) for key in
                    ['url', 'title', 'ready', 'visibility', 'fully_active',
                     'viewport_width', 'viewport_height', 'display_device_pixel_ratio',
                     'rendering_device_pixel_ratio', 'layout_coordinate_scale', 'font_rendering_policy']}
                result['counts'] = {group['name']: group['count'] for group in audit['selections']}
                result['javascript_diagnostics'] = audit.get('javascript_diagnostics', [])
                result['compiled_javascript_cache'] = audit.get('compiled_javascript_cache')
                result['native_errors'] = audit.get('native_reported_errors', [])
                result['native_error_count'] = audit.get('native_reported_error_count', 0)
                result['native_error_information'] = audit.get('native_reported_error_information', [])
            result['png_present'] = capture_png.is_file()
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            result['browser_exit'] = process.wait()
        if replay is not None:
            replay.server.shutdown()
            replay.server.server_close()
        result['host_after'] = dict(load=os.getloadavg(), unix=time.time())
        (output / 'summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: result.get(key) for key in
        ['pid', 'browser_exit', 'document', 'counts', 'png_present', 'changed_inputs',
         'javascript_diagnostics']}, ensure_ascii=False))
    return 0 if (result.get('browser_exit') == 0 and result.get('png_present')
                 and not result.get('changed_inputs')) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--archive', type=Path)
    source.add_argument('--url', type=live_http_url,
                        help='Capture current direct responses, without replay or a frozen-content claim')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--memory-guard-registry', type=Path, required=True)
    parser.add_argument('--engine', choices=['libjs', 'javascriptcore'], default='libjs')
    cache = parser.add_mutually_exclusive_group()
    cache.add_argument('--native-cache', type=Path,
                       help='Explicit persistent cache shared by first/reopened diagnostics')
    cache.add_argument('--disable-native-cache', action='store_true',
                       help='Use the interpreter as a separate diagnostic control')
    parser.add_argument('--native-compiler', type=Path,
                        help='Use /usr/bin/false on reopen to detect unexpected compilation')
    parser.add_argument('--frontend-cache', choices=['on', 'off'],
                        help='Control syntax reuse independently of native execution for matched diagnostics')
    parser.add_argument('--native-diagnostics', action='store_true',
                        help='Enable native entry/fast/slow counters in a separate eligibility diagnostic')
    parser.add_argument('--text-geometry', action='store_true',
                        help='Record bounded retained text paint positions and font metrics')
    parser.add_argument('--render-device-scale', type=float,
                        help='Preserve this windowed font/paint grid while capturing a 1x PNG')
    parser.add_argument('--date-epoch-ms', type=float,
                        help='LibJS Date origin for a clock-matched replay; real elapsed time is retained')
    parser.add_argument('--observe-ms', type=int, default=15000)
    parser.add_argument('--audit-interval-ms', type=int,
                        help='Rewrite the active document audit while waiting for the final capture')
    parser.add_argument('--timeout', type=float, default=150)
    parser.add_argument('--configuration', default='diagnostic browser; see its compile receipt')
    parser.add_argument('--sample-after', type=float,
                        help='Collect a separate one-second macOS stack diagnostic after this delay')
    parser.add_argument('--document-capture', action='store_true',
                        help='Capture only the document through the native screenshot path at 1x')
    parser.add_argument('--ready-selector',
                        help='Wait for this selector before a document-only capture')
    args = parser.parse_args()
    if args.observe_ms <= 0 or args.timeout <= args.observe_ms / 1000:
        parser.error('Timeout must exceed the positive observation delay')
    if args.audit_interval_ms is not None and args.audit_interval_ms <= 0:
        parser.error('Audit interval must be positive')
    if args.sample_after is not None and args.sample_after < 0:
        parser.error('Sample delay must be nonnegative')
    if args.ready_selector is not None and not args.document_capture:
        parser.error('A readiness selector requires --document-capture')
    if args.render_device_scale is not None and (not args.document_capture
            or not math.isfinite(args.render_device_scale) or args.render_device_scale <= 0):
        parser.error('A positive finite render device scale requires --document-capture')
    if args.date_epoch_ms is not None and (args.engine != 'libjs'
            or not math.isfinite(args.date_epoch_ms) or abs(args.date_epoch_ms) > 8_640_000_000_000_000
            or not args.date_epoch_ms.is_integer()):
        parser.error('A Date epoch requires LibJS and integer milliseconds in the Date range')
    raise SystemExit(run(args))


if __name__ == '__main__':
    main()
