# Wikipedia rendering: fewer allocations and instructions

Seven focused changes reduce mean retired instructions **11.90%** for Wikipedia
with JavaScript disabled against a fresh matched control, with all RAM medians lower. Rendering
retains the complete DOM, HTML/CSS and retained snapshots. All 20 CPU/RAM viewport
captures match the frozen reference exactly. Actual cohort supervisor exit is zero.

## Final matched results

The predeclared gate requires at least 10% fewer arithmetic-mean instructions,
with no median increase; settled and lifetime-peak footprint medians must also
not increase. Five alternating CPU pairs and five separate RAM pairs pass. All
rows are retained, without repeats; pair order alternates, starting before/after.

| CPU pair | Control instructions | Candidate5 instructions | Reduction |
| --- | ---: | ---: | ---: |
| 1 | 5,345,099,673 | 4,526,548,135 | 15.314% |
| 2 | 5,371,881,267 | 4,652,029,686 | 13.400% |
| 3 | 5,132,155,841 | 4,676,053,214 | 8.887% |
| 4 | 5,315,489,068 | 4,738,524,969 | 10.854% |
| 5 | 5,232,322,969 | 4,663,475,524 | 10.872% |
| Arithmetic mean | 5,279,389,763.6 | 4,651,326,305.6 | **11.897%** |
| Median | 5,315,489,068 | 4,663,475,524 | **12.266%** |

Pair 3 improves 8.887%, so a uniform 10% reduction is unsupported. Control range
is 5.132–5.372 billion instructions; candidate range is 4.527–4.739 billion.
One candidate time is 535 ms: there is no hard 500 ms or elapsed-speedup claim.

| RAM metric, MiB | Control | Candidate5 |
| --- | ---: | ---: |
| Median settled physical footprint | 339.540 | **332.447** |
| Median lifetime-peak physical footprint | 357.126 | **348.329** |
| Median settled resident size | 489.523 | 481.898 |
| Median kernel peak RSS | 507.297 | 498.453 |
| Median observed peak resident size | 506.453 | 497.656 |
| Median first-frame physical footprint | 308.376 | 304.939 |
| Median first-frame resident size | 457.891 | 453.641 |
| Highest lifetime physical-footprint peak | 358.736 | 354.079 |

RAM uses a five-second settle and pinned external roughly 5 ms observer; CPU
runs have no RAM polling. First-frame gaps span 6.101–7.718 ms, and steady-window
variation spans 7.534–9.098%. Kernel peak RSS differs from physical footprint.
Measurements cover one frozen document through screenshot/exit, not a long-term
memory bound. The first-frame readings follow the external drawing marker; they
are not exact checkpoint timestamps. Independent host workflows remained active;
one-minute load averages during the CPU cohort were 16.97–20.73.

The earlier candidate4 final remains a **failed 10% target**: mean 5.202→4.834
billion (-7.068%), median 5.233→4.827 billion (-7.755%). Settled/peak medians
339.540→335.814 / 357.095→352.720 MiB passed RAM gates; all 20 captures matched.
Its unchanged raw rows/verdict remain in `instructions-final/` and `memory-final/`.

## Seven focused changes

- `2c208bc9`: retain shadow geometry in one immutable managed payload only for
  shadow commands. Native culling/drawing, SVG and portable replay preserve
  rectangles/radii; nested replay shares storage and composes the common transform.
- `0b6d35d4`: keep rectangle corners in `[8]f32`, preserving winding, transforms,
  scroll and rounding. Native CGContext/GG synchronously borrow the coordinates,
  eliminating ordinary replay's temporary corner arrays.
- `2ed2e710`: recognize typed `none` backgrounds/masks and nonempty all-`none`
  lists before image-layer/context creation; mixed/active images retain their path.
- `b487c142`: allocate four uncommon Element maps in one managed payload on first
  relevant write. Absent reads/clears/removals allocate nothing; map identity,
  animation snapshots, random stability, adoption and fresh clone state remain.
- `708a240a`: skip length-resolution contexts for empty box/text shadow lists;
  nonempty unit, color, order, blur and spread resolution remain unchanged.
- `52fe2375`: update queued `:has()` property features in place, preserving
  identity, flags, empty keys and queue order. First records still schedule once.
- `ddfefde3`: allocate EventTarget handler-map storage on first handler write.
  Absent reads/removals/visits allocate nothing; handler/listener identity,
  callback retention, late compilation and reentrant hooks retain behavior.
  Activation still precedes publication, including nested different-name writes.

Generated-C/alignment analysis derives **PaintCommand 2,376→2,128 bytes** (-248,
10.44%) and **EventTargetData 176→64 bytes** (-112). The former has a rare
256-byte payload, independently checked by focused native tests, alongside a
2,140-byte command budget. These exact record sizes are derived layouts, not new
native `sizeof` prints. DOM embedding offsets remain zero; native C has no
hand-coded dependency on these record sizes/offsets.

An actual Boehm probe of 1,000 retained `Element.new` objects reports
**5,243,104→2,579,968 allocated bytes** (-2,663,136, 50.79%) for the four-map
Element slice; actual `sizeof(Element)` is **2,648→2,176 bytes**. The interval
excludes assertions/formatting/collections but includes inherited Node/event
storage and unique-ID work. This does not include the later handler-map change
and is not browser RAM. Both fixture executions have unchanged pins and exit zero.
For 1,024 repeated known-key property updates, allocation is **0 bytes** versus
**2,362,272 bytes** for the old collect/merge positive control in the same process.
First records/new keys still allocate; neither microprobe is credited as CPU speed.

Generated C proves four Element map initializers disappear from both factories.
Candidate5 C-only evidence shows nil handler storage and no eager handler-map
initializer in parser Element storage, `Element.new`, `Text.new_with_type` and
`EventTarget.new`; code generation exits zero without executing passing tests.

