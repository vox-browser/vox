# ChatGPT rendering and startup against Brave

The earlier guest homepage and live ChatGPT send/reply workflow were recorded
as pixel-exact against Brave at 1024×768, scale 1. The November 3 follow-up fixes
a fractional media-query breakpoint and the fixed picture's partial-recording
tile origin. The refreshed frozen guest homepage is now pixel-exact at
800×600, 1024×768 and 1280×800 on both the focused source browser and the
completed shared production bundle.
Original frontend/static captures use SOCKS and are replayed; earlier ordinary
conversation checks kept backend, identity and telemetry requests live.
Fresh-session captures and their request counts are recorded separately below.
The current production guest Send/reply check also succeeds and matches Brave
at zero pixels across the complete 1024×768 conversation viewport.

An external cleanup removed `Build/chatgpt-css-error-lifetime-20261102/` during
the follow-up, including the earlier raw receipts, archives and references.
Results linked to that removed directory below are historical reports and
cannot currently be independently rechecked. New evidence is under
`Build/chatgpt-responsive-20261103/`; its principal results, input hashes and
browser identities are also committed in the
[responsive parity receipt](parity/chatgpt-responsive-20261103.json).
The subsequent [fixed-tile receipt](parity/chatgpt-fixed-tiles-20261103.json)
records the exact three-viewport result and its focused browser identity.
The [current live receipt](parity/chatgpt-live-20261103.json) records the new
successful conversation, its production identity and the retained failures.
Both receipts include hashes for committed PNG evidence under `parity/raw/`.

The scale-2 follow-up remains open: the frozen 1024×768 Retina comparison
improves from 47,705 to 31,350 differing pixels after device-aware paint
snapping, then to 15,056 after device-aware font metrics and leading.
Scale-1 parity remains exact at all three sizes. The
[Retina receipt](parity/chatgpt-retina-20261103.json) retains both captures,
identities, checks and rejected diagnostics; the
[font receipt](parity/chatgpt-retina-fonts-20261103.json) retains the next
improvement. These are focused source-browser results, without a new
production or live Retina claim.

The earlier continuation used `Build/chatgpt-css-error-lifetime-20261102/`.
That homepage loaded suggestion cards and their Blob-backed icons, used Brave's
actual heading font instance, and retains the correct raster bounds and opaque
compositor continuation around the composer. These changes remove its final
eight differing pixels. Suggestions are randomized; the homepage comparison
therefore uses identical original page and image bytes.

The response sprite now loads through the public immutable cache adapter for
ordinary default-credential Fetch. Subsequent ordinary live runs obtain real
replies and exact conversation captures. The earlier missing-sprite result,
layout re-entry assertion, debugger-only result and service unusual-activity
response remain in the evidence; they are not silently retried or reclassified.

All eleven screenshot smoke checks and nine exact SVG mutation guards were
reported passing in the stable `production-conformance-final-84/` batch on `92387cec…`. Earlier
failures, identities, references and protocol corrections remain below. These
checks cover rendering and functionality for the recorded guest workflow and
viewport; they supply no performance claim.

## November 3: device-pixel snapping with CSS-coordinate layout

`ae71352ba` snaps HTML backgrounds, uniform borders and text-line origins to
the presenting device grid when inline SVG keeps layout in CSS coordinates.
The ratio is display density divided by layout-coordinate scale, so an
already scaled layout is not scaled twice. Uniform border recording now keeps
fractional layout coordinates instead of losing half-CSS-pixel edges through
an integer rectangle. Display-density changes invalidate retained paint caches;
the focused regression changes density from 1 to 2 and back on one document.

The standalone `device-pixel-paint-grid` fixture uses fractional fills, opaque
and translucent rounded borders, text origins, and inline SVG. It matches the
unchanged Brave reference at zero pixels across the full 1600×1200 capture
(800×600 CSS pixels, scale 2). The full archived ChatGPT page improves by
16,355 pixels, but its smaller text and shadows still differ. A broader
device-layout diagnostic bypassed the SVG eligibility check and produced
1,611,472 differing pixels; that experiment was removed rather than enabled.

The three new tests pass under default GC, `-gc none`, and bounded
`-prealloc -gc none`. Existing uniform-border, text-line-snapping and
device-layout tests also pass. Fresh focused-browser captures retain exact
scale-1 equality at 800×600, 1024×768 and 1280×800. Runtime checks use 3 GiB
memory guards, compiles use the default 12 GiB guard, and executable/native
library/resource identities remain unchanged throughout each accepted capture.
The [Retina receipt](parity/chatgpt-retina-20261103.json) includes the retained
failing tests, rejected font-changing Brave diagnostic and unstable baseline.

`178c506e9` rounds inline font ascent, descent, line gap and half-leading on
the device grid while preserving the selected CSS font instance and its
fractional x-height. Normal line height follows those metrics. Already scaled
layout divides out its coordinate scale, and LibWeb metrics retain their
previous behavior. A 17px system font's raw ascent of 16.435547 becomes 16.5
at density 2 instead of 16; this removes the composer's one-device-pixel
baseline error. The entire sidebar also becomes pixel-exact.

The standalone `device-pixel-font-metrics` fixture matches Brave at zero pixels
across 1600×1200 image pixels. It covers 12px, 14px and 17px system text,
fractional line leading, semibold text and normal line height while inline SVG
keeps CSS-coordinate layout. Five new tests pass in all three allocator modes,
covering metric-cache immutability, legacy ascent adjustments, invalid scales,
zero-size struts, negative leading, display changes and both coordinate spaces.
Existing inline-metric/cache, inline geometry, device-layout and style projection
tests pass. The full page improves from 31,350 to 15,056 differing pixels;
small glyph/underline differences and shadows remain. All three scale-1
viewports still match exactly. The [font receipt](parity/chatgpt-retina-fonts-20261103.json)
retains the unchanged-reference checks, source/browser identities and a rejected
test-driver report-name collision.

## November 3: fractional breakpoints and additional viewports

