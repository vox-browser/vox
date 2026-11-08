# github.com/vlang/v: Vox versus Brave instructions, 2026-11-08

Current goal (user, November 8): load `https://github.com/vlang/v` with at least
**20% fewer observed instructions** than Brave. **The latest c29 build gives
19.7355% fewer and still misses the conservative gate by 29,265,424 instructions.
The earlier c26 pass does not establish acceptance for the corrected build.**
Acceptance requires seven complete alternating pairs and
`10 * max(Vox) <= 8 * min(Brave)`. Tests started only after c26 passed, as requested.

The earlier 10% goal was **met for the pinned c12 frozen-page workload.** Seven
complete alternating pairs give a conservative maximum-Vox/minimum-Brave ratio
of **0.88483393** (11.5166% fewer observed instructions). The maximum Vox count,
9,760,439,813, also passes the earlier November 7 Brave minimum. First launches
and the earlier failed cohorts remain included. Regression and screenshot
checks started only after this complete instruction gate passed.

The ongoing 20% work keeps its generated performance diagnostic ledger local,
outside Git; the results are summarized in this report.
The restored HTML and both engine reference PNGs match c12 exactly. The rebuilt
response-cache directory has a different fingerprint, so it is pinned as a new
workload cohort and supplies no fixture-change optimization credit. The first
new cohort attempt is invalid because Brave's teardown watchdog exited nonzero;
its counters and failure remain recorded. Separate cleanup diagnostics exit
normally after the already-frozen capture endpoint. Parser and layout probes
are diagnostic only; the later native acceptance and regression results are
reported separately below.

The first complete 20% cohort, c13, still fails: maximum Vox **9,147,785,937**,
minimum Brave **11,072,030,805**, ratio **0.82620669** (17.3793% fewer).
Vox/Brave medians are 9,107,530,866 / 11,182,995,768. All seven alternating
pairs completed with normal browser exits, complete document audits and exact
per-engine reference pixels. Benchmark exit is 1 because the gate fails;
the memory guard completed under its 12 GiB cap, peaking at 1,406,369,792 bytes.
[Full c13 counts, commands, identities and exits](performance/github-vlang-instructions-20261108-20pct-c13.json)
are retained. The pinned executable is `b8c5285a19472a2abaddcbe8c3bafcc232aeea611a151ee6b0b6b7f33dc6553a`,
receipt `20261108-091839-e5dbdb92`. It uses a single C unit with non-literal
V `-prod` generation, `-O3` and inline threshold 1500, unlike c12's literal
`-prod`/`-O2` build. Concurrent engine changes are included; the cross-build
difference cannot be assigned solely to this session's optimizations.

The next complete cohort, c14, also fails: maximum Vox **9,133,086,489**,
minimum Brave **11,044,140,373**, ratio **0.82696219** (17.3038% fewer).
All fourteen captures remain pixel-exact with complete content audits and
normal browser exits. The publisher's completed staging bundle was measured
directly while another session's read lease delayed canonical publication;
no app bundle was copied or replaced. Executable
`207a9cc799d6020bf4c6a63d4b6cd18c06f12f60aaf63a79a49dfaa2560167f1`,
receipt `20261108-094601-fd31969d`, has the same single-C-unit O3 compilation
policy as c13. Benchmark/guard exit is 1 for the failed gate, with peak RSS
1,403,207,680 bytes. [Full c14 evidence](performance/github-vlang-instructions-20261108-20pct-c14.json)
retains every pair. Newer scalar-read, repeated-input, font-rule and line-buffer
candidates are absent from that binary and still need native validation.

