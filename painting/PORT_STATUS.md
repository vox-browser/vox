# Painting module V translation — present; active table/overlay/SVG-mask integration

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Painting`

Translation workspace: `~/code/libweb_v/painting`
Audited: 2026-09-05

All 48 upstream `.cpp` implementation units and all 56 adjacent headers have
filename-level mappings. The current semantic audit nevertheless reports 417
unmatched Painting implementations. The V package contains a renderer-independent painting model: CSS
and device geometry, box and border metrics, display-list commands/recording,
playback planning and culling, accumulated visual contexts, scroll/chrome
geometry, gradients/filters/shadows, backgrounds and borders, paintable hit
testing and selection, stacking order, form controls, replaced content, and SVG
path/mask/paint-server behavior.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Painting/` | 48 | 10,038 | 5,987 | 1,721 | Present; table, overlay, SVG paint servers, masks, and filters integrated |

## Independent fidelity audit

The completed translation was cross-checked unit-by-unit against all 48 current
upstream `.cpp` files and all 56 adjacent headers. The audit corrected the
following behavioral mismatches and added focused regressions:

- The four `upstream_*entry_points.v` facade files and their facade-only test
  were removed; the audit currently reports 417 unmatched Painting
  implementations.

- Device-pixel enclosing rectangles now floor the origin but ceil width and
  height independently, matching `DevicePixelConverter` for fractional origins.
- Text fragment point indexing, font ascender/descender selection inflation, and
  visibility/pointer-event gating now match the upstream hit-testing contract.
  The active shared predicate also rejects inert DOM nodes. Anonymous middle
  boxes created for split inline continuations keep a separate principal-inline
  fallback identity, matching `PaintableBox::hit_test_continuation()` without
  changing their paint or cache ownership.
- Equal table-border conflicts prefer the earlier left/top edge; indeterminate
  checkbox dash geometry and the resize cursor fallback follow their native
  implementations.
- Clip paths and SVG paths preserve nonzero/even-odd winding rules. SVG mask and
  clip display lists translate to mask-local coordinates, traverse descendants,
  and clip paths paint raw geometry without inherited fill/stroke rendering.
- The active browser retains ordinary SVG paths as exact curves/arcs with their
  computed fill rule and stroke cap/join/miter state. URL `<clipPath>` resources
  become paint-time alpha masks with exact per-component geometry, transforms,
  clip rules, union semantics, empty-resource suppression, and a bounded native
  raster cache. They do not constrain hit testing, matching `StackingContext`.
- URL `<mask>` path content now retains the nested display-list order, normal
  fill/stroke paints and opacity, `paint-order`, group-opacity layers,
  `maskContentUnits`, masking area, and alpha/luminance mask type. Balanced
  begin/end controls apply both masks and clips once to the composited target
  with `destination-in`, rather than once per leaf draw. The shared four-entry
  cache uses cropped transformed bounds so Retina masks do not allocate a full
  window surface per entry. SVG text is converted from TrueType contours to
  retained quadratic path segments before this boundary, so text masks reuse
  the same path operations rather than a separate text-mask implementation.
- `ImagePaintable` now crosses the active SVG boundary too. Ordinary `<image>`
  content keeps its image rectangle, forced `contain` fit, computed object
  position, translated scaling-mode selection, clip, and accumulated CSS
  transform. Image operations nested in an
  SVG mask retain source order and group-opacity boundaries and feed the same
  cached alpha/luminance surface as path content. The native image bridge
  handles both file-backed `NSImage` values and stb-decoded RGBA buffers rather
  than miscasting decoded pixels as Objective-C objects.
