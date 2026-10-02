#!/usr/bin/env python3
"""Refresh exact LibRegex record/input helper fixtures from pinned Rust sources.

AST, bytecode and Unicode property records are imported unchanged. The VM module
is copied verbatim into the temporary oracle with access wrappers for three
private helpers; no parser, compiler, matcher or Unicode FFI function is invoked.
"""
import argparse
import itertools
import os
from pathlib import Path
import random
import shutil
import subprocess
import tempfile

UPSTREAM_COMMIT = '963d46a829f3e1b79f44dba9d02afb70654300fa'

DRIVER = r'''
use std::io::{self, BufRead};
use oracle_vm::Input;
fn units(text: &str) -> Vec<u16> {
    if text == "-" { return Vec::new(); }
    (0..text.len()).step_by(4).map(|i| u16::from_str_radix(&text[i..i+4], 16).unwrap()).collect()
}
fn integers(text: &str) -> Vec<i32> {
    if text == "-" { Vec::new() } else { text.split(',').map(|x| x.parse().unwrap()).collect() }
}
fn hex(data: &[u16]) -> String {
    if data.is_empty() { "-".into() } else { data.iter().map(|x| format!("{x:04x}")).collect() }
}
fn optional(value: Option<usize>) -> String {
    value.map(|x| x.to_string()).unwrap_or_else(|| "-".into())
}
fn input_result<I: Input>(operation: &str, input: I, a: usize, b: usize, c: usize, extra: &str) -> String {
    match operation {
        "find" => optional(input.find_code_unit(a, b, c as u16)),
        "next" => optional(input.next_literal_start(a, c as u16)),
        "at" => u8::from(input.matches_u16_at(a, &units(extra))).to_string(),
        "ends" => u8::from(input.ends_with_u16(&units(extra))).to_string(),
        "equal" => u8::from(input.ranges_equal(a, b, c)).to_string(),
        "point" => format!("{},{}", oracle_vm::decode_code_point(b != 0, input, a),
                            oracle_vm::code_point_len(b != 0, input, a)),
        "unit" => input.code_unit(a).to_string(),
        _ => panic!("unknown input operation"),
    }
}
fn verify_invalid_patches() {
    std::panic::set_hook(Box::new(|_| {}));
    for instruction in [Some(bytecode::Instruction::Nop),
                        Some(bytecode::Instruction::Split { prefer: 1, other: 2 }), None] {
        let outcome = std::panic::catch_unwind(|| {
            let mut program = bytecode::Program::new();
            if let Some(instruction) = instruction { program.emit(instruction); }
            program.patch_jump(0, 9);
        });
        assert!(outcome.is_err());
    }
}
fn main() {
    verify_invalid_patches();
    for line in io::stdin().lock().lines() {
        let line = line.unwrap();
        let fields: Vec<&str> = line.split('\t').collect();
        assert_eq!(fields.len(), 7);
        let a: usize = fields[3].parse().unwrap();
        let b: usize = fields[4].parse().unwrap();
        let c: usize = fields[5].parse().unwrap();
        let result = match fields[0] {
            "negate" => {
                let classes = [ast::BuiltinCharacterClass::Digit, ast::BuiltinCharacterClass::NonDigit,
                               ast::BuiltinCharacterClass::Word, ast::BuiltinCharacterClass::NonWord,
                               ast::BuiltinCharacterClass::Whitespace, ast::BuiltinCharacterClass::NonWhitespace];
                classes.iter().position(|&x| x == classes[a].negated()).unwrap().to_string()
            }
            "quantifier" => {
                let q = match a { 0 => ast::Quantifier::zero_or_more(b != 0),
                                 1 => ast::Quantifier::one_or_more(b != 0),
                                 2 => ast::Quantifier::zero_or_one(b != 0), _ => unreachable!() };
                format!("{},{},{}", q.min, q.max.map(|x| x.to_string()).unwrap_or_else(|| "-".into()), u8::from(q.greedy))
            }
            "property" => character_types::PropertyKind::from_u8(a as u8)
                .map(|x| (x as u8).to_string()).unwrap_or_else(|| "-".into()),
            "append" => {
                let mut output = units(fields[2]);
                let success = bytecode::append_code_point_wtf16(&mut output, a as u32).is_some();
                format!("{},{}", u8::from(success), hex(&output))
            }
            "patch" => {
                let mut program = bytecode::Program::new();
                program.emit(bytecode::Instruction::Nop);
                let instruction = if fields[1] == "jump" { bytecode::Instruction::Jump(a as u32) }
                    else { bytecode::Instruction::Split { prefer: a as u32, other: b as u32 } };
                let index = program.emit(instruction);
                program.patch_jump(index, c as u32);
                if fields[6] != "-" { program.patch_jump(index, fields[6].parse().unwrap()); }
                match program.instructions[index as usize] {
                    bytecode::Instruction::Jump(target) => format!("{},{},{}", index, program.current_offset(), target),
                    bytecode::Instruction::Split { prefer, other } => format!("{},{},{},{}", index, program.current_offset(), prefer, other),
                    _ => unreachable!(),
                }
            }
            "captures" => {
                let registers = integers(fields[2]);
                let mut output = integers(fields[6]);
                oracle_vm::copy_out(&registers, a as u32, &mut output);
                if output.is_empty() { "-".into() }
                else { output.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(",") }
            }
            "search_position" => oracle_vm::search_position(a as i32, b as i32).to_string(),
            "classify" => {
                let (line, whitespace) = oracle_vm::classify(a as u32);
                format!("{},{}", u8::from(line), u8::from(whitespace))
            }
            operation => {
                let input = units(fields[2]);
                if fields[1] == "u8" {
                    assert!(input.iter().all(|&x| x <= 255));
                    let bytes: Vec<u8> = input.into_iter().map(|x| x as u8).collect();
                    input_result(operation, bytes.as_slice(), a, b, c, fields[6])
                } else { input_result(operation, input.as_slice(), a, b, c, fields[6]) }
            }
        };
        println!("{line}\t{result}");
    }
}
'''

