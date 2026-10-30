# Brave rendering fixtures

References were captured from Brave 155.1.97.57 on macOS at device scale 1.
`font-rasterization` covers Arial and Verdana at integer and fractional sizes,
automatic and antialiased smoothing, three foreground colors, and white and
colored backgrounds. All native browser documents use the Chromium compatibility
profile, including local fixtures without an explicit base URL.

```sh
./capture_screenshot.sh Tests/Browser/Brave/input/font-rasterization.html Build/font-rasterization.png 1024 768
python3 tools/check_pixel_equality.py Tests/Browser/Brave/expected/font-rasterization.png Build/font-rasterization.png Build/font-rasterization.diff.png
```

This comparison requires exact RGBA equality, with no excluded pixels or tolerance.

`lobsters-tag-alignment` extracts the story-title and tag alignment from Lobsters.
It covers middle-aligned bold text, nested inline-block tags, fractional line
heights, and an empty tall inline-block control. All six lines match Brave
156.1.98.60 exactly at 800×600 and scale 1. Run the focused native regression
with `python3 -m unittest discover -s tools -p forum_news_inline_pixels_test.py`.
The test uses the current production bundle in a fresh process without an
automatic rebuild and retains its identities, memory-guard reports and diffs.

[`diagnostic/forum-translucent-text.html`](diagnostic/forum-translucent-text.html)
and its adjacent Brave 156.1.98.60 PNG cover modern and legacy alpha,
fractional RGB channels, inheritance, and an opacity group at 800×600, scale 1.
Foreground colors retain their computed precision through glyph coverage and
the final page blend; cached glyphs distinguish those float colors. The native
output improves from 3,270 differing pixels to six, with maximum channel error
three. This remains an open diagnostic, including one inherited-text pixel and
five opacity-group pixels. Run the focused transport cases in
`layout/chromium_text_color_test.v` and the cold/warm glyph checks with
`sh tools/test_native_skia_text_color.sh` under the required memory guard.

`font-large-distance-field` checks colored 180px text in a shared SVG raster tile
at 800×600 and scale 1. The standalone Skia build's A8 gamma adjustment must be
disabled to match Chromium's macOS text coverage, including distance-field
glyphs. The fixture is pixel-exact; its original backend differed at 2,955 pixels.

`elliptical-uniform-border` checks a rotated translucent elliptical CSS border
at 800×600 and scale 1 against Brave 156.1.98.60. The border retains both
corner radii and fills one outer/inner rounded-rectangle ring. The full fixture
requires exact equality; four separately painted border sides differed at
1,539 pixels, with a maximum channel error of 8.

`transformed-border-offset` checks an elliptical border whose untransformed
origin has fractional coordinates. Geometry snaps in the box's local paint
space before rotation; the full 800×600 fixture is exact against Brave
156.1.98.60. Transformed outer shadows retain the same local paint offset.
`transformed-shadow-stack` also retains consecutive outer shadows and the
border of one transparent box in a document-aligned root picture. Their shared
coverage is pixel-exact at 800×600 and scale 1. The unchanged
[combined shadow diagnostic](diagnostic/transformed-border-shadow-offset.html)
and adjacent Brave PNG are now exact too; they previously differed at 474
pixels. The recording excludes browser chrome and preserves the root tile
origin. Unsupported recordings retain the ordinary fallback pixels.

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

`inset-box-shadow` checks unblurred and blurred inset shadows, offsets and
spread at 800×600 and scale 1 against Brave 156.1.98.60. It is pixel-exact.
The Chromium renderer retains the rectangular outer caster, rounded padding-box
hole and clip through Skia GPU replay. Consecutive backgrounds, inset shadows
and a uniform border from one root-layer box share antialias coverage; an
unsupported recording or GPU failure preserves ordinary rendering.

`inset-rounded-root` retains circular and elliptical backgrounds, inset shadows
and borders in a complete root picture. All three cases are now pixel-exact;
the original renderer differed at 17,183 pixels, with maximum channel error 77.
The original [diagnostic input](diagnostic/inset-rounded-box-shadow.html) and
Brave PNG remain unchanged. `inset-circle-root` separately checks a circular
case without another shape requiring tile-wide multisampling. Both references
use Brave 156.1.98.60 at 800×600 and scale 1. Elliptical border masks mark their
owning raster tiles for MSAA; retained inset pictures keep that shared coverage.

