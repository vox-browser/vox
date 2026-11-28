# Hacker News: V profiler investigation

Measured 2026-11-17, following [private call-argument copies](HACKER_NEWS_ARGUMENT_COPIES.md).
**No additional runtime speedup is accepted.** Two profiler-guided candidates
were tested and removed after mixed or regressing matched results. The existing
runtime implementation is preserved. The earlier pinned result remains **3.8310×
conservatively and 48.7143% peak RAM**, with the strict 4× target open; this
investigation does not validate that result for a newer production browser.

## Profile and implementation leads

A private single-C-unit production build used V `-profile` with
`-profile-fns main__hn_engine_toggle`. Its fresh, compiler-disabled warm process
reused all **27** native executables, with zero misses/invalid/pending entries,
zero compiler invocations and no native-engine fallback. The full archived HN
script ran against the native DOM, restored all 101 comment rows and cancelled
navigation. Diagnostics observed 185,871 native entries, 1,780,554 fast steps and
798,093 slow steps.

The profile covers 1,002 toggles: the first audited collapse/expand and 500
callback cycles. Initialization, compilation and final audits remain outside
that selected entry. Selected V counters:

| Function | Calls | Inclusive ms | Self ms |
| --- | ---: | ---: | ---: |
| Generic array getter | 25,550,877 | 165.270 | 165.270 |
| UTF-16 equality | 2,700,890 | 134.823 | 104.562 |
| Linear own-property lookup | 648,818 | 195.076 | 99.472 |
| Clear reused context | 417,333 | 149.600 | 97.318 |
| Allocate reusable context | 417,333 | 259.597 | 95.597 |

These are **instrumented elapsed counters**, not CPU work or unprofiled speedup.
Inclusive recursive rows overlap and cannot be added. Self includes native and
uninstrumented callees; timer overhead changes this workload substantially. The
selected entry totals 4,422.253 ms, and its callback loop alone takes 4,399.264 ms.
The summary retains all rows, including any negative self values (none here).

The first profile compile exposed a V code-generation error in an unrelated
optional canvas tuple containing two fixed arrays. The failed attempt is
retained. The diagnostic compiled after exactly two equivalent generated-C
initializer repairs using named array members. The build helper now applies and
hashes that narrow compatibility repair **before sealing**, only for profiling
builds. Runtime benchmark candidates had no generated-C repairs.

## Unprofiled experiments

Both candidates used separate sealed `-prod -O3` single-unit executables with
preallocation/GC disabled, the original scope and seven alternating pairs per
control. The longer 2,500-cycle calling-thread CPU cohort is a separate diagnostic;
it cannot supply credit to the 500-cycle wall-time gate. All attempts, including
outliers and regressions, remain in the local evidence.

| Rejected candidate | 500-cycle control/candidate median wall ms | 2,500-cycle control/candidate median thread CPU ms | CPU pairs improving |
| --- | ---: | ---: | ---: |
| UTF-16 identity checks and exact-length `memcmp` | 111.516 / 110.862 | 614.760 / 615.551 | 5/7 |
| Bounded typed own-property key scan | 172.073 / 170.585 | 1,356.115 / 1,380.071 | 3/7 |

The first trial improves short median wall time 0.59%, but regresses longer
median CPU 0.13%. Its median paired CPU reduction is 0.36%, with two regressions.
The second improves short median wall time 0.86%, but only two short pairs improve
and the median paired result regresses 3.10%. Longer median CPU regresses 1.77%,
with a 0.27% median paired regression. Neither establishes a reliable gain.

Separate eligibility runs prove that the typed scan replaces exactly **647,500**
legacy scans with 647,500 direct scans, with equal VM instruction/reuse counts.
Generated C confirms removal of its generic array getter. That source-level
change alone does not establish a timing gain, so it is removed along with the
`memcmp` trial. UTF-16 equality, own-property lookup, and the HN runtime harness
have no remaining changes from either experiment.

