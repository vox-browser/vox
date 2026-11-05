# vlang.io scrolling

The live **60 FPS target remains unmet**. The latest fully pinned default-path cohort (`0bb14e2f`) measures **10.56 / 10.12 scroll-changing publications/s**, with every measured interval exceeding 16.67 ms. Raster staging produces mixed results and is removed. A separate unpublished native image-cache candidate improves both pairs but remains near 8–9 FPS on its different native configuration, with correctness and installed-browser validation pending. The native complete-picture experiment has a failed complete-content audit and supplies no FPS credit. These are Cocoa layer publications; physical display scanout is unmeasured. See the [native candidate checkpoint](#static-pages-and-unpublished-native-candidates).

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

## Canonical path admission identity

The [admission checkpoint](benchmark-results/vlang-scroll-20261102-path-admission.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-path-admission-raw.json.gz) retain the failing regression, focused checks and native GPU comparisons for `b252cc7d9`. The cache's admission history hashed raw descriptor bytes even though full rendering equality ignores struct padding and disabled clip/color payloads. Equivalent descriptors could therefore fail to accumulate enough uses for admission. The fix hashes the same fields as rendering equality, preserving exact floating-point bits, budgets and full backdrop/geometry/pixel validation.

Both padding and disabled-payload regressions fail before the fix and pass afterward, including under ASan/UBSan. Ninety-six native scenes across scales, backgrounds, gradients, strokes, clipping and color spaces pass all 384 exact comparisons. Canonical admission supplies 96 verified hits, including 64 gradient hits; the same binary with the old admission hash supplies zero hits. These are deterministic native admission/correctness checks, not scrolling performance results.

The bounded browser-validation pipeline waits ten minutes without finding a completed production bundle containing the fix and launches no browser trials. Concurrent source changes supersede the shared builds; the available bundle remains usable for baseline work. Frozen-page and live-path/FPS validation of this change remain pending. No rendering tolerance, reference, unprofiled FPS result or instruction-savings carry changes.

## V function profile of live scrolling

The [V profile checkpoint](benchmark-results/vlang-scroll-20261102-v-profile.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-v-profile-raw.json.gz) retain both actual live runs, full function reports, compile commands, source/generated-C identities, loaded-library identities, content audits and actual browser/driver/guard exits. The user-requested `v -profile` diagnostic enables counters inside `main__BrowserApp__draw` and `main__BrowserApp__handle_event`, including their callees, with `-profile-no-inline`. The native observer confirms `SCROLL_PROFILE_RESET before_first_input=1 diagnostic_only=1` in each run.

The original combined V/Clang compile exceeds the default 12 GiB aggregate guard. The interruption and later adoption of its orphaned compiler are retained. Compiling the same generated C separately at `-O1` succeeds with unchanged inputs and a 9,326,329,856-byte sampled peak. This produces the bare diagnostic executable `Build/v/Vox-profile` (`0ef490f4`), using existing production native libraries. The production app is not replaced or copied. This unpublished instrumented executable differs from the normal `-O3` production build and cannot establish production FPS.

Both fresh live launches complete all 600 precise native delta-2 wheel inputs, reversing every 60 events, with the verified vlang.io title, 1024×768 document viewport and backing scale 2. Profiles/caches are empty, networking is direct HTTPS, author scripting is automatic and OS caches remain enabled. The first trial uses the usual 20-second settle, but its independent scheduled audit still records an interactive document and loading fonts. Its browser and precise driver exit zero; the validating wrapper/guard child exits one. This incomplete-content diagnostic remains retained. The second trial extends settling to 60 seconds and passes readiness, fonts, native-error, icon-size and script-mutated download-icon checks. Its author CSS is the unchanged 51,866-byte `b71286ff…` stylesheet; browser, precise driver, wrapper and guard all exit zero.

The second profile records 66 draw calls taking 12,000.572 ms inclusive. Selected main-thread rendering callers are:

| V function | Calls | Inclusive time (ms) | Exclusive time (ms) |
| --- | ---: | ---: | ---: |
| `BrowserApp.draw_command` | 11,319 | 5,919.162 | 3,888.052 |
| `draw_native_css_gradient_tile` | 310 | 1,430.067 | 1,429.358 |
| `BrowserApp.draw_chromium_rounded_background_pair` | 771 | 771.451 | 762.902 |
| `native_draw_retained_glyph_run` | 2,174 | 553.489 | 547.179 |
| `BrowserApp.relayout` | 36 | 2,751.048 | 0.067 |
| `AnimationSampleStorage.retire_unreachable` | 66 | 576.558 | 0.035 |

Native C calls are charged to their V callers. Exclusive paint-command time averages 58.91 ms per draw callback, gradient tiles 21.66 ms, rounded-background pairs 11.56 ms and glyph replay 8.29 ms in this instrumented build. Relayout averages 76.42 ms per invocation, or 41.68 ms amortized across those draw calls. These findings prioritize native leaf replay/gradient submission and repeated layout work; they do not establish the corresponding unprofiled costs or savings.

The generated C also reads the profile timer at every instrumented function entry, even when `-profile-fns` suppresses counter accumulation outside the chosen roots. Getter-heavy tree traversals therefore incur substantial diagnostic overhead. The roughly 60 ms attributed to paint reconstruction is not a predicted unprofiled saving. The compiler witness is `vlib/v/gen/c/profile.v` in the pinned V source; generated-C and compiler identities remain in the profile checkpoint.

V's profile enable flag and per-function counters are process-global. Background socket waits and timer sleeps also accumulate while a rendering root enables profiling, so the full exclusive sum is not a main-thread time partition. Their large raw totals must not be attributed to scroll blocking. Inclusive roots and callees overlap and must not be added. Counter reset is confirmed before input, but a function already active at reset can still contribute its elapsed time when it returns; exit-written reports also include tail callbacks inside the selected roots. These are function-profile diagnostics, not an exact closed first-to-last input interval.

No unprofiled optimization cohort, cache-path credit, instruction saving or CSS/SVG crash resolution is claimed. At that profile checkpoint, verified production throughput was 10.59/11.16 scroll-changing publications/s. Later matched results appear below; smooth live 60 FPS remains open.

## Preserving geometry for paint-only script callbacks

The [callback checkpoint](benchmark-results/vlang-scroll-20261102-js-paint-sync.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-js-paint-sync-raw.json.gz) retain the profile-guided fix `a6e56210e`, source witnesses, exact commands, original failures and all focused compile/runtime receipts. The V profile's 36 relayouts expose a shell condition that treats stale paint alone as a reason to reconstruct committed geometry. After scrolling invalidates the display-list snapshot, even a read-only callback can enter that path.

Task polling and synchronous event replay now share a paint-synchronization helper. Actual script effects and stale style/layout keep their full relayout behavior. When only paint is stale, the helper preserves the cosmetic-filter refresh, lets Document apply any resulting invalidations, adopts current geometry and records paint immediately or at the existing frame boundary. Pending initial layout and absent committed paint geometry retain the full initialization path. Heap activity scopes and retained scene ownership remain intact. `VOX_DISABLE_JAVASCRIPT_PAINT_SYNC=1` selects the control path; `VOX_JAVASCRIPT_PAINT_SYNC_DIAGNOSTICS=1` reports the selected action in separate diagnostic runs.

Both new scroll/read-only-task and scroll/read-only-input regressions fail on the original implementation because paint-tree storage is rebuilt. Final guarded checks pass all 14 focused cases in each of preallocation/`-gc none` and Boehm. These cover immediate/deferred paint, preserved geometry, filter-generated width/color changes, first-layout completion and the existing callback, synchronous-query, canvas, selection and native-mutation behavior. The earlier 13-case checks, before the added startup guard, remain retained separately.

At that checkpoint, the available production executable `f769e44d` lacked the change and the shared guard was busy. Subsequent completed bundles contain the exact tested source blobs; current canonical history records the implementation as `deb357e953`. Fresh startup, four frozen-page pairs and eight same-size SVG source-switch/paint-server mutation comparisons pass. The timestamped live diagnostic below finds zero paint-only fast-path uses and 76 relayouts during actual input. No callback FPS gain, retired-instruction saving, broad-suite carry change or crash resolution is credited.

## Live callback and wheel validation

The [checkpoint](../Build/vlang-wheel-cohort-20261102-1540/checkpoint.json), [raw records](../Build/vlang-wheel-cohort-20261102-1540/raw-evidence.json.gz) and [artifact inventory](../Build/vlang-wheel-cohort-20261102-1540/artifact-inventory.json) retain commands, all attempts, source/binary identities, audits, actual input/publication timestamps, host load and exits. New generated benchmark data stays under `Build/`. Earlier historical receipts remain unchanged.

Canonical cache admission regresses in both unprofiled pairs on executable `ca64e029`: **9.399→6.810** and **7.476→7.004 FPS**. The separate native-clock diagnostic finds only one large-gradient cache hit among 480 candidate calls during input, against zero among 531 control calls. Commit `5635c85e9` restores legacy admission by default and leaves canonical admission behind `VOX_ENABLE_CANONICAL_PATH_ADMISSION=1`; the disable override takes precedence. ASan/UBSan cache checks, four policy configurations and 384 exact GPU comparisons per policy pass. All four frozen-page pairs are exact. The [complete failed performance experiment](../Build/vlang-native-admission-20261102-1513/cohort.json) earns no FPS credit.

Commit `c2e625121` fixes a production build collision between two static PNG readers by namespacing the color-profile reader. The combined-header regression fails before the fix; all eight guarded PNG checks pass afterward, including 120 ICC extraction cases. Failed and superseded shared build receipts remain retained. No duplicate production build was queued.

Commit `4a6354cc2` permits wheel-hit reuse with an initialized but quiet script runtime. It rejects pending script work, wheel listeners, document/runtime replacement, changed paint revision or viewport, and stale target layout. Six routing cases pass in each of preallocation/`-gc none` and Boehm, covering nested fractional scrolling, cancellation and queued overflow changes. Four frozen pairs and eight SVG mutation reftests are pixel-exact on the measured executable `6415ee31`.

The earlier callback/wheel eligibility summaries incorrectly classified engine messages by log position. The observer buffers `SCROLL_INPUT` and `SCROLL_PUBLISH` until completion, so those lines cannot delimit input. A [separately tested diagnostic interposer](../Build/vlang-wheel-live-20261102-1527/probe2-fixture-result.json) timestamps engine messages using the observer's exported clock. The [corrected diagnostic](../Build/vlang-wheel-live-20261102-1527/timed-eligibility.json) verifies **521 reused hits and 76 fallbacks** inside the actual first-to-last input window; three decisions occur in the tail. It also records **76 callback relayouts and zero paint-only refreshes** during input. Startup counts are separate. The original invalid summaries and first failed interposer fixture are retained and identified in the [scope correction](../Build/vlang-wheel-cohort-20261102-1540/diagnostic-scope-correction.json). This instrumentation is absent from the unprofiled cohort.

| Wheel-hit reuse, executable `6415ee31` | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Control 1, reuse disabled | 10.029 | 52.24 | 600 / 121 | 97.53 / 114.84 / 194.28 | 100% | 236.49 / 92.10 |
| Candidate 1, default | 10.141 | 51.92 | 600 / 121 | 95.73 / 115.88 / 135.16 | 100% | 202.66 / 25.37 |
| Control 2, reuse disabled | 9.964 | 53.29 | 600 / 116 | 97.99 / 118.00 / 182.83 | 100% | 227.32 / 0.18 |
| Candidate 2, default | 9.686 | 51.80 | 600 / 116 | 99.83 / 123.83 / 142.74 | 100% | 232.21 / 131.95 |

These earlier wheel measurements predate worker/runtime-input pinning and remain historical observations, not optimization acceptance. Raw values are preserved. All four processes, drivers and the aggregate memory guard exit zero. Control/candidate median throughput is 9.996/9.913 FPS; the pairs have mixed directions. One-minute host loads vary from 5.61 to 8.67 on 18 logical CPUs and rise during the later trials. This does not establish useful scroll performance improvement. Every measured interval misses the 60 Hz budget.

The workload is unchanged: direct live `https://vlang.io/`, automatic author scripts, fresh empty private profiles/caches, OS caches retained, matching-title readiness followed by 20 seconds of settling, 1024×768 document viewport, 112px chrome, scale 2, and 600 precise delta-2 native inputs requested at 60 Hz with reversal every 60 events. Throughput spans the entire actual first-to-last input period. Both arms use default legacy native cache admission and identical pinned executable/libraries. Complete-document, loaded-font, icon-size, script-mutated download-icon and 51,866-byte author-CSS audits pass; stylesheet SHA256 remains `b71286ffeac1c0622b63535dcea97bc74dd25a7d3073d21cdd19919e126b6ed2`.

An earlier `f769e44d` baseline measures 7.509 FPS under heavier host load; its second fresh process exits 139 in CSS tokenization reached from SVG paint conversion during settling. That failed cohort remains retained and does not supply a two-run baseline. The later successful diagnostics do not resolve that lifetime fault. No instruction saving or broad-suite carry changes at this checkpoint.

## Retaining paint snapshots across viewport relayout

The V function profile attributes 2,159.265 ms across 36 calls to `refresh_document_paint_tree`, about 60 ms per call in the instrumented build. The viewport layout entry point unconditionally reconstructs every paint box when the typed layout handle stays current but painting is dirty. This discards the existing targeted animation/style refresh and rebuilds unrelated SVG, image and text snapshots.

Commit `7665e66f8` uses the same dirty-style refresh as paint recording and hit testing. Stable compositor samples, local color updates and scroll invalidation retain current paint geometry; category changes, unsupported style updates, incomplete projections and real layout/viewport changes retain the existing full paths. At this viewport boundary, scrolled scrollbar boxes rerecord their commands to preserve fresh endpoint rounding. Ordinary scrolling without relayout keeps its existing behavior. `VOX_DISABLE_RETAINED_VIEWPORT_PAINT_REFRESH=1` selects the full-refresh control. The separate diagnostic reports actual native owner reuse, including full fallbacks.

The [focused checkpoint](../Build/vlang-viewport-refresh-20261102-1625/checkpoint.json), [raw records](../Build/vlang-viewport-refresh-20261102-1625/raw-evidence.json.gz) and [artifact inventory](../Build/vlang-viewport-refresh-20261102-1625/artifact-inventory.json) retain every attempt and fixture correction. Both original retention regressions fail before the fix. Seventeen focused cases pass in each of preallocation/`-gc none` and Boehm across five files. They compare retained paint with a full reconstruction, exercise transform/opacity/color samples, full fallbacks and resizing, and preserve fractional scrollbar rounding on both axes and nested scrollports. Boehm has no pooled paint arena owner, so its regression checks child-vector identity; the disabled control still fails that assertion. Earlier null-owner and scrollbar/category fixture failures remain retained.

The separate viewport-interest file fails its blue-background assertion at line 63 in both GC modes, identically with this optimization disabled. The diagnostic reports zero calls to the changed branch in that file. It receives no whole-file pass credit, and its existing projection failure remains unresolved.

Production validation is now complete on the selected executable `118eb72018bd9b0760daba7fd84828dbd145f73fc2ae0b08e77847519c7a7f60`. Four frozen-page control/candidate pairs at scales 1/2 and Y=0/240 and all eight required SVG mutation guards are pixel-exact. The separate native-clock diagnostic confirms **82 native paint-owner reuses during actual input**, zero rebuilds in that window, 107 startup reuses and four tail reuses. The [new checkpoint](../Build/vlang-viewport-pinned-20261102-1750/checkpoint.json) retains the completed matched cohort, all audits, runtime identities and guard exits. Earlier unavailable/superseded build attempts remain preserved. The native-clock probe's three-case fixture also passes. No CSS/SVG lifetime fault resolution is claimed.

A separate GPU-only [gradient-chain prototype](../Build/vlang-gradient-chain-20261102-1610/runtime.log) preserves each original target and byte-format resolve between draws while avoiding intermediate CPU readback. All 288 comparisons are exact. Its two-gradient native diagnostic measures approximately 3.95/4.01 ms for separate draws versus 0.93/0.97 ms for the chain. It has no browser integration or live eligibility evidence and earns no FPS credit; Quartz clips, layer recording and transactional fallback still require integration checks.


## Production validation with pinned runtime inputs

The [corrected checkpoint](../Build/vlang-viewport-pinned-20261102-1750/checkpoint.json), [raw records](../Build/vlang-viewport-pinned-20261102-1750/raw-evidence.json.gz) and [inventory](../Build/vlang-viewport-pinned-20261102-1750/artifact-inventory.json) retain all attempts, pixels, identities, audits, actual input/publication timestamps and exits. Earlier `c9f2ba4f` retention observations were 10.198→10.064 and 8.726→9.523 FPS. They omitted worker/runtime-input pinning and cannot supply optimization acceptance; their original measurements and the qualification remain [preserved](../Build/vlang-viewport-live-20261102-1630/checkpoint.json). The new attempt first rejected a changed production identity before launching any browser, then prepared matching inputs for the selected completed bundle.

Commit `6601e5a4e` pins the actual adblock worker and selected runtime assets in `measure_precise_scroll.py`. V's runtime-loaded embedded assets can change independently of the executable: a later checkout engine script rejected the older packaged snapshot even in an uninjected worker self-test. A three-file fixture extracted from the selected bundle's verified Git revision matches its packaged snapshot exactly and is selected through the existing `VOX_ADBLOCK_ENGINE_ASSETS` mechanism. The full algorithm, data and author-script policy are retained. The earlier failed worker/probe diagnostics remain preserved. Hashes plus device/inode/size/mtime/ctime identities now reject mutation and change-then-restore during a run. All 28 focused tool tests pass, including an integrated worker-mutation rejection. The initial path-alias fixture failure remains retained.

| Alternating live trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Control 1 | 10.460 | 52.65 | 600 / 124 | 94.95 / 108.77 / 177.89 | 100% | 211.58 / 0.14 |
| Candidate 1 | 10.820 | 54.93 | 600 / 122 | 91.10 / 108.50 / 113.93 | 100% | 241.37 / 16.94 |
| Control 2 | 10.607 | 52.08 | 600 / 126 | 93.59 / 105.95 / 114.51 | 100% | 217.69 / 25.70 |
| Candidate 2 | 10.522 | 54.33 | 600 / 123 | 92.31 / 107.86 / 195.08 | 100% | 153.62 / 89.81 |

Both pairs complete with all content gates, browser exits, driver exits and the aggregate guard at zero. Default-path throughput is 10.820/10.522 FPS against 10.460/10.607 with full paint reconstruction. One pair improves and one regresses; no reliable FPS gain is established. One-minute host load varies from 4.00 to 6.13 on 18 logical CPUs. A shared production compilation overlaps the cohort and is retained as host contention. Every measured scroll interval exceeds 16.67 ms.

The workload remains live direct HTTPS, automatic author scripts, a fresh empty private profile/cache per launch, OS caches retained, title readiness followed by 20 seconds of settling, 1024×768 document viewport, 112px chrome, scale 2, and 600 precise delta-2 Cocoa wheel inputs requested at 60 Hz, reversing every 60 events. The denominator is the entire actual first-to-last input window. Both arms use the same executable, native libraries, worker and runtime assets. Complete-document, loaded-font, icon-size, mutated download-icon and original 51,866-byte author-CSS audits pass. No reference or tolerance changed. The 60 FPS goal remains open.

## Native painting after the V profile

The [validated native diagnostic](../Build/vlang-native-paint-profile-20261102-1650/attempt7-allocator/validated-analysis.json) records 10,178 graphics calls, of which 9,942 are fully enclosed by the actual first-to-last input window. Boundary and tail calls remain separate. All 15 wrapped symbols resolve to the selected bundle's actual `libLadybirdVSkiaText.dylib`; parameter/return-value fixtures and an injected/uninjected frozen-page pair pass exactly. This separate diagnostic preselects the same effective `MallocSpaceEfficient=1` allocator policy so the production allocator's one-time self-exec cannot discard the main-process probe. Child helpers do not inherit that probe. Earlier failed setups, including missing helper symbols, mismatched assets and lost instrumentation across self-exec, remain retained and receive no performance credit.

| Native call group | Input calls | Inclusive wall time (ms) |
| --- | ---: | ---: |
| Rounded rectangles | 2,025 | 2,320.49 |
| Clipped radial gradients | 367 | 1,602.93 |
| Outer shadows | 635 | 1,383.25 |
| Glyph runs | 4,241 | 765.97 |
| RGBA images | 386 | 735.31 |
| Clipped linear gradients | 212 | 705.18 |
| SVG paths with colors | 1,624 | 505.48 |
| Inner shadows | 122 | 201.68 |
| Shared-recording finish | 330 | 76.26 |

Merging overlapping native-call intervals yields 8,296.47 ms inside the 11,411.70 ms actual input window. These are inclusive, instrumented wall durations, including waits; they are neither an exclusive CPU partition nor unprofiled FPS evidence. The profile directs further work toward native rendering/submission. No retired-instruction saving or broad-suite cadence reset is claimed.


## Rounded-tile batch rejection

The [live checkpoint](../Build/vlang-rounded-tile-live-20261102-1835/checkpoint.json), [raw records](../Build/vlang-rounded-tile-live-20261102-1835/raw-evidence.json.gz) and [inventory](../Build/vlang-rounded-tile-live-20261102-1835/artifact-inventory.json) retain every attempt, exact pixels, runtime identities, audits, input/publication records, host conditions and exits. The [native checkpoint](../Build/vlang-rounded-tile-batch-20261102-1827/checkpoint.json) retains the implementation witness, focused tests and removal checks. No retired-instruction reduction or broad-suite cadence reset is claimed.

A [separate rounded-shape diagnostic](../Build/vlang-rounded-profile-20261102-1820/groups.json) narrows the earlier native profile: two 959×439 fill/stroke groups account for about 486/484 ms across 122 calls each. The opt-in experiment `f31130bb6` renders independent original-sized corner tiles before sharing one GPU submission/wait. It preserves each tile's matrix, sample mode, immutable backdrop, owned texels and byte-format output. Packed cache entries include output-view coordinates. CPU views remain untouched until every transfer succeeds, including callbacks surviving a later failed job.

The backend passes 2,880 exact output-view comparisons and 1,152 transactional preflight rejections in normal and ASan/UBSan modes. Sixteen additional sanitizer cases force failures after GPU work is queued and before publication, verify unchanged caller output, then rerun successfully. The native painter passes 3,168 exact scenes, including 1,440 direct helper comparisons. Its batch path executes 354 times in that focused suite. The disable override passes the same 3,168 scenes with no batch use. Two-library tests retain the existing duplicate `VoxFrameMetalQueue` class warning; no sanitizer failure is reported.

Production executable `33a523c366e9fa302d6fc70cda94d065101ba0cc21fef9c1242f9d379b1c2e0d`, with verified source head `2b0af9e3b`, contains the exact tested implementation. A fresh startup succeeds. All four frozen-page pairs at scales 1/2 and Y=0/240 and all eight SVG source-switch/paint-server mutation guards are pixel-exact. The frozen fixture audit compares the earlier saved 34-file manifest and verifies that every file/directory ctime predates the captures; this compensates for the diagnostic driver's omitted new manifest without changing its original logs. The [audit](../Build/vlang-rounded-tile-live-20261102-1835/fixture-stability-audit.json) retains that qualification.

The independent native-clock diagnostic confirms **55 batch completions during actual input**, containing 110 tile jobs, 106 cache hits, six readbacks and only two submissions. Startup/tail counts remain separate. These low miss counts limit the possible GPU-wait saving. The first clock-fixture attempt loses its injected environment while launching the Python memory guard; it fails before any browser launch and remains retained. The corrected fixture passes the injected library explicitly after the guard, preserving original output and return values and adding exactly one correctly timestamped diagnostic record. No probe or counters run in the following unprofiled trials.

| Alternating live trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Control 1 | 10.817 | 53.11 | 600 / 128 | 89.28 / 104.69 / 164.93 | 100% | 238.50 / 73.52 |
| Candidate 1 | 11.050 | 53.81 | 600 / 127 | 90.33 / 103.38 / 106.82 | 100% | 146.90 / 23.62 |
| Control 2 | 10.935 | 53.25 | 600 / 128 | 90.27 / 101.15 / 105.33 | 100% | 199.99 / 81.58 |
| Candidate 2 | 10.932 | 52.81 | 600 / 128 | 90.99 / 103.17 / 106.83 | 100% | 223.88 / 0.12 |

Every browser, driver and the final aggregate guard exits zero. Complete-document, loaded-font, native-error, 20×20 GitHub, 24×24 social, script-mutated download-icon and original 51,866-byte author-CSS audits pass. The page, native libraries, worker and actual packaged assets are pinned throughout. One-minute host load spans 2.52–3.36 on 18 logical CPUs; no shared production compilation overlaps this cohort. Mean throughput improves in one pair and is effectively unchanged/slightly lower in the second; median intervals worsen in both, and every interval misses 16.67 ms. The experiment earns no accepted gain.

The workload remains direct live HTTPS, automatic author scripting and animations, a fresh empty private profile/cache, retained OS caches, title readiness followed by 20 seconds of settling, 1024×768 document viewport, 112px chrome, scale 2, and 600 precise delta-2 native wheel events requested at 60 Hz and reversed every 60 events. Throughput uses the full first-to-last actual input window. References, tolerances, rendering settings and default filter algorithms/data are unchanged.

Commit `a15e7ee71` removes the experiment, its native API and dedicated tests. All affected implementation paths match the feature parent exactly; added files are absent. The restored raster cache passes ASan/UBSan, and both native renderer components compile. The latest measured bundle still contains the disabled opt-in code; a shared production build is running, so fresh validation of its source removal remains pending. No additional full build was queued manually.

Commit `934678fc3` retains a measurement fix required by the newer bundle packaging: precise-scroll trials now pin the packaged codec and metadata alongside the snapshot. Explicit asset-directory selection remains authoritative, incomplete selected packages are rejected, and legacy snapshot-only/standalone fallbacks remain supported. Two regressions fail before the fix, including an integrated package-codec mutation that previously escaped detection; all 30 focused tool tests pass afterward. The [checkpoint](../Build/vlang-scroll-packaged-inputs-20261102-1837/checkpoint.json) retains commands, source hashes and actual exits. These final live trials use the default packaged assets without overrides. This is one retained tooling fix since the preceding vlang report; the removed runtime experiment supplies no optimization or broad-check credit.

## Live image uploads and Quartz cost

The [Quartz diagnostic](../Build/vlang-quartz-profile-20261102-1910/checkpoint.json) follows the V/native profile with validated main-thread wrappers for `CGContextDrawImage`, `CGImageCreate` and `CGContextFlush`. A padded-row, fractional-placement, translucent fixture preserves its original checksum, and an injected/uninjected frozen-page pair is pixel-exact. Inside the entire actual 11,215.70 ms input window, 10,108 fully enclosed image draws total 1,518.61 ms of inclusive wall time; 6,637 image constructions total 8.34 ms and 9,693 flushes total 0.51 ms. Boundary calls remain excluded. Even 228 tiny 32×28 image draws account for 81.90 ms. Splitting each outline into several extra Quartz publications is therefore not implemented. This is separate instrumentation on executable `aa65987e`, not unprofiled FPS or exclusive CPU credit. [Raw records](../Build/vlang-quartz-profile-20261102-1910/raw-evidence.json.gz) and the [inventory](../Build/vlang-quartz-profile-20261102-1910/artifact-inventory.json) retain identities, calls, timestamps and exits.

Experiment `0591e9687` losslessly compresses large upload-source snapshots while preserving the existing entry and total cache budgets, full source-byte comparison and original CPU mip generation. The [native checkpoint](../Build/vlang-large-upload-20261102-1918/checkpoint.json) retains sanitizer checks and 160 exact GPU comparisons, including mip boundaries and source mutation. The first GPU fixture used an unsupported odd RGBA upload pitch; its failure is retained before correction to an aligned pitch. The mascot's 3993×2317 decoded pixels compress sufficiently to fit, but that alone does not establish live use.

The [live checkpoint](../Build/vlang-large-upload-live-20261102-1930/checkpoint.json) selects production executable `2f4bb4d9c8b30b19f3519d73f3dd0973251fd0ca0d2358bde9e6da6bad8de4c4`, verified head `3b98213a8`, containing the exact experiment. Four frozen pairs and eight SVG mutation references are pixel-exact. A separate native-clock diagnostic records **811 upload preparations during input, with zero mascot requests**. The 1426×1080 opaque poster supplies 636 preparations, all already texture-cache hits. The compressed-source path is unused during input, so no candidate FPS cohort is attributed to it. Commit `5721e548c` removes the experiment and dedicated tests; the restored upload-cache header matches its feature parent and the raster-cache sanitizer check passes. The upload-source diagnostic remains available. The first unavailable-build attempt remains retained; no extra full build was queued.

| Default live observation | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| 1 | 10.718 | 54.41 | 600 / 122 | 91.44 / 106.46 / 110.32 | 100% | 220.63 / 22.94 |
| 2 | 10.308 | 54.64 | 600 / 117 | 92.04 / 117.06 / 124.97 | 100% | 229.76 / 118.76 |

Both browsers, drivers and the aggregate memory guard exit zero. Complete-document, font, icon-size, script-mutated icon and unchanged author-CSS audits pass; executable, native libraries, worker and packaged runtime assets remain pinned. One-minute load ranges from 4.60 to 5.52 on 18 logical CPUs with shared compilation overlapping this workflow. These whole-build observations do not isolate any change. Direct HTTPS, automatic author scripts, private empty profiles/caches, retained OS caches, matching-title readiness plus 20 seconds of settling, a 1024×768 document viewport at scale 2 with 112px chrome, and 600 precise delta-2 native wheel events at requested 60 Hz/reversal every 60 remain unchanged. Throughput uses the entire actual first-to-last input period. [Raw records](../Build/vlang-large-upload-live-20261102-1930/raw-evidence.json.gz) and the [inventory](../Build/vlang-large-upload-live-20261102-1930/artifact-inventory.json) retain every attempt and actual exit. No instruction saving or broad-check cadence reset is claimed.

## Opaque RGBA raster-cache experiment

Commit `75f60a6fb` allows an owned, fully opaque RGBA source to prove that its covered interior is independent of hidden backdrop pixels. It remains opt-in with `VOX_ENABLE_OPAQUE_RGBA_IMAGE_CACHE=1`; the disable override wins. Complete source bytes and parameters must still match. The existing bounded positive axis-aligned transform proof, original target geometry, rounded clips and two-device-pixel fringe remain mandatory. Region views and contained subviews offset the ignore rectangle into the cached snapshot's coordinates; all visible backdrop pixels remain compared exactly. The diagnostic separately checks whether the full backdrop changed, so ordinary cache hits cannot masquerade as new useful hits.

The [focused checkpoint](../Build/vlang-opaque-rgba-20261102-1945/checkpoint.json) retains the original failing regression, source hashes, sanitizer checks for the cache and snapshot codec, legacy cache checks with the flag both off and on, four fresh-process policy configurations and **480 exact GPU scenes with 96 verified changed-backdrop hits**. The scenes cover both full and region APIs, contained views, scale 1/2, sample modes, source/alpha mutation, fringe changes, partial opacity and padded rows. [Raw records](../Build/vlang-opaque-rgba-20261102-1945/raw-evidence.json.gz) and the [inventory](../Build/vlang-opaque-rgba-20261102-1945/artifact-inventory.json) retain commands and actual exits. The [first production attempt](../Build/vlang-opaque-rgba-live-20261102-1955/attempt1-unavailable/readiness.json) rejects the older completed bundle before launch. One later shared build is superseded by another session's rendering changes. No duplicate production build is queued manually.

The completed [live checkpoint](../Build/vlang-opaque-rgba-live-20261102-1955/checkpoint.json) pins executable `d57a8b050aebc453ca930928e83f361b29e7ddf4a766963e7115a222bdbfec34`, verified head `937c6a044`, with exact implementation hashes. Four frozen-page pairs and all eight SVG mutation guards are pixel-exact. The separate native-clock diagnostic records **1,001 image-cache decisions, 167 hits and zero hits benefiting from ignored backdrop changes during input**. It also records zero beneficial hits outside the active epoch or in the tail. Two external stack-sampler setup attempts fail to locate the driver and collect no sample; they supply no attribution. Because the proposed fast path is unused, no candidate timing cohort is credited. The workflow instead collects two unprofiled default observations:

| Default live observation | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| 1 | 11.174 | 53.12 | 600 / 131 | 87.09 / 99.04 / 111.46 | 100% | 204.39 / 73.34 |
| 2 | 11.066 | 54.33 | 600 / 127 | 89.18 / 101.99 / 110.46 | 100% | 206.57 / 40.13 |

The exact input cadence and boundary gaps are retained in the checkpoint. All browser, driver and aggregate guard exits are zero; content, fonts, icon sizes, author CSS and runtime identities pass unchanged. One-minute host load spans 2.97–3.53 on 18 logical CPUs. The source-removal commit starts a shared production compile after this cohort has finished. Workload, native publication endpoint and full actual-input denominator match the preceding table. These whole-build observations isolate no optimization. Commit `8bbc4a095` restores all three implementation files exactly to the feature parent and removes both dedicated tests. The restored cache and snapshot codec pass ASan/UBSan, and the backend compiles. The removed experiment receives no FPS, instruction or broad-check credit. [Raw records](../Build/vlang-opaque-rgba-live-20261102-1955/raw-evidence.json.gz) and the [inventory](../Build/vlang-opaque-rgba-live-20261102-1955/artifact-inventory.json) retain the complete workflow.

## Independent image-tile submission experiment

Commit `20bd38904` batches independent raster tiles of a single RGBA image leaf. Each tile retains its original target dimensions, matrix, MSAA mode, backdrop and output rectangle. Readbacks are queued before one GPU wait; owned temporary views publish only after every result succeeds. Unsupported sizes, YUV and overlapping destination/source spans retain serial fallback. Texture ownership is released while the existing renderer mutex is held. The caller is opt-in with `VOX_ENABLE_IMAGE_TILE_BATCH=1`; `VOX_DISABLE_IMAGE_TILE_BATCH` wins.

The [focused checkpoint](../Build/vlang-image-tile-batch-20261102-2025/checkpoint.json), [raw records](../Build/vlang-image-tile-batch-20261102-2025/raw-evidence.json.gz) and [inventory](../Build/vlang-image-tile-batch-20261102-2025/artifact-inventory.json) retain 800 exact GPU tile comparisons with the backend and driver under ASan/UBSan, eight preflight rejections and eight late upload failures. Every late failure occurs with one readback already queued, leaves all caller output unchanged and is followed by successful replay. The native image painter passes 2,592 exact comparisons with 1,296 verified batch uses; the disable override passes the same 2,592 scenes with zero batch uses. Dynamic-loader records verify the actual test backend. Cases cover fractional scrolling, both scales, root and independent layers, clips, opacity, borders, sampling, source changes and padded rows.

Automatic production builds read the intermediate helper before it is moved below the raster-grid globals and fail compilation; this precedes the committed implementation and focused checks. Later shared builds compile successfully but are superseded by concurrent rendering edits. Their receipts remain retained. An initial bounded availability wait expires without launching a browser. The next attempt uses completed executable `5792ada53843e1d998b4d1392a615147cfe72f22afd523284f25a1c648e6ded9`, verified head `90357421a`, with matching implementation hashes. All four frozen-page pairs and eight SVG mutation guards are pixel-exact. During actual input the separate native-clock diagnostic records **115 completed batches, 638 jobs, 116 hits, 522 readbacks and 96 submissions**. Startup and tail remain separate. Its additional native stack sample is wholly inside input and is absent from unprofiled trials.

| Alternating live trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Control 1 | 11.128 | 53.75 | 600 / 128 | 88.21 / 103.29 / 110.57 | 100% | 222.19 / 18.07 |
| Candidate 1 | 10.911 | 53.14 | 600 / 128 | 90.30 / 105.12 / 166.35 | 100% | 194.80 / 44.46 |
| Control 2 | 10.369 | 52.63 | 600 / 123 | 95.99 / 107.46 / 115.50 | 100% | 217.66 / 66.22 |
| Candidate 2 | 10.561 | 54.07 | 600 / 121 | 93.60 / 104.22 / 109.03 | 100% | 224.37 / 23.08 |

The first pair regresses and the second improves; no useful gain is accepted. Every measured interval misses the 60 Hz budget. The [live checkpoint](../Build/vlang-image-tile-live-20261102-2032/checkpoint.json), [raw records](../Build/vlang-image-tile-live-20261102-2032/raw-evidence.json.gz) and [inventory](../Build/vlang-image-tile-live-20261102-2032/artifact-inventory.json) retain all attempts, identities, actual input/publication timestamps, audits and exits. All browsers, drivers and the aggregate memory guard exit zero. Complete-document, font, icon, author-CSS and runtime-input checks pass unchanged. One-minute host load ranges from 4.05 to 5.96 on 18 logical CPUs; no shared production compilation overlaps this cohort. The same direct-HTTPS/private-profile, script, viewport, scale, readiness, settle, 600-event input and full-window throughput protocol applies. No retired-instruction saving or broad-check cadence reset is claimed.

A separate [baseline stack diagnostic](../Build/vlang-baseline-stack-20261102-2040/checkpoint.json) on `d57a8b05` confirms 813 GPU-submission samples, 449 Quartz image-draw samples and 212 snapshot-codec samples among 2,738 main-thread samples. The raw call tree also contains 504 exclusive `memmove` and 235 exclusive `bzero` samples. These are sampled stack occupancies, including waits, with potentially overlapping inclusive groups; they are not milliseconds, exclusive CPU shares or FPS credit. PID, executable/native-library identities, observer-clock containment, content audits and browser/driver/guard exits are verified. [Raw records](../Build/vlang-baseline-stack-20261102-2040/raw-evidence.json.gz) and the [inventory](../Build/vlang-baseline-stack-20261102-2040/artifact-inventory.json) retain the complete profile.

Commit `e0ef04e1f` removes the batch's redundant staging copy and output clearing. Cache hits can write to a separate output while comparisons and pending snapshots still read the immutable original backdrop. GPU uploads use those same original rows, and each output is completely supplied by a hit or completed readback before publication. The [staging checkpoint](../Build/vlang-image-batch-staging-20261102-2052/checkpoint.json) retains sanitizer checks for exact and contained separate outputs, padding, input immutability, source/backdrop mutation and legacy cache behavior, plus another 800 exact GPU comparisons in both normal and sanitizer builds and eight verified late failures with one readback queued. The unchanged native caller's preceding 2,592-case checks used the earlier backend and are not counted as runs of this revision.

The revised [live checkpoint](../Build/vlang-image-staging-live-20261102-2055/checkpoint.json), [raw records](../Build/vlang-image-staging-live-20261102-2055/raw-evidence.json.gz) and [inventory](../Build/vlang-image-staging-live-20261102-2055/artifact-inventory.json) pin executable `1c9c91f584d6bff71b8f92cc5b236f22e92cbbe0f795d9e8674307d3a96aa8a6`, verified head `5cdb4578f`. Four frozen-page pairs and eight SVG guards remain exact. The separate input diagnostic confirms **115 batches, 642 jobs, 140 hits, 502 readbacks and 91 submissions**. Startup and tail are excluded, and the native sample is confined to this separate diagnostic.

| Revised alternating live trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Control 1 | 11.190 | 54.49 | 600 / 130 | 87.47 / 98.98 / 157.88 | 100% | 187.83 / 75.49 |
| Candidate 1 | 11.292 | 53.68 | 600 / 130 | 87.69 / 99.48 / 112.53 | 100% | 202.66 / 0.17 |
| Control 2 | 11.311 | 52.52 | 600 / 133 | 87.27 / 97.96 / 104.90 | 100% | 213.68 / 0.14 |
| Candidate 2 | 11.284 | 54.95 | 600 / 128 | 87.16 / 99.06 / 178.79 | 100% | 218.37 / 25.94 |

The revised first pair improves slightly and the second regresses slightly. The candidate's 178.79 ms stall is retained. These results do not establish a repeatable useful gain. All browser, driver and aggregate guard exits are zero; the same content and runtime gates pass. One-minute host load spans 2.63–3.24 on 18 logical CPUs. The input and rendering protocol, references and tolerances are unchanged. Commit `47cccf383` removes both revisions, their native API, caller flag, cache-output extension and dedicated tests. The restored cache passes ASan/UBSan and the Metal backend compiles. No FPS or instruction gain or broad-check cadence reset is accepted.

The cleanup also exposed a shared-file mistake: `20bd38904` had included four unrelated isolated-recording fields/assignments, so reversing the entire commit removed them. The initial removal build fails when the shared primitive recorder needs those fields. Commit `b52d67b7c` restores them with a clarifying comment. Both matched live cohorts above contained the fields; the final production bundle below includes the restoration. No history is rewritten.

## Restored production after image batching

The [final checkpoint](../Build/vlang-restored-20261102-2122/checkpoint.json), [raw records](../Build/vlang-restored-20261102-2122/raw-evidence.json.gz) and [inventory](../Build/vlang-restored-20261102-2122/artifact-inventory.json) select completed executable `208875f192d26570965f87aa88c6f5b31a57f3204793380697a15bf608bd3a96`, verified head `b52d67b7c`. Strict signing and a fresh headless startup pass. The batch flag and backend diagnostic marker are absent. Four frozen-page captures match the preceding pinned default references exactly at scales 1/2 and Y=0/240, with fixture bytes pinned before and after. The earlier eight SVG mutation guards are retained with their measured builds; they are not relabelled as runs of this final bundle.

| Restored default live observation | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| 1 | 9.362 | 53.41 | 600 / 110 | 104.34 / 120.29 / 125.11 | 100% | 249.74 / 96.88 |
| 2 | 8.685 | 52.55 | 600 / 102 | 111.99 / 142.17 / 149.14 | 100% | 251.14 / 0.17 |

Both browsers, drivers and the aggregate guard exit zero. Document identity, complete content, fonts, icon dimensions, script-mutated download icon, author CSS, worker and packaged-runtime identities pass. The native precise-wheel protocol and full first-to-last-input denominator remain unchanged. One-minute load spans 5.80–6.40 on 18 logical CPUs, higher than the preceding cohort. This whole build includes other committed rendering changes; these observations isolate no optimization or regression. Four isolated-primitive component cases also execute successfully afterward from the canonical checkout. Because that checkout has concurrent edits, this is a working-tree component check, not a rebuild of the pinned bundle.

Inspection of the earlier full-metadata work does not establish a safe way to enable the expensive shared layer: its exact full-metadata images still leave the live gradient layer ineligible, while later atomic and contiguous-span variants change pixels. The retained source and logs remain in `Build/vlang-metadata-20261102-0912/`. No such path is enabled here. Smooth live 60 FPS, the CSS/SVG lifetime fault and the earlier viewport-interest assertion remain open. No instruction reduction or broad-suite reset is claimed.


## Rounded-region rejection and pending raster staging

The [checkpoint](benchmark-results/vlang-scroll-20261102-shape-and-staging.json) and [raw records](benchmark-results/vlang-scroll-20261102-shape-and-staging-raw.json.gz) retain all four live measurements, the separate eligibility diagnostic, source witnesses, content and runtime identities, and the subsequent build availability receipts. Executable `c8993aa08e74513dacc5fda3f384b9cd6eb2835eddc8f98cf315b4c39bd9c324` supplies both control and candidate. The opt-in large rounded-region experiment is slower in both pairs and was removed in `707e2b6a4`.

| Large rounded-region trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| shape-control-1 | 10.571 | 54.59 | 600 / 120 | 92.88 / 107.47 / 117.58 | 100% | 267.90 / 23.85 |
| shape-candidate-1 | 10.325 | 54.73 | 600 / 118 | 94.05 / 113.53 / 124.43 | 100% | 222.27 / 80.45 |
| shape-control-2 | 9.717 | 53.40 | 600 / 113 | 100.48 / 117.45 / 126.10 | 100% | 264.93 / 0.40 |
| shape-candidate-2 | 8.139 | 52.99 | 600 / 96 | 117.11 / 152.47 / 159.47 | 100% | 267.31 / 123.22 |

These measurements keep the preceding live workload: fresh processes and private empty profiles/caches, direct HTTPS, automatic author scripts, matching-title readiness followed by 20 seconds of settling, a 1024×768 document viewport at backing scale 2, and 600 precise native delta-2 inputs requested at 60 Hz, reversing every 60 inputs. Throughput covers the complete actual first-to-last input period and counts scroll-changing Cocoa publications after updateLayer, rather than physical scanout. All four browser processes, drivers and the memory guard exit zero; the complete identity/content audits pass. The diagnostic confirms 1,373 candidate calls and 205 cache hits during input. Its reduced requested CPU view area does not establish an improvement over the prior packed-corner path. No optimization credit is accepted.

The next experiment (`b07a30c89`, extended in `7ba24c2ce`) constructs raster-tile inputs directly and publishes only after every callback succeeds, avoiding a complete result-surface copy. It retains the original GPU target, draw order, tile borders and pixel ownership. Compact buffers stay within the former result-plus-one-tile budget; large full-tile staging permits one extra result surface, capped at 32 MiB of staged pixels. It remains opt-in via `VOX_ENABLE_STAGED_RASTER_GRID=1`, with a disable override.

**The user requested no tests until the FPS goal is reached.** No additional correctness/regression tests were executed after that instruction. The authored staging tests have not been compiled or run. Earlier rounded-region native checks predate this instruction and remain in their separate receipt; they do not validate staging. Repeated successful production compilations were superseded by concurrent input edits, leaving the installed bundle without staging. The metadata-only availability waits were retained; no staging browser diagnostic or timing trial launched. Its live eligibility, FPS, pixels and lifetime validation remain pending. Smooth live 60 FPS remains open.


## Static pages and unpublished native candidates

The [checkpoint](benchmark-results/vlang-scroll-20261102-native-cache-and-pictures.json) and [raw records](benchmark-results/vlang-scroll-20261102-native-cache-and-pictures-raw.json.gz) preserve the complete staging cohort, native geometry diagnostic, native-cache experiments, the rejected private-loader attempt, explicit-candidate measurements and failed complete-picture diagnostic. Executables, libraries, runtime assets, tools, actual input/frame records, content audits, host conditions and actual exits remain pinned in the records.

Live Wikipedia, HN and Vlang select the same Chromium font/rendering policy in `main_font_rendering.v`; explicit layout-test-font mode is the exception. Their content exercises different reuse paths. Ordinary static text and solid backgrounds fit the viewport raster reuse policy. Vlang's measured author CSS contains layered gradients, shadows and rounded/translucent decorations. Its large decorative backgrounds are static after settling; the continuing CSS animation is the small blinking cursor. The engine currently rejects gradients/effects in the viewport raster cache, and complete compositor pictures require paint metadata for gradients and interleaved layers. Repeated separate leaf painting, transfers and CPU image preparation are the structural cost. This explains the profiling evidence; no new Wikipedia/HN cache-hit or FPS comparison is claimed here.

The staging path is used during input: 1,529 calls avoid 1,523,055,840 bytes of complete result copying. Both matched pairs do not improve, so `efe7ad7d1` removes the experiment and its unexecuted tests.

| Installed staging trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| grid-control-1 | 10.558 | 53.15 | 600 / 124 | 93.32 / 105.64 / 110.66 | 100% | 220.67 / 42.59 |
| grid-candidate-1 | 10.431 | 53.40 | 600 / 121 | 94.39 / 110.52 / 115.96 | 100% | 261.18 / 50.24 |
| grid-control-2 | 10.116 | 53.62 | 600 / 117 | 96.16 / 114.92 / 124.68 | 100% | 217.21 / 23.31 |
| grid-candidate-2 | 10.559 | 53.15 | 600 / 123 | 92.55 / 112.25 / 123.51 | 100% | 236.89 / 45.80 |

The separately validated geometry probe observes 3,552 input-window shape descriptors across 1,117 exact geometry keys. Deduplicating each multi-descriptor batch's shared wrapper interval yields 954.73 ms in shape GPU wrappers; per-key batch sums overlap and are not an exclusive CPU partition. The earlier native profile includes more CPU image preparation around those calls.

The opt-in complete native rounded-image cache (`b7714ba44`, extended to isolated layers in `3636b806a`) compares complete owned backdrop bytes and every relevant paint/raster parameter. Only successful single-image sparse publications are admitted. Packed cache ownership is capped at 64 MiB, with a 16 MiB per-entry limit and bounded admission metadata. Original caller/provider lifetimes do not supply identity.

The first private bridge uses a noncanonical basename. The canonical image gate rejects it after the browser exits zero; workflow/guard exits one. Its raw counters remain diagnostic only. Tool commit `a5b3fe997` adds explicit unpublished bridge selection without changing the default installed-bundle gate. The selected bridge must load at its exact declared and pinned path, GPU libraries remain bundle-local, and every run records its native configuration. Original failures are retained; this tooling correction supplies no engine-performance credit.

| Explicit unpublished native-cache trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| rounded-control-1 | 7.396 | 52.74 | 600 / 88 | 131.39 / 157.33 / 292.83 | 100% | 315.77 / 24.82 |
| rounded-candidate-1 | 8.783 | 53.14 | 600 / 102 | 112.00 / 131.70 / 136.92 | 100% | 250.84 / 23.64 |
| rounded-control-2 | 8.053 | 53.60 | 600 / 94 | 118.85 / 153.25 / 164.11 | 100% | 318.94 / 85.81 |
| rounded-candidate-2 | 8.390 | 53.46 | 600 / 99 | 114.68 / 139.95 / 224.25 | 100% | 293.06 / 82.35 |

These four trials share the same explicit native bridge and executable. All browser/driver/guard exits are zero, and complete content, fonts, icon sizes, script-mutated download icon, stylesheet and native/runtime identities pass. Both pairs improve, but controls vary materially; no precise isolated percentage or installed-production gain is accepted. The separate input diagnostic records 48 cache hits, including 28 in isolated layers, among 587 requests. Stationary startup hits are excluded. Correctness remains unverified under the user's test deferral, so the cache stays opt-in.

`493869e98` separately tries native complete compositor streams in actual visible paint order, preserving layer/context barriers and whole-frame replay after unsupported or failed deferred publication. Its native library compiles with stable inputs. The diagnostic browser and measurement driver exit zero, but the complete-content gate finds document readiness still `interactive`, so the workflow/guard exit one and no unprofiled cohort launches. Combined-picture publication and fallback counters belong to that partial-document diagnostic only. The mode remains opt-in and supplies no FPS, correctness or production acceptance. The initial scope text in this workflow reused the rounded-cache label; the actual command and diagnostic marker identify the complete-picture experiment.

The workload otherwise keeps fresh processes and private empty profiles/caches, direct HTTPS, automatic author scripts, matching-title readiness plus 20 seconds of settling, a 1024×768 document viewport at backing scale 2, and 600 precise native delta-2 wheel events requested at 60 Hz, reversed every 60 events. Throughput uses the full actual input period. No animation, reference or tolerance was changed. No focused correctness/regression suite was launched after the user requested deferral until the FPS target; new tests are authored but unexecuted. Independent shared production builds retain their own startup gates, which do not validate these prototype pixels. Smooth live 60 FPS remains open.


## Retained layer tiles and the root adapter

The [checkpoint](benchmark-results/vlang-scroll-20261102-retained-tiles.json) and [compressed raw records](benchmark-results/vlang-scroll-20261102-retained-tiles-raw.json.gz) retain nine diagnostic/cohort workflows, 2,095 artifacts, 765 text records, source witnesses, compiler/guard exits and two native-fault corrections. **No optimization is accepted.** All new rendering remains opt-in, pixel/ownership checks are deferred by the user's instruction, and the live 60 FPS goal is open.

`3bb8e8548` records transparent tiles in layer coordinates with owned per-operation keys and conservative ink bounds. `6a70e04f1` adds lossless row storage and edge-tile retention, and keeps document viewport clipping outside those keys. `178e1e19e` registers text/rectangle ink before the first deferred leaf and remembers declined transactions. These changes preserve ordinary frame replay after failed publication; their correctness is not yet established by executed tests.

The two complete matched cohorts below both regress. The first compares native speculative pictures plus retained interior tiles with ordinary painting. The second adds compressed/edge retention and first-leaf registration. Each cohort uses one pinned unpublished native bridge and the same `0bb14e2f` executable in both variants; these are not isolated measurements of one cache subcomponent.

| Cohort / trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Missed 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| Interior control-1 | 8.661 | 52.94 | 600 / 101 | 106.20 / 170.12 / 201.47 | 100% | 229.05 / 42.19 |
| Interior candidate-1 | 6.688 | 44.51 | 600 / 95 | 140.69 / 217.89 / 256.78 | 100% | 300.45 / 137.16 |
| Interior control-2 | 8.081 | 52.61 | 600 / 95 | 118.96 / 151.41 / 190.79 | 100% | 281.16 / 98.80 |
| Interior candidate-2 | 5.842 | 43.20 | 600 / 85 | 153.52 / 253.07 / 359.53 | 100% | 283.71 / 153.28 |
| Complete control-1 | 7.498 | 52.22 | 600 / 89 | 131.14 / 155.41 / 166.92 | 100% | 291.97 / 43.45 |
| Complete candidate-1 | 7.046 | 41.79 | 600 / 104 | 140.42 / 166.36 / 228.78 | 100% | 285.42 / 32.51 |
| Complete control-2 | 10.034 | 53.67 | 600 / 116 | 97.18 / 115.31 / 125.00 | 100% | 269.48 / 0.40 |
| Complete candidate-2 | 8.321 | 42.97 | 600 / 122 | 112.45 / 162.93 / 275.42 | 100% | 254.16 / 0.13 |

Both cohorts retain fresh processes, private empty profiles/caches, direct live HTTPS, automatic author scripts, the full cached author CSS and icon/font/content audits, a 1024×768 document viewport at backing scale 2, and 600 precise native delta-2 wheel events requested at 60 Hz, reversed every 60 events. The first uses matching-title readiness plus 20 seconds of settling; the later cohort uses 30 seconds. The pre-input observation moves from 15 to 25 seconds. Different settle protocols do not supply cross-cohort optimization credit. Throughput uses the complete actual first-to-last input period; native publications do not establish physical display presentation. Host load and all interval/boundary records remain in the receipt.

Intermediate failures remain preserved. The compressed-edge workflow stops after a control with `interactive` readiness and fonts still loading. Another viewport-key diagnostic exits 139 before input in CSS tokenization during SVG style conversion. A later diagnostic of the same viewport-key native candidate is labeled diagnostic only and does not erase that failure.

`cfd594ff3` separates vertical scroll translation from raster phase and samples the stable premultiplied texture during CPU composition. Its raw input trace records 7,252 tile hits and 2,619 misses, but its diagnostic logs a detached HTTP transport-thread fault after `SCROLL_DONE` despite process exit zero. The complete workflow is invalid; its partial unprofiled results are retained without acceptance. The final candidate also fails input identity after the measurement script is edited during the run. This was a measurement-workflow mistake, not evidence that the app bundle changed. `63170249d` now rejects `SCROLL_FAULT_FIRST` anywhere in a completed log, regardless of process status. The original receipts remain intact alongside the explicit invalidity correction.

Root-specific diagnostics show why child-layer reuse remains insufficient. Vlang's logical root is approximately 12,027 CSS pixels tall, exceeding the previous 16,384-device-pixel layer limit at scale 2, while the physical bitmap is only 2048×1760. `b43e4ec3f` permits large logical roots without enlarging the bounded tile or viewport raster allocation. It also checks the destination against an owned prefix before replacing a root segment. That check detects ordinary Cocoa rectangle fills after recording, correctly declines publication, and verifies zero root publications during input. No root-path timing cohort is collected for these unused candidates.

The same commit connects an optional recorded-fill deferral result to the platform graphics adapter and defers eligible solid SVG leaves. Rectangles are recorded in document coordinates before scroll composition. An older executable still performs its ordinary Cocoa fills and cannot exercise this adapter change merely by replacing the Skia bridge. The final native bridge compiles with stable inputs and exports the new service; live validation requires a newer completed shared executable. A concurrent build linking an earlier bridge reports the new symbol missing. The adapter now resolves this optional service dynamically, keeping the old-library fallback explicit.

The full experiment requires `VOX_ENABLE_SPECULATIVE_PICTURES=1`, `VOX_ENABLE_RETAINED_LAYER_TILES=1`, `VOX_ENABLE_COMPLETE_SPECULATIVE_PICTURES=1`, `VOX_ENABLE_LAYER_TEXTURE_SCROLL=1` and `VOX_ENABLE_ROOT_SPECULATIVE_PICTURES=1`. The latest completed installed bundle is reused for applicable checks; the busy shared build is not duplicated. No focused correctness/regression suite has been launched by this workflow after the user's deferral. Independently triggered production builds keep their own startup gates. Sampling, clipping, rollback, cache ownership and distant-coordinate checks are authored but unexecuted; no reference or tolerance was changed.


## Root-picture bounds and rejected cache experiments (2026-11-03)

**The live 60 FPS goal remains open.** The [checkpoint](benchmark-results/vlang-scroll-20261103-root-pictures.json) and [compressed raw records](benchmark-results/vlang-scroll-20261103-root-pictures-raw.json.gz) retain 43 workflows/build attempts, 885 artifacts and 776 text records, including failures and every complete timing trial. No optimization is accepted. All retained rendering stays opt-in, and correctness, ownership, sanitizer and screenshot tests remain deferred under the user's instruction until the FPS goal.

The completed production bundle finally contains the root-fill adapter. The first fresh diagnostic still publishes zero roots during input. Stack tracing identifies independent CSS-gradient blur and nested decoration publications changing a pending root prefix. `f1530b128` publishes preceding draws before isolated inputs and keeps decorations in their owning picture. `fa1802de1` defers supported images and stroked SVG leaves, includes stroke ink, and closes prefixes before mask publication. The separate live diagnostic then verifies 418 input-window root publications and 19,516 tile hits with no picture failures. These are use counters, not FPS savings or pixel acceptance.

`7328589d5` charges a shared retained picture/resource owner once while keeping the 64 MiB tile budget. The key trace shows a viewport-relative solid background changing while its neighboring gradient key stays stable; `ed8f6290c` keeps that cheap fill in the ordinary prefix. `8276f6904` prevents a zero-deferred-leaf segment from blacklisting later independent root pictures, while preserving the changed-pixel veto. `d519559ab` registers full-width gradient fringes before deciding deferral. `fc96ba3dc` bounds root CPU publication to recorded ink, preserves original GPU tile dimensions/coordinates, and decodes only that backdrop region from the existing owned RGBA guard snapshot. Its diagnostic verifies 490 input-window root publications, including narrow text/icon output, without picture failures. Focused source cases are authored but unexecuted.

| Prototype/cohort | Pair 1 control→candidate FPS | Pair 2 control→candidate FPS |
| --- | ---: | ---: |
| Complete root recording | 9.893→6.673 | 9.479→6.275 |
| Shared owner/prefix revision | 6.798→5.045 | 6.159→4.688 |
| Bounded root publications + gradient fringe | 7.073→6.346 | 6.842→6.396 |
| Unused empty-child experiment | 9.168→5.275 | 5.327→4.792 |
| Image identity component | 6.112→4.630 | 5.273→5.967 |
| Typeface lookup component | 8.468→7.938 | 7.762→8.778 |

The first four cohorts compare ordinary rendering with the full experimental picture/tile path at successive native revisions. The last two isolate a component: both arms keep identical retained-picture flags, and only the image-cache or direct-typeface option changes. They do not measure ordinary production defaults. Different executables, private native candidates and host conditions prevent attributing cross-cohort changes to one feature. Every complete cohort retains zero browser/driver/guard exits and successful document, font, icon, stylesheet and input-identity gates. Host loads and overlapping builds are retained; the empty-child cohort's controls vary from 9.168 to 5.327 FPS.

The empty-child path has zero useful input hits and is removed, with its exact reconstructed implementation and unexecuted test patch retained. Image identity records 294 input-window cache hits but mixed FPS; `62b0a8c23` removes `4052f2958` and restores its implementation paths exactly. A separate natural-image operation records zero input use and is removed before timing. Direct typeface lookup records 891 input-window hits over 1,085,137,451 embedded font bytes, but its FPS is also mixed; `93c85456c` removes `17ec762ae` and its unexecuted feature-only cases exactly. Removed experiments earn no gain.

The last component cohort's full-window measurements are:

| Trial | Scroll FPS | Actual input Hz | Inputs / completed publications | Median / p95 / max scroll interval (ms) | Over 16.67 ms | Leading / trailing scroll gap (ms) |
| --- | ---: | ---: | --- | --- | ---: | --- |
| control-1 | 8.468 | 42.27 | 600 / 123 | 115.31 / 141.89 / 190.78 | 100% | 331.50 / 0.18 |
| candidate-1 | 7.938 | 41.71 | 600 / 119 | 119.46 / 162.54 / 201.19 | 100% | 221.27 / 130.63 |
| control-2 | 7.762 | 39.74 | 600 / 123 | 124.24 / 157.65 / 249.26 | 100% | 334.86 / 22.96 |
| candidate-2 | 8.778 | 44.94 | 600 / 123 | 108.78 / 142.16 / 213.33 | 100% | 230.53 / 23.28 |

Every measured scroll interval in all six cohorts misses the 60 Hz budget. The complete interval distributions, input/publication counts, leading/trailing gaps, host load/timestamps, executable/native/runtime identities and exits for all trials are in the checkpoint and raw records. Throughput uses the entire actual first-to-last input period; native layer publication does not establish physical display scanout.

All runs keep direct live HTTPS, automatic author scripts, private empty profiles/caches, retained OS caches, matching-title readiness plus 30 seconds settling, a 1024×768 document viewport with 112px chrome at backing scale 2, and 600 precise native delta-2 wheel inputs requested at 60 Hz and reversed every 60 events. No author animation, pixel reference or tolerance changes. Invalidation failures remain: one observer-script rewrite changes file identity despite identical bytes, and shared bundle publication changes another attempt's pinned executable/libraries. Those workflows supply no performance acceptance.

A separate native stack diagnostic samples the actual input epoch from approximately 0.073 to 5.933 seconds, with browser, driver, sampler and guard exits zero. Of 2,662 main-thread samples, the per-category unions contain 1,378 in shared-picture finish, 959 in retained-tile draw, 347 in snapshot encoding, 238 in typeface decode and 356 in GPU submission. Categories overlap and must not be summed. Raw occurrence totals (including 656 snapshot-encoding occurrences and 255 snapshot-replay occurrences) are preserved separately; nested occurrences are removed in `sample-analysis-union.json`. No sample count establishes measured time or retired-instruction savings.

Tool commit `c3110eb69` allows an explicitly selected picture backend while requiring its exact loaded path, bytes and file identity; other graphics backends remain bundle-local. The successful fresh font diagnostic verifies this selection. Its earlier attempt is invalidated by a shared bundle replacement and retained. This tooling provides no engine credit. No focused correctness/regression tests were run by this continuation; independent shared production startup gates do not establish opt-in pixel correctness. No instruction credit or broad-check cadence reset is claimed.


## Metal device handoff regression recovery (2026-11-03)

**The live 60 FPS goal remains open, but a same-day regression that collapsed
vlang.io scrolling to ~1 FPS is fixed.** A CPU sample of live scrolling on the
installed bundle showed the main thread spending the frame inside
`native_draw_outer_box_shadow_corners_srgb` →
`vox_graphite_draw_shadow_pixels` → `context()` →
`vox_graphite_picture_retire_graphics_context` →
`DawnSharedContext::~DawnSharedContext()` →
`dawn::native::metal::Device::~Device()` →
`AsyncWorkerThreadPool::~AsyncWorkerThreadPool()` → `std::thread::join()` →
`__ulock_wait`. The shadow raster backend (`libVoxGraphite`) and the
picture/gradient backend (`libVoxGraphiteDawn`) each unconditionally retired the
other's Graphite context the first time they allocated their own, from
`3c5d0fe1b` ("Retire inactive raster backends before allocating their peer
context"). vlang.io interleaves outer box shadows with CSS gradients and
speculative pictures, so every switch between the two backends within one frame
destroyed and recreated a Metal device; the Dawn device destructor joins its
async worker-thread pool, blocking the main thread for hundreds of milliseconds
per handoff. Dawn picture drawing itself was a negligible fraction of the
samples, so the whole cost was device create/teardown, not useful rendering.

`ad002ac57` retires the peer backend only once it has been idle (the existing
two-second idle-release path, `vox_graphite_*release_idle_graphics_memory`)
instead of on every switch. During interleaved rendering both contexts stay
resident, so the handoff stops firing after the first frame; a genuinely unused
backend is still reclaimed when idle. Pixel output is unchanged.
`VOX_DISABLE_GRAPHICS_CONTEXT_HANDOFF` still bypasses the handoff entirely and
reproduces the same recovered throughput.

The matched before/after measurements use the same workload: live direct
`https://vlang.io/`, automatic author scripts, a fresh empty private
profile/cache per launch, matching-title readiness plus 30 s settle, a
1024×768 document viewport with 112 px chrome at backing scale 2, and 600
precise delta-2 native wheel events requested at 60 Hz, reversed every 60
events. Throughput spans the entire actual first-to-last input window. The
fixed binary is pinned at SHA256
`e312662c8ba206b831597d128a3e21b39519e642f20f86f3d52b7d6662815f4e`. Raw
receipts, summaries, the CPU samples, and guard exits are retained in
`Build/vlang-fps-20261103/`.

| Trial | Backend handoff | Scroll FPS | Input Hz | Pubs / inputs | Median / p95 / max interval (ms) | Over 16.67 ms |
| --- | --- | ---: | ---: | --- | --- | ---: |
| control-1 | unconditional (prior bundle) | 1.062 | 15.9 | 42 / 600 | 857.4 / 1030.1 / — | 100% |
| control-2 | unconditional (prior bundle) | 1.141 | 15.9 | 44 / 600 | 873.5 / 1030.0 / — | 100% |
| default-1 | idle-gated (`ad002ac57`) | 8.890 | 52.7 | 102 / 600 | 109.4 / 127.7 / 131.7 | 100% |
| default-2 | idle-gated (`ad002ac57`) | 7.912 | 51.5 | 93 / 600 | 122.2 / 146.1 / 157.9 | 100% |
| default-3 | idle-gated (`ad002ac57`) | 8.114 | 50.6 | 99 / 600 | 117.4 / 146.0 / 221.2 | 100% |

One-minute host load was ~3.5 on 18 logical CPUs for the fixed trials. Two
`VOX_DISABLE_GRAPHICS_CONTEXT_HANDOFF=1` control trials on the fixed binary
measured 8.849 and 9.386 FPS, confirming the idle-gated default matches a fully
disabled handoff during active scrolling. Median scroll publication rises from
~1.06-1.18 to ~7.9-8.9 FPS and the median frame interval falls from ~850 ms to
~110 ms; input delivery recovers from ~16 Hz to ~51 Hz. These are Cocoa layer
publications, not physical display scanout.

Every measured interval still exceeds the 16.67 ms budget. A fresh CPU sample of
the fixed binary shows the remaining per-frame cost is the paint itself: each
outer box shadow draws on the GPU and then reads the result back synchronously
(`vox_shared_readback` → `Context::submit` → `-[MTLCommandBuffer
waitUntilCompleted]` → `__psynch_cvwait`), interleaved with clipped CSS gradient
tiles and SVG paths. vlang.io's shadows, gradients and blur disqualify it from
the viewport scroll-raster shift-and-strip reuse, and the shadow raster cache is
keyed on the scroll-translated device matrix, so it misses on every scrolled
frame. Removing those synchronous GPU round-trips (shadow/gradient raster reuse
across scrolled frames, or asynchronous readback) is the remaining work toward
60 FPS and matches the open paint-architecture items recorded above.

A separate chrome regression was also removed. The bookmark bar favicons were
resolved every frame through the ordinary document image path, whose redirect
revalidation (`filter_preloaded_resource`) re-issued a synchronous network fetch
from the frame callback for any bookmark whose `/favicon.ico` redirects. In
restricted mode the bar lists 18 optimized sites and only four have bundled
icons, so the other remote favicons could each stall a frame on a TLS handshake.
Bookmark favicons now resolve through a dedicated non-blocking path: a remote
icon is requested once in the background, decoded from the retained response
when it arrives, and remembered as absent after an error, so later frames are a
map lookup. This mainly helps real profiles whose bookmark bar contains
redirecting favicons; the empty-profile acceptance workload above does not
isolate it.


## Content-damage reuse and content-anchored gradient blur (2026-11-04)

**The live 60 FPS goal remains open.** Viewport pixel reuse now engages on
vlang.io during scrolling, but it does not yet raise throughput: the remaining
frame cost is per-leaf GPU round trips for the large leaves that touch the
exposed strip or in-page damage. Raw logs, summaries, guard reports and the CPU
sample are in `Build/vlang-fps-20261103/` (`rE-*`, `rF-*`, `mini/*-H2-*`).

`16692c6f4` commits the content-damage reuse that previously shipped only in
dirty shared builds. Each frame records a scroll-normalized key per paint
command; the retained and current frames are diffed, and only the exposed strip
plus the old and new ink of changed commands is repainted. Its focused checks
pass: `main_scroll_raster_test.v` (after correcting five stale calls to the
five-argument key function), `layout/scroll_raster_eligibility_storage_test.v`
and the native `tools/test_scroll_raster_darwin.m`.

With that code alone (bundle `ee58ec95…`), a diagnostic run found every input
frame eligible but none reused: 55 frames fell back with `damage-too-large` and
8 with `too-many-changes`. The cause was `.showcase::before`, a faint radial
glow with `filter: blur(30px)`. Its layer was forced to mismatch every frame, so
its ~1024×611 ink was always damage. A new native test
(`tools/test_native_css_blur_translation.sh`) shows why that was needed: Skia
clips a filter layer to the canvas, and its downsampled blur follows the clipped
layer origin. Once the gradient overhangs the canvas by more than 3σ, the same
content rendered 1–2 levels differently at different whole-device-pixel offsets
(12 of 32 scenes).

`7f20f2ba3` rasterizes single-gradient blurs anchored to their content instead.
The filter output is drawn once over its complete ink on a transparent surface,
cached by a scroll-independent key from the paint commands, and blended over
opaque backdrops on the CPU inside the current clip. Translucent backdrops keep
the legacy GPU composite; `VOX_DISABLE_ANCHORED_GRADIENT_BLUR` restores it
everywhere. Top-level single-gradient blurs keep their identity in the damage
keys. Compared with the legacy composite, the 8-bit layer blend moves some
pixels by one level; no screenshot reference uses this path. Checks:

- The new native test: 28 scenes exact for translation, cached reuse and
  strip-clipped replay.
- The existing region test: 160 scenes exact.
- The existing backdrop test (legacy path pinned): 48 comparisons exact.
- `main_chromium_gradient_blur_test.v` and the new key test in
  `main_scroll_raster_test.v`.

On bundle `b6e4b222…` (receipt `20261104-014100-e011d913`), the diagnostic run
reused 70 of 93 input frames; 16 fell back with `too-many-changes`. It logged 87
anchored-blur draws during input. Its `cached` field also counted fresh rasters
newly inserted into the cache (corrected in `ecd5bc30d`), so that run does not
establish the cache hit rate. The matched cohort below keeps
the same protocol as before: live direct HTTPS, automatic scripts, empty
private profile/cache, title readiness plus 30 s settle, 1024×768 viewport with
112 px chrome at scale 2, and 600 precise delta-2 inputs at 60 Hz reversed every
60. One-minute host load was ~12 for the first four trials and rose to ~44
during control-3.

| Trial | Reuse | Scroll FPS | Input Hz | Inputs / pubs | Median / p95 / max interval (ms) | Over 16.67 ms | Lead / trail gap (ms) |
| --- | --- | ---: | ---: | --- | --- | ---: | --- |
| control-1 | off | 7.010 | 46.66 | 600 / 91 | 142.3 / 237.2 / 354.8 | 99% | 162.6 / 141.5 |
| candidate-1 | on | 6.869 | 45.72 | 600 / 91 | 138.7 / 246.1 / 304.9 | 100% | 117.3 / 157.7 |
| control-2 | off | 7.072 | 46.05 | 600 / 93 | 143.9 / 228.8 / 281.7 | 97% | 125.3 / 69.3 |
| candidate-2 | on | 6.421 | 45.79 | 600 / 85 | 153.1 / 238.3 / 276.5 | 100% | 158.1 / 169.2 |
| control-3 | off | 7.072 | 46.05 | 600 / 93 | 143.8 / 233.3 / 303.4 | 100% | 113.7 / 0.2 |
| candidate-3 | on | 7.801 | 46.73 | 600 / 101 | 135.9 / 214.0 / 265.2 | 97% | 141.1 / 0.2 |

Reuse earns no FPS credit: the arms overlap and nearly every interval misses
the 60 Hz budget. A reused frame replays only 37–66 of ~450 commands, yet costs
about as much as a full repaint. The input-window CPU sample (`rF-sample3.txt`)
explains this. The main thread is almost entirely in leaf replay: rounded rects,
CSS gradient tiles, outer box shadows, images, glyph runs and SVG paths. Each
leaf does its own Graphite submit, `waitUntilCompleted` and readback. Eight
commands change on every frame: the playing demo video, nested display lists, a
growing bar and animated text. Every large leaf that touches them or the strip
is still rasterized at its full original size, because the strip path
deliberately keeps leaf raster origins and dimensions. Damage-key hashing is
negligible (2 of 391 main-thread samples).

The fixture gate exposed an unrelated full-render bug. On a page of cards with
both an outer and an inset `box-shadow`, scrolling by N px removed the bottom
N px of every card background in ordinary full repaints. Reused frames looked
correct only because they kept pixels painted at earlier offsets.
`draw_chromium_inset_decorations` subtracted the root scroll a second time from
commands whose transforms already include it, shifting the deferred decoration
region up. `VOX_DISABLE_DEFERRED_DECORATIONS=1` avoided it. `7ec7e1ec6` computes
the region from the transform alone, like ordinary replay, and adds a focused
bounds test (`main_chromium_inset_decorations_test.v` passes). Its end-to-end
fixture check passes on bundle `9ebd66e2…` (built from `7ec7e1ec6`). Full
repaints at offsets 0, 100 and 240 now keep the card background (22,36,59)
inside every card. The stepped reuse-versus-full-repaint gate is exact for the
gradient, shadow and blur fixtures; the shadow fixture previously differed in
54% of pixels. A new fixture modeled on vlang.io's showcase glow
(`mini/f4-showcase.html`) is also exact between reuse and full repaint, and
takes the anchored path. Compared with the legacy blur composite, it differs by
at most one level in 5.2% of pixels.

The build containing `ecd5bc30d` failed with `ENOSPC` (receipt
`20261104-055347-22ab044c`). The shared data volume fell from 2.7 GiB free to
275 MiB during this checkpoint, so the cache hit rate is still unmeasured.

Next steps toward 60 FPS, in order of expected effect:

1. Keep GPU work for strip and damage repaints in one submission per frame,
   reading back only the clipped rows, instead of one synchronous round trip
   per leaf.
2. Give continuously changing content (video, animated nested display lists)
   its own retained layer, so its damage stops re-rasterizing the leaves
   beneath it.
3. Raise `scroll_raster_max_changed_commands` only after (1) and (2); the 16
   `too-many-changes` frames are full repaints today.

## Layer crops, video backdrop and tighter damage (2026-11-04)

Leaf timing of bundle `698536dc…` (diagnostic run `rH-diag`) split reused
frames into two populations: about 100 ms when the demo video had a new
frame and about 40 ms otherwise. Two facts explained most of it.

- The demo stage (commands ~357–441: its shadows, the two 958×438 radial
  gradients, the rotated orbit decoration and the video) is Chromium raster
  layer 10, not the root (`VOX_DIAGNOSTIC_PAINT_LAYER=1` prints each
  command's owner). Every crop added so far required the root layer, so
  these leaves were rasterized, read back and composited at full size for a
  2-pixel strip.
- Each new video frame damaged the video's rectangle. Every leaf beneath
  it (both gradients at ~20 ms each, the stage and orbit shadows, the orbit
  border) was rasterized again, although the video is the topmost content
  there. Chromium keeps the video in its own layer and composites new frames
  over raster it never invalidates.

Changes, each with focused tests:

- `3a182e1e2` crops strip and damage repaints in composited layers. Gradients
  keep their complete GPU target and the layer's ordered-dither phase; outer
  shadows use a new Graphite region draw that renders the complete
  transparent shadow target and transfers only the visible rows. The
  published damage rectangles now refine crops only on the canvas they were
  published for, so a full-canvas offscreen filter layer is never cropped
  by them. Native tests: 24 gradient and 22 shadow strips (root and layer)
  equal complete replays exactly.
- `4ce42bc35` composites new video frames over the pixels retained beneath
  them. Just before a top-level video draws, the native ring stores the
  freshly painted pixels under its damage rectangle in document device rows.
  When the only change between frames is that video's frame (same ink,
  nothing later in paint order touching it, an immediately drawing raster
  layer), the planner emits a restore rectangle instead of damage: commands
  beneath skip it, the backdrop is copied back and only the video draws. A
  row stays valid only while it has remained in the viewport since capture;
  complete repaints, other damage under the video and replays without capture
  invalidate it, and a planned restore that does not run keeps the frame out
  of the ring. `VOX_DISABLE_VIDEO_BACKDROPS=1` is the same-binary control.
- `6ab4f3083` bounds leaf damage keys by the command's conservative clip
  rectangle, as group keys already were. The orbit and its 60px shadow
  (1509×1347 ink) sit inside the scene's `overflow: hidden` box and touched
  every exposed strip.
- `e9c9df672` skips untouched fill-and-border underlay pairs. The hero's
  download button is such a pair and was never skipped; every reused frame
  replayed its text-coverage group (~4.5 ms, a deferred inset batch with
  full-surface transfers) although no damage reached it.
- `de016d415` stores only the strip and damage rows back into the ring.
  Any in-page damage previously stored all 1536 device rows (12.6 MB) each
  frame; that copy was 12% of the settled frame loop.

Diagnostic runs (leaf timing and damage diagnostics enabled, live page,
same protocol as `rH-diag`; not acceptance measurements):

| Run | Bundle | Reused replay median / p90 | Scrolled replay median / p90 | Diagnostic scroll FPS |
| --- | --- | --- | --- | --- |
| `rH-diag` | `698536dc…` | 34.5 / 112.7 ms | — | 14.2 |
| `rI-diag` | `51e68e38…` (`3a182e1e2`, `4ce42bc35`) | 18.4 / 40.5 ms | 20.5 / 41.2 ms | 32.8 |
| `rJ-diag` | `d63e1dc8…` (+ `6ab4f3083`, `e9c9df672`) | 13.4 / 23.6 ms | 14.8 / 23.7 ms | 31.2 |

`rI-diag` planned 1,146 video restores. Settled frames (video only) fell to a
2.8 ms replay median in `rJ-diag`. Its diagnostic FPS did not rise with the
replay time: a scroll-window CPU sample (`rF-sampleJ.txt`, bundle
`d63e1dc8…`) shows the main thread busy in frames 91% of the time, with the
remaining replay spread over CoreGraphics glyph rendering of strip text
(`aa_render`), per-leaf Graphite waits, and the video's CPU mipmap downscale
of each 1426×1080 frame (12% of samples).

Unprofiled cohort `rK` (2026-11-04 09:04–09:09 MSK, bundle `d63e1dc8…`, built
from the tree at `e9c9df672` without `de016d415`; live `https://vlang.io/`,
1024×768 viewport, 112-px chrome, backing scale 2, 600 precise wheel inputs
of 2 px at 60 Hz reversing every 60, 30 s settle after the title, empty
private profile and cache, OS caches retained). Control is the same binary
with `VOX_DISABLE_VIDEO_BACKDROPS`, `VOX_DISABLE_CLIPPED_LAYER_GRADIENTS` and
`VOX_DISABLE_CLIPPED_LAYER_SHADOWS`; clip-bounded keys and underlay pairs are
in both arms. All six runs are retained; every browser and guard exit was 0.
The host was heavily loaded by other work (1-minute load 26–48 on 18 cores),
so absolute rates are depressed; the arms alternate under the same load.

| Run | Scroll FPS | Median / p95 / max interval | Over 16.7 ms | Input delivery |
| --- | ---: | --- | ---: | ---: |
| control-1 | 10.8 | 105.6 / 155.4 / 729.0 ms | 80% | 46.1 Hz |
| candidate-1 | 32.7 | 28.2 / 51.2 / 265.0 ms | 67% | 51.3 Hz |
| control-2 | 10.9 | 113.5 / 147.0 / 439.1 ms | 85% | 46.0 Hz |
| candidate-2 | 30.0 | 31.7 / 56.3 / 270.5 ms | 76% | 46.4 Hz |
| control-3 | 8.7 | 118.8 / 187.6 / 1296.3 ms | 88% | 41.2 Hz |
| candidate-3 | 30.5 | 29.9 / 60.6 / 321.6 ms | 69% | 50.7 Hz |

The video backdrop and layer crops roughly triple scroll-changing publication
rate on this page (3 of 3 pairs). This is still about half of the 60 FPS goal
and two thirds of intervals miss the frame budget; the goal remains open.
Production builds of `de016d415` failed three times because concurrent work
changed repository inputs before C preprocessing (receipts
`20261104-085810-4b8aec69`, `20261104-090008-0c1af8c6`,
`20261104-090144-fd273186`), so that commit is not yet measured.

Next steps, in order of expected effect:

1. Draw video frames without the per-frame CPU mipmap downscale of the full
   1426×1080 frame (12% of the scroll-window sample), as Chromium's
   compositor samples the uploaded frame on the GPU.
2. Batch the remaining strip leaves (text, decorations, layer-10 shadows when
   the stage crosses the strip) into one GPU submission per frame instead of
   one synchronous round trip per leaf.
3. Find the 265–320 ms hitches (complete repaints from slide changes and
   `too-many-changes` frames).

`1a637a464` then sent live video frames through a GPU-only path: the complete
frame is uploaded and sampled linearly without mips, as Chromium's compositor
does, instead of the image decode-cache emulation (CPU resize to a mip level
plus a mip chain for every frame). A native test matches 8 frame leaves
exactly with independent complete-resolution GPU pictures.

Bundle `1f6b4cd9…` (receipt `20261104-091559-8c7bb7bf`) contains all six
changes. Diagnostic run `rM-diag`: reused replay median 13.3 ms (p90 23.5),
scrolled frames 14.1 ms (p90 23.5), settled frames 2.7 ms (p90 3.3, from
18.1 ms in `rJ-diag`). Its ten complete repaints (median 158.5 ms) are slide
changes (`too-many-changes`, 508–856 changed commands) and frames where
blur-filter groups, re-keyed every frame by design, exceed the damage-area
cap (`damage-too-large`).

Unprofiled cohort `rL` (09:37–09:42 MSK, same protocol and arms as `rK`) ran
under even heavier host load (1-minute load 68–113 on 18 cores):

| Run | Scroll FPS | Median / p95 / max interval | Over 16.7 ms | Input delivery |
| --- | ---: | --- | ---: | ---: |
| control-1 | 13.6 | 42.9 / 156.2 / 376.9 ms | 82% | 45.3 Hz |
| candidate-1 | 33.9 | 27.5 / 52.4 / 220.1 ms | 70% | 50.7 Hz |
| control-2 | 14.2 | 41.5 / 160.3 / 389.0 ms | 73% | 45.6 Hz |
| candidate-2 | invalid | browser exit 139 after `SCROLL_DONE` | — | — |
| control-3 | 12.1 | 46.3 / 165.6 / 415.4 ms | 80% | 44.5 Hz |
| candidate-3 | 32.6 | 28.4 / 54.7 / 249.2 ms | 69% | 50.8 Hz |

candidate-2 completed all 600 inputs (438 publications), then crashed with
SIGSEGV in `net.http.Transport.reap_idle_connections` on its detached thread;
the run is retained and excluded. The crash is outside rendering and is not
investigated here. Both valid pairs keep the roughly 2.5–3× separation; with
replay now at a 14 ms median, the 50 Hz input delivery and host contention
bound the remaining rate. The 60 FPS goal remains open.

## Decoration crops, cached blur input and script transforms (2026-11-04, later)

A scroll-window sample of bundle `f492d6c7…` attributed the remaining replay
to per-leaf Graphite waits (28%), CPU clears and copies (16%) and
CoreGraphics glyph rendering (8%). The largest owners were addressed:

- `70a969669` crops decoration groups (card shadows, rounded fills and
  borders batched through the document-anchored root grid) to the rows a
  strip or damage repaint publishes. 24 strips equal complete replays.
- `de93a3faf` skips rasterizing the showcase glow's gradient into the
  full-canvas filter layer once its blurred output is cached for the same
  content identity (~4.7 ms in 226 of 362 scrolled frames). The input
  is still recorded; a failed native blur replays it into the layer first.
- `f5fa57246` blends that cached blur only inside the published damage
  rectangles, in disjoint bands, instead of the clip's bounding box.
- `f41bebdf4` patches script `transform`/`opacity`-only style updates into
  the retained paint tree, as CSS animation samples already were. vlang.io
  sets the tab progress bar's `scaleX` every animation frame, and each such
  update rebuilt the whole document's renderer snapshot (~11% of the main
  thread). Category changes and other properties keep the full rebuild;
  every tested update paints exactly like a full refresh.

Diagnostic run `rN-diag` (bundle `cbcd8202…`, first three changes): scrolled
replay median 11.2 ms (p90 21.0), from 14.1 ms in `rM-diag`; the filter
layer's total time fell from 671 to 84 ms.

Two unprofiled alternating cohorts used the protocol of `rK`. The host was
shared with a QEMU VM (~670% CPU) and compiles, so absolute rates are low
and drift with load; only paired differences are meaningful.

| Cohort | Bundle | Control disables | Control FPS | Candidate FPS | Load |
| --- | --- | --- | --- | --- | --- |
| `rO` | `cbcd8202…` | first three changes | 18.6 / 16.5 / 18.7 | 17.8 / 21.5 / 25.1 | 19–38 |
| `rP` | `40174578…` | all four changes | 23.5 / 24.6 / 23.3 | 28.6 / 30.4 / 36.7 | 19–36 |

`rP` candidate medians were 31.6 / 28.4 / 24.3 ms (p95 63.8 / 62.2 /
48.7 ms, max 264–294 ms), and every run and guard exited 0. The earlier
`rL` reached 33 FPS on bundle `1f6b4cd9…` under a different load mix;
across bundles built from other sessions' intervening work, no comparison
is drawn. The 60 FPS goal remains open.

A scroll-window sample of `40174578…` still shows the complete renderer
snapshot rebuild from the rendering update (~12% of the main thread), so
something other than the progress bar's transform also requests it;
`58dfb55e5` adds `VOX_PAINT_REFRESH_DIAGNOSTICS` to report the trigger.

### The tab-progress rebuild, found (2026-11-04, afternoon)

`VOX_PAINT_REFRESH_DIAGNOSTICS` on the live page showed every one of the
411 full renderer rebuilds in a scroll window coming from the tab
progress bar's style update, and the printed values explained why: the
node retains its style in layout (device) coordinates, while the update
check compared that with the incoming CSS-pixel style. At device scale 2 a
`medium` border is 6px retained and 3px incoming, so every update looked
like a geometry change. Three commits address the path:

- `8798ef036` applies paint style updates to the viewport projection when
  every updated box is retained and meets the paint interest, instead of
  first restoring the complete transport.
- `079e24965` lets unchanged values in new style objects pass the
  compositor check through their CSS invalidation.
- `cb4be9fa5` compares the update in layout units before the local and
  compositor checks (`VOX_DISABLE_LAYOUT_UNIT_STYLE_COMPARISON` is the
  control). A 2x test fails with the control set.

On bundle `0994c97b…` (receipt `20261104-135552-90689c5a`) the diagnostic
reports no full rebuild during the scroll window. Unprofiled cohort `rQ`
(14:07–14:12 MSK, protocol of `rK`, control = the old unit comparison,
load 19–40, every run and guard exit 0):

| Run | Scroll FPS | Median / p95 / max interval | Over 16.7 ms | Input delivery |
| --- | ---: | --- | ---: | ---: |
| control-1 | 39.2 | 22.8 / 48.0 / 273.0 ms | 64% | 53.2 Hz |
| candidate-1 | 45.5 | 17.0 / 39.0 / 276.5 ms | 52% | 57.5 Hz |
| control-2 | 41.5 | 21.4 / 44.2 / 257.4 ms | 64% | 52.9 Hz |
| candidate-2 | 47.7 | 16.6 / 35.6 / 265.0 ms | 50% | 57.3 Hz |
| control-3 | 33.9 | 25.9 / 47.7 / 262.1 ms | 72% | 50.4 Hz |
| candidate-3 | 47.7 | 16.9 / 38.0 / 226.9 ms | 54% | 57.1 Hz |

The candidate's median interval now sits at the 60 Hz budget, but half the
intervals still exceed it and the 227–277 ms maxima are complete repaints
(slide changes). The 60 FPS goal remains open. The earlier evidence
directory `Build/vlang-fps-20261103` was removed while the disk was full;
new evidence is under `Build/vlang-fps-20261104`.

### Image-tile submission experiment (2026-11-04, later afternoon)

**The 60 FPS goal remains open; image-tile batching stays opt-in.**
`8eae1b2e3` adds `VOX_ENABLE_IMAGE_TILE_BATCH=1` (the disable override wins).
An image spanning several root or compositor raster tiles can now queue those
independent draws and readbacks before waiting once. Complete tile extents,
border ownership, matrices, MSAA selection, image decoding and sampling stay
unchanged. The batch shares its immutable source upload and publishes nothing
until all readbacks succeed; unsupported geometry and failures use serial
replay. GPU target allocation and CPU views are bounded.

Focused checks pass under the memory guard:

- 2,016 exact comparisons against complete GPU targets, including RGBA/YUV,
  video sampling, mip resizes, rounded clips, borders, partial opacity, source
  mutation, cache hits, row padding and failure after earlier queued readbacks.
- 240 exact native frame comparisons against serial complete draws and disjoint
  damage-strip replay at scales 1 and 2, in root and compositor coordinates.
  The final policy check also verifies default-off and disable precedence.
- 39 scroll-probe tests. Tool commit `b75a8b9ab` adds explicit image-renderer
  selection, requiring its exact loaded path and unchanged hash/file identity.

The shared production build guard was busy, so the native checks reused the
newest completed bundle, executable `f77039aa…` (receipt
`20261104-151223-21d94207`); both arms selected the same
explicit unpublished native libraries. These are native-candidate observations,
not validation of an installed production optimization. The measured bridge
enabled batching by default; the committed bridge changes only that admission
policy to require opt-in. The raw archive retains a hash-verified patch that
reconstructs the measured policy from the implementation commit.

The live protocol matches `rQ`: automatic author scripts, direct HTTPS, empty
private profile/cache, retained OS caches, matching-title readiness plus 30s
settling, 1024×768 document at scale 2 with 112px chrome, 600 precise delta-2
wheel events at requested 60 Hz, reversing every 60 inputs. Throughput covers
the entire first-to-last input interval and counts changed native layer
publications with changed scroll position, not physical display scanout.

| Run | Scroll FPS | Median / p95 / max interval | Over 16.7 ms | Input delivery |
| --- | ---: | --- | ---: | ---: |
| control-1 | 49.5 | 16.7 / 35.4 / 238.7 ms | 52% | 57.9 Hz |
| candidate-1 | 51.6 | 16.5 / 29.6 / 190.9 ms | 47% | 58.9 Hz |
| control-2 | 50.2 | 16.6 / 32.2 / 226.0 ms | 49% | 58.2 Hz |
| candidate-2 | 39.7 | 19.3 / 50.3 / 311.1 ms | 63% | 55.9 Hz |
| control-3 | 49.6 | 16.7 / 35.9 / 201.1 ms | 50% | 58.0 Hz |
| candidate-3 | 50.6 | 16.6 / 32.4 / 209.9 ms | 50% | 58.7 Hz |

Every browser and guard exited 0; all six trials retained unchanged executable,
native-library and probe identities throughout the cohort. Each pair's cached
resource URL/body-hash maps match. This is still a live animated carousel,
not a frozen animation workload. One-minute host load ranged from 14.5 to
32.2 on 18 logical CPUs; candidate-2 regressed despite a lower starting load.
Neither the median's small improvement nor two winning pairs establishes a
reliable gain, so the default renderer keeps serial image replay.

Separate diagnostic `batch-diag3` confirms execution during input: 33 GPU
readbacks used eight submissions, with further batches served entirely by the
pixel cache. This is batching per image, not one submission for the whole
frame. An earlier diagnostic was invalidated by shared-bundle replacement and
is retained; preliminary compile/loader failures are also retained. A fresh
`optin-live-check` using the final committed admission policy also completes
all 600 inputs with the exact selected native libraries and zero browser/guard
exits. No
instruction saving, completed default-path scrolling fix, broad-check cadence
reset or broad V-suite pass is claimed.

The working evidence is in `Build/vlang-scroll-next-20261104-1520`.
[Durable results](performance/vlang-image-tile-batch-20261104.json) and the
[raw logs, commands and receipts](performance/raw/vlang-image-tile-batch-20261104.tar.gz)
are committed so deleting `Build/` does not erase this cohort.

### Damage budgets and stationary filters (2026-11-04, evening)

**The live 60 FPS goal remains open.** Two separate changes address unnecessary
invalidation, with independent same-binary controls:

- `4b41a2670` budgets coalesced damage instead of charging overlapping old/new
  command ink repeatedly. Hundreds of changes inside one small region can
  reconcile. Conservative bounding joins never omit damaged pixels; the planner
  declines after 48 disjoint rectangles, preserving the native limit and bounded
  work. A join touching a saved video backdrop converts it to ordinary damage.
  `VOX_DISABLE_COALESCED_SCROLL_DAMAGE=1` restores the old accounting.
- Experiment `78bb5923e` gives non-pointwise filters an ordered input identity. Identical
  inputs at the same raster position retain their pixels. Scrolling changes a
  position-dependent filter's key, while changed descendants damage its complete
  inflated output. Nested groups, input order, clips, canvas draws and video
  generations participate; the content-anchored gradient blur still translates
  exactly. Policy follow-up `12fc06ffe` retains it behind `VOX_ENABLE_STATIONARY_FILTER_REUSE=1` after
  the paired regressions below; `VOX_DISABLE_STATIONARY_FILTER_REUSE=1` wins.
  The default keeps per-frame invalidation and skips input-identity bookkeeping.

Focused verification covers six new budget cases, four new filter-identity cases
and the existing 20-case scroll-raster file. The budget checks compare partial
replay with complete repaint in both scroll directions, and retain large-area,
unbounded-content, paint-order and native-capacity refusals. The filter checks
retain complete blur extents after a child changes. Thirty-two native blur and
drop-shadow scenes match complete repaints under partial publication at 1x/2x,
with opaque/translucent backdrops and padded rows. The existing native ring
pixel check also passes. These are focused checks, not a broad-suite pass or an
instruction-saving claim. One default planner fix and one opt-in experiment are recorded;
no broad-check baseline is reset.
The final four-case and 20-case filter executables also pass in separate
fresh processes with default admission, explicit enable, and enable plus the
disable override; enabled mode exercises all stationary-reuse assertions.

The first unprofiled cohort isolates damage coalescing on completed production
`5aea1198…`, receipt `20261104-164034-11ba6b48`. Its implementation includes the
final budget/video guards; only the later optional area logging is absent.
Each pair alternates `VOX_DISABLE_COALESCED_SCROLL_DAMAGE=1` and the default.

| Run | Scroll FPS | Median / p95 / max interval | Over 16.7 ms | Input delivery |
| --- | ---: | --- | ---: | ---: |
| control-1 | 54.4 | 17.0 / 26.0 / 138.1 ms | 56% | 59.3 Hz |
| candidate-1 | 53.3 | 16.7 / 28.4 / 153.1 ms | 51% | 58.5 Hz |
| control-2 | 50.8 | 16.7 / 28.8 / 217.1 ms | 51% | 58.2 Hz |
| candidate-2 | 54.1 | 16.7 / 25.0 / 151.7 ms | 53% | 59.1 Hz |

All four browser/guard exits are zero and all cohort input identities remain
unchanged. Each pair's 29 cached resource URL/body-hash records match. Host load
ranged from 9.1 to 11.3 on 18 logical CPUs. One pair regresses, so these live
animated-page observations do not establish a reliable throughput gain.
The protocol remains the 1024x768, scale-2, 112px-chrome, 30s matching-title
settle and 600 precise delta-2 wheel inputs of `rQ`, with automatic scripts,
private empty profiles/caches, direct HTTPS and retained OS caches. Reported
throughput spans the entire first-to-last input interval and counts changed
scrolling layer publications, not physical display scanout.

Separate diagnostics on the preceding baseline and an intermediate coalescing
build each retain ten complete repaints. The final installed-build diagnostic
`final-diag`, executable `4d55ec44…` (receipt `20261104-165354-07f93a6d`), completes
all 600 inputs and retains eleven area fallbacks. The new area log exposes
why coalescing alone does not remove them: most cover 428,980–436,560 CSS pixels
of the 786,432-pixel viewport, still above the 393,216-pixel budget. The full
viewport and a 494,648-pixel update also occur. Instrumented FPS is not used for
optimization credit, and comparisons across these different builds are not
attributed to either fix.

A second unprofiled cohort isolates stationary-filter reuse on that final
`4d55ec44…` bundle, with coalescing enabled in both arms. The measured revision
enabled stationary-filter reuse by default; controls disable it. The final
source gates it explicitly, and the archive retains a source-hash-verified
patch reconstructing the measured policy.

| Run | Scroll FPS | Median / p95 / max interval | Over 16.7 ms | Input delivery |
| --- | ---: | --- | ---: | ---: |
| control-1 | 35.5 | 21.9 / 42.9 / 314.3 ms | 72% | 52.6 Hz |
| candidate-1 | 31.8 | 23.9 / 47.3 / 656.3 ms | 75% | 51.7 Hz |
| control-2 | 35.6 | 21.5 / 54.1 / 282.3 ms | 70% | 53.9 Hz |
| candidate-2 | 25.6 | 28.7 / 65.5 / 695.3 ms | 86% | 48.6 Hz |

All four browser/guard exits are zero and identities remain unchanged.
Host contention rose sharply: one-minute load was 63.3–78.4 on 18 logical CPUs,
with candidates facing high/rising load. Both paired observations regress, so
they provide no optimization credit; their cause remains unresolved. They also
cannot be compared with the earlier low-load cohort as engine performance.
Stationary-filter reuse remains opt-in. The newest completed browser used here
predates that admission-policy rollback; installation of the final default-off
policy remains pending the shared production build.

Original compile/fixture failures, the provisional browser checks and all paired
attempts are retained. The corrected checks use the repository's UI2 embedding
module path and explicit Clang backend; obsolete per-frame-filter assertions
were updated to require stationary reuse and continued scroll invalidation.
Working evidence is under `Build/vlang-damage-20261104-1630`.
[Durable results](performance/vlang-damage-filter-20261104.json) and
[raw commands, logs and receipts](performance/raw/vlang-damage-filter-20261104.tar.gz)
preserve the evidence independently of that directory.

### Parallel CPU pixel work (2026-11-04, late evening)

**The live 60 FPS goal remains open.** Commit `c197d4355` adds one reusable CPU
worker pool for independent channel conversion, backdrop copying and recorded
layer compositing. Its capacity includes the caller and follows the available
logical CPU count (18 here). Large jobs can use every participant; each range
needs at least 524,288 pixels (2 MiB). Small jobs stay serial, and skipped opaque
centers do not count toward the backdrop-copy admission threshold. Only workers
assigned to a job wake. Concurrent producers share the pool; nested work runs
serially. Callbacks finish before their buffers are published or released.
Workers inherit the caller's floating-point rounding mode for exact blending.
AppKit, mutable paint state, Skia recorders and GPU submission retain their
existing owners and ordering. This does not parallelize the entire browser.

`VOX_DISABLE_PARALLEL_RASTER=1` restores serial execution in the same native
library. `VOX_PARALLEL_RASTER_DIAGNOSTICS=1` reports each parallel job's kind,
units, participating lanes and pool capacity. A separate live diagnostic with
the final policy records 44 parallel channel conversions and 16 backdrop copies
during native input, using two to four participants per job. Recorded-layer
compositing is covered by pixel checks, but did not occur in that live diagnostic
and earns no scrolling attribution. The scheduler test observes 18 distinct
threads inside one simultaneous job; a 10-megapixel conversion also exercises
the full pool. Capacity is not a claim that all cores stay busy on every frame.

The first policy used 65,536 pixels per participant and woke every worker.
Both live pairs regressed, so that policy was rejected:

| Pair | Serial FPS | Parallel FPS |
| --- | ---: | ---: |
| 1 | 46.2 | 39.3 |
| 2 | 44.0 | 40.6 |

Range-size sweeps showed that wake-up overhead exceeded the SIMD copy time for
small buffers. Those microbenchmarks selected the coarser policy; they do not
establish scrolling FPS. The final unprofiled cohort alternates serial and
parallel execution of the same native candidate:

| Run | Scroll FPS | Median / p95 / max interval | Over 16.67 ms | Inputs / scroll intervals / all publications |
| --- | ---: | --- | ---: | --- |
| serial-1 | 45.1 | 16.8 / 38.8 / 245.9 ms | 51% | 600 / 480 / 680 |
| parallel-1 | 45.3 | 17.0 / 37.1 / 315.1 ms | 53% | 600 / 479 / 705 |
| serial-2 | 46.8 | 17.0 / 31.5 / 235.8 ms | 53% | 600 / 489 / 718 |
| parallel-2 | 47.3 | 16.5 / 37.2 / 252.1 ms | 49% | 600 / 494 / 744 |

These small throughput differences do not establish a reliable improvement.
Tail latency regresses, including the first parallel run's 315 ms maximum.
Input delivery is respectively 56.3, 56.6, 57.3 and 57.4 Hz. Leading/trailing
scroll-publication gaps are 212.3/0.3, 237.0/1.4, 199.7/161.6 and 173.9/0.4 ms;
the throughput denominator includes the complete first-to-last input window.
The JSON retains raw counts, exact intervals, host loads and actual input/frame
timestamps. Publication means changed native layer contents after `updateLayer`,
not physical display scanout.

Both cohorts use live direct HTTPS, automatic scripting, a 1024x768 CSS-pixel
viewport at 2x backing scale, empty private profiles/caches, retained OS caches,
30 seconds of settling after the matching document title, and 600 native precise
wheel events at nominal 60 Hz, delta 2, reversing every 60 inputs. All browser,
driver and guard exits are zero; executable/native-library identities stay fixed
throughout each cohort. Every pair has the same 29 cached resource URL/body-hash
records. Host load changes from 62 to 37 in the rejected cohort and spans 38–45
in the final cohort on 18 logical CPUs. Other production compilation continued
on the host. Controls and candidates share that contention; small gains remain
uncertain.

The rejected cohort uses executable `6e17496f…`, and the final cohort uses the
newest completed production executable then available, `70de4b58…`. Each loads
an explicitly pinned native candidate, with serial/parallel selected only by the
disable variable. Do not compare the two cohorts as a same-build pair. Both
disable stationary-filter reuse. The final candidate also disables concurrent
hidden-content/root-region shadow experiments in every run, isolating this pool.
The raw records retain complete executable, library, source and resource hashes.

Focused verification passes optimized compilation with warnings treated as
errors (excluding unused helpers from the existing opacity header), plus
AddressSanitizer/UndefinedBehaviorSanitizer and ThreadSanitizer execution.
Checks cover exact in-place and unaligned conversion, scalar/SIMD tails, padded
rows, skipped opaque cores, strided and contiguous blending under all four
rounding modes, complete disjoint coverage, concurrent producers, nested calls,
exception draining, serial fallback and actual worker participation. All 144
existing local compositor picture comparisons also pass with the final pool.
Focused runtime guards retain the 3 GiB cap; production/native compiles and live
cohorts retain the default 12 GiB cap. This is no broad-suite or instruction-count
claim. GPU round trips, full carousel repaints and main-thread input remain the
larger unresolved work.

The shared production build subsequently completed as receipt
`20261104-181445-ed287358`, executable `b8701f74…`. A fresh installed-process
diagnostic on live vlang.io completes all 240 inputs, exits cleanly and confirms
that the installed bridge reaches the coarser parallel paths during input.
This run uses the installed default settings and has no candidate injection;
its diagnostic timing supplies no additional performance credit.

Working evidence is in `Build/parallel-raster-20261104-1800`.
[Durable results](performance/vlang-parallel-raster-20261104.json) and
[raw commands, logs, timestamps and receipts](performance/raw/vlang-parallel-raster-20261104.tar.gz)
retain both the rejected and final cohorts independently of `Build/`.

### Invisible clipped text and the root background (2026-11-04, evening)

**The live 60 FPS goal remains open, but periodic complete repaints are gone.**
In the `rQ` protocol's 10.6 s input window, ten complete repaints (median
123 ms, up to 246 ms) took 26% of all replay time and caused the 200+ ms
maxima. They were not carousel slide changes: slides last 10–25 s. A damage
diagnostic showed 12 `draw_text` runs leaving and re-entering the recorded
paint-interest area at each scroll reversal. That text overflows the demo
card's `overflow: hidden` box and is clipped away entirely, but its scroll key
used the whole clip rectangle as conservative ink. The card is 958x438, 55% of
the viewport and above the 50% damage budget, so each change fell back to a
complete repaint. Separately, the root background spans the viewport origin
to the document height. Its key hashed that height, so a document-height
change damaged the whole viewport, although only offscreen rows differ.