`webp-yuv-scaled` checks a lossy WebP at half size. The Chromium image path
selects an upload size with rounded-up mip dimensions, scales each decoded
plane using Chromium's CPU mip selection, promotes scaled YUV to 4:4:4, and
converts color in the GPU shader. `webp-yuv` separately checks the original
4:2:0 image at natural size. Capture each fixture in a fresh Brave instance:
its image cache can reuse an earlier upload size for the same resource.

`webp-rgba-mip` checks a synthetic lossless 960×540 RGBA image at quarter
size. RGBA uploads use the same rounded-up CPU mip size as YUV uploads before
GPU sampling. This catches a full-size upload that skips the decode cache's
resize. `webp-rgba-mip-blend` draws the same image at 320×180, between
the decoded upload's GPU mip levels. Full-source minification generates and
linearly blends those levels; cropped sources retain strict sampling bounds,
and nearest-neighbor draws keep their original sampling. Both fixtures require
exact equality. A separate 269×151 diagnostic still differs by one channel
level at 86 pixels; arbitrary fractional sampling and rounded image clips
remain open.

`percentage-transform-image` checks a minified PNG positioned with fractional
percentage translations at 1280×800 and scale 1 against Brave 156.1.98.60.
Transform lengths retain floating-point precision in the Chromium profile;
rounding them to layout units displaced image samples at 838 pixels. The full
fixture now requires exact RGBA equality. The source PNG is the V website's
mascot, preserved in `assets/vlang-mascot.png`.

`translated-image-minification` checks a synthetic RGB image drawn away from
the viewport origin at a nonintegral minification scale. Full-source image draws
retain natural coordinates and place their scale on the canvas, matching
Brave's recorded operation order. Cropped sources keep strict source bounds.
This fixture is exact; the separate 269-by-151 RGBA diagnostic above remains
open.

`replaced-image-overflow` checks an image's own circular rounded clip and a
rounded overflow clip on its parent. The Chromium image draw applies its own
clip in Skia; a rectangular image can also carry one ancestor rounded clip
with the same transform. Other ancestor clips retain their order on the native
context, including paths, masks, and clips with different transforms. This
fixture is pixel-exact. The unchanged elliptical case in
[`diagnostic/replaced-image-rounded.html`](diagnostic/replaced-image-rounded.html)
still differs by one channel level at one pixel from its adjacent Brave PNG.
That diagnostic remains open and is not an exact-parity result.

`video-poster-rounded-clip` checks a video poster with its own rounded corners
and a rectangular video inside rounded overflow at 800×600 and scale 1.
Both use the same GPU clip representation as replaced images and are exact
against Brave 156.1.98.60; the previous native clipping differed at 84 pixels.
Object-fit cropping stays on the element while one compatible rounded ancestor
moves to the GPU. Paths, masks and ancestors with different transforms retain
their native clip order.

`css-linear-gpu` checks opaque sRGB linear gradients, black alpha gradients
over a colored background, and coincident hard stops. Eligible Chromium-policy
gradients retain their original stops and blend through the GPU path. The
path requires constant alpha or constant RGB so straight and premultiplied
interpolation agree; other color spaces and gradients retain the existing
renderer. All three cases require exact equality.

`background-clip-text-retained-gradient` checks linear and radial gradients
clipped to shaped text at 800×600 and scale 1. Eligible masks retain the original
glyph and gradient operations through GPU DestinationIn composition, avoiding
an intermediate 8-bit gradient image. Both block cases are pixel-exact against
Brave 156.1.98.60. Mixed backgrounds and fallback glyph drawing retain the
existing bitmap path.

`background-text-clip-scope` places rounded decorations after a gradient text
mask. It is pixel-exact against Brave 156.1.98.60 at 800×600 and scale 1.
Offscreen mask
preparation blocks the active picture without leaving the destination clip
unsupported. The bitmap fallback saves and restores its shared clip with the
CoreGraphics mask. Native scope tests cover existing parent clips and parent
recordings, empty masks, both raster scales, and later sibling pixels.