The ownership-corrected candidate's complete c16 cohort also fails:
maximum Vox **9,106,689,654**, minimum Brave **11,061,084,520**, ratio
**0.82330893** (17.6691% fewer). All fourteen captures retain exact references,
complete content audits and normal exits. The 20% integer gate is
`91,066,896,540 > 88,488,676,160`. Executable
`67e9b8010eba8dcf31cc78152f7df19b7cd2793bac84720ecf673efb226e7c5e`
is newly compiled from the canonical source tree, using the same single-C-unit
non-literal-prod O3 policy as c13/c14. Its resources and ordinary small helper
reference the shared bundle under a publication lease; no app bundle was copied.
C compilation and frozen-input verification succeed; signing through referenced
bundle metadata initially fails and succeeds after generating regular packaging
metadata and verifying the raw executable signature. [Full c16 evidence](performance/github-vlang-instructions-20261108-20pct-c16.json)
retains both build/sign exits and every observation. Regression tests remain
deferred. A separate [c15 diagnostic cohort](performance/github-vlang-instructions-20261108-20pct-c15-diagnostic.json)
also fails and predates the boxed-payload ownership correction; it supplies no
acceptance claim. Fresh native diagnostics confirm the proposed fast paths
execute, but their headless gains are not additive native instruction credit.


Two later complete cohorts also fail. Experimental LLVM code generation in
c19 regresses to maximum Vox **9,607,344,384** / minimum Brave
**10,877,278,616**, ratio **0.88324890** (11.6751% fewer). Fresh C compilation
in c20, with native CPU tuning, inline threshold 3000 and machine outlining
and LTO disabled, gives **9,290,744,836** / **11,035,100,242**, ratio
**0.84192664** (15.8073% fewer). Each retains all seven pairs, fourteen exact
per-engine captures, complete content audits and normal browser exits. Both
benchmark/guard exits are 1 because their numerical gates fail; build guards
exit 0. These compiler experiments supply no optimization credit. The best
complete result remains c16, and regression tests remain deferred.
[Full c19 evidence](performance/github-vlang-instructions-20261108-20pct-c19.json)
and [full c20 evidence](performance/github-vlang-instructions-20261108-20pct-c20.json)
retain raw observations, identities, compiler provenance and exits. The two
intermediate build attempts c17/c18 produced no executable after their memory
guards terminated compilation; they contain no browser observations and remain
in the diagnostic ledger.


The next completed production bundle, receipt `20261108-123227-9e5f1952`,
was measured directly under its artifact lease in c22. It gives maximum Vox
**9,035,649,175** / minimum Brave **11,005,526,793**, ratio **0.82101015**
(**17.8990% fewer**). Vox/Brave medians are
8,950,439,213 / 11,071,898,785.
All seven alternating pairs, fourteen exact per-engine captures, complete
content audits and normal browser exits are retained. Its integer gate still
fails: `90,356,491,750 > 88,044,214,344`; Vox needs another **231,227,741**
instructions removed at that Brave minimum. Benchmark/guard exit is 1 for the
failed numerical gate, build guard exit 0. The single-C-unit O3/1500 policy
matches c16. This is now the best complete observed ratio, but still does not
meet 20%; median paired savings of 19.9768% do not satisfy the conservative
gate. Regression tests remain deferred. [Full c22 evidence](performance/github-vlang-instructions-20261108-20pct-c22.json)
retains build identity, source inputs, exact counters, commands and exits.
The earlier private candidate9 build and c21 watcher stopped before producing
an executable or any browser observations; their final exits were unavailable
on resume and are not inferred to have succeeded.

The following completed production cohort, c23, regresses to maximum Vox
**9,643,702,027** / minimum Brave **11,064,029,801**, ratio **0.87162654**
(**12.8373% fewer**). Vox/Brave medians are
9,503,105,698 / 11,358,357,657. All seven pairs retain exact per-engine pixels,
complete content audits and normal browser exits; benchmark/guard exit 1
records the failed numerical gate. Executable
`c7079cad06a2637240b8eab7e3ab6836e4c086a4fc714c706f7494ed3fe516d0`,
receipt `20261108-132148-eb3fda13`, uses the same single-C-unit O3/1500
policy but a newer V frontend and concurrent engine changes. It contains the
compact singleton CSS value prototype. Inspection of its generated C reveals
that recursive child equality compares slot addresses rather than child values;
this source candidate requires correction before acceptance. Coarse phase
markers place most of the extra observed work in paint and capture, without
proving that equality caused it. C22 remains the best complete result at
17.8990% fewer. [Full c23 evidence](performance/github-vlang-instructions-20261108-20pct-c23.json)
retains every observation and build receipt. Regression tests remain deferred.

