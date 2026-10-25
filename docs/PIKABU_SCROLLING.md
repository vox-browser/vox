# Pikabu scrolling profile

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
