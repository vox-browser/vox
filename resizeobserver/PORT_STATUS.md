# ResizeObserver translation status

Upstream: `Libraries/LibWeb/ResizeObserver`

| Upstream unit | V implementation |
| --- | --- |
| `ResizeObservation.cpp` | `resize_observer.v` |
| `ResizeObserver.cpp` | `resize_observer.v` |
| `ResizeObserverEntry.cpp` | `resize_observer.v` |
| `ResizeObserverSize.cpp` | `resize_observer.v` |

- Upstream: 4 `.cpp` files, 376 physical LOC.
- V implementation: 238 LOC.
- V tests: 89 LOC in 1 file.
- Status: complete.

`ResizeTargetMetrics` is the typed PaintableBox/window-device-scale boundary.
Observation identity follows the underlying DOM Element, and active gathering,
broadcasting, last-reported sizes, registration lifetime, logical sizes, and
entry rectangles are implemented.

Verification: `v test resizeobserver`, `v fmt -verify resizeobserver`, and
scoped `git diff --check` pass.
