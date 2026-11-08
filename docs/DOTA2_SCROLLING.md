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

`0f365f91` targets the next 30 ms median budget. The largest saving comes from
matching the RGBA channel order of readable native frame bitmaps before creating
their Quartz images. The previous BGRA image provider made CoreGraphics perform
an expensive conversion for each leaf. The new provider owns its converted
allocation until Quartz releases it. Other destination layouts retain the
previous provider path. Text, bitmap images and rounded boxes also reject
fully clipped leaf surfaces before allocation.

Large axis-aligned rounded boxes transfer only their border pixels through the
GPU readback. Opaque interiors use a direct fill; fractional edges, corners
and strokes retain Graphite's coverage and backdrop blending. The GPU surface
keeps its original extent and coordinate system: translating corners to small
surfaces produced a one-channel difference and was rejected. Packed border
cache entries include the original surface dimensions and compare their actual
backdrop pixels. The shape cache has a 16 MiB pixel budget, with 128 KiB ordinary
entries and 512 KiB packed entries; the image cache remains independently
bounded at 32 MiB. Existing idle cleanup releases both. Unsupported transforms,
compound shapes and oversized patches use the original renderer.

Three alternating matched pairs of 120 moving frames give these medians of
run medians, with identical executable code, page, initial cache, viewport,
scroll positions and 2,355 commands per frame:

| Per moving frame | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 32.059 ms | 23.281 ms | 27.4% |
| Native replay | 29.934 ms | 20.942 ms | 30.0% |
| Retired instructions | 246.637 million | 173.904 million | 29.5% |

Candidate run medians are 21.527, 23.281 and 26.546 ms, all below 30 ms.
Control medians vary from 25.897 to 37.186 ms. The third pair regresses
0.649 ms in wall time; it remains included. The median of run p95 values is
31.442 ms and the largest candidate callback is 166.964 ms, with a collection
recorded in that frame. This meets the median budget without bounding every
frame. Timings include synchronous GPU waits and exclude Cocoa presentation,
vsync and post-frame idle work, consistently with the earlier comparisons.

Focused checks pass 1,840 exact GPU comparisons and 180 exact Quartz compositor
comparisons. These include fractional geometry, large coordinates, partial
viewport clipping, changed border and interior backdrops, idle eviction, MSAA,
1×/2× surfaces, color spaces, bitmap layouts, blend modes and nonrectangular
clips. Cache, solid-fill and compositor unit checks also pass address and
undefined-behavior sanitizers. All four final page viewports are pixel-exact.
Broad verification passes 210 selected test functions in each GC mode, all
100 AST fixtures, the 15 native Skia scenes, the 11 screenshot smoke cases with
their existing rules, eight exact SVG mutation guards and both exact turbulence
references. This covers the additional 72,732,564 instructions saved per moving
frame and resets this endpoint's incremental broad-check count.

Evidence is retained under `Build/dota2-scroll/target30/`: `comparison.json`,
`source-pins.json`, `before/pins-final.json`, `after/pins-final.json`,
`final-focused.log`, `final-native.log`, `final-pixels/`, `validation.json`,
`regression-results.json` and their referenced logs. The provider-object cache
and translated-corner experiments were discarded; their measurements and failed
checks remain separate from the accepted result.

Concurrent repository work rebuilt the application executable during these
checks. Installation preserves that newer executable. A separate matched
120-frame pair with it measures 39.599 → 29.379 ms median (25.8% lower), with
37.056 ms candidate p95. Its scroll trace and 2,355 commands still match. This
additional pair is recorded in `installed-{control,candidate}-profile/`; it is
kept separate from the three-pair attribution above. The staged bundle retains
the last validated executable code and exact renderer libraries, verifies its
signature and headless startup, and reopens the reported URL.

The 20 ms follow-up combines native reuse and raster ownership (`f6209a65`),
conservative viewport culling (`d51cea5d`), and shared sprite-source snapshots
(`a4cd26d1`). Repeated glyph and SVG path draws reuse completed pixels only
when their actual inputs and backdrop match. A separate uploaded-image cache
avoids uploading unchanged decoded bytes when the destination changes. Cache
identity includes the relevant font, geometry, transform, clipping, sampling,
color-profile and source-format settings. Actual source and backdrop bytes are
compared; caller addresses never establish content identity.

Cached sprite results share an owned source snapshot by byte value. Previously,
each sprite draw retained another copy of its entire sheet, evicting otherwise
reusable results. Sources shared by pending requests remain valid across cache
clearing and eviction, and their storage is charged once while retained. The
image-result cache keeps its 32 MiB pixel budget and allows 2,048 entries.
Shape results retain a separate 16 MiB / 512-entry budget, with a 512 KiB
per-entry limit. Path results use 8 MiB / 512 entries. Glyph results use
8 MiB / 512 entries, capped at 256 KiB each. Uploaded images have a separate
32 MiB budget accounting for owned source bytes and estimated GPU texels,
128 entries and an 8 MiB per-entry limit. Idle graphics cleanup releases these
caches before purging the GPU context.

The native bridge transfers owned raster allocations to Quartz instead of
copying their full bitmap again; the image provider releases the allocation
after Quartz releases the image. Surfaces referencing those allocations are
released before transfer. Exact aligned opaque rectangular strokes use four
direct strips, with other strokes retaining the original path. Large rounded
boxes avoid unnecessary interior backdrop copies and readbacks, preserving
corner coverage and the original GPU surface coordinates. ARM64 channel
conversion uses an exact vectorized byte swap, with a scalar fallback.

