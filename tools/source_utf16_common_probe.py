#!/usr/bin/env python3
"""Observe Source Common's exact item/empty-EndOfQueue UTF16 UTF8 calls."""
import os
import pathlib
import subprocess
import sys
import source_utf16_utf8_streaming_probe as base

TEST = r''' 
#[cfg(test)]
mod source_replacement_probe {
use super::*;
use encoding_rs::{source_probe_utf16_snapshot,source_probe_utf16_variant,source_probe_utf16_lifecycle};
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
fn state(d:&encoding_rs::Decoder)->String {
    let s=source_probe_utf16_snapshot(source_probe_utf16_variant(d));
    format!("\"life_cycle\":\"{}\",\"lead_surrogate\":{},\"has_lead_byte\":{},\"lead_byte\":{},\"be\":{},\"pending_bmp\":{}",source_probe_utf16_lifecycle(d),s.0,s.1.is_some(),s.1.unwrap_or(0),s.2,s.3)
}
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u8,len:usize) {
    unsafe {*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}

fn encode(units:&[u16],be:bool)->Vec<u8> {units.iter().flat_map(|u|if be {u.to_be_bytes()}else{u.to_le_bytes()}).collect()}
#[test]
fn source_common_utf16_normal_items_then_empty_end_of_queue() {
 let mut cases=Vec::new();let mut failed_partial=0;
 for be in [false,true] {
  let mut inputs=vec![vec![],vec![0],vec![0xff],vec![0xfe]];
  for units in [&[0u16][..],&[0x41,0,0x42],&[0xfeff],&[0xfeff,0x41],&[0xfffe,0x41],&[0xfeff,0xfeff,0x41],&[0xd800],&[0xd800,0xdc00],&[0xdc00],&[0xd800,0x41],&[0xd800,0xd800,0xdc00],&[0x41,0xdc00,0x42]] {inputs.push(encode(units,be));}
  let mut eof=encode(&[0xd800],be);eof.push(0);inputs.push(eof);
  let label=if be {b"utf-16be"}else{b"utf-16le"};
  for input in &inputs {for one in 0..=input.len() {for two in one..=input.len() {for remove in [false,true] {for fatal in [false,true] {
   let owner=unsafe{textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};assert!(!owner.is_null());let mut steps=Vec::new();
   for(bytes,last)in[(&input[..one],false),(&input[one..two],false),(&input[two..],false),(&[][..],true)] {
    let d=unsafe{&(*owner).decoder};let capacity=if fatal {d.max_utf8_buffer_length_without_replacement(bytes.len())}else{d.max_utf8_buffer_length(bytes.len())}.unwrap();
    let mut output:Option<Vec<u8>>=None;
    let ok=unsafe{textcodec_rust_streaming_decoder_decode_to_utf8(owner,bytes.as_ptr(),bytes.len(),last,fatal,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
    let output=output.unwrap_or_default();if !ok&&!output.is_empty(){failed_partial+=1;}
    steps.push(format!("{{\"input_hex\":\"{}\",\"last\":{last},\"ok\":{ok},\"capacity\":{capacity},\"bytes\":{output:?},{}}}",hex(bytes),state(unsafe{&(*owner).decoder})));
   }
   unsafe{textcodec_rust_streaming_decoder_free(owner);}
   cases.push(format!("{{\"be\":{be},\"remove_bom\":{remove},\"fatal\":{fatal},\"steps\":[{}]}}",steps.join(",")));
  }}}}}
 }
 assert_eq!(cases.len(),1728);assert!(failed_partial>0);
 let out=std::env::var("VOX2_UTF16_COMMON_OUTPUT").unwrap();let path=std::path::Path::new(&out).join("common.json");let value=format!("[{}]\n",cases.join(","));
 if let Ok(previous)=std::fs::read_to_string(&path){assert_eq!(previous,value,"native Common profile artifacts differ");}std::fs::write(path,value).unwrap();
 println!("actual Source Common-reachable UTF16 UTF8:1728 sequences,6912 calls,{failed_partial} genuine failed nonempty callbacks PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf16-common-probe"])
    base.main()
    parser = base.base.raw.validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    # Original bridge bodies are included verbatim. This isolated harness uses
    # the same validated default-alloc Source package plus observation exports;
    # test configuration retains Source's normal native test allocator/panic ABI.
    (output / "Cargo.toml").write_text('[package]\nname="source_replacement_decoder_probe"\nversion="0.1.0"\nedition="2024"\n[workspace]\nexclude=["encoding_rs_source_probe"]\n[dependencies]\nencoding_rs={path="encoding_rs_source_probe"}\n')
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_UTF16_COMMON_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for name in ["common.json"]:
        (output / name).unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual Common UTF16 UTF8 + original FFI profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)
    print("actual Source Common UTF16 UTF8 and real FFI debug/release artifacts match exactly", flush=True)


if __name__ == "__main__":
    main()