The unchanged broader input and its original Brave reference are preserved in
[`diagnostic/background-clip-text-retained-gradient.html`](diagnostic/background-clip-text-retained-gradient.html).
Its inline angled gradient still has one-level dither differences, and its
wrapped inline background has larger positioning differences. Those cases
remain open; the exact block fixture does not establish general inline parity.

A fully transparent gradient stop contributes no premultiplied RGB. The
constant-color GPU path therefore normalizes its invisible RGB to the visible
color before interpolating. `css-linear-premult-transparent` checks an angled
fade, a vertical fade and a hard stop against the unchanged original Brave
reference. All three are pixel-exact. The Chromium path retains the CSS angle
and computes tile-local endpoints with Blink's float intermediates before
translating the shader to the tile origin.

`background-gradient-snapping` checks fractional auto-sized gradient backgrounds
at the default zero position, including hard stops expressed in pixels. Their
tile dimensions and stop positions use the snapped positioning area in the
Chromium profile. All three cases are exact. Explicit background sizes and
positions retain their existing path. The unchanged four-case
[`diagnostic/fractional-generated-gradient.html`](diagnostic/fractional-generated-gradient.html)
and adjacent original Brave PNG preserve remaining dither, rounded-clip and
explicit-size differences.

`gradient-raster-tiles` places angled and vertical fades across four Chromium
raster tiles. Their shared border texels make a 256-row tile advance by 254
rows. The opaque, unscrolled 1× root path now draws gradients in each tile's
coordinate space, preserving its dither pattern and float rounding; all eight
cases are exact. Tile allocation is bounded at 32 MiB. Other scales, scrolled
roots and isolated layers retain the existing leaf renderer.

Outer CSS SVG roots in the Chromium profile snap their border-box paint
origin while layout, padding, nested viewports and transforms keep their
fractions. The two CNN header icons are exact after this change. The unchanged
[`diagnostic/svg-root-paint-offset.html`](diagnostic/svg-root-paint-offset.html)
and adjacent original Brave reference retain seven differing pixels, two by
ten levels, where a rectangular path shares a raster tile with complex paths.
A private multisampling probe removes those differences; tile-wide native
multisampling remains open. This diagnostic is not an exact-parity fixture.

Non-repeating SVG backgrounds in the Chromium profile lay out in an
independently rounded container and replay into the snapped destination.
`svg-background-snapped-container` checks three fractional background sizes;
it improves from 27 differing pixels to zero. Brave's exported paint record
confirms that the rounded viewport supplies the final viewBox scale.
The unchanged
[`diagnostic/svg-background-fractional.html`](diagnostic/svg-background-fractional.html)
and adjacent original Brave reference retain translucent circle borders;
they improve from 123 to 96 differing pixels, with maximum channel error 12.

`inline-advances` checks shaped-item width rounding, kerning across ASCII
word boundaries, fractional max-content tables with emergency wrapping, and
font-relative inline margins. The Chromium profile keeps exact glyph advances
inside an item and rounds its outer advance upward to 1/64px. Normal fitting
and emergency breaking use that same cumulative advance. Compatible runs with
one font can share shaping across word chunks; the script and fallback-font
limits are described below.

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
The layout context tests also cover Cyrillic and contiguous segments on either
side of a fallback-font symbol, including supplementary characters. Each
segment must use one font and one supported script. Unsupported scripts,
incompatible bidi paths, discontinuities and multi-glyph clusters retain
ordinary shaping. These tests do not establish full-page pixel parity.

`opaque-box-shadow` checks opaque rounded backgrounds, solid borders, fractional
block offsets, a one-pixel shadow source, and an inline rounded border. Opaque
shadow cutouts overlap the background by one pixel. Block backgrounds inset
under opaque solid rounded borders; inline backgrounds retain Chromium's
separate treatment. Uniform circular rounded borders use an analytic stroke.

`compositor-box-shadows` checks overlapping outer shadows inside a transformed
header, including blur ink that extends beyond its compositor border box.

