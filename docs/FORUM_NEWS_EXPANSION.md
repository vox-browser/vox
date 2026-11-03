# Five additional news-site comparisons

The [forum/news catalog](../Tests/Browser/Brave/forum-news.json) now contains
15 sites. TechCrunch, Engadget, The Register, Slate and WIRED have sealed guest
DOM archives, original response bodies, full-uBlock Origin reports and source
PNGs. They are registered as strict conformance tests; **none of the five has
passed the complete pixel gate yet**.

The original ten are also incomplete: six accessible archives pass both source
fidelity and native equality; CNN matches frozen Brave but retains its separate
source-fidelity failure. Reddit is blocked, and Stack Overflow/Pikabu remain
deferred. See [the original checkpoints](ADBLOCK_POPULAR_SITES.md).

## Initial production baseline, November 2, 2026

All comparisons use a fresh private profile, an empty response cache, 1024×768
document viewport and scale 1. Brave Shields is disabled and full MV2 uBlock
Origin uses the repository's pinned lists. Vox uses the same filtering policy,
including disabling its additional cookie-banner blocker. Slate's initial
consent banner remains part of this guest viewport.

The production executable SHA-256 is
`0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`.
Each attempt retains before/after executable, native-library, runtime-asset and
Brave-framework identities. Comparisons replay original URLs through a sealed
private TLS proxy; missing resources never fetch from the network.

| Site | Saved source → frozen Brave pixels | Vox → frozen Brave pixels | Result |
| --- | ---: | ---: | --- |
| TechCrunch | 0 | 42,597 | Native rendering gap |
| Engadget | 90,850 | 1,717 | Source fidelity and native rendering gaps |
| The Register | 110,180 | 6,786 | Source fidelity and native rendering gaps |
| Slate | 19,064 | 221,448 | Source fidelity and native rendering gaps |
| WIRED | Unqualified | Unmeasured | Frozen reference changed between consecutive frames |
| Hacker News control | 0 | 0 | Strict pass |

The six-case command exited 1. All attempts, guards, exact commands, PNGs,
request/header checks, CSS comparisons and readiness audits are retained in
[the baseline](../Build/forum-news-expansion-20261102/registered-baseline/summary.json).
The shared bundle remained unchanged throughout each comparison. Small errors
still count: Engadget/Register source gaps are predominantly low-channel-error
image differences, not accepted equality.

An independent [TechCrunch diagnostic](../Build/forum-news-expansion-20261102/techcrunch-audit/summary.json)
again gives source equality but 41,841 native differing pixels, with no hovered
or focused element. The first capture's additional link underline was transient.
Remaining differences include image sampling and its SVG menu mask. No source
reference or tolerance was changed.

## Acquisition and oracle policy

Ars Technica returned HTTP 405 human verification, AP News returned HTTP 403
Cloudflare verification, and NPR navigation timed out. They were not substituted
with access pages. Direct captures also failed on several eventual additions;
Engadget, The Register and WIRED were acquired through the configured explicit
HTTP proxy. That proxy is used only for acquisition; comparisons remain sealed.
[Initial attempts](../Build/forum-news-expansion-20261102/acquisition-summary.json),
[replacement attempts](../Build/forum-news-expansion-20261102/replacement-acquisition-summary.json)
and [proxy attempts](../Build/forum-news-expansion-20261102/proxy-acquisition-summary.json)
retain failures as well as successes. ESPN's unsuccessful candidates remain
diagnostic evidence outside the selected five.

WIRED exposed an oracle bug: the pinned list contains `@@||wired.com^$ghide`.
Vox correctly suppressed generic cosmetics, but the old comparison queried
uBO's cosmetic engine without its tab policy. The oracle now obtains both
generic/specific switches from the matching full-uBO top-level PageStore,
passes them to the specific engine, and omits generic retrieval when disabled.
It rejects absent, disabled and unrelated tabs. The source capture
passes all filtering checks with `generic_enabled:false`; it has 20 cosmetic
rules, instead of the old query's invented 1,203.
[The corrected acquisition](../Build/forum-news-expansion-20261102/wired-policy-fixed/capture.json)
and [23 passing Node checks](../Build/forum-news-expansion-20261102/oracle-policy-tests.guard.json)
validate the change. Hacker News remains an independent normal-policy control.
This is a harness correction, not an engine rendering improvement.

Restored profiles exposed another oracle ambiguity: multiple PageStores can
have the same URL. The oracle now creates its own uniquely marked Chrome tab,
binds that tab ID to the corresponding CDP target, and closes other tabs in
the disposable profile. Cosmetic policy queries require that explicit tab ID.
[Seventeen focused Node checks](../Build/forum-news-expansion-20261102/oracle-target-tests.guard.json)
pass. An [Engadget complete-cache diagnostic](../Build/forum-news-expansion-20261102/engadget-complete-target/summary.json)
finishes the entire capture/filtering workflow with matching tab identities;
its source gap is 221 pixels and native gap remains 1,717. That alternate
diagnostic archive does not replace the registered cold archive.

