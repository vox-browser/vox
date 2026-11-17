# Optimized sites

Recorded workloads where Vox uses fewer CPU instructions than Brave. These
macOS comparisons cover browser startup through a completed document capture;
fewer instructions measure CPU work, rather than elapsed rendering time.
Results apply to the frozen page and pinned build in each linked report.
Provisional entries retain unresolved acceptance checks.

**Pixel recheck, 2026-11-16:** The six available frozen catalog workloads were
verified against their archived Brave references in production `93adced1`: **CNN, GitHub, Hacker News,
Lobsters, Wikipedia and Vlang.io are zero pixels twice each**. Catalog-wide
acceptance remains open. Old Reddit's 2026-11-04 catalog fixture is missing; a fresh
anonymous Brave navigation to `/r/programming/` redirects to a blocked login
page, with no posts. CNN's historical source/replay verification also remains
open. These frozen checks establish no live-site or performance acceptance.

**Uniform PNG follow-up:** a new independently repeated Brave control is now
exact with half/double scaling and mixed tile sample counts. Its published
baseline has 1,412 differences; scale folding, own-clip planning, destination
geometry and retained decode history together reduce that to **zero twice**.
All **57 workloads/114 captures** repeat; all 56 prior PNGs are unchanged.
All 30 focused tests pass. Production `93adced1` now confirms `40d8c41ed`:
58 workloads/116 captures repeat, preserving all 57 prior diagnostic PNGs. See the
[PNG follow-up](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#uniform-png-scales-decoded-frame-history-and-elliptical-geometry-2026-11-16).

**Expanded forum/news recheck:** fresh full-uBO Brave references agree for
BBC, The Guardian and The Verge and match their saved source PNGs. Production
`93adced1` differs by **32,482**, **425** and **262,012** pixels respectively.
`4924a3389` reduces BBC to **23,822** in diagnostics by retaining odd-height WebP
chroma; its public control improves **17,320→0**. All 59 diagnostic workloads/
118 captures repeat, with all 58 prior PNGs unchanged. Guardian also has a non-repeating diagnostic failure (208,511/205,681 pixels),
retained separately; its archive has no simple VP8 WebP images. These additional
sites still need production confirmation. See the [expanded audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-png-fix-and-expanded-forum-coverage-2026-11-16).

**SVG shadow follow-up:** `0dd8f7f65` reduces the isolated Verge logo from
31,489 to **14 pixels twice** and the complete frozen page from 32,035 to
**14,916 twice**, with maximum channel error two. BBC and Guardian remain exact
in both diagnostic captures. All **72 workloads/144 captures** repeat, with all
69 other prior PNGs unchanged. Newly published production `0cae86c8` repeats
the 14,916-pixel Verge baseline, but lacks the final geometry-enclosure guard.
Remaining pixels, that guard's production check and live acceptance stay open.
See the [local SVG filter audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-local-svg-drop-shadows-2026-11-16).

**Rectangular shadow follow-up:** `da4e91d4f` reduces the complete frozen
Verge viewport from 14,916 to **eight pixels twice**, with maximum channel error
one. BBC and Guardian remain exact in both captures. All **74 workloads/148
captures** repeat, preserving all 72 prior PNGs. The isolated card improves
18,935→1; a new fractional scaled control remains inexact. Production `0cae86c8`
lacks this fix; the coalesced rebuild and production checks remain pending.
Pixel-perfect catalog and live-site acceptance remain open. See the
[rectangular shadow audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#analytic-rectangular-shadows-on-verge-2026-11-17).

**Verge merge follow-up:** `b2f198209` matches Skia's image-filter backing
allocation and transparent merge border. The complete frozen Verge viewport is
now **zero pixels twice**, down from eight; the isolated logo and SVG rectangle
also reach zero. BBC and Guardian remain exact. All **74 workloads/148 captures**
repeat, preserving the other 72 PNGs. Production confirmation and live-site
acceptance remain pending. See the
[merge audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-svg-merge-allocation-and-transparent-borders-2026-11-17).

**Slashdot invalidation follow-up:** `df849839c` refreshes stale rule plans
before procedural marker attributes change. Frozen Slashdot improves
**232,234→41,281 pixels twice**; it remains inexact. BBC, Guardian and Verge
remain zero twice, and all **74 workloads/148 captures** preserve their previous
PNGs. Newly completed production `cd9930f9` now confirms the preceding Verge
fix at zero twice, but lacks the new invalidation fix. Its production check,
remaining Slashdot layout/image differences and catalog-wide acceptance stay
open. See the [invalidation audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-procedural-filter-invalidation-2026-11-17).

**Slashdot spacing follow-up:** `07adc126d` keeps nonempty zero-height lines
from collapsing margins. The second story now matches Brave's position, reducing
**41,281→2,325 pixels twice**. BBC, Guardian and Verge remain zero twice; all
**74 workloads/148 captures** preserve prior PNGs. Transparent image sampling,
other isolated pixels and production/live checks remain open. See the
[zero-height line audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-zero-height-line-margins-2026-11-17).

**Slashdot alpha-image follow-up:** `137b739ef` samples uniform near-native
lossless WebP alpha images from their retained premultiplied rows. Frozen
Slashdot improves **2,325→429 pixels twice**. BBC, Guardian and Verge remain zero
twice, and **75 workloads/150 captures** preserve all 74 prior PNGs. The new image
control improves 2,440→471 pixels, with maximum channel error one. Remaining text
shadow/edge differences and production/live checks stay open. See the
[alpha-image audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-transparent-lossless-webp-sampling-2026-11-17).

**Slashdot shadow-alpha follow-up:** `891fe707b` applies retained glyph-shadow
opacity once. Frozen Slashdot improves **429→390 pixels twice**. The opacity
property passes, while the new shadow fixture remains inexact at 4,083 pixels.
All **76 workloads/152 captures** preserve the 75 prior PNGs; BBC, Guardian and
Verge remain zero twice. Glyph-mask/blur differences and production/live checks
stay open. See the [shadow opacity audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-retained-shadow-opacity-2026-11-17).

**Slashdot glyph-shadow follow-up:** `12924db35` matches per-glyph mask filtering,
coverage and alpha blending. Frozen Slashdot improves **390→12 pixels twice**;
the twelve-case public shadow control improves **4,083→zero twice**. All
**76 workloads/152 captures** repeat, preserving the other 75 PNGs. Both request
streams pass; BBC, Guardian and Verge stay zero twice. Production `8dbf43a2`
confirms those three news pages at zero and repeats Slashdot's earlier 206-pixel
prototype; final production, remaining edge pixels and live/catalog acceptance
stay open. See the [glyph-mask audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-per-glyph-shadow-masks-2026-11-17).

**Slashdot viewport-clip follow-up:** `2d65e5d97` retains SVG background viewport
clips in GPU replay, reducing frozen Slashdot **12→10 pixels twice**. All
**77 workloads/154 captures** repeat, preserving all 76 prior PNGs. The logo
region is exact and 9,720 outside-viewport samples pass; the new whole control
remains inexact at 18 interior edge pixels. BBC, Guardian and Verge remain zero
twice in diagnostics and production `ad081765`. That production build now
confirms the committed shadow fix at 12 Slashdot pixels; the new clipping fix's
production check, remaining pixels and live/catalog acceptance stay open. See
the [viewport-clip audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-svg-background-viewport-clipping-2026-11-17).

**Remaining forum/news screen, November 17:** the exact Verge fix does not
finish the catalog. A separate diagnostic screen finds open Slashdot, Stack
Overflow, TechCrunch and Register differences; Engadget's fresh Brave references
also vary. Pikabu reaches the harness memory cap, Slate's oracle times out, and
disk-full errors interrupt the remaining captures. No new all-site pass is
claimed. See the [screen and failures](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17).

**Source browser audit:** CNN's retained live PNG was captured with Brave
156.1.98.60; its replay references use 157.1.99.56/57. `86220ffbe` now records
both replay versions and rejects source/replay acceptance across versions,
even when pixels match. Missing version evidence also fails. The original
107,289 differences remain; this check does not attribute them to the upgrade.
The earlier production baseline retained the PNG control's 1,412 differences.
Production `93adced1` now matches that control and all six archived site references
twice. See the
[version audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#source-and-replay-browser-version-qualification-2026-11-16).

**Fresh Brave reference audit:** `597984bc6` preserves each archive's recorded
image-decode preparation. Recent readiness calls to `img.decode()` changed CNN
by 31,766 pixels; preserving its original load/paint protocol reproduces the
retained reference exactly in two fresh full-uBO Brave processes. CNN's earlier
diagnostic Vox PNG matches these references too. Fresh Lobsters references expose
a **101-pixel cross-process repeat failure**: the first matches the retained PNG,
the second differs. Their text, geometry and image inventories agree. New full-uBO
acceptance remains open; no reference or tolerance changes. See the
[decode-preparation audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#preserve-recorded-image-decode-preparation-2026-11-16).

**Lobsters follow-up:** five of eight new default Brave processes differ by
101 pixels; all eight alternating full-raster controls match. After paint
instrumentation starts, the five failing frames become exact. The saved failures
remain intact. Standalone GPU replay predicts every one of the 101 pixels:
one-sample coverage matches the failures, four-sample coverage matches the
reference. The post-capture command logs agree after normalizing process-local
image IDs; they describe the later frame, not the original partial redraw.
Default Brave repeatability remains open. See the
[production and raster audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-production-confirmation-and-lobsters-sample-history-2026-11-16).

**Reddit title wrapping:** `130817464` adds six public cases for titles followed
by unbroken parenthesized domain labels. Two fresh Brave captures agree, and
two fresh captures from the available production browser are exact. This does
not verify the missing November 4 page. A read-only Git object scan found no
match for either recorded HTML hash among 8,850 blobs sized 50–300 kB. See the
[wrapping check](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#public-reddit-title-domain-wrapping-2026-11-16).

**Recovered Reddit follow-up:** the older 2026-11-01 HTML and its script-free
derivative are recovered with their exact documented hashes. With reconstructed
static assets, fresh full-uBO Brave references agree. Filled-marker coverage
reduces Vox 18→6 pixels; repeated-image and border composition now makes it
**6→0 twice**. Both public sprite controls are exact. **56 workloads/112 captures**
repeat exactly, and all 54 prior workload PNGs remain unchanged. This older page
does not restore the newer catalog fixture or certify its historical resource
cache. See the
[sprite composition audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#repeated-reddit-sprite-backgrounds-and-adjacent-borders-2026-11-16).

The latest fixes make CNN **94→73→46→0**: `a6edd14de` preserves fractional SVG
background layout, `fb71abe2d` renders rounded RGBA in owning-tile coordinates,
and `9b326517b` folds CPU-resized YUV into its decoded image frame. The final
**53 workloads/106 fresh captures** repeat byte for byte, with **all 52 non-CNN
PNGs unchanged** and **46 corrected, zero introduced** in the last step. Seven
final tile/callback functions and five unchanged GG functions pass. Existing
references and tolerances are unchanged. See the [decoded-frame audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#decoded-image-frames-for-cpu-resized-planar-uploads-2026-11-16).

Earlier published production **`bbd47035`**, built with literal V `-prod` in one C unit,
reproduced all **56 accepted diagnostic PNGs in 112 fresh captures**. CNN,
GitHub, Hacker News, Lobsters, Wikipedia and Vlang are exact twice; the recovered
older Reddit page also matches two fresh full-uBO Brave captures. This confirms
the recorded rendering fixes in the sealed production artifact. The current-checkout
preflight rejected concurrent image-sampling edits, later committed as
`12fc9e48b`; those newer changes are not validated by this artifact. Its comparison
instead pins the receipt and verifies 187 rendering-package source buffers plus
23 feature/native/shader inputs against the accepted diagnostic build. No manual build
was queued. See the
[production audit](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-production-confirmation-and-lobsters-sample-history-2026-11-16).

Separate ICC/rescaling and other diagnostic controls retain known differences,
including the forced four-sample profiled-image case. A tall-shadow control has
a retained historical repeat failure. Results apply to the pinned builds and
frozen page bytes in the linked report.

Production also confirms `1e1ffdd4e`: the sampled sRGB WebP control improves
5,059→588 pixels. Production then confirms `78f1fcf3b`: the complete control
is exact twice, including the viewport-clipped image, with zero introduced
differences. Its 45-workload recheck retains all 43 other non-CNN PNGs.
CNN stays at 165,579 reference differences and fails its production native
repeat at 1,484 pixels (1,558 in diagnostics); earlier exact-repeat cohorts do
not clear this recurring failure. The subsequent `de138d5e5` diagnostic
identifies its cause as an autoplay video bypassing the replay proxy. Native
playback now uses browser fetching when proxy policy may apply. CNN improves
to **164,021 differences**, repeats exactly in both focused and 45-workload
cohorts, and introduces zero new differences. All 44 non-CNN PNGs are unchanged.
The archive has no MP4 responses: those requests now receive the same 404s
that Brave receives. No reference or tolerance changed, and the source/replay
gate remains open. Production `0d895b01` now confirms this correction in 90 fresh
captures: all 45 pairs repeat exactly and every PNG matches the accepted
diagnostic build. CNN retains 164,021 differences; the four exact archived
sites and Vlang's 27 differences remain unchanged.
The subsequent `7083f309` recheck retains all 45 outputs in 90 fresh captures.
Independent Brave decoder checks now pin all fifteen YUV planes of five CNN
images exactly. Arbitrary-scale painting remains unresolved.
The subsequent `1d32867a2` mask fix makes CNN's headphone icon exact in
diagnostic captures: **164,021→163,914 differences**, 107 corrected and zero
introduced. All 44 other existing workload PNGs are unchanged, and all 46
pairs (including a new mask control) repeat exactly. Focused GG mask tests
pass against independent Brave samples. Production `395539f0` now confirms
this correction across all 46 workloads and 92 fresh captures.
The subsequent `d8e280439` inheritance fix preserves declared CSS variables
during ancestor updates and restores CNN's Watch dot. Diagnostic captures
improve CNN to **163,862 differences**: 52 corrected, zero introduced, with
eight one-level dot-edge differences remaining. All 45 non-CNN PNGs are
unchanged and all 46 pairs repeat exactly. Production `a7918541` now confirms
this inheritance correction across 46 workloads and 92 fresh captures; every
PNG matches the accepted diagnostic.
The next SVG leaf fix (`d86c965a2`) retains the owning raster tile's sample count
and makes the Watch dot exact in diagnostics: **163,862→163,854 differences**, eight
corrected and zero introduced. All 45 other existing PNGs are unchanged, and
all 47 pairs repeat exactly, including a new exact eight-case control. Its
production confirmation now passes on `c19672ae`.
The subsequent `58846cb2e` native continuation fix makes the archived CNN header
exact: **163,854→163,830 differences**, 24 corrected and zero introduced. The
existing opaque mask-gap reftest improves 7→0. All 46 other prior PNGs are
unchanged and all 48 pairs repeat exactly. Production `c19672ae` confirms both
the SVG sample-count and native continuation fixes in 96 fresh captures; every
PNG matches the accepted diagnostic. CNN remains at 163,830 differences and
Vlang at 27. Startup smoke passes. No original reference or tolerance changed.
The decoder checks now also pin five complete RGBA images against independent
Brave Canvas2D readbacks, alongside the fifteen exact YUV planes. These decoder
checks do not establish arbitrary-scale image or catalog-wide equality.
The subsequent `d1799617e` planar-filtering correction reduces CNN to **88,752
differences in diagnostics**, from 163,830: 75,105 corrected and 27 introduced
one-level differences, all within two image rectangles. It filters supported
power-of-two YUV uploads before RGB conversion. All 47 other PNGs are unchanged
in 48 workloads/96 repeatable captures, including the four exact archived sites
and Vlang's 27 pixels. Unsupported scales retain their existing rendering.
Production `44f9e0ff` now confirms the correction across 48 workloads/96 fresh
captures: every PNG matches the accepted diagnostic. CNN and the catalog
still do not pass equality. No original reference or tolerance changes.
The subsequent `59c259a55` mixed-tile YUV correction reduces CNN to **71,925
in diagnostics**, from 88,752: 16,841 corrected and 14 introduced one-level
differences, all inside the Trump image. Its interior improves 15,507→116
pixels, with remaining channel errors at most one. The sampler now preserves
each crossed tile's sample count instead of falling back for the whole image.
All 47 other PNGs are unchanged across 48 workloads/96 repeatable captures.
Focused V/native-callback checks pass under arena poisoning. Production
`523e30dd` now confirms this fix and the following mip fix across 48 workloads
and 96 fresh captures. No original reference or tolerance changes.
The subsequent `262c477c1` YUV mip correction reduces CNN to **58,062 in
diagnostics**, from 71,925: 14,488 corrected and 625 introduced differences,
each new error at most two channel levels. All changes are inside Sullivan's
image, whose interior maximum error improves 88→2. Supported scaled uploads
now retain planes through additional GPU mip filtering and final sampling.
All 47 other PNGs are unchanged across 48 workloads/96 repeatable captures;
the four exact sites and Vlang's 27 pixels retain their results. Focused GPU
and native callback checks pass with arena poisoning. Production `523e30dd`
confirms both fixes: every PNG matches the accepted diagnostic. CNN retains
58,062 differences in that production build; no original reference or tolerance
changed.
The subsequent `5995502f5` near-half YUV420 correction reduces CNN to **54,627
in diagnostics**, from 58,062: 3,508 corrected and 73 introduced one-level
differences. All introduced pixels lie inside the peptides image, whose
interior improves 4,106→1,048 and maximum error 26→1. Three existing one-level
pixels in other photos also become exact. Full-resolution luma and native
half-resolution chroma retain their independent sampling grids in one padded
texture. All 47 other PNGs are unchanged across 48 workloads/96 repeatable
captures. Focused packing, GPU, callback and preparer checks pass. Production
`419ad8d7` confirms this slice in 48 workloads/96 fresh captures: every PNG
matches its accepted diagnostic and every pair repeats. CNN retains 54,627
differences, Vlang 27, and the four exact archived sites stay exact.
The subsequent `69e1fce6c` full-plane mip correction reduces CNN to **33,409
in diagnostics**, from 54,627: 21,724 corrected and 506 introduced one-level
differences, all inside Sullivan's image. Its interior improves 22,366→2,698
and maximum error 2→1. Aligned stronger minification now preserves the original
YUV planes through GPU filtering; generated chroma mip padding repeats the
averaged edge. All 47 other PNGs are unchanged in 48 workloads/96 repeatable
captures. Ten focused V test functions pass under arena poisoning, including
an independent chroma-texture edge regression. Production `99957e17` confirms
the final fix across 48 workloads/96 fresh captures: every PNG matches its
accepted diagnostic and every pair repeats. CNN retains 33,409 differences;
catalog-wide parity remains open, with unchanged references and tolerances.
The subsequent `5a2157173` profiled-RGB half-upload correction
reduces CNN to **6,091 in diagnostics**, from 33,409: 27,321 corrected and
three introduced one-level differences, all inside the ice-cap photo. That
photo improves **27,345→27**, with maximum error one. Exact half-size uploads
retain CPU mip averages; a larger upload already used in the same raster scope
keeps its prior filtering. Stronger reductions retain their existing path.
All 47 other prior PNGs are unchanged across 50 workloads/100 repeatable
captures, including two new independent Brave controls. The direct GG controls
are exact; their browser captures retain 18/24 one-level differences. Four
focused V test functions pass under arena poisoning. Production `d0fa860e`
confirms this slice across 50 workloads/100 fresh captures: every PNG matches
the accepted diagnostic, with all pairs repeating. Full parity remains open.
The subsequent `f09630164` single-channel plane-resampling fix matches the
independent Skia oracle byte for byte. All 50 existing PNGs remain unchanged
in 100 fresh diagnostic captures: CNN stays at 6,091 and Vlang at 27. This
fix supplies no site-level pixel or instruction credit. Production `c23c0d0a`
contains the final sampler and confirms all 50 workloads in 100 fresh captures,
with every PNG matching the diagnostic. The rounded-upload expansion was
rejected and reverted after its visual checks failed.
The subsequent `8c2e79555` full-range JPEG plane upload reduces Vlang **27→5**
in 100 repeatable diagnostic captures across 50 workloads. All 49 other PNGs
are unchanged. Eighteen focused V functions and the Python staging check pass.
Production `aa91e7cc` now confirms that five-pixel result in 100 fresh captures.
The subsequent `293c8abed` Gray8 CPU-plane store correction reduces Vlang **5→4**,
with its JPEG now exact and zero new differences. All 49 other PNGs are unchanged
in another 100 repeatable diagnostic captures. Production `4488b888` contains
Gray8 and an earlier generic clip-elision variant: two fresh captures each confirm
Vlang at one scene pixel and its isolated JPEG at zero. `6003e7627` then keeps
clip elision at the CSS boundary and removes its arena allocations. Final
C/O0 diagnostics reduce Vlang **4→1**, the orbit underlay **3→0**, the complete
orbit scene **4→1**, and the rotated-ellipse control **19→5**, with zero new
differences. All 50 workloads/100 captures repeat; 46 PNGs are unchanged.
The final scoped implementation's production confirmation remains pending.
The subsequent `bd6bfd3f7` preserves resolved blur support and its origin before
rotation. Diagnostics make Vlang **1→0**, the clipped orbit **1→0**, and the
rotated-ellipse control **5→0**. All 50 pairs repeat, with zero introduced pixels
and 47 other PNGs unchanged; CNN stays at 6,091. Its production confirmation is
also pending. `eb35365d2` then corrects rounded WebP upload mip selection:
CNN improves **6,091→5,160**, with 934 corrected and three introduced one-level
pixels, while all 49 other PNGs remain unchanged in 100 repeatable captures.
Its maximum channel error drops **58→9**. New production `3c6be545` confirms
the final CSS gradient source in six focused baseline captures (Vlang one,
underlay zero, CNN 6,091); it lacks the shadow and mip changes. References and
tolerances remain unchanged and catalog parity is open.
The subsequent `6840391d5` supports rounded profiled RGB uploads and preserves
native-size upload history across raster scopes. CNN improves **5,160→4,788**:
372 corrected and zero introduced pixels; the profiled train photo is exact and
the complete viewport's maximum error is now one. All 51 workloads/102 captures
repeat, all 49 other prior PNGs are unchanged, and the new clipped-image control
is exact. The rejected first cohort's 371-pixel native-reuse regression is retained
and corrected in the final source. Production validation remains pending.
See the
[current audit, capture scopes and retained failures](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md).

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Vox RAM (MiB)‡ | Brave RAM (MiB)‡ | Vox scroll FPS§ | Vox GPU canvas FPS§ | Brave scroll FPS† | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Hacker News homepage | 2026-11-04 | 7 | Median | 1,918,074,453 | 8,056,201,640 | **76.19%** | — | — | 59.8–59.9 frozen | 59.8–59.9 frozen | — | [Comparison](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-1800-attempt-2026-11-04.json), [scrolling](docs/HACKER_NEWS_SCROLLING.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) (RAM 559.7/639.2 MiB and Brave scroll 59.78–59.79 FPS were measured on earlier builds; Vox FPS after the `d96b871e4` fix, see the HN note below) |
| Lobsters homepage | 2026-11-02 | 7 | Median | 8,082,180,934 | 27,446,683,211 | **70.55%** | 535.2 | 992.4 | 59.0–59.6 live | 58.7–58.9 live (no canvas frames) | — | [Comparison](docs/LOBSTERS_BRAVE_INSTRUCTIONS.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) |
| Old Reddit /r/programming/ | 2026-11-04 | 7 | Median | 3,060,307,260 | 9,374,680,561 | **67.36%** | — | — | — | — | — | [Reduction](docs/OLD_REDDIT_PROGRAMMING_REDUCTION.md), [ledger](docs/benchmark-results/old-reddit-programming-reduction-2026-11-04.json), [2026-11-03 recheck](docs/OLD_REDDIT_PROGRAMMING_RECHECK.md) (RAM 607.1/608.3 MiB, scroll 39.2–53.0/59.56–59.78 FPS on its earlier fixture; unmeasurable on 2026-11-05: fixture deleted, live page redirects guests to login) |
| CNN homepage (provisional) | 2026-11-01 | 7 | Median | 21,805,542,771 | 32,665,051,523 | **33.25%** | 1,234.0 | 1,031.5 | 33.1–35.9 live | 29.3–35.5 live (no canvas frames) | — | [Comparison](docs/CNN_INSTRUCTIONS.md), [receipts](docs/benchmark-results/cnn-home-thirty-percent-2026-11-01.json), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) |
| Wikipedia portal (www.wikipedia.org) | 2026-11-01 | 7 | Median | 6,686,475,010 | 9,702,898,348 | **31.09%** | 515.1 | 614.2 | 59.2–59.8 live | 59.5–59.7 live | 59.57–59.79 frozen | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/WIKIPEDIA_BRAVE_INSTRUCTIONS.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05) (frozen-fixture Vox 3.1–3.6 FPS on 2026-11-01) |
| vlang.io (CLI protocol) | 2026-11-01 | 7 | Mean | 8.630 billion | 10.500 billion | **17.81%** | 709.6 | 668.9 | 52.3–54.5 live | 54.8–55.7 live | 59.49–59.79 frozen | [Audit](docs/OPTIMIZED_SITES_AUDIT.md), [comparison](docs/VLANG_RENDERING_INSTRUCTIONS.md), [2026-11-05 FPS](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05), [GPU canvas](docs/VLANG_GPU_PASS.md) (frozen-fixture Vox 0.8–0.9 FPS on 2026-11-01) |
| GitHub /vlang/v (frozen, script-free) | 2026-11-08 | 7 | Max Vox / min Brave | 8,516,462,391 | 10,718,007,194 | **20.54%** | — | — | — | — | — | [Comparison](docs/GITHUB_BRAVE_INSTRUCTIONS.md), c35 pinned executable `f30a1422`; launch through document PNG (Vox teardown included), observed process-tree lower bounds; native and deferred regressions pass; c35 optimizations are now in newer shared build `23d3335d`, whose instruction cohort has not been rerun |

**Hacker News, current-Vox follow-up (2026-11-02):** the archived homepage's
startup-through-encoded-PNG median is **3,974,847,245**, **17.080% below** the
original Vox baseline of 4,793,590,625; the conservative historical reduction
is **16.115%**. Seven complete alternating encoder-control/default-Vox pairs
retain exact reference pixels and all 30 stories. This is a Vox-baseline
comparison; the additional Vox/Brave cohort failed one Brave ownership audit
and supplies no replacement for the historical Brave row. Author scripts execute
through JavaScriptCore. Live functional validation passes, while the instruction
claim remains frozen-page startup/capture work and establishes no rendering-time
or scrolling-FPS gain. See the [report](docs/HACKER_NEWS_VOX_REDUCTION.md) and
[raw counts](docs/performance/hn-vox-reduction-20261102.json).

**Hacker News, 3.2B target (2026-11-03):** seven fresh default-production launches
reach **3,060,115,612 median** and **3,087,147,950 maximum** observed coalition
instructions through encoded document PNG availability. Every trial passes exact
pixels, all 30 stories, PNG profile/density/metadata, ownership and normal-exit
audits. A separate seven-pair control/default cohort measures 3,133,122,728 →
3,061,561,124 medians; all fourteen output PNGs are byte-identical. Original
scripts run through JavaScriptCore. These are frozen-page startup/capture
results, with retained OS caches and excluded GPU/outside-service work, and
provide no new Brave ratio, isolated rendering time or scrolling-fps claim.
See the [report](docs/HACKER_NEWS_3_2B.md) and
[pinned evidence](docs/performance/hn-3200-progress-20261103.json).

**Hacker News, current Vox results:** the latest verified follow-up is listed
separately from the historical paired Vox/Brave row above.

| Workload | Trials | Vox median instructions | Vox maximum instructions | Status | Evidence |
| --- | ---: | ---: | ---: | --- | --- |
| Archived homepage, fresh launch through encoded document PNG | 7 | **3,060,115,612** | **3,087,147,950** | Earlier validated 3.2B result | [Validated result](docs/HACKER_NEWS_3_2B.md), [2.7B continuation](docs/HACKER_NEWS_2_7B.md) |
| Same archived homepage and capture scope, pinned build `db4eab23` | 7 | **2,655,492,802** | **2,676,747,832** | Packaged default build passes the 2.7B median/maximum gate | [Report](docs/HACKER_NEWS_2_7B.md), [evidence](docs/performance/hn-2700-resume-20261103.json) |
| Latest verified shared build `2e53ce13`, same workload | 7 | **2,675,233,606** | **2,701,876,818** | Median below 2.7B; maximum gate narrowly fails | [Retained cohort](docs/HACKER_NEWS_2_7B.md) |
| Same workload, shared build `9ebd66e2` (2026-11-04 baseline) | 7 | **2,720,274,906** | **2,737,779,104** | Brave median lower bound 8,109,046,423 | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md) |
| Same workload, shared build `698536dc` with window-indexing opt-out `dd8ce6d7a` | 7 | **2,477,573,492** | **2,492,665,267** | 8.92% below the 2026-11-04 baseline; every launch passes the requested 5% ceiling | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-window-indexing-2026-11-04.json) |
| Same workload, shared build `5283f5ee` with arena/font fixes `ce8ee0c1d`, `badeb3692`, `fbaa09e7a` | 7 | **2,415,799,258** | **2,423,249,629** | Second of two cohorts (first: 2,429,806,150 median); one Brave helper-ownership failure in each, so no Vox/Brave acceptance; 2.1B target open | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-progress-2026-11-04.json) |
| Same workload, shared build `5ec5d123` after the LaunchServices cleanup, ICU 78-only `fc6f92871` and toolbar glyphs `1faaf32c4` | 7 | **2,021,169,989** | **2,031,664,578** | Complete Vox/Brave cohort; Brave median lower bound 8,024,928,010; 2.1B target met | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-reached-2026-11-04.json) |
| Same workload, shared build `74270cfc` adding `07bc5117f` | 7 | **2,048,165,192** | **2,063,697,542** | Complete Vox/Brave cohort; Brave median lower bound 7,969,122,901; 2.1B target met | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-reached-2026-11-04.json) |
| Same workload, shared build `642ceefd` adding font order `4099177ce` | 7 | **2,011,557,697** | **2,090,182,179** | All Vox launches pass; one Brave helper-ownership failure, so no Vox/Brave acceptance | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-2100-reached-2026-11-04.json) |
| Same workload, shared build `ad0e4e39` adding `1bc242c98`, `301f49be4`, `486ea20d4`, `a1f7527e0`, `b512ff759` | 7 | **1,918,074,453** | **1,927,596,995** | Complete Vox/Brave cohort; Brave median lower bound 8,056,201,640; 1.8B target not met | [Report](docs/HACKER_NEWS_BRAVE_INSTRUCTIONS.md), [ledger](docs/benchmark-results/hacker-news-1800-attempt-2026-11-04.json) |

