# LibJS code reuse across page visits

LibJS documents now compile executed code during the first visit and load the
native binaries before those executables' first instruction on a later visit.
They also reuse immutable parsed sources across visits in the same process.
The JavaScriptCore default and engine-selection setting are unchanged.

This replaces the old experiment's requirement to repeat warmup in every VM.
The disk cache persists across browser restarts; the parsed-source cache is
process-local. Reopening still creates new realms, modules, environments,
constant pools and bytecode. Cached code never restores first-visit DOM objects,
variables, module evaluation results or side effects.

## Behavior and invalidation

* The native cache lives in `libjs-native-code/` beside the profile's settings.
  It is partitioned by generated-code ABI, target OS/architecture, source bytes,
  source URL, script/module/function identity and bytecode layout.
* Native records contain library hashes and symbol indices. Libraries are hashed
  before mapping; malformed, changed or missing records fall back to interpreting
  the current executable once. A successful later checkpoint repairs the entry.
* The first document coalesces missed executables into idle compilation tasks.
  Runtime disposal flushes remaining code before unloading libraries. Compilation
  and unloading reject active VM entries. Cache/compiler failures leave author
  code runnable and never replay its effects.
* A new VM performs native lookup before an executable's first instruction. It
  requires no warmup or execution profile. Second-visit tests replace clang with
  `/usr/bin/false`, so attempting to compile would fail the check.
* Parsed-source reuse is partitioned by profile, source bytes/type and parser
  options. The process-wide LRU retains at most 128 entries and 4 MiB of source
  bytes. That is an entry/source budget, not a hard RSS bound. Failed or
  recursion-limited parses are not retained. Resource text and syntax records
  are allocated independently of the first document's storage lifetime.

The compiler's numeric/control fast paths still use runtime guards; dynamic
operations keep the interpreter helpers. This is baseline native code, not a
type-feedback optimizing compiler. Parser reuse and resource caches can explain
reopen gains independently of native instruction throughput.

`VOX_LIBJS_NATIVE_CACHE=0` disables both caches for a document. A path overrides
the native cache directory; `VOX_LIBJS_NATIVE_COMPILER` selects the compiler for
diagnostics. These are process/test controls, not additional browser settings.

## What the GitHub diagnostic measures

`tools/libjs_github_revisit.v` creates a fresh native document, browser Runtime,
module host and performance binding for each visit. It runs the archived
`https://github.com/vlang/v` HTML and author-module initialization with the
original response bodies/headers. The second visit uses a fresh VM in the same
process and has the compiler disabled. It measures HTML parsing, realm/host
setup, author-script/module preparation and execution through idle compilation.
Fixture reading/hashing, post-timing audits, teardown, network, a native window,
layout, painting and PNG encoding are outside that interval.

**This is incomplete GitHub initialization, not a successful page-load or visual
acceptance.** Both visits retain 33 server-rendered directory rows and zero
commit links. They report identical unsupported for-of/async-generator and
missing-Set errors on the measured build. No JavaScriptCore context or fallback
is created. The diagnostic records these failures rather than treating process
exit zero as hydration success.

The retained November 8 manifest is SHA-256
`893e042c4f31e1b7fb984c81cf8f6a2a7eb65d790f7c3f4cc3e372c065de302d`;
its 427,595-byte HTML is
`a0f615f45a8745e26aa57443182e238ddcb678f19aa2915c69d5ef66ff7b1a08`.
The fixture was restored from the existing retained archives into the persistent
benchmark cache after shared `Build/` cleanup removed the old extracted copy.
Response records and every mapped body's hash are checked. The changed local
source-map paths do not rewrite source bytes, imports or headers.

## Seven first/reopen pairs — 2026-11-15

| Pair | First initialization ms | Reopened initialization ms |
| --- | ---: | ---: |
| 1 | 25440.603667 | 930.344917 |
| 2 | 25457.305250 | 994.575916 |
| 3 | 28222.692416 | 1104.311583 |
| 4 | 32324.405792 | 1081.246250 |
| 5 | 42607.425708 | 1111.341250 |
| 6 | 41326.998375 | 1516.987416 |
| 7 | 40354.912416 | 1073.876167 |

The medians are **32,324.405792 ms first** and **1,081.246250 ms reopened**:
about 30× faster by the ratio of medians. The median paired second/first ratio
is **0.036569294**, and the conservative highest-second/lowest-first ratio is
**0.059628594**. These describe the cached, incomplete initialization workflow;
they are not native-instruction throughput or completed GitHub page-load results.

Every first visit parsed 51 sources, missed and compiled 109 native executables,
and invoked clang twice. Every second visit reused all **51 parsed sources** and
**109 native executables**, with zero parser misses, native misses, invalid
entries or compiler invocations. Median native compilation time on the first
visit was 9,877.660583 ms; native-library loading on reopen was 5.429833 ms.
The second visit had a fresh realm/module environment and the compiler was
`/usr/bin/false`. No warmup was performed in that VM.