- Ordinary HTML and SVG replaced images now run the decoded frame through a
  direct translation of `ImagePaintable::paint()` instead of disguising it as
  a no-repeat CSS background and reparsing `object-fit`/`object-position`
  strings in the renderer. The source-ordered path preserves float aspect-ratio
  selection, fixed-point fitted-size and position rounding, `scale-down`, SVG's
  forced `contain`, and the source quirk that chooses scaling mode from the
  content-box size rather than the fitted destination. Its corner clip uses
  normalized radii shrunken by the four border widths. A six-case
  fill/contain/cover/none/scale-down differential capture reduced MAE from
  2.7990 to 2.1765, maximum channel error from 221 to 65, and pixels above 50
  channel error from 527 to 23; the remaining error is raster-edge
  antialiasing. The direct single-image replay also removes background tile
  allocation and string parsing from every replaced-image paint. SVG images
  nested in masks and pattern tiles consume this same result instead of the
  renderer-local `contained_image_destination()` shortcut.
- `CanvasPaintable::paint()` is now a direct foreground-phase translation
  instead of a test-only helper that incorrectly classified canvas content as
  `DrawScaledBitmap`. The typed layout bridge presents an existing canvas
  surface without allocating one for untouched elements, retains its RGBA
  bitmap, selects the source `DrawExternalContent` scaling mode, and clips it
  with normalized radii shrunken by the element's borders. Native replay now
  draws that external content; Canvas JavaScript bindings remain a separate
  HTML host gap, so the active integration is exercised through the translated
  Canvas 2D API.
- `VideoPaintable::paint()` now carries the source representation switch into
  the active typed bridge. First/current video frames become
  `DrawExternalContent`, poster frames become `DrawScaledBitmap`, and the
  no-data state records transparent black. Every branch uses the rounded video
  rectangle, translated image scaling, the explicit rectangular clip, and
  normalized border-shrunken corner radii. The native RGBA bridge replays both
  frame kinds while media decoding remains the existing host boundary.
- `NavigableContainerViewportPaintable::paint()` now records the hosted
  `srcdoc` document as a nested display list in the active typed bridge. It
  updates child layout at the iframe content size, retains child commands
  instead of rasterizing them, applies both the source rectangular and
  border-shrunken rounded clips, and composes the embedding transform into
  child commands, clip paths, mask operations, and nested opacity at replay.
- `SVGLinearGradientPaintStyle` now crosses the active path and mask boundaries
  without being reduced to an SVG paint fallback color. Resource href
  precedence and inheritance, monotonic computed stops, object-bounding-box and
  user-space coordinates, `gradientTransform`, pad/repeat/reflect spread,
  sRGB/linear-RGB interpolation selection, fill/stroke opacity, and paint order
  are retained. Quartz clips the exact fill or stroked path and consumes that
  style as a native gradient shader; the portable SVG serializer consumes the
  same retained value.
- `SVGRadialGradientPaintStyle` crosses those same boundaries without reducing
  its focal circle to a one-center approximation. Start/end centers and radii,
  `fr`, linked coordinate inheritance, negative-radius fallback, transforms,
  spread, interpolation, opacity, masks, and paint order remain retained for
  Quartz's native two-circle radial shader and the portable SVG serializer.
- `ClipPathData` now retains the source Gfx-style move, line, quadratic/cubic
  Bezier, elliptical-arc, and close segments alongside one-time flattened
  hit-test contours. Multiple subpaths combine under the selected winding rule,
  so even-odd holes no longer collapse into a bounding rectangle.
- The display-list recorder now exposes guarded typed entry points for paths,
  ellipses, gradients, bitmaps, lines, rounded fills, filters and shadows, and
  implements balanced alpha/luminance mask layer recording.
- Display-list commands now own the source-shaped `bounding_rect()`, `dump()`,
  and clip predicates from `DisplayListCommand.{h,cpp}`. Generic culling and
  diagnostics are thin variant dispatchers over those methods instead of a
  second handwritten set of geometry rules. Glyph-run culling also rounds its
  fractional translation like upstream rather than truncating it.
- Bitmap scaling uses Ladybird's exact `None`, `Bilinear`,
  `BilinearMipmap`, and `NearestNeighbor` modes. Smooth/high-quality sampling
  selects mipmapping only when both target dimensions shrink; the invented
  `smooth_pixels` mode was removed.