The packaged `db4eab23` cohort passes with exact original pixels, all 30 stories
and ownership/identity/exit audits. The corrective private-codec change also
saves 35.1M between medians in seven matched diagnostic pairs. Two earlier
pinned default builds pass the target; the `8f1ee6b0`, `3fafbc61` and `2e53ce13`
maximum-gate failures remain recorded. The latter builds pass default packaged
startup/helper checks, all 21 rendering cases and live HTTPS navigation with
successful author-script execution; their high trials still exceed the ceiling.
Regression suites start only after the first passing default cohort, as the
user requested. Source, native memory-safety, font, filtering, UI2, PNG and
21-case rendering checks now pass. The PNG literal optimization trades an
8.68% larger compressed stream for less work, within the existing size bound.
Failed cohorts and rejected prototypes remain recorded. PNG metadata is stable
against a newly pinned control PNG; the historical Vox PNG and earlier raw
directory are unavailable after shared Build cleanup. These are frozen-page
startup/capture counts, with no new Brave ratio or scrolling claim. See the
[fresh evidence](docs/performance/hn-2700-resume-20261103.json),
[progress report](docs/HACKER_NEWS_2_7B.md) and
[all retained attempts](docs/performance/hn-2700-progress-20261103.json).

**Old Reddit /r/worldnews, Linux Vox follow-up (2026-11-02):** typeface reuse
reduced median **Cachegrind guest instruction references (Ir)** from
**7,181,198,185** to **5,794,954,378**, a **19.30%** reduction. The conservative
highest-candidate/lowest-control reduction is **13.19%**, also passing the
retained earlier-control gate. Three alternating Vox control/candidate pairs
preserve exact PNGs and audited content for the frozen 2024-01-01 script-free
fixture at 1280×900. Scope is program execution through exit after PNG capture
and audit, including startup and teardown. These software counts establish a
Linux Vox before/after improvement; they do not measure hardware-retired
instructions, live Reddit, native latency, or a new Brave comparison. Known
baseline rendering gaps remain. See the [report](docs/OLD_REDDIT_LINUX_TYPEFACE_CACHE.md)
and [raw-count ledger](docs/benchmark-results/old-reddit-linux-typeface-cache-2026-11-02.json).