`transformed-partial-border` checks opaque two-sided borders rotated and skewed
at fractional box origins. Their paint offset snaps before the box transform;
matching solid sides retain overlapping antialiased rectangles. Retained
transform updates resolve that offset again without changing layout geometry.
The unchanged colored-backdrop case remains in
`diagnostic/rotated-partial-border.html`; five pixels still differ by one
channel level there. Translucent, rounded and differently colored sides keep
their existing border paths.

`background-sprite-rounding` checks an unscaled tall RGBA sprite whose offscreen
origin lies on a negative half pixel. Both edges round toward positive infinity
at ties, preserving the image's original size. `rounded-background-image`
checks repeated bitmap backgrounds inside rounded inline borders, including
a one-pixel strip before an image origin. The Chromium image player retains
that preceding tile and clips it in the GPU image operation, avoiding a second
Quartz antialiasing mask. Both fixtures use synthetic embedded PNGs.

`svg-path-coverage` checks SVG background images: a many-vertex star, curves
with an even-odd hole, serif letter outlines, a round-capped cubic stroke and
bounding-box linear and radial gradients, each at natural size and stretched.
Chromium draws these paths through its GPU rasterizer, whose multisampled edge
coverage differs from Skia's CPU analytic antialiasing, so Chromium-policy
fills, solid strokes and gradients use the Graphite backend. Gradients are
dithered on the page's eight-pixel grid. Paths inside SVG clip or opacity
layers composite over the layer instead of blending against the page
backdrop; Vox still applies SVG clip paths as Quartz masks, so clipped edges
are not yet exact. Dashed strokes keep the CPU path.

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

`checkbox` checks enabled, unchecked check boxes beside text, at a
half-pixel offset and over a tinted background. Blink paints them with
NativeThemeBase into the pixel-snapped control box: a white background inset
by 0.2px and a 1px #767676 border stroked half a pixel inside, both with a
2px radius. Both shapes are rasterized by the isolated GPU backend over the
page in one pass, as in Brave. Indeterminate, disabled, author-accented
checked and dark-scheme controls keep the existing LibWeb painting.

`checkbox-checked-device-layout` checks default checked controls, unchecked
controls, tinted backgrounds and fractional CSS positions at native scale 2
(800×600 viewport, 1600×1200 PNG). Theme rectangles snap in device pixels; radii, border widths and the checked
path scale with the display. The default enabled light-theme check uses Chromium’s blue accent
and white checkmark.

`checkbox-multisampled-tile` places such check boxes, at whole and fractional
offsets, in the raster tile of a skip-ink underline crossing two descenders,
as in each 4chan post header. That tile is multisampled, and Brave resolves
the background and border of each check box together; drawing and resolving
them separately leaves their corner pixels one level apart.

`jpeg-yuv` checks baseline and progressive 4:2:0 JPEG images and a
progressive 4:4:4 image at natural size. Brave decodes YCbCr JPEGs to Y, Cb
and Cr planes with libjpeg-turbo and converts them in the GPU shader with
full-range BT.601 while sampling chroma bilinearly; the Chromium profile
uploads the same planes to the isolated GPU backend. TurboJPEG pads 4:2:0
luma planes to even dimensions, so the decoder packs them before upload.
Images with an embedded ICC profile and other subsamplings keep the RGB
decoder.

`png-gamma` checks PNGs with `gAMA` and `cHRM` chunks: a palette sprite with
gamma 1/2.2 and sRGB primaries, drawn as an image and as background
positions, a linear-gamma image, an untagged gamma 1/2.2 image, and a
translucent image with gamma 1/1.8 and a wide green primary. Brave's PNG
codec tags these images with the color space built from the chunks, except
that gamma within 5% of 1/2.2 without `cHRM` is untagged, and `sRGB`, `iCCP`
and `cICP` chunks take precedence. Its GPU image cache premultiplies the
decoded texels, then converts the texture to an 8-bit sRGB copy before
drawing it. The Chromium profile tags images decoded by stb_image the same way
and converts them in the isolated GPU backend. An RGB variant of the first
image also matched except one pixel whose converted value lies within 1e-5 of
a rounding tie, so it is not part of the fixture.

