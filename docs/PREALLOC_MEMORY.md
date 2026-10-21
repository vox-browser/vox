# Bounded memory under `-prealloc`

The macOS browser build defaults to V's `-prealloc` allocator. Set
`LADYBIRD_V_GC=boehm` to build with the Boehm collector. Every prealloc thread allocates by
bumping a pointer through its arena; `free()` does nothing. Memory comes back
only when a whole arena is reset or released, so the rule for every piece of
retained state is: for a fixed live workload, retained memory must stop
growing after warm-up, however many frames or replacements happen.

This document records what the `-prealloc` build already bounds, the contracts
code must follow, how to measure it, and what remains to meet the RAM target.
The default has changed; beating Brave has not yet been demonstrated.

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
  than its high-water mark. When retained capacity reaches one MiB, reset also
  discards complete mmap payload pages, preserving virtual capacity and addresses
  without keeping their dirty physical backing. Small arenas keep warm pages;
  poison mode keeps its protected mappings. `release()` returns the blocks.
  `enter_persistent()` temporarily
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
  stay durable as complete operations. A flex algorithm invoked from retained
  inline construction opens its own workspace; its published used values, grid
  metadata and child lines still belong to the document. Existing workspaces
  and intrinsic probes keep their enclosing lifetime. Other temporaries inside
  those durable operations remain a later target. The outer scope closes
  before publishing the DOM geometry attachment.
- **Font inputs and keys**. Family lists, bridge-value parsing, variation/feature
  maps and key formatting use reusable arenas. Nested font lookups have separate
  input slots. Cache misses materialize their cascade and map/key in the owning
  document, or persistent storage for standalone callers, before resetting the
  inputs. Worker computers retain their ordinary allocation path. Document
  teardown releases both input and key arenas.
- **Stylesheet input and rule syntax**. Tokenization releases raw token builders
  after copying the immutable component tree into its owner. Component copies
  return directly from each sum-type branch, avoiding an unused default Function
  per token. Native whole-stylesheet parsing then retires its intermediate rule
  and declaration vectors after conversion. Declaration values borrow immutable
  token spans; deferred rules own their declaration records and original strings.
  Prelude spans which query parsers may keep are copied before retirement.
  CSSOM single-rule and fragment parsing keep their ordinary allocation path.
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
- **Native replay** (`main_native_replay_scratch.v`). Command replay enters a
  reusable arena after frame preparation and MSAA planning. The enclosing
  compositing layer and deferred rounded-rectangle underlay finish before reset.
  Nested SVG replay shares that frame lifetime. Image/color caches, gradient
  buffers and cached SVG layouts fill in durable storage. Browser input delivered
  at a cooperative checkpoint also allocates outside the current paint scope.
  Tab disposal releases the replay arena.
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
- Appending an optional binding directly (`if declaration := ... { list <<
  declaration }`): current V inserts `__derived_clone_*`, including string and
  array clones. A record literal with explicit fields preserves borrowed token
  spans and their original owner. Otherwise a temporary parser arena can become
  the accidental owner of a deferred declaration's name and value array.
- Assigning a sum-type match expression: generated C may allocate the first
  variant as a default before overwriting it. `ComponentValuePayload` starts
  with Function, so that default is substantially larger than an ordinary Token.
  A helper which returns directly from each match branch avoids the default.

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
large gap to Boehm. That experiment alone did not establish allocator readiness.
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

The next clean optimized build, `app-document-23`, settled at 1095.9 MiB with
about 0.248 MiB/s latter-half growth over 60 seconds
(`native-23-clean-memory/1-vox/result.json`). Its endpoint audit confirms the
Pikabu URL/title, complete readiness, 15 stories and 34 story images. This build
includes geometry and replay retirement, but predates the last lazy SVG style
ownership fix. Eight selected live SVG reftests subsequently compare exactly
with poisoning in `replay-24-svg/results.json`; these are O0 correctness checks.

