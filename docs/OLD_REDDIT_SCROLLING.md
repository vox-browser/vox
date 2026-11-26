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

## Page zoom

Viewport reuse used to require 100% page zoom. A user keeping
`old.reddit.com` at 175% therefore repainted the whole viewport on every
scrolled frame. Since `1db11f03b` zoomed frames use the ring. Keys, content
damage and the skip plan stay in the CSS pixels of the recorded commands; the
damage rectangles are scaled to view pixels and widened to whole pixels.
Keys remove the scroll translation the scroll state snapshot actually applied,
which is stored in f32: a zoomed view scrolls by fractional CSS pixels, and the
unrounded offset left a per-frame residue that mismatched every key.
`VOX_DISABLE_ZOOMED_SCROLL_RASTER=1` restores complete repaints. A complete
zoomed repaint does not use the GPU canvas: most of its rectangle edges are
fractional, and each declined leaf read the whole viewport back.

`309cd34d1` keeps zoomed fills and raster background images (Old Reddit's
vote-arrow sprites) on the GPU canvas instead of reading it back for their CPU
rasters. Canvas edges differ from Quartz only in partially covered pixels.
`VOX_DISABLE_FRACTIONAL_GPU_CANVAS=1` and
`VOX_DISABLE_FRACTIONAL_GPU_CANVAS_IMAGES=1` are same-binary controls.
`bf9c16d11` restores the arrival invalidation described above for content-damage
reuse: one run kept the r/europe header banner missing below the exposed strips.

Measured with `tools/measure_precise_scroll.py` on 2026-11-07 against the live
thread `/r/europe/comments/1xpp08u/`, logged in through the imported cookies,
in a private profile seeded with `--zoom old.reddit.com=1.75`, a 1701×948
document viewport at 2× and 600 precise wheel inputs at 60 Hz after an 8 s
settle. "Top" uses the default 2 px inputs reversing every 60; "sweep" uses
6 px inputs reversing every 300 and reaches the comments. Values are mean
scroll-changing publications per second over the input window; private bundles
built from the shared working tree, pairs alternated on one executable.

| Configuration | Top | Sweep |
| --- | ---: | ---: |
| Complete repaints (`VOX_DISABLE_ZOOMED_SCROLL_RASTER=1`) | 4.4–5.0 | 5.7–8.9 |
| Zoomed reuse, fractional canvas off | 41.5–44.5 | 48.4–50.4 |
| Zoomed reuse, fills on the canvas | – | 54.2–55.2 |
| Zoomed reuse, fills and images on the canvas | 56.0–56.7 | 57.1–59.6 |

With everything enabled the sweep's median publication interval is 16.6 ms and
its p95 21 ms, against 18 ms and 33–35 ms with the canvas change disabled;
input delivery returns to 59–60 Hz. Load averages were 10–21 on 18 cores. Later,
with `mediaanalysisd`, Finder, WindowServer and video decoding busy, the same
configuration measured 47.6–49.5 FPS, complete repaints 3.5–6.4 FPS, and the
sweep at 100% zoom 34.0 FPS.

Final frames of complete-repaint and reuse runs at the same scroll position match
except for live vote counts; the 24 px band under the status bar is white in
every reuse frame and is not document viewport. GPU canvas verification
(`VOX_GPU_CANVAS_VERIFY=2`) shows fills within 4 levels; vote-arrow sprites
differ by up to 29 levels in about seven pixels of their clipped edge column.
The remaining frame cost is shared with unzoomed scrolling at this window size:
restoring the retained rows, copying the frame for AppKit and the per-leaf
text pictures.

### 120 Hz input at page zoom

At 120 Hz precise input (3 px per input, 1,200 inputs, reversing every 600)
the same 175% thread published about 80 frames per second. Main-thread
samples put most of each frame into moving whole frames rather than drawing:

- `1861dc494` stops retaining stationary snapshots of scrolled frames. Every
  frame took a protected copy of its 3402×1896 bitmap (`CGBitmapContextCreateImage`)
  that the next, again-moved frame released; per input, 56.5 → 42.5 M
  instructions and 4.8 → 2.5 ms of system time. Control:
  `VOX_SNAPSHOT_MOVING_STATIONARY_FRAMES=1`.
- `3b381dcb7` rasterizes and uploads only the repainted part of GPU canvas text
  masks (control `VOX_DISABLE_CLIPPED_TEXT_MASKS=1`).