## Focused mask regression

`techcrunch-mask-sizing` retains the publisher's original 12×10 vector menu
shape. Ten cases cover contain sizing in integer/fractional/wide/tall boxes,
natural and explicit dimensions, cover sizing, percentage positioning and an
existing square-mask control; a zero-sized image must retain a transparent
mask group. Two independent full-uBO Brave captures agree exactly; the
production baseline differs at 1,286 pixels.
[Reference receipts](../Build/forum-news-expansion-20261102/mask-reference-complete/references.json)
and [the failing native check](../Build/forum-news-expansion-20261102/mask-expanded-before.guard.json)
are retained. Commit `7f31cf052` resolves concrete non-repeating SVG mask tiles
before collecting paths. Six focused V tests execute successfully with both
[default GC](../Build/forum-news-expansion-20261102/mask-final2-default-run.guard.json)
and [GC disabled](../Build/forum-news-expansion-20261102/mask-final2-none-run.guard.json).
Existing SVG-image, mask-origin, document-cache and gradient-mask controls also
pass in [the focused checks](../Build/forum-news-expansion-20261102/focused-masks/).
Production pixel validation is pending a bundle containing that change; the
old executable cannot validate it.

Commit `e2ccd4b63` also snaps generated linear/radial mask image origins in the
Chromium profile while preserving fractional layout and image dimensions.
The new eight-column `techcrunch-gradient-solid` regression removes image
decoding from the comparison: its two integer-origin columns already match,
while fractional columns account for all 50,400 differing pixels in the old
bundle. Two full-uBO Brave references agree exactly in
[the reference receipts](../Build/forum-news-expansion-20261102/solid-mask-reference2/references.json).
The layout test checks 32 policy/origin/gradient combinations and passes with
both [default GC](../Build/forum-news-expansion-20261102/gradient-origin-default-run.guard.json)
and [GC disabled](../Build/forum-news-expansion-20261102/gradient-origin-none-run.guard.json).
The browser regression remains pending a production bundle containing the fix.
The four pre-existing generated-mask tests also execute successfully in
[the current focused control](../Build/forum-news-expansion-20261102/gradient-existing-run.guard.json).

At the November 3, 00:20 Moscow checkpoint, the latest completed production
bundle is still `0bb14e2f…`. The shared build
[`20261103-001433-54a1d4f1`](../Build/production-build/receipts/20261103-001433-54a1d4f1/result.json)
exited 2 with `unexpected EOF while looking for matching '"'` while the build
script was being edited by another session. The current canonical script passes
`sh -n`. Its worker has already started `20261103-001955-0fffe2c3`; no duplicate
build was requested. Neither an older bundle nor the earlier superseded stage
validates the two new mask fixes. The five additions remain strict failures.

## Photo-mask isolation

A synthetic [original-origin HTTP diagnostic](../Build/forum-news-expansion-20261102/http-image-probe/summary.json)
uses TechCrunch's unchanged encoded WebP response, object-fit geometry,
fractional placement, green backdrop, gradient mask and dark overlay. Both
browsers load the same sealed response bytes with full uBO. Source and frozen
Brave agree exactly; Vox differs at 7,634 pixels, with maximum channel error 2.
The four separate controls have 24 plain-photo differences, 6,149 mask-only
differences, 4 overlay-only differences and 1,457 combined differences.

The corresponding local-file capture is a separate decoder diagnostic: local
WebP files currently enter AppKit's loader, while HTTP response bytes use the
resource decoder. Its larger error cannot establish HTTP mask behavior.
Constant-alpha composition is independently exact in 144 image/mask GPU
comparisons, alongside 56 existing scope/pixel cases and 24 opacity comparisons,
under both optimized and AddressSanitizer/UndefinedBehaviorSanitizer builds.
[The final native controls](../Build/forum-news-expansion-20261102/mask-composite-controls-final/result.json)
pin their canonical source and native-library inputs. Earlier `before2` and
`after` attempts used an incorrectly constructed empty mask and are invalid
for diagnosing composition; no renderer change was retained from them.

The durable [HTTP image-effects command](../tools/forum_news_image_effects.py)
now reconstructs that sealed diagnostic, checks a fresh full-uBO source against
the committed PNG, then applies the normal source/frozen/native conformance
workflow. It pins tools, canonical inputs and both browsers and rejects input
changes. [Its initial complete run](../Build/forum-news-expansion-20261102/http-image-command/summary.json)
reproduces the same 7,634 native differences with source equality;
[23 catalog/archive unit tests](../Build/forum-news-expansion-20261102/image-effects-final-unit.guard.json)
pass. The plain local-file fixture is intentionally absent from the inline
suite because that route exercises a different decoder.

## November 3 continuation: rectangular image crops

