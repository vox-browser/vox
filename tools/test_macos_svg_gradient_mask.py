#!/usr/bin/env python3
"""Compare the shared and Quartz SVG gradient mask paths in fresh windows."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

from test_linux_browser import check_svg_mask_gradient_pixels, rendered_png_rows


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def capture_document(binary, fixture, directory, settings, options=()):
    directory.mkdir()
    profile = directory / "profile"
    profile.mkdir()
    (profile / "settings.json").write_text(json.dumps({"allow_any_site": True}))
    screenshot = directory / "document.png"
    log = directory / "browser.log"
    environment = dict(os.environ, VOX_PROFILE_DIR=str(profile), VOX_TEST_WINDOW="1",
                       LADYBIRD_CACHE_DIR=str(directory / "cache"),
                       VOX_CAPTURE_DOCUMENT_ONLY="1", LADYBIRD_SCREENSHOT_SCALE="1",
                       VOX_CAPTURE_INITIAL_VIEWPORT="0", VOX_CAPTURE_READY_SELECTOR="",
                       VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1")
    environment.update(settings)
    command = [binary, "--window-width=1024", "--window-height=712",
               "--screenshot-viewport-height=600", f"--screenshot={screenshot}", *options, fixture]
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
    return screenshot.read_bytes(), diagnostics


def capture(binary, fixture, directory, shared, *, cache=False, eager=False, copy=False,
            scroll=0, clip_raster=False, require_viewport_hit=False, scale=1):
    settings = dict(VOX_SHARED_SVG_MASK_RASTER=str(int(shared)),
                    VOX_DISABLE_SHARED_SVG_MASK_CACHE=str(int(not cache)),
                    VOX_EAGER_SHARED_SVG_MASK_BITMAP=str(int(eager)),
                    VOX_COPY_SHARED_SVG_MASK_BITMAP=str(int(copy)),
                    VOX_CLIP_SHARED_SVG_MASK_RASTER=str(int(clip_raster)),
                    LADYBIRD_SCREENSHOT_SCALE=str(scale))
    options = []
    if scroll:
        settings.update(VOX_CAPTURE_INITIAL_VIEWPORT="1", VOX_SCREENSHOT_SCROLL_STEP="12")
        options.append(f"--screenshot-scroll-y={scroll}")
    data, diagnostics = capture_document(binary, fixture, directory, settings, options)
    for mode in ("true", "false"):
        rasters = [line for line in diagnostics.splitlines()
                   if line.startswith(f"VOX_SHARED_SVG_MASK luminance={mode} ")]
        assert bool(rasters) == shared, diagnostics
        assert all(line.endswith(f"bitmap_reused={str(not copy).lower()}") for line in rasters), rasters
        hits = [line for line in diagnostics.splitlines()
                if line.startswith(f"VOX_SHARED_SVG_MASK_CACHE_HIT luminance={mode} ")]
        assert bool(hits) == cache, diagnostics
        assert all(line.endswith(f"bitmap_allocated={str(eager).lower()}") for line in hits), hits
        if clip_raster:
            assert all("viewport_crop=false" in line for line in hits), hits
        if require_viewport_hit:
            assert any("viewport_crop=true" in line for line in hits), diagnostics
    if not scroll:
        check_svg_mask_gradient_pixels(data)
    return rendered_png_rows(data)


def check_mask_mutation(binary, fixture, directory):
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="1", VOX_COPY_SHARED_SVG_MASK_BITMAP="0",
                    VOX_DISABLE_SHARED_SVG_MASK_CACHE="0", VOX_EAGER_SHARED_SVG_MASK_BITMAP="0")
    original, _ = capture_document(binary, fixture, directory / "mutation-original", settings,
                                   ["--disable-javascript"])
    settings["VOX_CAPTURE_READY_SELECTOR"] = "html[data-masks-updated=true]"
    options = ["--enable-javascript", "--js-engine=javascriptcore"]
    cached, diagnostics = capture_document(binary, fixture, directory / "mutation-cached",
                                           settings, options)
    for mode in ("true", "false"):
        keys = re.findall(rf"^VOX_SHARED_SVG_MASK luminance={mode} .* resource_key=(\d+) ",
                          diagnostics, re.MULTILINE)
        assert len(set(keys)) == 2 and "0" not in keys, diagnostics
    settings["VOX_DISABLE_SHARED_SVG_MASK_CACHE"] = "1"
    uncached, _ = capture_document(binary, fixture, directory / "mutation-uncached", settings, options)
    width, height, channels, before = rendered_png_rows(original)
    updated = rendered_png_rows(cached)
    assert updated[:3] == (width, height, channels)
    assert updated == rendered_png_rows(uncached), "Cached masks hid a gradient mutation"
    _, _, _, after = updated
    assert before[40][40 * channels:40 * channels + 3] == b"\xff\xff\xff"
    assert before[40][180 * channels:180 * channels + 3] == b"\xff\xff\xff"
    assert after[40][40 * channels:40 * channels + 3] == b"\x00\x00\xff"
    assert after[40][180 * channels:180 * channels + 3] == b"\xff\x00\x00"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    args = parser.parse_args()
    binary = args.binary.resolve()
    root = Path(__file__).resolve().parents[1]
    fixture = root / "Tests/Browser/Native/svg-gradient-masks.html"
    mutation = fixture.with_name("svg-gradient-mask-mutation.html")
    inputs = [binary, fixture, mutation]
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
        before_cache = capture(binary, fixture, directory / "scrolled-uncached", True, scroll=96)
        eager_cache = capture(binary, fixture, directory / "scrolled-eager", True,
                              cache=True, eager=True, scroll=96)
        after_cache = capture(binary, fixture, directory / "scrolled-cached", True, cache=True, scroll=96)
        copied = capture(binary, fixture, directory / "scrolled-copied", True,
                         cache=True, copy=True, scroll=96)
        assert before_cache[3] != shared, "Capture must move the document"
        assert eager_cache == before_cache, "Eager cache changed the scrolled document pixels"
        assert after_cache == before_cache, "Cached masks changed the scrolled document pixels"
        assert copied == after_cache, "Reusing the bitmap changed the scrolled document pixels"
        clipped = capture(binary, fixture, directory / "viewport-clipped", True,
                          cache=True, clip_raster=True, scroll=42)
        full = capture(binary, fixture, directory / "viewport-full", True,
                       cache=True, require_viewport_hit=True, scroll=42)
        assert clipped == full, "Reusing a partially visible mask changed the document pixels"
        clipped_2x = capture(binary, fixture, directory / "viewport-clipped-2x", True,
                             cache=True, clip_raster=True, scroll=42, scale=2)
        full_2x = capture(binary, fixture, directory / "viewport-full-2x", True,
                          cache=True, require_viewport_hit=True, scroll=42, scale=2)
        assert clipped_2x[:2] == (2048, 1200)
        assert clipped_2x == full_2x, "Reusing a partially visible mask changed the 2× document pixels"
        check_mask_mutation(binary, mutation, directory)
    assert {path: digest(path) for path in inputs} == digests
    print("PASS: macOS rendered both gradient mask modes with the shared rasterizer")


if __name__ == "__main__":
    main()
