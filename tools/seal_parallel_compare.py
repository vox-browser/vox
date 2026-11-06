#!/usr/bin/env python3
"""Clang interposer that seals V's actual split plan, without optimizing it.

Set VOX_SEAL_PARALLEL_DIR and VOX_SEAL_REAL_CLANG and put a launcher named
clang on PATH. Only V's generated unit_N.c compiles and their final link are
intercepted. Other compiler work runs normally. Placeholder outputs are never
executables; compile_plan() replaces them with actual compiled outputs later.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

from freeze_browser_compile import (PREPROCESSED_LANGUAGES, check_fingerprints,
                                    compile_options, digest, fingerprint, parse_flags,
                                    preprocess_flags, resolved_libraries, seal_object)


def without_output(arguments):
    result = list(arguments)
    index = result.index('-o')
    output = Path(result[index + 1]).resolve()
    del result[index:index + 2]
    return result, output


def capture(arguments, directory, compiler):
    directory = Path(directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    generated = [Path(x).resolve() for x in arguments
                 if re.fullmatch(r'unit_\d+\.c', Path(x).name)]
    units = [Path(x).resolve() for x in arguments
             if re.fullmatch(r'unit_\d+\.o', Path(x).name)]
    if not generated and not units:
        return subprocess.call([compiler, *arguments])
    flags, output = without_output(arguments)
    is_compile = '-c' in flags
    if is_compile:
        flags.remove('-c')
    if is_compile != bool(generated) or len(generated) > 1:
        raise ValueError('Unrecognized split compiler invocation')
    parts = parse_flags(flags, Path.cwd())
    pp_flags = preprocess_flags(parts)
    command = [compiler]
    sealed = []
    name = generated[0].stem if generated else 'link'
    for index, (kind, value) in enumerate(parts):
        if kind == 'source':
            source, language = value
            destination = directory / f'{name}-{index}.i'
            before = digest(source)
            subprocess.run([compiler, *pp_flags, '-Qunused-arguments', '-x', language,
                            '-E', str(source), '-o', str(destination)], check=True)
            if digest(source) != before:
                raise RuntimeError('Generated source changed while preprocessing')
            sealed.append(destination)
            command.extend(['-x', PREPROCESSED_LANGUAGES[language], str(destination), '-x', 'none'])
        elif kind == 'object':
            if value in units:
                destination = directory / value.name
            else:
                destination = directory / f'{name}-{index}-{value.name}'
                seal_object(value, destination)
                sealed.append(destination)
            command.append(str(destination))
        elif kind == 'library':
            command.append(str(value))
        else:
            command.extend(compile_options(value))
    actual_output = directory / (output.name if is_compile else 'Vox')
    command.extend((['-c'] if is_compile else []) + ['-o', str(actual_output)])
    libraries = resolved_libraries(parts, Path.cwd()) if not is_compile else {}
    record = dict(generation_only=True, original_arguments=arguments, cwd=str(Path.cwd()),
                  command=command, output=str(actual_output), sealed=fingerprint(sealed),
                  live=fingerprint([compiler, *libraries.values()]), units=[x.name for x in units])
    (directory / (name + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    # The V driver needs an output to finish its generation phase. Deliberately
    # non-executable and invalid as an object, so accidental use fails closed.
    output.write_bytes(b'VOX_GENERATION_ONLY_NOT_COMPILED\n')
    return 0


def compile_plan(directory, jobs=4):
    directory = Path(directory)
    link = json.loads((directory / 'link.json').read_text())
    records = [json.loads((directory / (Path(unit).stem + '.json')).read_text())
               for unit in link['units']]
    if not records:
        raise RuntimeError('No generated split units')
    for record in [*records, link]:
        check_fingerprints(record['sealed'])
        check_fingerprints(record['live'])
    def compile_one(record):
        with (directory / (Path(record['output']).stem + '.log')).open('w') as stream:
            subprocess.run(record['command'], cwd=record['cwd'], stdout=stream,
                           stderr=subprocess.STDOUT, check=True)
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        list(pool.map(compile_one, records))
    compile_one(link)
    for record in [*records, link]:
        check_fingerprints(record['sealed'])
        check_fingerprints(record['live'])
    (directory / 'compiled.json').write_text(json.dumps(dict(
        complete=True, units=len(records), executable=link['output'],
        sha256=digest(link['output'])), indent=2) + '\n')


if __name__ == '__main__':
    if sys.argv[1:2] == ['--compile']:
        compile_plan(sys.argv[2])
    else:
        raise SystemExit(capture(sys.argv[1:], os.environ['VOX_SEAL_PARALLEL_DIR'],
                                 os.environ['VOX_SEAL_REAL_CLANG']))