C24, with recursive slot and parser-payload value equality restored, also
fails the conservative gate. Its first Vox launch uses **10,351,680,022**
instructions; the remaining six use 8,849,933,327–8,878,174,575. All seven
observations remain included. Minimum Brave is **11,003,128,307**, producing
ratio **0.94079427** (5.9206% fewer), despite median paired savings of 21.0418%.
All fourteen captures retain exact per-engine references, complete content and
normal browser exits. The first launch performs an additional paint-command
checkpoint with roughly 899M instructions; its cause remains unresolved.
Executable `5837924433ab3217d0db412cb9da680d6fc8a94ca222b503dcfed0c8174d0ffa`
uses canonical sources with the same single-C-unit O3/1500 policy. Build guard
exits 0, while benchmark/guard exit 1 records the failed gate. C22 remains the
best conservative result. [Full c24 evidence](performance/github-vlang-instructions-20261108-20pct-c24.json)
retains the first-launch outlier and all other attempts. Regression tests remain
deferred.

The complete c26 cohort passes against the updated installed Brave:
maximum Vox **8,965,426,938**, minimum Brave **11,318,614,571**, ratio
**0.79209579** (**20.7904% fewer**). The exact integer gate is
`89,654,269,380 <= 90,548,916,568`. All seven alternating pairs, including the
first launch, retain exact per-engine pixels, complete content audits and
normal exits; benchmark and guard exit 0. Vox/Brave medians are
8,875,520,338 / 11,595,809,689. Executable
`3562d544a39e4a36ab32132c78d586dd105171bd4883919ae19ef6b2294a37d4`
uses literal V `-prod`, one C unit, O3/1500, LTO disabled and frame pointers
omitted; its minimum macOS target is 27.2 (current packaging minimum 26.0).

Brave updated between c24 and c26 from Chrome 156.0.8078.48 to
Chrome 157.0.8103.39, with a different executable hash. C26 pins the updated
browser throughout. Vox's median is essentially unchanged from c24, so this
result does **not** isolate a gain from compiler tuning or establish 20% against
the earlier Chrome 156 minimum. OS filesystem/shader caches remain retained,
with fresh private profiles/page caches; no preparatory native13 browser run
preceded its acceptance cohort. [Full c26 evidence](performance/github-vlang-instructions-20261108-20pct-c26.json)
retains exact counts, both browser-version identities, input/source hashes,
commands, host contention and exits.

The deferred checks then caught a real scalar color-serialization mismatch:
the shortcut emitted legacy `rgba()` syntax rather than ordinary `Color.serialize()`
modern `rgb()` syntax and alpha precision. Commit `8446d7cbb` fixes it and adds
an explicit contract case. The 236-case focused CSS, 214-case broader CSS,
26-case additional equality/invalidation and 84-case layout batches pass in
both Boehm and preallocation/no-GC modes with normal assertions. These are
batch invocations with overlapping cases, not a sum of distinct tests. The
50 build-tool checks pass (two existing skips), as do 66 benchmark-driver checks.
The FastC filter helper compiles and passes its JavaScript/filtering/idle-release
check after the module-directory build fix. Initial failures and fixture fixes
remain in the [20% verification receipt](performance/github-vlang-instruction-validation-20261108-20pct.json).
C26 predates the serializer correction; final native startup/visual checks and
a new seven-pair cohort remain required before completing the goal.

