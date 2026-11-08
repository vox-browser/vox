# Migrating from Skia to vlib/gg

Vox currently renders through two Skia builds: LibWeb's Skia (CPU raster,
`libLadybirdVSkiaText.dylib` and the `skia/` module) and the pinned Chromium
Skia Graphite builds (`libVoxGraphite.dylib` on Metal and
`libVoxGraphiteDawn.dylib` for pictures). Brave parity depends on reproducing
Chromium's Skia output exactly. The migration replaces Skia with `gg.canvas`, a
new `vlib/gg` module, without changing any pixel of the passing tests.

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
  would contract into FMAs, and `tools/gg_migration/fma_audit.py` enforces it.
- **Verification.** `tools/gg_migration` runs scene scripts through the pinned
  Skia (an oracle linked against `libskia.a`) and through `gg.canvas`, compares
  every byte, and traces both Metal command streams to locate the first
  divergent draw.

The ABI between Vox and Graphite is plain values and pixel buffers
(`native_graphite_bridge.h`), so each entry point can be replaced by a V
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
[default-selection receipt](gg-migration/default-20261106.json) for the verified
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
[review-fix receipt](gg-migration/pr-reviews-20261105.json) for source pins,
commands, actual exits and retained failures.

The follow-up review confirmed those implementation fixes and found three text
helper tests still referencing Darwin-only definitions on other platforms.
`b434ae7005` puts their bodies under matching macOS guards. The previous
cross-target checks omitted `text_test.v`; verification now typechecks all 12
canvas test files for both Linux and Windows (24 checks), then runs the text
and platform test files on macOS. All pass. This follow-up changes only tests;
see its [verification receipt](gg-migration/pr-review-followup-20261105.json).

