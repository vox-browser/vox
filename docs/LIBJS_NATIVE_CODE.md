# LibJS cached native-code experiment

The [2026-11-15 document cache](LIBJS_REVISIT_CACHE.md) now saves native code on
the first visit and loads it before first execution on a later visit, with
process-local parsed-source reuse. The manual experiment below is historical;
its warmup requirement and HN callback timings do not describe the new workflow.

This is an explicit, standalone LibJS experiment. Browser settings and the default
JavaScriptCore backend are unchanged. The experiment runs Hacker News's unchanged
`hn.js` against Vox's translated native DOM, warms its comment handlers, and
compiles the observed cached bytecode to a local native shared library.
Three seven-pair cohorts demonstrate working native code and binary cache reuse,
but no reliable HN callback speedup. Keep this tier opt-in; it provides no
evidence for a browser-wide performance change.

## Implementation

`VM.profile_native_code()` counts entries into cached executables. After warmup,
`VM.compile_native_code(directory, compiler, minimum_calls)` selects warmed
executables, emits C and invokes clang with `-O2 -fno-strict-aliasing`. It loads
the resulting library into that VM. The embedder chooses when compilation runs;
there is no automatic compiler invocation during ordinary script execution.

Native code implements register moves, control flow, returns, numeric arithmetic,
numeric comparisons and selected unary operations. Runtime tag checks precede
numeric operations. Strings, BigInts and other values use the existing interpreter
helpers when necessary. Binding/property access, calls, object creation and
exceptions also use those helpers, preserving current environments, prototypes,
coercion hooks and source locations. A guard exit executes the current instruction
once; it never restarts a function or repeats its side effects. Unobserved
executables remain interpreted. Instruction budgets are shared with nested calls
and consumed exactly once per executed bytecode instruction.

The cache key includes generated code, the Value layout and tag constants,
register/control-flow layout, target OS/architecture and compilation options.
The library contains no realm pointers, constants or captured JavaScript values;
fresh VMs supply their own frames and runtime callbacks. Generated C is removed
after compilation. The caller supplies an executable cache directory, separate
from the HTTP resource cache. Currently the warmup and executable selection must
be repeated in a new VM before its matching binary can be loaded. This is a
baseline compiler with runtime guards, not a type-feedback optimizing JIT or OSR.
It does not add language or DOM compatibility beyond the interpreter.

`use_native_code(false/true)` supports matched comparisons without rebuilding.
`close_native_code()` unloads the library; the embedder must call it before
discarding an enabled VM. Profiling, compilation, switching, diagnostics and
unloading reject attempts made during active JavaScript execution. Diagnostic
counters are enabled separately and disabled during timing.

## Workload and protocol — 2026-11-14

The fixed discussion contains 101 comments. The timed workload repeatedly
collapses and expands the first subtree (`50232467`) using native DOM click
dispatch and the real HN event listeners. It excludes network, HTML parsing,
script parsing/initialization, warmup, compilation/loading, correctness audits,
browser startup, layout, paint and PNG encoding. It establishes no rendering,
scrolling, live navigation or Brave performance claim.

The standalone program creates a `libjs.VM` and a `libjsdom.Host`. It does not
create a JavaScriptCore context or fall back to JSC. The executable links system
JavaScriptCore through the broader HTML dependencies; library linkage alone is
not evidence of the executing JavaScript engine.

Both modes perform eight interpreted warmup collapse/expand cycles and prepare
the same native library. The control disables native execution, retaining the
same warmed bytecode and tier metadata; the candidate enables it. A separate
eligibility run enables native counters. Timed runs require counters to be zero
and the native file to be a cache hit. Every trial uses a fresh process, verifies
click cancellation and exact restoration of every original comment-row class,
and checks that no JS frame or callback error remains. The final harness also
verifies actual collapsed state and hidden descendants in the selected tier
before timing. Seven pairs reverse control/candidate order on alternating pairs;
all attempts and outliers are retained.

The executable, native library, fixtures and readable linked dependencies are
hashed and checked throughout each cohort. System shared-cache libraries have
no separate readable file; the complete `otool -L` list is retained. There is no
browser profile or HTTP cache in this engine-only harness. OS filesystem/dynamic
loader caches are retained. Raw commands, output, exit codes, timestamps, host
load and hashes remain in local ignored JSON files under
`docs/performance/libjs-native-hn-20261114-*`.

The live `https://news.ycombinator.com/hn.js` fetch returned HTTP 200 and matched
the archived 5,217-byte body on this date. The fixtures have SHA-256:

* Script: `2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0`
* Discussion HTML: `04bfd8b86c3a9098e4e4a8428e65142e4144d5f8184d66b802b26243baf19c07`

## Corrected native tier: final cohort

After fixing native error unwinding, another production C harness was built and
the same seven-pair, 2,000-cycle protocol was repeated. All fifteen processes
(one diagnostic and fourteen timed runs) exited zero, restored all 101 comment
classes, verified actual collapse and cancellation, retained no callback errors
or interpreter frames, and preserved all pinned input hashes. Timed runs were
cache hits with diagnostic counters disabled.

| Pair | Interpreted ms | Native ms |
| --- | ---: | ---: |
| 1 | 2757.620625 | 2795.872125 |
| 2 | 3008.439708 | 2954.442500 |
| 3 | 3297.239667 | 3144.039208 |
| 4 | 3269.584208 | 3277.237208 |
| 5 | 3238.945041 | 3405.350667 |
| 6 | 3283.278209 | 3361.600459 |
| 7 | 3099.933041 | 3165.020625 |

