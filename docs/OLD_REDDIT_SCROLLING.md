# Old Reddit scrolling

The macOS Chromium-compatible renderer retains one bounded viewport of document
pixels and repaints the exposed strip after an integral device-pixel scroll.
Overlay scrollbars are drawn afterward, so movement and fading cannot leave old
thumbs in the cached page. The cache is capped at 64 MiB; a 1024×768 viewport at
2× density uses 12 MiB. It does not grow with document length.

The retained rows form a ring. Scrolling advances its origin, restores the
overlapping pixels to the fresh canvas and writes only the exposed rows back
after painting. Each contiguous row transfer uses at most two copies when the
ring wraps; wider canvas pitches retain a row-by-row fallback. Reused frames clear
only the exposed document strip. Cached images are culled using their retained
image rectangle or background clip, including transforms and raster fringes,
before image decoding or upload. Unknown bounds remain eligible for replay.

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
scroll positions and paint-command counts. That repeat's executable SHA-256 is
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
`VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS=1` keeps viewport reuse while
selecting the previous full-canvas clear, full cache writeback and image replay
path for a matched comparison. An empty value keeps the optimized path.
The existing profiler can collect the matched workload with
`python3 tools/measure_browser_scroll.py --help`.

## 100 fps optimization

A further matched 1,200-callback comparison uses the same cached page, 1024×768
viewport, wheel trace, executable and native libraries. Each run uses an isolated
profile with bookmarks hidden. Both paths retain viewport reuse; the diagnostic
switch above selects the previous damage handling. Source is pinned to committed
renderer dependencies through `97ccca78` plus the scroll change.

| Per callback | Previous damage path | Optimized damage path |
| --- | ---: | ---: |
| Median | 4.440 ms | 3.899 ms |
| 95th percentile | 19.257 ms | 19.764 ms |
| Maximum | 45.753 ms | 49.007 ms |
| Callbacks exceeding 10 ms | 75 / 1,200 | 75 / 1,200 |
| Retired instructions, total | 48.907 billion | 43.939 billion |
| Mean native completion cadence | 109.90 fps | 110.47 fps |

Median callback work falls 12.17%, saving 4,967,359,749 observed retired
instructions over the identical trace. Both runs reuse the viewport in 1,185
callbacks and have 15 full replays. After the first 60 callbacks, all remaining
1,140 reuse the viewport. Their optimized median is 3.868 ms, p95 7.279 ms and
maximum 22.776 ms, with mean completion cadence 122.87 fps. Eighteen of those
callbacks exceed the 10 ms budget; all eighteen occur before callback 90.
Early slow frames remain included in the full-run results. The full-run tail
latency does not improve. These receipt-based averages exceed 100 fps, but do
not establish uninterrupted 100 fps or display scanout.

The accepted comparison and source pins are retained under
`Build/urr-100fps-20261025/`: `isolated-1200-{before,after}/summary.json`,
`isolated-performance-summary.json`, `isolated-viewport-proof.json` and
`source-identity.json`. Executable, native-library, resource-cache, wheel-position
and per-frame command-count checks all match. Earlier unisolated runs inherited
a visible bookmarks bar, reducing document height by 28 pixels despite the
requested viewport metadata; they are retained separately and receive no credit
in this table. The initial build failed because the validation copy lacked an
upstream include link; its receipt remains retained without passing credit.

A stable copy of the combined main app also passes strict signing and headless
startup. Its independent isolated-profile 1,200-callback run averages 110.74 fps,
with median 4.054 ms and p95 19.283 ms callback work. After the first 60 callbacks,
the remaining 1,140 average 122.88 fps, with median 4.030 ms and p95 7.573 ms;
18 callbacks exceed 10 ms. This standalone run earns no matched reduction credit.
`production-identity.json` pins executable SHA-256
`bbff479d4be0471325283794884cfae79d757a91c4d91270583c1461c63d055e`
and native libraries. Its recorded working-source hashes describe validation
time, not build provenance. Later concurrent builds of the main app receive no
timing credit from this copy. See `isolated-production-performance-summary.json`
and `isolated-production-1200/summary.json`.

Implementation commit `4264f040` contains the optimization and focused tests.
`committed-source-proof.json` verifies that its four complete scroll files equal
the tested source bytes and its `main.v` change applies identically to the
frozen dependency snapshot and the actual commit parent.

The measured instruction saving triggers broad verification. The tested snapshot
passes 70 root/layout cases in both preallocated and Boehm configurations (140
case executions). Optimized native tests pass with strict compiler warnings and
compare complete canvas buffers against full replay, including ring wrap in both
directions, padded row strides, zero movement, nearly full-height movement,
diagnostic mode changes and 1×/2× density. Build, strict signing and headless
startup pass. See `root-regressions-summary.json`, `root-{compile,run}-batch-guard.json`
and `runtime-batch-guard.json`.

