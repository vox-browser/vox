# Hacker News: V8 and cold/warm LibJS

This compares Vox's JavaScript/DOM integrations on the archived 101-comment HN
discussion, using the complete unchanged `hn.js`. It measures HTML parsing,
runtime/binding setup, script initialization, a first collapse/expand, repeated
collapse/expand cycles (500 in the latest cohorts), and an explicit native-cache checkpoint. It excludes
process startup, external network, a native window, document layout/painting, PNG capture,
correctness audits and teardown. The reported total sums those measured spans;
it is not a continuous browser navigation or rendering time.
Adblock is disabled in every mode to exclude filter-list initialization.

## Latest: compiled LibJS exceeds 2× V8 on HN callbacks — 2026-11-16

The final executable passes seven alternating matched control/candidate/V8
triplets and an independent seven-group cold/warm comparison. **Restarted warm
LibJS takes 299.834 ms versus V8’s 747.341 ms for 500 collapse/expand cycles:
2.4925× by medians.** This is the archived discussion’s actual script/DOM
integration workload, not an isolated JavaScript benchmark, rendering time,
live-site navigation or a universal LibJS/V8 claim. Both engines keep their
existing, different DOM bridges. The earlier results below remain historical.

| Median measured interval, ms | V8 | LibJS cold | LibJS warm, restarted | LibJS warm, same process |
| --- | ---: | ---: | ---: | ---: |
| HTML/runtime/script initialization | 82.221 | 20.280 | 21.575 | 31.921 |
| First collapse/expand | 3.814 | 1.062 | 1.413 | 1.558 |
| Next 500 collapse/expand cycles | **747.341** | **324.071** | **299.834** | **369.425** |
| Cache compilation/finish checkpoint | 0.000041 | 487.621 | 0.000250 | 0.000250 |
| **Total measured spans** | **832.771** | **834.128** | **322.994** | **403.109** |
| Callback minimum–maximum | 723.869–781.256 | 322.804–328.893 | 297.194–305.707 | 366.819–374.492 |

Every restarted warm trial exceeds 2× its paired V8 trial. The independent
cohort also passes `2 * max(LibJS callback ns) <= min(V8 callback ns)`;
fastest-V8/slowest-LibJS is **2.3679×**. Cold includes native compilation:
its total is approximately tied with V8 here, not 2× faster. Same-process
warm callbacks reach 2.0230× by medians but do not pass the all-extremes gate
(1.9329×). These independently computed medians need not sum to total medians.

| Pair | V8 callbacks ms | LibJS cold ms | LibJS restarted ms | LibJS same-process ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 752.915125 | 328.892750 | 305.706750 | 374.492417 |
| 2 | 743.862459 | 323.594084 | 299.945958 | 369.424792 |
| 3 | 746.772084 | 322.803625 | 297.194375 | 366.819000 |
| 4 | 747.341084 | 323.100459 | 300.614917 | 367.741292 |
| 5 | 781.255917 | 324.070583 | 299.771000 | 371.094917 |
| 6 | 751.542958 | 325.110500 | 299.834334 | 368.491000 |
| 7 | 723.869458 | 324.269333 | 299.830125 | 370.244709 |

### Changes and matched controls

The implementation removes runtime allocation and helper work without replacing
HN code or changing V8 settings:

* Scope analysis lowers uncaptured simple-function parameter/`var` accesses to
  native value-slot moves; captures, eval, TDZ and observable arguments retain
  environment handling (`beb51a568`). Reads snapshot values to preserve order.
* Array length tests compare ASCII directly and algorithms reuse the VM’s length
  key (`8102c8510`). Exact execution-context value capacity removes unused
  rounding (`3ee6e119c`). Getter/proxy access remains observable.
* Primitive property reads avoid unused wrappers (`e57e16936`). Hot bytecode
  validation compares bounded exact snapshots, including nested operand arrays
  and handlers (`c4e61779b`); mutable bytecode still invalidates the snapshot.
* Empty lexical scopes become budgeted native no-ops (`f783c6de7`), and numeric
  array keys avoid decimal/UTF-16 conversion below 2^32−1 (`25917c375`).
* Private synchronous calls reuse cleared frames and fixed value buffers
  (`cbe1263c4`) in a pool bounded to 64 frames/1 MiB. Escaped public frames, views, traces and saved
  stacks preserve their old lifetime. Suspensions/inline-linked frames stay on
  fresh storage. Reuse clears all values/metadata, retains stack limits and
  assigns a fresh frame ID; new layouts can evict old unused pool entries.

