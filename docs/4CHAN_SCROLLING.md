# 4chan scrolling through SOCKS and from disk

Investigated 2026-10-25–26 using
<https://boards.4chan.org/pol/thread/544908349/what-has-the-world-come-to>.
The acceptance endpoint is a changed native layer publication after
`updateLayer` completes. This does not measure physical display scanout.

## Disk-only capture and baseline

At the user's request, subsequent experiments use a sealed local capture to
remove SOCKS reliability from the measurement. The fixture is
`Build/pol-scroll-20261025-2210/disk-fixture-final/`: 65 HTTP-200 responses and
1,135,177 body bytes, including original HTML, all four external scripts,
stylesheets, image resources and three explicitly archived JSON API endpoints.
Its manifest SHA-256 is
`a6eea835480b8fe1073227f6717ca49f91b19a630499861230d4cb45d5619562`.
The original 334,163-byte HTML has SHA-256
`b248d4a5975efcfdc3aa67edbd26cb4b53e674829ba2929e8a2cfabc2f114afa`;
its inline scripts and external script references remain unchanged.

Existing raw cached responses were reused without refetching. Eight missing
resources were captured once through SOCKS into `disk-fixture/`, then the tail
JSON endpoint was added once to `disk-fixture-final/`. Per-response provenance,
download commands and the two sealed manifest identities are retained in
`disk-fixture-provenance.json`. Captures span October 25–26; this is a fixed
response collection, rather than a claim that all endpoints were fetched at
one instant.

`tools/page_archive.py` replays saved bodies from disk at their original HTTPS
origins through a loopback server with private TLS trust and no forwarding.
`tools/measure_disk_scroll.py` removes inherited proxy settings and injects the
tested external DNS/IPv4/IPv6 `connect`/`connectx` deny interposer. No SOCKS or
external page access is available during these runs. Every fresh process has
an initially empty private cache and profile. Both trials requested the same
32 distinct archived resources, including all four external scripts, with zero
archive misses; extra archived responses remain available for dynamic requests.
The native guard test and four archive tests passed, as did eleven existing
precise-probe regression tests. See [repeat commands](DISK_SCROLL_BENCHMARK.md).

These two baseline runs use the pinned production small-shape batch bundle
`tile-batch-candidate.app`, with executable/Skia/Graphite/Dawn hashes
`3764c693…`, `b5c00fd6…`, `23eaccf9…`, and `cb98233f…` respectively;
the full hashes are in `disk-baseline/build-sha256.json`. Both runs completed
360 inputs, moved the document, retained identical build/archive/tool hashes,
and exited 0. The required thread title was present before twenty seconds of
settling. The schedule is the 1024×764 CSS viewport, backing scale two, nominal
60 Hz precise input, delta 12 and reversal every 120 inputs described below.
The input view, including browser chrome, reports 1024×848.

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| disk-baseline/browser-1 | 27.61 | 32.89 / 67.64 / 89.57 | 95.68% | 185 / 196 / 360 |
| disk-baseline/browser-2 | 29.87 | 29.67 / 62.92 / 88.64 | 90.31% | 196 / 208 / 360 |

| Trial | Actual input Hz | Entire input period, s | Leading / trailing publication gap, ms | First counted scroll delay, ms |
| --- | ---: | ---: | --- | ---: |
| disk-baseline/browser-1 | 53.57 | 6.702 | 118.22 / 0.33 | 193.99 |
| disk-baseline/browser-2 | 54.71 | 6.562 | 140.28 / 20.03 | 223.58 |

The runs began at 02:49:13 and 02:49:44 UTC on October 26, with fresh browser
PIDs 68794 and 69363. The 18-CPU host's one-minute load before/after each run
was 10.27/8.99 and 8.99/9.17. Preserve this contention and variation when
interpreting results. These fresh-cache, original-script disk trials are a
different workload from earlier cache-seeded frozen trials; cross-family
timings do not isolate a code change. The page remains slow with SOCKS removed,
and smooth 60 fps is still unmet. These are native publication measurements,
not physical display presentation or a new live-page result.

Raw requests, original URL, private certificate identity, source/build hashes,
commands, actual input timestamps, frame records, exit codes and summaries are
under `disk-baseline/`. The benchmark driver and every child command exited 0;
the enclosing job later exited 1 at the separate experiment's eligibility gate
described next. Its memory guard reports normal process completion, child exit
1, a 3 GiB budget, sampled peak RSS 840,974,336 bytes and 296.08 seconds elapsed
in `large-batch-build-check-guard.json`. This failed experiment does not supply
an acceptance result; the two completed baseline trials retain their own
successful commands and browser exits.

### Rejected larger-shape batch experiment

A prototype broadened tile readback batching beyond small shapes, retaining
original GPU surface coordinates and reading back only caller-owned regions.
Native checks passed: 45,056 exact GPU tile comparisons both normally and with
AddressSanitizer/UndefinedBehaviorSanitizer; 6,912 serial ownership/backdrop
comparisons both normally and under sanitizers; and the existing shape-region,
MSAA mask/compositing and raster-grid checks. Headless startup also passed.

The new archive was then checked in separate 120-input control/candidate
diagnostics before timing. Both browsers exited 0 and scrolled the expected
document, with zero missing disk resources. Neither run logged a successful
larger-shape batch at startup or during input. The eligibility assertion failed,
so screenshot comparisons and alternating performance trials were not run.
There is no optimization credit from this prototype, and no claim that an
unexecuted path explains the baseline's slowdown.

The prototype and its focused tests were removed from the working source;
their immutable snapshot, patch, build identities, commands, sanitizer output,
diagnostics and rejection record remain in `large-batch-source/`,
`large-batch-owned.patch`, `large-batch-build-identity.json`,
`large-batch-build-check-commands.json`, `large-batch-validation-commands.json`
and `large-batch-rejection.json`. The disk archive and benchmark tooling are
the retained change.

### Profile of the original-script disk workload

A separate six-second native sample started at 03:52:16 UTC on October 26,
after title readiness, twenty seconds of settling and the start of precise
wheel input. It used the same sealed archive and pinned small-shape batch
bundle as the disk baseline, with 900 inputs to keep the sample within the
scrolling window. This is diagnostic evidence, with no performance credit.
Browser, driver, sampler and memory guard exited 0; all replay requests were
archived HTTP-200 responses. Raw evidence is in `disk-native-profile/`.

Of 3,760 main-thread samples, 1,552 included rounded-rectangle drawing (41.3%)
and 832 ended in a GPU completion wait (22.1%). These counts overlap. GPU waits
included 275 samples in full-shape drawing, 214 in regional shape drawing and
166 in the existing small-shape batch. Viewport visibility traversal accounted
for 85 samples (2.3%). This prioritizes reducing repeated shape submissions
and readbacks; culling alone cannot explain most of this workload's cost.

`symbol-validation.json` verifies the executable and native library SHA-256s,
Mach-O UUIDs, loaded image bases and 550 executable, 56 text-bridge and 88
Graphite sampled symbol addresses against their symbol ranges. The optional
Dawn library was not loaded; its absent samples are not treated as zero-cost
execution. `hotspots.json`, `sample.txt`, `result.json` and
`disk-native-profile-guard.json` retain the analysis, commands and actual exits.
The guard's sampled process-tree RSS peaked at 950,042,624 bytes within its
12 GiB budget, over 47.03 seconds including browser startup and settling.

### Larger-shape batch follow-up: no gain

A second prototype reached the archived workload, but only once during each
120-input eligibility diagnostic. Native comparisons and sanitizer checks
passed, and all thirteen control/candidate browser screenshot pairs were
pixel-exact. Four subsequent alternating, unprofiled 360-input runs completed
successfully, with the same archive and protocol as above:

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| control-1 | 22.00 | 40.51 / 75.14 / 128.53 | 100% | 151 / 161 / 360 |
| candidate-1 | 19.80 | 45.76 / 87.85 / 109.99 | 100% | 132 / 141 / 360 |
| control-2 | 21.45 | 41.90 / 77.76 / 108.96 | 100% | 146 / 158 / 360 |
| candidate-2 | 20.39 | 44.72 / 85.84 / 141.73 | 100% | 137 / 148 / 360 |

| Trial | Actual input Hz | Entire input period, s | Leading / trailing publication gap, ms | First counted scroll delay, ms |
| --- | ---: | ---: | --- | ---: |
| control-1 | 52.32 | 6.862 | 176.93 / 20.27 | 280.41 |
| candidate-1 | 53.85 | 6.667 | 174.67 / 20.43 | 274.31 |
| control-2 | 52.73 | 6.808 | 177.90 / 20.06 | 286.86 |
| candidate-2 | 53.44 | 6.718 | 179.35 / 19.89 | 280.62 |

The 18-CPU host's one-minute loads before/after these trials were
83.93/103.31, 101.12/98.37, 98.37/102.31 and 105.81/103.49. These heavily
contended runs provide no optimization credit; both candidate regressions are
retained. The infrequently executed path does not address the common draws.
The prototype was removed; `large-batch-v2-validated-rejected.patch` and
`large-batch-v2-decision.json` preserve that decision. Its executable, text
bridge, Graphite and Dawn hashes are `38ab89cf…`, `8fc5ef3f…`, `9d08dda8…`
and `cb98233f…`; full identities and commands are in
`large-batch-v2-build-identity.json` and `large-batch-v2-build-check-commands.json`.
The original validation stopped at an overstrict eligibility assertion and
exited 1; `large-batch-v2-validation-resume-1/` retains the completed pixel and
timing checks, their commands, timestamps, actual inputs, host loads and
browser exits. The enclosing resumed guard later exited 1 at a separate
viewport-projection regression test; that prototype was also removed.

### Small-shape cost diagnostic

`disk-shape-cost-profile-v3/` separates startup from the actual input window
using a marker installed by the precise-input probe. This separate instrumented
360-input run uses the same archive, title readiness and settling period,
and supplies no unprofiled performance credit. The driver and six-second
sampler exited 0, and all replay requests returned archived HTTP-200 bodies.
The probe identifies the executable, resolves all four Graphite entry points
to the pinned library, and checks the text bridge's leaf image. Source,
library hashes, addresses, commands and results remain with the raw logs.

During input, full-tile rounded strokes with an underlay made 1,319 calls
and consumed 708.81 ms inside the native API. Unrounded fills with two
clip exclusions made 365 calls and consumed 208.24 ms. Existing regional and
batched fills were already active. Only three larger-shape batches executed
during input. These API timings include nested work and must not be added to
the enclosing leaf timings or interpreted as scrolling fps. They motivate
extending compact readbacks to small controls with underlays and clip
exclusions while preserving the original GPU coordinates and surface extent.

### Small compound-shape patches

Commit `d2bfc81f` extends conservative compact GPU transfers to small controls
with a background underlay or rectangular clip exclusions. It preserves the
original GPU matrix and surface extent, unions the underlay bounds with the
foreground stroke, and owns clip bytes in the bounded raster cache. Patches
are at most 16,384 pixels and less than one quarter of the original tile.
Unsupported descriptors retain the full draw. The diagnostic control is
`VOX_DISABLE_COMPOUND_SHAPE_PATCHES=1`; both modes use identical signed binaries.

Separate eligibility runs on this exact archive recorded sixteen successful
compound patches during input per candidate (eleven underlays, five clip
exclusions), with zero in disabled controls. Startup counters are separate;
`dladdr` verified the loaded candidate library. Production native compilation,
headless startup, 15,104 GPU batch comparisons, 14,336 GPU region comparisons,
1,728 native shape-backdrop comparisons and 6,912 serial raster comparisons
passed, along with the existing MSAA, grid, shadow, snapshot and cache checks.
ASan/UBSan batch and owned-clip cache checks also passed. All thirteen browser
control/candidate screenshot pairs were pixel-exact: eleven canonical smoke
cases and the checkbox/clipped-link fixture at scales one and two. The same
four previously recorded smoke reference failures remain in both modes.

