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

The live capture audit matched all 268 request/header checks, including 24
blocked requests, with zero static-filter disagreements. Cosmetic CSS,
procedural filters and selected scriptlets also matched. A separate replay of
Vox's actual frozen-page traffic matched all 179 request/header checks over
124 distinct requests, including four blocked requests. The workload and raw
receipts are private under `Build/cnn-parity/`; the relevant receipts are
`capture-ubo.json` and `frozen-native-ubo.json`. These are observed-stream
results, not a claim of complete uBlock extension parity.

## Current diagnostic progress

The signed SVG-background, mask, selector, text-shadow and offset diagnostic has **2,490 differing pixels**, with a
maximum channel error of 59, against the unchanged Brave reference. Its single
diagnostic records **51,742,412,525 instructions** and receives no performance
credit while the pixels differ. A fresh Brave
diagnostic remains pixel-exact and records 42,262,584,954 instructions, whose
15% threshold is approximately 35.923 billion. These are diagnostic runs, not
the required seven-pair cohort, and no CNN performance success is credited.

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