Commit `7aee89d53` transfers a contained integer overflow crop into the image's
GPU operation. Previously that crop remained on Quartz's destination while the
GPU drew the larger image content rectangle. Those two operation sequences can
choose different bilinear samples. The existing rounded-clip priority remains;
fractional, empty, containing, disjoint and unsupported clips retain their
preceding path. SVG images and rectangular video clips are unchanged.

The original encoded WebP and committed full-uBO Brave reference supply the
native regression. The unchanged adapter configuration reproduces the browser's
24-pixel plain-photo residual with the toolbar offset and root tile grid. The
new crop arguments give **zero differing pixels in all four tested viewport/grid
configurations**, in both optimized and ASan/UBSan executables. The
[final native receipt](../Build/forum-news-resume-20261103/rect-clip-native-final/summary.json)
pins the browser libraries, external Skia, decoder, fixture, reference and test
inputs. The focused V clip-selection suite executes successfully with
[default GC](../Build/forum-news-resume-20261103/rect-clip-default2-run.guard.json)
and [GC disabled](../Build/forum-news-resume-20261103/rect-clip-none-run.guard.json).
A [live display-list diagnostic](../Build/forum-news-resume-20261103/live-clip-dump3-run.guard.json)
confirms that the fractional card layout publishes the integer `(4,229,242,242)`
overflow clip consumed by this policy.

This is a native adapter/clip-policy result, **not a new production homepage
pass**. The installed bundle still has SHA-256 `0bb14e2f…` at the 01:00 Moscow
checkpoint. All earlier failed diagnostics remain under
[`Build/forum-news-resume-20261103`](../Build/forum-news-resume-20261103/):
the first native regression lacked its standalone GPU-helper load and entered
the adapter's fallback; the initial raw adapter probe indexed bitmap rows in
reverse. The original interpose attempt could not resolve the locally loaded
symbol; the next captured draw arguments but recursed through the interposed
lookup and was terminated. Neither supplies a qualified browser PNG or engine
regression claim. The final independent native regression explicitly loads the
pinned GPU helper and records the four unchanged controls too.

Two shared production builds failed with a shell EOF/quoting error
while the entry script was being edited. Commit `1fb32b06e` makes future build
launchers read the canonical entry script once and deliver it through memory,
preserving `$0` and source-change rejection without copying repository tools.
[Eleven launcher tests](../Build/forum-news-resume-20261103/build-launch-final-tests.guard.json)
pass, including a concurrent script edit and real memory-guard stdin delivery.
The already-running worker retains its loaded launcher code; subsequent builds
have also been superseded by checkout changes, so no new bundle has qualified.

A single [pending validation job](../Build/forum-news-resume-20261103/after-build/state.json)
waits up to 20 minutes for a verified shared production receipt containing
`7aee89d53`. It then runs the two mask browser regressions, the HTTP photo
comparison, and strict TechCrunch/Hacker News comparisons sequentially through
their memory guards. It records every result and rejects a bundle change across
the batch. It does not request a production build. A waiting or timed-out state
is not a pixel pass, and the five added sites remain incomplete.

## November 3 production validation

The shared build
[`20261103-011139-5e6ed988`](../Build/production-build/receipts/20261103-011139-5e6ed988/result.json)
passed its startup check and published executable SHA-256
`1bcbbb5cca048906caf2151070018fb7ec0618b5af140b465700ba31a9cd1d75`.
It contains the three committed TechCrunch mask/crop fixes above. The pending
validation job completed on this unchanged bundle; it no longer awaits a build.

Both `techcrunch-mask-sizing` and `techcrunch-gradient-solid` now match their
unchanged Brave references exactly. The complete rendering suite also passes:
**99 tests / 105 captures**, with unchanged browser, runtime assets, test inputs
and references throughout the batch. Its [summary](../Build/forum-news-production-resume-20261103/summary.json),
[guard/log](../Build/forum-news-production-resume-20261103/inline.log) and
[capture inventory](../Build/forum-news-production-resume-20261103/captures.json)
retain the results. These browser checks validate the previously pending fixes;
they do not establish full-site equality.

| Workload | Saved source → frozen Brave pixels | Vox → frozen Brave pixels | Result |
| --- | ---: | ---: | --- |
| HTTP photo/mask regression | 0 | 4 | Reduced from 7,634; still fails |
| TechCrunch homepage | 0 | 34,710 | Still fails |
| Hacker News control | 0 | 0 | Strict pass |

The [completed pending job](../Build/forum-news-resume-20261103/after-build/state.json)
retains every command, guard, browser identity and result. Its overall result is
a failure because the photo and homepage comparisons still differ. A second
[TechCrunch comparison](../Build/forum-news-techcrunch-geometry-20261103/comparison/summary.json)
independently reproduces all 34,710 differing pixels. Native DOM audits confirm
that the three visible cards and their overlay bounds match Brave exactly.
34,709 differing pixels have maximum channel error one; the remaining pixel is
on the large SVG logo. No tolerance or reference was changed.

