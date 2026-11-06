# Single C unit vs `-parallel-cc` builds: page instruction counts

Recorded 2026-11-05 on the `OPTIMIZED_SITES.md` workloads that still have, or
could be given, a frozen page. Both builds compile the same generated C; only
the C compile differs:

- **single**: one clang unit with the production `-O3 -mllvm
  -inline-threshold=1500` flags (`sh build-prod-browser.sh --no-parallel-cc`).
- **parallel**: the default build, 33 units with `-flto=thin` and the same
  inline threshold at link time.

These prealloc builds optimize C directly; they do not pass V's literal
`-prod` option. Since November 6, `sh build-prod-browser.sh --prod` requests
literal V `-prod`, one C unit, and no custom C `-O3` or inlining options.
The allocator and native rendering backends retain their usual settings.
Its receipt records `c_compile.v_prod: true`. Automatic commit requests retain
this explicit selection; `sh build-prod-browser.sh` explicitly restores the
default build configuration. This additional mode changes V generation as
well as C compilation, so the historical table below does not measure it.
`sh build-prod-browser.sh --prod --parallel-cc` selects literal V
`-prod -parallel-cc`: V's per-unit optimization defaults and no LTO. The
literal-mode scrolling comparison is recorded at the end of this document.

The main Vox process's own retired instructions at `capture_document_encoded`
(fresh launch through encoded document PNG), median of 7 alternating pairs:

| Site | single | parallel | Median change | Paired change (parallel higher) |
| --- | ---: | ---: | ---: | ---: |
| Hacker News homepage (archived) | 1.608B | 1.621B | +0.85% | +1.12% (7/7) |
| Lobsters homepage (frozen) | 4.973B | 4.977B | +0.09% | +0.27% (5/7) |
| CNN homepage (frozen) | 21.690B | 22.215B | +2.42% | +1.81% (6/7) |
| Wikipedia portal (archived 2026-11-05) | 4.204B | 4.220B | +0.38% | +0.45% (5/7) |
| vlang.io (archived 2026-11-05) | 25.522B | 25.558B | +0.14% | +0.24% (4/7) |

Whole-coalition counts (the `OPTIMIZED_SITES.md` scope, including the filter
helper) change by +0.68%, +0.40%, +4.93%, +0.43% and −0.13% at the median.
They are noisier: on several launches of both builds, two extra short-lived
tasks joined the app's resource coalition and added up to 13B instructions,
mostly in the first pairs after each site's replay server started. Excluding
those launches, CNN changes by +3.68% (6/4 trials) and Hacker News by +1.32%.
Vox's own count is unaffected by them.

Captured PNGs are byte-identical between the builds on Hacker News, Lobsters,
CNN and Wikipedia. vlang.io's capture varies between launches of either build
(three hashes occur in both). All 70 launches passed their content checks.

**Reading:** ThinLTO keeps the split build within about 1% of one unit on most
pages; the JavaScript-heavy CNN page pays about 2%. Use `--no-parallel-cc` for
maximum binary performance and whenever comparing with single-unit results.

## Build cost in retired instructions

The stages that differ between the modes, with the same staged compiler and
production arguments. Every process is counted: the V process, each clang call
and ld (two runs per mode, alternating):

| Stage | single | parallel |
| --- | ---: | ---: |
| V: parse, check, generate C | 152.2B | 201.5B |
| Compile generated C | 2,438.3B / 2,423.7B, one `cc1` | 838.6B / 827.7B in 33 units (largest 38.8B) + 12.0B / 13.0B shared-header preprocessing |
| Link | 4.7B / 4.5B | 2,232.5B / 2,221.3B, ThinLTO optimization and code generation |
| Two small native sources | 10.6B / 10.4B | 6.7B / 6.6B |
| **Total** | **2,606B / 2,591B** | **3,291B / 3,270B** |

The split build retires about 26% more instructions: ThinLTO repeats work per
module, and V's own count is about 50B higher. Its time advantage comes from the
critical path. The single build runs 2.43 trillion instructions in one
single-threaded `cc1`, which took 318 s even on a quiet host (load 9). The split
build's largest unit is 38.8B, and its ThinLTO link spreads 2.22 trillion
instructions over the cores: 379 s of CPU in 34 s (load 10–25).

The counts are per process. A child's instruction count is not added to its
parent's when it exits, so a wrapper reads each process's final hardware counter
before reaping it. In the runs that hit the cache, the counted processes cover
98.6–98.9% of the build tree's CPU time; the rest is the wrappers' own
startup. To count `cc1`, compiles run it in-process (`-fintegrated-cc1`), and
multi-job clang calls run the driver's own job list; the xcrun `/usr/bin/clang`
stub (about 30M instructions per call) is bypassed. Two of the four runs missed
V's native-object cache because other sessions changed native inputs. Their
object compiles are excluded, and V's count comes from the runs with cache hits;
earlier `time -l` readings of the V process agree (151–152B single, 201–217B
parallel). Evidence:
[instruction counts per process](performance/parallel-cc-build-instructions-20261105.json).

## Build time

The same stages timed, alternating on the shared 18-core host (load 93–170):

| Run | Mode | C generation | C compile + link | Total | CPU | Peak RSS |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| p1 | parallel | 159 s | 316 s | 476 s | 592 s | 4.5 GB |
| s1 | single | 124 s | 895 s | 1,019 s | 473 s | 9.4 GB |
| s2 | single | 25 s | 589 s | 614 s | 470 s | 9.0 GB |
| p2 | parallel | 40 s | 183 s | 224 s | 594 s | 4.5 GB |

