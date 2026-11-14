# Brave rendering fixtures

Many fixtures below were first matched through the Skia text bridge and the
Graphite/Dawn GPU helpers. Vox no longer builds or loads either; the native
library checks named in older entries (`tools/test_skia_*.py`,
`tools/test_graphite_*.py`, `native_direct_image_pixels_test.mm`,
`test_chromium_image_decode_cache.py`, `test_chromium_screen_blend.py`) were
removed with them. The fixtures and references remain browser regressions.

`pikabu-direct-composited-image` and `pikabu-hoisted-image-clip` keep authored
overflow on the final compositor quad. Commit `81c3204c9` removes a synthetic
first-stage clip, resolving 1,097 differences in each unchanged reference.
`native_direct_image_pixels_test.mm` checks all visible photo pixels and
rounded edges with cold and warm uploads. See the
[direct-image evidence](../../../docs/evidence/pikabu-direct-overflow-20261105.json).

`avif-yuv-sampling` also covers a full-size nearest-neighbor upload followed
by a smaller smooth draw of the same original YUV planes. Commit `4b0036718`
generates GPU mipmaps for that warm upload, removing 34,796 differing pixels
without changing the reference. The native AVIF test checks repeated upgrades
across overlapping document tiles and both multisampling modes. See the
[sampling evidence](../../../docs/evidence/avif-planar-mipmap-upgrade-20261105.json).

`chromium-fractional-fixed-shadow` checks a five-percent shadow in a fixed
compositor picture at 1024×768, scale 1. Its reference comes from two agreeing
fresh Brave captures. The older `0bb14e2f…` production bundle differs by 752
pixels; a native reduction reproducing that screenshot exactly becomes
pixel-identical to Brave when it retains the fractional shadow color. Run
`python3 tools/fixed_shadow_pixels_test.py` against a production bundle
containing `f447b8603`. The installed `f8618e0d…` bundle passes with zero
differing pixels and stable bundle/fixture identities; see
[the ChatGPT report](../../../docs/CHATGPT_BRAVE_PARITY.md).

`chromium-sticky-raster-space` keeps a rounded message and a distant vector
inside the same horizontally translated sticky picture. Two Brave captures
agree at 1024×768, scale 1. The installed `10781424…` bundle is pixel-exact;
the retained stages have 27 and then two differing pixels. Run
`python3 tools/sticky_raster_pixels_test.py`. The planner and native GPU tests
cover live coordinates, sparse contents and layer-local rounded geometry.
See [the ChatGPT report](../../../docs/CHATGPT_BRAVE_PARITY.md) for evidence.

The [forum/news catalog](forum-news.json) has 16 entries, including Discord's
guest homepage. The five new guest-page
archives (TechCrunch, Engadget, The Register, Slate and WIRED) retain full-uBO
source evidence and original encoded response bodies. The Register passes all
strict gates with cold and complete caches; WIRED passes under its recorded
first-frame image policy. See [the expansion report](../../../docs/FORUM_NEWS_EXPANSION.md)
for the pinned builds and remaining gaps. Six original archives pass both strict gates;
CNN's source gate, Reddit access and the two deferred sites remain open.

`hyphenation-closing-punctuation` covers automatic dictionary breaks before
closing quotes and punctuation sequences, alongside manual, language and
capitalization controls. Its 1024×768, scale-1 reference has exact full-uBO source
fidelity and two agreeing fresh Brave replays. Commit `ef0a3531a` improves the
native comparison from 4,094 pixels to zero. Run
`python3 tools/forum_news_inline_pixels_test.py ForumNewsInlinePixelsTests.test_closing_punctuation_keeps_automatic_hyphenation_opportunities`.

`block-border-box-aspect-ratio` covers normal-flow CSS ratio blocks with
border-box sizing, padding, min/max constraints and percentage-height children.
Two fresh ordinary Brave file captures agree with each other and with a clean
full-uBO source capture at 1024×768, scale 1. Full-uBO frozen reducer attempts
failed process cleanup and remain unqualified. The preceding browser differs
by 9,950 pixels. Commit `7b9e6a8ab` corrects the repeated edge deduction and
transfers the final content height to descendants. The production fixture is
pixel-exact on `557eb0c8…`, alongside four SVG, percentage-height and header
controls. See the [Engadget sizing evidence](../../../docs/evidence/engadget-ratio-sizing-20261105.json).

`chromium-degenerate-border-arcs` checks square CSS borders beside rounded
image boxes, with real curved paths in the preceding raster tiles. Its small
opaque PNG is embedded to avoid decoder-path variation. The live full-uBO
source and two fresh Brave replays agree exactly at 1024×768, scale 1; the
native control is exact on `fc1b35e2…`. The Engadget border fix is
`c2deb6773`; the full candidate is native-exact with verified empty and warmed
replay caches on `68cec440…`, while its
295-pixel source-fidelity failure remains open. See the
[arc classification evidence](../../../docs/evidence/engadget-degenerate-arcs-20261105.json).

Oracle visits now require browser exit code zero, no signal and no surviving
observed helpers before a profile can qualify. Each report's `.shutdown.json`
records the initial and remaining owned processes, creation identities,
states and final exit. See the
[shutdown and repaint evidence](../../../docs/evidence/engadget-repaint-oracle-20261105.json).

The registered CNN archive is pixel-exact against Brave with full uBO at
1024×768, scale 1, when both browsers start fresh after complete encoded-response
cache warmups. The separate saved-live/frozen-reference gate remains open.
See the [CNN report](../../../docs/CNN_BRAVE_PARITY.md) for scope and evidence.

The full-site harness records both browser identities before and after every
attempt, including failures. It pins Vox's executable, native libraries and
adblock snapshot, bundled filter helper and checkout runtime assets, and Brave's executable, native frameworks, GPU libraries and
helper executables. Retargeting a framework's active `Current` version also
invalidates the comparison, even when both version directories remain present.

