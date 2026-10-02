#!/usr/bin/env python3
"""Record greedy consumption, suffix measurements and complete backtrack state.

The oracle imports unchanged Rust VM bodies and freshly builds native LibUnicode
and AK. It does not call a regex parser, compiler or VM execution loop.
"""
import argparse
import json
from pathlib import Path
import random
import subprocess
import sys

import libjs_regex_core_corpus as core
import libjs_regex_matching_corpus as matching
import libjs_regex_predicate_corpus as predicates
import libjs_regex_property_corpus as properties

MATCHERS = predicates.MATCHERS + ['literal:65601', 'union:37:5']

WRAPPERS = r'''
fn active(flags: u32) -> ActiveModifiers {
    ActiveModifiers {ignore_case:flags&4!=0,multiline:flags&16!=0,dot_all:flags&8!=0}
}
fn loop_program(flags: u32, index: usize, variant: u32, minimum: u32) -> Program {
    let mut p=program(flags);p.multiline=flags&16!=0;p.register_count=4;
    let m=matcher(index);
    let greedy=Instruction::GreedyLoop {matcher:m.clone(),min:minimum,max:None};
    let lazy=|min|Instruction::LazyLoop {matcher:m.clone(),min,max:None};
    p.instructions=match variant {
        0=>vec![greedy,Instruction::Nop],
        1=>vec![greedy,Instruction::Char(65)],
        2=>vec![greedy,Instruction::Char(0x10400)],
        3=>vec![greedy,Instruction::Char(0xdc00)],
        4=>vec![greedy,Instruction::GreedyLoop {matcher:m.clone(),min:2,max:None},lazy(1),Instruction::Nop],
        5=>vec![greedy,lazy(0),Instruction::Nop],
        6=>vec![greedy,Instruction::LazyLoop {matcher:SimpleMatch::Char(66),min:3,max:None},Instruction::Nop],
        7=>vec![greedy,Instruction::GreedyLoop {matcher:m.clone(),min:u32::MAX,max:None},lazy(1)],
        8=>vec![lazy(0),Instruction::Nop],
        9=>vec![Instruction::Nop],
        10=>vec![greedy,Instruction::GreedyLoop {matcher:m.clone(),min:1,max:None},Instruction::Nop],
        11=>vec![greedy],
        12=>vec![greedy,Instruction::Char(0x10041)],
        _=>panic!("unknown fixture loop program"),
    };p
}
fn modifier_text(m: &ActiveModifiers) -> u32 {
    crate::bit(m.ignore_case) as u32 | ((crate::bit(m.multiline) as u32)<<1) | ((crate::bit(m.dot_all) as u32)<<2)
}
fn list_text(values: &[i32]) -> String {
    values.iter().map(|v|v.to_string()).collect::<Vec<_>>().join(",")
}
fn state_text<I: Input>(vm: &Vm<I>) -> String {
    let scopes=vm.modifier_stack.iter().map(|v|modifier_text(v).to_string()).collect::<Vec<_>>().join(",");
    let stack=vm.backtrack_stack.iter().map(|s|match s {
        SavedState::Normal {pc,pos,reg_snapshot_offset,modifiers,modifier_stack_len}=>
            format!("n,{pc},{pos},{reg_snapshot_offset},{},{modifier_stack_len}",modifier_text(modifiers)),
        SavedState::Greedy {pc,start_pos,current_pos,reg_snapshot_offset,min,backward,modifiers,modifier_stack_len}=>
            format!("g,{pc},{start_pos},{current_pos},{reg_snapshot_offset},{min},{},{},{modifier_stack_len}",crate::bit(*backward),modifier_text(modifiers)),
        SavedState::Lazy {pc,pos,reg_snapshot_offset,max,consumed,modifiers,modifier_stack_len}=>
            format!("l,{pc},{pos},{reg_snapshot_offset},{},{consumed},{},{modifier_stack_len}",max.map(|v|v.to_string()).unwrap_or_else(||"-".into()),modifier_text(modifiers)),
    }).collect::<Vec<_>>().join(";");
    format!("{},{},{},{},{},{}!{}!{}!{scopes}!{stack}",vm.pc,vm.pos,vm.steps,modifier_text(&vm.modifiers),crate::bit(vm.backward),vm.bt_floor,list_text(vm.registers),list_text(vm.register_pool))
}
pub fn operation<I: Input>(input: I, op: &str,flags: u32,pos: usize,arg: &str,index: usize) -> String {
    if op=="consume" {
        let mut end=pos;let max=if arg=="-" {None} else {Some(arg.parse().unwrap())};
        let count=Vm::greedy_consume_fast(input,&mut end,&matcher(index),&active(flags),max);
        return format!("{count},{end}");
    }
    let spec:Vec<&str>=arg.split(':').collect();
    let variant=if op=="available" {0} else {spec[0].parse().unwrap()};
    let minimum=if op=="backtrack" {spec[2].parse().unwrap()} else {0};
    let p=loop_program(flags,index,variant,minimum);
    let mut scratch=VmScratch::new();let mut vm=Vm::new(&p,input,pos,&mut scratch);
    vm.modifiers=active(flags);vm.backward=flags&32!=0;vm.pc=99;vm.steps=13;
    if op=="available" {
        let count=vm.count_available_same_matcher_chars(pos,&matcher(index),arg.parse().unwrap(),flags&64!=0);
        assert_eq!((vm.pos,vm.pc,vm.steps,vm.backward),(pos,99,13,flags&32!=0));
        return count.to_string();
    }
    if op=="suffix" {
        let result=vm.same_matcher_loop_suffix_deficit(0,pos,flags&64!=0);
        assert_eq!((vm.pos,vm.pc,vm.steps,vm.backward),(pos,99,13,flags&32!=0));
        return result.map(|v|v.to_string()).unwrap_or_else(||"-".into());
    }
    assert_eq!(op,"backtrack");
    let choice:u32=spec[1].parse().unwrap();
    let maximum=if spec[3]=="-" {None} else {Some(spec[3].parse().unwrap())};
    let consumed=spec[4].parse().unwrap();let floor=spec[5].parse().unwrap();let rounds:u32=spec[6].parse().unwrap();
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
    vm.registers.copy_from_slice(&[31,32,33,34]);vm.pc=99;vm.pos=pos;vm.steps=13;
    vm.backward=flags&32!=0;vm.bt_floor=floor;
    let mut trace=vec![state_text(&vm)];
    for _ in 0..rounds {let result=vm.backtrack();trace.push(format!("{}~{}",crate::bit(result),state_text(&vm)));}
    trace.join("|")
}
'''

