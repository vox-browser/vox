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
| Native document payload (DOM, styles, layout tree) | `platform.RetainedArena` | until document retirement and the last asynchronous/snapshot reader |
| Document/Window/context identity and general DOM API allocations | base arena | existing navigation/history and embedder lifetime |
| Recyclable persistent storage (retained buffers, handle sets, phase buckets) | base arena, reused in place | grows to the workload's high-water mark |
| Frame/pass scratch (transform resolution, refresh lists) | `platform.Arena`, reset after the pass | one pass |
| Animation samples | `css.AnimationSampleStorage` arenas | until no style, layout snapshot or live scene can reach them |
| Display-list scenes | `layout.DisplayListScene` arenas | until the layout result and every consumer released them |
| Native paint trees and style-to-paint projections | `layout.PaintTreeStorage` arenas | until the layout result, shell geometry and every scene released them |
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
- **Native documents** (`dom/native_document_storage.v`). The shell enables
  payload storage before parsing. Replacement navigation closes the old realm,
  cancels document tasks and resources, retires layout publishers, and releases
  the document's allocation owner. Scenes, geometry, active/deferred timers and
  worker completions retain that owner through their final read. Inert template
  and fragment documents share their containing document's allocation lifetime.
  Cross-document adoption and untracked host borrowing conservatively pin it.
  Process-wide caches, diagnostic maps and V closure bookkeeping stay outside
  these arenas; `tools/prepare_prealloc_runtime.py` stages the closure runtime
  used by the build without modifying the compiler checkout.
- **Cascade bookkeeping** (`css/cascade_scratch.v`). Private style passes lease
  reusable buffers, with a separate slot for each nested call. Only map heads,
  presence bits and entry records belong to these buffers. Declarations and
  computed values keep their own storage. Public cascade APIs still return
  independent results. The final document reader releases the scratch arenas.
- **Intrinsic probes** (`layout/measurement_scratch.v`). Native document layout
  reuses a scratch arena at each nested probe depth. Scalar results are consumed
  before release. Text, font, intrinsic-size and table caches that survive a
  probe own their backing data outside it. The layout pass closes the pool.
- **Ordinary geometry** (`layout/document_geometry_scratch.v`). Native block,
  flex and grid work runs in a temporary scope. Used-value pages, rare data,
  retained snapshots and grid metadata allocate back into the entered document
  through `platform.enter_retained_allocations()`. Nested intrinsic probes
  retain their shorter lifetime. Inline, table and SVG construction currently
  stay durable as complete operations; their internal temporaries remain a
  later target. The scope closes before publishing the DOM geometry attachment.
- **Font keys and stylesheet tokens**. Font-cache key formatting reuses an arena;
  a miss copies its key before reset. Background font computers keep their
  ordinary allocation path. Native stylesheet tokenization releases raw token
  builders after copying the complete immutable component tree into its owner.
  This does not yet retire the rule parser's intermediate syntax trees.
- **Native graphics**. Each Skia GPU context has a 64 MiB resource-cache budget.
  Native maintenance retires contexts after two seconds without GPU raster work,
  including on scripted pages, while preserving reusable CPU raster results.
  Live Ganesh image/surface references keep their context alive. The default
  filtering VM is similarly released after five seconds without an evaluation;
  the next uncached filtering request recreates it under the evaluation lock.
- **Display-list scenes** (`layout/display_list_scene.v`). A recording enters a
  scene arena from the document's pool. The layout result holds one reference;
  the shell retains the scene it adopted (`retain_display_list_scene`) and
  releases it when it adopts the next. A released scene is reset and kept as a
  spare (at most two). Documents whose commands a host copies into its own
  paint data (nested viewports) record into ordinary storage. Recording copies
  command records; payloads stay owned by the retained phase caches.
