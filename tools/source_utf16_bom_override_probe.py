#!/usr/bin/env python3
"""Witness original Source whole-input UTF8 output for post-sniff UTF16 EOF."""
import os
import pathlib
import subprocess
import sys
import source_replacement_decoder_probe as shared

TEST=r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u8,len:usize) {unsafe {*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}}
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_post_bom_utf16_high_surrogate_and_odd_byte_emit_one_utf8_replacement() {
 let mut records=Vec::new();
 for (label,post_sniff) in [(b"UTF-16LE".as_slice(),b"\0\xd8\x61".as_slice()),(b"UTF-16BE".as_slice(),b"\xd8\0\x61".as_slice())] {
  for remove in [false,true] {for fatal in [false,true] {
   let mut output:Option<Vec<u8>>=None;
   let ok=unsafe {textcodec_rust_decode_to_utf8(label.as_ptr(),label.len(),post_sniff.as_ptr(),post_sniff.len(),remove,fatal,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
   assert_eq!(ok,!fatal);
   assert_eq!(output,if fatal {None}else{Some(vec![0xef,0xbf,0xbd])});
   records.push(format!("{{\"label\":\"{}\",\"input_hex\":\"{}\",\"remove_bom\":{remove},\"fatal\":{fatal},\"ok\":{ok},\"utf8_hex\":\"{}\"}}",std::str::from_utf8(label).unwrap(),hex(post_sniff),hex(&output.unwrap_or_default())));
  }}
 }
 assert_eq!(records.len(),8);let value=format!("[{}]\n",records.join(","));let path=std::env::var("VOX2_UTF16_BOM_UTF8_GOLD").unwrap();
 if let Ok(previous)=std::fs::read_to_string(&path) {assert_eq!(previous,value,"native Source profile artifacts differ");}
 std::fs::write(path,value).unwrap();
 println!("actual original whole-input UTF8 FFI: 8 post-sniff UTF16 EOF cases, one replacement or fatal no-callback PASS");
}
}
'''


def main():
    if not any(arg=="--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output","Build/audit-fixes/source-utf16-bom-override-probe"])
    parser=shared.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source",type=pathlib.Path,default=pathlib.Path.home()/"code/3rd/ladybird")
    parser.add_argument("--output",type=pathlib.Path)
    args,_=parser.parse_known_args()
    head=subprocess.check_output(["git","-C",str(args.source),"rev-parse","HEAD"],text=True).strip()
    if head!="963d46a829f3e1b79f44dba9d02afb70654300fa": raise SystemExit("Source HEAD differs from required pin: "+head)
    print("Source HEAD",head,flush=True)
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    artifact=output/"post_sniff_utf16_utf8.json";artifact.unlink(missing_ok=True)
    os.environ["VOX2_UTF16_BOM_UTF8_GOLD"]=str(artifact)
    shared.TEST=TEST
    shared.main()

if __name__=="__main__": main()