- `fc0de2a61` gives a leaf clipped away entirely a 1x1 rectangle inside its
  clip, nearest its ink. Ink within 2 CSS px of the clip keeps that sliver of
  the clip, because a device pixel can straddle a sub-pixel gap.
  `VOX_DISABLE_MINIMAL_CLIPPED_SCROLL_INK=1` restores whole-clip ink.
- `34bd72f6d` omits a viewport-filling solid's geometry from its
  translation-free key, with a domain marker. Color changes and a fill that
  stops covering the viewport still damage it.
  `VOX_DISABLE_VIEWPORT_FILL_EXTENT_REUSE=1` restores the geometry key.

`main_scroll_raster_test.v` and `main_scroll_raster_damage_budget_test.v` pass
with the production compiler, including new cases for invisible clipped text,
the straddling sliver and the background's offscreen extent.

Both run on production executable `b8701f74…` (receipt
`20261104-181445-ed287358`), which also contains the multicore pixel pool of
`c197d4355` with its default policy in every run. Separate damage diagnostics
on that executable count complete repaints inside the input window: the
control (both variables set) has ten `damage-too-large` fallbacks of 114–250
ms; the candidate has none among 818 reused frames.

Unprofiled cohort `rK2` (18:27–18:32 MSK) alternates the control and default on
that executable, with the `rQ` protocol: live direct HTTPS, automatic scripts,
empty private profile/cache, retained OS caches, 30 s settling after the
matching title, 1024x768 at scale 2 with 112px chrome, and 600 precise delta-2
wheel inputs at nominal 60 Hz, reversing every 60. Throughput spans the whole
first-to-last input window and counts changed native layer publications with
a changed scroll position, not physical scanout.

