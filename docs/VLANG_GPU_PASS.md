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
