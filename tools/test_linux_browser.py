#!/usr/bin/env python3
"""Exercise the built Linux browser, including native windows and process tabs."""

import argparse
import ctypes
import ctypes.util
import functools
import hashlib
import http.server
import json
import math
import os
import re
import select
import shutil
import signal
import ssl
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import time
import zlib


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def end_headers(self):
        # In particular, the trusted HTTPS load must not satisfy the subsequent
        # untrusted load from disk instead of checking its certificate again.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_GET(self):
        if self.path == "/keyboard":
            body = b'''<!doctype html><title>Vox keyboard navigation</title>
<style>body{margin:0;background:#394cad;color:white}h1{font:32px sans-serif;padding:24px}</style>
<h1>Address entry works</h1>'''
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/linux.html")
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            super().do_GET()


def run(command, **kwargs):
    log_path = kwargs.pop("log_path", None)
    environment = dict(kwargs.pop("env", os.environ))
    bypass = "127.0.0.1,localhost,::1," + environment.get("NO_PROXY", environment.get("no_proxy", ""))
    environment.update(NO_PROXY=bypass, no_proxy=bypass)
    try:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=kwargs.pop("timeout", 120),
                                env=environment, **kwargs)
    except subprocess.TimeoutExpired as error:
        if log_path is not None:
            output = error.output or b""
            Path(log_path).write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
        raise
    if log_path is not None:
        Path(log_path).write_text(result.stdout)
    if result.returncode:
        raise RuntimeError(f"{command!r} exited {result.returncode}:\n{result.stdout}")
    return result.stdout


def run_windowed(command, screen="1024x768x24", **kwargs):
    """Own and reap Xvfb before the runtime memory guard reaches its endpoint."""
    environment = dict(kwargs.pop("env", os.environ))
    read_fd, write_fd = os.pipe()
    server = None
    try:
        server = subprocess.Popen(["Xvfb", "-displayfd", str(write_fd), "-screen", "0",
                                   screen, "-nolisten", "tcp"], pass_fds=(write_fd,),
                                  stdout=subprocess.DEVNULL)
        os.close(write_fd)
        write_fd = None
        if not select.select([read_fd], [], [], 10)[0]:
            raise RuntimeError("Xvfb did not publish its display")
        display = os.read(read_fd, 64).decode().strip()
        if not display.isdigit():
            raise RuntimeError("Xvfb failed to initialize")
        return run(command, env=dict(environment, DISPLAY=":" + display), **kwargs)
    finally:
        os.close(read_fd)
        if write_fd is not None:
            os.close(write_fd)
        if server is not None:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=10)


def smoke_environment(directory, inherited=None):
    """Use fresh browser state and keep fixture traffic off ambient proxies."""
    directory = Path(directory)
    environment = dict(os.environ if inherited is None else inherited)
    for name in ("VOX_TAB_GROUP", "VOX_TAB_ID", "VOX_PROXY", "SSL_CERT_FILE", "SSL_CERT_DIR",
                 "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        environment.pop(name, None)
    for name, subdirectory in (("VOX_PROFILE_DIR", "profile"), ("LADYBIRD_CACHE_DIR", "cache"),
                               ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "xdg-cache"),
                               ("TMPDIR", "tmp")):
        path = directory / subdirectory
        path.mkdir(parents=True, exist_ok=True)
        environment[name] = str(path)
    (directory / "profile/settings.json").write_text(json.dumps({"enabled": False}) + "\n")
    # The update opt-out is outside VOX_PROFILE_DIR. Keep this local without
    # changing the developer's machine preference.
    (directory / "config/vox").mkdir(exist_ok=True)
    (directory / "config/vox/no-update-check").touch()
    environment.update(VOX_COOKIE_FILE="", VOX_TEST_WINDOW="1", VOX_TAB_EXIT_DIAGNOSTICS="1",
                       LIBGL_ALWAYS_SOFTWARE="1",
                       NO_PROXY="127.0.0.1,localhost,::1", no_proxy="127.0.0.1,localhost,::1")
    return environment


def require_tools():
    missing = [name for name in ("Xvfb", "xdotool", "scrot", "openssl")
               if not shutil.which(name)]
    if missing:
        raise RuntimeError("Missing Linux smoke dependencies: " + ", ".join(missing))


def unfilter_png_row(kind, row, previous, channels):
    """Reconstruct a scanline without computing unused filter predictors."""
    assert 0 <= kind <= 4, "Unsupported PNG filter"
    if kind == 1:
        for x in range(channels, len(row)):
            row[x] = (row[x] + row[x - channels]) & 255
    elif kind == 2:
        for x in range(len(row)):
            row[x] = (row[x] + previous[x]) & 255
    elif kind == 3:
        for x in range(len(row)):
            left = row[x - channels] if x >= channels else 0
            row[x] = (row[x] + (left + previous[x]) // 2) & 255
    elif kind == 4:
        for x in range(len(row)):
            a = row[x - channels] if x >= channels else 0
            b = previous[x]
            c = previous[x - channels] if x >= channels else 0
            p = a + b - c
            pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
            predictor = a if pa <= pb and pa <= pc else b if pb <= pc else c
            row[x] = (row[x] + predictor) & 255
    return row


def check_rendered_pixels(data, background=b"\x2c\xa0\x5a", size=None):
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Missing PNG signature"
    width, height, depth, kind = struct.unpack(">IIBB", data[16:26])
    assert depth == 8 and kind in (2, 6)
    if size is not None:
        assert (width, height) == size, f"Wrong captured size: {(width, height)} != {size}"
    channels = 4 if kind == 6 else 3
    compressed = bytearray()
    offset = 8
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + size])
        offset += size + 12
    raw = zlib.decompress(compressed)
    stride = width * channels
    previous = bytearray(stride)
    colored = white = edge = edge_total = 0
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        row = unfilter_png_row(filter_type, bytearray(raw[start + 1:start + 1 + stride]),
                               previous, channels)
        row_colored = row_white = 0
        for x in range(0, stride, channels):
            matches = row[x:x + 3] == background
            colored += matches
            row_colored += matches
            row_white += row[x:x + 3] == b"\xff\xff\xff"
            if x // channels >= width - 80 and height // 3 <= y < height - 80:
                edge += matches
                edge_total += 1
        # White browser chrome must not satisfy the retained document-text
        # check. Count text only on rows dominated by the fixture background.
        if row_colored > width * 0.6:
            white += row_white
        previous = row
    assert colored > width * height * 0.6, f"Missing page background: {colored} pixels"
    assert white > 200, f"Missing retained text: {white} pixels"
    assert edge > edge_total * 0.8, "The right edge was not repainted after resize/switch"


def rendered_png_rows(data):
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "Missing PNG signature"
    width, height, depth, kind = struct.unpack(">IIBB", data[16:26])
    assert depth == 8 and kind in (2, 6), "Unsupported capture format"
    channels = 4 if kind == 6 else 3
    compressed = bytearray()
    offset = 8
    while offset < len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + size])
        offset += size + 12
    raw = zlib.decompress(compressed)
    stride = width * channels
    previous = bytearray(stride)
    rows = []
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        assert filter_type <= 4
        row = unfilter_png_row(filter_type, bytearray(raw[start + 1:start + 1 + stride]),
                               previous, channels)
        rows.append(bytes(row))
        previous = row
    return width, height, channels, rows


def check_gradient_pixels(data):
    width, _, channels, rows = rendered_png_rows(data)
    assert width == 1024

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    # The header's stacking context paints after the large gradients.
    page_top = next((y - 12 for y in range(150) if pixel(30, y) == b"\xea\x70\xb5"), None)
    assert page_top is not None, "Positioned header vanished after gradient replay"
    assert pixel(310, page_top + 260) == b"\x45\xef\x97", "Gradient covered or dropped the card's foreground"
    assert pixel(64, page_top + 330) != pixel(928, page_top + 330), "Large card gradient is flat"
    assert pixel(330, page_top + 60) != pixel(510, page_top + 60), "Horizontal gradient is flat"
    assert pixel(585, page_top + 60) != pixel(585, page_top + 140), "Vertical gradient is flat"
    assert pixel(218, page_top + 16) == b"\xee\xc0\x54", "SVG contour was misplaced"
    assert pixel(234, page_top + 32) == b"\x10\x18\x20", "SVG fill covered its interior hole"
    ink = paper = 0
    for y in range(page_top + 48, page_top + 148):
        for x in range(24, 204):
            r, g, b = pixel(x, y)
            ink += r > 200 and g < 90 and b < 80
            paper += (r, g, b) == (16, 24, 32)
    assert ink > 400, "Gradient glyphs are missing"
    assert paper > 10000, "Gradient escaped the text mask"
    return rows[page_top:page_top + 530]


def check_gradient_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/portable-gradients.html"
    documents = []
    for label in ("gradients", "gradients-full-raster"):
        screenshot = artifacts / f"portable-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.pop("VOX_DISABLE_PORTABLE_GRADIENT_RAMP", None)
        environment["VOX_PORTABLE_GRADIENT_RAMP_DIAGNOSTICS"] = "1"
        full_raster = label == "gradients-full-raster"
        if full_raster:
            environment["VOX_DISABLE_PORTABLE_GRADIENT_RAMP"] = "1"
        log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                            "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                           env=environment, log_path=artifacts / f"portable-{label}.log")
        if full_raster:
            assert "VOX_GRADIENT_RAMP" not in log, log
        else:
            assert "VOX_GRADIENT_RAMP texture=200x1 destination=200x96" in log, log
            assert "VOX_GRADIENT_RAMP texture=1x96 destination=200x96" in log, log
        documents.append(check_gradient_pixels(screenshot.read_bytes()))
    assert documents[0] == documents[1], "Gradient ramps changed document pixels"
    print("PASS: clipped gradient text, foreground painting and exact gradient ramps", flush=True)


def check_web_font_pixels(data):
    _, _, channels, rows = rendered_png_rows(data)

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    paper = b"\x10\x18\x20"
    ink = b"\xe5\x2d\xb8"
    page_top = next((y for y in range(150) if pixel(225, y) == b"\xea\x70\xb5"), None)
    assert page_top is not None, "Missing web font fixture marker"

    # The author face's rectangular stems survive the left-edge crop. The
    # standard GG font does not have this arrangement of ink and gaps.
    cropped = sum(pixel(4, y) == pixel(30, y) == ink and pixel(16, y) == paper
                  for y in range(page_top + 24, page_top + 83))
    inside = sum(pixel(40, y) == pixel(59, y) == pixel(84, y) == pixel(111, y) == ink
                 and pixel(50, y) == paper
                 for y in range(page_top + 104, page_top + 163))
    assert cropped >= 20 and inside >= 20, (cropped, inside)


def check_web_font_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/portable-web-font.html"
    screenshot = artifacts / "portable-web-font.png"
    screenshot.unlink(missing_ok=True)
    run_windowed([str(binary), "--window-width=800", "--window-height=640",
                  "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
                 env=smoke_environment(Path(temporary) / "web-font"),
                 log_path=artifacts / "portable-web-font.log")
    check_web_font_pixels(screenshot.read_bytes())
    print("PASS: CSS web font glyphs and viewport-clipped text", flush=True)


def check_web_font_texture_cache(binary, artifacts, temporary):
    repo = Path(__file__).resolve().parents[1]
    fixture = repo / "Tests/Browser/Native/portable-web-font.html"
    font = repo / "Tests/Browser/Brave/resources/glyph-origin.ttf"
    page = Path(temporary) / "web-font-texture-edit.html"
    page.write_text(fixture.read_text().replace("../Brave/resources/glyph-origin.ttf", font.as_uri()) + """
<script>
let frames = 0;
function editText() {
    if (!document.fonts.check('80px Origin', 'Im')) {
        requestAnimationFrame(editText);
        return;
    }
    if (++frames === 8) {
        const target = document.querySelector('.inside');
        target.textContent = 'mI';
        target.style.color = '#27b989';
    }
    if (frames < 16) {
        requestAnimationFrame(editText);
    } else {
        document.body.setAttribute('data-text-edited', '1');
    }
}
requestAnimationFrame(editText);
</script>
""")
    documents = []
    for enabled in (False, True):
        label = f"web-font-texture-{int(enabled)}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.update(VOX_DISABLE_WEB_FONT_TEXTURE_CACHE=str(int(not enabled)),
                           VOX_WEB_FONT_SCROLL_REUSE="1",
                           VOX_WEB_FONT_TEXTURE_DIAGNOSTICS="1",
                           VOX_CAPTURE_READY_SELECTOR="body[data-text-edited]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=640",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        draws = re.findall(r"^VOX_WEB_FONT_TEXTURE cache=(hit|miss) recording=(\d+)$", log, re.MULTILINE)
        if enabled:
            hits = {generation for action, generation in draws if action == "hit"}
            uploads = {generation for action, generation in draws if action == "miss"}
            # Setting the capture-ready attribute can record the same glyphs again.
            assert len(hits & uploads) >= 2, draws
            assert draws[-1][1] in hits, draws
        else:
            assert not draws, draws
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        top = next(y for y in range(150) if rows[y][225 * channels:225 * channels + 3] == b"\xea\x70\xb5")
        text = [row[:140 * channels] for row in rows[top + 80:top + 176]]
        assert sum(row.count(b"\x27\xb9\x89") for row in text) > 100, "The edited text is missing"
        assert all(b"\xe5\x2d\xb8" not in row for row in text), "Stale texture after the live text edit"
        documents.append(rows[top:height - 24])
    assert documents[0] == documents[1], "Caching changed the document pixels"
    print("PASS: cached web font textures preserve pixels across a live text edit", flush=True)


def check_web_font_scroll_reuse(binary, artifacts, temporary, *, wide=False):
    font = Path(__file__).resolve().parents[1] / "Tests/Browser/Brave/resources/glyph-origin.ttf"
    case = "wide" if wide else "ordinary"
    page = Path(temporary) / f"scroll-web-font-{case}.html"
    repeat = 42 if wide else 3
    even_row = f"<div>{'Im' * repeat}</div>"
    odd_row = f'<div class="odd">{"mI" * repeat}</div>'
    lines = "".join(even_row if i % 2 == 0 else odd_row for i in range(31))
    page.write_text("""
<!doctype html><title>Scrolling web fonts</title>
<style>
@font-face {font-family:Origin;src:url('%s')}
body {margin:0;height:1480px;background:#101820;color:#e52db8;font:32px/44px Origin}
section {position:absolute;left:%dpx;top:24px;white-space:nowrap}
.odd {color:#45cfa6}
.clip {position:absolute;left:400px;top:1000px;width:55px;overflow:hidden}
.fractional {position:absolute;left:520px;top:1000px;transform:translate(.5px,.375px)}
.icon {position:fixed;right:32px;top:20px}
aside {position:fixed;top:0;bottom:0;right:0;width:8px;background:#093c57}
</style>
<svg class="icon" width="24" height="24"><path fill="#7bcefa" d="M1 1H23V23H1Z M6 6V18H18V6Z"/></svg>
<section>%s</section><div class="clip">mImImI</div><div class="fractional">ImImIm</div><aside></aside>
<script>
let wheels = 0;
window.addEventListener('wheel', function () {
    if (++wheels === 9)
        document.querySelector('section').style.color = '#ee8a24';
}, {passive:true});
</script>
""" % (font.as_uri(), -76 if wide else 24, lines))
    documents = []
    for enabled in (False, True):
        label = f"web-font-scroll-{case}-{int(enabled)}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.update(VOX_DISABLE_WEB_FONT_TEXTURE_CACHE="0",
                           VOX_GG_SVG="0",
                           VOX_WEB_FONT_SCROLL_REUSE=str(int(enabled)), VOX_WEB_FONT_TEXTURE_DIAGNOSTICS="1",
                           VOX_PROFILE_SCROLL="1", VOX_SCROLL_PROFILE_IDLE="0", VOX_SCROLL_PROFILE_FRAMES="31",
                           VOX_SCROLL_PROFILE_SETTLE_MS="1000")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=640",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        during = log.split("Vox scroll frame: 0 ", 1)[1].split("Vox scroll frame: 30 ", 1)[0]
        hits = during.count("VOX_WEB_FONT_SCROLL cache=hit ")
        assert (hits >= 50 if enabled else hits == 0), f"{label} reused {hits} textures"
        first_up = during.split("Vox scroll frame: 29 ", 1)[1]
        up_hits = first_up.count("VOX_WEB_FONT_SCROLL cache=hit ")
        assert (up_hits >= 5 if enabled else up_hits == 0), f"{label} reused {up_hits} textures on reversal"
        width, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        top = next(y for y in range(150)
                   if rows[y][(width - 4) * channels:(width - 4) * channels + 3] == b"\x09\x3c\x57")
        document = rows[top:height - 24]
        assert any(b"\xee\x8a\x24" in row for row in document), "The live color edit is missing"
        assert any(b"\x45\xcf\xa6" in row for row in document), "The alternate web-font rows are missing"
        assert any(b"\x7b\xce\xfa" in row for row in document), "The SVG texture is missing"
        documents.append(document)
    assert documents[0] == documents[1], "Reusing web-font textures during scrolling changed pixels"
    print(f"PASS: {case} web font textures preserve pixels while scrolling and after a live color edit", flush=True)