- Inner shadows retain their distinct expanded outer and spread-adjusted inner
  rectangles and radii, rather than collapsing both geometries into one rect.
  Their command types now own the translated `bounding_rect()` and `dump()`
  methods used by generic display-list culling and diagnostics. Corner spread
  adjustment and mix-blend conversion likewise use the upstream helper entry
  points instead of equivalent logic hidden under port-only names.
- `ShadowPainting.cpp::paint_box_shadow()` and
  `PaintableBox::paint_box_shadow()` now drive the active block paint path.
  Layers are recorded back-to-front after the background exactly where C++
  records them; outer shadows use the border box while inset shadows use the
  padding box, preserve separate elliptical radii for every shape and scoped
  clip, and keep the source fixed-point rounding and spread adjustment. Quartz
  replays the same outer difference clip and inner outer-minus-inner path as
  Skia with a shadow-only blur mask; the portable SVG backend consumes the same
  retained geometry. The legacy scalar shadow path remains only for inline
  fragment compatibility.
- Stacking-context painting now recursively paints nested negative, zero, and
  positive contexts in `(z-index, tree order)` order. Zero-opacity and
  non-invertible contexts suppress their complete subtrees, matching the early
  exits in `StackingContext::paint()` rather than returning a flat list of only
  direct child identifiers.
- The active Layout compatibility bridge now imports Painting's translated
  scrollbar geometry for its overlay phase and follows `PaintableBox::paint()`
  for scrollbar ordering/colors, chrome mirroring, thumb placement, and the
  resize-gripper line loop. This is a concrete one-way Layout-to-Painting use,
  although the native browser does not yet use Painting's retained display list.
- The same active path now calls direct translations of
  `PaintableBox::overflow_property_applies()`, `physical_resize_axes()`,
  `has_resizer()`, and `is_chrome_mirrored()`. A focused predicate matrix
  covers all source exclusions and table exceptions, viewport/generated
  suppression, logical-axis mapping in horizontal and vertical writing modes,
  clipped axes, and RTL/vertical chrome mirroring.
- `PaintableBox::available_scrollbar_length()`,
  `absolute_scrollbar_rect()`, `compute_scrollbar_data()`, and
  `absolute_resizer_rect()` now form the active scrollbar geometry pipeline.
  The decomposition preserves upstream's asymmetric horizontal/vertical gutter
  adjustments and signed resizer-adjusted rectangles for undersized boxes,
  while retaining thumb margins, minimum length, travel ratio, mirroring, and
  gutter enlargement.
- `PaintableBox::nearest_scroll_frame_index()` now drives the active Layout
  bridge. Fixed paintables and ordinary descendants behind a fixed containing
  block use the root frame, while sticky descendants keep searching for their
  outside scrollport, matching the upstream exception.
- `PaintableBox::nearest_scrollable_ancestor()` is translated separately for
  sticky percentage-inset resolution. It skips programmatically scrollable
  `overflow:hidden` frames and stops beyond a fixed containing block, exactly as
  the source containing-block walk does.
- `PaintableBox::overflow_clip_edge_rect()` is separated from the surrounding
  viewport clip builder on the active path. It preserves the replaced-element
  content-box exception and asymmetric per-edge overflow-clip-margin inflation.
- `TableBordersPainting.cpp` is now a dedicated source-shaped translation. It
  snaps spanned cells to shared device-pixel grid lines, emits each collapsed
  edge once, sorts intersections by border and element specificity, preserves
  dashed/dotted edges, applies `empty-cells: hide` in separate mode, and sends
  separate and radiused-cell repainting through the translated
  `paint_all_borders()` path. Layout retains the winning conflict border's
  typed style, width, color, and originating table element, and the active
  renderer consumes the resulting table-border phase.