`inline-block-followed-by-full-float` checks that a later full-width float
starts below the completed inline line instead of displacing the earlier
inline block. Its 1024×768 reference comes from two agreeing full-uBO Brave
captures. The preceding production browser differs at 76,001 pixels. Focused
layout checks cover fitting floats on both sides and prevent footer geometry
from inflating the document's scrolling width; production validation is pending.

`svg-auto-ratio-rounding` checks ratio-only inline and block SVGs, explicit
sizes and a minimum width. Its 1024×768 reference comes from two agreeing
full-uBO Brave captures. The preceding browser differs at two pixels, each
showing the same 52-channel-error fringe as Slashdot's Mastodon icon. Focused
layout checks preserve the used auto height when transferring it to width,
along with authored sizes, LibWeb sizing and SVG-image viewports. Production
validation of the new sizing path is pending.

Five focused CNN fixtures cover the solid and repeated SVG header backgrounds,
the rounded header with a captured mask, fractional SVG background pictures,
and a ticker fade beside an unsupported offscreen SVG background. They are
registered in `tools/forum_news_inline_pixels_test.py`. The ticker regression
improves from 63 pixels to zero against two agreeing Brave references. Native
picture-shader checks run with `python3 tools/test_graphite_svg_pattern.py`.

The registered `bbc` guest-page archive now retains the live author CSSOM
rules, original encoded images and the consent-rejected document. At 1024×768,
scale 1, it matches Brave with full uBO exactly when both browsers start with
complete encoded responses. Run `tools/forum_news_pixels.py --sites bbc
--cache-policy complete` with the extension, checker and closed profile options
described in [the site report](../../../docs/ADBLOCK_POPULAR_SITES.md).
This opt-in mode warms each browser in a discarded process before capturing
from a fresh process. Its separate reports retain the cache policy and filter
checks. The default cold native load still has a WebP decoder-state difference
and remains open; the cached result does not qualify cold-load parity.

`stackoverflow-empty-accessibility-clip` checks rounded header controls beside
an accessibility link clipped with `inset(50%)`. Its 800×600, scale 1 reference
comes from two agreeing Brave 156.1.98.60 captures. The fixture is pixel-exact;
recording the invisible path-clipped content changed eight pixels. Recognize
the collapsed path despite its nonempty reference-box bounds, and omit its
paint before compact context flattening. Full-site conformance gaps are tracked
in [the site report](../../../docs/ADBLOCK_POPULAR_SITES.md).

`stackoverflow-bordered-header` checks the same rounded controls beside unequal
header borders and an SVG. Its 1024×768, scale 1 reference comes from two agreeing
Brave 156.1.98.60 captures and is pixel-exact; cropping the shared picture to the
SVG raster safety fringe changed four pixels. Shared recording now derives
painted bounds from the paths and strokes while preserving the padded batch
viewport for rasterization. Run `python3 tools/test_skia_svg_ink_bounds.py` for
the focused AddressSanitizer checks. The native regression harness accepts this
fixture's viewport explicitly and preserves the other fixtures' 800×600 size.

`stackoverflow-sticky-raster-bounds` checks a rounded widget below empty space
in a tall sticky container. Its 1024×768, scale 1 reference comes from two
agreeing Brave 156.1.98.60 captures. The fixture improves from four differing
pixels to zero. Partial recordings snap their tile origin in 128-device-pixel
steps relative to the container, retaining nearby trailing layer edges. Layout
checks cover resizing, both device scales, overflow and nested compositor and
scroll surfaces. The full Stack Overflow page still has separate fallback
renderer differences; see the site report above.

The native fallback for rounded compositor-layer content is checked with
`python3 tools/test_skia_layer_compound.py`. It compares 72 real bridge draws
with independently assembled complete GPU tiles at scales 1 and 2, covering
background/border pairs, filled controls, transparent backdrops and fractional
trailing extents. The portable grid checks preserve off-layer fringes and
rollback failed draws. Both checks use AddressSanitizer and UndefinedBehaviorSanitizer;
the preceding native library fails the same GPU regression.

`forum-disjoint-msaa-raster` checks a rounded control beside an SVG after an
earlier compositor layer interrupts root painting. Its 1024×768, scale 1
reference comes from two agreeing Brave 156.1.98.60 captures. The old fallback
changed two corner pixels despite using the correct tile dimensions and MSAA
mode; it now matches exactly. The auxiliary transparent path used to select
MSAA stays below sample coverage instead of spanning the tile.
`python3 tools/test_graphite_msaa_noop.py` compares 96 filled and stroked
controls with independent Dawn pictures containing a real disjoint path,
including both device scales, fractional positions, translucent colors and
transparent backdrops. The sanitized driver checks every control pixel and
preserves all outside pixels and row padding; the preceding library fails it.

`forum-svg-viewport-fringe` places a vector image at a fractional CSS position.
Its curved path selects multisampling, and a later mask keeps its prefix on
ordinary SVG replay. The 1024×768, scale 1 reference comes from two agreeing
Brave 156.1.98.60 captures. The fixture improves from two differing pixels to
zero. Supported clips are applied in the GPU recording before publication,
preserving resolved coverage at the image viewport edge. Run
`python3 tools/test_skia_svg_clip.py` for 96 independent complete-raster
comparisons and 107 clip eligibility checks with sanitizers. The cases cover
root and compositor layers, both device scales, fractional geometry, rounded
clips and transparent/colored backdrops. The preceding library fails the
same native and browser regressions. Unsupported clips retain their fallback.

`forum-resumed-scroll-raster` checks three SVGs in a scrolling compositor layer,
with translucent paths that interrupt its parent picture. Its 1024×768,
scale 1 reference comes from two agreeing Brave 156.1.98.60 captures. Resuming
the picture previously erased earlier children, changing 398 pixels; it now
matches exactly. A new picture snapshots the painted prefix before fallback
leaves run. An empty canvas retains its fractional layer origin. The native
shared-layer test adds backdrop-hint coverage and transparent parents: 24
two-picture scenarios cover both device scales, translucent/opaque prefixes,
and explicit flushes/layer switches. The retained local-picture, gradient,
shadow, clip and unsupported-content checks also pass with sanitizers.