def check_gg_svg_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-path-fill.html"
    documents = []
    for label in ("portable-svg", "gg-svg", "gg-svg-decoded-bounds", "gg-svg-uncached", "gg-svg-fallback"):
        enabled = label != "portable-svg"
        uses_gpu = label in ("gg-svg", "gg-svg-decoded-bounds", "gg-svg-uncached")
        cache_control = {"gg-svg-decoded-bounds": "bounds", "gg-svg-uncached": "1"}.get(label, "0")
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.update(VOX_GG_SVG=str(int(enabled)), VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=cache_control)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        if label == "gg-svg-fallback":
            environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
                           env=environment, log_path=artifacts / f"{label}.log")
        assert ("VOX_GG_SVG unavailable:" in log) == (label == "gg-svg-fallback"), log
        if label == "gg-svg-fallback":
            assert log.count("VOX_GG_SVG unavailable:") == 1, log
            fallback_hits = [line for line in log.splitlines()
                             if line.startswith("VOX_CPU_SVG_FILL ") and " cache=hit " in line]
            assert fallback_hits and all(line.endswith(" bounds=hit") for line in fallback_hits), fallback_hits
        assert (" hint=hit" in log) == (label == "gg-svg"), log
        for size in ("120x80", "80x30", "42x20"):
            assert (f"VOX_GG_SVG draw={size}" in log) == uses_gpu, log
            assert (f"VOX_GG_SVG draw={size} cache=hit" in log) == (
                label in ("gg-svg", "gg-svg-decoded-bounds")), log
            assert (f"VOX_GG_SVG draw={size} cache=hit bounds=hit" in log) == (label == "gg-svg"), log
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3]

        top = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
        assert top is not None, "Missing document marker"
        top += 8
        assert pixel(22, top + 20) == b"\xff\x00\x00"
        assert pixel(45, top + 27) == b"\xff\xff\xff", "Even-odd hole was painted"
        assert pixel(45, top + 70) == b"\xff\x00\x00", "Path was flipped"
        assert pixel(95, top + 60) in (b"\x7f\x00\x80", b"\x80\x00\x7f"), "Incorrect premultiplied blend"
        assert pixel(145, top + 60) in (b"\x7f\x7f\xff", b"\x80\x80\xff")
        assert pixel(191, top + 20) == b"\x00\xaa\x00", "Transformed fill is missing"
        documents.append(rows[top:top + 100])
    assert all(document == documents[0] for document in documents[1:]), "GG changed the SVG document pixels"
    print("PASS: cached and uncached GG SVG replay and GL 4.2 fallback match the portable reference", flush=True)
    check_gg_svg_ellipses(binary, artifacts, temporary)
    check_gg_svg_mutations(binary, artifacts, temporary, fixture)
    check_gg_svg_viewport(binary, artifacts, temporary, fixture)
    check_gg_svg_strokes(binary, artifacts, temporary)
    check_cpu_svg_stroke_cache(binary, artifacts, temporary)
    check_gg_svg_non_scaling_strokes(binary, artifacts, temporary)
    check_gg_svg_dashed_strokes(binary, artifacts, temporary)
    check_gg_svg_gradient_fills(binary, artifacts, temporary)
    check_gg_svg_gradient_strokes(binary, artifacts, temporary)
    check_gg_svg_gradient_viewport(binary, artifacts, temporary)
    check_svg_gradient_group_viewport(binary, artifacts, temporary)
    check_gg_svg_radial_spread(binary, artifacts, temporary)
    check_gg_svg_repeat_point_focus(binary, artifacts, temporary)
    check_gg_svg_texture_pressure(binary, artifacts, temporary)
    check_gg_svg_image_budget(binary, artifacts, temporary)
    check_gg_svg_pad_fallback(binary, artifacts, temporary)
    check_gg_svg_spread_fallback(binary, artifacts, temporary)


def check_gg_svg_ellipses(binary, artifacts, temporary):
    page = Path(temporary) / "svg-gg-ellipses.html"
    page.write_text("""<!doctype html><title>SVG ellipse replay</title>
<style>body { margin: 0; background: white; }
header { width: 16px; height: 8px; background: #34b786; } svg { display: block; }</style>
<header></header>
<svg width="420" height="120">
  <defs><linearGradient id="ink"><stop stop-color="red"/>
    <stop offset="1" stop-color="blue"/></linearGradient></defs>
  <ellipse cx="70" cy="52" rx="56" ry="32" fill="#008844"/>
  <circle cx="220" cy="64" r="24" fill="none" stroke="#2244cc" stroke-width="8" stroke-linejoin="round"/>
  <ellipse cx="350" cy="60" rx="44" ry="25" fill="url(#ink)"/>
</svg>
""")
    portable_documents = []
    for mode in ("cpu", "gl42", "gpu"):
        label = f"{page.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        env = smoke_environment(Path(temporary) / label)
        env.pop("LADYBIRD_LAYOUT_TEST_FONT", None)
        env.pop("MESA_GL_VERSION_OVERRIDE", None)
        env.update(VOX_GG_SVG=str(int(mode != "cpu")), VOX_GG_SVG_DIAGNOSTICS="1",
                   VOX_DISABLE_GG_SVG_CACHE="0")
        if mode == "gl42":
            env["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=env, log_path=artifacts / f"{label}.log")
        prefix = "VOX_GG_SVG" if mode == "gpu" else "VOX_CPU_SVG_FILL"
        for size in ("112x64", "88x50"):
            assert f"{prefix} draw={size} cache=miss" in log, (mode, size, log)
            assert f"{prefix} draw={size} cache=hit" in log, (mode, size, log)
        stroke = "VOX_GG_SVG draw=58x58" if mode == "gpu" else "VOX_CPU_SVG_STROKE draw=58x58"
        assert stroke in log, (mode, log)
        assert ("VOX_GG_SVG unavailable:" in log) == (mode == "gl42"), log
        _, _, channels, rows = rendered_png_rows(screenshot.read_bytes())
        top = next(y for y in range(150) if rows[y][4 * channels:4 * channels + 3] == bytes.fromhex("34b786")) + 8

        def pixel(x, y):
            return rows[top + y][x * channels:x * channels + 3]

        assert pixel(30, 52) == bytes.fromhex("008844"), mode
        assert pixel(18, 24) == b"\xff\xff\xff", mode
        assert pixel(220, 40) == bytes.fromhex("2244cc") and pixel(220, 64) == b"\xff\xff\xff", mode
        left = pixel(320, 60)
        right = pixel(380, 60)
        assert left[0] > 200 and left[2] < 60 and right[2] > 200 and right[0] < 60, (mode, left, right)
        if mode != "gpu":
            portable_documents.append(rows[top:top + 120])
    assert portable_documents[0] == portable_documents[1], "GL 4.2 changed portable oval pixels"
    print("PASS: SVG oval fills and strokes use GG Canvas or the portable rasterizer", flush=True)


def check_gg_svg_radial_spread(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-radial-spread.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<script>
let frames = 0;
function moveFocalCircle() {
    if (++frames < 12) {
        requestAnimationFrame(moveFocalCircle);
        return;
    }
    document.getElementById('repeat-outer').setAttribute('fr', '12');
    document.getElementById('offset-pad').setAttribute('fx', '112.5');
    document.getElementById('tangent-circle').setAttribute('fx', '76.5');
    document.getElementById('tangent-repeat').setAttribute('spreadMethod', 'repeat');
    document.body.setAttribute('data-focal-ready', '1');
}
requestAnimationFrame(moveFocalCircle);
</script>
""")
    documents = []
    for label, disable_cache in (("cached", "0"), ("uncached", "1")):
        screenshot = artifacts / f"{fixture.stem}-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / screenshot.stem)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG="1", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=disable_cache,
                           VOX_CAPTURE_READY_SELECTOR="body[data-focal-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{screenshot.stem}.log")
        gradients = [line for line in log.splitlines() if line.startswith("VOX_GG_SVG draw=")
                     and line.endswith(" gradient=2")]
        assert any("draw=256x88 cache=miss" in line for line in gradients), log
        assert any("draw=240x88 cache=miss" in line for line in gradients), log
        assert any("draw=192x72 cache=miss" in line for line in gradients), log
        assert any("draw=192x88 cache=miss" in line for line in gradients), log
        for size in ("224x96", "208x96", "184x72", "184x88"):
            draws = [line for line in gradients if f"draw={size} " in line]
            misses = [line for line in draws if "cache=miss" in line]
            if label == "cached":
                assert len(misses) == 2 and "bounds=hit" in misses[1], log
            else:
                assert len(misses) >= 2 and len(misses) == len(draws), log

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150]) if row[4 * channels:4 * channels + 3] == b"\x34\xb7\x86")
        samples = ((112, 48, (191, 0, 64)), (132, 48, (128, 0, 128)), (144, 48, (191, 0, 64)),
                   (384, 48, (159, 127, 223)), (430, 48, (149, 127, 234)),
                   (112, 164, (255, 0, 0)), (132, 164, (159, 0, 96)), (112, 184, (123, 0, 132)),
                   (390, 188, (191, 127, 191)), (354, 140, (191, 127, 191)),
                   (60, 272, (255, 255, 255)), (76, 272, (255, 0, 0)), (100, 272, (170, 0, 85)),
                   (76, 284, (202, 0, 53)), (144, 272, (0, 0, 255)),
                   (334, 264, (255, 255, 255)), (346, 280, (223, 127, 159)),
                   (60, 360, (255, 255, 255)), (76, 360, (43, 0, 212)),
                   (100, 360, (170, 0, 85)), (148, 360, (170, 0, 85)),
                   (334, 352, (255, 255, 255)), (346, 368, (223, 127, 159)), (370, 400, (159, 127, 223)))
        for x, y, expected in samples:
            pixel = rows[marker + 8 + y][x * channels:x * channels + 3]
            assert all(abs(a - b) <= 2 for a, b in zip(pixel, expected)), (x, y, pixel, expected)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Cached radial spreads changed document pixels"
    print("PASS: GG renders SVG focal circles and spread methods through live edits", flush=True)


def check_gg_svg_repeat_point_focus(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-repeat-point-focus.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<script>
let frames = 0;
function changeStop() {
    if (++frames < 12) {
        requestAnimationFrame(changeStop);
        return;
    }
    document.getElementById('average-stop').setAttribute('stop-color', 'blue');
    document.body.setAttribute('data-average-ready', '1');
}
requestAnimationFrame(changeStop);
</script>
""")
    documents = []
    for label, disable_cache in (("cached", "0"), ("uncached", "1")):
        screenshot = artifacts / f"{fixture.stem}-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / screenshot.stem)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG="1", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=disable_cache,
                           VOX_CAPTURE_READY_SELECTOR="body[data-average-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{screenshot.stem}.log")
        draws = [line for line in log.splitlines() if line.startswith("VOX_GG_SVG draw=196x88 ")
                 and line.endswith(" gradient=2")]
        misses = [line for line in draws if "cache=miss" in line]
        if label == "cached":
            assert len(misses) == 2 and "bounds=hit" in misses[1], log
        else:
            assert len(misses) >= 2 and len(misses) == len(draws), log

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150])
                      if row[4 * channels:4 * channels + 3] == b"\x34\xb7\x86")
        row = rows[marker + 8 + 40]
        samples = ((50, (207, 175, 223)), (66, (207, 175, 223)),
                   (82, (255, 127, 127)), (100, (191, 191, 255)), (148, (191, 191, 255)))
        for x, expected in samples:
            pixel = row[x * channels:x * channels + 3]
            assert all(abs(a - b) <= 2 for a, b in zip(pixel, expected)), (x, pixel, expected)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "The cached repeating focus changed document pixels"
    print("PASS: GG averages repeating SVG point focuses and follows live stop edits", flush=True)


