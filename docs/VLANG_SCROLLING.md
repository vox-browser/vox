# vlang.io scrolling

The live **60 FPS target remains unmet**. The latest measured production snapshot publishes **5.40–5.45 scroll-changing native frames per second** on live `https://vlang.io/`, and **7.24–8.28** on the frozen page. Every measured scrolling interval still exceeds 16.67 ms. These are completed Cocoa layer publications; physical display scanout is unmeasured. Optimization work continues.

The [compositor milestone receipt](benchmark-results/vlang-scroll-20261101-compositor-milestone.json) and [compressed raw records](benchmark-results/vlang-scroll-20261101-compositor-milestone-raw.json.gz) retain 64 completed measurements and 1,657 raw text artifacts through this checkpoint, including diagnostic runs, failures, commands, input/publication timestamps, source and executable identities, host load, guard exits and rejected patches. Full artifacts remain in `Build/vlang-scroll-compositor-20261101-111741/`. Later experiments are not acceptance results in this checkpoint.

## Latest measured production snapshot

Executable SHA256 `aa1a84e71452debb6d14861c02e9033d972f6bb00184a19a82d22e6b12c984d9` identifies the pinned copy of the shared, successfully completed production bundle. It includes the first four changes below and other sessions' work. It precedes the large-raster admission change. These measurements describe the complete build and do not isolate an aggregate improvement from this session.

| Trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Frozen 1 | 8.28 | 48.13 | 600 / 109 | 104.19 / 158.09 / 568.27 | 100.00% | 970.83 / 91.50 |
| Live 1 | 5.45 | 14.25 | 600 / 231 | 180.29 / 221.02 / 601.98 | 100.00% | 362.60 / 0.28 |
| Frozen 2 | 7.24 | 51.02 | 600 / 88 | 136.55 / 155.83 / 157.63 | 100.00% | 365.16 / 85.90 |
| Live 2 | 5.40 | 14.50 | 600 / 226 | 179.81 / 224.99 / 631.56 | 100.00% | 361.89 / 133.82 |

The protocol remains a fresh process and empty private profile/cache per trial, a verified title followed by 20 seconds of settling, a 1024×768 document viewport at backing scale 2, and 600 precise native delta-2 wheel events requested at 60 Hz and reversed every 60 events. Full first-to-last actual input time supplies the throughput denominator. Tail publications establish final-input completion without increasing FPS. Frozen fixture bytes, scripting/animation policy, network denial and OS-cache policy remain unchanged. Live trials use direct HTTPS and automatic author-script policy.

## Additional completed rendering work

- `92153cd3` makes deferred decoration painting transactional: failure restores the saved bitmap and replays the ordinary V commands.
- `b2856df5` omits eligible speculative leaves inside complete non-root pictures and replays document painting after publication failure. Scripts and layout are not rerun. Private bitmap capability, clip and ink bounds remain required.
- `8407d236` encodes lossless raster snapshots in one pass from caller rows, preserving packet boundaries and the existing compression threshold while avoiding a temporary full copy.
- `916a028b` reuses a bounded Graphite recorder resource cache across full-surface draws, retaining a fresh target per draw and discarding abandoned recordings before reuse.
- `ce23f230` delays snapshots for large shape/path/shadow cache misses until a bounded allocation hint observes a repeat. Hints cannot return pixels: cache hits still compare complete owned inputs. Small draws and image admission retain their preceding policy.

| Change | Control FPS (1 / 2) | Candidate FPS (1 / 2) |
| --- | ---: | ---: |
| Deferred decorations | 4.86 / 5.67 | 5.08 / 5.76 |
| Deferred complete layers | 4.65 / 5.80 | 4.29 / 5.70 |
| Single-pass snapshots | 5.10 / 6.95 | 6.02 / 6.62 |
| Full recorder reuse | 6.84 / 8.58 | 9.81 / 9.07 |
| Large raster admission | 10.85 / 11.04 | 11.18 / 11.12 |

Each row retains two alternating, unprofiled frozen-page pairs with identical input/capture boundaries within that cohort. Builds differ between rows. Deferred-layer and snapshot results are mixed and receive no isolated FPS credit. Recorder reuse improves both pairs, but varying controls prevent a precise percentage attribution. Admission improves both pairs slightly while host load falls; that small timing gain remains uncertain. Its separate input diagnostic records 247 avoided snapshots and 102 admitted requests. These frozen results do not describe live vlang.io FPS.

