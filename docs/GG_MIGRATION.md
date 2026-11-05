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

## Status (2026-11-05)

The opt-in browser adapters and differential tools now live on canonical Vox
`master` (`05ffb14b8`, `edeebc78e`). They were integrated from `gg-migration`
`7377e0384`; the original worktree and its historical results remain intact.
Build and test from `/Users/alex/code/vox2`.

The V renderer commit is pushed and verified on the PR. The canonical Vox push
was rejected as non-fast-forward: `origin/master` at `868e16b99` has three
commits absent locally, while the shared local history has hundreds absent
remotely. The tested Vox integration, tooling and report commits remain local.
Reconciling those histories requires a decision consistent with the repository's
linear-history and no-rewrite rules; no force push, merge or rebase was attempted.

The upstream implementation is V branch `gg-skia-parity`, PR
[vlang/v#31826](https://github.com/vlang/v/pull/31826), now at `b434ae7005`.
`V_BIN=~/code/v-gg/v sh build-prod-browser.sh` selects that compiler. The build
recognizes `vlib/gg/canvas` and supplies `-d vox_gg_canvas`; ordinary V builds
exclude the adapters. Runtime selection remains `VOX_GG_TEXT=1`,
`VOX_GG_SHAPES=1`, and `VOX_GG_PATHS=1`. Unsupported draws retain Skia fallback.

The GG compiler predates `v root`. Build detection now uses the existing
`@VEXEROOT` library probe (`aa03e9ba8`), including for moved compilers and
staged runtimes. Three focused checks pass; real compiler probes detect the
GG module and leave it disabled for the standard shared V compiler.

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
On canonical master, frame-borrowing glyph tiles with a device clip keep Skia's
bounded draw because the GG glyph adapter currently has no device-clip argument.

The shared recording canvas, SkPicture/Dawn picture playback, LibWeb CPU Skia
paths and Linux still need migration. Remove Skia only after those paths pass
the native, screenshot and browser pixel suites through a production bundle.
