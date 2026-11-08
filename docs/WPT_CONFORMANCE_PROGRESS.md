# WPT conformance follow-up, 2026-11-08

**The suite still fails.** r14 reports **153,046 / 170,027
passing subtests (90.0%)**, with 1,920 of 3,808 files fully passing.
There are 16,981 reported non-passing subtests and 71 files without results.
The higher percentage is not an all-pass result or evidence of a 90% stable-denominator milestone.

The [full-run manifest](performance/wpt-r14-20261108.json) records every file's counts,
build identity, guard exit, comparison arithmetic, failure examples and local raw-evidence archive.
The [focused-check manifest](performance/wpt-fixes-20261108.json) preserves source checks,
development failures, and the separate Range diagnostic.

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

All seven final required source checks pass. The canonical build queue has not yet published a
bundle containing the later font-family, SVG-default and animation-cache fixes. Those fixes are
not counted as measured r14 gains. The build receipts show repeated input-change failures during
shared development; this session reused the latest completed bundle following the shared-build policy.

## Range diagnostic

The complete `Range-insertNode` page still records NO_HARNESS in r14. A separate run with a
30-second signal deadline reaches the diagnostic 2 GiB browser cap before reporting.

Using the test's existing `?subtest=i,j` option, a separate run executes all 920 distinct scenarios
from the retained r13 names. **All 1,840 / 1,840 subtests pass**, with 920 harness-OK reports,
19 fresh launches, no crashes, and no memory-limit outcomes. The 3 GiB guard and runner both
exit 0; observed peak RSS is 1,508,114,432 bytes. This diagnostic separates scenarios into
navigations and is not a replacement result for the original combined page. It is excluded from
r14's aggregate totals. The combined page's resource/deadline failure remains open.

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
