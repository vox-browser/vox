#!/usr/bin/env python3
"""Compare regex hint analysis and literal prefilters with unchanged Rust bodies.

Uses the pinned sources and Rust compiler selection of libjs_regex_core_corpus.
No regex parser/compiler, VM execution or Unicode FFI function is invoked.
"""
import argparse
import itertools
from pathlib import Path
import random
import subprocess
import tempfile

import libjs_regex_core_corpus as core

RECORDS = r'''
fn fixture_property() -> bytecode::UnicodePropertyData {
    bytecode::UnicodePropertyData { negated: true, name: "Script".into(), value: Some("Greek".into()),
        resolved: Some(bytecode::ResolvedProperty { kind: bytecode::PropertyKind::Script, id: 14 }) }
}
fn fixture_matcher(index: usize) -> bytecode::SimpleMatch {
    use bytecode::SimpleMatch as S;
    match index {
        0 | 1 => S::AnyChar { dot_all: index == 1 },
        2 => S::Char(97), 3 => S::CharNoCase(97, 65),
        4 | 5 => S::CharClass { ranges: vec![bytecode::CharRange { start: 65, end: 90 }], negated: index == 5 },
        6 => S::BuiltinClass(ast::BuiltinCharacterClass::Word),
        7 => S::UnicodeProperty(Box::new(fixture_property())),
        8 => S::Union(Box::new(fixture_matcher(4)), Box::new(S::Union(Box::new(fixture_matcher(2)), Box::new(fixture_matcher(7))))),
        9 => S::BuiltinClass(ast::BuiltinCharacterClass::NonWhitespace),
        _ => panic!("unknown fixture matcher"),
    }
}
fn builtin(index: u32) -> ast::BuiltinCharacterClass {
    [ast::BuiltinCharacterClass::Digit, ast::BuiltinCharacterClass::NonDigit,
     ast::BuiltinCharacterClass::Word, ast::BuiltinCharacterClass::NonWord,
     ast::BuiltinCharacterClass::Whitespace, ast::BuiltinCharacterClass::NonWhitespace][index as usize]
}
fn instruction(text: &str) -> bytecode::Instruction {
    use bytecode::Instruction as I;
    let f: Vec<&str> = text.split(',').collect();
    let n = |i: usize| f[i].parse::<u32>().unwrap();
    let maximum = |i: usize| if f[i] == "-" { None } else { Some(n(i)) };
    match f[0] {
        "c" => I::Char(n(1)), "i" => I::CharNoCase(n(1), n(2)), "a" => I::AnyChar { dot_all: n(1) != 0 },
        "h" => I::CharClass { ranges: (2..f.len()).step_by(2).map(|j| bytecode::CharRange { start: n(j), end: n(j+1) }).collect(), negated: n(1) != 0 },
        "b" => I::BuiltinClass(builtin(n(1))), "u" => I::UnicodeProperty(Box::new(fixture_property())),
        "j" => I::Jump(n(1)), "x" => I::Split { prefer: n(1), other: n(2) }, "s" => I::Save(n(1)), "e" => I::ClearRegister(n(1)),
        "^" => I::AssertStart { multiline: n(1) != 0 }, "$" => I::AssertEnd { multiline: n(1) != 0 },
        "w" => I::AssertWordBoundary, "W" => I::AssertNonWordBoundary, "M" => I::Match, "F" => I::Fail,
        "B" => I::Backref(n(1)), "N" => I::BackrefNamed("named".into()), "r" => I::RepeatStart { counter_reg: n(1) },
        "R" => I::RepeatCheck { counter_reg: n(1), min: n(2), max: maximum(3), body: n(4), greedy: n(5) != 0 },
        "l" => I::LookStart { positive: n(1) != 0, forward: n(2) != 0, end: n(3) }, "L" => I::LookEnd,
        "p" => I::PushModifiers { ignore_case: Some(false), multiline: None, dot_all: Some(true) }, "P" => I::PopModifiers,
        "n" => I::Nop, "t" => I::StringPropertyMatch { strings: vec![2, 97, 98, 1, 97].into_boxed_slice(), property: Box::new(fixture_property()) },
        "k" => I::ProgressCheck { reg: n(1), clear_captures: vec![2, 3] },
        "g" => I::GreedyLoop { matcher: fixture_matcher(n(1) as usize), min: n(2), max: maximum(3) },
        "G" => I::LazyLoop { matcher: fixture_matcher(n(1) as usize), min: n(2), max: maximum(3) },
        _ => panic!("unknown fixture instruction"),
    }
}
fn program(text: &str, flags: u32) -> bytecode::Program {
    let mut p = bytecode::Program::new();
    if text != "-" { p.instructions = text.split(';').map(instruction).collect(); }
    p.unicode = flags & 1 != 0; p.ignore_case = flags & 2 != 0; p.multiline = flags & 4 != 0;
    p.unicode_sets = flags & 8 != 0; p.dot_all = flags & 16 != 0;
    p
}
fn units(text: &str) -> Vec<u16> {
    if text == "-" { Vec::new() } else { (0..text.len()).step_by(4).map(|i| u16::from_str_radix(&text[i..i+4], 16).unwrap()).collect() }
}
fn hex(data: &[u16]) -> String {
    if data.is_empty() { "-".into() } else { data.iter().map(|x| format!("{x:04x}")).collect() }
}
fn optional(value: Option<usize>) -> String { value.map(|v| v.to_string()).unwrap_or_else(|| "-".into()) }
fn bit(value: bool) -> u8 { u8::from(value) }
fn matcher_text(matcher: &bytecode::SimpleMatch) -> String {
    use bytecode::SimpleMatch as S;
    match matcher {
        S::AnyChar { dot_all } => format!("a:{}", bit(*dot_all)), S::Char(c) => format!("c:{c}"),
        S::CharNoCase(a,b) => format!("i:{a}:{b}"), S::BuiltinClass(c) => format!("b:{}", *c as u8),
        S::CharClass { ranges, negated } => format!("h:{}:{}", bit(*negated), ranges.iter().map(|r| format!("{}-{}", r.start,r.end)).collect::<Vec<_>>().join("/")),
        S::UnicodeProperty(data) => format!("u:{}:{}:{}:{}:{}", bit(data.negated), data.name, data.value.as_deref().unwrap_or("-"), data.resolved.as_ref().unwrap().kind as u8, data.resolved.as_ref().unwrap().id),
        S::Union(a,b) => format!("({}+{})", matcher_text(a), matcher_text(b)),
    }
}
'''

