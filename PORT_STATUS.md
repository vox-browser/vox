# LibWeb V translation inventory

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb`

Translation workspace: `~/code/libweb_v`
Audited: 2026-09-05

The earlier inventory mapped every upstream implementation filename to V code,
but filename and symbol-name coverage did not establish behavioral parity. A
semantic re-audit found name-only `upstream_*entry_points.v` coverage-shim
files. Every such file has now been compared with the corresponding upstream
bodies, rewritten where necessary, and promoted under an implementation name;
the current audit has no quarantined coverage files. The remaining `Present`
modules still have upstream bodies that require the same behavioral audit.

`Complete` means every upstream `.cpp` unit has an audited V implementation
mapping. `Present` means translated module code exists but its full upstream
coverage has not yet been audited. `Untranslated` means no module translation
was found. The remaining module rows retain their earlier inventory status
until their own behavioral re-audits are performed.

LOC is physical line count (`wc -l`), including comments and blank lines.
Implementation and test V counts are disjoint. `Selection` includes its shared
`dom/selection.v` implementation, and `UIEvents` includes its shared
`dom/ui_events.v` implementation. Root support and non-LibWeb support modules
are documented separately in `ROOT_SUPPORT.md` and are not included below.
The upstream `Crypto` module maps to the `webcrypto/` V package so it can use
V's standard `crypto.*` modules without shadowing that namespace.
The IDL-only `Fullscreen` package delegates its state machine to the shared
translated DOM implementation.

Inventory reconciliation covers all 75 of 75 upstream module directories and
all 1,147 of 1,147 module-owned `.cpp` implementation units. The four
root-level LibWeb `.cpp` support units are mapped separately in
`ROOT_SUPPORT.md`.

| Upstream module | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ARIA` | 6 | 1,876 | 2,535 | 399 | Complete |
| `Animations` | 10 | 4,381 | 3,028 | 473 | Complete |
| `Bindings` | 9 | 1,718 | 1,731 | 555 | Complete |
| `CSS` | 212 | 66,305 | 99,216 | 6,542 | Present |
| `Clipboard` | 4 | 892 | 973 | 343 | Complete |
| `Compression` | 2 | 359 | 424 | 138 | Complete |
| `ContentSecurityPolicy` | 37 | 4,653 | 2,721 | 439 | Complete |
| `CookieStore` | 2 | 900 | 859 | 434 | Complete |
| `CredentialManagement` | 6 | 369 | 405 | 293 | Complete |
| `Crypto` | 6 | 13,297 | 3,287 | 1,006 | Complete |
| `DOM` | 57 | 26,465 | 36,784 | 2,250 | Complete |
| `DOMURL` | 4 | 1,016 | 754 | 336 | Complete |
| `Editing` | 4 | 7,980 | 3,074 | 741 | Complete |
| `Encoding` | 4 | 438 | 705 | 244 | Complete |
| `EncryptedMediaExtensions` | 3 | 544 | 572 | 329 | Complete |
| `EntriesAPI` | 1 | 55 | 44 | 32 | Complete |
| `EventTiming` | 1 | 131 | 153 | 94 | Complete |
| `Fetch` | 32 | 7,787 | 5,187 | 1,365 | Complete |
| `FileAPI` | 6 | 1,359 | 1,018 | 499 | Complete |
| `Fullscreen` | 0 | 0 | 93 | 177 | Complete |
| `GPC` | 1 | 21 | 16 | 13 | Complete |
| `Gamepad` | 6 | 1,382 | 756 | 274 | Complete |
| `Geolocation` | 4 | 511 | 416 | 176 | Complete |
| `Geometry` | 8 | 2,157 | 2,062 | 1,008 | Complete |
| `HTML` | 261 | 73,434 | 56,234 | 11,896 | Complete |
| `HighResolutionTime` | 2 | 521 | 435 | 195 | Complete |
| `IndexedDB` | 18 | 6,449 | 4,364 | 682 | Complete |
| `Infra` | 3 | 405 | 207 | 63 | Complete |
| `Internals` | 7 | 951 | 854 | 230 | Complete |
| `IntersectionObserver` | 2 | 445 | 569 | 327 | Complete |
| `Layout` | 50 | 19,592 | 34,261 | 11,547 | Present |
| `Loader` | 5 | 887 | 1,111 | 349 | Complete |
| `MathML` | 5 | 292 | 411 | 97 | Complete |
| `MediaCapabilitiesAPI` | 1 | 247 | 389 | 101 | Complete |
| `MediaSourceExtensions` | 8 | 413 | 357 | 110 | Complete |
| `MimeSniff` | 2 | 1,357 | 1,055 | 269 | Complete |
| `MixedContent` | 1 | 121 | 125 | 105 | Complete |
| `NavigationTiming` | 3 | 104 | 291 | 45 | Complete |
| `NotificationsAPI` | 1 | 249 | 290 | 68 | Complete |
| `Page` | 7 | 4,298 | 2,206 | 414 | Complete |
| `Painting` | 48 | 10,038 | 5,061 | 1,286 | Present |
| `PerformanceTimeline` | 5 | 391 | 447 | 130 | Complete |
| `PermissionsPolicy` | 1 | 98 | 86 | 21 | Complete |
| `Platform` | 4 | 415 | 1,167 | 96 | Complete |
| `ReferrerPolicy` | 2 | 298 | 239 | 123 | Complete |
| `RequestIdleCallback` | 1 | 55 | 59 | 18 | Complete |
| `ResizeObserver` | 4 | 376 | 420 | 152 | Complete |
| `ResourceTiming` | 1 | 340 | 330 | 72 | Complete |
| `SRI` | 1 | 191 | 147 | 95 | Complete |
| `SVG` | 80 | 9,570 | 5,066 | 1,015 | Complete |
| `SecureContexts` | 1 | 88 | 59 | 13 | Complete |
| `Selection` | 1 | 744 | 563 | 96 | Complete |
| `Serial` | 2 | 381 | 231 | 33 | Complete |
| `ServiceWorker` | 9 | 1,365 | 919 | 305 | Complete |
| `Speech` | 11 | 504 | 624 | 111 | Complete |
| `StorageAPI` | 7 | 381 | 444 | 235 | Complete |
| `Streams` | 25 | 8,784 | 5,645 | 1,649 | Complete |
| `TrustedTypes` | 7 | 1,108 | 756 | 185 | Complete |
| `UIEvents` | 12 | 1,557 | 1,358 | 378 | Complete |
| `URLPattern` | 1 | 148 | 1,632 | 214 | Complete |
| `UserTiming` | 2 | 164 | 115 | 35 | Complete |
| `ViewTransition` | 1 | 1,046 | 582 | 322 | Complete |
| `WebAssembly` | 6 | 2,157 | 1,057 | 268 | Complete |
| `WebAudio` | 26 | 3,649 | 2,593 | 420 | Complete |
| `WebDriver` | 17 | 5,013 | 3,447 | 638 | Complete |
| `WebGL` | 39 | 7,163 | 3,649 | 328 | Complete |
| `WebIDL` | 10 | 2,110 | 1,564 | 381 | Complete |
| `WebSockets` | 1 | 429 | 312 | 114 | Complete |
| `WebVTT` | 2 | 326 | 445 | 221 | Complete |
| `WebXR` | 3 | 409 | 308 | 86 | Complete |
| `Worker` | 1 | 47 | 81 | 33 | Complete |
| `XHR` | 7 | 1,706 | 1,115 | 340 | Complete |
| `XLink` | 1 | 16 | 13 | 10 | Complete |
| `XML` | 2 | 534 | 414 | 124 | Complete |
| `XPath` | 5 | 438 | 534 | 128 | Complete |
| **Total** | **1,147** | **316,400** | **311,454** | **54,333** | **72 complete, 3 present, 0 untranslated** |

