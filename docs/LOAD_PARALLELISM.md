# Page-load CPU parallelism and leaf raster transfers

A user reported that Vox keeps one CPU busy while it renders a page. This
report measures that on Hacker News, GitHub and old Reddit, explains why the
load is serial, and records the one change made: leaf raster no longer moves a
whole compositor tile through the GPU for every small shape. The pipeline is
still single-threaded; the change removes main-thread work rather than moving
it to other cores.

## Measurement

`tools/measure_load_parallelism.py` launches a fresh browser with an empty
profile and cache against an offline archive (`tools/page_archive.py`) and
samples every thread's cumulative CPU time through libproc every 2 ms. The
interval runs from process launch to the completed document PNG at a 1024×768
viewport with JavaScriptCore. It includes startup, replayed fetches, scripts,
layout, raster and PNG encoding. Thread sums are polling lower bounds; the
process total comes from rusage. GPU execution and helper processes are not
counted. A capture paints the document once, after its resources are ready.

| Page | Archive | `manifest.json` SHA-256 |
| --- | --- | --- |
| `https://news.ycombinator.com/` | `Tests/Browser/Brave/hn-home-instructions` | `e1425162…63ce0` |
| `https://old.reddit.com/r/programming/` | local `reddit-recovery-20261116/candidate-archive` (frozen HTML, no scripts) | `313886b3…2b13` |
| `https://github.com/vlang/v` | local `libjs-github-primer-effects-9568` archive (hydrating scripts) | `69673187…b357` |

The Reddit and GitHub archives hold private page data and are not committed.
GitHub captures use a ready selector for the sponsor button and the commit
links of the directory rows; without it 2 of 30 captures finished before
hydration (128 and 139 of 157 requests) and showed a different page.

The host is an 18-core Apple M5 Max shared with other sessions' builds and
tests. Load averages were 6 to 9 during the baseline and 9 to 33 during the
matched cohorts, so absolute times differ between sections; each comparison
below alternates both variants on one executable.

## Baseline: one busy core

Production executable `ba77ba2b9fd1…`, capture scale 1, medians of five
trials. The GitHub row lists two trials: a concurrent build replaced the
bundle during its cohort, which the tool rejects.

| Page | Wall | Process CPU | Main thread | Other threads | Main-thread share | Wall with ≥2 busy threads |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hacker News | 555 ms | 324 ms | 249 ms | 76 ms | 76% | 5 ms |
| old Reddit | 757 ms | 338 ms | 257 ms | 81 ms | 76% | 5 ms |
| GitHub | 3091, 2440 ms | 2184, 2120 ms | 1757, 1723 ms | 427, 397 ms | 80%, 81% | 66, 79 ms |

The other threads are fetch workers and JavaScriptCore's compiler and
collector threads. Two threads are busy together for about 1% to 3% of a load.

One instrumented load per page (`VOX_DIAGNOSTIC_THREAD_LOAD_STAGES`) attributes
the main thread's instructions:

| Main-thread share | Hacker News | old Reddit | GitHub |
| --- | ---: | ---: | ---: |
| Startup, window and browser chrome | 33% | 32% | 7% |
| Raster replay of the display list | 30% | 15% | 10% |
| JavaScript and its bindings | 11% | 11% | 31% |
| Layout | 9% | 8% | 24% |
| Style | 9% | 17% | 18% |
| CSS parsing | 2% | 6% | 4% |
| Other, including PNG encoding | 7% | 11% | 6% |
| Main-thread instructions | 3.08 B | 3.15 B | 24.37 B |

## Why these stages stay on one thread

- DOM, CSSOM, computed style, layout and the display list are V objects in
  scoped arenas. `platform` arenas belong to one thread and panic on another.
  A spawned worker allocates in its own arena, which is either freed when the
  thread returns or kept for the process (`retain_thread_allocations`, used by
  fetch workers for their results). A worker therefore cannot hand style,
  layout or parsed rules to a document without leaking them or copying them
  on the main thread. Parallel style or layout needs arenas that a document
  owns and several threads can fill; that is an allocator design change.
