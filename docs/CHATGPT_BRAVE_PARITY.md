# ChatGPT rendering and startup against Brave

The macOS production browser starts the archived logged-out ChatGPT
application and matches the unchanged Brave reference **pixel for pixel at
1024×768, scale 1**. The approved refreshed frontend also matches that reference
exactly. Both Send and Enter receive the real reply “Vox ready.” in native Vox
without native or module-script errors. Pixel equality of the live conversation
remains open; the original document's expired token is retained separately.

The latest unchanged-original-archive capture has **zero differing pixels out
of 786,432**, maximum channel error 0 and MAE 0. Startup and native typing
are validated; keyboard dispatch alone does not establish submission. The
recorded 60-second idle check peaks at 2,054,422,528 bytes,
within the 12 GiB guard. This result is specific to the pinned production build
and archived page described below.

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

Both successful unmodified conversation captures now produce the same PNG,
with 1,440 differing pixels against the unchanged live Brave reference. The
remaining mismatch is confined to the assistant reply and its actions. The
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