- **Native paint trees** (`layout/paint_tree_storage.v`). The native shell opts
  its documents into recycling before script execution can force layout. The
  contiguous `BlockBox` array and its projection payloads live in the tree arena.
  Reusable geometry/paint templates own their backing storage independently.
  SVG resource dependency lists belong to the document rather than a projection.
  The committed layout result, adopted shell geometry,
  and each display-list scene hold separate references. Replacing geometry or
  releasing a scene drops its reference; the final release resets the arena.
  A document keeps at most two reset spares. General layout APIs retain their
  existing snapshot lifetime, and host-borrowed documents remain unpooled.
- **Recording buffers**. The shell updates its raster-layer plan in place,
  retaining command vectors for temporarily inactive layers. Property/chunk
  scratch and scroll/fixed lookup maps also retain capacity. MSAA preparation
  reuses its triggers, layer groups, native tile vectors, grid maps and cell
  vectors; native setters copy those vectors before returning. Gradient replay
  reuses sampled stops, GPU stops and clip-path vectors across commands and
  frames, and color-only gradients no longer materialize fallback stop arrays
  for each interpolation sample.
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
6. A geometry snapshot from a document opted into native paint-tree recycling
   holds `retain_document_paint_tree()` until `release_paint_tree()`. Retain
   before replacing the previous snapshot, then release its handle. Scenes
   retain projections independently. The `paint tree projections` poison label
   covers both the slots and the payloads produced for that projection.

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

Two other implicit allocations matter on replay paths. Current V's
`i32.sort()` and `sort_with_compare()` reserve a merge buffer; collecting
unique tile indices in sorted order avoids that buffer. Constructing a
sum-type variant boxes its payload, including an enum used as an `or`
fallback. Gradient sampling shares one immutable sRGB default instead of
constructing it for every sample.

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

### Buffer reuse and tree retirement, 2026-10-20

`e09ac3ff`, `6217d8a8` and `fa517eaf` add reused raster-plan output, MSAA and
gradient buffers, then reference-counted native paint-tree slots. Current V
`0.5.2 1e63d0f` built the optimized prealloc bundle. Historical `memrun.py` runs
used the same Pikabu cache and network guard, a 1024×880 window,
JavaScript enabled, no scrolling, and 60 seconds per process:

These runs inherited ambient loopback proxy settings. The guard permits
loopback connections, so those proxies could fetch live refreshed content.
They are historical mixed cache/live measurements, **not verified offline
comparisons**. Do not compare them directly with a frozen Brave replay.

| Build | RSS at 30 s (MiB) | RSS at 60 s (MiB) | Idle RSS slope (MiB/s) |
| --- | ---: | ---: | ---: |
| Saved prealloc baseline | 2105.6 | 2169.7 | 1.69 |
| Reused buffers and retired tree slots | 1982.7 | 2012.2 | 0.55 |
| Saved Boehm reference | 934.2 | 938.5 | 0.13 |

The slopes are linear fits over samples from 20 to 60 seconds. Final physical
footprints were 2389, 2223 and 1132 MiB respectively. The measurement helper
terminated each browser normally for this experiment (`SIGTERM`, exit -15).
This reduces idle growth by about 68%, but still leaves growing memory and a
large gap to Boehm. It does not justify changing the default allocator.
Binary hashes, compiler and source identity, raw samples and logs are retained
under `Build/prealloc-reuse/`, including `metadata.json`,
`memory-summary.json`, `before.json`, `after.json` and
`boehm-reference.json`.

The raster-plan, MSAA and gradient reuse checks require zero base-arena growth
after warm-up. They pass under prealloc, including arena poisoning; the
recording behavior checks also pass under Boehm. Native tree and shell tests
cover retained old geometry and scenes, layout and paint-only replacements,
deferred recording, hit-test refresh and tab disposal. They pass with normal
arena reuse and poisoning. A 240-frame native Pikabu idle run also completes
with `VOX_ARENA_POISON=1`.
The two new shell lifetime cases and ten existing frame cases also pass under
Boehm, separately from its GC-worker check below.

