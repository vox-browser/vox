# Comment interaction work toward Brave latency

This continues [the latency follow-up](OLD_REDDIT_COMMENT_LATENCY_FOLLOWUP.md).
Brave parity remains open. The older follow-up's installed application and
measurements are preserved; the candidates below have not yet replaced it.

## Workload and measurement correction

The earlier fixed-control replay omitted Reddit's stylesheet and ran in quirks
mode. It was useful for handler diagnostics but inadequate for judging actual
comment interaction latency. The current replay restores the HTML5 doctype,
loads cached common Reddit styles, installs the original Reddit document base,
and runs the saved thread's original nine scripts. It clicks the original
`return togglecomment(this)` link with native mouse events. Native DOM and
JavaScript facade state must agree after every action. No proxy button or
replacement handler is used.

The standards-mode, port-normalized fixture SHA-256 is
`1f1c35438904efa1d791fb5b0736b3b8e9f431a0f6571b38228d6142faf4b681`.
The target's document rectangle is (63, 3520.265625, 19.265625, 14); scroll is
3380 CSS pixels. Brave uses the same fixture and target. Its recorded
`compatMode` is `CSS1Compat`, with an HTML doctype. Its six-click median through
two animation frames is 26.35 ms (`styled-standards-brave.json`). Vox measures
native mouse-down through completion of its layer update. These endpoints
are useful interaction comparisons but are not identical rendering endpoints.
Neither includes physical display scanout. Live Reddit currently returns a
block response; these results apply to the cached scripted replay.

## Completed fixes through the source-15 checkpoint

| Commit | Completed change |
| --- | --- |
| `ceb19991` | Invalidate retained text chunks when their font owner changes. |
| `ded0bdf4` | Expose computed-style mutation revisions for cache validation. |
| `0ec44055` | Apply requested screenshot scrolling after document installation. |
| `d436e828` | Refresh outline paint styles without rebuilding all transport. |
| `7530dd95` | Defer offscreen native phase commands until the viewport needs them. |
| `15397faf` | Reuse committed inline geometry during DOM paintable attachment. |
| `c949e451` | Keep inline item capacity growth geometric. |
| `6c9072c2` | Reject unsupported raw handlers before enumerating DOM owners. |
| `00b4ee46` | Resolve compact event targets using retained element identities. |
| `f7c2f2f4` | Retain closed inline geometry, paint and caret projections. |
| `23909048` | Retain ordinary action forms across unrelated tree updates. |

The hover identity correction `1559fd8f` was adopted from concurrent canonical
work, rather than credited as another owned fix. Every completed owned fix
has focused checks in both GC configurations. Source-15 broad coverage also
includes the action-form fix, so subsequent cadence starts after it.

Source-15 selects 1,040 original files and 4,064 test functions per GC
configuration across layout, CSS, browser bindings and root browser tests.
Original function bodies are grouped for compilation and each original file
runs in a fresh process. Raw broad exits are nonzero: CSS passes all 1,201
functions, while layout, browser bindings and root retain failures and panics.
The per-file receipts preserve expected, passed and failed function names;
a panic does not earn credit for functions that never ran.

Newly encountered media-control, idle-filter and preload failures reproduce
against clean `77de0b7d` using byte-identical failing test files, in both GC
configurations. Previously known visual-viewport, media-source, animation,
page-cache and view-transition failures remain recorded. The XHR timeout case
passes focused on both candidate and baseline after failing in each broad
selection. No all-pass claim is made and these existing failures remain open.

The LibJS union covers 236 original files and 782 functions per configuration.
The first serial default-GC attempt was interrupted after 118 genuinely passing
files and receives no whole-run pass credit. Those successes are retained with
source hashes. Recovery runs only the other 115 ordinary files plus three
self-spawning files; no-GC checks all 233 ordinary files plus the same three
self-spawning files. Recovery exits are zero. The unchanged official AST
driver compares all 100 upstream inputs exactly. Browser JavaScript continues
to use JavaScriptCore.

