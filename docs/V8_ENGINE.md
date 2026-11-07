# Experimental V8 backend

Vox runs page script on JavaScriptCore. Its bindings (about 150 V/C files) call
the JavaScriptCore C API directly. `VOX_JS_ENGINE=v8` builds the same browser
against an implementation of that C API on V8, so no binding changes. The
default build is unchanged and still uses JavaScriptCore.

## Build, run and test

```sh
brew install node          # V8 14.6 headers and libnode.147.dylib
VOX_JS_ENGINE=v8 sh build-prod-browser.sh
VOX_V8_DIAGNOSTICS=1 Build/v/Vox.app/Contents/MacOS/Vox https://chatgpt.com/
sh tools/test_jsc_on_v8.sh  # JavaScriptCore vs V8 differential check
```

The build compiles `browserjs/v8/jsc_on_v8.cpp` into `libVoxJSCOnV8.dylib`,
adds `-d vox_v8`, puts `browserjs/v8/include` ahead of the system framework
headers, and links the library instead of JavaScriptCore.framework. The bundle
loads V8 from `VOX_V8_ROOT` (default `/opt/homebrew`); it is not relocatable to
a machine without Homebrew node. `VOX_V8_FLAGS` passes V8 flags.
`VOX_V8_DIAGNOSTICS=1` prints the V8 version and handle counters at exit.

`tools/test_jsc_on_v8.sh` builds `browserjs/v8/jsc_api_conformance_test.c`
against JavaScriptCore (with `module_loader_darwin.m`) and against the backend,
also under AddressSanitizer/UndefinedBehaviorSanitizer, and requires identical
output for 78 checks: conversions, properties and attributes, host functions and
private data, exceptions, promises and microtask draining, typed arrays,
strings, protected values across turns and collections, classed globals,
asynchronous WebAssembly compilation, and module graphs (static imports, live
bindings, top-level await, syntax and evaluation errors, missing dependencies,
dynamic `import()` and deferred supply). Lines whose wording is engine-specific
(error messages, host functions inheriting `Function.prototype`) are labelled
`engine` and excluded.

## Design

**Values.** JavaScriptCore values stay valid while the C stack, a protect count
or the JS heap reaches them, and objects never move. V8 needs explicit handles
and moves objects, so every `JSValueRef` is a box:

- `undefined`, `null`, `true` and `false` are process-wide constants, so
  pointer comparison with `JSValueMakeUndefined()` still works;
- numbers carry their double;
- strings, symbols and BigInts own a `v8::Global` for the current turn, or
  longer while protected;
- each object has one canonical box, found through its identity hash, so maps
  keyed by `JSValueRef` keep working. An object box is strong during the turn
  in which it was last handed out and while protected; afterwards it is weak
  and is freed only when V8 collects the object. As in JavaScriptCore, an
  unprotected object pointer stays valid while the object is alive.

A turn ends at a `CFRunLoop` `BeforeWaiting` observer on the isolate's thread.
Vox pumps the run loop inside layout and navigation work, and nested loops can
run while a host callback is active, so a turn only ends at the outermost loop
level (identified by stack depth) with no host callback active.

**Isolates and threads.** A context group is an isolate; each Vox agent thread
creates its own. Every API entry takes a `v8::Locker`, as every JavaScriptCore
entry takes its API lock, and sets the thread's stack limit near the bottom of
its real stack. Microtasks drain when the outermost API entry returns, as they
do when JavaScriptCore releases its lock.

**Platform.** V8 worker threads come from the default platform. Foreground
tasks for an isolate (asynchronous WebAssembly compilation, GC finalization)
run on its thread's run loop, again only at the outermost level.

**Host objects.** Vox uses classes only for `callAsFunction`, private data,
`finalize` and a named worker global. Callback objects are V8 functions created
with `Function::New`; their box holds the class, private data and callback.
Unlike JavaScriptCore callback objects, they inherit `Function.prototype`.

**Modules.** `module_loader_darwin.m` uses JavaScriptCore's `JSScript` and
module-loader delegate SPI. The backend implements the same
`vox_module_loader_*` interface with V8 modules: a per-realm module map, one
fetch per URL through the existing `ModuleHost` delegate, linking once a graph
is complete, top-level await, and `import()` through
`SetHostImportModuleDynamicallyCallback`. The V module transform already
rewrites specifiers to absolute URLs.

**Not implemented.** The Objective-C `JSContext`/`JSValue` API, the JSScript
module source cache, persistent code caches and JavaScriptCore SPI. The adblock
helper executable is still built against JavaScriptCore; in-process adblock
contexts in the browser and its worker processes run on V8.

