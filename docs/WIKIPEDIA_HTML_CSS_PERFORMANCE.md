# Wikipedia without JavaScript

Wikipedia's cached 1024×768 first document frame now takes **301 ms median**, with all five measured runs between **295 and 347 ms**, after the [rendering optimization below](#rendering-follow-up-below-500-ms). That follow-up compares two JavaScript-disabled builds and preserves the rendered page.

The initial JavaScript policy experiment reduced median document-installation-to-first-frame time from **859 ms to 694 ms**, saving **165 ms (19.21%)**, in five alternating pairs on this Mac. The same rendering interval used **33.83% fewer CPU instructions**. JavaScript startup fell from 147 ms to zero; every disabled sample confirmed no runtime, source collection, or script preloads.

Vox renders HTTP(S) pages on `wikipedia.org` and its subdomains using HTML and CSS by default. The site list in `script/main_script_policy.v` is explicit; other sites retain their normal JavaScript behavior. The policy belongs to each navigation document, so leaving Wikipedia restores the destination site's policy.

The policy is installed before HTML parsing. Disabled documents do not create HTML/SVG script models, inline event-handler records, script-source collections, the JavaScriptCore runtime, or its host bindings. Script fetching, JavaScript parsing/evaluation, import-map processing, and script-driven rendering callbacks are skipped. HTML parsing still retains ordinary `<script>` elements and their raw text in the DOM. This does not claim zero HTML allocation or zero process memory.

`<noscript>` and Wikipedia's existing `no-js` CSS take their normal disabled-scripting paths. Wikipedia consequently exposes its static language list; the scripted and static layouts are intentionally different.

The launch overrides apply for the browser session:

```sh
Build/v/Vox.app/Contents/MacOS/Vox --enable-javascript https://www.wikipedia.org/
Build/v/Vox.app/Contents/MacOS/Vox --disable-javascript https://example.com/
```

## Measured results

These are medians of five fresh processes per mode, using the same optimized executable, native library, and initial cache bytes.

| Scope | JavaScript enabled | Default HTML and CSS | Change |
| --- | ---: | ---: | ---: |
| Document installation → first submitted frame | 859 ms | 694 ms | 19.21% less time; 1.24× speedup |
| Document installation → first frame, retired CPU instructions | 3,463,371,763 | 2,291,756,896 | 33.83% fewer |
| JavaScript startup | 147 ms | 0 ms | No JavaScript work |
| Collected script sources / bytes | 4 / 29,987 | 0 / 0 | None collected |
| Preloaded external scripts | 2 | 0 | None loaded |
| JavaScript runtime created | Yes | No | None allocated |

Rendering samples were 764, 859, 883, 871, and 818 ms with scripting enabled; corresponding disabled samples were 591, 776, 657, 694, and 745 ms. The host had substantial unrelated load, with one-minute load averages between 14.95 and 18.80 during these captures. CPU instruction scopes measure work inside the browser process and exclude GPU execution and WindowServer.

The broader native navigation-to-first-frame median was **4,914 → 4,359 ms (11.29% less time)**. That interval also includes earlier browser/native startup; it varied from 4,178 to 10,053 ms in the enabled samples and 3,199 to 5,247 ms in the disabled samples. This is a diagnostic launch result, separate from the rendering interval above. All ten capture logs contain exactly one document installation, so later refreshes did not substitute another page for the measured one.

All five disabled runs reported `enabled=false runtime=false sources=0 source_bytes=0 preloaded_scripts=0`. The 0 ms JavaScript timer is rounded to milliseconds; the runtime/source/preload records independently establish that the JavaScript path was skipped. Both variants render the globe, wordmark, ten prominent languages, and search form. The disabled variant also displays Wikipedia's full static language list. This is a functional HTML/CSS view, rather than a claim of pixel equivalence to the scripted layout.