The signed source-20 candidate passes startup, synthetic native comment
interaction, eight pixel-exact SVG mutation guards, and eleven default smoke
comparisons: eight exact, three under their unchanged existing allowances.
It also passes a separate exact full-versus-viewport recording comparison on
scrolled shadow, outline, transform and SVG content. This screenshot validation
does not cover later candidates automatically.

## Completed fixes after that checkpoint

| Cadence | Commit | Completed change and focused evidence |
| --- | --- | --- |
| 1/10 | `4d1257fa` | Retain ordinary flow roots and atomic inline action menus. |
| 2/10 | `05ce6ab5` | Reuse independent flow geometry with fresh UsedValues, line arrays, rare data and containing-block pointers; five focused cases. |
| 3/10 | `16a92240` | Retire superseded paintable callbacks using their installation-time inventory; three focused cases include mutation of the old layout tree. |
| 4/10 | `f6e7139a` | Honor full-canvas reference recording and retain unbounded text ink. |
| 5/10 | `10ecde42` | Generate line-box debug guides only while the inspector requests them; retain public compatibility defaults and old recordings. |
| 6/10 | `9b6562ff` | Retain media-query syntax trees while reevaluating current environments; three new cases plus existing query, link and font lifecycle coverage, 14 cases per GC mode. |
| 7/10 | `48242367` | Reuse validated flow-subtree shapes while rechecking live DOM, text, topology and computed-style identity; two new cases. |
| 8/10 | `ed456c22` | Increase the bounded large-scripted-document heap capacity hint from 160 to 320 MB, preserving explicit environment overrides, collection and idle unmapping. Existing platform heap tests pass in both modes. |
| 9/10 | `a06ffa59` | Reuse a DOM layout-style wrapper only while its exact layout mirror remains attached; reset its contents on every attachment. Three focused DOM cases and 80 repository layout cases pass per GC mode. |
| 10/10 | `5523b555` | Retain immutable paint projections inside validated independent flow subtrees, rebase coordinates, refresh live overflow and selection, and keep templates free of paint-arena links. Three new cases and 80 other layout cases pass per GC mode. |

`cd6054ed` separately repairs test isolation: the BFC fixture owns its helper
functions and compiles independently. Test-helper corrections do not advance
the fix counter. The layout aggregate also runs one private replay diagnostic,
which is not counted as an additional repository regression case.

## Measurements and ownership evidence

Tracing identified 170–210 ms of collection during warm clicks on the styled
replay. The collector already reports zero parallel markers. Changing marker
count or the free-space divisor did not establish a useful production policy.
A controlled capacity experiment with collection still enabled justified the
bounded capacity hint above. Explicit collector overrides remain diagnostic
and are not production measurements.

Walking the old layout tree to retire callbacks was insufficient because tree
rebuilding changes that old tree. A weak-reference probe kept all six old paint
arenas alive before the installation inventory fix. After it, old arenas are
collected and only the current arena remains. Graph scans exclude atomic GC
allocations to avoid treating string bytes and numeric map keys as references.
Forced collections and graph probes run after the measured endpoint and do not
provide latency credit.

Normal source-24 production replay, with no collector environment overrides,
records first action 114.345 ms and seven warm actions from 74.237 to 80.515 ms.
Normal source-25 records first action 102.172 ms and warm actions from 66.323 to
68.655 ms. Every native and facade state alternates correctly. Source-25's
executable SHA-256 is
`43d83230ca9f44af4758af5fdb9eea96151f1178e24533031d254e5d6e7e0289`.
These are private candidates, not an installed-build or Brave-parity claim.

All evidence remains under ignored `Build/reddit-comment-latency/`: pinned
source manifests, actual process exits, original failed attempts, corrected
fixture runs, baseline reproductions, native logs and screenshots. Builds use
isolated source snapshots so concurrent work cannot silently change a measured
candidate. Integration with current canonical work and final application
verification remain pending.

## Source-28 checkpoint and subsequent work

