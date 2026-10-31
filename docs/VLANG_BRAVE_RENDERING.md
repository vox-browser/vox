# vlang.io rendering against Brave

Pixel-perfect parity remains open. The current settled, archived comparison at
1280 × 800 CSS pixels and scale 1 has **9 differing pixels at the top** and
**242 at scroll Y 6400** after the image and underline paint-order fixes. These
numbers describe those viewports, not the complete live page. Earlier build
comparisons and validation limits are recorded below.

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
