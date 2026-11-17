# Experimental reuse of matching generated LibJS code

`4d06a27db` adds an opt-in native-cache identity based on the exact generated C
for each executable. On the real Hacker News comment workload, changing the
script URL or appending a comment retains **26 cache hits, zero misses, zero
compiler invocations and 747 native entries**. The existing source-bound mode
misses all 27 executables in those controls. This is functional reuse evidence;
no new browser-speed or live GitHub acceptance is claimed.

The default remains source/file/URL identity. Enable the experiment with
`NativeCodeCacheOptions{ generated_code_identity: true }` through
`enable_native_code_cache_with_options`, or
`VOX_LIBJS_NATIVE_GENERATED_CODE_CACHE=1` in the browser. Modes have separate ABI
partitions. `NativeCacheStats.identity_kind` reports `source` or `generated-code`.
The diagnostic's `--generated-code-cache` option requires the latter in both
capture and shutdown receipts; `--require-native-reuse --native-diagnostics`
additionally requires actual cached native execution and a clean cache.

The new key hashes the complete C emitted for a single entry named
`vox_native_0`, including helper definitions, operand slots and property plans,
alongside the current native ABI. A persisted record still names the original
batch symbol and verified library digest. Entry symbol numbering is the only
normalization. Changed generated C produces a different key.

Constants, lexical environments, exception tables and source metadata remain in
the current executable/realm. Generated code reads current values and invokes
the current VM's slow callback. Parsing and bytecode generation still occur.
Temporary C builders and hash input are reclaimed per lookup under preallocation;
the short returned digest outlives that workspace. Ordinary library hash,
metadata and symbol validation remain in the existing loader.

`f32a3c1d9` adds `tools/libjs_generated_code_hn.v`, a manual diagnostic using the
browser's actual `Runtime.install_libjs_document` bridge, original archived
`hn.js`, the complete 101-comment discussion, and two DOM click-driven
collapse/expand cycles. It verifies real collapse, cancelled navigation and
restoration of every row's classes in a fresh process/VM. It has no window,
layout or paint. Optional external script input makes source-change controls
explicit. Reopens use `/usr/bin/false`; a failed reuse check exits one after
reporting the content and native-cache results.

The sealed current-V, single-C-unit `-prod -prealloc -gc none` diagnostic build
consumes **2,863 V sources and zero test sources**. Its guarded build exits zero
in 241.712257917 seconds, sampled peak 7,292,338,176 bytes under the unchanged
12-GiB limit. Executable SHA-256:
`bf461fd6594882e06a60ba1afa4d284de8ad7ea43815db315672ccde19f5968c`.
The receipt pins the consumed dirty-checkout source buffers and native inputs;
all four implementation/tool hashes still match the checkout after the runs.

The resulting source-mode ABI is
`c880f030e81d9af7d39eca8fb7ba95ec1c5fd57ede5910ed48bafc412e4abf71`;
the generated-code ABI is
`5df3dbb4e79a0ba0f90d787e8c3a4491c27ee18272126eefe5d7b4683a9424c4`.
Both partitions are generated normally, without copying or renaming older data.
Each manual process runs under its own 3-GiB guard.

| Manual case | Hits / misses | Native entries | Diagnostic/guard exit |
| --- | ---: | ---: | ---: |
| Source mode, same source and URL | 27 / 0 | 747 | 0 |
| Source mode, URL changed | 0 / 27 | 0 | 1, expected |
| Source mode, appended comment | 0 / 27 | 0 | 1, expected |
| Generated-code mode, same source and URL | 26 / 0 | 747 | 0 |
| Generated-code mode, URL changed | 26 / 0 | 747 | 0 |
| Generated-code mode, URL plus comment changed | 26 / 0 | 747 | 0 |
| Generated-code mode, fresh repeat at another URL | 26 / 0 | 747 | 0 |
| Generated-code mode, an operation appended | 25 / 1 | 746 | 1, expected |

Both cold seeds pass. Source mode compiles 27 executables in three compiler
invocations; the new mode compiles 26 in three invocations, coalescing one
identical generated body. All successful reopens have zero new compilation,
pending/invalid entries and errors. All cases retain the complete 101 comments
and correct toggling, with no author errors or initialized JavaScriptCore context.
The changed-code control appends an assignment/addition, correctly leaves one
body pending and reports the disabled compiler's failure. Cached files remain
unchanged across that control. Original fixtures are never edited; derived
script bytes and hashes are retained separately.

The first available shared production bundle predates the
feature: executable
`dddbc5943fe4d7b8cf82ff35f3a10ccdeeaa74c39aa3a90be2533064d0b2c191`.
A fresh windowed HN capture succeeds, with ordinary native preparation and no
compiler error, but it does not report the requested new identity kind. The
diagnostic correctly rejects it: browser zero, diagnostic/guard one, unchanged
inputs and successful PID adoption. This old bundle supplies a negative
selection check, not candidate validation. No manual production build is queued;
feature/tool commits request the normal coalesced rebuild.

A newer completed shared production bundle validates the candidate without an
additional build. Its executable SHA-256 is
`61a7b90fc08b0bdc1ee9e4de0747f7c0d2c37502b058cfbb9f1a5f48ac92ecc4`.
The single-C-unit, literal V `-prod` receipt is
`Build/production-build/receipts/20261117-195151-c16c5606/frozen-compile.json`.
Its checkout is dirty and recorded head predates the feature commits; its exact
consumed-source manifest matches all three implementation files. The cohort
checks those hashes before launch and holds the canonical bundle publication
lease throughout. The full sealed receipt remains in the local evidence.

