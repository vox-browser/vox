#!/usr/bin/env python3
"""Observe original Shift_JIS whole FFI and exact copied-body local capacity events."""
import argparse
import os
import pathlib
import subprocess
import sys

import source_shift_jis_streaming_probe as base
from source_utf16_whole_input_probe import EVENT

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u8,len:usize){unsafe{*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}}
fn hex(bytes:&[u8])->String{bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_shift_jis_whole_original_ffi_and_actual_capacity_borrow_events() {
 let mut inputs=vec![vec![],vec![0],vec![0x41,0,0x82],vec![0x82],vec![0x82,0x41],vec![0x82,0xa0],vec![0x80,0x41],vec![0xa1,0x41],vec![0xa0,0x41],vec![0xfc,0x4b],vec![0xfc,0x4c],vec![0xff,0x41],vec![0x81,0x40,0x41],vec![0x82,0xa0,0x41,0x42],vec![0x82,0xa0,0x82,0xa0],vec![0x82,0x7f],vec![0x82,0xfd],vec![0xfc,0x4b,0xff,0],vec![0xef,0xbb,0xbf,0x41],vec![0xff,0xfe,0x41],vec![0xfe,0xff,0x41]];
 for first in 0..=255u8 {for second in [0,0x41,0x7f,0x80,0xa0,0xfc,0xff]{inputs.push(vec![first,second]);}}
 for length in (0..=65).chain([129,1023]){inputs.push((0..length).map(|i|(i%128)as u8).collect());}
 for prefix in [0,1,3,15,16,17,31,32,63,64,65,127,128,129,1023] {for tail in [vec![0x82,0xa0],vec![0x82],vec![0xfc,0x4c],vec![0x80,0xa1,0],vec![0xff,0],vec![0xef,0xbb,0xbf],vec![0,0x41]] {
  let mut bytes=(0..prefix).map(|i|(i%128)as u8).collect::<Vec<u8>>();bytes.extend_from_slice(&tail);inputs.push(bytes);
 }}
 for length in [1,2,3,4,7,8,15,16,31,32,63,64,65,127] {for prefix in [0,1,16] {for pattern in [vec![0x82,0xa0],vec![0xa1]] {
  let mut bytes=vec![0x41;prefix];for _ in 0..length{bytes.extend_from_slice(&pattern);}inputs.push(bytes);
 }}}
 assert_eq!(inputs.len(),2070);let label=b"shift_jis";let mut cases=Vec::new();let mut growth=0;let mut malformed=0;let mut borrowed=0;
 for input in inputs {for remove in [false,true] {
  // Matching BOM removal is a no-op for this actual non-Unicode Encoding.
  let (observed,errors,events)=encoding_rs::SHIFT_JIS.source_probe_decode_without_bom_handling(&input);
  let borrow=matches!(observed,std::borrow::Cow::Borrowed(_));if borrow{borrowed+=1;}
  let ascii_prefix=encoding_rs::source_probe_whole_ascii_prefix(&input);
  let mut output:Option<Vec<u8>>=None;
  let ok=unsafe{textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),input.as_ptr(),input.len(),remove,false,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
  assert!(ok);assert_eq!(output.as_deref(),Some(observed.as_bytes()));
  let mut fatal_output:Option<Vec<u8>>=None;let fatal_ok=unsafe{textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),input.as_ptr(),input.len(),remove,true,(&mut fatal_output as *mut Option<Vec<u8>>).cast(),collect)};
  assert_eq!(fatal_ok,!errors);if errors{malformed+=1;assert!(fatal_output.is_none());}else{assert_eq!(fatal_output,output);}
  let mut steps=Vec::new();for e in events{if e.full{growth+=1;}
   steps.push(format!("{{\"input_start\":{},\"output_start\":{},\"capacity\":{},\"read\":{},\"written\":{},\"had_errors\":{},\"full\":{},\"needed\":{},\"capacity_after\":{}}}",e.input_start,e.output_start,e.capacity,e.read,e.written,e.had_errors,e.full,e.needed.map(|n|n.to_string()).unwrap_or("null".to_string()),e.capacity_after));
  }
  cases.push(format!("{{\"remove_bom\":{remove},\"input_hex\":\"{}\",\"utf8_hex\":\"{}\",\"ascii_prefix\":{ascii_prefix},\"borrowed\":{borrow},\"had_errors\":{errors},\"fatal_ok\":{fatal_ok},\"events\":[{}]}}",hex(&input),hex(observed.as_bytes()),steps.join(",")));
 }}
 assert_eq!(cases.len(),4140);assert_eq!(growth,0);assert!(malformed>0&&borrowed>0);
 let out=std::env::var("VOX2_SHIFT_JIS_WHOLE_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("whole.json");let value=format!("[{}]\n",cases.join(","));if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"native whole profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Shift_JIS whole:4140 original FFI cases,{borrowed} actual ASCII borrows,{growth} natural reserve calls,{malformed} entire fatal callback withholdings PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-shift-jis-whole-input-probe"])
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
    original = contents[start:end]
    observed = original.replace("pub fn decode_without_bom_handling", "pub fn source_probe_decode_without_bom_handling", 1)
    observed = observed.replace("-> (Cow<'a, str>, bool) {", "-> (Cow<'a, str>, bool, Vec<SourceProbeWholeEvent>) {\n        let mut probe_events=Vec::new();", 1)
    observed = observed.replace("return (Cow::Borrowed(str), false);", "return (Cow::Borrowed(str), false, probe_events);", 1)
    observed = observed.replace("return (Cow::Owned(string), total_had_errors);", "probe_events.push(SourceProbeWholeEvent { input_start:probe_input, output_start:probe_output, capacity:probe_capacity, read, written:string.len()-probe_output, had_errors, full:false, needed:None, capacity_after:string.capacity() });\n                    return (Cow::Owned(string), total_had_errors, probe_events);", 1)
    observed = observed.replace("        loop {\n            let (result, read, had_errors)", "        loop {\n            let probe_input=total_read; let probe_output=string.len(); let probe_capacity=string.capacity();\n            let (result, read, had_errors)", 1)
    observed = observed.replace("                    string.reserve(needed.unwrap());", "                    let probe_written=string.len()-probe_output;\n                    string.reserve(needed.unwrap());\n                    probe_events.push(SourceProbeWholeEvent { input_start:probe_input, output_start:probe_output, capacity:probe_capacity, read, written:probe_written, had_errors, full:true, needed, capacity_after:string.capacity() });", 1)
    assert observed.count("probe_events.push") == 2
    # Keep the genuine original method. A separately named exact copy adds
    # only local observations and is checked against the actual original FFI.
    source.write_text(contents[:end] + '    #[cfg(feature = "alloc")]\n' + observed + contents[end:] + EVENT + '\npub fn source_probe_whole_ascii_prefix(bytes:&[u8])->usize{crate::ascii::ascii_valid_up_to(bytes)}\n')
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_SHIFT_JIS_WHOLE_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    (output / "whole.json").unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual Shift_JIS original whole FFI/local events profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)


if __name__ == "__main__":
    main()
