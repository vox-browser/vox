# Hacker News: compiled LibJS speed and RAM

This continues [the JSC/V8 comparison](HACKER_NEWS_JSC_COMPARISON.md).
The requested target is three times V8's speed on the unchanged archived
101-comment discussion's 500 collapse/expand cycles. This is Vox's script/DOM
integration benchmark, with the original complete `hn.js`; it excludes windows,
layout, painting and screenshot capture. It is not universal JavaScript or
browser-rendering performance.

**The scoped 3× target passes:** the two final seven-group cohorts give a
**3.0815× conservative callback ratio**, retaining all 14 warm and 14 V8 trials.
The exact integer check is
`3 × 198,544,167 = 595,632,501 ≤ 611,811,209` ns.
The pooled median callback ratio is 4.6355×. Every measured process and guard
exited zero; engine/DOM/cache audits and unchanged input identities passed.

The following table uses the separate seven-group **matching-current-build**
timing cohort, with RAM medians from its separate seven-group memory cohort.
Times are milliseconds; RSS is MiB. Totals are medians of each visit’s summed
spans, so they need not equal sums of column medians.

| Mode | Initialize | First cycle | 500 cycles | Compile/finish | Measured total | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| V8 | 107.179 | 5.395 | 993.676 | 0.000 | 1096.633 | 738.44 |
| JSC | 98.172 | 6.611 | 977.154 | 0.000 | 1080.376 | 601.88 |
| LibJS cold | 18.917 | 1.173 | 224.020 | 588.116 | 831.858 | 306.62 |
| Compiled LibJS, restart | 21.840 | 2.105 | 213.502 | 0.005 | 237.851 | 313.14 |
| Compiled LibJS, same process | 19.897 | 1.811 | 214.444 | 0.000 | 236.532 | 480.17 |

Current-build callback ranges are V8 842.395–1102.335 ms, JSC
805.042–1215.228 ms, cold LibJS 203.602–248.001 ms, restarted warm
164.992–225.620 ms and same-process warm 167.025–216.536 ms.
The faster-control acceptance cohorts span V8 611.811–1323.552 ms and
restarted warm 148.531–198.544 ms. Their one-minute host loads range
8.11–8.89 on 18 logical CPUs. Other sessions remained active.

Warm restart’s peak is 42.4% of V8’s observed process peak. The same-process
row retains cold compilation/allocation history and is consequently larger.
Cold LibJS still pays its explicit 27-body compilation checkpoint.

These are pinned-build observations under the recorded shared-host conditions.
Earlier failures remain below and in the linked historical report; the result
does not guarantee 3× on every host/load. The cross-build dispatch control
measured 175.313 → 167.720 ms by medians, but ranges overlap and some pairs
regress. It establishes allocation avoidance, not an independently proven
4.3% CPU improvement. Larger ratios between cohorts receive no optimization
credit from slower V8 or changed host load.

The private executables use one sealed C unit, `-O3`, production V code,
Vox's bounded preallocation runtime and GC disabled. Both native backends use
the same C mode and unchanged V8 adapter/libnode. V8 reports
14.6.202.34-node.40; system JavaScriptCore is 22625.2.8.11.9 on macOS 27.2
(26B123). Source manifests and completed frozen-compile receipts pin actual
parsed inputs; trials also hash binaries, fixtures, native libraries and tools.
They do not depend on mutable working-tree V files during measurement.

Final executable SHA-256 identities:

```text
hn-borrow-v8   74ac5502752f28ff89432a7a8b78b227f03ff7bca0e4377ee5e90dfe67e92729
hn-borrow-jsc  ed2fba46527686a07e59ec8fc8f2a790c3f82df2818beb122cbd0ecd18925e3f
V8 adapter    ad7196770fb36f755bdce1c89d759b811c377205f9921ab580015781e9e3ffeb
libnode       a65e29cb28c58d17ecaace4e3dc9ae2cd98cd9d65b59b2a00a972872e4d513ef
```

The source-built private executables validate this component workload. The
shared production bundle was reused as applicable infrastructure; its older
executable cannot validate these source changes. Feature commits request the
managed, coalesced production rebuild without a duplicate manual build.

## Measurement boundaries

Callback time covers 500 complete synchronous collapse/expand cycles after the
first audited cycle. Total time sums initialization, that first cycle, the next
500 cycles and the explicit compile/cache-finish checkpoint. Startup, final
correctness audits, external network and teardown are outside those timers.
Native engines replay the original images locally during initialization;
LibJS does not eagerly fetch them. Callback comparisons avoid that difference.
Native engines use the existing compact DOM bridge; LibJS uses native bindings.

Each trial starts a fresh process and private profile, retaining OS caches.
Cold LibJS interprets and then compiles 27 function bodies at the explicit
checkpoint. Warm restart reuses their native libraries in a new process;
same-process warm also retains parsed-source state. Both warm modes require
all 27 cache hits, zero misses/invalid/pending entries and zero compiler calls,
with `/usr/bin/false` installed as compiler. Separate instrumented diagnostics
prove native entry execution and absence of V8/JSC fallback. Timed diagnostics
must all be zero. Audits require cancellation without navigation, actual first
collapse, all 101 class strings restored, no errors and an empty VM stack.