WRAPPERS = r'''
pub fn copy_out(registers: &[i32], capture_count: u32, out: &mut [i32]) {
    copy_captures_to_out(registers, capture_count, out);
}
pub fn search_position(start: i32, end: i32) -> usize { next_search_position(start, end) }
pub fn classify(cp: u32) -> (bool, bool) { (is_line_terminator(cp), is_whitespace(cp)) }
'''


def encoded(units):
    return ''.join(f'{unit:04x}' for unit in units) or '-'


def cases():
    for value in range(6):
        yield 'negate', '-', '-', value, 0, 0, '-'
    for factory, greedy in itertools.product(range(3), range(2)):
        yield 'quantifier', '-', '-', factory, greedy, 0, '-'
    for value in range(256):
        yield 'property', '-', '-', value, 0, 0, '-'
    rng = random.Random(0x963_d46_a8)
    boundaries = [0, 0x7f, 0x80, 0xd7ff, 0xd800, 0xdbff, 0xdc00, 0xdfff, 0xffff,
                  0x10000, 0x1f600, 0x10ffff, 0x110000, 0xffffffff]
    for point in boundaries + [rng.randrange(0x110001) for _ in range(700)]:
        yield 'append', '-', '0061d800', point, 0, 0, '-'
    for first, target, second in itertools.product([0, 17, 0xffffffff], [0, 33, 0xffffffff], ['-', '19']):
        yield 'patch', 'jump', '-', first, 0, target, second
    for first, other, target in itertools.product([0, 0xffffffff], [17, 0xffffffff], [0, 23, 0xffffffff]):
        if first == 0xffffffff or other == 0xffffffff:
            yield 'patch', 'split', '-', first, other, target, '-'
            if first == 0xffffffff and other == 0xffffffff or target == 0xffffffff:
                yield 'patch', 'split', '-', first, other, target, '41'
    for count, registers_len, output_len in itertools.product([0, 1, 3, 0xffffffff], range(8), range(8)):
        registers = ','.join(str(i - 3) for i in range(registers_len)) or '-'
        output = ','.join(['99'] * output_len) or '-'
        yield 'captures', '-', registers, count, 0, 0, output
    for start, end in itertools.product([0, 1, 3, 0x7fffffff], repeat=2):
        if end >= start:
            yield 'search_position', '-', '-', start, end, 0, '-'
    whitespace_boundaries = [9, 10, 11, 12, 13, 32, 160, 0x1680, 0x2000, 0x200a,
                             0x2028, 0x2029, 0x202f, 0x205f, 0x3000, 0xfeff]
    points = boundaries + [x + delta for x in whitespace_boundaries for delta in [-1, 0, 1]]
    points += [rng.randrange(0x110001) for _ in range(700)]
    for point in points:
        yield 'classify', '-', '-', point, 0, 0, '-'
    for storage, alphabet in [('u16', [0, 0x61, 0x7f, 0x80, 0xd800, 0xdbff, 0xdc00, 0xdfff, 0xffff]),
                              ('u8', [0, 0x61, 0x7f, 0x80, 0xff])]:
        inputs = [(), *itertools.product(alphabet, repeat=2)]
        inputs += [tuple(rng.choice(alphabet) for _ in range(rng.randrange(17))) for _ in range(250)]
        for data in inputs:
            text, length = encoded(data), len(data)
            for position in range(length):
                yield 'unit', storage, text, position, 0, 0, '-'
                for unicode in range(2):
                    yield 'point', storage, text, position, unicode, 0, '-'
            for _ in range(6):
                start, end = rng.randrange(length + 3), rng.randrange(length + 3)
                unit = rng.choice(alphabet)
                yield 'find', storage, text, start, end, unit, '-'
                yield 'next', storage, text, start, 0, unit, '-'
                yield 'equal', storage, text, start, end, rng.randrange(length + 3), '-'
                needle = data[start:end] if start <= end and end <= length else (unit,)
                yield 'at', storage, text, start, 0, 0, encoded(needle)
                yield 'ends', storage, text, 0, 0, 0, encoded(needle)
            for position in [0, length, length + 1]:
                yield 'at', storage, text, position, 0, 0, '-'
            for start, end in [(0, length + 1), (length, length), (length + 1, length), (length + 2, length + 2)]:
                yield 'find', storage, text, start, end, 0x100, '-'
                yield 'equal', storage, text, start, end, 0, '-'


