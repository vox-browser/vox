# Skia to gg.canvas migration tools

These tools verify that `gg.canvas` (in the V repository) reproduces the pixels
of the pinned Chromium Skia that Vox currently uses, bit for bit.

- `skia_oracle.mm` executes a scene script with Skia Graphite on Metal, linked
  against the pinned `libskia.a`, and writes `NAME.expected.bgra` plus a Metal
  command trace for every scene.
- `canvas_scene.v` executes the same script with `gg.canvas` and compares every
  byte. Build it with `-d trace` to record its own Metal trace.
- `metal_trace.mm` swizzles the Metal classes to record shader sources,
  pipeline and depth/stencil state, render passes, and the vertex, instance and
  uniform bytes of every draw call.
- `trace_diff.py` reports the first differing draw call or instance between an
  oracle trace and a gg.canvas trace.
- `gen_shape_corpus.py` generates deterministic scene scripts; `--msaa-backdrops`
  also gives 4x MSAA scenes a backdrop, and `--clip-outs` adds non-AA difference
  clip rectangles (`clipout` lines) to the same scenes. `--clips` generates
  scenes with `save`/`restore`, intersect and difference `cliprect`/`cliprrect`
  lines, `drrect` draws and the clips of single rounded CSS border sides.
  `--paths` generates filled `path` lines (polygons, stars, curves, several
  contours, rect-shaped, nested-rect and oval paths) mixed with shapes and
  clips; `--strokes` mostly strokes them with every join and cap, and
  `--curves` strokes and fills curves that need chopping or turn around on a
  line (cusps); `--lines` draws single line segments of every cap, including
  hairlines and zero-length dots; `--clip-paths` clips shapes and paths with
  `clippath` lines (polygons, stars, several contours, border-corner miters,
  rect and oval paths) and rect and rrect clips. `--gradients` paints rects,
  rrects and ovals with `gradient` lines (linear, and two-point conical
  gradients that are mostly radial, with 2 to 10 stops, every tile mode,
  implicit, duplicate and unsorted positions, premultiplied interpolation and
  local matrices), built like the bridge's SVG path gradients; with `--paths`
  or `--strokes` it paints the path scenes with them.
- `--inverse` is `--paths` with half of the path fills inverted (path FILL 2
  and 3 are the inverse winding and even-odd fill types).
- `--layers` generates `savelayer` scenes (clips, unbounded and bounded,
  nested layers with shapes, paths and gradients inside, draws after their
  `restore`); the oracle's `savelayer [L T R B]` calls saveLayer() without a
  paint.
- `scenes/fractional-layers.txt` checks eight layer restores, including fractional
  rectangle clips, thin bounds, nested layers, backdrops and forced MSAA.
  The oracle also accepts `edgequad L T R B FLAGS [X0 Y0 ... X3 Y3]` for
  solid-color shader probes; this command is not a canvas_scene draw API.
- With `VOX_GG_DIAGNOSTICS=1` the gg.canvas adapters print one `VOX_GG` line
  per shape, path or SVG image descriptor with whether it was drawn;
  `summarize_gg_diagnostics.py` counts them in the candidate logs of a
  `capture_ab.py` run (pass `--candidate-env VOX_GG_DIAGNOSTICS=1`).
- `minimize_scene.py` shrinks a failing corpus scene to the lines that still
  make gg.canvas differ from the oracle.
- `fma_audit.py` fails if clang fuses multiply-adds in `canvas__*` functions
  (or those of `--prefix`); Skia is compiled with `-ffp-contract=off`.
  Instructions after assembler-local labels count toward their function. For
  `cpuraster__` it lists the explicit `mad()`/`fma` calls that reproduce
  Skia's raster pipeline and `SkCubics`; with `--contracted-only` it compiles
  the C again with `-ffp-contract=off` and lists only the functions clang
  fused on its own, which must be none.
- `graphite_shape_oracle.mm` runs Vox's own `libVoxGraphite.dylib` entry point
  on shape descriptors and traces it. With a third argument it replays
  descriptors dumped from the browser (`NAME.shape.bin`, `NAME.args` and
  `NAME.clips.bin`) over the oracle's backdrop.
- `path_bridge_check.v` draws random path descriptors with libVoxGraphite's
  `vox_graphite_draw_path_pixels()` and with `ggshape.draw_path` (the
  `VOX_GG_PATHS=1` adapter) and compares every byte.
- `shape_bridge_check.v` draws the descriptors saved by
  `graphite_shape_oracle.mm` with `ggshape.draw` (the `VOX_GG_SHAPES=1`
  adapter) and compares every byte with that entry point's output.
