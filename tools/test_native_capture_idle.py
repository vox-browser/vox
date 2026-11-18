#!/usr/bin/env python3
"""Check both real asynchronous native capture entry points without a window.

The fixture intercepts cacheDisplay and application termination. It inspects the
actual retained image, capture scale and deferred delivery under ARC and MRC.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entry_points(source):
    text = source.read_text()
    functions = []
    for declaration in ("static CGFloat native_screenshot_scale(",
                        "double native_raster_device_pixel_ratio(",
                        "static CGFloat native_window_backing_scale(",
                        "static CGFloat native_svg_mask_backing_scale(",
                        "void native_cache_browser_snapshot(",
                        "static void native_schedule_screenshot(",
                        "void schedule_native_screenshot(",
                        "void schedule_native_document_screenshot("):
        start = text.index(declaration)
        end = text.index("\n}\n", start) + 2
        function = text[start:end]
        if "native_when_document_work_idle" in function:
            assert function.index("native_when_document_work_idle") < function.index("[view displayIfNeeded]")
        functions.append(function)
    return "\n\n".join(functions) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    source = args.source_root.resolve()
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="vox-capture-idle-"))
    output.mkdir(parents=True, exist_ok=True)
    # Refuse to overwrite prior evidence, including a failed attempt.
    assert not (output / "result.json").exists(), output
    header = source / "native/include/native_layer_presentation_darwin.h"
    png_header = source / "native/include/native_snapshot_png_darwin.h"
    implementation = source / "native_capture_darwin.m"
    fixture = source / "tools/native_capture_idle_test.m"
    extracted = output / "native_capture_entry_points.inc"
    extracted.write_text(entry_points(implementation))
    compiler = Path(shutil.which("clang")).resolve()
    pins = {str(path): sha256(path) for path in (header, png_header,
        source / 'native/include/native_document_color_darwin.h',
        source / 'native/include/native_presented_capture_darwin.h', source / 'native/include/native_presented_pixels_darwin.h',
        implementation, fixture, extracted,
        compiler, Path(__file__).resolve())}
    result = {"status": "running", "pins": pins, "jobs": {}}
    for mode, flag in (("nonarc", "-fno-objc-arc"), ("arc", "-fobjc-arc")):
        directory = output / mode
        directory.mkdir()
        command = [str(compiler), flag, "-fblocks", "-framework", "Cocoa", "-framework", "ImageIO", "-framework", "QuartzCore", "-framework", "IOSurface",
                   "-framework", "CoreGraphics", "-lz", "-I", str(source), "-I", str(output), str(fixture),
                   "-o", str(directory / "tests")]
        row = {"command": command}
        with (directory / "compile.log").open("w") as log:
            row["compile_exit_code"] = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT).returncode
        if row["compile_exit_code"] == 0:
            row["binary_sha256"] = sha256(directory / "tests")
            row["color_spaces"] = {}
            for color_space in ("srgb", "display-p3"):
                artifacts = directory / color_space
                artifacts.mkdir()
                env = dict(os.environ)
                env.pop("VOX_TEST_CAPTURE_P3", None)
                if color_space == "display-p3":
                    env["VOX_TEST_CAPTURE_P3"] = "1"
                test_log = artifacts / "test.log"
                with test_log.open("w") as log:
                    test_exit = subprocess.run([str(directory / "tests"), str(artifacts)],
                                               env=env, stdout=log, stderr=subprocess.STDOUT).returncode
                text = test_log.read_text()
                row["color_spaces"][color_space] = {
                    "exit": test_exit,
                    "snapshot_and_window_cases": text.count("deferred=1 fresh_source=32x16 scale=1 once=1 path_alive=1"),
                    "document_cases": text.count("deferred=1 bounds=1 png=20x8 process=1 coalition=1"),
                    "invalid_cases": text.count("rejected=1 no_png=1 no_checkpoint=1"),
                    "final_marker_present": "PASS deferred actual snapshot/screenshot entry points preserve logical scale and path lifetime" in text,
                }
        expected = {"exit": 0, "snapshot_and_window_cases": 4, "document_cases": 2,
                    "invalid_cases": 8, "final_marker_present": True}
        row["status"] = "passed" if row.get("color_spaces") == dict.fromkeys(("srgb", "display-p3"), expected) else "failed"
        result["jobs"][mode] = row
    result["changed_inputs"] = [str(path) for path, digest in pins.items() if sha256(Path(path)) != digest]
    result["status"] = "passed" if all(row["status"] == "passed" for row in result["jobs"].values()) and not result["changed_inputs"] else "failed"
    (output / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"status": result["status"], "result": str(output / "result.json")}))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
