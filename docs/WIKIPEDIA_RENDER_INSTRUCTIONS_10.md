# Further Wikipedia instruction and memory optimization

The five-run median uses **12.16% fewer retired instructions than the previous
optimized result: 2,599,008,091 → 2,283,080,067**. A fresh run of that previous
executable gives 2,602,496,910; the reduction against it is 12.27%. Against the
matched current-source control, the reduction is **33.74%**, from 3,445,615,875.

RAM also falls in the separate matched five-pair cohort: median settled physical
footprint is **440.1 → 400.6 MiB**, and median lifetime peak is **482.0 →
441.4 MiB**. The largest observed candidate physical-footprint peak is 442.7 MiB.
These are single-document measurements, not a hard memory bound.

## Instruction comparison

The target requires a 10% median reduction against the smallest of the historical
reference, the fresh previous executable, and the fresh current-source control.
The limiting reference is 2,599,008,091, giving a threshold of 2,339,107,281.9.
All 15 CPU observations remain in the result, including the two higher candidate
samples. The 10% result applies to the median; those two samples do not achieve
10% individually. The candidate mean is 2,404,975,543.8 instructions, only
7.47% below the historical reference. This is a median result, not a uniform
10% reduction. No performance sample was repeated or discarded.

| Pair | Current-source control | New candidate | Previous optimized binary |
| --- | ---: | ---: | ---: |
| 1 | 3,559,408,352 | 2,258,322,006 | 2,584,751,934 |
| 2 | 3,494,505,345 | 2,614,313,211 | 2,589,311,060 |
| 3 | 3,442,390,157 | 2,283,080,067 | 2,616,510,746 |
| 4 | 3,445,615,875 | 2,592,299,361 | 2,613,400,306 |
| 5 | 3,338,478,140 | 2,276,863,074 | 2,602,496,910 |
| Median | **3,445,615,875** | **2,283,080,067** | **2,602,496,910** |

The primary counter still ends at `paint_timing.report_document_paint()` inside
`app.draw`. It includes document installation, parsing, preloading, style,
layout and native document drawing. The native raster wrapper completes
`CGBitmapContextCreateImage` and `CALayer.contents` afterward. Compositor, GPU,
WindowServer, saved-PNG capture and teardown work are outside this scope. This
is not web FCP. No work was moved before the primary counter to gain credit.

Elapsed times are retained as observations and receive no separate speedup
claim. Independent host workflows remained active, with one-minute load averages
18.66–19.42 during the CPU cohort. This task's compilers and captures were held
quiet during the measurements. Instruction counts still vary between processes;
no collection-timing cause is established for individual final rows.

## Memory comparison

Memory uses ten separate processes, five alternating pairs, with a five-second
settle delay and an external approximately 5 ms `proc_pid_rusage/RUSAGE_INFO_V4`
observer. The CPU cohort has no memory polling. `wait4` records kernel lifetime
peak RSS. Values below are medians; 1 MiB = 1,048,576 bytes.

| Root-process metric | Current-source control | New candidate |
| --- | ---: | ---: |
| After observing the drawing marker | 344.3 MiB | 325.5 MiB |
| Pre-capture physical footprint | 440.1 MiB | 400.6 MiB |
| Lifetime peak physical footprint | 482.0 MiB | 441.4 MiB |
| Pre-capture resident size | 597.9 MiB | 557.6 MiB |
| Kernel lifetime peak RSS | 639.7 MiB | 598.9 MiB |

All seven reported median memory metrics decrease, including observed resident
peak. Control physical-footprint peaks span 446.0–502.0 MiB; candidate peaks span
407.3–442.7 MiB. Lifetime peaks include capture and exit. RSS includes clean/shared
resident mappings and is reported separately from physical footprint.

The first observation follows the drawing log marker, with neighboring readings
5.8–14.6 ms apart across both variants. It is not an exact checkpoint timestamp.
The pre-capture window lasts one second and ends one second before the saved-PNG
marker. Physical footprint varies 5.8–12.1% within these windows. These short runs
do not establish long-session memory behavior.

## Changes

Five focused implementation commits add no persistent document cache:

- `c709a90d`: generate retained paint commands one entry at a time, reuse the
  largest entry's scratch storage and allocate exact-sized phase buckets.
