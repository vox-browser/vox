# GitHub rendering investigation

Measured on macOS on 2026-10-13 and 2026-10-14 with `https://github.com/vlang/v` and the
repository's native browser. These are individual diagnostic runs, not an
upstream parity benchmark.

## CPU instruction measurements

Retired CPU instructions are now the primary work metric for subsequent
optimization. The older wall-clock observations below remain historical
diagnostics. `VOX_PROFILE_INSTRUCTIONS=1` enables native cumulative checkpoints
and exact process-counter intervals for installation and first frame submission.
It works with the normal signed GC build; neither V's function profiler nor the
allocation wrapper is enabled for these measurements.

The counter is `proc_pid_rusage(..., RUSAGE_INFO_V4, ...)::ri_instructions`.
Apple's [Recount documentation](https://github.com/apple-oss-distributions/xnu/blob/main/doc/observability/recount.md)
describes retired instruction accounting for tasks across their threads,
including kernel execution charged to them. GPU execution and external
services such as WindowServer are excluded. These are hardware counts, not
estimates from elapsed time or V function-call counts. This Mac exposes them
without elevated permissions; unsupported systems report unavailable counters.

Measured on arm64 Darwin 25.5.0, 2026-10-14, at a 1024×768 document viewport:

| Interval | Run 1 instructions | Run 2 instructions | Run 3 instructions | Median instructions |
| --- | ---: | ---: | ---: | ---: |
| Vox: document installation | 55,489,577,542 | 55,318,675,420 | 54,252,275,306 | 55,318,675,420 |
| Vox: installation through first native frame | 59,086,726,044 | 58,890,426,942 | 57,818,863,748 | 58,890,426,942 |
| Vox: navigation through first native frame | 60,461,541,528 | 60,265,796,423 | 59,237,360,447 | 60,265,796,423 |
| Vox: process start through exit after capture | 86,304,129,954 | 65,191,818,531 | 69,574,762,502 | 69,574,762,502 |
| Chrome: navigation through completed-document capture, observed descendants | 11,901,119,888 | 12,506,518,885 | 12,908,501,390 | 12,506,518,885 |
| Chrome: process start through completed-document capture, observed descendants | 18,749,106,807 | 18,953,252,883 | 19,193,385,077 | 18,953,252,883 |

Vox's final process counts were read while it was a zombie, before `wait()`
reaped it, and include capture and shutdown. All three runs observed one browser
process and obtained its final exit sample. The first-frame intervals end at
native frame submission and exclude subsequent capture-related work. The much
wider full-process range reflects additional work after first paint; use the
navigation/installation intervals when judging changes to initial rendering.

Chrome 155.0.8059.80 used a fresh isolated profile for each run. The tool observed
12 processes per run, including helpers, and waited for `readyState=complete`,
font readiness and populated GitHub file links before capture. All runs exposed
72 file/directory links. Child processes that disappeared before a final sample
retain their last observed count: respectively 3, 3 and 2 such processes in
these runs, with no permission failures. Short-lived children can also fall
between samples. Chrome's totals are therefore **observed-descendant lower
bounds**, explicitly marked in JSON, rather than exact complete browser totals.
Counting just Chrome's main PID would exclude its renderers and other helpers.

The endpoints and functionality differ. Vox loads cached HTML/resources and
still displays file-row placeholders because its module backend is incomplete;
Chrome navigates the live URL and renders populated rows. Native submission is
not web FCP. These counts establish remaining CPU work, not a controlled speed
ratio or Chrome parity. Instruction counts reduce scheduling/frequency noise
but still change with executed work, GC scheduling, background activity, and
network-dependent content.

The largest checkpoint intervals during Vox installation were:

| Checkpoint interval, summed across both initial layout passes where applicable | Median instructions |
| --- | ---: |
| Formatting contexts and preliminary layout attachment | 15,591,571,027 |
| External stylesheet installation | 14,487,559,899 |
| Box construction and intervening style updates | 13,039,227,394 |
| Script startup | 2,964,339,594 |
| Initial retained paint commands | 2,694,847,852 |

These are **adjacent cumulative checkpoint deltas** in log order. A checkpoint
can include preparatory work since the previous marker and other process
threads; it is not the self cost of the function named in the label. The
separate `install_total` and first-frame scopes overlap those deltas and must
not be added to them. Stylesheet installation, style/box construction and
formatting remain the primary targets for further instruction reduction.

The earlier saved `Build/v/Vox-gc-baseline` binary consumed 112,372,918,564
instructions through exit after capture in one run. It predates several
optimization rounds, lacks native scope counters, and is only a diagnostic
reference; this is not an isolated measurement of the counter instrumentation.

Raw logs, counts and captures are under
`Build/instructions/{vox,chrome}-github-counts.run-{1,2,3}.{json,log,png}`.
The measured Vox executable SHA-256 is
`7a29a1f9ab2985566d488b2a3bd8c75db99e362ef38123a3c617ddc14880bdab`;
Chrome's is `4dbcffd1126e00453193bc5cc6bf096f37a53fda8567516b22ec576c55e2df4e`.
The tool records each binary hash, kernel, input, viewport, per-process coverage,
phase deltas and native scopes. It captures only the document viewport in new
Vox runs, preserving a separate raw window PNG; the original measurement images
predate that crop and include the 112px browser chrome.

Reproduce with:

```sh
sh build-prod-browser.sh
python3 tools/measure_browser_instructions.py --engine vox --repeat 3 \
  --output Build/instructions/vox-github-counts
python3 tools/measure_browser_instructions.py --engine chrome --repeat 3 \
  --output Build/instructions/chrome-github-counts
```

Use `--binary PATH` for another executable, `--url URL_OR_LOCAL_FILE` for another
input, and `--scratch-dir PATH` to place Chrome's disposable profiles elsewhere.
This investigation's Chrome app is on `/Volumes/LoomScratch/vox2-github-performance/Google Chrome.app`;
the default command uses `/Applications/Google Chrome.app`. Chrome's interval
ends before observer-side PNG writing and browser shutdown. Vox's viewport crop
runs after its exit sample. The watchdog uses elapsed time only to terminate a
stalled run; the reported metric is instructions. No personal Chrome profile is
used.

Validation: the counter module's two V cases, eight Python accounting/ABI/native
counter cases, the signed production build and native `--headless-smoke` pass.
The Python tests exercise live counters and zombie exit counters as well as
descendant retention, PID reuse, missing final samples and overlapping scopes.
Native smoke also passes with instruction checkpoints enabled. The counter and
browser instrumentation are opt-in; adding those counters did not change the
GC/arena allocation policy. Subsequent heap-capacity tuning is described below.

## Controlled instruction optimization, 2026-10-14

The next rounds use a fresh copy of the same 359 cached page/resource files for
every run. The snapshot SHA-256 is
`0570cfa09af662a0f1fa6735a563bad9dc2d332579e75ef06d50931f6a3aae95`.
The benchmark now accepts `--cache-template` and fingerprints the actual copied
input in each JSON result. Browser writes and network refreshes cannot change
the next run's starting cache. Background networking still runs, so this is a
controlled starting input rather than an offline replay. First-frame intervals
exclude later document replacement and capture work.

| Stage, normal signed C `-O2` / Boehm build | Median installation instructions | Median navigation through first native frame |
| --- | ---: | ---: |
| After component/context reuse, hashed invalidation sets, glyph-buffer sharing, fixed-arity edge sums, and DOM/animation lookup fixes | 52,361,249,718 | 57,340,083,570 |
| Defer unused ordinary declarations in large DOM-owned stylesheets | 50,732,412,766 | 55,586,162,661 |
| Retain font metrics on handles; avoid selector-span and DOM-name copies | 48,728,232,208 | 54,572,198,152 |
| Replace temporary arrays in common layout predicates | 48,474,488,345 | 53,425,100,681 |
| Final build, including numeric query and on-demand selector-cache cleanup | 48,466,031,817 | 53,424,928,934 |

Each row uses three runs. The first row already includes several independently
committed improvements, so it is not the original browser baseline. The older
uncontrolled navigation median before those changes was 60,067,376,980
instructions; cache contents changed during that series, preventing an exact
combined percentage claim.

The final controlled first-frame median is 6.8% below the first controlled row.
Its three counts are 53,316,369,219; 54,590,522,853; and 53,424,928,934. The last
two allocation cleanups do not show a separate instruction gain beyond run
variation. The final executable SHA-256 is
`37e1dcb6e442a28dbb49b7f8e906308767302f589e8034933090f0cee0e4571c`;
it also incorporates concurrent native wheel-handler work.

The remaining adjacent checkpoint medians before first submission include
13,644,028,352 instructions for box construction/intervening style work,
13,181,838,433 across formatting-context passes, 9,475,639,474 for external
stylesheet installation, and 6,422,418,754 across retained paint-command stages.
These process-wide deltas identify the next areas to profile; they do not
attribute all work to those functions or isolate collector self cost.

The changes address measured allocation work:

- Ordinary CSS declarations reuse their parsed component tree and block parsing
  context. Invalidation features use hashed membership instead of comparing
  every previously inserted serialized key.
- Large DOM-owned sheets parse syntax and selectors eagerly, then materialize
  ordinary properties on matching or CSSOM access. Descriptors remain eager;
  custom properties, quirks context, resource ownership, and base URLs survive
  deferred conversion. Public parser APIs retain eager behavior.
- Cached shaped text shares glyph and replay buffers until layout edits them.
  Fixed-arity edge sums and common DOM type checks avoid temporary arrays.
- Immutable font handles retain pixel metrics. Missing explicit font sources
  remain retryable. Selector operator scans compare spans directly, hashes read
  string bytes directly, and unchanged lowercase DOM names reuse their input.
- Common display, overflow, selection, and whitespace checks use direct
  comparisons. The compatibility compiler otherwise allocates heap arrays for
  these two-value membership expressions.
- Numeric environment/container query values keep their canonical numbers
  without formatting unused text. Authored units and calculations still follow
  the existing typed resolution and serialization paths. One-shot selector
  matching allocates its relational cache only when it reaches `:has()`.

An allocation-stack diagnostic of the deferred build recorded 25,212,974 GC
allocation calls requesting 3,922,605,181 bytes through exit after capture.
It used C `-O0` and sampled allocation backtraces; its instruction totals are
excluded from the normal-build benchmark. It identified font-key construction,
selector scan substrings, media-value formatting, and temporary predicate arrays
as remaining allocation sources. Allocation counts and requested bytes are not
peak live memory or self instruction costs.

An experimental token-array arena view passed semantic and optimized forced-GC
retention checks but increased the controlled first-frame median to
62,145,958,194 instructions. It was removed. Keeping entire lexer arrays alive
appears to outweigh the avoided per-token boxes; this is an inference from the
measured regression, not a separately attributed GC instruction count.

GC stays enabled in the native browser. The font-metrics and selector-span tests
also pass with `-prealloc`; this does not establish ownership for replacing the
collector across live document graphs and shared caches. Ten Python benchmark
tests cover isolated cache inputs, cleanup after failure, native counters, and
process-tree accounting.

The signed final bundle passes native `--headless-smoke` and all 15 viewport
comparisons in `Build/v/instruction-opt-final-screenshots.log`: the eleven
configured smoke cases plus image source replacement, paint-server ID collision,
gradient-stop movement, and late pattern-image loading after referencer removal.
The four added SVG comparisons are pixel-exact. Focused CSS/DOM/font/layout
regressions pass, including optimized Boehm retention of deferred declarations
and glyph buffers, live media changes, missing-font retries, and fresh `:has()`
results after DOM mutation. No profiler or allocation wrapper is present in the
measured final bundle.

Raw controlled results are under
`Build/instructions/vox-controlled-{before,deferred}-*.run-1.json` and
`Build/instructions/vox-controlled-{font-selector,predicates,final}.run-*.json`. The retained
snapshot and its per-file manifest are in `Build/instructions/`.

```sh
python3 tools/measure_browser_instructions.py --engine vox --repeat 3 \
  --cache-template Build/instructions/github-cache-template \
  --output Build/instructions/vox-controlled
```

Chrome's earlier observed navigation/capture median remains 12,506,518,885
instructions. Its endpoint, process coverage, starting resources, and working
module execution differ from Vox's. These changes reduce Vox's work but do not
establish Chrome parity.

## Further fixed-cache instruction reduction

The next round uses the same snapshot and three runs per stage. Its fresh
baseline is the saved preceding build, rather than a new network response.

| Stage | Median installation instructions | Median navigation through first native frame |
| --- | ---: | ---: |
| Fresh preceding-build baseline | 48,669,853,599 | 53,505,472,316 |
| Reuse immutable unresolved style defaults | 48,252,629,730 | 53,928,672,486 |
| Collect rule buckets directly | 47,143,413,017 | 53,057,966,448 |
| Source-size heap-hint prototype and allocation-free bidi classification | 37,787,118,615 | 42,626,718,364 |
| Final build with DOM-size heap-capacity hint | 37,554,213,581 | 42,443,808,462 |

The final navigation median is **20.7% lower** than this round's baseline;
installation work is 22.8% lower. The three final navigation counts are
42,443,808,462; 43,423,925,473; and 42,072,804,594. The executable SHA-256 is
`212b47bd29be89be86f1118f648cbc7965782718b491ec4bb4be25f91ac96a70`.
First-frame counts include animation/paint work and remain more variable than
installation counts; the template change alone did not resolve a first-frame
gain. No Chrome speed or functionality parity is established.

The computed-style constructor now shares immutable unresolved layout defaults,
while each style owns its property array, flags, and mutable maps. Resolution
replaces the defaults. This avoids constructing nested length and unused
optional payload graphs for every element. Candidate-rule lookup now iterates
attributes directly, reserves one bucket vector, and reuses lowercase ASCII
attribute names. Bucket ordering, namespace behavior, and existing Unicode
folding are preserved. Bidi classification evaluates its class once before the
membership check, allowing the compatibility compiler to emit comparisons
instead of a temporary array.

### Collector capacity experiment

Repeated early collection/growth is a material source of CPU work. On one
unchanged saved binary, varying only `GC_INITIAL_HEAP_SIZE` produced:

| Initial heap | Median first-frame instructions, billions | Median peak process physical footprint, MiB |
| --- | ---: | ---: |
| Default | 52.241 | 1,596.6 |
| 256 MiB | 48.264 | 1,599.4 |
| 512 MiB | 41.757 | 1,647.1 |
| 768 MiB | 38.028 | 1,811.8 |
| 1 GiB | 33.666 | 1,941.0 |
| 2 GiB | 26.080 | 2,725.5 |

These are three-run medians, not isolated collector self-instruction counts.
The 512 MiB choice gives a substantial work reduction with a modest peak-memory
increase. Larger heaps reduce instructions further at a much larger memory
cost; none establishes Chrome parity.

After parsing, the browser now counts up to 2,048 light-DOM elements and calls
`GC_expand_hp()` only when that threshold is reached, requesting the shortfall
to a 512 MiB heap before style/layout work. This is a capacity hint, not a
memory cap or an arena, and GC stays enabled. Smaller DOMs retain normal growth.
Existing `GC_INITIAL_HEAP_SIZE` or `GC_MAXIMUM_HEAP_SIZE` settings take precedence,
and a refused expansion leaves ordinary allocation working. Repeated
navigations do not reserve another 512 MiB once capacity is sufficient.

The initial source-size trigger was refined because a large comment could
qualify a tiny DOM. In single diagnostic runs, the padded-comment fixture's
peak fell from 435.5 to 394.0 MiB with the DOM guard. The final GitHub build
retains the instruction improvement and reached a 1,638.1 MiB median peak
physical footprint, about 42 MiB above the unchanged-binary default probe.

Memory is measured with `ri_lifetime_max_phys_footprint` and observed
`ri_phys_footprint` from the same rusage V4 ABI as instructions. Peaks cover the
whole process lifetime through capture/exit, not just first paint. The standard
benchmark now records root and per-process peaks, retains earlier samples when
a later sample loses metadata, and never sums peaks from different processes.

An eight-token allocation-chunk prototype also passed optimized forced-GC and
`-prealloc` retention tests. It increased installation work to a 48.975 billion
median versus 47.143 billion before it, so it was removed. Its raw counts and
source snapshot remain under `Build/`; fewer allocation calls alone were not a
valid reason to keep it.

The signed final build, native smoke, focused style/rule-cache/font/layout
regressions, optimized retention tests, and heap-policy checks with both Boehm
and `-gc none` pass. Eleven Python counter tests pass. All 17 final viewport
comparisons pass: fifteen existing cases, a padded-comment input that must keep
normal heap growth, and a dense hidden DOM that reaches the reservation
threshold. The four SVG mutation cases remain pixel-exact. Raw measurements are
`Build/instructions/vox-opt2-{before,style-template,rule-bucket,heap-hint}.run-*.json`
and `vox-opt2-{dom-heap,gc-*}.run-*.json`; validation logs are under
`Build/v/instruction-opt2-*`.

For another explicit memory/work tradeoff, the existing collector setting is
respected without changing the build:

```sh
GC_INITIAL_HEAP_SIZE=1073741824 python3 tools/measure_browser_instructions.py \
  --engine vox --cache-template Build/instructions/github-cache-template \
  --repeat 3 --output Build/instructions/vox-gc-1g
```

## Sparse layout storage and paint preparation

A fresh native sample and allocation-stack diagnostic identified sparse layout
pages, expected subgrid map misses, unused optional paint payloads, coordinate
walks, and visual-layer array copies as remaining allocation work. The diagnostic
counted 19,368,346 managed allocation calls requesting 3,754,801,539 bytes through
capture/exit. It used C `-O0` and sampled backtraces; its instruction totals are
not normal-build measurements or function self costs.

The normal signed C `-O2` builds were then interleaved five times each, rotating
their order and copying the same immutable cache snapshot for every run:

| Build | Median installation instructions | Median navigation through first native frame | Median process peak physical footprint, MiB |
| --- | ---: | ---: | ---: |
| Saved preceding build | 37,837,758,274 | 43,610,299,125 | 1,661.6 |
| Compact pages, empty paint payloads, coordinate walks, and layer-stack reuse | 35,823,050,650 | 41,583,891,499 | 1,643.8 |
| Also compact hidden debug guides in the replay buffer | 34,849,369,922 | 40,419,781,629 | 1,626.0 |

The final median uses **7.3% fewer first-frame instructions** and 7.9% fewer
installation instructions than the interleaved baseline. Its five first-frame
counts are 40,419,781,629; 40,643,501,821; 40,317,833,624; 40,430,983,296; and
39,240,788,918. Compaction alone reduces the first-frame median 2.8% versus the
preceding optimized build. Earlier three-run and five-run series also varied,
so their small changes must not be added together or attributed entirely to
individual functions.
Peak memory covers the entire process through capture/exit, not just first paint.

Sparse geometry pages now contain inline nullable pointer slots rather than a
separately allocated array of optional records. Committed geometry retains its
ordinary collector ownership; intrinsic probes retain their existing bounded
allocation chunks and explicit release. Subgrid lookups guard expected misses
before reading the map, avoiding the compatibility compiler's error allocation.

Paint commands explicitly default absent payloads to `none`. Otherwise this
compiler constructs unused image/video positions and gradient defaults before
wrapping them as absent. Generated C now omits those length constructors.
Ordinary coordinate walks use an allocation-free cycle check; malformed cycles
still use the former guarded traversal and count each distinct record once.
Visual-layer lowering reads immutable retained paths and trims its private stack
instead of cloning both arrays for each command. It preserves the payload of an
already-open prefix when a later path has the same scope identity.

A follow-up diagnostic sampled every allocation of at least 64 KiB as well as
sparse smaller calls. It recorded 18,778,186 calls requesting 3,593,463,020 bytes
through capture/exit, before debug-guide compaction. The copied filter buffer
alone requested 80,175,456 bytes across four recordings: each `PaintCommand`
occupies 5,704 bytes. The final change removes this copy by stably compacting the
newly replayed buffer in place. Retained phase buckets keep their guides, and
turning guides on and off preserves both the cache and earlier recordings.
These diagnostic totals include later frames and are not isolated first-frame
allocation counts. Large compatibility paint-tree and command buffers remain
material targets; GC tuning alone does not remove their work.

GC remains enabled, with the existing DOM-gated 512 MiB capacity hint and worker
policy. Three-run probes on the unchanged preceding binary with `GC_MARKERS`
set to 1, 2, or 4 produced first-frame medians of 41.521, 41.726, and 41.623 billion
instructions. Their small, overlapping differences do not justify a new default.
Neither this round nor the earlier Chrome lower-bound comparison establishes
Chrome speed or functionality parity; GitHub module hydration remains incomplete.

The controlled comparison's executable SHA-256 is
`27e11875063ff5f8b2a24c3564c45511613f1a59c2c07b538b467f2d9460ce8f`.
Raw final results are `Build/instructions/vox-opt3b-interleaved-{before,previous,compaction}-[1-5].run-1.json`.
Earlier five-run results use `vox-opt3-interleaved-{before,defaults,final}-[1-5].run-1.json`;
the individual three-run stages use `vox-opt3-{layout-storage,paint-default,paint-offset,final}.run-*.json`.
Collector probes use `vox-opt3-gc-markers-{1,2,4}.run-*.json`. All interleaved runs
record the same cache fingerprint documented above.

Focused layout-state/arena, paint transport, typed adapter, text-run, and
document-tree suites pass. Sparse storage and release also pass with `-gc none`;
storage, coordinate, and visual-layer tests pass with C `-O2` and pointer-aware
Boehm collection, as does the repeated guide-toggle/cache-retention test. The
signed measured build passes `--headless-smoke` and all
17 viewport comparisons: the existing fifteen-case set plus
`abspos-inside-opacity-inside-relpos` and
`visual-context/backdrop-filter-inside-filter-layer`. All four SVG mutation
cases and both added position/filter cases are pixel-exact.

Validation logs use `Build/v/instruction-opt3-*`. All seventeen final compaction
comparisons pass in `instruction-opt3-compaction-screenshots.log`. They use the
exact saved measured executable through a copy of the normal capture helper
with rebuilding disabled. Earlier screenshots triggered an unsuccessful
automatic rebuild during concurrent wheel-handler edits; those in-progress
sources are outside the controlled measured snapshot.

The compaction build uses the normal build script from a pinned source snapshot
under `Build/opt3-pinned-source`, preserving the preceding build's wheel code
while the independent edits were in progress. It writes the same signed `Build/v/Vox.app`;
the saved measured executable is `Build/v/Vox-opt3-compaction-bin`. Archived
tests have a `.v.txt` suffix so normal test discovery does not run them twice.
The source-tree build outputs are linked to the repository's existing outputs.

After the independent wheel work was committed, the current checkout was built
again with `sh build-prod-browser.sh`. The integrated bundle passes signature
verification and `--headless-smoke`; its SHA-256 is
`2aae73baffa39798d7f3a127ffbfe9f736769d14b3cabc22d5f7276f47aa7823`.
Three integration measurements give first-frame counts of 40,754,046,316;
40,726,892,057; and 40,469,323,798, with a 34,819,209,201-instruction installation
median. These include the updated wheel code and are recorded separately as
`Build/instructions/vox-opt3-integrated.run-*.json`, rather than replacing the
interleaved comparison with a different source snapshot.
The integrated bundle also passes the four SVG mutation comparisons and the
backdrop/filter-layer comparison, all pixel-exact, in
`Build/v/instruction-opt3-integrated-screenshots.log`.

## Shared retained media snapshots

The allocation diagnostic's large paint-tree and command buffers led to another
storage change. Every compatibility layout box and every paint command embedded
image, canvas, video, and nested-document geometry, including text and border
commands which use none of it. These immutable geometry records now live behind
optional references and are allocated only when present. The typed adapter
creates the snapshot once; retained commands share it. Replacing source geometry
installs a new snapshot while earlier recordings keep their original geometry.

On the measured arm64 build, `PaintCommand` shrinks from 5,704 to 4,488 bytes
(21.3%), and `BlockBox` from 6,432 to 5,216 bytes (18.9%). This reduces buffer
initialization, copies, and collector scanning without dropping paint state.
The snapshots remain GC-owned because recordings can outlive their source tree.
The collector policy, DOM-gated heap hint, and intrinsic-measurement arena are
unchanged; the browser does not use global `-prealloc`.

The normal signed C `-O2` builds were interleaved five times each, reversing
their order on alternate iterations. Every launch received a fresh copy of the
same immutable GitHub cache snapshot documented above:

| Build | Median installation instructions | Median navigation through first native frame | Median process peak physical footprint, MiB |
| --- | ---: | ---: | ---: |
| Preceding integrated build | 35,237,266,612 | 40,542,953,366 | 1,654.7 |
| Shared out-of-line media snapshots | 34,430,229,156 | 38,904,617,957 | 1,544.2 |

The first-frame median falls **4.0%**, installation 2.3%, and process peak memory
6.7% (110.5 MiB). The five final first-frame counts are 38,904,617,957;
39,486,173,932; 37,854,260,087; 38,916,534,972; and 38,032,921,234.
Peak footprint covers the process through capture/exit. A command-only pilot
reduced footprint but its three instruction counts overlapped the baseline;
the table measures the final change across both boxes and commands, without
attributing the complete difference to either field layout in isolation.
Chrome parity remains unestablished, for the endpoint and functionality reasons
described above.

The implementation and focused tests are in commit `ba00aca9`.
The baseline executable is `Build/v/Vox-opt3-integrated-bin`, SHA-256
`2aae73baffa39798d7f3a127ffbfe9f736769d14b3cabc22d5f7276f47aa7823`.
The final executable is `Build/v/Vox-opt4-shared-media-bin`, SHA-256
`4d78170793c19e7c0107c70f38cd43a59453f87c4f7b6ad31f3b4d2446c3cad4`.
It was built from the current checkout with the normal build script's GC and
optimization flags, adding only `-keepc` to inspect generated ownership.
The same binary is installed in `Build/v/Vox.app`.
Raw measurements are `Build/instructions/vox-opt4-interleaved-{before,final}-[1-5].run-1.json`;
`vox-opt4-interleaved-summary.json` records their medians. The earlier pilot
uses `vox-opt4-media.run-{1,2,3}.json`.

The focused snapshot suite checks absent payloads and record-size bounds,
geometry replay and bitmap retention after forced collection, shared identity,
and preservation of older image geometry after source replacement. It passes
with C `-O2` and the production pointer-aware Boehm collector, with ordinary test
settings, and with `-gc none`. Paint transport, typed adapter, and retained
debug-guide compaction suites also pass, as do signature verification and native
`--headless-smoke`. The exact saved measured executable passes the same seventeen
viewport comparisons used in the preceding round, including all four SVG
mutation cases and both position/filter cases pixel-exact. These use a copy of
the normal capture helper with rebuilding disabled so later source edits cannot
replace the measured executable. Validation logs use `Build/v/instruction-opt4-*`;
the viewport results are in `instruction-opt4-shared-media-screenshots.log`.

## Retained selected-font metrics

A fresh allocation-stack diagnostic, together with the earlier V `-profile`
call counts, identified repeated native font construction in CSS `line_height()`
and font-relative length contexts. Although `platform.Font` already caches its
decoded face and pixel metrics, these callers constructed a temporary handle,
cloned its strings, and discarded that cache after each query.

The selected `PlatformFont` now retains a native metrics handle. Cache hits
validate the family, CSS pixel size, integer weight, and explicit source path
consumed by the existing bridge. Changed inputs create a replacement handle;
previous handles retain their original values. The existing native metrics
cache still retries an unavailable explicit source instead of retaining its
temporary fallback. The implementation and focused tests are in `2807ba3c`.

The late-file test also exposed an existing glyph-unit cache error: it keyed
advances by requested family/source/weight, allowing a fallback's raw advance
to be scaled using the subsequently loaded face's units per em. Commit
`5c5382e4` keys those units by the actual decoded face and code point instead.
The process font-face cache retains those identities for its lifetime. Aliases
of the same concrete face can share units, and regular/bold collection faces
remain distinct. This also removes family-name normalization from those lookups.

Five normal signed C `-O2` runs per build were interleaved, reversing order on
alternate iterations and copying the same immutable GitHub cache each time:

