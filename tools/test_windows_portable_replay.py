#!/usr/bin/env python3
"""Check shared GG gradient, image, poster and canvas rendering on Windows."""

import argparse
from functools import partial
import hashlib
import json
from pathlib import Path
import tempfile

from test_linux_browser import (check_gradient_browser, check_late_canvas_draw,
                                check_rounded_image_browser, check_webgl_texture_reuse)
from test_windows_svg_pattern_tiles import input_hashes, run_guarded_capture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path, help="Windows Vox executable")
    parser.add_argument("--guard", type=Path, required=True, help="Windows job-object guard")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--canvas-only", action="store_true", help="check Canvas 2D and WebGL replay only")
    args = parser.parse_args()
    binary, guard = args.binary.resolve(), args.guard.resolve()
    artifacts = args.output.resolve()
    artifacts.mkdir(parents=True, exist_ok=True)
    tools = Path(__file__).resolve().parent
    native = tools.parent / "Tests/Browser/Native"
    fixtures = [tools / "test_linux_browser.py", tools / "test_windows_svg_pattern_tiles.py",
                Path(__file__).resolve(), native / "late-canvas.html", native / "webgl-texture-reuse.html"]
    if not args.canvas_only:
        fixtures.append(native / "portable-gradients.html")

    def hashes():
        return input_hashes(binary, guard) | {
            str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in fixtures
        }

    inputs = hashes()
    (artifacts / "windows-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n", encoding="utf-8")
    try:
        with tempfile.TemporaryDirectory(prefix="vox-portable-replay-") as temporary:
            capture = partial(run_guarded_capture, guard)
            if not args.canvas_only:
                check_gradient_browser(binary, artifacts, temporary, capture)
                check_rounded_image_browser(binary, artifacts, temporary, capture)
            check_late_canvas_draw(binary, artifacts, temporary, capture)
            check_webgl_texture_reuse(binary, artifacts, temporary, capture)
    finally:
        assert hashes() == inputs, "Windows capture inputs changed during the run"


if __name__ == "__main__":
    main()