- `skia_text_oracle.mm` draws glyph-run scenes with LibWeb's CPU Skia (the
  vcpkg build linked by `libLadybirdVSkiaText.dylib`) exactly like the bridge's
  retained glyph path and writes `NAME.expected.bgra`; `text_scene.v` runs the
  same scripts with `gg.canvas.RasterSurface` and compares every byte.
  `gen_text_corpus.py` generates random runs (fonts, sizes, colors,
  backgrounds, matrices and smoothing flags).
- `test_cpu_raster.sh OUTPUT [COUNT]` builds `skia_cpu_oracle.cpp` (the
  original LibWeb Skia implementations of everything moved to the Skia-free
  `cpuraster` and `gfxfont` code) against the vcpkg `libskia`, then
  `cpu_raster_check.v` compares both byte for byte: `read_pixels` over every
  premultiplied channel/alpha pair, font validation over every installed font,
  WebGL bitmap export over every layout, alpha type, color space, format,
  premultiplication and flip, plus `COUNT` random cases each; random
  anti-aliased and non-anti-aliased path fills; and random Canvas2D fills, hairline strokes and
  wider `SkStroke` strokes (every cap and join, miter limits around their
  thresholds, closed rects, cusps, degenerate curves, zero-length contours and
  extreme widths), and `SkDashPathEffect` dashes (random, degenerate and
  invalid intervals and phases, lines and rects culled to the device,
  translations, too many dashes), all also inside random anti-aliased and
  hard-edged clips (rects, circles, ellipses, slivers and curved paths with
  either fill rule), with every composite operation the raster pipeline
  blitter draws (over backgrounds with transparent, opaque and
  channel-equals-alpha pixels), and as blurred shadows (rects, rings, open
  and oversized rect contours, curves, hairlines and strokes across the
  no-blur, Gaussian, box and clamped sigma ranges; a declined shadow must
  leave the pixels untouched), and with linear, radial and conic gradients
  (degenerate geometries, focal and strip cases, swapped circles, thin rings,
  zero to nine hard and uneven stops, singular transforms) and patterns
  (one-pixel to 24-pixel images, premultiplied, unpremultiplied and Display
  P3, every repetition, legacy-context and raster-pipeline cases), and the
  bitmap commands (`clearRect()` under hard and anti-aliased clips, and
  `drawImage()` from whole, partial and out-of-bounds sources into sprite,
  scaled, flipped and quarter-turned destinations), through the production
  `vox_skia_canvas_path()`, and `fillText()` glyph runs (repository and macOS
  fonts, collections, variable, CFF and color emoji fonts, every
  quarter-pixel phase, mask and path sizes, flipped, rotated and skewed
  transforms, styles, composites and clips) through
  `vox_skia_canvas_glyphs()`, and all three under canvas filter lists of
  color matrices and blurs (`oracle_filters()`), plus image filter blurs
  through `SkImages::MakeWithFilter()` (`oracle_image_blur()`); declined
  draws must leave the pixels untouched.
  Inputs must stay unchanged during the run; set `CPU_RASTER_TEST_PROD=1` for
  `-prod -gc none`, and `CPU_RASTER_CHECKS=strokes`, `composites`, `shadows`,
  `gradients`, `patterns`, `clears`, `images`, `bwfills`, `glyphs`,
  `colorfilters`, `filterlayers` or `imageblur` to run only those
  comparisons (`CPU_RASTER_GLYPH_FONT` limits the glyph runs
  to one font file); a `-gc none` binary never frees, so run its
  categories in separate processes. The driver takes an optional seed after `COUNT`; with
  `CPU_RASTER_FAILURE_DIR` set it saves a failing case's starting, Skia and
  cpuraster bitmaps and parameters there.
- `test_clipped_text.sh OUTPUT [COUNT]` builds a native CPU Skia oracle and a
  V driver for the canonical borrowed-frame glyph adapter. It compares the
  original Skia draw with the real `ggtext.glyph_run` callback, including partial
  device clips, fractional affine transforms, 1x/2x backing scales, unsupported
  fonts/paints, row padding and immutable frame snapshots. A callback that writes
  before declining verifies that clipped staging preserves the fallback backdrop.
  Source, compiler, font, GG library and Skia hashes must stay unchanged.
- `metal_trace_inject.mm` builds `libvox_metal_trace.dylib`, which records the
  Metal work of any process started with `DYLD_INSERT_LIBRARIES` into
  `$VOX_METAL_TRACE_DIR` (used to inventory the pipelines of the Brave fixtures).