The source-28 checkpoint combines the ten fixes above with canonical commits
through `ac7bb271`. Its recorded source HEAD is merge `e7dea9cd`. Each GC mode
selects 1,052 original files and 4,118 functions: 4,095 pass, 17 fail, and six
bodies do not run after existing media-control panics. Raw package exits remain
nonzero. Every failing file is byte-identical to source-15. The additional CSS
registration-key failure reproduces at clean canonical `ac7bb271` in both GC
modes, without the owned optimizations. The remaining failures have the prior
source-15 baseline evidence. The earlier XHR and preload failures now pass.
This is completed coverage with reproduced existing failures, not an all-pass
claim. The receipt is `parity-v28-checkpoint.json`; cadence resets after the
covered owned fix `5523b555`.

LibJS passes all 233 ordinary files/769 functions in both modes, plus three
self-spawning files/13 functions. Default-GC linking first failed with
`No space left on device`; that attempt earns no pass credit. Its fresh retry
passes. The official AST driver again matches all 100 inputs exactly. The
source-28 bundle passes signing, startup and native comment interaction. An
old review parser then mistook new UI2 status labels for navigation URLs.
The corrected reader verifies the same executable and actual document URL,
retains those successful checks, and resumes only unfinished screenshots:
eight exact SVG guards and eleven default cases (eight exact, three under
unchanged existing allowances). The composite receipt is
`native-parity-v28-recovered.json`; the original failed receipt remains.

Paint reuse was measured in an ABBA sequence against source-25 under heavier
host load. Warm medians are 106.298/102.328 ms for the old candidate and
95.713/96.479 ms for the new one. All 32 native and facade states agree.
The source-27 weak-reference probe collects all seven superseded arenas and
retains only the eighth/current arena. Sampling and forced collection are
diagnostic and do not earn normal latency credit.

| New cadence | Commit | Completed change |
| --- | --- | --- |
| 1/10 | `a2e73994` | Finalization and log clearing drain tracked dirty facades and registered canvases without enumerating every unchanged element. Twenty cases in nine files pass in each GC mode, including two new cases. |
| 2/10 | `0111dad1` | DOM attachment resolves selection inheritance in preorder instead of repeatedly walking ancestors. Twenty-three distinct layout cases pass per GC mode, including two new attachment cases. |

The first selection fixture expected paint-only style changes to rebuild the
DOM geometry attachment. Its failed attempt remains. The corrected fixture
explicitly requests attachment after each change; its two cases pass in both
modes, combined with the already passing 21 other cases. Only the fixture
changes after the source-30 production build; its runtime implementation is
the tested implementation. Fixture repair adds no fix count.

Normal source-28 and source-29 integrated replays record warm medians of
79.553 ms and 62.436 ms. Normal source-30 records first action 148.865 ms and
seven warm actions from 47.941 to 53.809 ms (median 51.508 ms). These fresh
observations remain slower than Brave; host load and first-action variability
remain material. No collector environment overrides are used. These candidates
are still private; the installed application and canonical working changes
remain preserved pending final integration.

The following fixes complete the next ten-fix selection. Its broad checkpoint
is pending; no reset or Brave-parity credit is claimed yet.

