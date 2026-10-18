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
