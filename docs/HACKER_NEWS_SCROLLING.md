# Hacker News scrolling

The production build measures **115.65 / 113.14 scroll-changing publications/s**
on the live homepage, with p95 intervals of **10.74 / 11.67 ms**, below the
16.67 ms budget in both fresh-process trials. This meets the measured native
60 FPS target for the conditions below; physical display scanout is unmeasured.
Occasional deadline misses and initial publication gaps remain.

[Durable receipts](benchmark-results/hacker-news-scroll-2026-11-01.json) and
[compressed raw observations](benchmark-results/hacker-news-scroll-2026-11-01-raw.json.gz)
retain all attempts, commands, identities, counters, host conditions and exits.
Full PNGs, build outputs and logs remain in `Build/hn-scroll60-20261101/`.

## Live production results

| Trial | Scroll FPS | Median / p95 / max interval | Intervals over 16.67 ms | Inputs / total publications |
| --- | ---: | ---: | ---: | ---: |
| 1 | 115.65 | 8.39 / 10.74 / 18.28 ms | 0.17% | 1200 / 1213 |
| 2 | 113.14 | 8.39 / 11.67 / 18.14 ms | 2.27% | 1200 / 1201 |

Each trial uses live `https://news.ycombinator.com/`, JavaScript enabled,
a 1024×768 document viewport at native scale 2, a fresh empty private profile
and cache, direct networking, and 20 seconds settling after the HN title.
No allowlist override is present. A read-only document audit at ten seconds
precedes input in both runs and confirms complete readiness and 30 unique
story IDs. Selected JavaScript policy does not establish VM performance.

Inputs are 1,200 precise native wheel events at nominal 120 Hz, delta 1,
reversing every 120 events. Actual delivery is 116.23 / 118.38 Hz. The entire
input windows are 10.315 / 10.129 seconds, with 1,193 / 1,146 scroll-changing
publications. Leading publication gaps are 42.54 / 36.01 ms; the first counted
scroll changes arrive after 58.44 / 51.66 ms. Trailing gaps are 0.30 / 0.17 ms.
Animations and the completion tail do not inflate scroll FPS. The 18-CPU host's
load averages fall from 13.05 to 10.94 and 10.94 to 8.37 during the trials.
These observations do not promise every interval stays inside the budget.

The executable SHA-256 is `47a6b90f38920a7b950ed48775b5feadc5f4d5bdb68251a1bab6e9eeed26633b`; its Skia bridge is
`14c3896931934e842701cffb2184f3e7a07a0059f38b68dfd7d45b9cb2c7562c`. The copy used for these fresh processes has exactly the installed
bundle's executable and native-library hashes at cohort start. Both browser
exits, the benchmark controller and the memory guard exit zero; all identities
stay unchanged during the cohort. The shared build guard was busy with another
session, so no duplicate production build was queued.

## Frozen page

The existing six-response archive retains its author scripts. Trials use a
1024×768 document viewport at native scale 2, fresh processes, private profiles
and resource caches, no external network fallback, and 20 seconds settling after
the Hacker News title. OS filesystem and shader caches remain. The host has
18 CPUs; exact load averages, timestamps, identities, inputs and frames are
retained in the receipts. Other sessions were compiling and running browsers;
these observations do not establish an isolated cache speedup.

The original catalog protocol sends 600 precise native wheel events at nominal
60 Hz, delta 2, reversing every 60 inputs. All four alternating trials remain:

| Trial | Control FPS | Cached glyph blobs FPS | Control / candidate median layer duration | Control / candidate p95 scroll interval |
| --- | ---: | ---: | ---: | ---: |
| 1 | 59.30 | 59.70 | 5.183 / 4.642 ms | 21.03 / 18.26 ms |
| 2 | 59.79 | 59.80 | 4.792 / 5.018 ms | 20.82 / 25.09 ms |

The second pair regresses in layer duration and interval timing. Strict
16.67 ms misses remain in this timer-limited workload; it does not establish
uniform frame spacing. The initial two production baselines already measured
59.89 / 59.80 FPS before this cache change. The old catalog's 46.1–51.5 result
belongs to an older executable and remains in the
[historical report](OPTIMIZED_SITES_SCROLL_FPS.md). Its improvement cannot be
credited to this change.

