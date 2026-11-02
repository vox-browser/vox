# Popular-site adblock verification

The latest BBC, CNN, Guardian and Verge rendering checkpoints are recorded at the end
of this document. Guardian and Verge pass the registered viewport comparison
with cold and complete-response caches. BBC and CNN complete-response cache
captures are pixel-exact; cold BBC and CNN's saved-live/frozen-reference
acceptance remain open. The latest bundle also preserves CNN and Guardian's
unchanged archived viewports exactly; the earlier Guardian timeout is retained
with its original evidence below.

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


## Promoted text and inert sticky scrollports, 30 October 2026

`efeb1cc6` isolates contiguous text-only fixed and sticky compositor layers before
blending them over their parent. Scrolling text already used that path; other
promoted text incorrectly painted directly over the parent's pixels and skipped
premultiplied intermediate rounding. The extracted fixed/sticky sidebar fixture
improves from **312 differing pixels to zero**, with an unchanged opaque control
and two agreeing independent Brave references. Four focused eligibility and
real-document cases pass in both GC modes.

The short-document diagnostic then exposes a **140-pixel** regression: a sticky
scroll frame exists even when its scrollport cannot scroll. `9144d886` limits
sticky promotion to a scrolling nearest container. Inert overflow containers stop
the search instead of borrowing the viewport's range, and fixed ancestors block
outside scrolling. The new inert-sticky fixture retains a separately promoted
fixed control and improves from **140 differing pixels to zero**. The focused
layer suite covers active and inert viewports, nested scrollports, fixed ancestry,
and scroll ranges that disappear and return. A failed layer-count expectation
is retained; its correction checks the absent sticky promotion while preserving
fixed compositing, rather than assuming all fixed descendants merge into one
layer.

The original Stack Overflow text differences survive hiding surrounding page
content. Reduced fixed/sticky sidebars reproduce the same edge colors when their
ancestor can scroll; ordinary opaque controls match. These findings locate a
compositing boundary rather than a screenshot readback problem. They do not
establish full-page parity: the last complete promoted-text matrix retains Stack
Overflow at **592** pixels and accepts **one of ten** sites. A separate transparent
root-scrolling control still differs at **156** pixels. Mixed, noncontiguous
sidebar layers and this root-content case remain outside the text-only slice.

Evidence is retained under `Build/forum-news-promoted-text-20261030/` and
`Build/forum-news-inert-sticky-20261030/`, with reduction probes under
`Build/forum-news-so-dom-reduction-20261030/` and
`Build/forum-news-so-layer-backdrop-20261030/`. The resource-light, inlined-CSS
plan diagnostic is not a substitute for the native full-page comparison. These
are the ninth and tenth native fixes after `88275919`; the broader verification
batch follows this boundary.


Broader verification completes through **`9144d886`**: all **28 selected test
files pass in both GC modes** (56 executed binaries), including complete painting
and Skia packages, selected CSS/layout/glyph-storage cases, and the native TLS
regression. All **100 LibJS AST fixtures** match exactly. All **11 default
screenshot comparisons** pass with their existing bounds. All **eight required
SVG mutation/image reftests** are exact; the additional SVG use-element geometry
case is also exact. Two already-passing SVG cases are reused on the same recorded
bundle identity instead of being recaptured. All **seventeen native Brave
fixtures**, signing and startup smoke checks pass. Watched repository sources and
the compiler remain unchanged throughout the broad unit batch. The new broad-test
baseline is **`9144d886`**, with zero subsequent completed native fixes at this
checkpoint.

The complete site run still accepts **one of ten**. Native differences are HN 0,
Lobsters 115, Slashdot 9,773, Stack Overflow 592, BBC 76,604, CNN 101,466 and The
Verge 315,921. Reddit remains unavailable with guest HTTP 403; The Guardian's
consecutive references remain unstable. Pikabu initially fails an inline-layout
saturation assertion during font-failure handling, then completes on a fresh
same-build replay with 13,925 native differing pixels and 21,603 live-to-frozen
pixels. Both attempts are retained. Seven native comparisons complete in the
full run; the separate Pikabu replay supplies the eighth matching full-uBO
request/header, cosmetic, procedural and scriptlet check. The 326-file closed
oracle template is unchanged after that replay.

Stack Overflow's native and Brave frames are unchanged from the promoted-text
run. CNN's native frame is unchanged while its Brave reference changes at 15,866
pixels; Pikabu's native frame is unchanged while its reference changes at 66
pixels. Those reference changes receive no native improvement or regression
credit. A further diagnostic finds **28** differing pixels for sticky text in an
overflowing `overflow:hidden` container, which can scroll programmatically. That
separate case remains open after the broad baseline; it is not covered by the
inert-scrollport acceptance claim.


## Programmatic sticky scrollports, 30 October 2026

`21f20edc` bases sticky promotion on the nearest scrollport's actual range,
including programmatically scrollable `overflow:hidden` containers. Wheel-input
policy no longer determines that promotion. Padding belongs to the scrollport
and does not count as overflow; inert inner containers and fixed ancestry retain
their existing barriers. The new hidden/auto scrollport fixture improves from
**28 differing pixels to zero**, against two agreeing independent Brave captures.
The focused layer and text suites pass in both GC modes, including padded inert
and overflowing controls. All **eighteen native Brave fixtures**, three canonical
SVG reftests, signing and startup smoke checks pass on one recorded fresh bundle
identity. The production guard completes at 8.17 GiB sampled peak with unchanged
watched inputs.

The full-uBO ten-site matrix still accepts **one of ten**. Native differences are
HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 592, BBC 76,604, CNN 101,466, The
Verge 315,921 and Pikabu 13,863. Reddit remains unavailable with guest HTTP 403;
The Guardian's consecutive references remain unstable. Lobsters' live-to-frozen
difference is 71 pixels, so its frozen match does not establish live acceptance.
Its native frame is unchanged from the preceding run while its Brave reference
changes at 115 pixels; that change receives no native improvement credit. Stack
Overflow's native and reference frames are both unchanged. The closed 326-file
oracle template remains unchanged, and all eight completed native comparisons
retain matching full-uBO behavior evidence.

Evidence is under `Build/forum-news-programmatic-sticky-20261030/`, including
`checkpoint.json`, focused/build/validation receipts and `frame-comparison/`.
The broad baseline remains **`9144d886`**; this is the first completed native fix
after that baseline. A separate 156-pixel ordinary-text overlap mismatch remains
open and has its own two agreeing Brave references.


## Sticky overlap rasters and scrollbar identity, 30 October 2026

`5c41bc95` preserves the raster boundary for ordinary content following an
unclipped composited sticky element. Brave's layer trace gives the ordinary
control an overlap layer in this case; removing the sticky element or moving
the control earlier removes that layer and its color difference. Chromium's
[GeometryMapper source](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/platform/graphics/paint/geometry_mapper.cc)
treats unclipped sticky movement as unbounded during overlap projection. The
source copy under the evidence directory is a diagnostic reference from main,
not a claim to pin the installed Brave source revision.

The model now prevents reordering across that unclipped sticky boundary and
retains compositing for the resulting overlap raster. Scrollbar commands have
a separate property identity so they cannot merge into the final text fragment
and prevent its transparent isolation. Clipped controls retain their bounded
behavior, and reused plans clear the previous overlap state. Existing effect,
resource and discontinuous-layer eligibility gates remain in place.

The new fixture improves from **156 differing pixels to zero**, against two
agreeing independent Brave references. The first candidate leaves **16**
heading pixels different; its trace shows the heading and scrollbar in one
raster. That failed result remains under `verified/`. The completed scrollbar
revision passes all **nineteen native Brave fixtures**, three canonical SVG
reftests, signing and startup smoke checks. Three focused test files pass in
both GC modes, including the SVG compositor consumer of the shared layer flag.
The final production build completes within the unchanged 12 GiB guard with
stable watched inputs and one recorded executable/library/snapshot identity.

The complete full-uBO site run still accepts **one of ten**. Native differences
are HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow **584**, BBC 76,604, CNN
101,466 and The Verge 315,921. Reddit remains unavailable with guest HTTP 403;
The Guardian's consecutive references remain unstable. Stack Overflow's Brave
reference is unchanged and its native frame changes at exactly eight pixels,
matching the improvement from 592 to 584. Its remaining differences are 12 in
the header, **473 in the left sidebar**, 64 in the main content and 35 in the
right sidebar. Lobsters' native frame is unchanged while its reference changes
at 115 pixels; its live-to-frozen difference is 44, so no native regression or
live acceptance is credited to that reference change.

Pikabu's first native load takes about **98 seconds** and differs at **39,718**
pixels. Its text weights visibly differ, and its replay log contains only one
of the three native font requests seen in the baseline. A fresh same-build
full-uBO retry takes about **22 seconds** overall and returns to **13,863**
differing pixels. Both the retry's native and Brave frames are pixel-identical
to the preceding baseline frames. The first outlier and retry remain retained;
the loading variation is unresolved and receives no fix credit. Pikabu's
first live-to-frozen difference is 21,603, and the retry's is 21,537. All eight
completed native comparisons retain matching full-uBO behavior evidence. The
326-file oracle template remains unchanged after the retry.

Evidence is under `Build/forum-news-root-text-20261030/`, especially
`checkpoint.json`, `focused-scrollbar/`, `focused-svg/`, `production-scrollbar/`,
`verified-scrollbar/`, `frame-comparison/`, `pikabu-retry/` and
`region-diagnostic/`. The broad baseline remains **`9144d886`**; this is the
second completed native fix after that baseline. The remaining full-page
sidebar differences and intermittent font-loading behavior remain open.


## Native sidebar trace and scoped SVG opacity, 30 October 2026

A fresh native trace of the `5c41bc95` behavior captures four validated raster
plans. The final plan has **395 commands and 15 layers**, and the diagnostic
screenshot is pixel-identical to the unprofiled native frame. A small program
compiled with the repository's V compiler measures the array, command and layer
field offsets; the debugger checks array element sizes, ownership indices and
the executable UUID before writing snapshots. Six duplicate return-breakpoint
callbacks in that first probe are retained as probe errors and receive no capture
credit. The initial 3 GiB diagnostic guard stops the debugger before any plan is
captured; the separate default 12 GiB diagnostic guard completes at about
5.48 GiB sampled peak. These are debugger diagnostics, not performance trials.

The trace locates the remaining sidebar text in a scrolling raster split around
single-path SVG opacity effects. It also identifies a nested SVG viewport for
the Stack Internal illustration; that image contains a mask. An unrestricted
opacity-group repartitioning candidate passes the twenty-fixture reduction
batch but **regresses the full Stack Overflow comparison from 584 to 662
pixels**. Its new ten-layer plan merges the nested image into the main sidebar
raster, which the native isolation eligibility check then rejects. The candidate,
its trace, screenshot and failed full-page comparison remain retained; that
unrestricted behavior is **not adopted**.

`772b06bf` keeps a balanced, normal-blend, single solid SVG opacity group inside
its parent raster **only when the recording contains no nested viewport**.
Recordings with nested viewports retain the preceding atomic raster policy. The
native eligibility check recognizes the supported three-command opacity scope,
checks its scope identity and ownership, and leaves retained opacity untouched
for replay. Typed recording's paint opacity of 1 and native recording's
cumulative paint opacity are both accepted after matching their group opacity
at native float precision. Complex effects and unsupported payloads retain the
existing replay path.

