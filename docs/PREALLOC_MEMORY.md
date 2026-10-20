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

- `platform/prealloc_arena.v` wraps V's scoped arenas through the prealloc
  scope API of current V (the 0.5.2 compatibility compiler lacks it).
  `Arena.enter()` routes the thread's allocations into the arena until
  `leave()`; `reset()` rewinds it, keeping the blocks that cover a quarter more
  than its high-water mark; `release()` returns them. `enter_persistent()` temporarily
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
- **Viewport culling**. Viewport recordings resolve the visual contexts they
  need to cull offscreen entries in a scratch arena reset after culling, and
  keep the selection in a buffer retained with the recording scratch.
- **Shared caches**. Process-wide font caches (decoded faces, glyph units,
  system matches and fallbacks, HarfBuzz faces and scaled fonts, shaped runs)
  and cached native font handles fill their misses in persistent sections. A
  persistent section entered inside another leaves allocations where they go.
- **Sampled background layers**. An animation frame re-resolves its target's
  whole layout snapshot into the sample arena, including layers that do not
  animate. A paint box can outlive that arena, so it copies sampled layers
  into ordinary storage when it is built.
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
4. Paint data copied from a style must not point into its samples: retained
   boxes outlive the sample arena that a style was resolved in.
5. `VOX_ARENA_POISON=1` write-protects reset and released blocks instead of
   reusing them, so a stale pointer faults at its first use; the fault names
   the arena. `VOX_ARENA_NO_REUSE=label,...` poisons only the named arenas.

## Heap copies inserted by current V

Current V moves a by-value local or parameter to the heap (`memdup`) when it
cannot prove that an address taken from it stays inside the call. Under
`-prealloc` each copy is never freed, so one in a per-command or per-element
path grows memory every frame. Patterns that trigger it, and what to write
instead:

- Calling a `&` method on a by-value value whose type holds an inline fixed
  array (`layout.PaintCommand.transform`, `css.ComputedProperties`, a struct
  with `[N]T`): read the public payload fields directly (`command.svg_data`,
  `command.image_data`), or pass the command by reference.
- Returning a pointer reached through such a call, including through a
  pointer field of a by-value value (`return value.ptr_field.method()`): read
  the pointer field into a local first (`element := value.element_`).
- A by-value copy of a `@[heap]` struct: every local and loop copy is
  allocated on the heap. Do not declare small value records such as
  `dom.CSSCustomProperty_` `@[heap]`.
- Iterating an array field of a by-value parameter and appending the loop
  values elsewhere: index the array instead.

`v -warn-about-allocs` lists most of these copies with their reason and
position. To check a function, generate C (`v -o out.c` with the build's
`-path`) and look for `memdup(&__esc_` and `memdup(&__heap_value_param_` in its
body. The sampler shows an inlined copy as an allocation by the function itself.

## Measuring

- `layout/prealloc_bounded_frames_test.v` requires transform and
  pseudo-element transform animations to add at most 256 bytes of persistent
  storage per frame after warm-up and to keep one live scene, for complete and
  for viewport recordings. Run it with `-prealloc -gc none`: V keeps its
  default collector selected under `-prealloc` alone.
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
Viewport culling later added about 700 KB per frame until its storage was
retained (2026-10-19, `Build/pikabu-instructions-cache-final`, 400 frames:
median 5 KB, maximum 42 KB per frame after warm-up). Thirty poisoned runs
found no stale arena access after the font-cache and background-layer fixes.

## Remaining work before `-prealloc` becomes the default

- Opacity samples that stay nonzero keep the paint plan and phase cache;
  replay scales the cached commands. Background-color, color and
  outline-color samples refresh only their boxes in the retained paint tree,
  and only animated values a descendant can observe (inherited properties,
  or explicit `inherit`) revisit descendants. Each sample still re-records
  the animated box's phase commands (about 2.5 KB per animated box per frame
  for a background-color sample); those payloads need generation-retired
  storage like samples and scenes.
- Inherited samples rerun the full property computation for descendants
  with inheritance-dependent values such as `bolder` or `em` lengths (about
  48 KB per animated element per frame with one such child).
- Other paint-only animations (gradients, background-position, shadows)
  still rebuild the whole paint tree on every sample.
- Layout-affecting animations rebuild layout state every frame.
- Shell replay (`draw_command`) still allocates small per-frame temporaries.
- Paint boxes copy other snapshot data besides background layers. An
  animation frame resolves its target's whole snapshot into the sample arena;
  resolving only animated values there would remove that hazard and most
  sample bytes.
- Recording still rebuilds the Chromium raster-layer plan, MSAA tiles and
  gradient stop and clip buffers from scratch (about 6 MB/s on an idle Pikabu
  on 2026-10-20, after its heap copies were removed); they need reused
  storage or a per-recording arena.
- Document teardown: navigation, reload and tab close do not reclaim the old
  document's storage; documents need their own arenas and fetch threads need an
  owner for the allocations they retain. A Pikabu visit with a cached copy
  installs the cached document and then the refreshed one, and each install
  grows the base arena by about 800 MB (HTML 49 MB, style sheets 82 MB, the
  first style pass 137 MB, about 27 paint-tree rebuilds of 11 MB, layouts);
  `VOX_PHASE_DIAGNOSTICS=1` builds print these `PHASE` lines.