| Run | Scroll FPS | Median / p95 / max interval | Over 16.67 ms | Inputs / scroll intervals / all publications | Input delivery |
| --- | ---: | --- | ---: | --- | ---: |
| control-1 | 50.6 | 16.6 / 30.9 / 223.2 ms | 47% | 600 / 521 / 943 | 58.2 Hz |
| candidate-1 | 57.1 | 16.8 / 26.9 / 70.1 ms | 52% | 600 / 577 / 1070 | 59.3 Hz |
| control-2 | 52.2 | 16.7 / 27.3 / 174.9 ms | 50% | 600 / 530 / 1044 | 59.0 Hz |
| candidate-2 | 56.6 | 16.8 / 28.4 / 66.9 ms | 53% | 600 / 574 / 1039 | 59.1 Hz |
| control-3 | 49.6 | 16.5 / 34.5 / 225.3 ms | 47% | 600 / 508 / 914 | 58.4 Hz |
| candidate-3 | 53.0 | 16.7 / 32.5 / 85.3 ms | 50% | 600 / 549 / 862 | 57.8 Hz |

Every browser and guard exited 0, and executable/native-library hashes were
identical before and after the cohort. Leading/trailing scroll-publication gaps
are 179/4, 167/10, 159/13, 172/9, 188/4 and 274/11 ms. One-minute host load fell
from 20.2 to 12.0 on 18 logical CPUs; candidate-3 started at the same load as
control-3. All three pairs improve throughput (+6.5, +4.4, +3.4 FPS) and the
maximum interval falls from 175–225 ms to 67–85 ms. With input at a nominal
60 Hz, the fraction over 16.67 ms stays near half from delivery jitter alone,
so it does not separate the arms.

