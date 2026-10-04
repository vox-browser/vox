#!/usr/bin/env python3
"""Probe the actual UTF8 variant's prefix and raw UTF16 destination.

Reuse the pinned, archive-validated original Source dependency and bridge.
Snapshot exports observe genuine records; implementation bodies stay unchanged.
"""

import os
import pathlib
import subprocess
import sys

import source_utf8_validity_probe as validity

DRIVER = r'''
use encoding_rs::{SourceProbeUtf8Decoder,source_probe_utf8_snapshot,source_probe_utf8_variant,source_probe_utf16_prefix};
use std::panic::{catch_unwind,AssertUnwindSafe};
fn hex(input:&[u8])->String {input.iter().map(|b|format!("{b:02x}")).collect()}
fn slots(state:&SourceProbeUtf8Decoder)->String {
    let s=source_probe_utf8_snapshot(state);
    format!("\"code_point\":{},\"bytes_seen\":{},\"bytes_needed\":{},\"lower_boundary\":{},\"upper_boundary\":{}",s.0,s.1,s.2,s.3,s.4)
}
fn record(input:&[u8],capacity:usize,last:bool,status:&str,read:usize,written:usize,bad:u8,after:u8,errors:bool,output:&[u16],state:&SourceProbeUtf8Decoder)->String {
    format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"status\":\"{status}\",\"read\":{read},\"written\":{written},\"malformed_length\":{bad},\"bytes_after\":{after},\"had_errors\":{errors},\"units\":{:?},{},\"neutral\":{}}}",hex(input),&output[..written],slots(state),state.in_neutral_state())
}
fn sequence(inputs:&[(&[u8],usize,bool)],replacement:bool,panics:&mut usize)->String {
    let mut raw=SourceProbeUtf8Decoder::new_inner();
    let mut outer=encoding_rs::UTF_8.new_decoder_without_bom_handling();
    let mut steps=Vec::new();
    for &(input,capacity,last) in inputs {
        let mut output=vec![0;capacity];
        if replacement {
            if let Ok((status,read,written,errors))=catch_unwind(AssertUnwindSafe(||outer.decode_to_utf16(input,&mut output,last))) {
                let name=match status {encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"};
                steps.push(record(input,capacity,last,name,read,written,0,0,errors,&output,source_probe_utf8_variant(&outer)));
            } else {
                assert!(last&&input.is_empty()&&capacity==0,"unexpected native UTF16 panic");
                *panics+=1;
                steps.push(format!("{{\"panic\":true,\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"units\":{output:?},{}}}",hex(input),slots(source_probe_utf8_variant(&outer))));
            }
        } else {
            let (status,read,written)=raw.decode_to_utf16_raw(input,&mut output,last);
            let (name,bad,after)=match status {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(a,b)=>("malformed",a,b)};
            steps.push(record(input,capacity,last,name,read,written,bad,after,false,&output,&raw));
        }
    }
    format!("{{\"replacement\":{replacement},\"steps\":[{}]}}",steps.join(","))
}
fn main() {
    std::panic::set_hook(Box::new(|_|{}));
    let directory=std::path::PathBuf::from(std::env::var("VOX2_UTF8_UTF16_OUTPUT").unwrap());
    let mut pairs=Vec::new();
    // Observation layout: first/second byte ascending, then capacities1/2;
    // read:u8,written:u8 and capacity little-endian u16 slots. Uncommitted
    // Source SIMD slack is deliberately excluded from this logical record.
    for first in 0..=255 {for second in 0..=255 {for capacity in [1,2] {
        let mut output=vec![0u16;capacity];
        let (read,written)=source_probe_utf16_prefix(&[first,second],&mut output);
        pairs.push(read as u8);pairs.push(written as u8);
        for at in 0..capacity {pairs.extend_from_slice(&if at<written {output[at]} else {0}.to_le_bytes());}
    }}}
    assert_eq!(pairs.len(),655360);
    std::fs::write(directory.join("prefix_pairs.bin"),pairs).unwrap();
    let mut edges=Vec::new();
    for ascii_length in [0,1,3,4,15,16,63,64,65] {
        for suffix in [b"".as_slice(),b"\xc2",b"\xc2\x80",b"\xe0\xa0\x80",b"\xed\xa0\x80",b"\xe1\x80A",b"\xf0\x9f\x98\x80",b"\xf4\x90\x80\x80",b"\0\x80",b"\xe1\x80",b"\xef\xbb\xbfZ",b"\xf1\x80\x80A"] {
            let mut input=vec![b'A';ascii_length];input.extend_from_slice(suffix);
            for extra in [false,true] {
                let mut bytes=input.clone();if extra {bytes.extend_from_slice(b"\0Z");}
                for capacity in [0,1,2,3,4,7,15,16,17,63,64,65,66,80] {
                    let mut output=vec![0;capacity];let (read,written)=source_probe_utf16_prefix(&bytes,&mut output);
                    edges.push(format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"read\":{read},\"written\":{written},\"units\":{:?}}}",hex(&bytes),&output[..written]));
                }
            }
        }
    }
    assert_eq!(edges.len(),3024);
    std::fs::write(directory.join("prefix_edges.json"),format!("[{}]\n",edges.join(","))).unwrap();
    let mut records=Vec::new();let mut panics=0;
    for byte in 0..=255 {
        for capacity in 0..=8 {for last in [false,true] {for replacement in [false,true] {
            records.push(sequence(&[(&[byte],capacity,last)],replacement,&mut panics));
        }}}
    }
    for prefix in [b"\xc2".as_slice(),b"\xe0",b"\xe1",b"\xed",b"\xf0",b"\xf4",b"\xe1\x80",b"\xf0\x9f",b"\xf0\x9f\x98"] {
        for suffix in [b"".as_slice(),b"A",b"\x80A",b"\xa0\x80",b"\x9f\x98\x80",b"\x80\x80\x80",b"\0A"] {
            for capacity in 0..=8 {for last in [false,true] {for replacement in [false,true] {
                records.push(sequence(&[(prefix,32,false),(suffix,capacity,last)],replacement,&mut panics));
            }}}
        }
    }
    for input in [b"A\0\xf0\x9f\x98\x80Z".as_slice(),b"\xe1A",b"\xe1\x80A",b"\xf1\x80\x80A",b"\xed\xa0\x80",b"\xf4\x90\x80\x80",b"\xef\xbb\xbfZ"] {
        for capacity in 0..=15 {for last in [false,true] {for replacement in [false,true] {
            records.push(sequence(&[(input,capacity,last)],replacement,&mut panics));
        }}}
    }
    assert_eq!(records.len(),11932);assert_eq!(panics,9);
    std::fs::write(directory.join("decoder.json"),format!("[{}]\n",records.join(","))).unwrap();
    println!("actual UTF8 UTF16 destination: 65536 pairs at two capacities, {} prefix edges, {} raw/replacement sequences, {panics} native fatal calls PASS",edges.len(),records.len());
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf8-utf16-decoder-probe"])
    validity.main()
    parser = validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    clone = output / "encoding_rs_source_probe"
    exports = {
        "src/utf_8.rs": "\n// Isolated probe only: actual private slot snapshot.\npub fn source_probe_snapshot(decoder: &Utf8Decoder) -> (u32,usize,usize,u8,u8) { (decoder.code_point,decoder.bytes_seen,decoder.bytes_needed,decoder.lower_boundary,decoder.upper_boundary) }\n",
        "src/lib.rs": "\npub use utf_8::Utf8Decoder as SourceProbeUtf8Decoder;\npub fn source_probe_utf8_snapshot(decoder: &SourceProbeUtf8Decoder) -> (u32,usize,usize,u8,u8) { utf_8::source_probe_snapshot(decoder) }\npub fn source_probe_utf8_variant(decoder: &Decoder) -> &SourceProbeUtf8Decoder { match &decoder.variant { VariantDecoder::Utf8(actual) => actual, _ => panic!(\"actual UTF8 variant required\") } }\npub fn source_probe_utf16_prefix(src: &[u8], dst: &mut [u16]) -> (usize,usize) { utf_8::convert_utf8_to_utf16_up_to_invalid(src,dst) }\n",
    }
    for relative, export in exports.items():
        source = clone / relative
        original = source.read_bytes()
        source.write_bytes(original + export.encode())
        assert source.read_bytes().startswith(original)
    (clone / "src/bin/source_utf8_utf16_decoder_probe.rs").write_text(DRIVER)
    environment = os.environ.copy()
    environment["VOX2_UTF8_UTF16_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    debug_artifacts = None
    for profile in [[], ["--release"]]:
        print("actual UTF8 UTF16 destination profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "run", "--offline", "--bin", "source_utf8_utf16_decoder_probe", *profile], cwd=clone, env=environment, check=True)
        artifacts = [(output / name).read_bytes() for name in ["prefix_pairs.bin", "prefix_edges.json", "decoder.json"]]
        if debug_artifacts is None:
            debug_artifacts = artifacts
        else:
            assert artifacts == debug_artifacts, "Source debug/release UTF16 destination artifacts differ"
    print("actual Source UTF16 destination debug/release artifacts match exactly", flush=True)


if __name__ == "__main__":
    main()
