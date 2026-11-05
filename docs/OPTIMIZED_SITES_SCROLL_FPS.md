# Optimized-site scrolling FPS

The [current-build section](#current-build-2026-11-05) holds the 2026-11-05
remeasurement of every catalog row. The later sections are historical
measurements of the initial frozen-page production builds in
[OPTIMIZED_SITES.md](../OPTIMIZED_SITES.md). They measure **scroll-changing native
layer publications**, after Cocoa `updateLayer` completes. They do not measure
physical display scanout. Brave uses a separate, explicitly labeled
[CDP/presentation-feedback measurement](BRAVE_SCROLL_FPS.md).

Each initial Vox catalog range spans two completed, unprofiled trials.
The [Hacker News follow-up](HACKER_NEWS_SCROLLING.md) updates that row to
59.7–59.8 FPS under the same 60 Hz protocol and separately verifies live
scrolling above 60 FPS with 120 Hz input; the original evidence below remains.

Instruction counts, instruction-cohort trial counts and their mean/median labels
remain separate.
The [durable receipt](benchmark-results/optimized-sites-scroll-2026-11-01.json)
contains commands, identities, host load, actual exits, all attempts and exact
statistics. The [compressed raw records](benchmark-results/optimized-sites-scroll-2026-11-01-raw.json.gz)
retain native input/publication log lines and the orchestration source, without
publishing private archived Reddit markup or images. Full artifacts are in
`Build/optimized-sites-fps-20261101/`.

## Current build (2026-11-05)

All rows of [OPTIMIZED_SITES.md](../OPTIMIZED_SITES.md) were remeasured on the
shared production build `9e052f2bdc416f06…` (production receipt
`20261105-020854-53bebf59`, head `c0203bb8e`, built from master plus other
sessions' uncommitted changes). Each page alternates the default control with
`VOX_EXPERIMENT_GPU_CANVAS=1` ([GPU canvas](VLANG_GPU_PASS.md)) on the same
bundle, two fresh-process trials per arm, after one canvas verification run
(`VOX_GPU_CANVAS_VERIFY=2`, diagnostic only, not counted). The executable,
`libLadybirdVSkiaText.dylib` (`59cdfbd9…`) and `libVoxGraphite.dylib`
(`a8e4950d…`) were unchanged before and after every run. All 35 runs exited 0
under the memory guard with valid records and completed every input.

The catalog protocol is unchanged: 1024×768 document viewport at scale 2, empty
private profile/cache, 20 seconds settling after the title, then 600 precise
native wheel inputs at nominal 60 Hz, delta 2, reversing every 60 inputs.
The two live-table pages keep their own protocols: Wikipedia Main Page with 600
inputs at 120 Hz, delta 1, continuous, a 1024×764 viewport and 12 seconds
settling; Hacker News with 1,200 inputs at 120 Hz, delta 1, reversing every 120.

Hacker News uses its frozen six-response archive
(`Tests/Browser/Brave/hn-home-instructions`, loopback HTTP, author scripts
enabled). The frozen fixtures for Old Reddit, Wikipedia portal, vlang.io,
Lobsters and CNN were deleted by `Build/` cleanup, so those pages are measured
**live** with the automatic script policy; they are not the instruction
workloads. Old Reddit `/r/programming/` is unmeasured: its fixture is gone and
the live page now redirects guests to `/login/?reason=lor2`. Host load averages
were 4.6–13.6 on 18 CPUs (per-trial values below), higher during the Wikipedia,
vlang.io and Wikipedia Main Page cases.

| Page | Arm | Trial | Scroll FPS | Actual input Hz | Counted scroll changes / inputs | Input window (s) | Interval median / p95 / max (ms) | Intervals >16.67 ms | Leading / trailing scroll gap (ms) | Load |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | ---: |
| Hacker News (frozen archive) | Default | 1 | 39.22 | 57.30 | 410 / 600 | 10.454 | 24.55 / 32.46 / 55.11 | 100.00% | 94.39 / 17.10 | 6.3 |
| Hacker News (frozen archive) | GPU canvas | 1 | 46.06 | 57.84 | 477 / 600 | 10.355 | 20.81 / 26.91 / 45.42 | 98.53% | 72.77 / 16.89 | 6.9 |
| Hacker News (frozen archive) | Default | 2 | 43.80 | 57.03 | 460 / 600 | 10.503 | 22.48 / 28.63 / 57.14 | 94.57% | 68.65 / 0.17 | 5.7 |
| Hacker News (frozen archive) | GPU canvas | 2 | 33.97 | 56.37 | 361 / 600 | 10.626 | 28.97 / 34.44 / 62.39 | 100.00% | 75.62 / 0.16 | 5.8 |
| Lobsters (live) | Default | 1 | 59.00 | 59.50 | 594 / 600 | 10.068 | 16.65 / 23.91 / 83.50 | 47.98% | 33.66 / 10.91 | 5.6 |
| Lobsters (live) | GPU canvas | 1 | 58.70 | 59.60 | 590 / 600 | 10.051 | 16.66 / 24.52 / 91.79 | 50.00% | 32.68 / 7.87 | 5.0 |
| Lobsters (live) | Default | 2 | 59.59 | 59.89 | 596 / 600 | 10.001 | 16.64 / 21.04 / 38.83 | 47.82% | 30.98 / 10.98 | 5.1 |
| Lobsters (live) | GPU canvas | 2 | 58.90 | 59.40 | 594 / 600 | 10.084 | 16.65 / 20.69 / 100.26 | 49.49% | 32.86 / 10.57 | 4.6 |
| CNN (live) | Default | 1 | 35.86 | 55.93 | 384 / 600 | 10.710 | 25.61 / 46.24 / 58.35 | 97.66% | 96.27 / 18.51 | 5.5 |
| CNN (live) | GPU canvas | 1 | 35.51 | 56.56 | 376 / 600 | 10.590 | 25.53 / 44.97 / 55.18 | 99.20% | 102.75 / 18.74 | 6.8 |
| CNN (live) | Default | 2 | 33.09 | 55.98 | 354 / 600 | 10.700 | 26.82 / 50.19 / 78.28 | 99.15% | 84.10 / 17.16 | 9.4 |
| CNN (live) | GPU canvas | 2 | 29.25 | 55.09 | 318 / 600 | 10.874 | 29.20 / 58.29 / 125.02 | 99.37% | 159.06 / 17.81 | 8.2 |
| Wikipedia portal (live) | Default | 1 | 59.21 | 59.40 | 597 / 600 | 10.083 | 16.67 / 19.27 / 54.71 | 50.42% | 38.75 / 6.15 | 11.7 |
| Wikipedia portal (live) | GPU canvas | 1 | 59.70 | 59.90 | 597 / 600 | 10.000 | 16.66 / 18.60 / 32.62 | 49.92% | 36.22 / 5.64 | 13.6 |
| Wikipedia portal (live) | Default | 2 | 59.80 | 60.00 | 597 / 600 | 9.984 | 16.64 / 20.88 / 41.64 | 47.07% | 33.01 / 6.87 | 11.4 |
| Wikipedia portal (live) | GPU canvas | 2 | 59.50 | 59.80 | 596 / 600 | 10.017 | 16.63 / 20.75 / 58.09 | 47.15% | 34.13 / 6.28 | 11.0 |
| vlang.io (live) | Default | 1 | 52.31 | 57.50 | 545 / 600 | 10.418 | 17.54 / 32.35 / 285.25 | 55.78% | 98.30 / 3.09 | 11.8 |
| vlang.io (live) | GPU canvas | 1 | 54.84 | 57.23 | 574 / 600 | 10.466 | 16.88 / 25.28 / 386.16 | 54.36% | 120.04 / 8.29 | 12.6 |
| vlang.io (live) | Default | 2 | 54.51 | 58.51 | 558 / 600 | 10.237 | 17.01 / 27.57 / 355.46 | 53.58% | 81.24 / 8.47 | 12.4 |
| vlang.io (live) | GPU canvas | 2 | 55.68 | 57.90 | 576 / 600 | 10.345 | 16.74 / 26.34 / 352.65 | 51.74% | 83.10 / 10.99 | 13.3 |
| Wikipedia Main Page (live, 120 Hz) | Default | 1 | 64.29 | 70.27 | 548 / 600 | 8.524 | 14.50 / 20.87 / 79.49 | 18.98% | 138.20 / 0.16 | 10.5 |
| Wikipedia Main Page (live, 120 Hz) | GPU canvas | 1 | 68.75 | 76.55 | 538 / 600 | 7.825 | 13.61 / 20.21 / 77.55 | 15.24% | 69.03 / 2.07 | 10.9 |
| Wikipedia Main Page (live, 120 Hz) | Default | 2 | 83.26 | 98.36 | 507 / 600 | 6.090 | 11.79 / 15.48 / 47.09 | 2.37% | 72.28 / 0.15 | 11.8 |
| Wikipedia Main Page (live, 120 Hz) | GPU canvas | 2 | 81.95 | 83.91 | 585 / 600 | 7.139 | 11.57 / 16.55 / 72.49 | 4.96% | 69.91 / 19.36 | 9.8 |
| Hacker News (live, 120 Hz) | Default | 1 | 39.28 | 71.36 | 660 / 1200 | 16.803 | 24.70 / 31.13 / 53.33 | 100.00% | 107.28 / 0.17 | 7.3 |
| Hacker News (live, 120 Hz) | GPU canvas | 1 | 39.55 | 70.56 | 672 / 1200 | 16.992 | 24.21 / 33.85 / 58.79 | 99.85% | 105.90 / 18.36 | 6.2 |
| Hacker News (live, 120 Hz) | Default | 2 | 40.31 | 70.55 | 685 / 1200 | 16.995 | 23.91 / 32.42 / 62.32 | 100.00% | 92.89 / 0.14 | 5.6 |
| Hacker News (live, 120 Hz) | GPU canvas | 2 | 38.16 | 71.16 | 643 / 1200 | 16.850 | 25.74 / 31.26 / 84.47 | 100.00% | 67.88 / 0.12 | 5.3 |

Canvas verification runs draw each canvas leaf both on the GPU canvas and through
the ordinary path and compare them. The canvas engages only where scroll-raster
frames are reused:

| Page | Canvas frames | GPU leaves | Compared pixels | Differing pixels | Max channel error | Frames over 20 levels |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Hacker News (frozen archive) | 0 | 0 | 0 | 0 | 0 | 0 |
| Lobsters (live) | 0 | 0 | 0 | 0 | 0 | 0 |
| CNN (live) | 0 | 0 | 0 | 0 | 0 | 0 |
| Wikipedia portal (live) | 598 | 2,528 | 41,742,540 | 95,300 | 1 | 0 |
| vlang.io (live) | 1,054 | 3,431 | 157,624,292 | 4,422,800 | 58 | 3 |
| Wikipedia Main Page (live, 120 Hz) | 0 | 0 | 0 | 0 | 0 | 0 |
| Hacker News (live, 120 Hz) | 0 | 0 | 0 | 0 | 0 | 0 |

On Hacker News, Lobsters, CNN and the Wikipedia Main Page no frame is eligible,
so both arms run the same path and their difference is run-to-run variation. On
the Wikipedia portal both arms stay at about 60 FPS. On vlang.io under load
10–13 the canvas trials reach 54.84 / 55.68 FPS with p95 25.28 / 26.34 ms,
against 52.31 / 54.51 FPS and 32.35 / 27.57 ms; the quiet-host cohort in
[VLANG_GPU_PASS.md](VLANG_GPU_PASS.md) measures 59.9 FPS. The vlang.io
verification differs by at most 3 levels except three frames: one anti-aliased
SVG icon edge pixel (58 levels), two rounded-corner pixels of an MSAA-tile
button (46) and a border edge (10), from the canvas's whole-leaf multisampling
versus per-tile MSAA.

**Hacker News regression.** Hacker News now scrolls at 39.2–43.8 FPS (frozen,
60 Hz) and 39.3–40.3 FPS (live, 120 Hz), against 59.7–59.8 and 113.1–115.7 FPS
in the [earlier reports](HACKER_NEWS_SCROLLING.md). A diagnostic live run with
`VOX_SCROLL_RASTER_DAMAGE_DIAGNOSTICS=1 VOX_LEAF_TIMING_DIAGNOSTICS=1` shows
`VOX_SCROLL_RASTER_REJECT reason=nonviewport-vertical-scrollbar` for all 171
frames during input, each a complete repaint of 25–57 ms. A temporary
layout-package test laying out the archived page (stylesheet inlined) at
1024×768 with scroll offsets 0, 100 and 400 and viewport scrollbars on and off
finds only the viewport thumb at x=1016, width 6, and an eligible page, so the
browser-path cause is still open.

The [receipt](performance/optimized-sites-scroll-20261105.json) holds
every command, environment, identity, exit, host load and statistic, the
verification leaves and the Hacker News diagnostic. The
[raw archive](performance/raw/optimized-sites-scroll-20261105.tar.gz)
holds each run's `run.json`, `summary.json`, browser log, guard report and the
orchestration scripts. The sections below are the original 2026-11-01
measurements on the pinned instruction builds and frozen fixtures.

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

## Earlier Brave probe failure

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
The Brave cells initially stayed **—**, meaning unmeasured. A subsequent
[Brave-specific tool and cohort](BRAVE_SCROLL_FPS.md) measure Chromium's reported
scroll presentations through CDP without injection or macOS capture permissions.
The table labels that different input path, frame boundary and enabled tracing;
it does not claim a matched native-input FPS ratio. The historical Reddit-home
fixture is still missing and receives no new FPS value.

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

Subsequent [vlang.io scrolling work](VLANG_SCROLLING.md) bounds and batches
gradient-text, decoration and blur transfers. Its latest production snapshot
measures 3.51–4.25 native scroll FPS live and 6.28–7.68 on the frozen page.
Those results remain separate from the pinned catalog cohort above; every
measured interval still misses the 60 FPS budget and the target remains open.
