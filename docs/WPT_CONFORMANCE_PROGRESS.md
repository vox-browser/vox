# Imported WPT conformance follow-up, 2026-11-08

**Scope correction:** every historical "full run" or "full-suite" reference in
this report means the complete **Ladybird-imported expectation cohort**, not
the full upstream Web Platform Tests repository. The runner selects 3,808
imported testharness cases and uses a static HTTP server without WPT's Python
handlers, HTTPS, or multi-origin configuration. Its rates cannot establish
full upstream WPT conformance. The [upstream suite audit](WPT_UPSTREAM_SUITE.md)
records the complete checkout, manifest counts, and blocked execution attempts.

**The suite still fails.** r14 reports **153,046 / 170,027
passing subtests (90.0%)**, with 1,920 of 3,808 files fully passing.
There are 16,981 reported non-passing subtests and 71 files without results.
The higher percentage is not an all-pass result or evidence of a 90% stable-denominator milestone.

The [full-run manifest](performance/wpt-r14-20261108.json) records every file's counts,
build identity, guard exit, comparison arithmetic, failure examples and local raw-evidence archive.
The [focused-check manifest](performance/wpt-fixes-20261108.json) preserves source checks,
development failures, and the separate Range diagnostic.

## Further fixes and focused measurements

The later [follow-up manifest](performance/wpt-followup-20261108.json) records the
additional checks and their exact executable identities. These focused results do
not replace r14 or establish a new full-suite percentage.

- The completed `fa3b82a3b41d…` production bundle passes all 315 font-valid and
  all 130 SVG animated-length initial-value subtests.
- A subsequent completed bundle, `692d893aa761…`, runs the **complete,
  unpartitioned Range-insertNode page: 1,840 / 1,840 PASS**, harness OK. The
  document takes 16.55 seconds to report, with the existing 60-second WPT
  deadline and 4 GiB browser cap. The enclosing 12 GiB guard exits 0 and observes
  3,445,030,912 bytes peak aggregate RSS. This closes the original combined-page
  reporting failure for this pinned build and runner protocol.
- The same bundle reports **304 / 307 PASS** for processing-instruction parsing,
  up from 108 / 307 in the earlier focused check. Its three failures all expose
  an erroneous `data` property on ordinary elements.
- `svg/idlharness.window` remains **1,027 / 1,780 PASS** in that bundle, which
  predates the newly implemented SVG angle and marker-orientation bindings.
- Range-mutations-dataChange still reports NO_HARNESS in this bundle. Its
  synchronous inline work can prevent even an immediately sent asynchronous
  announcement from reaching the server before the startup deadline.

The reporter now sends its harness announcement when it executes, instead of
waiting for a 500 ms timer. Announcements carry the document path and query;
late announcements from a previous navigation cannot start the next document's
harness clock. The original assertion statuses, fixture bytes, harness deadlines,
and memory caps are preserved. The protocol change affects which results can be
collected, so it must accompany any comparison with r14. A synchronous-XHR
announcement experiment failed the warm-up and was reverted; its failure is
retained in the follow-up evidence.

The browser's disk cache already rejects `no-store`, but navigation preloads also
reuse a memory map of the previous page's rendering inputs. That separate path
must reject `no-store` before passing a response to a new navigation. The current
source fix and its loopback-server regression check address that reuse.

Additional source fixes implement real SVG angle conversion and marker
orientation, receiver checks on SVG value factories, temporary-text retirement
for iframe replay, and interface-specific placement and conversion of `data`.
Their focused source checks are separate from the production-bundle results
above. **All 11 focused native regressions pass with `-prealloc -gc none`**, under
a 3 GiB runtime guard. Repeating the same checks with shared node properties
disabled also passes all 11. All 12 reporter unit tests pass. Implementation and
test input hashes remain unchanged across the final checks.

| Follow-up fix | Commit(s) |
|---|---|
| HTML processing-instruction tokens, placement and storage lifetime | `4b8d61ce0` |
| SVG angles, marker orientation and SVG receiver checks | `39e6060cf`, `05d9c7808` |
| Immediate, document-identified harness announcements | `4f6cb2793` |
| Retire iframe replay's temporary text; preserve queued console output | `a1598d082` |
| Limit character-data properties and reflect HTML object URLs | `33e80e114` |
| Refetch previous-page `no-store` resources on navigation | `17b743462` |

At the end of that follow-up, the completed bundle still predated those source
fixes. The subsequent measurements below exercise them in newer bundles.

## Trusted Types integration and newer production checks

The [Trusted Types follow-up manifest](performance/wpt-trusted-types-20261108.json)
records four further fixes, source checks, both production attempts, and the
remaining failures. **100% conformance has not been reached.**

| Fix | Commit |
|---|---|
| Report concrete event-handler sink names to default policies and CSP | `56572251c` |
| Preserve original JavaScript callback exception values through host transports | `334e5f9cc` |
| Share JavaScript policies with the native owning Window factory; preserve callback conversion, mutations and retired-realm safety | `489d0ff01` |
| Enforce `setAttribute` and `setAttributeNS` synchronously, preserving genuine trusted values | `0ebd0d881` |

All 14 Trusted Types model tests pass in both allocator modes. Native host tests
preserve nine thrown values through three transports (27 combinations), also in
both modes. All 23 integration tests pass with ordinary allocation and production
`-prealloc -gc none`; the latter also passes with shared node properties disabled.
These cover policy sharing, CSP restrictions, original exceptions, callback
lifetimes, typed attributes, namespaces, receiver checks, custom-element reactions,
canvas sizing, and existing SVG/attribute-map behavior. The final focused input
hashes remain unchanged across those checks.

Two fresh production attempts, using `d17cb11af747…` and `843893a4a6f9…`, produce
the same assertion counts over 60 files:

| Group | r14 PASS / reported | New focused PASS / reported |
|---|---:|---:|
| Font shorthand validity | 271 / 315 | **315 / 315** |
| Processing-instruction parsing | 108 / 307 | **307 / 307** |
| SVG animated-length initial values | 124 / 130 | **130 / 130** |
| SVG IDL | 1,027 / 1,780 | 1,093 / 1,780 |
| Trusted Types, 56 files | 690 / 1,446 | 728 / 1,447 |

That cohort gains 353 reported passes, with one additional reported subtest.
It does not establish a new overall pass rate. Both attempts retain an iframe
navigation crash (`block-string-assignment-to-HTMLIFrameElement-srcdoc`) and the
`script-enforcement-001` harness timeout. Each uses a 3 GiB aggregate guard,
2 GiB browser cap, unchanged runner deadlines, fresh processes, and executable
and native-library identity checks. The guard and collection commands exit 0;
that does not mean the assertions pass.

Both measured bundles contain the first policy bridge. The later bundle also
contains its persistent callback lifetime guard. Neither contains `0ebd0d881`'s
typed, synchronous attribute transport, so that fix still needs production WPT
validation. The shared production worker has its build request; no duplicate
build was queued. A new full-suite result remains pending. Raw evidence is local
at `/Users/alex/.cache/vox/wpt/20261108-trusted-types.tar.gz`, with its hash and
per-attempt failures in the manifest.

## Native token-list bindings and additional source checks

The [token-list verification manifest](performance/wpt-token-lists-20261108.json)
records the next fixes and all development attempts. These are source checks;
they do not establish a new overall WPT percentage.

| Fix | Commit |
|---|---|
| Trusted Types argument counts, accessor names, and native Window receiver/factory lookup across iframe realms | `7ef5b8d9c` |
| Validate every token before mutating a DOMTokenList ordered set | `43d0cdcd8` |
| Destroy native test documents before releasing storage, removing queued load tasks | `2cd4bd68d` |
| Bind token lists and reflected token attributes to native DOM algorithms | `7a4904ebc` |

