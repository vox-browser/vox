# Wikipedia Main Page scrolling

The installed production build now exceeds 60 scroll-changing native publications/s on `https://en.wikipedia.org/wiki/Main_Page`, with p95 intervals inside the 16.67 ms frame budget in both final live trials. These measurements count changed layer contents after `updateLayer`; physical display scanout is unmeasured. Occasional longer intervals and an initial publication delay remain. Earlier failures and regressions are retained below.

| Final installed live trial | Scroll publications/s | Median / p95 / max interval | Intervals over 16.67 ms | Inputs / total publications |
| --- | ---: | ---: | ---: | ---: |
| 1 | 80.21 | 12.28 / 15.68 / 25.10 ms | 3.90% | 600 / 622 |
| 2 | 84.11 | 11.72 / 14.81 / 25.88 ms | 3.09% | 600 / 616 |

The full first-to-last input windows are 7.343 / 6.932 seconds, containing 589 / 583 scroll-changing publications after the reference sample. Actual input delivery is 81.57 / 86.41 Hz against a nominal 120 Hz timer. Leading publication gaps are 44.16 / 43.60 ms; the first counted scroll changes arrive at 69.26 / 69.48 ms. Trailing scroll-publication gaps are 0.08 / 0.50 ms. Idle-tail publications are retained in the raw totals and excluded from input-window throughput. The host has 18 CPUs; load averages rise from 7.94 to 8.59 and from 8.47 to 9.07 during these trials.

The installed executable SHA-256 is `7475d146a1eab27f54a0dc6bb626ecb41f43513442ea2317c6b458ac0564aa53`; its Metal renderer is `49ad49d0e9c938be19badcd8996f233ff87f687466b6a373adb6f65d303acdaa`. The final renderer uses the official production compile command from the canonical checkout. The existing completed V executable is retained and the bundle re-signed; this queue adjustment changes only the native renderer. Fresh installed processes and a short production-lock hold keep the artifact stable throughout final validation. One earlier trial invalidated by a concurrent bundle replacement is preserved without acceptance credit.

An actual V `-profile -profile-no-inline` build identified repeated paint-command copies, per-leaf settings queries, viewport ink reconstruction, duplicate wheel hit testing and native raster work. Its counters were reset immediately before the first precise wheel input and snapshotted after the final dispatch. Startup and publication-tail counters were retained separately, and executable symbols were resolved against the real Mach-O executable rather than injected image zero. Instrumented timings receive no scrolling FPS credit.

The follow-up fixes reuse the frame viewport origin, retain local ink rectangles across scroll recordings, borrow paint-command arguments, reuse exact cached image subregions, retain the Metal queue for 256 completed frames, reuse wheel hits only when callbacks cannot change them, clear a fresh private document bitmap directly, restrict native redraws to document canvases and their hosts, and cull cached rectangles without creating full paint commands. Every raster hit still checks the original geometry and complete relevant input pixels. The default automatic Wikipedia policy leaves its author-script runtime uninitialized; these results cover that shipped policy. The rectangle change has a small timing delta relative to control variation, so no separate FPS improvement is attributed to it. Whole-viewport scroll raster reuse remains ineligible on this page.

| Matched frozen continuous-input comparison | Control publications/s | Candidate publications/s | Candidate p95 interval |
| --- | ---: | ---: | ---: |
| Metal queue: 8 versus 64 completed frames | 69.47 / 68.48 | 86.73 / 81.11 | 15.41 / 16.28 ms |
| Guarded wheel hit reuse | 77.83 / 72.34 | 79.11 / 78.69 | 16.31 / 16.58 ms |
| Direct fresh-document clear | 58.62 / 63.15 | 63.59 / 65.40 | 20.97 / 19.36 ms |
| Native redraw: 47 views versus canvas/host | 72.16 / 74.06 | 86.25 / 82.96 | 15.77 / 15.90 ms |
| Direct cached-rectangle culling | 87.93 / 83.82 | 89.45 / 85.85 | 15.07 / 15.69 ms |
| Metal queue: 64 versus 256 completed frames | 86.35 / 85.94 | 92.46 / 92.95 | 14.23 / 14.01 ms |

Each comparison alternates control/candidate/candidate/control in fresh processes, with 600 precise wheel inputs nominally at 120 Hz, delta 1, continuous forward motion, a 1024×764 document viewport at 2× backing scale, independent empty profiles/caches and 12 seconds settling after a Wikipedia title. The frozen archive is replayed at the original HTTPS URL without forwarding. OS filesystem and GPU driver caches are retained; private browser profiles and caches are independent. Native throughput includes the full first-to-last input period. The receipts retain actual delivery cadence, median/p95/maximum intervals, budget misses, boundary gaps, counts, host load and identities. Different cohorts cannot establish isolated incremental gains because the shared source and host load changed.

Two live trials on the clean production build after the direct-clear change still measured 57.89 / 75.88 publications/s, with p95 intervals of 24.13 / 18.09 ms. These failures are retained; frozen results do not establish the live target. The next installed build reached 89.92 / 84.66 publications/s, with p95 intervals of 15.57 / 16.86 ms. Its second trial still missed the p95 budget. Phase analysis identified a recurring slow frame every 64 completed GPU frames: roughly 21 ms, against a 10.85 ms median frame. The final queue adjustment reduces those retirements to once every 256 completed frames.

