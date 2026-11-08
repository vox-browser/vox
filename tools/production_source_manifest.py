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
from pathlib import Path
import re

from rebuild_browser import git, production_input_path, write_json
from freeze_browser_compile import check_fingerprints


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


def validate_inventory(root, inventory):
    if inventory.get('protocol') != 'production-source-inventory-v1' or not inventory.get('names'):
        raise RuntimeError('Incomplete production source inventory')
    if input_names(root) != inventory['names']:
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


def combine(root, inventory, components):
    validate_inventory(root, inventory)
    result = dict(inventory['early_inputs'])
    for directory in components:
        for name, digest in component_inputs(directory).items():
            if name in result and result[name] != digest:
                raise RuntimeError('Production components consumed different source bytes: ' + name)
            result[name] = digest
    check_fingerprints(result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['begin', 'combine'])
    parser.add_argument('--root', required=True, type=Path)
    parser.add_argument('--inventory', required=True, type=Path)
    parser.add_argument('--component', action='append', type=Path, default=[])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.action == 'begin':
        # The supervisor delivered these shell bytes through stdin before this
        # script started; never describe a subsequently edited script as them.
        script = args.inventory.parent / 'build-script.json'
        if script.exists():
            delivered = json.loads(script.read_text())
            check_fingerprints({delivered['path']: delivered['sha256']})
        write_json(args.inventory, begin(args.root))
    else:
        if not args.component or not args.output:
            parser.error('combine requires components and an output')
        inventory = json.loads(args.inventory.read_text())
        write_json(args.output, combine(args.root, inventory, args.component))


if __name__ == '__main__':
    main()