The remaining long frames are one-off first draws (for example, 45 ms for the
first strip of the DOOM screenshot) and animation-damage frames: the tab
progress bar repaints the card's composited-layer shadow and the tab strip's
border at about 2.2 ms each. Their cost is the per-leaf GPU target, submission
and readback. Root-shadow region readback and a content-hole shadow skip were
tried as native experiments; neither executed on this page, because every
vlang.io shadow is drawn in a composited layer, so both were reverted and are
not in the tree.

Evidence is under `Build/vlang-fps-20261104` (`diagK-*`, `rK2-*`). The
[raw summaries, logs, commands and guard reports](performance/raw/vlang-clipped-ink-20261104.tar.gz)
are committed so deleting `Build/` does not erase them.

### Scroll-start stalls, idle GPU state and large uploads (2026-11-04, night)

**The live 60 FPS goal remains open.** After the clipped-text fix, every run
still starts with a 160–270 ms gap between the first input and the first scroll
publication: the first frames take about 104–119, 66–102 and 33–56 ms. Leaves
that normally cost ~2 ms take 9–53 ms. Two explanations were tested.

**Idle GPU context retirement is not the cause.** The bridge retires its three
GPU contexts after two seconds without raster work, and a standalone check of
the installed `libVoxGraphite.dylib` shows a retired context's first shadow
draw costs 13–18 ms instead of 2–3 ms. Retirement frees about 27 MiB of process
footprint per context there (217 → 190 MiB). A bridge-only experiment,
`VOX_GRAPHICS_IDLE_RETIRE_SECONDS`, kept every context while frames were being
painted. Its diagnostic confirms that no context retired, yet the first frames
stayed equally slow. Cohort `rI` (executable `2550c9ec…`, injected bridge
`002bae06…` in both arms, load 19.5–25) shows no consistent change: candidate
FPS 52.8/55.7/52.1 versus control 45.8/55.5/55.6, with leading gaps
253/164/238 versus 237/211/206 ms. The experiment was not committed; its patch
and logs are archived below.

