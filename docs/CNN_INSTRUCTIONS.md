# CNN rendering and instruction comparison

Latest compiler follow-up: the pinned `-O3` build uses a median
**32,256,937,280** instructions, versus **34,091,298,943** for its matched
`-O2` control and **30,504,929,341** for Brave across seven triplets. Every Vox
candidate/control capture is pixel exact and every candidate beats its matched
control. The site goal remains **open**: the conservative gate fails
(`10 * 32,458,664,754 > 9 * 29,791,596,487`), and four Brave captures differ from
the unchanged reference. All seven attempts, including those failures and the
first-launch outlier, remain in the receipt. The two compiler variants use the
same normal generated/preprocessed code and native dependencies; only the C
optimization level differs. No V runtime checks or floating-point semantics
change. The `-O3` build passes the screenshot smoke set, eight SVG mutation
guards, headless smoke and 100 exact AST fixtures. Commit `a07e34ff` enables
that flag for the macOS prealloc production engine translation unit. Raw data:
`Build/cnn-home-compiler-seven-20261101-0817/`.

The intervening live-font-cascade change passes 80 focused cases per GC mode
and the same visual guards, but two exact diagnostic triplets show no repeatable
site instruction saving. It receives no CPU credit. Those counts and compiler
build attempts are retained in the durable receipt below.

The shader-cache prototype was discarded after two exact diagnostic triplets
showed no useful saving. A changed shader entry-point namespace also caused
about 18 billion instructions in an owned Metal compiler service in both
first-pair variants. Those counters and attempts are retained; this work earns
no optimization credit and adds no shader-cache policy to the production code.
Raw evidence is under `Build/cnn-home-dawn-matched-20261101-0848/`.

The lazy-image batching change (`07d1e347`) snapshots which requests are near
one committed viewport before synchronous cached completions can invalidate it.
Source ownership and cancellation are still checked before each completion.
The diagnostic admits six requests together with exact CNN pixels. Current
checks cover 23 root cases per GC mode, 39 broader HTML/layout cases per mode,
the screenshot smoke set, eight SVG mutation guards and 100 AST fixtures.
The original movement fixture started outside the loading threshold; its failed
attempt remains, alongside a corrected fixture passing in both modes.

Two unprofiled diagnostic triplets have mixed full-coalition results:
**29,874,012,629 / 36,958,872,903** for Vox against
**31,423,152,926 / 31,222,913,480** for the same-binary control.
The process-only endpoints fall in both pairs, but owned GPU compiler-service
charges increase the second candidate's total. Those component counts do not
replace the selected launch-coalition scope. Both Brave captures also differ
from the fixed reference, so this earns no site acceptance or repeatable full
CPU saving. All attempts remain under
`Build/cnn-home-lazy-batch-matched-20261101-0918/`.

Explicit Brave scale and image-decoding diagnostics did not remove the pixel
variation. The normal measurement driver and reference remain unchanged.
The font-geometry slice (`33278ac1`) passes 49 cases in each of three modes.
Its first production diagnostic had zero reuse hits and a separate 119-pixel
gradient mismatch. Font and deferred-layer controls, plus native library swaps,
retain that mismatch. The shared raster-bounds correction (`fac01e59`) restores
CNN pixel equality; no reference or tolerance changed.

Guarded font refresh now preserves a cascade that the font computer still owns
(`75c8fef4`). It passes 147 focused runtimes across three compiler/GC modes, the
visual smoke and SVG guards, headless smoke and 100 AST fixtures. A diagnostic
uses 28,857,329,605 coalition instructions and confirms 1,433 retained cascades.
Two unprofiled triplets use 28,758,852,587 / 28,660,404,634 for Vox and
28,639,357,846 / 28,736,877,681 for its control: this slice has no repeatable
launch saving. All four Vox images are exact; Brave differs at 1 and 13,565
pixels, so neither pair qualifies. Evidence is under
`Build/cnn-home-font-refresh-matched-20261101-1021/`.

A production compilation completed but packaging failed when the shared disk
filled. Validation reuses a later successfully completed shared bundle with
matching required source hashes. Disposable completed-trial profile/cache copies
and rebuildable test binaries were removed with hash manifests; ten large
generated-source/log files were losslessly compressed. The original templates,
fixtures, raw counters, PNGs, audits and failed attempts remain. See the storage
incident in the durable receipt.

## November 1: current 10% request, sealed homepage cohort

The current target is **10% fewer instructions than Brave**, superseding the
older 15% request in the historical sections below. The completed seven-pair
cohort does **not** meet it: Vox's median is **41,186,019,148** instructions and
Brave's median lower bound is **31,496,128,055**. The conservative maximum-Vox /
minimum-Brave ratio is **1.3486672674**. The exact gate fails:
`10 * 41,535,524,696 > 9 * 30,797,458,870`.

