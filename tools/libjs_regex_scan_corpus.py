#!/usr/bin/env python3
"""Compare simple and greedy scan execution with unchanged native Rust helpers.

Exercises UTF-16/byte inputs and capture-buffer boundaries. Does not invoke the
regex parser/compiler, backtracking dispatcher or general VM execution loop.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

import libjs_regex_core_corpus as core
import libjs_regex_matching_corpus as matching
import libjs_regex_predicate_corpus as predicates
import libjs_regex_property_corpus as properties

SCANS = [
    'literal:65', 'literal:66560', 'literal:56320', 'class:0:65:90',
    'class:1:65:90', 'builtin:2', 'builtin:3', 'builtin:4', 'builtin:0',
    'greedy:15:1:-', 'greedy:15:3:-', 'greedy:15:1:2', 'greedy:15:0:-',
    'greedy:15:0:0', 'greedy:15:0:2', 'greedy:0:1:3', 'greedy:1:1:-',
    'greedy:21:1:-', 'greedy:22:1:2', 'greedy:8:2:-', 'greedy:11:2:-',
    'greedy:5:1:-', 'greedy:36:1:3', 'greedy:15:2:2', 'greedy:15:4:4',
    'greedy:25:1:-', 'greedy:28:1:-',
]

WRAPPERS = r'''
fn scanner(index: usize) -> SimpleScan {
    let f:Vec<&str>=crate::SCANS[index].split(':').collect();
    match f[0] {
        "literal"=>SimpleScan::Char(f[1].parse().unwrap()),
        "class"=>SimpleScan::CharClass {ranges:vec![CharRange {start:f[2].parse().unwrap(),end:f[3].parse().unwrap()}],negated:f[1]=="1"},
        "builtin"=>SimpleScan::BuiltinClass(crate::builtin(f[1].parse().unwrap())),
        "greedy"=>SimpleScan::GreedyQuantifier {matcher:matcher(f[1].parse().unwrap()),min:f[2].parse().unwrap(),max:if f[3]=="-" {None} else {Some(f[3].parse().unwrap())}},
        _=>panic!("unknown native fixture scanner"),
    }
}
pub fn scan_text<I: Input>(input: I,flags: u32,start: usize,index: usize) -> String {
    let p=program(flags);let scan=scanner(index);
    let mut output=vec![91,92,93,94,95];
    let result=execute_simple_scan_into(&p,input,start,&scan,&mut output);
    if let SimpleScan::GreedyQuantifier {matcher,min,max}=&scan {
        let mut direct=vec![91,92,93,94,95];
        assert_eq!(result,execute_simple_greedy_scan_into(&p,input,start,matcher,*min,*max,&mut direct));
        assert_eq!(output,direct);
    }
    let mut parts=vec![format!("{}!{}",crate::bit(result),output.iter().map(|v|v.to_string()).collect::<Vec<_>>().join(","))];
    for capacity in [0,1,2,3,4,5,8,12] {
        let mut output=vec![91;capacity];
        let count=find_all_simple_scan(&p,input,start,&scan,&mut output);
        parts.push(format!("{count}!{}",output.iter().map(|v|v.to_string()).collect::<Vec<_>>().join(",")));
    }
    parts.join("|")
}
'''

DRIVER = r'''
use std::io::{self,BufRead};
unsafe extern "C" {fn oracle_set_locale();}
fn main() {
    unsafe {oracle_set_locale();}
    for line in io::stdin().lock().lines() {
        let line=line.unwrap();let f:Vec<&str>=line.split('\t').collect();assert_eq!(f.len(),5);
        let flags:u32=f[1].parse().unwrap();let start:usize=f[2].parse().unwrap();let index:usize=f[3].parse().unwrap();
        let (kind,text)=f[4].split_once('!').unwrap();
        let units:Vec<u16>=if text=="-" {vec![]} else {text.split(',').map(|s|s.parse().unwrap()).collect()};
        let result=if kind=="u" {oracle_vm::scan_text(units.as_slice(),flags,start,index)} else {
            oracle_vm::scan_text(units.iter().map(|v|u8::try_from(*v).unwrap()).collect::<Vec<_>>().as_slice(),flags,start,index)
        };
        println!("{line}\t{result}");
    }
}
'''


def cases():
    fixtures=predicates.inputs()+[
        ('a',[32,97,32,97,98,99,32,97,98,99,100,32]),
        ('u',[0xd801,0xdc00,32,0xd801,0xdc00,0xd801,0xdc00,0xd801,0xdc00]),
        ('u',[97,65,0x17f,83,0x212a,107,32,97,98,99,100]),
    ]
    for kind,units in fixtures:
        text=kind+'!'+(','.join(map(str,units)) or '-')
        positions=sorted({0,1,len(units)//2,len(units),len(units)+1}
                         | {i for i,unit in enumerate(units) if 0xdc00<=unit<=0xdfff})
        for flags in [0,1,15]:
            for start in positions:
                for index in range(len(SCANS)):yield 'scan',flags,start,index,text


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-scans.tsv')
    args=parser.parse_args();upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    definitions='const MATCHERS: &[&str] = &['+','.join(json.dumps(v) for v in predicates.MATCHERS)+'];\n'
    definitions+='const SCANS: &[&str] = &['+','.join(json.dumps(v) for v in SCANS)+'];\n'
    answers=matching.native_outputs(upstream,build,prefix,args.simdutf_prefix.resolve(),args.jobs,
                                   properties.cpp_source(upstream),predicates.WRAPPERS+WRAPPERS,definitions+DRIVER,records)
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibRegex/LibUnicode/AK {revision}; native exact simple scan execution; locale en_US_POSIX\n'
    header+='# operation, flags, start, scanner, input, complete single/find-all capture buffers\n'
    chunks=[];current=[];size=len(header.encode())
    for line in answers:
        line_size=len(line.encode())+1
        if size+line_size>4_900_000:chunks.append(current);current=[];size=len(header.encode())
        current.append(line);size+=line_size
    if current:chunks.append(current)
    for index,chunk in enumerate(chunks):
        part=f'-{index+1}' if len(chunks)>1 else ''
        output=args.output.with_name(args.output.stem+part+args.output.suffix)
        output.write_text(header+'\n'.join(chunk)+'\n')
        print(f'{len(chunk)} exact regex scan fixtures written to {output}')
    output=args.output.with_name(args.output.stem+'-scanners'+args.output.suffix)
    output.write_text('# Fixture scanner records; execution uses unchanged source bodies\n'
                      +'\n'.join(f'{index}\t{value}' for index,value in enumerate(SCANS))+'\n')


if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        if error.stderr:sys.stderr.write(error.stderr)
        raise