C27 is invalid: Vox captures correctly at 8,986,010,264 instructions, then
Brave captures but exits 2 from its macOS teardown watchdog. Both counters and
the failed browser/guard exits are retained. A target-close cleanup experiment
also hits the watchdog and is removed. The retained cleanup change releases the
observer's DevTools socket after `Browser.close` is acknowledged and before
waiting for process exit (`493ff9f58`). It runs after the frozen counter endpoint
and earns no instruction credit. No launch flags, references or counter
boundaries change. The watchdog's documented ten-second termination is described
in the [Chromium implementation](https://chromium.googlesource.com/chromium/src/+/dc1ae3ada2dffe30971100b5b1d3185b1ad395c1%5E!/).

C28 completes all seven alternating pairs with exact per-engine references,
complete content audits and normal exits. Maximum Vox **8,872,351,990** /
minimum Brave **11,024,953,359** gives **0.80475188**, or **19.5248% fewer**.
The integer gate fails: `88,723,519,900 > 88,199,626,872`. Vox/Brave medians
are 8,852,126,742 / 11,070,951,458; the median paired reduction of 20.0780%
does not satisfy the conservative gate. Benchmark/guard exit is 1 for the
numerical failure. The build and native-check guards exit 0.

Executable `91be2b76025a47d21d22e7f40d13ebc47c81da4832515014a72c3506da579831`,
receipt `20261108-151324-a8c2bca5`, is a completed production staging build
with one C unit, non-literal-prod O3/1500 and minimum macOS 26.0. It contains
the serializer correction and all retained slot/equality/tokenizer changes.
The same image passes native DOM mutation/click/wheel startup checks, the real
filter-worker self-check, and all eleven standard visual cases: eight exact
and three within their unchanged existing fuzzy bounds. Source/reference hashes
remain fixed. A separate diagnostic explicitly verifies scripting enabled,
page runtime uninitialized and zero page sources on this script-free fixture;
the helper independently executes JavaScript. This supplies no live-page
script-execution claim. [Full c28 and partial c27 evidence](performance/github-vlang-instructions-20261108-20pct-c28.json)
and the [verification receipt](performance/github-vlang-instruction-validation-20261108-20pct.json)
retain the exact counters, identities, inputs, commands, failures and exits.
Brave remains Chrome 157, but its observed counts are lower than c26 under
the retained OS-cache conditions. Further engine optimization remains required.


C29 includes bulk ASCII/filter-byte probes and a narrowly eligible exact-UTF-8
ASCII decoder shortcut. It again completes seven alternating pairs with exact
pixels, complete audits and normal browser exits, but misses the20% gate:
maximum Vox **8,880,773,337** / minimum Brave **11,064,384,892**, ratio
**0.80264501** (**19.7355% fewer**). The integer check is
`88,807,733,370 > 88,515,079,136`, leaving **29,265,424** Vox instructions to
remove at this minimum. Medians are8,851,404,119 /11,128,645,021; the20.6438%
median paired saving cannot replace the failed conservative check.
Executable `f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`,
receipt `20261108-155123-59ff4982`, uses the same single-C-unit compilation
policy as c28. Build guard exits0, benchmark/guard1 for the numerical failure.

The preprocessing path executes in a separate native diagnostic. In matched
headless probes it saves median50,537,982 parsing instructions and18,894,627
layout-workload instructions with identical geometry. These are not additive
native credit: two same-image native A/B pairs show a10,170,454-instruction
regression and a14,383,224 saving. The small net median2,106,385 saving does
not establish a consistent full-load improvement. All four A/B captures retain
exact reference pixels and normal exits. New bulk regression checks remain
explicitly deferred after c29 fails. [Full c29 evidence](performance/github-vlang-instructions-20261108-20pct-c29.json)
retains every pair and the complete A/B. Increasing the longhand cache beyond
256 entries executes but has only a1,032,973 median probe saving with one
regression; that experiment is removed. Further optimization is required.

## Workload and scope

- Input: Brave's serialized DOM of the hydrated repository page, with every
  `<script>` removed and `<base href="https://github.com/vlang/v">`, plus the
  Sponsor heart's decorative `anim-pulse-in` class removed (Brave captured
  the 0.5 s pulse at varying phases). HTML SHA-256 prefix `4379cf699ec3e09b`.
  The page has 2,986 elements, 42 stylesheet links (2.56 MB of CSS loaded),
  33 directory rows and 38 images.
- Responses: 248 cache entries recorded by one networked Vox run (fingerprint
  prefix `97f637eaeda5b331`). Vox reads a fresh copy per run behind the
  process-local network-deny dylib; Brave replays the same bodies through CDP
  `Fetch`. Responses Vox never requested fail in Brave too.
- Scope: fresh launch through completed document capture, 1024×768 document
  viewport, 1× capture, fresh private profiles, no settle period. Vox counts
  its process tree from launch to exit after the capture (including teardown,
  about 47M); Brave counts its observed process tree from launch to the last
  complete sample before the CDP screenshot response (a polling lower bound,
  9 processes, browser shutdown excluded). Neither includes GPU execution or
  WindowServer.
