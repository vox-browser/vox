# Hacker News: JSC, V8 and compiled LibJS

This continues the [archived HN comparison](HACKER_NEWS_JS_ENGINES.md), adding
system JavaScriptCore and further LibJS optimizations. The workload is the
unchanged 101-comment discussion and complete author `hn.js`, with 500 complete
collapse/expand cycles. Native engines use Vox’s existing compact DOM bridge;
LibJS uses its direct native bindings. This compares browser integrations,
not isolated JavaScript throughput or browser rendering.

## Result: median 3.20×; reliable 3× remains open

The final faster-V8-control cohort gives the following medians in milliseconds.
It retains seven complete alternating groups, all exits zero and all audits valid.

| Interval | JSC | V8 control | LibJS cold | Warm restart | Warm same process |
| --- | ---: | ---: | ---: | ---: | ---: |
| Initialization | 70.449 | 73.274 | 13.075 | 14.398 | 13.492 |
| First collapse/expand | 4.690 | 3.380 | 0.934 | 1.267 | 1.326 |
| Next 500 cycles | 574.977 | 561.955 | 229.189 | 175.809 | 176.464 |
| Compile/finish checkpoint | 0.000 | 0.000 | 502.463 | 0.004 | 0.000 |
| Total measured spans | 651.906 | 638.877 | 745.476 | 191.089 | 191.042 |

The median callback ratio is **3.1964×**. The conservative ratio is only
**2.6843×**: `3 × 176,717,125 = 530,151,375 > 474,363,458` ns.
**The reliable 3× target is not achieved.** Cold compilation still dominates the
first-visit total. No browser-wide rendering or universal engine-speed claim follows.

Two earlier final-build cohorts pass their per-cohort 3× gate (3.492× and 3.419×
by callback medians). They remain valid scoped observations, but an additional
seven-pair V8 stability control exposes the limitation: previous/current V8
executable medians are 476.926/594.315 ms, with fast trials of 470.096/476.393 ms.
The adapter and libnode are unchanged. Both builds have identical normalized
vlib source hashes and matching C settings; unused LibJS code/layout and other
concurrent source changes differ. The cause of V8 timing variation is unresolved.
LibJS receives no optimization credit for slower V8 samples. The final cohort
uses `--v8-binary` to pin that previous, faster control while keeping the final
LibJS/JSC builds. Future 3× acceptance must retain these counterexamples.

The last same-binary reference-read control is 185.420 → 181.206 ms (2.27% by
medians); it cannot explain the much larger ratio shift between V8 cohorts.
On the 18-logical-CPU shared host, final cohort one-minute loads range from
10.64 to 27.10; own builds/broad tests finish before timings. Small differences
within control variation are not claimed as established gains.

Local evidence: `docs/performance/libjs-hn-3x-20261116/fast-v8-control/results.json`,
`final4-engines-{1,2}/results.json`, `references2/results.json` and
`v8-stability/results.json`. A separate `references` seed was rejected when another
session changed a pinned host source; it is retained before the corrected run.

## Scope and acceptance

Timed spans cover HTML/runtime/binding/script initialization, the first cycle,
the next 500 cycles and an explicit native-cache checkpoint. The total sums
those spans. Process startup, external network, windows, layout, painting,
PNG capture, correctness audits and teardown are excluded. Native engines
include original-origin local image replay during initialization; LibJS does
not eagerly fetch those images. Callback comparisons exclude initialization.

Every trial starts a fresh process/private profile, retaining OS caches.
Same-process warm LibJS reopens the document in the cold process; restarted
warm LibJS reparses in another process. Both warm modes use `/usr/bin/false`
as compiler and must reuse all 27 native executables with zero misses, invalid
entries, pending work or compiler invocations. Separate diagnostics establish
author-script/native-code execution; timing counters must all be zero.

Every acceptance cohort retains seven alternating complete groups and every
attempt. The conservative 3× gate uses integer arithmetic:
`3 * max(restarted_warm_callback_ns) <= min(V8_callback_ns)`.
A favorable median alone does not pass. Audits require actual first-subtree
collapse, restored class strings for all 101 rows, event cancellation without
navigation, no script errors and an empty interpreter stack. LibJS must have
no native V8/JSC context. Neither page source nor the V8 adapter was changed.

## Implementation and controls

Small ordinary calls borrow bounded stack arguments only for concrete copying
callees; custom/suspending calls and constructors preserve owning storage.
A 128-entry VM cache owns short UTF-8 inputs and their rooted UTF-16 strings.
Ordinary data reads avoid full descriptors. Fresh unpublished arrays fill own
data elements directly while String.split preserves conversion/limit order.

