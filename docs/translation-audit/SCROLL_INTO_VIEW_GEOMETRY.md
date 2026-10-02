# Scroll-into-view geometry source slice

Compared against Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`, with the upstream checkout read-only.

DN-15's position helper now translates `DOM/Element.cpp:4330–4494`. It starts at the current scroll position, aligns against the actual scrolling-box edges, and retains both nearest-alignment no-op cases. Inline-end alignment uses the target's right edge once. The source caller's precomputed target border box has its own entry point; the existing convenience entry point obtains the real client rectangle first.

| Source | Translation |
| --- | --- |
| `DOM/Element.cpp`, visual viewport geometry | The committed painting callback reads the owning Window's actual CSS VisualViewport offset and visible dimensions, combines its offset with the owning Navigable's current layout-viewport scroll, and uses source CSS-pixel rounding. |
| `Painting/Scrolling.cpp:67–99`, `scroll_snapport_rect()` | Scroll-padding resolves from the actual committed layout style. Viewport padding comes from the document element; percentages use the corresponding visible viewport or element padding-box dimension. The source shrink operation is preserved, including its lack of a zero-size clamp. |
| `Painting/BoxViews.cpp` and `Rust/src/painting/rect_to_viewport_transform.rs` | Element snapports use the real committed padding box and the retained accumulated visual contexts, live ancestor scroll snapshot, transforms and device-scale conversion. The projection excludes the visual viewport transform, as do upstream client rectangles. |
| `PixelUnits.h`, CSSPixelFraction conversion | Center alignment truncates the half-size quotient to the source's six fractional bits before its edge sum. |
| Existing renderer viewport transport | Its map now retains the omitted typed Viewport's actual layout identity. Absolute descendants whose containing block is that Viewport receive its already retained mandatory scroll frame. Fixed-to-viewport descendants retain their source behavior. |

The DOM-only adapter still exposes an explicitly unzoomed viewport without an HTML Window or CSS VisualViewport. Production geometry uses the actual owning records. The separate viewport identity prerequisite contains an actual-layout absolute/fixed regression. Its fixture-only companion corrects the existing standards-root horizontal-scroll expectation.

Validation: five actual committed-layout position cases pass with default GC and `-gc none`; the viewport identity regression, ten DOM entrypoint cases, ten existing scroll-snap cases and four client-geometry cases pass with `-gc none`. The position cases cover existing offsets, inline end, center, source fixed-point division, zoomed visible dimensions and percentage padding, element transforms and live offsets, covering nearest targets and uncommitted scrollers.

## Remaining DN-15 boundaries

The ancestor-scroll caller still needs source element scrolling, a single target rectangle projected and clipped outward after each intended scroll, behavior forwarding, container stopping and owning-realm ancestor Promise aggregation. The public typed API still needs the full options/boolean overloads and temporary execution context; the compact JavaScript scrolling interface remains separate. Compositor transport and user-gesture settlement also remain open.

The pinned source itself retains FIXMEs for other block/inline directions, target scroll-snap position selection in this helper, and optional attention actions. This slice preserves those source limitations. The source VisualViewport class is currently retained by the owning translated Window; replacing the old empty DOM VisualViewport facade with centralized source ownership is separate work.