The existing response cache also avoided fixture transport calls (43 first,
zero second, in every pair). Parser reuse, resource reuse and removal of first-
visit compilation cost all contribute. No isolated native-execution gain is
claimed. One-minute host load ranged from 3.43 to 10.56 on 18 logical CPUs;
retain the large variation in first-visit timings rather than selecting faster
trials. All seven processes, the driver and guard exited zero. Peak sampled
aggregate RSS was 2,916,433,920 bytes under the unchanged 3 GiB runtime guard.

Every pair retained identical title, 33 rows, zero commit links and the same
six module errors. The driver therefore records `cache_workflow_verified=true`,
`complete_page_load=false`, and `speed_acceptance=false`. Full hydration, pixels,
live navigation and displayed performance remain open.

The pinned C/clang/single-unit `-prod` harness SHA-256 is
`d846810c1729f70258d90fba2d56c140ce7b837a9bf867bdf6c075b214523397`.
It built in 97.38 s with sampled peak aggregate RSS 6,783,205,376 bytes under the
12 GiB guard; compiler and guard exited zero. The complete cohort took 245.10 s.
Individual source/library hashes, commands, host readings, exact results, stdout,
stderr and exits are in local
`docs/performance/libjs-github-revisit-20261115-cohort-r2/results.json`.

Earlier diagnostics are retained separately. The native-cache-only harness used
two fresh processes: 21,642.285583 ms first and 17,901.220833 ms second, with
60 native hits and zero compilation on the second process. That older binary
predates concurrent for-in/runtime changes and the parsed-source cache; it is
not a matched control for the later cohort. A same-process pilot of the final
harness took 26,321.947416/1,220.715000 ms, also retaining identical failures.
Two attempted cohort launches failed before starting browser processes because
the old extracted fixture had been removed. Their logs/guard exits are retained;
the restored immutable fixture supplied every completed pair above. No process
trial was discarded or retried to obtain the result.

## Checks and limits

Three persistent-cache tests and six existing native-tier tests pass in both
default-GC and GC-disabled modes. Five browser tests pass in both modes, covering
first-visit compilation, compiler-free second execution, idle coalescing, fresh
module live bindings, imported dependencies updating the new DOM, parser limits
and disabling caches. The exact upstream AST driver matches 100/100 fixtures.
The focused suites, builds and runtime diagnostics use the memory guard; V
invocations supply `-memory-limit 10G`. Runtime diagnostics use a 3 GiB budget.

No new whole-package, whole-browser visual or retired-instruction performance
acceptance is claimed. The available production receipt (`0e836d1f0`, verified
through `e535e22a6`) predates the parsed-source cache. Its fresh, privately profiled
`--headless-smoke --js-engine=libjs` process passed startup, DOM mutation and click
checks (browser/guard exits zero, sampled peak RSS 115,916,800 bytes). It created
no native-cache artifacts, so this is baseline evidence, not validation of the
new cache workflow. Its executable SHA-256 is
`90aaf0a525e848a597a9ba12603047ae999b6a7549bd454b925dbaeba4b61329`.
Managed commit hooks request the next production build. Source-built checks
validate the new workflow without copying an app bundle or queuing a duplicate
manual production build; full installed-browser validation remains pending.

## Reproduction

Use a persistent verified original-response fixture with a `manifest.json` and
`source-map.json` mapping its original URLs to the content-addressed local bodies.

```sh
env V3_STR_CAP=1 V_MACOS_V3_NO_FALLBACK=1 \
  sh tools/run_v_tool.sh run_memory_bounded \
    --lock Build/libjs-revisit-build-UNIQUE.lock \
    --report Build/libjs-revisit-build-UNIQUE.json -- \
  "$HOME/code/v/v" -w -n -nocache -b c -no-parallel -cc clang \
    -memory-limit 10G -enable-globals -prod \
    -o /tmp/vox-libjs-github-revisit tools/libjs_github_revisit.v

sh tools/run_v_tool.sh run_memory_bounded --limit-gib 3 \
    --lock Build/libjs-revisit-UNIQUE.lock \
    --report Build/libjs-revisit-UNIQUE.json -- \
  python3 tools/benchmark_libjs_revisit.py \
    --binary /tmp/vox-libjs-github-revisit --archive ORIGINAL_FIXTURE \
    --output docs/performance/libjs-github-revisit-UNIQUE --pairs 7
```

The paired driver starts a fresh process and private code cache per pair,
preserves every attempt and verifies identical content/error audits across the
two visits. It records executable/fixture hashes, commands, outputs, exits,
timestamps, host CPU/load and native library hashes. OS filesystem/loader caches
and existing resource caches are retained. First/reopen order is intrinsic to
this workflow; it is not an alternating optimized/unoptimized engine comparison.
Raw JSON/logs and generated native libraries stay local under
`docs/performance/libjs-github-revisit-20261115-*`; no evidence archive or binary
is committed.