The medians are 3238.945041 ms interpreted and 3165.020625 ms native. Although
their ratio is 0.977176, the median paired ratio is **1.013871**: native was
**1.39% slower** by the paired statistic, and slower in five of seven pairs.
`max(native)/min(control)` is **1.234887**. Controls varied substantially while
one-minute host load ranged from 18.08 to 25.11 on 18 logical CPUs. This cohort
also establishes no reliable speedup. No default tier promotion or compilation
break-even claim is justified by these measurements.

The separate diagnostic again counted 738,000 native entries, 3,510,000 native
fast steps and 6,764,000 interpreter helper steps: about 65.8% of steps still
needed dynamic helpers. It selected 22 of 42 observed executables, totaling 533
bytecode instructions with 195 statically lowered instructions. Preparation on
the first cache miss was 496.656583 ms: 251.682959 ms compilation and 243.741708 ms
loading. Cache-hit prepare medians were 1.250583/1.160708 ms for control/native,
including load medians of 0.391250/0.372500 ms. OS loader/filesystem caches were
retained. These preparation costs are separate from timed callback execution.

Corrected executable SHA-256:
`2a37f73786c8c244f1e9a81eb3771415b05c22fe8f79c641241dd6e6de8da3a0`.
Native library SHA-256:
`dd36504a9de23095b0ef936ee3b07165620e9ba5d3a5f9ac8455678970710a85`.
The library is 50,696 bytes; its generated-code key is
`946dbe1ea3ef982312b862069fba51c917116af1ec7aebc7577dd50efb01f20b`.
The corrected C/clang/single-unit `-prod` harness built in 221.58 s, with a
5.38 GiB sampled aggregate RSS peak under the 12 GiB guard. The cohort took
50.23 s with a 580.4 MiB peak under the 3 GiB guard. All compiler, harness and
guard exits were zero. Local `libjs-native-hn-20261114-r3/results.json` preserves
all attempts, counts, commands, audits, exact nanoseconds, identities and host
readings. Keep comparisons within each pinned cohort; neither changed source
epochs nor different host load establish cross-cohort optimization credit.

## Earlier long cohort, before the unwind correction

The final harness verifies actual collapse in the selected tier before timing
2,000 collapse/expand cycles (4,000 clicks) per fresh process. All fourteen
unprofiled runs and the separate diagnostic passed cancellation, collapse,
101-row restoration, callback-error and frame-depth audits. No input hashes
changed. Every timed run was a native cache hit with diagnostic counters zero.
Browser processes were not involved; harness and memory-guard exits were zero.

| Pair | Interpreted ms | Native ms |
| --- | ---: | ---: |
| 1 | 4172.443500 | 3936.610750 |
| 2 | 4379.476875 | 3815.996958 |
| 3 | 4101.903416 | 3959.090625 |
| 4 | 3955.468542 | 3993.504375 |
| 5 | 3978.531000 | 4022.466000 |
| 6 | 4018.518084 | 4153.916208 |
| 7 | 3871.728666 | 4168.765125 |

The interpreted/native medians are 4018.518084/3993.504375 ms. The ratio of
medians is 0.993775, while the median paired ratio is **1.009616**: native was
0.96% slower by that paired statistic and slower in four of seven pairs.
`max(native)/min(control)` is **1.076719**. One-minute host load ranged from
15.46 to 17.07 on 18 logical CPUs. The shifting controls and differing aggregate
statistics leave no reliable performance improvement to credit. Neither cohort
supports paying a compilation cost for this workload; no break-even claim is
made from these noisy differences.

The separate 2,000-cycle diagnostic recorded 738,000 native entries, 3,510,000
native fast steps and 6,764,000 interpreter helper steps. About 65.8% of executed
steps still used dynamic helpers. These counters suggest that binding/property
access and calls deserve investigation before extending numeric lowering, but
are not a causal timing profile. Initial preparation took 554.852667 ms, including
406.898709 ms in compilation and 146.460208 ms in loading. Cache-hit preparation
medians were 1.562208/1.596042 ms for control/native; load alone was
0.480458/0.490750 ms. All these costs are separate from callback timing.

Final executable SHA-256:
`7343333d83accca7f5374f2ca66c6fed3f212e75cf0332795aa73ca63712cf89`.
Native library SHA-256:
`30a1c9db252b70045b8843626e7406c82ae881c63021faddf5092467bef8d493`.
The library is 50,696 bytes; its generated-code key is
`58d983874ae0a8a03ea48732057acb9fb71d3619326980a7fac931e5aa666c50`.
The final build used current V `0.5.2 cbfc1be`, the C backend, literal `-prod`,
clang and one C unit. It took 107.86 s with sampled peak aggregate RSS 5.37 GiB
under the unchanged 12 GiB guard, exiting zero. The runtime cohort took 64.53 s
with sampled peak aggregate RSS 580.4 MiB under a 3 GiB guard, exiting zero.

The cohorts use different pinned harness executables. Compare control and
candidate within each cohort; differences between their absolute times or
startup costs are not native-tier optimization credit. Local
`libjs-native-hn-20261114-r2/results.json` retains all commands, exact nanoseconds,
stdout/stderr, audit results, hashes and host readings. The local
`libjs-native-hn-20261114-checks.json` retains build/test/benchmark guard receipts,
including failed attempts. Concurrent canonical-checkout changes were preserved;
the native-tier files entered shared commit `5ed3e8155` while another session
committed the shared index. Shared history was not rewritten.

## Initial pilot

The first seven-pair cohort timed 200 collapse/expand cycles per process. Its
end-state audit passed, but it predates the additional selected-tier collapse
audit. Keep it as an initial diagnostic, not a substitute for the final cohort.

| Pair | Interpreted ms | Native ms |
| --- | ---: | ---: |
| 1 | 418.322000 | 411.616875 |
| 2 | 366.477666 | 405.533791 |
| 3 | 361.526375 | 351.559208 |
| 4 | 323.404584 | 343.456334 |
| 5 | 333.780208 | 346.789000 |
| 6 | 361.491667 | 358.953792 |
| 7 | 366.230875 | 370.601625 |

