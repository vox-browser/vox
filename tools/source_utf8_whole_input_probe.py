#!/usr/bin/env python3
"""Probe pinned Source UTF8 whole-input bridge outputs and fatal withholding.

The existing probe validates Source and the locked archive, then compiles the
unmodified actual LibTextCodec Rust bridge. No Source implementation is copied
into the driver and no V result produces a golden.
"""

import os
import pathlib
import sys

import source_utf8_validity_probe as validity

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
    use super::*;
    unsafe extern "C" fn collect(ctx: *mut c_void, data: *const u8, len: usize) {
        unsafe { *ctx.cast::<Option<Vec<u8>>>() = Some(std::slice::from_raw_parts(data, len).to_vec()); }
    }
    fn decode(input: &[u8], fatal: bool) -> (bool, Option<Vec<u8>>) {
        let label = b"utf-8";
        let mut output = None;
        let ok = unsafe { textcodec_rust_decode_to_utf8(label.as_ptr(), label.len(), input.as_ptr(), input.len(),
            false, fatal, (&mut output as *mut Option<Vec<u8>>).cast(), collect) };
        (ok, output)
    }
    fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
    #[test]
    fn source_utf8_whole_valid_prefix_reserve_and_fatal_withholding() {
        let mut inputs = vec![vec![]];
        for byte in 0..=255 {inputs.push(vec![byte]);}
        for prefix in [b"\xc2".as_slice(),b"\xe0",b"\xe1",b"\xed",b"\xf0",b"\xf4",b"\xe1\x80",b"\xf0\x9f",b"\xf0\x9f\x98"] {
            for suffix in [b"".as_slice(),b"A",b"\x80A",b"\xa0\x80",b"\x9f\x98\x80",b"\x80\x80\x80",b"\0A"] {
                let mut input=prefix.to_vec(); input.extend_from_slice(suffix); inputs.push(input);
            }
        }
        for prefix_length in [0,1,2,3,4,7,8,15,16,31,32,63,64,65,127,128] {
            for malformed_length in [1,2,3,4,7,8,15,16,31,32,63,64] {
                for suffix in [b"".as_slice(),b"\0Z",b"\xf0\x9f\x98\x80"] {
                    let mut input=vec![b'A';prefix_length]; input.extend(vec![0xff;malformed_length]); input.extend_from_slice(suffix); inputs.push(input);
                }
            }
        }
        for input in [b"A\0\xf0\x9f\x98\x80\0Z".as_slice(),b"\xe1A",b"\xe1\x80A",b"\xf1\x80\x80A",b"\xed\xa0\x80",b"\xf4\x90\x80\x80",b"\xef\xbb\xbfZ"] {inputs.push(input.to_vec());}
        let mut records=Vec::new();
        for input in inputs {
            let (ok,output)=decode(&input,false); assert!(ok);
            let output=output.unwrap();
            let (cow,errors)=encoding_rs::UTF_8.decode_without_bom_handling(&input);
            assert_eq!(cow.as_bytes(),output);
            let fatal=decode(&input,true);
            assert_eq!(fatal.0,!errors);
            if errors {assert!(fatal.1.is_none());} else {assert_eq!(fatal.1,Some(output.clone()));}
            records.push(format!("{{\"input_hex\":\"{}\",\"utf8_hex\":\"{}\",\"had_errors\":{errors},\"fatal_ok\":{}}}",hex(&input),hex(&output),fatal.0));
        }
        assert_eq!(records.len(),903);
        let path=std::env::var("VOX2_UTF8_WHOLE_OUTPUT").unwrap();
        let artifact=format!("[{}]\n",records.join(","));
        if let Ok(previous)=std::fs::read_to_string(&path) {assert_eq!(previous,artifact,"native debug/release artifacts differ");}
        std::fs::write(path,artifact).unwrap();
        println!("actual Source UTF8 whole bridge:903 valid-prefix/NUL/malformed-tail/growth/fatal-withholding inputs PASS");
    }
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf8-whole-input-probe"])
    parser = validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "whole.json").unlink(missing_ok=True)
    os.environ["VOX2_UTF8_WHOLE_OUTPUT"] = str(output / "whole.json")
    validity.BRIDGE_TEST = TEST
    validity.main()


if __name__ == "__main__":
    main()
