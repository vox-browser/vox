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
