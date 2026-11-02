#!/usr/bin/env python3
r"""Check shadow typeface reuse/invalidation and exact cached/uncached pixels.

Requires a C++20 compiler and Skia available through pkg-config. Pass two distinct
SFNT fonts containing A, g and i. A two-face TTC is generated from those fonts
using Python fontTools, or pass an existing one with --collection. No downloads
or production archive rebuilds are performed. The default control compiles the
current shadow bridge with a test-only adapter that calls the font loader every
time; --control-archive instead extracts an original shadow_raster.o with GNU
ar/objcopy for a historical comparison.

Run compilation inside the repository memory guard, for example on Linux:

  python3 tools/run_memory_bounded.py --lock Build/shadow-cache-build.lock \
    --report Build/shadow-cache-build.json -- \
    python3 tools/test_shadow_typeface_cache.py \
      --font-a /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
      --font-b /usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf

The runner executes the native test under its own 3 GiB guard. It preserves
commands, compiler/input/fixture hashes, outputs and guard receipts in a new
Build directory (or a new --output directory); earlier runs are never replaced.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


UNCACHED_ADAPTER = """// Test-only oracle: reuse the real raster implementation, bypass its cache.
#include "skia/shadow_typeface_cache.h"
class UncachedShadowTypefaceCache {
public:
    template<class Loader>
    sk_sp<SkTypeface> get(char const* path, int face_index, Loader&& load)
    {
        return load(path, face_index);
    }
};
// The real header was already included; its pragma once keeps the replacement
// local to the cache instance in shadow_raster.cpp. Production needs no macro.
#define VoxShadowTypefaceCache UncachedShadowTypefaceCache
#define vox_skia_shadow vox_skia_shadow_uncached
#include "skia/shadow_raster.cpp"
"""


def digest(path):
    checksum = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(block)
    return checksum.hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--font-a', type=Path, required=True)
    parser.add_argument('--font-b', type=Path, required=True)
    parser.add_argument('--collection', type=Path,
                        help='Existing TTC with valid faces at indices 0 and 1; avoids fontTools')
    parser.add_argument('--control-archive', type=Path,
                        help='Preserved uncached native archive containing shadow_raster.o')
    parser.add_argument('--cxx', default=os.environ.get('CXX', 'c++'))
    parser.add_argument('--output', type=Path, help='New directory for logs, binaries and receipts')
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    compiler = shutil.which(args.cxx)
    if not compiler:
        parser.error(f'C++ compiler not found: {args.cxx}')
    font_a, font_b = args.font_a.resolve(), args.font_b.resolve()
    for path in (font_a, font_b, args.collection, args.control_archive):
        if path is not None and not path.is_file():
            parser.error(f'Input is not a file: {path}')
    if digest(font_a) == digest(font_b):
        parser.error('--font-a and --font-b must contain distinct fonts')
    if args.output:
        output = args.output.resolve()
        output.mkdir(parents=True, exist_ok=False)
    else:
        parent = repo / 'Build/native-shadow-typeface-cache-tests'
        parent.mkdir(parents=True, exist_ok=True)
        output = Path(tempfile.mkdtemp(prefix='run-', dir=parent))
    print(f'Logs: {output}', flush=True)
    environment = dict(os.environ)
    environment['PKG_CONFIG_PATH'] = str(repo / 'Build/deps/lib/pkgconfig') + os.pathsep + environment.get('PKG_CONFIG_PATH', '')
    result = {'passed': False, 'control': 'archive' if args.control_archive else 'uncached adapter'}
    pins = {}

    def execute(command, binary_output=None, log=None):
        started = time.monotonic()
        process = subprocess.run(command, cwd=repo, env=environment, capture_output=True)
        if binary_output is not None and process.returncode == 0:
            binary_output.write_bytes(process.stdout)
        record = {'command': command, 'cwd': str(repo), 'exit': process.returncode,
                  'seconds': time.monotonic() - started,
                  'stdout': '<binary>' if binary_output else process.stdout.decode(errors='replace'),
                  'stderr': process.stderr.decode(errors='replace')}
        with (output / 'commands.jsonl').open('a') as stream:
            stream.write(json.dumps(record) + '\n')
        if log:
            log.write_bytes(process.stdout + process.stderr)
        if process.returncode:
            raise RuntimeError(f'Command exited {process.returncode}: {shlex.join(command)}; see commands.jsonl')
        return process.stdout.decode() if binary_output is None else ''

    try:
        version = execute([compiler, '--version'])
        cflags = shlex.split(execute(['pkg-config', '--cflags', 'skia']))
        libs = shlex.split(execute(['pkg-config', '--libs', 'skia']))
        skia_version = execute(['pkg-config', '--modversion', 'skia']).strip()
        pc_directory = execute(['pkg-config', '--variable=pcfiledir', 'skia']).strip()
        inputs = [Path(__file__).resolve(), repo / 'tools/native_shadow_typeface_cache_test.cpp',
                  repo / 'tools/run_memory_bounded.py', repo / 'skia/shadow_raster.cpp',
                  repo / 'skia/shadow_typeface_cache.h', repo / 'skia/shadow_raster.h',
                  repo / 'skia/canvas_raster.h', Path(compiler).resolve(), font_a, font_b]
        pc_file = Path(pc_directory) / 'skia.pc'
        if pc_file.is_file():
            inputs.append(pc_file)
        # Pin libraries named in pkg-config's explicit search directories.
        library_dirs = [Path(flag[2:]) for flag in libs if flag.startswith('-L')]
        for flag in libs:
            if flag.startswith('-l'):
                for directory in library_dirs:
                    matches = [directory / ('lib' + flag[2:] + suffix)
                               for suffix in ('.so', '.dylib', '.a')]
                    match = next((path for path in matches if path.is_file()), None)
                    if match:
                        inputs.append(match.resolve())
                        break
        if args.collection:
            collection = args.collection.resolve()
        else:
            try:
                import fontTools
                from fontTools.ttLib import TTCollection, TTFont
            except ImportError as error:
                raise RuntimeError('Install Python fontTools or supply --collection with a two-face TTC') from error
            collection = output / 'two-face-fonts.ttc'
            ttc = TTCollection()
            ttc.fonts = [TTFont(font_a, recalcTimestamp=False), TTFont(font_b, recalcTimestamp=False)]
            try:
                ttc.save(collection)
            finally:
                for font in ttc.fonts:
                    font.close()
            result['fonttools_version'] = fontTools.__version__
        inputs.append(collection)
        control_object = output / 'shadow-control.o'
        candidate_object = output / 'shadow-candidate.o'
        if args.control_archive:
            archive = args.control_archive.resolve()
            inputs.append(archive)
        else:
            adapter = output / 'uncached_shadow_adapter.cpp'
            adapter.write_text(UNCACHED_ADAPTER)
            inputs.append(adapter)
        pins = {str(path): digest(path) for path in inputs}
        write_json(output / 'inputs.json', {
            'compiler': compiler, 'compiler_version': version, 'pins': pins,
            'skia_version': skia_version, 'skia_cflags': cflags, 'skia_libs': libs,
            'pkg_config_path': environment['PKG_CONFIG_PATH'], 'control': result['control']})
        common = [compiler, '-std=c++20', '-O2', '-fPIC', '-I' + str(repo),
                  '-I' + str(repo / 'skia'), *cflags]
        if args.control_archive:
            execute(['ar', 'p', str(archive), 'shadow_raster.o'], control_object)
            execute(['objcopy', '--redefine-sym', 'vox_skia_shadow=vox_skia_shadow_uncached', str(control_object)])
        else:
            execute([*common, '-c', str(adapter), '-o', str(control_object)])
        execute([*common, '-c', str(repo / 'skia/shadow_raster.cpp'), '-o', str(candidate_object)])
        binary = output / 'shadow_typeface_cache_test'
        execute([*common, str(repo / 'tools/native_shadow_typeface_cache_test.cpp'),
                 str(candidate_object), str(control_object), *libs, '-o', str(binary)])
        work = output / 'work'
        work.mkdir()
        runtime = [str(binary), str(font_a), str(font_b), str(collection), str(work)]
        result['artifacts'] = {str(path): digest(path)
                               for path in (binary, candidate_object, control_object, collection)}
        result['runtime_command'] = runtime
        execute([sys.executable, str(repo / 'tools/run_memory_bounded.py'),
                 '--limit-gib', '3', '--timeout', '180',
                 '--lock', str(output / 'runtime.lock'),
                 '--report', str(output / 'runtime.guard.json'), '--', *runtime],
                log=output / 'runtime.log')
        result['runtime_guard'] = json.loads((output / 'runtime.guard.json').read_text())
        result['passed'] = True
    except (OSError, RuntimeError, ValueError) as error:
        result['error'] = str(error)
    finally:
        result['changed_inputs'] = [path for path, before in pins.items()
                                    if not Path(path).is_file() or digest(path) != before]
        result['passed'] = result['passed'] and not result['changed_inputs']
        write_json(output / 'result.json', result)
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
