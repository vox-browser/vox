# Wikipedia rendering performance

The later [completed-page instruction benchmark](WIKIPEDIA_INSTRUCTIONS.md) measures **29.817% fewer launch-to-capture instructions than Chrome** with full JavaScript and filtering enabled. Its source, endpoint, memory tradeoff and verification record are separate from the historical measurements below.

The fixes remove **89.52% of install-to-frame instructions** from the exact repeated-SVG workload while preserving every pixel. Observed warmed Wikipedia first-frame medians are 1,489 ms before and 831 ms after; the final page also restores the globe, wordmark, and localized text that were missing from the initial frame. These elapsed times are diagnostic under a heavily loaded machine. Whole-page native instructions are 8.24% higher across the combined builds, so this is not a demonstrated whole-page CPU reduction. Frozen-page launch through capture is 1,567 ms in Vox versus 1,444 ms in Chrome, with different endpoints. **Chrome page-rendering parity remains unproven.**

## Measurement record

All figures are measured on this Mac. The production builds use the normal optimized C backend and Boehm collector. The machine was heavily loaded by unrelated work; elapsed times are diagnostic. Instruction counters exclude GPU execution and WindowServer. Chrome descendant-process totals are lower bounds because short-lived processes or final child samples can be missed.

The initial Vox binary is recorded in `before-source.json`: source HEAD `5e617ea2`, binary SHA-256 `669a2b7c83c590317c452a316e30ceb9110ac849b8770a0c4fb58db3f57569a7`. Its three runs used identical fresh copies of a frozen warm resource cache (`40fbc472c4bbf9fbfd537fa35abb645d35c17d14fe06b280641aa5e861754b25`). That original first frame lacked localized text, the globe, and SVG artwork, so it is not a content-equivalent baseline for a fully rendered final page.

Vox's counters in `paint/timing.v` begin at native navigation or document installation and stop at the first submitted document frame. They do not wait for background refresh or screenshot capture and do not measure web FCP.

| Vox workload and endpoint | Before | Measured Vox |
| --- | ---: | ---: |
| Warmed Wikipedia, 1024×768: native navigation → first submitted document frame, median instructions | 5.031 billion | 5.445 billion |
| Warmed Wikipedia: native navigation → first submitted document frame, median elapsed | 1,489 ms | 831 ms |
| Warmed Wikipedia: process launch → capture exit observed, median elapsed | Not collected with this endpoint | 1,669.89 ms |
| Frozen loopback Wikipedia: native navigation → first submitted document frame, median | Not collected | 817 ms; 5.458 billion instructions |
| Frozen loopback Wikipedia: process launch → capture exit observed, median elapsed | Not collected | 1,566.53 ms |
| Frozen loopback Wikipedia: JavaScript startup scope, median elapsed | Not collected | 241 ms |
| Exact 20-sprite fixture, 800×600: document installation → first submitted document frame, median instructions | 22.560 billion | 2.364 billion |

| Chrome reference workload and endpoint | Median |
| --- | ---: |
| Frozen Wikipedia: FCP | 224 ms |
| Frozen Wikipedia: navigation → complete/fonts-ready CDP screenshot | 294.23 ms; 2.871 billion instructions |
| Frozen Wikipedia: process launch → complete/fonts-ready CDP screenshot | 1,443.51 ms; 10.459 billion instructions |
| Exact 20-sprite fixture: navigation → complete/fonts-ready CDP screenshot | 614.21 ms; 1.847 billion instructions |

Vox's capture-exit observation excludes later image cropping but includes observer polling and process termination. It provides an approximate process-launch comparison with Chrome's screenshot response, whose browser remains running. The frozen-page medians differ by about 8.5% in elapsed time (Vox 1,566.53 ms; Chrome 1,443.51 ms), but this does not establish FCP or page-rendering parity. Neither endpoint substitutes for a matched web-paint timing measurement. Chrome's incomplete descendant counters cannot establish which browser uses less total CPU.

