#!/usr/bin/env python3
"""Run explicitly selected same-module font batches without changing staging."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--group', choices=['skia_focused', 'layout_integration', 'platform_font_integration'], required=True)
    parser.add_argument('--gc', choices=['boehm', 'none'], nargs='+', required=True)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    base = repo / 'Build/reddit-optimization'
    selection = json.loads((base / 'font-validation-selection.json').read_text())
    group = next(group for group in selection['groups'] if group['name'] == args.group)
    files = [repo / path for path in group['files']]
    compiler = repo.parent / 'v/v'
    linux_modules = repo / 'Build/linux/modules'
    http_modules = repo / 'Build/v/httpcompat/32bae206d5ba729b/modules'
    assert linux_modules.is_dir() and http_modules.is_dir()
    paths = f'{repo}|{linux_modules}|{http_modules}|@vmodules|@vlib'
    expected = []
    for path in files:
        for name in re.findall(r'^fn (test_[A-Za-z0-9_]+)\(', path.read_text(), re.M):
            expected.append({'file': str(path.relative_to(repo)), 'function': name})
    assert len(expected) == group['declared_test_functions']
    root = Path(tempfile.mkdtemp(prefix=args.group + '-', dir=base))
    print(f'Validation output: {root}', flush=True)
    env = dict(os.environ)
    removed = {}
    for name in ['VFLAGS', 'VTEST_ONLY', 'VTEST_ONLY_FN', 'VTEST_RUNNER', 'VTEST_SHOW_ASSERTS',
                 'LADYBIRD_SOURCE_ROOT', 'LADYBIRD_LAYOUT_TEST_FONT', 'LADYBIRD_BROWSER_FONT',
                 'LADYBIRD_BROWSER_DEFAULT_FONT']:
        if name in env:
            removed[name] = env.pop(name)
    env.update(V_C_ERROR_BUG_REPORT_DISABLED='1', V_MACOS_V3_NO_FALLBACK='1')
    env['PKG_CONFIG_PATH'] = str(repo / 'Build/deps/lib/pkgconfig') + ':' + env.get('PKG_CONFIG_PATH', '')
    cflags = '-D_GNU_SOURCE=1 -Werror=incompatible-pointer-types -Werror=incompatible-function-pointer-types -Wno-error=incompatible-pointer-types-discards-qualifiers'
    pin_paths = [*files, compiler, repo / 'Build/linux/native/skia.a', repo / 'Build/linux/native/stbi.a',
                 repo / 'skia/shadow_raster.cpp', repo / 'skia/shadow_typeface_cache.h', Path(__file__).resolve()]
    pins = {str(path): digest(path) for path in pin_paths}
    save(root / 'inputs.json', {'pins': pins, 'selected': expected, 'known_linux_skips': [
        'test_source_skia_font_decoder_loads_real_truetype_data'
    ] if args.group == 'skia_focused' else [], 'removed_child_environment': removed,
        'module_paths': paths, 'production_archive': str(repo / 'Build/linux/native/skia.a')})
    records = []

    def execute(command, environment, output, label, limit):
        guard = [sys.executable, str(repo / 'tools/run_memory_bounded.py'), '--limit-gib', str(limit),
                 '--lock', str(output / (label + '.lock')), '--report', str(output / (label + '.guard.json')),
                 '--', *command]
        started = time.monotonic()
        with (output / (label + '.log')).open('w') as log:
            result = subprocess.run(guard, cwd=repo, env=environment, stdout=log, stderr=subprocess.STDOUT)
        record = {'label': label, 'command': command, 'guard_command': guard, 'exit': result.returncode,
                  'seconds': time.monotonic() - started}
        save(output / (label + '.command.json'), record)
        return result.returncode

    for gc in args.gc:
        output = root / gc
        output.mkdir()
        temporary = output / 'vtmp'
        temporary.mkdir()
        compile_env = dict(env, VTMP=str(temporary))
        binary = output / ('font_tests_' + gc)
        command = [str(compiler), '-new-compiler', '-memory-limit', '10G', '-enable-globals', '-keepc',
                   '-cc', 'clang-18', '-cstrict', '-cflags', cflags, '-gc', gc, '-d', 'use_openssl',
                   '-exclude', '@vlib/time/zoneinfo.native.v', '-path', paths]
        if gc == 'boehm':
            command += ['-d', 'dynamic_boehm']
        command += ['-o', str(binary)]
        if len(files) > 1:
            command += ['-file-list', ','.join(map(str, files[1:]))]
        command += [str(files[0])]
        print(f'Compiling {args.group} gc={gc} ({len(expected)} declared functions)', flush=True)
        build_exit = execute(command, compile_env, output, 'compile', 12)
        record = {'group': args.group, 'gc': gc, 'compile_exit': build_exit, 'runtime_exit': None, 'passed': False}
        records.append(record)
        if build_exit:
            save(root / 'results.json', {'passed': False, 'attempts': records})
            print(f'Compile failed: {output / "compile.log"}', flush=True)
            return 1
        kept = list(temporary.glob('*.tmp.c'))
        assert len(kept) == 1, kept
        generated = kept[0].read_text()
        marker = 'int main(int argc, char** argv) {'
        main_start = generated.rfind(marker)
        assert main_start >= 0
        main_text = generated[main_start:]
        harness = []
        for item in expected:
            assert re.search(r'\b[A-Za-z0-9_]*' + re.escape(item['function']) + r'\(\)', main_text), item
            harness.append(item)
        slots = re.findall(r'int __test_failures_before_(\d+) = __test_failures;', main_text)
        assert len(slots) == len(expected), slots
        save(output / 'harness.json', {'generated_c': str(kept[0]), 'sha256': digest(kept[0]),
             'registered_test_count': len(slots), 'registered_tests': harness,
             'known_linux_early_return_count': group['expected_platform_skips'],
             'verification': 'Selected tests have explicit calls in the unchanged generated C main; zero runtime exit verifies the complete harness.'})
        runtime_env = dict(env, LADYBIRD_SOURCE_ROOT=str(base / 'test-font-resources'))
        record['binary_sha256'] = digest(binary)
        record['registered_test_count'] = len(slots)
        record['known_linux_early_return_count'] = group['expected_platform_skips']
        record['runtime_environment'] = {'LADYBIRD_SOURCE_ROOT': runtime_env['LADYBIRD_SOURCE_ROOT']}
        record['runtime_exit'] = execute([str(binary)], runtime_env, output, 'runtime', 3)
        changed = [path for path, value in pins.items() if not Path(path).is_file() or digest(path) != value]
        record['changed_inputs'] = changed
        record['passed'] = record['runtime_exit'] == 0 and not changed
        save(root / 'results.json', {'passed': all(item['passed'] for item in records), 'attempts': records})
        print(f'{"PASS" if record["passed"] else "FAIL"}: {args.group} gc={gc}; {len(slots)} registered, {group["expected_platform_skips"]} known platform early-return', flush=True)
        if not record['passed']:
            return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