`forum-svg-mask-backdrop` checks inline and external SVG luminance masks with
black cutout paths over white, plus translucent opacity groups inside alpha
masks. Its 800×600, scale 1 reference comes from two agreeing Brave
156.1.98.60 captures. It improves from 62 differing pixels to zero. Color-mask
paths blend with the translated mask bitmap on the GPU; active Quartz opacity
layers retain their isolated replay. `python3 tools/test_skia_svg_clip.py`
now also compares 96 translated mask draws with complete independent GPU masks,
including fills, strokes, both device scales, colored/translucent backdrops
and row padding. All 288 mapping guards pass; the preceding library and browser
fail the new checks. The native mask-scope harness also covers nested opacity
depth in its 56 cases, in optimized and sanitized modes.

`forum-svg-mask-group-opacity` checks half-opacity and neighboring 0.4-opacity
black cutouts inside luminance masks. Its 800×600, scale 1 reference comes from
two agreeing Brave 156.1.98.60 captures. It improves from 1,600 one-level
differences to exact RGBA equality. Color-mask groups use isolated pooled
bitmaps and the float opacity compositor; nested groups keep distinct contexts
and restore their parent. The mask-scope harness adds 24 independent complete
GPU comparisons across two device scales and six opacity values, plus depth,
legacy-painter and empty-clip fallbacks. Optimized and sanitized checks pass
with the pool enabled and disabled; the existing 56 mask cases remain passing.

`forum-svg-fractional-paint` checks translucent HSL fills and scaled individual
fills/strokes. Its two agreeing 1024×768, scale 1 Brave 156.1.98.60 references
improve from 128 differing pixels to zero. Retained solid paints carry fractional
sRGB channels through leaf and batch replay, key native caches by those values,
and preserve modern/legacy alpha and serialized-paint override checks. The SVG
native driver adds 24 complete-GPU comparisons across both device scales,
fill/stroke replay, and three alpha values.

`forum-svg-single-paint-opacity` uses the exact three sidebar icons and positions
from the Stack Overflow fixture. Two agreeing 1024×768, scale 1 Brave
156.1.98.60 references improve from 60 differing pixels to zero. An eligible
single paint carries the scope opacity in its GPU alpha, avoiding intermediate
bitmap rounding. Matching ownership, unit transforms and rectangular opening
clips are required; other scopes keep their existing replay. Selector and clip
guards pass in both collector modes. The source display list stays balanced.

`forum-fractional-rounded-underlay` places HSL card backgrounds and borders
in the same complete raster tile as a curved SVG. Two agreeing 1024×768,
scale 1 Brave 156.1.98.60 references improve from eight differing pixels to
zero. Shared recordings retain the background components through the border;
standalone fallback leaves keep their existing palette. The native driver
checks 120 shared/fallback color and reset cases and 12 direct GPU descriptors
against independent complete pictures, including both device scales. Cache
keys include optional underlay components. The earlier four-pixel standalone
reduction remains an open diagnostic; this fixture establishes shared-raster
precision only.

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

`scrolling-gradient-raster` checks translucent generated gradients after a
6,400px scroll, including an inset shadow. Capture at 1280×800, scale 1 with
`--screenshot-scroll-y 6400`. The Brave 156.1.98.60 reference is pixel-exact;
the previous bounded raster changed 79,675 pixels. Integral root scrolling
keeps the document's gradient tile coordinates through rasterization. Fractional
scroll offsets and other scales retain their existing path. The
[10px-radius diagnostic](diagnostic/scrolling-gradient-rounded.html) still has
twelve corner differences against its adjacent reference PNG.

`gradient-compositor-backdrop` checks two background gradients inside each
`will-change:opacity` compositor layer. Native gradient replay retains the
readable layer's existing pixels while shifting its dither origin, so GPU
blending happens before the result is quantized. Its 800×600, scale 1 Brave
156.1.98.60 reference is exact; the previous leaf path changed 25,086 pixels. Run the
real GPU backdrop comparison and native tile ownership checks with
`python3 tools/test_skia_gradient_backdrop.py`; both use AddressSanitizer and
the memory guard.

`png-icc-sampling` checks continuous Display P3 colors and alpha at natural,
downscaled and upscaled sizes, with untagged controls at all three sizes. Its
800×600, scale 1 Brave 156.1.98.60 reference is pixel-exact through file and
HTTP loading; the previous CPU conversion changed 2,090 pixels. Prepared
source rows remain premultiplied in their encoded color space. A representable
ICC transfer function and D50 gamut matrix cross the native boundary as plain
values; the GPU upload converts them to an 8-bit sRGB texture before filtering.
This also makes the original compilation thumbnail exact at natural size.
The untagged image is drawn at natural size before its smaller draw. That later
draw upgrades the cached GPU texture with mipmaps instead of uploading a new
CPU-generated mip chain; this removes another 1,014 differing pixels. The
[original diagnostic](diagnostic/png-icc-sampling-controls.html) now matches too.
`image-mip-first-use` checks the opposite order: an image and video poster whose
first draw already needs mipmaps keep the initial CPU-generated levels. This
also preserves the compilation video's poster on vlang.io.

`png-icc-matrix` checks an embedded Display P3 ICC profile on opaque and
translucent pixels, an untagged control, a CSS background, and a resized image.
Its 800×600, scale 1 reference from Brave 156.1.98.60 is pixel-exact through
both file and HTTP resource loading; ignoring the profile changed 38,400 pixels.
The synthetic PNGs contain original four-color artwork and a Skia-generated
matrix profile. Profiles that Skia cannot represent retain the original curves
through the floating-point skcms fallback. Prepared rasters use a 32 MiB,
128-entry cache, and only explicitly tagged PNG buffers consult it. Unsupported
conversions retain the original profile for the Core Graphics fallback.
`python3 tools/test_png_icc.py` checks bounded extraction, retagging, conversion
failure, color-space transport, original-curve fallback and cache eviction under
AddressSanitizer; the browser fixtures exercise GPU conversion and sampling.
This covers packed 8-bit RGB PNGs, including alpha.