Every one of these fourteen captures is pixel exact against the same unchanged
1024×768 reference. Each has all 82 ordered headlines, 80 image sources, eight
visible decoded images, real loaded CNN fonts, and the expected document body.
Every Vox traffic audit has 74 requests, 70 allowed, four blocked, and zero
full-uBO disagreements. No first-launch result or slower trial is excluded.

The counter backend is the exclusive LaunchServices resource coalition in both
engines, including exited helpers and explicitly allowed owned system services.
The scope starts at coalition creation and ends at encoded document PNG
availability: startup, window/target setup, full-uBO startup, readiness, and a
five-second settle are included. Vox ends before file writing; Brave's endpoint
includes delivery of the encoded PNG through CDP. Audits and teardown follow the
counted endpoint. GPU instructions, observer/replay and services outside the
exclusive coalition are excluded. Brave uses its initial headless target at
scale 1; Vox uses an inactive native window and scale-1 document capture.
OS filesystem and shader caches remain warm. Load averages span the retained
host receipts (18 logical CPUs); unrelated builds were active on this shared host.

This uses the newer 85-response archive at `Tests/Browser/Brave/sites/cnn`, with
original-origin sealed HTTPS replay, normal scripting policy, inline handlers
and uBO scriptlets, and author script elements removed. Fresh processes receive
private copies of the declared closed full-uBO profile and encoded response
cache. It measures the frozen rendering/startup workflow, **not live CNN author
JavaScript or isolated rendering time**. A separate diagnostic verifies that
JavaScriptCore initializes and executes the bootstrap/scriptlet/handler path;
`--enable-javascript` alone supplies no such evidence. Live-page parity remains
open.

Two engine changes are committed: stationary raster reuse now accepts immutable
nested snapshots and empty videos while rejecting live media, and unchanged
negative lazy-image geometry probes can be reused while still cancelling
superseded requests. Separate diagnostics verify both paths execute on CNN.
Earlier matched controls are retained, including noisy results and pixel
failures; they do not establish a repeatable final percentage saving. The pinned
candidate passes the screenshot smoke set, eight SVG mutation guards, 100 exact
upstream AST cases, and focused/broader tests in both GC modes. Four asynchronous
poster fixtures were repaired to wait for their actual completion events; their
original failures remain in the evidence.

The durable [cohort receipt](benchmark-results/cnn-home-instructions-2026-11-01.json)
retains exact counts, binary/native dependency hashes, fixture/reference pins,
host load, exits and memory-guard adoption. Raw commands, logs, PNGs, counter
membership and attempts are under `Build/cnn-home-acceptance-20261101-0653/`.
`tools/cnn_home_browser_instructions.py` is the current seven-pair driver.
A second seven-pair cohort adds the same-binary family-wide font-completion
control. All 21 captures remain pixel exact, but the selected-face candidate's
median is **40,624,138,961** instructions, against **31,867,698,094** for Brave
and **38,227,636,924** for the Vox control. Its conservative ratio against Brave
is **1.3336654651**; it meets neither the site goal nor the matched control gate.
Separate diagnostics verify selected-face invalidation executes, and 67 font
regressions pass in each GC mode. This change receives no CPU credit; a narrower
font-size dependency refinement is being checked. Raw evidence is under
`Build/cnn-home-font-matched-20261101-0703/`, with exact counts in the receipt.

The hidden-animation change (`6af8fd37`) stops CSS frame requests for targets
inside `display:none` subtrees, matching the existing animated-style consumer.
Display animations which can reveal a target remain eligible, as do transparent,
`visibility:hidden` and `display:contents` targets. Clocks/effects remain intact.
The diagnostic exercises hidden CNN ad-slot pseudo-elements and consent targets,
prepares **11** frames instead of the earlier **605**, and retains exact pixels.

Seven uninstrumented triplets retain all attempts and the same-binary control.
Every Vox candidate/control capture is exact, and every candidate uses fewer
instructions than its control (individual reductions 11.94%–28.04%). Median
Vox is **34,271,255,313** versus control **39,309,676,666** and
Brave **31,315,549,327**. This is still above Brave; the exact
10% gate fails: `10 * 34,582,950,864 > 9 * 30,835,969,151`. Brave pair 7 also differs
at **31,766 pixels**, matching the previously observed cross-process image
sampling variation. That trial remains included, so the cohort has no acceptance
credit. The independent Vox/control evidence establishes the redraw saving,
not the requested site goal. Raw evidence is
`Build/cnn-home-hidden-animation-matched-20261101-0728/`.

The feature passes 32 CSS cases per GC mode plus the screenshot smoke set,
eight SVG guards, and 100 AST fixtures. All 32 shell cases pass per mode when
their test process selects CSS-pixel coordinates; two initial failures per mode
used Retina device units and remain in the receipts. A fresh live load reaches
the CNN title and complete readiness (90 headlines, 85 images), but author
scripts report frame/consent bridge errors. Live script and visual parity remain
open; no live performance acceptance is claimed.

The following sections describe the earlier archive, tools and 15% target.

