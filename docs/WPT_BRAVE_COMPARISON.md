# WPT: Vox vs Brave

Conformance and per-test timing on Ladybird's imported web-platform-tests,
run with `tools/wpt_compare.py`. Manifest:
[performance/wpt-brave-20261106.json](performance/wpt-brave-20261106.json);
raw results, request log and browser logs stay in `Build/wpt-brave-20261106c`.

## Workload

- 3,808 testharness tests: every expectation under Ladybird
  `Tests/LibWeb/Text/expected/wpt-import` (`963d46a829f3`) that resolves to a
  document (`name@query` expectations name `?query` variants; 14 resolve to none).
- A local static server serves `Text/input/wpt-import` as the WPT root with
  `.headers` files, a small `.sub.` subset and `Cache-Control: no-store`. It has
  no wptserve Python handlers, so tests that need them fail in both browsers.
- `testharness.js` is served with Ladybird's CI edits reverted: 10 s/60 s
  harness timeouts instead of 150 s/300 s, and no `globalThis.internals`
  shortcuts. Vox exposes `window.internals` to pages. With the vendored harness
  it threw before defining any globals, and it would also have skipped assertion
  messages that Brave formats.
- The served `testharnessreport.js` turns off the result table (as wptrunner
  does), posts each top-level result and sets `location.href` to the next test.
- Each launch uses a fresh private profile, a 1024×768 window and an unrecorded
  warm-up page. Chunks of 100 tests alternate which browser runs first.
- Builds:
  - Vox `ed12977224de` (single C unit, receipt `20261106-173314-1b41aca8`),
    held under the shared bundle lease and rehashed before every launch.
  - Brave 156.1.98.60.
- One pass, 18:06–19:19 on 2026-11-06, 18-CPU host. Load averages were 14.2
  falling to 6.2, with other sessions active.
- Per-test time runs from the server receiving the test document request to
  receiving the result post. It excludes browser startup and includes
  subresource loads, script execution, the harness and one XHR.

## Conformance

| | Vox | Brave |
|---|---:|---:|
| Harness OK | 3,415 | 3,767 |
| Harness ERROR | 97 | 16 |
| Harness TIMEOUT | 228 | 18 |
| Harness never started | 48 | 0 |
| Browser exited | 13 | 0 |
| Browser over 4 GiB RSS | 7 | 1 |
| Other runner outcome | 0 | 6 |
| Tests with every subtest passing | 1,213 | 3,192 |
| Subtests passing | 61,729 / 129,952 (47.5%) | 172,368 / 182,388 (94.5%) |
| Launches | 106 | 46 |
| Suite wall clock | 3,815 s | 567 s |

Most of Vox's wall clock is spent waiting on harness timeouts: 3,095 of its
3,815 s.

## Timing

Ratios are Vox/Brave; above 1 means Vox is slower.

| Set | Tests | Vox | Brave | Total ratio | Geomean | Median | p10–p90 | Vox faster |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| Both harness OK, no timeouts | 3,404 | 251.2 s | 106.2 s | 2.36× | 2.34× | 2.46× | 1.45–3.72 | 171 |
| Identical subtest results | 1,306 | 74.5 s | 34.2 s | 2.18× | 2.33× | 2.44× | 1.63–3.12 | 24 |

The second row is the like-for-like set: both browsers produced the same
subtest names and statuses. In the first row Vox often fails early, which
shortens its work.

Vox's cost is mostly a fixed overhead per test document. The median clean test
takes 35.7 ms in Vox and 14.5 ms in Brave; the fastest take 24.9 ms and 9.5 ms.
On identical-result tests:

| Brave time | Tests | Vox/Brave total | Median Vox − Brave |
|---|---:|---:|---:|
| < 20 ms | 1,050 | 2.61× | +19.0 ms |
| 20–50 ms | 223 | 1.87× | +17.9 ms |
| 50–200 ms | 20 | 1.27× | +12.8 ms |

Timer, XHR and `load` callbacks are woken by run-loop sources, not by frames.
Page installation and the `load` event, however, run inside the on-demand
`draw()` pass. The source of the roughly 19 ms has not yet been measured.