**‡ RAM** is the median observed peak of simultaneous browser process-tree
physical footprints from separate **2026-11-02** measurements: two fresh pairs
per site, three for vlang.io. MiB means 1,048,576 bytes. Sampling covers root
discovery through browser exit, including capture/audits and observed browser
helpers/GPU processes; benchmark-tool memory is excluded. Early startup and
short-lived unsampled helpers can be missed. These current-build RAM runs use
the saved workloads and do not replace the instruction cohorts above. All
selected documents pass complete semantic audits; CNN, vlang.io and Brave's
Wikipedia capture differ from historical pixel references. See the
[RAM report](docs/OPTIMIZED_SITES_MEMORY.md) and
[raw values and receipts](docs/benchmark-results/optimized-sites-memory-2026-11-02.json).

**CNN is provisional:** its median lead exceeds 30%, but the conservative gate
fails with two large owned-helper costs, and one Brave capture mismatches the
fixed pixel reference. All seven Vox captures are exact. CNN scrolling was measured
only on the live page (2026-11-05), not on the instruction fixture.

**§ Vox scroll FPS (2026-11-05)** ranges span **two completed trials** per
column; the trial counts and mean/median labels above refer to instructions.
Both Vox columns use the shared production build `9e052f2b…` (head
`c0203bb8e`; Hacker News: `f1100092…`, head `ee091fb85`, after its fix), fresh
processes and private profiles/caches, a 1024×768 document
viewport at native scale 2, 20 seconds settling after the title and 600 precise
native wheel inputs at nominal 60 Hz, delta 2, reversing every 60 inputs. They
count scroll-changing native layer publications over the full input window.
**Vox GPU canvas FPS** enabled the then opt-in canvas
(`VOX_EXPERIMENT_GPU_CANVAS=1`), alternating with the canvas-off control on the
same bundle. The canvas is now the browser default (Settings → Advanced →
GPU-accelerated scrolling turns it off), so that column describes the current
default and "Vox scroll FPS" the canvas turned off. The canvas only draws frames that reuse
the previous frame's pixels while scrolling. A verification run per page shows
it engaging on the Wikipedia portal (598 frames, at most 1 level of difference),
vlang.io (1,054 frames; three frames differ by up to 58 levels at isolated
anti-aliased edge pixels) and, after its fix, Hacker News (599 frames, at most
1 level). CNN and the Wikipedia Main Page repaint every frame because their CSS
masks (`begin_svg_mask_layer`) are not supported by pixel reuse; Lobsters draws
each frame as one shared GPU picture, which turns pixel reuse off. There both
columns measure the same code path, so their difference is run-to-run variation.
Hacker News uses its frozen archive; the frozen fixtures of the other rows were
deleted by `Build/` cleanup, so those values come from the **live** pages and
differ from the instruction workloads. Host load averages were 4.6–15.2 on 18
CPUs. See the [Vox scrolling report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05)
and [receipt](docs/performance/optimized-sites-scroll-20261105.json).