Focused validation includes transactional rollback, 32 deferred-layer capability/clip/failure scenes, actual V shadow-policy execution, snapshot ownership/stride/packet checks, 4,718 GPU comparisons, 96 recorder failure/teardown scenes and exact HTTP page comparisons. Admission additionally passes address/undefined sanitizers and a fresh-process headless smoke check. Separate diagnostics verify that retained fast paths execute during actual wheel input. No retired-instruction reduction is claimed, so the instruction-based broad-suite savings carry remains unchanged.

## Rejected experiments at this checkpoint

Solid and cropped picture backdrops, a pooled Dawn picture recorder, retained full Metal targets and direct bitmap copies failed to demonstrate consistent matched gains; their source changes were reverted. Direct shared-Metal texture readback was pixel-correct but regressed both pairs, 10.84→9.98 and 10.71→9.21 FPS, and was also removed. Removing the unculled-gradient picture guard changed pixels in all 24 native scenes and received no timing credit.

A CPU fractional-color glyph experiment passed 4,995 exact native comparisons and ten page pairs, but all 750 actual-input glyph requests used byte colors and the existing CPU path. The proposed GPU replacement was therefore ineligible and was removed without a timing cohort. Correctness alone did not establish workload relevance.

All failed and partial attempts remain in the raw evidence. Earlier experimental native bridges picked up by shared builds were restored under the production guard, with fresh-process smoke checks and recorded identities. The latest measured production snapshot excludes the rejected bridge experiments. A new serialized-picture Metal prototype remains unaccepted at this checkpoint: its first version omitted a glyph label, and its font-guarded version keeps font pictures on the existing Dawn backend. Neither version supplies optimization credit here.

## Earlier picture-region production validation

The preceding production snapshot measured **3.51–4.25 scroll-changing native publications per second** on live `https://vlang.io/`, and **6.28–7.68** on the frozen page. Every measured scrolling interval exceeded 16.67 ms.

The [picture-region receipt](benchmark-results/vlang-scroll-20261101-picture-regions.json) and [compressed raw evidence](benchmark-results/vlang-scroll-20261101-picture-regions-raw.json.gz) retain all attempts, executable/library/probe hashes, input/publication records, actual exits, commands, pixel audits, source witnesses and host conditions. Full binaries, PNGs and samples remain in `Build/vlang-scroll-regions-20261101-092229/`.

Both frozen and both live trials use the same pinned copy of the installed production bundle, executable SHA256 `5aae83a4408e023380d51e4430003b519ec427bcd96b3701b634930eeda62952`. Its completed build receipt has unchanged before/after hashes for this session’s native sources and tab-directory fix. This shared build also includes other sessions’ changes; the results describe that complete build and do not isolate a percentage improvement for this session. Fresh-process headless smoke passes.

| Trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Frozen 1 | 7.68 | 47.93 | 600 / 100 | 119.48 / 145.84 / 226.48 | 100.00% | 972.19 / 42.85 |
| Live 1 | 4.25 | 11.37 | 600 / 226 | 227.78 / 295.48 / 712.14 | 100.00% | 954.36 / 19.34 |
| Frozen 2 | 6.28 | 48.19 | 600 / 84 | 152.84 / 186.23 / 299.94 | 100.00% | 470.56 / 137.57 |
| Live 2 | 3.51 | 10.42 | 600 / 205 | 274.62 / 345.22 / 901.37 | 100.00% | 501.74 / 189.86 |

Each run starts a fresh process with a private profile/cache and verifies the requested title before settling for 20 seconds. The document viewport is 1024×768, backing scale 2, excluding 112 pixels of browser chrome. The native probe sends 600 precise delta-2 wheel events, requested at 60 Hz and reversed every 60 inputs. The entire first-to-last actual input period supplies the throughput denominator. Tail frames establish final-input publication and do not increase FPS. Actual timestamps and scroll positions are retained.

The frozen workload remains the unchanged initialized vlang DOM and local assets over loopback HTTP, with scripts removed, animations disabled, a fixed video poster and external DNS/connect denied. The receipt hashes every fixture resource. Live runs use direct HTTPS and automatic author-script policy. OS caches remain enabled. These measurements establish no JavaScript VM performance claim.

## Additional rendering changes

- `27ab23e9` crops gradient-text backdrop/readback pixels while retaining the original GPU target and device coordinates.
- `7540bf94` reads only each decoration’s intersection with its original Chromium tile.
- `c8fa0eb5` batches independent decoration tiles, decodes each immutable picture once and reuses image uploads only within that recorder. Caller output remains untouched if any transfer fails.
- `da516117` bounds opaque-backdrop CSS blur transfers conservatively, preserving the full GPU surface, original filter layer and blur coordinates. Translucent backdrops retain the preceding behavior.
- `5741f9ae` scans lossless cache runs/literals in pixel groups. It preserves packet boundaries and retained storage exactly.

