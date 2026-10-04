#!/usr/bin/env python3
"""Witness Source TextDecoder reset outputs through the actual UTF16 bridge.

The original pinned Rust FFI creates real owned decoder records and emits real
UTF16 callback units. Source C++ reset ordering is mapped separately; this does
not compile its VM/GC class or infer destination capacities from UTF8 output.
"""

import os
import pathlib
import sys

import source_utf8_validity_probe as validity

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
    use super::*;
    unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u16,len:usize) {
        unsafe {*ctx.cast::<Option<Vec<u16>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
    }
    fn create(remove:bool)->*mut TextCodecRustStreamingDecoder {
        let label=b"utf-8";
        let owner=unsafe {textcodec_rust_streaming_decoder_new(label.as_ptr(),label.len(),remove)};
        assert!(!owner.is_null());owner
    }
    fn decode(owner:*mut TextCodecRustStreamingDecoder,input:&[u8],last:bool,fatal:bool)->(bool,Vec<u16>) {
        let mut out=None;
        let ok=unsafe {textcodec_rust_streaming_decoder_decode_to_utf16(owner,input.as_ptr(),input.len(),last,fatal,(&mut out as *mut Option<Vec<u16>>).cast(),collect)};
        (ok,out.unwrap_or_default())
    }
    fn hex(input:&[u8])->String {input.iter().map(|b|format!("{b:02x}")).collect()}
    fn step(owner:*mut TextCodecRustStreamingDecoder,input:&[u8],last:bool,fatal:bool)->String {
        let (ok,units)=decode(owner,input,last,fatal);
        format!("{{\"input_hex\":\"{}\",\"last\":{last},\"ok\":{ok},\"units\":{units:?}}}",hex(input))
    }
    #[test]
    fn source_utf16_real_decoder_reset_bom_and_fatal_output_witnesses() {
        let mut cases=Vec::new();
        for remove in [false,true] {for fatal in [false,true] {
            for partial in [b"\xc2".as_slice(),b"\xe1\x80",b"\xed",b"\xf0\x9f\x98"] {
                let mut owner=create(remove);let mut steps=Vec::new();
                steps.push(step(owner,b"A\0",false,fatal));
                steps.push(step(owner,partial,false,fatal));
                steps.push(step(owner,b"",true,fatal));
                // Source TextDecoder.cpp replaces the owner after its non-stream
                // call, including failed decoding, before exposing the result.
                let fresh=create(remove);
                unsafe {textcodec_rust_streaming_decoder_free(owner);}
                owner=fresh;
                steps.push(step(owner,b"\xef\xbb\xbfB\0\xf0\x9f\x98\x80",true,fatal));
                unsafe {textcodec_rust_streaming_decoder_free(owner);}
                cases.push(format!("{{\"remove_bom\":{remove},\"fatal\":{fatal},\"steps\":[{}]}}",steps.join(",")));
            }
        }}
        for remove in [false,true] {
            let owner=create(remove);
            let failed=decode(owner,b"\xe1\x80",true,true);assert!(!failed.0);
            let retained=decode(owner,b"\xef\xbb\xbfB",false,true);
            assert!(retained.0);assert_eq!(retained.1,vec![0xfeff,0x42]);
            unsafe {textcodec_rust_streaming_decoder_free(owner);}
            let fresh=create(remove);let expected=decode(fresh,b"\xef\xbb\xbfB",true,true);
            assert_eq!(expected.1,if remove {vec![0x42]} else {vec![0xfeff,0x42]});
            unsafe {textcodec_rust_streaming_decoder_free(fresh);}
        }
        assert_eq!(cases.len(),16);
        let path=std::env::var("VOX2_TEXT_DECODER_UTF16_GOLD").unwrap();
        let artifact=format!("[{}]\n",cases.join(","));
        if let Ok(previous)=std::fs::read_to_string(&path) {assert_eq!(previous,artifact,"native profile outputs differ");}
        std::fs::write(path,artifact).unwrap();
        println!("actual UTF16 bridge: 16 real-owner failure/reset/BOM/NUL/astral scenarios and 2 retained-versus-fresh witnesses PASS");
    }
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-text-decoder-utf16-reset-probe"])
    parser=validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output",type=pathlib.Path)
    args,_=parser.parse_known_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    (out / "utf16_reset.json").unlink(missing_ok=True)
    os.environ["VOX2_TEXT_DECODER_UTF16_GOLD"]=str(out / "utf16_reset.json")
    validity.BRIDGE_TEST=TEST
    validity.main()


if __name__ == "__main__":
    main()
