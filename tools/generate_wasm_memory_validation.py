#!/usr/bin/env python3
"""Copy complete scalar/vector memory access validator bodies from pinned source.

Only the entire source shape below is accepted. Operand types and access widths
come from its explicit statements, never instruction names. Other memory/SIMD
shapes remain separate translations.
"""
import argparse
import hashlib
from pathlib import Path
import re

from generate_wasm_fixed_validation import PIN, SOURCE_SHA256, KINDS

PATTERN = re.compile(r'''
auto& arg = instruction\.arguments\(\)\.get<Instruction::MemoryArgument>\(\);
auto memory = TRY\(validate\(arg\.memory_index\)\);
if \(arg\.align > 64\)
return Errors::out_of_bounds\("memory op alignment value"sv, arg\.align, 0, 64\);
if \(\(1ull << arg\.align\) > (?P<width>sizeof\(\w+\)|\d+ / 8)\)
return Errors::out_of_bounds\("memory op alignment"sv, 1ull << arg\.align, 0, (?P=width)\);
(?:TRY\(\(stack\.take<ValueType::(?P<stored>\w+)>\(\)\)\);)?
TRY\(\(take_memory_address\(stack, memory, arg\)\)\);
(?:stack\.append\(ValueType\(ValueType::(?P<loaded>\w+)\)\);)?
return \{\};
'''.replace('\n', ' ').strip())
WIDTHS = {'sizeof(i32)': 4, 'sizeof(i64)': 8, 'sizeof(float)': 4,
          'sizeof(double)': 8, 'sizeof(u128)': 16, '8 / 8': 1,
          '16 / 8': 2, '32 / 8': 4}


def translate(body):
    body = ' '.join(re.sub(r'//[^\n]*', '', body).split())
    # Empty optional statements must not introduce extra required spaces.
    pattern = PATTERN.pattern.replace(')? ', ')?\\s*')
    matched = re.fullmatch(pattern, body)
    if not matched or matched['width'] not in WIDTHS:
        return None
    stored, loaded = matched['stored'], matched['loaded']
    if bool(stored) == bool(loaded) or any(k not in KINDS for k in [stored, loaded] if k):
        return None
    return WIDTHS[matched['width']], stored, loaded


def generate(source):
    groups = {}
    for match in re.finditer(r'VALIDATE_INSTRUCTION\((\w+)\)\s*\{(.*?)^\}', source, re.M | re.S):
        translated = translate(match[2])
        if translated is not None:
            groups.setdefault(translated, []).append(match[1])
    rows = [
        '// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>',
        '// SPDX-License-Identifier: BSD-2-Clause',
        '// Generated complete source memory access bodies; no name inference.',
        f'// Ladybird {PIN}, AbstractMachine/Validator.cpp',
        f'// Source SHA256: {SOURCE_SHA256}',
        '// Regenerate with tools/generate_wasm_memory_validation.py.',
        'module webassembly', '',
        'fn validate_binary_memory_access_instruction(instruction BinaryInstruction, validator &BinaryInstructionValidator, mut stack BinaryValidationStack) !bool {',
        '\tmatch instruction.opcode {',
    ]
    for (width, stored, loaded), names in groups.items():
        rows += [
            '\t\t' + ', '.join('binary_op_' + name for name in names) + ' {',
            '\t\t\targ := instruction.arguments as BinaryMemoryArgument',
            '\t\t\tmemory := validator.memory_for_index(arg.memory_index)!',
            "\t\t\tif arg.align > 64 { return error('CompileError: memory op alignment value out of bounds') }",
            f"\t\t\tif (u64(1) << arg.align) > {width} {{ return error('CompileError: memory op alignment out of bounds') }}",
        ]
        if stored:
            rows.append(f'\t\t\tstack.take(BinaryValueType{{ kind: .{KINDS[stored]} }})!')
        rows.append('\t\t\tbinary_take_memory_address(memory, arg, mut stack)!')
        if loaded:
            rows.append(f'\t\t\tstack.append_type(BinaryValueType{{ kind: .{KINDS[loaded]} }})')
        rows += ['\t\t\treturn false', '\t\t}']
    rows += ["\t\telse { return error('instruction is outside the memory access validation slice') }", '\t}', '}', '']
    return '\n'.join(rows), sum(len(names) for names in groups.values())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--upstream', type=Path, default=Path.home() / 'code/3rd/ladybird')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'webassembly/memory_access_validation.v')
    args = parser.parse_args()
    source = (args.upstream / 'Libraries/LibWasm/AbstractMachine/Validator.cpp').read_text()
    if hashlib.sha256(source.encode()).hexdigest() != SOURCE_SHA256:
        raise SystemExit('Validator.cpp differs from the pinned source; review before refreshing it')
    generated, count = generate(source)
    args.output.write_text(generated)
    print(f'Copied {count} complete source memory access bodies to {args.output}')


if __name__ == '__main__':
    main()