The four photo errors reproduce in both the native probe and production PNG,
at `(455,255)`, `(455,275)`, `(455,278)` and `(455,293)`. These rows lie inside
the mask's fully opaque region, and the output equals the corresponding plain
photo pixels. This narrows that residual to image sampling rather than mask
alpha composition. An independent
[full-height HTTP diagnostic](../Build/forum-news-full-photo-20261103/summary.json)
also preserves source equality and has 45 native differences, confined to its
masked columns. It is an authored diagnostic, not another homepage pass.
The five additions remain incomplete.

### Additional isolation and preservation coverage

Commit `fa8782d01` adds `hidden-scroll-metadata` to the browser suite and three
focused V tests. They cover a closed zero-opacity scroll menu, inherited zero
opacity, an opaque scroll control and metadata restoration after live opacity
changes. Two independent full-uBO acquisitions agree exactly, and each sealed
source/frozen/native comparison has zero differing pixels:
[first acquisition](../Build/forum-news-hidden-scroll-reference-20261103/summary.json),
[second acquisition](../Build/forum-news-hidden-scroll-reference2-20261103/summary.json).
The committed PNG has SHA-256
`60791309e28da71e0d6868c57ac54eb007767dcc985851ba73420faeafee2911`.
The [native browser test](../Build/forum-news-hidden-scroll-20261103/browser.log)
and all three V cases pass with both default GC and GC disabled in
[the focused receipt](../Build/forum-news-hidden-scroll-20261103/summary.json).
The suite now registers 100 tests; the earlier complete 99-test batch remains
separate from this later focused check.

This is preservation coverage, **not a rendering fix**. The reduced hidden-menu
case already passed in the existing browser and V planner. It therefore does
not establish that invisible scroll metadata causes the full-page difference.
The original unit attempt incorrectly required fractional-opacity groups to
take the metadata path instead of their existing atomic fallback; its failure
is retained, and the control now checks a fully opaque scroll container.
No planner or renderer implementation change was retained.

The later installed executable, SHA-256
`7f7f497421070c18e8a32615cf206a5d5df242b59f69f0975d06a12424598aaa`,
also gives **34,710 TechCrunch pixels and zero Hacker News pixels**, with source
fidelity passing for both and unchanged bundle identities across the batch.
[The later receipt and results](../Build/forum-news-latest-sites-20261103/summary.json)
pin its complete native-library/runtime identity; this does not rerun or extend
the earlier complete rendering-suite claim to that build.

Further probes remain diagnostic. Replaying the homepage's captured backdrop
and gradient arguments reproduces 19,634 errors in the examined 484×321 photo
region; root-coordinate replay reduces that region to 28 errors. This does not
establish a correct full-page layer assignment. A later interposed experiment
used stale symbol offsets after a shared bundle publication and crashed; it is
[explicitly rejected](../Build/forum-news-gradient-trace-20261103/candidate-rejected.json),
with no qualified candidate PNG. The stronger Brave layer-snapshot diagnostic
also changes its photo output, failing source fidelity at 79,032 pixels in
[the retained attempt](../Build/forum-news-brave-layers3-20261103/summary.json).
Its layer data is not pixel-acceptance evidence. No reference, threshold or
registered site archive was changed to accept either experiment.

## Bookmark catalog and Engadget continuation (2026-11-03)

Commit `74ee15370` adds all 15 comparison sites to the bookmark-bar catalog,
startup migration and restricted-navigation routing. Wikipedia, Old Reddit's
programming page and vlang.io remain available; Hacker News is deduplicated.
The migration was also applied to the existing local profile: 14 missing entries
were added, bringing its total from six to 20. All 15 comparison URLs occur once;
existing entries, their order and bar visibility were preserved. Its saved flag
prevents a later startup from restoring bookmarks the user removes.
[The profile receipt](../Build/forum-news-bookmarks-20261103/profile-update.json)
records counts and hashes without publishing personal bookmark contents.

Seven bookmark/catalog test files pass with GC disabled. Default-GC coverage
combines six passing files from the first run with a successful uncached rebuild
of the remaining catalog test; its original cached-runtime loader failure is
retained. The four native UI2 routing/bar checks also pass.
[Module and UI receipts](../Build/forum-news-bookmarks-20261103/) retain the
checks. Commit `4b623394e` lists all 15 sites, their URLs and their actual parity
status in [OPTIMIZED_SITES.md](../OPTIMIZED_SITES.md); this does not award CPU
optimization acceptance to an incomplete rendering target.

Engadget is the next active site. Its
[fresh cold baseline](../Build/engadget-next-20261103/baseline/summary.json)
has **1,980 native differences and 90,850 saved-source/frozen differences**.
The later [production checkpoint](../Build/engadget-next-20261103/production-site/summary.json)
has **1,594 native differences**, with the same source-fidelity failure. Hacker
News remains strict-zero in both batches. The later batch pins executable
`f8618e0dd1854b53833106b154f9354dab0646d2e30069302a1c83163da33b60`
and its native libraries. These shared builds contain other sessions' changes;
the whole-page delta is not an isolated attribution to this fix.