The current 64-bit UTF16 record shrinks from 112 to 48 bytes. Rare unchecked-byte
and IPC metadata moves to an owned optional payload; normal strings allocate no
payload. Code units, raw bytes, NUL/surrogates, IPC storage form, stale byte
projections and independent clones retain focused coverage. Native-cache ABI
keys include changed layouts and semantic helpers.

Native calls, property/binding reads and callee resolution share helpers with
the interpreter. Budgets, exception routing and suspension exits stay at the
native bridge. Frame access validates operand layout and actual buffer length
before typed access. Immediately consumed property/environment reads avoid
materializing Reference records, retaining proxy/accessor lookup order,
with-environment receivers and TDZ/missing-name errors.

The native host retains at most 256 live class collections, validating root,
exact query, document and quirks mode. It caches no membership snapshot;
mutation invalidation remains active. The [DOM standard](https://dom.spec.whatwg.org/#concept-getelementsbyclassname)
permits collection reuse for identical arguments. Direct collection traversal
removes a capturing adapter for both V8 and LibJS.

## Validation and retained limitations

The final **294-function** aggregate passes with default GC and GC disabled. It covers calls/arguments/closures, scopes/registers,
properties/proxies/accessors, budgets/throws, native cache ownership,
async/generator suspension, arrays, string splitting and UTF-16 boundaries.
The exact upstream AST corpus is 100/100; ten Python evidence-validation tests
pass. Separate class-cache/HN and DOM traversal tests pass in both GC modes.
Production String.split checks use explicit failures because production
compilation disables ordinary assertions.

This is no full-package pass or full LibJS parity claim. The earlier aggregate
baseline has unrelated class/construction/global/Intl failures. A redundant
383-file per-file sweep here was stopped after its first passing file (guard
exit 143, driver 130); logs and interruption reason remain local. Completed
focused coverage is reported separately. The compatibility compiler is not
available. An older installed bundle cannot validate code it does not contain;
these measurements use private source-built executables.

The rejected environment pool gave 298.757 → 298.639 ms, no useful gain, and was
fully reverted. Its stack-overflow/reserve experiment is also reverted. The
fresh-array control held that experiment on in both arms, isolating only array
construction. An LLVM inline-threshold 1500 compile was killed by the unchanged
12 GiB guard (exit 137, peak 12,891,848,704 bytes); it supplies no timing evidence.
Two benchmark generations were correctly rejected when an AST check regenerated
a pinned input. Driver eligibility/lowering mistakes retain failed receipts
before corrected runs. No attempts are removed to pass the target.

## Reproduction and identity

Private builds use V 0.5.2 cbfc1be, C/clang, one C unit, literal
`-prod -no-prod-options`, O3, no LTO and canonical production preallocation
(`-prealloc -gc none`). Historical Boehm/O2 rows below are labeled separately.
The build helper runs V generation and clang sequentially under the normal
12 GiB compiler guard. Actual C, exact parsed-buffer hashes, sealed native
inputs/link objects and compiler commands remain local beside each binary.

JSC binds `JSGlobalContextCreate`/`JSEvaluateScript` to system JavaScriptCore;
V8 binds them to the existing adapter. Receipts retain `nm`, linkage,
`sw_vers`, host CPU/load/timestamps and executable/native-library/fixture hashes.
V8 is 14.6.202.34-node.40, libnode 147 (Node 26.13.0_2).
Adapter SHA-256: `ad7196770fb36f755bdce1c89d759b811c377205f9921ab580015781e9e3ffeb`.
libnode SHA-256: `a65e29cb28c58d17ecaace4e3dc9ae2cd98cd9d65b59b2a00a972872e4d513ef`.
HN script SHA-256: `2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0`.
HTML SHA-256: `04bfd8b86c3a9098e4e4a8428e65142e4144d5f8184d66b802b26243baf19c07`.

Initialize canonical test links with `tools/test_address_bar.sh` as in the
original report. Build each backend under its own 12 GiB guard, outside Build:

```sh
python3 tools/build_hn_engine_benchmark.py --engine v8 --output PATH/hn-v8 \
  --v8-adapter PATH/libVoxJSCOnV8.dylib
python3 tools/build_hn_engine_benchmark.py --engine jsc --output PATH/hn-jsc
```

Run each comparison under the 3 GiB runtime guard:

```sh
sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
  --lock Build/hn-engines-UNIQUE.lock --report Build/hn-engines-UNIQUE.json -- \
  python3 tools/benchmark_hn_engines.py \
    --binary PATH/hn-v8 --jsc-binary PATH/hn-jsc \
    --output docs/performance/hn-engines-UNIQUE \
    --pairs 7 --cycles 500 --target-v8-speedup 3
```

## Retained cohort statistics

Callback medians in ms; each row retains seven alternating complete groups.

| Cohort | JSC | V8 | Cold | Warm restart | Warm same process | 3× gate |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| First JSC, Boehm/O2 | 647.310 | 616.722 | 327.437 | 306.749 | 357.265 | fail |
| Preallocation/O2 | 561.568 | 499.379 | 242.931 | 214.589 | 216.369 | fail |
| Class cache + walk/O3, 1 | 576.960 | 540.144 | 235.744 | 202.255 | 203.806 | fail |
| Class cache + walk/O3, 2 | 587.966 | 506.986 | 237.973 | 207.270 | 204.372 | fail |
| Compact strings + handlers, 1 | 553.917 | 512.020 | 232.919 | 184.741 | 185.165 | fail |
| Compact strings + handlers, 2 | 556.288 | 485.887 | 232.641 | 183.722 | 184.248 | fail |
| Final current V8, 1 | 600.152 | 636.874 | 239.947 | 182.381 | 182.028 | pass |
| Final current V8, 2 | 556.987 | 596.155 | 226.808 | 174.357 | 175.223 | pass |
| Final faster V8 control | 574.977 | 561.955 | 229.189 | 175.809 | 176.464 | fail |

Matched control/candidate/V8 triplets, callback medians in ms. These are not
additive gains across different allocator/build cohorts.

| Control | Before | After | V8 |
| --- | ---: | ---: | ---: |
| Borrow small arguments | 311.102 | 304.602 | 615.440 |
| Short-string cache + data reads | 307.294 | 298.341 | 579.393 |
| Fresh array storage | 300.106 | 295.156 | 642.103 |
| Live class collection cache | 212.815 | 204.340 | 663.377 |
| Direct collection traversal, O2 | 206.166 | 200.999 | 662.216 |
| Direct collection traversal, O3 | 204.230 | 200.306 | 673.208 |
| 112 → 72-byte UTF16 records | 198.877 | 192.401 | 578.530 |
| Shared handlers, 48-byte strings | 190.276 | 186.891 | 586.511 |
| Checked typed frames + inline slots | 188.516 | 187.480 | 535.666 |
| Immediate object/environment reads | 185.420 | 181.206 | 610.568 |

Final separate diagnostics record 185,871 native entries, 1,675,845 fast and
902,802 helper steps, including 800,097 direct handler steps and 460,419 compact
reference reads. They also record 314,628 borrowed calls, 77,141 short-string
cache hits, 470,940 direct data reads, 55,110 fresh-array operations, 17,024 class
collection hits and 13,527 direct DOM collection walks. Timed counters are zero.

Final LibJS/V8 test executable SHA-256:
`3f609328943f95db5546a62b9b1edb6680b3f4d15c4469e79fac820790853962`.
JSC executable SHA-256:
`070005e9364a36c24de01ab22140a4b1311e6ffe863cda5677d8322d8ef56c0c`.
Both consumed exactly the same parsed source manifest, SHA-256:
`842c25d24d7c21f7b0d0d9d1cc8d13a98bb8fb30882bef6a952ccefe823efc8b`.

Completed checks: default/no-GC aggregate guard exits 0, 103.261/103.074 s,
peaks 9,084,747,776/9,067,069,440 bytes under 12 GiB. Final V8/JSC builds exit 0,
231.766/232.818 s, peaks 8,492,482,560/8,524,136,448 bytes. The three completed
final full cohorts (`final4-engines-1`, `final4-engines-2`, `fast-v8-control`)
each retain all 32 processes, driver/guard exits 0; guard durations are
32.490/29.858/32.122 s and peaks 922,927,104/917,471,232/924,925,952 bytes under
3 GiB. The reference control and V8 stability control also exit 0. Completed
Build guard receipts move to the local `guards/` directory and their locks
are removed.

The faster V8 control is selected with `--v8-binary PATH/hn-final3-v8`; its
identity and framework/adapter linkage are pinned separately from the final
LibJS executable. This option changes no timing or audit boundary.

A fresh installed production process passes `--headless-smoke` with unchanged
binary/library identities, exit 0. It is baseline JSC startup evidence only:
executable SHA-256 `c07ab59e250e33d50729886dfa0733d9a07070787c11dd4b7aabd288e2ef6a28`.
The native LibJS changes are exercised by the private source builds above.
Feature commits request coalesced C/single-unit/literal `-prod` rebuilds through
the managed post-commit hook; no extra manual production build is queued.