- `capture_ab.py` captures every Brave fixture with one Vox bundle, alternating
  explicit legacy Skia (`VOX_USE_SKIA=1`) and a GG candidate (`VOX_GG_TEXT=1` lets
  `gg.canvas` draw the bridge's CPU glyph runs, `VOX_GG_SHAPES=1` its Graphite
  shape descriptors). It compares decoded pixels
  outside the status bar's live RAM readout, captures the control again when
  they differ, and classifies each fixture as `equal`, `equal_to_repeat`,
  `different`, `unstable` or `failed`. `--recompare` rebuilds the summary
  from existing captures, preserving recorded exits, candidate environment,
  capture mask and validation failures. Missing exits or registration proof and
  interrupted/incomplete cohorts cannot pass recomparison.
  Each run needs a new output directory. The runner pins the executable, native
  libraries, input fixtures, assets and resources before every launch, verifies
  adapter registration, retains partial results and actual exits, and exits
  nonzero on rendering differences, unstable/failed captures or changed inputs.
  Runs against canonical `Build/v/Vox.app` hold a shared publication lease.
  The production builder can compile while captures run, then waits to publish
  its bundle until the captures release the lease. Hash checks still reject
  fixture/resource changes and replacements by publishers that lack the lease.
  `--fixture-list FILE` selects one fixture stem per line for a historical cohort.
  The runner and fixture list are hashed too. Repeat `--resource FILE` for
  resources outside `input`, `assets` and `resources`; a missing file fails
  before capture, and a changed file invalidates the cohort. For the 262-fixture
  cohort, include the local font used by `guardian-intrinsic-font-width.html`,
  as in the browser command below.

For non-scaling strokes, add `--non-scaling` to `path_bridge_check`: it flags
every generated stroke without changing the random stream, including when
combined with `--svg` and `--gradients`. The adapter transforms the finished path
like SkPath, preserves its original clips, and cancels only the SVG path matrix
using SkMatrix's inverse and SkM44 concatenation. Perspective strokes still decline.

The macOS default build requires `-d vox_gg_canvas` and a V compiler containing
`gg.canvas`, included upstream since PR #31826 (squash `ac9fbda08a`). The build
uses its `@VEXEROOT` probe, including with the compiler predating `v root`.
With `V_BIN` unset, an older shared compiler can select the existing
`~/code/v-gg/v`; an explicit compiler without GG fails the default build.
An explicit `VOX_USE_SKIA=1 sh build-prod-browser.sh` builds legacy Skia without
the GG adapters. Neither build is Skia-free yet: required native preparation,
canvas, shadows, images, filters and recording paths still depend on Skia.

The GG-capable binary registers all three adapters by default. Launch with
`VOX_USE_SKIA=1` for legacy Skia; that override dominates individual adapter flags.
Explicit `VOX_GG_TEXT=0`, `VOX_GG_SHAPES=0` and `VOX_GG_PATHS=0` isolate a port.
`capture_ab.py` explicitly uses legacy Skia for its control. A candidate with no
adapter flags selects all three; specifying any adapter flag preserves the
historical selective behavior (unspecified adapters off). The saved metadata
records both environments. The Hacker News performance tool likewise selects
both variants explicitly, so a default change cannot compare GG with itself.
Build and test from the canonical Vox checkout, following its shared-build rules:

```sh
V_BIN=~/code/v-gg/v sh build-prod-browser.sh
python3 tools/run_memory_bounded.py --limit-gib 3 --lock Build/gg-adapters.lock \
  --report Build/gg-adapters.json -- ~/code/v-gg/v -memory-limit 10G -cc clang \
  -enable-globals -d vox_gg_canvas -path "$PWD|@vlib|@vmodules" test ggshape ggtext
python3 -m unittest discover -s tools/gg_migration -p '*_test.py'
```

Typical run (use a V compiler built from the gg branch):

```sh
clang++ -std=c++20 -O1 -fno-objc-arc -mmacosx-version-min=14.0 -DSK_GRAPHITE -DSK_METAL \
  -DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER -I$SKIA tools/gg_migration/skia_oracle.mm \
  tools/gg_migration/metal_trace.mm -L$PINNED -lskia -lskcms -framework Metal \
  -framework Foundation -framework CoreGraphics -framework ImageIO -framework CoreText \
  -framework CoreFoundation -o Build/gg-oracle/skia-oracle
python3 tools/gg_migration/gen_shape_corpus.py --count 400 > $OUT/script.txt
Build/gg-oracle/skia-oracle $OUT/script.txt $OUT
v -cc clang -o Build/gg-oracle/canvas-scene tools/gg_migration/canvas_scene.v
Build/gg-oracle/canvas-scene $OUT/script.txt $OUT
```

