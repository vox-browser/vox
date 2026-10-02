#!/usr/bin/env python3
"""Compare regex folding and VM character/backreference helpers with upstream.

The Rust VM and record modules are unchanged. The canonicalization FFI is built
from current LibUnicode/AK bodies, not an older native Ladybird binary.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import itertools
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile

import libjs_regex_core_corpus as core
import libjs_regex_hints_corpus as hints
from libjs_regexp_preparation_corpus import between

WRAPPERS = r'''
pub fn folding(cp: u32) -> String {
    let classes=[BuiltinCharacterClass::Digit,BuiltinCharacterClass::NonDigit,
                 BuiltinCharacterClass::Word,BuiltinCharacterClass::NonWord,
                 BuiltinCharacterClass::Whitespace,BuiltinCharacterClass::NonWhitespace];
    let bits=|flag| classes.iter().map(|&c|crate::bit(match_builtin_class(cp,c,flag)).to_string()).collect::<String>();
    format!("{}|{}|{}|{}|{}|{}",case_fold(cp,false),case_fold(cp,true),crate::bit(is_word_char_unicode(cp,false)),crate::bit(is_word_char_unicode(cp,true)),bits(false),bits(true))
}
pub fn equality(a: u32,b: u32,unicode: bool) -> bool { case_fold_eq(a,b,unicode) }
pub fn matching<I: Input>(operation: &str, mut program: Program, input: I, arg: u32, pos: usize, backward: bool, extra: &str) -> String {
    let mut registers=Vec::new(); let mut name="";
    if operation=="backref" { registers=crate::integers(extra); }
    if operation=="named" {
        let f:Vec<&str>=extra.split('!').collect(); assert_eq!(f.len(),3);
        registers=crate::integers(f[1]); name=f[2];
        if f[0]!="-" { program.named_groups=f[0].split(',').map(|g| { let v:Vec<&str>=g.split(':').collect(); NamedGroupEntry { name:v[0].into(),index:v[1].parse().unwrap() } }).collect(); }
    }
    program.register_count=registers.len() as u32;
    let mut scratch=VmScratch::new(); let mut vm=Vm::new(&program,input,pos,&mut scratch);
    vm.registers.copy_from_slice(&registers); vm.backward=backward;
    let result=match operation {
        "char"=>vm.match_char(arg), "boundary"=>vm.at_word_boundary(),
        "backref"=>vm.match_backref(arg), "named"=>vm.match_backref_named(name),
        _=>panic!("unknown matching operation"),
    }; format!("{}|{}",crate::bit(result),vm.pos)
}
'''

DRIVER = r'''
use std::io::{self,BufRead};
unsafe extern "C" { fn oracle_set_locale(); }
fn integers(text: &str) -> Vec<i32> { if text=="-" {Vec::new()} else {text.split(',').map(|v|v.parse().unwrap()).collect()} }
fn main() {
    unsafe { oracle_set_locale(); }
    for line in io::stdin().lock().lines() {
        let line=line.unwrap(); let f:Vec<&str>=line.split('\t').collect(); assert_eq!(f.len(),7);
        let a:u32=f[3].parse().unwrap(); let b:usize=f[4].parse().unwrap(); let c:u32=f[5].parse().unwrap();
        let result=match f[0] {
            "fold"=>oracle_vm::folding(a),
            "eq"=>bit(oracle_vm::equality(a,b as u32,c!=0)).to_string(),
            operation=> {
                let data=units(f[2]); let flags:u32=f[1].split_once(':').unwrap().1.parse().unwrap();
                if f[1].starts_with("u8:") {
                    assert!(data.iter().all(|&v|v<=255)); let bytes:Vec<u8>=data.into_iter().map(|v|v as u8).collect();
                    oracle_vm::matching(operation,program("-",flags),bytes.as_slice(),a,b,c!=0,f[6])
                } else {oracle_vm::matching(operation,program("-",flags),data.as_slice(),a,b,c!=0,f[6])}
            },
        }; println!("{line}\t{result}");
    }
}
'''


def cpp_source(upstream):
    character=(upstream/'Libraries/LibUnicode/CharacterTypes.cpp').read_text()
    string=(upstream/'Libraries/LibUnicode/String.cpp').read_text()
    canonical=between(character,'u32 canonicalize(u32 code_point, bool unicode_mode)',
                      'Vector<CodePointRange> expand_range_case_insensitive')
    locale=between(string,'struct ResolvedLocale {','ErrorOr<String> String::to_lowercase')
    upper=between(string,'ErrorOr<String> String::to_uppercase','ErrorOr<String> String::to_titlecase')
    return '''#include <AK/String.h>
#include <AK/StringBuilder.h>
#include <LibUnicode/ICU.h>
#include <unicode/bytestream.h>
#include <unicode/casemap.h>
#include <unicode/uchar.h>
#include <unicode/stringoptions.h>
#include <unicode/uloc.h>
namespace AK {
'''+locale+upper+'\n}\nnamespace Unicode {\n'+canonical+'''
}
extern "C" u32 unicode_simple_case_fold(u32 cp, bool unicode) { return Unicode::canonicalize(cp,unicode); }
extern "C" void oracle_set_locale() { UErrorCode status=U_ZERO_ERROR; uloc_setDefault("en_US_POSIX",&status); VERIFY(U_SUCCESS(status)); }
'''


def encoded(data):
    return ''.join(f'{v:04x}' for v in data) or '-'


def cases():
    rng=random.Random(0x963_d46_a8+3)
    for cp in list(range(0x10000))+list(range(0x10400,0x10450))+[0x10000,0x1f600,0x10ffff]+[rng.randrange(0x10000,0x110000) for _ in range(1500)]:
        yield 'fold','-','-',cp,0,0,'-'
    palette=[0,0x41,0x61,0x53,0x73,0x4b,0x6b,0xdf,0xe9,0xc9,0x130,0x131,0x17f,0x212a,0x3a3,0x3c2,0x3c3,0xd800,0xdc00,0x10400,0x10428]
    for a,b,unicode in itertools.product(palette,palette,range(2)):
        yield 'eq','-','-',a,b,unicode,'-'
    for storage,alphabet in [('u16',[0,0x20,0x41,0x61,0xe9,0x17f,0x212a,0xd801,0xdc00]),('u8',[0,0x20,0x41,0x61,0x80,0xe9,0xff])]:
        inputs=[(),*itertools.product(alphabet,repeat=2)]
        inputs += [tuple(rng.choice(alphabet) for _ in range(rng.randrange(9))) for _ in range(90)]
        for data in inputs:
            text=encoded(data)
            for pos,flags,backward in itertools.product(range(len(data)+1),range(4),range(2)):
                yield 'boundary',f'{storage}:{flags}',text,0,pos,backward,'-'
                for cp in [rng.choice(palette),0x41,0x10428]:
                    yield 'char',f'{storage}:{flags}',text,cp,pos,backward,'-'
        pairs=[(0x61,0x41),(0xe9,0xc9),(0x17f,0x73),(0x212a,0x6b),(0x3c2,0x3c3),(0xd801,0xdc00)] if storage=='u16' else [(0x61,0x41),(0xe9,0xc9),(0x80,0xff)]
        captures=[(),(0x61,),(0x61,0xe9),(0xd801,0xdc00),(0xd801,0xdc00,0x212a)] if storage=='u16' else [(),(0x61,),(0x80,0xff)]
        variants=[(a,b) for a,b in pairs]+[(tuple(v),tuple(v)) for v in captures]
        for a,b in variants:
            a=(a,) if isinstance(a,int) else a; b=(b,) if isinstance(b,int) else b
            data=a+b; text=encoded(data); length=len(data)
            for start,end,pos,flags,backward in itertools.product(range(length+1),range(length+1),range(length+1),range(4),range(2)):
                if start>end: continue
                yield 'backref',f'{storage}:{flags}',text,0,pos,backward,f'{start},{end}'
        for _ in range(800):
            data=tuple(rng.choice(alphabet) for _ in range(rng.randrange(9)))
            registers=[]
            for _ in range(rng.randrange(5)):
                start=rng.randrange(len(data)+1);end=rng.randrange(start,len(data)+1)
                registers.extend([start if rng.randrange(3) else -1,end if rng.randrange(3) else -1])
            if registers and rng.randrange(5)==0: registers.pop()
            text=','.join(map(str,registers)) or '-'; flags=rng.randrange(4);pos=rng.randrange(len(data)+1);backward=rng.randrange(2)
            yield 'backref',f'{storage}:{flags}',encoded(data),rng.choice([0,1,2,3,0xffffffff]),pos,backward,text
            groups=rng.choice(['same:0,same:1,β:2','same:2,same:1,same:0','same:4294967295','-'])
            yield 'named',f'{storage}:{flags}',encoded(data),0,pos,backward,f'{groups}!{text}!{rng.choice(["same","Same","β","absent"])}'


def native_outputs(upstream,build,prefix,simdutf,jobs,cpp,wrappers,driver,records,invalid_probe=None):
    with tempfile.TemporaryDirectory(prefix='vox2-regex-matching-') as directory:
        temporary=Path(directory); source=temporary/'oracle.cpp'; source.write_text(cpp)
        compiler=[os.environ.get('CXX','c++'),'-w','-std=c++23','-DLAGOM','-fsanitize=address',
                  '-I'+str(simdutf/'include'),'-I'+str(upstream),'-I'+str(upstream/'Libraries'),
                  '-I'+str(build/'Lagom'),'-I'+str(build/'Lagom/Libraries'),'-I'+str(prefix/'include')]
        if sys.platform!='darwin': compiler += ['-fPIC']
        native=temporary/'oracle-cpp.o'; subprocess.run(compiler+['-c',str(source),'-o',str(native)],capture_output=True,text=True,check=True)
        names=re.findall(r'^    (\w+\.cpp)$',(upstream/'AK/CMakeLists.txt').read_text().split('if (WIN32)')[0],re.M)
        names.remove('FFIHelpers.cpp'); names.append('LexicalPathWindows.cpp' if sys.platform=='win32' else 'LexicalPath.cpp')
        def compile_ak(name):
            output=temporary/(name+'.o')
            subprocess.run(compiler+['-c',str(upstream/'AK'/name),'-o',str(output)],capture_output=True,text=True,check=True)
            return str(output)
        with ThreadPoolExecutor(max_workers=jobs) as pool: objects=list(pool.map(compile_ak,names))
        library=temporary/('libvox2_regex_case_oracle.dylib' if sys.platform=='darwin' else 'libvox2_regex_case_oracle.so')
        link=compiler+['-dynamiclib' if sys.platform=='darwin' else '-shared',str(native)]+objects
        if sys.platform=='darwin': link += ['-Wl,-U,_ak_assertion_handler']
        for dependency in [simdutf,prefix]: link += ['-L'+str(dependency/'lib'),'-Wl,-rpath,'+str(dependency/'lib')]
        link += ['-lsimdutf','-lfmt','-licuuc','-licui18n','-o',str(library)]
        subprocess.run(link,check=True,capture_output=True,text=True)
        def rust_string(path): return '"'+str(path).replace('\\','\\\\').replace('"','\\"')+'"'
        imports='#![allow(dead_code,unused_imports)]\nextern crate self as libunicode_rust;\n'
        imports+='#[path='+rust_string(upstream/'Libraries/LibUnicode/Rust/src/character_types.rs')+'] pub mod character_types;\n'
        for module in ['ast','bytecode']: imports+='#[path='+rust_string(upstream/'Libraries/LibRegex/Rust/src'/(module+'.rs'))+'] mod '+module+';\n'
        rust_source=temporary/'oracle.rs'; binary=temporary/'oracle'
        rust_source.write_text(imports+hints.RECORDS+'mod oracle_vm {\n'+(upstream/'Libraries/LibRegex/Rust/src/vm.rs').read_text()+wrappers+'\n}\n'+driver)
        command=[core.rustc_path(),'--edition=2024','-O',str(rust_source),'-o',str(binary),'-L','native='+str(temporary),'-l','dylib=vox2_regex_case_oracle','-C','link-arg=-Wl,-rpath,'+str(temporary)]
        subprocess.run(command,check=True,capture_output=True,text=True)
        result=subprocess.run([str(binary)],input='\n'.join(records)+'\n',capture_output=True,text=True,timeout=120)
        if result.returncode: raise RuntimeError(result.stderr)
        if invalid_probe is not None:
            invalid=subprocess.run([str(binary)],input=invalid_probe,capture_output=True,text=True)
            assert invalid.returncode!=0 and 'is_unicode(code_point)' in invalid.stderr,invalid.stderr
    return result.stdout.splitlines()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-matching.tsv')
    args=parser.parse_args(); upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    simdutf=args.simdutf_prefix.resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    answers=native_outputs(upstream,build,prefix,simdutf,args.jobs,cpp_source(upstream),WRAPPERS,DRIVER,records,
                           'fold\t-\t-\t1114112\t0\t0\t-\n')
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibRegex/LibUnicode/AK {revision}; native exact matching helpers; locale en_US_POSIX\n'
    header+='# operation, storage:flags, input, a, b, c, extra, result\n'
    folding=[line for line in answers if line.startswith('fold\t')]
    matching=[line for line in answers if not line.startswith('fold\t')]
    folded_path=args.output.with_name(args.output.stem+'-fold'+args.output.suffix)
    for output,values in [(args.output,matching),(folded_path,folding)]:
        output.write_text(header+'\n'.join(values)+'\n')
        print(f'{len(values)} exact regex-matching fixtures written to {output}')


if __name__=='__main__':
    try: main()
    except subprocess.CalledProcessError as error:
        if error.stderr: sys.stderr.write(error.stderr)
        raise