WRAPPERS = r'''
pub fn hint_text(program: &Program, empty: bool, ast: Option<RequiredLiteralHint>) -> String {
    let h = analyze_pattern(program, empty, ast);
    let first = h.first_char.map(|(c,i)| format!("{c}:{}", crate::bit(i))).unwrap_or_else(|| "-".into());
    let filter = h.first_filter.as_ref().map(crate::matcher_text).unwrap_or_else(|| "-".into());
    let start = h.start_position_hint.as_ref().map(|s| format!("{}:{}", crate::bit(s.includes_input_start), crate::hex(&s.literal_code_units))).unwrap_or_else(|| "none".into());
    let tail = h.trailing_literal.as_ref().map(|v| crate::hex(v)).unwrap_or_else(|| "none".into());
    let required = h.required_literal.as_ref().map(|r| format!("{}:{}", crate::bit(r.ascii_case_insensitive), crate::hex(&r.literal))).unwrap_or_else(|| "none".into());
    let scan = h.simple_scan.as_ref().map(|s| match s {
        SimpleScan::Char(c) => format!("c:{c}"), SimpleScan::BuiltinClass(c) => format!("b:{}", *c as u8),
        SimpleScan::CharClass { ranges, negated } => crate::matcher_text(&SimpleMatch::CharClass { ranges: ranges.clone(), negated: *negated }),
        SimpleScan::GreedyQuantifier { matcher, min, max } => format!("g:{}:{min}:{}", crate::matcher_text(matcher), max.map(|m| m.to_string()).unwrap_or_else(|| "-".into())),
    }).unwrap_or_else(|| "-".into());
    format!("{first}|{filter}|{start}|{}|{}|{tail}|{required}|{scan}|{}", crate::bit(h.starts_with_anchor), crate::bit(h.anchor_multiline), crate::bit(h.can_match_empty))
}
pub fn suffix_text(instructions: &[Instruction], pc: usize) -> String {
    extract_trailing_literal(instructions, pc).map(|v| crate::hex(&v)).unwrap_or_else(|| "none".into())
}
pub fn linear(instructions: &[Instruction], pc: usize) -> bool { suffix_has_linear_tail(instructions, pc) }
pub fn successor_text(instruction: &Instruction, pc: usize, count: usize) -> String {
    let mut out = Vec::new(); for_each_successor(instruction, pc, count, |v| out.push(v.to_string()));
    if out.is_empty() { "-".into() } else { out.join(",") }
}
pub fn search<I: Input>(op: &str, input: I, start: usize, flag: bool, extra: &str) -> String {
    let needle = crate::units(extra);
    match op {
        "contains" => crate::bit(contains_u16_from(input, start, &needle)).to_string(),
        "contains_i" => crate::bit(contains_ascii_case_insensitive_u16_from(input, start, &needle)).to_string(),
        "at_i" => crate::bit(matches_ascii_case_insensitive_u16_at(input, start, &needle)).to_string(),
        "start_scan" => crate::optional(next_literal_start_from_hint(input, start, &StartPositionHint { includes_input_start: flag, literal_code_units: needle })),
        _ => panic!("unknown search fixture"),
    }
}
pub fn reject<I: Input>(input: I, start: usize, flag: bool, extra: &str) -> String {
    let (tail, required) = extra.split_once(':').unwrap();
    let mut hints = analyze_pattern(&Program::new(), false, None);
    hints.trailing_literal = if tail == "none" { None } else { Some(crate::units(tail)) };
    hints.required_literal = if required == "none" { None } else { Some(RequiredLiteralHint { literal: crate::units(required), ascii_case_insensitive: flag }) };
    format!("{},{}", crate::bit(fails_trailing_literal_hint(input, &hints)), crate::bit(fails_required_literal_hint(input, start, &hints)))
}
'''