The reduced category-label fixture covers eight rounded labels: missing left
and right borders, integer and fractional authored positions, 30px and 46px
heights, normalized semicircles and a smaller-radius control. Two independent
full-uBO acquisitions agree exactly with their frozen Brave replays:
[first reference](../Build/engadget-next-20261103/capsule-reference/summary.json),
[second reference](../Build/engadget-next-20261103/capsule-reference2/summary.json).
The old native browser differs at **573 pixels**. Enabling native capsule replay
reduces that to 100. Brave's
[recorded painting commands](../Build/engadget-next-20261103/capsule-layers/layers.json)
then identify the ordered soft missing-edge clips and hard corner miters that a
single union fill loses. That diagnostic retains exact source fidelity.

Commit `6978fea47` preserves this side sequence for three equal opaque
sides around a symmetric rounded end. It also retains normalized complex-border
colors: dividing the original byte channels by 255 resolves two remaining edge
pixels that SkColor's reciprocal multiplication rounds differently. Other border
shapes keep their existing paths, and portable SVG fallbacks remain available.
The optimized and sanitized native replays are **pixel-exact on cold and repeated
draws**, and the existing partial-border native control remains exact:
[optimized](../Build/engadget-next-20261103/native-final-runtime.log),
[sanitized](../Build/engadget-next-20261103/native-sanitized-runtime.log),
[existing control](../Build/engadget-next-20261103/native-controls-runtime.log).
Commit `036a60820` separately corrects that older probe's RTTI compiler flag to
match the shared Skia library; its original linker failure is retained.

All seven selected V cases in three files pass with default GC and GC disabled:
[default](../Build/engadget-next-20261103/layout-final-default2.log),
[GC disabled](../Build/engadget-next-20261103/layout-final-none.log).
The first concurrent compiler batch exceeded the aggregate 12 GiB guard and was
terminated; both sequential reruns completed below 7.1 GB sampled RSS. That
[failed attempt](../Build/engadget-next-20261103/layout-final-default.guard.json)
is retained. The existing partial-border control and fractional-color cases
keep their assertions unchanged.

The browser suite now registers 101 tests. This is not a new whole-suite pass.
The intermediate production browser has the native side-order change but lacks
the V color-retention change: its new fixture still fails at two one-byte pixels,
while the existing partial-border and fractional-background controls pass.
[The retained intermediate browser check](../Build/engadget-next-20261103/browser-focused.log)
keeps that failure.

The next published production executable, SHA-256
`eb372f4d5ddf52e30963791fcccb16b88e15cc069fc6abbefed8946782e5dc6c`,
contains the combined fix. All three focused browser tests/four captures pass at
zero pixels, including the new category-label fixture and the unchanged partial
border/fractional-background controls. Its fresh full-page Engadget comparison
has **1,510 native differences and the same 90,850 source-fidelity differences**;
Hacker News is strict-zero. The complete executable/native/runtime identity
remains unchanged across both the focused checks and site comparisons.
[The production validation receipt](../Build/engadget-next-20261103/published-validation/summary.json)
retains the successful focused exit and failing whole-site exit separately.
This establishes the reduced label fix, not full Engadget parity or a complete
101-test-suite pass. Engadget remains incomplete while its full-page native and
source-fidelity gaps remain nonzero. No site archive, reference tolerance or
acceptance gate changed.

## SVG sizing and fixed-container metadata (2026-11-03)

Commit `f67e708d3` transfers a ratio-only SVG image's quantized used height back
to its automatic width. Engadget's cyclic percentage-height logo now uses
134.921875×27.984375 CSS pixels, matching Brave. Explicit widths, definite
height chains and raster natural dimensions retain their existing behavior.
The nine selected layout cases pass with default GC and GC disabled; two
independent full-uBO references agree. The reduced browser regression improves
from **66 pixels to zero**. On executable
`2f0771f27b0993071f274965a240eded0393e899c482fd89b00cdee84454be2f`,
all five focused browser tests/captures are exact. The whole Engadget viewport
still has 1,509 native differences and 90,850 source-fidelity differences.
[Sizing checks and production receipt](../Build/engadget-parity-20261103/verification.json)
retain both successful focused checks and the failing whole-site result.

That shared build also exposes a BBC preservation regression: 1,301 one-byte
differences in its cookie-banner text, with source fidelity still exact. The
earlier zero-pixel BBC runs remain valid for their pinned builds. A reducer
identifies the trigger: adding an independent scroller enables hit-test
metadata whose fixed-container identity differs from its painted commands.
That splits fixed backgrounds from their descendants into transparent rasters.
The new layout tests fail on the original code, including a background/text
layer split, and pass after commit `d6403778e` preserves the raster owner.
All 15 selected cases in three files pass with default GC and GC disabled;
existing sibling-fixed-container separation remains covered.

