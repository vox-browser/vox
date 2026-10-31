# vlang.io rendering against Brave

Pixel-perfect parity remains open. The current settled, archived comparison at
1280 × 800 CSS pixels and scale 1 has **9 differing pixels at the top** and
**147,641 at scroll Y 6400**. Two fresh warm-cache captures at 6400 produce the
same result. These numbers describe those viewports, not the complete live page.

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

The experimental paint-chunk metadata planner also remains outside production.
Further work needs correct chunk boundaries, scrolling overlap barriers, layer
origins, and mixed-content replay. Keep the top reference and settled geometry
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

The broader viewport metadata and complete CSS picture work is still being
validated. Its empty-scroller overlap fixture reaches exact equality, but its
full-page candidate loses code text at scroll Y 6400, and a separate scrolling
gradient fixture exposes a missing scrolling-background paint. These candidates
do not establish a vlang rendering improvement or full Brave parity. The four
existing gradient screenshot regressions remain exact in
`viewport-layer-gradient-regressions/status.json`.
