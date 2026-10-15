# Wikipedia rendering: accepted 7.83% instruction reduction

Vox used **7.83% fewer CPU instructions** to render the frozen Wikipedia portal with JavaScript disabled: arithmetic mean 2,498,763,004 → 2,303,143,466.6. Median settled physical footprint fell **5.83 MiB**, and median lifetime peak footprint fell **0.25 MiB**. All 20 viewport captures were pixel-identical to the matched reference.

The user accepted this reported result with “8% is enough.” The exact reduction is 7.8286551%; the original 10% mean target remains failed in its unchanged verdict. Acceptance is recorded separately, without rerunning, discarding or reclassifying observations. Final verification passes for the frozen measured source in both GC modes, with the visual and startup checks below.

Chrome provides a separate reference: approximately **2.74 billion observed CPU instructions** from navigation through a completed screenshot. Its counts are lower bounds, and its endpoint includes work excluded from the Vox endpoint. These figures do not establish a direct browser ratio or FCP comparison.

## Vox instructions

The selected C15 graph was measured once against five fresh matched controls. CPU pairs alternate order; five separate RAM pairs follow. The result covers the combined selected optimizations, with no gain inferred by subtracting percentages from other cohorts.

| Pair | Matched control instructions | C15 instructions | Reduction |
| --- | ---: | ---: | ---: |
| 1 | 2,480,300,889 | 2,252,893,148 | 9.1686% |
| 2 | 2,439,593,852 | 2,344,689,682 | 3.8902% |
| 3 | 2,468,032,161 | 2,346,442,524 | 4.9266% |
| 4 | 2,453,689,609 | 2,341,982,437 | 4.5526% |
| 5 | 2,652,198,509 | 2,229,709,542 | 15.9298% |
| **Arithmetic mean** | **2,498,763,004.0** | **2,303,143,466.6** | **7.8287%** |
| Median | 2,468,032,161 | 2,341,982,437 | 5.1073% |

Control observations range from 2,439,593,852 to 2,652,198,509; C15 ranges from 2,229,709,542 to 2,346,442,524. All five pairs improve. The original 10% mean threshold was missed by 54,256,763 instructions. The original verdict remains `target_or_review_needed`; the separate user acceptance selects the measured 7.83% result.

## Memory and pixels

The primary RAM requirements are no increase in median settled physical footprint or median lifetime peak physical footprint. Both pass. All seven observed metrics and ranges are shown, including the two first-frame increases.

| Metric | Control median bytes [min, max] | C15 median bytes [min, max] | Median change bytes |
| --- | ---: | ---: | ---: |
| Settled physical footprint | 353,568,112 [352,585,048, 359,466,376] | 347,456,856 [344,065,368, 353,404,272] | -6,111,256 |
| Settled resident size | 512,139,264 [510,443,520, 516,784,128] | 503,840,768 [501,809,152, 510,918,656] | -8,298,496 |
| Lifetime peak physical footprint | 379,127,200 [378,291,592, 388,564,384] | 378,865,056 [378,062,216, 380,011,936] | -262,144 |
| Kernel peak RSS | 537,133,056 [535,756,800, 545,423,360] | 536,051,712 [534,626,304, 536,641,536] | -1,081,344 |
| Observed peak resident size | 536,461,312 [535,445,504, 541,868,032] | 535,805,952 [533,446,656, 536,117,248] | -655,360 |
| First-frame physical footprint | 318,358,872 [316,147,032, 319,456,624] | 318,817,624 [317,588,848, 322,635,096] | +458,752 |
| First-frame resident size | 473,874,432 [473,104,384, 476,102,656] | 474,382,336 [472,596,480, 478,674,944] | +507,904 |

The highest lifetime physical-footprint peaks are 388,564,384 control bytes and 380,011,936 C15 bytes. First-frame observation gaps span 5.903–8.586 ms; within-row settled variation spans 7.639–8.978%. These gaps and auxiliary increases are retained, without a claim that every RAM measure improves.

Every CPU and RAM observation rendered one document installation and 836 paint commands, with zero JavaScript runtime, source count, source bytes or script preloads. All 20 logical 1024×768 viewport comparisons have zero differing pixels. Source, binary, native, compiler, observer, cache and all 299 authorization pins remained unchanged; actual outer exit was 0.