Two independent full-uBO acquisitions agree on the new fixed-header/banner
reference, including exact saved-source/frozen replay. Its old browser failure
is **1,722 pixels**. Production executable
`d9ac8f02f93515ca33b5fee082d265e8cb794741c44d1fac6a201e8811bc7481`
passes all eight focused browser tests/captures at zero pixels. BBC is restored
to strict zero, Hacker News remains strict zero, and Engadget improves to
**1,246 native differences**, retaining the 90,850 source-fidelity failure.
The newsletter border and other header icons are exact; 614 logo pixels and
632 photograph pixels remain. These shared-build totals do not isolate every
intervening session's changes. The complete browser identities stay unchanged
through the focused checks and the three-site batch:
[production validation](../Build/engadget-parity-20261103/fixed-published-validation/summary.json),
[layout checks and reference agreement](../Build/engadget-parity-20261103/fixed-verification.json).
The catalog now registers 103 browser tests; this is not a new whole-suite pass.

Acquisition experiments leave the registered Engadget archive unchanged. A
fresh complete-cache capture using a prepared full-uBO profile still differs
from its frozen replay at **221 pixels**. Its native difference is 967 pixels
on a different live feed, so that count cannot be attributed to these renderer
fixes. An earlier attempt fails the full-uBO observed/oracle decision gate, and
adding two animation-frame waits before capture worsens source fidelity to
5,367 pixels. Both failures are retained; no canonical capture protocol or
acceptance threshold was relaxed:
[fresh candidate](../Build/engadget-parity-20261103/fresh-prepared/summary.json),
[failed filtering attempt](../Build/engadget-parity-20261103/fresh-complete.log),
[rejected extra-wait experiment](../Build/engadget-parity-20261103/paint-wait-candidate/summary.json).

The remaining logo is byte-identical to the reduced fixed-header fixture's old
failure. Captured menu masks interrupt the header's recording, and the opaque
continuation check rejects every fixed command. Commit `20b3b9951` permits a
continuation when the parent and complete mask use the same viewport coordinate
space, retaining the existing opaque-coverage, separation and scope checks.
Four focused main-module cases pass with both GC modes; the new case also
rejects a coordinate-space mismatch in painted commands. The first
two candidate compiles fail during concurrent CSS regeneration and are retained;
the successful default-GC and GC-disabled compiles execute their tests separately.
Two qualified full-uBO references agree exactly, and the old browser differs
at **614 logo pixels**. This adds the 104th browser test. Its first production
check still fails at 614 pixels on executable
`a1157f457afdfb4266c3743f9c0fbe6f4f64257fbc93b4ff827dc7318790db9a`;
the other eight focused tests, BBC and Hacker News pass. The actual lowered
closing mask marker carries scope identity without the opening command's fixed
flag. Follow-up `805520666` preserves scope validation while omitting that
non-geometric closing flag. Five main-module cases now pass with both GC modes,
including the real default closing marker and mixed-space rejection.
[The intermediate checks](../Build/engadget-parity-20261103/fixed-mask-verification.json)
retain that failing production result.

Executable `759a9af066d214540c1c06b70796a1658b1ed1a1ea14abf53c67662825085f31`
contains the follow-up. All nine focused tests/captures and 96 installed-native
clipping comparisons pass. The complete browser suite also passes: **104 tests,
110 captures, zero differing pixels**, with unchanged executable/native-library
and fixture/reference identities throughout. The first broad attempt exhausts
disk space and cannot finish its test report; it supplies no acceptance result.
Its failure is retained. Completed test executables were compressed with byte
hash verification, and regenerable component-download caches in four closed
test output profiles were removed. Captures, logs, sealed archives, the prepared
input profile and build receipts remain available. The later run completes
normally under the memory guard:
[follow-up verification](../Build/engadget-parity-20261103/mask-closing-verification.json),
[104-test receipt](../Build/engadget-parity-20261103/final-inline-suite-rerun/summary.json),
[interrupted run](../Build/engadget-parity-20261103/final-inline-suite3.log).

Full Engadget still has **1,246 native / 90,850 source-fidelity pixels** on this
build; BBC and Hacker News remain strict-zero. The reduced 614-pixel regression
is repaired, while the publisher's complete extracted header still reproduces
614 logo pixels with exact source fidelity. That separate header diagnostic
preserves the original DOM, CSS, fonts and SVG response bytes:
[publisher header](../Build/engadget-parity-20261103/full-header2/summary.json).
Suppressing its pseudo-element masks still leaves 614 pixels, while the
authored fixed-header control with cyclic automatic logo sizing is exact:
[mask suppression control](../Build/engadget-parity-20261103/full-header-no-masks/summary.json),
[automatic-size header control](../Build/engadget-parity-20261103/fixed-header-auto/summary.json).
Neither diagnostic changes the registered archive. No whole-site parity is claimed.

