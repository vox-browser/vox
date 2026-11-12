#!/usr/bin/env python3
"""Verify default macOS WebGL shader execution and document presentation."""
import argparse
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zlib

from browser_bundle_lease import canonical_bundle_lease
from check_pixel_equality import compare
from measure_sealed_github_instructions import fingerprint, native_dependencies
from measure_browser_instructions import VOX_CHROME_HEIGHT

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 400, 240


def expected_png(path):
    # Independent expected document: top/bottom halves of two 64px canvases.
    data = bytearray()
    for y in range(HEIGHT):
        data.append(0)  # PNG filter: none.
        for x in range(WIDTH):
            color = (255, 255, 255, 255)
            if y < 64 and x < 128:
                color = ((255, 0, 0, 255) if y < 32 else (0, 0, 255, 255)) if x < 64 else (
                    (0, 255, 0, 255) if y < 32 else (255, 255, 0, 255))
            data.extend(color)
    def chunk(kind, payload):
        return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' +
        chunk(b'IHDR', struct.pack('>IIBBBBB', WIDTH, HEIGHT, 8, 6, 0, 0, 0)) +
        chunk(b'IDAT', zlib.compress(bytes(data))) + chunk(b'IEND', b''))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--diff-tool', type=Path, default=ROOT / 'Build/pixel-tools/pixel_diff')
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Requires macOS and a completed production browser')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    binary = ROOT / 'Build/v/Vox.app/Contents/MacOS/Vox'
    fixture = ROOT / 'Tests/Browser/Native/webgl-metal.html'
    expected = output / 'expected.png'
    expected_png(expected)
    report = dict(passed=False, trials=[], scope='fresh launch through document PNG; real author JavaScript')
    result_path = output / 'result.json'
    try:
        with canonical_bundle_lease(binary.parents[2]):
            prefix = Path(subprocess.check_output(['brew', '--prefix', 'glslang'], text=True).strip())
            libraries = [prefix / 'lib/libglslang.dylib', prefix / 'lib/libglslang-default-resource-limits.dylib']
            inputs = native_dependencies(binary, libraries) | {
                fixture, Path(__file__).resolve(), ROOT / 'tools/run_memory_bounded.py',
                ROOT / 'tools/check_pixel_equality.py', ROOT / 'tools/browser_bundle_lease.py',
                ROOT / 'tools/measure_sealed_github_instructions.py',
                ROOT / 'tools/measure_browser_instructions.py', args.diff_tool.resolve(), expected}
            pins = fingerprint(inputs)
            report['pins'] = pins
            report['production'] = json.loads((ROOT / 'Build/production-build/latest.json').read_text())
            for index in range(2):
                directory = output / ('trial-' + str(index + 1))
                directory.mkdir()
                profile = directory / 'profile'
                profile.mkdir()
                (profile / 'settings.json').write_text('{"allow_any_site":true}\n')
                audit_path = directory / 'audit.json'
                png = directory / 'document.png'
                env = {key: value for key, value in os.environ.items()
                       if 'proxy' not in key.lower() and not key.startswith(
                           ('VOX_', 'LADYBIRD_', 'DYLD_', 'GC_', 'JSC_'))}
                env.update(VOX_TEST_WINDOW='1', VOX_PROFILE_DIR=str(profile),
                    LADYBIRD_CACHE_DIR=str(profile / 'cache'), LADYBIRD_SCREENSHOT_SCALE='1',
                    LADYBIRD_SCREENSHOT_DELAY_SECONDS='2', VOX_CAPTURE_DOCUMENT_ONLY='1',
                    VOX_CAPTURE_AUDIT_PATH=str(audit_path), DYLD_PRINT_LIBRARIES='1')
                command = [str(binary), '--enable-javascript', '--window-width', str(WIDTH),
                    '--window-height', str(HEIGHT + VOX_CHROME_HEIGHT), '--screenshot', str(png), str(fixture)]
                guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'), '--limit-gib', '3',
                    '--timeout', '90', '--lock', str(directory / 'runtime.lock'),
                    '--report', str(directory / 'runtime.json'), '--', *command]
                run = subprocess.run(guard, cwd=ROOT, env=env, text=True, capture_output=True, timeout=110)
                log = run.stdout + run.stderr
                (directory / 'browser.log').write_text(log)
                trial = dict(command=command, guard_command=guard, exit=run.returncode)
                report['trials'].append(trial)
                if run.returncode:
                    raise RuntimeError('Browser/guard failed: ' + str(run.returncode))
                trial['guard'] = json.loads((directory / 'runtime.json').read_text())
                audit = json.loads(audit_path.read_text())
                trial['audit'] = audit
                if (audit['title'] != 'WebGL Metal smoke PASS' or audit['ready'] != 'complete' or
                    audit['viewport_width'] != WIDTH or audit['viewport_height'] != HEIGHT or
                    audit['native_reported_error_count'] != 0):
                    raise RuntimeError('Shader execution, document identity or viewport audit failed')
                if not re.search(r'WEBGL_METAL_SMOKE_PASS.*Vox direct Metal.*Vox direct Metal', '\n'.join(audit['javascript_diagnostics'])):
                    raise RuntimeError('Both shader contexts must report the direct Metal renderer')
                if re.search(r'/lib(?:EGL|GLES|ANGLE)', log):
                    raise RuntimeError('An ANGLE/EGL/GLES library loaded')
                trial['browser_pids'] = sorted(set(re.findall(r'dyld\[(\d+)\]', log)))
                comparison = compare(expected, png, directory / 'diff.png', args.diff_tool.resolve())
                trial['comparison'] = comparison
                if not comparison['exact']:
                    raise RuntimeError('Canvas presentation pixels differ')
                if fingerprint(inputs) != pins:
                    raise RuntimeError('Pinned executable, libraries or test inputs changed')
                result_path.write_text(json.dumps(report, indent=2) + '\n')
                print('WebGL1/WebGL2 shader/readback/presentation trial ' + str(index + 1) + ': passed', flush=True)
            report['passed'] = True
    except Exception as error:
        report['error'] = str(error)
        print(str(error), file=sys.stderr)
    result_path.write_text(json.dumps(report, indent=2) + '\n')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