- Pixels: each engine is compared with its own fixed reference (Brave
  `fbb453c8b70af3ba`, Vox `c4afc9a43569d7c4`). The two references differ in
  1,015 pixels (0.13%); this is not a cross-browser pixel-equality claim.
- Driver: `tools/github_browser_instructions.py` (`61917182c`), run under the
  memory guard; JavaScript enabled in both, no page scripts remain.

## Earlier 10% cohort: 2026-11-08, c12 (seven alternating pairs)

The shared production executable is
`468f7a4d650bf9880564cc40be5d8c60221ac769a9097714e639f499bb8b5201`,
frozen compilation `20261108-064807-93bb0c84`: single C unit, V `-prod`,
preallocation and JavaScriptCore. It includes the committed c11 engine fixes,
common-subject bucketing for multi-alternative `:is()`/`:where()`, and early
before/after admission when no candidate declaration can set `content`/`all`.
Concurrent canonical changes are included; this cohort establishes the combined
executable result. GitHub's URL-specific stylesheet startup handling is present
but ineligible for this file-URL fixture.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 9,760,439,813 | 11,030,815,529 |
| 2 | 9,731,553,687 | 11,094,836,329 |
| 3 | 9,719,933,395 | 11,155,174,516 |
| 4 | 9,680,281,407 | 11,131,048,931 |
| 5 | 9,719,071,273 | 11,078,394,136 |
| 6 | 9,685,598,004 | 11,073,377,614 |
| 7 | 9,680,452,413 | 11,116,788,355 |
| **Median** | **9,719,071,273** | **11,094,836,329** |

The integer gate passes:
`10 * max(Vox) = 97,604,398,130 <= 9 * min(Brave) = 99,277,339,761`.
The median reduction is 12.4000%; the conservative reduction is 11.5166%.
Against the historical Brave minimum of 10,876,864,218, the maximum Vox
observation is also below the 9,789,177,796 limit.

All fourteen browser observations exit zero, with exact fixed-reference pixels
and complete identity, readiness, viewport and 33-row audits. Benchmark and guard
exits are zero; peak guard RSS is 1,485,062,144 bytes under the 12 GiB cap. The
publication lease pins browser/native-library hashes throughout. Brave reports
Chrome/156.0.8078.48 and V8 15.6.75.19. The host has 18 CPUs; first load averages
span 14.13–19.56. Profiles and page caches are fresh; OS filesystem/shader caches
are retained. No preparatory Vox-only measurement ran for this cohort; no trial
was retried or excluded, including its first launch. Observed process-tree
counts are lower bounds for both engines; they exclude GPU/outside-service
work, and Vox's exited helper lacks a final sample. This is a frozen script-free
startup/capture result; it establishes no live-site JavaScript, isolated rendering
time or scrolling-FPS result.

The [complete c12 receipt](performance/github-vlang-brave-instructions-20261108-c12.json)
retains every raw process count, identity, endpoint, host observation, command,
exit and content/pixel audit. Separate headless matched probes measure the
common-subject bucket and combined admission changes with unchanged geometry;
those diagnostics do not isolate their contribution to the native cohort.

After the passing gate, all 146 CSS cases pass in both Boehm and
preallocation/no-GC modes. All eleven standard visual cases pass their unchanged
tolerances: eight are pixel-exact, while inline-node, text-decorations and
canvas-text retain their existing font/canvas allowances. The GitHub cohort's
fourteen captures are separately pixel-exact. New cases cover bucket completeness
against full selector matching, ancestor versus subject conditions, quirks
folding, specificity, lazy declaration inspection, CSSOM edits, hover content,
removal of published pseudo styles, origin/layer sources and shadow/host fallbacks.
The final fixes are committed as `bb70b2864` and `b58a355e5`. The earlier 138-case
CSS and 33-case layout batches already passed both modes after c9; the driver's
37 Python cases passed then too.
The [c12 verification receipt](performance/github-vlang-instruction-validation-20261108-c12.json)
retains commands, executable/source hashes, exits, case names, memory peaks,
visual metrics and initial fixture failures with their corrections. No engine
code changed after the measured c12 cohort. Scratch captures and temporary
combined test binaries are removed after recording the durable receipts. The
[remaining diagnostic ledger](performance/github-vlang-instruction-diagnostics-20261108.json)
retains quick runs, rejected prototypes, matched headless comparisons and
memory-guard receipts; these do not replace the acceptance cohorts.