The final `frames` cohort toggles only frame reuse in the same executable and
native-code cache. Callback medians are **375.289 ms control / 299.100 ms
candidate / 747.502 ms V8**, a **20.3%** reduction from reuse alone. Ranges are
373.139–378.307 / 298.615–300.880 / 710.093–755.144 ms. Every candidate beats
every control; even fastest-V8/slowest-candidate is **2.3601×**.

Separate diagnostics count **417,313 reused private frames and 20 new private
allocations**. Total fresh contexts fall from 422,343 to 5,030 and allocated
value capacity from 4,984,449 to 6,845 slots; public allocations remain fresh.
Native callback activity is identical: 185,871 entries, 1,675,845 direct steps,
902,802 helper steps. Earlier diagnostics verify 725,949 accesses moved to native
slot moves, 654,306 length-key constructions avoided, 24,048 unused primitive
boxes avoided, 184,848 validation snapshot hits with 2,046 full validations,
15 empty blocks elided and 108,216 numeric-key string conversions avoided.
Counters are disabled and zero in every timed visit.

Both final cohorts verify collapse/navigation cancellation, restoration of all
101 comment classes, no script errors, empty interpreter frames and unchanged
input hashes. Each cold run compiles 27 executables in one clang invocation;
all warm runs load the full 27 with zero misses, invalid entries or compiler
invocations (warm compiler path is `/usr/bin/false`). LibJS does not initialize
the native V8 context; the separate V8 diagnostic confirms actual V8 execution.

### Retained earlier cohorts and limits

All earlier results remain local under `docs/performance/libjs-hn-2x-20261116/`.
Timing changes across source epochs/host conditions are not combined into one
speedup. The `register-cohort` callback medians are control 680.467 / candidate
571.162 / V8 798.961 ms. `storage-cohort` gives 766.326 / 599.778 / 1247.259 ms:
its apparent 2.08× median fails the conservative gate and two paired trials,
with load 12.53–14.24 on 18 logical CPUs. A lower-load independent `final-engines`
then gives warm LibJS 394.776 / V8 629.911 ms (1.60×), so work continued.

`dispatch-cohort` gives 396.435 / 369.541 / 696.417 ms; `indices-cohort` gives
355.943 / 348.941 / 673.190 ms. Independent `optimized-engines` still falls
short at warm 347.002 / V8 674.350 ms (1.94×). A last-property-slot experiment
(`last-cohort`) produces 353.091 / 352.153 ms with a worse candidate maximum;
its implementation was removed and earns no performance credit.

The first frame-pool cohort (`reuse-cohort`) gives 346.296 / 275.153 / 572.988 ms,
passing the all-extremes 2× gate at 2.0330×. Its independent `reuse-engines`
gives warm 273.582 / V8 572.524 ms (2.0927×); all paired trials pass 2× but
its all-extremes ratio is 1.9325×. The final refinement admits new frame layouts
after pool saturation. Both final cohorts above measure that exact code.
Earlier and final absolute timings differ; no performance credit is assigned
to the eviction refinement, which does not execute on this HN workload.

The 257-function focused/lifecycle aggregate passes with default GC and
`-gc none`, including escaping native callbacks/value views, stack walks/traces,
saved stacks, errors, closures, async/generator frames and stack exhaustion.
The earlier full-package aggregate remains failing: five existing assertions
(class/construction expectations, global names, Intl patterns/formatting) and
an uncaught Intl ReferenceError prevent a green full-suite claim. A separate
proxy fixture’s missing Function binding reproduces with optimizations off/on;
classic `for(let…)` capture also fails with scope elision off/on. These are
retained limitations, not claimed fixes. AST fixtures compare exactly 100/100;
eight Python evidence-validation tests pass. The final AST rerun uses C/clang;
an initial default-FastC attempt fails on its unsupported generic parser syntax
and is retained as `final-ast2.log`. The compatibility compiler was
not available; these checks use current V `0.5.2 cbfc1be`.

### Final artifact and receipts