Fresh-process disk trials used the archived original HTTPS origins, private
TLS trust, no forwarding and denied external connections. Each used an empty
private profile, title readiness followed by twenty seconds settling,
1024×764 CSS viewport at backing scale two, and 360 native precise wheel
inputs at nominal 60 Hz, delta 12, reversing every 120 inputs. Diagnostics and
sampling were disabled for these alternating trials. Throughput uses the
entire first-to-last input period and counts scroll-changing publications
after `updateLayer`; it does not measure physical display presentation.

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| control-1 | 22.68 | 39.74 / 77.60 / 100.14 | 100.00% | 153 / 163 / 360 |
| candidate-1 | 25.73 | 33.69 / 79.23 / 172.88 | 96.83% | 189 / 205 / 360 |
| control-2 | 21.09 | 43.38 / 82.39 / 123.38 | 100.00% | 141 / 150 / 360 |
| candidate-2 | 25.88 | 34.58 / 72.20 / 93.07 | 97.22% | 180 / 190 / 360 |

| Trial | Actual input Hz | Input period, s | Leading / trailing publication gap, ms | First scroll change, ms |
| --- | ---: | ---: | --- | ---: |
| control-1 | 53.21 | 6.747 | 159.22 / 21.29 | 256.54 |
| candidate-1 | 48.87 | 7.346 | 50.95 / 21.70 | 135.74 |
| control-2 | 53.69 | 6.686 | 163.53 / 1.37 | 266.71 |
| candidate-2 | 51.62 | 6.955 | 165.92 / 20.10 | 231.59 |

Observed throughput increased 13.45% and 22.72%, but the host was severely
contended: eighteen CPUs, with one-minute load before/after each trial of
69.99/74.13, 77.49/78.49, 78.49/75.00 and 75.00/84.25. Controls also varied;
these results do not establish a reliable gain magnitude or isolate ambient
contention from the implementation. Regressions include pair one's p95 and
maximum intervals, its slower actual input cadence, and pair two's larger
boundary gaps. Both candidate trials still missed nearly every 16.67 ms
scroll deadline. **Smooth 60 fps remains unmet.** These disk results do not
establish that the installed bundle fixes live SOCKS scrolling.

Trials started at 05:43:58, 05:44:30, 05:45:02 and 05:45:34 UTC on October 26,
2026. All completed their 360 inputs, moved the document, retained their build
identity and exited 0. Every replay request returned an archived HTTP-200 body.
The build/check guard and child exited 0, with a twelve GiB budget, sampled
peak RSS 1,233,125,376 bytes and elapsed time 564.15 seconds.

Pinned SHA-256 identities:

- Vox: `7530bb0386801b6d0f7db80802d19574254e58b5823e6ad547a62491a2e1cfe3`.
- Skia: `e8dbb3c2078f2ecc248a87b37693875ece64fd92741fe38f280bf0424050867f`.
- Graphite: `92e137b45b2e14496331fd96386bfd88d2ccf15a70b59bf4bdb2006b97b2fc3b`.
- Dawn: `cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52`.

The unsigned V executable is unchanged from the disk baseline; signing reflects
the candidate native libraries. Source snapshots, compiler commands and build
identities are retained in `compound-patches-v1-source-identity.json`,
`compound-patches-v1-build-check-commands.json` and
`compound-patches-v1-build-identity.json`. Raw eligibility, pixel comparisons,
commands, input timestamps, host loads, browser exits and summaries are under
`compound-patches-v1-validation/`, `compound-patches-v1-trial-summary.json`
and `compound-patches-v1-build-check-guard.json` in the evidence directory.

## Baseline and bottleneck

The original production bundle published 39.81 scroll-changing frames/s on the
live SOCKS5h route `127.0.0.1:1337`. Its median/p95/maximum scroll intervals were
21.79/47.85/70.84 ms; 76.38% exceeded the 16.67 ms frame budget. Two later
installed-build live trials measured 42.09 and 41.84 frames/s; those builds also
contain concurrent changes and provide no isolated optimization credit.

A separate native-wheel diagnostic profile identified SVG-path replay as a
large cost. These paths are the reply boxes' bottom and right CSS borders,
with a large empty interior. Whole-rectangle backdrop copies, GPU readbacks,
and short-lived recorders made thin borders expensive. The page contains no
SVG markup; CSS border painting uses the general path renderer.

The border optimization transfers conservative, disjoint device-pixel regions
around straight contours. It retains the original path, transformation, GPU
surface extent, and coverage calculation, submits the readbacks together,
and caches owned geometry, region positions, backdrops, and resulting pixels
within the existing bounded path cache. Unsupported geometry retains full
replay. Native comparisons cover fractional scrolling, scale 1/2, curved and
rectangular clips, translucent backdrops/fills, source mutation, cache reuse,
odd pitches, untouched padding, and invalid region rejection.

An independent hit-test fix skips out-of-bounds text fragments before checking
style and DOM ancestry. It preserves nearest-text-cursor behavior and does not
supply scrolling performance credit by itself.

## Measurement protocol and retained evidence

Raw logs, exact commands, input/publication timestamps, source fingerprints,
executable/native-library SHA-256 hashes, compiler/test exit codes, and memory
guard reports are retained in `Build/pol-scroll-20261025-2210/`.

All timed runs use fresh processes/private profiles, a 1024×764 CSS-pixel
document viewport, backing scale 2, 20 seconds of settling after the required
thread title appears, and 360 precise native wheel inputs at nominal 60 Hz,
delta 12, reversing every 120 inputs. The browser applies 25.2 CSS pixels per
input. Actual input delivery times are retained. Throughput uses the entire
first-to-last input period; leading/trailing publication gaps are reported
separately. Animation-only publications do not count as scroll changes.

Frozen trials replay the original response at its original HTTPS URL through
a local CONNECT proxy with private TLS trust and no forwarding. The archived
main body SHA-256 is
`b248d4a5975efcfdc3aa67edbd26cb4b53e674829ba2929e8a2cfabc2f114afa`.
The resource manifest records 57 successful archived resource responses.
Matched control/candidate trials alternate twice. The control disables only
the new native sparse-path call. After removing code signatures from copies,
the main executables are byte-identical; unaffected native libraries match.
Signed executable bytes differ because signing covers the changed library. Two additional candidate trials use the live SOCKS route.
Profiles run separately and supply no unprofiled performance credit.


## Results and acceptance status

**The requested smooth 60 fps has not been achieved.** Retain the target as
open: high average throughput alone would also be insufficient with frequent
16.67 ms deadline misses.

The first border-only alternating series retained six valid browser trials,
but its outer memory guard was interrupted and left an empty report. Its
frozen control/candidate rates were 15.65/18.39 and 21.39/23.67 frames/s; live
candidate rates were 26.76/26.12 frames/s. These are incomplete acceptance
evidence. Independent samples showed the sparse-path function executing on
the requested thread; timing alone does not establish attribution. Different
build families and ambient host load cannot be compared as isolated changes.

A subsequent root-fill experiment extended sparse rendering to fractional
opaque fills. All 2,700 exact native GPU comparisons passed, including 1,350
successful direct helper calls. This did **not** produce a measured gain.
The complete guarded alternating series below retained all regressions.
The experiment was subsequently reverted. A separate diagnostic, with counters
split between startup and the input window, recorded only helper rejections
and no successful sparse root-fill calls. Its timings cannot establish a gain
from that path on this page. The rejected source and diagnostic logs remain
under `root-fill-diagnostic-v2*` and
`native_skia_text_darwin.cpp.root-fill-rejected-candidate` in the evidence directory.
Its frozen control/candidate bundles have the same unsigned main executable
SHA-256 `388f692e1d24f26c739a1dd72280359cdda9189b4d252013d4440c5d91fb3da5`.
Only their Skia bridge differs; full identities are in
`root-fill-pair-source-verified.json`. Live runs use the installed candidate
bundle via SOCKS, with identity verified before each launch.

| Trial | Scroll publications/s | Median / p95 / maximum interval (ms) | Over 16.67 ms | Moving intervals / measured publications / inputs |
| --- | ---: | --- | ---: | --- |
| root-fill-control-frozen-1 | 40.63 | 21.54 / 51.60 / 85.08 | 71.81% | 259 / 280 / 360 |
| root-fill-candidate-frozen-1 | 39.23 | 21.49 / 51.01 / 82.46 | 70.52% | 251 / 270 / 360 |
| root-fill-control-frozen-2 | 41.25 | 21.88 / 51.15 / 68.88 | 67.46% | 252 / 277 / 360 |
| root-fill-candidate-frozen-2 | 38.60 | 21.78 / 55.21 / 104.24 | 73.86% | 241 / 260 / 360 |
| root-fill-candidate-live-1 | 33.19 | 26.01 / 67.80 / 140.36 | 89.35% | 216 / 222 / 360 |
| root-fill-candidate-live-2 | 23.17 | 37.64 / 92.26 / 153.42 | 100.00% | 156 / 158 / 360 |

Each trial completed 360 inputs with browser exit 0 and valid publication
records. `root-fill-measurement-guard.json` records guard exit 0 and peak
aggregate RSS 1.04 GB. Boundary gaps and actual input cadence follow; leading
gaps refer to the first counted scroll change, trailing gaps to the last
scroll publication relative to the final input.

| Trial | Actual input Hz | First-to-last input period (s) | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- |
| root-fill-control-frozen-1 | 56.32 | 6.375 | 194.58 / 0.21 |
| root-fill-candidate-frozen-1 | 56.11 | 6.398 | 349.64 / 0.20 |
| root-fill-control-frozen-2 | 58.77 | 6.109 | 190.16 / 0.25 |
| root-fill-candidate-frozen-2 | 57.50 | 6.243 | 170.50 / 0.24 |
| root-fill-candidate-live-1 | 55.16 | 6.508 | 192.34 / 18.25 |
| root-fill-candidate-live-2 | 53.32 | 6.734 | 216.25 / 0.31 |

The production build and headless startup check passed. The 11-case screenshot
smoke set passed seven cases; the four failures were pixel-identical between
the pinned control and candidate. They remain pre-existing conformance
failures, not passing screenshot results. Commands, comparison images and
actual exits are retained in `root-fill-postbuild-commands.json`,
`root-fill-screenshot-smoke.json` and `root-fill-control-screenshot.json`.

The next profile showed substantial synchronous Metal readback time for small
shapes and images, in addition to paths. Further work must reduce that cost
and pass another matched native-input series plus installed live SOCKS trials.

## Bounded region-target reuse

Commit `55d94b25` reuses the existing bounded Graphite recorder/surface pool
for image regions, small shapes and rounded parts. Each operation saves and
restores canvas state before clearing and replaying, preserving clips and
transforms between uses. The pool retains at most 32 targets and 4 MiB of
surface pixels; larger requests keep the original allocation path. The
recorder retains its existing 16 MiB budget.

All 8,952 exact GPU comparisons passed, including 384 new interleaved region
comparisons, 1,920 image comparisons, 2,560 shape comparisons, 3,312 rounded-part
comparisons and 776 path comparisons. They cover repeated and changing
extents, eviction, the oversized fallback, source/backdrop changes, fractional
transforms, clips, alpha, MSAA, odd pitches and untouched padding. A separate
diagnostic confirmed successful image and small-shape pool hits during the
original archived page's input window.

