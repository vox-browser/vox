# GitHub rendering investigation

Measured on macOS on 2026-10-13 and 2026-10-14 with `https://github.com/vlang/v` and the
repository's native browser. These are individual diagnostic runs, not an
upstream parity benchmark.

## CPU instruction measurements

Retired CPU instructions are now the primary work metric for subsequent
optimization. The older wall-clock observations below remain historical
diagnostics. `VOX_PROFILE_INSTRUCTIONS=1` enables native cumulative checkpoints
and exact process-counter intervals for installation and first frame submission.
It works with the normal signed GC build; neither V's function profiler nor the
allocation wrapper is enabled for these measurements.

The counter is `proc_pid_rusage(..., RUSAGE_INFO_V4, ...)::ri_instructions`.
Apple's [Recount documentation](https://github.com/apple-oss-distributions/xnu/blob/main/doc/observability/recount.md)
describes retired instruction accounting for tasks across their threads,
including kernel execution charged to them. GPU execution and external
services such as WindowServer are excluded. These are hardware counts, not
estimates from elapsed time or V function-call counts. This Mac exposes them
without elevated permissions; unsupported systems report unavailable counters.

Measured on arm64 Darwin 25.5.0, 2026-10-14, at a 1024×768 document viewport:

| Interval | Run 1 instructions | Run 2 instructions | Run 3 instructions | Median instructions |
| --- | ---: | ---: | ---: | ---: |
| Vox: document installation | 55,489,577,542 | 55,318,675,420 | 54,252,275,306 | 55,318,675,420 |
| Vox: installation through first native frame | 59,086,726,044 | 58,890,426,942 | 57,818,863,748 | 58,890,426,942 |
| Vox: navigation through first native frame | 60,461,541,528 | 60,265,796,423 | 59,237,360,447 | 60,265,796,423 |
| Vox: process start through exit after capture | 86,304,129,954 | 65,191,818,531 | 69,574,762,502 | 69,574,762,502 |
| Chrome: navigation through completed-document capture, observed descendants | 11,901,119,888 | 12,506,518,885 | 12,908,501,390 | 12,506,518,885 |
| Chrome: process start through completed-document capture, observed descendants | 18,749,106,807 | 18,953,252,883 | 19,193,385,077 | 18,953,252,883 |

Vox's final process counts were read while it was a zombie, before `wait()`
reaped it, and include capture and shutdown. All three runs observed one browser
process and obtained its final exit sample. The first-frame intervals end at
native frame submission and exclude subsequent capture-related work. The much
wider full-process range reflects additional work after first paint; use the
navigation/installation intervals when judging changes to initial rendering.

Chrome 155.0.8059.80 used a fresh isolated profile for each run. The tool observed
12 processes per run, including helpers, and waited for `readyState=complete`,
font readiness and populated GitHub file links before capture. All runs exposed
72 file/directory links. Child processes that disappeared before a final sample
retain their last observed count: respectively 3, 3 and 2 such processes in
these runs, with no permission failures. Short-lived children can also fall
between samples. Chrome's totals are therefore **observed-descendant lower
bounds**, explicitly marked in JSON, rather than exact complete browser totals.
Counting just Chrome's main PID would exclude its renderers and other helpers.

The endpoints and functionality differ. Vox loads cached HTML/resources and
still displays file-row placeholders because its module backend is incomplete;
Chrome navigates the live URL and renders populated rows. Native submission is
not web FCP. These counts establish remaining CPU work, not a controlled speed
ratio or Chrome parity. Instruction counts reduce scheduling/frequency noise
but still change with executed work, GC scheduling, background activity, and
network-dependent content.

The largest checkpoint intervals during Vox installation were:

| Checkpoint interval, summed across both initial layout passes where applicable | Median instructions |
| --- | ---: |
| Formatting contexts and preliminary layout attachment | 15,591,571,027 |
| External stylesheet installation | 14,487,559,899 |
| Box construction and intervening style updates | 13,039,227,394 |
| Script startup | 2,964,339,594 |
| Initial retained paint commands | 2,694,847,852 |

