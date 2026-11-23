#!/usr/bin/env python3
"""Check shared GG gradient, rounded image and poster rendering in Windows windows."""

import argparse
from functools import partial
import hashlib
import json
from pathlib import Path
import tempfile

from test_linux_browser import check_gradient_browser, check_rounded_image_browser
from test_windows_svg_pattern_tiles import input_hashes, run_guarded_capture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path, help="Windows Vox executable")
    parser.add_argument("--guard", type=Path, required=True, help="Windows job-object guard")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    binary, guard = args.binary.resolve(), args.guard.resolve()
    artifacts = args.output.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    tools = Path(__file__).resolve().parent
    fixtures = (tools / "test_linux_browser.py", tools / "test_windows_svg_pattern_tiles.py",
                Path(__file__).resolve(), tools.parent / "Tests/Browser/Native/portable-gradients.html")

    def hashes():
        return input_hashes(binary, guard) | {
            str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in fixtures
        }

    inputs = hashes()
    (artifacts / "windows-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    try:
        with tempfile.TemporaryDirectory(prefix="vox-portable-replay-") as temporary:
            capture = partial(run_guarded_capture, guard)
            check_gradient_browser(binary, artifacts, temporary, capture)
            check_rounded_image_browser(binary, artifacts, temporary, capture)
    finally:
        assert hashes() == inputs, "Windows capture inputs changed during the run"


if __name__ == "__main__":
    main()
