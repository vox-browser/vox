# Wikipedia rendering instructions and memory

Five alternating production pairs use **31.86% fewer retired CPU instructions**
for Wikipedia's JavaScript-disabled document drawing: **3,814,245,213 →
2,599,008,091**. Both variants have the same compact managed-heap policy and
native frame presentation. The candidate is also **22.43% below the original
task baseline of 3,350,527,268 instructions**, exceeding the requested 15%
reduction against that original reference.

Memory remains lower in the matched comparison: median pre-capture physical
footprint is **483.4 → 475.2 MiB**, and median lifetime peak is **500.6 →
490.0 MiB**. Candidate peaks range from **473.3 to 567.6 MiB**; this is not a
500 MiB memory cap. All five CPU samples and all five memory samples per variant
are retained.

## Instruction comparison

| Pair | Common compact/native policy | Plus the four rendering optimizations |
| --- | ---: | ---: |
| 1 | 3,814,245,213 | 2,599,008,091 |
| 2 | 3,810,485,350 | 2,593,494,738 |
| 3 | 3,815,280,392 | 2,602,174,431 |
| 4 | 3,803,527,940 | 2,590,994,576 |
| 5 | 3,847,214,367 | 2,602,877,689 |
| Median | **3,814,245,213** | **2,599,008,091** |

The matched reduction is 1,215,237,122 instructions. Every candidate sample is
also below 85% of the original task's recorded median. The broader native
navigation-to-drawing scope falls from 5,736,266,047 to 4,523,008,910 instructions
(21.15%) with the same startup policies on both sides.

The primary counter ends at `paint_timing.report_document_paint()` inside
`app.draw`. It measures CPU work through Vox's first document drawing checkpoint.
The native raster wrapper still completes `CGBitmapContextCreateImage` and
`CALayer.contents` afterward. This is neither compositor presentation nor web
FCP. The wrappers are identical in the matched variants. GPU execution,
WindowServer, later screenshot capture and process teardown are excluded from
this instruction scope.

Independent workflows were active on the host. No compiler or other screenshot
capture owned by this experiment ran during the paired cohorts. One-minute load
averages in the instruction cohort ranged from 20.31 to 21.18. Retired
instructions are the primary result; the retained elapsed times are observations
and receive no separate speedup claim.

## Memory comparison

Memory uses a separate five-pair cohort so polling and the five-second screenshot
delay do not change the primary instruction samples. External
`proc_pid_rusage/RUSAGE_INFO_V4` observations run approximately every 5 ms;
`wait4` records the kernel lifetime peak RSS. Values below are medians and use
1 MiB = 1,048,576 bytes.

| Root-process metric | Common compact/native policy | Plus rendering optimizations |
| --- | ---: | ---: |
| Physical footprint after observing the drawing marker | 379.1 MiB | 363.3 MiB |
| Physical footprint in the pre-capture observation window | 483.4 MiB | 475.2 MiB |
| Lifetime peak physical footprint | 500.6 MiB | 490.0 MiB |
| Resident size in the pre-capture observation window | 640.3 MiB | 632.7 MiB |
| Kernel lifetime peak RSS | 657.6 MiB | 647.5 MiB |

The first reading follows observation of the drawing log marker and is bracketed
by neighboring readings 6.0–6.6 ms apart; it is not an exact memory timestamp for
the drawing checkpoint. The pre-capture window lasts one second and ends one
second before the saved-PNG marker, excluding normal PNG capture overhead. Its
footprint varies by approximately 5–6% within each sample. Lifetime peaks include
capture and exit. Control peaks range from 474.8 to 564.4 MiB; candidate peaks
range from 473.3 to 567.6 MiB. RSS includes clean/shared resident mappings and is
reported separately from physical footprint. These are short single-document
observations, not a long-session memory bound.

Both variants keep GC enabled. The common production policy reserves an initial
224 MiB managed heap before browser startup and uses a free-space divisor of at
least 16. It is a starting reservation, not a maximum. Explicit initial heap,
maximum heap or free-space-divisor environment settings retain precedence. The
measurement environment supplies only `GC_MARKERS=1` and clears other GC
overrides. Both variants also release unused native Metal drawable storage and
present a complete native raster frame as a bounded layer, preserving Retina
scale. The former automatic 4 GiB document reservation is absent from both.

## Rendering changes

The candidate differs from its matched control only by four completed features:

- Reuse current preflight computed styles for initial layout when the viewport
  matches, while preserving ordinary dirty-style and tree invalidation
  (`9309aa6e`).
- Discover CSS resource URLs from deferred tokens or retained values without
  materializing properties of otherwise unused rules (`cd411edb`).
- Attach the initial DOM/layout structure without constructing text chunks that
  are needed only by the completed attachment; populate those chunks in the
  committed layout pass (`eacfe0fb`).
- Size temporary replay arrays precisely and avoid copying disabled line-box
  guides into them. Retained guides and their visual-layer transitions
  remain available for later debug toggles (`1b5b997b`).

These changes add no persistent document cache. JavaScript remains disabled:
every sample reports no runtime, script sources, source bytes or script preloads.
HTML/CSS rendering, foreground and background resource requests, refresh and the
normal adblock engine remain enabled.

## Input and visual verification

Each fresh process receives a fresh copy of the same eight-resource cache, with
viewport 1024×768 and URL `https://www.wikipedia.org/`. Raster snapshot reuse is
disabled. Initial-cache fingerprint is
`46c277c0b7df22c8b1d5c1c00d55b1a2548750e7257cbe04f0b927de9ce8e5fd`.
The portal HTML contains 122,197 bytes with SHA-256
`5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`.
Live background refresh remains enabled; the test freezes initial inputs rather
than all subsequent network responses. Every final sample records exactly one
document installation.

