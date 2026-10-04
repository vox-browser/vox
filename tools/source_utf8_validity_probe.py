#!/usr/bin/env python3
"""Probe the actual pinned encoding_rs UTF8 validity helper and Source bridge.

The validated dependency is copied to ignored output. Its implementation bodies
remain unchanged; an appended harness export lets an isolated binary call the
actual private-module helper. Upstream/cache files are never modified.
"""

import argparse
import hashlib
import os
import pathlib
import platform
import re
import shutil
import subprocess
import sys

import source_replacement_decoder_probe as shared

BRIDGE_TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
    use super::*;
    unsafe extern "C" fn collect(ctx: *mut c_void, data: *const u8, len: usize) {
        unsafe { *ctx.cast::<Option<Vec<u8>>>() = Some(std::slice::from_raw_parts(data, len).to_vec()); }
    }
    fn decode(input: &[u8], fatal: bool) -> (bool, Option<Vec<u8>>) {
        let label = b"utf-8";
        let mut output = None;
        let ok = unsafe { textcodec_rust_decode_to_utf8(label.as_ptr(), label.len(), input.as_ptr(), input.len(),
            false, fatal, (&mut output as *mut Option<Vec<u8>>).cast(), collect) };
        (ok, output)
    }
    fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
    #[test]
    fn source_utf8_bridge_malformed_prefix_reprocess_and_truncated_tail() {
        assert_eq!(decode(&[0xe1, 0x41], false), (true, Some(vec![0xef, 0xbf, 0xbd, 0x41])));
        assert_eq!(decode(&[0xe1, 0x80, 0x41], false), (true, Some(vec![0xef, 0xbf, 0xbd, 0x41])));
        let mut records = Vec::new();
        for input in [vec![], vec![0xe1, 0x41], vec![0xe1, 0x80, 0x41], vec![0xf1, 0x80, 0x80, 0x41],
            vec![0xe0, 0x80, 0x80], vec![0xed, 0xa0, 0x80], vec![0xf4, 0x90, 0x80, 0x80], vec![0xf0, 0x9f],
            vec![0xc2], vec![0xe1, 0x80], vec![0x41, 0, 0xf0, 0x9f, 0x98, 0x80, 0], vec![0xef, 0xbf, 0xbd]] {
            let (ok, output) = decode(&input, false);
            assert!(ok);
            records.push(format!("{{\"input_hex\":\"{}\",\"utf8_hex\":\"{}\",\"fatal_ok\":{}}}",
                hex(&input), hex(&output.unwrap()), decode(&input, true).0));
        }
        std::fs::write(std::env::var("VOX2_UTF8_BRIDGE_GOLD").unwrap(), format!("[{}]\n", records.join(","))).unwrap();
        println!("actual Source UTF8 bridge malformed-prefix reprocessing and tail goldens PASS");
    }
}
'''

DRIVER = r'''
use encoding_rs::source_utf8_validity_probe;
use std::path::Path;
fn prefix(input: &[u8]) -> u8 {
    let actual = source_utf8_validity_probe(input);
    let standard = match std::str::from_utf8(input) { Ok(_) => input.len(), Err(error) => error.valid_up_to() };
    assert_eq!(actual, standard, "input {input:?}");
    actual as u8
}
fn hex(bytes: &[u8]) -> String { bytes.iter().map(|byte| format!("{byte:02x}")).collect() }
fn main() {
    let directory = std::env::var("VOX2_UTF8_VALIDITY_OUTPUT").unwrap();
    let output = Path::new(&directory);
    let mut pairs = Vec::new();
    for first in 0..=255 { for second in 0..=255 { pairs.push(prefix(&[first, second])); } }
    std::fs::write(output.join("pairs.bin"), pairs).unwrap();
    let mut triples = Vec::new();
    for first in 0xe0..=0xef { for second in 0..=255 { for third in 0..=255 {
        triples.push(prefix(&[first, second, third]));
    } } }
    std::fs::write(output.join("triples.bin"), triples).unwrap();
    let edges = [0, 0x7f, 0x80, 0x9f, 0xa0, 0xbf, 0xc0, 0xff];
    let mut quads = Vec::new();
    for first in 0xf0..=0xf4 { for second in 0..=255 { for third in edges { for fourth in edges {
        quads.push(prefix(&[first, second, third, fourth]));
    } } } }
    std::fs::write(output.join("quads.bin"), quads).unwrap();
    let mut records = Vec::new();
    for ascii_length in [0, 1, 3, 4, 15, 16, 63, 64, 65, 127, 128] {
        for suffix in [b"".as_slice(), &[0xc2], &[0xc2, 0x80], &[0xe0, 0xa0, 0x80], &[0xed, 0xa0, 0x80],
            &[0xe1, 0x80, 0x41], &[0xf0, 0x9f, 0x98, 0x80], &[0xf4, 0x90, 0x80, 0x80], &[0, 0x80]] {
            let mut input = vec![b'A'; ascii_length]; input.extend_from_slice(suffix);
            let valid = source_utf8_validity_probe(&input);
            for extra_ascii in [false, true] {
                if extra_ascii { input.extend_from_slice(b"\0Z"); }
                let actual = source_utf8_validity_probe(&input);
                if !extra_ascii { assert_eq!(valid, actual); }
                records.push(format!("{{\"input_hex\":\"{}\",\"valid_up_to\":{actual}}}", hex(&input)));
            }
        }
    }
    for lead in 0..=255 {
        let input = [lead, 0x80, 0x80, 0x80];
        records.push(format!("{{\"input_hex\":\"{}\",\"valid_up_to\":{}}}", hex(&input), source_utf8_validity_probe(&input)));
    }
    std::fs::write(output.join("edges.json"), format!("[{}]\n", records.join(","))).unwrap();
    println!("actual Source validator: 65536 pairs,1048576 triples,81920 quads,454 tail/ASCII/SIMD-threshold/lead cases PASS");
}
'''


def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-utf8-validity-probe"))
    known, _ = parser.parse_known_args()
    head = subprocess.check_output(["git", "-C", str(known.source), "rev-parse", "HEAD"], text=True).strip()
    if head != "963d46a829f3e1b79f44dba9d02afb70654300fa":
        raise SystemExit("Source HEAD differs from required pin: " + head)
    print("Source HEAD", head, flush=True)
    dependency = next((pathlib.Path.home() / ".cargo/registry/src").glob("*/encoding_rs-0.8.40"))
    for relative in ["src/utf_8.rs", "src/ascii.rs", "src/handles.rs", "src/lib.rs"]:
        print(relative, hashlib.sha256((dependency / relative).read_bytes()).hexdigest(), flush=True)
    output = known.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    os.environ["VOX2_UTF8_BRIDGE_GOLD"] = str(output / "bridge.json")
    if not any(arg == "--output" or arg.startswith("--output=") for arg in sys.argv):
        sys.argv.extend(["--output", str(output)])
    shared.__doc__ = __doc__
    shared.TEST = BRIDGE_TEST
    shared.main()
    # The shared path has validated every archive file before this copy.
    clone = output / "encoding_rs_source_probe"
    shutil.copytree(dependency, clone, dirs_exist_ok=True)
    original = (clone / "src/lib.rs").read_bytes()
    (clone / "src/lib.rs").write_bytes(original + b"\n// Isolated probe only: actual private-module Source helper.\npub fn source_utf8_validity_probe(input: &[u8]) -> usize { utf_8::utf8_valid_up_to(input) }\n")
    assert (clone / "src/lib.rs").read_bytes().startswith(original)
    # The registry-normalized manifest forces offline resolution of unused
    # optional/dev packages. This isolated AArch64 harness preserves the real
    # Source default alloc configuration and locked dependencies actually used
    # by that configuration, with every implementation body left unchanged.
    if platform.machine() != "arm64":
        raise SystemExit("The actual-helper harness currently selects Source AArch64 dependencies")
    locked = (known.source / "Cargo.lock").read_text().split("[[package]]")
    versions = {}
    for name in ["cfg-if", "scopeguard", "multiversion_no_op", "rustversion", "simdutf8"]:
        record = next(item for item in locked if '\nname = "' + name + '"\n' in item)
        versions[name] = re.search(r'\nversion = "([^"]+)"', record).group(1)
    original_manifest = (dependency / "Cargo.toml").read_text()
    features = original_manifest.split("[features]\n", 1)[1].split("\n[lib]", 1)[0]
    flags = re.findall(r"^([a-z0-9-]+) =", features, re.M)
    manifest = '[package]\nname="encoding_rs"\nversion="0.8.40"\nedition="2024"\n[workspace]\n[lib]\nname="encoding_rs"\npath="src/lib.rs"\n[features]\ndefault=["alloc"]\n'
    manifest += ''.join(name + '=[]\n' for name in flags if name != "default") + 'serde=[]\n'
    manifest += '[dependencies]\ncfg-if="=' + versions["cfg-if"] + '"\nmultiversion_no_op="=' + versions["multiversion_no_op"] + '"\n'
    manifest += 'scopeguard={version="=' + versions["scopeguard"] + '",default-features=false}\n'
    manifest += 'simdutf8={version="=' + versions["simdutf8"] + '",default-features=false,features=["aarch64_neon","public_imp"]}\n'
    manifest += '[build-dependencies]\nrustversion="=' + versions["rustversion"] + '"\n'
    manifest += '[lints.rust.unexpected_cfgs]\nlevel="warn"\ncheck-cfg=["cfg(fuzzing)"]\n'
    (clone / "Cargo.toml").write_text(manifest)
    print("actual helper Source default alloc; isolated AArch64 manifest", versions, flush=True)
    (clone / "Cargo.lock").write_bytes((known.source / "Cargo.lock").read_bytes())
    (clone / "src/bin").mkdir(exist_ok=True)
    (clone / "src/bin/source_utf8_probe.rs").write_text(DRIVER)
    environment = os.environ.copy()
    environment["VOX2_UTF8_VALIDITY_OUTPUT"] = str(output)
    environment["PATH"] = str(known.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for profile in [[], ["--release"]]:
        print("actual validator profile", profile or ["debug"], flush=True)
        subprocess.run([str(known.cargo.resolve()), "run", "--offline", "--bin", "source_utf8_probe", *profile], cwd=clone, env=environment, check=True)
    text = (dependency / "src/utf_8.rs").read_text()
    body = re.search(r"pub static UTF8_DATA: Utf8Data = Utf8Data \{\s*table: \[(.*?)\],\s*\};", text, re.S).group(1)
    values = re.findall(r"\b\d+\b", body)
    assert len(values) == 384
    license_text = text[:text.index("use super::*;")]
    (output / "utf8_validity_data.v").write_text(license_text + "// Source encoding_rs 0.8.40 UTF8_DATA.table (384 exact masks).\nmodule encoding\n\nconst utf8_validity_masks = [u8(" + values[0] + "), " + ", ".join(values[1:]) + "]\n")


if __name__ == "__main__":
    main()
