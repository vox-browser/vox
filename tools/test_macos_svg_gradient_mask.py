#!/usr/bin/env python3
"""Compare shared and Quartz SVG mask rendering in fresh macOS windows."""
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
    # Pin the raster backing density and keep every capture on the same path.
    environment = dict(os.environ, VOX_PROFILE_DIR=str(profile), VOX_TEST_WINDOW="1",
                       LADYBIRD_CACHE_DIR=str(directory / "cache"),
                       VOX_CAPTURE_DOCUMENT_ONLY="1", LADYBIRD_SCREENSHOT_SCALE="1",
                       LADYBIRD_SCREENSHOT_DELAY_SECONDS="0.1", VOX_DISABLE_PRESENTED_CAPTURE="1",
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
            scroll=0, clip_raster=False, require_viewport_hit=False, scale=1, disable_ramp=False):
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="" if shared is None else str(int(shared)),
                    VOX_DISABLE_SHARED_SVG_MASK_CACHE=str(int(not cache)),
                    VOX_DISABLE_SVG_MASK_RAMP=str(int(disable_ramp)),
                    VOX_EAGER_SHARED_SVG_MASK_BITMAP=str(int(eager)),
                    VOX_COPY_SHARED_SVG_MASK_BITMAP=str(int(copy)),
                    VOX_CLIP_SHARED_SVG_MASK_RASTER=str(int(clip_raster)),
                    LADYBIRD_SCREENSHOT_SCALE=str(scale))
    options = []
    if scroll:
        settings.update(VOX_CAPTURE_INITIAL_VIEWPORT="1", VOX_SCREENSHOT_SCROLL_STEP="12")
        options.append(f"--screenshot-scroll-y={scroll}")
    data, diagnostics = capture_document(binary, fixture, directory, settings, options)
    if disable_ramp:
        assert "VOX_SVG_MASK_RAMP " not in diagnostics, diagnostics
    elif shared is not False:
        assert "VOX_SVG_MASK_RAMP " in diagnostics, diagnostics
    for mode in ("true", "false"):
        rasters = [line for line in diagnostics.splitlines()
                   if line.startswith(f"VOX_SHARED_SVG_MASK luminance={mode} ")]
        expected = shared is True or (shared is None and
                                      (mode == "false" or cache and not eager and not clip_raster))
        assert bool(rasters) == expected, diagnostics
        assert all(line.endswith(f"bitmap_reused={str(not copy).lower()}") for line in rasters), rasters
        hits = [line for line in diagnostics.splitlines()
                if line.startswith(f"VOX_SHARED_SVG_MASK_CACHE_HIT luminance={mode} ")]
        assert bool(hits) == (expected and cache), diagnostics
        assert all(line.endswith(f"bitmap_allocated={str(eager).lower()}") for line in hits), hits
        if clip_raster:
            assert all("viewport_crop=false" in line for line in hits), hits
        if require_viewport_hit:
            assert any("viewport_crop=true" in line for line in hits), diagnostics
    if not scroll and scale == 1:
        check_svg_mask_gradient_pixels(data)
    return rendered_png_rows(data)


def check_mask_mutation(binary, fixture, directory):
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_COPY_SHARED_SVG_MASK_BITMAP="0",
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
    settings.update(VOX_SHARED_SVG_MASK_RASTER="1", VOX_DISABLE_SHARED_SVG_MASK_CACHE="1")
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