- `109ee2507` fills deferred viewport scrollbars with Quartz instead of a
  second GPU canvas pass and readback (control `VOX_GPU_SCROLLBAR_LEAVES=1`).
- `d58705ab1` splits ring row copies of at least 4 MB across four cores (control
  `VOX_SERIAL_SCROLL_RASTER_COPY=1`).

Same shared bundle (executable `90b49ce3e74d766d…`), three alternating
unprofiled pairs at load average 22–28:

| | Pair 1 | Pair 2 | Pair 3 |
| --- | ---: | ---: | ---: |
| All four controls set | 78.8 | 80.9 | 80.2 |
| Default | 101.9 | 115.4 | 111.2 |

Median publication intervals fall from 11.3–11.5 to 8.6–9.5 ms, p95 from
17.4–17.9 to 12.2–13.4 ms, and input delivery recovers from 82–84 to
104–116 Hz. The parallel copy alone measured 96.0/97.2/97.4 →
103.5/105.4/107.9. Final frames, aligned by their end offsets, differ between
the arms no more than repeated runs of one arm (live votes, thumb fade).
The remaining cost is one synchronous GPU canvas readback per frame (about a
fifth of the frame), leaf drawing, and the parallel ring restore.

### Reaching the 120 Hz input rate

Two more fixes bring the whole thread to the rate the precise input is
delivered at (about 119.5 Hz on this host):

- `7f7bee1f1` maps another shared IOSurface frame, up to six, while Core
  Animation still holds every earlier one. A third of the frames had fallen
  back to a CGImage that Core Animation copied in full (3402×2120) while
  committing. Same executable, three alternating pairs: capped at three
  117.8/107.4/93.6 fps, growing 118.6/117.3/101.4; median intervals 8.38–9.28
  → 8.24–8.35 ms. Control: `VOX_SHARED_FRAME_BUFFERS=3`.
- `fa079487f` lets the glyph raster cache reuse the subreddit header's
  text-shadowed runs (`#header { text-shadow: 1px 1px 4px black }`). Each such
  run rasterizes through a GPU picture with a synchronous Dawn readback, and
  each scrolled frame missed the cache: its key held the f32 rounding residue
  of the composed scroll offset, a strip repaint's backdrop outside the clip
  still held the previous frame (including the run), and larger runs exceeded
  the 32,768-pixel gate. Near the top of the page the hit rate rises from 46%
  to 88% and picture readbacks fall from 61% to 38% of frame drawing.
  Control: `VOX_EXACT_GLYPH_RASTER_KEYS=1`.

Same private build (executable `5b97c9233f44d5c6…`), three alternating
unprofiled pairs over the whole thread at load average 8–10:

| | fps | median ms | p95 ms | max ms | input Hz |
| --- | --- | --- | --- | --- | --- |
| Exact glyph keys | 106.9 / 118.6 / 118.7 | 8.28–8.31 | 11.0–11.2 | 306 / 48 / 49 | 108.7 / 119.0 / 119.1 |
| Default | 117.5 / 119.2 / 119.0 | 8.27–8.33 | 10.8–11.4 | 106 / 46 / 50 | 118.0 / 119.5 / 119.5 |

What remains below the input rate:

- When the trial returns to the top, two or three frames of 46–54 ms still
  rasterize the header runs: runs straddling the viewport's top edge get a
  different clipped raster each frame, so their first visit cannot hit.