The CNN target remains open. The accepted result requires seven fresh-process
pairs with **zero differing RGBA pixels** and `max(Vox) <= 0.85 * min(Brave)`.
The preliminary instruction counts do not meet that target and receive no
performance credit while their images differ.

The private workload was captured from `https://edition.cnn.com/`, reached by
CNN's redirect, on October 17, 2026. It retains the live DOM, removes executable
script elements, and keeps normal scripting policy for `noscript` parsing and
uBlock scriptlets. Both engines receive the original encoded resource bodies
and response headers. Missing archive entries fail offline. This is a frozen
rendering workload, not a live CNN JavaScript or interaction parity claim.

## Identical filtering

Brave uses full Manifest V2 uBlock Origin 1.75.0 in an isolated prepared profile,
with Brave Shields disabled, empty user filters, automatic list updates off,
and the same ten repository filter-list snapshots as Vox. The existing Brave
profile is unchanged.

The earlier live capture audit matched all 268 request/header checks, including 24
blocked requests, with zero static-filter disagreements. Cosmetic CSS,
procedural filters and selected scriptlets also matched. A separate replay of
Vox's actual frozen-page traffic matched all 179 request/header checks over
124 distinct requests, including four blocked requests. The workload and raw
receipts are private under `Build/cnn-parity/`; the relevant receipts are
`capture-ubo.json` and `frozen-native-ubo.json`. These are observed-stream
results, not a claim of complete uBlock extension parity.

## Current diagnostic progress

The latest signed normal build uses scroll and overlap raster layers for gradient
origins and MSAA, including paths replayed from SVG background images. Its
standalone capture records **50,026,514,857 instructions** and **112 differing
pixels**, with maximum channel error 12; content, fonts and all 173 observed
full-uBO checks pass. The instruction count remains above the approximately
36.171 billion ceiling and establishes no saving for this rendering change. The earlier
868-pixel result included a transient scrollbar-policy difference: a fresh capture
of the unchanged older binary also returns 208 pixels without any configuration
override. The scrollbar disappearance receives no code-improvement credit.
No pixels are excluded, and none of these results passes the final performance
gate.

Before that scrollbar difference appeared, the isolated natural-image change
reduced the original CNN difference from 2,470 to **209 pixels**. Brave's exported
paint records show full images drawn in natural coordinates under a canvas scale;
Vox now retains that operation order. The export's own screenshot is byte-exact
against the original Brave reference. The separate 269-by-151 RGBA diagnostic
still differs at 86 pixels. Image controls pass 34 of the 35 pre-existing Brave
fixtures; the gradient fixture's scrollbar mismatch is also present in the old
immutable binary. The new translated-image fixture is exact.

Brave's paint record also shows the play icon at 17/64 scale. Replaying the
independently rounded SVG container into its snapped destination removes the
extra fractional scale. A three-size SVG background fixture improves from 27
pixels to zero. The original circle-background diagnostic improves from 123 to
96 pixels; its translucent circle-border differences remain open.

A fresh Brave diagnostic remains pixel-exact and records 42,554,598,225
instructions, whose 15% threshold is approximately 36.171 billion. No qualifying
seven-pair CNN cohort has completed.
The implementation now skips unused fonts in collapsed whitespace contexts,
connects TCP before allocating TLS state, initializes DOM JSON through the
native engine API, and batches raw parser text without bypassing delimiters or
stream boundaries. Rendering fixes retain eligible gradient stops, normalize
invisible premultiplied RGB, snap SVG root paint origins, and round SVG
background containers independently of tile edges. Linear gradients preserve
Chromium's float endpoints, snap eligible default tile geometry before
resolving stops, and use root raster-tile coordinates for dithering. Opaque
transformed partial borders now use snapped local origins and antialiased
rectangles, fixing the carousel arrow's large coverage error. SVG backgrounds
now preserve absent natural dimensions through default sizing and clip their
contents to the image viewport. This removes the thumbnail placeholder's large
corner error; small image-sampling differences remain there. CSS SVG mask
images snap their paint origin while preserving fractional DOM geometry and
SVG image coordinates inside mask resources. Fractional SVG,
text-shadow and image-sampling diagnostics keep their unchanged inputs and original Brave
references under `Tests/Browser/Brave/diagnostic/`.

Cold parallel filtering also exposed incomplete JSON metadata and interleaved
audit writes. Separate conversion and log locks preserve engine serialization
and complete request/header records. The latest actual native stream matches
full uBO across 173 checks, 118 distinct requests and four blocked requests,
with zero disagreements.

