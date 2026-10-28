# 4chan catalog comparison

The controlled catalog replay now matches Brave exactly: **zero differing
pixels across 21 native viewport comparisons, totaling 65,620,992 pixels**.
This covers the full 14,457 CSS-pixel document in 19 successive 1024×768
viewports, plus 800×600 and 1280×768 captures, all at native scale 2.
Every comparison includes the complete viewport and exact RGBA equality.
Unmodified live Brave parity remains unestablished because its advertisement
filter policy differs from Vox's; the controlled replay applies the same
explicit cosmetic rule in both browsers.

## Completed candidate and comparisons

The 12 catalog source copies under `Build/` were removed on 2026-10-28 after
verifying that the completed fixes and tests are on `master`. Historical
build receipts, comparison results, generated test inputs, and the installed
browser remain; the old source paths in those receipts are no longer available.
The cleanup audit is in `Build/4chan-catalog-source-cleanup-20261028/`.
The installed executable still loads 13 data files through an old absolute
path, so that location retains only symlinks to the canonical data files.
No source files or build outputs remain in those copies. The executable and
native libraries retain their hashes, and a fresh headless smoke check passes
under the 3 GiB guard (`smoke-guard-2.json`, exit 0).

`Build/4chan-catalog-20261028-catalog-production-4/device.app` is the signed,
validated browser. Its executable SHA256 is
`e630a5941e905ab8f8609d5daf56ce60b39964d92e29c26e19fad5dd913bf49c`.
The pinned native library hashes are:

| Library | SHA256 |
| --- | --- |
| libLadybirdVSkiaText.dylib | `d90dc54a7b744d885210d60cac91b40612585f2d8612b4f50df94e18bec37b2b` |
| libVoxGraphite.dylib | `9d884d01248c1760d0b3dffb17a761ae199ac992d23ae540d277d56e68b6421b` |
| libVoxGraphiteDawn.dylib | `cb98233f4dd44223964522e972655d739d701da23ddf0a3a4fc794c8722b9b52` |

Compilation, linking, signing, signature verification, startup smoke and the
frozen-source identity check pass. `skia-guard.json` records child exit 0,
a 6,005,538,816-byte sampled aggregate peak under the unchanged 12 GiB budget,
and 168.655 seconds for the corrected native compile/package/smoke sequence.
The generated V C source is retained unchanged with SHA256
`5615e2699af7998e0e5c46f7bb0a8ed34dac86d00ba678105c0af6ac3d6040bd`.
This build contains the compact select clipping fix, collapsed-space shaping
and complete root shadow tile changes described below. Its frozen source
receipt defines the validated candidate; later changes in shared `master`
are outside this build's validation.

`catalog-pixels-6/candidate-scroll-pixels.json` records zero differences at
CSS offsets 0, 768, 1536, 2304, 3072, 3840, 4608, 5376, 6144, 6912,
7680, 8448, 9216, 9984, 10752, 11520, 12288, 13056 and 13689.
`candidate-scroll-coverage.json` verifies complete coverage, including the
footer. Every row compares 3,145,728 native pixels. `viewport-results.json`
adds exact 800×600 and 1280×768 comparisons. Each capture uses a fresh process,
an empty private profile and the display away from the pointer; receipts pin
executable/library identities, successful exit, complete document readiness,
201 threads and matched viewport/scroll geometry.

The independent Brave reference is 156.1.98.60 (Chromium 156.0.8078.48).
Its executable SHA256 is
`9d53e182ab59b7c430abea0233088cb452694b96843d62ccccbc6c0902b98fe5`;
framework SHA256 is
`f3c180e20cb50e055e3e4279e4663d79b457ede64f4d2f38e5b58cd92dbf6971`.
`catalog-pixels-4/fresh-reference/results.json` records unchanged identities
through all 19 reference captures and exact fresh repeats of the first and
last viewports. The candidate never supplies reference pixels. The archive
preserves the 200 original JPEG bodies byte for byte in data URLs and freezes
animated GIF frames, as explained below; network delivery and changing live
threads are outside this oracle.

`Build/4chan-catalog-20261028-catalog-acceptance-1/acceptance.json` aggregates
41 exact comparisons, verifies retained image hashes and fresh-process
identities, and records `strict_controlled_catalog_pixels_pass: true`.
Its separate 3 GiB guard exits 0 with a 129,302,528-byte sampled peak. The
original `catalog-pixels-6/` pipeline exits 1 against older select/text
references and a historical canvas capture; its failures remain intact.
The final acceptance receipt uses independently repeated fresh references
and a fresh matched canvas baseline rather than accepting those nonzero
comparisons or introducing a tolerance.