def check_gg_svg_texture_pressure(binary, artifacts, temporary):
    page = Path(temporary) / "svg-gg-texture-pressure.html"
    # The first 20 draws need distinct textures. The later 44 repeat the first
    # path at other integer positions, and the overlay tests submission order.
    placements = [(8 + i % 10 * 64, 8 + i // 10 * 32) for i in range(64)]
    shapes = []
    for i, (x, y) in enumerate(placements):
        width = 20 + i if i < 20 else 20
        shapes.append(f'<path d="M0 0H{width}V14H0Z" transform="translate({x} {y})" fill="url(#ramp)"/>')
    x, y = placements[19]
    shapes.append(f'<path d="M0 0H20V14H0Z" transform="translate({x} {y})" fill="#00ff00" fill-opacity=".5"/>')
    page.write_text("""<!doctype html><meta charset="utf-8"><title>GG SVG texture pressure</title>
<style>body { margin: 0; background: white } header { width: 16px; height: 8px; background: #34b786 }
svg { display: block }</style>
<header></header><svg width="648" height="232"><defs>
<linearGradient id="ramp" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="16" y2="0">
<stop offset="0" stop-color="#e03010"/><stop offset=".5" stop-color="#e03010"/>
<stop offset=".5" stop-color="#2040e0"/><stop offset="1" stop-color="#2040e0"/>
</linearGradient></defs>
""" + "\n".join(shapes) + "</svg>\n")

    documents = []
    for label, disable_cache in (("cached", "0"), ("uncached", "1")):
        screenshot = artifacts / f"svg-gg-texture-pressure-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / screenshot.stem)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG="1", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=disable_cache)
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{screenshot.stem}.log")
        draws = [line for line in log.splitlines() if line.startswith("VOX_GG_SVG draw=")
                 and line.endswith(" gradient=1")]
        assert sum("draw=39x14 cache=miss" in line and " transient=1" in line
                   for line in draws) >= 2, log
        assert any("draw=20x14 cache=hit" in line for line in draws) == (label == "cached"), log
        if label == "uncached":
            assert any("draw=20x14 cache=miss" in line and " transient=1" in line for line in draws), log

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150])
                      if row[4 * channels:4 * channels + 3] == b"\x34\xb7\x86")
        for i, (x, y) in enumerate(placements):
            row = rows[marker + 8 + y + 6]
            expected = ((112, 152, 8), (16, 160, 112)) if i == 19 else ((224, 48, 16), (32, 64, 224))
            for dx, color in zip((3, 12), expected):
                pixel = row[(x + dx) * channels:(x + dx) * channels + 3]
                assert all(abs(a - b) <= 2 for a, b in zip(pixel, color)), (i, dx, pixel, color)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Transient textures changed SVG paint order or pixels"
    print("PASS: GG renders 64 SVG gradient draws and a translucent overlay under texture pressure", flush=True)


def check_gg_svg_image_budget(binary, artifacts, temporary):
    page = Path(temporary) / "svg-gg-image-budget.html"
    # Eight 400x320 images use 1,024,000 pixels. Try one new paint before
    # placing the first image twice more. Then use 20,000 more pixels for
    # a solid image and try a 6,000-pixel crop of that image.
    opacities = (1, .5, .6, .7, .8, .9, .75, .625, .25, 1, 1)
    shapes = [f'<path d="M0 0H400V320H0Z" transform="translate({8 + i * 30} 8)" '
              f'fill="url(#ramp)" fill-opacity="{opacity}"/>'
              for i, opacity in enumerate(opacities)]
    page.write_text("""<!doctype html><meta charset="utf-8"><title>GG SVG image budget</title>
<style>body { margin: 0; background: white } header { width: 16px; height: 8px; background: #34b786 }
svg { display: block }</style>
<header></header><svg width="720" height="376"><defs>
<linearGradient id="ramp" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="320" y2="0">
<stop offset="0" stop-color="red"/><stop offset="1" stop-color="blue"/>
</linearGradient></defs>
""" + "\n".join(shapes) + """
<path d="M0 0H100V200H0Z" transform="translate(8 150)" fill="#00aa00"/>
<path d="M0 0H100V200H0Z" transform="translate(-70 150)" fill="#00aa00"/>
</svg>
""")

    for label, disable_cache, gradients_per_frame in (("cached", "0", 10), ("uncached", "1", 8)):
        screenshot = artifacts / f"svg-gg-image-budget-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / screenshot.stem)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG="1", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=disable_cache, VOX_GG_SVG_VIEWPORT_REUSE="1")
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{screenshot.stem}.log")
        draws = [line for line in log.splitlines() if line.startswith("VOX_GG_SVG draw=")]
        backing_draws = sum(line.startswith("VOX_GG_SVG draw=100x200 ") for line in draws)
        gradients = [line for line in draws if line.startswith("VOX_GG_SVG draw=400x320 ")]
        crops = [line for line in draws if line.startswith("VOX_GG_SVG draw=30x200 ")]
        assert backing_draws > 1 and len(gradients) == gradients_per_frame * backing_draws, log
        misses = sum(" cache=miss " in line for line in gradients)
        assert misses == (8 if label == "cached" else len(gradients)), log
        assert len(crops) == (backing_draws if label == "cached" else 0), log
        assert all(" cache=hit " in line and " crop=hit " in line for line in crops), log

        _, _, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150])
                      if row[4 * channels:4 * channels + 3] == b"\x34\xb7\x86")
        assert rows[marker + 8 + 344][3 * channels:3 * channels + 3] == b"\x00\xaa\x00"
        assert rows[marker + 8 + 60][694 * channels:694 * channels + 3] == b"\x00\x00\xff"
    print("PASS: SVG image budget charges distinct rasters and admits repeated placements", flush=True)


def check_gg_svg_pad_fallback(binary, artifacts, temporary):
    samples = ((11, 20, (255, 0, 0)), (32, 20, (199, 32, 88)),
               (105, 20, (127, 127, 255)), (55, 35, (255, 255, 255)),
               (196, 40, (255, 127, 127)), (212, 40, (191, 127, 191)),
               (224, 40, (127, 127, 255)))
    check_gg_svg_fallback(binary, artifacts, temporary, "svg-gg-pad-fallback", ("112x80", "104x80"), samples)


def check_gg_svg_spread_fallback(binary, artifacts, temporary):
    samples = ((52, 30, (64, 0, 191)), (100, 30, (191, 0, 64)),
               (272, 30, (191, 0, 64)), (320, 30, (64, 0, 191)),
               (60, 90, (255, 255, 255)), (76, 90, (43, 0, 212)), (148, 90, (170, 0, 85)),
               (280, 90, (255, 255, 255)), (296, 90, (212, 0, 43)), (368, 90, (85, 0, 170)),
               (50, 148, (207, 175, 223)), (82, 148, (255, 127, 127)), (148, 148, (191, 191, 255)),
               (296, 148, (159, 0, 96)), (310, 148, (128, 0, 128)), (326, 148, (128, 0, 128)))
    check_gg_svg_fallback(binary, artifacts, temporary, "svg-gg-spread-fallback", ("200x50", "200x48"), samples)


def check_gg_svg_fallback(binary, artifacts, temporary, name, extents, samples):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native" / f"{name}.html"
    fallback_documents = []
    for label in ("disabled", "gl42", "gpu"):
        screenshot = artifacts / f"{fixture.stem}-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / screenshot.stem)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(label != "disabled")), VOX_GG_SVG_DIAGNOSTICS="1")
        if label == "gl42":
            environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
                           env=environment, log_path=artifacts / f"{screenshot.stem}.log")
        assert ("VOX_GG_SVG unavailable:" in log) == (label == "gl42"), log
        for extent in extents:
            assert (f"VOX_GG_SVG draw={extent} " in log) == (label == "gpu"), log

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150])
                      if row[4 * channels:4 * channels + 3] == b"\x34\xb7\x86")
        for x, y, expected in samples:
            pixel = rows[marker + 8 + y][x * channels:x * channels + 3]
            assert all(abs(a - b) <= 2 for a, b in zip(pixel, expected)), (label, x, y, pixel, expected)
        if label != "gpu":
            fallback_documents.append(rows[marker:height - 24])
    assert fallback_documents[0] == fallback_documents[1], "OpenGL 4.2 changed fallback gradient pixels"
    print(f"PASS: {name} draws with GG disabled and on OpenGL 4.2", flush=True)


def check_gg_svg_gradient_viewport(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-gradient-viewport.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<style>#art { position: fixed; top: 0; left: 0; }</style>
<script>
let frames = 0;
function moveGradientAcrossViewport() {
    ++frames;
    if (frames === 12 || frames === 36)
        document.getElementById('art').setAttribute('style', 'top:-42px');
    if (frames === 24)
        document.getElementById('art').setAttribute('style', 'top:0');
    if (frames === 48)
        document.getElementById('art').setAttribute('style', 'top:-126px');
    if (frames === 60) {
        document.getElementById('linear').firstElementChild.setAttribute('stop-color', '#1746a8');
        document.getElementById('art').setAttribute('style', 'top:-42px');
    }
    if (frames === 72)
        document.body.setAttribute('data-gradient-viewport-ready', '1');
    else
        requestAnimationFrame(moveGradientAcrossViewport);
}
requestAnimationFrame(moveGradientAcrossViewport);
</script>
""")
    documents = []
    for label in ("rerasterized", "reused", "cpu-rerasterized", "cpu-reused"):
        gpu = not label.startswith("cpu-")
        enabled = label in ("reused", "cpu-reused")
        screenshot = artifacts / f"{fixture.stem}-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / screenshot.stem)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(gpu)), VOX_GG_SVG_DIAGNOSTICS="1", VOX_DISABLE_GG_SVG_CACHE="0",
                           VOX_GG_SVG_VIEWPORT_REUSE=str(int(enabled)),
                           VOX_CAPTURE_READY_SELECTOR="body[data-gradient-viewport-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{screenshot.stem}.log")
        prefix = "VOX_GG_SVG draw=" if gpu else "VOX_CPU_SVG_FILL draw="
        gradients = [line for line in log.splitlines() if line.startswith(prefix)
                     and " gradient=" in line]
        assert not any("crop=hit" in line for line in gradients), log
        if gpu:
            full_hits = [line for line in gradients if "draw=200x120 cache=hit bounds=hit" in line]
            assert any(" hint=hit " in line and line.endswith(" gradient=1") for line in full_hits), log
            # The radial fill shares the path bytes and extent with the linear
            # fill. Its separate paint must still select its own texture.
            assert any(" hint=hit " not in line and line.endswith(" gradient=2") for line in full_hits), log
        else:
            assert any("draw=200x120 cache=hit gradient=1 variant=hit" in line
                       for line in gradients) == enabled, log
        for height, kind in ((112, 1), (112, 2), (111, 1)):
            draws = [line for line in gradients if f"draw=200x{height} " in line
                     and f" gradient={kind}" in line]
            expected_misses = (1 if enabled else 3) + int(enabled and kind == 1)
            assert sum("cache=miss" in line for line in draws) == expected_misses, (label, height, kind, log)
            assert any("cache=hit" in line for line in draws), log
            if not gpu:
                assert any("variant=hit" in line for line in draws) == enabled, log
        for kind in (1, 2):
            assert any("draw=200x28 cache=miss" in line and f"gradient={kind}" in line.split()
                       for line in gradients), log

        width, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150])
                      if row[(width - 4) * channels:(width - 4) * channels + 3] == b"\x09\x87\x46")
        row = rows[marker + 8]
        left, middle = (row[x * channels:x * channels + 3] for x in (100, 330))
        assert left != middle and b"\xff\xff\xff" not in (left, middle)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Retaining exact gradient textures changed document pixels"
    assert documents[2] == documents[3], "Retaining exact CPU gradient textures changed document pixels"
    print("PASS: GG and CPU viewport changes reuse exact gradient textures and invalidate live stop edits", flush=True)


def check_gg_svg_gradient_fills(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-gradient-fill.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<script>
let frames = 0;
function editGradients() {
    if (++frames < 24) {
        if (frames === 12) {
            document.getElementById('endpoint').setAttribute('stop-color', '#00ff00');
            document.getElementById('radial').setAttribute('gradientTransform', 'translate(12)');
            document.getElementById('translucent').setAttribute('fill-opacity', '.5');
        }
        requestAnimationFrame(editGradients);
        return;
    }
    document.getElementById('radial').setAttribute('fr', '12');
    document.body.setAttribute('data-gradient-ready', '1');
}
requestAnimationFrame(editGradients);
</script>
""")
    documents = []
    for mode in ("cached", "uncached", "disabled", "gl42", "cpu-uncached"):
        label = f"{page.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(mode not in ("disabled", "cpu-uncached"))),
                           VOX_GG_SVG_DIAGNOSTICS="1", VOX_GG_SVG_VIEWPORT_REUSE="1",
                           VOX_DISABLE_GG_SVG_CACHE=str(int(mode in ("uncached", "cpu-uncached"))),
                           VOX_CAPTURE_READY_SELECTOR="body[data-gradient-ready]",
                           VOX_CAPTURE_INITIAL_VIEWPORT="1", VOX_SCREENSHOT_SCROLL_STEP="13")
        if mode == "gl42":
            environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=600", "--screenshot-viewport-height=600",
                            "--screenshot-scroll-y=65", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        gpu = mode in ("cached", "uncached")
        prefix = "VOX_GG_SVG draw=" if gpu else "VOX_CPU_SVG_FILL draw="
        gradients = [line for line in log.splitlines() if line.startswith(prefix)
                     and ("gradient=1" in line.split() or "gradient=2" in line.split())]
        assert ("VOX_GG_SVG unavailable:" in log) == (mode == "gl42"), log
        assert len(gradients) >= 6, log
        assert any("cache=hit" in line for line in gradients) == (mode not in ("uncached", "cpu-uncached")), log
        assert any("draw=84x35 cache=miss" in line for line in gradients), log
        if gpu:
            assert not any("crop=hit" in line for line in gradients), log
        for size, kind, variants in (("100x30", 1, 2), ("74x40", 2, 3), ("100x40", 1, 2)):
            misses = [line for line in gradients if f"draw={size} cache=miss" in line
                      and f"gradient={kind}" in line.split()]
            assert len(misses) >= variants, log
            if mode == "cached":
                assert len(misses) == variants and all("bounds=hit" in line for line in misses[1:]), log
            if mode in ("disabled", "gl42"):
                assert len(misses) == variants, (mode, size, len(misses), log)

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return tuple(rows[y][x * channels:x * channels + 3])

        marker = next((y for y in range(min(height, 150)) if pixel(4, y) == (52, 183, 134)), None)
        assert marker is not None, "Missing document marker"
        top = marker + 8
        samples = [
            (10, 26, (0, 0, 0)), (13, 26, (251, 4, 0)),  # fill over the inside half of the stroke
            (52, 26, (255, 255, 255)), (100, 26, (29, 226, 0)),  # hole and changed stop
            (178, 28, (255, 255, 255)), (189, 28, (255, 255, 255)),  # inside the focal circle
            (196, 28, (134, 178, 226)), (144, 28, (32, 113, 202)),  # transformed radial ramp and pad
            (13, 66, (255, 64, 0)), (35, 66, (255, 64, 0)),  # repeat
            (130, 66, (134, 134, 134)), (149, 66, (134, 134, 134)),  # reflect
            (52, 120, (200, 209, 242)),  # single stop with nested paint alpha
            (312, -6, (51, 133, 134)),  # scrolled gradient stays anchored to its path
        ]
        for x, y, expected in samples:
            actual = pixel(x, top + y)
            assert all(abs(a - b) <= 2 for a, b in zip(actual, expected)), (mode, x, y, actual, expected)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Cached gradient fills differ from uncached replay"
    assert documents[2] == documents[3] == documents[4], "Cached CPU gradient fill pixels changed"
    print("PASS: SVG gradient fills preserve spread, opacity, resource edits, and clipped pixels", flush=True)


