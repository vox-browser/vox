# Layout module V translation — present; semantic re-audit in progress

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Layout`

Re-audited: 2026-09-08

The 2026-11-03 Register compatibility slice adds horizontal block-content
distribution in `block_content_alignment.v`, after final used sizing and before
positioned descendants. Center/end alignment and distributed-value fallbacks
move block/inline contents as a unit; non-normal block alignment contains child
margins and floats. Six focused tests execute in both GC modes and 315 existing
formatting tests pass. Table/multicol and vertical writing remain separate work;
this does not establish complete CSS Align syntax or upstream method parity.
See [the Register checkpoint](../docs/FORUM_NEWS_EXPANSION.md).

All 50 upstream Layout `.cpp` units have filename-level homes in the typed V
Layout package. That inventory does not establish body-level parity: the
current semantic audit reports 4 unmatched Layout implementations, and the
legacy `BlockBox` renderer transport still sits between typed Layout and the
native shell.

The symbol-level audit excludes the former class-shaped
`upstream_*entry_points.v` facades because matching a C++ method name without
porting its body is not translation coverage. The live path uses typed layout
nodes and dense `LayoutState` storage, but each unmatched method still requires
comparison with the current upstream body.

The September semantic reconciliation accounts for formatting-context logic
that the V port decomposes into spec-named free functions rather than the C++
class method boundaries. It covers flex, grid, table, block, inline, SVG,
replaced-with-children, generic sizing dispatch, tree construction, and their
local state helpers; every mapping points at the active implementation rather
than a name-only facade. This reduced Layout's structural audit remainder from
595 to 171 without duplicating already-tested logic.

The node-hierarchy pass then reconciled the covariant DOM accessors, virtual
type predicates, intrinsic-size hooks, and paintable factories that V expresses
through its embedded `Node` prefix and centralized typed paint adapter. It also
closed a real behavioral gap: `VideoBox` natural size now reads the media
model's live video dimensions, including an aspect ratio when both dimensions
are positive, even when called through the common `Box` path. The audit moved
from 171 to 71 unmatched Layout implementations at that checkpoint.

The next node-state pass reduced Layout from 71 to 15. It ties the remaining
reviewed paintable-list operations, text segmentation, flex temporary-record
arithmetic, anonymous/table wrapper propagation, continuations, and node-kind
accessors to their active V implementations. `Node::has_css_transform()` now
also includes the individual `rotate`, `translate`, and `scale` properties, and
the source-shaped `css_clamp()` helper is used by flex sizing with CSS's defined
maximum-below-minimum behavior.

The 700 checkpoint reduces Layout from 15 to 4. Navigable container viewports
now negotiate natural metrics from hosted SVG document roots and commit their
content size to the child document viewport. The local margin-box geometry
helper preserves the source rule that negative margins do not extend the box,
and text segmentation treats both U+0020 and U+00A0 as inter-word spaces. The
active HTML image-provider and image-box relayout paths account for the former
class-shaped hooks. The four remaining implementations are the base insertion
and label hooks, list-style image provisioning, and contextual space-font
selection.

The line-clamp refresh translates the new line-clamp-container state shared by
block and inline formatting. It counts descendant in-flow line boxes, retains
the clamp point on the root used values, lays later boxes out as non-painting
content, and appends automatic, custom, or inherited block ellipses. Soft-wrap
displacement, glyph-boundary fallback, RTL placement, effective legacy WebKit
flex direction, scrollable-overflow exclusion, and DOM/paint projection are
covered by focused tests. The complete Layout unit-test directory passes, and
the upstream `line-clamp-properties` reftest is an exact zero-pixel match in the
native V browser. Block ellipses use the boundary text node and its UTF-16 end
offset, and compatible boundary/ellipsis glyph runs are replayed as one retained
run without reshaping. When the selected face lacks the ellipsis glyph, its
shaped missing-glyph run matches literal text instead of being reshaped by the
paint backend.

## Translated coverage

The translated path includes the complete layout-node hierarchy and tree
builder; incremental style application and anonymous/table-wrapper propagation;
block, inline, flex, grid, table, fieldset, replaced-with-children, SVG, and
absolute-position formatting; floats, clearance, margin collapse, intrinsic
sizing, aspect-ratio constraint solving, line construction and breaking,
generated content and counters, list markers, relative positioning, overflow,
SVG natural metrics and transforms, typed used-value state, layout/DOM bridging,
debug dumps, and the typed layout-to-renderer adapter used by the executable.

Collapsed-table cell geometry now derives its collapsing-border mode from the
presence of resolved override border data, as upstream does. Margin- and
border-box metrics use rounded half-widths for those shared borders, including
odd pixel widths. Table-cell coordinates, override borders, and resolved grid
tracks are installed through the translated `UsedValues` accessors.

Flex and grid percentage gaps now use the same axis-specific containing-block
bases as C++: flex main/cross gaps follow the current flex direction, while grid
column and row gaps use available width and height respectively. Flex's
automatic-minimum optimizations are also translated rather than approximated.
The whole-container proof handles definite single-line layouts; the per-item
proof handles a definite flex basis equal to its specified-size suggestion,
including wrapped row and column layouts. Both skip only the initial intrinsic
clamp: the real automatic minimum is computed lazily if flexible-length
violation handling needs it. Regressions cover row and column axes, automatic
cross sizes, both intrinsic-cache fast paths, and restoration of deferred
minimums for unfrozen items.

Flex and grid intrinsic modes now also preserve C++'s early exit for nested
containers whose parent has already resolved both available dimensions,
avoiding full formatting-context passes and their potential intrinsic subtree
measurements. A measured grid root returns after track sizing instead of
continuing through normal positioning and child layout. Column flex-base sizing
applies the same post-base natural-aspect-ratio cross min/max adjustment as the
row path, so a constrained cross size transfers back to the main axis.

Intrinsic inline-flex measurement now resolves an automatic block size,
including min/max constraints, before main- and cross-axis alignment. It also
retains the content-derived first and last baselines before discarding the
temporary measurement line boxes, matching the baseline exported by the normal
layout pass.

Flex and grid now build order-modified document order with C++'s distinct-order
buckets rather than insertion-sorting every child. Equal-order children retain
document order. `generate_anonymous_flex_items()` sorts those distinct keys
descending for a reverse direction rather than reversing the item list, because
the positioning code already lays a reverse line out from the far edge;
`is_direction_reverse()` also counts plain `row` - not `row-reverse` - as the
reversed one under `direction: rtl`.

A differential audit against the upstream browser corrected four more flex
divergences. An indefinite column container now runs
`calculate_intrinsic_main_size_of_flex_container()` - the desired/chosen flex
fraction algorithm the row axis already used - instead of summing outer
hypothetical main sizes, which ignored flexibility and left `flex-basis: 0` items
at zero. `calculate_cross_size_of_each_flex_line()` hands a line the container's
inner cross size only when `is_single_line()`, which means `flex-wrap: nowrap`
rather than "collection produced one line"; keying it on the line count removed
the free space that `align-content` distributes. `align_all_flex_lines()` treats
negative leftover free space as `center` for `space-around` and `space-evenly`,
and reverses the line order for wrap-reverse and for nothing else.

`align_all_flex_items_along_the_cross_axis()` consults flex-wrap in exactly one
case: wrap-reverse swaps the cross-start and cross-end directions for `normal`
alone, while every explicit keyword names a fixed edge of the line and the inline
`direction` does not affect the item's own offset. `FlexCrossAlignment` therefore
keeps `normal` distinct from an explicit `stretch` even though both stretch an
auto-sized item.

`align_all_flex_lines()` now uses the upstream per-keyword starting cross edge,
distributed gap, `place_items_backwards`, and `iterate_lines_backwards` flags.
This matters when stretched line sizes do not sum to the container exactly:
`align-content: stretch` over three lines in a 160px container distributes 70px
as truncated 23.328125px shares. Placing wrap-reversed lines backwards from the
far edge keeps the truncation residue out of item positions, closing the last two
generated flex-corpus differences. The 489-case corpus and both 80-case flex
alignment matrices now agree with upstream in full. Grid auto-placement also uses packed signed row/column keys for
its occupation set instead of formatting a string for every cell lookup. Table
layout records the equivalent of C++'s per-column `left_offset` array once and
uses prefix differences for spanning widths and final cell positions, removing
the former repeated scan of every preceding column. Row-group positioning now
walks each group's own rows with C++'s advancing group cursor instead of
rescanning every table row for every group; this also fixes empty groups after
nonempty groups being placed back at the table's first spacing edge.

Table height and caption layout now preserve the source's two-pass ordering and
its current quirks rather than independently implementing the specification.
Percentage cell heights are resolved and their contents laid out again only
after the table height is known; weighted row distribution may then leave the
cell taller than its row, and `position_cell_boxes()` retains the resulting
negative alignment padding. Caption descendants are laid out against the full
table border-box width before the caption's own fixed or percentage width and
box model are resolved. Caption margins do not shift a top caption from the
wrapper origin. Percentage-height cells spanning multiple rows also participate
in the second pass, as they do in the source. `visibility: collapse` on a row or
its row group now zeroes that row's base, reference, and final height and keeps
it from advancing the row cursor. The row-group cursor intentionally retains
the source's quirk of counting spacing between collapsed row boxes. Height left
over for auto rows is converted from `CSSPixelFraction` by truncating instead of
being recomputed and rounded through `f64`. Rowspans now use the same increasing-
span intrinsic min/max contribution algorithm as columns; both paths preserve
the source's fixed-point ratios and zero-baseline truncation. The former post-
layout equal shortfall split has been removed. Cell `min-height` contributes to
those row measures without clamping the automatic content height written back
by the cell's layout pass. Intrinsic cell-height throwaway states also seed an
external containing block even when the main table pass has not visited it yet,
which is required for absolutely positioned descendants contained by a row.
Finally, `rowspan="0"` remains a one-row span because upstream's downward-
growing-cell step is still a FIXME. A generated 752-case
general table matrix, a 216-case collapsed-row matrix, and a 576-case rowspan
matrix agree with the current C++ table/row geometry on every tracked case.

Column flex intrinsic cross sizing now follows C++'s two-pass contribution
algorithm for single-line min/max-content sizing and multi-line min-content
sizing. The first pass ignores cyclic percentage min/max constraints and sets
the provisional container cross size; the second resolves those constraints
against that size. Cross-size contributions also retain the upstream preferred
size, box-model, aspect-ratio transfer, and main-axis min/max clamping rules
instead of routing through the generic one-pass width contribution helper.
For a wrapped column's max-content cross size, the intrinsic path now lays out
the flex lines under the definite main size using the largest max-content item
contribution as the available cross space, then returns the sum of the resulting
line cross sizes and cross gaps instead of the former largest-item shortcut.

Grid's indefinite-space flexible-track expansion now translates C++'s full
"find the size of an fr" range calculation on both axes. The used flex fraction
includes every item crossing a flexible track, subtracts fixed tracks and gaps,
and restarts with any flexible track whose tentative share falls below its base
size treated as inflexible. This replaces the single-track-only column shortcut
and the base-size-only row shortcut.

Grid tracks now retain the separate min/max sizing-function identities that
C++ uses during intrinsic resolution instead of one ambiguous `intrinsic` bit.
The translated spanning-item algorithm now runs C++'s separate minimum,
min-content, and max-content base-size phases, followed by its intrinsic-maximum
and max-content growth-limit phases. Track-local frozen and infinitely-growable
state persists between those phases, fit-content limits are clamped after
planned growth, and unresolved infinite limits are finalized at the base size.
Non-spanning items now use those same phases instead of a separate one-pass
shortcut. Minimum contributions implement the content-based automatic minimum,
including specified and aspect-ratio-transferred suggestions, fixed maximum
track clamps, definite item maximums, and the zero minimum for multi-track
flexible spans. Intrinsic container sizing uses C++'s limited min/max-content
contributions, and row contributions are measured from the item's laid-out
inline size rather than reusing one previously computed margin-box height for
every phase. Column min/max-content probes now remain pure content measurements:
an item's own min/max-width is applied by the contribution caller, while cyclic
percentage minimums resolve through the still-indefinite grid area rather than
the definite outer grid width.
Base-size distribution continues beyond finite limits through the upstream
intrinsic-maximum selection and keeps fixed minima out of intrinsic base-size
growth. Spanning flexible tracks receive the largest per-item contribution in
flex-factor proportions after fixed tracks and gutters are removed; auto-sized
items spanning flexible tracks use C++'s zero automatic minimum. Max-content
measurement also maximizes non-frozen tracks toward their intrinsic growth
limits. The following maximization stage now preserves and retries the
pre-maximization bases against a definite `max-width`, exactly as C++ does,
and it selects definite versus indefinite row maximization and `fr` expansion
from the supplied available grid space rather than the computed `height`.
This keeps constrained relayouts of auto-height grids from prematurely growing
max-content rows past their available block size. Regressions cover mixed fixed/`fr` spans on both axes, definite
flexible-track overflow, base and growth-limit freezing, beyond-limit
distribution, fixed-minimum/max-content tracks, flexible-row automatic
minimums, max-height-limited intrinsic row contributions, maximum-size retry,
and definite-space auto-height row maximization.

Boxes with a preferred aspect ratio now enter the replaced-element sizing
algorithm through a translated `box_is_sized_as_replaced_element()`, together
with `should_treat_width_as_auto()` and `should_treat_height_as_auto()`. A
non-replaced box with a ratio and one specified axis therefore transfers its
automatic inline size through that ratio rather than stretching to its
containing block, on the normal-flow block, floating, and absolutely positioned
paths alike. Two axes that are both automatic keep the ordinary block sizing the
source falls back to.
`compute_width_for_block_level_replaced_element_in_normal_flow()` is translated
with its ordering intact: the replaced algorithm runs before the used inline
padding is assigned, so `box-sizing: border-box` is resolved once against the
still-zero padding, and the resulting content width is converted a second time
by `calculate_inner_width()` with the real padding in place. A block-level or
floating replaced box with `box-sizing: border-box` really does lose its inline
border and padding twice; an inline-block, flex item, or grid item does not,
because it never enters that function. A ratio-derived height follows the
converted inline size, as `tentative_height_for_replaced_element()` reads the
used content width. The width equation still re-runs with the max-width and
min-width clamps applied to that width so the used margins match, while the
clamped width itself is discarded exactly as in step 4 of `compute_width()`.
`solve_replaced_size_constraint()` resolves min/max constraints through the same
content-box conversion as preferred sizes and runs only when both axes are
automatic.
Steps 2 and 3 of `compute_width_for_replaced_element()` and
`compute_height_for_replaced_element()` are translated as written: both the
used-size comparison and a violated constraint use the content-box value
produced by `calculate_inner_width()` or `calculate_inner_height()`. Those steps
also run after the constraint table, and the block size is clamped before
`tentative_width_for_replaced_element()` transfers it through the ratio.
An unresolved percentage block size is treated as automatic, and only a box that
`box_is_sized_as_replaced_element()` selects transfers it from the inline size; a
box with two automatic axes takes its automatic content height, as
`resolve_used_height_if_treated_as_auto()` does.
`tentative_height_for_replaced_element()` also keeps its branch order: a natural
height wins over the ratio when both axes are treated as automatic, while a
computed `auto` height alongside a definite inline size is not treated as
automatic and does follow the ratio.
A generated 344-case matrix over aspect ratios, box sizing, specified axes,
box-model edges, and min/max constraints across block, float, absolute, image,
and floating-image contexts went from 127 differences against upstream to 0.

A table wrapper on a line now takes the width its table box's own algorithm
produces, as `BlockFormattingContext::compute_width()` does before any
shrink-to-fit pass. An `inline-table` therefore honours an intrinsic sizing
keyword on the table box - `width: min-content` and `width: fit-content` resolve
to the used min-width of the table rather than to the wrapper's max-content
measure. One known difference remains in this area: an `inline-table` with a
percentage width leaves the table box's own end margin at the value its width
equation produced, while upstream reaches
`InlineFormattingContext::dimension_box_on_line()` with a max-content constraint
still recorded on the wrapper's used values and so treats that percentage as
automatic. Only the dumped margin differs; every box's geometry agrees.

Block-level normal flow is direction-agnostic, as it is in the source. CSS 2.1
§10.3.3 asks the *start* margin to be ignored when a box is over-constrained in a
right-to-left containing block, but `try_compute_width()` never consults
`direction` - it always gives the remainder to `margin-right` - and no other part
of `BlockFormattingContext.cpp` reads `direction` either. The former
direction-aware branch placed every fixed-width block child at the right content
edge under `direction: rtl`; a generated 60-case matrix over direction, width,
and both inline margins now agrees with upstream on all 60, including the
negative remainder of an over-wide child.

`<meter>` now builds the same UA-internal layout subtree as `<progress>`:
`HTMLMeterElement::create_shadow_tree_if_needed()`'s `::slider-track` and
`::slider-fill` pair, with the meter's `Default.css` border and `height: 100%`
rules and the fill width `update_meter_value_element()` computes as
`(value - min) / (max - min) * 100%`. A degenerate range formats as `nan%` in
the source, which is not a valid declaration, so the fill keeps its automatic
width. `TextInputBox` and `TextAreaBox` also resolve their `size`/`cols`/`rows`
attributes as real `ch` and `lh` lengths against the box's own font, rather than
multiplying a raw font advance, so the advance is quantized to `CSSPixels` before
it is scaled exactly as `CSS::Length::to_px()` does.

Absolutely and fixed-positioned boxes now record their solved insets, as
`compute_width_for_absolutely_positioned_non_replaced_element()` and
`compute_height_for_absolutely_positioned_non_replaced_element()` do. Only
`position: relative` had been storing them, so `getComputedStyle()` reported
every inset of a positioned box as `0px`: the resolved value of
top/right/bottom/left is the used one whenever the specified inset is a
percentage, a calculation, or `auto`, and an `auto` side has to carry the
distance the layout actually produced. Grid containers likewise record the final
track base sizes and the explicit line names between them, which
`LayoutState::commit()` hands to the paintable so that "for
grid-template-columns and grid-template-rows the resolved value is the used
value" holds; the implicit `<area>-start`/`-end` names that
`grid-template-areas` contributes are excluded, as they are upstream. A
1,626-reading `getComputedStyle()` differential across sizing, box model, flex,
grid, text, transforms, filters, colours and positioning now agrees with
upstream on every value.

A 118-case differential over multi-column geometry, vertical writing modes with
real text, `<col>`/`<colgroup>` tables under both border models, floats with
`clear`, and justified text agrees with upstream on every case except two
`<colgroup>` behaviours, where this implementation is ahead of it.

KNOWN DEVIATIONS: `TableFormattingContext::compute_table_measures()` reads
column widths only from `<col>` boxes nested inside a `<colgroup>`, and assigns
each width to `m_columns[column_index]` alone before advancing the index by the
column's `span`. Two cases follow from that, and this implementation handles
both instead:

- A spanning column applies its width to every column it represents, not just
  the first. `<col span="2" style="width:70px">` over two cells sizes the table
  to 140px here and to 82px upstream.
- A `<colgroup>` with a `span` attribute and no `<col>` children still
  represents that many columns, so its width applies to them.
  `<colgroup span="2" style="width:70px">` sizes the table to 140px here and to
  24px upstream, where the group contributes nothing at all - even though the
  comment above that loop states that "the outer min-content width of a
  table-column or table-column-group is max(min-width, width)".

The upstream Layout regression corpus is exercised directly by
`tools/layout_corpus.v`. It discovers every HTML or SVG input with a matching
expected snapshot and compares the current upstream layout-tree and
stacking-context sections exactly. The 2026-03-24 checkout had 904 comparable
cases and all 904 passed byte-for-byte. The refreshed 2026-09-11 checkout has
1,089 cases; after translating the post-March dump format and deterministic
font setup, 639 pass and 450 remain as layout-semantic translation work.

The detached `BlockBox` compatibility layout now retains static-position data
at the same formatting-context boundary as C++. Its block pass records the
current border-box flow cursor before pending adjoining margins, and its inline
pass resolves an out-of-flow box from the last fragment belonging to its
immediate previous sibling after wrapping and trailing-space handling. Absolute
positions cross static ancestors and stop at the nearest positioned containing
block; fixed positions continue to the initial containing block. Auto inset
placement from block and inline formatting contexts therefore no longer
substitutes the containing block's padding-box origin. Focused regressions cover
padding, pending margins, a static intermediate ancestor, and both
inline-outside and block-outside IFC placement. The compatibility flex path now
also retains C++'s content-box rectangle after the container's final size is
known, maps every `justify-content` keyword through the main-direction reversal
rules, swaps main/cross axes for columns, and resolves `align-self` only after
the abspos margin box is final. Static grid contexts retain their content-box
rectangle through an outer containing block as well. Positioned grids now keep
the static-position rectangle separate from C++'s per-item inset containing
rectangle: explicit row/column lines select their grid area, auto axes use the
augmented padding-edge lines, content alignment and RTL determine its physical
origin, and percentage insets and sizes resolve against that area. The area is
also propagated through static descendants of an in-flow grid item, while a
nearer positioned item continues to establish its own containing block.
Compatibility row tracks now share the column sizing phases rather than deriving
every row solely from its tallest auto-placed item. Focused regressions cover
explicit two-dimensional areas and rows, self-alignment, percentages, padding
edges, content alignment, RTL, and a nested abspos descendant. The active typed
formatting contexts retain the same data in `LayoutState`.

The default-page spacing defect was caused by the old renderer transport
painting individually estimated word fragments. The typed adapter now preserves
each committed `LineBoxFragment` as the corresponding C++ `PaintableFragment`.
It no longer splits a shaped text run into word objects, clones inline paint
state into every word, and concatenates them again immediately before native
shaping. The detached compatibility layout can still coalesce its legacy word
fragments, while the active typed path reaches painting without that round trip.

The native shell now obtains paint commands through `Document::record_display_list()`
instead of calling the compatibility box tree directly. As in C++,
`ViewportPaintable::build_stacking_context_tree()` retains one sorted paint plan
shared by display-list recording and hit testing until stacking invalidation,
and the native boundary shares the retained command storage rather than cloning
the entire display list. Each retained paintable also keeps its commands split
by `PaintPhase`, matching `PaintableBox::m_cached_phase_commands`: ordinary
document repaint requests only replay those buckets. A
`PaintableBox::set_needs_repaint()` request invalidates and selectively rebuilds
the affected box plus its anonymous children, while explicit all-cache or
stacking-tree invalidation reconstructs the complete store.
Checkbox and radio foreground commands read the owning `HTMLInputElement`'s
live checked/indeterminate state when their phase bucket is rebuilt; checkedness
changes use the translated style and repaint invalidation path, so retained
commands cannot preserve the layout-time `checked` attribute snapshot. Direct
and fieldset-inherited disabled-state changes invalidate those same retained
phase buckets before the next display-list recording.

`NavigableContainerViewport` now retains its concrete `about:blank` or
`srcdoc` DOM document through the typed layout tree. During parent display-list
recording that document is updated at the iframe's content-box size and its
display list is retained as a nested command stream, matching the upstream
hosted-document-before-paint ordering. Replay translates the child coordinate
space at the nested-list boundary and preserves the parent's transforms,
rounded clipping, masks, and opacity.

`NodeWithStyle::apply_style()` now follows the upstream resolved-value boundary:
hot typed CSS values are materialized once and layout reads those slots instead
of repeatedly decoding `StyleValue` objects. Style propagation and the table,
fieldset, viewport-overflow, and anonymous-cell mutation paths keep the resolved
snapshot synchronized. A regression verifies that source-property mutation is
not visible until the next style application.

That boundary now also retains the document font cascade, list-style type,
counter reset/increment/set arrays, resolved colors, borders/radii, masks and
clip paths, SVG paints, shadows, and scrollbar colors. Counter-tree and marker
construction consume the retained values, and `Node::first_available_font()`
selects from the materialized cascade. If a retained line fragment outlives a
style mutation that invalidates the aliased V cache, the accessor rematerializes
it through the document's shared font computer; this preserves C++'s immutable
ComputedValues lifetime and prevents repeated rewrap relayouts from reaching an
empty cache.

Committed line fragments now retain their exact shaped `GlyphRun` through the
active paint bridge. A direct `PaintableWithLines` foreground translation
splits each fragment into before/selected/after UTF-16 spans, resolves
`Paintable::selection_style()` including explicit inheritance and UA shadow-host
fallback, paints every selection background before shadows and glyphs, and
clips partial colors from the original full run. Text-control ranges take
precedence over the document selection. Selection-state changes selectively
invalidate the containing retained paint bucket, and the ordinary
no-selection/no-shadow path remains coalesced. A focused regression covers
custom background, replacement shadow, wavy decoration, webkit fill color,
range geometry, command order, and cache invalidation.
Display-list recording now also preserves those runs through backend replay.
As in `GlyphRun::ensure_text_blob()`, packed glyph IDs and positions are
refreshed only after line construction has finished merging shaped chunks; the
native player draws them through their concrete document or emoji face and the
full accumulated affine transform, without asking AppKit to reshape the source
string on every repaint. Partial foreground spans clip the original run, while
text shadows retain C++'s UTF-16-to-glyph slicing without rebasing positions.
Compatibility-only word commands and vertical-orientation native fallback keep
their existing string path.
`PaintableWithLines::fragment_at_position()` and `paint_cursor()` now complete
that foreground path. Fragment carets use the retained UTF-16 glyph-run geometry;
empty editing hosts fall back to their padding-box origin and computed line
height; and transparent/custom caret colors follow the source checks. The
retained cache keys the caret's layout node, offset, blink state, and navigable
focus so movement between boxes or within one text node regenerates only the old
and new foreground buckets.

`PaintableWithLines::hit_test()` and `hit_test_fragments()` now replace the
bridge's former box-only shortcut. Inline fragment hits retain their exact DOM
text node and glyph-derived UTF-16 offset. Text-cursor misses use the source
vertical/horizontal nearest-edge candidates, selection common-ancestor and
`user-select: none` gates, while empty editable hosts produce offset zero. The
fragment walk uses the containing box's descendant visual context so scrolling,
transforms, and clipping remain shared with painting.

`PaintableBox::hit_test_chrome()` and `resizer_contains()` now share the active
overlay's translated scrollbar and resize geometry. Hit testing walks the
retained stacking-context paint phases backwards: overlay chrome precedes
descendants, foreground fragments precede their containing box, and border
geometry supplies the box fallback. This removes the flat-order bug that let a
scroller's child intercept its scrollbar. Horizontal/vertical scrollbar
identity, resize-corner precedence, border inflation, pointer-event gating, and
the source's inline `PaintableWithLines` gate have focused regressions. A
separate retained hit phase plan includes zero-opacity stacking contexts while
still excluding non-invertible transforms, matching `StackingContext::hit_test()`
rather than inheriting `paint()`'s transparent-context early exit. The same
plan drives `elementsFromPoint()`, so chrome-owning elements precede descendants
at scrollbar coordinates there as well.

The chrome input bridge now routes resize-handle pointer events through
Painting's retained `ResizeHandle` state machine and Page's
`ElementResizeAction`. Primary-button press captures input, uncaptured moves and
non-primary presses are ignored, subsequent moves update the element's inline
width and height with writing-mode/direction, min/max, and box-sizing rules, and
pointerup applies the final position before releasing capture. Active state is
copied across the layout invalidation caused by the style mutation, while
stable DOM-node chrome IDs keep the captured widget connected to its rebuilt
`BlockBox`. A focused regression performs a drag, forces relayout mid-capture,
continues the drag, and verifies final release. The native `BrowserApp` now
feeds mouse down/move/up through this Page-to-Layout bridge, adopts geometry
after resize-triggered layout, and maps the handle's physical axis to the
platform resize cursor. Its boundary regression begins outside Layout, drags
beyond the old box, observes the new inline size, and releases capture.

Inspector selection now reaches that same retained display list. Box highlights
unite continuation content, padding, border, and margin rectangles and append
the size tooltip; text highlights emit each fragment outline and baseline.
Only scroll, transform, and perspective visual contexts survive into this
overlay, so ancestor overflow, clip paths, masks, and effects cannot hide it.
Changing the DOM highlight invalidates the assembled list without discarding
the ordinary per-phase paint caches.

Each retained box now owns the same per-axis scrollbar state as
`PaintableBox`. Hover switches overlay recording and containment from the thin
thumb strip to the full gutter, while pointerdown, captured pointermove, and
pointerup call the translated `Scrollbar` state machine. Track clicks use its
constrained half-thumb grab rule, drags update the live DOM scroll offset on the
fixed CSS-pixel grid, and repaint/scroll-state invalidation continues through
the existing paintable callbacks rather than rebuilding layout. Widget identity
resolves through an index retained with the hit plan, so captured pointer events
remain O(1) instead of walking the paint tree on every move.

The active compatibility paint bridge now builds long text runs with a
capacity-sized `strings.Builder`, retains box references through paint-order
and hit-test traversal, skips invisible hit-test candidates, and sorts stacking
entries by Ladybird's `(z-index, tree order)` key in O(n log n). Regressions use
2,048 text fragments and 2,048 reverse-z-index contexts. The active renderer now
translates `Painting::StackingContext::paint_internal()`'s phase walk instead of
emitting every flattened box atomically: root background/border, negative
contexts, block backgrounds, floats, inline/replaced backgrounds, foregrounds,
zero/auto descendants, positive contexts, and outlines are replayed separately.
It also skips zero-opacity and non-invertible transform contexts. CSS transform
matrices are accumulated while descending the typed paint tree, matching the
stacking-context traversal without recursively copying an already-built subtree
for every transformed ancestor. Hit testing retains that source-shaped phase
plan with the stacking-context tree until invalidation instead of reconstructing
and sorting it for every pointer event. It resolves retained DOM identities directly,
inverse-maps points through accumulated transforms, and applies `visibility`,
`pointer-events`, and non-invertible-transform filtering at the same boundary as
`PaintableBox::hit_test()`. Ordinary paintable boxes use the translated
normalized elliptical border-radii containment check, while stacking-context
roots preserve `StackingContext::hit_test()`'s rectangle-only source behavior.
The active box, chrome, empty-editable, and text-fragment paths now share direct
translations of `PaintableBox::transform_point_to_local()` and its descendants
variant rather than invoking the visual tree through separately maintained
shortcuts. The same bridge retains `transform_rect_to_viewport()`,
`inverse_transform_point()`, and `transform_to_local_coordinates()`, including
the zero-context fast path, float device scaling, clip failure, and final
fixed-CSS-pixel conversion. Common visual-context chains use the upstream
eight-entry inline ancestor capacity, avoiding a heap array for each candidate.
The native shell consumes this same
viewport callback instead of independently flattening `BlockBox` during mouse
movement. The final
retained replay also consumes Painting's translated `ScrollState` snapshots.
Chrome and overflow decisions on that path now call source-shaped translations
of `PaintableBox::overflow_property_applies()`, `physical_resize_axes()`,
`has_resizer()`, and `is_chrome_mirrored()`. The shared predicates preserve the
SVG, inline, ruby, and internal-display exclusions; table-cell/caption
exceptions; viewport/pseudo-element suppression; logical resize-axis mapping;
and RTL/vertical writing-mode mirroring used by C++.
Overlay geometry likewise consumes Painting's direct
`PaintableBox::available_scrollbar_length()`, `absolute_scrollbar_rect()`,
`compute_scrollbar_data()`, and `absolute_resizer_rect()` translations. The
former combined helper's early clamp of undersized resizer-adjusted lengths is
gone, preserving the source's signed rectangle until device clipping.
Scroll-frame parentage now translates
`PaintableBox::nearest_scroll_frame_index()` directly. A fixed paintable gets
the zero/root parent; an intervening fixed containing block terminates an
ordinary descendant's search, while a sticky descendant crosses that boundary
to find the outer scrollport required for sticky constraints. Focused tests
cover the active fixed-scroller path and both synthetic boundary branches.
Sticky inset resolution separately follows
`PaintableBox::nearest_scrollable_ancestor()`. Unlike scroll-frame parentage,
that containing-block walk tests whether each box accepts wheel scrolling and
therefore skips `overflow:hidden`. Percentage insets use the returned box's
content size, matching `LayoutState.cpp`, while sticky movement remains attached
to the nearest scrolling frame.
`PaintableBox::overflow_clip_edge_rect()` is likewise a standalone operation on
the active visual-context path. It chooses the absolute padding box for normal
boxes and the content box for replaced boxes before applying the four resolved
overflow-clip margins. A focused geometry matrix covers both origins and
asymmetric edge inflation.
The typed adapter also constructs outlines through a direct translation of
`PaintableBox::outline_data()`. Its one result supplies color, line style, and
width together after the source's `auto` accent override and shared invisible
outline suppression, avoiding three separately maintained conversions.
The adapter's border-radius path now directly translates
`PaintableBox::border_radii_data()` and `normalized_border_radii_data()`.
Radius resolution, exact overlap-factor comparison, both fixed-point refinement
passes, and truncating multiplication occur before conversion to the renderer
transport. Padding-edge clips then perform only the source's adjacent-border
shrink; the previous extra normalization could let a wide opposite border
collapse an unrelated corner radius.
The active hit-test bridge also translates
`Paintable::visible_for_hit_testing()`, so inert DOM nodes no longer win
`elementFromPoint()`. For an anonymous block in the middle of a split inline
chain, `PaintableBox::hit_test_continuation()` walks back to the principal
inline paintable and returns that element only after the block descendants
decline the hit.
SVG path candidates additionally apply `SVGPathPaintable::hit_test()`'s
transformed raw-path bounding quad before this shared traversal. The surrounding
stroke-inflated layout box therefore cannot win a hit outside the source path
bounds.
The DOM/Layout paintable bridge also exposes
`Paintable::box_type_agnostic_position()`: boxes return the retained content
origin and inline paintables use their line container's first fragment. The
HTML label activation path consumes this after a layout update to rewrite the
cloned control click's offsets relative to the control.
The DOM mirror also preserves the layout tree's split-inline continuation chain
in forward order. This lets `PaintableBox`'s united geometry and the CSSOM
`offsetTop`, `offsetLeft`, `offsetWidth`, and `offsetHeight` algorithms account
for every continuation without replacing the DOM element's principal layout
node.
The mandatory viewport frame and normal overflow frames apply live, clamped
scroll offsets to descendant commands and hit testing without reconstructing
layout or its cached paint phases; padding-box clips and dynamically positioned
scrollbar thumbs use that same snapshot. Sticky frames translate the C++ inset,
scrollport, containing-block, and parent-sticky constraint calculation for both
element and root viewport scrolling, while fixed-position contexts inherit the
root visual context and remain anchored. Overflow clips retain each nested
visual-context node, its transform, and its elliptical per-corner radii in a
shared context list. Native Quartz replay intersects the corresponding
antialiased rounded paths, matching `DisplayList::apply_accumulated_clip()`
instead of scissoring their rectangular intersection. CSS basic-shape
`clip-path` is now appended after the box transform just as in
`ViewportPaintable::assign_accumulated_visual_contexts()`. Its exact Gfx-style
segments and fill rule reach Quartz replay, including Bezier and elliptical-arc
geometry and even-odd subpath holes. Hit testing shares the same context and
uses contours flattened once during paint-tree construction rather than
reparsing or retessellating the shape per event. CSS2 `clip: rect(...)` is also
translated through `PaintableBox::get_clip_rect()`: only absolute/fixed boxes
resolve it, its offsets use the absolute border box, negative extents produce an
empty clip, and the node is appended between the box transform and `clip-path`
so it clips self-paint, descendants, and hit testing. The `clip`, transformed
clip, offscreen clip, absolute-descendant clip, and clipped-image upstream
reftest pairs are pixel-identical.
`PaintableBox::transform_reference_box()` now supplies transform dimensions and
origins instead of hard-coding the border box. CSS and SVG box-type remapping,
the nearest SVG viewport for `view-box`, and the upstream fill/stroke box
approximations are preserved. The computed transform path also composes
individual `translate`, `rotate`, and `scale` before the legacy transform list,
including percentage resolution against the selected reference box. The HTML
transform-box reftest and both WPT individual-transform pairs are pixel-exact;
the comprehensive HTML/SVG screenshot's MAE fell from 4.6117 to 0.2584.
Text decorations now retain the committed fragment baseline and selected font
metrics through this bridge. The active painter directly follows
`PaintableWithLines::paint_text_decoration()` for device rounding, minimum
thickness, underline offset/position, solid/double/dotted/dashed line placement,
and the round-joined triangular wave path. Three focused upstream reference
pairs render with zero differing pixels.
Native checkbox and radio foregrounds no longer use renderer-local white
rectangles, ellipse strokes, and an approximate tick. The typed bridge retains
the computed color scheme and accent color while live paint reads checked,
indeterminate, enabled, and activation state. Painting's direct
`InputColors`/`CheckBoxPaintable`/`RadioButtonPaintable` translations emit the
rounded layers and exact checkmark path. A focused upstream capture matches
geometry and colors, with scale-normalized MAE 0.9256 from raster edges.
Fieldset nodes now retain a source-shaped `FieldSetPaintable` with the absolute
fieldset border box, CSS top-border width, and rendered legend margin/border
geometry. Background and split top-border recorder clips remain local to their
commands, then compose with the same accumulated transforms, overflow clips,
and masks as ordinary visual-context clips. This replaces the generic border
path that painted through a transparent legend.
Geometric list markers no longer branch into renderer-local rectangles,
ellipses, and polygons. The adapter resolves a typed marker kind and sends the
rounded marker rect through `MarkerPaintable::paint()`; its typed fill, ellipse,
and exact path commands then use the ordinary retained visual context. Native
ellipse replay restores the formerly absent `circle` and `disc` markers.
`SVGMaskable`'s URL `<clipPath>` path is active too: attached resource geometry
is omitted from normal child painting and retained as exact mask components.
Target, resource, child, viewBox, and `objectBoundingBox` transforms compose at
the same paint boundary as C++; component `clip-rule` values union into one
cached native alpha mask. Empty clip resources fully suppress the target, while
hit testing intentionally ignores the paint-time mask. Ordinary SVG paths now
use the same exact retained segments and computed fill/stroke style in the
native renderer instead of the former polygon endpoint fallback. SVG `<mask>`
path content now retains normal fill/stroke paints, separate fill/stroke
opacity, `paint-order`, nested group-opacity layers, `maskContentUnits`, and the
resolved masking area. The native backend converts the composited resource to
alpha or luminance and applies it once to the complete target layer with
`destination-in`; URL clip paths use the same whole-target layer semantics.
Their shared bounded cache stores only transformed mask bounds. Mask content
using ordinary SVG text now follows C++'s `Gfx::Path::text()` boundary: scaled
TrueType contours, including implied on-curve points, become retained quadratic
segments and pass through the same fill/stroke and mask paint path. SVG
`<textPath>` follows `Path::place_text_along()` by measuring only the first
contour, rotating each outline to the current tangent, applying the midpoint
cutoff, and advancing by the font glyph width. `layout_path_like_element()` also
advances the current text position from an SVG text element's own path only
after laying out its nested text children, matching where C++ assigns
`m_current_text_position`. A `<text>` whose characters all live in `<tspan>`s has
an empty path, so advancing before the recursion discarded the `x`/`y` it had
just resolved and started every child from the SVG origin. The old generic `svg_text_`
transport has been removed. `dominant-baseline: auto` now resolves through the
computed writing mode as upstream does: alphabetic for horizontal/sideways
text and central for vertical text until `text-orientation` is implemented.
All explicit baseline metrics retain their font-metric offsets. SVG `<image>`
now follows `ImagePaintable`: its
`href`/XLink precedence, intrinsic-ratio dimension fallback, forced `contain`
fit, computed object position, translated `image-rendering` scaling selection,
image-rect clip, and CSS visual-context transform cross the active renderer boundary. HTML `<img>` and SVG `<image>` now both retain the typed
`ImagePaintable` inputs and run object fitting, fixed-point positioning, scaling
selection, and border-shrunken corner clipping in the translated paint method;
they no longer detour through the renderer's CSS-background string resolver.
Unavailable HTML images retain the same paintable and use its other foreground
branch: a black content-box outline plus centered, computed-color `alt` text in
the default 12px font. The retained `ImageBox` refreshes selected source,
provider availability, intrinsic dimensions, and the live `alt` attribute
before each relayout, allowing fallback text and decoded content to replace one
another without a layout-tree rebuild.
The same bitmap operation is retained in
SVG mask display-list order and participates in alpha/luminance conversion and
nested group opacity. Canvas boxes likewise retain a dedicated
`CanvasPaintable` only when their element already owns a surface. The adapter
presents that surface before retaining its RGBA bitmap, preserves
`image-rendering` and border-shrunken corner radii, and emits external content
instead of the old bitmap classification; untouched canvases do not allocate a
default paint surface. Video boxes retain the HTML model's exact current/first
frame, poster, or transparent-black representation and pass it through the
dedicated `VideoPaintable`; live frames use external content while posters use
immutable bitmap commands, with scaling and clipping resolved in Painting.
URL `<linearGradient>`, `<radialGradient>`, and `<pattern>`
fill and stroke paints are active for ordinary
geometry/text and path content inside SVG masks. The typed adapter follows the
linked-resource algorithms for href precedence, coordinate and generic-attribute
inheritance, stop normalization, object-bounding-box/user-space coordinates,
transforms, spread mode, and color interpolation. Radial gradients retain their
focal/end centers and radii, including `fr` and upstream's negative-radius
inheritance behavior; valid resources no longer collapse to their fallback
color. Same-document CSS `filter: url(#id)` now resolves the live SVG filter
element and lowers its source-shaped graph after the standard CSS filter chain.
The active layer keeps named inputs, SourceAlpha, computed flood style, the
resolved filter region, and C++'s transparent bounds trigger for graphs that
generate content from an empty source. Native replay covers flood,
blend/composite/arithmetic, anisotropic blur and morphology, color transforms
and component-transfer tables, merge, offset, and channel-selecting
displacement. Turbulence rasterization and decoded-bitmap `feImage` graph inputs
now reach native replay, including filter boundaries nested in retained SVG
pattern tiles.
Wheel events follow
`EventHandler::handle_mousewheel()`:
they walk the hit paintable's containing blocks, skip programmatic-only
`overflow:hidden`, and fall back outward when an inner scroller reaches its
clamped edge. Focused regressions cover vertical, horizontal, nested, sticky,
fixed, hidden-overflow, retained-replay, scrollbar, and hit-test behavior. The
selection and text-control paths also translate
`Paintable::scroll_ancestor_to_offset_into_view()`: retained UTF-16 fragment
geometry locates the caret, then the typed containing-block chain scrolls the
nearest overflow box or root viewport without rebuilding layout. The
overlay phase now consumes Painting's translated `compute_scrollbar_data()` and
ports `PaintableBox::paint()`'s vertical/horizontal scrollbar order, initial and
custom colors, RTL/vertical chrome mirroring, `scrollbar-width:none`, current
scroll-offset thumb placement, resize applicability, and resize-gripper line
loop. Focused tests exercise those phase boundaries and typed CSS transport.
The active path now also follows `PaintableBox::paint()`'s dedicated table-border
phase. Table layout retains full winning conflict borders and cell coordinates,
uses packed coordinate maps instead of repeated placement scans, and Painting
snaps the resulting separate or collapsed edges to shared device lines. Cell
radii reach the exact rounded repaint pass. Ordinary block and inline-fragment
borders also retain their four computed `LineStyle` values and call Painting's
translated `paint_all_borders()`: joined elliptical paths, even-odd fill,
same-color batching, inset/outset HSV colors, dotted/dashed lines, and recursive
double/groove/ridge bands now cross the compatibility renderer boundary intact.
The immediate-mode compatibility bridge now walks accumulated visual contexts
parent-first with the same recursive shape as display-list playback. It no
longer builds and reverses a dynamic ancestor array for every distinct command
context; transform, scroll, clip, SVG mask, and filter ordering remain unchanged.
The outline phase inflates the outer border geometry and radii, clamps excessively
negative offsets, resolves `auto` to a 2px accent-color solid, and invokes that
same dispatcher instead of drawing local rectangles or a rounded stroke.
Root-canvas background preparation now follows the root/body branches of
`PaintableBox::paint_background()` as one operation. Body background propagation
copies `image-rendering` together with the retained color and layers, so decoded
body background images no longer use the transparent root's sampling mode.
URL background layers now retain `CSS::BackgroundLayerData` through the typed
adapter and call Painting's translated sizing/repetition algorithm only after
the renderer has decoded the image. `round`, `space`, contain/cover, one-axis
`auto`, fixed/local/scroll attachment, and CSS fixed-point positioning therefore
follow `BackgroundPainting.cpp` rather than the old string-based replay loop.
Live local and viewport offsets are refreshed while replaying cached phases;
the native command resolves before applying transforms and clips each layer to
its background-box-adjusted elliptical radii. Non-normal URL layers are wrapped
with the source-shaped background-only isolation group and retain all 18 blend
modes through Quartz and portable SVG replay.
Linear, radial, and conic gradients now remain in that same typed image list in
CSS source order instead of being extracted as one renderer-local gradient.
They use the no-intrinsic-dimensions branch of the translated sizing algorithm,
resolve percentage geometry and stops against each concrete tile, and carry
per-layer origin, clip, position, size, repeat, attachment, and blend state.
Stop normalization, repeat expansion, and transition-hint sampling now route
through Painting's shared `GradientPainting.cpp` translation rather than a
duplicate Layout implementation; only the final conversion to the compact
native transport remains in Layout.
`PaintableBox::paint_backdrop_filter()` is now active as a distinct first
command in the background phase. It resolves the computed `backdrop-filter`
through the same translated helper as ordinary CSS filters, converts it with
`ResolvedCSSFilter::to_gfx_filter()`, and retains the rounded border box,
elliptical corner radii, visual transform, and ancestor clips. Native replay
samples pixels already painted behind the box and renders only the affected
device bounds; a box's ordinary `filter` remains outside the backdrop operation
in the same order as C++. The frame-level bitmap requirement is cached with the
display-list command store and is not paid by pages without backdrop filters.
This path is shared by block and inline-fragment backgrounds. Portable SVG and
native Quartz both materialize the translated repeated-tile geometry. Quartz
now mirrors `DisplayListPlayerSkia::paint_*_gradient()` by submitting one axial,
elliptical-radial, or conic shading operation per tile instead of up to 16,384
four-polygon fills. The old tessellator remains only for non-native rendering
and pre-macOS-14 conic gradients. Native geometry remains tile-local under CSS
transforms and clips to the exact background-box-adjusted elliptical radii.
Root gradients retain the upstream ordering of resolving against the root
border box before extending their repeat clip to the canvas.
Resolved gradients also retain the parser's color interpolation method. The
shared sampler mirrors the premultiplied color-space and hue configuration from
`DisplayListPlayerSkia::to_skia_interpolation()` instead of blending encoded
sRGB channels unconditionally. Portable SVG selects `linearRGB` where SVG can
represent it exactly and expands the other modern spaces into sampled stops, so
native and portable replay preserve the same interpolation semantics. The
Quartz one-draw path samples each resolved span before creating `CGGradient`,
retaining duplicate-position hard stops and the translated Skia color result
while leaving only short sRGB intervals for CoreGraphics to interpolate.
`background-clip:text` now follows `compute_text_clip_paths()` as well. A
balanced background-phase mask owns the shaped runs from the paintable's
inclusive subtree, prunes absolute/fixed descendants but includes floats, and
wraps the color plus every image layer once outside the optional blend-isolation
group. The root bypasses that mask. Native Quartz builds a bounded mask from the
same retained glyph indices and positions used for foreground text, while
portable SVG serializes the corresponding user-space text mask.
Text fragments use the same nearest
non-atomic `InlineNode` ancestor walk as `LayoutState::commit()`, so direct block
text no longer repaints the block's background, border, radii, or box shadow as
an invented inline box.

Each committed document paint tree now collects the concrete paintable boxes
whose used `content-visibility` is `auto` and installs that filtered cache on
the viewport bridge. The HTML rendering loop can therefore update proximity
without traversing the entire retained tree on every frame.

The remaining integration gap is replacing the compatibility
`BlockBox`/`PaintCommand` transport with Painting's typed paintables and
display-list recorder, including interactive scrollbar enlargement/snapshot
replay. Decoded-bitmap `feImage`, native `feTurbulence`, and
interpolation-color-space conversion now flow through the retained graph.
Pattern tile display lists also retain nested filter begin/end operations and
normalized graph bounds.

## Verification

Verified through 2026-09-11:

```text
$ /Users/alex/code/v/v -enable-globals run tools/layout_corpus.v --all
Layout corpus: 639 passed, 450 failed, 1089 total

$ /Users/alex/code/v/v -enable-globals test .
Summary for all V _test.v files: 394 passed, 394 total.

$ /Users/alex/code/v/v -enable-globals test layout
Summary for all V _test.v files: 22 passed, 22 total.

$ /Users/alex/code/v/v -enable-globals test css
Summary for all V _test.v files: 26 passed, 26 total.

$ /Users/alex/code/v/v -enable-globals test integration
Summary for all V _test.v files: 2 passed, 2 total.

$ ./build_ladybird.sh
Built V-native Ladybird app: Build/v/Ladybird.app

$ Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
Ladybird V smoke check passed
```

## Module boundary

Layout consumes state supplied by HTML media/navigable objects and produces
renderer-facing data consumed by Painting and the native shell. Loading video
frames, creating child browsing contexts, system typeface discovery, and native
rasterization remain responsibilities of those modules and platform hosts; they
are not omitted Layout algorithms.