The complete alternating series follows. The candidate was faster in both
frozen pairs, by 7.61% and 19.83%, respectively. Attribution remains unresolved:
other compiler jobs loaded the host, and these runs lack matched load-average
records. Per-trial process snapshots are retained as `*-ambient.txt`; they
cannot establish equal host contention. These timings provide no isolated
optimization credit and cannot be compared as isolated changes against the
earlier build families. The live SOCKS result still misses the 60 fps target
substantially. New runs must retain the measurement tool's host CPU count,
load averages and timestamps as well as the existing browser identities.

| Trial | Scroll publications/s | Median / p95 / maximum interval (ms) | Over 16.67 ms | Moving intervals / measured publications / inputs |
| --- | ---: | --- | ---: | --- |
| region-reuse-control-frozen-1 | 22.11 | 39.14 / 86.45 / 120.21 | 100.00% | 156 / 158 / 360 |
| region-reuse-candidate-frozen-1 | 23.80 | 36.42 / 70.49 / 99.05 | 96.89% | 161 / 163 / 360 |
| region-reuse-control-frozen-2 | 20.97 | 44.06 / 91.00 / 132.05 | 100.00% | 140 / 142 / 360 |
| region-reuse-candidate-frozen-2 | 25.13 | 35.47 / 71.38 / 97.74 | 96.34% | 164 / 165 / 360 |
| region-reuse-candidate-live-1 | 27.66 | 31.17 / 65.43 / 125.09 | 95.63% | 183 / 185 / 360 |
| region-reuse-candidate-live-2 | 26.26 | 31.75 / 72.75 / 139.10 | 100.00% | 173 / 176 / 360 |

| Trial | Actual input Hz | First-to-last input period (s) | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- |
| region-reuse-control-frozen-1 | 50.89 | 7.054 | 493.77 / 1.34 |
| region-reuse-candidate-frozen-1 | 53.06 | 6.766 | 470.75 / 20.12 |
| region-reuse-control-frozen-2 | 53.78 | 6.676 | 265.45 / 1.43 |
| region-reuse-candidate-frozen-2 | 55.01 | 6.526 | 225.57 / 21.37 |
| region-reuse-candidate-live-1 | 54.25 | 6.617 | 203.00 / 36.96 |
| region-reuse-candidate-live-2 | 54.50 | 6.588 | 206.29 / 1.36 |

All six browsers completed 360 inputs and exited 0. The validation guard
completed with exit 0, a 3 GiB limit and sampled peak RSS 1,202,176,000 bytes.
Headless startup passed. Seven of the 11 screenshot smoke cases passed; the
four failures remained pixel-identical to fresh pinned-control captures.
These failures remain open conformance issues. Raw commands and exits are in
`region-reuse-validation-commands.json`, the individual trial result files
and `region-reuse-validation-guard.json`. Successful reuse counters are in
`region-reuse-diagnostic-result.json`.

The control/candidate unsigned main executable SHA-256 is
`388f692e1d24f26c739a1dd72280359cdda9189b4d252013d4440c5d91fb3da5`.
Graphite control SHA-256 is
`a36151a5d563b3a2875b4ed5d634b878f8d55d88f4199990c67f88fa9cefcf65`;
candidate SHA-256 is
`d570416e38bb99496c7d4a4b5201f85090321cfd6851ab4b0262daafbfe645d3`.
Complete signed executable and dependency identities, including unchanged
Skia and Dawn libraries, are in `region-reuse-pair-source-verified.json`.
Live trials launched fresh processes from the installed candidate bundle.
The previously installed bundle was restored when the experiment finished.

## Scroll-cache eligibility investigation

The actual wheel sequence advances by approximately 25.200001001 CSS pixels
per event because the native adapter converts deltas through 32-bit floats.
An idealized 25.2-pixel sequence therefore cannot establish cache reuse for
the measured workload. Preserving the original native wheel doubles remains
an unintegrated prototype without performance credit.

The bounded fractional-phase cache prototype passed its CPU pixel tests but
failed the GPU comparison at its first reused frame: frame 5, scroll 126 CSS
pixels, scale 2, cached byte 115 versus full-repaint byte 102 at offset
171,576. The scene includes overlapping translucent shapes, forced MSAA and
a vector path. The prototype is rejected; no cache behavior or wheel adapter
change has been enabled. Compilation and both wheel-dispatch test modes
passed. The GPU runtime and enclosing guard exited 1; the 3 GiB guard recorded
peak RSS 906,117,120 bytes. Commands, exits and raw output are retained in
`scroll-raster-phase-prototype.json`, `scroll-phase-prototype-v2-guard.json`
and `scroll-raster-phase-gpu-prototype.log`. CPU correctness alone did not
establish GPU pixel correctness.

A cache-state probe in the second root-fill diagnostic did not load because
the measurement tool replaced `DYLD_INSERT_LIBRARIES`; those absent counters
are inconclusive. The corrected third diagnostic uses `--insert-library`
and validates the actual executable header, image path and symbol segment
ranges. Both startup and input records show no allocated scroll-cache pixels
and no shared-recording path. Consequently, cache eligibility must be
resolved before a fractional-phase cache can help this page. The validated
probe's command, identities and state records are retained in
`scroll-cache-diagnostic-v3-result.json`; no timing credit is assigned to it.
The instrumented build subsequently identified `begin_css_effect_layer` as
the unsupported command on both the original frozen fixture and the live
SOCKS page. Actual input records show the other gates passing: zoom 1,
culling enabled, viewport origin following document scroll and shared
recording inactive. Neither page currently enters the viewport scroll-cache
fast path. The command's generic zero bounds do not describe its effect clip.

An independent read-only opacity probe validated its executable header,
symbol ranges and 56-byte group record before observing actual input. Both
pages paint normal-blend groups at opacity 0.800000012. Typical clips are
81 by 59 or 60 device pixels, while each group allocates a 2,048 by 1,696
bitmap. This supports investigating allocation reuse while preserving the
original device space; it does not establish an optimization or a frame rate.
The instrumented executable SHA-256 is
`94aa1cdc5cc9f66a6b24889a9ec63115fe913dc64fbfe8c0dca39b8ceb2f24f8`.
Commands, identities, raw browser logs and exits are retained in
`scroll-eligibility-{diagnostic,live-diagnostic}-result.json`,
`opacity-group-{frozen,live}-diagnostic-result.json` and
`opacity-group-probe-identity.json`. Both diagnostic browser series exited 0;
their timings receive no performance credit.

The native scroll-raster tests passed with diagnostics both disabled and
enabled. The current-V focused test compiled successfully and then passed
at runtime with the pinned bundle's dylib directory supplied explicitly.
Its runtime guard exited 0 with peak RSS 39,305,216 bytes. Earlier attempts
failed on a missing include path and then a missing runtime dylib; neither
executed the tests. Those failures remain recorded alongside the successful
`scroll-eligibility-focused-runtime-result.json` and
`scroll-eligibility-focused-runtime-guard.json`.

A fresh availability request through `socks5h://127.0.0.1:1337` returned HTTP
200 on October 26. The thread had grown to 222 posts and 482,754 response bytes,
compared with the saved 154-post fixture. Its response SHA-256 is
`fbfce9f74a54d5de4b8444e9848143cc30bb37ea6de63d2697be97153013ad14`;
the command, timestamp, title and exit 0 are retained in
`live-availability-20261026.json`. A successful fetch establishes availability,
not browser readiness or scrolling performance. The eligibility checks above
also verified the requested document title before their settle and input
periods on both pages.

## Bounded opacity-canvas reuse

Commit `7032ea1b` reuses up to two idle opacity-group bitmap contexts, bounded
by 32 MiB of pixel storage. It preserves the original full-canvas extent,
color space, transform and compositing math. Each group owns its context
until release; release clears its clipped write region, and acquisition
resets graphics state, paths, text geometry and context antialiasing switches.
Idle cleanup and memory pressure discard the pool. Oversized groups retain
the allocation path.

A separate read-only diagnostic validated the executable header, symbol
ranges and group ABI, then distinguished new bitmap generations from reused
addresses. During actual wheel input, the frozen control recorded 773 groups
and zero reuse; the frozen candidate recorded 764 groups and 761 reuses; the
live candidate recorded 767 groups and 764 reuses. All three recorded zero
invalid groups. Diagnostic timings receive no performance credit. Commands,
identities and counters are retained in `opacity-pool-probe-identity.json`
and `opacity-pool-*-diagnostic-result.json`.

Both optimized and ASan/UBSan native tests passed 2,304 exact comparisons
each, covering changing dimensions and color spaces, nested ownership,
fractional clips and transforms, state reset, retained image snapshots,
eviction, overflow and budget limits. The 3 GiB native-check guard exited 0
with sampled peak RSS 465,321,984 bytes. The standard production build and
headless startup passed. All 13 control/candidate browser image comparisons
were pixel-exact: the 11 screenshot smoke cases and nested-opacity fixtures
at 1x and 2x. Seven upstream smoke cases passed; `inline-node`, `ordered-list`,
`text-decorations` and `default-ignorable-code-points-not-painted` remain
pre-existing conformance failures in both modes.

The control and candidate use the same executable and native libraries;
`VOX_DISABLE_OPACITY_CANVAS_POOL=1` disables only this pool for the control.
The pinned executable SHA-256 is
`10645512ab9992c87430d4d626678a194cb55767559c40d19c0a7d2fe1528b53`.
Graphite SHA-256 is
`b5cccbe30e94b3080e7a7b370b4f31db66bc4dbf6a060967f3407af417cc0687`;
Skia SHA-256 is
`69ae7b64a6045a99c6e84dfcdb6a09466cdeb6b24873abc2f13ba407837ddfa1`;
Dawn SHA-256 is
`cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52`.
The completed standard build was pinned from a concurrent build whose source
manifest verifies unchanged production inputs throughout compilation. Its
only manifest change was an excluded test file. Full provenance, including
the native sources' before/after hashes, is retained in
`opacity-pool-clean-standard-build-provenance.json` and
`opacity-pool-build-identity.json`.

The following eight unprofiled trials alternate control and candidate twice
on each route. All use the protocol above, including title readiness, the
20-second settle period, fresh processes and private profiles. The actual
wheel increment remains approximately 25.200001001 CSS pixels. Frozen runs
start from the same archived cache template, SHA-256
`f819364b2d07047045f6203829e9ec23922499cf540ec41d099349d2ed57b5ea`.
Live runs start with empty caches and explicitly select
`VOX_PROXY=socks5h://127.0.0.1:1337`; this override takes precedence over the
ambient HTTP proxy, and the thread host is outside `NO_PROXY`. Every live
trial launches the temporarily installed pinned bundle with all four binary
hashes verified. The previously installed bundle was restored afterward.

| Trial | Scroll publications/s | Median / p95 / maximum interval (ms) | Over 16.67 ms | Moving intervals / measured publications / inputs |
| --- | ---: | --- | ---: | --- |
| opacity-pool-control-frozen-1 | 40.90 | 21.84 / 47.65 / 71.96 | 69.85% | 262 / 284 / 360 |
| opacity-pool-candidate-frozen-1 | 42.37 | 21.32 / 50.72 / 70.90 | 66.42% | 265 / 296 / 360 |
| opacity-pool-control-frozen-2 | 40.71 | 21.86 / 50.29 / 74.47 | 69.41% | 255 / 283 / 360 |
| opacity-pool-candidate-frozen-2 | 42.89 | 20.46 / 47.54 / 71.15 | 67.17% | 265 / 294 / 360 |
| opacity-pool-control-live-1 | 45.31 | 18.18 / 42.04 / 73.87 | 66.55% | 284 / 315 / 360 |
| opacity-pool-candidate-live-1 | 46.49 | 18.22 / 44.53 / 67.20 | 63.45% | 290 / 320 / 360 |
| opacity-pool-control-live-2 | 45.19 | 18.27 / 51.73 / 68.17 | 65.59% | 279 / 309 / 360 |
| opacity-pool-candidate-live-2 | 45.55 | 17.97 / 42.75 / 78.63 | 63.16% | 285 / 320 / 360 |