A temporary CPU-only graphics diagnostic on the same frozen page removed the
roughly 326 MiB category reported as unmapped graphics ownership. It establishes
that the GPU path contributes that cost, rather than a V document arena. It is
not a production renderer change or a visual-conformance result. Existing Skia
context/cache cleanup does not return all of this process-attributed memory.

## Remaining work toward the RAM target

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
- Frame preparation, event dispatch and browser chrome still allocate outside
  the bounded native command-replay workspace; idle growth remains measurable.
- Paint boxes copy other snapshot data besides background layers. An
  animation frame resolves its target's whole snapshot into the sample arena;
  resolving only animated values there would remove that hazard and most
  sample bytes.
- Recording and non-native replay temporaries still need allocation profiling.
  Bounding native command replay does not bound every frame-preparation path.
- Single-load parsing, style and layout temporaries still inflate a native
  document's high-water mark. Typed layout trees and committed geometry need
  finer retirement than the complete document lifetime. Native identity
  allocations and conservatively pinned adoption/host cases also retain their
  existing lifetime. `VOX_PHASE_DIAGNOSTICS=1` prints allocation-phase totals.


### Parser and font input follow-up, 2026-10-21

Font lookup input reuse, direct listener membership queries, rule-syntax
retirement and component-copy changes have focused prealloc and poisoned checks.
The parser checks include deferred/eager nested rules and a large single media
block containing discarded syntax; the latter catches an accidentally bypassed
scratch path. Font checks exercise nested lookups, document retirement and a
worker which must not enter UI arenas. Repeating a warm font lookup 256 times
adds less than 1 KiB of persistent storage. Component-copy checks bound each
leaf to its component slot, actual Token payload, spelling and alignment.
Boehm checks also cover parser and font behavior.

A separate graphics-helper prototype retained the existing GPU draw results
(2,920 image comparisons and 14 draw/lifecycle comparisons), but live animation
kept producing new cache misses. Its full process-tree footprint increased,
so the helper was removed from the source and build. The prototype and measured
logs remain under `Build/prealloc-document/`; it is not an enabled renderer.

These ownership and allocation checks do not establish the browser RAM target.
An earlier validated clean optimized Pikabu endpoint is 934.6 MiB
(`native-89-optimized-foreground/1-vox/result.json`), with a latter-half slope
of 135.2 KiB/s. The foreground checks pass and its completed document retains
15 stories and 34 story images. It remains above the 454.6 MiB Brave reference.
This includes the parent block-chain repair below. A diagnostic run of an earlier binary
faulted in `native_replay_font_path`; that run supplied allocation samples,
not a valid memory endpoint. Prealloc is the macOS default while the RAM target
remains unmet.

### Parent block chains and small idle allocations

A temporary V scope saves its parent's `next` block before entering. Redirected
document allocations can grow that parent while the temporary scope is active.
Restoring the original saved link on exit disconnected the newly grown document
blocks, so document retirement could not free them. `ThreadScratchScope` now
preserves the grown parent chain before leaving the raw V scope. A block census
previously counted 362,452,187 document bytes but could reach only 231,673,118
through the owner's chain. After the repair, the census and owner both reach
all 328,900,923 bytes in the corresponding diagnostic run. These runs include
instrumentation and are not clean production RAM comparisons.

The focused parent-growth regression creates three six-MiB allocations across
nested temporary scopes. It checks every original allocation remains in the
owner chain, then checks their actual OS mappings disappear at retirement.
Normal and poison modes pass. The full frozen Pikabu page also completes a
60-second normal-window poison run with a valid endpoint document after this
repair (`native-38-poison-memory/1-vox/result.json`).

SVG numeric scanning borrows its synchronous number span instead of copying
each substring; `viewBox` parses into four fixed coordinates. A 1,024-read
allocation check stays below one KiB in normal and poison modes, with the
existing accepted/rejected numeric syntax preserved. Animation sample retirement
also transfers spare target vectors in a record: appending a nested array had
copied the backing store which the pool intended to reuse. Repeated retirement
checks preserve the original pointer and capacity in both modes.

### Document caches, style indexes and native idle polling

