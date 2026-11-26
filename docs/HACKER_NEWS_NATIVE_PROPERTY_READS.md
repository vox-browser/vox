# Hacker News: compiled property-read continuation

The subsequent [call-frame initialization report](HACKER_NEWS_FRAME_INITIALIZATION.md)
contains the latest comparison and records the rejected numeric-key experiment.
The property-read measurements below remain historical evidence.

This follows [the 4×/50% comparison](HACKER_NEWS_LIBJS_4X.md). Guarded native
indexed reads replace **13,026 generic slow steps** in the eligibility diagnostic
without changing total JavaScript instruction or native-entry counts. The longer
matched diagnostic has **2.7% lower median calling-thread CPU time**, with six of
seven pairs improving. This is a modest, workload-specific result with retained
regressions. **The 50%-of-V8 RAM gate passes; the strict 4× wall-time gate remains
open.**

## Implementation and matched controls

Compiled property plans resolve operand slots without embedding realm values or
addresses in cached machine code. Guards check live instructions, slot layout,
backing storage and keys. Slow property reads retain conversions, nullish error
order, getters, proxies, exception dispatch and post-getter destination lookup.

The native indexed operation reads current own numeric data cells directly.
Small objects use allocation-free lookup; larger objects require an existing,
live-key-validated position hint. Holes, inherited properties, accessors, proxies,
typed arrays, arguments, string wrappers and host/legacy providers use the VM.
Generated C charges successful operations against the shared budget exactly once.
Rejected operations retain the ordinary error and budget path. This removes a
generic VM slow step while retaining a narrow runtime guard/lookup callback.

The separate diagnostic covers the first audited cycle plus 500 callback cycles:

| Counter | Indexed lowering disabled | Enabled |
| --- | ---: | ---: |
| Native entries | 185,871 | 185,871 |
| Native fast steps | 1,767,528 | 1,780,554 |
| Generic slow steps | 811,119 | 798,093 |
| Native indexed reads | 0 | 13,026 |

Both totals are 2,578,647 steps. This replaces 26 slow steps per cycle, or 1.61%
of the old slow-step count. These are VM counters, not hardware instructions.
Diagnostics are disabled in timing cohorts; content/cancellation audits and
complete compiler-free native-cache reuse pass in both configurations.

| Matched CPU diagnostic | Control median | Candidate median | Pairs improving |
| --- | ---: | ---: | ---: |
| 500 cycles | 203.924 ms | 195.759 ms | 4/7 |
| 2,500 cycles | 817.559 ms | 795.234 ms | 6/7 |

The longer cohort's ratio of medians is 2.73% lower; its median paired reduction
is 7.61%. One pair regresses 2.83%. The shorter cohort's ratio of medians is 4.00%
lower, but its median paired reduction is only 1.24%. Ranges overlap. These
observations do not establish a stable wall-time gain or a general engine speedup.

The optional CPU clock brackets the existing callback wall-clock markers. It
counts the calling thread, including those marker reads, and excludes scheduling
waits and other threads. It cannot establish V8/JSC whole-engine CPU costs. The
2,500-cycle diagnostic was scheduled before measurement and supplies no credit
to the unchanged 500-cycle wall-time or RAM gates.

## Latest five-mode comparison

Medians below use seven `index-current` timing groups and a separate seven-group
`index-memory` cohort. Times are ms; peak RSS is MiB. Total medians need not equal
the sums of column medians.

| Mode | Initialize | First cycle | 500 cycles | Compile/finish | Total | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| V8 | 95.633 | 4.414 | 710.182 | 0.000 | 813.241 | 725.03 |
| JSC, pinned baseline | 88.086 | 5.884 | 832.046 | 0.000 | 926.135 | 588.12 |
| LibJS cold | 16.362 | 1.001 | 180.401 | 601.561 | 798.930 | 247.50 |
| Compiled LibJS, restart | 18.504 | 1.454 | 152.921 | 0.005 | 173.618 | 245.31 |
| Compiled LibJS, same process | 16.886 | 1.458 | 152.690 | 0.000 | 170.171 | 353.06 |

The matching-current V8/restarted-warm median ratio is **4.6441×**. Compilation
improves the cold/restarted-warm callback median by only **1.1797×**: shared runtime
and DOM work still dominate much of this integration workload.

The unchanged speed gate combines two seven-group cohorts with the older faster
V8 control and one seven-group matching-current cohort. Every trial is retained:

* Restarted warm fails: `4 * 203,063,792 > 527,161,958` ns, a conservative
  highest-warm/lowest-V8 ratio of **2.5960×**.
* The stronger both-warm check also fails: its highest callback is 237,133,667 ns,
  giving **2.2231×**. The pooled restarted-warm median ratio is 4.7531×.