| Trial | Actual input Hz | First-to-last input period (s) | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- |
| opacity-pool-control-frozen-1 | 56.05 | 6.405 | 131.02 / 0.17 |
| opacity-pool-candidate-frozen-1 | 57.40 | 6.255 | 128.99 / 0.19 |
| opacity-pool-control-frozen-2 | 57.31 | 6.264 | 131.22 / 0.16 |
| opacity-pool-candidate-frozen-2 | 58.10 | 6.179 | 129.32 / 0.16 |
| opacity-pool-control-live-1 | 57.27 | 6.269 | 174.10 / 6.51 |
| opacity-pool-candidate-live-1 | 57.55 | 6.238 | 174.65 / 0.72 |
| opacity-pool-control-live-2 | 58.14 | 6.174 | 168.89 / 8.27 |
| opacity-pool-candidate-live-2 | 57.38 | 6.257 | 186.93 / 0.19 |

Every browser completed 360 inputs, moved the document, retained its binary
identity and exited 0. Total completed publications, including those outside
the measured window, were respectively 291, 304, 290, 303, 323, 329, 317 and
329. Throughput above uses the full first-to-last input window and counts
scroll changes separately from animation. It measures native publication,
not physical display presentation.

Observed throughput increased by 3.58% and 5.36% in the frozen pairs and
2.61% and 0.81% in the live pairs. Tail latency also regressed: frozen pair
one's p95 rose from 47.65 to 50.72 ms, live pair one's p95 rose from 42.04 to
44.53 ms, and live pair two's maximum rose from 68.17 to 78.63 ms. Its leading
gap also rose from 168.89 to 186.93 ms. Two pairs do not establish statistical
significance. The 18-CPU host's one-minute load averages before/after each
trial were 2.22/2.55, 2.55/2.35, 2.35/3.03, 3.03/4.59, 4.59/3.98,
3.98/3.03, 3.03/2.51 and 2.51/2.51. Per-trial load records and process
snapshots are retained; ambient load remains a limitation. These figures
cannot be compared with different build families as an isolated pool gain.
**Smooth 60 fps remains unmet:** approximately 63% of the live candidate's
scroll intervals still exceed the frame budget.

The complete browser-validation guard and child exited 0, with a 3 GiB limit,
sampled peak RSS 1,140,899,840 bytes and elapsed time 439.82 seconds. Raw
commands, exits, timestamps and summaries are in
`opacity-pool-validation-commands.json`, `opacity-pool-pixel-comparisons.json`,
`opacity-pool-trial-summary.json`, each trial's `run.json` and `summary.json`,
and `opacity-pool-validation-retry2-guard.json`. Earlier failures are retained:
a native test initially lacked CoreFoundation at link time; a build whose
source changed during compilation was rejected before measurement; and a
validation launch ran out of disk space before starting the browser. None
supplies passing evidence or performance credit.

## Independent small-shape tile batches

Commit `cfe0298f` queues the independent Chromium tiles of one small shape
before one synchronous GPU submission. Each tile keeps its original surface
dimensions, device coordinates, MSAA mode and immutable CPU backdrop. CPU
glyphs and other leaves retain their paint order. Failure publishes none of
the batch's CPU output. Temporary work is bounded to 64 jobs, one million
compact pixels and eight million original GPU tile pixels; larger work uses
the existing serial path. `VOX_DISABLE_SHAPE_TILE_BATCH=1` selects that path.

The focused checks passed 10,112 exact GPU tile comparisons against full
surface draws, plus 6,912 serial-grid ownership/backdrop comparisons in both
optimized and ASan/UBSan runs. Existing region, compositing, MSAA and native
backdrop regressions passed. The production native libraries and headless
startup passed; the V executable's unsigned bytes match the preceding
production build. The native build/check guard exited 0 with sampled peak
RSS 693,125,120 bytes. All 13 control/candidate browser screenshots remained
pixel-exact. The same seven upstream smoke cases passed, and the same four
pre-existing conformance failures listed above remained in both modes.

Separate, unprofiled diagnostic launches established that the batch executes
during actual wheel input on both frozen and live pages. They recorded
multiple GPU readbacks sharing one submission; the disabled control recorded
no batches. These diagnostic timings receive no performance credit. Raw
counters are in `tile-batch-*-diagnostic-result.json` and browser logs.

The control and candidate below use identical binaries, with only the batch
switch changed. The freshly signed executable SHA-256 is
`3764c693711dbf8bd4a2810a3e7af2c684cfe668c17849274a1a636737b61bb5`;
Graphite is `23eaccf96e0bf85b56350784606e39ee4d7addc07884ba2956a7f9be36a56b59`;
Skia is `b5c00fd68ce5a4cb8fb4579ebee148517f62e489d7bcc074c23af8e0f8143ac6`;
Dawn remains `cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52`.
The immutable native source snapshot, official compiler commands and unsigned
executable comparison are retained in `tile-batch-source-identity.json`,
`tile-batch-graphite-command.json`, `tile-batch-build-identity.json` and
`tile-batch-main-provenance.json`. The snapshot includes concurrent native
image changes; they are identical in this series' control and candidate.
Do not compare across build families to assign batching credit.

These eight trials use the preceding protocol unchanged: 1024x764 CSS viewport,
2x backing scale, matching title followed by 20 seconds settling, nominal
60 Hz precise wheel input, 360 events, reversal every 120 events, fresh
processes/private profiles and approximately 25.200001001 CSS pixels per
event. Frozen trials use the same archived cache and private TLS replay;
live trials use empty caches and explicit `socks5h://127.0.0.1:1337`. Each live
trial directly launches the temporarily installed candidate, verifying all
four binary hashes. The prior installed bundle was restored afterward.

| Trial | Scroll publications/s | Median / p95 / maximum interval (ms) | Over 16.67 ms | Moving intervals / measured publications / inputs |
| --- | ---: | --- | ---: | --- |
| tile-batch-control-frozen-1 | 44.68 | 19.86 / 43.83 / 61.08 | 65.83% | 278 / 314 / 360 |
| tile-batch-candidate-frozen-1 | 45.78 | 19.12 / 39.54 / 70.34 | 64.34% | 286 / 331 / 360 |
| tile-batch-control-frozen-2 | 42.74 | 20.76 / 49.70 / 69.17 | 64.93% | 268 / 292 / 360 |
| tile-batch-candidate-frozen-2 | 45.31 | 20.29 / 41.89 / 66.10 | 60.00% | 285 / 330 / 360 |
| tile-batch-control-live-1 | 45.96 | 17.97 / 46.45 / 68.05 | 64.46% | 287 / 326 / 360 |
| tile-batch-candidate-live-1 | 47.48 | 17.02 / 48.91 / 66.18 | 54.61% | 293 / 335 / 360 |
| tile-batch-control-live-2 | 44.79 | 17.44 / 56.98 / 74.65 | 61.21% | 281 / 317 / 360 |
| tile-batch-candidate-live-2 | 45.74 | 17.52 / 48.40 / 72.02 | 64.66% | 283 / 314 / 360 |

| Trial | Actual input Hz | First-to-last input period (s) | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- |
| tile-batch-control-frozen-1 | 57.70 | 6.222 | 166.52 / 0.15 |
| tile-batch-candidate-frozen-1 | 57.47 | 6.247 | 172.76 / 0.20 |
| tile-batch-control-frozen-2 | 57.25 | 6.270 | 169.74 / 0.21 |
| tile-batch-candidate-frozen-2 | 57.08 | 6.290 | 126.04 / 0.18 |
| tile-batch-control-live-1 | 57.49 | 6.244 | 175.32 / 0.13 |
| tile-batch-candidate-live-1 | 58.17 | 6.171 | 177.25 / 0.19 |
| tile-batch-control-live-2 | 57.22 | 6.274 | 176.44 / 0.13 |
| tile-batch-candidate-live-2 | 58.02 | 6.188 | 128.05 / 0.16 |

All trials moved the document, completed 360 inputs and exited 0 with stable
build identities. Total completed publications were respectively 322, 340,
300, 337, 334, 344, 325 and 322. Throughput counts scroll changes separately
from animation over the entire first-to-last input period; this endpoint
measures native publication, not physical display presentation.

Observed throughput increased 2.47% and 6.01% in the frozen pairs and 3.30%
and 2.12% in the live pairs. Regressions remain: frozen pair one's maximum
interval rose from 61.08 to 70.34 ms and its leading gap grew; live pair one's
p95 rose from 46.45 to 48.91 ms; live pair two's deadline-miss fraction rose
from 61.21% to 64.66%. Two pairs do not establish statistical significance.
The host's one-minute load averages before/after each trial were 3.38/3.57,
3.57/3.42, 3.42/4.14, 4.05/3.71, 3.71/2.88, 2.88/2.65, 2.65/2.81 and
2.81/2.74. Ambient load remains a limitation. **Smooth 60 fps remains unmet.**

The browser-validation guard and child exited 0, with a 3 GiB limit, sampled
peak RSS 1,082,048,512 bytes and elapsed time 430.21 seconds. Commands, actual
timestamps, exits and summaries are in `tile-batch-validation-commands.json`,
`tile-batch-pixel-comparisons.json`, `tile-batch-trial-summary.json`, each
trial's `run.json`/`summary.json` and `tile-batch-browser-validation-guard.json`.

## Rejected glyph raster buffer pool experiment

The prototype reused provider-released pixel allocations instead of
allocating and zeroing another vector on every cache miss. Its pool kept at
most eight idle allocations and four MiB of pixel storage. Its
retained glyph cache charged each allocation's full capacity, including unused
pixels, against its eight MiB limit. Quartz owned each allocation until its
last image provider releases it; purge generations prevented delayed callbacks
from refilling an emptied pool. Every used pixel was initialized by a complete
backdrop copy or transparent clear before drawing. Raster dimensions, text
coverage, clipping and image compositing were unchanged.
`VOX_DISABLE_GLYPH_RASTER_POOL=1` selected the preceding allocation path.

The preceding live profile selected this work: among 4,018 main-thread samples,
589 entered glyph drawing. Its main branch included 66 samples in glyph raster
zero-initialization and 84 in cache insertion/eviction; these inclusive counts
are diagnostic, not timing credit. The executable and Skia UUIDs, actual loaded
image ranges and sampled symbol addresses were checked against `nm` output.
See `tile-batch-native-sample.txt`, `tile-batch-profile-symbol-validation.json`
and `tile-batch-profile-glyph-children.json`.

The focused suite passed 16,416 exact comparisons against the preceding
production text library in both optimized and ASan/UBSan modes. It covers
fractional scroll phases, changing backdrops, clips, transforms, color spaces,
RGBA/BGRA storage, shadows and smoothing. Provider lifetime, concurrent
release, oversized allocation accounting, purge generations and pool limits
also passed. Existing native checks passed 720 compositing, 6,240 glyph-cache,
1,080 shape-backdrop and 288 tiled-image comparisons, plus the clipping cases.
The production native build and headless startup passed. The build/check guard
and child exited 0 with sampled peak RSS 705,839,104 bytes and elapsed time
32.46 seconds. An earlier interrupted attempt is preserved under
`glyph-pool-attempt1-*`; it receives no acceptance or timing credit.

The unsigned V executable remained byte-identical to the preceding build.
Freshly signed SHA-256 values are:

- Vox: `8745d92aca5c0e5488b43e0d29f1d233acbdfc231babf17ab0f52fb52a81d14a`.
- Graphite: `23eaccf96e0bf85b56350784606e39ee4d7addc07884ba2956a7f9be36a56b59`.
- Skia: `c4fbc23f7ce0602df3f06a713ebc1d7a9603370fa414bf73b5d4307733466810`.
- Dawn: `cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52`.

The immutable source snapshot and compiler commands are retained in
`glyph-pool-source-identity.json`, `glyph-pool-build-check-commands.json`,
`glyph-pool-build-identity.json` and `glyph-pool-main-provenance.json`. Both
modes share all binaries and source inputs, including concurrent native image
changes already present in the preceding snapshot; only the pool switch
changes. Cross-family timings cannot isolate this pool's effect.

The experiment was rejected and its implementation removed from the working
source after validation. The immutable prototype, tests and owned patch remain
under `glyph-pool-source/` and `glyph-pool-owned.patch` for reproducibility.
There is no production glyph-pool switch or performance credit from this work.

All 13 control/candidate native viewport comparisons were pixel-exact: eleven
smoke captures and the nested opacity fixture at logical and Retina scales.
Seven smoke references passed upstream; the four existing failures
(`inline-node`, `ordered-list`, `text-decorations` and
`default-ignorable-code-points-not-painted`) remained unchanged. Separate
frozen and live diagnostics each confirmed sixteen provider-released buffer
reuses during actual wheel input; the disabled control confirmed zero.

The protocol matched the preceding tile-batch experiment: original URL and
required document title, twenty-second settle after title readiness,
1024×764 CSS viewport at scale two, fresh process and private profile per trial,
360 native precise wheel events at nominal 60 Hz, delta 12 (actual CSS step
25.200001001), direction reversal every 120 events. Frozen trials replayed the
archived original HTTPS response with private TLS trust and no forwarding;
live trials used `socks5h://127.0.0.1:1337`, empty cache and the temporarily
installed candidate. The prior installed bundle was restored afterwards.
Both switch states used identical signed binaries. Input-period throughput
counts scroll-changing publications after native `updateLayer` completion;
this endpoint does not measure physical display presentation.

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| glyph-pool-control-frozen-1 | 46.77 | 18.88 / 40.01 / 58.21 | 62.67% | 292 / 337 / 360 |
| glyph-pool-candidate-frozen-1 | 46.77 | 19.15 / 38.93 / 65.85 | 63.76% | 287 / 334 / 360 |
| glyph-pool-control-frozen-2 | 47.94 | 18.61 / 39.10 / 55.14 | 59.46% | 296 / 346 / 360 |
| glyph-pool-candidate-frozen-2 | 45.32 | 19.92 / 40.09 / 67.67 | 63.51% | 285 / 325 / 360 |
| glyph-pool-control-live-1 | 40.16 | 21.00 / 57.27 / 73.53 | 83.53% | 255 / 264 / 360 |
| glyph-pool-candidate-live-1 | 45.51 | 17.96 / 47.06 / 63.87 | 62.63% | 281 / 326 / 360 |
| glyph-pool-control-live-2 | 45.04 | 18.12 / 47.90 / 67.70 | 62.37% | 279 / 310 / 360 |
| glyph-pool-candidate-live-2 | 43.25 | 18.19 / 48.05 / 216.13 | 65.43% | 269 / 310 / 360 |

| Trial | Actual input Hz | Input period, s | Leading / trailing publication gap, ms |
| --- | ---: | ---: | --- |
| glyph-pool-control-frozen-1 | 57.50 | 6.244 | 168.10 / 0.21 |
| glyph-pool-candidate-frozen-1 | 58.51 | 6.136 | 169.57 / 0.16 |
| glyph-pool-control-frozen-2 | 58.14 | 6.175 | 123.89 / 0.18 |
| glyph-pool-candidate-frozen-2 | 57.09 | 6.289 | 128.17 / 6.46 |
| glyph-pool-control-live-1 | 56.54 | 6.350 | 174.06 / 17.96 |
| glyph-pool-candidate-live-1 | 58.14 | 6.175 | 185.09 / 19.21 |
| glyph-pool-control-live-2 | 57.95 | 6.195 | 169.07 / 0.17 |
| glyph-pool-candidate-live-2 | 57.73 | 6.219 | 119.58 / 0.17 |

Frozen throughput changed +0.01% and −5.46%; live changed +13.31% and −3.96%.
Three pairs had a higher deadline-miss fraction, and the second live candidate
had a 216.13 ms interval versus its control's 67.70 ms maximum. These mixed
results do not establish an improvement. Ambient host load also varied; the
one-minute load before/after the eight trials was 3.62/3.12, 3.12/2.93, 2.93/3.05, 3.93/4.32, 4.32/6.77, 6.77/5.29, 5.29/4.58, 4.58/6.28. **Smooth 60 fps remains unmet.**

All eight trials completed their 360 inputs, moved the document, retained the
expected build identity and exited 0. The browser guard and child exited 0
with a 3 GiB budget, sampled peak RSS 1,081,638,912 bytes and elapsed 431.09 s.
Raw commands, actual input timestamps, cache and response hashes, publications,
exits and summaries remain in `glyph-pool-validation-commands.json`,
`glyph-pool-pixel-comparisons.json`, `glyph-pool-trial-summary.json`, each
trial's `run.json`/`summary.json`, the diagnostic result files and
`glyph-pool-browser-validation-guard.json` in the evidence directory above.

### Rejected small-patch load reuse (2026-10-26)

The `patch-load-v1` experiment omitted the full GPU target clear when an
existing small-shape patch replaced every pixel in its conservative readback
rectangle with the input backdrop. Background-free draws still cleared.
It passed 1,920 independent full/region/batch pixel comparisons, including
reused targets, translucent backdrops, compound shapes and both raster modes;
the same cases passed AddressSanitizer and UndefinedBehaviorSanitizer.
The cache, batch, region, composite, backdrop and grid checks also passed.
Separate browser diagnostics verified sixteen actual input-window executions
per candidate and zero per disabled control, with the loaded library path
validated. Thirteen native screenshot pairs were pixel-identical; the four
existing upstream smoke differences were identical in both modes.

Four alternating unprofiled trials used the sealed disk fixture, original
HTTPS URL, private TLS trust, denied external network, required title,
20-second settle, 1024×764 CSS viewport at scale two, fresh process/profile,
and 360 nominal 60 Hz precise wheel inputs with delta 12 and reversal every
120 inputs. The endpoint is changed Cocoa layer publication after
`updateLayer`, not physical scanout. All trials moved the document and exited
0 with unchanged binaries and successful archived responses.

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| control-1 | 25.87 | 34.56 / 74.74 / 99.59 | 99.44% | 177 / 186 / 360 |
| candidate-1 | 25.67 | 35.52 / 68.31 / 111.07 | 100% | 174 / 185 / 360 |
| control-2 | 25.12 | 35.11 / 72.75 / 89.67 | 98.79% | 165 / 173 / 360 |
| candidate-2 | 25.74 | 35.40 / 68.59 / 82.25 | 99.40% | 167 / 177 / 360 |

| Trial | Actual input Hz | Input period, s | Leading / trailing publication gap, ms | First scroll publication, ms |
| --- | ---: | ---: | --- | ---: |
| control-1 | 52.48 | 6.841 | 159.84 / 19.97 | 259.43 |
| candidate-1 | 52.96 | 6.779 | 144.71 / 22.28 | 223.54 |
| control-2 | 54.66 | 6.567 | 150.53 / 19.86 | 240.20 |
| candidate-2 | 55.32 | 6.489 | 143.26 / 31.85 | 222.73 |

The throughput changes were −0.80% and +2.43%; median intervals and deadline
miss fractions regressed in both candidates. This does not establish a useful
gain, so the implementation and its production switch were removed. The
18-CPU host's one-minute load before/after each trial was 24.28/25.90,
25.90/23.84, 23.37/22.53 and 22.53/22.09; variation and contention remain
material. Trials began at 06:17:31.709, 06:18:03.589, 06:18:35.854 and
06:19:07.547 UTC. **Smooth 60 fps remains unmet.**

Evidence is retained under `Build/pol-scroll-20261025-2210/` in
`patch-load-v1-source/`, `patch-load-v1-owned.patch`,
`patch-load-v1-build-identity.json`, `patch-load-v1-focused-checks/`,
`patch-load-v1-validation/` and `patch-load-v1-trial-summary.json`.
The signed candidate's Vox/Skia/Graphite/Dawn SHA256 values are
`b6c8a5514bef0082723c5a003f277c750bcd11a9bdb91c49327be0923d1f0b83`,
`e8dbb3c2078f2ecc248a87b37693875ece64fd92741fe38f280bf0424050867f`,
`a9f0d19177154232d915c13ff4256c8f5d8a08c7f8fa69d7d5e1c9b996693f6a`
and `cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52`.
The browser/build guard and child exited 0, sampled peak RSS 921,452,544
bytes within 12 GiB, elapsed 489.90 seconds.

### Rejected descriptor index (2026-10-26)

`cache-index-v2` added hash buckets in front of the raster cache's exact
source, descriptor and backdrop comparisons, preserving MRU order and byte
validation. Its focused differential test passed 64,000 operations with
10,401 identical hits across bounded capacities, collisions, padding,
mutations, delayed completion and eviction. Native cache, batch and region
regressions and AddressSanitizer/UndefinedBehaviorSanitizer checks passed.
Separate diagnostics confirmed the indexed lookup ran during actual input,
with fewer candidate descriptors and the expected loaded library path.
Thirteen native screenshot pairs were identical; the same four pre-existing
upstream screenshot differences remained in both modes.

The four alternating unprofiled runs used the sealed disk fixture at its
original HTTPS URL, denied external network, private TLS trust, fresh
process/profile, required title, 20-second settle, 1024×764 CSS viewport at
scale two, and 360 nominal 60 Hz precise wheel inputs (delta 12, reverse
every 120). The endpoint is changed native layer publication after
`updateLayer`, not physical display scanout.

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| control-1 | 43.67 | 21.06 / 43.16 / 70.97 | 64.34% | 272 / 324 / 360 |
| candidate-1 | 44.99 | 20.15 / 42.25 / 60.74 | 64.29% | 280 / 333 / 360 |
| control-2 | 45.72 | 19.48 / 44.05 / 60.79 | 61.65% | 279 / 326 / 360 |
| candidate-2 | 43.65 | 20.66 / 44.94 / 63.61 | 65.06% | 269 / 314 / 360 |

| Trial | Actual input Hz | Input period, s | Leading / trailing publication gap, ms | First scroll publication, ms |
| --- | ---: | ---: | --- | ---: |
| control-1 | 57.63 | 6.229 | 101.06 / 0.23 | 160.09 |
| candidate-1 | 57.68 | 6.224 | 95.36 / 18.46 | 124.89 |
| control-2 | 58.83 | 6.102 | 98.44 / 0.25 | 155.26 |
| candidate-2 | 58.26 | 6.162 | 107.68 / 0.18 | 139.07 |

Throughput changed +3.03% and −4.52%; the second candidate also regressed
median, p95 and deadline misses. The index was removed because these trials
do not establish a repeatable gain. All runs moved the requested document,
completed 360 inputs, retained binary identities and exited 0. The 18-CPU
host's one-minute load before/after each run was 4.63/5.27, 5.27/6.86,
6.95/6.84 and 6.61/5.99. Start times were 06:43:52.498, 06:44:21.940,
06:44:51.354 and 06:45:21.292 UTC. Lower contention than the preceding
25–26 fps trials also raised controls; that cross-session change is not an
optimization gain. **Smooth 60 fps remains unmet.**