Retained inline/block paint templates, UTF-16 and grapheme vectors, cached text
chunks and intrinsic shape vectors now use their native document's allocation
owner. They previously escaped temporary layout/paint storage into the process
base arena. SVG image documents can be visited inside another document's work:
the redirect is used only when the cache's document matches the entered owner.
Foreign and unowned caches retain independent persistent storage. Focused normal
and poison checks verify both ownership directions, retained-scene reads after
document retirement, and complete arena release after pending callbacks drain.

The computed-property page interner now has a separate reusable index arena.
Only map bookkeeping goes there; published pages and style values retain their
original owners. The outer style batch retires the index and document teardown
releases its storage. Nested-batch and published-page reads pass under prealloc,
poison and Boehm, alongside the existing page sharing and collection checks.

Native graphics maintenance originally checked one second after a frame, while
the backends require two seconds without GPU work before releasing a context.
The final check could therefore be too early with no later frame to schedule
another one. Idle retirement now reports a still-live context explicitly and
maintenance retries until retirement completes. It stops polling once all
contexts are gone. Dispatcher checks cover coalescing, busy drawing and the
absence of subsequent frames. Fourteen graphics lifetime comparisons and 3,040
GPU pixel comparisons pass.

The combined document-cache and interner build completes frozen Pikabu for 60
seconds normally and with `VOX_ARENA_POISON=1` in non-screenshot windows
(`native-54-checks-background` and `native-54-poison-background`). These are O0
ownership checks without the foreground comparison gate, not production RAM
results. Eight live SVG mutation reftests and both canonical turbulence images
remain pixel-exact under poisoning in `replay-54-svg/results.json`.

Native graphics still need substantial work. A standalone 64-by-64 draw accounts
for roughly 300--327 MiB of additional physical footprint immediately after
submission, with either Metal or Dawn; resident bytes alone hide most of that
cost. Further probes show automatic retirement after GPU activity stops: a raw
Metal clear falls from about 181 to 10.5 MiB after three seconds while its
device, queue and texture remain alive (`metal-clear-79.log`). The tiny Skia draw
similarly falls to about 11 MiB without explicit context destruction
(`metal-allocation-78-footprint.txt`). Active workload and context lifetime both
need checking. Larger CPU raster-cache budgets and a smaller
Metal command-queue capacity did not establish a full-page RAM improvement and
were reverted. Pikabu has running tag shimmers and loading animations, so a
static-page microbenchmark cannot establish its idle behavior. Recent
foreground attempts lost focus or were interrupted and do not replace the
validated optimized endpoint above.

### Anonymous inheritance and property-page publication

Anonymous layout wrappers keep a proof of their last inherited source and
destination. Immutable layout-cache identities, raw mutation epochs, property
flags, fonts, viewport/root metrics and counter definitions must still match
before propagation can skip another wide cache copy. Capturing the proof
freezes the observed caches, including against a later animation reuse. Font
inheritance also preserves the font-computer owner of its inherited list.
Focused CSS tests pass with prealloc, poisoning and Boehm. The layout integration
check propagates 1,024 times within eight KiB of document growth, then checks
source and destination mutations plus complete document retirement.

Native style batches also reuse exclusive property pages discarded when
publication finds an identical canonical page. Independent raw-store clones
clear the writable bits, so their shared pages cannot enter the free list.
The bounded list belongs to one document, survives index-arena resets, and
uses epochs to exclude styles retained from an earlier batch. Sample/scratch
allocations keep their existing owner. The combined page-sharing, collection,
index-retirement and recycling tests pass normally, under poisoning, and with
Boehm.

Script video discovery borrows candidate substrings while checking their
extensions and copies only returned references. Frame-time discovery scans
scripts in reverse order instead of joining their complete sources. A focused
allocation check scans roughly 2.8 MiB of irrelevant literals four times within
16 KiB of additional arena use; returned references remain independent of a
later overwrite of the input. Prealloc and Boehm checks preserve the previous
quote, extension, ordering, deduplication and last-literal-match behavior.

