# vlang.io rendering against Brave

Pixel-perfect parity remains open. The current settled, archived comparison at
1280 × 800 CSS pixels and scale 1 has **4 differing pixels at the top** and
**zero at every sampled 800-pixel scroll position from Y 2400 through 7200**,
with **4 at Y 8000**. The news/reviews viewport at Y 9600 has **137** differences,
and the community viewport at Y 10400 has **160**. The sponsor viewport at
Y 1600 has **452** differences, and the bottom has **97**. Lilly at Y 8800 now
has **14,681** differences against the full-resolution Brave variant, despite
matching a previously observed reduced-decode variant exactly. Some review
glyphs, sponsor edges and a footer book image still differ.
Copy-button and book-cover geometry agree with Brave.
These results do not establish full live-page or scale-two parity.

## Capture readiness correction

`5c39c7d1` fixes an intermittent 6.984375 CSS-pixel layout shift during ordered
captures. A synchronous cached image response could dirty layout midway through
the lazy-image queue. The tail remained deferred, but the active network map was
empty. Capture readiness then allowed scrolling away before the remaining
nearby images started.

Readiness now includes current deferred requests that can resume at the current
viewport. Polling schedules another normal frame to service them. Distant,
cancelled, and superseded requests do not block capture. The regression uses
synchronous data-URL completions to reproduce the cache-hit ordering without
network timing; it fails against the preceding implementation.

After the fix, all seven sponsor requests complete before the initial viewport
is released. The feature grid starts at 2530.828125 CSS pixels in both repeated
warm-cache checks. The dedicated `capture-lazy-scroll-order` HTTP fixture also
matches its Brave reference exactly in both scrolled checks. A viewBox-only
sponsor SVG has zero natural dimensions but a nonzero used box; that is not an
unfinished request.

## Verification and retained evidence

Artifacts are under `Build/vlang-parity-20261031/`:

- `lazy-readiness-before-run.json`: the new regression fails at the readiness
  assertion before the implementation change.
- `capture-focus-{none,boehm}-{build,run}.json`: all 13 lazy-image, font-resource,
  and capture-scroll test functions pass in both memory modes.
- `readiness-production-{guard,status}.json`: the signed production build
  succeeds under the default 12 GiB guard. Only an unrelated native test source
  changes during compilation; implementation inputs remain stable.
- `readiness-browser-verified/status.json`: document-only captures, image
  completion and layout audits, comparison metrics, and bundle hashes. The
  initial top capture is carried from `readiness-browser/`; its PNG and guard
  are identified explicitly. Its original supervisor stopped on an overly
  strict natural-width assertion for the viewBox-only SVG.
- `readiness-smoke-status.json` and `readiness-smoke.log`: all eleven default
  screenshot cases and `svg-image-source-switch-same-size` pass. Nine are exact;
  three pass their existing tolerances. The bundle identity remains unchanged.
- `readiness-live/status.json`: a fresh `https://vlang.io/` navigation completes
  with author scripts enabled, fonts loaded, zero native errors, and all five
  visible image requests complete. Its top capture was visually inspected.
  Carousel and media timing make this a loading check, not a pixel comparison.

The readiness-fix executable is
`29de8747966bd8ba46f8e6b7d4b720aad40f04d58c66e80c903290668f8dfe27`,
also pinned in `Vox-readiness.app`. Native library and resource hashes are in
the browser and smoke identity receipts. Browser runs use fresh processes and
private profiles, with 3 GiB runtime guards and the test display away from the
pointer.

The fully local archive is
`Build/vlang-instructions-20261030-1540/fixture/`, with HTML SHA-256
`dcf945273ed128180fa6f683d871ca4b1ef958ed8df4e366c1d4e31273f8589b`.
Its 31 asset hashes are checked before capture. Scripts are removed, animations
are disabled, fonts are local, and the video has a fixed poster. Live scripted
captures require separate validation and do not supply deterministic pixel
comparison credit.

## Remaining raster investigation

The lower mismatch primarily covers the translucent Veb card backgrounds.
Brave's retained SkPictures show direct gradient shaders there and a picture
shader for the following ORM card. Forcing every gradient into a picture is
therefore not a supported correction.

Uncommitted diagnostic bundles and probe sources remain only under `Build/`.
A transparent gradient leaf with the observed layer origin reduces the selected
6400 comparison to 75,224 differing pixels, but does not establish a correct
general layer implementation. Changing constant-alpha interpolation to premul
on an ABI-stable probe leaves that result unchanged. Moving the origin by one
pixel regresses it; direct Dawn leaf replay also regresses it to 193,477.
The first GPU-compositing probe lost opacity and is invalid for acceptance.
A corrected injection preserves opacity but leaves the same 75,224 differences.
Replaying the observed complete layer tile grid reduces the diagnostic to
12,488 differences. That probe hardcodes measured geometry and is not a
general renderer implementation. None of these probes is installed in the
production bundle or committed as renderer behavior.

That earlier paint-chunk metadata prototype remained outside production.
The viewport metadata section below records the subsequently validated
implementation and its remaining mixed-content replay limit. Keep the top reference and settled geometry
as regression checks; reject captures whose lazy images or fonts leave a
different document geometry. `e2f4fcfe` pins Brave's process device scale as well
as its CDP scale so display-dependent font rasterization does not contaminate
the comparison.

## Root CSS fade interpolation

`7a3bb534` gives CSS root gradients an explicit premultiplied interpolation
mode while preserving SVG's straight interpolation. The flag reaches Metal
and retained picture shaders and belongs to the raster cache key. An
alternating SVG/CSS GPU comparison caught a missing cache-key field during
implementation; the corrected backend passes all four independent Metal/Dawn
comparisons, and the preceding backend fails the radial CSS case.

The new `css-premultiplied-fades` fixture improves from two one-level
differences to zero at 1024 × 768 and scale 1. Two fresh Brave references agree
exactly. The existing `css-radial-gradient`, `fractional-gradient-pattern`,
`scrolling-gradient-raster`, and `gradient-compositor-backdrop` fixtures remain
exact. Applying the interpolation switch to the isolated compositor fallback
regresses the last fixture by one pixel, so that path retains its established
behavior pending complete CSS compositor pictures. The new fixture's scale-two
diagnostic improves from 280,090 to 280,084 differing pixels; its separate
raster mismatch remains open.

The settled vlang archive remains at **9 differing pixels at the top** and
**147,641 at scroll Y 6400** after this fix. A live scripted navigation again
loads its fonts and five visible images with zero native errors. The twelve
default and SVG image-invalidation screenshot checks pass; ten focused V test
functions pass with both no collector and Boehm. Native backdrop/tile checks
pass under AddressSanitizer, and the cache checks also pass with
UndefinedBehaviorSanitizer.

The final executable is
`cbda325e3c98a292d39966eec59c08f597dcc8ad698c4df00537b3dec05d9de2`,
pinned with its libraries in `Vox-css-premul-root.app`. Evidence under the
same `Build/vlang-parity-20261031/` directory includes:

- `css-premul-focus-{none,boehm}-{build,run}.json` and
  `css-premul-native-v6/`: focused compilation/runtime guards and GPU checks.
- `css-premul-cache-test-{build,run}.json`: cache mutation checks with both
  sanitizers.
- `css-premul-production-{guard,status}.json`: the production build succeeds.
  Unrelated HTTP sources and the cache header change during compilation. The
  final cache library and root-only native policy are rebuilt separately under
  the shared production lock; `css-premul-root-policy-status.json` records the
  final source/library identities. The bundle copy is verified by file
  basename and SHA-256; an earlier whole-map assertion compared different
  absolute paths and failed after an otherwise successful copy.
- `root-fades-root-final/`, `css-premul-root-gradient-regressions/`,
  `css-premul-root-page-final/`, `css-premul-root-smoke-status.json`, and
  `css-premul-root-live/`: final fresh-process browser checks.

The broader CSS compositor eligibility experiment was rejected after its
1024 × 768 fixture regressed from 33,850 to 176,261 differing pixels. Its patch,
test, and fixture remain deferred under `Build/`; those changes are absent
from master and the final production bundle. A separate reference-tool fix,
`f9b865f4`, keeps windowed Brave captures rendering while occluded. A fresh
scroll-6400 reference using that option agrees exactly with the settled
reference above.


## Scrolled pictures and clipped generated tiles

`659d8d05` retains the root scroll translation when locating a non-root
picture in its compositor tile grid. The native regression exercises explicit
bridge scrolling and scrolling already projected into the display-list matrix,
at device scales 1 and 2. The preceding implementation fails the projected
scroll case. `root-scrolled-compositor-verification.json` and
`shared-layer-before-scroll-{compile,run}.json` retain the controls under
`Build/vlang-parity-20261031/`.

`72a80bd2` intersects a generated gradient tile's recorded ink with its own
background clip and ancestor clip. Fully clipped repetitions no longer enlarge
the picture target or disable its tile grid. Four added native cases cover
direct and picture-pattern gradients at both device scales. The AddressSanitizer
run passes; the control with the preceding ink-bounds calculation fails the
same bounds assertion. Receipts are `gradient-clipped-bounds-{compile,run}.json`
and `gradient-clipped-bounds-control-{compile,run}.json`.

The first broader viewport candidate lost code text at scroll Y 6400 and
exposed a missing scrolling-background paint. Those rejected captures remain
in `viewport-layer-page-first/` and `compositor-css-viewport-layer/`; the
following implementation fixes both causes.


## Viewport paint metadata and complete CSS pictures

`b931b0d7` retains empty scroll hit-test boundaries and ordinary box bounds
when grouping paint chunks inside the root's expanded interest rect. It keeps
culled command spans separate, preserves complete effect scopes and fixed
content, and converts flattened viewport clips back to document coordinates
before testing their box bounds. The native text-loss regression only appeared
with a genuinely scrolled viewport recording; a complete recording at scroll
zero did not exercise it.

Eligible scale-one CSS gradient pictures retain their own backgrounds, text,
SVG and supported image draws. Generated-image patterns dither once. Flat opaque
scroll backgrounds also paint inside their contents picture; omitting that paint
introduced a separate quantization step. Higher device scales retain the
preceding planner and CSS picture policy because the direct-gradient phase
still differs there.

