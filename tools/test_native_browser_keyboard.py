#!/usr/bin/env python3
"""Check modifier presses and Command shortcuts in the built macOS browser.

Run through tools/run_memory_bounded.py. Uses a local page and the test display.
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
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="vox-native-keyboard-") as directory:
        output = Path(directory)
        page = output / "keyboard.html"
        page.write_text('<!doctype html><title>Keyboard regression</title>'
                        '<body style="margin:0;background:#159b53">'
                        '<h1>Command must preserve this page</h1>')
        library = output / "keyboard.dylib"
        subprocess.run([
            "clang", "-dynamiclib", "-fobjc-arc", "-fblocks",
            "-framework", "Cocoa", "-framework", "QuartzCore",
            str(repo / "tools/native_browser_keyboard_test.m"), "-o", str(library),
        ], check=True)
        env = dict(os.environ, VOX_TEST_WINDOW="1", VOX_PROFILE_DIR=str(output / "profile"),
                   LADYBIRD_CACHE_DIR=str(output / "cache"),
                   DYLD_INSERT_LIBRARIES=str(library))
        for name in ("LADYBIRD_SCREENSHOT_DELAY_SECONDS", "LADYBIRD_SCREENSHOT_SCALE",
                     "VOX_PROFILE_SCROLL", "VOX_PROFILE_INSTRUCTIONS"):
            env.pop(name, None)
        result = subprocess.run(
            [str(args.binary.resolve()), "--window-width=800", "--window-height=684", str(page)],
            env=env, capture_output=True, text=True, timeout=90,
        )
        print(result.stdout, end="")
        print(result.stderr, end="")
        if result.returncode:
            raise SystemExit(f"Vox exited with status {result.returncode} during keyboard checks")
        if "PASS native browser modifiers and Command shortcuts" not in result.stderr:
            raise SystemExit("Vox exited before completing the keyboard regression")


if __name__ == "__main__":
    main()