def rustc_path():
    compiler = os.environ.get('RUSTC') or shutil.which('rustc')
    if compiler:
        return compiler
    installed = sorted((Path.home() / '.rustup/toolchains').glob('stable-*/bin/rustc'))
    assert len(installed) == 1, 'Set RUSTC to a Rust compiler supporting edition 2024'
    return str(installed[0])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream', type=Path, default=Path.home() / 'code/3rd/ladybird')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] /
                        'libjs/testdata/regex-core.tsv')
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    revision = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == UPSTREAM_COMMIT, (UPSTREAM_COMMIT, revision)
    regex = upstream / 'Libraries/LibRegex/Rust/src'
    unicode = upstream / 'Libraries/LibUnicode/Rust/src/character_types.rs'
    # Quote paths as Rust string literals, including spaces and backslashes.
    def rust_string(path):
        return '"' + str(path).replace('\\', '\\\\').replace('"', '\\"') + '"'

    imports = '#![allow(dead_code, unused_imports)]\nextern crate self as libunicode_rust;\n'
    imports += '#[path = ' + rust_string(unicode) + '] pub mod character_types;\n'
    for module in ['ast', 'bytecode']:
        imports += '#[path = ' + rust_string(regex / (module + '.rs')) + '] mod ' + module + ';\n'
    oracle = imports + 'mod oracle_vm {\n' + (regex / 'vm.rs').read_text() + WRAPPERS + '\n}\n' + DRIVER
    records = list(dict.fromkeys('\t'.join(map(str, row)) for row in cases()))
    with tempfile.TemporaryDirectory(prefix='vox2-regex-core-') as directory:
        source, binary = Path(directory) / 'oracle.rs', Path(directory) / 'oracle'
        source.write_text(oracle)
        subprocess.run([rustc_path(), '--edition=2024', '-O', str(source), '-o', str(binary)], check=True)
        result = subprocess.run([str(binary)], input='\n'.join(records) + '\n',
                                capture_output=True, text=True, check=True)
    answers = result.stdout.splitlines()
    assert len(answers) == len(records)
    assert all(answer.startswith(record + '\t') for answer, record in zip(answers, records))
    args.output.write_text(f'# LibRegex/LibUnicode {revision}; native Rust exact helper outputs\n'
                           '# operation, storage, input, a, b, c, extra, result\n' +
                           '\n'.join(answers) + '\n')
    print(f'{len(answers)} exact regex-core fixtures written to {args.output}')


if __name__ == '__main__':
    main()