These are **adjacent cumulative checkpoint deltas** in log order. A checkpoint
can include preparatory work since the previous marker and other process
threads; it is not the self cost of the function named in the label. The
separate `install_total` and first-frame scopes overlap those deltas and must
not be added to them. Stylesheet installation, style/box construction and
formatting remain the primary targets for further instruction reduction.

The earlier saved `Build/v/Vox-gc-baseline` binary consumed 112,372,918,564
instructions through exit after capture in one run. It predates several
optimization rounds, lacks native scope counters, and is only a diagnostic
reference; this is not an isolated measurement of the counter instrumentation.

Raw logs, counts and captures are under
`Build/instructions/{vox,chrome}-github-counts.run-{1,2,3}.{json,log,png}`.
The measured Vox executable SHA-256 is
`7a29a1f9ab2985566d488b2a3bd8c75db99e362ef38123a3c617ddc14880bdab`;
Chrome's is `4dbcffd1126e00453193bc5cc6bf096f37a53fda8567516b22ec576c55e2df4e`.
The tool records each binary hash, kernel, input, viewport, per-process coverage,
phase deltas and native scopes. It captures only the document viewport in new
Vox runs, preserving a separate raw window PNG; the original measurement images
predate that crop and include the 112px browser chrome.

Reproduce with:

```sh
sh build-prod-browser.sh
python3 tools/measure_browser_instructions.py --engine vox --repeat 3 \
  --output Build/instructions/vox-github-counts
python3 tools/measure_browser_instructions.py --engine chrome --repeat 3 \
  --output Build/instructions/chrome-github-counts
```

Use `--binary PATH` for another executable, `--url URL_OR_LOCAL_FILE` for another
input, and `--scratch-dir PATH` to place Chrome's disposable profiles elsewhere.
This investigation's Chrome app is on `/Volumes/LoomScratch/vox2-github-performance/Google Chrome.app`;
the default command uses `/Applications/Google Chrome.app`. Chrome's interval
ends before observer-side PNG writing and browser shutdown. Vox's viewport crop
runs after its exit sample. The watchdog uses elapsed time only to terminate a
stalled run; the reported metric is instructions. No personal Chrome profile is
used.

Validation: the counter module's two V cases, eight Python accounting/ABI/native
counter cases, the signed production build and native `--headless-smoke` pass.
The Python tests exercise live counters and zombie exit counters as well as
descendant retention, PID reuse, missing final samples and overlapping scopes.
Native smoke also passes with instruction checkpoints enabled. The counter and
browser instrumentation are opt-in; the normal GC/arena allocation policy is
unchanged.

## Causes and changes

- The V 0.5.2 compatibility compiler's `-prod` Boehm code repeatedly snapshots
  nested pointers in live aggregates. Tokenization walks the growing token
  array around calls, turning large stylesheet parsing into quadratic work.
  The browser builder uses C `-O2` without `-prod`. The initial fix used
  `boehm_full`; optimized retention checks subsequently allowed pointer-aware
  `boehm`, which leaves pointer-free buffers atomic.
- Block layout measured automatic-height flex subtrees before running their
  actual flex layout. Ordinary horizontal flex containers now resolve their
  own height during that run. Buttons, vertical writing modes, and percentage
  row gaps retain their required preliminary measurement.
- Intrinsic and minimum-height probes allocated individual geometry records
  that survived until collection. These scalar-returning probes now allocate
  `UsedValues` in stable arena chunks and release their owned records and page
  containers when the probe ends. Shared line boxes and rare data keep their
  existing heap ownership; committed layout does not use this temporary arena.
- Recomputed unchanged styles rebuilt font cascades containing pending faces.
  Upstream's pending-cascade equality intentionally returns false, so each
  recomputation invalidated layout. Vox now preserves cascade identity when
  all font inputs, the owning font computer, and its environment generation
  match. Font loading and changes to font properties still invalidate it.
- Document script execution parsed entire ECMAScript modules before rejecting
  their unsupported execution. Execution now checks that capability before
  parsing. The explicit `prepare_script()` API still parses module ASTs and
  reports syntax errors.