A proposed native SVG backdrop shortcut was removed after the unchanged
clipping control failed, despite its new 48-case probe passing. A non-root
raster flag alone does not identify a private compositor destination. One shared
build captured that discarded experiment; its zero-pixel diagnostic is
[rejected](../Build/engadget-parity-20261103/fixed-mask-ref4/qualification.json).
The replacement executable
`ac089f6e9ee05ca73fad9393a5bf7b5cf4f2a5f676cb280da0763b113a7bde59`
passes all 96 installed-native SVG clipping comparisons with unchanged identity:
[restored production control](../Build/engadget-parity-20261103/svg-installed-control2.identity.json).
The restored source's clipping and color controls also pass with sanitizers.
No native shortcut or changed pixel tolerance remains.

The photograph diagnosis remains separate. A qualified draw-argument trace
preserves Engadget's 1,246-pixel result and captures the original ICC-tagged
WebP's decoded RGBA bytes. In the natural-size control's 92,700 interior pixels,
those decoded bytes match Vox exactly but differ from Brave at **467 one-byte
pixels**. That locates a remaining error before image sampling. Reconstructing
the source color space through Skia worsens that comparison to 1,392 pixels;
no converter change is retained. The earlier recursive interposition attempt
crashes and provides no accepted PNG:
[qualified trace](../Build/engadget-parity-20261103/image-trace3/sites/summary.json),
[decoded-pixel comparison](../Build/engadget-parity-20261103/decoded-icc-probe.json),
[rejected conversion probes](../Build/engadget-parity-20261103/icc-probe-comparison.json).

## WebP color and large-layer publication (2026-11-03)

Commits `c889fcc26` and `93da0f339` reduce Engadget from **1,246 to 87 native
pixels** on production executable
`92387cec83e3d3b5cf462f7e65b05f8d4978a5c6a8ec23bb2f0bc678692413db`.
The remaining 87 pixels differ by one channel value around photo corners.
The original archive and its reference remain unchanged; the separate
**90,850-pixel saved-source fidelity failure remains open**.
[Production results](../Build/engadget-continue-20261103-1002/production-checks/sites/summary.json),
[complete input identities](../Build/engadget-continue-20261103-1002/production-checks/identity.json),
[unchanged-input verdict](../Build/engadget-continue-20261103-1002/production-checks/summary.json).

Representable WebP ICC profiles now retain their source pixels and numerical
color space through GPU upload. The previous CPU conversion quantized colors
before that upload. The original-curve fallback remains for unsupported profiles,
and sRGB decoding retains libwebp's truncating alpha multiplication. The new
`engadget-webp-icc` browser regression improves from **1,192 pixels to zero**.
Two fresh full-uBO Brave references agree byte for byte; no existing reference
or tolerance was changed. Focused V tests pass with default GC and GC disabled,
and native profile, fallback, extraction, cache and retagging checks pass.
[Color checks](../Build/engadget-continue-20261103-1002/icc-verification.json),
[production source/replay/native comparison](../Build/engadget-continue-20261103-1002/icc-fixture-production/summary.json).

The header's logical compositor extent is 1,024 by 40,320 pixels. The native
recorder previously rejected it at the texture-size limit, although publication
allocates only its bounded visible intersection. The logical extent now has the
same finite coordinate cap as a root segment; the visible pixel and texture
allocation limits remain enforced. The new `compositor-large-logical-layer`
regression improves from **614 pixels to zero**. Sixteen extent/invalid-input
cases pass optimized and under AddressSanitizer, and 144 existing compositor
cases pass. Only the focused extent hunk was committed from the shared native
header; other sessions' pending renderer edits were preserved.
[Extent checks](../Build/engadget-continue-20261103-1002/large-layer-verification.json).

On this pinned production build, **8 focused tests / 13 captures pass**, including
both new regressions, existing WebP/YUV/alpha paths, rounded ICC images, masks,
fixed metadata and SVG controls. BBC and Hacker News also pass the strict
source/replay/native zero-pixel gates. This is a focused checkpoint; the earlier
104-test broad result remains tied to its earlier build.
[Focused captures](../Build/engadget-continue-20261103-1002/production-checks/focused-summary.json).

The first extent interposer used an incorrect float signature and supplied no
valid extent intervention. The corrected, exact-ABI diagnostic produced 87
pixels; the production result above independently confirms that result without
injection. Simple photo/background controls, including a root SVG trigger, are
exact; the remaining publisher corner differences still need isolation.
[Corrected diagnostic](../Build/engadget-continue-20261103-1002/layer-extent-probe3/sites/summary.json).

Completed output profiles were losslessly archived and every regular file hash
verified to relieve shared disk pressure. The prepared acquisition input profile,
sealed responses, captures, logs and receipts remain available.
[Archive receipt](../Build/engadget-continue-20261103-1002/closed-profile-compression.json).

