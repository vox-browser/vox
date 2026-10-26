# 4chan scrolling through SOCKS

Investigated 2026-10-25–26 using
<https://boards.4chan.org/pol/thread/544908349/what-has-the-world-come-to>.
The acceptance endpoint is a changed native layer publication after
`updateLayer` completes. This does not measure physical display scanout.

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
