# Dota2 comment-page scrolling

Scrolling [the reported old Reddit comment page](https://old.reddit.com/r/DotA2/comments/1x78he9/was_it_worth_it_no_i_am_happy_no/)
spent most of its frame time in native paint replay. Small opacity groups used
their ancestor's large clip, making transparency compositing and the Chromium
renderer's opacity-ink scans process viewport-sized regions, even for controls
below the viewport.

`fb37e5d5` bounds eligible opacity groups by the union of their transformed
painted contents. Text uses retained glyph ink, strokes retain their extent,
and bitmap backgrounds retain a source-space snapping fringe. Background
gradients use their paint clip rather than their positioning area. Nested
groups and viewport scrolling preserve those bounds. Filters, shadows,
unsupported operations and non-normal blending retain their original bounds.
The pass changes the published replay commands without modifying retained
layer payloads, leaf commands, layout or hit-test plans.

Three alternating pairs of 120 wheel events on the retained page produced
these medians of run medians:

| Per moving frame | Control | Bounds enabled | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 79.437 ms | 64.883 ms | 18.3% |
| Native replay | 76.882 ms | 62.511 ms | 18.7% |
| Retired instructions | 487.221 million | 351.554 million | 27.8% |

Every run uses the same 1024×768 viewport, initial resource cache and native
rendering libraries. All 120 events move the viewport, tracing 0–1260 CSS
pixels and back, with the same 2,355 paint commands. The comparison enforces
identical scroll positions and command counts. Slow frames and collections
remain in the results. The machine was running other compilation jobs, so
these wall times describe this workload under that load.

The control is a separately signed copy of the same production executable
whose content-bounds function returns immediately. Mach-O section comparison
confirms that only its first four instruction bytes differ; every other
file-backed section is identical. The installed executable runs the full pass.
The saved HTML retains the page's 85 comments and original base URL; its 20
scripts are removed to keep DOM content stable. JavaScriptCore remains enabled,
and the process-local network guard prevents remote fetches. These timings
cover native wheel dispatch, preparation and replay, including synchronous
renderer waits. Cocoa presentation, display-clock waits and post-frame idle
maintenance are outside the measured scope.

Four matched document viewports are pixel-exact: the top and a scrolled
position at 1×, and two scrolled positions at 2×. Seven focused content-bound
tests are included in the 210 selected test functions passing in each of the
default-GC and no-GC configurations: 10 layout, 13 painting and 26 platform
test files. The aggregate source manifest and retained recovery logs distinguish
successful checks from the initial harness failures. All 100 upstream LibJS
AST fixtures and 15 native Skia pixel scenes pass. Signed production startup
also passes.

The 11 default screenshot comparisons pass with their existing rules: eight
are exact and three use the existing allowances. All eight SVG mutation guards
are exact, as is the public Brave opacity-group fixture. Of seven additional
opacity reftests, four are exact and the rotated SVG case passes its existing
one-channel allowance. Two retain existing upstream-reference mismatches:
`scrollable-contains-boxes-with-hidden-overflow-and-opacity` (1,186 pixels) and
`abspos-escaping-overflow-clip-inside-opacity` (10,000 pixels). Both their input
and reference viewports are pixel-identical between the matched control and
changed browser.
The multiline match link in the live opacity-change fixture was followed
directly after the shell comparison script could not parse it; that comparison
is exact. No comparison limits were changed.

The measured saving is 135,667,014.5 instructions per moving frame, exceeding
the repository's 5,000,000-instruction broad-check threshold for this endpoint.
This is one scrolling fix; no other renderer change receives credit from the
matched comparison. That broad verification covers this fix; additional
instruction savings after this checkpoint are zero for this endpoint.

Evidence is retained in the private, ignored `Build/dota2-scroll/` directory:
`final-comparison.json`, `final-{before,after}-{1,2,3}/`,
`final-control-sections.json`, `final-pixels/`, `regression-composite.json`,
`regression/manifest.json`, and the build/startup logs. The interrupted build
was recovered using its unchanged generated C and original production compiler
response file; `build-final-recovery.json` records their hashes and exit zero.
Unrelated working-tree edits were preserved.

To profile the live page with the installed browser:

```sh
python3 tools/measure_browser_scroll.py \
  --url https://old.reddit.com/r/DotA2/comments/1x78he9/was_it_worth_it_no_i_am_happy_no/ \
  --env VOX_TEST_WINDOW=1 --frames 120 \
  --output Build/dota2-scroll-new-run
```

`51185e83`, the follow-up for the 50 ms target, caches completed Graphite image and small
shape draws. The profile showed repeated texture uploads, recorder creation
and synchronous GPU readbacks. A hit now copies the previously rendered pixels.
It requires identical source bytes, input backdrop, dimensions, transforms,
clips, opacity, sampling, color profile and shape paint settings. Sources are
copied into owned snapshots and compared by value, so mutable canvas/video
buffers, animation frames and recycled addresses cannot supply stale pixels.
Row padding and source addresses do not establish identity.

Image and shape caches have independent LRU budgets of 32 MiB and 8 MiB of
pixel storage, each with at most 512 entries. Images larger than the 8 MiB
per-entry limit bypass caching. Shapes exceeding 128 KiB bypass it, preventing
large changing backgrounds from displacing reusable small controls. The native
idle graphics cleanup clears both caches. Only successful GPU draws enter them.

Three alternating matched pairs, each containing all 120 moving frames, give:

| Per moving frame | Uncached control | Cached replay | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay, median | 67.809 ms | 41.255 ms | 39.2% |
| Native replay, median | 65.076 ms | 37.865 ms | 41.8% |
| Retired instructions, median | 314.733 million | 248.363 million | 21.1% |

The candidate run medians are 40.307, 41.261 and 41.255 ms. This meets the
50 ms target for the same median metric as the initial report. It does not
bound every frame: the median of the three run p95 values is 54.141 ms, and
the largest observed callback is 129.909 ms. All frames and collections remain
included. In the preceding diagnostic run, two collections each added roughly
80 ms to preparation; some frames near the top also exceeded 50 ms in replay.

Both variants use the same existing production executable and Skia bridge;
only the isolated Graphite library differs. This fresh comparison includes
intervening repository changes in both variants and attributes no savings from
those changes to the cache. It retains the same page, cache, viewport, scroll
trace and 2,355 commands per frame described above. Native libraries were
rebuilt with the production build commands. The benchmark tool's older endpoint
metadata says GPU execution is excluded; synchronous GPU waits are in fact
inside the measured replay, as confirmed by the sampled stacks.

The focused cache checks cover mutation at an unchanged address, replacement
addresses, backdrop changes, geometry, color profiles, row strides, odd-sized
YUV planes, LRU eviction, byte limits and idle clearing. They pass with address
and undefined-behavior sanitizers and with compiler warnings treated as errors.
The actual cached and uncached GPU backends also produce identical pixels in
792 comparisons, including image mutations, strokes, underlays, clip-outs,
MSAA and 1×/2× rasterization.

The four matched page viewports remain pixel-exact. Broad verification passes
all 210 selected test functions in each GC configuration, all 100 exact AST
fixtures and all 15 native Skia scenes. The 11 screenshot smoke comparisons
pass with their existing rules, and all eight SVG mutation guards are exact.
This covers the additional 66,370,890 instructions saved per moving frame and
resets the incremental broad-check count for this endpoint. Signed production
startup passes. The measured native libraries are installed into the existing
production bundle while preserving its executable code, and the reported URL
is reopened.

Run the focused cache checks with `sh tools/test_native_graphite_cache.sh`.
Passing uncached and cached Graphite library paths as its two arguments also
runs the GPU comparisons. No browser window is needed for either check.

Follow-up evidence is under `Build/dota2-scroll/target50-*`, particularly
`target50-v3-comparison.json`, the six referenced successful run directories,
`target50-source-pins.json`, `target50-raster-replay.log`, and the validation
logs. The first candidate comparison omitted frame 42 from its log and was
rejected completely; its replacement reruns all 120 frames. The earlier shared
image/shape cache policy regressed and was discarded. Neither diagnostic run
receives passing comparison credit.
Initial visual-harness attempts failed on script permissions and compiler
selection, and the first broad batch picked up the development compiler through
`VEXE`. The corrected runs use the repository's `-old-compiler` wrapper. The
initial default-GC platform result and the successful two-file recovery compose
the default-GC pass; the first complete no-GC recovery passes all three files.
Failed harness/compiler attempts remain in the logs without passing credit.