The frozen 1280×800, scale-one archive compares as follows:

| Scroll Y | Earlier root-fade bundle | Viewport bundle |
| --- | ---: | ---: |
| 0 | 9 | 9 |
| 6400 | 147,641 | 65,446 |

At 6400, eight pixels exceed three channel levels, four exceed ten, and the
maximum channel error remains 17. The other differences are one-level raster
rounding. These results do not establish pixel-perfect vlang rendering. The
whole-page picture still falls back when it reaches a rounded image with an
embedded color profile; the atomic recorder reports one blocked image.
`picture-image-flags-probe-page/` identifies that restriction separately from
acceptance measurements.

The new `culled-scroll-overlap-gradient` fixture improves from 159,392 differing
pixels to zero at 1280×800 and scroll Y 6400. Two fresh Brave references agree
exactly, and the focused native-browser regression requires exact RGBA equality.
The layout/diagnostic fixture `compositor-css-gradients` improves from 33,850
to 24 differences at 1024×768 and scale one. Its scale-two comparison retains
its preceding 86,723 differences; a rejected broader policy increased that to
168,111, so it was disabled at that scale.

The accepted executable is
`87fd6654400733b965a87a55e8553eb9c7b9a45a098bb660a572295d8bf95bd5`,
pinned with its libraries in `Vox-viewport-accepted.app`. The implementation
inputs remain unchanged across compilation; only unrelated binding/content
sources change. Receipts under `Build/vlang-parity-20261031/` include:

- `viewport-accepted-production-{guard,status}.json` and
  `viewport-accepted-identity.json`: production build, source and bundle hashes.
- `viewport-accepted-focus-{layout,main}-{none,boehm}-{build,run}.json`:
  seven layout and 49 main-package test functions pass in both memory modes.
- `viewport-layer-native/` and `gradient-clipped-bounds-{compile,run}.json`:
  the five sanitized native suites and the added generated-tile bounds cases.
- `viewport-accepted-page/`, `viewport-accepted-gradient-regressions/`,
  `culled-scroll-overlap-reference-agreement.json`, and
  `compositor-css-accepted-2x/`: fresh-process comparisons. All four existing
  gradient fixtures remain exact.
- `viewport-accepted-smoke-status.json`: fourteen screenshot checks pass,
  including SVG image invalidation and both canonical turbulence cases;
  the executable and library identities stay unchanged.
- `viewport-accepted-headless.json` and `viewport-accepted-live/status.json`:
  startup succeeds, and the live scripted page completes with loaded fonts,
  five completed visible images and zero native errors.

A broader 43-function layout check retains one existing failure in
`test_canvas_background_keeps_distant_page_content_in_the_root_raster`.
The preceding planner and its original record types independently produce
that same two-layer result; `canvas-original-types-control-v3-{build,run}.json`
retains the control. The assertion was not weakened. This failure is separate
from the passing focused metadata checks above.


## Rounded color-managed images in complete pictures

`ad869c6c` removes the remaining image restriction that aborted the Vlang
feature-grid picture. Rounded clips stay in the recorded canvas. Image payloads
carry premultiplied source pixels and numerical transfer/gamut values across
the independently linked Skia versions; ordinary sRGB payloads keep their
original format. The receiving GPU converts tagged uploads to eight-bit sRGB
before filtering. Converting on the CPU or during the final draw changes the
sampled pixels. Complete images also retain natural-coordinate drawing, and
mipmap eligibility uses the unrounded device size.

The frozen 1280×800, scale-one comparison improves from **65,446 to 251 differing
pixels at scroll Y 6400**. The top remains at **9**. Of the 251 lower differences,
228 are inside the color-managed screenshot and 23 are outside it. Most differ
by one channel level; eight underline pixels exceed three levels, with a
maximum of 17. These residuals and other viewports remain open.

`compositor-rounded-profiled-images` exercises rounded Display P3 and untagged
images at natural and enlarged sizes in a scrolled gradient picture. It improves
from 65,187 differing pixels to zero at 1280×800, scroll Y 6400. Two fresh Brave
references agree exactly. An earlier absolute-positioned diagnostic did not
engage the intended complete-picture path: both old and new bundles retained
38,306 differences. It supplies no acceptance credit. The final in-flow fixture
and native tests verify the intended path separately.

Evidence under `Build/vlang-parity-20261031/` includes:

- `profiled-picture-native-checks/`: all seven native suites pass under
  AddressSanitizer, including 96 complete image scenes across scales 1 and 2,
  three color spaces, square/rounded clips, cropped/full sources, nearest/linear
  sampling, and opaque/translucent texels. The preceding recorder fails the
  independent scene comparison in `profiled-image-negative-control-*.json`.
- `picture-image-transport-{old,new}-abi-{compile,run}.json`: both Skia versions
  pass the payload tests with AddressSanitizer and UndefinedBehaviorSanitizer.
  Five source color spaces preserve their bytes and profile, while truncated,
  oversized, non-finite and malformed payloads are rejected.
- `profiled-image-scroll-gradient-{flow,repeat,baseline}/` and
  `profiled-image-scroll-reference-agreement.json`: the matched browser fixture
  comparisons and independently repeated Brave reference.
- `profiled-picture-regressions/status.json`: the four existing gradient
  fixtures, PNG ICC sampling/matrix fixtures and mip-first-use fixture all
  remain exact.
- `profiled-picture-browser-test.json`, `profiled-picture-smoke-status.json`,
  `profiled-picture-headless.json` and `profiled-picture-live/status.json`:
  the new automated browser regression, fourteen screenshot checks, startup,
  and live scripted navigation pass. Live fonts and all five visible image
  requests complete with zero native errors. That live check is not a matched
  pixel comparison.
- `profiled-picture-installed-page/` and
  `profiled-picture-installed-identity.json`: fresh-process full-page captures
  and the latest completed production identity. The shared production build
  already included this native change, so no additional build or bundle
  replacement was needed. It is pinned in `Vox-profiled-installed.app`.

The installed executable is
`50678667e6408574074c5f7472ea601a61208ff038ff91d4fd6773a8daa91740`;
its native-library hashes are recorded alongside it. The private candidate's
native inputs remain unchanged during its guarded build. All runtime checks
use the 3 GiB memory guard and fresh processes. The earlier Retina CSS-picture
policy restriction remains in place; passing native scale-two scenes does not
establish Retina page parity.


## Underline paint order

