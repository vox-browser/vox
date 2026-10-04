#!/usr/bin/env python3
"""Probe real UTF8-selected outer UTF16 calls and actual owning Rust FFI.

The selected decoder snapshots come from the validated original dependency.
Owned modes call Source new/decode/free with genuine Box-backed records.
"""

import os
import pathlib
import subprocess
import sys

import source_utf8_utf16_decoder_probe as raw

TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
use super::*;
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
    let s=state(d);if bounds.contains_key(&s)||source_probe_utf8_lifecycle(d)=="Finished" {return;}
    let mut cases=Vec::new();
    for length in [0,1,2,8,usize::MAX/3-4,usize::MAX/3,usize::MAX-4,usize::MAX-2,usize::MAX-1,usize::MAX] {
        cases.push(format!("{{\"byte_length\":\"{length}\",\"max_utf16\":\"{}\"}}",bound(d.max_utf16_buffer_length(length))));
    }
    bounds.insert(s.clone(),format!("{{{s},\"capacities\":[{}]}}",cases.join(",")));
}
unsafe extern "C" fn collect(ctx:*mut c_void,data:*const u16,len:usize) {
    unsafe {*ctx.cast::<Option<Vec<u16>>>()=Some(std::slice::from_raw_parts(data,len).to_vec());}
}
fn selected<'a>(d:&'a encoding_rs::Decoder,owner:*mut TextCodecRustStreamingDecoder)->&'a encoding_rs::Decoder {
    if owner.is_null() {d} else {unsafe {&(*owner).decoder}}
}
fn sequence(chunks:&[(&[u8],bool)],remove:bool,mode:usize,capacity:usize,bounds:&mut BTreeMap<String,String>,panics:&mut usize)->String {
    let mut d=if remove {encoding_rs::UTF_8.new_decoder_with_bom_removal()} else {encoding_rs::UTF_8.new_decoder_without_bom_handling()};
    let owner=if mode>=2 {unsafe {textcodec_rust_streaming_decoder_new(b"utf-8".as_ptr(),5,remove)}} else {std::ptr::null_mut()};
    if mode>=2 {assert!(!owner.is_null());}
    record_bounds(selected(&d,owner),bounds);let mut steps=Vec::new();
    for &(input,last) in chunks {
        let call=catch_unwind(AssertUnwindSafe(|| {
            if mode>=2 {
                let cap=selected(&d,owner).max_utf16_buffer_length(input.len()).unwrap();
                let mut output:Option<Vec<u16>>=None;
                let ok=unsafe {textcodec_rust_streaming_decoder_decode_to_utf16(owner,input.as_ptr(),input.len(),last,mode==3,(&mut output as *mut Option<Vec<u16>>).cast(),collect)};
                // FFI intentionally discards raw counters/status. Observe only
                // its real capacity, bool, callback units and retained slots.
                format!("{{\"input_hex\":\"{}\",\"capacity\":{cap},\"last\":{last},\"ok\":{ok},\"units\":{:?},{}}}",hex(input),output.unwrap_or_default(),state(selected(&d,owner)))
            } else {
                let mut output=vec![0;capacity];
                if mode==0 {
                    let (status,read,written)=d.decode_to_utf16_without_replacement(input,&mut output,last);
                    let (name,bad,after)=match status {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(b,a)=>("malformed",b,a)};
                    format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"malformed_length\":{bad},\"bytes_after\":{after},\"had_errors\":false,\"units\":{:?},{}}}",hex(input),&output[..written],state(&d))
                } else {
                    let (status,read,written,errors)=d.decode_to_utf16(input,&mut output,last);
                    let name=match status {encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"};
                    format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"malformed_length\":0,\"bytes_after\":0,\"had_errors\":{errors},\"units\":{:?},{}}}",hex(input),&output[..written],state(&d))
                }
            }
        }));
        record_bounds(selected(&d,owner),bounds);
        match call {
            Ok(step)=>steps.push(step),
            Err(_)=>{*panics+=1;steps.push(format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"panic\":true,{}}}",hex(input),state(selected(&d,owner))));break;}
        }
    }
    if !owner.is_null() {unsafe {textcodec_rust_streaming_decoder_free(owner);}}
    format!("{{\"remove_bom\":{remove},\"mode\":{mode},\"steps\":[{}]}}",steps.join(","))
}
#[test]
fn source_utf8_outer_utf16_raw_and_real_ffi_output_state() {
    std::panic::set_hook(Box::new(|_|{}));
    let mut sequences=Vec::new();let mut bounds=BTreeMap::new();let mut panics=0;
    for input in [b"".as_slice(),b"A\0Z",b"\xef",b"\xef\xbb",b"\xef\xbb\xbf",b"\xef\xbb\xbfZ",b"\xefA",b"\xef\xbbA",b"\xef\xbb\xbf\xef\xbb\xbfZ",b"\xe1A",b"\xe1\x80A",b"\xf0\x9f\x98\x80\0Z",b"\xf4\x90\x80\x80"] {
        for one in 0..=input.len() {for two in one..=input.len() {for remove in [false,true] {for mode in 0..4 {
            let chunks=[(&input[..one],false),(&input[one..two],false),(&input[two..],true)];
            if mode<2 {for capacity in [0,1,2,3,4,8,32] {sequences.push(sequence(&chunks,remove,mode,capacity,&mut bounds,&mut panics));}}
            else {sequences.push(sequence(&chunks,remove,mode,0,&mut bounds,&mut panics));}
        }}}}
    }
    for remove in [false,true] {for mode in 0..4 {sequences.push(sequence(&[(b"A",true),(b"",false)],remove,mode,32,&mut bounds,&mut panics));}}
    assert_eq!(sequences.len(),5000);assert_eq!(bounds.len(),12);assert_eq!(panics,76);
    println!("actual Source outer UTF16: {} sequences, {} capacity states, {panics} direct native fatal calls; owned modes use real FFI Box records PASS",sequences.len(),bounds.len());
    let out=std::env::var("VOX2_UTF8_UTF16_STREAM_OUTPUT").unwrap();
    let artifacts=[("stream.json",format!("[{}]\n",sequences.join(","))),("capacities.json",format!("[{}]\n",bounds.values().cloned().collect::<Vec<_>>().join(",")))];
    for (name,value) in artifacts {
        let path=std::path::Path::new(&out).join(name);
        if let Ok(previous)=std::fs::read_to_string(&path) {assert_eq!(previous,value,"Source native profile artifacts differ");}
        std::fs::write(path,value).unwrap();
    }
}