- `BorderPainting.cpp`'s border-color adjustment, tangent-slope corner split,
  elliptical outer/inner arcs, same-color path batching, dotted/dashed endpoint
  shortening, and recursive double/groove/ridge bands are translated directly.
  The Layout bridge preserves per-edge styles and converts `FillPath` without
  flattening away its even-odd winding or arc segments; the native renderer
  consumes the retained path data. Outlines use the same translated dispatcher,
  including CSS UI's negative-offset clamp, radii inflation, and the resolved
  2px accent-color behavior for `outline-style:auto`. The active adapter now
  obtains color, style, and width together from a direct
  `PaintableBox::outline_data()` translation, including the shared invisible
  outline suppression.
- `BackgroundPainting.cpp`'s per-layer sizing and repetition path is now direct
  rather than a renderer-local approximation. Typed `BackgroundLayerData`
  reaches Painting intact; default sizing, contain/cover, `round` resizing and
  one-axis aspect restoration, fixed-point position resolution, `space` gaps,
  and fixed/local/scroll attachment run in the C++ source order. Retained replay
  refreshes local and viewport scroll offsets without rebuilding phase caches.
  The native image command resolves in CSS coordinates before applying the
  accumulated transform and clips with the layer's exact shrunken elliptical
  radii. Compatibility tile materialization is bounded before allocation. URL
  layers with any of the 18 CSS blend modes paint over the color and lower
  layers inside the isolated group required by the compositing specification;
  Quartz and the portable SVG serializer consume the same retained mode.
- The root/body branches of `PaintableBox::paint_background()` now keep the
  body's `image-rendering` value when its background properties are propagated
  to the root canvas, matching the source's explicit sampling-mode override.
- CSS gradients now use the same typed, source-ordered layer path as URL images.
  Their absent natural width, height, and aspect ratio are preserved through
  background-size resolution, and linear/radial/conic data resolves against the
  resulting tile rather than the containing border box. Repetition, attachment,
  origin, clip, asymmetric elliptical radii, and blending therefore share the
  translated `BackgroundPainting.cpp` behavior for block and inline backgrounds
  in both native Quartz and portable SVG replay.
- The active linear/radial/conic stop resolver now calls the shared
  `GradientPainting.cpp` translation instead of maintaining a second Layout
  interpolation and repeat-expansion implementation. Transition hints use the
  source `Gfx::color_stop_step()` exponent, so a non-centered hint is the actual
  50/50 color midpoint rather than a linearly weighted sample.
- `BackgroundPainting.cpp::compute_text_clip_paths()` now crosses the active
  bridge. Its inclusive-subtree walk records shaped text runs, includes floats,
  prunes absolute/fixed subtrees, and masks the complete background color/image
  group once while exempting the root element. Quartz consumes one bounded
  document-font alpha mask and the portable SVG serializer emits the same
  user-space mask boundary.
- Uniform rounded box backgrounds now follow `DisplayListPlayerSkia`'s single
  rounded-path draw in the native renderer. The previous renderer-local
  reconstruction used three rectangles and four `gg` circles, performed seven
  draws per box, blended the corner circles with an unintended 75% alpha, and
  discarded the corner arcs under rotation or skew. The retained local path is
  now transformed as a unit for opaque and translucent colors. On the upstream
  `nested-boxes-with-hidden-overflow-and-border-radius` screenshot this reduced
  pixels with channel error over 3 from 103,304 to 4,022 and MAE from 3.2946 to
  0.1633; the remaining delta is confined to antialiased path edges.
- `PaintableBox::get_clip_rect()` now crosses the active visual-context bridge
  directly. CSS2 `clip: rect(...)` is limited to absolute/fixed boxes, resolves
  auto and length edges from the absolute border box, maps negative extents to
  the upstream empty rectangle, and clips the box itself, all descendants, and
  hit testing in the same transform-before-clip order as C++. Clip edges now
  use `DevicePixelConverter::rounded_device_rect()` semantics instead of the
  former floor/ceil expansion. All five relevant upstream reftest pairs render
  with zero differing pixels; `clip.html` improved from 5,166 to zero.