`opacity-group` checks opacity groups: glyphs at 0.8 like 4chan's post-menu
button, translucent buttons with a rounded background and text, nested
groups, a blurred box shadow at 0.5, and faded text. Brave paints each group
into an 8-bit premultiplied layer and draws it over the backdrop in float32
GPU arithmetic, with the blend as one fused multiply-add. The Chromium profile
paints a normal-blending group into its own bitmap with the canvas's format,
where text, shadows and images still blend over the group's own pixels, then
composites it with the same arithmetic. Core Graphics transparency layers
rounded antialiased edges inside a group differently. Groups with another
blend mode keep the Core Graphics layer.

`paragraph-advances` checks 4chan's /pol/ rules post: 13.33px Arial paragraphs
whose text nodes wrap across several lines. Blink's HarfBuzz font functions
take each glyph's advance from its Skia strike, truncated to 16.16 fixed
point, and HarfBuzz adds its kerning at the same scale. Each line's glyph
positions are then exact 16.16 sums from the line's first glyph, converted to
float once. The Chromium profile uses the same strike widths and recomputes
each word's positions from those advances, rather than subtracting float pens
of a paragraph-long shaping run, so no glyph moves into a neighbouring
quarter-pixel raster position. Legacy `kern` adjustments keep the placement
HarfBuzz gives their second glyph.

`skip-ink-fractional-line` checks a 4chan file link's skip-ink underline on
lines whose top lies 0.09375px below a pixel boundary, with the link start
shifted in 1/64px steps. Blink draws the glyphs from the line top rounded to a
whole pixel but measures the ink-skip stripe from the unrounded decoration, so
the glyph intercepts, and the clip-outs around descenders, follow that
fraction. The underline crosses two descenders on every line, so each line's
GPU raster tile is multisampled.

`inline-isolate-kerning` checks text after and inside left-to-right
isolates: 4chan's inline OP post `div`, a `span dir="ltr"` and a `bdi`. The UA
style sheet isolates each of them, but an LTR isolate of LTR text resolves to
LTR bidi levels, so Blink keeps its paragraph in one LTR shaping run and kerns
pairs such as `w.` and `Ty`. Splitting neutral punctuation into separate runs
drops those kerns.

`svg-background-natural-size` covers eleven SVG backgrounds with a natural
aspect ratio alone, either dimension, percentage dimensions, and explicit
`background-size` values. Missing dimensions stay absent during CSS default
sizing. Each SVG viewport clips its contents before the background is
composited, including SVG children larger than a width-only image. The fixture
requires exact RGBA equality against its unchanged Brave reference.

`svg-mask-paint-origin` checks thirteen CSS SVG mask and image placements,
including fractional and negative half-pixel origins. The Chromium profile
snaps the CSS mask image paint origin while preserving its resolved size and
DOM geometry. Inline SVG, background images and SVG images inside mask
resources retain their own coordinate rules. All cases require exact RGBA
equality against the unchanged Brave reference.

`text-shadow-retained-font` checks four opaque text shadows using Arial and
Verdana, regular and bold faces, and fractional line positions. The Chromium
profile replays shadows with the foreground's retained font and glyph geometry.
The fixture is pixel-exact. Expanded alpha/scaled cases remain unchanged in
`diagnostic/text-shadow-retained-font.html` and its original Brave PNG; 1,085
pixels still differ by at most two levels. The four-case
`diagnostic/text-shadow-blur.html` and original PNG retain 5,295 differing
pixels, with maximum error four, after correcting double-scaled blur. Neither
diagnostic establishes exact parity.

`svg-ellipse-computed-geometry` checks CSS percentage circle geometry and an
ellipse with an automatic radius. Explicit SVG primitives retain their
identity in the native paint stream; the fixture improves from 184 differing
pixels to exact equality. The original thirteen-case
`diagnostic/svg-ellipse-identity.html` and Brave PNG remain unchanged. That
expanded diagnostic improves from 1,110 to 405 differing pixels, including
41 pixel errors that increase; its authored-arc and previously exact stroke
controls remain exact. Fractional, transformed, dashed and small-circle
cases still require work, so the expanded diagnostic has no parity credit.