The windowed comparison uses the original archived 30-story HN homepage, all
resources replayed at `http://127.0.0.1:52840/`, and the unchanged Brave reference
SHA-256 `e19c2f094456366ca3ddcaac9032f4696c98b17c8705bdf6f875fb6bc95b15fb`.
The archive manifest SHA-256 is
`e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0`.
Each capture uses a fresh process/profile/HTTP cache, enabled author scripts,
1024×768 document viewport, scale two and a two-second settle on the test
display. The frontend cache is cold per process; OS filesystem/shader caches
are retained. All eight proxy variables are removed. Both modes retain their
own native libraries and use the same browser executable and counter backend.

Each untimed cold seed compiles six executables with one ordinary Clang call.
Separate instrumented reopens with `/usr/bin/false` each record six hits, six
native entries, 40 fast steps and 107 slow steps, with zero misses, new
compilation, pending/invalid entries or errors. The source-mode native ABI is
`2cfa7781e370c5cb6ffaf26fe423cc9a7c32316858397367ac50235b03cc9d7a`;
the generated-code ABI is
`feb6c79b232473738a30fb26a06b8443dae8ee6e794be55fdb5bc927c4afabd3`.
The source/generated native-library SHA-256 values are respectively
`bd34689a92941a187f2ae59c6f695036d937ee7cf50a21ed08d30ca30fc27a84` and
`5eec4778cf04e76ba29e75933dae22b1374942b9bad618b41f0234022e16b289`.
All captures preserve complete content, exact original-reference pixels and
an uninitialized JavaScriptCore context, with no author/native page errors.

Seven measured pairs alternate source/generated and generated/source order.
Native-entry diagnostics are disabled in both measured modes, and their
optional counters are absent. Every measured reopen has six hits, zero misses
or compiler invocations and unchanged executable/library/resource hashes.

| Pair | Source identity instructions | Generated-code identity instructions |
| --- | ---: | ---: |
| 1 | 3,553,168,670 | 3,564,593,584 |
| 2 | 3,552,975,366 | 3,567,243,126 |
| 3 | 3,565,681,764 | 3,554,789,933 |
| 4 | 3,536,514,332 | 3,533,305,050 |
| 5 | 3,535,633,148 | 3,527,859,662 |
| 6 | 3,536,702,893 | 3,538,744,294 |
| 7 | 3,528,851,709 | 3,532,893,288 |

The medians are **3,536,702,893** and **3,538,744,294** instructions: generated
identity uses **0.0577% more** by the ratio of medians. The median paired ratio
and ratio of medians both equal **1.0005772045494803**; the conservative
highest-generated/lowest-source ratio is **1.010879294503106**. Four pairs use
more instructions with generated identity and three use fewer. This establishes
no speed gain and does not isolate the cause of the small difference.

The measurement starts at exclusive browser resource-coalition creation and
ends immediately after native document PNG encoding. It includes startup,
window setup, navigation and capture; file writing, subsequent content audit
and teardown are outside the endpoint. Cumulative hardware instruction counts
include exited coalition tasks and explicitly allowed owned services. GPU
execution, outside-coalition services, replay and observer work are excluded.
Stable live ownership and endpoint task totals pass; individual exited task
identities are not reconstructed. This compares cached native modes, not Brave
CPU performance, isolated JS execution, rendering time or scrolling.

The controller/guard and all 18 browsers exit zero, with successful PID adoption
and ownership audits. The unchanged 12-GiB guard records 61.121107791 seconds
and sampled aggregate peak 473,432,064 bytes. The host has 18 logical CPUs;
measured-trial one-minute loads range from 18.35888671875 to 22.19091796875.
That contention prevents treating wall-clock intervals as speed evidence.
The source/generated cold seeds record 4,889,575,214 / 4,800,658,192 instructions;
instrumented eligibility reopens record 3,562,724,987 / 3,564,109,503. These four
diagnostic captures are retained outside the seven-pair statistics.

The command clears the proxy variables and runs the local `browser.py` through
`sh tools/run_v_tool.sh run_memory_bounded`, using
`Build/libjs-generated-cache-browser-5204.lock`, report
`Build/libjs-generated-cache-browser-5204-guard.json`, shared adoption registry
`Build/libjs-generated-cache-browser-5204-pids.json`, and a 300-second watchdog.
It runs only the completed cohort above; there are no omitted browser attempts.

Five focused V regression cases cover current constants/closures/errors,
changed fast instructions/slots, corrupt records, default-mode preservation and
workspace lifetime. The diagnostic source-selection regression is extended too.
They remain uncompiled/unrun under the continuing automated-test hold. Other
GC modes, the compatibility compiler and broad suites have not been exercised
for this feature. Generating and hashing C adds lookup work; the new mode stays
opt-in with no measured instruction saving and broader correctness evidence
still pending. Full live GitHub cache validation remains open. The prior
[HN startup result](LIBJS_HN_NATIVE_BROWSER_20261117.md) is unchanged.

Exact commands, source/binary/library pins, logs, expected negative controls and
guard receipts remain local under
`docs/performance/libjs-generated-cache-20261117-5204/`. Completed Build receipts
move with idle-lock, SHA-256 and symlink verification to
`docs/performance/libjs-github-browser-20261116/scratch-receipts/continued-20261117-r42/`:
26 roots/38 files, exit zero in 0.180099958 seconds, sampled peak 393,216 bytes.
The completed browser cohort moves to the adjacent
`continued-20261117-r43/`: four roots/150 files, exit zero in 0.173985417
seconds, sampled peak 770,048 bytes. Exact counts, browser PID/start identities,
ownership receipts and PNGs remain there; library hashes also remain in
`browser-audit.json`. A convenient final native-cache capture is local at
`docs/performance/libjs-generated-cache-20261117-5204/hacker-news-generated-code.png`.
Disposable profiles, Build outputs and idle locks are removed. No renderer or
pixel reference changes are made.