DRIVER = r'''
use std::io::{self, BufRead};
fn main() {
    for line in io::stdin().lock().lines() {
        let line = line.unwrap(); let f: Vec<&str> = line.split('\t').collect(); assert_eq!(f.len(),7);
        let a: usize = f[3].parse().unwrap(); let b: usize = f[4].parse().unwrap();
        let result = match f[0] {
            "analyze" => {
                let p = program(f[2], f[1].parse().unwrap());
                let ast = if f[6] == "none" { None } else { Some(oracle_vm::RequiredLiteralHint { literal: units(f[6]), ascii_case_insensitive: b != 0 }) };
                oracle_vm::hint_text(&p, a != 0, ast)
            }
            "suffix" => oracle_vm::suffix_text(&program(f[2],0).instructions,a),
            "linear" => bit(oracle_vm::linear(&program(f[2],0).instructions,a)).to_string(),
            "successors" => oracle_vm::successor_text(&instruction(f[2]),a,b),
            "fold" => oracle_vm::fold_fixture(a as u16).to_string(),
            op => {
                let data = units(f[2]);
                if f[1] == "u8" {
                    assert!(data.iter().all(|&v| v <= 255)); let bytes: Vec<u8> = data.into_iter().map(|v| v as u8).collect();
                    if op == "reject" { oracle_vm::reject(bytes.as_slice(),a,b != 0,f[6]) } else { oracle_vm::search(op,bytes.as_slice(),a,b != 0,f[6]) }
                } else {
                    if op == "reject" { oracle_vm::reject(data.as_slice(),a,b != 0,f[6]) } else { oracle_vm::search(op,data.as_slice(),a,b != 0,f[6]) }
                }
            }
        };
        println!("{line}\t{result}");
    }
}
'''
WRAPPERS += '\npub fn fold_fixture(unit: u16) -> u16 { fold_ascii_for_compare(unit) }\n'