A separate protocol increases input resolution: 1,200 events at nominal 120 Hz,
delta 1, reversing every 120 events. Its intended velocity, range and ten-second
input duration match the original protocol. Actual input delivery is retained;
it is never assumed to equal the requested rate. This protocol was declared
before its four alternating trials:

| Trial | Control FPS | Cached glyph blobs FPS | Control / candidate p95 interval | Control / candidate intervals over 16.67 ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 117.38 | 117.71 | 10.08 / 9.97 ms | 0.25% / 0.00% |
| 2 | 107.49 | 112.55 | 16.49 / 11.98 ms | 4.33% / 1.82% |

Both controls also exceed 60 FPS. Control variation and host contention limit
attribution; higher input frequency alone earns no engine optimization credit.
These are gentle repeated sweeps around 0–252 CSS pixels, not rapid full-page
traversal or fling scrolling. Idle-tail frames prove completion and are excluded
from throughput. The first publication provides only the reference position.

## Implementation and checks

`58e8d7fb` retains immutable positioned Skia glyph blobs across frame replay.
Previously each visible run rebuilt and copied a blob before looking up the
existing raster cache. Identity includes the full font, glyph values and
positions after the same float conversion consumed by Skia. Paint, origin,
transform, clipping and backdrop decisions still run for each draw. The LRU is
bounded by 1,024 entries and an 8 MiB conservative charge; oversized runs render
without retention. Graphics-memory purging releases both caches.

A separate diagnostic resets cache counts after the native input-start marker:
58,068 hits in 58,112 requests, with 197 entries charged 864,432 bytes. These
post-start totals include the completion tail. A separate V `-profile` run resets
at the first wheel input and records 120 wheel calls, 156 draws and 37,876 native
glyph-run calls, including completion-tail draws. A four-second native sample
during input independently identifies glyph replay as active work. Profiles are
diagnostic; none supplies unprofiled FPS credit.

The profiler's production-O3 build hit the unchanged 12 GiB memory guard. Its
retained generated C was compiled separately at O0 for diagnosis. Three manual
link attempts failed before using the compiler's complete native dependency
plan. Those failures and actual exits remain recorded.

Ownership, font changes, mutable input buffers, float conversion, byte/count
limits, LRU eviction and explicit release pass focused checks. Normal and
ASan/UBSan runs each pass 6,240 exact native glyph comparisons against the pinned
control library. Five full HN viewport comparisons at scroll offsets 0, 21, 42,
126 and 252 preserve every one of 3,145,728 pixels and all 30 story IDs, with no
reference or tolerance changes. The first screenshot attempt incorrectly used
112 pixels of chrome: screenshot mode has 84, giving a 796-pixel document. It
failed the viewport audit and is retained. Corrected captures use an observed
1024×768 document; ordinary scrolling retains its observed 112-pixel chrome.

Live validation also exposed a catalog omission: Hacker News was documented as
optimized but absent from `optimizedsites.sites`. Normal navigation was blocked;
screenshot mode bypassed that restriction. The failed 150-second ordinary run
is retained. The catalog now includes its exact host and an original bundled
favicon, with host-spoofing, bookmark routing, migration and offline decoding
checks. Existing user bookmark edits remain preserved.

The first parallel package-test attempt hit the 3 GiB guard. A serialized run
then exposed unresolved native bridge symbols in the compiler's cached test
path. The explicit C/Clang, no-cache run passes all five bookmark/catalog test
files; the native shell and offline-icon test binaries also execute successfully.
The archived SVG logo did not decode through the favicon path, so its failed
checks are retained and the final catalog bundles the site's original ICO.

Production verification found a separate build issue. The implicit compiler
path returned success and stable source hashes while its executable still
reported three catalog entries and blocked Hacker News. Emitting complete C
from the same checkout showed the four-entry initializer. The production script
now explicitly selects `-b c -cc clang`, matching the focused checks. The rebuilt
runtime reports four entries, allows the HN address, and decodes the bundled
7,527-byte ICO to 256×256 with the exact asset SHA-256. The final build's generated C was inspected during compilation and contains
the four-entry initializer; the stock script removes its temporary directory
after packaging. A separate complete C-only emission remains in the artifacts. A subsequent
raw-ICO-byte assertion was too strict for compiled embedded data and failed
after the production shell had exited zero. Its original controller/guard exits
remain; runtime catalog and decoded-asset checks pass independently.