The final headless executable is SHA-256
`a7eea82ba7d077cb0a5f2ba81e107863df9c1c93f2da1482a0c7621017d121ad`.
It uses C/clang, literal V `-prod -no-prod-options`, `-O2`, one C unit, no LTO
and default Boehm GC. Build/guard exit zero; 174.137 s, peak sampled aggregate
RSS 11,764,088,832 bytes under 12 GiB. This is source-built benchmark evidence,
not validation of the installed production bundle’s allocator/configuration.
The shared checkout contains concurrent work; executable and pinned input
hashes identify the measured artifact. V8 is **14.6.202.34-node.40**; the `-O3`
adapter and libnode hashes below are unchanged from the original comparison.

`final-frames/results.json` retains every seed, diagnostic and timed attempt
(25 processes); `final-engines2/results.json` retains all 24 processes. Every
process, driver and guard exits zero. Guard peaks are 504,152,064 and
505,167,872 bytes under 3 GiB; durations 21.577 and 26.415 s. The 18-CPU host’s
one-minute load changes 4.741→4.577 and 4.771→4.847 respectively. OS filesystem
and loader caches remain warm; private per-process profiles/HTTP caches and
private native caches follow the policy below. Local replay serves unchanged
archived images without external forwarding. Exact commands, exits, PIDs,
cache/library/fixture/source hashes, replay requests, build context and all
prior failed/rejected attempts remain beside these local receipts. Guards are
retained under `guards/`; temporary Build job outputs are removed. Benchmark
controls are committed as `1dd95e61c`. Each feature commit requests the managed production rebuild; no duplicate manual browser
build was queued. The installed bundle is not used to validate new runtime code.

## Results — 2026-11-15

Seven complete groups used one optimized source-built executable containing
both backends. Each cell below is an independently computed median in ms.

| Measured interval | V8 | LibJS cold | LibJS warm, restarted | LibJS warm, same process |
| --- | ---: | ---: | ---: | ---: |
| HTML/runtime/script initialization | 122.200 | 33.657 | 37.250 | 30.306 |
| First collapse/expand | 6.532 | 3.659 | 4.327 | 4.928 |
| Next 100 collapse/expand cycles | 259.788 | 340.742 | 335.808 | 363.416 |
| Cache compilation/finish checkpoint | 0.000084 | 557.463 | 0.005791 | 0.000333 |
| **Total measured spans** | **388.847** | **938.405** | **378.223** | **398.756** |
| Total minimum–maximum | 373.595–389.493 | 909.468–960.414 | 374.530–388.431 | 396.102–424.894 |

Warm restarted LibJS takes **40.3% of cold time**, approximately **2.48× faster**
for this workflow, principally by avoiding first-visit compilation. Warm/cold
callback medians differ by only about 1.4%; the native tier does not demonstrate
a reliable callback-throughput improvement here. Same-process parser reuse
reduces initialization relative to restart, but its callback interval is slower
and its total is higher. No causal explanation for that difference is established.

V8's repeated-callback median is **259.788 ms versus 335.808 ms** for restarted
LibJS: warm LibJS takes **29.3% longer** in that interval. Every V8 callback
trial is faster than every restarted-LibJS callback trial. These intervals
include the engines' different browser DOM bindings and synchronization.
Overall totals are close: restarted LibJS/V8 is 0.972679 by the ratio of medians,
0.980599 by the median paired ratio, and **1.039711** by highest-LibJS/lowest-V8.
Their overlapping total ranges do not establish an overall winner.

| Group | V8 total ms | LibJS cold ms | LibJS restarted ms | LibJS same-process ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 386.657001 | 909.468334 | 388.430624 | 397.674916 |
| 2 | 389.244750 | 940.624209 | 378.223291 | 424.893543 |
| 3 | 373.594917 | 931.644792 | 374.530167 | 404.373875 |
| 4 | 389.075459 | 932.395249 | 376.452792 | 403.836750 |
| 5 | 388.847000 | 958.040876 | 381.302959 | 396.101917 |
| 6 | 389.492749 | 938.405417 | 380.518541 | 398.091917 |
| 7 | 380.673875 | 960.414001 | 377.023500 | 398.755793 |

Every cold visit compiles **27 executables with one clang invocation**. Both
warm modes load all 27 with zero native misses, invalid entries or compiler
invocations. Restart reparses one source; same-process reopen records one
frontend hit and zero misses. Median clang compilation itself is 389.714 ms;
first library loading is 159.296 ms. Warm library loading is 3.104 ms after
restart and 2.914 ms in the same process. Those costs are already included above.
Each separate warm diagnostic records 37,471 native callback entries, 177,457
fast steps and 342,390 dynamic-helper steps; cold records zero native entries.
Timed visits have all activity counters disabled/zero and no script errors or
native-engine fallback.

