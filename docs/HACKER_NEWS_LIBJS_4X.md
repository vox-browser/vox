# Hacker News: compiled LibJS speed and peak RAM

See the latest [call-argument copy continuation](HACKER_NEWS_ARGUMENT_COPIES.md)
for subsequent measurements and the current speed/RAM gates.

The latest [call-frame initialization continuation](HACKER_NEWS_FRAME_INITIALIZATION.md)
records further matched CPU measurements and the current speed/RAM gates.

The subsequent [native property-read continuation](HACKER_NEWS_NATIVE_PROPERTY_READS.md)
records guarded indexed-read lowering, matched CPU diagnostics, and newer five-mode
timing/RAM cohorts. The entry-cache measurements below remain historical evidence.

This continues [the previous 3× comparison](HACKER_NEWS_LIBJS_RAM.md). The target
is 4× V8 callback speed and at most 50% of V8 peak resident memory for **both**
compiled LibJS modes. **RAM passes; the strict 4× speed target remains open.**
The latest matching-current V8 cohort has a 4.70× restarted-warm median ratio,
but the combined 21-group highest-warm/lowest-V8 ratio is only 1.8457×.
These are different statistics; the median does not close the strict target.

The workload remains the archived 101-comment discussion, its complete original
`hn.js`, and 500 complete collapse/expand cycles. This measures Vox’s script/DOM
integration: V8 and JSC use the compact DOM bridge, while LibJS uses native DOM
bindings. It does not measure general JavaScript throughput, rendering, scrolling
or full browser launches.

## Latest comparison

The table uses the seven-group `entry-current` timing cohort and the separate
seven-group `entry-memory` RAM cohort. Times are ms and RSS is MiB. Medians of
summed spans need not equal sums of column medians.

| Mode | Initialize | First cycle | 500 cycles | Compile/finish | Measured total | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| V8 | 75.683 | 3.730 | 574.791 | 0.000 | 654.254 | 725.23 |
| JSC (pinned baseline) | 72.439 | 5.024 | 630.187 | 0.000 | 706.213 | 588.19 |
| LibJS cold | 13.320 | 0.814 | 142.634 | 484.013 | 644.890 | 247.20 |
| Compiled LibJS, restart | 14.906 | 1.183 | 122.267 | 0.005 | 138.506 | 245.94 |
| Compiled LibJS, same process | 13.338 | 1.156 | 121.045 | 0.000 | 135.540 | 353.34 |

Both compiled modes pass the conservative RAM gate:
`100 * 370,540,544 <= 50 * 760,315,904` bytes, or **48.74%** of V8 at the
highest compiled peak versus the lowest V8 peak. This is a comparison with V8,
not a claim that LibJS’s own previous peak fell by 50%.

The unchanged strict speed gate fails:
`4 * 281,081,667 > 518,784,292` ns. The pooled restarted-warm median ratio across
all 21 groups is 4.1431×. In the matching-current cohort, callback ranges are
V8 518.784–789.387 ms, restarted warm 114.886–154.687 ms and same-process warm
113.262–167.612 ms. All benchmark and guard exits are zero; all content, engine,
cache and input-identity audits pass. None of the outliers was removed.

The entry-cache control has identical native entry/fast-step/slow-step counts
with the cache off and on. Its medians are 184.759 → 178.422 ms, but the ranges
overlap and some pairs regress. Bounded retention and executed fast paths are
established; an isolated CPU gain of that percentage is not established.

A prospective quiet-host protocol requires no observed external compiler and
one-minute load at most 4 for 30 seconds before each cohort. Its first cohort was
never launched: 177 five-second admission samples did not meet the load gate.
The host reached load above 40 on 18 CPUs and was still near 11 at the end.
The waiting-only process was stopped to request an available validation window.
The initial sampler’s `ps comm` column truncated executable paths; it was fixed
to use `proc_pidpath` before any admitted run. The load gate stayed closed
throughout, so no acceptance depends on that classifier. No quiet-host result
or engine optimization credit is claimed. Whole-process CPU receipts remain a
separate diagnostic; their startup/audit scope cannot replace callback wall time.

## Changes

* A bounded, VM-owned cache reuses immutable short split/join results. It owns
  borrowed input and preserves UTF-16 code units, conversion order and exceptions.
  It is separate from the public string creation and source/IPC storage contracts.
* Plain text in safe HTML body contexts creates the text node directly, avoiding
  a temporary document and tokenizer. Markup, entities, CR/NUL, invalid UTF-8 and
  special/foreign contexts retain the full parser. Native document storage,
  replacement, mutation observers, ranges and invalidation remain in force.
* Synchronous calls reuse argument buffers by active depth, retaining at most 64.
  Known callees copy arguments before author code; custom/proxy/suspending calls
  retain owning storage. Returns and exceptions clear slots. Concurrent native
  invocation record reuse removes another per-entry heap allocation.
