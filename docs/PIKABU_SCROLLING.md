# Pikabu scrolling profile

The 60 fps goal remains open. The sections below retain historical workloads;
use the [precise-input protocol](#precise-input-measurement-protocol) for new
scrolling claims rather than the synthetic callback profiler.

Launch a fresh process when checking a rebuilt bundle:
`VOX_TEST_WINDOW=1 open -n Build/v/Vox.app --args https://pikabu.ru`.
Ordinary `open` can reuse a process that still maps the previous executable and
native libraries, even though their paths point into the rebuilt bundle. The
precise-input tool spawns the executable directly for each trial.

Scrolling `https://pikabu.ru/` was dominated by the collector, not by painting.
The page keeps about 75 infinite CSS animations running (skeleton shimmers on
tag and story placeholders, a progress spinner), so every frame restyled those
elements and re-recorded the complete display list. Each frame allocated about
9.6 MB, and a per-frame leak pinned roughly 1.4 MB of it, so the heap grew past
1 GB while one-marker collections of 150–400 ms ran every few frames.

## Causes and changes

- **Closure leak** (`cdc37ba2`). `viewport_rederive_scroll_state()` passed
  closures capturing its `mut result` parameter. An immutable capture of a `mut`
  struct parameter copies the whole `DocumentLayoutResult` into the closure
  context, and the compatibility compiler never frees closures, so every scroll
  or animation frame retained that frame's display list, visual-context tree and
  scroll state through the closure runtime's global live map. The walks now
  index the frames directly. Collections previously reclaimed about 4 MB each
  while the in-use pointer heap grew by about 10 MB per cycle; it is now flat.
- **Retained plans** (`738a27e5`). Viewport scrolling keeps the hit-test plan,
  as upstream keeps the display list. Compositor-only transform samples request
  a document-level re-record instead of invalidating the box, its containing
  block and the hit-test plan; paint and hit-test steps are rebuilt only when
  opacity or transform invertibility changes membership. Wheel coordinate
  queries and visual-context rebuilds share one index of the immutable paint
  tree instead of mapping every box several times per event.
- **Recording allocations** (`d5c0d9ad`). Visual contexts are flattened once
  per node from their parent instead of walking every ancestor chain with a new
  matrix map. Matrix, rect-mapping and backface helpers no longer allocate. The
  shell returns the command vector it adopted once it holds a newer one, and the
  next recording reuses that capacity; a vector that may still be read is never
  overwritten.
- **Off-screen animations** (`3dc7847a`). Following upstream's
  `KeyframeEffect::can_skip_per_frame_style_update()` INTEROP rule, infinite
  transform-only animations of pseudo-elements are not sampled while an ancestor
  clip keeps them outside the viewport. The check repeats every rendering
  update, so sampling resumes as soon as the clip can become visible.
- **Presentation** (`da5711de`). The window is tagged sRGB, matching the frame
  bitmaps, so the window server color-matches on the GPU. Core Animation
  previously converted each complete frame on the CPU during commit, about a
  fifth of main-thread time.
- **Profiler** (`b2edcc10`). The scroll profile dispatched its wheel inside the
  frame's navigation-work scope, deferring it to the next frame untimed. Wheels
  now enter like physical input, and each frame reports allocated bytes,
  collections and heap size.

## Measurements

Three alternating pairs of 200-frame sweeps of the archived page
(`Build/pikabu-instructions-cache-final`) with the offline network guard, a
1024×768 document viewport at Retina scale, production C `-O2`, Boehm with one
marker and page JavaScript enabled. The baseline is the same source with only
the profiler fix. Values are medians of the three runs.

| Per frame | Baseline | Changed |
| --- | ---: | ---: |
| Median frame | 34.5 ms | 23.6 ms |
| Mean frame | 68.3 ms | 23.5 ms |
| 95th percentile frame | 279 ms | 26.7 ms |
| Collections per 200 frames | 32 | 3 |
| Heap at end of run | ~1,000 MB, growing | ~430 MB, flat |
| Allocated per frame | 9.6 MB | 0.82 MB |
| Mean retired instructions | 569 M | 193 M |
| Frame preparation (median) | 13.3 ms | 4.2 ms |
| Wheel dispatch (median) | 2.5 ms | 1.2 ms |

A single live-network pair (150 frames, a copy of the user's browser cache,
clean builds of the baseline and changed commits) gave a median frame of
18.7 → 11.6 ms, a 95th percentile of 243 → 14.6 ms, 19 → 1 collections and an
end heap of 1,306 → 729 MB. Live content differs between runs, so this is a
sanity check rather than a controlled comparison.

One of the three changed runs collected 13 times (p95 125 ms); a separate
400-frame run collected 6 times with a flat in-use heap. Frame timing excludes
Cocoa layer publication and GPU work. These are wall-clock measurements on a
shared machine; instruction counts are the more stable comparison.

## Verification

Focused tests: `layout/paint_plan_retention_test.v`,
`layout/visual_context_memo_test.v`, `layout/offscreen_animation_throttle_test.v`,
`painting/backface_visibility_test.v`, `dom/layout_animated_style_callback_test.v`
and the existing compositor, fused-replay and replay-allocation tests. A batch
of 81 neighbouring CSS/DOM/HTML/layout/painting test files passes except
`css/generated_metadata_test.v`, `html/window_test.v` and
`layout/visual_viewport_resize_test.v`, which fail identically on the baseline.
The 11 default screenshot smoke cases pass with unchanged results (8 exact, 3
within their established tolerances). Clean builds of the baseline and changed
sources produce identical outcomes and differing-pixel counts on 53
mask/clip-path/backface/opacity/sticky/transform reftests (34 pass on both) and
the 8 SVG regression guards, which are pixel-exact on both.

## Remaining costs

- **Replay** is now the largest per-frame cost (11–18 ms). About a third is
  `ladybird_v_skia_draw_rgba_image` resampling every visible image every frame;
  each Skia primitive also rasterizes into its own surface before a Core
  Graphics composite. A scaled-image cache needs an explicit immutable-source
  signal from V: canvas and video draws pass their live, in-place updated pixel
  buffers.
- **Collection pauses** remain about 100 ms with one marker. With
  `GC_MARKERS=8` the same sweep's pauses fell from about 170 ms to about 50 ms
  (p95 frame 209 → 73 ms at the time), at a few percent more retired
  instructions. The one-marker default and the 64/64 collection divisors are
  deliberate memory and instruction policies and are unchanged.
- Visible animations still restyle their element and re-record the display list
  every frame; there is no off-thread compositor.

## Reproducing

```sh
clang -dynamiclib -O2 tools/pikabu_instruction_network_deny.c \
  -o Build/pikabu-instructions-network-deny.dylib
python3 tools/measure_browser_scroll.py --url https://pikabu.ru/ \
  --cache-template Build/pikabu-instructions-cache-final \
  --insert-library Build/pikabu-instructions-network-deny.dylib \
  --env VOX_TEST_WINDOW=1 --frames 200 --settle-seconds 3 \
  --output Build/pikabu-scroll-new-run
```

Allocation sites, including bytes that are never reclaimed:

```sh
LIBGC=~/.cache/v/v1-fallback/0.5.2/thirdparty/tcc/lib
clang -dynamiclib -O2 tools/gc_allocation_sampler.c -o Build/gc_allocation_sampler.dylib \
  -L"$LIBGC" -lgc -Wl,-rpath,"$LIBGC"
python3 tools/measure_browser_scroll.py ... \
  --insert-library Build/gc_allocation_sampler.dylib \
  --env GC_ALLOC_SAMPLE_OUT=$PWD/Build/alloc.txt \
  --env GC_ALLOC_SAMPLE_TRIGGER=$PWD/Build/alloc.trigger \
  --env GC_ALLOC_SAMPLE_TRACK_FREES=1 \
  --trigger-file Build/alloc.trigger --trigger-frame 5
python3 tools/gc_allocation_report.py Build/alloc.txt --mode retained
```

`tools/gc_retainer_finder.c` is injected the same way with
`GC_RETAINERS_SITE=<function substring>`, `GC_RETAINERS_TRIGGER` and
`GC_RETAINERS_OUT`; it reports the chain of reachable objects holding the
oldest remembered allocation. A level without heap referrers is a root.
Raw runs, samples and reftest results are under `Build/pikabu-scroll/`.


## Production native-raster follow-up (2026-10-25)

This follow-up profiles the current preallocated, no-GC production executable;
the Boehm measurements above describe the earlier implementation. The 60 fps
target has **not** been reached. The current controlled runs still take about
48 ms per scroll callback, before Cocoa publication.

The frozen input is the real Pikabu front page (347,352 bytes of HTML and 104
cached resources), with scripts and animations enabled. All runs use the same
production V executable and production `-O2` native libraries. Renderer-only
bundle copies isolate the native changes from concurrent V development. The
source diffs, library fingerprints, raw frame records and samples are retained
under `Build/pikabu-scroll-20261024/`. The shared memory guard serializes all
builds, tests and benchmarks with its default 12 GiB sampled RSS budget.

The changes so far are:

- Rounded opaque borders use exact solid edge spans plus the original GPU
  corner patches. Float colors qualify only when they exactly equal Skia's
  byte-color conversion. Collapsed edge geometry retains the GPU fallback.
- Complete Chromium tiles containing small rounded controls can enter the
  existing bounded cache. Small shapes transfer and retain only a conservative
  affected-pixel patch while preserving the original GPU surface dimensions,
  geometry, coverage and dither coordinates.
- Repeated raster pixels are compared and expanded in bulk, including
  unaligned rows and odd-length runs; row padding remains untouched.
- The frozen-network guard also blocks `connectx`. `VOX_PROXY` points to a dead
  loopback port so inherited local proxy settings cannot bypass the guard.
- The scroll driver fingerprints native libraries, retains failed-run logs,
  and records receipt times for every contiguous flushed frame ID. Window
  height now includes all 84 pixels of browser chrome. Earlier runs requested
  a nominal 768-pixel viewport but actually rendered 764 pixels; comparisons
  below use the same actual **1024 × 764** viewport at Retina scale.

Two complete baseline/candidate pairs for the small-shape and raster-run
changes give the following results. Each is the same 120 wheel events, 42 CSS
pixels per event, alternating direction every 30 events, over scroll positions
0–1260. Live network requests are blocked, and both sides receive private
copies of the same cache.

| Per scroll callback | First baseline | First candidate | Repeat baseline | Repeat candidate |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 74.905 ms | 48.115 ms | 56.492 ms | 48.047 ms |
| Median replay | 69.841 ms | 43.870 ms | 52.299 ms | 43.306 ms |
| Median retired instructions | 352.781 M | 299.163 M | 325.541 M | 278.273 M |
| Mean retired instructions | 357.329 M | 310.406 M | 335.421 M | 293.591 M |
| Complete frame-receipt cadence | 5.457 fps | 6.220 fps | 6.048 fps | 6.386 fps |

The paired callback reduction is 35.8% and 15.0%; median instruction reductions
are 15.2% and 14.5%. Shared-machine load changes substantially between pairs,
so the larger wall-time gain is not a stable speedup claim. Receipt cadence
includes every interval: the existing profiler inserts roughly three-second
quiet waits when background requests become pending. These waits are neither
filtered out nor converted into an apparent 60 fps result. Callback timing,
receipt cadence and actual display presentation are distinct measurements.

Focused validation includes CPU raster-cache tests, sanitizer checks for the
raster-run codec, eight scroll-driver tests and 4,718 exact GPU replay
comparisons against the original library. The broader native batch passes 15
clip cases, 720 composite comparisons, 6,240 glyph-cache comparisons, 864
shape/backdrop comparisons and 288 tiled-image comparisons (44 batched).

At scroll position 1260, baseline/candidate document screenshots are identical
at both 1× and 2× scale after pausing only the seven moving tag-placeholder
shimmers for the pixel comparison. Performance runs keep those animations
active. Nineteen screenshot/reftest pages also preserve every baseline pixel,
including the same-size SVG image replacement and eight SVG paint-server
mutation guards. Fourteen of these pages match their upstream reference
exactly; five retain pre-existing reference differences. This is preservation
evidence, not a claim that all upstream conformance cases pass.

The earlier `patch-guard.json` contains completed native tests and its first
benchmark, but ends with a failed fully paused-page capture. That failed
attempt remains retained. `continue-validation-guard.json` completes the
corrected pixel comparison, all 19 visual pages and the repeat benchmark.

Remaining sampled time is dominated by native replay, notably synchronous GPU
readbacks for animated clipped gradients and repeated root-tile processing.
The 48 ms callback cost remains above the 16.67 ms budget for 60 fps.

### Compact root-tile transfers (`cf97c93b`)

Small root-layer controls now allocate and transfer only their intersection
with each Chromium tile. The GPU still uses the original tile dimensions,
origin and coverage; absent CPU backdrop pixels remain transparent. A failed
compact draw leaves the original pixels available for the full-tile fallback.
The full-tile path also avoids clearing its newly zero-initialized first tile
twice.

Two 120-frame pairs use the same current production executable, frozen input,
viewport and animated workload described above. The repeat runs in reverse
order (candidate first) to expose time-dependent host load.

| Per scroll callback | Baseline | Compact tiles | Repeat baseline | Repeat compact tiles |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 54.342 ms | 50.680 ms | 51.991 ms | 51.847 ms |
| Median replay | 49.533 ms | 46.095 ms | 47.366 ms | 46.954 ms |
| Median retired instructions | 297.168 M | 288.519 M | 294.415 M | 287.127 M |
| Mean retired instructions | 308.912 M | 303.592 M | 306.530 M | 302.627 M |

Mean instruction savings are 5.321 M and 3.904 M per callback (1.72% and
1.27%). Median wall-time savings vary from 6.74% to 0.28%; this does not
establish a repeatable 6.74% speedup or meet the 60 fps target.

Focused validation passes 3,575 grid checks in both optimized and ASan/UBSan
builds, 2,560 exact GPU region comparisons, 1,080 shape/backdrop comparisons
and 6,986 GPU replay comparisons. Coverage includes overlapping tile ownership,
immutable backdrops, failure atomicity, odd row strides, untouched padding,
cache hits and context teardown. Pikabu screenshots remain pixel-exact at both
1× and 2×. The first pair crosses the cumulative 5 M instruction gate; the
broader native batch and all 19 visual pages pass with unchanged pixels.

Receipts are `grid-region-guard-3.json` (retained failed integration-test
attempt), `region-resume-guard.json` (completed checks and benchmarks),
`region-visual/` and the four benchmark directories named `grid-before`,
`region-after`, `region-repeat-after` and `region-repeat-before` under
`Build/pikabu-scroll-20261024/`. These focused native jobs use the guard's
3 GiB budget.


### Clipped gradient transfers

Root gradients at Retina scale (`2b4dc344`) now copy only the visible rectangle to and from
CPU memory. The GPU keeps the original full surface, geometry, clips and shader
coordinates, preserving coverage and dither phase. CoreGraphics still applies
the destination clip when publishing the compact image. Unsupported contexts
and older bridge libraries use the existing full-surface fallback.

| Per scroll callback | Compact-tile control | Gradient regions | Repeat control | Repeat gradient regions |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 50.680 ms | 46.988 ms | 52.749 ms | 48.591 ms |
| Median replay | 46.095 ms | 42.855 ms | 48.293 ms | 44.349 ms |
| Mean retired instructions | 303.592 M | 292.501 M | 308.468 M | 297.520 M |

The same 120-frame animated workload saves 11.091 M and 10.948 M instructions
per callback (3.65% and 3.55%), with median callback reductions of 7.29% and
7.88%. These callbacks exclude native publication and display scanout; they
remain above the 16.67 ms budget and do not establish 60 fps.

Validation passes 576 exact GPU path-region comparisons, 192 CoreGraphics
integration comparisons, 6,986 GPU replay comparisons and headless startup.
The new focused tests cover linear and radial gradients, alpha, strokes,
fractional transforms, local and ancestor clips, odd pitches, unaligned storage
and untouched padding. Integration checks include curved destination clips,
root and isolated layers, and both render scales. Pikabu remains pixel-exact at
1× and 2× with only its seven shimmers paused for visual comparison. The first
pair exceeds the 5 M instruction gate; the broader native batch and all 19
visual pages preserve the control's pixels.

Receipts are `gradient-region-retry-guard.json`, `gradient-region-result.json`,
`gradient-region-visual/`, `gradient-region-repository-tests-result.json` and
the benchmark directories `gradient-region-after`,
`gradient-region-repeat-after` and `gradient-region-repeat-before` under
`Build/pikabu-scroll-20261024/`. The initial compile failure is retained in
`gradient-region-guard.json`. This completed broad batch is the new instruction
savings baseline for subsequent native raster experiments.

The broad native checkpoint compiles the frozen gradient-region text bridge,
as well as loading its Graphite library. Its successful source-specific receipt
is `gradient-region-promoted-native-result.json`, with the full output in
`gradient-region-promoted-native-retry.log`. The earlier harness attempt lacked
the repository include path and receives no pass credit.


### Staged rounded corners (`05af5dc5`)

Large opaque root rectangles now retain their original GPU tiles while reading
back only the rounded corners. The bridge assembles those pixels and the exact
constant interior into one image before publishing it through the original
CoreGraphics clip. Unsupported contexts retain the complete-tile fallback;
failures leave destination pixels untouched. The production linker now exports
all 14 bridge functions, including the compact shape and gradient functions
that were missing from clean builds.

These pairs use the freshly rebuilt production executable frozen as
`production-20261025.app`. They share executable payload, input cache, viewport,
scroll positions, commands and fingerprints. Their absolute instruction counts
must not be compared with earlier pairs built from a different V revision.

| Per scroll callback | Fresh production control | Staged corners | Repeat control | Repeat staged corners |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 52.800 ms | 47.433 ms | 53.289 ms | 46.146 ms |
| Median replay | 48.329 ms | 42.756 ms | 48.682 ms | 41.709 ms |
| Mean retired instructions | 311.351 M | 279.744 M | 312.268 M | 279.833 M |

The 120-frame pairs save 31.607 M and 32.434 M instructions per callback
(10.15% and 10.39%). Callback medians improve by 10.17% and 13.40%. Publication
and scanout remain outside this measurement, and 60 fps remains unachieved.

Validation passes 2,184 direct GPU comparisons, 720 unsupported-case byte
preservation checks, 1,824 native comparisons including 96 required fast-path
cases and 192 anisotropic rejection checks, 6,986 GPU replay comparisons,
headless startup, strict bundle verification, and pixel-exact Pikabu captures
at 1× and 2×. The broader native batch passes 15 clipping, 720 composite, 6,240
glyph, 864 shape, 288 tiled and 44 batched cases against the frozen candidate
source. All 19 visual pages preserve the control pixels; the existing upstream
reference differences remain unchanged. This completed batch advances the
instruction-savings baseline to staged corners.

Receipts under `Build/pikabu-scroll-20261024/` are
`rounded-staged-measurements.json`, `rounded-staged-guard.json`,
`rounded-staged-verify-retry-guard.json`, `rounded-staged-visual/` and
`rounded-staged-promote-retry-guard.json`. The clean production rebuild also
passes graphics cache lifetime checks and the exact 14-symbol export check.
The initial verification precheck rejected a signature-only executable hash
change; the retry verifies the identical Mach-O payload separately. The initial
clean-build focused test caught the missing exports; its failed receipt remains
in `rounded-staged-promote-guard.json`, followed by the successful fixed retry.


### Staged rounded borders (`a527a6df`)

Aligned opaque borders use the same staged-corner path as fills. Straight
border strips are produced exactly on the CPU; corners retain the original
GPU target, tile origin, multisampling and backdrop. One assembled image goes
through the original CoreGraphics clip. Unsupported widths, collapsed inner
rectangles, transforms, colors and contexts retain the existing fallback.

| Per scroll callback | Staged-fill control | Staged borders | Repeat control | Repeat staged borders |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 30.621 ms | 27.807 ms | 31.566 ms | 27.743 ms |
| Median replay | 27.734 ms | 24.966 ms | 28.515 ms | 24.693 ms |
| Mean retired instructions | 273.244 M | 260.006 M | 272.730 M | 260.513 M |

These fresh 120-frame pairs save 13.238 M and 12.216 M instructions per
callback (4.84% and 4.48%), with callback reductions of 9.19% and 12.11%.
Both pairs use the same production executable payload and animated offline
Pikabu cache. Earlier wall times were measured in different load conditions;
only the paired controls establish this change's improvement. Callback timing
excludes native publication and scanout, and remains above 16.67 ms.

Validation passes 3,312 direct GPU comparisons, 2,520 unsupported-case
preservation checks, 2,016 native comparisons including 288 required helper
cases and 576 anisotropic rejection checks, plus 6,986 replay comparisons.
Coverage includes one-device-pixel borders centered on half pixels, arbitrary
backdrops, curved and fractional destination clips, unaligned storage and
untouched padding. Pikabu is pixel-exact at 1× and 2×; all 19 visual pages
preserve the control pixels. The frozen candidate source passes the full native
clipping/composite/glyph/shape/tile batch. The clean production library build
also passes cache lifetime checks and the exact 14-export check.

Receipts under `Build/pikabu-scroll-20261024/` are
`root-stroke-staged-result.json`, `root-stroke-staged-guard.json`,
`root-stroke-staged-verify-guard.json`, `root-stroke-staged-visual/` and
`root-stroke-staged-promote-guard.json`. This completed broad batch advances
the instruction-savings baseline to staged borders. A separate readback-polling
experiment passed focused correctness checks but increased instructions by
about 25 M per callback; it was rejected and receives no savings credit
(`readback-poll-result.json`).


### Span-based multisample masks (`e4951357`)

Rounded fallback shapes resolve multisampling once per horizontal tile span
and copy the resulting mask row through each vertical span. This preserves the
original tile ownership at overlapping borders, negative origins and the final
column while removing a binary search for every pixel.

| Per scroll callback | Staged-border control | Span masks | Repeat control | Repeat span masks |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 29.845 ms | 28.992 ms | 28.381 ms | 27.784 ms |
| Median replay | 26.626 ms | 25.965 ms | 25.331 ms | 24.865 ms |
| Mean retired instructions | 262.048 M | 243.278 M | 260.137 M | 241.593 M |

The fresh 120-frame pairs save 18.770 M and 18.544 M instructions per callback
(7.16% and 7.13%). Callback medians improve by 2.86% and 2.11%. Both orderings
retain the same executable payload, offline cache, viewport, positions and
command fingerprints. Publication and scanout remain outside this endpoint;
60 fps remains unachieved.

The mask helper passes 15,443 exact comparisons against the original per-pixel
algorithm in optimized and AddressSanitizer/UndefinedBehaviorSanitizer builds.
The focused native/GPU batch passes 2,016 native comparisons, 288 required
fast-path cases, 576 anisotropic rejection checks, 3,288 direct GPU comparisons
and 2,520 unsupported-case preservation checks. The broad batch passes 6,986
GPU replay comparisons, the complete frozen-source clipping/composite/glyph/
shape/tile batch, pixel-exact paused Pikabu captures at both densities and
unchanged pixels on all 19 visual pages. This advances the broad instruction
savings baseline to span masks.

Receipts under `Build/pikabu-scroll-20261024/` are `tile-mask-result.json`,
`tile-mask-guard.json`, `tile-mask-verify-retry2-guard.json` and
`tile-mask-visual/`. The first broad attempt ran out of disk space; the first
retry exposed loader coalescing of identical hardlinked test libraries. The
successful retry uses distinct library inodes with the same checked bytes.
Neither failed attempt receives broad-verification credit.

Clean production-library promotion also passes the optimized and sanitizer mask
checks, 3,312 exact rounded-part GPU comparisons and the required native
fast-path/rejection checks (`tile-mask-promote-retry-guard.json`, exit 0).


The signed span-mask libraries are installed in `Build/v/Vox.app`. Installation
preserves the production executable payload, passes strict signature verification
and the headless startup check, and opens the requested Pikabu URL. The receipt
is `canonical-tile-mask-installed.json` (guard exit 0).

Subsequent experiments remain outside the canonical implementation:

| Experiment | Control / candidate callback, first pair | Control / candidate, reverse pair | Decision |
| --- | ---: | ---: | --- |
| Glyph cache hash index | 30.863 / 29.091 ms | 29.385 / 32.329 ms | Mixed timing; reject |
| Bulk multisample run copies | 31.101 / 29.750 ms | 29.358 / 30.808 ms | Mixed timing; reject |
| Compact multisample spans | 33.769 / 35.830 ms | 36.041 / 36.717 ms | Slower in both orders; reject |
| Wider channel conversion | 38.242 / 39.265 ms | 39.703 / 38.153 ms | Mixed timing; pending fresh measurement |

The compact-span helper passes 15,443 mask/reference comparisons and 324
transaction/failure cases in optimized and sanitizer configurations; its native
integration batch also passes. The bulk-copy experiment passes 88,644 reference
cases; the wider conversion passes 640 reference cases including in-place,
unaligned and tail handling in both configurations. Correctness alone does not
establish a scrolling improvement. These experiments receive no accepted
instruction-savings credit. Their `*-result.json` and `*-metrics.json` receipts
are under the same evidence directory.

Two known task-owned URL launches were still running during these cohorts and
were stopped after the final paired run (`stale-owned-browser-cleanup.json`).
Fresh scheduling measurements use a separately frozen production executable;
its different V/native scheduling changes are not attributed to the span-mask
implementation. Ambient activity from other repository tasks remains outside
this benchmark's control.

### Destination-order sparse rasters (`79dd6b31`)

Sparse rounded rasters assemble their opaque interiors and copied backdrops in
RGBA order, converting only the small GPU corner patches. Every output pixel
is initialized, including entirely offscreen shapes and padded rows. This
removes an unnecessary zero initialization and a full-surface channel swap.

| Per callback | Control | RGBA staging | Repeat control | Repeat staging |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 23.013 ms | 23.154 ms | 23.311 ms | 22.105 ms |
| Mean retired instructions | 223.389 M | 212.676 M | 224.557 M | 212.476 M |
| Native completion cadence | 42.08 fps | 41.80 fps | 41.43 fps | 43.20 fps |

The two 240-frame pairs save 10.713 M and 12.081 M instructions. Wall time is
mixed; this change does not establish a repeatable frame-rate improvement.
The expanded native batch passes 3,168 exact comparisons, including 1,440
required sparse-helper cases and 2,880 anisotropic rejection checks. Clean
production promotion also passes 3,312 GPU comparisons and 2,520 unsupported
cases. Full native checks, paused Pikabu at 1×/2× and all 19 visual preservation
comparisons pass, advancing the broad baseline to RGBA staging. This batch does
not include the separate 6,986-comparison GPU replay suite.

### Bounded raster reuse (`0a04e03f`)

Quartz providers return sparse raster allocations to a pool only after their
last image reference is released. The pool retains at most eight allocations
and 32 MiB, expires on idle cleanup, and uses generations to prevent a delayed
release from refilling an explicitly purged pool.

| Per callback | Staging control | Buffer reuse | Repeat control | Repeat reuse |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 21.481 ms | 20.715 ms | 21.634 ms | 20.677 ms |
| Median replay | 19.080 ms | 18.337 ms | 19.283 ms | 18.330 ms |
| Mean retired instructions | 213.100 M | 205.713 M | 214.306 M | 208.434 M |
| Native completion cadence | 45.58 fps | 46.56 fps | 45.04 fps | 46.18 fps |

Callback medians improve by 3.57% and 4.43%; the pairs save 7.387 M and
5.872 M instructions. Ownership, late release, purge, budget and concurrent
reuse checks pass optimized and sanitizer builds. The same focused native/GPU
checks and full native/visual batch pass for the pool implementation, advancing
the broad baseline again; accumulated savings since that batch are zero.

These pairs use the same separately frozen production executable, animated
cache, positions and viewport. Changes in that executable's scheduling are
excluded from the native optimization credit. Native completion cadence
includes publication, scheduling and log delivery; it does not measure display
scanout. **60 fps remains unachieved.** Timing across different cohorts is not
a before/after comparison.

Evidence is under `Build/pikabu-scroll-20261024/`: `rgba-stage-result.json`,
`rgba-stage-steady-metrics.json`, `rgba-stage-verify-retry-guard.json`,
`rgba-pool-result.json`, `rgba-pool-metrics.json`,
`rgba-pool-verify-guard.json` and both `*-promote-guard.json` receipts.
The signed pool library is installed in the canonical production app while
preserving its executable and Graphite libraries. Strict signing, headless
startup and the requested Pikabu launch pass
(`canonical-rgba-pool-installed.json`).

Removing the mixed-MSAA rollback copy and repeating the wider channel
conversion on the pooled implementation both produce mixed timing and no
repeatable instruction reduction. They remain excluded from the implementation
and receive zero savings credit (`msaa-discard-result.json`,
`pooled-wide-result.json`).


### Borrow the fresh document frame (`74d53691`)

The document now paints into its freshly claimed RGBA frame when the complete
bitmap, transform, clip and color space match the separate canvas. Nested
layers retain their own canvases. Filtered roots snapshot their input and clear
the destination before compositing, including when snapshot allocation fails.

This cohort uses the newer frozen V executable with viewport reuse
(`9075134f`); the older buffer-pool timings above are not its control.

| Per callback | Separate canvas | Borrowed frame | Repeat control | Repeat borrowed |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 31.871 ms | 29.107 ms | 34.446 ms | 32.875 ms |
| Median replay | 27.564 ms | 25.012 ms | 29.880 ms | 28.462 ms |
| Mean retired instructions | 199.851 M | 190.907 M | 200.078 M | 195.575 M |
| Native completion cadence | 27.69 fps | 32.16 fps | 27.29 fps | 28.79 fps |

The matched 240-frame pairs save 8.943 M and 4.503 M instructions and reduce
callback medians by 8.67% and 4.56%. The visual driver's first-pair 8.943 M
saving crosses the broad-test threshold; its 19 preservation comparisons and
paused Pikabu at 1×/2× all pass exactly. The benchmark's stricter minimum-pair
gate is false; it does not itself claim a broad pass. The completed visual
batch advances this scrolling cohort's broad baseline to `74d53691`.

Optimized and ASan/UBSan fixtures pass 42 canvas comparisons with 24 rejected
borrow conditions, 846 bitmap comparisons with 281 guarded fallbacks, and
1,728 publication comparisons each. An isolated staged-source run passes the
same checks. This batch does not rerun the separate 6,986-case GPU replay suite.

A current-repository production build, strict signature verification, headless
startup, 240-frame scrolling profile and the requested Pikabu launch all pass.
That production profile records a 23.451 ms median callback, 20.399 ms median
replay and 36.87 fps native completion cadence. It is a separate measurement,
not a paired improvement claim or a display scanout measurement. **60 fps
remains unachieved.**

Evidence: `frame-borrow-benchmark-result.json`,
`frame-borrow-repository-retry/result.json`,
`frame-borrow-index-check/result.json`, `frame-borrow-visual-guard.json`,
`frame-borrow-visual/{gate,focused,broad}.json` and
`frame-borrow-production-retry-result.json`, all under
`Build/pikabu-scroll-20261024/`. The original production setup failure is
preserved in `frame-borrow-production-guard.json`; the compiler wrapper's V
library path was corrected before the successful retry.


### Reuse clipped-path render targets (`5a60e4b3`)

Clipped gradient paths reuse a bounded set of Graphite surfaces instead of
creating a recorder and render target for each draw. Every draw still clears
the full target and uses its original coordinates, backdrop and readback.
The cache holds at most 32 surfaces and 4 MiB of color pixels; its recorder has
a 16 MiB GPU budget. Larger targets retain the temporary allocation path.
Idle and explicit graphics purges destroy the surfaces before their recorder
and context.

This is the same newer frozen V executable and viewport workload as the
borrowed-frame cohort above, with four matched 240-frame runs.

| Per callback | Control | Reused target | Repeat control | Repeat reused |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 29.884 ms | 27.941 ms | 31.362 ms | 30.662 ms |
| Median replay | 25.808 ms | 23.306 ms | 27.053 ms | 26.193 ms |
| Mean retired instructions | 196.890 M | 181.240 M | 195.512 M | 192.977 M |
| Native completion cadence | 31.05 fps | 32.35 fps | 29.66 fps | 29.86 fps |

Both orders improve callback time and instruction count, saving 15.650 M and
2.535 M instructions. The stricter minimum-pair broad gate is false. The visual
driver's first pair crosses the 5 M threshold and its completed broad batch
advances this scrolling cohort's baseline to `5a60e4b3` with zero accumulated
savings after that batch.

A clean official Graphite build passes 776 exact path comparisons, including
stale-content, cache-budget, oversized-target and idle-release cases, and 192
native gradient integration comparisons. The ASan/UBSan path harness also
passes all 776 comparisons; the dynamically loaded libraries use optimized
builds. The broad batch passes the frozen native clipping, compositing, glyph,
shape and tiled replay checks, all 19 visual preservation pages, and paused
Pikabu at 1×/2×. It does not rerun the separate 6,986-case GPU replay suite.

The first visual attempt retained two unloaded sidebar avatars (518 pixels).
Its failure remains recorded. With an eight-second resource settle, both
Pikabu comparisons are exact; no pixels are masked or tolerance increased.

Evidence under `Build/pikabu-scroll-20261024/`:
`gradient-target-result.json`, `gradient-target-clean-retry-result.json`,
`gradient-target-clean-retry-guard.json`,
`gradient-target-visual-retry/{gate,focused,broad}.json` and
`gradient-target-verify-retry-guard.json`. The original clean-build setup
failure and shorter-settle visual failure are preserved in their original
reports. **60 fps remains unachieved.**

The canonical production bundle now contains the clean Graphite library. Its
existing unsigned V executable and text/Dawn libraries were preserved; strict
bundle signing, startup and the requested Pikabu launch pass. A fresh 240-frame
production run records a 35.605 ms median callback, 48.187 ms p95, 30.300 ms
median replay, 182.132 M mean instructions and 26.24 fps native completion.
This unpaired run is recorded separately from the matched improvements above;
it measures native completion rather than display scanout. Its evidence is
`canonical-gradient-target-installed.json`, `gradient-target-install-guard.json`
and `gradient-target-production-profile/summary.json`.


### Reuse Metal queues for eight completed frames (`add65da5`)

Graphite keeps one real Metal queue for up to eight completed frames before
releasing it. Each frame still completes its GPU work before returning CPU
pixels. Explicit graphics cleanup and idle context destruction retain their
immediate release behavior; Dawn keeps its existing retirement policy.
This amortizes driver setup without accumulating a queue for every frame.

Four matched 240-frame runs use the same newer frozen V executable, cached
Pikabu resources, viewport, scroll positions and replay command counts.

| Per callback | Control | Eight frames | Repeat control | Repeat eight frames |
| --- | ---: | ---: | ---: | ---: |
| Median callback | 31.194 ms | 19.661 ms | 29.179 ms | 18.976 ms |
| Median replay | 26.516 ms | 15.178 ms | 24.732 ms | 14.617 ms |
| Mean retired instructions | 186.581 M | 124.883 M | 183.957 M | 125.585 M |
| Native completion cadence | 29.93 fps | 41.28 fps | 30.87 fps | 41.21 fps |

Both orders improve callback time and instruction count, saving 61.697 M and
58.372 M instructions per frame. Both cross the 5 M broad-test threshold.
The completed broad batch advances this scrolling cohort's baseline to
`add65da5`, with zero accumulated savings after that batch. Completion cadence
includes publication and scheduling; it does not measure display scanout.

The clean official Graphite build passes 776 exact GPU path comparisons,
192 native gradient integration comparisons, and the sanitized 776-case
harness. CPU queue ownership tests pass optimized and ASan/UBSan builds,
covering the eighth-frame boundary, forced retirement, counter reset, labels,
residency sets and destruction. Dynamically loaded GPU libraries are optimized.

A separate 4,000-frame changing-gradient stress run performs six real readbacks
per frame. Peak physical footprint is 345.4 MB; the median near frame 2,000 is
337.118 MB versus 337.265 MB near frame 4,000. Idle cleanup reduces footprint to
10.9 MB. The first 1,000-frame experiment exceeded an initial 64 MiB fluctuation
bound by 0.2 MiB; its receipt remains preserved. The extended test separately
bounds peak footprint, fluctuation, sustained median growth and idle retention.

Paused Pikabu at 1×/2× and all 19 visual preservation pages compare exactly.
The frozen native clipping, compositing, glyph, shape and tiled replay checks
also pass. This batch does not rerun the separate 6,986-case GPU replay suite.

Evidence under `Build/pikabu-scroll-20261024/`: `queue-window-result.json`,
`queue-window-clean-result.json`, `queue-window-clean-guard.json`,
`queue-window-visual/{gate,focused,broad}.json`,
`queue-window-verify-guard.json`, `queue-window-memory-retry-result.json`
and `queue-window-memory-attempt1-*`.
The production bundle installation and fresh completion cadence are recorded
separately below; the paired runs in this table remain below 60 fps.


The canonical production bundle contains the clean queue-reuse Graphite library.
Installation preserves its unsigned V executable and text/Dawn libraries. Strict
bundle signature verification, headless startup and the requested live Pikabu
launch pass. Two fresh production processes each run the synthetic profiler on
the same cached page for 240 moving frames in a 1024×764 viewport, with external
network blocked. The profiler injects integer 42 CSS-pixel steps from inside the
draw callback, reverses every 30 frames, and requests the next frame as soon as
the callback finishes. It does not reproduce precise Cocoa wheel input.

| Synthetic production measurement | First run | Repeat |
| --- | ---: | ---: |
| Median callback | 12.756 ms | 11.896 ms |
| p95 callback | 23.809 ms | 21.607 ms |
| Median replay | 9.904 ms | 9.147 ms |
| Mean retired instructions | 122.390 M | 122.366 M |
| Mean completion-log receipt cadence | 61.68 fps | 68.72 fps |
| p95 native completion interval | 26.171 ms | 23.199 ms |

These numbers describe the synthetic workload only. Reporting them as proof
that ordinary production scrolling reached 60 fps was incorrect; the later
precise-input measurements below supersede that conclusion. The cadence comes
from flushed log receipts at the end of the app draw callback, before that
frame's native publication. Receipt intervals include work between callbacks
and log delivery, but are not timestamps of publication or physical scanout.
Some frames still exceed 16.7 ms. These fresh runs have different system load
from the matched table above and supply no additional paired improvement claim.

An audit of both saved traces confirms 120 steps of +42 CSS pixels and 120 of
-42 in each run. All 240 frames in each trace report `scroll_raster_reused=0`;
the discrepancy cannot be attributed to successful raster reuse in these runs.

Production evidence: `canonical-queue-window-installed.json`,
`queue-window-install-guard.json`,
`queue-window-production-profile/summary.json` and
`queue-window-production-repeat/summary.json`. The clean library SHA256 is
`bc5054c22f76b14da859f5f4f0a5217c158d26734aa329e35352018418bcff4c`;
after ad-hoc signing the installed library is
`a5d1163a5481b19ca0a8a40002a8b3fdac7ac22bf5a64720577b56f42fa3b062`.
The preserved unsigned V payload is
`46dfed8e2a5b60622af27998be96c618d2055a1e1fbabae30175c02d47e0399d`.

### Precise wheel input exposes the remaining lag (2026-10-25)

The 60 fps goal remains open. The integer-step synthetic profiler above does
not reproduce ordinary precise wheel input: the native wheel handler turns a
2-pixel event into an 8.4 CSS-pixel scroll step. At 2× scale those fractional
positions change antialiasing coverage. They also prevent integer-scroll raster
reuse, although neither earlier synthetic trace used that path either. Live CSS
animations invalidate retained paint input as well. These observations identify
workload differences, not an isolated explanation for the full cadence gap.

A separate probe sends 240 precise Cocoa wheel events at 60 Hz through the real
input view, reverses every 60 events, and verifies that the rendered scroll
position moves. It measures completion of the document view's `updateLayer`,
including native publication. This is not physical display scanout. It uses the
same cached Pikabu resources, frozen production V executable, 1024×764 document
viewport, 2× scale, and a 12-second initial settle in each paired run.

Three completed native changes reduce avoidable work without changing pixels:

- `d6cc7e21` copies mixed antialiasing output in contiguous spans.
- `4645e115`/`18e663d0` test and implement the existing exact opaque rectangle
  fallback before duplicate antialiasing passes.
- `f2f01605` composites mixed raster tiles from tile rectangles without building
  and scanning a per-pixel ownership mask.

The tile-rectangle change's matched precise-input measurements are:

| Measurement | Control | Candidate | Repeat control | Repeat candidate |
| --- | ---: | ---: | ---: | ---: |
| Mean native completion cadence | 29.29 fps | 31.18 fps | 29.59 fps | 32.55 fps |
| Median native frame | 31.055 ms | 28.042 ms | 30.063 ms | 26.747 ms |
| p95 completion interval | 53.749 ms | 51.791 ms | 54.833 ms | 49.748 ms |

These results still miss 60 fps. Earlier precise-input runs measured 18 fps;
those runs had different host load and supply no paired improvement claim.
A longer CPU-sampling run also measured only 17–18 fps and is diagnostic, not
performance credit. Rounded-rectangle tile replay, backdrop copying, and raster
allocation remain the largest native costs in that sample.

Focused validation passes 15,443 ownership-mask reference comparisons, 12,811
backdrop/mode/failure-rollback comparisons, and 3,575 grid ownership/backdrop
comparisons in optimized and ASan/UBSan builds. The optimized GPU checks pass
3,168 rounded-rectangle and 2,304 solid replay comparisons exactly. The
synthetic workload's instruction differences are below 5 M per frame and vary
with animation state, so this cohort credits zero additional instruction
savings and retains `add65da5` as its broad verification baseline.

Evidence: `Build/pikabu-live-lag-20261025/solid-comparison.log`,
`solid-comparison-guard.json`, `precise-grid-{baseline,spans}*/summary.json`,
`long-profile-guard.json`, and `long-{baseline,grid-spans}/sample.txt`.

### Bounded rounded-shape recorder reuse

`1b8461df` keeps the large rounded-shape recorder alive between cache misses,
with a 16 MiB resource budget and the existing GPU mutex. Both explicit and
idle context teardown discard it before destroying the context. Surface size,
origin, geometry, backdrop, coverage, and readback remain unchanged.

The dominant card's four fill/stroke and antialiasing draws take 20–28% less
time in three alternating native trials. The same precise-wheel page probe
gives a smaller, repeatable gain:

| Measurement | Control | Recorder reuse | Repeat control | Repeat reuse |
| --- | ---: | ---: | ---: | ---: |
| Mean native completion cadence | 31.72 fps | 32.63 fps | 33.65 fps | 34.61 fps |
| Median native frame | 27.506 ms | 26.601 ms | 26.844 ms | 25.167 ms |

The 60 fps target remains open. These runs keep the earlier production V
executable fixed and isolate the native library change; they do not establish
the performance of a later full V rebuild. No additional retired-instruction
savings are credited.

Focused checks pass 6,984 byte-exact full-shape comparisons, including repeated
context teardown and changing surface dimensions, plus the existing 2,520
unsupported-shape, 3,312 rounded-part, 1,440 direct-part, 3,168 native rounded,
and 2,304 solid replay checks. Evidence is under
`Build/pikabu-live-lag-20261025/`: `recorder.log`, `recorder-runtime.log`,
`recorder-runtime-guard.json`, `recorder-runtime-selection.json`, and
`precise-recorder-runtime*/summary.json`.

### Rejected combined antialiasing readback experiment

A private experiment submits both antialiasing modes with independent backdrops
before one GPU completion wait. Its isolated rounded-shape workload improves
by 1.46–1.48×, but the matched precise-wheel page runs do not establish a
consistent gain:

| Measurement | Control | Combined wait | Repeat control | Repeat combined |
| --- | ---: | ---: | ---: | ---: |
| Mean native completion cadence | 31.27 fps | 31.70 fps | 30.90 fps | 32.04 fps |
| Median native frame | 27.882 ms | 27.783 ms | 28.663 ms | 26.684 ms |

The first pair improves cadence by only 1.39% and median frame time by 0.36%.
It fails the experiment's requirement for both pairs to improve both measures
by more than 2%, so the change is excluded from production. The exactness checks
pass 6,984 full-shape and 6,984 independent paired-output comparisons, plus
1,160 unsupported cases and the existing focused native replay checks. This
experiment adds no retired-instruction credit or completed production fix.

Evidence: `Build/pikabu-live-lag-20261025/shape-pair-runtime-selection.json`,
`shape-pair-measurement.log`, `shape-pair-measurement-guard.json`, and
`precise-shape-pair*/summary.json`. The 60 fps goal remains open.

### Precise-input measurement protocol

`tools/measure_precise_scroll.py` injects precise Cocoa wheel events through
the native input view and timestamps changed layer contents after `updateLayer`
returns. It records rendered scroll positions so animation-only publications
cannot inflate scrolling fps. This endpoint is native publication, not physical
display scanout. The main-thread input timer can run late; its actual delivery
timestamps and cadence are retained separately.

For a live production trial, use a unique output and guard report:

```sh
python3 tools/run_memory_bounded.py --report Build/pikabu-precise-live-1-guard.json -- \
  python3 tools/measure_precise_scroll.py \
  --binary Build/v/Vox.app/Contents/MacOS/Vox --url https://pikabu.ru \
  --require-title 'Пикабу' --settle-seconds 20 \
  --network-policy 'live external network; independent empty cache' \
  --output Build/pikabu-precise-live-1
```

The defaults are 600 events at nominal 60 Hz, 2-pixel precise wheel deltas,
reversing every 60 events, a 12-second settle, and a 1024×764 document viewport.
The live example waits for the `Пикабу` title before its 20-second settle.
`--require-title` checks document identity before settling and again when input
starts; losing that identity restarts the settle. It does not establish network
idle. Without this option the settle starts at process startup, which can let
slow navigation overlap the measured input window. Such a run cannot establish
steady scrolling performance. Preserve readiness failures and timeouts.
Protocol version 2 divides observed scroll changes by the entire first-to-last
input period, including time before the first publication and after the last.
The first publication supplies a reference position and is conservatively
excluded from the scroll-change count. Leading/trailing publication gaps are
reported explicitly. Reciprocal publication-interval timings remain diagnostic
fields and do not replace full-window throughput.
The tool selects the test display away from the pointer. `--network-policy`
records the policy; an offline comparison must separately supply the blocking
interposer with `--insert-library` and an identical `--cache-template`.
Each trial uses an empty private `VOX_PROFILE_DIR`: saved proxy settings cannot
override the selected route, and the bookmark bar stays hidden so its height
cannot change the document viewport. The user's profile remains untouched.
Confirm that navigation actually loaded the intended document. Current
navigation fetches the main response rather than displaying the saved page
first; copying cached files and denying the network can therefore produce a
navigation-error page. An offline fixture must serve the archived response at
the original URL. Retain its source, body hash, request log, route and private
trust configuration. The probe records and pins an explicit `SSL_CERT_FILE`.
Run at least two unprofiled trials per build, alternating matched controls and
candidates for optimization credit, then validate the installed bundle live.
Use a separate diagnostic run to verify that the candidate path actually
executes. An ineligible path cannot explain timing differences between runs.

Keep `browser.log`, `run.json`, `summary.json`, and the outer guard report.
The evidence includes executable/library/probe hashes, cache hash, commands,
environment, actual browser exit code, input/publication counts, timestamps,
median/p95/maximum intervals, and the fraction over the target frame budget.
Missing frames, stationary input, crashes, timeouts, and identity changes
invalidate a run. Compilation alone does not execute a test. Agent requirements
are in `AGENTS.md` under "Scrolling performance measurements".

Two 240-input tool-validation runs use the unchanged frozen
`recorder-runtime.app` and the same cached resources, offline policy, 2× scale,
viewport, and settle time. They establish that the new probe runs end to end;
they do not establish a new renderer improvement or current installed/live
performance:

| Measurement | Validation | Repeat |
| --- | ---: | ---: |
| Full-input-window scroll throughput | 26.69 fps | 23.72 fps |
| Median scroll interval | 34.644 ms | 39.483 ms |
| p95 scroll interval | 58.092 ms | 63.071 ms |
| Maximum scroll interval | 81.582 ms | 91.506 ms |
| Scroll intervals over 16.67 ms | 128/128 | 121/121 |
| Actual input delivery | 49.84 Hz | 46.85 Hz |
| Completed inputs / changed publications | 240 / 145 | 240 / 139 |

The earlier native probe counted `updateLayer` returns even when contents did
not change. These new results count changed contents and report scroll-changing
publications separately; they cannot supply a paired regression claim against
that older endpoint. Both new browser processes exit zero. Evidence is under
`Build/pikabu-live-lag-20261025/precise-tool-validation{,-repeat}/`.
The table uses `summary-input-window-v2.json`, recalculated from the original
raw timestamps without rerunning the browser. The original `summary.json`
retains the earlier reciprocal-interval averages of 27.48 and 24.40 fps.

### Rejected buffer and recorder reuse experiments

Two private candidates were evaluated with the precise-input protocol. Buffer
reuse retains up to eight released rounded-raster vectors within 32 MiB; live
image providers retain exclusive ownership. Recorder reuse extends the bounded
rounded-shape recorder to small shapes, compact regions and rounded parts.
Neither candidate is included in production: buffer reuse regresses in the
first pair, while recorder reuse reverses direction between pairs. The latter
results also show substantial machine/workload variability. These trials do
not establish an optimization gain.

All eight trials use the same frozen `recorder-runtime.app` executable, with
only the candidate native library replaced, cached Pikabu resources, blocked
external network, a 1024×764 document viewport at 2× scale, a 12-second settle,
and 600 precise events at nominal 60 Hz, reversing every 60 events. Each
candidate is compared with its adjacent control. All processes exit zero with
unchanged binary/library identities and complete input/publication records.
The endpoint is changed native contents after `updateLayer`, not scanout.

| Trial | Scroll fps | Median ms | p95 ms | Maximum ms | Intervals >16.67 ms | Input Hz | Publications |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Buffer reuse, control 1 | 32.89 | 28.851 | 47.935 | 74.165 | 377/393 | 50.13 | 419 |
| Buffer reuse, candidate 1 | 32.74 | 29.100 | 49.695 | 70.236 | 389/410 | 47.83 | 440 |
| Buffer reuse, control 2 | 30.93 | 31.456 | 52.095 | 72.616 | 371/378 | 49.01 | 403 |
| Buffer reuse, candidate 2 | 31.51 | 30.385 | 49.702 | 70.998 | 350/361 | 52.29 | 390 |
| Recorder reuse, control 1 | 24.62 | 39.183 | 63.113 | 87.763 | 303/304 | 48.52 | 324 |
| Recorder reuse, candidate 1 | 20.70 | 47.102 | 70.552 | 91.447 | 259/259 | 47.86 | 273 |
| Recorder reuse, control 2 | 20.77 | 46.220 | 70.199 | 94.461 | 252/252 | 49.36 | 269 |
| Recorder reuse, candidate 2 | 25.10 | 37.036 | 64.976 | 92.877 | 295/296 | 50.80 | 319 |

Scroll fps uses the full input window from `summary-input-window-v2.json`,
recalculated from the original raw timestamps. The original summaries retain
the earlier reciprocal-interval averages; no browser rerun is implied.

The buffer candidate passes optimized and ASan/UBSan ownership checks,
1,440 direct cases, 3,168 native rounded comparisons and 2,304 native solid
comparisons. The recorder candidate passes 6,984 full-shape comparisons across
cache teardown epochs and the compact-region and rounded-part GPU checks.
Correctness alone does not supply performance credit. Raw inputs, publications,
hashes and summaries are under
`Build/pikabu-live-lag-20261025/{vector,all-recorder}-{control,candidate}-{1,2}/`;
`vector-pool-guard.json` records the completed serialized experiment job.

### Production rebuild and runtime validation

The loader-arena production rebuild succeeds with current V and the 10 GiB
compiler limit. The frozen `loader-arena.app` passes strict signature
verification and the headless startup check. Its executable SHA-256 is
`8c5842339359da6d62bbe609d0bcbe36b26e3d29be3ee48804546268602df228`.

The four focused canvas cases now execute successfully in both default GC
and preallocated/no-GC modes: CSSOM repaint, a 1024² native canvas with resize,
compact mutation deltas, and canvas/DOM/selection operation ordering. This uses
the staged compatible main-module fixture with the unchanged focused test
sources; the source pins are retained in the results. The earlier compile-only
checks did not establish these runtime passes.

The first 600-input offline production trial is invalid: its title is
`Navigation error — vox`, every rendered scroll position is zero, and the
probe rejects it. Its 570 changed publications receive no scrolling FPS
credit. The navigation implementation now requires a successful main fetch;
the old cached-page/blocked-network setup does not supply one. Remaining
measurements require a response replay or live access.

Evidence under `Build/pikabu-live-lag-20261025/`:
`canvas-finalize-executed-results.json`,
`canvas-finalize-executed-{gc,prealloc}.log`,
`loader-arena-build-identity.json`, `loader-arena-build.log`,
`loader-arena-smoke.log`, `loader-arena-production-guard.json`, and
`loader-arena-precise/{run.json,browser.log}`. The guard exits 1 because the
scrolling acceptance trial failed; the preceding executed checks pass.


### Archived-page baseline and readiness correction

A local TLS replay now serves the archived Pikabu main response and resources
at their original URLs, with external forwarding disabled. The main response
SHA-256 is `7d43fabcfe55aab6d0ffce072975d0266ba12d84787c39c028ad14cf82da486a`.
Both 600-input frozen-production trials start with the Pikabu document title.
They provide a baseline, without paired optimization credit:

| Measurement | Trial 1 | Trial 2 |
| --- | ---: | ---: |
| Full-input-window scroll throughput | 24.20 fps | 23.78 fps |
| Median scroll interval | 40.040 ms | 40.912 ms |
| p95 scroll interval | 56.454 ms | 57.957 ms |
| Maximum scroll interval | 92.136 ms | 79.283 ms |
| Scroll intervals over 16.67 ms | 266/266 | 267/267 |
| Completed inputs / changed publications | 600 / 279 | 600 / 281 |

The old live trial starts with title `vox`; input precedes the first publication
by 4.53 seconds. Its computed 12.49 fps includes navigation and cannot describe
steady scrolling. The repeat starts with the same unloaded title, never
scrolls, and fails summary validation. Both remain preserved as failed
acceptance evidence. This exposed the need for `--require-title`, whose settle
period begins after document identity matches. Nineteen measurement-tool tests
pass and the native probe compiles with strict warnings.

Ten canonical visual checks pass for the frozen loader-arena production build.
The separate sampling run identifies rounded-shape rasterization, backdrop
copying and image composition as substantial costs; sampled runs do not supply
performance credit.

Evidence under `Build/pikabu-live-lag-20261025/`:
`loader-arena-{replay,replay-repeat,live,live-repeat}/`,
`loader-arena-{sample.txt,diagnostic-result.json,visual-result.json}`, and
`loader-arena-resume-replay-guard-v1.json`. The guard's successful exit does not turn the
failed live trials into acceptance passes.

### Rejected fractional rounded-parts experiment

The candidate extends sparse rounded-corner staging to fractional opaque fill
edges while retaining the original GPU surface dimensions. Its 6,528 exact
native/GPU comparisons pass; that total includes 4,800 direct rounded-parts
comparisons. Alternating archived-page trials give:

| Measurement | Control 1 | Candidate 1 | Control 2 | Candidate 2 |
| --- | ---: | ---: | ---: | ---: |
| Scroll throughput | 22.87 fps | 36.49 fps | 35.23 fps | 35.65 fps |
| Median interval | 43.324 ms | 27.475 ms | 28.347 ms | 27.946 ms |
| p95 interval | 57.365 ms | 38.132 ms | 42.519 ms | 40.217 ms |
| Maximum interval | 80.859 ms | 54.768 ms | 57.515 ms | 55.279 ms |
| Intervals over 16.67 ms | 252/252 | 380/401 | 387/395 | 378/391 |
| Inputs / changed publications | 600 / 264 | 600 / 424 | 600 / 420 | 600 / 411 |

The second pair fails the experiment's required 2% throughput and median gain.
More decisively, a separate eligibility diagnostic observes 34,475 attempts and
zero successful sparse draws: every call fails the initial eligibility check.
The timing differences therefore cannot be credited to this change. The
candidate remains only under `Build/` and is not installed or promoted to
production. No sanitizer or visual follow-up is claimed for this rejected
candidate. The smooth 60 fps goal remains open.

Evidence: `fractional-sparse-result.json`, `fractional-exact.log`,
`fractional-{control,candidate}-{1,2}/`, and
`fractional-eligibility-result.json` under the same artifact directory.

### Non-root rounded-shape readbacks (October 25)

A finer eligibility diagnostic explains the rejected experiment: 17,940 calls
were non-root layers, while 17,054 root calls had no MSAA grid. The accepted
change adds compact rounded-edge readback for eligible non-root layers. It
retains the original GPU surface dimensions and transform, resolves each
patch against the original MSAA grid, and assembles one image with the same
Quartz footprint and clipping. Integer-aligned strokes and fills use corner
patches; fractional opaque fills retain all four edge bands. Unsupported
geometry, colors, backdrops and sizes retain the existing fallback.

The separate instrumented Pikabu run records 12,882 successful fast-path draws
from 23,572 attempts. Neither that diagnostic nor sanitizer runs supplies fps
credit. Alternating unprofiled trials use the same frozen executable, archive,
response bytes, proxy, private TLS trust, 1024-by-764 document viewport, 2x
backing scale, 600 precise two-pixel inputs, nominal 60 Hz input, reversal every
60 inputs, and 12-second settle after the Pikabu title appears. Both pairs
clear the preselected 2% throughput and median improvement requirement; p95
must stay within 2% of the matched control.

| Measurement | Control 1 | Candidate 1 | Control 2 | Candidate 2 |
| --- | ---: | ---: | ---: | ---: |
| Scroll throughput | 35.744 fps | 36.748 fps | 35.476 fps | 36.636 fps |
| Median interval | 28.109 ms | 27.094 ms | 28.384 ms | 27.137 ms |
| p95 interval | 40.385 ms | 39.647 ms | 39.427 ms | 40.030 ms |
| Maximum interval | 61.646 ms | 61.708 ms | 55.946 ms | 56.996 ms |
| Intervals over 16.67 ms | 385/405 | 382/410 | 395/406 | 379/408 |
| Inputs / changed publications | 600 / 425 | 600 / 439 | 600 / 425 | 600 / 438 |
| Actual input delivery | 52.865 Hz | 53.689 Hz | 52.340 Hz | 53.786 Hz |

This is a 2.81% and 3.27% improvement on the archived workload, measured at
changed native layer contents after `updateLayer`, with the entire input
window as denominator. Physical scanout is not measured. The p95 and maximum
regress slightly in the second pair. Most intervals still miss 16.67 ms, so
this change does not meet the smooth 60 fps target.

All 864 exact native/GPU comparisons pass, covering both backing scales,
rectangular and curved clips, analytic/mixed/all-MSAA grids, fills and strokes,
fractional positions, viewport clipping, padded rows, and translucent backdrops.
The same cases pass with ASan and UBSan. The committed native test also asserts
direct fast-path eligibility so identical fallback draws cannot silently pass.
Nineteen canonical visual cases remain pixel-identical to the control; existing
differences from upstream expected images are reported separately. No retired
instruction reduction is measured or credited; the broad-suite instruction
counter remains unchanged.

Fresh document-gated baseline checks on the frozen loader-arena build give
35.130/34.200 fps on the archive and 10.115/10.083 fps on the live page with
independent empty caches and 20-second settles after document identity. All
four start with the Pikabu title. The live runs have 93.494/93.464 ms median,
152.469/143.670 ms p95, 191.041/223.024 ms maximum, 118/118 over-budget
intervals each, and 600 inputs / 123 changed publications each. These workloads
are separate: archive results cannot establish live-page performance. The
installed production bundle requires its own fresh live checks.

Evidence under `Build/pikabu-live-lag-20261025/`:
`rounded-eligibility-v2-result.json`, `sparse-layer-result.json`,
`sparse-layer-{control,candidate}-{1,2}/`,
`sparse-layer-diagnostic-run/browser.log`,
`sparse-layer-{exact,sanitizer}.log`,
`sparse-layer-visual-preservation/summary.json`,
`integrated-native-{test,sanitizer}.log`, and
`readiness-{replay,live}-{1,2}/`. Source/library/probe identities and matching
initial cache hashes are retained in each trial's `run.json`.

### Installed production checks after rounded-layer integration (October 25)

The installed `Build/v/Vox.app` passes strict signature verification and the
headless startup check. Its executable SHA-256 is
`d0010b0f8223259f917b0c3a46fa169286fff244ef94633f493562659500891c`;
the native bridge is
`233f400b62a1e055a8e125784b670eb9d38db889ebe3582e69d66663a2ca32a6`.
The first successful compile overlapped edits to two other source files and
was rebuilt. Source pins remain unchanged throughout the second build, and
the executable and library hashes remain unchanged throughout all four trials.
The current-V compiler uses its 10 GiB limit and the standard production
preallocated/no-GC configuration, without profiling flags.

Each trial launches a fresh process with an empty private profile. All four
start with the Pikabu title and complete 600 precise two-pixel inputs, reversing
every 60 inputs, in the same 1024-by-764 document viewport at 2x scale. Archived
trials use the original-URL TLS response replay and matching initial cache;
live trials use independent empty caches and the ambient HTTP proxy. Settling
starts after the requested document title: 12 seconds for the archive and
20 seconds for live access. The endpoint remains changed native layer contents
after `updateLayer`, rather than physical scanout.

| Measurement | Archive 1 | Live 1 | Archive 2 | Live 2 |
| --- | ---: | ---: | ---: | ---: |
| Scroll throughput | 26.963 fps | 7.989 fps | 28.202 fps | 8.719 fps |
| Median interval | 36.454 ms | 115.800 ms | 34.577 ms | 107.507 ms |
| p95 interval | 49.506 ms | 172.885 ms | 46.386 ms | 146.001 ms |
| Maximum interval | 97.708 ms | 264.108 ms | 88.143 ms | 167.947 ms |
| Intervals over 16.67 ms | 296/296 | 93/93 | 310/310 | 101/101 |
| Inputs / changed publications | 600 / 309 | 600 / 97 | 600 / 326 | 600 / 106 |
| Actual input delivery | 54.563 Hz | 51.459 Hz | 54.494 Hz | 51.711 Hz |
| First scroll publication delay | 106.628 ms | 293.888 ms | 105.408 ms | 388.898 ms |
| Final scroll publication gap | 22.935 ms | 37.912 ms | 39.679 ms | 40.613 ms |

All four runs are valid and exit zero. Every measured interval misses the
60 Hz deadline. The live scrolling problem is unresolved. The earlier 2.81%
and 3.27% gain belongs to the alternating frozen control/candidate experiment;
it cannot establish a gain for this newer production build, which includes
independent concurrent changes. These installed-bundle results must accompany
any report of the isolated improvement.

A separate five-second live sample identifies the next bottleneck: 1,227 of
4,070 main-thread samples enter `native_end_svg_mask_layer`, dominated by
Core Graphics mask-image drawing and transparency-layer composition. Opacity
layer work is also substantial (`native_end_css_effect_layer` has 443 samples
at the top of the stack). This diagnostic receives no performance credit.
The mask path already bounds transparency layers to the mask rectangle plus a
fringe; further work must preserve fractional mask coverage and nested clips.
No additional mask optimization is claimed by these measurements.

The integrated native test and its ASan/UBSan build each execute all 864 exact
GPU comparisons and the direct eligibility assertion successfully. The entire
serialized integration job exits zero, with sampled aggregate peak RSS of
7,605,125,120 bytes within the default 12 GiB budget. This is a sampled process
tree measurement, not a kernel allocation limit. No new retired-instruction
savings are measured or added to the broad verification counter.

Evidence under `Build/pikabu-live-lag-20261025/`:
`production-source-before-{0,1}.json`, `production-sparse-build-{0,1}.log`,
`integrated-stage-result.json`, `production-sparse-{signature,headless}.log`,
`production-sparse-{replay,live}-{1,2}/{run.json,summary.json,browser.log}`,
`production-sparse-live-sample.txt`, and `readiness-guard-v1.json`.

### Mask experiments rejected after integration (October 26)

No further mask change is installed. Reducing the mask's pixel format or
dimensions changes Quartz's fractional-edge sampling, even for an entirely
transparent image. Exact comparisons rejected A8, gray-plus-alpha, constant
one-pixel, and transparent-only one-pixel replacements. The transparent-only
replacement fails 132 of 1,536 DestinationIn scenes, despite passing all 1,536
ClipToMask scenes. The two operations require separate validation.

A sparse-image draw preserves the original image, rectangle, and boundary
bands, clearing transparent interiors and clipping image drawing to the
remaining support. It passes 3,072 exact comparisons and ASan/UBSan, including
fractional positioning, interpolation, nested effects, and fallback transforms.
Its first archived-page diagnostic records zero eligible draws, so the archive
timings receive no optimization credit. A later live diagnostic verifies 664
fast draws among 4,332 mask draws. The following alternating unprofiled trials
complete with the frozen production executable and libraries unchanged:

| Measurement | Control 1 | Candidate 1 | Control 2 | Candidate 2 |
| --- | ---: | ---: | ---: | ---: |
| Scroll throughput | 23.655 fps | 7.332 fps | 4.843 fps | 8.156 fps |
| Median interval | 42.345 ms | 108.727 ms | 183.460 ms | 119.326 ms |
| p95 interval | 54.470 ms | 173.174 ms | 270.276 ms | 158.638 ms |
| Maximum interval | 80.078 ms | 2,668.826 ms | 348.044 ms | 177.754 ms |
| Intervals over 16.67 ms | 264/264 | 105/105 | 63/63 | 95/95 |
| Inputs / changed publications | 600 / 276 | 600 / 108 | 600 / 67 | 600 / 99 |
| Actual input delivery | 53.673 Hz | 41.827 Hz | 46.049 Hz | 51.423 Hz |
| First scroll publication delay | 123.906 ms | 147.013 ms | 1,341.945 ms | 291.303 ms |
| Final scroll publication gap | 37.377 ms | 62.409 ms | 38.175 ms | 83.698 ms |

Each trial uses an independent empty cache/profile, the ambient proxy, a
20-second settle after the Pikabu title, and the same viewport and precise
input schedule as the installed checks. The endpoint and throughput denominator
are unchanged. Live responses vary between trials, and the control variation
is substantial. These results show no repeatable gain and do not justify
promoting the sparse draw. Replacing the complex clip with rectangular clips
also fails 96 exact DestinationIn comparisons involving an active shadow.
No performance trials follow those failed pixel checks.

The agent instructions now require a separate eligibility diagnostic before
timing a new fixture and verification of the actual executable's probe ranges.
An injected library can occupy dyld image zero. Earlier probes using that image
as the executable base produced false zero counters; those counters are
inconclusive. The corrected probe uses `_NSGetMachExecuteHeader()` and records
the actual mask path. An interrupted first live run is retained as invalid.
No frame-rate or retired-instruction improvement is credited to these experiments.

Evidence under `Build/pikabu-live-lag-20261025/`:
`alpha-mask/{a8,gray-alpha}*`,
`alpha-mask/{metrics-base.c,metrics-base/browser.log,metrics-base-guard.json}`,
`sparse-mask/{test.c,check-retry-guard.json,live-interrupted.json}`,
`sparse-mask/live-v2/{live-result.json,live-*/run.json,live-*/browser.log}`,
`sparse-mask/live-v2-guard.json`, and
`{rectangular-mask,constant-mask,clear-mask}/{test.c,check-guard.json}`.


### Input-window profile and pending exact-byte optimizations (October 26)

A separate diagnostic run starts the five-second sampling window only after
`SCROLL_START` on the live Pikabu document. The probe identifies the actual
executable with `_NSGetMachExecuteHeader()`; dyld image zero is the injected
measurement library. Its first 12 logged mask builds occur after scrolling
starts. Process-wide totals are 57 builds, 97 draws and 28,241,286 mask pixels;
those totals include the whole process and are not isolated input-window counts.
The input-window sample also includes raster-cache snapshot encoding, image
rasterization and rounded-rectangle GPU synchronization. This establishes work
to investigate, without assigning an unprofiled frame-rate gain to any change.

Two candidates preserve the existing pixel format and geometry: moving mask
format selection outside pixel loops to permit vectorization, and copying
raster-snapshot literal spans in bulk while preserving the encoded word stream.
Both implementations and their focused tests are committed. Mask conversion
passes 248 stride/tail/guard scenes, all 16,777,216 RGB triples, every alpha
value, and ASan/UBSan; the existing 16 CoreGraphics mask-layer scenes remain
exact. Snapshot encoding passes the existing replay and Graphite cache tests,
11 literal-boundary cases, 1,024 reference comparisons and ASan/UBSan. The
promoted header and tests match the private candidates exercised by those
checks. The complete focused-check guard exits zero, peaking at 560,037,888
sampled RSS bytes.

The first conversion/snapshot microbenchmarks are noisy under host contention
and include regressions as well as gains. They receive no optimization credit.
Production build, paired visual checks and native scrolling trials remain
pending behind the shared memory guard. The mask comparison freezes the
preprocessed browser translation unit and native libraries; both variants
include the snapshot change, so it cannot establish a snapshot FPS gain.
Neither candidate has scrolling optimization credit or establishes smooth
60 fps. New fixture
checks must count eligibility during input separately from startup and settling;
a path exercised only while loading cannot explain a scrolling timing change.

Evidence under `Build/pikabu-live-lag-20261025/cache-mask/`:
`profile-job.py`, `live-profile-v3/{run.json,browser.log,summary.json}`,
`live-profile-v3-{result.json,sample.txt}` and
`live-profile-v3-queued-guard.json`. The browser measurement, sample and guard
all exit zero. This is a profiled diagnostic, not an acceptance run.

Focused-check evidence under `Build/pikabu-live-lag-20261025/`: `mask-pixels-check-result.json`, `mask-pixels-full-check-guard.json`,
`mask-pixels-{normal,sanitizers,layers}.log`, `mask-pixels-bench.jsonl`,
`mask-pixels-bench-assembly.txt`, and
`snapshot-literals/{result.json,comparisons-and-bench.log,sanitizer.log,
promoted-source-sha256.json}`. The committed changes are `d5cf4d2b` and
`c57e75f0`; these identifiers describe implementation and correctness, not
acceptance of the scrolling target.


### CPU diagnostics and production compiler retry (October 26)

Separate CPU-time diagnostics complete successfully under the shared guard.
For the 1,492 by 1,696 mask, median thread CPU time across three pairs changes
from 1,203.171 to 287.585 microseconds for A8 conversion, 1,508.130 to
345.194 microseconds for RGBA alpha, and 2,308.801 to 383.402 microseconds
for luminance. These are conversion diagnostics, not scrolling measurements.
Snapshot construction improves on four of five diagnostic scenes, but the
uncompressible noise scene regresses from 435.995 to 464.917 microseconds
(6.63%). Retain that regression when assessing the change; the diagnostic does
not establish an application frame-rate gain.

The first production attempt exits one before compiling the browser because
`/Users/alex/code/v/v` lacks the bounded prealloc allocator required by the
production build. The guard exits one after 40.941 seconds, with 456,785,920
sampled peak RSS bytes. No visual or scrolling acceptance run follows that
failed build. A retry selects `/Users/alex/code/v-latest/v`, whose library has
the required allocator helper, and remains queued for build, paired visual
checks and native scrolling trials. Production settings remain unchanged.

The precise measurement tool now records CPU count, load averages and run
start/end timestamps in `run.json`; its 11 mocked Python checks pass. Agent
instructions require assessing contention and control variation before
attributing timing changes to code. Neither this tooling change nor the CPU
diagnostics closes the 60 fps target.

Evidence under `Build/pikabu-live-lag-20261025/`:
`mask-pixels-production-v1/{result.json,build.log,build-visual-guard.json,
mask-cpu-diagnostic.log,snapshot-cpu-diagnostic.log,
measurement-tool-focused-check.json}` and
`mask-pixels-production-v2/retry-reason.json`. The measurement-tool and
instruction commits are `9a27b77c` and `4baaa110`.
