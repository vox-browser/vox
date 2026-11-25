# Page-load CPU parallelism and leaf raster transfers

A user reported that Vox keeps one CPU busy while it renders a page. This
report measures that on Hacker News, GitHub and old Reddit, explains why the
load is serial, and records the changes made. Leaf raster no longer moves a
whole compositor tile through the GPU for every small shape. Three follow-up
fixes remove a wait and repeated work that the first measurements exposed: a
deferred loading frame renders once the page is quiet, layout keeps its boxes
and inline layout on Retina displays, and identical leaf draws are not
repeated. A comparison with Brave follows: after two more waits were removed,
Hacker News and old Reddit load faster in Vox, and GitHub still takes more
than twice as long. Those changes remove main-thread work and idle waiting.
The later [glyph mask benchmark](#parallel-glyph-masks-on-hacker-news) measures
work dispatched to CPU workers during retained text rasterization.

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

## Against Brave

`tools/measure_load_against_brave.py` launches Vox and Brave 157.1.99.57
(Chrome/157.0.8103.79) alternately against the same archive: an empty
profile, a normal window with a 1024×768 document viewport at device scale 2
and the URL on the command line, timed from process launch to the completed
capture. Brave's window height is calibrated so that no viewport emulation is
needed, and every trial checks its viewport and capture size. Brave's
interval ends when `Page.captureScreenshot` returns after the load event,
`document.fonts.ready` and, on GitHub, the same ready selector; 96 to 150 ms
of it lie between readiness and the delivered PNG. Vox's interval ends when
its `--screenshot` PNG is complete and includes its capture raster and
encoding. The two captures of each page show the same content; the browsers'
readiness rules are their own. Each applies its own content blocking and
makes its own requests: Brave sends 18, 33 and 172, of which 12, 14 and 13
are outside the archive and rejected by the replay, against 7, 18 and 157 in
Vox with 1, 0 and 3 rejected. Brave's CPU is the sum over its process tree
at capture, a lower bound like Vox's process total.

Seven alternating pairs per page, medians with ranges:

| Page | Vox | Brave | Rounds Vox faster | Vox CPU | Brave CPU | Host load |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hacker News, before | 549 ms (518–562) | 533 ms (512–544) | 1 of 7 | 382 ms | 1149 ms | 10–11 |
| Hacker News, after | 469 ms (417–526) | 548 ms (500–565) | 7 of 7 | 391 ms | 1186 ms | 10–11 |
| Hacker News, after, loaded host | 646 ms (576–1114) | 849 ms (688–963) | 6 of 7 | 506 ms | 1598 ms | 37–43 |
| old Reddit, before | 606 ms (564–627) | 643 ms (583–677) | 7 of 7 | 495 ms | 1357 ms | 12–14 |
| old Reddit, after | 493 ms (446–502) | 563 ms (538–592) | 7 of 7 | 438 ms | 1195 ms | 10 |
| old Reddit, after, loaded host | 636 ms (571–913) | 807 ms (736–942) | 7 of 7 | 575 ms | 1644 ms | 37–40 |
| GitHub, before | 3329 ms (3178–3686) | 1426 ms (1185–1902) | 0 of 7 | 3336 ms | 3061 ms | 13 |
| GitHub, after | 3586 ms (3167–4163) | 1647 ms (1423–1757) | 0 of 7 | 3728 ms | 3555 ms | 15–16 |
| GitHub, after, loaded host | 3970 ms (3748–4442) | 1612 ms (1518–1871) | 0 of 7 | 4088 ms | 3583 ms | 37–43 |

"Before" is executable `2f77a736ea15…`. "After" has the two changes below:
`1141e476308d…` for Hacker News and old Reddit, `07b5829ff9ff…` for GitHub
with the dropped prefetch switched off, and `e895f0ee5b9e…`, built from the
committed tree, for the rows on a host at more than twice its core count in
load. Vox is faster than Brave on Hacker News and old Reddit in the medians
and in 27 of 28 rounds after the changes; its slowest launch beats Brave's
fastest only in the quieter old Reddit cohort. GitHub is 2.2 to 2.5 times
slower than Brave before and after: the two changes improve it by a few
hundred milliseconds in same-executable comparisons, which the host load
between these cohorts hides.

### Waits removed

An instrumented Hacker News load showed where a small page waited: the first
fetch was held until the first window frame (about 200 ms), and each frame
released by the quiet rule waited 50 ms, twice per load.

- `d4a7c2c60` shortens the quiet window of the load-frame throttle from 50 ms
  to 8 ms. Control `VOX_LOAD_RENDER_QUIET_MS=50`, four alternating capture
  pairs with identical pixels: Hacker News 474 → 406 ms, old Reddit 499 →
  477 ms, GitHub 3827 → 3472 ms (3108 → 2863 ms with 16 ms). GitHub in a
  normal window keeps its five later frames; the last one ends 2162–2433 →
  1827–2223 ms after first paint.
- `c0766d9cf` starts the first fetch of a launch when the navigation is
  requested instead of after the first window frame. Control
  `VOX_DEFER_INITIAL_NAVIGATION_FETCH=1`, four pairs, identical pixels:
  Hacker News 504 → 472 ms, old Reddit 568 → 529 ms, GitHub 2414 → 2393 ms.
  The document request reaches the replay about 60 ms after launch instead
  of about 220 ms. Against the live news.ycombinator.com in four alternating
  rounds the first window frame moves from 151–156 ms to 157–196 ms and the
  completed capture from 2797–3039 ms to 2704–2831 ms.

With the shorter window some GitHub captures, of both variants of a pair,
differ from the settled capture in the Sponsor icon and the branch button
(132 pixels in the pair examined), which is consistent with a transition
that is still running. Use `--settle-seconds` for pixel comparisons of that
page.

### Why GitHub stays behind

Both browsers spend about the same CPU on the GitHub load, 3.3 to 4.1 s in
Vox's process against 3.1 to 3.6 s in Brave's process tree. Brave spreads
it over its processes and finishes in 1.4 to 1.6 s. Vox's main thread is
busy for about four fifths of its load. One instrumented load (3.6 s with
stage logging) divides the main thread's wall time as follows:

| Main thread | Wall |
| --- | ---: |
| JavaScript execution and bindings | 750 ms |
| Layout (22 passes; the first, with its style pass, 404 ms) | 830 ms |
| Startup and waiting | 590 ms |
| Two full rasters and paint recording | 440 ms |
| Style | 370 ms |
| JavaScriptCore module parsing | 250 ms |
| CSS parsing | 100 ms |

JavaScript and startup alone take about as long as Brave's whole load, so
no amount of style, layout or raster tuning closes the gap on one thread.
Raster blocks scripts as well: the first full raster and its frame hold the
main thread for 470 ms, and the page sends its last requests right after.
Matching Brave here needs work on other cores (raster off the main thread,
which needs its own GPU context; script compilation; stylesheet parsing,
which the arena ownership rule above prevents today) together with
incremental style and layout.

One experiment was measured and dropped. Vox requests GitHub's 73 module
scripts about 600 ms after the document arrives, when its first layout is
done, where Brave requests them 250 ms after. Fetching them on resource
workers as soon as the markup arrives moved their median request from 1100
to 450 ms after launch with no additional request, since the module loader
reuses public immutable responses from the disk cache. Launch to capture did
not change: 3355 → 3422 ms in five alternating replay pairs and 6851 →
6757 ms (5911–7619 against 5901–6902) against the live page. The replay
serves a module in a few milliseconds and the main thread is busy either
way, so the code was not kept.

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
- GitHub loads 2.2 to 2.5 times slower than in Brave; see above for what
  closing that gap needs.
- In the cohorts above, the response of a launch's first fetch waited 100 to
  130 ms for the first window frame before Vox requested its stylesheets. The
  [follow-up](#initial-stylesheet-fetches-on-old-reddit) overlaps eligible
  stylesheet requests with window setup.
- Capture mode waits about 25 ms for a retry timer before its final raster.
- The message of commit `e39770061` gives a 2048×512, 4 MB tile as its
  example. The tiles on this display are those listed under leaf raster
  transfers; shared history is not rewritten for it.

## Initial stylesheet fetches on old Reddit

Vox now starts the first navigation's stylesheet batch on the response worker
when the HTML qualifies for tokenized discovery. The window opens while the
requests run. The navigation owns one cancellation scope from the main resource
through stylesheet adoption, and the usual stylesheet completion barrier
still precedes document installation. Tokenized discovery accepts a base
that repeats the response URL and an already-selected UTF-8 declaration.

We measured a fresh native window at 1024×768 CSS pixels and scale 2 on an
18-core Apple M5 Max running macOS 27.2. The URL was
`https://old.reddit.com/r/programming/` from the same sealed private archive
described above. The frozen page has no author scripts. JavaScriptCore and
normal content blocking were enabled in Vox. Every trial used a new process,
profile and HTTP cache. The offline replay rejected unarchived requests.
OS and GPU caches were left in their normal shared state.

The interval starts at process launch and ends at the completed document PNG.
Vox reports its written PNG after capture readiness. Brave returns its PNG via
CDP after the load event, font readiness and the shared post selector, with no
added settle time. The goal was 20% lower median elapsed time. The ratio of the
slowest Vox result to the fastest Brave result is also reported.

The published baseline (`8b66b96b8324…`, single-unit C with V `-prod`)
rendered all seven rounds ahead of Brave 157.1.99.57 (Chromium 157.0.8103.79).
Medians were 373.81 ms and 439.13 ms, with 14.88% lower time in Vox.
Vox ranged from 357.44 to 420.34 ms. Brave ranged from 431.21 to 462.34 ms.
The conservative ratio was 97.48%. One-minute host load was 5.86–6.84.
The baseline trace put the main HTML request at 57 ms, its response at 58 ms,
and the first stylesheet request at 158 ms.

Baseline elapsed times in pair order, in ms:

- Vox 383.486, 420.343, 393.539, 368.557, 369.705, 373.807, 357.445
- Brave 439.134, 437.628, 435.557, 431.207, 442.294, 445.939, 462.339

The document title and all 25 ordered post IDs, titles and link targets
matched in the audits. Both engines rendered a stable image across their own
baseline trials. The cross-browser capture differs in 349,523 pixels
(11.1110%, mean absolute channel error 0.2943 on the 0–255 scale).
Vox replayed 18 archived requests. Brave made 33 requests, including 14
unarchived requests rejected by the replay. All baseline timing processes
and the memory guard exited zero. The separately instrumented Brave content
audit captured matching content but needed forced cleanup on the busy host.

Eight focused tests in `navigation/fetch_state_test.v` and
`resources/tokenized_preloads_test.v` passed with preallocation and `-gc none`.
The loopback test held a stylesheet until after navigation polling. It checked
that the current document stayed installed until the stylesheet arrived and
that the new layout used its rule. Both test binaries and their 3 GiB runtime
guards exited zero. All 18 Python benchmark-harness tests passed. The first V
test invocation selected incompatible installed graphics modules. The passing
build used the production compiler and module paths.

The production compiler consumed the implementation in `5f21c7f3b`, but
receipt `20261122-080543-085d434c` ended during linking at the 2,700-second
build timeout. The guard recorded exit 137 for its child and exit 125 for the
managed build, with 6,276,431,872 bytes sampled at peak. The published bundle
retained the baseline executable when that attempt ended.

The live guest homepage returned HTTP 403, including after a direct request
redirected to sign-in, so live homepage timing remains unverified.

### Production validation on November 22

The completed single-unit C production build `6209346d8` (executable SHA-256
`a92b702d32ab26cf7835f2d4b148a39c8cca22f7ca841ede9542820d4a24a034`)
contains the stylesheet change. The diagnostic request trace put the first
stylesheet at 231 ms after launch, against 348 ms with
`VOX_DISABLE_EARLY_NAVIGATION_STYLESHEETS=1` on the same executable. Both
requested ten stylesheets and produced identical PNGs and content audits.
The live guest homepage still returned HTTP 403 after redirecting to sign-in.

| Seven alternating pairs per row | Vox median | Comparator median | Vox reduction | One-minute host load |
| --- | ---: | ---: | ---: | ---: |
| Current Brave, first cohort | 679.510 ms | 912.274 ms | 25.51% | 42.33–44.29 |
| Current Brave, repeat | 678.103 ms | 803.968 ms | 15.66% | 44.67–48.94 |
| Same Vox executable, stylesheet overlap disabled, first cohort | 663.023 ms | 741.974 ms | 10.64% | 41.12–42.50 |
| Same Vox executable, stylesheet overlap disabled, repeat | 685.050 ms | 711.919 ms | 3.77% | 49.07–54.02 |

Vox finished ahead in all 14 Brave pairs. Its slowest launch divided by
Brave's fastest was 104.00% in the first cohort and 109.94% in the repeat.
The 20% median margin held in one cohort and missed in the other.

Elapsed times in pair order, in ms:

| Cohort | Vox or enabled | Brave or disabled |
| --- | --- | --- |
| Brave, first | 858.468, 764.976, 679.510, 687.833, 677.016, 663.393, 657.754 | 929.577, 953.188, 912.274, 950.760, 854.459, 825.447, 838.157 |
| Brave, repeat | 727.917, 656.763, 805.395, 851.678, 661.686, 678.103, 665.134 | 798.476, 821.073, 945.369, 955.279, 779.899, 774.670, 803.968 |
| Same Vox executable, first | 723.127, 711.309, 660.482, 663.023, 751.168, 643.965, 644.762 | 776.077, 756.906, 707.215, 717.938, 816.975, 741.974, 698.691 |
| Same Vox executable, repeat | 752.481, 641.174, 675.515, 662.627, 685.050, 799.750, 788.203 | 703.199, 694.318, 702.611, 711.919, 764.817, 736.328, 1022.500 |

Brave updated to 158.1.100.58 (Chromium 158.0.8127.42). Two independent
captures match all 14 of its timing PNGs. Both audits match Vox's title and
all 25 ordered post IDs, titles and link targets. The current Brave PNG SHA-256
is `d251cbb8c3d9727f57936a08ad316ce2a5b708ae8614a56f2587fd39c3317622`,
and the historical Brave PNG hash starts `6b29ba023bc9`. The historical PNG
file is unavailable for a pixel comparison with the new version. The current
cross-browser diff has 349,523 differing pixels, the same count as the
historical comparison, with mean absolute channel error 0.2943. All Vox
timing PNGs match the published baseline SHA-256
`162ce22ae132e792387139541b8245c67a8e71dce1389b11b8dcbd8c0c153d69`.
Vox made 18 archived requests and Brave made 33 requests, including 14 that
the replay rejected. The shared archive manifest hash starts `313886b3b917`.

Each capture process exited zero. The first diagnostic and the first timing
wrappers exited 1 after writing the results because the post-run hash check
passed strings where the digest helper expected paths. Independent hash checks
matched the recorded inputs. The corrected wrappers and their memory guards
exited zero in both repeat cohorts and the separate Brave audit.

On the second archive with the original author scripts retained, a diagnostic
pair had identical captures and audits with JavaScriptCore initialized, 27
requests including two rejected by the replay, and no native-reported errors.
Its wall times were 1,151 ms enabled and 1,091 ms disabled during this
instrumented pair. In three regular-window diagnostic pairs at higher host load,
the first expensive frame ended at a median 1,276 ms enabled and 1,100 ms
disabled, with overlapping ranges of 1,022–1,389 ms and 879–1,803 ms. These
frame-log readings include installation and log delivery. With the frame
throttle disabled for seven screenshot pairs, the median rose from 803 ms to
894 ms with identical pixels. The throttle stays enabled.

### Pre-layout image requests

The trace of `6209346d8` showed the four initial CSS background requests just
after computed styles, followed by the fifth background and the 16×16 tab
icon after layout. In one diagnostic launch these groups started at 573–575 ms
and 633–637 ms, respectively. `5655e4448` queues the tab icon with the computed
backgrounds before layout and gives this batch half of the 16-request transport
budget. The regular background loader still owns cancellation, deduplication,
decoding and the icon fallback.

The four focused tests in `paint/resource_preload_test.v` passed with the
production module paths, preallocation and `-gc none`. The new test checks the
last declared favicon, duplicate URLs, hidden backgrounds and the combined
batch limit. Both the compilation guard and the 3 GiB runtime guard exited
zero. A fresh guest Vox launch of the live homepage rendered the sign-in page
with zero listing posts and exited zero.

Production attempts `20261122-153553-04c09a67` and `20261122-155304-02b2d5ea`
both exited 1. Input verification caught concurrent changes to
`platform/curl_api.h` in the first attempt and `libjs/native_code_cache.v` in
the second. The second compiler consumed the image scheduling sources. The
published executable still predates that change, so its effect on capture time
and the 20% margin remain open.

## Parallel glyph masks on Hacker News

Retained macOS text now prepares uncached A8 glyph masks in batches of up to
16. Up to four CPU lanes draw into private CoreGraphics bitmaps using a
retained immutable font. The renderer joins the batch, updates the glyph cache
on its owning thread, and composites glyphs in display-list order. Warm
strikes look up masks as before. Set `VOX_SERIAL_GLYPH_MASKS=1` for a control
that affects only this dispatch.

### Browser baseline

On 25 November 2026, seven fresh production browser processes rendered the
archived Hacker News homepage at a 1024×768 CSS viewport and 2× scale, through
the loopback replay proxy with JavaScriptCore and private profiles and caches.
The seven launch-to-written-PNG observations were 582.18, 578.18, 638.44,
629.91, 637.75, 695.81 and 641.59 ms (median 637.75 ms). Sampled browser CPU
time had medians of 478.81 ms total and 363.27 ms on the main thread. The
main-thread share had a median of 75.24%, with 16.59 ms of sampled wall time
having two or more busy threads. The sampler polls every 2 ms. Its browser
process totals omit GPU execution and helper processes, and its per-thread
counts are polling lower bounds.

All seven loads issued the same seven replay requests. The archive returned a
404 for the unarchived `/favicon.ico` fallback, and all seven document PNGs
matched the unchanged reference at all 3,145,728 pixels. A separate canonical
capture also verified all 30 story IDs in order. Its guarded run adopted both
browser and filter-worker PIDs and exited zero. The first canonical attempt
was rejected before launch because of ambient proxy and dynamic-loader
environment variables. The successful run cleared those variables and used a
fresh pixel-diff executable. Host load during the timed cohort was
161.23–161.72 on 18 CPUs. OS filesystem and shader caches were retained.

The production receipt is `20261125-055539-3e972e5b` at `4b4019fcc`
(single C unit, V `-prod`). The executable SHA-256 is
`dc25eab492d3658b87caab0ba56e9c7021ab1573b18822fc95477c88b4f534af`.
The bundled AVIF library SHA-256 is
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The archive manifest SHA-256 is
`e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0`.
The document PNG SHA-256 is
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The capture processes and the 3 GiB sampling guard exited zero.

One separately traced browser load put about 193 million main-thread
instructions in text replay. The frame also records fills, images and
compositing in display-list order. Style, layout, display-list construction
and native frame publication still run on the main thread. The mask workers
parallelize the independent CoreGraphics draws within their stage.

### Retained text replay

A separate browser launch with `VOX_TEXT_RASTER_DUMP` recorded 332 retained
draws, with their positions, transforms, colors and original backdrops.
[The glyph benchmark](../tools/benchmark_hn_glyphs.v) executes those draws
with a fresh strike cache. The timer covers the CPU glyph renderer and
excludes fixture reading, font registration, output hashing, Quartz
compositing, and the rest of the browser load.

Each cohort alternated two modes in nine fresh-process pairs using the same
optimized single-unit C executable within the cohort. The first used
`VOX_SERIAL_CPU_RASTER=1` for the control. The final cohort used the
glyph-only control `VOX_SERIAL_GLYPH_MASKS=1`. Times are milliseconds.

| Pair | First serial | First parallel | Final serial | Final parallel |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 27.478 | 23.890 | 25.093 | 21.106 |
| 2 | 32.026 | 22.447 | 23.703 | 26.708 |
| 3 | 27.320 | 23.881 | 24.960 | 26.239 |
| 4 | 24.452 | 22.309 | 23.383 | 22.738 |
| 5 | 25.761 | 22.744 | 22.730 | 22.641 |
| 6 | 25.012 | 25.263 | 28.395 | 20.493 |
| 7 | 27.778 | 27.804 | 38.349 | 27.679 |
| 8 | 22.553 | 20.268 | 27.221 | 118.276 |
| 9 | 24.488 | 24.314 | 64.013 | 150.185 |
| Median | 25.761 | 23.881 | 25.093 | 26.239 |

The parallel mode was faster in seven of nine pairs in the first cohort and
five of nine in the final cohort. Host load rose from 173.20–174.30 in the
first cohort to 203.05–203.45 in the final cohort. The timing ranges overlap
and the final cohort includes two large parallel stalls. These observations
establish pixel equality and worker activity. The latency effect is unresolved
under this level of contention.

Every captured text buffer matched between settings. The concatenated RGBA
SHA-256 was `66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`
in all 36 trials. Both executable fingerprints and the captured-input and
font fingerprints stayed fixed within their cohorts. The executable SHA-256
values were
`2e22519b82f824149e26a52e23b7348d0c66f735b9a2ec88fc21abb5bc820691` and
`0723616c7ac9159ca9c7eb0b1ad78c12c0b3a133f03b8d0f7b74f5b66e78a37f`.
The captured `runs.jsonl` SHA-256 was
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
An untimed diagnostic observed 238 mask draws in 33 batches. Fifteen batches
used four threads, 17 used three, and one used two. All replay processes and
3 GiB guards exited zero.

### Reproduce the measurements

```sh
archive=Tests/Browser/Brave/hn-home-instructions
job=Build/hn-glyphs-UNIQUE
sh tools/run_v_tool.sh run_memory_bounded --lock "$job-capture.lock" \
  --report "$job-capture-guard.json" --limit-gib 3 -- \
  python3 tools/measure_load_parallelism.py --archive "$archive" \
    --output "$job" --repeat 1 --screenshot-scale 2 \
    --ready-selector tr.athing --env "VOX_TEXT_RASTER_DUMP=$job/glyphs"
sh tools/run_v_tool.sh run_memory_bounded --lock "$job-compile.lock" \
  --report "$job-compile-guard.json" --limit-gib 3 -- \
  v -b c -cc clang -prod -enable-globals -prealloc -gc none \
    -memory-limit 10G -o "$job/glyph_benchmark" tools/benchmark_hn_glyphs.v
sh tools/run_v_tool.sh run_memory_bounded --lock "$job-replay.lock" \
  --report "$job-replay-guard.json" --limit-gib 3 -- sh -eu -c '
  for round in 1 2 3 4 5 6 7 8 9; do
    if [ $((round % 2)) = 1 ]; then modes="1 0"; else modes="0 1"; fi
    for serial in $modes; do
      VOX_SERIAL_GLYPH_MASKS=$serial "$1/glyph_benchmark" "$1/glyphs"
    done
  done
' sh "$job"
```

For the browser baseline, omit the dump and set `--repeat 7`. A production
bundle that contains the glyph change is needed for the matched full-page
comparison using `--control-env VOX_SERIAL_GLYPH_MASKS=1`.

The focused mask tests, production-mode browser type check and the pinned
glyph differential check passed. The browser bundle used above predates the
glyph change. Its replacement was still building when these checks finished.

### Glyph bounds and alpha conversion on raster workers

The worker batch now measures glyph bounds, draws each bitmap and converts the
bitmap to a packed A8 mask. Each worker uses private native bitmap storage.
The browser thread copies completed masks into its cache after the workers
join and composites the text in glyph order. Small batches give each lane
at least two keys.

A fresh capture against the same production bundle and archive reproduced
the documented PNG and glyph input hashes. Two optimized replay executables
used the same compiler flags. One used the original worker code and one
used the new pipeline. Each executable ran with parallel masks enabled and
with `VOX_SERIAL_GLYPH_MASKS=1`. The four variants rotated over 12 rounds,
with a fresh process and a fresh glyph cache for each of the 48 runs.
Glyph bounds, bitmap drawing and gamma conversion are inside the timed
interval. Input reading, font registration and hashing stay outside.

All times are milliseconds.

| Round | Previous serial | Previous parallel | New serial | New parallel |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 28.974 | 29.997 | 30.705 | 28.114 |
| 2 | 23.530 | 69.627 | 23.857 | 26.460 |
| 3 | 27.094 | 23.210 | 24.065 | 21.811 |
| 4 | 26.792 | 28.652 | 26.546 | 33.120 |
| 5 | 27.757 | 21.212 | 29.633 | 25.474 |
| 6 | 32.774 | 27.001 | 29.241 | 27.006 |
| 7 | 23.086 | 22.775 | 24.314 | 24.096 |
| 8 | 23.591 | 25.674 | 30.333 | 25.326 |
| 9 | 26.004 | 23.353 | 31.093 | 21.852 |
| 10 | 29.932 | 23.313 | 24.134 | 25.647 |
| 11 | 33.411 | 32.191 | 24.463 | 23.273 |
| 12 | 23.057 | 31.900 | 32.561 | 25.154 |
| Median | 26.943 | 26.338 | 27.893 | 25.400 |

The new parallel mode ran faster in nine of 12 rounds compared with its
serial control and seven of 12 compared with the previous parallel mode.
The ranges overlap at a one-minute host load of 212.81–214.10 on 18 CPUs.
Median CPU time for the entire process, including the input and hashing
work, was 88.754, 91.180, 86.673 and 90.727 ms respectively.

All runs produced the same 332-draw RGBA digest as the previous cohort.
Every process and the 3 GiB memory guard exited zero. Both executables, input
files and fonts kept their hashes throughout. The previous executable SHA-256
was `0723616c7ac9159ca9c7eb0b1ad78c12c0b3a133f03b8d0f7b74f5b66e78a37f`.
The new SHA-256 was
`9b1b642bffe50fceb6b348dc0b8683330b9ff930272f7a07d22d3847e3a4f2eb`.
An untimed candidate probe observed 249 keys in 34 batches. Ten batches
ran across four threads, nine across three, 13 across two and two on a
single thread.

The shared production attempt `20261125-063523-f43f35ba` rejected changed
repository inputs before C preprocessing. The timings above measure retained
text replay with the captured inputs.

### Whole-page glyph mask comparison

Production receipt `20261125-065539-e305edb5` published commit `4aad4baa6`
as a single C unit with V `-prod`. The executable SHA-256 was
`2bf74b5de62aaf33a0b2e1c538bab9bda8afe89fecb8af683dd218d42e2b3849`.
The bundled AVIF library and the archive manifest matched the earlier
baseline fingerprints. Three cohorts ran seven alternating fresh-process
pairs at 1024×768 CSS pixels and 2× scale, with JavaScriptCore, private
profiles and HTTP caches, loopback archive replay and a complete PNG
endpoint. The serial control set `VOX_SERIAL_GLYPH_MASKS=1` on the same
executable. OS filesystem and shader caches were retained.

One serial process in the first cohort fetched `y18.svg` twice. The initial
cohort failed the matched-request gate and the wrapper exited 1. All 14
browsers exited zero and matched the established document PNG digest.
Both repeats retained the same endpoint and matched every request
URL, response status, and body hash, including one archived-replay 404 for
`/favicon.ico` per process. All 28 repeat browsers and both 3 GiB guards
exited zero. The full PNG digest remained
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
A separate audit verified all 30 story IDs in order and observed 34 glyph
worker batches, including batches with four threads.

| Pair | First serial, ms | First parallel, ms | Second serial, ms | Second parallel, ms | Third serial, ms | Third parallel, ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 426.64 | 439.60 | 423.84 | 459.24 | 523.54 | 531.18 |
| 2 | 445.15 | 429.51 | 392.70 | 391.96 | 517.45 | 512.58 |
| 3 | 462.59 | 457.93 | 430.72 | 428.31 | 509.78 | 525.54 |
| 4 | 427.07 | 449.04 | 434.81 | 467.91 | 524.82 | 493.04 |
| 5 | 485.60 | 429.06 | 472.53 | 464.44 | 520.66 | 508.04 |
| 6 | 417.30 | 438.73 | 497.82 | 464.26 | 559.55 | 501.70 |
| 7 | 432.31 | 428.96 | 459.41 | 474.56 | 517.33 | 487.34 |
| Median | 432.31 | 438.73 | 434.81 | 464.26 | 520.66 | 508.04 |

The second cohort's main-thread CPU median was 269.97 ms serial and
284.74 ms parallel. Its median sampled time with at least two busy threads
rose from 13.16 to 17.84 ms and main-thread share fell from 74.2% to 73.2%.
In the third cohort, main-thread CPU medians were 311.88 and 309.28 ms,
with main-thread shares of 74.9% and 73.8%. Parallel finished first in three
of seven pairs in the second cohort and five of seven in the third.
One-minute host load was 45.03–45.47, 25.31–27.32 and 25.53–28.61,
respectively. The two request-matched launch-to-PNG medians changed in
opposite directions.

### Retained glyph blending across pixel stripes

Large retained text runs with a solid paint now batch their A8 blits and
partition the clipped destination along its longer dimension. Each worker
replays the masks in original order within its own stripe. Overlapping
glyphs keep their per-pixel blend order and worker writes are disjoint.
The path starts at 24 glyphs and at least 8,192 clipped mask pixels. It
uses up to four lanes and the existing low- or high-precision raster
pipeline. Set `VOX_SERIAL_GLYPH_BLEND=1` for the serial blend control.

The captured 332 retained draws were replayed with the same optimized C
flags and a fresh strike cache for each process. The prior code, the new
code with the serial blend control, and the striped blend rotated over 12
rounds. The timer includes the CPU glyph renderer and excludes Quartz
publication, input reading and output hashing.

| Round | Previous blend, ms | New serial, ms | Striped, ms |
| ---: | ---: | ---: | ---: |
| 1 | 15.652 | 15.413 | 13.877 |
| 2 | 14.531 | 12.884 | 13.173 |
| 3 | 16.025 | 14.668 | 16.270 |
| 4 | 16.004 | 18.238 | 20.946 |
| 5 | 17.096 | 18.263 | 14.849 |
| 6 | 17.362 | 17.728 | 17.069 |
| 7 | 17.469 | 18.658 | 18.405 |
| 8 | 18.215 | 17.213 | 19.453 |
| 9 | 18.710 | 17.860 | 18.129 |
| 10 | 17.763 | 18.358 | 16.940 |
| 11 | 18.198 | 16.944 | 18.458 |
| 12 | 17.424 | 18.277 | 18.348 |
| Median | 17.393 | 17.794 | 17.599 |

The host's one-minute load was 29.09 on 18 CPUs throughout. All 36 processes
and the 3 GiB guard exited zero, with the same RGBA digest as the preceding
replay. The executable SHA-256 values were
`9b1b642bffe50fceb6b348dc0b8683330b9ff930272f7a07d22d3847e3a4f2eb`
and `5aaabee0fdf3d5a16bdc859cd1b83405257403a96ba40713210df34665b1091c`.
The binaries, captured inputs and fonts stayed pinned. A separate probe
observed 17 striped batches, with four on four threads, seven on three
and six on two. The timing ranges overlap and the previous blend was
faster in six rounds.

### Production Hacker News captures with striped blending

Production receipt `20261125-070646-a45fd477` published the single-C-unit
V `-prod` executable
`1bb154684a1fcd711cec033152c86c1f62ce2d173d8139d3e465c15c555a9e29`.
The request started at `0c9a50a26`. The sealed C includes the striped blend
and the published executable logged 17 batches with two to four threads.
The diagnostic matched all 30 archived story IDs and the reference PNG.

Both seven-pair cohorts used fresh Vox processes and the same executable,
alternated default blending with `VOX_SERIAL_GLYPH_BLEND=1`, and timed
launch through encoded document PNG at 1024×768 CSS pixels and 2× scale.
JavaScriptCore, the offline archive, the executable and the native library
stayed fixed. OS filesystem caches were retained. Every browser and benchmark
driver exited zero, and all 28 PNG files matched the established reference
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.

| Pair | Serial, ms | Striped, ms | Repeat serial, ms | Repeat striped, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 493.548 | 516.316 | 481.704 | 464.244 |
| 2 | 470.222 | 481.186 | 470.126 | 466.136 |
| 3 | 486.807 | 533.583 | 486.574 | 478.959 |
| 4 | 475.440 | 440.499 | 467.481 | 439.772 |
| 5 | 470.764 | 458.171 | 463.582 | 497.515 |
| 6 | 470.455 | 470.491 | 455.285 | 456.481 |
| 7 | 470.434 | 514.491 | 466.623 | 451.013 |
| Median | 470.764 | 481.186 | 467.481 | 464.244 |

The seven valid pairs reproduced the same seven HTTP request and
status/body-hash records in every process, including a favicon 404.
Striping increased median wall time by 2.2% and lowered median main-thread
CPU time from 282.479 to 279.241 ms. The one-minute host load ranged from
34.67 to 39.82 on 18 CPUs. The repeat's guard returned 1 because striped
trial 4 and serial trial 7 each fetched `y18.svg` twice. Its host load
ranged from 29.52 to 32.00. The valid cohort shows a small wall-time
regression under these conditions, with overlapping trial ranges.

The diagnostic and valid cohort passed the 3 GiB guard. The cohort peaked
at 410,927,104 bytes of sampled aggregate RSS. The native AVIF library SHA
was `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
Use the load benchmark command above with
`--ready-selector tr.athing --repeat 7 --screenshot-scale 2 --js-engine javascriptcore --control-env VOX_SERIAL_GLYPH_BLEND=1`.
The diagnostic used `VOX_GLYPH_BLEND_DIAGNOSTICS=1` in its own launch.

### SVG background multisampling bounds

Static SVG backgrounds keep resource-owned scene commands after layout.
The raster plan batches their path bounds in groups of up to 256 jobs.
Workers read the retained commands and write separate trigger slots.
The browser thread prepares mutable scenes, joins the workers and
compacts the triggers in display-list order. The shared worker pool uses
up to four lanes. The serial control is `VOX_SERIAL_MSAA_PATHS=1`.

Before the change, a production capture of the archived Hacker News homepage
identified 56 root-layer triggers from SVG backgrounds. The focused replay
then used the archived HTML with its archived stylesheet inlined, registered
the archived images under their original URLs, and recorded at 1024×768 CSS
pixels with author scripts idle. The resulting list contained 554 commands
and 57 triggers. A separate
diagnostic scheduled 54 path jobs in three lanes, with 36 jobs off the caller
in its first batch. The serial and parallel trigger lists matched exactly.

The focused build used the C backend with `-prealloc -gc none` and ran 200
passes per process over the prepared list and warm SVG scenes. These
unprofiled times include trigger collection and the worker join.
They exclude layout, GPU rendering and PNG encoding.

| Pair | Serial, µs per pass | Parallel, µs per pass |
| ---: | ---: | ---: |
| 1 | 146.946 | 163.043 |
| 2 | 163.197 | 189.790 |
| 3 | 156.961 | 171.820 |
| 4 | 147.425 | 165.579 |
| 5 | 165.720 | 164.192 |
| 6 | 156.300 | 169.149 |
| 7 | 142.999 | 162.190 |
| 8 | 145.643 | 169.362 |
| 9 | 147.900 | 157.083 |
| Median | 147.900 | 165.579 |

The median dispatch and collection cost increased by 17.7 µs for this
workload. The one-minute host load was 28.30–28.94 on 18 CPUs. All 18
fresh processes and their 3 GiB guard exited zero. Peak aggregate RSS was
139,100,160 bytes. The archive manifest SHA was
`e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` and
the replay executable SHA was
`5dfe651c0b074d4c0f283009bc4a09c461ee77ea147c3084e3de59287647dfef`.

All 23 focused multisampling tests passed. The batch test preserved
clipping and trigger order across a 256-job batch with 192 off-thread
jobs and a 28-job tail. The shared raster scan worker tests also passed.
Two extra attempts to compile the stand-alone static SVG layout tests
exceeded the 12 GiB guard, including a retry with serial C generation.

#### Production page captures

Receipt `20261125-072247-4031dc62` passed the production startup smoke
and published executable
`8937b44ce64f1559096c0af2c202c720cfa9858df5982a622d0c00a0de7cb36a`.
The single-C-unit V `-prod` inputs were sealed at `b92bb2bda`.
The native AVIF library had the same SHA as in the striped-blend cohorts.
Eight fresh diagnostics matched the reference PNG and all 30 story IDs.
Each scheduled 54 jobs in three lanes and observed zero off-thread jobs
at one-minute host loads from 30.99 to 88.85. The browser and driver exits
were zero. The diagnostic wrappers and guards returned 1 because they
required actual off-thread work.

Two seven-pair cohorts timed fresh launches through encoded document PNG
at 1024×768 CSS pixels and 2× scale with JavaScriptCore and the offline
archive. Default and serial settings alternated. All 28 browser
processes and both drivers exited zero, and all PNGs matched the same
established reference. Executable, native library, fixture and tools stayed
pinned. OS filesystem caches were retained.

| Pair | Serial, ms | Default, ms | Repeat serial, ms | Repeat default, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 453.365 | 464.208 | 404.220 | 422.445 |
| 2 | 519.727 | 462.433 | 422.664 | 456.279 |
| 3 | 446.921 | 470.149 | 464.403 | 462.811 |
| 4 | 504.618 | 460.706 | 413.947 | 416.410 |
| 5 | 464.009 | 476.022 | 423.048 | 425.565 |
| 6 | 448.545 | 448.811 | 418.440 | 457.987 |
| 7 | 449.694 | 467.003 | 478.169 | 453.299 |
| Median | 453.365 | 464.208 | 422.664 | 453.299 |

Default trial 5 fetched `y18.svg` twice in the first cohort, so its
request-parity guard returned 1. Host load was 64.09–73.08 on 18 CPUs.
In the repeat, all seven request records matched across the 14 launches.
Its guard exited zero with a 412,450,816-byte peak, and host load was
47.33–52.61. The repeat's default median was 7.2% slower. Timing ranges
overlapped, and the diagnostic showed no worker overlap on this production
page. The observed launch difference cannot be attributed to off-thread
path evaluation.

For the full-page comparison, use the load benchmark command with
`--ready-selector tr.athing --repeat 7 --screenshot-scale 2 --js-engine javascriptcore --control-env VOX_SERIAL_MSAA_PATHS=1`.
Use `VOX_MSAA_TILE_DIAGNOSTICS=1` in a separate diagnostic to verify activity.
Batches of independent path geometry now use workers. Raster submission
and publication still depend on the browser thread.

### Overlap SVG path bounds with command collection

The macOS scheduler queues the first 32 retained path jobs as soon as
they are available. Their fixed input and result slots stay valid while the
browser thread prepares later paths. It can also evaluate the remaining
range before joining the worker. The browser thread compacts the completed
results in display-list order. `VOX_SYNC_MSAA_PATHS=1` defers dispatch
until collection ends. `VOX_SERIAL_MSAA_PATHS=1` keeps the direct serial
collector.

The focused Hacker News replay used the same inlined archive and the same
554 commands and 57 triggers as the earlier measurement. Its diagnostic
observed 32 of 54 jobs on a background thread in both the first pass and
the warm pass. The worker finished before the join in both passes.
The timed cohort rotated all three settings over seven rounds on one
non-`-prod` C executable with `-prealloc -gc none`. Each fresh process
timed the first collection and 200 subsequent collections with the
recording and SVG scenes retained. The first timed collection includes
SVG scene preparation. The warm passes include trigger assembly and the
worker join. All 21 processes produced identical ordered triggers and
exited zero. The 3 GiB guard exited zero and peaked at 138,018,816 bytes.

| Round | First serial, µs | First sync, µs | First overlap, µs | Warm serial, µs | Warm sync, µs | Warm overlap, µs |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1033.333 | 1063.709 | 935.042 | 100.246 | 109.077 | 96.851 |
| 2 | 872.292 | 1120.916 | 1037.250 | 96.938 | 107.570 | 95.462 |
| 3 | 1033.125 | 953.584 | 1154.459 | 95.148 | 110.623 | 98.024 |
| 4 | 964.333 | 916.625 | 1230.833 | 100.666 | 106.557 | 99.578 |
| 5 | 1036.583 | 1000.917 | 1191.667 | 94.643 | 110.931 | 105.058 |
| 6 | 914.375 | 950.917 | 904.208 | 94.741 | 110.312 | 92.610 |
| 7 | 886.208 | 900.583 | 909.958 | 96.034 | 109.052 | 95.771 |
| Median | 964.333 | 953.584 | 1037.250 | 96.034 | 109.077 | 96.851 |

Warm overlap reduced the synchronous median by 11.2%. The first-pass
median increased by 83.7 µs. Host load was 14.85–15.70 on 18 CPUs. The
replay executable SHA was
`1587a8a95511de36c3908b1f541993b548a7dc222ed56ce8543b1b9d3b0a48eb`.
The archive and all its response bodies stayed pinned.

The 23 focused multisampling tests passed with overlap, synchronous
dispatch, and raster workers disabled. The shared raster scan tests checked
that the submitted range executes on a separate thread and joins before
the caller uses its results. The focused multisampling and raster scan tests
also passed under ThreadSanitizer.

A separate instrumented launch on the synchronous production build
`2cbf2dd3cb2de7340ec9cc02263902ae590ce378451f8fb27cbbbc29d2137b33`
matched the Hacker News reference PNG. Through document encoding the
calling thread retired 2.216 billion instructions. Flow layout accounted
for 250.9 million exclusive instructions, text replay for 145.1 million,
and raster tile setup for 4.5 million including its child scopes. The
trace includes diagnostics overhead.

#### Production SVG overlap on Hacker News

Receipt `20261125-074137-dde245c0` sealed `9c2cd16ba` in a
single-C-unit V `-prod` build and passed the startup smoke. Its published
executable SHA was
`280d23619019e06b7147a470b816f6a183b79265829a80bc09e07c10fa60451d`.
The native AVIF library SHA matched the preceding production cohort.

Fresh launch diagnostics checked all 30 story IDs and the reference PNG.
In the overlap setting, 32 of 54 path jobs ran off the browser thread and
finished before the join. In the synchronous setting, zero path jobs ran
off the browser thread. Both settings selected the same ordered trigger
positions and layer grids. A separate diagnostic reproduced these results
with the paced replay used for timing. The diagnostic processes and
their 3 GiB guards exited zero.

Three seven-pair cohorts alternated default overlap and
`VOX_SYNC_MSAA_PATHS=1`. Every process started with a private empty profile
and HTTP cache. The timer spans launch through encoded document PNG at
1024×768 CSS pixels, 2× scale, and JavaScriptCore. The executable, native
library, archive, and driver hashes stayed fixed. OS filesystem caches
were retained. All 42 browsers and all three benchmark drivers exited
zero, and their PNGs matched the established reference exactly.

| Pair | Sync, ms | Overlap, ms | Repeat sync, ms | Repeat overlap, ms | Paced sync, ms | Paced overlap, ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 306.593 | 295.763 | 307.341 | 300.665 | 364.315 | 372.951 |
| 2 | 298.989 | 282.122 | 293.338 | 295.220 | 329.022 | 345.006 |
| 3 | 302.831 | 282.394 | 295.860 | 310.911 | 346.464 | 366.135 |
| 4 | 299.762 | 307.547 | 304.367 | 303.563 | 366.116 | 326.168 |
| 5 | 345.626 | 304.457 | 290.871 | 310.696 | 374.070 | 373.823 |
| 6 | 294.666 | 289.080 | 298.111 | 290.899 | 364.310 | 354.244 |
| 7 | 305.858 | 298.427 | 297.694 | 312.006 | 360.580 | 360.205 |
| Median | 302.831 | 295.763 | 297.694 | 303.563 | 364.310 | 360.205 |

The first two cohorts had an intermittent extra `y18.svg` request in
six launches each, so their request-parity guards returned 1. In the
first cohort, overlap trials 1, 2, 3, 5 and 6 and synchronous trial 6
made the extra request. In the repeat, overlap trials 1, 2, and 6 and
synchronous trials 2, 5 and 6 made it.

The paced cohort used the same browser driver and delayed every replayed
`GET https://news.ycombinator.com/y18.svg` response by 60 ms in
`Replay.response_entry`. All 14 launches then received the same eight
request and response records. The paced cohort passed the 3 GiB guard,
with a 391,495,680-byte peak. On 18 CPUs with one-minute load
22.15–23.82, overlap had a 1.1% lower median wall time and was faster in
four pairs. The timing ranges overlap and the effect on whole-page latency
remains inconclusive. The production probes establish off-thread path
evaluation under both replay policies.

### Shape independent Latin text runs during initial layout

The first native Chromium-policy layout collects up to 64 ordinary ASCII
text contexts with installed fonts. The browser thread resolves the usual
font and cache keys and skips warm entries. It sends half of a sufficiently
large cold batch to a worker and shapes the other half itself. The worker
owns its HarfBuzz buffers and borrows immutable native fonts. After the
join, the existing glyph decoder publishes results under the ordinary
shaping-cache keys. `VOX_SERIAL_ASCII_LAYOUT_SHAPING=1` selects ordinary
on-demand shaping. [HarfBuzz object lifetimes](https://harfbuzz.github.io/object-model-lifecycle.html)

The focused replay used the archived Hacker News HTML at 1024×768 CSS
pixels, with its stylesheet inlined and archived images registered under
their original URLs. Author scripts were idle. A separate probe prepared
28 entries, ran 14 jobs on a worker, and recorded 56 hits on the prepared
entries. Every replay produced the same 554 command geometries and 483
glyph runs. Their positions and glyph indices produced the same
checksum `961d99c633fd8923`.

Each measurement launched a fresh process with the same non-`-prod` C
executable and used `-prealloc -gc none`. The timer spans the first
typed layout call, including style resolution and geometry. It excludes
HTML parsing, display-list recording, and PNG encoding.

| Pair | Serial, ms | Parallel, ms | Repeat serial, ms | Repeat parallel, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 125.736 | 134.327 | 104.308 | 107.348 |
| 2 | 130.737 | 137.263 | 105.116 | 104.290 |
| 3 | 121.591 | 118.193 | 107.188 | 102.514 |
| 4 | 107.775 | 116.030 | 108.772 | 105.485 |
| 5 | 108.861 | 116.821 | 107.132 | 104.169 |
| 6 | 139.729 | 131.928 | 105.540 | 103.898 |
| 7 | 127.350 | 116.032 | 108.668 | 107.009 |
| 8 | 104.036 | 114.298 | 106.753 | 107.707 |
| 9 | 111.875 | 112.415 | 104.545 | 108.901 |
| Median | 121.591 | 116.821 | 106.753 | 105.485 |

The median paired change was +6.526 ms in the first cohort and −1.642 ms
in the repeat. Parallel was faster in three and six pairs, respectively.
One-minute host load was 16.59–16.90 and 10.46–10.58 on 18 CPUs. The
direction of the layout timing effect varies between cohorts. All 36
replay processes and both 3 GiB guards exited zero. The peak RSS was
144,130,048 bytes. The fixture manifest and replay executable stayed pinned
at `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0`
and `bd8b54b2b9f912340facc4a8102c38ae05c11d9b4feac3fe1e4e3a943038b310`.

The focused shaping checks passed, including exact glyph equality and
trailing whitespace after the join. ThreadSanitizer passed the worker
test. The UTF-16, bidi, safe-break and Chromium advance tests passed.
The focused layout checksum also matched with arena poisoning and with
raster workers disabled. The whole-browser production-mode type check
passed.

#### Production layout shaping on Hacker News

Receipt `20261125-080258-26aa2838` sealed `6f917d517` in a
single-C-unit V `-prod` build and passed the startup smoke. The
first build attempt ended before C preprocessing because repository inputs
changed during compilation. The published executable SHA was
`ebc1426818e108c8208c3d33209b68c3db600d381deb292bdb915e79c031b0ef`.
The AVIF library SHA matched the preceding production cohort.

A fresh diagnostic reproduced the focused 28 prepared shapes, 14
off-thread jobs and 56 cache hits. The serial control skipped the batch.
Both matched the reference PNG and all 30 archived story IDs. A separate
instrumented launch in each setting measured calling-thread instructions
through the encoded PNG. Exclusive flow layout changed from
157,090,135 to 152,125,735 instructions. The parallel prepare and publish
scope took 5,971,166 instructions, and the inclusive layout geometry
scope changed from 178,616,823 to 179,689,519. The scopes include
instrumentation overhead and the inclusive total covers its subscopes.

Two seven-pair cohorts alternated the default with
`VOX_SERIAL_ASCII_LAYOUT_SHAPING=1` on the same published executable.
Every launch used a fresh private profile and HTTP cache, 1024×768 CSS
pixels at 2× scale, and JavaScriptCore. The timer ended at the encoded
document PNG. The replay applied the preceding cohort's fixed 60 ms
delay on each `y18.svg` response. All 28 launches matched the same
eight request and response records and reference PNG. Executable,
native library, archive and tooling hashes remained pinned. OS
filesystem caches were retained.

| Pair | Serial, ms | Parallel, ms | Repeat serial, ms | Repeat parallel, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 358.740 | 337.592 | 338.732 | 352.840 |
| 2 | 340.844 | 392.580 | 353.420 | 354.544 |
| 3 | 357.323 | 336.007 | 343.588 | 340.194 |
| 4 | 355.782 | 348.285 | 346.530 | 338.614 |
| 5 | 334.991 | 340.988 | 348.905 | 371.340 |
| 6 | 352.211 | 346.000 | 352.424 | 371.470 |
| 7 | 358.397 | 350.501 | 357.510 | 366.556 |
| Median | 355.782 | 346.000 | 348.905 | 354.544 |

Parallel was faster in five pairs in the first cohort and two in the
repeat. Median paired changes were −7.497 ms and +9.046 ms at one-minute
host loads of 11.80–13.50 and 14.39–17.02, respectively, on 18 CPUs.
Launch latency remains inconclusive. The timing and diagnostic browsers,
drivers and 3 GiB guards all exited zero. The larger timing peak was
389,513,216 bytes of aggregate RSS.

### Decode prepared shapes at first use

The first layout keeps the batch's HarfBuzz buffers in a thread-local
geometry scope. A matching cache miss takes one buffer and uses the
normal decoder, cache store, and return path. The first glyph-run caller
receives the newly decoded run directly. Width and safe-break callers
populate the same cache. Scope exit releases unused buffers, and a
native font-cache reset makes outstanding buffers ineligible for reuse.
`VOX_EAGER_ASCII_LAYOUT_SHAPING=1` selects the preceding eager
publication behavior on the same executable.

The focused Hacker News replay used the same 1024×768 inlined archive and
the same initial typed-layout interval as the preceding focused cohorts.
A diagnostic staged 28 buffers, shaped 14 on the worker, and consumed
all 28. Eager publication and arena poisoning produced the same
554 commands, 483 glyph runs, and geometry and glyph checksum
`961d99c633fd8923`.

| Round | Serial, ms | Eager, ms | On demand, ms | Repeat serial, ms | Repeat eager, ms | Repeat on demand, ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 91.971 | 91.726 | 92.337 | 94.493 | 99.695 | 94.527 |
| 2 | 91.345 | 92.160 | 91.901 | 95.309 | 94.213 | 93.969 |
| 3 | 91.972 | 92.299 | 92.740 | 95.142 | 93.744 | 93.880 |
| 4 | 93.062 | 90.196 | 94.292 | 97.119 | 94.123 | 93.845 |
| 5 | 95.946 | 94.450 | 95.344 | 93.440 | 95.042 | 94.880 |
| 6 | 98.165 | 101.525 | 95.310 | 94.140 | 94.648 | 94.857 |
| 7 | 97.713 | 95.387 | 97.742 | 94.533 | 94.773 | 94.877 |
| 8 | 94.287 | 95.970 | 93.435 | 93.230 | 96.205 | 94.514 |
| 9 | 93.758 | 101.572 | 98.275 | 93.412 | 94.664 | 93.492 |
| Median | 93.758 | 94.450 | 94.292 | 94.493 | 94.664 | 94.514 |

The median paired change from eager to on-demand publication was
+0.441 ms and −0.245 ms, respectively. Host load was 22.19 in the first
cohort and 21.86–22.55 in the repeat on 18 CPUs. All 54 processes matched
the same layout checksum and exited zero, as did both 3 GiB guards.
The non-`-prod` C executable used `-prealloc -gc none` and stayed pinned
at SHA `8e77db4934e0bb86504542ff96177005c796107846f9986fb7b76a7f78cbb08e`.
The archive and response fingerprints stayed unchanged.

Focused checks covered glyph and whitespace equality, per-font and
spacing keys, first use by safe-break metrics, nested scopes, discard of
unused buffers, and native font retirement. The focused tests passed
under preallocation and ThreadSanitizer. The whole-browser
production-mode type check passed.

#### Production on-demand shaping on Hacker News

Receipt `20261125-081947-87776ad4` sealed `2b607e604` and passed the
startup smoke. It published the single-C-unit V `-prod` executable
`25a4419dd5ebe7ab916a465634fa27be4447094486083b9d6814a1037f04e434`.
The AVIF library SHA matched the preceding cohort. The earlier shared
build stopped before C preprocessing after repository inputs changed.

Native diagnostics verified the reference PNG and all 30 story IDs.
Both settings shaped 14 of the 28 jobs on a worker. On-demand
publication consumed all 28 prepared buffers and recorded 28 later
cache hits. Eager publication recorded 56 hits. A separate instrumented
pair traced main-thread instructions through the encoded PNG. The ASCII
preparation scope fell from 5,954,051 to 839,920 instructions. Exclusive
flow layout rose from 151,781,893 to 156,666,231, and inclusive layout
geometry moved from 179,297,222 to 179,155,395. The scope measurements
include tracing overhead, and the inclusive total covers its subscopes.

Two seven-pair cohorts alternated on-demand and eager publication on
the same executable using `VOX_EAGER_ASCII_LAYOUT_SHAPING=1` for the
control. The endpoint was the encoded document PNG at 1024×768 CSS
pixels and 2× scale. Every launch used JavaScriptCore, a fresh private
profile and HTTP cache, and the fixed 60 ms logo response delay used
above. All 28 launches matched the same eight request and response
records and the reference PNG. The executable, native libraries, archive,
and tooling hashes stayed pinned, and OS filesystem caches were retained.

| Pair | Eager, ms | On demand, ms | Repeat eager, ms | Repeat on demand, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 352.401 | 331.842 | 334.947 | 340.939 |
| 2 | 335.991 | 331.948 | 335.779 | 353.723 |
| 3 | 331.962 | 327.908 | 357.047 | 352.530 |
| 4 | 341.609 | 344.743 | 346.408 | 331.411 |
| 5 | 353.803 | 353.737 | 341.979 | 347.571 |
| 6 | 345.656 | 346.674 | 345.665 | 349.411 |
| 7 | 338.927 | 353.872 | 328.277 | 369.740 |
| Median | 341.609 | 344.743 | 341.979 | 349.411 |

On-demand publication was faster in four pairs and two repeat pairs.
The median paired changes were −0.066 ms and +5.592 ms. One-minute
host load was 20.12–21.92 and 19.30–20.32 on 18 CPUs. Whole-page
latency had no demonstrated improvement. All timing and diagnostic
browsers, drivers and 3 GiB guards exited zero. The larger timing peak
was 390,709,248 bytes of aggregate RSS.

#### Parallel Core Text strike advances on Hacker News

Commit `94e2ce428` moves eligible Core Text strike advance calculations
into the existing initial-layout HarfBuzz jobs. The browser thread
resolves the font file or registered face once per shaping key and
allocates the output arrays. The job computes the untracked native
widths and applies the same fixed-point HarfBuzz adjustments as the
on-demand path. The browser thread decodes glyphs and publishes the
cache. The on-demand path also handles longer runs and native failures.
[Core Text threading](https://developer.apple.com/documentation/coretext/)

Production receipt `20261125-083356-91b96f1e` sealed the change and passed
the startup smoke. It published the single-C-unit V `-prod` executable
`0ba5789de96871a2397864d66264528b2977d9481e1f2c8d8a33cddfdb166796`.
The AVIF library SHA was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.

Two seven-pair cohorts alternated the default with
`VOX_SERIAL_ASCII_STRIKE_ADVANCES=1` on this executable. The control
still shaped 14 HarfBuzz runs on the worker and calculated native
advances as the browser thread consumed each buffer. The launch-to-
encoded-PNG endpoint used 1024×768 CSS pixels, 2× scale, JavaScriptCore,
private empty profiles and HTTP caches, and the 60 ms replay delay for
each logo response. OS filesystem caches were retained. All 28 timing
launches and two diagnostic launches preserved the reference PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and the same eight request and response records. The diagnostics also
verified all 30 ordered story IDs and complete document readiness.
The executable, native library, archive, and tool hashes stayed pinned.

| Pair | Control, ms | Worker advances, ms | Repeat control, ms | Repeat worker advances, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 340.312 | 376.170 | 422.088 | 392.737 |
| 2 | 351.609 | 330.756 | 428.468 | 421.477 |
| 3 | 353.783 | 335.862 | 360.707 | 359.915 |
| 4 | 343.445 | 342.818 | 320.780 | 329.942 |
| 5 | 359.780 | 359.905 | 434.201 | 367.839 |
| 6 | 344.228 | 354.093 | 471.792 | 481.180 |
| 7 | 352.258 | 346.706 | 440.952 | 454.968 |
| Median | 351.609 | 346.706 | 428.468 | 392.737 |

Worker advances were faster in four pairs in each cohort. The median
paired changes were −0.626 ms and −0.793 ms. One-minute host load was
8.33–8.54 and 8.50–11.54 on 18 CPUs. The variation between launches
leaves the whole-page speedup unconfirmed. All browsers, drivers and
3 GiB guards exited zero. The highest timing peak was 375,799,808 bytes
of aggregate RSS.

In the separate diagnostic pair, both modes consumed all 28 buffers.
The candidate prepared the native advances for all 28 runs, including
14 on the worker. Exclusive main-thread instructions in flow layout
fell from 156,353,669 to 154,892,144. The preparation scope rose from
837,948 to 2,762,957 and inclusive geometry rose from 178,822,650 to
179,352,691. These instruction scopes include instrumentation overhead.
The change establishes off-thread strike work on this page. Style
resolution, line placement, glyph publication, and native frame
submission still execute on the browser thread.

Focused checks passed for shape equivalence, the long-run fallback,
context metrics, strike rounding and safe-break widths. The parallel
shaping tests also passed under ThreadSanitizer and with preallocation
and arena poisoning. The whole-browser production type check passed.
Two optional layout-only benchmark compilation attempts reached the
12 GiB guard before producing an executable. The production benchmark
used the published bundle.

#### Parallel glyph decoding on Hacker News

Commits `69a787ba2` and `06ff0e9be` let initial-layout shaping jobs
decode eligible HarfBuzz buffers into glyph positions, clusters, safe-break
flags, and trailing whitespace. The decoder writes into arrays allocated
by the browser thread and releases each successfully decoded buffer in
its shaping job. The ordinary decoder uses the same glyph calculations.
Cache publication copies the worker results into its own arena. Width,
context-metric, and safe-break queries can publish glyphs without building
a temporary playback run. A full run owns a mutable copy in its caller's
arena. The generated C reads the HarfBuzz buffer length without allocating
a V output variable on the worker.
[HarfBuzz buffer implementation](https://raw.githubusercontent.com/harfbuzz/harfbuzz/15.1.0/src/hb-buffer.cc)

Focused checks covered bidi, the original glyph producer, default-ignorable
characters, native strike rounding, spacing, ligatures, nonzero baselines,
safe breaks, and arena retirement. The prepared-shape checks also passed
with ThreadSanitizer, arena poisoning, and serial decoding.

The first shared production build, receipt `20261125-084749-76c57369`,
contained the worker decoder before the buffer metadata allocation fix.
One diagnostic pair compared it with all ASCII batching disabled. The
default decoded 14 of 28 runs off-thread and consumed all 28. Both
launches exited zero, preserved the same eight replay requests, matched the
reference PNG, and returned all 30 story IDs in order.

Receipt `20261125-085341-c890ddce` sealed the allocation fix and passed
the native startup smoke. This single-C-unit V `-prod` build published
executable SHA `bce49bde115317102cf6f8e48569a1b94ab12f2a5aca19fa63580a306667eae5`.
The AVIF library SHA was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.

Three seven-pair cohorts alternated worker decoding and
`VOX_SERIAL_ASCII_GLYPH_DECODE=1` on that executable. The third cohort
started with the serial setting to change which mode went first in the
odd-numbered pairs. Both settings kept HarfBuzz shaping and Core Text
strike calculation in the existing parallel batch. Every launch used
JavaScriptCore, a private empty profile and HTTP cache, a 1024×768 CSS
pixel viewport at 2× scale, and a 60 ms delay on replayed logo responses.
OS filesystem caches were retained. The timer starts at process launch
and ends when the document PNG is complete.

| Pair | Serial, ms | Worker, ms | Repeat serial, ms | Repeat worker, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 366.808 | 398.219 | 410.113 | 335.762 | 327.831 | 324.557 |
| 2 | 369.579 | 346.102 | 326.887 | 338.730 | 334.624 | 344.583 |
| 3 | 349.981 | 362.450 | 350.720 | 340.728 | 335.274 | 343.156 |
| 4 | 353.296 | 374.746 | 331.921 | 364.795 | 345.921 | 315.207 |
| 5 | 363.314 | 342.121 | 352.921 | 372.731 | 348.394 | 336.511 |
| 6 | 341.013 | 341.066 | 333.723 | 349.317 | 351.563 | 322.887 |
| 7 | 338.291 | 376.018 | 331.697 | 329.730 | 330.697 | 348.815 |
| Median | 353.296 | 362.450 | 333.723 | 340.728 | 335.274 | 336.511 |

Median paired changes were +12.469 ms, +11.842 ms, and −3.274 ms.
Worker decoding was faster in two, three, and four pairs, respectively.
One-minute load was 5.79–5.97, 5.97–6.05, and 5.79–6.93 on 18 CPUs.
These timings leave the whole-page speedup unconfirmed. All 42 timing
launches and both diagnostic launches had identical eight-record request
and response fingerprints and matched the reference PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The executable, native library, archive, and tool hashes stayed constant.
The browsers, drivers, and 3 GiB guards exited zero. The largest timing
peak was 377,225,216 bytes of aggregate RSS.

The separate diagnostic pair verified full readiness and all 30 ordered
story IDs in both settings. Both consumed all 28 prepared runs. The
default decoded 14 off-thread and 14 on the browser thread. The control
decoded all 28 on the browser thread when requested. Main-thread
instructions for flow layout fell from 150,384,792 to 150,232,088.
Preparation rose from 2,770,698 to 2,953,751, and inclusive geometry fell
from 174,917,384 to 174,850,467. These scopes include tracing overhead.
Style resolution, line placement, glyph publication, and native frame
submission still execute on the browser thread.

#### More workers for initial text shaping

Commit `334b43aa2` uses four lanes for a cold batch of at least 24 runs,
three for 16–23 runs, and two for 8–15 runs, within the CPU count and
raster worker limit. It explicitly submits the background ranges to
Grand Central Dispatch and shapes the final range on the browser thread.
The browser thread joins the workers before publishing or retiring the
prepared shapes. The candidate selection and cache keys are unchanged.
`VOX_TWO_LANE_ASCII_LAYOUT_SHAPING=1` selects the two-lane control.

The focused tests exercise uneven partitions, the serial raster setting,
exact glyph and whitespace equality, and the existing image and mask
blur paths. The range and shaping checks also passed with ThreadSanitizer
and with preallocation and arena poisoning.

The focused benchmark extracted 27 eligible title strings from the
archived homepage and shaped them in Verdana at 13⅓ CSS pixels. A fresh
process timed dispatch through worker join, excluding font preparation
and cache publication. It exercised the production shaping callback on
a small non-`-prod` C test executable using preallocation. The two-lane
probe shaped 13 titles off-thread. Four lanes shaped 20 off-thread and
used four distinct threads. Both modes consumed all 27 results and
produced 1,345 glyphs with the same playback and width checksum
`74745bc03b491318`, including in the arena-poisoned probes.

| Pair | Two lanes, ms | Four lanes, ms |
| ---: | ---: | ---: |
| 1 | 0.282 | 0.325 |
| 2 | 0.455 | 0.253 |
| 3 | 0.446 | 0.355 |
| 4 | 0.292 | 0.346 |
| 5 | 0.291 | 0.219 |
| 6 | 0.289 | 0.319 |
| 7 | 0.278 | 0.215 |
| 8 | 0.289 | 0.223 |
| 9 | 0.281 | 0.306 |
| 10 | 0.301 | 0.223 |
| 11 | 0.296 | 0.323 |
| Median | 0.291 | 0.306 |

The median paired change was −0.063 ms, with four lanes faster in six
pairs. The timings are mixed. All 24 processes and the 3 GiB guard exited
zero. Host load was 5.30 on 18 CPUs. The test executable stayed pinned at
`f903a34d78a3645b29234010f9d3c24c538981a419db5a2a7d3d9a0691a7d1bb`,
and the extracted title input at
`77fcc2b20ff0bbc1bfd1cc10829c3cee41ad4cbe05d44cb20608928d205452aa`.

Three production attempts stopped on changed checkout inputs before
sealing C. These were receipts `20261125-090719-ee1219c8`,
`20261125-090949-e49d7858`, and `20261125-091102-bdfc7600`. The
second identified a regenerated LibJS corpus tool C file. The shared
worker retried from the canonical checkout.

Production receipt `20261125-091339-20c7aecc` sealed `cf32affec`, which
includes the four-lane change. This single-C-unit V `-prod` build passed
the native startup smoke and published executable SHA
`0fb8d34da40c266b0235bb9512bfddc81db775d8b7a6e4d3b9be17dce9297e82`.
The AVIF library SHA was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.

The diagnostic pair confirmed that the default used four distinct threads
and shaped, measured, and decoded 21 of 28 runs off the browser thread.
The two-lane setting used two threads and did 14 of 28 runs off-thread.
Both consumed all 28 results and verified all 30 ordered story IDs
after the document reached complete readiness. Main-thread instructions
for preparing the shapes dropped from 2,874,059 to 1,695,296. Flow layout
rose from 150,432,963 to 150,774,198 while inclusive geometry fell from
174,890,951 to 174,102,692. These scopes include tracing overhead.

Two separate seven-pair cohorts alternated the default and the two-lane
control on that same executable. The second cohort started with the
two-lane process to reverse the order in odd-numbered pairs. The timer
ends when the document PNG is complete, starting from a fresh launch
with JavaScriptCore, an empty private profile and HTTP cache, 1024×768
CSS pixels at 2× scale, and the same 60 ms replay delay for each logo
response. OS filesystem caches were retained.

| Pair | Two lanes, ms | Four lanes, ms | Reversed two lanes, ms | Reversed four lanes, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 350.198 | 327.332 | 327.244 | 340.545 |
| 2 | 357.562 | 354.536 | 323.299 | 332.081 |
| 3 | 350.228 | 330.103 | 350.815 | 333.711 |
| 4 | 338.023 | 352.153 | 363.146 | 345.238 |
| 5 | 327.152 | 337.400 | 339.669 | 335.935 |
| 6 | 353.442 | 339.302 | 347.943 | 336.495 |
| 7 | 367.665 | 350.813 | 357.426 | 329.698 |
| Median | 350.228 | 339.302 | 347.943 | 335.935 |

Four lanes finished sooner in five pairs in each cohort. Median paired
changes were −14.139 ms and −11.448 ms. Host load was 5.09–5.66 and
4.92–5.09 on 18 CPUs. The end-to-end differences include startup, network
replay, and capture. The isolated shaping timings and traced geometry
show smaller changes within the renderer.

All 28 timing launches and both diagnostic launches had the same eight
request and response records and matched the reference PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
All browsers, drivers, and 3 GiB guards exited zero. The executable,
native library, archive and driver hashes stayed pinned, and the largest
timing peak was 377,847,808 bytes of aggregate RSS. Style resolution,
line placement, cache publication, and native frame submission still
run on the browser thread.

### Parallel viewport visibility checks

Commits `b027edd89` and `752ea3530` distribute cached viewport paint blocks
across raster workers on macOS. The browser thread resolves the visual
contexts used by testable entries, then workers use the existing
native-precision rectangle tests to mark disjoint ranges of the
visibility mask. The browser thread joins
the workers before recording commands in paint order. The serial path
handles small batches and legacy rectangle
diagnostics. `VOX_SERIAL_VIEWPORT_CULLING=1` selects the serial control.

The production browser type check passed. The focused layout test
compiler reached its memory limit during standalone compilation. The
production checks below exercise the visibility path through display-list
recording and capture.

Receipt `20261125-092631-fdf65c44` published the initial change with an
eligibility test that compared the full visual-context tree with the
number of entry blocks. The diagnostic Hacker News replays recorded
438 entries but issued zero worker batches. Both seven-pair timing
cohorts therefore measured the serial fallback. Their median paired
changes were −3.206 ms and +0.992 ms. Every capture matched the
reference PNG. Commit `752ea3530` removes the ineligible-context
limit and resolves only contexts used for ink tests.

Receipt `20261125-093413-469f9eae` published the corrected single-C-unit
V `-prod` executable at SHA
`1d227f827419b55b15f74e2dc175e7d9b5ab21e1cc4a7e343fcb4380c5e1bd41`.
The startup smoke passed. Hacker News used 129 visual contexts. The
candidate ran three lanes for each of two recordings of 438 entries
and tested nine of the 14 blocks off the browser thread in each
recording. The control ran the serial checks. Both diagnostics verified
the 30 ordered story IDs and complete document readiness.

Main-thread hardware instructions for viewport visibility fell from
1,941,999 to 1,546,419. Inclusive paint command recording fell from
33,378,268 to 33,299,282. These are instrumented scopes.

Two alternating seven-pair production cohorts used the same binary with
`VOX_SERIAL_VIEWPORT_CULLING=1` for the control. The second cohort ran
the serial setting first in odd-numbered pairs. The measurement spans
fresh launch through the encoded document PNG at 1024×768 CSS pixels
and 2× scale with JavaScriptCore and fresh private profiles and HTTP
caches. The replay retains the 60 ms delay on each logo response. OS
filesystem caches were retained.

| Pair | Serial, ms | Workers, ms | Reversed serial, ms | Reversed workers, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 327.004 | 351.014 | 359.601 | 368.243 |
| 2 | 349.519 | 339.458 | 389.586 | 365.713 |
| 3 | 334.575 | 337.330 | 363.172 | 384.928 |
| 4 | 375.633 | 344.910 | 370.586 | 361.044 |
| 5 | 370.963 | 367.383 | 391.478 | 399.443 |
| 6 | 361.144 | 354.364 | 378.370 | 379.977 |
| 7 | 361.390 | 376.542 | 402.738 | 387.336 |
| Median | 361.144 | 351.014 | 378.370 | 379.977 |

Median paired changes were −3.579 ms and +1.608 ms. Workers finished
first in four and three pairs, respectively. Host load was 7.00–7.40
and 7.93–8.02 on 18 CPUs. The launch-to-capture timings show no
consistent speedup.

All 28 timing launches and both diagnostics matched the same eight
replay requests and the established PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The executable, native libraries, replay archive and driver hashes
stayed pinned. All browsers, drivers and 3 GiB guards exited zero.
The larger timing peak was 377,225,216 bytes of aggregate RSS.

The focused browser fixture exercised a fixed translucent layer, a rotated
entry, an overflow clip, and an off-screen source with a visible drop
shadow. The first version stayed on the small-batch fallback and matched
the serial PNG at both offsets. A denser version with 160 rows generated
1,128 paint entries and dispatched 27 of 36 blocks to workers. Its top
and 740 CSS-pixel scroll captures matched the serial PNG byte for byte
at each offset. Both modes retained all 160 ordered row IDs. The four
processes and both 3 GiB guards exited zero. The two PNG SHAs were
`7d51e803cd0676a54cfe2c056d279bb933451d073610c73ef06823fc270cd7b8`
and `db268acf0e143fc1eb8a69c78c519bce30fe2e965843d273f2b15adc22939414`.

### Parallel display-list leaf projection

Commit `44ff81a77` lets workers copy eligible cached paint commands into
preassigned display-list slots and apply the resolved transform, clip and
opacity. The browser thread reserves slots in paint order and inserts the
layer transitions. Commands that require live canvas or scroll state,
local geometry, or scene allocation are projected there as well. Command
effect bounds and scene publication follow the worker join.
`VOX_SERIAL_DISPLAY_LIST_REPLAY=1` selects serial projection.

The whole-browser production type check passed, and the shared raster
range tests passed under ThreadSanitizer. The added regression case
checks source-command immutability and the slots reserved for layer
transitions. Standalone layout test builds had reached the compiler
memory limit during the preceding visibility work. Runtime coverage
for the new path used the production captures below. The generated C
projection and callback made no V heap allocations.

Receipt `20261125-094821-fe6de3ef` sealed `9bd548482`, which includes
the worker projection change. The single-C-unit V `-prod` build passed
the startup smoke and published executable SHA
`366a61547c13d4600b7e9984387bf5e1a93bf2ad0ee490e202e6a7f172ed6994`.
The native AVIF library SHA matched the preceding cohort.

Hacker News recorded two display lists of 443 commands in the
diagnostic launch. In each recording, 441 eligible leaves used the
preassigned slots, with 332 projected off the browser thread in a
four-lane batch. The serial control produced the same reference PNG
and all 30 ordered story IDs. Main-thread instructions for recording
the commands fell from 1,572,464 to 1,116,963. Inclusive paint command
recording rose from 32,076,821 to 32,466,757. These figures are from a
single instrumented pair.

The two seven-pair timing cohorts alternated worker projection and
`VOX_SERIAL_DISPLAY_LIST_REPLAY=1` on the same executable. The second
cohort started with the serial setting. Both measured from fresh
launch through the completed document PNG at 1024×768 CSS pixels
and 2× scale, with JavaScriptCore, private empty profiles and HTTP
caches, and a 60 ms delay on each replayed logo response. OS filesystem
caches were retained.

| Pair | Serial, ms | Workers, ms | Reversed serial, ms | Reversed workers, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 308.918 | 331.317 | 298.990 | 310.231 |
| 2 | 306.906 | 312.513 | 312.367 | 339.032 |
| 3 | 302.163 | 315.838 | 318.674 | 297.590 |
| 4 | 311.918 | 309.016 | 317.977 | 305.900 |
| 5 | 320.961 | 303.080 | 314.236 | 323.082 |
| 6 | 311.004 | 304.096 | 313.792 | 299.530 |
| 7 | 309.175 | 304.640 | 312.266 | 326.264 |
| Median | 309.175 | 309.016 | 313.792 | 310.231 |

Median paired changes were −2.902 ms and +8.846 ms, with workers
finishing first in four and three pairs. Host load was 5.40–5.92 and
4.76–5.44 on 18 CPUs. These results show no consistent end-to-end
speedup. The 28 timing launches and both diagnostics had identical
eight-record request and response fingerprints and matched PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
All browser, driver and 3 GiB guard exits were zero. Executable, native
library, archive, and driver hashes stayed pinned. The highest timing
peak was 375,734,272 bytes of aggregate RSS.

The mixed fixture included a live canvas, fixed opacity, transforms,
an overflow clip, and an off-screen source with a visible drop shadow.
Workers projected 638 leaves off-thread at the top and 649 at a
740 CSS-pixel scroll offset. Both pairs matched the serial PNG exactly
and preserved all 160 ordered row IDs. The top capture also matched
the earlier production reference and verified the canvas pixel
`(218, 69, 103)`. The two PNG SHAs were
`5c6ab81d41d7a00055571cdfe2adbc7d633b75d859759ae93fe1271a49d90229`
and `d9acc8f9908ab7eb7bc201b809cf18f1a1cbd7eb627cc17039a1f9cd43bf5f2e`.
All four browsers and both guards exited zero. Paint ordering, layer
effect bounds and frame publication still run on the browser thread.

### Parallel canvas bounds before paint replay

Commits `e777e5c10` and `37dd07d70` precompute the native-precision
off-canvas test for ordinary paint commands on raster workers. The draw
loop still walks group boundaries in paint order and decides whether each
result applies. Resource and filter inputs may contribute visible pixels
from outside the canvas. Videos, zoomed commands and frames reusing scroll
damage use the existing serial tests. `VOX_SERIAL_PAINT_CANVAS_BOUNDS=1`
selects the serial control.

The whole-browser type check passed. The standalone culling test exposed a
four-byte enum pointer store into a one-byte array in the intermediate
build. The fix uses explicit byte storage, and the corrected culling tests
passed with arena poisoning enabled. Disassembly confirmed a byte store.
The scope test covers translated ink, a filter with off-canvas inputs,
a skipped effect group, and the live video fallback.

Production receipt `20261125-100755-8cb4b858` sealed `37dd07d70` with
single-C-unit V `-prod`, passed startup smoke, and published executable SHA
`86238581844e719d3ba1c5e58f24d77a397781cb0409923bddf6f8eeb6119ebd`.
The native AVIF library SHA was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The sealed C included the byte store and its draw-loop consumer.

In the Hacker News diagnostic, the four-lane batch computed canvas bounds
for 443 commands, with 332 off the browser thread. The geometry test
reported 60 commands outside the canvas. Both captures matched the prior
reference and preserved all 30 ordered story IDs. In the single
instrumented pair, the preparation stage used 129,636 main-thread
instructions. Inclusive native raster replay measured 287,313,438
instructions with serial culling and 292,045,356 with workers.

The two seven-pair cohorts alternated workers and
`VOX_SERIAL_PAINT_CANVAS_BOUNDS=1` on the same executable. The second
cohort started with the serial setting. Each trial measured from fresh
launch through the completed document PNG, at 1024×768 CSS pixels and
2× scale with JavaScriptCore, private empty profiles and HTTP caches,
and a 60 ms delay on each replayed logo response. OS filesystem caches
were retained. The measurement used
`tools/measure_load_parallelism.py` with a temporary replay wrapper
that delayed the logo and verified input hashes before and after each trial.

| Pair | Serial, ms | Workers, ms | Reversed serial, ms | Reversed workers, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 307.856 | 308.175 | 309.545 | 305.332 |
| 2 | 306.713 | 322.241 | 319.244 | 323.044 |
| 3 | 325.499 | 298.037 | 299.858 | 313.775 |
| 4 | 307.791 | 335.806 | 318.867 | 295.983 |
| 5 | 313.329 | 328.121 | 308.618 | 312.199 |
| 6 | 304.758 | 294.968 | 329.150 | 311.084 |
| 7 | 306.572 | 306.604 | 312.604 | 302.437 |
| Median | 307.791 | 308.175 | 312.604 | 311.084 |

Median paired changes were +0.320 ms and −4.213 ms, with workers
finishing first in two and four pairs. Host load was 4.10–4.83 and
4.68–4.87 on 18 CPUs. Sampled main-thread CPU medians were
159.97 → 164.17 ms in the first cohort and 161.94 → 161.68 ms in
the second. Launch-to-capture timing showed no consistent speedup.

The 28 timing captures and both diagnostic captures matched the
reference PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
Every launch had the same eight request and response fingerprints,
including the replayed favicon miss. The executable, native library,
archive and driver hashes stayed pinned. All browser, driver and 3 GiB
guard exits were zero. Peak aggregate timing RSS was 368,377,856 bytes.

A 160-row fixture with transforms, opacity, an overflow clip, and a
drop-shadow filter exercised 644 off-thread bounds at the top and 655
at a 740 CSS-pixel scroll offset. Each capture matched its serial
control exactly and preserved all 160 ordered row IDs. The top capture
also matched the preceding production reference. The two PNG SHAs were
`933869e9973d6ad96c4476462b6cdd1e4c5e269545072285a31f29b316481b00`
and `459894db09e97b4d456446e4f9e3419593c7238a631936711f15bce0ac37363d`.
All four fixture browser exits and both guard exits were zero. Native
paint dispatch, group transitions and frame publication still execute
on the browser thread.

### Overlap canvas bounds with native frame setup

Commit `6b2f81f52` submits all canvas-bounds ranges to raster workers
before native frame setup when there is no previous scroll-raster
key frame. Worker inputs and results live in replay scratch until
the draw loop joins the batch. Raster-layer setup and the scroll
probe use their usual allocation scopes during that interval.
When previous scroll keys exist, the probe runs first. A full
repaint can use the synchronous worker batch, and a reused frame
culls against its scroll-damage plan. `VOX_SYNC_PAINT_CANVAS_BOUNDS=1`
selects the synchronous batch for the same-binary comparison.

The culling tests passed with arena poisoning. The overlap test
released the scratch allocation scope, allocated frame-setup data,
then reentered scratch and checked all 443 worker results before
resetting it. A ThreadSanitizer check ran 100 uneven workloads at
each of one, two, three and four background lanes and verified that
every range ran off the caller and wrote its assigned indices.

Production receipt `20261125-101808-2d03fa5d` sealed `6b2f81f52`,
passed startup smoke and published executable SHA
`a764074919e4bdbaab3600224665f7c197aba1c61dc2f2a3bcdad6f947187731`.
It used single-C-unit V `-prod`. Its native AVIF library SHA matched
the preceding canvas-bounds trial.

The diagnostic launch computed all 443 Hacker News bounds on four
worker lanes and completed before the join. The synchronous control
computed 332 bounds off-thread and 111 on the browser thread. Both
identified 60 off-canvas bounds and preserved all 30 ordered story IDs.
In the instrumented pair, the two overlap scopes used a combined
64,878 main-thread instructions for submission and join, compared
with 129,980 for the synchronous scope. Inclusive native raster replay
measured 287,971,459 instructions in the synchronous control and
291,091,538 with overlap.

The two seven-pair cohorts alternated both settings on the same build.
The second cohort started with the synchronous setting. Each trial ran
from fresh launch through completion of the 1024×768 CSS-pixel document
PNG at 2× scale, using JavaScriptCore, a private empty profile and HTTP
cache, and a replayed 60 ms delay on each logo response. OS filesystem
caches were retained.

| Pair | Synchronous, ms | Overlapped, ms | Reversed sync, ms | Reversed overlap, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 334.619 | 296.961 | 322.931 | 325.543 |
| 2 | 294.956 | 329.842 | 303.386 | 298.553 |
| 3 | 314.728 | 313.902 | 300.167 | 308.427 |
| 4 | 301.639 | 341.804 | 344.583 | 325.793 |
| 5 | 322.734 | 301.959 | 290.892 | 329.495 |
| 6 | 330.257 | 308.381 | 332.630 | 326.608 |
| 7 | 321.161 | 323.644 | 300.582 | 309.645 |
| Median | 321.161 | 313.902 | 303.386 | 325.543 |

Median paired changes were −0.826 ms and +2.612 ms, with overlap
finishing first in four and three pairs. Host load was 6.19–7.02 and
6.63–6.86 on 18 CPUs. The paired timings show no consistent change in
launch-to-capture latency.

The 28 timing captures and both diagnostics matched the prior reference
PNG SHA `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
All launches had identical eight-record request and response fingerprints,
including the replayed favicon miss. The executable, native library,
archive and driver hashes stayed pinned throughout. Browser, driver and
3 GiB guard exits were zero. Peak timing RSS was 368,885,760 bytes.

### Prepare retained glyph positions on raster workers

On the preceding production build (`a7640749…7731`), an instrumented
Hacker News capture measured 146,829,173 main-thread instructions for
text replay, the largest paint-leaf scope. Commit `e35e4ffc6` adds
position conversion and conservative run bounds to the canvas-bounds
worker batch. Each worker writes into a separate slice of a packed
replay scratch buffer. Chromium runs fold in the baseline after
rounding positions to float32. LibWeb runs apply the baseline later.
Replay uses the prepared values after joining the batch.

The native context, glyph cache and backdrop blending stay on the
browser thread. Small batches, zoomed commands and frames that reuse
scroll pixels prepare glyph positions when they draw. Frames cap the
number of prepared positions and command slots. The culling test ran
with arena poisoning and verified Chromium and LibWeb coordinates,
per-command bounds, and the source glyph positions across the worker join.
The CPU glyph raster suite passed its Skia pixel comparisons.

Production receipt `20261125-103028-32cdceac` sealed `c654765bd`,
which includes the glyph preparation change, in single-C-unit V `-prod`
mode. It passed startup smoke and published executable SHA
`e2d4c598ddd30eb15a8cf1e7ace242d3abb15c16bb63e2783b17c0b55bd5b5ee`.
Its native AVIF library SHA matched the preceding trial.

The Hacker News diagnostic found 373 runs prepared off-thread. Replay
used the prepared geometry for 332 runs, covering 5,428 position
coordinates. Both diagnostic launches matched the 30 ordered story IDs.
A separate instrumented pair without per-run logging measured
145,809,691 main-thread instructions in serial text replay and
150,919,537 with worker preparation. Inclusive native raster replay
measured 289,636,065 and 295,612,637 instructions, respectively.

The timing control set `VOX_SERIAL_RETAINED_GLYPH_GEOMETRY=1` and kept
canvas culling on workers. Two seven-pair cohorts alternated the same
executable's settings, with the second cohort starting in serial mode.
Each trial measured from fresh launch through the completed document
PNG at 1024×768 CSS pixels and 2× scale, with JavaScriptCore, private
empty profiles and HTTP caches, and a replayed 60 ms delay on each
logo response. OS filesystem caches were retained.

| Pair | Serial, ms | Workers, ms | Reversed serial, ms | Reversed workers, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 316.604 | 323.809 | 327.868 | 331.212 |
| 2 | 323.917 | 309.341 | 325.309 | 329.601 |
| 3 | 301.238 | 335.162 | 313.102 | 354.741 |
| 4 | 321.472 | 316.094 | 305.038 | 294.409 |
| 5 | 314.082 | 334.345 | 321.012 | 317.801 |
| 6 | 318.654 | 309.870 | 299.547 | 306.877 |
| 7 | 309.213 | 317.952 | 300.813 | 307.958 |
| Median | 316.604 | 317.952 | 313.102 | 317.801 |

Median paired changes were +7.205 ms and +4.293 ms. Workers finished
first in three and two pairs. Host load was 7.34–7.59 and 6.98–7.34
on 18 CPUs. Sampled main-thread CPU medians were 173.90 → 173.95 ms
and 170.22 → 171.18 ms. The measured cohorts show a launch-to-capture
regression alongside the extra off-thread work.

The 28 timing captures and four diagnostic captures matched the prior
reference PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
All 32 launches produced identical eight-record request and response
fingerprints, including the favicon miss. Executable, native library,
archive and driver hashes stayed pinned. All browser, driver and 3 GiB
guard exits were zero. Peak aggregate timing RSS was 383,270,912 bytes.

### Reserve glyph positions by worker range

Commit `5e7891ca6` removes the two command scans on the browser thread
that sized and packed the glyph buffer. The browser thread reserves
bounded scratch storage. Each worker gets a disjoint slice proportional
to its command range and assigns positions as it visits the commands.
The worker skips off-canvas text. A draw that needs that text inside an
effect, or has a run that exceeds the worker's slice, computes its
geometry during replay.

The production type check and arena-poisoned culling tests passed
with both worker strategies.
They cover uneven ranges, an oversized glyph run followed by a fitting
run, and text outside the canvas. The same-executable comparison uses
`VOX_PACKED_RETAINED_GLYPH_GEOMETRY=1` for the previous packing strategy
and `VOX_SERIAL_RETAINED_GLYPH_GEOMETRY=1` for on-demand glyph geometry.
Both controls keep canvas bounds preparation on workers.

Production receipt `20261125-104407-2f48c8c6` sealed `5e7891ca6` in
single-C-unit V `-prod` mode, passed startup smoke and published
executable SHA `d28f00de0a653a9fd4884ae70fa45ff069b99fd01b5014e67e25d513e5112664`.
The preceding attempt stopped when the source changed before C
preprocessing. The build worker retried from the committed revision.

On the archived Hacker News homepage, four worker lanes prepared 332
glyph runs and replay used all 332. The previous strategy prepared
373 runs and replay used 332. Both batches were ready at the join,
and the four diagnostic launches preserved all 30 ordered story IDs.

In a separate instrumented pair without per-run logging, browser-thread
glyph buffer reservation fell from 75,856 to 30,931 instructions.
Main-thread text replay measured 145,446,620 instructions with packed
geometry and 144,550,918 with per-range storage. Inclusive native
raster replay measured 284,069,760 and 282,882,390 instructions,
respectively.

Four seven-pair cohorts alternated the per-range mode with either packed
or serial geometry on the same executable. The reversed cohorts started
with the control. Each trial measured from fresh launch through the
completed document PNG at 1024×768 CSS pixels and 2× scale, with
JavaScriptCore, empty private profiles and HTTP caches, and a replayed
60 ms delay on each logo response. OS filesystem caches were retained.
Times below are milliseconds.

| Pair | Packed | Per-range | Reversed packed | Reversed per-range | Serial | Per-range | Reversed serial | Reversed per-range |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 310.476 | 327.799 | 315.464 | 312.449 | 339.131 | 344.140 | 299.149 | 315.600 |
| 2 | 339.581 | 331.637 | 329.628 | 369.372 | 320.510 | 341.902 | 310.456 | 314.875 |
| 3 | 312.734 | 322.568 | 305.958 | 329.378 | 323.138 | 343.153 | 320.156 | 317.695 |
| 4 | 332.344 | 336.409 | 324.892 | 321.831 | 288.678 | 309.197 | 303.613 | 315.855 |
| 5 | 337.407 | 316.665 | 306.945 | 326.362 | 307.715 | 311.253 | 297.861 | 296.610 |
| 6 | 342.180 | 311.051 | 313.281 | 297.744 | 297.892 | 321.479 | 299.723 | 291.287 |
| 7 | 330.847 | 313.889 | 305.179 | 309.081 | 311.094 | 330.719 | 313.283 | 302.572 |
| Median | 332.344 | 322.568 | 313.281 | 321.831 | 311.094 | 330.719 | 303.613 | 314.875 |

Median paired changes against packed geometry were −7.944 ms and
+3.902 ms, with per-range storage winning four and three pairs. The
changes against serial were +20.014 ms and −1.250 ms, with per-range
storage winning zero and four pairs. Host loads on 18 CPUs were
6.92–7.99 and 7.16–7.44 for packed controls, and 7.91–8.24 and
7.39–8.14 for serial controls. Launch-to-capture timings showed no
consistent speedup. The first serial cohort was slower with per-range
storage in every pair.

All 56 timing captures and six diagnostic captures matched reference PNG
SHA `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight-record request and response fingerprints matched in every
launch, including the favicon miss. Executable, native library,
archive and driver hashes stayed pinned. Browser, driver and 3 GiB
guard exits were zero. Peak aggregate timing RSS was 376,258,560 bytes.

### Overlap cold glyph masks with the backdrop read

Commit `633625da4` submits a cold A8 mask batch before reading the
backdrop for eligible document text. CoreText workers draw into
private bitmaps while the browser thread reads the previously
painted pixels. It joins the batch, publishes completed masks into
the glyph cache and blends in paint order. Short runs and warm
starts use the ordinary mask lookup. Clipped and extended-color runs
use the established read-before-raster path.

A dump from the preceding production bundle (`d28f00de…2664`) found
332 retained glyph runs on the Hacker News reference image. All 332
used a backdrop and 174 contained at least four glyphs. The new
diagnostic records how many completed mask jobs overlapped the
backdrop read. `VOX_SYNC_GLYPH_BACKDROP=1` reads the backdrop first
and uses the existing parallel mask batches as the timing control.

The production type check and arena-poisoned mask tests passed.
The tests compare the resulting pixels and verify caller-thread
loading, completed joins, and unchanged output and mask contents
after a failed backdrop read.
The CPU glyph raster suite also passed its Skia pixel comparisons.

Production receipt `20261125-105649-29d81323` sealed `633625da4` in
single-C-unit V `-prod` mode, passed startup smoke and published
executable SHA `87e856b295d23343569bbdacba074c0e3c9c43ae7fdff8038e8eb5338465d303`.

The production diagnostic saw 27 asynchronous batches containing
202 mask jobs across two to four lanes. Three jobs, each in a
different batch, overlapped the backdrop read. Every batch was
still running at the join. Both launches ran 34 total parallel
mask batches and matched all 30 ordered story IDs. A separate
instrumented pair measured 145,659,171 versus 136,908,798 main-thread
instructions for text replay, and 295,080,770 versus 283,785,200
inclusive native raster instructions, in synchronous and overlap
mode respectively.

The two seven-pair cohorts alternated modes on the same executable.
The reversed cohort started with the synchronous control. Each
trial measured fresh launch through the completed document PNG at
1024×768 CSS pixels and 2× scale, with JavaScriptCore, empty private
profiles and HTTP caches, and a replayed 60 ms delay on each logo
response. OS filesystem caches were retained.

| Pair | Synchronous, ms | Overlap, ms | Reversed sync, ms | Reversed overlap, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 307.766 | 302.737 | 329.298 | 338.384 |
| 2 | 329.841 | 318.692 | 334.162 | 314.100 |
| 3 | 306.484 | 320.464 | 330.396 | 294.155 |
| 4 | 301.197 | 315.878 | 300.174 | 323.864 |
| 5 | 330.500 | 319.797 | 291.354 | 322.017 |
| 6 | 312.779 | 337.143 | 309.710 | 311.444 |
| 7 | 306.556 | 362.447 | 318.429 | 313.462 |
| Median | 307.766 | 319.797 | 318.429 | 314.100 |

Median paired changes were +13.980 ms and +1.734 ms, with overlap
finishing first in three pairs in each cohort. Host load was
3.86–6.32 and 6.32–7.10 on 18 CPUs. Sampled main-thread CPU medians
were 179.96 → 179.14 ms and 174.85 → 173.34 ms. Both launch-to-capture
cohorts had a slower median paired result with overlap.

All 28 timing launches and four diagnostic launches matched reference
PNG SHA `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight-record request and response fingerprints matched in every
launch, including the favicon miss. Executable, native library,
archive and driver hashes stayed pinned. Browser, driver and 3 GiB
guard exits were zero. Peak aggregate timing RSS was 370,524,160 bytes.

Commit `118447667` makes overlap opt-in with
`VOX_OVERLAP_GLYPH_BACKDROP=1` following the timing results. Production
receipt `20261125-110428-557f50e0` sealed that setting and passed
startup smoke. Executable SHA
`0c03a94fe7cf6a81d3cfef9db4b732f86e1810cb37ce51e22fe1817ba3f65299`
ran 34 parallel mask batches in both verification captures. The
default ran zero asynchronous batches. Enabling the flag ran 27.
Both fresh launches matched the reference PNG, the 30 ordered
story IDs and the eight replay records. Browser and guard exits
were zero.

### Pipeline cold glyph masks through raster setup

Commit `87d566731` widens the work that the browser thread can do while
cold A8 masks render. The pipeline submits jobs before raster clip
checks, reads the backdrop on the browser thread, and joins the batch
after blitter setup. The browser thread publishes masks and blends in
glyph order. An early clip rejection or a backdrop read failure joins
the workers and releases their private bitmaps before returning.

`VOX_PIPELINE_GLYPH_MASKS=1` enables the wider pipeline.
`VOX_OVERLAP_GLYPH_BACKDROP=1` selects the backdrop-only experiment.
The default reads the backdrop before dispatching the ordinary parallel
mask batch. All three modes share the glyph cache and blitter.

The production type check and arena-poisoned glyph batch tests passed.
The tests compare both overlap modes with the synchronous image and
verify that a failed read or clip rejection publishes no masks. The
CPU glyph raster suite passed its Skia pixel comparisons.

Production receipt `20261125-111304-0ff2a011` sealed `87d566731` in
single-C-unit V `-prod` mode, passed startup smoke and published
executable SHA `1554fdfd9008cf7cc017f0b1eb60e5ad9f1ef1a239aadc11fe9d54a006e399ac`.

In the Hacker News diagnostic pair, both overlap modes submitted 27
batches with 202 mask jobs on two to four lanes. Seven pipeline jobs
overlapped browser-thread work across four batches, compared with
three jobs across three backdrop-only batches. The count covers the
interval between the end of submission and the join. Four pipeline
jobs overlapped the read itself. The pipeline repeated against the
default and recorded five overlapping jobs. Every overlap batch
still had work in flight at the join. Each launch ran
34 total parallel mask batches and preserved all 30 ordered story IDs.

A separate instrumented pair measured 134,739,485 versus 135,465,706
main-thread text replay instructions, and 288,407,664 versus
289,107,505 inclusive native raster instructions, in backdrop-only
and wider pipeline mode respectively.

Four seven-pair cohorts alternated the wider pipeline with either
backdrop-only overlap or the default on the same executable. The
reversed cohorts started with the control. Trials measured fresh
launch through the completed document PNG at 1024×768 CSS pixels and
2× scale, with JavaScriptCore, empty private profiles and HTTP caches,
and a replayed 60 ms delay on each logo response. OS filesystem
caches were retained. Times are milliseconds.

| Pair | Backdrop only | Pipeline | Reversed backdrop only | Reversed pipeline | Default | Pipeline | Reversed default | Reversed pipeline |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 340.688 | 348.401 | 316.167 | 320.973 | 318.400 | 326.531 | 291.508 | 300.104 |
| 2 | 338.438 | 324.702 | 328.403 | 334.284 | 303.823 | 323.352 | 300.171 | 308.036 |
| 3 | 321.837 | 315.380 | 324.683 | 293.159 | 312.649 | 296.770 | 293.275 | 292.912 |
| 4 | 330.210 | 304.290 | 316.075 | 316.893 | 325.867 | 309.094 | 311.199 | 302.716 |
| 5 | 314.377 | 308.436 | 292.947 | 295.741 | 312.691 | 336.055 | 300.186 | 325.639 |
| 6 | 287.582 | 295.530 | 315.588 | 314.488 | 291.581 | 325.143 | 329.680 | 338.824 |
| 7 | 330.180 | 308.622 | 317.575 | 313.514 | 294.131 | 312.694 | 330.266 | 316.385 |
| Median | 330.180 | 308.622 | 316.167 | 314.488 | 312.649 | 323.352 | 300.186 | 308.036 |

Median paired changes against backdrop-only overlap were −6.458 ms
and +0.818 ms, with the pipeline finishing first in five and three
pairs. Changes against the default were +18.563 ms and +7.866 ms,
with the pipeline finishing first in two and three pairs. Host load
on 18 CPUs was 5.77–6.10 and 5.26–7.12 for the backdrop-only
cohorts, and 5.00–5.77 and 4.76–5.26 for the default cohorts.
The wider pipeline remains opt-in.

All 56 timing launches and six diagnostic launches matched reference
PNG SHA `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight-record request and response fingerprints matched in every
launch, including the favicon miss. The executable, native library,
archive and driver hashes stayed pinned throughout. Browser, driver
and 3 GiB guard exits were zero. Peak aggregate timing RSS was
378,798,080 bytes.

### Prefetch glyph masks across replay commands

Commit `3cf41a0ca` schedules a single cold A8 mask batch across the
first eligible text runs. The browser thread plans the keys and opens
the strikes before command dispatch. Workers draw privately while the
browser thread paints the preceding commands. The browser thread joins
and publishes before its first ordinary text draw. Unused batches are
joined and discarded before replay scratch resets.

`VOX_PREFETCH_FRAME_GLYPH_MASKS=1` enables the experiment on native
Chromium-style sRGB replay at integral 1× or 2× scale. It draws from
prepared horizontal glyph positions and examines up to 160 commands,
with a limit of 32 runs, four strikes and 128 cold keys. The normal
draw resolves the actual strike and glyph key. A prediction that misses
uses the ordinary mask path.

The first production diagnostic, receipt `20261125-112907-e1cdc0cc`,
matched the Hacker News reference but submitted no jobs. It stopped
before the timing cohorts. The eligibility trace showed a 0.5 layout
transform on text in the 2× capture. Commit `277998efd` composes
positive axis-aligned layout scales with the device scale when
computing the candidate strike.

The scale-corrected diagnostic, receipt `20261125-113701-933c444e`,
published all 107 masks from four strikes before the first ordinary
text draw. Ninety-eight jobs overlapped earlier paint commands.
The default ran 34 per-run mask batches and the prefetch ran 27.
Both captures matched the reference PNG.

The production type check and arena-poisoned glyph tests passed. The
focused test prepares two strikes, verifies that publication happens at
the join, and matches the serial pixels. A warm repeat finds the
required keys in the cache. The CPU glyph raster suite passed its Skia
pixel comparisons. Commit `18e410c53` skips nonfinite projected glyphs
before building a subpixel key. The focused test verifies that invalid
transforms and positions produce no prefetch jobs.

Production receipt `20261125-114306-cc5fb4cc` sealed `09d2753be` with
the finite-coordinate guard in single-C-unit V `-prod` mode. It passed
startup smoke and published executable SHA
`b8666c1b92278aec0e78486c9f187841ab360a2f6d37bc6b43d3617e9ebf307c`.
The final diagnostic reproduced all 107 publications and 98
overlapping jobs across four lanes. Ordinary per-run mask work went
from 249 jobs in 34 batches to 192 jobs in 27 batches. Both launches
matched all 30 ordered story IDs.

In a separate instrumented pair, main-thread text replay went from
146,293,193 to 127,305,572 instructions. Prefetch submission and join
together took 3,875,262 instructions. The inclusive native raster
scope, which includes both, went from 292,965,417 to 274,590,281
instructions.

The timing comparison used two seven-pair cohorts on the same
executable. The reversed cohort started with the default. Each trial
measured fresh launch through completion of the 1024×768 CSS-pixel
document PNG at 2× scale, with JavaScriptCore, empty private profiles
and HTTP caches, and a replayed 60 ms delay on each logo response.
OS filesystem caches were retained.

| Pair | Default, ms | Prefetch, ms | Reversed default, ms | Reversed prefetch, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 290.834 | 294.680 | 295.313 | 299.067 |
| 2 | 300.776 | 315.453 | 310.146 | 292.409 |
| 3 | 314.448 | 311.067 | 316.778 | 300.676 |
| 4 | 321.805 | 312.138 | 302.462 | 303.090 |
| 5 | 302.809 | 329.975 | 306.145 | 299.639 |
| 6 | 318.573 | 350.003 | 309.987 | 304.335 |
| 7 | 302.583 | 320.394 | 315.268 | 294.699 |
| Median | 302.809 | 315.453 | 309.987 | 299.639 |

Median paired changes were +14.677 ms and −6.506 ms, with prefetch
finishing first in two and five pairs. Host load was 4.49–5.34 and
5.31–5.85 on 18 CPUs. Sampled main-thread CPU medians were
171.41 → 174.72 ms and 161.33 → 165.50 ms. Launch-to-capture timings
showed no consistent speedup, so prefetch remains opt-in.

All 28 timed launches and four diagnostic launches on the final
build matched reference PNG SHA
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight-record request and response fingerprints matched for all
32 launches, including the favicon miss. Executable, native library,
archive and driver hashes stayed pinned throughout. Browser, driver
and 3 GiB guard exits were zero. Peak aggregate timing RSS was
367,067,136 bytes.

### Plan cold frame glyph keys on a worker

Commit `c9b38730e` moves key selection for cold frame prefetch batches
off the browser thread. The browser thread resolves the strikes and
copies the existing glyph keys. A worker maps positions, rejects
nonfinite results and deduplicates into fixed-size tables in run order.
It then hands the selected keys to the raster lanes. The browser
thread joins the work and publishes the masks before ordinary text replay.

Warm batches select keys on the caller so an empty plan can return
without dispatching. `VOX_SYNC_FRAME_GLYPH_PLANNING=1` selects caller
planning for the benchmark control. Both modes enable
`VOX_PREFETCH_FRAME_GLYPH_MASKS=1` and use the same key selection logic.

The production type check passed. The arena-poisoned tests passed in
both modes. They compare output pixels with serial raster, verify
that the cache stays empty of masks until publication, and cover
fully warm keys and nonfinite projected positions.

#### Retained Hacker News text replay

The published `20261125-114306-cc5fb4cc` browser captured 332 retained
text draws from the archived homepage at 1024×768 CSS pixels and 2×
scale. The capture matched the reference PNG and all 30 ordered story
IDs. The input log SHA-256 was
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.

A standalone single-C-unit V `-prod` replay used the canonical glyph
fixture loader, `VOX_ARENA_POISON=1`, a fresh glyph cache and the first
32 eligible runs for prefetch. It timed submission, immediate join and
all 332 CPU draws. The replay omits the preceding paint commands, so
the join could not overlap with them. The initial harness used a V
assertion to call the draw. V `-prod` elided that call. The corrected
harness executes each draw unconditionally and checks its success.

The diagnostic pair published 107 masks across four strikes and four
lanes in each mode. The planner ran on a worker in the candidate and on
the caller in the control. Seven additional pairs alternated the modes
in fresh processes with the same executable
`b25099bb9e3155e00ab3880ed0b0f184ea1e1cef2086f8e07814577356ea59a5`.

| Pair | Caller planning, ms | Worker planning, ms |
| ---: | ---: | ---: |
| 1 | 9.702 | 9.808 |
| 2 | 9.429 | 10.178 |
| 3 | 9.262 | 9.518 |
| 4 | 9.068 | 9.634 |
| 5 | 9.592 | 10.306 |
| 6 | 9.646 | 9.535 |
| 7 | 9.110 | 11.124 |
| Median | 9.429 | 9.808 |

The paired median total increased 0.567 ms. Median submission was
1.468 ms on the caller and 1.445 ms with worker planning. Median join
was 1.245 ms and 1.112 ms, respectively. Host load was 5.45 on 18 CPUs.
All 16 valid replays matched the previous RGBA reference SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.
Executable and all 333 input hashes stayed pinned. Capture, build,
replays and memory guards exited zero. The 3 GiB replay guard measured
47,366,144 bytes peak aggregate RSS.

#### Matched production captures

Receipt `20261125-120409-e0083ee7` sealed `884e27054`, passed startup
smoke, and published single-C-unit V `-prod` executable SHA-256
`3aeba18066748f06b3fb28159cf4f9f50218b3a545f5270d2b1346e4e2d7f8d4`.
Earlier attempts stopped when source inputs changed before the seal.
The production diagnostic published 107 masks from four strikes
across four lanes in both modes. All 107 were ready at the join, 98
overlapped preceding paint commands, and ordinary replay issued 192
mask jobs in 27 batches. Both launches matched the 30 ordered story
IDs. The diagnostic confirmed the selected planner thread in each run.

A separate instrumented pair measured 3,567,776 → 3,567,367
main-thread instructions for prefetch submission and 228,781 →
241,247 for the join, in caller and worker mode respectively.
Inclusive native raster replay measured 274,315,605 → 277,574,719
instructions. Strike and run preparation still execute on the caller.

The timing cohorts used the same fresh-process launch-to-encoded-PNG
endpoint and 60 ms replayed logo delay as the preceding benchmark.
Both kept prefetch enabled. The first cohort started with worker
planning and the reversed cohort started with caller planning.

| Pair | Caller, ms | Worker, ms | Reversed caller, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 309.107 | 280.264 | 301.321 | 312.769 |
| 2 | 303.436 | 298.843 | 306.224 | 302.473 |
| 3 | 297.091 | 299.626 | 316.484 | 317.709 |
| 4 | 316.003 | 299.457 | 298.845 | 320.774 |
| 5 | 301.018 | 308.585 | 299.328 | 312.216 |
| 6 | 298.396 | 325.115 | 318.779 | 298.949 |
| 7 | 315.798 | 284.552 | 293.806 | 303.678 |
| Median | 303.436 | 299.457 | 301.321 | 312.216 |

Paired median changes were −4.593 ms and +9.871 ms. Worker planning
finished first in four and two pairs. Host load was 4.71–5.02 and
4.33–4.57 on 18 CPUs. Sampled median main-thread CPU changed from
161.86 to 161.81 ms and from 163.12 to 161.37 ms. Median sampled wall
time with two or more busy threads changed from 9.33 to 6.17 ms and
from 9.04 to 6.30 ms. The timed cohorts show mixed latency effects.
Frame mask prefetch remains opt-in, and final blending stays ordered.

All 28 timed launches and four diagnostic launches matched reference
PNG SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight-record replay fingerprints matched in every launch, including
the favicon miss. The executable, AVIF library, adblock helper, archive
and driver hashes stayed pinned. Browser, driver and 3 GiB guard exits
were zero. Peak aggregate timing RSS was 368,984,064 bytes.

### Prepare cold frame glyph strikes on a worker

Commit `780cfb16b` passes the frame's immutable glyph runs to the
coordinator when the document strike cache is empty. The worker
resolves CoreText strikes, groups equivalent runs and selects masks
before handing the draws to raster lanes. The browser thread allocates
the bounded plan before dispatch and constructs the cache keys for
publication at the join. Only the browser thread accesses the document cache.
Frames with existing cache entries keep caller-side strike preparation
and snapshot the cached glyph keys as before.

`VOX_SYNC_FRAME_GLYPH_STRIKES=1` keeps strike preparation on the caller
and still lets the coordinator select cold glyph keys. Both benchmark
settings enable `VOX_PREFETCH_FRAME_GLYPH_MASKS=1`.

The production type check passed. Arena-poisoned tests passed with
worker strikes, caller strikes and fully synchronous planning. They
compare serial pixels, cover empty and warm plans, and keep masks
that ordinary replay publishes while prefetch is in flight.

#### Retained Hacker News text replay

The published `20261125-120409-e0083ee7` browser reproduced the
archived homepage at 1024×768 CSS pixels and 2× scale. Its 332 retained
text draws matched the previous fixture log SHA-256
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
The standalone V `-prod` replay used the canonical fixture loader,
the first 32 eligible runs for prefetch, and `VOX_ARENA_POISON=1`.
It joins immediately and times all 332 draws. This scope excludes
page layout, preceding paint commands and the native window.

The diagnostic pair published 107 masks from four strikes on four
lanes in each mode. Both selected glyph keys off-thread. The candidate
also prepared the strikes off-thread. Seven timed pairs alternated
the modes in fresh processes using the same executable SHA-256
`c6c25989bf381cb5f5fab9d69da68613aeb3a7a190ac968fd6e703833a4a64f2`.

| Pair | Caller submit CPU, ms | Worker submit CPU, ms | Caller raster wall, ms | Worker raster wall, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 1.382 | 0.011 | 10.208 | 9.494 |
| 2 | 1.619 | 0.011 | 9.621 | 8.273 |
| 3 | 1.432 | 0.012 | 9.811 | 9.101 |
| 4 | 1.407 | 0.009 | 9.569 | 9.086 |
| 5 | 1.392 | 0.009 | 9.436 | 10.446 |
| 6 | 1.341 | 0.009 | 8.493 | 8.123 |
| 7 | 1.391 | 0.018 | 9.196 | 8.934 |
| Median | 1.392 | 0.011 | 9.569 | 9.086 |

Median join CPU on the caller was 0.023 → 0.025 ms. The median paired
raster wall change was −0.483 ms and six pairs favored worker strikes.
Host load was 7.27 on 18 CPUs. All 16 replays matched reference RGBA
SHA-256 `66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.
Executable and all 333 captured input hashes stayed pinned. Each
process and the 3 GiB replay guard exited zero. Peak aggregate RSS
was 47,349,760 bytes.

#### Matched production captures

Receipt `20261125-121959-2712ca82` sealed `780cfb16b`, passed startup
smoke and published single-C-unit V `-prod` executable SHA-256
`1b46b97d7f8d7bc2ba4ef14dd5360a42888005a93959eeb89284dc717de069d1`.
The diagnostic confirmed worker strike preparation on the archived
homepage. Both modes published 107 masks from four strikes across
four lanes. All masks were ready at the join, and 98 overlapped
preceding paint commands. Ordinary text ran 192 jobs in 27 batches.
Both captures matched all 30 ordered story IDs.

A separate instrumented pair measured 3,522,391 → 289,107
main-thread instructions for frame prefetch submission and
266,378 → 248,804 for the join. Inclusive native raster replay
measured 276,403,511 → 269,198,018 main-thread instructions. Both
variants use the same run grouping and retain the same per-glyph
raster worker path.

The timing cohorts used fresh launches through the encoded 1024×768
CSS-pixel PNG at 2× scale with JavaScriptCore. Each trial used empty
private profiles and HTTP caches, retained OS filesystem caches and
replayed a 60 ms delay on each logo response. The first cohort began
with worker strikes and the reversed cohort began with caller strikes.

| Pair | Caller, ms | Worker, ms | Reversed caller, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 302.686 | 291.837 | 281.761 | 295.017 |
| 2 | 312.328 | 309.240 | 310.637 | 296.432 |
| 3 | 299.835 | 283.315 | 301.960 | 301.305 |
| 4 | 317.191 | 296.091 | 285.185 | 346.626 |
| 5 | 341.815 | 333.893 | 308.207 | 299.024 |
| 6 | 317.337 | 296.702 | 291.645 | 297.696 |
| 7 | 293.801 | 298.559 | 318.263 | 303.378 |
| Median | 312.328 | 296.702 | 301.960 | 299.024 |

Paired median changes were −10.849 ms and −0.655 ms. The worker
finished first in six and four pairs. Host load ranged from 5.35 to
5.53 and from 5.25 to 5.53 on 18 CPUs. Sampled main-thread CPU
medians changed from 167.64 to 164.58 ms and from 163.13 to 165.72 ms,
respectively. The second cohort has a smaller wall effect and a
61.44 ms regression in one pair. Frame prefetch remains opt-in.

All 28 timed and four diagnostic launches matched reference PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
All eight request and response records matched in each launch,
including the favicon miss. The executable, AVIF library, worker
helper, archive and driver hashes stayed pinned. Browser, driver
and 3 GiB guard exits were zero. Peak aggregate timing RSS was
378,142,720 bytes.

### Open cold frame glyph strikes in parallel

Commit `c172ea42b` lets the cold prefetch coordinator open independent
CoreText strikes on up to four threads. It groups the immutable run
descriptors first, opens fonts in disjoint slots and joins before
selecting or drawing masks. If an open fails or encounters a color
face, it releases the opened fonts and retries collection in run
order so later usable strikes can take the available slots.
`VOX_SERIAL_FRAME_GLYPH_FONT_OPENS=1` keeps the same stages and opens
the strikes in sequence on the coordinator.

The production type check, arena-poisoned tests and ThreadSanitizer
passed. The focused tests compare serial pixels and verify that a
missing first face still admits four usable strikes, including an
eligible run outside the initial four candidates.

#### Retained Hacker News text replay

Receipt `20261125-121959-2712ca82` supplied the archived homepage
capture. Its PNG and all 30 ordered story IDs matched the references.
The 332 retained draws reproduced the fixture log SHA-256
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
The single-C-unit V `-prod` replay used the first 32 eligible runs for
prefetch, joined immediately and drew all 332 runs with a fresh cache.
Both modes used `VOX_ARENA_POISON=1`. The executable SHA-256 was
`526630a063372cbdc6e7acd026815a481de0a676d58763a5c44a46ddc1f1a492`.

In seven instrumented pairs, the candidate opened four strikes from
four distinct threads and the control used one. Both selected and
published 107 masks on four raster lanes. A separate seven-pair cohort
timed the full prefetch and raster intervals with diagnostics off.
Both cohorts alternated their modes in fresh processes.

| Pair | Serial opens, ms | Parallel opens, ms | Serial prefetch, ms | Parallel prefetch, ms | Serial raster, ms | Parallel raster, ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0.429 | 0.218 | 2.062 | 2.001 | 7.749 | 7.684 |
| 2 | 0.296 | 0.223 | 2.246 | 2.032 | 8.133 | 7.976 |
| 3 | 0.260 | 0.252 | 2.048 | 1.933 | 7.964 | 8.002 |
| 4 | 0.233 | 0.213 | 2.111 | 2.091 | 7.958 | 7.794 |
| 5 | 0.360 | 0.209 | 2.083 | 2.075 | 7.786 | 7.924 |
| 6 | 0.236 | 0.231 | 2.196 | 2.062 | 7.939 | 7.941 |
| 7 | 0.280 | 0.234 | 2.133 | 1.957 | 8.150 | 7.767 |
| Median | 0.280 | 0.223 | 2.111 | 2.032 | 7.958 | 7.924 |

The uninstrumented paired median changes were −0.115 ms through
the join and −0.065 ms through all draws. The parallel mode finished
the full replay first in four pairs. Host load was 6.06 on 18 CPUs.
All 28 runs matched the reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.
The binary, the Verdana font files and all 333 captured inputs stayed
pinned. Capture, build, replay and guard exits were zero. The 3 GiB
replay guard recorded 46,907,392 bytes peak aggregate RSS.

#### Matched production captures

Receipt `20261125-123322-d3696956` sealed `c172ea42b`, passed startup
smoke and published the single-C-unit V `-prod` executable SHA-256
`c2873282cbc96bcb93758e4f291a416abf892e6c7f2c2087eac34dcdd7f677a5`.
The production diagnostic confirmed four font-opening threads in the
candidate and one in the control. Opening took 0.084 and 0.046 ms,
respectively, in this instrumented pair. Both modes published all 107
masks before text replay, with 98 jobs overlapping earlier commands.
The remaining text used 192 mask jobs in 27 batches. Neither mode
needed a font fallback, and both captured all 30 story IDs in order.

The timed runs measured fresh launch through the encoded 1024×768
CSS-pixel PNG at 2× scale. They used JavaScriptCore, fresh private
profiles and HTTP caches, retained OS filesystem caches and an
identical 60 ms replay delay on each logo response. The reversed
cohort started with serial opens. Both modes kept frame prefetch on.

| Pair | Serial, ms | Parallel, ms | Reversed serial, ms | Reversed parallel, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 298.440 | 308.796 | 336.723 | 298.348 |
| 2 | 303.119 | 300.846 | 340.442 | 311.624 |
| 3 | 291.822 | 273.490 | 327.780 | 317.201 |
| 4 | 282.928 | 311.074 | 316.720 | 324.823 |
| 5 | 300.561 | 311.509 | 325.025 | 337.724 |
| 6 | 300.731 | 315.757 | 323.313 | 321.711 |
| 7 | 322.433 | 315.325 | 324.637 | 329.010 |
| Median | 300.561 | 311.074 | 325.025 | 321.711 |

Paired median changes were +10.356 ms and −1.602 ms. Parallel opens
finished first in three and four pairs. Host load was 4.68–5.03 and
5.51–6.11 on 18 CPUs. The browser timings show mixed latency effects.
Frame prefetch remains opt-in.

All 28 timed and both diagnostic launches matched reference PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight replay request and response records matched in every run,
including the favicon miss. The executable, AVIF library, adblock
helper, archive and driver hashes stayed pinned. Each browser, driver
and 3 GiB guard exited zero. Peak aggregate timing RSS was
418,168,832 bytes.

### Prefetch later glyph masks during frame replay

Commit `20dab029c` adds a second wave to the cold macOS frame mask
experiment. Enable `VOX_PREFETCH_FRAME_GLYPH_MASKS=1` and
`VOX_PREFETCH_TAIL_FRAME_GLYPH_MASKS=1` to use it. The first wave still
examines up to 32 eligible runs within the first 160 paint commands.
The second wave extends the search to 128 runs within 512 commands.
The coordinator deduplicates keys across both waves and uses up to
four strikes and 256 masks. It starts the second wave after drawing
the first. The browser joins that wave at or after its first text
command and releases the fonts after both waves finish.

The production type check, arena-poisoned tests and ThreadSanitizer
passed. The focused checks cover duplicate keys across waves,
separate publication, a skipped prefix, and discarding a pending
wave at the end of replay. The second wave's pixels match serial
replay.

#### Retained Hacker News text replay

Receipt `20261125-123322-d3696956` supplied the archived homepage
capture. Its PNG and all 30 ordered story IDs matched the references.
The 332 retained draws reproduced fixture log SHA-256
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
The standalone single-C-unit V `-prod` replay used `VOX_ARENA_POISON=1`
and a fresh glyph cache per process. It joined the first wave before
draw 1 and joined the second after the first 32 eligible draws.

The isolated diagnostic retained 107 first-wave masks in both modes.
All 48 additional masks overlapped the interval between first and
second publication. Ordinary raster work went from 192 mask jobs in
27 batches to 158 jobs in 23 batches. Seven timed pairs alternated the
modes across fresh processes with one executable SHA-256
`d7dc4a526416d144d438ef191d749461ee281355dba62cc2ec7127ffa297e330`.

| Pair | One wave through first join, ms | Two waves through first join, ms | One wave through all draws, ms | Two waves through all draws, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 2.052 | 2.046 | 7.853 | 7.328 |
| 2 | 1.943 | 2.043 | 7.866 | 7.517 |
| 3 | 1.975 | 2.066 | 7.694 | 7.345 |
| 4 | 1.965 | 2.313 | 7.669 | 7.575 |
| 5 | 2.076 | 2.079 | 7.746 | 7.447 |
| 6 | 1.961 | 2.000 | 7.531 | 7.497 |
| 7 | 2.042 | 2.129 | 7.764 | 7.481 |
| Median | 1.975 | 2.066 | 7.746 | 7.481 |

Paired median wall time rose 0.088 ms through the first join and
fell 0.299 ms through all draws. The full two-wave replay finished
first in all seven pairs. Host load was 4.68 on 18 CPUs. Every replay
matched reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.
The executable, font files and 333 captured input hashes stayed
pinned. Capture, build, replay and guard exits were zero. Peak
aggregate replay RSS was 46,858,240 bytes under the 3 GiB guard.

#### Matched production captures

Receipt `20261125-124903-d0b9c4b8` sealed `449b64ee7`, passed startup
smoke and published single-C-unit V `-prod` executable SHA-256
`9b3d5850b3fc89ea579000c61e1cfb12bea1f1728e1995c6412b8823a00f3120`.
The candidate published 107 masks in the first wave and 48 additional
masks across four lanes in the second. Both waves were ready at their
joins. The diagnostic reported no second-wave jobs overlapping text
after the first publication. Ordinary text issued 158 jobs in 23
batches with two waves and 192 jobs in 27 batches with one. Both
diagnostic captures matched the 30 ordered story IDs.

In a separate instrumented pair, text replay went from 127,446,216
to 120,688,642 main-thread instructions. Prefetch submission grew
from 299,853 to 822,597 and the combined joins grew from 269,408 to
400,394 instructions. Inclusive native raster replay went from
277,063,960 to 273,450,923 instructions.

The timing cohorts used fresh launches through the encoded document
PNG at 1024×768 CSS pixels and 2× scale. Both variants used
JavaScriptCore, private empty profiles and HTTP caches, retained OS
filesystem caches and a 60 ms replay delay on each logo response.
The first cohort started with two waves and the reversed cohort
started with one.

| Pair | One wave, ms | Two waves, ms | Reversed one, ms | Reversed two, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 317.704 | 314.652 | 311.188 | 323.488 |
| 2 | 305.075 | 329.590 | 312.272 | 314.432 |
| 3 | 308.150 | 324.109 | 331.927 | 320.808 |
| 4 | 294.797 | 298.392 | 319.549 | 308.799 |
| 5 | 316.963 | 299.217 | 314.352 | 315.195 |
| 6 | 337.973 | 305.589 | 316.327 | 308.825 |
| 7 | 317.082 | 310.007 | 294.372 | 343.239 |
| Median | 316.963 | 310.007 | 314.352 | 315.195 |

The paired median change was −3.052 ms and +0.843 ms. Two waves
finished first in four and three pairs, respectively. Host load was
5.15–5.40 and 5.37–5.42 on 18 CPUs. Sampled median main-thread CPU
changed from 175.81 to 170.37 ms and from 176.53 to 177.78 ms.
The full-page timings varied across trials. The second wave remains
opt-in.

All 28 timed and four diagnostic launches matched reference PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight replay request and response records matched in every run,
including the favicon miss. The executable, AVIF library, adblock
helper, archive and driver hashes stayed pinned. Browser, driver and
3 GiB guard exits were zero. Peak aggregate timing RSS was
373,506,048 bytes.

### Overlap glyph mask prefetch with native frame setup

Commit `840390f1a` lets cold frame prefetch borrow the immutable f64
positions from retained glyph runs. The coordinator folds the baseline
into float32 coordinates with the same rounding used by ordinary
replay. It can start after canvas-bounds submission, before native
viewport planning and canvas setup. The browser still publishes masks
at the text replay boundaries. A scroll-reuse hit discards the batch
after joining its work.

`VOX_EARLY_FRAME_GLYPH_PREFETCH=1` selects the early submission when
the existing frame prefetch experiment is enabled. It uses the cold
sRGB setup path with a background canvas-bounds batch. Warm frames use
prepared positions at the ordinary submission point.

The production type check, arena-poisoned tests and ThreadSanitizer
passed. The raw-position test folds a fractional baseline and matches
every strike key and mask against prepared positions. A diagnostic on
the preceding production executable (`9b3d5850b3fc89ea579000c61e1cfb12bea1f1728e1995c6412b8823a00f3120`)
confirmed that all 443 canvas bounds ran off-thread on four lanes.
That run matched the reference PNG and all 30 ordered story IDs.

#### Matched production captures

Receipt `20261125-130257-647367d1` sealed `840390f1a`, passed startup
smoke and published single-C-unit V `-prod` executable SHA-256
`023fcab30a49d36fcc0f38d7aef0c0e73c699247c9bebf3269001c86b4d1e297`.
The diagnostic observed 55 mask jobs overlapping native frame setup
with early submission and zero with the later submission. Both
variants computed 443 canvas bounds on four workers and classified 60
commands as outside the canvas. Both published 107 masks in the first
wave and 48 in the second. The two waves were ready when joined.
Ordinary text issued 158 jobs in 23 batches, and the two captures
matched all 30 ordered story IDs.

A separate instrumented pair measured 6,970,529 → 7,757,777 inclusive
main-thread instructions for raster setup and 834,749 → 924,478 for
prefetch submission. Inclusive native raster replay measured
272,139,671 → 273,072,390 instructions. Early submission shifts the
timing of mask drawing while adding some browser-thread preparation.

The timing cohorts used fresh launches through the encoded document
PNG at 1024×768 CSS pixels and 2× scale. Both variants enabled frame
prefetch and its second wave, used JavaScriptCore, fresh private
profiles and HTTP caches, retained OS filesystem caches, and replayed
a 60 ms delay on each logo response. The first cohort began with early
submission. The reversed cohort began with later submission.

| Pair | Later, ms | Early, ms | Reversed later, ms | Reversed early, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 337.819 | 313.214 | 316.004 | 316.060 |
| 2 | 323.089 | 303.508 | 321.437 | 321.160 |
| 3 | 305.002 | 318.700 | 318.294 | 317.358 |
| 4 | 321.854 | 310.306 | 324.477 | 317.173 |
| 5 | 304.475 | 313.150 | 311.395 | 326.964 |
| 6 | 305.646 | 323.833 | 319.774 | 303.225 |
| 7 | 315.910 | 303.415 | 311.636 | 300.154 |
| Median | 315.910 | 313.150 | 318.294 | 317.173 |

Paired median changes were −11.548 ms and −0.936 ms. Early submission
finished first in four and five pairs. Host load ranged from 4.69 to
6.07 and from 6.07 to 6.93 on 18 CPUs. Sampled median main-thread CPU
changed from 171.72 to 169.75 ms and from 174.59 to 177.20 ms. The
launch timing effect varied across the two cohorts. Early prefetch
remains opt-in.

All 28 timed and four diagnostic launches matched reference PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight replay request and response records matched in every run,
including the favicon miss. The executable, AVIF library, adblock
helper, archive and driver hashes stayed pinned. Browser, driver and
3 GiB guard exits were zero. Peak aggregate timing RSS was
374,390,784 bytes.

### Full frame prefetch compared with production defaults

The same `023fcab3…e297` production executable ran with all three
frame prefetch switches enabled and with its default replay settings.
The enabled diagnostic published 155 masks across two waves, with 18
jobs overlapping native setup. Ordinary replay issued 158 jobs in 23
batches with frame prefetch and 249 jobs in 34 batches at the default.
Both launches matched all 30 ordered story IDs.

In a separate instrumented pair, inclusive native raster replay on
the browser thread went from 286,940,279 to 272,777,369 instructions.
Text leaf replay went from 145,364,085 to 121,788,467 instructions.
Prefetch submission and joins accounted for 1,263,738 instructions.

Two seven-pair cohorts alternated fresh processes at 1024×768 CSS pixels
and 2× capture scale. Each used JavaScriptCore, private empty profiles
and HTTP caches, and a 60 ms replay delay on the logo responses.
The interval ran from launch through the encoded document PNG. OS
filesystem caches were retained. The reversed cohort started with the
default.

| Pair | Default, ms | Prefetch, ms | Reversed default, ms | Reversed prefetch, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 289.168 | 301.558 | 295.476 | 288.408 |
| 2 | 295.799 | 310.093 | 296.778 | 322.524 |
| 3 | 310.353 | 319.401 | 318.932 | 316.903 |
| 4 | 309.420 | 315.038 | 323.685 | 317.749 |
| 5 | 308.613 | 315.472 | 308.659 | 303.291 |
| 6 | 315.461 | 298.987 | 330.871 | 309.911 |
| 7 | 295.108 | 315.039 | 325.149 | 323.439 |
| Median | 308.613 | 315.038 | 318.932 | 316.903 |

The paired medians were +9.048 ms and −5.368 ms, with prefetch
finishing first in one and six pairs. Host load ranged from 4.81 to 5.06
and from 4.91 to 5.32 on 18 CPUs. Frame prefetch remains opt-in because
the launch measurements varied across cohorts.

All 28 timed and four diagnostic launches reproduced the unchanged
reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight replay records and the pinned executable, library, helper,
fixture and driver hashes matched throughout. Browser, driver and 3 GiB
guard exits were zero. Peak aggregate timing RSS was 370,262,016 bytes.

### Batch later glyph mask misses during retained text replay

Commit `086d79a4c` lets a retained macOS text run schedule another
parallel mask batch after the previous scan ends. Each scan examines
at most 48 glyphs and publishes up to 16 masks on the browser thread.
A later cache miss beyond that scan can start the next batch. The
ordinary glyph loop keeps the paint order and handles individual
misses inside a window. The experimental backdrop pipeline also
carries the end of its first scan into ordinary replay.
`VOX_SINGLE_GLYPH_MASK_BATCH=1` selects the previous one-batch control.

The production type check, arena-poisoned tests and ThreadSanitizer
passed. A long focused run has too few misses in its first window
and still draws 25 masks across two later batches. Both modes match
the serial reference pixels. The pinned glyph differential completed
1,962 exact comparisons and 38 declines in 2,000 cases.

#### Retained Hacker News text replay

The published executable `f7ab6eb5…6ba0` captured 332 retained glyph
draws from the archived homepage. The capture reproduced the reference
PNG and fixture log SHA-256
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
The canonical glyph replay driver used a fresh cache and
`VOX_ARENA_POISON=1` on single-C-unit V `-prod` executable SHA-256
`ff885637d0a173459d0c7750310303b86e967fc3b3b941f19a6f48e98a4eec6f`.
The timer covers CPU text rasterization of all captured runs.

The diagnostic issued 249 mask jobs in 34 batches with the one-batch
control. The rolling windows issued 277 jobs in 37 batches. The three
follow-up batches accounted for 16, five and seven jobs. Seven timed
pairs alternated the modes in fresh processes.

| Pair | One batch, ms | Rolling windows, ms |
| ---: | ---: | ---: |
| 1 | 9.639 | 10.553 |
| 2 | 10.077 | 9.591 |
| 3 | 9.734 | 8.747 |
| 4 | 9.450 | 8.595 |
| 5 | 9.535 | 8.979 |
| 6 | 10.965 | 8.633 |
| 7 | 9.016 | 8.920 |
| Median | 9.639 | 8.920 |

Rolling windows finished first in six pairs and saved 0.556 ms in the
paired median. Host load was 6.28 on 18 CPUs. Each replay matched
reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.
Executable, font and captured input hashes stayed pinned. Browser,
build, replay and guard exits were zero. Peak replay RSS under the
3 GiB guard was 45,563,904 bytes.

#### Matched production captures

Receipt `20261125-131846-a6067da7` sealed `d0cd66c78` with the rolling
windows, passed startup smoke and published single-C-unit V `-prod`
executable SHA-256
`4575782cafab004239ad56713933582762b7bc3f6806e876129c061e8e1cbfac`.
The diagnostic reproduced 34 batches and 249 jobs with the single-batch
control, and 37 batches and 277 jobs with rolling windows. Three
follow-up batches drew the same 28 masks as in standalone replay.
Both launches matched the 30 ordered story IDs.

A separate instrumented pair measured 145,450,649 → 142,147,656
browser-thread text replay instructions and 288,517,907 → 284,886,172
inclusive native raster replay instructions.

Both timing cohorts measured fresh launch through the encoded PNG at
1024×768 CSS pixels and 2× scale. They used JavaScriptCore, private
empty profiles and HTTP caches, retained OS filesystem caches and
a 60 ms delay on replayed logo responses. The first cohort started
with rolling windows and the reversed cohort with one batch.

| Pair | One batch, ms | Rolling windows, ms | Reversed one batch, ms | Reversed rolling, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 306.335 | 317.587 | 300.852 | 291.444 |
| 2 | 301.819 | 310.338 | 306.061 | 312.025 |
| 3 | 309.300 | 304.784 | 314.872 | 291.080 |
| 4 | 296.879 | 294.552 | 293.321 | 309.855 |
| 5 | 317.743 | 289.594 | 308.604 | 302.649 |
| 6 | 318.095 | 279.101 | 301.189 | 312.051 |
| 7 | 307.518 | 295.214 | 314.504 | 303.792 |
| Median | 307.518 | 295.214 | 306.061 | 303.792 |

Paired median changes were −4.516 ms and −5.955 ms, with rolling
windows finishing first in five and four pairs. Host load ranged from
4.91 to 5.53 and from 5.08 to 5.55 on 18 CPUs. Sampled browser-thread
CPU medians went from 164.80 to 161.54 ms and from 160.54 to 159.30 ms.

All 28 timed and four diagnostic launches matched reference PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight request and response records matched in every run, including
the favicon miss. Executable, library, helper, archive and driver
hashes stayed pinned throughout. Browser, driver and 3 GiB guard exits
were zero. Peak aggregate timing RSS was 374,718,464 bytes.

### Schedule short retained text runs by clipped pixel workload

Commit `f67d4df3e` lets short retained macOS text runs use the existing
striped mask blender when their device clip can hold 4,096 pixels. The
blender budgets one lane per 2,048 clipped mask pixels, up to four
lanes, and stays serial below two lanes. Long runs remain eligible for
batch collection, including overlapping glyphs in a small clip. The
workers retain paint order within each disjoint stripe.
`VOX_PREVIOUS_GLYPH_BLEND_BUDGET=1` restores the 24-glyph collection
minimum and the previous 4,096-pixel budget per lane.

The focused test used eight overlapping glyphs, a clipped edge,
fractional paint and row padding. It matched the individually drawn
reference and logged four blend participants over 14,468 mask pixels.
The arena-poisoned focused tests, legacy-budget control, ThreadSanitizer,
and production browser type check passed. The pinned glyph differential
returned 1,963 exact cases and 37 declines. A broad differential started
with the wrong case selector and reached the 3 GiB guard. The focused
retry used the glyph selector and exited zero. A preliminary unit run
used V `-prod`, which removed assertions, including preparation calls
inside assertions. The assertion-enabled rerun completed seven tests.

#### Hacker News retained text replay

The fresh dump on executable `4575782cafab…cbfac` used the archived
homepage and matched the reference PNG. The capture contained 332
retained draws and reproduced the input log SHA-256
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
Both replay modes used a fresh glyph cache and arena poisoning on
the same single-C-unit V `-prod` executable, SHA-256
`0fa03d4094dc4b7717cf10463bf2c12bae0560a99fbcf82387347f0a69e40621`.

The earlier budget blended 811 masks and 234,733 clipped mask pixels
in 17 parallel batches. The new budget blended 974 masks and 277,052
pixels in 25 batches. The eight extra batches held 16 to 23 glyphs
and each ran on two or three threads. The other batches used up to
four threads. All captures reproduced reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.

| Pair | Pilot previous, ms | Pilot new, ms | Pinned previous, ms | Pinned new, ms | Reversed previous, ms | Reversed new, ms |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 9.589 | 8.934 | 9.342 | 9.866 | 8.608 | 9.053 |
| 2 | 9.232 | 9.204 | 8.739 | 8.574 | 9.047 | 8.341 |
| 3 | 8.927 | 8.964 | 8.466 | 8.933 | 8.255 | 8.523 |
| 4 | 8.761 | 9.188 | 10.028 | 10.012 | 8.346 | 8.312 |
| 5 | 8.300 | 9.426 | 11.266 | 11.549 | 8.917 | 9.088 |
| 6 | 8.596 | 8.284 | 9.125 | 11.719 | 8.412 | 8.432 |
| 7 | 9.640 | 8.493 | 9.489 | 9.047 | 9.829 | 8.831 |
| Median | 8.927 | 8.964 | 9.342 | 9.866 | 8.608 | 8.523 |

The pilot's median paired change was −0.027 ms. The two pinned cohorts
recorded +0.282 and +0.019 ms with three wins each. One-minute host
load was 5.84 on 18 CPUs throughout the pinned run. Executable, driver,
captured backdrops and font hashes remained fixed in the pinned runs.
All replay processes and guards exited zero. The pinned run peaked
at 48,037,888 bytes under its 3 GiB guard.

#### Matched production captures

Receipt `20261125-133450-35c1b22c` sealed `f67d4df3e`, passed startup
smoke and published single-C-unit V `-prod` executable SHA-256
`dcbf80bcd447a22cccab9dec1709ca927f7fb7e773f21f825fd9ffda2fce382f`.
The native AVIF library remained
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
The separate diagnostic pair reproduced the replay's batch, mask and
pixel counts. The previous budget used multiple threads in all 17
scheduled batches. The new budget used multiple threads in 24 of 25
batches. The system dispatch queue executed both stripes of one
4,822-pixel batch on the same thread. Both diagnostics matched the
archived page URL, ready state, viewport and 30 ordered story IDs.

The instrumented pair recorded 142,993,066 → 139,789,214 browser-thread
text replay instructions and 289,373,388 → 288,978,982 inclusive native
raster replay instructions.

The unprofiled cohorts alternated the previous and new budgets on the
same executable. The reversed cohort started with the previous budget.
Each trial measured fresh launch through completion of a 1024×768 CSS
pixel document PNG at 2×, with JavaScriptCore, empty private profiles
and HTTP caches, retained OS filesystem caches and 60 ms of replay delay
per logo response.

| Pair | Previous, ms | New, ms | Reversed previous, ms | Reversed new, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 309.882 | 314.714 | 328.005 | 321.755 |
| 2 | 299.872 | 310.499 | 330.447 | 343.048 |
| 3 | 345.902 | 303.931 | 336.979 | 389.971 |
| 4 | 357.564 | 356.695 | 414.600 | 403.732 |
| 5 | 345.929 | 354.955 | 435.167 | 382.735 |
| 6 | 336.380 | 317.966 | 393.992 | 368.270 |
| 7 | 322.080 | 304.362 | 379.062 | 409.547 |
| Median | 336.380 | 314.714 | 379.062 | 382.735 |

Median paired changes were −0.869 and −6.250 ms, with four wins in each
cohort. Sampled browser-thread CPU medians were 202.69 → 175.93 ms and
239.65 → 240.52 ms. One-minute load ranged from 8.33 to 8.70 and 8.32 to
8.53 on 18 CPUs. The trial ranges and the replay timings leave the
end-to-end speed difference uncertain.

All 28 timed and two diagnostic captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The eight replay request and response records, executable, library,
helper, archive and driver hashes matched throughout. All browser and
driver exits were zero. The 3 GiB guard exited zero at a peak aggregate
RSS of 385,990,656 bytes.

### Dispatch retained glyph stripes explicitly

Commit `5a713c162` dispatches every stripe except the last to raster
workers and draws the last stripe on the caller. The dispatch group
joins before the caller releases the masks or uses the next paint
command. Each stripe blends its pixels in the original glyph order.
`VOX_GLYPH_BLEND_DISPATCH_APPLY=1` selects the previous scheduler,
which could execute an entire batch on one thread.

The focused 4,820-pixel test checked the caller and worker identities
and all output bytes. Ten arena-poisoned tests, the legacy scheduling
control, ThreadSanitizer and the production browser type check passed.
The pinned glyph differential returned 1,963 exact cases and 37 declines
under the 3 GiB guard.

#### Hacker News retained text replay

Production executable `dcbf80bcd447…ce382f` captured 332 retained draws
from the archived homepage and matched the document reference. The
captured input log SHA-256 was
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
The same single-C-unit V `-prod` replay executable in both modes had
SHA-256 `000fbf75d6ab29f55f9d2773dc90067158d94d2dcbc4220a8cb4c5f74cbe39e3`.
Each replay used fresh processes, a fresh strike cache and arena poisoning.

In two diagnostics per mode, all 25 eligible batches used two to four
threads with either scheduler. Each replay processed the same 974 masks
and 277,052 clipped mask pixels in those batches. All 32 replays matched
reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.

| Pair | Previous, ms | Explicit, ms | Reversed previous, ms | Reversed explicit, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 8.752 | 8.362 | 8.331 | 8.283 |
| 2 | 8.183 | 8.234 | 8.173 | 8.543 |
| 3 | 8.355 | 8.303 | 8.247 | 8.264 |
| 4 | 8.165 | 8.604 | 8.044 | 8.364 |
| 5 | 8.448 | 8.261 | 8.385 | 8.358 |
| 6 | 8.275 | 8.651 | 8.421 | 8.388 |
| 7 | 8.378 | 8.445 | 8.310 | 8.434 |
| Median | 8.356 | 8.362 | 8.310 | 8.364 |

Median paired changes were +0.051 and +0.017 ms. Explicit submission
finished first in three pairs per cohort. One-minute host load was
5.96 on 18 CPUs. Executable, fixture, font and driver hashes stayed
fixed. Every replay and the 3 GiB guard exited zero. Peak aggregate
RSS was 58,261,504 bytes.

#### Matched production captures

Receipt `20261125-134515-75117d77` sealed `5a713c162`, passed startup
smoke and published single-C-unit V `-prod` executable SHA-256
`e6de499528e972179c46e586aed7c1269ce07a7436bac4fc4e428a9b35fe7405`.
Four fresh diagnostic captures per mode verified the URL, ready state,
viewport and all 30 ordered story IDs. Both modes used two to four
threads in all 100 scheduled batches, including the 4,822-pixel batch
that had used one thread in an earlier production diagnostic.

| Diagnostic pair | Previous text instructions | Explicit text instructions | Previous native raster instructions | Explicit native raster instructions |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 138,410,727 | 138,460,594 | 287,553,815 | 288,174,083 |
| 2 | 138,738,228 | 137,742,493 | 285,950,138 | 284,609,600 |
| 3 | 138,464,229 | 137,767,986 | 288,128,661 | 283,795,477 |
| 4 | 137,709,021 | 137,407,964 | 285,742,630 | 279,844,503 |

Text and inclusive native raster instructions come from the browser
thread in separately instrumented runs. The unprofiled cohorts alternated
both schedulers. The reversed cohort started with the previous scheduler.
Each fresh process used JavaScriptCore, a private empty profile and HTTP
cache, retained OS filesystem caches and a 60 ms delay per replayed logo
response. Timing spans launch through the completed 1024×768 CSS-pixel
document PNG at 2× scale.

| Pair | Previous, ms | Explicit, ms | Reversed previous, ms | Reversed explicit, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 320.891 | 307.869 | 326.208 | 324.124 |
| 2 | 327.580 | 302.195 | 321.603 | 326.062 |
| 3 | 306.555 | 308.739 | 326.002 | 310.421 |
| 4 | 311.969 | 301.092 | 324.631 | 312.407 |
| 5 | 332.253 | 300.185 | 316.099 | 351.904 |
| 6 | 340.280 | 354.685 | 370.773 | 386.424 |
| 7 | 317.163 | 352.316 | 370.446 | 357.222 |
| Median | 320.891 | 307.869 | 326.002 | 326.062 |

Median paired changes were −10.878 and −2.085 ms, with four wins in
each cohort. Sampled browser-thread CPU medians were 177.08 → 173.66 ms
and 187.67 → 200.03 ms. Host load was 6.73–7.23 and 7.05–7.85 on 18
CPUs. The pair ranges and isolated replay timings leave the effect on
elapsed time uncertain.

All 28 timed and eight diagnostic captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
Every trial reproduced eight request and response records, including the
favicon miss. Executable, native library, helper, archive and driver
hashes stayed fixed. Browser, driver and 3 GiB guard exits were zero.
Peak aggregate RSS was 398,606,336 bytes.

### Draw short cold glyph-mask batches on workers

Commit `20ce6a8d6` allows retained macOS text replay to batch two or
three distinct cold A8 masks. A raster worker draws the first range
and the caller draws the rest. The caller joins before publishing
to the strike cache and blending in glyph order. Larger batches keep
their two-key-per-lane minimum. The optional backdrop pipeline keeps
its four-key entry threshold. `VOX_GLYPH_MASK_BATCH_MIN_FOUR=1`
selects the previous ordinary-replay policy.

The focused test checks two- and three-key windows against the serial
CoreText masks at fractional positions. Nine arena-poisoned tests,
the four-key control, ThreadSanitizer and the production browser
type check passed. The pinned glyph differential found 1,963 exact
cases and 37 declines under the 3 GiB guard.

#### Hacker News retained text replay

Production executable `e6de499528e97…7405` captured 332 retained draws
and matched the archived homepage reference. The captured input log
had SHA-256
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
Both replay modes used the same single-C-unit V `-prod` executable
with SHA-256 `137cdbe5d2643d7d2c21967cad743dce15add67737a88a9804e1e56d62c05709`.
Every process started with a fresh strike cache and arena poisoning.

The four-key policy dispatched 277 masks in 37 batches. The two-key
policy dispatched 391 masks in 84 batches. There were 27 new two-key
and 20 new three-key batches, including two later windows in their runs.
All 47 additional batches used two threads. All 30 pinned replays and
the separate diagnostic pilot matched RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.

| Pair | Four keys, ms | Two keys, ms | Reversed four keys, ms | Reversed two keys, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 15.933 | 16.478 | 16.159 | 12.692 |
| 2 | 18.207 | 14.760 | 15.141 | 11.973 |
| 3 | 14.155 | 14.168 | 16.330 | 15.989 |
| 4 | 16.596 | 15.451 | 14.139 | 11.923 |
| 5 | 15.589 | 16.440 | 12.022 | 15.415 |
| 6 | 16.946 | 14.478 | 16.663 | 15.788 |
| 7 | 13.900 | 15.672 | 14.491 | 16.909 |
| Median | 15.933 | 15.451 | 15.141 | 15.415 |

The paired medians were +0.013 and −0.875 ms with three and five
wins. One-minute host load ranged from 19.93 to 20.70 on 18 CPUs.
The changes in replay time varied across pairs under this contention.
Executable, driver, fixture and font hashes remained fixed in the
pinned runs. All replay processes and 3 GiB guards exited zero.
Peak aggregate RSS was 59,719,680 bytes.

Two more cohorts used the same executable and capture at one-minute
host load 9.52–9.65. Their paired medians were +0.656 and −0.131 ms,
with three and four wins. All 30 captures were exact again, including
the diagnostic pair. The executable, inputs and driver stayed pinned
through these runs. Replay and guard exits were zero. Peak
aggregate RSS was 59,424,768 bytes.

| Pair | Four keys, ms | Two keys, ms | Reversed four keys, ms | Reversed two keys, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 11.653 | 10.688 | 13.445 | 11.165 |
| 2 | 12.577 | 12.365 | 13.170 | 14.752 |
| 3 | 11.004 | 14.894 | 13.534 | 14.183 |
| 4 | 11.680 | 13.356 | 13.158 | 12.869 |
| 5 | 11.245 | 11.900 | 11.997 | 11.491 |
| 6 | 11.406 | 12.943 | 12.471 | 12.340 |
| 7 | 20.567 | 15.424 | 12.252 | 12.466 |
| Median | 11.653 | 12.943 | 13.158 | 12.466 |

#### Matched production captures

The managed builder retained the previous bundle when shared source
inputs changed before C preprocessing in receipts
`20261125-135632-45f410ad` and `20261125-140017-37790127`. Receipt
`20261125-140406-fd3faa82` sealed `d0282c4b7` with the short batches,
passed startup smoke and published single-C-unit V `-prod` executable
SHA-256 `0a575bf30871e915614c76e2390bcad07866431fb07297b366b8a97f33a0f311`.

Two diagnostic pairs reproduced 37 batches and 277 jobs in the
four-key control, and 84 batches and 391 jobs with the two-key minimum.
All 47 additional batches used two threads in both launches.
The page URL, ready state, viewport and all 30 ordered story IDs
matched in the worker and instruction diagnostics.

Two separate browser-thread counter pairs ran with mask logging disabled.

| Diagnostic pair | Four-key text instructions | Two-key text instructions | Four-key native raster instructions | Two-key native raster instructions |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 137,710,695 | 131,766,581 | 280,376,865 | 278,533,202 |
| 2 | 137,821,297 | 132,292,158 | 279,225,241 | 274,067,593 |

The unprofiled trials ran from fresh launch through the completed
1024×768 CSS-pixel document PNG at 2× scale. They used JavaScriptCore,
private empty profiles and HTTP caches, retained OS filesystem caches
and a 60 ms delay per replayed logo response. Each cohort alternated the
two settings on the same executable. The reversed cohort started with
the four-key control.

| Pair | Four keys, ms | Two keys, ms | Reversed four keys, ms | Reversed two keys, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 307.340 | 310.273 | 330.835 | 293.077 |
| 2 | 305.926 | 285.195 | 328.017 | 315.557 |
| 3 | 297.889 | 300.458 | 293.239 | 337.145 |
| 4 | 314.979 | 323.104 | 307.823 | 304.292 |
| 5 | 315.649 | 332.202 | 307.486 | 308.260 |
| 6 | 301.530 | 289.307 | 321.880 | 316.897 |
| 7 | 303.663 | 297.371 | 314.590 | 309.112 |
| Median | 305.926 | 300.458 | 314.590 | 309.112 |

Paired median changes were +2.568 and −4.983 ms, with three and five
wins. Sampled browser-thread CPU medians were 156.91 → 160.02 ms and
167.92 → 166.03 ms. One-minute load ranged from 3.76 to 3.90 and 3.54
to 4.09 on 18 CPUs. The elapsed changes varied between cohorts.

All 28 timed and eight diagnostic captures matched the unchanged PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
Every launch reproduced eight request and response records, including the
favicon miss. Executable, library, helper, archive and driver hashes
stayed fixed. All browsers, the driver and the 3 GiB guard exited zero.
Peak aggregate RSS was 397,934,592 bytes.

### Submit larger cold glyph-mask ranges explicitly

Before commit `5a7e9f5f7`, larger ordinary cold-mask batches used `dispatch_apply`, whose
scheduler can run multiple ranges inline. The retained renderer now
submits background ranges explicitly and draws the final range on
the caller for every eligible batch. It keeps the existing lane
budget and joins before publishing the masks. If submission fails,
the existing per-glyph lookup draws the missing masks.
`VOX_GLYPH_MASK_DISPATCH_APPLY=1` restores the previous scheduler for
batches of four or more. The diagnostics record how many jobs ran
on the caller.

#### Bitmap context reuse experiment

The production baseline `0a575bf30871…f311` captured 332 retained
draws on the archived Hacker News homepage. Its PNG reproduced
the reference, and the glyph input log SHA-256 was
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
Reusing one same-size CoreGraphics context per worker range avoided
70 context creations in the replay. The focused test matched
fresh-context masks across subpixel origins and smoothing modes,
and both variants matched the reference RGBA. Each comparison used
its own single-C-unit V `-prod` executable in both modes, a fresh
strike cache and arena poisoning.

| Experiment | Host one-minute load on 18 CPUs | First paired median | Reversed paired median | Wins |
| --- | ---: | ---: | ---: | ---: |
| All ranges | 73.21–77.38 | +1.125 ms | +2.532 ms | 2/7, 1/7 |
| Excluding single-glyph ranges | 106.26–109.37 | +0.474 ms | +6.202 ms | 3/7, 0/7 |

The executable SHA-256 values were
`7b7d6949d9544be6d09bb5aeb374b51c54568f372e2c39ad7e41a65679090f04`
and `bd9bed8d51c3b043d6f0741c586a24cb0d438d0afeff3d996823485c58411015`.
Each cohort kept its executable, captured inputs, fonts and driver
hashes pinned. Every isolated process and guard exited zero. The two
3 GiB runs peaked at 59,539,456 and 59,785,216 bytes. Both implementations
were withdrawn after all four paired medians increased. Explicit
dispatch uses the existing per-glyph bitmap code.

#### Explicit dispatch in retained text replay

The single-C-unit V `-prod` replay executable had SHA-256
`50730163349d9db529f98247152b3e4d18dc946310dab39967aaf2acf7608012`.
Both modes drew 391 masks across 84 batches, including 37 larger
batches. Both used multiple threads in every sampled larger batch.
The old scheduler drew 86 of 277 masks from the larger batches on
the caller. Explicit dispatch drew 101 there. The explicit scheduler
reserves a worker range in every eligible batch, even when the
system would choose inline execution.

Both alternating cohorts used fresh processes and strike caches
with arena poisoning. Every replay matched reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.

| Pair | Previous, ms | Explicit, ms | Reversed previous, ms | Reversed explicit, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 17.741 | 17.895 | 17.501 | 20.457 |
| 2 | 17.860 | 23.975 | 44.206 | 20.944 |
| 3 | 21.048 | 20.572 | 23.949 | 19.276 |
| 4 | 18.821 | 17.967 | 20.280 | 22.500 |
| 5 | 22.556 | 21.587 | 19.498 | 16.967 |
| 6 | 21.139 | 27.891 | 18.904 | 19.111 |
| 7 | 19.112 | 19.130 | 16.419 | 20.024 |
| Median | 19.112 | 20.572 | 19.498 | 20.024 |

The paired medians were +0.018 and +0.207 ms, with three wins per cohort.
Host one-minute load was 67.69–67.92 on 18 CPUs. Inputs stayed pinned,
every replay exited zero, and the guard for the focused tests, build
and replays exited zero at a peak aggregate RSS of 600,096,768 bytes.

Ten arena-poisoned tests passed, including a four-mask case that
verified caller and worker identities and compared the published
masks with serial CoreText output. ThreadSanitizer passed. The pinned
2,000-case glyph differential returned 1,963 exact cases and 37
declines, with both the suite and guard exiting zero. An earlier
focused attempt hit a full workspace volume before execution. The
successful runs followed cleanup of the completed experiment artifacts.

The full-page comparison was deferred while the guard was occupied by
single-C-unit production receipt `20261125-141127-f26f0f12`, which
sealed before the scheduler change. The commit hook queued the new
source for the shared builder. The available production executable
served as the archived text capture baseline.

#### Previous scheduler on the archived homepage

The completed `20261125-141127-f26f0f12` executable, SHA-256
`3b23dceb917896c9fe16aa8d6b5485dfb53786ed4ef3d1cd07d8104777c4327a`,
reproduced the single-thread case. One of its 37 larger batches
executed all four masks on one thread. The other 36 batches used two
to four threads. The launch matched the 30 ordered story IDs, the eight
replay records and the reference PNG. One-minute host load was 85.02 on
18 CPUs. The browser and the 3 GiB guard exited zero. This diagnostic
used the published baseline and supplies no cross-build timing result.

The first build with the scheduling change, receipt
`20261125-142907-1cde9348`, exited before linking after a compiler
cache object was missing. The manager retained the previous published
bundle and a new managed request used the same single-C-unit V `-prod`
build options. Retry receipt `20261125-143707-1e48ee6c` rejected
changed checkout inputs before C preprocessing. Neither receipt
produced a timed browser.

#### Matched production captures

Receipt `20261125-144341-7c04b73d` sealed `ec597a062` with explicit
dispatch, passed startup smoke and published single-C-unit V `-prod`
executable SHA-256
`4812830ce1912f8bb86e16b97dd4af79b5070c1857201732ad53f1cccd0d26bc`.
The native AVIF library SHA-256 was
`ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202`.
Both schedulers ran on that executable.

Each diagnostic drew 391 glyph masks in 84 batches, including 277
masks in 37 larger batches. One larger batch in the second control
executed all four masks on the browser thread. Every explicit
batch used two to four threads. The worker and instruction
diagnostics verified the URL, ready state, viewport and all
30 ordered story IDs.

| Diagnostic pair | Previous single-thread large batches | Explicit single-thread large batches | Previous large masks on caller | Explicit large masks on caller |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | 0 | 82 | 101 |
| 2 | 1 | 0 | 84 | 101 |

The browser-thread counters ran separately with glyph logging disabled.

| Counter pair | Previous text instructions | Explicit text instructions | Previous native raster instructions | Explicit native raster instructions |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 134,029,397 | 135,240,087 | 277,828,236 | 278,085,695 |
| 2 | 132,445,755 | 134,966,781 | 279,024,071 | 277,272,336 |

The unprofiled cohorts alternated both modes on the same executable.
The reversed cohort started with the previous scheduler. Each trial
used JavaScriptCore, a private empty profile and HTTP cache, retained
OS filesystem caches and a 60 ms delay per replayed logo response.
Timing spans fresh launch through the completed 1024×768 CSS-pixel
document PNG at 2× scale.

| Pair | Previous, ms | Explicit, ms | Reversed previous, ms | Reversed explicit, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 458.128 | 500.406 | 420.497 | 492.684 |
| 2 | 448.613 | 469.350 | 469.758 | 508.935 |
| 3 | 466.803 | 467.815 | 497.541 | 474.518 |
| 4 | 486.410 | 468.305 | 507.936 | 453.945 |
| 5 | 476.355 | 485.854 | 538.958 | 487.501 |
| 6 | 435.305 | 417.159 | 487.671 | 471.124 |
| 7 | 422.232 | 440.215 | 424.774 | 437.075 |
| Median | 458.128 | 468.305 | 487.671 | 474.518 |

Paired median changes were +9.500 and −16.547 ms, with two and four
wins. Sampled browser-thread CPU medians were 287.89 → 290.09 ms and
290.92 → 293.59 ms. One-minute load ranged from 35.72 to 39.90 and
33.01 to 35.72 on 18 CPUs. The cohorts showed mixed elapsed-time results
under this contention.

All 28 timed and eight diagnostic captures matched reference PNG
SHA-256 `a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
Every launch reproduced the same eight request and response records,
including the favicon miss. The executable, native library, helper,
archive, and driver hashes stayed pinned. The browser, driver and
3 GiB guard exited zero. Peak aggregate RSS was 406,093,824 bytes.

### Give the browser thread the shorter range in uneven mask batches

Commit `409314086` assigns the first range to the caller when the
mask count does not divide evenly among the available lanes. That
range rounds down, while the previous final range rounded up.
Worker ranges remain disjoint and join before cache publication.
Evenly sized batches use their final range on the caller.
`VOX_GLYPH_MASK_CALLER_LAST=1` selects the previous assignment with
the same explicit dispatch and lane budget.

The scan worker test covered every item of an uneven workload
with either assignment and verified the caller thread identity.
The glyph test checked batches of three, four and five at fractional
origins and compared all published masks with serial CoreText.
All 15 focused arena-poisoned tests, the caller-last control,
ThreadSanitizer and the production type check passed. The pinned
glyph differential returned 1,963 exact cases and 37 declines.

#### Hacker News retained text replay

Published executable `4812830ce191…26bc` captured 332 retained draws
from the archived homepage and reproduced the reference PNG.
The input log SHA-256 was
`0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24`.
Each replay used a fresh glyph cache and arena poisoning on one
single-C-unit V `-prod` executable, SHA-256
`a37eb8dfd43e8741b21b65beac30e6c946937c0b549faa6294e3dd8990ab8edd`.

Both modes drew 391 masks in 84 batches. The new assignment moved
39 masks off the browser thread. The larger batches moved from
101 to 82 caller masks, and the two- and three-mask batches moved
from 67 to 47. Every batch used multiple threads in the diagnostics.
All 30 isolated replays matched reference RGBA SHA-256
`66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52`.

| Pair | Previous, ms | Shorter range, ms | Reversed previous, ms | Reversed shorter range, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 8.450 | 8.913 | 11.017 | 9.602 |
| 2 | 8.988 | 9.403 | 9.888 | 10.542 |
| 3 | 8.798 | 8.766 | 10.997 | 10.148 |
| 4 | 8.588 | 8.723 | 10.178 | 10.544 |
| 5 | 8.672 | 8.865 | 11.362 | 10.674 |
| 6 | 9.825 | 9.430 | 10.734 | 9.851 |
| 7 | 9.443 | 10.070 | 12.076 | 11.257 |
| Median | 8.798 | 8.913 | 10.997 | 10.542 |

Paired median changes were +0.193 and −0.819 ms, with two and five
wins. One-minute host load was 14.66–15.59 on 18 CPUs. Executable,
fixture, font and driver hashes stayed fixed. Every replay and the
3 GiB guard exited zero. Peak aggregate RSS was 58,507,264 bytes.

Production attempt `20261125-145936-9b37066e` ended before publishing.
The resumed worker rejected changed checkout inputs before C
preprocessing in receipts `20261125-150441-f2cbf788` and
`20261125-150715-cc7fa132`, and retained the published baseline.

Production receipt `20261125-151032-18513f19` sealed the candidate
inputs, then failed verification because its preprocessed C file
disappeared during the link. Receipt cleanup could remove older
compiler inputs even while the guard held the receipt log open.
Commit `3f70f84f9` makes both pruning tools preserve in-use receipts
and covers reclamation after the log closes. The focused V tests and
12 Python pruning tests passed under the 3 GiB guard.

Receipt `20261125-153205-c781deaf` rejected checkout changes before
C preprocessing. Receipt `20261125-155026-9db2f7bb` captured its
input inventory before the pruning fix and rejected the edit to
`tools/buildtools/prune.v`. The coalesced single-C-unit V `-prod`
request included the fix.

Receipt `20261125-155553-2483b004` also rejected checkout changes
before C preprocessing and exited 1. Peak process-tree RSS was
7,675,166,720 bytes. The managed worker retained the previous
published app and started receipt `20261125-161203-c3737351`.

A fresh baseline capture on executable `4812830ce191…26bc` verified
the archived URL, complete readiness and all 30 ordered story IDs.
`tools/measure_load_parallelism.py` used JavaScriptCore, a private
profile and HTTP cache, a 60 ms replay delay for the logo and the
`tr.athing` ready selector at 1024×768 CSS pixels and 2× scale. It
reproduced all eight replay records, including the favicon miss, and
the reference PNG. The browser and 3 GiB guard exited zero. Peak
aggregate RSS was 371,392,512 bytes and one-minute load was 124.30 on
18 CPUs. This capture verifies the benchmark setup on the published
baseline. The shorter-range scheduler was measured in the retained
text replay above.

#### Shorter-range production captures

Receipt `20261125-161203-c3737351` sealed `ef8a858a2`, passed startup
smoke and published a single-C-unit V `-prod` build. Both modes used
that executable with `VOX_GLYPH_MASK_CALLER_LAST=0` for the shorter
range and `=1` for the previous range.

| Input | SHA-256 |
| --- | --- |
| Vox | `16c404942668946b797186d3133dba0a7dd84b200e355e7596b2f02966514caa` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `e1a6650b8fc91a2060dceb7fa737d2fe8b9244f13628323d8f40e29569d9d10d` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

In both diagnostic pairs, each mode drew 391 masks in 84 batches,
including 277 masks in 37 batches of at least four. Every batch used
two to four threads in both modes. The shorter range moved 39 masks
off the browser thread, reducing its share from 168 to 129 masks.
Caller counts went from 101 to 82 in the larger batches and from 67
to 47 in the two- and three-mask batches.

Separate browser-thread counter runs used
`VOX_DIAGNOSTIC_LOAD_STAGES=1`, `VOX_DIAGNOSTIC_THREAD_LOAD_STAGES=1`
and `VOX_PROFILE_INSTRUCTIONS=1` with glyph logging disabled.
Text instructions fell 4.6% and 4.4% in the two pairs. Native raster
replay instructions fell 2.8% and 2.1%.

| Counter pair | Previous text instructions | Shorter-range text instructions | Previous native raster instructions | Shorter-range native raster instructions |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 135,908,614 | 129,634,669 | 279,346,497 | 271,527,811 |
| 2 | 134,844,150 | 128,896,198 | 278,048,800 | 272,123,387 |

Two unprofiled cohorts alternated fresh browser launches through the
completed document PNG. The reversed cohort started with the previous
range. Both used a 1024×768 CSS-pixel viewport at 2× scale, JavaScriptCore,
private empty profiles and HTTP caches, retained OS filesystem caches
and a 60 ms replay delay per logo response.

| Pair | Previous, ms | Shorter range, ms | Reversed previous, ms | Reversed shorter range, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 336.234 | 323.910 | 327.548 | 335.642 |
| 2 | 301.384 | 328.743 | 323.343 | 315.295 |
| 3 | 291.555 | 312.694 | 347.368 | 319.982 |
| 4 | 312.872 | 303.879 | 392.296 | 387.234 |
| 5 | 299.477 | 313.863 | 366.504 | 347.118 |
| 6 | 301.060 | 307.184 | 324.301 | 336.639 |
| 7 | 297.526 | 302.748 | 319.894 | 329.494 |
| Median | 301.060 | 312.694 | 327.548 | 335.642 |

Paired median changes were +6.124 and −5.063 ms, with two and four
wins. Sampled browser-thread CPU medians were 164.212 → 160.971 ms
and 185.087 → 187.298 ms. The browser thread still accounted for
69%–70% of sampled process CPU time over the full capture interval.
One-minute host load ranged from 13.31 to 14.58 and 14.58 to 18.73 on
18 CPUs. The launch-to-PNG results show mixed elapsed times.

All 28 timed and eight diagnostic captures reproduced the eight
request records, including the favicon miss, and matched the
reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`.
The diagnostic captures also verified the URL, complete ready state,
viewport and all 30 ordered story IDs. Executable, library, helper,
archive body and driver hashes stayed fixed. All browser processes,
the benchmark driver and the 3 GiB guard exited zero. Peak aggregate
RSS was 388,055,040 bytes.

### Overlap initial layout with text shaping

Two archived homepage profiles on executable `16c404942668…14caa`
put 348.8–348.9 million browser-thread instructions in style update and
149.6–150.4 million in flow layout. The browser previously waited for its
initial ASCII shaping batch to complete before entering flow layout.

Commit `8d75c72a2` submits all ranges to background workers and lets
layout continue. Font keys are visible to the owner while the native
buffer and glyph outputs remain private to their workers. The first
matching shaping-cache miss joins the batch. Scope exit and font-cache
retirement join any outstanding work before releasing storage and
native font handles. Cache publication still runs on the owner.
`VOX_SYNC_ASCII_LAYOUT_SHAPING=1` restores the previous synchronous
schedule. Failed submission uses the existing fallback.

The focused tests compare the glyphs and trailing whitespace with
ordinary shaping through synchronous and background dispatch. They
also cover unrelated cache requests, a single join on first use,
unconsumed results and nested font-cache retirement. The tests passed
with arena poisoning, and the native worker test passed ThreadSanitizer.

#### Production captures with background shaping

Receipt `20261125-163110-4ed1a3a8` sealed `8d75c72a2`, passed startup
smoke and published a single-C-unit V `-prod` build. Both modes used
that executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `019c5ad01af7e0a0047cfa7e61aa5304b3ec7a6df7a5d33c10bb17e71179d276` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both diagnostic pairs prepared and consumed 28 jobs in each mode.
The synchronous path shaped, measured and decoded 21 jobs off the
browser thread. Background dispatch moved all 28 jobs to workers.
Four distinct threads contributed in each mode. Both background
batches were complete at the first matching cache miss.

Main-thread instruction counts came from separate diagnostic launches
with shaping diagnostics disabled. Counts are inclusive within each
listed scope. Preparation instructions dropped about 83%, while
inclusive layout geometry varied across the two pairs.

| Pair | Sync preparation | Background preparation | Sync flow layout | Background flow layout | Sync layout geometry | Background layout geometry |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1,662,504 | 288,499 | 150,374,754 | 150,747,866 | 175,485,173 | 173,940,371 |
| 2 | 1,647,488 | 288,312 | 149,284,730 | 150,660,509 | 173,060,172 | 175,466,519 |

Two unprofiled cohorts alternated fresh launches through the
completed document PNG, reversing the starting mode in the second
cohort. All launches used JavaScriptCore, a 1024×768 CSS-pixel viewport
at 2× scale, a private empty profile and HTTP cache, retained OS
filesystem caches and the 60 ms delay per archived logo response.

| Pair | Sync, ms | Background, ms | Reversed sync, ms | Reversed background, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 308.310 | 313.435 | 324.701 | 311.379 |
| 2 | 302.042 | 300.353 | 297.514 | 313.085 |
| 3 | 309.032 | 300.464 | 303.701 | 325.837 |
| 4 | 310.374 | 302.610 | 316.239 | 314.455 |
| 5 | 337.485 | 297.365 | 336.295 | 329.710 |
| 6 | 320.748 | 327.365 | 338.101 | 323.647 |
| 7 | 332.576 | 312.054 | 333.135 | 343.038 |
| Median | 310.374 | 302.610 | 324.701 | 323.647 |

Paired median changes were −7.764 and −1.783 ms, with five and four
background wins. Sampled browser-thread CPU medians moved from
180.100 to 171.764 ms and from 183.579 to 186.494 ms. The browser
thread still accounted for about 69% of sampled process CPU time.
One-minute load was 5.09–5.32 and 5.32–7.16 on 18 CPUs.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and the same eight replay records, including the favicon miss.
The eight diagnostic captures verified the URL, ready state,
viewport and all 30 ordered story IDs. Executable, native library,
helper, archive and driver hashes stayed pinned. The browser
processes, driver and 3 GiB guard exited zero. Peak aggregate RSS
was 391,675,904 bytes.

### Parse default user-agent stylesheet syntax on a worker

Commit `7c6562f89` moves tokenization and raw-rule parsing for the default
user-agent stylesheet to a worker on macOS preallocated builds. The
browser thread parses the quirks, MathML and SVG sheets in parallel.
It then converts the default sheet to CSSOM and publishes the rule-cache
entry. The worker keeps its scratch arena alive through conversion and
retires it before startup proceeds. `VOX_SYNC_UA_STYLESHEET_SYNTAX=1`
selects the synchronous control.

The worker-built sheet serialized rule for rule after its source arena
was poisoned, including the retained text used by lazy declarations.
The stylesheet rule-cache and shared user-agent cache-template tests
passed with arena poisoning. ThreadSanitizer passed on the same
preallocated worker path.

#### Production captures with stylesheet syntax on a worker

Receipt `20261125-165201-97a22bf9` sealed `7c6562f89`, passed startup
smoke and published a single-C-unit V `-prod` build. Both modes used
that executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `4087f96569a5011531befbe58071b20ae101e6e83aeeaa002859e4b68e21c72f` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both worker diagnostics recorded 157 raw rules off the browser
thread. The worker was still running when the owner reached the join
in both launches. Separate counter diagnostics recorded the following
inclusive browser-thread instruction counts.

| Pair | Sync UA initialization | Worker UA initialization | Sync style update | Worker style update |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 11,661,301 | 7,475,159 | 347,020,005 | 347,636,061 |
| 2 | 11,646,885 | 7,670,135 | 346,509,228 | 342,016,702 |

UA initialization instructions dropped by 35.9% and 34.1%. The
document style update still took 342–348 million instructions.

Two unprofiled cohorts alternated fresh launches through the completed
document PNG. The reversed cohort started with the synchronous mode.
Both used JavaScriptCore, a 1024×768 CSS-pixel viewport at 2× scale,
private empty profiles and HTTP caches, retained OS filesystem caches
and a 60 ms replay delay per logo response.

| Pair | Sync, ms | Worker, ms | Reversed sync, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 469.268 | 470.009 | 479.856 | 486.667 |
| 2 | 488.223 | 495.537 | 481.414 | 460.132 |
| 3 | 757.842 | 565.811 | 480.541 | 487.212 |
| 4 | 790.703 | 606.100 | 480.264 | 480.776 |
| 5 | 557.182 | 584.718 | 497.809 | 613.261 |
| 6 | 583.935 | 586.850 | 486.343 | 599.735 |
| 7 | 501.662 | 535.424 | 515.170 | 499.833 |
| Median | 557.182 | 565.811 | 481.414 | 487.212 |

Paired median changes were +2.915 and +6.671 ms, with two worker
wins per cohort. Sampled browser-thread CPU medians were
312.808 → 334.738 ms and 292.772 → 293.112 ms. One-minute host load
was 46.16–52.53 and 39.64–46.16 on 18 CPUs. These cohorts showed a
launch-to-PNG regression under contention. A 150-second wait for
one-minute load at or below 18 ended at 65.38, leaving the timing
comparison limited to the two contended cohorts.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and the same eight replay records, including the favicon miss.
The diagnostic captures verified the URL, ready state, viewport
and all 30 ordered story IDs. Executable, native library, helper,
archive and driver hashes stayed pinned. All browsers, the driver
and the 3 GiB guard exited zero. Peak aggregate RSS was 399,130,624
bytes.

### Move the default stylesheet join into browser startup

Commit `a3ed36c7f` starts the default stylesheet syntax worker after
heap setup on macOS production builds. The worker can run during
settings, font, browser state, navigation and native window setup.
A local document joins before installation. A remote launch joins
from the native window initializer, and the stylesheet accessor can
complete the handoff if an earlier consumer needs the sheet. CSSOM
conversion and publication remain on the browser thread in normal
startup. `VOX_EARLY_UA_STYLESHEET_JOIN=1` selects the previous worker
schedule, which completes the sheet during module initialization.

Focused preallocated tests covered first-use publication, repeated
startup calls, discarding an unused worker, rule serialization after
worker arena retirement, and shared sheet lifetime past the first
caller's scratch and worker exit. The user-agent cache template and
shadow cache suites passed with arena poisoning. ThreadSanitizer
passed the startup and lifetime tests.

#### Production captures with the later stylesheet join

Receipt `20261125-172559-4d24bb5b` verified `2cee06cef`, passed
startup smoke and published a single-C-unit V `-prod` build. Both
worker schedules used that executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `e9c5258ec283f042913e0f1dbfa7e0a4b19063ed1b75b7ee8107cd295816fb5e` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both schedules parsed 157 raw rules off-thread. The two late joins
found the syntax ready. Both early joins waited for the worker.
Separate counter runs included the module initialization scope and,
for the late join, the scope that completes the default sheet.

| Pair | Early UA initialization | Late companion sheets | Late default sheet | Late UA total | Early style update | Late style update |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 7,665,247 | 2,393,012 | 6,155,470 | 8,548,482 | 344,038,142 | 341,488,734 |
| 2 | 7,652,393 | 2,372,250 | 6,194,191 | 8,566,441 | 347,769,126 | 344,981,444 |

Browser-thread instructions for the combined stylesheet scopes
increased by 11.5% and 11.9%. The late schedule overlaps the raw
parse with independent work and shortens the dependency on the
worker at the join.

Two unprofiled cohorts alternated fresh launches through the
completed document PNG, with the early join starting the reversed
cohort. All launches used JavaScriptCore, a 1024×768 CSS-pixel
viewport at 2× scale, private empty profiles and HTTP caches,
retained OS filesystem caches and a 60 ms replay delay per logo
response.

| Pair | Early, ms | Late, ms | Reversed early, ms | Reversed late, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 515.219 | 492.823 | 523.854 | 566.472 |
| 2 | 490.555 | 527.874 | 585.292 | 587.432 |
| 3 | 526.977 | 522.810 | 680.291 | 687.873 |
| 4 | 570.092 | 528.494 | 578.275 | 569.513 |
| 5 | 624.227 | 541.273 | 585.442 | 577.727 |
| 6 | 563.458 | 599.146 | 574.298 | 487.419 |
| 7 | 574.658 | 578.625 | 582.531 | 547.190 |
| Median | 563.458 | 528.494 | 582.531 | 569.513 |

Paired median changes were −4.167 and −7.714 ms, with four late-join
wins in each cohort. Sampled browser-thread CPU medians moved from
335.498 to 331.899 ms and from 332.358 to 337.683 ms. One-minute host
load was 17.88–23.81 and 23.59–24.22 on 18 CPUs. Individual timing
pairs varied substantially.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced the eight replay records, including the favicon miss.
The diagnostic captures verified the URL, ready state, viewport and
all 30 ordered story IDs. Executable, native library, helper,
archive and driver hashes stayed pinned. Every browser, the driver
and the 3 GiB guard exited zero. Peak aggregate RSS was 441,630,720
bytes.

### Build the default stylesheet syntax cache on its startup worker

Commit `968abdaf9` also counts and copies the default stylesheet's syntax
cache payload on the existing startup worker. The worker detaches the copy's
arena and hands it to the browser thread, which publishes the entry under
the same source, node and storage budgets. The raw parser input has a separate
arena. The browser thread converts it to CSSOM, then the worker retires the
raw input. Discarded startup tasks release both allocations. The same-binary
control `VOX_SYNC_UA_STYLESHEET_RULE_CACHE=1` copies the cache payload on the
browser thread while continuing to parse raw syntax on the worker.

The preallocated user-agent and syntax-cache suites passed with arena
poisoning. The worker test converted a second sheet after the parser arena
and thread were gone, evicted the entry, and serialized both sheets. The
user-agent suite passed under ThreadSanitizer, and the cache suite passed
without preallocation.

Receipt `20261125-174702-1e7094d1` verified `968abdaf9`, passed startup
smoke and published a single-C-unit V `-prod` build.

| Input | SHA-256 |
| --- | --- |
| Vox | `ffb6de206b10adf93e214c32939715cdd175c8255683e9c27741c6072875e57e` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Two diagnostic pairs confirmed that the worker parsed 157 rules in both
schedules and built the 4,156-node cache entry in the candidate. Both
schedules had their worker results ready at the join in all four runs.
Separate calling-thread counter runs measured the following inclusive scopes.

| Pair | Serial default stylesheet | Worker default stylesheet | Serial companion sheets | Worker companion sheets | Serial style update | Worker style update |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 6,182,144 | 5,083,960 | 2,398,482 | 2,345,894 | 347,495,260 | 347,348,642 |
| 2 | 6,181,520 | 5,033,160 | 2,369,083 | 2,369,968 | 347,553,375 | 346,247,273 |

Browser-thread instructions in the default stylesheet scope fell by 17.8%
and 18.6%. The combined default and companion scopes fell by 13.4% in both
pairs. Style update still used about 347 million browser-thread instructions.

The unprofiled cohorts each alternated seven pairs of fresh launches through
completed document PNG. The second cohort started with the serial copy.
Both used JavaScriptCore, a 1024×768 CSS-pixel viewport at 2× scale, private
empty profiles and HTTP caches, retained OS filesystem caches, and a 60 ms
replay delay per logo response.

| Pair | Serial copy, ms | Worker copy, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 312.743 | 304.051 | 322.468 | 302.916 |
| 2 | 319.276 | 316.743 | 335.387 | 320.531 |
| 3 | 299.050 | 314.382 | 303.930 | 307.098 |
| 4 | 314.770 | 293.025 | 327.321 | 319.735 |
| 5 | 305.643 | 302.332 | 324.448 | 311.589 |
| 6 | 312.992 | 309.705 | 306.119 | 323.828 |
| 7 | 313.535 | 308.157 | 304.140 | 318.335 |
| Median | 312.992 | 308.157 | 322.468 | 318.335 |

Paired median changes were −3.310 and −7.586 ms, with six and four worker
wins. Sampled browser-thread CPU medians were 159.971 → 160.440 ms and
170.559 → 169.122 ms. The browser thread accounted for about 69% of
sampled process CPU in both schedules. One-minute host load ranged from
4.25 to 4.36 and 4.25 to 4.80 on 18 CPUs.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced the same eight replay records, including the favicon miss.
The worker diagnostic captures verified the URL, complete ready state,
viewport and all 30 ordered story IDs. Executable, native library, helper,
archive and driver hashes stayed pinned. All browser, driver and guard
exits were zero. The 3 GiB guard observed a peak of 399,933,440 bytes.

### Parse default stylesheet selectors on the startup worker

Commit `3a4d41e3d` prepares the standalone selector lists for the default
stylesheet alongside browser setup. The worker uses the ordinary validated
selector parser for top-level style rules and style rules within top-level
media groups. It hands over a detached arena holding the selector graphs.
The browser thread assembles CSSOM in source order, handles namespace and
nesting context, and reports parse errors. The shared default sheet owns
the selector arena for the process lifetime. `VOX_SYNC_UA_STYLESHEET_SELECTORS=1`
restores browser-thread selector parsing while preserving the worker's raw
grammar and cache preparation.

The user-agent and syntax-cache suites passed with arena poisoning. Tests
checked retained selector storage after worker exit, serialization after
cache eviction, namespace and nested-selector fallback, invalid selectors,
and discarding a startup task. The user-agent suite passed under
ThreadSanitizer. The selector memo and syntax-cache suites passed without
preallocation.

Receipt `20261125-180110-c0f9257e` verified `3a4d41e3d`, passed startup
smoke and published a single-C-unit V `-prod` build.

| Input | SHA-256 |
| --- | --- |
| Vox | `85a440370b6dc773afdeb6213d63c9505e7ff7912b13698272671202cd1b55cc` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both diagnostic pairs found the startup worker ready at the join. Both
schedules parsed 157 raw rules and built the 4,156-node cache entry on
the worker. In each candidate launch the browser used all 154 selector
lists the worker prepared. Separate counter runs measured these inclusive
browser-thread scopes.

| Pair | Serial default stylesheet | Worker default stylesheet | Serial companion sheets | Worker companion sheets | Serial style update | Worker style update |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 5,021,619 | 1,012,058 | 2,409,206 | 2,353,133 | 347,792,274 | 346,438,751 |
| 2 | 5,069,211 | 1,014,691 | 2,384,216 | 2,434,529 | 347,462,422 | 345,761,051 |

Browser-thread instructions for the default stylesheet fell by 79.8%
and 80.0%. The combined default and companion scopes fell by 54.7% and
53.7%. Style update accounted for about 346 million browser-thread
instructions per candidate launch.

Each unprofiled cohort alternated seven pairs of fresh launches through
completed document PNG. The reversed cohort started with serial selector
parsing. Both used JavaScriptCore, a 1024×768 CSS-pixel viewport at 2×
scale, private empty profiles and HTTP caches, retained OS filesystem
caches, and a 60 ms replay delay per logo response.

| Pair | Serial selectors, ms | Worker selectors, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 294.723 | 304.172 | 305.600 | 318.723 |
| 2 | 321.012 | 292.331 | 331.865 | 323.570 |
| 3 | 299.443 | 329.578 | 295.078 | 290.523 |
| 4 | 307.913 | 297.760 | 314.206 | 303.025 |
| 5 | 328.918 | 293.210 | 290.862 | 299.475 |
| 6 | 313.209 | 306.028 | 311.477 | 291.864 |
| 7 | 316.181 | 310.969 | 299.891 | 306.469 |
| Median | 313.209 | 304.172 | 305.600 | 303.025 |

Paired median changes were −7.181 and −4.555 ms, with five and four
worker wins. Sampled browser-thread CPU medians were 162.946 → 162.451 ms
and 161.900 → 160.775 ms. The browser thread accounted for about 69% of
sampled process CPU. One-minute host load was 5.96–6.13 and 6.12–6.86 on
18 CPUs.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced the same eight replay records, including the favicon miss.
The worker diagnostics verified the URL, complete ready state, viewport
and all 30 ordered story IDs. Executable, native library, helper, archive
and driver hashes stayed pinned. All browsers, the driver and the 3 GiB
guard exited zero. The guard observed a peak of 389,218,304 bytes.

### Prepare selector invalidation inputs on the startup worker

Commit `cb78c91bc` projects the parsed default stylesheet selectors into the
groups the invalidation builder reads, including nested pseudo-class and
slotted selectors. The groups live with the worker-built selector graphs.
Rule-cache construction uses them to build each document's own invalidation
plans in sheet order. Tests covered plan equivalence, overlapping merges,
and ownership after the worker's scratch arena retired. The focused suites
passed with arena poisoning, the startup tests passed under ThreadSanitizer,
and the invalidation workspace tests passed without preallocation.

Receipt `20261125-181318-8c447b81` verified that commit, passed startup
smoke and published a single-C-unit V `-prod` build. In this executable,
`VOX_SYNC_UA_SELECTOR_INVALIDATION=1` selected browser-thread projection.
Both schedules kept raw syntax, the syntax cache, and selector-list parsing
on the worker.

| Input | SHA-256 |
| --- | --- |
| Vox | `f55877b838c33d7a1d5ffedca5ef2bd64eab9d7851bb153f5235cb080cfc4efb` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Two diagnostic pairs found the startup worker ready at the join. In each
candidate launch, three rule-cache builds reused 421 prepared selectors
apiece. Separate browser-thread counters measured four rule-cache scope
calls per launch. The enclosing style-update scope ran 12 times in both
controls, 14 times in the first candidate and 12 in the second.

| Pair | Serial rule cache | Worker rule cache | Serial style update | Worker style update | Serial default stylesheet | Worker default stylesheet |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 58,297,226 | 57,262,552 | 347,226,538 | 346,157,577 | 1,039,011 | 1,040,670 |
| 2 | 58,293,851 | 57,355,289 | 347,808,919 | 345,687,409 | 1,031,619 | 1,038,688 |

The rule-cache scope used 1.77% and 1.61% fewer browser-thread instructions
with worker projection. Its counts are inclusive within style update.

The two unprofiled cohorts each alternated seven pairs of fresh launches
through completed document PNG. The reversed cohort started with serial
projection. Both used JavaScriptCore, a 1024×768 CSS-pixel viewport at 2×
scale, private empty profiles and HTTP caches, retained OS filesystem
caches, and a 60 ms replay delay per logo response.

| Pair | Serial projection, ms | Worker projection, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 292.820 | 321.557 | 286.851 | 317.854 |
| 2 | 298.169 | 319.089 | 328.429 | 324.938 |
| 3 | 316.118 | 308.793 | 298.039 | 303.883 |
| 4 | 321.255 | 303.427 | 293.152 | 316.434 |
| 5 | 311.000 | 328.403 | 307.525 | 297.335 |
| 6 | 305.182 | 340.293 | 321.353 | 301.773 |
| 7 | 313.996 | 294.459 | 299.394 | 317.281 |
| Median | 311.000 | 319.089 | 299.394 | 316.434 |

Paired median launch-to-PNG changes were +17.404 and +5.844 ms, with
three worker wins in each cohort. Sampled browser-thread CPU medians
were 161.714 → 165.481 ms and 163.143 → 162.453 ms. One-minute host load
was 4.74–5.32 and 4.74–5.16 on 18 CPUs.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced the same eight replay records, including the favicon miss.
The worker diagnostics verified the URL, complete ready state, viewport
and all 30 ordered story IDs. Executable, native library, helper, archive
and driver hashes stayed pinned. All browsers, the driver and the 3 GiB
guard exited zero. The guard observed a peak of 397,131,776 bytes.

The slower launch-to-PNG medians led to commit `8f046d3eb`, which makes the
worker projection an opt-in via `VOX_PREPARE_UA_SELECTOR_INVALIDATION=1`.
Startup tests passed in both modes with arena poisoning. Receipt
`20261125-182146-d7d3e0ef` passed startup smoke and published Vox SHA-256
`f9c2c07f29c6e7efa43f38735cf65a67dcc56da8ffc6c79dd5bf05fd2e4905ca`.
Two further diagnostic pairs on that executable recorded zero projections
in default mode and three reuses of 421 selectors in each opt-in launch.
The four captures matched the same PNG, content and replay records. All
browser and guard exits were zero, with peak RSS of 369,197,056 bytes under
the 3 GiB guard.

### Parse preloaded author stylesheets on fetch workers

Commit `a004f663a` lets a fetch worker parse the top-level grammar of a
preloaded CSS response on macOS with preallocation. The browser thread uses
the staged rules only when the decoded source bytes match exactly. It
converts them in the document's own namespace, URL and cascade context.
The staging cache has four slots with a 4 MiB arena budget per entry and
accepts sources from 4 to 32 KiB. A consumer claims each entry once, and
idle cleanup and eviction release unclaimed arenas.

The focused syntax-cache tests passed with arena poisoning. They exercised
exact source matching, conversion after the fetch worker and its original
response arena retired, and lease retirement under eviction and idle cleanup.
Concurrent publication passed ThreadSanitizer. The ordinary rule-cache
suite also passed without preallocation.

#### Preparation before delivering the response

Receipt `20261125-183352-aa7514a2` verified `a004f663a`, passed startup smoke
and published the single-C-unit V `-prod` executable with SHA-256
`6f5a192bf9c9e338f41af173ac5c83b23e98db548ba4f4ea629c8b6c1bc625bb`.
`VOX_SERIAL_PRELOADED_STYLESHEET_SYNTAX=1` selects the serial control. Both
diagnostic candidate launches consumed the complete 7,418-byte author
stylesheet as 63 top-level rules parsed on the fetch worker.

| Pair | Serial CSS parsing | Worker CSS parsing | Serial document install | Worker document install | Serial style update | Worker style update |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 34,388,727 | 33,076,369 | 635,344,939 | 638,105,246 | 345,776,797 | 347,904,204 |
| 2 | 34,888,006 | 33,016,609 | 639,316,169 | 636,259,098 | 348,374,290 | 347,848,345 |

The inclusive CSS parsing scope fell by 3.8% and 5.4% in the separate
browser-thread counter runs. Each launch recorded seven CSS parsing
scopes, one document install and 12 style-update scopes.

Each timing cohort alternated seven fresh launch pairs through completed
document PNG. The reversed cohort started with serial parsing. Both used
JavaScriptCore, a 1024×768 CSS-pixel viewport at 2× scale, private empty
profiles and HTTP caches, retained OS filesystem caches, and a 60 ms
replay delay per logo response.

| Pair | Serial syntax, ms | Worker syntax, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 310.393 | 320.721 | 332.961 | 321.957 |
| 2 | 306.279 | 329.927 | 317.035 | 342.025 |
| 3 | 307.409 | 319.347 | 332.376 | 313.282 |
| 4 | 334.005 | 359.816 | 322.664 | 322.218 |
| 5 | 313.336 | 323.823 | 324.622 | 309.171 |
| 6 | 321.021 | 312.575 | 317.540 | 319.397 |
| 7 | 320.624 | 329.075 | 320.673 | 320.659 |
| Median | 313.336 | 323.823 | 322.664 | 320.659 |

Paired median changes were +10.487 and −0.446 ms with one and five worker
wins. Sampled browser-thread CPU medians went from 178.051 to 183.374 ms
and from 173.849 to 175.960 ms. One-minute host load ranged from 6.36 to
6.61 and 6.26 to 6.46 on 18 CPUs. Preparing the rules added work before
the fetch completion could be delivered.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced eight request and response records, including the favicon
miss. The diagnostic captures verified the URL, ready state, viewport and
30 ordered story IDs. Inputs stayed pinned. All browsers, the driver and
the 3 GiB guard exited zero. Peak guard RSS was 391,118,848 bytes.

#### Preparation after delivering the response

Commit `584a222fc` sends the response and native wakeup before preparing
the rules. Preparation runs after the last request in that worker's batch.
The browser thread uses its normal parser when it reaches the stylesheet
before the prepared input is ready.

The resource fetch pool tests passed with arena poisoning. A combined
compile-and-test run reached the 3 GiB guard during compilation. The split
retry compiled under the 12 GiB build guard and ran the tests under the
3 GiB runtime guard. The compile and runtime peaks were 6,885,195,776 and
13,271,040 bytes, respectively.

Receipt `20261125-184341-9bfe537b` verified `584a222fc` and passed startup
smoke. Each schedule was measured against its same-binary serial control
in single-C-unit V `-prod` mode.

| Input | SHA-256 |
| --- | --- |
| Response-first Vox | `ff12fde05da780fe335310d7df448bc913dae54ea5e775b95a7cab749b4ac5c0` |
| `libVoxAVIF.dylib` in both builds | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` in both builds | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both response-first candidate diagnostics found the worker's 63 rules
ready when converting the 7,418-byte author stylesheet. Separate
browser-thread counter runs recorded the same scope counts as before.

| Pair | Serial CSS parsing | Worker CSS parsing | Serial document install | Worker document install | Serial style update | Worker style update |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 34,484,185 | 32,757,204 | 636,351,777 | 635,584,181 | 346,646,668 | 346,057,190 |
| 2 | 34,576,439 | 32,789,495 | 642,369,537 | 634,168,873 | 348,375,191 | 346,111,380 |

Browser-thread CSS parsing instructions fell 5.0% and 5.2%. Document
install instructions fell 0.1% and 1.3%. The timing protocol matched the
earlier cohorts.

| Pair | Serial syntax, ms | Worker syntax, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 337.115 | 348.373 | 293.903 | 338.948 |
| 2 | 320.116 | 345.792 | 325.111 | 304.773 |
| 3 | 339.674 | 313.975 | 305.771 | 310.873 |
| 4 | 319.867 | 317.725 | 328.996 | 306.288 |
| 5 | 316.403 | 305.199 | 306.656 | 327.673 |
| 6 | 328.607 | 323.709 | 293.792 | 328.498 |
| 7 | 359.440 | 302.804 | 303.046 | 305.574 |
| Median | 328.607 | 317.725 | 305.771 | 310.873 |

Paired median changes were −4.898 and +5.103 ms with five and two worker
wins. Sampled browser-thread CPU medians fell from 166.097 to 162.128 ms
and from 160.112 to 158.436 ms. One-minute host load ranged from 4.10 to
4.80 and 4.80 to 5.50 on 18 CPUs. The timing cohorts show mixed elapsed
times.

All 36 response-first captures matched the same PNG and replay records.
The diagnostic captures verified the URL, ready state, viewport and
30 ordered story IDs. Executable, native library, helper, archive and
driver hashes stayed pinned. All browsers, the driver and the 3 GiB guard
exited zero. Peak guard RSS was 393,363,456 bytes.

### Prepare replay rectangles on the culling workers

Commit `6a17a465b` adds screen-space corner projection to the existing
macOS culling batch. Workers prepare the projected corners, enclosing
rectangle and normalized transform for eligible visible leaves in their
assigned command slots. Replay reads those results after the culling join.
Video, native checkbox and radio geometry, and commands whose replay
depends on group order use their existing projection paths. Zoom and
reused scroll damage also use the existing path.

ThreadSanitizer found both glyph workers writing V array slice metadata
for the same backing buffer. It reproduced with rectangle preparation
disabled. Commit `27e2f21ff` gives each worker a fixed, non-owning view
of its disjoint range. The focused culling suite passed with arena
poisoning in both projection modes. It checked identity and reflected,
sheared transforms, replay-time fallbacks and uneven glyph ranges.
ThreadSanitizer passed with worker projection, serial projection and the
alternate packed glyph mode after the fix.

Production receipt `20261125-190608-7e5cf005` passed startup smoke in
single-C-unit V `-prod` mode. The same executable ran both modes, with
`VOX_SERIAL_PAINT_SCREEN_GEOMETRY=1` selecting the serial control.

| Input | SHA-256 |
| --- | --- |
| Vox | `99d6e8590f0a7c7749c65dc5dc243e4707405edcb1daa6371fae4feaaac7eae5` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both worker diagnostic launches prepared 383 rectangles off the browser
thread. The batch was ready at the join, and replay consumed 381 prepared
rectangles per launch. Both serial controls prepared zero. Separate
counter captures measured inclusive browser-thread instructions.

| Scope | Pair 1 serial | Pair 1 worker | Pair 2 serial | Pair 2 worker |
| --- | ---: | ---: | ---: | ---: |
| Paint command dispatch | 235,232,360 | 237,874,281 | 239,272,724 | 238,345,893 |
| Text leaves | 126,726,887 | 127,124,261 | 127,759,050 | 126,756,468 |
| Native raster replay | 261,949,574 | 264,692,246 | 269,361,985 | 264,938,562 |
| Raster frame setup | 5,314,011 | 5,310,125 | 6,038,434 | 5,247,829 |
| Culling worker submission | 29,190 | 29,721 | 29,031 | 29,249 |

Every counter capture recorded one dispatch, 333 text leaf calls, three
native raster replay scopes, one frame setup and one culling submission.
Native raster replay instructions rose 1.0% in the first pair and fell
1.6% in the second.

Two unprofiled timing cohorts each alternated seven launch pairs through
completed document PNG, starting with worker mode in the first cohort and
serial mode in the second. The archived Hacker News homepage used a
1024×768 CSS-pixel viewport at 2× scale, JavaScriptCore, fresh private
profiles and HTTP caches, retained OS filesystem caches, `tr.athing`
readiness, and a 60 ms replay delay per logo response.

| Pair | Serial, ms | Worker, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 598.452 | 510.912 | 768.177 | 598.737 |
| 2 | 563.704 | 566.757 | 501.294 | 573.851 |
| 3 | 476.840 | 534.079 | 481.955 | 495.882 |
| 4 | 464.753 | 447.299 | 489.916 | 491.827 |
| 5 | 479.923 | 463.721 | 487.777 | 448.464 |
| 6 | 472.115 | 483.222 | 426.328 | 454.973 |
| 7 | 532.740 | 480.623 | 422.909 | 411.816 |
| Median | 479.923 | 483.222 | 487.777 | 491.827 |

Median paired changes were −16.202 ms and +1.911 ms, with four and three
worker wins. Sampled browser-thread CPU medians fell from 287.257 to
285.873 ms and from 296.306 to 294.683 ms. The two cohorts ran at
one-minute host loads of 12.27–16.90 and 16.46–17.20 on 18 CPUs. The
elapsed-time result is inconclusive. Display list sequencing and native
submission still use the browser thread.

All 36 captures matched PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced eight request and response records, including the favicon
miss. The worker diagnostics verified the URL, complete ready state,
viewport and all 30 ordered story IDs. The executable, helper, library,
archive and harness inputs stayed pinned. All browser, driver and guard
exits were zero. The 3 GiB guard observed peak RSS of 403,292,160 bytes.

### Overlap the remaining SVG MSAA paths with raster layer setup

The Hacker News diagnostic on the previous executable (`99d6e859…eae5`)
found 54 retained SVG path jobs during multisample tile preparation.
The first 32 ran off the browser thread and the final 22 ran on it.

Commit `91d2a0961` submits the final range when it has at least 16 paths.
The workers read immutable, resource-owned SVG scenes and write their
assigned result slots. The browser thread prepares raster parents and per-layer
storage during that interval. Both ranges join before the ordered trigger
merge and tile selection. Small tails and unavailable worker tickets use
the synchronous path. `VOX_SERIAL_MSAA_PATH_TAIL=1` restores synchronous
tail processing for the same-executable control.

All 23 focused MSAA tests passed under ThreadSanitizer and arena poisoning
with the new schedule, the synchronous tail, the synchronous path scheduler
and raster workers disabled. The expanded test checks a 32-path prefix and
22-path tail, then reuses the same buffer across a larger batch that crosses
its capacity. Both cases match the serial trigger list in order, including
transparent paths and clipped results.

Production receipt `20261125-192653-2cd495a0` verified `d767892ff`, which
contains the scheduler change, and passed startup smoke in single-C-unit
V `-prod` mode. Both settings used the same executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `cdecff67a9324189ef24b4dba842efcaf1995ff8ce820ad8304e0e87c1349712` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

In both diagnostic pairs, the control ran 32 of 54 paths off-thread and
the new schedule ran all 54 off-thread. The prefix was ready at the join
in every launch. Both worker launches still waited for the tail at the
join. The raster grids, selected tiles and reported triggers matched
between modes.

Separate counter captures recorded one tile setup, one frame setup and
three native raster replay scopes per launch. Inclusive browser-thread
instruction counts varied between pairs.

| Scope | Pair 1 control | Pair 1 worker | Pair 2 control | Pair 2 worker |
| --- | ---: | ---: | ---: | ---: |
| Raster tile setup | 4,476,168 | 4,443,914 | 4,451,242 | 4,520,616 |
| Raster frame setup | 5,308,610 | 5,318,163 | 5,286,077 | 5,356,302 |
| Native raster replay | 263,591,096 | 265,404,656 | 264,493,079 | 263,309,543 |

Two unprofiled seven-pair timing cohorts alternated the settings and
reversed which setting went first. Each trial measured a fresh launch
through completed document PNG at 1024×768 CSS pixels and 2× scale,
using JavaScriptCore, private empty profiles and HTTP caches, retained OS
filesystem caches, `tr.athing` readiness and a 60 ms replay delay per logo
response.

| Pair | Control, ms | Worker, ms | Reversed control, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 322.977 | 333.034 | 305.068 | 299.914 |
| 2 | 296.359 | 303.433 | 325.912 | 305.493 |
| 3 | 312.993 | 293.916 | 316.509 | 304.691 |
| 4 | 292.853 | 305.481 | 313.967 | 315.936 |
| 5 | 299.139 | 316.517 | 305.694 | 309.184 |
| 6 | 332.895 | 315.383 | 318.129 | 318.093 |
| 7 | 297.666 | 301.357 | 291.365 | 313.956 |
| Median | 299.139 | 305.481 | 313.967 | 309.184 |

Median paired changes were +7.074 ms and −0.036 ms, with two and four
worker wins. Sampled browser-thread CPU medians changed from 161.350
to 164.605 ms and from 163.033 to 161.345 ms. One-minute host load ranged
from 7.46 to 7.99 and from 7.54 to 7.83 on 18 CPUs. The launch-to-PNG
results show no consistent speedup.

All 36 captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced eight request and response records, including the favicon
miss. Diagnostics verified the URL, complete ready state, viewport and
all 30 ordered story IDs. Executable, helper, library, archive and harness
hashes stayed pinned. All browser, driver and guard exits were zero. The
3 GiB guard observed peak RSS of 389,660,672 bytes.

### Submit the SVG path tail during trigger collection

Commit `7a48fb4bb` scans up to the last 512 commands to locate the final
possible source of retained SVG background jobs in the raster viewport.
It submits the tail after collecting the jobs through that boundary. The
browser thread continues collecting later triggers while the workers write
to their fixed job slots. The join and ordered merge precede tile selection.
`VOX_LATE_MSAA_PATH_TAIL=1` delays submission until the end of trigger
collection for the same-executable control. Both modes use the same worker
ranges.

All 23 focused MSAA tests passed under ThreadSanitizer and arena poisoning
with early submission, late submission, synchronous tail processing,
synchronous batching and raster workers disabled. The expanded test checks
the scan limit, an offscreen retained background after the boundary, and an
ordinary trigger collected after submission. The output matches the serial
trigger list across those cases and reuse of a capacity-sized batch.

Production receipt `20261125-194033-81e62f42` verified `7a48fb4bb` and
passed startup smoke in single-C-unit V `-prod` mode. Both settings used
the same executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `d7b1c9c64ba50cca838578c515f601ee4d2f9ba06287bfc8c37ad380a31c0ab7` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both modes prepared all 54 retained SVG path jobs off-thread. The early
schedule submitted the final 22 with 387 document commands left to scan.
The tail was ready at the join in both early diagnostic launches. Both
late launches still waited for it. The raster grids, selected tiles and
reported triggers matched in all four diagnostics.

Separate counter captures recorded one tile setup, one frame setup and
three native raster replay scopes per launch. The inclusive browser-thread
tile setup scope used 0.6% and 1.5% fewer instructions with early submission.

| Scope | Pair 1 late | Pair 1 early | Pair 2 late | Pair 2 early |
| --- | ---: | ---: | ---: | ---: |
| Raster tile setup | 4,492,183 | 4,463,867 | 4,486,648 | 4,418,209 |
| Raster frame setup | 5,320,478 | 5,310,419 | 5,304,980 | 5,241,989 |
| Native raster replay | 269,808,694 | 269,484,951 | 270,581,769 | 268,934,941 |

Two unprofiled seven-pair cohorts alternated modes, reversing which mode
went first. The measurement spans a fresh launch through completed
document PNG at 1024×768 CSS pixels and 2× scale. The browser used
JavaScriptCore, fresh private profiles and HTTP caches, retained OS
filesystem caches, `tr.athing` readiness and a 60 ms replay delay per
logo response.

| Pair | Late, ms | Early, ms | Reversed late, ms | Reversed early, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 353.957 | 347.433 | 331.222 | 351.633 |
| 2 | 341.336 | 352.246 | 325.352 | 339.280 |
| 3 | 337.691 | 359.462 | 351.466 | 324.407 |
| 4 | 328.630 | 324.729 | 334.209 | 319.747 |
| 5 | 356.752 | 339.782 | 352.023 | 299.397 |
| 6 | 382.628 | 389.668 | 309.544 | 303.882 |
| 7 | 361.303 | 412.106 | 319.939 | 311.756 |
| Median | 353.957 | 352.246 | 331.222 | 319.747 |

Median paired changes were +7.041 ms and −8.183 ms, with three and
five early wins. Sampled browser-thread CPU medians went from 202.890
to 202.115 ms and from 195.735 to 187.788 ms. One-minute host load ranged
from 6.92 to 7.16 and 6.88 to 7.23 on 18 CPUs. The launch-to-PNG timing
result remains mixed.

All 36 captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced the same eight request and response records, including the
favicon miss. The worker diagnostics verified the URL, complete ready
state, viewport and all 30 ordered story IDs. The executable, helper,
library, archive and harness inputs stayed pinned. All browser, driver
and guard exits were zero. Peak RSS was 400,490,496 bytes under the
3 GiB guard.

### Prepare ordinary MSAA leaves during SVG collection

Commit `5f41bad3e` uses the existing bounded SVG preflight scan to detect
a trailing run of ordinary leaves. When the scan finds a retained SVG
background and at least 96 eligible trailing commands, it submits those
leaves before collecting the SVG triggers. The worker reads retained
geometry and writes to a reusable result buffer. The browser thread
collects the earlier triggers and merges the suffix after the ordered SVG
merge. Nested viewports and other resource-dependent commands follow the
existing collection path. The measured build used `VOX_SERIAL_MSAA_LEAF_TAIL=1`
for the serial suffix control.

All 23 focused MSAA tests passed with ThreadSanitizer and arena poisoning
in the worker, serial suffix, late SVG and raster-workers-disabled modes.
The diagnostic test ran the 128-command suffix three times. Each worker
run returned 64 qualifying triggers in serial order and finished before
the join. The test also covered the bounded scan and reuse of a full SVG
job buffer.

The first 1024×768 Hacker News launch on receipt `20261125-195337-07b324e7`
matched the reference PNG and all 30 story IDs. The browser exited zero.
The driver and guard exited 1 because the diagnostic recorded zero leaf
jobs. A separate 1024×1800 capture on the same executable exposed a
replaced-image command near the footer that ended the eligible suffix.
This diagnostic used a different viewport and supplies no timing result.
Both launches used executable SHA-256
`323b7d19437dff637c0e02e6ee9aca67fe21f0618c9b39779cdeb6e3468c1bef`.

Commit `dc200e8c3` includes retained replaced-image geometry in the
worker scan. Its MSAA check reads the destination rectangle, transform,
and clip radii. Image decoding and drawing stay in their existing replay
paths. The final focused suite passed the same four modes under
ThreadSanitizer. Three repeats of the expanded 129-command batch
returned 65 triggers in serial order, including the constrained elliptical
image, and finished before the join.

Production receipt `20261125-200615-9febd3ff` verified `dc200e8c3` and
passed startup smoke in single-C-unit V `-prod` mode. Both modes used the
same executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `ad82c4507bf9ac39e0bf86bfe8f4558c0b77000c95380a235fdf4109eff73172` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Both worker diagnostics checked 379 ordinary commands off-thread and
finished before the join. Those leaves added zero MSAA triggers on the
archived page. All 54 SVG jobs ran off-thread and were ready at the join
in every diagnostic. Raster grids, selected tiles and reported triggers
matched in both modes.

Separate counter captures recorded one tile setup, one frame setup and
three native raster replay scopes per launch. Inclusive browser-thread
instructions changed little in the tile setup scope.

| Scope | Pair 1 serial | Pair 1 worker | Pair 2 serial | Pair 2 worker |
| --- | ---: | ---: | ---: | ---: |
| Raster tile setup | 4,483,119 | 4,482,944 | 4,438,393 | 4,422,579 |
| Raster frame setup | 5,325,359 | 5,312,214 | 5,259,294 | 5,270,181 |
| Native raster replay | 269,975,610 | 271,827,272 | 269,290,870 | 269,496,616 |

Two unprofiled seven-pair cohorts alternated modes, reversing which
setting went first. The timer spans fresh launch through completed
document PNG at 1024×768 CSS pixels and 2× scale, with JavaScriptCore,
empty private profiles and HTTP caches, retained OS filesystem caches,
`tr.athing` readiness and a 60 ms replay delay per logo response.

| Pair | Serial, ms | Worker, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 298.696 | 307.466 | 298.632 | 308.680 |
| 2 | 311.780 | 292.084 | 306.051 | 304.663 |
| 3 | 289.964 | 306.537 | 348.207 | 330.973 |
| 4 | 304.077 | 320.527 | 286.254 | 307.930 |
| 5 | 293.178 | 308.391 | 316.600 | 312.744 |
| 6 | 292.803 | 298.771 | 309.737 | 310.422 |
| 7 | 301.583 | 312.449 | 348.203 | 323.481 |
| Median | 298.696 | 307.466 | 309.737 | 310.422 |

Median paired changes were +10.866 ms and −1.388 ms, with one and four
worker wins. Sampled browser-thread CPU medians went from 158.271 to
160.295 ms and from 171.815 to 172.240 ms. One-minute host load ranged
from 6.28 to 8.10 and from 7.39 to 7.69 on 18 CPUs.

All 36 captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced eight request and response records, including the favicon
miss. Diagnostics verified the URL, complete ready state, viewport and
all 30 ordered story IDs. The executable, helper, library, archive and
harness inputs stayed pinned. All browser, driver and guard exits were
zero. Peak RSS was 401,965,056 bytes under the 3 GiB guard.

The weak timing result and higher browser-thread CPU medians led to commit
`9794688c2`. It keeps serial leaf collection as the default and exposes
the worker path through `VOX_PARALLEL_MSAA_LEAF_TAIL=1`. The focused
suite passed under ThreadSanitizer and arena poisoning in the default
and opt-in modes, with raster workers disabled, and with late SVG
submission.

Receipt `20261125-201551-cc7fa132` verified the opt-in change, passed
startup smoke and published Vox SHA-256
`30500d29306cbb90a5dbd32a0eb127b2c370e955e8bcf2dc2cef2ab7da4363cf`.
Two further diagnostic pairs recorded zero leaf batches in default
mode and 379 off-thread checks ready at the join per opt-in launch.
All four had matching PNGs, tile grids, story IDs and replay records.
Executable, helper, library, archive and harness hashes stayed pinned.
All browser, driver and guard exits were zero. Peak guard RSS was
371,441,664 bytes.

### Validate retained glyph coordinates on the culling workers

Commit `eca57586d` checks the converted coordinates in the existing
culling-worker batch. The check records the exact buffer and coordinate
count. CPU glyph replay reuses it while that position view is immutable.
Other position views and nonfinite buffers use the regular raster check.
`VOX_SERIAL_RETAINED_GLYPH_VALIDATION=1` keeps this check in raster replay
for the same-executable control and preserves worker position preparation.

The CPU glyph suite rendered the checked and serial views with identical
pixels. It also checked short views, copied buffers, NaN and both signs of
infinity. Pairing a valid check with replacement positions containing NaN
declined the draw and preserved destination pixels. The culling suite
passed under ThreadSanitizer and arena poisoning in worker-validation,
serial-validation and packed-position modes. The guarded tests verified
that each prepared view carries its own check.

Production receipt `20261125-202827-7588b02e` verified `eca57586d` and
passed startup smoke in single-C-unit V `-prod` mode. Both modes used
the same executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `3f021777d017a95715131e6fc059e865a6b70b41431a4151f508653daddd7a1c` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

All four diagnostic launches prepared 332 glyph runs off-thread in the
existing worker ranges. In both worker-validation launches, CPU glyph
replay reused the checks for all 332 runs and 5,428 coordinates. In the
serial launches replay performed every check itself.

Separate counter captures recorded 333 text leaves, three native raster
replay scopes and one culling preparation scope per launch. The
instrumented inclusive text instruction counts increased in both pairs.

| Scope | Pair 1 serial | Pair 1 worker | Pair 2 serial | Pair 2 worker |
| --- | ---: | ---: | ---: | ---: |
| Text leaves | 127,637,815 | 128,799,685 | 128,250,833 | 128,773,834 |
| Native raster replay | 270,570,646 | 276,719,886 | 276,243,477 | 276,337,917 |
| Culling preparation | 18,235 | 18,367 | 18,320 | 18,406 |

Two unprofiled seven-pair cohorts alternated modes and reversed which
setting went first. The timer spans fresh process launch through
completed document PNG at 1024×768 CSS pixels and 2× scale with
JavaScriptCore, empty private profiles and HTTP caches, retained OS
filesystem caches, `tr.athing` readiness and a 60 ms replay delay per
logo response.

| Pair | Serial, ms | Worker, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 368.399 | 337.612 | 359.902 | 375.630 |
| 2 | 335.087 | 332.580 | 392.038 | 374.874 |
| 3 | 344.586 | 363.472 | 353.054 | 331.563 |
| 4 | 339.283 | 333.368 | 328.928 | 326.303 |
| 5 | 358.645 | 357.794 | 340.435 | 385.906 |
| 6 | 363.896 | 353.845 | 448.498 | 415.591 |
| 7 | 358.177 | 368.452 | 445.091 | 400.293 |
| Median | 358.177 | 353.845 | 359.902 | 375.630 |

Median paired changes were −2.507 ms and −17.163 ms, with five worker
wins in each cohort. Sampled browser-thread CPU medians went from
206.705 to 203.923 ms and from 214.013 to 229.601 ms. One-minute host
load ranged from 6.88 to 7.44 and from 7.44 to 7.92 on 18 CPUs. The
captures establish reuse of the checks. The full-launch timing measures
many stages, with mixed browser-thread CPU results.

All 36 captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced eight request and response records, including the favicon
miss. Diagnostics verified the URL, complete ready state, viewport and
all 30 ordered story IDs. The executable, helper, library, archive and
harness inputs stayed pinned. All browser, driver and guard exits were
zero. Peak RSS was 392,462,336 bytes under the 3 GiB guard.

### Reuse worker-computed position bounds in CPU glyph replay

Commit `fe04e74ca` carries the culling worker's glyph position bounds
with its finite-coordinate check. CPU replay can reuse the bounds for
quick rejection and filter-layer sizing when the position buffer and
coordinate count match. The CPU glyph tests matched serial pixels for
plain and blurred text, exercised unmatched views and kept rejecting
nonfinite replacement coordinates. The culling suite passed under
ThreadSanitizer and arena poisoning with the worker, serial-bounds,
serial-validation and packed-position modes.

#### Isolated retained glyph replay

The verified browser from receipt `20261125-202827-7588b02e` captured
332 glyph runs from the 1024×768 Hacker News archive at 2× scale. The
glyph-dump launch exited zero and matched the reference document PNG.
Its executable SHA-256 was
`3f021777d017a95715131e6fc059e865a6b70b41431a4151f508653daddd7a1c`.
The matched replay used `tools/benchmark_hn_glyphs.v` with the
`--checked-positions` option added in `822faea96`. Checks were prepared
outside the timer in both modes. The measurement spans fresh-cache CPU
glyph rasterization of the 332 runs and their recorded backdrops. It
excludes fixture loading, the browser, Quartz publication and PNG
encoding. The serial control used `VOX_SERIAL_RETAINED_GLYPH_BOUNDS=1`
on the same single-C-unit V `-prod` replay executable.

| Input or output | SHA-256 |
| --- | --- |
| Replay executable | `8ac67cd91fb1c619d991707a1d29e3bf783e290e2fc7d83b890ffb0c2b908e4e` |
| Captured run records | `0b75efddc25387223969a473bf038cf9e4a80c59a3c3c40a2d440439b333cd24` |
| Ordered capture file fingerprints | `ceb4fc25a750f446b7a164281dd3d05059bde6d86939907e258489815b3bd20b` |
| Concatenated raster outputs | `66224ad1cc7630402f5456c035a7e639e2e503561098f9260f0e9e265285bd52` |

In both diagnostic sets, the original one-argument invocation reused zero
checks. Checked replay reused validation for all 332 runs in both modes.
The reuse mode also skipped the bounds scan for all 5,428 coordinates.
Two unprofiled nine-pair cohorts alternated modes and reversed their
starting mode. Each pair used fresh processes and retained OS filesystem
caches. The executable, renderer and harness sources, captured run
records and all backdrop hashes stayed pinned.

| Pair | Serial, ms | Reuse, ms | Reversed serial, ms | Reversed reuse, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 14.390208 | 15.147375 | 15.649875 | 14.935625 |
| 2 | 14.369292 | 14.932750 | 15.950542 | 13.627042 |
| 3 | 14.815458 | 15.872625 | 16.406541 | 14.118375 |
| 4 | 13.592917 | 15.468666 | 14.802125 | 16.190250 |
| 5 | 14.364041 | 15.070083 | 15.587375 | 16.076584 |
| 6 | 15.449917 | 14.755792 | 15.437292 | 13.730250 |
| 7 | 14.349209 | 16.069417 | 14.282667 | 15.798417 |
| 8 | 14.562125 | 14.924042 | 13.525791 | 16.839042 |
| 9 | 14.073250 | 15.677125 | 15.541333 | 18.016292 |
| Median | 14.369292 | 15.147375 | 15.541333 | 15.798417 |

Median paired changes were +0.757167 ms and +0.489209 ms, with one and
four reuse wins. One-minute host load was 4.39 and 6.13 on 18 CPUs.
All 42 processes produced the same output digest and exited zero. Both
3 GiB guards exited zero and the higher RSS peak was 47,939,584 bytes.

Commit `b669cbb35` leaves CPU bounds recomputation as the default. Set
`VOX_REUSE_RETAINED_GLYPH_BOUNDS=1` to use the worker's bounds. The focused
CPU tests passed again in both modes. Rebuilding the standalone replay
with the final flag verified the matching output digest, all 332 checks
in both modes, and 332 reused bounds in the opt-in mode. The replay
executable SHA-256 was
`3a67d535bc6646e9a447ec232e846759c96c22e821737b6b88dc44d6c65f1fc9`.

#### Full-page captures

Production receipt `20261125-205113-4a675b7f` verified `b669cbb35` and
passed startup smoke in single-C-unit V `-prod` mode. Both settings
used the same executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `b27e26e3422e1d900dffe0347b9dce7ff99cd10bddac6bd42578e2e6c456b9cf` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

All four worker diagnostics prepared 332 glyph runs off-thread and reused
the finite checks for all 5,428 coordinates in CPU replay. The two opt-in
launches reused the worker bounds for all 332 runs. The two default
launches computed their own CPU replay bounds.

Separate counter captures recorded inclusive main-thread instructions
for 333 text leaves, three native replay scopes and one bounds
preparation scope per launch.

| Scope | Pair 1 default | Pair 1 reuse | Pair 2 default | Pair 2 reuse |
| --- | ---: | ---: | ---: | ---: |
| Text leaves | 128,095,206 | 127,412,263 | 127,567,660 | 128,231,657 |
| Native raster replay | 270,102,994 | 269,964,514 | 269,820,110 | 271,841,909 |
| Bounds preparation | 18,445 | 18,557 | 18,495 | 18,421 |

Two unprofiled seven-pair cohorts alternated the settings and reversed
the first mode. The timer spans fresh process launch through completion
of the document PNG at 1024×768 CSS pixels and 2× scale. The captures
used JavaScriptCore, empty private profiles and HTTP caches, retained OS
filesystem caches, `tr.athing` readiness and a 60 ms replay delay per
logo response.

| Pair | Default, ms | Reuse, ms | Reversed default, ms | Reversed reuse, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 306.852 | 300.129 | 291.438 | 319.483 |
| 2 | 309.559 | 282.474 | 305.214 | 303.270 |
| 3 | 322.183 | 298.231 | 302.101 | 300.278 |
| 4 | 297.750 | 302.204 | 300.671 | 313.370 |
| 5 | 301.631 | 301.961 | 336.296 | 341.458 |
| 6 | 303.899 | 302.654 | 365.592 | 364.702 |
| 7 | 291.628 | 303.683 | 361.869 | 334.655 |
| Median | 303.899 | 301.961 | 305.214 | 319.483 |

The median paired changes were −1.245 ms and −0.889 ms, with four reuse
wins per cohort. Sampled browser main-thread CPU medians went from
158.534 to 157.719 ms and from 164.904 to 162.062 ms. One-minute host
load ranged from 4.52 to 4.84 and from 4.84 to 5.41 on 18 CPUs. Individual
launch differences ranged from −27.214 to +28.045 ms. The launch times
and instruction counts varied in both directions, and the isolated
replay regressed in both cohorts.

All 36 captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced eight request and response records, including the favicon
miss. Worker diagnostics verified the URL, complete ready state, viewport
and all 30 ordered story IDs. The executable, helper, library, archive and
harness inputs stayed pinned. All browser, driver and guard exits were
zero. Peak RSS was 384,909,312 bytes under the 3 GiB guard.

### Compile Metal shader stages concurrently

Two leaf-timing captures on the previous production build
(`b27e26e3422e…9cf`) placed the first gradient draw at 11.663 and
11.876 ms. The first draw sets up the GG Metal context and precompiles
its solid pipelines. Two separate counter captures attributed 68,388,250
and 65,281,123 main-thread instructions to the 25 fill leaves.
These diagnostic captures replayed the archive without an added logo
response delay and matched the reference PNG.

Commit `99dd612f7` sends the fragment library compile to a worker
while the drawing thread compiles the vertex library. The drawing
thread joins before reporting shader errors, looking up Metal functions
or registering objects in the Sokol pool. The worker gets the same
Metal device and a private copy of the compile options. The worker path
applies to GG canvas programs with both stages supplied as source and
an explicit Metal shader language version. `VOX_SERIAL_GG_METAL_SHADERS=1`
selects serial stage compilation on the same executable.

The native Metal checks passed in both modes, including 128 exact
render-and-readback cases and a deliberately invalid fragment shader.
The worker diagnostics recorded valid and invalid fragment compiles
off the drawing thread. The native checks also passed with address,
undefined-behavior and thread sanitizers. A separate non-ARC syntax
check passed. The staged Sokol header matched the Python staging
oracle and preserved the other adapters. The GG leaf-region suite
passed with both schedules using the production-staged Sokol header.

#### Matched homepage captures

Production receipt `20261125-210603-b2c6160e` verified `300816b71`,
which includes the shader change, and passed startup smoke in
single-C-unit V `-prod` mode. Both settings used the same executable.

| Input | SHA-256 |
| --- | --- |
| Vox | `217ed8355ca8144364a5a96da3786ccdeb0898d635aacd38546c1f7f23d86a44` |
| `libVoxAVIF.dylib` | `ebde1494c5aebaa69ebe6edab9f4e3333020cb4b2949d96fa1fbb35f19d6a202` |
| `VoxAdblockWorker` | `8ef704b018d10aee3d88821378ba1baae27f6adde1c60e43c6411ece44e6f0d4` |
| Archive manifest | `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0` |

Each worker diagnostic recorded 16 successful fragment compiles off
the drawing thread. The fragments were already ready at two joins in
the first worker launch and one in the second. Both serial controls
recorded zero worker compiles. The first gradient took 14.311 and
14.426 ms in the serial launches and 15.884 and 15.499 ms with worker
logging enabled.

Separate counter captures recorded 25 fill leaves, one command
dispatch and three native replay scopes per launch. The drawing
thread's inclusive fill instructions fell 16.8% and 18.0%.

| Scope | Pair 1 serial | Pair 1 worker | Pair 2 serial | Pair 2 worker |
| --- | ---: | ---: | ---: | ---: |
| Fill leaves | 69,983,945 | 58,218,725 | 70,473,491 | 57,811,665 |
| Paint command dispatch | 241,237,029 | 228,872,346 | 241,596,625 | 228,596,036 |
| Native raster replay | 268,099,580 | 255,611,842 | 268,432,019 | 255,259,476 |

Two unprofiled seven-pair cohorts alternated settings and reversed
the first mode. Timing ran from fresh process launch through the
completed document PNG at 1024×768 CSS pixels and 2× scale. Captures
used JavaScriptCore, empty private profiles and HTTP caches, retained
OS filesystem and shader caches, `tr.athing` readiness, and a 60 ms
replay delay per logo response.

| Pair | Serial, ms | Worker, ms | Reversed serial, ms | Reversed worker, ms |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 290.438 | 283.439 | 309.133 | 301.898 |
| 2 | 284.229 | 286.324 | 294.074 | 297.897 |
| 3 | 304.854 | 294.366 | 302.349 | 295.154 |
| 4 | 307.965 | 303.564 | 305.384 | 303.484 |
| 5 | 292.635 | 296.157 | 287.074 | 286.561 |
| 6 | 310.846 | 294.129 | 286.955 | 302.890 |
| 7 | 323.380 | 304.054 | 296.396 | 297.508 |
| Median | 304.854 | 294.366 | 296.396 | 297.897 |

Paired median changes were −6.999 and −0.513 ms, with five and four
worker wins. Sampled main-thread CPU medians went from 156.065 to
155.587 ms and from 155.461 to 155.916 ms. One-minute load was
4.66–4.89 and 4.58–4.69 on 18 CPUs.

All 36 captures matched reference PNG SHA-256
`a72f7c968e820bffe940c4ea7b49ce1ae92c3c81a7468a545c2d4e4fcf4e3293`
and reproduced the same eight request and response records, including the
favicon miss. The shader diagnostics verified the document URL, ready
state, viewport and all 30 ordered story IDs. Executable, helper, library,
archive and harness inputs stayed pinned. All browser, driver and guard
exits were zero. Peak RSS was 398,983,168 bytes under the 3 GiB guard.

#### First gradient wall time

Two more seven-pair cohorts used the same build, replay and alternating
schedule with only leaf timing enabled. The first visible gradient was
command 2 in every trial. Its replay interval includes the cold GG Metal
context, shader and pipeline initialization, and the first draw.

| Pair | Serial, µs | Worker, µs | Reversed serial, µs | Reversed worker, µs |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 15,438 | 15,464 | 15,146 | 14,958 |
| 2 | 15,169 | 15,529 | 14,772 | 15,012 |
| 3 | 14,481 | 15,173 | 14,280 | 15,169 |
| 4 | 14,708 | 14,747 | 15,582 | 14,904 |
| 5 | 14,442 | 16,049 | 14,760 | 15,675 |
| 6 | 15,366 | 15,220 | 14,589 | 16,688 |
| 7 | 15,195 | 15,368 | 14,846 | 15,299 |
| Median | 15,169 | 15,368 | 14,772 | 15,169 |

Paired median changes were +173 and +453 µs, with one and two worker
wins. One-minute load ranged from 4.85 to 5.27 and from 5.27 to 5.86.
All 28 captures matched the same reference PNG and replay records.
Executable and fixture hashes stayed pinned. All browser, driver and
guard exits were zero. Peak RSS was 367,443,968 bytes.

Worker compilation stays enabled. It moved 16 fragment compiles off
the drawing thread and reduced that thread's fill instruction counts.
The measured first gradient took slightly longer, while the unprofiled
whole-page paired medians fell by varying amounts. Pipeline creation
and native draw submission still run on the drawing thread.
