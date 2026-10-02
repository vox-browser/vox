#!/usr/bin/env python3
"""Compare Unicode property and string-property helpers with unchanged upstream.

Builds current LibUnicode/AK C++ bodies with ASan and imports the original Rust
wrappers. No regex parser, compiler, backtracking or VM execution is invoked.
"""
import argparse
from pathlib import Path
import random
import subprocess
import sys

import libjs_regex_class_corpus as classes
import libjs_regex_core_corpus as core
import libjs_regex_matching_corpus as matching
from libjs_regexp_preparation_corpus import between

DRIVER = r'''
use std::io::{self,BufRead};
use character_types as u;
const QUERIES: &[(&str,Option<&str>)] = &[
    ("Lu",None),("Ll",None),("Letter",None),("ASCII",None),("Any",None),("Assigned",None),
    ("Lowercase",None),("gc",Some("Cs")),("Script",Some("Greek")),("scx",Some("Hira")),
    ("Emoji",None),("Full_Composition_Exclusion",None),("unknown",None),("gc",Some("")),
    ("Cn",None),("Uppercase",None),
];
unsafe extern "C" {
    fn oracle_set_locale();
    fn oracle_alias(kind: u32,id: u32,choice: u32) -> *const std::ffi::c_char;
    fn oracle_lowlevel(cp: u32,kind: u32,id: u32,ignore: bool) -> bool;
    fn unicode_get_string_property_data(name: *const u8,len: usize,out: *mut u32,capacity: u32) -> u32;
}
fn meta(name: &str,value: Option<&str>) -> String {
    let resolved=u::resolve_property(name,value).map(|r|format!("{}:{}",r.kind as u8,r.id)).unwrap_or_else(||"-".into());
    format!("{resolved}:{}:{}",bit(u::is_valid_ecma262_property(name,value)),bit(u::is_string_property(name)))
}
fn alias_meta(kind: u32,id: u32,choice: u32) -> String {
    let ptr=unsafe {oracle_alias(kind,id,choice)};
    if ptr.is_null() {return "-".into();}
    let name=unsafe {std::ffi::CStr::from_ptr(ptr)}.to_str().unwrap();
    let variants=[name.to_string(),name.to_ascii_lowercase(),name.to_ascii_uppercase(),name.replace('_',""),name.replace('_',"-"),format!(" {name}"),format!("{name} "),format!("{name}\0")];
    let mut output=Vec::new();
    for variant in variants {
        output.push(meta(&variant,None));
        for key in match kind {0=>vec!["gc","General_Category"],1=>vec![],2=>vec!["sc","Script","scx","Script_Extensions"],_=>panic!("unknown alias kind")} {
            output.push(meta(key,Some(&variant)));
        }
    }
    format!("{}|{}",name.as_bytes().iter().map(|v|format!("{v:02x}")).collect::<String>(),output.join("|"))
}
fn named_bits(cp: u32) -> String {
    let mut result=String::new();
    for &(name,value) in QUERIES {
        let resolved=u::resolve_property(name,value).is_some_and(|r|u::resolved_property_matches(cp,r));
        let n=bit(u::property_matches(cp,name,value)) | (bit(u::property_matches_case_insensitive(cp,name,value))<<1)
             | (bit(u::property_all_case_equivalents_match(cp,name,value))<<2) | (bit(resolved)<<3);
        result.push(char::from_digit(n as u32,16).unwrap());
    }
    format!("{result}|{}{}{}",bit(u::code_point_has_space_separator_general_category(cp)),bit(u::code_point_has_identifier_start_property(cp)),bit(u::code_point_has_identifier_continue_property(cp)))
}
fn main() {
    unsafe {oracle_set_locale();}
    for line in io::stdin().lock().lines() {
        let line=line.unwrap();let f:Vec<&str>=line.split('\t').collect();assert_eq!(f.len(),5);
        let cp:u32=f[1].parse().unwrap();let a:u32=f[2].parse().unwrap();let b:u32=f[3].parse().unwrap();
        let result=match f[0] {
            "alias"=>alias_meta(cp,a,b),
            "bits"=>named_bits(cp),
            "low"=>bit(unsafe {oracle_lowlevel(cp,a,b,f[4]=="1")}).to_string(),
            "strings"=> {
                let data=u::get_string_property_data(f[4]);
                let needed=data.len();
                let capacity=match a {0=>0,1=>1,2=>needed.saturating_sub(1),3=>needed,4=>needed+2,_=>panic!("unknown capacity selector")};
                let mut output=vec![u32::MAX;capacity];
                let written=unsafe {unicode_get_string_property_data(f[4].as_ptr(),f[4].len(),output.as_mut_ptr(),capacity as u32)};
                format!("{written}|{}|{}",output.iter().map(|v|v.to_string()).collect::<Vec<_>>().join(","),data.iter().map(|v|v.to_string()).collect::<Vec<_>>().join(","))
            },
            _=>panic!("unknown property operation"),
        };println!("{line}\t{result}");
    }
}
'''