The 20-sprite fixture uses the exact 51,190-byte Wikipedia sprite (SHA-256 `7990aaba48727a6b458090128a1ccc1a1529cdee1449600864cfb92336240753`) and no page scripts or network. Before the fix, one background used 2.202 billion install-to-frame instructions, while 20 identical backgrounds used 22.570 and 22.551 billion. The final three 20-background runs use 2.359, 2.365, and 2.364 billion. The median reduction is **20,196,306,313 instructions (89.521%)**, with all three PNGs byte-identical to the baseline. The sample concentrated in repeated nested document layout, renderer conversion, and SVG path/model work. The final one-background control uses 1.945 billion instructions; repeated backgrounds now add much less work.

The measured optimized binary has SHA-256 `a048fc388eaa900fa4cadda245cab0b4015c75524bc1529ed2d4618c5e917025`, recorded in `final-combined-build-v1-result.json`. All five capture-pipeline jobs pass: startup smoke, repeated SVG, one-SVG control, warmed Wikipedia, and frozen Wikipedia. All six Wikipedia globe crops match the upright source pixels exactly. No successful capture was sampled, and the hang monitor records no events. These captures validate the measured candidate. Canonical installation was then checked separately as described below.

A separate headless diagnostic of the frozen portal scripts found 66 native selector queries and 15 full-state snapshots totaling 6,631,667 bytes. Most work occurred while running the portal's 27,732-byte author script. An equality guard alone reduced that diagnostic's median native JS-scope instructions from 8.935 to 8.502 billion. This was one unoptimized test binary with alternating diagnostic modes, not the final optimized delta-replay implementation; those figures receive no production performance credit. Nested query/apply scopes overlap and cannot be summed. See `js-profile-summary.json`.

Repeating the diagnostic on the final source retains the same 66 queries and 15 flushes, but their snapshot payload falls from 6,631,667 to **9,935 bytes (99.85% less)**. Median diagnostic JS instructions are 2.655 billion. Remaining non-overlapping phases are host/state/bootstrap setup (0.841 billion), author scripts including native host calls (1.419 billion), readiness callbacks (0.141 billion), and final serialization/replay/cleanup (0.254 billion). This is unoptimized headless attribution, not an optimized production benchmark or a replacement for the measured 241 ms JS scope. See `js-final-profile-summary.json`.

Chrome for Testing `155.0.8059.79` was downloaded under `Build/wikipedia-performance/` and used fresh isolated profiles. The latest frozen-page comparison serves unchanged cached HTML and resource bytes over loopback, without network fallback. The HTML SHA-256 is `5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`; the screenshot document had 2,022 body-text characters and 21 sprite elements in all three runs. Loopback changes the script-visible origin, and the legacy cache does not retain response MIME metadata. Chrome's complete/fonts-ready screenshot and Vox's native first-frame submission are distinct endpoints. These results support a performance reference, not a parity assertion.

## Changes and behavior

- `dfc0992d`: share SVG background documents within their owning viewport. The cache compares exact response or local-file bytes and keeps URL fragments and color-scheme variants distinct. A replacement source creates a new document without changing references retained by earlier paint commands. A new viewport owns a new cache; no global document cache is introduced. Existing style/layout invalidation continues to handle changed resources and environments.
- `070f4adc`: consume completed HTTP SVG resources through the resource loader and preserve the fetched document URL for relative references. Reject failed responses, explicitly wrong content types, and invalid SVG documents. No network I/O is added to layout.
- `50527bae` and `98c4bb94`: connect compact Element selectors and identity to the native DOM and preserve specialized image/media facades. `c63bff07` and `208a9b8a` expose the owning Window's native Navigator identity and language data. `cf0ec6ff` connects Location components and document cookies to their native owners. These let Wikipedia reveal its localized content immediately instead of waiting for its one-second fallback.
- `4d7b9a04`: native raster-image requests reuse preloaded HTTP bytes while preserving conservative CORS/taint handling. `8b573697`: completed background SVG resources invalidate retained layout and paint, and screenshot capture waits for requested background resources to settle.
- `24626bff`: selector reads flush only pending element/control changes and operations, avoiding whole-document snapshots and repeated writes of unchanged class/style/title data. Logs remain available for final replay, and explicit empty attribute writes remain distinguishable from absent attributes.
- `b443a60e`: retain top-to-bottom raster scanline order in both native DOM bitmaps and the GG image cache, correcting the globe's vertical reflection. `69d3ca03`: asynchronous resource completion requests redraw from the retained drawable's owning window even when AppKit has no main or key window.
- `da2929c1`: avoid unused GG GPU/font initialization for the native Cocoa rendering path and route fallback primitives through the native renderer. This change receives **zero instruction-savings credit**: its isolated navigation-to-frame median regressed slightly (5.057 billion versus 5.031 billion). A separate adjacent-run GC diagnostic suggests the changed allocation pattern shifted collection work into the renderer; it does not establish statistical speedup or exact causal attribution. The lower diagnostic latency is not counted as a demonstrated end-to-end instruction improvement.