The SVG-background slice passes two focused cases in each GC mode, with
14,980 assertions per mode. Its eleven-case Brave fixture and the existing
font, raster-gradient and transformed-border controls are pixel-exact in both
the diagnostic and normal optimized builds. The integrated regression union
covers 25 files in both GC modes (50 logical checks). An initial grouped layout
compile had an import/local-name collision; recovery checks preserve every
source body and run the affected file separately. The failed invocations are
retained without pass credit. Receipts are
`svg-natural-size-broad/combined-results.json`,
`svg-background-natural-size.clipped-production.json`,
`production-svg-natural-size-clipped/controls/results.json`, and
`production-svg-natural-size-clipped-instructions/pair-1.vox.{json,ubo.json}`.
The normal bundle and source/binary pins are under
`production-svg-natural-size-clipped/`.

The CSS-mask-origin slice passes two focused cases in each GC mode, with
19,566 assertions per mode. Its thirteen-case synthetic Brave fixture, the
eleven-case background fixture, and font, raster-gradient and transformed-border
controls are pixel-exact in the normal optimized build. The corrected default
check recovered from a missing archive by compiling its unchanged saved C
response; the no-GC check ran the complete V command. Earlier failed invocations
are retained without pass credit. Receipts are under
`mask-origin-focused-linked/`, `production-mask-origin/controls/results.json`,
and `production-mask-origin-instructions/pair-1.vox.{json,ubo.json}`.
The current bundle and source/binary pins are under `production-mask-origin/`.

SVG masks now share the response-validated SVG document cache with backgrounds
within each layout tree, keeping source changes, failed loads, color-scheme
variants and per-consumer viewport sizes distinct. The ten related focused
cases pass in both GC modes (24,531 assertions per mode). The integrated
candidate includes the repository's completed property-store, DOM allocation,
selector and paint-culling improvements as well as this cache change; the
7,623,747,800-instruction diagnostic reduction is not isolated cache credit.
Its CNN screenshot is byte-identical to the preceding normal mask build.

The resulting broad batch passes 40 files in both GC modes (80 logical checks,
18 compiler invocations), all 33 exact Brave fixtures, eight exact SVG mutation
guards and all 100 upstream AST comparisons. The guards were recovered after
script permissions and nested reference-path mistakes; earlier failed harness
invocations receive no pass credit. The current normal bundle and pins are
under `production-mask-cache-current/`. Receipts are
`mask-cache-regression/results.json`, `mask-cache-current-broad/summary.json`,
`mask-cache-current-brave-fixtures/results.json`,
`mask-cache-current-svg-guards-paths.{json,log}`, `mask-cache-current-ast.log`,
and `production-mask-cache-current-instructions/pair-1.vox.{json,ubo.json}`.
Neither the CNN pixel gate nor its seven-pair performance gate passes.

The short attribute-substring slice borrows checked string ranges for patterns
up to 32 bytes and retains linear KMP search for longer patterns. Insensitive
substring, prefix and suffix matching folds ASCII only, preserving non-ASCII
case distinctions. Both GC modes pass 57,117 focused assertions and a 17-case
selector union (60,434 assertions per mode). A normal build preserves the page
PNG byte for byte and records 48,007,760,558 instructions, down 5,745,936,579
(10.689%) from the controlled 53,753,697,137 baseline. This diagnostic reduction
does not establish CNN performance parity. All 42 files in the resulting
broad batch pass in both GC modes (84 logical checks, 18 invocations), and all
33 Brave fixtures remain exact. Its actual native stream again matches all
173 uBO checks, including four blocked requests. Receipts are
`selector-substring-focused/borrowed/`, `selector-substring-regression/`,
`selector-substring-broad/summary.json`,
`selector-substring-brave-fixtures/results.json`, and
`production-selector-substring-instructions/pair-1.vox.{json,ubo.json}`.
The current normal bundle and source/binary pins are under
`production-selector-substring/`. Earlier failed test-call signatures and the
stopped allocating-slice build are retained without pass credit.

Chromium text shadows now use the retained font, glyph IDs and positions
through Skia instead of the fallback Core Graphics face. Their CSS blur is
resolved before the paint transform, avoiding double scaling. The foreground
C ABI and the portable/emoji fallback remain unchanged. The four-case opaque
font fixture is exact; 4,800 native foreground cache replays also match the
preceding library, and all 34 Brave fixtures pass in the optimized build.
The unchanged expanded diagnostics still differ: alpha/scaled flat shadows
have 1,085 pixels with maximum error 2; four blurred cases have 5,295 pixels
with maximum error 4. These remain open, with no tolerance or reference edits.

The resulting normal CNN capture has 2,490 differing pixels (32 over three
channel levels), maximum error 59, and 48,943,973,161 instructions. Full uBO
again matches 173 checks over 118 distinct requests, including four blocked
requests. The count is diagnostic only and does not meet the seven-pair
performance target. Receipts are `text-shadow-native-focused/result.json`,
`retained-text-shadow-brave-fixtures/results.json`, and
`production-retained-text-shadow-instructions/pair-1.vox.{json,ubo.json}`.
The current normal bundle and pins are under `production-retained-text-shadow/`.
An additional GPU glyph-mask experiment produced the same diagnostic pixels
as the corrected CPU bridge and was omitted. Arc-normalization and coordinate
prototypes also remain outside production after regressions or no CNN benefit.

