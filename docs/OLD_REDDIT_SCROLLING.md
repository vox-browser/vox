# Old Reddit scrolling

The macOS Chromium-compatible renderer retains one bounded viewport of document
pixels and repaints the exposed strip after an integral device-pixel scroll.
Overlay scrollbars are drawn afterward, so movement and fading cannot leave old
thumbs in the cached page. The cache is capped at 64 MiB; a 1024×768 viewport at
2× density uses 12 MiB. It does not grow with document length.

Content invalidation advances a document paint revision. Navigation, resizing,
density changes and fractional device-pixel movement fall back to complete
replay. Fixed/sticky content, independent media, unsupported effects and deferred
shared SVG rendering also use complete replay. The command and visual-context
checks include offscreen content.

Completed background resources invalidate cached pixels even when layout and
paint commands remain unchanged. Native animated images disable reuse while
visible. Replaced-image visibility follows the retained image paintable rather
than the compatibility box, preserving thumbnail rows as they enter the viewport.

The native window avoids GG's second software frame limiter while retaining
Sokol's display scheduling. A redraw requested during layer publication is
redelivered after AppKit finishes its display pass. Hidden debug-status changes
keep their latest value without rebuilding native toolbar and tab controls;
showing the debug strip immediately displays that latest value.

Native events are copied field by field from Sokol to GG. Casting between their
records misread the 32-bit native dimensions as 64-bit V integers, corrupting
resize dimensions and later event fields. Keyboard, pointer and resize callbacks
retain GG's dispatch order and coordinate scaling.

## Measurement

A matched 600-callback measurement at 1024×768 compares complete replay with
viewport reuse in the same executable and native libraries:

| Per callback | Complete replay | Viewport reuse |
| --- | ---: | ---: |
| Median | 6.831 ms | 4.000 ms |
| 95th percentile | 18.147 ms | 15.868 ms |
| Maximum | 31.694 ms | 31.596 ms |
| Callbacks exceeding 16.667 ms | 55 / 600 | 19 / 600 |
| Retired instructions, total | 69.246 billion | 34.785 billion |
| Mean native completion cadence | 88.40 fps | 105.15 fps |

Median callback time falls 41.45%; the matched pair saves 34.460 billion retired
instructions. The cache is reused in 585 of 600 callbacks; 15 content revisions
require full replay. After the first 60 callbacks, the remaining 540 all reuse
the viewport: median 3.919 ms, p95 6.206 ms, maximum 15.756 ms, and zero callbacks
exceeding the 60 fps work budget. These are a separately identified steady
portion of the same full run. Cold content still produces occasional slow
frames; this does not establish uninterrupted 60 fps presentation.

The wheel workload moves 42 CSS pixels per callback, reversing every 30
callbacks between offsets 0 and 1260. Evidence is in `abi-600-before/summary.json`,
`abi-600-after/summary.json`, and `abi-performance-summary.json`. Both summaries
pin executable, native libraries and private resource-cache hashes.

The private workload is the cached
`https://old.reddit.com/r/UkraineRussiaReport/` page, with identical HTML,
resources, viewport and wheel positions in each pair. Network requests are
blocked for these measurements. The startup quiet period runs once; later lazy
image requests do not insert artificial pauses between wheels. The profiler is
opt-in and does not inject page scripts.

Native callback times include wheel dispatch, frame preparation, paint replay
and synchronous GPU waits. Completion-receipt intervals additionally include
layer publication and scheduling, but are not physical display scanout times.
This benchmark does not establish live-site performance or Brave frame-rate
parity. Retained private receipts are under
`Build/urr-scroll-20261025/`.

## Validation

Implementation commit `9075134f` contains the scrolling change; `7ff6f684`
contains the native event-record correction. All 17 scrolling source hashes
match the tested frozen source (`committed-source-proof.json`).

The final source passes 68 focused root/layout cases in both preallocated and
Boehm configurations (136 case executions), including scroll routing, repaint
revision, resource completion, fallback eligibility, image visibility, native
events, chrome control identity and scrollbar behavior. Optimized native tests
verify exact pixels at both densities while scrolling in both directions,
overlay fading, ownership/revision changes, resize, density changes, fractional
movement, animated-image invalidation and redraw requests during publication.
Production build, strict bundle signing and headless startup pass.

Four Reddit screenshot pairs are pixel-exact between full replay and viewport
reuse: 1× and 2× density, after 30 and 45 wheel callbacks (both directions).
All 11 default smoke captures also preserve the independently retained prior
build's decoded pixels exactly (`abi-smoke-baseline-preservation.json`). The
canonical-reference smoke command exits 1: inline-node, ordered-list,
text-decorations and default-ignorable-code-points-not-painted retain existing
font differences. Their respective differing-pixel counts are 14,944, 4,900,
29,823 and 1,712. No reference or tolerance is changed. This is preservation
credit, not a claim that all canonical reference comparisons pass.

All eight focused SVG image/paint-server mutation comparisons pass with zero
differing pixels, including same-size image source replacement, ID collisions,
removed gradients, changed stops and late-loading pattern images. Receipts are
in `abi-svg.log` and `abi-svg-guard.json`.

The table's production measurements use a frozen copy of the implementation and
all committed renderer dependencies through `0a04e03f`, excluding unrelated
unfinished edits. `validated-source-identity.json` records source hashes, and
`abi-native-final-identity.json` records the final native refresh. Failed early
build/test receipts remain retained without passing credit.

The combined main app also passes strict signing, headless startup and two
additional pixel-exact Reddit pairs at 1× and 2× density after 45 wheels
(`installed-*` receipts, executable SHA-256
`1d99000db16e7e552912813f4c53cb3503e7e3691d9f6421e90f04229d23882e`).
Its first additional 600-frame timing comparison was rejected: two cold-sweep
callbacks had different paint-command counts, so that pair earns no matched
performance credit. The table above uses the accepted frozen-source pair.

A subsequent production rebuild and repeat passes the full 600-callback trace
comparison, including identical executable/native-library hashes, resources,
scroll positions and paint-command counts. The current executable SHA-256 is
`6cf799d7a3e2f3ea4898677236622141f201d1ad0b24af9d4f127a60e324f0a2`.
Complete replay has median 6.643 ms and p95 16.753 ms; viewport reuse has median
3.487 ms and p95 14.674 ms, a 47.51% median reduction. The reused run has
20 / 600 callbacks over 16.667 ms, all during the initial 60 callbacks. Its
remaining 540 callbacks have median 3.447 ms, p95 5.742 ms and maximum 14.261 ms.
Reuse occurs in 585 / 600 callbacks, and all 540 steady callbacks. Both runs
finish successfully with strict comparison checks intact. Strict signing and
executable/native-library identity are verified afterward. See
`installed-repeat-runtime-guard.json`, `installed-repeat-600-{before,after}/summary.json`,
`installed-performance-summary.json` and `final-main-app-identity.json`.

For diagnostics, `VOX_DISABLE_SCROLL_RASTER_REUSE=1` selects complete replay.
The existing profiler can collect the matched workload with
`python3 tools/measure_browser_scroll.py --help`.
