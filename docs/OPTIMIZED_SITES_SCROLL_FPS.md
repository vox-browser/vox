# Optimized-site scrolling FPS

These measurements cover the frozen pages and production builds listed in
[OPTIMIZED_SITES.md](../OPTIMIZED_SITES.md). They measure **scroll-changing native
layer publications**, after Cocoa `updateLayer` completes. They do not measure
physical display scanout. Brave remains unmeasured with this endpoint.

Each catalog range spans two completed, unprofiled trials. Instruction counts,
instruction-cohort trial counts and their mean/median labels remain separate.
The [durable receipt](benchmark-results/optimized-sites-scroll-2026-11-01.json)
contains commands, identities, host load, actual exits, all attempts and exact
statistics. The [compressed raw records](benchmark-results/optimized-sites-scroll-2026-11-01-raw.json.gz)
retain native input/publication log lines and the orchestration source, without
publishing private archived Reddit markup or images. Full artifacts are in
`Build/optimized-sites-fps-20261101/`.

## Conditions

All scrolling trials use a 1024×768 CSS-pixel **document** viewport at native
backing scale 2. This differs from the scale-1 instruction screenshots for
Reddit, Wikipedia and vlang.io. The native overlays occupy 112 pixels on the
Reddit/Hacker News builds and 84 pixels on the older Wikipedia/vlang.io builds;
the probe measures them and verifies the resulting document viewport.

Each trial launches a fresh process of the row's pinned executable, checks its
embedded native-library identities before/after, and uses a new private profile
and cache. Reddit receives a fresh copy of its sealed encoded-resource cache;
snapshots are removed. File/loopback fixtures receive only
`{"allow_any_site":true}` in their private settings so the browser's navigation
allowlist permits the fixture. This profile does not retain user proxy settings,
cookies, bookmarks or browsing history. Wikipedia keeps its profile initially
empty and uses an explicit loopback SOCKS/TLS replay at the original origins.
A tested network interposer denies external DNS/connect/connectx. Replay has no
live fallback. OS filesystem/shader caches are retained; no warmup or slow
measurement sample is discarded.

| Page | Frozen workload and script policy | Pinned Vox executable SHA256 |
| --- | --- | --- |
| Old Reddit | `/r/programming/`, the existing script-stripped cached derivative; normal JavaScript policy enabled | `cdca80b1d73a31d1685ce3b64d79002887a91332612c9e958596cf14e9d51c52` |
| Hacker News | Existing six-response archive served over loopback HTTP; author script retained and enabled | `ac11c56baaa7d18a5ee0275c45c1e7a3f5409b81b7db3d13d87939878c39f81d` |
| Wikipedia | Existing 15-response archive at original HTTPS origins; JavaScript disabled | `9b4ad5481fd8f66d68ee6e4c4e5baf6285aab22de8b4e97b4649ddf09212e0e5` |
| vlang.io | Existing initialized DOM snapshot and local assets, scripts removed, animations disabled, fixed video poster; JavaScript policy enabled | `79b88644ff1669c6102bf344a46c6daa71ddc1f4cf313eab13f03fe0e91b448b` |

The selected Vox backend is JavaScriptCore. These frozen-page measurements do
not establish JavaScript VM performance or live-site behavior. The unchanged
instruction reports document content, script and rendering limitations for each
fixture, including the cached account UI on Reddit; no live login is validated.

After the required document title appears, the tool settles for 20 seconds,
then sends **600 precise native pixel-wheel events**, nominally at 60 Hz,
with delta 2 and direction reversed every 60 events. Inputs go through the
native input view. `VOX_TEST_WINDOW=1` selects native test-window placement away
from the pointer when another display is available. Actual input timestamps,
keyboard modifiers and scroll positions are retained. This gentle alternating
workload covers approximately 0–252 CSS pixels vertically; it does not measure
rapid full-page traversal or fling scrolling.

Only consecutive publications with a changed scroll position count toward
scroll FPS. The first publication supplies the reference position. The entire
first-to-last actual input period is the denominator, including leading and
trailing publication gaps. Tail publications prove completion but do not
increase the measured FPS. A low input cadence is reported alongside frame
cadence; the requested 60 Hz timer is not assumed to have delivered 60 Hz.

## Results

| Page | Trial | Scroll FPS | Actual input Hz | Counted scroll changes | Input window (s) | Interval median / p95 / max (ms) | Intervals >16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |
| Old Reddit /r/programming/ | 1 | 39.21 | 53.87 | 436 | 11.120 | 23.17 / 41.58 / 143.42 | 97.71% | 106.00 / 46.88 |
| Old Reddit /r/programming/ | 2 | 52.96 | 56.95 | 557 | 10.517 | 16.61 / 29.79 / 132.91 | 49.37% | 101.50 / 18.98 |
| Hacker News homepage | 1 | 51.47 | 57.31 | 538 | 10.452 | 18.88 / 24.78 / 55.21 | 79.18% | 82.17 / 20.69 |
| Hacker News homepage | 2 | 46.06 | 57.36 | 481 | 10.443 | 21.18 / 29.29 / 57.60 | 88.77% | 84.64 / 19.23 |
| Wikipedia homepage | 1 | 3.08 | 13.78 | 134 | 43.458 | 303.42 / 439.96 / 730.59 | 100.00% | 702.58 / 329.29 |
| Wikipedia homepage | 2 | 3.63 | 14.29 | 152 | 41.904 | 259.71 / 352.89 / 603.94 | 100.00% | 729.46 / 131.64 |
| vlang.io (CLI protocol) | 1 | 0.86 | 11.15 | 46 | 53.724 | 1107.22 / 1287.57 / 1511.95 | 100.00% | 2390.75 / 394.66 |
| vlang.io (CLI protocol) | 2 | 0.78 | 10.60 | 44 | 56.518 | 1196.98 / 1308.36 / 1409.88 | 100.00% | 4642.72 / 1119.57 |

