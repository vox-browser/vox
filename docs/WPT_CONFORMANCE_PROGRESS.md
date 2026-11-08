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
