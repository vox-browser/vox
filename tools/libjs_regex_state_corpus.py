#!/usr/bin/env python3
"""Refresh exact VM state/traversal fixtures from unchanged pinned LibRegex Rust.

Only construction/reset, storage/snapshot, modifier/repeat and traversal methods
are invoked. Matcher execution, backtracking dispatch and Unicode FFI stay unused.
"""
import argparse
import itertools
from pathlib import Path
import random
import subprocess
import tempfile

import libjs_regex_core_corpus as core
import libjs_regex_hints_corpus as hints

WRAPPERS = r'''
fn mods(m: ActiveModifiers) -> u8 {
    u8::from(m.ignore_case) | (u8::from(m.multiline) << 1) | (u8::from(m.dot_all) << 2)
}
fn ints(values: &[i32]) -> String {
    if values.is_empty() { "-".into() } else { values.iter().map(|v| v.to_string()).collect::<Vec<_>>().join(",") }
}
fn saved(s: &SavedState) -> String {
    match s {
        SavedState::Normal { pc,pos,reg_snapshot_offset,modifiers,modifier_stack_len } => format!("n:{pc}:{pos}:{reg_snapshot_offset}:{}:{modifier_stack_len}",mods(*modifiers)),
        SavedState::Greedy { pc,start_pos,current_pos,reg_snapshot_offset,min,backward,modifiers,modifier_stack_len } => format!("g:{pc}:{start_pos}:{current_pos}:{reg_snapshot_offset}:{min}:{}:{}:{modifier_stack_len}",crate::bit(*backward),mods(*modifiers)),
        SavedState::Lazy { pc,pos,reg_snapshot_offset,max,consumed,modifiers,modifier_stack_len } => format!("l:{pc}:{pos}:{reg_snapshot_offset}:{}:{consumed}:{}:{modifier_stack_len}",max.map(|v| v.to_string()).unwrap_or_else(|| "-".into()),mods(*modifiers)),
    }
}
fn state<I: Input>(vm: &Vm<'_, I>) -> String {
    let choices = if vm.backtrack_stack.is_empty() { "-".into() } else { vm.backtrack_stack.iter().map(saved).collect::<Vec<_>>().join("/") };
    let modifiers = if vm.modifier_stack.is_empty() { "-".into() } else { vm.modifier_stack.iter().map(|&m| mods(m).to_string()).collect::<Vec<_>>().join(",") };
    format!("{}|{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",vm.pc,vm.pos,vm.steps,mods(vm.modifiers),crate::bit(vm.backward),vm.bt_floor,vm.input_len(),ints(vm.registers),ints(vm.register_pool),choices,modifiers)
}
fn optional_bool(text: &str) -> Option<bool> { if text == "-" { None } else { Some(text == "1") } }
fn optional_max(text: &str) -> Option<u32> { if text == "-" { None } else { Some(text.parse().unwrap()) } }
pub fn transcript<I: Input>(mut program: Program, input: I, count: u32, initial: usize, start: usize, sequence: &str) -> String {
    program.register_count = count;
    let mut scratch = VmScratch::new();
    scratch.registers = vec![99;initial]; scratch.register_pool.push(9);
    scratch.modifier_stack.push(ActiveModifiers { ignore_case:false,multiline:true,dot_all:false });
    scratch.backtrack_stack.push(SavedState::Normal { pc:9,pos:0,reg_snapshot_offset:0,modifiers:scratch.modifier_stack[0],modifier_stack_len:1 });
    let mut vm = Vm::new(&program,input,start,&mut scratch);
    let mut output = vec![state(&vm)];
    for operation in sequence.split(';') {
        let f: Vec<&str> = operation.split(',').collect();
        let n = |i: usize| f[i].parse::<u64>().unwrap();
        match f[0] {
            "v" => vm.registers[n(1) as usize] = f[2].parse().unwrap(),
            "s" => { vm.snapshot_registers(); }, "o" => vm.restore_registers(n(1) as usize),
            "n" => vm.push_backtrack(n(1) as u32,n(2) as usize),
            "m" => vm.push_backtrack_modified(n(1) as u32,n(2) as usize,n(3) as usize,f[4].parse().unwrap()),
            "g" => vm.push_greedy_backtrack(n(1) as u32,n(2) as usize,n(3) as usize,n(4) as u32),
            "l" => vm.push_lazy_backtrack(n(1) as u32,n(2) as usize,optional_max(f[3]),n(4) as u32),
            "p" => vm.handle_push_modifiers(optional_bool(f[1]),optional_bool(f[2]),optional_bool(f[3])),
            "q" => vm.handle_pop_modifiers(),
            "d" => { vm.backward=n(1)!=0; vm.steps=n(2); vm.bt_floor=n(3) as usize; },
            "c" => { vm.pc=n(1) as u32; vm.pos=n(2) as usize; }, "z" => vm.reset(n(1) as usize),
            "r" => vm.handle_repeat_start(n(1) as u32),
            "t" => vm.handle_repeat_check(n(1) as u32,n(2) as u32,optional_max(f[3]),n(4) as u32,n(5)!=0),
            _ => panic!("unknown state operation"),
        }
        output.push(state(&vm));
    }
    output.join("~")
}
pub fn walk<I: Input>(unicode: bool, input: I, pos: usize, count: u32) -> String {
    let mut program=Program::new(); program.unicode=unicode;
    let mut scratch=VmScratch::new(); let mut vm=Vm::new(&program,input,pos,&mut scratch);
    let forward=vm.current_code_point().map(|v|v.to_string()).unwrap_or_else(||"-".into());
    vm.advance_char(); let next=vm.pos;
    vm.pos=pos; vm.backward=true;
    let backward=vm.current_code_point().map(|v|v.to_string()).unwrap_or_else(||"-".into());
    vm.advance_char(); let previous=vm.pos;
    format!("{forward}|{backward}|{next}|{previous}|{}|{}|{}|{}",vm.retreat_one_char(pos),vm.advance_one_char(pos),crate::optional(vm.retreat_n_chars(pos,count)),crate::optional(vm.advance_n_chars(pos,count)))
}
pub fn steps(pos: usize, count: u32) -> String {
    let program=Program::new(); let mut scratch=VmScratch::new(); let vm=Vm::new(&program,&[] as &[u16],0,&mut scratch);
    format!("{}|{}",crate::optional(vm.retreat_n_chars(pos,count)),crate::optional(vm.advance_n_chars(pos,count)))
}
pub fn suffix(program: &Program, start: usize, matcher: &SimpleMatch) -> String {
    let mut scratch=VmScratch::new(); let vm=Vm::new(program,&[] as &[u16],0,&mut scratch);
    vm.same_matcher_loop_suffix_min(start,matcher).map(|v|v.to_string()).unwrap_or_else(||"-".into())
}
pub fn verify_invalid_snapshots() {
    std::panic::set_hook(Box::new(|_|{}));
    for mode in ["empty","short","modified"] {
        let outcome=std::panic::catch_unwind(|| {
            let mut program=Program::new(); program.register_count=if mode=="empty" {0} else {2};
            let mut scratch=VmScratch::new(); let mut vm=Vm::new(&program,&[] as &[u16],0,&mut scratch);
            if mode=="modified" {vm.push_backtrack_modified(0,0,2,7);} else {vm.snapshot_registers();vm.restore_registers(1);}
        }); assert!(outcome.is_err());
    }
}
'''