DRIVER = r'''
use std::io::{self,BufRead};
unsafe extern "C" {fn oracle_set_locale();}
fn main() {
    unsafe {oracle_set_locale();}
    for line in io::stdin().lock().lines() {
        let line=line.unwrap();let f:Vec<&str>=line.split('\t').collect();assert_eq!(f.len(),6);
        let flags=f[1].parse().unwrap();let pos=f[2].parse().unwrap();let index=f[4].parse().unwrap();
        let (kind,text)=f[5].split_once('!').unwrap();
        let units:Vec<u16>=if text=="-" {vec![]} else {text.split(',').map(|s|s.parse().unwrap()).collect()};
        let result=if kind=="u" {oracle_vm::operation(units.as_slice(),f[0],flags,pos,f[3],index)} else {
            oracle_vm::operation(units.iter().map(|v|u8::try_from(*v).unwrap()).collect::<Vec<_>>().as_slice(),f[0],flags,pos,f[3],index)
        };println!("{line}\t{result}");
    }
}
'''


def cases():
    rng=random.Random(0x963_d46_a8+10)
    fixtures=predicates.inputs()[:26]+[
        ('a',[65,65,65,65]),('a',[97,97,97,97]),('a',[66,65,66,65,66]),
        ('u',[0xd801,0xdc00,0xd801,0xdc00]),('u',[0xd800,0xdc41,65,0xd800,0xdc41]),
        ('u',[0x3c3,0x3c2,0x3a3,0x3c3]),('u',[0x17f,83,115,0x212a,107]),
    ]
    for kind,units in fixtures:
        text=kind+'!'+(','.join(map(str,units)) or '-')
        positions=sorted({0,1,len(units)//2,len(units)} & set(range(len(units)+1)))
        for pos in positions:
            for index in range(len(MATCHERS)):
                for flags in [0,4,8,12]:
                    for maximum in ['-',0,1,3]:yield 'consume',flags,pos,maximum,index,text
                for flags in [0,1,3,4,5,15]:
                    for backward in [0,64]:
                        for maximum in [0,1,3]:yield 'available',flags|backward|32,pos,maximum,index,text
            for index in [0,5,12,21,22,33]:
                for flags in [0,1,3,4,5,15]:
                    for backward in [0,64]:
                        for variant in range(13):yield 'suffix',flags|backward,pos,variant,index,text
    for choice in range(4):
        for _ in range(2500 if choice else 500):
            kind,units=rng.choice(fixtures);text=kind+'!'+(','.join(map(str,units)) or '-')
            if choice in [1,2] and not units:continue
            pos=rng.randrange(len(units)+1)
            if choice==1 and pos==0:continue
            if choice==2 and pos==len(units):continue
            # Greedy states only require a nonempty consumed span; the source
            # applies character boundaries when computing their minimum.
            minimum=rng.randrange(2) if choice in [1,2] else 0
            flags=rng.choice([0,1,3,4,5,7,15,31,32,33,37,47])
            variant=8 if choice==3 else (9 if choice==0 else rng.choice([0,1,2,3,4,5,6,7,10,11,12]))
            maximum=rng.choice(['-',0,1,2]);consumed=rng.choice([0,1,2,4294967295])
            # Avoid native u32 overflow: consumed at MAX is legal only when a
            # finite maximum prevents another successful lazy consumption.
            if consumed==4294967295:maximum=2
            floor=rng.choice([0,0,0,1,2,3]);rounds=4
            spec=f'{variant}:{choice}:{minimum}:{maximum}:{consumed}:{floor}:{rounds}'
            yield 'backtrack',flags,pos,spec,rng.randrange(len(MATCHERS)),text


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-backtracking.tsv')
    args=parser.parse_args();upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    definitions='const MATCHERS: &[&str] = &['+','.join(json.dumps(v) for v in MATCHERS)+'];\n'
    answers=matching.native_outputs(upstream,build,prefix,args.simdutf_prefix.resolve(),args.jobs,
                                   properties.cpp_source(upstream),predicates.WRAPPERS+WRAPPERS,definitions+DRIVER,records)
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibRegex/LibUnicode/AK {revision}; exact loop/backtrack state; locale en_US_POSIX\n'
    header+='# operation, flags, position, argument, matcher, input, complete result\n'
    for operation in ['consume','available','suffix','backtrack']:
        values=[line for line in answers if line.split('\t')[0]==operation]
        chunks=[];current=[];size=len(header.encode())
        for line in values:
            line_size=len(line.encode())+1
            if size+line_size>4_900_000:chunks.append(current);current=[];size=len(header.encode())
            current.append(line);size+=line_size
        if current:chunks.append(current)
        for index,chunk in enumerate(chunks):
            part=f'-{index+1}' if len(chunks)>1 else ''
            output=args.output.with_name(args.output.stem+'-'+operation+part+args.output.suffix)
            output.write_text(header+'\n'.join(chunk)+'\n')
            print(f'{len(chunk)} exact {operation} fixtures written to {output}')
    output=args.output.with_name(args.output.stem+'-matchers'+args.output.suffix)
    output.write_text('# Fixture matcher records; unchanged native source bodies perform matching\n'
                      +'\n'.join(f'{index}\t{value}' for index,value in enumerate(MATCHERS))+'\n')


if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        if error.stderr:sys.stderr.write(error.stderr)
        raise