## Verification

The semantic inventory deliberately fails while reviewed upstream bodies are
missing. Its current baseline is:

```text
$ python3 tools/libweb_translation_audit.py
upstream modules: 74
upstream .cpp files: 1147
upstream implementations: 18658
quarantined name-only coverage shims: 0 files / 0 functions
explicit semantic-divergence markers: 11
suspicious empty/default-return implementations: 588
  candidate-name-match: 13956
  unmatched: 1811
  language-constructor-or-destructor: 1182
  gc-or-binding-runtime: 1109
  consolidated-name-match: 312
  namespace-template-specialization: 152
  language-operator: 71
  language-template-trait: 65
unmatched implementations by module:

   707 CSS
   597 Layout
   507 Painting

$ /Users/alex/code/v/v_old -enable-globals run tools/layout_corpus.v --all
Layout corpus: 904 passed, 0 failed, 904 total

$ /Users/alex/code/v/v -enable-globals test css
Summary for all V _test.v files: 26 passed, 26 total.

$ /Users/alex/code/v/v -enable-globals test layout
Summary for all V _test.v files: 18 passed, 18 total.

$ /Users/alex/code/v/v -enable-globals test painting
Summary for all V _test.v files: 7 passed, 7 total.

$ /Users/alex/code/v/v -enable-globals test .
Summary for all V _test.v files: 385 passed, 385 total.
```