## Historical failing cohort: 2026-11-08, c11 (seven alternating pairs)

The shared executable is
`692d893aa761c77d6f8fc6eb50db183accd230bbe40edbb9e6f738b3a817ce9d`,
frozen compilation `20261108-060445-7df1d8ac`, with single C unit, V `-prod`,
preallocation and JavaScriptCore. It contains the five committed engine fixes
and the live rule-cache query correction found by the CSS batch. The discarded
content-candidate experiment is absent from its frozen C. Concurrent canonical
changes are included.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 10,199,762,543 | 11,319,507,759 |
| 2 | 9,929,172,261 | 11,112,506,819 |
| 3 | 9,920,480,957 | 11,218,142,178 |
| 4 | 9,878,277,406 | 11,038,269,314 |
| 5 | 9,885,065,108 | 11,156,280,990 |
| 6 | 9,867,063,817 | 11,084,653,107 |
| 7 | 9,892,795,431 | 11,255,388,243 |
| **Median** | **9,892,795,431** | **11,156,280,990** |

`10 * max(Vox) = 101,997,625,430` exceeds
`9 * min(Brave) = 99,344,423,826`. Ratio: 0.92403639. The largest Vox
count needs at least 265,320,161 fewer instructions against this
Brave minimum. The median improvement does not satisfy this conservative gate.

All fourteen browser observations exit zero and retain exact fixed-reference
pixels and complete content audits. The benchmark and guard exit 1 for the
numerical failure; peak guard RSS is 1,479,606,272 bytes. The first Vox launch
is retained without a retry or exclusion. Its root contributes 9,925,355,613
instructions and its observed helper 274,406,930. The first-to-second difference
is mainly in the root, rather than an extra counted helper. No cause or engine
saving is inferred from that variation. Profiles, fixture/reference bytes,
viewport and measurement boundaries are unchanged.

The [complete c11 receipt](performance/github-vlang-brave-instructions-20261108-c11.json)
keeps all raw counters, identities, host conditions, commands and exits. It
superseded the earlier c9 checkpoint; the c12 cohort above now supplies
acceptance. Tests ran only after the earlier complete c9 gate passed; the
ordering is pinned in the verification receipt. Optimization continued after
this failure.

## Historical passing checkpoint: 2026-11-08, c9 (seven alternating pairs)

The pinned shared production executable is
`cd2b932437b2acf1ac113152c571af31c2bed0c8d8ffb7b9f4d1510c48d394d8`,
frozen compilation `20261108-053350-f77c8445`: single C unit, V `-prod`,
preallocation and JavaScriptCore. Besides the earlier committed optimizations,
it contains closed-inline question normalization, document-owned selector reuse,
per-pseudo rule indexes, writing-mode/direction declaration indexes, and the
absent generated-content preflight. Concurrent canonical changes are included;
this cohort establishes the combined executable result.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 9,901,425,124 | 11,208,997,250 |
| 2 | 9,922,531,593 | 11,309,787,202 |
| 3 | 9,948,024,034 | 11,169,279,474 |
| 4 | 9,908,670,937 | 11,106,986,445 |
| 5 | 9,878,544,659 | 11,144,512,232 |
| 6 | 9,928,661,154 | 11,316,987,949 |
| 7 | 9,937,761,026 | 11,205,473,395 |
| **Median** | **9,922,531,593** | **11,205,473,395** |

`10 * max(Vox) = 99,480,240,340` is below
`9 * min(Brave) = 99,962,878,005`. The conservative ratio is
0.89565465, or 10.4345% fewer observed instructions.
All fourteen browser exits, the benchmark and the memory guard are zero. Every
capture is pixel-exact against its unchanged engine reference, with successful
identity, readiness, viewport and complete 33-row audits. No observation within
this cohort was retried or excluded. A shared publication lease pinned the bundle.