Focused native tests, sanitizers, actual V test execution, unchanged full-page pixels and production startup checks cover the accepted changes. The GPU replay tests retain exact pixels, including thousands of generated cases. A 4,000-frame/24,000-readback Metal memory test for each library keeps the same 512 MiB peak, 64 MiB sustained-growth and 128 MiB post-cleanup limits for both queue lifetimes; both pass after asynchronous driver cleanup. For the final 64/256 comparison, peak process footprints are 353,665,672 / 378,634,912 bytes; the final median stays at 336,544,392 / 336,331,400 bytes and idle footprint drops to 20,234,888 / 16,466,568 bytes. A separate same-process exact-pixel test gives the control queue a unique Objective-C class name so the two implementations remain distinct; timing and memory trials each load one ordinary class in a fresh process. Initial premature idle samples and all rejected experiments are retained. Larger raster caches, an additional cache index, oversized recorders, white GPU no-op drawing and repeated white clears were removed after inconsistent gains or no use during scrolling.

[Follow-up profile and measurement receipts](benchmark-results/wikipedia-main-scroll-vprofile-20261101.json) retain all attempts and build/test exits. Raw commands, profiles, logs, PNGs and guarded runs are in `Build/wikipedia-vprofile-20261101-082120/`. The follow-up implementation commits are `22f41fd7`, `2d3f6957`, `0f04c149`, `6f499ac2`, `d6350d2a`, `ce6b9c4a`, `24cf9d34`, `5e896bf8`, `5a5705d5` and `56686cd8`.

## Earlier Main Page measurements

These earlier trials retained the smooth 60 fps target for `https://en.wikipedia.org/wiki/Main_Page`. These measurements count changed Cocoa layer contents after `updateLayer`, including scroll-position changes; they do not measure physical display scanout.

The native renderer now transfers fractional rectangular borders as edge strips, reuses eligible CPU glyph masks by Skia's exact packed mask phases, transfers small compositor controls through compact regions, and skips redundant GPU work for transparent shapes. Long thin scrollbars keep the compact transfer path. Lossless glyph-backdrop snapshots retain roughly twice as many entries within the existing 64 MiB text-cache budget; every hit still compares the complete input pixels. A larger 128 MiB budget and GPU batching were tested and rejected because neither gave consistent frame-timing gains.

The frozen page uses the original HTTPS URL and archived response bytes, without network forwarding. Every launch has an empty private profile, an independent cache, the default Wikipedia script policy, a 1024×764 document viewport at 2× scale, and 12 seconds settling after a matching title. Throughput includes the entire first-to-last input window. Reports include actual wheel delivery, leading/trailing stalls, scroll intervals and deadline misses. Continuous-forward and oscillating inputs are separate workloads. Other repository sessions ran compilers and browsers during these measurements; changing controls limit timing attribution.

| Workload and measured build | Mean scroll-changing publications/s, both trials | p95 scroll interval |
| --- | ---: | ---: |
| Frozen oscillating 60 Hz input, cohort 10 control | 48.25 / 50.33 | See full interval distributions |
| Frozen oscillating 60 Hz input, cohort 10 candidate | 58.61 / 57.00 | Deadline misses remain |
| Earlier live Main Page, continuous nominal 120 Hz input | 46.03 / 52.24 | 32.71 / 29.90 ms |
| Updated native libraries on the last working executable, live continuous input | 57.86 / 46.73 | 27.11 / 32.44 ms |
| Earlier installed production bundle, live continuous input | 28.00 / 28.94 | 55.07 / 53.76 ms |
| Frozen continuous nominal 120 Hz input, final compressed-cache control | 41.80 / 24.88 | 36.79 / 62.33 ms |
| Frozen continuous nominal 120 Hz input, final compressed-cache candidate | 35.15 / 26.62 | 45.07 / 57.78 ms |

The compressed-cache comparison demonstrates cache retention and pixel correctness; the timing cohort does not establish a reliable FPS improvement. All attempts and regressions are retained. Instrumented cache counters and conversion microbenchmarks do not supply scrolling performance credit. Isolated native-cache candidates preserve the page pixels at matching end scroll positions with zero differences. Those comparisons do not isolate all the other changes in the latest shared production bundle. Focused native tests cover fractional glyph positions, backdrop changes and padding, cache bounds and eviction, transparent compositing, original GPU tile geometry and ownership, and long scrollbar transfers. Startup smoke checks cover DOM events and native wheel routing.

[Committed measurement receipts](benchmark-results/wikipedia-main-scroll-20261101.json) retain cohort summaries, exact commands, executable/library/probe identities, host loads and exits. [Full local evidence](../Build/wikipedia-main-scroll-20261101-043231/report.md) includes every cohort, rejected experiment, protocol limitation and raw-log location. The native changes are commits `c51a8df9`, `f572d47a`, `270aeea8`, `7e9d1935`, `39a324e9` and `43241262`, with distant-boundary regression coverage in `1414526a`.

A new shared production executable crashed before navigation because the stationary-document cache dereferenced the initial absent document. Commit `962b53ba` adds a guard and a passing focused regression test. The completed shared production build includes that guard; a duplicate build was not queued. Fresh installed startup, headless smoke, original-renderer GPU comparisons and both live runs pass their functional checks. Those installed live trials ran at only 28–29 fps, with every scroll interval over budget, while host load rises from 24.5 to 51.2 on 18 CPUs. They cannot establish a smooth 60 fps fix or isolate a code regression. The receipt records unrelated inputs that changed during the shared build, as well as the stable sources for these fixes.

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