## Installed browser and live navigation

The validated production-4 bundle is installed at `Build/v/Vox.app` with the
executable and library identities above. The installation verified final
acceptance first and atomically exchanged bundles with `renameatx_np`;
`catalog-live-4/installation.json` retains both identities and the preserved
previous production-2 bundle. No additional production build was scheduled.

Two fresh installed-browser processes, PIDs 70572 and 80606, retain unchanged
production-4 identities but reach a navigation error on the direct live URL:
`h2: request timed out waiting for a response after 10.000s`.
The capture processes exit 0, while both live validation jobs correctly exit
1 after rejecting the error title. Their screenshots and guard receipts
remain in `Build/4chan-catalog-20261028-catalog-live-{4,5}/`.
These runs do not establish successful live loading or live rendering parity.

A direct HTTP HEAD returns 200 promptly, but this does not establish body
delivery. HTTP/1.1 and HTTP/2 compressed GETs in `catalog-live-4/` time out
with incomplete bodies. The longer direct HTTP/2 retry in
`catalog-live-5/direct-get.json` receives HTTP 200 and 21,877 compressed bytes,
then exits curl 56 after 31.449 seconds with a receive timeout. None of those
partial bodies is used as a valid replay or screenshot reference. The browser
has an explicit ten-second read timeout in `browsernet/http.v`; these results
do not identify the cause of the slow live transfer or justify a rendering
change. Earlier successful live navigation and the advertisement-slot policy
difference remain historical evidence below, not validation of this build.

An independent fresh Brave process on the same direct route also fails with
`net::ERR_TIMED_OUT`; `catalog-live-5/brave-direct/` preserves its command,
unchanged executable identity, log and guard exit 1. Its sampled process-tree
peak is 894,369,792 bytes under a 3 GiB budget. This provides no live screenshot
or parity credit and leaves the live check pending a successful transfer.

## Select clipping and reference checks

Commit `beb097d4` restores the compact select label's missing `overflow: clip`,
matching the persistent UA shadow label and upstream
`Libraries/LibWeb/HTML/HTMLSelectElement.cpp`. Retained display-list tests
compare label clips before and after shadow-tree creation. Seven focused
select cases compile and pass in default GC and `-gc none` under the memory
guard in `Build/4chan-catalog-20261028-select-clip-1/`.

The focused `select-label-ink-clip` fixture covers half-pixel origins,
glyph overhang, narrow labels, RTL and a borderless `appearance: none` control.
Two independent Brave captures agree exactly; the corrected browser matches
all 1,920,000 native pixels. The pre-fix production-3 browser differs at 1,179
pixels. The original broader probe used a 20.3828125px vertical origin and
an unstyled `appearance: none` border. Its 876 residual pixels expose separate
fractional text-phase and default-border/auto-height differences; that probe
and both failures remain in `catalog-pixels-6/` and `catalog-acceptance-1/`.
Narrowing the committed fixture isolates clipping and does not credit a fix
for those other cases.

The existing `chromium-select` fixture also matches two fresh independent
Brave captures exactly. Its older reference differs at 253 pixels and is
preserved in the run; the committed reference is refreshed from Brave.
Both collapsed-space text lines match two fresh Brave captures exactly;
the old text oracle differs at 4,101 pixels. Fresh captures repeat without
changing Brave executable/framework identity. The reason those older
references differ is unresolved; no source change or tolerance is inferred
from that difference.

All ten SVG image/mutation checks pass pixel-exactly. Ten of eleven default
smoke outputs equal the retained historical baseline exactly. The remaining
canvas output differs from the historical capture at 221 pixels, but a fresh
production-2 baseline and candidate are pixel-identical; a second candidate
capture also agrees exactly. Canvas passes the smoke suite's existing
allowance. The smoke suite still exits 1 for `inline-node`, `ordered-list`
and `text-decorations`; those three actual images remain identical to the
retained baseline. No all-tests-passing claim is made. The scale-2 shadow
fixture matches Brave exactly; the scale-1 diagnostic preserves the same
1,424 differences in baseline and candidate. Broad package failures and
incomplete batches remain recorded below; the AST corpus passes 100/100.

## Build recovery evidence