Canvas culling now operates through ordinary opacity scopes while preserving
filter/resource inputs. Complete offscreen effect and text-clip groups can be
discarded when their final output bounds prove them invisible. The inheritance
and culling build completes frozen Pikabu for 60 seconds normally and under
poisoning (`native-76-checks-background`, `native-76-poison-background`); all ten
SVG/image mutation and turbulence comparisons remain pixel-exact in
`replay-76-svg/results.json`. These checks do not establish the RAM target. The
optimized foreground attempt was interrupted by repeated new-tab actions and
then faulted in a PageClient rendering callback; its endpoint is invalid.

### Shared UA indexes, parser buffers and animation event delivery

Immutable selector indexes for process-lifetime UA stylesheets are shared across
documents and shadow roots. The bounded eight-entry template cache checks exact
sheet identities, revisions, media effectiveness and effective rule order; each
document retains its own wrapper and invalidation state. An empty view-transition
sheet does not prevent sharing, but its first rule does. Mutation, capacity,
document retirement and full computed-longhand comparisons pass with prealloc,
poisoning and Boehm. This establishes ownership and behavior, not a page RAM win.

HTML tokenization reuses character and entity buffers. ASCII output allocates
only its final owned string. Streamed character references retain one rewind
position per consumed code point until a token is delivered, fixing source
positions when a reference pauses across input chunks. The complete tokenizer
selection and focused allocation checks pass in all three modes.

SVG background replay uses a value iterator instead of materializing a tile
vector. Exhaustive geometry/repeat/limit comparisons preserve the previous tile
order, and nested traversals stay within the focused allocation bound. CSS
animation and transition queues likewise keep event metadata until delivery;
they construct an Event only when the current delivery path has listeners.
Late listeners, event identity, sorting and the original creation timestamp are
preserved. Focused prealloc, poison and Boehm checks pass for both changes.

### Physical pages retained by reset arenas

Resetting a large arena now discards its dead payload's complete OS pages.
Darwin replaces those anonymous pages in place because MADV_DONTNEED alone
leaves their dirty backing charged; Linux uses MADV_DONTNEED. Allocator metadata
and address reservations survive. A four-MiB test verifies the kernel reports
less than 512 KiB resident after reset, then refills the same addresses while
preserving capacity. Existing arena tests and the new check pass normally,
under poisoning and with Boehm.

The combined browser completes normal and poisoned headless startup checks and
a full 60-second Pikabu poison run with one installation, 15 stories and 34
story images (`native-117-poison-background`). All eight SVG/image mutation
reftests and both turbulence images remain pixel-exact under poisoning in
`replay-117-svg/results.json`.

The latest completed clean optimized foreground measurement before these later
buffer/parser/event changes is **1065.9 MiB**, with a latter-half physical-footprint
slope of **2496.3 KiB/s** (`native-95-optimized-foreground/1-vox/result.json`).
It passes all 59 focus checks and the endpoint document checks, but regresses
from the earlier 934.6 MiB result and remains above Brave's 454.6 MiB reference.
Background, poison, sampler and context-retirement experiments do not replace
that primary result. A raw Metal queue probe also finds essentially the same
181 MiB active footprint at command-buffer limits 1, 4, 8 and 64
(`metal-queue-119-count-*.log`); no queue-limit change is justified by that probe.


### Completed Metal queues and native idle checks

Graphite now keeps a stable queue adapter with its Context and compiled
pipelines, but releases the real Metal command queue after the native frame
completes synchronously. The next GPU frame creates another queue. Command
buffers keep their own queue references; no GPU resource crosses the CPU-pixel
readback bridge. Labels and residency-set membership survive replacement.
An unused backend is not loaded by frame completion. Two-second idle context
retirement still runs when only CPU raster-cache hits remain.

A raw Metal ownership probe distinguishes the queue from textures: releasing
only the queue drops an active clear from about 181 MiB to 8.9 MiB after 20 ms,
then 6.7 MiB after 220 ms. Releasing only the texture leaves about 181 MiB
until the driver retires idle work (`metal-partial-release-127-*.log`).
Keeping one persistent Skia recorder increased full-page RAM and was rejected;
the production renderer retains its per-call recorders.

