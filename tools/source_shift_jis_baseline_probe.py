#!/usr/bin/env python3
"""Witness retained Shift_JIS lead bytes through the original pinned Source FFI."""
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
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_shift_jis_original_ffi_retains_lead_until_real_next_item_or_flush() {
 let mut cases=Vec::new();let label=b"shift_jis";
 for remove in [false,true] {for fatal in [false,true] {
  for inputs in [vec![vec![0x82],vec![0xa0]],vec![vec![0x82]],vec![vec![0x82],vec![0x41]],vec![vec![0x82,0xa0]],vec![vec![0x41,0,0x82],vec![0xa0,0,0x42]]] {
   let owner=unsafe{textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};assert!(!owner.is_null());let mut steps=Vec::new();
   for(input,last)in inputs.iter().map(|v|(&v[..],false)).chain(std::iter::once((&[][..],true))) {
    let mut output:Option<Vec<u8>>=None;
    let ok=unsafe{textcodec_rust_streaming_decoder_decode_to_utf8(owner,input.as_ptr(),input.len(),last,fatal,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
    let callback_present=output.is_some();let output=output.unwrap_or_default();assert_eq!(callback_present,!output.is_empty());
    if input==[0x82]&&!last {assert!(ok);assert!(output.is_empty());}
    if input==[0xa0]&&!last {assert!(ok);assert_eq!(output,[0xe3,0x81,0x82]);}
    steps.push(format!("{{\"input_hex\":\"{}\",\"last\":{last},\"ok\":{ok},\"callback_present\":{callback_present},\"utf8_hex\":\"{}\"}}",hex(input),hex(&output)));
   }
   unsafe{textcodec_rust_streaming_decoder_free(owner);}
   cases.push(format!("{{\"remove_bom\":{remove},\"fatal\":{fatal},\"steps\":[{}]}}",steps.join(",")));
  }
 }}
 assert_eq!(cases.len(),20);
 let path=std::env::var("VOX2_SHIFT_JIS_BASELINE_OUTPUT").unwrap();let value=format!("[{}]\n",cases.join(","));
 if let Ok(previous)=std::fs::read_to_string(&path){assert_eq!(previous,value,"native baseline profiles differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Shift_JIS original FFI:20 split-lead/ASCII/NUL/flush sequences; fatal incomplete first item succeeds and retains lead PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-shift-jis-baseline-probe"])
    parser = base.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "baseline.json").unlink(missing_ok=True)
    os.environ["VOX2_SHIFT_JIS_BASELINE_OUTPUT"] = str(output / "baseline.json")
    base.BRIDGE_TEST = TEST
    base.main()


if __name__ == "__main__":
    main()