def check_gg_svg_gradient_strokes(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-gradient-stroke.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<script>
let frames = 0;
function editStrokes() {
    ++frames;
    if (frames === 12) {
        document.getElementById('line-end').setAttribute('stop-color', '#00ff00');
        document.getElementById('dashed').setAttribute('stroke-opacity', '.5');
        document.getElementById('radial').setAttribute('r', '24');
        document.getElementById('fixed-width').setAttribute('gradientTransform', 'translate(4)');
    }
    if (frames === 24) {
        document.getElementById('radial').setAttribute('r', '32');
        document.getElementById('fixed-width').setAttribute('gradientTransform', 'translate(2)');
        document.getElementById('dash').setAttribute('spreadMethod', 'reflect');
    }
    if (frames < 36) {
        requestAnimationFrame(editStrokes);
        return;
    }
    document.getElementById('dash').setAttribute('spreadMethod', 'repeat');
    document.body.setAttribute('data-stroke-gradient-ready', '1');
}
requestAnimationFrame(editStrokes);
</script>
""")
    documents = []
    for mode in ("cached", "uncached", "disabled", "gl42", "cpu-uncached"):
        label = f"{page.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(mode not in ("disabled", "cpu-uncached"))),
                           VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=str(int(mode in ("uncached", "cpu-uncached"))),
                           VOX_CAPTURE_READY_SELECTOR="body[data-stroke-gradient-ready]")
        if mode == "gl42":
            environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=600", "--screenshot-viewport-height=600",
                            f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        strokes = [line for line in log.splitlines() if " stroke=1" in line and " gradient=" in line]
        assert ("VOX_GG_SVG unavailable:" in log) == (mode == "gl42"), log
        if mode in ("cached", "uncached"):
            assert any(line.endswith(" gradient=2") for line in strokes), log
            assert any(" dash=2" in line for line in strokes), log
            assert any(" non_scaling=1" in line for line in strokes), log
            assert any("cache=hit bounds=hit" in line for line in strokes) == (mode == "cached"), log
            for size in ("110x48", "142x10"):
                misses = [line for line in strokes if f"draw={size} cache=miss" in line]
                assert len(misses) >= 2, log
                if mode == "cached":
                    assert "bounds=hit" in misses[1], log
                    if size == "110x48":
                        assert len(misses) == 2, log
        else:
            assert not strokes, log
            for size, kind, edits in (("110x48", 1, 1), ("82x48", 2, 2), ("142x10", 1, 3), ("98x8", 1, 2)):
                prefix = f"VOX_CPU_SVG_STROKE draw={size} cache="
                misses = log.count(f"{prefix}miss gradient={kind}")
                hits = log.count(f"{prefix}hit gradient={kind}")
                if mode == "cpu-uncached":
                    assert misses > edits + 1 and hits == 0, (mode, size, misses, hits, log)
                else:
                    assert misses == edits + 1 and hits > 0, (mode, size, misses, hits, log)

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return tuple(rows[y][x * channels:x * channels + 3])

        marker = next((y for y in range(min(height, 150)) if pixel(4, y) == (52, 183, 134)), None)
        assert marker is not None, "Missing document marker"
        top = marker + 8
        samples = [
            (100, 20, (55, 200, 0)), (74, 34, (64, 160, 255)),  # stroke over fill
            (223, 19, (184, 32, 32)), (223, 15, (237, 244, 251)),  # fill over stroke
            (18, 94, (132, 155, 162)), (26, 94, (255, 255, 255)),  # opacity and dash gap
            (217, 86, (186, 0, 69)), (248, 86, (98, 0, 157)),
            (217, 90, (255, 255, 255)),  # transformed gradient and fixed stroke width
        ]
        for x, y, expected in samples:
            actual = pixel(x, top + y)
            assert all(abs(a - b) <= 2 for a, b in zip(actual, expected)), (mode, x, y, actual, expected)
        text_pixels = [pixel(x, top + y) for y in range(82, 132) for x in range(302, 353)]
        assert sum(g > 247 and r < 8 and b < 8 for r, g, b in text_pixels) > 20, "Missing text stroke"
        assert sum(max(rgb) < 8 for rgb in text_pixels) > 20, "Missing text fill"
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Cached gradient strokes differ from uncached replay"
    assert documents[2] == documents[3], "OpenGL 4.2 changed CPU gradient stroke pixels"
    assert documents[2] == documents[4], "Reusing gradient stroke textures changed CPU pixels"
    print("PASS: SVG gradient strokes preserve paint order, dashes, fixed width, and text on GPU and CPU", flush=True)


def check_gg_svg_strokes(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-stroke.html"
    edited = Path(temporary) / "gg-svg-stroke-edit.html"
    edited.write_text(fixture.read_text() + """
<script>
let frames = 0;
function changeCap() {
    if (++frames < 12) {
        requestAnimationFrame(changeCap);
        return;
    }
    document.getElementById('round').setAttribute('stroke-linecap', 'butt');
    document.body.setAttribute('data-stroke-ready', '1');
}
requestAnimationFrame(changeCap);
</script>
""")
    white = bytes.fromhex("ffffff")
    blue = bytes.fromhex("0000ff")
    red = bytes.fromhex("ff0000")
    cap_color = bytes.fromhex("2244cc")
    for page in (fixture, edited):
        documents = []
        for mode in ("cached", "uncached", "disabled", "gl42"):
            label = f"{page.stem}-{mode}"
            screenshot = artifacts / f"{label}.png"
            screenshot.unlink(missing_ok=True)
            environment = smoke_environment(Path(temporary) / label)
            environment.pop("MESA_GL_VERSION_OVERRIDE", None)
            environment.update(VOX_GG_SVG=str(int(mode != "disabled")), VOX_GG_SVG_DIAGNOSTICS="1",
                               VOX_DISABLE_GG_SVG_CACHE=str(int(mode == "uncached")))
            if mode == "gl42":
                environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
            script = []
            if page == edited:
                environment["VOX_CAPTURE_READY_SELECTOR"] = "body[data-stroke-ready]"
                script = ["--enable-javascript"]
            log = run_windowed([str(binary), *script, "--window-width=800", "--window-height=600",
                                "--screenshot-viewport-height=600", f"--screenshot={screenshot}",
                                str(page)], env=environment, log_path=artifacts / f"{label}.log")
            strokes = [line for line in log.splitlines() if line.startswith("VOX_GG_SVG draw=")
                       and line.endswith(" stroke=1")]
            assert ("VOX_GG_SVG unavailable:" in log) == (mode == "gl42"), log
            if mode in ("cached", "uncached"):
                assert len(strokes) >= 6, log
            else:
                assert not strokes, log
            assert any("cache=hit bounds=hit" in line for line in strokes) == (mode == "cached"), log
            if page == edited and mode == "cached":
                cap_misses = [line for line in strokes if "draw=90x50 cache=miss" in line]
                assert len(cap_misses) == 2 and "bounds=hit" in cap_misses[1], log
            _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

            def pixel(x, y):
                return rows[y][x * channels:x * channels + 3]

            marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
            assert marker is not None, "Missing document marker"
            top = marker + 8
            assert pixel(26, top + 24) == (white if page == edited else cap_color), "Incorrect round cap"
            assert pixel(24, top + 19) == white and pixel(35, top + 24) == cap_color
            assert pixel(96, top + 24) == white, "Butt cap extended past the endpoint"
            assert pixel(112, top + 24) in (b"\x7f\x7f\xff", b"\x80\x80\xff"), "Incorrect stroke alpha"
            assert pixel(170, top + 20) == bytes.fromhex("dd6600"), "Square cap is missing"
            assert pixel(32, top + 56) == bytes.fromhex("00aa00"), "Transformed curve is missing"
            assert pixel(90, top + 70) == bytes.fromhex("00aa00"), "Second contour is missing"
            assert pixel(21, top + 101) == blue, "Miter join is missing"
            assert pixel(99, top + 100) == white and pixel(101, top + 103) == blue, "Incorrect round join"
            assert pixel(29, top + 120) == blue and pixel(107, top + 120) == red, "Incorrect paint order"
            documents.append(rows[marker:top + 180])
        assert documents[0] == documents[1], "Cached stroke pixels differ from uncached replay"
        assert documents[2] == documents[3], "OpenGL 4.2 changed CPU stroke pixels"
    print("PASS: SVG stroke geometry, paint order, and live cap edits on GPU and CPU", flush=True)


def check_cpu_svg_stroke_cache(binary, artifacts, temporary):
    page = Path(temporary) / "svg-cpu-stroke-cache.html"
    page.write_text("""<!doctype html>
<meta charset="utf-8">
<title>Portable SVG stroke texture reuse</title>
<style>
  body { margin: 0; background: white; }
  header { width: 16px; height: 8px; background: #34b786; }
  svg { display: block; }
</style>
<header></header>
<svg width="140" height="64">
  <path id="stroke" d="M30 40H94" fill="none" stroke="#2244cc" stroke-width="10" stroke-linejoin="round"/>
  <path id="fill" d="M24 34H100V46H24Z" fill="none"/>
  <path id="rule" d="M104 20H132V52H104Z M112 26H124V42H112Z" fill="#008844"/>
</svg>
<script>
  const stroke = document.getElementById('stroke');
  const fill = document.getElementById('fill');
  let frame = 0;
  function overwriteStrokeTexture() {
    ++frame;
    if (frame === 12) {
      stroke.setAttribute('stroke', 'none');
      fill.setAttribute('fill', 'red');
    }
    if (frame === 24) {
      fill.setAttribute('fill', 'none');
      stroke.setAttribute('stroke', '#2244cc');
      document.getElementById('rule').setAttribute('fill-rule', 'evenodd');
    }
    if (frame === 36) {
      document.body.setAttribute('data-cache-ready', '1');
      return;
    }
    requestAnimationFrame(overwriteStrokeTexture);
  }
  requestAnimationFrame(overwriteStrokeTexture);
</script>
""")
    documents = []
    for mode in ("cached", "uncached"):
        label = f"{page.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.update(VOX_GG_SVG="0", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=str(int(mode == "uncached")),
                           VOX_CAPTURE_READY_SELECTOR="body[data-cache-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=600", "--screenshot-viewport-height=600",
                            f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        prefix = "VOX_CPU_SVG_STROKE draw=76x12 cache="
        misses = log.count(prefix + "miss")
        hits = log.count(prefix + "hit")
        if mode == "cached":
            assert misses == 2 and hits > 0, (misses, hits, log)
        else:
            assert misses > 2 and hits == 0, (misses, hits, log)
        rule = "VOX_CPU_SVG_FILL draw=28x32 cache="
        if mode == "cached":
            assert log.count(rule + "miss") == 2 and (rule + "hit") in log, log
        else:
            assert log.count(rule + "miss") > 2 and (rule + "hit") not in log, log
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3].hex()

        marker = next((y for y in range(min(height, 150)) if pixel(4, y) == "34b786"), None)
        assert marker is not None, "Missing document marker"
        assert pixel(40, marker + 48) == "2244cc", "Restored stroke kept the fill texture"
        assert pixel(25, marker + 43) == "ffffff", "Fill survived outside the stroke"
        assert pixel(108, marker + 42) == "008844", "Solid fill disappeared"
        assert pixel(116, marker + 42) == "ffffff", "Changing the fill rule kept the old texture"
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Reusing stroke textures changed CPU pixels"
    print("PASS: CPU SVG stroke texture reuse invalidates an overwritten slot", flush=True)


def check_gg_svg_non_scaling_strokes(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-non-scaling-stroke.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text().replace(' vector-effect="non-scaling-stroke"', "", 1) + """
<script>
let frames = 0;
function changeVectorEffect() {
    if (++frames < 12) {
        requestAnimationFrame(changeVectorEffect);
        return;
    }
    document.getElementById('enlarged').setAttribute('vector-effect', 'non-scaling-stroke');
    document.body.setAttribute('data-vector-effect-ready', '1');
}
requestAnimationFrame(changeVectorEffect);
</script>
""")
    documents = []
    white = bytes.fromhex("ffffff")
    blue = bytes.fromhex("154fbc")
    brown = bytes.fromhex("b94015")
    green = bytes.fromhex("098746")
    purple = bytes.fromhex("8c2fa5")
    for mode in ("cached", "uncached", "disabled", "gl42"):
        label = f"{page.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(mode != "disabled")), VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=str(int(mode == "uncached")), VOX_GG_SVG_VIEWPORT_REUSE="1",
                           VOX_CAPTURE_READY_SELECTOR="body[data-vector-effect-ready]",
                           VOX_CAPTURE_INITIAL_VIEWPORT="1", VOX_SCREENSHOT_SCROLL_STEP="13")
        if mode == "gl42":
            environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=600", "--screenshot-viewport-height=600",
                            "--screenshot-scroll-y=65", f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        strokes = [line for line in log.splitlines() if line.endswith(" stroke=1 non_scaling=1")]
        assert ("VOX_GG_SVG unavailable:" in log) == (mode == "gl42"), log
        if mode in ("cached", "uncached"):
            assert "draw=114x38 cache=miss" in log, log
            assert any("draw=102x14 cache=miss" in line for line in strokes), log
            assert any("draw=164x5" in line for line in strokes), log
            assert any("draw=164x5 cache=hit bounds=hit crop=hit" in line for line in strokes) == (mode == "cached"), log
        else:
            assert not strokes, log
        assert any("cache=hit bounds=hit" in line for line in strokes) == (mode == "cached"), log
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3]

        top = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
        assert top is not None, "Missing document marker"
        assert pixel(21, top + 40) == blue, "Non-scaling round cap is missing"
        assert pixel(48, top + 44) == blue and pixel(48, top + 49) == white, "Stroke widened under scale"
        assert pixel(170, top + 50) == brown and pixel(228, top + 68) == brown, "Stroke narrowed under scale"
        assert pixel(255, top + 114) == green and pixel(252, top + 123) == white, "Skewed stroke is incorrect"
        assert pixel(360, top + 2) == purple and pixel(360, top + 7) == white, "Visible edge was culled"
        # The bottom 24px status bar includes live RAM usage.
        documents.append(rows[top:height - 24])
    assert documents[0] == documents[1], "Cached non-scaling strokes differ from uncached replay"
    assert documents[2] == documents[3], "OpenGL 4.2 changed CPU non-scaling stroke pixels"
    print("PASS: SVG non-scaling stroke width, live vector effect, and viewport edge on GPU and CPU", flush=True)


def check_gg_svg_dashed_strokes(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gg-dashed-stroke.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<script>
let frames = 0;
function changeDashes() {
    if (++frames < 12) {
        requestAnimationFrame(changeDashes);
        return;
    }
    document.getElementById('offset').setAttribute('stroke-dashoffset', '3');
    document.getElementById('intervals').setAttribute('stroke-dasharray', '10 9');
    document.body.setAttribute('data-dashes-ready', '1');
}
requestAnimationFrame(changeDashes);
</script>
""")
    documents = []
    white = "ffffff"
    blue = "154fbc"
    brown = "b94015"
    green = "098746"
    purple = "8c2fa5"
    for mode in ("cached", "uncached", "disabled", "gl42"):
        label = f"{page.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(mode != "disabled")), VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=str(int(mode == "uncached")),
                           VOX_CAPTURE_READY_SELECTOR="body[data-dashes-ready]")
        if mode == "gl42":
            environment["MESA_GL_VERSION_OVERRIDE"] = "4.2"
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=600", "--screenshot-viewport-height=600",
                            f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        strokes = [line for line in log.splitlines() if line.endswith(" dash=2")]
        assert any("cache=hit bounds=hit" in line for line in strokes) == (mode == "cached"), log
        assert ("VOX_GG_SVG unavailable:" in log) == (mode == "gl42"), log
        if mode in ("cached", "uncached"):
            assert len(strokes) >= 7 and any("non_scaling=1" in line for line in strokes), log
            for size in ("126x6", "130x6"):
                misses = [line for line in strokes if f"draw={size} cache=miss" in line]
                assert len(misses) >= 2, log
                if mode == "cached":
                    assert len(misses) == 2 and "bounds=hit" in misses[1], log
        else:
            assert not strokes, log

        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3].hex()

        marker = next((y for y in range(min(height, 150)) if pixel(4, y) == "34b786"), None)
        assert marker is not None, "Missing document marker"
        top = marker + 8
        samples = [
            (14, 20, blue), (20, 20, white), (26, 20, blue),  # pathLength and phase edit
            (21, 40, brown), (25, 40, white),  # interval edit
            (16, 80, green), (24, 74, white), (113, 88, green), (129, 88, white),
            (13, 108, purple), (30, 94, white),  # elliptical arc
            (12, 134, blue), (20, 134, white), (28, 134, blue),  # round zero-length dashes
            (164, 120, green), (172, 120, white), (181, 120, green), (164, 126, white),
            (186, 15, blue), (193, 17, "be2020"), (202, 14, white),  # closed path and paint order
        ]
        for x, y, expected in samples:
            assert pixel(x, top + y) == expected, (mode, x, y, pixel(x, top + y), expected)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Cached dashed strokes differ from uncached replay"
    assert documents[2] == documents[3], "OpenGL 4.2 changed CPU dashed stroke pixels"
    print("PASS: SVG dashes, curves, and live dash edits on GPU and CPU", flush=True)


