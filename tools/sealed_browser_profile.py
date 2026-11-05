#!/usr/bin/env python3
"""Build a diagnostic profiler from completed, sealed production C inputs.

Run through run_memory_bounded.py. No V source regeneration, app copy or shared
production build is performed. Timings include instrumentation and native waits;
they are main-thread leads, never unprofiled instruction/performance credit.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = Path(__file__).with_suffix('.c')
ENTRY = re.compile(r'^void main__main\(void\) \{', re.M)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def inject_entry(source):
    if 'vox_cprofile_start' in source:
        raise ValueError('Already instrumented source')
    legacy = list(ENTRY.finditer(source))
    if len(legacy) == 1:
        position, name = legacy[0].end(), 'main__main'
    else:
        modern = list(re.finditer(r'^int main\(int argc, char\*\* argv\) \{', source, re.M))
        if legacy or len(modern) != 1:
            raise ValueError('Expected one supported browser entry definition')
        # Current V emits the user entry directly in C main after module init.
        init = source.find('\n _vinit();', modern[0].end(), modern[0].end() + 8192)
        if init < 0:
            raise ValueError('Missing module initialization boundary')
        position, name = init + len('\n _vinit();'), 'main'
    return (source[:position] + '\n extern void vox_cprofile_start(void *);'
            '\n vox_cprofile_start((void *)&' + name + ');' + source[position:])


def profile_command(command, source, replacement, helper, binary, libraries):
    if command.count(str(source)) != 1 or command.count('-o') != 1:
        raise ValueError('Unexpected sealed compiler command')
    result = []
    index = 0
    while index < len(command):
        token = command[index]
        if token == '-o':
            result += ['-x', 'none', str(helper), '-finstrument-functions-after-inlining',
                       '-O1', '-o', str(binary)]
            index += 2
            continue
        if token == str(source):
            token = str(replacement)
        elif re.fullmatch(r'-O[0-3szgfast]+', token):
            token = '-O1'
        elif token.startswith('-l') and token[2:] in libraries:
            token = str(libraries[token[2:]])
        result.append(token)
        index += 1
    return result


def resolve_library(path, expected):
    original = Path(path)
    candidates = [original]
    if not original.exists() and '.production-output-' in str(original):
        # Signing the app can change the dylib's bytes. Prefer the exact
        # unsigned linker input retained by the canonical build cache.
        candidates += [ROOT / 'Build/v' / original.name,
                       ROOT / 'Build/v/Vox.app/Contents/MacOS' / original.name]
    for candidate in candidates:
        if candidate.is_file() and digest(candidate) == expected:
            return candidate
    raise ValueError('No byte-identical linker library: ' + path)


def parse_profile(text):
    metadata = [json.loads(line.removeprefix('VOX_CPROFILE_META '))
                for line in text.splitlines() if line.startswith('VOX_CPROFILE_META ')]
    rows = [json.loads(line.removeprefix('VOX_CPROFILE '))
            for line in text.splitlines() if line.startswith('VOX_CPROFILE ')]
    if len(metadata) != 1 or metadata[0]['faults'] or not rows:
        raise ValueError('Missing or unbalanced C profile')
    if len({r['address'] for r in rows}) != len(rows):
        raise ValueError('Duplicate profile address')
    for row in rows:
        if not (row['calls'] > 0 and 0 <= row['partial_calls'] <= row['calls']
                and 0 <= row['self_ns'] <= row['inclusive_ns']):
            raise ValueError('Invalid profile counters')
    return dict(metadata=metadata[0], rows=rows,
                self=sorted(rows, key=lambda r: r['self_ns'], reverse=True),
                inclusive=sorted(rows, key=lambda r: r['inclusive_ns'], reverse=True))


def build(receipt, out):
    production = json.loads(receipt.read_text())
    frozen_path = Path(production['frozen_compilation'])
    frozen = json.loads(frozen_path.read_text())
    if not (production['exit'] == 0 and frozen['complete'] and frozen['compiler_exit'] == 0
            and production['c_compile']['mode'] == 'single'):
        raise ValueError('Need a completed single-unit production receipt')
    if digest(production['executable']) != production['executable_sha256']:
        raise ValueError('Canonical executable does not match receipt')
    pins = dict(frozen['sealed_inputs'])
    libraries = {}
    for name, path in frozen['resolved_libraries'].items():
        expected = frozen['live_inputs'][path]
        p = resolve_library(path, expected)
        pins[str(p)] = expected
        if name.startswith('library:'):
            libraries[name.removeprefix('library:')] = p
    pins[str(frozen_path)] = digest(frozen_path)
    pins[str(HELPER)] = digest(HELPER)
    pins[str(Path(__file__))] = digest(__file__)
    pins[frozen['compiler']] = frozen['live_inputs'][frozen['compiler']]
    for path, expected in pins.items():
        if digest(path) != expected:
            raise ValueError('Changed sealed/link input: ' + path)
    source = Path(next(p for p in frozen['sealed_inputs'] if p.endswith('/0-Vox.c.i')))
    out.mkdir(parents=True, exist_ok=False)
    result = dict(complete=False, diagnostic=True, acceptance=False, instruction_credit=0,
                  production=production, inputs_before=pins, compiler_command=None)
    def save():
        (out / 'build.json').write_text(json.dumps(result, indent=2) + '\n')
    try:
        generated = out / 'profile.c.i'
        generated.write_text(inject_entry(source.read_text()))
        helper = out / 'profile-helper.o'
        result['helper_command'] = [frozen['compiler'], '-O2', '-Wall', '-Wextra', '-Werror',
                                    '-c', str(HELPER), '-o', str(helper)]
        subprocess.run(result['helper_command'], check=True)
        binary = out / 'Vox-profile'
        command = profile_command(frozen['compiler_command'], source, generated, helper,
                                  binary, libraries)
        result['compiler_command'] = command
        result['generated_sha256'] = digest(generated)
        result['helper_sha256'] = digest(helper)
        save()
        result['compiler_exit'] = subprocess.run(command, cwd=frozen['cwd']).returncode
        if result['compiler_exit']:
            raise RuntimeError('Instrumented compiler failed')
        subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements',
                        str(ROOT / 'packaging/Vox.entitlements.plist'), str(binary)], check=True)
        for path, expected in pins.items():
            if digest(path) != expected:
                raise ValueError('Changed sealed/link input after build: ' + path)
        result.update(complete=True, executable_sha256=digest(binary))
    finally:
        save()
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, default=ROOT / 'Build/production-build/latest.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.receipt.resolve(), args.output.resolve())


if __name__ == '__main__':
    main()
