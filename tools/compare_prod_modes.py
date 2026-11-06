#!/usr/bin/env python3
"""Generate and compile matched literal -prod browser variants.

Only generated/preprocessed compiler outputs are retained. The canonical app
is never copied or replaced by this build step. Generation is rejected if its
source closure changes; optimizing compilation then consumes sealed inputs.
"""
import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time

from browser_bundle_lease import publication_lease, ROOT
from freeze_browser_compile import prepare, validate, digest, fingerprint, check_fingerprints
from rebuild_browser import repository_state, same_build_inputs, write_json
from seal_parallel_compare import compile_plan


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--reference-receipt', type=Path, required=True)
    parser.add_argument('--source-list', type=Path, required=True,
                        help='Previously emitted -dump-files closure; both new generations must match it')
    args = parser.parse_args()
    output, reference = args.output.resolve(), args.reference_receipt.resolve()
    output.mkdir(parents=True, exist_ok=False)
    single, parallel = output / 'single', output / 'parallel'
    single.mkdir(); parallel.mkdir()
    build_line = next(line.split(' with: ', 1)[1] for line in
                      (reference / 'build.log').read_text().splitlines()
                      if line.startswith('Building Vox (single C) with: '))
    options, cflags = build_line.split(' -cflags ', 1)
    options = shlex.split(options)
    if '-prod' not in options or '-parallel-cc' in options:
        raise ValueError('Reference must be literal single-unit V -prod')
    vpath = options[options.index('-path') + 1]
    compiler = next(Path(folder) / 'compiler/v' for folder in vpath.split('|')
                    if (Path(folder) / 'compiler/v').is_file())
    clang = subprocess.check_output(['xcrun', '--find', 'clang'], text=True).strip()
    native = ROOT / 'Build/v/Vox.app/Contents/MacOS'
    skia = ROOT.parent / '3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic'
    ldflags = (f'-Wl,-dead_strip,-dead_strip_dylibs -L{ROOT}/Build/v/rust-yuv/release '
               f'-lladybird_v_yuv -L{native} -lLadybirdVSkiaText -Wl,-rpath,@executable_path '
               f'-Wl,-rpath,{skia}/lib -lc++ {skia}/lib/libicuuc.dylib -Wl,-rpath,{skia}/lib')
    base = [str(compiler), *options, '-cflags', cflags, '-ldflags', ldflags]
    environment = dict(os.environ, V_MACOS_V3_NO_FALLBACK='1', VFLAGS='', CFLAGS='', LDFLAGS='')
    launcher = output / 'compiler-launcher'
    launcher.mkdir()
    (launcher / 'clang').write_text('#!/bin/sh\nexec ' + shlex.quote(sys.executable) + ' ' +
                                   shlex.quote(str(ROOT / 'tools/seal_parallel_compare.py')) + ' "$@"\n')
    (launcher / 'clang').chmod(0o755)
    started_ns = time.time_ns()
    with publication_lease(ROOT, shared=True):
        before = repository_state(ROOT)
        source_paths = {Path(name).resolve() for name in args.source_list.read_text().splitlines()}
        source_manifest = fingerprint(source_paths)
        write_json(single / 'inputs-before.json', before)
        write_json(output / 'inputs-before.json', before)
        native_before = fingerprint(native.glob('*.dylib'))
        commands = []
        for mode, folder in [('single', single), ('parallel', parallel)]:
            command = [*base, '-dump-files', str(folder / 'source-files.txt'),
                       '-dump-c-flags', str(folder / 'Vox.flags')]
            env = dict(environment)
            if mode == 'single':
                command += ['-o', str(folder / 'Vox.c'), str(ROOT)]
            else:
                command += ['-parallel-cc', '-keepc', '-showcc', '-o', str(folder / 'generation-placeholder'), str(ROOT)]
                env.update(PATH=str(launcher) + ':' + os.environ['PATH'],
                           VOX_SEAL_PARALLEL_DIR=str(folder), VOX_SEAL_REAL_CLANG=clang,
                           V3_PARALLEL_CC_REQUIRE_SPLIT='1')
            commands.append(dict(mode=mode, command=command, cwd=str(compiler.parent)))
            write_json(output / 'generation-commands.json', commands)
            print('Generating and sealing ' + mode, flush=True)
            with (folder / 'generation.log').open('w') as stream:
                subprocess.run(command, cwd=compiler.parent, env=env, stdout=stream,
                               stderr=subprocess.STDOUT, check=True)
            if mode == 'single':
                previous = Path.cwd()
                os.chdir(compiler.parent)
                try:
                    prepare(ROOT, output, single, single / 'Vox.c', single / 'Vox.flags', single / 'Vox',
                            compiler=clang, source_manifest=source_manifest)
                finally:
                    os.chdir(previous)
        closures = [set(Path(name).resolve() for name in (folder / 'source-files.txt').read_text().splitlines())
                    for folder in (single, parallel)]
        if closures[0] != closures[1] or closures[0] != source_paths:
            raise RuntimeError('The two V source closures differ')
        changed = [str(path) for path in closures[0] if path.stat().st_ctime_ns >= started_ns]
        if changed:
            raise RuntimeError('Source closure modified during generation: ' + repr(changed))
        after = repository_state(ROOT)
        check_fingerprints(source_manifest)
        check_fingerprints(native_before)
        write_json(output / 'sealed-generation.json', dict(
            source_inputs=after, compiler_sha256=digest(compiler), clang_sha256=digest(clang),
            source_closure=fingerprint(closures[0]), native_inputs=native_before, generation_complete=True))
    # Compilation does not read repository C/V sources again.
    frozen = validate(single, before, require_complete=False)
    print('Compiling sealed single-unit -prod', flush=True)
    start = time.monotonic()
    with (single / 'compile.log').open('w') as stream:
        result = subprocess.run(frozen['compiler_command'], cwd=frozen['cwd'], stdout=stream, stderr=subprocess.STDOUT)
    frozen.update(compiler_exit=result.returncode, complete=result.returncode == 0, wall_seconds=time.monotonic() - start)
    write_json(single / 'frozen-compile.json', frozen)
    if result.returncode:
        raise RuntimeError('Single-unit C compilation failed')
    validate(single, before)
    print('Compiling sealed -prod -parallel-cc', flush=True)
    compile_plan(parallel)
    check_fingerprints(native_before)
    write_json(output / 'built.json', dict(complete=True, executables={
        mode: dict(path=str(folder / 'Vox'), sha256=digest(folder / 'Vox'))
        for mode, folder in [('single', single), ('parallel', parallel)]}))
    print('Both matched literal-prod builds completed', flush=True)


if __name__ == '__main__':
    main()
