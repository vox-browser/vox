# Hacker News: private call-argument copies

Measured 2026-11-17, following [frame initialization](HACKER_NEWS_FRAME_INITIALIZATION.md).
The subsequent [V profiler investigation](HACKER_NEWS_V_PROFILE.md) rejects two
additional candidates after mixed results and severe host contention.
ECMAScript and native calls now initialize their private argument slots with
bounded typed stores for small lists and bulk copying for larger disjoint lists.
Overlapping input retains the old forward-copy order. Public setters, argument
views, exposure barriers, pool selection/limits and execution budgets are unchanged.
Invalid layouts return to the original checked setters.

The preceding-build comparison records **1.27% lower median calling-thread CPU**,
with six of seven pairs improving. One substantial regression is retained; this
is a small workload-specific observation, not a stable wall-time guarantee.
**RAM passes at 48.7143% of V8; the strict 4× speed gate remains open.**

## Matched controls and net comparison

The same-executable control uses legacy per-argument setters via the test-only
`VOX_LIBJS_DIRECT_CALL_ARGUMENTS=0`; all prior optimizations remain enabled.
Separate diagnostics include the first audited cycle plus 500 callback cycles:

| Counter | Control | Candidate |
| --- | ---: | ---: |
| Native entries | 185,871 | 185,871 |
| Native fast steps | 1,780,554 | 1,780,554 |
| Generic slow steps | 798,093 | 798,093 |
| Reused frames | 417,313 | 417,313 |
| Allocated / exposed frames | 20 / 0 | 20 / 0 |
| Direct argument values copied | 0 | 488,475 |

Diagnostic counters are disabled during timing. Native instruction counts and
pool reuse/allocation/exposure counts must match, and full cache/content audits
must pass before accepting any timing sample.

| Calling-thread CPU diagnostic | Control median | Candidate median | Pairs improving |
| --- | ---: | ---: | ---: |
| Same binary, 500 cycles | 123.923 ms | 124.132 ms | 3/7 |
| Same binary, 2,500 cycles | 902.967 ms | 882.049 ms | 6/7 |
| Preceding build, 2,500 cycles | 552.328 ms | 545.308 ms | 6/7 |

The shorter comparison regresses 0.17% by ratio of medians. The longer same-binary
comparison improves 2.32%, with a 4.23% median paired reduction and one 4.46%
regression. Its broad CPU ranges (control 633.506–1,020.261 ms) limit attribution.

Disassembly shows a shared copy wrapper call in both same-binary configurations.
A separately scheduled cross-binary cohort therefore checks the net change against
the preceding measured executable. Both use the exact same compiler and C flags;
the only changed common HN implementation sources are `context_reuse.v`,
`ecmascript_function.v` and `native_function.v`, plus the new argument-copy module.
The new harness adds only its test selector/counter outside the callback loop.

The net comparison improves 1.27% by ratio of medians and 0.77% by median paired
reduction. Six pairs improve 0.03–1.29%; one regresses 15.96%. No sample is removed.
These results support a modest improvement with variation, not a general engine
speedup. Both longer cohorts are separate diagnostics and supply no credit to the
unchanged 500-cycle wall-time/RAM gates. The thread clock brackets the existing
callback markers, includes their reads, and excludes other threads and scheduling
waits; it cannot establish V8/JSC whole-engine CPU cost.

## Latest five-mode comparison

Timing medians come from seven `arguments-current` groups; RAM medians come from
a separate seven-group `arguments-memory` cohort. Times are ms and peak RSS is
MiB. Medians of totals need not equal sums of column medians.

| Mode | Initialize | First cycle | 500 cycles | Compile/finish | Total | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| V8 | 72.377 | 3.168 | 561.056 | 0.000 | 638.273 | 725.14 |
| JSC, pinned baseline | 71.584 | 4.171 | 558.166 | 0.000 | 635.184 | 588.23 |
| LibJS cold | 12.476 | 0.736 | 129.633 | 521.498 | 665.256 | 247.55 |
| Compiled LibJS, restart | 13.834 | 1.130 | 109.873 | 0.006 | 124.931 | 245.36 |
| Compiled LibJS, same process | 12.798 | 1.115 | 109.960 | 0.000 | 123.861 | 353.11 |