Containing-block offsets now use an iterative raw sum when conservative
absolute bounds prove no intermediate saturation. Large mixed-sign chains
retain the original root-to-leaf saturating calculation. Three focused cases
pass 814 assertions per GC mode, covering ordered saturation, 400 mixed
chains, a 4,096-level chain and live ancestor updates. The resulting broad
batch passes 45 files in both GC modes (90 logical checks, 22 invocations),
all 34 exact Brave fixtures and eight exact SVG mutation guards.

Three fresh baseline/candidate pairs preserve identical page PNGs and reduce
total instructions by 3.4174%. Their candidate counts range from 50,511,311,673
to 51,337,710,641, versus 51,279,452,878 to 53,431,472,348 for the preceding
normal text-shadow bundle. The first standalone candidate records
51,742,412,525. These counts vary between processes and remain diagnostics;
they are not the required seven Brave/Vox pairs or a CNN performance pass.
The actual native stream still matches all 173 uBO checks, including four
blocked requests. Receipts are `cumulative-offset-focused/corrected/`,
`cumulative-offset-controlled-diagnostics/results.json`,
`cumulative-offset-broad/summary.json`,
`cumulative-offset-brave-fixtures/results.json`,
`cumulative-offset-svg-guards.{json,log}`, and
`production-cumulative-offset-instructions/pair-1.vox.{json,ubo.json}`.
The current normal bundle and pins are under `production-cumulative-offset/`.
The initial test-only optional-pointer C interop failure is retained without
pass credit; the corrected checks preserve all runtime assertions.

Explicit SVG circles and ellipses now retain their primitive identity through
the existing twelve-float native paint protocol. Graphite, CPU Skia and the
CoreGraphics fallback recognize their ellipse bounds; authored four-arc paths
remain ordinary paths. Computed geometry, live updates and retained snapshots
are covered by two focused cases (22,118 assertions per GC mode), and 145
native path checks pass. The common paint record remains 1,320 bytes. Ten
related files pass in both GC modes (20 logical checks, four invocations),
all 34 existing Brave fixtures remain exact, the new computed-ellipse fixture
improves from 184 differing pixels to zero, and eight SVG mutation guards are
exact.

The original expanded thirteen-case ellipse diagnostic is retained unchanged:
1,110 differing pixels become 405, with 818 pixel errors improving, 41
increasing and seven changed pixels retaining the same maximum error. Its
authored-arc and previously exact stroked-ellipse controls remain exact.
Fractional, transformed, dashed and small-circle raster differences remain
open. CNN improves from 2,490 to 2,470 differing pixels; pixels over three
channel levels fall from 32 to 16. No tolerance or reference changes are used.
Receipts are `ellipse-current-focused/summary.json`,
`ellipse-identity-focused/native-result.json`, `ellipse-identity-visual/`,
`current-svg-ellipse-brave-fixtures/results.json`,
`current-svg-ellipse-svg-guards.log` and
`production-current-svg-ellipse-instructions/pair-1.vox.{json,ubo.json}`.

The installed Brave extension directory was replaced between checkpoints.
The earlier pinned profile and receipts remain untouched. A private copy of
the current full MV2 uBO 1.75.0 and a newly prepared profile use the same ten
filter snapshots, empty user filters, disabled automatic updates and disabled
Shields. The fresh Brave screenshot matches the original reference exactly;
the native stream again matches all 173 checks over 118 distinct requests,
including four blocked requests. Pins and preparation receipts are
`current-ubo-profile.json` and `current-ubo-profile-preparation.log`; the fresh
Brave receipt is `reference-current-ubo/pair-1.brave.json`. The normal ellipse
bundle is pinned under `production-current-svg-ellipse/`. An earlier untagged
synthetic fixture exercised LibWeb policy and receives no Chromium check
credit; its tagged replacement and original screenshots are retained. The
first incomplete native diagnostic and a failed test-helper Option signature
are also retained without final feature credit.

The local-video installer now checks its immutable markup for the legacy
fixture reference at most once, lazily when a sourceless HTML video needs it.
CNN has eight such videos in 3,722,837 bytes of markup. Across three fresh
normal-process pairs, the installer phase falls from approximately 397 million
to 104 million instructions: a mean saving of 293,055,284 (73.809%). An
independent seven-pair C-O0 entry probe also confirms fewer instructions; it
has no production or whole-page credit. Existing native video ownership and
canvas-frame tests pass 26,212 assertions per GC mode. The broad union passes
49 unchanged module files in both GC modes (98 logical checks, 26 compiler
invocations); all 35 Brave fixtures remain exact, and the actual native stream
again matches all 173 full-uBO checks.

