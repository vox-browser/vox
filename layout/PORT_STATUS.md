# Layout module V translation — present; semantic re-audit in progress

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/Layout`

Re-audited: 2026-09-05

All 50 upstream Layout `.cpp` units have filename-level homes in the typed V
Layout package. That inventory does not establish body-level parity: the
current semantic audit reports 597 unmatched Layout implementations, and the
legacy `BlockBox` renderer transport still sits between typed Layout and the
native shell.

The symbol-level audit excludes the former class-shaped
`upstream_*entry_points.v` facades because matching a C++ method name without
porting its body is not translation coverage. The live path uses typed layout
nodes and dense `LayoutState` storage, but each unmatched method still requires
comparison with the current upstream body.

## Translated coverage

The translated path includes the complete layout-node hierarchy and tree
builder; incremental style application and anonymous/table-wrapper propagation;
block, inline, flex, grid, table, fieldset, replaced-with-children, SVG, and
absolute-position formatting; floats, clearance, margin collapse, intrinsic
sizing, aspect-ratio constraint solving, line construction and breaking,
generated content and counters, list markers, relative positioning, overflow,
SVG natural metrics and transforms, typed used-value state, layout/DOM bridging,
debug dumps, and the typed layout-to-renderer adapter used by the executable.

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
every phase.
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

The upstream Layout regression corpus is exercised directly by
`tools/layout_corpus.v`. It discovers every HTML or SVG input with a matching
expected snapshot and compares all three upstream sections exactly: layout tree,
paint tree, and text. The current checkout has 904 comparable cases; all 904
pass byte-for-byte.

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
commands cannot preserve the layout-time `checked` attribute snapshot.

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
selects directly from the materialized cascade instead of entering the style
computer from a layout query.

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
for every transformed ancestor. Hit testing retains that sorted paint order with
the stacking-context tree until invalidation instead of reconstructing and
sorting it for every pointer event. It resolves retained DOM identities directly,
inverse-maps points through accumulated transforms, and applies `visibility`,
`pointer-events`, and non-invertible-transform filtering at the same boundary as
`PaintableBox::hit_test()`. Its final border-box test also uses the translated
normalized elliptical border-radii containment check, so clipped corner pixels
fall through to the paintable underneath. The native shell consumes this same
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
transport has been removed. SVG `<image>` now follows `ImagePaintable`: its
`href`/XLink precedence, intrinsic-ratio dimension fallback, forced `contain`
fit, computed object position, translated `image-rendering` scaling selection,
image-rect clip, and CSS visual-context transform cross the active renderer boundary. HTML `<img>` and SVG `<image>` now both retain the typed
`ImagePaintable` inputs and run object fitting, fixed-point positioning, scaling
selection, and border-shrunken corner clipping in the translated paint method;
they no longer detour through the renderer's CSS-background string resolver.
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
remain backend gaps.
Wheel events follow
`EventHandler::handle_mousewheel()`:
they walk the hit paintable's containing blocks, skip programmatic-only
`overflow:hidden`, and fall back outward when an inner scroller reaches its
clamped edge. Focused regressions cover vertical, horizontal, nested, sticky,
fixed, hidden-overflow, retained-replay, scrollbar, and hit-test behavior. The
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
group. The root bypasses that mask. Native Quartz builds a bounded mask with the
same configured document font used for foreground text, while portable SVG
serializes the corresponding user-space text mask.
Text fragments use the same nearest
non-atomic `InlineNode` ancestor walk as `LayoutState::commit()`, so direct block
text no longer repaints the block's background, border, radii, or box shadow as
an invented inline box.

The remaining integration gap is replacing the compatibility
`BlockBox`/`PaintCommand` transport with Painting's typed paintables and
display-list recorder, including interactive scrollbar enlargement/snapshot
replay. The remaining SVG-filter backend work is native `feTurbulence` and
decoded-bitmap `feImage` graph execution.

## Verification

Verified through 2026-09-05:

```text
$ /Users/alex/code/v/v_old -enable-globals run tools/layout_corpus.v --all
Layout corpus: 904 passed, 0 failed, 904 total

$ /Users/alex/code/v/v -enable-globals test layout
Summary for all V _test.v files: 18 passed, 18 total.

$ /Users/alex/code/v/v -enable-globals test css
Summary for all V _test.v files: 26 passed, 26 total.

$ /Users/alex/code/v/v -enable-globals test integration
Summary for all V _test.v files: 2 passed, 2 total.

$ ./build_ladybird.sh
Built V-native Ladybird app: Build/v/Ladybird.app

$ Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
Ladybird V smoke check passed
```

The repository-wide test command currently reports 324 passed and 11
compile-time failures in unrelated packages. None of those failures is in
Layout, CSS, or integration; they are V-compiler compatibility issues in
Encoding, Infra, Page, Platform, an SVG test, WebAssembly, WebDriver, and
WebIDL.

## Module boundary

Layout consumes state supplied by HTML media/navigable objects and produces
renderer-facing data consumed by Painting and the native shell. Loading video
frames, creating child browsing contexts, system typeface discovery, and native
rasterization remain responsibilities of those modules and platform hosts; they
are not omitted Layout algorithms.