def write_mask_cache_pressure_fixture(fixture, *, kind, count, solid_fills=1, opacity_depth=1,
                                      reflected=False):
    definitions = []
    paths = []
    for index in range(count):
        x = 8 + index % 5 * 180
        y = 12 + index // 5 * 120
        if kind == "solid-opacity":
            fill = (f'<g opacity=".625"><path fill="#{60 + index:02x}4060" fill-opacity=".75"'
                    ' d="M0 0h88v90H0Z"/><path fill="lime" fill-opacity=".5" d="M52 0h70v90H52Z"/></g>'
                    '<g opacity=".5"><path fill="white" d="M90 0h46v90H90Z"/></g>')
        elif kind == "solid":
            width = 88 if solid_fills == 2 else 136
            fill = f'<path fill="#{60 + index:02x}4060" fill-opacity=".75" d="M0 0h{width}v90H0Z"/>'
            if solid_fills == 2:
                fill += '<path fill="lime" fill-opacity=".5" d="M52 0h84v90H52Z"/>'
        else:
            if kind == "radial":
                tag = "radialGradient"
                coordinates = f'cx="{30 + index}" cy="42" r="60"'
            else:
                tag = "linearGradient"
                coordinates = f'x1="0" y1="0" x2="{50 + index}" y2="88"'
            definitions.append(f'<{tag} id="g{index}" gradientUnits="userSpaceOnUse" {coordinates}>'
                               f'<stop stop-color="white"/><stop offset="1"/></{tag}>')
            fill = f'<path fill="url(#g{index})" d="M0 0h136v90H0Z"/>'
            if kind == "opacity":
                fill = '<g opacity=".625">' * opacity_depth + fill + '</g>' * opacity_depth
            elif kind == "gradient-opacity":
                fill = (f'<g opacity=".625"><path fill="url(#g{index})" d="M0 0h88v90H0Z"/>'
                        '<path fill="lime" fill-opacity=".5" d="M52 0h70v90H52Z"/></g>'
                        '<g opacity=".5"><path fill="white" d="M90 0h46v90H90Z"/></g>')
            elif kind == "gradient":
                transform = ' transform="translate(88 0) scale(-1 1)"' if reflected else ''
                fill = (f'<path fill="url(#g{index})"{transform} d="M0 0h88v90H0Z"/>'
                        '<path fill="lime" fill-opacity=".5" d="M52 0h70v90H52Z"/>'
                        '<path fill="white" fill-opacity=".5" d="M90 0h46v90H90Z"/>')
        definitions.append(
            f'<mask id="m{index}" maskUnits="userSpaceOnUse" x="0" y="0" width="136" height="90">'
            f'{fill}</mask>'
        )
        paths.append(f'<path transform="translate({x} {y})" mask="url(#m{index})"'
                     ' fill="blue" d="M0 0h136v90H0Z"/>')
    height = ((count + 4) // 5 + 1) * 120
    fixture.write_text(f'<!doctype html><title>{kind.capitalize()} SVG mask cache pressure</title>'
                       '<style>body{margin:0;background:white}svg{display:block}</style>'
                       f'<svg width="960" height="{height}"><defs>'
                       + "".join(definitions) + "</defs>" + "".join(paths) + "</svg>")


def check_mask_cache_capacity(binary, directory, *, kind, solid_fills=1, opacity_depth=1,
                              reflected=False):
    name = f"{kind}-cache-capacity" if solid_fills == 1 else f"{kind}-two-fills-cache-capacity"
    if opacity_depth > 1:
        name = f"{kind}-{opacity_depth}-layers-cache-capacity"
    if reflected:
        name = f"reflected-{name}"
    fixture = directory / f"{name}.html"
    write_mask_cache_pressure_fixture(fixture, kind=kind, count=30, solid_fills=solid_fills,
                                      opacity_depth=opacity_depth, reflected=reflected)
    fractional_fill = kind == "gradient-opacity"
    if fractional_fill:
        # This solid fill follows the grouped fills in paint order and has a
        # fractional device edge. Its capacity fallback has a distinct label.
        mask = ('<mask id="fractional" maskUnits="userSpaceOnUse" x="0" y="0" width="30" height="48">'
                '<path fill="white" transform="translate(.25 0)" d="M0 0h28v48H0Z"/></mask>')
        target = ('<path transform="translate(908 100)" mask="url(#fractional)"'
                  ' fill="red" d="M0 0h30v48H0Z"/>')
        fixture.write_text(fixture.read_text().replace('</defs>', mask + '</defs>')
                           .replace('</svg>', target + '</svg>'))
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SHARED_SVG_MASK_CACHE="0",
                    VOX_EAGER_SHARED_SVG_MASK_BITMAP="0", VOX_COPY_SHARED_SVG_MASK_BITMAP="0",
                    VOX_CLIP_SHARED_SVG_MASK_RASTER="0", VOX_CAPTURE_INITIAL_VIEWPORT="1",
                    VOX_SCREENSHOT_SCROLL_STEP="12", LADYBIRD_SCREENSHOT_SCALE="2")
    options = ["--screenshot-scroll-y=42"]
    png, diagnostics = capture_document(binary, fixture, directory / name, settings, options)
    result = rendered_png_rows(png)
    assert result[:2] == (2048, 1200)
    sibling_groups = kind in ("solid-opacity", "gradient-opacity")
    cache_kind = "OPACITY" if sibling_groups else kind.upper()
    assert f"VOX_SHARED_SVG_MASK_SKIP_{cache_kind}_CACHE" in diagnostics, diagnostics
    if fractional_fill:
        assert "VOX_SHARED_SVG_MASK_SKIP_SOLID_CACHE" in diagnostics, diagnostics
        assert "VOX_SHARED_SVG_MASK luminance=true operations=1 " not in diagnostics, diagnostics
    assert "VOX_SHARED_SVG_MASK_CACHE_HIT luminance=true " in diagnostics, diagnostics
    operations = 2 * opacity_depth + 1 if kind == "opacity" else solid_fills
    if sibling_groups:
        operations = 7
    elif kind == "gradient":
        operations = 3
    assert f"VOX_SHARED_SVG_MASK luminance=true operations={operations} " in diagnostics, diagnostics
    if opacity_depth > 1 or sibling_groups or kind == "gradient":
        settings["VOX_SHARED_SVG_MASK_RASTER"] = "0"
        quartz, _ = capture_document(binary, fixture, directory / f"{name}-quartz", settings, options)
        control = rendered_png_rows(quartz)
        assert result[:3] == control[:3]
        maximum = max(abs(a - b) for current, previous in zip(result[3], control[3])
                      for a, b in zip(current, previous))
        assert maximum <= 2, f"Cache pressure changed {kind} channels by up to {maximum}"
        if fractional_fill:
            channels = result[2]
            first, last = 908 * 2 * channels, 938 * 2 * channels
            assert [row[first:last] for row in result[3][116:212]] == [
                row[first:last] for row in control[3][116:212]]
            inside = first + 4 * channels
            assert result[3][132][inside:inside + 3] == b"\xff\x00\x00"


