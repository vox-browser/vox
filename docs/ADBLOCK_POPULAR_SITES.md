# Popular-site adblock verification

The matrix exercises guest pages on 13 representative news, video, social,
shopping, reference, and developer sites. It compares Vox's native filtering
engine with full Manifest V2 uBlock Origin 1.75.0 in an isolated Brave profile,
using the repository's exact list snapshots and disabling Brave Shields.

Run the matrix with Node.js 22 or newer, Brave, full uBO, and the native checker
described in [ADBLOCK.md](ADBLOCK.md):

```sh
node tools/adblock/popular_sites.mjs
node tools/adblock/popular_sites.mjs --sites cnn,wikipedia,github,yahoo,espn,stackoverflow
node tools/adblock/popular_sites.mjs --sites pikabu
```

Reports, browser navigation evidence, matched logger filters, and a progressive
`summary.json` are written under `Build/comparisons/adblock-popular`. Each site
retains its requested and final URLs, title, HTTP status, document text sample,
request decisions, and cosmetic/procedural/scriptlet comparisons. Redirected
pages use their final URL for cosmetic selection.

The runner continues after an unavailable site, then exits nonzero for any
filtering disagreement, engine error, missing comparison, insufficient traffic,
navigation failure, access check, or consent interstitial. Matching a few
requests to an error page never counts as successful site coverage.
Unexpected redirects outside the requested host's domain also fail coverage.
`--reports-only` assesses existing reports without making fresh page visits.

To add comparisons of actual Vox traffic, pass a JSON map of catalog IDs to
audit JSONL files recorded with `VOX_ADBLOCK_LOG`:

```sh
node tools/adblock/popular_sites.mjs --sites cnn --vox-logs Build/vox-audits.json
```

For example, `Build/vox-audits.json` can contain
`{"cnn":"Build/comparisons/adblock-popular/cnn-vox.requests.jsonl"}`.
Recorded comparisons verify request filtering; native page availability must
also be checked through a capture or interactive visit.

## Observed coverage

