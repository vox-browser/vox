# Page-load CPU parallelism and leaf raster transfers

A user reported that Vox keeps one CPU busy while it renders a page. This
report measures that on Hacker News, GitHub and old Reddit, explains why the
load is serial, and records the changes made. Leaf raster no longer moves a
whole compositor tile through the GPU for every small shape. Three follow-up
fixes remove a wait and repeated work that the first measurements exposed: a
deferred loading frame renders once the page is quiet, layout keeps its boxes
and inline layout on Retina displays, and identical leaf draws are not
repeated. The pipeline is still single-threaded; the changes remove
main-thread work and idle waiting rather than moving work to other cores.

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

The bundle published from the committed tree (`67f4a238a1ba…`, head
`1aa004a52`) repeated three alternating pairs per page at scale 2 at load
averages of 10 to 13. Main-thread CPU was 243, 244 and 247 ms
against 269, 269 and 272 ms on Hacker News, 286, 287 and 287 ms against 295,
303 and 303 ms on old Reddit, and 3249, 3327 and 3512 ms against 3333, 3755
and 4141 ms on GitHub, again with byte-identical captures and zero exits.

### Frames in a normal Retina window

Three alternating rounds per page in an ordinary window at device scale 2,
without capture gating, reading each rendered frame's cost from
`VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS` (frame start to end on the main
thread, including document installation in the first frame).

| Page | First frame, control → candidate | Later frames | Last frame ends after first paint |
| --- | ---: | ---: | ---: |
| GitHub | 1039 → 920 ms | 470 → 336 ms (15 and 16 frames, −28%) | 5577 → 5010 ms |
| Hacker News | 200 → 165 ms | 100 → 58 ms | 601 → 559 ms |
| old Reddit | 315 → 281 ms | 59 → 37 ms | 562 → 539 ms |

An earlier revision of this table listed the last frame's end plus its cost
(5635 → 5097, 701 → 617 and 620 → 576 ms). Three rounds on a loaded host do
not support a precise percentage. Every
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

## Follow-up fixes

Each fix has an environment switch that restores the previous behavior, so
every comparison below alternates control and candidate on one executable.
`tools/measure_load_frames.py` runs the normal-window rounds: it opens the
archive in an ordinary window at device scale 2 and reads each rendered frame
of 20 ms or more from `VOX_LOAD_RENDER_THROTTLE_DIAGNOSTICS`.

### A deferred loading frame renders once the page is quiet

After a document's first frame the load-frame throttle holds the next frame
for three times the last frame's cost, up to 500 ms, to protect script time on
hydrating pages. The first frame includes document installation, so Hacker
News and old Reddit sat idle for most of 0.45 to 0.6 s before painting the
images that had arrived. Commit `3902effd8` releases a deferred frame once the
main thread has used at most a fifth of a 50 ms window and no fetch is in
flight (`VOX_LOAD_RENDER_QUIET_MS`; control
`VOX_DISABLE_LOAD_RENDER_QUIET_RELEASE=1`). A hydrating page keeps its
deferral while scripts run or resources load.

| Page | Second frame ends after first paint, control → candidate |
| --- | ---: |
| Hacker News | 363, 437 → 100, 100 ms |
| old Reddit | 530, 526 → 97, 93 ms |

GitHub's last loading frame ended 4773 and 4897 ms after first paint against
4323 and 3513 ms, with three or four early releases and the same number of
frames. Five alternating capture pairs per page at scale 2 kept identical
pixels and main-thread CPU (256 → 256 ms on Hacker News, 295 → 295 ms on old
Reddit); wall time from launch to capture fell 591 → 527 ms, 861 → 530 ms and
4737 → 3697 ms on GitHub.

### Layout keeps its work on Retina displays

Layout cost about three times as many instructions at scale 2 as at scale 1
on GitHub. At scale 2 a box holds the projection of its element's CSS-pixel
style into physical coordinates, and two checks treated every projection as
changed (commit `1af37f85c`):

