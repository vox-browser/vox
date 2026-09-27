# LibWeb root support translation

The upstream source of truth is `~/code/3rd/ladybird/Libraries/LibWeb`; all V
translation code, tests, and translation notes live in `~/code/vox2`.

| Upstream root file | V translation |
| --- | --- |
| `Dump.h`, `Dump.cpp` | `dump/dump.v` (including Navigation API entry scroll state, canonical serialized selectors, and associated shadow-host pseudo-element labels) |
| `GraphemeEdgeTracker.h`, `.cpp` | `dom/grapheme_edge_tracker.v` (`find_line_start`/`find_line_end`; the removed adjacent-line tracker is superseded by `dom/visual_lines.v`) |
| `Namespace.h`, `.cpp` | `namespace_/namespace_.v` |
| `PixelUnits.h`, `.cpp` | `css/css.v`, `css/pixel_units.v` (including nearest/floor/truncate conversion, saturated negation/absolute value, and raw `CSSPixelPoint` IPC component order) |
| `VisualLines.h`, `.cpp` | `dom/visual_lines.v`; committed line/caret projection in `layout/dom_layout_bridge.v`; selection and text-control consumers in `dom/selection.v` and `html/form_associated_element.v` |
| `TreeNode.h` | `dom/node.v`, `layout/tree_node.v` |
| `InvalidateDisplayList.h` | `dom/node.v` (`InvalidateDisplayList`) |
| `TraversalDecision.h` | `dom/document.v` (`TraversalDecision`) |
| `TraversalOrder.h` | `css/cssom_rules.v` (`TraversalOrder`) |
| `Forward.h` | No generated runtime unit: V resolves these types directly from their owning modules. |

`Dump.cpp` delegates layout diagnostics to Painting upstream. The V dump facade
likewise uses the retained typed layout serializer, while DOM tree dumps remain
recursive. The superseded standalone paintable-tree dump API has been removed.

The C++ `TreeNode<T>` helpers templated on a subtype are represented by
predicate-based `*_matching` helpers, including inclusive-ancestor iteration,
matching the V layout tree's explicit type-discriminant design. Tree-order
comparison walks depth-bounded ancestor chains and preserves the unordered
result for nodes in disconnected trees.

`VisualLines.cpp`'s Rust layout-arena queries map to a retained projection of
V's committed `LineBox` state. It preserves per-text-node visual ranges,
hanging-whitespace boundaries, fragmentless preserved-newline lines, owner/line
identity across adjacent text nodes, and grapheme-level inline caret stops.

`tools/upstream_function_delta.py` carries explicit mappings for these typed
root-support implementations. Current `Dump`, pixel-unit conversion, tree-node
ABI, and visual-line definitions are therefore classified through their real V
targets instead of falling outside the module-oriented symbol inventory.