| Build | Median installation instructions | Median navigation through first native frame | Median process peak physical footprint, MiB |
| --- | ---: | ---: | ---: |
| Preceding shared-media build | 33,696,355,216 | 39,222,539,247 | 1,541.8 |
| Retained metrics handles and decoded-face glyph keys | 33,229,651,184 | 37,651,905,505 | 1,548.0 |

The first-frame median falls **4.0%**, installation 1.4%. Median lifetime peak
footprint increases 6.3 MiB (0.4%), rather than showing a memory reduction.
Final first-frame counts are 37,651,905,505; 37,511,148,463; 37,393,358,563;
38,485,450,601; and 39,796,348,449. The ranges overlap and one paired final run
uses more instructions than its baseline; collector scheduling and background
work still affect these process-wide intervals. The table reports this round's
comparison rather than adding its percentage to earlier rounds. It does not
establish Chrome parity or complete GitHub module hydration.

Separate C `-O0` allocation diagnostics count 18,778,053 managed calls requesting
3,289,932,917 bytes before, and 17,718,245 calls requesting 3,275,761,085 bytes
after. Both use the same cache and record four layout-tree/paint-command
checkpoints through capture/exit. The wrapper samples one mixed-sequence call
in 4,096 for stacks; the former line-height allocation stacks disappear from
the sample, and font-context stacks become much less frequent. These whole-run
totals are not first-frame allocation counts or normal-build instruction costs.
GC policy and intrinsic-measurement arenas remain unchanged.

The baseline executable is `Build/v/Vox-opt4-shared-media-bin`, SHA-256
`4d78170793c19e7c0107c70f38cd43a59453f87c4f7b6ad31f3b4d2446c3cad4`.
The final is `Build/v/Vox-opt5-font-metrics-bin`, SHA-256
`114fb2ec163c5e5d3640cab537147c6ffc789e995a1ce1fcd86fd3f9be501fd2`,
also installed in `Build/v/Vox.app`. The build uses the normal script's GC and
optimization flags, adding only `-keepc` for ownership inspection.
Results are `Build/instructions/vox-opt5-interleaved-{before,final}-[1-5].run-1.json`
and `vox-opt5-interleaved-summary.json`. Allocation diagnostics are
`vox-opt5-{allocation-diagnostic,final-allocation-diagnostic}.run-1.{json,log}`.
An earlier, non-interleaved handle-only pilot uses
`vox-opt5-font-metrics-only.run-{1,2,3}.json`; it is not the final comparison.

New tests exercise fractional-size retention after forced collection, every
bridged input change, shared line-height/length metrics, replacement after style
mutation, delayed font-file appearance, and glyph advances across face aliases
and sizes. Both new suites pass with C `-O2` and pointer-aware Boehm, and with
`-gc none`. Existing computed-length-cache, font-cascade, layout-node, and native
pixel-metrics suites pass, as do signed-bundle verification and native startup
smoke checks. The exact saved measured executable passes nineteen viewport
comparisons: the previous seventeen-case set plus `css/line-height-zero` and
`select-line-height-ignored`. Both added cases and all four SVG mutation cases
are pixel-exact. The capture helper uses the saved executable with automatic
rebuilding disabled. Logs use `Build/v/instruction-opt5-*`; final ownership
results are in `instruction-opt5-font-final-{retention,gc-none}-tests.log`,
and screenshots in `instruction-opt5-font-metrics-screenshots.log`.

## CSS serialization fast paths

The remaining allocation stacks included number and identifier serialization.
Numbers previously used fixed-point formatting even for ordinary integers,
then copied the string once for every trailing zero removed. Commit `6897fa31`
formats exact signed 32-bit integers directly and trims fractional tails with
one scan and at most one substring copy. Larger values retain the fixed-point
formatter. Negative zero, six-decimal rounding, and non-finite spellings stay
unchanged, including the existing documented large-number deviation.

Commit `143018d3` lets ASCII identifiers which need no escaping retain their
immutable input string. Leading digits, a hyphen followed by a digit, a lone
hyphen, punctuation, controls, and non-ASCII input retain the existing Unicode
escape path. This avoids the rune array and builder for ordinary names.
Tokenizer source-slice copies remain a separate material allocation source;
the earlier ownership wording above has been corrected accordingly.

Five normal signed C `-O2` runs per build were interleaved, reversing order on
alternate iterations. Every run copied the same immutable GitHub cache:

| Build | Median installation instructions | Median navigation through first native frame | Median process peak physical footprint, MiB |
| --- | ---: | ---: | ---: |
| Preceding selected-font build | 34,494,815,746 | 39,066,355,139 | 1,565.5 |
| Number and identifier serialization fast paths | 33,818,055,305 | 37,623,859,617 | 1,552.3 |

The first-frame median falls **3.7%**, installation 2.0%, and lifetime peak
footprint 13.2 MiB (0.8%). Final first-frame counts are 37,211,164,239;
38,629,283,450; 38,413,122,416; 37,623,859,617; and 37,452,740,909.
The ranges overlap; one paired final run is slightly higher than its baseline.
These are local process-wide medians with collector/background variation, not
isolated function self costs. They must not be added to earlier percentages or
treated as proof of Chrome parity; GitHub module hydration remains incomplete.

A separate C `-O0` allocation diagnostic counts 16,783,869 managed calls
requesting 3,253,776,646 bytes through capture/exit, versus the preceding
17,718,245 calls requesting 3,275,761,085 bytes. Both record four layout-tree and
paint-command checkpoints with the same cache. Uniform mixed-sequence stack
samples for number serialization fall from 165 to 55, and identifier samples
from 86 to 1. These samples are not absolute function call counts, and the
diagnostic instruction totals are not normal-build measurements. GC settings
and intrinsic-measurement arenas are unchanged.

The baseline executable is `Build/v/Vox-opt5-font-metrics-bin`, SHA-256
`114fb2ec163c5e5d3640cab537147c6ffc789e995a1ce1fcd86fd3f9be501fd2`.
The final is `Build/v/Vox-opt6-css-serialization-bin`, SHA-256
`e25adf422d56108a3a3a57372972d3ce0e63fcf1ca283ea27bb6f50f6d2a67bb`,
also installed in `Build/v/Vox.app`. The normal build flags are unchanged;
only `-keepc` was added for generated-code inspection.
Raw measurements use `Build/instructions/vox-opt6-interleaved-{before,final}-[1-5].run-1.json`
and `vox-opt6-interleaved-summary.json`; the allocation diagnostic uses
`vox-opt6-final-allocation-diagnostic.run-1.{json,log}`.

The number tests check explicit rounding/special-value boundaries and over
20,000 integer/fractional cases against the existing fixed-precision formatter
and integer spellings, including magnitudes from `1e-308` to `1e308`. Identifier
tests cover ASCII and Unicode escape boundaries and retain a dynamically
created identifier after its producer exits and forced collections run.
Both new suites pass with ordinary settings, C `-O2` plus pointer-aware Boehm,
and `-gc none`. Component-text and shorthand serialization suites pass, as do
signature verification and native startup smoke checks. Validation logs use
`Build/v/instruction-opt6-*`. The exact saved measured executable passes the
same nineteen viewport comparisons used in the preceding round, including the
four SVG mutation cases and both added line-height cases pixel-exact. These use
the normal capture helper copied with automatic rebuilding disabled; results
are in `instruction-opt6-css-serialization-screenshots.log`.


## Rejected transient glyph-run wrapper arena

A uniform allocation-stack sample identified short-lived `GlyphRun` forks in
intrinsic sizing. An experiment placed their wrappers in GC-scanned chunks of
sixteen inside the existing scalar-measurement arena. Shared glyph buffers and
fonts kept their normal ownership; cache-miss shapes retained separate heap
copies. Thirty-three layout cases plus two platform fork cases passed in both
GC modes, including forced collection, with the three new lifetime cases also
passing C `-O2`. An initial fixture used value equality instead of pointer
identity; the corrected fixture produced those passing results.

Five interleaved normal-build pairs did not show an instruction improvement:
first-frame medians were **36,930,617,480 before** and **37,056,480,856 with the
arena**, a 0.34% increase within the observed variation. Separate C `-O0`
allocation diagnostics with three layout/paint checkpoints each counted
16,227,567 calls requesting 2,999,170,913 bytes before and 16,039,725 calls
requesting 3,006,068,290 bytes afterward. Fewer allocation calls alone did not
justify retaining the change. The wrapper arena was removed; the existing
`UsedValues` measurement arena and normal GC policy remain in place.

The rejected source patch, fixture, pinned-source manifest and executable are
retained under `Build/v/instruction-opt7-*`,
`Build/v/measurement-glyph-run-arena-test.v.txt`, and
`Build/v/Vox-opt7-glyph-arena-bin`. The five-pair reports and summary use
`Build/instructions/vox-opt7-interleaved-*`. Three candidate runs installed a
second document after their first frame, so only the first installation and
first-frame scopes were compared; through-exit work and lifetime footprints
are not comparable for those runs.

## Reusing immutable CSS token spellings

The allocation profile also showed duplicate strings for ordinary identifiers:
the tokenizer copied the decoded name and then copied the identical source
span again. Unescaped identifiers now share that one immutable spelling.
Escaped identifiers retain their decoded value and exact source separately,
using an explicit escape flag rather than assuming equal byte lengths imply
equal text. Single printable ASCII spellings, newline, tab and empty spans use
terminated literals. ASCII delimiter values reuse a matching single-byte
source spelling; other code points and differing source text retain conversion.
Every shared spelling remains NUL-terminated for native C interfaces.

Ten normal signed C `-O2` runs per build were interleaved, reversing order on
alternate pairs. Both builds use the same source snapshot at `59ecd8a0`, shared
build/branding inputs, compiler flags, and immutable GitHub cache; only the token
spelling implementation differs. This holds concurrent event-handler changes
outside the performance comparison. Normal GC remains pointer-aware Boehm, and
`-keepc` is the only added inspection flag.

| Build | Median installation instructions, rounded | Median navigation through first native frame, rounded |
| --- | ---: | ---: |
| Matching baseline | 33,597,969,650 | 38,208,989,604 |
| Shared token spellings | 33,327,901,674 | 36,911,794,184 |

The first-frame median falls **3.4%** and installation **0.8%**. Eight of ten
paired first-frame counts improve; the ranges overlap. These are process-wide
local measurements, including collector and repaint variation, rather than
isolated tokenizer self costs. The initial five-pair first-frame difference
was 6.5%; extending to ten pairs reduced the estimate. No percentages are added
to earlier rounds, and Chrome parity is not established. The earlier Chrome
observed-descendant lower bound has a different endpoint and workload; GitHub
module hydration remains incomplete in Vox.

The baseline executable is `Build/v/Vox-opt7-pinned-before-bin`, SHA-256
`ef4db860f1ae23ce56a819a9de32ee7d375afd906efdaf8c3bb57d3be12499c8`.
The candidate is `Build/v/Vox-opt8-token-spelling-bin`, SHA-256
`ff94dfc7104b160a751e3860fb6f0ee0fd9aa47b34ee94f78554576fb937194a`.
`Build/v/instruction-opt8-source-manifest.json` records the source and build-input
hashes. Raw counter reports are
`Build/instructions/vox-opt8-interleaved-{before,final}-{1..10}.run-1.json`, with
`vox-opt8-interleaved-summary.json`. All twenty reports use cache fingerprint
`0570cfa09af662a0f1fa6735a563bad9dc2d332579e75ef06d50931f6a3aae95`,
record one installation, and retain an exit sample for the root process.

The four new cases verify shared identifier storage, all 95 printable ASCII
spellings, all 128 ASCII delimiter code points, terminating zeros, Unicode,
escape decoding including equal-length substitutions, and retention after the
producer returns and forced collections run. The combined seven-file batch
passes all 26 cases in both GC modes, and the four new cases pass with C `-O2`
and Boehm. The original extended fixture had a mixed `u32`/`rune` array compiler
error; only the corrected runs receive those passing results. Validation uses
`Build/v/instruction-opt8-*-corrected-test.log` and the focused-test manifest.


A separate C `-O0` allocation diagnostic now records counters at the first-frame
report, avoiding the varying number of later paint passes through capture/exit.
The matching first-frame marks count **15,670,829 to 14,921,105 managed V
allocation calls** (749,724 fewer, 4.8%) and requested bytes
2,746,023,786 to 2,741,336,374 (4,687,412 fewer). These are allocation-wrapper
counts and requested bytes, not live memory or normal-build instruction costs.
The earlier through-exit diagnostics had three versus four layout/paint
checkpoints and are not used to attribute allocation gains. Scoped diagnostics,
summary, generated C and wrapper use `Build/instructions/vox-opt8-{before,final}-allocation-scopes*`,
`vox-opt8-first-frame-allocation-summary.json`, and
`Build/v/native_allocation_scope_profile.h`.

The exact saved candidate passes all nineteen viewport comparisons: sixteen
pixel-exact and the existing bounded tolerances for `inline-node`,
`text-decorations`, and `canvas-text`. The four SVG mutation cases and both
added line-height cases are exact. Native startup smoke passes, and the signed
private app bundle verifies with the exact same executable bytes as the saved
candidate. These checks use `Build/v/instruction-opt8-{pinned-smoke.log,pinned-signature-result.json,token-spelling-screenshots.log,screenshot-summary.json}`.

Broad validation for instruction optimization is now batched after each
additional **5,000,000 measured instructions saved**, using the same benchmark
endpoint and workload. Focused checks remain per fix. This batch crossed that
threshold, and its completed 26-case/two-GC and nineteen-screenshot runs are the
new performance verification baseline at `cc8c4e7c`; no additional broad suite
is run merely for the documentation or cadence update.


The canonical `Build/v/Vox.app` was also rebuilt with the token-spelling change
and the independent native handler changes already present in `cc8c4e7c`.
The CLI interrupted its first native compilation; the saved generated C and
original response-file flags were used to complete the backend and signing.
In-bundle signature verification and headless startup pass. Its executable
SHA-256 is `94ff47186ba5e27892bb2ea89fc9078cbd6382d207e7ad7bb2358dd1191df512`;
`Build/v/instruction-opt8-integrated-build-result.json` and
`instruction-opt8-integrated-smoke.log` retain the result. Instruction medians
above belong to the matching pinned comparison, rather than this separately
integrated binary.

## Sparse animation invalidation and streamed SVG paths

Animation invalidation now visits the union of the two sparse animated-property
maps instead of probing every longhand twice. This removes expected-miss error
allocations while preserving additions, removals, semantic equality, shorthand
exclusion, and the union of invalidation flags. SVG path serialization now
appends commands directly to one builder instead of building command strings,
arrays of formatted numbers, and a second array for the complete path. Number
formatting, command case, spacing, and the uppercase close command are unchanged.
These changes are `546b7b83` and `d31999c9`, each with three focused cases.

The SVG microbenchmark alternated five pairs of ten serializations of a path
containing 4,096 cubic commands and a close command. Median counts fell from
**273,071,398 to 230,882,778 instructions**, or **15.4%**. It also runs the final
three semantic/retention cases with C `-O2` and Boehm. This is a helper-specific
result, not a measured GitHub page improvement. The fixture and reports are
`Build/v/opt9-path-microbenchmark-test.v.txt` and
`instruction-opt9-svg-{optimized-microbenchmark.log,microbenchmark-summary.json}`.

Ten interleaved native GitHub pairs did **not** establish a page-level gain:

| Build | Median installation instructions, rounded | Median navigation through first native frame, rounded |
| --- | ---: | ---: |
| Matching control | 33,340,875,358 | 36,773,773,336 |
| Sparse animation maps and streamed paths | 33,393,506,154 | 36,839,600,671 |

Installation increased 0.16% and first-frame instructions increased **0.18%**;
three of ten paired first-frame counts improved, with heavily overlapping
ranges. The managed-allocation diagnostic counts 14,921,172 to 14,792,339 calls
before first paint, requesting 2,741,339,421 to 2,738,588,542 bytes: 128,833 fewer
calls and 2,750,879 fewer requested bytes. Fewer allocations and the isolated SVG
gain do not establish a browser-wide instruction reduction. No positive savings
are credited toward the next 5,000,000-instruction broad-test threshold, and the
prepared broad unit/screenshot batch was skipped.

Both normal builds use C `-O2`, pointer-aware Boehm, identical shared libraries,
and the same immutable GitHub cache. The control restores only the three prior
V-generated animation/SVG function bodies in the exact captured candidate C;
the previously unreferenced instruction serializer is restored before the path
serializer. Concurrent native media handler changes are therefore common to
both builds. This construction and its function/source hashes are recorded in
`Build/v/instruction-opt9-control-provenance.json`; the captured V source manifest
records no source changes during the candidate build. Raw normal-build counts
and summary use `Build/instructions/vox-opt9-interleaved-*`; scoped allocation
diagnostics use `vox-opt9-{before,final}-allocation-scopes*` and
`vox-opt9-first-frame-allocation-summary.json`. C `-O0` allocation instrumentation
is not used for the normal-build instruction comparison.

The matching control executable is `Build/v/Vox-opt9-control-bin`, SHA-256
`a9b0b5380335b094eaf95024d3a0a39639cd9ee6be022caf294ee70d664a528d`.
The candidate is `Build/v/Vox-opt9-final-bin`, SHA-256
`b7c59ca6b6f4c1f6bd4759f8a95f56f11be01b86fce3dfdde7d4e4931176a5b2`.
Both use the preceding round's cache fingerprint. All twenty runs record one
document installation and a final root-process exit sample. The six new cases
pass in both GC modes; the animation cases also pass C `-O2`, and the final SVG
cases pass C `-O2` in the microbenchmark fixture. The canonical signed
`Build/v/Vox.app` contains the exact saved candidate bytes and passes native
startup smoke and in-bundle signature verification. Evidence is in
`Build/v/instruction-opt9-*-test.log`, `instruction-opt9-smoke.log`, and
`instruction-opt9-signature-result.json`. GC and arena policy are unchanged.
Chrome instruction or functionality parity remains unestablished.

The follow-up layout trace found that the two initial geometry passes are not
duplicates: two pending size-query containers require reevaluation, which
changes ten descendants' `display` values (`flex` to `none` and `block` to
`inline-block`). The second pass rebuilds for those changes. It was retained.
The C `-O0` diagnostic and capture are saved as
`Build/v/instruction-opt10-layout-trace*` and
`Build/instructions/vox-opt10-layout-trace.run-1.log`; their instruction counts
are not normal-build performance results.

## Rejected ASCII CSS decoding shortcut

A follow-up experiment reused ASCII input for the canonical `utf-8` label,
avoiding a TextDecoder construction and a UTF-16 round trip for every such CSS
parser input. CR/FF/NUL filtering remained in the tokenizer; non-ASCII input
and other labels retained their decoder. Four cases covered all ASCII bytes,
BOM handling, malformed UTF-8, alternate encodings, token positions, and token
retention after the producer returned and collections ran. They passed in both
GC modes and with C `-O2`. The C `-O2` fixture also ran its instruction loop,
but the successful V test runner suppressed that loop's counter output; no
isolated decoding instruction numbers are claimed from it.

Ten interleaved normal C `-O2` pairs showed a first-frame regression:

| Build | Median installation instructions, rounded | Median navigation through first native frame |
| --- | ---: | ---: |
| Retained animation/SVG control | 33,255,771,839 | 36,636,857,516 |
| ASCII decoding experiment | 33,073,972,251 | 37,528,208,124 |

Installation improved **0.55%**, but first-frame instructions increased
**891,350,608 (2.43%)**, with nine of ten paired first-frame counts worse.
The separate allocation diagnostic nevertheless counted 14,792,339 to
14,537,213 managed calls and 2,738,588,542 to 2,705,547,605 requested bytes
through first paint: 255,126 fewer calls and 33,040,937 fewer requested bytes.
A separate normal-build GC-statistics pair observed 29 versus 30 collections
by first paint, demonstrating changed collector pacing. That one diagnostic
pair does not attribute the entire median difference to GC. Allocation-call
reductions alone remain insufficient evidence of a page-level instruction gain.

The experiment was committed at `97c69dfb` and reverted at `def3c1cb`.
Its source and four tests remain in
`Build/v/instruction-opt10-rejected-ascii.patch`, with the optimized fixture at
`Build/v/opt10-decoding-microbenchmark-test.v.txt`. Raw counters and summary use
`Build/instructions/vox-opt10-interleaved-*`; allocation reports use
`vox-opt10-ascii-allocation-scopes*` and
`vox-opt10-first-frame-allocation-summary.json`. GC diagnostics use
`vox-opt10-{before,final}-gcstats*` and
`Build/v/instruction-opt10-gcstats-summary.json`.

The saved control is `Build/v/Vox-opt9-final-bin`, SHA-256
`b7c59ca6b6f4c1f6bd4759f8a95f56f11be01b86fce3dfdde7d4e4931176a5b2`.
The rejected candidate is `Build/v/Vox-opt10-ascii-bin`, SHA-256
`c55d81e515c36c01bf81c99d606263635e220b9940669f48bd4a8a375458fe98`.
Both use the same immutable cache fingerprint and the same freshly rebuilt
shared library, SHA-256
`4eef3aa87146e510d851b5993358a1bbd15dc5d727a1d7872769cdba90f8cd14`.
That library remained unchanged through all twenty runs. It differs from the
preceding round's library artifact; no cross-round instruction difference is
credited to this rebuild.

An independent media-handler commit landed after V generated the candidate C.
The initial source guard stopped the comparison. The captured C was then
compared against the saved control: replacing just the decoder body made all
code agree after normalizing generated anonymous/local identifiers, assertion
line numbers, and qsort-helper ordering. The later `bc80a4b7` media changes are
absent from both executables. This evidence is recorded in
`Build/v/instruction-opt10-source-comparison-proof.json`; the full captured C is
`instruction-opt10-candidate.c`. All twenty measured runs record one document
installation and a final root-process exit sample.

The canonical `Build/v/Vox.app` was restored to the retained control's exact
executable bytes and passes signature verification and startup smoke with the
current shared library. Its pinned source predates `bc80a4b7`. Results are in
`Build/v/instruction-opt10-{restored-bundle-result.json,restored-smoke.log}`.
Neither this experiment nor the preceding animation/SVG comparison credits a
positive first-frame saving. The prepared 71-case/two-GC and nineteen-viewport
broad batch was skipped; the last completed performance broad baseline remains
`cc8c4e7c`, with zero new credited instructions saved toward the next 5,000,000.

## Shared background paint snapshots

The retained-paint investigation found another large optional payload embedded
in every command: a computed background layer and its CSS length-resolution
context. Text, border, and other commands paid for that storage when they had
no background. Commit `63b148e1` moves those values to one immutable,
GC-owned snapshot per recorded background layer. Phase caches and subsequent
display-list copies share it. Replay still resolves image and gradient geometry
using the retained context, clipping, and current scroll state.

The normal arm64 layout shrinks `PaintCommand` from **4,488 to 4,128 bytes**,
an **8.0%** reduction. Each actual background snapshot occupies 368 bytes;
ordinary commands retain no snapshot. This storage reduction is not itself a
page-level instruction result. Four focused cases cover absent payloads,
font-relative and percentage geometry after forced collections, replacement of
the source background, and snapshot identity across cache/display-list replay.
They pass with Boehm, `-gc none`, and C `-O2`; two existing background geometry
cases also pass. The optimized test log records the executed cases and sizes at
`Build/v/instruction-opt11-background-optimized-test.log`.

Ten interleaved pairs, reversing order on alternate pairs, measured:

| Build | Median installation instructions | Median navigation through first native frame |
| --- | ---: | ---: |
| Matching control | 33,350,721,723 | 37,825,806,661 |
| Shared background snapshots | 33,372,598,403 | 36,743,307,516.5 |

The first-frame median falls **1,082,499,144.5 instructions (2.86%)**;
installation changes **+0.066%**. Seven of ten paired first-frame measurements
improve, with a median paired saving of 768,923,607.5. Ranges overlap: control
36.644–40.203 billion, candidate 36.584–39.288 billion. These are observed
normal-build counts, not an extrapolation from command size. Raw reports and
summary use `Build/instructions/vox-opt11-interleaved-*`; paired evidence is
`Build/v/instruction-opt11-comparison-evidence.json`.

Four control runs and one candidate run install another document after the
first-frame scope has ended. Their log ordering is checked in the paired
evidence. The primary comparison always uses the first
`navigation_to_first_document_paint` interval and first installation, excluding
that later work. All twenty runs record a final root-process exit sample.
Post-capture process totals are not the optimization metric.

The matching control is `Build/v/Vox-opt11-control-bin`, SHA-256
`a595ec5f452d5e90955a7f5babbd7648c3bb2a64c0ce1a0aca602c5f37f78fce`.
The measured candidate is `Build/v/Vox-opt11-background-bin`, SHA-256
`941491ec45f1024ffe218d67aee0246ffb9943ee12acd7af6368c006316c7676`.
A focused before/after native viewport covering fractional font-relative
geometry, repeat modes, gradients, URL layers, blending, fixed/transformed
backgrounds, and content-box clipping is **pixel-exact**. Its fixture, log, and
images use `Build/v/instruction-opt11-background-reference.html`,
`instruction-opt11-background-visual.log`, and
`Build/comparisons/instruction-opt11-background/`.

Both page-comparison binaries use the normal C `-O2` and pointer-aware Boehm
configuration. The control is captured at `e881de58`, and the candidate's
background implementation is `63b148e1`. Five generated handler/bootstrap
function bodies restore the independently added `loadedmetadata`/`loadeddata`
guard expansions to the control behavior; no background changes are restored.
Function hashes and normalized-body agreement are recorded in
`Build/v/instruction-opt11-matching-provenance.json`. Both V generation manifests
record stable source files during capture. The comparison loads the same frozen
bridge library, SHA-256
`4eef3aa87146e510d851b5993358a1bbd15dc5d727a1d7872769cdba90f8cd14`,
from `Build/v/opt11-shared/`; loader traces verify the path for both binaries.
The GitHub cache fingerprint is unchanged. GC and arena policy are unchanged:
recorded commands can outlive their producer, so these snapshots require
retained ownership.

The measured saving crossed the 5,000,000-instruction cadence threshold. One
broad batch passes **61 selected cases in each GC mode** (31 CSS, 10 SVG,
20 layout) and **19 native viewport comparisons**, with 16 pixel-exact. The
three remaining comparisons use the existing bounded tolerances for
`inline-node`, `text-decorations`, and `canvas-text`; all four SVG mutation
comparisons remain exact. The layout aggregate's initial import-alias error
prevented compilation; only those two failed fixture compilations were retried
after correcting the alias. Production code and test bodies were unchanged.
Evidence uses `Build/v/instruction-opt11-{broad-*,screenshots.log,validation-result.json}`
and `Build/comparisons/instruction-opt11-batch/`.

This is the new broad-verification baseline at `63b148e1`, with the measured
candidate's **36,743,307,516.5** first-frame median. Additional savings since
that completed batch reset to zero. The matching comparison establishes a Vox
improvement; the different Chrome workload and rendering endpoint still prevent
a Chrome-parity claim.

The original, unmodified captured candidate C was also compiled with the
completed metadata/first-data handler additions, using runtime sources captured
at `867c5728`. That separately integrated executable is
`Build/v/Vox-opt11-integrated-bin`, SHA-256
`cd7b6ef3e955994c510aa4b6c6079d156f2dfe205b31db68d72198de82425f41`,
and passes startup smoke. During its compilation another build replaced the
canonical app. The install guard preserved that independently built app:
its executable contains the new background-snapshot helper and passes startup,
strict signature verification, and a pixel-exact focused viewport comparison
against the measured candidate. Its executable SHA-256 is
`598f9031f0ebd9a8b13929a0b2b2729ca4a4f4a10dd826966163f8a9f08b59d2`;
its complete source revision is not attributed. Evidence uses
`Build/v/instruction-opt11-{integrated-source-manifest.json,integrated-smoke.log,bundle-result.json,bundle-visual.log,bundle-signature.log}`.
The page medians above belong to the pinned matching comparison, rather than
either separately built executable.

## Shared SVG gradient paint snapshots

Commit `df931f85` removes the four inline optional SVG gradient styles from
`PaintCommand` and retains them in one immutable `PaintSVGGradientData`
snapshot. Ordinary commands and solid-color SVG paths retain no snapshot;
gradient-painted paths share their snapshot across phase caches and display-list
copies. The native solid-path fast path checks the absent snapshot directly.
Gradient readers retain the same optional value semantics, including linear
and radial fill/stroke geometry, transforms, spread, and color interpolation.

