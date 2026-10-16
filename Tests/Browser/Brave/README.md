# Brave rendering fixtures

References were captured from Brave 155.1.97.57 on macOS at device scale 1.
`font-rasterization` covers Arial and Verdana at integer and fractional sizes,
automatic and antialiased smoothing, three foreground colors, and white and
colored backgrounds. Its explicit base URL selects the native compatibility
profile used for old Reddit.

```sh
./capture_screenshot.sh Tests/Browser/Brave/input/font-rasterization.html Build/font-rasterization.png 1024 768
python3 tools/check_pixel_equality.py Tests/Browser/Brave/expected/font-rasterization.png Build/font-rasterization.png Build/font-rasterization.diff.png
```

This comparison requires exact RGBA equality, with no excluded pixels or tolerance.

`box-shadow-blur` checks square and two rounded outer shadows. The native
Chromium profile uses an isolated Skia 155 Metal backend for these shadows,
including Chromium's legacy rounded clip shader and full precision arithmetic.
The dependency is pinned to Chromium 155.0.8059.80's Skia revision. Its C ABI
exports pixels and plain values only; its hidden Skia symbols cannot interpose
on LibWeb's existing Skia library. Builds require GN and Ninja and cache the
verified dependency under `Build/deps/skia-brave`.

The three opaque shadow cases are exact. A separate diagnostic with a shadow
inside `opacity: .5` still differs by 1 at five pixels after the native layer
is composited. This fixture does not establish translucent-group parity.

`webp-yuv-scaled` checks a lossy WebP at half size. The Chromium image path
selects an upload size with rounded-up mip dimensions, scales each decoded
plane using Chromium's CPU mip selection, promotes scaled YUV to 4:4:4, and
converts color in the GPU shader. `webp-yuv` separately checks the original
4:2:0 image at natural size. Capture each fixture in a fresh Brave instance:
its image cache can reuse an earlier upload size for the same resource.

`inline-advances` checks shaped-item width rounding, kerning across ASCII
word boundaries, fractional max-content tables with emergency wrapping, and
font-relative inline margins. The Chromium profile keeps exact glyph advances
inside an item and rounds its outer advance upward to 1/64px. Normal fitting
and emergency breaking use that same cumulative advance. ASCII runs with one
font can share shaping across word chunks; other scripts and mixed-font runs
retain the existing shaping path.

`list-symbols` checks outside disc, circle and square markers and authored
marker text. The Chromium profile derives horizontal LTR symbol geometry from
the primary font's ascent and keeps fractional offsets for textual markers.
Circles and rounded shapes use the isolated GPU backend when available, with
the existing renderer as the fallback. Inside markers and other writing
directions retain their existing layout path.

`fractional-inline-lines` checks text at fractional block offsets with middle
alignment and both culled and spaced inline ancestors. Glyph painting snaps
the containing line or inline paint box while preserving the text's local
vertical alignment; selection and layout geometry retain their fractions.

`latin-context` extends shared shaping to Latin letters, combining marks and
common punctuation, including LTR `unicode-bidi:isolate` text. Chunk slicing
uses UTF-16 offsets so multibyte quotes and accents cannot shift source ranges.
Other scripts and mixed-font text continue through segmented shaping.