The shared production build includes concurrent work. Its receipt lists the
seven files changed during compilation, including initial-frame and retained
layout work. The final result applies to the pinned executable and embedded
libraries; it cannot isolate the incremental effect of the glyph cache, compiler
selection or those other changes. Shared build-lock contention is retained.
The completed production snapshot has exactly the installed bundle's bytes at
the start of live validation; fresh processes use that immutable copy while
another session owns the shared build guard.

The final production snapshot also preserves all pixels against the unchanged
control captures at scroll offsets 0 and 252, with complete 30-story audits.
No reference or tolerance was adjusted. Instruction counts were not remeasured
or credited, so no retired-instruction savings are added to the broad-check
cadence. The catalog's CPU row still refers to its historical pinned cohort.

Reproduce the live protocol using a fresh output path and completed bundle:

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-live-UNIQUE.lock --report Build/hn-live-UNIQUE-guard.json -- \
  python3 tools/measure_precise_scroll.py \
    --binary Build/v/Vox.app/Contents/MacOS/Vox \
    --url https://news.ycombinator.com/ --output Build/hn-live-UNIQUE \
    --width 1024 --height 768 --chrome-height 112 \
    --inputs 1200 --input-hz 120 --delta 1 --reverse-every 120 \
    --require-title 'Hacker News' --settle-seconds 20 --script-policy enabled \
    --network-policy 'Live HTTPS; fresh private profile/cache; OS caches retained'
```

The recorded final commands additionally include the read-only pre-input content
audits described above. Compare frozen controls with identical input schedules;
do not compare the 120 Hz live result directly with Brave's traced CDP column or
attribute its difference from the old 60 Hz result to the cache.

A later shared executable (`af46b81773fa96d7c20c06cbd943c32fcca71effd03ec033cdc1b21d2d14b3dc`)
also passes a separate live load/input smoke: fresh empty profile, correct
viewport/title, 60 completed precise inputs, scroll movement and normal exit.
That short diagnostic is retained without acceptance FPS credit; the two-trial
range above belongs to the pinned production snapshot, not every later build.

Implementation commits: glyph retention `58e8d7fb`, HN catalog/icon `01eda037`,
and explicit production C/Clang selection `8da83a2e`. The profiler-reset
measurement support is `cd250d8d` and only activates in diagnostic runs.

## Long comment threads (2026-11-07)

Scrolling `https://news.ycombinator.com/item?id=50391456` (1,904 comments,
2.8 MB of HTML) ran at about 21 FPS: every scrolled frame took ~45 ms.
Sampling the main thread showed where:

- One full-document hit test per replayed wheel. Wheels that arrive during
  frame work are queued, and 4–5 of them replayed per frame, each mapping the
  pointer through every one of ~207,000 retained hit-test steps (35% of the
  main thread).
- Viewport recording kept every entry with a background image, gradient or
  `<img>`. Each HN row has a vote-arrow background (image plus gradient) and
  an indent spacer image, so a 948 px viewport recorded 5,561 commands, of
  which 174 were visible text. Culling, key hashing, layer planning and replay
  then walked all of them on every frame.
- Wide `PaintCommand` and `TextFragment` values copied by value in per-frame
  scans.

Commits, each with its own kill switch where behavior changes:

| Commit | Change | Control |
| --- | --- | --- |
| `443905e78` | Coalesce queued wheels like Chromium's input queue (latest position, summed deltas, same modifiers) | `VOX_DISABLE_WHEEL_COALESCING=1` |
| `00278f0b4` | Map the hit-test point once per visual context per query; borrow fragments | `VOX_DISABLE_HIT_POINT_MEMO=1` |
| `057edbce1` | Copy each recorded viewport command once | none (same commands) |
| `42b9977f5` | Borrow commands in shared-recording layer scans | none (same decisions) |
| `3af03eeb0` | Reject offscreen entries with one cached ink union | `VOX_DISABLE_VIEWPORT_INK_BOUNDS=1` |
| `11f2211c1` | Cull background, gradient and `<img>` entries by border-box ink, keeping one viewport of prepaint above and below; still prefetch every network background | `VOX_DISABLE_BOUNDED_IMAGE_ENTRIES=1` |