The compact script bridge remains partial. The measured build above completed Wikipedia's localization but still stopped in a later fundraising script at unsupported `document.getElementsByClassName`. Subsequent compatibility work exposes live class-name collections on the compact document and Element facades; see [the compatibility record](translation-audit/COMPACT_CLASS_COLLECTIONS.md). This does not change the performance measurements above. The browser continues to use JavaScriptCore. The native screenshot still has CJK glyph boxes and footer layout/icon differences from Chrome, so there is no whole-page pixel-equivalence claim. Cached remote-image bytes lack final response/CORS metadata: unverified cross-origin CORS-mode loads are rejected, and all decoded remote responses remain tainted for canvas readback, including apparently same-origin cache keys that could conceal redirects.

## Verified checks

| Scope | Verified result | Evidence |
| --- | --- | --- |
| Remote SVG loading and viewport-owned SVG sharing | 8 cases; 16,605 assertions passed | `svg-cache-focused-combined-result.json`, `svg-cache-focused-combined-boehm.log` |
| Native context lifecycle, fallback paint, and frame behavior | 13 cases across 3 test files passed | `native-focused-boehm.log` |
| Native Navigator host | 3 focused cases passed | `chrome-compare-navigator-test.log` |
| Integrated compact Element, cookies, Location, Navigator owner, remote image CORS, and resource invalidation | 11 focused cases passed | `integrated-new-v2-result.json` |
| HTML image request preserves fetch-reported CORS taint for an initially same-origin URL | 1 focused case passed | `chrome-cors-focused-result.json` |
| Final compact replay, Element, and lazy content access | 7 focused cases passed: replay 2, Element 3, content 2 | `final-js-focused-result.json` |
| Native DOM bitmap and actual image-cache raster orientation | 2 focused cases passed | `raster-orientation-v2-result.json` |
| Async native redraw with no main/key window | 1 focused case passed | `native-redraw-v2-result.json` |
| Optimized production build | Passed; binary `a048fc38…` | `final-combined-build-v1-result.json` |
| Production startup smoke and capture pipeline | 5 jobs passed; 3 repeated-SVG screenshots exact; all 6 globe crops upright/exact; no hang sampling | `final-capture-pipeline-results.json`, `final-capture-review-summary.json` |
| Broad functional regressions | 135 selected cases passed in each GC mode: CSS 31, SVG 10, layout 54, native 40; 270 executions / 230,534 assertions | `final-broad-consolidated-result.json` and per-job receipts |
| Full upstream LibJS AST corpus | 100 passed, 0 failed; exact comparisons | `final-broad-ast-result.json`, `final-broad-ast.log` |
| Broad screenshot regressions | 39 comparisons: 29 exact, 8 within existing fuzzy bounds, 2 unchanged baseline mismatches; all 8 required SVG mutations exact | Per-job screenshot receipts and baseline comparison proofs |
| Canonical bundle installation | Ad-hoc signature verified; installed startup passes; 800×600 sprite capture byte-identical to measured candidate | `installed-candidate-result.json` |

The installed bundle is `Build/v/Vox.app`, binary SHA-256 `e4b1da939ce9289dd74c6f20d6ccd626d0ce5bb983b999fa9856e45e0264b8e7`. Installation changes the private build-directory rpath to `Build/v` and ad-hoc signs the bundle; executable instruction bytes are unchanged (both `__TEXT,__text` SHA-256 values are `b019b7d73d03fe367e891e53a8614f38f9bb92d833fc1ab2bd47b17bd14bb46f`). Its independent startup and sprite capture pass, and Wikipedia was launched from the installed bundle. The prior task-owned app is backed up before replacement. These installation checks receive no additional performance credit.