The guard peak is 1,443,774,464 bytes under the 12 GiB cap. The host has 18 CPUs;
first load averages span 52.08–65.89. Filesystem/shader caches
were retained, and private browser profiles/page caches were fresh. Counts are
polled process-tree lower bounds for both engines; exited/unsampled helpers,
GPU execution and outside services retain the coverage limitations above.
The [durable receipt](performance/github-vlang-brave-instructions-20261108-c9.json)
keeps exact per-process counts, identities, input hashes, host conditions,
commands, exits, pixel/content audits and both preceding invalid attempts.

This pass is qualified by this build and these conditions. It does not pass
against the historical November 7 Brave minimum of 10,876,864,218, which would
require Vox at or below 9,789,177,796. The fresh-cohort gate and that historical
comparison are distinct; earlier failing cohorts are retained below.

Two earlier c8 attempts were invalid: the first Brave shutdown was forced with
exit -9, and the second hit Brave's own teardown watchdog (exit 2). Extending
only the external wait exposed the watchdog. `0b55811b4` now cancels pending
page loads and disables resource interception after the frozen screenshot
counter endpoint, then requests Browser.close and requires an observed unforced
zero exit. It records cleanup and shutdown timing. The subsequent Brave-only
diagnostic and all seven accepted Brave observations exit normally. No capture
boundary moved, and this cleanup fix receives no engine optimization credit.

Per the user's request, the regression batch started only after this full
seven-pair gate passed. The 138-case CSS batch and 33-case layout batch pass
in both Boehm and preallocation/no-GC modes; 37 benchmark-tool tests pass.
The fixes are committed as `74b231aa9`, `d260ddea8`, `6394e67b4`,
`7d5fd8e46` and `fecf96523`. [Verification receipts](performance/github-vlang-instruction-validation-20261108.json)
retain the initial compile/runtime failures and their corrections. The later
c11 failure and c12 pass above retain the complete sequence. Further checks
resumed only after the c12 instruction gate passed.

## Historical cohort: 2026-11-08, c6 (seven alternating pairs)

The shared single-C-unit production executable is SHA-256
`c6b62c77913a18117f269fda73097c703b64e3d789b1ffe607f07c3f09efae95`,
built with V `-prod`, preallocation and JavaScriptCore. Its frozen compilation
receipt is `20261108-040315-4aba4e3c`. It contains the CoreText match cache
(`9f92e7888`), deferred PNG decoding (`72dabae0e`), inline element measurement
reuse (`a856c1160`), borrowed CSS syntax accessors (`56b74e474`), and the
pending closed-inline question normalization. Other concurrent canonical
changes are included; this cohort establishes the combined build result.

Each trial launched a fresh process. A shared publication lease held the bundle
fixed throughout all seven pairs. All fourteen captures were pixel-exact against
the unchanged per-engine references, and the identity, readiness, viewport and
33-row audits passed. No samples were retried or excluded. Profiles/caches were
fresh; OS filesystem and shader caches were retained. Host load and process
identities, counter coverage and exact exits are in the
[durable cohort receipt](performance/github-vlang-brave-instructions-20261108-c6.json).
Both engines use the same process-tree polling counter; their counts remain
observed lower bounds. This is a frozen script-free rendering workload, not a
live GitHub JavaScript-performance result.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 10,346,246,925 | 11,219,964,913 |
| 2 | 10,331,029,004 | 11,196,977,886 |
| 3 | 10,319,156,939 | 11,164,294,445 |
| 4 | 10,285,961,644 | 11,160,582,445 |
| 5 | 10,288,987,068 | 11,000,648,629 |
| 6 | 10,335,736,124 | 11,083,115,023 |
| 7 | 10,317,367,064 | 11,013,385,790 |
| **Median** | **10,319,156,939** | **11,160,582,445** |

`10 * max(Vox) = 103,462,469,250` exceeds
`9 * min(Brave) = 99,005,837,661`. The conservative ratio is
0.94051244. The largest Vox count must fall by at least
445,663,159 instructions against this Brave minimum.
The benchmark and memory guard both exit 1 because the instruction gate fails;
individual browser observations complete successfully. The guard's peak is
1,471,004,672 bytes, below its 12 GiB cap.