Two isolated-profile Reddit viewport pairs are pixel-exact against full replay
at 1× and 2× after 45 wheels, covering both scroll directions and all 1024×768
document pixels. All 11 default smoke captures exactly preserve the independent
prior build. The smoke command still exits 1 for the four existing canonical
font differences listed above; no references or tolerances change. The first
unisolated smoke attempt retained the bookmarks-bar offset and failed the
preservation check; its original failure receipt remains retained. All eight SVG
mutation comparisons pass with zero differing pixels. See
`isolated-pixels-*-equality.json`, `smoke-isolated-baseline-preservation.json`,
`svg-isolated.log` and `isolated-batch-guard.json`.

## 120 fps optimization

Viewport raster eligibility already requires overlay scrollbars to form a
trailing command suffix. Scrollbar replay now finds that suffix from the end
and preserves each command's original order and raster-layer index. It avoids
scanning and copying every document paint command again after document painting.
The optimized ARM64 disassembly confirms direct marker loads during suffix
discovery. `VOX_DISABLE_SCROLLBAR_TAIL_REPLAY=1` selects the previous scan for
diagnostics; an empty value keeps the optimization enabled.

Three interleaved pairs each run the same 1,200-callback cached Reddit trace
through the same signed production executable and native libraries. Isolated
profiles hide bookmarks, the document viewport is 1024×768, and network access
is disabled. Executable, libraries, cached resources, scroll positions and
per-callback paint-command counts match across all six runs. No CPU sampling
is active.

| Median across three runs | Previous scan | Scrollbar suffix |
| --- | ---: | ---: |
| Full-run callback median | 2.963 ms | 2.783 ms |
| Full-run native completion cadence | 118.668 fps | 118.392 fps |
| Settled completion cadence | 119.995 fps | 120.002 fps |
| Settled retired instructions | 30,540,964,646 | 30,351,081,623 |

Median callback work falls 6.06%. The settled instruction comparison saves
189,883,023 retired instructions over the same final 1,110 callbacks, exceeding
the repository's 5,000,000-instruction broad-verification threshold. All six
runs reuse the viewport in 1,185 callbacks and in every settled callback.
Optimized settled callback medians are 2.756–2.807 ms, p95 values are
3.186–3.272 ms, and maxima are 4.677–5.140 ms. None exceeds 8.333 ms.
The previous scan also fits that settled callback budget; the change reduces
CPU work without establishing a full-run cadence improvement. Initial slow
callbacks remain included above: the optimized runs have 27–29 callbacks over
8.333 ms, all within the first 90 callbacks. Completion-log receipts include
scheduling and log-delivery latency; they do not measure physical display
scanout. Callback timings exclude native bitmap acquisition and layer
publication. Live Reddit behavior and Brave parity remain unmeasured.

All four document comparisons are pixel-exact: suffix replay versus the
previous scan, and viewport reuse versus complete replay, at both 1× and 2×
after 45 wheel events. Production build, strict signing and headless startup
pass. Evidence is retained under `Build/urr-120fps-20261025/` in
`tail-performance-summary.json`, `tail-repeat-*/summary.json`,
`tail-frame-pixels-*-equality.json`, `tail-canonical-guard.json` and
`tail-runtime-guard.json`. The stable tested bundle is `tail-app/Vox.app`;
`tail-app-identity.json` pins executable SHA-256
`55b4724666ec512ac785d49db3693311939d9a60bd2482f910381e6f4c63a7cf`
and all bundled libraries. `tail-canonical-source-{before,after}.json` records
the combined working tree around compilation; the owned scroll files are
unchanged, while unrelated concurrent source changes are listed separately in
`tail-canonical-build-result.json` and receive no feature credit.

Frame-buffer pooling experiments were rejected and removed from the source.
Their final matched comparison increased callback work and retired
instructions without improving completion cadence; those results remain in
`resident-performance-summary.json`. No pooling implementation ships with
the scrollbar optimization.

Implementation commit `4293c031` contains the optimization and its focused test.
`tail-committed-source-proof.json` verifies that both complete scroll files in
the commit match the tested source bytes. All seven scroll cases pass in each
of the preallocated and Boehm configurations. The related 85-case batch runs
in both configurations: 82 cases pass and the same three native UI cases fail
in each. Two unchanged native pixel tests expect BGRA bytes while the committed
renderer creates RGBA frames. The third failure is in concurrent, uncommitted
native tab-drag work. None calls scrollbar suffix replay. The broad batch remains
red; no clean broad-verification checkpoint is credited. See
`tail-root-regressions-summary.json`, `tail-root-test-call-proof.json`,
`tail-root-compile-guard.json`, `tail-root-run-retry-guard.json` and
`tail-root-boehm-remaining-guard.json`.

The original regression-run attempt exhausted disk space before launching a
test. Its empty guard receipt and separate infrastructure-failure record remain
retained; completed compilation and performance checks were reused. The retry
does not hide those native UI failures or receive passing credit for them.

A native-only probe compiled from unmodified committed headers reproduces both
pixel failures without linking the V browser or scrollbar code: result masks
are 29 versus 31 and 964 versus 1023, with a red pixel stored as RGBA
`255,0,0,255`. Compilation succeeds; the diagnostic exits 1 because the
original assertions still fail. `tail-native-baseline/identity.json` pins
the source headers, `tail-native-baseline/result.json` records the output,
and `tail-native-baseline-guard.json` records the guarded execution. These
baseline failures remain reported as failures.