- Native navigation constructs an active document without session-history
  traversal. It now grants script readiness before parsing, allowing GitHub's
  import map to run without the script-readiness assertion.
- Column flex layout now retains its first inside-layout when flexing leaves
  both dimensions unchanged and no descendant consumes the new definite-height
  basis. Grids with only implicit automatic rows can use the same optimization;
  explicit, percentage, flexible, and subgrid rows retain the relayout guard.
- Immutable platform font handles retain their resolved file and decoded face.
  Glyph coverage and bounds no longer repeat file checks and global cache-key
  construction for every character. An unavailable explicit source continues
  to be retried instead of permanently selecting its temporary fallback.
- CSS component text serialization now uses linear builders. Unescaped
  identifier tokens borrow their contiguous filtered-input span; escaped names
  still use the decoder and builder. Optimized forced-GC tests cover a late
  identifier retained after the tokenizer and other tokens have gone away.
- The compact script bridge reads `innerHTML` and `textContent` lazily from
  captured native element identities. Initial state and unchanged snapshots
  no longer serialize every ancestor's complete subtree. Pending script writes
  and CSSOM rule mutations preserve their existing replay behavior.

## Historical wall-clock observations

The native timing log separates processing phases from network fetches and
the screenshot settle delay.

| Phase | Earlier run | Updated run |
| --- | ---: | ---: |
| External stylesheet installation | 78.2 s | 2.0 s |
| Document script startup | 8.2 s | 2.0 s |
| Geometry per initial stabilization pass | about 6–7 s | about 3–4 s |

The updated cached-document install took 14.5 seconds. A subsequent network
refresh returned different HTML and caused another document install lasting
20.6 seconds; the screenshot process exited after 40.7 seconds including both
installs and capture. These values must not be described as a single first
paint time. The repeated geometry passes triggered by unchanged pending-font
styles no longer occur after installation.

GitHub's file rows still show loading placeholders because this browser
JavaScript backend does not implement module execution/linking. Avoiding their
unnecessary parsing does not add module support or full LibJS parity. Equal
rendering speed and functionality with upstream Ladybird have not been
established.

### Chrome comparison and continued optimization

A subsequent native run at a 1024×768 document viewport reduced cached-document
installation from 16.2 seconds to 5.1 seconds after the column-flex, font-handle,
linear serialization, and lazy-content changes. Its script startup took 138 ms
instead of 2209 ms, and its two geometry passes took 1047 ms and 790 ms instead
of 4509 ms and 4083 ms. The process used a peak RSS of about 1.5 GiB.

The final build also includes the grid dependency refinement and identifier
source spans. Its two subsequent document-install measurements were 7.9 and
8.8 seconds. At that point the host load average was about 100 with many
unrelated compiler processes running. The differing phase timings do not
establish a regression or an additional speedup; repeat them on an idle host
before drawing either conclusion.

An isolated, clean-profile Chrome 155.0.8059.40 process loading the live URL
reported first contentful paint at 1516 ms, DOMContentLoaded at 1827 ms, and load
at 2722 ms through the Chrome DevTools Protocol. Its screenshot showed populated
file rows and 72 file/directory links. The Chrome measurement includes a cold
network navigation; the Vox measurements use cached HTML/resources and native
window capture. They are different workloads, and Vox has not reached Chrome
load-speed or functionality parity.

## Allocation policy

Upstream Ladybird uses its tracing `LibGC` collector for DOM and JavaScript
objects alongside reference counting and layout arenas. Vox retains Boehm GC
for live and shared V object graphs. Its scoped measurement arena is an
ownership optimization, not a switch to a globally uncollected heap.
`LADYBIRD_V_GC=boehm_full` retains the fully scanned diagnostic mode, and
`LADYBIRD_V_GC=none` remains available for ownership diagnostics.

The compatibility compiler forces GC off when `-prealloc` is used, including
when an explicit `-gc` argument is present. Its thread-local and scoped bump
arenas cannot be enabled for selected packages through that flag. The native
browser therefore uses scoped ownership where the lifetime is proven: CSS
tokenizer code points and byte offsets now share one pointer-free allocation
freed after tokenization, while intrinsic geometry retains its chunk arena.
The tokenizer retention and arena tests also pass with `-prealloc`. Enabling
that flag globally still requires ownership for document graphs, shared caches,
and updates that outlive a particular frame.