def write_reflected_strip_fixture(fixture, source):
    fixture.write_text(source.read_text()
                       .replace('<path d="M21', '<path transform="translate(222 122) scale(-1 -1)" d="M21')
                       .replace('<path d="M255', '<path transform="translate(0 120) scale(1 -1)" d="M255'))


def check_svg_mask_strips(binary, fixture, directory, *, luminance, reflected=False):
    name = fixture.stem
    axes = {"true", "false"} if luminance else {"true"}
    raster = f"VOX_SHARED_SVG_MASK luminance={str(luminance).lower()} "
    pattern = r"^VOX_SVG_MASK_RAMP .* vertical=(true|false)$"
    for scale in (1, 2):
        settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SHARED_SVG_MASK_CACHE="1",
                        VOX_DISABLE_SVG_MASK_RAMP="0", VOX_CAPTURE_INITIAL_VIEWPORT="1",
                        VOX_SCREENSHOT_SCROLL_STEP="12", LADYBIRD_SCREENSHOT_SCALE=str(scale))
        options = ["--screenshot-scroll-y=42", "--disable-javascript"]
        automatic, diagnostics = capture_document(binary, fixture, directory / f"{name}-auto-{scale}",
                                                  settings, options)
        expect_quartz = reflected and not luminance and scale == 1
        strip = automatic
        if expect_quartz:
            assert "VOX_SHARED_SVG_MASK luminance=" not in diagnostics, diagnostics
            settings["VOX_SHARED_SVG_MASK_RASTER"] = "1"
            strip, diagnostics = capture_document(binary, fixture, directory / f"{name}-forced-{scale}",
                                                  settings, options)
        assert set(re.findall(pattern, diagnostics, re.MULTILINE)) == axes, diagnostics
        assert raster in diagnostics, diagnostics
        settings.update(VOX_SHARED_SVG_MASK_RASTER="1", VOX_DISABLE_SVG_MASK_RAMP="1")
        full, diagnostics = capture_document(binary, fixture, directory / f"{name}-full-{scale}",
                                             settings, options)
        assert "VOX_SVG_MASK_RAMP " not in diagnostics, diagnostics
        assert raster in diagnostics, diagnostics
        result = rendered_png_rows(strip)
        assert result[:2] == (1024 * scale, 600 * scale)
        assert result == rendered_png_rows(full), f"Shading strips changed the {scale}× pixels for {name}"
        if reflected:
            settings.update(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SHARED_SVG_MASK_CACHE="0",
                            VOX_DISABLE_SVG_MASK_RAMP="0")
            cached, diagnostics = capture_document(binary, fixture, directory / f"{name}-cached-{scale}",
                                                    settings, options)
            if expect_quartz:
                assert "VOX_SHARED_SVG_MASK luminance=" not in diagnostics, diagnostics
            else:
                assert "VOX_SHARED_SVG_MASK_CACHE_HIT " in diagnostics, diagnostics
                assert re.search(r"^VOX_SHARED_SVG_MASK(?:_CACHE_HIT)? .* viewport_crop=true ",
                                 diagnostics, re.MULTILINE), diagnostics
            assert rendered_png_rows(automatic) == rendered_png_rows(cached), (
                f"Caching changed the {scale}× pixels for {name}")

        _, _, channels, rows = result

        def pixel(x, y):
            offset = x * scale * channels
            return rows[y * scale][offset:offset + 3]

        white = b"\xff\xff\xff"
        assert pixel(18, 15) == white and pixel(449, 15) == white
        if luminance:
            left, right = (237, 201) if reflected else (201, 237)
            assert abs(pixel(30, 15)[0] - left) <= 1 and abs(pixel(190, 15)[0] - right) <= 1
            assert pixel(105, 10) == pixel(105, 50) and pixel(105, 10)[0] < pixel(30, 10)[0]
            assert pixel(300, 10) == pixel(400, 10)
        else:
            assert pixel(50, 10) == pixel(160, 10)
            top, bottom = pixel(50, 10)[0], pixel(50, 50)[0]
            assert top != bottom and (top > bottom) != reflected
        top, bottom = pixel(300, 10)[1], pixel(300, 50)[1]
        assert top != bottom and (top > bottom) == (luminance != reflected)
        if scale == 2 or reflected:
            settings["VOX_SHARED_SVG_MASK_RASTER"] = "0"
            quartz, diagnostics = capture_document(binary, fixture, directory / f"{name}-quartz-{scale}",
                                                   settings, options)
            assert "VOX_SHARED_SVG_MASK luminance=" not in diagnostics, diagnostics
            control = rendered_png_rows(quartz)
            assert result[:3] == control[:3]
            if expect_quartz:
                assert rendered_png_rows(automatic) == control, f"{name} bypassed Quartz"
            else:
                maximum = max(abs(a - b) for current, previous in zip(result[3], control[3])
                              for a, b in zip(current, previous))
                assert maximum <= 2, f"{name} channels differed from Quartz by {maximum}"
                print(f"Largest {scale}× channel difference from Quartz for {name} is {maximum}")


