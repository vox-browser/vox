# Old Reddit CPU instruction comparison

The 2026-11-01 [catalog audit](OPTIMIZED_SITES_AUDIT.md) verifies the documented
arithmetic and startup scope, but the referenced private `Build/reddit-parity/`
fixture and process receipts are absent from this checkout. The historical
measurement below cannot be independently reverified here and is listed
separately from freshly verified catalog entries. The ratio of its medians
gives **23.38% fewer instructions**; its **23.44% median paired reduction** is
a different statistic. The legacy harness also did not enforce a fresh Vox
profile; fresh profiles, sanitized environments and fuller runtime pins are
now required by the repaired driver. No new Reddit performance claim is made.

On 2026-10-17, the production build used **21.39% fewer retired CPU
instructions** in the conservative seven-run comparison:
`max(Vox) / min(Brave) = 0.786111236`. Every measured
1024×768 document viewport has exact RGBA equality with the frozen authenticated
Brave reference: **zero differing pixels**, with no tolerance or excluded area.

| Run | Vox instructions | Brave observed instructions | Differing pixels (Vox / Brave) |
| --- | ---: | ---: | ---: |
| 1 | 6,447,334,359 | 8,359,043,525 | 0 / 0 |
| 2 | 6,278,920,882 | 8,201,554,772 | 0 / 0 |
| 3 | 6,289,762,769 | 8,225,122,809 | 0 / 0 |
| 4 | 6,291,475,588 | 8,208,707,273 | 0 / 0 |
| 5 | 6,251,320,860 | 8,204,109,772 | 0 / 0 |
| 6 | 6,302,631,857 | 8,206,238,907 | 0 / 0 |
| 7 | 6,242,200,594 | 8,229,996,379 | 0 / 0 |
| Median | 6,289,762,769 | 8,208,707,273 | 0 / 0 |

The median paired reduction is 23.44%.
The gate requires the highest Vox count to be at least 15% below the lowest
Brave count. It does not select the fastest run or compare medians alone.
These are observed results for this workload and hardware.

## What is measured

This is a **fresh-process launch through completed native viewport capture**
comparison of the same frozen page, with encoded resources already archived.
It includes startup, parsing, styling, layout, painting and capture encoding.
It is not a render-only counter, a cold filesystem-cache test, or a live Reddit
JavaScript/interaction benchmark.

The counter is macOS `proc_pid_rusage(RUSAGE_INFO_V4).ri_instructions` on an
Apple M5 Max running macOS 26.5. It includes CPU work charged to the observed
process threads, including charged kernel/driver execution. GPU machine
instructions, WindowServer and external services are outside this counter.

Vox includes its final root counter, read while the exact process is an
unreaped zombie, and therefore also includes process teardown. Brave includes
its observed browser descendant tree through the last complete sampler pass
before the first successful screenshot response. Brave's count is a polling
lower bound: late work and final counters from children that disappear between
polls can be missed. Brave audit and shutdown work are excluded. This
asymmetry favors Brave in the reported comparison.

Both browsers receive the same local HTML and original resource response
bodies/headers. Requests absent from the archive fail closed. Brave profiles
and resource caches are isolated per launch; the legacy harness does not prove
Vox profile isolation. Engine order alternates, and no decoded-image or
saved-page raster cache is used. The viewport and device scale are 1024×768
and 1 in both engines. Normal scripting policy remains enabled to preserve
`noscript` semantics; the frozen input has executable script tags removed.
See [the rendering comparison](OLD_REDDIT_BRAVE_PARITY.md) for authentication
and capture scope. The original Brave profile is unchanged.

## Implementation and memory

The initial three-run Vox median was 26,703,551,329 instructions. The final
median is 6,289,762,769, a reduction of
76.45% from that Vox baseline.

The changes retain managed collection during active browser work, keep its
policy across asynchronous callbacks, and perform idle cleanup outside paint
frames. Batch screenshots coalesce incomplete document pixel replays while
continuing to service engine tasks, layout and load promises. Ordinary windows
retain progressive painting. Capture uses its requested pixel density from the
first presentation and reuses a matching presented raster while honoring real
invalidation, resize and density changes. Redundant readiness wakes are
coalesced. CPU image conversion is deferred until a GPU fallback needs it,
and animation timelines avoid invalidating styles without effect targets.