The first production-4 link exposed ICU 78/79 header and runtime mismatches;
the retained generated C and case-mapping helper now use explicit ICU 78
linkage. A packaging attempt copied stale cached native libraries, and the
next attempt revealed that the frozen stage lacked its upstream `3rd`
symlink. This omitted the `LADYBIRD_V_HAS_SKIA_TEXT` and
`LADYBIRD_V_HAS_FFMPEG` native defines and the Skia text link. The resulting
fallback-renderer screenshots in `catalog-pixels-4/` and `catalog-pixels-5/`
are failed build evidence and supply no code validation credit. Actual
interruption/guard exits and invalid bundles remain preserved.

The corrected guarded native compile reuses the unchanged retained generated C,
restores the production defines and validated native-library identities, and
saves its main object separately. This avoids another V generation pass or
compiling over a live bundle. Earlier completed comparisons below remain
historical evidence and do not override the current strict result.

## Historical line-end production comparison

The following identity and initial result tables describe
`Build/4chan-catalog-20261027-line-end-production-2/`. Later production-3
results and broad-suite limitations appear at the end of this report.

## Completed browser and identity

The executable SHA256 is
`50e51b22af450c761c6b82db2cc67e76a04422af7b619f15f1d620c0c9e70163`.
`results.json` records the native library hashes, successful signing, startup
smoke, installation into `Build/v/Vox.app`, and unchanged frozen source,
capture scripts, and executable/library identity throughout the comparisons.
The pinned copy is `device.app` in the run directory. The earlier `label-2`
bundle cannot validate the subsequent fixes.

The retry preserved generated C and the exact native compiler command, exited
V, and then compiled the native executable separately. This avoided the
overlap that exceeded the memory budget in the earlier production attempt.
`guard.json` records a 9,456,959,488-byte sampled process-tree peak
against the unchanged 12 GiB budget. The overall check exits 1 because visual
acceptance fails; the native compiler, signing and smoke each exit 0.
The intentional compiler deferral exits V before native compilation and is
recorded separately from compilation success. Earlier failed attempts remain
in their original directories.

## Executed pixel results

The historical `final-1/` results below predate the line-end change. These
compare every pixel without a tolerance. The replay freezes animated
GIFs and explicitly hides `.danbo-slot` in both browsers to match Vox's enabled
EasyList policy. This controlled oracle does not establish parity with an
unmodified live Brave page.

| Comparison | Differing pixels | Total pixels |
| --- | ---: | ---: |
| Initial catalog, logical pixels | 1 | 786,432 |
| Initial catalog, native pixels | 7 | 3,145,728 |
| Catalog at 800×600, native pixels | 0 | 1,920,000 |
| Catalog at 1280×768, native pixels | 5 | 3,932,160 |
| Precision fixture, native pixels | 0 | 1,920,000 |
| Teaser fixture, native pixels | 0 | 1,920,000 |
| Transformed shadow fixture, native pixels | 19,277 | 1,920,000 |
| Select fixture, unchanged bundle retry | 0 | 1,920,000 |

The final run's select capture timed out in the Brave websocket handshake.
The unchanged select retry in `Build/4chan-catalog-20261027-filter-ready-1/`
passed with fresh Vox PID 37915, exit 0, and the same executable/library hashes.
`Build/4chan-catalog-20261027-acceptance-retry-1/` combines that receipt with
unchanged final-run results. Its `strict-pixel-acceptance.json` reports false;
no nonzero result is accepted as pixel exact. The original infrastructure
failure remains in the final run's log.

`scroll-coverage.json` establishes complete coverage of the 14,457-pixel document
through all 19 viewport offsets. Every row below compares 3,145,728 native pixels.

| Scroll offset (CSS pixels) | Differing pixels |
| ---: | ---: |
| 0 | 7 |
| 768 | 8 |
| 1536 | 6 |
| 2304 | 25,908 |
| 3072 | 3,873 |
| 3840 | 4 |
| 4608 | 26,022 |
| 5376 | 1,502 |
| 6144 | 1 |
| 6912 | 1,047 |
| 7680 | 1,897 |
| 8448 | 1,409 |
| 9216 | 4 |
| 9984 | 33,846 |
| 10752 | 1,035 |
| 11520 | 1,912 |
| 12288 | 4,217 |
| 13056 | 1,342 |
| 13689 | 4 |

The scrolling canvas-background fix is now exercised by the browser: the
previous 476,731 and 706,206 differences at offsets 768 and 1536 drop to 8 and
6. In these historical captures, remaining scrolled differences concentrate
in thumbnail interiors, teaser text and shadow edges. The later checks below
isolate JPEG delivery and validate the line-end correction.
The seven initial differences are each one blue-channel unit at shadow corners.