All ten settled memory captures and nine of ten zero-delay instruction captures
have identical document viewport PNG bytes. Decoded comparisons also report
zero differing pixels against the original task's normal viewport. The remaining
instruction capture, control pair 1, shows the footer instead of the top of the
document. Every initial draw has 836 commands, but no explicit scroll-event
timestamp proves when that viewport change occurred. Its counter remains in the
five-sample median. A supplementary zero-delay pair confirms matching pixels and
receives no additional instruction credit. The anomaly and original screenshot
remain in the evidence; no performance sample was discarded.

## Validation

Focused implementation checks pass: style reuse 5, resource URL/preload discovery
13, deferred text bridge 3, and paint replay 6 cases. The measured candidate's
`--headless-smoke` startup check passes with unchanged executable/library hashes.

All 19 native screenshot comparisons pass with their existing bounds. Sixteen
are pixel-exact, including all eight required live SVG/image mutation cases.
The remaining three retain their normal allowances; no bound changed.

The final frozen graph passes 414 selected test functions in each GC mode
(828 executions): CSS 63, SVG 10, layout 274, native browser 66, and isolated heap
policy 1. In each mode, 413 functions exercise assertions; one function guarded
for another platform has no assertions on macOS. All 100 upstream LibJS AST
fixtures compare exactly, without case overrides. This is selected regression
coverage, not a claim that every repository test was run or that translated
LibJS has full runtime parity.

The successful union is audited against the exact expected test names, order,
assertion summaries and source pins. Earlier wrapper failures remain preserved:
one attempted to relaunch an already completed temporary V test executable, and
the initial combined layout harness exposed an import/local-variable alias
collision. Recovery changes only harness invocation and the import alias;
production sources remain unchanged, and passing jobs were retained without
rerunning them. The final recovery supervisor exits zero.

This broad checkpoint covers the four rendering features and their measured
1,215,237,122-instruction reduction against the compact/native control. The next
reference for the same cache, viewport and drawing checkpoint is
2,599,008,091 instructions with source-manifest SHA-256
`45a6a2e5098d8577b4935f000c1a35fbfe2294e6a3081362dc8541d85acca435`.

## Provenance and reproduction

The original baseline was a literal working-tree snapshot captured while HEAD
was `98f69d16`, including then-existing modified and untracked browser files.
The source manifest, rather than that commit alone, identifies its exact bytes.
Both final matched graphs add the same committed compact heap policy
`1eb26abc` and native drawable/frame presentation from `5dacd60d`/`d11662f8`.
The exact matched runtime difference is six changed paths and five added
helper/test paths for this task's four rendering features.

| Identity | Control | Candidate |
| --- | --- | --- |
| Source-manifest SHA-256 | `27d06a658279dee7320cb7d5ebb3b704fdcaa38c6732c1f636d9039f1bbffe26` | `45a6a2e5098d8577b4935f000c1a35fbfe2294e6a3081362dc8541d85acca435` |
| Executable SHA-256 | `2a3363cd4db1d6a2bf5ab73c992da3465dd1ef83480955448cebe8603ff8c0e7` | `5230b12c47c69c59ecb92a17903da39f1be3d1d8c3f63ea4efc572912ead1a56` |

Both production builds use old V, C `-O2`, Boehm and the same native replay
library SHA-256
`46f0a3f9fa2e4cac09af21502d076ca7c3b1369ff84b6c1a5694e6c4f610a2cd`.
The regex and Rust-YUV archives are also pinned. Later independent workspace
changes are excluded from these measured graphs, including subsequent
heap-policy and idle-memory-maintenance experiments. The instruction and memory
figures apply to the pinned candidate, not to the currently mutable working
tree. The canonical application was not overwritten by this frozen build; the
reviewable candidate executable is
`Build/wikipedia-instructions-15/candidate-integrated/Vox`.

Evidence under `Build/wikipedia-instructions-15/` includes:

- `integrated-measurement-verdict.json`: combined instruction and memory results,
  original-reference comparison, sample retention and pinned evidence hashes.
- `instructions-integrated/summary.json`, `memory-integrated/summary.json` and
  their per-sample logs/JSON/crops: all final observations.
- `cohort-integrated-command.json`, `matched-integrated-source-delta.json`, the
  two `*-integrated-source-manifest.json` files and corresponding build commands,
  results and native-input pins: exact inputs and production builds.
- `viewport-equality-result.json`, `visual-anomaly-audit.json` and
  `visual-confirmation-result.json`: decoded pixel checks and retained anomaly.
- `integrated-headless-smoke-result.json`: production startup verification.
- `integrated-screenshots/result.json` and
  `integrated-screenshots/supervisor-exit.json`: the 19 native screenshot
  comparisons and immutable input checks.
- `integrated-broad/layout-recovery-result.json`,
  `integrated-broad/layout-recovery-supervisor-exit.json` and
  `integrated-broad/completed-union-audit.json`: the successful selected-test
  union, exact AST comparison and zero-exit audit. Earlier failed wrapper
  receipts remain alongside them.

`run-integrated-cohort.py` is the pinned task supervisor. New reproductions
should use a new output mode/name to preserve these observations. Reusable
observers are `tools/measure_browser_render.py` and
`tools/measure_browser_memory.py`; use explicit before/after binaries,
`--before-arg=--disable-javascript --after-arg=--disable-javascript`, the retained
cache template, five alternating pairs and the same 1024×768 viewport.
