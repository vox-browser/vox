#!/usr/bin/env python3
"""Record exact simple-match predicates and candidate-start filtering outputs.

Imports unchanged LibRegex/Rust VM helpers with the current native LibUnicode
and AK bodies. No regex parser, compiler or VM execution loop is invoked.
"""
import argparse
import json
from pathlib import Path
import random
import subprocess
import sys

import libjs_regex_core_corpus as core
import libjs_regex_matching_corpus as matching
import libjs_regex_property_corpus as properties

MATCHERS = [
    'any:0', 'any:1', 'literal:65', 'literal:83', 'literal:8490',
    'literal:66560', 'literal:56320', 'nocase:65:97', 'nocase:83:383',
    'nocase:233:122', 'nocase:66560:66600', 'class:0:65:90',
    'class:1:65:90', 'class:0:931:931', 'class:1:931:931',
    'builtin:2', 'builtin:3', 'builtin:0', 'builtin:1', 'builtin:4', 'builtin:5',
    'property:0:Lowercase:-:-', 'property:1:Lowercase:-:-',
    'property:0:gc:Lu:-', 'property:1:gc:Lu:-',
    'property:0:Script:Greek:-', 'property:1:scx:Hira:-',
    'property:0:ASCII:-:ASCII', 'property:0:unknown:<empty>:ASCII',
    'property:1:unknown:<empty>:ASCII', 'property:0:gc:Nd:Nd',
    'property:0:unknown:-:-', 'property:1:unknown:-:-',
    'union:3:17', 'union:21:22', 'union:33:26', 'union:34:35',
]