## Chrome reference

Chrome for Testing **155.0.8059.79** ran with a fresh profile per observation, author JavaScript disabled by CDP before navigation, and a 1024×768 viewport at DPR 1. Fetch replay served the frozen document and six images at the original Wikipedia URL; unavailable hidden badges and favicon requests were blocked.

| Run | Navigation → completed screenshot instructions | Launch → same screenshot instructions | Missing final child samples |
| --- | ---: | ---: | ---: |
| 1 | 2,447,427,030 | 10,445,016,894 | 1 |
| 2 | 2,735,173,810 | 9,907,345,948 | 1 |
| 3 | 2,895,571,202 | 9,918,868,958 | 1 |
| 4 | 3,039,428,475 | 9,883,455,134 | 1 |
| 5 | 2,690,669,916 | 9,985,241,431 | 1 |
| **Median** | **2,735,173,810** | **9,918,868,958** | |
| Mean | 2,761,654,086.6 | 10,027,985,673.0 | |

The endpoint waits for document completion, nonempty content, expected image sprites and `document.fonts.ready`, then receives the first CDP viewport PNG. Navigation counts start before `Page.navigate`; launch counts also include browser/V8 startup and CDP configuration. Author globals remain undefined, the root stays `no-js`, and no script request transfers bytes. Two zero-byte disabled-script ResourceTiming placeholders are allowed.

Counters sum observed browser, renderer, GPU-process CPU and utility instructions, including CDP readiness evaluations. Each run lacks one final descendant sample, and unsampled short-lived work can be omitted. Actual GPU execution and WindowServer are excluded; no extrapolation is applied. The final sample precedes screenshot completion by 2.39–6.30 ms. All five Chrome PNGs are identical, all 365 inputs stayed pinned, and actual outer exit was 0.

Vox stops its primary counter at the native document-paint report, before bitmap snapshot, CALayer submission and screenshot completion. Chrome stops after the completed screenshot. Their endpoints and rendered output are not asserted equivalent. Replay uses inferred MIME types and synthetic response headers because the inherited cache does not retain original headers.

## Scope and common policy

Both Vox variants use the same frozen HTML/resource cache, fresh processes and copied caches, with raster snapshot reuse disabled and background refresh enabled. The rendered viewport is 1024×768 inside a 1024×880 native window. The primary scope is `document_install_to_first_paint`; overlapping checkpoint deltas are not summed into it, and no work is moved before it. HTML/CSS still creates the DOM needed for selectors and layout; JavaScript being disabled does not make this a DOM-free renderer.

The existing collector policy stays identical: startup/activity divisors 64/64, cooperative work switches to 8 after 64 ms and restores it, and the static-document capacity hint remains 160 MiB. `GC_MARKERS=1` is retained and other GC overrides are cleared. No collector, heap, cache, counter or native rendering policy change receives gain credit. No elapsed-time speedup or hard 500 ms claim is made.

A common capture correction defers complete screenshot callbacks while document work or layer presentation is busy. It prevents reuse of a stale scale-2 backing image. The matched control is the frozen baseline plus this identical correction; the candidate contains it too. ARC/MRC native checks pass. The correction receives no instruction credit, and its original mismatched capture and cleanup-only proof failure remain retained.

## Changes and provenance

The selected graph avoids eager computed-property maps, layout indexes, intrinsic-height maps, variation-axis maps and invisible-font caches. It reuses native font handles and stable scope traversal, removes unused paint-box maps, and reduces attribute/font-input copying while preserving observable ownership and ordering. C14 adds inline invalidation storage, owned shaping-tag records and rendered UTF16-cache reuse.

C15 constructs expensive computation contexts only where required, avoids transient shaping-cache copies, and dispatches 869 CSS keywords and 440 canonical property names by length and initial byte. The dispatch preserves the frozen mappings; it does not refresh current upstream generated data or introduce a retained lookup cache.

