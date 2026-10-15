# Wikipedia instruction benchmark

The recorded Vox V6 build used **29.817% fewer CPU instructions than Chrome** on the Wikipedia portal load, exceeding the requested 20% reduction. Five production Vox captures and five fresh Chrome confirmations retain the same completed pixels as their respective baselines.

The current browser uses normal managed-heap growth. The later automatic 4 GiB
document heap expansion was removed after excessive Wikipedia memory use was
reported. The historical instruction measurements below retain their original
heap policy; they do not measure this memory fix. See [current memory
verification](WIKIPEDIA_MEMORY.md).

| Launch-to-capture comparison | Median retired instructions |
| --- | ---: |
| Conservative retained Chrome reference | 10,320,464,389 |
| Vox production V5, before the medium-document heap hint | 8,602,415,201 |
| Vox production V6 | **7,243,205,238** |
| Maximum for the 20% target | 8,256,371,511 |

The final five Vox counts are 7,251,067,590; 7,260,209,251; 7,161,911,113; 7,243,205,238; and 7,070,029,327. Every run also beats 80% of the lowest retained Chrome run. The fresh Chrome confirmation median is 10,365,801,670; the comparison keeps the smaller older reference instead of taking credit for that increase.

## Conditions and limits

Both browsers render the recorded Wikipedia portal at 1024×768 CSS pixels. The loopback server retains the 122,197-byte HTML (SHA-256 `5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`) and 51,190-byte SVG sprite (`7990aaba48727a6b458090128a1ccc1a1529cdee1449600864cfb92336240753`). Vox receives a fresh copy of the unchanged warm cache for each run. Chrome receives a fresh profile and directly opens the URL. Before capture it waits for complete readiness, fonts, 2,022 localized text characters and all 21 sprite elements; the retained image audit confirms the decoded globe.

Vox runs explicitly enable page JavaScript with `--enable-javascript` and retain the default full uBlock Origin engine: 258,456 filters from nine pinned lists. All 54 filtering decisions per run are retained and unchanged. The browser continues to execute JavaScript through JavaScriptCore.

Six absolute HTTPS donation-badge URLs remain external. Their legacy cache entries lack final-URL provenance, so the redirect-safe loader fetches them again; responses can be HTTP 429. Chrome can defer those hidden lazy images. The loopback server has no network fallback, but the browser workload is not entirely network-frozen. Rule logs record filtering decisions, not successful HTTP responses. No redirect provenance was fabricated and the cache template was not changed.

Counters use macOS `proc_pid_rusage`/`RUSAGE_INFO_V4`. Vox's exact final root counter includes native PNG capture and teardown; cropping happens afterward in the observer. Chrome sums observed browser, renderer, GPU-process CPU and utility tasks through its completed screenshot response and excludes shutdown. Short-lived children or missing final child samples make Chrome a conservative lower bound; the fresh runs disclose missing-sample counts 3, 2, 1, 2, 0. No counts are extrapolated. Both exclude GPU execution and WindowServer. These measurements concern this startup workload and do not establish FCP parity or performance across other sites.

Vox's whole viewport matches its completed baseline exactly. Existing CJK font and footer/icon differences from Chrome remain; this is not a claim of cross-browser pixel equivalence or complete browser API parity.

## Changes and memory tradeoff

The main fixes remove redundant SVG descendant-model construction for transform queries, retain completed SVG backgrounds without rebuilding HTML geometry, and resolve only DOM identities needed by pending script mutations. Preload request types are indexed once, HTTPS resources share validated HTTP/2 connections with HTTP/1 fallback, and a bounded per-browser palette reuses parsed colors. Earlier fixes retain focused control models before layout and preserve viewport scroll origin during paint updates.

The full filter engine restores typed snapshot bytes and native ASCII JSON metadata rather than compiling default filter lists or lexing a large JavaScript literal at startup. The raw snapshot validates magic, exact length and CRC32, then creates independent context-owned mutable storage. Custom filters, cosmetics, scriptlets and redirects remain available. This trades approximately 12 MB of executable size for less startup work.

Profiling also found repeated collector work during temporary style/layout allocation. The existing 512 MiB reservation now applies from 1024 elements instead of 2048; Wikipedia has 1193 parser-created elements. Collection remains enabled, and explicit initial/max heap settings retain precedence. Production measurements clear external heap overrides and use ordinary C `-O2`, Boehm, `LARGE_CONFIG=1` and one GC marker.

This reduces instructions at a real memory cost: the median per-process peak physical footprint rises from 673,777,032 bytes (**643 MiB**) to 989,726,352 bytes (**944 MiB**). The five final peaks range from 978,159,224 to 992,937,592 bytes. The threshold applies to ordinary production documents, not a benchmark-only mode.

## Verification and provenance

