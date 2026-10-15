# Wikipedia below 500 MB

The 2026-10-15 production build stays below **500,000,000 bytes** of process
physical footprint while loading and capturing Wikipedia at a 1024×768 document
viewport. All five recorded-page runs, a 20-second settled run, and a live
`https://wikipedia.org` run pass. The largest observed peak is **480,937,352 bytes**.

| Observation | Peak physical footprint |
| --- | ---: |
| Previously installed executable, one controlled run | 993,691,280 bytes |
| New build, median of five recorded-page runs | 471,680,416 bytes |
| New build, maximum of those five runs | 480,937,352 bytes |
| New build, 20-second settled capture | 453,330,240 bytes |
| New build, live Wikipedia capture | 475,252,176 bytes |

The five peaks are 480,937,352; 466,142,648; 465,028,512; 471,680,416; and
475,891,104 bytes. The settled run's final five-second median is 428,787,008 bytes.
The new maximum is 51.6% below the older observed peak. The older executable is
pinned by SHA-256 `eae5e104acc7d3a0586eca8c9f1cd1fc5b423ef51a0015f6f00d2962a151fa9a`;
its exact build-source provenance was unavailable, so no particular heap setting
is attributed to that binary.

The new frozen-workload median is **7,955,815,232 retired instructions**,
**22.912% fewer** than the retained conservative Chrome reference of
10,320,464,389. This retains the earlier 20% instruction target. The historical
29.817% result in [the instruction report](WIKIPEDIA_INSTRUCTIONS.md) belongs to
the older build. Live-network and long-settle instruction counts are separate
workloads and receive no Chrome-comparison credit here.

## Changes

The native view now rasterizes a complete frame into an owned sRGB bitmap and
presents its immutable image through `CALayer.contents`. Direct window painting
previously caused Quartz to upload and retain textures for individual Skia
primitives. Combining those operations into one presented image removes that
graphics-cache overhead. Retina display scale, resize invalidation, Sokol's
window timing/close callback, and logical-pixel screenshot scale are preserved.
Screenshot scale changes are scoped to the browser's capture entry points.

The browser initializes its managed heap before startup work with a **224 MiB
initial reservation** and a free-space divisor of at least **16**. The reservation
avoids repeated growth during startup; more frequent collections reclaim
temporary layout and paint records. It replaces the former document-size-based
expansion. Collection remains enabled and there is no hard heap maximum.
Explicit `GC_INITIAL_HEAP_SIZE`, `GC_MAXIMUM_HEAP_SIZE`, or
`GC_FREE_SPACE_DIVISOR` settings take precedence over the entire policy.

Disabling Metal drawables alone did not produce the large saving, and receives
no separate memory credit. Lower-collection diagnostic settings that exceeded
the limit after settling were rejected. The final measurements have no heap
environment overrides or injected renderer libraries.

## Workload and verification

Each run explicitly enables page JavaScript and the full uBlock Origin engine
with 258,456 filters from nine pinned lists. All seven final screenshots have
identical decoded document pixels to the retained Wikipedia baseline. All six
recorded-page/settled runs preserve the exact multiset of 54 filtering decisions.
Live navigation records 59 checks: after origin normalization it contains all 54
baseline decisions plus five checks associated with the real redirect and its
script/image requests. No filtering-engine errors occur.

The recorded HTML, sprite, viewport, and fresh copies of the unchanged warm cache
match the instruction benchmark. Six absolute HTTPS donation-badge URLs retain
their earlier external-network limitation; their legacy cache entries lack
redirect provenance. Filtering logs record decisions, not successful HTTP
responses. No cache provenance was fabricated.

Counters use macOS `proc_pid_rusage` / `RUSAGE_INFO_V4`, including the unreaped
root process's exact lifetime maximum physical footprint through native PNG
capture and teardown. Current footprint/RSS samples are also retained at a 5 ms
interval. The target uses decimal MB. It is verified for this Wikipedia workload;
larger live documents can still grow their heap.

Focused native tests pass in both Boehm and no-GC modes: seven cases per mode
cover image ownership, scale, context restoration, capture exceptions, lifecycle,
and parent callbacks. Early-heap tests pass in both modes, including explicit
settings and retained nested maps, arrays, and Unicode across forced collections.
The production bundle also passes `--headless-smoke` and three exact screenshot
checks: `svg-image-source-switch-same-size`, `canvas-text`, and `svg-feTurbulence`.
Broad suites were deferred under the repository's batching policy; this report
adds no broad-suite or later independent source-change credit.

An unattached-view `needsDisplay` probe initially suggested a resize problem.
The getter was unsuitable for that fixture. A corrected invalidation-callback
probe passes for frame and bounds changes; no resize fix was shipped. Proposed
edits made briefly during compilation were restored, and the compiled binary
retains the original hook and excludes the proposed hook. The restoration and
binary-symbol evidence are retained.

## Source and artifacts

The measured source is `1eb26abcd676f3a59a3a4dc38ef0142847a07a83`, incorporating
native changes `5dacd60d` and `d11662f8` and the early heap policy. Later committed
repository work is merged without extending this measurement's source claim.
The private executable SHA-256 is
`6c8bfd08283a30b72fa90e5f8fb2839189c49e89da931d78cb573875815c7a92`.

The bundle is installed at `Build/v/Vox.app`. Relocation changes its library
search path and ad-hoc signature while preserving every Mach-O `__TEXT` section
and all 48 non-system runtime-library hashes. Its installed executable SHA-256 is
`6c4fab118d3c928b15cbe30be6aac1a68aba73e544eb7f59b1322c520f9ae928`.
The actual installed executable separately passes its startup smoke check,
recorded Wikipedia capture at **463,619,464 bytes**, and live Wikipedia capture
at **465,601,976 bytes**. Both installed captures preserve the exact document
pixels and filtering decisions. Code and runtime-library hashes remain unchanged.

Evidence under `Build/wikipedia-memory-target/` includes:

- `candidate-v5-final-build-result.json` and its library closure: source and
  normal-build pins. Original build/packaging failures remain intact; successful
  compiled output was finalized without rebuilding.
- `final-production-v5-finalized-v1.json`: all seven original captures and 98
  rechecked evidence pins. The original observer rejected the live run's fixed
  filter-count expectation; read-only finalization validates the exact redirect
  additions without repeating any browser run.
- `early-heap-focused-v1-result.json`, `native-layer-focused-v1/result.json`,
  `native-layer-screens-v5-v1/result.json`, and
  `v5-native-source-restoration-attestation-v1.json`: focused checks and source
  restoration audit.
- `installed-candidate-ram500-v1-attempt-2-result.json`: atomic installation,
  code/library identity, and retained prior-bundle backups. The first installation
  attempt's helper-path failure rolled back both original targets.
- `installation-validation-v1.json`: successful startup and both actual installed
  captures, including their complete final counters and immutable runtime pins.

To repeat the recorded workload while its retained server is running, use the
versioned `measurement-v3/profile.py` with a pinned binary and library manifest.
Omit `--initial-mib`, `--maximum-mib`, `--free-space-divisor`, and diagnostic
injection options for normal production verification. Build from the repository
with `sh build-prod-browser.sh`; the measured source cutoff and runtime manifest
above identify this report's exact binary.