The thread now records 311 commands per frame instead of 5,561.

Protocol: `tools/measure_precise_scroll.py`, live HTTPS, fresh private
profile and cache (OS caches retained), 1701×948 document viewport, 112 px
chrome, backing scale 2, 600 precise inputs at nominal 120 Hz, 6 CSS px per
input, reversing every 300, 10 s settle after the title matches `Cybertruck`.
The endpoint is changed native layer publication, not display scanout.
Host: 18 CPUs, load averages 7–17 from other sessions. All browser and guard
exits were 0.

| Build / arm | Mean scroll FPS | Median / p95 / max interval (ms) | Over 16.67 ms |
| --- | --- | --- | --- |
| Shared bundle `d3c519f5…` before the changes | 20.9 | 45.6 / 58.3 / 113.5 | 100% |
| b1 (`489b87cc…`), coalescing + memo disabled | 21.1, 22.9 | 44.9, 42.8 median | 100% |
| b1, default | 29.2, 33.9 | 33.7, 29.2 median | 100% |
| b2 (`f6ca5af9…`), all four switches set | 40.1, 36.8 | 24.3 / 31.4 / 38.2; 25.8 / 36.5 / 47.6 | 100% |
| b2, only `VOX_DISABLE_BOUNDED_IMAGE_ENTRIES=1` | 49.0, 39.7 | 19.6 / 24.6 / 27.7; 24.8 / 30.0 / 40.1 | 98–100% |
| b2, default | 74.3, 74.5, 70.7, 70.4 | 12.8 / 17.0–17.3 / 23.1–35.8; 13.6 / 17.6–18.0 / 29.9–30.2 | 7–13% |

b1 and b2 are private single-C bundles of the dirty canonical tree, which
included other sessions' uncommitted work. Comparisons are same-binary
alternations of the kill switches. The b2 "switches set" arm still contains
the two commits without switches. Trials alternate, and all are retained in
[`docs/performance/hn-item-scroll-20261107.json`](performance/hn-item-scroll-20261107.json).
Input delivery rose from ~45 Hz to ~84 Hz because the main thread no longer
blocks the 120 Hz input timer. Average throughput above 60 means
publications exceed the 60 Hz budget metric; it does not establish 120 Hz
smoothness: the median interval is still 12.8–13.6 ms.

Pixels: on a local copy of the thread (HN's CSS inlined, scripts removed,
assets saved), b2 captures at scroll offsets 0, 2500, 20000 and 61000 are
byte-identical with and without the culling switches. The final frame after
3,600 CSS px of incremental ring-reused scrolling differs in 0 of 7,212,240
pixels between the default and all-switches-off arms. Focused layout tests
pass in Boehm and no-GC builds. Six cases in `scroll/wheel_input_routing_test.v` and
`scroll/element_wheel_owner_test.v` fail identically with the HEAD versions
of every changed file (`scroll_y` 4.0 instead of 3.75 and one listener-order
check). They predate these commits.

Remaining per-frame cost on this page: the single coalesced hit test still
walks every retained step (no spatial culling of hit-test steps), and the
scroll ring's row restore and `CGBitmapContextCreateImage` copy remain from
the earlier profiles.

### Toward 120 Hz on long threads (2026-11-07, later)

After the round above, the shared bundle scrolled the same thread at 48–56 FPS
under a 120 Hz input schedule, with 17–20 ms median intervals. Profiles and
publication logs showed four main-thread costs outside the culled recording:

- Once frames were short, wheels arrived between frames and each ran a
  full hit test on arrival (`wheel_us` ≈ 4 ms) over ~209,000 retained steps.
- Recording still visited all ~35,000 paint entries for culling,
  fixed-background invalidation and the raster layer plan.
- 15–20% of publications carried no new input. Replayed input requested
  its repaint with an ordinary wake before frame preparation began. Every
  wheel also scheduled a 600 ms overlay-scrollbar wake. Each such frame cost
  ~6 ms and delayed the next wheel.
- Each AppKit pump at a cooperative checkpoint ran two `dlsym` lookups.