Before native dispatch, viewport culling reuses the retained leaf ink bounds
with a three-CSS-pixel fringe. It preserves all group markers and disables leaf
culling inside effect and resource-input groups. Unknown, blurred and
nonfinite bounds fall through to normal painting. Large coordinates or scales
also fall through when float32 native geometry could invalidate a float64
visibility decision. Retained commands and hit-test records remain available.
`VOX_DISABLE_CANVAS_CULLING=1` selects the control behavior for diagnosis.

The final comparison uses three alternating matched pairs, retaining every
moving frame: 120 per run, 360 per variant. Both variants use the same newly
built production executable, the same frozen 85-comment page, initial cache,
1,024×768 viewport, interactive 2× scale, 0↔1,260 scroll trace and 2,355 retained
commands per frame. The control uses the native libraries captured at the start
of this follow-up with early culling disabled; the candidate uses the optimized
libraries with culling enabled. Concurrent repository changes receive no
savings credit. JavaScriptCore and production Boehm GC remain enabled, with
one marker thread.

| Per moving frame, median of run medians | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 26.0745 ms | 19.4780 ms | 25.3% |
| Native replay | 23.9675 ms | 17.2635 ms | 28.0% |
| Retired instructions | 173.334 million | 134.560 million | 22.4% |

Candidate run medians are 19.4780, 19.6085 and 19.0615 ms, all below 20 ms.
The median of their p95 values is 28.316 ms and the largest callback is
38.759 ms. This meets the median target; it does not bound every frame to
20 ms. All slow frames and collections remain included. Two collections occur
in the control's second run and none in the candidate runs. The endpoint
includes synchronous GPU waits and excludes Cocoa presentation, vsync and
post-frame idle work. `31c37aad` corrects the profiling tool's endpoint metadata
to state that existing behavior explicitly.

Native verification passes 2,920 exact GPU replay comparisons, 720 exact Quartz
compositor comparisons, 4,800 exact glyph comparisons, 864 exact shape-backdrop
comparisons and all 15 original Skia clip/shadow scenes. Focused cache, stroke,
compositor, glyph and shape checks pass address and undefined-behavior
sanitizers; source-sharing cases also pass a fresh sanitizer check after that
change. The external production Skia library itself is not sanitizer-built.
Mutation, changed addresses, row strides, source interpretations, profile
changes, backdrop changes, bounds, eviction and ownership are covered.

All four final page viewports are pixel-exact against the control: 1× at scroll
0 and 630, and 2× at 630 and 1,260. The 11 default screenshot smoke comparisons
pass, eight exactly and three under their existing allowances. The eight SVG
mutation guards and both turbulence references are exact. Selected V
regression checks cover 216 unique functions in each GC configuration: the
previous 210 plus six culling cases, including the later precision guard.
The root culling helper's aggregate adapter only changes module/import and
namespace qualification; its independent default-namespace check also passes.
All 100 upstream LibJS AST fixtures match exactly. This broad verification
covers the additional 38,773,699 instructions saved per moving frame and resets
the incremental broad-check count for this endpoint.

Evidence is retained privately under `Build/dota2-scroll/target20/`:
`budget-comparison.json`, its six referenced raw run directories,
`accepted-result.json`, `budget-validation.json`, `budget-pixels/`,
`budget-svg/`, `sanitize/`, `regression-results.json`, the regression source
manifest and referenced logs. Earlier candidates that missed 20 ms, rejected
prototypes, an interrupted build and a stale aggregate-module-link failure
remain retained without passing credit. The corrected production build uses a
private output name to avoid shared compiler-temporary collisions. The default
regression recovery refreshes the missing module links and retains the two
already successful groups; the complete no-GC run passes all three groups.

The measured executable and both native libraries are installed through a
separately signed staged bundle and rename, preserving the previous bundle
and existing processes' mapped files. Every file-backed Mach-O section matches
the measured candidate after signing. Deep signature verification and installed
headless startup pass, and the reported live URL is reopened without the test
network gate. `installed-verification.json` records the new running process and
the installed-component checks.

The next follow-up targets another 15% reduction. `4cd28888` compares and copies
tightly packed raster-cache rows as one contiguous block, retaining row-wise
handling for padded inputs and outputs. A changed backdrop is rejected before
comparing a potentially much larger sprite sheet. Owned snapshots, exact byte
comparisons, mutation detection and the cache budgets remain unchanged.

`c847a14d` processes eight opacity-layer pixels at a time with ARM64 NEON.
It preserves the original float32 divisions, separate opacity multiplications,
fused blend and double-precision scaling before ties-to-even quantization.
Empty spans copy the backdrop; opaque spans at unit opacity copy the source.
Other rounding modes and out-of-range opacities retain the original scalar
arithmetic, as do vector tails and non-ARM64 builds. Ink-bound discovery finds
the first and last painted pixels of each row, skipping empty blocks without
walking the painted interior. Any nonzero channel still counts as ink.

Three alternating matched pairs retain all 120 moving frames per run, 360 per
variant. Both executables come from identical generated production C, with the
original versus optimized opacity header as their sole source difference.
The Skia bridge is identical; the Graphite library differs only by the cache
change. This includes concurrent repository work in both variants without
attributing its savings to these fixes. The frozen page, initial cache,
1,024×768 interactive 2× viewport, scroll trace and 2,355 retained commands per
frame match. Production pointer-tracing Boehm GC and one marker thread remain
enabled.