`svg-shared-root-recording` captures an inline SVG image at 1280 by 800.
Its short non-scaling stroke shares the root recording with surrounding
drawing, then replays through the pinned Dawn/Metal backend. The expected PNG
requires exact RGBA equality; unsupported effect and clip scopes keep their
existing leaf rendering path.

`svg-shared-empty-clip` adds a checkbox hidden by a zero-area CSS clip.
Discarded drawing commands leave shared recording enabled; effect boundaries
and visible clips retain their existing fallback. Capture at 1280 by 800,
device scale 1, and require exact RGBA equality.

`isolated-svg-strokes` checks the fixed SVG image from
[AsgardPvP](https://asgardpvp.com/images/back-to-top.svg). Its original Brave
155.1.97.59 reference uses a normal 1280×800 window at native scale 2, giving
a 2560×1600 PNG. The fractional image origin requires a 100×135 device-pixel
layer. Rounding its dimensions before applying the device scale, or drawing
on the larger enclosing CSS-pixel rectangle, changes GPU stroke coverage.
The isolated SVG uses the same Dawn replay as the shared root recording.
This fixture requires exact RGBA equality.

Preserve device pixels when capturing this fixture; `capture_screenshot.sh`
normally downsamples Retina captures to logical pixels:

```sh
LADYBIRD_SCREENSHOT_SCALE=2 VOX_SCREENSHOT_NATIVE_LAYOUT=1 \
  Build/v/Vox.app/Contents/MacOS/Vox --window-width 1280 --window-height 884 \
  --screenshot Build/isolated-svg-window.png \
  "$PWD/Tests/Browser/Brave/input/isolated-svg-strokes.html"
sips --cropToHeightWidth 1600 2560 --cropOffset 120 0 \
  Build/isolated-svg-window.png --out Build/isolated-svg.png
python3 tools/check_pixel_equality.py \
  Tests/Browser/Brave/expected/isolated-svg-strokes.png \
  Build/isolated-svg.png Build/isolated-svg.diff.png
```

`device-layout-image-fallback` checks 70px fixed-size, empty-alt failed images
in LTR and RTL at native scale 2 (800×600 viewport, 1600×1200 PNG), against
Brave 156.1.98.60. The Chromium profile paints the silver frame and the
licensed Chromium icon only after failure; pending requests stay blank.
The zero-font thumbnail line also retains its 70px height. This focused
fixture is pixel-exact. The unchanged expanded cases in
[`diagnostic/device-layout-image-fallback.html`](diagnostic/device-layout-image-fallback.html)
and its adjacent Brave PNG preserve remaining small-image and inline RTL
ordering differences. Nonempty alternative text and images with automatic
sizes retain the existing layout path.

Capture device-layout fixtures without downsampling:

```sh
VOX_TEST_WINDOW=1 LADYBIRD_SCREENSHOT_SCALE=2 VOX_SCREENSHOT_NATIVE_LAYOUT=1 \
  VOX_CAPTURE_DOCUMENT_ONLY=1 Build/v/Vox.app/Contents/MacOS/Vox \
  --window-width 800 --window-height 684 --screenshot Build/image-fallback.png \
  "$PWD/Tests/Browser/Brave/input/device-layout-image-fallback.html"
python3 tools/check_pixel_equality.py \
  Tests/Browser/Brave/expected/device-layout-image-fallback.png \
  Build/image-fallback.png Build/image-fallback.diff.png
```

`background-sprite-device-layout` uses the same 800×600 viewport and native
scale 2 against Brave 156.1.98.60. Its natural-size sprite, `contain`, and
`cover` cases require exact RGBA equality. The original expanded fixture and
Brave reference remain in
[`diagnostic/background-sprite-device-layout.html`](diagnostic/background-sprite-device-layout.html)
and its adjacent PNG; fractional explicit sizes, repeated tiles, and `round`
tiling still have differences. These diagnostic cases are not parity claims.

`input-placeholder-clamped-line-height` reduces the Maps search field to a
padded input with an automatic height clamped by equal minimum and maximum
heights. In the Chromium profile, input placeholders use the UA's important
normal line height instead of inheriting the control's 48px line height.
The reference was captured with Brave 155.1.97.57 at 1024×768 and device
scale 1. Exact RGBA equality covers this reduced control, not the complete
live Maps page.

`hacker-news-item-50231722` freezes the discussion at
<https://news.ycombinator.com/item?id=50231722>, with scripts removed and render
assets stored beside the HTML. Its unchanged Brave 156.1.98.60 reference uses
a 1024×2048 viewport at device scale 1 and includes the footer search field.
Run the complete pixel comparison on macOS with:

```sh
V_BIN=~/code/v-latest/v python3 tools/run_memory_bounded.py \
  --report Build/hacker-news-pixels-job.json -- python3 tools/hacker_news_pixels_test.py
```

The same test includes `hacker-news-comment-initial-text`, reduced from
<https://news.ycombinator.com/item?id=50225695#50226323>. Its opening sentence,
“This statement stood out to me.”, is bare text preceding paragraph blocks.
Anonymous block wrappers must inherit the same physical font as those blocks.
The reference uses a native Brave 156.1.98.60 window at 800×600 CSS pixels and
device scale 2 (`--windowed --native-scale`),
then the screenshot workflow's `sips --resampleHeightWidth 600 800` conversion
to logical pixels. The layout test also checks both document modes, scale
changes, and live font-size changes.

`hacker-news-item-50231722-complete` retains all 101 comment rows from the
response frozen on 2026-10-25, including collapsed and hidden rows. Its Brave
reference uses a native 1024×768 CSS viewport at device scale 2 and retains the raw
2048×1536 PNG. The pixel test normalizes that reference to logical pixels; the
instruction gate checks every comment ID and exact native-resolution pixels
for every fresh-process observation:

```sh
python3 tools/run_memory_bounded.py --report Build/hn-instructions-job.json -- \
  python3 tools/hacker_news_browser_instructions.py --output Build/hn-instructions
```

The gate requires Vox's largest instruction count to be at most 90% of
Brave's smallest lower bound across at least two alternating pairs (three by
default). It records exclusive resource-coalition counters, including exited
helpers and coalition-owned Metal compiler services, executable and dependency
hashes, raw observations, real exit status,
and the loopback replay policy. The interval runs from navigation request to
encoded document PNG availability. Vox's native endpoint precedes file writing;
Brave's CDP endpoint includes PNG base64 and IPC delivery and readiness polling.
Both browsers use inactive native windows away from the pointer; their capture
workflows have different internal endpoints. GPU execution and services outside
the coalition are excluded. The gate does not establish pure first-render parity.
See [the rendering report](../../../docs/HACKER_NEWS_RENDERING.md) for provenance
and validation results.

