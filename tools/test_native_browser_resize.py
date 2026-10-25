#!/usr/bin/env python3
"""Maximize, restore and resize a built Vox window on the test display.

Run through tools/run_memory_bounded.py. The default source is the repository's
saved Old Reddit page, so the regression does not depend on the live website.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path,
                        default=repo / "Build/v/Vox.app/Contents/MacOS/Vox")
    parser.add_argument("--source", default=str(
        repo / "pixel_tests/sites/old-reddit-worldnews/index.html"))
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="vox-native-resize-") as directory:
        output = Path(directory)
        library = output / "resize.dylib"
        subprocess.run([
            "clang", "-dynamiclib", "-fobjc-arc", "-fblocks",
            "-framework", "Cocoa", "-framework", "QuartzCore",
            str(repo / "tools/native_browser_resize_test.m"), "-o", str(library),
        ], check=True)
        env = dict(os.environ, VOX_TEST_WINDOW="1", LADYBIRD_CACHE_DIR=str(output / "cache"),
                   DYLD_INSERT_LIBRARIES=str(library))
        # Screenshot/profile modes can exit or override scale before resizing.
        for name in ("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "LADYBIRD_SCREENSHOT_SCALE",
                     "VOX_PROFILE_SCROLL", "VOX_PROFILE_INSTRUCTIONS"):
            env.pop(name, None)
        result = subprocess.run(
            [str(args.binary.resolve()), "--window-width=800", "--window-height=684", args.source],
            env=env, capture_output=True, text=True, timeout=args.timeout,
        )
        print(result.stdout, end="")
        print(result.stderr, end="")
        if result.returncode:
            raise SystemExit(f"Vox exited with status {result.returncode} during resize")
        if "PASS native browser maximize, restore and resize" not in result.stderr:
            raise SystemExit("Vox exited before completing the resize regression")


if __name__ == "__main__":
    main()