`$SKIA` is `Build/deps/skia-brave/source` (Chromium 155 Skia with Vox's Metal
precision patch) and `$PINNED` holds copies of its `libskia.a`/`libskcms.a`.

The focused borrowed-frame text comparison runs without rebuilding the browser:

```sh
V_BIN=~/code/v-gg/v python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/gg-clipped-text.lock --report Build/gg-clipped-text.json -- \
  sh tools/gg_migration/test_clipped_text.sh Build/gg-clipped-text 2000
```

Use a new output directory for each run. Set `GG_TEXT_TEST_PROD=1` for
`-prod -gc none`. This tests the native adapter directly; browser acceptance
requires a fresh GG-enabled bundle. With `VOX_GG_DIAGNOSTICS=1`, eligible native
text callbacks log `text device_clip=0|1 drawn=0|1`. Early native rejections,
fully hidden tiles, recordings and picture playback are outside those counts.

Text (LibWeb's Skia lives in `$LADYBIRD/Build/release/vcpkg_installed/arm64-osx-dynamic`):

```sh
clang++ -std=c++20 -O1 -fno-objc-arc -mmacosx-version-min=14.0 -I$VCPKG/include/skia \
  -I$VCPKG/include tools/gg_migration/skia_text_oracle.mm -L$VCPKG/lib -lskia \
  -Wl,-rpath,$VCPKG/lib -framework CoreText -framework CoreGraphics \
  -framework CoreFoundation -framework Foundation -o Build/gg-oracle/skia-text-oracle
python3 tools/gg_migration/gen_text_corpus.py --count 2000 > $OUT/script.txt
Build/gg-oracle/skia-text-oracle $OUT/script.txt $OUT
v -cc clang -o Build/gg-oracle/text-scene tools/gg_migration/text_scene.v
Build/gg-oracle/text-scene $OUT/script.txt $OUT
```

Browser A/B (a bundle built with `V_BIN` from the gg branch):

```sh
gg_font_root=Tests/Browser/Brave/sites/guardian/bodies
python3 tools/run_memory_bounded.py --timeout 7200 --lock Build/gg-ab.lock \
  --report Build/gg-ab-guard.json -- python3 tools/gg_migration/capture_ab.py \
  --bundle Build/v/Vox.app --inputs Tests/Browser/Brave/input --output $OUT \
  --resource "$gg_font_root/bf672dbc2fe3d05096cb045691ec7a9dc00e3470458665d42d0b7aabd07bb990" \
  --candidate-env VOX_GG_TEXT=1 --candidate-env VOX_GG_SHAPES=1 \
  --candidate-env VOX_GG_PATHS=1 --candidate-env VOX_GG_DIAGNOSTICS=1
```

Hacker News rendering and precise scrolling comparison:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py --timeout 1200 \
    --lock Build/hn-gg-perf.lock --report Build/hn-gg-perf-guard.json \
    --adopt-pids-from Build/hn-gg-perf-pids.json -- \
  python3 tools/gg_migration/benchmark_hacker_news.py \
    --output Build/hn-gg-perf --memory-guard-registry Build/hn-gg-perf-pids.json \
    --diff-tool PATH_TO_EXISTING_PIXEL_DIFF
```

Use a new output directory and a completed GG-capable canonical bundle. The
driver holds its publication lease, preserves all attempts and pins executable,
native libraries, helpers, runtime resources, fixtures and measurement tools.
It replays the complete 30-story homepage archive over loopback with original
scripts, fresh profiles/caches, retained OS caches, a 1024x768 viewport and 2x
backing scale. GG enables all three adapters; unsupported and unmigrated draws
still use Skia.

Seven alternating load pairs measure main-process instructions from process
creation through encoded PNG, excluding helpers and GPU work. Native first-layer
submission times include scripting, style/layout and native rendering. These
are different scopes from the total-browser coalition comparison against Brave.
Four alternating scroll pairs use 600 precise events at nominal 60 Hz, delta 3,
reversing every 60 inputs to avoid holding at the page boundary. Startup and
scroll eligibility logs, and one hardware-counter scroll per variant, run
separately from the unprofiled FPS trials. `--scroll-only` omits the timed load
pairs; `--reverse-every` records a different input schedule.

The native probe's optional `VOX_PRECISE_FINAL_CAPTURE` writes final pixels
after timing and counter endpoints. Every later scroll capture must match the
first Skia reference outside the existing RAM-readout rectangle. This snapshot
and its PNG encoding are outside the measured input window. Native layer
publication FPS does not measure physical display scanout. Inspect per-trial
input delivery, interval tails, deadline misses, leading/trailing gaps and host
load alongside averages; reaching 60 on average alone does not prove smoothness.
