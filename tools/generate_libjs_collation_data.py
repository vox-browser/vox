#!/usr/bin/env python3
"""Generate native LibJS CLDR-root collation tables, without a host collator.

Input: CLDR release-48 at the pinned revision, plus Unicode 17.0.0
UnicodeData.txt and Blocks.txt in the same directory. Output is immutable
little-endian trie/element, decimal-digit and implicit-range source data.
"""
from collections import deque
from pathlib import Path
import argparse
import hashlib
import re
import struct
import xml.etree.ElementTree as ET

REVISION = 'acd6d88ae493633240e19a87a721076a8a75c310'
INPUTS = {
    'common/uca/allkeys_CLDR.txt': 'f6f8961f6c51373bdc00b09fb61cc8c07bec4122bc4b8bcb50ff71c4b0901ab5',
    'common/collation/root.xml': 'af6784292b2ec2576efcfdc5e1073f272edc1265a2dc5286ba9bd16b2d7a1ed9',
    'common/collation/en.xml': '593948669f284ed65c798778b82b8eafae492f759c48a17a4551421d18e4d665',
    'UnicodeData.txt': '2e1efc1dcb59c575eedf5ccae60f95229f706ee6d031835247d843c11d96470c',
    'Blocks.txt': 'c0edefaf1a19771e830a82735472716af6bf3c3975f6c2a23ffbe2580fbbcb15',
    'LICENSE': 'b4c0ae8ef04f7059f96ce5bbe0467f9fe6f6d81bbe13517701dfeb961fb4d0b6',
}
UPPER = set(range(0x08, 0x0d)) | {0x0e, 0x11, 0x12, 0x1d}


def generate(source: Path, destination: Path):
    raw = {}
    for name, expected in INPUTS.items():
        data = (source / name).read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(f'Changed pinned collation input: {name}')
        raw[name] = data
    root_xml = ET.fromstring(raw['common/collation/root.xml'])
    standard = root_xml.find("./collations/collation[@type='standard']")
    if standard is None or list(standard):
        raise ValueError('Expected empty CLDR root standard tailoring')
    en_xml = ET.fromstring(raw['common/collation/en.xml'])
    if en_xml.find('./identity/language').get('type') != 'en' or en_xml.find('./collations') is not None:
        raise ValueError('Expected English to inherit CLDR root collation')

    trie = {'point': 0, 'children': {}, 'elements': []}
    mappings = {}
    for line in raw['common/uca/allkeys_CLDR.txt'].decode().splitlines():
        text = line.split('#', 1)[0].strip()
        if not text or text == '@version 17.0.0':
            continue
        if text.startswith('@'):
            raise ValueError('Unsupported allkeys directive: ' + text)
        sequence, weights = text.split(';')
        points = tuple(int(item, 16) for item in sequence.split())
        elements = []
        cursor = 0
        for match in re.finditer(r'\[([.*])([0-9A-F]+)\.([0-9A-F]+)\.([0-9A-F]+)\]', weights):
            if weights[cursor:match.start()].strip():
                raise ValueError('Unparsed collation weights: ' + weights)
            primary, secondary, tertiary = [int(match[i], 16) for i in range(2, 5)]
            flags = int(match[1] == '*') | (int(tertiary in UPPER) << 1)
            elements.append((primary, secondary, tertiary, flags))
            cursor = match.end()
        if not elements or weights[cursor:].strip() or points in mappings:
            raise ValueError('Invalid/duplicate collation mapping: ' + text)
        mappings[points] = elements
        node = trie
        for point in points:
            node = node['children'].setdefault(point, {'point': point, 'children': {}, 'elements': []})
        node['elements'] = elements

    digits = []
    zero = mappings[(0x30,)][0][0]
    for line in raw['UnicodeData.txt'].decode().splitlines():
        fields = line.split(';')
        if fields[2] == 'Nd':
            point, digit = int(fields[0], 16), int(fields[6])
            if mappings[(point,)][0][0] != zero + digit:
                raise ValueError('Decimal digit mapping differs from pinned root data')
            digits.append((point, digit))

    implicit_names = {
        'Tangut': (0xfb00, 0x17000), 'Tangut Supplement': (0xfb00, 0x17000),
        'Tangut Components': (0xfb01, 0x18800), 'Tangut Components Supplement': (0xfb01, 0x18800),
        'Nushu': (0xfb02, 0x1b170), 'Khitan Small Script': (0xfb03, 0x18b00),
        'CJK Unified Ideographs': (0xfb40, 0), 'CJK Compatibility Ideographs': (0xfb40, 0),
    }
    implicit = []
    for line in raw['Blocks.txt'].decode().splitlines():
        text = line.split('#', 1)[0].strip()
        if not text:
            continue
        bounds, name = [part.strip() for part in text.split(';')]
        if name in implicit_names:
            start, end = [int(part, 16) for part in bounds.split('..')]
            implicit.append((start, end, *implicit_names[name]))

    nodes, pool = [], []
    queue = deque([trie])
    queued = 1
    while queue:
        node = queue.popleft()
        children = [node['children'][point] for point in sorted(node['children'])]
        nodes.append((node['point'], queued if children else 0, len(children), len(pool), len(node['elements'])))
        pool.extend(node['elements'])
        queue.extend(children)
        queued += len(children)
    destination.mkdir(parents=True, exist_ok=True)
    header = b'VCOLL01\0' + struct.pack('<II', len(nodes), len(pool))
    root_data = header + b''.join(struct.pack('<IIIII', *row) for row in nodes)
    root_data += b''.join(struct.pack('<IIII', *row) for row in pool)
    (destination / 'root.dat').write_bytes(root_data)
    (destination / 'digits.dat').write_bytes(b''.join(struct.pack('<II', *row) for row in digits))
    (destination / 'implicit.dat').write_bytes(b''.join(struct.pack('<IIII', *row) for row in implicit))
    (destination / 'LICENSE').write_bytes(raw['LICENSE'])
    provenance = [f'Unicode CLDR release-48, Unicode 17.0.0, unicode-org/cldr commit {REVISION}',
                  f'Source: https://github.com/unicode-org/cldr/tree/{REVISION}',
                  'UCD inputs: https://www.unicode.org/Public/17.0.0/ucd/',
                  'Generated with tools/generate_libjs_collation_data.py; pinned input SHA-256:']
    provenance += [f'{digest}  {name}' for name, digest in sorted(INPUTS.items())]
    provenance += [f'{len(mappings)} mappings; {len(nodes)} trie nodes; {len(pool)} elements; '
                   f'{len(digits)} decimal digits; {len(implicit)} implicit ranges']
    (destination / 'SOURCES').write_text('\n'.join(provenance) + '\n')
    print(f'{len(mappings):,} mappings, {len(nodes):,} nodes, {len(pool):,} elements, '
          f'{len(root_data):,} root bytes; English inherits the root standard order')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parent.parent / 'libjs/intl_collation_data')
    args = parser.parse_args()
    generate(args.source, args.output)