WRAPPERS = r'''
pub fn matcher(index: usize) -> SimpleMatch {
    let f: Vec<&str> = crate::MATCHERS[index].split(':').collect();
    match f[0] {
        "any" => SimpleMatch::AnyChar { dot_all:f[1]=="1" },
        "literal" => SimpleMatch::Char(f[1].parse().unwrap()),
        "nocase" => SimpleMatch::CharNoCase(f[1].parse().unwrap(),f[2].parse().unwrap()),
        "class" => SimpleMatch::CharClass {
            ranges:vec![CharRange { start:f[2].parse().unwrap(),end:f[3].parse().unwrap() }],negated:f[1]=="1"
        },
        "builtin" => SimpleMatch::BuiltinClass(crate::builtin(f[1].parse().unwrap())),
        "property" => {
            let value=match f[3] {"-"=>None,"<empty>"=>Some(String::new()),v=>Some(v.to_string())};
            let resolved=if f[4]=="-" {None} else {crate::character_types::resolve_property(f[4],None)};
            SimpleMatch::UnicodeProperty(Box::new(UnicodePropertyData { name:f[2].into(),value,negated:f[1]=="1",resolved }))
        },
        "union" => SimpleMatch::Union(Box::new(matcher(f[1].parse().unwrap())),Box::new(matcher(f[2].parse().unwrap()))),
        _=>panic!("unknown fixture matcher"),
    }
}
pub fn hints(index: u32) -> PatternHints {
    let mut hints=PatternHints {first_char:None,first_filter:None,start_position_hint:None,
        starts_with_anchor:false,anchor_multiline:false,trailing_literal:None,required_literal:None,
        simple_scan:None,can_match_empty:false};
    match index {
        0=>{}, 1=>hints.can_match_empty=true,
        2=>hints.starts_with_anchor=true,
        3=>{hints.starts_with_anchor=true;hints.can_match_empty=true;hints.anchor_multiline=true;},
        4=>hints.first_char=Some((65,false)), 5=>hints.first_char=Some((65,true)),
        6=>hints.first_char=Some((0x10400,false)),
        7=>hints.first_filter=Some(matcher(6)), 8=>hints.first_filter=Some(matcher(0)),
        9=>hints.first_filter=Some(matcher(15)), 10=>hints.first_filter=Some(matcher(21)),
        11=>hints.first_filter=Some(matcher(22)),
        12=>{hints.starts_with_anchor=true;hints.first_char=Some((65,true));hints.first_filter=Some(matcher(17));},
        13=>{hints.starts_with_anchor=true;hints.first_filter=Some(matcher(33));},
        14=>{hints.trailing_literal=Some(vec![0x7a,0x7a]);hints.required_literal=Some(RequiredLiteralHint {literal:vec![0x7a],ascii_case_insensitive:false});},
        15=>{hints.first_char=Some((0x10400,true));hints.first_filter=Some(matcher(15));hints.can_match_empty=true;},
        16=>{hints.first_filter=Some(matcher(6));hints.can_match_empty=true;},
        17=>{hints.first_char=Some((10,false));hints.first_filter=Some(matcher(1));hints.starts_with_anchor=true;},
        _=>panic!("unknown fixture hints"),
    }
    hints
}
fn program(flags: u32) -> Program {
    let mut p=Program::new();
    p.unicode=flags&1!=0;p.unicode_sets=flags&2!=0;p.ignore_case=flags&4!=0;p.dot_all=flags&8!=0;
    p
}
pub fn simple_bits(cp: u32,index: usize) -> String {
    let matcher=matcher(index);
    let raw=crate::bit(match_simple_match(&matcher,cp));
    let mut modifiers=0u32;let mut vm_bits=0u32;let mut first_bits=0u32;
    for flag in 0..4 {
        let active=ActiveModifiers {ignore_case:flag&1!=0,multiline:flag&1==0,dot_all:flag&2!=0};
        modifiers|=(crate::bit(match_simple_with_modifiers(&matcher,cp,&active)) as u32)<<flag;
    }
    let units=if cp<0x10000 {vec![cp as u16]} else {let n=cp-0x10000;vec![(0xd800+(n>>10)) as u16,(0xdc00+(n&1023)) as u16]};
    for flag in 0..16 {
        let p=program(flag);
        first_bits|=(crate::bit(first_filter_matches(&p,units.as_slice(),0,&matcher)) as u32)<<flag;
        let mut scratch=VmScratch::default();
        let mut vm=Vm::new(&p,&[] as &[u16],7,&mut scratch);
        vm.modifiers.ignore_case=flag&4!=0;vm.modifiers.multiline=flag&4==0;vm.modifiers.dot_all=flag&8!=0;
        vm.steps=13;
        vm_bits|=(crate::bit(vm.match_simple(cp,&matcher)) as u32)<<flag;
        assert_eq!((vm.pos,vm.pc,vm.steps),(7,0,13));
    }
    format!("{raw}|{modifiers:x}|{vm_bits:04x}|{first_bits:04x}")
}
pub fn first<I: Input>(input: I,flags: u32,pos: usize,target: u32) -> bool {
    first_char_matches(&program(flags),input,pos,target,flags&16!=0)
}
pub fn candidate<I: Input>(input: I,flags: u32,start: usize,index: u32) -> Option<usize> {
    next_candidate_start(&program(flags),input,&hints(index),start)
}
'''

DRIVER = r'''
use std::io::{self,BufRead};
unsafe extern "C" {fn oracle_set_locale();}
fn main() {
    unsafe {oracle_set_locale();}
    for line in io::stdin().lock().lines() {
        let line=line.unwrap();let f:Vec<&str>=line.split('\t').collect();assert_eq!(f.len(),5);
        let cp:u32=f[1].parse().unwrap();let a:usize=f[2].parse().unwrap();let b:u32=f[3].parse().unwrap();
        let result=match f[0] {
            "simple"=>oracle_vm::simple_bits(cp,a),
            "first" | "candidate"=> {
                let (kind,text)=f[4].split_once('!').unwrap();
                let units:Vec<u16>=if text=="-" {vec![]} else {text.split(',').map(|s|s.parse().unwrap()).collect()};
                if f[0]=="first" {
                    bit(if kind=="u" {oracle_vm::first(units.as_slice(),cp,a,b)} else {oracle_vm::first(units.iter().map(|v|u8::try_from(*v).unwrap()).collect::<Vec<_>>().as_slice(),cp,a,b)}).to_string()
                } else {
                    let result=if kind=="u" {oracle_vm::candidate(units.as_slice(),cp,a,b)} else {oracle_vm::candidate(units.iter().map(|v|u8::try_from(*v).unwrap()).collect::<Vec<_>>().as_slice(),cp,a,b)};
                    result.map(|v|v.to_string()).unwrap_or_else(||"-".into())
                }
            },
            _=>panic!("unknown predicate operation"),
        };println!("{line}\t{result}");
    }
}
'''


