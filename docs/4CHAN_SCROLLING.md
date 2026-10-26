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
