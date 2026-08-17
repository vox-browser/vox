# Selection translation status

Complete, audited translation of `Libraries/LibWeb/Selection` at the current
upstream revision.

| Upstream unit | LOC | V mapping |
|---|---:|---|
| `Selection.cpp` | 744 | `dom/selection.v` (cycle-free implementation) and `selection/selection.v` (namespace facade) |
| `Selection.h` | 93 | `dom/selection.v` and the shared `dom.Selection` object layout |
| `Selection.idl` | 33 | `dom/selection.v` public methods and attributes |
| **Upstream total** | **870** | **1 `.cpp`, 1 `.h`, 1 `.idl`** |

- Physical V implementation assigned only here: **569 LOC** in 2 `.v` files
  (`dom/selection.v` 560; facade 9).
- Physical focused tests assigned only here: **96 LOC** in 2 `_test.v` files
  (7 tests).
- The audit corrected nullable `collapse()`/`setPosition()`, foreign-document
  validation ordering, and the current upstream no-op behavior for
  unimplemented `modify()` granularities. Tests also cover range identity,
  forward/backward direction, UTF-16/grapheme movement, deletion and removal.
- Layout line geometry and form-control selected text remain explicit HTML,
  layout and paint integration boundaries; the range/selection object graph is
  shared with `dom` to avoid a module cycle.