Force-dark creates a replacement snapshot and replacement stop arrays for each
resolved command, preserving the author snapshot shared by other commands or
earlier recordings. Four new cases cover absent payloads, all four retained
gradient slots after the producer returns and forced collections run, force-dark
isolation, replay identity, and replacement after a live SVG stop mutation.
Those four cases and seven existing gradient/resource/force-dark cases pass in
both GC modes. Their aggregate and logs are
`Build/v/opt12-svg-focused-test.v.txt` and
`instruction-opt12-focused-{boehm,none}.log`.

The four new cases also pass with C `-O2` and Boehm, including their forced
collections and live mutation checks. The executed diagnostic records
**3,240 bytes per command**, down from 4,128: **888 bytes (21.5%)** smaller.
An actual gradient snapshot occupies 928 bytes and is shared by copies of its
command; this is a command-storage measurement, not a claim that every
gradient-painted path uses 21.5% less total memory. The fixture and complete
executed test output are `Build/v/opt12-svg-optimized-test.v.txt` and
`instruction-opt12-optimized-test.log`.

Ten valid interleaved pairs, reversing order on alternate pairs, measured:

| Build | Median installation instructions | Median navigation through first native frame |
| --- | ---: | ---: |
| Matching background-snapshot control | 33,342,377,657 | 36,878,826,334 |
| Shared SVG gradient snapshots | 32,252,656,852.5 | 36,159,520,428 |

The first-frame median falls **719,305,906 instructions (1.95%)** and installation
falls **1,089,720,804.5 (3.27%)**. Eight of ten paired first-frame counts improve;
the median paired saving is 1,140,056,577. Ranges overlap: control
36.574–38.080 billion, candidate 35.429–37.922 billion. These are normal-build
hardware counts, not a projection from the command-size reduction. Four control
runs install a refreshed document after the first-frame interval has ended;
the comparison uses the first installation and first navigation scope. All
twenty valid runs have a final root-process exit sample.

One initial candidate capture produced a 1728×880 window instead of the
requested 1024×880. The existing observer geometry check rejected it after the
browser exited successfully. Its log and PNG remain under
`Build/instructions/vox-opt12-interleaved-final-8-invalid-viewport.run-1.*`;
the comparison resumed the remaining pairs without rerunning completed pairs.
Its first-frame count is 37,722,486,923. As a sensitivity check, substituting
that count for the retry gives a candidate median of 36,704,044,356.5, still
174,781,977.5 instructions (0.47%) below the control. That invalid-geometry
capture is not included in the matching-viewport performance result.

Raw valid reports and summary use `Build/instructions/vox-opt12-interleaved-*`.
Paired differences, refresh ordering, and capture-failure sensitivity are in
`Build/v/instruction-opt12-comparison-evidence.json`. The control executable is
`Build/v/Vox-opt12-control-bin`, SHA-256
`4a541b1758823ec1a4e7c5ea92bdfaeedfad239fd08e03ee888b26a51176b8d3`.
The candidate is `Build/v/Vox-opt12-gradient-bin`, SHA-256
`08b4be2ad7096ffc589893e4582dac5a993c96d6a4f292f34a637be29ff2916b`.
A focused native before/after viewport with linear/radial fill and stroke,
linked/transformed gradients, mixed patterns, masks, and solid SVG paths is
**pixel-exact**. Its fixture and log use
`Build/v/instruction-opt12-gradient-{reference.html,visual.log}`; images are in
`Build/comparisons/instruction-opt12-gradient/`.

The control and candidate are separate normal C `-O2`, pointer-aware Boehm
builds. Both V-generated C captures record no runtime source changes during
generation. Their only four runtime source differences are this feature's
transport, snapshot helpers, force-dark, and native consumer changes; no
generated function substitutions are needed. The source manifests, native
commands, and hashes use `Build/v/instruction-opt12-*`, including
`instruction-opt12-matching-provenance.json`. Both comparison binaries load the
frozen `Build/v/opt12-shared/libLadybirdVSkiaText.dylib` and the same immutable
GitHub cache. GC and arena policy are unchanged.

The measured saving crossed the next 5,000,000-instruction threshold. One
broad batch passes **80 cases in each GC mode** (31 CSS, 10 SVG, 39 layout)
and **19 viewport comparisons**, with 16 pixel-exact. The three remaining
comparisons use the existing tolerances for `inline-node`, `text-decorations`,
and `canvas-text`; all four SVG mutation cases remain exact. Results are in
`Build/v/instruction-opt12-validation-result.json`, the `instruction-opt12-broad-*`
and `instruction-opt12-screenshots.log` logs, and
`Build/comparisons/instruction-opt12-batch/`. The new performance broad baseline
is `df931f85` at **36,159,520,428** first-frame instructions. Additional savings
since the completed batch reset to zero.

The signed canonical `Build/v/Vox.app` contains this candidate's code and passes
startup smoke and strict signature verification. Runtime source hashes still
match the captured candidate; later commits changed independent test fixtures.
Bundle signing changes the executable hash to
`e334eba8eec2344722c4bcdd1b7095ff31ac40d9ae7ea79b4bc009cb8bbdee31`;
the saved standalone comparison binary above retains its measured bytes.
Evidence uses `Build/v/instruction-opt12-bundle-{result.json,smoke.log,signature.log}`.

The remaining candidate checkpoint medians include **11.004 billion**
instructions in formatting-context intervals, **8.572 billion** in box-building
intervals, and **4.551 billion** in stylesheet installation. These are adjacent
checkpoint deltas before first paint, summed by label per run and then median,
not function self costs or additional costs to add to the overlapping native
scopes. They are recorded in `Build/v/instruction-opt12-remaining-checkpoints.json`
to guide the next profiling pass. Chrome functionality and instruction parity
remain unestablished.

## Initialize intrinsic geometry only when used

Feature `1e35047a` removes eager construction of all sixteen `UsedValues` records
when an intrinsic-measurement chunk is allocated. Each requested record already
receives its complete `UsedValues{}` defaults on first use. Constructing every
slot first repeated that work and initialized slots that short probes never use.
The empty line-box array headers do not themselves allocate native buffers at
C `-O2`; the removed work is default initialization and copying.

The chunk keeps its original fixed-array layout and one scanned allocation.
`vcalloc` leaves unused slots zeroed; the existing per-slot assignment installs
valid optional and array defaults before a record is exposed. The existing
probe-boundary release, chunk capacity, committed geometry ownership, and GC
policy are unchanged. No global `-prealloc` or GC disabling is introduced.

A fresh native sample exercises this allocator during intrinsic layout. A
separate headless diagnostic calls the normal binaries' paged-store allocation
and scalar-probe release functions for **10,000 probes of eight records each**.
Hardware snapshots surround that loop inside one debugger expression, excluding
debugger stop/step overhead and state-factory setup. Three interleaved pairs
measure median **78,066,647 → 58,105,102 instructions**, a **25.57%** reduction;
all three pairs improve. This isolates geometry allocation/initialization and
release; it is not a measurement of complete intrinsic layout or page loading.
The six counts and exact diagnostic scope are in
`Build/v/instruction-opt13-inprocess-probe-result.json`, with the expression and
logs under `instruction-opt13-inprocess-*`. Earlier debugger step-out counts
include trap overhead and are excluded from the saving claim.

Ten normal-build GitHub pairs, reversing order on alternating pairs, measure:

| Build | Median installation instructions | Median navigation through first native frame |
| --- | ---: | ---: |
| Matching eager-initialization control | 32,237,342,342 | 36,645,898,548.5 |
| Initialize requested records only | 32,175,571,592 | 36,500,209,444.5 |

The observed first-frame median is **145,689,104 instructions lower (0.40%)**,
but only **six of ten pairs improve**. A paired bootstrap interval for the
median saving spans **−390,541,355 to +1,343,835,733.5** instructions. This small
whole-page difference remains within the observed variation; a repeatable page
saving is not established. Installation's observed reduction is 61,770,750
instructions (0.19%). All twenty runs have valid capture geometry, exactly one
document installation, and final root-process exit samples; none were rerun.
Raw reports and the cohort summary use
`Build/instructions/vox-opt13-interleaved-*`; paired statistics and the remaining
checkpoint medians are in `Build/v/instruction-opt13-comparison-evidence.json`.

Both comparands include the same concurrent native media-handler updates. The
control uses the common captured V-generated C with only the eager arena
allocator restored from the preceding verified capture. Its restored function
matches an independent V generation from the original source byte for byte;
all six referenced geometry/chunk record definitions are also identical. Every
other generated C byte is shared, and both native builds use identical C `-O2`
flags, objects, pointer-aware Boehm, and the frozen rendering library. The
restoration audit and independent verification are in
`instruction-opt13-control-{generation-result,verification-result}.json`;
source, flags, and hashes are in `instruction-opt13-matching-provenance.json`.
The immutable GitHub cache fingerprint remains
`0570cfa09af662a0f1fa6735a563bad9dc2d332579e75ef06d50931f6a3aae95`.

The observed page median crossed the requested 5,000,000-instruction trigger,
so one broad batch ran: **87 cases in each GC mode** (31 CSS, 10 SVG, 46 layout)
and **19 native viewport comparisons**, with 16 pixel-exact and the same three
bounded differences as the preceding baseline. Seven focused checks also pass
with GC disabled and with optimized C `-O2`/Boehm, including forced collections,
complete defaults across chunk boundaries, release/reuse, pointer stability,
and nested allocations retained after their producer returns. The focused
flex/grid/table intrinsic viewport is pixel-exact before/after. A temporary
capture-helper permission failure occurred before the first broad screenshot;
only that capture batch resumed, preserving the completed unit results.
Evidence uses `instruction-opt13-{validation-result,focused-*,screenshots}.json`
(or `.log`) and `Build/comparisons/instruction-opt13-{intrinsic,batch}/`.

The new broad-test baseline is `1e35047a` at **36,500,209,444.5** observed
first-frame instructions, with zero additional savings accumulated. The ledger
credits no established whole-page saving for this noisy result; the allocator
microbenchmark is recorded separately. Chrome instruction and functionality
parity remain unestablished, including the existing GitHub module-hydration gap.

The signed canonical `Build/v/Vox.app` contains the measured candidate's code,
passes startup smoke and strict signature verification, and has the same
`__TEXT,__text` hash as the saved standalone binary. The control SHA-256 is
`8dc29e9f0008472c8bf24fa3e8c163316259ecc50adaf14d3c028608d29da97a`;
the candidate is `3665b98650cb37ddb21836c764c22e41779e1c9bb2aa21143202b1dc435d9b6a`.
Bundle signing changes the installed executable hash to
`b01846ea4edc0b3155936b0170ac7b429f4481083eaabab4b25564b6e65f92c0`.
Bundle evidence uses `Build/v/instruction-opt13-bundle-*`. Relaunch Vox to use it.

## Coalesce native paint recording during frame preparation

Feature `31ba3356` keeps layout synchronous while delaying the native shell's
paint-command assembly until frame preparation finishes. A single native draw
can install the cached document, process callbacks, resize, sample animations,
and set the screenshot scroll offset before presenting pixels. Previously,
`relayout()` recorded immediately, so GitHub's initial layout and animation
update each assembled a list before its first submitted document frame.

The shell now records after those updates. DOM geometry and explicit display-
list queries remain synchronous; a pending shell refresh adopts even an already
cached list after a document replacement. Nested native frames flush their own
current commands while preserving the outer frame's deferral. Relayout calls
outside native frame preparation still record immediately. Focused checks cover
mutations, animation transforms, synchronous geometry and paint queries, nested
frames, replacement documents, scrolling, editable carets, callback order and
exceptions, and layout-tree-only mode. All eleven pass with Boehm and with GC
disabled, using the production native feature defines and libraries. The
focused C test builds are unoptimized; the measured browser binaries use normal
C `-O2`, Boehm, and the old V compiler without `-prod` or `-prealloc`.

An initial focused-test link command omitted the native bridge libraries;
relinking the unchanged generated test C with the correct libraries resolved it.
An attempted retention of Clang's temporary optimized object preserved its empty
initial inode, so the focused tests were rebuilt without C optimization. These
setup failures are retained under `Build/v/instruction-opt14-focused-*`; no
behavior assertions failed. The production builds already had the complete
native link command and were unaffected.

The first ten interleaved pairs observed **36,316,430,487 → 35,660,421,509.5**
first-frame instructions (1.81% lower), but only seven pairs improved and the
paired bootstrap interval included zero. Before taking more samples, the run
was extended to a fixed **thirty pairs** with the same saved binaries, cache,
flags, shared library, viewport, endpoint, and alternating order. The first-ten
reports remain separate from the thirty-pair summary. No runs were discarded.

| Build | Median navigation through first submitted native document frame |
| --- | ---: |
| Immediate shell recording | 36,316,430,487 |
| Deferred shell recording | 35,155,866,846 |

The thirty-pair first-frame median falls **1,160,563,641 instructions (3.20%)**.
Twenty-two pairs improve. The paired median saving is **1,157,509,205**; its
95% percentile bootstrap interval is **165,262,518 to 1,896,450,137.5**
instructions (30,000 paired resamples, seed 14). The one-sided sign probability
is 0.0081. Every control records twice and every candidate once before the
first frame. The paint-command checkpoint interval totals are lower in all
thirty pairs; those adjacent checkpoint intervals are diagnostic rather than
renderer self costs, and work can move between them. The unchanged first-frame
scope is the page comparison. Installation intervals no longer cover the same
work because their eager paint now runs later in frame preparation.

All sixty captures have valid native geometry and exactly one installation
before the primary endpoint. Candidate pair 19 additionally installs a live
background refresh **after** that endpoint. Native draw reports first-frame
instructions before it starts the pending network navigation, so that refresh
cannot enter the reported primary count. The run is retained, and its later
installation and final capture are not used as page-work comparators. This is
recorded in the evidence rather than silently discarding or rerunning it.

Raw reports use `Build/instructions/vox-opt14-interleaved-*`; the thirty-pair
summary is `vox-opt14-interleaved-30-summary.json`. First-ten statistics remain
in `instruction-opt14-comparison-evidence.json`; the complete comparison,
interval diagnostics, hashes and refresh audit are in
`Build/v/instruction-opt14-30-comparison-evidence.json`.

The control is a fresh C capture before the change; runtime source manifests
show only `main.v` and the new `main_frame_paint.v` differ. Both captures remained
stable during generation, and native commands match except for their C input
and binary output. All 120 shared object/archive inputs retain their recorded
hashes. The control binary SHA-256 is
`6b0e767dffae1d38cbec4531232de146ec1219417537c82f3838507cd8b7b619`;
the candidate is
`57b4cb60ea60c70fa79c2a2e7be56db9bc0b4e143e7630385d663b71958fb965`.
The frozen native library and immutable GitHub cache retain the preceding
round's fingerprints. Capture manifests, flags, input hashes, and installation
guards are in `Build/v/instruction-opt14-matching-provenance.json`.

The first-ten observed median crossed the 5,000,000-instruction trigger, so
**one** broad batch ran: 87 selected CSS/SVG/layout cases in each GC mode and
19 native viewport comparisons, 16 pixel-exact. The same three bounded
screenshot differences remain. The focused intrinsic flex/grid/table viewport
is also pixel-exact before/after. Extending the instruction comparison did not
repeat the broad batch. Evidence is in
`Build/v/instruction-opt14-validation-result.json`,
`instruction-opt14-broad-*`, `instruction-opt14-screenshots.log`, and
`Build/comparisons/instruction-opt14-{intrinsic,batch}/`.

The new broad-test baseline is `31ba3356` at **35,155,866,846** first-frame
instructions. The 1,160,563,641 measured saving is included in that verified
baseline, with zero additional savings accumulated toward the next 5,000,000.
Chrome instruction and functionality parity remain unestablished, including
the existing GitHub module-hydration gap.

The signed canonical `Build/v/Vox.app` contains the measured candidate, passes
headless startup and strict signature verification, and has an identical
`__TEXT,__text` hash to the saved candidate. Bundle signing changes its installed
executable SHA-256 to
`d55690f5cd2bef86b5720261946d8b3cca2c8be67635a642dc3a66036d112ac5`.
Evidence uses `Build/v/instruction-opt14-bundle-*`. Relaunch Vox to use it.

## Native CSS pixel ties-to-even rounding

Feature `0f4faeec` replaces the software `math.round_to_even()` conversion in
`CSSPixels.nearest_value_for()` with Clang's fixed-rounding intrinsic. The
AArch64 production code uses `FRINTN`; it does not read the ambient rounding
direction as `rint()` or `nearbyint()` would. NaN handling and raw integer
saturation remain unchanged, and other V C compilers retain the portable path.
The earlier `v -profile` dump (`Build/v/github-v-profile.txt`) recorded 38.3
million calls to this conversion across its multiple-layout diagnostic; that
count identifies the hot path, not one isolated GitHub navigation.

Four new focused tests cover positive and negative halfway cases, representable
neighbors of ties, saturation boundaries, NaNs, infinities, signed zero,
subnormals, 8192 deterministic float bit patterns, and all four ambient rounding
modes. Together with fourteen existing CSS pixel tests, all **18 cases pass in
both GC modes**, including C `-O2` with Boehm. This changes arithmetic work rather
than ownership: production retains Boehm and JavaScriptCore, without global
`-prealloc` or V `-prod`.

The normal optimized candidate inlines every use of the small conversion and
has no standalone nearest-value symbol, so the initial direct-call debugger
diagnostic could not run against it. That setup result is retained under
`instruction-opt15-inprocess-*`. A second diagnostic measures the unchanged,
retained `CSSPixelPoint.from_values()` entry point in both normal binaries. It
performs two pixel roundings per call. Across three interleaved pairs of one
million calls, the median is **121,107,471 → 67,031,682 instructions (44.65%
fewer)**. All checksums match an independent expected sum of −1,073,728. Hardware
snapshots inside the debugger expression exclude stop/trap overhead; the
identical expression loop remains in both counts. This is a point-construction
diagnostic, not a page measurement. Evidence is
`Build/v/instruction-opt15-point-probe-result.json` and its command/log files.

Thirty interleaved GitHub pairs were fixed before observing results. Both
binaries use normal C `-O2`/Boehm, the same frozen native library and immutable
cache, fresh cache copies, a 1024×768 viewport, and alternating pair order.

| Build | Median navigation through first submitted native document frame |
| --- | ---: |
| Portable pixel rounding | 34,985,509,358 |
| Native pixel rounding | 34,612,742,404 |

The matched first-frame median falls **372,766,954 instructions (1.07%)**.
Twenty-two pairs improve; the paired median saving is **319,311,618.5**.
Its 95% paired percentile bootstrap interval is **126,125,054 to 534,252,632.5**
instructions (30,000 resamples, seed 15), and the one-sided sign probability is
0.0081. All sixty captures have valid geometry and one installation per run,
with no later refresh installations. Both builds retain two required geometry
passes and one shell paint recording before the primary endpoint. No runs were
discarded. The first native `navigation_to_first_document_paint` scope remains
the comparison; process-exit totals and diagnostic intervals are separate.

The control reuses the previous measured candidate after verifying every
captured runtime source hash against the workspace before editing. The C
captures differ only in the rounding function after normalizing generated
anonymous-function file indices and multi-return temporary names; all 120
common object/archive inputs retain their hashes. Provenance is in
`Build/v/instruction-opt15-matching-provenance.json`; the fixed sampling plan is
`instruction-opt15-measurement-plan.json`. Raw reports and summary use
`Build/instructions/vox-opt15-interleaved-*`, with paired evidence in
`Build/v/instruction-opt15-comparison-evidence.json`.

The measured saving crossed the 5,000,000-instruction trigger, so **one** broad
batch ran: 87 selected CSS/SVG/layout cases in each GC mode and 19 viewport
comparisons, 16 pixel-exact. The same bounded differences remain for inline-node
(13 pixels), text-decorations (1341), and canvas-text (1994). The focused
intrinsic flex/grid/table viewport is pixel-exact before/after. Evidence is
`Build/v/instruction-opt15-validation-result.json`, `instruction-opt15-broad-*`,
`instruction-opt15-screenshots.log`, and
`Build/comparisons/instruction-opt15-{intrinsic,batch}/`.

The new broad-test baseline is `0f4faeec` at **34,612,742,404** first-frame
instructions, with this saving included and zero additional instructions saved
toward the next 5,000,000. Compare against the matching current control above;
the preceding round's historical median is a separate sample. Chrome
instruction and functionality parity remain unestablished, including the
existing GitHub module-hydration gap.

The signed canonical `Build/v/Vox.app` contains the measured snapshot. Before
installation its executable and code section matched the unchanged installed
control exactly. Concurrent media progress/suspend source work appeared after
capture; it remains in the workspace and is not included in this measured
snapshot. The installer therefore guarded the exact installed control plus the
owned optimization sources, rather than overwriting a newer independently
built app. The candidate and installed `__TEXT,__text` hashes match, and strict
signature verification and headless startup pass. A missing Python import in
the initial verification helper stopped installation before any copy; only
installation/verification resumed after correction, preserving the completed
unit, screenshot and instruction results.

The control SHA-256 is
`57b4cb60ea60c70fa79c2a2e7be56db9bc0b4e143e7630385d663b71958fb965`;
the candidate is
`09db0c5e0d1f84c79816e854ad1f05925b2afd8eee2214c815579e55b1f3cfd2`.
Bundle signing changes the installed executable hash to
`98b7473632294a02824ebe7161d84a19dac006bbc727e434ae8952e08f716f1e`.
Installation guards, later source differences and signature/code checks are in
`Build/v/instruction-opt15-bundle-*`. Relaunch Vox to use it.

## Indexed layout ancestry

Feature `27011ca9` records preorder subtree ranges during the existing geometry
indexing pass. Indexed ancestry queries compare bounds instead of repeatedly
walking parent links. A shared validity record is invalidated by child mutation,
and queries use the original parent walk until reindexing. Physical owner
addresses keep copied nodes from borrowing another node's range. Partial subtree
reindexing invalidates enclosing ranges; unstyled nodes participate in tree order
without consuming geometry indices. The cost is 24 additional bytes per Node on
this 64-bit build and one shared record per indexing pass. Ownership remains
Boehm-managed, including retained layout graphs; global `-prealloc` and V
`-prod` remain disabled, and the browser still uses JavaScriptCore.

The earlier `v -profile` output in `Build/v/github-v-profile.txt` recorded
6,402,057 layout ancestry calls across its multiple-layout diagnostic. It
identifies the operation investigated here, rather than the current number of
calls in one navigation. Eight new tests cover indexed ancestry against a parent
walk for every pair in a 128-node tree, tree mutation and moves, replacements,
partial reindexing, copied-node identity, geometry indexing and forced collection.
With the four existing tree tests and the updated external-containing-block seed
fixture, **13 focused cases / 34,102 assertions pass in each GC mode**, including
C `-O2` with Boehm.

A fixed three-pair diagnostic exercises one million varied ancestry queries over
128 balanced nodes. Dedicated executables use the same V compatibility compiler,
C `-O2` and Boehm, with tree construction and indexing outside the hardware counter
scope. Every checksum matches the independent parent-walk expectation of 62,501.
The median is **43,430,694 → 36,148,055 instructions
(16.77% fewer)**; all three pairs improve. These are controlled
ancestry counts, not page measurements. Evidence is
`Build/v/instruction-opt16-diagnostic-{plan,result}.json` and the retained source,
commands and logs. The first direct debugger probe could not find the ancestry
symbol in the optimized browser. The first diagnostic compilation ran successfully
but V removed its test executable, preventing subsequent paired runs. Those setup
failures and initial diagnostic logs remain retained; `-keepc` retains the rebuilt
diagnostic executables for the predeclared pairs. Browser measurements and broad
unit tests were not repeated for either diagnostic correction.

Thirty alternating GitHub pairs were fixed before observing results. The primary
scope remains the first `navigation_to_first_document_paint` record, using fresh
copies of the immutable cache, a 1024×768 document viewport, normal C `-O2`/Boehm
binaries and the same frozen native library.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Parent walking | 34,632,915,358.5 |
| Indexed ancestry | 33,850,149,374 |

The observed median reduction is **782,765,984.5 instructions
(2.26%)**, but only **17/30 pairs improve**.
The paired median saving is 45,489,184; its 95% paired
bootstrap interval is **-71,167,041.5 to
610,838,477** instructions (30,000
resamples, seed 16). The one-sided sign probability is
0.2923. **A repeatable whole-page saving is not
established.** The narrower formatting-interval comparison is also uncertain;
these adjacent checkpoint intervals are not isolated self time. All sixty captures
have valid geometry and one installation, with two required geometry passes and
one shell paint recording before the first frame. No page samples were discarded.
Raw reports use `Build/instructions/vox-opt16-interleaved-*`; paired evidence is
`Build/v/instruction-opt16-comparison-evidence.json`.

The fresh control captures committed runtime sources at `06dbde16`. Concurrent
media abort/emptied changes are excluded from the frozen candidate source tree;
its runtime differs from the control only in `layout/node.v` and
`layout/tree_node.v`. Generated C restores repository source/header/resource path
prefixes after compilation from that frozen tree. Remaining generated differences
are cache implementation and derived Node initialization/equality/stringification,
source-derived anonymous/embed identifiers, a new type shifting subsequent V type
IDs, and owned assertion line numbers. All 120 common native object/archive inputs
retain their hashes. See `Build/v/instruction-opt16-matching-provenance.json`.

The observed median crossed the 5,000,000-instruction trigger, so **one** broad
batch ran. Six retained V group logs report the **87 selected CSS/SVG/layout cases
passing in each GC mode**. The focused intrinsic flex/grid/table viewport is
pixel-exact before/after. The first screenshot batch completed sixteen comparisons
before macOS reported a full disk. Its supervisor did not preserve a complete
terminal result, so that initial supervisor receives no full-pass credit. Two
derived normalized-C artifacts were compressed with their hashes retained, and
only the three remaining screenshot cases resumed. Composed verification records
**19 comparisons passing, 16 pixel-exact**, with the same bounded differences in
inline-node, text-decorations and canvas-text. Neither unit suites nor completed
screenshots repeated. Initial failure and continuation evidence are in
`Build/v/instruction-opt16-validation-initial-failure.json`,
`instruction-opt16-validation-result.json`, the broad/screenshot logs and
`Build/comparisons/instruction-opt16-{intrinsic,batch}/`.

The latest broad-verified candidate is `27011ca9` at an observed first-frame
median of **33,850,149,374** instructions. **Zero repeatable
page-level savings are credited**, with zero additional instructions accumulated
since this batch. The controlled diagnostic does not contribute to that counter.
Chrome instruction/functionality parity remains unestablished, including the
existing GitHub module-hydration gap.

The signed canonical `Build/v/Vox.app` contains this measured snapshot. Its prior
executable was unchanged from the measured pixel-rounding bundle. The fresh
control additionally includes the committed progress/suspend slice; those three
runtime-file differences are authenticated against the captured HEAD. Later media
abort/emptied source work remains intact and is excluded from this snapshot.
Candidate and installed code hashes match, strict signature verification and
headless startup pass, and the running browser was not restarted. Relaunch Vox to
use the updated bundle. Installation evidence is
`Build/v/instruction-opt16-bundle-{result,text-result}.json`.

The control SHA-256 is
`375d72a50389d253bba7c0f908dcaf00db61405c04b5902e3d1aedfcf337d993`;
the candidate is
`b36a057b58336992e80b0943e928642dd39af09983370459a9062d7e274590db`.
Bundle signing changes the installed executable hash to
`86b2bc6c5261cde99973d08fb737fcf095d0090c832de3244cd41e0acfc89223`.

## Integer fixed-point layout sums

Feature `489816e4` removes floating-point round trips from the four layout sum
helpers in `layout/layout_state.v`. Pixel and point pairs use the existing
saturating fixed-point addition. Three- and five-operand sums add raw values in
`i64` and clamp once at the end, preserving cancellation between oversized edges
and negative margins. Every raw operand is a signed 32-bit integer; even five
operands fit exactly in the wide accumulator. Results retain the previous
1/64-pixel precision, including saturation boundaries. There are no struct-layout,
allocation-policy or GC changes. Normal builds retain Boehm and JavaScriptCore,
without global `-prealloc` or V `-prod`.