`capture-lazy-scroll-order` checks a scrolled capture after the initial viewport's
lazy images have loaded. Serve this fixture over HTTP, capture at 800×600 and
scale 1 with `--screenshot-scroll-y 3200`, and set
`VOX_CAPTURE_INITIAL_VIEWPORT=1`. This opt-in mode presents the initial document
and waits for its requested images and fonts before scrolling, then waits for
the destination viewport as usual. Immediate jump captures keep their existing
behavior. The Brave 156.1.98.60 reference follows that same initial-load order;
skipping the image requests moved the destination by seven pixels and changed
14,191 pixels. File and data URLs complete synchronously and do not reproduce
this HTTP loading sequence.

`table-grid-intrinsic-height` checks a collapsed-border table's contribution to
an automatic grid row against an ordinary block control. The 1280×800, scale 1
fixture matches Brave 156.1.98.60 exactly; the previous extra outer border share
changed 2,328 pixels. Transparent cell borders isolate the container height.
The [visible-table companion](diagnostic/table-grid-intrinsic-height.html),
with its adjacent Brave PNG, also matches exactly, including its text, borders,
and following control. Focused layout cases cover both rendering policies,
odd and even border widths, authored table borders, and top/bottom captions.
The table context positions its vertical origin after border conflict
resolution; callers must not apply the same border adjustment again.

`fractional-gradient-pattern` checks a generated gradient tile beneath a rounded
opaque border, with integer-size and square-corner controls. Its 1280×800,
scale 1 fixture matches Brave 156.1.98.60 exactly; painting the shader directly
differed at 211,888 pixels. When rounded-border bleed clipping disables the
direct image path and the snapped tile cannot cover the original area, retain
the tile's premultiplied raster before blending it over its parent.
The small corner radius isolates tiling from curved-border coverage. The
[larger-radius diagnostic](diagnostic/rounded-gradient-pattern.html) still has
eight one-level corner differences and remains open.

`trailing-empty-block-margins` checks empty paragraphs after ordinary content,
larger collapsing margins, empty-only containers, and grid row sizing. The
800×600, scale 1 fixture matches Brave 156.1.98.60 exactly; the previous output
differed at 97,822 pixels. A formatting-context root consumes the run's collapsed
margin once instead of adding an empty child's placed margin a second time.
Focused cases also cover negative margins, nested empty blocks, and borders
that prevent the margins from collapsing through a child.

`font-synthesis` covers inherited synthesis controls through the `font` shorthand,
synthetic italic, bold and small caps, `oblique-only`, and real bold/italic faces.
The 800×600, scale 1 fixture matches Brave 156.1.98.60 exactly; ignoring the
controls differed at 1,567 pixels. Font matching keeps the requested style while
the inherited longhands independently prohibit manufactured variants. The
regular-only Ahem font comes from Ladybird's `Tests/LibWeb/Ref/data/fonts/`;
its embedded public-domain/CC0 notice is preserved in
[`resources/Ahem-LICENSE.txt`](resources/Ahem-LICENSE.txt).

`multicol-atomic-blocks` covers balanced `break-inside:avoid` blocks with mixed
heights, column-break margins, and two or three columns. The 800×600, scale 1
fixture matches Brave 156.1.98.60 exactly; the previous single-column output
differed at 152,960 pixels. Focused tests also cover RTL, list markers,
collapsible anonymous whitespace, and balanced height contributions to ancestor
grid rows. This slice handles auto-height horizontal columns of atomic blocks.

`nested-grid-block-size` checks auto rows whose block children contain nested
grids. Its 800×600, scale 1 reference matches Brave 156.1.98.60 exactly; the
previous output differed at 112,672 pixels. Intrinsic height measurement must
size a nested grid's rows when its block size is indefinite. A parent-resolved
definite block size still uses the existing measurement shortcut.

`translucent-rect-fill` covers solid alpha fills over three opaque backgrounds,
including legacy alpha, modern fractional color components, and a fractional
box position. The 800×600, scale 1 reference uses Brave 156.1.98.60 and is
pixel-exact. Retaining the source color through Skia's blend removes 184,800
one-level pixel differences from the previous CoreGraphics fill path.

`scrolling-text-raster` checks colored text inside an overflowing scroll container
and an `overflow:hidden` control. The 800×600, scale 1 fixture matches Brave
156.1.98.60 exactly. Contiguous text-only scrolling layers retain a transparent
premultiplied raster before blending over their parent. Direct glyph painting
over the parent differed at 2,734 pixels, each by one channel level.

`select-native-line-height` covers inherited and authored line heights on native
menu lists, plus an `appearance:none` control that retains its authored line
height. The 800×600, scale 1 fixture matches Brave 156.1.98.60 exactly. Resetting
the native menu's line height also gives the vlang.io example picker its 23px
height instead of 26.84px; its width and centered position remain authored.

`lobsters-tag-alignment` extracts the story-title and tag alignment from Lobsters.
It covers middle-aligned bold text, nested inline-block tags, fractional line
heights, and an empty tall inline-block control. All six lines match Brave
156.1.98.60 exactly at 800×600 and scale 1. Run the focused native regression
with `python3 -m unittest discover -s tools -p forum_news_inline_pixels_test.py`.
The test uses the current production bundle in a fresh process without an
automatic rebuild and retains its identities, memory-guard reports and diffs.

`pending-generated-icon-font` covers a webfont used only by generated private-use
glyphs, including `::before`, `::after`, and several font sizes. Its 1024×768,
scale 1 reference agrees across two full-uBO Brave captures. The earlier Vox
build differed at 2,369 pixels; starting the pending author face before selecting
a system fallback makes the fixture exact. Focused layout tests also check the
font-display block/swap periods and an unmatched unicode range. The fixture uses
Slashdot's archived `sdicon.woff` (SHA-256
`625cd71745541c37495055244a8c139e6f3c784b0f5262503ee0f304ee52944e`),
whose embedded notice credits the original authors at fontello.com (2015).