def check_gg_svg_mutations(binary, artifacts, temporary, fixture):
    page = Path(temporary) / "gg-svg-mutations.html"
    page.write_text(fixture.read_text() + """
<script>
let frames = 0;
function changePaths() {
    if (++frames < 12) {
        requestAnimationFrame(changePaths);
        return;
    }
    const paths = document.querySelectorAll('path');
    paths[0].setAttribute('d', 'M12 8H132V88H12Z M72 18H102V38H72Z');
    paths[1].setAttribute('fill', '#0f0');
    paths[2].setAttribute('transform', 'translate(170 38)');
    const svg = paths[0].parentNode;
    svg.appendChild(paths[0]);
    const duplicate = paths[2].cloneNode(true);
    duplicate.setAttribute('transform', 'translate(170 64)');
    svg.appendChild(duplicate);
    document.body.setAttribute('data-ready', '1');
}
requestAnimationFrame(changePaths);
</script>
""")
    documents = []
    for label, disable_cache in (("cached", "0"), ("uncached", "1")):
        screenshot = artifacts / f"gg-svg-mutations-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / f"gg-svg-mutations-{label}")
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG="1", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=disable_cache,
                           VOX_CAPTURE_READY_SELECTOR="body[data-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=600", "--screenshot-viewport-height=600",
                            f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"gg-svg-mutations-{label}.log")
        assert log.count("draw=120x80 cache=miss") >= 2, log
        assert log.count("draw=80x30 cache=miss") >= 2, log
        if label == "cached":
            assert log.count("draw=42x20 cache=miss") == 1, "Reordered path lost its retained texture"
            assert log.count("draw=120x80 cache=miss bounds=miss") >= 2, "Path edit reused the old bounds"
            assert "draw=80x30 cache=miss bounds=hit" in log, "A paint-only change discarded geometry"
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3]

        marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
        assert marker is not None, "Missing document marker"
        top = marker + 8
        assert pixel(45, top + 27) == b"\xff\x00\x00", "The old SVG hole was retained"
        assert pixel(88, top + 27) == b"\xff\xff\xff", "The new SVG hole is missing"
        assert pixel(95, top + 60) == b"\xff\x00\x00", "The original paint order was retained"
        assert pixel(145, top + 60) in (b"\x7f\xff\x7f", b"\x80\xff\x80"), "The old fill color was retained"
        assert pixel(191, top + 20) == b"\xff\xff\xff" and pixel(191, top + 48) == b"\x00\xaa\x00"
        assert pixel(191, top + 74) == b"\x00\xaa\x00", "The duplicated path is missing"
        documents.append(rows[top:top + 100])
    assert documents[0] == documents[1], "Cached SVG mutations differ from uncached replay"
    print("PASS: SVG texture reuse follows edits and preserves reordered and repeated draws", flush=True)


def check_gg_svg_viewport(binary, artifacts, temporary, fixture):
    page = Path(temporary) / "gg-svg-viewport.html"
    page.write_text(fixture.read_text().replace("</svg>", """
  <path fill="#574faa" fill-opacity=".67" transform="translate(196 16) rotate(7)"
        d="M0 4C5 0 26 0 25 47 Q27 64 13 73 Q0 71 0 4 Z"/>
</svg>
<style>
  body { min-height: 1400px; }
  #marker { position: fixed; inset: 0 0 auto auto; width: 12px; height: 4px; background: #098746; }
  #side { position: fixed; left: 10px; top: 69px; }
  #off-grid { position: fixed; left: 10px; top: 85px; }
  #expanding { position: fixed; left: -65px; top: 94px; }
</style>
<div id="marker"></div>
<svg id="side" width="120" height="20">
  <path fill="#1166dd" d="M5 3H105V15H5Z"/>
</svg>
<svg id="off-grid" width="120" height="10">
  <path fill="#eea009" d="M5 1H105V9H5Z"/>
</svg>
<svg id="expanding" width="120" height="8">
  <path fill="#226644" d="M5 1H105V7H5Z"/>
</svg>
<script>
let frames = 0;
function moveAcrossLeftEdge() {
    if (++frames < 12) {
        requestAnimationFrame(moveAcrossLeftEdge);
        return;
    }
    document.getElementById('side').setAttribute('style', 'left:-55px');
    document.getElementById('off-grid').setAttribute('style', 'left:-55px; transform:translateX(-.25px)');
    document.getElementById('expanding').setAttribute('style', 'left:-45px');
    document.body.setAttribute('data-viewport-ready', '1');
}
requestAnimationFrame(moveAcrossLeftEdge);
</script>"""))
    documents = []
    for label in ("rerasterized", "reused", "cpu-rerasterized", "cpu-reused"):
        gpu = not label.startswith("cpu-")
        reuse = label in ("reused", "cpu-reused")
        screenshot = artifacts / f"gg-svg-viewport-{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / f"gg-svg-viewport-{label}")
        environment.pop("MESA_GL_VERSION_OVERRIDE", None)
        environment.update(VOX_GG_SVG=str(int(gpu)), VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE="0",
                           VOX_GG_SVG_VIEWPORT_REUSE=str(int(reuse)),
                           VOX_CAPTURE_INITIAL_VIEWPORT="1", VOX_SCREENSHOT_SCROLL_STEP="13",
                           VOX_CAPTURE_READY_SELECTOR="body[data-viewport-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", "--screenshot-scroll-y=65",
                            f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"gg-svg-viewport-{label}.log")
        assert "draw=120x80 cache=miss" in log, log
        assert ("crop=hit" in log) == reuse, log
        if gpu:
            assert ("draw=50x12 cache=hit bounds=hit crop=hit" in log) == reuse, log
        else:
            assert ("draw=50x12 cache=hit gradient=0 crop=hit" in log) == reuse, log
            assert "draw=50x8 cache=miss gradient=0" in log, log
            assert "draw=60x6 cache=miss gradient=0" in log, log
            assert not any("crop=hit" in line and ("draw=50x8 " in line or "draw=60x6 " in line)
                           for line in log.splitlines()), log
        width, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3]

        top = next((y for y in range(min(height, 150)) if pixel(width - 4, y) == b"\x09\x87\x46"), None)
        assert top is not None, "Missing viewport marker"
        assert pixel(22, top + 12) == b"\xff\x00\x00", "The cropped SVG is missing"
        assert pixel(22, top + 40) == b"\xff\xff\xff", "The viewport did not scroll"
        assert pixel(12, top + 77) == b"\x11\x66\xdd", "The left crop is missing"
        assert pixel(65, top + 77) == b"\xff\xff\xff", "The SVG did not move across the left edge"
        documents.append(rows[top:top + 100])
    assert documents[0] == documents[1], "Cropped texture replay changed document pixels"
    assert documents[2] == documents[3], "Cropped CPU texture replay changed document pixels"
    print("PASS: GPU and CPU SVG viewport crops preserve their document pixels", flush=True)


def check_svg_opacity_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-opacity-groups.html"
    screenshot = artifacts / "portable-svg-opacity.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-opacity")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_OPACITY", None)
    environment["VOX_PORTABLE_SVG_OPACITY_DIAGNOSTICS"] = "1"
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                       env=environment, log_path=artifacts / "portable-svg-opacity.log")
    assert "VOX_SVG_OPACITY paths=2 texture=144x72" in log, log
    assert "VOX_SVG_OPACITY paths=2 texture=804x50" not in log, log
    _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    top = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert top is not None, "Missing document marker"
    red = pixel(20, top + 56)
    blue = pixel(128, top + 56)
    assert red in (b"\xff\x7f\x7f", b"\xff\x80\x80"), red
    assert blue in (b"\x7f\x7f\xff", b"\x80\x80\xff"), blue
    assert pixel(65, top + 56) == blue, "Overlap applied group opacity more than once"
    assert pixel(80, top + 56) == red, "Even-odd SVG hole failed to reveal the earlier path"
    assert pixel(172, top + 56) == b"\xff\xff\xff", "The scope painted outside its path bounds"
    translucent = pixel(100, top + 220)
    assert all(abs(value - expected) <= 2 for value, expected in zip(translucent, (215, 179, 195))), translucent
    for position, expected in ((200, red), (980, blue)):
        assert all(abs(value - target) <= 1 for value, target in zip(pixel(position, top + 40), expected))
    print("PASS: SVG group opacity applies once and preserves the path fill rule", flush=True)


def check_svg_clip_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-clip-groups.html"
    screenshot = artifacts / "portable-svg-clip.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-clip")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_CLIP", None)
    environment["VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS"] = "1"
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                       env=environment, log_path=artifacts / "portable-svg-clip.log")
    assert "VOX_SVG_CLIP crop=true components=1 paths=2 texture=92x57" in log, log
    assert "VOX_SVG_CLIP crop=false components=2 paths=2" in log, log
    assert "VOX_SVG_CLIP crop=false components=1 paths=1" in log, log
    _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    top = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert top is not None, "Missing document marker"
    top += 8
    white = b"\xff\xff\xff"
    assert pixel(20, top + 40) == b"\xff\x00\x00"
    assert pixel(80, top + 40) == b"\x00\x00\xff"
    assert pixel(110, top + 40) == white, "Rectangle clip leaked"
    assert pixel(132, top + 22) == white, "Circle was clipped to its bounding box"
    assert pixel(160, top + 50) == b"\xff\x00\x00"
    assert pixel(207, top + 50) == white, "Disjoint clip components filled the gap"
    assert pixel(226, top + 28) == b"\x00\x00\xff"
    assert pixel(254, top + 50) == white, "Even-odd clip hole was filled"
    assert pixel(325, top + 40) == b"\x00\xaa\x00"
    assert 70 < pixel(320, top + 40)[0] < 190, "Fractional clip edge lost coverage"
    assert pixel(430, top + 40) == b"\xff\x88\x00", "Mask affected an unclipped sibling"
    print("PASS: SVG clip bounds, curved unions, holes and fractional coverage", flush=True)


