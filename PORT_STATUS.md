# LibWeb V translation inventory

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb`

Translation workspace: `~/code/vox2`
Audited: 2026-09-28

## Upstream delta since the V snapshot

The last Ladybird commit on 2026-03-24 is
`1d025620e3344e3cc9aee26fe815d8675e4f9810` ("Everywhere: Move Mach
bootstrap listener into LibIPC"). The upstream checkout used for the current
refresh is `963d46a829f3e1b79f44dba9d02afb70654300fa` (2026-09-11).

The implementation review/translation workload between those commits is
**150,914 added lines in module-owned LibWeb `.cpp` files**. Rewritten and
removed behavior also has to be audited, so the complete implementation churn
is **288,219 lines**. These are physical diff lines and intentionally measure
the upstream review input, not the amount of V code a faithful translation
will produce.

| Diff scope | Files | Added | Deleted | Churn |
| --- | ---: | ---: | ---: | ---: |
| Module-owned LibWeb `.cpp` | 1,309 | 150,914 | 137,305 | 288,219 |
| Root-support LibWeb `.cpp` | 5 | 313 | 684 | 997 |
| All LibWeb headers | 1,442 | 42,247 | 29,692 | 71,939 |
| All LibWeb `.cpp` and headers | 2,756 | 193,474 | 167,681 | 361,155 |

There are 8,152 upstream commits in the range, of which 5,077 touch
`Libraries/LibWeb`. Reproduce the count and the per-module breakdown against
any upstream checkout with:

```sh
python3 tools/upstream_delta.py --upstream ~/code/3rd/ladybird
```

### 2026-09-11 rendering refresh slice

The current refresh translates the upstream behavior exercised by all 24
screenshot cases added after the baseline. It includes animated CSS image
timing and invalidation, single-value background sizing, canvas-to-canvas
ordering, form-control sizing/colors, fieldset clipping, inline-fragment
borders and shadows, adaptive overlay scrollbars, nested and out-of-line SVG
viewports, SVG clipping/patterns/non-scaling strokes and Skia gradient replay,
and FFmpeg-backed video/MSE/canvas frame presentation (including 10-bit YUV).
The comparison driver reads upstream fuzzy metadata and, on macOS only, admits
at most 64 additional sparse Skia CPU edge samples with a maximum channel error
of 20. Exact comparisons remain exact. All 24 new cases pass this bounded
workflow. The complete refresh run also covers the three default smoke cases
and five modified SVG cases: all 32 invocations pass (31 distinct fixtures).
The four CSS Scroll Snap initial-layout reftests also pass with exact zero-pixel
diffs, covering mandatory and proximity selection plus horizontal, vertical-lr,
and vertical-rl writing modes.
Button layout now forwards the button's definite block-size basis through its
anonymous flex and content wrappers. Percentage-height descendants therefore
continue to use the button content height when the content wrapper has a
smaller post-flexing height, including aspect-ratio, padded, fractional, nested,
and resized-equivalent cases.
Structured serialization records now keep a same-process side table for fixed
and growable shared array buffers. Local clones and cloned typed-array views
share one flattened backing store, while records crossing the byte-only IPC
boundary reconstruct an independent shared buffer from their encoded fallback
copy. Maximum lengths and growth remain visible through local aliases; storage
serialization and the default cross-origin-isolation gate still reject shared
buffers.
Custom properties declared in `@keyframes` now participate in animation
sampling. Registered values use typed computed-value interpolation and
composition, unregistered values animate discretely, important declarations
suppress the animation, and missing endpoints use the underlying value. The
sampled overlay is visible to `var()` resolution in longhands, shorthands, and
other animations; target and descendant styles refresh when it changes, while
the ordinary inherited environment remains independently replaceable beneath
the overlay.
Module-preload links now run the translated graph-fetch algorithm with their
typed script-like, style, JSON, or text destination and preserve nonce,
integrity, CORS credentials, referrer policy, parser metadata, and fetch
priority. Successful JavaScript roots start descendant fetching and all module
types populate the reusable module map; failures remove the in-progress entry
so a later import can retry. Media mismatches suppress both fetches and events,
while speculative parser requests preserve the same options but deliberately
leave the module map untouched so intervening CSP metadata remains effective.
Module maps now use the `javascript-or-wasm` type key and store all completion
callbacks in each in-progress entry. Fetch completion atomically installs the
module or removes a failure before notifying every waiter, including when an
implementation fetch hook aborts without a response. Text synthetic modules
expose their decoded source through their sole `default` export.
Dedicated worker termination now invalidates queued and already-scheduled
outside-port deliveries, closes the implicit port, discards the translated
worker event loop, releases its startup keepalive, and removes the owning
`PageClient` worker-agent record. Repeated worker creation and termination no
longer leaves live worker processes or IPC-equivalent state behind.
Meta `color-scheme` discovery now carries the `only` modifier separately from
the supported scheme list. Changing either value advances the document style
environment and schedules media-query and full-style reevaluation, preserving
the opt-out signal consumed by force-dark painting. Full-document parsing
refreshes this metadata after tree construction, so an initial declaration is
available to the first style and force-dark decision. The compact script bridge
also exposes `document.head`, reflects meta `name` and `content` properties, and
refreshes supported schemes after replaying live DOM mutations. A dynamically
inserted `only light` declaration therefore invalidates cached dark paint while
leaving the force-dark page setting intact.
Force-dark display-list resolution now assigns the upstream color roles to
backgrounds, text and shadows, borders, selections, SVG, gradients, markers,
form controls, scrollbars, and resizers. Border and selection resolution sees
the authored backdrop, while automatic focus rings and inspector/debug
overlays remain unchanged. The navigable's thresholds and page opt-out are
applied after recording and before retained commands reach native replay.
Decoded raster replay samples at most roughly one thousand pixels for the
translated palette, luminance, saturation, transparency, and chroma classifier.
Eligible icon and separator frames are cached after per-pixel Oklab inversion;
the CSS-size gate and classifier leave large or photographic images unchanged.
Line-box debugging now records each text fragment's green bounds and red
baseline immediately before its glyphs. The commands remain in the retained
paint cache for inexpensive toggling, are omitted from ordinary display lists,
and carry the explicit no-force-dark role when exposed.
Inline layout now publishes conservative glyph-run painted bounds in CSS pixels
when it finalizes each retained run. Merging, ellipsis, and line clamping dirty
the packed replay data and bounds together; finalization refreshes both once.
Display-list recording scales and positions the cached bounds with ties-to-even
rounding and retains the fragment rectangle separately, so damage and culling
use glyph ink without recomputing font bounds during every recording pass.
Overflow wrapping now follows the upstream shaped-text path.
`overflow-wrap:anywhere`, `overflow-wrap:break-word`, and legacy
`word-break:break-word` split only at extended grapheme boundaries, preserve
UTF-16 offsets and font/edge state across the resulting fragments, and continue
through changing float-intrusion bands. `anywhere` and the legacy value affect
min-content sizing, while `break-word` only supplies emergency breaks at a
definite line width. The textarea UA rule was already current, and the hot path
returns before segmenting text that fits. The four upstream overflow-wrap
reftests are pixel-exact, and the layout corpus gains the float and textarea
cases without regressions. Preserved trailing spaces and tabs now provide the
upstream soft wrap opportunity for following text; the V path distinguishes
them from collapsed whitespace so existing float-band placement stays stable.
An overflowing line now ignores `text-align` and stays aligned to inline-start;
RTL content wider than its block consequently extends to the left, matching the
upstream scrollable-overflow geometry.
Locale-sensitive casing now carries an element's inherited language into the
Unicode case mapper. A live `lang` mutation invalidates cached rendered text and
marks casing-transformed text for layout, so Turkish dotted-I changes appear in
the same update. The CSS/Layout font boundary also reuses last-resort handles
that resolve to the same concrete face, matching upstream fragment identity.
Table width resolution now retains whether `fit-content` had an argument. The
keyword form clamps against the available inline size, while explicit zero
length and percentage arguments clamp to min-content; intrinsic min/max width
constraints also clear the principal table's stale generic-block end margin.
Text shaping now applies computed `word-spacing` to spaces, no-break spaces,
and collapsed line feeds. The exact shaped advance of trailing ASCII whitespace
is retained through fragment merging and intrinsic shape reuse, so line-end
trimming subtracts precisely what shaping added, including text spacing.
Each inline formatting context is also classified before chunk generation.
Provably LTR paragraphs keep neutral punctuation in LTR shaping runs, preserving
contextual positioning and kerning across apostrophes and hyphens, while RTL,
mixed-direction, and `unicode-bidi` content retains per-code-point direction
resolution. This matches the updated `div_align.html` snapshot.
Unicode default-ignorable controls remain in shaped glyph records for UTF-16
bookkeeping but receive zero advance and are omitted from bounds, intercepts,
and retained paint buffers. Non-painting fallback-font fragments no longer
force raw-string replay, and the upstream input-placeholder reftest is exact.
HarfBuzz font scaling now clamps in double precision before conversion to the
library's 32-bit scale. Huge CSS font sizes no longer overflow during intrinsic
text measurement, and saturated cache entries remain separated by point size.
Text shaping now shares the upstream cache boundary across width-only and full
glyph-run consumers. Cached glyphs remain origin-relative and font-independent,
spacing keys compare their exact bit patterns, common single-ASCII shapes use
the dedicated fast path, and the upstream 64-font/16,384-text LRU limits are
enforced without allowing callers to mutate retained cache entries.
Font-face matching now keeps URL sources lazy while a cascade is merely probed
and starts a request only when shaping selects a pending face that covers the
code point. The `font-display` block, swap, and failure periods implement the
`auto`, `block`, `swap`, `fallback`, and `optional` timelines; invisible fallback
retains its ordinary metrics, only the selected pending face is resolved, and
deadline transitions invalidate the owning font computer.
Pending cache/decode font work can defer the document's first paint without
holding later rendering for a network request. The document font computer owns
that decision and exposes the completed/pending result through Internals.
Font-computer invalidation also advances an environment generation. Canvas and
offscreen-canvas drawing state retain the computed cascade behind the `font`
shorthand and refresh it when that generation changes, including cascades saved
and later restored around a font load.
Decoded bitmap transport now identifies row orientation independently from
alpha representation. FFmpeg video and video-backed canvas snapshots stay in
their native top-down order, while the existing Quartz-ordered image path keeps
its one native replay flip.
CSSOM `CaretPosition` and `Document.caretPositionFromPoint()` now consume the
retained text-fragment hit-test offsets, expose a transformed one-pixel client
rectangle, reject points outside the viewport, and retarget positions through
shadow hosts unless the caller explicitly exposes the corresponding shadow
root.
Custom-element state sets now feed the translated selector matcher, so
`:state()` participates in direct selector matching and DOM queries while set
mutation continues to invalidate style.
Cross-parent `moveBefore()` operations now invalidate cached inherited language
through the complete shadow-including moved subtree. The existing subtree
recascade then observes both the refreshed language and V's live parent-derived
directionality, so `:lang()`, `:dir()`, and inherited computed styles follow the
new parent without adding needless invalidation for same-parent reordering.
Slot removal now retains the exact descendant-slot list while unregistering a
subtree from its former shadow root. Each removed slot is reassigned directly,
so nested slots clear their assigned-node lists and light-tree nodes drop stale
`assignedSlot` links after either removal or `moveBefore()`.
Direct CSSOM `StyleSheetList` insertion now keeps an untitled alternate sheet
disabled instead of accidentally matching the initially empty preferred-set
name. Persistent untitled sheets and named alternates selected by a
case-insensitive preferred-set match retain their existing behavior.
Platform input-method sessions now expose the complete composition contract to
page script. `compositionstart` precedes each `compositionupdate` and its
non-cancelable `insertCompositionText` `beforeinput`/`input` pair, with
`compositionend` after the final update. Input, textarea, and contenteditable
paths preserve marked-range replacement, selected starting text, replacement
commits, cancellation, unmarking, event data, and `isComposing`; the V editing
bridge refreshes the marked node after rebuilding contenteditable markup.
Media resource selection now distinguishes automatic selection from an explicit
`load()` call. Paused `preload="none"` media continues to wait and emits
`suspend` during automatic selection, while `load()` starts the fetch; changing
preload/autoplay or calling `play()` resumes a deferred fetch. The explicit
selection marker survives resumption after document adoption and is cleared
before the next automatic selection.
The `:indeterminate`, `:open`, and `:closed` selectors now read live checkbox,
input-picker, and select-picker state. Control transitions mirror that state at
the DOM boundary and schedule style invalidation; `switch` checkboxes retain
the current upstream exclusion from `:indeterminate`.
Rich clipboard HTML is now parsed as an inert contextual fragment before use.
The translated sanitizer removes active elements, event handlers, `srcdoc`,
and JavaScript URL attributes while preserving ordinary markup, inline styles,
and safe relative, network, and data URLs.
Plain-text clipboard serialization now follows rendered structure: it omits
hidden, unpainted, and `user-select:none` text; emits paragraph, explicit-break,
table-cell, and table-row separators; includes rendered image alternative text;
and slices text at UTF-16 range boundaries. Navigable copy and cut selection
text use this shared serializer.
Rich clipboard serialization now clones the selected rendered tree, preserving
`display:contents` and inline markup while omitting hidden subtrees and clipped
transport-only wrappers. Partial text selections retain exact UTF-16 endpoints,
and navigables expose the resulting HTML alongside their plain selected text.
The interchange-whitespace translator now classifies ASCII-whitespace text and
rebalances collapsible space/newline runs into ordinary-text and protected-space
tokens. Rich clipboard serialization applies those tokens as span-wrapped
non-breaking spaces while retaining verbatim text whose computed
`white-space-collapse` mode is non-collapsing.
When a cloned fragment contains only sibling list items, rich clipboard
serialization now restores their shared `ol` or `ul` ancestor, including its
authored attributes.
Empty selected list items at fragment edges are now encoded as
`Apple-interchange-newline` markers inside the following item or after the
list, preserving their rendered paragraph boundaries for rich paste.
Partial selections inside one text node now materialize computed color,
background, font, and text-decoration differences from the editing host on a
clipboard span, retaining formatting that range cloning alone cannot carry.
Legacy single-`font` runs can now be removed or converted to inline color
spans, including quirks-mode legacy color parsing and preservation of text-run
seams. Rich clipboard serialization uses the rendered source color and keeps
protected whitespace runs independently styled.
Replacement fragments now consume rich-clipboard transport markup: they remove
top-level formatting whitespace and trailing interchange markers, retain a
leading marker as structural state, unwrap protected-space spans, prune empty
inline staging wrappers, protect external edge whitespace, and classify text-
only and block-containing fragments before insertion.
Inserted-fragment tracking now retains its connected top-level nodes, nested
text nodes, first and last structural extent, leading text shape, and terminal
atomic content while replacement preparation moves or substitutes nodes.
Independent mutation-tracked ranges now own replacement start and end points.
Their endpoints follow ordinary DOM mutation and explicitly relocate across
left-to-right and right-to-left text-node merges without range-order coupling.
Inserted-content tracking now combines structural nodes, the mutation-adjusted
destination seam, replacement topology, semantic content endpoints, terminal
atomic content, paragraph-integration state, and whitespace context throughout
fragment insertion and completion.
Editing DOM moves now preserve the active selection and internal mutation-
tracked ranges using Ladybird's boundary relocation rules. Wrapper removal uses
the same path, retaining selection and replacement seams while children are
hoisted into their parent.
Paragraph-boundary splitting now exposes text positions outside text nodes,
clones inline ancestor chains around interior boundaries, avoids empty clones at
wrapper edges, and moves the paragraph suffix into a shallow block clone.
Inline insertion preparation now advances equivalent trailing-edge caret
positions, identifies the highest modifiable destination style, splits that
inline chain for independent pasted styling, and defers list destinations to
the dedicated list-item path.
Paragraph transfer now moves or unwraps source paragraph children at a mutation-
tracked destination, applies explicit legacy-font style policy, removes the
source wrapper, and optionally coalesces the destination text seam while
returning the semantic moved range.
Visible editing positions now retain distinct script-visible and canonical
caret boundaries, delegate movement and extension canonicalization to the
translated caret navigator, scan rendered text and paragraph breaks, and
distinguish true block edges from carets beside atomic inline layout boxes.
Caret navigation now discovers text and atomic hosts from retained layout,
uses rendered line ownership for cross-node equivalence, recognizes empty-line
breaks from their containing block, and no longer joins caret positions across
separate block lines merely because they share an editing host.
Paragraph integration now decides both inserted seams from rendered visible
positions before mutation, respecting original paragraph-aligned selections,
list and table-cell context, heading compatibility, blockquotes, atomic caret
anchors, and empty transport paragraphs.
Replacement-range completion now coalesces both text seams while relocating
semantic endpoints, normalizes only interior protected clipboard spaces,
repairs integrated-paragraph whitespace, removes empty modifiable wrappers,
and preserves terminal atomic and empty-container caret boundaries.
Replacement-style cleanup now compares the destination cascade with and without
each inserted inline declaration, removes redundant longhands while preserving
custom properties, and unwraps empty style-only spans without disturbing live
selection or replacement ranges.
Block replacement planning now chooses split, after-block, internal-paragraph,
list-item, and empty-block insertion paths from rendered caret boundaries, and
integrates a pasted list into a matching destination list without losing the
tracked inserted extent.
Trailing interchange newlines now advance replacement carets into the retained
destination suffix, preserve genuine empty terminal paragraphs, and materialize
or enter the correct following list item at list boundaries.
DOM insertion seams now canonicalize collapsible and protected spaces across
inline wrappers, stop at atomic clipboard content, and leave preserved
white-space runs untouched.
Collapsed inline selection replacement now inserts prepared fragments through a
mutation-tracked range, splits destination formatting chains, removes redundant
transport styles and empty block props, normalizes both whitespace/text seams,
and collapses the live selection at the semantic inserted endpoint.
Collapsed block selection replacement now executes the planned split, after-
block, internal-paragraph, list-item, and empty-block paths; integrates matching
lists and eligible paragraph seams; preserves destination suffix whitespace and
trailing breaks; and finalizes the live caret through the shared cleanup path.
Inline replacement now validates every pasted descendant against its live HTML
ancestors after insertion. It applies the complete editing allowed-child table,
splits illegal inline, paragraph, anchor, and heading wrappers while preserving
ranges, wraps orphan definition items, and converts otherwise orphaned
paragraph-prohibited elements to the document's default single-line container.
Reversible edit commands now cover node insertion/removal, UTF-16 character-
data replacement, text splitting, attribute changes, fragment expansion, and
range insertion. Undo and redo replay the original nodes only after validating
the live DOM and refuse script-invalidated mutations atomically.
Document editing history now records those proxy mutations as user-level undo
steps, captures and restores directed selections, coalesces compatible typing
and deletion runs, prunes detached editing hosts, and atomically drops steps
invalidated by later script mutations. User history actions dispatch trusted,
cancelable `beforeinput` and follow successful replay with `input`; raw DOM
mutation during an active recording is diagnosed through a cycle-free DOM hook.
Text inputs and textareas now enter that same history through the DOM/HTML
interface boundary. Their value replacements retain UTF-16 offsets, synchronize
the control model and shadow text during replay, restore the control's directed
selection, coalesce typing and directional deletion runs, and keep paste as a
separate undo unit.
`execCommand()` and the `queryCommand*()` methods now run the translated
Commands and Internal/Algorithms steps directly on the live DOM instead of a
serialized host model. Commands mutate through the recording proxies, read
state and values from resolved style, record command-specific history
categories, and route `execCommand("undo")` and `execCommand("redo")` to the
shared history. The paste pipeline records through the same proxies, so pasted
content is undone as one step.
Rich copy now serializes through the translated styled-markup selection,
accumulator, and serializer, which derive interchange-newline boundaries from
visible positions and flatten lone transport wrappers. The caret navigator
follows the current upstream editing canonicalization, adjacent-host, word, and
editing-host boundary rules; line and page movement still wait for a painting
hit-test display list.
Case-insensitive command-enabled queries now reflect the actual undo and redo
stack state, including histories created by form controls.
The Page bridge now exposes navigable undo and redo entry points, recognizes
the platform undo/redo keyboard shortcuts, and forwards editing-history stack
state to `PageClient` so browser chrome can keep menu availability current.
Live document-selection range mutations and form-control caret navigation now
close an open typing unit, while selection changes made by the edit being
recorded or by history replay remain coalesced.
Contenteditable user edits now carry their UI input type through the live
command bridge. Cut takes the backward-delete path, cut and paste remain
standalone history units, and their trusted input events report
`deleteByCut`/`insertFromPaste` with the corresponding nullable data.
Clipboard insertion now crosses the active input-target boundary. Rich editing
hosts prefer sanitized HTML and execute it as one undoable `insertHTML` edit,
while `plaintext-only` hosts and form controls insert the normalized plain-text
representation; Page forwards both representations after `beforeinput`.
Select-all now follows the active input-events target before falling back to
the document body. Focused text controls select their complete value,
contenteditable hosts use rendered document-boundary navigation, and the Page
keyboard path recognizes the platform Ctrl/Cmd+A shortcut.
The common input-events target now also owns keyboard insertion, return-key
handling, and caret navigation. Page routes character/deletion keys and
character, word, rendered-line, page, Home/End, Shift-extension, and macOS
document-boundary movement to the focused form control or contenteditable host;
textarea returns insert line breaks while input returns preserve form action.
The platform Ctrl/Cmd+C, X, and V key combinations now enter the shared copy,
cut, and asynchronous paste actions, preserving their clipboard event,
representation filtering, newline normalization, and completion behavior.
System clipboard representations now retain whether their payload is raw bytes
or a user-selected file. Script-facing `read()` and `readText()` omit the
file-backed entries, while an explicit trusted paste turns raw PNG bytes and
selected image files into file items, generates a data-URL image, and sends it
through the same sanitized rich-editing insertion path.
Mouse-driven editing selection now also crosses the common input-target
boundary. Contenteditable constrains dragging to its active host, controls use
their shadow text node, and anchor/focus updates retain hit-test affinity while
keeping the control's selection model synchronized.

The refreshed current-tree semantic inventory reports 4,175 unmatched C++
spellings. That is a structural review queue rather than a count of missing behaviors: active V
implementations often consolidate C++ class hierarchies and overloads under a
single typed path. Empty/default-return implementations are checked separately,
and the refreshed audit has no suspicious trivial bodies awaiting review.

The current Layout refresh also follows shadow hosts while locating a positioned
inline containing block. Absolutely positioned shadow-tree descendants therefore
use their inline host instead of falling back to the viewport.
Inline containing-block rectangles are translated to the outer positioned box
through containing blocks rather than layout-tree parents, so internal table
row and row-group offsets are not counted twice for inline hosts inside cells.
Atomic inline used offsets are copied from fragments after final line alignment;
absolute-position static-position conversion therefore includes the atomic
inline's completed baseline and text-alignment shift.
CSS Scroll Snap now uses the translated candidate collection and selection
algorithms for element and viewport scrollers. It resolves physical and logical
axes, scroll margin and padding, oversized covering ranges, proximity and
mandatory strictness, directional `scroll-snap-stop: always`, and cross-axis
visibility. Snapped areas survive layout-tree replacement and are reselected
after relayout, including viewport scrollers and focused or targeted-area
preference. Containers without a previous selection also snap after initial
layout. Momentum-fling displacement estimation follows the compositor's rounded
geometric-decay calculation.
Flex and inline-flex fieldsets retain their special legend layout while applying
flex direction, wrapping, alignment, and gaps to the anonymous content box. The
wrapper is also created for flex fieldsets without a rendered legend.
Fieldsets with a flow inner display lay out as flow-root, and inline fieldsets
as inline-block, while their computed display is unchanged; an inline
fieldset therefore joins its parent's line as one atomic inline.
Line boxes derive their exported baseline from the final placement of the first
unshifted text fragment instead of retaining only the pre-alignment font strut.
Lines without such text keep the alignment-baseline fallback, including the
far-edge block offset used by reversed writing modes.
List items that establish an independent formatting context lay out their own
markers, outside markers align with the list item's first baseline, and the
marker line height floors only automatic list item heights. Marker symbols,
suffixes, list-style images, and authored `::marker` content now flow through
generated inline children of the marker box. Their own run discards a stale
zero-width intrinsic probe before measuring that content, including for floated
list items containing shrink-to-fit inline fieldsets. Inside markers participate in the
principal inline run, including through a trailing anonymous wrapper after
block content, and use the bundled layout-test symbol face. Live box-presence
changes now rebuild layout; a hidden list item drops its box and invalidates
cached ordinals so subsequent markers renumber. A hidden document element
leaves an empty viewport that still reports its root block formatting context. A single
authored generated image becomes the originating element or pseudo-element's
replacement box before quote controls resolve; list-item and display-contents
pseudos retain inline image children instead. Empty generated strings create a
text node only inside ordinary inline pseudo-elements. Quote controls that
resolve to no text under `quotes: none` remain represented in the layout tree
without being mistaken for authored empty strings: they contribute no line
fragment and retain zero geometry at the containing block origin.
Viewport propagation now copies the root scrollbar width and the containment-
aware principal writing mode and direction, while selecting and neutralizing
the correct root/body overflow origin.
The contain-intrinsic physical and logical longhands now parse and compute
non-negative lengths, preserve the optional `auto` state, and expand and
serialize the two-axis shorthand with the current upstream grammar.
Size-contained boxes now substitute those explicit physical inner dimensions
for content-derived automatic sizes across block and independent formatting
contexts, including inline blocks in vertical writing modes.
The multi-column rule longhands and shorthand now parse in any component order,
compute rule widths independently of the rule style, resolve `currentcolor`, and
round-trip through CSS declaration serialization.
The fragmentation break-before, break-after, and break-inside properties now
accept their complete CSS Break keyword grammars and retain typed computed
values for future pagination and multicolumn layout consumers.
Box decoration breaks and multicolumn fills now accept their complete keyword
grammars and retain typed computed values for future layout and painting
consumers.
The legacy page-break-before, page-break-after, and page-break-inside
shorthands now map their restricted grammars to the modern break longhands and
follow the upstream CSSOM serialization rules, including unresolved values.
The standard and legacy line-clamp shorthands now expand and serialize their
max-lines, block-ellipsis, and continue longhands with the upstream grammars.
Legacy vertical WebKit boxes retain their authored display while computing to
an independent flow-root or inline-block when clamping is active.
Layout now establishes those line-clamp containers, counts descendant in-flow
line boxes across block children, suppresses later in-flow content, and paints
automatic, omitted, custom, and inherited block ellipses. Ellipsis placement
uses retained soft-wrap boundaries with glyph-boundary fallback and bidi-aware
placement; scrollable overflow, DOM visual-line projection, and the typed paint
adapter exclude clamped fragments. The legacy horizontal WebKit-box path uses
its effective row flex direction. The upstream `line-clamp-properties` input
and reference render with an exact zero-pixel difference in the native V app.
Synthetic ellipses retain Ladybird's boundary text-node ownership and UTF-16
offsets. The paint bridge joins compatible retained glyph runs without
reshaping, while unsupported glyphs take the same native fallback path as
literal mixed-font text.
CSS scroll margins now implement all physical and logical longhands plus the
four-side, block-axis, and inline-axis shorthands. Signed lengths and calculated
lengths compute through the normal logical-property mapping, and scroll-into-view
expands the target border box by the resolved physical margins.
CSS scroll padding now implements all physical and logical longhands plus the
four-side, block-axis, and inline-axis shorthands. Non-negative lengths,
percentages, `auto`, and calculated values compute through the normal logical-
property mapping. Scroll-into-view resolves percentages against the corresponding
scrollport dimension and applies the root scrolling element's padding to viewport
alignment.
The scroll-snap-align, scroll-snap-stop, and scroll-snap-type grammars now
parse and retain typed computed values. Alignment pairs use shortest-value
serialization, scroll-snap-type normalizes its default `proximity` strictness,
and the computed layer exposes physical axis, alignment, stop, and strictness
enums for scrolling and painting consumers.
SVG filters now compute and inherit `color-interpolation-filters`, track the
operating color space of each graph result, insert only the required sRGB and
linear-light conversions, and preserve the special color-space behavior of
flood, image, offset, displacement-map, turbulence, and final filter output.
The native filter bridge applies those conversions, runs component-transfer
tables directly in the selected space, clamps arithmetic output to
premultiplied alpha, and renders turbulence through upstream's Skia Perlin
shader. Turbulence replay forwards scaled, half-away-from-zero-rounded stitch
tile dimensions and rasterizes the retained filter target rather than the
browser's full canvas, keeping deterministic noise independent of chrome
offsets. The turbulence and fractal-noise canonical screenshots are exact
zero-pixel matches.
Decoded `feImage` resources now retain their absolute URL in the graph, preload
through the browser image cache, and attach the decoded frame during native
replay. The same filter boundaries are retained inside SVG pattern tiles, and
the compact script bridge exposes completed images and late `load` listeners so
visibility changes do not strand a cached pre-load tile. The three new
`feImage` reference cases are exact zero-pixel matches.
The same script bridge now round-trips the reflected `src` property and
`setAttribute("src", ...)` for image elements into the live DOM. Synchronously
decoded replacements enter the translated HTML image update boundary and
explicitly invalidate layout plus retained paint input, so an intrinsic-size
replacement with unchanged dimensions still repaints. The upstream
`svg-image-source-switch-same-size` reference pair is pixel-identical.
Document ID-map additions, removals, and changes now invalidate published SVG
paint resources like upstream, so a previously shadowed gradient or pattern is
resolved after an HTML/SVG ID collision changes. The compact browser bridge
tracks elements independently of their mutable or duplicate IDs, preserves
SVG attribute case and namespaces, creates SVG children, replays
`moveBefore()`, and commits the retained final keyframe used by completed paint
animations. The nine new gradient, pattern, and ID-collision mutation reftests
are exact zero-pixel matches.
Ladybird's new color-matrix reftest is an exact zero-pixel match; its displacement
and turbulence mismatch references both differ. The comparison driver now
follows both `rel="match"` and `rel="mismatch"` references.

Incremental HTML parsing now retains undecoded encoding-sensitive bytes while
scripts are not yet permitted to run or the tokenizer is paused on a
parser-blocking script. Encoding confidence, late meta-charset processing,
on-the-fly decoder replacement, parser-resume notification, and implied-EOF
draining follow the current upstream parser. Focused streaming tests cover both
the initial deferred-start path and the parser-blocking-script regression with
a late Windows-1252 declaration.

SVG and MathML computed display now follows CSS Display's unboxing rules.
`display: contents` computes to `none` for an outermost SVG that participates
in CSS box layout, for SVG elements outside the allowed container/text-child
set, and for every MathML element. The allowed nested SVG elements continue to
hoist their contents, and an SVG nested through `foreignObject` correctly
starts a new outermost-SVG boundary. Focused tests mirror upstream's complete
13-element SVG computed-display matrix and also cover MathML and the
`foreignObject` position boundary.

The compact document bridge now preserves namespaces and case-sensitive local
names when replaying `document.createElementNS()` and attributes on
script-created SVG content. Layout construction exits SVG rendering context at
`foreignObject`, skips SVG graphics in its HTML subtree, and re-enters only at
a nested SVG root. The upstream
`svg/foreignObject-with-svg-namespace-child.html` corpus case now matches
exactly.

SVG viewport boxes now append their SVG content directly even when the outer
SVG is block-level. Whitespace text and `foreignObject` siblings no longer gain
anonymous HTML block wrappers, matching both upstream absolute-positioned
`foreignObject` corpus cases. Their inline-child state now follows the upstream
insertion rule as well: an in-flow block `foreignObject` clears a block SVG
viewport's flag, while remaining an interrupting block in an inline SVG
viewport. This also matches `svg/foreignObject-with-mask.html` without changing
the default inline SVG cases.

Attached SVG mask, clip, and pattern layout subtrees now keep the active SVG
formatting context as their coordinate containing block. A resource referenced
from a translated `foreignObject` therefore starts at its own `(0, 0)` origin,
and its SVG descendants no longer inherit the host's translation.

Resolved SVG `foreignObject` geometry supplies definite available space to its
independent formatting context without becoming a definite CSS percentage
basis. Percentage-height HTML descendants therefore remain automatic, matching
the upstream viewBox geometry corpus case.

The compact script bridge now replays `Element.remove()` through the DOM removal
algorithm. Removing a referenced SVG mask consequently marks its registered
referencer for layout-tree rebuilding and drops the synthetic resource box,
matching the upstream resource-removal corpus case.

Inline declarations on UA-shadow elements associated with host pseudo-elements
now resolve logical aliases against the inherited pseudo-element writing mode
and direction before entering the physical computed-property table. A
placeholder added by script after the input's first layout therefore retains
its negative inline-start overlay margin, and the upstream
`input-placeholder.html` corpus case now matches exactly.

Fallback number-input stepper buttons now seed their SVG `d` computed property
from the same path data used to construct the internal icon element. SVG layout
therefore retains the up/down path bounds, matching both the upstream
`input-number-placeholder.html` and `number-input-appearance.html` corpus cases.

Anonymous whitespace-only flex children, including an empty button's generated
content box, are now skipped before used values are created. Debug output keeps
the skipped box's inline-block identity without inventing geometry. This matches
the explicit `LayoutState` lifecycle and fixes the two empty-button snapshots,
`flex-baseline-alignment.html`, and
`flex/box-baseline-with-inline-flex-empty-child.html`.

Inline-grid formatting no longer materializes used values for anonymous
whitespace runs that grid placement skipped. They remain present in the layout
tree but unpainted, matching `grid/fit-content-3.html`.

GIF image loading now follows upstream's tolerant LZW behavior: a stream that
ends without an explicit end-of-information code keeps the successfully decoded
frame and its natural dimensions. The one-pixel data GIF in
`table-replaced-child-percentage-height-in-auto-table.html` therefore supplies
the table's intrinsic width and height instead of collapsing the table to zero.

Collapsed-table intrinsic probes now replay the cached grid's winning borders
into each throwaway layout state. Anonymous wrapper intrinsic widths retain the
table-owned outer shares, percentage border-box widths subtract those split
shares, and the wrapper's exported row baselines follow the final collapsed-
border content-origin rebase. This matches
`table/width-distribution-of-max-width-increment.html` and
`table/border-collapse-is-inherited.html` while preserving the separate-border
absolute-positioned, nested, and max-content table cases.

Pseudo-elements generated by the document element no longer receive root-only
box transformations. In particular, `html::first-letter` remains inline and
resolves `em` lengths against the originating root's computed font metrics.
The native browser bridge now replays live `Selection.selectAllChildren()`,
`getRangeAt()`, and `Range.surroundContents()` mutations through the translated
DOM implementation; upstream's `first-letter-of-html-root-refcrash` reftest is
an exact zero-pixel match.

HTML image `x` and `y` geometry queries now resolve accumulated paint and
hit-testing state only after finding committed layout geometry. Images without
a box return zero before that work, avoiding stale paint-property resolution
for disconnected and non-rendered elements. Focused tests observe both the
committed-box resolution path and the no-box early return.

The inherited `-webkit-font-smoothing` property now accepts all four upstream
keywords and propagates through ordinary glyph runs, text shadows, and
`background-clip: text` masks. The macOS native renderer maps those modes to
Skia and CoreGraphics font rasterization settings, including Blink-compatible
non-dilated outlines for `antialiased`; direct screenshots verify that the
rasterization mode changes pixels.

The browser script bridge now preserves explicit `Range` boundary points,
replays `removeAllRanges()` and successive selection moves in order, moves
existing nodes through `insertBefore()`, and applies CSSOM rule declaration
changes before style computation. The three upstream live-selection reftests
now match exactly, including insertion between unchanged boundaries and moving
a highlight between subtrees after its `::selection` rule changes.

Range client rectangles now include selected retained text fragments and map
each fragment through its containing block's accumulated visual context.
Element client rectangles use the same viewport transform boundary, so their
geometry agrees under CSS transforms and both reflect live ancestor scrolling.

Empty editable blocks, paragraphs, and inline elements now derive caret height
from the selected font's ascent plus descent, cap it at the computed line
height, and center it in the line's extra leading. The compact browser bridge
replays `Selection.collapse()` at element and text boundaries, so the upstream
`empty-caret-with-placeholder` reference pair paints real carets and matches
with an exact zero-pixel diff.

Selections left on a parent's child boundary now derive their caret rectangle
from the adjacent retained text fragment, preferring the previous text child's
end before the next text child's start. This preserves identical LTR, RTL, and
vertical geometry between parent and text-node offsets. The compact browser
attaches a focused HTML navigable before display-list recording, and the visible
`caret-after-first-character` reference pair matches with an exact zero-pixel
diff.

Dashed CSS calls now resolve and evaluate active `@function` definitions during
arbitrary substitution. The translated evaluator carries parameter and result
registrations through function-local scopes, applies defaults and typed syntax,
resolves local declarations and inheritance, caches resolved local properties,
and preserves CSS-wide result-keyword behavior. Shared guarded substitution
contexts now mark the complete cycle and include function identity in property
dependencies. Arguments substitute before missing/excess arity rejection, and
custom properties retain function-registry access when a normal property later
depends on them. Focused tests mirror the five new upstream regressions for
cycle fallback, context identity, evaluation order, result keywords, and
registry dependency.

CSS backface visibility now parses, computes, inherits, serializes, and
interpolates through the typed property pipeline. The transform implementation
retains full 4x4 matrices, builds explicit and synthetic 3D planes, bounds
backface tests at their plane roots, and resets ancestor culling when a
descendant enters its own 3D sorting plane. Painting and hit testing share that
culling decision. The browser animation loop refreshes retained paint-only
transform state after load-handler and `requestAnimationFrame` mutations. The
expanded backface comparison set passes 25/25 cases: 23 are exact and two stay
within the comparison workflow's checked tolerances.

The earlier inventory mapped every upstream implementation filename to V code,
but filename and symbol-name coverage did not establish behavioral parity. A
semantic re-audit found name-only `upstream_*entry_points.v` coverage-shim
files. Every such file has now been compared with the corresponding upstream
bodies, rewritten where necessary, and promoted under an implementation name;
the current audit has no quarantined coverage files. The remaining `Present`
modules still have upstream bodies that require the same behavioral audit.

A 2026-09-26 triage of the 285 trivial-bodied V functions against upstream
found 230 faithful, 28 V-only helpers (25 adapters, 3 placeholders), and 27 real
divergences.
Those translated since: bare `safe`/`unsafe` alignment keywords, canvas repaint
requests, navigator languages, queued media source and element tasks,
traversal initiator sandboxing, theme color resolution, layout tree teardown,
time-origin-relative DOM timestamps, external software hand-off, navigation
start times for new browsing contexts and navigated documents, hyperlink
activation and following through the navigable, form and interactive element
activation behavior from event dispatch, the navigators' ID, language, online,
and hardware mixins, media devices bound to their window's document, navigation
referrer policies from hyperlinks, per-element focusable areas with their
rendering requirement and image maps, request policy containers, and style
elements that create their sheets in the style scope's style sheet list with
the parser handshake and script-blocking state. Hyperlink downloads now fire
their cancellable Navigation API event, honor sandboxing, fetch with the
download initiator and URL credentials, apply the upstream Content-Disposition
and same-origin filename precedence, sanitize the result, and stream response
bodies through the owning PageClient. Navigation responses with an attachment
disposition now take that download path without installing a document or
history entry, enforce both source and target sandboxing, and retain request-
server identity for direct PageClient handoff. Still open:

- The browser shell dispatches clicks through its JavaScript mirror and follows
  links itself instead of the page event handler's click and activation path.
- `<link rel=stylesheet>` sheets are read from local files by a layout-time
  CSS bridge, and the shell inlines remote ones as style elements, instead of
  `HTMLLinkElement` fetching and processing them; the shell installs no fetch
  host, so the fetch module has no resource loader behind it.
- The compositor keeps its own visual context tree instead of
  `AccumulatedVisualContextTree` spatial transforms and sticky offsets.
- The WebGL module is not connected to `<canvas>` or the DOM event model.
- IndexedDB is a synchronous model without connection queues or task-driven
  request processing.
- Stream transfer and ML-KEM remain untranslated.

`Complete` means every upstream `.cpp` unit has an audited V implementation
mapping. `Present` means translated module code exists but its full upstream
coverage has not yet been audited. `Untranslated` means no module translation
was found. The remaining module rows retain their earlier inventory status
until their own behavioral re-audits are performed.

LOC is physical line count (`wc -l`), including comments and blank lines.
Implementation and test V counts are disjoint. `Selection` includes its shared
`dom/selection.v` implementation, and `UIEvents` includes its shared
`dom/ui_events.v` implementation. Root support and non-LibWeb support modules
are documented separately in `ROOT_SUPPORT.md` and are not included below.
The upstream `Crypto` module maps to the `webcrypto/` V package so it can use
V's standard `crypto.*` modules without shadowing that namespace.
The IDL-only `Fullscreen` package delegates its state machine to the shared
translated DOM implementation.

The table below is the refreshed 2026-09-26 inventory. It covers 76 current
implementation-bearing upstream modules plus the translated IDL/IPC-only
`Fullscreen` and `Worker` packages, and all 1,193 module-owned `.cpp`
implementation units. Root-level LibWeb `.cpp` support units are mapped
separately in `ROOT_SUPPORT.md`. The removed upstream `PermissionsPolicy`
module's small compatibility package remains in the repository but is excluded
from the current-module totals.

| Upstream module | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ARIA` | 6 | 1,955 | 2,535 | 399 | Complete |
| `Animations` | 10 | 5,187 | 3,981 | 1,041 | Complete |
| `Bindings` | 11 | 2,501 | 2,679 | 918 | Complete |
| `CSS` | 215 | 47,722 | 103,997 | 8,755 | Present |
| `Clipboard` | 4 | 1,009 | 1,037 | 383 | Complete |
| `Compositor` | 6 | 1,687 | 2,403 | 361 | Complete |
| `Compression` | 2 | 348 | 424 | 138 | Complete |
| `ContentSecurityPolicy` | 37 | 4,725 | 2,740 | 427 | Complete |
| `CookieStore` | 2 | 850 | 859 | 434 | Complete |
| `CredentialManagement` | 6 | 382 | 418 | 301 | Complete |
| `Crypto` | 6 | 13,412 | 4,472 | 1,459 | Complete |
| `DOM` | 59 | 34,859 | 36,776 | 2,205 | Complete |
| `DOMURL` | 4 | 1,039 | 758 | 336 | Complete |
| `Editing` | 26 | 12,720 | 13,918 | 226 | Complete |
| `Encoding` | 6 | 769 | 705 | 244 | Complete |
| `EncryptedMediaExtensions` | 3 | 535 | 572 | 329 | Complete |
| `EntriesAPI` | 1 | 47 | 44 | 32 | Complete |
| `EventTiming` | 1 | 122 | 153 | 95 | Complete |
| `Fetch` | 33 | 8,493 | 5,193 | 1,365 | Complete |
| `FileAPI` | 6 | 1,357 | 1,018 | 499 | Complete |
| `Fullscreen` | 0 | 0 | 93 | 177 | Complete |
| `GPC` | 1 | 21 | 16 | 13 | Complete |
| `Gamepad` | 6 | 1,351 | 760 | 275 | Complete |
| `Geolocation` | 4 | 643 | 416 | 176 | Complete |
| `Geometry` | 8 | 2,078 | 2,062 | 1,008 | Complete |
| `HTML` | 286 | 83,853 | 58,131 | 15,244 | Complete |
| `HighResolutionTime` | 2 | 516 | 442 | 195 | Complete |
| `IndexedDB` | 19 | 6,991 | 5,211 | 1,086 | Complete |
| `Infra` | 3 | 385 | 207 | 63 | Complete |
| `Internals` | 7 | 2,583 | 861 | 231 | Complete |
| `IntersectionObserver` | 2 | 528 | 569 | 327 | Complete |
| `Layout` | 9 | 4,001 | 37,944 | 11,639 | Present |
| `Loader` | 6 | 1,291 | 1,921 | 664 | Complete |
| `MathML` | 6 | 369 | 411 | 97 | Complete |
| `MediaCapabilitiesAPI` | 1 | 345 | 676 | 117 | Complete |
| `MediaCapture` | 5 | 1,475 | 1,212 | 205 | Complete |
| `MediaSourceExtensions` | 13 | 4,094 | 361 | 110 | Complete |
| `MimeSniff` | 2 | 1,607 | 1,108 | 308 | Complete |
| `MixedContent` | 1 | 127 | 125 | 105 | Complete |
| `NavigationTiming` | 4 | 497 | 291 | 45 | Complete |
| `NotificationsAPI` | 1 | 301 | 290 | 68 | Complete |
| `Page` | 8 | 6,450 | 2,985 | 886 | Complete |
| `Painting` | 22 | 8,227 | 7,609 | 2,357 | Present |
| `PerformanceTimeline` | 5 | 476 | 447 | 130 | Complete |
| `PermissionsAPI` | 3 | 388 | 239 | 74 | Complete |
| `Platform` | 4 | 431 | 2,330 | 405 | Complete |
| `ReferrerPolicy` | 2 | 341 | 239 | 123 | Complete |
| `RequestIdleCallback` | 1 | 52 | 59 | 18 | Complete |
| `ResizeObserver` | 4 | 424 | 420 | 152 | Complete |
| `ResourceTiming` | 1 | 357 | 338 | 84 | Complete |
| `SRI` | 1 | 198 | 156 | 100 | Complete |
| `SVG` | 82 | 9,020 | 5,184 | 1,222 | Complete |
| `SecureContexts` | 1 | 76 | 59 | 13 | Complete |
| `Selection` | 3 | 1,470 | 1,479 | 332 | Present |
| `Serial` | 2 | 366 | 243 | 35 | Complete |
| `ServiceWorker` | 11 | 2,608 | 1,573 | 513 | Complete |
| `Speech` | 11 | 421 | 624 | 111 | Complete |
| `StorageAPI` | 6 | 433 | 444 | 235 | Complete |
| `Streams` | 22 | 8,789 | 6,290 | 1,972 | Complete |
| `TrustedTypes` | 7 | 1,175 | 756 | 185 | Complete |
| `UIEvents` | 12 | 1,871 | 1,359 | 378 | Complete |
| `URLPattern` | 1 | 223 | 1,632 | 214 | Complete |
| `UserTiming` | 2 | 160 | 119 | 35 | Complete |
| `ViewTransition` | 1 | 1,054 | 598 | 324 | Complete |
| `WebAssembly` | 7 | 3,441 | 2,065 | 702 | Complete |
| `WebAudio` | 47 | 8,256 | 2,649 | 444 | Complete |
| `WebDriver` | 16 | 5,321 | 3,451 | 638 | Complete |
| `WebGL` | 42 | 7,846 | 6,205 | 1,470 | Complete |
| `WebIDL` | 10 | 2,466 | 2,162 | 613 | Complete |
| `WebLocks` | 5 | 647 | 701 | 169 | Complete |
| `WebSockets` | 1 | 476 | 316 | 115 | Complete |
| `WebVTT` | 2 | 378 | 464 | 232 | Complete |
| `WebXR` | 6 | 492 | 312 | 90 | Complete |
| `Worker` | 0 | 0 | 81 | 33 | Complete |
| `XHR` | 7 | 1,855 | 1,131 | 343 | Complete |
| `XLink` | 1 | 16 | 13 | 10 | Complete |
| `XML` | 2 | 556 | 477 | 164 | Complete |
| `XPath` | 5 | 435 | 613 | 189 | Complete |
| **Total** | **1,193** | **329,970** | **353,611** | **67,210** | **74 complete, 4 present, 0 untranslated** |