This slice starts with a **fresh `v -profile` capture** of the current engine,
using committed runtime sources at `b4a325cb`. Its diagnostic records
2,643,505 point additions and 434,088 / 549,234 / 975,908 scalar sums with two,
three and five operands. Counts include the instrumented capture's layout/paint
passes, including work after the first frame, rather than one first-frame scope.
The diagnostic uses C `-O1` and profiling timers; its instruction totals are not
compared to the normal binaries. Source, argv, logs and the full profile are under
`Build/v/instruction-opt17-{profile-*,v-profile.txt}`.

Four new tests compare boundary pairs and full-range deterministic raw values
against the old floating-point path, verify deferred saturation through
cancellation, and check independent point axes. With four existing DOM client-
geometry cases, **eight functional cases pass in both GC modes**, including
C `-O2` with Boehm. The retained aggregate also runs one instruction diagnostic;
each complete focused run passes 33,943 assertions.

The controlled diagnostic fixes three interleaved pairs before execution. One
million iterations exercise all four helpers and produce five scalar/coordinate
outputs each, using small, fractional, extreme and saturating raw inputs. Setup
and assertions are outside the hardware counter scope. All checksums match an
independent integer reference of -302,011,986,410,836.
The median is **109,066,434 → 56,016,176
instructions (48.64% fewer)**, with all three pairs improving.
These dedicated C `-O2`/Boehm test executables establish the sum-work reduction;
they are separate from page measurements. Evidence is
`Build/v/instruction-opt17-diagnostic-{plan,result}.json` and
`opt17-integer-sums-focused-test.v.txt`.

Thirty alternating normal-build GitHub pairs were fixed before observing results.
Both use C `-O2`/Boehm, the same frozen native library, fresh copies of the immutable
cache and a 1024×768 document viewport. The primary endpoint remains the first
native `navigation_to_first_document_paint` scope.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Floating-point sums | 34,822,469,699.5 |
| Integer sums | 34,666,996,715.5 |

The observed median falls **155,472,984 instructions
(0.45%)**; **20/30 pairs improve**. The paired
median saving is 252,739,132.5; its 95% paired percentile
bootstrap interval is **-10,971,201
to 1,183,628,166.5** instructions
(30,000 resamples, seed 17). The one-sided sign probability is
0.0494. The paired interval still includes zero,
so **a repeatable whole-page saving remains unestablished**. All sixty captures
have valid geometry and one installation, with two required geometry passes and
one shell paint recording before the first frame. No page samples were discarded
or added after inspecting results. Raw reports use
`Build/instructions/vox-opt17-interleaved-*`; paired evidence is
`Build/v/instruction-opt17-comparison-evidence.json`.

The frozen control and candidate runtime differ only in `layout/layout_state.v`.
After normalizing source-derived anonymous symbols and temporary names, the C
difference contains only the four helper replacements, the new wide-sum clamp
and its declaration, plus matching source-derived embed keys. Embedded content
and all 120 common native object/archive inputs remain byte-identical. Source
capture paths are normalized back to the repository root before native
compilation. See `Build/v/instruction-opt17-matching-provenance.json` and
`instruction-opt17-generated-c.diff`.

Storage exhaustion interrupted the initial focused/native object emission and
link steps before any page measurements. Original compiler logs and available
failure records are retained; missing initial supervisor terminal records receive
no successful-build or runtime credit. Older generated C captures were archived
as verified gzip streams, preserving their original SHA-256 hashes. A redundant
normalized profiling C capture was archived while its untouched raw input remained
available. Resumed builds reuse retained C and exact compiler arguments, with
actual native compile and runtime exits captured. Source generation was not
repeated. Archive indexes are `instruction-opt17-earlier-c-compression.json` and
`instruction-opt17-profile-c-compression.json`.

The observed page median crossed the 5,000,000-instruction trigger, so **one**
broad batch ran: **87 selected CSS/SVG/layout cases in each GC mode and 19
screenshot comparisons, 16 pixel-exact**. All six group commands and the full
screenshot batch record actual exit zero. The same bounded differences remain
for inline-node, text-decorations and canvas-text; the focused intrinsic
flex/grid/table viewport is pixel-exact before/after. Group results are persisted
before screenshots. Evidence is `Build/v/instruction-opt17-validation-result.json`,
`instruction-opt17-broad-*-result.json`, `instruction-opt17-screenshots.log` and
`Build/comparisons/instruction-opt17-{intrinsic,batch}/`.

The new broad-verified baseline is `489816e4` at an observed first-frame median
of **34,666,996,715.5** instructions. **Zero repeatable page
savings are credited**, with zero additional instructions accumulated since this
batch. Diagnostic savings do not contribute to that counter. Chrome instruction
and functionality parity remain unestablished, including the GitHub
module-hydration gap.

The signed canonical `Build/v/Vox.app` contains the measured candidate. Installation
guards authenticated the unchanged previous measured ancestry bundle and the
committed reset/loadstart source lineage added by this fresh control. At
installation all captured runtime hashes matched the workspace; unrelated
branding/documentation changes remain preserved. Candidate and installed code
sections match, strict signature verification and headless startup pass, and the
running browser was not restarted. Relaunch Vox to use it. Evidence is
`Build/v/instruction-opt17-bundle-{result,text-result}.json`.

The control SHA-256 is
`917f64bb7cb8a5b4c21180842ce923f5a7d6efe5f007f4e5663f4853b1072623`;
the candidate is
`59a9ab1e1214c1098eca742e6a5bc922adc8801488765ed65ee0c0cf93e7aff2`.
Bundle signing changes the installed executable hash to
`93b958d6d52a31950e926ce840bdb1f9dfcf019b1b10470d108b1eac698d623b`.

## Count-only UTF-16 text lengths

Feature `4a07b578` replaces seven length-only UTF-16 array conversions with
an allocation-free count in the layout text paths: source/rendered caret mapping,
viewport text positions, generated visual-line lengths, first-letter source
ranges, block ellipses and grapheme boundary offsets. ASCII returns the byte
length after the existing ASCII check. Other input uses V's rune iterator,
which shares the exact decoder used by the old materialized rune array, and
counts supplementary characters as two UTF-16 code units. Full code-unit
conversions remain where callers need their contents. No persistent cache,
struct layout, GC or allocation-lifetime policy changes are involved; normal
builds retain Boehm and JavaScriptCore without global `-prealloc` or V `-prod`.

The preceding fresh `v -profile` capture recorded 104,484 calls to the shared
UTF-16 conversion helper across its layout/paint passes. This identifies a
source of repeated allocation, rather than a first-frame retired-instruction
count. Four new cases cover known Unicode lengths, all 65,536 two-byte inputs,
truncated multibyte strings, 4,096 deterministic malformed/mixed inputs and live
rendered-length clamping. Together with the ten existing first-letter cases and
twelve text-chunk cases, **26 functional checks plus one diagnostic pass in both
GC modes**. The Boehm tests use C `-O2`; each full focused run passes 87,206
assertions. Existing expanding-case, sliced-source and DOM mutation tests retain
their original geometry and text mapping assertions.

Three fixed interleaved diagnostic pairs count 250,000 lengths over sixteen
ASCII/Unicode/embedded-NUL/malformed strings, with setup and assertions outside
the hardware counter interval. All checksums match the independent UTF-16
reference of 27,343,750. Median work falls **1,892,538,446 →
195,016,955 retired instructions (89.70% fewer)**;
all three pairs improve. These are separate C `-O2`/Boehm test executables, not
whole-page measurements. The before executable adds a test-only length wrapper
around the old array conversion, leaving its production layout implementation
unchanged. Plans, retained aggregate and diagnostic counts are under
`Build/v/instruction-opt18-*` and `opt18-utf16-focused-test.v.txt`.

Thirty alternating normal-build GitHub pairs were fixed before results were
observed, with fresh copies of the same immutable cache, the same frozen native
library, a 1024×768 document viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Materialized length conversions | 34,794,106,174 |
| Count-only length conversions | 34,334,019,490.5 |

The observed median change is **-1.32%**
(460,086,683.5 fewer instructions); **24/30 pairs improve**.
The paired median saving is 482,906,045.5; its 95% paired percentile
bootstrap interval is **391,414,424.5 to 621,322,664.5** instructions
(30,000 resamples, seed 18). The paired interval excludes zero and supports a repeatable reduction for this workload.
All sixty captures have valid geometry and one installation, with the same two
required geometry passes and one shell paint recording before the first frame.
No page samples were discarded, extended or selected after observing results.
Adjacent checkpoint intervals remain process-wide deltas, not function self cost.
Raw page evidence is `Build/instructions/vox-opt18-interleaved-*`; paired evidence
is `Build/v/instruction-opt18-comparison-evidence.json`.

The control reuses the exact previously measured round17 candidate executable
and immutable source snapshot, including integer layout sums `489816e4`.
Its source recipe is committed runtime `b4a325cb` plus that layout-sum feature.
The candidate adds only the five owned layout sources. Subsequent independent
media completion work (`6d566297`) is excluded from both compared builds and
remains preserved in the workspace. The generated-C audit reviews the seven
changed/new emitted functions and their prototype, plus path-derived embed keys
and compiler temporary/anonymous names. All other generated C, including type
IDs, struct layouts and embedded data, is identical. The viewport text-position
call is absent from this native binary's emitted functions. All 120 common
native input hashes and the frozen shared library remain unchanged. The C diff
is 10,302 bytes after anonymous-hash/temporary normalization; matching source
hashes, argv and the projection audit are retained in
`Build/v/instruction-opt18-matching-provenance.json`.

The observed page median crossed the user's 5,000,000-instruction gate, so
one broad batch ran after the completed measurement. All six commands for the
87 selected CSS/SVG/layout cases pass in Boehm and no-GC modes; all nineteen
screenshot comparisons pass, sixteen pixel-exact. The three existing screenshot
differences remain inline-node (13 pixels), text-decorations (1,341) and
canvas-text (1,994). The focused multilingual/first-letter/ellipsis/control
viewport is pixel-exact between the two binaries. Actual command exits and
image metrics are in `Build/v/instruction-opt18-validation-result.json` and its
per-command logs. The new broad-verified baseline is `4a07b578` at the observed
median 34,334,019,490.5; credited repeatable savings are 460,086,683.5
and additional savings after this broad batch reset to zero. Diagnostic savings
never contribute to that counter.

The measured candidate replaces only the authenticated, unchanged prior
canonical executable in `Build/v/Vox.app`; its native `__TEXT,__text` hash is
`aa4483fe3b39d7084150d8810e5ca9c356cfed2843164430c0a2db141d209f83`. Bundle signing,
deep strict verification and `--headless-smoke` pass. The existing GUI process
was left running; relaunch the bundle to load the new executable. Later media
sources are preserved but excluded from this measured app snapshot.

Completed generated C and derived normalization artifacts were losslessly
gzip-archived to retain evidence under disk pressure, with original SHA-256 and
round-trip verification. No compiler/test/page failure occurred in this round.
Chrome instruction and functionality parity remain unestablished, including
GitHub module hydration and populated file rows.

## Direct reads of guarded layout styles

Feature `11442940` removes temporary optional casts from the three layout
`Node` style accessors: `computed_values()`, `display()` and
`display_before_box_type_transformation()`. Each uses the same `has_style_`
discriminant checked by `as_node_with_style()` before accessing the embedded
`NodeWithStyle`. Unstyled computed-value reads still walk the live parent chain
and retain the disconnected-root assertion; unstyled display reads still return
inline flow. No cached pointer, field-layout, allocation-policy or GC changes
are involved. Boehm remains enabled in normal builds, with JavaScriptCore and
without global `-prealloc` or V `-prod`.

The recent `v -profile` diagnostic recorded 8,818,514 `Node.computed_values()`
calls and 2,629,842 `Node.display()` calls across its layout/paint passes, including
work after the first frame. The normal C `-O2` control's native assembly shows
stack stores/reloads for the temporary styled pointer. The generated C includes
`GC_reachable_here(&styled)` around that optional binding even though the
accessor needs only a guarded field read. Reading through the guarded receiver
removes that temporary; the receiver and returned style retain normal traced
ownership. Its direct style path drops from twelve native instructions to seven.
Before/after assembly is retained under
`Build/v/instruction-opt19-native-style-*.txt`.

Four new functional cases cover four concrete styled-node types, pointer
identity, different transformed/original display values, unstyled chains at
multiple depths, reparenting, live ancestor style replacement, nearest styled
ancestor selection and collection between reads. Together with the sixteen
existing node cases, **20 functional checks plus one diagnostic pass in both
GC modes**, including C `-O2` with Boehm. Each focused run passes 15,299 assertions.
The first focused compiles rejected a fixture's `.none` spelling; the enum uses
`.none_`. Those actual exit-one reports and logs remain retained without runtime
credit; only the corrected focused commands were rerun. No production source
or benchmark samples changed during that correction.

Three fixed interleaved diagnostic pairs exercise one million iterations of
all three accessors across 128 nodes: styled roots and unstyled chains at depths
one through three, with four display types. Setup, collection and assertions
are outside the hardware counter interval. Every checksum matches the independent
reference of 375,000. Median work falls **53,519,687 →
34,837,149 retired instructions (34.91% fewer)**;
all three pairs improve. These separate C `-O2`/Boehm test executables establish
accessor-work reduction, rather than whole-page savings. Plans, retained
aggregate, results and initial compile failures are under
`Build/v/instruction-opt19-*` and `opt19-style-focused-test.v.txt`.

Thirty alternating normal-build GitHub pairs were fixed before results were
observed, using fresh copies of the same immutable cache, the same frozen native
library, a 1024×768 document viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Optional styled-pointer binding | 34,317,297,094 |
| Direct guarded style access | 34,294,041,571.5 |

The observed median change is **-0.07%**
(23,255,522.5 fewer instructions); **14/30 pairs improve**.
The paired median saving is -19,373,783.5; its 95% paired percentile
bootstrap interval is **-973,558,548 to 194,553,829.5** instructions
(30,000 resamples, seed 19). The paired interval includes zero, so a repeatable
whole-page reduction remains unestablished. Zero repeatable page savings are
credited.
All sixty captures have valid geometry and one installation, with the same two
required geometry passes and one shell paint recording before the first frame.
No page samples were discarded, extended or selected after observing results.
Checkpoint intervals remain process-wide deltas rather than function self cost.
Raw page evidence is `Build/instructions/vox-opt19-interleaved-*`; paired evidence
is `Build/v/instruction-opt19-comparison-evidence.json`.

The control reuses the exact previously measured round18 candidate executable
and immutable source snapshot, including count-only UTF-16 lengths `4a07b578`.
The candidate changes only `layout/node.v`. Subsequent independent media
completion work remains preserved in the workspace and is excluded from both
compared binaries. After authenticating path-derived embed lookup keys and
normalizing compiler anonymous hashes/temporary names, the generated-C diff is
7,021 bytes. The reviewed body changes are only
`Node.display()` and `Node.computed_values()`; the third accessor is absent from
the normal browser's emitted functions and is exercised by the focused tests.
All remaining generated C, including type IDs, struct layouts and embedded data,
is identical. All 120 common native input hashes and the frozen shared library
remain unchanged. Source hashes, argv and the projection audit are retained in
`Build/v/instruction-opt19-matching-provenance.json`.

The observed page median crossed the user's 5,000,000-instruction gate, so
one broad batch ran after the completed measurement. All six commands for the
87 selected CSS/SVG/layout cases pass in Boehm and no-GC modes; all nineteen
screenshot comparisons pass, sixteen pixel-exact. Existing differences remain
inline-node (13 pixels), text-decorations (1,341) and canvas-text (1,994). The
focused multilingual/first-letter/ellipsis/control viewport is pixel-exact
between the two binaries. Actual exits and image metrics are in
`Build/v/instruction-opt19-validation-result.json` and its per-command logs.
The new broad-verified baseline is `11442940` at the observed median
34,294,041,571.5; credited repeatable savings are 0 and
additional savings after this batch reset to zero. Diagnostic savings never
contribute to that counter.

The measured candidate replaces only the authenticated, unchanged prior
canonical executable in `Build/v/Vox.app`; its native `__TEXT,__text` hash is
`38caf26aa3621c8afd60eef068ba833661321ccc373707bc9749a82172ad45a4`. Bundle signing,
deep strict verification and `--headless-smoke` pass. The existing GUI process
was left running; relaunch the bundle to load the new executable. Later media
sources are preserved but excluded from this measured app snapshot.

Earlier completed generated C and current derived normalization artifacts were
losslessly gzip-archived under disk pressure, with original SHA-256 and
round-trip verification. Chrome instruction and functionality parity remain
unestablished, including GitHub module hydration and populated file rows.

## Absent optional lengths without payload allocations

Feature `3894727a` makes `LengthPercentageOrAuto.length_percentage_` explicitly
default to `none`. The compatibility compiler otherwise constructs a zero-length
sum-type payload, including its heap allocation, before marking the option
absent. That payload has no value to expose. Explicit absence agrees with the
upstream `Optional<LengthPercentage>` default in `CSS/PercentageOr.h`, including
the four auto sides of `CSS/LengthBox`. Present lengths, percentages and
calculations retain their existing ownership. No object-layout, lifetime or GC
policy changes are involved. Normal builds retain Boehm and JavaScriptCore,
without global `-prealloc` or V `-prod`.

The recent `v -profile` diagnostic recorded 104,365 `make_auto()` calls across
its layout/paint passes, including work after the first frame. Its call counts
are a hotspot diagnostic rather than first-frame retired-instruction counts.
The normal control's C and assembly show a heap-backed 16-byte `Length` payload
being constructed for that absent value. The candidate's auto constructor
returns an explicit absent option with no payload construction. The generated
C removes **37 static construction sites**: the auto constructor and eighteen
sites each in the two computed-property constructors. The other sixteen
implicit optional-length sites belong to different fields and remain unchanged.
Static sites are not runtime allocation counts; cached constructor branches do
not execute on every call. Before/after assembly is retained under
`Build/v/instruction-opt20-native-option-*.txt`.

The static-site inventory also flags thirty allocating defaults in
`block_box_from_typed_layout_shallow()`. They occur in its three empty fallback
returns for missing style, missing used values or disabled SVG; its populated
paint-box path supplies the option values explicitly. Multiplying those static
sites by total function calls would overestimate executed allocation work.
The investigation is retained in
`Build/v/instruction-opt20-paint-default-investigation.json`.

Three new focused cases check nested/default boxes and arrays, independent
slots, typed and DOM conversions, and retained lengths/percentages/calculations
surviving reset and collection. Together with existing default, length-or-auto
and precision cases, **ten functional checks plus one diagnostic pass in both
GC modes**, including C `-O2` with Boehm. Each focused run passes 181 assertions.

Three fixed interleaved diagnostics perform 250,000 iterations. Each stores
one explicit auto value and a partially initialized `LengthBox` with three auto
sides and a changing explicit width. Thus the interval exercises one million
absent optional-length constructions and retains explicit width payloads.
Setup, collection and assertions are outside the hardware counter interval.
Every checksum matches the independent integer reference of 1,017,000,000.
Median work falls **233,722,409 → 60,850,034
retired instructions (73.96% fewer)**; all three pairs improve.
These separate C `-O2`/Boehm test executables establish constructor-work reduction,
rather than page savings. Plans, retained aggregate and results are under
`Build/v/instruction-opt20-*` and `opt20-optional-length-focused-test.v.txt`.

Thirty alternating normal-build GitHub pairs were fixed before results were
observed, using fresh copies of the same immutable cache, the same frozen native
library, a 1024×768 document viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Implicit absent-length payload | 34,187,647,382 |
| Explicit absent optional length | 34,200,115,498.5 |

The observed median change is **+0.04%**
(12,468,116.5 more instructions); **13/30 pairs improve**.
The paired median saving is -15,800,703; its 95% paired percentile
bootstrap interval is **-284,085,015.5 to 398,932,428** instructions
(30,000 resamples, seed 20). The paired interval includes zero, so a repeatable
whole-page reduction remains unestablished. Zero repeatable page savings are
credited.
All sixty captures have valid geometry and one installation, with the same two
required geometry passes and one shell paint recording before the first frame.
No page samples were discarded, extended or selected after observing results.
Raw reports are `Build/instructions/vox-opt20-interleaved-*`; paired evidence is
`Build/v/instruction-opt20-comparison-evidence.json`. Checkpoint intervals remain
process-wide deltas rather than function self cost.

The control reuses the exact previously measured round19 candidate executable
and immutable source snapshot, including guarded style reads `11442940`.
The candidate changes only `css/css.v`. Subsequent independent media completion
sources remain preserved and are excluded from both compared binaries.
The generated-C diff is 130,115 bytes after anonymous-hash
and compiler temporary normalization. Its projection audit rewrites only the
exact generated absent-option zero-Length initializer and copy-only aliases to
the explicit absent option, canonicalizes temporary identities within each
function, and authenticates path-derived embed lookup keys. All other code,
type IDs, object layouts and embedded data match. All 120 common native input
hashes and the frozen shared library remain unchanged. Matching source hashes,
argv and the projection audit are retained in
`Build/v/instruction-opt20-matching-provenance.json`.

The completed page measurement stayed below the user's 5,000,000-instruction
gate, so broad suites did not run. The focused viewport is pixel-exact. The
preceding broad baseline remains guarded style reads `11442940`; the diagnostic
contributes no page savings credit.

The installed app was preserved because the page median did not improve.

Disk exhaustion interrupted the initial optimized focused native compiles
before their object outputs could be opened. It also prevented their supervisors
from writing result JSON: only the supervisors' actual exit-one results and
compiler diagnostics are available for that initial attempt, with zero runtime
credit. The successful no-GC run was retained. After verified compression of
completed C captures and older benchmark executables, only the two native
compiles resumed from saved C/response files; the V frontends were not repeated.
Resumed compiler and runtime exits are recorded separately. The normal browser
build kept its frozen inputs; no page capture began until the prerequisite
builds passed. Original failed logs, supervisor results, artifact SHA-256,
archive round-trip checks and executable modes are retained. Derived C
normalization archives were recovered from untouched original C after their
first compression attempt also ran out of space. Byte-identical, mode-matching
files in completed source snapshots through round16 now share APFS copy-on-write
storage. Their bytes, permissions and timestamps are preserved and verified;
active snapshots were excluded. The clone journal is
`Build/v/instruction-opt20-historical-source-clones.json`.

Chrome instruction and functionality parity remain unestablished, including
GitHub module hydration and populated file rows.

## Reading retained CSS keywords without optional copies

Feature `a888f10b` reads the keyword from the typed box already owned by
the DOM style value. Previously it copied a `?StyleValue`, unwrapped that
sum type and retained a GC-root temporary before calling `to_keyword()`.
The normal optimized native code still performed those copies. The direct
read uses the same type discriminator and keyword payload, matching upstream
`StyleValues/StyleValue.cpp:StyleValue::to_keyword()`. A retained non-keyword
continues to return absence even if its bridge text looks like a keyword;
values without a typed handle keep their trimmed, case-insensitive text
fallback. The read borrows no pointer beyond the call. Boehm ownership and
JavaScriptCore are retained; no global arena or compiler GC policy changes.

The recent `v -profile` diagnostic recorded 3,371,354 calls to the keyword
helper across its layout/paint passes, including work beyond the first frame.
Those calls guided the investigation and are not first-frame instruction counts.
Normal C `-O2` assembly confirms removal of the optional sum copy and rooting
temporary; the helper's stack frame falls from 160 to 48 bytes. Assembly and
the two generated helper bodies are retained under
`Build/v/instruction-opt21-native-keyword-*.txt` and `instruction-opt21-keyword-*`.

Four focused cases cover all 869 non-invalid keyword enum values, retained
non-keyword and invalid types, CSS-wide/current-color predicates, serialized
fallbacks, and replacement handles across collection. They pass in Boehm
(C `-O2`) and no-GC modes. With the separate instruction diagnostic, each run
passes 1,056 assertions. The three fixed, alternating diagnostic pairs cycle
four million reads across six retained keywords and two non-keyword values.
Setup, collection and assertions stay outside the counter interval. The
independent reference sums known keyword ordinals, with checksum 1,191,500,000;
every run agrees. Median work falls **320,428,681 →
192,176,161 instructions (40.03% fewer)**,
with all three pairs improving. This establishes reader-work reduction,
rather than a whole-page saving.

Thirty alternating normal-build GitHub pairs were fixed before results were
observed. They use fresh copies of the same immutable cache, the same frozen
native library, a 1024×768 document viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Optional typed-value copy | 34,392,949,060 |
| Direct retained keyword read | 34,248,541,966.5 |

The observed median falls **144,407,093.5 instructions
(0.42%)**; **20/30 pairs improve**.
The paired median saving is 163,388,035.5; the 95% paired
percentile bootstrap interval is **-62,398,475.5 to 900,344,421.5**
instructions (30,000 resamples, seed 21). The interval includes zero, so a
repeatable page gain remains unestablished and **zero repeatable page savings
are credited**. All sixty captures have one installation, two required geometry
passes and one shell paint recording before the first frame. No samples were
discarded, extended or selected after results. Checkpoint intervals remain
process-wide deltas, rather than function self cost. Raw reports are
`Build/instructions/vox-opt21-interleaved-*`; paired evidence is
`Build/v/instruction-opt21-comparison-evidence.json`.

The control is the retained round20 candidate, including absent optional
lengths `3894727a`. The candidate changes only `css/computed_interpolation.v`.
Its earlier typed-box reference moves the identical one-field generated C
definition and renumbers some CSS type tags. The projection audit authenticates
those IDs by named sum-type members, casts and type-name metadata. It also
canonicalizes anonymous-function hashes/positional names (keeping distinct
same-signature ordinals), per-function temporary identities, authenticated
path-derived embed keys and the changed source's three-line assertion offsets.
After these metadata changes, only the keyword helper's executable logic
differs. Layouts, resources and every other function's logic match. All 120
common native input hashes and the shared library remain unchanged. Exact
source hashes, argv and audit provenance are retained under
`Build/v/instruction-opt21-*`.

The observed median exceeds the user's 5,000,000-instruction gate, so one broad
batch ran after measurement. All six commands for 87 selected CSS/SVG/layout
cases pass in both GC modes. All nineteen screenshot comparisons pass, sixteen
pixel-exact; existing differences remain inline-node (13 pixels),
text-decorations (1,341) and canvas-text (1,994). The focused viewport is
pixel-exact between the binaries. Actual exits and image metrics are retained
in `Build/v/instruction-opt21-validation-result.json` and per-command logs.
The new broad-verified baseline is `a888f10b` at the observed median
34,248,541,966.5; repeatable page savings credited are zero and
additional savings after this batch reset to zero.

The measured candidate is installed in `Build/v/Vox.app`. Installation follows
the existing positive observed median policy, with the uncertainty above.
The preceding installed executable is authenticated against round19; cumulative
runtime changes are exactly the two CSS files for absent lengths and this
reader. Native text SHA-256 is `4d568b4d6f6d34d7c1384397c0e617c1b8b5333a32ebee515771655eecbb6eee`.
Bundle signing, deep strict verification and headless startup pass. Independent
media completion sources are preserved and excluded from both benchmark builds
and this app snapshot. The existing GUI process was left running.

Low disk space was managed by round-trip-verified compression of completed C
and executable artifacts and by APFS cloning of byte-identical, mode-matching
files in completed source snapshots from rounds17–20. Source bytes, permissions
and timestamps are preserved; active round21 snapshots were excluded. Archive
journals retain SHA-256 and executable modes. The optional formatter command
could not build its tool because its configured compiler checkout lacked
`libgc.a`; it made no source edits. No test or page-capture failures receive
runtime credit. Chrome instruction and functionality parity remain unverified,
including GitHub module hydration and populated file rows.

## Consolidated keyword classification during property computation

Feature `eb4e269e` classifies each cascaded value once for `inherit`,
`unset` and color's `currentcolor` rule. It separately classifies the value
after inheritance, preserving the initial/unset fallback even when inheritance
replaces the value. The final relative-font keyword check now runs only for
`font-size` and `font-weight`. Relative length dependencies on all properties
continue through the existing length path. This removes repeated reads and
optional-result handling from `StyleComputer.compute_properties()` without
changing type ownership, arena lifetimes, Boehm collection or JavaScriptCore.

