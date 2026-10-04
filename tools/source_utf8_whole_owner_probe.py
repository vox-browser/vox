#!/usr/bin/env python3
"""Observe original UTF8 whole FFI and exact Source whole-owner local events.

The original pinned whole method remains intact. A separately named exact body
adds local capacity/lifecycle observations, checked against original FFI output.
"""
import argparse
import os
import pathlib
import subprocess
import sys

import source_utf8_whole_input_probe as base

EVENT = '''
#[cfg(feature = "alloc")]
pub struct SourceProbeUtf8WholeEvent {
 pub input_start:usize, pub output_start:usize, pub capacity:usize,
 pub read:usize, pub written:usize, pub had_errors:bool,
 pub full:bool, pub needed:Option<usize>, pub capacity_after:usize,
 pub life_before:String, pub life_after:String,
}
'''

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u8,len:usize) {
 unsafe {*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_utf8_whole_original_ffi_and_observed_off_owner() {
 let mut inputs=vec![vec![]];
 for byte in 0..=255 {inputs.push(vec![byte]);}
 for prefix in [b"\xc2".as_slice(),b"\xe0",b"\xe1",b"\xed",b"\xf0",b"\xf4",b"\xe1\x80",b"\xf0\x9f",b"\xf0\x9f\x98"] {
  for suffix in [b"".as_slice(),b"A",b"\x80A",b"\xa0\x80",b"\x9f\x98\x80",b"\x80\x80\x80",b"\0A"] {
   let mut input=prefix.to_vec();input.extend_from_slice(suffix);inputs.push(input);
  }
 }
 for prefix_length in [0,1,2,3,4,7,8,15,16,31,32,63,64,65,127,128] {
  for malformed_length in [1,2,3,4,7,8,15,16,31,32,63,64] {for suffix in [b"".as_slice(),b"\0Z",b"\xf0\x9f\x98\x80"] {
   let mut input=vec![b'A';prefix_length];input.extend(vec![0xff;malformed_length]);input.extend_from_slice(suffix);inputs.push(input);
  }}
 }
 for input in [b"A\0\xf0\x9f\x98\x80\0Z".as_slice(),b"\xe1A",b"\xe1\x80A",b"\xf1\x80\x80A",b"\xed\xa0\x80",b"\xf4\x90\x80\x80",b"\xef\xbb\xbfZ"] {inputs.push(input.to_vec());}
 assert_eq!(inputs.len(),903);
 for valid in [b"\0Z".as_slice(),b"\xc2\xa2",b"\xe2\x82\xac",b"\xf0\x9f\x98\x80",b"A\0\xc2\xa2\xe2\x82\xac\xf0\x9f\x98\x80"] {
  for repeat in [1,2,3,7,8,15,16,31,32] {for tail in [b"\xff".as_slice(),b"\xff\xff\xff",b"\xe1\x80",b"\xf0\x9fA\0"] {
   let mut input=valid.repeat(repeat);input.extend_from_slice(tail);inputs.push(input);
  }}
 }
 inputs.push(b"\xef\xbb\xbf\xef\xbb\xbfZ".to_vec());inputs.push(b"\xef\xbb\xbf\xef\xbb\xbf\xef\xbb\xbfZ".to_vec());
 assert_eq!(inputs.len(),1085);
 let label=b"utf-8";let mut cases=Vec::new();let mut growth=0;let mut malformed=0;let mut borrowed=0;
 for input in inputs {for remove in [false,true] {
  let span=if remove&&input.starts_with(b"\xef\xbb\xbf"){&input[3..]}else{&input[..]};
  let valid_prefix=encoding_rs::source_utf8_validity_probe(span);
  let (observed,errors,events)=encoding_rs::UTF_8.source_probe_decode_without_bom_handling(span);
  let borrow=matches!(observed,std::borrow::Cow::Borrowed(_));if borrow {borrowed+=1;}
  let mut output:Option<Vec<u8>>=None;
  let ok=unsafe{textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),input.as_ptr(),input.len(),remove,false,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
  assert!(ok);assert_eq!(output.as_deref(),Some(observed.as_bytes()));
  let mut fatal_output:Option<Vec<u8>>=None;
  let fatal_ok=unsafe{textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),input.as_ptr(),input.len(),remove,true,(&mut fatal_output as *mut Option<Vec<u8>>).cast(),collect)};
  assert_eq!(fatal_ok,!errors);if errors {malformed+=1;assert!(fatal_output.is_none());}else{assert_eq!(fatal_output,output);}
  let mut steps=Vec::new();for e in events {if e.full {growth+=1;}
   assert_eq!(e.life_before,"Converting");assert_eq!(e.life_after,if e.full {"Converting"}else{"Finished"});
   steps.push(format!("{{\"input_start\":{},\"output_start\":{},\"capacity\":{},\"read\":{},\"written\":{},\"had_errors\":{},\"full\":{},\"needed\":{},\"capacity_after\":{},\"life_before\":\"{}\",\"life_after\":\"{}\"}}",e.input_start,e.output_start,e.capacity,e.read,e.written,e.had_errors,e.full,e.needed.map(|n|n.to_string()).unwrap_or("null".to_string()),e.capacity_after,e.life_before,e.life_after));
  }
  cases.push(format!("{{\"remove_bom\":{remove},\"input_hex\":\"{}\",\"utf8_hex\":\"{}\",\"valid_prefix\":{valid_prefix},\"borrowed\":{borrow},\"had_errors\":{errors},\"fatal_ok\":{fatal_ok},\"events\":[{}]}}",hex(&input),hex(observed.as_bytes()),steps.join(",")));
 }}
 assert_eq!(cases.len(),2170);assert!(borrowed>0&&malformed>0&&growth>0);
 let path=std::path::PathBuf::from(std::env::var("VOX2_UTF8_WHOLE_OWNER_OUTPUT").unwrap()).join("whole_owner.json");let value=format!("[{}]\n",cases.join(","));
 if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"original whole owner profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source UTF8 whole Off owner:2170 original FFI cases,{borrowed} actual UTF8 Cow borrows,{growth} natural reserve calls,{malformed} entire fatal callback withholdings PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf8-whole-owner-probe"])
    base.main()
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    source = output / "encoding_rs_source_probe/src/lib.rs"
    contents = source.read_text()
    start = contents.index("    pub fn decode_without_bom_handling<'a>(")
    end = contents.index("    /// Decode complete input", start)
    observed = contents[start:end].replace("pub fn decode_without_bom_handling", "pub fn source_probe_decode_without_bom_handling", 1)
    observed = observed.replace("-> (Cow<'a, str>, bool) {", "-> (Cow<'a, str>, bool, Vec<SourceProbeUtf8WholeEvent>) {\n        let mut probe_events=Vec::new();", 1)
    observed = observed.replace("return (Cow::Borrowed(str), false);", "return (Cow::Borrowed(str), false, probe_events);", 1)
    observed = observed.replace("return (Cow::Owned(string), total_had_errors);", "probe_events.push(SourceProbeUtf8WholeEvent { input_start:probe_input, output_start:probe_output, capacity:probe_capacity, read, written:string.len()-probe_output, had_errors, full:false, needed:None, capacity_after:string.capacity(), life_before:probe_life, life_after:alloc::format!(\"{:?}\",decoder.life_cycle) });\n                    return (Cow::Owned(string), total_had_errors, probe_events);", 1)
    observed = observed.replace("        loop {\n            let (result, read, had_errors)", "        loop {\n            let probe_input=total_read; let probe_output=string.len(); let probe_capacity=string.capacity(); let probe_life=alloc::format!(\"{:?}\",decoder.life_cycle);\n            let (result, read, had_errors)", 1)
    observed = observed.replace("                    string.reserve(needed.unwrap());", "                    let probe_written=string.len()-probe_output;\n                    string.reserve(needed.unwrap());\n                    probe_events.push(SourceProbeUtf8WholeEvent { input_start:probe_input, output_start:probe_output, capacity:probe_capacity, read, written:probe_written, had_errors, full:true, needed, capacity_after:string.capacity(), life_before:probe_life, life_after:alloc::format!(\"{:?}\",decoder.life_cycle) });", 1)
    assert observed.count("probe_events.push") == 2
    source.write_text(contents[:end] + '    #[cfg(feature = "alloc")]\n' + observed + contents[end:] + EVENT)
    (output / "Cargo.toml").write_text('[package]\nname="source_replacement_decoder_probe"\nversion="0.1.0"\nedition="2024"\n[workspace]\nexclude=["encoding_rs_source_probe"]\n[dependencies]\nencoding_rs={path="encoding_rs_source_probe"}\n')
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_UTF8_WHOLE_OWNER_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    (output / "whole_owner.json").unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual UTF8 whole original FFI/local Off owner profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)


if __name__ == "__main__":
    main()
