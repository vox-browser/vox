#!/usr/bin/env python3
"""Exercise the browser's real window selection and async redraw under Cocoa."""
from pathlib import Path
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parent.parent
    source = (repo / "native_capture_darwin.m").read_text()
    functions = []
    for signature in (
        "static void native_consider_largest_view(",
        "static NSView *native_browser_view(",
        "static void native_mark_browser_redraw(",
        "static void native_request_browser_redraw(",
        "void native_wake_browser(",
    ):
        start = source.index(signature)
        end = source.index("\n}", start) + 2
        functions.append(source[start:end])
    with tempfile.TemporaryDirectory(prefix="vox-browser-window-") as directory:
        output = Path(directory)
        (output / "browser_view_functions.inc").write_text(
            "static void native_trace_browser_redraw(const char *point) {}\n"
            + "\n\n".join(functions)
        )
        for mode in ("-fobjc-arc", "-fno-objc-arc"):
            binary = output / "tests"
            subprocess.run([
                "clang", mode, "-fblocks", "-framework", "Cocoa",
                "-framework", "QuartzCore", "-framework", "IOSurface",
                "-I", str(output), str(repo / "tools/native_browser_window_test.m"),
                "-o", str(binary),
            ], check=True)
            subprocess.run([str(binary)], check=True)


if __name__ == "__main__":
    main()
