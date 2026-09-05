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

KNOWN DIVERGENCE, diagnosed but not yet fixed: flex lines are positioned by a
cursor that starts at the cross-start edge and adds each line's cross size, where
`align_all_flex_lines()` computes a per-keyword `start_of_current_line` and, for
the keywords that set `place_items_backwards`, *subtracts* each line's cross size
from the container's cross edge. The two agree except when the stretched line
sizes do not add up to the container exactly: `align-content: stretch` over three
lines in a 160px container distributes 70px as a truncated 23.328125px each, so
the sum is 1/64px short and the last line placed lands 1/64px off. Upstream never
accumulates that residue because the line size cancels out of
`start - cross_size/2` plus the item's own `cross_size/2 - item_size` offset.
Closing it means translating that switch and its `place_items_backwards` /
`iterate_lines_backwards` flags wholesale rather than patching the cursor, since
the correct starting edge differs per keyword. It accounts for the 2 remaining
divergences in the generated flex corpus. Grid auto-placement also uses packed signed row/column keys for
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
`PaintableBox::hit_test()`. The native shell consumes this same viewport callback
instead of independently flattening `BlockBox` during mouse movement. The final
retained replay also consumes Painting's translated `ScrollState` snapshots.
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
reparsing or retessellating the shape per event. Wheel events follow
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
image-rect clip, and CSS visual-context transform cross the active renderer boundary. The same bitmap operation is retained in
SVG mask display-list order and participates in alpha/luminance conversion and
nested group opacity. URL `<linearGradient>`, `<radialGradient>`, and `<pattern>`
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
