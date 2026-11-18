#!/usr/bin/env python3
"""Compare the shared and Quartz SVG gradient mask paths in fresh windows."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from test_linux_browser import check_svg_mask_gradient_pixels, rendered_png_rows


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def capture(binary, fixture, directory, shared):
    directory.mkdir()
    profile = directory / "profile"
    profile.mkdir()
    (profile / "settings.json").write_text(json.dumps({"allow_any_site": True}))
    screenshot = directory / "document.png"
    log = directory / "browser.log"
    environment = dict(os.environ, VOX_PROFILE_DIR=str(profile), VOX_TEST_WINDOW="1",
                       LADYBIRD_CACHE_DIR=str(directory / "cache"),
                       VOX_CAPTURE_DOCUMENT_ONLY="1", VOX_SHARED_SVG_MASK_RASTER=str(int(shared)),
                       VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1")
    command = [binary, "--window-width=1024", "--window-height=712",
               "--screenshot-viewport-height=600", f"--screenshot={screenshot}", fixture]
    with log.open("w") as output, subprocess.Popen(command, env=environment, stdout=output,
                                                  stderr=subprocess.STDOUT) as browser:
        try:
            status = browser.wait(timeout=45)
        except subprocess.TimeoutExpired:
            browser.kill()
            browser.wait()
            raise
        print(f"Browser PID {browser.pid} exited {status}", flush=True)
    diagnostics = log.read_text(errors="replace")
    assert status == 0, diagnostics
    for mode in ("true", "false"):
        assert (f"VOX_SHARED_SVG_MASK luminance={mode}" in diagnostics) == shared, diagnostics
    data = screenshot.read_bytes()
    check_svg_mask_gradient_pixels(data)
    return rendered_png_rows(data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    args = parser.parse_args()
    binary = args.binary.resolve()
    root = Path(__file__).resolve().parents[1]
    fixture = root / "Tests/Browser/Native/svg-gradient-masks.html"
    inputs = [binary, fixture]
    avif_library = binary.with_name("libVoxAVIF.dylib")
    if avif_library.exists():
        inputs.append(avif_library)
    digests = {path: digest(path) for path in inputs}
    with tempfile.TemporaryDirectory(prefix="vox-svg-mask-") as temporary:
        directory = Path(temporary)
        width, height, channels, quartz = capture(binary, fixture, directory / "quartz", False)
        new_width, new_height, new_channels, shared = capture(binary, fixture, directory / "shared", True)
        assert (width, height, channels) == (new_width, new_height, new_channels)
        maximum = max(abs(a - b) for old_row, new_row in zip(quartz, shared) for a, b in zip(old_row, new_row))
        assert maximum <= 2, f"Document channels differed by up to {maximum}"
        print(f"Largest document channel difference against Quartz is {maximum}")
    assert {path: digest(path) for path in inputs} == digests
    print("PASS: macOS rendered both gradient mask modes with the shared rasterizer")


if __name__ == "__main__":
    main()