Focused checks pass: 93 picture/text/batch scenes, 64 decoration scenes, 160 blur scenes, snapshot codec tests in vector/scalar and address/undefined-sanitizer modes, cache ownership/mutation/bounds tests, and 4,718 exact GPU replay comparisons. Four HTTP page pairs at Y=0/240 and scales 1/2 match exactly for each region/batch/blur/scanner stage; retained audit records report complete readiness, no native errors and no failed font faces. The replay tool’s duplicate Objective-C queue-class warning is retained with its successful zero exit.

## Matched unprofiled cohorts

Each row contains two alternating control/candidate pairs at the same input/capture boundaries. Builds differ between cohorts; their exact identities remain in the receipt. No trial is selected out of a cohort.

| Change | Control FPS (1 / 2) | Candidate FPS (1 / 2) |
| --- | ---: | ---: |
| Gradient-text regions | 4.98 / 6.16 | 5.23 / 6.28 |
| Decoration regions | 6.00 / 5.85 | 6.42 / 6.58 |
| Batched decorations | 8.08 / 8.31 | 8.38 / 8.57 |
| Blur regions | 7.46 / 5.72 | 7.92 / 7.82 |
| Snapshot scanning | 5.41 / 7.46 | 6.48 / 6.66 |

Controls vary substantially with concurrent host work, so these observations do not provide a precise isolated aggregate improvement. The scanner improves one pair and regresses the other; its FPS benefit is unresolved. Its separate captured-tile codec microbenchmark has a median 108,892 µs for scalar scanning versus 67,896.4 µs for grouped scanning, with identical encoded byte counts. That microbenchmark is diagnostic, supplies no native FPS or instruction-count credit, and does not close the scrolling target.

Separate sampled/input-window diagnostics confirm gradient-text regions, decoration batches, blur regions and raster snapshots execute during the wheel window. Startup/settle counters are excluded from those eligibility counts. Main-thread rendering still spends time across gradients, rounded geometry, shadows, raster-cache work and GPU synchronization. Mean throughput alone cannot establish smooth 60 FPS.

## Startup failure and retained attempts

Three earlier batch cohorts stopped at candidate startup with `File exists` before navigation. All partial cohorts and failed probes remain in the receipt. A corrected native probe observed `mkdir` returning EEXIST for old `/tmp/vox-tabs-…` directories. The cause of the repeated application-generated names remains undetermined. Commit `61a178e5` reserves session directories atomically with `mkdtemp`; tab IDs retain their existing behavior. Tests force repeated application randomness and verify independent sessions, 0700 directory permissions, metadata isolation and error handling. The complete tab package passes with a fresh compiler cache in both normal-GC and no-GC modes. Earlier cached-compiler missing-symbol failures remain retained.

The earlier report’s temporary-directory explanation was incorrect: current V hardcodes `os.temp_dir()` to `/tmp` on macOS, so setting `TMPDIR` did not isolate these session names. No existing tab directory was removed to obtain successful trials. After the allocator fix, the complete batch, blur, scanner and latest-production cohorts launch successfully.

## Earlier decoration-bounds cohort

The following retained measurements describe the preceding bounds-only builds, before the additional changes above.

The target remains smooth 60 FPS on live `https://vlang.io/`. It has **not**
been reached. Commit `10997795` bounds decoration-picture backdrops to their
recorded ink. Two frozen-page trials measure **3.82–4.05 scroll-changing native
publications per second**, versus **0.63–0.82** for the preceding library.
Live trials on that executable with the changed library measure **2.84–3.20**.
The later installed production snapshot measures **2.68–3.37**. Every measured
scrolling interval still exceeds 16.67 ms.

These are changed Cocoa layer contents after `updateLayer`, not physical
display scanout. The [durable receipt](benchmark-results/vlang-scroll-20261101-inset-bounds.json)
retains exact commands, executable/library/probe hashes, every attempt, actual
exits, host load, input cadence, interval distributions and boundary gaps.
[Compressed raw records](benchmark-results/vlang-scroll-20261101-inset-bounds-raw.json.gz)
retain the native input/publication records and orchestration sources.
Full artifacts, stack samples, captures and build logs remain under
`Build/vlang-scroll-20261101-0900/`.

## Change and correctness