Every trial completed all **600 inputs**. Completed native-publication counts,
including the untimed tail, were Old Reddit /r/programming/: 449/634, Hacker News homepage: 554/499, Wikipedia homepage: 139/156, vlang.io (CLI protocol): 48/46.

Pooled full-window rates (sum of counted changes divided by sum of input windows)
were Old Reddit /r/programming/ **45.89 FPS**, Hacker News homepage **48.77 FPS**, Wikipedia homepage **3.35 FPS**, vlang.io (CLI protocol) **0.82 FPS**.
The catalog shows the per-trial range so that this aggregation does not hide variation.

The host has 18 logical CPUs and substantial concurrent load. Per-trial load
averages and timestamps are in the receipt. Reddit's large variation and the
late input delivery make these observations specific to the recorded conditions;
they are not optimization credit. Wikipedia's recorded intervals all exceed the
16.67 ms budget. These results do not establish smooth 60 FPS.

## Retained diagnostics and protocol corrections

The first Reddit diagnostic loaded a navigation-blocked page and timed out;
it supplied no FPS. Enabling fixture navigation in its isolated profile fixed
that load. Inspection also established that `MyView2` covers the full native
content view, including browser chrome. The updated probe subtracts the actual
native toolbar/status overlays and rejects a mismatched document viewport.

The first Wikipedia replay diagnostic seeded a settings file that unintentionally
disabled the environment replay proxy. It failed navigation and supplied no FPS.
The tool now rejects combining `--allow-fixture-navigation` with `VOX_PROXY`.
Wikipedia needs no allowlist override at its original URL, so its measured runs
use the initially empty private profile with the explicit replay proxy.

With that corrected route, Wikipedia's first trial completed at **3.9008 FPS**,
but the second trial exited before the final input had a completed publication.
The old observer allowed only a fixed 250 ms tail. That pair is retained as an
incomplete attempt, including the successful trial, all 600 inputs in the failed
trial, the actual zero browser exit, and the summarizer's failure. The corrected
observer waits for the final input's publication, with a five-second timeout.
It retains all tail frames outside the timed window. A complete new two-trial
pair supplies Wikipedia's catalog range. No browser code or timing denominator
was changed. The Reddit/Hacker News trials had already published their final
inputs; their results remain in the table.

Tooling commits `0f7e9ee0`, `a037770f` and `5050b551` contain the viewport,
profile/proxy and final-publication corrections. The final focused suite passes
18 tests, including an actual delayed native completion after 400 ms and an
explicit missing-publication timeout. All browser measurements and probe tests
ran under the memory guard. The receipt preserves nonzero controller/guard
exits from the earlier failed diagnostics as well as the completed run exits.

Hacker News also requested `/favicon.ico` once per launch; the sealed server
returned 404 for that non-document tab-icon fallback. Its document and archived
page resources returned successfully. The request audit retains these failures;
they did not provide a live fallback or a different document. vlang.io’s logs
also retain CoreText warnings that `.SFNS-Regular` falls back to
`TimesNewRomanPSMT` in the pinned build. These are recorded rendering conditions.

## Brave measurement remains open

A diagnostic constructor observer loaded in Vox, but the same injection mechanism
did not load in either a fresh headless or windowed process of the installed
Brave 156.1.98.60 / Chromium 156.0.8078.48. Both Brave processes exited normally.
The signed executable reports hardened runtime, restriction and library-validation
flags. Its executable and framework hashes remained unchanged. The windowed
check retains native display placement and the `Browser.getVersion` response.

Independent macOS preflight checks returned false for both screen capture and
posting native events. No validated external frame-publication/input measurement
was therefore available in this session. CDP screenshots, `requestAnimationFrame`
and synthetic callback throughput do not supply a matching native FPS result.
The Brave cells stay **—**, meaning unmeasured, rather than assuming 60 FPS or
substituting a different endpoint. The historical Reddit-home fixture is also
still missing and receives no new FPS value.

## Reproduce Vox trials

Start the same sealed fixture server or original-origin replay described above,
clear ambient measurement/proxy overrides, and run the appropriate pinned app.
The durable receipt and compressed drivers retain the exact invocations. A
single file/loopback trial follows this shape; use distinct outputs for at least
two complete trials:

```sh
python3 tools/run_memory_bounded.py \
  --lock Build/scroll-UNIQUE.lock --report Build/scroll-UNIQUE-guard.json -- \
  python3 tools/measure_precise_scroll.py \
    --binary PINNED_APP/Contents/MacOS/Vox --url FIXTURE_URL \
    --output Build/scroll-UNIQUE --width 1024 --height 768 \
    --chrome-height 112 --inputs 600 --input-hz 60 \
    --delta 2 --reverse-every 60 --settle-seconds 20 \
    --require-title EXPECTED_TITLE --script-policy enabled \
    --allow-fixture-navigation --insert-library VERIFIED_NETWORK_DENY_DYLIB \
    --network-policy 'Describe the sealed replay/cache and external network denial' \
    --timeout 150
```

Use `--chrome-height 84` for the pinned Wikipedia/vlang.io builds. Reddit also
needs its recorded `--cache-template`. Wikipedia instead uses its recorded
`VOX_PROXY`, private `SSL_CERT_FILE`, and `--script-policy disabled`, without
`--allow-fixture-navigation`. Keep the native scale, input schedule, fixture
hashes and network/cache policy fixed when comparing new browser builds.

Subsequent [vlang.io scrolling work](VLANG_SCROLLING.md) bounds decoration
backdrops and records new frozen/live trials. Those results remain separate
from the pinned catalog cohort above; the live 60 FPS target is still open.
