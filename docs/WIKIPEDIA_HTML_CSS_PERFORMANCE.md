# Wikipedia without JavaScript

Wikipedia's median document-installation-to-first-frame time fell from **859 ms to 694 ms**, saving **165 ms (19.21%)**, in five alternating pairs on this Mac. The same rendering interval used **33.83% fewer CPU instructions**. JavaScript startup fell from 147 ms to zero; every disabled sample confirmed no runtime, source collection, or script preloads.

Vox renders HTTP(S) pages on `wikipedia.org` and its subdomains using HTML and CSS by default. The site list in `main_script_policy.v` is explicit; other sites retain their normal JavaScript behavior. The policy belongs to each navigation document, so leaving Wikipedia restores the destination site's policy.

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
`main_document_creation_test.v` fixture, which still calls a removed four-argument
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