Evidence under `Build/pol-scroll-20261025-2210/` includes
`cache-index-v2-source/`, `cache-index-v2-owned.patch`,
`cache-index-v2-source-identity.json`, `cache-index-v2-build-identity.json`,
`cache-index-v2-build-check-commands.json`, `cache-index-v2-validation/`
and `cache-index-v2-trial-summary.json`. Vox/Skia/Graphite/Dawn SHA256 values:
`47794dbe646a2e8aabd74b04c1672b0084ed7648eab66e22d4f924a71975fa56`,
`e8dbb3c2078f2ecc248a87b37693875ece64fd92741fe38f280bf0424050867f`,
`262c99e2c90aad90a00859faa89ab3b654e8297eafbda1789ab3ca4d3ab414e6`,
`cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52`.
The build/browser guard and child exited 0, with sampled peak RSS
924,073,984 bytes within 12 GiB and elapsed 394.53 seconds.

A separate fractional-rectangle coverage oracle rejected a CPU-only edge
formula: 184 of 480 cases differed from the retained GPU implementation,
including coverage ties and one-byte color rounding. No approximate edge
rasterizer was installed. `fractional-rect-oracle.cpp`, its commands/log and
`fractional-rect-oracle-guard.json` retain this diagnostic (guard/child 0,
117,112,832-byte sampled peak within 3 GiB, elapsed 1.07 seconds); its exit
code records oracle completion, not pixel equivalence or scrolling credit.

### Rejected direct RGBA glyph raster (2026-10-26)

Two prototypes rasterized glyphs directly into the document's RGBA byte order
to avoid backdrop/output channel conversion. The first failed a focused pixel
comparison for RGBA grayscale text with smoothing flags zero. Restricting the
change to Chromium text with an existing backdrop still failed at smoothing
flags 48. Both implementations were removed. Neither reached scrolling trials
or supplies performance credit; text pixels retain the existing raster path.

Immutable sources, commands, failure logs and the decision are retained in
`Build/pol-scroll-20261025-2210/glyph-rgba-v1-source/`,
`glyph-rgba-v2-source/`, their source identity manifests, focused output
directories and `glyph-rgba-rejected.json`. Both focused guards completed with
child exit 1 within 3 GiB. Their sampled peak RSS/elapsed values were
406,634,496 bytes/2.81 seconds and 407,748,608 bytes/6.65 seconds respectively,
as recorded in `glyph-rgba-v1-focused-guard.json` and
`glyph-rgba-v2-focused-guard.json`.


### Rejected fractional root-border extension (2026-10-26)

The root-layer prototype preserved the original tile coordinates and GPU
coverage while reading only fractional edge bands, batching independent tile
readbacks behind one wait. Normal and ASan/UBSan checks passed: 74,880 exact
serial batch comparisons, 6,336 atomic rejection cases, 4,392 original-renderer
rounded comparisons, and 1,440 exact root replay comparisons. The production
native build, matching-baseline clip/glyph/image regressions, public exports,
memory check and headless startup also passed.

Actual-input eligibility rejected this optimization for the archived thread.
Both candidate trials completed all 120 wheel inputs, but the extended path
executed zero times during the first input window and only once during the
second. Each candidate recorded one extended draw overall. A matching title
and successful navigation did not make this loading/header path representative
of scrolling. The two controls recorded no extended draws. Screenshot and
unprofiled timing stages were deliberately not reached, and the prototype was
removed. This supplies no scrolling performance credit; smooth 60 fps remains
unmet.

Evidence under `Build/pol-scroll-20261025-2210/` includes the sealed
`root-stroke-v1-source/`, source/build identity manifests, owned patch,
focused/build command logs, `root-stroke-v1-validation/eligibility/`, and
`root-stroke-v1-rejected.json`. The focused guard/child exited 0 with sampled
peak RSS 704,888,832 bytes within 3 GiB and elapsed 34.17 seconds. The build and
browser guard/child exited 1 at the eligibility assertion, with sampled peak
RSS 875,790,336 bytes within 12 GiB and elapsed 138.49 seconds. All four browser
processes exited 0; failure records insufficient fast-path use, not a crash.

### Rejected glyph-cache bypass (2026-10-26)

Bypassing the glyph raster cache executed during actual wheel input and kept
all 13 control/candidate screenshot pairs identical. Matching-baseline native
clip, composite, glyph, shape-backdrop and image tests also passed. It produced
no repeatable scrolling gain, so the production cache remains enabled.

| Alternating trial | Scroll fps | Median / p95 / max interval (ms) | Over 16.67 ms | Moving / publications / inputs |
| --- | ---: | --- | ---: | --- |
| Cache control 1 | 43.41 | 21.25 / 46.32 / 64.83 | 62.17% | 267 / 301 / 360 |
| Bypass 1 | 41.88 | 21.54 / 45.87 / 71.78 | 64.23% | 260 / 301 / 360 |
| Cache control 2 | 40.83 | 21.92 / 52.97 / 64.18 | 66.54% | 254 / 289 / 360 |
| Bypass 2 | 41.90 | 22.68 / 42.96 / 69.88 | 65.28% | 265 / 292 / 360 |

Throughput uses each complete 6.15–6.32 second input window; actual input
delivery was 56.76–58.37 Hz. First publication gaps were 104.71–107.90 ms;
first counted scroll gaps were 136.19–168.80 ms, and trailing gaps were
0.19–0.26 ms. All four browser processes exited 0 with valid navigation and
completed inputs. The 18-CPU host's one-minute load ranged from 6.18 to 9.14;
the varying controls and mixed -3.51%/+2.61% changes do not establish a gain.
These are native layer publications after `updateLayer`, not display scanout.

Evidence under `Build/pol-scroll-20261025-2210/` includes the sealed
`glyph-bypass-v1-source/`, matching-baseline regression source manifest,
`glyph-bypass-v1-validation/` with eligibility, pixels, commands and raw timing,
and `glyph-bypass-v1-rejected.json` with timestamps, load and boundary gaps.
The browser driver recorded exit 0, but the outer resume guard's report is
empty; its final exit and peak memory cannot be recovered. This incomplete
guard evidence supplies no acceptance credit. Smooth 60 fps remains unmet.


### Rejected direct BGRA glyph replay (2026-10-26)

Drawing text directly into the fresh document backdrop avoided a separate
bitmap snapshot and glyph raster cache. Its guarded root-canvas path executed
in all 16 sampled input draws in each of two eligibility trials. The eight
focused normal and sanitizer checks passed, including 6,240 glyph comparisons,
48 snapshot cases and clip rejection. All 13 control/candidate screenshot
pairs were pixel-identical. The production build, native regressions, signing
and headless startup passed. The path still produced no scrolling gain and was
removed; its sealed patch remains in `glyph-inplace-integrated-v1-rejected-source/`.

| Alternating trial | Scroll fps | Median / p95 / max interval (ms) | Over 16.67 ms | Moving / publications / inputs |
| --- | ---: | --- | ---: | --- |
| Control 1 | 49.14 | 18.42 / 39.36 / 54.49 | 60.66% | 305 / 379 / 360 |
| Direct glyph 1 | 48.92 | 18.43 / 39.11 / 58.02 | 60.60% | 302 / 395 / 360 |
| Control 2 | 48.34 | 18.28 / 38.26 / 58.88 | 61.20% | 299 / 363 / 360 |
| Direct glyph 2 | 47.43 | 18.67 / 41.79 / 60.15 | 63.85% | 296 / 379 / 360 |

The complete first-to-last input windows lasted 6.17–6.24 seconds with actual
input delivery of 57.53–58.16 Hz. Leading publication gaps were 96.05–124.47 ms;
leading counted-scroll gaps were 123.59–180.24 ms. Trailing publication gaps
were 0.12–18.79 ms and trailing scroll gaps 0.19–26.14 ms. All four browsers
exited 0 with valid archived navigation and 360 inputs. Paired changes were
-0.44% and -1.88%. The 18-CPU host's one-minute load declined from 5.70 to 3.16;
these results cannot attribute the improvement over older controls to code.
The endpoint remains native publication after `updateLayer`, not scanout.
Smooth 60 fps remains unmet.

Evidence under `Build/pol-scroll-20261025-2210/` includes
`glyph-inplace-integrated-v1-summary.json` (every trial, hash, timestamp, host
load and boundary gap), `glyph-inplace-integrated-v1-validation/`, the sealed
source, and two separately sampled profiles in
`glyph-inplace-integrated-v1-profile/`. Both profiles validated the actual
executable UUID and symbol ranges. GPU submission/waits accounted for 956/2,694
and 1,118/3,058 samples inside the main draw routine. Image rendering accounted
for 562 and 683 samples; these diagnostics supply no unprofiled fps credit.
The focused guard exited 0 at 700,596,224 bytes sampled peak RSS in 19.76 s
within 3 GiB. The successful production/validation guard exited 0 at
10,440,474,624 bytes in 598.30 s within 12 GiB; earlier disk, wrapper and C
macro build failures are retained separately.

A second CPU fractional-rectangle oracle also failed exact pixels: its best
float coverage/rounding models differed in 100 of 240 cases, including MSAA
coverage outside the analytical edge. `fractional-rect-float-oracle-v2.cpp`
and its recorded output remain diagnostic evidence only.


### Rejected independent image-tile readback batching (2026-10-26)

Queuing independent image-tile readbacks before one GPU submission executed
throughout both actual-input eligibility trials: 16 bounded input records per
candidate, with 2–8 tile jobs sharing one submission. Controls used the serial
path. Normal and sanitizer checks each passed 7,808 exact batch comparisons
and 11 atomic rejection cases, alongside 1,920 GPU-region and 2,592 native
caller comparisons. All 13 browser screenshot pairs were pixel-identical.
Production signing, headless startup, document canvas, native regression and
graphics memory checks passed. Timings did not repeat the gain, so the
prototype was removed.

| Alternating trial | Scroll fps | Median / p95 / max interval (ms) | Over 16.67 ms | Moving / publications / inputs |
| --- | ---: | --- | ---: | --- |
| Serial control 1 | 44.71 | 20.45 / 42.25 / 71.42 | 61.87% | 278 / 321 / 360 |
| Image batch 1 | 46.15 | 19.07 / 42.27 / 60.71 | 63.07% | 287 / 327 / 360 |
| Serial control 2 | 44.47 | 20.53 / 40.47 / 65.90 | 62.50% | 272 / 322 / 360 |
| Image batch 2 | 44.38 | 20.19 / 42.07 / 64.73 | 66.43% | 280 / 320 / 360 |

These use the frozen original-origin archive and unchanged 1024×764 viewport,
2× backing scale, title-gated 20-second settle, and 360 precise wheel inputs.
Full input windows lasted 6.12–6.31 seconds; actual delivery was 56.90–58.69 Hz.
Leading publication gaps were 98.21–101.88 ms and leading counted-scroll gaps
126.77–160.91 ms. Trailing gaps were 0.21–0.97 ms. All four browsers exited 0
with valid document navigation and completed input. Paired throughput changes
were +3.22% and -0.20%, while both candidate deadline-miss fractions increased.
The 18-CPU host's one-minute load declined from 10.03 to 6.36; these trials
supply no repeatable optimization credit. The endpoint is completed native
layer publication after `updateLayer`, not physical display scanout. Smooth
60 fps remains unmet.