The new bindings cover `classList`, `part`, `relList`, iframe `sandbox`, output
`htmlFor`, and link `sizes`. Lists retain identity and read current attributes;
invalid token mutations leave their ordered sets unchanged. Iteration uses the
[specified Array intrinsics](https://webidl.spec.whatwg.org/#es-iterable).
Forwarded assignments consult the public getter, preserve the original value,
and follow the [Web IDL setter steps](https://webidl.spec.whatwg.org/#dfn-attribute-setter).

**All 40 final focused integration tests pass in both allocator modes**, and
the production-allocation binary also passes with shared node properties disabled.
They include all 175 token-attribute/namespace combinations from the existing
coverage table, plus live mutation, indexed/prototype lookup, iteration, receiver
checks, forwarding, mutation observers, and custom-element reactions. The two
native ordered-set validation regressions also pass. The final binaries and listed
source inputs retain their recorded hashes throughout the checks.

An additional existing SVG rendering test remains failing: it expects two gradient
path commands and observes zero. An isolated control with the legacy class-list
bootstrap reproduces that assertion; its other two tests pass. The assertion was
not relaxed, and its results remain separate from the passing binding checks.
Concurrent renderer edits limit attribution; no pixel-conformance claim is made.

The available production bundle remains `843893a4a6f9…`, which predates these
changes. The shared worker has the current build request; its recent attempts
reject source inputs that change before C preprocessing. Production WPT, pixel
validation, and a new full run remain pending. **100% conformance is still open.**
The manifest links three verified local evidence archives; completed job outputs
and the temporary combined test source have been removed from `Build/` and the
canonical source tree.

## Full run and comparison

| Cohort | Executions / distinct files | Passing / reported subtests | Reported pass rate |
|---|---:|---:|---:|
| r13 retained raw results | 3,810 / 3,808 | 155,284 / 175,472 | 88.5% |
| r14 | 3,808 / 3,808 | 153,046 / 170,027 | 90.0% |

r14 has **2,238 fewer passing subtests and 5,445 fewer reported subtests**.
The saved r13 file repeats `custom-elements/upgrading/Node-cloneNode` and
`custom-elements/upgrading/upgrading-parser-created-element`. Both repeated results are identical;
the extra executions contribute 15 subtests, including 14 passes. Raw r13 totals above retain them.
Both cohorts cover the same 3,808 distinct file IDs.

Matching exact file IDs and subtest names, and collapsing only identical duplicate r13 results:

- 167,667 subtest names appear in both runs: passes rise from 149,452 to 151,465.
- 2,309 change to PASS and 296 change from PASS: a net gain of 2,013 in that common set.
- 7,790 r13 names are absent from r14, including 5,818 previously passing names.
- 2,360 names are newly reported, including 1,581 passes.

These categories account exactly for the raw count changes. Conditional or dynamically named
subtests can move between the newly reported and missing sets; the manifest retains per-file data.
Brave's historical 94.5% used another reported denominator and is not a matched current comparison.
The old [47.5% comparison](WPT_BRAVE_COMPARISON.md) remains a historical baseline.

Largest losses of previously reported PASS names:

| File | Previously passing names now absent | r14 outcome |
|---|---:|---|
| `dom/ranges/Range-mutations-dataChange` | 2748 | NO_HARNESS |
| `html/the-xhtml-syntax/parsing-xhtml-documents/xhtml-mathml-dtd-entity-8` | 2125 | MEMORY_LIMIT |
| `css/css-masking/animations/clip-interpolation` | 324 | CRASH |
| `css/css-transitions/animations/text-shadow-interpolation` | 146 | CRASH |
| `css/css-break/animation/orphans-interpolation` | 110 | CRASH |
| `css/css-tables/animations/border-spacing-interpolation` | 110 | CRASH |

## Execution conditions

- Imported WPT checkout: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`; fixture worktree clean at the end.
- Vox executable: `c6b62c77913a18117f269fda73097c703b64e3d789b1ffe607f07c3f09efae95`; receipt input head
  `a440e507b082bdff46b98ecec6ab714428d40b4f`, dirty source inputs, single C unit.
- The executable and native-library hashes remained unchanged; no run abort occurred.
- One serialized Vox-only pass, chunks of 100, fresh profiles per launch, 1024×768 window.
  r13 used six shards and chunks of 50, so ordering and cross-navigation state differ.
- Existing runner deadlines and default 4 GiB browser cap; 12 GiB process-tree guard.
  Runner and guard exited 0; the guard observed 4,595,810,304 bytes peak aggregate RSS.
  A successful collection command does not mean its WPT assertions passed.
- 18 CPUs; load averages [10.64, 12.82, 14.23] → [175.11, 134.41, 81.99].
  This substantial contention limits interpretation of deadline outcomes; no timing improvement is claimed.
- Harness: 3,568 OK, 40 ERROR, 129 TIMEOUT. Non-reporting outcomes: 51 NO_HARNESS,
  15 CRASH, 5 MEMORY_LIMIT. NO_HARNESS is a missing signal before the deadline, not proof that
  scripts never ran. Exact per-process browser return codes are not retained by this runner.
- The static server still lacks Python WPT handlers and full HTTPS/multi-origin capabilities.

## Implemented and committed fixes

| Change | Commit(s) | Validation |
|---|---|---|
| Accept `/normal` line heights and `oblique` without an angle in font shorthands | `a440e507b` | Focused parser checks pass; r14 `font-valid` improves 136→271 of 315 |
| Reflect and inherit `writingSuggestions`, with DOMString conversion | `ae4779e64` | Focused source check passes; all 80 WPT subtests pass in the pinned bundle |
| Preserve font-family identifier boundaries through serialization, equality, invalidation and computed-style reuse | `ab26c1688`, `3c283dbe9`, `0d1e9ea79` | Focused checks pass with current V and production `-prealloc -gc none`; later than r14's bundle |
| Preserve zero-percentage SVG gradient defaults | `da726f979` | Focused source check passes; targets the six remaining default-unit failures in the bundle's 124/130 result |
| Own the default animation timeline cache in its document | `dd1cf9253` | Old allocator regression fails; fixed allocator test passes across 12 document-storage lifetimes |
| Give animation replacement tests an active navigable | `3b20d2001` | All seven existing Animatable tests pass, with additional finished-state assertions |

All seven final required source checks pass. At the end of the original r14 collection, the canonical build queue had not yet published a
bundle containing the later font-family, SVG-default and animation-cache fixes. Those fixes were
not counted as measured r14 gains. The subsequent focused results above use later bundles. The build receipts show repeated input-change failures during
shared development; this session reused the latest completed bundle following the shared-build policy.

## Original r14 Range diagnostic

The complete `Range-insertNode` page still records NO_HARNESS in r14. A separate run with a
30-second signal deadline reaches the diagnostic 2 GiB browser cap before reporting.

Using the test's existing `?subtest=i,j` option, a separate run executes all 920 distinct scenarios
from the retained r13 names. **All 1,840 / 1,840 subtests pass**, with 920 harness-OK reports,
19 fresh launches, no crashes, and no memory-limit outcomes. The 3 GiB guard and runner both
exit 0; observed peak RSS is 1,508,114,432 bytes. This diagnostic separates scenarios into
navigations and is not a replacement result for the original combined page. It is excluded from
r14's aggregate totals. The later combined-page result above supersedes that diagnostic's open reporting outcome.

## Remaining reported failures

Largest non-passing subtest groups in r14:

| File | Passing / reported |
|---|---:|
| `webaudio/idlharness.https.window` | 12 / 1163 |
| `svg/idlharness.window` | 1027 / 1780 |
| `css/css-typed-om/idlharness` | 27 / 545 |
| `trusted-types/set-attributes-mutations-in-callback.tentative` | 0 / 248 |
| `speech-api/idlharness.https.window` | 11 / 250 |
| `css/cssom-view/idlharness` | 190 / 400 |
| `html/syntax/parsing/parse-processing-instruction.tentative` | 108 / 307 |
| `html/semantics/embedded-content/the-img-element/naturalWidth-naturalHeight-width-height.tentative` | 30 / 228 |
| `trusted-types/set-attributes-require-trusted-types-default-policy` | 82 / 264 |
| `css/css-flexbox/abspos/position-absolute-013` | 252 / 432 |

Unimplemented APIs, rendering differences, crashes, missing reports and runner limitations
still prevent an all-tests-pass result. Expectations, assertions and tolerances were not weakened.
Raw full-run data and baseline records are preserved in `/Users/alex/.cache/vox/wpt/20261108-r14-full.tar.gz`
(SHA-256 `4da67d256f14cd6c19b3e7034f916f4a9f02013d9eabd2c5d4b50c4e7baaf374`); focused archives are listed in their manifest. Archives stay local;
completed job directories are removed from `Build/`.

## November 8 imported cohort: 6,828 cases, collection complete

**100% has not been reached.** The [final r15 record](performance/wpt-larger-r15-final-20261108.json)
covers all 6,828 cases selected from Ladybird
`2919bf87a5e5dfc49a210a70bda079afa411c6c5`. It reports **239,015 / 310,935
subtests passing (76.87%)**: 70,623 FAIL, 316 TIMEOUT, 971 NOTRUN, and ten
PRECONDITION_FAILED. Only 2,141 cases have every subtest passing. There are
30 crashes, four browser-memory-limit outcomes, nine hard timeouts, 65 missing
harnesses, and three documents never requested. Of 6,717 completed reports,
6,124 have harness OK, 510 TIMEOUT and 83 ERROR. The all-pass gate fails.

The executable was the shared `b8c5285a1947…` bundle, which predates the source
fixes below. Fresh processes ran 50-case chunks with unchanged deadlines and a
4 GiB per-browser cap. Input verification reports no changed executable,
native libraries or fixture files. The [earlier snapshot](performance/wpt-larger-r15-progress-20261108.json)
is retained as historical partial evidence; its running status is superseded here.

Aggregate supervision is incomplete: the original 12 GiB guard and completion
observer disappeared before collection ended. A replacement adoption guard
also left no final receipt. Exact interruption times and runner/guard exit codes
are unknown. The final rows and identities remain useful diagnostic evidence;
this is not a fully supervised acceptance run. No unobserved exit is reported
as passing. Raw results, logs and empty supervision receipts are archived at
`/Users/alex/.cache/vox/wpt/20261108-r15-0940-b8c5285a.tar.gz`
(SHA-256 `58ff39eb0a775a392af8a4393bf5ac66a95bd111a2f04730b6d0e2f56d415dcf`).
The results hash was checked after archiving, and completed Build scratch was removed.

This remains the imported testharness subset. Static HTTP lacks Python handlers,
real HTTPS and WPT's multi-origin setup; it is not full upstream WPT or directly
comparable with r13/r14's smaller denominator. The fixture cache contains 15,399
hashed files. The `--require-all-pass` gate rejects missing or duplicate cases,
empty reports, harness failures and any non-PASS subtest.

| Source fix | Commit | Focused validation |
|---|---|---|
| Pipe `Blob.textStream()` through a fresh native UTF-8 decoder and stream | `f3c82806a` | Eight data scenarios, native stream identity, receiver and metadata checks |
| Update the remaining native Blob assertion after the shared UTF-8 text fix | `19dacc90f` | All seven current native Blob checks pass with production allocation |
| Notify input models after synchronous typed attribute writes, preserving old type state and namespaces | `f418f5b48` | Existing input-value regressions plus one-write/one-mutation checks |
| Bind `input.files` to native FileList owners and synchronize pending detached-element state | `073100a83` | Assignment identity, nullable/invalid inputs, fake paths, insertion and clearing |

The [Blob evidence](performance/wpt-blob-text-stream-20261108.json) preserves the
initial checks, two legacy assertion failures during concurrent UTF-8 source
changes, and the later seven-test passing run. The
[input evidence](performance/wpt-input-files-20261108.json) retains development
failures and the final **10 / 10 passing production-allocation checks**, including
the existing Trusted Types regressions. All run under 3 GiB runtime guards.
Final normal-allocation compilation remains pending: one attempt failed to
link `_v_brotli_unpoison_noop`; a pinned compiler attempt found an undefined
`visual_changed` in the shared UI2 dependency. Neither attempt counts as passing.

The older baseline cannot validate these source changes. Focused production
WPT and the SVG paint-server/same-size image-mutation pixel checks require a
newer completed shared bundle; no duplicate production build was queued.
The next large failure group under investigation is the imported test driver's
missing `internals.sendText()` call (9,340 failed subtests in this baseline).
Providing it enables native keyboard execution; it does not establish that all
those subtests will pass.

## Focused follow-up on the newer shared bundle

The completed `3feee902668f…` production bundle contains the native Blob,
input-files, typed-attribute and Element.remove changes, verified against its
parsed-source manifest. [Focused imported WPT checks](performance/wpt-blob-input-remove-followup-20261108.json)
pass all **174 / 174 Blob subtests** in three cases, plus the removal-unscopable
case. Across the two focused runs, 203 subtests pass and one fails:
`DataTransfer.files` does not preserve the FileList identity expected by the
input-files assignment case. Both runs retain unchanged input identities and
successful aggregate guard completion; the second runner exits 1 as required.
This is a small selected cohort, not an updated full-cohort percentage.

All [seven SVG bridge pixel regressions](performance/wpt-svg-bridge-followup-20261108.json)
pass exactly, with zero differing pixels: same-size image source replacement,
hidden inherited paint-server style changes, SVG/HTML ID collisions, gradient
stop offset/moveBefore changes, and pattern attribute updates. These use fresh
processes and the same pinned completed bundle under the publication lease.
Later beforeinput/StaticRange source changes still require their own validation.

## Native keyboard and input-event range follow-up

The imported driver's `internals.sendText()` now enters the actual Page keyboard
path. Follow-up source fixes dispatch cancellable native `beforeinput` before
text insertion, deletion and Return; keyup uses current focus and drops inactive
or repeated releases. Home/End navigation canonicalizes element-boundary
contenteditable carets. Native StaticRange snapshots and InputEvent target-range
sequences preserve node identity, immutable offsets, receiver checks and iterator
closing. These changes are committed as `e73e02f1b` and `70be0a1c7`.

The [native evidence](performance/wpt-native-keyboard-ranges-20261108.json)
records **20 passing production-allocation regressions before the final shared
AbstractRange getter change**. That last getter change and its added prototype
assertion remain unexecuted: subsequent compiles fail in generated-C optional
function-pointer declarations, including an uncached attempt. A compiler matched
to the shared current V checkout also encounters in-progress CSS/IndexedDB
errors. The standalone three-test InputEvent file did not compile. Two Page
compilations reached the unchanged 12 GiB cap; none of these failed attempts are
counted as passing. All attempts and the exact source-hash difference after the
passing snapshot are retained in the evidence.

[Element.remove's four focused regressions](performance/wpt-element-remove-20261108.json)
pass against unchanged source. Newer production WPT and pixel validation for the
keyboard/range changes remain pending on a bundle that contains them. The
completed larger cohort's 76.87% remains a baseline for its older executable.
The DataTransfer FileList identity failure, other browser gaps, full-upstream
runner integration and the final compiler blockers remain open; this work does
not establish 100% for either the imported cohort or full upstream WPT.

## Live DataTransfer files and completed native validation

`DataTransfer.files` now returns one live native FileList per transfer. Saved
lists observe item additions, removals, store-mode changes and disassociation;
surviving File objects retain their identity. The internal fresh-snapshot API
remains available. `DataTransferItemList.clear()` now removes files as well as
strings and disables retained item owners, while `DataTransfer.clearData()`
keeps its string-only behavior. Commits `9255ef7c2` and `f4834eb63` include the
implementation and focused regressions.

[Native verification](performance/wpt-live-filelist-native-20261108.json) passes
**44 distinct production-allocation checks**: eight FileList, two live HTML
model, 13 native binding/InputEvent, and 21 compact keyboard/range/input-files
checks. The eight FileList and 13 binding checks also pass with normal Boehm
allocation. This executes the final shared AbstractRange getter assertion and
all three existing InputEvent tests, superseding their earlier pending status.
The initial clear failure and the concurrent raster/CSS/UI2 compilation failures
remain archived. After the shared UI2 integration refresh, the final 21-case
compact suite passes with the unchanged 3 GiB runtime guard.

[Production WPT follow-up](performance/wpt-live-files-production-20261108.json)
on the pinned completed `c7079cad06a2…` bundle passes the input-files case
**24 / 24**, confirming the FileList identity correction. Blob cases pass
174 / 174. The selected editing variant advances from 76 missing-sendText
failures to **12 PASS / 64 FAIL**, exposing actual whitespace-preservation
failures. `Range-insertNode` again reaches a hard timeout without a subtest
report. Across these same six selected cases, reported passes increase from
163 to 210 out of 274, a gain of 47 that includes several earlier fixes.
The archived r15 aggregate supervision gap still qualifies that old comparison.
This is neither a new full-cohort percentage nor an all-pass result: the new
run's gate exits 1, all six cases remain included, and the unchanged Range
reporting failure is explicit.

The bundle manifest contains the live-list/getter and final keyboard/range
changes, but predates the later `items.clear()` correction. That correction is
verified by native model and compact tests; production WPT coverage still needs
a later completed bundle. No duplicate production build was queued.
All [seven SVG bridge reftests](performance/wpt-live-files-svg-20261108.json)
remain pixel-exact on this bundle, including same-size image replacement and
paint-server mutations.

A separate, explicitly profiled Range diagnostic retains the original fixture
and deadlines. The five-second sample places the main thread in a load-event
JavaScript callback, with JSC property access/enumeration among hot leaves.
Unknown JIT frames prevent assigning the exact bridge function. It supplies
no optimization or all-pass credit. Raw results, samples, guards and failed
attempts are preserved in the external archives named by the three manifests;
completed Build scratch is removed. Range timeouts, the remaining editing
failures, other browser gaps and full-upstream runner integration remain open.

## Whitespace-aware paragraph joins and qualified attribute updates

The newer Ladybird paragraph-join behavior is translated in `29feaceb9`.
Joining blocks now records resolved whitespace independently of formatting
commands, preserves styles inherited from classes, and moves only the first
line of the right paragraph. Preserved newlines and nested `<br>` elements
split inline formatting without losing UTF-16 boundaries. Default `<pre>`
styling remains distinct from author styles.

`44732b1d3` refreshes retained element and Attr wrappers after native keyboard
editing through the existing execCommand mutation-refresh path. Without this
refresh, the native diagnostic reached 52 PASS / 24 FAIL because a styled
`<b>` still exposed its old cached attributes. The selected variant now passes
76 / 76. Expanded validation also exposed three namespace-owner regressions:
public `setAttribute()` incorrectly selected a null-namespace attribute instead
of the first qualified-name match. `c8a3a2b15` fixes that lookup while preserving
attribute order, namespace, prefix and identity; all three regressions pass.

The [native verification manifest](performance/wpt-paragraph-joining-20261108.json)
records **all 60 declared variants of
`editing/other/join-different-white-space-style-paragraphs`: 3,456 / 3,456 PASS**.
Each variant runs in a fresh process with the unchanged imported test script,
assertions and official harness, the original timeout, and an exact expected
count derived from the test declarations and skip predicates. Every harness
and process exit is clean; executable and fixture hashes remain unchanged.
All three input methods and all five whitespace modes are covered. These are
direct native Page checks, not production browser navigation or a new full
cohort measurement.

**34 distinct focused regressions also pass**: 19 compact keyboard, range,
file, activation, identity and namespace cases; two qualified-name DOM cases;
and 13 editing/undo/paste/whitespace cases. The latter pass with normal GC
after all fixes and also passed with production allocation before the final
qualified-name setter correction. Failed compiler, runner and regression
attempts remain in the external evidence archive; no failures are excluded
from an acceptance cohort.

The completed `59de419d75f2…` bundle contains the paragraph translation but
predates the keyboard refresh and qualified-name setter fix. Later shared
production attempts fail in FastC while parsing the generic `T` parameter of
`adblock/json_transport.v::encode_transport_json`; the successful focused
checks use the C backend. Commit hooks use the existing coalescing build queue;
no separate browser build was launched. Production WPT and seven SVG pixel
checks therefore remain pending on a bundle containing both fixes. This work
does not establish 100% for the larger imported cohort or full upstream WPT;
the Range reporting timeout and other browser failures remain open.


## Production Range and paragraph checks pass after lazy content invalidation

`5b3b51613` replaces whole-document content-cache cleanup after native edits
with an epoch. An element retires stale clean content when it is next read or
replayed. Pending author writes and native canvas fallback content remain
preserved. `89f3350e8` also corrects focused file filtering so a bare imported
file name includes its query variants; the full cohort inventory is unchanged.

The [verification manifest](performance/wpt-range-cache-20261108.json) records
**61 production WPT cases, 5,296 / 5,296 assertions PASS**, all harnesses OK:
`Range-insertNode` passes **1,840 / 1,840**, and all 60 paragraph-join variants
pass **3,456 / 3,456**. The unchanged Range page finishes in about 9.2 seconds.
The completed C-backend executable is `91be2b76025a…`, now published at the
canonical bundle location. Its sealed source manifest contains the lazy cache,
paragraph translation, keyboard wrapper refresh and qualified-attribute fix.
This closes their previously pending production validation on those selected
cases. All seven SVG bridge reftests remain pixel-exact, with no reference or
tolerance changes.

The old `59de419d75f2…` bundle still times out on Range under the same documented
WPT defaults: 4 GiB per browser and 12 GiB aggregate, unchanged harness and
60-second timeout plus 10-second reporting grace. An earlier attempt using
2.5 / 3 GiB hits the browser memory cap on the new build and remains archived;
it has not passed that tighter budget. Native unit checks retain their 3 GiB
guard. The two production builds include other changes, so this comparison
does not isolate a performance gain attributable to one fix.

All 25 distinct focused regressions pass with normal allocation; 19 also pass
with production allocation. All 60 paragraph variants additionally pass in
fresh direct native Page processes. The unsuccessful native Range adapter
attempts are retained without pass credit; production navigation supplies the
Range result above. Runner, guard, fixture and executable identities are clean
for the passing production checks. Raw evidence and failed attempts are
archived externally as recorded in the manifest, and completed job scratch is
removed. **100% for the larger imported cohort and full upstream WPT remains
unachieved; these results do not establish a new full-suite percentage.**


## Larger imported r16 scheduled with upstream server coverage

The [r16 plan and preflight](performance/wpt-larger-r16-plan-20261108.json)
retain an additional production preflight using the real upstream WPT server:
three cases, **1,859 / 1,859 PASS**, all harnesses OK, runner and guard exits 0,
unchanged inputs. They cover Blob text, the complete Range page and fetch
form data. This verifies the server path before the complete imported sweep.

A detached supervisor is scheduled to run **all 6,828 imported cases without
path filters** after the already running broad validation jobs finish. It
then selects the latest published production bundle, verifies that the required
fixes are in its sealed source manifest, and holds its read lease through the
actual guard completion. Browser and aggregate budgets remain 4 / 12 GiB;
harness deadlines and strict all-pass checks remain unchanged. Tool and browser
identities are monitored, and actual runner and guard exits will be recorded.
The durable status and completion paths are in the manifest. No complete r16
result or full-cohort percentage is available at this recording.

Unlike r15's static server, this run uses upstream Python handlers, stash,
substitutions, localhost aliases and HTTP/HTTPS services with a private CA.
WebSocket services remain unavailable. This server change prevents treating
r16 as a matched regression or performance comparison to r15. The selected
6,828 cases are still Ladybird's imported testharness subset, not the full
132,460-variant upstream inventory. Full upstream execution and 100% passing
remain unfinished.


r16 started at `2026-11-08T16:01:38+0300` after the existing jobs exited.
It selected the newer published executable `f26b41bdc7345c07…`,
whose sealed source manifest matches all six required implementation files.
The detached observer and aggregate guard are active. This is an in-progress
collection, with no complete result or all-pass claim; the independent preflight
above remains attributed to its original `91be2b76025a…` executable.


## IndexedDB keys, key ranges and ordered key/count queries

Three further fixes are committed: `f6d912b04` separates key conversion from
structured clone; `edbbebca2` exposes native `IDBKeyRange` in Window and Worker
realms; `7f9fa5e21` adds ordered object-store `getKey()` and index `count()`
requests. Key conversion now reads indexed own array properties and engine
Date/buffer slots, accepts repeated array children, rejects cycles with
`DataError`, preserves original getter exceptions and binary view slices, and
leaves author buffers transferable. Key ranges retain native bounds and accept
range queries without converting the range object into a stored value.

The [focused verification manifest](performance/wpt-indexeddb-key-ranges-20261108.json)
records **eight original imported WPT pages, 53 / 53 assertions PASS**, all
harnesses OK, in fresh direct native Page processes with the real upstream
server. The original `getKey()` page passes 17 / 17; key-range construction,
binary comparisons, cursor advance/continue, bounded index directions and
reverse cursors supply the other 36 assertions. Fixtures, assertions and
harness deadlines are unchanged. These are native Page checks, not production
browser results or a new full-cohort percentage.

All **44 distinct focused regressions pass with production allocation**:
32 binding checks and 12 typed model checks. The 12 model checks and all 12
new binding checks additionally pass with normal allocation. Coverage includes
receiver validation, source/transaction identity, explicit commit, deleted-source
error ordering, stable request values and actual Worker task dispatch. Final
compiler and runtime guards complete with exit 0; source, executable, fixture
and server identities remain unchanged. The raw archive retains the earlier
36-assertion run as well as the final 53-assertion run. Completed test scratch
and temporary canonical test files are removed after archival verification.

r16 continues on its pinned earlier `f26b41bdc734…` production image, which
contains none of these three new fixes. A single coalesced C-backend production
build is requested because no available production bundle contains them. A
detached focused observer will check the eight pages against that completed
image in place under its artifact read lease, preserving r16's bundle. Its
durable status/completion paths are recorded in the manifest. Production
validation is pending at this recording. Missing batch retrieval APIs, storage
clone types and the other larger-suite failures remain open; **100% has not
been reached**.


## IndexedDB batch retrieval and fixed typed-array storage

`6a385d1c7` exposes queued `getAll()`, `getAllKeys()` and `getAllRecords()` on
object stores and indexes, including native `IDBRecord` snapshots, count and
direction options, request identity and explicit commit ordering. Window and
Worker bindings share the implementation. `0a4708c60` adds fixed typed-array
and DataView storage: constructor, complete backing bytes, offset and length
survive retrieval, while author metadata getters are ignored and snapshots
remain independent of later mutations. Shared/cyclic records and resizable
view backing buffers remain unsupported.

The [local focused manifest](/Users/alex/.cache/vox/wpt/20261108-idb-batch-values-summary.json)
records **ten original WPT pages, 174 / 174 assertions PASS**, every harness OK,
in fresh direct native Page processes with upstream wptserve. Large-value,
options, index request-source and query-exception-order cases all pass. Several
older pages stopped at the missing key-range constructor and reported fewer
assertions; the new checks require the full original expectation counts.
Fixtures, assertions and harness deadlines are unchanged. This remains a
native Page result, not a production browser or full-cohort percentage.

All **55 distinct focused regressions pass in both normal and production
allocation**: 39 binding and 16 typed model functions. The source, executable,
fixture and server hashes remain stable during the passing checks. Failed
compiler attempts and two premature runtime launches that executed no tests
are retained in the external archive. Heavy shared host load is also recorded;
no performance improvement is inferred from these runs. Completed owned job
scratch and temporary canonical test files are removed after archive verification.

The earlier eight-page production observer executed no tests: its completed
candidate had already been superseded before it could pin the artifact. Its
failure record and archive are preserved. A replacement observer searches the
latest published bundle and completed build receipts, validates all 13 required
source hashes, and checks the original artifact in place under its read lease.
It selects **18 pages with 227 expected assertions**, covering both the earlier
key/range fixes and this batch, and records actual guard/runner exits. Its
status/completion paths are in the manifest; production validation remains
pending at this recording. r16 continues on its original pinned earlier build,
which lacks these newer fixes. **100% for the larger set and full upstream WPT
has not been reached.**


The complete selected-page counts are retained here because new performance
JSON dumps remain local under the repository ignore policy:

| Original imported WPT page | Native Page PASS / reported |
| --- | ---: |
| `IndexedDB/idbindex-query-exception-order.any` | 12 / 12 |
| `IndexedDB/idbindex-request-source.any` | 7 / 7 |
| `IndexedDB/idbindex_getAll.any` | 19 / 19 |
| `IndexedDB/idbindex_getAllKeys.any` | 18 / 18 |
| `IndexedDB/idbindex_getAllRecords.any` | 25 / 25 |
| `IndexedDB/idbobjectstore-query-exception-order.any` | 12 / 12 |
| `IndexedDB/idbobjectstore_getAll-options.any` | 24 / 24 |
| `IndexedDB/idbobjectstore_getAll.any` | 18 / 18 |
| `IndexedDB/idbobjectstore_getAllKeys-options.any` | 23 / 23 |
| `IndexedDB/idbobjectstore_getAllKeys.any` | 16 / 16 |

Raw focused evidence archive:
`/Users/alex/.cache/vox/wpt/20261108-idb-batch-values-6a385d1c7.tar.gz`
SHA-256: `3f139d69f25b3683fc553f6aeb41c054a04480572a0de6a3b4a0b073e5406216`.
The local machine-readable summary is
`/Users/alex/.cache/vox/wpt/20261108-idb-batch-values-summary.json`, SHA-256
`820d2dadf71ff1f7062b9ba5bd87f91ba683fd7e9e5f28ac35dcaf8367ba8e40`.
The compiler is `V 0.5.2 395d574`, C backend; V invocations retain the
10 GiB compiler limit, compile guards retain 12 GiB, and native runtime guards
retain 3 GiB. All final runner/guard exits are 0. The final native Page binary
is SHA-256 `0870810cc25bf281133e6090b60e5beebc35d634c21371cef32b65806ad828bf`.
These records describe functional checks; sampled guard RSS is not an exact
peak measurement.

A serial **r17** observer is also prepared to run all **6,828 imported cases**
without path filters after r16 actually finishes and the new 18-page production
gate passes. It then uses the latest published bundle containing the verified
source, pins its executable and native libraries, and records the actual runner
and 12 GiB guard exits with the original harness deadlines and 4 GiB browser cap.
It does not run a second broad cohort concurrently. Status is at
`/Users/alex/.cache/vox/wpt/20261108-r17-status.json`; completion and its raw
archive will be recorded at
`/Users/alex/.cache/vox/wpt/20261108-r17-completion.json`.
The one-run supervisor is
`/Users/alex/.cache/vox/wpt/20261108-r17-supervisor.py`, SHA-256
`10ebea87809d50238d79879865e54dc8dca286525f79874f1d16c1410694219c`.
It remains pending until those prerequisites succeed; this is a schedule,
not a completed r17 result or a full-upstream result.


The focused production observer was restarted before launching any tests so
its availability wait can cover the shared build's 45-minute guard and source
inventory retries. It now allows up to two hours for a matching completed
image; actual WPT deadlines and memory budgets are unchanged. The old waiter's
plan and its replacement record are preserved at
`/Users/alex/.cache/vox/wpt/20261108-idb-production-observer-restart.tar.gz`, SHA-256
`98d094166ad39b17b10f1d99e68f1ff7565c22bf3b612eff1edeea38fe3a2e86`.
The current observer is `/Users/alex/.cache/vox/wpt/20261108-idb-batch-production-followup-r2.py`, SHA-256
`c535cadefe741068b84b63cfe7315176323119063255ae890d727e833f04efe3`; its status and completion paths remain unchanged.


## Production validation of all five IndexedDB fixes

The focused production check has now completed on the signed C-backend
executable `7c41735d12565c78ebfdfd91156e84e1fad2f05871f3b4ec9e2518eef3002e79`:
**18 / 18 cases COMPLETE, all 18 harnesses OK, 227 / 227 assertions PASS**.
The original expected count is met for every selected page. This verifies
both the earlier key conversion, key-range and key/count-query fixes and the
new batch retrieval and fixed-view storage in the browser, closing their
previously pending production validation.

The original completed production artifact is checked in place under its read
lease, with 18 fresh launches and private profiles. The sealed manifest matches
all 13 required implementation hashes from `0a4708c60d33d3c38a80781f734ed02a04fefdbc`.
Browser/native-library and runner-tool identities remain unchanged, unexpected
posts are zero, and collection is not aborted. The strict runner and aggregate
guard both exit 0. Original harness deadlines, the 4 GiB browser cap and 12 GiB
aggregate guard remain unchanged. The guard observes
`414384128` bytes sampled aggregate RSS;
this is functional validation, not a performance comparison.

Raw production evidence is
`/Users/alex/.cache/vox/wpt/20261108-idb-batch-production-raw.tar.gz`, SHA-256
`f2830f9d636b82279cfe77f0823ed9e5f5d5e70c1c1ec0495edab0ffa8ca946b`.
Completion is recorded at
`/Users/alex/.cache/vox/wpt/20261108-idb-batch-production-completion.json`.
The separate sealed-source verification is
`/Users/alex/.cache/vox/wpt/20261108-idb-batch-production-source-proof.json`, SHA-256
`625e307c5ae5d0128bc2a674bc7011795db7796f769d078da615a7eb190d8734`.
The observer removes its completed Build scratch after archiving.

r16 continues on its pinned earlier image. The serial r17 prerequisite for the
focused production gate is now satisfied; r17 waits for actual r16 completion
and a matching published bundle before collecting all 6,828 imported cases.
**The larger cohort and full upstream WPT have not reached 100%.** The 227
passing assertions here are a focused result, not a new full-suite percentage.


## Referenced accessible-name text (2026-11-08)

Commit `3843777c9` fixes a destructive builder read in the accessible-name
algorithm: checking whether the accumulated IDREF text is empty consumed it,
so the later return lost the referenced label. The result is now materialized
once and reused for both the fallback check and return. Regressions cover
IDREF order, missing IDs, self-labels and an empty-reference `aria-label`
fallback; the JavaScript `getComputedLabel()` bridge also checks a referenced
input label.

Both new regressions fail before the implementation change. All five focused
HTML accessibility checks pass with it in normal and preallocated-memory
modes. The native JavaScript bridge regression also passes. Three original
imported WPT pages pass **168 / 168 assertions**, meeting every expected count:

| Original imported WPT page | Native Page PASS / reported |
| --- | ---: |
| `accname/name/comp_label` | 131 / 131 |
| `accname/name/comp_labelledby` | 10 / 10 |
| `accname/name/comp_labelledby_hidden_nodes` | 27 / 27 |

All three harnesses report OK. These are fresh native Page processes loading
the original HTTP pages through the pinned upstream server, rather than a
production navigation result. Fixtures, server inputs, driver, tested source
and binary hashes remain unchanged. The first native integration compilation
reaches its 600-second
compile timeout (guard exit 125, compiler killed with -9), below the 12 GiB
budget at a sampled aggregate 6,076,055,552 bytes. Its log and guard receipt are
retained. The successful compilation retry allows 1,800 seconds and finishes
in 479.77 seconds. All final compiler, runtime, driver and guard exits are 0;
the original WPT harness limits are unchanged. V is `0.5.2 395d574` with the
C backend and 10 GiB compiler limit; compile/outer guards retain 12 GiB and
native runtime guards retain 3 GiB.

The final native test executable has SHA-256
`06811accece3e5f7f00aef1510dd75cf824ef2092007f55532ed29c24aedaee0`.
Raw evidence, including the initial failed regressions and compile timeout,
is `/Users/alex/.cache/vox/wpt/20261108-accessibility-reference-3843777c9.tar.gz`,
SHA-256 `ebf155546f8a666d9c0453d8188e384566187d1a1bf539ff8d837bfc3f5a5752`.
The local summary is
`/Users/alex/.cache/vox/wpt/20261108-accessibility-reference-summary.json`,
SHA-256 `1145326f43227e545a8d1e5a8318f1fdf775b05fdb1e4bef23334984d25f4435`.
Generated C is excluded from the archive. Completed job output, temporary
canonical check files and locks are removed from Build/the checkout.

The focused production observer is
`/Users/alex/.cache/vox/wpt/20261108-accname-production-followup.py`, SHA-256
`408b924b1b4b3bb5251ecf5bcabe37867a43f18ef79466ce17a69940c4f06fd4`.
It selects three original pages with 168 expected assertions, uses fresh
browser processes and private profiles, verifies sealed source and executable
identities, and checks a matching completed production artifact in place.
Status and completion are at
`/Users/alex/.cache/vox/wpt/20261108-accname-production-{status,completion}.json`.
The shared attempt `20261108-175454-dd4b7e01` parses the fixed source but is
rejected when another input changes during compilation, so it supplies no
production validation. No duplicate production build is started for this fix.

r16's observer has detected that `tools/wpt_compare.py` changed on disk during
collection. Preserve its results as diagnostic evidence; it cannot supply an
accepted stable-input cohort. The serial r17 observer will pin its own tools
at launch, after r16 finishes and a matching bundle is published. Neither
these focused checks nor the pending broad run establish 100% of the larger
imported set or full upstream WPT.


## Completed larger r16 collection: diagnostic only

r16 collected all **6,828 imported cases** on executable
`f26b41bdc7345c07673f9bbe6eeb9cda4308454efe8cb6a185537cc420f19d48`.
It reports **251,699 / 312,898 runtime subtests PASS (80.44%)**. This is a
**diagnostic count, not an accepted stable-input cohort**: the observer detects
`tools/wpt_compare.py` changing during collection. It is also a different
fixture selection and denominator from r13; these percentages do not establish
a regression or a rate for full upstream WPT.

The case outcomes are 6,711 COMPLETE, 35 CRASH, 67 NO_HARNESS, 5 HARD_TIMEOUT,
7 MEMORY_LIMIT and 3 NO_DOCUMENT. Completed harnesses include 6,148 OK,
112 ERROR and 451 TIMEOUT. There are 59,983 failing, 307 timed-out,
899 not-run and 10 precondition-failed reported assertions; only 2,382 cases
pass completely. Cases without a harness are not counted as passing.
The strict runner and aggregate guard exit 1.

Raw evidence is `/Users/alex/.cache/vox/wpt/20261108-r16-1558-raw.tar.gz`,
SHA-256 `ab758535b7722f3e7dbec67e73ae182ba23de836b9b84cea63dd8e31ba13c071`.
r17 has started all 6,828 cases on the pinned completed production executable
`8fe20c9aaaa506da42672d47f1f1ffc087fce78f44290e68f14e62d00a1b90de`.
Its result remains pending; it does not contain the final coordinate fix below.

## Accessibility production validation completed

The same completed production image passes all **168 / 168 assertions** on
`accname/name/comp_label`, `comp_labelledby` and
`comp_labelledby_hidden_nodes`: three fresh processes, all harnesses OK, every
expected count met, and runner/guard exits 0. This closes production validation
of `3843777c9`. Raw evidence is
`/Users/alex/.cache/vox/wpt/20261108-accname-production-raw.tar.gz`, SHA-256
`969033eccefaa3a82233cb159a782a4e86e297ca27caa4fad855526292971ad0`.

## SVG pointer regions and native coordinate mapping

The following slices are committed separately:

| Commit | Change |
| --- | --- |
| `1c3591c32` | Parse and preserve all eleven SVG pointer-events values. |
| `4ff319b3a` | Query fill/stroke geometry through the existing Skia path decoder, including winding rules, caps, joins, dashes and non-scaling strokes. |
| `d0a5cfed7` | Clip hit queries to the union of transformed SVG clip-path components; retain non-geometric alpha-mask, filter and opacity behavior. |
| `ec0ff060b` | Use SVG fill/stroke regions and text character cells, specified paint presence and each pointer-events visibility rule. Preserve geometry in immutable retained snapshots and conservative hit bounds. |
| `9ec7ba16d` | Give native Page WPT checks a visible viewport and rendering updates so FontFaceSet.ready can settle. |
| `b64060862` | Map SVG user units into scaled native layout without an authored viewBox, and apply SVG CTMs to client rectangles. |

The geometry rules follow [SVG 2 pointer events](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProperty).
The referenced SVG clip change intentionally corrects the upstream translation's
paint-only clip limitation. Existing regressions that encoded that limitation
now check the geometric clip, while retaining the paint-mask assertions.

**22 distinct focused checks pass in normal and preallocated-memory modes**:
3 CSS, 3 native geometry, 2 clip-context and 14 layout checks. Three geometry
checks also pass with the fastc backend. The final layout cohort covers retained
storage, transformed strokes, unpainted character cells, live attributes,
clipping, percentages, nested SVGs, authored viewBoxes and both rendering
policies at native scales 1 and 2. V is `0.5.2 395d574`; V retains its 10 GiB
compiler limit, compilation/outer guards retain 12 GiB, and native runtime
guards retain 3 GiB. Required final checks and guards exit 0.

Before the final coordinate fix, the original nine-page native Page collection
matches the relevant sources of `9ec7ba16d` and reports the following results:

| Original imported WPT page | Native Page PASS / reported | Expected |
| --- | ---: | ---: |
| `accname/name/comp_label` | 131 / 131 | 131 |
| `accname/name/comp_labelledby` | 10 / 10 | 10 |
| `accname/name/comp_labelledby_hidden_nodes` | 27 / 27 | 27 |
| `svg/interact/parsing/pointer-events-computed` | 0 / 0, no harness | 11 |
| `svg/interact/parsing/pointer-events-valid` | 0 / 0, no harness | 11 |
| `svg/interact/scripted/ellipse-hittest` | 24 / 24 | 24 |
| `svg/interact/scripted/pointer-events-fill-stroke-hittest` | 8,910 / 8,910 | 8,910 |
| `svg/interact/scripted/rect-hittest-002` | 53 / 53 | 53 |
| `svg/interact/scripted/svg-pointer-events-bbox` | 23 / 31 | 31 |

This is **9,178 / 9,186 reported assertions**, with 22 expected assertions
unreported by the two SVG document pages. The strict driver/outer guard exit 1;
the eight bounding-box failures and missing harnesses remain failures.
The native executable is SHA-256
`0937e4ebd9423aa06458370bc2d57c5fbf968c628a6c5f1f2453b04a2ef27c81`.
Fixtures, required source files, native binary, server and runner inputs remain
unchanged during that collection. It uses native Page processes at an 800x600
viewport, rather than production navigation or the production display scale.
The earlier no-rendering native probe reports zero assertions and a harness
timeout; that failed attempt is retained too.

The first nine-page production check on `8fe20c9a…` reports only
**4,725 / 9,186 PASS**, 4,461 FAIL and two NO_HARNESS cases. Both strict exits
are 1. Its source proof includes the pointer-region implementation but lacks
the final coordinate and corrected clip code. This discrepancy is retained at
`/Users/alex/.cache/vox/wpt/20261108-svg-pointer-production-raw.tar.gz`, SHA-256
`29d831dd4d5508ac582a6abb365c24fe2b973e1eee7050810697efcbaa08af42`.
A separate minimized production diagnostic reproduces a 40 CSS-pixel SVG
rectangle reporting a 20-pixel client width on the native scaled viewport.
The initial wide-stroke probe masked this error. The strengthened regression
fails with the same 20-versus-40 result before `b64060862`, then passes along
with percentage, nested-viewport and authored-viewBox checks after both
coordinate mappings are fixed. The minimized diagnostic is not an official
WPT result or part of a WPT denominator.

Raw focused evidence, including failed regressions, compilation attempts and
diagnostics, is `/Users/alex/.cache/vox/wpt/20261108-svg-pointer-b64060862-raw.tar.gz`,
SHA-256 `997f55972cfe7c9df53d2440dc97d3b748c8ea044a350029e56d5e7dfb5af790`.
The local summary is `/Users/alex/.cache/vox/wpt/20261108-svg-pointer-summary.json`,
SHA-256 `2760a3ea4e7c8c0311fdd74cc4a40b9c246c32b555135ac928eca8e37009cf05`.
Generated C is excluded; completed Build output, locks and the temporary
canonical combined test file are removed after archiving.

A matching-image production follow-up targets six original HTML pages with
**9,155 expected assertions**, with fresh browser processes, unchanged harness
deadlines, 4 GiB browser caps and a 12 GiB outer guard. It requires all 16
implementation hashes from `b6406086260673bb5136284254572bbbe6059d07` and checks
the original completed artifact in place under a read lease. The two SVG
document-loader cases and eight bounding-box failures remain recorded above.
Status/completion are
`/Users/alex/.cache/vox/wpt/20261108-svg-pointer-fixed-production-{status,completion}.json`.
Its observer is `/Users/alex/.cache/vox/wpt/20261108-svg-pointer-fixed-production-followup.py`,
SHA-256 `de4d24c48d1f872212903d130447d7bd9aff224ac04c61da91b05ef98c6206c2`.

That production follow-up completed: **9,155 / 9,155 PASS**, all six cases
COMPLETE with harness OK, and strict runner/outer guard exits 0. It checks the
original completed production artifact in place under a shared read lease,
with all 16 required implementation hashes unchanged. The executable is
`cd7f5f91e8b46a0f1a313ee9b8c93478081c035eaf36e6532699f0035ffeb978`,
receipt `Build/production-build/receipts/20261108-193625-82de3115`.
Raw evidence is `/Users/alex/.cache/vox/wpt/20261108-svg-pointer-fixed-production-raw.tar.gz`,
SHA-256 `046d31bf23b3b2438ef7dc5040e2403ee5b98b5c7dfb37c423134cd0194435ea`.
The failed fastc attempt and the earlier failing nine-page collection remain
retained above. r17 continues on its original pinned image. **The larger
imported set and full upstream WPT have not reached 100%.**

## SVG object boxes and active XML navigation

Three further fixes are committed separately:

| Commit | Change |
| --- | --- |
| `8a88436b4` | Resolve SVG text x/y/dx/dy and textLength lengths in the element's font context, including `dy="3em"`, while preserving float user-space and device-scale behavior. |
| `60cc4ae8b` | Include nonempty SVG box edges, descendant text lines and gaps, and hidden SVG image viewports in the appropriate pointer regions. Keep aggregate hit bounds separate from painting geometry. |
| `c1f5d35ed` | Navigate SVG/XML responses as active XML documents instead of image wrappers or HTML. Preserve namespaces, CDATA, script order, UTF-8/XML declarations and transport charsets; use inert XML trees for preload discovery and own source tokens beyond decoded-input storage. |

**30 distinct focused checks pass in normal and preallocated-memory modes**:
18 layout checks and 12 navigation/response checks. They retain V's 10 GiB
compiler limit, 12 GiB compile/outer guards and 3 GiB focused runtime guards.
The XML checks include character decoding, malformed-document handling,
HTML/image navigation regressions and source lifetime after scratch reuse.
An initial XML regression exposes an absent MIME charset becoming a present
empty string; corrected extraction passes the final checks. Failed attempts
and their diagnostics remain in the raw evidence. Shared-host load averages
were about 28–44 while r17 and other sessions ran; no timing comparison is claimed.

The unchanged original bbox page improves from **23 / 31 to 31 / 31** in
native Page navigation. All seven selected original HTML pages then pass
**9,186 / 9,186**. After the XML loader fix, both previously unreported SVG
pages (`pointer-events-computed` and `pointer-events-valid`) report and pass
**11 / 11 each**. The complete original nine-page focused collection passes
**9,208 / 9,208**, with all expected counts, harness OK and strict driver/outer
guard exits 0. Required source hashes, binary, fixtures, server and runner
inputs remain unchanged throughout that collection. Its native Page executable
is SHA-256 `ccf0ca8c89af224fa01e5655a616bbe2786365756406aba6f43dff1697d468b3`; this is not a production-browser or full-suite result.

Focused raw evidence is
`/Users/alex/.cache/vox/wpt/20261108-svg-bbox-xml-c1f5d35ed-raw.tar.gz`,
SHA-256 `c74ec683fa664b494f341ca8217343f536a696f9de7cefaf89ad2d705875a047`.
The summary is `/Users/alex/.cache/vox/wpt/20261108-svg-bbox-xml-summary.json`,
SHA-256 `6624e8fcc3fa31e05a4b7f85ddce1c33f33324b3546c244f0a4f1e342fce9593`.
Generated C is excluded. Completed Build output, temporary canonical combined
tests and their locks are removed after archiving.

A production follow-up requires all 23 implementation hashes from
`c1f5d35ede5d4cbf5885c769d076f11561419b50` and checks the same nine original
pages (**9,208 expected assertions**), with fresh browser processes, unchanged
harness deadlines, 4 GiB browser caps and a 12 GiB outer guard. It checks a
matching completed bundle in place under a read lease. Status/completion:
`/Users/alex/.cache/vox/wpt/20261108-svg-xml-production-{status,completion}.json`.
Observer: `/Users/alex/.cache/vox/wpt/20261108-svg-xml-production-followup.py`,
SHA-256 `71a3cb09697323dcd0164204d7ff414aacf7367832ddc1a2847dea2c09757bd1`.
Production validation of these latest slices remains pending. The shared build
request uses the C backend because the fastc attempt fails on a missing legacy
OS header. r17 remains on its original pinned image and has collected 5,400 of
6,828 cases at this checkpoint, with no changed runner/bundle inputs.
**Neither the larger imported cohort nor full upstream WPT is at 100%.**

## MathML interfaces, native clipboard events, and the partial r17 collection

The next slices are committed independently:

| Commit | Change |
| --- | --- |
| `4821b88b6` | Expose MathMLElement and shared element event-handler descriptors; compile SVG/MathML handler attributes into native slots. Preserve namespace and receiver brands, dataset identity, signed 32-bit tabIndex conversion and native default indices. |
| `a538e472a` | Make native DragEvent regression assertions compare ownership by pointer identity instead of recursively comparing complete owner graphs. |
| `491fe78fa` | Expose Window-only ClipboardEvent through the native event binding, with the existing native ClipboardEvent record and DataTransfer identity registry. Preserve dictionary conversion order, author exceptions, subclassing and native dispatch. |

**40 distinct focused checks pass in both normal and preallocated-memory
modes**: 37 application/native-binding checks and three DOM checks. The final
combined application test compilation peaks at 6,109,872,128 bytes normally
and 6,113,001,472 bytes with preallocation, below the unchanged 12 GiB guard.
V retains its 10 GiB compiler limit; focused execution retains 3 GiB.
Earlier browserjs-module compilation attempts exceed those existing limits;
they are failures, retained with their diagnostics. Profiling identifies the
module-wide generic-body checking pass. Exercising these public native APIs
from the application test module avoids that expansion, without disabling
compiler checks or selecting a compatibility compiler. The pointer assertion
correction alone does not resolve the compilation memory failure.

The four unchanged original MathML pages now pass **672 / 672 assertions**:
global handlers 375, clipboard handlers nine, and tabIndex cases 64 and 224.
Before ClipboardEvent is exposed, the clipboard page passes only six of nine;
that failed collection is retained. The final collection also repeats the
nine SVG/accessibility pages above: all **13 original pages pass
9,880 / 9,880 assertions**, with exact expected counts, harness OK, strict
driver/outer exits 0 and unchanged pinned inputs. Its native Page executable
is SHA-256 `49789acc2388f96cf6a52b4cf665c69bea53e1bccda88c7f6aa7e57c0eb5ea29`.
This is focused native Page evidence, not a production or full-suite result.

Raw evidence: `/Users/alex/.cache/vox/wpt/20261108-mathml-clipboard-491fe78fa-raw.tar.gz`,
SHA-256 `2ea81eda6ec3a80eb84b35ed1f4f41aa05570c451948f8c70340e3f35f4ef6b5`.
Summary: `/Users/alex/.cache/vox/wpt/20261108-mathml-clipboard-summary.json`,
SHA-256 `1308163fa2eb031c4f5f9d6f023e2de8de5314339a0cc22bcd65783825052c3a`.
Generated C is excluded; completed job output, temporary canonical combined
tests and locks have been removed after archiving.

r17 has stopped after **6,452 of 6,828 cases**. Its runner aborts because
`vox-064-005` cannot complete the warm-up (`NO_DOCUMENT`), with strict
runner/outer exits 1. The partial records contain **244,380 PASS of 299,872
reported subtests**, alongside 54,511 FAIL, 239 TIMEOUT, 732 NOTRUN and ten
PRECONDITION_FAILED. There are 11 memory-limited cases, 31 crashes, six hard
timeouts, 65 cases without a harness and three without a document. No changed
runner/bundle inputs or unexpected POSTs are observed. These counts describe
an incomplete diagnostic collection and cannot establish a full-suite rate
or a regression relative to another run's denominator. r17 uses executable
`8fe20c9aaaa506da42672d47f1f1ffc087fce78f44290e68f14e62d00a1b90de`,
which lacks the latest XML, MathML and clipboard changes.
Its archived raw evidence is `/Users/alex/.cache/vox/wpt/20261108-r17-raw.tar.gz`,
SHA-256 `efbe3f633080a1ec73bd7d3ddf74cbe4b6c7171484b5a9500ebfb60ee18b76dd`;
the completed Build directory is removed.

Production validation waits for a completed image containing the committed
implementation hashes. In addition to the existing nine-page SVG/XML check,
the new observer requires all four MathML pages and 11 original SVG
source-switch/paint-server mutation reftests, with unchanged references and
exact zero-pixel tolerance. It checks the completed bundle in place under a
read lease and launches fresh processes. Status/completion:
`/Users/alex/.cache/vox/wpt/20261108-mathml-clipboard-production-{status,completion}.json`.
Observer: `/Users/alex/.cache/vox/wpt/20261108-mathml-clipboard-production-followup.py`,
SHA-256 `1d21ab4f2cb0b2aadddd0d56c28742d37d02cfc7b75d56b8e46679344becb597`.

r18 is prepared to collect all 6,828 imported cases serially after both strict
production gates pass and a matching published image is available. It retains
the existing 4 GiB browser/12 GiB outer budgets and unchanged harness deadlines.
Status/completion: `/Users/alex/.cache/vox/wpt/20261108-r18-{status,completion}.json`.
Supervisor: `/Users/alex/.cache/vox/wpt/20261108-r18-supervisor.py`, SHA-256
`04511d82dd96c8e5232821076ee91b04a7f707ed62497f64a4350761518f8beb`.
At this checkpoint production and pixel validation are pending, and r18 has
not begun collection. The official full upstream checkout remains available;
its complete manifest is not yet integrated into execution. **Neither the
larger imported set nor full upstream WPT has reached 100%.**

The matching production image is now available, executable
`e66ce03390efb5ef5b85d4e9009db6df414ed241d9b9b9217222e5825a767e33`,
receipt `Build/production-build/receipts/20261108-210831-30409edf`.
It confirms **672 / 672 MathML assertions**, with all four pages COMPLETE,
harness OK, exact counts, unchanged pinned inputs and strict runner/outer
exits 0. Ten of the 11 SVG reftests remain pixel-exact. The gradient
stop-color animation case differs in 10,000 pixels; unchanged tolerance rejects
it. The separate SVG/XML production collection reports **9,204 / 9,208 PASS**:
all pages complete with harness OK, but four group bounding-box assertions
fail. These production failures remain open despite the native Page result.

Production MathML/pixel evidence:
`/Users/alex/.cache/vox/wpt/20261108-mathml-clipboard-production-raw.tar.gz`,
SHA-256 `deb57dfd80d9f322aca29c9d17e502650a13e6616edd03c3f89897758b705adb`.
SVG/XML production evidence:
`/Users/alex/.cache/vox/wpt/20261108-svg-xml-production-raw.tar.gz`, SHA-256
`aec7019edb03c9695320fdec7b664e9ab81c54a129788607eb4a203a74e6a796`.
Completed production-check directories and locks are removed after archiving.
r18 is consequently **DEFERRED**, with no imported collection started.

Commit `4c03f4713` separately integrates the official manifest's 40,139
testharness variants, including generated worker/window URLs and HTTPS.
All 32 tooling checks pass; five original HTTP/window/worker/HTTPS probe pages
pass 23 assertions. Unsupported HTTP/2 cases stay in the denominator and force
a nonzero strict result. The first unfiltered official-manifest collection is
now **RUNNING** on the matching production executable above, after r18 ends,
with broad suites serial. Other manifest types and unavailable server
protocols remain explicit limitations. See [the upstream execution report](WPT_UPSTREAM_SUITE.md)
for scope, original failed attempts, executable identity and local receipts.
**No completed full-upstream rate or 100% result is established.**

## Production follow-up fixes and renderer snapshot promotion

| Commit | Change |
| --- | --- |
| `15b805dfc` | Retain SVG container object bounds and transforms separately from CSS border boxes. A bounding-box pointer region includes the gaps between descendant shapes; fill/painted modes do not turn those gaps into a filled container path. |
| `1478eda7d` | Materialize the first renderer snapshot when a completed tree-only layout is subsequently requested for painting at the same viewport. Reuse the committed typed root and geometry and install the painting callbacks. |
| `92d0c9e87` | Notify referencing SVG paint resources when animated samples change, including stops in hidden resource trees. Retire retained gradient colors, preserve existing snapshots, and restore original colors on cancellation. |

**23 distinct focused checks pass in normal and preallocated-memory modes**:
14 layout checks and nine application/rendering-loop checks. The latter include
the existing SVG identity/mutation assertions and native finished-promise
delivery. Original WPT assertions, references and pixel tolerances are preserved.
The same V 10 GiB compiler limit, 12 GiB compile/outer guards and 3 GiB focused
runtime guards remain in force. Final application compilations peak at
6,105,661,440 and 6,106,873,856 bytes, respectively.

Before these fixes, the new gradient check retains red instead of green, and
the container check accepts an unfilled gap after switching pointer modes.
The broader application checks also expose a tree-only result with an empty
renderer snapshot: direct paint commands contain only a background, whereas a
subsequent document recording materializes both SVG paths. Explicit promotion
now makes the original mutation check pass without a viewport resize or forced
geometry rebuild. Those failed attempts, the diagnostic, and an initial
compiler variable-name error remain in the raw evidence.

The final native Page collection repeats all **13 original MathML, SVG and
accessibility pages: 9,880 / 9,880 PASS**, exact expected counts, harness OK,
strict driver/outer exits 0, unchanged fixture/runner/source hashes. Executable
SHA-256: `b9e452264f5720e814b9a92336fc621fea2c07de69c2ccdb45cc944d3fdf3aeb`.
This is focused native evidence; it does not supersede the earlier failed
production cohorts or establish a full-suite result.

Raw evidence: `/Users/alex/.cache/vox/wpt/20261108-svg-resources-92d0c9e87-raw.tar.gz`,
SHA-256 `6a547c64cc238c077bee41a39f5a52854deffce4c9a29650c35ef032c0c2e188`.
Summary: `/Users/alex/.cache/vox/wpt/20261108-svg-resources-summary.json`, SHA-256
`77a13c6a83ed572bb308dc083f63ef946ad7e4ae8db0e29df04918fccc2bac2c`.
Generated C and private profiles are excluded. Completed Build output,
temporary canonical combined tests and locks are removed after archiving.

A new production follow-up checks all 13 pages and the same 11 original SVG
reftests, requiring all 37 implementation hashes from `92d0c9e87`. It checks a
matching completed artifact in place under a read lease. Status/completion:
`/Users/alex/.cache/vox/wpt/20261108-svg-resources-production-{status,completion}.json`.
Observer: `/Users/alex/.cache/vox/wpt/20261108-svg-resources-production-followup.py`,
SHA-256 `93abe06b374c3ee0061bad68b463d74939183798d516d4aea5339fbffd58070b`.
At this checkpoint validation is waiting for a matching completed image: the
newer `20261108-213614-44e2fd3f` receipt contains the SVG fixes but lacks the two
renderer-promotion source hashes; its staged artifact has already been retired.
The shared C-backend build request is current. No separate bundle is copied or
queued by the checks.

The unfiltered official-manifest testharness collection continues on its
original pinned `e66ce03390ef...` executable, with 200 case records at the last
checkpoint and no changed inputs. Its partial counts are diagnostic only; it
does not contain these last three commits. The imported r18 remains deferred.
**Full upstream WPT and the larger imported set are not at 100%.**

The matching production follow-up has now completed successfully:
**9,880 / 9,880 PASS across all 13 original pages**, all COMPLETE with harness
OK, exact expected counts and strict runner/outer exits 0. **All 11 original
SVG reftests are pixel-exact**, including the previously failing stop-color
animation, with unchanged zero-pixel tolerance. Executable SHA-256 is
`4b11a1dbe4a4325a282f4ad443bba031f010428cd296c6319a6f017c33ff6f00`,
receipt `Build/production-build/receipts/20261108-214607-1eaf91e5`.
All 37 required implementation hashes match the frozen source manifest.
The checks launch fresh processes from the original completed production
artifact in place under its shared read lease; no bundle is copied. Runner,
fixture, executable/library and pixel inputs remain unchanged, with no
unexpected result posts or collection aborts. Pixel driver/outer exits are 0.

Production raw evidence:
`/Users/alex/.cache/vox/wpt/20261108-svg-resources-production-raw.tar.gz`,
SHA-256 `29218650df3a24e101c2293688d1e335c9cc89f2dfd5c0f68a96c6cef6a6fc15`.
The completed focused production directory and its locks have been removed.
The official-manifest run remains pinned to its earlier executable and has
500 records at this checkpoint, with no changed inputs. This focused passing
cohort does not establish full imported or upstream conformance.