def check_svg_group_strokes_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-group-strokes.html"
    documents = []
    for gpu in (False, True):
        label = f"{fixture.stem}-{int(gpu)}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        env = smoke_environment(Path(temporary) / label)
        env.update(VOX_GG_SVG=str(int(gpu)), VOX_GG_SVG_DIAGNOSTICS="1",
                   VOX_DISABLE_GG_SVG_CACHE="0",
                   VOX_DISABLE_PORTABLE_SVG_OPACITY="0", VOX_PORTABLE_SVG_OPACITY_DIAGNOSTICS="1",
                   VOX_DISABLE_PORTABLE_SVG_CLIP="0", VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS="1",
                   VOX_DISABLE_PORTABLE_SVG_MASK="0", VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1")
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
                           env=env, log_path=artifacts / f"{label}.log")
        assert "VOX_SVG_OPACITY paths=2 " in log, log
        assert "VOX_SVG_OPACITY paths=1 " in log, log
        assert "VOX_SVG_CLIP crop=false components=1 paths=1 " in log, log
        assert "VOX_SVG_MASK luminance=false operations=1 paths=1 " in log, log
        assert "VOX_SVG_GROUP cache=hit " in log, log
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y in range(150) if rows[y][4 * channels:4 * channels + 3] == bytes.fromhex("34b786"))
        top = marker + 8

        def pixel(x, y):
            return tuple(rows[top + y][x * channels:x * channels + 3])

        red_half = (255, 127, 127)
        blue_half = (127, 127, 255)
        white = (255, 255, 255)
        blue = (0, 0, 255)
        samples = ((22, 45, red_half), (64, 45, blue_half), (125, 45, blue_half), (130, 45, white),
                   (168, 45, red_half), (159, 45, blue_half),
                   (280, 42, blue), (295, 42, white), (260, 42, white), (332, 42, blue), (340, 42, white),
                   (375, 45, (255, 0, 0)), (353, 45, white), (399, 45, white), (375, 52, white))
        for x, y, expected in samples:
            actual = pixel(x, y)
            assert all(abs(a - b) <= 1 for a, b in zip(actual, expected)), (label, x, y, actual, expected)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "GG Canvas changed isolated stroke pixels"
    print("PASS: SVG groups preserve stroke opacity, paint order, caps, dashes, clips, and masks", flush=True)


def check_svg_group_gradient_strokes_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-group-gradient-strokes.html"
    documents = []
    for mode in ("cpu", "gg", "uncached"):
        label = f"{fixture.stem}-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        env = smoke_environment(Path(temporary) / label)
        env.update(VOX_GG_SVG=str(int(mode == "gg")), VOX_GG_SVG_DIAGNOSTICS="1",
                   VOX_DISABLE_GG_SVG_CACHE=str(int(mode == "uncached")),
                   VOX_DISABLE_PORTABLE_SVG_OPACITY="0", VOX_PORTABLE_SVG_OPACITY_DIAGNOSTICS="1",
                   VOX_DISABLE_PORTABLE_SVG_CLIP="0", VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS="1",
                   VOX_DISABLE_PORTABLE_SVG_MASK="0", VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1",
                   VOX_CAPTURE_READY_SELECTOR="body[data-gradient-stroke-ready]")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800", "--window-height=600",
                            "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
                           env=env, log_path=artifacts / f"{label}.log")
        assert log.count("VOX_SVG_OPACITY paths=2 ") >= 2, log
        assert "VOX_SVG_OPACITY paths=1 " in log, log
        assert "VOX_SVG_CLIP crop=false components=1 paths=1 " in log, log
        assert "VOX_SVG_MASK luminance=false operations=1 paths=1 " in log, log
        assert ("VOX_SVG_GROUP cache=hit " in log) == (mode != "uncached"), log
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y in range(150) if rows[y][4 * channels:4 * channels + 3] == bytes.fromhex("34b786"))
        top = marker + 8
        white = (255, 255, 255)
        samples = ((22, 45, (255, 127, 127)), (56, 46, (191, 144, 175)), (112, 46, (191, 245, 201)),
                   (168, 45, (255, 127, 127)), (159, 45, (127, 231, 151)),
                   (304, 42, (0, 6, 249)), (331, 42, (0, 225, 30)), (295, 42, white), (340, 42, white),
                   (378, 45, (125, 0, 130)), (353, 45, white), (399, 45, white), (378, 52, white))
        for x, y, expected in samples:
            actual = tuple(rows[top + y][x * channels:x * channels + 3])
            assert all(abs(a - b) <= 2 for a, b in zip(actual, expected)), (label, x, y, actual, expected)
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1] == documents[2], "Gradient stroke group replay changed document pixels"
    print("PASS: isolated SVG gradient strokes preserve paint order, opacity, clipping, and live stop edits", flush=True)


def check_svg_gradient_groups_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gradient-groups.html"
    edited = Path(temporary) / "svg-gradient-groups-edited.html"
    edited.write_text(fixture.read_text() + """
<script>
let frame = 0;
function editGradient() {
    if (++frame === 12)
        document.getElementById('blue').firstElementChild.setAttribute('stop-color', '#f00');
    if (frame === 24)
        document.body.setAttribute('data-gradient-edit', 'ready');
    else
        requestAnimationFrame(editGradient);
}
requestAnimationFrame(editGradient);
</script>
""")
    documents = []
    for mode in ("cpu", "gg", "uncached", "edited"):
        label = f"svg-gradient-groups-{mode}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        for effect in ("OPACITY", "CLIP", "MASK"):
            environment.pop(f"VOX_DISABLE_PORTABLE_SVG_{effect}", None)
            environment[f"VOX_PORTABLE_SVG_{effect}_DIAGNOSTICS"] = "1"
        environment.update(VOX_GG_SVG=str(int(mode == "gg")), VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE=str(int(mode == "uncached")))
        source = fixture
        arguments = []
        if mode == "edited":
            source = edited
            arguments.append("--enable-javascript")
            environment["VOX_CAPTURE_READY_SELECTOR"] = "body[data-gradient-edit=ready]"
        log = run_windowed([str(binary), "--window-width=800", "--window-height=600",
                            *arguments, f"--screenshot={screenshot}", str(source)],
                           env=environment, log_path=artifacts / f"{label}.log")
        assert "VOX_SVG_OPACITY paths=2" in log, log
        assert "VOX_SVG_CLIP crop=false components=1 paths=2" in log, log
        assert "VOX_SVG_MASK luminance=false" in log, log
        reused_scopes = set(re.findall(r"^VOX_SVG_GROUP cache=hit start=(\d+)", log, re.M))
        assert len(reused_scopes) == (0 if mode == "uncached" else 3), log
        _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

        def pixel(x, y):
            return rows[y][x * channels:x * channels + 3]

        marker = next(y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86")
        top = marker + 8
        white = b"\xff\xff\xff"
        if mode == "edited":
            assert log.count("VOX_SVG_MASK luminance=false") >= 2, log
            assert pixel(24, top + 220) in (
                b"\xff\x7f\x7f", b"\xff\x80\x80"), "The cached mask group kept its previous gradient stop"
            assert pixel(100, top + 220) == white, "The edited gradient escaped the mask"
            continue
        red = pixel(20, top + 56)
        blue = pixel(112, top + 56)
        assert red in (b"\xff\x7f\x7f", b"\xff\x80\x80"), red
        assert blue in (b"\x7f\x7f\xff", b"\x80\x80\xff"), blue
        assert pixel(65, top + 56) == blue, "Gradient overlap blended the group opacity twice"
        assert pixel(80, top + 56) == red, "Gradient fill lost its even-odd hole"
        dark = pixel(148, top + 56)
        assert dark[:2] == blue[:2] and dark[2] < blue[2], "The linear gradient missed the darker stop"
        assert pixel(35, top + 108) == white, "Gradient escaped the curved clip"
        assert pixel(68, top + 132) == b"\x00\xcc\x00", "The radial gradient center is missing"
        assert pixel(95, top + 145) == b"\xff\x00\x00", "The later solid fill lost paint order"
        assert pixel(116, top + 146) == white, "The clip missed the later solid fill"
        assert pixel(24, top + 220) in (b"\x7f\x7f\xff", b"\x80\x80\xff"), "Mask opacity changed"
        assert pixel(100, top + 220) == white, "The gradient escaped the alpha mask"
        documents.append(rows[top:top + 264])
    assert documents[0] == documents[1] == documents[2], "Grouped gradient replay changed pixels"
    print("PASS: SVG gradient fills preserve group opacity, curved clips and alpha masks", flush=True)


def check_svg_gradient_group_viewport(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gradient-groups.html"
    page = Path(temporary) / "svg-gradient-group-viewport.html"
    page.write_text(fixture.read_text() + """
<style>
body { min-height: 642px; }
aside { position: fixed; top: 0; right: 0; width: 12px; height: 4px; background: #093c57; }
</style>
<aside></aside>
<script>
let wheels = 0;
window.addEventListener('wheel', function () {
    if (++wheels === 101)
        document.getElementById('blue').firstElementChild.setAttribute('stop-color', '#f00');
}, {passive: true});
</script>
""")
    documents = []
    for reuse in (False, True):
        label = f"svg-gradient-group-viewport-{int(reuse)}"
        screenshot = artifacts / f"{label}.png"
        screenshot.unlink(missing_ok=True)
        environment = smoke_environment(Path(temporary) / label)
        for effect in ("OPACITY", "CLIP", "MASK"):
            environment.pop(f"VOX_DISABLE_PORTABLE_SVG_{effect}", None)
        environment.update(VOX_GG_SVG="1", VOX_GG_SVG_DIAGNOSTICS="1",
                           VOX_DISABLE_GG_SVG_CACHE="0", VOX_GG_SVG_VIEWPORT_REUSE=str(int(reuse)),
                           VOX_PROFILE_SCROLL="1", VOX_SCROLL_PROFILE_FRAMES="181",
                           VOX_SCROLL_PROFILE_SETTLE_MS="1000")
        log = run_windowed([str(binary), "--enable-javascript", "--window-width=800",
                            "--window-height=712", "--screenshot-viewport-height=600",
                            f"--screenshot={screenshot}", str(page)],
                           env=environment, log_path=artifacts / f"{label}.log")
        moves = []
        draws = []
        for line in log.splitlines():
            if line.startswith("VOX_SVG_GROUP "):
                draws.append(line)
            if line.startswith("Vox scroll frame:"):
                frame = line.split()
                fields = dict(token.split("=", 1) for token in frame[4:])
                before, after = float(fields["before_y"]), float(fields["after_y"])
                if before != after:
                    moves.append((int(frame[3]), before, after, draws))
                draws = []
        assert [(frame, before, after) for frame, before, after, _ in moves] == [
            (frame, 42 if frame % 60 else 0, 0 if frame % 60 else 42)
            for frame in range(0, 181, 30)
        ], (label, moves)
        for frame, _, _, draws in moves[1:]:
            # The stop edit invalidates the old texture at y=42 before frame 120.
            kind = "variant=hit" if reuse and frame != 120 else "cache=miss"
            assert len(draws) == 3 and all(kind in draw for draw in draws), (label, frame, draws)

        width, height, channels, rows = rendered_png_rows(screenshot.read_bytes())
        marker = next(y for y, row in enumerate(rows[:150])
                      if row[(width - 4) * channels:(width - 4) * channels + 3] == b"\x09\x3c\x57")
        row = rows[marker + 8 + 220 - 42]
        assert row[24 * channels:24 * channels + 3] in (b"\xff\x7f\x7f", b"\xff\x80\x80"), label
        assert row[100 * channels:100 * channels + 3] == b"\xff\xff\xff", label
        documents.append(rows[marker:height - 24])
    assert documents[0] == documents[1], "Reusing an exact SVG group viewport changed the document pixels"
    print("PASS: SVG groups reuse exact viewport textures and invalidate them after a live stop edit", flush=True)


def check_nested_svg_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/nested-svg-groups.html"
    screenshot = artifacts / "portable-svg-nested.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-nested")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_CLIP", None)
    environment.pop("VOX_DISABLE_PORTABLE_SVG_OPACITY", None)
    environment.update(VOX_PORTABLE_SVG_CLIP_DIAGNOSTICS="1", VOX_PORTABLE_SVG_OPACITY_DIAGNOSTICS="1")
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                       env=environment, log_path=artifacts / "portable-svg-nested.log")
    assert "VOX_SVG_CLIP crop=false components=1 paths=2" in log, log
    assert "VOX_SVG_OPACITY paths=2" in log, log
    _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert marker is not None, "Missing document marker"
    white = b"\xff\xff\xff"
    top = marker + 18
    for origin in (12, 260):
        assert pixel(origin + 14, top + 14) == white, "Nested SVG drew beyond the curved clip"
        assert pixel(origin + 30, top + 42) == b"\xff\x00\x00", "Nested SVG lost the red clip interior"
        assert pixel(origin + 54, top + 42) == b"\x00\x00\xff", "Nested SVG lost the blue clip interior"
        assert pixel(origin + 138, top + 40) in (b"\x7f\x7f\xff", b"\x80\x80\xff"), "Nested group applied opacity per path"
    assert pixel(204, top + 102) == b"\xff\x88\x00"
    assert pixel(218, top + 102) == white, "Path painted beyond the replaced image viewport"
    assert pixel(420, top + 40) == white, "Nested group painted beyond the CSS background area"
    assert pixel(465, top + 102) == white, "Path painted beyond the CSS background area"
    assert pixel(60, top + 230) == b"\xff\x00\x00", "Nested clip did not follow the scaled image"
    print("PASS: replaced and CSS background SVGs replay clip and opacity groups within their viewport", flush=True)