`cca118e7c` fixes the desktop/mobile switch at an 800 CSS-pixel viewport.
The site's `(width>=800.01px)` query matches in Brave but previously failed in
Vox. Chromium allows one LayoutUnit (1/64 CSS pixel) for inclusive length
comparisons and equality; strict comparisons retain their unrounded operands.
The implementation follows that
[Chromium comparison behavior](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/core/css/media_query_evaluator.cc#292)
under the existing Chromium rendering policy. LibWeb-policy comparisons,
non-length features and negative query values keep their previous behavior.

The new standalone `media-query-length-precision` fixture compares nine colored
blocks against a committed, unchanged Brave reference at 800×600. The existing
production browser differed at 23,040 pixels; the production build containing
the fix differs at zero pixels. Five focused V tests pass with default GC,
`-gc none`, and the bounded `-prealloc -gc none` allocator. Existing media
evaluation and parsed-query retention tests also pass. The focused tests cover
both sides of the precision boundary, reversed and chained comparisons,
calculated/rem lengths, fractional viewport sizes, display density, negative
values, and stylesheet reevaluation after a resize.

The fresh normal Brave session downloaded through
`socks5h://127.0.0.1:1337`. Its frontend initiated two document requests, both
HTTP 200 with 465,942-byte bodies; both hashes remain in the receipt. Its guest
variant has a textarea, a “Where should we begin?” heading, cookie consent and
a “What can you do?” button. The initial capture driver still required the
previous variant's contenteditable editor and three suggestion images, so that
readiness check timed out. Fifty-three response-body retrieval errors from the
reload are retained; no successful live capture or live conversation is claimed
from that attempt.

Brave then executed the archived original frontend without forwarding missing
resources and serialized its resulting DOM. Comparison launches remove scripts
from that clone and use the same original archived styles and resources in both
browsers. Fresh Brave references were captured for each viewport. They do not
replace the earlier variant's references.

| Document viewport | Previous production | Production with breakpoint fix |
| --- | ---: | ---: |
| 800×600 | 479,849 differing pixels | **0** |
| 1024×768 | 14 differing pixels | 14 |
| 1280×800 | 14 differing pixels | 14 |

All three production captures completed with matching titles, document URLs,
viewport and PNG dimensions, empty native error/JavaScript diagnostic arrays,
and stable browser/resource/input identities. The selected executable is
`406aaa0e2a9130580d16bfcadc8ee08c8b0fa05f59cd9f0ec2ee18383b342808`,
from receipt `20261103-110455-30b1ed31`. Its frozen compiler input contains the
precision fix although its recorded Git head predates the feature commit.
The captures use scale 1, ten-second settling, private profiles, fresh browser
processes, and separate 3 GiB runtime memory guards. This frozen comparison
does not establish responsive JavaScript behavior or live application execution.

At that point, the remaining fourteen pixels had maximum channel error 2 along the
bottom corners of the rounded “What can you do?” border. Independent Skia probes
reproduced that difference when the border shared a multisampled surface. The
initial tile-origin probes did not remove it. Those failed probes remain
historical diagnostics; the complete tile trace below identifies the correct
origin. The standalone media-query fixture and its Brave PNG remain unchanged.

## November 3: fixed hit-test bounds and exact partial raster tiles

`635ceb1b6` retains hit-test-only fixed-container geometry while tracking the
drawn recording bounds separately. Compatible viewport anchors can contribute
that empty geometry to an earlier fixed picture; drawing commands keep their
existing fixed-owner identity. Opposite anchors, independently composited
surfaces and scrolling descendants retain their own recordings. The added
fixed-container mode preserves ordinary drawing-client grouping and the
existing unsupported root-culling fallback.

Chromium's
[partial-recording tiling calculation](https://chromium.googlesource.com/chromium/src/+/156.0.8078.48/cc/tiles/picture_layer_tiling.cc#884)
snaps the recorded rectangle to 128 device texels within the complete layer's
coordinate space. A complete, non-lossy Brave trace places this page's main
layer at `(144,61)`, size `996×667`, with tiling rectangle `(0,128,996,349)`.
Its raster tiles begin at layer y=128 and y=382. The button's bottom corners
therefore paint in the second tile, which has none of the composer's SVG paths.
Vox previously started its recording at document y=230 and put the button and
composer paths together in one multisampled tile. The fixed-container geometry
restores the partial recording's document y=189 origin. Replaying Brave's own
picture at its traced second-tile origin independently reproduces the border
at zero pixels, without color adjustments.

The small layout reduction independently confirms this geometry in Brave:
an unpainted fixed sibling extends a layer to `(100,20,800,700)`, while the
recorded tile rectangle is `(128,128,92,142)` in that layer. The focused V tests
check the corresponding `(228,148,92,142)` document rectangle, device scaling,
resize/reuse, opposite anchors and nested compositor/scroll exclusions.

| Document viewport | Matched source control | Source browser with fixed tiles |
| --- | ---: | ---: |
| 800×600 | 0 differing pixels | **0** |
| 1024×768 | 14 | **0** |
| 1280×800 | 14 | **0** |

`layer-origin-control-matrix-6/` and `layer-origin-final-matrix-9/` use fresh
processes, private profiles, scale 1, ten-second settling and the same unchanged
Brave references and original archived resources. All four native libraries
match between control and candidate. Every capture has stable identities and
inputs, matching document/viewport/PNG identity, complete readiness and empty
native error/script diagnostic arrays. The candidate is a directly compiled
no-GC source browser linked to the existing canonical native libraries; it is
not a production-bundle or performance result.

All three new test functions pass in default, no-GC and verified bounded
prealloc modes. Fifty existing layer, sticky, fixed-owner, hit-test and MSAA-grid
test functions also pass. All twenty guarded compile/runtime steps exit zero,
with relevant source hashes stable. The existing fixed-sibling visual pair
remains exact against the unchanged Brave capture. Evidence is in
`fixed-recording-focused-9/`, `fixed-recording-regressions-9/` and the two
`fixed-sibling-*-final-9/` directories under the private evidence root.

Rejected candidates remain retained: broad metadata regrouping introduced
55/230/5,667 differences across the three viewports, and trimming every fixed
recording introduced a single sidebar-icon pixel at each size. Neither was
shipped. GPU format, resolve-mode and Skia-version probes did not fix the original
border. A separate single-SVG reduction still differs at eighteen pixels in
both control and candidate; its input/reference are preserved in
`rejected-single-svg-reduction-9/`, with no acceptance claim for that case.

The completed shared production executable
`904ce62baa0e755a003f763ba56044239d694963679b2f45eca8cd8e07e72b35`,
from receipt `20261103-133720-8d009b74`, independently repeats all three exact
captures in `matrix-production-fixed-18/`. All document, viewport, resource,
reference and executable/native-library identity checks pass, with empty
native error/script diagnostic arrays and successful browser/guard exits.
The preceding guarded build failures remain retained; no additional production
build was queued for this check.

The exact frozen-page result does not revalidate the current
live frontend, backend conversation workflow, responsive scripts, signed-in
sessions or other routes. Earlier live results above remain historical because
their raw evidence was removed externally.

## November 3: current live guest conversation

`brave-fresh-service-17/` starts a normal fresh anonymous Brave session through
`socks5h://127.0.0.1:1337`. Its frontend makes two HTTP 200 document requests;
both original body hashes and request counts are retained. Native and Brave
execute the unmodified original frontend. The captured styles, scripts, fonts
and images supply the native static cache; backend responses are excluded.

`live-native-clean-20/` uses production executable `904ce62b…`, an empty initial
native cookie jar and a private profile. Its initial read-only audit verifies
complete readiness, an active document and the visible editor's geometry.
A native AppKit input probe then clicks that editor, types the controlled
prompt and presses Return after input settling. No author script or DOM state
is patched. Screenshot mode explicitly keeps the document active; this is a
functional capture with native input instrumentation, not an uninstrumented
performance result.

Both browsers receive the real reply `Vox ready.` in independent guest
conversations. The native URL advances to a conversation route, native/script
errors are empty, browser/guard exits are zero, and all pinned inputs and
executable/native-library identities remain stable. After the archived initial
homepage, backend connections retain native encrypted TLS through SOCKS; no
conversation or Sentinel response is replayed. The standard 12 GiB application
guard observes a 4,364,320,768-byte process-tree RSS peak.

The complete 1024×768 native conversation viewport matches the unchanged fresh
Brave frame at **zero differing pixels and zero channel error**, including all
four RGBA channels. The alpha channel is opaque in both captures. The
[Brave PNG](parity/raw/chatgpt-live-1024x768-20261103.brave.png) and
[production PNG](parity/raw/chatgpt-live-1024x768-20261103.vox.png) are committed
with their hashes in the live receipt. This verifies the recorded guest
workflow and viewport; signed-in sessions, other routes and performance remain
outside this result.

Earlier attempts remain failures. The first 3 GiB application trial is stopped
by its memory guard before a reply is verified. An older captured guest
frontend and a later imported-cookie trial receive visible unusual-activity
rejections. The successful current native run uses a clean cookie jar; no
cookie import is needed. The initial replayed Brave controls have a harness
type error, missing dynamically selected scripts, and a CDP timeout respectively;
none supplies a backend comparison or acceptance claim. The subsequent normal
fresh Brave session and clean native run establish the current result without
reclassifying those attempts.

`live-fresh-10/` retains another fresh guest variant, headed “What’s on the
agenda today?”. Its one HTTP 200 document response has no reported errors.
Brave's live and frozen captures match exactly, and the focused source browser
independently matches that frozen page at zero pixels at 1024×768
(`fresh-live-frozen-vox-12/`). This additional homepage comparison remains
separate from the production conversation and the three-viewport frozen cohort.

## Captured workload

The successful capture used a fresh, normal Brave window through
`socks5h://127.0.0.1:1337`, away from the pointer. The page title was
`ChatGPT: Chat, Work, Create & Code with AI`, at 1024×768 CSS pixels and an
emulated device scale of 1. Earlier curl and headless Brave attempts received
Cloudflare challenges; those responses are retained separately.

Private evidence is under `Build/chatgpt-parity-20261031/`. The successful
capture is `native/`, including `brave.png`, `frozen.html`, and
`original-archive/manifest.json`. That archive retains the original HTML,
stylesheets and available script responses, rather than replacing the site
with an imitation. The original document's SHA256 is
`1f72b297f96be72d20c6392e53c5fc63b05fcb022e70c8bb1449afdd20c13903`.

The archive has 304 response entries, including 291 scripts and two
stylesheets. It also records 218 response-body retrieval errors, including
requests from the earlier document before the site's reload. It is a captured
homepage workload, not a complete archive of every route or future API request.
CDP's newline-combined headers were split into individual HTTP fields for
replay; the original CDP metadata remains in `manifest.cdp.json`.

Vox additionally requested a 4,001-byte HTML-setter polyfill that Brave did not
need. A separate normal Brave capture downloaded that asset once through SOCKS
after curl received a challenge. `original-plus-fallback-archive/` adds this
response while retaining the original archive unchanged. It does not replace
the missing response with a fabricated script or forward later cache misses.

Subsequent comparisons use the local, non-forwarding HTTPS replay in
`tools/page_archive.py`. Missing requests never download from the internet.
The separate `frozen-archive/` removes scripts from the captured DOM to isolate
rendering. A successful frozen capture cannot validate application behavior.

The initial live reference used native-window raster settings. Later controlled
references pin Brave's device scale with the updated reference tool. Their
decoded images differ, so they are not interchangeable references. No exact
live-to-frozen parity is claimed.

## Implemented fixes

- `2baaeecd`: Inactive scroll timelines no longer sample the document clock
  and install forwards-filled animation values. ChatGPT's sidebar, header and
  composer retain their cascaded geometry. Explicit scroll clocks and paused
  hold times have focused coverage. This does not implement source resolution
  or the complete CSS scroll-animation range model.
- `88203642`: Compact wrappers expose the correct HTML interfaces for links,
  scripts, buttons, forms, dialogs and textareas. Parser-created and created
  elements retain their namespace, prototype hierarchy and interface identity.
- `889ae90d`: `querySelectorAll()` returns a static, branded `NodeList` with
  `item()`, iteration and out-of-range behavior. `childNodes` remains live.
  This removes ChatGPT's startup failure when it calls `list.item(list.length-1)`.
- `dd340a2a`: The Chromium font policy continues past unavailable
  `ui-sans-serif`. Brave's platform-font probe identifies `.SF NS` for the
  homepage heading. This commit also assumed -apple-system was an alias;
  `97efe424` corrects that assumption using a disambiguating Arial fallback.
  A standalone unavailable UI family still falls through to the author's
  ordinary sans-serif fallback. The LibWeb fixture policy is preserved.
- `3ee2380c`: Compact elements implement `toggleAttribute()`, including
  optional/undefined force values, validation, preserved existing values and
  the ordinary attribute mutation path. HTML names use ASCII lowercasing;
  non-ASCII names and SVG attribute case remain intact.

The initial `bde4c36a` mapping selected system UI directly for `ui-sans-serif`.
The unchanged Brave reference rejected it with 9,347 differing pixels.
`dd340a2a` corrects that generic-family assumption rather than changing the
reference or relaxing the comparison. Its separate -apple-system alias
assumption is corrected in the continuation below. The failed test and platform-font probes are retained.

The focused V tests execute twelve cases in each of Boehm and no-GC modes,
24 executions total. Compilations use the 12 GiB guard and a 10G V compiler
limit; test binaries execute under separate 3 GiB guards. Receipts are in
`focused-test-results.json`. The first attempt to compile the CSS tests under
a 3 GiB aggregate guard was stopped; it receives no test credit.

The reduced `inactive-scroll-sidebar` native comparison passes with zero
differing pixels. Both font comparisons also pass with zero differing pixels,
using the original `ui-sans-system-font` reference and the added
`apple-system-font-stack` reference.

## Earlier native validation

The shared production build completed successfully and its recorded tracked
inputs stayed stable. Its receipt is
`Build/forum-news-svg-opacity-fold-20261031/production-final-guard/result.json`.
This session's later build request encountered the busy shared guard and did
not queue a build. The completed shared bundle was reused instead. Its tracked
feature hashes match the tested source; the complete current toggle helper's
JavaScript bytes were additionally verified in the executable because that
new file was untracked when the other session collected its build inputs.

The executable SHA256 is
`7a940e79d2d2105d721e201664d17885863b9010680510d8a3266cbfb3627306`.
`selected-production.json` records the native libraries and bundled filter
snapshot too. Every final check launches fresh processes and retains an
unchanged executable/library identity before and after capture.

- Three focused Brave pixel comparisons: all exact.
- Default screenshot smoke set: 11 passes, eight exact and three within their
  existing allowances.
- SVG image replacement and paint-server mutation guards: ten exact passes.
- Native `--headless-smoke`: passes.
- Original-script replay: document loads, but application startup fails its
  JavaScript gate. Successful screenshot capture is not application success.

The 1024×768 frozen-page comparison still fails exact equality:

| Saved Vox capture | Differing pixels against the same controlled Brave reference |
| --- | ---: |
| Initial completed production bundle | 222,349 / 786,432 (28.2731%) |
| Selected final production bundle | 124,595 / 786,432 (15.8431%) |

The final maximum channel error is 239 and MAE is 2.5606. No pixels or regions
are excluded. These whole-page counts include independent native changes in
the shared builds and do not isolate an individual fix's contribution.
Cookie-banner policy and text wrapping still visibly differ. The exact focused
fixtures do not establish exact rendering of the complete page.

Images, diffs, commands and actual guard results are in `frozen-acceptance/`,
`original-acceptance/`, `acceptance.pixels.json`, `screenshot-summary.json` and
`acceptance-validation.json`. `site-status.json` explicitly records
`target_met: false`, `application_startup_success: false` and
`conversation_verified: false`.

## Remaining gates

The macOS host now executes real JavaScriptCore module graphs, with import-map
resolution, cycles, live bindings, dynamic imports and top-level await. The
standalone runtime without that host, and the Linux backend, still reject
module execution. Native module support alone does not establish that the
complete ChatGPT application starts.

The original-script replay passes the app's `data-octane-home-behavior-ready="1"`
gate in a fresh production window, with no native reported script errors.
The unmodified native startup probe also settles with 284 module sources,
no pending module requests, and no host errors. Brave reaches the same marker
from the same non-forwarding archive.

Vox hides matching cookie banners by default through `cookie_blocker.v`.
Conformance launches set `VOX_BLOCK_COOKIE_BANNERS=0` so both browsers display
the site's unchanged consent UI. Screenshot mode otherwise reports an inactive
window; `VOX_CAPTURE_DOCUMENT_ACTIVE=1` matches the focus emulation used in the
Brave reference. These policies are recorded explicitly and do not alter site
HTML, scripts, stylesheet rules, expected pixels, or comparison regions.

No screenshot tolerance or reference region is relaxed for ChatGPT. Startup
failures, incomplete captures, changed executable identities and memory-guard
failures do not count as successful validation.

## Native modules and live DOM follow-up

Private evidence for this continuation is under
`Build/chatgpt-shadow-modules-20261031/`. It reuses the sealed original archive
and the captured fallback response; ChatGPT has not been downloaded again.

- `4c870df8` and `aaba271e`: declarative shadow attachment clears the existing
  children, and compact ShadowRoot wrappers operate on native trees, including
  attachment, markup replacement, queries and root lookup.
- `bbc8921b` and `77ce4dbb`: parser-created import maps reach the owning Window,
  and the macOS host loads native JavaScriptCore module graphs through Fetch.
  Dynamic import rewriting uses the pinned es-module-lexer parser. Focused
  tests retain native module identity, cycles, live bindings and top-level await.
- `9ad0eff1`: asynchronous module supply enters the owning HTML realm.
- `1ca19806`: linked stylesheets expose their native CSSStyleSheet and live
  rule lists. Real link owners preserve style order, duplicate URLs each get
  completion events, and cross-origin rules retain their SecurityError gate.
  The pre-existing compact style-element sheet approximation is still separate.
- `0cb1ea9f`: input and textarea value/defaultValue access uses the real control
  models, including clean/dirty values, textarea newlines, reset and insertion.
  This fixes the captured app's `defaultValue.replace` startup exception.
- `f2afb17b`: macOS socket readiness survives partial SOCKS/TLS handshakes.
  Dispatch sources signal the owning CF loop; V callbacks stay on that loop.
  Duplicated descriptors remain owned until asynchronous cancellation finishes.
- `de4e64ac`: native socket callbacks and output pointers use 32-bit C integers.
  A Darwin arm64 ABI regression test deliberately leaves upper argument-register
  bits nonzero: the old callback created descriptor key 20014547599363 for
  descriptor 3; the corrected callback registers and removes descriptor 3.
- `b776b6b6`: the native module fixture covers 130 concurrent 256 KiB HTTPS
  responses through the local SOCKS replay. Failed module loads identify the
  requested URL. Both Boehm and no-GC executions pass.

The socket adapter passed twenty fresh-process HTTPS/SOCKS module trials.
Certificate tests still reject incorrect hostnames and unrelated certificate
chains. Native transport, large concurrent HTTP modules and scratch-lifetime
checks pass in Boehm and no-GC modes. Link/control tests additionally pass in
production allocator mode. Detailed compile and execution receipts, including
failed diagnostic attempts, remain in the private evidence directory.

The completed `production-control-styles-network` bundle includes the linked
stylesheets, text controls and dispatch socket adapter. Its executable SHA256 is
`2a3659dbae38badde55abe985f87b58f1c340ea1cfd7a42c134ae4d4db805f2d`.
Its build completed with stable recorded sources. It predates the integer ABI
fix and subsequent layout work, so it cannot validate those changes.

The unchanged original-script replay at 1024×768 still differs from its matched
normal-window Brave reference at 125,454 / 786,432 pixels (15.9523%, MAE 2.6107).
Both captures retain an identical native executable/library identity across
the check. `original-production-gcd-acceptance/` retains the images, complete
unmasked diff, readiness audit, proxy requests and build identity. This original
script workload is distinct from the earlier frozen-DOM comparison above.

## Focused screenshot checks

With the recorded completed production bundle:

```sh
python3 tools/test_scroll_animation_pixels.py
python3 tools/test_ui_sans_font_pixels.py
```

Each test pins the executable and native-library identity, launches a fresh
process with a private profile, and requires exact RGBA equality with its
Brave reference. The HTML inputs and reference PNGs are in
`Tests/Browser/Brave/{input,expected}/`.

## Native startup continuation

The original HTML response remains
`1f72b297f96be72d20c6392e53c5fc63b05fcb022e70c8bb1449afdd20c13903`.
No further ChatGPT download was made. Every replay uses the local SOCKS/TLS
archive with private, process-local trust; it does not forward misses.

- `547b107f` binds native document visibility; `96b9a8fa` reflects HTML language.
- `3bfd24c3` drains already-ready native completions within the event pump's
  existing budget. This lets the actual HTTPS module fan-out complete.
- `53906747` discovers lazy native controls in form collections; `5a560998`
  exposes live native form/radio collections and form-control owners.
- `873efb07` binds document focus queries to the actual navigable.
- `c5ffb62b` exposes native client rectangles and mutable DOMRect values.
  Native client rectangles currently describe one border box per element;
  fragmented inline geometry is not established by this slice.
- `dbd88037` keeps persistent allocations outside scratch around nested owners.
- `e4d17315` queues native mutation records and tracks removed subtree
  registrations through notification, re-observation and disconnect.
- `bfc8ad41` delivers MutationObserver/MutationRecord wrappers from native DOM
  records, with filtering, old values, static NodeLists, takeRecords and callback
  exceptions. During JavaScript, notifications share its protected Promise
  carrier; native-origin changes enter through the owning HTML checkpoint.
  Complete interleaving parity between the embedding's HTML and JSC queues
  is not established.
- `487a6830` exposes CSS.supports and CSS.escape through the existing CSS engine.
- `a1618b65` gives parsed and constructed Text/Comment nodes their native
  interface identities and CharacterData/Text mutation operations.
- `3e70411d` completes initial style preloads on their actual link owners,
  allowing load listeners to promote them to stylesheets using the fetched
  bytes. Failure, duplicated-link identity and request-scratch ownership are
  covered. Dynamic preloads of every destination are outside this slice.
- `717307f5` balances short text and avoids orphan words using native advances;
  `d15bc3ae` retains this behavior with overflow-wrap:break-word when whole words
  fit. Long-word fallback remains with the existing breaker.
- `c62c4f32` and `52317945` make consent and capture focus policies explicit.

Evidence is under `Build/chatgpt-shadow-modules-20261031/`. The 23-case API batch
passes in Boehm, no-GC and preallocated modes, including arena poisoning in the
last mode (`api-batch-results.json`, source hashes in `api-batch-sources.json`).
The 12-case stylesheet/preload regression batch passes in all three modes
(`style-preload-final-results.json`); the four wrap cases do too
(`wrap-breakword-final-results.json`). Compile and execution receipts are
separate. Failed diagnostic attempts remain available.

The focused persistent-allocation poison reproducer and native observer lifetime
checks pass. The allocator regression diagnostic also retains the original
unmodified failures: several string buffers were not inside the asserted owner,
and subsequent tests inherited the unfinished scopes. A separate 20-case harness
that explicitly clones the input buffers passes with poisoning. That adjusted
harness is diagnostic evidence, not an unmodified broad-suite pass.

The first completed continuation production build is pinned in
`production-frontend-complete/{result,guard,identity-after}.json`: executable
`50678667e6408574074c5f7472ea601a61208ff038ff91d4fd6773a8daa91740`.
All recorded source inputs were stable. Its fresh full-page capture reaches the
application marker with zero native errors, but differs from Brave in 371,812
of 786,432 pixels (47.2783%, MAE 3.7186). This exposed the missing promotion of
the secondary stylesheet and the unmatched screenshot focus policy. It used
visible consent UI and cannot be compared as a performance or regression result
with the earlier hidden-banner capture. Artifacts are in
`frontend-production-acceptance/`.

That same executable passes the default 11 screenshot cases, all 10 required SVG
mutation guards, the shadow/module fixture, the original wrapping fixture and
headless startup (`candidate-validation/results.json`). Brave's 5-second and
20-second original-archive control captures are pixel-identical. The additional
break-word fixture also leaves Brave's existing reference pixel-identical.

The next production comparison includes preload promotion, matched focus and
break-word wrapping. The executable is
`8fc9c4297469ca52c766697319c56d31d722f189bd2fdec0d6dfbe154f9bae37`
(`production-preload-focus-wrap/`). Its required implementation sources were
stable, although two unrelated native renderer test/header files changed during
the shared build, so the complete checkout was not stable. The unchanged
original archive reaches the application marker, activates both stylesheets and
reports zero native or JavaScript errors after 20 seconds. At 1024×768, scale 1,
with visible consent UI and explicitly active capture focus, it differs in
9,495 of 786,432 pixels (1.2074%, MAE 0.1889). No mask or pixel tolerance is used.
Artifacts are in `frontend-preload-focused-acceptance/`.

That executable passes both wrapping fixtures, the shadow/module fixture,
headless startup, the default 11 screenshot cases and the 10 SVG mutation
checks (`candidate-validation-preload-focused/results.json`). Native typing
then exposed missing active-element getters and legacy input events; commits
`984b07da` and `72f02cc7` provide those bindings. A later shared executable's
longer typing diagnostic exceeded the default 12 GiB memory guard after input,
so that diagnostic supplies no acceptance result. A separate small native
textarea fixture reproduces the first-character loss without React: its first
input listener's `.value` read resets a still-clean model. The dirty flag now
precedes input dispatch, including reentrant `defaultValue` access. This is an
intentional ordering correction to the current upstream translation.

Cached sentinel and conversation preparation POSTs return 404 in this archive;
no conversation has been sent or verified. Full pixel equality and sustained
interactive memory behavior remain open.


## Native editing, caret and idle-memory continuation

`ecde0df9` integrates `origin/master` at `b5af1a2e`, preserving the existing
shared commits. No textual merge conflicts occurred. The incoming 63 Python
checks and 26 CSS checks pass; the CSS checks run in all three allocator modes.
The integration receipts are in `Build/chatgpt-master-integration-20261031/`.

The following focused changes are committed separately:

- `1b90a77e` marks textarea edits dirty before input listeners can read the value.
- `144829e2`, `1ce246dc`, `a48ace48` and `bbe70152` provide cap metrics,
  cross-node kerning, nested-inline wrapping and horizontal text-box trimming.
  Trimming supports the implemented Latin edges; ideographic edges, vertical
  propagation and the complete shorthand are not claimed.
- `fbc807eb` routes clicks through the native event path without duplicate
  delivery. `21c21bba` exposes native KeyboardEvent data and listeners;
  `9cb5058e` dispatches keydown/keypress before editing default actions. Native
  Enter reaches JavaScript and cancellation prevents the editing action.
  This is not complete platform-key coverage: the shell's printable-character
  path and keyup delivery still have separate implementation limits.
- `4a1d9636` holds the caret visible during explicitly focused deterministic
  captures, without changing ordinary interactive blinking.
- `e844a956` distinguishes :has() match propagation from a fresh DOM mutation
  and drains whole-subtree fanout in the same style pass. Nested :is()/:where()
  selectors previously lagged a state change and continually scheduled work.
  Eighteen related CSS cases pass in all three allocator modes, including
  shadow trees, sibling selectors, later mutations and the existing result cache.
- `d59473cb` paints opaque padding-box outer shadows before the background,
  using the existing one-CSS-pixel overlap. The isolated Brave fixture is exact
  with single, multiple, asymmetric and hard shadows. The rejected wider-border
  overlap attempt and its failed comparison remain under Build/.
- `643b27e7` creates a focused textarea's native editor before layout, paints
  its caret above the placeholder, and uses integer CSS-pixel font metrics for
  Chromium caret height. The existing focused-control preparation, selection
  and layout-retention regressions and the new empty-control case pass in
  Boehm, no-GC and preallocated modes.
- `97efe424` corrects the earlier -apple-system alias assumption. Brave's
  platform-font probe selects ArialMT for `-apple-system, Arial`; the family is
  unavailable and must fall through. Explicit system-ui and BlinkMacSystemFont
  continue to select the system face. The original stack reference remains
  unchanged; the new disambiguating fixture is also exact.

The final validated production executable is
`c088a9024bdf363d2b05d519bf4cd6c50f3109630aa384de10119e6fac74cce4`.
Its native-library identities and build receipts are in
`production-caret-font-fallback/` under
`Build/chatgpt-shadow-modules-20261031/`. Required implementation inputs stayed
stable. An unrelated flex-layout source changed during the shared build, so
this is not a stable-whole-checkout build claim. Every acceptance capture and
screenshot group pins an unchanged executable/library identity and starts fresh
processes on the test display.

`candidate-validation-caret-font/results.json` records ten exact focused Brave
fixtures, successful headless startup, all eleven default screenshot passes
(eight exact and three within existing allowances), and ten exact SVG mutation
guards. The broader Page regression compilation exceeded the 12 GiB guard;
those attempts supply no broad-suite test credit. The twelve native editing
cases and native Enter regression execute successfully in all three modes.

`frontend-caret-font-acceptance/` retains the unchanged-original-archive capture,
matched normal-window Brave reference, complete diff, native readiness audit,
proxy log, PID and identity. Both original stylesheets load, the actual frontend
reaches its home-ready marker, and native/JavaScript error counts are zero.
At 1024×768, scale 1, visible consent UI and explicitly active document focus,
7,169 pixels differ (0.9116%, maximum channel error 60, MAE 0.0110). There are
454 pixels above channel error 3 and seven above 25. No region is masked and
no tolerance is applied to this whole-page result. SVG edges, rounded controls
and shadow/compositing rounding remain open.

The matched 20-second original-archive captures record peak aggregate RSS of
9,051,865,088 bytes before the :has() correction and 1,822,883,840 bytes after it.
The separate pinned diagnostic `native-idle-has-settle-60s/` completes in 61.34
seconds with peak RSS 1,824,686,080 bytes and zero script/native errors. Its
symbolized mmap stacks contain no :has() invalidation allocations after the
first ten seconds. These are memory/eligibility observations, not frame-rate
or scrolling-performance claims; the shared builds include independent changes.
The final full-page capture peaks at 1,826,340,864 bytes.

`native-editor-enter-caret-font/` records the latest native input check. A probe
sends actual AppKit mouse and keyboard events to the content view, types Vox,
and presses Enter. The composer retains all three characters; Enter reaches
the frontend without adding an editing newline. Archive-only sentinel and
conversation preparation requests remain 404, so neither that check nor the
startup marker establishes a completed chat response. All these checks reuse
the original saved download through the non-forwarding local SOCKS replay.


The latest shared bundle subsequently replaced that executable with
`588e99f41112f9986419a766bf7682e66736886f809ea296a07c19325ff983be`.
Its `Build/vlang-parity-20261031/definite-flex-basis-production-inputs-{before,after}.json`
receipts match all fourteen required implementation hashes
(`installed-shared-source-validation.json`). It is reused without another build.
`candidate-validation-installed-shared/results.json` repeats every focused,
headless, screenshot and SVG group successfully with stable identity.
`native-installed-shared-acceptance/` records a fresh original-archive native
capture compared against the unchanged, matched Brave reference identified in
`reference.json`: the same 7,169 differing pixels, zero script/native errors,
and peak RSS 1,826,275,328 bytes. The native typing/Enter check above also uses
this latest shared executable. Pixel-perfect rendering and a completed chat
reply remain unverified.


## Translucent rounded borders (2026-11-01)

`b976cef2` composites a matching solid background and translucent uniform border
through one outer rounded clip and offscreen layer. The border fills the inverse
inner rounded path, matching Brave's recorded paint commands. The recorder finds
the background after leading outer shadows; padding-box and content-box
backgrounds retain their separate clips. The native fallback uses the Dawn
picture rasterizer to preserve the layer's premultiplied resolve. Its inverse
path remains inside that offscreen layer and does not select MSAA for unrelated
shapes in the parent raster.

The new `rounded-translucent-border-clip-layer` fixture includes five border
cases, with thin borders and several shadows, and an unrelated black pill.
Every RGBA pixel in its 800×600 viewport matches normal-window Brave at scale 1.
The five original cases are unchanged in the reference; the added pill catches
parent-pass MSAA leakage. That rejected trial differed by 32 pixels with maximum
channel error 12 in this expanded fixture and added three larger errors to the
homepage's Accept all button. The final build removes those errors. No masks,
reference allowances or full-page tolerances were introduced.

Evidence is under `Build/chatgpt-svg-parity-20261101/`:

- `rounded-translucent-border-isolated-msaa-results.json`: both focused V cases
  execute in Boehm, no-GC and prealloc modes. They cover all three background
  clips, no/one/multiple shadows, empty clips and incompatible geometry.
- `native-clip-sanitizers/`: all five native sanitizer executables pass, including
  twelve exact native/GPU clip-layer cases and the existing rounded-underlay
  checks with tile batching and compound patches disabled separately.
- `black-neighbor-reference-v2/` and `border-reference-final.json`: the matched
  local Brave capture, reference identity and retained rejected control.
- `production-border-isolated-msaa/`: successful signed production build,
  stable source snapshots and `committed-source-validation.json`. All nine
  required committed source hashes match the build inputs. Later unrelated
  image-decode edits in shared files were excluded from this feature commit.
- `candidate-validation-border-isolated-msaa/results.json`: eleven exact
  focused Brave fixtures, successful headless startup, eleven default screenshot
  passes (eight exact and three within existing allowances), ten exact live SVG
  mutation comparisons, and successful archived startup/native input checks.
  Every group retains stable executable and native-library identities.

The executable SHA256 is
`c1d92f0e526723503945bb70de68b7337ad8195a86fa2bee484eed4ccd3511c7`.
The Skia bridge SHA256 is
`45909d7f9f2380c57ac81ddc65f991c99adcca526a88a8fe6f86ef79344efa5f`.

`Build/chatgpt-shadow-modules-20261031/rounded-border-isolated-msaa-20261101-acceptance/`
retains the final original-archive capture, PID, audit, proxy log and complete
pixel diff against the unchanged matched Brave reference. Both stylesheets load,
the frontend reaches its home-ready marker, and native/JavaScript error counts
are zero. The full 1024×768 comparison has 6,797 differing pixels, maximum error
60, MAE 0.0095, 334 pixels above error 3 and seven above 25. Its sampled aggregate
peak RSS is 1,821,261,824 bytes over 21.29 seconds. This is a capture observation,
not a new idle-memory or scrolling-performance measurement.

`rounded-border-isolated-msaa-20261101-editor/` records fresh native AppKit
mouse/keyboard input. The composer retains `Vox`, Enter adds no newline, and
native/JavaScript errors remain zero. The archive still lacks the service
responses needed for an actual chat reply. All captures reuse the original
SOCKS download through non-forwarding local replay. Full-page pixel parity and
a completed conversation remain open.


## CSS superellipse decorations and shared recordings

`813c0e68` transports computed physical/logical `corner-shape` values through
layout decorations and retained paint payloads. The Chromium painter now draws
solid nonnegative superellipse backgrounds, uniform borders and outer shadows.
Inset curves retain their original border geometry. Separate native geometry
checks reproduce Brave's complete spread-shadow and below-round inset paths,
including their float control points and path ordering. Concave native replay,
gradient backgrounds and propagation of custom contours to descendant clips
remain outside this slice.

The captured ChatGPT composer uses `superellipse(1.1)`. Its outer contour and
unfiltered shadow require parent-tile multisampling; ordinary rounded-border
rules remain unchanged. Supported contoured decorations now join root and
compositor picture eligibility. Keeping interacting paints in one picture
preserves their shared coverage before resolving pixels. The native shadow
sequence also retains the opaque source and `SrcIn` color filter used by
[Chromium's DrawLooper](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/cc/paint/draw_looper.cc).
That sequence adjustment alone produced no pixel improvement in its diagnostic.

The new `corner-shape-superellipse` fixture covers `1.1`, `1.25` and `.98`,
padding/content background clips, elliptical corners, three overlapping
shadows and an independent rounded button. Its normal-window Brave reference
is unchanged across two captures. Earlier prototypes differed in 267 pixels,
then 100. A diagnostic shared recording reached zero; the final installed
production bundle also compares **pixel-exact over all 800×600 pixels**.
The reference and comparison regions were not changed to obtain that result.

Evidence is under `Build/chatgpt-svg-parity-20261101/`:

- `contoured-final-binding-results.json` executes five focused binding,
  tile-classification and recording-eligibility cases in Boehm, no-GC and
  preallocated modes. The two style-transport cases also pass in all three
  modes; their original Boehm receipt is in `corner-shape-transport/`, and the
  other modes are in `corner-shape-transport-results.json`.
- `corner-shape-reference-native-sanitizers/` passes all seven sanitizer
  programs, including 27 geometry checks. The final expanded contour test
  passes 24 exact native/GPU cases in
  `native-corner-shape/test-msaa-color-v8-{compile,run}.*`, covering both scales,
  shared recording on/off, both parent-tile modes and three border alphas.
  Failed development prototypes remain retained without acceptance credit.
- `production-corner-shape-shared/` records the successful canonical production
  build: 452.16 seconds, sampled peak RSS 8,839,282,688 bytes, compiler and guard
  exit zero. Eighteen separate compiled feature files match both snapshots and
  the committed sources in `committed-feature-sources.json`. Independent edits
  changed shared files during compilation; no claim is made that the bundle
  validates every later edit in the shared checkout.
- `candidate-validation-corner-shape-shared/results.json` passes all fourteen
  groups with stable executable/native-library identities. Twelve focused
  Brave fixtures and ten SVG mutation guards are exact. The eleven default
  screenshot cases pass with their unchanged bounds: eight exact and three
  existing allowances. Headless startup and archived native input also pass.
  This totals 33 screenshot comparisons, thirty exact.

The accepted executable SHA256 is
`30c8df0398d9da52bd307e321324fad8ee0ef6e9973def12a270a5f8c4b6d045`;
the Skia bridge is
`a2c8091e077d7b6e7c807d7849db597a0a4bc65d264d9a25a954c14ee714290b`.
The retained identity files also pin Graphite, Dawn and the filter snapshot.
Each check launches a fresh process.

The original-archive capture is
`Build/chatgpt-shadow-modules-20261031/corner-shape-shared-20261101-acceptance/`.
Both stylesheets load, home-ready is `1`, and native/JavaScript errors are zero.
It differs from the unchanged Brave reference in **6,594 pixels**, with MAE
0.0066, maximum error 60, eight pixels above error 3, five above 25 and two
above 50. The capture peaks at 1,955,495,936 bytes over 21.29 seconds. The earlier
6,797-pixel capture is retained; these whole-bundle comparisons also include
independent changes and do not isolate one fix's contribution.

`corner-shape-shared-20261101-editor/` verifies native AppKit typing and Enter:
the textarea contains `Vox` without a newline and startup remains error-free.
Its peak RSS is 2,250,014,720 bytes over 23.10 seconds. These are capture/input
observations, not idle-memory or scrolling measurements. The original SOCKS
archive is reused through non-forwarding replay. Full-page pixel equality and
a completed service reply remain open.

## Rounded SVG compositor clips and shadow bounds (2026-11-01)

Commit `541dfe29` makes complete compositor pictures retain rounded ancestor
clips on supported solid SVG fills and simple strokes. Scalar SVG batches keep their rectangular
clip restriction. Balanced CSS scopes with full opacity and normal blending
are eligible when their boundaries share the layer; incomplete scopes, real
effects, masks and unsupported transforms retain their fallback.

The ChatGPT microphone's two filled paths exercise this path. The focused
`compositor-rounded-svg-clip` fixture combines a large SVG fill crossing a
rounded overflow clip with the captured microphone, translucent border and
three composer shadows. Its normal-window Brave reference is unchanged across
two captures. The final production capture matches all 480,000 pixels exactly.

A shadow recording must use the compositor's three-sigma ink extent in document
coordinates, while its fallback bitmap may keep a larger allocation margin.
Using the allocation margin as recording ink extends the picture above its
layer and disables the raster tile that preserves Chromium's coverage phase.
The original fixture had 270 one-level differences. The first installed bounds
fix retained those differences because its extent was calculated after the
paths moved to local coordinates; that failure is retained. The final fix
calculates the extent before moving the paths and is pixel-exact.

Private evidence is under `Build/chatgpt-svg-parity-20261101/`:

- `compositor-rounded-svg-identity-scopes-results.json`: four focused V cases
  pass in Boehm, no-GC and preallocation modes (12 case executions).
- `compositor-clip-bounds-native-sanitizers/`: all seven native programs pass
  AddressSanitizer and UndefinedBehaviorSanitizer. After correcting the bounds'
  coordinate space, `compositor-clip-bounds-final-native/` repeats the affected
  contoured painter's 24 exact GPU cases successfully.
- `production-compositor-clip-bounds/`: the guarded base production build
  succeeds. Other sessions changed unrelated inputs during compilation; the
  feature's V files remain identical before and after. The initial installed
  native bounds failure is retained in
  `candidate-validation-compositor-clip-bounds/`.
- `production-compositor-native-bounds-final/`: rebuilds and installs only the
  corrected native painting library under the shared production lock, then
  re-signs and verifies the assembled bundle. All native source inputs remain
  stable. Re-signing changes the executable hash as well as the library hash;
  the final identities are recorded in `identity-after.json`.
- `candidate-validation-compositor-clip-bounds-final/results.json`: final
  focused pixels, headless startup, the original archived application and
  native input checks. All 15 groups pass with one unchanged final bundle
  identity. The 34 screenshot comparisons include 13 exact focused fixtures,
  the default 11 smoke cases (eight exact, three within existing bounds), and
  ten exact SVG mutation guards. No reference or tolerance was changed.

The accepted archived capture is
`Build/chatgpt-shadow-modules-20261031/compositor-clip-bounds-final-20261101-acceptance/`.
It preserves the original archived document and the existing 1024×768 Brave
reference, with scale 1, an active document and the cookie banner visible.
The private HTTPS SOCKS replay never forwards missing responses. A 60-second
settle is followed by checks for the home-ready marker, both stylesheets,
complete readiness, document activity and zero reported native JavaScript
errors. The guard records a successful exit and a 1,947,320,320-byte peak.
This is a readiness/rendering check, not a startup-speed measurement.

The result is **876 of 786,432 differing pixels (0.1114%, MAE 0.0008688)**,
with maximum channel error 18. Two pixels exceed 3 and 10; none exceed 25.
The remaining differences include the heading, footer, cookie-banner edges
and two caret-end pixels. The separately injected aliasing and clipping caret
experiments do not fix those two pixels and supply no acceptance credit.

`compositor-clip-bounds-final-20261101-editor/` checks native AppKit mouse and
keyboard input after startup. Typing `Vox` followed by Enter leaves `Vox` in the
focused textarea without a newline, with the home-ready marker present and no
reported JavaScript errors. The archive does not contain a successful chat
response, so a completed conversation and pixel-exact full-page parity remain
unverified.


## Fractional compositor caret sampling (2026-11-01)

Commit `89d2708c` tags input and textarea carets in the paint transport and
routes eligible Chromium caret fills through a translated solid color raster.
The native recorder was introduced on shared master in `e61b978f`; this commit
connects it to the tagged caret and adds its focused coverage. Complete
compositor pictures sample transparent cap rows linearly and retain integral
side coverage. Rectangular control clips round outward to avoid applying the
fractional cap coverage twice. Unsupported geometry retains the rectangle path.

All 16 native cases pass AddressSanitizer and UndefinedBehaviorSanitizer,
covering two raster scales, four fractional phases, two widths, the text-control
clip and all neighboring pixels. The focused layout test passes with Boehm,
no GC and preallocated memory. The new normal-window Brave fixture is pixel-exact.
The original complete-page comparison falls from 876 to **874 differing pixels**,
with maximum channel error falling from 18 to **2**; no pixel exceeds 3. MAE is
0.0008344650 across all 786,432 pixels. References and tolerances are unchanged.

Evidence under `Build/chatgpt-svg-parity-20261101/`:

- `caret-layer-native-sanitizers/` and `compositor-caret-tag-results.json`:
  native sanitizers and all three V memory configurations pass.
- `production-caret-layer/`: guarded production build succeeds. Other sessions
  changed unrelated inputs during compilation; the caret helper, transport,
  native bridge and recorder remain identical before and after. The executable
  SHA256 is `407366bc00663be8487f2b0d3ddc484b4bb337390bed62c4170d06c889105d38`;
  the native painter is
  `16b596c215b3953bf9ea320fe0d9fab3e9e6569c1291633089cc86456e357e55`.
- `candidate-validation-caret-layer/results.json`: all 16 validation groups
  pass with stable executable/library identities. The 35 screenshot checks
  include 14 exact focused comparisons, the default 11 smoke cases (eight
  exact, three within their existing bounds), and ten exact SVG mutation guards.
  Headless startup also passes.

The unchanged, non-forwarding original archive capture is
`Build/chatgpt-shadow-modules-20261031/caret-layer-20261101-acceptance/`.
It retains the active document, visible cookie banner, 1024×768 viewport and
60-second settle. Startup, both stylesheets and zero native script errors are
verified. `caret-layer-20261101-editor/` separately passes native typing and Enter.
The remaining heading, footer and cookie-edge differences leave pixel-perfect
parity open; the archive still cannot establish a completed service reply.

An ordinary rounded-shadow recording experiment was rejected because its
focused comparison regressed. Its patches and failed captures are retained
under the same evidence root. Earlier first-frame crashes from a shared bundle
lacking the already-landed stationary-raster document guard also remain failures;
only the fresh, successfully completed bundle above receives validation credit.


## macOS reduced-transparency preference (2026-11-01)

Commit `ea5cc6b2` samples macOS's native Reduce Transparency setting before the
browser's initial document is created. The Page preference reaches both the
stylesheet media evaluator and Window media-feature queries through Document.
Detached documents retain `no-preference`. Changing a Page preference invalidates
attached styles and schedules media-query evaluation; setting the same value
again leaves the environment version unchanged. Native OS notification handling
and resampling after a running process's startup remain outside this slice.

This Mac's `NSWorkspace.accessibilityDisplayShouldReduceTransparency` and its
stored accessibility preference both report true. Brave consequently disables
ChatGPT's heading masks; Vox previously always reported `no-preference`.
A separate diagnostic forces only that CSS condition in a copied replay archive
and reduces the comparison from 874 to 523 differing pixels. It is diagnostic
only. The production fix then obtains **the same 523-pixel result from the
unchanged original archive**, without stylesheet or HTML substitutions.
The complete heading now matches the unchanged Brave reference.

All remaining differences are in the footer/cookie-banner region and have
maximum channel error **1**. Full-page MAE is 0.0004987717 across 786,432 pixels.
Pixel-perfect parity and a completed conversation remain open. The original
HTML and Brave PNG hashes are rechecked and unchanged; replay still never
forwards missing responses or downloads ChatGPT again.

Evidence under `Build/chatgpt-svg-parity-20261101/`:

- `reduced-transparency-host.json`: the native macOS preference observation.
- `reduced-transparency-render-update-results.json`: three focused cases pass
  in Boehm, no-GC and preallocation modes (nine case executions). They cover
  detached defaults, Page isolation/reassociation, cached stylesheet and Window
  queries, boolean query syntax, no-op preference writes and actual relayout.
  The first test attempt read the cached MediaQueryList before its rendering
  update and failed. Its original result is retained; the corrected test runs
  the existing media-query update before observing the cached value.
- `production-reduced-transparency/`: guarded production build succeeds. The
  implementation inputs remain identical before and after. Other sessions
  changed unrelated inputs, and the focused test correction changed the
  test-only source during compilation. The executable SHA256 is
  `7ce713f3ebb850274e4383c162af0aaaee02200aaf91418489509a114f3fb1fc`;
  the native painting library remains
  `16b596c215b3953bf9ea320fe0d9fab3e9e6569c1291633089cc86456e357e55`.
- `candidate-validation-reduced-transparency/results.json`: all 16 groups pass
  with stable executable/library identities: 14 exact focused screenshots,
  eleven smoke comparisons (eight exact, three under existing bounds), ten
  exact SVG guards, headless startup, original archived startup and native input.

The full archived capture and native input evidence are respectively
`Build/chatgpt-shadow-modules-20261031/reduced-transparency-20261101-acceptance/`
and `reduced-transparency-20261101-editor/`. Both pass complete readiness,
active-document identity, both stylesheet owners, the home-ready marker and
zero native-reported JavaScript errors. The native input check types `Vox` and
presses Enter without inserting a newline. No successful service reply is in
the archive, so this is not evidence of a completed conversation.


## Promoted text and rounded compositor surfaces (2026-11-01)

`cebba92c` keeps solid underline rectangles and their skip-ink clips in the
same transparent compositor raster as their glyphs. Previously, any underline
sent an otherwise supported fixed text layer back to painting over the parent.
It also retains a transparent surface for contiguous, fully opaque promoted
boxes containing ordinary rounded shadows, backgrounds, borders and text.
Those boxes keep the established individual leaf painters instead of recording
the ordinary shadow into a different GPU picture. Unsupported resources,
effects, ownership gaps and clips retain the existing fallback.

The original-archive comparison now has **22 differing pixels**, maximum
channel error 1 and MAE 0.0000209808349609375. They are confined to the sidebar
Log in button's curved edges; the visible footer and cookie-banner region are
exact. No pixels or regions are excluded from the full-page comparison, and
pixel-perfect parity remains open. The intermediate shared build had 84
remaining pixels before the rounded-box surface was enabled. Different shared
builds also contain other sessions' changes; these totals are pinned rendering
results, not a controlled attribution of every changed pixel to this commit.

The selected production build is
`Build/cnn-home-static-media-20261101/`, reused without scheduling another
build. Its executable SHA256 is
`4d0a240456beb554d5dc63ebb8432c24d54c7e9024e8e8e9b87657ed98562b16`
and painting-library SHA256 is
`ea57efeed85f7fd70a42fdf5cbe3200c074405ac127edef143c35a092b0ec9aa`.
All four implementation/test inputs for this feature match the build's before
and after snapshots. The receipt also retains unrelated shared-source drift;
it does not validate native changes made after the native library was built.

Evidence under `Build/chatgpt-svg-parity-20261101/` includes:

- `decorated-text-mini/`: the actual eligibility function bodies and six text
  cases pass in default, no-GC and preallocated modes, with unchanged inputs.
  A full-root compilation initially encountered an unrelated UI migration
  syntax error. After that owner corrected it, the two new text tests also
  compile and execute in the complete browser module.
- `leaf-compositor-focused-*` and `leaf-modes/`: two rounded-surface cases pass
  in all three modes, including an actual fixed clipped document and rejection
  of unsupported resources, invalid clips, effects and ownership gaps.
- `candidate-validation-promoted-layers/results.json`: all 18 groups pass with
  stable executable/library identities. Both new reduced fixtures and the
  existing focused pixel guards are exact. Eleven smoke comparisons pass
  (eight exact, three with their existing bounds), as do ten exact SVG guards,
  headless startup, original archived startup and native typing plus Enter.
- The full-page and native-input captures are
  `Build/chatgpt-shadow-modules-20261031/promoted-layer-20261101-acceptance/`
  and `promoted-layer-20261101-editor/`. Both have the expected active document,
  complete readiness, both stylesheets, the home-ready marker and zero native
  JavaScript errors. Their guarded peaks are 2,056,192,000 and 2,265,530,368
  bytes, respectively. A successful Enter dispatch still does not prove a reply.

The full normal-window Brave reference remains byte-identical to
`59c9c9d12efe7410712f6edf1d4f82db9d79d3d219afd2914796aec2b1366095`.
`brave-footer-link-audit-20261101/` confirms the links use weight **400**; an
initial reduced model's inferred weight 590 was incorrect and is retained as
an unsuccessful diagnostic. The committed footer fixture models its visible
last line. An exploratory expanded fixture retains 19 mismatched pixels in
OKLCH channel conversion and skip-ink positioning, and the unoccluded first
footer line retains an eight-pixel cross-element shaping difference. Those
failures remain in the evidence directory without passing credit; that first
line is covered by the banner in the unchanged full-page reference. No
reference or tolerance in the existing conformance suites was changed.

## Conversation assets captured once (2026-11-01)

Typing and Enter requested six scripts absent from the initial homepage
capture. A normal Brave window fetched those files and their 56 previously
uncaptured static dependencies once through `socks5h://127.0.0.1:1337`.
All 62 responses are JavaScript with HTTP 200, totaling 1,106,764 bytes. The
original HTML and archive remain unchanged. The separate
`original-plus-conversation-assets-archive/` has 367 responses and a closed
static import graph; it replays from disk and forwards no missing request.
Receipts and raw bodies are in `conversation-assets-once/` and
`conversation-graph-assets-once/`.

`Build/chatgpt-shadow-modules-20261031/conversation-assets-once-20261101-editor-diagnostic/`
loads that extended archive, dispatches native typing and Enter, and reports
zero native JavaScript errors with a stable executable/library identity.
The missing-script requests disappear. Sentinel and conversation preparation
POSTs still receive the deliberate offline 404 responses, and two favicons
remain absent. A completed service reply remains unverified.


## Live API checks with the original cached document (2026-11-01)

The captured homepage embeds a signed conversation-document affinity token,
issued on **2026-10-31 at 03:41:38.169 UTC** and expiring on **2026-11-01 at
03:41:38.169 UTC**. Normal Brave, using the sealed frontend bytes and its own
TLS connection through the original SOCKS proxy, receives **HTTP 403,
`Invalid conversation document affinity`**, from both conversation preparation
attempts. Its Sentinel preparation requests succeed with HTTP 200. After
CDP keyboard input, Brave displays “Chat stopped unexpectedly”. This
rejects a completed-conversation claim for the expired snapshot; it does not
establish a Vox runtime defect.

`Build/chatgpt-svg-parity-20261101/brave-live-api-direct-socks/` records the
fresh private normal-window Brave process, intercepted cached GET responses,
forwarded conversation/Sentinel requests, status/body hashes, input and
before/after screenshots. The original HTML SHA256 remains unchanged; no
existing page or script response was downloaded again. The guard exits zero
with a sampled peak of 1,190,592,512 bytes. Token expiry is recorded without
copying the token into `expired-document-affinity.json`.

A separate native Vox diagnostic replays the same frontend and forwards only
the two API families through a local TLS bridge and SOCKS. It completes with
zero native JavaScript errors and dispatches native typing plus Enter, but
receives HTTP 403 challenge HTML. That bridge uses Python TLS rather than
Vox's or Brave's direct upstream TLS, so those responses cannot be attributed
to Vox's native transport. Evidence is
`Build/chatgpt-shadow-modules-20261031/live-api-20261101-editor-diagnostic/`;
the guarded peak is 2,387,869,696 bytes and the browser/guard exit zero.

At that checkpoint a fresh homepage response required an explicit exception
to this task's download-once constraint. The user subsequently authorized
“Fetch fresh session once”; the continuation below records that single fetch.
The original HTML and its pixel reference remain unchanged.


## Rounded backgrounds beneath invisible borders (2026-11-01)

`51a4d34f` removes the final **22 one-shade edge differences**, at the sidebar's
**Log in** button. An invisible uniform border still clips a solid background
to its outer rounded contour. Vox previously rejected the zero-alpha border
from its shared-clip path and drew a rounded rectangle directly. The native
player now clips a rectangle as Brave does, without allocating an offscreen
layer or painting an inverse inner path when the border has no ink. Matching
outer backgrounds after ordinary shadows use the same path; padding/content
background clips remain separate.

The accepted full capture is
`Build/chatgpt-shadow-modules-20261031/transparent-background-20261101-acceptance/`.
It reports complete readiness, the expected active document, both stylesheet
owners, the home-ready marker and zero native JavaScript errors. All 786,432
RGBA pixels match the unchanged normal-window Brave reference, whose SHA256
remains `59c9c9d12efe7410712f6edf1d4f82db9d79d3d219afd2914796aec2b1366095`.
The browser and 12 GiB guard exit zero after 61.70 seconds, with a sampled peak
of 2,054,422,528 bytes. No regions are excluded and no tolerance is applied.

The reused completed production bundle is
`Build/vlang-text-phase-20261101/Vox-feature-trace-installed.app`. Its executable
SHA256 is `65377482c779266be6ef7474ac186a7bd80645a39cb148ceb513f6c2be28b847`
and painting-library SHA256 is
`a81429e0c55e0da9cc5fcaf52240b75b15b3a5ccd2e54392c5c18c37eea47e7d`.
All four changed implementation/test inputs match the build's before and after
snapshots and the checked source. The shared build includes unrelated source
drift, retained in its receipt. New processes were launched for every check;
the pinned bundle remains stable throughout the focused and full captures.

Verification under `Build/chatgpt-svg-parity-20261101/`:

- `transparent-rounded-checks/`: three focused V functions pass in default,
  no-GC and preallocated modes, nine executions total. This includes actual
  transparent-border documents with and without shadows, matching outer clips,
  and rejection of padding/content clips and opaque borders. Inputs are stable.
- `candidate-validation-transparent-background/results.json`: all fifteen
  groups pass, including ten focused pixel groups, headless startup, archived
  startup and its assessment, eleven screenshot smoke comparisons (eight exact
  and three under their existing bounds), and ten exact SVG guards. Both the
  new transparent-border fixture and the existing translucent-border fixture
  are exact. Executable/library identities are recorded and stable.
- `Build/chatgpt-shadow-modules-20261031/transparent-background-20261101-editor/`
  validates native typing plus Enter against the extended cached script graph,
  without inserting a newline. It has complete startup/readiness, zero native
  JavaScript errors and stable identities; the browser/guard exit zero after
  78.50 seconds with a sampled peak of 2,366,111,744 bytes. This remains an
  input check, not a successful service reply.
- `brave-sidebar-audit-20261101/` records the real sidebar button's geometry,
  computed styles and Brave's `clipRRect` followed by `drawRect`. An earlier
  sign-up selector matched a hidden header button and is retained separately;
  it supplied no sidebar evidence.
- `rounded-background-native-20261101-probe/` and
  `transparent-clip-control-20261101-diagnostic/`, under the shadow-modules
  evidence root, retain the private diagnostic control: 22 pixels before
  zero-alpha eligibility and zero afterward. A separate production capture,
  rather than this patched executable, supplies the accepted result above.

The original broader reduced fixture retains a 24-pixel, one-shade difference
for a padding-box background in `transparent-rounded-background-capture/`.
That separate case is outside this matching outer-border change and has no
passing credit. The committed fixture covers ordinary and promoted outer
backgrounds, a neighboring vector path and a shadowed background. Existing
conformance references and tolerances are unchanged.

Failed production attempts are retained without acceptance credit. The shared
`Build/cnn-home-lazy-final-20261101/` build encountered a build-script syntax
change during execution; the first `production-transparent-background/` attempt
then encountered an unrelated mutable array alias in the shared lazy-image WIP.
The buffer now uses a mutable reference, retaining its storage reuse. That
small compatibility correction remains with the existing shared lazy-image
work rather than including that unfinished feature in this rendering commit.
Two later build-attempt guards returned busy without queueing a build; the
completed shared bundle above was reused instead.

The earlier `rounded-background-20261101-probe/` interposition experiment exits
before startup with a dynamic-linker symbol error. It supplies no rendering
credit. The successful native-library diagnostic and the final complete
production captures remain distinct from that failed launch.


## Approved fresh session and native form events (2026-11-02 local time)

Private evidence is in `Build/chatgpt-fresh-session-20261101/`. The three
download ledgers record **one** fresh homepage GET through
`socks5h://127.0.0.1:1337`, and 228 new asset attempts with no repeated static
URLs. The refreshed HTML SHA256 is
`d0b3728cb686e0b8daa56463be1e5a5da96551073f3e0af585953779cf402547`.
All matched homepage captures use these cached bytes. The initial 129-asset
limit left modules missing; the next capture completed startup but blocked a
connectivity probe. Both failed attempts remain retained.

`brave-fresh-connectivity/` subsequently reaches `homeReady=1`, submits
“Reply with exactly: Vox ready.” and displays the real response “Vox ready.”
at a conversation URL. Its conversation updates return HTTP 200. This uses
the cached refreshed frontend with live backend requests through Brave's
native TLS and SOCKS. Cookies belong to its fresh private guest profile;
cookie and signed-token values remain outside Git.

The initial `fresh-live-archive/` lacks two attempted response bodies:
`conversation-source-dil.worker-jdREWLSm.js` and
`dil-catalog-names-D8rdU_EF.js`. Both were subsequently recovered from the
original private Brave HTTP cache, validating its SimpleCache CRC32 and
decoding Brotli locally. `http-cache-recovery.json` records zero network
fetches. `fresh-recovered-archive/` now has 598 hash-verified responses; the
earlier archive and its missing-body ledger remain intact. This recovery
does not establish a closed live resource graph.
`fresh-session-summary.json` preserves both the download totals and recovery.
Native checks seed the available response cache, replay the sole homepage
locally, and tunnel later ChatGPT connections through SOCKS without terminating
their upstream TLS. Encrypted connection counters do not establish which
uncached subresources were downloaded.

The refreshed frontend exposed three engine defects:

- `ca3a0862` exposes `compareDocumentPosition` on `Node.prototype` and resolves
  its receiver and argument to their actual DOM nodes. The absent method
  previously stopped module startup. Live ordering, containment, reparenting,
  detached nodes, interface branding and invalid calls pass six focused test
  executions across default, no-GC and preallocated modes. The new native
  pixel fixture changes from all-red to exact green. The pinned executable
  SHA256 is `a3090be3949360c1c114f55d511bb4ce4cb61691459449d2d32c595c0c65a6c7`;
  `node-position-validation-owned-build/results.json` records nine passing
  groups, including the unchanged original homepage at zero differing pixels,
  eleven screenshot smoke cases and ten exact SVG mutation guards.
- `dcfd6116` publishes disabled-attribute changes before native activation
  reads them. Without an active mutation observer, reflected-property and
  attribute writes previously waited for a later frame. Native click defaults
  now see enabling and disabling performed by the click listener. Three
  focused functions pass in all three memory modes, nine executions total,
  with stable inputs in `disabled-checks-3/`. The original failing assertion
  remains in `disabled-baseline/`.
- `91a7b133` routes editing and form listeners on compact elements and the
  document through native EventTarget dispatch. Form-level submit handlers
  previously stayed in the legacy callback list and missed native submission.
  Capture, cancellation, removal, once listeners, non-bubbling invalid events
  and an actual button-triggered submission pass six focused executions across
  the three memory modes, with stable inputs in `form-event-checks-2/`.

The production build containing both form fixes is pinned in
`form-events-production/Vox.app`, executable SHA256
`540e7144a515c0b5d576fc2fd11d4d853bb2241f5ae477e821dec85e1648946b`.
Its before/after source snapshots are identical and its 12 GiB guard exits zero,
with a sampled peak of 9,118,695,424 bytes. Earlier diagnostic pages added
observers and are retained separately; they do not supply unmodified-page
rendering or conversation acceptance.

`form-events-validation/results.json` records nine passing groups on that
stable pinned bundle: the Node fixture, eleven screenshot smoke cases, ten
exact SVG mutation guards, compact modules, decorated text, focused controls,
headless startup, the original full-page capture and its zero-pixel assessment.
The smoke cases retain their existing eight exact results and three allowances.
Screenshot drivers use the pinned executable directly, so another session can
replace the canonical bundle without changing these captures.

The unmodified refreshed homepage in `vox-fresh-homepage-form-events/` also
starts without native script errors. Its first comparison against the earlier
live Brave capture differs at 12,425 pixels (maximum 227, MAE 0.563493).
That Brave launcher omitted `--force-device-scale-factor=1`: a CDP viewport
override leaves rasterization dependent on native display scale. This is an
unmatched capture, retained without engine-regression or optimization credit.

`brave-fresh-replay-audit/` and `brave-fresh-replay-reference/` repeat the
refreshed frontend at matched 1024×768 and scale 1, with the native scale pinned
as well. Both Brave captures match each other and Vox at **zero differing
pixels**, maximum channel error 0 and MAE 0. The reference has complete
readiness, `homeReady=1` and loaded fonts; its PNG SHA256 is again
`59c9c9d12efe7410712f6edf1d4f82db9d79d3d219afd2914796aec2b1366095`,
identical to the unchanged original reference. No rendering implementation,
expected pixels, regions or tolerances changed to obtain this matched result.
The original live capture remains separate. This is a downloaded-frontend
comparison; live API behavior is validated independently.

Submitting on the unmodified page with both form fixes reaches its submit
handlers and clears the draft, but the application then displays an error.
`vox-form-events-live-click/` retains this failure without conversation credit.
`vox-submit-stack-diagnostic/` opens the site's own error panel and identifies
the absent `parentNode.replaceChild()` used for the page transition. A separate
native reported `e.set` error is retained too.

`ebe2053c` binds `Node.prototype.replaceChild()` to the native replacement
algorithm. Return identity, sibling moves, empty and populated fragments,
live collections, detached parents, cross-document adoption, branding and
hierarchy failures pass nine focused executions in the three memory modes,
with stable inputs in `replace-child-checks-2/`. The query dispatch was
incorporated in the intervening shared `7cdf5fdd` commit; existing history is
preserved. `replace-child-validation/results.json` records the nine passing
production groups, including the unchanged original homepage at zero pixels.

## Live native Send and remaining conversation parity

Further fresh-session fixes are committed separately:

- `f1ace039` exposes the native `FormDataEvent.formData` entry list to page
  scripts. This resolves the submit handler's `e.set` failure and preserves
  mutations and native File identity. Six focused executions and 34 adjacent
  HTML, XHR and JavaScript binding executions pass in
  `form-data-event-checks-2/` and `form-data-event-boundaries/`.
- `0a2f92c71` exposes native `ErrorEvent` constructors and payloads, including
  dictionary conversion, UTF-16 strings, native branding and error identity.
  Nine focused and 24 adjacent event-handler executions pass in
  `error-event-checks-4/` and `error-event-boundaries-final/`. The missing
  constructor previously obscured module-loading failures.
- `801af00ae` lets native Fetch transports reuse existing public, immutable,
  fresh script-cache responses. Module loading previously bypassed the seeded
  browser resource cache and could fail a new TLS fetch for an already saved
  module. Responses still pass through Fetch/CORS policy; authorization,
  private responses, unsupported variants and non-script/API destinations are
  excluded. Nine focused and ten transport-boundary executions pass in
  `script-cache-checks-3/` and `script-cache-boundaries/`.

The latest selected completed production is pinned in
`script-cache-selected-production/Vox.app`, executable SHA256
`4e6ade6f94b27fac5b2a51561742a7025a8beaa2ab699c99704785f58ace3cb3`.
It reuses the successful shared inline-measurement build, with matching
before/after hashes for the script-cache implementation and a verified
initializer in the executable. Two own build requests encountered the busy
production guard and did not queue. `script-cache-validation/results.json`
records all nine production groups passing, preserving the original homepage,
eleven smoke cases with existing allowances and ten exact SVG mutation checks.

`vox-script-cache-live-click/` uses the unmodified refreshed homepage, a fresh
private Vox process/profile and imported guest cookies. Only static resources
are seeded; backend responses are excluded. Native AppKit input types
“Reply with exactly: Vox ready.” and activates Send. The page navigates to a
real conversation and displays “Vox ready.” Both `native_reported_errors` and
`javascript_diagnostics` are empty, and executable/library identities remain
stable. Backend traffic uses native TLS through SOCKS, rather than replaying
the captured conversation response.

The matched-scale live Brave capture in
`brave-conversation-live-cached-workers/` also displays the exact prompt and
reply, using the saved frontend, the original private worker HTTP cache and
live backend requests. No additional parent-target static download is allowed.
This live comparison differs at 1,520 pixels, maximum channel error 239 and
MAE 0.162840. Native Vox renders a different reply DOM with default paragraph
margins, shifting its text by 12 pixels and its actions by 24 pixels. Rendering
Brave's saved conversation DOM in Vox instead matches the unchanged live Brave
PNG at **zero differing pixels** in `conversation-frozen-layout-2/`. The
separate Brave replay of that frozen DOM differs from its live capture at 27
user-bubble edge pixels; that discrepancy is retained. Neither frozen result
supplies acceptance for the live application's different DOM.

`vox-script-cache-live-enter/` retains the earlier failed Enter case: the full
draft remains in the editor, no messages appear, and both error collections
are empty. `982077b92` connects the missing JavaScript
`HTMLFormElement.requestSubmit()` to native form validation and submission.
It also synchronizes button form-attribute changes and initializes an inserted
submitter's absent owner. Native cancellation, constraint validation,
`formnovalidate`, receiver and submitter branding, ownership exceptions,
reassociation, created buttons and image submitters pass nine focused
executions across the three memory modes in `request-submit-checks-5/`.

The resulting production is pinned in `request-submit-production/Vox.app`,
executable SHA256
`9e4ea3c77ca40c7713b8f19b67c40e8bb0671f3eb571cb19dec182ab8fcf9bd5`.
Its owned implementation hashes are stable before and after the successful
12 GiB build; unrelated shared inputs changed and are listed in its receipt.
The sampled peak RSS is 9,150,840,832 bytes.
`vox-request-submit-live-enter/conversation-assessment.json` verifies the
unmodified refreshed page: native AppKit input types the full prompt and
presses Enter, a real conversation receives “Vox ready.”, and both error
collections remain empty. Backend responses are excluded from the seeded
cache, the homepage hash is unchanged, and executable/library identities
remain stable. The live conversation still differs at 1,520 pixels from the
same Brave reference. `request-submit-validation/results.json` records all
ten groups passing: the live Enter reply, the retained Node fixture, eleven
smoke cases with unchanged allowances, ten exact SVG mutations, compact
modules, decorated text, focused controls, headless startup, the original
homepage and its zero-pixel assessment. Every group retains its command,
actual exits and stable executable/library identity.

The worker runtime explicitly rejects module workers, but a late observer in
`vox-worker-diagnostic-hidden/` sees no worker creation before the fallback.
That observer is diagnostic only and does not establish the fallback's cause.
The earlier style-based observer crashed and is retained without acceptance
credit in `vox-worker-diagnostic/`. Request-path differences are being checked;
no full live-conversation parity claim is made yet.

## Decoder metadata lifetime across navigation

`f0047c3c2` protects the seven typed compact-query decoders from publishing
process-wide field metadata in a document arena. `json2` initializes that
metadata lazily; releasing its first allocation owner leaves later queries
with dangling pointers. `query-decode-baseline/poison.log` deterministically
reproduces a read from the released “initial compact query document” arena in
the inline-style decoder. Several earlier native diagnostics failed on that
same decoder path.

The new helper initializes only immutable field metadata in base storage,
then decodes actual request strings in their caller's allocation scope.
Navigation retirement, escaped-string ownership and syntax-failure scope
restoration pass nine focused executions across default, no-GC and
preallocated modes, with arena poisoning enabled. Receipts are in
`query-decode-checks/`, `query-decode-checks-remaining/` and
`query-decode-focused-summary.json`. The first no-GC compilation ran out of
disk space; its failed attempt is retained. Generated historical test
executables were removed with SHA256 cleanup receipts; commands, logs,
screenshots, references and pinned production bundles remain.

The resulting production is pinned in `query-decode-production/Vox.app`,
executable SHA256
`a935e1163b0e1c9cf6ae29e5ebb26d2cacc876e5d28120528f8a271cde35ffb5`.
Its owned inputs remain stable across the successful build, whose sampled
peak RSS is 9,996,615,680 bytes. Unrelated shared inputs changed and are listed
in its receipt. The unmodified live Enter check passes again with the exact
reply and empty native/module error collections. All nine standard rendering
and startup groups pass in `query-decode-validation-remainder/`, including the
unchanged homepage at zero differing pixels.

The additional whole-browser poison experiment is **failed**. Its fixed-delay
input activated Voice before the composer was ready, navigated to
`/?mode=voice`, reported missing `TextEncoderStream` support on that different
document, and faulted during shutdown. A later title-gated diagnostic also
activated Voice and failed. Neither supplies Send or poison acceptance.
`query-decode-validation/results.json` retains the failed group alongside the
ten passing normal groups; its combined assessment remains false.

The input investigation waits separately for composer attachment and a draft
that enables Send. On the decoder build, the textarea contains the full prompt
but that application state never becomes ready. The matching frontend uses
`instanceof InputEvent`, `inputType` and `data`; that build exposes native text
edits through a plain `UIEvent` wrapper. The instrumented renderer-error module
and title markers remain diagnostic only and supply no unmodified-page pixel
acceptance.

## Native InputEvent payloads

`34e5fedb0` binds native `InputEvent` text and composition payloads, nullable
data, data-transfer identity and the `UIEvent` inheritance chain. Text controls
return a fresh empty target-range array. Native contenteditable ranges and
nonempty constructor `targetRanges` remain unsupported; this is not full
StaticRange or InputEvent parity.

Constructor conversion, UTF-16 preservation, native wrapper identity and
retained-root checks pass nine focused executions across default, no-GC and
preallocated modes in `input-event-checks-final/`. Three further executions in
`input-event-native-checks-final/` exercise actual BrowserApp typing and deletion,
including a supplementary character, trusted event payloads, document capture,
target identity and the textarea value visible during delivery. Final source
hashes remain stable in both sets of receipts.

The pinned production in `input-event-production/Vox.app` has executable SHA256
`09a6eabeeab25d9c072d7d8fb616259be4d9ae2d0f5541b23d0e7347cf2e306b`.
Its owned implementation hashes remain stable across the successful build;
the sampled peak RSS is 9,014,509,568 bytes, and the receipt lists unrelated
shared inputs that changed. The fixed-delay click
again activates Voice and faults during teardown, so it supplies no Send
acceptance. The unmodified Enter check exits normally with empty native/module
error collections but stays on the homepage without a reply. Both failures
remain in `input-event-validation/` and `input-event-validation-remainder/`.

`vox-native-input-state/` confirms that the macOS input path delivers all thirty
typed characters as trusted, composed `InputEvent` objects with the correct
target, type, data and current value, observed in both capture and bubble
listeners. The application's draft signal contains the exact prompt, while
its `canSubmit` signal remains false. This diagnostic rules out absent native
input delivery as the remaining submission failure; it does not establish the
cause of the false signal or supply pixel acceptance.

All nine rendering/startup groups pass in `input-event-rendering-validation/`:
the Node fixture, eleven smoke cases with unchanged allowances, ten exact SVG
mutations, compact modules, decorated text, focused controls, headless startup,
the original homepage and its zero-pixel assessment. Executable/library
identities remain stable. `input-event-combined-assessment.json` retains these
passes alongside both failed interaction checks and remains false overall.

The subsequent diagnostic in `vox-submit-input-state-3/` narrows the false
submit signal to `authReady=false`; `hasText` is true, the draft is exact, and
the other blocking flags are clear. It changes two composer modules to expose
their inputs and adds a hidden observer, so it is diagnostic only. The earlier
probe preparations and failed archive-header attempt remain retained without
acceptance credit. The subsequent controller investigation is recorded below.

## Custom element events and frontend readiness

`9d2a968f5` routes arbitrary author event names through the native listener
list used by element `dispatchEvent`. Existing built-in resource/UI adapters
retain their delivery paths. Previously, custom element listeners stayed in
the compact JavaScript list, while dispatch used native DOM records. A refresh
event therefore never reached the composer's listener, leaving its frontend
`authReady` flag false. This flag describes controller readiness on the logged
out page, not a login result.

`vox-controller-state/` verifies that the controller's attachment guards all
pass but its readiness update never runs. The focused baseline retains the
same mismatch: document listeners receive `refresh`, while the target and
parent element listeners do not. `custom-event-baseline/` preserves its input,
hash, failed exits and the test-file rename receipt. An existing CustomEvent
test filename was initially reused by mistake; its original contents were
restored unchanged, and the new regression lives separately in
`main_compact_custom_element_event_test.v`.

Propagation, event identity, cancellation, once/duplicate handling, removal,
AbortSignal cleanup, case sensitivity, created-element identity and retained
built-in adapter behavior pass fifteen focused test executions in the three
memory modes. Final hashes are stable in `custom-element-event-checks/` and
`custom-element-host-checks/`.

The completed shared production from `Build/pikabu-clip-state-20261102/` was
reused rather than submitting another build. It is pinned at
`custom-element-production/Vox.app`, executable SHA256
`de1a55c201c45d3e8a49d21379f83a5cf1871a9bf2423a1c98b2ca0602ec0e6b`.
All build inputs remain stable, the build exits successfully, and sampled peak
RSS is 9,624,305,664 bytes. The updated controller diagnostic observes readiness
becoming true and a native Send receiving the exact reply with no native/module
errors. Its instrumented page supplies diagnostic evidence only.

On the unmodified refreshed page, `vox-custom-element-live-enter/` passes with
the exact reply and empty error collections. All nine retained rendering and
startup groups pass in `custom-element-validation-remainder/`, including the
unchanged homepage at zero differing pixels, eleven smoke cases with existing
allowances, and ten exact SVG mutations. The one-second fixed-delay Send attempt
still activates Voice and faults during teardown; its failure remains in
`custom-element-validation/`. A separate unmodified Send run with five seconds
of settling after typing passes in `vox-custom-element-settled-live-click/`.
This slower test does not erase the earlier failure or establish a one-second
input-readiness guarantee. The combined assessment retains the failed attempt.

The successful Enter capture and instrumented controller capture produce the
same PNG, with 1,440 differing pixels against the unchanged live Brave
reference. The separate settled Send capture differs at 1,154 pixels, with a
different assistant-action arrangement; both results are retained. The
remaining mismatches are confined to the assistant reply and its actions. The
user bubble now matches; the assistant still uses the ordinary paragraph DOM
with its twelve-pixel margin offset.

## Rich reply response selection

`vox-custom-element-worker-wire-diagnostic/` captures the native backend
response and observes the reply renderer. Rich browser rendering is enabled,
but the response contains `dil:null` and ordinary Markdown, so no worker is
created. Brave's retained response instead contains a `dil-v2` payload. The
HTTP Fetch user agent differs from `navigator.userAgent`.

The controlled HTTP-only override in
`vox-navigator-ua-worker-wire-diagnostic/` uses exactly the existing navigator
user agent. It receives the rich DIL payload and creates the corresponding
module worker. The next concrete failure is `Worker.postMessage` rejecting a
MessagePort as an unsupported transfer-list entry; fifteen native errors are
retained. Module-worker execution is also explicitly unsupported by the current
agent runtime. These diagnostics change no product user-agent behavior and
make no live pixel-parity claim. User-agent coherence, module execution and
cross-process port transfer remain required before rich-reply acceptance.

## Native worker prerequisites, 2026-11-02

`c5b553f47` makes HTTP Fetch use the current Loader user agent, including the
worker-process default before Loader initialization. Explicit request headers
remain authoritative. The two focused functions pass in default, no-GC and
preallocated modes in `user-agent-coherence-checks-2/`. The earlier controlled
override establishes that this coherent identity selects DIL; production
rich-reply validation with the committed implementation remains pending.

`95963892c` loads dedicated module workers through the worker's HTML module
map and the native JSC module loader. It covers redirected entries, static
imports and cycles, dynamic imports, credentials, import metadata, startup
failures, and top-level await while parent messages continue to run. Runtime
exceptions dispatch native worker error events. Module evaluation notifications
now call V directly: the previous JavaScript callback consumed a pending
exception, making a throwing dynamic import fulfill instead of reject. The
added caught-import regression passes for window modules and workers. The
native callback avoids reentering JSC at its
[module evaluation delegate boundary](https://github.com/WebKit/WebKit/blob/main/Source/JavaScriptCore/API/JSAPIGlobalObject.mm).

The five module-worker functions pass in all three memory modes in
`module-worker-entry-errors/`. Window modules, worker execution contexts and
classic script loading pass in `module-worker-window-checks/`,
`module-worker-context-checks/` and `module-worker-scripts-checks/`.
`module-worker-scope-checks/` exposed an independent native MessageEvent crash:
the implicit empty-origin default emitted an invalid sum-type tag. `36abf10e5`
boxes that default explicitly. Two focused functions and all six worker-global
functions pass in all three modes in `message-event-origin-checks/` and
`module-worker-scope-fixed/`. Original failures remain retained.

The macOS JSC module API requires its ordinary global class. Module workers
therefore expose real native worker members as own properties; their actual
global prototype chain still lacks WorkerGlobalScope/EventTarget inheritance.
Classic workers retain their existing native prototype chain. This is an
explicit module-worker parity limitation, without forged prototype queries or
Object.prototype pollution. Module execution on Linux remains unsupported.

The saved real worker then failed on a missing `performance` global.
`75c1deaac` extends the existing Performance and PerformanceObserver bindings
to the worker's settings, clock, timeline and event loop. Three worker
functions, the window performance tests and observer regressions pass in all
three memory modes in `worker-performance-entry-checks-2/`,
`worker-performance-window-checks/` and `worker-performance-observer-checks/`.
The window run's full source snapshot also includes two independently changing
worker-only paths; `focused-source-stable.json` authenticates its unchanged
performance implementation and actual test input.

`real-module-entry-performance/` executes both unchanged cached ChatGPT worker
assets, observes its native message handler, and finishes with zero error
events and zero reported exceptions. The earlier settled audit without
performance failed and is retained. These are worker startup checks using the
existing archive, with no new homepage download or browser screenshot credit.

`ceb0d2241` transfers fresh native MessagePorts through the dedicated-worker
process protocol. Each process keeps its own HTML endpoints and JavaScript
wrappers; hidden endpoints relay owned messages over the existing worker pipe.
Mixed buffer/port graphs retain transfer-list order, aliases and the received
MessageEvent.ports identities. Source ports are neutered, ArrayBuffers detach,
and port messages arriving before the receiving Worker task remain queued.
Messages and buffers cross by owning copies; this makes no zero-copy claim.

The new port tests and codec checks, plus classic/module agents, parent/child
sessions, ArrayBuffer transfer and both window/worker channel regressions,
pass 47 selected functions in each of the three memory modes: 141 function
executions. Receipts are in `worker-port-transfer-complete/`,
`worker-port-codec-final/` and the `worker-port-*-regression/` directories. The
standalone window-channel recovery is `worker-port-window-channel-standalone/`:
the initial invocation could not compile because its helpers lived in another
test file. Those helpers now belong to the actual channel test input; no
assertions were removed. All earlier failures remain retained.

Port transfer currently rejects active, previously used or queued endpoints,
and transferring a port through MessagePort.postMessage is still unsupported.
Those paths fail explicitly instead of dropping queued messages. The current
ChatGPT handoff uses a fresh port. Its first real process check reaches the
sandbox and then fails because non-configurable implementation callbacks are
visible on the worker global. The private diagnostic observer in
`dil-port-process-error-observer-2/` identifies
`__ladybirdDOMExceptionConstruct`; the subsequent worker-global audit also
finds the quota callbacks. This observer changes only the diagnostic worker
response. Browser conversation pixels with the new worker support remain
unvalidated at this point.

`056eb2989` keeps the DOMException, QuotaExceededError and EventTarget native
callbacks in private closures. Event wrapper factories also return directly
to V instead of becoming global properties. The module import helper uses a
private global lexical binding with its temporary initializer removed before
author modules execute; dynamic imports continue to work after an author
creates a same-named global property. The focused callback, exception, event,
module and port checks pass in all three memory modes, with stable source
receipts in `private-binding-focused-assessment.json`.

The unchanged worker now completes its real process/port handshake in
`dil-port-process-private-complete/`, returning `{kind:2,messageId:1}` with no
errors. `dil-port-process-private-prealloc/` also passes using the same patched
preallocation compiler as production. The error-observer worker response was
used only to diagnose the earlier failure; these successful handshakes use
the original two saved worker assets.

The first production candidate is pinned in `rich-worker-production/`,
executable `942104d390511a289c8096c1f9a40b5f5589cbfe113a57c3abc82907711807b8`.
It builds with unchanged source inputs under the memory guard. Its first
110-second Enter run reaches the 12 GiB guard before capture; that failed
attempt remains in `vox-rich-worker-live-enter/`. The separate 70-second run
finishes normally with the exact reply and empty error collections, but still
uses fallback Markdown and retains the same 1,440 differing conversation
pixels. This shorter result does not erase or explain the earlier memory
failure. The fresh homepage run `vox-rich-worker-fresh-home-60/` is pixel-exact
against the unchanged Brave homepage reference, at 1024×768.

`vox-rich-worker-wire-70/` confirms that the actual committed Fetch path
receives non-null DIL. The unchanged user-agent logger in
`vox-rich-worker-front-observer-75/` also observes the coherent navigator
identity. Its page observer sees repeated Worker construction and generic
worker error events before rendering falls back. The native input probe
changes dyld image order, and V's `os.executable()` returns image zero: the
browser consequently attempts to spawn the injected library as its worker.

`d3cb3ed99` selects the kernel-backed executable path already used for tabs and
the filter worker. `worker-executable-checks/` passes in default, no-GC and
preallocated modes with an injected library confirmed as image zero. The
replacement production build and full browser conversation validation follow
below; the first candidate's fallback capture earns no rich-reply parity.

## Rich conversation pixel validation, 2026-11-02

The replacement production bundle is pinned in
`Build/chatgpt-fresh-session-20261101/rich-worker-executable-production/`.
Its executable SHA256 is
`0ac2623ae134fdfb608d2d92e4c0a74c331bf8a7257a7d3ea84a6bf386bb9f3b`,
and its native Skia text library is
`44b2b4f0531513c817b69f2159d78cb1dbd30916bbd72cf46428a5a6f8bba572`.
The production build finishes with exit 0, unchanged source inputs, and a
9,745,465,344-byte sampled process-tree RSS peak under the default 12 GiB
guard. Checks launch fresh processes from this saved bundle and verify its
identity throughout. Independent work has since replaced the shared bundle;
these results apply to the pinned executable.

All nine selected rendering/startup groups pass with stable identities in
`rich-worker-rendering-validation/results.json`: node positioning, the existing
screenshot smoke set, live SVG mutation guards, compact modules, decorated
text composition, focused controls, headless startup, and the original archived
ChatGPT homepage capture and assessment. Existing references and tolerances
are unchanged.

`vox-rich-worker-executable-live-enter/` records the live service rejection.
Native typing and Enter submit the prompt, but the page displays the unusual
activity message and no assistant reply. The browser exits normally with
empty native and JavaScript error collections. The service's reason for this
rejection is unknown; this attempt fails live acceptance.

The subsequent `conversation-replay-tools/` fixture intercepts only conversation
prepare/update requests and directs them to a loopback HTTP server; none of
those requests reaches the live service. It serves the responses previously
captured in `vox-rich-worker-wire-70/`. The prepare response SHA256 is
`f049e8530fc1468ca4fd143cf71b350776ca24d150ffcc5578673cb5df8ef67d`,
and the rich NDJSON reply is
`f1b3e1e841458bd5a62ad68e82c4f40e64a7597d199c0d463c09b12e5985ac59`.
Only request UUID identities are normalized in the saved reply. Frontend HTML,
styles, scripts and both worker assets remain unchanged. Final-response replay
does not preserve the original streaming cadence or establish live backend
compatibility or performance.

The Enter and settled Send checks retain the existing native route for startup
and session requests: the first homepage response and static assets are served
from the archive, while later ChatGPT connections can use the SOCKS tunnel.
They are not fully offline trials. The separate strict archive checks below
reject every unknown external request instead of forwarding it.

| Fresh-process capture | Pixel differences | Sampled peak RSS | Browser exit |
| --- | ---: | ---: | ---: |
| `vox-rich-worker-executable-replayed-home/` | 0 / 786,432 | 1,871,216,640 bytes | 0 |
| `vox-rich-worker-executable-replayed-enter/` | 0 / 786,432 | 2,933,161,984 bytes | 0 |
| `vox-rich-worker-executable-replayed-settled-click/` | 0 / 786,432 | 3,149,643,776 bytes | 0 |

Each capture has empty native and JavaScript error collections and a stable
executable identity. The homepage reference remains
`Build/chatgpt-shadow-modules-20261031/frontend-caret-font-acceptance/brave.png`,
SHA256 `59c9c9d12efe7410712f6edf1d4f82db9d79d3d219afd2914796aec2b1366095`.
The conversation reference remains
`brave-conversation-live-cached-workers/after.png`, SHA256
`7acf0a8c964824340077c5a1f435a491a8f5da61cb813acc237b12bc4a849572`.
Both 110-second conversation captures have identical PNG SHA256
`192b4d28c56970c9f39c56a3041180a807993c1656c6474d067da9a97476a7ca`,
maximum channel error 0 and RGB MAE 0. The worker-generated assistant paragraph
now occupies the same geometry as Brave; the fallback's twelve-pixel offset
is absent.

The one-second Send checks in `vox-rich-worker-executable-offline-click/` and
`vox-rich-worker-executable-offline-session-click/` do not complete a
conversation. Their browsers exit 0 with stable identities and empty error
collections, but both drivers exit 2 after the content audit fails. The first
attempt lacks a Sentinel session-preparation POST response. The second serves
the original saved prepare/finalize responses for those two POST paths, while
continuing to reject every unknown external request. It still displays “Chat
stopped unexpectedly” without issuing a conversation update request. These
are failed offline fixture checks, with no one-second Send acceptance or new
homepage download. Their logs, screenshots and default memory-guard receipts
remain retained.

`rich-reply-validation-assessment.json` indexes the build, rendering checks,
successful pixel captures and retained failures. Its frozen-response pixel
result passes; its live acceptance result remains false. Private replay
artifacts retain session material locally under ignored `Build/` paths.

The first candidate's failed 110-second memory-guard attempt remains retained
and unexplained. Successful later checks do not establish a memory optimization
or erase that failure. These results cover the saved logged-out homepage and
single rich reply. Voice, login, other conversation content, module-worker
prototype inheritance, and active/nested MessagePort transfer remain outside
this acceptance result.

## Fresh live continuation, 2026-11-02

Private evidence for this continuation is under
`Build/chatgpt-live-refresh-20261102/`. Fresh sessions are authorized. The
successful direct Brave capture, `brave-direct-fresh-2/`, uses the real network
through `socks5h://127.0.0.1:1337`, an empty profile and no response substitution.
It submits the exact prompt “Reply with exactly: Vox ready.” and receives the
rich reply with zero runtime exceptions. `direct-fresh-archive-2/` retains 396
responses with verified body hashes and no body-retrieval errors. Its homepage
SHA256 is `fc8df84294fcfaa580f669af70f439e5d235a425d03226561aa107000df6af92`.
Both PNGs are byte-identical to the retained homepage and conversation
references; `reference-continuity.json` records this comparison.

Three fixes address the native input and worker paths:

- `bab31baea` consumes pending JavaScript effects before native pointer hit
  testing. It checks document and navigation identity after that work. The
  focused real-BrowserApp test switches the composer from Voice to Send in an
  input listener and clicks without an intervening draw or query.
- `d8714ad8c` initializes saved profile proxy settings in isolated script
  workers. Worker roles enter before the normal browser settings initializer;
  previously their requests silently took the direct route. The focused tests
  cover both scoped SOCKS routing and an explicitly direct profile.
- `7aae524a2` preserves FIFO order after cooperative document work finishes.
  New characters, Backspace and mouse releases join older queued input until
  replay begins. Replay has a reentry guard. The focused tests cover all three
  input types.

`pointer-state-final/`, `worker-proxy-checks/` and
`deferred-input-order-checks/` pass in default, no-GC and preallocated modes
with unchanged focused source hashes. Compiler jobs use the 12 GiB guard and
V's 10G limit; test executables use separate 3 GiB guards.
`deferred-navigation-css-coordinates/` also passes all eleven existing
navigation functions in each mode. Its initial link-click failure used internal
Retina coordinates as native CSS-pixel coordinates. `8bedb8e20` converts the
test's coordinates while preserving its queued press/release and navigation
assertions. The failed original and isolated invocations remain retained.

Final checks use `Build/v/Vox.app` directly and launch fresh processes. Its
executable SHA256 is
`e9b1cdeb2197ef69aacf701bb0e12149aecfabed3f2c68cb675d34631c3f681e`,
and Skia text library SHA256 is
`40ad586745631516ef2f9e7ddabb2c78db27943ab929a28c271c2cd2a7d4c27b`.
`final-production/reuse-canonical.json` records all bundled identities and the
production supervisor receipts. The published build at `d8714ad8c` and the
subsequent build at committed HEAD `7aae524a2` have the same complete repository
filename/content digest, `6c2a68e124167f164ece609e3ef087afbd27758e9aa84a2c8fee41410a084662`.
The published build therefore already contains the input-order changes. Its
build and headless-smoke receipts both exit 0; the build peaks at
9,670,606,848 sampled RSS bytes under the default 12 GiB guard. No duplicate
production build or new app-bundle copy is used for final validation.

`vox-final-ready-direct-click-1/` starts with empty settings storage apart from
the saved SOCKS endpoint, an empty cookie store and an empty resource cache.
There is no `VOX_PROXY` override or archive server. The audit verifies the real
homepage's behavior-ready marker and empty errors before native AppKit input
begins. Thirty character events arrive in separate native turns; Send follows
one second after typing. The final audit verifies both the exact user prompt
and exact assistant reply at a conversation URL, with empty error collections.
The browser and driver exit 0, and sampled process-tree RSS peaks at
3,241,918,464 bytes. Executable and native-library identities stay unchanged
throughout. The actual downloaded homepage SHA256 is
`e383d7bf02fe4266e269cac271feafc1b46398fff7b492372f5701e0c1d0e836`.

Its conversation PNG has SHA256
`192b4d28c56970c9f39c56a3041180a807993c1656c6474d067da9a97476a7ca`.
Both the newly captured Brave reply and the unchanged earlier reference have
**0 / 786,432 differing pixels, maximum channel error 0 and RGB MAE 0**.
No backend response, request UUID or frontend bytes are substituted in this
fully live check. These results establish the logged-out homepage-to-Send
workflow and this single rich reply at the recorded viewport.

The same production identity also passes these fresh-process checks, with
empty error collections, normal exits, unchanged references and input hashes:

| Capture | Network policy | Pixel differences | Sampled peak RSS |
| --- | --- | ---: | ---: |
| `vox-final-cached-front-home-1/` | Archived frontend 2; later ChatGPT connections live | 0 / 786,432 | 1,862,565,888 bytes |
| `vox-final-cached-front-live-enter-2/` | Archived frontend 4; conversation requests live | 0 / 786,432 | 3,025,076,224 bytes |

The Enter check uses the latest captured homepage and cookies from
`brave-direct-home-fresh-4/`. `fresh-merged-archive-4/` retains that unmodified
homepage and static responses, supplemented with earlier static assets from
the same URLs. Every archived body hash is verified before use. Conversation,
Sentinel and other backend response bodies are excluded from the seeded cache;
later ChatGPT TLS connections tunnel through SOCKS. Neither successful Enter
nor homepage capture establishes an additional cold-network pass. The homepage
uses the original controlled frontend bytes and retained homepage reference.

Retained failures qualify the result:

- The earlier live Enter check in `vox-fresh-live-enter-1/` passes with exact
  pixels and empty errors on executable `7a702c0d…`, using archived frontend
  bytes and live backend requests. `vox-direct-own-session-home/` also passes
  direct empty-session homepage loading with exact pixels on that build.
- Direct conversations before the worker proxy fix hit the 12 GiB guard.
  `vox-pointer-ready-direct-wire/` retains worker-script HTTP 403 responses
  and the sampled main-thread microtask loop. An explicit proxy override in
  `vox-pointer-ready-explicit-proxy/` permits a live reply at about 3.24 GB,
  but its scrambled user prompt fails content acceptance. That failure led to
  the FIFO fix. Later successful runs do not erase these memory failures or
  establish a general memory bound for failed worker startup.
- `vox-pointer-fixed-cached-click/` still follows Voice on the intermediate
  pointer-only build and then crashes during tab disposal. The pointer flush
  alone did not establish rapid-input Send correctness. The native stack,
  failed content audit and exit 139 remain retained.
- `vox-final-cached-front-burst-send-1/` also follows Voice and exits 139 on
  the final build, despite verified homepage readiness and stable inputs.
  Thirty key events run in one Cocoa turn, followed by a fixed-position click
  one second later. This differs from the successful per-character native-turn
  Send check. Its default memory guard peaks at 2,305,654,784 bytes. The final
  audit has two JavaScript diagnostics from the unsupported Voice route and
  no conversation. The FIFO fix does not establish correctness for this
  rapid-click case or repair the disposal crash.
- `vox-final-ready-direct-enter-1/` and
  `vox-final-direct-burst-click-1/` receive Cloudflare challenge documents
  before the behavior-ready gate. Both fail content acceptance with stable
  identities; the Enter probe sends no input. Thus the successful cold live
  Send run does not establish reliable challenge handling on every fresh load.
- `brave-direct-home-fresh-3/` differs by 21 caret pixels from the retained
  reference and receives no exact-pixel credit. The later
  `brave-direct-home-fresh-4/` receives the real homepage but fails readiness
  within its 40-second observation. Its captured document and static bytes
  remain usable as unchanged archive inputs; the incomplete live run receives
  no application-readiness or reference credit.

The initial fresh capture's incomplete CDP interception and the first merged
archive's missing seal are harness failures. Their evidence is retained and
neither counts as an application pass. Session cookies and response bodies
remain private under ignored `Build/` paths. Voice, login, other conversation
content and the previously documented worker/port limitations remain outside
the checked workflow.

Further diagnostics preserve that distinction. The native
`nested-frame-composer-diagnostic/` completes two nested animation frames and a
zero-delay timer after burst typing, then clicks Send with the full prompt and
empty errors. `navigation-identity-diagnostic/` passes a preallocated check
that navigates while document and temporary allocation owners are entered;
it does not reproduce the crash and introduces no product change.

`dispose-disassembly.guard.json` maps the observed crash to the document access
immediately after `destroy_a_document_and_its_descendants()` in tab disposal.
This identifies the faulting boundary without proving a lifetime or compiler
cause. The first debugger attempt stops at exec before the requested breakpoint;
the second lacks the intended private target environment and is invalid.
`vox-burst-dispose-debugger-3/` explicitly installs that environment, reaches the
live rich reply with the exact prompt and empty errors, and exits the browser
normally after the disposal breakpoint. The later debugger backtrace command
fails because the browser already exited, so its guard records exit 1. Debugger
instrumentation changes timing; this result supplies no uninstrumented rapid
Send acceptance and does not erase the exit-139 failure.

`fresh-live-validation-assessment.json` indexes these captures, focused checks,
production receipts and retained failures. Basic text-chat rendering passes for
the recorded workflows; reliable fresh-load challenge handling and the
rapid-click cleanup failure remain unresolved.

## Preload allocation ownership follow-up, 2026-11-02

`90c3b01e6` fixes discovery documents created while a temporary caller arena is
entered. Their Document identity, URL and font-policy metadata now use
persistent storage. Parsing and style discovery explicitly enter the discovery
document's independent payload arena, and exported resource URL vectors and
strings escape both that document and a temporary caller. The previous ordinary
storage entry preserved an already-entered caller, which let asynchronous
preload state retain temporary allocations.

The new `main_preload_identity_storage_test.v` first fails because the Document
itself belongs to the caller arena. After correcting document ownership, its
second case exposes the separately retained URL vector in the caller arena.
Both cases now release the caller before using the retained state and pass.
The existing preload-storage and navigation-input-storage tests also pass:
five functions in each of default, no-GC and preallocated modes. All required
source hashes stay unchanged during these final checks. The preallocated run
uses the same patched runtime preparation as production with the compiler from
PATH. An earlier attempt selected a different V checkout that rejected the
repository's existing `uint` usage; it executed no tests and earns no credit.

Private evidence is in `Build/chatgpt-rapid-cleanup-20261102/`, including
`preload-owner-before/`, `preload-owner-after-identity/`,
`preload-owner-verified/` and `preload-regressions/`.

The available production executable at the start of this follow-up is
`f769e44dbef6c5c309654f532cadf36bc7d5288a4b99c9f4a03f40845649be49`.
`baseline-burst-1/` reproduces Voice activation and the disposal crash on that
identity with exit 139 and unchanged inputs. Separate fault-recorder runs
catch an earlier map insertion fault and a CSS-source serialization fault
during navigation. These instrumented failures are diagnostic evidence rather
than pixel or performance acceptance; they do not prove that the preload fix
repairs every observed fault.

The fresh Brave capture with debugger auto-attachment fails readiness within
two minutes. Removing that debugger attachment in `brave-fresh-home-2/` reaches
the real homepage-ready marker with no runtime exceptions. Its homepage PNG is
byte-identical to the retained reference, with zero differing pixels. The first
failure remains retained and is not attributed to service compatibility. The
fresh homepage and its unmodified static responses are retained for subsequent
native checks, with missing immutable worker assets supplied from the earlier
archive and every body hash verified.

The corrected standalone HTML-link fixture in `css-root-diagnostic-3/` also
parses and retires the saved 1,897,153-byte Voice stylesheet, retaining 699
top-level rules and exiting 0 under its 3 GiB runtime guard. It does not
reproduce the native navigation fault. The earlier standalone attempts fail
at harness setup: one uses an invalid method name, and one constructs an
inappropriate element before an unsafe link cast. They receive no parser
acceptance credit.

Browser validation of `90c3b01e6` remains pending. Multiple shared production
builds complete compilation and smoke checks but are superseded by concurrent
compiled-source edits, including receipts `20261102-135944-54a55bfc`,
`20261102-140543-e157c03b` and `20261102-141127-73cb4598`. The canonical completed
bundle still has the older `f769e44d…` identity. No duplicate build or copied
bundle is used, and that older executable cannot validate the ownership fix.
`validation-assessment.json` records the exact before/after checks and pending
status; prepared native checks are `run_candidate_burst_1.py` and
`run_candidate_typing_1.py`. No browser-crash resolution or additional native
pixel-parity result is claimed for this source fix yet.


## CSS diagnostic map lifetime and refreshed live state, 2026-11-02

The preload ownership fix is present in production executable
`208875f192d26570965f87aa88c6f5b31a57f3204793380697a15bf608bd3a96`.
`Build/chatgpt-rapid-cleanup-20261102/candidate-burst-1/` still reproduces
Voice activation and exit 139 on that executable with unchanged inputs. Its
faulting stack reaches `ErrorReporter.report()` while parsing the destination
stylesheet, before normal disposal. The earlier preload fix alone therefore
does not resolve the rapid-input failure.

`17c3576e0` corrects a separate shared CSS diagnostic lifetime bug. Updating
an existing diagnostic can grow and rehash V's map before finding the key.
That update previously ran outside persistent storage, allowing global map
metadata to enter a temporary stylesheet arena. Both insertion and repeated
updates now enter persistent storage. The regression exercises every map size
from 1 through 128, repeats reports in temporary storage, resets and overwrites
that storage, and then verifies every retained occurrence count. The original
code fails with an occurrence count of zero instead of two. Earlier probes
with sparse sizes or without overwriting retired storage pass and are retained
as insufficient reproducers.

The corrected regression and existing diagnostic and stylesheet-workspace
checks pass all 30 test-function executions across default, no-GC and patched
production-preallocated modes; all 18 compile/runtime steps exit zero and the
focused source hashes remain stable. Private evidence is in
`Build/chatgpt-css-error-lifetime-20261102/`, particularly `before-reuse/`,
`focused/results.json` and `focused/source-stable.json`. No native crash
resolution is inferred from those unit checks.

The later available production executable
`c8993aa08e74513dacc5fda3f384b9cd6eb2835eddc8f98cf315b4c39bd9c324`
precedes this CSS fix. Static disassembly confirms that its persistent-storage
entry still follows the existing-key lookup. Its `latest-typing-1/` native
capture does reach the live conversation with the exact prompt and reply,
empty native errors and JavaScript diagnostics, unchanged inputs and browser
exit zero. The frontend is unmodified archived HTML with cached static assets;
backend requests remain live through the local SOCKS proxy. Input uses native
per-character turns followed by Send. This success does not cover burst input
or validate the newer CSS code.

Fresh Brave runs `brave-fresh-1/` and `brave-settle-3/` also reach the real
homepage and live reply with no runtime exceptions. Their current page state
has a second disclaimer line and shifts the lower composer and cookie banner
relative to the retained reference. The long-settle control keeps the same
private session, disables the browser cache, waits 40 seconds after homepage
readiness and 45 seconds after the reply, and retains those bulk differences.
The original PNG references and comparison tolerances remain unchanged. This
new live-state comparison does not replace the old frozen-page acceptance.
`brave-settle-2/` fails at harness startup because a reused profile contains a
stale debugger endpoint; it supplies no content or rendering result. The next
run removes that stale endpoint before launching a fresh browser process.

Against the fresh short-settle Brave conversation, `latest-typing-1/` has
406 differing pixels; the long-settle comparison has 433. The copy/share SVG
buttons exist at the expected native layout coordinates but their icons are
missing from the PNG. These differences remain failures of exact rendering;
text-chat functionality does not establish current pixel parity. The prior
references, refreshed captures, failed attempts and raw comparisons remain
under the private evidence root. Current browser validation of `17c3576e0`
awaits a published shared bundle that actually contains it; superseded builds
are not validation of the installed executable.


`style-diagnostic-1/` and `style-diagnostic-2/` reach the live reply and render
both response icons on the same `c8993aa0…` executable. Their PNGs have
identical decoded pixels and differ from the fresh Brave conversation by
120 pixels around the cookie banner. The first read-only script cannot iterate
the facade's attributes; the second stops at rectangle serialization. These
instrumented captures are diagnostic observations, not uninstrumented
acceptance. `brave-style-4/` independently reaches the live reply and exactly
matches `brave-fresh-1/after.png`; the retained older references are unchanged.

`latest-typing-2/` and `latest-typing-4/` both preserve audited readiness and the
exact submitted prompt but show no assistant reply or conversation URL at the
110-second capture. Both browsers exit zero with stable identities and empty
reported errors; both content gates correctly fail. The latter uses refreshed
Brave cookies and the newer, hash-verified merged frontend. Thus freshness
alone does not establish reliable live chat. `latest-typing-3/` never launches
the browser because that merged archive initially lacks its required seal;
this harness failure remains retained separately. `style-diagnostic-3/` uses
direct rectangle fields, reaches the live reply and obtains visible computed
styles for the action buttons. Its pre-query snapshot reports zero queued
operations and 399 dirty facade records. A selector query can flush pending
facade state; these observations do not isolate the reason for the ordinary
capture failures or establish an asynchronous replay fix.

## Bounding rectangle binding follow-up, 2026-11-02

The style diagnostic exposes a separate concrete API gap:
`getBoundingClientRect()` returns a plain object even though the runtime already
implements `DOMRect` and `DOMRectReadOnly`. Calling the returned rectangle's
`toJSON()` fails. `1995e261f` returns fresh native-backed, mutable `DOMRect`
snapshots through both the shared and per-element geometry binding paths.
The binding captures the intrinsic constructor before author replacement and
preserves live native layout reads and receiver checks. This fixes the observed
API failure; it is not attributed as the cause of missing sprites or replies.

Both new regression functions fail before the fix: one rejects the rectangle
type, and one rejects the result after author replacement of the global
constructor. Afterwards all 30 focused test-function executions pass: four
client/bounding-rectangle cases and one descriptor case, each in shared and
per-element modes, across default, no-GC and patched production-preallocated
builds. The checks cover exact JSON fields, mutable independent snapshots,
subsequent layout changes, hidden/detached empty rectangles, SVG elements,
intrinsic constructor capture and illegal receivers. All 18 compile/runtime
steps exit zero and the focused inputs remain unchanged. Evidence is in
`bounding-rect-before/` and `bounding-rect-focused/` beneath the same private
root. Installed-browser validation awaits a shared production bundle containing
this commit. `current-assessment.json` indexes these checks, current captures,
failed attempts and the remaining live and pixel gates.


## Published production follow-up, 2026-11-02 evening

The shared supervisor publishes executable
`0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`
with compiled-input hash
`957400908dd63a5c454797fc199588b1d1496a8a51fc5b3dc8cada4159bc9778`.
The retained receipt is `production-0bb-identity.json`. Its verified source
identity includes `1995e261f`; the executable contains the intrinsic rectangle
factory. Static disassembly also verifies persistent-storage entry before the
CSS diagnostic map lookup. This supersedes the earlier pending-bundle status
for these source changes without rewriting their historical failed trials.

`production-burst-1/` reaches the exact live prompt/reply and conversation URL,
with no native errors or JavaScript diagnostics, a successful PNG, normal
shutdown, browser/guard exit zero and stable executable/input identities. Its
30 key events run in one native turn at 45 seconds, followed by the fixed
Send click one second later. The guard observes a peak of 2,885,025,792 bytes.
The Voice navigation and crash are not observed in this attempt.
`production-typing-1/` independently passes the same content, error, identity,
PNG and shutdown checks with per-character native turns. Both use unmodified
archived frontend/static assets and live backend traffic through SOCKS. These
are two recorded successful workflows, not a general guarantee covering the
retained earlier failures, every fresh challenge or other ChatGPT features.

Both document PNGs differ from `brave-style-4/after.png` by exactly 120 pixels,
all within `(272, 558, 1012, 684)` around the cookie banner. Both retain the
expected response icons. The original reference PNGs and tolerances remain
unchanged; current exact-pixel parity remains open. A separate layer trace
places the banner and a lower SVG button in the same native raster layer.
That is a diagnostic observation, not yet an isolated explanation or a fix.
The new `brave-cookie-5/` capture retains computed cookie geometry, a frozen
DOM and the available CDP layer observations for further reduction. A small
static fixed-banner control has 752 differing pixels, each with channel error
one; its absolute-position counterpart is exact. Moving the transparent fixed
container's top changes neither browser's fixed-banner PNG. Adding a separate
fixed SVG also leaves the banner pixels unchanged in both browsers. These
controls prevent treating an unverified flattening or layer-identity change
as a rendering repair. The first minimal Brave launch uses an incorrect
window position; the subsequent capture uses the display-selection helper's
position and is retained separately. The initial standalone plan probe reads
compatibility commands without paint metadata and is not a native layer-plan
check; its corrected probe records the display list before inspecting layers.


## Independent fixed-container raster coverage

The wider sibling-SVG control isolates an actual planner bug. Expanding the
transparent fixed SVG container from 40 to 740 pixels changes 71 banner pixels
in Vox, with maximum channel error 12, while Brave's banner remains exactly
unchanged. The visible SVG stays below the banner in both variants. Native
paint records show that the wider container's path merges into the banner's
layer, changing its multisample coverage. The control and raw images are in
`minimal-cookie-1/fixed-coverage-control.json` and the `wide-svg-*` outputs.
This is separate from the small control's pre-existing 752 one-channel-error
pixels against Brave.

`9cee866b6` adds the owning fixed container's identity to raster property state.
Sibling viewport-fixed containers retain independent raster coverage, while
ordinary descendants of the same fixed container can still share a picture.
Compositor boundary markers keep that same owner identity. The corrected
before regression fails because both sibling draws receive layer 1. An earlier
version of that regression incorrectly requires viewport-only paint metadata
from an unculled plan; that harness failure is retained separately and is not
the product regression.

All 105 focused test-function executions pass: two new fixed-owner functions,
23 existing layer-plan functions and ten paint-chunk metadata functions in
each of default, no-GC and patched production-preallocated modes. All 18
compile/runtime steps exit zero, and the focused source identities remain
stable. Evidence is in `fixed-raster-before-corrected/` and
`fixed-raster-focused/` under the private root.

The committed visual pair is
`Tests/Browser/Ref/fixed-sibling-raster.html` and
`Tests/Browser/Ref/fixed-sibling-raster.ref.html`. Its opaque white SVG paints
below the banner over the same white background, so the pair should be
pixel-identical. The older `0bb14e2f…` production bundle fails this invariant
by 71 pixels, with maximum channel error 12 and stable inputs; both actual
browser captures exit zero. `fixed-raster-visual-before/` retains those images,
commands and guards. Capture both documents at 1024 by 768 using the default
Chromium paint policy. The layout-test font selects LibWeb policy and bypasses
this planner, so the ordinary LibWeb screenshot mode cannot validate this
specific rendering regression. Browser validation of the new fixed-owner
source and its effect on the remaining 120 live-page pixels awaits a published
bundle containing `9cee866b6`. No existing pixel reference or tolerance changes.


## Hidden inherited SVG paint-resource guard

`conformance-0bb-1/` runs the unchanged eleven-case smoke set and ten SVG
mutation reftests against the pinned `0bb14e2f…` bundle. The smoke set passes
with its existing allowances, and nine SVG cases are exact. The hidden
paint-server inherited-style case fails by 10,000 pixels, so the combined
command and memory guard correctly record exit 1. It does not receive an
all-pass conformance claim. Browser/input identities remain unchanged.

The first two-second audit still has the initial red resource style and its
readiness class. `hidden-style-audit-10s/` allows the nested animation-frame
callbacks to finish: the class clears, the actual inline custom property is
green and reported errors are empty, but all 10,000 painted square pixels
remain red. This isolates a retained-resource failure beyond the early
capture's readiness issue. The expected reference and tolerances stay intact.

The new `layout/svg_hidden_paint_server_style_test.v` reproduces the stale
red gradient after a hidden ancestor's custom property changes through CSSOM.
Its `currentColor` control already passes. Existing retained recordings must
also keep their old colors after a later recording changes. The source fix
notifies SVG paint-resource descriptions when an existing computed style or
its custom-property data changes; an unrendered resource can affect a visible
referencing element even when its own subtree contributes no visible box.
The first six new-test executions pass across default, no-GC and production
preallocated modes. That initial batch then stops on an unrelated, transient
compile error in a new shared-checkout `layout/retained_simple_svg.v` file.
The writer replaces its mutable scalar parameter with a budget record; this
session leaves that work untouched. The failed compile is retained, and the
broader corrected-source verification is recorded separately in
`hidden-paint-style-verified/`. Native validation of this source fix remains
pending a bundle containing it.


`af634b414` commits that paint-resource invalidation fix with its focused
regressions. The corrected-source verification passes 54 test-function
executions across the three GC modes: two new hidden-resource cases, four
retained-gradient snapshot cases, two hidden HTML deferral cases and ten
unboxed CSSOM cases per mode. The 18 layout compile/runtime steps in
`hidden-paint-style-recovery/` exit zero with unchanged focused inputs. The six
actual-zero CSSOM steps are carried from `hidden-paint-style-verified/` after
checking the relevant CSS/DOM sources remain unchanged; `cssom-carryover.json`
records that disjoint carryover. Neither failed whole-batch attempt is called
a pass. The second attempt encounters another unrelated, untracked shared
file's optional-bounds compile error in `layout/css_svg_mask_geometry.v`;
its writer subsequently adds the missing unwrap. This session changes neither
of those concurrent feature files.

`b508a2fb4` also adds a fixed-owner regression through the viewport metadata
planner actually used by the browser. All three fixed-owner functions pass
in default, no-GC and production-preallocated modes with unchanged inputs;
`fixed-raster-viewport/` retains those six actual-zero compile/runtime steps.
The earlier 105-function-execution planner selection remains retained.

The latest completed bundle at this checkpoint remains `0bb14e2f…`. It
validates the two successful live Send workflows and exposes the retained
120-pixel live difference and hidden-resource guard failure. It cannot
validate `9cee866b6` or `af634b414`. The shared production supervisor is
building newer source; superseded receipts and the original failures remain
retained. Current live pixel parity and the corrected native SVG guard await
an executable that contains both rendering fixes. No duplicate production
build, copied bundle, changed reference PNG or relaxed tolerance is used.

## Fresh private-session refresh

`brave-fresh-6/` launches a new private Brave profile through
`socks5h://127.0.0.1:1337`, downloads the homepage once, verifies application
readiness and receives the exact live test reply. It records no runtime
exceptions. Executable and measurement-input identities remain stable
throughout the capture; browser/guard exit zero and the observed process-tree
peak is 1,324,990,464 bytes. All 394 newly captured response bodies pass their
hash and length checks.

The reply PNG is byte-identical to the retained `brave-style-4/after.png`, with
SHA-256 `742795448dec4df1c9076d8a2ee81e35ec3b57998c74d918a88b34775289fc7c`.
This refreshes session evidence without replacing the reference or changing a
tolerance. `fresh-merged-archive-6/` seals the fresh homepage/resources together
with previously captured immutable static/worker assets; all 611 response
bodies are verified. The prepared native check uses the fresh session cookies
and keeps subsequent backend requests live through SOCKS, without seeding
backend responses.

The shared build attempt `20261102-235354-342478ad` completes successfully but
is superseded because compiled inputs change during the build. The supervisor
starts `20261102-235949-39c3e18d`. The published bundle remains `0bb14e2f…` at
this refresh checkpoint. The pending fixed-container visual pair, audited
hidden-resource repaint check and live Send comparison explicitly pin the
candidate executable, so the older bundle cannot stand in for validation of
the new rendering fixes.

## Fractional shadow color in recorded pictures

`f447b8603` fixes another generic paint discrepancy exposed by the reduced
banner. The leaf renderer accepts fractional sRGB shadow components, while
the recorded compositor/decoration path converts them to a byte color before
recording. A five-percent black shadow therefore loses precision only when
its contents become eligible for a complete picture. Recorded shadows now
retain their supplied floating components, and legacy byte colors keep their
existing path.

The new `tools/native_skia_shadow_recording_color_test.cpp` compares the native
bridge with independently recorded GPU pictures at scales one and two. Before
the fix, all four legacy-color controls are exact and the four fractional
cases differ by 90, 130, 354 and 732 pixels. Afterwards all eight are exact.
The existing shadow-layer checks pass 72 exact comparisons, including root
controls against the published native library. All twelve outer-shadow group
cases also pass. Compiler and runtime commands/guards are retained in
`shadow-recording-color-before/` and `shadow-recording-color-after/` beneath
the same private evidence root.

The initial broad source fingerprint detects a concurrent change to
`native_browser_tab_titles_test_darwin.h`. The compiler dependency list proves
that header is not used by these tests. `dependency-seal.json` verifies the
actual renderer inputs remain unchanged; `related-results.json` retains the
original broad-fingerprint failure rather than relabeling it as a pass.
Native library identities remain unchanged. Only the shadow-color hunk and
its regression are committed; the unrelated pending native include is left
with its owner's work.

`banner-native-probe-1/` retains the diagnostic reductions, including the first
failed link without Skia's required `-fno-rtti` and an initial unsnapped-geometry
model. The corrected geometry follows the browser's recorded integer paint
bounds rather than the fractional DOM rectangle. Independent shadow/border
toggles isolate the precision change to shadow color. This probe still differs
from the actual browser reduction, so it supplies no live-page pixel gain or
whole-page acceptance claim. The last tested production ChatGPT result remains
120 differing pixels until a published bundle containing the rendering fixes
is captured against the unchanged Brave reference.

## Exact reduced-banner check

`banner-arguments-3/` observes the actual old production paint calls with a
native probe. It verifies probe loading, normal browser/guard exit, stable
binary/library/fixture identities and a screenshot identical to the retained
old native reduction. The shadow cutout is `(273, 559, 738, 124)` with radius
29, one CSS pixel inside the opaque border box. The earlier model used the
outer border box instead; that modeling error accounts for its unexplained
corner pixels and does not require a layout change.

With this corrected cutout, `banner-native-probe-1/actual-clip/` reproduces the
old native PNG exactly using the legacy byte shadow color, retaining all 752
differences from Brave. With fractional shadow color and the committed
recording fix, the same reduced native scene matches Brave exactly: zero
differing pixels and zero channel error. Separate border-color toggles leave
those results unchanged. The complete source fingerprint stays stable during
this check. This establishes reduced-banner parity through the native
renderer; it does not substitute for the pending full ChatGPT capture.

The failed diagnostic attempts are retained. `banner-arguments-1/` provides
no probe-loading or intercepted-call evidence. The environment-preserving
launcher in `banner-arguments-2/` verifies loading, but its `RTLD_NEXT`
forwarding attempt ends with signal 10 and no PNG.
The successful third probe forwards through the original imported C symbol.
Neither of the preceding attempts supplies paint-parameter evidence.

The durable browser regression is
`Tests/Browser/Brave/input/chromium-fractional-fixed-shadow.html`, its expected
PNG and `tools/fixed_shadow_pixels_test.py`. Two fresh Brave processes agree
exactly with each other and the original reduced reference at 1024×768, scale
1; identities and inputs remain stable. `fixed-shadow-reference-1/` retains
both commands, guards and metadata. The expected PNG hash is
`f418d4562fe9690651e10559d9e21defb58cb4db1ff017565d81d544070e69e6`.
`fixed-shadow-browser-before/` runs the new test against `0bb14e2f…` and
correctly records exit 1 with 752 differing pixels, maximum channel error one
and unchanged fixture inputs. Its native artifacts are in
`Build/forum-news-inline-1pkx6ng2/`. No existing reference or tolerance changes.

The shared supervisor continues building newer source. Its completed attempts
are superseded when compiled inputs change, so the published browser still
cannot validate the pending fixed-owner, hidden-SVG and shadow-color fixes.
The last tested full ChatGPT result remains the older bundle's 120 differing
pixels. Full-page pixel parity remains open.

## Test-only production-build invalidation

`f5651c585` fixes an unnecessary rebuild trigger found while waiting for the
integrated pixel checks. The supervisor previously treated screenshot fixtures,
V test files and standalone test drivers as production build inputs. Editing
one could supersede a successfully compiled browser despite changing no input
consumed by that build. This is an additional trigger; genuine runtime-source
changes still require a new build.

The production fingerprint now excludes `Tests/`, V's `_test.v` files and
standalone Python/C-family test drivers under `tools/`. The complete repository
receipt continues hashing them. Runtime sources, native headers (including
headers whose names mention tests), packaged resources, worker entry points and
build helpers remain production inputs. Visual-check fixture/reference hashes
are separate measurement inputs and still require verification.

All thirteen build-manager tests pass. The retained old-policy check fails
eight test-only mutation/addition cases; runtime-source/header/helper/resource
controls continue invalidating builds. A publication test edits a reference
during compilation and verifies one successful build, changed full repository
receipts and unchanged production inputs. Evidence is retained in
`build-input-filter-1/` beneath the private root. The active supervisor loaded
the earlier code; a new supervisor process will use the corrected filter.
The existing build continues under its memory guard.

`current-painter-recheck-1/` also recompiles the native shadow regression and
the corrected banner reduction after the shared painter headers change. All
eight GPU comparisons and both fractional-color banner controls remain exact,
with unchanged actual source/library inputs and zero compiler/runtime exits.
The published bundle still predates the rendering fixes, so the full-page and
installed-browser SVG gates remain pending.

## Published production validation and the newer bubble edge

The frozen-input production pipeline publishes executable SHA-256
`1bcbbb5cca048906caf2151070018fb7ec0618b5af140b465700ba31a9cd1d75`
with receipt `Build/production-build/receipts/20261103-011139-5e6ed988/`.
Its verified inputs contain `9cee866b6`, `af634b414` and `f447b8603`.
The preceding superseded attempts are retained. Later shared source edits do
not invalidate the sealed compiler inputs recorded by this receipt.

Evidence below is in `Build/chatgpt-css-error-lifetime-20261102/`:

- `production-1bc-typing-7/`: fresh native process, audited application
  readiness, separate native typing events and Send after one second. It
  observes the exact prompt and live reply, a conversation URL, no JavaScript
  diagnostics and no native reported errors. Browser and memory guard exit
  zero; executable, native libraries and measurement inputs remain stable.
  Sampled process-tree peak RSS is 2,969,583,616 bytes.
- `retained-pixels.json` in that directory: zero differing pixels against
  unchanged `brave-style-4/after.png`, SHA-256
  `742795448dec4df1c9076d8a2ee81e35ec3b57998c74d918a88b34775289fc7c`.
  `pixels.json` records 27 differing pixels against `brave-fresh-7/after.png`,
  SHA-256 `1b35a7492c394330fe9740c93304176c3160d5c77a338df5fd4b7a4e048e608c`.
  Their bounding box is `(765, 80, 1005, 121)` and maximum channel error is two.
- `fixed-raster-visual-1bc-1/`: the fixed-container regression improves from
  71 differing pixels on the old bundle to zero, with stable inputs/identities.
- `hidden-style-1bc-1/`: the inherited SVG paint-resource update improves
  from 10,000 differing pixels to zero. The ten-second capture separately
  verifies application readiness, the changed resource style and empty errors;
  the earlier shorter capture failures remain retained.
- `conformance-1bc-1/`: all eleven standard screenshot smoke cases pass their
  existing checks, and all nine remaining image-source/SVG paint-server
  mutation reftests are pixel-exact. Together with the separately audited
  inherited-style case, all ten SVG checks pass. No references change.
- `fixed-shadow-browser-current-1/`: the permanent fixed-picture shadow test
  passes on executable `f8618e0dd1854b53833106b154f9354dab0646d2e30069302a1c83163da33b60`.
  The old bundle's 752 differing pixels become zero. Browser/test and outer
  guard exit zero; fixture/reference hashes and bundle inputs remain stable.
  The earlier `fixed-shadow-browser-1bc-1/` attempt fails its identity
  precondition before launching a browser and receives no validation credit.

`brave-fresh-7/` captures 395 responses through SOCKS and verifies every retained
body's hash and length. Its two root document requests are recorded; this
session is not described as a single homepage download. The merged archive
retains 611 verified original responses. `brave-replay-8/` uses that same
archived homepage/static policy with live backend routing and reproduces the
newer reference byte for byte. Both normal and replayed Brave runs reach the
exact reply without runtime exceptions and retain stable identities/inputs.
The older single-download fresh-session evidence remains unchanged.

`production-bubble-diagnostic-1/` repeats native send/reply on executable
`9cd7a4070b1721ba7a3ce41772dd35102b5b913aa1fab6990dc03af0a0169d6a`.
It again matches the retained reference exactly and has the same 27 newer
edge differences. Read-only style inspection leaves its PNG unchanged.
The bubble's computed geometry, color and radius agree between browsers.
Brave controls in `brave-bubble-10/` explicitly assigning the computed RGB
background and removing overflow clipping also leave the newer PNG unchanged.

The reductions in `bubble-reduction-1/` through `bubble-reduction-4/` preserve
all attempts, including the first model's incorrect white backdrop. Corrected
sticky/grid geometry with the actual offscreen root width is pixel-exact in
both browsers and reproduces the retained bubble edge. Invisible fixed and
ordinary sidebar SVG controls also remain exact. These controls do not
establish a renderer fix for the newer full-page edge; no speculative paint
policy change is credited. Full current-session parity and broader ChatGPT
feature coverage remain open.

## Live sticky coordinates and complete message pictures

`b8bb7b560` fixes a generic coordinate-space error exposed by
`bubble-reduction-6/`. The retained box transform omits the live sticky offset,
while its paint command and viewport clip include it. The old planner therefore
clips a visible SVG against untranslated bounds and chooses the message
picture's origin before the sticky translation. The reduction reproduces the
same 27 rounded-edge differences as the newer full-page reference.

Sticky ink and its container now use the live scroll-property coordinate space.
Compatible sparse descendants of the same promoted sticky container retain one
picture, while intervening overlap barriers and distinct property states still
separate pictures. The new focused tests pass in all three GC modes; the
existing raster-layer, fixed-owner, paint-metadata and partial-sticky-bound
checks also pass. `sticky-raster-focused-3/` and `sticky-raster-bounds-guard/`
retain the commands and stable inputs. The first test attempts are preserved:
one selected a serialized color incorrectly, and the next exposed the separate
sparse-picture issue before its fix.

The durable regression is `chromium-sticky-raster-space`, with
`tools/sticky_raster_pixels_test.py`. Two fresh Brave captures agree exactly.
The old production bundle has 27 differing pixels. The first installed fix
reduces that to two, still failing the strict gate; both attempts remain in
`sticky-raster-browser-before/` and `sticky-raster-browser-after/`.

## Layer-local rounded geometry

`fd12fa62a` removes the final two reduced-scene differences. Recorded rounded
rectangles previously subtracted the compositor origin from untranslated
layout coordinates while leaving an integral sticky translation in their
matrix. The result has the correct mathematical device position but the wrong
local geometry for GPU edge rounding. Translation-only integral offsets now
enter the rectangle and its underlay before the layer origin is subtracted;
the matrix retains the page offset. Fractional and non-translation matrices
keep their existing path.

`bubble-geometry-1/` verifies that this equivalent representation alone makes
the reduced browser scene exact. Separate raster-height and floating-color
controls leave the two differences unchanged. The native regression compares
equivalent translations in multisampled vector pictures at scales one and two,
with underlays and root controls. Three cases fail on the old installed native
library; all eight cases are exact after the fix. Its first compile failure
and earlier control lacking a nonconvex path remain retained in
`sticky-rrect-native-1/` and `sticky-rrect-native-2/`; the effective regression
is `sticky-rrect-native-3/`.

The related rounded-parts, underlay-color and shadow-color checks pass, including
864 rounded GPU comparisons and all existing typed-color/reset controls.
`sticky-rrect-dependencies-2/` verifies 183 actual compiler dependencies and
runtime inputs remain unchanged across the four native test binaries. The
preceding dependency run detects a concurrent edit to
`native_solid_svg_polygons.h` and is retained as unstable. Only the rounded
geometry hunk is committed from the shared native source file; the unrelated
SVG optimization remains with its owner.

The installed executable
`107814245c9defc216e452388949a272894fd5a1b84ef4b8e53531ec7fcdb12f`
passes the strict browser regression with zero differing pixels.
`sticky-raster-browser-final/` pins its executable/native resources and the
unchanged Brave fixture/reference. `conformance-final-painter-1/` passes all
eleven existing smoke cases and all nine image/SVG mutation reftests with
stable inputs and identities. No reference or tolerance changes.

## System Reduce Motion

`07169af78` connects macOS's native Reduce Motion preference to the owning
Page, Document, CSS media evaluation and window media queries. It reuses the
PageClient's existing motion preference and invalidates attached style/media
state only when the preference changes. Detached documents retain their
no-preference default. The native addition reads the operating-system setting;
application UI policy remains in V.

The host has Reduce Motion enabled. Brave consequently suppresses ChatGPT's
message-row animation, while the earlier native capture retains its identity
transform. `reduced-motion-browser-before/` proves the mismatch in both the
script query and computed CSS color, with empty errors and 786,432 differing
pixels. `reduced-motion-browser-after/` records matching true queries, matching
CSS and zero differing pixels on both native and Brave. Inputs and executable
identities remain stable.

The new Page/media tests pass in default, no-GC and production prealloc modes.
The existing reduced-transparency checks still pass, and the native integration
test agrees with both NSWorkspace accessibility preferences.
`reduced-motion-focused/` and `reduced-motion-native/` retain the guarded checks.

## Fresh session 14 and clean native session 16

`brave-fresh-14/` starts a new private Brave session through SOCKS. It downloads
the homepage once, verifies all 410 captured response bodies and receives the
exact live reply without runtime exceptions. The merged archive has 618
verified original responses. Its PNG is byte-identical to the retained
`74279544…` reference. The additional replayed `brave-frozen-15/` conversation
produces the other retained rounded-edge pattern, differing by 27 pixels.
Normal captures of the same frontend can therefore produce both edge patterns;
neither reference has been replaced.

`production-current-typing-7/` retains a native attempt whose bundle changes
and whose backend returns unusual activity. `production-motion-typing-14/`
fails before browser launch because the prepared merged manifest lacks its
seal; that preparation error is corrected and retained. The next attempt,
`production-motion-typing-14-2/`, has stable identities and empty native/script
errors but receives the same unusual-activity application response. These
attempts import the captured Brave cookies and receive no functional credit.

`brave-clean-16/` and `production-clean-16/` instead start with empty cookie
jars against the same original session-14 homepage/static resources. Both
receive the exact live reply. The native check verifies readiness before
separate character input and Send after one second, reaches a conversation URL,
and records empty native/script errors, normal browser/guard exits and stable
inputs/identities. Its sampled process-tree RSS peak is 2,700,574,720 bytes.
Backend responses remain live through SOCKS and are never seeded into the
native resource cache. Cross-browser cookie import is unnecessary for this
successful native session.

The native live PNG has 161 differing pixels against the matched clean Brave
control, maximum channel error two: 76 in the user bubble and 85 in the reply
text. This remains a failing live pixel result. The read-only runtime/layer
diagnostic is separate from this uninstrumented acceptance attempt.

`brave-frozen-15/frozen.html` preserves the actual post-conversation DOM while
removing scripts. `frozen-conversation-15-final/` renders it in the installed
native browser against the same static resources, with no forwarding. It
matches the captured live Brave document exactly: zero differing pixels and
zero channel error, correct prompt/reply content, empty error collections and
stable inputs/identities. This establishes full frozen-page rendering parity;
it does not replace the live scripted pixel gate. The capture helper's inherited
session-number label is corrected in `brave-frozen-15/route-provenance-note.json`;
the route receipt and pinned inputs identify session 14 without changing bytes.

## Remaining live layout capability gates

`production-bubble-diagnostic-2/` repeats the successful native conversation
from an empty initial cookie jar. Its read-only style query leaves the same
161-pixel difference. The query confirms reduced motion is true and the message
row has no animation or transform; the earlier animation-state hypothesis is
therefore not the remaining cause. The helper's inherited cookie label is
corrected in `cookie-provenance-note.json`; its pinned source constructs an
empty initial jar.

The native application selects ChatGPT's fallback shell. Its offscreen root
and grid are 1024 pixels wide; Brave's scroll-driven shell is 1224 pixels wide.
Both still place the visible main box at `(260, 61)` with width 764.
`capability-browser-1/` compares actual browser queries: both parse
`animation-timeline: scroll(root inline)`, but Vox rejects
`animation-range: 0px 50vw` and lacks Document/Element `onscrollend` properties.
Brave exposes all three. The original application combines the range query and
Document property check when choosing the shell, explaining the different
classes and compositor structure.

`brave-fallback-17/` is a causal diagnostic: it makes only Brave's script-level
animation-range feature query return false before loading the unchanged
frontend. The live reply still succeeds, and its root becomes 1024 pixels
wide. This reduces its difference from the native live image to 37 pixels,
while it differs from ordinary Brave at 174 pixels. It supplies no acceptance
credit and replaces no reference. The unchanged ordinary live gate remains
161 differing pixels.

Further work requires the missing CSS range and DOM handler bindings, with
actual parsing/storage and event behavior. Source resolution and active
scroll-animation ranges remain incomplete in the translated runtime; a positive
feature probe alone cannot establish those behaviors. The current frozen and
reduced-scene exact results remain distinct from full live parity.

## Native Document and Element scroll-end handlers

`5f0ab980a` connects Document and HTML/SVG/MathML `onscrollend` accessors to
the actual native EventTarget handler slots. Detached documents retain separate
owners. Element listeners and raw content handlers use the same native event
queue, including handler replacement, equal-text attribute writes, removal,
callback identity and receiver checks. This does not change CSS feature queries.

The three focused tests pass in default, no-GC and patched production prealloc
modes. Existing compact Document, native wheel-owner, raw wheel-owner and
browserjs wheel-handler tests also pass. `scrollend-focused-final/`,
`scrollend-focused-recovery-2/`, `scrollend-regressions-2/` and
`scrollend-regressions-recovery-2/` retain commands and guarded results. Earlier
compile failures from concurrent retained-layout work remain in the preceding
recovery directories; they are not counted as passes.

`scrollend-native-visual-4/` verifies actual programmatic scrolling in fresh
native and Brave processes. The element reaches offset 20, the root reaches
offset 30, and both native handlers receive their correct target, receiver and
bubbling flag. The page turns green and matches Brave and its unchanged green
reference at zero differing pixels. Native errors are empty, all browser/guard
exits are zero, and inputs/executables remain stable. The native executable is
`d9ac8f02…`. The committed input and reference are
`Tests/Browser/Ref/scrollend-native-handlers{,.ref}.html`.

Earlier visual attempts are retained: attempt 1 used a comparison path that
did not recognize repository-local reftests; attempts 2 and 3 called the
separately unsupported JavaScript `window.scrollTo` method. Attempt 3's audit
already showed the element handler firing. Attempt 4 uses the existing native
root-element scrolling API and verifies both handlers. No reference or pixel
tolerance changed.

`conformance-scrollend-1/` passes the eleven screenshot smoke cases and all
nine SVG/image mutation guards, including same-size image-source replacement
and paint-resource lookup/invalidation. Every SVG comparison is pixel-exact;
input and executable identities remain stable.

Document and Element scroll-end exposure now agree with Brave. CSS
`animation-range` parsing and active scroll-timeline source/range sampling
remain incomplete, so ChatGPT still selects its fallback shell. The last valid
full live pixel result remains 161 differing pixels with maximum channel error
two; the exact scroll-handler fixture does not establish full ChatGPT parity.

`production-scrollend-clean-18/` repeats the live conversation on executable
`ea0fd8ca…`, using the unchanged session-14 original frontend/static archive,
an empty initial native cookie jar and the live backend through SOCKS. Readiness,
prompt, exact reply and conversation URL checks pass; native/script errors are
empty. Browser/guard exits are zero, inputs/executables remain stable, and the
sampled process-tree RSS peak is 2,743,484,416 bytes. The live screenshot still
differs at 161 pixels with maximum channel error two against the session-14
Brave image and retained `74279544…` reference. Backend responses are not seeded
into the cache.

The standard comparison command now recognizes repository-local browser
reftests as well as upstream reftests:

```sh
SCREENSHOT_REUSE_PRODUCTION=1 VOX_CAPTURE_DOCUMENT_ACTIVE=1 \
  ./compare_screenshots.sh Tests/Browser/Ref/scrollend-native-handlers.html
```

Run it through the required memory guard. `scrollend-canonical-reftest-1/`
retains a successful invocation on `ea0fd8ca…`: zero differing pixels, normal
guard/browser exits and stable input/executable identities.

## CSS attachment ranges and anonymous scroll clocks

`3a68a1719` implements `animation-range`, `animation-range-start` and
`animation-range-end` parsing, declaration expansion and reconstruction,
coordinated lists, named range defaults, calculated lengths and computed
viewport units. The `animation` shorthand resets the two range longhands;
non-initial reset-only values prevent shorthand serialization. New generated
metadata is merged without removing earlier translation compatibility entries.
The existing generator has unrelated drift, retained in `range-metadata-merge-1/`.

The four range tests pass in default, no-GC and patched production prealloc
modes with stable source hashes (`range-focused-final/`). Existing scroll-clock,
text-box, backface, color-interpolation and font-synthesis checks pass in the
guarded regression/recovery directories. `range-regressions-1/` retains the
broader metadata suite's opacity extrapolation failure: it returns `1.4` where
the test expects `1`. `range-metadata-baseline-1/` reproduces the identical
failure with the attachment-range changes temporarily removed from the
canonical source, then restores those changes. That broader suite is not
reported as passing. Intermediate compile failures caused by concurrent
device-layout edits are retained as well.

`5ede19adf` resolves anonymous `scroll(root|nearest|self <axis>)` clocks from
the native retained scroll boxes. Sampling reads committed layout without
recursively requesting layout. It handles physical/logical axes, reverse
origins, inactive or removed sources, and length/percentage/calc attachment
ranges. Finite range length supplies the iteration duration; wall-clock time
does not advance these animations. Active auto-duration effects retain their
compositor property identity. Named view ranges and named timeline lookup
remain separate incomplete runtime features.

The six real-layout scroll-clock tests pass in default, no-GC and patched
production prealloc modes (`scroll-source-focused-final/`). They cover root,
nearest and self sources, reverse scrolling, RTL, calculated ranges,
auto-duration compositor identity, zero overflow and removed targets. Existing
scroll sampling, compositor identity and animation invalidation tests pass in
`scroll-source-regressions-1/`; the recorded source hashes remain stable.

`e0af4f9b2` adds explicit horizontal scroll positions to the Brave capture tool,
including RTL negative offsets and observed-position validation. Its thirteen
tests pass under the memory guard. The first scene comparison exposed the
tool's prior unconditional horizontal reset to zero; that result is retained
in `scroll-source-browser-1/`. Attempt 2 requests the not-yet-implemented CLI
flag, and attempt 3 captures Brave at the correct offset while the older Vox
bundle still leaves the animation at its initial position. These attempts
receive no parity credit.

`scroll-source-browser-4/` launches fresh native and Brave processes at matching
800 by 600 document viewports and horizontal offset 200. The native executable
`759a9af0…` and Brave both render the root-inline, auto-duration, viewport-range
translation exactly like the static reference: zero differing pixels and zero
channel error. Native errors are empty, all exits are zero and input/executable
identities remain stable. `range-oracle-native-1/` compares 36 actual CSSOM
specified/computed declaration cases with `range-oracle-brave-2/`; every value
matches and both error collections are empty. These are focused browser checks,
not a replacement for the full live ChatGPT pixel comparison.

## Native scrolling methods in the compact JavaScript facade

`ebe8fa1a6` exposes `scroll`, `scrollTo` and `scrollBy` on Window and Element,
delegating to the existing native CSSOM View algorithms. The original modern
ChatGPT sidebar module calls `window.scrollTo`; enabling its layout without
this binding would leave a runtime gap. The bindings preserve omitted axes,
normalize non-finite offsets, flush queued styles before scrolling, validate
receivers before argument conversion and convert dictionary members in WebIDL
order. Root/body forwarding now preserves explicit instant/smooth behavior
instead of replacing it with auto. A subsequent direct Brave audit finds that
the comparison browser returns Promises for all six methods; receiver and
conversion failures reject rather than throw. The initial offset bindings'
undefined return therefore requires a native completion-Promise bridge.

Both focused tests pass in default, no-GC and patched production prealloc modes
with stable source hashes (`scroll-methods-focused-2/`). Existing compact scroll
metrics/timer, compact Document and native smooth-scroll/promise tests all pass
in `scroll-methods-regressions-1/`. The first compile attempt runs out of disk
space while writing Clang objects; it is retained in `scroll-methods-focused-1/`.
Space recovers before the successful retry. No authored files or historical
capture evidence are removed.

`capability-range-1/` confirms that Vox and Brave now both accept the exact
timeline/range queries used by the frontend and expose all three scroll-end
properties. Both report reduced motion, select the same green media-query
style and render that probe at zero differing pixels, with empty errors and
stable inputs/executables. The installed root-inline animation scene already
matches Brave; the updated regression inputs additionally use the new Window
and Element methods so their production integration can be checked together.


## Scroll completion values and keyframe variable substitution

`953aa85eb` connects all six compact scrolling methods to their actual native
scroll-operation Promises. A completed call fulfills with the ordinary object
`{interrupted:false}`. Replacement and owner teardown fulfill the displaced
operation with `{interrupted:true}`; reusing the same destination preserves the
geometry animation while interrupting the prior invocation. Receiver and
conversion failures reject with the original JavaScript value. The binding
uses the owning realm's WebIDL capability and microtask path. It does not
substitute a timer or an immediately fulfilled Promise for smooth completion.

The four compact API cases pass in default, no-GC and patched production
prealloc modes, with unchanged source hashes (`scroll-promises-focused-final/`).
They cover native offsets, IDL conversion/rejection identity, delayed smooth
completion and interruption. `scroll-promises-native-1/` passes the native
operation regression with actual microtask checkpoints. Earlier compile and
runtime failures remain retained in the numbered Promise diagnostic directories.
The final correction routes the native operation key as a raw query result;
otherwise it incorrectly enters the DOM element facade lookup.

`scroll-promises-oracle-native-1/` exercises a fresh production process on
executable `86688ea5…`. All six specified API results exactly match the direct
Brave audit in `scroll-methods-brave-oracle-3/`, including function metadata,
Promise branding, fulfillment object and invalid receivers. Native/script
errors are empty, browser/guard exits are zero and identities/inputs are stable.

Enabling real attachment ranges also enables the modern sidebar layout. The
live workflow in `production-range-scroll-19/` still reaches the exact reply
with no native or script errors, but differs at **143,784 pixels**, maximum
channel error 242. `frozen-range-scroll-1/` reproduces the identical error with
scripts removed and all static resources replayed. Animated width and logical
inset contain unresolved `var()` expressions, leaving the main box at its auto
width instead of the requested viewport-minus-sidebar width. This supersedes
the earlier fallback-shell 161-pixel result as the active layout diagnosis.

`a22f9f7f1` substitutes the target's custom properties before computing sampled
keyframe values, then maps logical properties to their physical axes. It
preserves the immutable specified keyframes. Its focused test passes in all
three memory modes (`keyframe-vars-focused-2/`), and three existing animation
storage/dependency checks pass (`keyframe-vars-regressions-1/`). The permanent
`scroll-driven-keyframe-substitution` browser reftest matches the static
reference in both Vox and Brave at zero differing pixels, with stable identities
and empty errors (`keyframe-vars-browser-1/`).

`frozen-keyframe-vars-1/` restores the sidebar geometry but retains 21,483 text
pixel differences on executable `5775fb14…`. Its sealed compiler input contains
a transient shared glyph-copy flag collision: `32 | 64` sets the existing
synthetic-italic bit. The simple normal/bold/italic probe reproduces the error
while computed CSS still reports normal. Disabling the file-font manager does
not fix it. These failed diagnostics remain preserved. The next shared build
contains the corrected `32 | 256`; this investigation adds no separate font-fix
commit or optimization credit.

`frozen-keyframe-vars-2/` repeats the original frozen conversation on executable
`86688ea5bc02f03050ee70997f07d8ecc1f4c33af08e1c4acf7024bdd2085bf4`,
receipt `Build/production-build/receipts/20261103-053009-1922e187/`. It matches
unchanged `brave-frozen-15/after.png` **pixel-for-pixel**, with zero channel error,
normal browser/guard exits, stable executable/native-library/input identities,
and empty native/script errors. This is a frozen-page result; live functionality
and current reference parity require their separate checks.


## Fresh session and native Promise reaction context

`production-keyframe-scroll-20/` loads, reaches audited readiness and submits the
prompt without script/native errors on `86688ea5…`, but the service responds
with unusual activity. Browser/guard exits are zero and inputs/identities stay
stable; the reply and conversation-URL checks fail. This failed live run
receives no rendering or functional acceptance credit.

The authorized refresh in `brave-fresh-21/` uses a fresh empty Brave profile
through SOCKS, downloads the homepage **once**, captures 402 responses, and
receives the exact reply without runtime exceptions. Its PNG is byte-identical
to retained `brave-frozen-15/after.png` (`1b35a749…`). The verified merged archive
contains 825 original responses; the session-21 entries take precedence over
older immutable resources. Earlier references remain untouched. Native replay
continues to exclude all backend response seeding and starts with no cookies.

`production-fresh-21/` fails archive validation before launching: its merge
manifest initially omits the sealing timestamp. The corrected manifest is used
by `production-fresh-21-b/`, which exits 1 during startup on `86688ea5…` at the
HTML current-principal-realm assertion. This is an engine failure rather than
another service rejection. No visual or workflow acceptance is claimed for it.

The retained debugger attempts culminate in `fresh-context-trace-3/` on
`dc6b9b95…`. A network completion resolves a JSC Promise through
`Runtime.call_engine_function`; JSC drains Promise reactions inside
`JSObjectCallAsFunction` while the HTML execution-context stack is empty. The
reaction calls `URL.createObjectURL`, whose actual native Blob URL algorithm
requires the current settings object. This directly explains the assertion.
The earlier debugger attempts stop at process exec or miss the panic symbol;
they provide no successful stack-trace evidence.


`f094236f3` keeps the owning HTML script realm active across the actual JSC
function call, including its internal Promise-reaction drain and exceptional
return. The focused regression settles both fulfilled and rejected Promises
from native code while no outer script is active. Their reactions create and
revoke real Blob URLs, observe the correct current settings and active VM
context, and defer queued HTML microtasks until the engine call returns. The
realm and VM are empty after each operation. The test passes in default,
no-GC and patched production prealloc modes with stable sources
(`promise-realm-focused-1/`). The sealed production function is retained in
`promise-realm-production-source.json`; installed-browser validation is tracked
separately from this source proof.


All thirteen existing cases in `script_environment_binding_test`,
`url_object_blob_host_test` and `main_compact_scroll_methods_test` also pass with
this fix and stable sources (`promise-realm-regressions-1/`). They preserve
cross-realm ownership, Blob URL store/revocation behavior and native scroll
Promise completion.

A cache-policy audit narrows an earlier harness claim: conversation, sentinel,
`backend-api` and `backend-anon` responses were excluded, but account-picker and
telemetry JSON entries were copied into earlier caches. The final fresh-session
harness explicitly excludes `/api/`, `/ces/`, `/backend-` and non-static JSON.
Only the manifest and immutable discovery-catalog JSON remain eligible alongside
scripts, styles, fonts and images. `static-cache-policy-correction.json` records
the initial driver hash and retained source. This is a protocol correction,
not engine optimization credit; earlier failed attempts remain failed.


The fixed production executable is
`a630da28c1145951ae253eb93bd642cd510488241e460420f98f738241d51e03`,
from `Build/production-build/receipts/20261103-055307-8634efa2/`.
`production-fresh-21-c/` reaches audited startup readiness without native or
script errors, confirming the prior principal-realm crash no longer occurs.
However, its input probe still clicks the earlier homepage's hard-coded
379.5px composer position. The fresh native and Brave layouts both put the
editor at y=504, center 516. Typing reaches the autofocused editor, but the
old Send click misses, leaving the prompt unsent. The workflow check correctly
fails; this is retained as a failed input protocol, not a backend rejection.

The final position probe reads the already recorded `VOX_TYPE_DOCUMENT_Y`,
validates it as a finite number and uses that position for both focus and Send.
It sends the same individual native AppKit key events and clicks Send one
second after typing. Its source/binary are pinned in the final run's inputs;
`ready-input-position.guard.json` retains its bounded compile. No page script,
DOM state or application event handler is patched by the probe.


`production-fresh-21-d/` validates the corrected native input protocol on
`a630da28…`: audited readiness, exact prompt/reply and conversation URL, empty
native/script errors, zero browser/guard exits and stable inputs/identities.
Its strict live comparison still fails at 313 pixels (maximum channel error
159): 286 are the two missing response SVG controls; 27 are bubble-edge pixels
with maximum error two. This failure is retained.

`frozen-promise-realm-21/` remains exact. The separate read-only style diagnostic
in `live-svg-diagnostic-21/` obtains an exact PNG on `a829ba36…`, but its SVG
inspection encounters an unavailable `outerHTML` accessor and it also requests
a diagnostic redraw. Its zero-pixel result receives **no ordinary-run parity
credit**. The initial probe source/binary and failed observation are retained.

`production-fresh-21-e/` is the subsequent ordinary run on
`a829ba36cf2cc23395ab6633d73038bae08f24b93ca9180583971b86ebcca6c4`
(receipt `Build/production-build/receipts/20261103-060046-aaf568a2/`). It uses
only native input, with no style inspection or diagnostic redraw. The live
prompt/reply and conversation checks pass, errors are empty, all exits are
zero, and executable/native-library/input identities stay stable. Its full
1024×768 conversation matches unchanged fresh-21 Brave **at zero differing
pixels and zero channel error**. This result is pinned to that shared build;
the preceding SVG-control difference is not attributed to an unproven engine
path or to the style probe.

The requested repeat and latest visual guards initially fail their executable
identity precondition because another shared bundle publishes before launch
(`production-fresh-21-f/`, `conformance-fresh-21-latest/`). No browser is
launched and no acceptance is claimed for those attempts. The current-bundle
checks are recorded separately.


`production-fresh-21-g/` repeats the ordinary live workflow on current executable
`317f313a4b621eb2662df8e6d557f71e11dae3ddaf8dd80fe240990d60350012`
(receipt `Build/production-build/receipts/20261103-060729-291a6a00/`). It again
passes readiness, exact prompt/reply and conversation-URL checks, with empty
native/script errors and stable identities/inputs. Browser and guard exit zero.
Its full conversation has **zero differing pixels and zero channel error**
against the unchanged fresh-21 Brave reference. `conformance-fresh-21-current/`
passes all eleven existing smoke checks and all nine SVG mutation reftests;
every SVG comparison is exact and all identities/inputs remain stable. The
preceding `conformance-fresh-21/` also passes on `a630da28…`.

Homepage suggestion data/error handling remains a separate open item; no
pre-submit homepage equality is inferred from the exact conversation.


## Homepage resources, Blob images and font replay continuation

`f7c0a21a3` permits fresh, explicitly public responses for credentialless Fetch
without requiring `immutable`; scripts retain that additional requirement.
The native request still passes Fetch security, CORS and adblock checks. The
regional discovery catalogue is public with a seven-day freshness lifetime,
not immutable. Its original JSON and all ten referenced PNGs are now present in
`complete-static-archive-25/` (834 verified responses). Missing original assets
were downloaded once through normal Brave and SOCKS, with no fabricated module
or image bytes. `popover-archive-22/` and `discovery-assets-archive-25/` retain
those fetches. Dynamic identity, telemetry and backend responses remain excluded
from the native static cache.

The complete static archive resolves the earlier discovery-feed error. An
initial private assessment incorrectly searched the body's aggregate text,
which includes hidden templates and bootstrap code, for a visible error. The
corrected check uses the visible error node's exact text and viewport rectangle.
`production-homepage-blob-baseline-27/` has three loaded, 192-pixel Blob images,
no visible error and no native/script errors. Its `paint_decoded` flags are
false because that observer reads the shell's background-image cache, while
these HTML images paint retained decoded data. The first assessment's extra
requirement on that flag is retained as a protocol error; the PNG visibly shows
the icons. `run_homepage_28.py` records this distinction.

`95e27c99d` routes image Blob URLs through the actual owning document's Fetch
client, including its policy container, origin and storage partition. Serialized
URLs are parsed with the native Blob-entry hook; existing parsed snapshots are
retained. MIME-selected SVG decoding works without a filename suffix. The tests
cover JavaScript-created PNGs, cross-origin adoption, revocation and SVG MIME
selection. Default and no-GC modes pass in `blob-images-focused-10/`; the corrected
production allocator passes in `blob-images-focused-final/` with identical own
sources. Additional event-timing/revocation coverage is tracked separately.

`10a91bb75` preserves the system font's CSS optical instance during device-layout
scaling. `f103c2a9b` then resolves CoreText's generated variable-instance names
against a compatible base descriptor and reapplies every supplied axis. The
native trace proves the exact heading instance previously failed registration:
`.SFNS-Regular_wdth_opsz140000_GRAD_wght1F40000`, optical size 20 and weight 500.
That failure silently fell back to regular weight. The focused CoreText test
verifies descriptor identity, axis coordinates and rejection of unknown faces
or unsupported axes. `frozen-homepage-font-fixed-27/` confirms the heading's
1,584 differing pixels are gone on production `b2c78a1c…`.

`brave-homepage-26/frozen.html` materializes each live Blob image's original bytes
as a data URI in the serialized clone only. The live page is untouched; the PNG
before and after serialization is exact. All three embedded hashes match the
original archived PNGs. A fresh Brave capture of that clone also matches the
unchanged original homepage at zero pixels. The native capture differs by only
eight pixels: four around the plus path and four around the disabled Send circle.
`frozen-homepage-svg-control-32/` still has those eight pixels with the optional
SVG polygon/triangle/coverage caches disabled. Removing the two controls'
isolation in a diagnostic clone leaves Brave unchanged and still leaves the
native difference, so isolation alone is not established as the cause.

`1d11642dd` fixes another independently reproduced problem: `atob` removes
forgiving-base64 padding before passing data to V's decoder, which requires
complete four-character groups. Previously even `atob("aGVsbG8=")` returned an
empty string in the production browser. The fix restores decoder padding after
validation and projects binding inputs through actual UTF-16, preserving
`InvalidCharacterError` for lone surrogates. The source and native binding tests
pass in default, no-GC and correctly staged prealloc modes
(`forgiving-base64-focused-final/`, `forgiving-base64-binding-final/`). The old
binding test also reused a top-level `let rejected` across evaluations; its
counter now has a distinct name so the later assertions execute.

`4c2b74fb1` extends public immutable cache reuse to default-credential Fetch.
`live-conversation-fetch-trace-30/` proves the missing response controls' sprite
request received a live 403, despite its exact original bytes and explicitly
public, fresh and immutable headers being archived. The unmodified loader uses
plain `fetch(url)`. Explicit Cookie/Authorization/Range headers, private or varied
responses, revalidation modes and missing provenance still bypass this adapter;
credentialed non-immutable Fetch responses remain ineligible. All five focused
cases pass in three modes (`immutable-fetch-cache-focused-1/`), including actual
native deferred delivery with CORS and filtering.

`production-cached-sprite-38/` reaches readiness and native Send, then fails
`Document.update_layout`'s re-entry invariant; this is retained as a failing
ordinary run. The assertion is not suppressed. `layout-reentrance-trace-39/`
does not reproduce it under LLDB: the real reply succeeds, all 48 sprite symbols
are present, errors are empty and the unchanged conversation reference is exact.
The debugger exits nonzero because its final backtrace command finds an already
exited browser. This diagnostic supplies no ordinary-run parity credit.
`production-cached-sprite-41/` is also invalidated by a shared bundle update and
does not receive the expected reply. Its failed result is retained.

The prealloc runner protocol needed correction. Selecting the staged compiler
from the repository working directory still selected its baked-in original
builtin library; an actual PNG decode exposed the unbounded `v_realloc(nil,n)`.
Production builds already compile from the staged compiler directory. Corrected
focused runners now do likewise, use absolute input paths, and require the
bounded realloc helper in each binary. `prealloc-correction-regressions/`
repeats the keyframe substitution, compact scroll Promise, native Promise realm,
optical font and public Fetch cache tests successfully with this verified
allocator. Earlier tests labeled patched prealloc are superseded for that
allocator claim; their raw results remain intact.

`4be7e30cb` adds eight fractional-translation/half-pixel cases to the existing
native rounded-rectangle test. All sixteen comparisons are exact, with 185
source/library dependencies stable (`fractional-sticky-rrect-final/`). This is
regression coverage, not a claimed fix for the remaining composer pixels.

## Exact homepage continuation

`aa9bdab1b` delivers native image load/error events as owning-document tasks.
The compact bridge previously fabricated `load` both when assigning `src` and
when registering a listener on an initially complete image. A listener that
revoked its Blob URL could therefore destroy the resource before native loading.
Image wrappers now use the native EventTarget; queued events also reject a
superseded request, changed URL/state, adoption or an inactive document.
The new tests cover HTTPS and file origins, actual trusted events, setter/event
ordering, revocation, listener removal, `once`, and replacement by an empty
source. `image-event-task-focused-5/` passes in default, no-GC and verified bounded
prealloc modes. All five image regressions pass with stable inputs in
`image-event-task-regressions-3/`. The production Blob PNG/SVG reftest is exact
against both unchanged Brave and its native HTML reference
(`native-blob-images-45/`, `production-blob-images-80/`), without reported errors.

`44404a75b` fixes the disabled Send circle's four remaining pixels. Brave's
recorded draw commands use the same rounded background and stroke as Vox.
Independent Dawn replay of the complete recorded scene is exact
(`brave-composer-paint-57/`, `brave-paint-replay-58/`). The scalar leaf's generic
stroke/miter and antialias padding instead expanded its surface to 40 by 39
pixels. Its natural enclosing 32 by 33 surface reproduces Brave exactly
(`circle-descriptor-replay-55/`, `circle-descriptor-replay-59/`). Axis-aligned
compound rounded strokes now retain those natural bounds. No site, coordinate
or color selects the correction. The eight independent saveLayer comparisons
pass at both backing scales and fractional translations. Switching GPU backends,
paint palettes or the rounded-ring primitive did not supply the fix; those
failed candidates remain in runs 47–54.

`8c4610547` removes the plus icon's four one-level errors. The native observer
shows it painted into an empty surface: quarter coverage becomes premultiplied
`3,3,3,64` before meeting the white composer. Brave keeps the same path and its
background in one parent picture. A non-composited normal-opacity child had
incorrectly separated the parent's later paint chunks. The planner now retains
that parent identity. Native continuation is enabled only after proving a
complete child scope, supported bounded ink, separation from later parent ink,
and an opaque prefix covering that later ink and its raster fringe. Coverage
checks retain rounded corners, transforms and ancestor clips. Only this proved
continuation paints its prefix inside the GPU picture; independent translucent
surfaces retain their existing resolve.

`atomic-opacity-layout-focused-4/` and `opaque-effect-gap-focused-final-2/` pass
in all three memory modes, with stable relevant sources and the bounded prealloc
allocator verified. The four existing compositor-gap, SVG-layer and text-layer
regressions pass in `opaque-effect-gap-regressions-1/`; its only changed tracked
input was the new test file, which none of those four targets compile. This
over-inclusive input pin is explained in `relevant-source-stable.json` rather
than discarded. `opaque-effect-native-final/` passes the shared-picture suite
(including 144 existing comparisons and two new opaque-continuation cases), the
eight compound-stroke cases, sixteen translation cases and twelve border-clip
cases, with 187 source/library dependencies stable.

The final focused prealloc browser and explicit candidate native library match
the **unchanged complete frozen homepage at zero differing pixels and zero
channel error** (`homepage-opaque-effect-final/`). Every original archived body,
fixture/reference, executable and native-library identity remains pinned.
`opaque-effect-pixel-regressions-final/` keeps ten rounded-rendering fixtures
exact; four additional SVG/opacity fixtures are exact too. Two existing fixtures
retain 186 and 471 differing pixels. A matched control with both new grouping and
continuation disabled has byte-identical output, establishing no changed pixels
for those mismatches (`opaque-effect-disabled-control-81/comparison.json`). The
device-scale diagnostic also retains an identical existing 8,590-pixel mismatch
in control and candidate after correcting its viewport/capture-scale protocol
(`rounded-device-scale-regressions-63/`). None of these references is replaced.

The canonical production executable
`aca93fa23e0057135e261d3491fd6deee1d0ebef781b2f156aed00f4fd3082c8`
and native bridge
`b3d30c2e9625c471c9c8afd6be833247846a65386e96570f88915eb26a2c1acc`
also match that full unchanged homepage exactly, with empty native/script errors
and stable identities and all 834 archived response bodies
(`production-frozen-homepage-80/`). The bundle came from receipt
`Build/production-build/receipts/20261103-101458-3df5eaea/`; its sealed dirty inputs
already include this implementation. The later feature commit does not imply
that an older executable without those inputs validated it.

Live-session evidence remains separate. `production-cached-sprite-43/` is an
ordinary successful reply and exact comparison against the retained fresh-21
reference, resolving the earlier ordinary-run validation gap. The re-entry
assertion in run 38 is retained; no unproved assertion fix is claimed. A later
ordinary run, `production-image-events-68/`, receives the service's visible
unusual-activity response. `brave-fresh-70/` captures one authorized fresh browser
session through SOCKS and obtains a real reply with no runtime exceptions.
The frontend itself performs two document requests during that session; both
original response hashes and the request count are retained. Nothing is silently
described as one network request.

`production-fresh-72/` uses that unmodified fresh frontend, an empty initial native
cookie jar, native input after audited readiness, the archived static resources,
and a live encrypted backend through SOCKS. It receives the exact reply and a
conversation URL, has no reported errors, and matches fresh Brave at zero pixels
on executable `8952628605d7026f7f5817a8b8149ff3cbdd0249f2402a609e2a6212c571f4d5`.
The fresh-70 reference differs from retained fresh-21 by 409 response-control
pixels; both references and their corresponding exact native runs are retained.
New session data is not a replacement reference for the frozen-homepage claim.

The final ordinary live run, `production-chatgpt-final-82/`, repeats the native
Send/reply workflow on shared production executable
`590975bd959b0889ade8b5ba711bb2297bc8423f62f9d810673bcc182881a81c`.
Readiness, prompt, real reply and conversation URL all pass; native/script errors
are empty, browser/guard exits are zero and all identities/inputs remain stable.
Its full viewport matches fresh-70 Brave at **zero differing pixels and zero
channel error**. `production-frozen-homepage-final-83/` independently matches the
unchanged frozen homepage exactly on the same executable.

`production-conformance-final-83/` passes every screenshot check, but a shared
bundle replacement invalidates its identity cohort. That run receives no stable
batch credit. `production-conformance-final-84/` repeats all eleven existing
smoke checks and nine SVG mutation guards successfully on
`92387cec83e3d3b5cf462f7e65b05f8d4978a5c6a8ec23bb2f0bc678692413db`;
all nine SVG comparisons are exact and every identity/input sample is stable.
A fresh frozen-homepage capture on the next available completed bundle,
`6b29971990bdae025e55f58633868c2ef45ee4243ebcba162d2a233a0506c577`,
is also exact with empty errors and stable inputs
(`production-frozen-homepage-current-84/`). These individual captures retain
their own executable and native-library identities.

The final production [homepage assessment](../Build/chatgpt-css-error-lifetime-20261102/production-frozen-homepage-current-84/assessment.json),
[live conversation comparison](../Build/chatgpt-css-error-lifetime-20261102/production-chatgpt-final-82/pixels.json),
and [stable screenshot guards](../Build/chatgpt-css-error-lifetime-20261102/production-conformance-final-84/assessment.json)
link the current outcome to the raw evidence. All earlier failing diagnostics
and protocol corrections remain available. Obsolete focused-test executables
were removed during disk pressure after recording their hashes; raw probe pixel
buffers were gzip-compressed with verified lossless hashes. Commands, logs,
receipts, accepted PNGs and references are preserved in the same evidence root.