The transformed shadow fixture remains unchanged: normal, rounded and offset
regions match, while half-scale, double-scale and rotated regions differ by
952, 17,364 and 961 pixels respectively. Standalone transparent/opaque raster
probes provide diagnostic samples, not proof of a browser compositing fix.

## Live Brave and filter limitations

`device-live-run.json` records fresh Vox PID 19724, exit 0, and unchanged build
identity. The live catalog reached its expected title, complete readiness,
over 100 threads and decoded thumbnails. This establishes live document loading,
not live screenshot parity.

Both live Brave comparisons retain a 728×90 advertisement slot, while Vox's
EasyList cosmetic rule hides it. The initial board navigation, title, post-form
link and blotter geometry match; the controls and threads in Brave start
103.3359375 CSS pixels lower. `live-geometry.json` reports geometry failure.
`default-brave-live-geometry-corrected.json` resolves the default capture's
classes from its retained raw rectangle rows, including elements that also have
IDs; the original report and raw evidence remain intact. It also reports failure.

Copying seven signed public filter components into fresh profiles did not
reproduce the ad-hidden oracle, even with default component registration
enabled. Both component probes differ at 882,138 native pixels. Their archives
retain identical frozen assets and differ from the controlled oracle only by
removing the explicit cosmetic style. No personal browsing profile was copied.
The separate filter-readiness probe in
`Build/4chan-catalog-20261027-filter-ready-1/` also retains the ad slot after
reload: both its initial and reloaded captures differ at 882,138 pixels.

## Focused checks already executed

The option-label mutation hook, fractional shadow-color transport,
device-scaled shadow cutout, and scrolling canvas-background changes passed 31
focused runtime tests in `Build/4chan-catalog-20261027-background-1/`, plus four
native cache tests. The runtime receipt records exit 0 under the 3 GiB guard.
Legacy comma-separated `rgba()` alpha rounding passed its parser-to-paint
focused runtime check under the same limit in
`Build/4chan-catalog-20261027-alpha-1/`. Modern space-separated alpha retains its
fractional value. The completed production comparisons above now exercise
these changes together; they do not meet strict catalog acceptance.

## Wrapped line-end shaping (d68a3cf9)

A discarded wrapping space retained its preceding letter's HarfBuzz kerning.
This shifted centered teaser lines and could accept a word that overflowed
once the line boundary was reshaped. Chromium-policy line measurement and
painting now reshape the supported exposed boundary, preserving spacing and
retrying the previous word when necessary. Preserved whitespace keeps its
original context; ambiguous clusters, fallback faces and bidi remain outside
this existing context-shaping scope.

`Build/4chan-catalog-20261027-line-end-3/` records 28 focused tests passing in
both default GC and `-gc none`, with actual compile/runtime exits 0. The shared
12 GiB guard exits 0 at a sampled 8,471,805,952-byte peak. The companion
`line-end-glyphs-2/` comparison matches Brave's text and horizontal origins for
all 79 teaser lines and 14 narrow-width lines, without tolerance. These are
layout diagnostics. The completed `line-end-production-2/` run also matches
both complete teaser and narrow-width screenshots exactly: zero differing
pixels out of 1,920,000 native pixels in each. The signed browser, startup
smoke and unchanged-source/identity checks pass. Catalog comparisons against
the earlier delivery-dependent references still fail, including seven initial
shadow pixels. Its overall guard correctly exits 1.
The first production attempt failed before compilation because its frozen
checkout lacked compiler/dependency links. Those links were restored without
changing the frozen V sources; its failed receipt remains intact.

This is fix 10/10 after broad baseline `f2e223c9`. The full affected package
batches, full LibJS AST corpus, default screenshot smoke set and broad SVG
checks run in `Build/4chan-catalog-20261027-broad-2/` and the completed
production run. All ten SVG cases pass exactly. Seven default smoke cases
pass exactly and canvas text passes its existing allowance; `inline-node`,
`ordered-list` and `text-decorations` fail. The first layout batch compiles in
both GC modes but fails the same three test functions in each: two active-state
cases and one Chromium inline-block baseline case. Separate checks against the
pre-line-end browser in `line-end-baseline-1/` reproduce all three failed
smoke images exactly: zero baseline-to-candidate differences. Its separate
two-file unit binary compiles but crashes with exit 139, so unit-test causality
remains unresolved. The second broad layout batch stops at a syntax error in
`compositor_phase_cache_test.v:71`; the other package batches and full AST
corpus continue separately and remain pending.
The original broad attempt failed its first compilation on
the missing dependency include path and executed no test cases. The counter
has **not** reset. No JPEG or shadow fix is credited by this change. Strict
pixel-perfect catalog acceptance remains false.