The measured executable SHA-256 is `9787a04d5bfb1be82420759ad4b9a766fdcb253fd5dee7606ffa42fb5fba3687`; its native library is `46f0a3f9fa2e4cac09af21502d076ca7c3b1369ff84b6c1a5694e6c4f610a2cd`. Every sample used initial-cache fingerprint `46c277c0b7df22c8b1d5c1c00d55b1a2548750e7257cbe04f0b927de9ce8e5fd`. The signed optimized Boehm build completed successfully; canceled earlier build attempts receive no measurement credit. Primary evidence is `paired/summary.json`, `paired-benchmark-command.json`, `paired-benchmark-result.json`, `after-build-result.json`, and `after-source-hashes.json` under the task's build directory.

## Measurement method

The primary comparison uses one optimized production executable for both modes: `--enable-javascript` reproduces the prior Wikipedia policy, and the default selects HTML and CSS. This isolates the policy from unrelated concurrent workspace changes. Each mode runs five times, alternating order between pairs, with a fresh process and a fresh copy of the same initial HTML/resource cache. The viewport is 1024×768 logical pixels. Cached viewport screenshots are removed and snapshot reuse is disabled.

The endpoint is Vox's native navigation to the first submitted document frame. The document-installation timer excludes earlier native window initialization. Both timers exclude subsequent screenshot capture and process teardown; neither is the web Performance API's FCP. If a background revalidation installs another document before capture, the measurement driver retains the first document's timings and reports the number of installations. Network refresh remains enabled, so the experiment freezes initial cache inputs rather than claiming a network-isolated or cold-load test.

The frozen portal HTML is 122,197 bytes with SHA-256 `5c0de7d8a1af1dc8c06cc2a517265ff96db0ed11114a62be2625ed13c9cdb466`. Eight resources were fetched over HTTPS and verified byte-identical before retaining their actual final URLs as cache redirect provenance. The input includes both external scripts, allowing the enabled variant to load the unchanged script bytes while the default variant skips them. Full logs, screenshots, cache fingerprints, executable/library hashes, source manifests, and per-sample JSON are retained under `Build/wikipedia-html-css/`.

## Reproduction

Build with `sh build-prod-browser.sh`. To prepare a new warm cache, use the enabled override so it includes the scripted comparison's resources:

```sh
mkdir -p Build/wikipedia-html-css/recheck-cache
LADYBIRD_CACHE_DIR="$PWD/Build/wikipedia-html-css/recheck-cache" \
  LADYBIRD_SCREENSHOT_DELAY_SECONDS=0 \
  Build/v/Vox.app/Contents/MacOS/Vox --enable-javascript \
  --window-width 1024 --window-height 880 \
  --screenshot "$PWD/Build/wikipedia-html-css/recheck-warm.png" \
  https://www.wikipedia.org/

python3 tools/measure_browser_render.py \
  --before-binary Build/v/Vox.app/Contents/MacOS/Vox \
  --after-binary Build/v/Vox.app/Contents/MacOS/Vox \
  --before-arg=--enable-javascript \
  --cache-template Build/wikipedia-html-css/recheck-cache \
  --repeat 5 --output Build/wikipedia-html-css/recheck
```

The driver rejects changed initial-cache hashes and executable/library changes within or between samples. Four focused driver tests check first-document attribution across refreshes, native timing/instruction medians, changed-input rejection, and unavailable instruction counters:

```sh
python3 tools/measure_browser_render_test.py
```

## Verification

- 89 selected browser checks pass, including disabled script fetching, invalid
  JavaScript left inert, CSS geometry, Page preference precedence, and runtime
  creation/disposal across navigation and explicit overrides.
- 100 HTML checks pass with both Boehm and `-gc none`, including HTML/SVG scripts,
  fragments, inline handlers, speculative requests, module preloads, and
  `javascript:` navigation. The no-GC run caught an invalid test cast in an XML
  fixture; setting that fixture to HTML and checking namespaces fixed the test.
- All 100 upstream LibJS AST fixtures compare exactly, without case overrides.
- All 11 default screenshot smoke cases pass with existing tolerances. All eight
  required live SVG/image mutation comparisons are pixel-exact. No tolerance
  changed.