- `19f513dc`: collect final rendered DOM text without initializing shaping-only
  font, UTF-16 or full segmenter state for ordinary text. Preserve transforms,
  first-letter behavior, whitespace, malformed input and removed-space grapheme
  handling through a narrow compatibility fallback.
- `f8e9b352`: construct paint boxes directly in stable final child storage using
  a queue of node/box pointers, avoiding duplicate wide box vectors while
  preserving breadth-first construction and retained snapshots.
- `811552fc`: retain immutable optional layer, mask and backdrop-filter payloads
  separately. Ordinary `PaintCommand` records shrink from 3,248 to 2,376 bytes.
- `2d5b04d9`: for parsed JavaScript-disabled documents with at least 1,024
  elements, top up total reusable Boehm capacity to 160 MiB before resource/style
  preflight. Count traversal stops at the threshold without a node vector.

The capacity hint counts both mapped and unmapped memory, so idle unmapping does
not cause repeated expansion on navigation. It preserves existing larger heaps,
GC, active/idle collection divisors and unused-page unmapping. Any explicit
`GC_INITIAL_HEAP_SIZE`, `GC_MAXIMUM_HEAP_SIZE` or `GC_FREE_SPACE_DIVISOR` overrides
it. Small, text-only and script-enabled documents skip the hint. The element
threshold is a heuristic and includes hidden elements; 160 MiB is capacity, not a
maximum or a promise that all sites need that much memory.

Both new variants otherwise use the same current natural startup heap growth,
active divisor 4 / idle divisor 32 and idle page release. The prior executable
keeps its historical 224 MiB startup/divisor-16 policy; it is an additional
reference rather than the matched control. The measurement environment supplies
only `GC_MARKERS=1` and clears other GC overrides.

## Workload and pixels

Each process loads `https://www.wikipedia.org/` in a 1024×768 CSS viewport from a
fresh copy of the identical eight-resource cache, with raster snapshot reuse
disabled. HTML/CSS, normal adblocking, resource requests and subsequent background
refresh remain enabled. Every final row has exactly one document installation,
836 first-draw commands and no JavaScript runtime, sources, source bytes or
script preloads.

Initial HTML: 122,197 bytes, SHA-256
`5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`.
Initial-cache fingerprint:
`46c277c0b7df22c8b1d5c1c00d55b1a2548750e7257cbe04f0b927de9ce8e5fd`.

All ten memory captures, all five candidate CPU captures, all five previous-binary
CPU captures and four of five control CPU captures match the reference exactly.
The remaining control capture differs in 66 pixels at x829–875, y726–727, only
in the underline below the Magyar link. The frozen page has an `a:hover`
underline rule. Transient hover is consistent with the image and CSS, but is an
inference without an event timestamp. Its full row remains in the median. No
rerender, discarded row or generic tolerance change was used. The initial strict
pixel validation gate is preserved; a separate exact-anomaly review enables
regression validation. Decoded coordinates and enlarged crops pin the exact
control-only difference.

## Validation

The final frozen graph passes **444 selected test functions in each GC mode**
(888 executions across 64 files): CSS 63, SVG 10, layout 301, native browser 68
and platform 2. Each mode has 443 functions with assertions and one function
conditionally inactive on macOS. Explicit compilation and test exits are zero;
expected function names/order, assertion summaries and immutable input hashes
are verified. All 100 current upstream LibJS AST fixtures match exactly with the
official unchanged driver and no case overrides. This is selected regression
coverage, not every repository test or full translated LibJS runtime parity.

All 19 native screenshot comparisons pass under their existing bounds. Sixteen
are pixel-exact, including all eight required live SVG/image mutation guards;
`inline-node`, `text-decorations` and `canvas-text` retain their existing
allowances. No screenshot bound changed. Production `--headless-smoke` exits
zero on the same measured executable and replay library.

The final recovery supervisor and both child supervisors exit zero, with
unchanged source/native/harness inputs. The earlier strict control-pixel gate
failure remains recorded beside its exact-anomaly review and successful
recovery; no passing measurement or screenshot was rerun.

This checkpoint covers the five implementation commits and the measured
1,162,535,808-instruction median saving against the current-source control
(315,928,024 against the historical prior checkpoint). The next median reference
for this cache, viewport and drawing endpoint is **2,283,080,067 instructions**,
source-manifest SHA-256
`fe981a834213b99d1e9b14b32e084daa452d77d71ff0c41c853305030eacc765`.
Additional measured savings since this completed broad checkpoint: zero.