## Verification

The semantic inventory exits nonzero while structural spellings still require
manual classification. Its current baseline is:

```text
$ python3 tools/libweb_translation_audit.py
upstream modules: 76
upstream .cpp files: 1193
upstream implementations: 21401
quarantined name-only coverage shims: 0 files / 0 functions
explicit semantic-divergence markers: 5
reviewed upstream-equivalent trivial implementations: 541
suspicious empty/default-return implementations: 0
  candidate-name-match: 14257
  unmatched: 4162
  language-constructor-or-destructor: 1383
  gc-or-binding-runtime: 655
  consolidated-name-match: 525
  namespace-template-specialization: 177
  language-operator: 124
  language-template-trait: 64
  value-record-field-match: 54

largest unmatched modules:

  1682 CSS
  1173 HTML
   590 DOM
   404 Painting
   313 Layout

$ v -old-compiler -enable-globals run tools/layout_corpus.v --all
Layout corpus: 1089 passed, 0 failed, 1089 total

$ v -old-compiler -enable-globals test .
Summary for all V _test.v files: 652 passed, 652 total.

$ Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
Ladybird V smoke check passed

$ ./compare_screenshots.sh <four-overflow-wrap-reftests>
4 passed, 4 total (all exact zero-pixel diffs)

$ ./compare_screenshots.sh <24-new-cases>
24 passed, 24 total

$ ./compare_screenshots.sh
11 passed, 11 total (including 3 live-selection, 2 caret, and the
default-ignorable-code-points reftest)
```

