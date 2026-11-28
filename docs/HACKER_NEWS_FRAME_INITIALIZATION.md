# Hacker News: reused call-frame initialization

The subsequent [call-argument copy report](HACKER_NEWS_ARGUMENT_COPIES.md) records
the latest comparison and its additional net-change control.

Measured 2026-11-16/17, following [native indexed reads](HACKER_NEWS_NATIVE_PROPERTY_READS.md).
The retained change replaces generic array setters with bounded typed stores for
reserved slots and a bulk copy for nonoverlapping constants in reused frames.
Aliased constants keep the original reserved-reset and forward-copy order.
Frame selection, clearing, public exposure barriers, pool bounds and budgets are
unchanged. Fresh allocations retain their existing initialization path.

The longer matched diagnostic has **2.42% lower median calling-thread CPU time**,
with all seven pairs improving. **RAM passes at 48.7291% of V8; the strict 4×
wall-time target remains open.**

## Matched controls

Both configurations run the same executable and all prior optimizations. The
test-only `VOX_LIBJS_DIRECT_CONTEXT_INIT` switch selects legacy generic setters or
the bounded direct initialization. Separate eligibility diagnostics cover the
first audited cycle plus the callback loop; counters are disabled during timing.

| Diagnostic counter, first cycle plus 500 cycles | Control | Candidate |
| --- | ---: | ---: |
| Native entries | 185,871 | 185,871 |
| Native fast steps | 1,780,554 | 1,780,554 |
| Generic slow steps | 798,093 | 798,093 |
| Reused frames | 417,313 | 417,313 |
| Allocated frames | 20 | 20 |
| Exposed frames | 0 | 0 |
| Direct frame initializations | 0 | 417,313 |

| Callback thread-CPU diagnostic | Control median | Candidate median | Pairs improving |
| --- | ---: | ---: | ---: |
| 500 cycles | 113.882 ms | 112.154 ms | 6/7 |
| 2,500 cycles | 586.359 ms | 572.152 ms | 7/7 |

The longer run's ratio of medians is 2.42% lower, and its median paired reduction
is 1.63% (range 0.70–5.15%). The shorter run's ratio of medians is 1.52% lower;
its median paired reduction is 0.86%, with one 2.43% regression. These are modest
same-engine CPU results. They do not establish a general JavaScript speedup or
replace the wall-time acceptance gate.

The optional clock brackets the existing callback wall-clock markers and counts
only the calling thread, including those marker reads. Scheduling waits and other
threads are excluded; it cannot measure V8/JSC whole-engine CPU cost. The longer
workload was scheduled before collection and supplies no 500-cycle acceptance
credit. All samples, including regressions, are retained.

## Latest comparison

Seven `frames-current` groups supply timing medians; a separate seven-group
`frames-memory` cohort supplies RAM medians. Times are ms, peak RSS is MiB, and
total medians need not equal sums of individual column medians.

| Mode | Initialize | First cycle | 500 cycles | Compile/finish | Total | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| V8 | 76.233 | 3.655 | 636.577 | 0.000 | 716.593 | 725.03 |
| JSC, pinned baseline | 73.877 | 5.009 | 620.095 | 0.000 | 698.547 | 588.22 |
| LibJS cold | 12.881 | 0.806 | 137.272 | 504.091 | 655.019 | 247.48 |
| Compiled LibJS, restart | 14.153 | 1.154 | 118.312 | 0.005 | 133.565 | 245.30 |
| Compiled LibJS, same process | 13.029 | 1.145 | 111.702 | 0.000 | 126.250 | 353.08 |

The matching-current V8/restarted-warm median ratio is **5.3805×**. The strict
gate retains two seven-group cohorts with the older faster V8 executable and one
seven-group matching-current cohort:

* Speed fails for both warm modes: `4 * 165,219,125 > 540,320,208` ns. The
  conservative ratio is **3.2703×**; the pooled restarted-warm median ratio is
  5.0234×. No outlier or unsuccessful cohort is excluded.
* RAM passes for both warm modes:
  `100 * 370,311,168 <= 50 * 759,939,072` bytes, or **48.7291%**. This compares
  the highest compiled peak with the lowest V8 peak, not a reduction of LibJS's
  own previous memory use.

