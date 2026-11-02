# vlang.io scrolling

The live **60 FPS target remains unmet**. The latest verified default-path runs (`ae08e7ca`) measure **10.59 / 11.16 scroll-changing publications/s**, with every measured interval exceeding 16.67 ms. The region-cache experiment passes pixel checks but receives zero live input calls, so it was removed without a timing cohort. Loaded native libraries match the canonical bundle. The intermittent CSS/SVG fault remains unresolved; successful diagnostic launches do not establish a fix. These are completed Cocoa layer publications; physical display scanout is unmeasured. See the [latest checkpoint](#first-fault-diagnostics-and-region-cache-eligibility).

The [compositor milestone receipt](benchmark-results/vlang-scroll-20261101-compositor-milestone.json) and [compressed raw records](benchmark-results/vlang-scroll-20261101-compositor-milestone-raw.json.gz) retain 64 completed measurements and 1,657 raw text artifacts through this checkpoint, including diagnostic runs, failures, commands, input/publication timestamps, source and executable identities, host load, guard exits and rejected patches. Full artifacts remain in `Build/vlang-scroll-compositor-20261101-111741/`. That milestone is historical; later accepted cohorts are retained below.

## Immutable bitmap inputs and empty filter bounds

The [filter-input receipt](benchmark-results/vlang-scroll-20261101-filter-inputs.json) retains all later attempts, host conditions, identities, actual input/publication timestamps and exits. Its [compressed raw delta](benchmark-results/vlang-scroll-20261101-filter-inputs-raw.json.gz) applies to the preceding large-decoration raw snapshot, pinned by SHA256 in both files. Earlier receipts remain unchanged.

`f7e2c53b` reads owned immutable provider bytes for the exact premultiplied sRGB RGBA format used by isolated Quartz layers, avoiding redundant bitmap decoding. Other alpha/layout/color formats keep Quartz decoding. Whole Skia-image construction is deferred to CPU fallback. A separate live diagnostic confirms 114 uses during input on 2048×1760 buffers. Ownership, source mutation, tagged fallback, unsupported layouts and row padding are covered by 144 native blur/drop-shadow scenes.

`185f27c7` computes alpha bounds from the first and last nontransparent pixel in each row, with bounded block scans for transparent spans. It allocates filter output only after nonempty input is established. All 123 bitmap-filter calls during the separate live input diagnostic were empty. The new scan matches the original bounds in 4,608 normal and sanitizer cases; the 144 native filter scenes and four HTTP page pairs at 1×/2× and Y=0/240 remain exact. References, tolerances, blur settings and GPU rendering are unchanged.

| Alternating unprofiled cohort | Control FPS (1 / 2) | Candidate FPS (1 / 2) |
| --- | ---: | ---: |
| Immutable bitmap input, frozen | 10.98 / 10.83 | 10.82 / 10.13 |
| Immutable bitmap input, live | 26.18 / 27.24 | 28.81 / 28.95 |
| Alpha bounds, frozen | 11.45 / 11.66 | 11.10 / 11.26 |
| Alpha bounds, live | 29.15 / 27.98 | 32.66 / 33.10 |

Both changes improve both live pairs and regress both frozen pairs; those regressions remain acceptance qualifications. Varying host load prevents a precise isolated percentage attribution. The bounds control's 422.44 ms stall is retained. Fresh production checks after immutable input measured 30.83/30.79 FPS live and 12.01/11.35 frozen; these complete builds include other sessions' changes and do not isolate the contribution of each commit.

The bounds installation first encountered a busy production guard. No duplicate build was queued. Once the shared build completed, the tested native libraries were installed, signed, verified, smoke-checked in a fresh process and pinned for the four measurements below.

| Installed bounds build | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Frozen 1 | 11.98 | 55.61 | 600 / 133 | 81.74 / 91.55 / 94.94 | 100.00% | 239.39 / 17.71 |
| Live 1 | 33.73 | 48.33 | 600 / 433 | 29.33 / 33.53 / 76.70 | 100.00% | 75.94 / 20.92 |
| Frozen 2 | 11.23 | 56.04 | 600 / 125 | 87.71 / 99.04 / 158.94 | 100.00% | 243.94 / 0.13 |
| Live 2 | 32.96 | 48.63 | 600 / 419 | 29.99 / 34.17 / 71.78 | 100.00% | 77.57 / 20.04 |

The native-input protocol is unchanged: fresh processes, empty private profiles/caches, matching title followed by 20 seconds of settling, a 1024×768 document viewport at backing scale 2, and 600 precise delta-2 wheel events requested at 60 Hz and reversed every 60 events. Full first-to-last actual input time supplies throughput. Live trials use direct HTTPS and automatic author scripting; the frozen fixture and its script/network policy remain unchanged. This does not establish physical scanout or JavaScript VM performance. No retired-instruction savings are claimed; the broad-suite savings carry remains unchanged.

A subsequent device-space key experiment was removed without implementing a cache: exact keys change with fractional transforms and the transparent MSAA-trigger geometry. Most repeats occur near reversals or after movement stops. Flat-picture analysis and verification are later unaccepted experiments at this checkpoint and supply no timing credit here.

## Large decoration batches and direct backdrop upload

The [large-decoration receipt](benchmark-results/vlang-scroll-20261101-large-decorations.json) and [compressed raw records](benchmark-results/vlang-scroll-20261101-large-decorations-raw.json.gz) retain every subsequent cohort, failed attempt, input/publication record, source/executable identity, pixel audit, host condition and actual exit. Earlier receipts remain unchanged.

`71c708db` sends large root-decoration pictures through the existing tile batch instead of serial GPU submissions. It raises only the bounded CPU-region ceiling; original tile sizes, MSAA, backdrop pixels and aggregate GPU limits remain unchanged. Scoped shared pixels are deduplicated by full value. Separate actual-input diagnostics record 72 batches covering 2.07–3.03 million pixels, and 118 shared encode/decode pairs. The corrected live stack sample identifies the preceding serial decoration raster path; the first empty-stack sample remains invalid and retained.

`590ecea7` uploads immutable backdrop tile pixels directly to the same Dawn targets before drawing the original content picture. It avoids encoding/decoding a backdrop image and retains transactional fallback. The final path passes 48 exact native scenes, including translucent backgrounds, row padding, mixed MSAA and fractional scrolling. Both changes preserve four HTTP page pairs at scales 1/2 and Y=0/240 exactly. No reference or tolerance changed. An initial direct-upload build failed because `writePixels` returns void; tests against that build's old backend exercised fallback and supply no path-validation credit. Corrected builds explicitly verify the new API.

| Alternating unprofiled cohort | Control FPS (1 / 2) | Candidate FPS (1 / 2) |
| --- | ---: | ---: |
| Large decorations, frozen | 11.18 / 11.99 | 11.80 / 11.96 |
| Large decorations, live | 7.35 / 7.16 | 28.08 / 26.75 |
| Direct backdrop, frozen prototype | 9.87 / 11.47 | 11.21 / 11.37 |
| Direct backdrop, live prototype | 27.56 / 27.48 | 28.45 / 28.21 |
| Direct backdrop, final live build | 27.80 / 26.59 | 28.66 / 26.88 |

The large live gain reproduces in both pairs. Frozen results are mixed. Direct upload yields small live gains across both prototype and final pairs; host variation prevents a precise isolated percentage claim. The 456.75 ms frozen control stall is retained. Decoder image caching was not pursued: the large batch already reuses one upload in 23/24 or 27/28 jobs.

The native libraries were installed under the shared production guard, signed and verified, then smoke-tested in a fresh process and pinned for all four measurements below. This reuses the latest completed executable, including other sessions' changes, and does not require a duplicate full V build. Whole-build measurements do not isolate the contribution of every commit.

| Installed production trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Frozen 1 | 10.90 | 55.79 | 600 / 121 | 90.65 / 103.89 / 109.07 | 100.00% | 263.79 / 0.13 |
| Live 1 | 28.15 | 52.70 | 600 / 334 | 34.62 / 39.58 / 84.44 | 100.00% | 88.61 / 37.25 |
| Frozen 2 | 11.25 | 55.70 | 600 / 126 | 86.79 / 96.55 / 173.17 | 100.00% | 271.74 / 59.77 |
| Live 2 | 28.24 | 53.02 | 600 / 335 | 34.16 / 39.56 / 86.48 | 100.00% | 85.72 / 0.18 |

The protocol remains a fresh process/private profile/cache, verified title plus 20-second settle, 1024×768 document viewport at backing scale 2, and 600 precise delta-2 native wheel events requested at 60 Hz and reversed every 60 events. Full first-to-last actual input time supplies the throughput denominator. Fixture bytes, script/animation policy, network denial and pixel references remain unchanged; live trials use direct HTTPS and automatic author scripting. Shared host load is retained. No retired-instruction savings are claimed and the broad-suite instruction-savings carry is unchanged. Subsequent device-space picture-key/cache experiments remain unaccepted diagnostics at this checkpoint.

## Clipped shape batches and shared picture pixels

The [follow-up receipt](benchmark-results/vlang-scroll-20261101-compositor-followup.json) and [compressed raw evidence](benchmark-results/vlang-scroll-20261101-compositor-followup-raw.json.gz) retain the later cohorts, every rejected/partial experiment, commands, actual input/publication timestamps, executable/library identities, host conditions and actual exits. Previous receipts remain unchanged.

- `34717a80` batches independent clipped tiles of one non-root shape. Each tile retains its original target size, immutable backdrop, coordinates, border ownership and MSAA mode. The backend also accepts bounded regions for larger shapes. Output stays transactional, with ordinary replay available after a failed batch.
- `c1ec852d` shares immutable encoded image pixels across the two Skia libraries through scoped tokens and C callbacks. Decoder leases preserve bytes after token retirement and count toward a 64 MiB live limit. Older decoders, small payloads and capacity failures retain the copied format. No Skia or C++ object crosses the ABI.

| Cohort | Control FPS (1 / 2) | Candidate FPS (1 / 2) |
| --- | ---: | ---: |
| Clipped shape batches | 10.92 / 10.90 | 11.17 / 11.57 |
| Shared pixels, initial prototype | 11.16 / 10.88 | 11.67 / 11.31 |
| Shared pixels, final default-enabled build | 11.10 / 10.94 | 11.24 / 10.96 |

Each row contains two alternating unprofiled frozen-page pairs. The final shared-pixel differences are small, so its isolated FPS benefit remains uncertain. The larger initial-prototype result is retained separately. Neither row establishes smooth 60 FPS. Separate actual-input diagnostics confirm 50 clipped batches and 53 shared encode/decode pairs; startup counters are excluded.

Validation passes: 30,080 exact GPU tile comparisons, 6,912 serial grid ownership/backdrop comparisons in normal and sanitizer modes, 1,728 native scene comparisons for each of normal operation and two forced rollback points, 160 blur scenes and 93 picture-region scenes. Shared-pixel ownership tests cover stale tokens, caller mutation, delayed image use after scope exit, tagged/sRGB data, malformed headers, capacity accounting and lease release. Four original HTTP page pairs at scales 1/2 and Y=0/240 remain pixel-exact for both accepted changes. No references or tolerances changed.

The final native libraries were installed under the shared production guard, followed by signing, a fresh-process headless smoke check and a pinned bundle copy. A preceding busy-guard attempt remains retained; no duplicate full production build was queued. Executable SHA256 `b9105b32531ba710ff77791d97cd9456ec8ec26d5c220d4d7dfc9aa1b038e943` identifies this complete build, which also contains other sessions' work.

| Trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Frozen 1 | 10.78 | 55.21 | 600 / 122 | 90.31 / 104.54 / 116.67 | 100.00% | 256.08 / 88.46 |
| Live 1 | 6.57 | 15.55 | 600 / 257 | 151.74 / 171.82 / 461.19 | 100.00% | 329.69 / 17.92 |
| Frozen 2 | 10.93 | 55.01 | 600 / 124 | 88.03 / 103.19 / 181.14 | 100.00% | 249.91 / 17.69 |
| Live 2 | 7.12 | 15.13 | 600 / 287 | 142.71 / 156.18 / 428.31 | 100.00% | 240.06 / 19.25 |

The protocol remains a fresh process/private profile/cache, verified title and 20-second settle, 1024×768 document viewport at backing scale 2, and 600 precise delta-2 native wheel events requested at 60 Hz and reversed every 60 events. Throughput uses the entire first-to-last actual input window. The frozen fixture, network denial, script/animation policy and references are unchanged; live runs use direct HTTPS and automatic author-script policy. These are native publications, not physical scanout. The earlier batch-only production snapshot measured 6.87/7.11 FPS live. Its results remain retained; later whole-build variation cannot establish an aggregate gain attributable to these changes.

Additional rejected work remains in the follow-up evidence:

- The integrated native-Metal serialized-picture path regressed all three completed pairs: 10.56→10.35, 10.85→10.73 and 10.82→10.48 FPS. A separate candidate interrupted before input has unknown process exit and receives no acceptance credit. All source changes were removed and native libraries restored.
- Retina/promotion metadata experiments changed reference pixels, including a substantial scale-one regression. Fixed Brave captures show integer-scroll invariance, while Vox's existing Retina raster phase remains unresolved. The experimental V changes were removed; no timing credit was taken.
- A retained-picture tile cache passed unit/native/page checks but never executed during vlang input because shadow overflow kept the picture on its untiled path. Its source was removed without an unprofiled cohort.
- Adaptive cache admission reduced path snapshots but produced mixed pairs, 11.75→10.95 and 10.83→11.14 FPS. It was removed.
- Large shape-region caching recorded 29 input-window hits and passed sanitizer, 40,064 GPU comparisons and page checks, but regressed both pairs, 11.77→11.46 and 11.71→11.07 FPS. It was removed.

No retired-instruction reduction is claimed. The instruction-based broad-suite savings carry is unchanged. The 60 FPS target remains open.

## Earlier production snapshot before clipped batches

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


## Selector and content audit follow-up

The [diagnostic checkpoint](benchmark-results/vlang-scroll-20261101-selector-diagnostics.json) and [raw delta](benchmark-results/vlang-scroll-20261101-selector-diagnostics-raw.json.gz) preserve 195 trial summaries and 4,417 raw artifacts reconstructed against the pinned large-decoration base. The target remains open; there is no additional accepted optimization at this checkpoint.

The flat-picture tile prototype passed native pixel, ownership and rollback checks, plus separate live verification of 152,687,392 pixels. Its prototype live pairs were 33.58→34.48 and 32.33→35.20 FPS. The final cohort was inconsistent: 33.48→59.90 and 34.27→33.17. A later resource-cache audit found that the near-60 trial had no stylesheet or subresources cached, while the other three retained identical 51,866-byte author CSS. That outlier fails content acceptance; a matching document title alone was insufficient. The experiment was removed, and the earlier production libraries restored. Frozen actual-input verification proved zero tiles, correcting the earlier implication that both workloads exercised the fast path. No references or tolerances were changed.

Active-window audits then exposed a correctness problem: the GitHub SVG occupies 752.33×752.33 CSS pixels in normal browsing despite an author rule specifying 20×20. Screenshot mode on the same build uses 20×20. The cached stylesheet bytes match. Both the DOM's raw style and the layout style lose the SVG width/height rules, with correct SVG namespaces. Disabling font-refresh shortcuts did not help. A separate diagnostic bypass of the ancestor-selector bloom filter restores 20×20 GitHub and 24×24 social icons, locating the problem in selector filtering. Root-cause work remains pending; this diagnostic bypass supplies no optimization credit.

Tooling commits `fed9bd7a` and `d47d3f4c` add bounded read-only computed-size, namespace and SVG paint-geometry audit output. Their full build, fresh startup and zero-exit active/screenshot observations are retained. Other active-window observations write their audit and PNG but crash in the HTTP/2 TLS read thread during shutdown; exit 139 is preserved and the driver now rejects it. A short corrected-page scroll diagnostic was initially stopped by an overly restrictive 3 GiB guard before input; its subsequent normal-budget run is diagnostic work, not an acceptance cohort. Shared build identities, changing unrelated inputs and all failures remain in the evidence.


## Animation ancestor filter correction

The [fix checkpoint](benchmark-results/vlang-scroll-20261101-animation-ancestor-fix.json) and [raw delta](benchmark-results/vlang-scroll-20261101-animation-ancestor-fix-raw.json.gz) retain the root-cause trace, source witnesses, every failed check, native runs and actual exits. Commit `fe4f61b6` seeds the target's shadow-including ancestor chain when animation sampling recascades custom-property dependants or refreshes retained samples. It balances that chain afterward and keeps the selector filter enabled. The live trace previously showed valid hashes with zero bloom buckets from `style_computer_update_animated_style_callback`.

Focused custom-property, forced-arena-rotation and shadow-host tests pass under preallocation; the two non-arena cases pass with the collector. Disabling the fix reproduces the failures, including SVG width reverting to `auto`. Four existing animation/filter test files pass serially, and four frozen-page image pairs remain exact at both scales and offsets. Fresh startup and a normally active live window pass: GitHub is 20×20, social icons are 24×24, the document is complete and fonts loaded, with zero native script errors and browser exit zero.

One complete unprofiled live trial with the standard 600-event schedule measures **8.54 FPS**. Its read-only pre-input audit confirms correct sizing and the JavaScript-mutated macOS download icon. The next trial exits 139 in `chromium_text_srgb_color` while recording early text paint, before input, and is invalid. Both attempts remain retained. Separate native sampling during actual input is diagnostic only: gradients, outer shadows, rounded boxes, images, glyphs and shared-picture publication dominate. The short layer dump has insufficient moving publications for FPS, and supplies only paint-command evidence. No timing from malformed rendering, profiling, or incomplete content earns optimization credit.


## Direct gradient-blur backdrops

The [blur checkpoint](benchmark-results/vlang-scroll-20261102-gradient-blur.json) and [compressed raw delta](benchmark-results/vlang-scroll-20261102-gradient-blur-raw.json.gz) retain 208 trial summaries, all failed attempts, source/build identities, resource audits, host load and actual exits. Commit `02b4b21e` uploads opaque regional blur backdrops directly through the existing transactional Dawn API. It avoids a background image inside the serialized picture while keeping the original target, blur coordinates and crop. Unsupported or failed transfers retain ordinary replay.

The focused test makes 48 exact comparisons in each normal and sanitizer run, for both prototype and final source. It covers two scales, linear/radial inputs, padded rows, translucent fallback and forced partial-write rollback. Four frozen-page pairs remain exact at scales 1/2 and offsets 0/240. Separate actual-input diagnostics confirm 41 prototype and 39 final direct calls; loading counts are separate.

| Cohort | Control FPS | Candidate FPS | Qualification |
| --- | ---: | ---: | --- |
| Prototype pair 1 | 10.297 | 10.656 | Complete, matching content audits |
| Prototype pair 2 | 10.361 | 10.445 | Complete, small gain |
| Final pair 1 | Invalid | 9.573 | Control crashes in CSS decoding before input |
| Final pair 2 | 8.489 | 8.998 | Mean improves; median 101.70→106.98 ms and p95 120.72→140.56 ms regress |

The final cohort is incomplete, so it supplies no complete optimization acceptance. The source change has exact correctness checks and reduces intermediate transport; these results do not establish smooth scrolling. No attempt is excluded or retried to pass.

A newer shared Pikabu production build already contained the final blur source and animation-selector correction. Its required task inputs are stable; unrelated form/event files changed during compilation and remain recorded. It was reused, signed/verified and smoke-checked without another production build or native install. Two fresh live processes on this installed identity complete with correct icon sizes, the JavaScript-mutated macOS icon, matching cached author CSS, complete readiness, loaded fonts and zero native script errors. They measure **6.502 / 8.998 FPS**, with median **128.85 / 109.69 ms** and p95 **170.39 / 125.39 ms**. Whole-build and host variation cannot be attributed entirely to the blur change. The earlier paint/CSS/TLS crashes remain unresolved. No retired-instruction savings or broad-suite carry is claimed.


## Animation storage lifetimes and rejected sparse readbacks

The [lifetime and rejection checkpoint](benchmark-results/vlang-scroll-20261102-lifetimes-rejections.json) and [raw delta](benchmark-results/vlang-scroll-20261102-lifetimes-rejections-raw.json.gz) retain subsequent trials, failures, commands, source witnesses, executable/library identities, resource audits, host conditions, actual input/publication timestamps and exits. Both rendering prototypes below were removed. No additional scrolling optimization is accepted here.

`1239aa45c` preserves an animation-owned copy-on-write property page even when its style, store and individual values live elsewhere. Previously retirement could reset that page while an installed style still read its slots. `38e2d26dd` follows a retained density projection and its resolved style/provenance as well. A projected style can borrow old samples after its CSS source has replaced them. Both preallocation regressions fail before their respective fixes and pass afterward, including normal arena release after the last reader disappears. Existing animation/selector and density-projection checks pass. These are ownership fixes, not demonstrated FPS gains.

The shared production guard was initially busy. The available completed bundle was reused for applicable checks; no duplicate build was queued. Its two fresh live trials measured 7.770/7.377 FPS while another production build ran, with all intervals over budget. That pinned bundle contained disabled contour code. The shared build subsequently restored canonical native source itself, so the blocked native-restoration attempt was not repeated. The later projection protection required a new build because available executables lacked it. That build has stable source inputs, passes fresh startup checks and uses the canonical Metal backend; four old/new frozen pairs remain pixel-exact.

A separate live diagnostic on the new build completes, but records zero property-page/projection retention hits. Earlier CSS decoding crashes therefore remain unresolved evidence; the ownership fixes are not claimed as their proven root cause. A short all-arena-poisoning run completes without a fault and supplies no performance acceptance. Its diagnostic schedule and all prior failed debugger/probe attempts remain preserved.

| Rejected experiment | Control FPS (1 / 2) | Candidate FPS (1 / 2) | Result |
| --- | ---: | ---: | --- |
| Precise-color stroke extension | 11.381 / — | 10.580 / — | Corrected diagnostic shows zero newly eligible calls; cancelled after the first pair |
| Separate elliptical contour transfers | 10.579 / 10.189 | 10.241 / 10.174 | Mean FPS regresses in both pairs |
| Packed contour atlas | 11.390 / 10.561 | 10.946 / 10.647 | Mixed mean FPS; median intervals regress in both pairs |

The stroke extension passes 864 GPU comparisons and frozen images, but an earlier counter included 342 existing byte-color fast-path calls. The corrected counter reports zero new live calls. Video/gradient layer batching also preserves four frozen pairs, but covers only small layers and leaves the expensive main layer ineligible. Both changes were removed without optimization credit.

The contour prototypes preserve the full original GPU targets, matrices, coverage and backdrop pixels. Each checked version passes 192 complete GPU comparisons; rotated/cropped ellipses, fractional coordinates, both scales, multisampling, precise colors, mutable backdrops and row padding are covered. Packed transfers additionally preserve every pixel through nearest source replacement. Four frozen pairs per checked page version are exact. Timestamped live diagnostics verify 39 uses during actual input, separately from startup/settle and trailing frames. The serial prototype regresses, and packing into one readback fails to produce a consistent gain. Raw variants, authenticated source witnesses, failed diagnostic loads and complete alternating cohorts remain preserved; references and tolerances are unchanged.

The final production snapshot below contains the two lifetime fixes and excludes all rejected native rendering experiments. Both fresh processes pass the matching-title, complete-document, loaded-font, icon-size, JavaScript mutation and cached-author-CSS audits. They describe the complete pinned build and shared host conditions, not an isolated contribution of either lifetime fix.

| Production snapshot `0ff019c5` | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Live 1 | 8.671 | 44.78 | 600 / 120 | 99.42 / 119.81 / 660.82 | 100.00% | 1065.82 / 52.90 |
| Live 2 | 9.642 | 52.50 | 600 / 115 | 99.46 / 122.48 / 211.68 | 100.00% | 271.52 / 44.61 |

The protocol remains 600 precise delta-2 native wheel events requested at 60 Hz, reversed every 60 events, a 1024×768 document viewport at scale 2, empty private profiles/caches, direct live HTTPS and the matching title followed by 20 seconds of settling. Throughput uses the entire first-to-last actual input window. No author animation or paint setting changed in acceptance trials. Diagnostic runs are separate. No retired-instruction savings or broad-suite carry is claimed.


## Shadow batch rejection and typed color payload lifetime

The [checkpoint receipt](benchmark-results/vlang-scroll-20261102-shadow-payload.json) and [compressed raw evidence](benchmark-results/vlang-scroll-20261102-shadow-payload-raw.json.gz) retain the shadow experiment, its removal, all resumed attempts, source and binary identities, commands, input/publication records, content audits, host load and actual exits. The raw archive contains its own artifact records and hashes; it needs no historical delta base. Full files remain under `Build/vlang-scroll-compositor-20261101-111741/`. No new retired-instruction savings or broad-suite carry is claimed.

The experiment batches independent transparent shadow surfaces into one GPU submission and wait. Collection preserves normal replay order, destination clips and parameter identity. Its native tests pass 192 exact GPU comparisons and 36 integrated rendering scenes with 60 verified prefetched uses. Four frozen-page comparisons are exact at scales 1/2 and Y=0/240. Separate timestamped live diagnostics establish 27 batches and 132 uses during actual input, excluding startup/settle. The approximately 2.00→1.28 ms native diagnostic does not measure scroll FPS.

The original unprofiled cohort stops when its candidate crashes in `chromium_svg_paint_components` before input; its completed control measures 10.32 FPS. That failure remains retained. The resumed cohorts below each use two complete alternating control/candidate pairs on one pinned executable and native-library set. The follow-up version also defers fallback buffer allocation during collection and prefetched replay; its 36 native scenes and four additional frozen pairs pass exactly.

| Rejected version | Control FPS (1 / 2) | Candidate FPS (1 / 2) | Median interval, control→candidate (ms), pairs 1 / 2 | p95 interval, control→candidate (ms), pairs 1 / 2 |
| --- | ---: | ---: | --- | --- |
| Original shadow batch | 9.996 / 10.972 | 10.758 / 10.323 | 98.26→92.09 / 88.64→95.06 | 116.10→104.16 / 102.23→112.58 |
| Deferred fallback allocation | 9.187 / 10.275 | 9.546 / 10.185 | 95.59→101.74 / 94.51→96.55 | 112.37→131.96 / 110.72→111.36 |

Every scrolling interval exceeds 16.67 ms. Both versions regress mean FPS in their second pair, and the allocation version regresses both median/p95 pairs. Host contention remains recorded: one-minute loads span approximately 5.18–9.02 on 18 logical CPUs. Both experiments, their V bridge, native API and tests were removed from canonical source; their source witnesses remain archived. Their prototype correctness checks supply no accepted optimization credit.

All eight complete runs have complete readiness, loaded fonts, zero reported native script errors, 20×20 GitHub and 24×24 social icons, and the JavaScript-mutated macOS download icon. The cached 51,866-byte author stylesheet is identical in every run (`b71286ffeac1c0622b63535dcea97bc74dd25a7d3073d21cdd19919e126b6ed2`). The workload remains 600 precise native delta-2 wheel inputs requested at 60 Hz, reversed every 60 inputs, with a 1024×768 document viewport, backing scale 2, private empty profiles/caches, automatic author scripts, matching-title readiness and 20 seconds of settling. Throughput uses the entire actual first-to-last input window. References, tolerances, author animations and acceptance paint settings remain unchanged.

Commit `34ab5e7dc` fixes another demonstrated animation ownership gap: a persistent DOM value and opaque typed box can still borrow color-component arrays allocated in a retiring sample arena. Retirement now checks the typed payload's pointer fields before releasing that arena. The new regression fails before the fix, then passes while verifying both retention and later release after replacement. Together with the existing property-page, density-projection and target-list checks, five preallocation cases pass through separately guarded compile/runtime jobs. The new file's Boehm execution has a compiled-out body and earns compilation evidence only.

No available completed browser contained that fix, so production was rebuilt under the shared guard. The initial build caught a helper reference left during experiment removal; the serial shadow body was restored, and both attempts remain retained. The successful build pins executable `399be67f`, has stable required inputs, passes strict signing and fresh headless startup, excludes the shadow experiment, and preserves all four before/after frozen-page comparisons exactly. Only another session's diagnostic test file changed during compilation.

Its first unprofiled live attempt exits 139 in SVG style conversion during settling, before wheel input. The cohort stops and has no production FPS result. Three subsequent, separately labelled diagnostic launches complete without reproducing the fault; they are not acceptance retries. The signal-interposition experiment never logs installation and supplies no fault-register evidence. The ordinary fault probes install but observe no fault. The typed-array lifetime fix therefore is not a proven cause or resolution of the intermittent CSS/SVG crash, and smooth live 60 FPS remains open.


## Combined-picture eligibility follow-up

The [checkpoint](benchmark-results/vlang-scroll-20261102-dynamic-picture.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-dynamic-picture-raw.json.gz) preserve all attempts, commands, source/binary identities, content audits, exact input/publication records, native samples, failures and actual exits. Full artifacts remain in `Build/vlang-scroll-20261102-0833/`. No rendering optimization, retired-instruction savings or broad-suite carry is accepted here.

The existing completed browser was pinned before making changes. Both fresh live runs pass readiness, font/error, icon-size and JavaScript-mutated download-icon audits with identical 51,866-byte author CSS (`b71286ffeac1c0622b63535dcea97bc74dd25a7d3073d21cdd19919e126b6ed2`). The protocol remains 600 precise native delta-2 wheel events, requested at 60 Hz and reversed every 60 inputs, after title readiness and 20 seconds of settling; the document viewport is 1024×768 at scale 2 with private empty profiles/caches and direct HTTPS. OS caches remain enabled. Throughput uses the full first-to-last actual input period.

| Complete build verification | Scroll FPS | Actual input Hz | Inputs / publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Original baseline 1, `7a702c0d` | 9.974 | 50.63 | 600 / 122 | 93.30 / 109.76 / 751.63 | 100% | 162.53 / 60.12 |
| Original baseline 2 | 10.791 | 52.98 | 600 / 126 | 93.34 / 107.00 / 113.11 | 100% | 207.00 / 0.42 |
| Later completed bundle 1, `859d0933` | 7.830 | 50.98 | 600 / 96 | 125.12 / 147.51 / 157.10 | 100% | 304.09 / 104.51 |
| Later completed bundle 2 | 8.315 | 52.43 | 600 / 99 | 117.60 / 137.17 / 150.78 | 100% | 244.84 / 113.17 |

These are separate whole-build verification cohorts, with host load and concurrent work retained. They do not isolate any one change. The later bundle was initially selected for restoration, but it contains rendering changes absent from canonical source. That selection was corrected: the original verified `7a702c0d` bundle was restored under the shared guard, with matching executable/library hashes and fresh headless startup. Both displaced bundles and every slower result remain preserved. Existing GUI processes were not used as proof of the restored executable.

A separate live diagnostic samples actual input and finds the large layer first rejected at a CSS gradient. The opt-in experiment admits gradients and frame bitmaps into complete pictures. The shared build guard was initially busy; the existing bundle supplied applicable baseline checks, with no duplicate build queued. A subsequent experiment build completes, but concurrent changes to the eligibility source fail the required-source stability gate. Its pinned disassembly verifies the opt-in gradient/video branches; the image is used only diagnostically.

Four frozen comparisons at scales 1/2 and Y=0/240 remain exact. However, the native picture trace is unchanged: after the first rejection is bypassed, intervening layers still require paint metadata that this plan lacks. The expensive layer remains on separate leaf replay. Pixel equality therefore supplies no fast-path execution or FPS credit. No unprofiled prototype FPS cohort was collected. The experiment was removed, and commit `7ece99aa5` adds a diagnostic for that previously silent rejection without changing its result. The existing CSS-gradient compositor test file passes through guarded compile and runtime checks. The restored browser predates this logging-only change; no new production logging claim is made.

Commit `577cf4afb` retains a useful native regression: 48 independent complete GPU scenes combine generated gradients with changing frame pixels, then overwrite and release each source frame before recorded replay. Both scales, direct/pattern gradients, backdrop modes and trimmed ink remain exact. An initial reference omitted the required image serialization callback and failed; the corrected reference passes, followed by the stronger ownership check. Both failures and successful checks are retained. Earlier reference variants in the archive are labelled reconstructions, not original hashed witnesses.

Debugger attempts also remain diagnostic: the first stops at an executable restart, the second exceeds its 3 GiB guard, and a corrected normal-budget run completes all 600 inputs with browser exit zero. Its LLDB process then exits one because register inspection occurs after the browser has exited. No fault registers were captured and no crash resolution is claimed. Smooth live 60 FPS remains open; further work must preserve layer ordering and raster precision while making the expensive picture eligible.

## Staged runtime identity correction

The [checkpoint](benchmark-results/vlang-scroll-20261102-runtime-identity.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-runtime-identity-raw.json.gz) retain 508 artifact records, source witnesses, commands, audits, samples, all failed attempts and actual exits. Fifty-two PNGs remain under `Build/vlang-metadata-20261102-0912/`, with their hashes in the archive. No scrolling optimization, instruction savings or broad-suite carry is accepted at this checkpoint. Smooth live 60 FPS remains open.

The investigation found a packaging regression introduced by staged builds. V modules still add canonical `Build/v` to the executable's runtime search paths. Packaging removed the staging directory but left that earlier canonical path ahead of `@executable_path`. A live dyld trace confirms the process loading `Build/v/libLadybirdVSkiaText.dylib`, `Build/v/libVoxGraphite.dylib` and `Build/v/libVoxGraphiteDawn.dylib`, rather than the signed app's copies. Pinning only the bundle files therefore did not establish which substituted native code ran. Earlier zero-counter conclusions about shadow and gradient-region eligibility were premature: the new library could simply be absent from the process.

Commit `b622df245` removes both external build paths. Its regression uses real Mach-O executables with different shared and bundled library results: it fails against the previous helper and passes after localization and signing. All three packaging tests pass, including idempotence and rejection before mutation when the bundle search path is missing.

Commit `51eb23b02` makes the canonical scroll observer record the native image paths actually loaded. The driver requires the renderer record, rejects malformed identities or paths outside the selected bundle, and requires every observed image to have been pinned before launch. All 22 tests pass, including a real dyld callback test with spaces and non-ASCII path bytes. A separate short file-page diagnostic completes all ten inputs with browser exit zero; the driver then correctly rejects the installed browser's external renderer path. This is an expected identity-gate rejection, not an FPS result. An earlier literal-HTML diagnostic instead hits the existing missing-source-origin panic for `about:srcdoc`; that failed attempt is retained separately.

The rendering experiments were removed. Full paint metadata was tested independently of culling, including atomic opacity/filter/blend runs; a later experiment recorded uninterrupted compositor spans. Some frozen comparisons match and others differ. Expanding the scalar shadow cache and adding an exact gradient-region cache also produced matching images, but private native-library substitution checks lack verified loaded-image identities and cannot validate the substituted implementation or its live use. The direct library-handle test's 776 exact GPU comparisons and the ownership/admission tests remain focused native evidence only. No matched, unprofiled scrolling cohort was collected for these experiments, and references or tolerances were not changed.

A separate canonical diagnostic completes 600 inputs and a three-second native sample. It remains profiled evidence, with the external-library qualification above. Work is spread across rounded geometry, gradients, shadows, glyphs, image draws, compositing and GPU waits. Another launch receives an AppKit quit event during replay and panics while cleanup releases an entered scratch arena. A distinct dyld diagnostic exits 139 in `chromium_text_srgb_color` during settling, before input. Neither failure establishes a resolution of the earlier intermittent SVG/CSS lifetime fault.

Historical private bundles and tool copies predate the repository's new prohibition on such snapshots. The private app copies subsequently disappeared; their recorded identities remain, and subsequent checks use the canonical bundle and tools directly. The final recorded canonical executable is `e9b1cdeb`, with the defective search path still present. The shared production build guard is busy; no separate production build was queued or bundle overwritten. The committed packaging fix and stricter probe still need verification together on a newly published canonical bundle before live FPS acceptance can resume.

## Large shadow cache rejection and snapshot pool ownership

The [checkpoint receipt](benchmark-results/vlang-scroll-20261102-large-shadow-owner.json) and [compressed raw evidence](benchmark-results/vlang-scroll-20261102-large-shadow-owner-raw.json.gz) retain all attempts, input/publication timestamps, loaded-image identities, content audits, native checks, failed diagnostics, build receipts and actual exits. Full artifacts and PNGs remain in `Build/vlang-large-shadow-20261102-1055/`. Every new browser run references the canonical bundle and repository tools directly. No rendering optimization, instruction savings or broad-suite carry is accepted here.

Commit `680bfd247` lets the shared build controller publish a completed browser across documentation-only commits. Receipts retain both full repository identities and the production-input digest; native code, assets and tools still invalidate a changed build. Nine controller tests pass. The obsolete worker was stopped between compiles, with no compiler or smoke child interrupted. Receipt `20261102-113808-1ac25d97` publishes executable `192ff348` across different documentation heads with identical production inputs. Fresh startup, strict signing, all eight frozen capture launches and the live observer confirm bundle-local native library loading. The earlier external-runtime defect is no longer present in these measurements.

Commit `c7b655ff2` exposes the observer's actual input clock to native diagnostics. Its 23 tests pass. The opt-in large-shadow experiment admits transparent raw surfaces up to 16 MiB while retaining the existing 8 MiB cache budget, repeat-admission policy and byte-exact output. It passes normal/sanitized ownership and admission checks, 180 exact native GPU comparisons, and four exact frozen-page pairs at scales 1/2 and Y=0/240. The direct GPU test's duplicate Objective-C class warning remains retained. None of these checks measures scrolling FPS.

The first live diagnostic exits 139 during settling, before any input: the initial fault is in `chromium_text_srgb_color`; a later HTTP/2 reader fault does not identify the original cause. Debugger setup attempts, a 3 GiB guard termination and a separate null-pointer stop in `idle_layout_snapshots_equal` remain preserved. Subsequent complete debugger runs are diagnostics only. The 600-input diagnostic independently verifies **45 large-shadow cache hits during the input window**, separately from 1,073 earlier calls and trailing work. Readiness, fonts, native error count, icon sizes and the script-mutated download icon pass the content audit.

The following unprofiled trials alternate on one unchanged executable and native-library set. All four complete with browser and guard exit zero, validated native image paths, and identical 51,866-byte author CSS (`b71286ffeac1c0622b63535dcea97bc74dd25a7d3073d21cdd19919e126b6ed2`).

| Live trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Control 1 | 11.009 | 52.76 | 600 / 130 | 88.45 / 102.95 / 173.60 | 100% | 233.35 / 37.28 |
| Candidate 1 | 10.766 | 52.43 | 600 / 129 | 91.48 / 107.68 / 168.68 | 100% | 200.25 / 46.19 |
| Control 2 | 10.495 | 52.83 | 600 / 124 | 92.63 / 109.77 / 113.33 | 100% | 211.52 / 63.33 |
| Candidate 2 | 10.708 | 52.58 | 600 / 129 | 90.08 / 108.29 / 164.70 | 100% | 209.86 / 81.02 |

The workload remains 600 precise native delta-2 wheel events requested at 60 Hz, reversing every 60 events, after matching-title readiness and 20 seconds of settling. Each trial has a fresh process, empty private profile/cache, direct HTTPS, automatic author scripts, a 1024×768 document viewport and backing scale 2. OS caches remain enabled. Throughput covers the entire first-to-last actual input period. The 18-CPU host's one-minute load spans 2.84–4.45. The candidate loses the first pair and wins the second; cohort medians are 10.752 control and 10.737 candidate. Commit `717254858` removes the prototype and its tests; source witnesses and every result remain archived. The restored shadow-cache regression passes.

Commit `5e81d64c6` fixes a demonstrated ownership gap discovered while investigating the null snapshot. A final animation update can remove its animated properties before resolving ordinary values inside the sample arena. Initial snapshot interning previously put its document-wide pool, or a new pooled snapshot, into that reusable arena. The pool is outside the target graph inspected by animation retirement. Such updates now retain ordinary target-owned snapshots and skip interning. The new regression fails before the guard; both new-pool and existing-pool cases pass afterward, along with all 11 existing initial-snapshot tests under preallocation. This establishes the lifetime fix, not the root cause or resolution of the intermittent live fault, and earns no FPS credit.

Concurrent source edits supersede two completed builds, and the first bounded readiness check ends without launching a browser. Receipt `20261102-120648-95563443` then publishes executable `c1a609e1` with stable required inputs, the ownership guard and the shadow experiment removed. A separate resumed check passes fresh startup, strict signing and four exact before/after frozen pixel comparisons. Its first live trial exits 139 in `chromium_text_srgb_color` during settling; the cohort stops before input. There is no new installed-build FPS result, and the ownership guard does not resolve the recurring live fault.

A subsequent debugger run on `c1a609e1` captures registers and a full first-fault stack: SVG paint conversion reaches `typed_property_value`, falls back to parsing CSS text, and `decode_css_input` reads the invalid address `0x5100000001e`. This establishes a malformed style text pointer, without identifying its writer or lifetime owner. The follow-up memory-inspection run and an all-arena-poisoning run each complete 600 inputs without reproducing that fault; both remain instrumented diagnostics. Their successful exits are not acceptance retries or evidence that the crash is fixed. No duplicate production build was queued, and the 60 FPS target stays open.

## First-fault diagnostics and region-cache eligibility

The [checkpoint](benchmark-results/vlang-scroll-20261102-fault-region.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-fault-region-raw.json.gz) retain every attempt, commands, source/build identities, actual input/publication records, content audits, failed setup and test attempts, guard exits, native samples and rejected patch. Full files remain in `Build/vlang-style-owner-20261102-1220/`. No optimization or retired-instruction credit is accepted, and the broad-suite savings carry is unchanged.

The new fault-recorder launches and debugger runs do not reproduce the malformed style pointer. These diagnostic successes do not resolve the earlier crash. Commit `480bd2db6` adds `--capture-faults` to the canonical observer, avoiding another injected library. It explicitly labels the run diagnostic, pins the helper header and records the actual executable text range, first-fault registers, frame pointers and bounded readable memory. Mach reads avoid dereferencing invalid pointers, and the handler exits without allocator cleanup. Ordinary runs leave the handler disabled, including with an ambient enabling variable. All 25 observer tests pass; controlled SIGSEGV and SIGBUS cases verify fault evidence and preservation of the disabled handler. Commit `fad500edb` exercises SIGBUS through the native run loop; the earlier libdispatch-worker fixture failures remain retained.

External `sample` attachment is denied by macOS and supplies no profile. A separate in-process main-thread sampler completes 301 samples between input timestamps 1.547 and 4.550 seconds, entirely inside the actual input window. Executable identity and text ranges are verified. Of those samples, 288 include native frame rendering. Selecting the nearest matching paint caller gives 54 rounded-rectangle, 53 CSS-gradient, 40 outer-shadow and 20 glyph samples; the remaining 134 have other callers. These are diagnostic stack counts, not isolated timings or unprofiled FPS evidence.

The opt-in path-region cache retains original GPU dimensions, matrices, clips, gradient stops, source bytes and backdrop pixels. Its normal and sanitizer ownership/budget checks pass. The strengthened GPU test repeats identical inputs through initial drawing, cache admission and cache reuse: **1,928 exact comparisons with 1,008 verified hits** pass. The earlier 776-comparison run had no verified cache hits, so it established only uncached region rendering. The duplicate Objective-C class warning from direct two-library tests remains retained.

The shared worker publishes `ae08e7ca` with the experiment after superseding earlier compiles on changed source inputs. No duplicate production build is queued. Fresh startup, strict signing, actual bundled-library identities and all four frozen-page pairs at scales 1/2 and Y=0/240 pass exactly. The separate 600-input live diagnostic, however, records **zero region API calls during input**. The matched unprofiled experiment cohort is not started. Commit `d00daad05` removes the prototype; source hashes match the original renderer and cache implementation. The stronger GPU target-reuse test remains, and all 1,928 comparisons also pass with the restored implementation.

A debugger probe verifies the full-surface API's instruction location and cache-result layout, then captures 64 calls during input. Eighteen are gradients with no observed cache hit; six small solid-path calls hit the existing cache. The trace shows changing gradient surface heights. Its samples do not establish a whole-window hit rate, an admission failure's cause, or a scrolling gain, but identify the API the expensive gradients actually use.

Two fresh unprofiled default-path verifications on the same `ae08e7ca` executable and native-library set complete with browser and guard exit zero. The fault recorder and region-cache flag are disabled. These whole-build results do not isolate any change from the preceding build.

| Live default verification | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| 1 | 10.587 | 52.41 | 600 / 127 | 90.89 / 107.64 / 165.31 | 100% | 208.53 / 84.99 |
| 2 | 11.156 | 53.89 | 600 / 130 | 88.48 / 100.33 / 162.71 | 100% | 209.35 / 75.57 |

Both trials pass document readiness, loaded-font, zero-native-error, 20×20 GitHub icon, 24×24 social icon and script-mutated download-icon audits. Author CSS remains 51,866 bytes with SHA256 `b71286ffeac1c0622b63535dcea97bc74dd25a7d3073d21cdd19919e126b6ed2`. The workload remains 600 precise native delta-2 wheel events requested at 60 Hz, reversing every 60, after matching-title readiness and 20 seconds of settling; the document viewport is 1024×768 at scale 2. Each trial uses a fresh process and empty private profile/cache, direct HTTPS and automatic author scripts. OS caches remain enabled. Throughput uses the full first-to-last actual input period; host load and timestamps remain in the receipt. The 60 FPS target stays open.
