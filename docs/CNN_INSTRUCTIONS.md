# CNN rendering and instruction comparison

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

The latest signed normal build also suppresses duplicate descendant invalidations
and avoids constructing an absent block-margin record. Its standalone capture
records **50,469,492,588 instructions** and **208 differing pixels**, with maximum
channel error 13; content and fonts pass. Three interleaved native pairs average
48,454,193,091 candidate instructions, still above the target. The earlier
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
