#!/usr/bin/env python3
"""Validate the diagnostic JSC probe against real recursive/throwing API calls."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys


def text_range(binary):
    data = binary.read_bytes()
    header = struct.unpack_from('<8I', data)
    assert header[0] == 0xfeedfacf, 'Expected native 64-bit Mach-O'
    offset = 32
    base = section = None
    for _ in range(header[4]):
        command, size = struct.unpack_from('<II', data, offset)
        if command == 0x19:
            segment = data[offset + 8:offset + 24].split(b'\0')[0]
            address = struct.unpack_from('<Q', data, offset + 24)[0]
            if segment == b'__TEXT':
                base = address
            count = struct.unpack_from('<I', data, offset + 64)[0]
            for i in range(count):
                start = offset + 72 + i * 80
                name = data[start:start + 16].split(b'\0')[0]
                if segment == b'__TEXT' and name == b'__text':
                    section = struct.unpack_from('<QQ', data, start + 32)
        offset += size
    assert base is not None and section
    return section[0] - base, section[0] - base + section[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    probe = out / 'jsc-instructions.dylib'
    fixture = out / 'fixture'
    sources = [Path(__file__).resolve(), root / 'tools/jsc_instruction_probe.m',
               root / 'tools/jsc_instruction_probe_test.m',
               root / 'browserjs/module_loader_darwin.m',
               root / 'browserjs/module_loader_darwin.h']
    def pins():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    result = dict(complete=False, inputs_before=pins(), jobs=[])
    def save():
        (out / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    environment = {k: v for k, v in os.environ.items()
                   if not k.startswith(('VOX_', 'DYLD_', 'LADYBIRD_', 'JSC_'))}
    def job(name, command, runtime=False, extra=None):
        guard = [sys.executable, str(root / 'tools/run_memory_bounded.py'),
                 '--lock', str(out / (name + '.lock')),
                 '--report', str(out / (name + '-guard.json'))]
        if runtime:
            guard += ['--limit-gib', '3']
        child = list(map(str, command))
        if extra:
            child = ['env', *[k + '=' + v for k, v in extra.items()], *child]
        command = guard + ['--'] + child
        with (out / (name + '.stdout')).open('w') as stdout, (out / (name + '.log')).open('w') as stderr:
            code = subprocess.run(command, cwd=root, env=environment,
                                  stdout=stdout, stderr=stderr).returncode
        result['jobs'].append(dict(name=name, command=command, environment=extra or {}, exit=code))
        save()
        assert code == 0, name
    try:
        common = ['clang', '-O2', '-Wall', '-Wextra', '-Werror', '-fno-objc-arc',
                  '-framework', 'Foundation', '-framework', 'JavaScriptCore']
        job('probe-compile', common + ['-dynamiclib', sources[1], '-o', probe])
        job('fixture-compile', common + [sources[2], '-o', fixture])
        job('probe-sign', ['codesign', '--force', '--sign', '-', probe])
        job('fixture-sign', ['codesign', '--force', '--sign', '-', fixture])
        job('baseline', [fixture], True)
        job('inactive', [fixture], True, dict(DYLD_INSERT_LIBRARIES=str(probe)))
        job('active', [fixture], True, dict(DYLD_INSERT_LIBRARIES=str(probe), VOX_JSC_INSTRUCTION_PROBE='1'))
        baseline = (out / 'baseline.stdout').read_text()
        assert baseline.startswith('JSC scope fixture passed:')
        assert baseline == (out / 'inactive.stdout').read_text() == (out / 'active.stdout').read_text()
        for name in ['baseline', 'inactive']:
            assert 'VOX_JSC_SCOPE' not in (out / (name + '.log')).read_text()
        text = (out / 'active.log').read_text()
        metadata = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines()
                    if line.startswith('VOX_JSC_SCOPE_META ')]
        rows = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines()
                if line.startswith('VOX_JSC_SCOPE ')]
        assert len(metadata) == 1
        meta = metadata[0]
        assert meta['faults'] == meta['open_frames'] == 0 and meta['maximum_depth'] >= 5
        assert meta['factory_available'] and meta['objc_call_available'] and meta['script_eval_available']
        assert Path(meta['executable']).resolve() == fixture
        assert all(r['pid'] == meta['pid'] and 0 < r['self_instructions'] <= r['inclusive_instructions'] for r in rows)
        assert sum(r['self_instructions'] for r in rows) <= meta['process_instructions']
        start, end = text_range(fixture)
        main_rows = [r for r in rows if Path(r['image']).resolve() == fixture]
        for row in main_rows:
            assert start <= row['caller_offset'] < end
            assert row['caller'] == row['image_base'] + row['caller_offset']
        counts = {name: sum(r['calls'] for r in main_rows if r['api'] == name)
                  for name in ['JSEvaluateScript', 'JSObjectCallAsFunction', 'JSScriptFactory',
                               'JSValue.callWithArguments', 'JSContext.evaluateJSScript']}
        assert counts == dict(JSEvaluateScript=3, JSObjectCallAsFunction=6, JSScriptFactory=3,
                              **{'JSValue.callWithArguments': 2, 'JSContext.evaluateJSScript': 3}), counts
        factories = [r for r in main_rows if r['api'] == 'JSScriptFactory']
        assert all(r['url'] == 'https://probe.test/module.js' and not r['url_truncated'] for r in factories)
        expected_units = sum(len(s.encode('utf-16-le')) // 2 for s in
                             ['globalThis.probeAnswer=1', "globalThis.probeAnswer='🦊'", 'function {'])
        assert sum(r['source_utf16_units'] for r in factories) == expected_units
        result.update(complete=True, metadata=meta, scopes=rows, fixture_native_text_range=[start, end],
                      counts=counts, fixture_sha256=hashlib.sha256(fixture.read_bytes()).hexdigest(),
                      probe_sha256=hashlib.sha256(probe.read_bytes()).hexdigest())
    finally:
        result['inputs_after'] = pins()
        assert result['inputs_after'] == result['inputs_before']
        save()
    print(json.dumps(dict(complete=True, counts=result['counts'])))


if __name__ == '__main__':
    main()
