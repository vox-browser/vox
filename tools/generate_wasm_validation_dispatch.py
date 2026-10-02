#!/usr/bin/env python3
"""Route every pinned validator specialization to its translated V body."""
import hashlib
from pathlib import Path
import re

from generate_wasm_fixed_validation import PIN, SOURCE_SHA256

ROOT = Path(__file__).resolve().parents[1]
ROUTES = [
    ('fixed_stack_validation.v', 'validate_binary_fixed_stack_instruction(instruction, mut stack)'),
    ('reference_variable_validation.v', 'validate_binary_reference_variable_instruction(instruction, mut validator, mut stack)'),
    ('control_validation.v', 'validate_binary_control_instruction(mut instruction, mut validator, mut stack)'),
    ('call_validation.v', 'validate_binary_call_instruction(instruction, mut validator, mut stack)'),
    ('table_validation.v', 'validate_binary_table_instruction(instruction, &validator, mut stack)'),
    ('memory_access_validation.v', 'validate_binary_memory_access_instruction(instruction, &validator, mut stack)'),
    ('memory_validation.v', 'validate_binary_memory_bulk_instruction(instruction, &validator, mut stack)'),
    ('simd_lane_validation.v', 'validate_binary_simd_lane_instruction(instruction, mut stack)'),
    ('simd_memory_validation.v', 'validate_binary_simd_memory_instruction(instruction, &validator, mut stack)'),
    ('gc_reference_validation.v', 'validate_binary_gc_reference_instruction(mut instruction, &validator, mut stack)'),
    ('gc_aggregate_validation.v', 'validate_binary_gc_aggregate_instruction(instruction, &validator, mut stack)'),
]


def main():
    upstream = Path.home() / 'code/3rd/ladybird/Libraries/LibWasm/AbstractMachine/Validator.cpp'
    source = upstream.read_text()
    if hashlib.sha256(source.encode()).hexdigest() != SOURCE_SHA256:
        raise SystemExit('Validator.cpp differs from pinned source; review before refreshing')
    source_names = set(re.findall(r'VALIDATE_INSTRUCTION\((\w+)\)', source)) - {'name'}
    seen = set()
    rows = [
        '// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>',
        '// SPDX-License-Identifier: BSD-2-Clause',
        f'// Pinned source instruction dispatch: Ladybird {PIN}.',
        '// Regenerate with tools/generate_wasm_validation_dispatch.py.',
        'module webassembly', '',
        'pub fn (mut validator BinaryInstructionValidator) validate_instruction(mut instruction BinaryInstruction, mut stack BinaryValidationStack) !bool {',
        '\tmatch instruction.opcode {',
    ]
    for filename, call in ROUTES:
        names = set(re.findall(r'binary_op_(\w+)', (ROOT / 'webassembly' / filename).read_text()))
        if names & seen or names - source_names:
            raise SystemExit(f'Duplicate or non-source handler route in {filename}')
        seen.update(names)
        rows += ['\t\t' + ', '.join('binary_op_' + name for name in sorted(names)) + ' {',
                 '\t\t\treturn ' + call, '\t\t}']
    if seen != source_names:
        raise SystemExit(f'Missing source handlers: {sorted(source_names - seen)}')
    rows += ["\t\telse { return error('CompileError: invalid instruction opcode (0x${instruction.opcode:x})') }", '\t}', '}', '']
    output = ROOT / 'webassembly/instruction_validation.v'
    output.write_text('\n'.join(rows))
    print(f'Routed all {len(seen)} pinned validation specializations without omissions or duplicates')


if __name__ == '__main__':
    main()