`empty-pseudo-inline-end-edges` covers an empty generated string closing nested
inline boxes, its own end edges, an opening pseudo-element, intrinsic inline
width, and collapsed trailing whitespace. Transparent borders preserve the edge
widths while isolating layout from the separate inline-border painting gap.
Two full-uBO Brave captures agree at 1024×768 and scale 1. The older production
bundle differs at 12,341 pixels. The matching layout tests pass in both GC modes;
see the [Slashdot receipt](../../../docs/benchmark-results/slashdot-brave-pixels-2026-11-02.json)
for the production evidence. This fixture is pixel-exact on the canonical
`192ff348…` production browser.

`chromium-unchecked-radio` covers automatic and authored control sizes,
fractional placement, and a nonsquare control with a half-pixel center. Its two
full-uBO Brave references agree at 1024×768 and scale 1. The pixel test waits
five seconds for native publication; the settled older bundle differs at 556
pixels. Four focused layout/paint cases pass with default GC and `-gc none`,
including native replay coordinates and preserved fallback states. The fixture
is pixel-exact on the canonical `192ff348…` production browser.

`border-color-runs-zero-width` covers transparent triangle borders in four
orientations, two sizes, and a generated comment-bubble tail. Two full-uBO Brave
references agree at 1024×768 and scale 1. The settled older bundle differs at
208 pixels. Three focused cases pass with default GC and `-gc none`, preserving
color boundaries across zero-width or hidden sides and the final same-color
flush. The typed pipeline now retains only the opaque triangle in its visible
path. The fixture is pixel-exact on the canonical `192ff348…` production browser.

`empty-inline-ending-edges` covers ordinary empty descendants and skipped
whitespace at inline box endings, including their own edges and a following
tab stop. Two full-uBO Brave references agree at 1024×768 and scale 1. It exposes
the additional end-edge loss seen in Slashdot's real byline, beyond the empty
generated-content case above. The canonical `c1a609e1…` production browser
improves this fixture from 6,637 differing pixels to zero.

`chromium-mozilla-selector-list` covers a Slashdot search control whose grouped
rule includes `::-moz-placeholder`, another unsupported control alias, a valid
WebKit placeholder, and quoted attribute text. Two full-uBO Brave references
agree at 1024×768, scale 1. Chromium compatibility rejects the entire standard
selector list when it contains Mozilla pseudos; LibWeb retains its aliases.
Seven focused cases also cover escaped names, forgiving branches, parser memo
policy changes, namespaces, `@supports selector()`, and native stylesheet loading.
The canonical `f769e44d…` production browser improves the fixture from 6,761
differing pixels to zero.

`svg-fractional-background-container` covers SVG background aspect-ratio fitting
at automatic, integer, and fractional image sizes. Two full-uBO Brave references
agree at 1024×768, scale 1. The preceding production browser differs at 294
pixels. Keep the SVG layout container at LayoutUnit precision, then map it into
the rounded image bounds. The first candidate fixes only the container and
differs at 429 pixels; native validation of the residual mapping is pending.

`chromium-inline-font-box` covers positioned icon backings, short and tall
atomic children, nested fonts, padding and extra line spacing. Two full-uBO
Brave references agree at 1024×768, scale 1. Baseline-aligned Chromium inlines
use their own ascent/descent for the paint box and positioned containing block.
LibWeb, other writing modes and non-baseline alignment keep their existing
geometry. The first candidate improves 3,591 differing pixels to 1,320; the
atomic-descendant paint-order follow-up is pending native validation. A fifth
typed case also retains the paint baseline when a following clear break grows
the line around a float.

`chromium-transformed-solid-fill` covers opaque rotated squares, chevrons and
a fractional rectangle at two angles. Two full-uBO Brave references agree at
1024×768, scale 1. The preceding production browser differs at 276 pixels.
Chromium solid fills with non-axis-aligned transforms use Skia edge coverage,
as rounded rectangles already do. Native validation is tracked in the Slashdot
receipt.

`chromium-blurred-byte-text-shadow` covers Submit-style text on colored
backdrops, fractional origins, three blur radii, translucent and opaque shadows,
and Helvetica Neue, Arial and Verdana. Two full-uBO Brave references agree at
1024×768, scale 1. The preceding `f769e44d…` production browser differs at
1,059 pixels. The GPU-blending fix has 18 passing native shadow/cache comparisons;
this browser regression awaits a production bundle containing that fix.

`stackoverflow-independent-hyphen-shaping` checks inserted system-font hyphens
at integer and fractional line origins, narrow line fitting, explicit hyphen
controls, and Arial. Its 800×600, scale 1 reference comes from two agreeing
Brave 156.1.98.60 captures and is pixel-exact. Shape the inserted hyphen
independently so the source word cannot kern with it; the previous renderer
differed at 515 pixels, including an incorrectly fitted line.

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

`overlapping-shadow-boxes` checks adjacent transparent boxes with different
transforms and overlapping outer shadows. Their shadow/border pairs share one
root raster pass, skipping only commands culled by ordinary viewport replay.
Visible paint, resource inputs, and compositor boundaries stop the group. The
800×600, scale 1 fixture is exact against Brave 156.1.98.60; resolving each box
separately differed at 192 pixels, all by one channel level.

`rounded-background-border-root` checks backgrounds and uniform borders with
different corner radii after a text mask. A complex SVG in the same raster row
selects multisampling. Each background/border pair shares one root picture;
the 1280×800, scale 1 fixture is exact against Brave 156.1.98.60. Separate draws
previously differed at 15 pixels, all by one channel level.

`rounded-image-clip-transform` checks a minified bitmap inside a translated
rounded clip at 1280×800 and scale 1. Both GPU backends use Chromium's
`SK_SUPPORT_LEGACY_RRECT_TRANSFORM` option, preserving the clip's radii through
the raster transform. The fixture is exact against Brave 156.1.98.60; deriving
the transformed radii from a contour differed at nine pixels. Its image is a
713×540 decoded mip of the frozen vlang.io compilation poster.