The ratio of medians is 0.992884, but the median paired ratio is 1.011934 and
`max(native)/min(control)` is 1.272761. This is not a reliable speedup. On this
18-CPU host the one-minute load ranged from 29.47 to 30.56 during the cohort;
other builds and a VM were active.

The separate diagnostic observed 42 executables, compiling 22 with 533 bytecode
instructions, including 195 statically lowered instructions. During 200 cycles
there were 73,800 native entries, 351,000 native fast steps and 676,400 interpreter
helper steps. These counts establish path execution, not an unprofiled timing
result or a causal profile. Initial generation/compilation/loading took
566.062417 ms, including 414.471792 ms in compilation and 146.985042 ms in load.
Subsequent prepare medians were 1.45/1.42 ms for control/native. The library is
50,696 bytes. Most steps still require dynamic helpers; lowering numeric/control
operations alone did not demonstrate an HN improvement.

Pilot executable SHA-256 is
`e89adfb0f3cad8b7310eb1f1960a04d49ef53594e37d2d8b1a7ca2ec76b6cb15`;
complete per-run evidence is recorded in local
`libjs-native-hn-20261114-r1/results.json`. The native library SHA-256 is
`d3a66e93a6ac5e668eac8032bc5ae63ceee3f59583b0a3bc46cdb55da740b087`.

## Reproduction

Build from the canonical checkout, keeping generated compiler output outside
`Build/`. This uses literal V `-prod`, the C backend, clang and one C unit:

```sh
env V3_STR_CAP=1 V_MACOS_V3_NO_FALLBACK=1 \
  sh tools/run_v_tool.sh run_memory_bounded \
    --lock Build/libjs-native-build-UNIQUE.lock \
    --report Build/libjs-native-build-UNIQUE.json -- \
  "$HOME/code/v/v" -w -n -nocache -b c -no-parallel -cc clang \
    -memory-limit 10G -enable-globals -prod \
    -o /tmp/vox-libjs-native-hn tools/libjs_native_hn.v

sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
    --lock Build/libjs-native-hn-UNIQUE.lock \
    --report Build/libjs-native-hn-UNIQUE.json -- \
  python3 tools/benchmark_libjs_native.py \
    --binary /tmp/vox-libjs-native-hn \
    --output docs/performance/libjs-native-hn-UNIQUE \
    --pairs 7 --cycles 2000 --warmup 8
```

`V3_STR_CAP=1` is the compiler's existing reduced autostringification setting.
Without it, the broad HTML/DOM import graph exceeded the 12 GiB guard in the
initial `-prod`, C-O2 and C-O0 build attempts. Those attempts exited guard 125 /
child 137; an explicit compatibility-compiler attempt rejected `-memory-limit`
before compilation (exit 1). The first guarded reduced-stringification build
reached C compilation but exposed a generic encoder name collision with a local
record named `Result` (exit 1). Giving the record a distinct name fixed that
tooling issue. The successful pilot build took 151.66 s and peaked at 5.38 GiB
sampled aggregate RSS, with compiler/guard exits zero. No memory limits,
pixel references or tolerances were relaxed, and no shared browser bundle was
copied or rebuilt manually for this experiment.

Six native-tier tests cover string/BigInt guard exits, dynamic property values
and replacement callbacks, exceptions, truthiness, signed zero/NaN, nested call
budgets, cache reuse in fresh realms with different heap strings, native/interpreter
switching, compiler failure, exact budget exhaustion at 64 boundaries and
preservation of the throwing bytecode position during unwind jobs. They
pass in default-GC and GC-disabled modes. The focused interpreter, ECMAScript
function and object-binding files also pass in both modes. This is focused
experimental coverage, not a new full LibJS/AST or production visual parity claim.
No retired-instruction savings are measured or credited toward broad-suite cadence.

An additional full default-GC sweep was attempted after the focused checks and
cohorts. It passed 83 files before concurrent uncommitted Error-intrinsics changes
began failing compilation at `libjs/error_intrinsics.v:31`: `FunctionObject` has
no `object` field. After repeated identical compilation failures, only this
experiment's verified test process group was stopped. Its guard recorded child
exit 143, elapsed 168.83 s and peak sampled aggregate RSS 4.31 GiB. Failed files
did not execute their tests. The concurrent owner fixed and committed that code
as `0d6c5a339`; the restarted default-GC sweep passed 268/268 files (318.83 s,
5.12 GiB sampled peak RSS), and the unchanged upstream AST driver matched 100/100
fixtures exactly (11.22 s, 478.3 MiB peak RSS). All successful command/guard exits
were zero. The GC-disabled sweep then passed 208/268 files before concurrent
removal of `Expression`'s heap annotation caused 60 compilation failures at
`conditional_tail.v:62`. It exited 1 after 282.66 s, with 5.10 GiB sampled peak
RSS. After the owner adjusted the conditional traversal, the no-GC type-check
passed, and all 60 failed files passed in a separate recovery batch (62.40 s,
4.78 GiB sampled peak RSS, command/guard exits zero). This is a 268-file union
across that sweep and recovery, not a single clean no-GC sweep. The concurrent
implementations were not edited or reverted to manufacture passing results.
After that AST ownership recovery, the unchanged AST driver again matched all
100 fixtures exactly (3.84 s, command/guard exits zero). Its upstream reference
is `963d46a829f3e1b79f44dba9d02afb70654300fa`; individual input/expected hashes
are retained in the local checks receipt.