def check_svg_mask_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-content-masks.html"
    screenshot = artifacts / "portable-svg-mask.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-mask")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_MASK", None)
    environment["VOX_PORTABLE_SVG_MASK_DIAGNOSTICS"] = "1"
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                       env=environment, log_path=artifacts / "portable-svg-mask.log")
    assert "VOX_SVG_MASK luminance=false operations=2 paths=2" in log, log
    assert "VOX_SVG_MASK luminance=true operations=4 paths=1" in log, log
    assert "VOX_SVG_MASK luminance=false operations=1 paths=1" in log, log
    _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert marker is not None, "Missing document marker"
    top = marker + 8
    white = b"\xff\xff\xff"
    assert pixel(16, top + 24) == b"\xff\x00\x00", "Black must contribute alpha coverage"
    assert pixel(34, top + 42) == white, "Even-odd mask hole was filled"
    assert pixel(62, top + 42) == b"\xff\x00\x00", "Overlapping mask paths lost opaque coverage"
    assert pixel(140, top + 42) == white, "Mask painted beyond its region"
    assert pixel(310, top + 42) == white, "Black must be transparent in a luminance mask"
    assert pixel(340, top + 42) == b"\x00\x00\xff"
    assert pixel(375, top + 42) == b"\xff\x88\x00", "Mask affected an unclipped sibling"
    assert pixel(420, top + 24) == white
    assert pixel(430, top + 24) == b"\x00\x00\xff", "Nested SVG mask did not replay"
    for x, channel in ((90, 127), (208, 202), (240, 137), (255, 164), (421, 127)):
        y = top + (24 if x == 421 else 42)
        actual = pixel(x, y)
        assert all(abs(value - target) <= 1 for value, target in zip(actual, (channel, channel, 255))), (x, actual)
    print("PASS: SVG alpha and luminance masks, ordered coverage, and a fractional nested region", flush=True)


def check_svg_solid_rect_mask_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-solid-rect-masks.html"
    screenshot = artifacts / "portable-svg-solid-rect-mask.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-solid-rect-mask")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_MASK", None)
    environment.update(VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1", VOX_SVG_MASK_SOLID_RECTS="1")
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                       env=environment, log_path=artifacts / "portable-svg-solid-rect-mask.log")
    assert re.search(r"^VOX_SVG_MASK_RECT luminance=false alpha=(127|128)$", log, re.MULTILINE), log
    assert "VOX_SVG_MASK_RECT luminance=true alpha=44" in log, log
    assert "VOX_SVG_MASK_RECT luminance=false alpha=255" in log, log
    _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert marker is not None, "Missing document marker"
    y = marker + 48
    white, blue = b"\xff\xff\xff", b"\x00\x00\xff"
    assert pixel(15, y) == pixel(228, y) == pixel(380, y) == white
    assert pixel(50, y) in (b"\x7f\x7f\xff", b"\x80\x80\xff")
    assert all(abs(value - target) <= 1 for value, target in zip(pixel(270, y), (211, 211, 255)))
    assert pixel(425, y) == pixel(550, y) == blue
    edge = pixel(420, y)
    assert 0 < edge[0] < 255 and edge[0] == edge[1] and edge[2] == 255, edge
    assert pixel(600, y) == b"\xff\x88\x00"
    print("PASS: solid SVG rectangle masks preserve alpha, reflected luminance and fractional edges", flush=True)


def check_svg_mask_opacity_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-mask-opacity.html"
    page = Path(temporary) / fixture.name
    invisible = """      <g opacity=".003">
        <path fill="black" d="M10 10h160v100H10Z"/>
        <g opacity=".5"><path fill="black" d="M10 10h160v100H10Z"/></g>
      </g>
      <g opacity=".5"><path fill="black" d="M20 -20h10v15H20Z"/></g>
      <g opacity=".004"><path fill="black" d="M20 12h6v4H20Z"/></g>
"""
    # A short first layer forces growth for the next sibling. A curve in
    # the luminance layer exercises the full-surface path.
    page.write_text(fixture.read_text().replace(
        '      <g opacity=".5">',
        invisible + '      <g opacity=".5"><path fill="black" d="M165 92h5v4h-5Z"/></g>\n'
        '      <g opacity=".5">', 1).replace('M150 20h10v55h-10Z', 'M150 30h10v55h-10Z')
        .replace('M210 20h80v70h-80Z', 'M210 20h80q4 35 0 70h-80Z'))
    screenshot = artifacts / "portable-svg-mask-opacity.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-mask-opacity")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_MASK", None)
    environment.update(VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1", VOX_SVG_MASK_ROW_BANDS="1")
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(page)],
                       env=environment, log_path=artifacts / "portable-svg-mask-opacity.log")
    assert "VOX_SVG_MASK luminance=false operations=26 paths=2" in log, log
    assert "VOX_SVG_MASK luminance=true operations=5 paths=1" in log, log
    assert "VOX_SVG_MASK_LAYER_SKIP opacity_byte=0" in log, log
    assert "VOX_SVG_MASK_LAYER_SKIP opacity_byte=127" in log, log
    bands = ((1, 81, 6, 100), (1, 0, 91, 100), (2, 0, 67, 91), (1, 19, 57, 100), (1, 0, 100, 100))
    for depth, first, rows, parent_rows in bands:
        assert (f"VOX_SVG_MASK_LAYER depth={depth} first_row={first} rows={rows} "
                f"parent_rows={parent_rows}") in log, log
    _, height, channels, rows = rendered_png_rows(screenshot.read_bytes())

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert marker is not None, "Missing document marker"
    y = marker + 48
    half = pixel(25, y)
    assert half in (b"\x7f\x7f\xff", b"\x80\x80\xff"), half
    assert pixel(21, marker + 21) == b"\xfe\xfe\xff", "An opacity of one byte must still paint"
    assert pixel(167, marker + 101) == half, "Growing the next opacity layer erased the first sibling"
    assert pixel(50, y) == half, "Overlapping mask paths applied opacity independently"
    assert pixel(155, y) == half, "A sibling mask group retained the previous surface"
    assert pixel(25, marker + 97) == half, "Restoring a short sibling read stale rows"
    assert pixel(114, y) == pixel(104, y), "Nested overlap changed group opacity"
    assert pixel(94, y) == b"\xff\xff\xff", "Mask group painted beyond its paths"
    assert pixel(195, y) == b"\x00\x00\xff"
    assert pixel(375, y) == b"\xff\x88\x00", "Opacity affected an unclipped sibling"
    for x, channel in ((114, 192), (220, 101), (250, 37)):
        actual = pixel(x, y)
        assert all(abs(value - target) <= 1 for value, target in zip(actual, (channel, channel, 255))), (x, actual)
    print("PASS: isolated and nested SVG mask opacity with alpha and luminance", flush=True)


def check_svg_mask_gradient_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/svg-gradient-masks.html"
    screenshot = artifacts / "portable-svg-mask-gradient.png"
    screenshot.unlink(missing_ok=True)
    environment = smoke_environment(Path(temporary) / "svg-mask-gradient")
    environment.pop("VOX_DISABLE_PORTABLE_SVG_MASK", None)
    environment["VOX_PORTABLE_SVG_MASK_DIAGNOSTICS"] = "1"
    log = run_windowed([str(binary), "--window-width=1024", "--window-height=640",
                        "--screenshot-viewport-height=640", f"--screenshot={screenshot}", str(fixture)],
                       env=environment, log_path=artifacts / "portable-svg-mask-gradient.log")
    assert "VOX_SVG_MASK luminance=false operations=1 paths=2" in log, log
    assert "VOX_SVG_MASK luminance=true operations=1 paths=1" in log, log
    assert "VOX_SVG_MASK luminance=false operations=1 paths=1" in log, log
    check_svg_mask_gradient_pixels(screenshot.read_bytes())
    print("PASS: SVG gradient masks preserve stop opacity, the path, and gradient-local coordinates", flush=True)


def check_svg_mask_gradient_pixels(data):
    _, height, channels, rows = rendered_png_rows(data)

    def pixel(x, y):
        return rows[y][x * channels:x * channels + 3]

    marker = next((y for y in range(min(height, 150)) if pixel(4, y) == b"\x34\xb7\x86"), None)
    assert marker is not None, "Missing document marker"
    y = marker + 8
    white = b"\xff\xff\xff"
    assert pixel(20, y + 42) == white, "The transformed alpha ramp started too early"
    assert pixel(110, y + 16) == white, "The gradient transform also moved the mask path"
    assert pixel(143, y + 42) == white, "The gradient leaked beyond the mask region"
    assert pixel(275, y + 91) == white, "The radial shader ignored the vertical scale"
    assert pixel(375, y + 42) == b"\xff\x88\x00", "Mask affected an unclipped sibling"
    assert pixel(449, y + 32) == white, "Embedded SVG lost the object-box gradient transform"
    assert pixel(502, y + 32) == b"\x00\x00\xff"
    for x, offset, channel in ((70, 42, 151), (110, 42, 51), (275, 55, 5),
                               (310, 55, 129), (275, 70, 132), (475, 32, 128)):
        actual = pixel(x, y + offset)
        assert all(abs(value - target) <= 2 for value, target in zip(actual, (channel, channel, 255))), (x, actual)


def check_svg_mask_strips_browser(binary, artifacts, temporary, name, luminance, axes):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native" / f"{name}.html"
    page = Path(temporary) / fixture.name
    page.write_text(fixture.read_text() + """
<style>
#sample > path:first-child { fill-opacity: .65; }
#capture-marker { position: fixed; top: 0; bottom: 0; right: 0;
                  width: 3px; background: #093c57; z-index: 100; }
</style>
<div id="capture-marker"></div>
""")
    documents = {}
    for mode in ("strip", "shader"):
        for scroll in (0, 42):
            label = f"{name}-{mode}-{scroll}"
            environment = smoke_environment(Path(temporary) / label)
            environment.update(VOX_DISABLE_PORTABLE_SVG_MASK="0", VOX_PORTABLE_SVG_MASK_DIAGNOSTICS="1",
                               VOX_DISABLE_SVG_MASK_RAMP=str(int(mode == "shader")))
            screenshot = artifacts / f"{label}.png"
            screenshot.unlink(missing_ok=True)
            log = run_windowed([str(binary), "--window-width=1024", "--window-height=720",
                                "--screenshot-viewport-height=600", f"--screenshot-scroll-y={scroll}",
                                f"--screenshot={screenshot}", "--disable-javascript", str(page)],
                               env=environment, log_path=artifacts / f"{label}.log")
            assert f"VOX_SVG_MASK luminance={str(luminance).lower()} operations=1 paths=1" in log, log
            observed = set(re.findall(r"^VOX_SVG_MASK_RAMP .* vertical=(true|false)$", log, re.MULTILINE))
            assert observed == (axes if mode == "strip" else set()), log
            width, _, channels, rows = rendered_png_rows(screenshot.read_bytes())
            assert width == 1024
            marker = (width - 2) * channels
            top = next((y for y, row in enumerate(rows) if row[marker:marker + 3] == b"\x09\x3c\x57"), None)
            assert top is not None and len(rows) >= top + 600, "Missing document viewport"
            orange = [y for y in range(180)
                      if rows[top + y][500 * channels:500 * channels + 3] == b"\xff\x88\x00"]
            assert orange == [y for y in range(180) if 27 <= (y + scroll) % 180 < 67], (label, orange)
            documents[mode, scroll] = rows[top:top + 600]
    for scroll in (0, 42):
        assert documents["strip", scroll] == documents["shader", scroll], (name, scroll)
    print(f"PASS: {name} matches the full shader pixel for pixel before and after scrolling", flush=True)


def check_webgl_pixels(data):
    """Find both complete shader canvases, excluding unknown browser chrome."""
    width, height, channels, rows = rendered_png_rows(data)

    def pixel(rgb):
        return bytes(rgb) + (b"\xff" if channels == 4 else b"")
    top = pixel((255, 0, 0)) * 64 + pixel((0, 255, 0)) * 64
    bottom = pixel((0, 0, 255)) * 64 + pixel((255, 255, 0)) * 64
    for y in range(min(200, height - 63)):
        for x in range(min(8, width - 127)):
            start, end = x * channels, (x + 128) * channels
            if all(rows[y + dy][start:end] == (top if dy < 32 else bottom) for dy in range(64)):
                return
    raise AssertionError("Missing or incorrect WebGL1/WebGL2 shader presentation pixels")


def check_webgl_browser(binary, artifacts, temporary):
    fixture = Path(__file__).resolve().parents[1] / "Tests/Browser/Native/webgl-smoke.html"
    pins = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (binary, fixture, Path(__file__).resolve())}
    environment = smoke_environment(Path(temporary) / "webgl")
    audit = artifacts / "webgl-audit.json"
    screenshot = artifacts / "webgl.png"
    environment['VOX_CAPTURE_AUDIT_PATH'] = str(audit)
    screenshot.unlink(missing_ok=True)
    audit.unlink(missing_ok=True)
    run_windowed([str(binary),
         "--enable-javascript", "--window-width=800", "--window-height=600",
         "--screenshot-viewport-height=600", f"--screenshot={screenshot}", str(fixture)],
        env=environment, timeout=90, log_path=artifacts / "webgl.log")
    result = json.loads(audit.read_text())
    assert result['title'] == 'WebGL GPU smoke PASS', result
    assert result['ready'] == 'complete' and result['native_reported_error_count'] == 0
    diagnostic = next((line for line in result['javascript_diagnostics'] if line.startswith('WEBGL_GPU_SMOKE_PASS ')), '')
    assert diagnostic, "Author WebGL script did not execute"
    renderers = json.loads(diagnostic.split(' ', 1)[1])
    assert len(renderers) == 2 and all(renderer and 'ANGLE' not in renderer for renderer in renderers), renderers
    check_webgl_pixels(screenshot.read_bytes())
    assert all(hashlib.sha256(Path(name).read_bytes()).hexdigest() == value
               for name, value in pins.items()), "WebGL inputs changed during capture"
    (artifacts / "webgl-result.json").write_text(json.dumps(
        dict(passed=True, pins=pins, renderers=renderers, audit=result), indent=2) + "\n")
    print('PASS: native GLES WebGL1/WebGL2 shaders, readback and canvas presentation', flush=True)