The two corpus cases whose checked-in upstream text dumps predate the current
Rust layout output use narrowly documented exact overrides under
`tools/layout_expected/`; the other 1,087 cases compare directly with upstream.
The function-delta audit classifies every changed definition since the March
baseline, including root support and the consolidated anchor/style-element
lifecycle hooks: 0 of 5,653 changed definitions remain unclassified. Its
remaining unmatched structural queue is confined to definitions classified as
added in the five large source/Rust-restructured modules; the audit leaves
those visible instead of accepting them through an old symbol-name match.

The Editing reconciliation accounts for all 432 current upstream
implementations. Its five primitive command subclasses are dispatched by V's
tagged `EditCommand`, inline undo-step getters use the corresponding typed
record fields, callback traversal returns the same tree-order list for direct
iteration, and C++'s owned-string-to-view helper has no V representation.
Editing therefore has no unmatched structural entries; each explicit mapping
fails open if its concrete V target disappears.

The 2026-09-08 default-body pass exhausted the suspicious-stub queue at that
checkpoint and then
closed the ten unmatched symbols outside CSS, Layout, and Painting. It added
document-owned animation-timeline updates, the observable constructed-sheet
adoption callbacks, and live SVG `use` shadow trees. Consequently every
remaining unmatched symbol at that checkpoint was contained in the three large
modules already under structural and differential audit. The refreshed
September source introduced and reorganized spellings and 18 new trivial-body
review candidates across many modules; the current structural count above is
not a claim that every one lacks behavior.