Five new regression cases cover typed and serialized CSS-wide values,
inherited flags and importance, missing parent defaults, `currentcolor`,
relative fonts and lengths, spoofed bridge text, and checking the replacement
inherited value afresh. With retained-keyword and animated-inheritance checks,
**ten focused functional cases plus one diagnostic pass in both GC modes**,
including C `-O2` with Boehm. Each regular run passes 3,209 assertions.

Three fixed interleaved diagnostics perform 256 complete property-computation
passes with all 355 initial longhands explicitly cascaded and font size fixed
at 16px. A sixteen-entry ring retains outputs. Input setup, eight warmups,
collection and assertions stay outside the counter interval. Every checksum
matches the independent reference `(355 + 16*64)*256 = 353024`.
Median work falls **250,761,811 → 238,750,508
instructions (4.79% fewer)**; all three pairs improve.
This diagnostic measures complete property computation for an explicit
all-longhand input, rather than GitHub's particular cascade or whole-page cost.
Plans, retained aggregate, binaries and results are under
`Build/v/instruction-opt22-*` and `opt22-cascade-focused-test.v.txt`.

A fresh `v -profile` comparison executes the same focused workload in two
separate C `-O1`/Boehm builds using `-profile-no-inline`, which omits inline-marked
functions from profiling rather than disabling Clang inlining. Retained legacy
generated C saves the previous profiling flag but omits its restoration; these
counters cover the replay from the first selected call through process exit.
Both builds record 285 calls to `compute_properties`.
Keyword helper calls fall **480,653 → 196,843
(59.05% fewer)**.
These are call counts across all focused cases and the diagnostic, including
warmups. Instrumented times and instruction counts are excluded from normal
page measurements. Raw profiles and scope notes are
`Build/v/instruction-opt22-{before,final}-v-profile.txt` and
`Build/v/instruction-opt22-profile-evidence.json`.

Thirty alternating normal-build GitHub pairs were fixed before results were
observed. They use fresh copies of the same immutable cache, the frozen native
library, a 1024×768 document viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Repeated keyword classification | 34,050,968,012 |
| Consolidated classification | 33,958,775,388 |

The observed change is **-0.27%**
(92,192,624 fewer instructions);
**15/30 pairs improve**. The paired median saving is
7,667,421.5; its 95% paired percentile bootstrap interval is
**-149,035,714.5 to 929,117,874.5** instructions (30,000 resamples, seed 22).
The paired interval includes zero, so a repeatable whole-page gain remains
unestablished. Zero repeatable page savings are credited. All sixty captures
have valid 1024×768 geometry, one installation,
two required geometry passes and one shell paint recording before the first
frame. No samples were discarded, extended or selected after results.
Checkpoint intervals remain process-wide deltas rather than function self cost.
Raw reports are `Build/instructions/vox-opt22-interleaved-*`; paired evidence
is `Build/v/instruction-opt22-comparison-evidence.json`.

The control reuses the exact round21 candidate executable and source snapshot,
including direct retained keyword reads `a888f10b`. The sole runtime source
change is `css/computed_interpolation.v`. After authenticated embed lookup keys,
compiler temporary/symbol identities and source assertion offsets are
canonicalized, the generated-C audit finds only changed `compute_properties`
logic. The unchanged private currentcolor predicate loses its last production
caller and is no longer emitted. Type layouts, resources and every other
function's logic match. All 120 common native input hashes and the shared
library remain unchanged. Source hashes, exact argv and the C projection audit
are retained in `Build/v/instruction-opt22-matching-provenance.json`.

The observed median crossed the user's 5,000,000-instruction gate, so one
broad batch ran after measurement. All six commands for 87 selected CSS, SVG and
layout cases pass in both GC modes. All nineteen screenshot comparisons pass,
sixteen pixel-exact; existing differences remain inline-node (13 pixels),
text-decorations (1,341) and canvas-text (1,994). The focused Unicode/control
viewport, extended with CSS-wide, relative-font and currentcolor examples,
is pixel-exact between the builds. Actual exits and metrics are retained in
`Build/v/instruction-opt22-validation-result.json` and per-command logs.
The broad-verified baseline is now `eb4e269e` at the observed median
33,958,775,388; repeatable page savings credited are 0,
with additional savings after this batch reset to zero.

The measured candidate replaces the authenticated prior executable in
`Build/v/Vox.app`; native text SHA-256 is `34023c0f9fb2c44be79267262203bbd3848fff3e7d338af882241e346fd4cf10`.
Bundle signing, deep strict verification and headless startup pass.
Installation follows the existing positive observed median policy, with the
uncertainty above. Independent media completion sources are preserved and
excluded from both compared binaries and this app snapshot. The existing GUI
process was left running.

The initial focused fixture passed a serialized-only non-CSS-wide
background-color to a computation boundary requiring a typed value. Unchanged
control and candidate failed with the same panic before their diagnostics.
Those results and original C/executables are retained without runtime credit.
Only the fixture was corrected: background-color keeps its parsed type, while
the serialized CSS-wide inheritance cases remain covered. All subsequent
focused runs pass before page measurement begins. The browser implementation
and normal build inputs were unchanged by this fixture correction.
Low disk space was managed by round-trip-verified compression of completed
older artifacts; archive journals retain SHA-256 and executable modes.
Chrome instruction and functionality parity remain unverified, including
GitHub module hydration and populated file rows.

## Borrowed sources for synchronous property computation

Feature `8b80c79a` replaces a managed property-lookup closure allocated for
each ordinary computed property with one small descriptor per style pass.
The descriptor borrows the live `ComputedProperties` record and is used only
synchronously. Only background coordination and font sizing request dependency
values. The public callback API remains available for custom callers and
keyframes, including their specified-value overlay and computed/initial
fallbacks. The main cascade previously captured a pointer, not a complete style
record; its avoidable cost was closure allocation and registration. The separate
recomputation method previously captured the record by value. The generated-C
audit authenticates both removed closure contexts and the three-field source
layout; the property computation body matches after exactly its two dependency
lookups and required source-root barriers are projected. All unrelated
executable logic, layouts and resources match after named type IDs, compiler
symbol/temporary identities, embed keys and assertion offsets are canonicalized.

Four new cases check lazy custom callbacks across explicit collection,
background layer coordination, math-depth font sizing, repeated live-style
recomputation, importance/inheritance flags, and keyframe overlays and
fallbacks. Together with the prior keyword and animated-inheritance checks,
**fourteen functional cases plus one diagnostic pass in both GC modes**,
including C `-O2` with Boehm. Each run passes 3,341 assertions.
Boehm and JavaScriptCore remain enabled; no arena lifetime is extended into
live cyclic/shared DOM or JavaScript state.

Three fixed alternating diagnostics perform 256 complete property-computation
passes with all 355 initial longhands explicitly cascaded and font size fixed
at 16px. A sixteen-entry ring retains outputs; setup, eight warmups, collection
and assertions stay outside the hardware counter scope. Every checksum matches
the independent reference `(355 + 16*64)*256 = 353024`.
Median work falls **240,480,935 → 173,316,500
instructions (27.93% fewer)**; all three pairs improve.
This explicit all-longhand diagnostic does not represent GitHub's complete
cascade or whole-page cost. Plans, retained aggregate and results are under
`Build/v/instruction-opt23-*` and `opt23-property-source-focused-test.v.txt`.

A fresh `v -profile` comparison uses separate C `-O1`/Boehm builds with the same
focused input. `-profile-no-inline` omits inline-marked functions from
instrumentation; it does not disable Clang inlining. Profiling covers the full
process, including module initialization, all cases, warmups and the diagnostic;
there is no `-profile-fns` filter or counter reset. Both builds execute 286
main cascade calls, two recomputation calls and 56,804 property computations.
Managed closure creation/registration calls fall **63,154 → 6,357
(89.93% fewer)**, and `memdup` calls fall 354,494 → 240,900.
The new dependency getter runs 2,155 times. These are diagnostic call counts,
not GitHub whole-page allocation counts. Instrumented times and instruction
counts are excluded from normal page results. Raw profiles, exact argv and
generated-C scope proofs are retained under `Build/v/instruction-opt23-*`.

Thirty alternating normal-build GitHub pairs were fixed before measurement,
using fresh copies of the same immutable cache, the frozen native library,
a 1024×768 document viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Per-property managed lookup closure | 34,154,501,639 |
| Borrowed synchronous property source | 33,258,794,887 |

The observed change is **-2.62%** (895,706,752 fewer instructions);
**24/30 pairs improve**. The paired median saving is 501,954,294.5; its
95% paired percentile bootstrap interval is **100,859,636.5 to 1,199,365,742**
instructions (30,000 resamples, seed 23). The paired interval excludes zero and
supports a repeatable reduction for this cached workload. Repeatable page
savings credited: 895,706,752. All sixty captures have valid 1024×768 geometry,
one installation, two required geometry passes and one shell paint recording
before the first frame. No observations were discarded, selected or added
after results. Disk exhaustion interrupted cache copying before pair 8's first
browser launch. The original seven pairs and failure logs were retained, and
the unchanged schedule resumed at pair 8; the failed cache copy produced no
browser observation. Completed artifacts were compressed with SHA-256
round-trip checks and executable modes retained in archive journals.
Checkpoint intervals remain process-wide deltas rather than function self cost.
Raw reports are `Build/instructions/vox-opt23-interleaved-*`; paired evidence
is `Build/v/instruction-opt23-comparison-evidence.json`.

The control reuses the exact round22 executable and source snapshot, including
consolidated keyword classification `eb4e269e`. The sole runtime source change
is `css/computed_interpolation.v`; all 120 common native input hashes and the
shared library remain unchanged. Source manifests, exact argv and the generated
C audit are retained in `Build/v/instruction-opt23-matching-provenance.json`.

The observed page median crossed the user's 5,000,000-instruction gate, so
one broad batch ran after all measurements. All six commands for 87 selected
CSS, SVG and layout cases pass in both GC modes. All nineteen screenshot
comparisons pass, sixteen pixel-exact; existing differences remain inline-node
(13 pixels), text-decorations (1,341) and canvas-text (1,994). The focused
Unicode/control viewport, extended with coordinated background layers and
math-depth font sizing, is pixel-exact between builds. Actual exits and metrics
are retained in `Build/v/instruction-opt23-validation-result.json`.
The broad-verified baseline is now `8b80c79a` at the observed median
33,258,794,887; additional savings after this batch reset to zero.

The measured candidate replaces the authenticated round22 executable in
`Build/v/Vox.app`; native text SHA-256 is `783716b09e63e10655019eeb857344f3277e408ec94342a0b24f1ee27f83ef2c`.
Bundle signing, deep strict verification and headless startup pass.
Independent native media completion/error-handler changes are preserved and
excluded from both compared binaries and the app snapshot. The existing GUI
process was left running. Chrome instruction and functionality parity remain
unverified, including GitHub module hydration and populated file rows.

## Borrowed reads of retained scalar style values

Feature `fab6eba8` reads the retained typed box directly when extracting a
length, number or percentage. The DOM value owns that box throughout the
synchronous read. This removes an intermediate optional `StyleValue` copy and
its GC root; it does not remove required collection or allocate a replacement
arena. A retained value with a different type still returns no scalar even
when its serialized text looks valid. Values without a typed handle retain
the original parser, whitespace handling and trailing-token rejection.

Four new cases cover length units and signed/fractional magnitudes, exact
number/percentage types, misleading bridge text, other retained types and
calculations, serialized parsing, invalid trailing input, and replacement
handles across explicit collection. Together with the retained cascade,
keyword, inheritance and property-source checks, **eighteen functional cases
plus one diagnostic pass in both GC modes**, including C `-O2` with Boehm.
Each run passes 3,729 assertions. The initial candidate builds exhausted disk
space while generating C, after zero V checker errors and before tests ran.
Those logs, exits and empty C outputs are retained. Completed profiling and older
allocation-trace artifacts were compressed with SHA-256 round-trip checks and
executable modes recorded; the unchanged candidate then passed both GC modes.

A fresh full-process `v -profile` GitHub replay uses the exact round23 runtime
snapshot and frozen native inputs in a separate C `-O1`/Boehm build. It records
465,867 calls to the length reader, 135,992 to the number reader and 3,625 to
the percentage reader: 605,484 calls across the screenshot process. These are
diagnostic calls across module initialization and all rendering work, not
first-frame-only counts or estimates of instructions saved. Profiling has no
`-profile-fns` filter or counter reset; `-profile-no-inline` omits inline-marked
functions from instrumentation. Instrumented times and instruction counts are
excluded from normal page results. The raw profile, exact argv, generated-C
scope proof and source manifest reference are under
`Build/v/instruction-opt24-profile-*` and `instruction-opt24-v-profile.txt`.

Three fixed alternating diagnostics perform 256 complete property-computation
passes with all 355 initial longhands explicitly cascaded and font size fixed
at 16px. A sixteen-entry ring retains outputs; setup, eight warmups, collection
and assertions stay outside the hardware counter interval. All checksums match
the independent reference `(355 + 16*64)*256 = 353024`.
Median work falls **173,400,898 → 171,215,549
instructions (1.26% fewer)**; all three pairs improve. This all-longhand
diagnostic is separate from GitHub whole-page work. Plans, aggregate, exact
commands and results are retained under `Build/v/instruction-opt24-*` and
`opt24-scalar-focused-test.v.txt`.

Thirty alternating normal-build GitHub pairs were fixed before measurement,
using fresh copies of the same immutable cache, the frozen native library,
a 1024×768 viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Optional typed scalar inspection | 33,186,479,019 |
| Borrowed scalar inspection | 33,138,879,247 |

The observed change is **-0.14%**
(47,599,772 instructions saved); **16/30 pairs improve**.
The paired median saving is 67,859,699.5; its 95% paired percentile
bootstrap interval is **-221,048,596.5 to 256,119,497.5** instructions
(30,000 resamples, seed 24). The paired interval includes zero, so a repeatable
whole-page gain remains unestablished. Repeatable page savings credited: 0.
All sixty captures have valid 1024×768 geometry, one installation,
two required geometry passes and one shell paint recording before the first
frame. No observations were discarded, extended or selected after results.
Checkpoint intervals remain process-wide deltas rather than function self cost.
Raw reports are `Build/instructions/vox-opt24-interleaved-*`; paired evidence
is `Build/v/instruction-opt24-comparison-evidence.json`.

The control reuses the exact round23 executable and immutable runtime snapshot,
including borrowed property sources `8b80c79a`. The sole runtime source change
is `css/computed_interpolation.v`. The generated-C audit requires every other
function, type layout and resource to match after compiler identities, embed
keys and authenticated source assertion offsets are canonicalized. All three
serialized parser tails match byte for byte. All 120 common native input hashes
and the shared library remain unchanged. Proofs are retained in
`Build/v/instruction-opt24-matching-provenance.json`.

The observed page median crossed the user's 5,000,000-instruction gate, so
one broad batch ran after measurement. All six commands for 87 selected CSS,
SVG and layout cases pass in both GC modes. All nineteen screenshot comparisons
pass, sixteen pixel-exact; existing differences remain inline-node (13 pixels),
text-decorations (1,341) and canvas-text (1,994). The focused Unicode/control,
background and math-depth viewport is pixel-exact between builds. Actual exits
and metrics are retained in `Build/v/instruction-opt24-validation-result.json`.
The broad-verified baseline is now `fab6eba8` at the observed median
33,138,879,247; additional savings after this batch reset to zero.

The measured candidate replaces the authenticated round23 executable in
`Build/v/Vox.app`; native text SHA-256 is `eef341b4e7695e7623fe71942dac1447431be5da7ffb859fee7c0da0d5f51221`.
Bundle signing, deep strict verification and headless startup pass.
Installation follows the existing positive observed median policy, with the
uncertainty above.
Independent native media completion/error-handler changes are preserved and
excluded from the compared binaries and app snapshot. The existing GUI process
was left running. Boehm and JavaScriptCore remain enabled. Chrome instruction
and functionality parity remain unverified, including GitHub module hydration
and populated file rows.

## Rejected unused-context copy optimization

Attempt `3ad9a504`, reverted by `46fdbe37` after its page median regressed,
avoided repeated cached-context copies and dependency resets
for values needing no computation. Their first visit still initializes a cold
context category through the original getter at the same point in property
order; later visits inspect only cache presence. This preserves the first
observed font metrics, writing mode and
query-container lookup state. Simply deferring all context initialization could
change those inputs. Font, line-height and generic categories keep the same
mapping, and the public getter still returns an independent context value.
Viewport tracking continues to reset and propagate around every actual value
computation. Cache ownership, Boehm collection and JavaScriptCore are unchanged.

Five new cases cover all nineteen font-category IDs, separate line-height and
generic caches, seeded font metrics, per-pass clearing across collection,
unchanged/inherited values with stale dependency flags, first generic-context
initialization before a later writing-mode change, and actual viewport/font
dependencies across successive passes. Together with the retained cascade,
scalar, inheritance, property-source and targeted length/cache tests,
**thirty functional cases plus one diagnostic pass in both GC modes**,
including C `-O2` with Boehm. Each run passes 3,997 assertions.

The initial fixture helpers used Result propagation without Result return
types and declared a value return for a pointer constructor. All three initial
checkers rejected these helpers before C generation or tests. Only the helpers
were corrected; runtime sources and normal browser inputs stayed unchanged.
Original fixtures, aggregate hashes, checker exits and dependency failures are
retained in `Build/v/instruction-opt25-fixture-revision.json` and related logs.
Completed older artifacts were compressed with SHA-256 round-trip checks and
executable modes retained in archive journals.

A paired `v -profile` replay uses the identical focused aggregate in separate
C `-O1`/Boehm builds. Both execute **302 style passes, 56,880 value computations
and 899 font-metric construction calls**. Context-getter calls fall
**97,638 → 57,004 (41.62% fewer)**. The new cache-presence path handles
40,734 unchanged-value visits. Tracking resets fall 97,613 → 56,879.
Profiling covers module initialization, all focused cases, warmups and the
diagnostic, with no `-profile-fns` filter or counter reset.
`-profile-no-inline` omits inline-marked functions from instrumentation.
Only call counts are interpreted; instrumented times and instructions are
excluded from normal page results. Exact argv, raw profiles and generated-C
scope proofs are under `Build/v/instruction-opt25-profile-*` and
`instruction-opt25-{before,final}-v-profile.txt`.

Three fixed alternating diagnostics perform 256 complete property-computation
passes with all 355 initial longhands explicitly cascaded and font size fixed
at 16px. A sixteen-entry ring retains outputs; setup, eight warmups, collection
and assertions stay outside the hardware counter interval. All checksums match
the independent reference `(355 + 16*64)*256 = 353024`.
Median work falls **169,899,922 → 165,106,228
instructions (2.82% fewer)**; all three pairs improve. This all-longhand
diagnostic is separate from GitHub's cascade and whole-page work. Plans,
aggregate, commands and results are retained under `Build/v/instruction-opt25-*`
and `opt25-context-focused-test.v.txt`.

Thirty alternating normal-build GitHub pairs were fixed before measurement,
using fresh copies of the same immutable cache, the frozen native library,
a 1024×768 viewport and the first native
`navigation_to_first_document_paint` endpoint.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Context copies for every visited value | 32,917,340,013.5 |
| Context copies only for computed values | 33,775,976,869 |

The observed change is **+2.61%**
(-858,636,855.5 instructions saved); **15/30 pairs improve**.
The paired median saving is -4,633,306.5; its 95% paired percentile
bootstrap interval is **-868,011,039 to 159,457,339.5** instructions
(30,000 resamples, seed 25). The paired interval includes zero, so a repeatable
whole-page change remains unestablished. Repeatable savings credited: 0.
The worse observed median was sufficient to reject this optimization;
`46fdbe37` restores the previously verified implementation and removes its
feature tests. The candidate, tests and evidence remain in history and snapshots.
All sixty captures have valid 1024×768 geometry, one installation,
two required geometry passes and one shell paint recording before the first
frame. No observations were discarded, extended or selected after results.
Checkpoint intervals remain process-wide deltas rather than function self cost.
Raw reports are `Build/instructions/vox-opt25-interleaved-*`; paired evidence
is `Build/v/instruction-opt25-comparison-evidence.json`.

The control reuses the exact round24 executable and immutable runtime snapshot,
including retained scalar reads `fab6eba8`. The sole runtime source change is
`css/computed_interpolation.v`. The generated-C audit permits changes only to
the property loop and context getter plus two new private helpers. It
authenticates the original nineteen font-category IDs and verifies that context
construction and cache-hit source bodies after classification are identical.
The warm path has no optional-context local; a cache hit reads only presence.
All other executable logic, layouts and resources match after compiler
identities, embed keys and authenticated assertion-line mappings are
canonicalized. All 120 common native input hashes and the shared library
remain unchanged. Proofs are in `Build/v/instruction-opt25-matching-provenance.json`.

The observed page saving stayed below the user's 5,000,000-instruction gate,
so broad suites were skipped. The focused Unicode/control, background and
math-depth viewport is pixel-exact between builds. Actual exits and metrics are
retained in `Build/v/instruction-opt25-validation-result.json`. The last broad
baseline remains `fab6eba8`; additional credited savings are
0.

The observed page median did not improve, so the signed round24 application
remains installed in `Build/v/Vox.app`. The local diagnostic improvement receives
no whole-page runtime credit.
Independent native media completion/error-handler changes are preserved and
excluded from the compared binaries and app snapshot. The existing GUI process
was left running. Chrome instruction and functionality parity remain
unverified, including GitHub module hydration and populated file rows.


Separate GC tracing replays the same before/candidate binaries in three fixed
pairs. Collections through the first frame are 27/29/27 for the control and
27/28/27 for the candidate. The library starts fifteen marker helper threads
on this eighteen-processor host. Trace timing and instrumented instruction
counts are excluded from the normal result. A separate three-pair probe on the
unchanged round24 binary compares the default collector with `GC_MARKERS=1`:
its observed median falls 32,779,422,844 → 32,108,764,221 instructions (2.05%),
with two of three pairs improving. This preliminary configuration probe is
not confirmatory, adds no credited saving and does not extend the thirty-pair
candidate comparison. Plans and raw data are retained under
`Build/v/instruction-opt25-gc-*` and `instruction-gc-markers-probe-*`.

## Default Boehm marking to the initiating thread

Feature `36142146` sets `GC_MARKERS=1` through a V compiler flag in
`main.v`. This host previously used sixteen total markers, including fifteen
helper threads. Boehm remains enabled for the shared DOM graph, and
JavaScriptCore retains its collector. Existing scoped arenas remain in use.
The linked header calls `GC_set_markers_count(1)` before `GC_init()`;
the library then honors the `GC_MARKERS` environment override.
`tools/check_gc_markers.py` verifies actual browser startup: default marker
counts change from sixteen to one, both builds use two under `GC_MARKERS=2`,
and all four checks complete eight collections and pass the engine/JS smoke test.

Thirty alternating pairs were fixed before measurement, comparing the retained
round24 executable with the same frozen runtime plus this flag. Both use normal
C `-O2`, Boehm GC, the frozen native library, fresh copies of the immutable GitHub
cache and a 1024×768 document viewport. Both clear the environment override;
V profiling and allocation wrappers are off. The primary counter is
`native.scopes.navigation_to_first_document_paint[0]`.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Automatic marker count | 33,036,972,779.5 |
| One marker by default | 32,136,369,324.5 |

The observed reduction is **900,603,455 instructions
(2.73%)**, with **24/30 pairs improving**.
The paired median saving is 925,426,541; its 95% paired
percentile bootstrap interval is **835,019,108.5 to 1,168,396,823.5** instructions
(30,000 resamples, seed 26). This supports a repeatable reduction for this
cached workload. Repeatable savings credited: 900,603,455.
All sixty complete captures retain the cache and binary hashes, one installation,
two geometry passes, one shell paint before the first frame and valid viewport
geometry. FuseCode interrupted one attempt in pair 25 before the primary endpoint:
all 48 complete reports were retained, the incomplete attempt was logged and
retried, and the original schedule finished without discarding a completed
observation or extending the sample.

A separate fixed thirty-pair confirmation uses the **same executable and file
path** for both variants, selecting sixteen markers or one through the verified
environment override. Its medians are 32,983,649,024.5 and
32,230,529,807 instructions, a **2.28%** reduction
(753,119,217.5 instructions); **22/30 pairs improve**.
The paired median saving is 758,435,970.5, with a positive 95%
paired interval of 476,027,209 to 887,849,820 (30,000 resamples, seed 2601).
All sixty confirmation captures pass the same cache, binary, geometry and frame
checks. One cache copy failed with ENOSPC before the pair-26 browser launch;
all fifty completed reports were retained, and the remaining five scheduled
pairs resumed with the cache in the same location. These samples remain
separate from the primary comparison. They confirm the GC effect without
additional savings credit or another broad batch. See
`Build/v/instruction-opt26-same-image-{plan,result,resume}.json` and
`Build/instructions/vox-opt26-same-image-*`.

System-disk exhaustion interrupted compiler output before measurement began.
Generated C and compiler temporary files then used scoped scratch storage;
the candidate executable and compressed C evidence are persisted in `Build/v`.
All generated executable logic, record layouts and embedded resources match
after compiler identities and authenticated source-line metadata are normalized.
The initial audit difference was the include comment shifting from `main.v:46`
to `main.v:49`, exactly matching the three inserted source lines. Native arguments
add only the marker definition apart from artifact paths; all 120 frozen native
inputs remain unchanged.

Thirty focused functional cases plus one diagnostic pass with 3,997 assertions
in both optimized Boehm builds and the final no-GC ownership build. The focused
Unicode/control, background and math-depth viewport is pixel-exact. The saving
crossed the user's 5,000,000-instruction gate, so one broad batch ran: all six
commands for 87 selected CSS/SVG/layout cases pass in both GC modes with the new
marker definition. All nineteen screenshot comparisons pass, sixteen pixel-exact.
Existing differences remain inline-node (13 pixels), text-decorations (1,341)
and canvas-text (1,994).

The signed candidate replaces the authenticated round24 executable in
`Build/v/Vox.app`; deep strict signing verification and headless startup pass.
Native text SHA-256: `84a9c7ed826ca9a414b4d64c347a0c01c95a8921926e5a84234fbed30b91643b`.
The existing GUI process was not restarted. Independent native media work is
preserved in the repository and excluded from both measured snapshots; the
installed artifact retains that measured runtime scope.
The broad baseline is now `36142146` at 32,136,369,324.5
instructions, with additional savings after this batch reset to zero.
Chrome instruction and functionality parity remain open: its earlier counts
use a different endpoint and populated file rows.

Evidence: `Build/instructions/vox-opt26-interleaved-*` and
`Build/v/instruction-opt26-{comparison-evidence,matching-provenance,c-audit-result,
gc-macro-proof,gc-policy-result,cli-resume,capture-audit,build-retry,
validation-result,bundle-result}.json`.

## Skip scans for absent pseudo styles

Feature `909f2968` avoids the known-pseudo-element scan during keyframe
invalidation when an element has no pseudo records. The base element's
animation names are checked first. A nonempty record map retains the complete
original scan, including computed pseudo styles that have no layout node.
Checking only painted pseudo-elements would miss those styles.

Six focused functional cases plus one diagnostic pass with **1,131 assertions**
in before/final C-optimized Boehm builds and in the final no-GC ownership build.
Coverage includes base lists and quoted names, case sensitivity, unlaid-out
pseudo styles, the highest known pseudo, cleared/reused records, forced GC,
precise invalidation, shadow descendants and shadow-host fan-out.
The controlled diagnostic makes 4,096 passes over 64 live elements: 62 empty
pseudo maps, one base animation name and one pseudo-only name. Three fixed
alternating pairs all improve: median **350,882,116 → 19,244,283 instructions
(−94.52%)**, preserving the independent checksum of 4,096. Setup, eight warmups,
forced collection and assertions stay outside the counter.

Fresh paired V profiles of the identical focused replay record 262,678 calls
to the invalidation predicate in each build. Pseudo-style queries fall from
**5,440,151 to 310,031 (−94.30%)**, avoiding 5,130,120 queries; actual
animation-name style checks remain 8,222 in both builds. These are full-process
C `-O1`/Boehm call counts, including setup and the probe, with `-profile-no-inline`
and no filter or counter reset. Instrumented timings and instruction counts
receive no normal-page credit.