`1ae4227d` paints Chromium-profile underlines and overlines before glyphs,
and line-through afterward, including selected spans and ancestor decorations.
This follows [CSS Text Decoration painting order](https://www.w3.org/TR/css-text-decor-3/#painting-order)
and the captured Brave picture. Previously a translucent underline blended over
the descenders of the Veb link even though the skip-ink stripe correctly found
no intersection. The translated LibWeb profile retains its existing order.

The lower frozen viewport improves from **251 to 242 differing pixels**. All
242 now differ by one channel level: 228 are inside the color-managed image
and 14 are at rounded card corners. The top remains at 9 differences.
`translucent-underline-paint-order` improves from 114 differences to zero at
800×600 and scale 1. Two fresh Brave references agree exactly.

Evidence in `Build/vlang-parity-20261031/` includes:

- `decoration-order-before-{build,run}.json`: three new ordering assertions fail
  against the preceding implementation; the LibWeb control passes.
- `decoration-order-focus-layout-{none,boehm}-{build,run}.json`: eight focused
  functions pass in both memory modes.
- `decoration-order-production-{guard,status}.json`: the production build passes
  under the default 12 GiB guard, with the required implementation inputs stable.
  Unrelated stylesheet/preload implementation and test files change during the
  build. `decoration-order-production-identity.json` records the completed
  executable and libraries, pinned in `Vox-decoration-order.app`.
- `underline-order-{narrow-baseline,candidate,repeat}/` and
  `underline-order-reference-agreement.json`: exact browser regression and
  repeated reference. The earlier larger-font diagnostic also exposed separate
  underline geometry differences and is not the accepted fixture.
- `decoration-order-page/`, `decoration-order-smoke-status.json`,
  `decoration-order-inline-regressions.json`, `decoration-order-headless.json`,
  and `decoration-order-live/status.json`: fresh page comparisons, fourteen
  screenshot checks, all forty inline browser regressions, startup and live
  scripted navigation pass. Live fonts and five visible image requests finish
  with zero native errors; this is a loading check, not pixel comparison credit.

The accepted executable is
`cf6d98ef8f239316a488dadc2d304e65edd99f8b37dbda2742903f0c8609e994`.
The remaining image investigation independently compares the actual embedded
ICC profile across both Skia versions: all 17 transported values agree exactly
in `image-profile-{old,new}-abi-run.log`. Profile parsing is not established as
a cause of those residual pixels. Full page and Retina parity remain open.


## Complete mipmapped image replay

`12668630` follows Chromium's [complete-source mipmapped image helper](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/cc/paint/paint_op.cc):
apply the decoded source scale to the canvas, then draw the uploaded image in
its own pixel coordinates. Keeping that scale inside `drawImageRect` changed
228 thumbnail pixels. The containment check retains the strict rectangle draw
when floating-point source adjustment falls below the image boundary.

The frozen 1280×800, scale-one comparison is now **9 differing pixels at the
top and 14 at scroll Y 6400**. The thumbnail is exact. All fourteen lower
residuals differ by one channel level at rounded card corners. This does not
establish complete-page, live scripted, or Retina pixel parity.

The native image regression now checks 200 independent GPU scenes. Large odd
source sizes reproduce the old mismatch; both 2482-to-621 and 2483-to-621 height
adjustments test the float containment boundary at scale two. Smaller scenes
retain the color-space, transparency, clipping, crop and sampling matrix at
both scales. Evidence under `Build/vlang-parity-20261031/` includes:

- `mipped-image-negative-control-v3-{compile,run}.json`: the preceding recorder
  fails the new large-source comparison by 1,968 channels.
- `mipped-image-native-final/`: all seven sanitized native suites pass, including
  all 200 image scenes. An initial independent reference rounded its expected
  source height to 621; retaining Chromium's float multiplication corrects that
  reference and adds the opposite rounding boundary as a separate case.
- `mipped-image-build-v2{,-inputs}.json`, `mipped-image-install-v2.json`, and
  `mipped-image-installed-{before,after}.json`: native-only build, stable source
  inputs and installation under the shared production lock. The first install
  attempt found the lock busy and made no changes. Private candidate validation
  continued before a later attempt acquired the now-free lock. No V or graphics
  dependency rebuild was needed.
- `mipped-image-final-page/` and `mipped-image-installed-page/`: independently
  launched candidate and installed-bundle comparisons both produce 9/14.
- `mipped-image-regressions/status.json`: all seven existing image/gradient
  references remain exact. `mipped-image-candidate-smoke-status.json` and
  `mipped-image-installed-smoke-status.json` retain fourteen passing screenshot
  checks for each bundle. The candidate uses copies of the capture scripts with
  only the binary path and repository root changed; their diffs are retained.
- `mipped-image-installed-headless.json` and
  `mipped-image-installed-live/status.json`: startup and live scripted navigation
  pass with fonts loaded, five completed visible image requests and zero native
  errors. Live loading is not matched pixel comparison credit.

The installed executable is
`6fdaa9be28a89efd95965f8579bd306088e73cebf98e26330df6ae09db37eabe`,
pinned with the native libraries in `Vox-mipped-image-installed.app`.
The reduced-precision experiment remains rejected under `dawn-f16-probe-*`:
it increased the top/lower mismatches to 3,653/7,005 and changed 2,602 pixels in
`fractional-gradient-pattern`. It was never installed. A separate tiny-image
first-use/cache diagnostic still differs at 2,026 pixels; neither that fixture
nor unsupported image combinations receives exact-parity credit from this fix.


## Gradient destinations and Metal image leaves

`e4ed5e42` transports the computed background destination for generated
gradients as well as ordinary images. Opaque border edges trim the painted
bounds while the original image tile still determines shader coordinates.
The half-border rounded bleed clip previously admitted a sliver of another
repeat; that extra paint caused the fourteen lower corner differences.
A per-draw native bounds record preserves the complete generated-image picture
when its visible paint is trimmed. It is copied immediately and cleared after
the draw. The independent trimmed-pattern test fails against the old behavior
by 19,758 channels.

The new `gradient-obscured-border-destination` fixture reproduces all fourteen
errors and now matches Brave exactly at 1280×800, scale 1 and scroll Y 6400.
Two fresh references agree. Seven layout and eleven main-package geometry tests
pass with no collector and Boehm, including translucent-border and translated
LibWeb controls. Native CSS picture coverage increases to sixteen cases.

`b58db23a` applies Chromium's decoded-pixel image transform to the ordinary
Metal image path too. That removes the five JPEG differences in the top
viewport. A new independent Metal/Dawn comparison covers sixteen combinations
of scale, odd source dimensions, rounded clips and transparency. The preceding
Metal library fails by 2,106 pixels; the candidate is exact. The float source
containment check also preserves the strict-rectangle fallback.

The installed archived captures now have **4 differing pixels at the top** and
**zero at scroll Y 6400**. The four top errors are one-level blue-channel
rounding inside the compilation panel's gradient. Full-page, live scripted and
Retina parity remain open.

Evidence under `Build/vlang-parity-20261031/` includes:

- `gradient-destination-before-{layout,main}-none-{build,run}.json`:
  both new V regressions fail against the preceding implementation.
- `gradient-destination-focus-{layout,main}-{none,boehm}-{build,run}.json`:
  focused geometry checks pass in both memory modes.
- `gradient-destination-pattern-before-{compile,run}.json` and
  `gradient-destination-native-checks/`: the independent cropped-pattern
  control fails, and all seven updated native suites pass.
- `gradient-destination-production-{guard,status}.json`: the production build
  passes with all required V/native inputs stable. Unrelated CSS/font/text
  sources and the later Metal image implementation change during compilation.
  The Metal library is built and installed separately afterward; the V build
  alone does not validate that later native change.
- `metal-mipped-image-test-v2-{before,candidate}.json`,
  `metal-mipped-image-final-{build,inputs}.json`, and
  `metal-mipped-image-install.json`: independent GPU controls, native-only
  build/source hashes and installation under the shared production lock.
- `all-rendering-native-accepted/`: all eight sanitized native suites pass,
  including 200 image pictures, sixteen CSS gradient pictures and sixteen
  Metal image comparisons. The preceding `all-rendering-native-final/` run
  overlapped replacement of its input library and failed its identity guard;
  that run is excluded from acceptance. The accepted rerun uses pinned modules.
- `gradient-destination-{baseline,candidate}/` and
  `gradient-destination-reference-agreement.json`: exact new browser fixture.
- `all-vlang-installed-page/`, `all-vlang-installed-smoke-status.json`,
  `all-vlang-installed-inline-regressions.json`, and
  `all-vlang-installed-gradient-regressions/status.json`: fresh installed
  captures, fourteen screenshot checks, all forty-one inline browser tests and
  seven exact image/gradient references pass without an identity change.
- `all-vlang-installed-headless.json` and
  `all-vlang-installed-live/status.json`: startup and live scripted navigation
  pass with fonts loaded, five completed visible image requests and zero
  native errors. Live loading does not supply matched pixel comparison credit.

The installed executable is
`f7bad678c22005f7a109e416c03d2ff61ffbdff349c7f21ad54a7dc422bab17f`,
pinned in `Vox-all-vlang-installed.app`; its libraries and source inputs are
recorded in `all-vlang-installed-after.json`. Page-coordinate rounded-rectangle
and inset-color probes did not change the fourteen corner errors. Endpoint
padding and transparent-stop probes did not remove the remaining four top
pixels. These diagnostic changes remain only under `Build/`.


## Source cropping before decoded image replay

`d1f6cbe0` applies Chromium's replaced-image content crop to the source and
snapped destination before native replay. Ancestor clips remain separate.
Source offsets and sizes use `gfx::MapRect`'s relative, float arithmetic;
transforming document-space edges first loses precision far down the page.
The native image leaf and retained picture recorder select the decoded upload
from the complete image at that draw scale, matching
[`DrawImageRectOp::Serialize`](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/cc/paint/paint_op.cc).
The final cropped draw retains its strict source constraint.

The new `replaced-image-source-crops` fixture exercises top and centered cover
images at scroll Y 9000. It improves from **359 differing pixels to zero** at
800 × 600 and scale 1. Two fresh Brave references agree exactly. The earlier
fixture with a generated-gradient backdrop has one remaining background pixel;
the committed fixture isolates image sampling with a solid backdrop. A mixed
image-size/color-space diagnostic remains non-exact and is retained only under
`Build/`; it does not supply conformance credit.

On the settled vlang archive, scroll Y 8000 improves from **13,070 to 4 differing
pixels**. The Gitly preview there is exact. At Y 8800, the GUI preview is exact
and the full viewport improves from **21,886 to 20,196**. The remaining mismatch
mostly covers Lilly. A full-resolution private probe matches Lilly but changes
other previews; decode/cache coordination remains under investigation. Fresh
Brave references agree exactly with the preceding references at all four
checked positions: 0, 6400, 8000, and 8800. The top remains at four differences
and Y 6400 remains exact.

Evidence under `Build/vlang-parity-20261031/`:

- `cropped-image-focus-main-{none,boehm}-{build,run}.json`: eight crop and
  retained-clip test functions pass in both memory modes.
- `cropped-image-picture-control-{compile,run}.json`: the preceding picture
  recorder fails the new cropped/minified source comparison.
- `cropped-metal-image-{test-compile,control-run}.json`: the preceding Metal
  leaf fails the first cropped case by 70,194 pixels.
- `cropped-image-native-accepted/`: all eight native suites pass, including
  200 independent color-managed image-picture scenes, 32 Metal/Dawn image
  comparisons, and 16 generated-gradient pattern cases. The earlier
  `cropped-image-native-checks/` run exposes an incorrect test expectation:
  halving an odd height of 2483 requires 1242, not 1241. Its failure is retained;
  the corrected fixed-size expectation passes every case.
- `cropped-image-production-{guard,status}.json`: production build succeeds,
  with all implementation inputs stable, in 208.46 seconds and a sampled peak
  aggregate RSS of 7.75 GiB under the default 12 GiB guard.
- `cropped-image-cover-{final,control-final,reference-repeat}/` and
  `cropped-image-cover-reference-agreement.json`: new browser fixture,
  negative control, and reference repeat.
- `cropped-image-installed-page/`, `cropped-image-page-ref-*.json`, and
  `cropped-image-installed-{before,after}.json`: fresh frozen-page captures,
  reference agreement, and stable installed executable/library identities.
- `cropped-image-installed-smoke-status.json`: all fourteen screenshot,
  selection, image-invalidation and turbulence checks pass.
- `cropped-image-installed-inline-regressions.json`: all 42 inline browser
  regressions pass. `cropped-image-installed-gradient-regressions/status.json`
  retains seven exact image and generated-gradient golds.
- `cropped-image-installed-headless.json` and
  `cropped-image-installed-live/status.json`: fresh headless startup and live
  scripted navigation pass; fonts and five visible image requests load with
  zero native errors. Live navigation remains a loading check.

The installed executable is
`e0176c5cbe01aedcd17c99cdbff62e8d1d987ffc7409a36805e4f0a141eaa85c`,
pinned with its signed libraries in `Vox-cropped-image-installed.app`.
The broader page sweep in `all-vlang-page-sweep/` remains non-exact and includes
a wrapping Copy button, table/text differences, and other raster discrepancies.
Full-page and scale-two parity remain open.


## Trailing fallback spaces and intrinsic button width

`450d02ad` preserves the visible text-item advance when removing a trailing
whitespace fragment after a font fallback. Chained fragments start at a nearest
LayoutUnit offset, while their ends use an upward-rounded item advance.
Subtracting the entire whitespace fragment box removed an overlapping 1/64
pixel from the preceding visible content. Intrinsic sizing then gave the
button too little room for its final definite-width layout.

The installed Copy button now matches Brave at **47.96875 × 26.5 CSS pixels**,
instead of 47.953125 × 43. Its surrounding region at scroll Y 800 is exact.
The complete viewport improves from **1,753 to 1,463 differing pixels**; the
remaining differences are outside that button. The new Arial/native-fallback
fixture improves from **332 differences to zero**, and two fresh Brave references
agree exactly. It needs no bundled font.

Evidence under `Build/vlang-parity-20261031/`:

- `trailing-fallback-before-{build,run}.json`: the new scalar regression
  compiles, then fails against the preceding implementation (1047 instead of
  1048 raw LayoutUnits). `trailing-fallback-focus-layout-{none,boehm}-{build,run}.json`
  records seven passing focused functions in both memory modes.
- `copy-button-native-fallback-{before,after}/` and
  `trailing-fallback-reference-repeat.json`: isolated negative control,
  pixel-exact candidate, and reference agreement.
- `trailing-fallback-resumed-production-{guard,status}.json`: successful
  production build, stable implementation inputs, 216.47 seconds, and a sampled
  peak aggregate RSS of 6.80 GiB under the default 12 GiB budget. The preceding
  `trailing-fallback-production` attempt was interrupted before completion and
  supplies no validation credit.
- `trailing-fallback-installed-page/`, `trailing-fallback-copy-region.json`, and
  `trailing-fallback-ref-*.json`: the Copy region is exact; top, Y 2400, Y 6400,
  and Y 8000 retain 4, 649, 0, and 4 differences respectively. Every fresh Brave
  reference agrees with its preceding reference.
- `trailing-fallback-installed-smoke-status.json` and
  `trailing-fallback-installed-inline-regressions.{json,log}`: fourteen
  screenshot/selection/invalidation/turbulence cases and all 43 inline browser
  regressions pass. Seven image/gradient golds remain exact in
  `trailing-fallback-installed-gradient-regressions/status.json`.
- `trailing-fallback-installed-headless.guard.json` and
  `trailing-fallback-installed-live/status.json`: startup and live scripted
  loading pass, with fonts loaded, five visible image requests complete, and
  zero native errors. Live loading remains separate from pixel comparison.

The signed executable is
`d76d7b939717bdfd35efb784bafb7713f68ae24a8cd7a581eec1c86e9153e180`,
pinned with its libraries in `Vox-trailing-fallback-installed.app`.
`trailing-fallback-installed-{before,after}.json` records unchanged bundle
identity across validation. Full-page and scale-two parity remain open.


## Fractional collapsed borders and table placement

`2b365f5c` keeps collapsed border halves at 1/64 CSS-pixel precision in
Chromium-policy layout and painting. LibWeb-policy documents retain the
translated whole-pixel split. Cell intrinsic measurements and final content
offsets use the same policy, including temporary height measurements.
[`TableBorders::GetCellBorders`](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/third_party/blink/renderer/core/layout/table/table_borders.cc)
divides both sides in LayoutUnits before pixel snapping.

Normal-flow table placement also retains the border edge actually used before
conflict resolution. An earlier intrinsic pass can already install collapsed
borders; subtracting the unsplit authored border again shifted tables with
explicit borders. The new regression covers both policies, repeated layout,
three odd border widths, and the resulting horizontal origin. Painting tests
cover scales 1 and 2 and odd raw LayoutUnit widths.

The `collapsed-table-fractional-shares` browser fixture improves from **978
differing pixels to zero** at 800 × 600 and scale 1. Two fresh Brave references
agree exactly. It covers translucent cell backgrounds behind horizontal border
halves and an explicitly bordered table's placement. Explicit cell minimums
keep empty-row height distribution out of this regression. A separate
intersection probe improves from 1,189 to 45 pixels; its remaining alpha
intersections are not accepted as conformance and remain only under `Build/`.

On vlang, the first table grid line now matches Brave at document coordinates
**680.5, 2821.75**, instead of 681, 2822.25. The table viewport still has **649
text differences**. Its first and last column widths differ by one raw
LayoutUnit; proportional surplus rounding remains a separate investigation.
The checked top, Y 6400, and Y 8000 retain 4, 0, and 4 differing pixels.

Evidence under `Build/vlang-parity-20261031/`:

- `fractional-table-origin-checked-{layout,painting}-{none,boehm}-{build,run}.json`:
  all 13 layout and ten painting functions pass in both memory modes.
- `fractional-table-halves-sized-{before,after}/` and
  `fractional-table-reference-repeat.json`: isolated negative control,
  exact candidate, and reference agreement.
- `fractional-table-production-reuse.json` and
  `fractional-table-reused-build-validation.json`: a running shared build
  already contained the initial border-half changes and supplied intermediate
  browser evidence. The nonblocking duplicate attempt returned 125; no second
  build ran while its lock was busy. That intermediate executable predates
  the subsequent placement fix.
- `fractional-table-origin-production-{guard,status}.json`: the final build
  succeeds in 217.08 seconds, with sampled peak aggregate RSS of 7.15 GiB.
  The supervisor then rejects whole-file stability because another session
  removes an unrelated shadow cutout in `paint_transport.v`. The other four
  implementation files remain stable. `fractional-table-origin-function-stability.json`
  verifies the complete table paint function is unchanged: reconstructing the
  preceding file differs only at that unrelated cutout and matches its recorded
  full-file hash. Both source versions are retained as
  `fractional-table-transport-{before,after}.v`; the raw rejection is preserved.
- `fractional-table-origin-installed-page/`: fresh frozen-page comparisons and
  geometry audits. `fractional-table-origin-installed-smoke-status.json` and
  `fractional-table-origin-installed-inline-regressions.{json,log}` record
  fourteen passing screenshot cases and all 44 inline browser regressions.
- `fractional-table-origin-installed-gradient-regressions/status.json`: seven
  image/gradient golds plus the existing intrinsic-table-height gold are exact.
- `fractional-table-origin-installed-headless.guard.json` and
  `fractional-table-origin-installed-live/status.json`: startup and live
  scripted loading pass with fonts loaded, five visible image requests complete,
  and zero native errors. Live loading supplies no pixel comparison credit.

The accepted signed executable is
`ad0fc19e7d258f157f9de1864b9950d3ea2d0d057a88c233d33126222049aa63`,
pinned with its libraries in `Vox-fractional-table-origin-installed.app`.
`fractional-table-origin-installed-{before,after}.json` records unchanged
installed identity across validation. Full-page and scale-two parity remain open.


## Automatic table column surplus rounding

`d62cee6f` matches Chromium's surplus distribution when every table column is
an unconstrained automatic column with positive max-content width. It computes
each proportional increment with one integer product and division, then gives
the remaining raw LayoutUnits to the last column. Blink uses the same
[`DistributeInlineSizeToComputedInlineSizeAuto`](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/third_party/blink/renderer/core/layout/table/table_layout_utils.cc)
branch and truncating
[`LayoutUnit::MulDiv`](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/third_party/blink/renderer/platform/geometry/layout_unit.h).
Fixed layout, percentage, constrained, mixed, zero-width, and LibWeb-policy
cases retain the existing path; this does not establish complete Chromium
table-sizing parity.

The vlang table viewport at scroll Y 2400 improves from **649 differing pixels
to zero**. The standalone `automatic-table-column-surplus` fixture improves
from **210 differences to zero**. Fresh Brave references agree exactly with
the preceding captures. Other checked vlang positions retain 4, 0, 4, and
20,196 differences at Y 0, 6400, 8000, and 8800 respectively.

Evidence under `Build/vlang-parity-20261031/`:

- `column-distribution-before-layout-none-{build,run}.json`: the original
  regression compiles and fails against the preceding distribution.
  `column-distribution-expanded-layout-{none,boehm}-{build,run}.json` records
  fourteen passing focused functions in each mode. The new test covers both
  policies, surplus and exact-fit widths, border spacing, and both directions
  across sixteen scenarios.
- `column-distribution-production-{guard,status}.json`: successful production
  build with stable implementation input, 219.18 seconds, sampled peak aggregate
  RSS of 6.19 GiB under the default 12 GiB guard. Only test inputs change during
  compilation.
- `column-distribution-installed-page/`, `column-distribution-ref-*.json`, and
  `column-distribution-reference-repeat.json`: fresh archived comparisons,
  geometry audits, and repeated reference agreement.
- `column-distribution-installed-smoke-status.json` and
  `column-distribution-installed-inline-regressions.{json,log}`: fourteen
  screenshot/selection/invalidation/turbulence checks and all 45 inline browser
  regressions pass.
- `column-distribution-installed-gradient-regressions/status.json`: all eight
  image, gradient, and intrinsic-table-height golds remain exact.
- `column-distribution-installed-headless.guard.json` and
  `column-distribution-installed-live/status.json`: startup and live scripted
  loading pass, fonts load, all five visible image requests complete, and native
  errors remain zero. Live loading supplies no matched pixel-comparison credit.

The signed executable is
`397cc65cf55ae3e4f2acc56492bed208949ea1e09471461a22bee6f3ccf38127`,
pinned with its libraries in `Vox-column-distribution-installed.app`.
`column-distribution-installed-{before,after}.json` records unchanged installed
identity across validation. Full-page and scale-two parity remain open.


## Definite flex bases and cross-axis limits

`8448f210` preserves a definite used flex basis in Chromium-policy documents.
Cross-axis min/max constraints still clamp the eventual cross size, but they no
longer feed back through the natural aspect ratio into that definite basis.
Content-based sizing and LibWeb-policy behavior retain their translated path,
including the existing column-canvas regression. This follows
[Flexbox 9.2(A)](https://drafts.csswg.org/css-flexbox-1/#algo-main-item) and Blink's
[`base_border_size` resolution](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/third_party/blink/renderer/core/layout/flex/flex_layout_algorithm.cc).

The second book cover now has Brave's **60 × 88 CSS-pixel** used box instead of
58.03125 × 87.96875. Its caption positions agree, and total document height
matches **11,500.5 CSS pixels**. The archived Y 10400 comparison improves from
**14,330 to 9,000 differing pixels**, and Y 10664 improves from **7,912 to 360**.
Other checked positions retain their preceding results, including exact Y 2400
and 6400 captures. Fresh references agree at all eleven positions. Remaining
one-level raster differences and unrelated image sampling are not conformance.

Evidence under `Build/vlang-parity-20261031/`:

- `definite-flex-basis-before-v2-layout-none-{build,run}.json`: the corrected
  isolated suite compiles, then fails with 40 instead of 100 CSS pixels. The
  first `before` compile omitted a helper and supplies no negative-control
  credit. `definite-flex-basis-focus-layout-{none,boehm}-{build,run}.json`
  records all eight focused functions passing in both modes. The new test
  covers both policies, rows and columns, and explicit versus auto flex bases.
- `definite-flex-basis-{before,after}-browser/` and
  `definite-flex-basis-reference-repeat.json`: the new standalone fixture
  improves from **6,639 differences to zero**, with exact repeated references.
- `definite-flex-basis-production-{guard,status}.json`: successful production
  build with stable implementation input, 207.83 seconds, sampled peak aggregate
  RSS of 8.06 GiB under the default 12 GiB budget. Only temporary test sources
  change during compilation.
- `definite-flex-basis-installed-page/` and `definite-flex-basis-ref-*.json`:
  fresh archived captures, geometry audits, and reference agreement.
- `definite-flex-basis-installed-smoke-status.json` and
  `definite-flex-basis-installed-inline-regressions.{json,log}`: fourteen
  screenshot/selection/invalidation/turbulence checks and all 46 inline browser
  regressions pass. Eight image, gradient, and intrinsic-table-height golds
  remain exact in `definite-flex-basis-installed-gradient-regressions/`.
- `definite-flex-basis-installed-headless.guard.json` and
  `definite-flex-basis-installed-live/status.json`: startup and live scripted
  loading pass with loaded fonts, five completed visible image requests, and
  zero native errors. Live loading supplies no matched pixel-comparison credit.

The signed executable is
`588e99f41112f9986419a766bf7682e66736886f809ea296a07c19325ff983be`,
pinned with its libraries in `Vox-definite-flex-basis-installed.app`.
`definite-flex-basis-installed-{before,after}.json` records unchanged installed
identity across validation. The browser test method was included by a concurrent
shared commit before the implementation commit. Full-page and scale-two parity
remain open.


## Letter spacing and optional ligatures

`a0b9d9ff` disables the optional HarfBuzz `liga`, `clig`, and `calt` features
for nonzero letter spacing in Chromium-policy text. Both signs of spacing use
this rule; zero letter spacing, word spacing alone, and LibWeb policy retain
their previous shaping. Required script features remain HarfBuzz defaults.
This follows Blink's
[`FontFeatureRanges::FromFontDescription`](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/third_party/blink/renderer/platform/fonts/shaping/font_features.cc).
General CSS font-feature settings are still not passed through this platform
font record; this fix does not establish support for those overrides.

The Times fixture improves from **2,560 differing pixels to zero**. The archived
profiler viewport at Y 4800 improves from **208 to zero**, and Y 8800 improves
from **20,196 to 20,163**. Fresh Brave references agree exactly at all eleven
positions shared with the preceding sweep. The complete current sampled results
at scale 1 are:

| Scroll Y | Differing pixels |
| --- | ---: |
| 0 | 4 |
| 800 | 1,463 |
| 1600 | 22,821 |
| 2400 | 0 |
| 4000 | 0 |
| 4800 | 0 |
| 5600 | 0 |
| 6400 | 0 |
| 8000 | 4 |
| 8800 | 20,163 |
| 9600 | 2,982 |
| 10400 | 9,000 |
| 10664 | 360 |

Evidence under `Build/vlang-parity-20261031/`:

- `spaced-ligatures-before-v2-platform-none-{build,run}.json`: the corrected
  regression compiles, then fails against the preceding shaping with one
  glyph instead of two for spaced Chromium text. The first negative control
  assumed the wrong LibWeb fallback face and supplies no acceptance evidence.
  `spaced-ligatures-focus-platform-{none,boehm}-{build,run}.json` records eight
  focused functions passing in both memory modes, including repeated cache
  use, UTF-16 glyph spans, advance truncation, and CoreText hyphens.
- `spaced-ligatures-{before,after}-browser/` and
  `spaced-ligatures-reference-repeat.json`: standalone comparisons with exact
  repeated Brave references.
- `spaced-ligatures-production-{guard,status}.json`: successful production
  build with all implementation inputs stable, 188.60 seconds, sampled peak
  aggregate RSS of 8.11 GiB under the default 12 GiB guard.
- `spaced-ligatures-installed-page/` and
  `spaced-ligatures-reference-repeat-page.json`: fresh archived comparisons,
  geometry audits, bundle identities, and repeated reference agreement.
- `spaced-ligatures-installed-smoke-status.json` and
  `spaced-ligatures-installed-inline-regressions.{json,log}`: all fourteen
  screenshot/selection/invalidation/turbulence checks and 47 inline browser
  regressions pass. All eight image, gradient, and intrinsic-table-height golds
  remain exact in `spaced-ligatures-installed-gradient-regressions/`.
- `spaced-ligatures-installed-headless.guard.json` and
  `spaced-ligatures-installed-live/status.json`: startup and live scripted
  loading pass with loaded fonts, five completed visible image requests, and
  zero native errors. Live loading supplies no matched pixel-comparison credit.

The signed executable is
`a3a038e28e57a3648d8c72071cfa01c87e863e9be8ed68091358c4fc736f5120`,
pinned with its libraries in `Vox-spaced-ligatures-installed.app`.
`spaced-ligatures-installed-{before,after,final}.json` records unchanged
installed identity throughout validation. Private probes that route byte-color
text through GPU replay or replace a constant backdrop image with a solid fill
leave the Y 10400 and 10664 comparisons unchanged. They remain diagnostic
artifacts under `Build/`, with no production renderer change. Full-page and
scale-two parity remain open.

## Disjoint parent compositor spans

`47cafed0` preserves transparent parent-raster rounding across an independently
scrolling child when the native ink before and after that child is disjoint.
Native replay already closes and reopens the parent surface at those transitions;
the new eligibility check proves that these separate surfaces cannot blend with
each other or cover a child that Chromium composites above the parent.

The proof retains a three-CSS-pixel raster fringe at both edges and the native
float-precision guard. It checks individual leaves when their coarse unions
overlap, preserving empty space between separated backgrounds. Serialized SVG
bounds include Bezier and arc-generated conic controls. Ordinary TrueType runs
can use their glyph outlines; varied, synthetic, color, and unsupported outline
faces retain the broad font envelope. Inset shadows use their native content
clip. Scrollbar leaves use their actual ink instead of a layer union that can
include distant scrollports. Unknown geometry, unsupported scopes, fixed content,
and overlapping ink retain the previous replay path. Ordinary canvas culling
and retained glyph positions remain unchanged.

The standalone `compositor-disjoint-scroll-gap` fixture improves from **9,328
differing pixels to zero** at 800 × 600 and scale 1. Three agreeing Brave
156.1.98.60 references support its committed gold. On the archive, Y 9600
improves from **2,982 to 308**, and Y 10400 from **9,000 to 160**. Pixel-by-pixel
error auditing finds **2,674** and **8,840** removed differences respectively,
with no new or worsened pixels. All thirteen shared Brave references match the
preceding sweep exactly. The expanded sweep is:

| Scroll Y | Differing pixels |
| --- | ---: |
| 0 | 4 |
| 800 | 1,463 |
| 1600 | 22,821 |
| 2400 | 0 |
| 3200 | 0 |
| 4000 | 0 |
| 4800 | 0 |
| 5600 | 0 |
| 6400 | 0 |
| 7200 | 0 |
| 8000 | 4 |
| 8800 | 20,163 |
| 9600 | 308 |
| 10400 | 160 |
| 10664 | 360 |
| 10701 | 360 |

Y 10701 is the bottom: Brave reports that scroll offset, and Vox reports the
body at Y -10701 with height 11500.5. Both bottom captures retain the same 360
image differences. The remaining 308 review pixels include existing glyph
coverage errors; reducing the count does not establish exact text rasterization.

Evidence under `Build/vlang-parity-20261031/`:

- `compositor-gap-v10-focus-main-{none,boehm}-{build,run}.json` records 64
  focused functions passing in both memory modes. The corrected self-contained
  file also passes its eleven functions independently in
  `compositor-gap-v10-standalone-{none,boehm}-{build,run}.json`.
  `compositor-gap-v10-before-main-none-run.json` fails against the preceding
  viewport eligibility function.
- `compositor-gap-v10-pinned-verified-{target,negative,fixture}/` records fresh
  captures and exact repeated Brave references. The negative browser is a
  private signed copy of the same executable with only the new gap helper
  returning false; it restores both old viewport counts. Its exact byte patch
  and hashes are in `compositor-gap-v10-negative-browser.json`.
- `compositor-gap-v10-pixel-audit.json` records the removed differences and
  unchanged error masks. `compositor-gap-v10-pinned-page/` retains all sixteen
  captures, geometry audits, commands, and browser exits.
- `compositor-gap-v10-production-{guard,status}.json` records the successful
  production build: 258.08 seconds, sampled peak aggregate RSS of 8.06 GiB
  under the default 12 GiB guard. All five implementation inputs for this fix
  remain stable. Independent main/native-header and tooling changes during
  compilation are listed in the receipt and receive no validation credit here.
- `compositor-gap-v10-pinned-smoke-status.json` and
  `compositor-gap-v10-pinned-inline-regressions.{json,log}` record all fourteen
  screenshot/selection/invalidation/turbulence checks passing their existing
  bounds and all 48 strict browser regressions matching exactly. All eight
  image, gradient, and table golds remain exact in
  `compositor-gap-v10-pinned-gradient-regressions/`.
- `compositor-gap-v10-pinned-headless.guard.json` and
  `compositor-gap-v10-pinned-live/status.json` record startup and live scripted
  loading with loaded fonts, five completed visible image requests, and zero
  native errors. Live loading supplies no matched pixel-comparison credit.
- `compositor-gap-v10-pinned-all-{status,guard}.json` records the complete
  sequential validation and actual supervisor exit zero. Its aggregate runtime
  remains under the 3 GiB guard.

The signed executable is
`a1785ca9c26eb36849389505196e675c9206b4b180db95dcb2af185fc7c75cd2`,
preserved with its libraries in `Vox-compositor-gap-v10-installed.app`.
The first direct shared-bundle run is rejected because another session changed
its identity during capture. Accepted runs use the preserved completed production
bundle; `compositor-gap-v10-pinned-final.json` confirms its unchanged identity.
Private harness adapters bind only the repository/browser paths while retaining
the canonical screenshot comparisons and tolerances. Full live-page and scale-two
parity remain open.

## Resource-specific image decode reuse

`5fcca1f8` removes all 263 footer-logo differences. The header draws the same
500×500 resource at 60 CSS pixels, selecting a 63×63 upload. Its later 32-pixel
footer draw now retains that compatible upload instead of independently
selecting 32×32. Both the Metal image leaf and complete-picture replay receive
the selected size. This follows the compatible-image lookup in Chromium's
[GPU image decode cache](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.48/cc/tiles/gpu_image_decode_cache.cc).

Equal pixels at different URLs remain independent. A retained raster picture
keeps its existing requested-size decision, while a new picture can reuse
completed earlier decodes. Source pixels, alpha interpretation, dimensions and
color-profile changes invalidate that resource's history. The cache owns bounded
source snapshots rather than retaining borrowed pixel pointers: 32 MiB overall,
128 resources, at most 8 MiB per entry, and 64 retained request decisions per
resource. Oversized, planar and repeated inputs retain their preceding path.
This is compatible reuse for ordinary replaced RGBA images, not a complete
translation of Chromium's image scheduler or decode cache.

Three new 800×600, scale 1 golds have agreeing fresh Brave 156.1.98.60
references before the fix, after it, and with the same-build negative control:

| Fixture | Before | After |
| --- | ---: | ---: |
| `image-decode-resource-reuse` | 262 | 0 |
| `image-decode-compositor-reuse` | 0 | 0 |
| `image-decode-scrolling-reuse`, Y 8800 | 262 | 0 |

The concurrent compositor control prevents promoting another picture's in-use
decode prematurely. The scrolling case settles the initial viewport before
moving a distant image into a new compositor picture. The three resource files
contain identical bytes at distinct URLs; content equality cannot stand in for
resource identity.

On the archived page, Y 10664 and the bottom at Y 10701 improve from **360 to
97**. The other fourteen sampled positions retain byte-identical Vox captures.
Using one fixed Brave reference per viewport, the pixel audit records no new or
worsened pixels anywhere. All remaining bottom differences belong to the book
image. A private signed negative copy returns immediately from the new resource
identity setter, restoring both old fixture counts and all 263 logo differences
without changing the executable or other native code.

The initial fresh-pair sweep remains failed: Brave's Lilly pixels changed at
Y 8800, and its Y 10664 reference also varied despite unchanged reported scroll
coordinates. Both complete sets are retained; they are not presented as a
successful matched fresh-reference sweep. The separate fixed-reference audit
compares the unchanged native captures against the negative run's references.
An additional diagnostic headless Brave pair demonstrates that `decoding="async"`
alone changes the isolated Lilly crop by 14,994 pixels; it does not yet establish
the cause of the full-page variations or fix Lilly.

Evidence under `Build/vlang-parity-20261031/`:

- `image-decode-cache-focused/` records 115 ASan/UBSan checks passing, including
  source/profile mutation, independent URLs, retained pictures, byte/count
  eviction, malformed inputs and decode hints. Run the committed check with
  `python3 tools/test_chromium_image_decode_cache.py`.
- `image-decode-v2-{resource,compositor,scrolling}/` and
  `image-decode-v2-negative-{resource,compositor,scrolling}/` retain the exact
  fixture comparisons. `image-decode-v2-negative-browser.json` records the
  diagnostic native-library byte patch and identities.
- `image-decode-v2-{negative-page,page}/` retains all 32 fresh page captures;
  `image-decode-v2-all-{status,guard}.json` retains their failed reference check.
  `image-decode-v2-native-pixel-audit.json` records the fixed-reference audit.
  `image-decode-v2-footer/` independently records the fresh 97-pixel result.
- `image-decode-v2-production-{guard,status}.json` records production exit zero,
  243.42 seconds and sampled peak RSS of 8.24 GiB under the 12 GiB guard. Six
  feature input files remain stable; shared native files and unrelated headers
  change during compilation, so this is not a claim of a wholly frozen checkout.
- `image-decode-v2-pinned-smoke-v2-status.json` records fourteen screenshot checks
  passing their existing bounds. `image-decode-v2-pinned-inline-regressions-v2.log`
  records all 51 strict browser cases passing, and
  `image-decode-v2-pinned-gradient-regressions/` retains eight exact image,
  gradient and table golds. The earlier smoke adapter failed before launching a
  browser because its wrapper was missing; that failed receipt is preserved.
- `image-decode-native-{picture,metal}-run.json` records 200 independent native
  picture comparisons and 32 mipmapped leaf comparisons passing under ASan.
  `image-decode-v2-recovery-{status,guard}.json` records the remaining sequential
  checks with actual supervisor exit zero. Startup and live scripted loading
  pass, including loaded fonts, five completed visible image requests and zero
  native errors. Live loading supplies no matched pixel-parity credit.

The signed production executable is
`07ef545eb25728ef3b7e4db83b53044136eae6b0d1d9519a510a6d1688e4197a`,
preserved in `Vox-image-decode-v2-installed.app`. Its final identity is recorded
in `image-decode-v2-pinned-final.json`; `image-decode-v2-installed-final.json`
also confirms identical installed bundle bytes. Sponsor, Lilly, shadow, glyph,
gradient and book-image residuals, full live-page parity and scale-two parity
remain open.

## Screen blending with floating-point group opacity

`6e7472f4` extends the readable offscreen layer path to CSS screen blending.
The preceding Quartz transparency path quantizes fractional group opacity,
shifting otherwise matching colors by one level. The new compositor applies
opacity to premultiplied source channels as float32 and uses Skia's screen
coefficients, One and InverseSourceColor, before final byte rounding. Other
blend modes retain their existing paths.

The 800×600 `screen-opacity-composite` gold improves from **80,000 differing
pixels to zero**, with agreeing fresh Brave references before, after and in a
same-build negative control. A separate scale-two capture also matches exactly.
The fixture includes grayscale and unfiltered screen blending at opacity 0.85,
plus normal blending and full-opacity screen controls.

At archived Y 1600, differences improve from **22,821 to 452**. The audit removes
22,379 errors and introduces ten one-level errors. Nineteen pixels in total
worsen by one level. The mask of errors above three levels stays unchanged.
The other fifteen sampled positions have byte-identical native captures, including the
97-pixel footer. This is a partial page correction, not pixel-perfect sponsor
or effect-scene rendering.

An additional diagnostic scene with nested groups, clipped text, gradients and
SVG edges improves from 22,958 to 10,764 differences, but introduces 942 new
one-level errors. Its inputs, captures and audit remain under `Build/`; it does
not receive exact-conformance credit. These remaining raster and filter errors
need further work.

Evidence under `Build/vlang-parity-20261031/`:

- `screen-blend-focused-formatted/` records ASan/UBSan validation of 917,504
  pixels against fourteen independent GPU pictures: opaque and translucent
  sources/backdrops at seven opacities. Run
  `python3 tools/test_chromium_screen_blend.py` with a completed Dawn library.
- `screen-opacity-composite-before/`, `screen-blend-v1-{fixture,scale2}/` and
  `screen-blend-v1-negative-fixture/` retain the browser comparisons. The
  signed negative copy changes one comparison in `native_begin_css_effect_layer`
  to admit only normal blending into the offscreen path. Its exact instruction,
  disassembly and hashes are recorded in `screen-blend-v1-negative-browser.json`
  and `screen-blend-v1-effect-assembly.txt`.
- `screen-blend-v1-negative-target-control.json` records the negative browser's
  byte-identical native match to the preceding production browser at Y 1600,
  restoring 22,821 errors against the valid fixed reference. Its fresh Brave
  reference shows missing What Lab artwork and changed downstream geometry and
  is rejected. That failed reference and its 395,094-pixel comparison remain
  in `screen-blend-v1-negative-target/`.
- `screen-blend-v1-page/` explicitly uses fixed references from
  `image-decode-v2-negative-page/`; it is not a fresh paired Brave sweep.
  `screen-blend-v1-detailed-pixel-audit.json` preserves the introduced and
  worsened coordinates. `screen-blend-v1-scopes-audit.json` retains the
  nonconformant diagnostic scene's results.
- `screen-blend-v1-production-{guard,status}.json` records production exit zero,
  430.42 seconds and sampled peak RSS of 8.21 GiB under the 12 GiB guard. All
  four implementation dependencies for this fix stay stable; unrelated CSS,
  native corner/glyph work and test formatting changes are listed separately.
- `screen-blend-v1-pinned-smoke-v2-status.json` records fourteen screenshot
  checks passing their existing bounds. All 52 strict browser fixtures and all
  eight image/gradient/table golds pass. `screen-blend-v1-all-{status,guard}.json`
  records the sequential checks and actual supervisor exit zero under 3 GiB.
  Startup and live scripted loading pass with loaded fonts, five completed
  visible image requests and zero native errors.

Full-sweep credit belongs to the preserved production executable
`7cc8f303f57f2f7fc6e0c6f1122296c55556e8802ec3124602c44f29688f3c51`
in `Vox-screen-blend-v1-installed.app`, whose identity stays unchanged through
validation. Another session subsequently replaces the shared bundle; both
identities are retained in `screen-blend-v1-installed-final.json`. Fresh checks
of that latest bundle also pass the exact screen fixture and live scripted
loading in `screen-blend-latest-{fixture,live}/`. Its fixed-reference target
captures in `screen-blend-latest-target/` reproduce 4/452/97 differences at
Y 0/1600/10701. Those checks do not supply the preceding bundle's
broad-validation credit. Full live-page and scale-two parity remain open.


## CPU image resize consistency

`19dc02cc` makes retained pictures use the same Chromium-pinned CPU resizer as
native image leaves. The recorder previously used Ladybird's Skia, whose
sampling phase differs for some odd-sized downscales. With identical Lilly
pixels and numerical color profile, resizing 1191 × 690 to 596 × 345 produced
98,115 different pixels between the two Skia revisions. The leaf already used
the Chromium result; later retained-picture replay replaced it with the other
upload. The fix transports premultiplied RGBA through a bounded C API without
crossing Skia object ABIs. Older libraries retain their previous fallback.

The generated `odd-image-picture-upload` fixture places an odd-sized PNG in
tiles covered by an SVG picture. It improves from **44,844 differing pixels to
zero** at 800 × 600 and scale 1 against an unchanged Brave reference. Two fresh
Brave references agree byte for byte. The fixture's separate scale-two check
still has **983 one-level differences**; the old and new native PNGs are
byte-identical there. No tolerance or reference was changed to accept them.

The archived page at Y 8800 improves from **20,163 to 14,681** against the fixed
full-resolution Brave reference. This is not a monotonic pixel improvement:
4,244 previously matching pixels become different, 5,710 have greater maximum
channel error, and 12,848 improve. Against the independently retained
reduced-decode Brave screenshots in `image-decode-v2-page/` and
`cropped-image-probe-page/`, the result improves from **22,623 to zero**.
Both newly captured full-page Brave references in this run choose the
full-resolution variant and still differ by 14,681 pixels. The decode-choice
variation remains unresolved; matching the earlier variant does not establish
current full-page conformance.

All fifteen other sampled native page PNGs are byte-identical to the preceding
screen-blend bundle. Their counts stay 4/1463/452 at Y 0/800/1600, zero at every
sample from 2400 through 7200, 4 at 8000, 308 at 9600, 160 at 10400, and 97 at
10664 and 10701. Every captured document reports complete readiness, loaded
fonts and zero native errors. Live scripted navigation separately completes
with five visible image requests loaded; it supplies loading evidence only.

The new native check freezes 24 CPU resize hashes from Chromium's pinned Skia,
covering odd/even dimensions, opaque/translucent sources, color profiles,
strides, row padding and source immutability, plus identity copying and 29
invalid descriptors. It passes ASan/UBSan. The expanded GPU test passes 204
image scenes, including four half-sized odd-source cases. Restoring the old
recorder resizer fails the new case with 110,896 differing channels; the former
200-scene corpus did not expose that phase difference. All nine native
image/gradient programs pass, including 32 mipmapped leaves. The 115 decode
cache checks, fourteen screenshot smoke cases, 53 existing strict browser
fixtures, the new strict fixture and eight image/gradient/table golds pass.

Run the focused checks with `python3 tools/test_chromium_image_resize.py` and
`python3 tools/test_skia_gradient_backdrop.py`. Evidence is retained under
`Build/vlang-color-filters-20261101/`:

- [Resize oracle comparison](../Build/vlang-color-filters-20261101/resize-comparison.json),
  [fixed-hash check](../Build/vlang-color-filters-20261101/resize-final-runner/status.json),
  [GPU positive/negative checks](../Build/vlang-color-filters-20261101/resize-204-status.json)
  and `native-regressions/` identify the CPU difference and regression coverage.
- `odd-picture-{before,after,repeat}/` preserves the strict fixture's captures,
  browser identities, audits and guards. `odd-picture-scale-two{,-before}/`
  retains the unchanged failing scale-two comparison.
- [Fixed-reference sweep](../Build/vlang-color-filters-20261101/pinned-resize-fixed-page/status.json),
  [pixel movement](../Build/vlang-color-filters-20261101/lilly-pixel-movement.json),
  [other viewport audit](../Build/vlang-color-filters-20261101/full-page-regression-audit.json)
  and `pinned-resize-fresh-{a,b}/` retain both passing and failing comparisons.
- [Validation exits](../Build/vlang-color-filters-20261101/validation-status.json)
  accompany the individual runtime guards and logs. Capture-driver exit zero
  means capture completed, not that its pixel comparison passed.
- `pinned-resize-production-{guard,status}.json` records production exit zero,
  246.25 seconds and sampled peak RSS of 8.22 GiB under the 12 GiB guard.
  Another session changed unrelated Metal adapter code during compilation,
  so whole-file source stability is false. Adding the unchanged resize
  function to the preserved source reconstructs the pre-build hash; the other four feature
  inputs stay stable. `resize-feature-source-audit.json` preserves that limit.

The validated executable is
`433f15dc0ea95ad33ab6d835b8ecc990afbfec55f9a8f2741e0c8b3ff1049c51`,
preserved in `Vox-pinned-resize-installed.app`. Its native library hashes and
unchanged final identity are recorded in `validation-final-identity.json`.
These results correct CPU upload consistency, not the remaining Brave decode
choice, live-page differences or scale-two raster differences.

## Root scrolling and independent image grids

`48e8106d` restores the root scroll offset when locating an image inside an
independent compositor layer's raster grid. Display-list matrices already
project that scrolling into the image's viewport region. Subtracting only the
layer's document origin selected the wrong tile, or rejected the grid and
fell back to a tight image surface. The root-layer calculation is unchanged.
The resumed vlang footer exercises these coordinates, but its remaining
97-pixel book difference is unchanged by this fix.

The focused ASan/UBSan check compares 64 scenes against two independently drawn
complete GPU tiles. It covers both display scales, adjacent tile seams, four
MSAA selections, two root scroll offsets, browser chrome offsets and local
scrolling. All 64 scenes match exactly. Restoring the preceding formula rejects
32 grids and produces 352 differing pixels. A separate public-bridge comparison
uses equivalent projected and document coordinate bases: all sixteen scenes
match, while the old formula produces 88 differing pixels. The 42 existing root
image-row comparisons also remain exact.

Run the focused positive and negative checks with:

```sh
python3 tools/test_scrolled_image_grid.py --negative-control
```

Add `--bridge-library PATH` to exercise a completed browser's native text
library through the same sixteen public-bridge cases. The old completed
production library fails those cases; the candidate library and rebuilt
production library pass. The existing image-region harness passes 1,920 GPU
comparisons and 2,592 bridge/grid comparisons. Its non-root local-scroll cases
now describe their coordinate basis consistently; projected root scrolling is
covered separately by the new test. All eleven native image/gradient programs
pass. That broad run compiled the 64-scene test before the public-bridge cases
were added; the final focused run supplies the latter's separate coverage.

The private candidate passes 55 of 56 current strict browser fixtures. The
newly added CNN opaque-mask fixture fails with 120 one-level differences on
both the old baseline and candidate; their native PNGs are byte-identical.
The complete candidate suite therefore exits one, and is not a whole-suite
pass. Its fixed-reference vlang samples stay at 4/14,681/0/97 differences for
Y 0/8800/6400/10701. None of these results establishes full page parity.

Evidence is retained under `Build/vlang-decode-policy-20261101/`:

- [Focused positive/negative result](../Build/vlang-decode-policy-20261101/scrolled-grid-bridge-final/status.json)
  accompanies source/module hashes, commands, sanitizer logs and memory guards.
  Its `bridge-runtime.log` tests the preserved candidate native library.
- `image-region-regressions.{json,log}` and `native-regressions/` retain the
  existing comparison and eleven-program results.
- `image-grid-strict.{json,log}` retains the failed 56-case candidate run;
  [CNN baseline comparison](../Build/vlang-decode-policy-20261101/cnn-baseline-comparison.json)
  identifies the unchanged failure without waiving it.
- [Candidate page captures](../Build/vlang-decode-policy-20261101/image-grid-candidate-page/status.json)
  retain the unchanged sampled page errors against fixed earlier references.
- `image-grid-production-{guard,status}.json` records the successful production
  build: 457.07 seconds and 8.21 GiB sampled peak RSS under the 12 GiB guard.
  Other sessions changed shared source inputs during compilation, so whole-file
  stability is false. `image-grid-feature-source-audit.json` separately pins
  the unchanged grid function and the completed library's behavioral check.

The rebuilt browser is preserved in `Vox-image-grid-installed.app`, executable
`c1fac2b689de3a25e44a18519de1e4a4015432e5da021e944f075e5f30151ca1`,
native text library
`c6a1960392ff18ff854ec39e5904f8074dc59af06947771a9a4a287226516cfe`.
It passes startup, all fourteen screenshot smoke checks and eight exact
image/gradient/table golds. Its strict suite passes 55/56: the CNN fixture now
has seven one-level differences, byte-identical to the intervening completed
production baseline. That different baseline explains the difference from the
private candidate's 120-pixel failure; neither reduction is attributed to this
image-grid fix. `cnn-production-comparison.json` retains the comparison.

Both its frozen vlang navigation and separate live navigation exit 139 before
loading a document. The retained stacks locate the crash in
`begin_stationary_document_raster()`, which this mixed build acquired during
compilation. The nil-document guard is subsequently committed as `962b53ba`;
the preceding binary does not contain it. Those page checks fail, and the
aggregate validation exits one. The preserved candidate supplies separate
page evidence, not a successful result for the crashing production executable.
`image-grid-validation-status.json` retains every stage exit. The corrected
public-library check in `image-grid-production-gpu-v2-status.json` also audits
the actual production Metal and native text dylib loads; its earlier attempt
lost DYLD variables across the protected Python exec boundary and does not
establish GPU-library identity.

The completed candidate sweep captures all sixteen earlier page positions.
Every decoded RGBA buffer is byte-identical to the preceding pinned-resize
bundle, including the remaining Lilly and book errors. All sixteen documents
have complete readiness, loaded font sets, matching identities/viewports and
zero reported native errors; all audited visible image requests complete.
The candidate's separate live scripted navigation also completes with five
visible image requests loaded and zero native errors. This supplies loading
evidence only. `image-grid-candidate-{validation-status,page-audit}.json` and
`image-grid-candidate-live/status.json` retain these results and the unchanged
candidate executable/library identity.

### Partial-response decode diagnostic

A new controlled HTTP experiment reproduces the Lilly decode variation.
Three identical, explicitly async images receive the same PNG bytes, split
after the first 32 KiB. With no pause, Brave's crop matches Vox. Pausing for
50 or 200 milliseconds before sending the remainder yields 14,993 and 14,995
different crop pixels respectively. Each capture waits for complete loading
and the same two-second settle interval. This is one diagnostic run, not a
stability cohort or acceptance result.

An independent fresh windowed page with auto, sync and async decoding hints
likewise matches the existing reduced upload only for async: the other two
crops each differ by 14,994 pixels. Forcing a full upload solely in a private
Lilly-sized probe makes Y 8800 exact against the fixed full-resolution page
reference. That dimension-specific probe remains under `Build/` and is not
part of the implementation.

Chromium's [checker-image tracker](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.48/cc/tiles/checker_image_tracker.cc)
vetoes async checkering for partially loaded images. Its
[GPU decode cache](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.48/cc/tiles/gpu_image_decode_cache.cc)
also disables reduced uploads for cropped source requests unless clipped-image
scaling is explicitly enabled. These paths offer a concrete explanation for
the observed variant change, but the experiment does not prove which internal
cache request won. Vox's current browser image loader publishes complete
responses, so it cannot yet reproduce that partial-load decision sequence.
Forcing an upload solely from the HTML decoding hint would be insufficient.

`lilly-decode-modes-before/`, `lilly-progressive-response/` and
`lilly-full-probe-page/` preserve captures, audits, identities, commands and
guards. The partial-response directory also records the PNG hash, exact split,
delays and per-crop counts. Plane upload, CPU versus GPU plane mip generation,
source endpoint rounding and Metal-versus-Dawn probes leave the 97 book pixels
unchanged. Full live-page and scale-two conformance remain open.

## Cropped image decoding hints

`81e6b5f8` applies the synchronous cropped-source decode rule before choosing an
upload. The browser collects live HTML image hints across the paint list first,
so a synchronous use also governs an earlier async use of the same resource.
`ab12479b` excludes empty image rectangles and requests with no decoded frame.
Those inactive uses cannot contribute a decode task merely because the shell
has cached pixels from another image at the same URL.

The implementation follows Chromium's
[cropped-upload rule](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.48/cc/tiles/gpu_image_decode_cache.cc)
and [checker-image decisions](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.48/cc/tiles/checker_image_tracker.cc).
Unspecified/sync hints, animated images and small async source regions select
the full source for a cropped draw. Large, completed async images retain their
scaled complete-source request. Source bounds round outward before testing
the desktop 1 MiB threshold; Blink only lowers that threshold on
[non-desktop Android configurations](https://chromium.googlesource.com/chromium/src/+/refs/tags/156.0.8078.48/third_party/blink/renderer/platform/widget/compositing/layer_tree_settings.cc).
This does not implement partial PNG publication or the complete task scheduler.

Two 800×600 scale-one fixtures have byte-identical fresh Brave references
before and after their respective changes:

| Fixture | Before | After |
| --- | ---: | ---: |
| `cropped-image-decoding-modes` | 182,349 | 0 |
| `cropped-image-inactive-decode-hints` | 45,528 | 0 |

The first includes auto/sync/async crops, a shared resource whose async use
occurs first, a small async crop and an uncropped control. The second adds
hidden and distant deferred images at a visible async image's URL. The first
implementation regresses the Gitly viewport from four to 9,314 differences;
the inactive-use correction restores four. Both failing captures and their
unchanged references remain retained.

Focused checks pass 134 ASan/UBSan cache assertions, including nineteen new
mode/crop checks, thirty public image-bridge scenes at both display scales,
and four V tests in each of no-GC and Boehm modes. Disabling hint collection in
the GPU test produces 459,355 differing pixels. The V mini suite links the
canonical helper and test files, avoiding unrelated browser UI compilation.
Earlier failed attempts remain preserved without pass credit. Run the cache
checks with `python3 tools/test_chromium_image_decode_cache.py`; the GPU program
is included in `tools/test_skia_gradient_backdrop.py`.

The broad native run passes eleven of twelve programs across its original and
continuation runs. Its shared-layer gradient case fails with 5,343 differing
channels both with and without this feature. The separate browser validation
passes startup, fourteen screenshot smoke checks, all sixty strict fixtures,
eight exact image/gradient/table golds and live scripted loading. Live loading
reports five complete visible images, loaded fonts and zero native errors;
it supplies no whole-live-page pixel comparison credit.

The sixteen-position fixed-reference sweep retains the preceding residuals
except Y 9600, which has 2,982 differences rather than the historical 308.
Disabling this feature in the same earlier production executable also produces
2,982 there, isolating that additional text difference from image hints. Lilly
still differs by 14,681 pixels and the footer book by 97. All sixteen document
identity, viewport, readiness and font/error audits pass. Full page parity
remains open.

An HTTP fixture diagnostic initially captures a blank Brave uncropped control,
producing 63,348 differences. Its metadata does not establish image readiness,
so the cause remains unproven. A later diagnostic with image and network audits
is exact with all seven images complete and no network failures. The inactive
fixture's HTTP comparison is also exact. These separate diagnostics retain the
failed capture and do not establish a stable HTTP cohort.

Evidence under `Build/vlang-cropped-decode-20261101/` includes
`fixture-comparison.json`, `cache-focused/`, `native-policy-{positive,negative}-*`,
`policy-final-v3-*`, the failed `native-regressions/` and successful
`native-regressions-remaining/`, `shared-layer-before-policy-v2-*`,
`validation-status.json`, `final-page-audit.json` and the individual capture
directories. The controlled HTTP runs are `cropped-image-*-http/` and
`cropped-image-decoding-modes-http-audit/`.

The final executable is
`53f2472079173736dcca4b68415ee5ac798df4ae18b2fc7c814d266db48f4552`,
preserved in `Vox-cropped-decode-v2-installed.app`; its native text library is
`ea57efeed85f7fd70a42fdf5cbe3200c074405ac127edef143c35a092b0ec9aa`.
All six feature inputs remain unchanged through the 366.13-second production
build, whose sampled peak RSS is 8.12 GiB under the 12 GiB guard. Other shared
inputs change, so the complete checkout is not frozen. The initial shared
build's source hashes and compiled-C feature witness are also retained.

## Promoted text after vector culling

`f0895d33` preserves the transparent raster of a promoted text layer after its
last vector leaves the viewport. The existing complete-picture eligibility
check already validated every remaining command, effect boundary and child
gap, but its final vector-only condition discarded that layer when culling
removed the vector. Text then painted over the parent pixels directly, changing
the intermediate premultiplied rounding. A validated text-containing layer now
retains its surface. Unsupported effects, clipping and gaps keep their existing
rejection checks; a layer without text or vectors does not gain this path.

The fixed-reference News viewport at Y 9600 improves from **2,982 to 137
differing pixels**. A same-build negative control replaces only the final
`has_svg || has_text` machine instruction with the preceding `has_svg` result.
It restores 2,982 differences with byte-identical native libraries. The change
removes 2,845 errors, introduces none and worsens none. This exceeds restoration
of the historical 308-pixel result, but the remaining 137 still prevent exact
conformance.

Every decoded native PNG at the other fifteen sampled positions is byte-identical
to the preceding cropped-decode production bundle. The remaining counts are
4/1,463/452 at Y 0/800/1600, zero at each 800-pixel sample from 2400 through
7200, 4 at 8000, 14,681 at 8800, 160 at 10400, and 97 at 10664 and 10701.
All sixteen document identity, 1280×800 viewport, readiness, font/error and
visible-image completion audits pass. These remain scale-one archived-page
comparisons against unchanged earlier Brave references.

Five focused culling tests pass in both Boehm and no-GC builds. Ten SVG layer
tests pass in no-GC mode. Their former vector-only expectations are updated to
check the new supported text capability while retaining rejection cases for
unsupported effects and resources. The initial run against those old
expectations remains preserved as a failure.

The production validation passes startup, fourteen screenshot smoke cases under
their existing bounds, and eight exact image/gradient/table golds. Its strict
browser suite passes **61 of 63** fixtures and exits one. The Guardian carousel
fade has 3,208 differing pixels; the JPEG XL image-path fixture has 22,715.
Both failures produce byte-identical native RGBA with the same-build feature
veto, so neither is attributed to this text change. They remain failures, with
no reference or tolerance adjustment. Separate live scripted vlang.io loading
has loaded fonts, five completed visible images and zero native errors. It
supplies loading evidence, not a live-page pixel comparison.

`9ae9bfbb` adds a diagnostic for the first vector feature selecting a
complete compositor picture. Additional native probes confirm identical glyph
IDs, positions, colors and font settings across the culling control; its layer
recording state differs. The first injected probe breaks the separate adblock
worker handshake and captures a navigation-error page, so it receives no
document or rendering credit. Corrected probes exclude injection from the
separate worker and successfully load the audited document. A proposed bounded-SVG culling change and an integer-color
GPU glyph experiment leave the page unchanged and are not shipped. Two small
experimental text fixtures likewise do not exercise this promoted path; their
unchanged 2,432-pixel failures remain under `Build/` and are not added as golds.

Evidence under `Build/vlang-text-phase-20261101/` includes:

- [Matched negative control](../Build/vlang-text-phase-20261101/promoted-text-negative-control.json),
  `promoted-text-{target,negative-target}/`, and
  [pixel movement](../Build/vlang-text-phase-20261101/news-pixel-movement.json).
- [Full-page audit](../Build/vlang-text-phase-20261101/page-regression-audit.json),
  `promoted-text-full-page/`, `promoted-focus-{none,boehm}-*` and
  `promoted-svg-{none,final}-*` retain successful and failed checks.
- [Validation exits](../Build/vlang-text-phase-20261101/validation-status.json),
  [unchanged browser failures](../Build/vlang-text-phase-20261101/unchanged-browser-failures.json),
  and the individual smoke, strict, gradient and live logs preserve the aggregate
  failed browser verdict.
- [Source witness](../Build/vlang-text-phase-20261101/production-source-witness.json),
  `compiled-promoted-text-function.c` and `production-generated.c.gz` retain the
  compiled eligibility expression. Both implementation inputs remain stable
  through the 268.16-second production build, whose sampled peak RSS is
  8.10 GiB under the 12 GiB guard. Other shared inputs change, so the complete
  checkout is not frozen.

The validated executable is
`774a3b6a18b0b87c1fd416128bb0bc3697431f2278ddb89ba4f5709135e77518`,
preserved in `Vox-promoted-text-installed.app`. Its native text library is
`a18b3fda25126c2dd392b73df017f1280c4ddb84a52c380e3b5a6546efef85f0`.
The initial shared production attempt fails after compilation because its build
script changes during execution; that private candidate supplies diagnostic
evidence only. The final promoted-text build supplies the checks above.
Full live-page and scale-two parity remain open.