## JPEG delivery and reference repeatability

`Build/4chan-catalog-20261027-jpeg-stream-1/` isolates one unchanged 250×140
JPEG (SHA256 `4f1375a064c91fb43b4a40a6e66ea1eeb0b2be816438658dd057cdad134dc75e`).
Fresh Brave processes receive either the complete body immediately, or all
but the final two EOI bytes followed by a two-second pause. The scaled target
thumbnail differs at 20,055 native pixels between these delivery schedules.
The complete-body result matches the isolated Brave and Vox result; the
delayed-body result matches the earlier catalog reference exactly. An
independent catalog capture differs from that old reference at 20,127 pixels,
of which 20,055 are inside this thumbnail. That oracle is not deterministic
with respect to JPEG delivery timing.

Chromium 156's JPEG decoder selects its YUV path only when all bytes arrive
before decompression starts. The complete delivery and incremental delivery
therefore exercise different decode paths. The corrected `rgba-all.html`
control replaces all six JPEG image elements with the same decoded PNG;
`complete-jpeg-2/rgba-control.json` reports an exact whole-image match to the
delayed JPEG result. The earlier `rgba.html` replaced only the first image
and cannot establish a PNG comparison for the other five regions.

`Build/4chan-catalog-20261027-complete-jpeg-2/` preserves all 200 archived
JPEG bodies byte for byte in data URLs, ensuring complete input before either
browser starts decoding. Its manifest records every original URL, body hash
and byte count. The controlled document hash is
`4777d0e59c714666f6c507a1d0ef146bbe5a11ca8f0df9f518e0c2ee57b087b0`.
Two fresh Brave captures at offset 2304 match every native pixel. The command
and runtime guard both exit 0; the sampled peak is 1,000,161,280 bytes under
the 3 GiB limit. The signed line-end production browser then compares against
this repeatable oracle under a separate 3 GiB guard (746,864,640-byte peak).
Each row compares 3,145,728 native pixels without tolerance:

| Scroll offset (CSS pixels) | Differing pixels |
| ---: | ---: |
| 0 | 7 |
| 2304 | 3 |
| 3072 | 4 |
| 4608 | 2 |
| 9984 | 3 |

The strict candidate command and guard exit 1. Complete 19-viewport coverage
is running separately in `complete-jpeg-full-1/`; these five offsets alone
cannot establish whole-document parity. This changes fixture delivery, not
image pixels, and provides no claim about parity under uncontrolled live
network delivery.

The blur investigation also records the exact Skia revision from Chromium
156's DEPS (`886e42fda11610a56dd1b22e8697e27f9d1e34f2`), which differs from
the compatibility library pin (`29ed1e87a0a50f3d8347e988842d9d59e7573efa`).
The rectangle blur shader and its integral-table implementation are unchanged
in the inspected sources. The revision difference alone does not establish
the cause of the seven remaining initial shadow pixels.

`shadow-pipeline-1/` replaces only the pinned baseline's local Metal library,
then verifies that diagnostic mode 0 reproduces every previous Vox pixel.
Opaque black plus a source-in color filter, forced multisampling, and both
together all preserve the same seven one-unit blue differences. The separate
`shadow-dawn-1/` library repeats this result with Dawn, including both options.
All browser launches and both diagnostic guards exit 0; neither diagnostic
credits a fix or accepts the nonzero pixel result. These older executables
supply shadow baseline evidence only. The color-filter, multisampling and
backend changes do not solve this discrepancy; no raster-library update is
justified by this source comparison.


## Collapsed whitespace and root shadow tiles

The complete deterministic baseline in
`Build/4chan-catalog-20261027-complete-jpeg-full-1/` covers all 14,457 CSS
pixels of document height with 19 overlapping 1024×768 viewports at scale 2.
Every comparison includes all 3,145,728 native RGBA pixels, without tolerance.
The nonzero counts at offsets 0, 768, 1536, 2304, 3072, 3840, 4608, 5376,
6144, 6912, 7680, 8448, 9216, 9984, 10752, 11520, 12288, 13056 and 13689
are respectively 7, 8, 6, 3, 4, 4, 2, 5, 1, 1047, 3, 3, 4, 3, 2, 4,
1558, 2 and 4. The large differences include 1,042 text pixels in the
“Altman. The core” line and 1,554 in “France, They completely”.