| Completed C15 slice | Commit |
| --- | --- |
| CSS name dispatch, generators and focused tests | `1d746ab45f602d25e7cecced45d45674e0b77d96` |
| Shaping-cache ownership and width queries | `e62b0267a117eaa927fbe5d59221664fe450d8e4` |
| Four context regressions | `f07418b3ccd81f8dd41bb00892232d5f83213ef3` |

Concurrent canonical commit `e58fb75b7f079416f25a62bdc2de84eb8aa7cd5e` independently installed the same context runtime change, apart from two comments. It is preserved and attributed jointly; this task adds its four corrected tests separately. Later unrelated canonical changes remain outside the measured graph. The canonical app bundle is not the frozen benchmark binary.

## Verification

The private production O2 build passes. Final focused validation passes **216 functions per GC mode**: CSS 150, layout 32 and platform 34, with 432 asserting rows and 53,626 Boehm / 53,622 GC-none assertions. The validation graph contains 5,713 files. All 3,482 non-test files match production byte for byte.

The original focus batch retains actual outer exit 1: two CSS compiles failed before execution on a test-only color accessor. Four layout/platform jobs passed. Immutable validation-v2 fixes one assertion; only the unexecuted CSS 150 functions per GC ran in recovery, with compiler/test/outer exits 0. No passing job was rerun. Independent composite evidence is retained in `candidate15-focused-composite-independent-audit.json`.

Final checks use the frozen C15 production bytes and corrected validation-v2 tests:

| Check | Scope | Actual result |
| --- | --- | --- |
| Semantic union, Boehm and GC-none | 1,013 selected functions per GC: 216 exact focused carry + 797 fresh | Pass: 1,012 asserting functions and one platform conditional per GC |
| Official upstream AST corpus | All 100 exact fixtures, no overrides | Pass, actual exit 0 |
| Private native headless smoke | Real browser/engine startup | Pass, actual exit 0 |
| Screenshot conformance | 19 cases: 16 exact and three established fuzzy cases | Pass under unchanged expectations |
| SVG mutation subset | All eight required cases pixel-exact | Pass: zero differing pixels in all eight |

The original 18-job broad batch retains actual outer exit 1: its two native jobs compiled successfully, but the queue-sensitive redraw fixture returned 23 instead of 31. Each job retains its other 137 passed functions. The missing bit checks the first event count; earlier queued redraws are a source-backed explanation, not a measured attribution of their origin. Only that failed unchanged fixture then ran in its normal separate process per GC, with compiler/test/outer exits 0 and expected result 31 unchanged. No passing function was repeated, and no production, native or test body changed.

The final union has **1,246,572 Boehm and 1,244,454 GC-none assertions**. Each mode selects 1,013 distinct functions; 1,012 assert, while `test_native_browser_context_preserves_native_callbacks_on_other_platforms` has its assertions inside `$if !macos` and does not assert on this Mac. The independent composite audit passed with actual auditor exit 0, retaining the original failed jobs and both successful isolated recoveries.

The three established screenshot tolerances remain unchanged: `inline-node` differs at 13 pixels with maximum channel error 1, `text-decorations` at 1,341 pixels/error 2, and `canvas-text` at 1,994 pixels/error 8 under the retained macOS allowance. The other 16 cases are pixel-exact.

The browser continues to use JavaScriptCore; this change does not claim full LibJS translation parity. Separate acceptance-aware controllers preserve all original 299 measurement pins, 20 validation pins and 20 recovery pins. All 5,692 production files, 5,713 validation files, the broad source graph and toolchain were rehashed unchanged. No performance observation was repeated.

## Earlier fixed attempts

Each earlier result has its own five fresh CPU pairs and five separate RAM pairs, exact captures and actual outer exit 0. None met the original 10% mean requirement. Every observation remains retained; gains are not pooled across cohorts.

| Candidate | Mean instruction reduction | Settled footprint median change bytes | Peak footprint median change bytes | Primary RAM |
| --- | ---: | ---: | ---: | --- |
| C5 | 6.1229% | -1,351,656 | +638,928 | Fail |
| C6 | 1.1807% | -1,343,536 | +1,818,600 | Fail |
| C8 | 7.0957% | -6,619,136 | -1,638,400 | Pass |
| C10 | 8.1464% | -5,537,768 | -901,168 | Pass |
| C11 | 8.3691% | -5,210,136 | -458,800 | Pass |
| C14 | 7.7704% | -7,102,512 | -1,196,056 | Pass |

