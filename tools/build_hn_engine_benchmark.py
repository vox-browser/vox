#!/usr/bin/env python3
"""Build a browser engine benchmark backend, sealing C before optimizing it.

Run through run_memory_bounded (12 GiB). V generation and clang run sequentially
so the compiler's retained AST does not share the C optimizer's memory budget.
Generated artifacts stay beside --output, outside Build; source stays canonical.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from freeze_browser_compile import fingerprint, prepare, validate
from production_source_manifest import begin, combine, compile_component
from rebuild_browser import repository_state

ROOT = Path(__file__).resolve().parents[1]


def benchmark_entry(root, source):
    """Expose canonical main-module sources as links, never source snapshots."""
    root, source = Path(root).resolve(), Path(source).resolve()
    if not source.is_relative_to(root) or not source.is_file() or not source.name.endswith('_test.v'):
        raise ValueError('Benchmark entry must be a canonical repository test source')
    directory = root / 'Build/v/address-bar-tests'
    directory.mkdir(parents=True, exist_ok=True)
    inputs = [root / 'v.mod', *root.glob('*.h'),
              *(p for p in root.glob('*.v') if not p.name.endswith('_test.v')),
              *(p for p in root.iterdir() if p.is_dir() and p.name != 'Build'), source]
    for path in inputs:
        link = directory / path.name
        if link.is_symlink():
            if link.resolve() == path:
                continue
            link.unlink()
        if link.exists():
            raise ValueError('Refusing to replace a non-link benchmark input: ' + str(link))
        link.symlink_to(path, target_is_directory=path.is_dir())
    return directory / source.name


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def v_tool(name, *arguments):
    return subprocess.check_output(['sh', str(ROOT / 'tools/run_v_tool.sh'), name,
                                    *map(str, arguments)], cwd=ROOT, text=True).strip()


def profile_array_return_compat(source):
    """Preserve fixed-array members in V's profiled optional canvas tuple return.

    V's profile return temporary emits array expressions as positional scalar
    initializers. Named array members retain the original values and ordering.
    Restrict this workaround to the known generated type in diagnostic builds.
    """
    pattern = (r'\(multi_return_Array_fixed_canvas__Rect_2_Array_fixed_int_2\)\{\s*'
               r'\(canvas__Rect\[2\]\)\{([^{}]+)\},\s*\(int\[2\]\)\{([^{}]+)\}\}')
    return re.subn(pattern, lambda m:
        '(multi_return_Array_fixed_canvas__Rect_2_Array_fixed_int_2){.arg0={'
        + m[1] + '}, .arg1={' + m[2] + '}}', source)


def recompile_sealed(args, receipt, output):
    """Change only the inlining policy of already sealed, unprofiled inputs."""
    origin = args.recompile_from.resolve()
    configuration = json.loads((origin / 'configuration.json').read_text())
    if ('-profile' in configuration.get('generation_command', [])
            or configuration['engine'] != args.engine
            or configuration['allocator'] != args.allocator
            or configuration['optimization'] != args.optimization
            or configuration.get('benchmark_mode', 'test') != ('production' if args.production else 'test')
            or configuration['c_mode'] != 'single'):
        raise ValueError('Recompilation requires matching unprofiled sealed inputs')
    data = json.loads((origin / 'frozen-compile.json').read_text())
    validate(origin, data['source_inputs'], require_complete=False)
    command = data['compiler_command']
    if command.count('-o') != 1:
        raise ValueError('Expected one sealed compiler output')
    command[command.index('-o') + 1] = str(output)
    # Keep every compiler argument except the explicitly selected LLVM policy.
    command = [item for index, item in enumerate(command)
               if not item.startswith('-inline-threshold=')
               and not (item == '-mllvm' and index + 1 < len(command)
                        and command[index + 1].startswith('-inline-threshold='))]
    if args.inline_threshold is not None:
        command += ['-mllvm', f'-inline-threshold={args.inline_threshold}']
    configuration.update(inline_threshold=args.inline_threshold,
                         recompiled_from=str(origin))
    data.update(compiler_command=command, complete=False)
    data.pop('compiler_exit', None)
    data['sealed_inputs'].update(fingerprint([origin / name for name in
        ['configuration.json', 'source-manifest.json', 'frozen-compile.json']]))
    save(receipt / 'configuration.json', configuration)
    save(receipt / 'source-manifest.json', json.loads((origin / 'source-manifest.json').read_text()))
    save(receipt / 'frozen-compile.json', data)
    validate(receipt, data['source_inputs'], require_complete=False)
    result = subprocess.run(command, cwd=data['cwd'])
    data.update(compiler_exit=result.returncode, complete=result.returncode == 0)
    save(receipt / 'frozen-compile.json', data)
    if result.returncode:
        return result.returncode
    validate(receipt, data['source_inputs'])
    print(output, flush=True)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True, choices=['v8', 'jsc'])
    parser.add_argument('--entry', type=Path, default=Path('sites/hacker_news_engine_benchmark_test.v'),
                        help='Canonical main-module benchmark test, relative to repository root')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--allocator', choices=['prealloc', 'boehm'], default='prealloc')
    parser.add_argument('--optimization', choices=['O2', 'O3'], default='O3')
    parser.add_argument('--inline-threshold', type=int, help='LLVM inlining threshold; manual production prealloc builds use 1500')
    parser.add_argument('--recompile-from', type=Path,
                        help='Reuse a sealed .build directory, changing only its inlining threshold')
    parser.add_argument('--seal-only', action='store_true',
                        help='Prepare verified C/native inputs without running clang or producing a binary')
    parser.add_argument('--compiler', type=Path, default=Path(os.environ.get('V_BIN', str(Path.home() / 'code/v/v'))))
    parser.add_argument('--v8-adapter', type=Path)
    parser.add_argument('--production', action='store_true',
                        help='Build the Reddit workload through main without V test-mode branches')
    parser.add_argument('--profile', type=Path,
                        help='Diagnostic V -profile output; never use this binary for acceptance timing')
    parser.add_argument('--profile-fns', help='Restrict V profiling to these comma-separated entry functions')
    args = parser.parse_args()
    reddit = args.entry.resolve() == (ROOT / 'sites/reddit_engine_benchmark_test.v').resolve()
    if args.production and not reddit:
        parser.error('--production currently supports the Reddit workload')
    if args.profile_fns and not args.profile:
        parser.error('--profile-fns requires --profile')
    if args.inline_threshold is not None and args.inline_threshold < 1:
        parser.error('Use a positive inlining threshold')
    output = args.output.resolve()
    if output.is_relative_to(ROOT / 'Build'):
        parser.error('Keep private benchmark binaries and generated C outside Build')
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt = output.with_name(output.name + '.build')
    receipt.mkdir(exist_ok=False)
    if args.recompile_from:
        if args.profile or args.profile_fns or args.seal_only:
            parser.error('Sealed recompilation does not add profiling')
        return recompile_sealed(args, receipt, output)
    compiler = args.compiler.resolve()
    if args.allocator == 'prealloc':
        runtime = Path(v_tool('prepare_prealloc_runtime', compiler, ROOT / 'Build/v/prealloc-runtime'))
        compiler = runtime / 'compiler/v'
    ui = v_tool('prepare_ui2', compiler)
    http = v_tool('prepare_http_compat', compiler)
    entry = ROOT if args.production else benchmark_entry(ROOT, ROOT / args.entry)
    cflags = '-' + args.optimization
    backend = []
    if reddit:
        backend += ['-d', 'vox_reddit_engine_benchmark']
    if args.engine == 'v8':
        if not args.v8_adapter or not args.v8_adapter.is_file():
            parser.error('V8 requires --v8-adapter pointing to libVoxJSCOnV8.dylib')
        adapter = args.v8_adapter.resolve()
        link = output.parent / 'libVoxJSCOnV8.dylib'
        if link.exists():
            if hashlib.sha256(link.read_bytes()).digest() != hashlib.sha256(adapter.read_bytes()).digest():
                parser.error('Output directory contains another V8 adapter')
        else:
            link.symlink_to(adapter)
        backend += ['-d', 'vox_v8', '-ldflags', f'-L{adapter.parent} -lVoxJSCOnV8 -Wl,-rpath,{adapter.parent}']
        cflags += f' -I{ROOT}/browserjs/v8/include'
    source, flags = receipt / 'benchmark.c', receipt / 'benchmark.flags'
    component = receipt / 'parsed'
    component.mkdir()
    command = [str(compiler), '-exclude', '@vlib/time/zoneinfo.native.v', '-enable-globals',
               '-d', 'vox_ui2', '-path', f'{ui}|{ROOT}|{http}|@vmodules|@vlib',
               '-cflags', f'-DLARGE_CONFIG=1 -O0 -I{ROOT}', '-w', '-n', '-b', 'c',
               '-no-parallel', '-cc', 'clang', '-memory-limit', '10G', '-prod',
               '-no-prod-options', '-nocache', '-skip-running']
    if args.allocator == 'prealloc':
        command += ['-prealloc', '-gc', 'none']
    if args.profile:
        args.profile.resolve().parent.mkdir(parents=True, exist_ok=True)
        command += ['-profile', str(args.profile.resolve())]
        if args.profile_fns:
            command += ['-profile-fns', args.profile_fns]
    command += [*backend, '-cflags', cflags, '-dump-c-flags', str(flags), '-o', str(source), str(entry)]
    os.environ['VFLAGS'] = ''
    os.environ['CFLAGS'] = ''
    os.environ['LDFLAGS'] = ''
    os.environ['V3_STR_CAP'] = '1'
    os.environ['V_MACOS_V3_NO_FALLBACK'] = '1'
    save(receipt / 'configuration.json', dict(engine=args.engine, allocator=args.allocator,
         optimization=args.optimization, inline_threshold=args.inline_threshold, c_mode='single',
         benchmark_mode='production' if args.production else 'test', generation_command=command))
    save(receipt / 'inputs-before.json', repository_state(ROOT))
    inventory = begin(ROOT)
    save(receipt / 'source-inventory.json', inventory)
    code = compile_component(ROOT, inventory, component, command)
    if code:
        return code
    if args.profile:
        original = source.read_text()
        replacement, count = profile_array_return_compat(original)
        source.write_text(replacement)
        save(receipt / 'profile-c-compat.json', dict(
            fixed_array_returns=count, original_sha256=hashlib.sha256(original.encode()).hexdigest(),
            replacement_sha256=hashlib.sha256(replacement.encode()).hexdigest()))
    manifest = combine(ROOT, inventory, [component], parsed=True)
    save(receipt / 'source-manifest.json', manifest)
    # Native headers and link objects are sealed by the canonical production
    # helper; the large C compile starts after V has exited.
    data = prepare(ROOT, receipt, receipt, source, flags, output,
                   compiler=shutil.which('clang'), source_manifest=manifest,
                   source_inventory=inventory, source_components=[component])
    if args.inline_threshold is not None:
        data['compiler_command'] += ['-mllvm', f'-inline-threshold={args.inline_threshold}']
        save(receipt / 'frozen-compile.json', data)
    validate(receipt, data['source_inputs'], require_complete=False)
    if args.seal_only:
        print(receipt, flush=True)
        return 0
    result = subprocess.run(data['compiler_command'], cwd=data['cwd'])
    data.update(compiler_exit=result.returncode, complete=result.returncode == 0)
    save(receipt / 'frozen-compile.json', data)
    if result.returncode:
        return result.returncode
    validate(receipt, data['source_inputs'])
    print(output, flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
