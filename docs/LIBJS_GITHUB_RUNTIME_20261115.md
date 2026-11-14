# GitHub compiled-JavaScript continuation, 2026-11-15

**Pixel-perfect GitHub rendering remains unachieved.** The native LibJS page
exceeds the unchanged 3 GiB runtime guard before an audit or PNG. A source-built
DOM/module diagnostic gets further through initialization, but all five failing
entries now stop on missing `WeakMap`, and no commit links hydrate.

The native compiler first appeared in `5ed3e8155`, despite that commit's
object-literal title: concurrent staged native-tier work was included. Persistent
first-instruction reuse across visits was added in `7ec82b601`; parsed-source
reuse across document visits followed in `07902ae2d`. The earlier cache cohort
and its limited performance scope are in [the revisit report](LIBJS_REVISIT_CACHE.md).

## Completed runtime work

| Commit | Behavior | Remaining boundary |
| --- | --- | --- |
| `d925de78e` | Set construction, SameValueZero keys, ordered mutation, live iterators, callbacks and abrupt iterator closing. | Set algebra methods. |
| `bf068d688` | Map construction, access/mutation and live ordered iteration using the same native storage. | Grouping and getOrInsert extensions. |
| `056f35f47` | Async declaration/expression creation retains source, names, length and async prototype identity without evaluating bodies. | Async calls, Promise/await execution and the AsyncFunction constructor link. |
| `a8c7ba38c` | `element.style` uses the real retained native CSS declaration block; property accessors, priorities, serialization, indexed declarations, mutations and feature detection are live. | Full CSS interface constructor/prototype ancestry and custom-element reaction wrapping. |
| `1ec8f2467` | Base-class construction, static/instance methods, accessors, strict computed keys, immutable inner names, mutable outer declarations and cached native execution. | Heritage, fields, private methods, super, static blocks and anonymous assignment-name inference. |

These are partial translations, without JavaScriptCore fallback. In particular,
async creation does not pretend to implement async execution, and WeakMap has
not been replaced with a strongly retaining Map shim.

The Set/Map and class tests execute the same scripts in two fresh VMs. The second
VM uses `/usr/bin/false` as its compiler, attaches persisted native entries and
executes dynamic operations through the runtime helpers. Each feature's focused
checks pass with default GC and with GC disabled. Native CSSOM checks pass in
both modes; the original Hacker News script's four DOM/event checks also pass,
including restoration of all 101 archived comment rows.

## Original-response initialization diagnostic

The unchanged `https://github.com/vlang/v` fixture retains its original HTML,
scripts, imports and response headers. Its manifest is SHA-256
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
the HTML is `a0f615f45a8745e26aa57443182e238ddcb678f19aa2915c69d5ef66ff7b1a08`.
The existing Brave PNG remains
`649abff51549508516e2e0681866ba81ce69e7112cfa8dc3446b9b76c99be3d3`.
Neither reference nor pixel tolerance was changed.

`tools/libjs_github_revisit.v` was rebuilt from the canonical checkout with
single-unit C/clang and literal `-prod`. Its SHA-256 is
`b3ab3d085b98cc79b0365833c1406a4a4a9cdfab2950f33c8366d81be927edbf`.
Compilation took 114.33 seconds under the 12 GiB guard, with sampled aggregate
RSS 7,423,426,560 bytes; compiler and guard exited zero.

One functional first/reopened pair has the same title, 33 directory rows,
**zero commit links**, console diagnostics and five module errors on both visits.
All five errors are `ReferenceError: 'WeakMap' is not defined`, in the original
polyfill and React bundles. The first visit compiled 119 executables; the second
reused all 119, reused 51 parsed sources, had zero cache/parser misses and invoked
no compiler. Neither VM initialized JSC. Binary and fixture hashes remain stable.
Process/guard exits are zero; sampled aggregate RSS is 2,902,016,000 bytes.

This harness has no window, CSS layout or paint. Its one pair supplies no timing,
rendering or successful-hydration acceptance. Local raw commands, pins, host
readings, logs and results are in
`docs/performance/libjs-github-classes-20261115/`. Earlier collection/style probes
are retained separately; their temporary executables disappeared before final
identity capture, so they receive no pinned-build or performance credit here.

## Native browser observations

Fresh processes use private profiles, original-origin offline HTTPS replay,
the test display, a 1024×768 document viewport and a 30-second observation timer.
The same PID registries are supplied to the memory guard and launch controller;
PID adoption succeeded. The sampled budget remains 3,221,225,472 bytes (3 GiB).

| Attempt | Build / PID | Result | Sampled aggregate RSS |
| --- | --- | --- | ---: |
| LibJS, unprofiled | `85fc5781…`, 83830 | Guard terminates before audit/PNG; controller 137, guard 125. | 4,074,831,872 |
| LibJS, separate stack diagnostic | `3bbd530b…`, 88986 | Guard terminates before audit/PNG or completed stack sample; controller 137, guard 125. | 3,589,029,888 |
| JSC control, unprofiled | `3bbd530b…`, 90023 | Complete native document: 33 rows, 56 commit links, latest commit and README; no script diagnostics; browser/controller/guard zero. | 2,505,080,832 |

The full executable identities are
`85fc578181ef2fdc0ec6e614797219095d6558d9fea66036241668b96de7557f` and
`3bbd530be52f4115c39e0b98709de61f7b653ef953291eb86565d03b7828ad82`.
The latter contains the base-class code; the former predates it. Both are shared
single-unit C `-prod` production bundles. The LibJS runs do not establish browser
terminal status after controller termination. No failed attempt was discarded.
The first controller attempt, under system Python 3.9, failed before launching
a browser because `hashlib.file_digest` is unavailable; Python 3.11 supplied
the subsequent attempts. The first LibJS observation overlapped the broad
GC-disabled suite; the later LibJS diagnostic and JSC control did not.

The successful JSC control uses the default engine and supplies no LibJS credit.
Its PNG is a whole-window diagnostic, not a document-only pixel comparison.
There is no new LibJS PNG to compare with Brave. The missing runtime behavior
and the native LibJS memory failure both remain required work.

## Verification checkpoint

The complete package passes **283/283 files with default GC** and **283/283 with
GC disabled**. The unchanged canonical AST driver passes **100/100 exact upstream
fixtures**. All 721 recorded LibJS/Unicode source/fixture/compiler inputs remain
unchanged across the final sweeps and AST check. Checks use current V, the C
backend, `-memory-limit 10G` and memory guards; no compatibility-compiler result
is claimed. The pin set includes the shared checkout's in-progress module-audit
slice; this is a tested worktree checkpoint, not a clean commit-only receipt.
Both broad guard/process exits are zero; sampled peaks are
6,276,988,928 and 6,193,430,528 bytes respectively under the 12 GiB budget.

The initial broad sweep is retained: 280 passed and three failed. `779068b32`
corrects the old IteratorStep test, which incorrectly required a value getter;
IteratorStepValue still checks and preserves that getter's exception.
`bcccde804` separates UTC/ISO round trips from native GMT offset precision. A
pinned Node 26.13.0 control also parses the 1900 Moscow GMT+0230 string 17 seconds
later than the original instant. The in-progress module-audit test was corrected
to compare observation generations after linking and to link before evaluation.
Those corrections precede the two complete passing sweeps.

Local receipts are in `docs/performance/libjs-classes-checkpoint-20261115/`;
native observations are retained under
`~/Library/Caches/Vox/benchmarks/libjs-runtime-20261115/`. These checks do not
reset the browser's unresolved memory, hydration or pixel-conformance gates.