`device-layout-inline-precision` checks native scale 2 fractional form-control
heights, fixed line heights, `ex` widths, middle alignment and soft line breaks.
`device-layout-display-density` checks resolution media queries at the same
800×600 viewport and scale 2. Both references use Brave 156.1.98.60 and require
exact RGBA equality.

`rounded-single-border-device-layout` checks all four single solid rounded
border sides, both with zero-width adjacent sides and with transparent adjacent
borders. The transparent widths still inset the inner rounded rectangle and
position the corner miter clips.

`repeating-sprite-boundaries` checks gapless bitmap repetition in both axes and
in each axis separately, including rounded inline borders. Image shaders filter
across repeat boundaries instead of clamping each materialized tile. A rounded
background color, repeated image and adjacent uniform border retain their
multisample coverage in one native pass.

`border-miter-raster-tile` places rounded borders beside a rectangular border
with differently colored sides and diagonal corner clips. Those clips make the
shared GPU raster tile multisampled; a rounded border in the next tile retains
its independent raster mode. These three references use Brave 156.1.98.60 at
800×600 CSS pixels and native scale 2, and require exact RGBA equality.

`dynamic-script-loading` checks two ordered dynamically inserted classic
scripts sharing one URL, followed by a chained script inserted by a load
handler. It turns green only after all executions and trusted load events
complete in order and the window load event follows the chain. Capture at
800×600, scale 1; the native browser and Brave reference are pixel-exact.

