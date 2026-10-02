#!/usr/bin/env python3
"""Record exact native UnicodeSet, character-class and scan membership outputs.

Uses unchanged LibRegex VM/Rust Unicode wrappers and extracted current C++
LibUnicode bodies. No parser, compiler, scan execution or VM dispatch is run.
"""
import argparse
import itertools
import json
from pathlib import Path
import random
import subprocess
import sys

import libjs_regex_core_corpus as core
import libjs_regex_matching_corpus as matching
from libjs_regexp_preparation_corpus import between

WRAPPERS = r'''
pub fn range_member(cp: u32, ranges: &[CharRange]) -> bool { char_in_ranges(cp,ranges) }
pub fn class_bits(cp: u32, ranges: &[CharRange]) -> String {
    (0..8).map(|flags|crate::bit(match_char_class(cp,ranges,flags&1!=0,flags&2!=0,flags&4!=0)).to_string()).collect()
}
pub fn scan_member(cp: u32, kind: &str, arg: u32, ranges: Vec<CharRange>) -> bool {
    let scan=match kind {
        "class"=>SimpleScan::CharClass { ranges,negated:arg!=0 },
        "builtin"=>SimpleScan::BuiltinClass(crate::builtin(arg)),
        "literal"=>SimpleScan::Char(arg),
        "greedy"=>SimpleScan::GreedyQuantifier { matcher:SimpleMatch::Char(arg),min:0,max:None },
        _=>panic!("unknown scan variant"),
    }; match_simple_scan(&scan,cp)
}
'''

DRIVER = r'''
use std::io::{self,BufRead};
unsafe extern "C" {
    fn oracle_set_locale();
    fn oracle_expand_case_range(start: u32,end: u32,out: *mut u32,capacity: u32) -> u32;
}
fn ranges(text: &str) -> Vec<bytecode::CharRange> {
    let text=if let Some(index)=text.strip_prefix('@') {RANGE_FIXTURES[index.parse::<usize>().unwrap()]} else {text};
    if text=="-" {Vec::new()} else {text.split(',').map(|r| {
        let (a,b)=r.split_once(':').unwrap(); bytecode::CharRange {start:a.parse().unwrap(),end:b.parse().unwrap()}
    }).collect()}
}
fn main() {
    unsafe {oracle_set_locale();}
    for line in io::stdin().lock().lines() {
        let line=line.unwrap();let f:Vec<&str>=line.split('\t').collect();assert_eq!(f.len(),5);
        let cp:u32=f[1].parse().unwrap();let a:u32=f[2].parse().unwrap();let b:u32=f[3].parse().unwrap();
        let result=match f[0] {
            "closure"=> {
                let mut output=vec![u32::MAX;a as usize];
                let n=character_types::get_case_closure(cp,&mut output);
                format!("{n}|{}",output.iter().map(|v|v.to_string()).collect::<Vec<_>>().join(","))
            },
            "expand"=> {
                let count=unsafe {oracle_expand_case_range(a,b,std::ptr::null_mut(),0)};
                let mut output=vec![0;2*count as usize];
                assert_eq!(count,unsafe {oracle_expand_case_range(a,b,output.as_mut_ptr(),count)});
                if count==0 {"-".into()} else {output.chunks_exact(2).map(|r|format!("{}:{}",r[0],r[1])).collect::<Vec<_>>().join(",")}
            },
            "inverse"=>(0..2).map(|flag|bit(character_types::code_point_matches_range_ignoring_case(cp,a,b,flag!=0)).to_string()).collect(),
            "member"=>bit(oracle_vm::range_member(cp,&ranges(f[4]))).to_string(),
            "class"=>oracle_vm::class_bits(cp,&ranges(f[4])),
            "scan"=> {
                let (kind,text)=f[4].split_once('!').unwrap();
                bit(oracle_vm::scan_member(cp,kind,a,ranges(text))).to_string()
            },
            _=>panic!("unknown character-class operation"),
        };println!("{line}\t{result}");
    }
}
'''


def cpp_source(upstream):
    character=(upstream/'Libraries/LibUnicode/CharacterTypes.cpp').read_text()
    methods=between(character,'Vector<CodePointRange> expand_range_case_insensitive',
                    '\n}\n\nenum class ResolvedPropertyKind')
    ffi=character[character.index('extern "C" bool unicode_code_point_matches_range_ignoring_case'):]
    return matching.cpp_source(upstream)+'''#include <LibUnicode/CharacterTypes.h>
#include <unicode/uniset.h>
#include <unicode/uset.h>
namespace Unicode {
'''+methods+'\n}\n'+ffi+'''
extern "C" u32 oracle_expand_case_range(u32 start,u32 end,u32* out,u32 capacity) {
    auto ranges=Unicode::expand_range_case_insensitive(start,end);
    for (u32 i=0;i<ranges.size() && i<capacity;++i) {out[2*i]=ranges[i].from;out[2*i+1]=ranges[i].to;}
    return ranges.size();
}
'''


def encoded(ranges):
    return ','.join(f'{a}:{b}' for a,b in ranges) or '-'


