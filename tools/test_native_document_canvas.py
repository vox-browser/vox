#!/usr/bin/env python3
"""Compare real document canvas/filter entry points with isolated publication.

Run through tools/run_memory_bounded.py (3 GiB suffices). Uses production ARC;
optimized and ASan/UBSan cases include the BGRA compatibility and publication
fixtures. No window or external image decoder is required.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


def entry_points(text):
    def function(signature):
        start = text.index(signature)
        return text[start:text.index("\n}\n", start) + 2]

    declarations = text[text.index("#define NATIVE_CSS_FILTER_MAX_DEPTH"):
                        text.index("// Run after the native draw has unwound.")]
    # This fixture does not use decoded SVG image nodes.
    declarations = declarations.replace(
        "static CGImageRef native_copy_cg_image(gg__Image *image);",
        "static CGImageRef native_copy_cg_image(gg__Image *image) { (void)image; return NULL; }")
    functions = [function(signature) for signature in (
        "static void native_add_elliptical_arc(",
        "static CGPathRef native_create_corner_rounded_rect_path(",
        "static void native_initialize_css_filter_renderer(",
        "void native_prepare_css_filter_renderer(",
        "void native_begin_css_filter_layer(")]
    functions.append("void native_end_css_filter_layer(void);")
    functions += [function(signature) for signature in (
        "void native_begin_font_compositing_layer(", "void native_end_font_compositing_layer(")]
    functions.append(text[text.index("void native_begin_backdrop_filter_layer("):
                          text.index("static CGRect native_svg_mask_canvas_rect(")])
    return declarations + "\n" + "\n".join(functions) + "\n"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve()
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="vox-document-canvas-"))
    output.mkdir(parents=True, exist_ok=True)
    assert not any(output.iterdir()), "Refusing to overwrite prior evidence"
    implementation = source / "native_capture_darwin.m"
    extracted = output / "native_document_canvas_entry_points.inc"
    extracted.write_text(entry_points(implementation.read_text()))
    fixtures = ("native_document_canvas_test.m", "native_document_bitmap_copy_test.mm",
                "native_document_publication_test.mm", "native_css_grayscale_test.m",
                "native_css_grayscale_rows_test.m", "native_css_compact_input_test.m",
                "native_css_color_filter_cache_test.m", "native_empty_pointwise_filter_test.m",
                "native_sparse_bitmap_context_test.cpp", "native_pointwise_output_bounds_test.m")
    compiler = Path(shutil.which("clang")).resolve()
    inputs = [implementation, extracted, compiler, Path(__file__).resolve()]
    inputs += list(source.glob("native*darwin.h"))
    inputs += [source / "tools" / name for name in fixtures]
    pins = {str(path): sha256(path) for path in inputs}
    result = {"status": "running", "pins": pins, "jobs": []}
    for mode, flags in (("o2", ["-O2"]),
                        ("sanitized", ["-O1", "-g", "-fsanitize=address,undefined"])):
        for fixture in fixtures:
            name = Path(fixture).stem
            binary = output / (name + "-" + mode)
            arc = "-fobjc-arc" if fixture.endswith(".m") else "-fno-objc-arc"
            cxx = [] if fixture.endswith(".m") else ["-std=c++20", "-lc++"]
            command = [str(compiler), arc, "-fblocks", *flags, *cxx, "-Wno-deprecated-declarations",
                       "-I", str(source), "-I", str(output), str(source / "tools" / fixture),
                       "-framework", "Cocoa", "-framework", "CoreGraphics", "-framework", "CoreImage",
                       "-framework", "QuartzCore", "-framework", "IOSurface", "-o", str(binary)]
            row = {"fixture": fixture, "mode": mode, "command": command}
            log_path = binary.with_suffix(".log")
            with log_path.open("x") as log:
                row["compile_exit_code"] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
                if row["compile_exit_code"] == 0:
                    row["binary_sha256"] = sha256(binary)
                    row["test_exit_code"] = subprocess.run([str(binary)], stdout=log, stderr=subprocess.STDOUT).returncode
            row["status"] = "passed" if row.get("test_exit_code") == 0 else "failed"
            result["jobs"].append(row)
            print(f"{fixture} {mode}: {row['status']} ({log_path})", flush=True)
    result["changed_inputs"] = [path for path, digest in pins.items() if sha256(Path(path)) != digest]
    result["status"] = "passed" if not result["changed_inputs"] and all(
        row["status"] == "passed" for row in result["jobs"]) else "failed"
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