C6 also increased median instructions; C14 retains its regressing second pair. Rejected C7/C9/C12/C13 graphs and insufficient profiles receive no performance credit. C16 is unselected: its private build had already completed when the user accepted C15, and it ran no focus or performance cohort. Diagnostic and stopped-experiment details are retained in the artifact audits, rather than folded into the selected result.

## Reproduction and evidence

The [instruction measurement tool](../tools/measure_browser_instructions.py) supports disabling Chrome JavaScript before navigation. Exact commands and frozen inputs are retained with the cohort. Artifacts are under `Build/wikipedia-instructions-next10/`. The following hashes identify the actual frozen workload and binaries; source closure, build commands, observer inputs and all raw observations remain retained.

| Input | SHA-256 |
| --- | --- |
| Wikipedia HTML, 122,197 bytes | `5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466` |
| Copied cache contents | `46c277c0b7df22c8b1d5c1c00d55b1a2548750e7257cbe04f0b927de9ce8e5fd` |
| Matched control source | `f96ab7f5105c284d2c5b996813c06a5ff31162a9f65ea6889e8c2579b867d55a` |
| Matched control executable | `5c32714a91af2784b1d6ef0c0092dcf5fad2a2957f5d6c312ec6d2f5ca0836f0` |
| C15 production source | `eaee515900442058899d85706df6e613dd835c26ee9ad82660daff5b1da6f864` |
| C15 validation-v2 source | `9bce6ffdb8f090a83ea74389aa70b0c8222fbcf7fbe5a5f5286278ae0493eac4` |
| C15 executable | `cbfd9f4e12198938b819ccecdcb586a75b4aeecbc6b49f92623fe046ee823b9a` |
| Shared native replay library | `97834a755eb05f33b1297791b38c854c1ed13cfcbdc96546532bd0e858afc45c` |
| Common viewport reference | `fd26323787ff5d6eeb09c3b2848670d4837063720c63cc2af17a81f445d04d3d` |
| Final cohort runner | `692546fde976e398ae073b2fc9ddd3ebcc75e60f1dcdb218902acd0caffcf9f3` |
| Predeclared measurement protocol | `9345eb4ce99044f9587e20bfee9c0d60a0c9e2750b3075d636395c152032185b` |
| Capture protocol amendment | `6846cc7588414d01aa17e17c69b03c0bccfac54d137713a374168d07a6ed9a51` |

C15 authorization is `3a55ff80732e54e4beaa2d37f4edd64ebb54f2ce344664272b378f8529931781`; its original verdict is `f610aa2d7bdc176d0a09a44636db2279ddec171019471541c3653f3ede5f34bd`. Separate user acceptance is `125b5d2f63f16f278604ee59f3cf63e6ec010fd9f209820ebe0f439e25aca644`. The final independent fixed-cohort audit is `candidate15-final-independent-audit.json` (`e615d709…`), with unchanged pins, all 20 raw rows/pixel comparisons and all seven RAM metrics.

Chrome evidence is in `chrome-reference/{protocol.json,cohort/summary.json,cohort-supervisor-exit.json,final-audit.json}`. Vox raw rows and summaries are in `instructions-final-candidate15/` and `memory-final-candidate15/`. Sampling and rejected-experiment audits, including `candidate14-suspended-stack-profile-v2/calltree-scope-audit.json` and `candidate16-stop-after-user-acceptance-audit.json`, remain available without gain credit.

Final validation evidence: `candidate15-user-accepted-validation-composite-independent-audit.json` (`10414e37268c894e2a6c26b63ffee0570f8100537f091f954fb1299a92b9d7dc`), with actual auditor exit receipt `041203ebf27ae43889279b6ccae1caca3d7c616e06cc40c8b9d85abd3244e2ef`. The original broad/visual/startup controller retains outer exit 1 (`de4d89b0…`); the isolated recovery outer exit is 0 (`086b57a2…`). Its result is `final-broad-candidate15-native-redraw-isolated-recovery/result.json` (`91add75f…`).
