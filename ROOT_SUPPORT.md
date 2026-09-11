# LibWeb root support translation

The upstream source of truth is `~/code/3rd/ladybird/Libraries/LibWeb`; all V
translation code, tests, and translation notes live in `~/code/vox2`.

| Upstream root file | V translation |
| --- | --- |
| `Dump.h`, `Dump.cpp` | `dump/dump.v` |
| `GraphemeEdgeTracker.h`, `.cpp` | `dom/grapheme_edge_tracker.v` |
| `Namespace.h`, `.cpp` | `namespace_/namespace_.v` |
| `PixelUnits.h`, `.cpp` | `css/css.v`, `css/pixel_units.v` (including IPC component order) |
| `TreeNode.h` | `dom/node.v`, `layout/tree_node.v` |
| `InvalidateDisplayList.h` | `dom/node.v` (`InvalidateDisplayList`) |
| `TraversalDecision.h` | `dom/document.v` (`TraversalDecision`) |
| `TraversalOrder.h` | `css/cssom_rules.v` (`TraversalOrder`) |
| `Forward.h` | No generated runtime unit: V resolves these types directly from their owning modules. |

`Dump.cpp`'s paintable traversal is limited to the state present in the current
V `dom.Paintable`. The port does not yet give paintables layout/child links, so
`dump.paintable` emits the complete translated leaf state. Layout and DOM tree
dumps are recursive.

The C++ `TreeNode<T>` helpers templated on a subtype are represented by
predicate-based `*_matching` helpers, matching the V layout tree's explicit
type-discriminant design.