**GPU power-state ramp is.** Without any retirement, the same standalone shadow
draw takes 2.2–2.7 ms warm, 9.4 ms after 3 s idle, 10.7 ms after 10 s and
15.3 ms after 30 s, and the following draws stay slower for a few frames. Each
leaf's synchronous submit-and-readback pays that latency separately, so the
cost of resuming after a pause grows with the number of GPU leaves in the
first strips. It is inherent to per-leaf GPU readback rather than to a cache
policy.

**Large decoded images now reuse one upload** (`d0347a830`). The DOOM screenshot
on the second slide is 1824x1468, uploaded at 912x734. With the source copy the
upload cache keeps for exact reuse, an entry costs 13.4 MiB, above the 8 MiB
per-entry cap, so each tile of each redraw repeated its CPU downscale and
upload: three ~6.5 ms uploads per redraw. One entry may now use half of the
unchanged 32 MiB budget. A diagnostic run on the candidate library shows all 19
uploads in the input window reused, and the image's first two strips fall from
38–52 ms to 37 and 20 ms; ordinary strips of it still cost ~6 ms of tile work.
`tools/test_native_graphite_cache.sh` passes with a new admission case.

Cohort `rU` alternated the rebuilt unchanged library (byte-identical to the
installed one) with the candidate. A production build replaced the executable
mid-cohort (`abd2573b…` then `49e0a818…`), so the cohort is invalid as a whole;
candidate-2 aborted on the identity check. The two pairs that stayed on one
executable show no throughput change: 45.9 versus 45.7 and 48.2 versus 47.3
scroll FPS. The image redraws only at a few scroll extremes, so no scrolling
speedup is claimed.

