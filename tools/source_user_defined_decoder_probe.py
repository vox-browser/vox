#!/usr/bin/env python3
"""Probe pinned Source UserDefinedDecoder and its expanded raw capacity path."""

import argparse
import hashlib
import os
import pathlib
import subprocess
import sys

import source_replacement_decoder_probe as shared

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
    use super::*;
    unsafe extern "C" fn collect(ctx: *mut c_void, data: *const u8, len: usize) {
        unsafe { *ctx.cast::<Option<Vec<u8>>>() = Some(std::slice::from_raw_parts(data, len).to_vec()); }
    }
    fn decode(bytes: &[u8], remove_bom: bool, fatal: bool) -> (bool, Option<Vec<u8>>) {
        let label = b"x-user-defined";
        let mut output = None;
        let ok = unsafe { textcodec_rust_decode_to_utf8(label.as_ptr(), label.len(), bytes.as_ptr(), bytes.len(),
            remove_bom, fatal, (&mut output as *mut Option<Vec<u8>>).cast(), collect) };
        (ok, output)
    }
    fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
    #[test]
    fn source_user_defined_bridge_all_bytes_nulls_fatal_and_bom_flags() {
        let input: Vec<u8> = (0..=255).collect();
        let expected = decode(&input, false, false).1.unwrap();
        let units: Vec<u32> = std::str::from_utf8(&expected).unwrap().chars().map(|point| point as u32).collect();
        assert_eq!(units.len(), 256);
        for byte in 0..=255 { assert_eq!(units[byte], if byte < 128 { byte as u32 } else { byte as u32 + 0xf700 }); }
        for remove_bom in [false, true] {
            for fatal in [false, true] {
                assert_eq!(decode(&input, remove_bom, fatal), (true, Some(expected.clone())));
                assert_eq!(decode(&[0, 0x80, 0, 0xff, 0], remove_bom, fatal),
                    (true, Some(vec![0, 0xef, 0x9e, 0x80, 0, 0xef, 0x9f, 0xbf, 0])));
                assert_eq!(decode(&[], remove_bom, fatal), (true, Some(vec![])));
            }
        }
        std::fs::write(std::env::var("VOX2_USER_DEFINED_GOLD").unwrap(), format!("{{\"utf8_hex\":\"{}\",\"code_units\":[{}]}}\n",
            hex(&expected), units.iter().map(|unit| unit.to_string()).collect::<Vec<_>>().join(","))).unwrap();
        println!("Source UserDefined all256/native units/NUL/fatal/BOM flags PASS");
    }
    #[test]
    fn source_user_defined_raw_capacity_control_order() {
        let mut records = Vec::new();
        for input in [b"".as_slice(), b"A", b"ABC", b"A\0\x80B\xff\0Z", b"\0\0", b"\xffABCD"] {
            for capacity in 0..=18 {
                let mut decoder = encoding_rs::X_USER_DEFINED.new_decoder_without_bom_handling();
                let mut output = vec![0; capacity];
                let (status, read, written) = decoder.decode_to_utf8_without_replacement(input, &mut output, true);
                let name = match status { DecoderResult::InputEmpty => "input_empty", DecoderResult::OutputFull => "output_full", _ => panic!("UserDefined cannot report malformed") };
                records.push(format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"output_hex\":\"{}\"}}", hex(input), hex(&output[..written])));
            }
        }
        std::fs::write(std::env::var("VOX2_USER_DEFINED_RAW_GOLD").unwrap(), format!("[{}]\n", records.join(","))).unwrap();
        println!("114 raw capacity/read/write/output cases include Source3-byte reservation before ASCII PASS");
    }
}
'''


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-user-defined-decoder-probe"))
    known, _ = parser.parse_known_args()
    head = subprocess.check_output(["git", "-C", str(known.source), "rev-parse", "HEAD"], text=True).strip()
    if head != "963d46a829f3e1b79f44dba9d02afb70654300fa":
        raise SystemExit("Source HEAD differs from required pin: " + head)
    print("Source HEAD", head, flush=True)
    dependency = next((pathlib.Path.home() / ".cargo/registry/src").glob("*/encoding_rs-0.8.40"))
    for relative in ["src/x_user_defined.rs", "src/macros.rs", "src/handles.rs"]:
        print(relative, hashlib.sha256((dependency / relative).read_bytes()).hexdigest(), flush=True)
    output = known.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    os.environ["VOX2_USER_DEFINED_GOLD"] = str(output / "all-bytes.json")
    os.environ["VOX2_USER_DEFINED_RAW_GOLD"] = str(output / "raw-capacities.json")
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", str(output)])
    shared.__doc__ = __doc__
    shared.TEST = TEST
    shared.main()


if __name__ == "__main__":
    main()