Host contention became severe. On this **18-core** host, one-minute load moves
from 10.44 to 22.14 during the scan's short control cohort, then 21.65 to 41.59
during its CPU cohort. Later readings exceed **140** while shared compiler CI
runs. Short control wall times span 139.088–284.194 ms. Calling-thread CPU excludes
scheduling waits, but does not remove clock/cache/contention effects. Those
conditions prevent accepting a new wall-time speedup or a 4× result.

Both trials also retain seven-group current-V8, older-faster-V8 and separate RAM
cohorts including JSC. All ten cohorts pass content/cache/identity audits and all
benchmark/guard exits are zero. This is input/correctness verification, not
performance acceptance. The first trial's numerical both-warm gate passes at
4.0714× against a slower observed V8 minimum of 542.060 ms; that does not turn
mixed matched results into optimization credit. The later scan cohort fails
at 0.5675× conservatively under heavy contention, despite a pooled restarted-warm
median ratio of 5.8806×. No sample is discarded to improve either result.

RAM remains within the requested threshold in both **rejected** candidates:
`100 * 370,262,016 <= 50 * 760,020,992` and
`100 * 370,360,320 <= 50 * 760,184,832` bytes. These are the highest root-process
peaks of both warm modes against the lowest V8 root peak. They do not validate
removed code or replace the earlier accepted runtime evidence.

## Checks and retained tooling

Each experimental implementation passes **67 focused tests** with assertions in
default GC, GC-none and preallocation modes, including property-key identity,
live mutation, duplicate-key order, slices/Unicode boundaries, exact execution
budgets, unwinding and compiler-free native-cache reopening. Both AST corpus
checks are **100/100 exact**. The optional 0.5.2 attempt stops before compilation:
that compiler rejects the required `-memory-limit` option. No limit is bypassed.

The retained tooling adds `--profile` and `--profile-fns` to
`tools/build_hn_engine_benchmark.py`, the diagnostic-only C compatibility repair,
and explicit rejection of V-profiled binaries by the acceptance driver. All
**29** focused Python tests pass (19 evidence, two build compatibility, eight
profile summaries). The separate LibJS verification hold/parity status is
unchanged.

With the canonical HN test link initialized, build a private profile executable
through the usual memory guard, for example:

```sh
sh tools/run_v_tool.sh run_memory_bounded \
  --lock Build/hn-profile-UNIQUE.lock --report Build/hn-profile-UNIQUE.json -- \
  python3 tools/build_hn_engine_benchmark.py --engine v8 \
    --v8-adapter docs/performance/libjs-hn-2x-20261116/bin/libVoxJSCOnV8.dylib \
    --output docs/performance/UNIQUE/bin/hn-profile-v8 \
    --profile docs/performance/UNIQUE/profile.txt \
    --profile-fns main__hn_engine_toggle
```

Use the archived replay, private profiles/caches and the usual all-optimization
HN environment. Seed once, then restart with `VOX_HN_ENGINE_BENCHMARK=libjs-warm`;
the harness configures compiler `/usr/bin/false`. Rename the profile output after
each process because V writes the same configured path. Summarize it using
`tools/summarize_v_profile.py`. Build a separate executable without `--profile`
for any timing or RAM acceptance; the driver rejects the instrumented build.

The original [protocol and rendering limits](HACKER_NEWS_ARGUMENT_COPIES.md) are
unchanged: archived complete script, native LibJS DOM versus the V8/JSC compact
bridge, fresh processes/private caches, retained OS caches, and excluded process
startup/window/layout/paint/teardown. JSC is the pinned historical baseline.
This is not an isolated-JavaScript, full-browser or live-site comparison.

Local evidence remains in `docs/performance/libjs-hn-vprofile-20261117/` and
`docs/performance/libjs-hn-key-scan-20261117/`: profile rows/summaries, failed build,
compatibility transformation, all attempts, commands, host readings, guards,
source/build identities, candidate patches and rejected analyses. Generated
compiler inputs are retired after hashing; measured executables, native caches,
three build receipts and raw results remain local. No production browser rebuild
was queued manually; commits request the managed coalesced rebuild.