The Painting state pass then reduced that module from 230 to 146 unmatched
implementations without adding class-shaped facades. It tied `PaintableBox`
geometry, scroll/visual-context state, table metadata, and phase caches to the
live `UsedValues`, `BlockBox`, and `DocumentLayoutResult` records; mapped the
base `Paintable`, line-fragment, and viewport operations to their active
lowering and replay functions; and fixed the one behavioral discrepancy found
during comparison. Static grid items with a non-auto `z-index` are now treated
as positioned by the paint transport, while ordinary static boxes remain in
their normal paint group.

The next active-path pass reduced Painting from 146 to 142. It translated
`Paintable::scroll_ancestor_to_offset_into_view()` through the retained text
fragments and typed containing-block chain, so DOM selections and anonymous
text-control cursors scroll their nearest overflow ancestor or the viewport.
It also restored `SVGPathPaintable::hit_test()`'s raw path-bounds gate: stroke
inflation still contributes layout and paint bounds but cannot make the
inflated margin win `elementFromPoint()`.

`Paintable::box_type_agnostic_position()` now crosses the active DOM/Layout
bridge as well, reducing Painting from 142 to 141. Label activation updates
layout and uses that content-box origin plus the live viewport scroll offset to
recompute a cloned control click's `offsetX`/`offsetY`, as upstream requires.

