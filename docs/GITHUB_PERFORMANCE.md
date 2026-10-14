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