`box-shadow-blur` checks square and two rounded outer shadows. The native
Chromium profile uses an isolated Skia 155 Metal backend for these shadows,
including Chromium's legacy rounded clip shader and full precision arithmetic.
The dependency is pinned to Chromium 155.0.8059.80's Skia revision. Its C ABI
exports pixels and plain values only; its hidden Skia symbols cannot interpose
on LibWeb's existing Skia library. Builds require GN and Ninja and cache the
verified dependency under `Build/deps/skia-brave`.

`radial-gradient-float-geometry` checks a percentage-positioned circle and an
explicit ellipse at 1280×800, scale 1. CSS radial gradients retain float center
and radius geometry, and the painter scales the ellipse around that center.
The separate [large ellipse diagnostic](diagnostic/radial-gradient-ellipse-rounding.html)
and adjacent Brave 156.1.98.60 reference retain nine one-level differences;
its geometry matches Brave's recorded shader, but its complete raster is still
open. These checks do not establish full-page vlang.io parity.

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
`device-pixel-underlines` checks auto and explicit underline thickness,
fractional offsets, small-font minimum thickness and ink skipping. Inline SVG
keeps layout in CSS coordinates. Its unchanged Brave reference is a raw
1600×1200 PNG for an 800×600 CSS viewport, `--windowed --scale 2`. The complete
comparison improves from 1,682 differing pixels to **two**, maximum channel
error 3, at the small Arial underline's right end. This remains a known visual
failure; do not normalize or relax the reference.

`device-pixel-shadows` retains the unchanged raw 1600×1200 Brave reference for
an 800×600 CSS viewport, `--windowed --scale 2`. It checks fractional outer
shadow parameters and device-snapped base boxes. The opaque sample matches
exactly; the translucent sample retains **92 differing edge pixels** with
maximum channel error 6. The full comparison improves from 12,093 to 92 pixels
and remains a known visual failure. Do not normalize or relax its reference.

`device-pixel-font-metrics` checks presenting-grid font metrics and half-leading
without scaling the selected font instance. It includes 12px, 14px and 17px
system text, fractional line height, semibold text and normal line height.
Inline SVG keeps layout in CSS coordinates. Its raw 1600×1200 Brave reference
uses an 800×600 CSS viewport, `--windowed --scale 2`, and matches the focused
source browser exactly without downsampling.

`device-pixel-paint-grid` checks device-pixel snapping while inline SVG keeps
HTML layout in CSS coordinates. Fractional solid fills, opaque and translucent
rounded borders, and text-line origins use the presenting grid. Its unchanged
Brave reference is a raw 1600×1200 PNG for an 800×600 CSS viewport, scale 2
(`--windowed --scale 2`). Compare native-resolution pixels without downsampling;
the focused source browser matches exactly. The V regression also changes
display density from 1 to 2 and back, exercising retained paint invalidation.

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

`css-premultiplied-fades` checks linear and radial fades over a dark root
background at 1024×768 and scale 1. Two agreeing Brave 156.1.98.60 captures
provide its reference. It improves from two one-level differences to exact
RGBA equality. CSS root gradients carry an explicit premultiplied interpolation
flag through direct and picture replay; SVG retains straight interpolation.
The raster cache includes this flag. `python3 tools/test_skia_gradient_backdrop.py`
adds four exact Metal/Dawn comparisons for both gradient kinds and modes;
the preceding backend fails the radial CSS case. The isolated compositor
compatibility path retains its existing interpolation because switching that
path alone regresses `gradient-compositor-backdrop` by one pixel. The new
fixture's scale-two diagnostic retains a separate raster mismatch; this is
not a claim of complete Retina or vlang.io parity.

`css-radial-gradient` covers sRGB elliptical and circular fades, layered
backgrounds, hard stops, and a rounded descendant clip at 800×600 and scale 1.
Its Brave 156.1.98.60 reference is pixel-exact. Eligible radial gradients retain
the original stops and use the same Skia path as linear gradients.
The adjacent `diagnostic/css-radial-rounded-border.html` and its unchanged Brave
PNG keep an outer rounded-border case open: eight pixels differ by one level.

`diagnostic/rotated-ellipse-shadow` retains a rotated, clipped orbit over layered
CSS gradients. Two fresh Brave 157.1.99.56 captures agree exactly at 1024×768,
scale 1. The bounded GPU ellipse blur reduces its difference from 26,238 to
1,901 pixels. Commit `50bdd42d6` shares the rotated ellipse's shadows and
border through one resolve and preserves the common rounded clip list, reducing
this to 1,530 pixels in two diagnostic captures. It remains a known failing
diagnostic with an unchanged exact reference; production validation is pending.
`ggshape/rotated_shadow_darwin_test.v` executes equivalent rotated and
axis-aligned ellipse draws and requires exact RGBA equality, visible blur and
an empty clipped interior. Sheared and anisotropic kernels retain the fallback.

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


`culled-scroll-overlap-gradient` covers a gradient grid separated from earlier
paint by a tall gap, with an empty horizontal scroller farther down the page.
Two independent Brave 156.1.98.60 references agree at 1280×800, scale 1 and
scroll Y 6400. The fixture improves from 159,392 differing pixels to zero.
Viewport paint metadata retains the empty scroll boundary and the grid's
compositor origin; complete CSS pictures keep the gradient on that tile grid.
Run `python3 tools/forum_news_inline_pixels_test.py
ForumNewsInlinePixelsTests.test_culled_scroll_metadata_retains_a_complete_gradient_picture`.
The native gradient harness also checks sixteen direct/pattern picture cases.

`compositor-css-gradients` supplies focused layout tests and a diagnostic for
promoted and scrolling panels with direct, repeated and radial backgrounds.
At 1024×768 and scale 1 it improves from 33,850 differing pixels to 24, including
four channel errors of four. It is not an exact screenshot regression. Its
scale-two comparison retains the preceding 86,723 differences. New viewport
metadata and CSS picture eligibility therefore remain restricted to scale 1;
see [the vlang report](../../../docs/VLANG_BRAVE_RENDERING.md) for identities,
controls and remaining page differences.