The new extracted fixture improves from **44 differing pixels to zero**, against
two agreeing independent Brave references. Real-document layer tests cover the
parent scroll raster and the nested-viewport fallback; eligibility tests cover
both retained-opacity forms, mismatched scopes, ownership and unsupported paint.
All three focused test files pass in both GC modes. The final build completes
within the unchanged 12 GiB guard with stable watched inputs. Signing, startup,
all **twenty native Brave fixtures** and three canonical SVG reftests pass on the
recorded bundle identity. The colored SVG control improves from 299 to **261**
differing pixels and remains an unresolved diagnostic, rather than an exact
regression fixture or a claim of complete SVG color parity.

The final full-uBO ten-site run still accepts **one of ten**. Native differences
are HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow **584**, BBC 76,604, CNN
101,467 and The Verge 315,921. All seven completed native frames are identical
to the preceding committed build. CNN's reference changes at four pixels,
accounting for its changed mismatch count without native regression credit.
Reddit remains unavailable with guest HTTP 403, and The Guardian's references
remain unstable. Pikabu again hits the previously observed inline-layout
saturation assertion during font-failure handling after about 92 seconds; a
fresh same-build retry completes with 13,863 native differing pixels and 21,537
live-to-frozen pixels. Both retry frames exactly match their preceding baseline
frames. The first failed attempt remains retained. The completed native checks,
including that retry, retain matching full-uBO evidence, and the 326-file closed
oracle template remains unchanged.

Concurrent sessions subsequently update shared source files and replace the
production bundle. Those edits are excluded from this seven-path feature
commit. A fresh check of the newer completed bundle passes signing, startup,
all twenty native fixtures, three canonical SVG cases and the full-uBO HN/SO
comparisons (0/584). Every check pins its executable/library/snapshot identity;
subsequent shared bundle replacements are outside those recorded results. This
does not claim validation of unbuilt concurrent font, cache or native-color edits.

The original native trace is under `Build/forum-news-so-native-plan-20261030/`.
Feature evidence is under `Build/forum-news-svg-opacity-raster-20261030/`, with
`checkpoint.json`, `focused-resource-guard/`, `production-resource-guard/`,
`verified-resource-guard/`, `latest-bundle/`, `frame-comparison/`,
`pikabu-resource-retry/` and the retained unrestricted-candidate diagnostics.
The broad baseline remains **`9144d886`**, with **three** completed native fixes
after it. Full sidebar resource isolation, the colored SVG diagnostic and
intermittent font-loading failures remain open.


## Captured SVG masks in sidebar rasters, 30 October 2026

`b65a2ab2` lets captured vector SVG viewports share their parent compositor
raster with neighboring SVG opacity groups and text. The validator accepts only
bounded, finite vector paths, rectangular clips and balanced captured vector
masks. Nested HTML, external image resources, filters, unsupported masks and
malformed scopes retain the preceding replay policy. Rectangular skip-ink
exclusions on ordinary fills also remain in that raster after their complete
coordinate list is checked; other command kinds retain their exclusion gate.

The first candidate passes the reduced mask fixture but regresses the complete
Stack Overflow frame from **584 to 662** differing pixels. A fresh native trace
shows that the nested SVG is accepted, while a later underline's skip-ink
rectangles reject the whole parent raster. That failed candidate and its full
matrix remain retained. A separate debugger experiment forces only this sidebar
isolation and produces 258 differing pixels. This is diagnostic evidence; the
subsequent unmodified production browser independently reproduces the same
frame exactly and confirms **584 to 258** against an unchanged Brave reference.
Its native frame changes at 365 pixels. Remaining differences are 12 in the
header, **147 in the left sidebar**, 64 in main content and 35 in the right
sidebar. This does not establish complete Stack Overflow parity.

The permanent masked-SVG/opacity/text fixture includes a black underlined link
with skip-ink exclusions. It improves from **44 differing pixels to zero**
against two agreeing independent Brave references. An earlier colored-underline
variant retains a separate **one-pixel** blue-channel error at the fractional
underline endpoint. Its source, agreeing references and failed native frame are
retained under `baseline-skip-ink/` and `underline-color-open.json`; no pixel
tolerance is added. The real Stack Internal illustration reduction still has
66 differences, and the earlier colored SVG control still has 261. These remain
open diagnostics rather than exact regression fixtures.

All four focused test files pass in both GC modes. The SVG compositor consumer
is rerun in both modes after adding skip-ink eligibility, including malformed,
reversed and nonfinite exclusions. All **21 native Brave fixtures**, three
canonical SVG reftests, signing and startup smoke checks pass. The five catalog
and harness unit tests also pass. The existing completed shared production
bundle supplies the initial candidate checks. One production build is then
required for the new skip-ink eligibility; it completes with unchanged watched
inputs and a 7.97 GiB sampled peak under the unchanged 12 GiB guard. The completed
bundle is copied as a pinned binary artifact so concurrent bundle replacements
cannot mix executable or native-library identities during the matrix.

The final full-uBO run accepts **one of ten**. Native differences are HN 0,
Lobsters 115, Slashdot 9,773, Stack Overflow 258, BBC 76,604, CNN 102,112,
The Verge 315,921 and Pikabu 13,925. Reddit remains unavailable with guest HTTP
403, and The Guardian's consecutive references remain unstable. All eight
completed native cases retain matching full-uBO request/header, cosmetic,
procedural and scriptlet evidence. The closed 326-file oracle template is
unchanged. The first candidate batch's BBC uBO-subprocess guard failure is
retained; the complete final batch passes that native filtering check.

All completed native frames other than Stack Overflow are unchanged from their
preceding baselines. CNN's Brave frame changes at 698 pixels. Pikabu's native
frame is identical to the preceding successful retry while its Brave frame
changes at 66 pixels. Those reference changes receive no native improvement or
regression credit. Lobsters' live-to-frozen difference remains 44, so it still
cannot count as an accepted live match. Concurrent changes to `main.v` and
`main_frame_paint.v` after the checked build are excluded from this feature's
validation claims and commit.

Evidence is under `Build/forum-news-nested-svg-isolation-20261030/`, especially
`checkpoint.json`, `focused/`, `focused-skip-ink/`, `native-eligibility/`,
`force-isolation-diagnostic/`, `production-skip-ink/`, `accepted-skip-ink/`,
`frame-comparison-final/` and `final-comparisons/`. The broad baseline remains
**`9144d886`**, with **four** completed native fixes after it. The remaining
sidebar colors, image fringes, underline behavior and site/reference failures
remain open.


## Fractional solid-underline colors, 30 October 2026

`512e8a05` retains computed RGB precision on Chromium-policy solid underline
commands, using the existing native float-color bridge. It resolves
`text-decoration-color`, including `currentColor`, from the command's layout
node and checks the serialized resolved color before publishing an immutable
payload. Byte-exact colors retain their preceding path, including legacy
comma-separated alpha. Synthetic color overrides and fragments without a live
layout handle retain the existing fallback.

The previously open fractional underline endpoint now improves from **one
differing pixel to zero**, against two agreeing independent Brave references.
The latest completed shared baseline reproduces the original blue-channel
error at `(122,246)`. A separate debugger diagnostic on the candidate suppresses
only the retained underline color. Its frame exactly reproduces that baseline
and restores precisely the one differing pixel. The unmodified candidate is
exact. This diagnostic checks causality despite concurrent shared changes;
it does not substitute for the unmodified production screenshot checks.

Four focused test files pass in both GC modes, covering current and explicit
fractional decoration colors, modern alpha, unchanged byte colors, ancestor
decorations, synthetic overrides and retained snapshots after a hover changes
fractional channels without changing serialized RGB bytes. All **22 native
Brave fixtures**, three canonical SVG reftests, signing, startup and the five
catalog/harness unit tests pass. The initial test compiler error and corrected
non-Chromium test expectation remain in the evidence directories; neither is
counted as an executed passing check.

No additional production build is submitted. The already-running shared
`production-coalesced-turn2` build contains the exact helper and paint-transport
inputs before and after compilation. It completes inside the unchanged 12 GiB
guard at an 8.16 GiB sampled peak. The executable exports the new helper, and
a pinned copy supplies every final native check. The shared build also records
a concurrent change in `layout/chromium_raster_layers.v`; that edit and ongoing
main/font/frame work are excluded from this feature commit and source-validation
claims. Its exact compiled variant is not inferred from source timestamps.

The full-uBO ten-site run still accepts **one of ten**. Native differences are
HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow **258**, BBC 76,604, CNN 64,993,
The Verge 315,921 and Pikabu 13,925. All eight native frames are pixel-identical
to the preceding completed baseline; the extracted color fix receives no
full-page improvement credit. CNN's Brave reference changes at 74,528 pixels,
accounting for its changed mismatch count without native improvement credit.
Reddit remains unavailable with guest HTTP 403, and The Guardian's consecutive
references remain unstable. All eight completed native cases retain matching
full-uBO behavior evidence. The closed 326-file oracle template is unchanged.

Evidence is under `Build/forum-news-underline-color-20261030/`, especially
`checkpoint.json`, `baseline/`, `focused-current/`, `verified-shared/`,
`same-build-color-control/` and `frame-comparison/`. The broad baseline remains
**`9144d886`**, with **five** completed native fixes after it. Stack Overflow's
larger skip-ink clipping error, SVG colors and image fringes remain open.


## Variable-font ink exclusions, 30 October 2026

`e70a718e` measures Chromium-policy variable-font ink intersections with the
same registered Skia face used to paint the glyphs. The preceding portable
TrueType path read default contours without applying the selected variation
coordinates, so bold system text could retain the regular instance's underline
gap. The native bridge receives bounded glyph IDs and float coordinates with
32-bit counts, honors the replay face's variation and synthesis settings, and
rejects invalid geometry or insufficient output capacity. Hidden glyphs are
excluded. Unavailable bridges and non-variable faces retain the portable path.
The change does not replace the general SVG-text outline implementation.

A three-weight system-font reduction improves from **three differing pixels to
zero**, against two agreeing independent Brave references. The new native test
checks distinct regular/bold ink widths, position and scale changes, capacity
canaries and invalid coordinates. Four focused V test files pass in both GC
modes, including packing visible glyphs, malformed native results and fallback
behavior. All **23 native Brave fixtures**, three canonical SVG reftests,
signing, startup and the five catalog/harness tests pass. `1c3fec79` adds the
standalone native test runner; its compile and runtime stages also pass under
separate 12 GiB and 3 GiB guards.

The complete Stack Overflow comparison improves from **258 to 257** differing
pixels. Its Brave reference is unchanged, and the native frame changes at
exactly the previously traced underline pixel `(24,606)`. A fresh native probe
records the affected 23-glyph run using `.SFNS-Bold`, `wght=700`, `opsz=17`,
11px size and the 1.625–1.725 intersection band. The probe validates its native
library UUID, and its screenshot is pixel-identical to the unprofiled candidate.
The earlier origin-offset hypothesis remains ruled out. An attempted breakpoint
on the optimized V outline method yielded no captures and receives no diagnostic
credit; the exported native bridge supplies the validated captures instead.

The already-running shared `production-start-selected` build includes the
exact helper, glyph-run hook and native bridge source hashes before and after
compilation, so no additional production build is submitted. It completes
inside the unchanged 12 GiB guard at a 7.73 GiB sampled peak. Its two changed
source entries are test files; current-source focused checks validate the final
tests separately. A pinned binary copy supplies all final captures. Subsequent
shared startup/font/tree edits and a separate native SVG-gradient edit are
excluded from this feature's commit and validation claims.

The full-uBO ten-site matrix still accepts **one of ten**. Native differences
are HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 257, BBC 76,604, CNN 101,466
and The Verge 315,921. Reddit remains unavailable with guest HTTP 403, and
The Guardian's consecutive references remain unstable. Lobsters' live-to-frozen
difference is 71, so its frozen match still cannot count as live acceptance.
Its native frame is unchanged while its Brave reference changes at 115 pixels.
CNN's native frame is unchanged while its reference changes at 73,834 pixels.
Neither reference change receives native improvement or regression credit.

