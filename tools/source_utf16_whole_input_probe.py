#!/usr/bin/env python3
"""Observe original UTF16 whole-input FFI and actual copied-body growth calls.

The validated copied package retains the original decode method unchanged.
A separately named copy of that exact method adds only local observations.
Its outputs are compared with the genuine original FFI for every input.
"""
import os
import pathlib
import subprocess
import sys

import source_utf16_common_probe as base

EVENT = '''
#[cfg(feature = "alloc")]
pub struct SourceProbeWholeEvent {
 pub input_start:usize, pub output_start:usize, pub capacity:usize,
 pub read:usize, pub written:usize, pub had_errors:bool,
 pub full:bool, pub needed:Option<usize>, pub capacity_after:usize,
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
fn encode(units:&[u16],be:bool)->Vec<u8> {units.iter().flat_map(|u|if be {u.to_be_bytes()}else{u.to_le_bytes()}).collect()}
#[test]
fn source_utf16_whole_original_ffi_and_observed_body_growth() {
 let mut cases=Vec::new();let mut growth=0;let mut malformed=0;
 for be in [false,true] {
  let encoding=if be {encoding_rs::UTF_16BE}else{encoding_rs::UTF_16LE};
  let label=if be {b"utf-16be"}else{b"utf-16le"};
  let mut inputs=vec![vec![],vec![0],vec![0xff],vec![0xfe]];
  for units in [&[0u16][..],&[0x41,0,0x42],&[0xfeff],&[0xfeff,0x41],&[0xfffe,0x41],&[0xfeff,0xfeff,0x41],&[0xd800],&[0xd800,0xdc00],&[0xdc00],&[0xd800,0x41],&[0xd800,0xd800,0xdc00],&[0x41,0xdc00,0x42]] {inputs.push(encode(units,be));}
  for unit in [0,0x7f,0x80,0x7ff,0x800,0xd7ff,0xd800,0xdbff,0xdc00,0xdfff,0xe000,0xffff] {
   for length in [1,2,3,4,7,8,15,16,31,32,63,64,65,127] {
    let mut units=vec![unit;length];units.extend_from_slice(&[0,0x41]);let bytes=encode(&units,be);
    inputs.push(bytes.clone());let mut odd=bytes;odd.push(0);inputs.push(odd);
   }
  }
  for prefix in [vec![],vec![0],encode(&[0xd800],be),encode(&[0xfeff],be)] {
   for suffix in [vec![],vec![0],encode(&[0],be),encode(&[0x41],be),encode(&[0xdc00],be),encode(&[0xfeff],be)] {
    let mut bytes=prefix.clone();bytes.extend_from_slice(&suffix);inputs.push(bytes);
   }
  }
  for input in inputs {for remove in [false,true] {
   let without_bom=if remove&&input.starts_with(if be {b"\xfe\xff"}else{b"\xff\xfe"}){&input[2..]}else{&input[..]};
   let (observed,errors,events)=encoding.source_probe_decode_without_bom_handling(without_bom);
   let mut output:Option<Vec<u8>>=None;
   let ok=unsafe{textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),input.as_ptr(),input.len(),remove,false,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
   assert!(ok);assert_eq!(output.as_deref(),Some(observed.as_bytes()));
   let mut fatal_output:Option<Vec<u8>>=None;
   let fatal_ok=unsafe{textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),input.as_ptr(),input.len(),remove,true,(&mut fatal_output as *mut Option<Vec<u8>>).cast(),collect)};
   assert_eq!(fatal_ok,!errors);if errors {malformed+=1;assert!(fatal_output.is_none());}else{assert_eq!(fatal_output,output);}
   let mut steps=Vec::new();
   for e in events {if e.full {growth+=1;}
    steps.push(format!("{{\"input_start\":{},\"output_start\":{},\"capacity\":{},\"read\":{},\"written\":{},\"had_errors\":{},\"full\":{},\"needed\":{},\"capacity_after\":{}}}",e.input_start,e.output_start,e.capacity,e.read,e.written,e.had_errors,e.full,e.needed.map(|n|n.to_string()).unwrap_or("null".to_string()),e.capacity_after));
   }
   cases.push(format!("{{\"be\":{be},\"remove_bom\":{remove},\"input_hex\":\"{}\",\"utf8_hex\":\"{}\",\"had_errors\":{errors},\"fatal_ok\":{fatal_ok},\"events\":[{}]}}",hex(&input),hex(observed.as_bytes()),steps.join(",")));
  }}
 }
 assert_eq!(cases.len(),1504);assert!(malformed>0);
 let out=std::env::var("VOX2_UTF16_WHOLE_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("whole.json");let value=format!("[{}]\n",cases.join(","));
 if let Ok(previous)=std::fs::read_to_string(&path){assert_eq!(previous,value,"native whole-input profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source UTF16 whole-input:1504 original FFI outputs/errors, {growth} actual OutputFull reserve calls, {malformed} whole-input fatal withholdings PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf16-whole-input-probe"])
    base.main()
    parser = base.base.base.raw.validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    source = output / "encoding_rs_source_probe/src/lib.rs"
    contents = source.read_text()
    start = contents.index("    pub fn decode_without_bom_handling<'a>(")
    end = contents.index("    /// Decode complete input", start)
    original = contents[start:end]
    observed = original.replace("pub fn decode_without_bom_handling", "pub fn source_probe_decode_without_bom_handling", 1)
    observed = observed.replace("-> (Cow<'a, str>, bool) {", "-> (Cow<'a, str>, bool, Vec<SourceProbeWholeEvent>) {\n        let mut probe_events=Vec::new();", 1)
    observed = observed.replace("return (Cow::Borrowed(str), false);", "return (Cow::Borrowed(str), false, probe_events);", 1)
    observed = observed.replace("return (Cow::Owned(string), total_had_errors);", "probe_events.push(SourceProbeWholeEvent { input_start:probe_input, output_start:probe_output, capacity:probe_capacity, read, written:string.len()-probe_output, had_errors, full:false, needed:None, capacity_after:string.capacity() });\n                    return (Cow::Owned(string), total_had_errors, probe_events);", 1)
    observed = observed.replace("        loop {\n            let (result, read, had_errors)", "        loop {\n            let probe_input=total_read; let probe_output=string.len(); let probe_capacity=string.capacity();\n            let (result, read, had_errors)", 1)
    observed = observed.replace("                    string.reserve(needed.unwrap());", "                    let probe_written=string.len()-probe_output;\n                    string.reserve(needed.unwrap());\n                    probe_events.push(SourceProbeWholeEvent { input_start:probe_input, output_start:probe_output, capacity:probe_capacity, read, written:probe_written, had_errors, full:true, needed, capacity_after:string.capacity() });", 1)
    assert "source_probe_decode_without_bom_handling" in observed and observed.count("probe_events.push") == 2
    # Preserve the actual original method. Only this separately named exact
    # body receives local result/capacity observations in the ignored copy.
    source.write_text(contents[:end] + "    #[cfg(feature = \"alloc\")]\n" + observed + contents[end:] + EVENT)
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_UTF16_WHOLE_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    (output / "whole.json").unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual UTF16 whole-input original FFI + body observations", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)


if __name__ == "__main__":
    main()
