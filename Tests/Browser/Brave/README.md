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

`opaque-box-shadow` checks opaque rounded backgrounds, solid borders, fractional
block offsets, a one-pixel shadow source, and an inline rounded border. Opaque
shadow cutouts overlap the background by one pixel. Block backgrounds inset
under opaque solid rounded borders; inline backgrounds retain Chromium's
separate treatment. Uniform circular rounded borders use an analytic stroke.

`background-sprite-rounding` checks an unscaled tall RGBA sprite whose offscreen
origin lies on a negative half pixel. Both edges round toward positive infinity
at ties, preserving the image's original size. `rounded-background-image`
checks repeated bitmap backgrounds inside rounded inline borders, including
a one-pixel strip before an image origin. The Chromium image player retains
that preceding tile and clips it in the GPU image operation, avoiding a second
Quartz antialiasing mask. Both fixtures use synthetic embedded PNGs.

`svg-path-coverage` checks SVG background images: a many-vertex star, curves
with an even-odd hole, serif letter outlines and a round-capped cubic stroke,
each at natural size and stretched. Chromium draws these paths through its GPU
rasterizer, whose multisampled edge coverage differs from Skia's CPU analytic
antialiasing, so Chromium-policy fills and solid strokes use the Graphite
backend. Paths inside SVG clip or opacity layers composite over the layer
instead of blending against the page backdrop; Vox still applies SVG clip
paths as Quartz masks, so clipped edges are not yet exact. Dashed strokes and
gradient fills keep the CPU path.

`fallback-text-items` checks text split by fallback fonts: Simplified and
Traditional Chinese with SF punctuation and digits, Japanese and Korean
lines, fractional line offsets, and an inline-block whose text nodes must
not wrap. Each text node is rounded as one Blink item across font changes
and CJK break opportunities, spaces use the first covering font, and with
`line-height: normal` the line box includes each fallback face's metrics
and half its line gap.

`color-emoji` checks emoji inside Arial text at 10.67, 13.33, 16, 19.5 and
24px, in regular and bold text. Blink selects Apple Color Emoji through
CoreText fallback and shapes with Skia's advances, which for its bitmap
strikes are whole pixels rather than the font's horizontal metrics. The
installed face is created by PostScript name, as Blink's CTFont is: a face
re-created from the font file loses Apple Color Emoji's strike advances and
ascent. Emoji with variation selector 16 after a text-presentation code point,
such as ❤️, still select a monochrome face and are not covered.