The predeclared acceptance consists of two seven-group alternating cohorts.
It retains every attempt, outlier and failure. The combined integer gate is
`3 * max(all restarted-warm callback ns) <= min(all V8 callback ns)`.
The V8 control is the previously faster `hn-final3-v8`; a separate comparison
uses matching current V8 and JSC builds. Previous failures remain evidence;
favorable medians or slower V8 samples alone earn no optimization credit.
Own compilers/broad checks finish before timing. Host contention is recorded.

RAM comes from a separate seven-group `--memory` cohort using the same current
binaries and workload. Each row reports **root-process peak resident bytes from
startup through its visit checkpoint**, immediately after cache finish and
before final audits. Compiler children, replay and measurement wrappers are
excluded. Same-process warm retains the cold visit's allocation history.
MiB means 1,048,576 bytes. These are complete benchmark-process peaks, including
Vox's common runtime infrastructure; they are not isolated engine heaps.

The optional self-RSS checkpoint is off in timing cohorts. An external `wait4`
receipt also preserves actual PID, exit, CPU accounting and final peak RSS.
On macOS that final peak can include the largest reaped compiler child: it is
explicitly labelled compiler-inclusive, is not aggregate process-tree RAM,
and is **not** the RAM table's metric. A forked 64 MiB child test checks the
root-only distinction and byte units. Memory cohorts cannot pass the speed gate.

## Runtime changes

`Value` now shares its mutually exclusive number/cell payload: 24 → 16 bytes,
including an exact generated-native-C size/offset check. Tags, negative zero,
NaN/infinity, cells, mixed calls and heap roots have focused coverage. The
context-pool test derives its oversized input from bytes so its 1 MiB cap stays
unchanged as values shrink.

`PropertyName` becomes a 16-byte tagged payload instead of an 80-byte record.
Ordinary construction owns a UTF-16 header; primitive-string conversion retains
the immutable cell's first-field header. Equality compares key contents, symbol
identity and numeric indices, including V's `==` and array equality. A bounded
VM fly-string cache reuses short binding-name headers without caching binding
values or absence. Empty/default keys, numeric boundaries, cache eviction and
collection survival retain coverage. Native cache identity includes the key ABI.

Compact binding reads skip empty concrete function/declarative environments
and read live own data on ordinary globals. Lexical shadowing, accessors,
proxies, host/exotic objects, prototypes and with-environment receivers keep
the existing observable operations and order.

Ordinary reads can dispatch a selected accessor without constructing another
full descriptor or searching for the same cell again. Both paths share holder
cache eligibility and the post-callback identity check. Ordinary setters and
own writable data writes similarly avoid descriptor round trips; foreign and
exotic receivers retain checked definition. No property value is cached.

`Function.prototype.call` can forward its owned frame's argument tail to the
existing concrete callees that copy arguments before executing author code.
Custom, proxy, bound and suspending callees retain owned slices. Array `indexOf`
combines `HasProperty`/`Get` only for live own ordinary data, preserving the
original instruction-budget charge; absence, accessors and exotics use the
original protocol. Their individual median shifts were within variation.

Private synchronous frames can retain an empty function environment in the
existing 64-frame, 1 MiB pool. Reuse clears this/new-target, function, outer,
class, private and home-object references. Closure creation, public frame or
environment exposure, retained references, root inspection and child/replaced
lexical scopes protect the old environment. Native frames carry a separate
caller marker so their exposure also protects the caller. Nonempty bindings,
escaped frames and suspensions retain fresh storage. Cached environment bytes
count toward the unchanged pool limit and cached records appear in heap roots.

Same-binary switches and diagnostic counters establish path eligibility before
unprofiled alternating control/candidate/V8 runs. The earlier value/key layout
controls are within host variation; their small median shifts are not claimed
as established speed gains. The binding control measured 221.321 → 207.578 ms
by callback medians. Its first full faster-V8-control cohort still failed the
conservative gate, despite a favorable median; the next passed at 3.606×.
These observations preceded the accessor change and are retained.

The two later `forward-fast-*` cohorts each passed individually, but their
combined gate failed: `3 * 182559667 > 535478167` ns (2.933×). No slow sample was
removed. This failure motivated environment reuse. A prepared native operand
cache was also implemented, checked and discarded: its cross-build median
regressed 132.146 → 137.159 ms. Its favorable full-comparison ratios under
lighter load do not earn optimization credit. The rejected patch and results
remain local.

The `env-fast-*` cohorts also passed separately and failed jointly:
`3 * 288792709 > 697718750` ns (2.416×). The same-build environment control was
241.743 → 236.525 ms with overlapping ranges; the cross-build control retained
a 640.170 ms candidate outlier. These do not establish an isolated CPU gain.
The separate RAM cohort reduced restarted-warm process peaks from the prior
360.16 MiB to 320.97 MiB. Dispatch allocation work followed this failure.