Thirty alternating normal-build pairs were fixed before measurement, comparing
the retained round26 executable/source snapshot with this guard. Both executable
images are persisted in `Build/v`, use C `-O2` with Boehm and one marker, and
load the same frozen native library. Both clear `GC_MARKERS`; profiling and
allocation wrappers are off. Fresh byte-identical copies of the immutable cache
use one RAM-backed parent for all pairs, chosen before measurement to avoid
system-disk cache-copy exhaustion. The endpoint remains
`native.scopes.navigation_to_first_document_paint[0]` at 1024×768.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Probe all known pseudos | 32,167,225,634 |
| Skip empty pseudo maps | 31,715,678,253.5 |

The observed reduction is **451,547,380.5 instructions
(1.40%)**, with **23/30 pairs improving**.
The paired median saving is 457,607,797.5; its 95% paired
percentile bootstrap interval is **384,674,505 to 551,900,614.5** instructions
(30,000 resamples, seed 27). Repeatable page savings credited:
451,547,380.5. No completed observations were discarded and
the sample was not extended after results.

All sixty primary intervals have one installation, two geometry passes and one
shell paint recording before the first frame. All captures have valid viewport,
cache and binary hashes. Candidate pair 1 refreshed after the primary endpoint;
its screenshot shows the later document and its process/installation totals
include that extra work. The retained primary sample is the initial cached
frame at 31,685,160,623 instructions, exactly the predeclared first-scope rule.
The later refresh is recorded separately in `instruction-opt27-capture-audit.json`.

All other generated executable logic, layouts and resources match after compiler
identities and authenticated embed keys are canonicalized. Removing the one
new C branch reproduces the old predicate after temporary names are normalized;
the existing pseudo scan is unchanged. Native flags, GC initialization and all
120 frozen native inputs are unchanged apart from artifact paths.

The observed saving crossed the user's 5,000,000-instruction gate. One broad
batch completed: all six final jobs for 87 selected CSS/SVG/layout cases pass
in both GC modes. Initial outer `vtest` jobs reported blank compilation failures
with zero test runtime during disk exhaustion, and the supervisor's result write
also failed with ENOSPC. The successful SVG/Boehm job was retained; the five
unfinished jobs used the identical V test harness and unchanged sources with
explicit RAM-backed outputs. Their actual commands, logs and exits are retained.
All nineteen screenshot comparisons pass, sixteen pixel-exact; existing
differences remain inline-node (13 pixels), text-decorations (1,341) and
canvas-text (1,994). The focused viewport is pixel-exact.

The measured candidate is installed in `Build/v/Vox.app`; ad-hoc signing,
deep strict verification and headless startup pass. Native text SHA-256:
`de648d132a6e0fa544029a1bb353b8f56d2d503e0a5cf3e777a269733b39b30c`. The existing GUI process was not restarted.
Independent native media work is preserved in the repository and excluded from
both comparison snapshots; the installed artifact retains the measured runtime
scope. GC remains enabled. The broad baseline is now `909f2968` at
31,715,678,253.5 instructions; additional savings after this
batch reset to zero. Chrome instruction/functionality parity remains open.

Evidence is under `Build/instructions/vox-opt27-interleaved-*` and
`Build/v/instruction-opt27-*`, including `comparison-evidence.json`,
`matching-provenance.json`, `profile-evidence.json`, `diagnostic-result.json`,
`capture-audit.json`, `broad-resume.json`, `completed-artifact-compression.json`,
`validation-result.json` and `bundle-result.json` with the round prefix.

## Fill ASCII tokenizer arenas directly

Feature `2cb35962` fills the tokenizer's code-point and byte-offset tables
from bytes when every byte is below 128. The allocation and release boundary
stay unchanged; non-ASCII input retains the original rune iterator. Boehm
remains enabled with one marker, and JavaScript still uses JavaScriptCore.
An initial printable-only `string.is_ascii()` check missed CSS newlines and
showed no controlled gain; it was replaced before any browser observations.

Twelve focused functional cases plus one diagnostic pass **165,086 assertions**
in before/final Boehm builds and final `-gc none`, all with C `-O2`. Coverage
includes all 128 ASCII bytes, Unicode byte offsets, CRLF/FF/NUL filtering,
empty input, escape spellings, retained source strings and forced collections.
The controlled probe fills and releases 1,024 arenas of 1,984 ASCII bytes,
including newlines. Setup, eight warmups, forced GC and assertions are outside
the counter; all three alternating pairs preserve checksum 4,161,536.
Its median is **67,726,882 → 13,086,891
instructions (-80.68%)**. This is a local result.

Fresh full-process `v -profile` replays record 1,283 arena
constructions in each build. Rune-iterator calls fall from **2,538,014
to 277,440**. These C `-O1`/Boehm call counts include initialization,
functional tests and the probe; no filter or counter reset is used.
Instrumented timings and counts are excluded from normal-page measurements.

Thirty alternating normal-build pairs were fixed in advance, seed 28 and
30,000 paired bootstrap resamples. Both persisted executable images use C
`-O2`, Boehm, one marker and the same frozen native library. Each run receives
a fresh byte-identical cached GitHub copy on the same RAM-backed volume.
The endpoint remains `navigation_to_first_document_paint[0]` at 1024×768.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Rune iterator for every input | 31,780,944,181 |
| Direct ASCII table fill | 31,626,063,087 |

Observed saving: **154,881,094 instructions
(0.49%)**, 20/30 pairs improve.
Paired median saving: 72,481,159; 95% paired percentile
bootstrap interval: **13,874 to 173,522,760.5** instructions. The lower bound
is close to zero, so the evidence for a repeatable page gain is narrow.
Repeatable page savings credited: 154,881,094. No completed observations
were discarded and the sample was not extended after results. Two startup attempts,
one control and one candidate, hit the watchdog before parsing or the primary
endpoint. All 32 completed captures at the first interruption and all 53 at
the second were retained by hash. The remaining captures resumed with the same
binaries, cache and order; both incomplete logs are preserved separately.

All sixty captures retain valid viewport, cache and executable hashes; the
capture audit confirms one installation, two geometry passes and one shell
paint recording before each primary endpoint. Ten captures have a later
installation; their screenshots/process totals include that later work, while
the predeclared first-frame sample is retained for every capture.
The generated-C audit permits only the arena constructor to change; all other
logic, layouts and resources match after compiler identities are normalized.
Two byte-identical interface helpers only change declaration order; one parser
assertion line is mapped to its unchanged source.
All 120 frozen native inputs, GC initialization and native flags are unchanged.
Disk exhaustion during initial snapshot creation was handled by moving this
round's snapshots and compiler scratch to the existing RAM-backed volume.
The snapshot's upstream dependency link was restored before successful builds.
Those pre-measurement failures are retained separately. After measurement
and broad tests, all three snapshots were persisted back under `Build/` with
runtime hashes verified; compiler and profile C archives are also durable.

The observed saving crossed the 5,000,000-instruction gate. One broad batch
passes: six direct V test-harness jobs cover 87 selected CSS/SVG/layout cases
in both GC modes, with explicit RAM-backed outputs and six recorded zero exits.
All nineteen screenshot comparisons complete, sixteen exact. Existing pixel
differences remain inline-node 13, text-decorations 1,341 and canvas-text 1,994;
the focused viewport is exact. A launch produced no image after twelve
completed comparisons; all six test passes and the twelve completed image
comparisons were retained, and only the seven unfinished comparisons resumed.

The measured candidate was installed in `Build/v/Vox.app`; ad-hoc signing,
deep strict signature verification, headless startup and default/override GC
marker checks passed. Its native text SHA-256 is
`3d44b5a4208c993ac5d9456ffa20f6696ea63d8a080fc0c49eac88e68c64ec62`.
A subsequent independent build replaced the app before the final audit. That
newer app is preserved and includes the optimization: all 183 constructor
instructions match after authenticating relocated constants and call targets.
Signature, headless startup and default/override GC checks pass again for that
app, whose native text SHA-256 is
`9cf9a6c3c664c74533eff03f5b1dd36b533316ed9ea6add4d7fa80af24a56d8e`.
The full independent build is not rebenchmarked and receives no additional
instruction credit. The existing GUI process was not restarted by this round.
Independent native media changes remain preserved; they are excluded from the
frozen performance comparisons and present in the later independent app build.
The broad baseline is `2cb35962` at 31,626,063,087
instructions, with zero additional savings after this batch. Chrome
instruction/functionality parity remains open; its earlier capture uses a
different endpoint and hydrated content.

Evidence: `Build/instructions/vox-opt28-interleaved-*` and
`Build/v/instruction-opt28-*`, including comparison, C/source provenance,
focused diagnostics, fresh profiles, capture audit, validation and bundle results.

## Probe decoded CSS bytes before scalar filtering

Feature `5e617ea2` checks decoded CSS bytes for CR, FF and NUL before
entering the Unicode replacement loop. These code points are single bytes in
validated UTF-8; surrogate code points cannot occur in decoder output. Decoding
and the complete replacement loop remain unchanged, including legacy encoding,
UTF-16, BOM and malformed-input handling. GC stays enabled with one marker.

Seventeen focused functional cases plus one diagnostic pass **165,227 assertions**
in before/final Boehm and final no-GC builds, all C `-O2`. Five new cases cover
all ASCII bytes beside Unicode scalars, repeated CR/CRLF, legacy and UTF-16
input, BOMs and malformed UTF-8. An initial check exposed the direct filter's
pre-existing loss of a final standalone CR in both control and candidate; that
separate behavior is unchanged and recorded in the initial-check evidence.
Nonterminal CR and CRLF behavior is covered by the completed focused suite.

The controlled probe retains decoding: 512 complete filter calls on 2,112-byte
Unicode CSS input, with setup, eight warmups, forced GC and assertions outside
the counter. Three alternating pairs all improve; the independent checksum
remains 1,136,128. Median instructions: **172,592,494 →
158,433,048 (-8.20%)**.
Fresh full-process `v -profile` replays retain 714 filter calls in each build;
rune-iterator calls fall **1,177,237 → 33,072**. Profiles use C
`-O1`, Boehm, `-profile-no-inline`, no filter and no counter reset. Instrumented
timings and counts receive no normal-page credit.

Thirty alternating normal-build pairs were fixed before observation, using
30,000 paired bootstrap resamples and seed 29. Both executable images are
persisted in `Build/v`, use C `-O2`/Boehm/one marker, and load the same frozen
native library. Fresh byte-identical cached GitHub copies use the same
RAM-backed parent. The endpoint is `navigation_to_first_document_paint[0]`
at 1024×768. The control is the retained round28 executable; the candidate
changes only this presence probe in the frozen runtime.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Scalar presence check | 31,793,399,656.5 |
| Byte presence check | 31,699,419,363.5 |

Observed saving: **93,980,293 (0.30%)**;
17/30 pairs improve. Paired median saving: 62,499,053.5.
The 95% paired percentile bootstrap interval is **-80,422,250.5 to 105,220,236.5**
instructions. The interval includes zero; repeatable page savings credited: **0**.
All sixty first-frame intervals retain one installation, two geometry passes
and one shell paint recording. 10 captures have later installations;
those later frames remain separate from the fixed first-scope observation.
Executable hashes and retained copied-cache fingerprints match. The control at
pair 13 completed its primary at 31,654,246,001 instructions, then hit the
watchdog during later refresh/layout work. That primary is retained directly
from its unchanged native log without a rerun; the missing screenshot and
unavailable final process-exit report are recorded explicitly. Fifty-nine
completed screenshots have verified dimensions; the recovered observation has
only the requested viewport recorded. Its original per-copy cache fingerprint
was not persisted after the observer failure; its template hash is recomputed
and checked against completed captures under the same fresh-copy protocol.
No completed primary observations were discarded or the sample extended. One
startup failure in candidate pair 22 occurred before parsing or the primary
endpoint. Its failed attempt is archived; the successful retry stayed within
the predeclared three-attempt limit.

The generated-C audit permits only `filter_code_points` to change. Its entire
replacement tail matches after temporary names are normalized; decoding,
other logic, layouts and resources match. Native flags, GC initialization and
all 120 frozen native inputs are unchanged. Generated C and profile C archives
are retained under `Build/v` alongside source manifests and raw observations.

The observed saving crossed the 5,000,000-instruction gate. One broad batch
passes all 87 selected CSS/SVG/layout cases in both GC modes, six recorded zero
exits through the direct V test harness with RAM-backed outputs. All nineteen
screenshot comparisons complete, sixteen exact; existing differences remain
inline-node 13, text-decorations 1,341 and canvas-text 1,994. Focused viewport exact.

The newer independently built app is preserved. Its complete 149-instruction
native filter matches the measured candidate: both relocated constants and all
twelve call targets are authenticated, and every other instruction word is
identical. The full independent app receives no extra page-performance credit.
Signature, headless startup and default/override GC marker checks pass. The
obsolete duplicate current-source build was stopped and receives no build-pass
credit; its interrupted result and cancellation reason remain recorded.
Native text SHA: `4b7724de4f9b0c69301454f45438b6d82daeb52f82b0a17525fa7071d7758af5`. No GUI process was restarted.
The broad baseline is `5e617ea2` at 31,699,419,363.5 instructions,
with zero additional savings after this batch. Chrome parity remains open:
its earlier capture uses a different endpoint and hydrated content.

Evidence: `Build/instructions/vox-opt29-interleaved-*` and
`Build/v/instruction-opt29-*`, including comparison, source/C provenance,
profiles, diagnostics, capture audit, regression exits, current-app native
verification, interrupted duplicate-build evidence and bundle verification.

## Keep decoded CSS in its UTF-8 destination

Feature `a278f7b1` keeps the same fresh selected decoder and invokes its
existing Common UTF-8 processing/output methods. CSS previously materialized
the public TextDecoder's genuine UTF-16 result and converted it back to UTF-8.
The final item flushes the one-shot owner, which is then discarded. Encoding
selection, BOMs, malformed-input repairs, CSS filtering and tokenizer arenas
remain unchanged. The public TextDecoder and all encoding implementations are
unchanged; decoding remains enabled. Boehm stays enabled with one marker.

Twenty-two functional cases plus one diagnostic pass **169,128 assertions**
in before/final Boehm and final no-GC builds, all C `-O2`. Five new cases add
3,901 assertions covering valid scalars and controls, malformed/truncated UTF-8,
UTF-16 endian/BOM/surrogate boundaries, aliases, legacy encodings, Shift_JIS and
fresh-owner isolation. They compare the unchanged public destination with the
CSS destination and include explicit expected Unicode results.

Three alternating controlled pairs improve complete filtering instructions:
**158,257,859 → 84,545,269
(-46.58%)**. Each probe makes 512 complete filter calls on
2,112-byte Unicode CSS, with setup, eight warmups, forced GC and assertions
outside the hardware counter. All checksums remain 1,136,128.
Fresh full-process `v -profile` replays of the focused harness retain
4,615 CSS decode calls
in each build. Selected UTF-8 decoder calls to its UTF-16 destination fall
**8,424 → 3,848**; calls to its UTF-8 destination
change **0 → 4,576**. Oracle checks still use
the public UTF-16 destination. Profiles use C `-O1`, Boehm and
`-profile-no-inline`, with no filter/reset; only call counts are interpreted.

The page comparison fixes thirty alternating normal-build pairs before any
observation, with 30,000 paired bootstrap resamples and seed 30. Both C
`-O2`/Boehm/one-marker executables are persisted before measurement and load
the same frozen native library. Every run starts with a fresh identical cached
GitHub copy on the same RAM-backed volume. The viewport is 1024×768; the primary
endpoint is `navigation_to_first_document_paint[0]`.

| Build | Median instructions through first native document frame |
| --- | ---: |
| Public UTF-16 projection | 31,623,734,484.5 |
| Existing UTF-8 destination | 31,304,933,831.5 |

Observed saving: **318,800,653 instructions
(1.01%)**; 24/30 pairs improve. Paired median saving:
289,428,758.5. The 95% paired percentile bootstrap interval is
**230,304,180.5 to 883,081,890.5** instructions. The positive paired interval supports a repeatable gain on this cached workload.
Repeatable page savings credited: 318,800,653.

All sixty first-frame intervals retain one installation, two geometry passes
and one shell paint recording. 5 observations have later
installations, outside the primary endpoint. 60 screenshots have verified
1024×768 dimensions. All sixty primary observations also have completed screenshot/process reports.
One startup retry is archived, permitted only before parsing and
the primary under the predeclared three-attempt limit. No completed primary is
discarded and the sample is not extended.
The first six pairs completed during an earlier CLI resume and are retained;
the next interrupted startup ended before parsing at pair 7. Its terminal
status is unavailable and receives no pass credit. Continuation starts with
that same unmeasured slot, with receipts in
`Build/v/instruction-opt30-cli-resume-2.json`.

The generated-C audit permits only `decode_css_input` to change. The queue
struct moves to its first CSS use; its complete definition is authenticated as
identical, as are two reordered interface helpers. All other logic, layouts,
resources, native flags and GC initialization match after established compiler
identity/source-location normalization. All 120 cached native inputs match.
Before the first observation, 37 repository native includes are pinned to the
immutable source snapshot; their hashes are checked. This keeps an independent
Root native line-paint change out of the performance candidate. The control's
frozen native source is identical. The initial declaration-order audit failure
and interrupted compile logs remain retained without pass credit.

The compiled candidate C SHA256 is
`f2842eef2e2b9b0b99432b594458454b950b3d3ef3cb5e377d47357d73f0aab7`.
Durable compressed C, focused-binary and profile-binary archives have both
uncompressed and archive hashes in
`Build/v/instruction-opt30-artifact-archives.json`; full-process profile C hashes
are in `Build/v/instruction-opt30-profile-evidence.json`. The pre-existing
terminal standalone-CR loss documented in the previous round remains outside
this change.

The observed reduction crossed the 5,000,000-instruction gate. One broad batch passes all 87 selected CSS/SVG/layout cases in both GC modes, six actual zero exits. Nineteen screenshot comparisons complete, sixteen exact; the existing differences remain inline-node 13, text-decorations 1,341 and canvas-text 1,994. The focused viewport is pixel-exact.
The broad cases use the retained selected regression snapshot and this CSS
implementation, with its source base and overlay declared in
`Build/v/instruction-opt30-broad-manifest.json`.

The separately built current-source snapshot is available at `/Users/alex/code/vox2/Build/v/Vox-opt30.app`. Its decoder C body matches the measured candidate byte for byte, retaining independent work present at snapshot time. It receives no extra page-performance credit; frozen regression results do not cover unrelated current-source changes. The canonical app is preserved because its original pre-build hash was not persisted across the CLI interruption. No GUI process is restarted.
Signature, headless startup and actual GC collection checks pass, with default
marker 1 and override 2. App native text SHA:
`b522380c6c8d605024463417c0561e58dbbcc7ac004f2942dc86f68ee1a2978c`.

Chrome parity remains open: its earlier capture measures a different endpoint
and hydrated content. Evidence is retained in
`Build/instructions/vox-opt30-interleaved-*` and `Build/v/instruction-opt30-*`,
including original observations, C/native-input provenance, profiles, diagnostics,
actual regression exits, snapshot/app provenance and GC checks.

## Resolve public lengths before constructing unused contexts

Feature `137e4e85` extends the existing context-free layout conversion to
both public computed-length entry paths. Absolute units use the existing
fixed-point absolute conversion, and percentages retain the existing rounded
basis and truncated percentage conversion. Relative and calculated values
continue through the full font, viewport and per-resolution container-query
context. SVG unitless-number rules, animation precedence and rejected value
kinds remain unchanged.

Eighteen functional cases plus one inactive diagnostic pass **2,004 assertions**
in before/final Boehm and final no-GC builds, all native C `-O2`. Three new cases
compare exact results against the original full-context path across every
absolute unit, fractional and saturation boundaries, percentages, live font and
viewport changes, calculations, animation replacement and SVG number rules.
Existing query-container geometry and per-context cache isolation checks remain
in the same focused harness.

Three alternating controlled pairs reduce **8,192 complete public length
resolutions** from **7,470,747 to 2,769,994** retired
instructions (-62.92%). All checksums are 204,800. The probe
uses 32 real computed styles with a DOM subject, half absolute and half
percentage, and 128 iterations of both APIs. Setup, the full-context oracle,
eight warmups, forced collection and checksum assertions are outside the
counter. This is a local result and receives no separate page credit.

Fresh full-process C `-O1`/Boehm profiles execute the same 4,682 property resolver
calls and 4,675 component resolver calls in both builds. Context constructions
fall **9,737 to 438**. Profiles include module initialization, all focused cases
and the diagnostic, with `-profile-no-inline`, no filter and no counter reset.
Only call counts are interpreted.

Thirty alternating normal C `-O2`/Boehm/one-marker pairs were fixed before any
primary observation, with 30,000 paired bootstrap resamples and seed 31. Each
variant uses the same frozen library and a fresh copy of the unchanged 359-file
cache on the same RAM volume. The document viewport is 1024×768; the endpoint
remains `navigation_to_first_document_paint[0]`.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Full context for every public resolution | 32,288,188,899 |
| Context-free public resolution when possible | 32,211,926,316 |

Observed saving: **76,262,583 (0.24%)**.
17/30 pairs improve; paired median saving is
23,877,597. The 95% paired percentile interval is
**-509,124,286 to 184,175,767.5** instructions. The paired interval includes zero or worse; a repeatable whole-page reduction is not established.
Repeatable page credit: **0** instructions.

All sixty primaries are retained. Each has one installation, two geometry
passes and one shell paint preparation before the endpoint; later installations
occur in 19 observations and remain separate.
59 actual viewport screenshots have verified dimensions. Archived
preparse startup retries: 1. Final pair 25 retains the completed primary from
its post-primary capture watchdog, with unknown terminal status, no PNG and no
original per-copy cache fingerprint. Its raw log and recovery provenance remain
retained; the immutable template fingerprint and declared copy protocol survive.
No completed primary is rerun or discarded, and the cohort is not extended.

Interrupted native and broad controllers retain partial logs with unknown
terminal statuses under `instruction-opt31-interrupted-resume-{1,2}`. Only
unfinished work resumes. One screenshot attempt produced no PNG; its failed
shell receipt and log remain under `instruction-opt31-screenshot-failure-1`.
The successful resumption reuses every completed harness and screenshot. Broad
commands use SSD scratch; the inherited receipt wording "RAM-backed output"
is inaccurate, and the recorded commands show their actual paths.

The generated-C audit permits exactly the two resolver bodies to change; all
remaining executable logic, layouts, resources, GC initialization and native
arguments match the frozen round30 control after established compiler identity
normalization and authenticated snapshot include paths. All 120 common native
inputs are unchanged. Compiled candidate C SHA256:
`1ad6a77eba7529ffb02c8987aa57905930dcfa4bfced9c024a1cc546d719f7c4`.
Durable C and profile archives retain raw/archive hashes in
`Build/v/instruction-opt31-artifact-archives.json`; profile scope proofs and C
hashes are in `Build/v/instruction-opt31-profile-evidence.json`.

The focused absolute/percentage/relative/calc/SVG viewport is pixel-exact.
The observed saving crossed the 5,000,000-instruction gate. All six direct V harness jobs pass: 87 selected CSS/SVG/layout cases in each GC mode, 174 executions. All 19 screenshot comparisons pass, 16 exact; unchanged differences are inline-node 13, text-decorations 1,341 and canvas-text 1,994. The selected regression snapshot's base and overlay remain declared
in `Build/v/instruction-opt31-broad-manifest.json`.

A separate immutable snapshot of contemporary Root sources is packaged at
`/Users/alex/code/vox2/Build/v/Vox-opt31.app`. Its two resolver bodies match after authenticating the
compiler-emitted LengthStyleValue/PercentageStyleValue IDs (210/211 in the
measured image, 214/215 in this Root image) and their conversion helpers and
associated CSS layouts. The initial byte-comparison failure remains retained.
The first native attempt also retained a cJSON header failure; the resumed build
uses the compatibility JSON module's declared cJSON header/object flags, with
additional native inputs hashed separately. Its exact failed native status was
not persisted by the initial controller and receives no pass credit. The
successful resumed compile has an actual terminal status. These dependencies
and independent Root changes receive no frozen benchmark credit or regression
coverage. The canonical app and user's running GUI browser are preserved.
Signature, headless smoke and actual GC collections pass with marker default 1
and override 2. Snapshot app text SHA256:
`cfcde1dcc9bff59fa950bd263ed088c0b4ec4e9edacbf214c975be503d8c7ff9`.

Chrome parity remains unestablished: the earlier Chrome measurements use a
different endpoint and hydrated GitHub content. The continuing optimization goal
requires an equivalent-workload comparison, not a timing or call-count proxy.
Evidence is retained under `Build/instructions/vox-opt31-interleaved-*` and
`Build/v/instruction-opt31-*`, including all actual failures and resumed work.

## Frozen-cache content audit and cyclic inline maxima

The isolated Chrome replay probe (`1bc4df87`) loads the exact cached GitHub
response bodies at their original URLs, blocks every missing or non-GET request,
and records each response's source hash. Chrome for Testing 155.0.8059.79 replays
37 bodies and blocks 126 uncached requests. Its completed DOM contains 72
repository file/directory anchors, and visible filenames appear without the
missing module scripts. The filenames are already present in cached HTML;
Vox's blank labels were a layout defect rather than proof that those labels
required hydration.

This is a content diagnostic with zero performance credit. The legacy cache has
no response headers: the probe explicitly infers MIME and supplies wildcard
CORS/no-store/status-200 headers. It does not recover original response metadata.
Its later document screenshot is not Vox's first submitted-frame endpoint.
The three focused probe tests cover binary/query-key preservation, interleaved
CDP fetch acknowledgements, and blocking uncached/non-GET requests.

Feature `9292a1aa` fixes the layout defect. Atomic inline sizing now uses the
existing cyclic-maximum policy before clamping a percentage `max-width` during
an intrinsic contribution. Resolving that maximum against a zero placeholder
previously reduced the containing flex item to zero width. Definite final layout
still applies the percentage limit, and absolute maxima, minimum precedence and
border-box adjustments remain covered.

The retained before/Boehm test fails with actual width 0 versus expected 60;
its other two original cases pass. The final four cases pass in Boehm and no-GC,
with 16,921 assertions per configuration. They cover percentage and calculated
maxima, wide/narrow flex rows, definite percentage limits, absolute maxima,
minimum precedence and a border-box minimum. No passing focused run was repeated.

A normal C-O2/Boehm diagnostic image built from the frozen round32 integration
plus this one-file fix passes signing, headless smoke and actual viewport capture.
The 1024×768 capture now displays the repository filenames. It remains separate
from contemporary Root work and leaves the canonical app and GUI untouched.
The unchanged 359-file cache retains SHA256
`0570cfa09af662a0f1fa6735a563bad9dc2d332579e75ef06d50931f6a3aae95`.
No page instruction saving or Chrome rendering parity is credited for restoring
previously missing visible content. Other visual differences remain, and a
matching first-frame hardware-instruction comparison is still required.

Evidence: `Build/v/inline-cyclic-max-*`,
`Build/v/filename-correctness-*-result.json`,
`Build/v/filename-correctness-content-evidence.json`,
`Build/instructions/github-filename-correctness.run-1.*`, and
`Build/instructions/chrome-frozen-probe/content-1/`.

## Existing focused-control and viewport-origin integration

Round 32 integrates the already committed focused-control preparation
`058ba684` and viewport-origin preservation `3235339f` into the frozen round 31
runtime. It changes only `layout/document_tree_builder.v`; it does not include
the later filename correction or independent Root/adblock/browser work.
The five focused input/textarea, selection/caret and scrolled-viewport cases
pass **16,596 assertions** in each C-O2 Boehm/no-GC configuration.

The generated-C audit permits the two changed layout bodies and two added
private helpers. Two compiler-emitted RequestClient/RequestSecurityClient
helpers reorder, with their raw bodies authenticated byte for byte before
placing them in fixed order. All remaining logic, layouts, resources and native
arguments match. All 120 common native inputs and 37 frozen quoted includes
are authenticated. Compiled C SHA256:
`74b01612be5677044c3532679cbc16ca50332a7fed7cf5a904ff38b163338f12`.
Durable raw/generated C hashes are in
`Build/v/instruction-opt32-artifact-archives.json`.