At this checkpoint regression tests were deferred until the instruction gate
passed, as requested by the user. These earlier checks remain historical evidence.

## Historical cohort: 2026-11-07 (seven pairs)


Vox: private single-C-unit build of the canonical tree including
`376272155`, executable SHA-256 prefix `8e63a3693630a02f`. Brave
156.1.98.60 (Chromium 156.0.8078.48). All exits zero, all captures exact
against their references, all 33 rows present in order.

| Pair | Vox | Brave |
| --- | ---: | ---: |
| 1 | 12,293,413,600 | 11,108,817,812 |
| 2 | 12,352,003,793 | 11,056,159,242 |
| 3 | 12,268,078,994 | 10,897,522,076 |
| 4 | 12,326,536,648 | 10,876,864,218 |
| 5 | 12,213,277,249 | 10,985,556,298 |
| 6 | 12,278,125,302 | 10,896,091,333 |
| 7 | 12,295,985,694 | 11,022,444,115 |
| **Median** | **12,293,413,600** | **10,985,556,298** |

Worst Vox over best Brave: 1.136. The 10% gate requires
`10 × max(Vox) ≤ 9 × min(Brave)`, i.e. Vox at or below about 9.79B here.

## Earlier scroll-timeline change

`376272155` samples scroll-driven animations after each layout pass inside
`Document.update_layout()`. GitHub's repository tabs reveal their More
button through `animation-timeline: scroll(self)`; the change used to appear
only at the next animation frame and forced a third full layout after the
first paint. Same binary, three runs each: 12.40B with the change versus
13.62B with `VOX_DISABLE_SCROLL_TIMELINE_LAYOUT_VALIDATION=1` (−1.22B), with
identical captures.

## Historical ~12.3B phase breakdown

| Phase | Instructions |
| --- | ---: |
| First style pass (`build_boxes`) | 2.78B |
| Stylesheet fetch and parse (`preload_resources`) | 1.76B |
| First layout pass | 1.66B |
| First frame raster (`frame_complete`) | 1.52B |
| Second layout pass (size container queries) | 1.49B |
| AppKit/window setup and first frame preparation | 0.84B |
| Image hooks: synchronous full decode of every `<img>` | 0.69B |
| Startup, parsing, paint recording, capture | ~0.7B |
| Adblock worker process | 0.26B |

## Earlier remaining-work assessment

1. **Second layout pass (~1.5B).** GitHub hides tab icons with
   `@container (width<48rem)`; the second tab strip is 604 px wide, which is
   only known after layout. About 11 elements change `display`, but the tree
   builder rebuilds every layout node on the path from the root, and clean
   siblings are retained only when every element passes its whitelist. In the
   second pass 3,128 of 5,408 formatting-context lookups find no cache entry.
   Options: rebuild only a size container's subtree (container queries can only
   affect descendants, and `container-type` implies layout containment), or
   interleave container-query restyling with layout as Chromium does.
2. **Style (~2.8B for 2,986 elements).** Rule matching, property computation,
   CoreText face matching per (family, weight, size), rule-cache building and
   `:has()` invalidation each cost tens of milliseconds.
3. **CSS parsing (~1.5B for 2.56 MB).** Tokenizing, selector parsing and rule
   conversion; declarations could be parsed lazily per matched rule.
4. **First frame raster (~1.5B).** SVG icons and rounded rects are drawn through
   per-primitive GPU round trips with synchronous readback (gg.canvas/Graphite);
   Brave rasterizes on the GPU outside the counted CPU work.
5. **Image decoding (~0.5B).** Every `<img>` and preloaded image is fully decoded
   with stb at installation, including 1 MB README screenshots and header-menu
   PNGs outside the viewport; only natural sizes are needed before paint.

Same-binary GPU canvas capture (`VOX_ENABLE_GPU_CANVAS_CAPTURE=1`) did not
change Vox's total (13.70B versus 13.69B). Allowing absolutely positioned
subtrees in retained flow reuse did not shorten the second pass and was not
kept.
