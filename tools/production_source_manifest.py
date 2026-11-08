#!/usr/bin/env python3
"""Verify the source bytes consumed by each production V invocation.

Native/helper/resource inputs remain pinned from the start. V supplies the
digests of the buffers it parsed, so an edit before the browser parser reads a
file need not invalidate an independent helper compiled earlier. Conflicting
component inputs, edited consumed files and changed package membership fail.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

from rebuild_browser import git, production_input_path, write_json
from freeze_browser_compile import check_fingerprints, fingerprint


def input_names(root):
    names = git(root, 'ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0')
    return sorted({name.decode() for name in names if name
                   and not name.decode().endswith('.swp') and b'.v3cc.' not in name
                   and production_input_path(name.decode())})


def begin(root):
    names = input_names(root)
    # Keep every non-V input, including native build scripts and resources,
    # pinned across helper compilation and browser C generation. Symlink V
    # sources must retain their resolution too.
    paths = [root / name for name in names if (root / name).is_file()
             and (Path(name).suffix not in {'.v', '.vv', '.vsh'} or (root / name).is_symlink())]
    return dict(protocol='production-source-inventory-v1', names=names,
                early_inputs={str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths})


def validate_inventory(root, inventory, parsed=False):
    if inventory.get('protocol') != 'production-source-inventory-v1' or not inventory.get('names'):
        raise RuntimeError('Incomplete production source inventory')
    names, original = input_names(root), inventory['names']
    if parsed:
        names = [name for name in names if Path(name).suffix not in {'.v', '.vv', '.vsh'}]
        original = [name for name in original if Path(name).suffix not in {'.v', '.vv', '.vsh'}]
    if names != original:
        raise RuntimeError('Production source membership changed')
    check_fingerprints(inventory['early_inputs'])


def component_inputs(directory):
    names = (directory / 'v_sources').read_bytes().split(b'\0')
    digests = (directory / 'v_source_digests').read_bytes().split(b'\0')
    if len(names) != len(digests) or not names or not names[0]:
        raise RuntimeError('Incomplete compiler source manifest: ' + str(directory))
    result = {}
    for raw_name, raw_digest in zip(names, digests):
        name, digest = raw_name.decode(), raw_digest.decode()
        if not re.fullmatch('[0-9a-f]{64}', digest):
            raise RuntimeError('Invalid compiler source digest: ' + name)
        if name == '@native-input-manifest:v1':
            if digest != hashlib.sha256(b'v3-native-input-manifest-v1').hexdigest():
                raise RuntimeError('Invalid native source manifest marker')
            continue
        name = name.removeprefix('@native-input:')
        if not Path(name).is_absolute() or name.startswith('@'):
            raise RuntimeError('Invalid compiler source path: ' + name)
        if name in result and result[name] != digest:
            raise RuntimeError('Conflicting compiler source digest: ' + name)
        result[name] = digest
    if not any(Path(name).suffix in {'.v', '.vv', '.vsh'} for name in result):
        raise RuntimeError('Compiler manifest has no V sources')
    return result


def v_inputs(inputs):
    return {name: digest for name, digest in inputs.items() if Path(name).suffix in {'.v', '.vv', '.vsh'}}


def verified_component(directory):
    proof = json.loads((directory / 'parsed-verified.json').read_text())
    actual = component_inputs(directory)
    if proof.get('protocol') != 'verified-parsed-buffers-v1' or proof.get('sources') != v_inputs(actual):
        raise RuntimeError('Compiler source buffers changed after verification: ' + str(directory))
    return actual


def combine(root, inventory, components, parsed=False):
    validate_inventory(root, inventory, parsed=parsed)
    result = dict(inventory['early_inputs'])
    for directory in components:
        inputs = verified_component(directory) if parsed else component_inputs(directory)
        for name, digest in inputs.items():
            if name in result and result[name] != digest:
                raise RuntimeError('Production components consumed different source bytes: ' + name)
            result[name] = digest
    parsed_names = v_inputs(result) if parsed else {}
    check_fingerprints({name: digest for name, digest in result.items() if name not in parsed_names})
    return result


def compile_component(root, inventory, directory, command):
    """Seal parsed-buffer metadata before expensive checking/C generation.

    V writes its manifest after parsing, then compiles its immutable AST. Verify
    every parsed buffer while it still matches the checkout. Later edits cannot
    change that AST; the final manifest must describe exactly the sealed buffers.
    No source tree or V source file is copied.
    """
    environment = dict(os.environ, V_MACOS_V3_SOURCE_MANIFEST='1',
                       V_MACOS_V3_C_ERROR_DIR=str(directory))
    compiler = Path(command[0]).resolve()
    identity = fingerprint([compiler])
    process = subprocess.Popen(command, env=environment)
    proof, error = None, None
    while True:
        code = process.poll()
        if proof is None and error is None and (directory / 'v_source_digests').exists():
            try:
                sources = v_inputs(component_inputs(directory))
            except (OSError, RuntimeError, UnicodeError):
                # The compiler writes paths followed by digests, not one atomic
                # JSON record. Wait for a complete, well-formed pair of files.
                pass
            else:
                try:
                    validate_inventory(root, inventory)
                    check_fingerprints(sources)
                    if sources != v_inputs(component_inputs(directory)):
                        raise RuntimeError('Compiler manifest changed during parsed-buffer verification')
                    proof = dict(protocol='verified-parsed-buffers-v1', sources=sources,
                                 compiler=identity, verified_unix=time.time())
                    write_json(directory / 'parsed-verified.json', proof)
                except (OSError, RuntimeError) as failure:
                    error = str(failure)
                    write_json(directory / 'verification-error.json', dict(error=error))
        if code is not None:
            break
        time.sleep(.05)
    if code:
        return code
    check_fingerprints(identity)
    if error:
        raise RuntimeError(error)
    if (directory / 'v_sources').exists():
        verified_component(directory)
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['begin', 'combine', 'compile'])
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--inventory', required=True, type=Path)
    parser.add_argument('--component', action='append', type=Path, default=[])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--parsed', action='store_true')
    parser.add_argument('--component-dir', type=Path)
    parser.add_argument('--command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.action == 'begin':
        # The supervisor delivered these shell bytes through stdin before this
        # script started; never describe a subsequently edited script as them.
        script = args.inventory.parent / 'build-script.json'
        if script.exists():
            delivered = json.loads(script.read_text())
            check_fingerprints({delivered['path']: delivered['sha256']})
        write_json(args.inventory, begin(args.root))
    elif args.action == 'combine':
        if not args.component or not args.output:
            parser.error('combine requires components and an output')
        inventory = json.loads(args.inventory.read_text())
        write_json(args.output, combine(args.root, inventory, args.component, parsed=args.parsed))
    else:
        if not args.command or not args.component_dir:
            parser.error('compile requires component-dir and command')
        return compile_component(args.root, json.loads(args.inventory.read_text()), args.component_dir, args.command)


if __name__ == '__main__':
    raise SystemExit(main())