## V profiling and allocation follow-up

The investigation used V's `-profile`, with inline functions excluded, around
native layout entry points. The diagnostic recorded three layout calls before
an ongoing background refresh was interrupted; its totals are not one isolated
navigation. It recorded about 38.8 million `_v_malloc` calls, 14.7 million
computed-property reads, 1.28 million length-context constructions, and
6.4 million layout ancestry checks. Instrumentation and V's non-thread-safe
profiler make these diagnostic counts more useful than their absolute timings.

A separate sampled GC allocation wrapper confirmed the generated-C causes:
optional map misses constructed error objects; selector matching allocated an
attribute-name array and a captured metadata closure; DOM value equality copied
whole heap node records; and default length wrappers constructed unused
`CalculatedStyleValue` objects, maps, and arrays. Even absent optional values
could retain those unused objects in their payloads.

The follow-up changes are:

- Guard missing animated-property and pseudo-element entries before lookup.
- Use pointer identity in selector matching and a borrowed metadata helper;
  compare case-insensitive attribute names without rebuilding a list.
- Use zero-length defaults, explicit absent optionals, and direct conversion
  returns instead of building discarded calculation objects.
- Retain font length metrics on the owning style, borrow that style through
  layout aliases, and reuse native font handles on retained layout nodes.
- Visit shared external containing-block chains once per intrinsic probe.
- Retain the installed document selector-query state. Repeated font/style
  lookups previously rebuilt it and cleared its parsed-selector cache.
- Resolve absolute and percentage layout lengths before creating a font or
  container-query context; relative and calculated lengths retain that context.

Before the selector/default/font-handle changes, the allocation wrapper counted
81.3 million managed allocation calls requesting 8.1 GB through native capture.
After those changes it counted 50.4 million calls requesting 5.5 GB. These are
cumulative requested bytes, not live memory or RSS, and exclude JavaScriptCore
and other native allocations. These two runs installed the cached document in
5.1 and 5.9 seconds with different host contention, so the allocation reduction
does not establish a corresponding timing ratio. The later query-hook and
context-free length changes are additional to those allocation measurements.

The final signed production build, with profiling disabled and all follow-up
changes included, installed the cached GitHub document in 5413 ms and 5549 ms.
An adjacent run of the saved earlier binary took 8086 ms. The final two geometry
passes took 855/794 ms and 903/747 ms, versus 1403/1373 ms in that earlier run.
The final peak RSS was about 1.4 GiB. The full screenshot processes took 6.8 and
7.3 seconds, including startup and capture; these must not be called FCP.
The normal collector log accounted for about 5.5 GB between 59 collections,
versus about 9.0 GB between 79 collections in the initial allocation diagnostic.
Those interval totals include padding and omit the final allocation interval.

Host load ranged from roughly 30 to 90 during final compilation and measurement.
These individual runs show a remaining gap to the earlier 1.5-second Chrome FCP
measurement; they do not establish Chrome parity. GitHub module execution and
its hydrated file rows remain unsupported by the compact browser backend.

## Retained parser input and SVG geometry follow-up

The next allocation-stack diagnostic found repeated copies of parser input,
three parses of each validated selector, full native-element registry snapshots
for individual bindings, and complete computed-style materialization while
building SVG models. It also found document-root checks invoking value equality,
which copied two 640-byte DOM node records for each unsuccessful check.

The follow-up retains immutable component/token spans across parser transactions,
supplies EOF without appending a sentinel, and validates a single selector graph.
CSS keyword comparisons fold only ASCII bytes without allocating lowercase
strings. Containing-block recomputation indexes inline nodes once, preserving
continuation order and ignoring stale DOM handles from an earlier layout tree.
Native bindings resolve one registry key while preserving provider precedence
and live replacements. SVG models read their filter properties directly, and
path boxes retain immutable parsed geometry keyed by the applied CSS `d` value.
Document-root checks now compare pointer identity.