- `has_identical_retained_layout_inputs()` rejected every style at a layout
  scale other than 1, so each no-op restyle rebuilt its boxes: 8,626 to
  10,544 clean elements were rebuilt per load against 282 to 469 at scale 1.
  It now projects the replacement and compares in physical coordinates,
  which leaves 402 (control `VOX_DISABLE_DEVICE_LAYOUT_STYLE_REUSE=1`).
- A projected font list carried none of the font computer's stamps, so text
  shaped with it never counted as current and no inline layout was reused
  between passes. A projection now reads the stamps of the cascade it scales
  (control `VOX_DISABLE_DEVICE_LAYOUT_FONT_STAMPS=1`).

One instrumented GitHub pair per step at capture scale 2 (executables
`432e5f7edf08…` and `c93e43a7e58c…`), with byte-identical captures. The
middle column holds both pairs' values:

| Main thread | Both off | Style comparison | Both |
| --- | ---: | ---: | ---: |
| `flow_layout` instructions | 11.28 B | 9.23, 9.20 B | 3.07 B |
| Layout tree construction, instructions | 1.44 B | 0.88, 0.91 B | 0.78 B |
| Inline layouts reused in their pass | 0 | 0 | 10,075 |
| Inline layouts restored from an earlier pass | 0 | 0 | 657 |
| Inline layouts laid out for the first time | 50,881 | 51,060 | 4,294 |
| Whole load, instructions | 33.8 B | 31.1, 30.8 B | 23.6 B |

Scale 1 measures 3.3 B in `flow_layout` and 10,801, 817 and 4,294 inline
layouts. Unprofiled GitHub cohorts with both switches as control, captures on
`c93e43a7e58c…` and the normal window on `830d0151f7c0…`, which a concurrent
build published from the same tree; the round it interrupted was rejected and
repeated:

| GitHub at scale 2 | Control | Candidate |
| --- | ---: | ---: |
| Capture, main-thread CPU (five pairs) | 3144 ms (2812–3402) | 2259 ms (2208–2548) |
| Capture, launch to PNG | 3814 ms | 2899 ms |
| Normal window, first frame (three rounds) | 894, 955, 1023 ms | 796, 776, 813 ms |
| Normal window, later frames, median | 267 ms | 176 ms |
| Normal window, last frame ends after first paint | 3238, 3047, 3297 ms | 2090, 2216, 2337 ms |
| Normal window, main-thread CPU in 9 s | 3696, 3549, 3872 ms | 2520, 2630, 2815 ms |

Captures of 17 archived pages (GitHub, old Reddit and the 15 pages under
`Tests/Browser/Brave/sites`) are byte-identical with and without the two
switches at scale 1, the scale of the Brave references. At scale 2 they are
byte-identical except The Verge, where 725 pixels change in the seven "/"
separators of its navigation row. Before, once an unrelated face had loaded,
a box computed a new cascade for its physical font size instead of keeping
the faces scaled from its CSS-size cascade; the unit test reproduces this.
The separators were thinner and shifted. They now have the ink of the scale
1 render (21,687 to 21,701 against 4 × 5,424; 20,748 to 20,756 before) and
its centroids within 0.25 device pixels (up to 0.92 before). The neighbouring
words are identical in both renders. The repository has no Brave reference
for this page at scale 2.

`css/device_layout_retained_style_test.v` (7 cases) covers no-op restyles,
changed lengths, flags and context, pending faces, another scale, the
unchanged CSS-pixel comparison and both font cases; the two font cases fail
with the stamp switch set. Layout-module tests, modified or not, do not
compile within the 12 GiB guard at present, so the layout side is covered by
these whole-browser comparisons.

### Identical leaf draws are not repeated

GitHub repaints the same icons, borders and gradients in each of its loading
frames, and every draw blocked the main thread for a GPU round trip. Commit
`d40a69411` keys a region draw by all of its inputs (kind, flags, surface and
region, backdrop rows, and the descriptors with the data their pointers
address) and copies the rows of an identical earlier draw. The cache holds
at most 32 MB in entries of up to 512 KB (control
`VOX_DISABLE_LEAF_RASTER_CACHE=1`).