Commit `37a307eb` collapses consecutive spaces before Chromium context
shaping. Previously the iterator collapsed them after shaping, losing the
kerning between the remaining space and the following `T`. A UTF-16 source
map restores discarded source spans as invisible, zero-advance glyphs,
retaining DOM offsets and the following glyph's boundary kerning. Preserved
whitespace bypasses this mapping. Unsupported clusters still fall back to
the existing shaping path.

`Build/4chan-catalog-20261027-collapsed-context-1/retry-guard.json` records
31 focused cases passing in both default GC and `-gc none`, with actual
compile and runtime exit codes zero. Its sampled aggregate peak is
8,437,645,312 bytes under the default 12 GiB budget. The initial disk-full
attempt remains recorded and supplies no passing credit.

The separate `shadow-tiles-1/retry-guard.json` diagnostic isolates ten
catalog shadow descriptors. Rendering each in a complete 2048×416 root
raster tile, then extracting its affected pixels, eliminates every sampled
shadow difference. The preceding tightly cropped surfaces retain seven
initial one-level blue errors. This diagnostic excludes content pixels and
therefore does not establish whole-image acceptance. The candidate native
bridge uses the existing root raster grid to preserve the complete render
target extent and tile-relative transform; independent layers retain their
existing path.

`catalog-production-3/` successfully builds, signs and starts the frozen
candidate containing both changes. Its guard and startup smoke exit zero,
with a sampled 9,415,901,184-byte aggregate peak. Executable SHA256 is
`18ed315192d7be1bbc3a6c0f16a4a710cc664dc3f126c897e0413fff96ceddf9`;
`libLadybirdVSkiaText.dylib` SHA256 is
`d90dc54a7b744d885210d60cac91b40612585f2d8612b4f50df94e18bec37b2b`.
The source identity check passes. `catalog-pixels-3/` completes all 19 native
catalog comparisons: 18 are exact, while offset 13689 retains one differing
pixel (PNG x=1890, y=1293, white in Brave and one gray level in Vox).
Two fresh matched captures in `catalog-bottom-repeat-1/` reproduce that pixel.
The text-line oracle, scale-2 shadow fixture, and ten SVG checks are exact.
All 11 default smoke outputs equal the retained baseline, including its three
known reference failures. The scale-1 shadow diagnostic still differs from
Brave at 1,424 pixels in both builds. These are preserved failures, not parity
credit. The strict catalog run correctly exits 1.

The broad batch remains at 10/10. `broad-2/` exceeds the aggregate memory
limit during its third layout compilation (13,028,900,864 sampled bytes),
after the earlier runtime and syntax failures described above. `broad-3/`
retains the same 1,037 test files in smaller batches and separates V code
generation from native compilation under the unchanged guard. Executing the
first three retained layout binaries in both GC modes reproduces six failing
assertions: two active-state invalidation cases, a nested flex baseline,
a text-control baseline, retained compositor geometry, and device-scaled
control width. `repaired-runtime-results.json` records the actual binary
identities and runtime exits; earlier missing-output and directory-collision
failures remain in their original receipts.

The next batch fails compilation on geometry-helper type mismatches and a
scratch-scope nil comparison. A later compilation exceeds the unchanged
12 GiB budget at 12,908,019,712 sampled bytes and stops the scheduler. The
remaining package batches are not claimed as executed. The separate full
upstream AST comparison subsequently passes all 100 cases with no overrides;
`ast-results.json` and `ast-resume-guard.json` record compile/runtime exits 0
and a 682,475,520-byte sampled peak. The broad suite remains incomplete and
failing; no cadence reset is made.

Brave's documented Standard Shields policy applies cosmetic filtering to
third-party elements, while Aggressive mode also permits first-party
cosmetics. This supplies a policy explanation for the live advertisement
slot difference; it is not evidence of a layout defect. See the official
[web compatibility policy](https://brave.com/privacy-updates/9-web-compat-blocking/)
and [cosmetic filtering explanation](https://brave.com/privacy-updates/2-third-party-cosmetic-filtering/).
No per-site rendering override or default filter-policy change is part of
these fixes. The controlled replay uses the same explicit cosmetic policy
in both browsers. Uncontrolled live pixel parity remains unestablished.