def inputs():
    rng=random.Random(0x963_d46_a8+7)
    fixtures=[('a',[]),('a',[65]),('a',[97,10,65,53,32,48,95]),('a',[10,13,10]),
              ('a',[0,127,128,255,97]),('u',[0xd801,0xdc00]),
              ('u',[0xd801,0xdc00,10,0x104,65,0xdc00]),
              ('u',[0x212a,0x17f,0x3a3,0x3c2,0x30fc,0x3042,0xf882]),
              ('u',[0xd800,65,0xdc00,0xdbff,0xdfff]),('u',[65,0x2028,83,0x2029,10])]
    palette=[0,9,10,13,32,48,65,83,97,115,0x130,0x17f,0x212a,0x2028,0xd801,0xdc00,0xd800,0xdc01]
    for _ in range(70):
        fixtures.append(('u',[rng.choice(palette) for _ in range(rng.randrange(1,12))]))
    return fixtures


def cases():
    rng=random.Random(0x963_d46_a8+8)
    palette=[0,9,10,13,32,48,65,83,97,115,0xdf,0xe9,0x130,0x131,0x17f,0x3a3,0x3c2,0x3c3,
             0x1e9e,0x212a,0x2028,0x2029,0x30fc,0x3042,0xd800,0xdc00,0xf882,0xffff,
             0x10400,0x10428,0x1f600,0x10ffff]
    for cp in list(range(0x10000))+[rng.randrange(0x10000,0x110000) for _ in range(300)]:
        for index in [12,22]:yield 'simple',cp,index,0,'-'
    for cp in palette+[rng.randrange(0x110000) for _ in range(500)]:
        for index in range(len(MATCHERS)):yield 'simple',cp,index,0,'-'
    for kind,units in inputs():
        text=kind+'!'+(','.join(map(str,units)) or '-')
        for flag in [0,1,4,5,15]:
            for pos in range(len(units)+2):
                for index in range(18):yield 'candidate',flag,pos,index,text
        for flag in [0,1,4,5,15,16,17,20,21,31]:
            for pos in range(len(units)+2):
                for target in palette:yield 'first',flag,pos,target,text


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-predicates.tsv')
    args=parser.parse_args();upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    definitions='const MATCHERS: &[&str] = &['+','.join(json.dumps(v) for v in MATCHERS)+'];\n'
    answers=matching.native_outputs(upstream,build,prefix,args.simdutf_prefix.resolve(),args.jobs,
                                   properties.cpp_source(upstream),WRAPPERS,definitions+DRIVER,records)
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibRegex/LibUnicode/AK {revision}; native exact matcher predicates; locale en_US_POSIX\n'
    header+='# operation, code point / flags, matcher / position, argument, input, result\n'
    # Split by operation and keep each embedded file below V's 5 MB limit.
    for suffix,operation in [('', 'simple'),('-candidate','candidate'),('-first','first')]:
        values=[line for line in answers if line.split('\t')[0]==operation]
        chunks=[];current=[];size=len(header.encode())
        for line in values:
            line_size=len(line.encode())+1
            if size+line_size>4_900_000:chunks.append(current);current=[];size=len(header.encode())
            current.append(line);size+=line_size
        if current:chunks.append(current)
        for index,chunk in enumerate(chunks):
            part=f'-{index+1}' if len(chunks)>1 else ''
            output=args.output.with_name(args.output.stem+suffix+part+args.output.suffix)
            output.write_text(header+'\n'.join(chunk)+'\n')
            print(f'{len(chunk)} exact regex predicate fixtures written to {output}')
    output=args.output.with_name(args.output.stem+'-matchers'+args.output.suffix)
    output.write_text('# Fixture matcher records; matching is performed by unchanged source bodies\n'
                      +'\n'.join(f'{index}\t{value}' for index,value in enumerate(MATCHERS))+'\n')


if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        if error.stderr:sys.stderr.write(error.stderr)
        raise