Evidence under `Build/pol-scroll-20261025-2210/` includes the sealed
`image-batch-v1-rejected-source/`, `image-batch-v1-summary.json`, production
source/build identities, focused logs, and `image-batch-v1-validation/` with
eligibility, pixels and every alternating trial. The focused guard/child
exited 0 at 784,138,240 bytes sampled peak RSS in 89.03 seconds within 3 GiB.
The production/validation guard/child exited 0 at 12,223,315,968 bytes in
681.77 seconds within 12 GiB. Earlier failed attempts remain separately.
The pinned executable SHA-256 is
`309468f5235acd8a1f388e311dcf0f1d8c7f7d5fb5d0ea6c44b71bdbc1cbc2e8`;
all library hashes and raw timestamps remain in the evidence manifests.

Two separate sampled runs in `image-batch-v1-profile/` validated the actual
Vox executable UUID and C/V symbol ranges. GPU waits accounted for 892/3,150
and 986/3,433 native drawing samples. Rounded rectangle calls accounted for
920 and 1,009 samples, and glyph calls for 630 and 622. These profiles are
diagnostics and supply no unprofiled scrolling performance credit.


### Rejected bounded GPU readback polling (2026-10-26)

Submitting asynchronously and polling for up to 200 microseconds before the
blocking wait did not remove the waits: all 32 sampled actual-input readbacks
across two eligibility trials exhausted that budget. The prototype was removed.
Normal and sanitizer completion/failure tests passed, alongside the existing
shape, rounded-parts, image, path, native clip and graphics-memory checks. All
13 control/candidate screenshot pairs were pixel-identical. The two screenshot
smoke commands each returned 1 for existing reference differences; their
control/candidate outputs matched exactly. Signing and headless startup passed.

| Alternating trial | Scroll fps | Median / p95 / max interval (ms) | Over 16.67 ms | Moving / publications / inputs |
| --- | ---: | --- | ---: | --- |
| Blocking control 1 | 45.90 | 19.98 / 38.68 / 61.72 | 63.41% | 287 / 347 / 360 |
| Bounded polling 1 | 37.91 | 24.18 / 47.91 / 69.01 | 83.87% | 248 / 260 / 360 |
| Blocking control 2 | 44.28 | 20.79 / 43.10 / 68.28 | 64.89% | 282 / 320 / 360 |
| Bounded polling 2 | 47.01 | 19.24 / 38.65 / 63.74 | 64.51% | 293 / 362 / 360 |

The frozen original-origin archive, viewport, backing scale, settle period and
wheel schedule were unchanged. Full input windows lasted 6.23–6.54 seconds;
actual delivery was 54.88–57.59 Hz. Leading publication gaps were 94.08–100.11 ms
and leading scroll gaps 123.33–158.55 ms. Trailing publication gaps were
0.12–18.82 ms and trailing scroll gaps 0.19–18.82 ms. Every browser exited 0
with valid navigation and 360 inputs. Paired changes were -17.41% and +6.15%;
the 18-CPU host's one-minute load varied from 3.04 to 5.88. This supplies no
repeatable optimization credit. The endpoint remains native layer publication
after updateLayer, not display scanout. Smooth 60 fps remains unmet.

Evidence under `Build/pol-scroll-20261025-2210/` includes
`readback-poll-v1-rejected-source/`, `readback-poll-v1-summary.json`,
`readback-poll-v1-focused/`, `readback-poll-v1-assembly/`, production identities
and `readback-poll-v1-validation/` with every raw trial, input timestamp and
load record. The focused guard/child exited 0 at 679,477,248 bytes sampled peak
RSS in 102.92 seconds within 3 GiB. The assembly/validation guard/child exited
0 at 934,182,912 bytes in 507.31 seconds within 12 GiB. This native-only build
retained the pinned V executable and Dawn library and rebuilt both the Metal
Graphite candidate and accepted Skia bridge; the latter removed the previously
rejected image-batch prototype from the artifact used for these trials.


### Rectangle prefetch correctness and eligibility checks (2026-10-26)

An opt-in prototype speculates on thin opaque underline rectangles across text
commands in the same raster layer. It leaves ordinary replay in order and
validates each actual backdrop before accepting a cached result. Clearing the
GPU cache between the reference render and prefetch forced cold misses: normal
and ASan/UBSan executions each passed 432 exact ordered comparisons. These
cover two grid sizes, 1×/2× scales, three MSAA modes, fractional positions,
clips, and intervening backdrop changes. Prefetch left the destination intact.
The 3 GiB runtime guard completed with child exit 0, sampled peak RSS
711,131,136 bytes and elapsed time 46.59 seconds.

A separate private backend compared a one-device-pixel patch guard for thin,
plain opaque rectangles against the full GPU renderer, bypassing the patch,
CPU and raster-cache paths in the reference. All 5,376 comparisons passed,
including 1,008 eligible reduced patches. Cases include cache misses and hits,
changed and transparent backgrounds, cropped edges, padded row pitches,
1×/2× scales, MSAA on/off, and fractional coordinates next to integer
boundaries. This diagnostic does not change the production patch guard.

Raw commands, source hashes, binaries and results remain under
`Build/pol-scroll-20261025-2210/rect-prefetch-v1/cold-cache-tests/` and
`rect-prefetch-guard-oracle/`, with runtime reports in
`rect-prefetch-v1/build-recovery-1/`. The first focused V compilation was
incorrectly capped at 3 GiB and was killed at 3,251,011,584 bytes sampled RSS;
its tests did not run. A subsequent compile attempt failed against a mismatched
ICU installation; that attempt likewise supplies no V test result. The resumed
pipeline reused a pinned production executable containing the exact prototype
sources and recorded its build provenance rather than treating the current,
independently changing checkout as the compiled source. Its corrected focused
V test command was conditional on actual-input eligibility and did not run.

Four alternating 120-input diagnostics completed for the original patch guard,
then four for a private one-device-pixel guard. Every browser exited 0, loaded
the required thread title, moved the document and requested only archived
responses. Neither candidate recorded prefetch cache calls or completed
prefetch batches at startup or during input. Ordinary replay continued to use
the existing cache:

| Patch guard | Trial | Sampled ordinary replay cache hits / calls during input | Recorded input prefetch batches |
| --- | --- | ---: | ---: |
| Original | control-1 | 436 / 1,024 | 0 |
| Original | candidate-1 | 448 / 1,024 | 0 |
| Original | control-2 | 419 / 1,024 | 0 |
| Original | candidate-2 | 457 / 1,024 | 0 |
| Reduced | control-1 | 399 / 980 | 0 |
| Reduced | candidate-1 | 493 / 1,024 | 0 |
| Reduced | control-2 | 459 / 1,024 | 0 |
| Reduced | candidate-2 | 466 / 1,024 | 0 |

The cache log is capped at 1,024 entries per phase; these are sampled counts,
not whole-run hit rates. Zero batch logs do not identify the blocking gate:
logging occurs only after native job collection. They do not establish that
cache margins are responsible or that V/native prefetch entry was reached.
Neither variant qualified for browser pixel comparisons or unprofiled
acceptance timing. The reduced guard also passed 432 exact ordered comparisons
in each of its normal and sanitizer control/candidate executions; it remains a
private experiment and does not change the production patch guard.

The completed pipeline's commands, provenance and all diagnostics are in
`rect-prefetch-v1/build-recovery-3/`, `rect-prefetch-v1/diagnostic/` and
`rect-prefetch-reduced-guard-v1/`. Its enclosing memory report is
`rect-prefetch-v1/queue-recovery-20261026-201058/guard.json`: child exit 0,
12 GiB budget, sampled peak RSS 937,476,096 bytes, elapsed 607.13 seconds.
Both eligibility decisions explicitly disable unprofiled acceptance. These
instrumented diagnostics supply no scrolling performance credit; smooth
60 fps remains unmet.

A subsequent read-only gate probe identified the rejection. It validated the
actual executable image and symbol ranges, called the compiled leaf/scanner
functions with the recorded V array layout, and observed native prefetch entry.
The executable's draw-loop disassembly also contains the prefetch call. Both
120-input archived-page trials reached eligible command groups; native entry
ran 484 and 466 times during input. The first 128 recorded input entries in
each trial all returned 0 with a 2048×384 root tile. That tile contains 786,432
device pixels, exceeding the prototype's 262,144-pixel admission limit. The
other recorded native state gates admitted those calls. The earlier absent
batch logs therefore cannot assess either patch margin's cache usefulness.

The probe and its exact ABI declarations, commands, symbols, disassemblies,
source and bundle identities, raw trials, and parsed diagnosis are retained in
`rect-prefetch-gate-diagnostic-v1/`; the complete draw disassembly is
`rect-prefetch-draw-disassembly.txt`. The enclosing report is
`rect-prefetch-gate-queue-20261026-222119/guard.json`: child exit 0, 12 GiB
budget, sampled peak RSS 855,113,728 bytes, elapsed 52.92 seconds. These
instrumented observations establish the blocking gate and supply no
performance credit. An expanded admission limit with batches split at the
backend's unchanged aggregate pixel limit still requires correctness,
actual-input eligibility, and unprofiled acceptance checks.

The expanded-grid prototype then passed 648 exact ordered comparisons in
each normal and ASan/UBSan execution, including the real 2048×384 root tile.
The focused 3 GiB runs exited 0 at sampled peaks of 103,645,184 and
710,737,920 bytes, in 37.72 and 61.18 seconds respectively. Four alternating
120-input diagnostics loaded the archived thread, moved its scroll position,
used only archived responses and exited 0. Prefetch still produced zero
batches during startup and input. Sampled ordinary input cache hits/calls
were 400/974, 468/1,024, 477/1,024 and 435/1,008 in control/candidate order.
These counters remain capped and do not establish whole-run hit rates.
The eligibility decision rejected acceptance timing; this experiment supplies
no performance credit. Evidence is in `rect-prefetch-large-grid-v1/` with
enclosing report `rect-prefetch-large-grid-queue-20261026-230412/guard.json`
(child exit 0, 12 GiB budget, 958,529,536-byte sampled peak, 283.57 seconds).

A subsequent test expansion to half-scale paint transforms aborted on its
first native comparison, before sanitizer, browser eligibility, pixel or
timing checks ran. That case applies a half-scale transform to a 1× surface,
outside the backend patch cache's supported device scales of one and two.
The admission check and test expectations require correction before the
Retina half-scale case can be evaluated. The failed command and source are
retained in `rect-prefetch-device-grid-v1/`; the enclosing report is
`rect-prefetch-device-grid-queue-20261026-233829/guard.json` (child exit 1,
565,166,080-byte sampled peak, 23.08 seconds). The native child aborted with
exit -6 and its wrapper returned 134. Smooth 60 fps remains unmet.

### Device-grid prefetch validation: no established gain (2026-10-26 UTC)

The corrected admission check accepts only effective device scales one and two.
The expanded normal and ASan/UBSan executions each passed 1,296 exact ordered
comparisons: 972 admitted cases and 324 deliberately declined cases. Both
focused 3 GiB commands exited 0; sampled peaks were 175,390,720 and
1,096,679,424 bytes, with elapsed times 104.30 and 206.24 seconds. The sanitizer
log also retains one Skia `Unfinished command buffer status: 3` warning; it
contains no reported ASan/UBSan violation. All three focused V scanner tests
were compiled and executed successfully (3 GiB runtime peak 11,501,568 bytes,
0.64 seconds).

Four alternating 120-input diagnostics established that prefetch executes
during scrolling: candidates completed 222 and 228 successful input batches;
controls completed zero. Sampled ordinary input cache hits/calls were
503/1,024, 532/932, 412/1,024 and 533/947 in control/candidate order. These
logs are capped at 1,024 per phase and stage, not whole-run hit rates.
Recorded declined calls had fewer than two collected jobs, and the recorded
page matrices independently confirmed half-scale transforms on the Retina
destination. These instrumented observations supply no performance credit.

