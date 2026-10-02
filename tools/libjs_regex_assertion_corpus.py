#!/usr/bin/env python3
"""Compare shared regex failure/assertion handlers and their complete VM state.

Uses unchanged upstream Rust handlers, backtracking and native LibUnicode/AK.
Fixture programs and saved choices are supplied without a parser or VM loop.
"""
import argparse
import json
from pathlib import Path
import random
import subprocess
import sys

import libjs_regex_backtrack_corpus as backtrack
import libjs_regex_core_corpus as core
import libjs_regex_matching_corpus as matching
import libjs_regex_predicate_corpus as predicates
import libjs_regex_property_corpus as properties

WRAPPERS = r'''
pub fn assertion_operation<I: Input>(input: I, op: &str,flags: u32,pos: usize,arg: &str,index: usize) -> String {
    let spec:Vec<&str>=arg.split(':').collect();
    let minimum=spec[2].parse().unwrap();
    let p=loop_program(flags,index,spec[0].parse().unwrap(),minimum);
    let mut scratch=VmScratch::new();let mut vm=Vm::new(&p,input,pos,&mut scratch);
    vm.modifiers=active(flags);
    let choice:u32=spec[1].parse().unwrap();
    let maximum=if spec[3]=="-" {None} else {Some(spec[3].parse().unwrap())};
    let consumed=spec[4].parse().unwrap();let floor=spec[5].parse().unwrap();let rounds:u32=spec[6].parse().unwrap();
    let cached_len=spec[7].parse().unwrap();
    if choice!=4 {
        vm.registers.copy_from_slice(&[11,12,13,14]);vm.push_backtrack(77,pos);
        vm.handle_push_modifiers(Some(flags&4==0),Some(flags&16==0),Some(flags&8==0));
        vm.registers.copy_from_slice(&[21,22,23,24]);
        match choice {
            0=>vm.push_backtrack(55,pos),
            1 | 2=>{vm.backward=choice==2;vm.push_greedy_backtrack(0,if choice==2 {input.len()} else {0},pos,minimum);},
            3=>vm.push_lazy_backtrack(0,pos,maximum,consumed),
            _=>panic!("unknown saved choice"),
        }
        vm.handle_push_modifiers(Some(flags&4!=0),Some(flags&16!=0),Some(flags&8!=0));
    }
    vm.registers.copy_from_slice(&[31,32,33,34]);vm.pc=99;vm.pos=pos;vm.steps=13;
    vm.backward=flags&32!=0;vm.bt_floor=floor;
    let mut trace=vec![state_text(&vm)];
    for _ in 0..rounds {
        let result=match op {
            "fail"=>vm.fail_current_path(),
            "start"=>vm.handle_assert_start(flags&128!=0),
            "end"=>vm.handle_assert_end(flags&128!=0,cached_len),
            "word"=>vm.handle_word_boundary_assert(flags&128!=0),
            _=>panic!("unknown assertion operation"),
        };
        let result=match result {None=>"-",Some(VmResult::NoMatch)=>"no_match",_=>panic!("unexpected handler result")};
        trace.push(format!("{result}~{}",state_text(&vm)));
    }
    trace.join("|")
}
'''

DRIVER = backtrack.DRIVER.replace('oracle_vm::operation(', 'oracle_vm::assertion_operation(')


def cases():
    rng=random.Random(0x963_d46_a8+11)
    fixtures=predicates.inputs()+[
        ('a',[65,65,65,65]),('a',[10,65,13,66]),
        ('u',[0xd801,0xdc00,0xd801,0xdc00]),
        ('u',[0x2028,0x17f,0x2029,0x212a,10,0x3c3]),
    ]
    for op in ['fail','start','end','word']:
        for _ in range(2500):
            kind,units=rng.choice(fixtures);text=kind+'!'+(','.join(map(str,units)) or '-')
            pos=rng.randrange(len(units)+1);choice=rng.randrange(5)
            if choice==1 and pos==0:continue
            if choice==2 and pos==len(units):continue
            minimum=rng.randrange(2) if choice in [1,2] else 0
            flags=rng.choice([0,1,3,4,5,7,15,16,17,31,32,33,37,47])|rng.choice([0,128])
            variant=8 if choice==3 else (9 if choice in [0,4] else rng.choice([0,1,2,3,4,5,6,7,10,11,12]))
            maximum=rng.choice(['-',0,1,2]);consumed=rng.randrange(3)
            floor=rng.choice([0,0,0,1,2,3]);rounds=4
            cached_len=rng.choice([0,pos,len(units)]) if op=='end' else len(units)
            spec=f'{variant}:{choice}:{minimum}:{maximum}:{consumed}:{floor}:{rounds}:{cached_len}'
            yield op,flags,pos,spec,rng.randrange(len(backtrack.MATCHERS)),text


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-assertions.tsv')
    args=parser.parse_args();upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    definitions='const MATCHERS: &[&str] = &['+','.join(json.dumps(v) for v in backtrack.MATCHERS)+'];\n'
    answers=matching.native_outputs(upstream,build,prefix,args.simdutf_prefix.resolve(),args.jobs,
                                   properties.cpp_source(upstream),predicates.WRAPPERS+backtrack.WRAPPERS+WRAPPERS,definitions+DRIVER,records)
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibRegex/LibUnicode/AK {revision}; exact assertion/failure state; locale en_US_POSIX\n'
    header+='# operation, flags, position, argument, matcher, input, complete result\n'
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
        print(f'{len(chunk)} exact assertion fixtures written to {output}')


if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        if error.stderr:sys.stderr.write(error.stderr)
        raise