Flex and grid layout were additionally checked differentially against the upstream
browser with `tools/layout_dump.v`. Flex: a 489-case generated corpus (directions,
wrapping, justify/align keywords, gaps, box-model edges, order, aspect ratios,
item min/max sizes and auto margins) plus an 80-case `align-self` matrix. Grid: a
715-case corpus (track templates including `repeat()`, `minmax()`,
`fit-content()` and `auto-fill`/`auto-fit`, auto-flow modes, explicit and negative
line placement, spans, template areas, named lines, gaps, and the
justify/align-content/items/self keywords).

The grid corpus agrees with `Build/release/bin/Ladybird.app --headless=layout-tree`
on all 715 cases, and the `align-self` matrix on all 80. The flex corpus agrees on
487 of 489; the two remaining cases differ by one subpixel and are diagnosed under
"KNOWN DIVERGENCE" in `layout/PORT_STATUS.md`.

## Native browser rendering

The translated browser builds as `Build/v/Ladybird.app` and passes its
JavaScript/DOM headless smoke check. Its 800x600 `https://example.com` document
capture was compared with an upstream Ladybird capture from the same checkout:

```text
different pixels: 11888 / 480000 (2.4767%)
pixels with channel error over 10: 6767 (1.4098%)
mean absolute error: 0.6846
RMSE: 7.8784
```