`chromium-select` checks the catalog's three menus, right-to-left placement,
an authored tall control, custom borders and colors, and `appearance: none`. Its Brave
156.1.98.60 reference uses an 800×600 CSS-pixel viewport at native scale 2
(1600×1200 image pixels). Compare the complete native-resolution viewport
with exact RGBA equality. The executed reference comparison has zero differing
pixels. Focused layout tests also cover intrinsic sizes and persistent UA
shadow-tree label geometry.

`select-label-ink-clip` checks a label's glyph overhang at half-pixel positions,
narrow labels, RTL, and a borderless `appearance: none` control. Its Brave
156.1.98.60 reference uses
800×600 CSS pixels at native scale 2. Compare the complete
`expected/select-label-ink-clip@2x.png` viewport with exact RGBA equality.
The compact label and persistent UA shadow label both clip overflowing ink;
the focused retained-display-list test checks that their clips match. Two fresh
Brave captures agree exactly, and the production browser matches all 1,920,000
native pixels. The previous production browser differs at 1,179 pixels.
The `chromium-select` reference was also refreshed from two matching independent
Brave captures. Capture commands, hashes and full viewport comparisons are in
`Build/4chan-catalog-20261028-catalog-acceptance-1/`.

`shadow-raster-grid` places outer shadows at integer and fractional positions,
across a root raster tile boundary and at the viewport edge. It includes
rounded corners and an offset, spread shadow. The reference uses Brave
156.1.98.60 at 1024×768 and native device scale 2; the full-resolution
`expected/shadow-raster-grid@2x.png` requires exact RGBA equality. Root shadows
retain the complete Chromium raster tile extent while independent layers keep
their existing surfaces. The scale-1 diagnostic retains 1,424 differing pixels
in both the baseline and candidate, confined to the fractional box and rounded
background; it does not establish scale-1 parity. See
[`CHROMIUM_CATALOG_PARITY.md`](../../../docs/translation-audit/CHROMIUM_CATALOG_PARITY.md)
for capture identities and results.


`svg-rectangular-clip-local-transform` checks a half-pixel rectangular SVG clip
inside transformed CSS surfaces at five page positions. Both references use a
1024×768 CSS viewport; the `@2x` PNG retains scale-two device pixels. Clip
transforms stay local until entering page space, and supported rectangular clip
scopes share path sample coverage. Both scales require exact RGBA equality.
Capture commands, source hashes and fresh-process identities are retained in
`Build/pikabu-rectangular-mask-1793128123792884000/visual-results.json`.

`css-radial-gradient` covers sRGB elliptical and circular fades, layered
backgrounds, hard stops, and a rounded descendant clip at 800×600 and scale 1.
Its Brave 156.1.98.60 reference is pixel-exact. Eligible radial gradients retain
the original stops and use the same Skia path as linear gradients.
The adjacent `diagnostic/css-radial-rounded-border.html` and its unchanged Brave
PNG keep an outer rounded-border case open: eight pixels differ by one level.

CSS blur uses Skia's premultiplied sRGB image-filter path in the Chromium
profile. A supported single gradient retains its drawing commands through
the filter input instead of quantizing to a bitmap before blur.
[`diagnostic/css-blur-radial.html`](diagnostic/css-blur-radial.html) and its
adjacent Brave 156.1.98.60 PNG preserve three cases at 800×600 and scale 1.
The current native output differs at 7,257 pixels, all by one channel level;
this remains a diagnostic, not an exact-parity fixture. The separate existing
`drop-shadow-chain` reference comparison remains pixel-exact.

`system-ui-variable-weight` checks the system UI star at eleven CSS weights,
including 550 and 650, at 800×600 and scale 1. It uses `font-synthesis:none`,
as vlang.io does, and matches Brave 156.1.98.60 exactly. System UI selection
retains the requested variable weight after choosing symbolic traits.
The original default-synthesis case remains in
`diagnostic/system-ui-variable-weight-synthesis.html` with its unchanged Brave
PNG: weight 550 retains 69 differing pixels, maximum channel error 123.
Synthetic bold at intermediate system weights remains open.
