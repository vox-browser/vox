#!/usr/bin/env python3
"""Build one HN benchmark backend, sealing C before optimizing it.

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

from freeze_browser_compile import prepare, validate
from production_source_manifest import begin, combine, compile_component
from rebuild_browser import repository_state

ROOT = Path(__file__).resolve().parents[1]


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', required=True, choices=['v8', 'jsc'])
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--allocator', choices=['prealloc', 'boehm'], default='prealloc')
    parser.add_argument('--optimization', choices=['O2', 'O3'], default='O3')
    parser.add_argument('--inline-threshold', type=int, help='LLVM inlining threshold; manual production prealloc builds use 1500')
    parser.add_argument('--compiler', type=Path, default=Path(os.environ.get('V_BIN', str(Path.home() / 'code/v/v'))))
    parser.add_argument('--v8-adapter', type=Path)
    parser.add_argument('--profile', type=Path,
                        help='Diagnostic V -profile output; never use this binary for acceptance timing')
    parser.add_argument('--profile-fns', help='Restrict V profiling to these comma-separated entry functions')
    args = parser.parse_args()
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
    compiler = args.compiler.resolve()
    if args.allocator == 'prealloc':
        runtime = Path(v_tool('prepare_prealloc_runtime', compiler, ROOT / 'Build/v/prealloc-runtime'))
        compiler = runtime / 'compiler/v'
    ui = v_tool('prepare_ui2', compiler)
    http = v_tool('prepare_http_compat', compiler)
    entry = ROOT / 'Build/v/address-bar-tests/hacker_news_engine_benchmark_test.v'
    if not entry.is_file():
        parser.error('Initialize canonical test links with tools/test_address_bar.sh first')
    cflags = '-' + args.optimization
    backend = []
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
        backend = ['-d', 'vox_v8', '-ldflags', f'-L{adapter.parent} -lVoxJSCOnV8 -Wl,-rpath,{adapter.parent}']
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
         optimization=args.optimization, inline_threshold=args.inline_threshold, c_mode='single', generation_command=command))
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