| New cadence | Commit | Completed change and focused checks per GC mode |
| --- | --- | --- |
| 3/10 | `569f2a59` | Share successful and failed SVG source probes during one paint-tree build, with document ownership and nested scope restoration. Expire the cache before later resource refreshes. Fourteen cases in five files pass. |
| 4/10 | `d42d9c69` | Reuse ordinary paint headers only after checking final dimensions, box edges, child presence, style identity/revision and environment; keep dynamic resources and effects on full projection. Twenty-four cases in eight files pass. |
| 5/10 | `0b771933` | Construct calculation/color contexts only for paint that needs them, retaining full gradient/filter resolution and SVG image color schemes. Twenty-one cases in seven files pass. |
| 6/10 | `6c26f447` | Replacing a layout child vector no longer detaches a child already moved into an anonymous wrapper. The new ownership case and surrounding table/tree cases pass. |
| 7/10 | `6504bb45` | Prove table-free subtrees once and skip the table-specific fixup sweeps there; restore all temporary flags afterwards. The combined ownership/table selection passes 37 cases in eight files. |
| 8/10 | `5fdde264` | Retain ordinary float-tree structure while rerunning placement, float bands, clearance and geometry. Nineteen cases in five files pass, including two new comparisons with full rebuilds. |
| 9/10 | `725fe5e1` | Assign normal-flow containing blocks in preorder while retaining absolute/fixed and inline-ancestor lookup behavior, including standalone subtree and staged-parent cases. Thirty-two cases in six files pass. |
| 10/10 | `c48ef6a7` | Accept complete reverse-identity alias lists, validate key precedence with pointer identity, and avoid provider snapshots on indexed misses. Ten cases pass: six identity/alias cases and four keyed/batch cases. |

The two source-32 comment document viewports, expanded and collapsed, remain
pixel-identical to source-31: 800×488, zero differing RGBA pixels. The source-32
weak probe again collects seven old arenas and retains only the current one.
It confirms that ordinary header templates do not root the old paint arena.

Original failed checks remain retained: the first color fixture attempted to
call `str()` directly on an optional gradient; the corrected fixture unwraps
both values and preserves the comparison. The first containing-block fixture
propagated optional values from a non-optional traversal closure; explicit
failure branches repair the fixture without changing its assertions. The first
table optimization exposed the parent-link defect now fixed separately by
`6c26f447`; the original panic receives no pass credit.

The source-38 layout aggregate adds all completed layout cases through fix nine.
Its first harness omitted `http` and `loader` imports; archived original input
and failures remain. The corrected harness passes 100 repository cases plus one
private replay diagnostic in each GC mode. The source-38 native build stops at
a misplaced tab-shortcut expression already present in canonical HEAD. The
current shared working tree contains that tab-input correction. Final
integration must preserve it and all other concurrent working changes, rather
than publishing a stale isolated application.

Several native runs were terminated by SIGTERM before their first action. They
receive no timing credit. Later diagnostic launches use private application
aliases to isolate process naming. The executable bytes are verified identical
to their production candidates; only bundle executable/identity metadata differs.
Those aliases are not claimed as signed production applications. Original
bundles and receipts remain unchanged. The adaptive profiler additionally
derives the chrome offset and adjusts window height to retain the same 800×488
document viewport after the canonical tab-strip change. Its timestamp endpoint
and original native mouse action are unchanged.

A fresh Brave replay reports 2.45 ms median handler-plus-layout and 28.35 ms
through two animation frames (`styled-v35-current-brave.json`). Under the
heavier host load during the paired source-35 replay, warm native medians are
71.527/76.268 ms against source-33's 78.595 ms. These observations show a modest
table-pass improvement but do not establish a stable latency bound or Brave
parity. Final combined-source measurement and installation remain open.

## Source-40 integration and later measurements

The ten completed fixes through `c48ef6a7` are integrated into canonical master
by `e8ef1568`, preserving the then-current foreign working changes. The frozen
combined source-40 build succeeds, passes strict signing and headless startup,
and handles all eight original scripted comment actions correctly. It is a
verified private production bundle; no installation or Brave parity is claimed.

The source-40 broad selection runs all 4,189 functions in 1,080 original files
in each GC mode. Default GC passes 4,164 and fails 25; no-GC passes 4,163 and
fails 26. No test bodies are skipped after a panic. All named failures either
belong to the previously reproduced source-28 set or reproduce against the
exact pre-integration working files, with identical test bytes. This includes
the additional no-GC media-error-handler failure. Raw package exits stay
nonzero, and the checkpoint is explicitly not an all-pass claim.