#[test]
fn source_utf16_actual_ffi_withholds_failure_but_calls_back_partial_units() {
    let mut cases=Vec::new();
    for remove in [false,true] {for last in [false,true] {
        for input in [b"A\0\xffZ".as_slice(),b"A\xe1A",b"\xef\xbb\xbfA\0\xffZ",b"A\xf4\x90\x80"] {
            let owner=unsafe {textcodec_rust_streaming_decoder_new(b"utf-8".as_ptr(),5,remove)};
            assert!(!owner.is_null());
            let capacity=unsafe {(*owner).decoder.max_utf16_buffer_length(input.len()).unwrap()};
            let mut output:Option<Vec<u16>>=None;
            let ok=unsafe {textcodec_rust_streaming_decoder_decode_to_utf16(owner,input.as_ptr(),input.len(),last,true,(&mut output as *mut Option<Vec<u16>>).cast(),collect)};
            assert!(!ok);let units=output.expect("actual fatal bridge must invoke partial callback");assert!(!units.is_empty());
            cases.push(format!("{{\"remove_bom\":{remove},\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"ok\":{ok},\"units\":{units:?},{}}}",hex(input),state(unsafe {&(*owner).decoder})));
            unsafe {textcodec_rust_streaming_decoder_free(owner);}
        }
    }}
    assert_eq!(cases.len(),16);
    let out=std::env::var("VOX2_UTF8_UTF16_STREAM_OUTPUT").unwrap();
    let path=std::path::Path::new(&out).join("partial_callbacks.json");
    let value=format!("[{}]\n",cases.join(","));
    if let Ok(previous)=std::fs::read_to_string(&path) {assert_eq!(previous,value,"Source native partial callbacks differ");}
    std::fs::write(path,value).unwrap();
    println!("actual original UTF16 FFI: 16 fatal calls invoke nonempty partial callbacks before returning false PASS");
}
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf8-utf16-streaming-probe"])
    raw.main()
    parser = raw.validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    clone = output / "encoding_rs_source_probe"
    source = clone / "src/lib.rs"
    original = source.read_bytes()
    source.write_bytes(original + b'\npub fn source_probe_utf8_lifecycle(decoder: &Decoder) -> String { alloc::format!("{:?}",decoder.life_cycle) }\n')
    assert source.read_bytes().startswith(original)
    # Original bridge bodies are included verbatim. This isolated harness uses
    # the same validated default-alloc Source package plus observation exports;
    # test configuration retains Source's normal native test allocator/panic ABI.
    (output / "Cargo.toml").write_text('[package]\nname="source_replacement_decoder_probe"\nversion="0.1.0"\nedition="2024"\n[workspace]\nexclude=["encoding_rs_source_probe"]\n[dependencies]\nencoding_rs={path="encoding_rs_source_probe"}\n')
    bridge = args.source.resolve() / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["VOX2_UTF8_UTF16_STREAM_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for name in ["stream.json", "capacities.json", "partial_callbacks.json"]:
        (output / name).unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual outer UTF16 + original FFI profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile, "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)
    print("actual Source outer UTF16 and real FFI debug/release artifacts match exactly", flush=True)


if __name__ == "__main__":
    main()