A fresh review of `b434ae7005` reproduced two further state-management bugs.
`6c8b7be581` clears pending clip usage, order and depth when a draw list is
discarded; otherwise restoring a clip after `clear()` could resurrect the
discarded depth and reject the first new draw. `5b06b5a56b` unwinds the implicit
save if layer creation fails, preserving the caller's save and matrix. Both
regressions failed before the fixes and pass afterwards. All 12 canvas test files,
three affected files with `-gc none`, and six Linux/Windows type checks pass.
The new Metal pixel test also checks that clearing pending usage preserves the
active clip geometry. See the [fresh-review receipt](gg-migration/review-20261106.json).

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
See the [focused verification receipt](gg-migration/focused-20261105.json) for
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
bridge (`native_gg_text.h`), and the bridge's raster glyph paths (retained glyph
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
claim. See the [clipped-text receipt](gg-migration/clipped-text-20261106.json)
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
(`native_gg_shape.h`) first offer each descriptor to `ggshape.draw`:
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
[non-scaling stroke receipt](gg-migration/non-scaling-20261105.json) for pins,
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
[stage22 receipt](gg-migration/stage22-20261105.json) for commands, build
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
`tools/gg_migration/fma_audit.py --contracted-only` lists any it finds. V
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
| `skia.draw_glyph_run` (`vox_skia_canvas_glyphs`) | Canvas 2D `fillText()` without filters | `cpuraster.fill_canvas_glyphs` on macOS, with CoreText doing exactly what `SkTypeface_Mac` and `SkScalerContext_Mac` ask of it (the font from the file's bytes, `SkCTFontCreateExactCopy()` at the strike's text size, advances and bounding rects through `fTransform`, glyphs drawn into the offscreen `CGBitmapContext`, CoreGraphics' inline point and size transforms evaluated without fused multiply-adds): `SkScalerContextRec`'s relaxed 2x2, `computeMatrices(kVertical)` with its Givens rotation, the quarter-pixel `SkPackedGlyphID` positions and rounding, `generateMetrics()`'s bounds rounding and outset, `SkTMaskGamma<3, 3, 3>`'s default sRGB tables selected by the paint's luminance color (a gradient's average stop color, gray for patterns), the blob's conservative quick reject from the typeface bounds, and `Draw::paintMasks()` through the existing blitters and anti-aliased clip; glyphs over 256 pixels per em are the 64-point strike's outlines (`generatePath()`'s 4x request through `SkCTPathGeometrySink`) filled like `SkCanvas::drawPath()`, concatenated onto the canvas matrix in `SkM44`'s float arithmetic or mapped first under a shader; color typefaces make ARGB32 strikes drawn whole by `Draw::drawSprite()` (sprite blitters, or a clamped image shader where the clip cuts them), and glyphs without outlines stay masks at path sizes; 80,000 random runs over two seeds (22,710 of them drawing, about 1,300 path-sized) and 10,000 color emoji runs (2,960 drawing) exact in both default and `-prod -gc none` builds. Declines faces past the first of a collection (Skia's CoreText manager cannot open them either), color glyphs 8192 or more pixels wide and non-finite positions; Linux declines until FreeType's scaler is ported |
| `skia.draw_path` and `draw_glyph_run` color filters | Canvas 2D `filter` lists of grayscale, sepia, saturate, hue-rotate, invert, opacity, brightness and contrast on fills, strokes and `fillText()` | `cpuraster.ColorFilter`: `SkImageFilters::ColorFilter()`'s composed `SkMatrixColorFilter`s, moved into the paint by `SkCanvasPriv::ImageToColorFilter()` and folded by `SkBlitter::Choose()`'s `RemoveColorFilter()`: `filterColor4f()`'s one-pixel highp pipeline for a solid color (then the legacy blitter when it fits in bytes, else the constant pipeline, highp through `unbounded_uniform_color` when a channel exceeds alpha), `SkColorFilterShader` stages after gradients and patterns, `CheckFastPath()` and `nothingToDraw()` seeing the filter, and the filtered luminance color for glyph mask gamma; 200,000 random filtered draws over two seeds exact in both default and `-prod -gc none` builds. Filters that change transparent black decline (they need an image filter layer) |
| `skia.draw_path` and `draw_glyph_run` blur layers | Canvas 2D `filter: blur()` on fills, strokes and `fillText()` | `cpuraster.draw_blur_layer`: `AutoLayerForImageFilter` and `internalSaveLayer()` for a scale-translate CTM (layer bounds from the clip bounds outset by the blur kernel and the paint's fast bounds rounded out with skif's epsilon, the transparent padding pixel, `SkM44::postTranslate()` for the layer matrix), `internalDrawDeviceWithFilter()` with `insetForSaveLayer()` and the layer-space sigma, SkBlurEngine's `Raster8888BlurAlgorithm` (`eval_blur_passes()`, the float Gaussian pass below sigma 2, `ThreeBoxApproxPass` with `ScaledDividerU32` up to 135) inside `Builder::blur()`'s bounds, and `FilterResult::draw()`'s sprite or image-shader draw-back with the composite operation; 60,000 random `SkImages::MakeWithFilter()` blurs and 60,000 random blurred canvas draws over two seeds exact in both default and `-prod -gc none` builds. Rotations, blenders that change transparent black, sigmas over 135, blurs mixed with other filters and fonts without typeface bounds decline |
| Rest of `skia.draw_path`, `draw_glyph_run` (`canvas_raster.cpp`, `canvas_chromium_raster.h`) | Canvas 2D | Remaining: scaled drop shadows, mixed and rotated filter layers, SVG filter graphs, and image filters on `drawImage()` |
| `skia.rasterize_shadow` (`shadow_raster.cpp`) | Portable (sokol/Linux) shadows | Not started: AA clips under transforms, PathOps difference, blur mask filters, blur image filter layers, glyph masks |
| `libLadybirdVSkiaText.dylib` (`native_skia_text_darwin.cpp` and headers, 65 entry points) | macOS native painter (`native_capture_darwin.m`), HarfBuzz advances, glyph intercepts, PNG ICC | Not started: fonts and blobs feeding GG text, images and decode cache, gradients, shadows, blurs, SVG turbulence, command groups, SkPicture recording, Ganesh GPU canvas |
| `libVoxGraphite.dylib` (`native_graphite_darwin.mm`) | Loaded by the bridge | Shapes and paths partly through GG adapters; images, shadows, canvas presentation and pictures remain |
| `libVoxGraphiteDawn.dylib` | Picture playback | Not started |
| Linux `pkg-config skia` | Canvas and portable shadows | Remains until those ports land |

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
RGBA canvases use the raster pipeline blitter); the Linux behavior is not ported
yet. The pipeline stages follow the arm64 (NEON) build; x86 Skia's lowp
`div255` and its `rcp_fast` differ. Next prerequisite: the rest of the image filter
layers (scaled drop shadows, mixed lists, rotations, SVG graphs).

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
[verification receipt](gg-migration/drop-shadow-20261108.json) for source and
oracle hashes, commands, exits and the unsuccessful intermediate candidates.

Linux dependency audit: `build-linux-browser.sh` still requires `skia.pc`;
`tools/build_linux_native.py` still builds the Skia canvas and shadow bridges;
`skia/canvas.c.v` links that archive and Skia; and
`cpuraster/glyph_scaler_linux.c.v` still declines glyphs. The macOS native text,
Graphite and Dawn dependencies listed above also remain. No Skia-free Linux
build has been produced. The local Linux VM failed to bring up SSH on both
startup attempts, so no Linux compilation took place during this slice.

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
[performance receipt](gg-migration/hacker-news-performance-20261106.json) for
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