- `PaintableBox::border_radii_data()` and the corresponding final hit-test gate
  now use the resolved, normalized elliptical radii retained by the typed paint
  tree. Points inside the rectangular border box but outside a rounded corner
  no longer select that paintable, matching the upstream hit-test traversal.
  The active construction path retains `CSSPixels` and exact
  `CSSPixelFraction` overlap factors through both source refinement passes
  before crossing the f64 transport boundary. Its
  `normalized_border_radii_data()` translation only performs the requested
  adjacent-border shrink, without the former extra padding-box normalization.
- `PaintableBox::absolute_united_border_box_rect()`,
  `absolute_united_content_rect()`, and
  `absolute_united_padding_box_rect()` now walk the retained split-inline
  continuation chain and unite its nonempty absolute boxes. The upstream
  `HTMLElement-offsetFoo-for-split-inline-element` case matches all four
  expected CSSOM offsets.
- `PaintableBox::transform_reference_box()` now selects the source-shaped
  content/border/fill/stroke/view reference rectangle for HTML and SVG boxes,
  including the nearest SVG viewport and upstream's current fill/stroke
  approximations. `ViewportPaintable::compute_transform()` composes individual
  `translate`, `rotate`, and `scale` ahead of `transform`, with percentages and
  transform origins resolved against that rectangle. Three upstream reftest
  pairs are pixel-identical. The comprehensive `css-transform-box` screenshot
  improved from 24,212 to 9,859 differing pixels and MAE from 4.6117 to 0.2584;
  the residual is raster-edge and text-antialiasing variance.
- `PaintableWithLines::paint_text_decoration()` and
  `build_triangle_wave_path()` replace the former hand-built fill rectangles,
  ellipses, and wave polygons. The active path retains the line builder's exact
  baseline and font metrics, rounds endpoints and thickness in device space,
  and preserves C++'s per-style double offsets, native dotted/dashed strokes,
  underline position/offset, spelling/grammar colors, and round cap/join wave
  path. The anonymous-wrapper, minimum-thickness, and underline-offset upstream
  reference pairs are pixel-identical.
- Text selection now crosses the active retained-paint path through direct
  translations of `Paintable::selection_style()`, `PaintableFragment` range
  selection, `compute_render_spans()`, `paint_text_shadow()`, and
  `paint_text_fragment()`. The bridge preserves explicit-property inheritance
  rules and the UA shadow-host fallback, text-control precedence, UTF-16 span
  boundaries, `-webkit-text-fill-color`, replacement selection shadows and
  decorations, clipped full glyph runs, and the source background/shadow/text
  ordering. Selection-state changes invalidate the owning retained phase cache.
  Geometry walks the committed `GlyphRun` directly rather than constructing a
  second per-paint glyph-metric vector, while the common no-selection/no-shadow
  path keeps its coalesced fast path. Quartz replays blurred text-shadow masks;
  the portable backend retains the same layer order with sharp shadows.
- `InputColors.h`, `CheckBoxPaintable::paint()`,
  `RadioButtonPaintable::paint()`, and `check_mark_path()` now feed the active
  renderer instead of hard-coded white rectangles, ellipse strokes, and an
  approximate tick polygon. The bridge retains computed scheme and accent
  color, reads checked, indeterminate, enabled, and activation state at paint
  time, and preserves C++ shading, contrast correction, device rounding,
  rounded layers, indeterminate dash, and exact scaled path. A focused upstream
  capture matches geometry and colors; its scale-normalized MAE is 0.9256 from
  rasterized edges.
- `FieldSetPaintable::effective_border_top()`,
  `visual_border_box_rect()`, and its specialized border phase now replace the
  generic box-paint shortcut. The bridge retains the rendered legend's margin
  and border boxes, clips only the fieldset background to the shifted visual
  border box, paints side/bottom borders there, and replays the top border in
  the two device-rounded clips beside the legend. Phase-local recorder clips
  compose with accumulated transforms, overflow clips, and masks without
  affecting descendants. The retained-list regression fixes the exact
  208-by-88 test box to a 208-by-78 visual box and verifies the two top-border
  clips. A font-free, scale-normalized upstream capture has no channel error
  above 1 and MAE 0.0244.
