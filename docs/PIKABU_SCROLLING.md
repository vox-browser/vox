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