The inspector-overlay pass then reduced Painting from 141 to 137. The earlier
broken-image branch reduced it to 136 and established the pending third provider
state: image and image-input requests occupy blank replaced space while a new,
in-flight, or pending request can still produce pixels. The current upstream
representation then replaces the bespoke `ImagePaintable` fallback entirely.
Known-broken and source-less elements with nonempty `alt` content attach a
closed UA shadow tree and create an ordinary non-replaced layout node, so CSS
font inheritance, wrapping, selection, and find-in-page use normal text layout.
Source, request, and alternative-text changes refresh that shadow content and
rebuild the node kind when the element moves between fallback text, pending
blank space, and decoded pixels. The `img-alt-text-font` reftest is pixel-exact.

Decoded bitmap data now exposes its retained external-memory size and tracks
live clients for static images as well as animations. Shared resource requests
and the list of available images carry monotonic LRU touch serials and prune to
the upstream 8 MiB/96-entry document limits after successful loads. Entries
whose decoded data still has a display client are excluded from both cache
accounting and eviction: removing them would free no pixels, but would force a
framework-created replacement element to fetch and decode the same URL again.
Focused tests cover external-memory accounting, touch order, size/count
eviction, client registration/release by an image element, and retention of a
live image; the full repository suite passes 651/651.