* Global binding reads reuse bounded, owned key/position hints. Every hit checks
  the current key and data value; deletion/reordering, accessors, lexical shadowing,
  TDZ, with environments, proxies/exotics and inherited properties keep their
  ordinary behavior. Reused input addresses also require equal UTF-16 content.
* Primitive string/symbol property keys bypass redundant conversion wrappers,
  while object coercion, exceptions and nullish error order keep the full path.
* Native code handles primitive `typeof`, string truthiness and same-type equality directly.
  It reads current immutable UTF-16 storage with the exact compiler’s offsets;
  no realm addresses are embedded. `typeof` names are rooted in the current VM,
  supplied through per-depth invocation state and verified across compiler-free
  fresh-VM reuse. Callable objects keep the VM path. Cross-type coercion and BigInt comparisons
  retain VM fallback. Disk identity includes string-layout facts and source hashes.
* A bounded tier-owned native-entry table removes repeated preparation/dispatch
  map lookups. Exact executable identity guards collisions; writes update the
  table, bulk replacement clears it and closing the tier discards it with the
  native-library handles. It caches neither misses nor JavaScript values.
* Cache-file hashing uses temporary storage, retaining only owned results.
  A native-cache reopen crash exposed process-wide JSON decoder metadata allocated
  in a freed temporary arena. The decoder now validates map fields without that
  retained reflection cache; hashing and record/mapping owners have explicit lifetimes.

A generated-C check found that the earlier fixed-size local argument array was
heap copied on every call. An attempted unsafe slice alias still retained
1,280,000 bytes for 10,000 calls and was rejected. Reusable buffers reduce that
focused preallocation check below 4 KiB; native invocation reuse likewise remains
below 4 KiB for 100,000 entries. These checks establish allocation avoidance,
not standalone application speedups.

## Protocol

Each group has fresh private processes for V8, JSC, cold LibJS, restarted compiled
LibJS, and a same-process compiled visit following cold execution. OS caches are
retained. Cold execution interprets, then explicitly compiles 27 function bodies.
Both compiled modes require 27 hits, no misses/invalid/pending entries and no
compiler invocation, with `/usr/bin/false` as compiler. Separate diagnostics prove
native execution and no fallback. Timed counters and builtin profiling are off.
Audits require real collapse, all 101 classes restored, canceled navigation,
no errors and an empty VM stack.

Callback time covers the 500 cycles after the first audited cycle. The measured
total sums initialization, first cycle, callbacks and explicit cache finish.
Process startup, final audits, window setup, layout, paint, PNG capture and teardown
are outside those timers. Native engines replay original resources locally during
initialization; LibJS does not eagerly fetch images, so callback speed is the gate.

Two seven-group cohorts retain the older, faster pinned V8 control; a third uses
matching current V8/JSC builds because the HTML optimization also benefits them.
The combined gate is `4 * max(all restarted-warm callback ns) <= min(all V8 ns)`.
An additional stricter gate uses the maximum across **both** compiled warm modes.
Every attempt, outlier and failure is retained. Own builds/checks finish before
acceptance timing; other sessions and their recorded host load remain a limitation.

A separate seven-group memory cohort reports root `RUSAGE_SELF` high-water RSS
from process startup through the checkpoint after cache finish and before final
audits. It excludes compiler, replay and wrapper processes. Same-process warm
retains cold history. The exact gate is
`100 * max(both compiled warm peaks) <= 50 * min(V8 peak)`.
RSS includes the integration’s DOM/bridge state and the native engines’ eager
image replay; it is not isolated JavaScript-heap memory. The separately retained
`wait4` metric can include compiler children on macOS and
is not the table metric. Timing results from the memory cohort earn no speed credit.

## Retained unsuccessful measurements

The initial baseline had a conservative 3.749× callback ratio and a same-process
compiled peak near 480 MiB. Short-string and plain-text changes reduced that peak
to about 440 MiB; restarted compiled execution was about 294 MiB. The 50% gate
still failed. The two initial speed cohorts also failed the 4× gate; all results,
including their slowest compiled trials, remain in the local receipts.

After argument/native-invocation reuse and the cache fix, a seven-group memory
cohort passed: the maximum across both compiled modes was 372,015,104 bytes,
versus V8’s minimum 760,168,448 bytes (48.94%). The next 21 timing groups still
failed the strict 4× gate: `4 * 163,368,125 > 495,619,250` ns, a conservative
3.0338× despite a pooled median ratio of 4.6894×. Those cohorts remain evidence;
the median alone did not close the target.

The first global-hint/native-primitive build also passed RAM, but the 21-group
speed gate remained open: `4 * 178,416,083 > 490,375,500` ns for restarted warm;
the highest of both warm modes was 185,644,584 ns. Its pooled median ratio was
4.1732×. Applying application scheduling policy equally to all engines did not
close the gate either (`4 * 192,196,583 > 481,640,166` ns). Scheduling receives no
engine optimization credit. Both failing cohorts and all host conditions remain.
The following `typeof`/property-key cohorts use the original inherited CLI policy.

