#!/usr/bin/env python3
"""Observe actual Source Shift_JIS UTF8 raw bodies, retained slots and counters."""
import hashlib
import os
import pathlib
import subprocess
import sys

import source_jis0208_data_probe as base

RUST = r'''
use encoding_rs::{source_probe_shift_jis_new,source_probe_shift_jis_lead};
fn record(d:&mut impl_shift_jis::Decoder,input:&[u8],capacity:usize,last:bool,out:&mut Vec<u8>) {
 let mut output=vec![0;capacity];let (status,read,written)=d.decode_to_utf8_raw(input,&mut output,last);
 let (status,bad,after)=match status {encoding_rs::DecoderResult::InputEmpty=>(0,0,0),encoding_rs::DecoderResult::OutputFull=>(1,0,0),encoding_rs::DecoderResult::Malformed(b,a)=>(2,b,a)};
 let lead=source_probe_shift_jis_lead(d);
 out.extend_from_slice(&[status,read as u8,written as u8,bad,after,lead.is_some() as u8,lead.unwrap_or(0)]);
 out.extend_from_slice(&output[..written]);out.extend(std::iter::repeat_n(0,8-written));
}
mod impl_shift_jis {pub type Decoder=encoding_rs::SourceProbeShiftJisDecoder;}
fn main() {
 let mut output=Vec::new();let mut records=0;
 for first in 0..=255u8 {for second in 0..=255u8 {for capacity in [3,8] {
  let mut whole=source_probe_shift_jis_new();record(&mut whole,&[first,second],capacity,true,&mut output);records+=1;
  let mut split=source_probe_shift_jis_new();
  for (input,last) in [(&[first][..],false),(&[second][..],false),(&[][..],true)] {record(&mut split,input,capacity,last,&mut output);records+=1;}
 }}}
 let mut edges=Vec::new();
 for input in [vec![],vec![0],vec![0x41,0,0x82],vec![0x82],vec![0x82,0x41],vec![0x82,0xa0],vec![0x80,0x41],vec![0xa1,0x41],vec![0xa0,0x41],vec![0xfc,0x4b],vec![0xfc,0x4c],vec![0xff,0x41],vec![0x81,0x40,0x41],vec![0x82,0xa0,0x41,0x42],vec![0x82,0xa0,0x82,0xa0],vec![0x82,0x7f],vec![0x82,0xfd],vec![0xfc,0x4b,0xff,0]] {
  for cut in 0..=input.len() {for capacity in 0..=8 {
   let mut d=source_probe_shift_jis_new();let mut steps=Vec::new();
   for(bytes,last)in[(&input[..cut],false),(&input[cut..],false),(&[][..],true)] {
    let mut output=vec![0;capacity];let (status,read,written)=d.decode_to_utf8_raw(bytes,&mut output,last);
    let (name,bad,after)=match status {encoding_rs::DecoderResult::InputEmpty=>("input_empty",0,0),encoding_rs::DecoderResult::OutputFull=>("output_full",0,0),encoding_rs::DecoderResult::Malformed(b,a)=>("malformed",b,a)};
    let lead=source_probe_shift_jis_lead(&d);let input_hex=bytes.iter().map(|b|format!("{b:02x}")).collect::<String>();
    steps.push(format!("{{\"input_hex\":\"{input_hex}\",\"last\":{last},\"capacity\":{capacity},\"status\":\"{name}\",\"read\":{read},\"written\":{written},\"bad\":{bad},\"after\":{after},\"has_lead\":{},\"lead\":{},\"bytes\":{:?}}}",lead.is_some(),lead.unwrap_or(0),&output[..written]));
   }
   edges.push(format!("{{\"steps\":[{}]}}",steps.join(",")));
  }}
 }
 let mut capacities=Vec::new();
 for first in [None,Some(0x82u8),Some(0xfcu8)] {
  let mut d=source_probe_shift_jis_new();if let Some(byte)=first {let mut temp=[0;8];let r=d.decode_to_utf8_raw(&[byte],&mut temp,false);assert_eq!(r.1,1);}
  let lead=source_probe_shift_jis_lead(&d);let mut limits=Vec::new();
  for length in [0,1,2,8,usize::MAX/3-1,usize::MAX/3,usize::MAX/3+1,usize::MAX-1,usize::MAX] {
   fn bound(v:Option<usize>)->String {v.map(|n|n.to_string()).unwrap_or("none".to_string())}
   limits.push(format!("{{\"byte_length\":\"{length}\",\"utf16\":\"{}\",\"utf8\":\"{}\",\"utf8_without_replacement\":\"{}\"}}",bound(d.max_utf16_buffer_length(length)),bound(d.max_utf8_buffer_length(length)),bound(d.max_utf8_buffer_length_without_replacement(length))));
  }
  capacities.push(format!("{{\"has_lead\":{},\"lead\":{},\"neutral\":{},\"capacities\":[{}]}}",lead.is_some(),lead.unwrap_or(0),d.in_neutral_state(),limits.join(",")));
 }
 assert_eq!(records,524288);assert_eq!(output.len(),records*15);
 let dir=std::env::var("VOX2_SHIFT_JIS_RAW_OUTPUT").unwrap();let path=std::path::Path::new(&dir).join("pairs.bin");
 if let Ok(previous)=std::fs::read(&path){assert_eq!(previous,output,"native raw pair profiles differ");}std::fs::write(path,output).unwrap();
 let edge_path=std::path::Path::new(&dir).join("edges.json");let edge_value=format!("[{}]\n",edges.join(","));if let Ok(old)=std::fs::read_to_string(&edge_path){assert_eq!(old,edge_value,"native edge profiles differ");}std::fs::write(edge_path,edge_value).unwrap();
 let cap_path=std::path::Path::new(&dir).join("capacities.json");let cap_value=format!("[{}]\n",capacities.join(","));if let Ok(old)=std::fs::read_to_string(&cap_path){assert_eq!(old,cap_value,"native capacity profiles differ");}std::fs::write(cap_path,cap_value).unwrap();
 println!("actual Source Shift_JIS raw:all65536 byte pairs,2 capacities,whole+3 retained split calls;524288 exact result/counter/lead/output records;3 capacity states/522 short-output edge sequences PASS");
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-shift-jis-raw-probe"])
    base.main()
    parser = base.base.base.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    clone = output / "encoding_rs_source_probe"
    for relative in ["src/shift_jis.rs", "src/macros.rs", "src/handles.rs"]:
        print("actual original", relative, hashlib.sha256((clone / relative).read_bytes()).hexdigest(), flush=True)
    unit = clone / "src/shift_jis.rs"
    unit.write_text(unit.read_text() + '\npub fn source_probe_lead(d:&ShiftJisDecoder)->Option<u8>{d.lead}\n')
    lib = clone / "src/lib.rs"
    lib.write_text(lib.read_text() + '\npub use crate::shift_jis::ShiftJisDecoder as SourceProbeShiftJisDecoder;\npub fn source_probe_shift_jis_new()->SourceProbeShiftJisDecoder{match crate::shift_jis::ShiftJisDecoder::new(){crate::variant::VariantDecoder::ShiftJis(d)=>d,_=>unreachable!()}}\npub fn source_probe_shift_jis_lead(d:&SourceProbeShiftJisDecoder)->Option<u8>{crate::shift_jis::source_probe_lead(d)}\n')
    (clone / "src/bin/source_shift_jis_raw_probe.rs").write_text(RUST)
    environment = os.environ.copy()
    environment["VOX2_SHIFT_JIS_RAW_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for name in ["pairs.bin", "capacities.json", "edges.json"]:
        (output / name).unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual Shift_JIS raw profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "run", "--offline", *profile, "--bin", "source_shift_jis_raw_probe"], cwd=clone, env=environment, check=True)


if __name__ == "__main__":
    main()