def check_linear_rgb_fallback(binary, fixture, directory):
    linear = directory / "linear-rgb-luminance.html"
    linear.write_text(fixture.read_text().replace("<linearGradient ", '<linearGradient color-interpolation="linearRGB" '))
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SVG_MASK_RAMP="0",
                    LADYBIRD_SCREENSHOT_SCALE="2", VOX_DISABLE_SHARED_SVG_MASK_CACHE="1")
    automatic, diagnostics = capture_document(binary, linear, directory / "linear-rgb-auto", settings)
    assert "VOX_SVG_MASK_RAMP " not in diagnostics, diagnostics
    assert "VOX_SHARED_SVG_MASK luminance=" not in diagnostics, diagnostics
    settings["VOX_SHARED_SVG_MASK_RASTER"] = "0"
    quartz, _ = capture_document(binary, linear, directory / "linear-rgb-quartz", settings)
    assert rendered_png_rows(automatic) == rendered_png_rows(quartz), "Linear RGB luminance bypassed Quartz"


def check_cached_svg_masks(binary, fixture, directory, *, operations=1, alpha_operations=None,
                           samples=()):
    name = fixture.stem
    mask_operations = (("true", operations), ("false", alpha_operations or operations))
    # Scroll far enough for both mask regions in the next row to enter the canvas edge.
    options = ["--screenshot-scroll-y=132", "--disable-javascript"]
    for scale in (1, 2):
        settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SHARED_SVG_MASK_CACHE="0",
                        VOX_EAGER_SHARED_SVG_MASK_BITMAP="0", VOX_COPY_SHARED_SVG_MASK_BITMAP="0",
                        VOX_CLIP_SHARED_SVG_MASK_RASTER="0", VOX_DISABLE_SVG_MASK_RAMP="0",
                        VOX_CAPTURE_INITIAL_VIEWPORT="1", VOX_SCREENSHOT_SCROLL_STEP="12",
                        LADYBIRD_SCREENSHOT_SCALE=str(scale))
        automatic, diagnostics = capture_document(binary, fixture, directory / f"{name}-auto-{scale}",
                                                   settings, options)
        for luminance, count in mask_operations:
            assert f"VOX_SHARED_SVG_MASK luminance={luminance} operations={count} " in diagnostics, diagnostics
            assert re.search(rf"^VOX_SHARED_SVG_MASK_CACHE_HIT luminance={luminance} .* viewport_crop=true ",
                             diagnostics, re.MULTILINE), diagnostics
        assert "VOX_SVG_MASK_RAMP " not in diagnostics, diagnostics
        settings.update(VOX_SHARED_SVG_MASK_RASTER="1", VOX_DISABLE_SHARED_SVG_MASK_CACHE="1")
        full, diagnostics = capture_document(binary, fixture, directory / f"{name}-full-{scale}",
                                             settings, options)
        for luminance, count in mask_operations:
            assert f"VOX_SHARED_SVG_MASK luminance={luminance} operations={count} " in diagnostics, diagnostics
        assert "VOX_SHARED_SVG_MASK_CACHE_HIT " not in diagnostics, diagnostics
        result = rendered_png_rows(automatic)
        assert result[:2] == (1024 * scale, 600 * scale)
        assert result == rendered_png_rows(full), f"Cached {name} changed the {scale}× document"
        _, _, channels, rows = result
        for x, y, expected in samples:
            start = x * scale * channels
            actual = rows[y * scale][start:start + 3]
            assert actual == bytes(expected), (name, scale, x, y, list(actual), expected)
        if scale == 2:
            settings["VOX_SHARED_SVG_MASK_RASTER"] = ""
            uncached, diagnostics = capture_document(binary, fixture, directory / f"{name}-auto-uncached",
                                                       settings, options)
            assert "VOX_SHARED_SVG_MASK luminance=" not in diagnostics, diagnostics
            settings["VOX_SHARED_SVG_MASK_RASTER"] = "0"
            quartz, _ = capture_document(binary, fixture, directory / f"{name}-quartz", settings, options)
            control = rendered_png_rows(quartz)
            assert rendered_png_rows(uncached) == control, f"Uncached {name} bypassed Quartz"
            assert result[:3] == control[:3]
            maximum = max(abs(a - b) for current, previous in zip(result[3], control[3])
                          for a, b in zip(current, previous))
            assert maximum <= 2, f"{name} differed from Quartz by {maximum} levels"
            print(f"Largest 2× channel difference from Quartz for {name} is {maximum}")