Outliers on identical results:
- `streams/piping/general-addition.any`: 228 vs 11 ms.
- `css/css-logical/logical-box-*`: 115–156 vs 19–25 ms.
- `css/css-flexbox/relayout-align-items`: 141 vs 19 ms.
- `css/selectors/invalidation/*-pseudo-containing-complex-in-has`: 80–95 vs 14 ms.
- `html/rendering/replaced-elements/svg-embedded-sizing/svg-in-iframe-*`:
  6.1–8.9 s vs 1.6–1.9 s.

Vox has lower totals in three directories, but only because it fails slow
subtests quickly. For example, `scroll-animations/scroll-timelines/effect-updateTiming`
passes 0/67 subtests in 54 ms, against Brave's 772 ms. Restricted to
identical-result tests, Vox is slower in all three:

| Directory | All clean tests | Identical-result tests |
|---|---:|---:|
| `scroll-animations` | 0.43× | 2.25× (6 tests) |
| `streams` | 0.64× | 1.07× (7 tests) |
| `IndexedDB` | 0.76× | 1.74× (9 tests) |

## Vox defects found

### Crashes

The browser exited on these tests:
- `compression/decompression-empty-input.any`
- `css/css-values/if-conditionals`
- `css/filter-effects/animation/filter-interpolation-003`
- `css/selectors/invalidation/not-002`
- `dom/events/scrolling/scrollend-event-fired-for-scroll-attr-change?include=subframe-scrollTop-smooth`
- `dom/nodes/Node-replaceChild`
- `dom/nodes/moveBefore/Node-moveBefore`
- `dom/nodes/moveBefore/object-crash-regression`
- `editing/plaintext-only/insertLineBreak?white-space=pre`
- `html/browsers/history/the-history-interface/history_forward_cross_realm_method`
- `html/browsers/origin/api/origin-from-global.any`
- `html/canvas/element/text/2d.text.draw.baseline.ideographic`
- `html/infrastructure/urls/resolving-urls/query-encoding/attributes.sub?encoding=windows-1252`

### Runaway memory

The process group exceeded 4 GiB on these tests:
- `css/css-grid/computed-grid-column`: over 3.7 GiB within about 2 s in
  isolation, and over 12 GiB in the first full attempt.
- `html/semantics/embedded-content/the-img-element/img.complete`
- `html/semantics/forms/the-select-element/customizable-select/selectedcontent`
- Four `html/syntax/parsing/html5lib_*` variants.

### Scripts that never run

- Vox does not run scripts in standalone SVG documents: 43 of the 48
  never-started tests.
- Four HTML tests and one XHTML test (`xml-stylesheet-blocking`) also never
  started the harness.
- Script execution in XHTML documents is inconsistent.
  `dom/nodes/Element-firstElementChild-namespace-xhtml` ran its scripts in one
  smoke run and in the full run, but not in another smoke run.

### Navigation APIs

- `location.replace()`, `location.assign()` and `HTMLFormElement.submit()` are
  undefined.
- Assigning `window.location` does not navigate; only `location.href` does.

### Caching and globals

- Vox reuses `testharness.js` and other subresources across navigations despite
  `Cache-Control: no-store`. Brave fetches them for every test. This favours Vox
  slightly in the timings above.
- Pages see a non-standard `window.internals` object.

## Caveats

- Single unprofiled pass. The sets are large, but host load was high and varied,
  and alternating chunks only offsets drift.
- Runner artifacts in Brave:
  - Four `navigation-api` tests recorded NO_DOCUMENT: the preceding test's
    navigation handlers intercepted the runner's move to the next test.
  - `url/a-element-origin` and `css/css-values/urls/resolve-relative-to-base.sub`
    did not report.
  - `xhtml-mathml-dtd-entity-3` exceeded the summed 4 GiB RSS, which counts
    shared pages once per helper.

  None of these are in the timing sets.
- Ladybird's import is a subset of WPT that tracks Ladybird's own work.
  Pass rates are not representative of all of WPT.

## Rerun

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py --lock Build/wpt-brave-UNIQUE.lock \
    --report Build/wpt-brave-UNIQUE-guard.json --timeout 14400 -- \
  python3 tools/wpt_compare.py --output Build/wpt-brave-UNIQUE --chunk-size 100
```

Use `--include css/css-grid` (repeatable), `--limit N` or `--browsers vox` for
focused runs. The full suite takes about 75 minutes, most of it Vox harness
timeouts.
