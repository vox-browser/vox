# Viewport scrollbar synchronization

The renderer transport represents the omitted viewport box on its root element.
Its scrollbar previously read that element's scroll offset, which remains zero
when the document viewport scrolls. `BlockBox.current_scroll_offset()` now reads
the owning document's viewport position for that box. Element scrollbars continue
to read their own paintables. This follows the viewport distinction in upstream
`Painting/Scrolling.cpp::scroll_offset()`.

The focused layout tests reproduced both stationary viewport thumbs before the
fix. They cover live horizontal and vertical movement through cached paint
commands, both ends of the scroll range, returning to the origin, independent
nested scrolling, and scrolling before the first paint. The browser test sends
a software GG wheel event through the native input entry and verifies the next
frame's scrollbar, followed by clamped scrolling to each end.

Validation on 2026-10-15:

- Both new layout cases pass with the default collector and `-gc none`.
- The browser wheel/frame case passes with the default collector.
- Three existing viewport geometry, scrollbar hit-testing, and hover/drag/release
  cases pass with the default collector.
- The optimized macOS app builds and passes `--headless-smoke`, including its
  JavaScript DOM/click and wheel-routing checks. The native build already running
  in this workspace included the fix, verified in its generated C, and supplied
  the executable used for these checks.
- Native 320 by 200 document-viewport captures with an explicit dark scrollbar
  on a white track put the thumb at y=2, y=83, and y=165 for viewport scroll
  positions 0, 500, and 1000. Its bottom edge reaches y=199 at maximum scroll.
  Captures and measurements are under `Build/v/scrollbar-verification/`.

Commands use `v -old-compiler -enable-globals`, exclude the duplicate
`@vlib/time/zoneinfo.native.v` backend, and compile C with `-O0`. Default-collector
checks also define `LARGE_CONFIG=1`.

This is one completed browser/paint-transport fix toward the next ten-fix broad
verification batch. Broad suites are deferred.