The allocation wrapper counted 47,305,300 managed allocation calls requesting
4,527,048,497 bytes before the registry/selector/SVG changes and 35,244,219 calls
requesting 4,073,835,695 bytes afterward: about 25.5% fewer calls and 10.0% fewer
requested bytes. These process totals include capture-related frames and exclude
native/JSC allocation. The latter measurement precedes the document-root change.
Their instrumented document-install times were 4819 ms and 2942 ms; host load
changed between runs, so those times do not establish a controlled speedup ratio.

The final signed, uninstrumented GC build installed the cached document in
4550 ms and 4148 ms. Installation through first native frame submission took
4930 ms and 4341 ms; navigation through that submission took 5290 ms and 4574 ms.
Peak RSS was 1286.5 MB and 1349.3 MB. The timing output now reports these complete
intervals, and `first_paint_total` includes the complete frame rather than just
the final segment after document replay. Native submission is not web FCP.

A fresh isolated Chrome 155.0.8059.80 run reported FCP at 2436 ms, DOMContentLoaded
at 1331 ms, and load at 1468 ms. Its screenshot showed populated rows and 72
file/directory links. Vox's cached screenshot still shows loading placeholders;
its module backend remains incomplete. The inputs also differ between cached
Vox HTML/resources and Chrome's cold network navigation. Chrome speed and
functionality parity have not been achieved.

GC remains enabled. A lower heap-divisor probe timed out before startup timing
was emitted and provides no valid navigation measurement; it did not change
the default collector policy. Compiler scratch files were moved to a scratch
volume after disk exhaustion interrupted builds. Those interrupted compilations
are not test-body failures. Retried parser and SVG suites passed, including
forced collection, and borrowed parser input also passed with `-prealloc`.
The final native startup/signature checks and six screenshot comparisons pass;
ordered lists, SVG image replacement, and both turbulence cases are pixel-exact.

## Validation and reproduction

Focused tests cover forced-GC token retention, arena pointer stability and
release with both `boehm_full` and `none`, flex sizing, pending-font cache
invalidation, import-map navigation, and module rejection followed by classic
script execution. The signed native bundle passes `--headless-smoke`.
The continued optimization tests also cover stylesheet-graph retention with
optimized pointer-aware GC, UTF-8 arena offsets, live font/context changes,
selector case sensitivity and metadata, animation/transition precedence,
pseudo-element identity, retained query hooks, and context-free layout lengths.
They also cover column/grid percentage bases,
changed flex heights, font-file retention and late availability, large CSS
component serialization, and lazy DOM reads with pending writes and inserted
nodes. Final native comparisons pass for `inline-node`, `ordered-list`,
`text-decorations`, and `svg-image-source-switch-same-size`; the ordered list
and SVG source-switch comparisons are pixel-exact. The earlier lazy-content
build also passes `selection-focus-between-text-controls` exactly.

```sh
sh build-prod-browser.sh
LADYBIRD_DEBUG_TIMING=1 Build/v/Vox.app/Contents/MacOS/Vox https://github.com/vlang/v
```

Use `sample PID 2 5 -file OUTPUT.txt` during a slow phase to inspect the native
stack. Account for cached-page installation and background refresh separately;
a blank upstream headless screenshot is not a valid speed comparison.

Build an instrumented native browser with V's profiler, then restore the normal
build before measuring speed:

```sh
LADYBIRD_V_PROFILE="$PWD/Build/v/github.vprof.txt" sh build-prod-browser.sh
LADYBIRD_SCREENSHOT_DELAY_SECONDS=0 Build/v/Vox.app/Contents/MacOS/Vox \
  --screenshot "$PWD/Build/v/github.profile.png" https://github.com/vlang/v
sort -k3,3nr Build/v/github.vprof.txt | head -n 30
sh build-prod-browser.sh
```

The current profiler emits calls, inclusive milliseconds, exclusive
milliseconds, average nanoseconds, and the C function name.
`LADYBIRD_V_PROFILE_FNS` overrides the default navigation/layout entry points.
The build supplies the macOS stdio compatibility flags required by this
compiler's profiling output.