Signing verification and headless startup passed. All thirteen native browser
control/candidate pixel pairs were exact, including compound fixtures at 1×
and 2×. Both reference smoke commands exited 1 with pre-existing mismatches;
no reference allowances were changed. The four unprofiled trials used the
same sealed archive, original URL, 1024×764 CSS viewport at scale two,
360 nominal 60 Hz delta-12 inputs with reversal every 120, title-gated
20-second settling, and a fresh process, private profile and cache per run.

| Trial | Scroll fps | Median / p95 / max interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| control-1 | 34.35 | 25.63 / 56.14 / 74.86 | 91.45% | 234 / 246 / 360 |
| candidate-1 | 29.08 | 30.20 / 66.90 / 112.18 | 96.39% | 194 / 204 / 360 |
| control-2 | 29.51 | 30.82 / 57.25 / 80.55 | 98.41% | 189 / 199 / 360 |
| candidate-2 | 29.65 | 29.63 / 71.19 / 100.48 | 95.96% | 198 / 210 / 360 |

| Trial | Actual input Hz | Entire input period, s | Leading / trailing publication gap, ms | First counted scroll delay, ms |
| --- | ---: | ---: | --- | ---: |
| control-1 | 52.70 | 6.812 | 126.93 / 1.51 | 162.10 |
| candidate-1 | 53.82 | 6.671 | 152.69 / 19.83 | 243.41 |
| control-2 | 56.05 | 6.405 | 110.83 / 19.31 | 168.08 |
| candidate-2 | 53.76 | 6.678 | 136.31 / 19.74 | 213.32 |

All four browsers exited 0, moved the requested document and used only
archived responses. Paired throughput changes were −15.33% and +0.47%;
controls varied by 16.40%. The 18-CPU host's one-minute loads before/after
each run were 29.77/26.45, 26.45/23.91, 23.91/20.04 and 20.04/16.80.
All load averages and timestamps remain in the raw results. This variation
and contention preclude attributing a gain to prefetch; the regression is
retained. The prototype remains opt-in and has not been installed as a
default speed fix. Smooth 60 fps remains unmet. The endpoint is changed native
publication after `updateLayer`, not physical display scanout or live SOCKS
acceptance.

Evidence is in `rect-prefetch-device-grid-v2/` and
`rect-prefetch-device-grid-v2-validation/`, including `acceptance-summary.json`,
`decline-analysis.json`, immutable source and dependency identities, raw
commands, pixels, actual input/frame timestamps and browser exits. The
enclosing `rect-prefetch-device-grid-queue-20261027-000135/guard.json` reports
child exit 0, 12 GiB budget, sampled peak RSS 8,432,549,888 bytes and elapsed
931.24 seconds. No production patch margin was changed by this experiment.

### Reduced patch guard on the real root grid (2026-10-26 UTC)

The next matched experiment kept the same archived original HTTPS URL,
1024×764 CSS viewport, 2× backing scale, fresh private profiles, title-gated
20-second settle, and 360 precise wheel inputs at nominal 60 Hz (delta 12,
reversing every 120 inputs). All responses came from `disk-fixture-final/`
over the loopback CONNECT replay and private TLS trust; SOCKS and external
network traffic were excluded. The fixture manifest and response body retain
the hashes recorded above. Only the conditional thin-rectangle patch guard
changed from two to one device pixels, using the earlier reduced-guard
backend with the validated device-grid frontend. Prefetch remains opt-in.

Four native oracle executions passed: control and candidate each ran 1,296
ordered comparisons normally and with AddressSanitizer/UndefinedBehaviorSanitizer
(972 admitted, 324 declined per execution). Each focused execution stayed
under its sampled 3 GiB budget and exited 0. The identical three V scanner
cases reuse their authenticated, executed device-grid-v2 results. Signing
and headless startup passed. Eleven canonical screenshots and two compound
fixtures at 1×/2× were pixel-exact between modes. Both canonical comparison
commands retained their existing reference mismatches and exit 1; no
allowance changed. All required driver commands exited 0.

In separate 120-input diagnostics, ordinary replay cache hits increased
from 43.07% to 74.61%, and from 39.41% to 73.97% in the two pairs.
These are capped diagnostic samples, not whole-frame hit rates or timing
credit. Candidate input windows executed 314 and 236 successful prefetch
batches; controls executed zero. This met the predeclared eligibility gate.

Unprofiled alternating trials measured changed native frame publications
after `updateLayer` over the entire first-to-last input period:

| Trial | Scroll fps | Median / p95 / maximum interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| control-1 | 25.71 | 35.18 / 72.79 / 84.23 | 99.43% | 175 / 187 / 360 |
| candidate-1 | 25.17 | 35.69 / 72.75 / 92.40 | 99.42% | 172 / 181 / 360 |
| control-2 | 26.15 | 33.53 / 66.62 / 123.34 | 100.00% | 177 / 187 / 360 |
| candidate-2 | 25.41 | 35.75 / 66.06 / 88.97 | 100.00% | 166 / 176 / 360 |

| Trial | Actual input Hz | Entire input period, s | Leading / trailing publication gap, ms | First counted scroll delay, ms |
| --- | ---: | ---: | --- | ---: |
| control-1 | 52.75 | 6.805 | 117.54 / 21.24 | 197.99 |
| candidate-1 | 52.54 | 6.833 | 135.30 / 26.70 | 225.75 |
| control-2 | 53.04 | 6.768 | 116.16 / 19.42 | 196.73 |
| candidate-2 | 54.94 | 6.534 | 131.25 / 1.58 | 219.69 |

Paired throughput changes were -2.11% and -2.85%;
controls varied by 1.70%. All four browsers exited 0 and moved the
requested archived document. The 18-CPU host had high contention: one-minute
loads before/after each trial were 73.56/65.36, 65.36/61.18, 59.24/53.65, 53.65/58.31.
The results establish no performance gain, despite improved sampled cache
hits. Smooth 60 fps remains unmet; these are native publications, not display
scanout or live SOCKS acceptance. No default patch margin was changed.

Evidence is in `rect-prefetch-device-grid-reduced-v2/` and
`rect-prefetch-device-grid-reduced-v2-validation/`, including the complete
`acceptance-summary.json`, eligibility decision, commands, executable/library
and dependency hashes, pixel comparisons, actual input/frame timestamps,
host load and browser exits. The enclosing
`rect-prefetch-device-grid-reduced-queue-20261027-003300/guard.json` reports
child exit 0, 12 GiB budget, sampled peak RSS 1,218,396,160 bytes
and elapsed 742.53 seconds.

### Scratch lookahead native checks (2026-10-26 UTC)

The next opt-in prototype replays intervening text into a private bitmap to
predict the backgrounds of later thin rectangles. Normal ordered painting
still checks each exact background before using a prefetched cache entry.
The prototype remains disabled by default; these native checks establish no
scrolling performance gain.

Normal and ASan/UBSan executions each passed all 1,296 existing ordered
prefetch comparisons (972 admitted and 324 deliberately declined). Both
executions of the new scratch oracle also passed all 288 ordered pixel
comparisons: 216 admitted cases and 72 deliberately declined cases. Each
scratch execution additionally verified 272 exact text-dependent backdrop
predictions. Cases cover real Arial glyph replay, translucent intervening
painting, patterned backgrounds, rectangular and elliptical clipping,
overlapping rectangles, 1×/2× destinations, half-scale/unit transforms,
fractional phases, and the real 2048×384 root grid. The real destination
remained unchanged until normal replay; cancellation, duplicate/incomplete
submission, nesting and malformed geometry were checked as well.

All eight compile/runtime commands exited 0, with no reported sanitizer
violation. Immutable source and dependency identities, exact commands, logs
and exits are in `rect-prefetch-scratch-v1/` under the existing evidence
root. Its `memory.json` reports child exit 0, a 3 GiB sampled budget,
1,257,897,984-byte sampled peak RSS and 401.97 seconds elapsed. Cocoa/V
wrapper checks and full-browser eligibility, pixels and unprofiled timing
remain pending. The completed shared production bundle lacks the scratch
implementation and can supply baseline evidence only. Smooth 60 fps remains
unmet; no live SOCKS fix is claimed.

### Reused shared production baseline (2026-10-26 UTC)

Two fresh-process, unprofiled trials reused the latest completed signed
production bundle, executable SHA256
`a1167c7abc73b8b0ac45f1d3eb0f5ace4f1b44375df75dff3108af46f0de2123`.
This bundle does not contain the scratch-prefetch implementation. Its native
library hashes, source receipts and unchanged cloned identity are retained in
`shared-baseline-20261027-015031/identity.json`.

The workload remained the archived original HTTPS thread at 1024×764 CSS
pixels and 2× backing scale, with fresh empty private profiles and caches,
20 seconds settling after the matching title, and 360 precise wheel inputs
at nominal 60 Hz (delta 12, reversing every 120). The loopback replay served
only archived HTTP 200 responses with private TLS trust; external network
access and SOCKS were excluded. Manifest and response-body hashes match the
fixture above. Native publications were counted after `updateLayer`, over
the full first-to-last input period.

| Trial | Scroll fps | Median / p95 / maximum interval, ms | Over 16.67 ms | Moving intervals / publications / inputs |
| --- | ---: | --- | ---: | --- |
| browser-1 | 33.55 | 25.69 / 55.33 / 97.98 | 90.91% | 231 / 243 / 360 |
| browser-2 | 32.36 | 27.15 / 57.56 / 75.19 | 93.55% | 217 / 232 / 360 |

| Trial | Actual input Hz | Entire input period, s | Leading / trailing publication gap, ms | First counted scroll delay, ms |
| --- | ---: | ---: | --- | ---: |
| browser-1 | 52.14 | 6.886 | 325.66 / 19.47 | 397.87 |
| browser-2 | 53.54 | 6.705 | 111.37 / 1.45 | 180.58 |

Both browsers exited 0, completed all inputs and moved the intended document.
The 18-CPU host's one-minute loads before/after the trials were
34.26/27.25 and 27.25/24.21. These baseline results differ in build and
host contention from earlier experiments and establish no optimization gain.
Smooth 60 fps remains unmet; physical scanout and live SOCKS acceptance are
not established. Full commands, raw timestamps, requests, identities, host
loads and exits are under `shared-baseline-20261027-015031/trials/`;
`reviewed-results.json` records the independent evidence checks. The enclosing
memory guard exited 0, with a 12 GiB budget, sampled peak RSS
870,645,760 bytes and 68.93 seconds elapsed.

### Scratch wrapper validation status (2026-10-26 UTC)

Commit `e3379f47` contains the bounded native prefetch API and both native
pixel oracles described above. The Cocoa scope wrapper passed its normal and
ASan/UBSan executions, including context restoration before submission,
nesting, cancellation and declined admission. Those successful commands and
their immutable inputs remain in `scratch-scope-focused-v1/`.

The V fixture has not executed successfully. Its first compile failed because
the fixture omitted declarations for mock C counters. The corrected fixture
then exceeded its 3 GiB guard while importing the full layout dependency
graph: `scratch-scope-focused-v2/memory.json` records reason `memory_limit`,
child exit -9, sampled peak 3,243,016,192 bytes and 26.69 seconds elapsed.
Neither attempt receives runtime-test credit.

The same-budget retry in `scratch-scope-focused-v3/` retains the exact V
wrapper body and mocks only the command fields it consumes; production
compilation must still check the real layout type. The dependent coordinator
in `scratch-browser-isolated-v4/` waits outside the guard and submits no browser
build unless that focused retry passes. The preceding coordinator withheld its
build after the focused guard failure.
Browser eligibility, pixel comparisons and alternating unprofiled acceptance
remain pending. The candidate is disabled by default; 60 fps and a live SOCKS
fix remain unestablished.