* RAM passes for both warm modes:
  `100 * 370,245,632 <= 50 * 760,020,992` bytes, or **48.7152%**. This compares
  the highest compiled peak with the lowest V8 peak, rather than claiming a 50%
  reduction of LibJS's own previous memory use.

All final benchmark and guard exits are zero. Twenty-eight common pinned inputs
match across the three speed cohorts and RAM cohort. On the 18-CPU M5 Max, timed
attempts record one-minute load between 8.06 and 10.52; these are not quiet-host
measurements. The older failed cohorts remain separate evidence, not discarded
outliers or optimization credit.

## Scope, retained experiments and checks

The archived 101-comment discussion, complete unchanged `hn.js`, 500 full
collapse/expand cycles, private processes/caches and OS-cache policy are unchanged.
The existing protocol excludes process startup, final audits, windowing, layout,
paint and teardown. V8/JSC use the compact DOM bridge; LibJS uses native DOM
bindings. Native engines eagerly prepare replayed image hosts during initialization.
The results therefore compare this script/DOM integration, not isolated JavaScript
throughput, rendering or browser launches. RAM is root-process `RUSAGE_SELF`
through the post-cache-finish checkpoint; compiler/replay/wrapper processes are
excluded from that statistic and covered separately by the memory guard.

Both warm modes require 27 cache hits, zero misses/invalid/pending entries and
zero compiler invocations with `/usr/bin/false`. Separate diagnostics establish
native execution with no native-engine fallback. The JSC baseline's 727 common
browserjs/compact/DOM/HTML V sources match the final build exactly; it cannot
validate new LibJS code.

The earlier operand-plan cohort has wall medians 238.622 → 235.576 ms with
overlapping ranges. The subsequent object/string-key wrapper refinement has
thread-CPU medians 164.348 → 164.963 ms. Neither establishes an isolated gain.
Their retained 21-group conservative speed ratios are respectively 2.5993× and
3.2222×. Guarded native string/array `.length` reads also pass focused tests, but
HN's collapse path records **zero** such native steps: the eligibility gate rejects
that comparison before its first timed pair. No HN gain is attributed to it.

Validation: 35 focused native/property/cache tests pass with current V under
default GC, `-gc none`, and preallocation. Assertions are enabled. Coverage includes
exact budget exhaustion, getters/reentry/unwinding, numeric-key edge cases,
changed layouts/storage/keys, compiler-free fresh-VM reuse and allocation guards.
The AST corpus remains 100/100 exact; all 19 Python evidence/clock checks pass.
These checks do not establish full LibJS parity or replace the separate broad-suite
verification status in [PORT_STATUS.md](../libjs/PORT_STATUS.md).

## Reproduction and local evidence

Local receipts, commands, every attempt, guards and analyses are retained under
`docs/performance/libjs-hn-property-20261116/`; generated measurement JSON remains
untracked. `index-plan.json`, `index-analysis.json`, `index-cpu-analysis.json`,
`index-focused-checks.json` and `index-source-verification.json` record the final
protocol and checks. `property2-analysis.json`, `object-analysis.json` and
`length-eligibility/results.json` retain earlier outcomes. One initial private
build was rejected because an AST diagnostic changed a generated input; it supplied
no timing evidence and was rebuilt with a fresh receipt.

The measured LibJS/current-V8 executable is `bin/hn-index-v8`, built as one sealed
C unit with production V, `-O3`, preallocation and GC disabled. Generated native
libraries retain `clang -O2 -std=c11 -fno-strict-aliasing`. No C mode, LLVM inlining
threshold, workload boundary or correctness tolerance changed to obtain credit.

| Executable | SHA-256 |
| --- | --- |
| LibJS/current V8 | 9abfebfc032961a6ba30c379ebd86b07fd642d57c5f7c4119fb47e79a4336731 |
| Pinned JSC baseline | 04dc49df9638605874eed4a7c6a9fd0c4448dd5c0a3e9e233d703365fe62e0bf |
| Older faster V8 | 566764a299a9b8829d7cd8705665bb615158bd86dcec4f6f67e7b0e92bdc40bf |

Use the canonical tools under the memory guard, with unique output/lock/report
paths. The focused runtime comparison uses
`tools/benchmark_hn_property_lookup.py --optimization native-index --pairs 7
--cycles 500 --callback-thread-cpu`; the longer diagnostic uses `--cycles 2500`.
Five-mode and separate RAM comparisons use `tools/benchmark_hn_engines.py` with
`--pairs 7 --cycles 500 --target-v8-speedup 4`, adding
`--memory --target-v8-memory-percent 50` only to the memory cohort. Supply the
pinned executables through `--binary`, `--jsc-binary` and, for older-control
cohorts, `--v8-binary`, as recorded in the local plan.