The 18-logical-CPU host's one-minute load ranges from 10.98 to 11.70. All 24
processes (three diagnostics and 21 timed processes), the driver and runtime
guard exit zero. Runtime guard peak sampled aggregate RSS is 386,007,040 bytes
under 3 GiB; duration is 28.096 s. The final source build uses current V
`0.5.2 cbfc1be`, C/clang, literal V `-prod -no-prod-options`, `-O2`, one C unit,
no LTO and default Boehm GC. It finishes in 287.442 s with sampled peak
12,435,816,448 bytes under the unchanged 12 GiB guard; compiler/guard exit zero.
This is a source-built headless benchmark, not the installed production bundle's
allocator/build configuration. Seven Python evidence-validation tests also pass.
Benchmark tooling is committed as `9dcf51f62`. The executable was built from the
shared canonical checkout with concurrent uncommitted work; its binary identity
and sealed generated-C hash in the local build context identify the measured
artifact, rather than a claim that it is a clean build of that tooling commit.

V8 reports **14.6.202.34-node.40**. Pinned SHA-256 identities:

* Executable: `a75333d531086eaeacf76baffe08549a80009594d8b6587d3301fc84940abf37`
* V8 adapter: `ad7196770fb36f755bdce1c89d759b811c377205f9921ab580015781e9e3ffeb`
* Homebrew libnode: `a65e29cb28c58d17ecaace4e3dc9ae2cd98cd9d65b59b2a00a972872e4d513ef`

The exact results, outputs, commands, process identities, host readings,
per-cache library hashes and replay requests remain local in
`docs/performance/hn-engines-20261115/cohort-r6/results.json`; build/guard logs
and prior attempts are retained beside it. The initial harness diagnostics
identified duplicate-ID dispatch, missing navigation settings and an inactive-VM
counter read; they yielded no accepted cohort. A rebuild stopped for a harness
correction exits 143. The subsequent live-image cohort is invalid: V8 host
setup fetched images over the internet. Its 23–24 s V8 totals are retained and
earn no optimization credit from switching to replay. The first replay rejects
the discussion fixture's local asset-base URLs. The final replay explicitly
aliases those two URLs to hash-identical retained images and passes all checks.

## Workload and cache policy

The three primary modes are V8 in a fresh process, LibJS in a fresh process with
an empty native cache, and LibJS in another fresh process using that cache.
Restarted LibJS reparses the script; it cannot reuse the process-local frontend
cache. A fourth observation reopens a fresh document/VM in the first LibJS
process and can reuse both native code and the parsed source. Both warm modes
replace clang with `/usr/bin/false` before creating their runtimes.

The first LibJS workload executes before its explicit cache checkpoint. Its
reported total includes compiling cache-eligible executed functions for subsequent visits.
There is no claim that production idle tasks have the same scheduling or that
cached native instructions alone account for changes in total time. V8 uses
Vox's compact/native DOM bridge; LibJS uses its direct native bindings. These
are actual browser integration paths, rather than isolated engine throughput.
Callbacks form a synchronous burst without per-click native window/run-loop
turns; their timings do not establish interactive input latency.

The fixture hashes are:

* `hn.js`: `2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0`
* Discussion HTML: `04bfd8b86c3a9098e4e4a8428e65142e4144d5f8184d66b802b26243baf19c07`

V8's native image host eagerly initializes the fixture's images; that local
fetch/decode work remains inside its initialization interval. LibJS's direct
binding installation does not eagerly fetch those images. Both processes use
the sealed HN original-response archive through the same loopback SOCKS replay
and private TLS certificate, with forwarding disabled and a new HTTP cache per
process. The fixture retains its existing local-assets `<base>`: its `s.gif`
and `y18.svg` URLs are explicitly aliased to archived bodies only after verifying
they match the retained discussion assets byte for byte. HTML and author-script
bytes are unchanged. All 16 replay requests (two per V8 process) return archived
HTTP 200 responses; no request is missing or forwarded. This setup difference
also limits interpreting initialization/total ratios as engine-only speed.

Every visit verifies navigation cancellation, actual collapse of the first
subtree, restoration of all 101 comment-row classes, absence of script errors
and empty interpreter frames. Warm visits must reuse the entire compiled cohort
without compiler invocations, native misses or invalid entries. A separate
diagnostic verifies native execution. Timed visits disable diagnostic counters.
The driver also verifies that the executable's JavaScript context/evaluation
imports bind to `libVoxJSCOnV8`, and records the backend's actual V8 version.

