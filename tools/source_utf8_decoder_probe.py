#!/usr/bin/env python3
"""Probe actual Source Utf8Decoder slots, raw/replacement calls and capacities.

Reuse the validated actual-helper copy/default AArch64 manifest. Append only
snapshot accessors in ignored copied modules; all Source bodies stay intact.
"""

import os
import pathlib
import subprocess
import sys

import source_utf8_validity_probe as validity

DRIVER = r'''
use encoding_rs::{SourceProbeUtf8Decoder, source_probe_utf8_snapshot, source_probe_utf8_variant};
use std::collections::BTreeMap;
use std::panic::{catch_unwind,AssertUnwindSafe};
type Slots = (u32, usize, usize, u8, u8);
fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
fn bound(value: Option<usize>) -> String { value.map(|value| value.to_string()).unwrap_or("none".to_string()) }
fn slots_json(slots: Slots) -> String {
    format!("\"code_point\":{},\"bytes_seen\":{},\"bytes_needed\":{},\"lower_boundary\":{},\"upper_boundary\":{}", slots.0,slots.1,slots.2,slots.3,slots.4)
}
fn record(input: &[u8], capacity: usize, last: bool, status: &str, read: usize, written: usize,
    malformed: u8, after: u8, errors: bool, output: &[u8], state: &SourceProbeUtf8Decoder, bounds: &mut BTreeMap<Slots,String>) -> String {
    capacities(state,bounds);
    format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"status\":\"{status}\",\"read\":{read},\"written\":{written},\"malformed_length\":{malformed},\"bytes_after\":{after},\"had_errors\":{errors},\"output_hex\":\"{}\",{},\"neutral\":{}}}",
        hex(input),hex(&output[..written]),slots_json(source_probe_utf8_snapshot(state)),state.in_neutral_state())
}
fn capacities(state: &SourceProbeUtf8Decoder,bounds: &mut BTreeMap<Slots,String>) {
    let slots = source_probe_utf8_snapshot(state);
    if bounds.contains_key(&slots) {return;}
    let mut capacities = Vec::new();
    for length in [0,1,2,8,usize::MAX / 3 - 4,usize::MAX / 3,usize::MAX - 4,usize::MAX] {
        capacities.push(format!("{{\"byte_length\":\"{length}\",\"max_utf16\":\"{}\",\"max_utf8_without_replacement\":\"{}\",\"max_utf8\":\"{}\"}}",
            bound(state.max_utf16_buffer_length(length)), bound(state.max_utf8_buffer_length_without_replacement(length)), bound(state.max_utf8_buffer_length(length))));
    }
    bounds.insert(slots,format!("{{{},\"capacities\":[{}]}}",slots_json(slots),capacities.join(",")));
}
fn sequence(inputs: &[(&[u8],usize,bool)], replacement: bool, bounds: &mut BTreeMap<Slots,String>, panics: &mut usize) -> String {
    let mut raw = SourceProbeUtf8Decoder::new_inner();
    let mut outer = encoding_rs::UTF_8.new_decoder_without_bom_handling();
    let mut steps = Vec::new();
    for &(input,capacity,last) in inputs {
        let mut output = vec![0;capacity];
        if replacement {
            if let Ok((status,read,written,errors))=catch_unwind(AssertUnwindSafe(||outer.decode_to_utf8(input,&mut output,last))) {
                let name=match status {encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"};
                steps.push(record(input,capacity,last,name,read,written,0,0,errors,&output,source_probe_utf8_variant(&outer),bounds));
            } else {
                assert!(last && input.is_empty() && capacity < 3, "unexpected actual Source panic");
                *panics+=1;
                let state=source_probe_utf8_variant(&outer);
                capacities(state,bounds);
                // No Source return counters exist after a panic. Keep the
                // actual partial destination and actual final slots only.
                steps.push(format!("{{\"panic\":true,\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"output_hex\":\"{}\",{}}}",hex(input),hex(&output),slots_json(source_probe_utf8_snapshot(state))));
            }
        } else {
            let (status,read,written)=raw.decode_to_utf8_raw(input,&mut output,last);
            let (name,malformed,after)=match status {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(length,after)=>("malformed",length,after)};
            steps.push(record(input,capacity,last,name,read,written,malformed,after,false,&output,&raw,bounds));
        }
    }
    format!("{{\"replacement\":{replacement},\"steps\":[{}]}}",steps.join(","))
}
fn main() {
    // The initial failing log retains the exact native panic location. This
    // fixture run catches it without flooding logs or inventing return data.
    std::panic::set_hook(Box::new(|_|{}));
    let mut records = Vec::new();
    let mut bounds = BTreeMap::new();
    let mut panics=0;
    for byte in 0..=255 {
        for capacity in 0..=8 { for last in [false,true] { for replacement in [false,true] {
            records.push(sequence(&[(&[byte],capacity,last)],replacement,&mut bounds,&mut panics));
        } } }
    }
    for prefix in [b"\xc2".as_slice(),b"\xe0",b"\xe1",b"\xed",b"\xf0",b"\xf4",b"\xe1\x80",b"\xf0\x9f",b"\xf0\x9f\x98"] {
        for suffix in [b"".as_slice(),b"A",b"\x80A",b"\xa0\x80",b"\x9f\x98\x80",b"\x80\x80\x80",b"\0A"] {
            for capacity in 0..=8 { for last in [false,true] { for replacement in [false,true] {
                records.push(sequence(&[(prefix,32,false),(suffix,capacity,last)],replacement,&mut bounds,&mut panics));
            } } }
        }
    }
    for input in [b"A\0\xf0\x9f\x98\x80Z".as_slice(),b"\xe1A",b"\xe1\x80A",b"\xf1\x80\x80A",b"\xed\xa0\x80",b"\xf4\x90\x80\x80",b"\xef\xbb\xbfZ"] {
        for capacity in 0..=15 { for last in [false,true] { for replacement in [false,true] {
            records.push(sequence(&[(input,capacity,last)],replacement,&mut bounds,&mut panics));
        } } }
    }
    assert_eq!(records.len(),11932);
    assert_eq!(bounds.len(),60);
    assert_eq!(panics,27);
    println!("actual Source Utf8Decoder {} sequences: slots/raw/replacement/unread/EOF PASS; {} observed states/max checked capacities; {panics} actual fatal short-EOF replacement calls",records.len(),bounds.len());
    let directory=std::env::var("VOX2_UTF8_DECODER_OUTPUT").unwrap();
    std::fs::write(std::path::Path::new(&directory).join("decoder.json"),format!("[{}]\n",records.join(","))).unwrap();
    std::fs::write(std::path::Path::new(&directory).join("capacities.json"),format!("[{}]\n",bounds.values().cloned().collect::<Vec<_>>().join(","))).unwrap();
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf8-decoder-probe"])
    validity.main()
    parser = validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    clone = output / "encoding_rs_source_probe"
    exports = {
        "src/utf_8.rs": "\n// Isolated probe only: actual private slot snapshot.\npub fn source_probe_snapshot(decoder: &Utf8Decoder) -> (u32,usize,usize,u8,u8) { (decoder.code_point,decoder.bytes_seen,decoder.bytes_needed,decoder.lower_boundary,decoder.upper_boundary) }\n",
        "src/lib.rs": "\npub use utf_8::Utf8Decoder as SourceProbeUtf8Decoder;\npub fn source_probe_utf8_snapshot(decoder: &SourceProbeUtf8Decoder) -> (u32,usize,usize,u8,u8) { utf_8::source_probe_snapshot(decoder) }\npub fn source_probe_utf8_variant(decoder: &Decoder) -> &SourceProbeUtf8Decoder { match &decoder.variant { VariantDecoder::Utf8(actual) => actual, _ => panic!(\"actual UTF8 variant required\") } }\n",
    }
    for relative, export in exports.items():
        source = clone / relative
        original = source.read_bytes()
        source.write_bytes(original + export.encode())
        assert source.read_bytes().startswith(original)
    (clone / "src/bin/source_utf8_decoder_probe.rs").write_text(DRIVER)
    environment = os.environ.copy()
    environment["VOX2_UTF8_DECODER_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    debug_artifacts = None
    for profile in [[], ["--release"]]:
        print("actual Utf8Decoder profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "run", "--offline", "--bin", "source_utf8_decoder_probe", *profile], cwd=clone, env=environment, check=True)
        artifacts = [(output / name).read_bytes() for name in ["decoder.json", "capacities.json"]]
        if debug_artifacts is None:
            debug_artifacts = artifacts
        else:
            assert artifacts == debug_artifacts, "Source debug/release decoder artifacts differ"
    print("actual Source decoder debug/release artifacts match exactly", flush=True)


if __name__ == "__main__":
    main()