The concurrent dispatch fix in `6c43920fb` borrows checked executable instruction
records rather than making V heap-copy every dispatched instruction. The next
sealed builds include that commit and the runtime changes above. A cross-build
control keeps all other optimization switches enabled in both binaries; its
native-entry diagnostics and generated-C inspection accompany timing. This
shared fix is identified separately from the environment-reuse control.

## Verification and retained failures


The final assertion-enabled aggregate passes **134 functions with default GC
and the same 134 with GC disabled** (`env4-default` / `env4-none`, all actual
guard/child exits zero). It covers compact values/keys, native helpers, budgets,
proxy/getter ordering, call retention, context/environment lifetime, arguments,
closures, bound calls, constructors and super. Its compiled runtime includes
the concurrent borrowed-instruction change. A separate production-allocator
regression passes 100,000 interpreter dispatches and 100,000 native fallback
dispatches with less than 4 KiB retained growth per path, with assertions enabled.
The 100 upstream AST fixtures compare exactly. All 14 Python benchmark checks
pass, including sealed build identity, actual child exits and RAM units/scope.
Python syntax checks pass for both comparison drivers.

A diagnostic aggregate of 1,494 checks is not green. It exposed and led to a
fix for key-array equality. Nine older optional-boolean assertions needed
explicit unwrapping. An import-meta fixture unsafely cast `VM **` to `VM *`;
it now constructs its immutable string without that cast. The initial default
aggregate exited 138 at that fixture. The subsequent no-GC aggregate reached
the 12 GiB guard (benchmark/child exit 125/137), after reporting failures in
block-function iteration, stale unsupported-feature/global-order expectations,
locale/date formatting and host promise-job budgets. Those broader results
are retained and do not establish full runtime parity.

A super-property fixture declared the same top-level classes twice in one VM.
Both environment-reuse settings correctly rejected its second declaration.
The second case now uses distinct class names while retaining its tagged-super
assertion. A first final-check invocation accidentally listed its last file
twice and was rejected during compilation; the corrected invocation excludes
that duplicate. Neither attempt is described as a runtime failure.

An initial focused compile exceeded its 3 GiB cap; compilation was rerun with
the normal 12 GiB compiler guard. Another focused development run failed a
compiler-disabled revisit when shared native-cache ABI sources changed during
execution. A production-mode test attempt was discarded because this compiler removes
assertions and their side effects. The final checks keep assertions enabled;
the concurrent development-cache fix binds its ABI to executable identity.
The no-GC follow-up is split to bound the cost of repeated executable reads. Two
initial private builds were rejected after another session changed a pinned
build input. No rejected result contributes performance credit.

Local raw evidence is under `docs/performance/libjs-hn-ram-3x-20261116/`:
`values-control`, `keys-control`, `bindings-control`, their full comparison and
RAM cohorts, `accessors-*`, `forward-*`, `env-*`, all test/build logs, source
manifests and `guards/`. The earlier
report's failures and V8 stability counterexamples remain linked there too.
Generated JSON, binaries and C remain local; only this summary is committed.
Completed superseded generated C/preprocessed inputs were retired to bound
disk usage; their hashes and sizes are in `retired-generated-artifacts.json`.
Measured binaries, complete configuration/source/frozen-build receipts and raw
measurement results remain available.

## Reproduction

Build private executables with `tools/build_hn_engine_benchmark.py`, once with
`--engine v8 --v8-adapter PATH` and once with `--engine jsc`, under the normal
12 GiB compiler guard. The final configurations are in
`bin/hn-borrow-{v8,jsc}.build/configuration.json` beneath the evidence root.
Keep all own builds/checks finished before timings. For example, using the
retained executables (choose new output and guard names for every attempt):

```sh
evidence=docs/performance/libjs-hn-ram-3x-20261116
sh tools/run_v_tool.sh run_memory_bounded \
  --lock Build/hn-CUSTOM.lock --report Build/hn-CUSTOM.json --limit-gib 3 -- \
  python3 tools/benchmark_hn_engines.py \
  --binary "$evidence/bin/hn-borrow-v8" \
  --jsc-binary "$evidence/bin/hn-borrow-jsc" \
  --v8-binary docs/performance/libjs-hn-3x-20261116/bin/hn-final3-v8 \
  --output "$evidence/CUSTOM" --pairs 7 --cycles 500 --target-v8-speedup 3
```

Run two predeclared acceptance cohorts and recompute the combined integer gate
from every uninstrumented warm/V8 visit. `borrow-acceptance.json` retains the
14 exact counts and decision. Omit `--v8-binary` for matching-current builds;
add `--memory` in a separate cohort for RSS. Memory cohorts deliberately cannot
pass the speed gate. `borrow-{control,fast-1,fast-2,current,memory}/results.json`,
the plans/commands, actual process receipts and guard logs retain every attempt.