**Hacker News regression and fix:** on build `9e052f2b…` every HN frame was a
complete repaint of about 25 ms (39.2–43.8 FPS frozen, 39.3–40.3 FPS live at
120 Hz). The text input editor built by layout lacked upstream's
`scrollbar-width: none`, so the footer search box painted a 3×6 px overlay
thumb; as the last painted box, it joined the trailing viewport scrollbars and
scroll-raster reuse rejected every frame (`nonviewport-vertical-scrollbar`).
Commit `d96b871e4` restores the upstream editor style. On build `f1100092…`
every scrolled frame reuses pixels again and HN measures the values listed here
(load 8.6–15.2). See the [fix report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#hacker-news-fix-2026-11-05).

**† Brave uses CDP wheel input and Chromium presentation feedback, with
frame-event tracing enabled**; see its [report and raw evidence](docs/BRAVE_SCROLL_FPS.md).
Its values are the 2026-11-01 measurements on the since-deleted frozen pages.
This bypasses Cocoa input and observes a later frame boundary, so the Brave and
Vox columns do not establish a matched FPS ratio or optimization acceptance.
Neither endpoint measures physical display scanout or establishes smooth 60 FPS.
**— means unmeasured, not zero FPS.**

Percentages compare the two browser summaries in the same row. Means and
medians are labeled separately; the vlang.io means are rounded. Instruction
captures use a 1024×768 CSS-pixel viewport. Hacker News uses native capture scale 2;
the other workloads use scale 1. Old Reddit, Wikipedia and vlang.io use process-tree counters:
Vox includes capture and teardown, while Brave ends before shutdown. Both sums
are observed lower bounds because short-lived unsampled children can be missed.
Hacker News, CNN and Lobsters use exclusive resource-coalition counters through PNG availability,
including exited helpers and explicitly allowed coalition-owned system services;
Vox ends before the PNG file write and Brave includes CDP screenshot delivery.
GPU execution and services outside the recorded ownership scope are excluded.
The reports retain exact endpoints, identities and counter limits.

Lobsters uses its dated frozen guest DOM with author scripts removed, normal
scripting and filtering scriptlets retained, full-uBO filtering, and private
copies of complete encoded-resource caches. All 14 captures match the original
live Brave reference exactly. Its conservative highest-Vox/lowest-Brave lead is
69.28%; the existing completed production build already passes the 10% target.

## Latest live scrolling

| Page | Recorded date | Vox scroll FPS | p95 interval, both trials | Intervals over 16.67 ms | Vox GPU canvas FPS | Evidence |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Wikipedia English Main Page (live) | 2026-11-05 | **64.3–83.3** | 20.87 / 15.48 ms | 18.98% / 2.37% | 68.8–82.0 (no canvas frames) | [Report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#current-build-2026-11-05), [receipt](docs/performance/optimized-sites-scroll-20261105.json); 2026-11-01: 80.2–84.1, [report](docs/WIKIPEDIA_SCROLLING.md) |
| Hacker News homepage (live) | 2026-11-05 | **117.1–119.5** | 9.57 / 8.87 ms | 0.77% / 0.25% | 117.6–119.6 | [Fix report](docs/OPTIMIZED_SITES_SCROLL_FPS.md#hacker-news-fix-2026-11-05), [receipt](docs/performance/hn-scroll-fix-20261105.json); 2026-11-01: 113.1–115.7, [report](docs/HACKER_NEWS_SCROLLING.md) |

**Wikipedia:** These two fresh installed-process trials count scroll-changing native layer
publications over the full input window. Each completes 600 precise wheel inputs
at nominal 120 Hz, delta 1, continuous forward motion, with a 1024×764 document
viewport at scale 2, fresh private profiles/caches and 12 seconds settling after
the Wikipedia title. The default Wikipedia script policy leaves its author-script
runtime uninitialized. The report retains median/maximum intervals, publication
counts and boundary gaps. Occasional longer intervals remain; physical display
scanout is unmeasured. This English Main Page result has a different workload
from the portal row above. The 2026-11-05 trials ran on the shared build
`9e052f2b…` at host load 9.8–11.8; their actual input delivery (70–98 Hz)
varied with that load, so the range is wider than on 2026-11-01.

**Hacker News:** Two fresh processes of the completed installed production
snapshot each complete 1,200 precise native inputs at nominal 120 Hz, delta 1,
reversing every 120 events, with a 1024×768 document viewport at scale 2 and
20 seconds settling after the title. They use the live page, empty private
profiles/caches and normal site restrictions. This protocol checks rendering
headroom above 60 FPS; it differs from the 600-input, 60 Hz frozen-page protocol
in the main table. After the `d96b871e4` fix the p95 intervals are 8.87–9.57 ms,
close to the 8.33 ms input period and well inside a 60 FPS budget; the build
before it measured 39.3–40.3 FPS with every interval over 16.67 ms (see the
Hacker News note above). Physical display scanout is unmeasured.

## How to benchmark against Brave

Use the following procedure before adding or updating a result. The full
repository requirements are in [AGENTS.md](AGENTS.md#cpu-instruction-comparisons-against-brave).

1. **Choose the scope before measuring.** The default is a fresh browser launch
   through completed document PNG capture, including startup and window/target
   setup in both engines. Use cumulative process/coalition readings; subtracting
   a post-launch baseline removes startup. Record whether encoding, CDP delivery,
   content audits and teardown are included. A navigation-only comparison needs
   equivalent initialized windows and matching boundaries in both browsers.
   Hacker News's old navigation markers included window setup only for Vox;
   use its `--instruction-scope launch` acceptance mode.
2. **Pin the browsers and inputs.** Reuse the latest successfully completed
   production bundle, following the shared-build rules; pin a completed copy
   when isolating a change. Record executable and transitive native-library
   hashes, helpers, Brave's framework/version, HTML/resource hashes, references
   and measurement sources. Launch fresh processes and verify identities
   throughout the cohort. An older build cannot validate newer engine code.
3. **Match the workload.** Use the same frozen bytes, author-script policy,
   viewport, backing/capture scale and settle conditions. Record both browsers'
   filtering policies. Give every trial fresh private profiles/caches, remove
   ambient measurement and proxy overrides, and replay archived responses
   without live fallback.
   State whether OS filesystem/shader caches are retained. Record host CPU
   count, load and timestamps. Validate live behavior separately before making
   a live-site claim; an archived or script-stripped page has that limited scope.
4. **Verify JavaScript activity separately.** Record the selected backend and
   script policy. Vox's selectors are `javascriptcore` and `libjs`; Brave uses
   V8. A selector or `--enable-javascript` does not prove execution: independently
   verify runtime initialization, actual code execution and absence of fallback.
   Keep probes outside the measured cohort and report unsupported DOM/script
   behavior. A script-free page whose runtime stays uninitialized measures
   startup/rendering, not JavaScript execution speed. See the
   [Old Reddit runtime probes](docs/OLD_REDDIT_ENGINE_COMPARISON.md).
5. **Validate content and pixels.** Establish fixed references before the cohort.
   Require the intended URL/title, complete readiness, correct viewport and full
   content identity, such as every post/story ID in order. Reject error pages,
   missing content, crashes and abnormal/unknown exits. Check unchanged pixel
   references for every capture. Per-engine reference stability is distinct
   from cross-browser pixel equality; disclose any difference and never change
   references, masks or tolerances to obtain instruction credit.
6. **Use matching counters and memory guards.** Use the same hardware-counter
   backend and ownership policy for both engines. Account for exited helpers
   where supported; disclose missing samples and excluded GPU/outside-service
   work. Both polled process-tree totals are lower bounds, so do not call a Vox
   observation an upper bound without proof. Run under
   `tools/run_memory_bounded.py` with its default 12 GiB budget. LaunchServices
   runs also need the same private PID registry passed as `--adopt-pids-from`
   to the guard and `--memory-guard-registry` to the supporting harness; verify
   adoption and browser RSS accounting.
7. **Collect at least seven complete alternating pairs.** For multiple Vox
   backends, rotate matched configurations and Brave controls. Keep every
   attempt, including first-launch outliers, failures and regressions; do not
   retry or exclude samples to pass. Profile with `v -profile` or other probes
   in separate diagnostic runs. Attribute an optimization only when its path
   executes on this workload and matched unprofiled controls support the gain.
8. **Compute and retain the result.** For a 10% target, require
   `10 * max(Vox) <= 9 * min(Brave)` using exact integer arithmetic; use Vox's
   upper and Brave's lower readings when intervals are available. Honor a
   different requested threshold explicitly. A gate on polled lower-bound totals
   is an **observed-count comparison**, not a certified
   bound on total work. Report the highest-Vox/lowest-Brave ratio as well as
   medians. The catalog percentage is `100 * (1 - statistic(Vox) / statistic(Brave))`,
   using the same declared mean or median and unrounded counts; paired reductions
   are a separate statistic. Preserve raw commands, logs, counters, PNGs, audits,
   identities, host conditions and actual browser/benchmark/guard exits in a
   unique `Build/` directory, with durable counts and hashes linked from the
   report. Keep private account-bearing artifacts out of commits. Preserve
   earlier failing cohorts, and qualify the result by its build, workload and
   cache conditions. Changing measurement boundaries earns no engine speedup.

For example, replay the archived Hacker News homepage with fresh output,
receipt and registry names (replace `UNIQUE` on every run):

```sh
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY \
    -u all_proxy -u http_proxy -u https_proxy \
  python3 tools/run_memory_bounded.py \
    --lock Build/hn-brave-UNIQUE.lock \
    --report Build/hn-brave-UNIQUE-guard.json \
    --adopt-pids-from Build/hn-brave-UNIQUE-pids.json -- \
  python3 tools/hacker_news_browser_instructions.py \
    --output Build/hn-brave-UNIQUE \
    --memory-guard-registry Build/hn-brave-UNIQUE-pids.json \
    --home-archive Tests/Browser/Brave/hn-home-instructions \
    --instruction-scope launch --target-vox-fraction .9 --repeat 7 \
    --scale 2 --settle-seconds 2 \
    --diff-tool Build/hn-home-instructions-20261031/pixel_diff
```

Use an existing verified pixel-diff binary. For other rows, use the linked
report's own fixture, references and harness. The [Old Reddit recipe](docs/OLD_REDDIT_PROGRAMMING_INSTRUCTIONS.md#verification-and-reproduction)
accepts `--vox-js-engine javascriptcore` or `--vox-js-engine libjs`, with
`--repeat 7 --required-reduction .10`; record runtime eligibility for either.
Keep the existing focused checks and broad-regression cadence from `AGENTS.md`.

For scroll FPS, follow the [scrolling measurement rules](AGENTS.md#scrolling-performance-measurements)
and use [precise native input](tools/measure_precise_scroll.py) or the
[disk-replay runner](docs/DISK_SCROLL_BENCHMARK.md) for Vox. Use the listed page
and pinned builds; match viewport, scale and input schedule between browsers,
with at least two complete unprofiled trials each. Count
scroll-changing native frame publications over the entire first-to-last input
window, verify movement and retain actual input times.
Link median/p95/maximum intervals, deadline misses, input/frame counts and
boundary gaps alongside FPS. State the endpoint for each browser; native
publication is distinct from physical display scanout. A Brave FPS value needs
its own matched measurement.

## Workload and rendering scope

- **Old Reddit /r/programming/ (2026-11-04):** a refreshed frozen page fetched
  with the imported session, all 17 script elements removed and 20 sealed
  responses replayed offline. Vox and Brave differ in two wrapped title lines
  (2,046 pixels), so captures are checked against fixed per-engine references;
  all 25 post IDs are preserved. Medians fall from 3,430,344,655 to
  3,060,307,260 (10.79%); the worst-final/best-baseline bound is 9.996%. About
  200M comes from four committed launch/paint changes and the rest from
  concurrent commits; RAM and scrolling were not remeasured on this fixture. See
  the [reduction report](docs/OLD_REDDIT_PROGRAMMING_REDUCTION.md).
- **Old Reddit /r/programming/ (earlier fixture):** cached account-bearing markup, 17 executable
  script elements removed, normal scripting policy retained, 120 sealed
  successful resource responses and fresh profiles/caches. All 14 captures
  match the same Brave reference exactly and preserve all 25 post IDs. The
  highest observed Vox count is **56.19% below the lowest Brave count** in the
  [2026-11-03 recheck](docs/OLD_REDDIT_PROGRAMMING_RECHECK.md). Live
  access is blocked by HTTP 403; no live or current-authentication claim is
  made. This new workload does not reverify the historical home-page fixture.
  The selected Vox page-script runtime is unused on this script-free fixture;
  the [JSC/LibJS selector comparison](docs/OLD_REDDIT_ENGINE_COMPARISON.md) is
  a configuration comparison, not a JavaScript-execution benchmark.
- **Hacker News:** the frozen original homepage and five resources, with author
  scripts enabled, fresh empty profiles/caches and two seconds of settlement.
  All 14 captures match the unchanged Brave reference at every pixel and retain
  all 30 story IDs. The highest Vox count is **41.61% below the lowest Brave
  bound**, passing the 10% target. The earlier 3× headline excluded Brave's
  window setup while including Vox's; the corrected startup scope includes
  setup for both. The same pinned binaries were reused, so the accounting
  correction receives no engine optimization credit. OS caches are retained;
  the report preserves earlier startup outliers and makes no cold-system claim.
- **Wikipedia:** original archived responses, fresh empty profiles/caches,
  JavaScript disabled in both browsers, matching Vox's existing Wikipedia
  policy. All 14 captures match their respective engine baselines exactly;
  seven pixels at the search-box corners differ between engines. Even the
  highest observed Vox count is **29.81% below the lowest observed Brave count**
  in the fresh audit, which records successful browser exits. A separate live
  navigation using the measured capture path matches the frozen Vox pixels.
  The existing production build already met the target; this comparison
  required no runtime optimization.
- **CNN (provisional):** the frozen homepage has author scripts removed, with
  normal scripting policy, JavaScriptCore initialization, inline handlers and
  full-uBO filtering retained. Seven alternating pairs use original-origin
  replay, fresh private copies of the declared cache/profile templates,
  1024×768 at scale 1, five seconds of settlement and retained OS caches.
  All content/filter audits and actual browser exits pass. The highest Vox
  count, **36,373,350,927**, is **1.13119×** the lowest Brave lower bound,
  **32,154,975,008**, so the strict 30% target remains open. Brave pair 4 differs
  at 13,565 pixels; that failure and both Vox outliers remain in the statistics.
  The live-load check records frame and consent-API JavaScript errors; this
  frozen startup/capture result does not establish live author-script performance.
- **vlang.io:** an initialized DOM snapshot with archived assets, author scripts
  removed, animations/transitions disabled and a fixed video poster; JavaScript
  policy remains enabled. The fresh CLI audit records clean exits and exact
  matches to unchanged engine references in all 14 captures. The highest Vox
  count is **15.10% below the lowest Brave bound**. Cross-browser equality is
  unmet: 112,005 pixels differ, with maximum channel error 3. The earlier CLI
  cohort's 16.54% mean lead and the background cohort's **0.41% mean lead** both
  remain in the report. Launch-context dependence is unresolved; the table
  applies to the stated CLI protocol. Live author-script behavior is checked
  separately from these instruction measurements.

## GitHub full-JavaScript site-policy comparison

The GitHub site policies reduce observed instructions by **29.23% between
medians** and **22.19% conservatively** across seven matched pairs on
`github.com/vlang/v`. Control median: **56,828,029,810**; optimized median:
**40,219,144,070**. This is a Vox policy-on/policy-off comparison on the
same completed build `91be2b76`, with full immediate JavaScriptCore startup,
original-origin frozen replay, a shared Date prefix, fresh profiles/caches and
five-second settling after Sponsor/sidebar readiness. The launch-through-document
PNG/audit/teardown scope uses 1024×768 at 1×; all fourteen PNGs match the unchanged
reference exactly and complete content audits pass. Counts are process-tree lower
bounds and exclude GPU/WindowServer work. Live loading passes separately; live
performance, isolated rendering, scrolling and comparison with Brave are outside
this result. [Report and limitations](docs/GITHUB_SITE_OPTIMIZATIONS.md),
[exact counts and retained attempts](docs/performance/github-raster-input-validation-20261108.json).

## Historical result awaiting raw verification

| Site | Recorded date | Trials per browser | Statistic | Vox instructions | Brave observed instructions | Fewer instructions | Vox scroll FPS | Brave scroll FPS | Evidence |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Old Reddit home | 2026-10-17 | 7 | Median | 6,289,762,769 | 8,208,707,273 | **23.38%** | — | — | [Historical comparison](docs/OLD_REDDIT_INSTRUCTIONS.md), [audit](docs/OPTIMIZED_SITES_AUDIT.md) |

The documented arithmetic and startup scope check out, but the private
`Build/reddit-parity/` fixture and per-process receipts are absent from this
checkout. This older home-page row is distinct from the newly measured
`/r/programming/` workload above and is not a freshly verified acceptance result. Its report
describes a frozen authenticated page with executable author scripts removed,
exact Brave-reference captures and a conservative 21.39% observed lead. Live
scripting, interactions and authentication parity are outside that record.

## Comparisons still open

[Pikabu](docs/PIKABU_INSTRUCTIONS.md) has a small, variable observed median lead
that does not establish a repeatable advantage. [CNN](docs/CNN_INSTRUCTIONS.md)
has the provisional median lead listed above; its strict 30% acceptance remains
open. [Stack Overflow on macOS](docs/STACKOVERFLOW_BRAVE_INSTRUCTIONS.md) has not
established lower instruction counts than Brave. The fresh seven-pair Stack
Overflow comparison records median observed counts of **27,723,596,574 for Vox**
and **10,379,419,729 for Brave**: Vox uses **2.67× as many instructions** on the
frozen questions page. All captures match their fixed per-engine references;
2,061 pixels differ across engines. The earlier
[PR diagnostic](docs/STACKOVERFLOW_MACOS_PR_COMPARISON.md) remains separate.
Stack Overflow's
[Linux optimization](docs/STACKOVERFLOW_LINUX_PERFORMANCE.md) compares two Vox
versions using Cachegrind instruction references, rather than Vox against Brave.

[ChatGPT](docs/CHATGPT_BRAVE_INSTRUCTIONS.md) (chatgpt.com) has not established
lower instruction counts than Brave. The latest complete seven-pair cohort on the
frozen homepage records median observed counts of **30,006,382,557 for Vox** and
**16,334,249,687 for Brave** (lower bound): the conservative ratio is **1.8651×**
and the 5% advantage target fails. All fourteen captures match the retained
document PNG exactly. The current target is 20B instructions; see the
[sealed-profile receipt](docs/performance/chatgpt-sealed-profile-20261105.json).

## Forum/news rendering coverage

The sixteen registered forum/news sites are in the
[test catalog](Tests/Browser/Brave/forum-news.json). The table also retains the
earlier blocked Reddit guest-homepage record; Old Reddit programming and the
separate ChatGPT instruction workload above keep their own evidence.
The bar retains Wikipedia, Old Reddit `/r/programming/` and vlang.io too, and
lists Hacker News once. These entries track rendering work; the instruction
comparisons above retain their own acceptance requirements and measured pages.

The pixel checks use a frozen guest DOM at 1024×768, scale 1, original response
bytes and matching full uBlock Origin lists. New strict passes require zero
pixels from saved source to frozen Brave, from Vox to frozen Brave, and between
two fresh Brave replay processes. Older checkpoints retain their recorded
protocols. Results apply to each report's pinned build and captured viewport,
with live scripting, scrolling and whole-site behavior outside that claim.

| Site | Rendering checkpoint | Evidence |
| --- | --- | --- |
| [Hacker News](https://news.ycombinator.com/) | Strict cold source/replay/native pass, 0 pixels on `0f2d286a…`. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json) |
| [Reddit](https://www.reddit.com/) | Guest homepage blocked by HTTP 403; distinct from the measured Old Reddit programming page above | [Access record](docs/ADBLOCK_POPULAR_SITES.md) |
| [ChatGPT](https://chatgpt.com/) | Registered guest fixture unavailable; no new guest capture, HTTP result or pixel pass claimed. The separate frozen instruction workload above is not this archive. | [Archive status](Tests/Browser/Brave/sites/chatgpt/status.json) |
| [Lobsters](https://lobste.rs/) | Strict cold source/replay/native pass, 0 pixels on `0f2d286a…`. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json) |
| [Slashdot](https://slashdot.org/) | November 17: `2d65e5d97` reduces diagnostic differences 232,234→10 twice vs agreeing Brave replays; source also matches. Production `ad081765` confirms the preceding committed shadow fix at 12 pixels twice. Source/replay browser versions differ; current acceptance open. Earlier strict zero-pixel checkpoint retained. | [Header fix](docs/FORUM_NEWS_EXPANSION.md#rounded-slashdot-headers-across-square-borders-2026-11-06), [evidence](docs/evidence/slashdot-rounded-header-20261106.json); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17); [glyph-mask fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-per-glyph-shadow-masks-2026-11-17); [viewport clip](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#slashdot-svg-background-viewport-clipping-2026-11-17) |
| [Stack Overflow](https://stackoverflow.com/questions) | November 17 diagnostic: 3,297 pixels vs agreeing Brave replays; saved source also matches. Source/replay version qualification and rendering parity remain open. | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [BBC News](https://www.bbc.com/news) | November 16: `93adced1` production 32,482 pixels; WebP fixes give zero diagnostic pixels twice; production `ad081765` confirms zero twice on November 17. Earlier strict 0-pixel checkpoint retained. | [Historical checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json); [November 16 recheck](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-png-fix-and-expanded-forum-coverage-2026-11-16); [cropped WebP fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#cropped-webp-plane-sampling-2026-11-16); [full-image atlas fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#even-webp-atlas-clips-and-bbc-rendering-parity-2026-11-16) |
| [CNN](https://edition.cnn.com/) | Open: source 107,289; independent Brave replays differ 31,766. Vox matches the second replay exactly; strict gate fails. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json) |
| [The Guardian](https://www.theguardian.com/international) | November 16: 425 production pixels on `93adced1`; JPEG XL and border fixes give zero diagnostic pixels twice; production `ad081765` confirms zero twice on November 17. Earlier strict 0-pixel checkpoint retained. | [Mask-gap fixes](docs/FORUM_NEWS_EXPANSION.md#guardian-header-pictures-across-offscreen-masks-2026-11-06), [evidence](docs/evidence/guardian-compositor-mask-gaps-20261106.json); [November 16 recheck](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-png-fix-and-expanded-forum-coverage-2026-11-16); [JPEG XL fixes](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#guardian-jpeg-xl-circles-and-remaining-dropdown-border-2026-11-16); [border fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#guardian-solid-border-sample-ownership-2026-11-16) |
| [The Verge](https://www.theverge.com/) | November 17: shadow, WebP and SVG merge fixes give zero diagnostic pixels twice on the complete frozen viewport. Production `ad081765` confirms zero twice on November 17; live acceptance remains pending. Earlier checkpoints retained. | [Damage-clip fix](docs/FORUM_NEWS_EXPANSION.md#verge-retained-text-and-disjoint-frame-damage-2026-11-06), [evidence](docs/evidence/verge-glyph-damage-clips-20261106.json); [November 16 recheck](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#published-png-fix-and-expanded-forum-coverage-2026-11-16); [shadow color fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-css-shadow-color-2026-11-16); [enlarged WebP fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-enlarged-webp-crops-and-runtime-shader-pins-2026-11-16); [local SVG filter fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-local-svg-drop-shadows-2026-11-16); [exact merge fix](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#verge-svg-merge-allocation-and-transparent-borders-2026-11-17) |
| [Pikabu](https://pikabu.ru/) | November 17 native archive capture exceeds the harness 3 GiB RSS guard; no valid completed screenshot or new pixel pass. | [Original checkpoints](docs/ADBLOCK_POPULAR_SITES.md); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [TechCrunch](https://techcrunch.com/) | November 17 diagnostic: 173,970 pixels vs agreeing Brave replays and saved source. Current rendering and source/replay version gates remain open. Earlier strict checkpoint retained. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [Engadget](https://www.engadget.com/) | November 17 diagnostic: Vox/first Brave 66,383 pixels; Brave references vary by 9,363 and source/first Brave by 100,163. Source/replay browser versions differ. Current reference and rendering gates remain open. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [The Register](https://www.theregister.com/) | November 17 diagnostic: six pixels vs agreeing Brave replays and saved source. Source/replay versions differ; current rendering acceptance open. Earlier strict checkpoint retained. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [Slate](https://slate.com/) | November 17 native capture exists, but its full-uBO oracle times out in CDP; no new acceptance. Earlier source/replay gate and RGBA controls retained. | [RGBA controls](docs/FORUM_NEWS_EXPANSION.md#slate-rgba-decoder-and-mixed-photo-controls-2026-11-06), [evidence](docs/evidence/slate-rgba-decoder-controls-20261106.json); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [WIRED](https://www.wired.com/) | November 17 audit is interrupted by disk-full errors; no new pass. Earlier first-frame checkpoints and source/replay gap retained. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json); [November 17 screen](docs/OPTIMIZED_SITES_PIXELS_2026_11_12.md#remaining-forum-and-news-archive-screen-2026-11-17) |
| [Discord](https://discord.com/) | Vox/saved source 0 on `0f2d286a…` after image-coordinate fixes. Both agreeing Brave replays differ 598 from that source; strict frozen-replay gate remains open. | [Current checkpoint](docs/FORUM_NEWS_EXPANSION.md#local-background-origins-and-catalog-controls-2026-11-06), [evidence](docs/evidence/discord-background-local-origin-20261106.json) |