def check_quartz_mask_fallback(binary, fixture, directory):
    name = fixture.stem
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="", LADYBIRD_SCREENSHOT_SCALE="2",
                    VOX_DISABLE_SHARED_SVG_MASK_CACHE="0")
    automatic, diagnostics = capture_document(binary, fixture, directory / f"{name}-auto", settings)
    assert "VOX_SHARED_SVG_MASK luminance=" not in diagnostics, diagnostics
    settings["VOX_SHARED_SVG_MASK_RASTER"] = "0"
    quartz, _ = capture_document(binary, fixture, directory / f"{name}-quartz", settings)
    assert rendered_png_rows(automatic) == rendered_png_rows(quartz), f"{name} bypassed Quartz"


def write_nested_opacity_fixture(fixture, source, *, depth):
    fixture.write_text(source.read_text()
                       .replace('<title>SVG gradient mask opacity groups</title>',
                                '<title>Nested SVG gradient mask opacity</title>')
                       .replace('      <g opacity=', '      ' + '<g opacity=".75">' * (depth - 1) + '<g opacity=')
                       .replace('      </g>\n    </mask>', '      ' + '</g>' * depth + '\n    </mask>'))


def write_mixed_opacity_fixture(fixture, source):
    gradients = '''
    <linearGradient id="alpha-linear" gradientUnits="userSpaceOnUse" x1="14" y1="18" x2="72" y2="100">
      <stop stop-opacity=".25"/><stop offset="1"/>
    </linearGradient>
    <linearGradient id="alpha-sibling" gradientUnits="userSpaceOnUse" x1="150" y1="20" x2="160" y2="75">
      <stop/><stop offset="1" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="luminance-linear" gradientUnits="userSpaceOnUse" x1="210" x2="290" y1="20" y2="90">
      <stop stop-color="red"/><stop offset="1" stop-color="yellow"/>
    </linearGradient>'''
    fixture.write_text(source.read_text()
                       .replace('<title>SVG mask opacity groups</title>',
                                '<title>SVG mask opacity groups with mixed fills</title>')
                       .replace('  <defs>', '  <defs>' + gradients)
                       .replace('fill="black" d="M14', 'fill="url(#alpha-linear)" d="M14')
                       .replace('fill="black" d="M150', 'fill="url(#alpha-sibling)" d="M150')
                       .replace('fill="#f00"', 'fill="url(#luminance-linear)"'))


def write_direct_fills_fixture(fixture, source, *, gradients, reflected=False):
    text = (source.read_text()
            .replace('<title>Overlapping solid SVG mask fills</title>',
                     '<title>Overlapping rectangular SVG mask fills</title>')
            .replace('    </mask>', '      <path d="M105 45h25v44H105Z" fill="black" fill-opacity=".375"/>\n'
                                    '    </mask>', 1)
            .replace('fill="lime" fill-opacity=".5"/>',
                     'fill="lime" fill-opacity=".5"/>\n'
                     '      <path d="M352 44h56v47H352Z" fill="blue" fill-opacity=".375"/>'))
    if gradients:
        definitions = '''
    <linearGradient id="alpha-left" gradientUnits="userSpaceOnUse" x1="21" y1="11" x2="147" y2="11">
      <stop stop-opacity=".25"/><stop offset="1"/>
    </linearGradient>
    <linearGradient id="alpha-center" gradientUnits="userSpaceOnUse" x1="105" y1="45" x2="130" y2="89">
      <stop/><stop offset="1" stop-opacity=".25"/>
    </linearGradient>
    <linearGradient id="luminance-right" gradientUnits="userSpaceOnUse" x1="335" y1="36" x2="447" y2="98">
      <stop stop-color="lime"/><stop offset="1" stop-color="white"/>
    </linearGradient>'''
        text = (text.replace('  <defs>', '  <defs>' + definitions)
                .replace('fill="black" fill-opacity=".5"', 'fill="url(#alpha-left)" fill-opacity=".5"')
                .replace('fill="black" fill-opacity=".375"', 'fill="url(#alpha-center)" fill-opacity=".375"')
                .replace('fill="lime" fill-opacity=".5"', 'fill="url(#luminance-right)" fill-opacity=".5"'))
    if reflected:
        # Reflect each rectangle about its own center to preserve its coverage.
        text = (text.replace('<path d="M21', '<path transform="translate(168 0) scale(-1 1)" d="M21')
                .replace('<path d="M105 26', '<path transform="translate(0 127) scale(1 -1)" d="M105 26')
                .replace('<path d="M255', '<path transform="translate(0 120) scale(1 -1)" d="M255')
                .replace('<path d="M335', '<path transform="translate(782 134) scale(-1 -1)" d="M335'))
    fixture.write_text(text)