The optimized queue build completes the frozen Pikabu background diagnostic
at **527.1 MiB**, with **307.3 KiB/s** latter-half growth, one installation,
15 stories and 34 story images
(`native-132-frame-queue-optimized-background/1-vox/result.json`). This
background result remains above Brave's 454.6 MiB reference and does not
replace the latest valid foreground result. The intervening optimized
foreground attempt lost focus near the endpoint and was rejected
(`native-117-optimized-foreground-run.log`).

The final queue implementation passes the CPU ownership mock, eight GPU
replays across queue replacement with a retained Context, the existing
graphics lifetime checks, 3,040 exact GPU comparisons, normal and poisoned
headless startup, and all ten SVG/image mutation and turbulence comparisons.
The default screenshot suite has six exact passes, its existing canvas
allowance pass, and the same four upstream-reference failures listed above.
Those four are pixel-identical to the previous renderer with the same V binary
(`replay-132-default/`, `replay-137-default-control/`).

Microtask checkpoints reuse their settings snapshot and visit attached VMs
directly. Native chrome preserves unchanged title and console-footer strings;
empty native image response channels no longer allocate select descriptors
on each poll. Their focused allocation and behavior checks pass with normal
prealloc, poisoning and Boehm. The broader native tab test still fails its
modified-link case at an unset option; an exact pre-change control fails at
the same point (`tabs-129-control-prealloc-run.log`).


### Stylesheet cache candidate ownership and parser snapshots

The shared stylesheet syntax cache parses a miss in temporary storage before
deciding its owner. A candidate that exceeds the node budget, or a disabled
cache, returns an immutable copy in the caller's storage. Admitted trees and
their source keys are copied to process storage after a locked duplicate
check. A publishing worker retains its base storage beyond thread exit.
Previously, even a rejected candidate stayed process-owned. Focused checks
cover repeated owner retirement, source/key ownership, concurrent publication
and cache reads after all workers exit; prealloc, poisoning and Boehm pass
(`syntax-candidate-139-*-run.log`). Full-page RAM savings are not yet established.

CSS parser parameter snapshots clone local array/map headers. Taking the
addresses of fields directly had caused current V to box the entire parser
for each snapshot. The generated C now clones stack headers without a parser
`memdup`; focused checks preserve independent value/rule contexts and namespace
maps, and bound repeated empty snapshots. All three allocator/poison modes
pass (`syntax-candidate-141-*-run.log`,
`parser-params-141-generated-c.txt`).


### Lossless CPU raster rows

The native raster cache stores large flat RGBA backdrops and results as
32-bit runs and literals when that uses at least one eighth fewer bytes.
High-entropy and small rasters stay raw. Hits compare the actual backdrop
and expand owned results directly into strided output rows without allocating
a decoded temporary. Padding remains untouched. The byte budget charges
compressed storage; admission still checks the uncompressed maximum.

CPU checks include runs across row boundaries, mixed literals, unaligned rows,
mutated inputs, raw fallbacks and three surfaces whose combined raw size
exceeds the unchanged budget. Address/undefined-behavior sanitizer checks,
3,040 GPU comparisons and ten poisoned SVG/image/turbulence checks pass
(`native-148-final-compression-replay.log`, `replay-148-svg/results.json`).
A matched O0 background diagnostic falls from 541.8 to 529.3 MiB in one trial
(`native-138-normal-background`, `native-142-compression-background`). These
trials do not establish a foreground RAM result. A separate cache census
finds about 0.66 MiB of retained shape pixels and 0.89 MiB of shadow pixels
after compression (`native-145-cache-census-background/1-vox/browser.log`).


### Foreground and live-arena diagnostics