Decoded image data now also carries the upstream response provenance needed by
canvas security. Shared resource completion preserves the Fetch response's
CORS-cross-origin bit, while the compact synchronous image hook derives the
equivalent opaque no-CORS state from the selected URL and the owning document's
origin. Drawing such an image permanently clears the 2D context's origin-clean
flag. `getImageData()`, HTML canvas data-URL serialization, and blob
serialization then reject with a security error; successful CORS image loads
stay readable. Focused tests cover provenance on bitmap and animated decoded
data, shared and direct image loads, draw-time tainting, pixel readback, and
both HTML serialization paths; the full repository suite remains 651/651.

The viewport content-visibility pass reduces Painting from 136 to 134. Layout
now caches the committed `PaintableBox` objects whose used
`content-visibility` is `auto`, and `ViewportPaintable` exposes the source-shaped
setter and readonly accessor used by the HTML rendering loop. That loop performs
initial viewport-proximity determinations and repeats layout when a previously
undetermined box is initially relevant; it also runs the translated
ResizeObserver gather/broadcast loop to a fixed point. Relevance now includes
focused and selected contents, top-layer descendants, and view-transition
captures as well as viewport proximity.

The backing-store lifecycle pass reduces Painting from 134 to 133. Navigable
viewport changes now restart the source's three-second single-shot timer and
grow device-pixel backing stores with a 256-pixel resize cushion. When the
timer fires, the stores shrink to the exact viewport; each allocation publishes
fresh bitmap IDs to PageClient and the rendering thread. The DOM/Page bridge
supplies the actual device scale, and SVG or child navigables retain the source
early-return behavior.

The 800 checkpoint reconciles the remaining reviewed Layout node/iterator/flex
record shapes and 44 specialized paintable factories, accessors, resets, and
kind discriminators with the active typed lowering path. It also translates
`Layout::css_clamp()` into the flex algorithm, preserving CSS's permitted
maximum-below-minimum ordering, and makes `Node::has_css_transform()` account
for the individual `rotate`, `translate`, and `scale` properties. The full
suite passes 392/392 at this checkpoint.

The 700 checkpoint completes Painting's structural reconciliation against the
renderer-independent command, recording, playback, typed-lowering, and native
resource boundaries, taking Painting from 88 unmatched implementations to
zero. Layout falls from 15 to 4 after translating nested SVG viewport natural
metrics and committed child-viewport sizing, the local margin-box geometry
helper, and inter-word NBSP classification; the active image-provider paths are
also explicitly accounted for. The full suite passes 392/392 at this
checkpoint.

The 600 checkpoint reconciles 100 methods from the previously differential-
tested CSS calculation cluster. Upstream's virtual calculation-node hierarchy
maps to V's live `CalcNode` sum type, its typed record fields, and the parser,
simplifier, resolver, serializer, equality, and Typed OM reification paths.
This reduces the calculation cluster from 238 to 138 and CSS from 696 to 596
without adding class-shaped facade functions. The full suite passes 392/392 at
this checkpoint.

The 500 checkpoint reconciles the next 100 calculation-tree bodies: inversion,
rounding, the inverse and remaining trigonometric functions, exponential and
stepped functions, and calculation-result arithmetic. These map to the same
live `CalcNode` fields and resolver/simplifier paths, reducing the calculation
cluster from 138 to 38 and CSS from 596 to 496. The full suite passes 392/392 at
this checkpoint.

The 400 checkpoint closes the final 38 calculation-tree shapes, then reconciles
the concrete V records replacing the `CalculatedOr` and `PercentageOr` C++
templates, boolean-expression factories, optional column counts, rule-list
iteration, and reviewed stylesheet/image accessors. The pending-image and
associated-font stylesheet lifecycle hooks remain explicitly unmatched. CSS
falls from 496 to 396, and the full suite passes 392/392 at this checkpoint.

The 300 checkpoint reconciles the next 100 CSS bodies with the active V model:
media-feature and `@supports` leaf classes fold into `BooleanExpression`,
selector variants expose typed record fields and parse through the decomposed
complex/simple selector routines, token-stream transactions use the explicit
mark stack, syntax subclasses use one tagged `SyntaxNode`, and eleven error
record hash methods share the exhaustive `ParsingError` key function. CSS falls
from 396 to 296 without adding facade implementations, and the full suite
passes 392/392 at this checkpoint.

The 200 checkpoint reconciles another 100 reviewed CSS shapes: the remainder of
syntax-node serialization, basic-shape serialization and geometry, computed
CSSOM conversion and Typed OM property maps, abstract images, color components,
length contexts, UA style scopes, easing functions, and concrete color fields.
The generated WebIDL self-upcast is classified as a binding-runtime artifact.
CSS falls from 296 to 196 without adding facade implementations, and the full
suite passes 392/392 at this checkpoint.

The 100 checkpoint reconciles another 100 reviewed CSS shapes: typed parser
wrappers and calculation construction, CSS Syntax rule and declaration parsing,
descriptor and Typed OM conversions, rule-subclass records, and per-variant
style-value equality. Known implementation boundaries remain visible rather
than being classified through adjacent code. CSS falls from 196 to 96 without
adding audit-only facades, and the full suite passes 392/392 at this checkpoint.

The zero checkpoint closed the final 100 implementations reviewed against the
2026-03-24 baseline. Direct
translations cover stylesheet invalidation and font/image ownership, numeric
and transform interpolation (including matrix decomposition), grid-track
interpolation and composition, descriptor conversion, Unicode-range
serialization, meter matching, color/style-value operations, list markers, and
text font selection. The remaining C++ ownership accessors, template artifacts,
record fields, and decomposed algorithms are classified only where the active V
path supplies the same responsibility. At that baseline, the audit accounted
for all 18,658 upstream implementations with 0 unmatched, 0 suspicious trivial
bodies, and 0 quarantined coverage shims. The current September audit above
supersedes that historical count. Focused matrix/grid regressions and the full
suite passed 392/392 at this checkpoint.

Flex and grid layout were additionally checked differentially against the upstream
browser with `tools/layout_dump.v`. Flex: a 489-case generated corpus (directions,
wrapping, justify/align keywords, gaps, box-model edges, order, aspect ratios,
item min/max sizes and auto margins) plus an 80-case `align-self` matrix. Grid: a
715-case corpus (track templates including `repeat()`, `minmax()`,
`fit-content()` and `auto-fill`/`auto-fit`, auto-flow modes, explicit and negative
line placement, spans, template areas, named lines, gaps, and the
justify/align-content/items/self keywords).

The grid corpus agrees with `Build/release/bin/Ladybird.app --headless=layout-tree`
on all 715 cases, the flex corpus on all 489, and the `align-self` /
`align-content` matrices on all 80 cases each.

## Native browser rendering

The translated browser builds as `Build/v/Ladybird.app` and passes its
JavaScript/DOM headless smoke check. Its 800x600 `https://example.com` document
capture was compared with an upstream Ladybird capture from the same checkout:

```text
different pixels: 11888 / 480000 (2.4767%)
pixels with channel error over 10: 6767 (1.4098%)
mean absolute error: 0.6846
RMSE: 7.8784
```