def templates():
    nodes = ['c,97', 'i,97,65', 'a,0', 'h,1,65,90', 'b,2', 'u', 'j,0', 'x,0,0',
             's,2', 'e,3', '^,0', '$,0', 'w', 'W', 'M', 'F', 'B,1', 'N', 'r,4',
             'R,4,1,3,0,1', 'l,1,1,3', 'L', 'p', 'P', 'n', 't', 'k,4', 'g,4,1,-', 'G,4,1,-']
    yield []
    for node in nodes:
        yield ['s,0', node, 's,1', 'M']
    for matcher, minimum, maximum in itertools.product(range(10), [0, 1, 3], ['-', '4']):
        yield ['s,0', f'g,{matcher},{minimum},{maximum}', 's,1', 'M']
    for prefix in [[], ['w'], ['W'], ['s,2'], ['n'], ['e,3'], ['p'], ['l,1,1,4'], ['l,0,1,4'], ['l,1,0,4']]:
        for end in [[], ['$,0'], ['$,1']]:
            yield ['s,0', *prefix, '^,0', 'c,97', 's,2', 'c,128512', 'P', 'n', *end, 's,1', 'M']
    for chars in [('c,97', 'c,97'), ('i,97,65', 'c,97'), ('c,97', 'i,97,65'),
                  ('^,0', 'c,97'), ('^,0', '^,0'), ('c,97', 'c,98'),
                  ('c,97', 'c,98', 'c,99'), ('c,97', 'c,97', 'c,98'),
                  ('c,55296', 'c,56320'), ('c,128512', 'c,97')]:
        for setup in [[], ['s,2'], ['n'], ['e,2']]:
            result = ['s,0']
            jumps = []
            for i, char in enumerate(chars):
                if i < len(chars) - 1:
                    pc = len(result)
                    result += [f'x,{pc+1},{pc+3+len(setup)}', *setup, char, 'j,0']
                    jumps.append(len(result)-1)
                else:
                    result += [*setup, char]
            continuation = len(result)
            result += ['c,98', 's,1', 'M']
            for jump in jumps:
                result[jump] = f'j,{continuation}'
            yield result