- The stylesheet rule cache states the same constraint: only the origin
  thread may store or lease its retained arenas. Tokenizing and syntax parsing
  on fetch threads would move about a third of CSS parsing (1% to 2% of a
  load) and still convert rules on the main thread.
- Raster leaves draw through one Sokol/Metal context on the main thread and
  wait for each readback. Pixel loops inside them already use the scan workers
  above 256 K pixels; typical leaves are far smaller.
- JavaScriptCore already compiles and collects on its own threads.

## Leaf raster transfers

A leaf (an SVG path, a rounded shape or border, a CSS gradient) is drawn on a
GPU surface of its compositor tile's size so its samples match the tile. Each
leaf also cleared a tile-sized buffer, uploaded the whole tile as its backdrop
and read the whole tile back: 1.0 MB at scale 1 (1024×256 tiles) and 1.8 MB
at scale 2 (1056×416 tiles), for an icon of a few kilobytes. The commit
message's 2048×512, 4 MB example overstates the tile size on this display. In
a normal Retina window GitHub repaints about six times while it hydrates;
sampling those frames put 29% of main-thread time in display-list replay,
most of it in this path: GPU waits 11%, tile copies 8% and tile clears about
8%.

Commit `e39770061` uploads and reads back only the leaf's rows on the same
tile-sized surface. Every destination pixel blends with its own backdrop
pixel, so the published rows are unchanged. Glyph-coverage groups and filter
layers keep whole-tile transfers, as does any leaf the region path declines.
`VOX_GG_FULL_TILE_TRANSFERS=1` restores the previous transfers; it is the
control below, on executable `5ca3ed99fb8d…`.

### Checks

- `ggshape/leaf_region_darwin_test.v`: 5 cases, 1,026 assertions. Region draws
  of shapes, shape groups, paths, strokes, SVG images and dithered gradients,
  with and without backdrop and MSAA, equal the same rows of whole-tile draws;
  row padding is untouched and unsupported regions leave pixels unchanged.
- Nine existing Metal pixel tests in `ggshape` (shapes, SVG batches, mask
  paths, gradients, non-scaling strokes, contoured and clipped rectangles)
  pass unchanged.
- The whole-browser type check passes.
- All 84 captures of the matched cohorts (three pages, scales 1 and 2, seven
  pairs each) are byte-identical between control and candidate.

### Main-thread instructions of paint leaves, one raster frame

One instrumented pair per page and scale; both captures of each pair are
byte-identical and replay the same leaves.

| Page | Scale | Control | Candidate | Change | Largest leaf kinds, control → candidate |
| --- | ---: | ---: | ---: | ---: | --- |
| Hacker News | 2 | 775 M | 299 M | −61% | fill 535 → 81 M |
| Hacker News | 1 | 794 M | 220 M | −72% | fill 348 → 72 M, SVG 301 → 17 M |
| old Reddit | 2 | 710 M | 363 M | −49% | fill 175 → 8 M, SVG 119 → 4 M, border 120 → 55 M |
| old Reddit | 1 | 411 M | 292 M | −29% | fill 67 → 5 M, SVG 36 → 2 M |
| GitHub | 2 | 3,368 M | 950 M | −72% | SVG 1,785 → 66 M, border 561 → 48 M, shadow 310 → 168 M |
| GitHub | 1 | 1,920 M | 780 M | −59% | SVG 886 → 53 M, border 277 → 23 M |

Text leaves (127 to 445 M) and filter leaves are unchanged. Whole-load
main-thread instructions fell 18% and 19% on Hacker News (3,063 → 2,511 M at
scale 2 and 2,990 → 2,424 M at scale 1) and 11% and 4% on old Reddit. GitHub's whole-load
totals vary by several billion between runs with the number of layout passes,
so only its leaf scopes are compared.

### Launch to completed capture

Seven alternating pairs per page and scale, medians, every trial retained.

