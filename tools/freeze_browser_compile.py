#!/usr/bin/env python3
"""Seal generated compiler inputs before optimizing a canonical macOS build.

Only generated C/preprocessed C and link objects are retained. Repository tools
and source trees are never copied. A changed source receipt before sealing, or
a changed live linker/packaging input afterwards, rejects the build.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shlex
import shutil
import subprocess

PROTOCOL = 'preprocessed-c-v1'
SOURCE_LANGUAGES = {'.c': 'c', '.m': 'objective-c', '.cc': 'c++', '.cpp': 'c++',
                    '.cxx': 'c++', '.mm': 'objective-c++'}
PREPROCESSED_LANGUAGES = {'c': 'cpp-output', 'objective-c': 'objective-c-cpp-output',
                          'c++': 'c++-cpp-output', 'objective-c++': 'objective-c++-cpp-output'}
OPTION_ARGUMENTS = {'-I', '-L', '-F', '-D', '-U', '-isystem', '-iquote', '-idirafter',
                    '-isysroot', '--sysroot', '-include', '-imacros',
                    '-framework', '-weak_framework', '-arch',
                    '-target', '-stdlib', '-isystem-after'}
SYSTEM_LIBRARIES = {'System', 'c', 'm', 'pthread', 'objc', 'z', 'iconv', 'c++',
                    'resolv', 'dl'}


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(chunk)
    return value.hexdigest()


def fingerprint(paths):
    return {str(Path(path).resolve()): digest(path) for path in sorted(set(map(Path, paths)))}


def check_fingerprints(expected):
    for name, value in expected.items():
        if not Path(name).is_file() or digest(name) != value:
            raise RuntimeError('Frozen build input changed: ' + name)


def parse_flags(flags, cwd):
    """Keep option operands distinct from sources and preserve source languages."""
    cwd = Path(cwd)
    parts = []
    language = 'none'
    index = 0
    while index < len(flags):
        token = flags[index]
        if token.startswith('-Wl,'):
            linker = token.split(',')[1:]
            if not (len(linker) == 2 and linker[0] in ('-rpath', '-stack_size')
                    or linker and all(item in ('-dead_strip', '-dead_strip_dylibs',
                                               '-search_paths_first', '-no_compact_unwind')
                                      for item in linker)):
                raise ValueError('Unsupported linker option in frozen build: ' + token)
        if token == '-x':
            if index + 1 == len(flags):
                raise ValueError('Missing -x language')
            language = flags[index + 1]
            parts.append(('option', [token, language]))
            index += 2
            continue
        if token in OPTION_ARGUMENTS:
            if index + 1 == len(flags):
                raise ValueError('Missing operand for ' + token)
            parts.append(('option', flags[index:index + 2]))
            index += 2
            continue
        if token in ('-o', '-E', '-c', '-S'):
            raise ValueError('Unexpected output/action in dumped flags: ' + token)
        if token.startswith('@') or token.startswith(('-fmodule', '-fplugin', '-fpass-plugin',
                                                       '-fprofile', '-B', '-specs=')) \
                or token in ('-Xclang', '-Xpreprocessor', '-Xlinker', '-include-pch') \
                or token.startswith(('-Wl,@', '-Wl,-filelist', '-Wl,-force_load',
                                     '-Wl,-bundle_loader', '-Wl,-lto_library', '-Wl,-sectcreate')):
            raise ValueError('Unsealed response file or module flag: ' + token)
        path = Path(token)
        if not path.is_absolute():
            path = cwd / path
        if not token.startswith('-') and path.suffix in SOURCE_LANGUAGES:
            if not path.is_file():
                raise FileNotFoundError(path)
            selected = SOURCE_LANGUAGES[path.suffix] if language == 'none' else language
            if selected not in PREPROCESSED_LANGUAGES:
                raise ValueError('Unsupported source language: ' + selected)
            parts.append(('source', (path.resolve(), selected)))
        elif not token.startswith('-') and path.suffix in ('.o', '.a', '.dylib', '.tbd'):
            if not path.is_file():
                raise FileNotFoundError(path)
            parts.append(('object' if path.suffix in ('.o', '.a') else 'library', path.resolve()))
        elif token.startswith('-'):
            parts.append(('option', [token]))
        else:
            raise ValueError('Unrecognized compiler operand: ' + token)
        index += 1
    return parts


def preprocess_flags(parts):
    return [token for kind, value in parts if kind == 'option' and value[0] != '-x'
            for token in value]


def compile_options(value):
    # Forced includes were expanded during preprocessing. Reapplying them to a
    # preprocessed translation unit can both reread live headers and duplicate
    # declarations. Search paths/macros otherwise have no preprocessing work.
    if value[0] in ('-include', '-imacros', '-include-pch'):
        return []
    if value[0].startswith(('-include', '-imacros')) and len(value) == 1:
        raise ValueError('Unsupported attached forced-include flag')
    return value


def resolved_libraries(parts, cwd):
    directories, frameworks, names, libraries = [], [], [], []
    for kind, value in parts:
        if kind == 'library':
            libraries.append(('file:' + str(value), value))
        if kind != 'option':
            continue
        token = value[0]
        if token in ('-framework', '-weak_framework'):
            names.append(value[1])
        if token == '-F' or token.startswith('-F') and len(token) > 2:
            directory = Path(value[1] if token == '-F' else token[2:])
            frameworks.append((directory if directory.is_absolute() else Path(cwd) / directory).resolve())
        if token == '-L':
            directory = Path(value[1])
        elif token.startswith('-L') and len(token) > 2:
            directory = Path(token[2:])
        else:
            continue
        directories.append((directory if directory.is_absolute() else Path(cwd) / directory).resolve())
    for kind, value in parts:
        if kind != 'option' or not value[0].startswith('-l') or len(value[0]) <= 2:
            continue
        name = value[0][2:]
        found = next((folder / ('lib' + name + suffix) for folder in directories
                      for suffix in ('.dylib', '.tbd', '.a')
                      if (folder / ('lib' + name + suffix)).is_file()), None)
        if found is not None:
            libraries.append(('library:' + name, found.resolve()))
        elif name not in SYSTEM_LIBRARIES:
            raise RuntimeError('Cannot pin linker library: ' + name)
    if names:
        sysroot = None
        for kind, value in parts:
            if kind == 'option' and value[0] in ('-isysroot', '--sysroot'):
                sysroot = value[1]
            elif kind == 'option' and value[0].startswith('--sysroot='):
                sysroot = value[0].split('=', 1)[1]
        sdk = Path(sysroot or subprocess.check_output(['xcrun', '--show-sdk-path'], text=True).strip())
        settings = sdk / 'SDKSettings.json'
        if settings.is_file():
            libraries.append(('sdk-settings', settings))
        for name in names:
            selected = next((folder / (name + '.framework') for folder in frameworks
                             if (folder / (name + '.framework')).is_dir()),
                            sdk / 'System/Library/Frameworks' / (name + '.framework'))
            binary = selected / name
            stubs = sorted(selected.rglob('*.tbd')) if selected.is_dir() else []
            if binary.is_file():
                libraries.append(('framework:' + name, binary.resolve()))
            elif stubs:
                libraries.extend(('framework:' + name + ':' + str(path.relative_to(selected)), path)
                                 for path in stubs)
            else:
                raise RuntimeError('Cannot pin linker framework: ' + name)
    return {key: str(path.resolve()) for key, path in libraries}


def staging_inputs(stage):
    stage = Path(stage)
    return [path for path in (stage / 'Vox.app').rglob('*') if path.is_file()] + list(stage.glob('*.dylib'))


def seal_object(source, destination):
    before = digest(source)
    shutil.copyfile(source, destination)
    if digest(destination) != before or digest(source) != before:
        raise RuntimeError('Link object changed while sealing: ' + str(source))
    return before


def prepare(root, stage, receipt, source, flags_path, output, compiler='clang', run=subprocess.run,
            source_manifest=None, source_inventory=None, source_components=None):
    from rebuild_browser import repository_state, same_build_inputs, write_json
    root, stage, receipt = map(lambda value: Path(value).resolve(), (root, stage, receipt))
    source, flags_path, output = map(lambda value: Path(value).resolve(), (source, flags_path, output))
    before = json.loads((receipt / 'inputs-before.json').read_text())
    def check_sources():
        if source_components:
            from production_source_manifest import combine
            if combine(root, source_inventory, source_components, parsed=True) != source_manifest:
                raise RuntimeError('Parsed source proof does not match compiler inputs')
        else:
            check_fingerprints(source_manifest)
    if source_inventory is not None:
        from production_source_manifest import validate_inventory
        validate_inventory(root, source_inventory, parsed=bool(source_components))
    if source_manifest is not None:
        check_sources()
    elif not same_build_inputs(before, repository_state(root)):
        raise RuntimeError('Repository inputs changed before C preprocessing')
    cwd = Path.cwd()
    compiler_path = Path(shutil.which(compiler) or compiler).resolve(strict=True)
    parts = parse_flags(shlex.split(flags_path.read_text()), cwd)
    frozen = receipt / 'frozen-compiler-inputs'
    frozen.mkdir()
    pp_options = preprocess_flags(parts)
    sources = [(source, 'objective-c')] + [value for kind, value in parts if kind == 'source']
    preprocessed, objects, original_objects = {}, {}, {}
    commands = []
    for index, (path, language) in enumerate(sources):
        source_digest = digest(path)
        destination = frozen / f'{index}-{path.name}.i'
        command = [str(compiler_path), *pp_options, '-Qunused-arguments', '-x', language,
                   '-E', str(path), '-o', str(destination)]
        commands.append(command)
        write_json(receipt / 'preprocess-commands.json', commands)
        run(command, check=True)
        if digest(path) != source_digest:
            raise RuntimeError('C source changed during preprocessing: ' + str(path))
        preprocessed[str(path)] = (str(destination), PREPROCESSED_LANGUAGES[language])
    for index, (kind, value) in enumerate(parts):
        if kind != 'object':
            continue
        destination = frozen / f'link-{index}-{value.name}'
        original_objects[str(value)] = seal_object(value, destination)
        objects[str(value)] = str(destination)
    libraries = resolved_libraries(parts, cwd)
    late = staging_inputs(stage) + [root / 'packaging/Vox.entitlements.plist',
                                   root / 'tools/localize_bundle_rpaths.py', compiler_path]
    live_inputs = fingerprint(late + [Path(name) for name in libraries.values()])
    sealed_inputs = fingerprint([source, flags_path] + list(frozen.iterdir()))
    if source_components:
        sealed_inputs.update(fingerprint([directory / name for directory in source_components
                                          for name in ['v_sources', 'v_source_digests', 'parsed-verified.json']]))
    after = repository_state(root)
    if source_inventory is not None:
        validate_inventory(root, source_inventory, parsed=bool(source_components))
    if source_manifest is not None:
        check_sources()
    elif not same_build_inputs(before, after):
        raise RuntimeError('Repository inputs changed while sealing compiler inputs')
    command = [str(compiler_path), '-x', preprocessed[str(source)][1], preprocessed[str(source)][0], '-x', 'none']
    for kind, value in parts:
        if kind == 'source':
            path, language = preprocessed[str(value[0])]
            command.extend(['-x', language, path, '-x', 'none'])
        elif kind == 'object':
            command.append(objects[str(value)])
        elif kind == 'library':
            command.append(str(value))
        else:
            command.extend(compile_options(value))
    command.extend(['-o', str(output)])
    result = dict(protocol=PROTOCOL, source_inputs=before if source_manifest is not None else after, cwd=str(cwd),
                  compiler=str(compiler_path), compiler_command=command,
                  flags_parts=[(kind, str(value) if kind in ('object', 'library') else
                                [str(value[0]), value[1]] if kind == 'source' else value)
                               for kind, value in parts],
                  resolved_libraries=libraries, live_inputs=live_inputs, sealed_inputs=sealed_inputs,
                  original_objects=original_objects, complete=False)
    if source_manifest is not None:
        result['exact_source_manifest'] = source_manifest
        result['source_inputs_at_sealing'] = after
        if source_components:
            # This identity describes the consumed buffers, which may precede
            # later checkout edits. Never call the later checkout the compiled
            # source. Its ordinary repository receipt remains informational.
            result['repository_at_sealing'] = after
            result['source_inputs_at_sealing'] = dict(head=after['head'], dirty=True,
                source_kind='verified parsed buffers and sealed native inputs',
                build_inputs_sha256=hashlib.sha256(json.dumps(source_manifest, sort_keys=True).encode()).hexdigest())
    if source_inventory is not None:
        result['source_inventory'] = source_inventory
    write_json(receipt / 'frozen-compile.json', result)
    return result


def validate(receipt, expected, require_complete=True):
    from rebuild_browser import same_build_inputs
    receipt = Path(receipt)
    data = json.loads((receipt / 'frozen-compile.json').read_text())
    if data.get('protocol') != PROTOCOL or not same_build_inputs(data.get('source_inputs', {}), expected):
        raise RuntimeError('Frozen compilation source receipt does not match build inputs')
    if require_complete and (data.get('complete') is not True or data.get('compiler_exit') != 0):
        raise RuntimeError('Frozen compilation did not complete successfully')
    if not data.get('sealed_inputs') or not data.get('live_inputs') or not data.get('compiler_command'):
        raise RuntimeError('Frozen compilation input manifest is incomplete')
    check_fingerprints(data['sealed_inputs'])
    check_fingerprints(data['live_inputs'])
    parts = []
    for kind, value in data['flags_parts']:
        parts.append((kind, (Path(value[0]), value[1]) if kind == 'source' else
                      Path(value) if kind in ('object', 'library') else value))
    if resolved_libraries(parts, data['cwd']) != data['resolved_libraries']:
        raise RuntimeError('Link library search resolution changed after sealing')
    return data


def main():
    from rebuild_browser import write_json
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('root', 'stage', 'receipt', 'source', 'flags', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--source-manifest', type=Path)
    parser.add_argument('--source-inventory', type=Path)
    parser.add_argument('--parsed-component', action='append', type=Path)
    args = parser.parse_args()
    if bool(args.source_manifest) != bool(args.source_inventory):
        parser.error('source manifest and source inventory must be supplied together')
    if args.parsed_component and not args.source_manifest:
        parser.error('parsed components require source manifest and inventory')
    data = prepare(args.root, args.stage, args.receipt, args.source, args.flags, args.output,
                   source_manifest=json.loads(args.source_manifest.read_text()) if args.source_manifest else None,
                   source_inventory=json.loads(args.source_inventory.read_text()) if args.source_inventory else None,
                   source_components=args.parsed_component)
    validate(args.receipt, data['source_inputs'], require_complete=False)
    result = subprocess.run(data['compiler_command'], cwd=data['cwd'])
    data.update(compiler_exit=result.returncode, complete=result.returncode == 0)
    write_json(args.receipt / 'frozen-compile.json', data)
    if result.returncode:
        return result.returncode
    validate(args.receipt, data['source_inputs'])
    print('Compiled the verified preprocessed production inputs', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
