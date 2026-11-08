#!/usr/bin/env python3
"""Check shared YUV uploads against Skia and observe cold Metal memory."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--minimum-reduction-mib', type=int, default=64,
                        help='Cold isolated memory guard on this unified-memory Metal host')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    out.mkdir()
    source = repo / 'Build/deps/skia-brave/source'
    inputs = [Path(__file__).resolve(), repo / 'tools/native_graphite_shared_yuva_test.mm',
              repo / 'native_graphite_darwin.mm', repo / 'native/include/native_graphite_shared_yuva_metal.h',
              repo / 'native/include/native_graphite_shared_metal.h', source / 'out/Release/libskia.a',
              source / 'out/Release/libskcms.a']
    def identity():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = identity()
    binary = out / 'shared_yuva'
    command = ['clang++', '-std=c++20', '-O2', '-DNDEBUG', '-DSK_RELEASE',
               '-UNDEBUG', '-fno-rtti', '-fPIC', '-mmacosx-version-min=14.0',
               '-DSK_GRAPHITE', '-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER',
               '-I' + str(repo), '-I' + str(source),
               str(repo / 'tools/native_graphite_shared_yuva_test.mm'),
               '-L' + str(source / 'out/Release'), '-Wl,-hidden-lskia', '-Wl,-hidden-lskcms']
    for framework in ['Metal', 'CoreGraphics', 'Foundation', 'ImageIO', 'CoreText']:
        command += ['-framework', framework]
    command += ['-o', str(binary)]
    rows = []
    def run(name, actual, runtime=False, diagnostics=False):
        guarded = [sys.executable, str(repo / 'tools/run_memory_bounded.py'),
                   '--lock', str(out / (name + '.lock')),
                   '--report', str(out / (name + '-guard.json'))]
        if runtime:
            guarded += ['--limit-gib', '3']
        guarded += ['--', *actual]
        env = os.environ.copy()
        env.pop('VOX_DISABLE_SHARED_YUVA_UPLOADS', None)
        env.pop('VOX_SHARED_YUVA_DIAGNOSTICS', None)
        if diagnostics:
            env['VOX_SHARED_YUVA_DIAGNOSTICS'] = '1'
        with (out / (name + '.log')).open('w') as log:
            code = subprocess.run(guarded, cwd=repo, env=env, stdout=log,
                                  stderr=subprocess.STDOUT).returncode
        rows.append(dict(name=name, command=guarded, exit=code,
                         host=dict(cpus=os.cpu_count(), load=os.getloadavg(), timestamp=time.time())))
        changed = identity() != before
        (out / 'result.json').write_text(json.dumps(dict(inputs=before,
            inputs_changed=changed, results=rows), indent=2) + '\n')
        print(name, code, flush=True)
        if code or changed:
            raise SystemExit(code or 1)
    run('build', command)
    run('functional', [str(binary)], runtime=True, diagnostics=True)
    assert 'VOX_SHARED_YUVA ' in (out / 'functional.log').read_text(), 'No shared path executed'
    memory = []
    for index, mode in enumerate(['control', 'shared', 'control', 'shared']):
        name = f'memory-{index}-{mode}'
        run(name, [str(binary), mode], runtime=True)
        line = next(line for line in (out / (name + '.log')).read_text().splitlines()
                    if line.startswith('{"shared":'))
        memory.append(json.loads(line))
    assert len({x['pixel_hash'] for x in memory}) == 1
    controls = [x['growth_bytes'] for x in memory if not x['shared']]
    candidates = [x['growth_bytes'] for x in memory if x['shared']]
    result = dict(trials=memory, minimum_observed_reduction_bytes=min(controls) - max(candidates),
                  scope='Cold isolated Metal YUV draw through synchronous CPU readback; not browser RAM.')
    (out / 'memory.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result), flush=True)
    assert result['minimum_observed_reduction_bytes'] >= args.minimum_reduction_mib * 1024 * 1024, \
        'Shared YUV uploads did not preserve the required isolated memory reduction'


if __name__ == '__main__':
    main()
