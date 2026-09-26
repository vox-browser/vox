# Selection translation status

Translation of `Libraries/LibWeb/Selection` at the current upstream revision.
Audited: 2026-09-26. Status: Present (caret line and page movement pending).

| Upstream unit | LOC | V mapping |
|---|---:|---|
| `CaretNavigation.cpp` | 726 | `dom/selection.v` |
| `Selection.cpp` | 651 | `dom/selection.v` (cycle-free implementation) and `selection/selection.v` (namespace facade) |
| `SelectionModifier.cpp` | 93 | `dom/selection.v` |
| Headers and IDL | 256 | `dom/selection.v` and the shared `dom.Selection` object layout |
| **Upstream total** | **1,726** | **3 `.cpp`, 3 `.h`, 1 `.idl`** |

- Physical V implementation assigned only here: **1,479 LOC** in 2 `.v` files
  (`dom/selection.v` 1,470; facade 9).
- Physical focused tests assigned only here: **332 LOC** in 2 `_test.v` files.
- The caret navigator follows the current upstream rules for editing
  canonicalization (comments and processing instructions, source formatting
  whitespace between blocks, trailing placeholder breaks, and the preference
  for the following block at a block boundary), adjacent caret hosts (empty-line
  breaks, atomic inline edges, visual text edges), extension canonicalization,
  word movement (Unicode separator and punctuation general categories,
  punctuation stops, split text sharing an inline context), and editing-host
  boundaries.
- Retained paint-fragment geometry and form-control selected text remain
  explicit layout/paint and HTML integration boundaries; the range/selection
  object graph is shared with `dom` to avoid a module cycle.

## Known gaps

- Line, line-boundary, and page movement: upstream asks the painting
  `HitTestDisplayList` for `caret_position_on_adjacent_line()`,
  `caret_position_at_line_edge()`, and `caret_line_block_coordinate()`. V has
  no hit-test display list yet, so these granularities still move within a
  text node's visual lines and step a page as repeated line moves.
- `inline_coordinate()` for a non-text boundary falls back to the boundary
  offset instead of the document's current caret rect.
- `is_empty_line_host()` does not check `is_paintable_with_lines()`, which the
  DOM layout bridge does not expose. The bridge does expose replaced boxes, so
  the empty-line `<br>` rule follows `HTMLBRElement::represents_empty_line()`.