def check_solid_mask_order_change(binary, fixture, directory):
    reordered = directory / "reordered-solid-masks.html"
    reordered.write_text(re.sub(r"^  <use .*\n", "", fixture.read_text(), flags=re.MULTILINE) + """
<script>
requestAnimationFrame(() => requestAnimationFrame(() => {
    const mask = document.getElementById("luminance-mask");
    mask.insertBefore(mask.lastElementChild, mask.firstElementChild);
    document.documentElement.setAttribute("data-masks-updated", "true");
}));
</script>
""")
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SHARED_SVG_MASK_CACHE="0",
                    VOX_CAPTURE_READY_SELECTOR="html[data-masks-updated=true]")
    options = ["--enable-javascript", "--js-engine=javascriptcore"]
    cached, diagnostics = capture_document(binary, reordered, directory / "reordered-solid-cached",
                                           settings, options)
    keys = re.findall(r"^VOX_SHARED_SVG_MASK luminance=true operations=2 .* resource_key=(\d+) ",
                      diagnostics, re.MULTILINE)
    assert len(set(keys)) == 2 and "0" not in keys, diagnostics
    settings.update(VOX_SHARED_SVG_MASK_RASTER="1", VOX_DISABLE_SHARED_SVG_MASK_CACHE="1")
    uncached, _ = capture_document(binary, reordered, directory / "reordered-solid-uncached",
                                  settings, options)
    updated = rendered_png_rows(cached)
    assert updated == rendered_png_rows(uncached), "Cached luminance hid a change in fill order"
    _, _, channels, rows = updated
    assert rows[70][370 * channels:370 * channels + 3] == b"\xff\xb7\xb7"