## Comparison scope and source closure

Both fresh builds retain frozen **64/64 active/idle GC divisors**, the existing
160 MiB static-document capacity hint, GC, environment overrides and unused-page
unmapping. No collector-policy change is credited. Both use old V, C `-O2`,
Boehm and native GG. Compiler/runtime/native dependencies/observers are pinned;
later independent adaptive/cooperative GC work is excluded. These are private GG
builds; ongoing UI2 and canonical-bundle work is outside this comparison.

Control source: `f16ed29ac84efc7c8c305526bdc60098b1835774a7413d8f6c7b82370c95c1be`.
Control executable: `a55d6fcfa9c8a1da7e436fef05ec0bd4dae4e1ebad8bbb963de194b31d85742d`.
Candidate5 production: `937cae2a60d5739a02be422e93a6441a084f97a9fc5b50dafaa968270fa837e6`.
Candidate5 validation: `9b667038657d92ddfa87400b5069522ddcb5a2e20155eb8fc078817c245d81f7`.
Candidate5 executable: `1a400e6660f7ec2be493edc4f8b5e67f50b651c4262f980b9911e0d7486a65a5`.
Shared native bridge: `97834a755eb05f33b1297791b38c854c1ed13cfcbdc96546532bd0e858afc45c`.
All **3,460 non-test files** match production/validation. Their **50 test-only
differences** are 49 migrated fixtures (422 accesses, 167 functions, all 3,664
assertion tokens preserved) and one four-case fixture.

The archived checkpoint in `Build/wikipedia-instructions-10/candidate4/` used
another native/compiler graph and 4/32 GC. Its 2,283,080,067
median, 2,404,975,543.8 mean and 400.6 MiB settled footprint are context only.
The historical preferred absolute mean/median targets remain **unmet**. Its prior
12.16% median gain was 7.47% by mean against 2,599,008,091. The old app cannot
honor away-pointer placement and is not relaunched; no same-closure claim is made.

The counter ends at `paint_timing.report_document_paint()` in `app.draw`, after
install/parse/resources/style/layout/native drawing, before bitmap-image/CALayer
commit. GPU/WindowServer, PNG and teardown are outside; this is not web FCP.
No work was moved ahead of the counter. Every row has one install, 836 commands,
JS disabled and zero JS runtime/sources/source bytes/preloads.
Each process loads `https://www.wikipedia.org/` at 1024×768 CSS pixels from a
fresh identical eight-resource cache, with snapshot reuse disabled and normal
resources/adblocking/background refresh enabled. HTML is 122,197 bytes, SHA
`5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`;
cache SHA `46c277c0b7df22c8b1d5c1c00d55b1a2548750e7257cbe04f0b927de9ce8e5fd`.
`VOX_TEST_WINDOW=1` places windows away from the pointer while preserving viewport
and foreground app. Task compilers/captures stay quiet during final cohorts.

## Verification and retained evidence

The final composite passes **640 selected test functions in each GC mode across
123 files**: 171 handler-focused functions carried from the identical production
source plus 469 fresh broad functions. All compilation/test and supervisor exits
are zero. Each mode has 639 asserting functions and one native function whose
non-macOS branch is inactive on this host. This is selected coverage, not the full
repository suite.

The unchanged official AST driver matches all **100 upstream fixtures exactly**.
All **19 screenshot comparisons pass**, with 16 pixel-exact, including all eight
live SVG/image mutation guards. `inline-node`, `text-decorations` and `canvas-text`
pass their existing bounds; no bound changed. The measured executable's
`--headless-smoke` and actual final validation supervisor both exit zero.
The browser uses JavaScriptCore; these checks do not establish full LibJS parity.

`final-measurement-verdict-c5.json` and the actual supervisor exit receipt bind
CPU/RAM summaries; independent audits recompute all 20 rows, medians/ranges,
first-frame gaps and byte-exact captures, and check actual binary/native hashes,
source/observer manifests and unchanged pin snapshots. Receipts include
`candidate5-independent-{cpu,final}-audit.json`, feature focused suites, ABI and
constructor-C audits, allocation probes and production/validation byte audit.
Initial failed fixtures/borrow attempts, diagnostic cohorts and the failed
candidate4 final are retained. No passing measurement was repeated or discarded.

All artifacts below are under `Build/wikipedia-instructions-next/`:

- `instructions-final-c5/summary.json` and `memory-final-c5/summary.json` retain
  every row, raw counters/readings, logs, captures, cache IDs and input pins.
- `candidate5-source-manifest.json`, `candidate5-validation-source-manifest.json`,
  `candidate5-production-validation-source-audit.json` and the build command/result
  pin the two source graphs and the measured `candidate5/Vox` executable.
- `final-measurement-verdict-c5.json`,
  `candidate5-authorized-final-cohort-supervisor-exit.json` and
  `candidate5-independent-final-audit.json` authenticate the performance result.
- `final-broad-c5/result.json`, `event-handler-focused/result.json`,
  `final-screenshots-c5/result.json`, `final-validation-c5-composite-audit.json`,
  `final-validation-c5-result.json` and
  `final-validation-c5-actual-supervisor-exit.json` authenticate final validation.

Reproduction uses the pinned observers in `harness/`, the retained cache template
and explicit before/after binaries. Keep the same 1024×768 viewport, JavaScript
disabled, five alternating CPU pairs and five separate RAM pairs. Preserve the
existing results and select new output paths for another run.

This broad checkpoint covers all seven implementation commits and the matched
**628,063,458 mean / 652,013,544 median** retired-instruction saving. Its next
same-closure reference is mean **4,651,326,305.6**, median **4,663,475,524** at the
source identities above. Additional measured savings after this batch: zero.