def window_wait_seconds():
    value = os.environ.get("VOX_LINUX_TEST_WAIT_SECONDS", "20")
    try:
        seconds = float(value)
    except ValueError as error:
        raise RuntimeError("VOX_LINUX_TEST_WAIT_SECONDS must be positive, finite and at most 3600") from error
    if not math.isfinite(seconds) or not 0 < seconds <= 3600:
        raise RuntimeError("VOX_LINUX_TEST_WAIT_SECONDS must be positive, finite and at most 3600")
    return seconds


def wait_for(description, predicate, browser=None, timeout=None):
    timeout = window_wait_seconds() if timeout is None else timeout
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if browser is not None and browser.poll() is not None:
            raise AssertionError(f"Browser exited {browser.returncode} while waiting for {description}")
        result = predicate()
        if result:
            return result
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for {description}")


def process_group_alive(pid):
    try:
        os.killpg(pid, 0)
        return True
    except ProcessLookupError:
        return False


def successful_tab_exit(log, pid):
    """Require the native reaper's actual waitpid status for this one child."""
    statuses = []
    for line in log.splitlines():
        match = re.fullmatch(r"VOX_TAB_EXIT pid=(\d+) code=(-?\d+) signal=(\d+)", line)
        if match and int(match[1]) == pid:
            statuses.append((int(match[2]), int(match[3])))
    if not statuses:
        return False
    assert len(statuses) == 1, f"Duplicate exit diagnostics for tab process {pid}: {statuses}"
    code, signum = statuses[0]
    assert (code, signum) == (0, 0), f"Tab process {pid} failed: code={code} signal={signum}"
    return True


def terminate_process_group(browser):
    """Failure cleanup only; successful tests first prove a normal exit."""
    try:
        os.killpg(browser.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        browser.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    if process_group_alive(browser.pid):
        try:
            os.killpg(browser.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        browser.wait(timeout=5)


def visible_window(title, pid=None):
    command = ["xdotool", "search", "--onlyvisible", "--all"]
    if pid is not None:
        command += ["--pid", str(pid)]
    command += ["--name", title]
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=5)
    if result.returncode not in (0, 1):
        raise RuntimeError(f"X11 window search failed: {result.stderr}")
    return result.stdout.splitlines()[0] if result.returncode == 0 and result.stdout.strip() else None


def close_native_window(window):
    """Deliver the window-manager close protocol without requiring a WM."""
    class ClientMessage(ctypes.Structure):
        _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong),
                    ("send_event", ctypes.c_int), ("display", ctypes.c_void_p),
                    ("window", ctypes.c_ulong), ("message_type", ctypes.c_ulong),
                    ("format", ctypes.c_int), ("data", ctypes.c_long * 5)]

    class Event(ctypes.Union):
        _fields_ = [("client", ClientMessage), ("padding", ctypes.c_long * 24)]

    library = ctypes.util.find_library("X11")
    if library is None:
        raise RuntimeError("libX11 is required for the native close check")
    x11 = ctypes.CDLL(library)
    x11.XOpenDisplay.argtypes, x11.XOpenDisplay.restype = [ctypes.c_char_p], ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                              ctypes.c_long, ctypes.POINTER(Event)]
    x11.XSendEvent.restype = ctypes.c_int
    x11.XFlush.argtypes = x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError("Cannot open the X11 display for the native close check")
    try:
        event = Event()
        event.client.type = 33  # ClientMessage
        event.client.display = display
        event.client.window = int(window)
        event.client.message_type = x11.XInternAtom(display, b"WM_PROTOCOLS", False)
        event.client.format = 32
        event.client.data[0] = x11.XInternAtom(display, b"WM_DELETE_WINDOW", False)
        if not x11.XSendEvent(display, int(window), False, 0, ctypes.byref(event)):
            raise RuntimeError("WM_DELETE_WINDOW could not be delivered")
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay(display)


def check_window_lifecycle(binary, page, address, output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / "window.log"
    with log_path.open("w") as log:
        browser = subprocess.Popen([binary, "--enable-javascript", "--window-width=800",
                                    "--window-height=600", page], stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True)

        def wait(description, predicate):
            return wait_for(description, predicate, browser)

        def key(window, shortcut):
            run(["xdotool", "windowfocus", "--sync", window], timeout=5)
            run(["xdotool", "key", "--clearmodifiers", shortcut], timeout=5)

        def navigate(window, destination):
            key(window, "ctrl+l")
            run(["xdotool", "type", "--clearmodifiers", "--delay", "1", destination], timeout=10)
            key(window, "Return")

        def open_process_tab(window, description):
            key(window, "ctrl+t")
            child = wait(description, lambda: visible_window("^New Tab"))
            child_pid = int(run(["xdotool", "getwindowpid", child], timeout=5).strip())
            assert child_pid != browser.pid, "New tab did not start an independent process"
            assert os.getpgid(child_pid) == browser.pid, "New-tab window belongs to another launch"
            wait("original tab hidden", lambda: not visible_window("Vox keyboard navigation", browser.pid))
            return child, child_pid

        def painted(window, label, background, size):
            # --screenshot exits and disables process tabs. Read back this live
            # X11 window to cover native presentation after resize and switch.
            run(["xdotool", "windowfocus", "--sync", window], timeout=5)
            screenshot = output / f"{label}.png"
            last_error = ""

            def capture():
                nonlocal last_error
                run(["scrot", "--focused", "--overwrite", str(screenshot)], timeout=5)
                try:
                    check_rendered_pixels(screenshot.read_bytes(), background, size)
                    return True
                except AssertionError as error:
                    last_error = str(error)
                    return False

            try:
                wait(f"{label} pixels", capture)
            except AssertionError as error:
                raise AssertionError(f"{error}: {last_error}") from error

        try:
            original = wait("initial X11 window", lambda: visible_window("Vox Linux smoke", browser.pid))
            painted(original, "startup", b"\x2c\xa0\x5a", (800, 600))
            navigate(original, address)
            wait("Ctrl+L / Enter replacement", lambda: visible_window("Vox keyboard navigation", browser.pid))
            painted(original, "navigation", b"\x39\x4c\xad", (800, 600))
            print("PASS: X11 startup, native paint and keyboard document replacement", flush=True)

            run(["xdotool", "windowsize", "--sync", original, "960", "720"], timeout=5)
            painted(original, "resize", b"\x39\x4c\xad", (960, 720))
            print("PASS: X11 resize and redraw at 960x720", flush=True)

            child, child_pid = open_process_tab(original, "new process tab")
            navigate(child, page)
            wait("child document", lambda: visible_window("Vox Linux smoke", child_pid))
            painted(child, "child", b"\x2c\xa0\x5a", (960, 720))

            key(child, "ctrl+shift+Tab")
            wait("switch to original", lambda: visible_window("Vox keyboard navigation", browser.pid) == original)
            wait("child tab hidden", lambda: not visible_window("Vox Linux smoke", child_pid))
            painted(original, "switch-original", b"\x39\x4c\xad", (960, 720))
            key(original, "ctrl+Tab")
            wait("switch to child", lambda: visible_window("Vox Linux smoke", child_pid) == child)
            painted(child, "switch-child", b"\x2c\xa0\x5a", (960, 720))
            key(child, "ctrl+w")
            wait("child process reaped", lambda: not Path(f"/proc/{child_pid}").exists())
            # waitpid can remove /proc/PID before the reaper writes its status.
            # Open independently: seeking the shared stdout descriptor would
            # also move the browser writer's offset.
            wait("successful child exit status", lambda: successful_tab_exit(log_path.read_text(errors="replace"), child_pid))
            wait("original restored after close", lambda: visible_window("Vox keyboard navigation", browser.pid) == original)
            painted(original, "close-tab", b"\x39\x4c\xad", (960, 720))
            print("PASS: process-tab startup, switching, retained paint and child retirement", flush=True)

            # Keep another process alive when closing the native window, so
            # this also checks the group's shutdown path with a hidden sibling.
            sibling, sibling_pid = open_process_tab(original, "second process tab")
            key(sibling, "ctrl+shift+Tab")
            wait("original selected before group close", lambda: visible_window("Vox keyboard navigation", browser.pid) == original)
            wait("sibling hidden before group close", lambda: not visible_window("^New Tab", sibling_pid))
            assert Path(f"/proc/{sibling_pid}").exists(), "Sibling exited before the group-close check"
            # Forced termination in finally must never count as a passing close.
            close_native_window(original)
            assert browser.wait(timeout=20) == 0, "Browser did not exit normally"
            wait_for("sibling process retired by native close", lambda: not Path(f"/proc/{sibling_pid}").exists(), timeout=10)
            wait_for("all browser processes retired", lambda: not process_group_alive(browser.pid), timeout=5)
            assert not visible_window("Vox keyboard navigation", browser.pid), "Closed window remains visible"
            assert successful_tab_exit(log_path.read_text(errors="replace"), child_pid)
            print("PASS: native close and complete process-group retirement", flush=True)
        except BaseException:
            print(log_path.read_text(errors="replace"), file=sys.stderr)
            raise
        finally:
            terminate_process_group(browser)


def check_https_navigation(binary, directory, environment):
    certificate = Path(directory) / "certificate.pem"
    key = Path(directory) / "key.pem"
    run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
         "-subj", "/CN=localhost", "-addext", "subjectAltName=IP:127.0.0.1",
         "-keyout", str(key), "-out", str(certificate)])
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
        functools.partial(Handler, directory=directory))
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certificate, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        address = f"https://127.0.0.1:{server.server_port}/linux.html"
        output = run([str(binary), "--headless=layout-tree", address],
                     env=dict(environment, SSL_CERT_FILE=str(certificate)))
        assert "Linux JavaScript rendered" in output, output
        untrusted = dict(environment)
        untrusted.pop("SSL_CERT_FILE", None)
        output = run([str(binary), "--headless=layout-tree", address], env=untrusted)
        assert "Could not load page" in output, output
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


def main():
    if sys.platform != "linux":
        raise SystemExit("Run this smoke test on Linux")
    if len(sys.argv) > 1 and sys.argv[1] == "--window":
        check_window_lifecycle(*sys.argv[2:])
        return
    repo = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", nargs="?", type=Path, default=repo / "Build/linux/vox")
    parser.add_argument("--output", type=Path, default=repo / "Build/linux/browser-smoke")
    parser.add_argument("--gg-svg", action="store_true", help="check shared GG SVG replay against the portable renderer")
    args = parser.parse_args()
    wait_seconds = window_wait_seconds()
    binary = args.binary.resolve()
    artifacts = args.output.resolve()
    require_tools()
    artifacts.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="vox-linux-") as temporary:
        if args.gg_svg:
            check_gg_svg_browser(binary, artifacts, temporary)
            return
        environment = smoke_environment(temporary)
        output = run([str(binary), "--headless-smoke"], env=environment)
        assert "javascript DOM mutation: passed" in output, output
        assert "ordinary element wheel listeners: passed" in output, output
        print("PASS: headless JavaScript, DOM, events and wheel scrolling", flush=True)
        page = Path(temporary) / "linux.html"
        page.write_text('''<!doctype html><title>Vox Linux smoke</title>
<style>body{margin:0;background:#2ca05a;color:white}h1{font:32px sans-serif;padding:24px}</style>
<h1 id="result">script has not run</h1>
<script>document.getElementById('result').textContent='Linux JavaScript rendered';</script>''')
        output = run([str(binary), "--headless=layout-tree", str(page)], env=environment)
        assert "Linux JavaScript rendered" in output, output
        print("PASS: local HTML and scripted layout")
        check_webgl_browser(binary, artifacts, temporary)
        check_gradient_browser(binary, artifacts, temporary)
        check_web_font_browser(binary, artifacts, temporary)
        check_web_font_texture_cache(binary, artifacts, temporary)
        check_web_font_scroll_reuse(binary, artifacts, temporary)
        check_web_font_scroll_reuse(binary, artifacts, temporary, wide=True)
        check_svg_opacity_browser(binary, artifacts, temporary)
        check_svg_clip_browser(binary, artifacts, temporary)
        check_svg_group_strokes_browser(binary, artifacts, temporary)
        check_svg_group_gradient_strokes_browser(binary, artifacts, temporary)
        check_svg_gradient_groups_browser(binary, artifacts, temporary)
        check_nested_svg_browser(binary, artifacts, temporary)
        check_svg_mask_browser(binary, artifacts, temporary)
        check_svg_solid_rect_mask_browser(binary, artifacts, temporary)
        check_svg_mask_opacity_browser(binary, artifacts, temporary)
        check_svg_mask_gradient_browser(binary, artifacts, temporary)
        check_svg_mask_strips_browser(binary, artifacts, temporary, "svg-vertical-alpha-masks",
                                      False, {"true"})
        check_svg_mask_strips_browser(binary, artifacts, temporary, "svg-linear-luminance-masks",
                                      True, {"true", "false"})
        check_https_navigation(binary, temporary, environment)
        print("PASS: HTTPS navigation and certificate verification")
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0),
            functools.partial(Handler, directory=temporary))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            address = f"http://127.0.0.1:{server.server_port}/redirect"
            output = run([str(binary), "--enable-javascript", "--headless=layout-tree", address], env=environment)
            assert "Linux JavaScript rendered" in output, output
            print("PASS: HTTP navigation, redirect and JavaScript")
            screenshot = artifacts / "smoke.png"
            screenshot.unlink(missing_ok=True)
            run_windowed([str(binary),
                 "--enable-javascript", "--window-width=800", "--window-height=600",
                 "--screenshot-viewport-height=600", f"--screenshot={screenshot}", address],
                env=dict(environment, SCREENSHOT_SETTLE_SECONDS="0.5"))
            data = screenshot.read_bytes()
            assert data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) > 1000
            assert struct.unpack(">II", data[16:24]) == (800, 600)
            check_rendered_pixels(data)
            print(f"PASS: X11 window and 800x600 rendered screenshot ({screenshot})")
            print(run_windowed([sys.executable,
                       str(Path(__file__).resolve()), "--window", str(binary), str(page),
                       f"http://127.0.0.1:{server.server_port}/keyboard", str(artifacts)],
                      screen="1280x960x24", env=environment, timeout=max(300, 15 * wait_seconds),
                      log_path=artifacts / "window-driver.log"), end="")
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    main()
