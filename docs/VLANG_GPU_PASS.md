# One GPU pass per damaged region: feasibility (2026-11-04)

Branch `vlang-gpu-pass` (worktree `~/code/vox2-gpu`) investigates replacing
per-leaf GPU readback with one GPU pass per damaged region on vlang.io. Evidence
is under `~/code/vox2/Build/vlang-fps-20261104` (`sample120*`, `hz120-*`,
`shadow-target-exp/`).

## What a frame costs

At the usual 60 Hz input, vlang.io already publishes 53–57 scroll FPS; most
frames finish well inside 16.7 ms. With 1200 delta-1 inputs requested at
120 Hz, actual input delivery falls to 69–73 Hz and scroll FPS is 55.7–62.1
(median interval 14.2–16.3 ms): the main thread is saturated.

A 6 s sample of that 120 Hz run (623 main-thread samples, diagnostic only):

| Work | Samples | Share |
| --- | ---: | ---: |
| Leaf replay (`draw_command`) | 331 | 53% |
| — waiting for GPU readbacks (`__psynch_cvwait`) | 155 | 25% |
| Ring rows copied into the canvas (`native_scroll_raster_copy_rows`) | 44 | 7% |
| Wheel handling | 46 | 7% |
| Navigation UI service | 26 | 4% |

GPU waits are spread over at least six paths: layer shape regions (37), layer
shadow regions (33), root shape batches (18), gradient path regions (16),
rounded parts (15) and layer MSAA shapes (15).

Standalone measurements against the installed `libVoxGraphite.dylib`:

- One region shadow draw costs 0.4–0.6 ms of fixed round trip on small targets
  and 2.6 ms on a 2400x1360 target; reusing that target instead of allocating
  it each time gives 1.3 ms with byte-identical output.
- Clipping a shadow draw to the requested rows (keeping the target) is not
  exact: 6,980 of 34.4 M bytes differ.
- Cropping the target itself changes blur pixels (57 of 72 crops match).

## Expected gain

Removing nearly all GPU waits saves about a fifth of main-thread time at
120 Hz input: roughly 60 → 75 FPS there, and about +1 FPS on the 60 Hz test,
where frames are already mostly within budget. Removing the per-frame ring
copy and part of wheel handling could add another ~10%. Doubling is not
expected from GPU batching alone.

## Why an exact single pass is hard

- Root leaves blend over the page backdrop on the GPU, then their pixels are
  copied back under the CoreGraphics clip that is active for that command.
  Keeping a tile on the GPU across leaves is exact only while every clip is a
  rectangle equal to the view and no CPU drawing intervenes.
- Composited-layer leaves (every vlang.io shadow) render on a transparent
  target and are blended onto the canvas by CoreGraphics. Blending them on the
  GPU instead changes rounding.
- Text and solid rectangles are drawn by CoreGraphics on the CPU between GPU
  leaves, so a GPU-resident canvas needs a readback and upload around each
  run of CPU drawing.
- Earlier picture-based attempts (`docs/VLANG_SCROLLING.md`, "Root-picture
  bounds") regressed because the recording bridge and GPU backends are
  separate Skia builds and every picture is serialized and deserialized.

## Change on this branch

`native_graphite_darwin.mm` keeps reusable region targets up to 64 MiB instead
of 4 MiB, so large layer-shadow targets are reused when their dimensions
repeat (byte-identical; 2.6 → 1.3 ms per isolated draw). On vlang.io most
large shadows straddle the viewport edge, so their target dimensions change
while scrolling and reuse rarely hits; no FPS gain has been measured.

## Prototype: GPU-resident canvas (2026-11-04, night)

`VOX_EXPERIMENT_GPU_CANVAS=1` implements the single pass for reused scroll
frames. The repainted device rectangles (exposed strip and content damage)
live on shared-storage Graphite surfaces aligned to the 8-pixel dither grid.
The V draw loop asks the native bridge whether each command can draw there
(`native_gpu_canvas_command`); approved commands draw box shadows, rounded
fills and borders, device-aligned solid rectangles, SVG paths, gradient paths
and text with device matrices and the destination's mirrored rounded clips.
Text is rasterized by the bridge on a transparent CPU target and composited
on the canvas, as Chromium uploads CPU glyph masks. Any other command, and any
offscreen effect/filter layer entering or leaving, first reads every rectangle
back with one GPU wait; the next GPU leaf uploads the CPU pixels again.

Parity guards keep the per-leaf path where the canvas cannot match it yet:
fractional solid rectangles (Quartz's antialiasing state is not observable)
and root rounded shapes overlapping a Chromium MSAA tile.
`VOX_GPU_CANVAS_VERIFY=2` draws every canvas leaf both ways and compares each
leaf by itself. With the guards, 836,821 of 61,187,656 compared pixels (1.37%)
differ, by at most 3 levels per channel: blending rounding between the GPU and
Quartz, not geometry. Without the guards the progress bars differed by up to
48 and MSAA-tile shapes by up to 61.

During input a median frame draws 5–8 leaves on the canvas with 2–4 GPU waits
(previously one wait per GPU leaf). Remaining waits come from raster-layer
text scrolling and offscreen effect layers, images, gradient text, CSS filters
and inset shadows.

Same worktree executable `e8c021b3…`, same injected bridge and Graphite
libraries in both arms; the candidate only sets the variable. Live vlang.io,
the `rQ` protocol (or 1200 delta-1 inputs at 120 Hz), host load in the table:

| Run | Scroll FPS | Input delivery | Median / p95 / max interval | Inputs / scroll intervals | Load |
| --- | ---: | ---: | --- | --- | ---: |
| 120 Hz control-1 | 79.9 | 87.5 Hz | 11.5 / 21.0 / 42.0 ms | 1200 / 1094 | 39.1 |
| 120 Hz candidate-1 | 94.1 | 96.1 Hz | 9.7 / 17.8 / 33.1 ms | 1200 / 1174 | 40.4 |
| 120 Hz control-2 | 79.1 | 91.0 Hz | 11.6 / 20.8 / 44.5 ms | 1200 / 1042 | 40.3 |
| 120 Hz candidate-2 | 94.5 | 95.5 Hz | 9.7 / 17.2 / 32.5 ms | 1200 / 1186 | 37.5 |
| 60b Hz control-1 | 56.8 | 59.1 Hz | 16.6 / 31.6 / 51.9 ms | 600 / 576 | 38.4 |
| 60b Hz candidate-1 | 59.3 | 59.6 Hz | 16.7 / 22.8 / 42.4 ms | 600 / 596 | 41.1 |
| 60b Hz control-2 | 56.9 | 59.4 Hz | 16.7 / 28.0 / 52.6 ms | 600 / 574 | 38.4 |
| 60b Hz candidate-2 | 59.1 | 59.6 Hz | 16.6 / 23.1 / 46.5 ms | 600 / 594 | 38.1 |
All runs and guards exited 0 with fixed identities. At 120 Hz the canvas
raises throughput by 15 FPS in both pairs and keeps up with more of the
requested input; at 60 Hz it delivers a frame for 594–596 of 600 inputs versus
574–576. An earlier cohort without the parity guards measured 102.0/87.9
versus 80.2/77.6 FPS at 120 Hz and 59.5/59.3 versus 57.1/56.7 at 60 Hz; its
second candidate included one 974 ms frame that a diagnostic rerun did not
reproduce.

Not done yet: complete repaints still use per-leaf rendering (retained ring
pixels and canvas strips can differ by the rounding above), images, inset
shadows, filters and gradient text still read back, Chromium per-tile MSAA is
not emulated, and no screenshot or broad regression suite has run on this
branch.
