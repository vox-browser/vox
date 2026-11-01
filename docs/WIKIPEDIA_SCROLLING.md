# Wikipedia Main Page scrolling

The target for `https://en.wikipedia.org/wiki/Main_Page` remains smooth 60 fps. The current changes reduce repeated native raster work and preserve the tested pixels, but the live and contended precise-wheel measurements have not established that target. These measurements count changed Cocoa layer contents after `updateLayer`, including scroll-position changes; they do not measure physical display scanout.

The native renderer now transfers fractional rectangular borders as edge strips, reuses eligible CPU glyph masks by Skia's exact packed mask phases, transfers small compositor controls through compact regions, and skips redundant GPU work for transparent shapes. Long thin scrollbars keep the compact transfer path. Lossless glyph-backdrop snapshots retain roughly twice as many entries within the existing 64 MiB text-cache budget; every hit still compares the complete input pixels. A larger 128 MiB budget and GPU batching were tested and rejected because neither gave consistent frame-timing gains.

The frozen page uses the original HTTPS URL and archived response bytes, without network forwarding. Every launch has an empty private profile, an independent cache, the default Wikipedia script policy, a 1024×764 document viewport at 2× scale, and 12 seconds settling after a matching title. Throughput includes the entire first-to-last input window. Reports include actual wheel delivery, leading/trailing stalls, scroll intervals and deadline misses. Continuous-forward and oscillating inputs are separate workloads. Other repository sessions ran compilers and browsers during these measurements; changing controls limit timing attribution.

| Workload and measured build | Mean scroll-changing publications/s, both trials | p95 scroll interval |
| --- | ---: | ---: |
| Frozen oscillating 60 Hz input, cohort 10 control | 48.25 / 50.33 | See full interval distributions |
| Frozen oscillating 60 Hz input, cohort 10 candidate | 58.61 / 57.00 | Deadline misses remain |
| Earlier live Main Page, continuous nominal 120 Hz input | 46.03 / 52.24 | 32.71 / 29.90 ms |
| Updated native libraries on the last working executable, live continuous input | 57.86 / 46.73 | 27.11 / 32.44 ms |
| Latest installed production bundle, live continuous input | 28.00 / 28.94 | 55.07 / 53.76 ms |
| Frozen continuous nominal 120 Hz input, final compressed-cache control | 41.80 / 24.88 | 36.79 / 62.33 ms |
| Frozen continuous nominal 120 Hz input, final compressed-cache candidate | 35.15 / 26.62 | 45.07 / 57.78 ms |

The compressed-cache comparison demonstrates cache retention and pixel correctness; the timing cohort does not establish a reliable FPS improvement. All attempts and regressions are retained. Instrumented cache counters and conversion microbenchmarks do not supply scrolling performance credit. Isolated native-cache candidates preserve the page pixels at matching end scroll positions with zero differences. Those comparisons do not isolate all the other changes in the latest shared production bundle. Focused native tests cover fractional glyph positions, backdrop changes and padding, cache bounds and eviction, transparent compositing, original GPU tile geometry and ownership, and long scrollbar transfers. Startup smoke checks cover DOM events and native wheel routing.

[Committed measurement receipts](benchmark-results/wikipedia-main-scroll-20261101.json) retain cohort summaries, exact commands, executable/library/probe identities, host loads and exits. [Full local evidence](../Build/wikipedia-main-scroll-20261101-043231/report.md) includes every cohort, rejected experiment, protocol limitation and raw-log location. The native changes are commits `c51a8df9`, `f572d47a`, `270aeea8`, `7e9d1935`, `39a324e9` and `43241262`, with distant-boundary regression coverage in `1414526a`.

A new shared production executable crashed before navigation because the stationary-document cache dereferenced the initial absent document. Commit `962b53ba` adds a guard and a passing focused regression test. The completed shared production build includes that guard; a duplicate build was not queued. Fresh installed startup, headless smoke, original-renderer GPU comparisons and both live runs pass their functional checks. The installed live trials run at only 28–29 fps, with every scroll interval over budget, while host load rises from 24.5 to 51.2 on 18 CPUs. They cannot establish a smooth 60 fps fix or isolate a code regression. The receipt records unrelated inputs that changed during the shared build, as well as the stable sources for these fixes.