Focused checks cover exact phase storage/order/refresh, forced-GC tree ownership,
rare payload defaults and immutable nested masks, text parity over 150
input/whitespace combinations, live first-letter/text/geometry behavior, and heap
override/ownership behavior. Under Boehm, the heap test performs three real
idle-unmap cycles with positive unmapped bytes and verifies no new total capacity.
Its no-GC branch verifies that the hint is a no-op. Browser count/gating fixtures
pass their focused Boehm run.

Earlier failures remain in the evidence. Text parity exposed a removed-space
combining-grapheme bug and was corrected before the measured candidate. The first
heap browser fixture lacked a browsing context, and its corrected fixture retains
all production bytes. Independent review caught the private heap hint's omitted
unmapped capacity; an actual failure of the old helper authenticates that
regression. Candidate3 was never used for performance credit. Heap fixture recovery
carried the passing platform jobs and reran only the failed browser fixture; the
later capacity fix reran its changed platform test. Wrapper recognition failures
are recorded separately from actual test exits.

## Provenance and reproduction

Both matched builds use old V, C `-O2`, Boehm and the same native GG renderer.
The exact matched source difference is 20 owned paths, including tests. All three
source graphs, executables, native/compiler closure and observers are checked
before and after the final cohorts. Later independent workspace changes are
excluded, including ongoing UI2 work. The figures apply to these frozen native
GG builds and do not establish UI2 performance. The canonical app bundle was not
overwritten.

| Identity | Current-source control | New candidate |
| --- | --- | --- |
| Source-manifest SHA-256 | `7311dff43569101f942f5b3098b30d08afd4628e309e7863243b8340401c929f` | `fe981a834213b99d1e9b14b32e084daa452d77d71ff0c41c853305030eacc765` |
| Executable SHA-256 | `bd0190f7fd1f1c02dc28e0e60a569f86ca691d6301cb11b97a0f58f8815e3734` | `2a9d7c3a784171c0eb03d5c0fb3b0c3fce50155a91606189826593224ab2ba5b` |

Native replay library SHA-256:
`46f0a3f9fa2e4cac09af21502d076ca7c3b1369ff84b6c1a5694e6c4f610a2cd`.
Regex and Rust-YUV archives, V executables, fallback GG runtime and observers are
also pinned. Previous-binary provenance remains in
[the preceding report](WIKIPEDIA_RENDER_INSTRUCTIONS.md).

The reviewable executable is
`Build/wikipedia-instructions-10/candidate4/Vox`. Final observations are under
`Build/wikipedia-instructions-10/`:

- `instructions-final/summary.json` and `memory-final/summary.json`: every row,
  native logs, scripts, sources, cache IDs, viewport pixel audit and retained
  source/native/compiler/observer pins.
- `candidate4-source-manifest.json`, `candidate4-build-command.json`,
  `candidate4-build-result.json` and corresponding baseline files: exact graphs
  and builds.
- `candidate4-headless-smoke-result.json`: successful startup on the same binary.
- `final-measurement-verdict.json` and `gc-boundary-variance-audit.json`: the
  integrated verdict, sample spread and limits on GC-timing attribution.
- `control-viewport-anomaly-review.json` and
  `root-viewport-review-acceptance.json`: the exact control-only underline review.
- `final-broad-c4/result.json`, `final-broad-c4/completed-audit.json` and
  `final-broad-c4/supervisor-exit.json`: selected tests in both GC modes, exact
  AST comparison and input verification.
- `final-screenshots-c4/result.json` and its `supervisor-exit.json`:
  all 19 comparisons, original bounds and immutable input/artifact hashes.
- `final-validation-c4-recovery-result.json` and
  `final-validation-c4-recovery-supervisor-exit.json`: final validation union and
  actual zero-exit receipt. The original `final-validation-c4-result.json`
  preserves the initial strict control-pixel rejection.

For a new reproduction, preserve these observations and choose a new output
name. `run-final-cohort.py` orchestrates the task-specific five-pair CPU and RAM
cohorts. Reusable observers are `tools/measure_browser_render.py` and
`tools/measure_browser_memory.py`. Supply explicit pinned before/after binaries,
`--before-arg=--disable-javascript --after-arg=--disable-javascript`, the retained
cache template, five alternating pairs and the same viewport. Include the prior
binary as a separate five-sample reference when checking the historical target.