Pikabu's first native load again hits the previously observed inline-layout
saturation assertion after about 92 seconds during font-loading failure. That
failed attempt remains retained. A fresh same-build full-uBO retry completes
with 13,925 native differences and 21,603 live-to-frozen differences; both frames
are pixel-identical to the preceding successful baseline. The seven initial
native completions plus the retry retain matching full-uBO behavior evidence.
The closed 326-file oracle template remains unchanged after the retry.

Evidence is under `Build/forum-news-variable-ink-20261030/`, especially
`checkpoint.json`, `probe/`, `reduction-baseline/`, `focused/`, `native-unit/`,
`native-runner/`, `verified-shared/`, `native-instance/`, `frame-comparison/`
and `pikabu-retry/`. The broad baseline remains **`9144d886`**, with **six**
completed native fixes after it. The remaining SVG/image differences, font-load
failures and site/reference failures remain open.


## Inserted hyphen shaping, 30 October 2026

`770fd7c7` shapes a Chromium-policy automatic hyphen independently of the source
prefix, then retains both sets of glyphs in the line's paint run. Previously,
shaping the concatenated text applied the SFNS `r`–hyphen kern across the
insertion boundary, shifting the hyphen by 0.6640625px and underestimating its
fit. Explicit source hyphens keep their normal contextual shaping, and inserted
hyphens still consume zero DOM code units. The other rendering policy retains
its existing behavior.

The new system-font fixture improves from **515 differing pixels to zero**
against two agreeing independent Brave references. It includes fractional line
placement, explicit and Arial controls, and a narrow case where the old kern
incorrectly admitted a longer prefix. Three focused V files, containing eleven
test functions, pass in both GC modes. All **24 native Brave fixtures**, three
canonical SVG reftests, signing, startup and five catalog/harness tests pass.
The guarded production build completes at an 8.18 GiB sampled peak under the
unchanged 12 GiB limit. The feature's production source hashes stay unchanged;
five concurrent startup/frame source edits are outside this feature's commit.
Final captures use the pinned executable `44fe25b5…`; the shared bundle has
since advanced independently.

The full Stack Overflow comparison improves from **257 to 251** differing
pixels. Its Brave reference is unchanged, and exactly the six incorrect title
hyphen pixels change in the native frame. Maximum channel error falls from 178
to 59. Its remaining differences, using document boundaries, are header 12,
left sidebar 146, main column 2 and right sidebar 91. The largest remaining
errors occur on the header buttons' rounded edges.

The full-uBO ten-site run still accepts **one of ten**: native differences are
HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 251, BBC 76,604, CNN 65,056,
The Verge 315,921 and Pikabu 13,925. Lobsters' live-to-frozen difference remains
71. Reddit's guest HTTP 403 and The Guardian's unstable consecutive references
remain failures. All eight completed native cases retain matching full-uBO
behavior, and the closed 326-file oracle template stays unchanged.

CNN's reference changes at 73,834 pixels against the preceding run. A separate
full-uBO capture of the production build that preceded this hyphen fix has a
native frame identical to the candidate, including 63 one-level icon changes
already present since the preceding feature's checked build. Both current
native frames differ at 65,056 pixels against the same candidate reference.
Those icon and reference changes receive no credit for this fix. Every other
completed native frame is unchanged apart from Stack Overflow's six pixels.
Pikabu completes on its first attempt in this run; its earlier load failures
remain unresolved and retained in the preceding evidence.

Evidence is under `Build/forum-news-hyphen-instance-20261030/`, especially
`checkpoint.json`, `fixture-baseline/`, `focused/`, `verified/`,
`stack-overflow-comparison/`, `baseline-cnn/` and `frame-comparison/`.
The broad baseline remains **`9144d886`**, with **seven** completed native fixes
after it. Full ten-site pixel parity remains open.

## Collapsed accessibility clips, 31 October 2026

`85f1d6b9` recognizes a basic-shape clip whose exact finite path geometry
collapses along an axis, even when its conservative reference box remains
nonempty. It propagates that empty-clip state through the visual tree and
consults it in both compact phase recorders before flattening a paint input.
Curve controls participate in the proof; arcs and nonfinite geometry stay
conservative. Thin fills and self-intersecting contours are retained.

The new fixed-header fixture improves from **eight differing pixels to zero**
against two independently agreeing Brave captures. Removing only the hidden
accessibility anchor was already an exact control in the preceding bundle.
Six new focused functions and three existing replay functions pass in both GC
modes. The existing replay fixture now supplies a nonempty SVG clip component
for the visible mask it exercises. All **25 native Brave fixtures**, three
canonical SVG reftests, signing and startup pass. The five catalog/harness
tests also pass.

Production completes under the unchanged 12 GiB guard at a sampled peak of
**7.29 GiB**. All required implementation sources remain stable throughout the
build; two test files are corrected during compilation and subsequently pass
their final focused runs. Native captures use the pinned executable
`e7e540b500291da53cedcf151434e0bdc6702e1e5469cf603a450f83c9eae22b`.
The first scalar-only candidate still differed at eight pixels and receives no
acceptance credit. Its logs and the intermediate focused-test failures remain
with the evidence.

Stack Overflow improves from **251 to 246** differing pixels against an
unchanged Brave reference. Its header changes at thirteen pixels: nine become
correct and four previously correct samples differ. Header differences fall
from twelve to seven; the left sidebar's 146, main column's two and right
sidebar's 91 remain unchanged. Maximum channel error remains 59. The separate
bordered-header diagnostic retains four button-edge differences, so the full
header is not accepted as pixel-exact.

The full-uBO ten-site run still accepts **one of ten**. Native differences are
HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 246, BBC 76,604, CNN 101,529,
The Verge 315,921 and Pikabu 13,925. Lobsters retains its 71-pixel live-to-frozen
mismatch. Reddit's guest HTTP 403 and The Guardian's changing consecutive
references remain failures. Every completed native frame outside Stack
Overflow is unchanged. CNN's reference changes at 73,834 pixels, explaining
its changed comparison total; this fix receives no CNN credit. All eight
completed native cases retain matching full-uBO request/header decisions and
validated full-uBO document references. The closed 326-file oracle template
remains unchanged.

Evidence is under `Build/forum-news-rounded-corners-20261030/`, especially
`checkpoint.json`, `combined-focused.json`, `geometry-compiled-c.json`,
`production-geometry.guard.json` and `verified-geometry/`. That final directory
contains the pinned identity, all regression artifacts, reference provenance,
ten-site results and complete frame comparisons. The broad baseline remains
**`9144d886`**, with **eight** completed native fixes after it. Full ten-site
pixel parity remains open.

## SVG ink bounds and complete header coverage, 31 October 2026

`db6965c4` separates a shared SVG batch's painted bounds from its padded raster
viewport. Previously, the border paths' one-pixel safety fringe expanded a
56px compositor layer into a 58px cropped picture. Rounded controls then lost
the coverage they receive on the full 64px raster tile. Debugger captures show
identical control geometry and grid settings in the bordered and borderless
cases, but different final render-target heights. Translating the geometry by
the parent border offset did not change the four errors.

Shared recording now derives conservative bounds from each retained path and
stroke, including its transform and batch clip. Legacy rasterization keeps its
padded viewport. The new 1024×768 fixture improves from **four differing pixels
to zero** against two agreeing Brave references. The native harness accepts
that explicit viewport while preserving its other fixtures' 800×600 size.
AddressSanitizer checks compile and execute the actual bridge implementation,
covering the fringe, transforms, clipping, strokes, non-scaling strokes and
whole-batch rejection. All **26 native Brave fixtures**, three canonical SVG
reftests, signing, startup and five catalog/harness checks pass.

The guarded production build completes at **6.49 GiB** sampled peak RSS under
the unchanged 12 GiB limit. Required implementation hashes remain stable;
one independent CSS font-loader test changes during compilation. Captures use
executable `48f96938d848ad630deeee8d0ba6433d505d1f30121c4c551d3c28c5db93defd`
and native bridge `e220b085a158565e6aa2f706f9c5753674dba3d09f31d0b77fb325561b37466d`.

Stack Overflow improves from **246 to 239** differing pixels against an
unchanged reference. Exactly seven native pixels change, all becoming correct.
The captured header is now pixel-exact; the left sidebar's 146, main column's
two and right sidebar's 91 differences remain. Maximum channel error falls
from 59 to 32, with the largest remaining error on the blog widget's rounded
border at (701,378). Together with `85f1d6b9`, this removes all twelve header
differences from the preceding 251-pixel result.

The full-uBO matrix still accepts **one of ten**. Its completed native cases
report HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 239, BBC 76,604,
CNN 198,011 and The Verge 315,921. Reddit's guest HTTP 403 and The Guardian's
unstable consecutive references remain failures. Lobsters still has its
71-pixel live-to-frozen difference. Every completed native frame outside
Stack Overflow and CNN is unchanged.

CNN's frame changes alongside an independent V/font-loading edit between
builds. A binary-only control retains every executable `__TEXT` section and
replaces just the native bridge with its preceding version. It produces the
same CNN native pixels and reference, with zero differences from the candidate.
The CNN change therefore lies outside this C++ fix. The control's source,
signature and library identities are retained; it supplies no performance
credit.

Pikabu initially exits 1 with `VERIFY(!value.might_be_saturated())` during inline
layout. A fresh candidate retry exits zero and returns to **13,925** differing
pixels, with a native frame identical to both the preceding feature and the
same-executable library control. The control and retry references differ at
66 pixels; their native frames agree. This does not establish a crash fix:
the intermittent layout failure remains open, and the original matrix retains
its failed Pikabu result. The eight completed native workloads across the
matrix and retry retain matching full-uBO request/header decisions and
validated full-uBO document references. The closed 326-file template stays
unchanged through all controls.

Evidence is under `Build/forum-news-svg-ink-bounds-20261031/`, especially
`checkpoint.json`, `diagnosis.json`, `native/`, `verified/`, `library-control/`,
`cnn-isolation.json`, `pikabu-isolation.json` and `pikabu-retry/`. The preceding
origin, grid and picture probes remain in the adjacent `forum-news-border-*`
directories. The broad baseline remains **`9144d886`**, with **nine** completed
native fixes after it. Full ten-site parity remains open.

## Partial sticky recording bounds, 31 October 2026

`adf10924` adds `stackoverflow-sticky-raster-bounds`, placing a rounded blog
widget below empty space in a tall sticky container. It improves from **four
differing pixels to zero** against two agreeing 1024×768, scale 1 Brave
156.1.98.60 references. Brave's compositor trace retains a 300×2561 layer at
(700,80), records local bounds (0,295,300,366), and uses a 320×416 tile starting
at local y=256. Tightening that tile to the widget's ink moves its origin and
changes rounded-edge coverage. Extending only the layer bounds also fails:
that diagnostic introduces seven bottom-corner differences.