def check_cached_geometry_change(binary, source, directory):
    fixture = directory / "svg-mask-geometry-change.html"
    text = re.sub(r"^  <use .*\n", "", source.read_text(), flags=re.MULTILINE)
    fixture.write_text(text.replace("M255 15h200v90H255Z", "M275 15h150v90H275Z") + """
<script>
requestAnimationFrame(() => requestAnimationFrame(() => {
    document.querySelector("#alpha-mask path").setAttribute("d", "M21 11H201V111Z");
    document.querySelector("#luminance-mask path").setAttribute("transform", "translate(.25 0)");
    document.documentElement.setAttribute("data-masks-updated", "true");
}));
</script>
""")
    settings = dict(VOX_SHARED_SVG_MASK_RASTER="", VOX_DISABLE_SHARED_SVG_MASK_CACHE="0",
                    LADYBIRD_SCREENSHOT_SCALE="2")
    original, _ = capture_document(binary, fixture, directory / "geometry-before", settings,
                                   ["--disable-javascript"])
    settings["VOX_CAPTURE_READY_SELECTOR"] = "html[data-masks-updated=true]"
    options = ["--enable-javascript", "--js-engine=javascriptcore"]
    changed, diagnostics = capture_document(binary, fixture, directory / "geometry-after", settings, options)
    for luminance in ("true", "false"):
        rasters = re.findall(rf"^VOX_SHARED_SVG_MASK luminance={luminance} operations=1 .*",
                             diagnostics, re.MULTILINE)
        assert len(rasters) == 1, diagnostics
    settings["VOX_SHARED_SVG_MASK_RASTER"] = "0"
    quartz, _ = capture_document(binary, fixture, directory / "geometry-quartz", settings, options)
    result = rendered_png_rows(changed)
    assert result == rendered_png_rows(quartz), "A mask hit retained old geometry"
    before = rendered_png_rows(original)
    assert before[:3] == result[:3] and result[:2] == (2048, 1200)
    _, _, channels, rows = result
    before_rows = before[3]
    outside = 40 * 2 * channels
    edge = 275 * 2 * channels
    assert rows[180][outside:outside + 3] == b"\xff\xff\xff"
    assert before_rows[180][outside:outside + 3] == b"\x7f\x7f\xff"
    assert rows[120][edge:edge + 3] != before_rows[120][edge:edge + 3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    args = parser.parse_args()
    binary = args.binary.resolve()
    root = Path(__file__).resolve().parents[1]
    fixture = root / "Tests/Browser/Native/svg-gradient-masks.html"
    mutation = fixture.with_name("svg-gradient-mask-mutation.html")
    vertical = fixture.with_name("svg-vertical-alpha-masks.html")
    luminance = fixture.with_name("svg-linear-luminance-masks.html")
    diagonal = fixture.with_name("svg-diagonal-gradient-masks.html")
    opacity = fixture.with_name("svg-gradient-mask-opacity.html")
    solid = fixture.with_name("svg-solid-rectangle-masks.html")
    overlap = fixture.with_name("svg-overlapping-solid-mask-fills.html")
    grouped_solids = fixture.with_name("svg-mask-opacity.html")
    inputs = [binary, fixture, mutation, vertical, luminance, diagonal, opacity, solid, overlap,
              grouped_solids]
    avif_library = binary.with_name("libVoxAVIF.dylib")
    if avif_library.exists():
        inputs.append(avif_library)
    digests = {path: digest(path) for path in inputs}
    with tempfile.TemporaryDirectory(prefix="vox-svg-mask-") as temporary:
        directory = Path(temporary)
        unscrolled = capture(binary, fixture, directory / "samples-1x", True)
        width, height, channels, quartz = capture(binary, fixture, directory / "quartz", False, scale=2)
        new_width, new_height, new_channels, shared = capture(binary, fixture, directory / "shared", True,
                                                              scale=2)
        assert (width, height, channels) == (new_width, new_height, new_channels)
        maximum = max(abs(a - b) for old_row, new_row in zip(quartz, shared) for a, b in zip(old_row, new_row))
        assert maximum <= 2, f"Document channels differed by up to {maximum}"
        print(f"Largest document channel difference against Quartz is {maximum}")
        automatic = capture(binary, fixture, directory / "automatic", None, scale=2)
        assert automatic[:3] == (width, height, channels)
        automatic_difference = max(abs(a - b) for old, new in zip(quartz, automatic[3])
                                   for a, b in zip(old, new))
        assert automatic_difference <= 2, f"Automatic raster channels differed by {automatic_difference}"
        before_cache = capture(binary, fixture, directory / "scrolled-uncached", True, scroll=96)
        rows_reference = capture(binary, fixture, directory / "scrolled-full-shader", True,
                                 disable_ramp=True, scroll=96)
        assert rows_reference == before_cache, "Copying the shaded row changed the document pixels"
        eager_cache = capture(binary, fixture, directory / "scrolled-eager", True,
                              cache=True, eager=True, scroll=96)
        after_cache = capture(binary, fixture, directory / "scrolled-cached", True, cache=True, scroll=96)
        copied = capture(binary, fixture, directory / "scrolled-copied", True,
                         cache=True, copy=True, scroll=96)
        assert before_cache != unscrolled, "Capture must move the document"
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
        automatic_2x = capture(binary, fixture, directory / "automatic-2x", None,
                               cache=True, require_viewport_hit=True, scroll=42, scale=2)
        assert automatic_2x == full_2x, "Automatic radial raster changed the 2× document pixels"
        check_mask_mutation(binary, mutation, directory)
        for kind in ("radial", "diagonal", "opacity", "solid"):
            check_mask_cache_capacity(binary, directory, kind=kind)
        check_mask_cache_capacity(binary, directory, kind="solid", solid_fills=2)
        check_mask_cache_capacity(binary, directory, kind="opacity", opacity_depth=4)
        check_mask_cache_capacity(binary, directory, kind="solid-opacity")
        check_mask_cache_capacity(binary, directory, kind="gradient-opacity")
        check_mask_cache_capacity(binary, directory, kind="gradient")
        check_mask_cache_capacity(binary, directory, kind="gradient", reflected=True)
        check_svg_mask_strips(binary, vertical, directory, luminance=False)
        check_svg_mask_strips(binary, luminance, directory, luminance=True)
        for source, is_luminance in ((vertical, False), (luminance, True)):
            reflected_strips = directory / f"reflected-{source.name}"
            write_reflected_strip_fixture(reflected_strips, source)
            check_svg_mask_strips(binary, reflected_strips, directory, luminance=is_luminance,
                                  reflected=True)
        fractional_strip = directory / "fractional-reflected-strips.html"
        fractional_strip.write_text(reflected_strips.read_text()
                                    .replace('translate(222 122)', 'translate(222.25 122)')
                                    .replace('translate(0 120)', 'translate(0 120.25)'))
        check_quartz_mask_fallback(binary, fractional_strip, directory)
        check_linear_rgb_fallback(binary, luminance, directory)
        check_cached_svg_masks(binary, diagonal, directory)
        # The second repeated sample starts at y=48 after scrolling 132 px.
        white = (255, 255, 255)
        check_cached_svg_masks(binary, opacity, directory, operations=4, samples=(
            (130, 138, (128, 128, 255)), (170, 138, (128, 128, 255)), (205, 138, (128, 128, 255)),
            (290, 98, (255, 115, 115)), (415, 98, (255, 222, 222)), (18, 138, white), (449, 98, white),
        ))
        check_cached_svg_masks(binary, solid, directory, samples=(
            (130, 110, (127, 127, 255)), (290, 98, (255, 215, 215)), (18, 110, white), (449, 98, white),
        ))
        check_cached_svg_masks(binary, overlap, directory, operations=2, samples=(
            (18, 118, white), (70, 118, (127, 127, 255)), (128, 118, (63, 63, 255)),
            (180, 118, (127, 127, 255)), (295, 118, (255, 228, 228)),
            (370, 118, (255, 150, 150)), (430, 118, (255, 164, 164)), (449, 118, white),
        ))
        check_solid_mask_order_change(binary, overlap, directory)
        check_cached_geometry_change(binary, solid, directory)
        for gradients in (False, True):
            name = "direct-gradient-fills" if gradients else "direct-solid-fills"
            direct_fills = directory / f"{name}.html"
            write_direct_fills_fixture(direct_fills, overlap, gradients=gradients)
            check_cached_svg_masks(binary, direct_fills, directory, operations=3,
                                   samples=((18, 118, white), (449, 118, white), (500, 98, (255, 136, 0))))
            reflected_fills = directory / f"reflected-{name}.html"
            write_direct_fills_fixture(reflected_fills, overlap, gradients=gradients, reflected=True)
            check_cached_svg_masks(binary, reflected_fills, directory, operations=3,
                                   samples=((18, 118, white), (449, 118, white), (500, 98, (255, 136, 0))))
        fractional_reflection = directory / "fractional-reflected-fills.html"
        fractional_reflection.write_text(reflected_fills.read_text()
                                         .replace('translate(168 0)', 'translate(168.25 0)')
                                         .replace('translate(782 134)', 'translate(782 134.25)'))
        check_quartz_mask_fallback(binary, fractional_reflection, directory)
        too_many_direct_fills = directory / "seven-direct-fills.html"
        too_many_direct_fills.write_text(direct_fills.read_text().replace(
            '</mask>', '<path d="M10 10h450v100H10Z" fill="white"/>' * 4 + '</mask>'))
        check_quartz_mask_fallback(binary, too_many_direct_fills, directory)
        check_cached_svg_masks(binary, grouped_solids, directory, operations=5, alpha_operations=11,
                               samples=((94, 104, white), (195, 104, (0, 0, 255)),
                                        (375, 104, (255, 136, 0))))
        mixed = directory / "mixed-gradient-opacity.html"
        write_mixed_opacity_fixture(mixed, grouped_solids)
        check_cached_svg_masks(binary, mixed, directory, operations=5, alpha_operations=11,
                               samples=((94, 104, white), (195, 104, (0, 0, 255)),
                                        (375, 104, (255, 136, 0))))
        radial_siblings = directory / "radial-opacity-siblings.html"
        radial_siblings.write_text(re.sub(
            r'<linearGradient id="(alpha-sibling|luminance-linear)"[^>]*>(.*?)</linearGradient>',
            r'<radialGradient id="\1" gradientUnits="userSpaceOnUse" cx="155" cy="45" r="30">\2</radialGradient>',
            mixed.read_text(), flags=re.DOTALL))
        check_quartz_mask_fallback(binary, radial_siblings, directory)
        too_many_gradients = directory / "three-gradients-opacity.html"
        too_many_gradients.write_text(re.sub(r'^        <path .*fill="url\(#[^)]+\)"/>$',
                                            lambda match: '\n'.join([match[0]] * 3),
                                            opacity.read_text(), flags=re.MULTILINE))
        check_quartz_mask_fallback(binary, too_many_gradients, directory)
        fractional_group = directory / "fractional-solid-opacity.html"
        fractional_group.write_text(grouped_solids.read_text().replace('<path fill="black"',
                                    '<path transform="translate(.25 0)" fill="black"')
                                    .replace('<path fill="#f00"',
                                             '<path transform="translate(.25 0)" fill="#f00"'))
        check_quartz_mask_fallback(binary, fractional_group, directory)
        too_many_fills = directory / "large-solid-opacity-group.html"
        too_many_fills.write_text(grouped_solids.read_text().replace(
            '</mask>', '<path fill="white" d="M10 10h350v100H10Z"/>' * 8 + '</mask>'))
        check_quartz_mask_fallback(binary, too_many_fills, directory)
        for depth, alpha_channel, luma_channel, overlay in ((2, 160, 151, 230), (4, 202, 197, 242)):
            nested = directory / f"nested-gradient-opacity-{depth}.html"
            write_nested_opacity_fixture(nested, opacity, depth=depth)
            check_cached_svg_masks(binary, nested, directory, operations=2 * depth + 2, samples=(
                (130, 138, (alpha_channel, alpha_channel, 255)), (170, 138, (alpha_channel, alpha_channel, 255)),
                (205, 138, (alpha_channel, alpha_channel, 255)), (290, 98, (255, luma_channel, luma_channel)),
                (415, 98, (255, overlay, overlay)), (18, 138, white), (449, 98, white),
            ))
        too_deep = directory / "nested-gradient-opacity-5.html"
        write_nested_opacity_fixture(too_deep, opacity, depth=5)
        check_quartz_mask_fallback(binary, too_deep, directory)
        fractional = directory / "fractional-solid-mask.html"
        fractional.write_text(solid.read_text().replace('fill-opacity=', 'transform="translate(.25 0)" fill-opacity='))
        check_quartz_mask_fallback(binary, fractional, directory)
        fractional_overlap = directory / "fractional-overlapping-solid-mask.html"
        fractional_overlap.write_text(overlap.read_text()
                                      .replace('<path d="M105', '<path transform="translate(.25 0)" d="M105')
                                      .replace('<path d="M335', '<path transform="translate(.25 0)" d="M335'))
        check_quartz_mask_fallback(binary, fractional_overlap, directory)
    assert {path: digest(path) for path in inputs} == digests
    print("PASS: macOS shared SVG masks, cache reuse, and Quartz fallback")


if __name__ == "__main__":
    main()
