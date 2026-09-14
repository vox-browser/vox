# LibWeb V translation inventory

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb`

Translation workspace: `~/code/vox2`
Audited: 2026-09-14

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

The current base-to-head semantic delta audit reports 4,612 unmatched changed
C++ spellings. That is a structural review queue rather than a count of missing behaviors: active V
implementations often consolidate C++ class hierarchies and overloads under a
single typed path. Empty/default-return implementations are checked separately,
and the refreshed current-tree audit has 21 candidates awaiting body review.

The current Layout refresh also follows shadow hosts while locating a positioned
inline containing block. Absolutely positioned shadow-tree descendants therefore
use their inline host instead of falling back to the viewport.
Flex and inline-flex fieldsets retain their special legend layout while applying
flex direction, wrapping, alignment, and gaps to the anonymous content box. The
wrapper is also created for flex fieldsets without a rendered legend.
Viewport propagation now copies the root scrollbar width and the containment-
aware principal writing mode and direction, while selecting and neutralizing
the correct root/body overflow origin.

The earlier inventory mapped every upstream implementation filename to V code,
but filename and symbol-name coverage did not establish behavioral parity. A
semantic re-audit found name-only `upstream_*entry_points.v` coverage-shim
files. Every such file has now been compared with the corresponding upstream
bodies, rewritten where necessary, and promoted under an implementation name;
the current audit has no quarantined coverage files. The remaining `Present`
modules still have upstream bodies that require the same behavioral audit.

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

The table below is the refreshed 2026-09-12 inventory. It covers 76 current
implementation-bearing upstream modules plus the translated IDL/IPC-only
`Fullscreen` and `Worker` packages, and all 1,193 module-owned `.cpp`
implementation units. Root-level LibWeb `.cpp` support units are mapped
separately in `ROOT_SUPPORT.md`. The removed upstream `PermissionsPolicy`
module's small compatibility package remains in the repository but is excluded
from the current-module totals.

| Upstream module | `.cpp` files | Upstream `.cpp` LOC | Translated implementation `.v` LOC | Test `.v` LOC | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| `ARIA` | 6 | 1,955 | 2,535 | 399 | Complete |
| `Animations` | 10 | 5,187 | 3,972 | 1,041 | Complete |
| `Bindings` | 11 | 2,501 | 2,675 | 918 | Complete |
| `CSS` | 215 | 47,722 | 101,898 | 7,726 | Present |
| `Clipboard` | 4 | 1,009 | 973 | 343 | Complete |
| `Compositor` | 6 | 1,687 | 2,403 | 361 | Complete |
| `Compression` | 2 | 348 | 424 | 138 | Complete |
| `ContentSecurityPolicy` | 37 | 4,725 | 2,738 | 427 | Complete |
| `CookieStore` | 2 | 850 | 859 | 434 | Complete |
| `CredentialManagement` | 6 | 382 | 418 | 301 | Complete |
| `Crypto` | 6 | 13,412 | 4,472 | 1,459 | Complete |
| `DOM` | 59 | 34,859 | 35,721 | 2,154 | Complete |
| `DOMURL` | 4 | 1,039 | 754 | 336 | Complete |
| `Editing` | 26 | 12,720 | 3,294 | 741 | Complete |
| `Encoding` | 6 | 769 | 705 | 244 | Complete |
| `EncryptedMediaExtensions` | 3 | 535 | 572 | 329 | Complete |
| `EntriesAPI` | 1 | 47 | 44 | 32 | Complete |
| `EventTiming` | 1 | 122 | 153 | 94 | Complete |
| `Fetch` | 33 | 8,493 | 5,188 | 1,365 | Complete |
| `FileAPI` | 6 | 1,357 | 1,018 | 499 | Complete |
| `Fullscreen` | 0 | 0 | 93 | 177 | Complete |
| `GPC` | 1 | 21 | 16 | 13 | Complete |
| `Gamepad` | 6 | 1,351 | 760 | 275 | Complete |
| `Geolocation` | 4 | 643 | 416 | 176 | Complete |
| `Geometry` | 8 | 2,078 | 2,062 | 1,008 | Complete |
| `HTML` | 286 | 83,853 | 56,513 | 12,347 | Complete |
| `HighResolutionTime` | 2 | 516 | 442 | 195 | Complete |
| `IndexedDB` | 19 | 6,991 | 5,211 | 1,086 | Complete |
| `Infra` | 3 | 385 | 207 | 63 | Complete |
| `Internals` | 7 | 2,583 | 854 | 230 | Complete |
| `IntersectionObserver` | 2 | 528 | 569 | 327 | Complete |
| `Layout` | 9 | 4,001 | 40,972 | 15,303 | Present |
| `Loader` | 6 | 1,291 | 1,921 | 664 | Complete |
| `MathML` | 6 | 369 | 411 | 97 | Complete |
| `MediaCapabilitiesAPI` | 1 | 345 | 676 | 117 | Complete |
| `MediaCapture` | 5 | 1,475 | 1,205 | 205 | Complete |
| `MediaSourceExtensions` | 13 | 4,094 | 357 | 110 | Complete |
| `MimeSniff` | 2 | 1,607 | 1,108 | 308 | Complete |
| `MixedContent` | 1 | 127 | 125 | 105 | Complete |
| `NavigationTiming` | 4 | 497 | 291 | 45 | Complete |
| `NotificationsAPI` | 1 | 301 | 290 | 68 | Complete |
| `Page` | 8 | 6,450 | 2,662 | 666 | Complete |
| `Painting` | 22 | 8,227 | 6,811 | 2,089 | Present |
| `PerformanceTimeline` | 5 | 476 | 447 | 130 | Complete |
| `PermissionsAPI` | 3 | 388 | 239 | 74 | Complete |
| `Platform` | 4 | 431 | 1,750 | 200 | Complete |
| `ReferrerPolicy` | 2 | 341 | 239 | 123 | Complete |
| `RequestIdleCallback` | 1 | 52 | 59 | 18 | Complete |
| `ResizeObserver` | 4 | 424 | 420 | 152 | Complete |
| `ResourceTiming` | 1 | 357 | 338 | 84 | Complete |
| `SRI` | 1 | 198 | 156 | 100 | Complete |
| `SVG` | 82 | 9,020 | 5,107 | 1,069 | Complete |
| `SecureContexts` | 1 | 76 | 59 | 13 | Complete |
| `Selection` | 3 | 1,470 | 598 | 125 | Complete |
| `Serial` | 2 | 366 | 243 | 35 | Complete |
| `ServiceWorker` | 11 | 2,608 | 1,562 | 513 | Complete |
| `Speech` | 11 | 421 | 624 | 111 | Complete |
| `StorageAPI` | 6 | 433 | 444 | 235 | Complete |
| `Streams` | 22 | 8,789 | 6,290 | 1,972 | Complete |
| `TrustedTypes` | 7 | 1,175 | 756 | 185 | Complete |
| `UIEvents` | 12 | 1,871 | 1,358 | 378 | Complete |
| `URLPattern` | 1 | 223 | 1,632 | 214 | Complete |
| `UserTiming` | 2 | 160 | 119 | 35 | Complete |
| `ViewTransition` | 1 | 1,054 | 598 | 324 | Complete |
| `WebAssembly` | 7 | 3,441 | 2,065 | 702 | Complete |
| `WebAudio` | 47 | 8,256 | 2,649 | 444 | Complete |
| `WebDriver` | 16 | 5,321 | 3,447 | 638 | Complete |
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
| **Total** | **1,193** | **329,970** | **338,462** | **66,317** | **75 complete, 3 present, 0 untranslated** |

## Verification

The semantic inventory exits nonzero while structural spellings still require
manual classification. Its current baseline is:

```text
$ python3 tools/libweb_translation_audit.py
upstream modules: 76
upstream .cpp files: 1193
upstream implementations: 21401
quarantined name-only coverage shims: 0 files / 0 functions
explicit semantic-divergence markers: 10
reviewed upstream-equivalent trivial implementations: 534
suspicious empty/default-return implementations: 21
  candidate-name-match: 13847
  unmatched: 4612
  language-constructor-or-destructor: 1383
  gc-or-binding-runtime: 655
  consolidated-name-match: 488
  namespace-template-specialization: 177
  language-operator: 124
  language-template-trait: 63
  value-record-field-match: 52