Review then added a sixth native regression: an uncaught native slow-path error
must retain its real bytecode PC while queued unwind jobs run. Before the fix it
reproduced `4294967295` instead of PC `1`; the native dispatch exit marker had
overwritten the throwing instruction. The fix leaves that PC installed. The
six-case focused file passes in both GC modes; the completed default-GC sweep
above covered the earlier five-case file. The measured cohorts above predate
this exception-only correction; a corrected-build cohort is recorded separately.

## Adjacent argument registers, 2026-11-18

A frozen GitHub startup sample on `fa6b0d0c…47c9` observes 123 samples
under the outer native entry, 122 under the slow callback and 110 under call
handling. These are inclusive stacks that include callee work. The first
native sampling attempt times out and is retained. The shorter retry collects
its stack while the browser completes a clean compiler-disabled capture.

`8f3436768` lets the existing synchronous-call path borrow a checked span of
initialized adjacent registers. The permitted ECMAScript and native callees
copy the incoming values into their own frames before author code runs.
Exposed frames, nonadjacent operands, other operand types and failed bounds
or initialization checks use the existing workspace path. The argument
workspace counter continues to count uses of the workspace itself.

A focused V `-prod -prealloc -gc none` diagnostic compiles and reuses one
native entry containing 750,000 two-argument calls. Both modes execute the
same bytecode, native library, budget and callee, returning 42. Separate
instrumented runs record 750,000 workspaces with an explicitly exposed
caller frame and zero with adjacent registers in a private frame. Both
report one cache hit with zero misses or compiler invocations on reopen.
An earlier probe placed exposure inside an assertion and failed the
workspace-count check in production mode. The corrected probe calls it
explicitly and verifies the return value and counters.

Seven alternating fresh-process pairs have native counters disabled.
Median retired instructions are **1,325,381,467** on the exposed workspace
path and **1,123,529,478** with adjacent register borrowing, **15.23% fewer**
for this isolated call loop. Every run exits zero with unchanged inputs.
The focused build exits zero under the 12-GiB guard. The 3-GiB diagnostic
guard records 2.139045041 seconds and 114,966,528 sampled peak bytes.
The regression source covers address identity and fallback predicates, and
remains unrun under the automated-suite hold.

The installed browser predated the borrowing change during the isolated
probe. Sample files, commands, exact counts, run and guard receipts stay local in
`docs/performance/libjs-github-browser-20261116/libjs-github-native-dispatch-20261118/`.

### Published browser on frozen GitHub

The managed single-C `-prod` build publishes executable
`09e4dcb3fe88617ba5afe0a6af7a20c957f203f5bc2a000d21917bfbde539e76`.
Its sealed source manifest contains the exact `8f3436768` caller-register
implementation. The previous `fa6b0d0c…47c9` executable and this build have 30
sealed source differences, including DOM and browser changes. The archived
page, policy, tools, native dependencies, optimized cache, audit config bytes,
and standard-raster reference have the same hashes in both cohorts.

A separate instrumented launch reuses generated-code ABI
`8de10f8472f7f5c449c9bb03b99b7bf95fd688e163bc4e32c0cdd6393711d1e7`
with `/usr/bin/false` as the compiler. It records 2,948 hits and 475,731
native entries with zero misses, pending or invalid entries, compilations,
or compiler calls. The previous instrumented capture recorded 664,754
scratch-buffer calls and 411,660 native entries. This capture records 290,598
scratch-buffer calls. The different execution counts and source inputs keep
this a build-level comparison. The isolated call probe measures borrowing
with the same bytecode and callee.

Seven alternating interpreter and cached-native pairs count instructions
from fresh exclusive browser resource-coalition creation through the native
`capture_document_encoded` marker. This includes browser startup, window
setup, and PNG encoding. File writing, audits, teardown, and GPU and
outside-service instructions fall outside the measurement. Each launch uses
a private profile and empty HTTP cache. The run retains OS filesystem and
shader caches. Native diagnostics are disabled in the measured runs.

| Pair | Interpreter instructions | Cached native instructions |
| ---: | ---: | ---: |
| 1 | 75,866,455,189 | 78,011,809,203 |
| 2 | 69,846,567,542 | 78,242,573,882 |
| 3 | 75,923,281,070 | 72,410,504,111 |
| 4 | 69,984,748,343 | 78,073,878,394 |
| 5 | 75,848,788,670 | 71,959,897,275 |
| 6 | 69,860,254,794 | 77,919,324,548 |
| 7 | 68,026,738,479 | 78,364,042,861 |
| Median | **69,984,748,343** | **78,011,809,203** |

Cached native uses **11.47% more instructions** at the median and wins two
of seven pairs. The highest native count is 1.152 times the lowest
interpreter count. Relative to the previous cohort, the cached-native median
decreases 0.06% and the interpreter median decreases 7.58%. One-minute host
load ranges from 7.47 to 9.88 on 18 CPUs, versus 8.98 to 13.87 previously.

All 14 captures match the pinned 1024×768 Vox reference pixel for pixel and
pass document ownership and the repository content audit. Every capture has
33 file rows, 56 commit links, the latest commit and README, and 81 evaluated
modules with fulfilled promises. JavaScriptCore stays uninitialized and the
three replayed compatibility script bodies match their pinned hashes. Each
native run has 2,948 hits and zero misses, compiler calls, or pending or invalid
entries at capture and shutdown. All browser, harness, and guard exits are
zero. The guard adopts 28 browser processes across 14 trials and reports a
sampled aggregate peak of 8,015,691,776 bytes over 132.040 seconds. The
instrumented run also exits zero at 8,001,798,144 bytes over 14.459 seconds.
The regular raster reference is the retained Vox PNG. This cohort covers
the frozen repository landing page.

Raw receipts and input fingerprints remain local under
`docs/performance/libjs-github-browser-20261116/libjs-github-registers-after-20261118/`.