## Rounded photo backgrounds and capture limits (2026-11-03)

Commit `9cf299518` composites a validated opaque rounded background with its
replaced image in one GPU pass. The first photograph's native regression
compares 240 frozen Brave corner pixels: the separate-pass control differs at
14 pixels and the paired draw is exact. The sample rectangles exclude the
category badge overlay; the original WebP response bytes are unchanged. Three
selection tests, including actual layout/raster ownership, pass with default GC
and GC disabled. Colors requiring more than byte precision, unmatched clips, effects, transforms
and other raster owners retain their ordinary path.
[Durable receipts and identities](evidence/engadget-parity-20261103.json),
[native regression](../tools/test_native_rounded_image_pair.py).

On executable
`406aaa0e2a9130580d16bfcadc8ee08c8b0fa05f59cd9f0ec2ee18383b342808`,
the registered frozen Engadget page improves from 87 native pixels to **zero**.
A fresh, complete-cache acquisition through the explicit SOCKS proxy also has
**zero native pixels**, but still fails source fidelity at **221 pixels**
(maximum channel error 3). Its candidate archive is kept separately and does
not replace the registered archive, whose original source-fidelity failure is
90,850 pixels. These results do not establish a strict site pass.
[Registered capture](../Build/engadget-continue-20261103-1002/rounded-pair-site/summary.json),
[fresh complete-cache candidate](../Build/engadget-continue-20261103-1002/fresh-complete-site/summary.json).

Cold replay is not deterministic. A later cold attempt on the same executable
has 39,914 native/reference differences because **Brave's image changes** by
that amount; Vox's decoded RGBA is byte-identical to its earlier zero-diff
capture. That failing attempt is retained, not retried away. The source-fidelity
metric in that attempt is 76,080. Exactness is qualified by the pinned capture
and cache conditions rather than claimed for every cold launch. Complete cache
preparation is also insufficient to guarantee one Brave output: the latest
registered-archive repeat on executable
`6f46b72a7ca84ae4852e3e8cfc0b092f85d3c1518ea0148b90939a0d7e3bcdd7`
has **23,596 native/reference differences**, while Vox's RGBA remains identical
to the earlier exact capture. Only Brave changes; that failure is retained too.
[Latest complete-cache attempt](../Build/engadget-continue-20261103-1002/registered-complete2/summary.json),
[RGBA comparison](../Build/engadget-continue-20261103-1002/latest-complete-variation.json).
[Cold variation](../Build/engadget-continue-20261103-1002/cold-replay-variation.json),
[retained attempt and controls](../Build/engadget-continue-20261103-1002/pair-production-checks/sites/summary.json).

All **8 focused tests / 13 captures** pass on the pinned build. BBC and Hacker
News still pass their strict source/replay/native zero-pixel checks. The latest
installed native backend also passes the 240-pixel regression. Shared CSS work
briefly blocked final V compilation; after its narrowing fix, all three selection
tests execute successfully in both GC modes. An initial complete-cache repeat
is invalid because the production bundle changed during it, and is retained
without acceptance credit.
[Focused verification](../Build/engadget-continue-20261103-1002/rounded-pair-verification.json),
[latest native backend](../Build/engadget-continue-20261103-1002/native-pair-latest/summary.json),
[invalid bundle-change attempt](../Build/engadget-continue-20261103-1002/registered-complete/summary.json).

Shared cleanup removed older test dependencies and historical Build artifacts.
The full 1.75.0 uBO extension was restored from the upstream release with its
published SHA-256 checked, and the checker/diff binaries were rebuilt from
canonical sources. The durable JSON receipt above preserves the current exact
counts, image hashes, engine identities and failures independently of Build
cleanup. Authored WebP/texture reducers with decoding or sampling differences
are diagnostic only; none replaced an existing reference or lowered a gate.

## Run

```sh
python3 tools/forum_news_pixels.py \
  --sites techcrunch,engadget,theregister,slate,wired \
  --extension Build/forum-news-parity-20261030/extension/uBlock0.chromium \
  --checker Build/slashdot-packaged-validation-20261102/adblock-check \
  --diff-tool Build/forum-news-parity-20261030/hn-baseline/pixel_diff \
  --output Build/forum-news-five-UNIQUE

python3 tools/forum_news_image_effects.py \
  --extension Build/forum-news-parity-20261030/extension/uBlock0.chromium \
  --checker Build/slashdot-packaged-validation-20261102/adblock-check \
  --diff-tool Build/forum-news-parity-20261030/hn-baseline/pixel_diff \
  --output Build/forum-news-image-effects-UNIQUE
```

Run expensive checks through the repository's memory guard. The driver also
guards every browser invocation at 3 GiB. Both native and source/frozen RGBA
comparisons must be exact. Frozen, script-free viewports do not establish live
scripting, scrolling, media or whole-site parity.
