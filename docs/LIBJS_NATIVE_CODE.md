# LibJS cached native-code experiment

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
