# Old Reddit comment latency

Native CPU samples showed that a comment toggle was doing substantial work
outside Reddit's JavaScript handler. Pressing the mouse activated the clicked
element and its ancestors; invalidating `html` and `body` restyled the whole
thread. The subsequent layout update recreated unchanged boxes, DOM layout
boundaries and text caches. A separate collection trace found 12,858 collection
property reads during one toggle.

## Changes

- `71c76800`: compact click replay returns pending edits instead of serializing
  the whole document. Explicit snapshots, cancellation, navigation and edits
  following synchronous native queries retain their existing behavior.
- `6a574003`: ordinary inherited text-color changes refresh retained paint
  styles without discarding geometry. Current-color dependencies update;
  generated content, SVG, filters and geometry changes keep the full path.
- `38562a18`: activation uses the existing selector dependency invalidation
  plans, including `:active` inside `:has()`. Legacy DOM-only clients keep
  conservative invalidation. Repeated presses preserve the computed styles of
  512 unrelated comments while affected selectors and pseudo-content update.
- `7bd67711`: unchanged live tag collections check a native scalar tree version
  before performing a JSON query. Pending edits still flush and native tree
  changes invalidate collection membership.
- `260cdb08` / `26b07c0f`: resolved document styles reuse their immutable layout
  cache when document, property graph and font-computer identities, geometry,
  font inputs and color context agree. Counter definitions remain live;
  animations, manual cache edits and changed inputs retain full resolution.
  Identity checks use pointer casts because V's pointer equality can compare
  pointed-to values.
- `0b659953` / `2ed7fff5`: layout-tree updates retain clean ordinary flow
  branches, including text shaping caches and DOM boundaries. Formatting still
  runs against fresh layout state. Dirty descendants, adoption, reparenting,
  changed display, special boxes, generated content and SVG references use the
  complete builder. Counter effects replay in document order. Inline branches,
  line breaks and flat list markup are covered; namespace-bridging SVG
  descendants retain separate reference instances.

## Measurement

The matching build experiment measured a 71.38% lower median time to the next
native frame. All six actual comment states alternated correctly in both runs.

| Median of six clicks | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Native mouse handling | 5,471.15 ms | 1,588.16 ms | 70.97% |
| Through next native frame | 5,603.00 ms | 1,603.56 ms | 71.38% |

The separate current-workspace production replay measured 224.41 ms median to
the next frame across all six clicks. The first measured toggle took 979.44 ms;
the subsequent five ranged from 145.81 to 265.71 ms, with a median of 186.47 ms.
That build includes newer concurrent changes, including computed-cache
compaction. Its additional improvement is not attributed solely to this slice.
These are single six-click diagnostic sequences on a shared working machine,
not a latency guarantee or a statistical confidence bound. The remaining first
toggle cost is explicit rather than being excluded from the overall median.

`comparison-final4.json` and `replay-integrated.json` retain every sample,
actual collapsed-state sequence, binary hash and fixture hash. All three final
document captures have identical RGB pixels after cropping native chrome at
`[0, 88, 800, 576]`; the document SHA256 is
`c8bd010142efbb8e4a721f080c55465f909812e3944fcfefa822d6ccee3771bb`.

The replay serves a private cached thread and its nine original scripts from
localhost. Six native Cocoa mouse presses/releases invoke the original
`togglecomment` function through a visible proxy control. Both variants use
identical markup and minimal collapse CSS. Every run must alternate the actual
comment container's collapsed state six times. No delta shim or diagnostic
collection wrapper is enabled in timed runs. This measures cached native replay,
not live-site loading or a universal latency for every Reddit thread.

Handling time includes synchronous native mouse handling. Frame time ends when
the next native layer update returns; physical display scanout is outside that
measurement. The fixture is deliberately kept private under ignored
`Build/reddit-comment-latency/`, together with samples, logs and receipts.

The matching control restores the old activation setter, full event return,
conservative color-refresh functions, JSON collection reads, full resolved-value
materialization and full tree building. All other generated C, native libraries,
assets and compiler flags match. Both use C-O2, Boehm GC and one marker.

The frozen candidate's four retained-flow helper functions were refreshed from
the tested V-generated reference C after the inline and namespace corrections.
Their signatures match, each definition is replaced exactly once, and the copied
bodies contain no test-runner calls or entry-module type indexes. The matching
control disables their caller. `final4-build-plan.json` records source hashes
and the four old/new function hashes. The installable app is built separately
through the normal production script against the current shared workspace and
receives its own native replay, so newer concurrent work is included.

The initial two changes improved an intermediate replay by only 8.4%, prompting
the warm-click profile. The three-change replay improved its frame median from
5,106.39 to 2,596.70 ms (49.15%), which motivated the remaining work. These are
intermediate results. Startup samples and runs with diagnostic shims receive no
final timing credit. An early observer read the proxy control's class instead
of the comment container; its rejected run remains retained.

## Validation

Focused default-GC and no-GC checks cover click deltas, cancellation and
navigation; color-only updates; active descendant/sibling/negated/relational
selectors; live collection membership and pending writes; resolved-style cache
provenance; and retained layout branches. Layout tests compare every toggle
with a forced full rebuild, check inherited color and width-dependent wrapping,
preserve earlier display-list snapshots, and exercise counters, adoption,
inline/block wrapping, special-box fallback and SVG reference independence.

The prior expansion report recorded seven fixes after its inherited broad
baseline. The first three here completed that ten-fix checkpoint. Selected
translation checks, the 236-file/782-case LibJS source union in both GC modes,
all 100 unchanged upstream AST comparisons and eleven default screenshot cases
passed (eight exact, three within existing bounds). The final three optimization
slices receive focused checks afterward and start the next batch at 3/10;
corrections remain part of their original slice. No retired-instruction savings
or full LibJS parity are claimed; browser execution continues to use
JavaScriptCore.

The LibJS aggregate initially failed on an import alias collision; a combined
self-spawning regex run was cancelled. Recovery kept passing groups and ran
the three subprocess tests as separate original files. Failed/cancelled whole
runs receive no wholesale pass credit. Focused fixture/compiler failures, an
incorrect control-extractor attempt, a disk-full build and an early verifier
wait race are also retained separately from successful retries.

Both final binaries passed strict code-signature verification, headless startup,
a controlled native click without navigation, the cached thread's original nine
scripts and all eight required SVG mutation guards with exact pixels. The
current-workspace production build also passed its independent six-toggle
replay, and its document pixels match the frozen optimized build exactly.
The receipts are `native-final4-{verified,real-thread}.json`,
`native-integrated-{verified,real-thread}.json`, `comparison-final4-pixels.json`
and `integrated-pixels.json` under the private evidence directory.

## Installation

The verified current-workspace production bundle was installed atomically at
`Build/v/Vox.app` on 2026-10-18. The previous bundle was preserved at
`Build/reddit-comment-latency/previous-Vox-1792288551.app`. Strict signature
verification and headless startup passed after installation, and the installed
executable matches the independently timed binary:
`9d6286d94254e1a2b19098f6e7c633f3f67573856c7212dad34db22db6b3536f`.
`installed-integrated.json` records the previous hash and all 37 prerequisite
checks. Existing browser processes were left running; restart Vox to load the
installed executable. Temporary aggregate test files were removed; the focused
regression tests remain committed with their implementation slices.
