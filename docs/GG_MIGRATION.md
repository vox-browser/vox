# Migrating from Skia to vlib/gg

Vox currently renders through two Skia builds: LibWeb's Skia (CPU raster,
`libLadybirdVSkiaText.dylib` and the `skia/` module) and the pinned Chromium
Skia Graphite builds (`libVoxGraphite.dylib` on Metal and
`libVoxGraphiteDawn.dylib` for pictures). Brave parity depends on reproducing
Chromium's Skia output exactly. The migration replaces Skia with `gg.canvas`, a
new `vlib/gg` module, without changing any pixel of the passing tests.


The CPU differential suite and large generated verification receipts live in
[vox-browser/vox-tests](https://github.com/vox-browser/vox-tests). Vox pins the
suite in `tools/raster_tests.json`; `tools/raster_tests.py` fetches that exact
revision, verifies a clean checkout and runs it against this canonical source.
The existing `tools/gg_migration/test_cpu_raster.sh` command remains a launcher.
Small focused unit tests and their frozen inputs stay in `cpuraster/`. New
bulk receipts belong in the test repository, with a concise result here.
Historical receipts below retain their original bytes and source identities.

## Approach

`gg.canvas` reproduces Skia rather than approximating it:

- **GPU work.** Graphite's generated MSL is embedded unchanged and compiled
  with Graphite's options. Instance, vertex and uniform data are written byte
  for byte, render passes use the same attachments, sample counts and blend
  state, and draws are ordered, sorted (libc++ `std::sort`) and split into
  instanced draw calls exactly like Graphite's `Device`, `DrawList`,
  `DrawWriter` and `DrawBufferManager`. On Apple GPUs, splitting or reordering
  a batch changes MSAA and antialiased pixels, so batching is part of the
  output.
- **CPU arithmetic.** Ported geometry uses the same float operations. Skia is
  built with `-ffp-contract=off`; the V code avoids expressions that clang
  would contract into FMAs, and `tools/raster_tests.py fma_audit.py` enforces it.
- **Verification.** `tools/gg_migration` runs scene scripts through the pinned
  Skia (an oracle linked against `libskia.a`) and through `gg.canvas`, compares
  every byte, and traces both Metal command streams to locate the first
  divergent draw.

The ABI between Vox and Graphite is plain values and pixel buffers
(`native/include/native_graphite_bridge.h`), so each entry point can be replaced by a V
implementation exporting the same symbols and compared against the pinned
original dylib with the existing `tools/native_graphite_*_test.cpp` harnesses.

## Status (2026-11-06)

The browser adapters and differential tools now live on canonical Vox
`master` (`05ffb14b8`, `edeebc78e`). They were integrated from `gg-migration`
`7377e0384`; the original worktree and its historical results remain intact.
Build and test from `/Users/alex/code/vox2`.

The V renderer PR is merged. The canonical Vox push
was rejected as non-fast-forward: `origin/master` at `868e16b99` has three
commits absent locally, while the shared local history has hundreds absent
remotely. The tested Vox integration, tooling and report commits remain local.
Reconciling those histories requires a decision consistent with the repository's
linear-history and no-rewrite rules; no force push, merge or rebase was attempted.

Upstream V merged [vlang/v#31826](https://github.com/vlang/v/pull/31826) on
November 6 at squash commit `ac9fbda08a140196f9aff3aa377b404868249740`.
Its `vlib/gg/canvas` directory is byte-identical to the reviewed source head
`5b06b5a56b` in `~/code/v-gg`. The shared parallel compiler still uses its
earlier V checkout without this module; it has not been overwritten.
`V_BIN=~/code/v-gg/v sh build-prod-browser.sh` selects the existing GG compiler.
The default macOS build requires `gg.canvas` and supplies `-d vox_gg_canvas`.
GG's text, shape and path adapters now register by default. `VOX_USE_SKIA=1`
at launch selects the legacy renderer, overriding all three adapter switches.
Explicit `VOX_GG_TEXT=0`, `VOX_GG_SHAPES=0` and `VOX_GG_PATHS=0` still isolate
individual adapters for differential checks. Unsupported and unmigrated draws
retain Skia fallback; **the default binary is not Skia-free**.

With `V_BIN` unset, an older shared compiler can use the existing
`~/code/v-gg/v` without overwriting the shared parallel compiler. An explicit
compiler lacking `gg.canvas` fails the default build. An explicit
`VOX_USE_SKIA=1 sh build-prod-browser.sh` builds the legacy renderer without
requiring or compiling the GG adapters. This build choice is recorded in the
shared queue and its renderer receipt. Linux's existing Skia renderer is unchanged;
the GG browser adapters currently require macOS.

The GG compiler predates `v root`. Build detection now uses the existing
`@VEXEROOT` library probe (`aa03e9ba8`), including for moved compilers and
staged runtimes. Three focused checks pass; real compiler probes detect the
GG module and identify its absence from the standard shared V compiler.

### Default selection and remaining Skia dependencies

`e76d0e595` makes GG the macOS default and adds the explicit Skia override. Build
workers use protocol `bundle-lease-v4`, preserving a queued legacy request and
rebuilding when the requested renderer changes even if source bytes do not.
`renderer.json` records both the selected default and `skia_free:false`.
Comparison tools explicitly select Skia for controls, clear inherited renderer
overrides, and retain the existing selective adapter cohorts.

Production receipt `20261106-133828-93b254e2`, executable
`7f519bf2f01db83bf45be3da6b09f7031f7c4d894df4b50f07662e8a07e5544e`,
verifies registration with **no renderer flags** (all three GG adapters true)
and `VOX_USE_SKIA=1` (all three false). The two fresh captures match. Twelve
focused fixture pairs also match, with unchanged executable, native libraries,
fixtures and resources: 57 unclipped and 38 device-clipped text draws, six
shape draws, 24 path draws and three path declines. Those three gradient
declines still require Skia to preserve pixels. All 26 launches exit zero;
the four V selection cases and 55 build/comparison-tool checks pass.

The requested binary-size reduction remains unfinished. `otool -L` confirms
both Vox and `libLadybirdVSkiaText.dylib` directly link `libskia.dylib`.
The Graphite and Dawn picture libraries also retain their Skia implementation.
The `skia/` package still supplies canvas paths/text/filters and shadows (font
validation, pixel readback and bitmap export have since moved to Skia-free
code; see [Removing Skia](#removing-skia-started-2026-11-06)); the native text
bridge creates Skia fonts and blobs before invoking GG. Removing these links now would leave required symbols and
rendering operations unimplemented. Runtime environment selection cannot
eliminate compiled dependencies. See the
[default-selection receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/default-20261106.json) for the verified
selection, pixel tests and dependency audit. Skia-free rendering still requires
the ports listed under Remaining work.

### Upstream review fixes

Seven fixes were committed and pushed to the PR's verified source branch,
`medvednikov/v-pr-fork:gg-skia-parity`, after review of `ff4cd6dc66`:

| Commit | Fix |
| --- | --- |
| `01a7922600` | Define `GL_PACK_ALIGNMENT` in the embedded Windows GL loader. |
| `8e76b07a8f` | Isolate CoreText files; unsupported platforms expose explicit text errors. |
| `50dad21400` | Restore the temporary DRRect clip/save on every error path. |
| `0b9adab99b` | Reject CPU gradient text before modifying pixels. |
| `7b1b0ebb16` | Reject depth exhaustion, reserving the extra depth for deferred clips. |
| `6ce199418c` | Reserve complete draw and pending-clip uniforms before the 4096-block limit. |
| `dbfcab86a1` | Bound text caches; release retained fonts, glyph masks and native contexts. |

The text cache retains at most 32 strikes in LRU order, with at most 256 glyphs
and 256 KiB of masks per strike. Individual masks over 512 pixels in either
dimension decline. `canvas.clear_text_cache()` releases strikes while preserving
live faces; `Typeface.free()` also releases that face's retained font. Text
drawing and cleanup are serial operations on the drawing thread.

All 12 canvas test files pass on macOS, including the retained Metal and CPU-text
pixel hashes. The text cache, text pixels and draw-list tests also pass with
`-gc none`. Linux and Windows type checks cover paths and the platform/cache
tests. The Windows GLCORE regression test compiles the embedded loader with
MinGW, and a separate GLCORE executable cross-build links successfully. Native
Windows execution and Linux runtime tests were not run. See the
[review-fix receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/pr-reviews-20261105.json) for source pins,
commands, actual exits and retained failures.

The follow-up review confirmed those implementation fixes and found three text
helper tests still referencing Darwin-only definitions on other platforms.
`b434ae7005` puts their bodies under matching macOS guards. The previous
cross-target checks omitted `text_test.v`; verification now typechecks all 12
canvas test files for both Linux and Windows (24 checks), then runs the text
and platform test files on macOS. All pass. This follow-up changes only tests;
see its [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/pr-review-followup-20261105.json).

A fresh review of `b434ae7005` reproduced two further state-management bugs.
`6c8b7be581` clears pending clip usage, order and depth when a draw list is
discarded; otherwise restoring a clip after `clear()` could resurrect the
discarded depth and reject the first new draw. `5b06b5a56b` unwinds the implicit
save if layer creation fails, preserving the caller's save and matrix. Both
regressions failed before the fixes and pass afterwards. All 12 canvas test files,
three affected files with `-gc none`, and six Linux/Windows type checks pass.
The new Metal pixel test also checks that clearing pending usage preserves the
active clip geometry. See the [fresh-review receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/review-20261106.json).

The 262-fixture stage22 browser result below remains pinned to `ff4cd6dc66`;
it does not validate a production browser built with this newer review-fix head.

Implemented in `gg.canvas`:

- sokol: integer vertex formats; synchronous image upload/readback and flush;
  Metal shader compile options; partial uniform updates on Metal.
- `gg.canvas`: Graphite's analytic rrect and non-AA bounds renderers for
  filled, stroked and hairline rects, rrects and ovals, inner fills, fixed src
  blending, 1x and 4x MSAA surfaces, backdrop upload (loaded into MSAA passes
  with Graphite's `LoadMSAAFromResolve` draw) and readback, SkCanvas quick
  reject, Graphite draw ordering, sorting and batching, the ordering effects
  of Vox's forced-MSAA path, and `GpuContext.precompile()`.
- `gg.canvas` clips: a port of Graphite's ClipStack for rect and rrect
  elements: `save`/`restore` with deferred save records, intersect and
  difference `clip_rect`/`clip_rrect` under any affine transform (rrects
  under 90-degree rotations through SkRRect's legacy transform), element
  simplification and combination, geometric intersection of rect and rrect
  draws with intersect elements in the same or a relatively axis-aligned
  space (SkM44 concatenation), flood fills and the fullscreen clear,
  scissors, the legacy analytic rect and circular rrect clip shader on every
  renderer, and depth-only element draws in 4x MSAA passes: convex wedges
  (lines and conics, FixedCountWedges' templates) for difference elements,
  winding stencil wedges and an inverse cover of the scissor for intersect
  elements. `draw_drrect` follows Graphite's drawDRRect (stroked rects and
  rrects, rect differences, clipped fills, and other strokes as even-odd
  paths).
- sokol: vertex-only Metal shaders. Graphite's depth-only clip pipelines have
  no fragment function, and on Apple GPUs an empty fragment function changes
  their rasterization.
- `gg.canvas` paths: `Path`/`PathBuilder` (SkPathBuilder's verbs, conic
  weights, `addOval` and SVG `arcTo`), path bounds, Skia's convexity and its
  line, rect and nested-rect detection, and `draw_path` for fills, following
  Graphite's `drawPath` with `PathRendererStrategy::kTessellation` (Graphite
  on Apple silicon uses no path atlas): rect, oval and nested-rect paths use
  those renderers, convex paths the shaded convex wedges, and other paths the
  MSAA stencil-and-cover wedges (winding and even-odd, disjoint stencil sets),
  with Wang's formula for lines, quads, conics and cubics and PatchWriter's
  chopping of curves that need more than 32 segments. Compiled Skia
  evaluates the sine and cosine of one angle with a combined sincos call,
  which can differ from separate calls in the last bit; the arc port does the
  same.
- `gg.canvas` strokes: Graphite's tessellated stroke renderer for path strokes
  and for rrects the analytic renderer cannot stroke (elliptical corners):
  deferred first patches joined to the closing patch, miter, round and bevel
  joins, butt, round and square caps, cubic, quad and conic cusps,
  hairlines, cubic convex-180 chops, chopped long curves and the stroke
  tolerances that select the fixed-count vertex count. Lines (`draw_line` and
  single-line paths) use the analytic rrect renderer with caps, like
  Graphite's `drawPoints`.

- Clip paths: convex and non-convex elements, winding and even-odd stencil
  tests, and clip-state save/restore. Some rotated curved clip paths still decline.
- Gradients: dithered linear and radial gradients, up to eight stops, every
  tile mode, local matrices, premultiplied interpolation and translucent paint
  variants. General two-point conical gradients still decline.
- Layers: `save_layer` without a paint, nested offscreen textures and image
  shader restores. `restore` also restores the matrix. Fractional rectangular
  restores now use Graphite's PerEdgeAAQuad renderer: its 16 template vertices,
  29 indices, 80-byte instance layout, coverage, bounds, ordering and batching.
- Inverse winding and even-odd path fills: stencil wedges followed by an inverse
  cover. Empty inverse fills still require the drawPaint path.

Differential results against the pinned Graphite (exact means every byte equal;
unsupported scenes decline rather than earn a pass):

| Corpus | Scenes | Exact | Unsupported |
| --- | ---: | ---: | ---: |
| 400 mixed single/few draws | 400 | 400 | 0 |
| 2000 mixed single/few draws | 2000 | 2000 | 0 |
| 30 fills per scene | 60 | 60 | 0 |
| 90 fills per scene | 60 | 60 | 0 |
| 200 fills per scene | 60 | 60 | 0 |
| 400 with 4x MSAA backdrops (69 such scenes) | 400 | 400 | 0 |
| 2000 with 4x MSAA backdrops (322 such scenes) | 2000 | 2000 | 0 |
| 400 with difference clips (`--clip-outs`) | 400 | 400 | 0 |
| 2000 with difference clips (`--clip-outs`) | 2000 | 2000 | 0 |
| 300 skip-ink lines with 1-10 clip-outs each | 300 | 300 | 0 |
| 400 with save/restore, rect/rrect clips, DRRects, border sides (`--clips --msaa-backdrops`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 filled paths mixed with shapes and clips (`--paths --msaa-backdrops`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 of the same with SVG arcs (seed 777) | 400 | 400 | 0 |
| 2000 of the same with SVG arcs | 2000 | 2000 | 0 |
| 400 mostly stroked paths of every join and cap (`--strokes --msaa-backdrops`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 stroked and filled curves that need chopping or turn around (`--curves`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| 400 single line segments of every cap, hairlines and dots (`--lines`) | 400 | 400 | 0 |
| 2000 of the same | 2000 | 2000 | 0 |
| Clip paths, 400 scenes | 400 | 399 | 1 |
| Clip paths, 2000 scenes | 2000 | 1997 | 3 |
| Gradients | 2000 | 1604 | 396 |
| Gradient paths | 2000 | 1434 | 566 |
| Gradient strokes | 2000 | 1430 | 570 |
| Layers before the per-edge AA port | 2000 | 1604 | 396 |
| Layers after the per-edge AA port (`ff4cd6dc66`) | 2000 | 1796 | 204 |
| Inverse fills | 2000 | 2000 | 0 |
| Focused fractional layer restores (`ff4cd6dc66`) | 8 | 8 | 0 |

The stroke corpora listed in earlier revisions of this document (376 of 400
and 1846 of 2000 exact) were generated after a `gen_shape_corpus.py` change
dropped the paint lines from path scenes, so they drew only fills; the
corpora above were regenerated with the paints restored (the SVG arc corpora
regenerate byte for byte). The previous build of `gg.canvas` declined 831
and 421 scenes of the 2000 curve scenes for stroked chopping and cusps.

The clip-path and gradient rows retain the preceding session's corpus results.
The current layer, inverse-fill and focused layer rows were rerun with the new
renderer: zero differing scenes. On identical layer inputs the previous
`canvas-scene-inverse` binary declines 192 scenes specifically because the
per-edge AA renderer was missing; the new renderer draws all 192 exactly.
The remaining layer declines are gradient limitations (68 linear color space,
30 without dithering, 65 general conical, 24 over eight stops, 17 degenerate).
See the [focused verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/focused-20261105.json) for
input hashes, executable identities, commands, actual exits and raw evidence.
All ten canvas test files pass; the layer test also passes with `-gc none`.

`gg.canvas` still declines unsupported image operations, layer paints,
stroke-and-fill, empty inverse fills, blurs and perspective transforms.

CPU text (`gg.canvas.RasterSurface.draw_glyphs`) reproduces the bridge's
retained glyph path, which runs on LibWeb's Skia (vcpkg m144, source
`google/skia@ee20d565`). That build defines `SK_GAMMA_APPLY_TO_A8` and uses
RGBA as kN32, so BGRA surfaces always blend through the lowp
`SkRasterPipeline`, never the legacy ARGB32 blitters. Ported: the scaler
record, `SkScalerContext_Mac` CoreGraphics masks with Skia's linearization and
`SkMaskGamma` pre-blend, subpixel buckets and placement, and the A8 mask
pipeline (`uniform_color`, `lerp_u8`/`scale_u8`, `srcover`, NEON `div255`).

| Text corpus | Scenes | Exact | Unsupported |
| --- | ---: | ---: | ---: |
| 400 random glyph runs | 400 | 400 | 0 |
| 2000 random glyph runs | 2000 | 2000 | 0 |

The runs cover six system fonts, 6-90px, opaque and translucent colors over
opaque, translucent and transparent backgrounds, identity, scale/translate and
rotated/skewed matrices, and both the Chromium and LibWeb smoothing settings.

### Text in the browser (`VOX_GG_TEXT=1`)

With `VOX_GG_TEXT=1` the browser registers `ggtext.glyph_run` with the text
bridge (`native/include/native_gg_text.h`), and the bridge's raster glyph paths (retained glyph
runs and glyph bitmap tiles) draw single-run blobs with `gg.canvas` instead of
`SkCanvas::drawTextBlob`. Typefaces wrap the bridge's own CTFonts
(`Typeface.from_ct_font`). Runs `gg.canvas` cannot draw exactly fall back to
Skia: shaders, mask/color/image filters, float colors, multi-run blobs, LCD
pixel geometry, synthetic bold and color glyphs.

`capture_ab.py` captured all 262 Brave fixtures (1024x852 window) with one
bundle, with and without the switch (Vox `1deb74782`, V `3c0c17b20c`,
executable `034ac038`, unchanged before and after): **262 pixel-equal**, none
different, unstable or failed. An earlier bundle with the adapter in `main`
(`3ccf48da`) matched on the 241 fixtures it reached before the memory guard's
30-minute timeout.

A separate lldb diagnostic counted the text drawn with the switch on:

| Glyph runs | Count | Fixtures |
| --- | ---: | ---: |
| Drawn by `gg.canvas` | 875 | 89 |
| Declined by `gg.canvas` (13 color emoji, 1 synthetic bold) | 14 | 2 |
| Raster runs declined before `gg.canvas` (`background-clip: text`, one root-background run) | 3 | 2 |
| Recorded into the shared recording canvas | 253 | 37 |
| Recorded into pictures for the GPU picture backend | 183 | 18 |

`SkPicture::serialize` replays recorded text through `drawTextBlob` another
299 times. The recorded paths (compositor layers, sticky and select content,
and most stackoverflow, lobsters and forum fixtures) are not routed to
`gg.canvas` yet. 160 fixtures, mostly gradients, borders, shadows and images,
draw no bridge text.

Canonical Vox `257add3f9` also routes borrowed-frame tiles with a device clip
through GG. The native adapter keeps the original raster dimensions and device
matrix, renders partial clips against a private backdrop, then copies back only
the visible rectangle. Full-tile clips need no staging. A declined draw leaves
the original backdrop available for Skia, including if a callback writes before
returning failure. Quartz snapshot detachment and RGBA/BGRA conversion retain
their existing behavior.

The focused native integration compares the actual `ggtext.glyph_run` callback
against the original CPU Skia draw through the same borrowed-frame adapter:

| Configuration | Pixel-exact cases | GG drawn | Fallback | Fully hidden |
| --- | ---: | ---: | ---: | ---: |
| Normal | 2000 | 1280 | 231 | 489 |
| `-prod -gc none` | 2000 | 1280 | 231 | 489 |

Both runs attempt 1,405 GG callbacks and change 1,413 tiles. They cover three
system fonts, fractional sizes and affine transforms, 1x/2x backing scales,
transparent and translucent backdrops, narrow/empty/disjoint clips, synthetic
bold and aliased masks, shader/float-color/perspective/LCD rejection, row padding
and immutable frame snapshots. The original implementation fails the first
case because it never invokes GG. Both existing text-adapter test runs pass,
normally and with `-prod -gc none`. These are correctness checks, with no speed
claim. See the [clipped-text receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/clipped-text-20261106.json)
for input and executable hashes, actual exits and retained failures.

Production receipt `20261106-101340-fca9026b` builds this adapter with the
reviewed V module (identical to the merge), literal `-prod`, preallocation and
one C unit. Executable
`74fbd0d869fef85f67ef07679310566dde0c325f224a70063c1d411883b5d09c`
passes 12 focused browser A/B fixtures with text, shapes and paths enabled:
24 successful fresh launches, no different, unstable or failed pairs, and
unchanged bundle, fixture and resource hashes. Diagnostics count 91 text draws
without a device clip and **38 with a device clip across three fixtures**,
all drawn by GG. The latter fixtures are `hacker-news-comment-initial-text`,
`scrolling-text-raster` and `select-label-ink-clip`. Shapes and paths each
draw four descriptors, with no declines. The 1024x852 captures exclude only the
existing status-bar RAM readout; they compare the two Vox modes, not Brave.
The first build attempt was rejected because shared sources changed before
preprocessing; the supervisor's retry sealed its compiler inputs and succeeded.
This focused result does not replace stage22's older 262-fixture acceptance.
All six existing native glyph executables also pass with AddressSanitizer and
UBSan, including 216 bitmap-surface cases, 16 device clips and four disjoint
damage-clip checks. Their source inputs stay unchanged throughout the run.

### Shapes in the browser (`VOX_GG_SHAPES=1`)

With `VOX_GG_SHAPES=1` the bridge's four `libVoxGraphite` shape entry points
(`native/include/native_gg_shape.h`) first offer each descriptor to `ggshape.draw`:
rounded-rect fills and strokes with an optional underlay, with or without
forced MSAA and a backdrop. Region, rounded-part and batched draws render the
same full surface with the CPU views as the only backdrop; a batch falls back
as a whole. Clip-outs become `gg.canvas` difference clips. The CSS border
modes now include elliptical rings, single rounded sides, three-sided labels,
and backgrounds sharing the border's layer. Unsupported draws keep the original
backend. `tools/gg_migration/shape_bridge_check.v`
checks the adapter against the saved `graphite_shape_oracle.mm` outputs
(14 of 14 exact), all 29 clip-out descriptors dumped from Brave fixtures
(29 of 29 exact), and the 35 formerly declined CSS border descriptors
(35 of 35 exact). These replay results precede the current integration.

The macOS browser renders natively and never sets up sokol.gfx, so
`gg.canvas` sets up a headless Metal context. sokol allocates its pools
through V's allocator, so the context and its precompiled pipelines are
created in Vox's persistent arena; each draw uses a fresh surface on the main
thread. (Creating the context inside a paint scope corrupted sokol's pools
once that scope's arena was reclaimed; `ggtext` keeps `gg.canvas`' typeface,
strike and glyph caches in the persistent arena for the same reason.)

`capture_ab.py` with `VOX_GG_TEXT=1` and `VOX_GG_SHAPES=1` together (Vox
`651df85fb`, V `cb7d505099`, executable `27e72ca8`, unchanged before and
after): **262 of 262 fixtures pixel-equal**, none different, unstable or
failed. A separate lldb count of the shape descriptors:

| Shape descriptors | Count | Fixtures |
| --- | ---: | ---: |
| Drawn by `gg.canvas` (29 of them with clip-outs) | 367 | 85 |
| Declined: CSS border modes (12 elliptical rings, 8 three-sided labels, 15 single sides) | 35 | 7 |

These historical 35 declines match the 35 calls that still reach `libVoxGraphite` (17
region, 9 full-surface and 9 batched calls); in those 9 batches, shapes
`gg.canvas` drew before the declined one were discarded. 87 fixtures draw
shapes through these entry points. Before clip support, the same count was
338 drawn and 64 declined.

### Paths in the browser (`VOX_GG_PATHS=1`)

The path and SVG-image entry points offer their descriptors to `ggshape.draw_path`
and `ggshape.draw_svg_image`. Supported fills and strokes include gradients and
rounded clips. SVG images concatenate parent and path matrices, apply their
viewport, and use a layer for the rounded clip. Here "SVG image" means a batch
of vector paths, not a general bitmap/image draw.

The preceding session compared 2,000 path descriptors exactly against
`libVoxGraphite`; SVG image and region comparisons were 794 of 800 exact, with
six declines and zero differences. The canonical integration reran 2,000 solid
path descriptors (all exact), and a different SVG gradient cohort: 590 of 800
exact, 210 declines, zero differences or original-backend failures. Coverage
counts belong to their particular seeds and flags; they are not interchangeable.

Canonical Vox `09d135d80` adds affine non-scaling strokes, including SVG image
and region draws. The adapter transforms the completed path's points and conics
like SkPath, retains oval classification for axis-aligned transforms, and leaves
the original clips in device space. Standalone strokes reset the draw matrix;
embedded SVG strokes concatenate SkMatrix's inverse so only the path's user-space
transform is cancelled, preserving the parent transform and SkM44 rounding.
Singular intersect clips and non-invertible SVG matrices follow Skia's no-op
behavior. Perspective and other unsupported draws still fall back atomically.

Focused checks against the original `libVoxGraphite` with `--non-scaling`
(mixed fills and strokes; the flag changes strokes without consuming random values):

| Cohort | Comparisons | Exact | Declined | Different / original failed |
| --- | ---: | ---: | ---: | --- |
| Paths, seed 20261105 | 2000 | 2000 | 0 | 0 / 0 |
| Gradient paths, seed 20261105 | 2000 | 1741 | 259 | 0 / 0 |
| SVG images and regions, seed 1 | 800 | 800 | 0 | 0 / 0 |
| SVG images and regions with gradients, seed 2 | 800 | 596 | 204 | 0 / 0 |

The solid path and SVG-gradient cohorts also pass through an optimized C-O3/LTO driver.
Both GG adapter test files pass normally and with `-prod -gc none`, including
original-backend comparisons for clips, affine SVG parents, singular matrices,
row padding and unchanged pixels after an unsupported batch. The assembly audit
finds zero fused multiply-adds in `ggshape__*`. See the
[non-scaling stroke receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/non-scaling-20261105.json) for pins,
commands, exits, retained failed attempts and raw evidence. These checks exercise
the adapter directly and do not establish browser acceptance.

Browser A/B results with text, shapes and paths enabled:

| Bundle | Fixtures | Pixel-equal | Different / unstable / failed |
| --- | ---: | ---: | --- |
| stage18 | 262 | 262 | 0 / 0 / 0 |
| stage19 | 262 | 262 | 0 / 0 / 0 |
| stage20 | 262 | 262 | 0 / 0 / 0 |
| stage21 | 262 | 262 | 0 / 0 / 0 |
| stage22 (`ff4cd6dc66`, canonical integration) | 262 | 262 | 0 / 0 / 0 |

Stage21 used Vox `60516f48f`, V `276636673e`, executable
`54eedf139a745d9daadffe4a3a75a99d6089550ed3f0f80dd3c65d7375f6f91c`, unchanged
before and after. The older rows retain their capture logs; superseded bundles
and PNG directories were removed in the earlier disk cleanup. These captures
mask only the status bar's live RAM readout and do not establish parity with Brave.

Stage22 originally failed with ENOSPC before compilation. The continuation
completed a GG-enabled canonical production build, including the inverse-fill,
per-edge AA and non-scaling stroke work. Receipt `20261105-112409-8bb6c959`
pins executable
`58129def664e8367a17cd04b3f8e8e313d3665ac31187ba71fe475b33a920ef9`
and V `ff4cd6dc66`. The frozen source record is based on canonical HEAD
`6835e42ea`, with dirty shared changes recorded by its input hashes; it is not
a clean-commit build. The GG compiler lacks native-header splitting, so this
build uses one C unit despite requesting parallel compilation. It supplies no
performance comparison with the standard compiler's split builds.

With `VOX_GG_DIAGNOSTICS=1`, all 262 historical fixture names, using their
current canonical contents, matched on their first control/candidate pair.
No repeats were needed. All 524 browser launches and the memory guard exited
zero; executable, native libraries, fixtures, runner, manifest and the Guardian
font hashes stayed unchanged. Captures used a 1024x852 window and the existing
224x24 RAM-readout exclusion, private profiles and fresh browser processes.

Candidate-log descriptor counts for this cohort:

| Adapter | Drawn | Declined | Fixtures with calls |
| --- | ---: | ---: | ---: |
| Shapes | 535 | 0 | 87 |
| Paths | 436 | 3 | 81 |
| SVG vector batches | 57 | 0 | 14 |

The three declines are gradient descriptors in `css-gradient-masks` (one) and
`svg-path-coverage` (two); their Skia fallback preserves the matching pixels.
`device-layout-svg-user-space` executes one non-scaling stroke through GG.
These counts include repeated paint calls; they count adapter descriptors,
not all primitives or all Skia work. Text registration is verified, but these
diagnostics do not count glyph runs. Recording canvases, GPU picture playback
and other bypasses still use Skia. The historical stage17 counts (394/4 shapes
and 205/103 paths drawn/declined) belong to a different bundle and workload.

The current runner automatically enables `VOX_GG_DIAGNOSTICS=1`, verifies the
requested adapters registered in each candidate process, pins executable,
native-library and fixture/resource hashes throughout, retains actual exits,
and fails on changed inputs or rendering failures. The canonical input directory
now has more than 262 fixtures; use the recorded historical fixture list when
continuing that cohort. See [the tool instructions](../tools/gg_migration/README.md).

The first continuation run was correctly rejected after 58 matching pairs when
the shared builder replaced the executable and libraries. `4415f3e07` adds a
shared bundle publication lease: captures retain the canonical app while builds
can compile, then publication waits for readers to finish. Five lease checks
and 22 build-supervisor checks pass. During the successful full run, a completed
standard build actually waited at publication and installed after the lease
released. The shared app may therefore differ from this tested GG bundle now;
the receipt and capture hashes identify the accepted result.

The recompare fix `fcfceaebc` preserves interrupted-run exits and provenance,
rejects missing registration proof and unknown exits, and keeps incomplete
cohorts from passing despite equal PNGs. The runner also supports explicit
resource files and automatically pins its source and fixture manifest
(`1fac432a7`); all 14 capture-tool checks pass. The full browser run preceded
that final tool change and used an equivalent per-launch hash extension for
its font, runner and manifest. See the
[stage22 receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/stage22-20261105.json) for commands, build
identities, coverage, actual exits, rejected attempts and retained raw evidence.
The older `49a4b05f` capture remains baseline evidence in the non-scaling receipt.

### Brave fixture inventory

`libvox_metal_trace.dylib` traced the production bundle on all 262 Brave
fixtures (`classify_inventory.py`; the bundle's hashes were identical before
and after). Fixtures using each Metal renderer:

| Renderer | Fixtures |
| --- | ---: |
| Graphite CoverBounds (non-AA fills, covers) | 146 |
| Dawn picture path (Tint MSL) | 113 |
| Graphite AnalyticRRect | 112 |
| Graphite tessellated wedges (path fills) | 78 |
| Graphite middle-out fans | 15 |
| Graphite tessellated strokes | 8 |
| Graphite coverage masks (path atlas) | 6 |
| Graphite per-edge AA quads | 3 |
| None (CPU Skia and CoreGraphics only) | 58 |

Text, images and most decorations of every fixture go through the CPU Skia
bridge as well.

## Removing Skia (started 2026-11-06)

The goal is a binary with no Skia at all, keeping every pixel Skia produces
today. Each Skia call is replaced by a Skia-free V port only once it matches the
pinned build byte for byte, and the Skia code is deleted in the same change.
CPU ports live in the `cpuraster` module (`gfxfont` for font validation); their
oracle `tools/gg_migration/skia_cpu_oracle.cpp` keeps the original Skia
implementations verbatim, and `test_cpu_raster.sh` compares them against
LibWeb's vcpkg Skia (`google/skia@ee20d565`, the same revision as Linux).

To find the exact arithmetic, run the original call under lldb: breakpoints on
the `neon::` and `neon::lowp::` stage functions list the raster pipeline Skia
actually executes, and stage contexts hold its constants (transfer functions,
gamut matrices, sampling matrices). The disassembly shows which operations
fuse: this Skia is built with `-ffp-contract=off`, so only explicit `mad()`
(`fmla`/`fmls`) fuses. Ports must keep every other product in its own
statement, because clang fuses `a + b * c` written in one V expression;
`tools/raster_tests.py fma_audit.py --contracted-only` lists any it finds. V
calls `dlsym` pointers without prototypes, so oracle entry points take their
integer arguments as one `i32` array.

| Dependency | Users | Status |
| --- | --- | --- |
| `skia.read_pixels` (SkBitmap::readPixels) | getImageData/putImageData | `cpuraster.read_pixels`; all 65,536 channel/alpha pairs (NEON blocks and tail) plus 20,000 random geometries exact |
| `skia.font_typeface_is_valid` (SkFontMgr makeFromStream) | CSS font loading | `gfxfont.typeface_data_is_valid`: CoreText descriptor/font creation, or FreeType face, axes and design coordinates on Linux; 3,022 font comparisons equal |
| `skia.export_bitmap_to_byte_buffer` (drawImageRect into export formats) | WebGL texture uploads | `cpuraster.export_bitmap_to_byte_buffer`: lowp/highp pipelines, Display P3, nearest sampling with draw tiles, legacy fixed-point sampler; 448 exhaustive and 100,016 random exports exact |
| `skia.draw_path` solid fills | Canvas 2D `fill()`/`fillRect()` | `cpuraster.fill_canvas_path` for solid source-over fills without shadows or filters, including SVG arcs and global alpha: Skia's analytic AA (`SkScan_AAAPath`, analytic edges, edge and line clippers with `SkCubics` chops, introsort) and legacy `SkARGB32` blitters on macOS's `SkPathRef` paths; 60,000 random fills and 5,000 production canvas fills exact |
| `skia.draw_path` hairline strokes | Canvas 2D `stroke()`/`strokeRect()` whose `lineWidth` maps to at most one device pixel, including the default width 1 untransformed | `cpuraster.stroke_canvas_path` for solid, undashed source-over strokes without shadow blur or filters: SkDraw's thin-stroke-as-hairline alpha scaling and SkCanvas's quick reject, `SkScan_Hairline` flattening with butt, square and round caps (cubics chopped at maximum curvature), `SkScan_Antihair`'s four line walkers with fixed-point range and rect clipping; 36,124 random strokes exact |
| `skia.draw_path` wider strokes | Canvas 2D `stroke()`/`strokeRect()` wider than a device pixel | `cpuraster.stroke_canvas_path` for the same solid source-over strokes: `skpathutils::FillPathWithPaint`'s `SkStrokeRec` at the matrix's resolution scale, `SkStroke`/`SkPathStroker` (quad approximation of quads, conics and cubics with their recursion limits, inflection splits and cusp circles, degenerate-curve reductions, `strokeRect` for closed rects) with `SkStrokerPriv`'s caps and joins (unit-arc round joins, miter limits), then `SkPathBuilder::transform` and analytic AA fill, keeping a rect outline's known convexity; 150,000 random strokes over five seeds, 112,726 of them wider than a device pixel, exact in both default and `-prod -gc none` builds |
| `skia.draw_path` dashed strokes | Canvas 2D `setLineDash()` strokes | `cpuraster.stroke_canvas_path` with `SkDashPathEffect`: `ValidDashPath`/`CalcDashParameters` (invalid lists leave the stroke undashed), `SkDashPath::InternalFilter` with its cull rect (the device bounds mapped through `SkMatrix::invert`/`mapRect`, lines and rects trimmed in phase, the closed-rect corner join), `SpecialLineRec`'s direct quads for butt-capped lines, the million-dash limit's fallback, and `SkContourMeasure` (length tables with curve tolerances, `getSegment` with quad, conic and cubic chops); the dashes are then drawn as hairlines or stroked; 100,000 random dashed strokes over five seeds, 66,597 of them wider than a device pixel, exact in both default and `-prod -gc none` builds |
| `skia.draw_path` clips | Canvas 2D `clip()` under fills and strokes | `cpuraster.canvas_raster_clip` with `SkCanvas::clipPath`'s anti-aliased intersections in device space: `SkRasterClip` (rect paths through `op(rect)` with its nearly-integral hard-edge test, path clips into an `SkAAClip`, and AA clips that are hard-edged rects back to rects, keeping `SkAAClip::isRect()`'s offset quirk), `SkAAClip` (the builder's coverage rows from an RLE analytic AA fill, row merging, Y-gap rows, top/bottom and left/right trimming, `quickContains`, and intersections run by run with `SkMulDiv255Round`), and `SkAAClipBlitter` merging the clip's coverage into every span and column; fills force the RLE blitter and hairlines go unclipped where the clip is opaque, as in Skia; quick reject and the dash cull rect use the clip's bounds; 100,000 random clipped fills and strokes (hairline, wide and dashed) over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` composite operations | Canvas 2D `globalCompositeOperation` under solid fills and strokes | `cpuraster` pipeline blitter (`SkRasterPipelineBlitter` for a constant color) for every operation, including the runtime-effect `plus-darker` and `plus-lighter` (their SkSL programs in highp, with `saturate()` as `min(max(x, 0), 1)`, coverage lerped and nothing skipped): `SkBlitter::Choose`'s fast paths (an opaque `copy` draws as source-over, an opaque `destination-in` draws nothing) and `SkPaint::nothingToDraw`, the constant color pipeline and `copy`'s memset, coverage scaled before or lerped after the blend, the lowp stages (wrapping 16-bit lanes, NEON's exact `div255`) and the highp ones for color-dodge, color-burn, soft-light, hue, saturation, color and luminosity (fused `mad`, `vminq`/`vmaxq` NaN and signed-zero rules, `rcp_fast` from a software `FRECPE` equal to the hardware's on all 2^32 inputs); thin strokes stay `SkStroke` outlines unless the mode supports coverage as alpha; 200,000 random composited fills and strokes over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` blurred shadows | Canvas 2D `shadowBlur` under solid fills and strokes | `cpuraster` blur (`SkBlurMaskFilterImpl`, normal style) as `vox_skia_canvas_path()` sets it up: sigma `blur / 2` mapped by `SkMatrix::mapRadius` (at most 128) in place of the canvas filters and global alpha, `SkCanvas`'s quick reject with the 3-sigma outset, rects and nested-rect rings as nine-patches (`SkBlurMask::BlurRect`'s analytic profile for one rect, the blurred ring for two, found by `SkPathPriv::IsRectContour` with its partial contours), and other paths drawn into an A8 mask through `SkA8_Blitter` (hairlines always with butt caps) and blurred by `SkMaskBlurFilter` (its Bessel-normalized Gaussian kernel below sigma 2, three box passes above, nothing below 1/3), then blitted through the clip; masks more than 8191 pixels across are filled with the non-anti-aliased `SkScan::FillPath`, as `SkScan::AntiFillPath` falls back to it; 200,000 random shadows over five seeds exact, none declined, in both default and `-prod -gc none` builds |
| `skia.draw_path` gradients | Canvas 2D `createLinearGradient()`, `createRadialGradient()` and `createConicGradient()` fills and strokes | `cpuraster` gradient shaders as `apply_style()` builds them: `SkGradientShader::MakeLinear`, `MakeTwoPointConical` (radial, concentric, strip and focal geometries, with `FocalData`'s swap, on-circle, well-behaved and smaller/greater cases and their degenerate masks) and `MakeSweep`, their degenerate fallbacks to `SkShaders::Color()` (the last color, or a thin ring as a radial gradient) and null shaders, and `SkGradientBaseShader`'s stops (implicit end stops, monotonic pinning, uniform stops as evenly spaced, hard-stop runs reduced); the pipeline's seed, `appendMatrix()` matrix (the inverse CTM concatenated with the unit matrix from `SkMatrix::setSinCos`, `postScale`, `setPolyToPoly` and `Concat`), radius, unit-angle, conical, `clamp_x_1`, two-stop, evenly spaced and arbitrary fill and premul stages in lowp and highp; conical strip and focal gradients force highp, so every blend mode and coverage prescaling has a highp version; shaders never take the legacy blitter, opaque shaders draw source-over as Src, and the paint alpha follows as `scale_1_float`; 200,000 random gradient draws over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` patterns | Canvas 2D `createPattern()` fills and strokes | `cpuraster` image shaders as `apply_style()`'s `SkImage::makeShader()` builds them. LibWeb's Skia keeps `SK_ENABLE_LEGACY_SHADERCONTEXT`, so source-over draws of premultiplied sRGB images with equal, non-decal tile modes use `SkBitmapProcState` and `SkARGB32_Shader_Blitter`: `init()`'s tiling division, near-translate snapping and filtering checks, the translate and one-column shader procs, the scale, affine and translate matrix procs (16.16 and 32.32 fixed point, decal fast paths, 4-bit bilinear weights, remapping per 128-entry chunk), NEON `filter_and_scale_by_alpha()` and `blit_row_s32a_opaque`/`blend`, and `blend_row_A8` masks. Other patterns run `SkImageShader::appendStages()`: nearest sampling for integer translations, one-pixel clamps, repeat and decal tiling (lowp's half-open decal test, highp's inclusive edge), `gather_8888`, the four-sample bilinear sampler, `bilerp_clamp_8888` and its forced highp, and `SkColorSpaceXformSteps` to premultiplied sRGB, including Display P3 images; 200,000 random pattern draws over five seeds exact in both default and `-prod -gc none` builds |
| `skia.draw_path` bitmap commands | Canvas 2D `clearRect()` and unfiltered `drawImage()` | `cpuraster.clear_canvas_rect`: `clipRect()` without anti-aliasing (a hard rect, or `SkAAClip::op()`'s rounded rect inside anti-aliased clips) and `clear()` as `drawColor(kSrc)` through `SkScan::FillIRect`. `cpuraster.draw_canvas_image`: `SkCanvas::drawImageRect()` with the strict constraint (mipmaps dropped, fillable rects, quick reject) and `SkBitmapDevice::drawImageRect()`'s `Rect2Rect` matrix, source clipping, subset extraction with `preTranslate`, `Draw::drawBitmap()`'s `SkTreatAsSprite()` and `SkBlitter::ChooseSprite()` (Memcpy, `Sprite_D32_S32` and the raster pipeline sprite blitter), and otherwise the clamped image shader (legacy context or pipeline, now with nearest sampling and lowp's fixed-point `bilerp_clamp_8888`) through `Draw::drawRect()` and `SkScan::FillRect`; transforms that do not keep rects rects fill the rect's path with `SkScan::FillPath` (into a region for the clear's clip, intersected with anti-aliased clips through `SkAAClip::setRegion()`, and through the image shader for images); 200,000 random clears and 200,000 random image draws over five seeds exact, none declined, in both default and `-prod -gc none` builds |
| Non-anti-aliased path fills | Rotated `clearRect()` and `drawImage()`, oversized blur masks | `cpuraster.fill_path` (`SkScan::FillPath`): `SkEdge`'s 26.6 and 16.16 fixed-point lines and forward-differenced quadratic and cubic segments, `SkBasicEdgeBuilder` (poly and clipped builds, vertical-edge combining), `SkTQSort`, `walk_edges()` for winding and even-odd fills and `walk_simple_edges()` for convex paths, the 16.16 clip limit, conservative bounds rounding and `SkScanClipper`; 200,000 random fills of lines, quads, conics and cubics over five seeds exact in both default and `-prod -gc none` builds. Inverse fills are not ported |
| `skia.draw_glyph_run` (`vox_skia_canvas_glyphs`) | Canvas 2D `fillText()` without filters | `cpuraster.fill_canvas_glyphs` on macOS, with CoreText doing exactly what `SkTypeface_Mac` and `SkScalerContext_Mac` ask of it (the font from the file's bytes, `SkCTFontCreateExactCopy()` at the strike's text size, advances and bounding rects through `fTransform`, glyphs drawn into the offscreen `CGBitmapContext`, CoreGraphics' inline point and size transforms evaluated without fused multiply-adds): `SkScalerContextRec`'s relaxed 2x2, `computeMatrices(kVertical)` with its Givens rotation, the quarter-pixel `SkPackedGlyphID` positions and rounding, `generateMetrics()`'s bounds rounding and outset, `SkTMaskGamma<3, 3, 3>`'s default sRGB tables selected by the paint's luminance color (a gradient's average stop color, gray for patterns), the blob's conservative quick reject from the typeface bounds, and `Draw::paintMasks()` through the existing blitters and anti-aliased clip; glyphs over 256 pixels per em are the 64-point strike's outlines (`generatePath()`'s 4x request through `SkCTPathGeometrySink`) filled like `SkCanvas::drawPath()`, concatenated onto the canvas matrix in `SkM44`'s float arithmetic or mapped first under a shader; color typefaces make ARGB32 strikes drawn whole by `Draw::drawSprite()` (sprite blitters, or a clamped image shader where the clip cuts them), and glyphs without outlines stay masks at path sizes; 80,000 random runs over two seeds (22,710 of them drawing, about 1,300 path-sized) and 10,000 color emoji runs (2,960 drawing) exact in both default and `-prod -gc none` builds. Declines faces past the first of a collection (Skia's CoreText manager cannot open them either), color glyphs 8192 or more pixels wide and non-finite positions; Linux uses the FreeType outline, bitmap and COLRv0 routes; COLRv1 remains pending |
| `skia.draw_path` and `draw_glyph_run` color filters | Canvas 2D `filter` lists of grayscale, sepia, saturate, hue-rotate, invert, opacity, brightness and contrast on fills, strokes and `fillText()` | `cpuraster.ColorFilter`: `SkImageFilters::ColorFilter()`'s composed `SkMatrixColorFilter`s, moved into the paint by `SkCanvasPriv::ImageToColorFilter()` and folded by `SkBlitter::Choose()`'s `RemoveColorFilter()`: `filterColor4f()`'s one-pixel highp pipeline for a solid color (then the legacy blitter when it fits in bytes, else the constant pipeline, highp through `unbounded_uniform_color` when a channel exceeds alpha), `SkColorFilterShader` stages after gradients and patterns, `CheckFastPath()` and `nothingToDraw()` seeing the filter, and the filtered luminance color for glyph mask gamma; 200,000 random filtered draws over two seeds exact in both default and `-prod -gc none` builds. Filters that change transparent black decline (they need an image filter layer) |
| `skia.draw_path` and `draw_glyph_run` filter layers | Canvas 2D filters on fills, strokes and text | `cpuraster.draw_filter_layer` and `draw_blur_filter_chain` cover scale/translate blur and drop-shadow layers, every composite mode, color matrices around one spatial filter and throughout repeated blur lists. Rotated layers, chains containing further shadow nodes, sigmas over 135, transparency-flooding matrices and tiling retain fallback. Native fixtures and comparison receipts are linked below. |
| Rest of `skia.draw_path`, `draw_glyph_run` (`canvas_raster.cpp`, `canvas_chromium_raster.h`) | Canvas 2D | Remaining: further spatial chains, general rotated layers, SVG graphs, integer-source spatial resampling, source clipping on spatial draws, large-sigma rescaling and tiling. Direct image filters already cover aligned sources, fractional-source surfaces, deferred conversion and paint alpha. |
| `skia.rasterize_shadow` (`shadow_raster.cpp`) | Portable (sokol/Linux) shadows | Untiled outer shadows and strictly nested inner shadows with rectangular or proven containing rounded outer casters use V. Retained text shadows on macOS also use V for scale/translate transforms, including all smoothing modes, large outlines, variable and color fonts. Intersecting or unproven inner contours, rotated/skewed text layers, sigma over 135 and tiled surfaces retain native fallback; Linux bitmap and COLRv0 glyphs use V composition; COLRv1 remains pending |
| `libLadybirdVSkiaText.dylib` (`native_skia_text_darwin.cpp` and headers, 65 entry points) | macOS native painter (`native_capture_darwin.m`), HarfBuzz advances, glyph intercepts, PNG ICC | Not started: fonts and blobs feeding GG text, images and decode cache, gradients, shadows, blurs, SVG turbulence, command groups, SkPicture recording, Ganesh GPU canvas |
| `libVoxGraphite.dylib` (`native_graphite_darwin.mm`) | Loaded by the bridge | Shapes and paths partly through GG adapters; images, shadows, canvas presentation and pictures remain |
| `libVoxGraphiteDawn.dylib` | Picture playback | Not started |
| Linux `pkg-config skia` | Canvas and portable shadows | Remains until those ports land |

SVG fill/stroke geometry queries now use `cpuraster.path_hit_test`; the
production `vox_skia_path_hit_test` entry point and C transport are removed.
See the [path geometry checks](#path-containment-and-svg-hit-testing-2026-11-09).

Anti-aliased path filling, hairlines, the stroker, dashing, anti-aliased clips,
the legacy solid blitters, the raster pipeline blitter with constant colors,
gradient shaders and image shaders, the legacy bitmap shader context and the
blur mask filter are ported (see `cpuraster/scan_aaa.v`,
`cpuraster/scan_hairline.v`, `cpuraster/stroke.v`, `cpuraster/dash.v`,
`cpuraster/aaclip.v`, `cpuraster/pipeline_blitter.v`, `cpuraster/gradient.v`,
`cpuraster/image_shader.v`, `cpuraster/bitmap_proc.v`, `cpuraster/canvas_image.v`,
`cpuraster/scan_path.v` and `cpuraster/blur.v`), and so are the CoreText glyph
strikes of canvas glyph runs (`cpuraster/glyph_run.v`,
`cpuraster/glyph_coretext.h`), color-matrix canvas filters
(`cpuraster/color_filter.v`) and blur filter layers (`cpuraster/image_blur.v`,
`cpuraster/image_filter.v`, `cpuraster/filter_layer.v`).
Platform
differences matter: macOS LibWeb Skia uses the `SkPathRef` path backend
(trailing moves keep their bounds) and RGBA as kN32 (legacy blitters for RGBA
canvases), while the Linux build defines `SK_HIDE_PATH_EDIT_METHODS`
(`SkPathData`, which trims trailing moves) and `SK_R32_SHIFT=16` (BGRA kN32, so
RGBA canvases use the raster pipeline blitter). The native Linux behavior is
now ported and verified in the Linux RGBA section below. The pipeline stages follow the arm64 (NEON) build; x86 Skia's lowp
`div255` and its `rcp_fast` differ. Next prerequisite: the rest of the image filter
layers (mixed lists, rotations, SVG graphs).

### Drop-shadow canvas layers (2026-11-08)

`cpuraster` now draws a single Canvas2D `drop-shadow()` on fills, strokes and
text under a translation-only canvas transform. Shadow offsets may be
fractional: the image is blurred, sampled through a deferred SrcIn tint,
then merged beneath SourceGraphic before applying the original composite
operation and device clip. This keeps paint alpha on the source and shadow
tint alpha on the shadow. An invalid blur still leaves the tint, offset and
merge intact. Offscreen shadow input is intersected with the content before
unioning the foreground input, so it cannot unnecessarily enlarge the layer.

The port retains the padded image boundary and Skia's matrix-conjugation,
concatenation and integer-bound rounding order. Scaled drop shadows still
decline: differential checks found one-byte errors that require more of
FilterResult's resampling/crop analysis. Rotations, mixed filter lists,
composites that affect transparent black, oversized sigmas/layers and text
without typeface bounds also retain the native fallback. The existing scaled
single-blur path remains supported. This is another migration slice, not a
Skia-free browser.

Feature commit `244dc3607` passes 9,343 supported byte-for-byte comparisons
from 20,000 attempts in each of the default and `-prod -gc none` builds
(seed 20261106); 10,657 draws decline in each build without changing the
pixels. Seven focused raster test files pass normally, four also with
`-prod -gc none`; two HTML canvas test files and a final translation-path
HTML check pass. The full-browser type check passes and the final FMA audit
reports zero contracted multiply-adds. All ten final memory-guard receipts
have actual child exit zero. These are focused correctness checks, with no
production-browser, Linux-build or performance claim. See the
[verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/drop-shadow-20261108.json) for source and
oracle hashes, commands, exits and the unsuccessful intermediate candidates.

Linux dependency audit: `build-linux-browser.sh` still requires `skia.pc`;
`tools/build_linux_native.py` still builds the Skia canvas and shadow bridges;
`skia/canvas.c.v` links that archive and Skia; and
`cpuraster/glyph_scaler_linux.c.v` now selects the portable FreeType outline scaler; bitmap/color faces still decline. The macOS native text,
Graphite and Dawn dependencies listed above also remain. No Skia-free Linux
build has been produced. The local Linux VM failed to bring up SSH on both
startup attempts, so no Linux compilation took place during that slice.

### Portable outer shadows (2026-11-08)

`404906f5b` ports normalized rounded rectangles and AA clip subtraction;
`57422172f` routes untiled portable outer shadows through `cpuraster`.
The normalized geometry and transformed clips match 20,000 randomized pairs
per build, and outer shadows match all 30,000 cases per build (4,938 painted),
in both default and `-prod -gc none` modes. The corpus includes elliptical
corners, rotated/skewed clips, content holes, and zero, negative, tiny and
positive blur values. Focused V and native shadow tests pass; the FMA audit
reports zero contracted operations. The tests preserved local fast-bounds
rejection, hard clipping of nearly integral holes and the separate 24.8
rectangle coverage algorithm. See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/portable-outer-shadow-20261108.json).

Inner/text shadows, tiled surfaces and the other dependencies above remain
open. A new Linux VM now mounts the canonical checkout and has its system
dependencies and compiler installed; Skia-free browser linking is still pending.

`207516e40` also ports nested inner shadows whose outer caster is rectangular.
The difference path preserves PathOps' contour order, near-degenerate edge
elimination and conic endpoint joining. All 30,000 comparisons match in each
build mode (7,964 painted). Focused portable and native shadow tests pass, and
the FMA audit stays at zero contracted operations. The outer-shadow and rounded
rectangle tests also pass on Ubuntu 24.04 aarch64 in normal and `-prod -gc none`
modes, with compiler fallback disabled. The nested inner-shadow tests pass on
Linux too. `e3e879076` supplies the GNU feature flag needed by glibc's combined
trigonometry function. These module tests do not establish a Skia-free browser
link; see the [nested-shadow/Linux receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/nested-inner-shadow-20261108.json).

`fa8188a4e` ports retained text shadows through an unbounded blur layer and one
SrcIn tint on restore. It also adds retained-text baseline snapping, the
CoreText smoothing probe and gamma correction, zero-contrast mask tables, and
aliased large-glyph outlines. All 20,000 comparisons match in each build mode
(4,163 painted), across four smoothing modes, scale/reflection, rounded clips,
variable/color fonts, large glyphs and invalid blur. All 23 raster/native shadow
test files pass and the FMA audit stays clean. The earlier 10,000-case AA and
default-smoothing cohorts also passed. Headers and native oracle includes now
join the pinned differential inputs (`b5634a8cc`). See the
[retained-text receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/retained-text-shadow-20261108.json).

Linux staging now keeps UI2 under `Build/linux/modules` (`6c96821cf`); its real
staging check preserved all 140 entries in the shared macOS UI2 tree. This avoids
replacing host module symlinks with guest-only paths during concurrent builds.

## Hacker News performance (2026-11-06)

GG's current adapters preserve pixels and sustain the same continuous-scroll
publication throughput as Skia. Load/capture uses **2.80% more main-process
instructions** with GG; every one of the seven alternating pairs increases.
This compares all three adapters enabled versus disabled in one executable,
`c05715c149c8a3f7b70644bb425bfdcd740e3cc0f37c59254bae74374b4dd6a5`,
receipt `20261106-123237-a1883a12` (single C unit, literal `-prod`, preallocation).
Unsupported and unmigrated draws still use Skia.

The complete archived 30-story homepage retains its scripts and resources,
replayed over loopback with no-store responses, fresh profiles/caches, retained
OS caches, 1024x768 document pixels and 2x backing scale. Both modes use the
same compiled inputs and native libraries under a publication lease.

| Metric | Skia | GG |
| --- | ---: | ---: |
| Load/capture main-process instructions, median of 7 | 1,822,155,059 | 1,873,254,992 |
| Document installation to native submission, median (range), ms | 174 (120–215) | 176 (127–203) |
| Navigation to native submission, median (range), ms | 491 (294–747) | 566 (327–697) |
| Continuous scroll: median of 4 full-window mean publication FPS | 59.8985 | 59.8983 |
| Scroll interval median, median of trials, ms | 16.647 | 16.636 |
| Scroll interval p95, median of trials, ms | 22.176 | 20.125 |
| Worst observed scroll interval, ms | 32.188 | 37.423 |
| Intervals over 16.667 ms, median of trials | 47.83% | 46.82% |

Instruction counts run from main-process creation through encoded document PNG;
filter helpers, GPU work and external services are excluded consistently. This
is a different scope from the historical total-browser coalition comparison
against Brave. The conservative maximum-GG/minimum-Skia instruction ratio is
1.04846. Native submission includes scripting, style/layout and rendering.
Other sessions and compilation overlapped on the 18-CPU host; the wide wall-time
ranges prevent an isolated renderer wall-time conclusion.

The continuous-scroll cohort delivers 600 precise events per trial at nominal
60 Hz, delta 3 (observed 6.5 CSS pixels per event), reversing every 60 events,
after four seconds of title-based settling. Four alternating pairs complete
2,400 inputs per variant: 4,329 Skia and 4,135 GG total publications, including
stationary publications, and 2,392 changing-scroll intervals each. Actual input
delivery is 59.994–60.002 Hz. Leading counted-scroll delays are 20.30–31.01 ms
for Skia and 20.65–22.66 ms for GG; trailing gaps are 4.37–13.34 ms and
6.73–11.75 ms. Throughput uses the entire first-to-last-input period. The
interval tails and deadline misses remain visible despite the near-60 average;
these are native publications, not physical display scanout.

All timed load PNGs and final scroll PNGs match the fixed Skia references. Final
scroll captures exclude only the existing RAM status rectangle and run after
the timing/counter endpoints. Separate diagnostics confirm 317 GG text draws
on load and, during continuous scrolling plus final publication, 1,194 text
draws and 20 SVG vector batches, with no callback declines. A separate live
HTTPS check loads all 30 stories at the requested viewport, completes readiness
without script/native errors, and scrolls through GG; it supplies no paired
live performance result.

The original 90-event reversal cohort remains retained: it reaches the 498.5px
page boundary, measuring 52.0835 versus 51.5725 FPS while some inputs hold at
the end. Those numbers do not establish continuous-motion throughput. The first
coalition diagnostic was rejected when another session launched an independent
Vox window during its ownership scan. The strict audit remains unchanged; the
later main-process protocol declares its narrower scope. The rejected viewport
preflight and source-change build failures also remain failures.

The benchmark and post-endpoint pixel capture are committed in `890da6bb9`;
`fa96f3caf` adds the continuous reversal schedule and scrolling-only mode.
All 91 focused measurement-tool checks pass; both completed cohorts and the
live check exit zero under their memory guards. See the
[performance receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/hacker-news-performance-20261106.json) for
every trial, executable/resource hashes, CPU diagnostics, host loads, actual
exits and the retained raw PNGs/logs. Reproduction commands are in the
[tool instructions](../tools/gg_migration/README.md).

## Remaining work

Stage22's GG-enabled browser comparison and drawn/declined summary are complete.
Keep using the shared build protocol, publication lease and memory guards for
later cohorts. Pin resources outside the default directories explicitly. Do not
delete the old GG worktree until its committed logic and retained evidence have
been incorporated and verified.

Next renderer gaps: general image entry points and texture sampling; true
two-point conical gradients; gradients with more than eight stops and linear
color space; layer paints; stroke-and-fill; empty inverse fills; remaining
rotated curved path clips; blurs, filters and shadows.

Remaining text includes synthetic bold, color glyphs, aliased masks, glyphs over
256px, fractional paint colors/F32 surfaces, shaders, and recording/picture text.
Frame-borrowing glyph tiles now offer device-clipped draws to GG. Partial clips
use a private copy of the original backdrop, with unchanged raster dimensions,
matrix and glyph positions. Only pixels inside the device clip are published
after a successful draw; a decline leaves the original backdrop for Skia.
Full-tile clips keep the existing direct path. This is a correctness migration;
the extra scratch copy has no measured performance benefit.

The shared recording canvas, SkPicture/Dawn picture playback, LibWeb CPU Skia
paths and Linux still need migration. Remove Skia only after those paths pass
the native, screenshot and browser pixel suites through a production bundle.


### Portable FreeType outlines (2026-11-08)

`37b39b5bd` adds Linux outline glyphs through FreeType's native rasterizer,
with the full strike decomposition, 26.6 sizing, 16.16 transforms, quarter-pixel
placement, mask gamma and the existing V blitters. Large glyphs use the
canonical 64-point outlines, and variable faces explicitly initialize their
default design coordinates. The macOS test switch uses the native FreeType face
factory and the same FreeType library for the reference and candidate.

Across 20,000 runs in each build mode, 18,631 are exact (5,326 painted, about
304 as paths); 1,369 decline. Bitmap/color faces and remaining filter/tiling
cases still retain fallback in this slice. Focused Linux tests pass normally
and with `-prod -gc none`, including hashes captured from native FreeType;
macOS's normal CoreText glyph/filter/text-shadow tests still pass. The FMA audit
reports zero contracted operations. See the [outline verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/freetype-outlines-20261108.json).

`38d1c9223` gives Linux its own production queue, receipts, memory locks and
publication lease under `Build/linux/production-build`. Its focused Linux
supervisor/lease run passes (37 tests, 11 platform skips), including publication
while the macOS build lock is held. Full-browser Skia removal remains open.


### Portable bitmap glyphs and mipmaps (2026-11-08)

`601709dab` ports image mipmap construction and selection; 20,000 random levels
match the native image sampler in each build mode. `f281b6557` adds FreeType
bitmap-only faces, color glyph sprites, strike selection, transformed bitmap
bounds, quarter-pixel phases, and resampling through those mipmaps. Scalable
faces keep embedded strikes disabled, matching the native font defaults.
An original 16-by-16 sbix fixture exercises tiny mipmapped glyphs and rotated,
nonzero bitmap origins on Linux as well as macOS's test-only FreeType backend.

Of 20,000 mixed-font runs per build, 19,688 match exactly (5,441 painted) and
312 decline. The fixture has 9,793 exact runs per build (3,831 painted), with
207 declines for invalid collection faces. Another 10,000 emoji-only runs
match in the normal build (849 painted). The portable fixture's native hashes
pass on Linux normally and with `-prod -gc none`; all 25 CPU raster test files
pass on macOS, and the FMA audit reports zero contracted operations. The
comparison tooling now pins font files and fixture data throughout each run.
See the [bitmap and mipmap receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/bitmap-glyphs-mipmaps-20261108.json),
including the failed diagnostic attempts and their corrections. COLR paint
graphs, oversized glyphs, other filters, the browser bridges and their Skia
links still remain; this is not a completed browser dependency removal.


### Portable layered color glyphs (2026-11-08)

`3bf202a52` adds COLRv0 palette/current-color layers. Small glyphs compose
native FreeType outlines into V-rendered color sprites. Large glyphs replay
the canonical 64-point outlines as vector drawables through saved layers,
including clip-relative allocation and transparency-affecting restores.
An original font fixture covers overlapping translucent outlines and current
text color. Over two seeds, all 48,971 supported runs match exactly; 1,029
invalid-face runs decline. This includes 10,000 normal runs and 20,000
production runs at seed 20261106 plus 20,000 normal runs at seed 20261108.
Focused Linux golden-image tests and CoreText regression tests pass; the FMA
audit reports zero contracted operations. See the [COLRv0 receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/colrv0-glyphs-20261108.json).
The broad Linux module run passes 25 files and exposes two platform-dependent
SVG arc/stroke hashes in `aaclip_test.v`; native Linux verification is pending.
COLRv1 graphs and the browser's remaining native dependencies are still open.


### Native Linux RGBA surfaces and reference fixtures (2026-11-08)

`36c6d146f` carries the destination storage policy through paths, glyphs,
images and filters. Linux RGBA canvases use the raster pipeline. FreeType
bitmap masks and image-filter content use native N32 scratch surfaces, which
are BGRA on Linux. Ordinary saved layers preserve the parent surface format.
This resolves the differences found by the native Linux comparison build.

All 26 CPU raster test files now pass on both platforms. Four focused Linux
files also pass with `-prod -gc none`. Native Linux differential checks match
20,000 clipped draws, 20,000 patterns, 20,000 images, 19,560 supported glyph
runs, 18,736 supported color-filter draws and 5,868 supported blur-layer draws.
The FMA audit reports zero contracted operations and 166 explicit operations.

The fixture capture tool records 60 complete native inputs and output hashes
on each platform. Its macOS outputs equal the frozen macOS test references;
32 Linux hashes differ. The earlier arc investigation is resolved: platform
libm and pixel-layout behavior require native Linux references. See the
[Linux raster report](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linux-rgba-raster-20261108.json),
[macOS fixture inputs](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/macos-native-raster-fixtures-20261108.json)
and [Linux fixture inputs](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linux-native-raster-fixtures-20261108.json).
These are module checks. The browser still links Skia; bitmap export sampling,
remaining filters, tiled draws, boolean shadows and native browser bridges
still require work.


### Linux bitmap export and scaled drop shadows (2026-11-08)

`478d7dcab` selects the native Linux raster-pipeline sampler for RGBA WebGL
bitmap exports. All 448 exhaustive configurations and 20,016 random exports
match in both normal and production builds. A native boundary fixture retains
the differing Linux and macOS row selection. See the
[bitmap export receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linux-bitmap-export-20261108.json).

`f58b137ad` enables single drop-shadow layers under scales and translations.
Saved layers have transparent borders; blur output has initialized borders
that require anti-aliased image edges when transformed. The distinction
resolves the original one-pixel mismatch, and merge surfaces now retain their
one-pixel padding too. Of 20,000 attempts per mode, 15,330 supported macOS
draws match in both normal and production builds; on Linux 16,298 match.
Unsupported draws preserve the destination. Focused platform and production
checks pass, and the arithmetic audit reports zero contracted operations.
See the [scaled-shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/scaled-drop-shadow-20261108.json),
including native fixture inputs and the failed intermediate experiments.

The full Linux browser type check also passes. This does not establish a
Skia-free browser link or run: remaining filter, shadow and native bridge
fallbacks still link Skia.


### Filter restores with all composite operations (2026-11-08)

`87e152a92` removes the composite-mode fallback for single blur and
drop-shadow layers. Restores use a decal shader to fill the clip when the
blender affects transparent black and the filtered image does not cover it.
Empty filtered sources also restore through that blender, while the draw's
quick reject still avoids a restore. Fast bounds preserve the native handling
of empty path bounds.

All 12,195 supported blur draws match out of 20,000 attempts in each build
mode. Drop shadows match 17,475 supported draws in the normal seed-20261106
run and 17,395 in the production seed-20261108 run. The native Linux run
matches 18,608 supported drop-shadow draws. Four focused test files pass on
each platform, including Linux production mode, and 14 native fixtures cover
the clearing and runtime blend modes through an AA clip. The FMA audit reports
zero contracted operations. See the
[composite-filter receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/filter-composites-20261108.json).
Mixed filters, rotated layers, tiled draws and the native browser bridges
remain open.


### Filtered source images and bitmap-space policy (2026-11-08)

`289bb001b` adds translated, pixel-aligned color-filtered image subsets and
a CPU implementation of the bitmap-space blur/drop-shadow policy. Native
image filters preserve their source transform and sampling through
`FilterResult::MakeFromImage`; rasterizing into a layer first is not generally
equivalent. General source-image resampling therefore remains a fallback.
The browser preserves the existing macOS Chromium/Dawn image dispatch.

`a7401d378` fixes sprite eligibility when an RGBA source enters a Linux BGRA
filter layer. Native regression fixtures retain the differing platform rounding.
Of 20,000 attempts, 6,123 supported comparisons match on macOS and Linux at
seed 20261106; 6,223 match in production mode at seed 20261108. These counts
include no-ops and both CPU policies. Image/filter/bitmap-glyph focused tests
and HTML canvas integration pass. The FMA audit reports zero contracted
operations. See the [filtered-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/filtered-images-20261108.json)
for source identities, native fixture inputs, exact declines and failures.
This is CPU verification; Skia-free browser compilation and GPU image parity
remain open.


### Transformed nearest color-filtered images (2026-11-08)

`045e0ace6` extends deferred source images to scales, flips and rotations.
The matrix concatenation preserves SkM44 float association, and image edges
use the native antialiasing and sprite eligibility rules. Four added native
fixtures match on macOS and Linux, including a near-integer transform whose
AA clip prevents sprite snapping.

At seed 20261106, 6,745 of 20,000 comparisons match on both platforms,
with 13,255 declines; production seed 20261108 matches 6,870 with 13,130
declines. Counts include no-ops and the existing bitmap-space policy. Focused
macOS and Linux production image tests pass, and the arithmetic audit reports
zero contracted operations. See the
[transformed-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/transformed-images-20261108.json).
Linear mipmaps, clearing blends under general transforms, fractional source
subsets, image-space blur/drop-shadow, GPU parity and browser dependency
removal remain open.


### Linear mipmaps for filtered images (2026-11-08)

Deferred source images now support linear sampling under scales, flips and
rotations. Sampling interpolates the two adjacent mipmap levels before color
conversion, alpha and color filtering. Native fixtures cover magnification,
rotation and odd-size downsampling in premultiplied sRGB and unpremultiplied
Display P3.

At seed 20261106, 7,347 of 20,000 comparisons match on both macOS and Linux,
with 12,653 declines; production seed 20261108 matches 7,519 with 12,481
declines. Counts include no-ops and the existing bitmap-space policy. All 26
CPU raster test files pass on macOS; the image and mipmap files also pass in
Linux production mode. The FMA audit reports zero contracted operations and
170 explicit operations. See the
[linear-sampling receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/linear-image-sampling-20261108.json).
Clearing blends under general transforms, fractional source subsets, direct
image-space blur/drop-shadow, mixed filters, general rotated layers, GPU
parity and full browser dependency removal remain open.


### Clearing composite modes on filtered source images (2026-11-08)

`b5fe5ba8d` restores color-filtered images across the clip for composite
operations that affect transparent black. Nearest sampling supports affine
transforms; linear sampling supports rect-preserving transforms. Scaled linear
edges use the native layer-space decal ramp. Runtime decal shader children
retain the base image level, matching the native matrix-record policy.

Sixteen new native fixtures match on macOS and Linux. At seed 20261106,
7,523 of 20,000 comparisons match on both platforms with 12,477 declines;
production seed 20261108 matches 7,683 with 12,317 declines. Counts include
no-ops and both CPU policies. All 26 CPU raster test files pass on macOS,
and the image tests pass in Linux production mode. The FMA audit reports zero
contracted operations. The full Linux browser type check passes in 40.23
seconds with 4.75 GB sampled peak RSS. See the
[image-composite receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/image-filter-composites-20261108.json).
The browser still links Skia; the type check does not establish a Skia-free
compile, link or run. Rotated linear restores, source clipping, direct image
blur/drop-shadow, mixed filters and native browser bridges remain open.


### Filtered source-image clipping (2026-11-08)

`e0cd3675f` clips source rectangles to the image before mapping the smaller
source into the destination. Empty clipped sources restore through the
composite operation; the original draw's quick reject and empty-rectangle
handling still precede that restore. Five native fixtures match on both
platforms.

At seed 20261106, 9,055 of 20,000 comparisons match on macOS and Linux,
with 10,945 declines; production seed 20261108 matches 9,161 with 10,839
declines. Counts include no-ops and both CPU policies. Focused image tests
pass on macOS and in Linux production mode; the FMA audit reports zero
contracted operations. See the
[source-clipping receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/image-source-clipping-20261108.json).
The remaining source-image, filter-layer and native bridge work still retains
Skia dependencies in the browser.


### Rotated linear source-image restores (2026-11-08)

`58d397180` extends clearing composite restores to rotated and skewed linear
source images. Singular values select image-space or layer-space decal
sampling. Layer-space edges retain the native scale decomposition and the
separate rounding of the two matrix stages. Nine native fixtures match on
macOS and Linux, including near-unit scales and all seven clearing/runtime
composite modes.

At seed 20261106, 9,057 of 20,000 comparisons match on both platforms with
10,943 declines; production seed 20261108 matches 9,161 with 10,839 declines.
Counts include no-ops and both CPU policies. All 26 CPU raster test files
pass; the image tests also pass in Linux production mode. The FMA audit
reports zero contracted operations and 175 explicit operations. See the
[rotated-restore receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rotated-image-restores-20261108.json).
Blur/drop-shadow source images, mixed filters, general rotated filter layers
and native bridges still retain browser Skia dependencies.


### Color matrices combined with filter layers (2026-11-08)

Filter layers now support color matrices before and after one blur, and
after one drop shadow. A real blur resolves the preceding matrices into
pixels; an identity blur keeps them deferred through the final color filter
and restore blend, preserving native quantization. Eight native fixtures
cover solid/pattern fills, a dashed stroke, clearing/runtime composite
operations, scaled layers, and unpremultiplied destinations.

Of 20,000 attempts, 15,813 supported mixed blur comparisons match on macOS
at seed 20261106, 15,772 in production mode at seed 20261108, and 16,717
on Linux at seed 20261106. Filtered-image comparisons also pass: 9,727
on Linux and 9,856 in macOS production mode, including no-ops and both CPU
policies. All 26 CPU raster files and the focused Linux production tests
pass. The FMA audit reports zero contracted operations. See the
[mixed-filter receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/mixed-filter-layers-20261108.json).
Color filters before drop-shadow, repeated spatial filters, rotated layers,
SVG graphs, source-image blur/drop-shadow and native bridges remain open;
the browser still retains Skia dependencies.


### Color filters before drop shadows (2026-11-08)

Drop-shadow layers now preserve the preceding color filters on the foreground
through its merge draw. Real shadow blurs resolve those filters into pixels;
identity blurs keep them deferred through tinting and sampling. An invalid
blur instead discards its shadow input filter while the foreground retains
it, matching the native filter graph. Five native fixtures cover the real,
identity and invalid blur branches.

The new `CPU_RASTER_CHECKS=mixedshadows` corpus matches 15,840 supported
draws out of 20,000 on macOS at seed 20261106, 15,896 in production mode
at seed 20261108, and 16,760 on Linux at seed 20261106. The unchanged
single-shadow corpus still matches 17,475 supported draws. Focused production
tests pass on both platforms, and the FMA audit reports zero contracted
operations. See the
[prefiltered-shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/prefiltered-drop-shadows-20261108.json).
Spatial filter chains, rotated layers, SVG graphs, image-space blur/drop-shadow
and native browser bridges still retain Skia dependencies.


### Repeated blur filters (2026-11-08)

Sequences of blur filters now share a single source layer and evaluate
backward input-bound requests and separate quantized intermediate images.
Six native fixtures cover Gaussian and box passes, identities on either
side and within a chain, scaled layers, unpremultiplied targets and clearing
composites. Intermediate dimensions are checked before touching the target.

Of 20,000 attempts, 17,490 supported comparisons match on macOS at seed
20261106, 17,435 in production mode at seed 20261108, and 18,459 on Linux
at seed 20261106. All 26 CPU raster test files pass, the focused Linux
production tests pass, and the FMA audit reports zero contracted operations.
See the [repeated-blur receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/repeated-blurs-20261108.json).
Color matrices within repeated spatial chains, drop-shadow chains, rotated
layers, SVG graphs, image-space spatial filters and native bridges remain
open; the browser still retains Skia dependencies.


### Bitmap-space color filters (2026-11-08)

Explicit bitmap-space CPU color filters now draw into an N32 layer before
applying the color filter on restore. Three native fixtures retain the source
quantization and platform rounding for translated premultiplied images,
rotated unpremultiplied Display P3 images, and downsampled clearing restores.

Of 20,000 comparisons, 13,261 match on both platforms at seed 20261106,
with 6,739 declines. Production seed 20261108 matches 13,321 with 6,679
declines. Counts include no-ops and both CPU policies. Focused image tests
pass on macOS and in Linux production mode; the FMA audit reports zero
contracted operations. See the
[bitmap-color receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/bitmap-color-filters-20261108.json).
This validates the explicit CPU policy; the existing macOS Dawn dispatch is
unchanged. Direct image-space spatial filters, remaining spatial chains,
rotated layers, SVG graphs and native bridges retain browser Skia dependencies.


### Portable Linux shadow blending (2026-11-08)

Portable box shadows now select blending for the explicit RGBA surface instead of native N32. Two native fixtures freeze faint inner and outer shadows on both platforms. The isolated regression tests pass on macOS and Linux production builds; 20,000 existing Linux inner-shadow attempts also match, including 5,364 painted results.
See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/shadow-rgba-20261108.json).
The browser still retains Skia dependencies; no Skia-free link or run is claimed.


### Linux rounded-clip convexity (2026-11-08)

Axis-preserving transforms now retain rounded-rectangle convexity on Linux, matching immutable SkPathData. The legacy macOS path behavior is preserved. A frozen mask regression covers the quarter-turn rounding difference. Both platforms match 20,000 rounded-rectangle and difference-clip cases; Linux also matches 20,000 outer-shadow attempts, including 3,285 painted results.
See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rounded-clip-convexity-20261108.json).
The browser still retains Skia dependencies; no Skia-free link or run is claimed.


### Nested rounded inner shadows (2026-11-08)

Portable inner shadows now accept strictly nested rounded contours when bounding-box corners or concentric corner ellipses prove containment. Six native fixtures cover curved outer bounds, scales, rotations, antialiased overlap and concentric insets. The 20,000-attempt corpora match on macOS (5,134 painted), production macOS (5,167 painted) and Linux (5,155 painted). All 27 CPU raster test files pass; the FMA audit reports zero contracted operations. Intersections and shared edges still require the native fallback.
See the [verification receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rounded-inner-shadows-20261108.json).
The browser still retains Skia dependencies; no Skia-free link or run is claimed.


### Color matrices within repeated blur chains (2026-11-08)

Repeated blur layers now retain color matrices between passes. Identity blurs
keep the matrices deferred; real blurs resolve them into N32 pixels before
sampling. Eight native fixtures cover clearing composites, patterns, scaled
layers, unpremultiplied targets and dashed strokes. Canvas integration tests
exercise fills, strokes and text.

Of 20,000 attempts, 16,044 supported comparisons match on macOS at seed
20261106, 16,079 in production mode at seed 20261108, and 16,985 on Linux
at seed 20261106. All 27 CPU raster test files and focused Linux production
tests pass. The FMA audit reports zero contracted operations. See the
[blur/color-chain receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/blur-color-chains-20261108.json).
Drop-shadow chains, general rotated layers, SVG graphs, image-space spatial
filters and native bridges still retain browser Skia dependencies.


### Spatial filters on pixel-aligned source images (2026-11-08)

Direct source-image filters now use V for integer-aligned premultiplied sRGB
subsets at full paint alpha, with one source pixel per device pixel. The
port retains unknown source-image boundaries for identity shadow sampling.
Eight native fixtures cover real and identity blur/shadow passes, subsets,
color-filter chains and clearing composites. A canvas integration test also
checks the direct CPU route against the native command.

Of 20,000 attempts, 18,973 supported comparisons match on both platforms
at seed 20261106, and 19,016 match in production mode at seed 20261108.
The existing Linux filtered-image corpus matches 13,283 supported draws.
All 27 CPU raster files, canvas integration tests and focused Linux
production tests pass. The FMA audit reports zero contracted operations.
See the [aligned-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/aligned-image-layers-20261108.json).
General source-image transforms, fractional subsets, paint alpha and color
conversion still require work, as do the remaining filter graphs and native
bridges. The browser retains Skia dependencies.


### Deferred source-image color state (2026-11-08)

Pixel-aligned source filters now retain unpremultiplied sRGB and Display P3
storage until the native filter graph converts it. Color matrices, identity
passes and shadow foregrounds keep that conversion deferred. Image shadow
merges also retain the original layer coordinates, preserving fractional
offset rounding. Twelve new native fixtures cover these branches; the
canvas integration test now exercises an unpremultiplied filtered image.

Of 20,000 attempts, 18,792 supported comparisons match on both platforms at
seed 20261106, and 18,771 match in production mode at seed 20261108. The
existing Linux image-filter corpus matches 13,330 supported draws. All 27
CPU raster files, canvas integration tests and focused Linux production tests
pass; the FMA audit reports zero contracted operations. See the
[source color-state receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-image-color-state-20261108.json).
Nonintegral mappings, source-image paint alpha, remaining spatial chains,
rotated layers, SVG graphs, tiling and native bridges retain Skia dependencies.


### Fractional source-image filter surfaces (2026-11-08)

Fractional in-bounds source rectangles now draw into an antialiased source
surface before filtering under scale/translation, including flips. Color-only
filters use the same surface policy. Source-image filter evaluation keeps its
original layer coordinates. Six native fixtures cover color conversion,
clearing composites, blur chains, fractional shadows and flipped sources.

At seed 20261106, 18,821 supported comparisons match out of 20,000 on both
platforms. Production runs match 4,698 of 5,000 at seed 20261108 and 4,694
of 5,000 at seed 20261109. All 27 CPU raster files, focused Linux production
tests and canvas integration tests pass; the FMA audit reports zero contracted
operations. HTML continues to round source rectangles; the integration test
checks its existing output and the direct fractional service separately.

The full current Linux browser typecheck passes in 50.18 seconds with 4.72 GB
sampled peak RSS after refreshing the VM UI2 dependency. Skia libraries were
available during that check. See the
[fractional-image receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/fractional-image-layers-20261108.json).
Source-image paint alpha, integer-source resampling, rotations, remaining
spatial chains, SVG graphs, tiling and native bridges retain Skia dependencies.


### Paint alpha before source-image filters (2026-11-08)

Filtered source images now keep paint alpha as a deferred DstIn filter before
the canvas filter graph. Real blurs resolve it into pixels; identity passes
and shadow foregrounds retain it through sampling and color filters. Invalid
shadow blurs still sample SourceGraphic with its paint alpha. Ten native
fixtures cover raw and fractional sources, sRGB and Display P3, unpremultiplied
storage, zero alpha, clearing blends and repeated blur/color lists.

Of 20,000 attempts, 18,735 supported comparisons match on both platforms at
seed 20261106, and 18,801 match in production mode at seed 20261108. The
existing Linux image-filter corpus matches 13,685 supported draws. All 27
CPU raster files, canvas integration tests and focused Linux production tests
pass; the FMA audit reports zero contracted operations. See the
[paint-alpha receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-image-paint-alpha-20261108.json).
Integer-source spatial resampling, source clipping, general rotated layers,
remaining spatial chains, SVG graphs, tiling and native bridges still retain
Skia dependencies.


### Resampling integer source images before blur (2026-11-08)

Scaled, flipped and fractionally translated integer source rectangles now
resolve their sampling, source color conversion, paint alpha and preceding
color filters together before the first real blur. Identity blurs preserve
that ordering. Native bounds analysis chooses clamp or decal and the backing
image or strict subset, including linear mipmaps. Eight new frozen native
fixtures match on both platforms.

At seed 20261108, 8,310 of 20,000 attempts are supported and exact on both
macOS and Linux. Production mode matches 8,349 at seed 20261109. The original
Linux filtered-image corpus matches 14,397 supported draws. All 27 CPU raster
files, the canvas integration test and focused Linux production tests pass;
the FMA audit reports zero contracted operations. Counts include no-ops and
explicit declines. See the [resampling receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/resampled-image-blurs-20261108.json).

Source clipping, scaled shadow foregrounds, all-identity lists, near-integer
transforms, general rotated layers, remaining spatial chains, SVG graphs,
tiling and native browser bridges remain open. The browser still links Skia.


### Source clipping before spatial filters (2026-11-08)

Source rectangles that cross an image edge now clip before the source-to-layer
mapping. Quick rejection retains the original draw bounds, including clearing
blends whose clipped image has no visible pixels. This covers the previously
supported aligned and fractional-source shadows and resampled blur chains.
Shadow restores also reproduce FilterResult's nearest sampling within 1e-3 of
an integer translation while preserving the original geometry. A two-pixel
regression failed before that fix and matches the frozen native result after it.

At seed 20261108, 16,855 of 20,000 attempts are supported and exact on both
macOS and Linux. Production mode matches 16,803 at seed 20261109. All 27 CPU
raster files, canvas integration and focused Linux production tests pass. The
full canonical Linux browser typecheck passes with Skia available; no Skia-free
browser compile/link/run is established. The FMA audit reports zero contracted
operations. Counts include no-ops and explicit declines; nine new native
fixtures and the initial failing checks are in the
[clipping receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/spatial-source-clipping-20261108.json).

Scaled shadow foregrounds, all-identity and nearly integer source mappings,
general rotated layers, remaining spatial chains, SVG graphs, intersecting
boolean shadows, large-sigma rescaling, tiling and native browser bridges
continue to retain Skia dependencies.


### Deferred color through source-image identity blurs (2026-11-08)

When every mapped blur is an identity and a color matrix remains, integer
source images now retain their sampling, color conversion, alpha and matrix
list through the final image draw. The original expanded draw bounds still
control quick rejection, including clearing blends. Six new native fixtures
cover mipmaps, flips, P3, source clipping and a fully transparent clearing draw.

At seed 20261108, 17,281 of 20,000 attempts are supported and exact on both
platforms; production mode matches 17,298 at seed 20261109. All 27 CPU raster
files, canvas integration and focused Linux production tests pass. The FMA
audit reports zero contracted operations. Counts include no-ops and explicit
declines. See the [identity-blur receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-image-blurs-20261108.json).

Identity lists without color matrices, nearly integer deferred mappings,
scaled shadow foregrounds and the previously listed graph/native work remain
open. The browser still links Skia.


### Source-image identity blurs without color matrices (2026-11-08)

Integer source images now also restore all-identity blur lists when no color
matrix remains. Paint alpha stays in the raster pipeline, while unfiltered
full-alpha draws retain the native legacy eligibility. Linear mipmap sampling
correctly declines the legacy bitmap context and uses the raster pipeline.
Six new native fixtures cover these routes, including downsampling, P3,
unpremultiplied pixels, flips, clearing blends and fractional translations.

All 20,000 attempts are supported and exact on both macOS and Linux at seed
20261108, and in production mode at seed 20261109. The original Linux
filtered-image corpus matches 15,427 supported draws. All 27 CPU raster files,
canvas integration and focused Linux production tests pass; the FMA audit
reports zero contracted operations. The full canonical Linux typecheck also
passes with Skia available. Counts include no-ops. See the
[identity-sampling receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-image-sampling-20261108.json).

Nearly integer deferred mappings, scaled shadow foregrounds and the previously
listed graph/native work remain open. The browser still links Skia; a full
Skia-free browser compile/link/run remains unverified.


### Nearly integer source-filter mappings (2026-11-08)

Source filters now reproduce applyTransform's replacement of requested
sampling by default bilinear sampling for nearly integer incoming transforms,
and the final restore's separate reduction to nearest. Real blurs preserve
raw sRGB pixels when no deferred effect requires resolution, including
unpremultiplied storage. Color effects resolve with the original transform.
Slight scales with integer translations also use the native sprite shortcut,
including clearing blends whose clip lies inside the image. Thirteen new
native fixtures cover these rules and factored canvas transforms.

Of 20,000 near-integer attempts, 19,217 supported draws match on each platform
at seed 20261108; production mode matches 19,184 at seed 20261109. Factored
transforms match 19,265 on each platform and 19,207 in production mode. The
original Linux image-filter corpus matches 15,427 supported draws. All 27
CPU raster files pass, as does the expanded image fixture file on macOS and
Linux production builds. Canvas integration, the FMA audit (zero contracted
operations) and the full canonical Linux typecheck pass. Counts include
no-ops and explicit declines. Initial sampling/sprite failures and two
transient, unrelated regex compile failures are retained in the
[near-integer receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/near-integer-image-filters-20261108.json).

Rounding-induced layer crops, scaled shadow foregrounds, remaining spatial
chains, rotations, SVG graphs, intersecting boolean shadows, large-sigma
rescaling, tiling and native browser bridges remain open. The Linux typecheck
uses Skia development files; a Skia-free browser compile/link/run remains
unverified.


### CPU mipmap exhaustion review verification (2026-11-08)

The review's proposed clamp beyond the mipmap pyramid was checked against
the pinned native CPU renderer. Its SkMipmapAccessor calls getLevel(), which
rejects a missing upper level and reloads the base image. When only the lower
level is missing, linear mode retains the available upper level without a
lerp. The separate extractLevel() API clamps, but neither these image shaders
nor the legacy bitmap context use that API.

Eight direct native shader cases match on both platforms. They distinguish
the base image's clamped edge (192) from the final 1x1 mip's average (96), at
scales .125, .1, .05 and .025 in nearest and linear mipmap modes. The portable
regressions pass in default and production builds on macOS and Linux. Another
2,000 macOS and 10,000 Linux mipmap-level comparisons pass. Production sampling
arithmetic is unchanged; comments explain the intentional fallback. See the
[native review verification](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/mipmap-review-native-20261108.json).


### Scaled source-image drop shadows (2026-11-08)

Integer source images under real drop-shadow blurs now resample through the
portable filter layer. The blur input resolves sampling, color conversion,
paint alpha and preceding matrices together. The foreground retains those
effects until the merge, avoiding an extra 8-bit quantization. Its original
global mapping is preserved before translating the merge surface. The blur's
sampling region is independent of the foreground extent. Reversed axes use
sorted double-precision integer filter bounds.

Eight new native fixtures cover scaled subsets, nearest sampling, P3 and
unpremultiplied sources, paint alpha, color matrices, downscaling, reversed
axes and fractional translation. All 86 image-filter reference fixtures pass
on macOS and Linux. Of 20,000 random scaled-shadow attempts, 17,958 supported
draws match exactly on each platform; production mode matches 17,975 at a
second seed. The broader Linux filtered-image cohort matches 16,195 supported
draws. Counts include no-ops and explicit declines.

All 27 CPU raster files, the focused FastC image tests, Linux production image
tests and HTML canvas integration pass. The FMA audit reports zero contracted
operations (175 explicit). The filter still declines identity or invalid
resampled shadow blurs, nearly integer shadow mappings and rounding-induced
layer crops. General spatial chains, rotations, SVG graphs, boolean shadows,
large-sigma rescaling, tiling and native/GPU bridges remain. The browser still
links Skia; a Skia-free Linux browser compile/link/run is unverified. See the
[scaled-source shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/scaled-source-image-shadows-20261108.json).


### Nearly integer source-image shadows (2026-11-08)

Real drop shadows now share the blur's raw-subset shortcut at nearly integer
source mappings. The shadow input can preserve unpremultiplied sRGB storage,
while the foreground keeps its original mapping and deferred effects until
merge. Color-converting sources retain the existing resampling path. Seven
new native fixtures cover both routes, source subsets, requested sampling
and factored canvas transforms. All 93 native image-filter fixtures pass on
macOS and Linux.

Of 20,000 attempts, 19,116 supported draws match on each platform; production
mode matches 19,032 at another seed. A separately factored Linux cohort
matches 19,075. The new raw-shadow regression fails without the change.
Focused C/FastC tests, Linux production image tests and HTML integration pass.
This small forwarding change reuses the preceding slice's broader checks.
Counts include no-ops and explicit declines. Rounding-induced crops and
identity/invalid resampled shadow blurs still decline, and the remaining
filter graphs, native/GPU services and Skia-free browser link/run remain
unfinished. See the [near-integer shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/near-integer-image-shadows-20261108.json).


### Deferred identity and rejected source-image shadow blurs (2026-11-08)

Source-image shadows now keep sampling, source conversion, paint alpha,
color matrices and the SrcIn tint deferred when the blur is an identity.
Rejected blur nodes tint SourceGraphic, while the foreground still retains
its preceding matrices. Compatible offset sampling follows the native rules;
nearest sources requiring a separate linear resolve surface still decline.
The merge drops empty shadow/color-filter results from its bounds, preserving
the native surface origin and floating-point sampling.

Nine additional native fixtures bring the image-filter corpus to 102 exact
cases on both platforms. Of 20,000 identity-shadow attempts, 9,499 supported
draws match on each platform. Production mode matches 9,461 at another seed,
and the broader Linux image-filter cohort matches 16,430. Counts include
no-ops and explicit declines. The production cohort originally found a
one-byte origin error; its frozen regression produces 127 before the fix
and the native 128 afterward, with the whole-image hash matching as well.

All 27 CPU raster test files, C/FastC image regressions, Linux production
image tests and HTML integration pass. The FMA audit reports zero contracted
operations (175 explicit). The Linux browser typecheck passes with Skia
available; the later bounds correction is compiled and exercised by Linux
production image tests. Initial concurrent-edit compile failures and a
comparison rejected by the input guard are retained without pass credit.
The differential harness now enables globals for shared module diagnostics.
Concurrent pixel-readback work is preserved outside these commits and PR
changes. See the [identity-shadow receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-source-image-shadows-20261108.json).

Rounding-induced crops, nearest/fractional-offset resolve surfaces, further
spatial chains, rotations, SVG graphs, boolean shadows, large-sigma rescaling,
tiling and native/GPU bridges remain. The browser still links Skia, and a
complete Skia-free Linux browser compile/link/run remains unverified.


### Nearest source-image shadows with fractional offsets (2026-11-09)

Nearest source images now resolve their shadow tint, color conversion and
paint effects before a fractional linear offset. The foreground remains
deferred. The intermediate retains its transparent pixel border, and its
restore uses the destination's RGBA color type. Linux therefore keeps the
raster-pipeline shader where native N32 would be BGRA. The full pixel outset
is drawn without an unnecessary logical-layer clip; a thin-shadow control
captures legacy bilerp's nonzero four-bit contribution beyond epsilon-rounded
bounds. This fixes the second seed's one-byte coverage difference.

Twelve new native fixtures bring the image-filter corpus to 114 exact cases
on both platforms. Of 20,000 forced-nearest shadow attempts, 19,109 supported
draws match on each platform; production mode matches 19,131 at a second seed.
The broader Linux image-filter cohort matches 16,573 supported draws at seed
20261108. Counts include no-ops and explicit declines. All 27 CPU raster files,
C/FastC image regressions, HTML integration, the FMA audit (zero contracted
operations, 175 explicit) and the canonical Linux browser typecheck pass.

The standalone Linux image tests also compile with Skia unavailable to
pkg-config, then execute all 34 generated test functions. The link command
contains no Skia libraries; readelf and ldd confirm no direct or transitive
Skia dependency. Direct dependencies are FreeType, libm and libc. This proves
the portable image-raster module's build and execution, while the complete
browser still retains Skia services and uses Skia files for its typecheck.
A full Skia-free browser compile/link/run remains unverified.

Rounding-induced crops, additional spatial chains, rotated layers, SVG graphs,
intersecting boolean shadows, large-sigma rescaling, tiling and native/GPU
bridges remain. The [resolve-surface receipt](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/resolved-source-image-shadows-20261109.json)
retains source and binary identities, native hashes, the Linux dependency
inspection and initial failures without full-cohort pass credit.


### Mixed blur and drop-shadow graphs (2026-11-09)

`cda95382d` moves mixed blur/drop-shadow lists off the canvas Skia fallback
for axis-aligned saved layers: fills, strokes, glyph runs and bitmap-space
image layers. Color matrices remain deferred through identity passes, resolve
before real blurs and run before each shadow tint/foreground merge. Each
shadow evaluates its preceding graph separately for the foreground and blur
requests. Source bounds are intersected at each graph leaf before request
unions. Both details have frozen native regression fixtures. Evaluation above
256 graph visits declines before changing destination pixels.

Native captures supply 21 new fixtures on both macOS and Linux (40 mixed
filter fixtures total), including repeated shadows, scaled strokes, P3
patterns, identity passes and clearing composite modes. Random comparisons:

| Platform/build | Seed | Attempts | Exact | Declined |
| --- | --- | ---: | ---: | ---: |
| macOS, default | 20261109 | 5,000 | 3,896 | 1,104 |
| macOS, `-prod -gc none` | 20261110 | 5,000 | 3,811 | 1,189 |
| Linux ARM64, default | 20261109 | 5,000 | 4,141 | 859 |

All runs finish with unchanged input pins. The two earlier failing prototypes
are retained in the receipt and covered by regressions. All 27 CPU raster
test files, focused C/FastC filter-layer tests, and HTML canvas integration
pass. The FMA audit reports zero contracted operations (175 explicit FMAs).
The full Linux browser typecheck passes **with Skia available**.

A separate Linux `-prod -gc none` filter-layer binary compiles with Skia
unavailable to pkg-config and runs all 14 registered test functions, including
the three new tests. Its only direct dynamic dependencies are FreeType, libm
and libc; the transitive library list also contains no Skia. This is a
component proof. The existing production browser predates these changes and
still links Skia; a complete Skia-free browser compile/link/run is unverified.

Direct source-image mixed graphs, rotated layers, SVG graphs, boolean shadow
intersections, large-sigma rescaling, tiling and native/GPU bridges remain.
See the [checks, native fixtures and retained failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/spatial-filter-chains-20261109.json).


### Mixed spatial graphs on source images (2026-11-09)

`0554d9a4d` extends the branching evaluator to source images. Pixel-aligned
sources keep their raw alpha type, color space and paint alpha until each
consumer resolves them. Fractional source rectangles use MakeFromImage's AA
surface. The graph evaluates in the original image-filter coordinate system,
retains the correct known/unknown pixel boundary and applies global shadow
offsets. Fourteen new native cases cover interleaved matrices, repeated shadows,
P3/unpremultiplied input, source clipping, empty sources and zero-alpha clears.
All 128 native source-image fixtures verify on macOS and Linux.

| Platform/build | Sources | Seed | Attempts | Exact | Declined |
| --- | --- | --- | ---: | ---: | ---: |
| macOS and Linux, each | Aligned | 20261111 | 10,000 | 8,824 | 1,176 |
| macOS and Linux, each | Fractional | 20261111 | 10,000 | 8,853 | 1,147 |
| macOS, `-prod -gc none` | Aligned | 20261112 | 5,000 | 4,381 | 619 |
| macOS, `-prod -gc none` | Fractional | 20261112 | 5,000 | 4,431 | 569 |

Every cohort ends with unchanged input pins; exact counts include no-ops.
C and FastC image tests, all 27 raster test files, and HTML canvas image
integration pass. A fresh FMA audit reports zero contracted operations (175
explicit). The full Linux browser typecheck passes with Skia development
files available. The first attempt saw a temporarily incomplete shared
`main.v`; the successful retry pins its unchanged before/after identity.

A separate Linux production/no-GC image test binary runs all 35 registered
tests with Skia unavailable to pkg-config. Its direct dependencies are
FreeType, libm and libc, with no direct or transitive Skia linkage. This is
component evidence; the full browser still needs Skia. The existing production
bundle predates this change and cannot validate it.

General resampled integer-source mixed graphs still decline, along with the
remaining crops, rotations, SVG graphs, boolean shadows, large-sigma/tiling
paths and native/GPU bridges. The requested Skia-free full-browser Linux
compile/link/run remains unverified. See the
[source-image graph checks and native fixtures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-spatial-chains-20261109.json).


### Mixed spatial graphs after source-image resampling (2026-11-09)

`0061d1d78` supports scaled/flipped integer-source images when a real blur
precedes the first shadow. Each branch resolves the source using its own
first-blur sample bounds. Reusing one union-sized source surface changes
clamping and strict/decal sampling. Larger default and production cohorts
exposed that error; both full inputs and native output hashes are frozen as
regressions. Ten new native fixtures include those failures, minification,
identity prefixes, nearest sampling, source clipping and clearing composites.
All 138 source-image native fixtures verify on macOS and Linux.

| Platform/build | Seed | Attempts | Exact | Declined |
| --- | --- | ---: | ---: | ---: |
| macOS, current pinned compiler | 20261113 | 10,000 | 8,288 | 1,712 |
| Linux ARM64 | 20261113 | 10,000 | 8,288 | 1,712 |
| macOS, `-prod -gc none` | 20261114 | 5,000 | 4,137 | 863 |

Each accepted cohort finishes with unchanged listed input pins. Counts include
no-ops. C/FastC image tests, all 27 CPU raster files, HTML canvas integration,
and the full Linux browser typecheck pass. The latter uses installed Skia
development files. The FMA audit reports zero contracted operations (189
explicit with this compiler). Host checks pin compiler executable
`d39159ce199ca1aa9c8734d2ae4f4a05fd468d79165ad9a1e8a7c0d6b2ac3145`;
the receipt retains the compiler/test-harness and shared-edit setup failures.
These concurrent bounded checks establish pixel parity, not performance gains.

The Linux production/no-GC image-test executable runs all 38 registered tests
with Skia unavailable to pkg-config. Its only direct libraries are FreeType,
libm and libc, and its transitive library list contains no Skia. This remains
component evidence: the full browser and the older shared bundle still need
Skia, and a Skia-free full-browser Linux compile/link/run remains unverified.

Resampled graphs that branch into a shadow before a real blur keep the native
fallback so their original foreground stays deferred. Remaining crops,
rotations, SVG graphs, boolean shadows, large-sigma/tiling paths and native/GPU
bridges also remain. See the
[resampling graph checks and retained failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/resampled-spatial-chains-20261109.json).


### Path containment and SVG hit testing (2026-11-09)

`c0bf6f955` translates path containment to V, including monotonic line,
quadratic, conic and cubic crossings, on-curve points, inverse/even-odd fill
rules and coincident tangent cancellation. SVG stroke queries use the existing
V dash and stroke-outline engines at the native identity resolution scale;
non-scaling strokes transform the geometry first. The production C entry point
and query struct are removed. The compatibility API in `skia/` now calls V.

| Platform/build | Seed | Containment queries | Fill/stroke queries |
| --- | --- | ---: | ---: |
| macOS, C backend | 20261116 | 100,000 exact | 100,000 exact |
| Linux ARM64, C backend | 20261116 | 100,000 exact | 100,000 exact |
| macOS, `-prod -gc none` | 20261117 | 50,000 exact | 50,000 exact |

These cohorts have no declines and finish with unchanged input pins. An
independent native capture supplies 72 coincident-curve boundary expectations
on each platform. Focused C/FastC hit tests, the compatibility API tests, all
28 CPU raster test files and SVG pointer/group/bounding-box integration pass.
Raster-suite credit combines 27 completed files from the interrupted batch
with a guarded final text-shadow check; no whole-batch exit is claimed.
The bounding-box fixture now owns its helper so it can compile independently;
its assertions are unchanged. The optional FastC differential driver encounters
an unsupported generic in V's math library; no FastC random-parity credit is
claimed. The FMA audit finds zero contractions (189 explicit operations).
The full Linux browser typecheck passes with Skia development files available.

A standalone Linux production/no-GC hit-test binary compiles with Skia
unavailable to pkg-config, then executes all four registered test functions.
Its only direct libraries are FreeType, libm and libc, with no direct or
transitive Skia linkage. This verifies the geometry component. The complete
browser still links Skia and its older production bundle cannot validate this
change. Full-browser Linux compile/link/run without Skia remains unverified.
See the [receipts, native fixtures and retained interrupted checks](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/path-hit-geometry-20261109.json).


### Resampled chains beginning with a real shadow (2026-11-09)

`5756031ad` preserves the source-image foreground through a first real
`drop-shadow()` in a mixed graph. Only the blur branch resolves its source
sampling, alpha and color filters. The merge draws the original deferred
foreground; later blur/shadow nodes consume that merged surface. Identity
blur and matrix prefixes remain supported. Identity/rejected shadows before
the first real blur still decline.

Eight new native regressions cover scaling, nearest sampling, minification,
P3/unpremultiplied input, flips, nearly integer mappings, repeated shadows,
clipped sources and clearing composites. All 146 native source-image fixtures
verify on both platforms. At seed 20261119, each platform matches 4,121 of
5,000 attempts and declines 879. Optimized macOS/no-GC matches 1,647 of 2,000
at seed 20261120 and declines 353. Counts include no-ops; every cohort ends
with unchanged input pins. Host contention and the separate eligibility sample
are retained without performance credit.

C/FastC image and filter-layer tests, HTML canvas integration, the full Linux
browser typecheck and the zero-contraction FMA audit (189 explicit operations)
pass. The typecheck uses installed Skia development files. The standalone
Linux production/no-GC image-test binary runs all 39 registered tests with
Skia unavailable to pkg-config and no direct or transitive Skia linkage.
Its direct libraries are FreeType, libm and libc. The complete browser still
links Skia, and full-browser Linux compile/link/run without it remains open.
See the [source identities, fixtures and guarded check results](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/shadow-first-spatial-chains-20261109.json).


### Resampled chains beginning with an identity shadow (2026-11-09)

`290baeab8` extends the source-view graph to identity shadows. The shadow
keeps its tint, color filters and image sampling deferred through merge. A
nearest source followed by a fractional linear offset resolves the tinted
input first, preserving both sampling operations. The lone-shadow renderer
uses the same preparation helper. Matrix prefixes stop folding at the first
shadow, so later matrices apply to its merged image.

Eight new regressions bring the independently verified native source-image
corpus to 154 cases per platform. The nearest/P3 case retains different
macOS and Linux native expectations. Random comparisons, including no-ops:

| Platform/build | Seed | Attempts | Exact | Declined |
| --- | --- | ---: | ---: | ---: |
| macOS, identity-first graph | 20261121 | 1,000 | 844 | 156 |
| Linux, identity-first graph | 20261121 | 2,000 | 1,661 | 339 |
| macOS, production/no-GC graph | 20261122 | 2,000 | 1,676 | 324 |
| Linux, existing nearest-source shadows | 20261123 | 2,000 | 1,921 | 79 |

Every cohort ends with unchanged input pins. C/FastC image and filter-layer
regressions, HTML canvas integration, the full Linux browser typecheck and
zero-contraction FMA audit (189 explicit operations) pass. The Linux standalone
production/no-GC image-test binary runs all 40 registered tests with Skia
unavailable to pkg-config and no direct or transitive Skia dependency. Its
direct libraries remain FreeType, libm and libc. The browser typecheck uses
Skia development files; the complete browser still links Skia.

Rejected mixed-graph blur nodes, rounding-induced crops, rotated layers, SVG
filters, boolean shadows, large-sigma/tiling paths and native/GPU bridges
remain. A full Skia-free Linux browser compile/link/run is still unverified.
See the [native platform expectations, checks and retained setup failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/identity-first-spatial-chains-20261109.json).


### Rejected blur branches in mixed shadow graphs (2026-11-09)

`ab4ec8e68` handles rejected drop-shadow blur nodes in mixed graphs. The
shadow's tint/offset branch reads the original SourceGraphic while the
foreground retains its preceding filters. Source bounds, requests and fast
bounds follow that branch reset. Resampled images keep an unfiltered source
view independently of their resolved foreground. Invalid standalone blur
functions continue to discard preceding nodes as before.

Eleven new native image cases freeze resets before/after blurs, after earlier
shadows and after an alpha-changing matrix. All 165 image fixtures verify on
both platforms. Two additional geometry-layer cases replace the former
unsupported-case expectation with native pixels for both destination alpha
types; the rotation guard is preserved. The receipt retains that initial
assertion failure without whole-selection pass credit.

At seed 20261124, macOS and Linux each match 853 of 1,000 resampled graph
attempts, declining 147. Optimized macOS/no-GC matches 840 of 1,000 at seed
20261125, declining 160. Fill/stroke/glyph layer cohorts match 387 of 500 on
macOS and 400 of 500 on Linux, declining 113 and 100 respectively. Counts
include no-ops; all cohorts finish with unchanged input pins.

Final C/FastC focused tests, HTML canvas integration, the full Linux browser
typecheck and zero-contraction FMA audit (189 explicit operations) pass.
A standalone Linux production/no-GC executable runs all 42 image tests with
Skia unavailable to pkg-config and no direct or transitive Skia linkage.
Its direct libraries are FreeType, libm and libc. The browser typecheck uses
installed Skia development files, and the complete browser still links Skia.
Full-browser Linux compile/link/run without Skia remains unverified.
See the [native branch-reset fixtures and guarded checks](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/rejected-shadow-graphs-20261109.json).


### Cropped deferred image views (2026-11-09)

`c03433aba` retains MakeFromImage's layer crop on deferred foregrounds and
shadow source views. The renderer clips intermediate source-over draws to
that crop. A visible crop followed by a fractional offset resolves the tinted
input first, preserving the crop and its quantization through both sampling
operations. Identity-first graphs bypass the raw blur-subset shortcut.

A bounded geometry search found three exact float inputs whose mapped image
extends one pixel past its stored layer bounds. The prior renderer declined
all three identity-shadow probes. Their float bits are frozen in twelve
independent native cases, covering identity, real and rejected shadow blurs,
alpha matrices, P3, unpremultiplied sources and clearing composites. All 177
native image fixtures verify on both platforms; C/FastC image and filter-layer
regressions pass.

Default macOS and Linux each match 880 of 1,000 crop-focused attempts at seed
20261127, declining 120. Optimized macOS/no-GC matches 880 of 1,000 at seed
20261128, also declining 120. Earlier identity/rejected-only cohorts each
match 453 of 500 and decline 47. Counts include no-ops; all cohorts finish
with unchanged input pins. The initial probe is diagnostic evidence, not a
performance measurement.

HTML canvas integration, the full Linux browser typecheck and zero-contraction
FMA audit (189 explicit operations) pass. The Linux standalone production/no-GC
image binary executes all 43 registered tests with Skia unavailable to
pkg-config and no direct or transitive Skia linkage; direct libraries are
FreeType, libm and libc. The browser typecheck uses installed Skia development
files, and the complete browser still links Skia. The older shared production
bundle predates this change.

Raw near-integer real-blur crop/resampling cases and other layer crops remain,
along with rotated layers, SVG graphs, boolean shadows, large-sigma/tiling
paths and native/GPU services. Full-browser Linux compile/link/run without
Skia remains unverified. See the [native crop cases, baseline probes and guarded checks](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/deferred-image-crops-20261109.json).

### Color-filter image crops and clearing restores (2026-11-09)

`216da0f27` preserves the source layer crop for color-filter-only images.
Bounded blends clip the draw; transparency-affecting blends resolve the cropped
image before restoring across the full clip. General affine bounds use mapped
float corners, retaining the existing double-precision scale/translate path.

The new random crop selection exposed a real mismatch at case 92: a gain of
100 amplified sampling beyond the source crop, producing red 39 instead of 36
at pixel (9, 8). The exact source, background and filter request are frozen as
a regression; independent native recapture on both platforms reproduces the
original full expected SHA-256. Twelve additional native cases cover gain,
opacity, P3, source alpha, clips and clearing modes. All 190 image fixtures
verify on macOS and Linux. Initial focused checks caught five rotated-image
regressions from applying scale-only bounds math; their failures remain in
the receipt and the final C/FastC image and filter-layer suites pass.

Default macOS and Linux each match 1,863 of 2,000 crop-focused attempts at
seed 20261129, declining 137. Optimized macOS/no-GC matches 1,888 of 2,000
at seed 20261130, declining 112. The broader image-filter selection matches
4,122 of 5,000 on each platform at seed 20261131, declining 878. Counts
include no-ops; every final cohort finishes with unchanged input pins.

HTML canvas integration, the full Linux browser typecheck and the FMA audit
pass (zero contracted operations, 189 explicit). A standalone Linux
production/no-GC executable runs all 45 image tests with Skia unavailable to
pkg-config and no direct or transitive Skia linkage; direct libraries are
FreeType, libm and libc. The browser typecheck uses installed Skia development
files. The complete browser still links Skia, and full-browser Linux
compile/link/run without Skia remains unverified. The shared production bundle
was not used to validate this fix; its parsed source manifest predates it.

Raw near-integer real-blur crops, rotated saved layers, SVG graphs, boolean
shadows, large-sigma/tiling paths and native/GPU services remain. See the
[original mismatch, native fixtures, input pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/color-image-crops-20261109.json).

### Nearly integer blur source crops (2026-11-09)

`66151b4db` handles rounding-induced source crops in single image blurs and
blur/color-filter chains. When a crop is visible to the requested blur input,
the source resolves sampling and alpha conversion first. A request wholly
inside the logical layer retains the native raw subset shortcut, including
unpremultiplied storage. Cropped near-integer shadow graphs still decline
without changing the destination; their branches need independent decisions.

A geometry search found three distinct float inputs that previously declined.
Eighteen new native regressions cover visible crops, interior requests,
premultiplied/unpremultiplied images, clearing restores and blur/color chains.
Every new native case changes pixels; all 208 fixtures verify on macOS and
Linux. The diagnostic search output retains duplicate hits explicitly, and
compiler failures from initial probe setups receive no comparison credit.

At seed 20261132, macOS and Linux each match 1,954 of 2,000 crop-focused
attempts, declining 46. Optimized macOS/no-GC matches 1,948 of 2,000 at seed
20261133, declining 52. The existing near-integer image selection matches
4,807 of 5,000 on each platform at seed 20261134, declining 193. Counts
include no-ops; all final cohorts finish with unchanged input pins.

C/FastC image and filter-layer tests, HTML canvas integration, the full Linux
browser typecheck and the FMA audit pass (zero contracted operations, 189
explicit). A standalone Linux production/no-GC executable runs all 46 image
tests with Skia unavailable to pkg-config and no direct or transitive Skia
linkage; direct libraries remain FreeType, libm and libc. The browser
typecheck uses installed Skia development files. The shared production bundle
was not used to validate this slice. The complete browser still links Skia;
full-browser Linux compile/link/run without it remains unverified.

See the [baseline declines, eighteen native cases, input pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/near-integer-blur-crops-20261109.json).

### Cropped first-shadow image branches (2026-11-09)

`0ab10a4cf` resolves a cropped nearly integer source separately for each
first-shadow blur request. An interior request can retain raw source pixels
and their alpha type; a visible crop resolves sampling and conversion first.
The foreground remains deferred until merge. Lone cropped real shadows use
the same graph path. The source policy requires no pending color filter,
paint alpha, tint or color-space conversion before reusing raw pixels.

Eighteen new native cases cover lone shadows, interior requests and mixed
blur/color/multiple-shadow graphs, with both source alpha types. Every new
case changes pixels. All 226 native fixtures verify on both platforms.
The prior unsupported-case regression now covers a real blur before the
first shadow, which remains a separate unported case.

Default macOS and Linux each match 1,892 of 2,000 crop-focused attempts at
seed 20261135, declining 108. Optimized macOS/no-GC matches 1,902 of 2,000
at seed 20261136, declining 98. The existing first-shadow graph selection
matches 4,138 of 5,000 on each platform at seed 20261137, declining 862.
Counts include no-ops; all cohorts finish with unchanged input pins.

C/FastC image and filter-layer suites, HTML canvas integration, the full
Linux browser typecheck and the FMA audit pass (zero contracted operations,
189 explicit). The standalone Linux production/no-GC executable runs all 47
image tests with Skia unavailable to pkg-config and no direct or transitive
Skia linkage; direct libraries are FreeType, libm and libc. The browser
typecheck uses installed Skia development files, and the shared production
bundle was not used to validate this slice. The complete browser still links
Skia; full-browser Linux compile/link/run without it remains unverified.

See the [native branch cases, source pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/first-shadow-image-crops-20261109.json).

### Cropped image graphs with prior blurs (2026-11-09)

`b9ec7f034` retains a deferred source view when a real blur precedes the
first shadow. Each request for that blur can reuse raw storage or resolve
its visible crop independently. This removes the previous branch-order
restriction; the guard for differing parameter/mapped layer bounds remains.

Eighteen new native cases cover blur-before-shadow graphs, high-gain color
filters between nodes, interior clips and additional blur/shadow branches,
with both source alpha types. Every case changes pixels. The expectations
were captured independently before the V implementation change and verified
through the canonical fixture generator. All 244 native image fixtures verify
on macOS and Linux, and the former unsupported regression is replaced with
positive native expectations.

Default macOS and Linux each match 1,890 of 2,000 crop-focused attempts at
seed 20261138, declining 110. Optimized macOS/no-GC matches 1,891 of 2,000
at seed 20261139, declining 109. The broader resampled graph selection matches
837 of 1,000 on each platform at seed 20261140, declining 163. Counts include
no-ops; all final cohorts finish with unchanged input pins.

C/FastC image and filter-layer suites, HTML canvas integration, the full Linux
browser typecheck and the FMA audit pass (zero contracted operations, 189
explicit). The standalone Linux production/no-GC executable runs all 48 image
tests with Skia unavailable to pkg-config and no direct or transitive Skia
linkage; direct libraries are FreeType, libm and libc. The browser typecheck
uses installed Skia development files. The shared production bundle was not
used to validate this slice. The complete browser still links Skia, and
full-browser Linux compile/link/run without it remains unverified.

Other crop/bounds cases, rotated saved layers, SVG graphs, boolean shadows,
large-sigma/tiling paths and native/GPU services remain. See the
[independent native expectations, guarded checks and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/prior-blur-image-crops-20261109.json).

### Original source-image layer bounds (2026-11-09)

`bab7f6d56` preserves the integer layer bounds produced by MakeFromImage's
concatenated source transform. Single blur/shadow layers and blur/spatial
graphs use those bounds instead of re-mapping the parameter-space destination.
Raw near-integer subsets retain their actual snapped bounds. This removes
the guards that declined deferred shadows when the two calculations differed.

A bounded search found twelve declined geometries. Four distinct inputs,
including bounds that grow and shrink, are frozen in twenty-four native cases
covering identity/real shadows, prior blurs, color filters, P3, source alpha,
clips and clearing blends. The random baseline also exposed a real bug at
case 3: alpha 4 instead of 3 at pixel (25, 7). Its exact source, background
and filter request are saved; native recapture on both platforms reproduces
the original full expected SHA-256. All 269 native image fixtures verify.

Default macOS and Linux each match 1,920 of 2,000 bounds-focused attempts at
seed 20261141, declining 80. Optimized macOS/no-GC matches 1,935 of 2,000 at
seed 20261142, declining 65. Broader resampled graphs match 811 of 1,000 on
each platform at seed 20261143, declining 189; near-integer image layers match
955 of 1,000 at seed 20261144, declining 45. Counts include no-ops; every final
cohort finishes with unchanged input pins.

C/FastC image and filter-layer suites, HTML canvas integration and the FMA
audit pass (zero contracted operations, 189 explicit). The standalone Linux
production/no-GC executable runs all 50 image tests with Skia unavailable to
pkg-config and no direct or transitive Skia linkage; direct libraries are
FreeType, libm and libc. The initial full-browser typecheck hit an unavailable
method in concurrent SVG geometry work. After that source was corrected in
the shared checkout, the same check passed. The initial failure is retained;
no foreign source edits are included in this slice.

The browser typecheck uses installed Skia development files. The shared
production bundle was not used to validate this change. The complete browser
still links Skia; full-browser Linux compile/link/run without it remains
unverified. See the [original failure, native cases, source pins and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/source-image-layer-bounds-20261109.json).

### Large single-blur layers (2026-11-09)

`4115cd979` ports progressive resampling for sigmas beyond the raster blur
engine's 135 limit. Each pass keeps floating-point logical bounds and padded
integer surfaces. The low-resolution blur retains its final upscale until
restore. Single saved canvas blur layers support this path, including incoming
and outgoing color matrices and clearing blends. The standalone image blur API
also supports large, asymmetric sigmas. Native sigma clamping still applies.
Large direct source-image filters, spatial chains, drop-shadows, rotated layers
and tiled surfaces retain their guards.

Thirty-six independent native fixtures cover image subsets, threshold sigmas,
progressive rescaling, asymmetric axes, clips, color filters, strokes and
clearing restores. Four captured macOS mismatches freeze initialized padding,
color-filter ordering, logical bitmap subsets and clearing draw selection.
A narrow Linux fixture also exposed an intermediate-surface distinction:
saved canvas filters use N32 buffers, whereas the standalone image API keeps
RGBA. All thirty-six fixtures now match native expectations on each platform.

Default C builds match 2,000 large image-filter attempts on each platform at
seed 20261147 (147 empty results). The optimized macOS/no-GC image run matches
1,000 at seed 20261154 (69 empty). Default canvas runs at seed 20261146 match
2,539 of 3,000 attempts on macOS and 2,657 on Linux, declining 461 and 343.
The broader resampled graph control matches 846 of 1,000 on macOS at seed
20261155, declining 154. Counts include no-ops. All completed final cohorts
finish with unchanged input pins.

The first 2,000-attempt optimized/no-GC canvas run reached the unchanged 3 GiB
memory guard and supplies no passing result. Eight separate 128-attempt
processes, with seeds 20261153 through 20261160, subsequently matched 840 of
1,024 attempts, declining 184, within that same budget. The failed larger
attempt remains recorded. These bounded no-GC diagnostics do not establish
bounded allocation over a long-running no-GC process.

The focused C suites, HTML canvas integration, Linux browser typecheck and C
FMA audit pass (zero contracted operations, 189 explicit). The earlier three
image/filter suites also pass FastC. The new FastC large-blur suite fails the
captured degenerate linear-gradient fixture: an emitted-C probe shows a fully
transparent source layer. A capacity-initialization exploration also failed
and was reverted. No FastC canvas parity is claimed for this slice.

A separate Linux production/no-GC executable compiles with Skia unavailable
to pkg-config and runs all four new test functions, including the thirty-six
fixtures, under the 3 GiB guard. Its link command, `readelf` and `ldd` show no
direct or transitive Skia dependency; direct libraries are FreeType, libm and
libc. This verifies the component. The browser typecheck uses installed Skia
development files. The older shared bundle does not contain this change and
was not used to validate it. The complete browser still links Skia; full
Linux browser compilation, linking and execution without it remain open.

See the [native fixtures, failed attempts, final checks and Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/large-blur-rescaling-20261109.json).

### Large aligned and fractional source-image blurs (2026-11-09)

`bfa0951df` sends large single-blur image filters through the CPU rescaling
engine when the original pixels are aligned or MakeFromImage prescribes an
AA surface for a fractional source subset. Exactly aligned factored mappings
also work. Image filters retain their original layer coordinates and RGBA
intermediate buffers. When the near-identity downsample is skipped, the blur
retains the source's alpha type instead of treating unpremultiplied pixels as
premultiplied. Other deferred source transforms keep their existing guard.

Thirty-five supported fixtures match independent native expectations on macOS
and Linux, covering P3, both source alpha types, paint alpha, color filters,
clips, clearing modes, clipped sources and asymmetric/scaled fractional
surfaces. Four further controls retain native reference hashes and verify that
unsupported transforms decline without changing the destination. The final
fixture explicitly checks raw unpremultiplied storage through a skipped
resample; final focused suites and the Linux component executable include it.

At seed 20261161, the baseline declines all 500 attempts. The new code matches
392 of those same attempts on each platform, declining 108. Default C builds
match 1,573 of 2,000 at seed 20261162 on each platform, declining 427. Optimized
macOS/no-GC matches 1,560 of 2,000 at seed 20261163, declining 440. The existing
converted-image control also passes. Counts include no-ops and every completed
cohort finishes with unchanged input pins.

The C source/image/filter suites, the corresponding FastC source/image/filter
suites, HTML canvas integration, Linux browser typecheck and C FMA audit pass
(zero contracted operations, 189 explicit). The earlier FastC saved-canvas
large-blur gradient failure remains separate. A standalone Linux production/
no-GC executable compiles with Skia unavailable to pkg-config and explicitly
runs all three new test functions under the 3 GiB guard. Its link command,
`readelf` and `ldd` show no direct or transitive Skia dependency; direct libraries
are FreeType, libm and libc.

These checks verify the component. The browser typecheck uses installed Skia
development files, and the older production bundle was not used to validate
this slice. Complete Linux browser compilation, linking and execution without
Skia remain open. See the [native expectations, baseline, guarded cohorts and
Linux linkage](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/large-source-image-blurs-20261109.json).

### Near-integer large blurs with skipped downsampling (2026-11-09)

`e51a070aa` admits near-integer source mappings when the native downscale-step
calculation omits both resampling passes. The original pixels and snapped
origin then follow the same path as a smaller blur. Existing eligibility
checks still exclude incoming color/alpha effects and visible source crops
that require resolution. Near-integer mappings that need actual resampling
retain their guard.

The baseline declines all 500 requests at seed 20261165. The new default C
builds match all 2,000 requests at that seed on macOS and Linux, including that
same 500-request prefix. Optimized macOS/no-GC matches all 2,000 at seed
20261166. All final cohorts finish with unchanged input pins. Two additional
native fixtures cover both source alpha types and fractional near-integer
origins; source-image coverage now includes 37 supported native fixtures and
four decline controls on each platform.

Focused C/FastC source/image/filter suites, Linux browser typechecking and the
C FMA audit pass (zero contracted operations, 189 explicit). The standalone
Linux production/no-GC source-image executable runs all four registered test
functions under the 3 GiB guard with Skia unavailable to pkg-config. Its link
command, `readelf` and `ldd` show no direct or transitive Skia dependency.

HTML integration remains pending. The pinned comparison compiler exceeded
the unchanged 12 GiB aggregate guard twice. A fresh attempt with the production
browser's compiler reached invalid `to_keyword()` and `StyleValueList.create()`
calls in concurrent, uncommitted CSS parser edits. Those edits were preserved;
the unsuccessful attempts are retained. After those API calls were corrected,
both compilers still exceeded the same guard. An experiment using plain error
messages instead of formatting error objects also exceeded it and was reverted;
every assertion remained enabled. Integration validation therefore remains
limited by compilation memory on macOS. A separate Linux attempt fails before
running any tests at another concurrent, uncommitted CSS edit: a `:not()` loop
iterates `SelectorList` instead of its `.selectors` array. That edit was also
preserved. The earlier integration result predates this near-integer change
and cannot validate it.

The Linux typecheck uses installed Skia development files. The shared bundle
was not used to validate this slice, and complete browser compilation, linking
and execution without Skia remain open. See the [native fixtures, guarded
checks and integration failures](https://github.com/vox-browser/vox-tests/blob/a50c0037a29324ced47b3f6ad410171e52e248e6/evidence/gg-migration/large-near-integer-image-blurs-20261109.json).


### External parity suite and large canvas shadows (2026-11-09)

The CPU differential suite and all 68 generated receipts (517,447 lines)
now live in `vox-browser/vox-tests`. Imported receipts retain their exact
bytes and original SHA-256 hashes. Vox keeps a pinned launcher and small
focused unit tests. Four launcher checks and twenty production-manifest
checks pass; new bulk evidence belongs in the test repository.

`e9c57e1fc` adds large saved-canvas drop shadows using the rescaled blur,
deferred tint/offset and foreground merge. Native N32 rules survive a
resolved shadow intermediate on Linux. All 58 large-blur fixtures, including
22 new shadow cases, verify on macOS and Linux. Through the external launcher,
macOS matches 112 of 128 large-shadow requests and Linux matches 111 of 128
(seed 20261181). Optimized macOS/no-GC matches 110 of 128 (seed 20261182).
Other requests decline; counts include no-ops. All cohorts finish with
unchanged inputs under the 3 GiB guard. The C FMA audit passes with zero
contracted operations (189 explicit).

The standalone Linux production/no-GC executable runs all five registered
large-blur test functions with Skia unavailable to pkg-config; its link,
`readelf` and `ldd` checks find no Skia dependency. This is component evidence.
The current browser typecheck stops at a CSS highlight-selector error before
execution. The inherited FastC degenerate-gradient failure remains open.
The complete browser still links Skia; full Linux compile/link/run without
it remains unverified. See the [retained checks and failures](https://github.com/vox-browser/vox-tests/blob/b61c01f7326843d005cad1f3e5f9a1269da5db2f/evidence/gg-migration/external-suite-and-large-shadows-20261109.json).


### Large source-image drop shadows (2026-11-09)

`24e007856` retains original image coordinates, RGBA filtering rules and
source alpha/color metadata through large shadow blur and merge. An eligible
deferred foreground is drawn from its original view. This covers aligned
sources, prescribed fractional AA surfaces and eligible near-integer sources;
other deferred large mappings keep their guards.

The baseline declines all 500 attempts at seed 20261191; the candidate matches
395 of that same 500. Final default C cohorts match 1,563 of 2,000 on both
macOS and Linux at seed 20261192, declining 437. Optimized macOS/no-GC matches
777 of 1,000 at seed 20261193, declining 223. Counts include no-ops; every
completed cohort retains unchanged input pins. Twenty-two independent native
shadow fixtures verify on each platform. Their bulk inputs and receipts live
in `vox-tests`; the focused V regression uses compact hashes and existing inputs.

Focused C/FastC image suites, Linux HTML canvas integration, the full Linux
browser typecheck and the C FMA audit pass (zero contracted, 189 explicit).
The standalone Linux production/no-GC image executable explicitly runs all
five test functions with Skia unavailable to pkg-config. Its link command,
`readelf` and `ldd` show no direct or transitive Skia dependency. This verifies
the component: the browser integration checks still use installed Skia, and
full Linux browser compile/link/run without it remains open. The older shared
bundle was not used to validate this change. See the [native cases, guarded
cohorts and component linkage](https://github.com/vox-browser/vox-tests/blob/202eeab62636f300465f78280e3fc9e7ce9a31c3/evidence/gg-migration/large-source-image-shadows-20261109.json).


### Large blurs with an initial minified-source resolve (2026-11-09)

`a53278da8` handles whole-image mappings for which native rescale resolves
minification before progressive downsampling. The step-count test preserves
that boundary; other deferred mappings keep their guards. Sampling, paint
alpha, P3 conversion and incoming matrices resolve together, while outgoing
matrices stay deferred through the large blur.

The fixed-sigma baseline declines all 500 requests at seed 20261201; the
candidate matches all 500. Broader final cohorts vary scales, flips, sigmas
and matrices: macOS and Linux match 1,380 of 2,000 requests at seed 20261202,
declining 620. Optimized macOS/no-GC matches 699 of 1,000 at seed 20261203,
declining 301. Counts include no-ops; all completed cohorts finish with
unchanged inputs under the 3 GiB guard. Eight additional native regressions
verify on both platforms. Focused C/FastC suites, Linux browser typechecking,
Linux HTML canvas integration and the C FMA audit pass (zero contracted,
189 explicit).

The standalone Linux production/no-GC image executable runs all six registered
test functions with Skia unavailable to pkg-config. Its direct libraries are
FreeType, libm and libc; link/readelf/ldd checks find no Skia dependency. Browser
integration still uses installed Skia, so the requested full-browser Linux
compile/link/run without it remains open. See the [native inputs, cohorts and
component linkage](https://github.com/vox-browser/vox-tests/blob/ecea3ad79cde8a95bac6a811ad46ba0a04b50e42/evidence/gg-migration/large-minified-source-blurs-20261109.json).


### Large shadows of minified whole images (2026-11-09)

`f90220e40` resolves a minified whole image for the shadow blur's own requested
bounds, then merges the original deferred foreground above the tinted,
offset blur. Foreground sampling, paint alpha and incoming color effects
remain deferred through merge. An offscreen shadow retains the foreground.

The corrected baseline declines all 500 requests at seed 20261211; the
candidate matches 340 of that same cohort, declining 160. Final default C
cohorts on macOS and Linux both match 1,360 of 2,000 requests at seed 20261212,
declining 640. Optimized macOS/no-GC matches 705 of 1,000 at seed 20261213,
declining 295. Counts include no-ops; completed cohorts finish with unchanged
input pins under the 3 GiB guard. The first driver attempt omitted the
minification selector and is retained as a setup error, outside these results.
Ten independent native fixtures verify on each platform, including two
foreground-only results whose shadow lies outside the clip.

Focused C/FastC suites, Linux browser typechecking, Linux HTML canvas
integration and the C FMA audit pass (zero contracted, 189 explicit). The
standalone Linux production/no-GC image executable runs all seven registered
test functions with Skia unavailable to pkg-config; link/readelf/ldd checks
find no direct or transitive Skia dependency. Its direct libraries are
FreeType, libm and libc. Browser integration still uses installed Skia;
full-browser Linux compile/link/run without it remains open. See the
[native cases, setup error, cohorts and component linkage](https://github.com/vox-browser/vox-tests/blob/655628b3d28da2c41312f5af653c2071b22f294b/evidence/gg-migration/large-minified-image-shadows-20261109.json).


### Large filters of minified source subsets (2026-11-09)

`fb9c8e5af` extends initial source resolution to cropped images when native
rescale requires it before progressive downsampling. The extracted bitmap
keeps its original row stride and layer crop. Fractional subsets retain their
AA surface; shadow merge retains the original deferred foreground.

At seed 20261221 the baseline accepts 47 of 500 requests; the candidate accepts
336 of the same cohort. Final default C cohorts on macOS and Linux both match
1,418 of 2,000 requests at seed 20261222, declining 582. Optimized macOS/no-GC
matches 686 of 1,000 at seed 20261223, declining 314. Counts include no-ops;
all completed cohorts finish with unchanged input pins. Fourteen independent
native regressions verify on each platform, covering integer, fractional,
clipped and flipped source subsets across blur and shadow filters.

Focused C/FastC suites, Linux browser typechecking, Linux HTML canvas
integration and the C FMA audit pass (zero contracted, 189 explicit). The
standalone Linux production/no-GC executable runs all eight registered image
test functions with Skia unavailable to pkg-config. Link/readelf/ldd checks
find no direct or transitive Skia dependency; direct libraries are FreeType,
libm and libc. Browser integration still uses installed Skia development
files. Full-browser Linux compile/link/run without Skia remains open. See the
[guarded comparisons and dependency proof](https://github.com/vox-browser/vox-tests/blob/a0a230fb6b113ac5935d7a758a6805add64031c3/evidence/gg-migration/large-minified-source-subsets-20261109.json).