| Page | Scale | Main-thread CPU, control → candidate | Wall, control → candidate | Host load average |
| --- | ---: | ---: | ---: | ---: |
| Hacker News | 2 | 360 → 322 ms (−10.8%) | 788 → 739 ms (−6.1%) | 15–16 |
| Hacker News | 1 | 414 → 366 ms (−11.6%) | 1096 → 1028 ms (−6.2%) | 24–30 |
| old Reddit | 2 | 331 → 323 ms (−2.5%) | 944 → 931 ms (−1.4%) | 12–15 |
| old Reddit | 1 | 448 → 409 ms (−8.6%) | 1218 → 1143 ms (−6.2%) | 30–33 |
| GitHub | 2 | 3046 → 2967 ms (−2.6%) | 5070 → 4991 ms (−1.6%) | 9–12 |
| GitHub | 1 | 2633 → 2732 ms (+3.8%) | 4326 → 4519 ms (+4.5%) | 19–32 |

Hacker News' ranges do not overlap at scale 1 (359–387 ms against
404–431 ms) and overlap at scale 2. The old Reddit and GitHub ranges overlap:
a capture rasters the page once, their loads are dominated by other work, and
the host was heavily loaded. GitHub at scale 1
spans 2,217 to 3,607 ms within each variant; its +3.8% is not a measured
regression, and the −2.6% at scale 2 is not established either. The main
thread's share of process CPU stays at 71% to 84%.

### Frames in a normal Retina window

Three alternating rounds per page in an ordinary window at device scale 2,
without capture gating, reading each rendered frame's cost from
`VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS` (frame start to end on the main
thread, including document installation in the first frame).

| Page | First frame, control → candidate | Later frames | Last frame ends after first paint |
| --- | ---: | ---: | ---: |
| GitHub | 1039 → 920 ms | 470 → 336 ms (15 and 16 frames, −28%) | 5635 → 5097 ms |
| Hacker News | 200 → 165 ms | 100 → 58 ms | 701 → 617 ms |
| old Reddit | 315 → 281 ms | 59 → 37 ms | 620 → 576 ms |

Three rounds on a loaded host do not support a precise percentage. Every
candidate first frame is below every control first frame on GitHub and old
Reddit, and GitHub's hydration frames cost 239–402 ms against 393–583 ms.

### Commands

```sh
sh tools/run_v_tool.sh run_memory_bounded --lock Build/JOB.lock \
  --report Build/JOB-guard.json --limit-gib 8 -- \
  python3 tools/measure_load_parallelism.py --archive ARCHIVE \
    --output Build/JOB --repeat 7 --screenshot-scale 2 \
    --control-env VOX_GG_FULL_TILE_TRANSFERS=1
```

The instrumented pairs add `--repeat 1 --env VOX_DIAGNOSTIC_LOAD_STAGES=1
--env VOX_DIAGNOSTIC_THREAD_LOAD_STAGES=1 --env VOX_PROFILE_INSTRUCTIONS=1`
and are reduced with `tools/summarize_thread_load_stages.py`. Every browser
and guard exit of the cohorts, instrumented pairs, normal-window rounds,
focused tests and the type check is zero; sampled peak process-tree RSS stays
under 2.5 GiB for page loads and 5.6 GiB for the type check. Raw logs,
timelines and captures were local job output and are deleted.

## Not changed

- Each GPU leaf still creates tile-sized textures and blocks the main thread
  for one GPU round trip (about 0.5 ms). Batching leaves of one tile into one
  pass, or continuing CPU replay while the GPU renders, would remove most of
  the remaining leaf cost and needs overlap tracking between leaves.
- After a document's first frame, the load-frame throttle defers the next
  frame by three times that frame's cost, up to 500 ms. The first frame
  includes document installation, so on Hacker News and old Reddit the main
  thread is idle for most of the 0.45 to 0.6 s before the second frame paints
  the images that arrived in the meantime. The policy protects script time on hydrating pages and
  was left as it is.
- Layout costs about three times more instructions at capture scale 2 than at
  scale 1 on GitHub (`flow_layout` 3.3 B in 21 passes against 8.5 to 11.3 B
  in 20 to 22). The cause was not investigated.
- The first navigation of a launch starts after the first window frame, by an
  earlier measured decision; the fetch does not overlap AppKit startup.
