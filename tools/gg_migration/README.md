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
- `fma_audit.py` fails if clang fuses multiply-adds in `canvas__*` functions;
  Skia is compiled with `-ffp-contract=off`.
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
- `metal_trace_inject.mm` builds `libvox_metal_trace.dylib`, which records the
  Metal work of any process started with `DYLD_INSERT_LIBRARIES` into
  `$VOX_METAL_TRACE_DIR` (used to inventory the pipelines of the Brave fixtures).
- `capture_ab.py` captures every Brave fixture with one Vox bundle, alternating
  a plain launch and one with extra environment (`VOX_GG_TEXT=1` lets
  `gg.canvas` draw the bridge's CPU glyph runs, `VOX_GG_SHAPES=1` its Graphite
  shape descriptors). It compares decoded pixels
  outside the status bar's live RAM readout, captures the control again when
  they differ, and classifies each fixture as `equal`, `equal_to_repeat`,
  `different`, `unstable` or `failed`. `--recompare` rebuilds the summary
  from existing captures.
  Each run needs a new output directory. The runner pins the executable, native
  libraries, input fixtures, assets and resources before every launch, verifies
  adapter registration, retains partial results and actual exits, and exits
  nonzero on rendering differences, unstable/failed captures or changed inputs.
  `--fixture-list FILE` selects one fixture stem per line for a historical cohort.

The adapters on master require `-d vox_gg_canvas` and a V compiler containing
`gg.canvas`. `build-prod-browser.sh` detects that module in the selected compiler
and supplies the flag; normal V builds keep the original renderer. Renderer
selection remains opt-in at runtime (`VOX_GG_TEXT`, `VOX_GG_SHAPES`, `VOX_GG_PATHS`).
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
python3 tools/run_memory_bounded.py --timeout 7200 --lock Build/gg-ab.lock \
  --report Build/gg-ab-guard.json -- python3 tools/gg_migration/capture_ab.py \
  --bundle Build/v/Vox.app --inputs Tests/Browser/Brave/input --output $OUT \
  --candidate-env VOX_GG_TEXT=1 --candidate-env VOX_GG_SHAPES=1 \
  --candidate-env VOX_GG_PATHS=1 --candidate-env VOX_GG_DIAGNOSTICS=1
```