Two further findings bound the remaining options:

- The card's 1200x680 composited-layer shadow is painted after the tab strip
  (the demo stage is positioned), so it genuinely darkens the strip under the
  progress bar. Animation damage there must replay it; only the strip's
  border could be skipped by a ring-aware planner, worth about 5% of replay.
- Layer shadows render their whole canvas-clipped region on the GPU for every
  strip. A standalone check confirms the code's warning: cropping that target
  by hundreds of rows changes the blur's pixels (57 of 72 crops match; large
  ones do not), so their output cannot be reused across scroll positions
  without changing pixels.

The remaining cost is structural: each leaf is drawn by its own synchronous
GPU submission and readback, then composited on the CPU. Drawing all leaves of
a damaged region in one GPU pass, as Chromium rasterizes a tile, is the next
substantial lever.

Evidence is under `Build/vlang-fps-20261104` (`rI-*`, `rU-*`, `idlediag-*`,
`imgdiag*`, `shadow-target-exp`). The
[raw logs, experiment sources and guard reports](performance/raw/vlang-gpu-idle-upload-20261104.tar.gz)
are committed.

## GPU canvas for reused scroll frames (2026-11-05)

The GPU canvas, on by default since 2026-11-05 (Settings → Advanced →
GPU-accelerated scrolling turns it off), draws the approved leaves of a reused frame's
repainted rectangles on GPU surfaces and reads them back once, like
Chromium's tile raster, instead of a synchronous GPU wait per leaf. On a
quiet host it delivers 59.9 versus 59.3–59.6 FPS at 60 Hz (598 versus
593–596 of 600 inputs, scroll-start gap 40 versus 90 ms) and 119.1–119.2
versus 112.1–112.4 FPS at 120 Hz (p95 10 versus 14 ms). Per-leaf verification
differs by at most 5 levels. Design, guards, verification, cohorts and
remaining readbacks: [VLANG_GPU_PASS.md](VLANG_GPU_PASS.md).