All visual checks use the final optimized prealloc bundle and arena poisoning.
The four targeted gradient/SVG reftests are pixel-exact (`css-gradient-currentcolor`,
`css-gradient-negative-first-stop`, `svg-gradient-in-defs-removed-repaint`, and
`svg/gradient-stop-move-before`). The default smoke suite has six exact passes,
one pass within its existing canvas allowance, and four upstream-reference
failures: `inline-node`, `ordered-list`, `text-decorations`, and
`default-ignorable-code-points-not-painted`. Capturing those four through the
saved prealloc baseline gives identical decoded pixels to the final bundle;
no tolerance was changed. Receipts and images are in `screenshots.log`,
`gradient-screenshots.log` and `screenshot-baseline-proof.log` under the same
artifact directory.

Broader checks have separate limits: `layout/typed_paint_arena_test.v` reached
the compiler's 10 GiB footprint cap while compiling its whole-struct string
comparisons; an unrestricted retry was stopped after compiler RSS exceeded
35 GiB. The broader Boehm retirement test needs `-D_VGCBOEHM` to expose its
legacy C helper, then exhausts that helper's worker stack in generated
`__v3_sum_eq_css__StyleValue`. Neither check receives broad pass credit. The
previously reported `css/native_style_scope_retirement_test.v` failure is
unchanged.

### Reproducible Brave comparison

`tools/pikabu_browser_memory.py` clears inherited proxies and runtime overrides,
uses a fresh cache/profile per trial, and counts the simultaneous physical
footprint of the whole process tree, including GPU and filtering helpers.
Brave uses default Shields without extra extensions. Both execute author
JavaScript against the same archived responses. Missing responses fail closed.
The offline native page may install only once; replacement safety is tested
with explicit navigation, rather than requiring an unavailable live refresh.

```sh
python3 tools/pikabu_browser_memory.py \
  --cache Build/pikabu-instructions-cache-final \
  --network-deny Build/pikabu-instructions-network-deny.dylib \
  --output Build/prealloc-comparison --trials 3 --seconds 60
```

The comparison alternates launch order, verifies foreground focus, retains
binary/runtime identities and samples, and requires every Vox trial to be below
every Brave trial. A one-shot observer captures the normally active Vox window
and reads its retained DOM immediately after the memory endpoint. It does not
enable screenshot document mode. Both captures use the display's pixel density.
The endpoint must still have the frozen URL, a nonempty title, complete readiness,
paint commands and story elements; an initial successful paint followed by an
empty replacement is rejected. The verified Brave reference on 2026-10-20 was 454.6 MiB of
settled process-tree physical footprint with 15 stories loaded. Diagnostic Vox
builds still exceed that target; no claim of beating Brave is established yet.

The clean optimized build retained at `Build/prealloc-document/app-document-16`
settled at 1113.3 MiB over 60 seconds; its fitted latter-half growth was about
0.47 MiB/s (`native-16-memory/1-vox/result.json`). This predates the font-key,
tokenizer, ordinary-geometry and replay changes. Later poisoned/O0 runs validate
ownership and content; their totals are not optimized allocator comparisons.

A temporary CPU-only graphics diagnostic on the same frozen page removed the
roughly 326 MiB category reported as unmapped graphics ownership. It establishes
that the GPU path contributes that cost, rather than a V document arena. It is
not a production renderer change or a visual-conformance result. Existing Skia
context/cache cleanup does not return all of this process-attributed memory.

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
- Gradient tile enumeration, nested/SVG replay transformations and other shell
  replay temporaries still need allocation profiling. Reusing the plan, MSAA
  and gradient data vectors does not bound every recording allocation.
- Single-load parsing, style and layout temporaries still inflate a native
  document's high-water mark. Typed layout trees and committed geometry need
  finer retirement than the complete document lifetime. Native identity
  allocations and conservatively pinned adoption/host cases also retain their
  existing lifetime. `VOX_PHASE_DIAGNOSTICS=1` prints allocation-phase totals.
