# ResizeObserver translation status

Upstream: `Libraries/LibWeb/ResizeObserver`

| Upstream unit | V implementation |
| --- | --- |
| `ResizeObservation.cpp` | `resize_observer.v` |
| `ResizeObserver.cpp` | `resize_observer.v` |
| `ResizeObserverEntry.cpp` | `resize_observer.v` |
| `ResizeObserverSize.cpp` | `resize_observer.v` |

Observation identity follows the underlying DOM Element. Active gathering,
broadcasting, last-reported sizes, registration lifetime, and immutable entry
rectangles use the translated document rendering loop.

`ResizeTargetMetrics` remains the explicit manually supplied box boundary.
`ResizeTarget.for_element()` instead reads the current committed DOM layout box,
normalizes layout coordinates to CSS pixels, and supplies padding-relative
content rectangles. Missing boxes and non-replaced ordinary inline boxes have
zero dimensions. Reads never force layout during an observation broadcast.
Observer gathering and entry snapshots use the owning document's retained
storage so they survive rendering scratch reclamation.

`browserjs/resize_observer_binding*` exposes the Window constructors and native
observe/unobserve/disconnect methods to JavaScriptCore. It validates Element
identity and dictionary conversion, delivers native entries after layout,
reports callback exceptions, and disconnects observers at runtime shutdown.
The browser synchronizes pending compact DOM mutations before observation.
Box-size arrays are frozen, and saved entry snapshots retain their geometry.

Remaining limits: the translated device-pixel-content-box calculation retains
upstream's border-box multiplication; physical width/height retain upstream's
writing-mode limitations. JavaScript wrappers and callback roots currently live
until runtime close rather than following weak-reference collection. These
limits prevent claiming complete Brave or ResizeObserver parity.

Focused validation covers four JavaScript binding cases, related intersection
and rectangle bindings (nine cases total), and eleven core observer cases.
All four normal/poisoned-arena compile and runtime steps pass in
`Build/pikabu-story-resize-tests-1793018008591901000/results.json`.
An unrelated concurrent `html/message_port.v` edit makes the driver's source
manifest gate exit 1; observer sources remain unchanged.
