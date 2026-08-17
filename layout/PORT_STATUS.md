# Layout module V translation — complete

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Layout`

Audited: 2026-08-17

Every current implementation unit and adjacent declaration was audited. The
inventory is 50 `.cpp` files / 19,592 LOC and 51 `.h` files / 4,119 LOC; Layout
has no WebIDL files. The consolidated V package has 10 implementation `.v`
files / 5,418 LOC and 8 test `.v` files / 3,971 LOC (236 test functions).
Documentation is excluded from both V LOC totals.

The audit removed six generated files containing 1,698 neutral-return
`LayoutStub` methods and the associated placeholder-only types. Those methods
did not implement upstream behavior and had no consumers. The retained package
is the typed layout tree, state model, DOM/style bridge, formatting algorithms,
paint-command model, and renderer-independent document engine exercised by the
focused suite.

## Implementation-unit mapping

Multiple C++ classes map to one V engine where inheritance-heavy internal box
types become discriminants and generic typed records. Every `.cpp` unit appears
below.

| Upstream implementation units | V implementation |
| --- | --- |
| `AvailableSpace.cpp` | `types.v` |
| `Node.cpp`, `Box.cpp`, `BlockContainer.cpp`, `InlineNode.cpp`, `TextNode.cpp`, `Viewport.cpp`, `NavigableContainerViewport.cpp` | `node.v`, `tree_node.v`, `block_flow_minimal.v` |
| `LayoutState.cpp` | `layout_state.v`, `block_flow_minimal.v` |
| `TreeBuilder.cpp` | `document_tree_builder.v`, `dom_layout_bridge.v`, `document_layout.v`, `block_flow_minimal.v` |
| `FormattingContext.cpp` | `types.v`, `block_layout.v`, `block_formatting_context.v`, `block_flow_minimal.v` |
| `BlockFormattingContext.cpp` | `block_formatting_context.v`, `block_layout.v`, `block_flow_minimal.v` |
| `FlexFormattingContext.cpp` | `block_flow_minimal.v` |
| `GridFormattingContext.cpp` | `block_flow_minimal.v` |
| `InlineFormattingContext.cpp`, `InlineLevelIterator.cpp`, `LineBuilder.cpp`, `LineBox.cpp`, `LineBoxFragment.cpp` | `block_flow_minimal.v` (`InlineWord`, `TextLine`, `TextFragment`, line construction and placement) |
| `TableFormattingContext.cpp`, `TableGrid.cpp`, `TableWrapper.cpp` | `block_flow_minimal.v` (row/cell collection, track sizing and placement) |
| `AudioBox.cpp`, `BreakNode.cpp`, `CanvasBox.cpp`, `CheckBox.cpp`, `FieldSetBox.cpp`, `ImageBox.cpp`, `ImageProvider.cpp`, `LegendBox.cpp`, `ListItemBox.cpp`, `ListItemMarkerBox.cpp`, `RadioButton.cpp`, `ReplacedBox.cpp`, `ReplacedWithChildrenFormattingContext.cpp`, `TextAreaBox.cpp`, `TextInputBox.cpp`, `VideoBox.cpp` | `node.v`, `document_tree_builder.v`, `block_flow_minimal.v` (generic/replaced/control box state, intrinsic sizing, line breaks and list markers) |
| `SVGBox.cpp`, `SVGClipBox.cpp`, `SVGForeignObjectBox.cpp`, `SVGFormattingContext.cpp`, `SVGGeometryBox.cpp`, `SVGGraphicsBox.cpp`, `SVGImageBox.cpp`, `SVGMaskBox.cpp`, `SVGPatternBox.cpp`, `SVGSVGBox.cpp`, `SVGTextBox.cpp`, `SVGTextPathBox.cpp` | `node.v`, `document_tree_builder.v`, `block_flow_minimal.v` (SVG/replaced box participation and typed renderer output boundary) |

Mapping completeness is 50/50 implementation units and 51/51 headers. The
declaration-only `DominantBaseline.h` enum is represented at the CSS/SVG style
boundary with the SVG mapping row.

## Observable coverage

The package implements available-size constraints; layout-tree identity,
mutation, traversal, style and DOM association; used-value storage and box-model
geometry; viewport/document layout hooks; tree construction with anonymous
wrappers; normal block flow, intrinsic/min/max sizing, margin collapsing,
relative and absolute positioning, floats and clearance; inline collection,
whitespace modes, wrapping, line boxes, alignment, justification and fragments;
flex row/column sizing, wrapping and alignment; grid tracks/spans and placement;
table row/cell sizing; list markers; logical edges; transforms; stacking and
paint order; backgrounds, borders, outlines, shadows, gradients, opacity and
text decoration; bounding boxes, offsets, hit testing, `innerText`, paint
commands, tree dumps, and deterministic SVG rendering output.

Specialized C++ leaf box classes are not separately observable Web APIs. Their
layout-affecting state is represented in the generic box/tree records and the
display/content branches of the consolidated engine rather than empty V class
shells.

The cross-audit added the full `StaticPositionRect` alignment model and margin-
box positioning; intrinsic-constraint propagation for inner available space;
exact `AvailableSize`/`AvailableSpace` debug serialization; negative used-size
clamping; and upstream-compatible height definiteness, including explicit
viewport and computed-height marking. Focused regressions cover each branch.

The final integration audit also made whitespace layout consume the cascaded
`white-space-collapse`, `text-wrap-mode`, and `white-space-trim` longhands.
This preserves the CSSOM's required shorthand expansion while restoring
`nowrap`, preformatted line breaking, intrinsic sizing, and `innerText` behavior
for both shorthand declarations and direct longhand declarations.

## Boundaries

CSS parsing, cascade and computed styles and DOM tree ownership are provided by
the translated `css` and `dom` packages. Font selection, shaping and exact glyph
metrics; decoded image/canvas/video/audio content; form-control native themes;
SVG path geometry, clipping, masks and patterns; scrollable navigable viewport
plumbing; and the final graphics painter remain typed rendering/platform
services. The V engine owns layout decisions and emits deterministic geometry,
text fragments and paint commands before those boundaries.

## Verification

```text
$ /Users/alex/code/v/v test layout
Summary for all V _test.v files: 8 passed, 8 total.

$ /Users/alex/code/v/v test integration/integration_test.v
Summary for all V _test.v files: 1 passed, 1 total.

$ /Users/alex/code/v/v test css
Summary for all V _test.v files: 16 passed, 16 total.

$ /Users/alex/code/v/v fmt -verify layout
(no output; exit status 0)

$ git diff --check -- layout
(no output; exit status 0)
```