LibJS again passes 233 ordinary files/769 functions plus three separately
launched files/13 functions in each GC mode. The official AST driver matches
100 inputs exactly. All eight SVG mutation guards remain pixel-exact. Seven
default screenshot cases pass; four reference comparisons fail. Those four
rendered document images are decoded-pixel-identical to the pre-integration
production build. The original nonzero screenshot receipt is retained. See
`parity-v40-checkpoint.json`, `parity-v40-preintegration-*-*.json`,
`native-parity-v40-verified.json`, and `parity-v40-baseline-pixels.json` under
the ignored evidence directory.

Further completed changes are committed separately:

| Commit | Change and focused verification in each GC mode |
| --- | --- |
| `b4d926cd` | Keep provider order when an element has both legacy and indexed aliases. The new ordering case fails before the correction; all seven identity cases then pass. |
| `633266ae` | Avoid heap arrays for common scroll-container, position, stacking and inherited selection checks. The allocation case and surrounding attachment, float, containing-block and scroll cases pass. |
| `34482bcd` | Read the already resolved background lists during painting, retaining the raw-property fallback. Live style changes, old recordings, resource replacement and SVG natural dimensions remain covered. |
| `8fff73f9` | Reuse local caret/selection line projections owned by retained independent blocks, including contexts with atomic inlines. Copies rebind their owner index and keep independent caret arrays. Twenty cases in eight files pass. |

The original background fixture supplied only `background-image` to an otherwise
empty raw property set. Its required coordinating longhands were missing. The
corrected fixture supplies all nine longhands and retains both fallback and
live-update assertions; both cases pass in each mode. The original block-caret
fixture used the base layout node's nonexistent index accessor and attempted
to mutate an immutable record field. Its correction uses the styled-node
accessor and an explicit array alias; all original isolation assertions remain.
These fixture repairs add no implementation credit. Failed receipts remain.

A standards-mode diagnostic over the current thread finds 1,731 text nodes:
718 covered by the closed-inline cache and 779 additional text nodes covered
by retained independent blocks. Its 87 block caches explain the additional
caret reuse opportunity. The earlier source-38 private coverage diagnostic
read the older fixture and reported zero block caches; it is not evidence for
the standards-mode benchmark's block coverage.

The source-40/source-42 ABBA sequence uses byte-identical probe code and a
matching normalized scripted fixture, with no GC environment overrides. It
adds process-wide `RUSAGE_INFO_V4.ri_instructions` readings at the existing
native-action-to-returning-`updateLayer` endpoint. Median warm instruction
counts fall from 381,795,150 to 367,158,840, an observed reduction of 14,636,310
(3.83%). Warm elapsed medians are 77.665/76.995 ms before and 76.071/76.776 ms
after, under substantial concurrent host load. The cold actions remain more
variable. This does not establish Brave parity or physical scanout timing.

The repository's current cadence uses cumulative retired-instruction savings.
The observed reduction exceeds its 5,000,000-instruction threshold. The resulting
source-45 broad batch is complete: 1,083 files and 4,196 functions run in each
mode, with 4,170 passing/26 failing under default GC and 4,169 passing/27 failing
under no-GC. No files remain unrun. All earlier named failures persist unchanged;
the additional CSS allocation-budget failure reproduces in the original compiled
source-40 binary, and the additional no-GC native-poster HTTP timeout also
reproduces there. The candidate poster file subsequently passes all five cases
without a code change. Original nonzero receipts remain authoritative.
`parity-v45-checkpoint.json` accepts coverage, explicitly with
`all_tests_passed: false`. LibJS is unchanged and was not rerun in this batch.
All eight SVG guards are exact; all eleven document screenshots match source-40,
including the four existing reference mismatches.

## Lazy projection and passive counters

`0a335ab5` passes resolved incoming counter scopes through unchanged ordinary
flow branches when every retained element has no counter operation or list-item
display. Each DOM owner still receives an independent snapshot, and subsequent
creator ordering matches a full rebuild. An empty-only prototype provided no
meaningful native instruction improvement and is not credited separately.
The first counter fixture needed optional-value unwrapping. A later assertion
exposed an existing counter-only style invalidation limitation: the same assertion
fails on source-45. Its correction triggers the TreeBuilder with an unrelated
preceding child edit and retains the expected counter value; counter-only CSS
invalidation is not claimed fixed.