DRIVER = r'''
use std::io::{self,BufRead};
fn main() {
    oracle_vm::verify_invalid_snapshots();
    for line in io::stdin().lock().lines() {
        let line=line.unwrap(); let f:Vec<&str>=line.split('\t').collect(); assert_eq!(f.len(),7);
        let a:u64=f[3].parse().unwrap(); let b:u64=f[4].parse().unwrap(); let c:u64=f[5].parse().unwrap();
        let result=match f[0] {
            "state" => oracle_vm::transcript(program("-",f[1].parse().unwrap()),units(f[2]).as_slice(),a as u32,b as usize,c as usize,f[6]),
            "walk" => {
                let data=units(f[2]);
                if f[1]=="u8" {assert!(data.iter().all(|&v|v<=255));let bytes:Vec<u8>=data.into_iter().map(|v|v as u8).collect();oracle_vm::walk(a!=0,bytes.as_slice(),b as usize,c as u32)}
                else {oracle_vm::walk(a!=0,data.as_slice(),b as usize,c as u32)}
            }
            "steps" => oracle_vm::steps(b as usize,c as u32),
            "suffix" => oracle_vm::suffix(&program(f[6],0),b as usize,&fixture_matcher(c as usize)),
            _ => panic!("unknown fixture"),
        }; println!("{line}\t{result}");
    }
}
'''