def cpp_source(upstream):
    character=(upstream/'Libraries/LibUnicode/CharacterTypes.cpp').read_text()
    prelude=character[:character.index('static constexpr BidiClass char_direction_to_bidi_class')]
    ffi=between(character,'enum class ResolvedPropertyKind','extern "C" u32 unicode_simple_case_fold(u32 code_point')
    icu=(upstream/'Libraries/LibUnicode/ICU.cpp').read_text()
    conversion=between(icu,'String icu_string_to_string(icu::UnicodeString const& string)',
                       'Utf16String icu_string_to_utf16_string(icu::UnicodeString const& string)')
    return classes.cpp_source(upstream)+prelude+'\n}\n#include <AK/Utf16View.h>\nnamespace Unicode {\n'+conversion+'\n}\n'+ffi+r'''
extern "C" char const* oracle_alias(u32 kind,u32 id,u32 choice) {
    auto name_choice=static_cast<UPropertyNameChoice>(choice==0?U_LONG_PROPERTY_NAME:choice==1?U_SHORT_PROPERTY_NAME:U_LONG_PROPERTY_NAME+1);
    if (kind==0) {
        if (id==U_CHAR_CATEGORY_COUNT) return nullptr;
        return u_getPropertyValueName(id<U_CHAR_CATEGORY_COUNT?UCHAR_GENERAL_CATEGORY:UCHAR_GENERAL_CATEGORY_MASK,
               id<U_CHAR_CATEGORY_COUNT?id:Unicode::get_icu_mask(Unicode::GeneralCategory{id}),name_choice);
    }
    if (kind==1) {
        if (id==Unicode::PROPERTY_ANY.value()) return choice==0?"Any":nullptr;
        if (id==Unicode::PROPERTY_ASCII.value()) return choice==0?"ASCII":nullptr;
        if (id==Unicode::PROPERTY_ASSIGNED.value()) return choice==0?"Assigned":nullptr;
        return u_getPropertyName(static_cast<UProperty>(id),name_choice);
    }
    if (choice==0) return uscript_getName(static_cast<UScriptCode>(id));
    if (choice==1) return uscript_getShortName(static_cast<UScriptCode>(id));
    return u_getPropertyValueName(UCHAR_SCRIPT,id,name_choice);
}
extern "C" bool oracle_lowlevel(u32 cp,u32 kind,u32 id,bool ignore) {
    auto sensitivity=ignore?CaseSensitivity::CaseInsensitive:CaseSensitivity::CaseSensitive;
    switch(kind) {
    case 0:return Unicode::code_point_has_general_category(cp,Unicode::GeneralCategory{id},sensitivity);
    case 1:return Unicode::code_point_has_property(cp,Unicode::Property{id},sensitivity);
    case 2:return Unicode::code_point_has_script(cp,Unicode::Script{id});
    case 3:return Unicode::code_point_has_script_extension(cp,Unicode::Script{id});
    default:VERIFY_NOT_REACHED();
    }
}
'''


def cases():
    rng=random.Random(0x963_d46_a8+6)
    for kind,count in [(0,39),(1,80),(2,213)]:
        for index in range(count):
            for choice in range(3):yield 'alias',kind,index,choice,'-'
    palette=[0,9,0x20,0x24,0x30,0x41,0x61,0x7f,0x80,0xa0,0xdf,0x130,0x17f,0x378,0x3b1,0x1e9e,
             0x212a,0x30fc,0xd800,0xdc00,0xffff,0x10400,0x1f1e6,0x1f600,0x10ffff,0x110000,0x7fffffff,0x80000000,0xffffffff]
    for cp in list(range(0x10000))+palette+[rng.randrange(0x10000,0x110000) for _ in range(700)]:
        yield 'bits',cp,0,0,'-'
    for cp in palette+[rng.randrange(0x110000) for _ in range(64)]:
        for kind,count in [(0,39),(1,80),(2,214),(3,214)]:
            for index in range(count):
                for flag in range(2 if kind<2 else 1):yield 'low',cp,kind,index,flag
    for name in ['Basic_Emoji','Emoji_Keycap_Sequence','RGI_Emoji','RGI_Emoji_Flag_Sequence',
                 'RGI_Emoji_Tag_Sequence','RGI_Emoji_Modifier_Sequence','RGI_Emoji_ZWJ_Sequence',
                 'Emoji','ASCII','unknown','rgi_emoji']:
        for selector in range(5):yield 'strings',0,selector,0,name


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream',type=Path,default=Path.home()/'code/3rd/ladybird')
    parser.add_argument('--build-dir',type=Path)
    parser.add_argument('--dependency-prefix',type=Path)
    parser.add_argument('--simdutf-prefix',type=Path,default=Path('/opt/homebrew/opt/simdutf'))
    parser.add_argument('--jobs',type=int,default=8)
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'libjs/testdata/regex-properties.tsv')
    args=parser.parse_args();upstream=args.upstream.resolve()
    revision=subprocess.check_output(['git','-C',str(upstream),'rev-parse','HEAD'],text=True).strip()
    assert revision==core.UPSTREAM_COMMIT,(core.UPSTREAM_COMMIT,revision)
    build=(args.build_dir or upstream/'Build/release').resolve()
    prefix=(args.dependency_prefix or build/'vcpkg_installed/arm64-osx-dynamic').resolve()
    records=list(dict.fromkeys('\t'.join(map(str,row)) for row in cases()))
    answers=matching.native_outputs(upstream,build,prefix,args.simdutf_prefix.resolve(),args.jobs,
                                   cpp_source(upstream),'',DRIVER,records)
    assert len(answers)==len(records)
    assert all(answer.startswith(record+'\t') for answer,record in zip(answers,records))
    header=f'# LibUnicode/LibRegex/AK {revision}; native exact property helpers; locale en_US_POSIX\n'
    header+='# operation, code point / alias kind, a, b, extra, result\n'
    for suffix,operations in [('',{'alias','low'}),('-bmp',{'bits'}),('-strings',{'strings'})]:
        values=[line for line in answers if line.split('\t')[0] in operations]
        output=args.output.with_name(args.output.stem+suffix+args.output.suffix)
        output.write_text(header+'\n'.join(values)+'\n')
        print(f'{len(values)} exact Unicode property fixtures written to {output}')


if __name__=='__main__':
    try:main()
    except subprocess.CalledProcessError as error:
        if error.stderr:sys.stderr.write(error.stderr)
        raise