The page geometry and content coincide visually; the remaining pixel delta is
concentrated on glyph edges rendered by the two native text backends. The
layout-test comparison path selects Ladybird's Serenity Sans test face.
Production style and geometry already run through `Document::update_style()`,
`StyleComputer`, `Layout::TreeBuilder`, and the typed formatting contexts. The
active compatibility renderer still adapts that typed tree to `BlockBox` and
`PaintCommand`; this transport conversion is a real remaining handwritten
boundary and is not counted as a completed Painting translation. It replays
retained box commands through
Ladybird's stacking-context phase order instead of painting each flattened box
atomically. Its hit-test path reverses that retained phase plan so overlay
chrome, foreground fragments, and border-box fallback preserve their painted
depth without rebuilding paint order or rescanning the DOM for each mouse
event. It resolves the direct DOM owner and applies inverse transforms and
`pointer-events` filtering at the same boundary. The hit plan separately keeps
zero-opacity stacking contexts targetable while excluding non-invertible ones,
and preserves the source's rectangle-only context-root fallback separately from
ordinary boxes' rounded-corner containment.
Committed text runs also remain source-shaped
`PaintableFragment`s instead of being expanded into compatibility word objects
and joined again before native shaping. The native shell records through the
translated `Document::record_display_list()` lifecycle; painting and hit testing
share one retained sorted stacking plan, and command storage crosses the native
boundary without a full-array clone. Retained per-paintable `PaintPhase` command
buckets survive document-level repaints, while `PaintableBox` repaint requests
selectively regenerate that box and its anonymous children. Explicit all-cache
and stacking invalidation clear the whole store, matching the separate C++
invalidation boundaries. Checkbox/radio buckets read live DOM checkedness and
indeterminate state rather than a layout-time attribute snapshot; the translated
`HTMLInputElement::set_checked()` invalidation refreshes the retained commands.
The three-way display-list invalidation mode retains that hit-test plan for
paint-command-only style, focus, selection, media, image, inspector, and
scrollbar changes. The nine properties marked as affecting hit testing upstream
still discard it, and the compatibility renderer eagerly remaps a logically
retained plan when its paint-tree transport snapshot is refreshed so input
dispatch never observes stale pointers or records paint commands synchronously.
Its overlay phase uses Painting's translated scrollbar geometry and
ports PaintableBox's scrollbar colors, mirroring, current-offset placement, and
resize-gripper drawing. That geometry now also drives scrollbar and resize-handle
hit testing, including horizontal-before-vertical checks, resize-corner
precedence, border inflation, and stable chrome-widget identity. Both
`elementFromPoint()` and `elementsFromPoint()` consume the same phase order.
Retained replay and hit testing now share translated
`ScrollState` snapshots: a mandatory root frame and live element offsets
transform descendant content, padding-box clips contain overflow, sticky
constraints track element or viewport scrollports and containing blocks, and
fixed contexts remain rooted to the viewport. Accumulated overflow clips retain
their nested transformed shapes and elliptical per-corner radii in shared
context lists; the native Quartz path intersects those shapes with antialiased
rounded clipping rather than reducing them to bounding boxes. CSS basic-shape
`clip-path` now follows the same accumulated-context order as
C++ and retains move, line, quadratic/cubic Bezier, elliptical-arc, close, and
nonzero/even-odd path state. Quartz clips with the exact retained curves, while
hit testing consumes contours flattened once when the paint tree is built;
neither path is reparsed per command or pointer event. Legacy CSS2
`clip: rect(...)` now follows `PaintableBox::get_clip_rect()` too: it is resolved
from an absolute/fixed box's border box, inserted after its transform and before
`clip-path`, and shared by the box's own paint, descendants, and hit testing.
Negative extents become an empty clip and the four edges use the same rounded
device conversion as C++. Five upstream reftest pairs, including transformed,
offscreen, descendant, and image cases, render with zero differing pixels.
The final `PaintableBox` hit-test gate also rejects points outside normalized
elliptical border radii instead of treating every rounded box as rectangular.
The overlay and visual-context paths now share direct translations of
`PaintableBox::overflow_property_applies()`, `physical_resize_axes()`,
`has_resizer()`, and `is_chrome_mirrored()` instead of embedding those decisions
in compatibility conditionals. SVG/inline/ruby/internal-display exclusions,
table-cell/caption exceptions, viewport and generated-content suppression,
logical-axis mapping, and RTL/vertical chrome placement are covered as one
source-shaped predicate matrix.
Scrollbar layout now follows `PaintableBox::available_scrollbar_length()`,
`absolute_scrollbar_rect()`, `compute_scrollbar_data()`, and
`absolute_resizer_rect()` as separate source-shaped operations. In particular,
resizer-adjusted scrollbar lengths retain C++'s signed geometry for boxes
smaller than the platform gripper instead of being prematurely clamped by the
combined V helper.
Inspector highlighting now records after the ordinary phase stream as well.
Box paintables unite continuation content, padding, border, and margin geometry,
draw the upstream yellow/cyan/green/magenta overlay plus its size tooltip, and
text paintables outline every matching fragment with its red baseline. The
overlay retains scroll, transform, and perspective state while deliberately
discarding clip paths, overflow clips, masks, and effects; changing or clearing
the highlighted DOM node invalidates only the assembled retained display list.
The retained scrollbar objects now also translate `Scrollbar.cpp`'s hover and
thumb-grab state rather than calling a stateless pointer-ratio helper. Hover
enlarges both paint and hit geometry; track presses use C++'s constrained grab
point, captured moves retain that point, and the resulting element scroll
offset is rounded through `CSSPixels::nearest_value_for`. Page's chrome-widget
dispatcher separately preserves captured-before-current-target routing and the
independent `CaptureInput`/`SwallowEvent` decisions. A retained widget index
keeps captured moves O(1), matching C++'s direct object reference rather than
rescanning the paint tree for every pointer event.
`ScrollFrame` and `ScrollState` now expose the source accessors and in-place
`for_each_*_frame()` traversal used by `ViewportPaintable::refresh_scroll_state()`.
The active bridge no longer allocates sticky and ordinary index arrays on every
refresh, `clear()` keeps the vector capacity across paint-tree rebuilds, and
snapshot conversion follows C++'s `FloatPoint` precision. The resulting
snapshot is retained and replaced only when scroll state is dirty, so display
recording, hit testing, and captured chrome dispatch no longer allocate and
copy every frame on each query.
The retained `ScrollState` now owns that dirty bit instead of mirroring it on
the document layout result. Element and viewport scroll-offset storage perform
the invalidation next to the mutation, visual-context rebuilding completes
before offsets are refreshed, and display-list/hit-test/chrome consumers enter
through the shared paint-property update instead of issuing defensive refreshes.
`LIBWEB_VERIFY_SCROLL_STATE=1` force-derives a temporary snapshot after every
skipped refresh and asserts that it matches the retained publication without
replacing its storage.
Scroll-frame parent selection now directly follows
`PaintableBox::nearest_scroll_frame_index()`: fixed paintables attach to the
root frame, ordinary descendants stop at an intervening fixed containing block,
and sticky descendants retain the outer scrollport needed by their constraints.
Percentage sticky insets now resolve against the separate
`PaintableBox::nearest_scrollable_ancestor()` walk. This skips an
`overflow:hidden` containing block even though it owns a programmatic scroll
frame, and uses the next wheel-scrollable ancestor as C++ does.
The overflow-clip path now calls a standalone translation of
`PaintableBox::overflow_clip_edge_rect()`: ordinary boxes start at the absolute
padding box, replaced boxes start at the content box, and the four resolved
clip-margin edges inflate that origin independently.
Outline transport now comes from a direct `PaintableBox::outline_data()`
translation instead of three independent adapter conversions. The operation
resolves `auto` to a 2px solid system accent outline and applies Painting's
shared transparent/none/zero-width suppression before transport.
Border-radius transport now follows `PaintableBox::border_radii_data()` and
`normalized_border_radii_data()` directly. Lengths and overlap factors remain
fixed-point through the source's two refinement passes, and padding-edge clips
only shrink adjacent radii instead of running a second, invented normalization.
Hit-test eligibility now uses a direct
`Paintable::visible_for_hit_testing()` predicate, excluding inert DOM nodes as
well as `pointer-events:none`. Upstream no longer splits inlines around
in-flow blocks, so an interrupting block that declines a hit falls through to
the block container behind it rather than to its inline parent.
The active DOM/layout bridge records the absolute border box of every
paintable an inline generates, one per line. `PaintableBox`'s three absolute
united-rectangle operations unite those boxes, skipping empty boxes after the
first; `HTMLElement` CSSOM offsets therefore span all of an inline's lines
while the line that only hosts an interrupting block contributes nothing,
matching the upstream flat-inline regression.
`PaintableBox::transform_reference_box()` is translated on the same active path:
CSS boxes remap fill/stroke/view to content/border, SVG paintables remap
content/border to fill/stroke, and SVG view-box transforms use the nearest SVG
viewport. `ViewportPaintable::compute_transform()` now composes individual
`translate`, `rotate`, and `scale` before the transform list. The HTML reference
and both WPT percentage-translate reference pairs are pixel-identical; the
mixed HTML/SVG screenshot improved from 24,212 to 9,859 differing pixels and
MAE 4.6117 to 0.2584, leaving raster-edge and text-antialiasing deltas.
`PaintableWithLines::paint_text_decoration()` and
`build_triangle_wave_path()` now replace the renderer-local decoration
reconstruction. Baselines and font metrics come from committed line fragments;
thickness and endpoints use upstream rounding; double-line offsets, native
dotted/dashed strokes, underline position/offset, and the round-joined triangle
wave follow the C++ switch directly. A retained fragment whose style mutation
invalidated the aliased V font cache now rematerializes that cascade through the
document's shared font computer, preserving C++'s immutable-ComputedValues
lifetime across repeated relayouts. The anonymous-wrapper, minimum-thickness,
and underline-offset upstream reference pairs are pixel-identical. Text
selection now follows the adjacent upstream `PaintableWithLines`
foreground pipeline as well. Committed fragments retain their shaped glyph run;
selection and text-control ranges split it at UTF-16 boundaries; explicit
`::selection` color, shadow, and decoration inheritance plus the UA shadow-host
fallback are resolved once; and all backgrounds, shadows, then clipped glyph
runs/decorations are recorded in source order. Selection-state changes
selectively invalidate retained phase commands, while unselected text keeps the
existing coalesced fast path. Quartz consumes the new blurred text-shadow
command and the portable player preserves its layer order with a sharp fallback.
The adjacent `fragment_at_position()` and `paint_cursor()` methods now use the
same retained UTF-16 glyph geometry for a focused editable caret, including the
padding-box fallback for an empty editing host and custom `caret-color`. Empty
block, paragraph, and inline fallbacks use the first available font's ascent
plus descent, capped by line height and centered in its extra leading, so their
geometry remains stable when the first character appears. Parent child offsets
beside text use that text child's retained fragment geometry, so they agree with
equivalent text-node offsets in horizontal and vertical writing modes. Cursor
moves, focus changes, and blink transitions invalidate only the old and new
containing-block foreground buckets, rather than either replaying a stale caret
or discarding the full paint cache.
`PaintableWithLines::hit_test()` and `hit_test_fragments()` now run on that same
retained fragment representation. Exact hits return the text node and
glyph-derived UTF-16 offset; text-cursor misses preserve upstream's nearest-edge
candidate comparison, current-selection ancestry gate, `user-select: none`
exclusion, and empty editable-host offset-zero path. The former active shortcut
that reduced inline content to its containing box remains only as the source
fallback after fragment testing.
Native checkbox and radio foreground painting now uses direct translations of
`InputColors`, `CheckBoxPaintable`, and `RadioButtonPaintable` rather than
renderer-local white boxes and approximate paths. Theme and accent colors,
disabled and active shading, contrast correction, device rounding, rounded
layers, and the exact checkmark path reach the active display list. A focused
upstream control capture has matching geometry and colors; its scale-normalized
MAE is 0.9256, with residuals confined to rasterized edges.
`FieldSetPaintable` now owns fieldset background and border recording on the
active path. Its effective top edge is derived from the rendered legend's
margin box, its background is clipped to the shifted visual border box, and its
top border is replayed only through the device-rounded segments beside the
legend. The recorder-local clips compose with transforms and accumulated
overflow/mask contexts without leaking into descendants or other paint phases;
a transparent-legend capture confirms the former border-through-legend artifact
is gone. Its font-free, scale-normalized upstream comparison has no channel
error above 1 and MAE 0.0244. Geometric list markers also use
`MarkerPaintable::paint()` instead of a renderer-local shape switch. The direct
path preserves CSS-pixel rounding, enclosing device rectangles, exact
disclosure triangles, and typed square/circle/disc commands. Native Quartz now
consumes ellipse commands rather than sending them to the inactive software
surface, restoring the missing circle and disc markers; the five-shape upstream
corpus improves from MAE 0.4082 to 0.1665. Wheel routing follows the C++
containing-block fallback, including
declining
programmatic-only hidden overflow and saturated inner scrollers. These updates
preserve layout and per-phase command caches while refreshing visual scroll
state and dynamic scrollbar thumbs. Uniform rounded box backgrounds now use
one native rounded path, matching the Skia display-list player, rather than a
renderer-local composition of three rectangles and four circles. This removes
six draws per box, fixes translucent corner artifacts, and preserves the arcs
through rotation, skew, and nonuniform scale. The focused nested-overflow
screenshot improved from 103,304 to 4,022 pixels over channel error 3 (MAE
3.2946 to 0.1633); its residual delta is on antialiased path edges. SVG
geometry now reaches the native Quartz renderer as its retained move, line,
quadratic/cubic Bezier, elliptical-arc,
and close segments, including fill rule and stroke cap/join/miter state. URL
`<clipPath>` resources follow `SVGMaskable`'s paint-time path: the attached
resource subtree, target/resource transforms, `userSpaceOnUse` or
`objectBoundingBox` units, per-component `clip-rule`, and component union are
retained in a reusable alpha-mask cache. Empty resources suppress the target;
the mask is deliberately excluded from hit testing, as in C++. SVG `<mask>`
path content now follows the same retained nested-display-list boundary: normal
fill/stroke colors and opacity, `paint-order`, group opacity layers, mask-area
clipping, `maskContentUnits`, and alpha/luminance conversion are composited once
over the complete target context with `destination-in`. URL clips use that same
layer boundary instead of applying antialiased coverage independently to every
leaf command. The shared four-entry native cache rasterizes only each mask's
transformed bounds, not a full-window surface. SVG text is materialized from
the shaped per-code-point computed font cascade into the same quadratic path
representation as `Gfx::Path::glyph_run()`, including lazy author faces and
invisible fallback, so ordinary text and text inside a mask share SVG
fill/stroke/paint-order and mask compositing. Text chunks apply `text-anchor`
once across their nested runs and advance following tspans by shaped advance
rather than outline bounds. SVG `<textPath>` now follows
`Path::place_glyph_runs_along()` too: it measures only the referenced path's
first contour, rotates retained glyph outlines to each tangent, and enforces
the glyph-midpoint cutoff before the same normal or mask path replay. SVG `<image>` now follows
`ImagePaintable` through href/XLink selection, intrinsic-ratio sizing, forced
`contain`, computed object position, `image-rendering` scaling selection,
image-rect clipping, and transformed native bitmap replay. The same ordered
bitmap operations can supply alpha or luminance inside `<mask>`, including
nested group opacity. Canvas boxes now cross the same typed paint boundary:
`CanvasPaintable::paint()` presents an existing surface without allocating one
for untouched elements, retains the RGBA content as `DrawExternalContent`, and
applies upstream scaling-mode selection plus border-shrunken corner clipping.
Native replay consumes that surface directly. Video boxes now retain
`VideoPaintable`'s full representation switch as well: current and first frames
use external content, posters use scaled immutable bitmaps, and the no-data
case records transparent black, all under the same rectangular and
border-shrunken rounded clips. Iframe `srcdoc` documents now cross that boundary
as nested display lists too.
`NavigableContainerViewportPaintable::paint()` updates and records the child at
the iframe content size, clips it to the border-shrunken rounded viewport, and
replays it under the parent transform without rasterizing the child tree.
URL `<linearGradient>` and `<radialGradient>`
fill and stroke paints now retain C++'s same-document resource resolution, href
inheritance and precedence, normalized computed stops, `gradientUnits`,
`gradientTransform`, `spreadMethod`, color interpolation, and paint order.
Radial gradients additionally retain the two focal/end circles, `fr`, C++'s
negative-radius inheritance behavior, and width-relative radius resolution.
Skia consumes both retained gradient styles directly for ordinary paths;
bounded Quartz mask surfaces consume the same data for mask content. Both paths
preserve pad/repeat/reflect tiling instead of substituting the URL paint's
fallback color. SVG `<pattern>` now follows C++'s retained paint-server
path as well: same-document href inheritance, first content-owning linked
resource selection, `patternUnits`, `patternContentUnits`, `viewBox`,
`preserveAspectRatio`, CSS-transform precedence, `patternTransform`, and
non-invertible/empty-tile rejection feed a cached tile display list. Tile
content preserves ordered solid, linear/radial gradient, image, nested-pattern,
stroke, and group-opacity operations. Object-bounding-box content is normalized
against the target origin before rasterization, matching the C++ recorder's
content-origin translation. Quartz caches the resulting high-DPI tile and
repeats it for normal fill/stroke and alpha/luminance mask content. Standard CSS
filters now follow `PaintableBox::resolve_css_filter()` and
`ResolvedCSSFilter::to_gfx_filter()`: retained computed blur, drop-shadow,
brightness, contrast, grayscale, invert, opacity, saturate, sepia, and
hue-rotate operations preserve C++ composition order and create one visual
layer around the complete filtered subtree. Filter layers and SVG masks share
one ordered scope stream, so either may correctly contain the other. The native
Core Image replay uses LibGfx's exact color matrices and device-scaled blur and
drop-shadow geometry instead of filtering individual leaf commands.
`PaintableBox::paint_backdrop_filter()` now uses that same translated resolver
for `backdrop-filter`, records `ApplyBackdropFilter` before the box background
and shadows, and retains the normalized border radii and accumulated clips and
transforms. Quartz snapshots the already-painted destination, applies the
LibGfx operation chain through the shared Core Image implementation, and
composites only the transformed rounded region. If the box also has `filter`,
the sample comes from outside its newly opened filter layer and the result is
painted inside it with the rest of the box. Backdrop presence is cached when
the display list changes (including nested viewports); pages without it remain
on the direct rendering path, and Core Image evaluates only the backdrop's
device bounds. SVG URL filters no longer use the earlier generic sequential
placeholder graph:
`SVGFilterElement::gfx_filter()` is represented with LibGfx constructor input
order and primitive-specific state, including explicit SourceAlpha and
luminance matrices, named-result fallback, blend/composite/arithmetic modes,
component-transfer channel tables, matrix/saturate/hue operations, merge,
morphology, offset, turbulence, displacement, and the specified six-node
drop-shadow expansion. Same-document fragment URLs now resolve the live
`SVGFilterElement`, preserve the standard-CSS-inside/SVG-outside composition
order, and carry the resolved target region and computed flood color/opacity to
native replay. Empty-source, content-generating graphs retain C++'s transparent
target-bounds display-list trigger. Core Image executes flood, every translated
blend/composite mode (including arithmetic and plus-darker), anisotropic blur
and morphology, color matrix/saturate/hue, component-transfer tables, merge,
offset, and channel-selecting displacement while propagating logical graph
extents instead of allocating or flooding the full canvas. Native turbulence,
filter color-space conversions, and decoded-bitmap `feImage` graph inputs now
execute through that graph. The native turbulence node uses Skia's matching
Perlin shader over the retained target bounds and preserves rounded stitch-tile
dimensions. Decoded resources retain their graph URL and target bounds, while
nested pattern display lists replay the same filter layer and bitmap frame. Its
table phase consumes the translated collapsed and separate border collector,
including conflict winners, cell snapping, empty-cell suppression, and exact
rounded-cell repainting. Ordinary block and inline borders now retain their
computed per-edge styles and consume the direct `BorderPainting.cpp`
translation, including elliptical joins, same-color path batching,
dotted/dashed endpoints, inset/outset colors, and double/groove/ridge recursion.
Outlines resolve their computed style and `auto` accent color, inflate the border
geometry with the C++ negative-offset clamp, and enter the same dispatcher.
The root/body branches of `PaintableBox::paint_background()` are now a single
source-shaped operation. When the body's background is propagated to the root
canvas, its `image-rendering` value travels with its color and image layers
instead of leaving the root's sampling mode in place.
Background propagation also identifies the document's first body before
looking for its generated box. If that body has no box, a later rendered body
keeps and paints its own background; containment is read only from the boxes
that actually exist, matching the upstream restyle-time crash fix.
URL backgrounds now retain typed layer data and enter the direct
`BackgroundPainting.cpp` sizing/repetition path after decode. This restores the
source ordering for default sizing, contain/cover, `round` aspect correction,
fixed-point positions, `space` gaps, and attachment handling. Cached replay
refreshes local and viewport scroll offsets, while Quartz resolves tiles in CSS
coordinates, then applies the accumulated transform and the layer's shrunken
elliptical clip radii. The previous screen-AABB sizing and stale-scroll paths
are gone. Non-normal URL layers now paint with all 18 translated CSS blend
modes inside the isolated background group required by
`BackgroundPainting.cpp`, rather than blending directly with page content.
Background sizing and repeat positioning now remain fixed-point `CSSPixels`
through contain/cover scaling, `round` correction, aspect restoration, and the
source's exact first-visible-tile calculation. Ordinary repeat and round layers
without `space` gaps replay as one device-rounded native tiled-image operation,
matching `DrawRepeatedDecodedImageFrame` instead of allocating up to 4,096 tile
rectangles and crossing the renderer boundary once per tile.
Typed linear, radial, and conic gradients now travel through that same ordered
background-image list instead of a separate first-gradient shortcut. Each
gradient is resolved only after `BackgroundPainting.cpp` determines its tile
size with absent intrinsic dimensions, and retains its own origin, clip,
position, size, repetition, attachment, and blend mode. Blocks, inline
fragments, portable SVG, and native Quartz replay all consume the same layer
geometry; transformed native gradients sample in tile-local coordinates and
clip against the exact per-corner elliptical background box.
The gradient parser now follows `GradientParsing.cpp` for interpolation-method
placement, geometry ordering, double-position stops, position-first stops, and
transition-hint attachment. Modern stops select the upstream OKLab default;
legacy stops retain sRGB. Resolved gradients carry that method into every
backend, where the V sampler mirrors `DisplayListPlayerSkia`'s premultiplied
sRGB, linear-sRGB, Lab/OKLab, wide-gamut RGB, and polar-space interpolation,
including hue routing and Skia's powerless-hue neighbor substitution. Portable
SVG uses native sRGB/linearRGB when exact and emits sampled stops for the other
spaces instead of silently falling back to raw sRGB channel mixing.
The same group now implements `background-clip:text`. It records the element's
inclusive-subtree glyph runs, skips absolute/fixed subtrees while retaining
floats, masks the color and all image layers together, and leaves root canvas
backgrounds unmasked. Quartz rasterizes the real configured document font into
one bounded alpha mask before compositing the background group; portable SVG
emits the equivalent user-space text mask.
Full typed Painting
display-list integration remains outstanding.