`compositor-rounded-profiled-images` checks rounded Display P3 and untagged
images at natural and enlarged sizes inside a complete scrolled CSS gradient
picture. Capture at 1280×800, scale 1 and scroll Y 6400. Two fresh Brave
156.1.98.60 references agree exactly; the preceding recorder differs at 65,187
pixels and the current recorder is exact. Run
`python3 tools/forum_news_inline_pixels_test.py ForumNewsInlinePixelsTests.test_rounded_color_managed_images_retain_the_complete_gradient_picture`.
The native gradient harness also runs 200 independent image scenes and payload
validation. Full vlang.io parity and Retina page raster differences remain open.


`translucent-underline-paint-order` checks translucent underlines crossing
antialiased descenders at integer and fractional line origins. Capture at
800×600 and scale 1. The preceding glyph-first order differs at 114 pixels;
the current order matches two independent Brave references exactly. Underlines
and overlines precede glyphs; line-through follows them. Run
`python3 tools/forum_news_inline_pixels_test.py ForumNewsInlinePixelsTests.test_translucent_underlines_paint_beneath_glyph_edges`.
Focused layout checks also cover selected spans, ancestor decorations and the
translated LibWeb profile's existing order.


`gradient-obscured-border-destination` checks repeated linear gradients beneath
opaque rounded borders, including an inset shadow and a fractional-height
pattern tile. Capture at 1280×800, scale 1 and scroll Y 6400. Two fresh Brave
references agree exactly. Trimming ink to the computed background destination
removes all fourteen preceding one-level corner errors while preserving the
original generated-image tile. Run
`python3 tools/forum_news_inline_pixels_test.py ForumNewsInlinePixelsTests.test_gradient_repetitions_stop_at_the_unobscured_background_destination`.
The native harness also compares sixteen Metal image leaves against independent
Dawn pictures, including odd decoded sizes and the float containment boundary.

`compositor-disjoint-scroll-gap` checks a translucent gradient and Times text in
one compositor parent around independently scrolling content and its scrollbar.
Three agreeing Brave 156.1.98.60 captures support its 800×600, scale 1 gold.
It improves from 9,328 differing pixels to exact RGBA equality. Parent spans
isolate only when their native ink is disjoint, including raster fringes;
scrollbar geometry and clipped inset shadows retain their actual bounds.
Run `python3 tools/forum_news_inline_pixels_test.py` for the browser regression.
See [vlang rendering](../../../docs/VLANG_BRAVE_RENDERING.md) for the matched
viewport controls, focused checks, bundle identity, and remaining page differences.

`image-decode-resource-reuse` checks larger decoded-image reuse for the same
resource while identical bytes at separate URLs stay independent. The
`image-decode-compositor-reuse` control keeps concurrent retained pictures'
decode choices independent. `image-decode-scrolling-reuse` settles the initial
viewport and then captures Y 8800, allowing a newly visible picture to reuse a
completed larger decode. The three 800×600, scale 1 golds have agreeing Brave
156.1.98.60 references before/after the fix and in the same-build negative
control. Their differing-pixel counts change from 262/0/262 to 0/0/0. Run
`python3 tools/forum_news_inline_pixels_test.py` for all browser fixtures, and
`python3 tools/test_chromium_image_decode_cache.py` for the bounded native cache
checks. See [vlang rendering](../../../docs/VLANG_BRAVE_RENDERING.md) for build
identities, retained failed reference captures and the footer pixel audit.

`screen-opacity-composite` checks fractional opacity with CSS screen blending,
with and without grayscale. Normal blending and full-opacity screen blending
provide controls. Its 800×600, scale 1 gold has three agreeing Brave references
and improves from 80,000 differing pixels to zero; a separate scale-two capture
is also exact. Run `python3 tools/forum_news_inline_pixels_test.py` for the
browser regression and `python3 tools/test_chromium_screen_blend.py` for the
ASan/UBSan comparison against independent GPU pictures. See
[vlang rendering](../../../docs/VLANG_BRAVE_RENDERING.md) for the sponsor
viewport's gains, remaining edge regressions and preserved negative controls.

The `device-pixel-overflow-clips.html` fixture covers fractional overflow and
CSS `clip` edges in CSS-coordinate layout. At 800×600 CSS pixels and scale 2,
the device-clip source browser matches Brave at zero pixels. The
[device-clip receipt](../../../docs/parity/chatgpt-retina-device-clips-20261103.json)
retains the unchanged reference, control failure, native identities and checks.

`diagnostic/rounded-scaled-png.html` isolates scaled PNGs inside rounded
overflow clips, including vlang.io's fractional Patreon rectangle. The plain
scaled image is a control. Two fresh Brave 157.1.99.56 captures agree exactly
at 600×160, scale 1, with scripts disabled. The V/GPU clip correction reduces
the diagnostic from 2,143 differing pixels to zero in two fresh captures;
the focused GPU test also requires exact logo pixels and preserves pixels
outside a rectangular crop. This diagnostic does not establish full-site parity.

`diagnostic/legacy-gamma-scaled-png.html` retains the source PNG's `gAMA` and
canonical sRGB `cHRM` metadata while drawing at 24px and 20px. Two fresh Brave
157.1.99.56 captures agree exactly at 600×300, scale 1, with scripts disabled.
The focused GPU test requires exact pixels at both sizes, including mipmap
generation after the upload's color conversion. A separate conversion gold
matches an independently pinned previous-renderer readback, preserves alpha
and leaves its input unchanged. The cache test runs with poisoned scratch
memory to verify that temporary decode storage cannot escape into the upload.


