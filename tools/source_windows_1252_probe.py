#!/usr/bin/env python3
"""Probe the pinned Source Rust bridge's Windows-1252 bytes and raw capacities.

Reuse the existing exact Cargo.lock/archive validation and unmodified Source
bridge inclusion. Emit golden data from those actual decoder calls, not from
the translated V table or codec.
"""

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
    fn decode(label: &[u8], bytes: &[u8], remove_bom: bool, fatal: bool) -> (bool, Option<Vec<u8>>) {
        let mut output = None;
        let ok = unsafe { textcodec_rust_decode_to_utf8(label.as_ptr(), label.len(), bytes.as_ptr(), bytes.len(),
            remove_bom, fatal, (&mut output as *mut Option<Vec<u8>>).cast(), collect) };
        (ok, output)
    }
    fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
    #[test]
    fn source_windows_1252_bridge_all_bytes_nulls_aliases_and_fatal() {
        let all: Vec<u8> = (0..=255).collect();
        let expected = decode(b"windows-1252", &all, false, false).1.unwrap();
        assert_eq!(std::str::from_utf8(&expected).unwrap().chars().count(), 256);
        for label in [b"windows-1252".as_slice(), b"latin1", b"iso-8859-1", b"ascii"] {
            for remove_bom in [false, true] {
                for fatal in [false, true] {
                    assert_eq!(decode(label, &all, remove_bom, fatal), (true, Some(expected.clone())));
                    assert_eq!(decode(label, &[0, 0x80, 0, 0xff, 0], remove_bom, fatal),
                        (true, Some(vec![0, 0xe2, 0x82, 0xac, 0, 0xc3, 0xbf, 0])));
                    assert_eq!(decode(label, &[], remove_bom, fatal), (true, Some(vec![])));
                }
            }
        }
        assert_eq!(decode(b"windows-1252", &[0xef, 0xbb, 0xbf], true, false),
            (true, Some(vec![0xc3, 0xaf, 0xc2, 0xbb, 0xc2, 0xbf])));
        let file = std::env::var("VOX2_WINDOWS_1252_GOLD").unwrap();
        std::fs::write(file, format!("{{\"utf8_hex\":\"{}\",\"code_units\":[{}]}}\n", hex(&expected),
            std::str::from_utf8(&expected).unwrap().chars().map(|point| (point as u32).to_string()).collect::<Vec<_>>().join(","))).unwrap();
        println!("all256, aliases, leading/interior/trailing NUL, empty, fatal and BOM flags: PASS");
    }
    #[test]
    fn source_windows_1252_raw_capacity_and_read_write_positions() {
        let mut records = Vec::new();
        for input in [b"".as_slice(), b"A", b"A\0\x80B\xff\0Z", b"\x81\0\0A", b"\xffABCD"] {
            for capacity in 0..=12 {
                let mut decoder = encoding_rs::WINDOWS_1252.new_decoder_without_bom_handling();
                let mut output = vec![0; capacity];
                let (status, read, written) = decoder.decode_to_utf8_without_replacement(input, &mut output, true);
                let name = match status { DecoderResult::InputEmpty => "input_empty", DecoderResult::OutputFull => "output_full", _ => panic!("unexpected undefined Windows1252 byte") };
                records.push(format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"output_hex\":\"{}\"}}", hex(input), hex(&output[..written])));
            }
        }
        std::fs::write(std::env::var("VOX2_WINDOWS_1252_RAW_GOLD").unwrap(), format!("[{}]\n", records.join(","))).unwrap();
        println!("65 raw capacity/status/read/write/output cases: PASS");
    }
}
'''


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-windows-1252-probe"))
    known, _ = parser.parse_known_args()
    head = subprocess.check_output(["git", "-C", str(known.source), "rev-parse", "HEAD"], text=True).strip()
    if head != "963d46a829f3e1b79f44dba9d02afb70654300fa":
        raise SystemExit("Source HEAD differs from required pin: " + head)
    print("Source HEAD", head, flush=True)
    dependency = next((pathlib.Path.home() / ".cargo/registry/src").glob("*/encoding_rs-0.8.40"))
    for relative in ["src/single_byte.rs", "src/handles.rs", "src/data.rs"]:
        print(relative, hashlib.sha256((dependency / relative).read_bytes()).hexdigest(), flush=True)
    output = known.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    os.environ["VOX2_WINDOWS_1252_GOLD"] = str(output / "all-bytes.json")
    os.environ["VOX2_WINDOWS_1252_RAW_GOLD"] = str(output / "raw-capacities.json")
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", str(output)])
    shared.__doc__ = __doc__
    shared.TEST = TEST
    shared.main()


if __name__ == "__main__":
    main()