Large documents with scripting enabled now receive the same bounded 160 MiB
heap-capacity hint already used for large static documents (at least 1,024
elements). Small documents and explicit collector settings retain their
existing behavior. Collection stays enabled and idle page unmapping remains
available. The final runs contain **no collector environment overrides**;
`collector_environment` in the result is empty. Vox's observed root lifetime
peak physical footprint spans 622.0–638.3 MiB.
Capacity hints trade some transient memory for fewer repeated heap traces.

## Reproduction and artifacts

The following command requires restoring the private fixture and reference
first. Reuse the latest completed signed bundle, an existing verified
process-local network guard and pixel-diff tool, following `AGENTS.md`.
Run from the repository root under the memory guard:

```sh
env -u VOX_TRACE_REDRAWS -u GC_INITIAL_HEAP_SIZE -u GC_MAXIMUM_HEAP_SIZE \
  -u GC_FREE_SPACE_DIVISOR -u GC_MARKERS \
  python3 tools/run_memory_bounded.py \
  --lock Build/reddit-repeat.lock --report Build/reddit-repeat-guard.json -- \
  python3 tools/reddit_browser_instructions.py \
  --html Build/reddit-parity/frozen.html \
  --expected Build/reddit-parity/brave-frozen.png \
  --cache Build/reddit-parity/instructions/frozen-cache \
  --repeat 7 --output Build/reddit-parity/instructions/new-measurement
```

The output directory and guard receipt names must be new.
The command exits nonzero on a pixel mismatch, unreadable counters, changed
pinned inputs/binaries, or a failed instruction gate. Keep measurement runs
serialized with other local tests and builds. Account-bearing inputs and raw
results stay in ignored, mode-0700 `Build/reddit-parity`.

The accepted receipt is
`Build/reddit-parity/instructions/document-heap-verified/summary.json`, with
per-browser counters, native phase logs, captures and exact pixel comparisons
beside it. Earlier failed cohorts and heap environment probes remain private
and receive no credit for the final default-build result. The saved
[side-by-side image](images/old-reddit-brave-vox.png) remains pixel-identical.

Pinned SHA-256 values for this receipt:

| Input | SHA-256 |
| --- | --- |
| Frozen HTML | `c5904316065b4e6a7de8f55cb61098a9b65961579685dace50b771ecd984718c` |
| Brave reference | `a061aff1dfa50faf4ad39879a08edfa91d544572998f93379239d3ab83e92c71` |
| Resource archive tree | `d7f1e3d3c220cacde473861e335aceb3b8c72b274775dca1ff85d252a4b0bbdd` |
| Vox executable | `ff5de5ae57830aad494bc44b63095ebf707eb90b23669cf450380e16701aeef4` |
| Brave executable | `a17d7d68343726bb2a601ef237b90198bf1bb0133952dc3935435c8fed70d6f5` |

The summary additionally pins both rendering dylibs and the network guard.

## Verification

The broad verification baseline was the exact coalesced-capture cohort,
7,142,006,615 Vox instructions at the same launch-through-capture endpoint.
The final median saves 852,243,846 instructions from that baseline, exceeding
the repository's 5,000,000-instruction broad-check threshold.

Focused checks cover native frame density, invalidation and pixel copying,
paint-context ownership, coalesced/cancelled capture timers, readiness,
consumed navigation wakes, non-consuming script-state inspection, heap scopes,
and heap-hint bounds/overrides/retained ownership. Relevant tests pass under
both Boehm and `-gc none`. Collector-tool tests pass (41 tests).

The broad batch also includes both platform suites (24 pass, one deliberate
skip each), all 100 exact LibJS AST corpus cases, the frozen page and thirteen
public Brave fixtures, eleven default screenshot cases under their existing
rules, eight live SVG mutation cases, native Skia pixel tests, headless startup
and signature verification. Broad visual receipts are prefixed
`Build/reddit-parity/v2/document-heap-`; inputs and tolerances are unchanged.