def cases():
    rng = random.Random(0x963_d46_a8 + 2)
    for count, initial, flags in itertools.product([0,1,2,5,9],[0,2,12],range(32)):
        sequence='q;p,0,-,1;p,-,0,-;q;d,1,99,3;c,7,9;n,3,5;g,4,2,7,1;l,5,7,-,2;z,4'
        yield 'state',flags,'0061d800dc00',count,initial,11,sequence
    for value, minimum, maximum, greedy in itertools.product([-1,0,1,2,3,0x7fffffff,-0x80000000],[0,1,2,3,0xffffffff],['-',0,1,2,3,0xffffffff],range(2)):
        sequence=f'v,1,{value};c,4294967295,9;t,1,{minimum},{maximum},17,{greedy}'
        yield 'state',rng.randrange(32),'-',2,0,0,sequence
    for _ in range(500):
        count=rng.randrange(9)
        sequence=['s']
        for step in range(16):
            op=rng.choice(['n','g','l','p','q','d','c','z','s','o','r']+(['v','m','t'] if count else []))
            if op=='n': text=f'n,{rng.randrange(25)},{rng.randrange(20)}'
            elif op=='g': text=f'g,{rng.randrange(25)},{rng.randrange(20)},{rng.randrange(20)},{rng.randrange(5)}'
            elif op=='l': text=f'l,{rng.randrange(25)},{rng.randrange(20)},{rng.choice(["-",0,1,9,0xffffffff])},{rng.randrange(5)}'
            elif op=='p': text='p,'+','.join(rng.choice(['-','0','1']) for _ in range(3))
            elif op=='d': text=f'd,{rng.randrange(2)},{rng.randrange(0x100000000)},{rng.randrange(5)}'
            elif op=='c': text=f'c,{rng.choice([0,7,0xffffffff])},{rng.randrange(20)}'
            elif op=='z': text=f'z,{rng.randrange(20)};s'
            elif op=='o': text='o,0'
            elif op=='r': text=f'r,{rng.choice([count,0xffffffff,rng.randrange(count or 1)])}'
            elif op=='v': text=f'v,{rng.randrange(count)},{rng.choice([-1,0,1,3,0x7fffffff,-0x80000000])}'
            elif op=='m': text=f'm,{rng.randrange(25)},{rng.randrange(20)},{rng.randrange(count)},{rng.randrange(-5,6)}'
            elif op=='t': text=f't,{rng.randrange(count)},{rng.choice([0,1,3,0xffffffff])},{rng.choice(["-",0,1,9,0xffffffff])},{rng.randrange(25)},{rng.randrange(2)}'
            else: text=op
            sequence.append(text)
        yield 'state',rng.randrange(32),'006100800062',count,rng.randrange(12),rng.randrange(20),';'.join(sequence)
    for storage,alphabet in [('u16',[0,97,0x80,0xd800,0xdbff,0xdc00,0xdfff]),('u8',[0,97,0x7f,0x80,0xff])]:
        inputs=[(),*itertools.product(alphabet,repeat=2)]
        inputs += [tuple(rng.choice(alphabet) for _ in range(rng.randrange(12))) for _ in range(100)]
        for data in inputs:
            for pos,unicode,count in itertools.product(range(len(data)+1),range(2),[0,1,2,5,0xffffffff]):
                yield 'walk',storage,core.encoded(data),unicode,pos,count,'-'
    for pos,count in itertools.product([0,1,9,0xffffffff,0xffffffffffffffff-1,0xffffffffffffffff],[0,1,2,0xffffffff]):
        yield 'steps','-','-',0,pos,count,'-'
    for matcher,mins,stop in itertools.product(range(10),[(0,0),(1,3),(0xffffffff,0),(0xffffffff,1)],['n','g,2,7,-']):
        instructions=f'g,{matcher},{mins[0]},-;G,{matcher},{mins[1]},9;{stop};g,{matcher},7,-'
        for start in range(5): yield 'suffix','-','-',0,start,matcher,instructions
    for _ in range(300):
        matcher=rng.randrange(10)
        nodes=[f'{rng.choice(["g","G"])},{rng.choice([matcher,matcher,rng.randrange(10)])},{rng.choice([0,1,3,0xffffffff])},-' for _ in range(rng.randrange(9))]
        if rng.randrange(2): nodes.insert(rng.randrange(len(nodes)+1),'n')
        yield 'suffix','-','-',0,rng.randrange(len(nodes)+2),matcher,';'.join(nodes) or '-'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-state.tsv')
    args=parser.parse_args()
    upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    regex=upstream/'Libraries/LibRegex/Rust/src'
    def rust_string(path): return '"'+str(path).replace('\\','\\\\').replace('"','\\"')+'"'
    imports='#![allow(dead_code,unused_imports)]\nextern crate self as libunicode_rust;\n'
    imports+='#[path = '+rust_string(upstream/'Libraries/LibUnicode/Rust/src/character_types.rs')+'] pub mod character_types;\n'
    for module in ['ast','bytecode']: imports+='#[path = '+rust_string(regex/(module+'.rs'))+'] mod '+module+';\n'
    oracle=imports+hints.RECORDS+'mod oracle_vm {\n'+(regex/'vm.rs').read_text()+WRAPPERS+'\n}\n'+DRIVER
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    with tempfile.TemporaryDirectory(prefix='vox2-regex-state-') as directory:
        source,binary=Path(directory)/'oracle.rs',Path(directory)/'oracle'
        source.write_text(oracle)
        subprocess.run([core.rustc_path(),'--edition=2024','-O',str(source),'-o',str(binary)],check=True)
        result=subprocess.run([str(binary)],input='\n'.join(records)+'\n',capture_output=True,text=True,timeout=120)
        if result.returncode: raise RuntimeError(result.stderr)
    answers=result.stdout.splitlines()
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    args.output.write_text(f'# LibRegex {revision}; native Rust exact VM state/traversal outputs\n'
                          '# operation, flags/storage, input, a, b, c, operations/instructions, result\n'+'\n'.join(answers)+'\n')
    print(f'{len(answers)} exact regex-state fixtures written to {args.output}')


if __name__=='__main__': main()
