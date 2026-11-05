# Forum/news rendering comparisons

The [forum/news catalog](../Tests/Browser/Brave/forum-news.json) contains
16 sites, including Discord. TechCrunch, Engadget, The Register, Slate and
WIRED have sealed guest DOM archives, original response bodies, full-uBlock
Origin reports and source PNGs. **The Register passes every strict pixel gate
with cold and complete caches. WIRED passes with its explicit first-frame
image policy.** The other additions retain the open gaps documented below.

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

## Engadget source stability and decode-path diagnosis (2026-11-03)

Commit `cf5684597` applies the frozen reference's readiness and consecutive-frame
checks to live acquisition too. Missing visible images, active stylesheets,
pending fonts or changing screenshots now prevent sealing an archive. Failed
frames and readiness sidecars remain available. No reference or tolerance changed.
All **16 focused Node checks and 21 Python conformance checks pass**; the live
CSSOM/quirks-mode source and frozen replay also remain exact.

The fresh complete-cache acquisition passes the stronger checks. On executable
`3fafbc6189d483cfcd826f5d6b7880e1c705dce36604856b79f005759ad60f48`, its
native/frozen gap is **2,294 pixels**, confined to a newly published photo at the
bottom of the viewport. Source/frozen fidelity fails at **2,485 pixels**. Full
uBO audits pass and browser identities remain unchanged. This is an additional
retained failure; the earlier pinned exact captures still stand.

Three fresh Brave replays copy the **same closed encoded-cache profile** and
load the **same sealed archive**. Each passes its consecutive-frame and filtering
checks, yet their differences from the retained native PNG are **0, 15,642, 0**.
Brave and archive identities remain unchanged throughout. Every attempt is
retained, including the differing middle result; no repeat earns unconditional
site acceptance.

Two diagnostic controls narrow the reference variation:

- Enabling Chromium's paint-record inspection after four identical screenshots
  causes precisely the **221 corner pixels** to change, with maximum channel
  error 3. That instrumented replay fails the normal stability gate and is not
  an acceptance run. Post-repaint records omit backgrounds behind opaque photos;
  attributing the prior cached pixels to background culling remains an inference.
  Waiting for visible images' `decode()` promises does not resolve the mismatch.
- Commit `733b88a5d` retains the new publisher WebP and an independent frozen
  Brave interior crop. RGB decoding matches all **2,520 crop pixels**; the YUV
  control differs at **937**. Optimized and sanitized tests both pass. The live
  source is within one channel value of the YUV probe at one pixel, so that
  diagnostic is not called exact. The test validates both existing draw paths;
  it does not select a production path or establish whole-site parity.

Strict Engadget parity remains open. These checks distinguish stable frames
within a process from reproducible images across processes. No renderer change
is justified merely by choosing one of Brave's differing decode results. The
registered archive, bookmarks and fifteen-site test catalog remain unchanged.
[Durable counts, identities, image hashes and retained failures](evidence/engadget-capture-state-20261103.json),
[fresh full comparison](../Build/engadget-observation-20261103-1436/guarded-site/summary.json),
[three Brave replays](../Build/engadget-observation-20261103-1436/repeat-brave/summary.json).

## Fresh-process reference agreement (2026-11-03)

Commit `146fd2d24` makes every new site-test pass require two independently
launched Brave references to agree at zero RGBA pixels. Each reference retains
its own within-process stability and full-uBO checks. Prepared-cache runs copy
the same closed profile into both new processes; cold runs start empty. Both
PNGs, audits and differences are retained. A differing second reference produces
`reference-replay-mismatch`, even if the first matches Vox and the source.
Native/source comparison metrics remain available when references disagree.

All **24 Python conformance checks pass**. An offline control using the actual
previously retained Brave frames detects their **15,642-pixel** disagreement and
returns `reference-replay-mismatch` despite a zero native difference from the
first frame. That control stubs the launcher and earns no new browser acceptance.

The fresh end-to-end checks give:

| Page / replay cache | Vox versus Brave | Brave versus fresh Brave | Saved source versus Brave | Result |
| --- | ---: | ---: | ---: | --- |
| Engadget / complete | 0 | 0 | 221 | Source-fidelity failure |
| Engadget / cold | 0 | 0 | 221 | Source-fidelity failure |
| Hacker News / complete | 0 | 0 | 0 | Strict pass |

The complete Engadget run pins executable `2e53ce13…`; the cold Engadget and
passing Hacker News runs pin `5e3e9612…`. Browser identities are unchanged within
each qualified run. The earlier Hacker News control was invalidated when the
shared executable/helper changed; it remains recorded without acceptance credit.
Both Engadget runs replay the same complete-acquisition candidate, so “cold”
describes the frozen/native replay caches, not a new cold live acquisition.
These matching reference pairs do not supersede the earlier differing replays.