Seven groups alternate V8-first and LibJS-first order. Cold/reopen/restart order
is intrinsic to the cache workflow. Each group has a new private native cache
and each process a private profile. OS filesystem/loader caches are retained.
Executable, native libraries, fixtures and benchmark sources are hashed and
checked throughout. The raw local receipts retain every attempt, commands,
environment, PIDs, outputs, exits, exact timings, native/cache counters and host
load/timestamps.

## Property lookup optimization — 2026-11-16

The follow-up removes repeated scans of long ordinary-object property lists.
Objects with at least 16 properties lazily retain up to 64 successful hash-to-
position hints. Every hit checks the live key and array bounds; collisions,
deletion/compaction and replacement fall back to the ordered lookup. Values,
descriptors and absence are never cached. Prototype/accessor behavior and
enumeration order stay in their existing implementations. Small objects keep
linear lookup without allocating a cache. Ordinary own keys remain unique.

A test-only switch compares the old linear path and hints in the **same**
optimized executable, with identical native-code libraries and fresh processes.
Both LibJS modes are warm native-cache restarts; the V8 mode uses the same
compiled browser bindings and frozen-image replay as above. Seven alternating
control/candidate/V8 groups time 500 collapse/expand cycles each. Diagnostics
run separately, and all timed native/hint counters are zero.

| Median interval, ms | LibJS linear control | LibJS property hints | V8 |
| --- | ---: | ---: | ---: |
| Initialization | 38.277 | 35.025 | 116.072 |
| 500 collapse/expand cycles | 1795.796 | 1284.017 | 1156.145 |
| Total measured spans | 1835.079 | 1323.643 | 1287.218 |
| Callback minimum–maximum | 1502.540–1944.539 | 1139.371–1402.071 | 924.358–1605.005 |

The callback median decreases **28.5%** (1.40× speedup). The median paired
candidate/control ratio is **0.756527**, and highest-candidate/lowest-control is
**0.933134**. Every candidate beats its paired control, and even the slowest
candidate beats the fastest control. Control/host variation remains in the
report; no retired-instruction savings or universal site-speed claim is made.

This does **not** establish that compiled LibJS is faster than V8. Its callback
median is still 11.1% higher, and V8 varies considerably: highest-candidate/
lowest-V8 is 1.516805. The total medians differ by only 2.8%. The native tier
still uses dynamic interpreter helpers for most operations.

The separate candidate diagnostic records **722,224 property-hint hits** and
17,052 fallbacks. Both LibJS modes load all 27 compiled executables with zero
compiler invocations or native-cache misses. All 101 comment classes restore,
collapse/cancellation checks pass, and no JavaScript errors or fallback occur.
The 25 browser-test processes, driver and 3 GiB guard exit zero; sampled peak
aggregate RSS is 593,182,720 bytes. The cohort takes 52.785 s on 18 logical CPUs,
with one-minute host load 10.50–11.45. A separate before/after sample identifies
property scanning first and allocation/GC after the cache; neither sampled run
supplies timing credit. Other sessions were active; this session's full-suite
compilation was stopped before the timed cohort.

Executable SHA-256:
`f08c021280e1935b67941200c3728e9e921e6cab8cafdec69355e7a57f069e6c`.
The build retains the earlier C/clang, single-unit, `-prod -no-prod-options`,
`-O2`, no-LTO, default-GC configuration. It finishes in 304.147 s, guard/compiler
exit zero, sampled peak 11,692,670,976 bytes under 12 GiB. Raw results, every
attempt, hashes, native libraries, replay routes, diagnostics and guard receipts
remain local under `docs/performance/libjs-hn-optimization-20261115/`.

All **45 focused functions across nine files** pass in default and GC-disabled
modes, covering the cache, ordinary objects, property keys/references/mutations,
Array.map and the three corrected fixtures;
the exact upstream AST corpus matches **100/100**. The full package remains
red for unrelated baseline expectations and Intl execution. After fixing three
existing test compiler issues (literal JavaScript templates, fixture mutability
and uint/u64 arguments), the 364-file aggregate reaches 503 passing functions
and five failed expectations, then aborts in Intl `formatToParts`. Both GC
modes stop at the same point. A separate same-executable probe with hints
disabled/enabled reproduces the same five failures and exception. The ordinary
per-file suite also has two retained 12 GiB guard failures. No full-suite pass
is claimed; raw failures and partial coverage are retained.