| Commit | Change | Control |
| --- | --- | --- |
| `98a823b4d` | Hold page wheels for the next native frame and merge them (Chromium's rAF-aligned input); other input dispatches a held wheel first | `VOX_DISABLE_FRAME_ALIGNED_WHEELS=1` |
| `c2d9f16ee` | Per-step and per-run hit bounds by paint revision; exact queries skip runs that miss (Blink's `MayIntersect`) | `VOX_DISABLE_HIT_TEST_CULLING=1` |
| `83e38801e` | Cull runs of 32 entries with one union test | `VOX_DISABLE_VIEWPORT_ENTRY_BLOCKS=1` |
| `90797a664` | Read the clock only for entries that record commands | none |
| `41e99fcee` | Cache fixed-background and raster-plan candidates per revision | `VOX_DISABLE_VIEWPORT_ENTRY_CANDIDATES=1` |
| `5ffe909b7` | Resolve the event pump's `NSApp` and run-loop mode once | none |
| `a36f70e59` | Stamp repaints requested by replayed input into that frame | `VOX_DISABLE_REPLAYED_INPUT_FRAME_STAMP=1` |
| `03305b5e2` | One pending overlay-scrollbar fade wake | `VOX_DISABLE_OVERLAY_SCROLLBAR_WAKE_COALESCING=1` |

On a saved copy of the thread, one exact hit test takes 45 µs instead of
2.7–3.2 ms (`-prod` layout probe).

Protocol: as above, except that the budget is 120 Hz (8.33 ms) and
`--target-hz 120`. Host: 18 CPUs shared with other sessions; one-minute
load averages were 20–34 during the b5 cohort, and every trial records it.
All browser and guard exits were 0.

| Bundle / arm (alternating, same executable) | Mean scroll FPS | Median / p95 interval (ms) | Input-free publications |
| --- | --- | --- | --- |
| Shared bundle `c22eae1c…` (previous round) | 55.6, 47.5, 47.7 | 16.9–19.6 / 25–32 | — |
| b5 `12dc39c1…`, last two switches set | 92.2, 94.6, 83.0 | 9.7–10.5 / 18.2–22.1 | 134, 121, 91 |
| b5, default | 113.7, 110.8, 97.0 | 9.0–9.4 / 12.0–16.5 | 7, 5, 1 |
| b5, default, later at load 28–34 | 99.3, 96.6, 110.7, 87.7, 76.3 | 9.1–11.3 / 12.3–23.8 | 1–6 |

b5 is a private single-C bundle of the dirty canonical tree, so it includes
other sessions' uncommitted work. The earlier b3/b4 cohorts are kept in the
receipt: without the frame-aligned wheels, hit-test culling and entry blocks,
b3 measured 50.6–70.3 FPS against 95.6–99.6 with them.

Retained experiments: disabling the GPU canvas (47.5–73.4 FPS) and the GPU
scrollbar batch (51.9–57.7) are slower. The CPU scroll-tile compositor
(`VOX_SCROLL_TILE_COMPOSITOR=1`) lowers preparation time, but its matched
FPS is lower in all three b5 pairs (84.0, 62.6, 68.4).

Pixels: on the local copy, the final frame after 3,600 CSS px of incremental
scrolling differs in 0 of 7,212,240 pixels between all seven switches on and
off. Captures at offsets 0, 2500, 20000 and 61000 are byte-identical with
hit/entry culling and candidates on and off. Focused layout tests pass under
Boehm and no-GC; the navigation, frame-request, overlay and raster suites
pass apart from pre-existing cases. `test_overlay_scrollbar_input_reveals_and_releases_the_live_thumb`
and the six wheel cases listed above fail identically with this round's
changes removed.

The mean now exceeds 100 FPS at ordinary load, but 56–72% of intervals are
still over 8.33 ms. At this size, the largest remaining cost is restoring the
retained 26 MB viewport ring into each fresh frame buffer (~31% of the
frame). Presenting the ring through Core Animation without that copy is the
next step for a steady 120 Hz. Receipt: [`docs/performance/hn-item-scroll-120hz-20261107.json`](performance/hn-item-scroll-120hz-20261107.json).

### 120 FPS (2026-11-07, evening)

With the round above plus the parallel ring copy (`d58705ab1`), Quartz
deferred scrollbars (`109ee2507`) and the moved-frame snapshot fix
(`1861dc494`) from the Old Reddit work, the same thread now scrolls at the
120 Hz input rate:

| Build | Load | Mean scroll FPS | Median / p95 interval (ms) | Preparation median |
| --- | --- | --- | --- | --- |
| Private h0 (HEAD `2c3cd2a88` + tree) | 10–15 | 117.7–119.6 (7 runs) | 8.3–8.4 / 10.5–11.1 | 2.7–3.2 ms |
| Private h2, control arm | 7–8 | 119.6, 119.8, 118.8 | 8.3–8.4 / 10.0–10.4 | 2.3–2.6 ms |
| Shared bundle `81adeff1…` | 6 | 117.6, 118.4, 119.3 | 8.3–8.4 / 10.5–10.6 | 2.2 ms |

About 97% of intervals are exactly one vsync. The ~10.5 ms p95 is
publication jitter within it. "Over 8.33 ms" stays near 50% because
publications sit on both sides of the boundary. Counters: 26–27 million
instructions and 3.9–4.5 ms of process CPU per input across all threads.
Input-free publications are 1–8 per 600 inputs.

Committed here: `1161402e2` (the Graphite frame-finish entry is resolved
once; dyld work showed up every frame) and `5a5d3f8ad`
(`VOX_GPU_CANVAS_START_DIAGNOSTICS=1` names the command that starts a
frame's GPU canvas). The diagnostic shows that ~20% of scrolled frames on
this thread start the canvas for an antialiased skip-ink underline rect,
paying an upload and a synchronous readback. A rule keeping such rects on
the CPU was ineffective because isolated shapes are on by default, and it
would have moved MSAA-tile edges onto a different raster path. It was
reverted unmeasured for pixels; FPS was already at the input cap.

A reused selected-step buffer (h1) grew inside the scene arena and crashed
another session's shared bundle on Old Reddit video posts. It was reverted
before any commit, and the next shared build (20:38) excludes it. Remaining
per-frame costs, which matter under heavier host load: recording (~23%),
the main thread waiting on the parallel ring restore (~13%), GPU-canvas
readbacks in underline frames (~12%), glyph raster and frame keys. Receipt:
[`docs/performance/hn-item-scroll-120fps-20261107.json`](performance/hn-item-scroll-120fps-20261107.json).

### Brave on the same thread (2026-11-08)

Brave 156.1.98.60 (Chromium 156.0.8078.48, executable SHA256 `9d53e182…`)
was measured on the same live thread with `tools/measure_brave_scroll.py`:
1701×948 CSS-pixel viewport at scale 2, 600 CDP wheels at 120 Hz, 12.6 CSS
px each (Vox's native delta 6), reversing every 300, 10-second settle,
fresh private profile, host load 13–14.

| Trial | Network | Mean scroll FPS | Input Hz | Median / p95 / max interval (ms) | >8.34 ms | Partial frames |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | direct | 118.53 | 119.73 | 8.34 / 9.07 / 18.66 | 20.4% | 4 |
| 5 | shell HTTP proxy | 117.64 | 118.43 | 8.33 / 8.33 / 16.68 | 1.5% | 5 |

Both trials also run at the input rate. Brave's compositor thread scrolls
HN without waiting for the main thread: 4–5 frames per trial are
`STATE_PRESENTED_PARTIAL`, meaning the main-thread update missed that frame
while the scroll was still presented. Excluding them gives 117.7 and 116.7
FPS. The tool's strict check rejects a trial containing any such frame, so
both trials report a validation error; the numbers above are recomputed
from their retained traces. Trials 2–4 failed navigation with
`net::ERR_SOCKET_NOT_CONNECTED` before any input (direct connections from
this session); trial 5 loaded through the shell's proxy instead.

This is an instrumented CDP observation: input bypasses Cocoa and frames are
timed by vsync-aligned Chromium presentation feedback, while Vox's figures
time native layer publications. Brave's tighter p95 therefore does not
establish lower jitter than Vox's 10.5 ms, and the two FPS figures are not
a matched ratio. Receipt:
[`docs/performance/hn-item-scroll-brave-120hz-20261108.json`](performance/hn-item-scroll-brave-120hz-20261108.json).