def range_fixtures():
    rng=random.Random(0x963_d46_a8+5)
    shapes=['65:90','0:0,48:57,65:90,97:122,223:223,383:383,931:931,962:963,7838:7838,8490:8490,55296:57343,66560:66639',
            '-',encoded([(0x5a,0x61)]),encoded([(90,65)]),encoded([(0xdf,0xdf),(0x17f,0x17f)]),encoded([(0x10400,0x10427)])]
    for count in [1,8,9,16,31]:
        rs=[(100+5*i,102+5*i) for i in range(count)]
        shapes += [encoded(rs),encoded(list(reversed(rs)))]
    for _ in range(70):
        values=sorted(rng.sample(range(0x110000),rng.randrange(1,40)))
        shapes.append(encoded([(cp,cp+rng.randrange(3)) for cp in values]))
    return shapes


def cases():
    rng=random.Random(0x963_d46_a8+4)
    palette=[0,9,0x20,0x30,0x39,0x41,0x5a,0x61,0x7a,0xdf,0xe9,0x130,0x131,0x17f,
             0x3a3,0x3c2,0x3c3,0x1e9e,0x212a,0xd800,0xdc00,0xfeff,0x10400,0x10428,0x10ffff]
    supplementary=list(range(0x10400,0x10450))+[0x10000,0x1f600,0x10ffff]
    supplementary += [rng.randrange(0x10000,0x110000) for _ in range(700)]
    for cp in list(range(0x10000))+supplementary:
        yield 'closure',cp,3,0,'-'
        for text in ['@0','@1']:
            yield 'class',cp,0,0,text
    for cp,capacity in itertools.product(palette+supplementary[:83]+[0x110000,0x7fffffff,0x80000000,0xffffffff], [0,1,2,3,16]):
        yield 'closure',cp,capacity,0,'-'
    intervals=[(0x41,0x5a),(0x61,0x7a),(0x5a,0x61),(0x17f,0x17f),(0x212a,0x212a),
               (0xdf,0xdf),(0x1e9e,0x1e9e),(0x3a3,0x3a3),(0x3c2,0x3c3),(0xd800,0xdfff),
               (0x10400,0x10427),(0x10428,0x1044f),(0,0x10ffff),(90,65),(0x110000,0x110000),
               (0x7fffffff,0x7fffffff),(0x80000000,0x80000000),(0xffffffff,0xffffffff)]
    intervals += [(a,a) for a in palette]
    for a,b in intervals:
        yield 'expand',0,a,b,'-'
        for cp in palette+supplementary[:83]:
            yield 'inverse',cp,a,b,'-'
    shapes=[f'@{index}' for index in range(len(range_fixtures()))]
    for count in [1,8,9,16,31]:
        rs=[(100+5*i,102+5*i) for i in range(count)]
        for cp in range(98,105+5*count):
            yield 'member',cp,0,0,encoded(rs)
    points=palette+[rng.randrange(0x110000) for _ in range(200)]
    for cp,text in itertools.product(points,shapes):
        yield 'member',cp,0,0,text
        yield 'class',cp,0,0,text
    for cp in points:
        for text,negated in itertools.product(shapes[:7],[0,1]):
            yield 'scan',cp,negated,0,'class!'+text
        for kind,arguments in [('builtin',range(6)),('literal',palette),('greedy',range(10))]:
            for a in arguments:
                yield 'scan',cp,a,0,kind+'!-'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-class.tsv')
    args=parser.parse_args();upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    definitions=range_fixtures()
    driver='const RANGE_FIXTURES: &[&str] = &['+','.join(json.dumps(v) for v in definitions)+'];\n'+DRIVER
    answers=matching.native_outputs(upstream,build,prefix,args.simdutf_prefix.resolve(),args.jobs,
                                   cpp_source(upstream),WRAPPERS,driver,records)
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibRegex/LibUnicode/AK {revision}; native exact class helpers; locale en_US_POSIX\n'
    header+='# operation, code point, a, b, extra, result\n'
    groups={'':[], '-closure':[], '-bmp':[]}
    for line in answers:
        fields=line.split('\t')
        suffix='-closure' if fields[0]=='closure' else '-bmp' if fields[0]=='class' and fields[4].startswith('@') else ''
        groups[suffix].append(line)
    for suffix,values in groups.items():
        output=args.output.with_name(args.output.stem+suffix+args.output.suffix)
        output.write_text(header+'\n'.join(values)+'\n')
        print(f'{len(values)} exact regex-class fixtures written to {output}')
    ranges_path=args.output.with_name(args.output.stem+'-ranges'+args.output.suffix)
    ranges_path.write_text(f'# LibRegex {revision}; shared fixture range arrays\n# index, inclusive start:end intervals\n'
                           +'\n'.join(f'{i}\t{v}' for i,v in enumerate(definitions))+'\n')


if __name__=='__main__':
    try: main()
    except subprocess.CalledProcessError as error:
        if error.stderr: sys.stderr.write(error.stderr)
        raise
