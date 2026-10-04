#!/usr/bin/env python3
"""Probe actual Source UTF8-selected outer Decoder Off/Remove ownership.

Validated Source bodies remain intact. The ignored copied package receives only
native field observation exports; every call uses the actual outer Decoder.
"""

import os
import pathlib
import subprocess
import sys

import source_utf8_decoder_probe as raw

DRIVER = r'''
use encoding_rs::{source_probe_utf8_snapshot,source_probe_utf8_variant,source_probe_utf8_lifecycle};
use std::collections::BTreeMap;
use std::panic::{catch_unwind,AssertUnwindSafe};
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
fn bound(v:Option<usize>)->String {v.map(|n|n.to_string()).unwrap_or("none".to_string())}
fn state(d:&encoding_rs::Decoder)->String {
    let s=source_probe_utf8_snapshot(source_probe_utf8_variant(d));
    format!("\"life_cycle\":\"{}\",\"code_point\":{},\"bytes_seen\":{},\"bytes_needed\":{},\"lower_boundary\":{},\"upper_boundary\":{}",source_probe_utf8_lifecycle(d),s.0,s.1,s.2,s.3,s.4)
}
fn record_bounds(d:&encoding_rs::Decoder,bounds:&mut BTreeMap<String,String>) {
    let s=state(d); if bounds.contains_key(&s)||source_probe_utf8_lifecycle(d)=="Finished" {return;}
    let mut cases=Vec::new();
    for length in [0,1,2,8,usize::MAX/3-4,usize::MAX/3,usize::MAX-4,usize::MAX] {
        cases.push(format!("{{\"byte_length\":\"{length}\",\"with_replacement\":\"{}\",\"without_replacement\":\"{}\"}}",bound(d.max_utf8_buffer_length(length)),bound(d.max_utf8_buffer_length_without_replacement(length))));
    }
    bounds.insert(s.clone(),format!("{{{s},\"capacities\":[{}]}}",cases.join(",")));
}
fn sequence(chunks:&[(&[u8],bool)],remove:bool,mode:usize,capacity:usize,bounds:&mut BTreeMap<String,String>,panics:&mut usize)->String {
    let mut d=if remove {encoding_rs::UTF_8.new_decoder_with_bom_removal()} else {encoding_rs::UTF_8.new_decoder_without_bom_handling()};
    record_bounds(&d,bounds); let mut steps=Vec::new();
    for &(input,last) in chunks {
        let call=catch_unwind(AssertUnwindSafe(|| {
            if mode>=2 {
                let cap=if mode==3 {d.max_utf8_buffer_length_without_replacement(input.len())} else {d.max_utf8_buffer_length(input.len())}.unwrap();
                let mut output=String::with_capacity(cap);
                if mode==3 {
                    let (status,read)=d.decode_to_string_without_replacement(input,&mut output,last);
                    let (name,bad,after)=match status {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(b,a)=>("malformed",b,a)};
                    (cap,name,read,output.len(),bad,after,false,output.as_bytes().to_vec())
                } else {
                    let (status,read,errors)=d.decode_to_string(input,&mut output,last);
                    let name=match status {encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"};
                    (cap,name,read,output.len(),0,0,errors,output.as_bytes().to_vec())
                }
            } else {
                let mut output=vec![0;capacity];
                if mode==0 {
                    let (status,read,written)=d.decode_to_utf8_without_replacement(input,&mut output,last);
                    let (name,bad,after)=match status {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(b,a)=>("malformed",b,a)};
                    output.truncate(written);(capacity,name,read,written,bad,after,false,output)
                } else {
                    let (status,read,written,errors)=d.decode_to_utf8(input,&mut output,last);
                    let name=match status {encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"};
                    output.truncate(written);(capacity,name,read,written,0,0,errors,output)
                }
            }
        }));
        record_bounds(&d,bounds);
        match call {
            Ok((cap,status,read,written,bad,after,errors,output))=>steps.push(format!("{{\"input_hex\":\"{}\",\"capacity\":{cap},\"last\":{last},\"status\":\"{status}\",\"read\":{read},\"written\":{written},\"malformed_length\":{bad},\"bytes_after\":{after},\"had_errors\":{errors},\"output_hex\":\"{}\",{}}}",hex(input),hex(&output),state(&d))),
            Err(_)=>{*panics+=1;steps.push(format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"panic\":true,{}}}",hex(input),state(&d)));break;}
        }
    }
    format!("{{\"remove_bom\":{remove},\"mode\":{mode},\"steps\":[{}]}}",steps.join(","))
}
fn main() {
    std::panic::set_hook(Box::new(|_|{}));
    let mut sequences=Vec::new();let mut bounds=BTreeMap::new();let mut panics=0;
    for input in [b"".as_slice(),b"A\0Z",b"\xef",b"\xef\xbb",b"\xef\xbb\xbf",b"\xef\xbb\xbfZ",b"\xefA",b"\xef\xbbA",b"\xef\xbb\xbf\xef\xbb\xbfZ",b"\xe1A",b"\xe1\x80A",b"\xf0\x9f\x98\x80\0Z",b"\xf4\x90\x80\x80"] {
        for one in 0..=input.len() {for two in one..=input.len() {for remove in [false,true] {for mode in 0..4 {
            let chunks=[(&input[..one],false),(&input[one..two],false),(&input[two..],true)];
            if mode<2 {for capacity in [0,1,2,3,4,8,32] {sequences.push(sequence(&chunks,remove,mode,capacity,&mut bounds,&mut panics));}}
            else {sequences.push(sequence(&chunks,remove,mode,0,&mut bounds,&mut panics));}
        }}}}
    }
    // Actual outer lifecycle prohibits a subsequent use after converting EOF.
    for remove in [false,true] {for mode in 0..4 {sequences.push(sequence(&[(b"A",true),(b"",false)],remove,mode,32,&mut bounds,&mut panics));}}
    assert_eq!(sequences.len(),5000);assert_eq!(bounds.len(),12);assert_eq!(panics,144);
    println!("actual Source outer UTF8: {} sequences,{} observed max-capacity states,{panics} genuine fatal calls PASS",sequences.len(),bounds.len());
    let out=std::env::var("VOX2_UTF8_STREAM_OUTPUT").unwrap();
    std::fs::write(std::path::Path::new(&out).join("stream.json"),format!("[{}]\n",sequences.join(","))).unwrap();
    std::fs::write(std::path::Path::new(&out).join("capacities.json"),format!("[{}]\n",bounds.values().cloned().collect::<Vec<_>>().join(","))).unwrap();
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf8-streaming-probe"])
    raw.main()
    parser = raw.validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    clone = output / "encoding_rs_source_probe"
    source = clone / "src/lib.rs"
    original = source.read_bytes()
    source.write_bytes(original+b'\npub fn source_probe_utf8_lifecycle(decoder: &Decoder) -> String { alloc::format!("{:?}",decoder.life_cycle) }\n')
    assert source.read_bytes().startswith(original)
    (clone / "src/bin/source_utf8_stream_probe.rs").write_text(DRIVER)
    env = os.environ.copy()
    env["VOX2_UTF8_STREAM_OUTPUT"] = str(output)
    env["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + env.get("PATH", "")
    debug = None
    for profile in [[], ["--release"]]:
        print("actual outer UTF8 profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "run", "--offline", "--bin", "source_utf8_stream_probe", *profile], cwd=clone, env=env, check=True)
        assets=[(output / name).read_bytes() for name in ["stream.json","capacities.json"]]
        if debug is None: debug=assets
        else: assert assets == debug, "Source outer decoder debug/release differ"
    print("actual Source outer UTF8 artifacts match exactly", flush=True)


if __name__ == "__main__":
    main()