Whole-page results do not establish a reduction. The three candidate counts
range from 50,620,952,098 to 51,519,184,129, versus 48,923,460,406 to
52,802,237,932 for the baseline. Two pairs improve, but the aggregate increases
0.1196%; a separate first candidate records 47,536,437,100. All images remain
byte-identical with 2,470 differing pixels against Brave. These overlapping
ranges and the still-failing image gate receive no CNN performance credit.
Receipts are `video-fallback-focused/results.json`,
`video-fallback-entry-probe/results.json`,
`video-fallback-controlled-diagnostics/results.json`,
`video-fallback-broad-combined.json`, `video-fallback-brave-fixtures/results.json`
and `production-video-fallback-scan-instructions/pair-1.vox.{json,ubo.json}`.
The normal source and binary pins are under `production-video-fallback-scan/`.
The initial private probe's missing CSS import is retained without check credit.

The ellipse payload also supplies both corners to conservative MSAA tile
classification, preserving transformed, stroked and Retina bounds across tile
boundaries. Four focused tile cases pass 17 assertions per GC mode. A separate
native SVG leaf raster-origin probe yields byte-identical CNN pixels and is
not shipped; it has no performance credit.

The complete normal bundle with the MSAA bounds correction remains
byte-identical to the video-scan capture, records 49,967,109,139 instructions
and passes content/font gates, all 35 exact Brave fixtures, eight exact SVG
mutation guards and all 173 full-uBO checks. Source and binary pins are under
`production-ellipse-msaa-bounds/`; receipts are
`production-ellipse-msaa-bounds-instructions/pair-1.vox.{json,ubo.json}`,
`ellipse-msaa-bounds-brave-fixtures/results.json` and
`ellipse-msaa-bounds-svg-guards.log`. This single count remains diagnostic;
the CNN pixel and seven-pair 15% gates are still open.

The preceding isolated gradient-tile baseline passes a 24-file CSS/layout/HTML/
network selection in both default and no-GC builds, all 30 exact Brave
fixtures, eight exact SVG mutation guards, all 100 upstream AST comparisons,
signing and native startup. Earlier failed invocations are retained and receive
no wholesale pass credit. Browser JavaScript still runs on JavaScriptCore.
The test union carries 15 already-passing checks and adds 33 successful recovery
checks. Earlier disk-full and incorrectly configured compiler invocations are
retained without pass credit. The private receipts are
`gradient-tiles-broad-pinned-recovery/combined-results.json`,
`gradient-tiles-broad-images/results.json`, `gradient-tiles-svg-guards.log`,
`gradient-tiles-ast.log`, and
`production-gradient-tiles-instructions/pair-1.vox.{json,ubo.json}`. The preceding
border slice passes 90 focused assertions per GC mode and the unchanged paint
record size/lifetime contracts (16,004 assertions per mode). Its new three-case
Brave fixture is exact, as are the existing opaque-shadow and raster-gradient
controls. The colored-border diagnostic retains five one-level differences.
The final opacity fallback guard is covered by the focused checks; that older
partial-border diagnostic predates the guard and its CNN borders are opaque.
The current SVG-background bundle includes the guard. Its native
traffic again matches full uBO across 173 checks and four blocked requests.
Receipts are under `partial-border-focused/`,
`partial-border-and-fma-native-results.json`, and
`production-partial-border-instructions/pair-1.vox.{json,ubo.json}`. The current side-by-side
image is saved to `Build/cnn-parity/cnn-brave-vox-progress.png`.

## Reproduction

Build the normal signed bundle with `sh build-prod-browser.sh`. Capture a new
workload using `tools/adblock/brave_parity.mjs --url https://edition.cnn.com/
--capture-dir NEW_DIRECTORY --output LIVE_RECEIPT.json` as described in
[the adblock workflow](ADBLOCK.md). Prepare a full-uBO profile with
`tools/pikabu_browser_instructions.py --engine prepare-profile`; the profile
preparation is independent of which page will later be visited.

With the frozen cache, prepared profile and live receipt in place:

```sh
clang -dynamiclib -O2 tools/pikabu_instruction_network_deny.c \
  -o Build/pikabu-instructions-network-deny.dylib
python3 tools/cnn_browser_instructions.py --mode compare \
  --cache Build/cnn-parity/capture/cache \
  --profile Build/cnn-parity/ubo-profile \
  --extension "$CNN_UBO_EXTENSION" \
  --expected Build/cnn-parity/reference-initial/pair-1.brave.png \
  --adblock-reference Build/cnn-parity/capture-ubo.json \
  --output Build/cnn-parity/new-comparison
```

Set `CNN_UBO_EXTENSION` to the installed full-uBO extension directory. The native
adblock checker and exact PNG diff executable must already be built; see the
adblock workflow and `tools/check_pixel_equality.py`. Output directories must
be new. `--mode vox` and `--mode brave` capture one diagnostic run each.