- Every ~0.5 s, for ~100 ms, AppKit runs the document's display pass on the
  next vsync instead of right after the input's redraw request. The main
  thread is idle in between, and no timer or Core Animation animation in the
  process coincides with it (`VOX_FRAME_TIMELINE_DIAGNOSTICS=1`, added in
  `b07daae5e`, timestamps wakes, layer updates, CF timers and
  `addAnimation:forKey:` on the probe's clock). It costs about one frame per
  burst, and one run had none at all, so it depends on the environment.
- Occasional 100–130 ms frames elsewhere in the thread did not recur under
  diagnostics; host load from other sessions also moves the input rate itself.

## Live r/europe listing on 2026-11-23

Two fresh launches of the live listing at 100% page zoom on the shared macOS
production build reproduced the lag. Each trial used a 1701×948 document
viewport at 2×, an empty private profile and HTTP cache, and the automatic
script policy (which enabled JavaScript). The host's OS caches were retained.
After the title `Europe` settled for eight seconds, the native input probe
sent 360 precise six-point wheel events at nominal 60 Hz, reversing at event
180. Throughput counts scroll-changing native frame installations during the
entire input window. The Mac's 18 logical CPUs were under substantial
contention, with one-minute load rising from 92.4 to 129.1 across the trials.

| Trial (UTC start) | Scroll FPS | Input Hz | Scroll changes / publications | Median / p95 / max (ms) | Over 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 02:18:51 | 9.48 | 28.12 | 121 / 142 | 73.20 / 245.70 / 550.74 | 90.91% | 669.34 / 25.36 |
| 02:19:20 | 17.04 | 40.79 | 150 / 181 | 34.01 / 126.26 / 268.18 | 90.00% | 393.28 / 197.62 |

Both browsers and the 12 GiB memory guard exited 0. The production receipt was
`20261123-042042-7650db79` with executable SHA-256
`6a541ab7cc0463cbc93bdb76e769b62b1dc131df5256e7275163af3ae2678102` and
`libVoxAVIF.dylib` SHA-256
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
Two earlier attempts using lowercase `europe` missed the case-sensitive title
gate and timed out before input (both browser exits were −9). The external
sample captured rendering stacks, while the simultaneous bounded stall logger
overflowed and the diagnostic driver exited 1. Separate raster and geometry
diagnostics both finished with browser and guard exit 0.

All 45 raster passes logged after input began reused the viewport. The largest
rounded shadow still rasterized a 2738×2120 device-pixel surface even when
Quartz published a strip as narrow as 50 device pixels. Another tall shadow and
the rounded listing background also transferred large surfaces. Sampled
main-thread stacks were dominated by shadow mask preparation, Metal transfers
and texture uploads.

On reused frames the macOS shape bridge now bounds rounded fill and outer
shadow transfers to the repaint clip when it covers at most half the leaf.
It keeps the original standalone surface or compositor tiles, including their
sample count, and computes analytic shadow coverage only for the transfer
rectangle. General blur filters keep their source bounds and sampling grid.
`VOX_DISABLE_SCROLL_SHAPE_REGIONS=1` selects the whole-leaf control on the same
binary, and `VOX_SCROLL_SHAPE_REGION_DIAGNOSTICS=1` logs the cropped and
original dimensions for a separate eligibility run.

An isolated C-backend test drew the 2738×2120 rounded shadow five times per
path, comparing a 2738×100 crop byte for byte. Every crop matched. The full
draws took 183–316 ms and the cropped draws took 13–91 ms with the leaf cache
off. These diagnostic timings are for one shadow in an unoptimized test
executable under contention.

The Chromium geometry test also matched full and cropped pixels for
rectangular and rounded shadows and rounded fills, with fractional shape
coordinates, mixed sample counts and a crop crossing both tile boundaries.
The GG leaf-region, shadow reference and native scroll-ring checks passed.

Reproduce the live input protocol from the repository root with a unique job
directory. Use a new output directory for every process.

```sh
D=$(mktemp -d Build/reddit-europe-scroll.XXXXXX)
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u http_proxy -u https_proxy \
  VOX_TEST_WINDOW=1 sh tools/run_v_tool.sh run_memory_bounded \
  --lock "$D/live.lock" --report "$D/live-guard.json" -- \
  python3 tools/measure_precise_scroll.py --output "$D/run" \
  --url https://old.reddit.com/r/europe/ --width 1701 --height 948 \
  --inputs 360 --delta 6 --reverse-every 180 --require-title Europe \
  --settle-seconds 8 --timeout 55 \
  --network-policy 'Live HTTPS, empty private HTTP cache per process, host OS caches retained'
```

## Live r/europe comment thread on 2026-11-23

The [reported comment thread](https://old.reddit.com/r/europe/comments/1y2nf00/intimidating_vigilantes_posing_as_farright/)
still stalled after the listing change. Two fresh macOS launches at 100% zoom
used a 1701×948 document viewport at 2×, an empty private profile and HTTP cache,
the automatic script policy, and retained OS caches. After eight seconds with
the matching title, `tools/measure_precise_scroll.py` sent 480 precise six-point
wheel events at nominal 60 Hz, reversing after 240. The endpoint measures
scroll-changing native frame installations over the complete input window.

| Trial (UTC start) | Scroll FPS | Input Hz | Scroll changes / publications | Median / p95 / max (ms) | Over 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 03:13:08 | 23.38 | 48.27 | 232 / 236 | 21.29 / 193.08 / 329.04 | 72.41% | 203.08 / 0.33 |
| 03:14:02 | 23.58 | 47.26 | 239 / 244 | 22.18 / 187.08 / 340.53 | 74.06% | 155.85 / 0.35 |

Both completed all 480 inputs, and the browser and guards exited 0. The
one-minute host load was 17.0–21.4 on 18 logical CPUs. The first attempted run
completed in the browser, but its driver exited 1 because production published
a replacement executable before it could verify the input hashes. The valid
trials used receipt `20261123-060034-72fee019`, executable SHA-256
`1a716874d467a366ff3eeeab46e48954c0f93e97bd4245e37a01af9db8e840da`,
and `libVoxAVIF.dylib` SHA-256
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.

The separate raster and stack diagnostic completed 205 viewport-reusing
passes after input began. It logged 379 cropped shape transfers. The tall
comment outlines still dominated the slowest frames, despite damage largely
following the exposed strip. A second geometry diagnostic found unblurred
shadows with zero effective alpha and uniform strokes replaying surfaces as
large as 2650×2120 device pixels. The geometry and sampling drivers and their
guards exited 0.

Chromium replay now returns before native raster setup when an outer box
shadow's effective alpha is zero. Stroked rounded rectangles and visible
unblurred shadows can use the existing cropped transfer path with their
original tile geometry. The same-binary control sets
`VOX_DISABLE_SCROLL_OUTLINE_REGIONS=1` and
`VOX_REPLAY_TRANSPARENT_BOX_SHADOWS=1`, leaving the earlier listing
optimizations active.

Five isolated C-backend trials on the traced 2650×2120 shadow and border
compared a 2650×100 repaint strip byte for byte. All pixels matched. The full
pair took 6.1–7.7 ms. The cropped stroke took 54.5 ms on its first draw and
0.9–3.8 ms on subsequent draws. These times describe two isolated leaves with
the leaf cache disabled, including the cold draw.

The Chromium geometry regression passed with exact pixels for the new
outline modes, including fractional coordinates, rounded underlays, mixed
tile sample counts and a crop spanning tile boundaries. The transparent
shadow test also passed with no native raster context.

### Production replay

Receipt `20261123-061736-d9523769` published the renderer change in executable
`70d03ef7a4fe9572c2397421b6922cf7b1a6bddf2b01fb5b84c4e43e9fa76bc9`
(single C unit, V `-prod`, same AVIF library hash as above). Its source manifest
matches both committed renderer files and its guarded startup and native
wheel smoke check exited 0.

The same-binary live comparison used the protocol above. The first pair ran
control then fixed, and the second reversed that order. All four browser runs
completed 480 wheel events with verified input hashes. Their browser, driver
and 12 GiB guard exits were 0. One-minute host load varied from 54.5 to 76.6
during the cohort, including the lower-load second control.

| Arm (UTC start) | Scroll FPS | Input Hz | Scroll changes / publications | Median / p95 / max (ms) | Over 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Control 03:27:30 | 25.52 | 47.02 | 260 / 265 | 20.10 / 160.30 / 282.66 | 70.77% | 163.40 / 0.33 |
| Fixed 03:27:54 | 46.26 | 55.95 | 396 / 408 | 17.08 / 55.01 / 119.68 | 57.83% | 193.92 / 17.85 |
| Fixed 03:28:17 | 45.53 | 56.65 | 385 / 396 | 17.12 / 52.92 / 128.86 | 58.70% | 157.20 / 18.63 |
| Control 03:28:38 | 25.20 | 48.87 | 247 / 250 | 20.01 / 169.69 / 276.86 | 74.49% | 155.33 / 0.34 |

A separate eligibility run logged 442 cropped stroke transfers whose original
surfaces exceeded 1900×1000 device pixels. The slowest frames still included
bursts of small sidebar shadows and several nested borders. The live
measurements continue to miss the 60 Hz frame budget.

The 3402×1896 document viewport of a fixed nested-outline page matched
pixel for pixel at final scroll offset 2910. The production diagnostic
confirmed cropped strokes during that run. A fixture with a repeating
gradient differed by one channel level in 27,652 pixels inside the gradient.
Two control runs of that same gradient differed by one level in 28,024 pixels
in the same bounds. Both screenshot guards exited 0 after correcting the
repeat helper's string comparison of the numeric offset. The solid fixture
was compared with zero tolerance.