The split compile and link is 2.8–3.2× faster and the whole stage 2.1–2.7×
faster in neighbouring runs; it uses about 25% more CPU (ThinLTO and repeated
header parsing per unit) and half the peak memory. Its advantage depends on free
cores: on 2026-11-04 the ThinLTO split compile took 136 s (load 32–68) against
370–432 s for one unit (load 12–63), and 51–63 s without LTO. The remaining
production steps (Rust, Skia/Graphite libraries,
ad-block helper, signing) are the same in both modes. Raw timings:
[build-time evidence](performance/parallel-cc-build-time-20261105.json).

## Method and limits

- One V generation (V branch `parallel-cc-native-headers` at `57cb0da449`,
  prealloc runtime) of vox2 `d4bb0d8d8` plus the shared working tree; the full
  C (SHA256 `e8a4a174…`) was compiled both ways. The bundles differ only in
  `Contents/MacOS/Vox`.
- Fresh process and private empty profile/cache per launch, 1024×768,
  JavaScriptCore, 5 s settle, replayed responses only. Wikipedia and vlang.io
  use new archives because their earlier fixtures were deleted. Old Reddit is
  not measured: its fixture is gone and the live page redirects to login.
- Differences from the site reports: no Brave trials, cold caches (the CNN and
  Lobsters reports used warm cache templates), and the endpoint stable-task-set
  ownership audit is off because cold-cache helpers start and exit during
  capture. These are build-to-build comparisons, not new Brave ratios.
- Host load averaged 45–100 (other sessions); alternation balances it.

Evidence: [per-trial counts and identities](performance/parallel-cc-ab-20261105.json),
[driver, analysis and receipts](performance/raw/parallel-cc-ab-20261105.tar.gz).

## Literal `-prod` versus `-prod -parallel-cc`: vlang.io scrolling

Measured November 6 with GPU scrolling enabled in both modes. Both V
generations consumed the same verified 4,638-file source/header closure.
Single-unit `-prod` uses `-O2 -flto -mllvm -inline-threshold=75`; the actual
33-unit parallel plan uses V's per-unit `-O2`/`-O3` defaults without LTO.
No custom ThinLTO or inline-threshold-1500 options are added.

Seven alternating counter pairs, with 600 precise native wheel inputs per
fresh process, give these medians for the main process (all threads):

| Mode | CPU time, ms | Retired instructions | Scroll-changing publications |
| --- | ---: | ---: | ---: |
| `-prod` | 5,288.52 | 35,139,338,700 | 534 |
| `-prod -parallel-cc` | 5,166.39 | 39,558,848,211 | 496 |

Single-unit instructions are lower in all seven pairs, with an **11.2% lower
median total**. Input coalescing produces fewer publications in the parallel
runs. Normalizing each trial by its scroll-changing publications gives median
CPU costs of **9.85 versus 11.09 ms/publication**, and **67.12M versus 82.02M
instructions/publication**. Those are 11.2% and 18.2% lower for single-unit
`-prod`. These normalized costs include background/media work in the main
process; they are not isolated render costs.

Separate unprofiled timing pairs show mixed wall-time changes:

| Pair | Mode | Mean updateLayer, ms | Scroll publications/s | Interval median / p95 / max, ms | Over 16.67 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | `-prod` | 9.83 | 82.32 | 8.79 / 25.47 / 99.83 | 15.2% |
| 1 | `-prod -parallel-cc` | 10.15 | 70.78 | 10.82 / 28.28 / 182.55 | 27.5% |
| 2 | `-prod` | 12.99 | 68.18 | 10.27 / 37.35 / 155.29 | 22.6% |
| 2 | `-prod -parallel-cc` | 12.17 | 71.64 | 9.29 / 33.88 / 102.56 | 22.1% |

This establishes an observed instruction-efficiency difference, with no
consistent wall-time win in these trials. Smooth 60 fps remains open.
Publication throughput uses the entire first-to-last actual input window and
does not measure physical display scanout.

The workload is a 42-response original-origin vlang.io replay, including its
video, at 1708×953 document pixels and 2× backing. Each run uses an empty private
profile/cache, automatic script policy, ten seconds of settling after the
matching title, and nominal 120 Hz delta-8 input reversing every 150 events.
OS filesystem/shader caches are retained. All 20 final trials complete 600
inputs and exit normally. Separate GPU diagnostics observe 2,224/2,508 GPU
draws during the input/publication period, with maximum channel error three
in both modes. The 18-core host's one-minute load ranges from 6.37 to 13.25.

CPU counters cover first wheel dispatch through completion of both the last
dispatch and its first publication. Startup, settling, child processes, GPU
execution and outside services are excluded. Raw legacy `user_ns`/`system_ns`
fields contain Mach ticks; the derived report converts them with the measured
125/3 ns timebase. Calibration against `CLOCK_PROCESS_CPUTIME_ID` agrees to
0.0023%. Raw summaries are retained unchanged. The reader is fixed, and all
45 precise-scroll tests pass, including a native CPU-clock scale check.

The final cohort holds the canonical bundle's publication lease and changes
only its V executable. Shared native publications between build attempts
updated the renderer; the final cohort pins the same newer installed renderer
for both variants and verifies its loaded identity and GPU parity. This is a
comparison of V executable modes with one common renderer. The original
signed executable is restored byte-for-byte after both controllers. Rejected
source/build attempts, the corrected buffered-log analysis failure, original
counter data, all input/publication timestamps, identities and exits remain in
the [report](performance/vlang-literal-prod-compare-20261106.json) and
[raw evidence](performance/raw/vlang-literal-prod-compare-20261106.tar.gz).