| Per moving frame, median of run medians | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 18.765 ms | 15.143 ms | 19.3% |
| Native replay | 16.461 ms | 13.043 ms | 20.8% |
| Retired instructions | 134.342 million | 126.876 million | 5.6% |

Candidate run medians are 12.7015, 15.2480 and 15.1430 ms; controls are 13.6325,
18.7650 and 21.7245 ms. Each pair improves, with variation in wall time across
runs. The result exceeds the requested 15% median reduction on this fresh
matched control. Candidate p95, taken as the median of run p95 values, is
23.745 ms, and the largest callback is 62.540 ms. All slow frames and all three
collections in each variant remain included. The endpoint still includes
synchronous GPU waits and excludes Cocoa presentation, vsync and idle work.

The opacity oracle checks 134,217,728 source/destination/coverage combinations
at eight opacities, plus arbitrary opacities, rounding modes, unaligned buffers,
tails and in-place output. Another 33,280 exact bounds comparisons cover dense,
sparse and empty regions, padding and all ink channels. Both the vector and
forced scalar paths pass; address and undefined-behavior sanitizers pass.
Cache checks additionally cover packed/strided equivalence, row tails, padding,
and source/backdrop mutations. All 2,920 GPU replay comparisons are exact.

The four matched page viewports remain exact at 1× and 2× scale. The 11 default
screenshot cases pass under their existing rules, and the eight SVG mutation
guards plus both turbulence references are exact. Six focused opacity visuals
pass: five exactly and the rotated SVG case under its existing one-channel
allowance. Native broad checks pass the 15 original Skia scenes, 720 compositor
comparisons, 4,800 glyph comparisons and 864 shape-backdrop comparisons.
Selected V regression checks cover 218 functions in 52 original test files per
GC configuration; all 100 upstream LibJS AST fixtures match exactly. This
covers the additional 7,465,984 retired instructions saved per moving frame
and resets this endpoint's incremental broad-check count.

Evidence is retained under the private, ignored
`Build/dota2-scroll/target15percent/`: `comparison.json` and its six raw runs,
`compiler-source-pins.json`, the matched generated C and native-header
snapshots, `validation.json`, `pixels/`, `visual-validation.json`,
`opacity-visual-validation.json`, `opacity-validation-final.json`,
`regression-composite.json` and their referenced logs. An initial isolated
compiler snapshot omitted a nested instruction-counter header; the retained
generated C was recovered after copying that unchanged header into both
snapshots. The initial broad default-GC batch omitted a new C++ support source:
its layout/opacity groups pass, and only painting/platform are rerun after the
harness repair. The complete no-GC batch passes all four groups. Original
failed attempts remain retained without whole-batch passing credit.

The measured production components are installed through a signed staged
bundle and rename, with the previous bundle preserved. Installed sections,
deep signature verification and headless startup are checked against the
measured candidate, then the live Reddit URL is reopened. The resulting
process and component checks are recorded in `installed-verification.json`.

The next follow-up targets another 10% reduction. Sampling the installed
control identifies final Quartz image publication as a substantial remaining
cost: 147 sampled stacks pass through `native_end_css_filter_layer`, including
protected snapshot reads, copying and pixel-layout conversion.

`24c82057` makes completed effect layers transfer their bitmap context into the published
image's data provider. The last provider release releases the context, keeping
its allocation alive through deferred Quartz drawing. Opacity results likewise
use context-owned storage rather than a separate allocation and snapshot.
For an unfiltered RGBA image going to an 8-bit BGRA bitmap, publication swaps
red and blue in place, using ARM64 NEON with scalar tails. Other destinations
retain their source layout, and filter inputs retain their original layout.
Color-space metadata, interpolation and rendering intent are preserved;
unsupported bitmap formats retain the existing snapshot fallback. The context
is consumed only after its final drawing operation.

Three alternating matched pairs contain all 120 moving frames per run, 360 per
variant. Both signed executables use the same retained production-generated C,
with only these native bitmap-publication changes; both rendering libraries are
byte-identical. Concurrent repository changes are excluded from the measured
difference. The frozen 85-comment page, initial cache, 1,024×768 interactive 2×
viewport, 0–1,260 scroll trace and 2,355 commands per frame match exactly.
JavaScriptCore, production Boehm GC and one marker thread remain enabled. Both
variants receive a four-second settling interval.

| Per moving frame, median of run medians | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 19.116 ms | 14.852 ms | 22.3% |
| Native replay | 16.599 ms | 12.379 ms | 25.4% |
| Retired instructions | 127.642 million | 105.156 million | 17.6% |

Control run medians are 17.7740, 19.1165, 19.3730 ms; candidate
medians are 14.3300, 14.8520, 15.3515 ms. Every pair improves.
The candidate's median run p95 is 24.534 ms and maximum is
75.417 ms. All slow frames and three collections per variant remain included.
The endpoint includes synchronous GPU waits and excludes Cocoa presentation,
vsync and idle work; this is a median improvement rather than a frame-time cap.

The bitmap oracle passes 13,824 exact comparisons across RGBA/BGRA, sRGB,
Display P3 and linear RGB, padded rows, 1×/2× scale, fractional/rotated drawing,
clipping, alpha and blend modes. Another 216 opacity results match exactly.
Metadata, last-owner release, retained snapshot immutability, null input and
monochrome fallback are covered. Address and undefined-behavior sanitizers pass.

