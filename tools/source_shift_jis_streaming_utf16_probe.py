#!/usr/bin/env python3
"""Observe original selected Shift_JIS UTF16 outer and genuine owning u16 FFI."""
import argparse
import os
import pathlib
import subprocess
import sys

import source_shift_jis_streaming_probe as base

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
use encoding_rs::source_probe_shift_jis_owner;
use std::panic::{catch_unwind,AssertUnwindSafe};
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u16,len:usize) {
 unsafe {*ctx.cast::<Option<Vec<u16>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
unsafe extern "C" fn collect_utf8(ctx:*mut c_void,data:*const u8,len:usize) {
 unsafe {*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
fn state(d:&encoding_rs::Decoder)->String {
 let (lead,life)=source_probe_shift_jis_owner(d);
 format!("\"has_lead\":{},\"lead\":{},\"life_cycle\":\"{life}\"",lead.is_some(),lead.unwrap_or(0))
}
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_shift_jis_actual_utf16_outer_and_original_owning_ffi() {
 let old_hook=std::panic::take_hook();std::panic::set_hook(Box::new(|_|{}));let mut cases=Vec::new();let mut fatal_calls=0;
 let inputs=[vec![],vec![0],vec![0x41,0,0x82],vec![0x82],vec![0x82,0x41],vec![0x82,0xa0],vec![0x80,0x41],vec![0xa1,0x41],vec![0xa0,0x41],vec![0xfc,0x4b],vec![0xfc,0x4c],vec![0xff,0x41],vec![0x81,0x40,0x41],vec![0x82,0xa0,0x41,0x42],vec![0x82,0xa0,0x82,0xa0],vec![0x82,0x7f],vec![0x82,0xfd],vec![0xfc,0x4b,0xff,0],vec![0xef,0xbb,0xbf,0x41],vec![0xff,0xfe,0x41],vec![0xfe,0xff,0x41]];
 for input in &inputs {for cut in 0..=input.len() {for remove in [false,true] {for mode in 0..4 {for capacity in if mode>=2 {vec![0]}else{vec![0,1,2,3,4]} {
  let encoding=encoding_rs::SHIFT_JIS;let mut d=if remove{encoding.new_decoder_with_bom_removal()}else{encoding.new_decoder_without_bom_handling()};
  let label=b"shift_jis";let owner=if mode>=2{unsafe{textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)}}else{std::ptr::null_mut()};
  if mode>=2{assert!(!owner.is_null());}let mut steps=Vec::new();
  for(bytes,last)in[(&input[..cut],false),(&input[cut..],false),(&[][..],true)] {
   let call=catch_unwind(AssertUnwindSafe(||{
    let input_hex=hex(bytes);
    if mode>=2 {
     let record=unsafe{&(*owner).decoder};let cap=record.max_utf16_buffer_length(bytes.len()).unwrap();
     let mut output:Option<Vec<u16>>=None;let ok=unsafe{textcodec_rust_streaming_decoder_decode_to_utf16(owner,bytes.as_ptr(),bytes.len(),last,mode==3,(&mut output as *mut Option<Vec<u16>>).cast(),collect)};
     let callback_present=output.is_some();let output=output.unwrap_or_default();assert_eq!(callback_present,!output.is_empty());
     format!("{{\"input_hex\":\"{input_hex}\",\"last\":{last},\"capacity\":{cap},\"ok\":{ok},\"callback_present\":{callback_present},\"units\":{output:?},{}}}",state(unsafe{&(*owner).decoder}))
    }else{
     let mut output=vec![0;capacity];
     let (name,read,written,bad,after,errors)=if mode==0 {
      let (status,read,written)=d.decode_to_utf16_without_replacement(bytes,&mut output,last);
      let (name,bad,after)=match status{encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(b,a)=>("malformed",b,a)};(name,read,written,bad,after,false)
     }else{let (status,read,written,errors)=d.decode_to_utf16(bytes,&mut output,last);let name=match status{encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"};(name,read,written,0,0,errors)};
     format!("{{\"input_hex\":\"{input_hex}\",\"last\":{last},\"capacity\":{capacity},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"bad\":{bad},\"after\":{after},\"had_errors\":{errors},\"units\":{:?},{}}}",&output[..written],state(&d))
    }
   }));
   match call{Ok(step)=>steps.push(step),Err(_)=>{fatal_calls+=1;steps.push(format!("{{\"input_hex\":\"{}\",\"last\":{last},\"capacity\":{capacity},\"panic\":true,{}}}",hex(bytes),state(&d)));break;}}
  }
  if !owner.is_null(){unsafe{textcodec_rust_streaming_decoder_free(owner);}}
  cases.push(format!("{{\"remove_bom\":{remove},\"mode\":{mode},\"steps\":[{}]}}",steps.join(",")));
 }}}}}
 std::panic::set_hook(old_hook);
 assert_eq!(fatal_calls,0,"normal bounded sequence has no native panic");

 let mut mixed=Vec::new();
 for input in &inputs {for cut in 0..=input.len() {for remove in [false,true] {for fatal in [false,true] {for first_utf16 in [false,true] {
  let label=b"shift_jis";let owner=unsafe{textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};assert!(!owner.is_null());let mut steps=Vec::new();
  for(index,(bytes,last))in[(&input[..cut],false),(&input[cut..],false),(&[][..],true)].into_iter().enumerate() {
   let utf16=if index%2==0{first_utf16}else{!first_utf16};let input_hex=hex(bytes);let record=unsafe{&(*owner).decoder};
   let cap=if utf16{record.max_utf16_buffer_length(bytes.len())}else if fatal{record.max_utf8_buffer_length_without_replacement(bytes.len())}else{record.max_utf8_buffer_length(bytes.len())}.unwrap();
   let(ok,units,output_bytes,callback_present)=if utf16 {
    let mut output:Option<Vec<u16>>=None;let ok=unsafe{textcodec_rust_streaming_decoder_decode_to_utf16(owner,bytes.as_ptr(),bytes.len(),last,fatal,(&mut output as *mut Option<Vec<u16>>).cast(),collect)};let present=output.is_some();(ok,output.unwrap_or_default(),vec![],present)
   }else {
    let mut output:Option<Vec<u8>>=None;let ok=unsafe{textcodec_rust_streaming_decoder_decode_to_utf8(owner,bytes.as_ptr(),bytes.len(),last,fatal,(&mut output as *mut Option<Vec<u8>>).cast(),collect_utf8)};let present=output.is_some();(ok,vec![],output.unwrap_or_default(),present)
   };
   assert_eq!(callback_present,!units.is_empty()||!output_bytes.is_empty());
   steps.push(format!("{{\"input_hex\":\"{input_hex}\",\"last\":{last},\"utf16\":{utf16},\"capacity\":{cap},\"ok\":{ok},\"callback_present\":{callback_present},\"units\":{units:?},\"bytes\":{output_bytes:?},{}}}",state(unsafe{&(*owner).decoder})));
  }
  unsafe{textcodec_rust_streaming_decoder_free(owner)};
  mixed.push(format!("{{\"remove_bom\":{remove},\"fatal\":{fatal},\"steps\":[{}]}}",steps.join(",")));
 }}}}}
 assert_eq!(mixed.len(),568);let out=std::env::var("VOX2_SHIFT_JIS_UTF16_OWNER_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("mixed_owned.json");let value=format!("[{}]\n",mixed.join(","));if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"native mixed owners differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Shift_JIS mixed UTF8/UTF16 genuine original FFI owners:{} sequences PASS",mixed.len());
 let mut fatal=Vec::new();
 for mode in ["short0","finished_capacity","finished_raw","finished_replace"] {
  let mut d=encoding_rs::SHIFT_JIS.new_decoder_without_bom_handling();let mut output=vec![0;8];
  if mode.starts_with("short") {let(result,read,written)=d.decode_to_utf16_without_replacement(&[0x82],&mut output,false);assert_eq!((result,read,written),(encoding_rs::DecoderResult::InputEmpty,1,0));}
  else {let(result,read,written)=d.decode_to_utf16_without_replacement(&[],&mut output,true);assert_eq!((result,read,written),(encoding_rs::DecoderResult::InputEmpty,0,0));}
  let old_hook=std::panic::take_hook();std::panic::set_hook(Box::new(|_|{}));
  let mut short=vec![0;mode.strip_prefix("short").map(|n|n.parse::<usize>().unwrap()).unwrap_or(8)];
  let failure=catch_unwind(AssertUnwindSafe(|| {match mode {
   "finished_capacity"=>{d.max_utf16_buffer_length(0);},
   "finished_raw"=>{d.decode_to_utf16_without_replacement(&[],&mut short,false);},
   "finished_replace"=>{d.decode_to_utf16(&[],&mut short,false);},
   _=>{d.decode_to_utf16(&[],&mut short,true);},
  }}));std::panic::set_hook(old_hook);
  let failure=failure.expect_err("original Source fatal call returned");
  let message=if let Some(s)=failure.downcast_ref::<String>(){s.clone()}else{failure.downcast_ref::<&str>().unwrap().to_string()};
  if mode.starts_with("short"){assert!(message.contains("index out of bounds"));}else{assert_eq!(message,"Must not use a decoder that has finished.");}
  fatal.push(format!("{{\"mode\":\"{mode}\",\"units\":{short:?},{}}}",state(&d)));
 }
 let out=std::env::var("VOX2_SHIFT_JIS_UTF16_OWNER_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("utf16_fatal.json");let value=format!("[{}]\n",fatal.join(","));
 if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"native fatal profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Shift_JIS direct UTF16 fatal witnesses:{} short-output/finished calls PASS",fatal.len());
 let out=std::env::var("VOX2_SHIFT_JIS_UTF16_OWNER_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("utf16_sequences.json");let value=format!("[{}]\n",cases.join(","));
 if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"native owner profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Shift_JIS UTF16 outer/real FFI:{} sequences,{fatal_calls} natural sequence native fatal calls PASS",cases.len());
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-shift-jis-streaming-utf16-probe"])
    base.main()
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    # Preceding probes enforce Source HEAD/archive/configuration and install
    # read-only actual owner observers. Include the original bridge verbatim.
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_SHIFT_JIS_UTF16_OWNER_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for name in ["utf16_sequences.json", "utf16_fatal.json", "mixed_owned.json"]:
        (output / name).unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual Shift_JIS UTF16 outer/original FFI profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)


if __name__ == "__main__":
    main()