## Historical portal profiling

The earlier results below concern `https://www.wikipedia.org/`, a different document and a synthetic draw-callback workload. They do not establish the Main Page's native scrolling FPS.

The shipped change bounds native SVG-mask and opacity transparency layers before replaying their children. Wikipedia's sprite backgrounds previously replayed many opacity groups whose output was outside the embedding clip. Effect commands now retain the clip active at their scope, before descendant clips; mask layers likewise use their mask bounds. A small fringe preserves fractional antialiasing. Filter inputs retain their independent offscreen contexts.

Three comparable 120-wheel-event sweeps of the retained Wikipedia portal produced these medians of run medians:

| Timed scope | Control | Shipped fix | Reduction |
| --- | ---: | ---: | ---: |
| Native paint replay | 37.455 ms | 21.881 ms | 41.6% |
| Wheel dispatch, preparation and replay | 76.948 ms | 61.634 ms | 19.9% |
| Moving-frame scope, 95th percentile | 117.203 ms | 106.074 ms | 9.5% |

Each run contains 44 events that move the viewport and 76 boundary events. The observer reports both populations and retains slow frames. Comparisons require identical URL, initial cache hash, viewport, raster mode, scroll positions and paint-command counts. The final comparison also verifies identical native replay-library bytes. Both variants use the same frozen source except the early clipping calls, production C `-O2`, Boehm, JavaScriptCore with page JavaScript enabled, and a 1024×768 document viewport at the native display scale.

These timings cover software GG wheel delivery through native replay inside the browser frame callback. Cocoa layer publication, display waits, GPU execution and post-paint idle maintenance are outside that scope. The input HTML and initial cache are retained; legacy external donation-badge requests remain possible.

Garbage collection during replay-vector allocation remains a source of stalls. A separate attempt to transfer layer-free replay vectors passed its focused tests but increased the measured median scope to 95.129 ms. Commit `ff31f3da` was reverted by `eebbd10e`; that experiment is excluded from the shipped result.

Verification covers the focused effect-bound tests with Boehm and `-gc none`, existing visual-layer and replay tests, 16 native pixel scenes plus empty/disjoint clip restoration, ASan/UBSan, and four observer checks. Eight upstream mask/clip/filter input pages retain exactly the control's viewport pixels on the matched runtime. Seven retain existing differences from their upstream expected/reference images. Signed startup and live Wikipedia capture also pass. This is one completed rendering fix toward the repository's ten-fix broad-test cadence; tooling, documentation and the reverted experiment add no shipped fixes.

The tested snapshot is installed at `Build/v/Vox.app`, with its replay library embedded beside the executable. Relocation preserves every Mach-O `__TEXT` section and the exact replay-library bytes. The previous bundle is preserved at `Build/scroll-performance/pre-install-Vox.app`. Concurrent source changes remain in the workspace.

Reproduce a live profile with a fresh output directory:

```sh
python3 tools/measure_browser_scroll.py \
  --url https://www.wikipedia.org/ \
  --output Build/wikipedia-scroll-new-run
```

Use `--sample-seconds 3` for a native stack sample and `--compare-to PATH/summary.json` to enforce comparable inputs. `--capture` selects the separate logical-pixel screenshot mode.

Evidence under `Build/scroll-performance/`:

- `shipped-comparison.json` and `matched-{before,after}-{1,2,3}/`: the accepted comparison and raw frames.
- `control-source-manifest.json`, `matched-source-delta.json`: source snapshot and isolated clipping changes.
- `matched-regressions-{baseline,candidate}/results.json`: all eight render comparisons.
- `installation.json`, `installed-smoke.log`, `installed-live/`: installed artifact verification.
- `remaining-profile/sample.txt`: allocation/collector attribution after clipping.
- `rejected-vector-transfer-evaluation.json`: rejected experiment and its preserved measurements.

Earlier probes with differing command traces or native libraries remain diagnostic records and receive no shipped performance credit.