`diagnostic/legacy-backdrop-border.html` is an unresolved 1024×768, scale-1
reduction of GitHub's search-border mismatch. Its reference comes from two
identical fresh Brave captures. Production `6bf5db1e` differs at exactly four
pixels: (764,16), (762,18), (801,49), (799,51), with the same RGBA values as the
full GitHub archive's search-border errors. The fractional x=760.75, relative
header, isolated long page and backdrop blur reproduce the original context.
Commit `7019fc7ec` makes the full fixture exact in two diagnostic browser captures
and checks its border band through single and grouped replay. Production
`b6501a1e` now confirms the full search-border fixture exactly twice. See the
[pixel audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#legacy-grid-reduction-2026-11-14).


`diagnostic/shadowed-elliptical-avatar.html` and `resources/shadowed-avatar.png`
cover an anisotropic rounded PNG with an unblurred one-pixel outer shadow.
Two fresh Brave captures agree. Production `6bf5db1e` leaves eight differences
on its white background; `cd0173d0d` matches the full fixture exactly twice.
The corresponding GitHub archive's fifteen avatar differences also disappear.
The GPU test checks a shared resolve against a separated-resolve control and
rejects filtered underlays without mutating the backdrop. Production `314e32e9`
confirms the avatar fixture and GitHub archive exactly twice; see the
[audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#production-confirmation-of-ellipse-and-text-gradient-fixes-2026-11-14).


`resources/gradient-text-linear-mask.png` freezes the retained glyph coverage
for the first line of `input/background-clip-text-retained-gradient.html`.
The focused raster test combines this coverage input with the gradient and
compares against the existing, unchanged Brave reference. A page-origin control
differs at 597 pixels; the text-layer origin is exact with two- and four-pixel
leaf padding. Seven focused checks pass with `f2ee06925`; the complete basic
browser fixture is exact twice at scale 1 in diagnostics and production
`314e32e9`. Higher backing scales retain the
previous renderer path, verified by unchanged Retina captures. This does not
make the fractional, inline or mixed-scope text controls exact; see the
[pixel audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#text-layer-gradient-dither-origin-2026-11-14).

`tall-rounded-shadow` checks an asymmetric 3,069px-tall panel shadow over
opaque blue controls. Two fresh Brave captures agree at 1024×768, scale 1.
Production `d94dced5` differs at 2,114 pixels; `de478eee8` makes the complete
fixture exact twice by restricting axis-aligned filter inputs to each tile's
three-sigma footprint. The separate `diagnostic/tall-rounded-shadow-mask`
control also has agreeing Brave captures and is exact twice in the browser.
Its focused GPU test checks the complete upper shadow band against that
independent reference. Thirteen shadow tests pass with arena poisoning;
production `731ef68c` now confirms both complete fixtures exactly twice. See the
[pixel audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#tile-local-shadow-filter-inputs-2026-11-14).

`input/rotated-translucent-shadow.html` isolates a rotated elliptical shadow
with a faint blue floating-point color over a dark background. Two independent
Brave captures agree, including two canonical-path confirmations. The focused
GPU test checks the shadow through row 279 in both tile sampling modes, exactly;
the initial complete browser capture with `d79672699` retains four one-level
differences. Follow-up `a4b71a733` makes the complete fixture exact twice in
diagnostics by preserving the root compositor grid across an invisible negative
readback fringe. Production `e1925955` now confirms that complete fixture
exactly twice with matching rendering witnesses.
The SVG triangle below that band establishes tile MSAA. The corresponding
opaque `diagnostic/rotated-filter-layer` control stays on the preceding path
and retains 21,069 differing pixels. References and tolerances are unchanged.
The [pixel audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#rotated-shadow-filter-layers-2026-11-14)
records the 23 focused checks, site results and rejected precision experiments.

The root-fringe regression also exercises the real 400×404 readback at `(0,-60)`
through single and grouped drawing, checks the unchanged non-root fallback,
and verifies that outside pixels stay untouched. See the
[root-fringe audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#root-picture-shadow-fringes-2026-11-14).

`rounded-background-border-root` also covers three opaque boxes with uniform,
left-only and right-only rounded corners. Its unchanged Brave reference is
1280×800. The GPU test compares the upper and lower corner bands in their
raster tile: grouped background/border samples are exact, while separated
resolves differ at 24 pixels. `77143c150` makes the complete browser fixture
exact twice, correcting its fourteen errors. Seven focused checks pass;
production `1861ac91` now confirms that complete fixture exactly twice. See the
[shared-rounding audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#rounded-backgrounds-and-borders-in-one-v-raster-group-2026-11-14).

`diagnostic/inset-decoration-samples.html` checks a fractional-position rounded
box and a tall asymmetric box with unblurred inset highlights. Two fresh Brave
captures agree at 1280×800, scale 1. The SVG establishes MSAA in the first tile.
The GPU test uses snapped decoration coordinates and checks both boxes against
the unchanged reference: separate resolves leave nine differences; one resolve
is exact. `f4a40d91b` also makes the complete fixture exact twice in diagnostics
and production `1861ac91`, while the ordinary non-SVG inset fixture stays exact.
Eleven focused checks pass; known blur and repeatability failures remain open.
See the [inset-group audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#shared-unblurred-inset-decorations-2026-11-14).

`diagnostic/large-clipped-orbit.html` uses an empty transform-hinted overlap
barrier to give the tall panel its own picture at y=384. The clipped orbit's
author bounds extend below the visible window. `large-orbit-underlay.html`
keeps the same layout with the orbit hidden. Each unchanged 1024×768, scale-1
reference matches two fresh identity-pinned Brave captures. The GPU test uses
that independent background and compares the final tile's visible RGBA pixels:
window-clipped filter input leaves 485 errors; recorded author bounds are exact.
After `8dc5c0df1`, the complete scene retained 111 differences and its underlay
105. `19224ad53` preserves the promoted gradient picture without optional
hit-test metadata, reducing these to **4 and 3**, twice, with zero new errors.
The unchanged references remain independent; neither fixture is globally exact.
`8dc5c0df1` corrects 469 vlang.io pixels without new differences in diagnostics;
vlang.io remains 341 after the gradient change. Production validation of both
fixes is pending. See the
[recorded-clip audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#recorded-filter-clips-beyond-the-window-2026-11-14)
and [gradient isolation audit](../../../docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#gradient-picture-isolation-without-hit-test-metadata-2026-11-14).
