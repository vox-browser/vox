#!/usr/bin/env python3
"""Compile and execute direct Metal WebGL service tests under the memory guard."""
import argparse
import atexit
import hashlib
import json
import os
import re
import tempfile
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fastc_test_groups(tests):
    """FastC accepts one entry; merge same-package tests without alias rewrites.

    Temporary entries stay beside the originals in the canonical checkout so
    @DIR and module lookup retain their meaning. Conflicting import aliases get
    separate executables. Original inputs and generated entries are both pinned.
    """
    groups = []
    metadata = {}
    for test in tests:
        source = test.read_text()
        module = re.search(r'^module (\w+)\s*$', source, re.M)
        if not module or re.search(r'^import\s*\(', source, re.M):
            raise ValueError('FastC batching requires one-line imports: ' + str(test))
        imports = re.findall(r'^import[^\n]*', source, re.M)
        aliases = {}
        for line in imports:
            match = re.fullmatch(r'import\s+([\w.]+)(?:\s+as\s+(\w+))?\s*', line)
            if not match:
                raise ValueError('Unsupported batch import: ' + line)
            aliases[match[2] or match[1].split('.')[-1]] = match[1]
        metadata[test] = (module[1], imports, source)
        for group, existing in groups:
            if test.parent == group[0].parent and module[1] == metadata[group[0]][0] and all(
                    alias not in existing or existing[alias] == path for alias, path in aliases.items()):
                group.append(test)
                existing.update(aliases)
                break
        else:
            groups.append(([test], aliases))
    entries = []
    for group, _ in groups:
        if len(group) == 1:
            entries.append(group[0])
            continue
        imports = sorted({line for test in group for line in metadata[test][1]})
        parts = ['module ' + metadata[group[0]][0], *imports]
        for test in group:
            body = re.sub(r'^(?:module \w+|import[^\n]*)\s*$', '', metadata[test][2], flags=re.M)
            parts.extend(['// Original: ' + str(test.relative_to(ROOT)), body])
        descriptor, name = tempfile.mkstemp(prefix='metal_batch_', suffix='_test.v', dir=group[0].parent)
        os.close(descriptor)
        entry = Path(name)
        atexit.register(entry.unlink, missing_ok=True)
        entry.write_text('\n\n'.join(parts) + '\n')
        entries.append(entry)
    return [group for group, _ in groups], entries


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--v-bin', type=Path, default=Path.home() / 'code/v/v')
    parser.add_argument('--gc', choices=['both', 'default', 'none'], default='both')
    parser.add_argument('--backend', choices=['c', 'fastc'], default='c')
    parser.add_argument('--service', choices=['metal', 'angle'], default='metal')
    parser.add_argument('--batch', action='store_true', help='Compile all selected tests into one executable using V -file-list')
    parser.add_argument('tests', nargs='*', type=Path)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('The direct Metal backend requires macOS')
    compiler = args.v_bin.expanduser().resolve()
    if not compiler.is_file():
        parser.error('V compiler not found: ' + str(compiler))
    tests = [(ROOT / path).resolve() for path in args.tests] if args.tests else sorted(
        (ROOT / 'webgl').glob('service*_d_vox_direct_metal_test.v'))
    if not tests or any(not path.is_file() or not path.is_relative_to(ROOT) or
                        not path.name.endswith('_test.v') for path in tests):
        parser.error('Tests must be existing repository *_test.v files')
    groups = [tests] if args.batch else [[test] for test in tests]
    entries = [group[0] for group in groups]
    if args.batch and args.backend == 'fastc':
        groups, entries = fastc_test_groups(tests)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = {Path(__file__).resolve(), ROOT / 'tools/run_memory_bounded.py', compiler, *tests, *entries}
    for path in (ROOT / 'webgl').rglob('*'):
        if path.is_file() and path.suffix in ['.v', '.h', '.m'] and not path.name.endswith('_test.v'):
            inputs.add(path)
    pins = {str(path): digest(path) for path in sorted(inputs)}
    report = dict(pins=pins, selected_tests=[str(path.relative_to(ROOT)) for path in tests], service=args.service, batch=args.batch, jobs=[], passed=False)
    environment = os.environ.copy()
    if args.backend == 'fastc':
        environment['VJOBS'] = '1'  # Native header state must live in one FastC C unit.
    modes = ['default', 'none'] if args.gc == 'both' else [args.gc]
    report['batch_groups'] = [[str(path.relative_to(ROOT)) for path in group] for group in groups]
    for group_index, group in enumerate(groups):
        test = entries[group_index]
        stem = ('combined-webgl' + (f'-{group_index}' if len(groups)>1 else '')) if args.batch else test.stem
        for gc in modes:
            binary = output / (stem + '-' + gc)
            command = [str(compiler), '-w', '-new-compiler', '-skip-running', '-b', args.backend,
                       '-cc', 'clang', '-cflags', '-O0 -ObjC' if args.backend == 'fastc' else '-O0', '-memory-limit', '10G', '-enable-globals',
                       *(['-d', 'vox_direct_metal'] if args.service == 'metal' else []),
                       *(['-file-list', ','.join(str(path) for path in group[1:])] if len(group)>1 and args.backend == 'c' else []),
                       *(['-gc', 'none'] if gc == 'none' else []),
                       '-o', str(binary), str(test)]
            for phase, invocation in [('compile', command), ('runtime', [str(binary)])]:
                label = stem + '-' + gc + '-' + phase
                guard = [sys.executable, str(ROOT / 'tools/run_memory_bounded.py'),
                         '--limit-gib', '12' if phase == 'compile' else '3',
                         '--timeout', '300' if phase == 'compile' else '120',
                         '--lock', str(output / (label + '.lock')),
                         '--report', str(output / (label + '.json')), '--', *invocation]
                result = subprocess.run(guard, cwd=ROOT, env=environment, text=True, capture_output=True)
                (output / (label + '.log')).write_text(result.stdout + result.stderr)
                report['jobs'].append(dict(test=str(test.relative_to(ROOT)), gc=gc, phase=phase,
                    command=invocation, exit=result.returncode))
                report['changed_inputs'] = [name for name, pin in pins.items() if digest(Path(name)) != pin]
                (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
                if result.returncode or report['changed_inputs']:
                    print(label + ': failed', flush=True)
                    print((result.stdout + result.stderr)[-12000:])
                    if report['changed_inputs']:
                        print('Inputs changed: ' + ', '.join(report['changed_inputs']))
                    return result.returncode or 1
            print((f'{len(group)} combined files' if args.batch else str(test.relative_to(ROOT))) + ' gc=' + gc + ': passed', flush=True)
    report['passed'] = True
    (output / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
