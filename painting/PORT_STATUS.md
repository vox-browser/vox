# Painting module V translation — present; active table/overlay/SVG-mask integration

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Painting`

Translation workspace: `~/code/libweb_v/painting`
Audited: 2026-09-05

All 48 upstream `.cpp` implementation units and all 56 adjacent headers have
filename-level mappings. The current semantic audit nevertheless reports 521
unmatched Painting implementations. The V package contains a renderer-independent painting model: CSS
and device geometry, box and border metrics, display-list commands/recording,
playback planning and culling, accumulated visual contexts, scroll/chrome
geometry, gradients/filters/shadows, backgrounds and borders, paintable hit
testing and selection, stacking order, form controls, replaced content, and SVG
path/mask/paint-server behavior.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Painting/` | 48 | 10,038 | 5,061 | 1,286 | Present; table, overlay, SVG paint servers, masks, and filters integrated |

## Independent fidelity audit

The completed translation was cross-checked unit-by-unit against all 48 current
upstream `.cpp` files and all 56 adjacent headers. The audit corrected the
following behavioral mismatches and added focused regressions:

- The four `upstream_*entry_points.v` facade files and their facade-only test
  were removed; the audit currently reports 521 unmatched Painting
  implementations.

- Device-pixel enclosing rectangles now floor the origin but ceil width and
  height independently, matching `DevicePixelConverter` for fractional origins.
- Text fragment point indexing, font ascender/descender selection inflation, and
  visibility/pointer-event gating now match the upstream hit-testing contract.
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
- Bitmap scaling uses Ladybird's exact `None`, `Bilinear`,
  `BilinearMipmap`, and `NearestNeighbor` modes. Smooth/high-quality sampling
  selects mipmapping only when both target dimensions shrink; the invented
  `smooth_pixels` mode was removed.
- Inner shadows retain their distinct expanded outer and spread-adjusted inner
  rectangles and radii, rather than collapsing both geometries into one rect.
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
  2px accent-color behavior for `outline-style:auto`.
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
- CSS gradients now use the same typed, source-ordered layer path as URL images.
  Their absent natural width, height, and aspect ratio are preserved through
  background-size resolution, and linear/radial/conic data resolves against the
  resulting tile rather than the containing border box. Repetition, attachment,
  origin, clip, asymmetric elliptical radii, and blending therefore share the
  translated `BackgroundPainting.cpp` behavior for block and inline backgrounds
  in both native Quartz and portable SVG replay.
- `BackgroundPainting.cpp::compute_text_clip_paths()` now crosses the active
  bridge. Its inclusive-subtree walk records shaped text runs, includes floats,
  prunes absolute/fixed subtrees, and masks the complete background color/image
  group once while exempting the root element. Quartz consumes one bounded
  document-font alpha mask and the portable SVG serializer emits the same
  user-space mask boundary.

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
| `CanvasPaintable.cpp` | `painting_algorithms.v` |
| `CheckBoxPaintable.cpp` | `painting_algorithms.v` |
| `DisplayList.cpp` | `display_list.v` |
| `DisplayListCommand.cpp` | `display_list.v` |
| `DisplayListPlayerSkia.cpp` | `display_list.v` |
| `DisplayListRecorder.cpp` | `display_list.v` |
| `DisplayListRecordingContext.cpp` | `geometry.v`, `display_list.v` |
| `ExternalContentSource.cpp` | `display_list.v` |
| `FieldSetPaintable.cpp` | `painting_algorithms.v` |
| `GradientPainting.cpp` | `effects.v` |
| `ImagePaintable.cpp` | `painting_algorithms.v` |
| `MarkerPaintable.cpp` | `painting_algorithms.v` |
| `NavigableContainerViewportPaintable.cpp` | `painting_algorithms.v` |
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
| `VideoPaintable.cpp` | `painting_algorithms.v` |
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
Painting: 521 unmatched implementations.

$ git diff --check -- painting
(no output; exit status 0)
```