Pikabu was added with RU AdList enabled. Its captured site traffic has seven
blocked resources out of 62, with identical Vox/full-uBO decisions; the native
shared fixture hides all five ad candidates and preserves both content controls.
See [Pikabu verification](ADBLOCK.md#pikabu-verification) for the request/header
corpus, scriptlet checks and live native capture. The earlier 12-site results
below retain their original list snapshots and observed counts.

These are public guest-page observations from October 15, 2026. Counts vary
with live content, timing, location, consent, and connectivity. They do not cover
logged-in flows, purchases, video playback, or every browser API.

| Site | Live Brave/full-uBO comparison | Native Vox observation |
| --- | --- | --- |
| CNN | Matched; 23 blocked out of 123 requests | Article grid rendered; some images missing; all 118 native request decisions matched |
| Wikipedia | Matched; 1 blocked out of 29 | Readable Main Page; image/layout gaps; all 31 native decisions matched |
| GitHub | Matched; 2 blocked out of 170 | Homepage hero and sign-up controls rendered; all 53 native decisions matched |
| Yahoo | Matched on follow-up; 75 blocked out of 248 | Homepage content rendered; media/feed partly incomplete; all 185 native decisions matched |
| ESPN | Matched; 17 blocked out of 173 | Homepage and lead photograph rendered; score strip partly incomplete; all 46 native decisions matched |
| Stack Overflow | Matched; 3 blocked out of 79 | Native transport received HTTP 403; native page coverage unavailable |
| BBC News | DNS failure in the isolated Brave session | Native connection failure; page coverage unavailable |
| Reuters | HTTP 401 | Native HTTP 401; page coverage unavailable |
| The New York Times | HTTP 403 | Native HTTP 403; page coverage unavailable |
| YouTube | DNS failure in the isolated Brave session | Native connection failure; playback coverage unavailable |
| Reddit | Network-security access check | Native splash screen without a feed; page coverage unavailable |
| Amazon | Continue-shopping access check with too few requests | Partial navigation/category shell; all 28 native decisions matched, including one blocked request |

The six accessible live pages in that capture supplied **822 requests, 121
blocked, zero Vox/full-uBO static decision differences**, with equal cosmetic
CSS, procedural filters, and scriptlet selections. The other six sites remain
explicit coverage failures in the aggregate report. Native rendering has image
and SPA gaps; these checks do not establish complete site functionality or
attribute each rendering gap to a particular subsystem.

An initial Yahoo capture had four live-uBO-logger/replay disagreements on video
telemetry pings, while Vox and the static oracle agreed. Its report is retained
as `yahoo-initial-anomaly.json`. Two follow-ups retained individual logger filters and matched all 258 and 248
decisions, respectively, without that anomaly. Its original cause is
unresolved; any recurrence fails the matrix instead of being ignored.

## Offline and native regressions

The checked-in [request corpus](../tools/adblock/fixtures/popular-sites.json)
retains 89 observed requests across the six accessible pages: 41 blocks and 48
allowed content controls. It records the full engine/list hashes and covers
distinct filter rules, resource types, methods, and initiating domains. Refresh
the recorded oracle evidence after changing list snapshots; the V test rejects
a corpus with different engine/list identities.

```sh
v -old-compiler -enable-globals test adblock
v -old-compiler -enable-globals test main_adblock_popular_test.v
node --test tools/adblock/navigation.test.mjs tools/adblock/popular_sites_test.mjs
```

Eight native page tests exercise actual selected scriptlets and the native
user-origin stylesheet adapter on CNN, YouTube, Reddit, Amazon, Yahoo, GitHub,
ESPN, and Wikipedia. They check CNN ad settings, YouTube ad-response fields,
Reddit outbound-link JSON pruning, Amazon ad/cuepoint JSON pruning, selected
privacy constants, domain ad-slot hiding, and preservation of article content.
They also preserve uBO's generic-hide exceptions on YouTube, Reddit, Amazon,
GitHub, and Wikipedia. These deterministic native effects remain testable when
a public site is unreachable, while the live matrix continues to report the
missing page coverage.


## Strict rendering checkpoint, October 30, 2026

The ten-site pixel suite is implemented in `tools/forum_news_pixels.py` with
`Tests/Browser/Brave/forum-news.json`. It uses full MV2 uBO 1.75.0 and the exact
repository filter-list bytes in both engines. Each native capture gets a fresh
private profile, a pinned executable/library identity, and a 3 GiB process-tree
guard. The shared production bundle is reused without an automatic rebuild.

Commits `cbea4277` and `29a4305e` register all ten cases, retain eight sealed
guest-page captures, and record explicit coverage failures for Reddit and
Stack Overflow. `69515a3d` preserves the content-addressed HTTP bodies as binary
assets so line-ending conversion cannot change their hashes.

Only **Hacker News** currently has exact full-viewport evidence: zero differing
RGBA pixels at 1024 by 768, including an exact live-to-frozen Brave comparison
and matching actual Vox/full-uBO request decisions. The other nine acceptance
cases remain open. Captures for CNN, The Verge, and Pikabu show pixel differences;
Lobsters and BBC also differ between the live capture and frozen replay.
The Slashdot native attempt is invalid because another session replaced the
shared bundle during capture. Reddit returns an HTTP 403 network-security
block. Stack Overflow's response-body capture is incomplete. None are skips or
passing comparisons, and no mismatch bounds were introduced.

Fix `05f1d30a` makes native RequestServer subresources honor navigation's
process-local `SSL_CERT_FILE` trust configuration. The focused default-GC TLS
regression passes its trusted-CA, unrelated-CA, and wrong-host checks. The
no-GC attempt stalls on a later unrelated-CA check and remains unresolved.
A production build fails at C compilation while the shared disk is exhausted;
the later diagnostic compiler and its guard receipt also encounter ENOSPC.
The last completed browser remains available but does not validate this fix.

The tooling checks pass four Python cases and twelve Node cases. Raw reports,
screenshots, actual guard outcomes and the consolidated `summary.json` are
retained under `Build/forum-news-parity-20261030/`. Duplicate intermediate
archives and private replay caches were removed after sealing their canonical
bytes in the fixtures; screenshots, raw filter evidence and logs are retained.
This workstream contains one native code fix. Broad regression suites were
not run and the repository's existing broad-test baseline was not reset.

### Resumed checks and Lobsters fixes

Evidence for the resumed work is in
`Build/forum-news-parity-resume-20261030/`. The unchanged RequestServer TLS
test now passes with `-gc none`, including trusted CA, unrelated CA and wrong
hostname checks. The original stalled attempt is retained; its cause was not
established. A current-V production build, signing verification and fresh
headless startup also pass. An attempted build with the stale alternative V
compiler is retained as a failure, not production validation.

`f9126fb6` corrects middle-aligned text's contribution to line baselines and
negative half-subpixel rounding. New and existing inline geometry tests pass
in both GC modes. `5c42f6b1` adds a six-line native regression extracted from
Lobsters; all 480,000 RGBA pixels match its Brave reference. On the sealed
Lobsters page, story-row geometry now matches Brave, reducing the mismatch
from 130,582 pixels to 18,323.

`9bb7020d` retains fractional foreground components through native glyph
blending and includes the actual float color in glyph-cache identities. Its
two transport tests pass in both GC modes, including inherited colors and a
hover change between alpha values with the same byte representation. Native
checks pass seven fractional/byte cache comparisons and the existing 6,240
glyph-cache replay comparisons, 720 raster-composite comparisons, 36 shadow
layer comparisons and 15 clipping cases. The text-paint regression passes in
both GC modes. `6d9a6495` repairs an existing test's inline optional recording
call; its three text-refresh cases pass in both modes without weakening their
assertions. Original failed attempts remain in the evidence directory.

The full Lobsters comparison now differs at **111 pixels**, with zero actual
Vox/full-uBO decision mismatches. It still fails: 44 pixels have larger rounded
tag-border differences, and its original live Brave PNG differs from the frozen
Brave replay at 71 pixels. A six-line translucent-text diagnostic improves from
3,270 differing pixels to six but remains open. No thresholds or excluded
regions were added. One replay attempt failed image readiness; a fresh attempt
with a ten-second settle completed. Failed Brave captures now retain readiness
and missing-image details through `f7c87ca9`; the related nine Node tests pass.

CNN's resumed native capture exceeds the focused 3 GiB process-tree limit and
is killed by its guard; it supplies no pixel result. The other site's previous
coverage failures remain open. This checkpoint contains three native fixes in
this workstream; broad suites were not run and the broad-test baseline remains
unchanged.

### Inline radii and capture-state checkpoint

`1fcc3d76` resolves inline corner radii against the complete border-box piece,
including padding and the whole text run. Its two focused cases pass with
default GC and `-gc none`. `e0f0440a` adds the narrow-tag native screenshot:
its previous 112 differing pixels now match Brave exactly. Both native forum
fixtures pass all 480,000 pixels each on the final production bundle.

The final production receipt is `production-inline-radius.json`; source hashes,
fresh-process identities, signing, startup and native captures are retained in
the resumed evidence directory. An attempted block-style background inset was
incorrect for inline backgrounds and was removed completely. Its patch, tests
and failed 84-pixel captures remain evidence of the rejected experiment, not
passing feature credit. The translucent-text diagnostic still differs at six
pixels on this bundle.

`e1710aa4` adds Stack Overflow's 56 sealed responses. Its successful main
document followed an access check as a POST navigation. The capture now accepts
that completed response only in the verified top frame and records the source
method; replay remains local and never repeats the POST. Brave's live and frozen
viewports match exactly. Nine catalog sites now have captures; Reddit retains
its explicit guest-session HTTP 403 coverage failure.

The capture workflow now waits for the requested document, fonts and page
content, retains failure diagnostics, rejects missing active stylesheets, and
preserves CSSOM rules from empty author style elements and the original doctype.
Seventeen focused Node cases and nine Python archive cases pass. A real
Brave/full-uBO capture-state regression preserves dynamic CSS, raw modern color
syntax and quirks mode with zero differences across 786,432 pixels. Its evidence
is `capture-state-regression/`. An initial IP-address control failed cosmetic
agreement; the named-domain control passes. The IP-specific difference remains
open outside this public-domain matrix.

HTTPS replay now sends a TLS shutdown alert. A strict client reproduced the old
invalid EOF on a large CSS response and passes after the fix. This does not
establish the cause of every intermittent archived-resource reset. The original
failed responses and the complete `final-matrix/` and `clean-tls-matrix/` runs
are retained.

The four-fix checkpoint gave **one full passing site out of ten**:

| Site | Native/reference pixels | Remaining acceptance failure |
| --- | --- | --- |
| Hacker News | 0 | Pass; live-to-frozen also exact |
| Reddit | No captured page | Guest HTTP 403 network-security block |
| Lobsters | 55, maximum channel error 1 | Live-to-frozen Brave also differs at 71 pixels |
| Slashdot | 9,795 | Live-to-frozen differs at 598,814 pixels |
| Stack Overflow | 9,489 | Native pixels differ; live-to-frozen exact |
| BBC News | 76,604 | Live-to-frozen differs at 526,496 pixels; old snapshot lacks dynamic author rules |
| CNN | No native PNG | 3 GiB guard terminates the process |
| The Guardian | No stable reference PNG | Consecutive Brave frames differ |
| The Verge | No native PNG | 3 GiB guard terminates the process |
| Pikabu | 14,267 | Latest styled reference differs from the live capture at 21,603 pixels |

Pikabu's latest row comes from `pikabu-style-readiness/`; earlier full-matrix
references were unstyled and recorded a connection reset, so they are not
rendering acceptance evidence. Fresh BBC and Slashdot captures with the corrected snapshot
logic hit navigation connection failures, so their existing fixtures were not
replaced. All pixel thresholds remain zero. Four native fixes belong to this
workstream at that checkpoint; broad suites were not run and the broad-test baseline is unchanged.

### GPU glyph precision follow-up

`45e7a1e8` keeps fractional foreground colors and glyph coverage in the same GPU
picture before rounding the page pixel. The path uses the existing bounded
glyph cache (at most 4,096 glyphs and 32,768 raster pixels), with the float CPU
fallback retained. The new `forum-fractional-foreground` fixture covers modern
and legacy alpha, fractional RGB, inheritance, opaque controls and an opacity
group. Its previous eight differing pixels now match Brave exactly. All three
focused native fixtures pass at 800×600, scale 1; 14 GPU/CPU glyph cache cases
and the existing clip, composite, shadow, image and glyph replay checks pass.
The unchanged broader translucent-text diagnostic improves from six differing
pixels to two; the first glyph of its opacity group still paints outside the
reference layer edge.

The completed production receipt is `production-glyph-gpu-v2.json` under
`Build/forum-news-parity-resume-20261030/`, with source hashes, executable/library
identities, signing and startup results alongside it. An initial build attempt
found the shared guard busy and did not queue. Earlier injected-library trials
remain separately labelled candidate evidence.

`8e2c340f` raises the archive replay's accept queue to handle browser connection
bursts. A focused test reproduced a connection reset before a request reached
the log with the previous five-entry queue; all 16 connections and response
bodies pass after the fix. Six archive and four forum-runner cases pass. This
does not establish the cause of every remaining resource failure.

The complete `glyph-gpu-production-matrix/` run still passes **one of ten sites**:

| Site | Native/reference pixels | Remaining acceptance failure |
| --- | --- | --- |
| Hacker News | 0 | Pass; live-to-frozen also exact |
| Reddit | No captured page | Guest HTTP 403 network-security block |
| Lobsters | 18, maximum channel error 1 | Live-to-frozen Brave differs at 71 pixels |
| Slashdot | 9,795 | Live-to-frozen differs at 598,814 pixels |
| Stack Overflow | 7,022 | Native pixels differ; live-to-frozen exact |
| BBC News | 76,604 | Live-to-frozen differs at 526,496 pixels |
| CNN | No native PNG | 3 GiB guard terminates the process |
| The Guardian | No stable reference PNG | Consecutive Brave frames differ |
| The Verge | 315,921 | Live-to-frozen differs at 135,187 pixels |
| Pikabu | 39,565 initially; 14,267 on retry | Regular-font loading failed initially; live-to-frozen differs at 21,603 pixels |

Lobsters improves from 55 to 18 against the same reference pixels, and Stack
Overflow from 9,489 to 7,022. A separate fresh Brave trial changed some tag-edge
pixels, so its 115-pixel candidate result is also retained; no reference was
replaced to make a case pass. Stack Overflow still requests automatic
hyphenation, which the CSS/layout implementation does not yet support.

Pikabu's first native run took about 98 seconds and showed bold fallback text;
its sample was in font-error completion and style/layout updates. The fresh
`glyph-gpu-pikabu-retry/` run loaded the regular font and restored the previous
14,267-pixel result. Both runs remain evidence. The Verge completed within the
memory guard this time; this is not attributed to the glyph change because
other shared source and runtime conditions also changed. Thresholds remain
zero. Five native fixes belong to this workstream; broad suites were not run
and the broad-test baseline is unchanged. The ten-site task remains incomplete.

### Inline multisample coverage follow-up

`6ba82afb` pairs a rounded inline background with its uniform border in one
multisampled render pass. It retains the background's complete outer border
box; applying the block-background inset to an inline box remains incorrect.
A native diagnostic reproduced the final rounding discrepancy with both GPU
backends: the red edge was `248,222,225` when drawn separately and Brave's
`248,222,224` when combined. The new `lobsters-inline-msaa-compositing` fixture
previously differed at 16 pixels and now matches every pixel.

The first implementation also paired some block backgrounds. The wider site
run caught a Stack Overflow regression from 7,022 to 8,612 differing pixels.
`21aed633` restricts outer-border-box pairing to inline fragments and adds a
translucent block-border regression. Stack Overflow returns to 7,022, with its
native PNG pixel-identical to the pre-change baseline. The correction belongs
to this same fix and does not advance the fix counter separately.

On the corrected bundle, the archived Lobsters viewport matched the full-uBO
Brave replay at all 786,432 pixels during its focused check. Its catalog case
still failed because the original live Brave
PNG and the replay differ at 71 pixels. No golden or threshold was changed.
All four focused native fixtures are exact at 800×600, scale 1. Three focused
inline cases and eight existing rounded-border cases pass with default GC and
`-gc none`, using separate compile/runtime guards. Signing and startup pass.

Evidence is retained in `Build/forum-news-parity-continue-20261030/`:
`inline-compositing-focused.json`, `inline-only/inline-compositing-focused.json`,
`production-inline-msaa.json`, `production-inline-only.json`, their source and
identity records, and `inline-only-sites/`. The initial wider run is preserved
under `lobsters-inline-msaa/` plus `other-nine-inline-msaa/`; it includes the
Stack Overflow regression, followed by the corrected focused page checks.
The other catalog outcomes remain recorded there: Hacker News passes; Reddit
has no guest fixture; Slashdot, BBC, The Verge and Pikabu have pixel/snapshot
differences; CNN exceeds its 3 GiB guard; The Guardian lacks a stable reference.
The complete acceptance count remains **one of ten**.

A fresh live Lobsters capture through the working proxy retained 33 responses
with full-uBO agreement. Its first replay differed at 44 native pixels and 167
live-to-frozen pixels, so it was not promoted into the catalog. The archive and
failure remain under `lobsters-fresh-capture/`, `fresh-fixtures/` and
`lobsters-fresh-validation/`. A separate fresh Brave diagnostic matched that
draft's native PNG exactly; temporary viewport resizing changed neither its
DOM hash nor its pixels. This is diagnostic evidence, not a deterministic
reference or a passing live-site claim. The capture policy remains unchanged.

A later completed shared bundle was reused for the final checks. All four
focused pixel fixtures pass on it. Its Lobsters and Stack Overflow native PNGs
are pixel-identical to the corrected production run. The fresh Brave reference
for Lobsters changed by 115 pixels, however, producing a 115-pixel comparison
and a 44-pixel live-to-frozen difference. Stack Overflow's reference and its
7,022-pixel mismatch are unchanged. These observations are retained under
`latest-shared-sites/` and the `*-shared-drift.json` reports; the zero Lobsters
result applies to its retained matching oracle frame, not every fresh capture.

Six native fixes belong to this workstream. Broad suites were not run, and the
broad-test baseline is unchanged. Live-page and remaining-site parity are open.

### Automatic hyphenation checkpoint

`b4ab0d65` implements inherited `hyphens:auto`, `manual`, and `none`, including
layout invalidation and generated CSS metadata. On macOS, automatic wrapping
uses the element's inherited language and CoreFoundation dictionary positions.
Inserted hyphens retain zero source code units: the DOM text and subsequent
line offsets remain unchanged. Normal and min-content layout use the same
dictionary boundaries; max-content and nowrap retain whole words. Missing
languages and unsupported dictionaries do not select a fallback language.
The current automatic path handles horizontal left-to-right text on macOS;
other platforms retain ordinary wrapping. This is not complete CSS hyphenation
parity. Brave rejects `-webkit-hyphens`, so Vox continues to ignore that spelling.

The new `stackoverflow-auto-hyphenation` reference covers dictionary wrapping,
repeated word splits, min-content sizing, manual wrapping, and an unknown
language. Two fresh Brave profiles produce identical references, and Vox
matches every pixel at 800×600. All five focused native forum fixtures pass.
Thirty focused CSS/platform/layout cases pass in both default GC and `-gc none`,
with separate compile and 3 GiB runtime guards. Two generator-extension tests,
production signing, and a fresh startup smoke check also pass.

The final production browser reduces the sealed Stack Overflow mismatch from
**7,022 to 3,064 pixels**. Its full-uBO request/header and cosmetic comparisons
pass; the live-to-frozen Brave comparison remains exact. The site still fails
strict pixel acceptance. Hacker News remains exact, including live-to-frozen
and actual native filtering checks. No reference archive or tolerance changed.

Evidence is retained under `Build/forum-news-hyphenation-20261030/`, including
the focused build/run receipts, source hashes, executable/library identities,
two production build receipts, final five-fixture checks, and `final-sites/`.
Initial test-development errors are retained with their actual exit statuses.
The first build predates removal of the unsupported alias; the final build
contains the final source and its source snapshot remains unchanged.

Seven native fixes belong to this workstream. Broad suites were not run, and
the broad-test baseline is unchanged. The complete acceptance count remains
**one of ten**; live-page and remaining-site parity are open.

### Legacy line-clamp truncation checkpoint

`84e3bcaa` retains the glyphs that fit before the ellipsis in legacy
`-webkit-line-clamp`, including partial words. The previous soft-wrap preference
discarded a complete trailing word after automatic hyphenation introduced a
dictionary break. Standard block-ellipsis retains its existing behavior.
The new three-excerpt fixture reproduces 364 differing pixels before the fix
and matches Brave exactly afterward. Two fresh Brave captures are identical.

All six focused native pixel fixtures pass. The new layout case and eight
existing line-clamp cases pass in both GC modes; production signing and a
fresh startup check pass. The full-uBO Stack Overflow comparison improves
from **3,064 to 2,818 differing pixels**, with exact live-to-frozen Brave
pixels and matching actual native filtering decisions. The remaining errors
still fail strict acceptance. Source, identity, build/run receipts and images
are retained in `Build/forum-news-ellipsis-20261030/`.

Eight native fixes belong to this workstream. Broad suites were not run, and
the broad-test baseline is unchanged. Complete acceptance remains **one of ten**.

### Fractional border-color checkpoint

`5df83edf` preserves fractional computed sRGB channels on opaque solid borders
whose visible sides share the same components. Rounded borders pass those
components to native Skia; a single square side uses its equivalent rectangle
instead of quantizing a generic border path. Integer colors, translucent
colors, and sides with different precision retain their existing paths.
This does not cover every multicolored or translucent border path.

The `stackoverflow-fractional-borders` fixture previously differed at 4,500
pixels, all within one channel value. It now matches every Brave pixel. Two
fresh Brave profiles produce identical references. The fixture includes
horizontal rules, circular and elliptical corners, and the established inline
tag geometry. An initial larger-font padded inline diagnostic exposed a
separate geometry discrepancy; that input and its failure remain in the raw
artifacts rather than being counted as a passing comparison.

All seven native pixel fixtures pass. Thirteen focused border cases pass in
both GC modes, and the production build, signing, and fresh startup checks
pass. The full-uBO Stack Overflow comparison improves from **2,818 to 1,051
differing pixels**, with an exact live-to-frozen Brave comparison. A fresh
Hacker News control remains exact. Both sites pass their actual native
request/header and cosmetic checks. The remaining Stack Overflow pixels still
fail acceptance; no threshold or archived reference changed.

Evidence is retained under `Build/forum-news-border-color-20261030/`: initial
and corrected focused-test receipts, source snapshots, build and executable
identities, seven-fixture results, `final-sites/`, `control-hacker-news/`, and
the remaining color-difference analysis. Nine native fixes belong to this
workstream. Broad suites were not run; the next completed native fix reaches
the ten-fix verification boundary. The broad-test baseline is unchanged, and
complete site acceptance remains **one of ten**.

### Single-path opacity and completed broader verification

`285c38e8` routes a single translucent SVG paint through the existing float-alpha
recording path. Previously, only groups of paths used that path; an isolated
fill or stroke rounded its paint opacity into a byte too early. The new
`forum-single-svg-opacity` fixture improves from **4,000 differing pixels to
zero**. Two fresh Brave references are identical. Seven focused grouping cases
pass in both GC modes, covering mask/effect boundaries, clips, root raster
layers, and rejection of unsupported paint combinations. All eight focused
Brave fixtures are now exact. This is the tenth native fix in this workstream.

The required broader batch exposed a separate canonical-font problem:
navigation and preload documents selected Chromium metrics even when
`LADYBIRD_LAYOUT_TEST_FONT` explicitly requested the upstream test font.
`88275919` installs LibWeb's fixture policies before either parser starts in
that mode. Normal browser documents retain Chromium's policies. Five focused
policy cases pass in both GC modes. `9a89f8ad` also lets screenshot callers
explicitly reuse the selected production bundle without starting another build.

Broader verification is complete through `88275919`:

- 461 cases across 27 files pass in each GC mode, including the complete
  painting and Skia packages and selected CSS, layout, and glyph-storage cases.
- The native TLS regression also passes in both GC modes: trusted CA succeeds;
  wrong hostname and unrelated CA remain rejected. This resolves the previously
  pending no-GC verification, bringing the broad unit count to **462 per mode**.
- All **100 LibJS AST fixtures** match without case overrides.
- All **11 default screenshot comparisons** pass: eight are exact and three
  use their existing upstream/platform bounds. The previously failing
  `inline-node`, `ordered-list`, and `text-decorations` comparisons now pass.
- All **eight SVG mutation/image reftests** are exact. The eight Brave regression
  fixtures remain exact on the final shared production build. Signing and
  fresh startup checks pass.

No reference image or tolerance was changed. The latest complete ten-site run
retains these failures rather than treating them as skips:

| Site | Native differing pixels | Remaining acceptance failure |
| --- | ---: | --- |
| Hacker News | 0 | Pass; live-to-frozen Brave is also exact |
| Reddit | — | Guest HTTP 403 fixture remains unavailable |
| Lobsters | 115 | Live-to-frozen Brave differs at 44 pixels |
| Slashdot | 9,795 | Live-to-frozen Brave differs at 598,814 pixels |
| Stack Overflow | 1,051 | Native pixel mismatch; live-to-frozen Brave is exact |
| BBC News | 76,604 | Live-to-frozen Brave differs at 526,496 pixels |
| CNN | — | Native process exceeds its 3 GiB guard |
| The Guardian | — | Consecutive Brave reference captures differ |
| The Verge | 315,921 | Live-to-frozen Brave differs at 135,187 pixels |
| Pikabu | 14,267 | Live-to-frozen Brave differs at 21,603 pixels |

Lobsters' native PNG is unchanged between the shared builds; its Brave frame
changes by 115 pixels. Both Stack Overflow PNGs are unchanged. An earlier
Pikabu attempt had a Roboto face error and 39,565 differing pixels; that failed
font load is retained separately, and the final attempt loads that face.
Complete site acceptance remains **one of ten**.

Raw commands, source/build identities, guard receipts, images and metrics are
under `Build/forum-news-svg-opacity-20261030/` and
`Build/forum-news-layout-font-20261030/`. The final validation controller and
every completed regression stage have recorded actual exit statuses; the
ten-site command correctly exits nonzero. This workstream's new broad-test
baseline is `88275919`; completed native fixes since that baseline: **zero**.

### Composited SVG contents and reusable picture typefaces

`3451ccc0` isolates supported SVG compositor contents together with their own
backgrounds and glyphs before blending them over the parent. The layer plan
retains fixed, sticky, scrolling and hinted compositor ownership. Contiguous
solid-vector layers use the existing isolated destination; unsupported effects,
resources and child-layer gaps retain their previous player. The new
`forum-composited-svg-edges` fixture covers transparent and painted fixed layers,
with ordinary, transformed, will-change and opacity controls. Two independently
captured Brave references agree, and all **nine focused Brave fixtures are exact**.

`30918985` reuses decoded typefaces across GPU picture replays. The producer frames
the same embedded font bytes, and Dawn retains decoded faces by exact packet
content under its renderer mutex. The cache charges both packet and font-stream
storage, caps that charge at 128 MiB and 64 entries, and preserves ordinary
unframed picture fonts. Four actual embedded faces cover system, bold, Helvetica
and Courier styles; ownership, deterministic packets, eviction, oversize and
invalid input tests pass. Mixed-font pictures match through the CPU protocol and
four cold/warm old-versus-new GPU comparisons. The existing 14 glyph-cache and
144 compositor-picture comparisons also pass.

Eighteen focused V cases pass in both GC modes. Stack Overflow now completes
under the unchanged 3 GiB runtime guard, with a sampled aggregate RSS peak of
2,124,365,824 bytes. Its native difference improves from **1,051 to 957 pixels**;
the fresh full-uBO Brave frame remains identical to the archived live frame.
Hacker News remains exact, and completed native comparisons retain matching
request/header and cosmetic evidence. No existing golden or tolerance changed.

The complete ten-site rerun still accepts **one of ten**:

| Site | Native differing pixels | Remaining acceptance failure |
| --- | ---: | --- |
| Hacker News | 0 | Pass |
| Reddit | — | Guest HTTP 403 fixture remains unavailable |
| Lobsters | 115 | Live-to-frozen Brave differs at 44 pixels |
| Slashdot | 9,795 | Live-to-frozen Brave differs at 598,814 pixels |
| Stack Overflow | 957 | Native pixel mismatch; live-to-frozen Brave is exact |
| BBC News | 76,604 | Live-to-frozen Brave differs at 526,496 pixels |
| CNN | — | Native process exceeds its 3 GiB guard |
| The Guardian | — | Consecutive Brave reference captures differ |
| The Verge | 315,921 | Live-to-frozen Brave differs at 135,187 pixels |
| Pikabu | — | Native font-load fallback panics before the final capture |

The first per-path SVG prototype regressed the painted header and was rejected.
Its images and failed receipts remain in the evidence. A full V rebuild later
failed during concurrent CSS enum generation. Accepted checks reuse the completed
v42 executable, whose source snapshots contain the SVG change, with separately
compiled and tested native libraries. Their code/data sections and bundle
signatures verify; the executable UUID matches the original v42 sample. Signing
changes its raw file hash, so checks pin the post-signing identity. This native
refresh does not establish a successful full V rebuild or validate later shared
font-synthesis edits.

Evidence is under `Build/forum-news-svg-color-20261030/`, including the final
`checkpoint.json`, `layer-isolation/focused-final/`, native cache tests and the
completed `typeface-cache/verified/` matrix. Its aggregate site command exits
nonzero as required. Broad-test baseline remains `88275919`; these are **two**
completed native fixes since that baseline.

### Block text-control border-box widths

`49e81496` makes Chromium-mode block and floating text controls subtract their border-box
edges once. The prior block replaced-size path subtracted the inline borders a
second time, leaving Stack Overflow's search input two pixels narrower than its
correctly sized parent. The translated LibWeb path and aspect-ratio transfer
retain their existing behavior.

The focused cases cover percentage and fractional widths, fixed lengths,
`calc()`, min/max constraints, intrinsic widths, padding floors, textareas,
floating controls and inline/flex/grid comparisons. All eleven focused V cases
pass in both GC modes. The native fixture covers
the same box-model boundaries without font rasterization noise. Two independent
Brave references agree, and all ten focused native Brave fixtures are exact.
The completed v43 production bundle contains the fix; its source timing and
hashes, fresh-process captures and executable/native-library identities are
recorded under `Build/forum-news-search-width-20261030/`.

With full uBO evidence intact, Stack Overflow improves from **957 to 871**
differing pixels, and its live-to-frozen Brave comparison remains exact. Hacker
News remains exact. The two-site command correctly exits nonzero for Stack
Overflow's remaining mismatch. Overall acceptance remains **one of ten**; the
other sites' failures in the preceding matrix remain open. No tolerance or
existing golden changed. Broad-test baseline remains `88275919`; this is the
third completed native fix since that baseline.

### Fractional SVG rectangle geometry

`eef7e195` resolves Chromium-mode SVG rectangles in floating user units, sharing
the existing ellipse length resolver. Rectangle positions, sizes and radii keep
their precision through presentation attributes, author CSS, percentages and
`calc()`. The LibWeb path retains its existing layout precision. Four focused V
cases pass in both GC modes, including live CSS overrides and retained path
endpoints.

The new `forum-fractional-svg-rectangles` fixture checks straight rectangles in
inline SVG and an SVG image. Two independent Brave references agree. All
**eleven focused native Brave fixtures** and three canonical SVG reftests are
pixel-exact. The canonical checks cover image-source replacement, use-element
geometry and colliding paint-server IDs. A completed production build contains
the change; captures pin its executable and native-library hashes.

The larger SVG diagnostic improves from 1,703 to 1,055 differing pixels. Its
unscaled tiles improve from 328 to four each, while scaled and rounded cases
remain open. That diagnostic is retained separately from the exact fixture.
Stack Overflow's new native capture differs at **629 pixels**, compared with
871 before this build. All 148 recorded request/header decisions match the
preceding full-uBO-verified stream exactly.

Fresh empty Brave profiles stalled on an unresolved `storage.managed.get()`
before uBO became ready; the same failure occurred without the archive proxy.
The failed and interrupted matrix attempts remain in the evidence. A disposable
profile prepared with an explicitly empty cached managed-settings snapshot
reached full uBO's actual ready state and was closed before copying.
`4e8b52a5` exposes the oracle's existing closed-profile copy option in the
ten-site driver through `--profile-template`. Each copy reloads the repository's
exact lists and clears user filters through the full extension. Five driver
tests and three profile-copy tests pass. Profile preparation and configuration
are recorded alongside the run; this is a controlled unmanaged test profile.

The completed fresh ten-site run still accepts **one of ten**. Stack Overflow's
fresh full-uBO reference confirms the same 629-pixel native difference and an
exact live-to-frozen comparison. The profile template's file hashes remain
unchanged after all copies.

| Site | Native differing pixels | Remaining acceptance failure |
| --- | ---: | --- |
| Hacker News | 0 | Pass |
| Reddit | — | Guest HTTP 403 fixture remains unavailable |
| Lobsters | 115 | Live-to-frozen Brave differs at 44 pixels |
| Slashdot | 9,773 | Live-to-frozen Brave differs at 598,814 pixels |
| Stack Overflow | 629 | Native mismatch; live-to-frozen Brave is exact |
| BBC News | 76,604 | Live-to-frozen Brave differs at 526,496 pixels |
| CNN | 86,250 | Live-to-frozen Brave differs at 86,524 pixels |
| The Guardian | — | Consecutive Brave reference captures differ |
| The Verge | 315,921 | Live-to-frozen Brave differs at 135,187 pixels |
| Pikabu | 13,863 | Live-to-frozen Brave differs at 21,537 pixels |

Slashdot's first guard failed during process-group cleanup after its Brave
command finished. The retained retry completes with the result above. CNN and
Pikabu both complete within the unchanged 3 GiB runtime guard in this run, with
sampled aggregate RSS peaks of 1,488,060,416 and 1,509,081,088 bytes. This does not
identify the cause of the earlier memory-limit failure or font-fallback panic;
those failed runs remain in the evidence. Completed native comparisons retain
matching full-uBO request/header, cosmetic, procedural and scriptlet evidence.
The aggregate site command exits nonzero for the remaining failures. Existing
goldens and the zero-difference acceptance threshold are unchanged.

Evidence is under `Build/forum-news-svg-rect-precision-20261030/`, including
`checkpoint.json`, `focused/`, `regressions.json`, `verified/`, `slashdot-retry/`,
the original and focused diagnostics, and the production receipt. Broad-test
baseline remains `88275919`; this is the fourth completed native fix since that
baseline.

## Empty clips and tile antialiasing, 30 October 2026

`2a7b23e7` excludes fully clipped geometry from Chromium tile-MSAA selection.
Zero-size overflow clips and collapsed straight clip paths now discard their
vector triggers before nested traversal. Packed clip geometry determines whether
a path is empty; its positive reference box does not. Curved clips retain the
existing conservative behavior, and SVG masks keep their separate replay path.

The extracted tag/avatar fixture improves from **115 differing pixels to zero**
against two agreeing Brave references. All **twelve native Brave fixtures** and
three canonical SVG reftests are exact. Sixteen focused tile-selection tests pass
with both default GC and `-gc none`. An initial scalar-only prototype passed its
unit tests but failed the native fixture; that failure remains in the evidence.

The shared production guard was busy, so validation reused the next completed
shared bundle. Its receipt completes within the unchanged 12 GiB budget, and
the owned clip sources match before/after build hashes. That build also reports
concurrent changes to the separate lazy-image files. Every validation stage
retains the same executable, native-library and adblock-snapshot hashes.

The new full-uBO matrix still accepts **one of ten**. Native differences are HN
0, Lobsters 115, Slashdot 9,773, Stack Overflow 629, BBC 76,604, CNN **87,907**,
The Verge 315,921 and Pikabu **39,337**. Reddit remains unavailable with guest
HTTP 403, and The Guardian's consecutive Brave references remain unstable.
Lobsters' live-to-frozen difference remains 44 pixels: the extracted empty-clip
fix does not reduce that sealed page's mismatch. CNN and Pikabu regress versus
the preceding run; their causes are not established. Their live-to-frozen
differences also change, to 88,131 and 21,603 pixels respectively. These results
are retained without changing a golden or acceptance threshold.

All eight completed native comparisons retain matching full-uBO request/header,
cosmetic, procedural and scriptlet evidence. The 326-file closed oracle template
is unchanged. The site command correctly exits nonzero; its validating controller
completes successfully after recording that result. Evidence is under
`Build/forum-news-tile-mode-20261030/`, including `checkpoint.json`,
`path-clips-verified/`, focused checks and the retained prototype failures.
Broad-test baseline remains `88275919`; this is the fifth completed native fix
since that baseline.

## Transparent SVG paint and oracle variation, 30 October 2026

`f5c8978e` excludes a zero-opacity SVG fill from tile-MSAA selection when no
visible stroke remains. A retained stroke width alone does not establish a
stroke paint: solid colors, gradient strokes and pattern strokes are checked
separately. Nonzero fill/stroke opacity retains the conservative trigger.

The extracted transparent SVG-background fixture improves from **71 differing
pixels to zero**, with two agreeing independent Brave references. All **thirteen
focused Brave fixtures**, three canonical SVG reftests and twenty tile-selection
tests in both GC modes pass. The current compiler's default-GC check explicitly
builds its bundled libgc. The latest completed shared production bundle contains
the unchanged owned sources recorded before its build; executable, native-library
and adblock-snapshot identities remain stable throughout native validation.

The full-uBO matrix still accepts **one of ten**. Its native differences are HN
0, Lobsters 0, Slashdot 9,773, Stack Overflow 629, BBC 76,604, CNN **107,059**,
The Verge 315,921 and Pikabu **13,925**. Reddit remains unavailable with guest
HTTP 403, and The Guardian's consecutive Brave captures remain unstable.

Lobsters' zero does **not** establish a native improvement: its Vox PNG is
pixel-identical to the preceding build while the Brave reference changes at
115 pixels. The new native PNG still differs from the preceding Brave reference
at those same 115 pixels. Live-to-frozen Brave now differs at 71 pixels, so the
site stays unaccepted. Separate diagnostic captures also vary with Shields and
extension presence despite reporting the same Metal renderer and Graphite
feature status; their cause remains unresolved. These diagnostics do not replace
the full-uBO acceptance reference.

CNN's mismatch grows again and its live-to-frozen difference reaches 107,289
pixels. Pikabu improves versus the immediately preceding shared bundle, but
remains above the earlier 13,863-pixel result; its live-to-frozen difference is
21,603. Both regressions and improvements are retained without attributing them
to the transparent-paint fix. Stack Overflow remains a stable 629-pixel native
mismatch with an exact live-to-frozen reference.

All eight completed native comparisons retain matching full-uBO request/header,
cosmetic, procedural and scriptlet evidence. The 326-file closed profile template
is unchanged. Evidence is under `Build/forum-news-transparent-svg-20261030/`,
including `checkpoint.json`, `verified/`, focused checks and retained failures.
Additional oracle diagnostics are under `Build/forum-news-tile-mode-20261030/`.
Broad-test baseline remains `88275919`; this is the sixth completed native fix
since that baseline.

## Modern RGB alpha in solid SVG recordings, 30 October 2026

`eefbe1a1` retains modern RGB paint alpha before SVG solid colors become byte
colors. Supported solid recordings use that alpha for fills, simple strokes and
SVG images, and select the float recording for an isolated modern translucent
paint. Legacy syntax keeps its existing byte-alpha conversion. Serialized color
keys still reject metadata after callers replace a paint color.

The extracted fixture improves from **46,544 differing pixels to zero**. It
covers direct fills, inherited `currentColor`, nearly opaque paints, strokes,
legacy controls and embedded SVG images. Two independent Brave references agree.
All **fourteen native Brave fixtures** and three canonical SVG reftests are exact.
Sixteen focused storage/replay cases pass in both GC modes, including collection,
retained old recordings and a live alpha change from .31 to .3101 whose byte
color string remains identical. The final mutation check changes only its test
after the production build; implementation hashes match the build inputs.

The production build completes within the unchanged 12 GiB guard with stable
watched inputs. Native validation retains one executable/library/snapshot
identity and the unchanged 326-file oracle template. All eight completed native
comparisons retain matching full-uBO request/header, cosmetic, procedural and
scriptlet evidence. The matrix still accepts **one of ten**: native differences
are HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow 629, BBC 76,604, CNN 107,059,
The Verge 315,921 and Pikabu 13,925. Reddit remains unavailable with guest HTTP
403, and The Guardian's consecutive Brave captures remain unstable.

Lobsters' Brave reference flips back by 115 pixels while Vox's PNG stays
pixel-identical to the preceding run. Its live-to-frozen difference returns to
44 pixels. Stack Overflow retains its stable 629-pixel difference and exact
live-to-frozen reference. CNN and Pikabu retain the preceding run's mismatches;
neither is credited as an improvement from this SVG-alpha change.

Evidence is under `Build/forum-news-svg-color-alpha-20261030/`, including
`checkpoint.json`, `verified/`, the two-reference baseline, focused checks and
retained failures. Further Stack Overflow isolation is retained under
`Build/forum-news-stackoverflow-remaining-20261030/`. Broad-test baseline remains
`88275919`; this is the seventh completed native fix since that baseline.


## Fractional flex and grid gaps, 30 October 2026

`607bb32f` truncates fixed Chromium gaps to the 1/64px layout unit after
resolving their length. The prior nearest-unit rounding widened Stack
Overflow's shrink-to-fit counter row and shifted its end-aligned number. The
3.9px gap now resolves to 3.890625px, matching Brave's glyph positions.
Percentage, calculated and normal gaps retain their existing resolution; the
LibWeb rendering policy keeps its existing nearest-unit conversion.

The extracted counter fixture improves from **74 differing pixels to zero**,
with two agreeing independent Brave references. Three focused tests pass in
both GC modes, covering absolute, font-relative and root-relative lengths,
flex/grid placement, column gaps, shrink-to-fit rows and the unaffected gap
forms. All **fifteen native Brave fixtures** and three canonical SVG reftests
are exact. The first focused compile failed because the new test used point
fields instead of accessors; that failure is retained alongside the corrected
passing run.

The production build completes within the unchanged 12 GiB guard with stable
watched inputs. Native validation retains one executable/library/snapshot
identity and an unchanged 326-file oracle template. The full-uBO matrix still
accepts **one of ten**: native differences are HN 0, Lobsters 115, Slashdot 9,773,
Stack Overflow **592**, BBC 76,604, CNN 101,466, The Verge 315,921 and Pikabu
13,863. Stack Overflow's live-to-frozen reference remains exact; its 37-pixel
native improvement matches the isolated counter diagnosis. CNN and Pikabu's
other changed results are retained without attribution to this gap fix.
Reddit remains unavailable with guest HTTP 403, and The Guardian's consecutive
Brave references remain unstable. Lobsters' live-to-frozen mismatch remains
44 pixels. All eight completed native comparisons retain matching full-uBO
request/header, cosmetic, procedural and scriptlet evidence.

Evidence is under `Build/forum-news-flex-gap-20261030/`, including
`checkpoint.json`, `verified/`, `baseline/` and focused receipts. Read-only GPU,
font and geometry diagnostics are under
`Build/forum-news-so-native-colors-20261030/`; they do not themselves validate a
fix. Broad-test baseline remains `88275919`; this is the eighth completed
native fix since that baseline.


## Remaining color diagnostics and discarded experiment, 30 October 2026

Read-only tracing confirms that Stack Overflow's fractional text colors reach
the GPU. For the traced opaque glyph patches, GPU readback and the final native
PNG agree exactly; the one-channel difference from Brave is already present
before the capture. Reduced direct, variable, calculated and RGB color cases
still match their own Brave references, so they do not establish the cause of
the full-page difference.

A broader solid-SVG RGB pass-through experiment was **discarded**. Its diagnostic
fixture changes from 13,089 to 13,207 differing pixels, including a scaled-icon
regression, while the existing fifteen fixtures remain exact. Tracing confirms
that the proposed float channels reached the native batch. Those results do not
justify adopting the change. Its patch, fixture, agreeing Brave references and
failed checks remain under `Build/forum-news-svg-rgb-20261030/`; the experiment
adds no source change, test-suite change or completed-fix credit.

The installed bundle is rebuilt from the restored source after the experiment.
The first restoration attempt reports a busy shared production guard and queues
no build. A concurrent shared build detects changed inputs and exits 2; that
result receives no validation credit. The subsequent restoration completes
within the unchanged 12 GiB guard with stable watched inputs. The fifteen native
Brave fixtures, three canonical SVG reftests, signing and startup smoke check
pass on one fresh executable/library/snapshot identity. Evidence is retained in
`restore-production-retry/` and `restore-verified/` under the experiment directory.
Broad-test cadence remains **eight** completed native fixes after `88275919`.

The restoration's full-uBO checks retain HN **0** and Stack Overflow **592**
differing pixels, each with an exact live-to-frozen reference. Both restored
Stack Overflow PNGs are pixel-identical to their matching pre-experiment gap-fix
captures. The 326-file oracle template is unchanged. This focused restoration
check does not replace the preceding full ten-site matrix: strict acceptance
remains **one of ten**.
