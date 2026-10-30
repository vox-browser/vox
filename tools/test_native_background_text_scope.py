#!/usr/bin/env python3
"""Test text mask entry points and subsequent shared decoration recording.

Run through tools/run_memory_bounded.py with a 3 GiB cap. Only the display's
backing scale is substituted; cache, mask compositing and shared clip code are
compiled from the canonical sources. No source checkout is copied.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile


def entry_points(text):
    def function(signature):
        start = text.index(signature)
        return text[start:text.index("\n}\n", start) + 2]

    declarations = text[text.index("static CGContextRef native_background_text_clip_build_context;"):
                        text.index("void native_prepare_background_text_gradient_input(")]
    return declarations + "\n" + "\n".join(function(signature) for signature in (
        "void native_begin_clip(", "void native_end_clip(",
        "void native_prepare_background_text_gradient_input(",
        "static void native_discard_background_text_recording(",
        "void native_begin_background_text_clip(",
        "void native_finish_background_text_clip(",
        "void native_end_background_text_clip(")) + "\n"



def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--implementation", type=Path,
                        help="Optional historical source for a regression sensitivity check")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent.parent
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="vox-text-mask-scope-"))
    output.mkdir(parents=True, exist_ok=True)
    assert not any(output.iterdir()), "Refusing to overwrite prior evidence"
    implementation = args.implementation.resolve() if args.implementation else source / "native_capture_darwin.m"
    extracted = output / "native_background_text_scope_entry_points.inc"
    extracted.write_text(entry_points(implementation.read_text()))
    compiler = Path(shutil.which("clang++")).resolve()
    upstream = Path(os.environ.get("LADYBIRD_SOURCE_DIR", source.parent / "3rd/ladybird"))
    triplet = os.environ.get("LADYBIRD_VCPKG_TRIPLET",
                             "arm64-osx-dynamic" if platform.machine() == "arm64" else "x64-osx-dynamic")
    skia = upstream / "Build/release/vcpkg_installed" / triplet
    fixture = source / "tools/native_background_text_scope_test.mm"
    inputs = [implementation, extracted, compiler, Path(__file__).resolve(), fixture,
              source / "native_skia_text_darwin.cpp", skia / "lib/libskia.dylib"]
    inputs += list(source.glob("native*.h"))
    pins = {str(path): sha256(path) for path in inputs}
    result = {"pins": pins, "source_copies": 0, "jobs": []}
    for mode, flags in (("o2", ["-O2"]),
                        ("sanitized", ["-O1", "-g", "-fsanitize=address,undefined"])):
        binary = output / ("native_background_text_scope-" + mode)
        command = [str(compiler), "-std=c++20", "-fno-objc-arc", *flags,
                   "-I", str(output), "-I", str(skia / "include/skia"),
                   "-I", str(skia / "include"), str(fixture), "-L", str(skia / "lib"), "-lskia"]
        for framework in ("Cocoa", "CoreFoundation", "CoreGraphics", "CoreText", "Foundation", "Metal"):
            command += ["-framework", framework]
        command += ["-Wl,-rpath," + str(skia / "lib"),
                    "-Wl,-rpath," + str(source / "Build/v/Vox.app/Contents/MacOS"), "-o", str(binary)]
        row = {"mode": mode, "command": command}
        with binary.with_suffix(".log").open("x") as log:
            row["compile_exit_code"] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
            if row["compile_exit_code"] == 0:
                row["binary_sha256"] = sha256(binary)
                row["test_exit_code"] = subprocess.run([str(binary)], stdout=log, stderr=subprocess.STDOUT).returncode
        result["jobs"].append(row)
        print(f"{mode}: {row}", flush=True)
    result["changed_inputs"] = [path for path, digest in pins.items() if sha256(Path(path)) != digest]
    result["status"] = "passed" if not result["changed_inputs"] and all(
        row.get("test_exit_code") == 0 for row in result["jobs"]) else "failed"
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
