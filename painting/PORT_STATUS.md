# Painting module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Painting`

Translation workspace: `~/code/libweb_v/painting`
Audited: 2026-08-29

All 48 upstream `.cpp` implementation units and all 56 adjacent headers were
audited. The V package implements the renderer-independent painting model: CSS
and device geometry, box and border metrics, display-list commands/recording,
playback planning and culling, accumulated visual contexts, scroll/chrome
geometry, gradients/filters/shadows, backgrounds and borders, paintable hit
testing and selection, stacking order, form controls, replaced content, and SVG
path/mask/paint-server behavior.

| Upstream source area | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `Painting/` | 48 | 10,038 | 4,265 | 825 | Complete |

## Independent fidelity audit

The completed translation was cross-checked unit-by-unit against all 48 current
upstream `.cpp` files and all 56 adjacent headers. The audit corrected the
following behavioral mismatches and added focused regressions:

- The repository-wide symbol audit now classifies all 741 extracted Painting
  implementations: 670 direct or consolidated V candidates, 52 constructors or
  destructors, 10 GC/binding-runtime hooks, and 9 namespace template
  specializations, with zero unmatched symbols.

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
- The display-list recorder now exposes guarded typed entry points for paths,
  ellipses, gradients, bitmaps, lines, rounded fills, filters and shadows, and
  implements balanced alpha/luminance mask layer recording.
- Inner shadows retain their distinct expanded outer and spread-adjusted inner
  rectangles and radii, rather than collapsing both geometries into one rect.

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
| `TableBordersPainting.cpp` | `painting_algorithms.v` |
| `TextPaintable.cpp` | `paintable.v` |
| `VideoPaintable.cpp` | `painting_algorithms.v` |
| `ViewportPaintable.cpp` | `paintable.v`, `scrolling.v`, `visual_context.v` |

The consolidated C++ class entry points are implemented in
`upstream_paintable_entry_points.v`, `upstream_display_entry_points.v`,
`upstream_value_entry_points.v`, and `upstream_algorithm_entry_points.v`, with
focused parity coverage in `upstream_entry_points_test.v`.

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
$ /Users/alex/code/v/v_old -enable-globals test painting
Summary for all V _test.v files: 7 passed, 7 total.

$ python3 tools/libweb_translation_audit.py
Painting: 741 symbols, 0 unmatched.

$ git diff --check -- painting
(no output; exit status 0)
```