The final frozen source passes **208 selected cases in each GC mode (416 executions)**: CSS 35, SVG 10, layout 77, native 73, adblock 2, browser JS 7, HTTP transport 3 and heap policy 1. All 100 upstream LibJS AST fixtures compare exactly, and production startup succeeds. Of 39 screenshot comparisons, 37 pass their existing bounds; the two existing gradient reference failures retain identical decoded pixels to their old baselines. All eight required live SVG mutation comparisons are pixel-exact. No bounds were changed.

The original broad wrapper counted zero cases for the two single-case heap tests because V omits its usual progress prefix. Both actual subprocesses exited zero with every assertion passing. The separate corrected aggregate reparses the exact expected function and assertion summaries, preserves the original failed wrapper receipts, and records all 416 executions without rerunning tests.

Snapshot validation also passes 10 Node tests, 118 old/new full-filter parity assertions, 35 native checksum views and 16 focused V executions, including ASan/UBSan, asset reproduction, context ownership and malformed-input checks. The final broad cadence follows a measured reduction of 1,359,209,963 instructions from V5.

The measured runtime source is `2f6a0e72aefc28bcce3b7cff6b4b0671a2b8360e`: 4,186 frozen files, manifest SHA-256 `b3e74fc4db6ec8710a65ea3576616742266af692d0217c16ea6aed34d0463aec`. The private executable SHA-256 is `1896dd622ba4b704903673a5ab6cfdbb6d7c39ee0eb35d67b923cc73251d3b1e`. Its non-system runtime libraries, compiler binaries and 13 HTTP transport sources are pinned.

The observer readiness fix `81f49c92` waits for Chrome's complete debugger port file and passes 28 driver/counter tests. It changes no measured native runtime code. The passed read-only recovery-v3 record retains the initial failed observer/postprocessing receipts and every completed capture; successful Vox or Chrome runs were not repeated for recovery.

Authoritative artifacts under `Build/wikipedia-instruction-target/`:

- `final-capture-pipeline-v6-recovery-v3-result.json` and `production-pipeline-v6-recovery-v3-result.json`: final comparison and preserved recovery provenance.
- `vox-combined-v6.json`, `chrome-confirmation-v6-recovery-v1.json`: all ten raw observations and capture paths.
- `production-source-v5-manifest.json`, `production-build-v6-result.json`, `production-build-v6-library-closure.json`: normal build and immutable source/runtime identities.
- `broad-v4-corrected-aggregate-v1.json`, `broad-batch-v4-result.json`, `broad-v4-platform-observer-correction-v2.json`, `broad-source-v4-manifest.json`: final selected regression checks, original wrapper failures, explicit read-only corrections and exact inputs.
- `final-snapshot-focused-evidence-v3.json`: native ownership, integrity, sanitizer, full-filter parity and asset reproduction proofs.
- `gc-reservation-profile-v1/`: separate attribution probes; their instruction savings are not added to the production result.

## Installed bundle

The measured bundle is installed at `Build/v/Vox.app`. Installation changes its private library search path and ad-hoc signature; every Mach-O `__TEXT` section and all 48 non-system runtime library hashes remain verified against the measured candidate. The relocated executable SHA-256 is `482a953decf38ba0bddd017ac553e6dc23ed4e322577bb1e284ea19706b230c0`.

The installed startup check and both frozen/live Wikipedia URL captures exit zero. The frozen capture retains exactly the measured viewport pixels. Original app/library versions are preserved under the versioned pre-install backup. See `installed-candidate-v6-recovery-v4-attempt-1-result.json` and `installed-v6-functional-verification-v1-result.json`; these installation checks receive no extra instruction-savings credit.

## Reproduction

Build with `sh build-prod-browser.sh`. The reusable observer is `tools/measure_browser_instructions.py`; Vox runs require `--vox-arg=--enable-javascript`, and direct Chrome runs require `--chrome-launch-mode direct --chrome-outer-window-height 911 --width 1024 --height 768`. Use five runs, explicit binaries/runtime-library arguments, and fresh copies of the retained cache. The versioned build/capture scripts record the exact commands and flags.

To restart the frozen fixture without overwriting its original evidence, copy `Build/wikipedia-instruction-target/frozen-server.py` to a new sibling directory under `Build/` and launch that copy. It serves port 49171 and reads `Build/wikipedia-performance/cache-template`. Use a new observer output prefix for every reproduction attempt.

Later independently authored media namespace and intrinsic-layout commits are preserved in the integrated source. They were merged after the measured runtime was frozen and receive no benchmark credit. The installed measured bundle retains the frozen runtime identified above.

The earlier repeated-SVG and first-frame measurements remain in [WIKIPEDIA_PERFORMANCE.md](WIKIPEDIA_PERFORMANCE.md); their endpoints and figures are separate from this completed-page startup result.