- `MarkerPaintable::paint()` now replaces the active renderer-local marker
  switch. It rounds the marker rectangle in CSS pixels before enclosing it in
  device space, emits the translated square/circle/disc display-list commands,
  and retains the exact equilateral disclosure paths with even-odd winding.
  Native Quartz now replays fill/stroke ellipse commands under the accumulated
  transform instead of losing them on the inactive software surface. Circle and
  disc markers reappear in the five-shape differential corpus, reducing MAE
  from 0.4082 to 0.1665; the residual is confined to antialiased edges.

## Implementation-unit mapping

| Upstream implementation unit | V implementation |
| --- | --- |
| `AccumulatedVisualContext.cpp` | `visual_context.v` |
| `BackgroundPainting.cpp` | `painting_algorithms.v` |
| `BackingStoreManager.cpp` | `scrolling.v` |
| `Blending.cpp` | `effects.v` |
| `BorderPainting.cpp` | `painting_algorithms.v` |
| `BorderRadiiData.cpp` | `box_model.v` |
| `BorderRadiusCornerClipper.cpp` | `display_list.v` |
| `BordersData.cpp` | `box_model.v` |
| `BoxModelMetrics.cpp` | `box_model.v` |
| `CanvasPaintable.cpp` | `canvas_paintable.v` |
| `CheckBoxPaintable.cpp` | `painting_algorithms.v` |
| `DisplayList.cpp` | `display_list.v` |
| `DisplayListCommand.cpp` | `display_list.v` |
| `DisplayListPlayerSkia.cpp` | `display_list.v` |
| `DisplayListRecorder.cpp` | `display_list.v` |
| `DisplayListRecordingContext.cpp` | `geometry.v`, `display_list.v` |
| `ExternalContentSource.cpp` | `display_list.v` |
| `FieldSetPaintable.cpp` | `painting_algorithms.v` |
| `GradientPainting.cpp` | `effects.v` |
| `ImagePaintable.cpp` | `image_paintable.v` |
| `MarkerPaintable.cpp` | `painting_algorithms.v` |
| `NavigableContainerViewportPaintable.cpp` | `navigable_container_viewport_paintable.v` |
| `PaintStyle.cpp` | `svg_painting.v` |
| `Paintable.cpp` | `paintable.v` |
| `PaintableBox.cpp` | `paintable.v`, `scrolling.v`, `painting_algorithms.v` |
| `PaintableFragment.cpp` | `paintable.v` |
| `PaintableWithLines.cpp` | `paintable.v` |
| `RadioButtonPaintable.cpp` | `painting_algorithms.v` |
| `ResizeHandle.cpp` | `scrolling.v` |
| `ResolvedCSSFilter.cpp` | `effects.v` |
| `SVGClipPaintable.cpp` | `svg_painting.v` |
| `SVGForeignObjectPaintable.cpp` | `svg_painting.v` |
| `SVGGraphicsPaintable.cpp` | `svg_painting.v` |
| `SVGMaskPaintable.cpp` | `svg_painting.v` |
| `SVGMaskable.cpp` | `svg_painting.v` |
| `SVGPaintable.cpp` | `svg_painting.v` |
| `SVGPathPaintable.cpp` | `svg_painting.v` |
| `SVGPatternPaintable.cpp` | `svg_painting.v` |
| `SVGSVGPaintable.cpp` | `svg_painting.v` |
| `ScrollFrame.cpp` | `scrolling.v` |
| `ScrollState.cpp` | `scrolling.v` |
| `Scrollbar.cpp` | `scrolling.v` |
| `ShadowPainting.cpp` | `effects.v` |
| `StackingContext.cpp` | `paintable.v` |
| `TableBordersPainting.cpp` | `table_borders_painting.v` |
| `TextPaintable.cpp` | `paintable.v` |
| `VideoPaintable.cpp` | `video_paintable.v` |
| `ViewportPaintable.cpp` | `paintable.v`, `scrolling.v`, `visual_context.v` |