The comparison pins the native executable and colocated dylibs, Brave,
extension, prepared profile, filter assets, expected image, archive, offline
guard, checker, driver, audit sources and the resolved Boehm runtime. Each launch receives a fresh cache
or profile clone. The native capture must contain the loaded CNN display
fonts and decoded visible images. Each measured Vox request log is checked
against the full extension outside the counted interval. Collector environment
and dyld loader overrides are rejected for production comparisons.

Filter audits also receive a fresh copy of the pinned prepared profile through
`brave_parity.mjs --profile-template`. Process locks and the old debugging
endpoint are omitted. The audit reloads the identical list bytes and clears
user filters; it never launches against or writes to the prepared source.

Counts use macOS `proc_pid_rusage(RUSAGE_INFO_V4).ri_instructions`. Vox includes
the exact root's final unreaped counter and teardown. Brave includes the
observed descendant tree through the last complete sampler pass before the
first screenshot response; this is a polling lower bound. Brave audit and
shutdown work are excluded. GPU instructions, WindowServer and external
services are outside both CPU counters. A mismatched or incomplete capture
cannot pass the performance gate.

The hover invalidation fix preserves DOM identity without copying Node records:
its 10,000-iteration regression allocates 34.56 MB before the fix and less than
4 KiB afterward. Both GC configurations pass. Three alternating native pairs
increase mean whole-page instructions from 49,519,917,196.67 to
50,863,284,679.33 (+2.713%); this is not credited as a page optimization.
Full-style invalidation uses the existing whole-subtree drain for both the
initial mutation plans and subsequent `:has()` fanout. Three focused cases pass
5,192 assertions in each GC mode, preserving removed attributes, shadow scopes,
and later selective updates. Its standalone page counts do not establish a
whole-page reduction. No new broad instruction-saving threshold is credited.

Private receipts: `hover-identity-controlled/assessment.json`,
`full-style-final-focused/`, `brave-skp-investigation/`,
`image-natural-coordinates-brave-controls/`, `gradient-controls-recovery/`,
`svg-snapped-picture-focused/`, and
`natural-image-final-normal-instructions/pair-1.vox.{json,ubo.json}`.
The latter bundle is pinned in `natural-image-final-normal/`; it includes the
four fixes above, based on the earlier isolated source, rather than unrelated
concurrent canonical work. The first SVG no-GC compile failed with ENOSPC before
running tests; the unchanged retry passes. Failed receipts remain retained.

Duplicate descendant invalidation suppression (`299be763`) restores the missing
upstream pending/active-list checks. Structural comparisons include the reason
and nested payload; equivalent records with a different ordering remain separate.
Three focused cases pass nine assertions in each GC mode, while the original
implementation fails all three. Three interleaved native pairs reduce the observed
mean from 50,258,308,254.33 to 48,632,429,750.67 instructions, with two wins out of
three and all six captures at 208 differing pixels. This noisy result is not a
robust final speed claim. Its observed saving exceeds the repository's five-million
instruction broad-check gate.

Explicit absent block-margin initialization (`b994ddfa`) reduces allocation for
512 empty contexts from 257,472 to 57,680 bytes. The final focused tests verify
the allocation bound and retained child ownership across copying and collection;
both GC modes pass two cases and 33 assertions, while the original implementation
fails the allocation bound. Three further interleaved native pairs observe a
207,195,607.33-instruction mean reduction, again only two wins out of three and
unchanged 208-pixel differences. The combined frozen-source regression batch
passes 49 files in both GC modes: 98 logical checks, 22 compiler invocations,
with unchanged implementation hashes.

Private receipts are `invalidation-dedup-focused/`,
`invalidation-dedup-controlled/assessment.json`, `invalidation-dedup-broad/summary.json`,
`block-context-optional-focused/commit.json`,
`block-context-optional-controlled/assessment.json`, and the signed bundles under
`invalidation-dedup-normal/` and `block-context-optional-normal/`.
The final block-margin tests use the retained `tight-default`, `tight-none`, and
`tight-baseline` logs; the earlier weaker allocation bound did not distinguish
the baseline and receives no regression-failure credit. The prepared near-viewport
script-image integration passes its three focused cases in both GC modes and
matches all 173 full-uBO checks, but its standalone count establishes no page gain.

Brave's current exported layer reasons identify the ribbon button as a separate
layer promoted for overlap with accelerated scrolling. A private rectangle-MSAA
probe changes only 11 chevron pixels and reduces the full difference from 208 to
200; a private image-MSAA probe reduces it to 198. These blanket policies remain
diagnostics, with no production or CPU credit. General layer-aware rasterization
and the remaining image-corner/gradient-compositing differences remain open.

Conditional scroll-edge resolution (`d318908d`) avoids creating font and query
container context for automatic, absolute and percentage edges. Three focused
cases pass 16,932 assertions per GC mode, preserving relative/calculated values
and retained padding, margin and snap metadata. The original implementation
fails the cache-elision guard. Three native pairs increase the observed mean
from 48,531,873,958 to 49,497,586,169.67 instructions; this receives no page saving
credit. An unrelated programmatic snap control returns the same unexpected
position in both binaries and remains an explicitly retained pre-existing issue.