The first argument-workspace comparison aborted during its seed with exit 139.
Its cold visit completed, but same-process native-cache reopen crashed in JSON
field metadata. It has no valid acceptance trials. The subsequent decoder and
owner-lifetime regressions cover repeated lookups after scratch-memory overwrite.

Diagnostic builtin profiles measure inclusive nested time and current-arena
allocation, so samples overlap and cannot be summed or used for acceptance.
OS sampling produced no useful application stacks. A V profiling build failed
in unrelated canvas generated-C tuple handling; a separate comparison build hit
concurrent MSAA staging changes. Both failures are preserved, with no speed credit.
A later private build was intentionally stopped to add compiler-layout identity;
another was rejected when concurrent graphics edits changed a pinned input.
Neither supplied measurements. A consecutive-dynamic-step batching experiment
failed its eligibility regression and was removed before further comparisons.

## Validation and evidence

The final entry-cache matrix passes with normal GC, GC disabled and preallocation.
It includes 100,000 allocation-free-after-warmup lookups, collisions, replacement,
miss/insertion, disabled execution, roots and close/reopen, along with native
execution/budget/unwind, invocation ownership, compiler-free type-name reuse,
primitive coercion and cache record/digest lifetime checks. Unit assertions are
enabled; production mode is used only for the benchmark executables.


Focused tests cover string ownership, collisions, eviction, surrogates, NUL,
getter/conversion exceptions and exact instruction budgets; text-fragment parser
differentials, native ownership, ranges and mutation observers; argument-buffer
bounds, nesting, proxy fallbacks, exceptions, roots and clearing; and cache record,
digest and mapping lifetimes. The diagnostic profiler is tested separately.

The 32-function string suite and 27-function call suite pass with normal GC and
GC disabled. All four text-fragment tests pass in those modes and preallocation;
allocation proofs and cache-lifetime checks also pass with preallocation. The
Python evidence suite passes 17 tests. The AST comparison remains exact, 100/100.
These are focused results, not a claim that the entire LibJS suite passes.
The 0.5.2 compatibility command rejected the repository-required
`-memory-limit 10G` before compiling, so no compatibility pass is claimed.

Broader checks retain existing failures: parser lifecycle expects every queued
task to be unspecified despite current CSP tasks; an older spread-call test
expects rejection although spread is now implemented. Neither acceptance protocol
nor those expectations was weakened to hide the failures. Full LibJS parity and
browser scripting support remain limited as documented in `libjs/PORT_STATUS.md`.

Raw commands, identities, host conditions, all attempts, guard exits, parsed-source
manifests and frozen compiler receipts are local in
[`docs/performance/libjs-hn-4x-20261116`](performance/libjs-hn-4x-20261116/).
`protocol.json` pins the scope; `entry-plan.json` pins the measured cohorts; `quiet-plan.json` pins the pending host-admission protocol.
Completed generated C and test executables are retired with hashes and sizes in
`retired-generated-artifacts.json` to keep disk use bounded. Measured benchmark
executables and their identity/source receipts are retained.

The compiled candidate and matching-current V8 use the same `hn-entry-v8`
executable. JSC reuses the completed `hn-primitives2-jsc` baseline after the new
JSC attempt was rejected for concurrent source-membership drift. All browserjs,
compact, DOM and HTML source hashes match; only harness counter resets and JSON
fields outside the callback timer differ. This older executable supplies JSC
baseline evidence and does not validate the new LibJS implementation. GG/paint
changes are outside this non-windowed workload. Differences and source checks
are retained in `entry-jsc-native-input-difference.json` and
`entry-source-verification.json`.

Final measurement identities (SHA-256):

```text
hn-entry-v8      eaa074b7f11c517353f2367ae984a0fd8cd4a1ed4c6757932687529edd984cfe
JSC baseline    04dc49df9638605874eed4a7c6a9fd0c4448dd5c0a3e9e233d703365fe62e0bf
V8 adapter      ad7196770fb36f755bdce1c89d759b811c377205f9921ab580015781e9e3ffeb
libnode         a65e29cb28c58d17ecaace4e3dc9ae2cd98cd9d65b59b2a00a972872e4d513ef
hn.js           2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0
HTML            04bfd8b86c3a9098e4e4a8428e65142e4144d5f8184d66b802b26243baf19c07
```

Hardware is Apple M5 Max, 18 CPUs (6 Super, 12 Performance). The pinned software
is macOS 27.2 (26B123), V8 14.6.202.34-node.40 / Node 26.13.0_2 and system JSC
22625.2.8.11.9. Host timestamps/load and actual commands/exits are retained for
every attempt. Prior application-role scheduling did not close the gate and
is not used for this table. Its separate receipts remain available.

Private comparison executables use production V, one sealed C unit, `-O3`, the
bounded preallocation runtime and GC disabled. The existing shared production bundle was inspected at the start. Validation
of the new runtime uses the pinned source-built component executable; the older
bundle cannot validate code it does not contain.
Commits request the managed, coalesced production rebuild without duplicate builds.
