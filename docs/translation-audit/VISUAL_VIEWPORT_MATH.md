# VisualViewport source math

The reference is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`, `CSS/VisualViewport.cpp:175–214` and `LibGfx/AffineTransform.{h,cpp}`, with the upstream checkout read-only. The viewport uses the [actual retained document owner](VISUAL_VIEWPORT_OWNERSHIP.md).

## Fractional pinch focal points

`zoom()` now retains the source `CSSPixels` focal coordinates as doubles through the pinch offset calculation. It no longer rounds them to whole pixels before applying the scale ratio. The existing scale limits, actual viewport-dimension offset clamps, final CSS-pixel conversion and conditional scroll event remain unchanged.

Two committed-layout cases pass with default GC and `-gc none`. They verify fractional focal points across repeated zooms with an already fractional offset, actual facade dimensions/offsets, same-target scroll coalescing and zero-delta suppression, and the source scale/offset limits against actual owner dimensions. Five existing scroll-into-view position cases also pass in both modes.

## Float transform and integer mapping

The active affine operations now use `Gfx::AffineTransform`'s six float coefficients, source scale/translation operations and full float determinant/inverse formula. `VisualViewport::transform()` multiplies offset coordinates as doubles before converting to the float affine arguments. It no longer rounds this intermediate value through another CSS-pixel point. The existing CSS-point convenience mapper transports through the source float map.

`map_to_layout_viewport()` uses the source identity fallback for a missing inverse, truncates input CSS coordinates to integers, maps those integers as floats, then converts the integer result back to CSS pixels. The narrow `AK/Math.h::round_to<int>(float)` ABI retains the source signed AArch64/x86 conversion instructions and portable `llrintf` fallback, including their rounding and exceptional-conversion behavior.

Three committed-layout owner cases and two affine primitive cases pass in both GC modes on native AArch64. They cover fractional scaled-offset/float-inverse precision, fractional and negative input truncation, halfway rounding to even, the integer-to-float precision boundary, all six coefficients, scale/translation ordering, full inverse mapping and the singular identity fallback. The three existing VisualViewport ownership cases also pass in both modes. The other architecture branches reproduce the pinned instructions but were not executed here.

## Integration boundaries

The active VisualViewport affine operations are translated; general LibGfx rotation, skew-construction and other matrix consumers remain outside this slice. Accumulated painting-context/repaint handoff, compositor and remote/process transport, compact JavaScript exposure and full runtime/GC bindings remain explicit boundaries.
