# VisualViewport source math

The reference is Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`, `CSS/VisualViewport.cpp:175–214` and `LibGfx/AffineTransform.{h,cpp}`, with the upstream checkout read-only. The viewport uses the [actual retained document owner](VISUAL_VIEWPORT_OWNERSHIP.md).

## Fractional pinch focal points

`zoom()` now retains the source `CSSPixels` focal coordinates as doubles through the pinch offset calculation. It no longer rounds them to whole pixels before applying the scale ratio. The existing scale limits, actual viewport-dimension offset clamps, final CSS-pixel conversion and conditional scroll event remain unchanged.

Two committed-layout cases pass with default GC and `-gc none`. They verify fractional focal points across repeated zooms with an already fractional offset, actual facade dimensions/offsets, same-target scroll coalescing and zero-delta suppression, and the source scale/offset limits against actual owner dimensions. Five existing scroll-into-view position cases also pass in both modes.

## Remaining math and integration boundaries

The affine transform and integer map still need the source float-coefficient precision, unrounded double-scaled offset before the float cast, full determinant/inverse calculation and integer input/output conversion. These are separate from the completed focal-point correction. Accumulated painting-context/repaint handoff, compositor and remote/process transport, compact JavaScript exposure and full runtime/GC bindings remain explicit boundaries. No compositor algorithm or result is introduced by this slice.