## Leaf costs at a 1708 px window (2026-11-05)

The user's 1708×1065 window (1708×953 document viewport) scrolls vlang.io far
below 60 FPS: delta 8 at 120 Hz measured 16.5 FPS with a 68.7 ms mean
scroll-frame draw loop, on a host at load 40–140 from concurrent sessions. The
site's stylesheet has changed since the earlier work: its code panels use
`inset 0 1px #ffffff05`, sponsor logos use `filter: grayscale(1)` under
`mix-blend-mode: screen`, and the hero shows a 3993×2317 mascot and a
1426×1080 video. Leaf timings (`VOX_LEAF_TIMING_DIAGNOSTICS=1`) per scroll
frame, and the fixes:

| Leaf | Cause | Fix |
| --- | --- | --- |
| Inset shadows, 37–65 ms each | backdrop of the whole 581×447 box serialized into a picture and replayed in every root tile, for any strip | `2247795d5` crops to the damage rows as outer shadows do; `11e71c035` renders the tiles in one GPU submission (12.5 → 7.2 ms per slow leaf) |
| CSS filter layers, 21 ms (300 ms frames as logos enter) | canvas-sized offscreen layer filtered and composited entirely | `0c5028c48` filters and composites only the clip bounds for color filters (21 → 15 ms); `19e9d038a` also crops the Core Image input |
| Mascot image, 22 ms | 37 MB source exceeds the upload cache's copy budget, so every draw rescaled it | `404e5ef4d` keeps a seeded digest instead of a source copy (21.7 → 11.2 ms; all 57 draws reuse the upload) |

Each fix has a pixel-exact native test against the complete or serial
replay. Measured with injected libraries or kill switches on one executable,
the mean scroll-frame loop fell from 68.7 to about 25 ms and FPS rose to
23–27. Host load swung between 20 and 150 during these runs, and unprofiled
pairs often disagreed in direction, so only the per-leaf diagnostic
reductions are firm. The CSS filter input crop is in the executable and has no
scroll measurement yet.

Two experiments are rejected and kept as patches in the evidence archive:
inset shadows as pictures on the GPU canvas (exact, but most vlang.io insets
overlap Chromium MSAA tiles and are declined: 6.7 versus 6.0 ms per frame,
FPS slightly lower), and video frames on the GPU canvas (exact, but the slow
video leaf rose from 28.4 to 33.7 ms).

The largest remaining cost is outside the leaves. A sample of the idle page
with its video playing spends 28% of main-thread time in
`native_scroll_raster_copy_rows`: every reused frame copies the complete
retained viewport (about 26 MB at this window size) from the ring into
AppKit's fresh canvas before replay. Chromium never copies retained tiles;
the compositor offsets them. Presenting the ring through Core Animation
(two wrapped sublayers, or layer-anchored tiles) would remove that copy and
the per-frame full-canvas upload with it. Evidence:
`docs/performance/raw/vlang-large-window-leaves-20261105.tar.gz`.

The 119 FPS result above and these numbers measure different workloads. That
cohort used a 1024×768 viewport, 1200 delta-1 inputs at 120 Hz reversing every
120 (the top 120 px of the page) and a host at load 4. On bundle `e9b0f545…`,
which contains all five fixes, alternating runs at load 12–33 measured 97.0 and
111.1 FPS with that protocol, and 54.3 and 46.7 FPS (p95 44 ms) with the
1708×953, delta-8, reverse-every-150 protocol. The larger window and longer
scroll range reach the code panels, sponsor logos, mascot and video that the
original protocol never scrolls to.

## Toward 60 FPS at a 1708 px window (2026-11-05, continued)

A main-thread sample of the user-sized scroll (bundle `e9b0f545…`, GPU canvas
on) put 45% of the main thread in synchronous GPU round trips (inset
shadows, CSS gradient tiles, shapes and images, plus canvas readbacks before
unsupported commands), 19% in the scroll ring's copy into the frame and 11%
in CSS gradient tiles alone. Changes since:

| Commit | Change | Evidence |
| --- | --- | --- |
| `52b606694` | Inset shadows (including over Chromium MSAA tiles, through a multisampled scratch pass), stroked rounded rectangles and ellipses draw on the GPU canvas | 3 pairs, load 102–118: 46.6/45.9/46.7 → 53.1/53.8/51.8 FPS; live per-leaf verification finds no differing inset leaf |
| `9d8ecb111` | CSS gradient tiles (generated-image patterns) draw on the GPU canvas | 3 pairs, load 42–58: 36.6/38.3/41.7 → 40.6/43.4/43.9 FPS |
| `f9d0d123d` | Frame bitmaps come from a pool of three mapped buffers instead of a new 29 MB allocation per frame | copying 26 MB into a fresh bitmap: 2.73 ms, into a reused one: 0.75 ms; idle animation frames spend 33% of the main thread in that copy |
| `8f7a8e859` | The ICC conversion cache holds 96 MB, so the 37 MB converted mascot is cached | the mascot leaf took 40–118 ms per frame, converting 9.25 million pixels each draw |
| `3ac582b15` | Video frames swap channels with NEON instead of a per-byte loop | conversion check covers every byte |

Both A/B cohorts use the same injected libraries in both arms with the new
kill switches (`VOX_GPU_CANVAS_DISABLE_INSET`, `_OUTLINES`, `_GRADIENT_TILES`)
in the control. With all canvas changes injected, a scroll frame reads the
canvas back 0.88 times (only the end-of-frame readback in most frames) and
the mean draw loop is 13.0 ms, against 26.9 ms for the bundle installed at the
time under the same load.

Absolute FPS moved with host contention throughout: the GPU was 20–36% busy
with other sessions' work and per-leaf GPU waits grew about 1.5 times between
two otherwise similar runs. The pool, ICC and video changes are in the main
executable and await a production build; the shared build was repeatedly
invalidated by concurrent edits before freezing, so no installed bundle
contains them yet and they have no scroll measurement.

Remaining costs per scroll frame at this size: the end-of-frame canvas
readback, the playing video (a 1426×1080 frame uploaded and drawn at
948×718 for every new frame, about 30 ms per draw under contention), the
sponsor logos' Core Image filters, solid fills with fractional edges (the
canvas cannot observe Quartz's anti-aliasing state and reads back first) and
the scrollbar thumb, which is often a frame's only GPU leaf. The ring copy
itself remains until the retained frame is presented through Core Animation
instead of copied.

## Video batching and shared frame presentation (2026-11-05)

The large-window 60 FPS target remains open. The following changes are committed
and have focused pixel and ownership checks:

| Commit | Change | Matched live observations |
| --- | --- | --- |
| `881f5a55c` | Completed opaque callbacks skip clearing their pooled frame first; incomplete callbacks still clear | Initial pairs improved, installed pairs regressed; no reliable throughput credit |
| `f5139fcdc` | Video draws remain in the GPU canvas across mixed ordinary/MSAA tiles, after restoring their CPU backdrop | 35.77→39.71 and 33.64→36.59 FPS; p95 74.3→62.2 and 75.4→64.5 ms |
| `c1debfe0f` | A successful canvas read happens once; only a failed transfer retries | 69.89→75.41 and 63.54→86.67 FPS; host load fell during these pairs, so the size of the gain is uncertain |
| `d7427e739`, `8a1e4df5f` | Raster frames paint directly into pooled IOSurfaces that Core Animation presents; immutable images remain available for snapshots and capture | 66.65→75.02 and 58.93→67.01 FPS; median intervals 11.81→9.23 and 12.89→9.98 ms |

These are separate cohorts, each using one executable and matching C mode in
both arms. They cannot be joined into a cumulative speedup: the video cohort
uses a parallel-C build, the single-read cohort a single-C build, and the
IOSurface cohort a newer parallel-C build. The latter pins executable
`d0eac328379f92fcaef0206c83caad98113c17c97b78748df06f1995ba79758e` and the
same unpublished native bridge in both arms. All use the live HTTPS page,
a fresh private profile/cache, automatic author scripting, a 1708×953 document
viewport at 2×, a title readiness check followed by 10 seconds of settling,
and 600 precise delta-8 inputs at nominal 120 Hz reversing every 150 inputs.
OS filesystem/shader caches are retained. The endpoint is a changed native
layer publication with changed scroll position after `updateLayer`, measured
across the entire first-to-last input period; physical display scanout is not
measured.

Shared frames are enabled by default. `VOX_DISABLE_IOSURFACE_FRAMES=1` restores
CGImage presentation. A surface remains unavailable while an immutable image
owns its pixels or WindowServer reports it in use. Exhaustion, unsupported
sizes and allocation failures retain the ordinary image path. The focused
checks compare actual Core Animation output exactly at 1× and 2×, cover
padded rows and transparency, retain snapshots across further frames, simulate
WindowServer use counts, exercise capture ownership and test resizing.
A live diagnostic recorded 291 IOSurface and 11 fallback publications, plus
359 direct canvas reads, during input; it is excluded from performance credit.

`08fc3c50a` adds direct shared-Metal readback into the final frame rows, avoiding
staging allocations and copies. It remains opt-in with
`VOX_GPU_CANVAS_DIRECT_READBACK=1`: its live pairs were mixed (45.91→37.35 and
41.05→54.26 FPS) while host load rose from 14 to 38. Unsupported targets or
failures use the staged reader. Tests compare exact bytes, odd widths, row
padding, multiple regions, CPU interruption order, and unchanged output when
a later region is invalid.

IOSurface p95 intervals were 32.71 and 38.82 ms, with maximum intervals 172.1
and 141.6 ms. One p95 and one maximum regressed despite improved throughput;
these results do not establish smooth 60 FPS. Earlier 60 Hz input trials of
the single-read build produced 53.12 and 56.30 FPS, also below the target.
The retained viewport copy and synchronous GPU/filter waits remain costs.

The previous CPU video experiment was rejected: temporary source buffers were
freed before Skia consumed them, and the corrected CPU rendering still differed
at rounded clips and regressed scrolling. A copy into IOSurfaces before
presentation also regressed both pairs. Disabling Metal GPU-optimized texture
layout passed a small native test but failed to load the browser page; that
experiment was reverted. Patches, failed attempts, profiles, all paired results,
input schedules, native image identities, host load, raw publication timings,
checks and actual exits are retained in the
[machine-readable evidence](performance/vlang-gpu-scroll-finish-20261105.json)
and its linked raw archive. References and pixel tolerances were not changed.

The installed default-on IOSurface bundle `142853c750815d0bf22b98526a0bca75806620c7c58e768b2e1f9c58364eb0f0`
(parallel C) completed two fresh, unprofiled 60 Hz trials at 50.19 and
56.96 scroll-changing publications/second. Actual input delivery was 53.40 and
58.73 Hz. Median/p95/maximum scroll intervals were 16.76/28.23/912.48 ms and
16.68/22.78/105.88 ms, with 54.0% and 50.6% over the strict 16.67 ms budget.
The 912 ms gap is retained. Earlier same-bundle IOSurface 60 Hz pairs were
52.83→47.60 and 49.64→51.37 FPS; the throughput gain at 120 Hz does not carry
over reliably to 60 Hz input. The installed bundle also passes `inline-node`
and `canvas-text` with their existing bounds and the same-size SVG source
mutation with exactly zero differing pixels.

A separate stall diagnostic found that normal reused frames batch on the GPU,
but full repaint fallbacks still perform synchronous per-leaf drawing. Two
full repaint loops took 544 and 290 ms, with large shadow/decorations groups
costing 176–180 ms each. `6dbf49287` permits the same GPU canvas to cover a
complete eligible document raster with `VOX_ENABLE_FULL_FRAME_GPU_CANVAS=1`.
The full-frame native pixel comparison passes the existing 3-level bound; the production V check passes with current V,
`-new-compiler -prealloc -gc none -n`. The earlier check without the production
compiler flags failed and is retained. Screenshot rendering preserves its
ordinary full-frame path. The build request and any pending publication are
recorded in the evidence; an older executable cannot validate this new path.


The initial live full-frame verification exposed a 29-level stroke difference,
so its timings are diagnostic evidence rather than optimization acceptance.
`a367abce6` detects complete viewport rectangles and retains the ordinary tile
path for shapes there; other approved leaves continue to batch. Forced full
repaints with per-leaf verification now stay within 3 channel levels, including
video, shadows and text. The earlier short verification schedules failed (an
8-input schedule was below the tool minimum; 10 inputs completed only one
publication under instrumentation). Both failures and their pixel diagnostics
are retained; they are not performance results.

With the corrected native bridge identical in both arms, two fresh unprofiled
60 Hz pairs measured 49.85→57.04 and 52.92→53.32 FPS. Maximum scroll intervals
fell 689.71→114.99 and 474.32→191.39 ms; p95 changed 30.66→26.02 and
25.11→28.71 ms. The second p95 regressed. These pairs use parallel-C executable
`fcbdb3e693fa5ed4dbb6c9b84fa0ba8770570f97afaeaab3b95a82a56aad97de`
with the same explicit native bridge. `1458ba146` enables complete-frame
batching by default for eligible rasters up to 64 MiB;
`VOX_DISABLE_FULL_FRAME_GPU_CANVAS=1` restores the reused-frame-only policy.
The user's GPU-scrolling setting still controls both paths. Screenshot
full-frame rendering keeps its established path; native full-frame tests and
the separate live per-leaf diagnostic exercise batching directly.

Direct readback also had small gains in another combined-path cohort
(57.18→57.42 and 53.59→54.82 FPS), with a p95 regression in one pair. It remains
opt-in. All previous cohorts and regressions remain in the linked evidence.
The shipped fixes remove substantial work and long stalls, but neither these
throughput results nor the remaining p95/max gaps establish smooth 60 FPS.

The final default-policy build was requested once after `1458ba146`. At the
last check, publication was waiting behind another session's shared bundle
lease; the available production bundle still used the older opt-in policy.
The corrected full-frame measurements therefore use the explicitly pinned
native candidate. They validate that rendering path, but do not substitute
for a fresh launch of a subsequently published default-on executable.

## Published defaults and remaining filter work (2026-11-05, continuation)

The default-on policies are now present in production executable
`e05f01a6c41853464760ce4b59cf1782813fca8b9b1e45de22d7fe22be7a1b5c`
(parallel C). Two fresh installed-bundle trials at the same 1708×953, 2×,
600-input, 60 Hz protocol measured 44.68 and 40.30 FPS. Actual input delivery
was 53.52 and 50.93 Hz; p95 scroll intervals were 48.16 and 55.42 ms, maxima
189.60 and 756.55 ms. Host load was 67.55 and 70.12 on 18 CPUs. These are
installation checks under contention, not a new optimization comparison or a
60 FPS acceptance result. `inline-node`, `canvas-text`, and the same-size SVG
source-switch check pass their unchanged bounds on the published bundle.