Thirty alternating pairs were fixed before observations, using 30,000 paired
bootstrap resamples with seed 32, the same frozen helper and fresh copies of the
unchanged 359-file cache. Both copies use the predeclared SSD scratch directory.
The endpoint remains `navigation_to_first_document_paint[0]`, viewport 1024×768,
native C-O2/Boehm with one marker and no prod/prealloc flags.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 31 | 32,075,423,647.5 |
| Existing layout fixes integrated | 32,055,542,279.5 |

Observed saving: **19,881,368 (0.062%)**.
16/30 pairs improve; paired median saving is
13,437,089.5. The 95% paired percentile interval is
**-132,106,848 to 762,825,416** instructions. The interval includes zero, so
repeatable page credit is **0**. All 60 primaries and 60 actual PNGs
remain retained, with no startup retries or recovered counters. Each first
interval still has one installation, two geometry passes and one shell paint
preparation. These fixes do not remove the page's second geometry pass.
Seven observations contain a later installation, kept separate from the primary.

The observed saving crosses the 5,000,000-instruction broad gate. All six direct
V harness jobs pass: 31 CSS, 10 SVG and 46 layout cases in both GC modes, 174 executions.
The focused viewport is exact. All 19 screenshot comparisons pass, 16 exact;
unchanged differences remain inline-node 13, text-decorations 1,341 and
canvas-text 1,994. The selected regression runtime and overlays are pinned in
`Build/v/instruction-opt32-broad-manifest.json`. The inherited receipt description
"RAM-backed output" is inaccurate; actual broad commands use SSD scratch.

The first native preparation receipt retains a missing control-path error
before compilation; generated C was retained and compiled successfully without
regenerating it. Initial C-audit differences and the helper authentication remain
recorded. The screenshot wrapper initially lacked executable permission, then
a later actual-page capture exhausted its two AppKit/Metal launch retries.
Both failed selections remain archived. Resumption retained all six successful
harnesses, earlier screenshots and the completed reference image, and captured
only unfinished work. No completed primary was repeated.

`/Users/alex/code/vox2/Build/v/Vox-opt32.app` is an isolated **frozen performance comparison app**.
Its signature, headless startup and actual GC collections pass with default
marker 1 and override 2. The native text hash matches the measured executable:
`ca8891ed26173c13aea41a55c1b2168624a2d45a492093d2c1dcddead24152ae`.
It retains the old blank filenames and is not the contemporary Root browser.
The canonical app and user's GUI are preserved. The separate filename-correctness
image described above restores those labels and receives no performance credit
from this comparison. Neither image establishes Chrome parity.

Evidence: `Build/instructions/vox-opt32-interleaved-*` and
`Build/v/instruction-opt32-*`. The GitHub broad baseline resets only after the
completed batch to 32,055,542,279.5 instructions; additional
observed savings after this batch are zero.

## Release the private inline item buffer after formatting

Feature `77a59b25` releases the outer item array owned by the private
inline-formatting iterator when that formatting run returns. Item records are
consumed by value; published line fragments retain their own node and glyph
references. The public iterator API and retained glyph storage are unchanged.

Nineteen functional cases and an inactive diagnostic pass **23,135 assertions**
in before/final Boehm and final no-GC C-O2 configurations. Two new lifetime cases
retain wrapped mixed-direction/Unicode text and ellipsis glyphs through later
formatting runs and forced collection. Existing line-box merge, wrapping,
grapheme, ellipsis and cyclic-maximum cases remain in the focused harness.
The original aggregate import error is retained; no test cases ran in that
failed compilation. Corrected passing checks were not repeated for validation.

Three fixed alternating controlled pairs reduce **512 complete inline formatting
runs** from **2,643,948,073 to 2,629,170,910** retired
instructions (-0.56%). All three pairs improve; all six
checksums are 17,694,720. The probe uses 16 text nodes. Setup, eight warmups, the
expected result and forced collection precede the counter; the checksum
assertion follows it. This local result receives no separate page credit.

Fresh full-process C-O1/Boehm profiles report **776 formatting runs and 776
iterator constructions** in each variant. They include all focused cases and
the enabled diagnostic, with profile-no-inline, no filter and no reset. Only
call counts are interpreted. The generated-C audit permits only the private
formatting function to change, adding one outer-array release at return.
All other logic, layouts, resources, GC initialization and native arguments
match after established compiler identity and authenticated include normalization.
The two raw-identical RequestSecurityClient helpers may reorder. All 120 common
native inputs and 37 frozen quoted includes are authenticated. Compiled C SHA256:
`68cb24afbc3bf6cdc7c7acec423aa5bef1c7c148237a63318c6a0f03d395300a`.
Durable C/profile archive hashes are recorded in
`Build/v/instruction-opt33-artifact-archives.json`.

Thirty alternating pairs were fixed before observations, with 30,000 paired
bootstrap resamples and seed 33. Both variants include the filename correction
`9292a1aa`, use the same frozen helper and fresh copies of the unchanged 359-file
cache, and use the same predeclared SSD scratch directory. The document viewport
is 1024×768 and the endpoint is `navigation_to_first_document_paint[0]`.
Normal native C-O2/Boehm uses one marker, without prod/prealloc flags.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Restored filenames, ordinary item-buffer collection | 32,007,846,653 |
| Restored filenames, release after formatting | 31,972,073,267 |

Observed saving: **35,773,386 (0.112%)**.
17/30 pairs improve; paired median saving is
22,158,871. The 95% paired percentile interval is
**-90,375,009.5 to 495,964,057** instructions. The interval includes zero, so
repeatable page credit is **0**. All 60 primaries and 60 actual PNGs
are retained. There are no startup retries, recovered counters or post-primary
installations. Each first interval retains one installation, two geometry
passes and one shell paint preparation. The cohort is not extended or filtered.

The observed saving crosses the 5,000,000-instruction broad gate. All six direct
V harness jobs pass: 31 CSS, 10 SVG and 46 layout cases in both GC modes, 174
executions. All 19 screenshots pass, 16 exact; the only differences remain
inline-node 13, text-decorations 1,341 and canvas-text 1,994. The focused wrapping,
ellipsis, nested-inline and Unicode viewport is pixel-exact. The selected
regression runtime and overlays remain pinned in the broad manifest; inherited
receipt wording about RAM output is inaccurate, as the commands use SSD scratch.

The isolated frozen comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt33.app`. Signature,
startup and actual GC collections pass with default marker 1 and override 2.
Its native text matches the measured image:
`1b1dcab38c4bc5d521c2b872af2ceef52c23477e84fb06cee8b453cf5062d4c4`.
The newer canonical app and user's GUI remain preserved. This app excludes
independent current Root work, including later container-query changes, and
receives no current-Root performance credit. Chrome parity remains open.

Evidence: `Build/instructions/vox-opt33-interleaved-*` and
`Build/v/instruction-opt33-*`. The completed broad batch resets the GitHub
baseline to 31,972,073,267 instructions; additional observed
savings after the batch are zero.

## Inherit directly after an empty custom-property cascade

Feature `35615f24` checks the matching author declarations and applicable
inline style before allocating temporary cascade maps. When none defines a
custom property and no animation overlay exists, the element receives its
parent's existing inheritable environment directly, or none. This also removes
stale own declarations. Registered non-inheriting properties use the same
existing parent filter. Animation overlays and declarations with values retain
the original cascade path; its source tail is byte-identical.

Thirteen functional cases plus an inactive diagnostic pass **1,310 assertions**
in the before/final Boehm and final no-GC C-O2 configurations. Three new cases
cover removed declarations, live inherited data, inline and pseudo-element
ownership, and animation values retained after base changes and collection.
Initial compiler errors are retained. A strict generated-C audit caught three
unrelated Root edits copied with the first source file. Their completed builds,
checks and candidate profile remain separately archived without matched credit.
The corrected frozen candidate contains only this feature; valid control checks
and its profile are retained, and only candidate checks were repeated against
the corrected runtime. A missing command file prevented one recovery wrapper
from launching tests; its traceback is retained.

Three fixed alternating diagnostic pairs reduce **8,192 complete custom-property
installations** from **28,728,578 to 4,323,927** retired
instructions (-84.95%). All three pairs improve, with checksum
8,192 in all six observations. DOM setup, eight warmups and forced collection
precede the counter; final data validation follows it. This is local evidence.
Fresh full-process C-O1/Boehm profiles include the same focused harness and active
diagnostic, with no filter/reset: installer calls remain
**8,219** in each variant;
ordinary cascade calls change from
**8,232 to 11**.
These are call counts, with no profile-time performance credit.

The generated-C audit permits only the installer and its new declaration
predicate to differ. All other logic, layouts, resources and GC setup match
after established compiler identity/source-assertion normalization and the two
authenticated byte-identical interface helper reorderings. All 120 native inputs,
37 frozen includes and native C-O2 arguments are authenticated. Compiled C SHA256:
`0f2d0b57616c545a2c067a4ea4a7094de8a4a888f8563f420c4d29b616271781`.
The durable C/profile archive hashes are in
`Build/v/instruction-opt35-artifact-archives.json`.

Thirty alternating pairs were predeclared, with 30,000 paired bootstrap resamples
and seed 35, the same 359-body cache and helper, fresh cache copies, 1024×768
document viewports and `navigation_to_first_document_paint[0]`. Both variants
include complete filenames and round 33 buffer release. Boehm uses one marker,
with no prod/prealloc flags.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 33 control | 32,043,531,858 |
| Empty custom-property inheritance | 31,126,229,194 |

Observed matching median saving: **917,302,664** instructions
(2.863%). 21/30 pairs improve; paired median
saving is 832,318,281.5. The 95% paired percentile interval is
**41,975,924 to 1,081,594,740**. Repeatable page credit is **917,302,664**, requiring a
strictly positive lower confidence bound. All 60 primary observations remain;
there are 60 actual PNGs, 0 recovered post-primary counters and
0 archived pre-parse startup retries. Completed primaries are never rerun,
filtered or extended. Capture preparation and later refreshes remain separately
audited in `Build/v/instruction-opt35-capture-audit.json`. Each primary retains
one installation, two geometry passes and one paint preparation. Control pair 21
has one separately retained later installation.

All six direct V jobs pass: CSS 31, SVG 10 and layout 46 in each GC mode,
174 case executions. All 19 screenshots pass, 16 exact; the retained differences
are inline-node 13, text-decorations 1,341 and canvas-text 1,994. The commands use
SSD scratch; inherited receipt wording about RAM output is inaccurate.
The focused inheritance, inline, pseudo and layered custom-property viewport is
pixel-exact. Broad runtime and overlays remain pinned separately from Root.

The isolated frozen comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt35.app`. Signature and
startup pass, with actual collections under default marker 1 and override 2.
Its native text matches the measured binary. Canonical and GUI apps remain
preserved. Contemporary independent Root changes are excluded from the measured
image; the current Root feature retains those changes. This app receives no
extra current-Root credit, and Chrome parity remains open.

Evidence: `Build/instructions/vox-opt35-interleaved-*` and
`Build/v/instruction-opt35-*`. The completed broad batch resets the GitHub
baseline to 31,126,229,194 instructions, with zero additional observed savings.

## Keep text context inside its inline iterator

Feature `3f660b04` stores the private inline text cursor in its owning
iterator, with an explicit presence flag. Entering another text node replaces
that cursor; exhaustion clears retained chunk references. Published items keep
their own node and glyph references. No global pool or shared mutable cursor is
introduced, and the public iterator and item APIs retain their behavior.

Twenty functional cases and an inactive diagnostic pass **23,230 assertions**
in before/final Boehm and final no-GC C-O2 builds. A new lifetime case retains
items for distinct ASCII, RTL, Greek and non-BMP sources through 64 later
iterations and forced collection. Existing wrapping, bidi, grapheme, ellipsis,
cyclic-maximum and published-fragment lifetime checks remain in the harness.

Three fixed alternating diagnostic pairs measure 512 complete inline formatting
runs on 16 text nodes. Medians are **2,626,998,976 to
2,626,474,454** retired instructions (-0.020%).
Two of three pairs improve; this small mixed local result establishes no
separate repeatable saving. All six checksums are 17,694,720. Setup, eight
warmups, expected output and forced collection precede the counter; final
validation follows it. Full-process C-O1/Boehm profiles, without filter/reset,
retain **776 private formatting calls and 8,869 text-context entries** in each
variant. Call counts receive no instruction credit.

The strict C audit authenticates one private optional pointer becoming an
embedded context and presence flag, removal of that optional wrapper, relocation
of the byte-identical context definition and exactly four edited function
bodies. Text entry no longer allocates a context owner. All other code, layouts,
resources and GC initialization match after established compiler identities,
exact unchanged-source assertion mapping and frozen include normalization.
Two byte-identical interface helpers and two integer comparator helpers may
reorder. All 120 native inputs, 37 frozen includes and native arguments remain
authenticated. Compiled C SHA256:
`ee014cc90ab9e420483ced18ac2e86986644928363d127219076adcf42487e41`.
Durable C/profile archives: `Build/v/instruction-opt37-artifact-archives.json`.

Thirty alternating pairs were fixed before observations, with 30,000 paired
bootstrap resamples and seed 37. Both regular binaries use the unchanged 359-body
cache, fresh copies, frozen helper, 1024×768 document viewport and
`navigation_to_first_document_paint[0]`. C-O2/Boehm uses one marker, without
prod/prealloc flags. The control includes round 35 custom-property inheritance.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 35 control | 31,132,876,172 |
| Iterator-owned text context | 30,970,670,843.5 |

Observed matching median saving: **162,205,328.5** instructions
(0.521%). 20/30 pairs improve, with paired
median saving 995,134,439.5. The 95% paired percentile interval
is **424,049,953 to 1,120,490,463**. Repeatable page credit is **162,205,328.5**, requiring
a strictly positive lower confidence bound. All 60 primary observations remain,
with 60 actual PNGs, 0 recovered post-primary counters and
0 archived pre-parse startup retries. Completed primaries are never
rerun, discarded or extended. First-frame preparation and later refreshes are
separately recorded in `Build/v/instruction-opt37-capture-audit.json`. Each
primary has one installation, two geometry passes and one paint preparation.
Candidate pair 24 has one separately retained later installation. The interval
resamples the median of paired savings; the observed point above is the
difference of the two marginal medians.

All six direct V jobs pass: CSS 31, SVG 10 and layout 46 in each GC mode,
174 case executions. All 19 screenshots pass, 16 exact; the retained differences
are inline-node 13, text-decorations 1,341 and canvas-text 1,994. The first
empty-caret actual capture exhausted its two startup attempts after a successful
reference capture. Its failure and blocked dependent receipts are retained;
only that unfinished actual capture and subsequent cases were resumed. The
reference, exact focused comparison and six successful test jobs were reused.
The focused multi-node, preserved tab/newline, bidi, wrapping and ellipsis
viewport is pixel-exact. Regression sources and overlays are pinned separately;
the commands use SSD scratch despite inherited RAM-output receipt wording.

The signed isolated comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt37.app`. Signature,
startup and actual GC collections pass with default marker 1 and override 2.
Native text matches the measured image. The canonical app and GUI are preserved;
independent current Root work is excluded from this frozen app and earns no
extra performance credit. Chrome parity remains open.

Evidence: `Build/instructions/vox-opt37-interleaved-*` and
`Build/v/instruction-opt37-*`. The completed broad batch resets the GitHub
baseline to 30,970,670,843.5 instructions, with zero additional observed savings.

## Fresh-reading audit for the experimental Chrome counter

Tooling `bdf12eb1` adds a conservative delta helper for retained process-counter
snapshots. It omits unavailable endpoint readings, waits for a fresh starting
reading after an unavailable baseline, and starts newly observed tasks at their
first actual counter rather than lifetime zero. Four focused unit cases pass,
including task birth/exit, stale readings, later samples, root identity and
counter monotonicity. This helper is independent of the unchanged Vox observer.

The second isolated headless Chrome probe records **2,044,596,124** retired
instructions across 12 included tasks and omits two tasks whose endpoint reads
are unavailable. All 48 retained sampling passes, baseline/endpoint readings,
missing-read sets and clock brackets are archived; the delta is independently
recomputed from that evidence. Observer and browser exits are both zero.
The original probe remains preserved, but its missing-read availability was
not archived, so its asserted lower-bound status is not authenticated.

This is an uncredited diagnostic. Sampling starts after the navigation response
and ends conservatively before `paintTime`; tracing is disabled. The
[2 October 2026 Paint Timing working draft](https://www.w3.org/TR/2026/WD-paint-timing-20261002/)
distinguishes the rendering-update endpoint from later presentation. This probe
still differs from Vox's native submitted-document-frame endpoint. Legacy cache
headers are inferred: status 200, MIME by URL/type, wildcard CORS and no-store;
missing/non-GET requests fail instead of reaching the live network. This body
replay policy is disclosed and does not establish equivalent HTTP semantics or
rendered content. No Chrome parity, speed ratio or page saving is claimed.

Evidence: `Build/instructions/chrome-frozen-probe/counter-diagnostic-2/`,
`Build/v/instruction-chrome-counter-v{1,2}-audit.json`. The binary SHA256 remains
`c41c446837b5888d9574dbe462a4f01f02459bffee534eb945d2418984135a92`.

## Native instruction scopes for the next layout investigation

A separate C-O2 diagnostic wraps six selected functions with the existing
process-wide retired-instruction counter. Wrappers observe entries on the
navigation's owner thread, from its first navigation entry through the first
native document-frame report. Counter reads still include charged work in
other process threads. This is an instrumented diagnostic with zero page credit.

| Function scope | Calls | Summed inclusive retired instructions |
| --- | ---: | ---: |
| `layout__run_flex_formatting_context_with_mode` | 9,144 | 83,632,570,216 |
| `layout__InlineLevelIterator_generate_all_items` | 44,580 | 3,084,922,839 |
| `css__StyleComputer_compute_properties` | 2,910 | 1,514,022,678 |
| `layout__populate_intrinsic_containing_block_chain` | 7,852 | 1,147,287,040 |
| `layout__populate_intrinsic_external_containing_blocks` | 7,852 | 273,429,200 |
| `css__install_custom_property_data_for_style` | 7,990 | 202,504,063 |

Nested flex calls and the other scopes overlap; these totals cannot be added
or interpreted as exclusive self cost. They include wrapper/counter overhead
and compiler effects from instrumentation. They guide the next investigation,
while normal uninstrumented paired binaries remain required for page credit.

The instrumentation audit restores every edited function definition and removes
only its wrappers/globals to reproduce the original round 37 C byte-for-byte.
Native arguments and 120 existing inputs are retained, with the frozen helper.
An initial misspelled C equality symbol failed compilation and is archived;
the corrected build, signing, startup, observer and browser exits are zero.
All six scope readings report zero counter failures, with a complete capture.
Binary SHA256:
`0668710d35dafac4b87e6c83e8da90ac0d52b7ceeecd7c1196bea573d431c1ac`.
Evidence: `Build/v/instruction-hotspots38-*` and
`Build/instructions/vox-hotspots38-diagnostic.run-1.*`.

## Defer copying rare geometry snapshots without grid storage

Feature `5f212342` shares a populated ancestor's private rare geometry
record when all four grid arrays have zero capacity. Both source and snapshot
are marked shared; either owner clones the existing record before changing a
rare field. This preserves snapshots when the committed source changes first.
Records with nonempty or reserved grid storage retain the original eager copy,
so public array borrows made before population remain independent. Ordinary
geometry, line-box copies, grid getters and all rare-data setters retain their
existing behavior. No global pool or reference-count lifecycle is introduced.

Eighteen functional cases plus an inactive diagnostic pass **17,785 assertions**
in before/final Boehm and final no-GC C-O2 builds. Three new cases cover source
and multiple snapshot mutations through collection, existing nonempty grid
borrows, and empty arrays with reserved writable capacity. Existing arena,
complete-default, copied-geometry and paged-store cases remain selected.

Three fixed alternating pairs reduce **8,192 complete intrinsic width/height
probes** from **1,621,168,300 to 1,293,526,023** retired
instructions (-20.21%). All three pairs improve. Setup gives
the nested containing-block chain retained rare baseline data. DOM/layout setup,
eight warmups, expected results and forced collection precede the counter;
checksum validation follows it. All six checksums are 180,379,648. This local
result receives no separate page credit. Full-process C-O1/Boehm profiles have
no filter/reset: population calls remain **123,187** in both variants, while
rare-record clones change from **123,157 to 7**. These are diagnostic call counts.

The strict C audit authenticates one private UsedValues flag and exactly four
zero defaults inside balanced UsedValues literals, two modified functions and
one predicate that checks all four grid capacities. All other logic, layouts,
resources and GC setup match after established compiler identities, exact source
assertion-line mapping and frozen include normalization. Four raw-identical
interface/comparator helpers may reorder. All 120 native inputs, 37 quoted
includes and native C-O2 arguments remain authenticated. Compiled C SHA256:
`96c5b67c7bd43ce959fe97fda1d2ec6ca129c238b7787f5a7010881b20071f97`.
Durable archives: `Build/v/instruction-opt38-artifact-archives.json`.

Thirty alternating pairs were fixed before observations, with 30,000 paired
bootstrap resamples and seed 38. Both regular binaries retain the 359-body cache,
fresh per-run copies, frozen helper, 1024×768 viewport and
`navigation_to_first_document_paint[0]`. Normal C-O2/Boehm uses one marker,
without prod/prealloc flags. The control is the frozen round 37 final runtime.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 37 control | 31,075,999,429.5 |
| Deferred rare geometry copies | 31,062,009,877 |

Observed matching median saving: **13,989,552.5** instructions
(0.045%). 11/30 pairs improve; paired median
saving is -127,860,906. The 95% paired percentile interval is
**-545,839,225 to 34,650,863**. Repeatable page credit is **0**, requiring a
strictly positive lower confidence bound. The interval resamples paired median
savings; the point above is the difference of the marginal medians. All 60
primaries remain, with 60 actual PNGs, 0 recovered post-primary
counters and 0 archived pre-parse startup retries. Completed primaries
are never rerun, discarded or extended. Preparation and later refreshes remain
separately audited in `Build/v/instruction-opt38-capture-audit.json`. Each primary has
one installation, two geometry passes and one paint preparation; there are no
later installations.

All six direct V jobs pass: CSS 31, SVG 10 and layout 46 in each GC mode,
174 case executions. All 19 screenshots pass, 16 exact; the retained differences
are inline-node 13, text-decorations 1,341 and canvas-text 1,994.
The focused nested-flex, grid-buffer, table and baseline viewport is pixel-exact.
Regression runtime and overlays are pinned separately from Root. Commands use
SSD scratch despite inherited RAM-output wording in some receipts.

The signed isolated comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt38.app`. Signature,
startup and actual collections pass with default marker 1 and override 2. Native
text matches the measured image. Canonical and GUI apps are preserved; unrelated
current Root work is excluded from this app and earns no additional performance
credit. Chrome parity remains open.

Evidence: `Build/instructions/vox-opt38-interleaved-*` and
`Build/v/instruction-opt38-*`. The completed broad batch resets the GitHub
baseline to 31,062,009,877 instructions, with zero additional observed savings.

## Reuse unchanged column-flex geometry during intrinsic sizing

Feature `e4f2da02` applies the existing guarded column-flex geometry reuse
to intrinsic sizing too. The natural child layout still runs first, in normal
mode. When the final height and forced width match, and no descendant consumes
a newly definite height, its geometry can be retained instead of laying out
the same subtree again. Changed flex targets and percentage-dependent descendants
still rerun. Inline-flex baselines are retained before intrinsic line boxes
are discarded. This removes one mode restriction from the existing guard;
the remaining sizing, dependency and baseline behavior is unchanged.

Fourteen functional cases and an inactive diagnostic pass **18,854 assertions**
per configuration in before/final Boehm and final no-GC C-O2 builds. Three new
cases cover retained first-pass baselines with centered intrinsic content,
percentage descendants after height promotion, and changed shrink targets.
The initial harness's immutable-state access failed compilation before any
test ran. Those logs remain in `instruction-opt39-initial-harness-failure`;
only the harness accessor was corrected before the successful checks.

Three fixed alternating diagnostic pairs run **2,048 complete intrinsic
max-content height probes** through ten nested column-flex containers.
Medians change from **1,346,808,160 to 776,540,639**
retired instructions (-42.34%). All three pairs improve;
all six checksums are 10,485,760. Setup, eight warmups, expected results and
forced collection precede the counter, with checksum assertions afterward.
This is a local result without separate page credit. Full-process C-O1/Boehm
profiles have no filter or counter reset: column-flex calls change from
**43,423 to 22,763**, and child-layout calls from **45,542 to 22,803**.
Profile call counts support the mechanism; they are not hardware instructions.

The strict generated-C audit permits only
`layout__run_column_flex_formatting_context` to change. All other generated
logic, layouts, resources and collector setup match after established compiler
identity, exact assertion-line and frozen-include normalization. Four helpers
may reorder only when their raw bodies are identical. All 120 native inputs,
37 quoted includes and native C-O2 arguments remain authenticated. Compiled C
SHA256: `ed777ac45fa1f835fc2247860ca78ae35d31f868f35cb9fa500c6c289b2c7397`.
Durable generated-C and profile archives are hashed in
`Build/v/instruction-opt39-artifact-archives.json`.

The predeclared cohort contains 30 alternating pairs and 30,000 paired bootstrap
resamples, seed 39. Both regular binaries use the same 359-body cache with
fresh copies, frozen helper, 1024×768 viewport and
`navigation_to_first_document_paint[0]`. Normal C-O2/Boehm retains one marker,
without prod/prealloc. The control is the frozen round 38 final runtime.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 38 control | 31,058,303,623.5 |
| Intrinsic column geometry reuse | 30,989,389,977.5 |

Observed matching median saving is **68,913,646** instructions
(+0.222%). 18/30 pairs improve. The paired
median saving is 46,124,713.5; its 95% paired percentile
interval is **-163,544,061.5 to 1,050,264,518**. Repeatable page credit is **0**,
requiring a strictly positive lower confidence bound. The interval estimates the
paired median; the point saving above is the difference of marginal medians.

All 60 primary observations remain, with 60 actual PNGs, 0
recovered post-primary counters and 0 archived pre-parse startup retries.
No completed primary is rerun, discarded or extended. The first attempt stopped
at fresh-cache directory creation before launching a browser; its failed
pipeline receipts remain in `instruction-opt39-prelaunch-directory-failure`.
Creating the declared scratch parent allowed the unexecuted cohort to start.
Every primary has one installation, two geometry preparations and one paint;
there are 0 separately retained post-primary
refreshes. Capture evidence is `instruction-opt39-capture-audit.json`.

A concurrent observer change extracts its default launch list into a helper
that accepts optional explicit arguments. This cohort passes none. Five Vox
routines remain AST-identical to the starting observer; `run_vox` is identical
after unfolding that exact default helper. All 60 recorded launch arrays are
verified separately. The fixed native endpoint and binaries are unchanged.

All six direct V harness jobs exit zero: CSS 31, SVG 10 and layout 46 in both GC modes, totaling 174 case executions. All 19 screenshot comparisons pass, 16 exact; known differences remain inline-node 13, text-decorations 1,341 and canvas-text 1,994.
The focused intrinsic-column, baseline, percentage and shrink viewport is
pixel-exact. The selected broad runtime and this feature's overlay are pinned
separately from contemporary Root and use SSD scratch.
The first broad screenshot command stopped before capture because its copied
helper lacked executable permission. That failed receipt and its blocked
dependents remain in `instruction-opt39-validation-launch-permission-failure`.
After restoring permission, only unfinished screenshot work resumed; the exact
focused comparison and all six successful regression jobs were retained.