Small rounded background/border pairs previously copied, serialized and
replayed a backdrop covering almost the entire viewport. The native recording
now collects the transformed rectangle ink, including stroke and underlay
bounds, then trims its saved backdrop before picture serialization. A
two-pixel logical guard preserves antialias coverage. Cropping requires exact
alignment with the existing device-pixel grid; other scales retain the original
path. The GPU still renders the original complete Chromium tiles, preserving
their coverage and ownership. Unsupported recordings retain their fallback.

The focused test compares 64 scenes with the unbounded implementation. All
RGBA bytes match, including both backing scales, tile MSAA modes, fractional
positions, root scrolling, shears, thick strokes, transparency, ancestor clips
and row padding. The existing native inner-shadow isolation/fallback tests
also pass. These native tests use the 3 GiB memory guard.

Four HTTP-served frozen-page comparisons at Y=0/240 and scales 1/2 are also
pixel-exact. All eight captures have complete readiness, zero native errors,
and no failed font faces. Earlier file-based comparisons failed to resolve
root-relative fonts; those artifacts remain retained but do not supply the
page conformance result.

## Measurements

Each trial launches a fresh process with a private profile and cache, a
1024×768 document viewport at backing scale 2, default 112-pixel browser
chrome, and native test-window placement. After the matching title appears,
the probe settles for 20 seconds and sends 600 precise native wheel events:
nominally 60 Hz, delta 2, reversing every 60 inputs. All listed trials complete
every input and its final publication. The full first-to-last input period
supplies the throughput denominator; tail publications do not increase FPS.

| Frozen-page trial | Scroll FPS | Input Hz | Median / p95 / maximum scroll interval (ms) | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- |
| Control 1 | 0.82 | 10.45 | 1113.33 / 1344.60 / 2372.21 | 3720.54 / 1039.60 |
| Bounded 1 | 4.05 | 41.13 | 206.32 / 264.00 / 408.23 | 2135.90 / 214.82 |
| Control 2 | 0.63 | 9.70 | 1434.99 / 1854.54 / 2831.18 | 5016.02 / 1512.15 |
| Bounded 2 | 3.82 | 43.20 | 245.82 / 297.91 / 417.53 | 721.43 / 131.07 |

| Live-page trial | Scroll FPS | Input Hz | Median / p95 / maximum scroll interval (ms) | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- |
| Original executable + bounded library 1 | 2.84 | 10.96 | 321.51 / 467.59 / 983.89 | 1963.95 / 50.49 |
| Original executable + bounded library 2 | 3.20 | 11.77 | 296.80 / 350.44 / 906.20 | 630.80 / 204.60 |
| Installed production snapshot 1 | 2.68 | 10.10 | 350.48 / 445.38 / 1033.40 | 1920.64 / 59.58 |
| Installed production snapshot 2 | 3.37 | 12.38 | 275.91 / 364.64 / 927.29 | 647.42 / 41.24 |

The frozen workload is the existing initialized vlang DOM snapshot and local
assets over loopback HTTP: author scripts removed, animations disabled and a
fixed video poster. External network access is denied. Live trials use normal
HTTPS and automatic script policy. OS filesystem/shader caches remain enabled.
Neither the fixture nor this report establishes JavaScript VM performance.

The host has 18 logical CPUs and concurrent browsers/builds. One-minute load
averages range from roughly 11 to 52 across the recorded comparisons, so the
timing difference cannot supply a precise isolated percentage improvement.
Separate stack samples verify that decoration replay executes while scrolling;
the final sample starts five seconds after input begins. Remaining work is
spread across gradients, blur/text effects, rounded geometry, shadows and
GPU readbacks. Faster isolated conversion or callback timings would not close
the live 60 FPS target.

## Rejected experiments and installed build

Keeping the Dawn recorder alive and caching complete serialized-picture
results measure only 2.66 and 2.86 FPS in their exploratory frozen trials.
Both source changes were reverted; these single trials establish no benefit.
Their binaries, patches, commands and results remain in the evidence directory.
Separate diagnostic launches that failed before navigation with a tab-session
`File exists` error are retained without FPS. That successful diagnostic did not prove `TMPDIR` isolated tab-session directories;
the follow-up startup investigation above corrects that explanation.

A concurrent production build picked up the temporary picture-cache source.
Its Dawn library was rebuilt from the reverted source and installed while
holding `Build/v/production.lock`. The receipt pins the before/after identities
and verifies that the installed bundle contains the bounds fix and excludes
the rejected cache. Fresh-process headless smoke passes. The production
snapshot includes other sessions' changes; its live trial results in the
receipt describe that complete bundle and do not isolate this one fix.