`76ee6f7d` defers DOM caret-line projections until selection, caret navigation or
another consumer requests them. A constant provider uses the viewport's committed
geometry state, avoiding per-text closures that retain old result records. The
explicit public attachment API remains eager. Old mirrors can still project their
old geometry after a rebuild and collection; live reused mirrors reset to current
geometry. Source-52 passes 111 focused layout cases in fourteen files per mode.
Both DOM visual-line/selection files pass on source-49, whose DOM implementation
is identical. The original layout build failed on a compatibility-compiler array
assignment; an early return fixes it without an extra array clone. All failed
attempts remain retained.

The signed source-52 production build passes signature/startup checks and eight
exact SVG guards. All eleven document screenshots are decoded-pixel-identical to
source-44. The weak probe collects seven superseded paint arenas and retains only
the current one; it does not claim an inventory of every retained geometry chunk.
The source-44/source-52 ABBA sequence observes 363,381,392 versus 359,761,683.5
median warm instructions, a reduction of 3,619,708.5 (about 1%). This remains below
the next broad threshold. Elapsed warm medians vary substantially with host load:
79.860/59.610 ms for the controls and 55.974/65.114 ms for the candidate. A fresh
Brave comparison reports 2.4 ms for handler plus layout and 25 ms through two
animation frames. Endpoint differences remain, and Brave parity is not achieved.
See `parity-v52-instruction-abba.json`, `native-parity-v52-verified.json`,
`parity-v52-document-pixels.json`, and `styled-v52-current-brave.json`.

The scripted app diagnostic confirms retained layout-node identities for 3,113
unchanged DOM elements across toggles. Chromium font policies and standards mode
do not disable the retained inline/block caches. The phase/sample diagnostic
shows repeated selector traversals and containing-block position walks around the
remaining whole-document geometry and paint projections.

`6d7dc085` establishes a matching context once for queries made only of type,
universal, ID, class and attribute compounds. Combinators and pseudo-classes keep
the existing general matcher. Namespace/attribute/case behavior uses the same
simple-selector engine. Fourteen distinct cases in three files pass in each GC
mode: two existing files retain their passing source-55 results and all three new
cases pass after the source-56 shadow fixture correction. The original fixtures
used a nonexistent attribute setter and an XML-created shadow host; failed
receipts remain. The production implementation is byte-identical to source-53.
Its first native observation is 347,903,971 warm instructions, with 64.738 ms warm
median and 245.187 ms cold action; this single run does not establish repeatable
savings or a latency bound. Position-cache work and combined canonical validation
are still in progress. No new application has been installed.


## Source-60 combined verification and the incomplete click path

`b9d0aa07` scopes an ordinal-indexed paint-position cache to committed geometry
projection. It keeps `UsedValues` compact, expires the table before later
geometry changes, and restores nested scopes. Cycles, foreign records and deep
chains keep the iterative fallback. Absolute coordinate travel proves that
regrouping fixed-point additions cannot change saturation behavior. Eighty-eight
cases in ten files pass per mode on source-59. The initial source-57 build fails
on an integer/unsigned capacity expression; the corrected source-59 code is the
only version receiving build credit. Its new test helper is self-contained.
Original missing-file harness attempts and failed build receipts remain.

The source-52/source-53 query-context ABBA sequence observes 357,203,108.5 versus
351,450,678.5 median warm instructions: 5,752,430 fewer (1.61%). This exceeds the
next broad threshold. The source-60 combined snapshot includes all four later
completed fixes (passive counters, lazy DOM lines, independent query contexts and
scoped paint positions), current canonical commits and then-current foreign
working changes. Integration `d8e4fa00` preserves unrelated working files.