The V layer plan now follows
[Chromium's partial-recording tiling rule](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/cc/tiles/picture_layer_tiling.cc#888):
snap the recording's leading edges down in 128-device-pixel steps relative to
the complete container, and retain trailing layer edges less than 128 pixels
away. Apply this after layer merging, preserving its overlap decisions. Nested
compositor and independent scroll surfaces retain their own extents. Focused
layout checks cover resizing, device scales 1 and 2, the exact edge threshold,
overflow, nested surfaces and sticky containers inside composited scrollers.
All four focused files pass in both GC modes. All **27 native Brave fixtures**,
three focused canonical SVG reftests, signing, startup and five harness checks
pass. The broad checkpoint executes **58 runtime binaries** across 29 selected
files in both GC modes, matches all **100 upstream AST cases** exactly, and
passes eleven default screenshots under their existing bounds plus nine exact
SVG reftests, including the three focused cases.

The guarded production build completes at **8.19 GiB** sampled peak RSS under
the unchanged 12 GiB limit. Captures pin executable
`64f70d824d8970f86d9b525e9a0353c7d1ce645bdef9484266bc63d08d82ca38`
and native bridge
`e220b085a158565e6aa2f706f9c5753674dba3d09f31d0b77fb325561b37466d`.
Vox source inputs remain stable during compilation. The canonical V executable
is replaced independently during the build, while the build's private compiler
retains its original verified hash. The broad checks pin a binary copy of the
latest current compiler separately.

The full-uBO matrix still accepts **one of ten**. Its completed native cases
report HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow 239, BBC 76,604,
CNN 101,529, The Verge 315,921 and Pikabu 13,863. Reddit's guest HTTP 403 and
The Guardian's unstable references remain failures. Lobsters' native frame is
unchanged; its reference changes at 115 pixels and still differs from the live
capture at 44 pixels. Pikabu completes without the preceding intermittent
panic, but this supplies no crash-fix credit: its native frame matches the
preceding successful retry, whose reference differs at 66 pixels.

Stack Overflow's reference and native frame both remain unchanged. Its header
is exact; the left sidebar retains 146 differences, the main column two and
the right sidebar 91. A fresh debugger capture reproduces that frame exactly
and shows the blog border using the fallback renderer with shared recording
disabled. The reduced recording fix receives no full-page pixel credit. CNN's
native frame changes alongside independent font-loading and initial-layout
source changes between builds; this fix receives no CNN credit. Every other
completed native frame remains unchanged. All eight completed workloads retain
matching full-uBO request/header decisions and validated full-uBO document
references. The closed 326-file oracle template remains unchanged.

The original broad supervisor exits 1 because its source watcher sees an
independent edit to `page/page_client_runtime_test.v`. Every selected compile
and runtime exits zero; that imported-package test file is outside the
selection and is excluded from production and AST builds. A separate guarded
audit exits zero after verifying all implementation and selected-test hashes,
the completed receipts and the pinned compiler and browser identities. The
shared canonical bundle is replaced after the screenshot stages, during unit
checks which do not execute it; the tested pinned bundle remains unchanged.
Both initial failed audit and successful corrected audit receipts are retained,
and no successful check is rerun. The ten-fix checkpoint is complete, with
**`adf10924`** as the new broad baseline and **zero** later native fixes.

Evidence is under `Build/forum-news-blog-border-20261031/`, especially
`diagnosis.json`, `brave-raster-trace-v2/sidebar-tiles.json`, `focused-v5/`,
`candidate-v2/verified/`, `candidate-v2/actual-compiler.json`, `broad/` and
`full-page-trace/`. The original full-container candidate and its failed native
fixture remain retained. Full ten-site parity remains open.

## Complete tiles for rounded layer fallbacks, 31 October 2026

`7186b286` replays rounded fallback draws in complete compositor tiles instead
of cropped leaf-sized targets. This includes both a background/border pair and
an ordinary rounded fill. Each tile retains its original backdrop, coordinates
and multisampling mode. A clipped staging buffer preserves the conservative
fringe outside the layer, and failed draws leave the caller's pixels unchanged.
The finite content bounds also include snapped paint reaching the next pixel
after a fractional trailing box edge; simply clipping to the raw layer width
lost a column of paint in an intermediate candidate.

The new native regression compiles the actual bridge and compares **72 GPU
draws** with independently assembled complete tiles at scales 1 and 2. It
covers transparent and opaque backdrops, translucent underlays, mixed tile
multisampling, ordinary filled controls and fractional extents. The preceding
native library fails this regression. AddressSanitizer and UndefinedBehaviorSanitizer
checks also pass all existing portable grid cases plus **5,600** clipped-fringe
ownership comparisons, including extreme origins and failed-draw rollback.
All **27 native Brave fixtures**, three focused canonical SVG reftests,
signing and startup pass.

The production update rebuilds only the changed native bridge with the normal
production flags, reusing the latest completed bundle. All file-backed Mach-O
sections of its executable remain identical through signing, the bridge's C
exports remain unchanged, and the Graphite libraries and uBO snapshot retain their
identities. Fresh processes use the final pinned bundle under
`Build/forum-news-compound-layer-20261031/verified-v3/`. The unchanged executable
sections isolate this native change from independent V compiler work.
Captures pin executable
`d915142a1c5c2cfef928f7b34726c2404e4af0d55b7b6dcb987a223a8d332f72`
and bridge
`1e5171e5b686734ea89e2f7083f2b01de23ed0f5d4b017fd47f4b583d9cdcfe7`.

Stack Overflow improves from **239 to 236** differing pixels against an
unchanged Brave reference. Exactly five native pixels change, all becoming
closer to that reference: three left-sidebar pixels become exact, while the
blog border's two large errors fall to one-channel rounding differences. No
previously correct pixel becomes incorrect. The header remains exact; the
left sidebar now has **143**, main column **two**, and right sidebar **91**
differences. Maximum channel error falls from **32 to 20**, with the largest
remaining error on the main-column control at (674,115).

The full-uBO matrix still accepts **one of ten**. Completed native cases report
HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 236, BBC 76,604, CNN 107,122,
The Verge 315,921 and Pikabu 13,925. Every completed native frame outside Stack
Overflow remains identical to the preceding feature's frame. Lobsters, CNN
and Pikabu instead change at 115, 31,766 and 66 reference pixels respectively;
their changed totals receive no renderer credit. Lobsters retains its 71-pixel
live-to-frozen mismatch. Reddit's guest HTTP 403 and The Guardian's unstable
references remain failures. All eight completed workloads retain matching
full-uBO request/header decisions and validated document references, and the
closed 326-file oracle template stays unchanged.

Evidence is under `Build/forum-news-compound-layer-20261031/`, especially
`checkpoint.json`, `native-extent/`, `old-library-extent-control.*`,
`native-build-v3/`, `verified-v3/stackoverflow-comparison.json` and
`verified-v3/frame-comparison.json`. Rejected and intermediate candidates are
retained separately. The broad baseline remains **`adf10924`**, with **one**
completed native fix after it. Full ten-site pixel parity remains open.

## MSAA setup without covered samples, 31 October 2026

`2a7f1337` changes the transparent path used to select a multisampled fallback
render pass. A path spanning the complete tile left its colors unchanged but
altered later rounded-corner coverage. Its replacement occupies less than a
sample. A separate debugger check verifies that the replacement retains **4×
MSAA** in every one of the 96 native regression cases.

The new `forum-disjoint-msaa-raster` fixture reproduces the full-page problem:
an earlier compositor layer disables shared root recording, leaving a rounded
blue control and a neighboring SVG on the fallback path. It improves from
**two differing pixels to zero** against two agreeing 1024×768, scale 1 Brave
156.1.98.60 captures. The preceding production bundle fails the same fixture.
The new native regression compares **96** real Metal draws with independent
Dawn pictures containing a visible disjoint path. It covers 320px and 1024px
tiles, device scales 1 and 2, fills and strokes, fractional positions,
translucent colors, transparent and opaque backdrops, fringes and row padding.
The sanitized driver passes; the preceding library fails. All **28 native
Brave fixtures** pass, combining the retained 27-case run with the new focused
case. The **72** rounded-layer comparisons, all portable raster-grid checks,
three focused canonical SVG reftests, five harness tests, signing and startup
also pass.

The production update rebuilds only the changed Metal backend with its normal
production script and pinned Skia dependency. The tested candidate and the
published bundle have identical executable, library and uBO snapshot bytes.
All file-backed executable sections remain unchanged through signing; the
bridge, Dawn backend, public C exports and uBO snapshot retain their identities.
Fresh captures pin executable
`b7a549827a7e1444f51fa9c05f8a238deffd59af064bf0d6380216d2e5f70dd1`
and Metal backend
`6e2776d893c7711d1bc82d1686916957f0d18a9eee573ed7c0a54722761a42fd`.
The shared production guard completes at **0.40 GiB** sampled peak RSS under
the unchanged 12 GiB limit. A fresh installed-bundle startup check passes.

Stack Overflow improves from **236 to 232** differing pixels against an
unchanged full-uBO reference. Exactly four native pixels change, all becoming
correct, with no new errors. The header and main column are now pixel-exact;
the left sidebar retains **141** and the right sidebar **91** differences.
Maximum channel error falls from **20 to 10**, with the largest remaining
error at (94,674) in the left sidebar.

The ten-site matrix still accepts **one of ten**. Completed native cases
report HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 232, BBC 76,604,
CNN 101,529, The Verge 315,921 and Pikabu 13,925. Every completed native frame
outside Stack Overflow remains unchanged. CNN's reference instead changes at
31,766 pixels; its changed total receives no renderer credit. Lobsters retains
its 71-pixel live-to-frozen mismatch. Reddit's guest HTTP 403 and The Guardian's
unstable consecutive references remain failures. All eight completed workloads
retain matching full-uBO request/header decisions and validated document
references, and the closed 326-file oracle template remains unchanged.

Evidence is under `Build/forum-news-root-raster-20261031/`, especially
`native/`, `compound/`, `reference/`, `production-pass/`, `candidate/`,
`native-build/publication.json`, `stackoverflow-comparison.json` and
`frame-comparison.json`. Rejected hypotheses and diagnostic failures remain
retained separately. The broad baseline remains **`adf10924`**, with **two**
completed native fixes after it. Full ten-site pixel parity remains open.

## SVG clip coverage during publication, 31 October 2026

`4cba0e2f` preserves the resolved coverage of a clipped SVG batch when it is
published to the native destination. The GPU now applies the tracked clips;
Quartz's clip is temporarily reset for that completed raster and restored
after publication. This path requires a readable bitmap with matching canvas
dimensions and CTM, supported clip metadata, and matching native/tracked clip
bounds. Implicit rectangular crops, transformed contexts, unsupported masks,
skewed clips and empty clips retain their preceding path. Opaque root draws
retain their original backdrop inside the GPU picture.

The new `forum-svg-viewport-fringe` fixture reproduces two faint yellow pixels
above a fractional-positioned image, with a curved SVG path and a later mask.
It improves from **two differing pixels to zero** against two agreeing
1024×768, scale 1 Brave 156.1.98.60 references. Expanding the viewport clip in
a debugger first removed those same differences; the implementation instead
preserves the clip inside the GPU raster. The preceding browser and native
library fail the new regressions.

The sanitized native check compares **96** batches with independently clipped
complete Dawn rasters. It covers root and compositor layers, scales 1 and 2,
fractional geometry, rectangular and rounded clips, and transparent, white and
colored backdrops. All **107** clip eligibility checks pass, including a
narrower implicit clip, unsupported state, CTM/dimension mismatches and scope
restoration. All **29 native Brave fixtures** pass, combining the retained
28-case run with the new focused case. Three focused canonical SVG reftests,
five harness cases, signing and startup also pass. The production update
rebuilds only the changed native bridge with the normal production flags;
the shared guard completes at **0.45 GiB** sampled peak RSS under the unchanged
12 GiB limit. Published bytes match the tested candidate, public C exports
remain unchanged, and all file-backed executable sections retain their hashes.
The Metal backend, Dawn backend and uBO snapshot keep their identities.
Fresh captures pin executable
`0d5b6e047ed949250592cc2d92fa66d5dfa7d46af1f942341c4a0a69f6198830`
and native bridge
`d5633caff5984aef9527bc693a7497b7f435a3aaf78360a47088bca4dcea9420`.
A fresh installed-bundle startup check passes.

Stack Overflow improves from **232 to 230** differing pixels against an
unchanged full-uBO reference. Exactly two native pixels change, both becoming
correct. The header and main column remain exact; the left sidebar retains
**139** differences and the right sidebar **91**. Maximum channel error falls
from **10 to 2**. The original complex image still has 63 one-level differences
inside its mask, and the separate reduced inline-SVG diagnostic retains its
two fringe errors on ordinary leaf replay. Those diagnostics remain open.

The ten-site matrix still accepts **one of ten**. Completed native cases
report HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow 230, BBC 76,604,
CNN 101,529, The Verge 315,921 and Pikabu 13,925. Every completed reference
is unchanged from the preceding feature. All native frames outside Stack
Overflow and Slashdot remain unchanged. Slashdot changes two already
incorrect pixels: maximum channel error at (70,44) improves from 14 to 12,
while (78,44) worsens from 3 to 4. Its differing-pixel count stays 9,773, and
this change supplies no Slashdot parity credit. Lobsters retains its 71-pixel
live-to-frozen mismatch. Reddit's guest HTTP 403 and The Guardian's unstable
consecutive references remain failures. All eight completed workloads retain
matching full-uBO request/header decisions and validated document references;
the closed 326-file oracle template remains unchanged.

Evidence is under `Build/forum-news-svg-fringe-20261031/`, especially
`native-rounded/`, `reference/`, `clip-probe/`, `candidate/`,
`native-build/publication.json`, `stackoverflow-comparison.json`,
`slashdot-comparison.json` and `frame-comparison.json`. Intermediate reductions
and both expected predecessor failures remain retained. The broad baseline
remains **`adf10924`**, with **three** completed native fixes after it. Full
ten-site pixel parity remains open.

## Painted prefixes in resumed compositor pictures, 31 October 2026

`57dcba8b` adds the `forum-resumed-scroll-raster` regression with three SVGs
in a scrolling compositor layer. Translucent paths interrupt the parent's picture; resuming
that picture previously erased pixels from earlier children. The fixture
improves from **398 differing pixels to zero** against two agreeing 1024×768,
scale 1 Brave 156.1.98.60 references. The preceding production browser fails
the same permanent regression, with maximum channel error 255.

Non-root pictures now retain a painted destination prefix before their
fallback leaves run, including resumptions inside transparent offscreen
parents. Empty canvases retain the original fractional layer phase; the
explicit backdrop hint retains its preceding behavior. An initial candidate
that snapped even empty canvases failed the existing native local-picture
check. That failure remains retained, and the final candidate passes it.

The sanitized native shared-layer suite passes its **144** local-picture
comparisons and their blocked-content guards, **32** gradient comparisons,
tile/clip/shadow checks, and **24** two-picture backdrop scenarios. The backdrop
cases cover both device scales, transparent/translucent/opaque prefixes,
explicit flushes and layer switches, with the native backdrop hint enabled
and disabled. All **30 native Brave fixtures**, three canonical SVG reftests,
five harness cases, signing and startup pass on the final pinned bundle.

Only the changed native bridge is rebuilt, using the normal production flags
and the shared production guard. The publication completes at **0.45 GiB**
sampled peak RSS under the unchanged 12 GiB limit. Published bytes match the
tested candidate, public C exports remain unchanged, and all file-backed
executable sections retain their hashes. The Metal backend, Dawn backend and
uBO snapshot keep their identities. Fresh captures pin executable
`612b1fdeb5a9e0348325485a1a35e0601449654876ccde4ca520b750e8c88c3b`
and native bridge
`a26490174d1128794532d0db8ef2fa178f08bb2f9242b0db64fc15369b5241b7`.
A fresh installed-bundle startup check passes.

The final full-uBO matrix still accepts **one of ten**. All eight completed
native frames and their Brave references remain pixel-identical to the
preceding feature's frames: HN 0, Lobsters 0, Slashdot 9,773, Stack Overflow
**230**, BBC 76,604, CNN 101,529, The Verge 315,921 and Pikabu 13,925 differing
pixels. Stack Overflow's maximum channel error stays **2**; its remaining
color and mask differences are unchanged. This fix receives no full-site
pixel-improvement credit. Lobsters retains its 71-pixel live-to-frozen mismatch;
Reddit's guest HTTP 403 and The Guardian's unstable references remain failures.
All eight completed workloads retain matching full-uBO request/header,
cosmetic, procedural and scriptlet evidence, and the closed 326-file oracle
template remains unchanged. Full ten-site pixel parity remains open.

Evidence is under `Build/forum-news-svg-alpha-20261031/`, especially
`fixture-comparison.json`, `reference/`, `native-v3/`, `candidate-v3/` and
`native-build/publication.json`. The superseded `candidate-v2` matrix was
cancelled and supplies no acceptance credit; its outer receipt is incomplete.
The final candidate has its own complete guarded validation. The broad
baseline remains **`adf10924`**, with **four** completed native fixes after it.

## SVG mask bitmap backdrops, 31 October 2026

`ba04c31b` blends solid mask paths with the mask bitmap's existing pixels on
the GPU. Previously, rendering each path on transparency and compositing its
quantized image through Quartz changed antialiased black/white boundaries by
one level. The bridge maps page coordinates into the translated bitmap and
requires readable premultiplied RGBA, uniform scale, aligned device pixels and
in-bounds raster dimensions. Active Quartz opacity groups retain their
isolated replay; their depth is tracked independently of the page's effects.

The new `forum-svg-mask-backdrop` fixture checks inline and external luminance
masks plus translucent opacity groups in alpha masks. It improves from **62
differing pixels to zero** against two agreeing 800×600, scale 1 Brave
156.1.98.60 references. Both the preceding browser and native library fail
the new checks. The native regression compares **96** translated mask draws
with independent complete GPU masks, covering fills, strokes, both device
scales, fractional geometry, transparent/colored backdrops and protected row
padding. All **288** mapping checks pass. The existing **96** SVG publication
comparisons and **107** clip checks also pass. These drivers use AddressSanitizer
and UndefinedBehaviorSanitizer. The **56** mask-scope cases pass in optimized
and sanitized modes, including nested opacity depth. All **31 native Brave
fixtures**, three canonical SVG reftests, five harness cases, signing and
startup pass on the final pinned bundle.

The native application caller changes, so a complete production build is
required. It completes with stable inputs at **7.43 GiB** sampled peak RSS under
the unchanged 12 GiB guard and 10 GiB compiler limit. A subsequent comment-only
bridge compilation reproduces identical unsigned bytes. The installed bundle
matches the tested candidate; public bridge exports, the Metal/Dawn backends
and the uBO snapshot retain their identities. Fresh checks pin executable
`1428a2f2ac8f734aae44170ddfb2a25715059c69ea5c2c4fd40cb4bdbbb0ef3b`
and native bridge
`5cc7e85c69584f5004288148105d7908cfbcdafbf7b2ef21e90b702c7c2ebcdb`.
A fresh installed-bundle startup check passes.

Stack Overflow improves from **230 to 170** differing pixels against an
unchanged full-uBO reference. Exactly **60** native pixels change, all becoming
correct; no new pixel becomes incorrect. The header and main column remain
exact, the left sidebar falls from **139 to 79**, and the right sidebar remains
at **91**. Maximum channel error stays **2**, with the existing gray icon
differences unchanged. The illustration reduction improves from **63 to three**
one-level differences. A separate half-opacity mask diagnostic retains **1,600**
one-level differences and is pixel-identical before and after this fix. Its
source and both images remain under `reduced/`; that gap remains open.

The ten-site matrix still accepts **one of ten**. Completed native comparisons
report HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow 170, BBC 76,604,
CNN 101,529, The Verge 315,921 and Pikabu 13,925. All completed native frames
outside Stack Overflow remain unchanged. Lobsters' reference changes at 115
pixels, accounting for its new count without renderer regression credit;
its live-to-frozen mismatch is now 44. Every other completed reference is
unchanged. Reddit's guest HTTP 403 and The Guardian's unstable references
remain failures.

The initial Pikabu capture hits the previously documented inline-iterator
saturation assertion during font-failure handling after about 92 seconds.
That failed run remains retained. A fresh same-build retry completes with
13,925 native differing pixels and 21,603 live-to-frozen pixels; its native
frame and reference both match the preceding feature. The eight completed
workloads, including the retry, retain matching full-uBO request/header,
cosmetic, procedural and scriptlet evidence. The closed 326-file oracle
template remains unchanged through both the matrix and the retry.

Evidence is under `Build/forum-news-mask-backdrop-20261031/`, especially
`production/`, `native-padded/`, `mask-scope-v2/`, `reference/`, `original/`,
`candidate/`, `pikabu-retry/`, `final-matrix.json`, `fixture-comparison.json`
and `frame-comparison.json`. The broad baseline remains **`adf10924`**, with
**five** completed native fixes after it. Full ten-site pixel parity remains
open.

## SVG mask group opacity, 31 October 2026

`77eb247c` retains float opacity while compositing groups inside color SVG
masks. A Quartz transparency layer previously rounded half-opacity black over
white down to 127 before luminance conversion; the final masked black pixel
became 128 instead of Brave's 127. Eligible groups now own isolated, pooled
RGBA bitmaps and blend their completed pixels with the existing float compositor.
Nested paths can read that group's actual bitmap backdrop. The parent clip is
applied once at publication, and its context, transform and clip are restored.
Alpha-only masks, legacy painting, empty clips, unsupported bitmaps and groups
beyond the bounded 64-level bitmap stack retain Quartz scopes.

The new `forum-svg-mask-group-opacity` fixture improves from **1,600 differing
pixels to zero**, using two agreeing 800×600, scale 1 Brave 156.1.98.60 references.
The preceding production browser fails at exactly those 1,600 one-level pixels.
The native mask-scope driver adds **24** exact comparisons with independent
complete GPU float-opacity images, spanning both device scales, nested groups
and six opacity values. All **56** existing scope/pixel cases and both-scale
context-ownership/depth/legacy/empty-clip fallbacks pass in optimized and
AddressSanitizer/UndefinedBehaviorSanitizer modes, with the canvas pool enabled
and disabled. The pool's **2,304** existing exact comparisons also pass in both
modes. The **96** translated-mask comparisons, **288** mapping checks, **96**
SVG publication comparisons and **107** clip guards remain passing. All **32
native Brave fixtures**, three canonical SVG reftests, five harness cases,
signing and startup pass on the pinned production browser.

The required complete production build finishes with stable watched inputs at
**6.89 GiB** sampled peak RSS under the unchanged 12 GiB guard and 10 GiB
compiler limit. Fresh processes pin executable
`233fbd2fac67f2695d49435fb6ea84f91c7fe958bfb83b24ac93a89fe125de86`.
The native bridge remains
`5cc7e85c69584f5004288148105d7908cfbcdafbf7b2ef21e90b702c7c2ebcdb`;
the Metal/Dawn backends and uBO snapshot also keep their identities. The
installed bundle matches the tested candidate and passes a fresh startup check.
An initial regression batch loses its shared temporary volume and records 14
compiler errors. Its complete rerun uses a private checkout-local temporary
directory and passes all 32 cases; both attempts remain retained.

The full-uBO matrix still accepts **one of ten**. All eight completed native
frames and their Brave references are pixel-identical to the preceding feature:
HN 0, Lobsters 115, Slashdot 9,773, Stack Overflow **170**, BBC 76,604,
CNN 101,529, The Verge 315,921 and Pikabu 13,925 differing pixels. Stack
Overflow's maximum error remains **2**. This fix receives no full-site pixel
improvement credit. Pikabu completes on its first attempt in this matrix.
Reddit's guest HTTP 403 and The Guardian's unstable references remain failures.
Lobsters retains its 44-pixel live-to-frozen mismatch. All eight completed
workloads retain matching full-uBO request/header, cosmetic, procedural and
scriptlet evidence; the closed 326-file oracle template stays unchanged.

Evidence is under `Build/forum-news-mask-opacity-20261031/`, especially
`production-resume/`, `native-final/`, `native-no-pool/`, `pool-checks/`,
`svg-guards/`, `reference-final/`, `baseline/fixture.log`, `candidate-resume/`,
`final-matrix.json` and `frame-comparison.json`. The interrupted initial build
and debugger jobs retain their incomplete receipts and receive no validation
credit. The broad baseline remains **`adf10924`**, with **six** completed native
fixes after it. Full ten-site pixel parity remains open.

## Fractional SVG solid paint channels, 31 October 2026

`38e7fa20` retains fractional sRGB fill/stroke channels through both ordinary
SVG path replay and batched recordings. Previously, HSL and fractional RGB
colors reached those paths only as rounded bytes. Retained snapshots keep the
serialized paint key, so live changes that share the same rounded color remain
distinct and a caller's color override cannot reuse stale components. Modern
and legacy alpha keep their existing conversions. The optional float color is
part of the native path-cache key; the previous byte-only bridge entry remains
available. An isolated opaque path keeps its existing geometry route.

The new `forum-svg-fractional-paint` reference checks translucent HSL fills plus
scaled individual fills and strokes. Two agreeing 1024×768, scale 1 Brave
156.1.98.60 captures establish exact RGBA equality. The preceding production
browser differs at **128** one-level pixels; the new browser differs at **zero**.
Focused retained-paint/replay checks pass with both collectors. The optimized
and sanitized native path-cache tests pass, and **24** sanitized leaf/batch
comparisons match independent complete GPU pictures at both device scales.
The retained **96** SVG clip comparisons, **107** eligibility checks, **96**
translated-mask comparisons and **288** mapping guards pass. All **33 browser
fixtures**, three canonical SVG mutation reftests, signing, startup and five
harness cases pass on the pinned candidate.

Initial production validations pin executable
`ce9cb3f87f033215f91e6504da849c92eb9993026d12b01a3368f98f95caaaf1`
and native bridge
`86c937726c80ea6cec0d7d59f5fae2bde8c8424227709a245d3bf2f43686c4c2`.
The Metal backend changes; the Dawn picture backend and uBO snapshot retain
their identities. Both completed builds compile successfully, but their wider
source audits record concurrent changes in other sessions. Every SVG feature
input stays fixed. The initial source-audit failures and later replacement of
the installed bundle remain retained; they supply no whole-tree stable-build
credit. The next slice reuses a completed shared build with a stable full
source audit and includes this RGB implementation.

This RGB slice receives no full-site pixel credit: all eight completed native
frames are unchanged. The final matrix accepts **one of ten**: HN 0, Lobsters 0,
Slashdot 9,773, Stack Overflow **170**, BBC 76,604, CNN 59,463, The Verge 315,921
and Pikabu 13,925 differing pixels. Lobsters' Brave reference changes at 115
pixels, and CNN's at 42,068; these reference changes account for their new
counts. Lobsters still has a 71-pixel live-to-frozen mismatch. Reddit's guest
HTTP 403 and The Guardian's unstable reference remain failures. All eight
completed full-uBO audits match, and the closed 326-file template is unchanged.
The separate exact-position opacity-group reduction remains **60** pixels away
from Brave; changing paint alpha instead of group alpha isolates that next gap.

Evidence: `Build/forum-news-svg-color-20261031/`, especially `focused-v2/`,
`cache/`, `cache-sanitized/`, `native/`, `reference/`, `production-local-lock/`,
`production-final/`, `candidate-final/`, `fixture-comparison.json`,
`frame-comparison.json` and `filter-audit-summary.json`. The existing
`adf10924` broad baseline remains; this is the seventh completed SVG/native
fix in this conformance series after that checkpoint.

## Single-paint SVG opacity, 31 October 2026

`6a8784e2` applies an eligible SVG scope's opacity in the single GPU paint,
retaining its fractional color and coverage until the parent raster resolves.
The previous isolated bitmap quantized those values before applying opacity.
The immutable display list keeps its balanced scopes and ownership; replay
folds only one supported solid fill or stroke in a matching scope. Filters,
multiple paints, mismatched layers, scaled/rotated geometry, narrower opening
clips, rounded/skewed opening clips, clip-outs and recorded clips retain their
existing replay paths. Root and nested SVG replay use the same selection.

The new `forum-svg-single-paint-opacity` fixture uses the exact Tags and
DocumentAlt SVGs at their captured positions. Two agreeing 1024×768, scale 1
Brave 156.1.98.60 references match the corresponding full-page icons. It
improves from **60 differing pixels to zero**. Focused selector and replay
checks pass with Boehm and `-gc none`, including the stronger nonempty opening
clip cases. All **34 native Brave fixtures**, three canonical SVG mutation
reftests, signing and startup pass on the final pinned bundle. The native
libraries are byte-identical to the RGB slice's tested libraries, retaining
its sanitized GPU and cache checks without rerunning unchanged native code.

The initial windowed checks reuse another session's completed production build
`64f4498ae17abfe161d2d41a2c07fec3c79a058e3b63ad59cc313a5f4e8158fb`.
Its recorded input hashes match the initial folding implementation, and its
whole-tree source audit passes. A matching rebuild is then necessary for the
final rounded/skewed opening-clip guards. It completes at **6.78 GiB** sampled
peak RSS under the unchanged 12 GiB guard and 10 GiB compiler limit, with every
watched source unchanged. Final captures pin executable
`7a940e79d2d2105d721e201664d17885863b9010680510d8a3266cbfb3627306`.
The installed bundle matches that candidate and passes a fresh startup check.
This completed stable build carries both SVG fixes from this continuation.

Stack Overflow improves from **170 to 108** differing pixels against an
unchanged full-uBO reference. Of **71** native pixels that change, **62** become
correct and none becomes newly incorrect. The left sidebar falls from **79 to
19**, the right from **91 to 89**, and the header and main column stay exact.
Maximum channel error falls from **2 to 1**. Nine changed pixels retain an
existing mismatch. The remaining rounded borders, translucent icons and
illustration differences remain open.

The full matrix still accepts **one of ten**. It reports HN 0, Lobsters 115,
Slashdot 9,773, Stack Overflow 108, BBC 76,604, CNN 107,122, The Verge 313,982
and Pikabu 13,925 differing pixels. Outside Stack Overflow and The Verge, all
native frames are unchanged from the RGB candidate. The Verge changes at
2,776 native pixels while concurrent font fixes are also present; its lower
count receives no attribution to this SVG change. Lobsters' reference changes
at 115 pixels and CNN's at 73,834; their native frames remain unchanged. Their
live-to-frozen counts are 44 and 107,289. Reddit's HTTP 403 and The Guardian's
unstable references remain failures. Pikabu completes without a retry. All
eight completed full-uBO request/header, cosmetic, procedural and scriptlet
audits match, and the closed 326-file template remains unchanged.

Evidence is under `Build/forum-news-svg-opacity-fold-20261031/`, especially
`focused-v2/`, `focused-v3/`, `reference/`, `production-reuse-initial.json`,
`production-final-guard/`, `candidate-final/`, `fixture-comparison.json`,
`stackoverflow-comparison.json`, `frame-comparison.json` and
`filter-audit-summary.json`. The initial reused-build results remain retained
separately. The `adf10924` broad baseline remains; this is the eighth completed
SVG/native fix in this conformance series after that checkpoint. Full ten-site
pixel parity remains open.


## Shared rounded-background colors, 31 October 2026

`f918ff2d` retains fractional background components when a rounded background
and its border enter a shared raster recording. The serialized-color guard
rejects stale metadata, opacity is applied once, and null/replaced underlays
and failed draws clear pending components. Typed GPU shape descriptors can
also carry those components, and their cache keys distinguish every channel.
Standalone browser leaves retain their existing byte palette.

The new `forum-fractional-rounded-underlay` fixture places the gray HSL rounded
card inside a complete raster tile containing a curved SVG. Two agreeing
1024×768, scale 1 Brave 156.1.98.60 references show **eight differing pixels
before the fix and zero afterward**. All **35 native Brave fixtures**, three
canonical SVG mutation reftests, five harness checks, signing and startup pass.
The final sanitized native driver passes 120 shared/fallback color and reset
cases, 12 direct GPU descriptor comparisons, the existing 96 clipped SVG
comparisons with 107 guards, 96 translated-mask comparisons with 288 guards,
and 24 SVG color comparisons. Optimized and sanitized cache checks pass.
The retained-color V guard executes successfully with the default collector.
Two no-GC attempts have no test-body credit: concurrent module work first fails
V parsing and later fails Objective-C ARC checks before the test can execute.

The initial unrestricted precision change makes a separate four-pixel
standalone reduction exact but regresses Stack Overflow from **108 to 116**
differing pixels. It receives no acceptance credit. Restricting the browser
change to shared recordings restores the complete Stack Overflow frame to its
prior, byte-identical **108** differences. The original standalone reduction
still has four differences; adjacent-SVG and translucent diagnostics remain
open too. Earlier failed native references omitted MSAA or used the wrong
conservative stroke bounds; their results remain retained without pass credit.
The final native references match the raster surface and publication endpoint.

A full production build completes in 263 seconds at **8.87 GiB** sampled peak
RSS under the unchanged 12 GiB guard and 10 GiB compiler limit, with all watched
inputs stable. The final recording-only adjustment rebuilds the native bridge
in 6.6 seconds. It reuses the completed executable code and Metal ABI; the
recorded executable prefix before its embedded signature is unchanged.
Re-signing changes the final executable hash to
`35489bab3b1adbcda4bfc057b91bc336724e1d3f237b5b31509ff92bf3436466`.
The bridge is
`8fb1aeab2ebaba2a1388ac9e2b6dc7ac1d48e70bcfb67293fae88985400af523`,
Metal is
`8dacafe0fd8906e593f99843ff70ce0f12b699a2c5d3ec383ccb3c64a0bfcf12`,
and Dawn and the uBO snapshot retain the preceding checkpoint's identities.
The installed bundle matches the final pinned candidate and passes a fresh
startup check. The native-only update avoids rebuilding unrelated in-progress
module sources. Shared history advances before the feature commit; its four
main replay changes are verified against the compiled drawing function.

The final matrix accepts **one of ten**: HN 0, Lobsters 0, Slashdot 9,773,
Stack Overflow 108, BBC 76,604, CNN 101,529, The Verge 313,982 and Pikabu 13,925
differing pixels. All eight native page images are byte-identical to the prior
checkpoint, so this change earns no whole-site improvement. Lobsters' reference
changes at 115 pixels and CNN's at 31,766, accounting for their changed counts.
Lobsters remains open with 71 live-to-frozen differences; CNN has 101,696.
Reddit's HTTP 403 and The Guardian's unstable references remain coverage
failures. All eight completed full-uBO request/header, cosmetic, procedural and
scriptlet audits match, and the closed 326-file oracle template stays unchanged.

Evidence is under `Build/forum-news-underlay-colors-20261031/`, including
`shared-scenes/`, `reference-shared/`, `fixture-comparison.json`, `native-final/`,
`cache/`, `cache-sanitized/`, `focused/`, `focused-no-gc/`, `production/`,
`native-update/`, `candidate-accepted/`, `install/`, `frame-comparison.json`,
`filter-audit-summary.json` and `checkpoint.json`. The rejected unrestricted
candidate and the original standalone reduction remain in the same directory.
The `adf10924` broad baseline remains; this is the ninth completed SVG/native
fix in this conformance series after that checkpoint. Full ten-site pixel
parity remains open.

## BBC author styles and response-cache state, 1 November 2026

Work moved to BBC News at the user's request to skip Stack Overflow.
The preceding BBC archive had lost the empty style element's inserted author
rules, so its unstyled logo and the historical 76,604/526,496 pixel counts did
not represent the styled guest page. Commit `2657d0a2` refreshes the registered
archive using the existing CSSOM-aware capture implementation. It retains 94
responses, 5,168,947 bytes, their original URLs and content hashes, and the full
uBO capture report. The manifest SHA-256 is
`ded3c976d0e47081743f3caa948576e5c9aa2f144cede9b1cc07674bd399bc8b`.
The preparation used a disposable profile and clicked Sourcepoint's “I do not
agree” button; personal browser profiles and system proxy settings were unused.

Commit `1a2e34bf` aligns the native comparison with full uBO's consent UI
policy by disabling Vox's separate cookie-banner blocker in the capture
process. It preserves the banner shown in Brave and removes 75,941 differing
pixels from that comparison. The browser's ordinary default is unchanged.

The remaining cold native difference is confined to the lead WebP photograph:
78,799 pixels on both the earlier executable
`068c409166506105949b7ba18416367c6fd5cfd1785fa78b38b308577c652356`
and the latest pinned executable below. The final cold trial's live-to-frozen
reference is exact and all its full-uBO audits match; it still fails pixels.
The resource bytes, selected URL, natural dimensions and CSS geometry agree.
Its retained incremental RGB generator differs from Brave's complete-body YUV
decode. Fresh Brave replays can also select a different generator for the two
gallery thumbnails; one observed replay differs from the live image at 18,786
pixels. These decoder-state differences remain visible failures. No URL, image
size, timing heuristic, tolerance or excluded region was added to mask them.

Commits `d4fb032b` and `ecb4d675` add an explicit `--cache-policy complete`
comparison. Each browser first loads the sealed archive in a discarded process.
Brave saves a closed private profile without process locks; Vox retains only
encoded responses and uses a separate final private profile. Both captures
then launch fresh processes. Warmup reports, final audits and `cache-policy.json`
remain separate. Missing navigation, filter disagreement, changed executable
identity, forced shutdown and guard failures still reject the trial. The
default native cache policy remains `cold`.

Two independent full BBC runs are exact with this complete-response policy:
**zero differing RGBA pixels**, and **zero live-to-frozen pixels**, at 1024×768
and scale 1. The native request/header decisions and Brave's cosmetic, procedural
and scriptlet selections agree with full MV2 uBO 1.75.0 and the pinned lists.
The latest reused executable is
`c1d92f0e526723503945bb70de68b7337ad8195a86fa2bee484eed4ccd3511c7`;
the native text bridge is
`45909d7f9f2380c57ac81ddc65f991c99adcca526a88a8fe6f86ef79344efa5f`.
The earlier completed executable also gives zero under the qualified policy.
This work changes the comparison tooling and test archive, with no new renderer
implementation or production build. It establishes cached BBC rendering only;
cold BBC and full ten-site acceptance remain open.

Reproduce the qualified trial with:

```sh
python3 tools/forum_news_pixels.py --sites bbc --cache-policy complete \
  --output Build/bbc-complete-new-trial \
  --profile-template Build/forum-news-svg-rect-precision-20261030/oracle-unmanaged-template \
  --extension Build/forum-news-parity-20261030/extension/uBlock0.chromium \
  --checker Build/forum-news-parity-resume-20261030/adblock-check \
  --diff-tool Build/forum-news-parity-20261030/hn-baseline/pixel_diff
```

Eleven Python conformance tests and sixteen Node capture/profile/reference
tests pass. All BBC archive body hashes and both provenance hashes validate.
Evidence is under `Build/bbc-parity-20261101/`: `both-cache/` and
`both-cache-repeat/` contain the qualified latest-bundle runs, `complete-policy/`
the earlier bundle, `final-cold/` and `consented-matrix/` the cold native
residuals, and `fixture-integrity.json` the
sealed-body validation. `registered-bbc/`, `registered-repeat/` and
`registered-complete/` retain the incidental native hover, cold Brave decoder
variation and remaining-child guard failure; none supplies acceptance credit.

## CNN SVG background eligibility, 1 November 2026

The next site after BBC is CNN. Its registered archive validates all 85 sealed
responses (14,846,886 bytes), provenance and full-uBO evidence. An explicit
complete-response cache trial gives 224 native/replay differences, each no
greater than one color level. The saved live reference also differs from that
replay at 101,696 pixels, so this is a failing full-site comparison. These cache
conditions differ from the earlier cold checkpoints; the smaller count is not
credited as a renderer improvement.

Commit `22cac16b` fixes one reproducible painting case. A solid SVG background
previously prevented its entire compositor picture from sharing its painted
background with neighboring paths. The isolated CNN logo was already exact;
adding the small SVG background exposed the extra intermediate rounding.
The new `cnn-svg-background-header` regression improves from **120 differing
pixels to zero**, against two agreeing Brave 156.1.98.60 references at 1024×768,
scale 1. The fixture is registered in the native pixel suite.

Eligibility inspects the SVG's actual resolved picture and requires supported
solid paths, normal blending and one non-repeating tile without effects or
rounded image clips. Unsupported pictures retain their fallback. Two focused
V tests pass with both default GC and `-gc none`; the 20 existing shared-picture
tests also pass. The registered Python pixel test and eight related visual
fixtures are exact. `compositor-shared-recording` retains its existing 12-pixel
reference mismatch, with identical decoded pixels in control and candidate.
No reference, tolerance or excluded region was changed.

A same-binary diagnostic changes only the background to repeat. Its logo is
identical in Brave, while Vox's existing fallback retains 112 logo differences
(120 over the complete fixture). The non-repeating case remains exact. This
checks that the new eligibility path executes and accounts for the focused
change despite other sessions' independent changes in the shared browser.

The reused production executable is
`f65b14337cb44141f9b1b301632d9bf925746a62e4c84770fbba3c35e2ff179b`,
with native bridge
`19069788d4c21921473e3589a47beaf73272a3dda3618f620cf39510223fd7f7`.
It contains the exact V fix and passes fresh headless startup. The shared build
receipt records an independent native C++ edit during compilation; the V
inputs for this fix stay unchanged, and executable/library identities are
pinned for the captures. An attempted separate build returned a busy guard
immediately and queued nothing; the shared build was reused instead.

The full registered CNN frame remains at **224 differing pixels** and is
pixel-identical to the preceding control. This fix earns no full-site gain.
Fresh capture through the HTTP route fails document readiness. The SOCKS route
loads the live page but its frozen replay changes between consecutive Brave
captures at both five- and fifteen-second settle periods. A private profile
then rejects optional cookies using “Essential Cookies Only”; its subsequent
full-uBO capture matches all 321 request/header observations, but the frozen
reference remains unstable. Those attempts remain failures. The registered
archive was not replaced with unstable content, and CNN parity remains open.

Evidence is under `Build/cnn-parity-20261101/`: `baseline/`, `candidate-site/`,
`reduced/`, `candidate-reduced/`, `eligibility-control/`, `registered-test.log`,
`related-valid/`, `related-control-matched/`, the focused compile/run guard
receipts, `candidate/identity.json`, `candidate/receipt.json`, `fresh/`,
`fresh-socks/`, `settle15/`, and `consented/`. Diagnostic extraction errors,
an invalid injected trace and incomplete browser exits are retained separately
and supply no acceptance credit. The existing broad baseline is unchanged.


## CNN archived viewport reaches zero pixels, 1 November 2026

The unchanged CNN archive now matches Brave/full uBO at **zero differing RGBA
pixels** across the full 1024×768 viewport, scale 1, with complete encoded
response caches and fresh capture processes. The preceding control has 67
differences; the earlier matched-cache baseline has 224. The header, generated
play icon, ticker fade and photo corners all match. The registered full-uBO
comparison reports zero filter disagreements, and seven focused native pixel
cases pass. Each completed renderer fix has its own commit with focused tests.

The full site status remains `live-to-frozen-mismatch`: its unchanged saved
live image differs from the frozen Brave replay by 101,696 pixels. The runner
retains exit 1 for that gate. Cold decoding and unstable live recaptures remain
unqualified. See [CNN rendering evidence](CNN_BRAVE_PARITY.md) and its
[durable receipt](benchmark-results/cnn-brave-pixels-2026-11-01.json) for exact
scope, bundle identities, commands, guard results and retained failed attempts.


## Guardian archived viewport reaches zero pixels, 1 November 2026

The Guardian passes the registered full-uBO comparison at **zero differing RGBA
pixels** over the complete 1024×768 document viewport, scale 1, with both cold
and complete encoded-response caches. The saved live Brave frame also matches
both frozen Brave references exactly. Each capture uses a fresh browser process
and private profile. No pixel reference, tolerance or excluded region was changed
to accept a renderer fix.

The archive was refreshed after declining optional cookies with SourcePoint's
“No, thank you” button in a private Brave profile. Its 88 sealed responses contain
3,529,846 bytes. The fresh live capture checks 207 request/header decisions,
including 16 blocks, with zero native/full-uBO disagreements and matching
cosmetic CSS, procedural filters and scriptlets. This establishes real page
coverage before accepting the frozen reference; the consent UI was not hidden
by an injected stylesheet or script.

The matched native baseline has 250,066 differing pixels. Focused fixes refresh
intrinsic widths after a web font loads, decode supported static sRGB JPEG XL
images with Brave-compatible pixels, validate gradient stops at native float
precision, preserve SVG and positioned paint-client boundaries, resume pictures
across provably disjoint content and masks, and snap eligible hit-test bounds
before mapping through paint properties, while preserving painted ink bounds.
Own and inherited non-translation transforms keep their property-space bounds;
the earlier broader snapping experiment regressed CNN's gradient and was rejected.

Each renderer fix has a separate commit with focused tests. The final fix is
`fac01e59`. The final check covers the paint-client cases in both default and
no-GC modes, related metadata
and layer planning, eleven native pixel regressions, CNN's unchanged archived
viewport, and fresh headless startup. Full acceptance commands, exact executable
and native-library identities, cache conditions, source/build receipts, all
retained intermediate pixel counts and failed attempts are in the
[durable Guardian receipt](benchmark-results/guardian-brave-pixels-2026-11-01.json).
Raw evidence is under `Build/guardian-parity-20261101/`. The required V inputs
remain unchanged across the build; independent native Graphite edits during
compilation are recorded. Acceptance is tied to the pinned executable and
library bytes.

This result covers the frozen guest viewport. The freezer removes author scripts
and preserves the initialized DOM/CSS; the replay serves only sealed resources
at their original HTTPS origins. It does not establish complete live Vox
scripting, video playback, logged-in behavior or every scrolling position.
There is no CPU-instruction or scrolling-performance claim, and the existing
broad-verification baseline is unchanged. The other catalog sites retain their
individual acceptance status.


## Verge archived viewport reaches zero pixels with complete caches, 2 November 2026

The Verge passes the registered Brave/full-uBO comparison at **zero differing
RGBA pixels** across the complete 1024×768 document viewport, scale 1, with
complete encoded-response caches and fresh browser processes. Its saved live
Brave frame also matches the frozen replay exactly. The final same-bundle
control has 17,112 differing pixels when the new SVG replay is disabled.
No pixel tolerance or excluded region was changed.

The archive was refreshed after clicking the real “Dismiss privacy notice”
button in a private windowed Brave profile. Its 164 sealed responses contain
9,123,281 bytes. The live full-uBO capture checks 625 request/header decisions,
including 37 blocks, with zero native/full-uBO disagreements; cosmetic CSS,
procedural filters and scriptlet lists agree. Earlier archives and the failed
memory-bounded live capture remain in the evidence.

Separate renderer commits map spatial filters through their owning transform
(`1f561e8f`), rebuild filter mappings after sampled transform animation
(`6c406097`), and replay eligible SVG vectors inside local filter coordinates
on the complete owning root raster tiles (`755929b0`). The last fix retains
SkScalar rectangle edges and includes roots whose positioned ink is shorter
than the viewport. Unsupported input retains the bitmap fallback. The refreshed
reference is independently committed as `5c3459c2`.

The final SVG geometry/eligibility tests pass in default and no-GC modes.
Eight native pixel regressions pass, including the new Verge case, related
Guardian/CNN cases, compositor continuation and blending. Fresh headless startup
passes, and CNN's unchanged archived viewport remains pixel-exact. A separate
Guardian full-page preservation capture timed out at 120 seconds without a PNG.
A 35-second diagnostic with the new SVG replay disabled also timed out; its
sample shows the main event loop idle. Neither run supplies full-site
preservation credit or identifies the cause of that capture stall.

**Cold-cache acceptance remains open.** The retained parent-bundle cold trial
has 105,761 differing pixels in the lead WebP photograph (maximum channel error
58), while saved-live/frozen Brave equality remains zero. The existing streamed
RGB versus complete-body YUV generator policy is a suspected cause; that
per-image decoder choice has not yet been independently instrumented. This
renderer change does not claim to fix cold image decoding.

The result covers the frozen guest viewport with initialized DOM/CSS and author
scripts removed. Complete live Vox scripting, video, logged-in behavior and all
scroll positions remain unqualified. There is no CPU-instruction or scrolling
performance claim. Exact commands, executable/library hashes, full-uBO list
hashes, build source concurrency, failed experiments and guard exits are in the
[durable Verge receipt](benchmark-results/verge-brave-pixels-2026-11-02.json).
Raw artifacts are under `Build/verge-parity-20261101/`.


## Verge cold and complete caches reach zero pixels, 2 November 2026

Commit `55a065fa` closes the cold-cache lead-photo difference. Two independent
registered cold-cache comparisons and one complete-response-cache comparison
pass at **zero differing RGBA pixels**, over the entire 1024×768 document
viewport at scale 1. Saved-live Brave and each frozen Brave reference also
match exactly. The archive, resource bytes, references, tolerances and full-uBO
settings are unchanged. Every comparison reports zero filtering disagreements.

A separate native diagnostic confirms the earlier cold run painted the
540×360 WebP as premultiplied RGB, whereas the exact cached run used YUV420.
Its source URL and 580×464 destination rectangle agree. The old policy inferred
that an incremental RGB generator existed whenever HTTP delivered a decodable
prefix before completion. That is transport progress: the native adapter
publishes the completed response before creating its first paint image.
[Chromium records whether decoding is incremental when its first paint
generator is created](https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/graphics/deferred_image_decoder.cc#L139).

The fix removes that inference. Eligible completed WebP resources now use the
same native YUV painting path after chunked and buffered delivery. An RGB paint
image already present in the image cache remains retained. Document/canvas
RGBA decoding, alpha and color-managed fallbacks, and HTTP progress reporting
are preserved. This does not add progressive partial-response painting.

Both focused tests pass with the native Skia painter explicitly enabled in
default and no-GC modes. Six existing WebP fixtures are now registered in the
pixel suite, covering YUV, scaling, RGBA mipmaps, alpha and root tiles. All nine
selected pixel captures pass. Fresh headless startup passes, and the same
pinned bundle preserves CNN and Guardian's unchanged archived viewports at
zero pixels. Earlier Guardian timeouts remain in the prior receipt; their
recovery on this later shared-source build is not attributed to this fix.

Exact commands, decoder diagnostics, executable/library hashes, source/build
receipts, the original 105,761-pixel failure and all qualifying checks are in
the [cold-cache Verge receipt](benchmark-results/verge-cold-brave-pixels-2026-11-02.json).
Raw artifacts are under `Build/verge-cold-20261102/`. This establishes the frozen
guest viewport with author scripts removed; live scripting, video, logged-in
behavior and all scroll positions remain unqualified. There is no instruction
count or scrolling-performance claim.


## Pikabu compositor isolation; full-page gate remains open, 2 November 2026

A fresh capture with the pinned completed browser reproduces **79,769**
differing pixels. Brave's layer-tree and paint-record diagnostics put the lead
photograph in a 578×436 layer promoted for overlap; Vox assigns that image to
the root raster. A controlled Brave-only `z-index:auto` override preserves the
image's DOM rectangle and makes its interior match Vox exactly, improving that
rectangle from **68,723 to zero** differing pixels. The unmodified Brave capture
still matches the original frozen reference over the entire viewport. These
mutations are diagnostic evidence and have not changed Vox's author styles or
the reference. Changing native origins, grids, clipping, decoding, mipmaps or
GPU backends alone has not established a renderer fix.

A later private prototype rasterizes the photo at a uniform intermediate
scale before compositing it at its CSS size. This reduces the full-viewport
count to **17,057**, and the measured photo interior to **6,483** pixels with a
maximum error of two. The opposite scale-selection control retains 79,154
full-viewport differences. This narrows the next implementation work to direct
image compositing, its eligibility, raster tiles and final sampling. The
prototype selects this diagnostic image by dimensions and is unsuitable for
production; it was not committed as a renderer fix. The exact remaining
sampling, other page differences and the three saved-live/frozen reference
pixels remain open.

The checks exposed a cleanup race in the memory guard. Commit `0f1e11993`
reaps an identity-verified root already signalled with `SIGKILL` before handling
a process-group permission error. Surviving owned processes still fail the
check, and the memory limit is unchanged. All ten guard tests pass; a later
windowed browser attempt correctly retains its memory-limit failure receipt.
Commands, hashes, layer reasons, controlled mutations and rejected probes are
retained in the [compositor isolation receipt](benchmark-results/pikabu-compositor-isolation-2026-11-02.json).
No new site parity or performance acceptance is claimed.

## Pikabu sizing and SVG patterns improve; full-page gate remains open, 2 November 2026

Four separately committed fixes correct constrained replaced-element heights
(`be3bb70d`), SVG image resource transforms (`f6f48ee53`), pattern viewport
normalization (`7fdd5da4b`), and single-image pattern sampling (`b170f17be`).
Pikabu's SVG spacer now derives its automatic height from the clamped used
width, removing the vertical gap above its photograph. Embedded pattern images
keep their `<use>` and resource transforms. Eligible single-image patterns
retain a paint record instead of passing through a second sampled Quartz tile.
Effects and unsupported inputs retain the existing fallback.

The controlled sizing regression improves from **78,400 to zero** differing
pixels. The regression using Pikabu's real onboarding SVG and its actual
fractional placement improves from **12,819 to zero**, with two agreeing Brave
references. The same banner rectangle is exact in both cold and complete-cache
full-page captures. Outside that rectangle, the matched native before/after
frames are unchanged. Twelve selected native pixel captures pass, including
both new SVG pattern cases, the sizing case, WebP paths and related image
controls. Focused layout and eligibility checks pass in default and no-GC
modes. CNN and Guardian's unchanged archived viewports remain exact, and fresh
headless startup passes.

**Pikabu is not pixel-exact yet.** The registered complete-cache run has
**79,769 differing pixels**, including the photograph, header shadows and some
controls. Its saved-live/frozen Brave reference differs at **three** plus-button
edge pixels, despite matching bounds and computed styles. Neither discrepancy
is waived. The candidate archive is retained under `Build/` and has not
replaced the canonical site fixture. Its live full-uBO capture checks 174
decisions, including one block, with zero disagreements and matching cosmetic,
procedural and scriptlet policies. Native replay checks 52 decisions with zero
disagreements. Cookie preparation uses the real “Понятно” button in a private
profile.

A broader synthetic SVG-image case still differs at **307 pixels** near a
fractional image boundary. It remains in the raw diagnostics; the initial
attribution to explicit SVG dimensions was rejected. Adding a site base and
removing those dimensions preserves both its original Brave PNG and the native
failure. The committed real-asset regression covers Pikabu's observed placement
and does not claim to resolve every fractional SVG-image embedding. A broader
adapter test also fails three empty-clip assertions; its inputs contain no
images, and that entire suite is not reported green. The affected pattern/mask
subset passes in both memory modes.

The final production build records unchanged inputs throughout compilation.
Exact executable/library hashes, commands, guards, all rejected experiments,
reference checks and remaining diagnostics are in the
[Pikabu receipt](benchmark-results/pikabu-brave-pixels-2026-11-02.json).
Raw evidence is under `Build/pikabu-parity-20261102/`. Live browser capture uses
the default 12 GiB guard after a retained 3 GiB failure; frozen/native runtime
checks retain 3 GiB. This validates frozen guest rendering with author scripts
removed. Full live scripting, video, authenticated behavior and all scroll
positions remain unqualified. There is no instruction-count or scrolling claim.

## Direct-image raster scale and conservative clips, 2 November 2026

Commit `cd567c6de` retains eligible running and paused CSS transform/opacity
animation surfaces, including identity samples, and preserves their overlap
barriers. Commit `202e09746` adds a bounded direct-image raster path: a uniform
source scale and overlapping raster tiles followed by compositor image quads.
The final visible quad keeps its fractional bounds. The implementation selects
single-image compositor layers without URL, site or image-dimension exceptions.

The new shared-clip image regression improves from **69,331 differing pixels
to zero**, with two agreeing Brave/full-uBO references. A separate standalone
rounded-wrapper control remains exact before and after the change. Both are
registered in the native pixel suite. Image-local corner radii, mixed pictures
and unsupported geometry retain their existing paths. Rounded ancestor clips
are currently eligible only when their prefix is shared with the preceding
composited layer; general clip upcasting remains pending. Chromium likewise
[rejects picture-local clip operations when recognizing a direct image](https://github.com/chromium/chromium/blob/main/cc/paint/display_item_list.cc#L378).

**The full Pikabu gate remains open at 79,930 pixels**, compared with 79,769
before the animation-layer change. Its visible photo still has **69,331**
differences. An unrestricted private sampler made that entire photo exact and
reduced the full viewport to **10,599** pixels, but regressed the standalone
rounded-wrapper case by 69,331 pixels. That predicate was rejected. The
committed conservative predicate preserves that control and leaves the real
photo on its existing picture path until its parent-picture/compositor clip
mapping can be established. The header shadow and remaining controls, and the
three saved-live/frozen Brave reference pixels, are also unresolved. No site
fixture, existing reference or tolerance was changed to pass the gate.

All **47 compositor checks** and **three eligibility checks** pass in default
and no-GC modes. Native raster geometry checks pass in release and with
ASan/UBSan. All **13 selected native pixel captures** pass, covering the two new
cases and existing SVG, WebP and shadow controls. The pinned final bundle keeps
CNN, Guardian and Verge's unchanged archived viewports exact; fresh headless
startup also passes. Pikabu's recorded native stream matches full uBO on all
52 decisions, with no blocks or disagreements.

The [direct-image receipt](benchmark-results/pikabu-direct-image-raster-2026-11-02.json)
retains executable/library and fixture hashes, commands, guards, agreeing
references, failing controls and remaining work. Raw artifacts are under
`Build/pikabu-direct-image-20261102/`. Required renderer inputs stayed unchanged
during the final build; five unrelated shared JavaScript/BBC-tool files changed,
so evidence is attached to the pinned executable and libraries. These checks
cover frozen guest rendering with author scripts removed and establish no
live-site, instruction-count or scrolling-performance acceptance.