def cases():
    rng = random.Random(0x963_d46_a8 + 1)
    ast_hints = [('none', 0), ('-', 0), ('0078', 0), ('0078', 1),
                 ('00610062', 1), ('00610062', 0), ('00780079007a', 0)]
    patterns = list(dict.fromkeys(';'.join(p) or '-' for p in templates()))
    for pattern, flags, empty in itertools.product(patterns, range(8), range(2)):
        for ast, ignore_case in ast_hints:
            yield 'analyze', flags, pattern, empty, ignore_case, 0, ast
    for _ in range(1400):
        length = rng.randrange(1, 25)
        nodes = []
        for pc in range(length):
            kinds = ['literal', 'split', 'jump', 'repeat', 'look', 'other'] if pc+1 < length else ['literal', 'other']
            kind = rng.choice(kinds)
            if kind == 'literal':
                node = 'c,' + str(rng.choice([0, 97, 98, 0x7f, 0x80, 0xd800, 0xdc00, 0x1f600, 0x110000]))
            elif kind == 'split':
                node = f'x,{rng.randrange(pc+1,length)},{rng.randrange(pc+1,length)}'
            elif kind == 'jump':
                node = f'j,{rng.randrange(pc+1,length)}'
            elif kind == 'repeat':
                node = f'R,4,1,-,{rng.randrange(pc+1,length)},1'
            elif kind == 'look':
                node = f'l,{rng.randrange(2)},{rng.randrange(2)},{rng.randrange(pc+1,length)}'
            else:
                node = rng.choice(['s,0','s,1','s,2','n','p','P','e,3','w','W','^,0','^,1','$,0','$,1','a,0','b,2','h,0,65,90','i,97,65','M','F','L','g,8,1,4'])
            nodes.append(node)
        if rng.randrange(2):
            nodes += ['$,0'] if rng.randrange(2) else []
            nodes += ['s,1', 'M']
        ast, ignore_case = rng.choice(ast_hints)
        pattern = ';'.join(nodes)
        yield 'analyze', rng.randrange(32), pattern, rng.randrange(2), ignore_case, 0, ast
        for pc in [0, len(nodes)//2, len(nodes)]:
            yield 'suffix', '-', pattern, pc, 0, 0, '-'
            yield 'linear', '-', pattern, pc, 0, 0, '-'
    for node in ['c,97','j,2','x,2,2','R,4,1,3,2,1','l,1,0,2','M','F','L','p','g,8,1,-']:
        for pc, length in [(0,1),(0,4),(3,4)]:
            yield 'successors', '-', node, pc, length, 0, '-'
    for unit in range(65536):
        yield 'fold', '-', '-', unit, 0, 0, '-'
    for storage, alphabet in [('u16', [0, 65, 97, 66, 98, 0x7f, 0x80, 0xd800, 0xdc00, 0x212a]), ('u8', [0,65,97,66,98,0x7f,0x80,0xff])]:
        inputs = [(), (65,97,97,66), *itertools.product(alphabet, repeat=2)]
        inputs += [tuple(rng.choice(alphabet) for _ in range(rng.randrange(18))) for _ in range(250)]
        for data in inputs:
            for _ in range(6):
                start = rng.randrange(len(data)+3)
                needle = tuple(rng.choice(alphabet) for _ in range(rng.randrange(4)))
                text, extra = core.encoded(data), core.encoded(needle)
                for op in ['contains', 'contains_i', 'at_i', 'start_scan']:
                    yield op, storage, text, start, rng.randrange(2), 0, extra
                tail = rng.choice(['none', '-', extra])
                required = rng.choice(['none', '-', extra])
                yield 'reject', storage, text, start, rng.randrange(2), 0, tail+':'+required


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream', type=Path, default=Path.home() / 'code/3rd/ladybird')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'libjs/testdata/regex-hints.tsv')
    args = parser.parse_args()
    upstream = args.upstream.resolve()
    revision = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == core.UPSTREAM_COMMIT, (core.UPSTREAM_COMMIT, revision)
    regex = upstream / 'Libraries/LibRegex/Rust/src'
    def rust_string(path):
        return '"' + str(path).replace('\\', '\\\\').replace('"', '\\"') + '"'
    imports = '#![allow(dead_code, unused_imports)]\nextern crate self as libunicode_rust;\n'
    imports += '#[path = ' + rust_string(upstream / 'Libraries/LibUnicode/Rust/src/character_types.rs') + '] pub mod character_types;\n'
    for module in ['ast','bytecode']:
        imports += '#[path = ' + rust_string(regex / (module+'.rs')) + '] mod '+module+';\n'
    oracle = imports + RECORDS + 'mod oracle_vm {\n' + (regex/'vm.rs').read_text() + WRAPPERS + '\n}\n' + DRIVER
    records = list(dict.fromkeys('\t'.join(map(str, row)) for row in cases()))
    with tempfile.TemporaryDirectory(prefix='vox2-regex-hints-') as directory:
        source, binary = Path(directory)/'oracle.rs', Path(directory)/'oracle'
        source.write_text(oracle)
        subprocess.run([core.rustc_path(), '--edition=2024', '-O', str(source), '-o', str(binary)], check=True)
        result = subprocess.run([str(binary)], input='\n'.join(records)+'\n', capture_output=True, text=True, check=True, timeout=120)
    answers = result.stdout.splitlines()
    assert len(answers) == len(records)
    assert all(answer.startswith(record+'\t') for answer, record in zip(answers,records))
    header = (f'# LibRegex {revision}; native Rust exact hint and prefilter outputs\n'
              '# operation, storage/flags, input/instructions, a, b, c, extra, result\n')
    # V warns about embedding a file above 5 MB; keep the exhaustive folding
    # table separate without dropping or changing any native comparison.
    fold_output = args.output.with_name(args.output.stem+'-fold'+args.output.suffix)
    args.output.write_text(header+'\n'.join(a for a in answers if not a.startswith('fold\t'))+'\n')
    fold_output.write_text(header+'\n'.join(a for a in answers if a.startswith('fold\t'))+'\n')
    print(f'{len(answers)} exact regex-hints fixtures written to {args.output} and {fold_output}')


if __name__ == '__main__':
    main()
