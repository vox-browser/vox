# Hacker News browser startup with cached native LibJS, 17 November 2026

Cached native code does **not reduce startup CPU work** in this homepage
experiment. Seven matched pairs give medians of **3,535,614,581 instructions
with the interpreter** and **3,548,528,899 with native reuse**, a **0.3653%
increase** by the ratio of medians. Six pairs use more instructions with native
reuse; one uses fewer. This result supplies no optimization credit.

This compares two LibJS modes in the same production Vox executable. It does
not compare CPU performance with Brave or measure isolated JavaScript speed,
rendering time, scrolling, or comment-collapse callbacks. The unmodified archived
homepage executes only six cached native entries in the eligibility diagnostic.

The interval starts at exclusive browser resource-coalition creation and ends
at `capture_document_encoded`, immediately after native document PNG encoding.
It includes process/window startup and navigation. PNG file writing, subsequent
semantic audit and teardown follow the endpoint. Cumulative hardware-retired
instruction counts include exited coalition tasks and explicitly allowed owned
Metal compiler/CascadeSets services. GPU execution, outside-coalition services,
the replay server and the observer are excluded. Stable live ownership and
endpoint task totals pass for every capture; individual exited task identities
are not reconstructed. Both modes use this same backend and ownership policy.

Each trial launches a fresh process, realm, profile and HTTP cache, with enabled
author scripts, a 1024×768 document viewport, capture scale two and a two-second
settle. The sealed original homepage/resources are served at the same loopback
URL throughout the completed cohort, `http://127.0.0.1:49853/`, with
`Cache-Control: no-store`. All 30 story IDs must match. Both modes enable the
frontend cache, which starts cold in each process. Only the native candidate
retains executable libraries. Ambient proxies, including `NO_PROXY`/`no_proxy`,
are removed. OS filesystem and shader caches are retained. Window placement
uses the test display away from the pointer.

The browser is the existing shared single-C-unit, literal V `-prod` build:

- Executable SHA-256:
  `d166b53e27274390a698704536cd3984a15b1094579e0c0f9fb126616565b56c`.
- Sealed build receipt:
  `Build/production-build/receipts/20261117-173658-4f20c82c/frozen-compile.json`.
  Its source checkout is dirty; the receipt records the consumed inputs.
- Native ABI:
  `b32c6cda1d21c6618167f155e29fa1f51192c6c09c86208025bcc3c250b24e45`.
- Generated native-library SHA-256:
  `d8cdbc32c6a533c89d79e3052b2fd29bc08c41ba5d3433eb0bae588ae86f0ba5`.
- Homepage manifest SHA-256:
  `e1425162ca7c3373275914a5e7373f4a6a240ae4ce05d3160cf7039371c63ce0`.
- Original, unchanged Brave pixel reference SHA-256:
  `e19c2f094456366ca3ddcaac9032f4696c98b17c8705bdf6f875fb6bc95b15fb`.

A separate untimed seed compiles six executables with one ordinary Clang
invocation, reporting 101.627667 ms compilation and 169.626417 ms loading.
The instrumented eligibility reopen has six cache hits, six native entries,
40 fast steps and 107 slow steps. It uses `/usr/bin/false`, with zero misses,
compiler invocations, new compilation, pending/invalid entries and errors.
Page JavaScriptCore stays uninitialized. This establishes execution of cached
native code rather than inferring it from an engine selector.

Native-entry diagnostics are disabled in every measured trial. Their optional
counters are therefore absent in both timed modes, as specified by
`libjs/native_code_activity.v`. The same hardware instruction markers remain
enabled in both modes; no V `-profile` build is used. Every timed native visit
has six hits, zero misses, no compiler invocation or error and unchanged native
library hashes. Interpreter visits explicitly disable the native cache. Both
modes execute LibJS with no initialized JavaScriptCore context or author/native
page errors. All captures match the original reference with zero tolerance.

| Pair | Interpreter instructions | Cached native instructions |
| --- | ---: | ---: |
| 1 | 3,531,905,044 | 3,558,437,591 |
| 2 | 3,535,614,581 | 3,549,321,088 |
| 3 | 3,541,960,757 | 3,547,555,930 |
| 4 | 3,539,429,173 | 3,548,528,899 |
| 5 | 3,534,760,197 | 3,548,211,896 |
| 6 | 3,535,499,285 | 3,550,189,209 |
| 7 | 3,551,345,689 | 3,547,803,091 |

Pair order alternates interpreter/native and native/interpreter. The median
paired native/interpreter ratio is **1.0038055478307741**; the ratio of medians
is **1.0036526373857038**. The conservative highest-native/lowest-interpreter
ratio is **1.00751224811241**. No consistent instruction saving is established,
and the experiment does not isolate the cause of the small difference.

The completed guard/controller and all 16 browsers, including seed/eligibility,
exit zero. PID adoption and ownership audits pass. The unchanged 12-GiB guard
records 53.543013459 seconds and a sampled aggregate peak of 465,469,440 bytes.
The host has 18 logical CPUs; measured-trial one-minute loads range from
6.6796875 to 7.50439453125. Measured trials start after the separate GitHub
compilation cohort finishes. The eligibility setup ran while that preparation
was active; it contributes no timing or instruction samples to the seven pairs.

All failed controller attempts remain. The first exits before launching a
browser because ambient proxy-bypass controls were not cleared. The second
stops after a valid interpreter capture because its audit wrongly requires an
optional native-execution field. The third also wrongly requires that field
in a timed native capture with diagnostics disabled. Those browser captures
and pixel/counter receipts pass; their controllers/guards exit one after capture.
The corrected protocol requires absent instrumentation counters in timed runs
and positive execution only in the separate eligibility run. It uses a new
output, registry and native cache and completes the seven pairs above.

The earlier measured receipts are retained explicitly: interpreter
3,549,925,390; interpreter 3,550,259,706; native 3,556,084,076 instructions.
Including those observations leaves the conservative ratio unchanged at
1.00751224811241. No attempt is hidden or selected to obtain an improvement.

The completed command clears all eight proxy variables and runs
`python3 docs/performance/libjs-hn-native-browser-20261117-5204/run_r4.py`
through `sh tools/run_v_tool.sh run_memory_bounded`, using lock
`Build/libjs-hn-native-browser-5204-r41-r4.lock`, report
`Build/libjs-hn-native-browser-5204-r41-r4-guard.json`, shared PID registry
`Build/libjs-hn-native-browser-5204-r41-r4-pids.json`, and a 300-second watchdog.
Exact commands, logs, input hashes, process identities, PNGs, raw counts and
every failed attempt remain local under
`docs/performance/libjs-hn-native-browser-20261117-5204/` and
`docs/performance/libjs-github-browser-20261116/scratch-receipts/continued-20261117-r41/`.
Completed Build outputs and locks are removed. Automated test suites remain
paused; these are browser experiments, not a resumed test-suite run.