The page geometry and content coincide visually; the remaining pixel delta is
concentrated on glyph edges rendered by the two native text backends. The
layout-test comparison path selects Ladybird's Serenity Sans test face.
Production style and geometry already run through `Document::update_style()`,
`StyleComputer`, `Layout::TreeBuilder`, and the typed formatting contexts. The
active compatibility renderer still adapts that typed tree to `BlockBox` and
`PaintCommand`; this transport conversion is a real remaining handwritten
boundary and is not counted as a completed Painting translation. It replays
retained box commands through
Ladybird's stacking-context phase order instead of painting each flattened box
atomically. Its hit-test path retains the sorted paintable order until stacking
invalidation, resolves the direct DOM owner, and applies inverse transforms and
`pointer-events` filtering instead of rebuilding paint order and rescanning the
DOM for each mouse event. Committed text runs also remain source-shaped
`PaintableFragment`s instead of being expanded into compatibility word objects
and joined again before native shaping. The native shell records through the
translated `Document::record_display_list()` lifecycle; painting and hit testing
share one retained sorted stacking plan, and command storage crosses the native
boundary without a full-array clone. Retained per-paintable `PaintPhase` command
buckets survive document-level repaints, while `PaintableBox` repaint requests
selectively regenerate that box and its anonymous children. Explicit all-cache
and stacking invalidation clear the whole store, matching the separate C++
invalidation boundaries. Checkbox/radio buckets read live DOM checkedness and
indeterminate state rather than a layout-time attribute snapshot; the translated
`HTMLInputElement::set_checked()` invalidation refreshes the retained commands.
Its overlay phase uses Painting's translated scrollbar geometry and
ports PaintableBox's scrollbar colors, mirroring, current-offset placement, and
resize-gripper drawing. Retained replay and hit testing now share translated
`ScrollState` snapshots: a mandatory root frame and live element offsets
transform descendant content, padding-box clips contain overflow, sticky
constraints track element or viewport scrollports and containing blocks, and
fixed contexts remain rooted to the viewport. Accumulated overflow clips retain
their nested transformed shapes and elliptical per-corner radii in shared
context lists; the native Quartz path intersects those shapes with antialiased
rounded clipping rather than reducing them to bounding boxes. CSS basic-shape
`clip-path` now follows the same accumulated-context order as
C++ and retains move, line, quadratic/cubic Bezier, elliptical-arc, close, and
nonzero/even-odd path state. Quartz clips with the exact retained curves, while
hit testing consumes contours flattened once when the paint tree is built;
neither path is reparsed per command or pointer event. Legacy CSS2
`clip: rect(...)` now follows `PaintableBox::get_clip_rect()` too: it is resolved
from an absolute/fixed box's border box, inserted after its transform and before
`clip-path`, and shared by the box's own paint, descendants, and hit testing.
Negative extents become an empty clip and the four edges use the same rounded
device conversion as C++. Five upstream reftest pairs, including transformed,
offscreen, descendant, and image cases, render with zero differing pixels.
`PaintableBox::transform_reference_box()` is translated on the same active path:
CSS boxes remap fill/stroke/view to content/border, SVG paintables remap
content/border to fill/stroke, and SVG view-box transforms use the nearest SVG
viewport. `ViewportPaintable::compute_transform()` now composes individual
`translate`, `rotate`, and `scale` before the transform list. The HTML reference
and both WPT percentage-translate reference pairs are pixel-identical; the
mixed HTML/SVG screenshot improved from 24,212 to 9,859 differing pixels and
MAE 4.6117 to 0.2584, leaving raster-edge and text-antialiasing deltas.
`PaintableWithLines::paint_text_decoration()` and
`build_triangle_wave_path()` now replace the renderer-local decoration
reconstruction. Baselines and font metrics come from committed line fragments;
thickness and endpoints use upstream rounding; double-line offsets, native
dotted/dashed strokes, underline position/offset, and the round-joined triangle
wave follow the C++ switch directly. The anonymous-wrapper, minimum-thickness,
and underline-offset upstream reference pairs are pixel-identical. Native
checkbox and radio foreground painting now uses direct translations of
`InputColors`, `CheckBoxPaintable`, and `RadioButtonPaintable` rather than
renderer-local white boxes and approximate paths. Theme and accent colors,
disabled and active shading, contrast correction, device rounding, rounded
layers, and the exact checkmark path reach the active display list. A focused
upstream control capture has matching geometry and colors; its scale-normalized
MAE is 0.9256, with residuals confined to rasterized edges.
`FieldSetPaintable` now owns fieldset background and border recording on the
active path. Its effective top edge is derived from the rendered legend's
margin box, its background is clipped to the shifted visual border box, and its
top border is replayed only through the device-rounded segments beside the
legend. The recorder-local clips compose with transforms and accumulated
overflow/mask contexts without leaking into descendants or other paint phases;
a transparent-legend capture confirms the former border-through-legend artifact
is gone. Its font-free, scale-normalized upstream comparison has no channel
error above 1 and MAE 0.0244. Geometric list markers also use
`MarkerPaintable::paint()` instead of a renderer-local shape switch. The direct
path preserves CSS-pixel rounding, enclosing device rectangles, exact
disclosure triangles, and typed square/circle/disc commands. Native Quartz now
consumes ellipse commands rather than sending them to the inactive software
surface, restoring the missing circle and disc markers; the five-shape upstream
corpus improves from MAE 0.4082 to 0.1665. Wheel routing follows the C++
containing-block fallback, including
declining
programmatic-only hidden overflow and saturated inner scrollers. These updates
preserve layout and per-phase command caches while refreshing visual scroll
state and dynamic scrollbar thumbs. Uniform rounded box backgrounds now use
one native rounded path, matching the Skia display-list player, rather than a
renderer-local composition of three rectangles and four circles. This removes
six draws per box, fixes translucent corner artifacts, and preserves the arcs
through rotation, skew, and nonuniform scale. The focused nested-overflow
screenshot improved from 103,304 to 4,022 pixels over channel error 3 (MAE
3.2946 to 0.1633); its residual delta is on antialiased path edges. SVG
geometry now reaches the native Quartz renderer as its retained move, line,
quadratic/cubic Bezier, elliptical-arc,
and close segments, including fill rule and stroke cap/join/miter state. URL
`<clipPath>` resources follow `SVGMaskable`'s paint-time path: the attached
resource subtree, target/resource transforms, `userSpaceOnUse` or
`objectBoundingBox` units, per-component `clip-rule`, and component union are
retained in a reusable alpha-mask cache. Empty resources suppress the target;
the mask is deliberately excluded from hit testing, as in C++. SVG `<mask>`
path content now follows the same retained nested-display-list boundary: normal
fill/stroke colors and opacity, `paint-order`, group opacity layers, mask-area
clipping, `maskContentUnits`, and alpha/luminance conversion are composited once
over the complete target context with `destination-in`. URL clips use that same
layer boundary instead of applying antialiased coverage independently to every
leaf command. The shared four-entry native cache rasterizes only each mask's
transformed bounds, not a full-window surface. SVG text is materialized from
the font's TrueType contours into the same quadratic path representation as
`Gfx::Path::text()`, so ordinary text and text inside a mask share SVG
fill/stroke/paint-order and mask compositing. SVG `<textPath>` now follows
`Path::place_text_along()` too: it measures only the referenced path's first
contour, rotates glyph outlines to each tangent, and enforces the glyph-midpoint
cutoff before the same normal or mask path replay. SVG `<image>` now follows
`ImagePaintable` through href/XLink selection, intrinsic-ratio sizing, forced
`contain`, computed object position, `image-rendering` scaling selection,
image-rect clipping, and transformed native bitmap replay. The same ordered
bitmap operations can supply alpha or luminance inside `<mask>`, including
nested group opacity. Canvas boxes now cross the same typed paint boundary:
`CanvasPaintable::paint()` presents an existing surface without allocating one
for untouched elements, retains the RGBA content as `DrawExternalContent`, and
applies upstream scaling-mode selection plus border-shrunken corner clipping.
Native replay consumes that surface directly. URL `<linearGradient>` and
`<radialGradient>` fill and stroke paints now retain C++'s same-document
resource resolution, href
inheritance and precedence, normalized computed stops, `gradientUnits`,
`gradientTransform`, `spreadMethod`, color interpolation, and paint order.
Radial gradients additionally retain the two focal/end circles, `fr`, C++'s
negative-radius inheritance behavior, and width-relative radius resolution.
Quartz consumes both retained styles directly for ordinary paths and mask
content, including pad/repeat/reflect tiling, instead of substituting the URL
paint's fallback color. SVG `<pattern>` now follows C++'s retained paint-server
path as well: same-document href inheritance, first content-owning linked
resource selection, `patternUnits`, `patternContentUnits`, `viewBox`,
`preserveAspectRatio`, CSS-transform precedence, `patternTransform`, and
non-invertible/empty-tile rejection feed a cached tile display list. Tile
content preserves ordered solid, linear/radial gradient, image, nested-pattern,
stroke, and group-opacity operations. Object-bounding-box content is normalized
against the target origin before rasterization, matching the C++ recorder's
content-origin translation. Quartz caches the resulting high-DPI tile and
repeats it for normal fill/stroke and alpha/luminance mask content. Standard CSS
filters now follow `PaintableBox::resolve_css_filter()` and
`ResolvedCSSFilter::to_gfx_filter()`: retained computed blur, drop-shadow,
brightness, contrast, grayscale, invert, opacity, saturate, sepia, and
hue-rotate operations preserve C++ composition order and create one visual
layer around the complete filtered subtree. Filter layers and SVG masks share
one ordered scope stream, so either may correctly contain the other. The native
Core Image replay uses LibGfx's exact color matrices and device-scaled blur and
drop-shadow geometry instead of filtering individual leaf commands. SVG URL
filters no longer use the earlier generic sequential placeholder graph:
`SVGFilterElement::gfx_filter()` is represented with LibGfx constructor input
order and primitive-specific state, including explicit SourceAlpha and
luminance matrices, named-result fallback, blend/composite/arithmetic modes,
component-transfer channel tables, matrix/saturate/hue operations, merge,
morphology, offset, turbulence, displacement, and the specified six-node
drop-shadow expansion. Same-document fragment URLs now resolve the live
`SVGFilterElement`, preserve the standard-CSS-inside/SVG-outside composition
order, and carry the resolved target region and computed flood color/opacity to
native replay. Empty-source, content-generating graphs retain C++'s transparent
target-bounds display-list trigger. Core Image executes flood, every translated
blend/composite mode (including arithmetic and plus-darker), anisotropic blur
and morphology, color matrix/saturate/hue, component-transfer tables, merge,
offset, and channel-selecting displacement while propagating logical graph
extents instead of allocating or flooding the full canvas. Native turbulence
generation and decoded-bitmap `feImage` graph inputs remain outstanding. Its
table phase consumes the translated collapsed and separate border collector,
including conflict winners, cell snapping, empty-cell suppression, and exact
rounded-cell repainting. Ordinary block and inline borders now retain their
computed per-edge styles and consume the direct `BorderPainting.cpp`
translation, including elliptical joins, same-color path batching,
dotted/dashed endpoints, inset/outset colors, and double/groove/ridge recursion.
Outlines resolve their computed style and `auto` accent color, inflate the border
geometry with the C++ negative-offset clamp, and enter the same dispatcher.
URL backgrounds now retain typed layer data and enter the direct
`BackgroundPainting.cpp` sizing/repetition path after decode. This restores the
source ordering for default sizing, contain/cover, `round` aspect correction,
fixed-point positions, `space` gaps, and attachment handling. Cached replay
refreshes local and viewport scroll offsets, while Quartz resolves tiles in CSS
coordinates, then applies the accumulated transform and the layer's shrunken
elliptical clip radii. The previous screen-AABB sizing and stale-scroll paths
are gone. Non-normal URL layers now paint with all 18 translated CSS blend
modes inside the isolated background group required by
`BackgroundPainting.cpp`, rather than blending directly with page content.
Typed linear, radial, and conic gradients now travel through that same ordered
background-image list instead of a separate first-gradient shortcut. Each
gradient is resolved only after `BackgroundPainting.cpp` determines its tile
size with absent intrinsic dimensions, and retains its own origin, clip,
position, size, repetition, attachment, and blend mode. Blocks, inline
fragments, portable SVG, and native Quartz replay all consume the same layer
geometry; transformed native gradients sample in tile-local coordinates and
clip against the exact per-corner elliptical background box.
The gradient parser now follows `GradientParsing.cpp` for interpolation-method
placement, geometry ordering, double-position stops, position-first stops, and
transition-hint attachment. Modern stops select the upstream OKLab default;
legacy stops retain sRGB. Resolved gradients carry that method into every
backend, where the V sampler mirrors `DisplayListPlayerSkia`'s premultiplied
sRGB, linear-sRGB, Lab/OKLab, wide-gamut RGB, and polar-space interpolation,
including hue routing and Skia's powerless-hue neighbor substitution. Portable
SVG uses native sRGB/linearRGB when exact and emits sampled stops for the other
spaces instead of silently falling back to raw sRGB channel mixing.
The same group now implements `background-clip:text`. It records the element's
inclusive-subtree glyph runs, skips absolute/fixed subtrees while retaining
floats, masks the color and all image layers together, and leaves root canvas
backgrounds unmasked. Quartz rasterizes the real configured document font into
one bounded alpha mask before compositing the background group; portable SVG
emits the equivalent user-space text mask.
Full typed Painting
display-list integration remains outstanding.
