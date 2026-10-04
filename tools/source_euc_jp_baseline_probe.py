#!/usr/bin/env python3
"""Witness genuine pinned EUC-JP owner pending bytes through original Source FFI."""
import os
import pathlib
import sys

import source_utf8_validity_probe as base

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u8,len:usize) {
 unsafe {*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
unsafe extern "C" fn collect16(ctx:*mut c_void,data:*const u16,len:usize) {
 unsafe {*ctx.cast::<Option<Vec<u16>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_euc_jp_original_ffi_retains_all_real_pending_variants() {
 let mut cases=Vec::new();let label=b"euc-jp";
 for remove in [false,true] {for fatal in [false,true] {for utf16 in [false,true] {
  for inputs in [vec![vec![0xa4],vec![0xa2]],vec![vec![0x8f],vec![0xa2],vec![0xaf]],vec![vec![0x8e],vec![0xa1]],
   vec![vec![0xa4]],vec![vec![0x8f]],vec![vec![0x8f,0xa2]],vec![vec![0x8f],vec![0xa4],vec![0x41]],vec![vec![0xa4],vec![0x41]],
   vec![vec![0xa4,0xa2]],vec![vec![0x41,0,0xa4],vec![0xa2,0,0x42]]] {
   let owner=unsafe{textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};assert!(!owner.is_null());let mut steps=Vec::new();
   for(input,last)in inputs.iter().map(|v|(&v[..],false)).chain(std::iter::once((&[][..],true))) {
    let mut output:Option<Vec<u8>>=None;let mut output16:Option<Vec<u16>>=None;
    let ok=if utf16 {unsafe{textcodec_rust_streaming_decoder_decode_to_utf16(owner,input.as_ptr(),input.len(),last,fatal,(&mut output16 as *mut Option<Vec<u16>>).cast(),collect16)}}
     else {unsafe{textcodec_rust_streaming_decoder_decode_to_utf8(owner,input.as_ptr(),input.len(),last,fatal,(&mut output as *mut Option<Vec<u8>>).cast(),collect)}};
    let callback_present=if utf16 {output16.is_some()}else{output.is_some()};
    let bytes=output.unwrap_or_default();let units=output16.unwrap_or_default();assert_eq!(callback_present,if utf16 {!units.is_empty()}else{!bytes.is_empty()});
    if input==[0xa4]&&!last {assert!(ok);assert!(!callback_present);}
    if inputs[0]==[0xa4]&&input==[0xa2]&&!last {assert!(ok);if utf16 {assert_eq!(units,[0x3042]);}else{assert_eq!(bytes,[0xe3,0x81,0x82]);}}
    steps.push(format!("{{\"input_hex\":\"{}\",\"last\":{last},\"ok\":{ok},\"callback_present\":{callback_present},\"utf8_hex\":\"{}\",\"utf16\":{units:?}}}",hex(input),hex(&bytes)));
   }
   unsafe{textcodec_rust_streaming_decoder_free(owner);}
   cases.push(format!("{{\"remove_bom\":{remove},\"fatal\":{fatal},\"utf16\":{utf16},\"steps\":[{}]}}",steps.join(",")));
  }
 }}}
 assert_eq!(cases.len(),80);
 let path=std::env::var("VOX2_EUC_JP_BASELINE_OUTPUT").unwrap();let value=format!("[{}]\n",cases.join(","));
 if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"original EUC-JP baseline profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source EUC-JP original FFI:80 UTF8/UTF16 retained JIS0208/JIS0212-shift/JIS0212-lead/half-width/ASCII/NUL/EOF owner sequences PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-euc-jp-baseline-probe"])
    parser = base.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "baseline.json").unlink(missing_ok=True)
    os.environ["VOX2_EUC_JP_BASELINE_OUTPUT"] = str(output / "baseline.json")
    base.BRIDGE_TEST = TEST
    base.main()


if __name__ == "__main__":
    main()
