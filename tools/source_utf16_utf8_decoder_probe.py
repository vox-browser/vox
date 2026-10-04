#!/usr/bin/env python3
"""Probe pinned actual UTF16 variant slots and its raw UTF8 destination.

The validated dependency copy receives snapshot exports only. Original decoder
and destination bodies are unchanged; normal Source AArch64 alloc configuration
is inherited from the existing archive-validated helper harness.
"""
import os
import pathlib
import subprocess
import sys
import source_utf16_decoder_probe as raw

DRIVER = r'''
use encoding_rs::{SourceProbeUtf16Decoder,source_probe_utf16_new,source_probe_utf16_snapshot,source_probe_utf16_variant};
fn hex(bytes:&[u8])->String {bytes.iter().map(|b|format!("{b:02x}")).collect()}
fn encode(units:&[u16],be:bool)->Vec<u8> {units.iter().flat_map(|u|if be {u.to_be_bytes()} else {u.to_le_bytes()}).collect()}
fn slots(d:&SourceProbeUtf16Decoder)->String {let(s,b,be,p)=source_probe_utf16_snapshot(d);format!("\"lead_surrogate\":{s},\"has_lead_byte\":{},\"lead_byte\":{},\"be\":{be},\"pending_bmp\":{p}",b.is_some(),b.unwrap_or(0))}
fn raw_record(input:&[u8],capacity:usize,last:bool,replacement:bool,raw:&mut SourceProbeUtf16Decoder,outer:&mut encoding_rs::Decoder)->String {
 let mut output=vec![0;capacity];
 let (status,read,written,bad,after,errors)=if replacement {
  let(s,r,w,e)=outer.decode_to_utf8(input,&mut output,last);
  (match s {encoding_rs::CoderResult::InputEmpty=>"input_empty",encoding_rs::CoderResult::OutputFull=>"output_full"},r,w,0,0,e)
 } else {
  let(s,r,w)=raw.decode_to_utf8_raw(input,&mut output,last);
  let(n,a,b)=match s {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(a,b)=>("malformed",a,b)};
  (n,r,w,a,b,false)
 };
 let state=if replacement {source_probe_utf16_variant(outer)}else{raw};
 format!("{{\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"status\":\"{status}\",\"read\":{read},\"written\":{written},\"malformed_length\":{bad},\"bytes_after\":{after},\"had_errors\":{errors},\"bytes\":{:?},{}}}",hex(input),&output[..written],slots(state))
}
fn sequence(inputs:&[(&[u8],usize,bool)],be:bool,replacement:bool)->String {
 let mut raw=source_probe_utf16_new(be);
 let mut outer=if be {encoding_rs::UTF_16BE}else{encoding_rs::UTF_16LE}.new_decoder_without_bom_handling();
 let steps=inputs.iter().map(|&(i,c,l)|raw_record(i,c,l,replacement,&mut raw,&mut outer)).collect::<Vec<_>>();
 format!("{{\"be\":{be},\"replacement\":{replacement},\"steps\":[{}]}}",steps.join(","))
}
fn mixed_record(d:&mut SourceProbeUtf16Decoder,input:&[u8],capacity:usize,last:bool,utf16:bool)->String {
 let mut bytes=vec![0u8;capacity];let mut units=vec![0u16;capacity];
 let(s,read,written)=if utf16 {d.decode_to_utf16_raw(input,&mut units,last)}else{d.decode_to_utf8_raw(input,&mut bytes,last)};
 let(status,bad,after)=match s {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(a,b)=>("malformed",a,b)};
 let produced_bytes=if utf16 {&[][..]}else{&bytes[..written]};let produced_units=if utf16 {&units[..written]}else{&[][..]};
 format!("{{\"utf16\":{utf16},\"input_hex\":\"{}\",\"capacity\":{capacity},\"last\":{last},\"status\":\"{status}\",\"read\":{read},\"written\":{written},\"malformed_length\":{bad},\"bytes_after\":{after},\"bytes\":{produced_bytes:?},\"units\":{produced_units:?},{}}}",hex(input),slots(d))
}
fn maybe(v:Option<usize>)->String {v.map_or("null".into(),|n|n.to_string())}
fn main() {
 let output=std::path::PathBuf::from(std::env::var("VOX2_UTF16_UTF8_OUTPUT").unwrap());
 let mut pairs=Vec::new();
 // be false/true, each unit ascending, capacity3/4. Each 13-byte record:
 // status/read/written/bad/after, lead_surrogateLE16, byte-present/value,
 // pending_bmp, three committed UTF8 bytes (zero for uncommitted slots).
 for be in [false,true] {for unit in 0..=u16::MAX {for capacity in [3,4] {
  let mut state=source_probe_utf16_new(be);let mut destination=vec![0;capacity];
  let(s,r,w)=state.decode_to_utf8_raw(&encode(&[unit],be),&mut destination,true);
  let(n,a,b)=match s {encoding_rs::DecoderResult::InputEmpty=>(0,0,0),encoding_rs::DecoderResult::OutputFull=>(1,0,0),encoding_rs::DecoderResult::Malformed(a,b)=>(2,a,b)};
  let(lead,byte,_,pending)=source_probe_utf16_snapshot(&state);
  pairs.extend_from_slice(&[n,r as u8,w as u8,a,b]);pairs.extend_from_slice(&lead.to_le_bytes());
  pairs.extend_from_slice(&[byte.is_some() as u8,byte.unwrap_or(0),pending as u8]);
  for i in 0..3 {pairs.push(if i<w {destination[i]}else{0});}
 }}}
 assert_eq!(pairs.len(),3407872);std::fs::write(output.join("units.bin"),pairs).unwrap();
 let mut edges=Vec::new();
 for be in [false,true] {for ascii_length in [0,1,3,4,15,16,63,64,65] {
  for suffix in [&[][..],&[0u16],&[0x80],&[0x7ff],&[0x800],&[0xd800],&[0xdc00],&[0xd800,0xdc00],&[0xd800,0x41],&[0x41,0xdc00,0x42],&[0xfeff,0x41]] {
   let mut units=vec![0x41;ascii_length];units.extend_from_slice(suffix);let bytes=encode(&units,be);
   for capacity in [0,1,2,3,4,5,7,8,15,16,17,63,64,65,66,80] {
    let mut destination=vec![0;capacity];let(malformed,read,written)=encoding_rs::source_probe_utf16_utf8_prefix(&bytes,&mut destination,be);
    edges.push(format!("{{\"be\":{be},\"input_hex\":\"{}\",\"capacity\":{capacity},\"malformed\":{malformed},\"read\":{read},\"written\":{written},\"bytes\":{:?}}}",hex(&bytes),&destination[..written]));
   }
  }
 }}
 assert_eq!(edges.len(),3168);std::fs::write(output.join("prefix_edges.json"),format!("[{}]\n",edges.join(","))).unwrap();
 let mut records=Vec::new();let mut capacities=Vec::new();
 for be in [false,true] {
  let mut prefixes=vec![vec![],vec![0],encode(&[0xd800],be),encode(&[0xdbff],be),encode(&[0xd800,0xd800],be),encode(&[0xd800,0x41],be)];
  let mut three=encode(&[0xd800],be);three.push(0);prefixes.push(three);
  let mut suffixes=vec![vec![],vec![0],vec![255]];
  for units in [&[0u16][..],&[0x41],&[0x7ff],&[0xd7ff],&[0xd800],&[0xdbff],&[0xdc00],&[0xdfff],&[0xe000],&[0xfeff],&[0xffff],&[0xd800,0xdc00],&[0xd800,0xd800,0xdc00],&[0xd800,0x41,0x42],&[0x41,0xdc00,0x42]] {suffixes.push(encode(units,be));}
  for prefix in &prefixes {for suffix in &suffixes {for capacity in [0,1,2,3,4,8,16] {for last in [false,true] {for replacement in [false,true] {
   records.push(sequence(&[(prefix,32,false),(suffix,capacity,last)],be,replacement));
  }}}}
   let mut state=source_probe_utf16_new(be);let _=state.decode_to_utf8_raw(prefix,&mut[0;32],false);
   let mut values=Vec::new();
   for length in [0,1,2,3,4,9,usize::MAX/3,usize::MAX/3+1,usize::MAX-4,usize::MAX-3,usize::MAX-2,usize::MAX-1,usize::MAX] {
    values.push(format!("{{\"length\":{length},\"utf16\":{},\"utf8\":{},\"utf8_without_replacement\":{}}}",maybe(state.max_utf16_buffer_length(length)),maybe(state.max_utf8_buffer_length(length)),maybe(state.max_utf8_buffer_length_without_replacement(length))));
   }
   capacities.push(format!("{{\"prefix_hex\":\"{}\",{},\"values\":[{}]}}",hex(prefix),slots(&state),values.join(",")));
  }
  for byte in 0..=255 {for capacity in [0,1,2,3] {for last in [false,true] {for replacement in [false,true] {
   records.push(sequence(&[(&[byte],capacity,last)],be,replacement));
  }}}}
 }
 let mut mixed=Vec::new();
 for be in [false,true] {for first_utf16 in [false,true] {
  for prefix in [vec![],vec![0],encode(&[0xd800],be),{let mut p=encode(&[0xd800],be);p.push(0);p}] {
   for suffix in [vec![],vec![0],encode(&[0],be),encode(&[0x41],be),encode(&[0xd800],be),encode(&[0xdc00],be),encode(&[0xdfff],be)] {
    for capacity in [0,1,2,3,4,8] {
     let mut state=source_probe_utf16_new(be);
     let steps=[mixed_record(&mut state,&prefix,32,false,first_utf16),mixed_record(&mut state,&suffix,capacity,false,!first_utf16),mixed_record(&mut state,&[],8,true,first_utf16)];
     mixed.push(format!("{{\"be\":{be},\"steps\":[{}]}}",steps.join(",")));
    }
   }
  }
 }}
 assert_eq!(mixed.len(),672);std::fs::write(output.join("mixed.json"),format!("[{}]\n",mixed.join(","))).unwrap();
 std::fs::write(output.join("sequences.json"),format!("[{}]\n",records.join(","))).unwrap();
 std::fs::write(output.join("capacities.json"),format!("[{}]\n",capacities.join(","))).unwrap();
 println!("actual UTF16 raw UTF8 destination: 262144 exhaustive unit/capacity records, {} raw/replacement sequences, {} checked-capacity states PASS",records.len(),capacities.len());
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-utf16-utf8-decoder-probe"])
    raw.main()
    parser = raw.validity.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home()/".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output=args.output.resolve()
    clone=output/"encoding_rs_source_probe"
    exports={
        "src/handles.rs": '\npub fn source_probe_utf16_utf8_prefix(input:&[u8],output:&mut[u8],be:bool)->(bool,usize,usize) {let mut source=ByteSource::new(input);let mut destination=Utf8Destination::new(output);let malformed=if be {destination.copy_utf16_from::<BigEndian>(&mut source)}else{destination.copy_utf16_from::<LittleEndian>(&mut source)}.is_some();(malformed,source.consumed(),destination.written())}\n',
        "src/lib.rs": '\npub fn source_probe_utf16_utf8_prefix(input:&[u8],output:&mut[u8],be:bool)->(bool,usize,usize) {handles::source_probe_utf16_utf8_prefix(input,output,be)}\n',
    }
    for relative,export in exports.items():
        target=clone/relative
        original=target.read_bytes()
        target.write_bytes(original+export.encode())
        assert target.read_bytes().startswith(original)
    (clone/"src/bin/source_utf16_utf8_decoder_probe.rs").write_text(DRIVER)
    environment=os.environ.copy()
    environment["VOX2_UTF16_UTF8_OUTPUT"]=str(output)
    environment["PATH"]=str(args.cargo.resolve().parent)+os.pathsep+environment.get("PATH","")
    reference=None
    for profile in [[],["--release"]]:
        print("actual UTF16 UTF8 variant profile",profile or ["debug"],flush=True)
        subprocess.run([str(args.cargo.resolve()),"run","--offline","--bin","source_utf16_utf8_decoder_probe",*profile],cwd=clone,env=environment,check=True)
        actual=[(output/name).read_bytes() for name in ["units.bin","sequences.json","capacities.json","prefix_edges.json","mixed.json"]]
        if reference is None: reference=actual
        else: assert actual==reference,"Source debug/release UTF16 raw artifacts differ"
    print("actual UTF16 UTF8 variant debug/release artifacts match exactly",flush=True)

if __name__=="__main__":
    main()