## ChatGPT comparison, November 7

Question: does V8 change Vox's chatgpt.com load time or the time to answer
"capital of italy"? Full rows, identities and conditions are in the
[receipt](performance/v8-engine-chatgpt-20261107.json).

Both bundles were built from the same clean commit (`c311b8215`, identical
build-input hash) in single-C-unit V `-prod` mode with the prealloc allocator:
JavaScriptCore 22625.2.8.11.9 (macOS 27.2) versus V8 14.6.202.34 from Homebrew
node 26.8.1. `tools/measure_chatgpt_engines.py` alternated fresh launches with
empty private profiles over the SOCKS route, anonymous sessions, a 1024×768
document viewport and native key input; a driver probe polled the page every
100 ms. Two cohorts of seven pairs ran on a shared 18-CPU host (one-minute load
averages 10.5–18.1). Every attempt is retained.

| Median (successful trials) | JavaScriptCore | V8 |
| --- | ---: | ---: |
| Launch to laid-out composer | 2.96 s (n=14) | 2.75 s (n=14) |
| Launch to ChatGPT bootstrap marker (cohort 2) | 11.05 s (n=7) | 12.43 s (n=7) |
| Return to user message shown | 2.15 s | 1.46 s |
| Return to first answer containing "Rome" | 10.30 s (n=11) | 8.70 s (n=11) |
| Browser CPU until typing (load + settle) | 5.54 s | 5.38 s |
| Browser CPU, Return to answer | 6.60 s | 6.78 s |
| Peak physical footprint | 2,291 MiB | 2,604 MiB |

Per cohort the direction flips: launch to composer was 4.21 s versus 2.26 s in
cohort 1 and 2.77 s versus 3.37 s in cohort 2; the answer took 6.91 s versus
6.34 s, then 11.18 s versus 11.73 s. Paired, V8 was faster in 6 of 14 load
pairs (median difference +0.08 s, range −2.22 to +2.36 s) and in 5 of 8 answer
pairs (−1.35 s, range −5.40 to +2.92 s). Answer time is dominated by the
service: both engines slowed from about 6–7 s to 9–14 s between cohorts.
**No end-to-end difference is established** at this sample size. V8's peak
footprint is about 300 MiB higher.

Six attempts failed, three per engine: in cohort 1 the typed prompt did not
reach a re-rendered composer (two V8, one JavaScriptCore; cohort 2 retries the
focus before submission, outside the measured interval); in cohort 2 one V8
query got ChatGPT's "temporarily experiencing issues" banner, and two
JavaScriptCore submissions never posted the user message (the page stayed on
`/` after Return). Whether the latter is engine-related is not established.

The counters cover the browser process only, not its worker and adblock helper
processes. The probe adds identical work to both engines. This is a live
user-flow observation, not a frozen-page instruction comparison, and gives no
optimization credit.

### Engine-only workloads

`tools/compare_js_engine_microbench.sh 4 5` runs the same programs through the
C API in alternating processes (four rounds; warm medians of runs 2–5):

| Workload | JavaScriptCore | V8 | V8 / JSC |
| --- | ---: | ---: | ---: |
| Object allocation and property access | 25.0 ms | 7.8 ms | 0.31 |
| Classes, methods and `Map` | 6.7 ms | 5.1 ms | 0.77 |
| String building, split and RegExp | 25.3 ms | 31.4 ms | 1.24 |
| `JSON.stringify`/`parse` of 50,000 objects | 126.4 ms | 170.7 ms | 1.35 |
| Sorting with closures | 93.9 ms | 123.5 ms | 1.31 |
| Compiling 20,000 functions (first run) | 42.8 ms | 41.9 ms | 0.98 |
| 300,000 JS→native calls | 35.1 ms | 44.0 ms | 1.26 |

Neither engine wins overall. The last row is the backend's own overhead: a
native callback through boxes costs about 147 ns versus about 117 ns in
JavaScriptCore.

### Diagnostics

Over one complete ChatGPT load and query, the backend created 369,577 value
boxes and freed 348,104 at turn ends; 9,853 object boxes were released by V8
collections. The largest turn held 73,976 boxes. There were 232,605 JS→native
callbacks, 10,756 native→JS calls, 887 script evaluations and 383 modules, with
no cross-thread use in the browser process.

A 12-second `sample` of each launch attributes about 545 samples to
`libnode.147.dylib` versus about 260 to JavaScriptCore, with similar totals for
Vox code; this undercounts JIT code and V8's background compiler/GC threads
are included, so it is only indicative.
