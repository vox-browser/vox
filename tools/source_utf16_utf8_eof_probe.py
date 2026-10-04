#!/usr/bin/env python3
"""Witness the pinned Source UTF16 UTF8 trailing-surrogate EOF behavior.

Invoke only the original Rust streaming FFI with genuine owned records. This
isolates the existing Common/Stream mismatch before its real UTF8 owner hookup.
"""

import os
import pathlib
import subprocess
import sys

import source_replacement_decoder_probe as shared

SOURCE_PIN = "963d46a829f3e1b79f44dba9d02afb70654300fa"

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u8,len:usize) {
    unsafe {*ctx.cast::<Option<Vec<u8>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
#[test]
fn source_utf16_retained_high_surrogate_and_odd_byte_form_one_malformed_eof() {
    let mut records=Vec::new();
    for (label,input) in [(b"utf-16le".as_slice(),b"\x00\xd8\0".as_slice()),(b"utf-16be".as_slice(),b"\xd8\0\0".as_slice())] {
        for remove in [false,true] {for fatal in [false,true] {for split in 0..=input.len() {
            let owner=unsafe {textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};
            assert!(!owner.is_null());let mut steps=Vec::new();
            for (bytes,last) in [(&input[..split],false),(&input[split..],true)] {
                let mut output:Option<Vec<u8>>=None;
                let ok=unsafe {textcodec_rust_streaming_decoder_decode_to_utf8(owner,bytes.as_ptr(),bytes.len(),last,fatal,(&mut output as *mut Option<Vec<u8>>).cast(),collect)};
                let units=output.unwrap_or_default();
                if last {assert_eq!(ok,!fatal);assert_eq!(units,if fatal {vec![]} else {vec![0xef,0xbf,0xbd]});}
                else {assert!(ok);assert!(units.is_empty());}
                steps.push(format!("{{\"input_hex\":\"{}\",\"last\":{last},\"ok\":{ok},\"bytes\":{units:?}}}",hex(bytes)));
            }
            unsafe {textcodec_rust_streaming_decoder_free(owner);}
            records.push(format!("{{\"label\":\"{}\",\"remove_bom\":{remove},\"fatal\":{fatal},\"steps\":[{}]}}",std::str::from_utf8(label).unwrap(),steps.join(",")));
        }}}
    }
    assert_eq!(records.len(),32);
    let path=std::env::var("VOX2_UTF16_UTF8_EOF_GOLD").unwrap();let value=format!("[{}]\n",records.join(","));
    if let Ok(previous)=std::fs::read_to_string(&path) {assert_eq!(previous,value,"Source native profile results differ");}
    std::fs::write(path,value).unwrap();
    println!("actual Source UTF16-selected UTF8 FFI: 32 EOF scenarios, 64 calls; high-surrogate plus odd byte -> one replacement, or fatal failure PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf16-utf8-eof-probe"])
    parser = shared.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=pathlib.Path)
    args, _ = parser.parse_known_args()
    head = subprocess.check_output(["git", "-C", str(args.source), "rev-parse", "HEAD"], text=True).strip()
    if head != SOURCE_PIN:
        raise SystemExit("Source HEAD differs from required pin: " + head)
    print("Source HEAD", head, flush=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    artifact = output / "utf16_utf8_eof.json"
    artifact.unlink(missing_ok=True)
    os.environ["VOX2_UTF16_UTF8_EOF_GOLD"] = str(artifact)
    shared.TEST = TEST
    shared.main()


if __name__ == "__main__":
    main()