The unchanged speed gate combines two seven-group cohorts with the older faster
V8 executable and one seven-group matching-current cohort:

* Restarted warm fails: `4 * 122,191,000 > 468,107,958` ns, or **3.8310×**
  conservatively. The pooled restarted-warm median ratio is 5.1375×.
* The stronger both-warm check also fails: the highest warm callback is
  127,483,792 ns, giving **3.6719×**.
* RAM passes for both warm modes:
  `100 * 370,294,784 <= 50 * 760,135,680` bytes, or **48.7143%**. This compares
  the highest compiled peak with the lowest V8 peak, not LibJS's previous peak.

All final benchmark and guard exits are zero, and 28 common pinned inputs match
across the three speed cohorts and RAM cohort. Cross-cohort changes from earlier
reports are not attributed to this optimization. Retained failing cohorts and
regressions remain part of the evidence.

## Scope, validation and receipts

The [prior protocol and limitations](HACKER_NEWS_FRAME_INITIALIZATION.md) remain
unchanged: archived 101-comment discussion, complete original `hn.js`, 500 full
collapse/expand cycles, fresh private processes/caches and retained OS caches.
The script/DOM spans exclude process startup, final audits, windowing, layout,
paint and teardown. Native V8/JSC use the compact DOM bridge and eagerly prepare
replayed image hosts during initialization; LibJS uses native DOM bindings.
This is not an isolated JavaScript or full browser rendering comparison.

RAM uses root-process `RUSAGE_SELF` through the post-cache-finish checkpoint;
compiler/replay/wrapper processes are covered separately by the memory guard.
Both warm modes require 27 cache hits, no misses/invalid/pending entries and no
compiler invocation, with `/usr/bin/false` configured. Separate diagnostics verify
native execution, no native-engine fallback, content restoration and cancellation.
The JSC baseline's common browserjs/compact/DOM/HTML V sources match exactly; the
older executable cannot validate new LibJS code.

**57 focused tests pass** with current V under default GC, `-gc none` and
preallocation, with assertions enabled. Coverage includes zero/small/large/partial
copies, live heap values, aliased inputs, untouched prefixes/tails, exact budgets,
native-cache reopen, retained views, nested calls and workspace ownership.
All **19 Python evidence/clock checks** pass; the AST corpus remains **100/100
exact**. These checks do not establish full language/DOM parity or change the
separate verification status in [PORT_STATUS.md](../libjs/PORT_STATUS.md).

Local evidence is under `docs/performance/libjs-hn-arguments-20261117/`, including
`plan.json`, `cross-plan.json`, all attempts, `arguments-analysis.json`,
`cpu-analysis.json`, `cross-analysis.json`, source/compiler comparisons and guards.
Generated JSON stays untracked. Actual disk pressure required retiring older
generated compiler inputs and 24 superseded experimental executables after
hashing. The retirement manifests are local; all executables used by the current
comparison, prior final frame build, pinned baselines, raw results and build
receipts were preserved.

The final `bin/hn-arguments-v8` SHA-256 is `cc6f58bdfcc4d3b47ed62302a5352b1889d207d81c76faa3d708c1abc360b820`.
It uses one sealed C unit, production V, `-O3`, preallocation and GC disabled.
Generated native libraries retain `clang -O2 -std=c11 -fno-strict-aliasing`.
No global compiler flag, C mode, workload boundary or tolerance changed for credit.

Reproduce under the memory guard with unique outputs using
`tools/benchmark_hn_property_lookup.py --optimization argument-copy --pairs 7
--cycles 500 --callback-thread-cpu`; use `--cycles 2500` for the longer diagnostic,
and `--control-binary` for the preceding-build cohort. Five-mode cohorts use
`tools/benchmark_hn_engines.py --pairs 7 --cycles 500 --target-v8-speedup 4`, adding
`--memory --target-v8-memory-percent 50` only to the separate RAM cohort. Supply
the pinned `--binary`, `--jsc-binary` and older-control `--v8-binary` from the plan.
