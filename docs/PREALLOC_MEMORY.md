# Bounded memory under `-prealloc`

`LADYBIRD_V_GC=prealloc sh build-prod-browser.sh` builds Vox with V's
`-prealloc` allocator instead of the Boehm collector. Every thread allocates by
bumping a pointer through its arena; `free()` does nothing. Memory comes back
only when a whole arena is reset or released, so the rule for every piece of
retained state is: for a fixed live workload, retained memory must stop
growing after warm-up, however many frames or replacements happen.

Boehm remains the default build. This document records what the `-prealloc`
build already bounds, the contracts code must follow, how to measure it, and
what remains before it can become the default.

## Ownership classes

| Class | Storage | Lifetime |
| --- | --- | --- |
| Document-owned state (DOM, styles, layout tree) | thread base arena | process (document teardown is not reclaimed yet) |
| Recyclable persistent storage (retained buffers, handle sets, phase buckets) | base arena, reused in place | grows to the workload's high-water mark |
| Frame/pass scratch (transform resolution, refresh lists) | `platform.Arena`, reset after the pass | one pass |
| Animation samples | `css.AnimationSampleStorage` arenas | until no style, layout snapshot or live scene can reach them |
| Display-list scenes | `layout.DisplayListScene` arenas | until the layout result and every consumer released them |
| Shared caches (fonts, parsed values, images) | base arena via `platform.enter_persistent()` | process |

Allocated during a frame does not mean safe to discard at the end of that
frame: each arena is reset only after its last reader has let go.

## Mechanisms

- `platform/prealloc_arena.v` wraps V's scoped arenas. `Arena.enter()` routes the
  thread's allocations into the arena until `leave()`; `reset()` reuses its
  blocks (a multi-block arena is remapped as one block sized from its
  high-water mark); `release()` returns them. `enter_persistent()` temporarily
  routes allocations back to the thread's base arena: every cache fill or
  install into longer-lived state that can run inside an arena must use it.
  Outside `-prealloc` all of this is inert and the collector owns everything.
- Threads that hand results to the UI thread (fetch, preload and thread-pool
  workers) call `platform.retain_thread_allocations()` first, so their
  allocations survive the thread's exit.
- **Display-list scenes** (`layout/display_list_scene.v`). A recording enters a
  scene arena from the document's pool. The layout result holds one reference;
  the shell retains the scene it adopted (`retain_display_list_scene`) and
  releases it when it adopts the next. A released scene is reset and kept as a
  spare (at most two). Documents whose commands a host copies into its own
  paint data (nested viewports) record into ordinary storage. Recording copies
  command records; payloads stay owned by the retained phase caches.
- **Animation samples** (`css/animation_samples.v`). Keyframe values,
  interpolated results, and everything derived from them for the target's
  layout snapshot are allocated in the current sample arena. Installing a
  sample into a retained style goes through `enter_persistent()` for the map
  entry while the value itself stays a sample. When the arena has seen enough
  sample bytes (adaptively, from recent per-update volume) it starts a new one;
  the old arena is reset only after every target's style, DOM mirror, custom
  property data and layout snapshot have been rewritten from newer samples,
  layout has run, and no live scene was recorded before that point.
- **Layout snapshots** (`css/computed_layout_cache.v`). Outside animation
  frames a snapshot is copy-on-write, as before. While an animation frame
  restyles its target (`begin_layout_cache_reuse`), the style rewrites its own
  snapshot in place; code that copies a style by value must call
  `share_computed_layout_cache()` first.
- **Visual contexts**. Compositor-only samples patch transform and opacity in
  the existing accumulated visual-context tree instead of rebuilding it; the
  topology is rebuilt only when a sample changes box categories.
- **Per-frame churn removed**: per-frame client event logs, empty map/array
  temporaries, `in [...]` literal arrays on hot paths (the compatibility
  compiler allocates them), unchanged scroll snapshots, idle channel selects,
  rebuilt counter styles, cloned animation maps.

## Contracts

1. Nothing that outlives an arena may point into it. Lazy cache fills and
   installs reached from arena code use `enter_persistent()`.
2. A consumer that keeps a display list beyond the next recording retains its
   scene (tests use `record_retained_display_list`).
3. A value copy of `ComputedProperties` shares its layout snapshot; call
   `share_computed_layout_cache()` before copying.
4. `VOX_ARENA_POISON=1` write-protects reset and released blocks instead of
   reusing them, so a stale pointer faults at its first use.

## Measuring

- `layout/prealloc_bounded_frames_test.v` (run with `-prealloc`) requires
  transform and pseudo-element transform animations to add at most 256 bytes
  of persistent storage per frame after warm-up and to keep one live scene.
- `VOX_PREALLOC_SAMPLER=1 LADYBIRD_V_GC=prealloc sh build-prod-browser.sh`
  links `tools/prealloc_allocation_sampler.c`, which samples allocations from
  thread base arenas (never reclaimed) when the V allocator provides the
  `prealloc_alloc_hook` callback. Report sites with
  `python3 tools/gc_allocation_report.py --mode stack REPORT`.
- `tools/measure_browser_scroll.py --idle` profiles frames without wheel input;
  the browser log's `allocated_kb` is base-arena growth per frame and
  `arena_mb`/`arena_blocks` the thread's arena totals.

Pikabu (offline cache, 1024×880, idle animations, 600 frames): the profile's
base-arena growth fell from about 587 KB per frame before this work to about
5 KB per frame; the sampler attributes what remains to shell replay
temporaries, CSS animation events and the hidden-target animation query.

## Remaining work before `-prealloc` becomes the default

- Repaint animations (opacity, colors, gradients) still re-record retained
  phase-cache entries and rebuild paint plans; their payloads need
  generation-retired storage like samples and scenes. Opacity changes that do
  not cross zero can scale cached commands at replay instead.
- Layout-affecting animations rebuild layout state every frame.
- Shell replay (`draw_command`) still allocates small per-frame temporaries.
- Document teardown: navigation, reload and tab close do not reclaim the old
  document's storage; documents need their own arenas and fetch threads need an
  owner for the allocations they retain.
- The compatibility compiler's V runtime must provide a `realloc` that copies
  only the old allocation's size under `-prealloc`; current V does.
