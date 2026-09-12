# Selection translation status

Complete, audited translation of `Libraries/LibWeb/Selection` at the current
upstream revision.

| Upstream unit | LOC | V mapping |
|---|---:|---|
| `CaretNavigation.cpp` | 726 | `dom/selection.v` |
| `Selection.cpp` | 651 | `dom/selection.v` (cycle-free implementation) and `selection/selection.v` (namespace facade) |
| `SelectionModifier.cpp` | 93 | `dom/selection.v` |
| Headers and IDL | 256 | `dom/selection.v` and the shared `dom.Selection` object layout |
| **Upstream total** | **1,726** | **3 `.cpp`, 3 `.h`, 1 `.idl`** |

- Physical V implementation assigned only here: **1,080 LOC** in 2 `.v` files
  (`dom/selection.v` 1,071; facade 9).
- Physical focused tests assigned only here: **177 LOC** in 2 `_test.v` files
  (10 tests).
- The audit corrected nullable `collapse()`/`setPosition()`, foreign-document
  validation ordering, caret affinity, cross-node and atomic-inline movement,
  line/document boundaries, and one-shot range mutation through
  `SelectionModifier`. Tests also cover range identity, forward/backward
  direction, UTF-16/grapheme movement, deletion and removal.
- Retained paint-fragment geometry and form-control selected text remain
  explicit layout/paint and HTML integration boundaries; the range/selection
  object graph is shared with `dom` to avoid a module cycle.