## Argumentless synchronous calls, 2026-11-18

A separate instrumented pair on `23ba3183…3bb` passes the pinned GitHub
image, repository audit and all 81 module completions in both modes. The
native capture records 2,947 hits with zero misses or compiler calls. Its
main-thread trace contains 129 samples under native invocation, 128 under
the slow callback and 127 under call handling. These are inclusive stacks
that contain nested callee work. The interpreter sample window falls after
JavaScript execution. Both samplers, browsers and the 12-GiB guard exit
zero, with a sampled peak of 7,899,856,896 bytes over 19.230 seconds.

`2da4ea24d` passes an empty view directly to the existing concrete
synchronous callees when a bytecode call has zero arguments. The view
needs no backing storage and works with an exposed caller. The callee still
sets up its own frame, with zero passed arguments and the original receiver.

Two focused `-prod -prealloc -gc none` executables run the same 750,000-call
loop with an exact shared optimized native library. The generated host C
diff contains the empty-call branch and a reordered pair of declarations.
Both reopens return 42, checking the receiver and the missing first
argument on every call. They report one native entry, 750,000 slow call
steps, one cache hit, and zero misses or compiler calls. Workspace usage
falls from 750,000 to zero. A separate script passes default arguments,
`arguments.length`, bound and proxy calls, receiver binding, and exception
propagation. The focused regression source includes exposed callers and
remains unrun under the automated-suite hold.

Seven alternating fresh-process pairs disable the diagnostic counters.
Median retired instruction counts are **1,105,955,657** before and
**1,050,183,390** after, **5.04% fewer** for this loop. All 14 processes and
the 3-GiB guard exit zero. The guard records 2.213 seconds and a sampled
peak of 85,065,728 bytes. The production hook requests the build used in
the browser verification below.

Raw captures, stacks, exact counts, input hashes and guard receipts stay
local under `docs/performance/libjs-github-browser-20261116/libjs-github-dispatch-23ba-20261118/`.

### Budget and unwind verification

A separate `-prod -prealloc -gc none` probe runs a nested zero-argument
call chain with a caught exception, a default parameter and a checked
receiver. Interpreter and cached-native execution agree at each instruction
limit from 1 through 160. Limits through 58 report instruction-budget
exhaustion, and limits from 59 return 42. Each execution restores the
context stack to its starting depth.

The compiler-disabled native probe records five cache hits, 732 native
entries and zero workspace calls. It has zero misses, invalid or pending
entries, and compiler calls. The executable and cache files match their
initial hashes after the run. Seed, interpreter, native and memory guard
exit zero. The 3-GiB guard records 0.773 seconds and 119,652,352 sampled
peak bytes. The exact outcomes and receipts stay local under
`docs/performance/libjs-github-browser-20261116/libjs-github-empty-calls-after-20261118/`.

The same standalone probe with `-prod -gc boehm` produces identical results
at all 160 limits, with a separately seeded cache. Its native reopen again
records five hits, 732 entries, zero workspace calls, and zero misses or
compiler calls. The 3-GiB guard exits zero at 0.798 seconds and 105,496,576
sampled peak bytes.

### Repeat control on the published emitter build

The worker attempt `20261118-022652-880e7db2` sealed its LibJS sources
before the empty-call change. Its compiler-input check rejects a concurrent
edit to `browsernet/cancellable_transport.h`, so the installed production
executable stays at `23ba3183…3bb`.