All final benchmark and guard exits are zero, and 28 common pinned inputs match
across the three speed cohorts and the RAM cohort. The 18-CPU M5 Max recorded
one-minute load of 4.64–8.16 during those timed attempts. Cross-cohort timing
changes are not attributed to this optimization; the same-executable controls
above supply the isolated comparison.

## Scope and rejected experiment

The [existing protocol](HACKER_NEWS_NATIVE_PROPERTY_READS.md) remains unchanged:
the archived 101-comment discussion, complete original `hn.js`, 500 complete
collapse/expand cycles, fresh private processes/caches and retained OS caches.
The measured script/DOM spans exclude process startup, final audits, windowing,
layout, paint and teardown. V8/JSC use the compact DOM bridge and eagerly prepare
replayed image hosts during initialization; LibJS uses native DOM bindings.
These are integration results, not isolated JavaScript, rendering or full browser
launch measurements. RAM is root-process `RUSAGE_SELF` through the post-cache-finish
checkpoint; compiler/replay/wrapper processes are covered separately by the guard.

Both warm modes require 27 cache hits, zero misses/invalid/pending entries and no
compiler invocation, with `/usr/bin/false` configured. Content, cancellation,
native execution and absence of native-engine fallback are separately verified.
The reused JSC baseline has identical common browserjs/compact/DOM/HTML V sources;
it cannot validate new LibJS implementation code.

An earlier numeric-property-key conversion experiment was **reverted**. Its
500-cycle thread-CPU medians were 111.310 → 110.875 ms, but its 2,500-cycle medians
were 563.942 → 569.207 ms. That mixed result did not justify retaining the path.
Its complete 21-group speed result was 3.7298× conservatively, with RAM passing;
all evidence remains separate under `libjs-hn-numeric-20261116`.

A separate delayed whole-process profile identified frame reuse and generic
array stores as hot work. An initial sample attached during dyld startup and had
no browser image list; it is retained as inconclusive. The delayed sample has the
expected executable image and runtime symbols. Neither profile supplies timing
acceptance or optimization percentages.

Validation: **47 focused tests** pass under current V with default GC, `-gc none`
and preallocation, with assertions enabled. They cover layout boundaries, zero
and short buffers, aliased constants, live heap values, exact budgets, fresh-VM
compiler-free reuse, escaped frames/views, pool limits and under-4-KiB growth for
10,000 reused calls. All **19 Python evidence/clock tests** pass. The unchanged
parser's AST comparison was **100/100 exact** in the same optimization run.
These checks leave the separate broad-suite verification status and language/DOM
parity limits in [PORT_STATUS.md](../libjs/PORT_STATUS.md) unchanged.

## Local receipts

`docs/performance/libjs-hn-frames-20261116/` retains the prospective `plan.json`,
all attempts, guard reports, `frames-analysis.json`, `cpu-analysis.json`, focused
checks and source identities. Numeric experiment receipts and both profiles remain
under `docs/performance/libjs-hn-numeric-20261116/`. Generated JSON remains local.
Completed older generated compiler inputs were retired after hashing to recover
disk space; measured executables and build receipts remain available.

The final `bin/hn-frames-v8` SHA-256 is
`cb3905a6ae154ec0b290de1be16bb93aabaf542fefcd04351f4be9ca33f64e86`.
It uses one sealed C unit, production V, `-O3`, preallocation and GC disabled;
generated native libraries retain `clang -O2 -std=c11 -fno-strict-aliasing`.
C mode, compiler optimization flags, capture boundaries and correctness
tolerances were not changed for credit. The pinned JSC and older V8 identities
remain those in the linked previous report.

Reproduce with the canonical tools under the memory guard and unique outputs:
`tools/benchmark_hn_property_lookup.py --optimization frame-initialization
--pairs 7 --cycles 500 --callback-thread-cpu`, with `--cycles 2500` for the longer
diagnostic. The five-mode cohorts use `tools/benchmark_hn_engines.py --pairs 7
--cycles 500 --target-v8-speedup 4`; the separate RAM cohort adds
`--memory --target-v8-memory-percent 50`. Supply the pinned executables through
`--binary`, `--jsc-binary` and the older-control cohorts' `--v8-binary`, as recorded
in the local plan.