The clean optimized source-133 build completes a valid foreground Pikabu
trial at **714.9 MiB**, with **329.2 KiB/s** latter-half growth. All 59 focus
checks pass, with one installation, 15 stories and 34 images
(`native-159-source-133-foreground/1-vox/result.json`). This includes completed
Metal queue retirement and the newer inline-length/parser work, but predates
compressed raster rows and stylesheet candidate retirement. It supersedes
the earlier 1065.9 MiB foreground endpoint, while remaining above Brave.

A later background arena census counts about 273 MiB used by the main
document and 110 MiB in base storage. A 15-second warm base allocation sample
records about 0.2 MiB, roughly 14 KiB/s
(`native-150-idle-profile/`, `native-150-idle-base-sites.txt`). The raw footprint
still varies substantially across GPU frame phases; these diagnostic numbers
do not establish a foreground comparison. Releasing all Context GPU resources
after every completed frame has not established a RAM win and remains an
unlanded experiment (`native-156-frame-resources-background`).


### Scripted tokenizer retirement

Closed-input native HTML parsers now retire their tokenizer storage for
scripted documents too. DOM and script-model strings own their copies, and
paused parsers retain input until they reach EOF. Ready parser-blocking scripts
open a fresh insertion point; resumed scripts clear the pause flag before
execution so `document.write()` can synchronously reenter parsing.

Eight focused checks pass with prealloc, poisoning and Boehm, including ready
and stylesheet-blocked scripts, synchronous inserted-node reads, source/type
metadata after tokenizer retirement, streaming behavior, immutable payloads
and release of document storage after pending progress callbacks drain
(`scripted-tokenizer-163-*-run.log`). An earlier full-page prototype also
completes the 60-second normal/poison Pikabu checks with one installation and
the expected 15 stories/34 images (`native-147-*-background`); its RAM numbers
vary and do not establish a win.

The broader existing parser-end-state test faults in its script event-count
map under prealloc even when run alone, with no new tokenizer fixtures
executed (`scripted-tokenizer-161-end-only*-run.log`). Its end-state execution
path is unchanged here; Boehm passes it. This check receives no prealloc pass
credit.

The next clean optimized foreground endpoint is **657.6 MiB**, with
**947.3 KiB/s** latter-half growth, all 59 focus checks, one installation,
15 stories and 34 images
(`native-162-source-141-foreground/1-vox/result.json`). It adds compressed
raster rows and stylesheet candidate ownership to source-133, but predates
scripted tokenizer retirement. It is the latest valid primary endpoint and
still exceeds Brave. A later profiling attempt lost focus and acquired empty
replacement documents; its small vmmap snapshot is invalid as a Pikabu RAM
result (`native-164-foreground-vmmap/`).


### Flex work nested in retained inline construction

`ab01fde4` retires normal flex algorithm work when its caller is constructing
retained inline lines. Previously that retained allocation redirect also owned
flex item vectors, flexible-length work and their closures until document
retirement. The flex result contains only scalar dimensions; published used
values and nested line construction continue through their existing retained
ownership paths. Existing transient geometry work and intrinsic probes do not
open another scope.

Three new cases plus five geometry/intrinsic regression cases pass with
prealloc, arena poisoning and Boehm in the source-168 snapshot. They check
reclamation of a 20 MiB nested workspace, document ownership after retirement,
probe lifetime, row/column inline-flex painting with nested grids, and reflow.
Both checked-browser startup modes pass. Eight live SVG mutation comparisons
and both turbulence screenshots remain pixel-exact with poisoning
(`replay-171-svg/results.json`). Sixty-second O0 full-page runs preserve one
installation, 15 stories and 34 images with normal allocation and with poison
(`native-172-source-168-poison-background` and
`native-173-source-168-poison-background`). Despite its directory name, the
172 run is normal: the measurement harness cleared its inherited poison flag.
The 173 run applies the flag after environment cleanup. These background
ownership checks receive no primary RAM comparison credit.