GitHub in a normal window on `432e5f7edf08…`, three alternating rounds:
later frames cost 310 → 209 ms (median), the last one ends 3143, 3377, 3355
→ 2542, 2751, 2796 ms after first paint, and the first frame is unchanged
(828, 870, 871 against 868, 868, 881 ms): its leaves are all new. One load
has 570 hits and 198 misses and keeps 4.8 MB. Captures of the 17 pages at
scales 1 and 2 are byte-identical with and without the cache.
`ggshape/leaf_region_darwin_test.v` gained three cases: repeated draws,
changed segment data at a reused address, and shape groups against
whole-tile draws.

### All three together

Executable `c93e43a7e58c…` with the four switches as control, at load
averages of 9 to 14. Captures at scale 2, five alternating pairs per page,
byte-identical:

| Page | Launch to PNG, control → candidate | Main-thread CPU, control → candidate |
| --- | ---: | ---: |
| Hacker News | 642 → 580 ms | 274 → 296 ms (249–307 against 248–299) |
| old Reddit | 874 → 514 ms | 295 → 285 ms |
| GitHub | 5158 → 3005 ms | 3072 → 2339 ms (2783–3215 against 2175–2420) |

Normal window, three alternating rounds per page:

| Page | Control | Candidate |
| --- | ---: | ---: |
| Hacker News, second frame ends after first paint | 457, 541, 494 ms | 82, 87, 91 ms |
| Hacker News, second frame cost (median) | 61 ms | 36 ms |
| old Reddit, second frame | ends 526, 529, 527 ms; costs 25 ms | under the 20 ms the diagnostics list |
| GitHub, first frame | 870, 855, 1081 ms | 850, 698, 1038 ms |
| GitHub, second frame ends after first paint | 790, 779, 880 ms | 388, 361, 458 ms |
| GitHub, last frame ends after first paint | 4768, 4583, 5667 ms | 2312, 2094, 2864 ms |
| GitHub, later frames, median cost | 333 ms | 159 ms |
| GitHub, main-thread CPU in 9 s | 3289, 3050, 4260 ms | 2853, 2450, 3484 ms |

The small pages gain wall time, not CPU: their main thread was idle while it
waited. GitHub's main-thread CPU ranges do not overlap in the captures.
Every browser and guard exit is zero.

The bundle published after the commits (`917504deb379…`, head `e32a9a894`)
passes the headless smoke and repeated three alternating capture pairs at
scale 2 with byte-identical pixels, at a load average of 9 to 11: launch to
PNG 626, 638, 647 → 537, 548, 573 ms on Hacker News and 5652, 6144, 6253 →
3454, 3682, 3826 ms on GitHub, whose main-thread CPU was 3510, 4090, 4110 →
2743, 2965, 3075 ms.

### Captures before hydration

The GitHub captures that preceded hydration came from this benchmark, which
captures as soon as the page reports ready with no settle period.
`tools/measure_load_parallelism.py` takes `--ready-selector` and
`--settle-seconds` and lists the replayed request count of every variant, so
an early capture is visible. The selector is sufficient at scale 2. At scale
1 two of four captures still replayed 155 of 157 requests; with
`--settle-seconds 1.5` all six of three pairs are identical.

## Not changed

- The first time a leaf is drawn it still creates tile-sized textures and
  blocks the main thread for one GPU round trip (about 0.5 ms; about 200
  draws in a GitHub load). Batching the leaves of one tile into one pass, or
  continuing CPU replay while the GPU renders, needs overlap tracking between
  leaves.
- Glyph-coverage groups and filter layers still upload and read back whole
  tiles.
- When a box's own cascade expires while the box is retained at scale 2,
  `computed_font_list()` still computes a cascade for the physical font size
  until the element is restyled. The sweeps above did not show it.
- The first navigation of a launch starts after the first window frame, by an
  earlier measured decision; the fetch does not overlap AppKit startup.
- The message of commit `e39770061` gives a 2048×512, 4 MB tile as its
  example. The tiles on this display are those listed under leaf raster
  transfers; shared history is not rewritten for it.