Structural CSS invalidation-plan union (`8557a132`) merges equal payloads and
unions their match sets without mutating source plans or previous value copies.
Unordered payload comparison retains duplicate multiplicity. Four focused cases
pass 21 assertions in each GC mode, while the original fails all four. Three
native pairs average 48,925,071,717.33 baseline instructions against
47,524,836,952.67 candidate instructions, with two wins out of three. All six
captures retain the 208-pixel difference; the noisy reduction is not a final
15% result. Its observed reduction, net of the scroll-edge regression, exceeds
the broad-check cadence threshold. The unchanged cumulative source passes
another 49-file batch in both GC modes, 98 logical checks and 22 compilations.

Private receipts are `scroll-snap-context-focused/`,
`scroll-snap-context-controlled/assessment.json`, `css-plan-union-focused/commit.json`,
`css-plan-union-controlled/assessment.json`, `css-plan-union-broad/summary.json`,
and `css-plan-union-normal-instructions/pair-1.vox.{json,ubo.json}`. Signed normal
bundles, complete source and binary pins, and all failed invocations are retained.
A transparent-gradient diagnostic alone worsens the full CNN comparison to
2,019 pixels. A separate synthetic ribbon case improves from 80 to 12 when
its exported layer origin is reproduced. These are diagnostic observations,
with no site-coordinate exception or blanket raster policy shipped for credit.

Raster-layer replay (`dfa92b07`) reads retained scroll, sticky and viewport-fixed
ancestry, limits sparse merges using the Chromium area-growth rule, and preserves
atomic effect groups. Gradient dither origins and path-triggered MSAA follow the
resulting layers. SVG background paths participate using their actual resolved
tile and snapped viewport geometry. The new gradient fixture improves from 68
pixels to zero; all 35 existing Brave image fixtures are pixel-exact. Focused
layout tests pass seven cases and 20,599 assertions per GC mode; focused native
classification tests pass six cases and 15,926 assertions per mode. The original
classifier fails the SVG-background tile assertion, while the other five cases
pass. The portable native dither-phase tests also pass.

Private receipts are `raster-layer-commit/receipt.json`,
`raster-layer-final-focused/summary.json`,
`raster-layer-svg-focused-retry/summary.json`, `raster-layer-svg-negative/`,
`raster-layer-public-fixture/assessment.json`,
`raster-layer-svg-normal-controls-retry/recovered-summary.json` and
`raster-layer-svg-normal-instructions/pair-1.vox.{json,ubo.json}`. Initial control
setup failed before launch; subsequent successful captures initially lacked the
pixel-diff executable in the isolated checkout. Exact metrics were recovered
from those unchanged PNGs using the pinned executable, without recapture.
The archived failures receive no pass credit. The side-by-side image on disk
at that checkpoint contained the original Brave viewport and the 112-pixel Vox result, with every
viewport byte preserved. Both final gates and the seven-pair cohort remain open.


Bitmap raster mode replay (`0f3938ae`) applies the owning layer's path-triggered
MSAA mode to image rows, including overlapping tile borders. Mixed rows draw
both passes against the same immutable backdrop; fractional translated MSAA
batches retain individual draws. Portable row/failure tests and the raster-cache
checks pass. The native image comparison covers 288 configurations, with 44
batched paths, and all 36 Brave fixtures remain pixel-exact. The frozen CNN
viewport improves from 112 to 95 differing pixels, maximum channel error 12.
Content, fonts and all 173 full-uBO checks pass with zero disagreement. A fresh
normal build records 48,951,064,933 instructions; this single observation does
not establish a CPU improvement or meet the 36,171,408,491.25 ceiling.

Private evidence is `image-layer-msaa-final-focused/results.json`,
`image-layer-msaa-final-controls/results.json`,
`image-layer-msaa-final-normal/conformance-summary.json`,
`image-layer-msaa-final-normal-instructions/pair-1.vox.{json,ubo.json}` and
`image-layer-msaa-commit/receipt.json`. The updated
`Build/cnn-parity/cnn-brave-vox-progress.png` preserves the exact raw Brave and
95-pixel Vox viewports. The earlier composite remains archived separately.

The equal opaque border ordering fix (`836f8222`) passes five focused cases per
GC mode but leaves the private four-pixel chevron difference unchanged. SVG
raster preparation culling (`e8ac8892`) preserves the full visible tile fringe;
seven focused cases pass per GC mode, while its normal CNN capture remains at
112 pixels and establishes no CPU saving. Native view ownership (`0cf6956f`)
passes the replacement-view regression in both modes; the extracted old getter
fails that regression. This is independent of a diagnostic viewport mismatch:
a changed measurement driver requested compact chrome from an older bundle.
The pinned matching driver restores the required 768-pixel document viewport.
The failed diagnostic captures retain no benchmark credit. Both final gates
and the seven-pair cohort remain open.