All four final Reddit viewports are pixel-exact after both variants receive
three seconds to settle: 1× at scroll 0 and 630, and 2× at 630 and 1,260.
The eleven screenshot smoke comparisons pass under their existing rules;
eight SVG mutation guards and both turbulence references are exact. Six opacity
visuals pass under their existing rules, and six filter/backdrop-filter pages
are byte-identical between control and candidate.

Selected V regression checks cover 218 functions in 52 original test files per
GC configuration, with unchanged aggregate test bodies. The default-GC result
combines retained painting/platform passes, the completed root opacity check,
and a fresh layout pass. A stopped verification run and the later layout
harness's missing links to two new implementation files remain retained without
whole-batch passing credit. Refreshing those links changes no production code
or test assertions. The complete no-GC selection passes, and all 100 upstream
LibJS AST fixtures match exactly. This broad verification covers 22,485,954
saved retired instructions per moving frame, including the 6,464,936 already
covered by the earlier checkpoint and 16,021,018 additional instructions.
The incremental broad-check count resets to zero for this endpoint.

Evidence is retained privately under `Build/dota2-scroll/target10percent/`:
`packed-comparison.json` and its six `isolated-packed-*` run directories,
`accepted-result.json`, `packed-source-pins.json`, the retained generated C and
native source snapshots, `packed-validation.json`, `pixels-settled/`,
`packed-cow-results.json`, `packed-rendering.json`, `filter-pixels.json`,
`packed-broad-gate.json`, the regression input manifest and their logs.
Earlier prototypes below the target, an invalid paint-command trace, the
one-second scrollbar-fade capture mismatch and two SIGTERM-interrupted control
runs remain retained without passing credit. The final timing series uses
byte-identical copies of the signed binaries named `ScrollBench`; both
variants receive the same process-name change and no successful timing run is
retried. Fresh three-second captures verify full viewports without masking
scrollbars or changing rendering behavior.

The measured executable and both native libraries are installed through a
separately signed staged bundle and rename. The previous bundle is preserved,
and existing processes keep their mapped files. All file-backed Mach-O sections
match the measured candidate after signing; deep signature verification and
installed headless startup pass. The live Reddit URL is reopened without the
test network gate. `installed-verification.json` records the new process and
component checks. Concurrent source, staged work and flat development libraries remain preserved.

A concurrent build replaced the executable immediately after the first install.
The final recovery preserves that intervening bundle under
`pre-install-recovery/`, restores the measured components, and repeats signing,
startup and section checks after an eight-second live launch. The initial
receipt remains in `installed-verification-initial.json`; the final receipt is
`installed-verification.json`. Flat development libraries remain untouched.

The next follow-up reduces redundant blending at final document publication.
`07ab3cc2` identifies the fresh sRGB bitmap allocated for each native frame and
lets its enclosing font-compositing canvas claim that destination once, before
any frame pixels are painted. Publishing onto this transparent bitmap uses
`kCGBlendModeCopy`; later and nested canvases retain source-over compositing.
A save/restore pair preserves the parent's graphics state for chrome and later
painting. The frame marker restores its previous value through nested raster
callbacks and exception unwinding. Image formats, color profiles, filter input,
and pixel arithmetic remain unchanged.

A focused 2,048×1,760 bitmap benchmark reduces publication CPU time from a
median 2.696 ms to 1.290 ms. The full-browser improvement is smaller and varies
across runs. Three alternating matched pairs retain all 120 moving frames per
run, 360 per variant, on the same frozen page and cache. Both signed executables
use identical retained production-generated C with only this native publication
change; both rendering libraries are byte-identical. The 1,024×768 interactive
viewport, scroll trace and 2,355 retained commands per frame match. Production
Boehm GC, one marker thread and JavaScriptCore remain enabled; both variants
receive four seconds to settle.

| Per moving frame, median of run medians | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 13.682 ms | 13.386 ms | 2.2% |
| Native replay | 11.618 ms | 11.261 ms | 3.1% |
| Retired instructions | 101.135 million | 93.460 million | 7.6% |

Control run medians are 13.6575, 13.7920, 13.6820 ms; candidate
medians are 11.1625, 13.3860, 13.6045 ms. Every pair improves, with
substantial wall-time variation. The median run p95 is 22.862 ms for control
and 22.913 ms for the candidate, so tail timing does not improve in this series.
The candidate maximum is 69.579 ms. All slow frames and three collections per
variant remain included. The endpoint includes synchronous GPU waits and
excludes Cocoa presentation, vsync and idle work.

The focused native test passes 1,728 exact pixel comparisons across source and
destination color spaces, RGBA/BGRA, transparent/translucent/opaque images,
1×/2× scale, clipping, fractional placement and later translucent painting.
It checks blend-state restoration, foreign-context rejection, one claim per
frame, nested scopes and exception cleanup. Address and undefined-behavior
sanitizers pass. Four full Reddit viewports are exact at 1× and 2×. The eleven
screenshot smoke cases pass under their existing rules; eight SVG mutation
guards and both turbulence references are exact. Six opacity visuals pass
under their existing rules, and six filter/backdrop-filter pages match the
control byte for byte.

The additional 7,675,256.5 retired instructions saved per moving frame cross
the broad-check gate. The current selection contains 219 functions in 52 test
files per GC configuration: layout 44, painting 88, platform 85 and root opacity
2. Both GC configurations and all 100 exact upstream LibJS AST fixtures pass.
A stale aggregate-input guard first stops before running tests because a
concurrent debug-guide test changed and gained a second case. The refreshed
aggregate copies that current test body without editing assertions; all other
selected bodies remain pinned. The root opacity test uses the same original
body in an isolated main package instead of letting a symlink pull in the
whole browser. The incremental broad-check count resets to zero.