Source-60 runs all 4,234 functions in 1,097 original layout/CSS/browser/root files
per mode. Default GC passes 4,209 and fails 25; no-GC passes 4,208 and fails 26.
There are no unrun cases. Every named failure belongs to the source-45 set, with
identical original test bytes. The CSS allocation check and no-GC media handler
case that failed earlier now pass. The raw package exits remain nonzero. All 236
LibJS files pass in both modes: 233 ordinary files/771 functions plus three
separate files/13 functions. The official AST comparison passes all 100 cases
exactly. These are fresh checks: a strictness-metadata optimization and its two
cases differ from the earlier frozen source and prevent carrying old LibJS
results without a rerun. The initial checkpoint attempt rejects that carry;
`parity-v60-checkpoint.json` records the subsequent fresh verification, with
`all_tests_passed: false`.

The signed source-60 bundle passes startup and all eight exact SVG guards. Its
eleven rendered document images are decoded-pixel-identical to source-52;
the four old reference mismatches remain. The first combined native observation
is 345,473,118 median warm instructions and 58.078 ms median elapsed, with one
measured collection on a later action. No application has been installed and
Brave parity remains open.

A sparse invalidation-frontier experiment passes 89 focused cases per mode but
provides no Reddit instruction benefit: its ABBA comparison is 341,128,486.5
versus 341,688,759 warm instructions, 560,272.5 more for the candidate. The entire
experiment (`8243cba3`) is reverted by `17038ad8`. Failed immutable-fixture receipts
remain; repaired DOM cases pass on source-62. The experiment receives no
performance credit and is absent from later candidates.

`efc7e404` skips property-name conversion for empty `will-change` lists.
`caa12b8d` shares the existing per-document parsed-selector cache with CSS-side
queries, keeping live match evaluation separate. Eighty-six focused cases in six
files pass per mode, including three new cache/relational/allocation cases.
Source-63's combined native ABBA observes 343,222,424.5 versus 342,197,383 median
warm instructions, 1,025,041.5 fewer (0.30%): below the next broad threshold.

A later diagnostic reveals an important limitation in all earlier native click
measurements: Reddit changes the comment class, then jQuery throws while reading
`DocumentFragment.childNodes`. The snapshots contain `TypeError: undefined is
not an object (evaluating n.childNodes.length)`. The earlier native success
criteria checked alternating collapsed classes and an unchanged URL; they did
not prove the original handler completed or updated its control label. Their
before/after instruction comparisons cover that same incomplete native path,
and cannot establish successful Brave-equivalent completion. The original
`togglecomment` returns undefined, so `defaultPrevented: false` alone is not a
failure. The compatibility correction is recorded below. Future functional
verification must check completion without click errors and the original
`[–]`/`[+]` labels before making a new Brave comparison.


`4f53c164` supplies native text-node and fragment creation, live child-node lists,
fragment insertion, and content-cache invalidation used by the original jQuery
handler. Source-67 passes 16 focused cases in eight original files per GC mode.
The actual nine-script replay completes four alternating toggles with the
original labels and no click errors. The native windowed completion probe
verifies eight correct labels and eight empty dispatch error logs; its extra
snapshot I/O is diagnostic and receives no performance credit. Signed startup
and all eight SVG mutation guards pass. All eleven document captures are
pixel-identical to source-60; the same four reference failures remain.

A separate unmodified-instruction-probe run (`styled-v67-complete-baseline`)
uses the now-complete original handler: seven warm actions have a 51.248 ms
median and 367,024,968 median retired instructions. The first action is
105.416 ms. A fresh Brave run on the same normalized fixture verifies six
original alternating labels, unchanged URL, and no click errors. It observes
1.75 ms median handler plus forced layout and 24.25 ms to two animation frames.
The normalized fixture hash remains
`1f1c35438904efa1d791fb5b0736b3b8e9f431a0f6571b38228d6142faf4b681`.
Native completion returns from `updateLayer`; Brave uses two animation frames,
so these are different endpoints and do not establish physical presentation
parity. Earlier incomplete-handler instruction reductions are not used as a
before/after comparison with this new complete workload. No app is installed.
