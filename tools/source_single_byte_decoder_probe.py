#!/usr/bin/env python3
"""Probe pinned Source's 27 SingleByte tables, raw and replacement loops.

Include the unmodified LibTextCodec Rust bridge and validated locked encoding_rs
archive. Golden outputs come from actual native calls; the V table asset copies
only the exact dependency data and Source's registered table/name association.
"""

import argparse
import hashlib
import os
import pathlib
import re
import subprocess
import sys

import source_replacement_decoder_probe as shared

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
    use super::*;
    const LABELS: &[&str] = &["IBM866", "ISO-8859-2", "ISO-8859-3", "ISO-8859-4",
        "ISO-8859-5", "ISO-8859-6", "ISO-8859-7", "ISO-8859-8", "ISO-8859-8-I",
        "ISO-8859-10", "ISO-8859-13", "ISO-8859-14", "ISO-8859-15", "ISO-8859-16",
        "KOI8-R", "KOI8-U", "macintosh", "windows-874", "windows-1250", "windows-1251",
        "windows-1252", "windows-1253", "windows-1254", "windows-1255", "windows-1256",
        "windows-1257", "windows-1258", "x-mac-cyrillic"];
    unsafe extern "C" fn collect(ctx: *mut c_void, data: *const u8, len: usize) {
        unsafe { *ctx.cast::<Option<Vec<u8>>>() = Some(std::slice::from_raw_parts(data, len).to_vec()); }
    }
    fn decode(label: &str, input: &[u8], remove_bom: bool, fatal: bool) -> (bool, Option<Vec<u8>>) {
        let mut output = None;
        let ok = unsafe { textcodec_rust_decode_to_utf8(label.as_ptr(), label.len(), input.as_ptr(), input.len(),
            remove_bom, fatal, (&mut output as *mut Option<Vec<u8>>).cast(), collect) };
        (ok, output)
    }
    fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
    #[test]
    fn source_single_byte_bridge_all_bytes_fatal_and_null_ownership() {
        let mut records = Vec::new();
        let input: Vec<u8> = (0..=255).collect();
        for &label in LABELS {
            let (ok, output) = decode(label, &input, false, false);
            assert!(ok);
            let output = output.unwrap();
            assert_eq!(std::str::from_utf8(&output).unwrap().chars().count(), 256);
            let mut undefined = Vec::new();
            for byte in 128..=255 {
                if !decode(label, &[byte], false, true).0 { undefined.push(byte); }
            }
            for remove_bom in [false, true] {
                assert_eq!(decode(label, &input, remove_bom, false), (true, Some(output.clone())));
                assert_eq!(decode(label, &input, remove_bom, true).0, undefined.is_empty());
                assert_eq!(decode(label, &[0, b'A', 0], remove_bom, true), (true, Some(vec![0, b'A', 0])));
                assert_eq!(decode(label, &[], remove_bom, true), (true, Some(vec![])));
            }
            records.push(format!("{{\"label\":\"{label}\",\"utf8_hex\":\"{}\",\"undefined_bytes\":[{}]}}",
                hex(&output), undefined.iter().map(|byte| byte.to_string()).collect::<Vec<_>>().join(",")));
        }
        std::fs::write(std::env::var("VOX2_SINGLE_BYTE_GOLD").unwrap(), format!("[{}]\n", records.join(","))).unwrap();
        println!("28 names / 27 actual tables: all256, per-byte fatal, embedded/trailing NUL and empty PASS");
    }
    #[test]
    fn source_single_byte_raw_and_replacement_capacity_positions() {
        let mut records = Vec::new();
        for &label in LABELS {
            let encoding = Encoding::for_label(label.as_bytes()).unwrap();
            let mut inputs = vec![vec![], b"A".to_vec(), b"A\0\xa5B\xff\0Z".to_vec(),
                b"\x81\0\0A".to_vec(), b"\xffABCD".to_vec()];
            for byte in 128..=255 {
                if !decode(label, &[byte], false, true).0 {
                    inputs.push(vec![byte, 0, byte, b'A']);
                }
            }
            for input in inputs {
                for capacity in 0..=12 {
                    for replacement in [false, true] {
                        let mut decoder = encoding.new_decoder_without_bom_handling();
                        let mut output = vec![0; capacity];
                        let (name, read, written, malformed_length, bytes_after, had_errors) = if replacement {
                            let (status, read, written, errors) = decoder.decode_to_utf8(&input, &mut output, true);
                            let name = match status { CoderResult::InputEmpty => "input_empty", CoderResult::OutputFull => "output_full" };
                            (name, read, written, 0, 0, errors)
                        } else {
                            let (status, read, written) = decoder.decode_to_utf8_without_replacement(&input, &mut output, true);
                            let (name, malformed, after) = match status { DecoderResult::InputEmpty => ("input_empty", 0, 0),
                                DecoderResult::OutputFull => ("output_full", 0, 0), DecoderResult::Malformed(length, after) => ("malformed", length, after) };
                            (name, read, written, malformed, after, false)
                        };
                        records.push(format!("{{\"label\":\"{label}\",\"input_hex\":\"{}\",\"capacity\":{capacity},\"replacement\":{replacement},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"malformed_length\":{malformed_length},\"bytes_after\":{bytes_after},\"had_errors\":{had_errors},\"output_hex\":\"{}\"}}", hex(&input), hex(&output[..written])));
                    }
                }
            }
        }
        let count = records.len();
        std::fs::write(std::env::var("VOX2_SINGLE_BYTE_RAW_GOLD").unwrap(), format!("[{}]\n", records.join(","))).unwrap();
        println!("{count} raw/replacement capacity/status/read/write/error/output cases PASS");
    }
}
'''


def generate_table_asset(dependency, output):
    data = (dependency / "src/data.rs").read_text()
    names = re.findall(r"    pub ([a-z_0-9]+): \[u16; 128\],", data)
    assert len(names) == 27, names
    license_text = data[:data.index("// BEGIN GENERATED CODE")]
    tables = []
    lookup = []
    for name in names:
        body = re.search(r"    " + name + r": \[(.*?)\n    \],", data, re.S).group(1)
        values = re.findall(r"0x[0-9A-Fa-f]+", body)
        assert len(values) == 128, name
        canonical = name.replace("_", "-")
        lookup.append("\t\t'" + canonical + "' { single_byte_" + name + " }")
        tables.append("const single_byte_" + name + " = [u16(" + values[0] + "), " + ", ".join(values[1:]) + "]\n")
    lookup.append("\t\t'iso-8859-8-i' { single_byte_iso_8859_8 }")
    translated = license_text + "// Source encoding_rs 0.8.40 SINGLE_BYTE_DATA (27 actual tables).\nmodule encoding\n\n"
    translated += "\n".join(tables)
    translated += "\n// LibTextCodec Decoder.cpp registered exact names; ISO8859-8-I shares its Hebrew table.\nfn source_single_byte_table(name string) ?[]u16 {\n\treturn match name {\n"
    translated += "\n".join(lookup) + "\n\t\telse { return none }\n\t}\n}\n"
    (output / "single_byte_data.v").write_text(translated)


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-single-byte-decoder-probe"))
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
    os.environ["VOX2_SINGLE_BYTE_GOLD"] = str(output / "all-bytes.json")
    os.environ["VOX2_SINGLE_BYTE_RAW_GOLD"] = str(output / "raw-capacities.json")
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", str(output)])
    shared.__doc__ = __doc__
    shared.TEST = TEST
    shared.main()
    # Archive validation and native tests completed before copying table data.
    generate_table_asset(dependency, output)


if __name__ == "__main__":
    main()