Evidence is retained privately under `Build/dota2-scroll/copy-publication/`:
`comparison.json` and its referenced raw runs, `accepted-result.json`,
`compiler-source-pins.json`, `focused-complete.json`, `validation.json`,
`pixels-settled/`, `rendering.json`, `broad-gate.json`, the refreshed regression
manifest, and their logs. An initial candidate launch hits the pre-existing
cache-header JSON decoder panic before scrolling. The whole incomplete pair
is retried once; its successful unpaired control and failed candidate remain
retained. All completed matched pairs are kept, with no timing-based retries.

Earlier prototypes remain under `Build/dota2-scroll/followup/`. An opaque RGBX
image declaration preserved pixels but increased instructions and wall time;
it was reverted. The accepted change keeps the premultiplied format and avoids
blending only where the destination is known to be empty. Rejected prototypes
receive no optimization or broad-cadence credit.

The measured executable and native libraries are installed through a signed
staged bundle and rename, preserving the prior bundle and existing mapped
files. Installed file-backed Mach-O sections match the measured candidate;
deep signature verification and headless startup pass. The Reddit URL is
reopened without test environment overrides. `installed-verification.json`
records the running process and checks. Concurrent source, staged work and flat
development libraries remain preserved.

The next follow-up, `9a83198c`, fuses document format conversion and publication.
The claimed private frame remains empty with its initial clip and graphics state
while the document paints into its separate RGBA canvas. When dimensions, color
spaces, bitmap formats and device alignment match, one pass copies RGBA into the
BGRA frame. This removes the intermediate root-layer image and the subsequent
Quartz copy. Source pixels remain unchanged. Filters and unsupported formats or
placements retain the previous image path; the final Core Animation frame
snapshot remains unchanged.

An isolated 2,048×1,760 publication probe preserves pixels and reduces median CPU
time from 2.674 to 2.387 ms. Three alternating full-browser pairs compare the
preceding accepted build against this change alone, using the same retained
production-generated C and 121 pinned link inputs. Both rendering libraries are
byte-identical. The frozen Reddit input, cache, 1,024×768 viewport, 0↔1,260 CSS
pixel trace and 2,355 commands per frame match. Window geometry receipts confirm
2× backing scale for all six runs. JavaScriptCore and normal Boehm GC with one
marker remain enabled, with four seconds to settle.

| Per moving frame, median of run medians | Control | Optimized | Reduction |
| --- | ---: | ---: | ---: |
| Wheel dispatch through native replay | 14.132 ms | 13.768 ms | 2.6% |
| Native replay | 12.115 ms | 11.6645 ms | 3.7% |
| Retired instructions | 94.515346 million | 88.985185 million | 5.9% |

Control medians are 14.6455, 14.1320 and 14.1115 ms; candidate medians are
14.0345, 13.7680 and 12.4695 ms. Every pair improves. All 120 moving frames per
run remain included, 360 per variant, with no rejected or retried pair. The
median run p95 improves from 25.843 to 24.701 ms; maximums are 71.034 and
70.149 ms. Both variants include three collections. These are matched-run
comparisons; absolute timing varies between sessions. The endpoint includes
synchronous GPU waits and excludes Cocoa presentation, vsync and idle work.

The new native test passes 846 exact comparisons, including 281 guarded
fallbacks, vector tails, padded source rows, alpha states, aligned fractional
backing scales, color conversion and later translucent paint. It verifies
immutable snapshots of both source and destination, rejects unclaimed and
foreign destinations, and checks non-finite geometry. The existing 1,728-case
publication oracle and 13,824-case bitmap ownership oracle, including 216
opacity results, also pass. All three tests pass address and undefined-behavior
sanitizers. An initial standalone ownership-test link omitted CoreFoundation;
the corrected command passes without rerunning the successful tests.

Four complete Reddit viewports match the control exactly at 1× and 2×. Eleven
screenshot smoke cases and six opacity visuals pass under existing rules; eight
SVG mutation guards and both turbulence references are exact. Six filter and
backdrop-filter pages match the control byte for byte. The additional 5,530,161
instructions saved per moving frame reach the broad-check gate: 219 selected V
functions across 52 source test files pass in each GC configuration, and all
100 upstream AST fixtures compare exactly. The incremental savings count resets
to zero after this broad verification.

Evidence is retained privately under `Build/dota2-scroll/clear-root/`:
`comparison.json`, raw `fused-*` runs and their `window-scale.json` receipts,
`accepted-result.json`, `compiler-source-pins.json`, `focused-complete.json`,
`pixels-settled/`, `validation.json`, `rendering.json`, `broad-gate.json`, and
associated test logs. The signed measured components are installed through a
staged bundle and rename, preserving the previous app and flat development
libraries. Installed file-backed Mach-O sections match the measured candidate;
deep signature verification and headless startup pass. The Reddit URL is reopened
without test overrides. `installed-verification.json` records the live process
and installation checks.

## 10 man boots thread: clipped root image transfers (2026-11-08)