Reproduce the comparison using the newly built HN executable:

```sh
sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
    --lock Build/hn-lookup-UNIQUE.lock --report Build/hn-lookup-UNIQUE.json -- \
  python3 tools/benchmark_hn_property_lookup.py \
    --binary /tmp/vox-hn-engines/hn-engines \
    --output docs/performance/hn-lookup-UNIQUE --pairs 7 --cycles 500
```

## Unobserved arguments allocation — 2026-11-16

The next profile showed allocation/GC after property scanning was reduced.
The runtime still created an `arguments` object, indexed properties, parameter
mapping and an environment binding for every ordinary HN function call, although
this `hn.js` never references `arguments`.

Parser-owned functions now use existing parsing/scope insights to omit an
unobservable arguments binding. Explicit access, arrow captures, parameter
initializers and possible eval access keep the existing behavior. Parserless
embedder records remain conservative. Parameter/shadowing rules still run first.
No AST metadata, bytecode budget, source/cache key or author-script bytes change.

Two additional seven-group cohorts use one executable and unchanged native
libraries. Each uses fresh processes, 500 callback cycles, archived images and
separate diagnostics. All timed activity counters are disabled. The combined
control disables both optimizations; the candidate enables both. Its medians:

| Interval, ms | Original LibJS paths | Optimized LibJS | V8 |
| --- | ---: | ---: | ---: |
| Initialization | 29.295 | 26.664 | 95.418 |
| 500 collapse/expand cycles | 1372.608 | **676.465** | 815.618 |
| Total measured spans | 1404.110 | **706.809** | 912.402 |
| Callback minimum–maximum | 1337.521–1685.259 | 642.609–699.754 | 754.702–885.746 |

Combined callback time decreases **50.7%**, approximately **2.03× faster** than
the original compiled-LibJS paths in this same executable. Candidate/control is
0.492832 by ratio of medians, 0.501718 by median paired ratio and 0.523172 by
highest-candidate/lowest-control.

Against V8, optimized callback time is **17.1% lower** and the total is **22.5%
lower** by ratios of medians. The paired callback ratio is 0.857943; the
highest-candidate/lowest-V8 ratio is **0.927192**. The total's conservative ratio
is 0.852904. Every candidate beats both its matched control and V8; even the
slowest candidate callback trial is faster than the fastest V8 trial.
The conservative callback ratio supports a smaller margin than the medians;
these observations do not establish a universal engine advantage.

| Group | Original LibJS callbacks ms | Optimized callbacks ms | V8 callbacks ms |
| --- | ---: | ---: | ---: |
| 1 | 1685.259333 | 642.608583 | 878.631166 |
| 2 | 1374.494417 | 682.407666 | 773.085833 |
| 3 | 1337.521125 | 672.933167 | 878.969000 |
| 4 | 1342.401625 | 675.152500 | 754.702167 |
| 5 | 1372.607708 | 676.464750 | 885.745500 |
| 6 | 1394.716292 | 699.753666 | 815.617584 |
| 7 | 1356.158750 | 683.051583 | 767.788125 |

The independent allocation-only cohort keeps property hints enabled in both
LibJS modes. Callback medians are **1057.950 ms control / 713.685 ms candidate**:
a further **32.5% reduction** from elision. The median paired ratio is 0.692604,
and highest-candidate/lowest-control is 0.776606. V8's callback median is
880.044 ms in that cohort; candidate/V8 is 0.810965 by medians, 0.784593 paired,
and **0.980583** conservatively. Its total medians are 1090.043 / 748.011 /
983.136 ms (control/candidate/V8). Every candidate beats V8 in this cohort too,
with a small worst-case margin. Keep comparisons within each cohort; do not
multiply medians from changing source epochs or host conditions.

Diagnostics in both cohorts change **185,875 arguments objects created** into
**zero created / 185,875 elided**. The candidate still executes the same 185,871
native entries, 880,257 fast steps and 1,698,390 dynamic-helper steps as its
control. Thus it avoids helper-side allocation rather than skipping bytecode or
changing the workload. Both LibJS modes reuse all 27 native executables without
compiler invocations or cache misses; the compiler is disabled for warm visits.
All cancellation, first-subtree collapse, 101-row restoration, no-error and
frame-cleanup checks pass. Each cohort retains all 25 process attempts; all
processes, drivers and runtime guards exit zero. Their sampled peak aggregate
RSS is 593,870,848 / 593,707,008 bytes under 3 GiB. Durations are 39.955 / 35.919 s;
one-minute host loads are 8.41–9.61 / 8.02–8.28 on 18 logical CPUs.