While the managed retry is pending, another seven alternating pairs use
the same pinned executable, optimized native libraries, replay, policy,
tools and image. All 14 new captures match the pinned Vox image and audit,
fulfill all 81 modules and serve all three pinned compatibility script
bodies. JavaScriptCore stays uninitialized. Cached-native runs have
2,946–2,948 hits with zero misses or compiler calls. All browsers, the
harness and guard exit zero. The guard adopts 28 processes and records
124.662 seconds and 7,929,036,800 sampled peak bytes.
[Original emitter cohort](LIBJS_NATIVE_GENERATED_CACHE.md#published-emitter-build-on-frozen-github)

| Cohort | Interpreter median | Cached-native median | Native above interpreter |
| --- | ---: | ---: | ---: |
| Emitter report | 70,043,818,443 | 77,903,580,950 | 11.22% |
| Same-build repeat | 75,845,204,833 | 77,822,647,059 | 2.61% |

The same executable's native median moves **−0.10%** and its interpreter
median moves **+8.28%** between cohorts. These counts include the full
browser startup and capture window. The repeat supplies an observed
variation check for the later build comparison. Exact counts and receipts
stay local under
`docs/performance/libjs-github-browser-20261116/libjs-github-empty-calls-after-20261118/`.

For the two median interpreter trials, the root-process markers place
9,450,512,454 and 9,367,942,667 instructions before first document paint.
From that marker through PNG encoding, the numbers are 59,924,685,963 and
65,813,104,936. Both trials log seven paint-command builds. This diagnostic
places the increase after first paint. The acceptance comparison uses the
full coalition startup-to-PNG count.

### Published empty-call build on frozen GitHub

The worker attempt `20261118-024638-c98004e8` includes the patch and stops
when the production input inventory changes during sealing. The next
inventory includes the new native frame-clear header. The managed single-C
`-prod` build then publishes executable
`9c165f7ab3dc15fd6fcc7a0d89336aefde735c3a9f983c15248727de89918301`.
Its verified source manifest includes the exact `2da4ea24d` workspace file.
The candidate and control differ in 29 sealed source inputs, including
RegExp literals, call-frame reuse, keyed collections and rendering.

The existing `-O2` cache files, ABI, browser dependencies, archived page,
compatibility policy and standard-raster reference match the repeat
control. The candidate eligibility run records 2,948 hits and 483,835
native entries, with zero misses, pending or invalid entries, compilations
or compiler calls. It records 267,526 scratch-buffer calls, compared with
292,074 in the repeat control's 480,307 native entries. Both diagnostics
pass the pixel, content and capture-ownership checks. This is an observed
change across builds. The standalone loop isolates the empty-call change.

Seven alternating fresh-process pairs use the same private-profile and
empty HTTP-cache protocol. The exclusive coalition counter covers startup,
window setup and native document PNG encoding. PNG file writing, audit,
teardown, GPU and outside service work fall outside that endpoint. Native
diagnostics are disabled during the numbered runs.

| Pair | Interpreter instructions | Cached-native instructions |
| ---: | ---: | ---: |
| 1 | 66,686,954,974 | 76,242,593,566 |
| 2 | 66,709,279,635 | 67,118,090,473 |
| 3 | 75,658,668,175 | 74,366,839,394 |
| 4 | 66,639,850,358 | 74,559,625,963 |
| 5 | 66,319,178,698 | 75,879,454,114 |
| 6 | 76,037,526,441 | 76,331,726,902 |
| 7 | 75,658,475,605 | 70,245,119,601 |
| Median | **66,709,279,635** | **74,559,625,963** |

The cached-native median is **4.19% lower** than the same-cache repeat
control. The interpreter median falls **12.05%** across those builds.
On the candidate, cached native uses **11.77% more instructions** by the
ratio of medians and uses fewer instructions in two of seven pairs. The
median paired ratio is 1.00613 and the highest-native/lowest-interpreter
ratio is 1.15098. One-minute load ranges from 6.47 to 7.84 on 18 logical
CPUs, compared with 5.58 to 6.73 during the repeat control.

All 14 captures match the pinned 1024×768 Vox image and the full repository
audit. All 81 modules fulfill, all three compatibility scripts match their
pinned bodies, and JavaScriptCore stays uninitialized. Native shutdown
receipts show 2,946–2,949 cache hits with zero misses, compiler calls,
compilations, pending or invalid entries. All browser, harness and guard
exits are zero. The guard adopts 28 processes and records 129.417 seconds
and 7,027,703,808 sampled peak bytes. Exact counts, image audits, input
hashes and failed-build receipts stay local under
`docs/performance/libjs-github-browser-20261116/libjs-github-empty-calls-after-20261118/`.

## Operand slot decoding, 2026-11-18

A paired profile on `9c165f7a…8301` matches the pinned GitHub image and
repository audit in both modes and fulfills all 81 modules. The native
capture records 2,947 hits and zero misses or compiler calls. Main-thread
stacks include operand slot resolution in 19 of 716 interpreter samples
and one of 708 native samples. These are instrumented observations.

`ff9d28415` resolves the encoded tag and bounds in one step, eliminating
the intermediate checked tag result in the common operand path. Registers,
locals, constants and arguments keep their original slot and error rules.
A standalone probe compares the exact old and new decoder bodies over
2,560 cases, including all eight tags, read and write access, and boundary
indices. All 360 valid offsets and 2,200 error messages match. Focused
regression source remains unrun under the automated-suite hold.

Two single-C `-prod -prealloc -gc none` builds verify a 750,000-call loop.
Their generated host C differs in the slot decoder and the embedded source
used for cache ABI hashing. Both compile exactly the same 5,006 native C
bytes and matching machine-code sections, then reopen with the compiler
disabled. Each returns 42 and records one cache hit, zero misses or
compiler calls, and 750,000 native slow call steps in the separate
eligibility run. The interpreter returns the same result.

Seven alternating fresh-process pairs per tier count retired instructions
through process exit with native diagnostics disabled during measurement.

| Focused workload | Previous median | Direct tag median | Reduction |
| --- | ---: | ---: | ---: |
| Cached native | 1,077,818,478 | 1,068,678,071 | 0.85% |
| Interpreter | 2,037,325,893 | 2,014,575,108 | 1.12% |

All 28 processes and the 3-GiB guard exit zero. The guard records 4.066
seconds and 85,704,704 sampled peak bytes. The source-based ABI fingerprint
includes `operand.v`, so the new production build requires a new cache
partition. The GitHub profile uses the installed predecessor. The managed
hook requests the production build for page-level verification.

Raw profiles, exact counts, generated C and guard receipts stay local under
`docs/performance/libjs-github-browser-20261116/libjs-github-call-profile-9c16-20261118/`.

### Mixed operand frames and live GitHub control

A standalone VM probe on the current operand decoder returns 42 across
interpreted and cached-native runs. The interpreter reads an argument, adds
a constant through two local slots and a register, then writes 42 back to the
argument. Frame validation rejects the same stream at arity zero with
`Argument out of range`. The native stream reads the argument through
`GetArgument` and records one slow step and three generated fast steps. Its
fresh reopen records one cache hit and zero misses or compiler calls. The
3-GiB runtime guard exits zero with a sampled peak of 64,290,816 bytes.

Direct navigation to the live `https://github.com/vlang/v` page uses the
installed predecessor `9c165f7a…8301`. An initial run reuses the archived
generated-code cache for 2,838 hits and reports 180 misses. The interpreter
control and the archived-cache run match the four repository audit groups.
Two private cache preparations time out during Clang `-O2` compilation. The
following reopen still has 29 misses. An `-O0` seed ends before hydration
completes, and its reopen reports two misses. These attempts are retained.

The final seed waits for a commit link in every file row and an active
Sponsor control before the four-second document capture delay. It extends
the private cache at `-O0`, retaining the earlier optimized libraries.
The fresh reopen with the compiler disabled records **3,014 hits**, zero
misses, compiler calls, compilations, pending or invalid entries, and
673,140 native entries. All 76 modules evaluate and fulfill, and JSC stays
uninitialized. The complete audit matches the interpreter, including 34
file rows, 53 commit links, the latest commit and the README. Both document
PNGs are 1024×768 and have SHA-256
`7723d292a3c1773a48db54c5270029b41743912e06a0eff8d173bec5ac9bb0d8`.

Both captures use fresh private profiles and HTTP caches with cookie imports
disabled. The browser, driver and guard exit zero and the native cache
hashes stay fixed through the reopen. The measured peak sampled process-tree
RSS is 7,053,164,544 bytes for the cached run and 7,095,926,784 for the
interpreter. This live check establishes functional cache reuse and rendering
equality between LibJS modes for the observed responses. Raw receipts remain
local under
`docs/performance/libjs-github-browser-20261116/libjs-github-operand-after-20261118/`.

### Published operand decoder on the frozen GitHub page

Production receipt `20261118-035602-2025fd74` pins executable SHA-256
`296096c89d6b92677139a110f2004bfe8df20d6ebc70db759960be3046c4e829`.
Its sealed source manifest includes the exact `ff9d28415` decoder. The
earlier production attempt stops when V package membership changes during
parsing. Both receipts are retained.

The preparation capture fulfills all 81 modules and matches the pinned
1024×768 Vox image. The audit independently rederives **13,915 keys** over
109 generated C units. All canonical function bodies match the prior corpus.
The new cache ABI is
`857d37bf4f2f69da0f581b6094ba9c3456b3b7a09045cfdca817c386c8034ab6`.
Each unit is freshly compiled with Clang `-O2`. Hashes verify the finished
libraries, and a separate fresh diagnostic records 466,831 native entries,
2,942 hits, zero misses and zero compiler calls.

Seven alternating fresh-process pairs use this optimized cache, with
diagnostics disabled. Retired instructions cover exclusive Vox coalition
creation through native PNG encoding, including startup and window setup.
The endpoint precedes PNG write, audit and shutdown.

| Pair | Interpreter | Cached native |
| ---: | ---: | ---: |
| 1 | 75,522,988,899 | 76,134,219,106 |
| 2 | 66,353,584,412 | 76,053,662,540 |
| 3 | 66,187,459,334 | 75,743,640,085 |
| 4 | 66,229,010,898 | 74,574,455,335 |
| 5 | 75,062,865,386 | 76,068,375,045 |
| 6 | 73,795,896,319 | 76,200,196,259 |
| 7 | 66,315,979,785 | 66,856,594,986 |
| Median | **66,353,584,412** | **76,053,662,540** |

Cached native uses **14.62% more instructions** by the ratio of medians
and more instructions in every pair. The median paired ratio is 1.03258
and the highest-native/lowest-interpreter ratio is 1.15128. Relative to the
preceding production cohort, the native median is 2.00% higher and the
interpreter median is 0.53% lower. The builds differ in 31 sealed inputs
and the current host's one-minute load ranges from 9.18 to 25.40, so the
isolated VM probe remains the per-change instruction measurement.

All 14 captures match the pinned Vox PNG and the complete frozen repository
audit. Each fulfills the 81 modules using LibJS, with JSC uninitialized.
The three compatibility-script bodies match the archive, and native library
and cache hashes stay fixed. The cached runs record 2,947–2,948 hits and zero
misses, compiler calls, compilations, pending or invalid entries. Browser,
harness and guard exits are zero. The 12-GiB guard adopts all 28 recorded
processes and reports 137.561 seconds and 6,990,544,896 sampled peak bytes.
The commands, images, input hashes and raw attempts stay local under
`docs/performance/libjs-github-browser-20261116/libjs-github-operand-after-20261118/`.

## Linear declarative binding lookup, 2026-11-18

A matched main-thread sample of `296096c8…e829` on the frozen GitHub
workload records 307 of 717 native-run samples inside a native entry.
300 include a slow callback. The linear declarative binding scan is the
leaf in 10 native-run samples and eight of 736 interpreter-run samples.
Both samples match the pinned document and repository audit, fulfill all
81 modules, and keep JSC uninitialized. The native run reuses 2,947 entries
with zero cache misses or compiler calls.

`6cb1be824` scans binding records in place. The loop already bounds each
index by the current array length. Its generated C reads the deleted flag
and name through the binding pointer, removing the generic array access
and record copy. Slot order, tombstones and UTF-16 name equality stay the
same.

Two single-C `-prod -prealloc -gc none` builds differ only in this
lookup's generated C. Seven alternating fresh-process pairs verify
1,200,000 hits and 400,000 misses per run, including checks for deletion,
recreated names, a supplementary character and unpaired surrogates.
The old and new medians are **460,014,013** and **413,587,277** retired
instructions through process exit, a **10.09% reduction** for this workload.
Six pairs improve. The first candidate run uses 479,224,676 instructions
and is retained. The separate default-GC executable reports the same lookup
results, and all focused program and guard exits are zero. Focused
regression source is included under the automated-suite hold.

A translated JavaScript closure reads an outer binding and a local UTF-16
identifier, returning 85 in both tiers. A fresh compiler-disabled reopen
records three cache hits, zero misses or compiler calls, four native
entries and 13 native fast steps.

The installed production sample predates the scan change. The managed hook
has requested a build containing it. The raw stacks, source and binary
hashes, measurements and guard receipts remain local under
`docs/performance/libjs-github-browser-20261116/libjs-github-cost-profile-2960-20261118/`.

### Same-build control and frame costs

Seven additional alternating pairs on the installed `296096c8…e829`
executable reuse the same optimized libraries, frozen responses, script
policy and image reference. The interpreter median is **66,494,302,215**
instructions and the cached-native median is **75,816,089,857**. From the
previous cohort on the same build, the medians move +0.21% and −0.31%,
respectively. Cached native uses 14.02% more by the ratio of medians and
uses fewer in one pair. One-minute host load ranges from 8.82 to 27.23
on 18 logical CPUs. All 14 captures match the pinned image and audit,
with 81 fulfilled modules and all three compatibility script bodies.
Native runs record 2,947–2,948 hits with zero misses or compiler calls.

The median trials differ by 25.3 million root-process instructions through
first document paint. Through PNG encoding, the cumulative intervals
between `frame_prepared` and `frame_complete` account for 12.74 billion
instructions in the interpreter trial and 18.49 billion in the native trial.
They cover the whole root process while those frames run. The interpreter
trial has two intervals above one billion instructions and the native trial
has three, despite identical final document pixels.

A separate pair uses the existing main-thread stage counters to inspect the
work inside those boundaries. On that pair, the native run records 0.447
billion more exclusive instructions in `javascript_execution_and_bindings`,
3.822 billion more in `flow_layout` and 3.044 billion more in
`paint_leaf_svg`. It records 25 flow-layout scopes and 508 SVG paint scopes,
compared with 22 and 338 for the interpreter. The stage counters include
tracing overhead and report these two captures. The uninstrumented cohort
supplies the startup-to-PNG comparison.

Raw inputs, exact phase totals and diagnostic attempts remain local under
`docs/performance/libjs-github-browser-20261116/libjs-github-binding-after-20261118/`.

### Published binding scan on frozen GitHub

Managed production receipt `20261118-043956-76e1c1ba` pins executable
SHA-256 `66f97ef08d4c9ff9ae1195cd80c9817add78ab82c27960580f1444a44101e77d`.
Its sealed source manifest contains the exact `6cb1be824` scan. The
17 embedded native cache inputs match the predecessor. A fresh diagnostic
reuses the existing ABI and optimized libraries with the compiler disabled.
It records 483,888 native entries, 2,947 cache hits, and zero misses or
compiler calls.

Seven alternating pairs count retired instructions from exclusive Vox
coalition creation through native document PNG encoding. They use fresh
profiles and HTTP caches, with cookie imports and native diagnostics
disabled. All 14 captures match the pinned 1024×768 image and the full
repository audit. The 81 modules fulfill on every visit using LibJS with
JSC uninitialized, and the three compatibility scripts match their archive
hashes. The native runs record 2,947–2,949 hits and zero misses, compiler
calls, compilations, pending or invalid entries. Cache and library hashes
stay fixed. Browser, harness and guard exits are zero. The guard adopts 28
processes and records 151.543 seconds and 6,964,117,504 sampled peak bytes.

The cached-native median is **75,462,692,949** instructions and the
interpreter median is **74,682,115,989**, a **1.05%** native increase by
the ratio of medians. Cached native uses fewer instructions in two of
seven pairs. The median paired ratio is 1.01012, and the highest-native
to lowest-interpreter ratio is 1.16903.

Relative to the same-cache repeat on the predecessor, the native median
falls 0.47% and the interpreter median rises 12.31%. In the selected
interpreter median trial, root-process instructions during the recorded
frame intervals rise from 12.74 to 18.60 billion. The native median trials
move from 18.49 to 18.62 billion in those intervals. The publications differ
in nine sealed inputs, including raster and native capture code. Host
one-minute load ranges from 7.70 to 12.89 in the published scan cohort.
The isolated lookup probe supplies the per-change instruction result.

A separate native sample maps 22 of 679 main-thread samples to the
inlined scan in the verified executable. Five land on the small-scope
loop and 17 on the linear fallback after a hint miss. All 22 have a
native-entry ancestor. The recorded address slide and disassembly identify
both loops. This capture also matches the pinned image and complete audit.

## Interpreter stack frame release, 2026-11-18

The native profile on `66f97ef0…e77d` includes frame deallocation in five
of 679 main-thread samples. All five have native-entry and call-dispatch
ancestors. The capture matches the pinned GitHub image and audit.

`fc3eec5f9` reads each retiring frame pointer once, clears its slot with
a typed store, and shortens the private unsliced array. Clearing the
retired slot keeps conservative collectors from retaining the frame via
unused capacity. Mark validation, release order and recycling use the
existing rules. A first variant retaining the generic deletion call
changes both measured medians by less than 0.09% and is retained.

Two single-C `-prod -prealloc -gc none` builds differ only in the
`InterpreterStack.deallocate` body in generated host C. The emitted native
C, cache ABI, cache key and native library text match exactly. Each fresh
reopen records one cache hit, zero misses or compiler calls, and 750,000
native slow call steps in the diagnostic. The loop returns 42 in both tiers.

Seven alternating fresh-process pairs per tier count retired instructions
through process exit. Every pair improves with direct tail clearing.

| Focused call loop | Previous median | Direct tail clearing | Reduction |
| --- | ---: | ---: | ---: |
| Cached native | 1,067,522,702 | 1,043,658,421 | 2.24% |
| Interpreter | 2,014,550,365 | 1,990,558,272 | 1.19% |

The default-GC probe checks a no-op mark, release of two nested frames,
preservation of arguments in retained public frames, and full unwind.
The focused regression source also checks recycling order and zeroes in
the retired capacity slots. It type-checks with the C backend and remains
unrun under the automated-suite hold. All 28 measured processes and
the guard exit zero. The 3-GiB measurement guard records 3.713 seconds and
99,221,504 sampled peak bytes.

The installed GitHub profile predates the frame change. The managed hook
has requested its production build. Raw measurements, source and binary
hashes, and the earlier attempts remain local under
`docs/performance/libjs-github-browser-20261116/libjs-github-frame-release-66f9-20261118/`.
