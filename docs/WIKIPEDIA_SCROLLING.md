# Wikipedia scrolling profile

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
