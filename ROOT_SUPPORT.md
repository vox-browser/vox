# LibWeb root support translation

The upstream source of truth is `~/code/3rd/ladybird/Libraries/LibWeb`; all V
translation code, tests, and translation notes live in `~/code/vox2`.

| Upstream root file | V translation |
| --- | --- |
| `Dump.h`, `Dump.cpp` | `dump/dump.v` |
| `GraphemeEdgeTracker.h`, `.cpp` | `dom/grapheme_edge_tracker.v` (`find_line_start`/`find_line_end`; the removed adjacent-line tracker is superseded by `dom/visual_lines.v`) |
| `Namespace.h`, `.cpp` | `namespace_/namespace_.v` |
| `PixelUnits.h`, `.cpp` | `css/css.v`, `css/pixel_units.v` (including nearest/floor/truncate conversion, saturated negation/absolute value, and raw `CSSPixelPoint` IPC component order) |
| `VisualLines.h`, `.cpp` | `dom/visual_lines.v`; committed line/caret projection in `layout/dom_layout_bridge.v`; selection and text-control consumers in `dom/selection.v` and `html/form_associated_element.v` |
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

`VisualLines.cpp`'s Rust layout-arena queries map to a retained projection of
V's committed `LineBox` state. It preserves per-text-node visual ranges,
hanging-whitespace boundaries, fragmentless preserved-newline lines, owner/line
identity across adjacent text nodes, and grapheme-level inline caret stops.