Engadget remains open on the 221 repaint-sensitive source pixels. Its original
registered archive and golden references are unchanged. Current Chromium's
[WebP decoder](https://raw.githubusercontent.com/chromium/chromium/main/third_party/blink/renderer/platform/image-decoders/webp/webp_image_decoder.cc)
enables YUV eligibility after receiving the complete body. This supports further
investigation of load/paint ordering; it does not identify the installed Brave
decoder's path in a particular frame.
[Durable evidence and invalid attempts](evidence/engadget-replay-gate-20261103.json),
[current Hacker News control](../Build/engadget-replay-gate-20261103-1522/hn-current/summary.json).

Older site checkpoints retain their recorded protocols; they do not
retroactively establish agreement between fresh Brave processes.

## Engadget: oracle startup and cleanup blocker (2026-11-05)

The fresh Engadget continuation supplies **no new qualified pixel result**.
Seven normal acquisition/baseline attempts fail browser lifecycle checks.
Several fresh full-uBO profiles stall before page navigation: `readyToFilter` remains
false, selected lists remain empty, and the buffered startup log stops before
administrative settings are ready. The extension files match the pinned
1.75.0 release ZIP exactly. An explicit-proxy HTTP 200 response establishes
reachability only, not browser document coverage.

Clones of a previously verified closed test profile get past initialization.
They load Engadget with matching full-uBO request, cosmetic and list audits,
and produce stable source PNGs with matching before/after DOM snapshots.
Their source capture or cache warmup nevertheless leaves owned Brave processes
alive at shutdown. Those captures are retained as diagnostics and are not sealed
or registered as passing archives. The original registered Engadget manifest
`53ea109a…`, its source PNG and its historical 221-pixel source-fidelity failure
remain unchanged.

Two harness fixes are committed separately. `684f8ed3c` logs and writes the
original comparison exception before cleanup, so a second shutdown exception
cannot erase its cause. `457e899b9` closes page/extension debugger clients before
requesting browser shutdown and releases the browser debugger after that request.
The complete observed process tree must still exit; no process-exit or pixel
gate is relaxed. One warmup exits cleanly with the revised order, but subsequent
source captures still fail cleanup. All **49 focused Node checks and 29 Python
conformance checks pass**.

A separate mock-keychain diagnostic does not fix initialization and is removed.
A 30-second shutdown wait also fails and is restored to the original eight
seconds. Moving temporary profiles under the task's `Build/` directory does not
qualify an acquisition. A browser worker is sampled in `fsync` while uBO awaits
managed storage; this does not establish causation. Foreground fsync probes in
both directories complete in under a millisecond. Host load is high
(177.87 / 157.78 / 129.72), so contention remains a possible contributor rather
than a demonstrated explanation. No renderer change or new parity acceptance is
claimed; the next comparison still requires successful uBO startup and complete
owned-process shutdown.

[Evidence and exact commands](evidence/engadget-oracle-lifecycle-20261105.json),
[raw diagnostics and failed source captures](evidence/engadget-oracle-lifecycle-20261105.zip).

## Engadget: border-box ratio blocks (2026-11-05)

A fresh complete-cache acquisition now completes uBO initialization, capture,
both independent Brave replays and owned-process shutdown. Candidate manifest
`fa56c7ca…` has **295 source/frozen differences**, **zero independent Brave
replay differences**, and **202,684 native differences** on executable
`8a1e86fa…`. Its 70 files are preserved byte for byte in
[`engadget-guest-20261105.zip`](../Tests/Browser/Brave/candidates/engadget-guest-20261105.zip).
It remains separate from the registered archive. The 295 source differences
lie around rounded photo corners and adjacent borders, with maximum channel
error 4; their cause remains open. The historical 221-pixel source gap and
cross-process image variation are retained.

The native page exposes an independent layout error. Brave's hero image is
462×259 inside a 464×261 border box; Vox produces 460×258.75. Secondary images
are 208×117 instead of 210×117.25. Normal-flow blocks with a concrete CSS width
and preferred ratio pass through translated replaced-element sizing, deducting
inline borders twice. A later automatic-height resolution also divides the
content width by the ratio without accounting for the ratio's box model.

Commit `7b9e6a8ab` converts these Chromium CSS ratio blocks once, transfers the
final width through the existing aspect-ratio box-model helper and applies
block-size constraints before percentage descendants resolve their height.
Natural replaced boxes keep their existing path. The translated LibWeb policy
retains its recorded behavior. All **three focused test functions / eleven
style and policy cases pass with default GC and GC disabled**. All **315 existing
formatting-context tests pass**, including the replaced-size and constraint
controls. The original code
fails the width regression; an intermediate width-only correction fails height.
Those failures and an accidental runtime launch before compilation completed
remain in the evidence.

The authored `block-border-box-aspect-ratio` browser fixture checks full-width,
small, padded, min/max-clamped and explicitly sized blocks with percentage
children. Two fresh ordinary Brave file captures exit zero and match each other
and a clean full-uBO source capture exactly. Several attempts to replay the
reducer with full uBO fail browser cleanup and receive no acceptance credit.
The fixture contains no scripts, ads or fetched image assets. Its preceding
native result is **9,950 differing pixels**. The new input, expected PNG and
suite registration are committed; existing references and tolerances are
unchanged.

Production executable `557eb0c8…` contains both sizing changes in its sealed
compiler input. All **five focused browser regressions pass at zero pixels**,
including the new ratio fixture, SVG natural sizing, SVG min/max clamping,
intrinsic button baselines and the Engadget header. The full candidate improves
from **202,684 to 22 native pixels**, with maximum channel error 2. They lie at
the bottom corners of the two lower photos. The source/frozen gate still differs
at **295 pixels** and the two fresh Brave replays agree exactly. All three
controls—Hacker News, WIRED and The Register—pass every strict gate at zero
pixels with complete caches; WIRED retains its first-frame image policy.
Executable, library and runtime-asset identities remain unchanged within and
across these checks. The separate candidate source-fidelity failure prevents
strict Engadget acceptance.

The uninterrupted broad run completes **133 tests / 139 captures**, with
**136 captures exact** and unchanged executable, library, fixture and tool
inputs. It retains the same three preceding failures: AVIF YUV sampling
(34,796 pixels), Pikabu hoisted image clip (1,097), and Pikabu direct composited
image (1,097). There are no additional pixel failures or process errors.

The remaining 22 pixels are sensitive to multisampling: adding a visible SVG
changes those same corner samples in both browsers. Removing the surrounding
page makes both browsers agree at all 22 samples, although the reduced photo
page has separate interior sampling differences and earns no acceptance credit.
Adding an offscreen SVG changes neither browser, so the initial geometry-grid
hypothesis is not supported by that reducer. Its temporary unit-test patch and
intentionally interrupted compile are retained; no grid implementation change
is kept. Disabling the optional GPU-canvas path also leaves the 22 pixels.
The separate no-image offscreen-corner control has exact full-uBO source and
two fresh replay references and already matches Vox. These diagnostic controls
do not replace the failing full-page source or native results.

A corrected native interposition probe preserves the 22-pixel result and
records root-grid cells `0,1,2,3,5,7,8,9,10,12,13` at 1024×256. Disabling all
root MSAA removes those samples but introduces **109 other differences**.
Explicitly dropping only root cell 2 makes the native PNG exact. That override
is a workload-specific diagnostic, **not an implementation fix or acceptance
result**; the production result remains 22. The initial `RTLD_NEXT` probe times
out without a PNG and remains recorded. The next renderer investigation is
the eligibility of draws entering root cell 2, including retained menu layers;
the source-fidelity gap remains independent.

[Exact commands, identities and checks](evidence/engadget-ratio-sizing-20261105.json),
[retained screenshots, logs and failed attempts](evidence/engadget-ratio-sizing-20261105.zip).

## Engadget: degenerate border arcs (2026-11-05)

Commit `c2deb6773` removes the candidate's final **22 native pixel differences**
on production executable `fc1b35e2…`. Follow-up checks on `68cec440…` with
verified empty and separately warmed replay caches also give exact Vox and two
fresh full-uBO Brave pixels. Independent decoded RGBA byte hashes agree for all
three PNGs under both policies. The **295-pixel saved-source/frozen gap remains
open**, so this does not qualify Engadget as a strict site pass. Candidate
manifest `fa56c7ca…` and registered manifest `53ea109a…` are unchanged.

The retained trigger list identifies three ordinary CSS borders: the Latest
Stories top rule and two vertical dividers. Their packed paths contain
zero-radius arcs with equal start and end points, such as
`M 24 733 A 0 0 0 0 0 24 733`. The MSAA classifier treated every arc as a curve
and enabled multisampling for the photos' bottom-corner tile. The
[SVG path rules](https://www.w3.org/TR/SVG2/paths.html#ArcImplementationNotes)
omit an arc with identical endpoints and turn a zero-radius arc into a line.
The correction applies those rules when classifying CSS border paths. Real
curves, diagonal segments and dashed borders retain their MSAA selection.

All **seven focused tests pass with default GC and GC disabled**. They include
the three actual border geometries and controls for omitted arcs, vertical and
horizontal zero-radius lines, diagonal lines, real curves and dashes. All
**21 additional MSAA controls pass**. The new
`chromium-degenerate-border-arcs` browser control, committed as `f93de5999`,
has exact full-uBO source fidelity, two agreeing fresh Brave references and
zero native differences. It embeds a small opaque PNG to avoid WebP decoder
variation; no existing golden or tolerance changed.

The historical attempts before the cache-protocol correction retain their
reference variation. Their closed uBO template also contains HTTP responses;
the earlier "cold" label does not establish an empty Brave HTTP cache:

| Build / cache policy | Native versus first Brave | Fresh Brave disagreement | Source versus first Brave | Result |
| --- | ---: | ---: | ---: | --- |
| `dd2957bc…` / complete, before fix | 87,153 | 87,131 | 87,413 | Reference replay mismatch |
| `fc1b35e2…` / complete, fixed | 87,181 | 87,181 | 87,366 | Reference replay mismatch |
| `fc1b35e2…` / labeled cold, template HTTP cache retained | 0 | 0 | 295 | Source-fidelity mismatch |

The pre-fix native PNG is byte-identical in decoded RGBA to its earlier
22-pixel result. The fixed native PNG matches the retained agreeing Brave
pair and the second fresh complete-cache reference at zero pixels. This does
not discard either complete-cache failure or turn it into acceptance credit.
These are replay checks of the same complete-acquisition candidate, not new
acquisitions.

Commit `2fb0edff5` corrects the oracle cache protocol. After uBO is ready and
before page navigation, cold runs clear the private browser's inherited HTTP
cache. Warmups also begin empty; only their successfully closed output profiles
are retained for complete-cache replays. All replay page targets bypass saved
site service workers. The harness records and validates these operations and
fails if their proof is absent or differs from the requested policy. Extension
stores remain intact. All **131 Node checks and 32 Python conformance checks
pass**, including cache failure and missing-proof controls.

The corrected runs pin `68cec440…` with unchanged browser identities throughout:

| Site / verified replay cache | Native versus Brave | Fresh Brave disagreement | Source versus Brave | Result |
| --- | ---: | ---: | ---: | --- |
| Engadget / empty | 0 | 0 | 295 | Source-fidelity mismatch |
| Engadget / warmed | 0 | 0 | 295 | Source-fidelity mismatch |
| The Register / empty | 0 | 0 | 0 | Strict pass |
| The Register / warmed | 0 | 0 | 0 | Strict pass |

The initial corrected launcher fails because its fixture aliases do not yet
exist; it supplies no pixel result and remains recorded. The corrected cohorts
retain every completed comparison, including Engadget's source failure. The
earlier reference failures remain evidence under their original protocol.

The diagnosis uses fresh debugger processes and validates the current C ABI
against the sealed compiler input before reading bounded scalar path data.
The first run stops at exec without a screenshot; a second reaches the 3 GiB
aggregate cap. The instrumented debugger sessions then use the standard
12 GiB job bound, while normal browser captures and focused runtime tests keep
their 3 GiB bounds. Intermediate helper errors and every failed attempt remain
recorded. The final diagnostic preserves the 22 pixels and reports the three
border paths; it supplies diagnosis, not acceptance pixels.

Shared build attempts fail for disk space before the containing build
publishes. Cleanup removes only closed task profile copies and obsolete task
unit binaries, preserving sealed archives, PNGs, logs, receipts and retained
comparison templates. The containing receipt is
`20261105-085357-ec81582c`; its frozen compiler input contains the corrected
classification. No duplicate production build is queued.

The broad run completes **134 tests / 140 captures**, with **137 captures
exact**, no process errors and all 306 pinned input files and browser identities
unchanged. Its three failures are the preceding AVIF YUV sampling case
(34,796 pixels), Pikabu hoisted image clip (1,097), and Pikabu direct composited
image (1,097). The focused site controls overlap the tail of this single broad
run because the guard creates an initially empty report file. The private
scheduler now waits for a completed JSON report; the original helper and
actual receipts remain available. These checks make no performance claim.

Hacker News and WIRED pass all strict gates on `fc1b35e2…` under the earlier
prepared-template protocol; WIRED retains its first-frame image policy. The
Register's earlier complete-cache control has **35,498** native/first-reference,
source/first-reference and
independent-reference differences. Its native PNG matches the saved source
and second reference exactly. A separate control labeled cold also has zero
pixels, but retained template responses prevent an empty-HTTP-cache claim.
The corrected empty and warmed Register controls above pass every strict gate;
the old failure is not attributed to this renderer fix.

[Commands, identities and verdicts](evidence/engadget-degenerate-arcs-20261105.json),
[raw results and failed attempts](evidence/engadget-degenerate-arcs-20261105.zip).

### Remaining source backgrounds

The 295 saved-source differences occupy rounded photo edges and borders within
`(24,88)`–`(999,544)`, with maximum channel error 4. Two separate diagnostic
variants make only the photo-holder backgrounds transparent or absent. Each
then matches the retained source at **zero pixels** and differs from the
unchanged frozen reference at **295 pixels**. These variants alter page CSS;
they establish a pixel effect, not a production correction or acceptance result.

A read-only preload records computed styles and rectangles from fresh full-uBO
live and frozen processes. All **eight inspected photo holders and their
descendants agree** in the recorded fields, including background, borders,
clipping, transforms and opacity. The frozen diagnostic retains all original
295 differing samples. The live diagnostic differs from the original source
at 24 of those samples and from the old frozen frame at 294; image-state
variation remains relevant. Background occlusion is consistent with these
observations, but its internal Brave call path is not established.

A small RGB-PNG control does not reproduce the source behavior when image
insertion, picture reattachment or stylesheet insertion is delayed. Giving
the picture its actual block display and the holder its actual background
also leaves Brave and Vox exact. This prevents treating a generic missing
background rule as a justified renderer fix.

The ordinary fresh complete-cache acquisition reaches a stable live warmup
frame but fails owned-process shutdown. Its cleanup also raises a permission
error and leaves an empty inner memory-guard report. The acquisition receives
no acceptance credit and creates no replacement archive. The instrumented
style probes exit normally but remain diagnostics. Earlier diagnostic launcher
failures, all frames and logs are retained. The registered archive, candidate,
existing goldens and tolerances are unchanged; strict source fidelity remains
open.

[Diagnostic verdicts and limits](evidence/engadget-source-background-20261105.json),
[raw probes and failed attempts](evidence/engadget-source-background-20261105.zip).

## Engadget: repaint diagnostics and oracle exits (2026-11-05)

The fresh complete-cache acquisition reproduces **0 native / 0 independent
replay / 295 source pixels** on `c81e92df…`. Its source PNG is unchanged from
candidate `fa56c7ca…`; the new manifest is `69897e15…`. All six full-uBO browser
processes, including the request-log oracle, exit normally with no surviving
observed helpers. The new candidate remains unregistered. Its exact 70 files
can be restored from the existing candidate ZIP plus the four changed files
and two removals recorded in the evidence; the reconstructed hashes are checked.

A preceding cold comparison of the older candidate on `d4e842eb…` fails
independent-reference agreement at **87,131 pixels**, with 87,131 native and
87,413 source differences from the first reference. Vox matches the second
reference and its preceding native frame exactly. Both attempts remain
recorded; the fresh acquisition does not discard that reference variation.

The paint probe reacquires Brave's layer tree after navigation. This itself
forces repainting: one frozen process changes **295 pixels** and then matches
the old source exactly, with two agreeing post-inspection frames. The recorded
picture contains no visible photo-holder background commands. A live process
also omits those backgrounds and changes zero pixels after inspection, but its
image samples still differ from the old source by 87,133 pixels. These are
instrumented diagnostics. Neither the post-inspection PNG nor transparent CSS
is installed as a replacement reference. The initial stale-layer-ID failure
and probes interrupted by debugger shutdown remain retained; the completed
probe defers debugger close until its paint-record reads finish.

Commit `4517407d7` fixes an independent oracle correctness error: waiting for
the process tree to disappear previously accepted nonzero and signalled
browser exits. These now fail before saving a prepared profile. Successful
shutdown requires exit code zero, no signal and no remaining observed helpers.
An unchanged eight-second watchdog still rejects survivors. Every visit writes
a separate shutdown receipt with process states, executable names, creation
identities, remaining ownership and the browser's final status. The original
comparison-failure receipt remains separate. Older runs do not gain this new
exit-status proof retroactively.

All **135 Node checks and 32 Python checks pass**. The new nonzero-exit
regression fails against the old implementation in an in-memory negative
control. Fresh complete-cache **Hacker News and WIRED pass all strict gates**
on `c81e92df…`; WIRED retains its explicit first-frame policy. The 14 full-uBO
processes across those controls and the fresh acquisition have verified normal
shutdowns. Browser and tool identities stay unchanged within each cohort.

Two fresh ordinary Brave file captures reproduce each of the three retained
image goldens exactly. Native rendering still differs by **1,097 pixels** in
each Pikabu image case and **34,796** in AVIF sampling. Disabling shared YUV
uploads changes neither tested failure. These focused diagnostics preserve
the existing references and do not establish a new broad-suite pass. The
earlier baseline uses a parallel build and the subsequent cohorts a single-C
build; this is pixel evidence, with no performance comparison or claim.

[Commands, exit receipts, hashes and verdicts](evidence/engadget-repaint-oracle-20261105.json),
[raw attempts and reconstructable candidate delta](evidence/engadget-repaint-oracle-20261105.zip).

## The Register: block-content centering (2026-11-03)

The Register is the next active site. Its registered archive remains unchanged
(`44f76a95…`). On executable `fdea37c1…`, two fresh Brave references agree but
the original source still differs by **110,180 pixels**; Vox differs by **6,786**.
Of that native gap, **6,509 pixels** are in the header and **277** in the hero
image. The logo's image box has the correct width and height but starts at
`y=0` instead of Brave's `y=13`.

Commit `51574b6dc` implements horizontal block-content alignment. The header's
70px block uses `align-content:center` around its 44px child, requiring a 13px
offset. The layout pass applies distribution after final sizing and before
positioned descendants/relative insets; non-normal alignment establishes an
independent formatting context so child margins and floats stay contained.
The [CSS alignment rule](https://drafts.csswg.org/css-align-3/#distribution-block)
aligns the contents as one unit, with positional fallbacks for distributed values.
Flex/grid/table/multicol and vertical writing retain their separate paths.

All **six focused layout tests pass with default GC and GC disabled**, including
repeated layout, margins, minimum heights, inline content, floats and positioned
children. All **315 existing formatting tests pass**. The new
`block-content-alignment` browser regression is registered in the rendering
suite. Its full-uBO source and two independent frozen Brave captures match at
zero pixels; the pre-fix browser differs by **19,230 pixels**. Its expected PNG
is a new authored regression reference; no existing golden changed.

A new complete-cache acquisition through the current explicit HTTP proxy
produces candidate manifest `4f343769…`. Both its **source/frozen and independent
Brave replay comparisons pass at zero pixels**, unlike the old archive. On the
pre-fix `6a0f6c5a…` browser its native gap is **7,465 pixels**, comprising **6,509
header / 956 body pixels**. That candidate remains separate from the registered
archive until the full gate passes. Live scripting and whole-site behavior are
outside this frozen viewport result.

At the initial checkpoint, production pixel validation was pending. The shared
compile receipt `20261103-192306-58b60ec7` contained the implementation while the
published bundle predated it. A five-minute bounded validation job checked the new
regression, candidate and Hacker News control if a qualified replacement was
published during its observation window; its linked status records the timeout.
Earlier failed builds rejected repository changes before C preprocessing.
The initial fixture's uBO startup failure, SOCKS acquisition timeout and attempt
using the retired HTTP proxy port are retained; none supplied reference credit.
[Durable evidence](evidence/register-parity-20261103.json),
[original baseline](../Build/register-parity-20261103-next/baseline/summary.json),
[fresh candidate](../Build/register-parity-20261103-next/fresh-current-http/summary.json),
[publication validation status](../Build/register-parity-20261103-next/published-validation.json).

### Register production checks and remaining pixels (2026-11-04)

Production executable `9ebd66e2…` contains the block-alignment implementation.
The same source-qualified candidate improves from **7,465 to 982 native pixels**;
source/frozen and independent Brave replay comparisons remain **0**. The header
is now positioned correctly. Its authored regression has **80 pixels** of
one-byte edge error on a white rectangle inheriting a fractional translation.

The main remaining text error was automatic hyphenation of the final word in
the IPO subtitle. Commit `81434ddb0` follows Blink's
[paragraph-final-word policy](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/fonts/shaping/shaping_line_breaker.cc),
keeping that word intact when it can move to the next line. On production
executable `1af7388d…`, the same candidate improves to **246 pixels**, with
**0 source/frozen and independent replay differences**. The residual is **26
header SVG pixels and 220 photo pixels**, with a maximum channel error of 13.
This remains a failing zero-pixel gate.

The new authored `paragraph-final-hyphenation` reference has two identical fresh
Brave/uBO captures and exact source fidelity. The initial implementation fixed
its ordinary paragraph but exposed a separate span-boundary case, retaining a
942-pixel failure. Follow-up commit `da87d7d92` preserves Blink's exception at
the start of a new text range. All **eight hyphenation tests pass in both GC
modes**, including the ordinary/span distinction, long first words, nonfinal
words, language and intrinsic-size controls.

Commit `ca4549005` extends the existing Skia-coverage flag to plain backgrounds
inheriting a fractional translation. The failing control confirms that the
descendant previously missed that flag; all **eight background tests pass in
both GC modes** after the fix. The existing 80-pixel browser regression covers
the actual drawing path. Direct GPU and adapter probes produce the expected
half-coverage byte; they do not replace a complete production screenshot check.

Production executable `698536dc…` contains both follow-ups. All **three authored
browser controls pass at zero pixels**: final-word hyphenation, block alignment
and translated solid backgrounds. The source-qualified Register candidate still
differs at **246 pixels**, with both Brave comparisons exact. The **Hacker News
control passes all strict gates at zero pixels**. A subsequent lookup cleanup,
`e560b618d`, rejects nonfinal words before inspecting their text prefix; the eight
hyphenation checks pass in both GC modes with that change too.
Its browser regression also passes at zero pixels on executable `289eb15e…`,
whose generated code contains the lookup cleanup.

The full site's CSS replaces Foundation Icons glyphs with SVG backgrounds.
A preliminary font-only control is exact but does not reproduce that path.
The original SVG bytes in an isolated background fixture differ at **seven
one-byte pixels**, with source/frozen and independent Brave references exact.
Its first pair matches Vox's full-page icon pixels, while Brave changes coverage
in the full page. This narrows the next investigation to the SVG drawing context.
The registered Register archive remains `44f76a95…`; candidate `4f343769…` stays
separate while its strict gate fails.

Commit `d4f0561a5` addresses the SVG-picture rejection. Round-capped and curved
solid SVG strokes can stay in the complete picture, whose native recorder
computes their stroked bounds. Compact scalar batches retain their previous
straight, butt-ended stroke restriction. All **five picture-policy tests pass
in both GC modes**, including curves, caps, joins, dashed and non-scaling
fallbacks and the existing effect/clip/repetition controls.
All **11 existing scalar SVG tests also pass** with default GC.

The new registered `register-svg-stroke-recording` browser regression preserves
the two original SVG byte streams and adds a distant curved path. Its source
and two fresh Brave/uBO references agree at zero pixels; the available browser
differs by **107 pixels**, reproducing the larger coverage error. An earlier
attempt was rejected because the shared bundle changed during comparison; that
failure is retained alongside the qualified repeat. Production validation of
`d4f0561a5` remains pending: the existing shared compile predates the policy
change. Its five-minute publication observation ended without a qualifying
bundle, retaining a pending receipt. The prepared validation command covers
the new regression, the earlier controls, the Register candidate and Hacker News.
[Durable evidence](evidence/register-parity-20261104.json),
[measured candidate](../Build/register-parity-20261104/hyphen-fixed-candidate/summary.json),
[completed follow-up validation](../Build/register-parity-20261104/followup-validation.json),
[SVG-picture validation](../Build/register-parity-20261104/svg-followup-validation.json).

## The Register: exact guest viewport (2026-11-05)

Production executable
`2983f4d0e5af714059b1a4bc4f3f79f00e1dafacedeb233a4aa591f230a9f5b0`
passes **source/frozen Brave, independent fresh Brave replay, and Vox/Brave
at zero differing RGBA pixels**, with both cold and complete encoded-response
caches. This uses normal image animation policy, full uBlock Origin 1.75.0,
the pinned lists, a 1024×768 guest viewport and scale 1. Independent Pillow
RGBA-byte comparisons confirm all eight source/reference/native captures have
the same decoded-pixel SHA-256, `b1db81df…`.

The previously source-qualified candidate existed only under `Build/` and was
unavailable on resumption. The original registered archive still had 110,180
saved-source differences and two native header-edge differences; those remain
historical failures, not optimization credit. It is preserved byte for byte in
[`register-original-20261102.zip`](../Tests/Browser/Brave/candidates/register-original-20261102.zip).
A new acquisition through the configured HTTP proxy passes source fidelity and
independent replay exactly. Its initial native gap is **1,165 pixels**, all in
two text fragments, with exact header and photo pixels.

Commit `ef0a3531a` fixes the macOS dictionary search for words followed by closing
punctuation. Starting CoreFoundation's backwards search inside the comma/quote
suffix of `incident,'` returned no dictionary locations. Starting before that
suffix preserves the original string, range and UTF-16 offsets while finding
the expected breaks. All **three dictionary and nine layout checks pass in both
GC modes**, covering original DOM text and zero-length inserted hyphen ranges.
The new `hyphenation-closing-punctuation` browser regression improves from
**4,094 pixels to zero** against two agreeing full-uBO Brave references with
exact source fidelity. The earlier final-word, header-alignment and SVG-stroke
browser regressions also pass at zero pixels. All 29 conformance and 18 archive
Python checks pass.

The sealed 128-file candidate is committed separately as
[`register-guest-20261105.zip`](../Tests/Browser/Brave/candidates/register-guest-20261105.zip)
in `678fc8e03`. Registration commit `94897c89a` installs those exact bytes;
manifest SHA-256 is `304107f4…`. No existing focused golden or tolerance changed.
The initial direct acquisition failed document coverage and crossed a bundle
publication. An HTTP synthetic fixture could not use the HTTPS-only SOCKS
replay endpoint; its HTTPS replacement qualifies. The first V invocation omitted
`-enable-globals`, and a combined layout compile/run reached its 3 GiB guard;
separate compilation and capped execution pass. The first cold-cache production
attempt failed Brave shutdown cleanup; the complete fresh repeat passes every
gate. These failures remain in the evidence.

WIRED and Hacker News controls also pass every strict gate at zero pixels on
the same executable. The full rendering run completes **132 tests, with 129
passing and the same three retained image failures**: AVIF YUV sampling and
the two Pikabu image-clip cases. The executable and runtime-asset identities
remain unchanged across the entire 589-second run. This supplies an
uninterrupted broad checkpoint after the earlier WIRED runs crossed shared
bundle publications. Raw PNGs, commands, checks and failures are preserved in
the [evidence archive](evidence/register-punctuation-20261105.zip).
This is frozen-viewport parity; live scripting, interactions, scrolling and
whole-site behavior remain outside the claim.
[Durable evidence](evidence/register-punctuation-20261105.json).

## Slate: AVIF image decoding (2026-11-04)

Slate is the next active site. The registered archive remains unchanged at
`e28a9ed9…`. On executable `289eb15e…`, the complete-cache comparison reproduces
the initial **221,448 native pixels**, **19,064 source/frozen pixels** and
**0 independent Brave replay pixels**. The photos are original AVIF responses
at `.jpeg` URLs; the old image model has zero natural dimensions and no decoded
pixels. The missing logo and icons use external SVG `<use>` sprites.

Commit `393a45902` adds static sRGB AVIF decoding through the existing libavif
dependency. Models keep straight, top-down RGBA; native painting premultiplies
before byte output. Images, CSS backgrounds and local files sniff the encoded
bytes, so JPEG-labelled resources follow the same decoder. The macOS build
packages `libVoxAVIF.dylib`; the Linux build wires the helper when libavif is
available through pkg-config. Runtime validation here is macOS only.
Animation, ICC profiles and image transformations remain unsupported; input,
dimensions and decoded-pixel counts are bounded before output allocation.

All **19 native decoding/alpha/error controls pass optimized and sanitized**.
All **three V integration tests pass with default GC and GC disabled**, and all
**four existing JPEG XL controls pass** after the local-file sniffing change.
The two publisher AVIF files retain their original encoded hashes. Generated
alpha, animation, size and ICC controls have committed provenance.

Executable `ea74a6fa…` contains the new image paths and bundled decoder. It
renders both photos and reduces the registered page's native gap to **180,821
pixels**. Source/frozen still differs by **19,064**, while the two fresh Brave
processes agree exactly. A separate comparison confirms that its bundled helper
and the checked helper return identical straight and premultiplied RGBA bytes
for both publisher images and the opaque/alpha controls.

The registered `avif-image-paths` browser regression has exact full-uBO source
fidelity and two identical Brave references. The old browser differs at
**46,189 pixels**. The AVIF-capable browser differs at **26,279**: both alpha
panels are exact, but the opaque red panel has 8,192 one-byte differences and
the scaled photo has 18,087 differences. The two Slate photos are 8-bit,
full-range BT.601 **4:2:2** images. The existing planar renderer handles 4:2:0
and 4:4:4; 4:2:2 painting remains a separate rendering gap. No tolerance or
previous golden changed, and this is not a complete Slate parity result.

Fresh acquisition failed the required page-coverage gate both directly and
through the configured SOCKS proxy. Both failed attempts are retained and
neither replaced the registered archive. The consent banner remains part of
the frozen guest workload. Source qualification, opaque AVIF painting and the
external SVG sprites remain open.
[Durable evidence](evidence/slate-parity-20261104.json),
[original baseline](../Build/slate-parity-20261104/baseline/summary.json),
[AVIF-capable browser](../Build/slate-parity-20261104/avif-installed/summary.json).

## Slate: planar decoding, sprites and containment (2026-11-04)

The registered archive remains `e28a9ed9…`. Executable `10bec67f…` reduces its
native difference to **2,821 pixels**, with **19,064 source/frozen pixels** and
**0 independent Brave replay pixels**. This is still an open parity result.
The remaining native regions are header 125, left column 35, main photo 422,
right column 1,911 and consent banner 328 pixels.

The follow-up fixes preserve the original AVIF 4:2:2 planes through native
sampling and retain the same decode choices across cache requests. The static
AVIF browser regression now matches at zero pixels. External SVG `<use>`
sprites load through both initial preload barriers, and large embedded-image
URLs receive bounded decode-history identities. The focused native decode and
sampling controls, sanitizer checks and both V GC modes pass. Earlier ctypes
probes with an incorrect color-profile ABI are explicitly excluded from the
evidence.

Paint-contained images, overflow clips and backgrounds now snap from the outer
fragment inward. The expanded containment regression preserves every earlier
reference region and reduces its mismatch from 62,534 to **9 one-byte pixels**;
the nested clip and new background controls are exact. Seven layout controls
pass with default GC and GC disabled, including fractional movement of retained
backgrounds. Separately, `text-wrap: pretty` and `balance` score merged shaped
advances rather than independently rounded word widths. This removes the
spurious second line in the “Shirin Ali” author and the resulting headline
displacement. The wrapping controls pass in both GC modes.

Commit `de1afaa5e` adds Chromium's adjusted dash spacing and half-pixel border
stroke centers for single square dashed sides. Three layout controls pass in
both GC modes, and the parent-raster multisampling controls pass. Its authored
reference has zero source/frozen and independent replay differences; the old
production bundle differs by **4,544 pixels**. Production validation of this
fix is pending a shared bundle that contains it.

Acquisition now brackets source pixels with frozen-DOM, text and viewport
identities. Cache preparation retains original encoded response bytes and
headers separately; a cached response can reuse those headers only with a
matching request origin, body hash and unchanged header receipt. This repairs
missing CORS headers on cached fonts without changing their bytes. Full uBO's
updater is stopped and its list bytes are checked before and after each visit.
The focused archive, preparation, policy and identity tests pass.

Fresh candidates remain separate from the registered fixture. The pinned-list
candidate has stable live DOM, restored font headers and identical list hashes
at both boundaries. Its second Brave replay failed the guard's surviving-child
check after a successful browser exit; peak RSS remained below 3 GiB. It is
unqualified. Its first replay still differs from source at 16,448 photo/story
pixels and 2,412 consent-banner pixels. Earlier CSS, access, source-fidelity and
unstable-capture failures remain retained. No site reference or tolerance was
changed to obtain a pass.

[Durable follow-up evidence](evidence/slate-containment-parity-20261104.json),
[latest registered comparison](../Build/slate-contained-clip-20261104/production-wrap/summary.json),
[cache/header candidate](../Build/slate-source-20261104-pinned-lists/comparison/summary.json).

## Slate: exact frozen viewport (2026-11-04)

The unchanged registered archive `e28a9ed9…` now matches **Brave + full uBlock
Origin at 0 differing pixels**, with both cold and complete encoded caches.
Both runs also have **0 independent fresh-process Brave replay pixels**.
Production executable `6e17496f…`, receipt `20261104-171308-b650b0ea`, contains
all four final fixes. Fresh processes, sealed original response bytes, 1024×768
document viewports, pinned filtering lists and zero tolerance remain required.
The Hacker News control passes every strict gate at zero pixels.

The original saved-source fidelity check remains **19,064 pixels** in both
cache modes. Slate therefore retains `live-to-frozen-mismatch` status; this is
exact frozen-viewport rendering, not an ordinary live-site or full-script claim.
No registered source PNG or tolerance changed.

Commit `f79723f02` preserves non-stacking SVG ancestor opacity and distinguishes
inner SVG graphics from the outer CSS SVG bitmap scope. Its six-icon authored
matrix is exact in production; layout controls pass with both GC modes.
Commit `8c5d9c80e` retains the actual fractional clips when publishing opaque SVG
leaves through the audited GPU batch bridge. Its unmodified native control
fails, while all 16 candidate cases match complete GPU pictures, optimized and
sanitized. The complete-page logo improves from ten pixels to zero. The
attempted V clip-geometry workaround was removed.

Commit `ab4c39108` carries hard SVG-image bounds alongside antialiased destination
coverage. The hard-only intermediate browser fixed the leading edge but failed
at three trailing-edge pixels; that failure remains retained. The final authored
browser scene is exact. All 16 native hard/overflow-clip cases pass, and all 13
native clip, mask, color, MSAA, image and border programs pass under
AddressSanitizer/UndefinedBehaviorSanitizer.

Commit `94c603d80` prevents horizontal hidden overflow from promoting an inert
vertical `auto` axis to a scrolling raster. Slate's banner has 1,036 pixels of
horizontal overflow in a 1,024-pixel container, with no vertical overflow. The
old policy created extra layers absent from Brave's layer tree and changed the
button's raster origin. Sixteen DOM combinations pass in both GC modes, and
the existing raster-layer controls pass. The final complete-page banner is exact.

All four final focused browser controls pass. The broader suite executes
**123 tests / 129 captures: 119 tests pass and 125 captures are exact**. Every
capture uses the same executable identity, and all recorded HTML, PNG, resource
and test-module inputs remain unchanged. Four standalone fixtures still fail:
`avif-yuv-sampling` (34,796 pixels), `pikabu-direct-composited-image` and
`pikabu-hoisted-image-clip` (1,097 each), and
`chromium-positioned-header-image-gap` (56). These failures are retained; the
suite is not reported as passing. The earlier nine-pixel contained-image
control is exact on this build, without assigning optimization credit to an
unverified cause.

Separate source diagnostics find identical thumbnail draw arguments and identical
CPU-replayed RGBA bytes in a fresh live page and its frozen replay. However,
inspecting/replaying layer snapshots changes 98,275 pixels in the final screenshot
relative to ordinary frozen capture. These instrumented captures are excluded
from acceptance and cannot replace the original source. Two ordinary fresh
frozen references still agree exactly; that new source retains a 17,953-pixel
fidelity gap. GPU image-cache/raster history remains an investigation, not a
renderer-fix claim.

[Durable evidence](evidence/slate-svg-publication-parity-20261104.json),
[complete-cache comparison](../Build/slate-final-strict-20261104-171308-b650b0ea/summary.json),
[cold-cache comparison](../Build/slate-final-cold-20261104/summary.json),
[rendering suite](../Build/slate-contained-clip-20261104/final-inline-suite-results.json).

## WIRED: exact frozen first-frame viewport (2026-11-05)

The original registered WIRED archive, manifest
`36ce372012656721fb98070682a309d5d7a621607748d9e7a61de3ba44dc213e`,
is preserved byte for byte in
[the ordinary-animation archive](../Tests/Browser/Brave/candidates/wired-original-animation-20261105.zip).
Its reference fails stability: two original GIF responses loop indefinitely.
All 94 files round-trip exactly. The replacement registered scene uses the
explicit first-frame policy described below; the original GIF bytes remain
intact.

Commits `7541a3502` and `eea19aa09` add an explicit, recorded first-frame
image policy to acquisition and replay. Brave pins its image-animation
preference and Vox selects frame zero. An archive's policy cannot be silently
overridden during replay. Commit `6aa870d92` adds a browser regression with
external and embedded GIFs: its live source, two fresh full-uBO Brave replays,
and Vox are exact. Optimized and sanitized native GIF-policy checks pass.
This policy qualifies a static capture; it does not establish motion parity.

WIRED also exposed lost author CSS in the archiver. Chromium serializes a
CSSOM-inserted `font:var(...)` followed by `font-feature-settings` as empty
font longhands. The live page retains its intended font, while the serialized
page falls back to another face. Commit `ec5c6ba77` records original rule
strings at insertion and verifies their serialized rule identity before
freezing. Changed or unrecoverable rules fail acquisition. The reduced pending
font regression has exact source, independent replay and native pixels.

A new first-frame candidate preserves 2,254 inserted author rules. Its source
and two independent frozen Brave references are exact. On executable
`4eb56074784f880e3245713097e11e76d50187d1dc779974f94122517c140b04`,
Vox still differs at **121,964 pixels**. Its manifest is
`c70c845521149c08f0243e4529b8510581e47f9d7a56d4f3d9bb9ae4f9f90f7b`.
The separate ordinary-animation candidate fails again: source/replay differs
at **40,905 pixels**, and independent Brave replays at **44,080 pixels**.
These archives contain different captured page/media bytes and are not a
matched renderer comparison with each other. Commit `88671cbeb` preserves all
99 files of that ordinary-animation candidate byte for byte in
[its complete archive](../Tests/Browser/Brave/candidates/wired-author-animation-20261104.zip),
retaining the failed motion workload for follow-up.

Commit `0e2cb622f` preserves the then-unregistered first-frame candidate in
[a complete archive](../Tests/Browser/Brave/candidates/wired-first-frame-20261104.zip).
All 101 files round-trip exactly, including the original encoded responses,
full-uBO provenance and source PNG. Its native result remained unqualified
until the production checks below.

Commit `649e52860` repairs a seven-pixel excess in the consent description's
intrinsic height. Recursive flex cleanup discarded descendant text lines;
enclosing blocks then overlooked saved baselines and synthesized a bottom-edge
baseline for the inline button. The fix preserves nested flex/grid baseline
sets and lets enclosing blocks find them. Nine focused layout checks pass in
both GC modes, with every test call verified. The complete reduced banner's
description now measures **288 pixels**, and its border box **522.40625 pixels**,
matching Brave's geometry. These layout checks do not establish browser PNG
equality. The committed browser regression retains the old bundle's
**50,384-pixel** failure.

Commit `107b15e10` uses CoreText's `hhea` vertical metrics for downloaded fonts
under the macOS Chromium policy. WIRED's display font sets `USE_TYPO_METRICS`,
but CoreText still uses the `hhea` values. The former selection put its
headlines five pixels too high. Ten focused font checks pass in both GC modes;
`7fbf7cebf` retains a browser regression using the original encoded font bytes.
The intrinsic-baseline, downloaded-font and first-frame GIF browser regressions
all reach **zero differing pixels** in published production browsers.

Commit `74b5f4a3c` waits for decoding of visible, complete images before the
stable reference check. Two identical PNGs alone did not prove that image decode
preparation was complete: independent WIRED replays could differ by 28,297
pixels across four WebP photographs. Three fresh diagnostic replays with
explicit decoding match the unchanged saved source exactly. The shared capture
helper now records decode preparation and rejects decode failures. It retains
the consecutive-capture and independent replay gates. All **122 Node checks
and 29 Python conformance checks pass**.

The uniform protocol run on executable
`f7a36b29f87e6b334ac7aa14e177598eeb5e6ec18648f4af26e8c973090ea18c`
has **zero source/frozen and independent replay differences**, with **678 native
differences**. Browser and tool inputs remain unchanged throughout that run.
Thirteen disabled layout-reuse controls leave those 678 pixels unchanged;
that diagnostic does not establish that every cache path is excluded.

Commit `f73a2514a` corrects physical centering in reversed flex rows under the
Chromium policy. Mirroring a truncated half-space shifted WIRED's action row
by 1/64 pixel. Focused tests cover both text directions, normal/reversed rows
and columns, positive/negative free space, and preserve LibWeb's remainder
placement; both GC modes pass. On production executable
`7ce37121784a00da11f4099f0df0fbabc8a68cc48a948625d1b40739457bc552`,
WIRED drops to **198 native differences**, with source/frozen and independent
replay still **zero**. All four browser regressions pass, and Hacker News is
strict zero with a cold cache.

Commit `2fdac92da` truncates Chromium letter- and word-spacing to signed 16.16
text-run units before adding glyph advances. Five focused checks pass in both
GC modes, including existing HarfBuzz and optional-ligature controls. The new
browser fixture retains the previous bundle's 180-pixel failure with exact
source and independent references. On production executable
`efbd9bb05ad26dc97a1954934d4be54f0b7f2ffd9ef7eae1c273fa47fd396a2f`,
WIRED drops to **9 native differences**, with exact source/frozen and independent
Brave replay checks. All five focused browser regressions are exact. The
remaining differences are one account-icon pixel and eight photo pixels, each
with maximum channel error 1. A reduced photo with matching encoded bytes and
two translucent scrims is exact; the full-page raster geometry still needs
correction at that checkpoint.

Commit `32b22bf9c` retains root-scroller hit-test metadata when fixed overlays
cover a scrolling document. The source browser places this sparse photo in the
1,024-pixel root raster, while Vox had isolated it in a 602-pixel card raster.
Keeping the correct root tile geometry removes all eight photo differences.
Sixteen focused controls pass in both GC modes. Production executable
`c8a0f687…` leaves **one account-icon pixel**, with both reference gates exact.
Commit `8dfa77247` makes the reduced regression establish its root scroll
range explicitly; its original expected PNG remains byte-for-byte unchanged.
The corrected reduced source, both fresh Brave replays and Vox are exact.

Commit `b382d245d` permits a whole opaque header picture to resume after a
disjoint captured SVG path mask, including retained native ellipse strokes.
Seven focused predicate tests and 48 wider controls pass in both GC modes.
However, production validation exposes an incomplete handoff: the native
opaque-continuation flag was sent only for CSS-effect gaps. The header fixture
and full WIRED page still differ at **seven pixels** on `809de706…`, with exact
source and independent replay checks. A separate instrumented diagnostic that
supplies the missing flag reaches zero on both; instrumentation is not accepted
as production parity. Commit `3c4617f26` forwards the same proved continuation to the native
compositor for both gap types. Eight focused tests pass in both GC modes,
including the actual reduced header's layout and paint ownership. Native shared
picture, opacity-continuation and large-layer controls pass. Uninstrumented
production validation uses published executable
`2e38a43647171308010b7cf1eeffd8aba34170b74400d15b5284b0c5d597318d`,
receipt `20261105-002844-ad6b35b4`. The immutable preprocessed C contains the
correct native handoff. All seven focused browser regressions pass. The same
WIRED archive reaches **zero native, source/frozen and independent replay
differences**, and Hacker News passes its strict cold-cache control.

Commit `69c948cb3` registers the exact 101 files from first-frame
candidate `c70c8455…`, including its original source PNG. The candidate's
source PNG, encoded responses and zero-pixel threshold stayed unchanged
throughout the rendering fixes. Both the former
ordinary-animation scene and this first-frame candidate remain available as
complete ZIP archives. This result covers the frozen guest homepage and its
consent dialog, in a 1,024×768 document viewport at scale 1 under explicit
image-animation policy `none`; live scripting,
scrolling, motion and whole-site behavior remain outside the claim. Both
registered-fixture cache checks, complete and cold, pass all strict gates at
zero pixels on the same production executable. The first expanded rendering run completes 130 tests and 136 captures, but
cannot establish a single-build result: the shared bundle changes from
`2e38a436…` to `82b6eb4b…` during capture. It records the three earlier image
failures, a four-pixel Stack Overflow header regression, and one rejected
capture spanning the bundle replacement. A fresh pinned repeat confirms the
four header pixels while the fixed-metadata control is exact.

Commit `fa56dfd57` excludes fully clipped boxes from hit-test metadata, using
the compact paint recorder's existing empty-clip proof. A collapsed hidden label
had no paint but still extended its header from x=0 to x=-1, changing its raster
tile origin. Both new baseline metadata assertions fail before the correction.
All 19 metadata checks, including the three new tests, pass in both GC modes;
thin nonempty clips remain represented. The actual header's bounds now match
the control without the hidden label. Production executable
`aa370dd4a75a63f6db5b233ba4c33732ced7381c1693f3b2c256b216f01e7274`,
receipt `20261105-004824-8773f951`, contains the correction. All **nine focused
browser regressions pass at zero pixels**, including the restored accessibility
header and the fixed-metadata control. Registered WIRED passes every strict
gate with both complete and cold caches; Hacker News's cold control is also
exact. Independent Pillow decoding confirms equal RGBA bytes for all nine
fixtures and all four WIRED source/reference/native images under each cache
policy.

Two further expanded runs each complete **130 tests / 136 captures**, with
**132 exact captures**, the same three image failures, and one rejected capture
spanning a shared bundle replacement. Fixtures, references and tool sources
remain unchanged; the browser identity changes during each run. The three
known pixel failures retain their previous counts: AVIF YUV sampling **34,796**,
Pikabu hoisted image **1,097**, and Pikabu direct composited image **1,097**.
The interrupted fixed-metadata, single-SVG-opacity and large-layer fixtures all
pass a fresh focused run with unchanged executable/native-library identities.
All three broad attempts remain retained; an uninterrupted single-build suite
result is not established. WIRED's earlier strict complete/cold runs and its
nine focused regressions remain qualified by their pinned executable above.

The wider intermediate and final layout controls also fail two text-control
expectations (13.5 versus 13, and radio baseline 16 versus 15). Their attribution
remains unresolved. The retained broad baseline on `487c7846…` runs 126 tests
and 132 captures: 128 captures are exact, four fail, and none error. A later
broad run on `6c57297b…` has 128 tests / 134 captures: 131 exact, three failing,
no errors, and unchanged browser/fixture/tool inputs. Downloaded fonts now pass;
AVIF YUV sampling and two Pikabu image cases remain open. No full-suite pass
is claimed.

[Evidence and qualification](evidence/wired-parity-20261104.json),
[site captures and checks](evidence/wired-parity-20261104-raw.zip),
[4 November rendering captures](evidence/wired-rendering-20261104-raw.zip),
[5 November rendering captures](evidence/wired-rendering-20261105-raw.zip).

## Discord (2026-11-05)

Discord's guest homepage joined the catalog as its sixteenth site. It was
downloaded once through the SOCKS proxy by the full-uBO Brave harness; the
sealed archive keeps 113 original responses, the frozen guest DOM with its 33
scripts removed, and the live source PNG. Every comparison replays it through
the local proxy without forwarding. Brave is 156.1.98.60; 1024x768, scale 1,
cold caches.

| Stage | Vox → frozen Brave pixels |
| --- | ---: |
| Shared bundle `c0203bb8e` | 226,441 |
| Flex, grid and single-tile background fixes | 12,512 |
| Unsnapped paint rect (`53c6e33d…`) | **6,261** (max error 4) |

Three fixes account for the change:

- `140a0b996`: a percentage-width replaced flex item keeps its specified size
  as its automatic minimum. Discord's chat images had shrunk to half their
  row, and four sections were 128-155px short.
- `77200c451`: Chromium sizes grid rows one span group and one step at a time.
  The footer's social row had moved 18.66px and the grid lost 1/32px, which
  changed the page height that the `cover` background depends on.
- `73262c05f`: single-tile bitmap backgrounds follow Blink's
  OptimizeToSingleTileDraw, sampling from the unsnapped tile and paint rect.
  The 131x768 page background upscales 7.85x, so a 0.05-texel source shift
  changed most background pixels by one level.

With these, the body height (6030.828125px) and every section match Brave,
and the background, headline, paragraph, nav links and buttons are exact.
The new `discord-background-paint-rect` fixture matches two agreeing Brave
captures exactly; the preceding build differs at 19,528 pixels. The 131-case
inline suite keeps its three known failures with unchanged counts.

Remaining gaps:

- Brave composites the hero container, nav logo and Log In button as overlap
  layers above Webflow's `translate3d(0,0,0)` elements, and rounds them as
  premultiplied 8-bit layers. That accounts for about 5,100 pixels along the
  hero's semi-transparent edges. Vox keeps content under the hero's
  `perspective: 999px` in one root raster and has no transparent-surface path
  for overlap-promoted layers. Letting flat perspective subtrees layerize
  alone was tried and backed out: without that surface it exposed a new
  difference on the second section's robot image.
- Three 14x14 blurred SVG stars (a pattern-filled embedded PNG) differ by up
  to 3 per channel.
- Brave renders the hero image in one of four variants (two independent
  rectangles of sparse ±1 pixels) across fresh processes. The archived live
  capture is a rare variant, so the saved-source gate fails at 598 pixels
  even in runs where both fresh references agree.

[Evidence](evidence/discord-parity-20261105.json). Raw captures are in
`Build/discord-20261105/`.

## Run

```sh
python3 -m zipfile -e \
  Tests/Browser/Brave/candidates/wired-first-frame-20261104.zip \
  Build/wired-first-frame-fixtures-UNIQUE
python3 tools/forum_news_pixels.py --sites wired \
  --fixtures Build/wired-first-frame-fixtures-UNIQUE \
  --extension Build/wired-parity-20261104-inputs/extension/uBlock0.chromium \
  --checker Build/wired-parity-20261104-inputs/adblock-check \
  --diff-tool Build/pixel-tools/pixel_diff --cache-policy complete \
  --output Build/wired-first-frame-replay-UNIQUE

python3 tools/forum_news_pixels.py \
  --sites techcrunch,engadget,theregister,slate,wired,discord \
  --extension Build/engadget-continue-20261103-1002/extension/uBlock0.chromium \
  --checker Build/engadget-continue-20261103-1002/adblock-check \
  --diff-tool Build/engadget-continue-20261103-1002/pixel_diff \
  --output Build/forum-news-five-UNIQUE

python3 tools/forum_news_image_effects.py \
  --extension Build/engadget-continue-20261103-1002/extension/uBlock0.chromium \
  --checker Build/engadget-continue-20261103-1002/adblock-check \
  --diff-tool Build/engadget-continue-20261103-1002/pixel_diff \
  --output Build/forum-news-image-effects-UNIQUE

python3 tools/test_native_webp_decode_choice.py \
  --output Build/engadget-webp-decode-UNIQUE
python3 tools/test_native_webp_decode_choice.py --sanitize \
  --output Build/engadget-webp-decode-sanitized-UNIQUE
```

Run expensive checks through the repository's memory guard. The driver also
guards every browser invocation at 3 GiB. Both native and source/frozen RGBA
comparisons must be exact. Frozen, script-free viewports do not establish live
scripting, scrolling, media or whole-site parity.