**53 distinct focused functions** pass in default and GC-disabled modes: the
36-function arguments/parameters/ECMAScript/native-tier/cache group and the
23-function async/generator group share the six new regressions. These cover
strict/sloppy mapping, defaults and arrow captures, eval conservatism, parserless
records, native-cache reopen, generators/async calls and all 99 tested budget
boundaries with identical completion and restored frames. The unchanged AST
corpus again matches **100/100**. The broader baseline failures described above
remain a validation limitation; this is not a new full-package pass.

The final executable SHA-256 is
`662ec7307a8fbfc0c996c9c719496a1b1ebc139b006e20a492a1ec8ee31d49e6`.
It retains the same optimized C mode, default GC and V8 adapter as the earlier
cohorts; build/compiler/guard exit zero, 260.382 s, sampled peak 11,158,962,176
bytes under 12 GiB. The canonical installed production bundle has not supplied
these measurements; managed commit hooks request its rebuild. The complete
local receipts are `libjs-hn-optimization-20261115/{combined,arguments}/results.json`
under `docs/performance/`, with guard logs and focused checks beside them.

Use the previous comparison command with `--optimization combined` or
`--optimization arguments` and the newly built executable to reproduce these
cohorts. The result remains an archived HN script/DOM measurement, excluding
browser launch, rendering, physical input/presentation and live navigation.

## Reproduction

Build the V8 adapter and one source-built executable containing both backends.
No browser bundle is copied or manually rebuilt. Keep compilation and runtime
inside their separate memory guards; use the default 12 GiB for compilation
and 3 GiB for runtime. Generated C and binaries stay outside `Build/`.

```sh
mkdir -p /tmp/vox-hn-engines
sh tools/run_v_tool.sh run_memory_bounded \
  --lock Build/hn-v8-UNIQUE.lock --report Build/hn-v8-UNIQUE.json -- \
  clang++ -std=c++20 -O3 -fPIC -dynamiclib -fvisibility=hidden \
    -I/opt/homebrew/include/node -Ibrowserjs/v8/include \
    browserjs/v8/jsc_on_v8.cpp /opt/homebrew/lib/libnode.147.dylib \
    -framework CoreFoundation -Wl,-rpath,/opt/homebrew/lib \
    -Wl,-install_name,@rpath/libVoxJSCOnV8.dylib \
    -o /tmp/vox-hn-engines/libVoxJSCOnV8.dylib

env V3_STR_CAP=1 V_MACOS_V3_NO_FALLBACK=1 \
    VOX_CHROME_TEST_FILE=sites/hacker_news_engine_benchmark_test.v \
  sh tools/run_v_tool.sh run_memory_bounded \
    --lock Build/hn-build-UNIQUE.lock --report Build/hn-build-UNIQUE.json -- \
  sh tools/test_address_bar.sh -w -n -b c -no-parallel -cc clang \
    -memory-limit 10G -prod -no-prod-options -d vox_v8 -skip-running \
    -cflags '-O2 -I/Users/alex/code/vox/browserjs/v8/include' \
    -ldflags '-L/tmp/vox-hn-engines -lVoxJSCOnV8 -Wl,-rpath,/tmp/vox-hn-engines' \
    -o /tmp/vox-hn-engines/hn-engines

sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
    --lock Build/hn-run-UNIQUE.lock --report Build/hn-run-UNIQUE.json -- \
  python3 tools/benchmark_hn_engines.py \
    --binary /tmp/vox-hn-engines/hn-engines \
    --output docs/performance/hn-engines-UNIQUE --pairs 7 --cycles 500

sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
    --lock Build/hn-frames-UNIQUE.lock --report Build/hn-frames-UNIQUE.json -- \
  python3 tools/benchmark_hn_property_lookup.py \
    --binary /tmp/vox-hn-engines/hn-engines \
    --output docs/performance/hn-frames-UNIQUE \
    --optimization frames --pairs 7 --cycles 500

python3 -m unittest discover -s tools -p benchmark_hn_engines_test.py
```
