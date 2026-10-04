#!/usr/bin/env python3
"""Probe Source's real LibTextCodec Rust replacement decoder and dependency.

The temporary test crate includes the pinned, read-only LibTextCodec bridge and
links the exact Cargo.lock encoding_rs dependency. It does not rewrite the
decoder, compile a LibWeb owner, or build the browser bundle.
"""

import argparse
import hashlib
import os
import pathlib
import re
import subprocess
import tarfile


TEST = r'''
#[cfg(test)]
mod source_replacement_probe {
    use super::*;

    unsafe extern "C" fn collect(ctx: *mut c_void, data: *const u8, len: usize) {
        unsafe {
            let result = &mut *ctx.cast::<Option<Vec<u8>>>();
            *result = Some(std::slice::from_raw_parts(data, len).to_vec());
        }
    }

    fn decode(label: &[u8], bytes: &[u8], remove_bom: bool, fatal: bool) -> (bool, Option<Vec<u8>>) {
        let mut result = None;
        let ok = unsafe {
            textcodec_rust_decode_to_utf8(label.as_ptr(), label.len(), bytes.as_ptr(), bytes.len(),
                remove_bom, fatal, (&mut result as *mut Option<Vec<u8>>).cast(), collect)
        };
        (ok, result)
    }

    #[test]
    fn source_replacement_bridge_labels_and_one_shot() {
        for label in [b"replacement".as_slice(), b"csiso2022kr", b"hz-gb-2312", b"iso-2022-cn",
            b"iso-2022-cn-ext", b"iso-2022-kr", b" \tISO-2022-KR\r\n"] {
            let mut name = std::ptr::null();
            let mut len = 0;
            assert!(unsafe { textcodec_rust_get_standardized_encoding(label.as_ptr(), label.len(), &mut name, &mut len) });
            assert_eq!(unsafe { std::slice::from_raw_parts(name, len) }, b"replacement");
            for bytes in [b"".as_slice(), b"A", b"AB", &[0, 0xff, 0x61], &[0xef, 0xbb, 0xbf],
                &[0xff, 0xfe], &[0xfe, 0xff], &[0xef, 0xbb], &[0xff]] {
                for remove_bom in [false, true] {
                    let expected = if bytes.is_empty() { b"".as_slice() } else { b"\xef\xbf\xbd".as_slice() };
                    assert_eq!(decode(label, bytes, remove_bom, false), (true, Some(expected.to_vec())));
                    assert_eq!(decode(label, bytes, remove_bom, true),
                        if bytes.is_empty() { (true, Some(vec![])) } else { (false, None) });
                }
            }
            println!("{}: empty -> empty; nonempty -> one U+FFFD; fatal -> failure", String::from_utf8_lossy(label));
        }
    }

    #[test]
    fn source_replacement_raw_emitted_and_output_capacity() {
        let mut decoder = encoding_rs::REPLACEMENT.new_decoder_without_bom_handling();
        assert_eq!(decoder.decode_to_utf8_without_replacement(b"", &mut [], false),
            (DecoderResult::InputEmpty, 0, 0));
        let mut short = [0; 2];
        assert_eq!(decoder.decode_to_utf8_without_replacement(b"AB", &mut short, false),
            (DecoderResult::OutputFull, 0, 0));
        let mut room = [0; 3];
        assert_eq!(decoder.decode_to_utf8_without_replacement(b"AB", &mut room, false),
            (DecoderResult::Malformed(1, 0), 1, 0));
        assert_eq!(decoder.decode_to_utf8_without_replacement(b"BC", &mut [], true),
            (DecoderResult::InputEmpty, 2, 0));
        assert_eq!(room, [0; 3]);
        let mut decoder = encoding_rs::REPLACEMENT.new_decoder_without_bom_handling();
        assert_eq!(decoder.decode_to_utf8(b"AB", &mut room, false),
            (CoderResult::InputEmpty, 2, 3, true));
        assert_eq!(room, [0xef, 0xbf, 0xbd]);
        assert_eq!(decoder.decode_to_utf8(b"CDEF", &mut [], true),
            (CoderResult::InputEmpty, 4, 0, false));
        println!("raw state: empty and OutputFull retain emitted=false; first malformed consumes1; later input consumed without output");
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=pathlib.Path, default=pathlib.Path.home() / "code/3rd/ladybird")
    parser.add_argument("--cargo", type=pathlib.Path, default=pathlib.Path.home() / ".rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("Build/audit-fixes/source-replacement-decoder-probe"))
    args = parser.parse_args()
    source = args.source.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    locked_package = next(item for item in (source / "Cargo.lock").read_text().split("[[package]]")
        if '\nname = "encoding_rs"\n' in item)
    dependency = dict(re.findall(r'^([a-z_]+) = "([^"]*)"$', locked_package, re.MULTILINE))
    assert dependency["version"] == "0.8.40", dependency
    registry = pathlib.Path.home() / ".cargo/registry/src"
    candidates = list(registry.glob("*/encoding_rs-" + dependency["version"]))
    assert len(candidates) == 1, candidates
    decoder = candidates[0]
    archive = pathlib.Path.home() / ".cargo/registry/cache" / decoder.parent.name / (decoder.name + ".crate")
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == dependency["checksum"]
    with tarfile.open(archive) as package:
        for member in package.getmembers():
            if member.isfile():
                relative = pathlib.Path(member.name).relative_to(decoder.name)
                assert (decoder / relative).read_bytes() == package.extractfile(member).read(), relative
    references = [source / "Cargo.lock", source / "Libraries/LibTextCodec/Rust/Cargo.toml",
        source / "Libraries/LibTextCodec/Rust/src/lib.rs", source / "Libraries/LibTextCodec/Decoder.cpp",
        decoder / "src/replacement.rs", decoder / "src/lib.rs"]
    for reference in references:
        print(reference, hashlib.sha256(reference.read_bytes()).hexdigest(), flush=True)
    print("encoding_rs", dependency["version"], dependency["checksum"], flush=True)
    (output / "Cargo.toml").write_text('[package]\nname="source_replacement_decoder_probe"\nversion="0.1.0"\nedition="2024"\n[workspace]\n[dependencies]\nencoding_rs="=0.8.40"\n')
    # Keeping the pinned lock provides the exact transitive package versions.
    (output / "Cargo.lock").write_bytes((source / "Cargo.lock").read_bytes())
    (output / "src").mkdir(exist_ok=True)
    bridge = source / "Libraries/LibTextCodec/Rust/src/lib.rs"
    (output / "src/lib.rs").write_text('include!(r#"' + str(bridge) + '"#);\n' + TEST)
    environment = os.environ.copy()
    environment["PATH"] = str(args.cargo.resolve().parent) + os.pathsep + environment.get("PATH", "")
    for profile in [[], ["--release"]]:
        print("profile", profile or ["debug"], flush=True)
        subprocess.run([str(args.cargo.resolve()), "test", "--offline", "--lib", *profile,
            "source_replacement_probe", "--", "--nocapture"], cwd=output, env=environment, check=True)


if __name__ == "__main__":
    main()