For the [newly reported thread](https://old.reddit.com/r/DotA2/comments/1xqhd8i/am_i_the_only_one_who_is_sick_of_10_man_boots_dota/),
`8bc8743a2` keeps the original root image raster dimensions, matrix, tile
ownership and MSAA selection, while uploading and reading only the native
clip and scroll damage. A typical exposed image strip transfers 16,276 pixels
instead of a 1,344,000-pixel tile. Partial failures retain the original full
replay fallback. No rendering tolerance or reference changes.

Two alternating control/candidate pairs use one pinned completed production
executable and one pinned native candidate bridge. The control sets
`VOX_DISABLE_ROOT_IMAGE_REGION=1`; the candidate **omits** that variable.
Native switches test presence, so setting it to an empty string still selects
the control. The corrected cohort retains both earlier control-only cohorts
without candidate credit.

The frozen workload retains 152 original responses at their HTTPS origins,
disables author script execution, and denies external network access. Unrelated
default bookmark favicon CONNECTs are denied in both arms; document resources
must be archived. Each fresh process has an empty private profile/cache, seeds
only Reddit's saved 125% zoom, and keeps OS filesystem/shader caches. Its native
document viewport is 1400×900 view pixels, excluding 112 pixels of chrome, at
2× backing scale. Input is 900 precise native wheel events, nominally 120 Hz,
delta 3, reversing every 300 events, after 12 seconds of title-checked settling.
The observed root view offsets span 0–1950 pixels (0–1560 CSS pixels at this zoom).

| Trial | Scroll updates/s | Median / p95 / maximum interval, ms | Intervals over 16.67 ms | Inputs / all publications / counted scroll changes |
| --- | ---: | --- | ---: | --- |
| Frozen control 1 | 112.14 | 8.35 / 14.73 / 24.62 | 3.03% | 900 / 895 / 892 |
| Frozen candidate 1 | 114.84 | 8.37 / 12.36 / 20.05 | 0.78% | 900 / 905 / 892 |
| Frozen control 2 | 109.93 | 8.38 / 16.24 / 26.94 | 4.03% | 900 / 904 / 893 |
| Frozen candidate 2 | 117.07 | 8.34 / 11.65 / 19.63 | 0.22% | 900 / 901 / 895 |
| Installed live 1 | 112.55 | 8.38 / 12.18 / 168.23 | 0.57% | 900 / 891 / 884 |
| Installed live 2 | 111.72 | 8.35 / 12.58 / 172.02 | 1.02% | 900 / 893 / 886 |

| Trial | Actual input Hz | Entire input window, s | Leading / trailing counted-scroll gap, ms |
| --- | ---: | ---: | --- |
| Frozen control 1 | 113.02 | 7.954 | 53.94 / 0.21 |
| Frozen candidate 1 | 115.75 | 7.767 | 38.67 / 0.18 |
| Frozen control 2 | 110.66 | 8.124 | 94.45 / 0.22 |
| Frozen candidate 2 | 117.59 | 7.645 | 41.58 / 0.18 |
| Installed live 1 | 114.46 | 7.854 | 36.15 / 0.20 |
| Installed live 2 | 113.36 | 7.931 | 37.73 / 0.25 |

The endpoint is completed native frame installation after outer view painting,
stamped with the rendered input. Animation-only publications do not count as
scroll changes. Throughput includes the entire input window and boundary gaps;
it does not measure physical display scanout. Host load varied on this 18-core
machine and remains in the receipt. No retired-instruction saving or Brave
comparison is claimed, so the instruction-saving broad-check cadence is unchanged.

The completed shared production bundle was checked independently, without an
injected candidate renderer. A separate diagnostic confirms the new path runs
on the live URL. The two live trials use automatic page-script policy and the
existing SOCKS5h route, with fresh private profiles/caches. The executable hash
is `c6b62c77913a18117f269fda73097c703b64e3d789b1ffe607f07c3f09efae95`;
its build receipt predates the feature commit and includes dirty native source.
This live validation gives no additional attribution credit to intervening
shared-checkout changes.

**Steady 60 fps remains open.** Average native throughput exceeds 60, and p95
intervals meet its budget, but the rare 168–172 ms live gaps remain. Separate
sampling observes synchronous JavaScript task layout in wheel handling, GPU
waits and raster row copies. Sampling changes timing and does not identify the
cause of every long live frame. Those stalls are not reported as fixed.

Both full 1400×900 document captures, at view offsets 0 and 850, are pixel-exact
against full replay. The scrolled capture advances in 3-pixel steps after its
initial viewport settles. Native checks pass 1,728 complete-buffer comparisons
covering 1×/2× density, 100%/125%/175% zoom, nearest/linear sampling, mixed MSAA,
fractional and elliptical clips, scroll offsets, RGBA and planar YUV formats,
plus 42 independent root-boundary cases. Both normal and ASan/UBSan builds pass;
runtime checks use 3 GiB guards. Strict bundle signing and fresh headless startup
also pass. Reproduce the focused checks with:

```sh
python3 tools/test_root_image_regions.py --output Build/reddit-root-images
python3 tools/test_root_image_regions.py --sanitize --output Build/reddit-root-images-asan
```

The [durable receipt](performance/reddit-boots-scroll-20261108.json) records all
trial commands, exact metrics, build/resource hashes, host loads, exits,
rejected attempts and the private local raw-evidence archive identity. Per-job
`Build/reddit-boots-scroll-20261108/` output is removed after recording.

## November 8: identify the long frames

The follow-up investigation uses a new opt-in, frame-correlated stack sampler
(`tools/measure_precise_scroll.py --sample-stalls-ms 25`). It samples the actual
main thread only while a native display callback exceeds its threshold, resumes
that thread before resolving symbols, and records each image's actual load base.
The driver marks these runs diagnostic. Their timings earn no performance credit.

The live baseline identifies two avoidable paths. A 251.388 ms callback has
44 of 46 samples in synchronous Metal shader compilation, reached through
Graphite's `Recorder.snap()` during a canvas flush. A separate 235.443 ms callback
includes synchronous wheel hit-test layout followed by
`poll_javascript_tasks -> relayout`, then extensive native repaint and GPU
readback work. Queued wheels ran before frame preparation began, so pending
script effects bypassed the existing layout coalescing boundary.

Commit `1ebbfe1bc` starts frame preparation before queued input replay. The new
regression exercises accepted and cancelled wheels, synchronous geometry queries,
a changed overflow target, one layout pass, and final paint adoption. It passes.
The seven-case wheel executable also reports four failures in unchanged older
cases: they expect fractional root offsets that the current physical-pixel
snapping code rounds. Those cases do not call the new preparation helper. Their
assertions and geometry were preserved; the complete wheel suite is not passing.

Commit `38784c9f0` prepares bounded image/mask pipeline variants during the first
canvas render and preserves compiled Metal pipelines across ordinary idle
cleanup. Cleanup still frees upload caches, recorder caches and raster surfaces;
explicit full retirement and unused-memory purge still destroy the context.
Preparation uses 64 temporary 32-by-32 targets, with a 1 MiB recorder budget.
This moves compilation into the first canvas render and retains compiled
pipeline/driver state while idle. It cannot preclude compilation of every future
shader or a cold restart after full retirement.

The initial warm-up attempt still stalls for 239.536 ms. A subsequent attempt
needs additional transformed, analytically clipped mask variants. Both attempts
are retained. The final diagnostic observes no Metal compilation in its sampled
slow callbacks, but still observes a long layout/repaint callback. This supports
the specific pipeline path, not a claim that scrolling is stall-free.

The fresh combined diagnostic narrows the remaining stall to a single
190.163 ms callback: 14 snapshots are in synchronous DOM layout and 19 in
native replay. None is in the redundant shell relayout or Metal compilation.
Eliminating those two avoidable paths has not made all remaining layout and
paint work fit the 16.67 ms budget.

Optimized and ASan/UBSan focused checks pass with exact pixels, no additional
pipeline compilation for their scrolling-mask case, idle raster release,
compiled-pipeline reuse and full retirement. The existing native canvas checks
pass, including 36 nested-layer scenes with zero error. Both complete frozen
1400-by-900 Reddit captures, at scroll offsets 0 and 850, match the control with
zero differing pixels. The 53 precise-scroll/probe tests and the real nested
main-thread sampler check pass. Commands, source/library identities, actual
exits, guard receipts, failures and sampled stacks are retained in
[the stall report](performance/reddit-boots-stalls-20261108.json).

The first alternating live timing attempt changes shared executable between
pairs: each individual run and pair stays pinned, but there is only one pair
per executable. Pair 2 regresses. Host load exceeds 100 on an 18-CPU host during
much of the attempt, and live page bytes are not frozen. Pooling those pairs or
attributing a throughput improvement to the change would be invalid.

Two further unprofiled trials use the same newer production executable
`135bdc55…` and the final native candidate `31b5a71a…`. Its frozen C contains the
queued-input preparation change. Both trials complete all 1,800 inputs:

| Trial | Scroll publications/s | Median interval | p95 | Maximum | Over 16.67 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Combined 1 | 93.60 | 9.527 ms | 16.913 ms | 217.595 ms | 5.708% |
| Combined 2 | 99.65 | 9.105 ms | 15.711 ms | 208.264 ms | 3.462% |

These are native frame publications, not physical display scanout. Their entire
first-to-last input window is the throughput denominator; boundary gaps, input
cadence, counts and host load remain in the report. **The steady 60 fps goal is
still open.** Mean throughput above 60 does not excuse these stalls. The native
candidate is explicitly injected for these checks; default native publication
is pending the shared production worker. No separate production build was queued
and no bundle was copied or replaced for the investigation.

## November 8: timestamp reuse, policy reads and idle device teardown

The next investigation fixes three more blocking paths on the same thread.
Reddit periodically replaces its live timestamp Text nodes. The native
equal-text layout shortcut rejected those updates because an unrelated table's
copied computed-property store had no tracked revision. Commit `933a78eb5`
gives each copied table store its own mutation token. Equal replacements keep
fresh DOM Text identities and mutation behavior while reusing geometry; real
text and style changes still invalidate it.

When layout did rebuild, it forked glyph-run records whose allocation addresses
formed the raster keys. One diagnostic marked 611 unchanged commands dirty and
produced 36 damage rectangles. Commit `5f12d69e2` keys published, clean glyph
runs by their exact replay contents and conservative font ownership. Dirty or
malformed runs retain pointer keys. Commit `0bc9a628d` admits bounded batches of
up to 64 rectangles, and `c27521c32` stages large readbacks together within a
64 MiB limit. The early isolated batch/readback cohorts retain regressions and
mixed results; they earn no throughput improvement credit.

Sampling only view callbacks missed another pause between frames. Commit
`04881ebe4` extends the bounded diagnostic sampler to late native input timers.
The long diagnostic records three delayed-input episodes, with maximum timer
lateness of 107.545 ms. Their sampled stacks destroy Dawn's device and join its
worker pool during ordinary idle cleanup, even while the Metal canvas backend
is scrolling. Commit `34314a33e` releases regional raster and purgeable GPU
resources while retaining the device and bounded pipeline caches. Explicit
retirement still destroys the context. The diagnostic marker in `f55a7ebc2`
confirms idle release leaves zero purgeable bytes.

Separate 56–60 ms callbacks wait in the adblock engine mutex. A cached
`BrowserApp.background_image` lookup still queried the enabled flag through
that mutex, which can be held during worker/filter operations. Commit
`5b588f5a8` makes this scalar read atomic; engine operations and changes retain
their existing mutex. Its regression verifies reads while the outer engine
lock remains owned. Commit `3c677fb5d` makes the old recursive-lock behavior
fail promptly instead of hanging the test.

The completed production executable is
`843893a4a6f9e8f235b9fe36cb4184e3df6c038dbf41370f219dcecdc1581bd2`.
Receipt `20261108-072002-e3db71fa` records single-C-unit compilation with
`-O2 -flto`, the default JavaScriptCore backend and GG adapters. The sealed
input metadata and compiled scalar getter confirm these fixes are present.
No additional production build was queued. All checks launch fresh processes;
an existing Vox process continues to use its older mapped executable.

The final installed-bundle diagnostic completes 5,400 precise wheel events. It
executes timestamp geometry reuse and two Dawn idle raster releases during
input, with zero delayed-input gap samples. Its seven slow-callback snapshots
show GPU completion, pixel readback/decompression, SVG raster and buffer work;
none shows the earlier adblock mutex or Dawn worker-pool destruction. This is
diagnostic path evidence, not unprofiled timing acceptance.

Four long unprofiled runs use that installed bundle with no candidate renderer
override or diagnostic environment. The workload remains a title-checked
12-second settle, 1400×900 document viewport, 2× backing scale, 125% saved zoom,
automatic scripts, and nominal 120 Hz native precise wheel input with delta 3,
reversing every 300 events. Each launch gets an empty private profile/cache;
OS caches remain. Live runs use the existing SOCKS5h route. Frozen runs replay
the same 152 original-origin responses and deny external network access.

| Trial | Scroll publications/s | Median / p95 / maximum interval, ms | Over 16.67 ms | Inputs / all publications / counted scroll changes |
| --- | ---: | --- | ---: | --- |
| Final live 1 | 118.549 | 8.339 / 9.871 / 24.094 | 0.0927% | 5400 / 5401 / 5393 |
| Final frozen 1 | 117.665 | 8.335 / 10.438 / 22.507 | 0.8568% | 5400 / 5411 / 5369 |
| Final live 2 | 118.455 | 8.328 / 10.035 / 26.614 | 0.5585% | 5400 / 5404 / 5372 |
| Final frozen 2* | 118.306 | 8.333 / 10.008 / 43.965 | 0.3530% | 5400 / 5407 / 5382 |

| Trial | Actual input Hz | Entire input window, s | Leading / trailing counted-scroll gap, ms |
| --- | ---: | ---: | --- |
| Final live 1 | 118.681 | 45.492 | 32.443 / 0.159 |
| Final frozen 1 | 118.322 | 45.630 | 31.115 / 0.173 |
| Final live 2 | 119.050 | 45.351 | 25.903 / 4.208 |
| Final frozen 2* | 118.680 | 45.492 | 29.195 / 4.094 |

*The second frozen run overlaps a later readback diagnostic for 19.294 seconds
because that diagnostic was started before its controller finished. Both runs
completed before interruption was attempted; no signal was sent. Both results
are retained and neither supplies timing-gain acceptance. Separate clean
alternating cohorts follow. These final live/frozen checks validate the combined
production code; they do not isolate a gain from each individual change or from
unrelated shared-checkout changes.

The remaining GPU samples motivated two existing transport switches, tested
without changing defaults. In two clean alternating frozen pairs, forcing blit
readback for small regions regresses both candidate throughput results
(118.037 versus 119.050, then 114.071 versus 119.469 publications/s), with more
deadline misses. Linear textures give mixed results with widely varying
controls; host load reaches 121 on this 18-CPU host. Neither experiment earns
optimization credit, and both remain opt-in. The report retains all earlier
cohorts, failed attempts, timings and host loads.

**Steady 60 Hz remains open.** The reproduced long blocking paths no longer
appear in the final diagnostic, but occasional GPU/readback intervals still
exceed 16.67 ms, including the leading publication gaps. Native publication is
not physical display scanout, and mean throughput does not establish a
zero-stall guarantee. No retired-instruction saving or Brave comparison is
claimed; the existing instruction-saving broad-check cadence is unchanged.

Focused glyph and table-revision/native-layout tests execute successfully.
Native damage-batch, readback-ordering/allocation-fallback and Dawn
idle-retention tests pass optimized and ASan/UBSan checks. The 54 precise-scroll
and native sampler checks pass, as do the adblock snapshot/engine checks and
fresh production headless smoke. The two full frozen 1400×900 document captures,
at scroll offsets 0 and 850, remain pixel-exact against the unchanged earlier
controls: zero differing pixels and zero maximum channel error. The previously
reported four unchanged legacy wheel assertions remain outside this passing
focused set; the complete wheel suite is not claimed to pass.

The [follow-up receipt](performance/reddit-boots-stalls-next-20261108.json)
records all 24 unprofiled trials and 14 diagnostics, actual commands and exits,
build/resource identities, interval and boundary statistics, contention,
correctness checks, rejected attempts and the private raw archive identity.
The per-job `Build/reddit-stalls-next-20261108/` directory is removed after
archiving; raw authenticated page responses remain private and outside Git.