The selected browser batch excludes the pre-existing
`document/main_document_creation_test.v` fixture, which still calls a removed four-argument
browsing-context creation API. This is selected regression coverage rather than
a claim that every repository test was run. Receipts and exact combined test
inputs are retained under `Build/wikipedia-html-css/` alongside
`root-regression-result.json`, `html-regression-manifest.json`,
`ast-corpus-result.json`, and `screenshots-result.json`.

## Installed bundle

`Build/v/Vox.app` was rebuilt afterward to include the independent adblock updates
present when that build started. Its installed executable SHA-256 is
`d14460feaa815133bec1b39c21b9193543e69e33482aa00c26637dfdc1b5f326`.
The native library path was relocated to `Build/v`, and the app was ad-hoc signed
and signature-verified. Relocation preserved the later candidate's executable
code bytes. Both supported startup smoke modes pass; this does not change the
documented LibJS DOM/runtime limitations.

The installed bundle reports the same zero-script diagnostics on Wikipedia, and
its 1024×768 document screenshot is byte-identical to measured `after-5.png`
(zero differing pixels). These installation checks receive no additional
performance credit: the headline comparison remains pinned to the measured
executable above. See `installed-build-result.json`,
`installed-validation-result.json`, and `installed-screenshot-result.json` in the
task's build directory. The previous executable and native library are backed up
under `Build/wikipedia-html-css/bundle-before-install/`.

## Rendering follow-up: below 500 ms

Five alternating pairs of JavaScript-disabled production builds measured **820 → 301 ms**, a **519 ms (63.29%)** reduction and **2.72×** speedup. Every optimized sample met the 500 ms target. These are new matched-build measurements, separate from the earlier JavaScript-enabled comparison above.

| Native scope | Before | After |
| --- | ---: | ---: |
| Document installation → first submitted document frame | 820 ms | 301 ms |
| Resource preload interval | 629 ms | 69 ms |
| Document parsing/setup | 32 ms | 31 ms |
| Layout interval | 131 ms | 180 ms |
| First paint replay | 18 ms | 19 ms |
| Rendering interval, retired CPU instructions | 2,096,516,346 | 3,363,621,620 |
| Native navigation → first submitted document frame | 1,095 ms | 568 ms |

Document-installation-to-first-frame samples, in pair order:

| Pair | Before | After |
| --- | ---: | ---: |
| 1 | 871 ms | 295 ms |
| 2 | 820 ms | 311 ms |
| 3 | 657 ms | 296 ms |
| 4 | 697 ms | 301 ms |
| 5 | 1,102 ms | 347 ms |

The rendering endpoint is unchanged: document installation through the first submitted document frame, excluding earlier native startup, later screenshot capture, and process teardown. This is a cached rendering measurement, not a cold network load, web FCP, or a guarantee that complete browser launch finishes within 500 ms. The one-minute host load average ranged from 18.16 to 19.71. No builds, test compilations, or other screenshot captures owned by this task ran during these pairs.

The main delay was waiting for image downloads inside Wikipedia's closed donation dialogs. Two badge images were absent from the unchanged initial resource cache, so their live HTTPS requests held up the visible portal. JavaScript-disabled pages now install their styles and viewport first, then distinguish HTML images under computed `display:none` ancestors from images needed by the first frame. Hidden images still start downloading eagerly through the existing resource request path; their transfers finish in the background. Visible images remain foreground work. This does not enable HTML lazy loading when scripting is disabled, omit requests, change adblock policy, or reuse a raster snapshot.

The resource plan conservatively retains foreground loading for URLs also used by visible elements, CSS, SVG, responsive image candidates, or other resource roles. Author shadow roots retain the foreground path for all resource URLs. A hidden image that becomes visible before its response completes triggers layout and paint invalidation on completion. An image that remains hidden does not cause an unnecessary layout rebuild. Separately, text consumers that do not wrap no longer initialize the Unicode line segmenter merely to enumerate text chunks.