A separate profile puts 195 of 1590 main-thread samples in the retained pixel
copy and substantial work in Core Image filters and synchronous readback.
A four-lane retained-copy experiment passed exact ring/wrap/row-padding and
sanitizer checks, but was rejected before a production build. Its four serial
versus parallel p95 copy measurements were 999→1785, 697→1293, 747→992, and
1081→1318 microseconds. A smaller median in some rounds does not compensate
for worsening every p95. The patch and all measurements are retained.

`8e3b30e54` adds an opt-in identity check for grayscale-only filter chains over
already-gray sRGB pixels (`VOX_ENABLE_GRAYSCALE_IDENTITY=1`, with
`VOX_DISABLE_GRAYSCALE_IDENTITY=1` taking precedence). It scans the visible
rows of the live source bitmap before its context becomes an immutable image,
then skips the Core Image submission only when every inspected pixel is gray.
Colored input, other filters, other profiles and unsupported formats retain
the existing filter path. The check creates no provider-sized byte copy.
Direct Core Image probes preserve every tested gray/alpha byte exactly at
five grayscale amounts. The new real-publication test and the existing canvas
checks pass all eight optimized/sanitized jobs, including RGBA/BGRA input,
padded rows, fractional clips, 1×/2× and colored/profile/filter fallbacks.
Workload eligibility and unprofiled comparison are required before enabling
this path by default. Follow-up evidence is retained separately from the
original archive so earlier results remain immutable.

`3e0c785d7` also verifies the observable submission count: an accepted gray
source makes zero Core Image render calls, while a colored source still makes
one. Optimized and sanitized variants pass. The new source has not yet had a
live scrolling comparison: completed shared builds have been superseded by
concurrent edits, and the next production build is still compiling. A later
host sample recorded load 209.60 on 18 CPUs. Neither the unit-level identity
result nor these contended installed-bundle trials establishes 60 FPS.
See the [continuation evidence](performance/vlang-gpu-scroll-followup-20261105.json)
for raw runs, profiles, pixel comparisons, rejected copy experiment and filter
checks; the original evidence archive is preserved.

## Isolated GPU shape passes and video backdrops (2026-11-05)

The latest installed check uses parallel-C executable
`2de773e7b01c08e979c6925842a1233b51c801131f0394c7d8736453dcb2c95e`.
Two fresh live trials measure **86.14 and 83.67 scroll-changing publications/s**,
with median intervals 8.83/9.39 ms, p95 25.01/26.48 ms, maxima
99.95/107.25 ms and 13.8/15.7% of intervals exceeding 16.67 ms. Actual input
delivery is 93.82/90.47 Hz against the nominal 120 Hz schedule. These use the
same 1708×953 document viewport, 2× backing, 600 precise delta-8 inputs and
150-input reversals, title readiness and ten-second settle, automatic scripts,
fresh private profile/cache and direct live HTTPS. OS filesystem/shader caches
remain warm. This is native publication throughput, not physical scanout.
The average exceeds 60 FPS, but the deadline misses leave smooth 60 FPS open.

`be6aeb0f2` corrects a shape coverage problem exposed during live verification:
the former GPU pass selected MSAA for an entire shape after any raster-tile
overlap. Rounded strokes can differ by 29 channel levels, and a mixed-tile
ordinary-texture control also exposes errors up to 14. The conservative path
keeps these shapes on their established per-tile replay. Video retains its
separate, explicit MSAA-rectangle API.

`c937d6203` then isolates ordinary and multisampled shape passes, selecting
their raster tiles only when compositing the results. Keeping each leaf's
original raster extent is essential: an earlier damage-cropped scratch surface
still differs by seven levels on a fractional fill. The final path stays within
one level in focused fill/stroke cases and three in the live per-leaf check
(1,183 comparison records). It prepares every scratch result before changing
any destination, and failed preparation preserves the original backdrop.
Optimized, ASan/UBSan, ownership, padding and forced-failure checks pass.
`f640b922a` enables the verified path by default when the bridge supports it;
`VOX_GPU_CANVAS_DISABLE_ISOLATED_SHAPES=1` retains the per-tile fallback.

All pairs below use one executable, C mode and native-library configuration
within their cohort. Different rows use different pinned builds and host loads;
their absolute rates cannot establish a cross-build gain. All attempts and
regressions remain in the [evidence and raw archive](performance/vlang-gpu-scroll-isolated-shapes-20261105.json).

| Change | Control → candidate FPS, pair 1 | Pair 2 | Policy |
| --- | ---: | ---: | --- |
| CPU grayscale rows | 63.88 → 59.52 | 60.26 → 59.85 | Off by default |
| Linear Metal canvas textures | 37.98 → 42.65 | 41.49 → 43.74 | Opt-in; early shape-error cohort is diagnostic |
| Queued canvas uploads | 58.47 → 61.97 | 62.37 → 62.91 | Opt-in; mixed tails and falling host load |
| Isolated shape passes | 81.95 → 84.03 | 65.79 → 84.08 | Default on |
| Combined linear textures, queued uploads, direct readback | 85.26 → 81.98 | 84.12 → 86.56 | Opt-in; both maximum gaps regress |
| GPU video-backdrop restore | 84.06 → 81.77 | 74.98 → 87.55 | Opt-in; mixed result |

Isolated-shape p95 changes 28.97→26.90 and 41.21→26.27 ms; maxima change
111.10→94.72 and 105.19→96.31 ms. The first median regresses 8.56→9.24 ms,
and the controls vary materially. Candidate peak guarded process-tree RSS is
2,147/2,318 MiB; all browser and guard exits are zero. These results support
the default change while leaving the smoothness target open. A separate profile
still finds synchronous readbacks around rounded-shape replay, retained row
copies and frame preparation.

`6a79e1871` adds opt-in `VOX_GPU_CANVAS_VIDEO_BACKDROP=1`. A capable host can
restore cached RGBA rows directly on the GPU before drawing the video, keeping
the pending frame off the CPU. A per-frame callback handshake preserves older
hosts; captures and failed copies retain the CPU barrier and ordinary fallback.
Tests cover odd widths, alpha, source eviction, legacy hosts, failed GPU copies
and the verification path. Focused error is at most one level; live verification
has 1,042 records, 14 input-window GPU restores and maximum error three. The
unprofiled eligibility run also observes actual GPU restores during input.
Its mixed paired results do not justify enabling it by default.

`inline-node`, `canvas-text` and same-size SVG source switching pass their
unchanged installed-bundle bounds; the SVG case remains pixel-exact. The first
screenshot workflow overlaps a script edit and logs a shell parsing error despite
returning zero, so it is rejected. The committed-script rerun pins the executable,
libraries and scripts, observes no changed inputs, and completes without errors.
`bb2f87162` also supplies the required V compiler memory limit in screenshot
comparisons. Earlier evidence archives remain unchanged.

### Readback and pointwise filter follow-up (2026-11-05)

Smooth 60 fps remains open. The following same-binary pairs use the live URL,
1708×953 document pixels at 2×, 600 precise delta-8 inputs at nominal 120 Hz,
private empty profiles/caches, title readiness and ten seconds of settling.
They measure changed scroll publications over the full input window, not scanout.
Every attempt, interval distribution, boundary gap, input timestamp, cache hash,
build identity and guard result is retained in
[the report](performance/vlang-gpu-scroll-readback-filters-20261105.json) and its
[raw archive](performance/raw/vlang-gpu-scroll-readback-filters-20261105.tar.gz).

| Opt-in candidate | Pair 1 publication fps | Pair 2 publication fps | Decision |
|---|---:|---:|---|
| Compact clipped filter input | 78.18 → 89.19 | 90.39 → 90.30 | Mixed; disabled |
| CPU grayscale on current isolated shapes | 87.39 → 87.20 | 87.35 → 89.90 | Mixed; disabled |
| Integer-texel IOSurface readback | 86.43 → 75.83 | 78.62 → 79.54 | Mixed; disabled |
| Partial GPU readback | 77.69 → 91.74 | 90.50 → 77.45 | Mixed; disabled |
| GPU video backdrop with partial readback | 86.55 → 81.50 | 83.80 → 73.75 | Both regress; disabled |
| Tight pointwise filter input | 72.68 → 73.30 | 68.52 → 69.85 | Falling host load confounds small gains; disabled |

`d565ac6dd` fixes a correctness gap: two failed GPU reads reject the replay and
disable later GPU attempts in that process. The immediate ordinary replay can
then reconstruct the missing GPU-only leaves. Forced failure and retry tests pass.

The first IOSurface implementation copied Skia image snapshots. Its live transport
check found an eleven-level error during loading and rejected the path before
scrolling. `6200f6524` replaces it with integer Metal texel reads on the same
ordered queue. Native optimized/sanitized tests cover alpha, padded rows,
overlapping damage, pending writes, lifetime and full 3416×1906 targets; live
transport checks are exact. The mixed timings keep it opt-in. Partial readback
also verifies unchanged pixels outside each proposed extent: 151 input-window
checks are exact, with 43,859,561 rather than 70,761,568 transferred pixels.

Command-boundary diagnostics identify repeated CSS filter completions near
scroll position 697. `9805d92bc` trims transparent margins for pointwise filters
with the existing integer device mapping, retaining Core Image arithmetic and
ordinary non-pointwise fallback. Both optimized and ASan/UBSan runs pass 768
exact frame comparisons, including empty/sparse input, profiles and alpha.
The live diagnostic reduces source bytes from 669,399,360 to 1,095,324, but its
timing cohort still has p95 gaps of 34.61/35.25 ms and maxima of 110.35/119.46 ms.
Host load falls through the cohort; this does not establish an isolated gain.

`40fd1d3e0` and `a76fd7d25` add opt-in command/Metal timing diagnostics. Creation
to GPU start includes encoding and submission, so it does not isolate queue wait.
The later profile also finds separate shape readbacks in the scrollbar tail.
`7f478e6b8` batches those V-owned leaves after the document ring is stored;
`VOX_GPU_SCROLLBAR_BATCH=1` remains opt-in pending live validation. Its V geometry
tests execute successfully, and 24 native variants stay within the existing
three-level GPU bound (observed two), with exact unchanged outside pixels.
Concurrent source edits temporarily supersede production builds; no other
session is stopped and older bundles do not validate the new V integration.

### Later scrollbar and layer experiments, November 5

Smooth 60 fps remains open. The direct scrollbar batch is now enabled by
`5acc85b33`: the qualifying matched pairs improved 83.01→90.62 and
76.88→88.97 scroll-changing publications/s, with p95 intervals improving
26.86→24.67 and 27.98→23.48 ms. The controls are
`VOX_DISABLE_GPU_SCROLLBAR_BATCH=1` and
`VOX_GPU_CANVAS_DISABLE_DIRECT_LAYER_SHAPES=1`. This supersedes the pending
default described in the preceding historical evidence snapshot.

The later installed-bundle repeat is mixed: 69.94→67.90 and 66.21→87.08
publications/s. Its default trials still have p95 intervals of 37.38 and
22.51 ms, maxima of 109.25 and 94.37 ms, and deadline misses of 23.27% and
11.41%. Mean rates above 60 do not establish smooth 60 fps.

All measurements below use the same live-page protocol and retain both pairs.
The native layer-publication endpoint does not establish display scanout.

| Additional candidate | Pair 1 publications/s | Pair 2 publications/s | Decision |
|---|---:|---:|---|
| Fourth pooled frame slot | 74.44→75.37 | 81.03→91.06 | Off; maximum gaps regress in both pairs |
| Native GPU raster grid | 75.50→84.36 | 83.42→72.61 | Off; mixed |
| Cached compact color-filter results | 86.50→82.57 | 86.60→89.02 | Off; mixed, few cache hits |
| GPU normal/screen opacity composites | 87.07→85.55 | 76.07→87.00 | Off; mixed |
| Reused video-backdrop textures | 73.67→84.21 | 77.66→75.94 | Off; mixed |

`1b84aab51` retains native raster-grid dimensions, origins and overlap ownership
in GPU batches. Coverage selection must precede the damage clip so that the
MSAA marker survives. Focused mixed-coverage cases stay within the existing
three-level bound; backend optimized and sanitizer checks pass. Live counters
prove the path executes during input, but its regression keeps it opt-in.

`e265cdbfe` keys an 8 MiB color-filter cache by complete pixels, profile and
operations. `b3aacd9f0` and `388cdb8a5` keep independent color-filter and
normal/screen opacity results in pending GPU batches. The actual nested native
entry points, independent blend arithmetic, source lifetime and fallback checks
are exact. The first offscreen eligibility counter mistakenly counted only
nonzero-error lines: aggregate counters show 21 exact input-window screen-group
draws, with the correction retained separately. The later diagnostic observes
16 group draws and a whole-log maximum of three levels in other GPU leaves.

`7c8c55569` reuses video-backdrop uploads with owned exact rows and bounded
texture storage. Padding changes do not invalidate them; changed pixels do.
`44453b22e` adds an opt-in exact gradient-text raster cache. Its 64 cold/warm
native cases include real glyphs, gradients, changed masks/backdrops and both
scales, but neither live input diagnostic records a hit, so it receives no
scrolling credit. An exact ARM digest experiment was removed after its
microbenchmark showed no gain.

The [machine-readable evidence](performance/vlang-gpu-scroll-layer-experiments-20261105.json)
contains 53 attempts and links a verified archive of 711 raw files: commands,
build/library identities, actual input schedules, complete interval statistics,
guard/browser exits, host load, pixels, tests and retained failures. A later
Dawn recorder experiment has separate pending validation.

### Dawn submission, font transport and scheduling follow-up, November 5

Smooth 60 fps remains open. These are two alternating live-page pairs per
candidate, using the same 1708×953 document viewport at 2×, 600 precise
delta-8 inputs at nominal 120 Hz, private empty profiles/caches, title readiness
and ten seconds of settling. The endpoint is scroll-changing native layer
publication over the entire input window, not display scanout.

| Opt-in candidate | Pair 1 publications/s | Pair 2 publications/s | Decision |
|---|---:|---:|---|
| Reused regional Dawn recorder | 89.66→90.81 | 72.05→90.05 | Off; first p95 regresses |
| Reused regional Dawn target | 89.39→92.96 | 92.13→90.51 | Off; mixed |
| Single final Dawn queue wait | 88.70→88.03 | 88.41→91.03 | Off; maxima regress |
| Owned shared font packets | 78.07→89.74 | 90.06→96.23 | Off; second maximum regresses |
| Deferred gradient-text input rasters | 79.60→90.31 | 91.19→90.82 | Off; second pair regresses |
| Compatible GPU flags combined | 87.31→75.95 | 88.22→89.92 | Off; mixed |

Candidate p95 intervals remain about 21–28 ms. The combined experiment reaches
a 164 ms maximum. Mean rates above 60 do not establish smooth scrolling;
variation and host contention also limit attribution. Separate diagnostics
confirm the proposed rendering paths execute during input and retain the
existing three-level pixel bound. Native optimized and sanitizer tests cover
font packet ownership, old-backend fallback, exact glyph output, deferred-input
failure and transactional replay.

`790294447` fixes an independently reproduced shutdown fault: detached HTTP
workers could read the prealloc arena after its exit cleanup freed it. The
browser keeps that arena alive until process termination; ordinary document
and worker retirement remains active. A real pthread fixture reproduces the
unprotected fault and passes five fresh normal exits with the browser policy.
Subsequent live cohorts terminate normally.

The expired-timer coalescing and parallel readback diagnostics complete all 600
inputs but find zero eligible input-window work, so neither proceeds to timing
pairs. Existing parallel jobs use at most two lanes, below the experimental
four-lane cap. Large row conversion is faster in a conversion microbenchmark,
but those copies occur during startup on this page and earn no scrolling credit.

The [evidence report](performance/vlang-gpu-scroll-dawn-20261105.json) retains
all pairs, interval distributions, deadline misses, boundary gaps, actual input
timestamps, host load, identities, test outcomes and failed attempts. Its
[verified raw archive](performance/raw/vlang-gpu-scroll-dawn-20261105.tar.gz)
also preserves the failed exit diagnostics and lossless compiler-input archive
receipts used to recover disk space. Earlier evidence archives are unchanged.

### Retained copies and pointwise filter follow-up, November 5

Smooth 60 fps remains open. The same live native-input protocol gives these
two alternating pairs; all candidates remain disabled.

| Candidate | Pair 1 publications/s | Pair 2 publications/s |
|---|---:|---:|
| Omit retained copies inside large opaque damage | 91.17→89.98 | 91.35→88.48 |
| Admit smaller opaque damage | 88.10→86.69 | 83.01→84.89 |
| Skip transparent pointwise input, prototype scan | 91.21→90.22 | 90.32→92.11 |
| Skip transparent pointwise input, final scan | 88.20→81.63 | 89.60→77.86 |
| Software Core Image for small pointwise input | 88.83→85.13 | 87.65→79.93 |

`f1d9219c9` requires an explicit opaque-clear promise before omitting retained
pixels wholly inside damage. Fractional clip edges retain their original bytes.
`afdd58f96` admits smaller damage: its input diagnostic confirms 107 reduced
copies and 247,077,552 omitted bytes, but timings remain mixed. Optimized and
sanitizer tests cover overlapping damage, direction changes, ring wraps,
padded rows, fractional edges and callers without the clear promise.

`a7c527b83` skips a pointwise filter only when its visible input is transparent
and no GPU or speculative pixels are pending. The prototype diagnostic finds
25 input-window skips and lower maxima in both pairs, but means are mixed and
p95 slightly regresses. The final-code repeat also regresses; a focused native
verification job overlaps its second candidate, so that cohort supplies no
optimization acceptance. All attempts are retained.

`83d423923` selects software Core Image for bounded pointwise inputs, preserving
the existing graph and color management. `25f59dac8` separately compares each
selected output with GPU output from the same input. All 106 live input-window
comparisons are exact. Optimized and sanitizer corpora each compare 1,536 real
frames exactly, including 672 software draws, plus cache and ownership checks.
The first expanded fixture exceeded the unchanged 3 GiB guard because comparison
buffers survived across cases; per-case autorelease pools fix that fixture.
Both live timing pairs regress, with candidate p95 intervals of 24.86 and
28.19 ms, so software selection remains off.

The [evidence report](performance/vlang-gpu-scroll-filter-copy-20261105.json)
and [verified raw archive](performance/raw/vlang-gpu-scroll-filter-copy-20261105.tar.gz)
retain exact build/library identities, input schedules, whole-window rates,
intervals, misses, gaps, host load, diagnostics, tests and failures. Native
publications remain distinct from physical display scanout. `69c332f7e` adds
separate filter-stage timing diagnostics; those supply no unprofiled credit.