Two later valid foreground trials of the same source-141 V executable show
substantial run-to-run variation: the retained control is **494.9 MiB**
(`native-170-source-141-control-foreground/1-vox/result.json`); a native Ganesh
queue-retirement prototype is **497.3 MiB** (`native-169-ganesh-queue-foreground`).
Both preserve one installation and all 59 focus checks. This pair establishes
no benefit from that prototype, so it remains unshipped. Neither result
includes the flex change, and neither establishes the Brave goal. The earlier
657.6 MiB result remains retained; final comparison still requires three
alternating trials, with every Vox endpoint below every Brave endpoint.


### Source-168 alternating comparison and parser array follow-up

All six 60-second foreground trials completed in
`native-175-source-168-alternating/results.json`, alternating launch order.
Vox endpoints were **464.9, 507.6 and 477.6 MiB**; Brave endpoints were
**457.4, 458.7 and 458.9 MiB**. The median comparison is 477.6 versus
458.7 MiB, and the all-trials criterion remains false. This includes the
nested flex workspace but predates idle shaping-cache retirement and the
CSS value-array change below. All three Vox audits retain one installation,
15 stories and 34 images.

A separate O0 source-168 census (`native-176-source-168-census-background`)
finds 303,675,309 used bytes in the main document arena and 105,784,754 in
the main thread base arena. The live paint projection uses 10,459,087 bytes.
These are allocator usage counts, not physical footprint or clean optimized
comparison results. The older source-141 allocation sample, reranked by site
in `native-160-document-sites-120.txt`, attributes about 30.2 MiB of document
allocation to resolved layout-cache writes; ordinary measurement record
allocation is about 3.5 MiB. This does not establish a gain from a hypothetical
geometry-generation arena.

`d9aa07b3` keeps immutable component spans when a CSS parser receives freshly
tokenized text or the result of substitution. The public component constructor
still snapshots its caller's array. Property validation also calls the existing
single-component presence checker directly, replacing a one-element array per
token. The new long-input regression first retained 33,588,945 bytes across
64 parses; after the direct call it passes a 1,573,056-byte bound, including
actual property parsing. Three new cases and seven substitution/presence
regressions pass with prealloc, poisoning and Boehm (`parser-span-178-*`).
No full-page RAM saving is attributed to this microbenchmark.


### Cold base profile and selector graph copies

The source-178 optimized browser completes a valid foreground trial at
**463.4 MiB** (`native-183-source-178-foreground/1-vox/result.json`), with
one installation, 15 stories, 34 images and all 59 focus checks. This single
trial does not replace the failed three-trial comparison or establish a
full-page saving from the parser change. Both startup modes and all ten SVG
checks also pass for source-178 (`replay-182-svg`).

A separate full-load base-allocation sample (`native-181-base.sample`,
`native-181-base-sites.txt`, `native-181-base-stacks.txt`) records about
105.7 MiB of allocations. Its census finds 106,123,864 used bytes in the
main-thread base arena, 304,042,959 in the main document, and 2,139,425 in
the recyclable shaping cache. Unlike the earlier warm profile, this includes
startup. The largest sites include shared stylesheet syntax, selector graph
copies, cached response bodies and TTF cmap tables. These sampled bytes do
not imply that every allocation at those sites is disposable.

`b959eea1` builds selector-copy memo tables and entries inside the existing
selector workspace, then fills preallocated entry slots while publishing the
owned graph. Slot updates avoid V map growth during an existing-key assignment.
The edge-copy loops borrow source records by index; taking a match-set address
from a by-value loop record previously made current V box each edge. Generated
source-184 C shows those `memdup` calls; source-185 removes them.

The 256-node cyclic/shared graph regression retains 159,872 bytes before
borrowing the edge records and 102,520 afterwards. Its initial allocation
budget omitted managed-array headers and alignment; the corrected budget
allows those for both edge vectors while excluding memo tables and boxed
loop records. All four focused cases pass with prealloc, poisoning and Boehm
in source-186, whose implementation matches source-185. The earlier failed
assertions are retained without pass credit. Source-185 browser startup passes
in both modes, all ten SVG checks remain pixel-exact (`replay-187-svg`), and
a poisoned 60-second Pikabu run preserves its complete page audit
(`native-188-source-185-poison-background`). An optimized comparison of this
change remains pending.