Focused SVG, integration, and final JS/raster/redraw tests use Boehm with the standard unoptimized C test compilation, `LARGE_CONFIG=1`, and `GC_MARKERS=1`; production benchmark binaries use the normal optimized production build. The 3 Element cases overlap between the integrated 11 and final 7; the latter also reruns 2 existing content-access cases. These rows report scopes, not an additive unique-case total.

The 11-case integration fixture records source graph SHA-256 `303a0fe9d74463ea43138ca78474ecd200acc8bd3cf1c837fa8c5419cbde07ec`. The final combined runtime is pinned HEAD `607e3bfa8590373fbff3dd70a4dfa5801ca10da3` plus the task's three recorded source overlays; unfinished independent working-tree runtime edits are excluded. `final-combined-source-manifest.json` has SHA-256 `200386cf657e35e7cf334d43accf28e97f1fd12f2faa88a541f01ebfb7e74c19` and records every production input. The older `verified-build-source-manifest.json` describes an earlier candidate, not the final source. A source freeze alone is not a successful build or test result. Interrupted compile/test attempts receive no validation credit.

The unchanged reference failures are `svg-stroke-paintstyle-with-opacity` (3,460 differing pixels, maximum channel error 4, 3,200 outliers) and `svg-radialGradient` (2,160 differing pixels, maximum error 1, beyond its 1,509-pixel allowance). Both have exactly identical decoded pixels in the original baseline, intermediate v3, and final native captures. The opacity-stroke PNG files are also byte-identical. These remain known renderer/reference gaps; failed comparisons are preserved and no tolerance was changed. See `gradient-baseline-comparison.json` and `radial-gradient-baseline-comparison.json`. The 39 invocations include three repeated fixtures, so the unique-fixture counts are 26 exact, 8 fuzzy, and 2 unchanged failures.

The broad test input overlays include the existing background-helper callsite correction (`3d88268d`) and redraw test queue isolation (`12713a3b`). Both are test-only corrections; the production binary remains unchanged. Initial layout-harness compilation and disk-full native attempts are retained as failed evidence and receive no pass credit.

The final pinned HEAD also includes independently committed work since the original baseline. Whole-page before/after figures therefore describe the combined builds rather than an isolated A/B test of one commit; previously credited independent savings must not be counted again.

The completed broad batch verifies the matching 20-sprite saving of 20,196,306,313 retired instructions against the repository cadence. Additional measured savings after this batch: zero.

## Reproduction

Build and check the native production app using the normal optimized backend and collector:

```sh
sh build-prod-browser.sh
Build/v/Vox.app/Contents/MacOS/Vox --headless-smoke
```

The existing measurement tool captures the document viewport and reports native installation/first-frame instruction scopes. To repeat the warmed workload while the frozen cache artifacts are retained:

```sh
LADYBIRD_DEBUG_TIMING=1 python3 tools/measure_browser_instructions.py \
  --engine vox --binary Build/v/Vox.app/Contents/MacOS/Vox \
  --url https://wikipedia.org --repeat 3 \
  --cache-template Build/wikipedia-performance/cache-template \
  --output Build/wikipedia-performance/recheck
```

Investigation artifacts under `Build/wikipedia-performance/` are ignored build outputs. Exact historic comparisons require their frozen inputs, binary hashes, and endpoint definitions; a later live Wikipedia page is a different workload. The temporary Chrome for Testing download was removed after measurement to recover disk space; its version, URL, hashes, and measured reports remain recorded.

Primary evidence: `vox-baseline-summary.json`, `svg-repeat-before-compact-summary.json`, `native-startup-result.json`, `startup-gc-assessment.json`, `js-profile-summary.json`, `js-final-profile-summary.json`, `chrome-frozen-resume-summary.json`, `chrome-svg-repeat-20-summary.json`, `final-combined-source-manifest.json`, `final-combined-build-v1-result.json`, `final-capture-pipeline-results.json`, `final-capture-review-summary.json`, `final-broad-consolidated-result.json`, `installed-candidate-result.json`, `installed-wikipedia-launch-result.json`, and the successful test receipts listed above.