This is a latency improvement. The measured first-frame instruction scope **increased by 60.44%**; no CPU reduction is claimed for this follow-up. Additional style/resource classification and asynchronous downloading trade more work before the frame for less time waiting on hidden transfers. Downloads can continue beyond the measured first frame, so this instruction scope also does not measure total page-load CPU work.

All ten runs reported `enabled=false runtime=false sources=0 source_bytes=0 preloaded_scripts=0` and exactly one document installation. Every optimized screenshot is byte-identical to before samples 1 and 3, with zero differing pixels across the full 1024×768 document viewport. The baseline contains two image hashes (two and three samples); all five optimized images share the first hash. Direct pair comparisons are exact for pairs 1 and 3. Pairs 2, 4, and 5 differ at 1,716 pixels within the native search-field focus border/caret rectangle, `x=287, y=472, width=394, height=44`, and have zero differences outside it. These are the same two focus states already present in earlier captures; the portal content is unchanged.

Both variants used fresh copies of the same eight-resource initial cache, fingerprint `46c277c0b7df22c8b1d5c1c00d55b1a2548750e7257cbe04f0b927de9ce8e5fd`. The missing badge responses were not added to the template. Background revalidation remained enabled and raster snapshots remained disabled. Each sample launched a fresh process; pair order alternated before/after and after/before. The native replay library was identical in both variants.

The before executable SHA-256 is `8d06779203c63a58fb2a1f9614d0e38116207a6b5c9ea29150eed9fb6ece7b5e`; the after executable is `cca5ad8cd4a8ec505446505136768c5851dd1a9efbf010e45e0312b7e22ed7de`. Both use library `46f0a3f9fa2e4cac09af21502d076ca7c3b1369ff84b6c1a5694e6c4f610a2cd`. The source manifest starts at `b40f8cd6ab216e49b695fd74d2807804dfff6cfb`: 5,497 baseline files remain identical, three files changed, and four resource implementation/test files were added. The implementation is committed as `d1165164` and `9e4db022`.

Evidence is retained under `Build/wikipedia-nojs-500/`: `paired/summary.json`, all ten sample logs/JSON/screenshots, `paired-benchmark-command.json`, `paired-benchmark-result.json`, `paired-visual-verification.json`, both literal source manifests, and both successful build receipts. The earlier installed-binary diagnostic and single candidate pair receive no credit in these results. Reproduce with the existing measurement driver and the preserved binaries:

```sh
python3 tools/measure_browser_render.py \
  --before-binary Build/wikipedia-nojs-500/baseline/Vox \
  --after-binary Build/wikipedia-nojs-500/candidate/Vox \
  --before-arg=--disable-javascript \
  --after-arg=--disable-javascript \
  --cache-template Build/wikipedia-nojs-500/cache-template \
  --repeat 5 --width 1024 --height 768 \
  --output Build/wikipedia-nojs-500/recheck
```

Focused validation covers 20 distinct resource-plan, initial-image, adblock, and SVG-completion cases. The final three initial-image cases and three SVG cases pass in `Build/wikipedia-500/completion-result.json`; the unchanged eight plan and six adblock cases retain their passing results from `preload-regression-result.json`. The completion fixture declares image dimensions, matching Wikipedia's badges. The literal measured snapshot retains the earlier test fixture; this dimensions-only test correction does not alter compiled production code. Pre-existing remote raster intrinsic sizing without ImageHost remains outside this change. No-wrap text tests also pass. All eight required live SVG/image mutation screenshot comparisons are pixel-exact on the measured candidate, with unchanged inputs; see `svg-validation-result.json`. This selected coverage does not claim the full repository test suite passed.

The installed bundle contains the measured candidate's identical native `__text` bytes after library-path relocation. Its executable hash is `4a2630310f5eff8481318d9b7c0769bb56df2faa973e9a8632c3cbb2bd15f5c0`; signature verification and both supported startup smoke modes pass. These checks are recorded in `installed-validation-result.json` and receive no extra performance credit. The browser still uses JavaScriptCore for pages with scripting enabled; the existing LibJS runtime limitations remain.
