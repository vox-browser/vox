#!/usr/bin/env python3
"""Generate exact Source JIS/IBM tables and observe actual decode helpers."""
import hashlib
import os
import pathlib
import re
import subprocess
import sys

import source_shift_jis_baseline_probe as base

TABLES = ["JIS0208_LEVEL1_KANJI", "JIS0208_LEVEL2_AND_ADDITIONAL_KANJI", "IBM_KANJI", "JIS0208_SYMBOLS", "JIS0208_SYMBOL_TRIPLES", "JIS0208_RANGE_TRIPLES"]

RUST = r'''
use encoding_rs::{source_probe_jis0208_table,source_probe_jis0208_decode};
fn main() {
 let out=std::env::var("VOX2_JIS0208_OUTPUT").unwrap();let mut tables=Vec::new();
 for index in 0..6 {tables.push(source_probe_jis0208_table(index).to_vec());}
 let mut records=Vec::new();
 for pointer in (0..=11280).chain([usize::MAX/2,usize::MAX/2+1,usize::MAX-2,usize::MAX-1,usize::MAX]) {
  let (symbol,range)=source_probe_jis0208_decode(pointer);
  records.push(format!("{{\"pointer\":\"{pointer}\",\"symbol\":{},\"range\":{}}}",symbol.map(|n|n.to_string()).unwrap_or("null".to_string()),range.map(|n|n.to_string()).unwrap_or("null".to_string())));
 }
 assert_eq!(records.len(),11286);assert_eq!(tables.iter().map(|t|t.len()).sum::<usize>(),7042);
 for (name,value) in [("tables.json",format!("{tables:?}\n")),("helpers.json",format!("[{}]\n",records.join(",")))] {
  let path=std::path::Path::new(&out).join(name);if let Ok(old)=std::fs::read_to_string(&path){assert_eq!(old,value,"native JIS profiles differ");}std::fs::write(path,value).unwrap();
 }
 println!("actual Source JIS0208/IBM:6 literal tables/7042 units;11286 ordered symbol/range helper observations PASS");
}
'''


def main():
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", "Build/audit-fixes/source-jis0208-data-probe"])
    base.main()
    parser = base.base.argparse.ArgumentParser(add_help=False)
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    args, _ = parser.parse_known_args()
    output = args.output.resolve()
    clone = output / "encoding_rs_source_probe"
    data = (clone / "src/data.rs").read_text()
    print("actual copied src/data.rs", hashlib.sha256(data.encode()).hexdigest(), flush=True)
    exports = '\npub fn source_probe_jis0208_table(index:usize)->&\'static [u16] {match index {\n'
    generated = data[:data.index("// BEGIN GENERATED CODE")] + "// Exact encoding_rs 0.8.40 JIS/IBM data.\nmodule encoding\n\n"
    for index, name in enumerate(TABLES):
        match = re.search(r"pub static " + name + r": \[u16; (\d+)\] = \[(.*?)\n\];", data, re.S)
        assert match, name
        values = re.findall(r"0x[0-9A-Fa-f]+", match.group(2))
        assert len(values) == int(match.group(1)), name
        exports += f"{index}=>&crate::data::{name},\n"
        generated += "const source_" + name.lower() + " = [u16(" + values[0] + "), " + ", ".join(values[1:]) + "]\n\n"
    exports += "_=>panic!(\"unexpected table index\")}}\n"
    exports += "pub fn source_probe_jis0208_decode(pointer:usize)->(Option<u16>,Option<u16>){(crate::data::jis0208_symbol_decode(pointer),crate::data::jis0208_range_decode(pointer))}\n"
    lib = clone / "src/lib.rs"
    lib.write_text(lib.read_text() + exports)
    (clone / "src/bin/source_jis0208_data_probe.rs").write_text(RUST)
    (output / "jis0208_data.v").write_text(generated)
    environment = os.environ.copy()
    environment["VOX2_JIS0208_OUTPUT"] = str(output)
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for name in ["tables.json", "helpers.json"]:
        (output / name).unlink(missing_ok=True)
    for profile in [[], ["--release"]]:
        print("actual JIS tables/helpers profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "run", "--offline", *profile, "--bin", "source_jis0208_data_probe"], cwd=clone, env=environment, check=True)


if __name__ == "__main__":
    main()