largest unmatched modules:

  1716 CSS
  1261 HTML
   639 DOM
   438 Painting
   316 Layout
   242 Editing

$ /Users/alex/code/v/v -enable-globals run tools/layout_corpus.v --all
Layout corpus: 788 passed, 301 failed, 1089 total

$ /Users/alex/code/v/v -enable-globals test .
Summary for all V _test.v files: 398 passed, 398 total.

$ Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
Ladybird V smoke check passed

$ ./compare_screenshots.sh <24-new-cases> inline-node ordered-list \
    text-decorations <5-modified-svg-cases>
32 passed, 32 total (31 distinct fixtures)
```

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

The inspector-overlay pass then reduced Painting from 141 to 137. The broken
HTML image branch now reduces it to 136: `ImagePaintable` outlines the content
rectangle and centers the live `alt` text with the default 12px font when its
provider is unavailable. Retained layout trees refresh provider availability,
selected source, intrinsic dimensions, and alternative text before relayout,
so a failed image can transition to changed fallback text or decoded content
without rebuilding the tree.

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
well as `pointer-events:none`. Anonymous middle boxes in a split inline chain
retain the source's `PaintableBox::hit_test_continuation()` fallback to the
principal inline element after their block descendants decline the hit.
The active DOM/layout bridge now retains the forward chain corresponding to
Layout's split-inline continuation links. `PaintableBox`'s three absolute
united-rectangle operations walk that chain and unite its nonempty border,
padding, or content boxes; `HTMLElement` CSSOM offsets therefore include block
descendants and trailing fragments of an inline principal box, matching the
upstream split-inline regression exactly.
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
padding-box fallback for an empty editing host and custom `caret-color`. Cursor
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
the font's TrueType contours into the same quadratic path representation as
`Gfx::Path::text()`, so ordinary text and text inside a mask share SVG
fill/stroke/paint-order and mask compositing. SVG `<textPath>` now follows
`Path::place_text_along()` too: it measures only the referenced path's first
contour, rotates glyph outlines to each tangent, and enforces the glyph-midpoint
cutoff before the same normal or mask path replay. SVG `<image>` now follows
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
extents instead of allocating or flooding the full canvas. Native turbulence
generation and decoded-bitmap `feImage` graph inputs remain outstanding. Its
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
