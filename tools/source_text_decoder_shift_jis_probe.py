#!/usr/bin/env python3
"""Observe original Shift_JIS u16 FFI with pinned TextDecoder caller schedules."""
import argparse
import os
import pathlib
import subprocess
import sys

import source_shift_jis_streaming_utf16_probe as base

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
use encoding_rs::source_probe_shift_jis_owner;
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u16,len:usize){unsafe{*ctx.cast::<Option<Vec<u16>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}}
fn state(d:&encoding_rs::Decoder)->String {
 let(lead,life)=source_probe_shift_jis_owner(d);
 format!("\"has_lead\":{},\"lead\":{},\"life_cycle\":\"{life}\"",lead.is_some(),lead.unwrap_or(0))
}
#[test]
fn source_shift_jis_original_u16_ffi_with_text_decoder_schedules() {
 let mut cases=Vec::new();let mut calls=0;let mut withheld_partial=0;
 let inputs=[vec![],vec![0],vec![0x41,0,0x82],vec![0x82],vec![0x82,0x41],vec![0x82,0xa0],vec![0x80,0x41],vec![0xa1,0x41],vec![0xa0,0x41],vec![0xfc,0x4b],vec![0xfc,0x4c],vec![0xff,0x41],vec![0x81,0x40,0x41],vec![0x82,0xa0,0x41,0x42],vec![0x82,0xa0,0x82,0xa0],vec![0x82,0x7f],vec![0x82,0xfd],vec![0xfc,0x4b,0xff,0],vec![0xef,0xbb,0xbf,0x41],vec![0xff,0xfe,0x41],vec![0xfe,0xff,0x41]];
 for input in &inputs {for cut in 0..=input.len() {for remove in [false,true] {for fatal in [false,true] {for pattern in 0..3 {
  let label=b"shift_jis";let mut owner=unsafe{textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};assert!(!owner.is_null());let mut steps=Vec::new();
  let empty=&[][..];let z=&[0x5au8][..];
  let schedule=match pattern {0=>vec![(&input[..cut],true),(&input[cut..],true),(empty,false),(z,false)],1=>vec![(&input[..cut],true),(&input[cut..],false),(empty,true),(z,false)],_=>vec![(&input[..],false),(empty,false),(z,false)]};
  for(bytes,stream)in schedule {
   let cap=unsafe{(*owner).decoder.max_utf16_buffer_length(bytes.len()).unwrap()};
   let mut output:Option<Vec<u16>>=None;let ok=unsafe{textcodec_rust_streaming_decoder_decode_to_utf16(owner,bytes.as_ptr(),bytes.len(),!stream,fatal,(&mut output as *mut Option<Vec<u16>>).cast(),collect)};
   let callback_present=output.is_some();let units=output.unwrap_or_default();assert_eq!(callback_present,!units.is_empty());
   let before_reset=state(unsafe{&(*owner).decoder});
   // TextDecoder.cpp:85–96 retains streaming state or replaces the actual
   // decoder after flushing, before exposing either the saved result/error.
   // This is the pinned caller schedule around original FFI, not execution
   // of the C++ public binding/VM or a replacement decoder implementation.
   if !stream {unsafe{textcodec_rust_streaming_decoder_free(owner);owner=textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};assert!(!owner.is_null());}
   let after_reset=state(unsafe{&(*owner).decoder});
   let input_hex=bytes.iter().map(|b|format!("{b:02x}")).collect::<String>();
   steps.push(format!("{{\"input_hex\":\"{input_hex}\",\"stream\":{stream},\"capacity\":{cap},\"ok\":{ok},\"callback_present\":{callback_present},\"units\":{units:?},\"before_reset\":{{{before_reset}}},\"after_reset\":{{{after_reset}}}}}"));
   calls+=1;if !ok && !units.is_empty(){withheld_partial+=1;}
  }
  unsafe{textcodec_rust_streaming_decoder_free(owner)};
  cases.push(format!("{{\"remove_bom\":{remove},\"fatal\":{fatal},\"pattern\":{pattern},\"steps\":[{}]}}",steps.join(",")));
 }}}}}
 assert_eq!(cases.len(),852);assert_eq!(calls,3124);assert!(withheld_partial>0);
 let out=std::env::var("VOX2_SHIFT_JIS_TEXT_DECODER_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("text_decoder.json");let value=format!("[{}]\n",cases.join(","));if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"native caller schedule profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Shift_JIS original u16 FFI with pinned TextDecoder schedules:{} scenarios/{calls} calls/{withheld_partial} failed nonempty callbacks PASS",cases.len());
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-text-decoder-shift-jis-probe"])
    base.main()
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_SHIFT_JIS_TEXT_DECODER_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    (output / "text_decoder.json").unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual Shift_JIS u16 FFI/TextDecoder schedule profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)


if __name__ == "__main__":
    main()