The former consolidated C++ class-name facades
`upstream_paintable_entry_points.v`, `upstream_display_entry_points.v`,
`upstream_value_entry_points.v`, and `upstream_algorithm_entry_points.v` are
removed and do not count as translated implementations.

The native browser still converts the typed Layout tree to a compatibility
`BlockBox` tree and emits `layout.PaintCommand` values; it does not yet construct
upstream-shaped `Paintable` objects or record through Painting's display list.
The active Layout bridge now uses retained-reference traversal, linear text-run
building, and O(n log n) z-order sorting, removing its known subtree-copy,
quadratic concatenation, and insertion-sort costs. It also translates the
ordering in `StackingContext::paint_internal()` into separate background,
border, float, inline/replaced, foreground, zero/auto, positive, and outline
replay phases, skips zero-opacity/non-invertible contexts, and records a final
overlay phase using `painting.compute_scrollbar_data()`. Full Painting
integration remains required for typed paintables, recorder-side phase caches,
interactive scroll-state replay, and specialized SVG phases. The table border
phase and the general `BorderPainting.cpp` path are translated and active for
ordinary boxes, inline fragments, form-control frames, outlines, and table-cell
repainting.
URL and gradient background layers use the translated `BackgroundPainting.cpp`
geometry, a single CSS-ordered layer list, and isolated blend groups in native
replay. Their `background-clip:text` group mask is active too.
The URL SVG clip and path/text/image mask phases are active, including glyph
outlines placed along a referenced path and bitmap content under nested opacity.
Linear- and radial-gradient fill/stroke paint servers are active in ordinary
paths and path mask operations, as are linked SVG patterns. Standard CSS filters
and same-document SVG URL filters share the retained visual-layer stream. The
SVG graph preserves C++ node inputs, named-result fallback, SourceAlpha,
primitive state, resolved target bounds, and the transparent paint trigger for
source-independent output. Native replay implements flood, blend,
composite/arithmetic, anisotropic blur and morphology, matrix/saturate/hue,
component-transfer tables, merge, offset, and channel-selecting displacement.
Native turbulence generation and decoded-bitmap `feImage` graph inputs remain
the specialized SVG-filter gaps.

Header-only APIs are represented alongside their implementation families:
`ChromeMetrics` and border/box data in `box_model.v`; `ChromeWidget`, resize,
scroll frames and scroll state in `scrolling.v`; `DevicePixelConverter` in
`geometry.v`; gradient, shadow and filter data in `effects.v`; display-list
commands, paint phases and anti-alias flags in their owning V types; and SVG
paint styles in `svg_painting.v`.

## Platform boundaries

- `DisplayListPlayerSkia.cpp`'s Skia calls are represented by deterministic
  playback actions. Context switching, save/restore balancing, command bounds,
  clipping/culling, effect pre-culling, and scroll-thumb translation execute in
  V; backend rasterization remains the native renderer boundary.
- GC cells and Layout/DOM ownership become stable typed identifiers and explicit
  geometry/state inputs. Painting algorithms do not fabricate a DOM or garbage
  collector inside this module.
- Native bitmap, IOSurface/Vulkan, font/glyph and video resources remain opaque
  immutable identifiers. Their replacement, clearing, sizing and display-list
  handoff semantics are implemented and tested.
- CSS style parsing and layout resolution remain in the translated `css` and
  `layout` modules. Painting consumes resolved values, matching the upstream
  subsystem boundary.

## Verification

```text
$ /Users/alex/code/v/v -enable-globals test painting
Summary for all V _test.v files: 7 passed, 7 total.

$ python3 tools/libweb_translation_audit.py
Painting: 417 unmatched implementations.

$ git diff --check -- painting
(no output; exit status 0)
```
