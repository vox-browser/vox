#!/usr/bin/env python3
"""Copy pinned LibWasm opcode constants and parser no-immediate case groups."""
import argparse
import hashlib
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=Path.home() / 'code/3rd/ladybird/Libraries/LibWasm')
parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'webassembly/binary_opcodes.v')
args = parser.parse_args()
opcodes_text = (args.source / 'Opcode.h').read_text()
parser_text = (args.source / 'Parser/Parser.cpp').read_text()
opcodes = dict(re.findall(r'\bM\((\w+),\s*(0x[\da-fA-F]+)[uU]?,', opcodes_text))
body = parser_text.split('ParseResult<Instruction> Instruction::parse(', 1)[1].split('ParseResult<CustomSection>', 1)[0]
pending = []
empty = []
for line in body.splitlines():
    case = re.search(r'case Instructions::(\w+)\.value\(\):', line)
    if case:
        pending.append(case[1])
    if 'return Instruction {' in line:
        if re.search(r'return Instruction \{ (?:full_)?opcode \};', line):
            empty.extend(pending)
        pending.clear()
if not opcodes or not empty or any(name not in opcodes for name in empty):
    raise SystemExit('Unexpected pinned opcode/parser source structure')
header = '''// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Generated from LibWasm Opcode.h and Parser/Parser.cpp by
// tools/generate_wasm_opcodes.py. No instruction algorithms are generated.
'''
header += '// Opcode.h SHA256: ' + hashlib.sha256(opcodes_text.encode()).hexdigest() + '\n'
header += '// Parser.cpp SHA256: ' + hashlib.sha256(parser_text.encode()).hexdigest() + '\n'
lines = [header, 'module webassembly\n']
lines.extend('const binary_op_' + name + ' = u32(' + value + ')' for name, value in opcodes.items())
lines.extend(['', 'fn binary_opcode_has_no_immediate(opcode u32) bool {', '\treturn match opcode {'])
for start in range(0, len(empty), 6):
    lines.append('\t\t' + ', '.join('binary_op_' + name for name in empty[start:start + 6]) + ' { true }')
lines.extend(['\t\telse { false }', '\t}', '}', ''])
args.output.write_text('\n'.join(lines))
print(f'Copied {len(opcodes)} source opcodes and {len(empty)} parser no-immediate cases to {args.output}')