The signed isolated comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt39.app`. Signature,
startup, matching native text and actual collections pass with default marker
1 and override 2. Canonical and GUI apps are preserved. Independent Root work
is excluded from the frozen app and receives no performance or regression
credit from this cohort. Chrome parity remains unestablished.

Evidence: `Build/instructions/vox-opt39-interleaved-*` and
`Build/v/instruction-opt39-*`.

## Hardware instructions at collector event boundaries

A separate diagnostic based on the frozen round 39 normal C installs Boehm's
collection-event callback without changing collector settings. Under the
allocator lock it records process-wide hardware instruction reads at each
collection event. Its analysis window starts at navigation entry and ends at
the existing native first-document-frame counter. Completed event intervals
are clipped to that window; the retained log reconstructs every interval.

The single diagnostic records **23 full collections**, with
**14,822,083,472 instructions** inside their start/end
boundaries, out of **32,108,421,151** in its navigation
window (46.16%). Stop-world boundaries contain
14,454,081,404 instructions. These scope types overlap and must
not be summed. They include hook/counter overhead and any other process-thread
work charged during the intervals, so they are not collector self-instruction
counts. They identify temporary allocation as a useful next target; this is no
normal-page improvement, paired cohort, or Chrome parity result.

Native compilation, signing, startup, observer and browser all exit zero. No
counter failures or unmatched collection boundaries occur. The instrumentation
restores byte-for-byte to the normal round 39 C after removing exactly two
wrappers, callback setup and diagnostic storage. Its durable C archive, binary,
raw log, real exits, frozen-cache/helper identity and interval reconstruction
are authenticated in `Build/v/instruction-gc40-final-audit.json` and
`Build/v/instruction-gc40-instrumentation-audit.json`. Performance credit is zero.

## Current allocation requests and sampled native stacks

A second frozen round 39 diagnostic intercepts generated-C `GC_MALLOC`,
`GC_MALLOC_ATOMIC` and `GC_REALLOC` requests on the navigation owner thread,
from navigation entry through the first native frame report. It records
**14,322,522 requests for 2,545,818,467 bytes**. Requested
bytes include reallocations that may grow in place; they are not live memory,
all process allocations, or retired instructions. Native libraries and other
threads are outside request interception.

A mixed allocation sequence selects approximately one in 8,192 requests for a
native stack, retaining **1,748 raw samples** without
extrapolation or dropped samples. The largest sampled application allocation
site by requested bytes is glyph-array growth while merging text runs. Other
sampled sites include initial property arrays, selectors, measurement records
and inline item storage. Samples guide the next experiment and provide no
performance credit. Native stacks reflect C-O2 inlining and tail calls; symbols
are resolved against the retained native symbol table and actual image base.

Native build, signing, startup, observer and browser exit zero. Removing only
the request macros, diagnostic storage and two wrappers restores the original
normal C byte-for-byte. All 120 native inputs and the frozen cache/helper remain
authenticated. Two earlier preparation failures are retained: a misplaced
header caused native frontend errors, and an overly specific include assertion
stopped before compilation. Neither launched a measured browser. The initial
failed native command's exact terminal code was not retained and is unknown;
no pass credit is assigned to it. Evidence and archive hashes are in
`Build/v/instruction-alloc40-final-audit.json`,
`Build/v/instruction-alloc40-instrumentation-audit.json` and the retained raw log.

## Rejected glyph-capacity preparation prototype

Round 40 tested a helper that detaches shared glyph storage directly into
append-sized capacity and reserves ordinary append capacity ahead of the loop.
Eleven functional cases plus an inactive diagnostic pass 956 assertions in
before/final Boehm and final no-GC C-O2 builds. Three new cases retain cached
runs and other forks across long LTR/RTL appends, end padding and collection.

Three fixed alternating local pairs run 512 complete normal inline formatting
contexts on sixteen text nodes. Median retired instructions change from
**1,831,739,039 to 1,832,703,846 (+0.0527%)**; all three pairs are worse, and
all six checksums are 17,694,720. This normal fixture never populates the
intrinsic shape cache, so it does not exercise the helper's shared-storage
branch. It nevertheless rejects the added normal-path overhead. The cohort is
retained without extension, replacement or performance credit.

The prototype remains frozen under `Build/opt40-final-source`; neither runtime
file was promoted to Root. No normal candidate, page primary, broad suite or
app was produced. The three new correctness cases are archived and retained
for the subsequent bulk-append experiment. The verified broad baseline stays
at round 39. Evidence: `Build/v/instruction-opt40-rejected-result.json` and the
focused/local receipts.

## Append shaped glyph vectors in one operation

Feature `90ddf27a` copies each incoming glyph vector through the existing
array append operation, then applies the existing positional shifts to its new
range. Both LTR and RTL fragments retain their insertion direction, prior-run
shifts, end-padding rule and inline length. Existing replay invalidation and
copy-on-write storage ownership remain unchanged. Only the two private glyph
append functions change; the rejected round 40 capacity helper is excluded.

The unchanged 12-case common harness (11 functional plus an inactive diagnostic)
passes **956 assertions** in before/final Boehm and final no-GC C-O2 builds.
The before success is retained from round 40: runtime manifest, common source,
compiler flags, executed command, log and copied binary are authenticated.
Three new cases cover long LTR/RTL appends, other cached forks, end padding,
empty input and retained replay across collection. An additional candidate-only
self-append regression passes **63 assertions** in each GC mode, for **1,019
candidate assertions per configuration** across 13 harness cases.

The control self-append attempt did not complete; its original controller and
test were absent at a fresh process check, and its terminal status is unknown.
It receives no pass credit and is never rerun. The old generated loop tests
the source length while extending the same object's glyph vector, so the bound
keeps growing. The new vector operation takes the source header by value and
completes a bounded append. Both candidate self-append logs and the incomplete
control log remain retained. The single-case V output omits a bracketed case
index; a derived parser authenticates its passing function and 63-assertion
summary without rerunning the successful candidate checks.

Three fixed alternating local pairs run **512 complete normal inline formatting
contexts** on sixteen text nodes. Median retired instructions change from
**1,828,044,863 to 1,804,313,258**
(-1.30%). All three pairs improve, and all six checksums are
17,694,720. Setup, eight warmups, the expected result and forced collection
precede the counter; checksum assertions follow it. This is local evidence
without separate page credit. Full-process C-O1/Boehm profiles of the common
harness and diagnostic have no filter/reset: LTR append calls remain **133,908**
and RTL calls **4** in both variants. Profile call counts are not hardware
instruction measurements.

The strict C audit confines changes to the LTR/RTL append bodies, each using
two existing `_PUSH_MANY_noscan` sites and the unchanged replay invalidation.
All other logic, layouts, resources and GC setup match after established
compiler identities, exact assertion-line mapping and frozen include paths.
Four helpers may reorder only with identical raw bodies. All 120 native inputs,
37 quoted includes and native C-O2 arguments remain authenticated. The first
audit expected the expanded helper spelling instead of its existing macro;
that failed assertion is preserved, and the corrected audit authenticates the
exact macro sites without widening the allowed function scope. Compiled C
SHA256: `a505540d9a635428f6cb8f01d169cb205b617bef53e1e3fa5f9963bed77612a1`.
Durable C/profile archive hashes are in `instruction-opt41-artifact-archives.json`.

The predeclared cohort fixes 30 alternating pairs and 30,000 paired bootstrap
resamples, seed 41. Regular frozen round 39 and candidate binaries use the same
359-body cache with fresh copies, helper, 1024×768 viewport and
`navigation_to_first_document_paint[0]`. Normal C-O2/Boehm retains one marker,
without prod/prealloc. Before the cohort began, interrupted pending controllers
were absent with unknown terminal statuses; only the unstarted page pipeline
was resumed. Every successful prerequisite remains retained.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 39 control | 30,101,652,130.5 |
| Bulk glyph append | 30,884,123,038.5 |

The candidate marginal median is **782,470,908 instructions higher (+2.599%)**;
observed matching savings are negative. 16/30 pairs improve. Paired
median saving is 22,380,349, with a 95% paired percentile
interval of **-799,503,938 to 107,688,401.5**. Repeatable page credit is **0**,
requiring a strictly positive lower confidence bound. The interval estimates
the paired median; the point saving above is the difference of marginal medians.
All 60 primaries remain, with 60 actual PNGs, 0 recovered
post-primary counters and 0 archived pre-parse startup retries. No
completed primary is rerun, discarded or extended. Each primary has one
installation, two geometry preparations and one paint; 0
post-primary refreshes are retained separately. Native scopes, raw logs and all
recorded launch arrays are authenticated; default observer command extraction
is equivalent to the starting Vox command.

The observed matching median saving stays below the 5,000,000-instruction gate, so broad suites and the 19-case screenshot batch remain deferred.
The focused LTR/RTL, wrapping, Unicode and tab viewport is pixel-exact. Selected
regression runtime and overlays are pinned separately from current Root, using
SSD scratch. The isolated signed comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt41.app`.
Signature, startup, matching native text and actual collections pass with
default marker 1 and override 2. Canonical and GUI apps are preserved. Independent
Root changes receive no performance or regression credit from this cohort.
Chrome parity remains unestablished.

Evidence: `Build/instructions/vox-opt41-interleaved-*` and
`Build/v/instruction-opt41-*`.

## Accumulate pending `:has()` mutation features in place

Feature `32b44c5f` sends subsequent mutation-feature collection directly
into the record already queued for a node. The unchanged element and subtree
collectors retain the same tags, IDs, classes, attributes and namespace case
variants. Sibling and pseudo-class flags accumulate monotonically; existing
conservative and property features remain. First-record allocation, queue order,
document scheduling, clearing and every other recording path are unchanged.
Public mutable maps keep independent ownership.

The common harness passes **573 assertions across 15 cases** (14 functional
plus an inactive diagnostic) in before/final Boehm and final no-GC C-O2 builds.
Four new cases compare repeated collection with the unchanged collect-and-merge
oracle, check independent namespace expectations, queue ordering, retained
records across clearing and collection, conservative/property features, and
real DOM insertions of two distinct selector classes. The first candidate
binding failed V's mutable-alias check before tests; its logs, receipts and
immutable source remain preserved. Only that binding was corrected; the
successful control harness was retained and never rerun.

Three fixed alternating local pairs execute **8,192 complete already-queued
node mutation-feature recordings**. Median retired instructions fall from
**89,936,691 to 22,104,065**
(-75.42%), with all three pairs improving and checksum 8 in
all six observations. Setup, eight warmups, expected result and forced collection
precede the counter; assertions follow it. This is local evidence with no
separate page credit. Full-process C-O1/Boehm profiles run the entire common
harness plus the active probe, without filters or resets. Recording calls remain
**8,210** in each variant; feature constructors fall
**8,226 to 22**,
temporary collectors **8,214 to 10**,
and merges **8,208 to 4**.
Call counts are separate from hardware instruction measurements. An initial
extraction used the wrong static-constructor symbol; both successful profiles
were retained and their existing evidence re-extracted without rerunning them.

The strict generated-C audit permits only
`css__StyleScope_record_pending_has_invalidation_mutation_features` to change.
All other executable logic, layouts, collectors, merge helpers, resources and
GC setup match after established compiler identities, assertion-line mapping
and frozen include paths. Four helpers may reorder only with identical raw
bodies. All 120 native inputs, 37 quoted includes and native C-O2 arguments
remain authenticated. Compiled C SHA256:
`8004ae04295595413cd9135d7671cdf95e8e9aee9d0fe551e3edbec6b3530270`.
Durable focused, normal and profile C archive hashes are in
`instruction-opt42-artifact-archives.json`.

The predeclared cohort contains 30 alternating pairs, 30,000 paired bootstrap
resamples and seed 42. Regular frozen round 41 and candidate binaries use the
same 359-body cache, fresh copies, helper, 1024×768 document viewport and
`navigation_to_first_document_paint[0]`. Native C-O2/Boehm keeps one marker,
without prod/prealloc.

| Build | Median first-frame retired instructions |
| --- | ---: |
| Frozen round 41 control | 30,948,611,900 |
| In-place pending feature accumulation | 30,974,728,492.5 |

Observed matching median saving: **-26,116,592.5** instructions
(-0.084%). 16/30 pairs improve. Paired
median saving is 13,707,404.5, with a 95% paired percentile
interval of **-70,388,590.5 to 51,858,644.5**. Repeatable page credit is **0**,
requiring a strictly positive lower confidence bound. The interval estimates
the paired median; the point saving above is the difference of marginal medians.
All 60 primaries remain, with 60 actual PNGs, 0 recovered
post-primary counters and 0 archived pre-parse startup retries. No
completed primary is rerun, discarded or extended. Each primary has one
installation, two geometry preparations and one paint; 0
post-primary refreshes are retained separately. The unchanged observer hash
retains its authenticated default Vox launch behavior; all actual launch arrays
are checked separately.

The observed matching median saving stays below the 5,000,000-instruction gate, so broad suites and the 19-case screenshot batch remain deferred.
The focused live `:has()` insertion viewport is pixel-exact. Selected regression
runtime includes the prior bulk-glyph change and this feature, pinned separately
from current Root. The isolated signed comparison app is `/Users/alex/code/vox2/Build/v/Vox-opt42.app`.
Signature, startup, matching native text and actual collections pass with
default marker 1 and override 2. Canonical and GUI apps are preserved. Independent
Root changes receive no performance or regression credit from this cohort.
Chrome parity remains unestablished.

Evidence: `Build/instructions/vox-opt42-interleaved-*` and
`Build/v/instruction-opt42-*`.

## Causes and changes

- The V 0.5.2 compatibility compiler's `-prod` Boehm code repeatedly snapshots
  nested pointers in live aggregates. Tokenization walks the growing token
  array around calls, turning large stylesheet parsing into quadratic work.
  The browser builder uses C `-O2` without `-prod`. The initial fix used
  `boehm_full`; optimized retention checks subsequently allowed pointer-aware
  `boehm`, which leaves pointer-free buffers atomic.
- Block layout measured automatic-height flex subtrees before running their
  actual flex layout. Ordinary horizontal flex containers now resolve their
  own height during that run. Buttons, vertical writing modes, and percentage
  row gaps retain their required preliminary measurement.
- Intrinsic and minimum-height probes allocated individual geometry records
  that survived until collection. These scalar-returning probes now allocate
  `UsedValues` in stable arena chunks and release their owned records and page
  containers when the probe ends. Shared line boxes and rare data keep their
  existing heap ownership; committed layout does not use this temporary arena.
- Recomputed unchanged styles rebuilt font cascades containing pending faces.
  Upstream's pending-cascade equality intentionally returns false, so each
  recomputation invalidated layout. Vox now preserves cascade identity when
  all font inputs, the owning font computer, and its environment generation
  match. Font loading and changes to font properties still invalidate it.
- Document script execution parsed entire ECMAScript modules before rejecting
  their unsupported execution. Execution now checks that capability before
  parsing. The explicit `prepare_script()` API still parses module ASTs and
  reports syntax errors.
- Native navigation constructs an active document without session-history
  traversal. It now grants script readiness before parsing, allowing GitHub's
  import map to run without the script-readiness assertion.
- Column flex layout now retains its first inside-layout when flexing leaves
  both dimensions unchanged and no descendant consumes the new definite-height
  basis. Grids with only implicit automatic rows can use the same optimization;
  explicit, percentage, flexible, and subgrid rows retain the relayout guard.
- Immutable platform font handles retain their resolved file and decoded face.
  Glyph coverage and bounds no longer repeat file checks and global cache-key
  construction for every character. An unavailable explicit source continues
  to be retried instead of permanently selecting its temporary fallback.
- CSS component text serialization now uses linear builders. Unescaped
  identifier tokens use a contiguous filtered-input slice without a builder;
  the compatibility compiler copies that slice. Escaped names still use the
  decoder and builder. Optimized forced-GC tests cover a late
  identifier retained after the tokenizer and other tokens have gone away.
- The compact script bridge reads `innerHTML` and `textContent` lazily from
  captured native element identities. Initial state and unchanged snapshots
  no longer serialize every ancestor's complete subtree. Pending script writes
  and CSSOM rule mutations preserve their existing replay behavior.

## Historical wall-clock observations

The native timing log separates processing phases from network fetches and
the screenshot settle delay.

| Phase | Earlier run | Updated run |
| --- | ---: | ---: |
| External stylesheet installation | 78.2 s | 2.0 s |
| Document script startup | 8.2 s | 2.0 s |
| Geometry per initial stabilization pass | about 6–7 s | about 3–4 s |

The updated cached-document install took 14.5 seconds. A subsequent network
refresh returned different HTML and caused another document install lasting
20.6 seconds; the screenshot process exited after 40.7 seconds including both
installs and capture. These values must not be described as a single first
paint time. The repeated geometry passes triggered by unchanged pending-font
styles no longer occur after installation.

GitHub's file rows still show loading placeholders because this browser
JavaScript backend does not implement module execution/linking. Avoiding their
unnecessary parsing does not add module support or full LibJS parity. Equal
rendering speed and functionality with upstream Ladybird have not been
established.

### Chrome comparison and continued optimization

A subsequent native run at a 1024×768 document viewport reduced cached-document
installation from 16.2 seconds to 5.1 seconds after the column-flex, font-handle,
linear serialization, and lazy-content changes. Its script startup took 138 ms
instead of 2209 ms, and its two geometry passes took 1047 ms and 790 ms instead
of 4509 ms and 4083 ms. The process used a peak RSS of about 1.5 GiB.

The final build also includes the grid dependency refinement and identifier
source spans. Its two subsequent document-install measurements were 7.9 and
8.8 seconds. At that point the host load average was about 100 with many
unrelated compiler processes running. The differing phase timings do not
establish a regression or an additional speedup; repeat them on an idle host
before drawing either conclusion.

An isolated, clean-profile Chrome 155.0.8059.40 process loading the live URL
reported first contentful paint at 1516 ms, DOMContentLoaded at 1827 ms, and load
at 2722 ms through the Chrome DevTools Protocol. Its screenshot showed populated
file rows and 72 file/directory links. The Chrome measurement includes a cold
network navigation; the Vox measurements use cached HTML/resources and native
window capture. They are different workloads, and Vox has not reached Chrome
load-speed or functionality parity.

## Allocation policy

Upstream Ladybird uses its tracing `LibGC` collector for DOM and JavaScript
objects alongside reference counting and layout arenas. Vox retains Boehm GC
for live and shared V object graphs. Its scoped measurement arena is an
ownership optimization, not a switch to a globally uncollected heap.
`LADYBIRD_V_GC=boehm_full` retains the fully scanned diagnostic mode, and
`LADYBIRD_V_GC=none` remains available for ownership diagnostics.

The compatibility compiler forces GC off when `-prealloc` is used, including
when an explicit `-gc` argument is present. Its thread-local and scoped bump
arenas cannot be enabled for selected packages through that flag. The native
browser therefore uses scoped ownership where the lifetime is proven: CSS
tokenizer code points and byte offsets now share one pointer-free allocation
freed after tokenization, while intrinsic geometry retains its chunk arena.
The tokenizer retention and arena tests also pass with `-prealloc`. Enabling
that flag globally still requires ownership for document graphs, shared caches,
and updates that outlive a particular frame.

## V profiling and allocation follow-up

The investigation used V's `-profile`, with inline functions excluded, around
native layout entry points. The diagnostic recorded three layout calls before
an ongoing background refresh was interrupted; its totals are not one isolated
navigation. It recorded about 38.8 million `_v_malloc` calls, 14.7 million
computed-property reads, 1.28 million length-context constructions, and
6.4 million layout ancestry checks. Instrumentation and V's non-thread-safe
profiler make these diagnostic counts more useful than their absolute timings.

A separate sampled GC allocation wrapper confirmed the generated-C causes:
optional map misses constructed error objects; selector matching allocated an
attribute-name array and a captured metadata closure; DOM value equality copied
whole heap node records; and default length wrappers constructed unused
`CalculatedStyleValue` objects, maps, and arrays. Even absent optional values
could retain those unused objects in their payloads.

The follow-up changes are:

- Guard missing animated-property and pseudo-element entries before lookup.
- Use pointer identity in selector matching and a borrowed metadata helper;
  compare case-insensitive attribute names without rebuilding a list.
- Use zero-length defaults, explicit absent optionals, and direct conversion
  returns instead of building discarded calculation objects.
- Retain font length metrics on the owning style, borrow that style through
  layout aliases, and reuse native font handles on retained layout nodes.
- Visit shared external containing-block chains once per intrinsic probe.
- Retain the installed document selector-query state. Repeated font/style
  lookups previously rebuilt it and cleared its parsed-selector cache.
- Resolve absolute and percentage layout lengths before creating a font or
  container-query context; relative and calculated lengths retain that context.

Before the selector/default/font-handle changes, the allocation wrapper counted
81.3 million managed allocation calls requesting 8.1 GB through native capture.
After those changes it counted 50.4 million calls requesting 5.5 GB. These are
cumulative requested bytes, not live memory or RSS, and exclude JavaScriptCore
and other native allocations. These two runs installed the cached document in
5.1 and 5.9 seconds with different host contention, so the allocation reduction
does not establish a corresponding timing ratio. The later query-hook and
context-free length changes are additional to those allocation measurements.

The final signed production build, with profiling disabled and all follow-up
changes included, installed the cached GitHub document in 5413 ms and 5549 ms.
An adjacent run of the saved earlier binary took 8086 ms. The final two geometry
passes took 855/794 ms and 903/747 ms, versus 1403/1373 ms in that earlier run.
The final peak RSS was about 1.4 GiB. The full screenshot processes took 6.8 and
7.3 seconds, including startup and capture; these must not be called FCP.
The normal collector log accounted for about 5.5 GB between 59 collections,
versus about 9.0 GB between 79 collections in the initial allocation diagnostic.
Those interval totals include padding and omit the final allocation interval.

Host load ranged from roughly 30 to 90 during final compilation and measurement.
These individual runs show a remaining gap to the earlier 1.5-second Chrome FCP
measurement; they do not establish Chrome parity. GitHub module execution and
its hydrated file rows remain unsupported by the compact browser backend.

## Retained parser input and SVG geometry follow-up

The next allocation-stack diagnostic found repeated copies of parser input,
three parses of each validated selector, full native-element registry snapshots
for individual bindings, and complete computed-style materialization while
building SVG models. It also found document-root checks invoking value equality,
which copied two 640-byte DOM node records for each unsuccessful check.

The follow-up retains immutable component/token spans across parser transactions,
supplies EOF without appending a sentinel, and validates a single selector graph.
CSS keyword comparisons fold only ASCII bytes without allocating lowercase
strings. Containing-block recomputation indexes inline nodes once, preserving
continuation order and ignoring stale DOM handles from an earlier layout tree.
Native bindings resolve one registry key while preserving provider precedence
and live replacements. SVG models read their filter properties directly, and
path boxes retain immutable parsed geometry keyed by the applied CSS `d` value.
Document-root checks now compare pointer identity.

The allocation wrapper counted 47,305,300 managed allocation calls requesting
4,527,048,497 bytes before the registry/selector/SVG changes and 35,244,219 calls
requesting 4,073,835,695 bytes afterward: about 25.5% fewer calls and 10.0% fewer
requested bytes. These process totals include capture-related frames and exclude
native/JSC allocation. The latter measurement precedes the document-root change.
Their instrumented document-install times were 4819 ms and 2942 ms; host load
changed between runs, so those times do not establish a controlled speedup ratio.

The final signed, uninstrumented GC build installed the cached document in
4550 ms and 4148 ms. Installation through first native frame submission took
4930 ms and 4341 ms; navigation through that submission took 5290 ms and 4574 ms.
Peak RSS was 1286.5 MB and 1349.3 MB. The timing output now reports these complete
intervals, and `first_paint_total` includes the complete frame rather than just
the final segment after document replay. Native submission is not web FCP.

A fresh isolated Chrome 155.0.8059.80 run reported FCP at 2436 ms, DOMContentLoaded
at 1331 ms, and load at 1468 ms. Its screenshot showed populated rows and 72
file/directory links. Vox's cached screenshot still shows loading placeholders;
its module backend remains incomplete. The inputs also differ between cached
Vox HTML/resources and Chrome's cold network navigation. Chrome speed and
functionality parity have not been achieved.

GC remains enabled. A lower heap-divisor probe timed out before startup timing
was emitted and provides no valid navigation measurement; it did not change
the default collector policy. Compiler scratch files were moved to a scratch
volume after disk exhaustion interrupted builds. Those interrupted compilations
are not test-body failures. Retried parser and SVG suites passed, including
forced collection, and borrowed parser input also passed with `-prealloc`.
The final native startup/signature checks and six screenshot comparisons pass;
ordered lists, SVG image replacement, and both turbulence cases are pixel-exact.

## Validation and reproduction

Focused tests cover forced-GC token retention, arena pointer stability and
release with both `boehm_full` and `none`, flex sizing, pending-font cache
invalidation, import-map navigation, and module rejection followed by classic
script execution. The signed native bundle passes `--headless-smoke`.
The continued optimization tests also cover stylesheet-graph retention with
optimized pointer-aware GC, UTF-8 arena offsets, live font/context changes,
selector case sensitivity and metadata, animation/transition precedence,
pseudo-element identity, retained query hooks, and context-free layout lengths.
They also cover column/grid percentage bases,
changed flex heights, font-file retention and late availability, large CSS
component serialization, and lazy DOM reads with pending writes and inserted
nodes. Final native comparisons pass for `inline-node`, `ordered-list`,
`text-decorations`, and `svg-image-source-switch-same-size`; the ordered list
and SVG source-switch comparisons are pixel-exact. The earlier lazy-content
build also passes `selection-focus-between-text-controls` exactly.

```sh
sh build-prod-browser.sh
LADYBIRD_DEBUG_TIMING=1 Build/v/Vox.app/Contents/MacOS/Vox https://github.com/vlang/v
```

Use `sample PID 2 5 -file OUTPUT.txt` during a slow phase to inspect the native
stack. Account for cached-page installation and background refresh separately;
a blank upstream headless screenshot is not a valid speed comparison.

Build an instrumented native browser with V's profiler, then restore the normal
build before measuring speed:

```sh
LADYBIRD_V_PROFILE="$PWD/Build/v/github.vprof.txt" sh build-prod-browser.sh
LADYBIRD_SCREENSHOT_DELAY_SECONDS=0 Build/v/Vox.app/Contents/MacOS/Vox \
  --screenshot "$PWD/Build/v/github.profile.png" https://github.com/vlang/v
sort -k3,3nr Build/v/github.vprof.txt | head -n 30
sh build-prod-browser.sh
```

The current profiler emits calls, inclusive milliseconds, exclusive
milliseconds, average nanoseconds, and the C function name.
`LADYBIRD_V_PROFILE_FNS` overrides the default navigation/layout entry points.
The build supplies the macOS stdio compatibility flags required by this
compiler's profiling output.

## Round 34: rejected intrinsic chunk-pool prototype

A source-owned pool of at most eight returned measurement chunks passed the
16-case baseline and 19-case candidate focused selections (17,753 baseline
assertions; 17,795 candidate assertions in both Boehm and no-GC C-O2 builds).
Three fixed alternating diagnostic pairs measured 8,192 complete intrinsic
width/height probes per observation, with setup, warmups and forced GC outside
the counter. Median retired instructions rose from 1,355,157,482 to
1,356,832,572 (+0.12%); two of three pairs worsened. Every checksum was
180,379,648. This design is rejected with zero performance credit.

The prototype, focused logs, initial import failure and all six diagnostic
observations remain in `Build/v/instruction-opt34-*` and the frozen snapshots.
Only this prototype's four owned runtime edits were restored; its uncommitted
test was archived. No browser primary observations or normal browser build
were started. The declared page cohort remains unexecuted, and the broad
validation baseline stays at round 33. Chrome parity remains open.

## Round 36: rejected explicit DOM root loop

An explicit loop over Node's retained parent pointers passed nine focused cases
in before/final Boehm and final no-GC C-O2 builds, including deep connection,
detachment, reparenting, nested shadow roots and adoption. Native disassembly
then showed the existing recursive implementation and the proposed loop both
compile to the same five-instruction pointer walk. The rewrite is rejected.
Its three alternating local pairs are retained; the control's very cheap
optimized lookup loop makes source-call counts an unreliable description of
completed native traversals. No local or page saving is credited.

Only the proposed root-method edit was restored, and its uncommitted tests
were archived. Initial test-harness compiler failures, generated-C comparator
ordering mismatch, focused results and disassembly remain under
`Build/v/instruction-opt36-*`; the frozen prototype is retained. The speculative
normal build is independently recorded without performance credit. No browser
primary observations started, and the declared page cohort remains unexecuted.
