#!/usr/bin/env python3
"""Check Dawn IOSurface transport, pinned buffer changes and cold GPU memory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tarfile
import time

from build_mac_graphite_dawn import REVISION, SHARED_PIXELS_INPUTS, prepare_shared_pixels_patch


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--minimum-reduction-mib', type=int, default=64)
    parser.add_argument('--minimum-final-reduction-mib', type=int, default=8)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    out = args.output.resolve()
    out.mkdir()
    source = repo / 'Build/deps/skia-brave-dawn/source'
    dawn = repo / 'Build/deps/skia-brave-dawn/dawn-build'
    archive = repo / 'Build/deps/skia-brave' / (REVISION + '.tar.gz')
    inputs = [Path(__file__).resolve(), repo / 'tools/native_graphite_shared_dawn_test.mm',
              repo / 'native_graphite_dawn_darwin.mm', repo / 'native_graphite_shared_dawn.h',
              repo / 'native_picture_image_transport.h', repo / 'native_picture_typeface_cache.h',
              repo / 'native_graphite_context_lifetime.h', repo / 'native_skia_image_color_space.h',
              repo / 'native_shared_picture_pixels.h',
              repo / 'tools/build_mac_graphite_dawn.py', repo / 'tools/skia_dawn_shared_pixels.patch',
              archive, source / 'out/Release/libskia.a', source / 'out/Release/libskcms.a',
              dawn / 'src/dawn/native/libwebgpu_dawn.a']
    def identity():
        return {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    before = identity()
    rows = []
    artifacts = {}
    def run(name, command, runtime=False, diagnostics=False, cwd=repo):
        guarded = [sys.executable, str(repo / 'tools/run_memory_bounded.py'),
                   '--lock', str(out / (name + '.lock')), '--report', str(out / (name + '-guard.json'))]
        if runtime:
            guarded += ['--limit-gib', '3']
        guarded += ['--', *command]
        env = os.environ.copy()
        env.pop('VOX_DISABLE_SHARED_DAWN_PIXELS', None)
        env.pop('VOX_DISABLE_DIRECT_DAWN_READBACK', None)
        env.pop('VOX_SHARED_DAWN_DIAGNOSTICS', None)
        if diagnostics:
            env['VOX_SHARED_DAWN_DIAGNOSTICS'] = '1'
        host = dict(cpus=os.cpu_count(), load=os.getloadavg(), timestamp=time.time())
        with (out / (name + '.log')).open('w') as log:
            code = subprocess.run(guarded, cwd=cwd, env=env, stdout=log,
                                  stderr=subprocess.STDOUT).returncode
        rows.append(dict(name=name, command=guarded, cwd=str(cwd), exit=code, host=host))
        changed = identity() != before or any(
            hashlib.sha256(Path(p).read_bytes()).hexdigest() != h for p, h in artifacts.items())
        (out / 'result.json').write_text(json.dumps(dict(inputs=before, inputs_changed=changed,
            artifacts=artifacts, results=rows), indent=2) + '\n')
        print(name, code, flush=True)
        if code or changed:
            raise SystemExit(code or 1)

    # Stage only the two authenticated patch inputs, not another Skia tree.
    staged = out / 'buffer-inputs'
    with tarfile.open(archive) as bundle:
        for name in SHARED_PIXELS_INPUTS:
            target = staged / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(bundle.extractfile(f'skia-{REVISION}/{name}').read())
    prepare_shared_pixels_patch(staged, archive, repo / 'tools/skia_dawn_shared_pixels.patch')
    objects = []
    for name in SHARED_PIXELS_INPUTS:
        stem = Path(name).stem
        target = 'obj/' + str(Path(name).parent) + '/graphite.' + stem + '.o'
        command = shlex.split(subprocess.check_output(['ninja', '-C', str(source / 'out/Release'),
            '-t', 'commands', target], text=True).strip())
        command[command.index('-c') + 1] = str(staged / name)
        obj = out / (stem + '.o')
        command[command.index('-o') + 1] = str(obj)
        command[command.index('-MF') + 1] = str(out / (stem + '.d'))
        run('build-' + stem, command, cwd=source / 'out/Release')
        objects.append(str(obj))
    binary = out / 'shared_dawn'
    command = ['clang++', '-std=c++20', '-O2', '-DSK_RELEASE', '-UNDEBUG', '-fno-rtti',
               '-fPIC', '-mmacosx-version-min=14.0', '-DSK_GRAPHITE', '-DSK_DAWN',
               '-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER', '-I' + str(repo), '-I' + str(source),
               '-I' + str(source / 'third_party/externals/dawn/include'), '-I' + str(dawn / 'gen/include'),
               str(repo / 'tools/native_graphite_shared_dawn_test.mm'), *objects,
               '-L' + str(source / 'out/Release'), '-L' + str(dawn / 'src/dawn/native'),
               '-Wl,-hidden-lskia', '-Wl,-hidden-lskcms', '-Wl,-hidden-lwebgpu_dawn']
    for framework in ['CoreText', 'Metal', 'CoreGraphics', 'Foundation', 'ImageIO',
                      'IOSurface', 'IOKit', 'QuartzCore', 'Cocoa']:
        command += ['-framework', framework]
    command += ['-o', str(binary)]
    run('build', command)
    artifacts = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in [str(binary), *objects]}
    run('functional', [str(binary)], runtime=True, diagnostics=True)
    assert 'VOX_SHARED_DAWN ' in (out / 'functional.log').read_text()
    assert 'Dawn error:' not in (out / 'functional.log').read_text()
    assert 'VOX_DAWN_DIRECT_READBACK ' in (out / 'functional.log').read_text()
    memory = []
    for index, mode in enumerate(['control', 'shared', 'control', 'shared']):
        name = f'memory-{index}-{mode}'
        run(name, [str(binary), mode], runtime=True)
        memory.append(json.loads(next(line for line in (out / (name + '.log')).read_text().splitlines()
                                      if line.startswith('{"shared":'))))
    assert len({x['pixel_hash'] for x in memory}) == 1
    controls = [x['growth_bytes'] for x in memory if not x['shared']]
    candidates = [x['growth_bytes'] for x in memory if x['shared']]
    result = dict(trials=memory, minimum_observed_reduction_bytes=min(controls) - max(candidates),
                  scope='Cold isolated Dawn picture drawing through CPU readback; not browser peak RAM.')
    (out / 'memory.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result), flush=True)
    assert result['minimum_observed_reduction_bytes'] >= args.minimum_reduction_mib * 1024 * 1024
    final_reads = []
    for index, mode in enumerate(['final-staged', 'final-direct', 'final-staged', 'final-direct']):
        name = f'final-memory-{index}-{mode}'
        run(name, [str(binary), mode], runtime=True)
        final_reads.append(json.loads(next(line for line in (out / (name + '.log')).read_text().splitlines()
                                          if line.startswith('{"direct":'))))
    assert len({x['pixel_hash'] for x in final_reads}) == 1
    controls = [x['peak_bytes'] for x in final_reads if not x['direct']]
    candidates = [x['peak_bytes'] for x in final_reads if x['direct']]
    final_result = dict(trials=final_reads, minimum_observed_peak_reduction_bytes=min(controls) - max(candidates),
                        scope='Fresh-process 2048x2048 single picture draw; macOS lifetime physical footprint peak.')
    (out / 'final-read-memory.json').write_text(json.dumps(final_result, indent=2) + '\n')
    print(json.dumps(final_result), flush=True)
    assert final_result['minimum_observed_peak_reduction_bytes'] >= args.minimum_final_reduction_mib * 1024 * 1024



if __name__ == '__main__':
    main()
